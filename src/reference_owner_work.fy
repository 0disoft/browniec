module reference_owner_work;
import ir as ir;
import functions as functions;
import reference_call_source as calls;
import errors as errors;
import metadata_budget as budget;

// A single dependency is followed at a time. The original depth check is
// applied before inspecting each value, including cyclic reference chains.
pub struct State { usize value; usize depth; usize at; usize pc; usize next;
    usize result; usize visits; u8 phase; bool done; }
pub fn State begin(usize value,usize depth,usize at){return State{.value=value,.depth=depth,.at=at,
    .pc=0,.next=0,.result=0,.visits=0,.phase=0,.done=false};}
pub fn Result<usize,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.result);
}
pub fn Result<bool,errors::Error> advance(ref ir::Program p,ref functions::Table signatures,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}w.visits+=1;
    if(w.phase==0){
        if(w.depth>32){return .err(errors::make(4,w.at));}
        if(w.value>=160 && w.value<176){let usize root=p.slice_roots[w.value-160] as usize;
            if(root>16){return .err(errors::make(3,w.at));}let usize one=1;
            w.result=if(root==0){0}else{one<<(root-1)};w.done=true;return .ok(true);}
        if(w.value<192 || w.value>=208){return .err(errors::make(3,w.at));}
        w.pc=0;w.phase=1;return .ok(false);
    }
    if(w.phase==2){w.value=w.next;w.depth+=1;w.phase=0;return .ok(false);}
    if(w.phase!=1){return .err(errors::make(5,w.at));}
    if(w.pc>=p.count){return .err(errors::make(3,w.at));}
    let usize code=w.pc*8;let u8 op=p.code[code];let usize a=p.code[code+2] as usize;
    if(p.code[code+1] as usize==w.value-192){
        if(op==69 || op==77){w.result=0;w.done=true;return .ok(true);}
        if(op==74 || op==75 || op==76){w.next=192+a;w.phase=2;return .ok(false);}
        if(op==78 && calls::result(signatures,a)){
            let usize chosen=signatures.return_slice_inputs[a] as usize;
            if(chosen==9){w.result=0;w.done=true;return .ok(true);}
            let usize map=p.code[code+3] as usize;
            if(chosen==0 || chosen>p.arities[a] || map>=p.call_count){return .err(errors::make(3,w.at));}
            w.next=p.call_args[map*8+chosen-1] as usize;w.phase=2;return .ok(false);
        }
    }
    w.pc+=1;return .ok(false);
}
