module slice_place_vm;
import ir as ir;
import place_ir as proof;
import slice_place_ir as typing;
import place_vm as arrays;
import slice_places as places;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import array_vm as failures;
import cells as cells;
import errors as errors;
import fuel as meter;
import std::vec as vec;

// This private adapter does not issue executable VM admission. The caller owns
// one immutable independently analysed Program and the current resumed binding.
pub struct Requirement { usize width; bool slices; usize cost; }
fn Result<usize,errors::Error> kind(ref ir::Program p,usize pc){
    if(p.count>256 || pc>=p.count || pc>=256){return .err(errors::make(5,pc));}
    let usize at=pc*8;let u8 op=p.code[at];let usize mode=p.code[at+4] as usize;
    let usize id=p.code[at+if(op==84){2}else{1}] as usize;
    if(!proof::operation(op) || mode>1 || id>=16 || p.code[at+5]!=0 ||
        p.code[at+6]!=0 || p.code[at+7]!=0 ||
        (op==86 && (mode!=0 || p.code[at+2]!=0 || p.code[at+3]!=0))){return .err(errors::make(5,pc));}
    return .ok(mode);
}
pub fn Result<Requirement,errors::Error> requirement(ref ir::Program p){
    if(p.count>256){return .err(errors::make(5,0));}
    var usize width=0;var bool extended=false;var usize pc=0;
    while(pc<p.count){let usize at=pc*8;let u8 op=p.code[at];
        if(proof::operation(op)){let usize mode=kind(p,pc)?;
            let usize id=p.code[at+if(op==84){2}else{1}] as usize;
            if(mode==1){extended=true;}if(width<=id){width=id+1;}
        }pc+=1;
    }
    let usize price=if(extended){meter::slice_place_prepare(width)}else{meter::place_prepare(width)};
    return .ok(Requirement{.width=width,.slices=extended,.cost=price});
}
pub fn Result<vec::Vec<usize>,errors::Error> prepare(ref Requirement plan){
    if(plan.width>16 || (plan.width==0 && plan.slices) ||
        plan.cost!=if(plan.slices){meter::slice_place_prepare(plan.width)}else{meter::place_prepare(plan.width)}){
        return .err(errors::make(5,0));
    }
    return arrays::prepare_format(plan.width,plan.slices);
}
pub fn Result<usize,errors::Error> cost(ref ir::Program p,usize pc,bool extended){
    let usize mode=kind(p,pc)?;let usize at=pc*8;let u8 op=p.code[at];
    if(mode==0){let usize ordinary=arrays::cost(p,pc)?;
        return .ok(ordinary+if(extended && op==86){5}else{0});
    }
    if(!extended){return .err(errors::make(5,pc));}
    let usize site=p.code[at+if(op==84){3}else{2}] as usize;
    let u8 element=switch(ir::slice_element(p,site,pc)){
        case .ok(v):{v}case .err(_):{return .err(errors::make(5,pc));}
    };
    if(!ir::exclusive(p,site)){return .err(errors::make(5,pc));}
    let layouts::Array shape=switch(layouts::scalar(element,1)){
        case .ok(v):{v}case .err(_):{return .err(errors::make(5,pc));}
    };
    return .ok(meter::slice_place_instruction(op,shape.stride));
}

// Array operations share their original implementation. END uses the active
// row's explicit kind, not a current descriptor or an ambiguous vector length.
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize pc,usize function,usize frame,
    ref mut vec::Vec<usize> state,ref owners::Table table,ref owners::Token[] tokens,
    ref slices::Pool pool,slices::Ticket current,ref mut u8[] data,ref mut i64[] registers,usize fuel){
    let usize mode=kind(p,pc)?;let usize at=pc*8;let u8 op=p.code[at];
    if(mode==0 && op!=86){return arrays::step(p,pc,frame,state,table,tokens,data,registers,fuel);}
    let usize offset=p.offsets[pc];let arrays::Format shape=arrays::format(state,offset)?;
    let usize price=cost(p,pc,shape.row==14)?;
    if(fuel<price){return .err(errors::make(8,offset));}
    let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    let usize id=if(op==84){a}else{dst};
    if(frame>=32 || shape.width==0 || id>=shape.width){return .err(errors::make(5,offset));}
    let usize header=shape.prefix+frame*(shape.row*shape.width+1);
    let usize base=header+1+shape.row*id;let usize tail=base+shape.row-1;
    if(op==86){
        let ref mut usize[] words=vec::view_mut_usize(state);
        let usize active=words[header];let usize packed=words[tail];let usize phase=(packed>>8)&3;
        if(active==0 || active>shape.width || phase==0 || packed>if(shape.row==14){2047}else{1023}){
            return .err(errors::make(5,offset));
        }
        var usize i=0;while(i<shape.row){words[base+i]=0;i+=1;}words[header]=active-1;
        return .ok(fuel-price);
    }
    if(shape.row!=14){return .err(errors::make(5,offset));}
    if(function>=p.function_count || function>=16 || pc<p.starts[function] || pc>=p.ends[function]){
        return .err(errors::make(5,offset));
    }
    let usize site=if(op==84){b}else{a};let u8 element=typing::element(p,site,function,pc)?;
    let ref mut usize[] words=vec::view_mut_usize(state);
    let usize active=words[header];let usize packed=words[tail];let usize phase=(packed>>8)&3;
    if(active>shape.width || packed>2047){return .err(errors::make(5,offset));}
    if(op==83){
        if(phase!=0 || packed!=0 || active>=shape.width || b>=registers.len){return .err(errors::make(5,offset));}
        var usize i=0;while(i<13){if(words[base+i]!=0){return .err(errors::make(5,offset));}i+=1;}
        let usize index=cells::unpack(registers[b],offset)?;
        let places::Place selected=switch(places::select(pool,current,table,index,data.len)){
            case .ok(v):{v}case .err(e):{return .err(failures::failure(e,offset));}
        };
        if(selected.lease.view.element!=element){return .err(errors::make(5,offset));}
        let usize rooted=p.slice_roots[site] as usize;
        if(rooted!=0){
            if(tokens.len!=512){return .err(errors::make(5,offset));}
            let owners::Token expected=tokens[frame*16+rooted-1];
            if(selected.lease.view.root.slot!=expected.slot || selected.lease.view.root.generation!=expected.generation ||
                selected.lease.view.length!=p.arrays.lengths[rooted-1]){return .err(errors::make(5,offset));}
        }
        words[base]=selected.lease.view.root.slot;words[base+1]=selected.lease.view.root.generation;
        words[base+2]=selected.lease.view.length;words[base+3]=selected.lease.view.start;words[base+4]=selected.lease.view.end;
        words[base+5]=selected.lease.generation;words[base+6]=selected.ticket.slot;words[base+7]=selected.ticket.generation;
        words[base+8]=selected.mark;words[base+9]=selected.base;words[base+10]=selected.end;
        words[base+11]=selected.index;words[base+12]=selected.offset;
        words[tail]=(element as usize)|(site<<4)|256|1024;words[header]=active+1;
    }else{
        if(active==0 || phase==0 || (packed&1024)==0 || ((packed>>4)&15)!=site ||
            (packed&15)!=(element as usize)){return .err(errors::make(5,offset));}
        let usize rooted=p.slice_roots[site] as usize;
        if(rooted!=0 && words[base+2]!=p.arrays.lengths[rooted-1]){return .err(errors::make(5,offset));}
        let places::Place selected=places::Place{
            .lease=owners::WriteLease{.view=owners::View{
                .root=owners::Token{.slot=words[base],.generation=words[base+1]},.element=element,
                .length=words[base+2],.start=words[base+3],.end=words[base+4]},.generation=words[base+5]},
            .ticket=slices::Ticket{.slot=words[base+6],.generation=words[base+7]},
            .mark=words[base+8],.base=words[base+9],.end=words[base+10],.index=words[base+11],.offset=words[base+12]};
        if(op==84){
            if(phase!=1 || dst>=registers.len){return .err(errors::make(5,offset));}
            let i64 cell=switch(places::read(pool,current,table,ref selected,data)){
                case .ok(v):{v}case .err(e):{return .err(failures::failure(e,offset));}
            };
            words[tail]=(packed&1279)|512;registers[dst]=cell;
        }else{
            if(phase==3 || b>=registers.len){return .err(errors::make(5,offset));}
            let usize written=switch(places::store(pool,current,table,ref selected,registers[b],data)){
                case .ok(v):{v}case .err(e):{return .err(failures::failure(e,offset));}
            };
            words[tail]=(packed&1279)|768;
        }
    }
    return .ok(fuel-price);
}
