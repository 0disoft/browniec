module output_list_metadata_work;
import ir as ir;
import array_list_ir as lists;
import errors as errors;
import metadata_budget as budget;

// Analysis only. Keep the same immutable Program until completion. This is the
// dense-span/padding pass, not operand liveness or executable proof authority.
// A stage visits one instruction or <=256 pool entries. Reserve the whole fresh
// allowance conservatively; no credit is accumulated for a later atomic scan.
pub struct State { u8 phase; usize pc; usize cursor; bool done; }
pub fn State empty(){return State{.phase=0,.pc=0,.cursor=0,.done=false};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
pub fn Result<bool,errors::Error> advance(ref ir::Program p,ref mut State work,ref mut budget::State meter){
    if(work.done){return .ok(true);}
    if(!budget::admit(meter,4096,work.pc)?){return .ok(false);}
    if(work.phase==0){
        if(p.count>256 || p.arrays.count>16 || p.list_used>4096){return .err(invalid(0));}
        work.phase=1;return .ok(false);
    }
    if(work.phase==1){
        if(work.pc<p.count){
            if(lists::operation(p,work.pc)){
                let usize id=lists::destination(p,work.pc);
                if(id>=p.arrays.count || lists::start(p,work.pc)!=work.cursor){return .err(invalid(work.pc));}
                let usize length=p.arrays.lengths[id];
                if(length==0 || length>4096 || work.cursor>p.list_used || length>p.list_used-work.cursor){return .err(invalid(work.pc));}
                work.cursor+=length;
            }
            work.pc+=1;return .ok(false);
        }
        if(work.cursor!=p.list_used){return .err(invalid(0));}
        work.phase=2;return .ok(false);
    }
    if(work.phase!=2 || work.cursor>4096){return .err(invalid(0));}
    var usize end=work.cursor+256;if(end>4096){end=4096;}
    while(work.cursor<end){
        if(p.list_operands[work.cursor]!=0){return .err(invalid(0));}
        work.cursor+=1;
    }
    if(work.cursor==4096){work.done=true;return .ok(true);}
    return .ok(false);
}
