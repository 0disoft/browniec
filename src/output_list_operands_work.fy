module output_list_operands_work;
import ir as ir;
import array_list_ir as lists;
import register_set as registers;
import errors as errors;
import metadata_budget as budget;

// Canonical operand proof only; the parent proves owner/place liveness first.
// Pin Program and the independently reconstructed definition set until done.
// <=64 operand visits per fresh stage, including their fixed scalar-role fields.
pub struct State { usize pc; usize function; usize cursor; usize start; usize length; usize root; bool begun; bool done; }
pub fn State empty(usize pc,usize function){return State{.pc=pc,.function=function,.cursor=0,.start=0,.length=0,.root=0,.begun=false,.done=false};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
pub fn Result<bool,errors::Error> advance(ref ir::Program p,ref registers::Set defined,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(!budget::admit(meter,4096,w.pc)?){return .ok(false);}
    let usize f=w.function;let usize pc=w.pc;
    // The raw operand helper is called only at a bounded canonical CFG PC.
    if(p.count>256 || pc>=p.count || p.function_count>16 || f>=p.function_count){return .err(invalid(pc));}
    if(!w.begun){
        let usize id=lists::destination(p,pc);
        if(id>=p.arrays.count || id>=16){return .err(invalid(pc));}
        let usize at=lists::start(p,pc);let usize length=p.arrays.lengths[id];
        if(p.list_used>4096 || at>p.list_used || length>p.list_used-at){return .err(invalid(pc));}
        w.root=id;w.start=at;w.length=length;w.begun=true;return .ok(false);
    }
    let usize id=w.root;var usize end=w.cursor+64;if(end>w.length){end=w.length;}
    while(w.cursor<end){let usize r=p.list_operands[w.start+w.cursor] as usize;
        if(r<p.register_starts[f] || r>=p.register_ends[f] || r>=128 || p.slots[r] ||
            p.types[r]!=p.arrays.elements[id] || p.array_parameters[r]!=0 || p.record_parameters[r]!=0 ||
            p.slice_parameters[r]!=0 || !registers::contains(defined,r)){return .err(invalid(pc));}
        w.cursor+=1;
    }
    w.done=w.cursor==w.length;return .ok(w.done);
}
