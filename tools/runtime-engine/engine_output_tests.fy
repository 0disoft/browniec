module engine_output_tests;
import runtime_engine as engine;
import module_output_program as programs;
import module_entry as entries;
import module_input_entry as input_entries;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import runtime_input as inputs;
import std::bytes as bytes;
unsafe extern C fn void bc_runtime_engine_test_seed(ptr mut void e,u32 kind);
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
unsafe extern C fn void bc_runtime_engine_test_closed_allocations();

// No recursive fixture fallbacks: construction failures must not masquerade as
// native stack exhaustion. Each group owns and drops its complete fixture.
fn Result<modules::Index,u8> indexed(ref u8[] source){
    var sources::Builder builder=switch(sources::builder(4096,4096)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    if(!sources::add(ref mut builder,b"app.brc",source).is_ok){return .err(2);}
    let sources::Snapshot snapshot=switch(sources::freeze(ref builder)){
        case .ok(v):{v}case .err(_):{return .err(3);}
    };
    return switch(modules::build(snapshot)){case .ok(v):{.ok(v)}case .err(_):{.err(4)}};
}
fn Result<entries::Entry,u8> selected(ref u8[] source){
    return switch(entries::select_i32(indexed(source)?,b"app",b"chosen")){
        case .ok(v):{.ok(v)}case .err(_):{.err(5)}
    };
}
fn Result<input_entries::InputEntry,u8> selected_input(ref u8[] source){
    return switch(input_entries::select_i32_input(indexed(source)?,b"app",b"chosen")){
        case .ok(v):{.ok(v)}case .err(_):{.err(6)}
    };
}
fn Result<engine::Engine,engine::Error> created(usize programs,usize instances){
    return engine::create(engine::Limits{.programs=programs,.instances=instances,.fuel=16000000});
}
fn usize id(Result<usize,engine::Error> result){
    return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn usize code(ref mut engine::Engine e,ref u8[] source){
    let entries::Entry entry=switch(selected(source)){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}
    };
    return id(engine::compile_output(e,entry,65536));
}
fn usize input_code(ref mut engine::Engine e,ref u8[] source){
    let input_entries::InputEntry entry=switch(selected_input(source)){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}
    };
    return id(engine::compile_input_output(e,entry,65536));
}
fn Result<inputs::Snapshot,inputs::Error> captured(ref u8[] data){
    var usize budget=11;
    return inputs::snapshot(data,inputs::hard_limit(),1,ref mut budget);
}
fn usize bound(ref mut engine::Engine e,usize p,ref u8[] data,usize budget,usize limit,bool allowed){
    let inputs::Snapshot input=switch(captured(data)){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}
    };
    return id(engine::create_input_output_instance(e,p,input,budget,limit,allowed));
}
fn diagnostics::Error absent(){return diagnostics::absent(errors::make(0,0));}
fn engine::Event event(Result<engine::Event,engine::Error> result){
    return switch(result){
        case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,
            .diagnostic=absent(),.remaining=0,.fuel_known=false}}
    };
}
fn void rejected(Result<usize,engine::Error> result,u32 status){
    switch(result){case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}};
}
fn void rejected_event(Result<engine::Event,engine::Error> result,u32 status){
    switch(result){case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}};
}
fn void rejected_take(Result<engine::Output,engine::Error> result,u32 status){
    switch(result){case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}};
}
fn void counts(ref mut engine::Engine e,usize programs,usize instances,usize pins){
    switch(engine::inspect(e)){
        case .ok(v):{assert(v.programs==programs && v.instances==instances && v.pins==pins && !v.closed);}
        case .err(_):{assert(false);}
    };
}
fn void same_diagnostic(diagnostics::Error a,diagnostics::Error b){
    assert(a.code.kind==b.code.kind && a.code.offset==b.code.offset);
    assert(a.at.source==b.at.source && a.at.start==b.at.start && a.at.end==b.at.end);
}
fn void same_event(engine::Event a,engine::Event b){
    assert(a.kind==b.kind && a.value==b.value && a.remaining==b.remaining && a.fuel_known==b.fuel_known);
    same_diagnostic(a.diagnostic,b.diagnostic);
}
fn void mapped(ref engine::Output output,engine::Event terminal){
    let programs::Completion completed=engine::output_completion(output);
    assert(terminal.kind==if(completed.success){1}else{2});
    assert(terminal.value==completed.value && terminal.fuel_known && terminal.remaining==completed.remaining);
    same_diagnostic(terminal.diagnostic,completed.diagnostic);
}
fn void published(ref engine::Output output,ref u8[] expected,usize emits){
    let programs::Completion completed=engine::output_completion(output);
    assert(completed.success && completed.value==42 && completed.diagnostic.code.kind==0);
    assert(completed.output_bytes==expected.len && completed.emits==emits && engine::output_available(output));
    assert(bytes::equal(engine::output_view(output),expected));
    assert(bytes::equal(engine::output_view(output),expected));
    assert(engine::output_completion(output).remaining==completed.remaining);
}
fn void unpublished(ref engine::Output output,u8 kind,usize emits){
    let programs::Completion completed=engine::output_completion(output);
    assert(!completed.success && completed.value==0 && completed.diagnostic.code.kind==kind);
    assert(completed.output_bytes==0 && completed.emits==emits && !engine::output_available(output));
    assert(engine::output_view(output).len==0);
}

// Group 1: Ready rejection, one-shot transfer, unchanged terminal Event, then
// a complete owning return across Instance, Program and Engine destruction.
fn Result<engine::Output,engine::Error> detached_success(){
    var engine::Engine e=created(1,1)?;
    let usize p=code(ref mut e,b"module app;pub fn i32 chosen(){output::emit(ref b\"A\\x00\\xFF\");return 42;}");
    let usize i=id(engine::create_output_instance(ref mut e,p,16000000,3,true));
    let engine::Event ready=event(engine::observe(ref mut e,i));
    rejected_take(engine::take_output(ref mut e,i),11);
    same_event(ready,event(engine::observe(ref mut e,i)));
    let engine::Event done=event(engine::execute_once(ref mut e,i));
    let engine::Output output=engine::take_output(ref mut e,i)?;
    published(ref output,b"A\x00\xFF",1);mapped(ref output,done);
    assert(done.remaining>0 && done.remaining<16000000);
    rejected_take(engine::take_output(ref mut e,i),2);
    same_event(done,event(engine::observe(ref mut e,i)));
    same_event(done,event(engine::cancel_ready(ref mut e,i)));
    rejected_event(engine::execute_once(ref mut e,i),11);
    assert(id(engine::release_program(ref mut e,p))==p);
    assert(id(engine::destroy_instance(ref mut e,i))==i);
    rejected_take(engine::take_output(ref mut e,i),2);
    counts(ref mut e,0,0,0);assert(id(engine::destroy(ref mut e))==0);
    published(ref output,b"A\x00\xFF",1);return .ok(output);
}
fn void take_once_and_detached_lifetime(){
    let engine::Output output=switch(detached_success()){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    // detached_success's Engine owner and all its vectors have left scope.
    published(ref output,b"A\x00\xFF",1);
}

// Group 2: existing Instance creation is deny/zero; explicit grant changes only
// this invocation. No-emit completion remains valid without any output grant.
fn void default_denial_explicit_grant_and_noemit(){
    var engine::Engine e=switch(created(2,3)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize p=code(ref mut e,b"module app;pub fn i32 chosen(){output::emit(ref b\"*\");return 42;}");
    let usize q=code(ref mut e,b"module app;pub fn i32 chosen(){return 42;}");
    let usize denied=id(engine::create_instance(ref mut e,p,16000000));
    let usize allowed=id(engine::create_output_instance(ref mut e,p,16000000,1,true));
    let usize quiet=id(engine::create_instance(ref mut e,q,16000000));
    let engine::Event denial=event(engine::execute_once(ref mut e,denied));
    let engine::Event grant=event(engine::execute_once(ref mut e,allowed));
    let engine::Event silent=event(engine::execute_once(ref mut e,quiet));
    let engine::Output d=switch(engine::take_output(ref mut e,denied)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let engine::Output a=switch(engine::take_output(ref mut e,allowed)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let engine::Output n=switch(engine::take_output(ref mut e,quiet)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    unpublished(ref d,19,0);published(ref a,b"*",1);published(ref n,b"",0);
    mapped(ref d,denial);mapped(ref a,grant);mapped(ref n,silent);
    same_event(denial,event(engine::observe(ref mut e,denied)));
    same_event(grant,event(engine::observe(ref mut e,allowed)));
    same_event(silent,event(engine::observe(ref mut e,quiet)));
    assert(id(engine::release_program(ref mut e,p))==p);assert(id(engine::release_program(ref mut e,q))==q);
    assert(id(engine::destroy_instance(ref mut e,denied))==denied);
    assert(id(engine::destroy_instance(ref mut e,allowed))==allowed);
    assert(id(engine::destroy_instance(ref mut e,quiet))==quiet);
    counts(ref mut e,0,0,0);assert(id(engine::destroy(ref mut e))==0);
    unpublished(ref d,19,0);published(ref a,b"*",1);published(ref n,b"",0);
}

// Group 3: input bytes move into the Instance; releasing its Program and moving
// the Engine must preserve both that input pin and a detached binary output.
fn void moved_input_released_pin_and_engine_move(){
    var engine::Engine original=switch(created(1,1)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize p=input_code(ref mut original,b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}");
    var bytes::Buffer backing=switch(bytes::copy(b"\x00\xFF\x00")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let inputs::Snapshot input=switch(captured(bytes::view(ref backing))){case .ok(v):{v}case .err(_):{assert(false);return;}};
    bytes::view_mut(ref mut backing)[1]=1;assert(bytes::resize_zeroed(ref mut backing,0).is_ok);
    let usize i=id(engine::create_input_output_instance(ref mut original,p,input,16000000,3,true));
    assert(id(engine::release_program(ref mut original,p))==p);
    rejected(engine::create_output_instance(ref mut original,p,1,0,false),2);
    var engine::Engine moved=original;counts(ref mut moved,1,1,1);
    let engine::Event done=event(engine::execute_once(ref mut moved,i));
    let engine::Output output=switch(engine::take_output(ref mut moved,i)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    published(ref output,b"\x00\xFF\x00",1);mapped(ref output,done);
    same_event(done,event(engine::observe(ref mut moved,i)));
    assert(id(engine::destroy_instance(ref mut moved,i))==i);counts(ref mut moved,0,0,0);
    rejected(engine::release_program(ref mut moved,p),2);assert(id(engine::destroy(ref mut moved))==0);
    published(ref output,b"\x00\xFF\x00",1);
}

// Group 4: taking a middle record and destroying an untaken front record both
// relocate peers through scratch storage, without switching any output owner.
fn void middle_and_front_record_removal_preserves_peers(){
    var engine::Engine e=switch(created(1,4)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize p=input_code(ref mut e,b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}");
    let usize a=bound(ref mut e,p,b"A\x00",16000000,2,true);
    let usize b=bound(ref mut e,p,b"B\x01",16000000,2,true);
    let usize c=bound(ref mut e,p,b"C\x02",16000000,2,true);
    let usize d=bound(ref mut e,p,b"D\x03",16000000,2,true);
    let engine::Event ea=event(engine::execute_once(ref mut e,a));
    let engine::Event eb=event(engine::execute_once(ref mut e,b));
    let engine::Event ec=event(engine::execute_once(ref mut e,c));
    let engine::Event ed=event(engine::execute_once(ref mut e,d));
    assert(ea.kind==1);assert(id(engine::release_program(ref mut e,p))==p);
    let engine::Output middle=switch(engine::take_output(ref mut e,b)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    published(ref middle,b"B\x01",1);mapped(ref middle,eb);
    assert(id(engine::destroy_instance(ref mut e,a))==a);counts(ref mut e,1,3,3);
    rejected_take(engine::take_output(ref mut e,a),2);rejected_take(engine::take_output(ref mut e,b),2);
    same_event(ec,event(engine::observe(ref mut e,c)));same_event(ed,event(engine::observe(ref mut e,d)));
    let engine::Output tail=switch(engine::take_output(ref mut e,d)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let engine::Output front=switch(engine::take_output(ref mut e,c)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    published(ref tail,b"D\x03",1);mapped(ref tail,ed);published(ref front,b"C\x02",1);mapped(ref front,ec);
    assert(id(engine::destroy_instance(ref mut e,b))==b);assert(id(engine::destroy_instance(ref mut e,c))==c);
    assert(id(engine::destroy_instance(ref mut e,d))==d);counts(ref mut e,0,0,0);assert(id(engine::destroy(ref mut e))==0);
    published(ref middle,b"B\x01",1);published(ref tail,b"D\x03",1);published(ref front,b"C\x02",1);
}

// Group 5: failed VM completion is transferable but carries no prefix. A Ready
// cancellation creates no completion owner at all, and preserves its budget.
fn void failed_prefix_and_cancelled_absence(){
    var engine::Engine e=switch(created(1,2)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize p=input_code(ref mut e,b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"prefix\");return 42/(data[0] as i32);}");
    let usize failed=bound(ref mut e,p,b"\x00",16000000,6,true);
    let usize cancelled=bound(ref mut e,p,b"\x01",123,6,true);
    rejected_take(engine::take_output(ref mut e,cancelled),11);
    let engine::Event failure=event(engine::execute_once(ref mut e,failed));
    assert(failure.kind==2 && failure.diagnostic.code.kind==7 && failure.remaining>0 && failure.remaining<16000000);
    let engine::Output output=switch(engine::take_output(ref mut e,failed)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    unpublished(ref output,7,1);mapped(ref output,failure);
    rejected_take(engine::take_output(ref mut e,failed),2);
    same_event(failure,event(engine::observe(ref mut e,failed)));
    let engine::Event stopped=event(engine::cancel_ready(ref mut e,cancelled));
    assert(stopped.kind==3 && stopped.remaining==123 && stopped.fuel_known);
    rejected_take(engine::take_output(ref mut e,cancelled),2);
    same_event(stopped,event(engine::observe(ref mut e,cancelled)));
    rejected_event(engine::execute_once(ref mut e,cancelled),11);
    assert(id(engine::release_program(ref mut e,p))==p);assert(id(engine::destroy_instance(ref mut e,failed))==failed);
    assert(id(engine::destroy_instance(ref mut e,cancelled))==cancelled);assert(id(engine::destroy(ref mut e))==0);
    unpublished(ref output,7,1);
}

// Group 6: extraction is owner maintenance and remains available after the
// final admission epoch, although creating or executing new work is rejected.
fn void take_after_admission_exhaustion(){
    var engine::Engine e=switch(created(1,2)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize p=code(ref mut e,b"module app;pub fn i32 chosen(){output::emit(ref b\"done\");return 42;}");
    let usize done=id(engine::create_output_instance(ref mut e,p,16000000,4,true));
    let usize pending=id(engine::create_output_instance(ref mut e,p,123,4,true));
    let engine::Event terminal=event(engine::execute_once(ref mut e,done));
    unsafe{bc_runtime_engine_test_seed(ref mut e as ptr mut void,2)};
    counts(ref mut e,1,2,2); // Consumes the last epoch.
    rejected(engine::create_output_instance(ref mut e,p,1,0,false),8);
    rejected_event(engine::execute_once(ref mut e,pending),8);
    let engine::Output output=switch(engine::take_output(ref mut e,done)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    published(ref output,b"done",1);mapped(ref output,terminal);
    same_event(terminal,event(engine::observe(ref mut e,done)));
    rejected_take(engine::take_output(ref mut e,done),2);
    rejected_take(engine::take_output(ref mut e,pending),11);
    let engine::Event stopped=event(engine::cancel_ready(ref mut e,pending));assert(stopped.kind==3 && stopped.remaining==123);
    rejected_take(engine::take_output(ref mut e,pending),2);
    assert(id(engine::release_program(ref mut e,p))==p);assert(id(engine::destroy_instance(ref mut e,done))==done);
    assert(id(engine::destroy_instance(ref mut e,pending))==pending);counts(ref mut e,0,0,0);assert(id(engine::destroy(ref mut e))==0);
    published(ref output,b"done",1);
}

// Group 7: fail the outgoing one-slot preparation, restore the allocator before
// asserting, then prove the terminal record and all peer bytes still exist.
fn void take_preparation_allocation_failure_preserves_state(){
    var engine::Engine e=switch(created(1,2)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize p=input_code(ref mut e,b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}");
    let usize a=bound(ref mut e,p,b"A\x00",16000000,2,true);
    let usize b=bound(ref mut e,p,b"B\xFF",16000000,2,true);
    let engine::Event ea=event(engine::execute_once(ref mut e,a));
    let engine::Event eb=event(engine::execute_once(ref mut e,b));
    unsafe{bc_runtime_engine_test_fail(0)};
    let Result<engine::Output,engine::Error> failed=engine::take_output(ref mut e,a);
    unsafe{bc_runtime_engine_test_fail(-1)};
    rejected_take(failed,6);counts(ref mut e,1,2,2);
    same_event(ea,event(engine::observe(ref mut e,a)));same_event(eb,event(engine::observe(ref mut e,b)));
    let engine::Output first=switch(engine::take_output(ref mut e,a)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let engine::Output second=switch(engine::take_output(ref mut e,b)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    published(ref first,b"A\x00",1);mapped(ref first,ea);published(ref second,b"B\xFF",1);mapped(ref second,eb);
    rejected_take(engine::take_output(ref mut e,a),2);rejected_take(engine::take_output(ref mut e,b),2);
    same_event(ea,event(engine::observe(ref mut e,a)));same_event(eb,event(engine::observe(ref mut e,b)));
    assert(id(engine::release_program(ref mut e,p))==p);assert(id(engine::destroy_instance(ref mut e,a))==a);
    assert(id(engine::destroy_instance(ref mut e,b))==b);assert(id(engine::destroy(ref mut e))==0);
    published(ref first,b"A\x00",1);published(ref second,b"B\xFF",1);
}

// Group 8: leave a released pinned Program, Ready owned input, untaken success,
// untaken failure and a detached Output to ordinary owning scope cleanup.
fn void implicit_owning_cleanup(){
    var engine::Engine e=switch(created(1,4)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize p=input_code(ref mut e,b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42/(data[0] as i32);}");
    let usize ready=bound(ref mut e,p,b"\x01\x00",123,2,true);
    let usize taken=bound(ref mut e,p,b"\x01T",16000000,2,true);
    let usize untaken=bound(ref mut e,p,b"\x01U",16000000,2,true);
    let usize failed=bound(ref mut e,p,b"\x00F",16000000,2,true);
    assert(event(engine::execute_once(ref mut e,taken)).kind==1);
    assert(event(engine::execute_once(ref mut e,untaken)).kind==1);
    assert(event(engine::execute_once(ref mut e,failed)).kind==2);
    let engine::Output output=switch(engine::take_output(ref mut e,taken)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    published(ref output,b"\x01T",1);assert(id(engine::release_program(ref mut e,p))==p);
    counts(ref mut e,1,4,4);assert(event(engine::observe(ref mut e,ready)).kind==0);
    // No explicit destroy or take of the remaining records.
}

pub fn void run(){
    take_once_and_detached_lifetime();unsafe{bc_runtime_engine_test_closed_allocations()};
    default_denial_explicit_grant_and_noemit();unsafe{bc_runtime_engine_test_closed_allocations()};
    moved_input_released_pin_and_engine_move();unsafe{bc_runtime_engine_test_closed_allocations()};
    middle_and_front_record_removal_preserves_peers();unsafe{bc_runtime_engine_test_closed_allocations()};
    failed_prefix_and_cancelled_absence();unsafe{bc_runtime_engine_test_closed_allocations()};
    take_after_admission_exhaustion();unsafe{bc_runtime_engine_test_closed_allocations()};
    take_preparation_allocation_failure_preserves_state();unsafe{bc_runtime_engine_test_closed_allocations()};
    implicit_owning_cleanup();unsafe{bc_runtime_engine_test_closed_allocations()};
}
