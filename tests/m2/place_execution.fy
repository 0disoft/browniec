module tests::m2::place_execution;
import ir as ir;
import verifier as verifier;
import vm as vm;
import errors as errors;
import static_image as images;
import static_call_ir as calls;
import program_image as programs;
import slice_result_ir as results;
import slice_result_runtime as runtime;
import slice_result_execution as retained;
import array_owners as owners;
import array_slices as slices;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};}
fn void completed(Result<i64,errors::Error> r){assert(switch(r){case .ok(n):{n==42}case .err(_):{false}});}
fn void shortage(Result<i64,errors::Error> r){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==8}});}
fn void finish(ref mut ir::Program p){let usize count=p.count;let usize registers=p.registers;
    p.function_count=1;p.entry=0;p.return_types[0]=1;p.ends[0]=count;p.register_ends[0]=registers;
}
fn ir::Program compound(){
    var ir::Program p=ir::empty();let usize root=built(ir::array(ref mut p,1,2,true,0));
    let usize fill=built(ir::literal(ref mut p,20,0));let usize index=built(ir::integer(ref mut p,0,12,0));
    let usize initialized=built(ir::array_init(ref mut p,root,fill,0));let usize selected=built(ir::place_select(ref mut p,0,root,index,0));
    let usize old=built(ir::place_read(ref mut p,0,root,0));let usize addend=built(ir::literal(ref mut p,22,0));
    let usize result=built(ir::emit(ref mut p,2,old,addend,0));let usize stored=built(ir::place_store(ref mut p,0,root,result,0));
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize observed=built(ir::array_read(ref mut p,root,index,0));
    let usize dropped=built(ir::array_drop(ref mut p,root,0));let usize returned=built(ir::emit(ref mut p,8,observed,0,0));
    finish(ref mut p);return p;
}
fn images::Image image(){var images::Builder b=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    return switch(images::freeze(ref b,images::metadata_charge())){case .ok(v):{v}case .err(_):{assert(false);image()}};
}
fn void public_retained(ref ir::Program p,usize exact){
    let calls::Program code=calls::Program{.body=*p,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    switch(programs::retain_reference_returns(ref code,image(),65536)){
        case .ok(p):{
            shortage(programs::run_public_references(ref p,exact-1));
            completed(programs::run_public_references(ref p,exact));
            completed(programs::run_public_references(ref p,exact+1));
        }case .err(_):{assert(false);}
    };
}
@test fn void ordinary_and_retained_compound_execution_match_independent_exact_fuel(){
    let ir::Program p=compound();assert(verifier::verify(ref p).is_ok);
    // Body=387; backing=9/65537; snapshot setup=3457. Retained adds
    // 147456 entry +196608 leave +7 extra aggregate/place dispatch units.
    shortage(vm::run_with_array_limit(ref p,3852,8));completed(vm::run_with_array_limit(ref p,3853,8));
    completed(vm::run_with_array_limit(ref p,3854,8));shortage(vm::run(ref p,69380));
    completed(vm::run(ref p,69381));completed(vm::run(ref p,69382));public_retained(ref p,413452);
}
@test fn void all_six_domains_store_and_read_the_actual_selected_element(){
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;
    while(i<6){var ir::Program p=ir::empty();let u8 tag=tags[i];let usize root=built(ir::array(ref mut p,tag,2,true,0));
        let usize fill=if(tag==2){built(ir::boolean(ref mut p,false,0))}else{built(ir::integer(ref mut p,0,tag,0))};
        let usize index=built(ir::integer(ref mut p,0,12,0));let usize initialized=built(ir::array_init(ref mut p,root,fill,0));
        let usize selected=built(ir::place_select(ref mut p,0,root,index,0));
        let usize old=built(ir::place_read(ref mut p,0,root,0));
        let usize fresh=if(tag==2){built(ir::boolean(ref mut p,true,0))}else{built(ir::integer(ref mut p,42,tag,0))};
        let usize stored=built(ir::place_store(ref mut p,0,root,fresh,0));let usize ended=built(ir::place_end(ref mut p,0,0));
        let usize read=built(ir::array_read(ref mut p,root,index,0));let usize dropped=built(ir::array_drop(ref mut p,root,0));
        let usize equal=built(ir::emit(ref mut p,11,read,fresh,0));let usize branch=built(ir::raw(ref mut p,20,0,equal,0,0));
        let usize yes=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,yes,0,0));
        let usize no_pc=p.count;let usize patched=built(ir::patch(ref mut p,branch,no_pc,0));
        let usize no=built(ir::literal(ref mut p,0,0));let usize failed=built(ir::emit(ref mut p,8,no,0,0));finish(ref mut p);
        completed(vm::run_with_array_limit(ref p,100000,16));
        let calls::Program code=calls::Program{.body=p,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
        switch(programs::retain_reference_returns(ref code,image(),65536)){
            case .ok(p):{completed(programs::run_public_references(ref p,1000000));}case .err(_):{assert(false);}
        };i+=1;
    }
}
fn ir::Program looped(){
    var ir::Program p=ir::empty();let usize root=built(ir::array(ref mut p,1,2,true,0));
    let usize zero=built(ir::literal(ref mut p,0,0));let usize index=built(ir::integer(ref mut p,0,12,0));
    let usize initialized=built(ir::array_init(ref mut p,root,zero,0));let usize counter=built(ir::slot(ref mut p,1,0));
    let usize initial=built(ir::raw(ref mut p,18,counter,zero,0,0));let usize limit=built(ir::literal(ref mut p,3,0));
    let usize one=built(ir::literal(ref mut p,1,0));let usize begin=p.count;
    let usize selected=built(ir::place_select(ref mut p,0,root,index,0));let usize old=built(ir::place_read(ref mut p,0,root,0));
    let usize next=built(ir::emit(ref mut p,2,old,one,0));let usize stored=built(ir::place_store(ref mut p,0,root,next,0));
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize count=built(ir::emit(ref mut p,17,counter,0,0));
    let usize increment=built(ir::emit(ref mut p,2,count,one,0));let usize assigned=built(ir::raw(ref mut p,18,counter,increment,0,0));
    let usize again=built(ir::emit(ref mut p,13,increment,limit,0));let usize exit=built(ir::raw(ref mut p,20,0,again,0,0));
    let usize back=built(ir::raw(ref mut p,22,0,begin,0,0));let usize after=p.count;let usize patched=built(ir::patch(ref mut p,exit,after,0));
    let usize read=built(ir::array_read(ref mut p,root,index,0));let usize dropped=built(ir::array_drop(ref mut p,root,0));
    let usize fourteen=built(ir::literal(ref mut p,14,0));let usize result=built(ir::emit(ref mut p,4,read,fourteen,0));
    let usize returned=built(ir::emit(ref mut p,8,result,0,0));finish(ref mut p);return p;
}
@test fn void loop_reuse_and_fuel_abort_drain_invocation_owners_without_replay(){
    let ir::Program p=looped();assert(verifier::verify(ref p).is_ok);completed(vm::run_with_array_limit(ref p,100000,8));
    let results::Program code=results::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
    var runtime::State state=runtime::empty(8);var u8[8] data=[85;8];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    assert(switch(retained::execute_scalar(ref code,0,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,151057)){
        case .ok(_):{false}case .err(e):{e.kind==8}
    });assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    assert(switch(retained::execute_scalar(ref code,0,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,1000000)){
        case .ok(v):{v.value==42}case .err(_):{false}
    });assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
}
@test fn void readonly_mutations_and_missing_end_still_fail_before_runtime_preparation(){
    var ir::Program p=compound();p.arrays.mutable[0]=false;
    assert(switch(vm::run_with_array_limit(ref p,0,0)){case .ok(_):{false}case .err(e):{e.kind==5}});
    p=compound();p.code[8*8]=19;p.code[8*8+1]=0;p.code[8*8+2]=9;p.code[8*8+3]=0;
    assert(switch(vm::run_with_array_limit(ref p,0,0)){case .ok(_):{false}case .err(e):{e.kind==5}});
}
