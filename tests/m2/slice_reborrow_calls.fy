module tests::m2::slice_reborrow_calls;
import ir as ir;
import errors as errors;
import slice_builders as builders;
import slice_reborrow_ir as forest;
import slice_reborrow_call_ir as proof;
import verifier as verifier;
import vm as vm;
import vm_execution as execution;
import array_vm as arrays;
import slice_vm as slices;
import slice_call_vm as calls;
import std::bytes as bytes;
fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void finish(ref mut ir::Program p,usize f){let usize n=p.count;let usize r=p.registers;p.ends[f]=n;p.register_ends[f]=r;}
fn usize opcode(ref ir::Program p,u8 op){var usize pc=p.starts[1];while(pc<p.ends[1]){if(p.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;}
fn void bad(ref ir::Program p,usize at){assert(switch(verifier::inspect_reborrow_calls(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==at}});}
fn void good(ref ir::Program p){assert(built(verifier::inspect_reborrow_calls(p))==p.count);let usize at=opcode(p,9);assert(switch(verifier::inspect(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==at}});assert(verifier::verify(p).is_ok);}
fn void skip(ref mut ir::Program p,usize pc){p.code[pc*8]=19;p.code[pc*8+1]=0;p.code[pc*8+3]=0;p.code[pc*8+4]=0;let usize patched=built(ir::patch(p,pc,pc+1,77));}
fn ir::Program program(u8 tag,bool formal,usize levels,usize argc,bool loop){
    var ir::Program p=ir::empty();p.function_count=3;p.entry=2;p.arities[0]=argc;p.return_types[0]=1;p.return_types[1]=1;p.return_types[2]=1;
    var usize[2] callee=[16;2];var usize row=0;
    while(row<argc){callee[row]=built(builders::parameter_exclusive(ref mut p,0,tag,77));row+=1;}
    row=0;while(row<argc){let usize close=built(ir::slice_close(ref mut p,callee[row],77));row+=1;}
    let usize answer=built(ir::literal(ref mut p,42,77));let usize done=built(ir::emit(ref mut p,8,answer,0,77));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize width=if(argc==2){2}else{1};p.arities[1]=if(formal){width}else{0};
    var usize[2] roots=[16;2];var usize[32] sites=[16;32];row=0;
    while(row<width){
        if(formal){sites[row*16]=built(builders::parameter_exclusive(ref mut p,1,tag,77));}
        else{roots[row]=built(ir::array_in(ref mut p,1,tag,2,true,77));sites[row*16]=built(ir::exclusive_slice(ref mut p,roots[row],77));}
        row+=1;
    }
    // Complete all formal positions before builders inspect a derived origin.
    row=0;while(row<width){var usize level=1;while(level<=levels){sites[row*16+level]=built(forest::derived(ref mut p,sites[row*16+level-1],77));level+=1;}row+=1;}
    let usize lo=built(ir::integer(ref mut p,0,12,77));let usize hi=built(ir::integer(ref mut p,1,12,77));
    if(!formal){let usize fill=built(if(tag==2){ir::boolean(ref mut p,false,77)}else{ir::integer(ref mut p,0,tag,77)});row=0;while(row<width){let usize init=built(ir::array_init(ref mut p,roots[row],fill,77));let usize open=built(ir::slice_open(ref mut p,sites[row*16],lo,hi,77));row+=1;}}
    let usize condition=built(ir::boolean(ref mut p,true,77));let usize target=p.count;row=0;
    while(row<width){var usize level=1;while(level<=levels){let usize begin=built(forest::begin(ref mut p,sites[row*16+level],sites[row*16+level-1],lo,hi,77));level+=1;}row+=1;}
    let usize[2] args=[160+sites[levels],160+sites[16+levels]];
    let usize result=built(ir::call(ref mut p,0,ref args[..argc],77));
    row=width;while(row>0){row-=1;var usize level=levels;while(level>0){let usize end=built(forest::end(ref mut p,sites[row*16+level],sites[row*16+level-1],77));level-=1;}}
    if(loop){let usize branch=built(ir::raw(ref mut p,20,0,condition,0,77));let usize back=built(ir::raw(ref mut p,22,0,target,0,77));let usize end=p.count;let usize patched=built(ir::patch(ref mut p,branch,end,77));}
    row=width;while(row>0){row-=1;let usize length=built(ir::slice_length(ref mut p,sites[row*16],77));let usize close=built(ir::slice_close(ref mut p,sites[row*16],77));if(!formal){let usize drop=built(ir::array_drop(ref mut p,roots[row],77));}}
    let usize returned=built(ir::emit(ref mut p,8,result,0,77));finish(ref mut p,1);
    let usize entry=p.count;let usize end_regs=p.registers;p.starts[2]=entry;p.register_starts[2]=end_regs;
    let usize entry_answer=built(ir::literal(ref mut p,42,77));let usize entry_return=built(ir::emit(ref mut p,8,entry_answer,0,77));finish(ref mut p,2);return p;
}
@test
fn void all_six_owned_and_formal_children_prove_and_preserve_caller_live_word(){
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;
    while(i<6){let ir::Program owned=program(tags[i],false,2,1,false);let ir::Program formal=program(tags[i],true,2,1,false);good(ref owned);good(ref formal);
        let forest::Sites sites=switch(forest::metadata(ref formal)){case .ok(v):{v}case .err(_):{assert(false);forest::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};
        let usize one=1;let usize live=(one<<35)|(one<<49)|(one<<50);let usize at=opcode(ref formal,9);
        assert(built(proof::inspect(ref formal,ref sites,at,1,live))==live);i+=1;}
}
@test
fn void scalar_calls_maximum_site_depth_balanced_loops_and_independent_roots_prove(){
    let ir::Program scalar=program(10,false,2,0,false);good(ref scalar);
    let ir::Program full=program(10,true,14,1,false);good(ref full);assert(full.slice_origins[15]==2);
    let ir::Program loop=program(10,true,2,1,true);good(ref loop);
    let ir::Program owned=program(10,false,2,2,false);good(ref owned);
    let ir::Program formals=program(10,true,2,2,false);good(ref formals);
}
@test
fn void suspended_parent_intermediate_and_closed_child_arguments_are_rejected(){
    let ir::Program p=program(10,true,2,1,false);let usize at=opcode(ref p,9);var ir::Program q=p;
    q.call_args[0]=161;bad(ref q,at);q=p;q.call_args[0]=162;bad(ref q,at);
    // Ending the child restores its parent; the former child cannot be passed.
    q=p;let usize end=opcode(ref q,62);var usize c=0;while(c<8){let u8 v=q.code[at*8+c];let u8 w=q.code[end*8+c];q.code[at*8+c]=w;q.code[end*8+c]=v;c+=1;}bad(ref q,end);
    q=p;q.call_args[0]=160;bad(ref q,at);
}
@test
fn void duplicate_exclusive_writers_modes_tags_and_wrong_functions_are_rejected(){
    let ir::Program p=program(10,true,2,2,false);let usize at=opcode(ref p,9);var ir::Program q=p;
    let u8 first=q.call_args[0];q.call_args[1]=first;bad(ref q,at);
    q=p;q.slice_elements[0]=9;bad(ref q,at);
    q=p;q.slice_elements[0]=10;bad(ref q,at);
    q=p;q.call_args[1]=160;bad(ref q,at);
    q=p;q.call_args[1]=0;bad(ref q,at);
}
@test
fn void malformed_call_descriptors_and_late_arguments_keep_complete_validation(){
    let ir::Program p=program(10,false,1,2,false);let usize at=opcode(ref p,9);var ir::Program q=p;
    q.code[at*8+2]=16;bad(ref q,at);q=p;q.code[at*8+3]=32;bad(ref q,at);
    q=p;q.call_arities[0]=1;bad(ref q,at);q=p;q.call_args[2]=160;bad(ref q,at);
    q=p;q.code[at*8+5]=1;bad(ref q,at);q=p;q.call_count=2;bad(ref q,0);
}
@test
fn void forests_joins_and_backedges_still_require_exact_lifo_restoration(){
    let ir::Program p=program(10,true,2,1,true);let usize end=opcode(ref p,62);var ir::Program q=p;
    skip(ref mut q,end);assert(!verifier::inspect_reborrow_calls(ref q).is_ok);
    q=p;let usize begin=opcode(ref q,61);q.code[(begin+1)*8+2]=3;assert(!verifier::inspect_reborrow_calls(ref q).is_ok);
    q=p;let usize back=opcode(ref q,22);q.code[back*8+2]+=1;bad(ref q,back);
    q=p;q.code[begin*8+2]=3;assert(!verifier::inspect_reborrow_calls(ref q).is_ok);
}
@test
fn void forged_live_forest_is_rejected_without_mutating_the_supplied_snapshot(){
    let ir::Program p=program(10,true,2,1,false);let usize at=opcode(ref p,9);let usize one=1;
    let forest::Sites sites=switch(forest::metadata(ref p)){case .ok(v):{v}case .err(_):{assert(false);forest::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};
    let usize live=(one<<35)|(one<<49)|(one<<50);
    assert(!proof::inspect(ref p,ref sites,at,1,live|(one<<33)).is_ok);
    assert(!proof::inspect(ref p,ref sites,at,1,live^(one<<50)).is_ok);
    assert(!proof::inspect(ref p,ref sites,at,1,live|(one<<48)).is_ok);
    assert(!proof::inspect(ref p,ref sites,at,1,live|(one<<51)).is_ok);
    assert(built(proof::inspect(ref p,ref sites,at,1,live))==live);
}
@test
fn void public_admission_keeps_legacy_execution_rejected_before_state_publication(){
    let ir::Program p=program(10,false,1,1,false);good(ref p);var arrays::State a=arrays::empty(0);var slices::State l=slices::empty();var calls::Frames f=calls::empty();var bytes::Buffer b=bytes::empty();
    assert(switch(execution::execute(ref p,0,ref mut a,ref mut b,ref mut l,ref mut f)){case .ok(_):{false}case .err(e):{e.kind==5}});
    assert(switch(vm::run_with_array_limit(ref p,0,0)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(a.owners.depth==0 && a.owners.arena.used==0 && bytes::len(ref b)==0);
    var usize i=0;while(i<16){assert(!l.pool.slots[i].live);i+=1;}good(ref p);
}
