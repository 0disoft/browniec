module tests::m2::place_cleanup;
import ir as ir;
import locals as locals;
import place_source as places;
import array_source as arrays;
import array_result_source as array_results;
import struct_result_source as records;
import propagation as propagation;
import errors as errors;
import verifier as verifier;
import vm as vm;
import static_image as images;
import static_call_ir as calls;
import program_image as programs;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void completed(Result<i64,errors::Error> r){assert(switch(r){case .ok(v):{v==42}case .err(_):{false}});}
fn void seed(ref mut ir::Program p,ref mut locals::Table names,i64 value){
    let usize root=built(ir::array(p,1,1,true,0));
    let usize fill=built(ir::literal(p,value,0));let usize index=built(ir::integer(p,0,12,0));
    let usize initialized=built(ir::array_init(p,root,fill,0));
    let usize bound=built(locals::declare(names,0,0,128+root,true));
}
fn void finish(ref mut ir::Program p){let usize count=p.count;let usize registers=p.registers;
    p.function_count=1;p.entry=0;p.return_types[0]=1;p.ends[0]=count;p.register_ends[0]=registers;
}
fn images::Image image(){var images::Builder b=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    return switch(images::freeze(ref b,images::metadata_charge())){case .ok(v):{v}case .err(_):{assert(false);image()}};
}
fn void retained(ref ir::Program p){
    let calls::Program code=calls::Program{.body=*p,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    switch(programs::retain_reference_returns(ref code,image(),65536)){
        case .ok(p):{completed(programs::run_public_references(ref p,16000000));}
        case .err(_):{assert(false);}
    };
}
fn void both(ref ir::Program p){assert(verifier::verify(p).is_ok);
    completed(vm::run_with_array_limit(p,1000000,16));retained(p);
}
@test fn void sixteen_pending_places_preserve_all_sixty_four_bindings_and_allow_id_reuse(){
    var ir::Program p=ir::empty();var locals::Table names=locals::empty();seed(ref mut p,ref mut names,42);
    while(names.count<64){let usize bound=built(locals::declare(ref mut names,0,0,0,false));}
    var usize id=0;while(id<16){assert(built(places::select(ref mut p,ref mut names,0,1,0))==id);id+=1;}
    let usize before=p.count;
    assert(switch(places::select(ref mut p,ref mut names,0,1,17)){case .ok(_):{false}case .err(e):{e.kind==4 && e.offset==17}});
    assert(p.count==before && p.registers==2 && names.count==64 && names.pending_places==65535);
    let locals::Table copy=locals::snapshot(ref names);assert(copy.pending_places==65535);
    let usize ended=built(places::end(ref mut p,ref mut names,7,0));
    assert(built(places::select(ref mut p,ref mut names,0,1,0))==7);
    let usize exit_pc=p.count;assert(built(arrays::release_visible(ref names,ref mut p,0))==17);
    assert(names.pending_places==65535 && p.code[exit_pc*8]==86 && p.code[(exit_pc+15)*8+1]==0);
    assert(p.code[(exit_pc+16)*8]==37);
    let usize returned=built(ir::emit(ref mut p,8,0,0,0));finish(ref mut p);both(ref p);
}
@test fn void loop_transfer_keeps_surrounding_selection_when_binding_counts_are_identical(){
    var ir::Program p=ir::empty();var locals::Table outer=locals::empty();seed(ref mut p,ref mut outer,20);
    assert(built(places::select(ref mut p,ref mut outer,0,1,0))==0);
    let usize old=built(ir::place_read(ref mut p,0,0,0));
    let usize scope=places::scope(ref outer);assert(scope==129);
    var locals::Table inner=locals::snapshot(ref outer);
    assert(built(places::select(ref mut p,ref mut inner,0,1,0))==1);
    let usize exit_pc=p.count;let usize first=built(places::leave_loop(ref inner,ref mut p,scope,0));
    assert(first==1 && inner.pending_places==3 && p.count==exit_pc+1 && p.code[exit_pc*8+1]==1);
    assert(built(arrays::release_from(ref inner,ref mut p,first,0))==0);
    let usize extra=built(ir::literal(ref mut p,22,0));let usize value=built(ir::emit(ref mut p,2,old,extra,0));
    let usize stored=built(ir::place_store(ref mut p,0,0,value,0));
    let usize ended=built(places::end(ref mut p,ref mut outer,0,0));
    let usize observed=built(ir::array_read(ref mut p,0,1,0));
    let usize dropped=built(arrays::release_visible(ref outer,ref mut p,0));
    let usize returned=built(ir::emit(ref mut p,8,observed,0,0));finish(ref mut p);both(ref p);
}
fn ir::Program aggregate(bool record){
    var ir::Program p=ir::empty();var locals::Table names=locals::empty();seed(ref mut p,ref mut names,42);
    let usize selected=built(places::select(ref mut p,ref mut names,0,1,0));
    if(record){p.records.layouts.count=1;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=1;
        let usize root=built(ir::record_in(ref mut p,0,0,false,0));
        let usize initialized=built(ir::record_init(ref mut p,root,0,0));
        let usize bound=built(locals::declare(ref mut names,0,0,144+root,false));p.record_results[0]=1;
        let usize exit_pc=p.count;let usize returned=built(records::finish(ref mut p,ref names,root,0));
        assert(p.code[exit_pc*8]==86 && p.code[(exit_pc+1)*8]==37 && p.code[(p.count-1)*8]==50);
    }else{p.array_results[0]=1;p.return_types[0]=1;let usize exit_pc=p.count;
        let usize returned=built(array_results::finish(ref mut p,ref names,0,0));
        assert(p.code[exit_pc*8]==86 && p.code[(exit_pc+1)*8]==39);
    }
    let usize end=p.count;let usize registers=p.registers;
    p.function_count=2;p.entry=1;p.ends[0]=end;p.register_ends[0]=registers;
    p.starts[1]=end;p.register_starts[1]=registers;p.return_types[1]=1;
    let usize[1] none=[0];var usize observed=0;
    if(record){let usize root=built(ir::record_in(ref mut p,1,0,false,0));
        let usize called=built(ir::record_call(ref mut p,0,root,ref none[..0],0));
        observed=built(ir::record_read(ref mut p,root,0,0));let usize dropped=built(ir::record_drop(ref mut p,root,0));
    }else{let usize root=built(ir::array_in(ref mut p,1,1,1,false,0));
        let usize called=built(ir::array_call(ref mut p,0,root,ref none[..0],0));
        let usize index=built(ir::integer(ref mut p,0,12,0));observed=built(ir::array_read(ref mut p,root,index,0));
        let usize dropped=built(ir::array_drop(ref mut p,root,0));
    }
    let usize returned=built(ir::emit(ref mut p,8,observed,0,0));let usize count=p.count;let usize total=p.registers;
    p.ends[1]=count;p.register_ends[1]=total;return p;
}
@test fn void array_and_record_handoffs_end_pending_places_before_drops_and_promotion(){
    let ir::Program a=aggregate(false);both(ref a);let ir::Program r=aggregate(true);both(ref r);
}
fn ir::Program propagated(bool some){
    var ir::Program p=ir::empty();var locals::Table names=locals::empty();seed(ref mut p,ref mut names,42);
    let usize selected=built(places::select(ref mut p,ref mut names,0,1,0));
    let usize old=built(ir::place_read(ref mut p,0,0,0));
    let usize subject=built(ir::construct(ref mut p,3,if(some){1}else{0},0,0));
    let usize value=built(propagation::lower(ref mut p,ref names,subject,3,0));
    assert(names.pending_places==1);
    let usize stored=built(ir::place_store(ref mut p,0,0,value,0));let usize ended=built(places::end(ref mut p,ref mut names,0,0));
    let usize dropped=built(arrays::release_visible(ref names,ref mut p,0));
    let usize result=built(ir::construct(ref mut p,3,1,value,0));let usize returned=built(ir::emit(ref mut p,8,result,0,0));
    let usize end=p.count;let usize registers=p.registers;
    p.function_count=2;p.entry=1;p.return_types[0]=3;p.ends[0]=end;p.register_ends[0]=registers;
    p.starts[1]=end;p.register_starts[1]=registers;p.return_types[1]=1;
    let usize[1] none=[0];let usize called=built(ir::call(ref mut p,0,ref none[..0],0));
    let ir::Case branch=switch(ir::branch_case(ref mut p,called,1,0)){case .ok(v):{v}case .err(_):{assert(false);return propagated(some);}};
    let usize success=built(ir::emit(ref mut p,8,branch.payload,0,0));let usize target=p.count;
    let usize patched=built(ir::patch(ref mut p,branch.instruction,target,0));
    let usize fallback=built(ir::literal(ref mut p,42,0));let usize failure=built(ir::emit(ref mut p,8,fallback,0,0));
    let usize count=p.count;let usize total=p.registers;p.ends[1]=count;p.register_ends[1]=total;return p;
}
@test fn void propagation_failure_abandons_selection_and_success_keeps_it_for_store(){
    let ir::Program a=propagated(false);both(ref a);let ir::Program b=propagated(true);both(ref b);
}
@test fn void invalid_scope_masks_and_dead_ends_fail_before_emitting_cleanup(){
    var ir::Program p=ir::empty();var locals::Table names=locals::empty();seed(ref mut p,ref mut names,42);
    let usize before=p.count;
    assert(!places::end(ref mut p,ref mut names,0,0).is_ok);
    assert(!places::select(ref mut p,ref mut names,16,1,0).is_ok);
    assert(!places::release(ref names,ref mut p,1,0).is_ok);
    assert(!places::leave_loop(ref names,ref mut p,65,0).is_ok);
    assert(!places::leave_loop(ref names,ref mut p,129,0).is_ok);
    assert(p.count==before && names.pending_places==0 && names.count==1);
}
