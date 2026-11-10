module output_place_lifetimes_work;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
import place_ir as places;
import aggregate_place_ir as aggregates;

// Resumable identity/lifetime graph after canonical place metadata, scalar
// ownership and reachable CFG proof. Place metadata is trusted: this kernel does
// not replay 83..87 structural checks or aggregate copies preparation.
pub struct State {
    u8[4096] origins;
    usize[256] phases;
    bool[256] seen;
    usize function; usize pc; usize count; usize cleared;
    u8 phase; bool active; bool done;
}

pub fn State empty(){
    return State{.origins=[0;4096],.phases=[0;256],.seen=[false;256],
        .function=0,.pc=0,.count=0,.cleared=0,.phase=0,.active=true,.done=false};
}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}

fn Result<usize,errors::Error> merge(ref mut State w,usize target,ref u8[] origins,
    usize phases,usize pc,bool backedge){
    if(target>=256 || (backedge && !w.seen[target])){return .err(invalid(pc));}
    if(w.seen[target] && w.phases[target]!=phases){return .err(invalid(pc));}
    var usize i=0;
    while(i<16){
        let usize offset=target*16+i;
        if(w.seen[target] && w.origins[offset]!=origins[i]){return .err(invalid(pc));}
        if(!backedge){w.origins[offset]=origins[i];}
        i+=1;
    }
    if(!backedge){w.phases[target]=phases;w.seen[target]=true;}
    return .ok(target);
}
fn Result<u8,errors::Error> encoded(usize value,usize pc){
    var u8 result=0;var usize n=0;
    while(n<value){if(result==255){return .err(invalid(pc));}result+=1;n+=1;}
    return .ok(result);
}

pub fn Result<bool,errors::Error> advance(ref ir::Program p,ref mut State w,
    ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(!w.active){return .err(invalid(0));}
    if(meter.last!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.pc)?){return .ok(false);}
    let usize current=w.function;
    let Result<usize,errors::Error> result=if(w.phase==0){prepare(w,p)}
        else if(w.phase==1){function_header(w,p)}
        else if(w.phase==2){clear_origins(w)}
        else if(w.phase==3){clear_frame(w,p)}
        else if(w.phase==4){function_pc(w,p,current)}
        else{.err(invalid(0))};
    switch(result){case .ok(_):{}case .err(e):{w.active=false;return .err(e);}};
    return .ok(w.done);
}

fn Result<usize,errors::Error> prepare(ref mut State w,ref ir::Program p){
    if(!places::present(p)){w.done=true;w.active=false;return .ok(0);}
    if(p.count==0 || p.count>256 || p.function_count==0 || p.function_count>16 ||
        p.arrays.count>16 || p.records.count>16 || p.registers>128){return .err(invalid(0));}
    w.function=0;w.count=0;w.phase=1;return .ok(0);
}
fn Result<usize,errors::Error> function_header(ref mut State w,ref ir::Program p){
    let usize f=w.function;
    if(p.starts[f]>=p.ends[f] || p.ends[f]>p.count ||
        p.register_starts[f]>p.register_ends[f] || p.register_ends[f]>p.registers){return .err(invalid(0));}
    w.cleared=0;w.phase=2;return .ok(0);
}
fn Result<usize,errors::Error> clear_origins(ref mut State w){
    let usize stop=if(w.cleared+2048>4096){4096}else{w.cleared+2048};
    var usize index=w.cleared;while(index<stop){w.origins[index]=0;index+=1;}w.cleared=stop;
    if(w.cleared==4096){w.phase=3;}
    return .ok(0);
}
fn Result<usize,errors::Error> clear_frame(ref mut State w,ref ir::Program p){
    var usize i=0;while(i<256){w.phases[i]=0;w.seen[i]=false;i+=1;}
    let usize start=p.starts[w.function];w.seen[start]=true;w.pc=start;w.phase=4;return .ok(0);
}

fn Result<usize,errors::Error> function_pc(ref mut State w,ref ir::Program p,usize f){
    if(w.pc==p.ends[f]){
        w.function+=1;
        if(w.function==p.function_count){w.done=true;w.active=false;}
        else{w.phase=1;}
        return .ok(0);
    }
    let usize pc=w.pc;let usize at=pc*8;let u8 op=p.code[at];
    if(!w.seen[pc]){w.pc+=1;return .ok(0);}
    var u8[16] origins=[0;16];var usize i=0;
    while(i<16){origins[i]=w.origins[pc*16+i];i+=1;}
    var usize phases=w.phases[pc];
    if(places::operation(op)){
        let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;
        let usize site=if(op==84){a}else{dst};
        let usize phase=(phases>>(2*site))&3;
        let usize three=3;let usize mask=three<<(2*site);
        if(op==83){
            if(phase!=0 || origins[site]!=0){return .err(invalid(pc));}
            origins[site]=encoded(pc+1,pc)?;
            phases|=(three-2)<<(2*site);w.count+=1;
        }else{
            if(phase==0 || origins[site]==0){return .err(invalid(pc));}
            let usize selected=(origins[site] as usize)-1;
            if(selected>=pc || p.code[selected*8]!=83 || p.code[selected*8+1] as usize!=site){return .err(invalid(pc));}
            if(op!=86){
                if(p.code[selected*8+4]>=3){if(!aggregates::same_selection(p,selected,pc)){return .err(invalid(pc));}}
                else if(p.code[selected*8+2] as usize!=if(op==84){p.code[at+3] as usize}else{a} ||
                    p.code[selected*8+4]!=p.code[at+4] || p.code[selected*8+5]!=p.code[at+5]){
                    return .err(invalid(pc));
                }
            }
            if(op==84 && phase!=1){return .err(invalid(pc));}
            if((op==85 || op==87) && phase==3){return .err(invalid(pc));}
            phases&=~mask;
            if(op==86){origins[site]=0;}
            else{let usize next=if(op==84){2}else{3};phases|=next<<(2*site);}
        }
    }else if(op==37 || op==45 || op==56 || op==62){
        i=0;while(i<16){
            if(origins[i]!=0){let usize selected=((origins[i] as usize)-1)*8;let u8 kind=p.code[selected+4];
                if(p.code[selected+2] as usize==p.code[at+1] as usize &&
                    if(op==37){kind==0 || kind==3}else if(op==45){kind==2 || kind==4}else{kind==1}){
                    return .err(invalid(pc));
                }
            }i+=1;
        }
    }
    if(op==8 || op==39 || op==50 || op==65 || op==79 || op==82 || op==94 || op==113){
        if(phases!=0){return .err(invalid(pc));}w.pc+=1;return .ok(0);
    }
    if(op==25){w.pc+=1;return .ok(0);}
    if(op==22){let usize linked=merge(w,p.code[at+2] as usize,ref origins[..],phases,pc,true)?;w.pc+=1;return .ok(0);}
    if(op==19 || op==20 || op==21 || op==24 || op==92){
        let target=if(op==19){p.code[at+2] as usize}else if(op==24 || op==92){p.code[at+4] as usize}else{p.code[at+3] as usize};
        let usize linked=merge(w,target,ref origins[..],phases,pc,false)?;
        if(op==19){w.pc+=1;return .ok(0);}
    }
    if(pc+1>=p.ends[f]){return .err(invalid(pc));}
    let usize linked=merge(w,pc+1,ref origins[..],phases,pc,false)?;w.pc+=1;return .ok(0);
}
