module place_vm;
import ir as ir;
import place_ir as proof;
import array_places as places;
import array_owners as owners;
import array_layout as layouts;
import array_vm as arrays;
import cells as cells;
import errors as errors;
import fuel as meter;
import std::vec as vec;

pub struct Requirement { usize width; usize cost; }
// One frame counter plus nine usize words per location, over 32 frames.
// Slots contain eight original location words and packed type/root/phase.
// Metadata is invocation-owned; no fixed snapshot array on the native stack.
pub fn Result<Requirement,errors::Error> requirement(ref ir::Program p) {
    if(p.count>256){return .err(errors::make(5,0));}
    var usize width=0;var usize pc=0;
    while(pc<p.count){let usize at=pc*8;let u8 op=p.code[at];
        if(proof::operation(op)){let usize id=p.code[at+if(op==84){2}else{1}] as usize;
            if(id>=16){return .err(errors::make(5,pc));}if(width<=id){width=id+1;}
        }pc+=1;
    }
    return .ok(Requirement{.width=width,.cost=meter::place_prepare(width)});
}
pub fn Result<vec::Vec<usize>,errors::Error> prepare(ref Requirement plan) {
    if(plan.width>16 || plan.cost!=meter::place_prepare(plan.width)){return .err(errors::make(5,0));}
    var vec::Vec<usize> state=vec::empty<usize>();
    if(plan.width!=0){let usize count=32*(9*plan.width+1);
        let usize reserved=switch(vec::reserve<usize>(ref mut state,count)){
            case .ok(n):{n}case .err(_):{return .err(errors::make(15,0));}
        };
        var usize i=0;while(i<count){let usize pushed=switch(vec::push<usize>(ref mut state,0)){
            case .ok(n):{n}case .err(_):{return .err(errors::make(15,0));}
        };i+=1;}
    }
    return .ok(state);
}
fn Result<usize,errors::Error> width(usize count,usize offset) {
    if(count==0){return .ok(0);}
    if(count%32!=0 || count<320 || count>4640 || (count/32-1)%9!=0){return .err(errors::make(5,offset));}
    return .ok((count/32-1)/9);
}
pub fn Result<usize,errors::Error> empty_frame(ref vec::Vec<usize> state,usize frame,usize offset) {
    let usize stride=width(vec::len<usize>(state),offset)?;
    if(frame>=32){return .err(errors::make(5,offset));}
    if(stride!=0 && vec::view_usize(state)[frame*(9*stride+1)]!=0){return .err(errors::make(5,offset));}
    return .ok(frame);
}
pub fn Result<usize,errors::Error> cost(ref ir::Program p,usize pc) {
    if(pc>=p.count || pc>=256){return .err(errors::make(5,pc));}
    let usize at=pc*8;let u8 op=p.code[at];
    if(!proof::operation(op)){return .err(errors::make(5,pc));}
    if(op==86){return .ok(meter::place_instruction(op,0));}
    let usize root=p.code[at+if(op==84){3}else{2}] as usize;
    if(root>=p.arrays.count || root>=16 || !p.arrays.mutable[root]){return .err(errors::make(5,pc));}
    let layouts::Array layout=switch(layouts::scalar(p.arrays.elements[root],p.arrays.lengths[root])){
        case .ok(v):{v}case .err(_):{return .err(errors::make(5,pc));}
    };
    return .ok(meter::place_instruction(op,layout.stride));
}
// Caller supplies immutable independently admitted code and its invocation's
// owner table/backing. Dispatch allocates nothing and never copies token tables.
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize pc,usize frame,
    ref mut vec::Vec<usize> state,ref owners::Table table,ref owners::Token[] tokens,
    ref mut u8[] data,ref mut i64[] registers,usize fuel) {
    let usize price=cost(p,pc)?;let usize offset=p.offsets[pc];
    if(fuel<price){return .err(errors::make(8,offset));}
    let usize count=vec::len<usize>(state);let usize slots=width(count,offset)?;
    let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
    let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    let usize id=if(op==84){a}else{dst};
    if(frame>=32 || slots==0 || id>=slots || tokens.len!=512){return .err(errors::make(5,offset));}
    let usize header=frame*(9*slots+1);let usize base=header+1+9*id;
    let ref mut usize[] words=vec::view_mut_usize(state);
    let usize active=words[header];let usize packed=words[base+8];let usize phase=packed>>8;
    if(active>slots || phase>3){return .err(errors::make(5,offset));}
    if(op==83){
        if(phase!=0 || packed!=0 || active>=slots || b>=registers.len){return .err(errors::make(5,offset));}
        let usize index=cells::unpack(registers[b],offset)?;
        let places::Place selected=switch(places::select(table,tokens[frame*16+a],index,data.len)){
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
        };
        if(selected.element!=p.arrays.elements[a] || selected.length!=p.arrays.lengths[a]){return .err(errors::make(5,offset));}
        words[base]=selected.root.slot;words[base+1]=selected.root.generation;words[base+2]=selected.length;
        words[base+3]=selected.mark;words[base+4]=selected.base;words[base+5]=selected.end;
        words[base+6]=selected.index;words[base+7]=selected.offset;
        words[base+8]=(selected.element as usize)|(a<<4)|256;words[header]=active+1;
    }else{
        if(phase==0 || active==0){return .err(errors::make(5,offset));}
        if(op==86){var usize i=0;while(i<9){words[base+i]=0;i+=1;}words[header]=active-1;}
        else{
            let usize root=if(op==84){b}else{a};
            if(((packed>>4)&15)!=root || (packed&15)!=(p.arrays.elements[root] as usize) ||
                words[base+2]!=p.arrays.lengths[root]){return .err(errors::make(5,offset));}
            let places::Place selected=places::Place{.root=owners::Token{.slot=words[base],.generation=words[base+1]},
                .element=p.arrays.elements[root],.length=words[base+2],.mark=words[base+3],.base=words[base+4],
                .end=words[base+5],.index=words[base+6],.offset=words[base+7]};
            if(op==84){
                if(phase!=1 || dst>=registers.len){return .err(errors::make(5,offset));}
                let i64 cell=switch(places::read(table,ref selected,data)){
                    case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
                };
                words[base+8]=(packed&255)|512;registers[dst]=cell;
            }else{
                if(phase==3 || b>=registers.len){return .err(errors::make(5,offset));}
                let usize written=switch(places::store(table,ref selected,registers[b],data)){
                    case .ok(n):{n}case .err(e):{return .err(arrays::failure(e,offset));}
                };
                words[base+8]=(packed&255)|768;
            }
        }
    }
    return .ok(fuel-price);
}
