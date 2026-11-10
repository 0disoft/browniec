module output_reference_lifetimes_work;
import ir as ir;
import static_ir as statics;
import errors as errors;
import metadata_budget as budget;

// Analysis after the complete canonical recipe/scalar/owner/loan proof. Keep
// that exact immutable Program and Sites pinned. This never grants admission.
// One fresh stage prepares one PC, initializes one CFG bank, or proves one PC.
pub struct State { usize[16] roots; bool[256] seen; usize[256] states; usize pc; usize function; u8 phase; bool done; }
pub fn State empty(){return State{.roots=[0;16],.seen=[false;256],.states=[0;256],.pc=0,.function=0,.phase=0,.done=false};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
fn Result<usize,errors::Error> actual(ref ir::Program p,ref usize[] roots,usize value,usize pc){
    if(value>=192 && value<208){return .ok(roots[value-192]);}
    if(value<160 || value>=176){return .err(invalid(pc));}
    let usize root=p.slice_roots[value-160] as usize;let usize one=1;
    if(root>16 || root>p.arrays.count){return .err(invalid(pc));}
    return .ok(if(root==0){0}else{one<<(root-1)});
}
fn Result<usize,errors::Error> guard(ref ir::Program p,usize pc,usize protected){
    let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
    let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;let usize one=1;
    if(op==36 || op==37 || op==38 || op==40 || op==81){
        if((protected&(one<<dst))!=0){return .err(invalid(pc));}
    }else if(op==83 || op==84 || op==85 || op==87){let usize site=if(op==84){b}else{a};
        // Plain records cannot back byte-reference results. Their catalog site
        // is a separate namespace from both array roots and slice sites.
        if(p.code[at+4]==2 || p.code[at+4]==4){return .ok(protected);}
        let usize root=if(p.code[at+4]==0 || p.code[at+4]==3){site+1}else{p.slice_roots[site] as usize};
        if(root!=0 && (protected&(one<<(root-1)))!=0){return .err(invalid(pc));}
    }else if(op==60 || op==61 || (op==54 && ir::exclusive(p,dst))){
        let usize root=p.slice_roots[dst] as usize;
        if(root!=0 && (protected&(one<<(root-1)))!=0){return .err(invalid(pc));}
    }else if(op==9 || op==64 || op==66 || op==78){var usize i=0;
        while(i<p.arities[a]){let usize formal=p.slice_parameters[p.register_starts[a]+i] as usize;
    if(formal!=0 && ir::exclusive(p,formal-1)){let usize source=p.call_args[b*8+i] as usize;
        if(source<160 || source>=176){return .err(invalid(pc));}
        let usize root=p.slice_roots[source-160] as usize;
        if(root!=0 && (protected&(one<<(root-1)))!=0){return .err(invalid(pc));}
    }i+=1;
        }
    }return .ok(protected);
}
fn Result<usize,errors::Error> merge(ref mut State w,usize target,usize bits,usize pc){
    if(w.seen[target] && w.states[target]!=bits){return .err(invalid(pc));}
    w.seen[target]=true;w.states[target]=bits;return .ok(target);
}

pub fn Result<bool,errors::Error> advance(ref ir::Program p,ref statics::Sites sites,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(!budget::admit(meter,4096,w.pc)?){return .ok(false);}
    if(p.count>256 || p.function_count>16){return .err(invalid(0));}
    if(w.phase==0){
        if(w.pc==p.count){w.phase=1;w.function=0;return .ok(false);}
        let usize pc=w.pc;let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
        let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
        if((op==75 || op==76) && sites.kinds[dst]==3){let usize value=w.roots[a];w.roots[dst]=value;}
        else if(op==78 && sites.results[a]==3){let usize origin=sites.origins[a] as usize;
    if(origin==0 || origin>9 || (origin!=9 && origin>p.arities[a])){return .err(invalid(pc));}
    if(origin!=9){let usize value=actual(p,ref w.roots,p.call_args[b*8+origin-1] as usize,pc)?;w.roots[dst]=value;}
        }
        w.pc+=1;return .ok(false);
    }
    if(w.phase==1){
        if(w.function==p.function_count){w.done=true;return .ok(true);}
        let usize f=w.function;
        if(p.starts[f]>=p.ends[f] || p.ends[f]>p.count){return .err(invalid(0));}
        w.seen=[false;256];w.states=[0;256];w.seen[p.starts[f]]=true;w.pc=p.starts[f];w.phase=2;return .ok(false);
    }
    if(w.phase!=2){return .err(invalid(0));}
    let usize f=w.function;
    if(w.pc==p.ends[f]){w.function+=1;w.phase=1;return .ok(false);}
    let usize pc=w.pc;let usize one=1;
    if(!w.seen[pc]){return .err(invalid(pc));}var usize bits=w.states[pc];var usize protected=0;var usize site=0;
    while(site<16){if((bits&(one<<site))!=0){protected|=w.roots[site];}site+=1;}
    let usize checked=guard(p,pc,protected)?;let usize at=pc*8;let u8 op=p.code[at];
    let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    if((op>=74 && op<=77) || op==69 || (op==78 && sites.results[a]!=0)){bits|=one<<dst;}
    else if(op==70){bits^=one<<dst;}
    if(op==8 || op==39 || op==50 || op==65 || op==79 || op==25 || op==82){w.pc+=1;return .ok(false);}
    if(op==22){if(!w.seen[a] || w.states[a]!=bits){return .err(invalid(pc));}w.pc+=1;return .ok(false);}
    if(op==19 || op==20 || op==21 || op==24){
        let usize target=if(op==19){a}else if(op==24){p.code[at+4] as usize}else{b};
        let usize linked=merge(w,target,bits,pc)?;
        if(op==19){w.pc+=1;return .ok(false);}
    }
    if(pc+1>=p.ends[f]){return .err(invalid(pc));}
    let usize linked=merge(w,pc+1,bits,pc)?;w.pc+=1;return .ok(false);
}
