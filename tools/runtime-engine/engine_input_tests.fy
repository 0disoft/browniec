module engine_input_tests;
import runtime_engine as engine;
import module_input_program as programs;
import module_input_entry as entries;
import module_entry as ordinary;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import runtime_input as inputs;
import runtime_input_adoption as os_input;
import std::bytes as bytes;
unsafe extern C fn void bc_runtime_engine_test_seed(ptr mut void e,u32 kind);
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
unsafe extern C fn void bc_runtime_engine_test_closed_allocations();
unsafe extern C fn usize bc_runtime_engine_test_input_open(u32 kind,usize length);
unsafe extern C fn void bc_runtime_engine_test_input_close();
unsafe extern C fn void bc_runtime_engine_test_input_measure();
unsafe extern C fn void bc_runtime_engine_test_inject_input_fault(u32 stage);
unsafe extern C fn usize probe_attempts();
unsafe extern C fn usize probe_live_bytes();

fn sources::Builder builder(){return switch(sources::builder(4096,4096)){
    case .ok(v):{v}case .err(_):{assert(false);builder()}
};}
fn modules::Index index(ref u8[] a,ref u8[] b){
    var sources::Builder scratch=builder();assert(sources::add(ref mut scratch,b"library",a).is_ok);
    if(b.len!=0){assert(sources::add(ref mut scratch,b"application",b).is_ok);}
    let sources::Snapshot snapshot=switch(sources::freeze(ref scratch)){
        case .ok(v):{v}case .err(_):{assert(false);return index(a,b);}
    };
    return switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);index(a,b)}};
}
fn entries::InputEntry entry(ref u8[] a,ref u8[] b){
    return switch(entries::select_i32_input(index(a,b),b"app",b"chosen")){
        case .ok(v):{v}case .err(_):{assert(false);entry(a,b)}
    };
}
fn ordinary::Entry plain(ref u8[] source){return switch(ordinary::select_i32(index(source,b""),b"app",b"chosen")){
    case .ok(v):{v}case .err(_):{assert(false);plain(source)}
};}
fn programs::Program kept(ref u8[] a,ref u8[] b){return switch(programs::compile(entry(a,b),65536)){
    case .ok(v):{v}case .err(_):{assert(false);kept(a,b)}
};}
fn engine::Engine create(usize programs,usize instances){return switch(engine::create(engine::Limits{
    .programs=programs,.instances=instances,.fuel=16000000})){
    case .ok(v):{v}case .err(_):{assert(false);create(programs,instances)}
};}
fn usize id(Result<usize,engine::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn engine::Event event(Result<engine::Event,engine::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,
        .diagnostic=diagnostics::absent(errors::make(0,0)),.remaining=0,.fuel_known=false}}
};}
fn void rejected(Result<usize,engine::Error> result,u32 status){switch(result){
    case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}
};}
fn void rejected_event(Result<engine::Event,engine::Error> result,u32 status){switch(result){
    case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}
};}
fn void counts(ref mut engine::Engine e,usize programs,usize instances,usize pins){switch(engine::inspect(e)){
    case .ok(v):{assert(v.programs==programs && v.instances==instances && v.pins==pins && !v.closed);}
    case .err(_):{assert(false);}
};}
fn void same_diagnostic(diagnostics::Error a,diagnostics::Error b){
    assert(a.code.kind==b.code.kind && a.code.offset==b.code.offset);
    assert(a.at.source==b.at.source && a.at.start==b.at.start && a.at.end==b.at.end);
}
fn void same_event(engine::Event a,engine::Event b){
    assert(a.kind==b.kind && a.value==b.value && a.remaining==b.remaining && a.fuel_known==b.fuel_known);
    same_diagnostic(a.diagnostic,b.diagnostic);
}
fn bytes::Buffer backing(usize length){
    var bytes::Buffer data=switch(bytes::with_capacity(length)){
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    assert(bytes::resize_zeroed(ref mut data,length).is_ok);return data;
}
fn inputs::Snapshot captured(ref u8[] data){
    var usize budget=11;return switch(inputs::snapshot(data,inputs::hard_limit(),1,ref mut budget)){
        case .ok(v):{assert(budget==10);v}case .err(_):{assert(false);captured(data)}
    };
}
fn inputs::Snapshot detached_binary(){
    var bytes::Buffer data=backing(3);bytes::view_mut(ref mut data)[1]=255;
    let inputs::Snapshot input=captured(bytes::view(ref data));
    bytes::view_mut(ref mut data)[1]=1;assert(bytes::resize_zeroed(ref mut data,0).is_ok);return input;
}
// Compare both the legacy standalone Result and the accounted completion. The
// latter exposes the exact failure remainder without guessing an opcode price.
fn engine::Event matches(ref mut engine::Engine e,usize instance,ref programs::Program standalone,
    ref inputs::Snapshot input,usize budget){
    let programs::Completion direct=programs::complete(standalone,input,budget);
    let engine::Event actual=event(engine::execute_input_once(e,instance,input));
    assert(actual.kind==if(direct.success){1}else{2});
    assert(actual.value==direct.value && actual.fuel_known && actual.remaining==direct.remaining);
    same_diagnostic(actual.diagnostic,direct.diagnostic);
    switch(programs::run(standalone,input,budget)){
        case .ok(v):{assert(actual.kind==1 && actual.value==v.value && actual.remaining==v.remaining);}
        case .err(d):{assert(actual.kind==2);same_diagnostic(actual.diagnostic,d);}
    };
    same_event(actual,event(engine::observe(e,instance)));return actual;
}

fn void binary_reuse(){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){if(data.len!=3){return -1;}return 3+data[0] as i32+data[1] as i32+data[data.len-1] as i32;}";
    let programs::Program standalone=kept(source,b"");var engine::Engine e=create(1,3);
    let usize p=id(engine::compile_input(ref mut e,entry(source,b""),65536));
    let usize a=id(engine::create_instance(ref mut e,p,16000000));
    let usize b=id(engine::create_instance(ref mut e,p,16000000));
    let usize again=id(engine::create_instance(ref mut e,p,16000000));counts(ref mut e,1,3,3);
    {
        let inputs::Snapshot first=detached_binary();let inputs::Snapshot second=captured(b"*\x00\x01");
        assert(matches(ref mut e,a,ref standalone,ref first,16000000).value==258);
        assert(matches(ref mut e,b,ref standalone,ref second,16000000).value==46);
        assert(matches(ref mut e,again,ref standalone,ref first,16000000).value==258);
        assert(bytes::equal(inputs::view(ref first),b"\x00\xFF\x00"));
        assert(bytes::equal(inputs::view(ref second),b"*\x00\x01"));
        rejected_event(engine::execute_input_once(ref mut e,a,ref second),11);
    }
    // Completed events outlive both borrowed Snapshots and retain scalar data only.
    let engine::Event completed=event(engine::observe(ref mut e,a));assert(completed.value==258 && completed.fuel_known);
    same_event(completed,event(engine::cancel_ready(ref mut e,a)));
    assert(id(engine::release_program(ref mut e,p))==p);
    assert(id(engine::destroy_instance(ref mut e,b))==b);assert(id(engine::destroy_instance(ref mut e,a))==a);
    counts(ref mut e,1,1,1);assert(id(engine::destroy_instance(ref mut e,again))==again);
    counts(ref mut e,0,0,0);assert(id(engine::destroy(ref mut e))==0);
}
fn void length_case(ref mut engine::Engine e,usize p,ref programs::Program standalone,usize length,i64 expected){
    var bytes::Buffer data=backing(length);if(length!=0){bytes::view_mut(ref mut data)[length-1]=255;}
    let inputs::Snapshot input=captured(bytes::view(ref data));let usize instance=id(engine::create_instance(e,p,16000000));
    assert(matches(e,instance,standalone,ref input,16000000).value==expected);
    assert(inputs::observe(ref input).length==length);assert(id(engine::destroy_instance(e,instance))==instance);
}
fn void full_length_and_last_byte(){
    let ref u8[] library=b"module lib;pub fn i32 unused(){return 9;}";
    let ref u8[] application=b"module app;pub fn i32 chosen(ref u8[] data){if(data.len==0){return 0;}if(data.len==4096){return 1+data[data.len-1] as i32;}if(data.len==4097){return 2+data[data.len-1] as i32;}if(data.len==1048576){return 3+data[data.len-1] as i32;}return -1;}";
    let programs::Program standalone=kept(library,application);var engine::Engine e=create(1,1);
    let usize p=id(engine::compile_input(ref mut e,entry(library,application),65536));
    length_case(ref mut e,p,ref standalone,0,0);length_case(ref mut e,p,ref standalone,4096,256);
    length_case(ref mut e,p,ref standalone,4097,257);length_case(ref mut e,p,ref standalone,1048576,258);
    counts(ref mut e,1,0,0);assert(id(engine::release_program(ref mut e,p))==p);assert(id(engine::destroy(ref mut e))==0);
}
fn void wrong_api_preserves_ready(){
    var engine::Engine e=create(2,2);let inputs::Snapshot input=captured(b"*");
    let usize p=id(engine::compile_input(ref mut e,entry(b"module app;pub fn i32 chosen(ref u8[] data){return data[0] as i32;}",b""),65536));
    let usize q=id(engine::compile(ref mut e,plain(b"module app;pub fn i32 chosen(){return 43;}"),65536));
    let usize a=id(engine::create_instance(ref mut e,p,16000000));let usize b=id(engine::create_instance(ref mut e,q,16000000));
    let engine::Event ready_a=event(engine::observe(ref mut e,a));let engine::Event ready_b=event(engine::observe(ref mut e,b));
    assert(ready_a.kind==0 && ready_b.kind==0);
    rejected_event(engine::execute_once(ref mut e,a),1);rejected_event(engine::execute_input_once(ref mut e,b,ref input),1);
    same_event(ready_a,event(engine::observe(ref mut e,a)));same_event(ready_b,event(engine::observe(ref mut e,b)));counts(ref mut e,2,2,2);
    let engine::Event first=event(engine::execute_input_once(ref mut e,a,ref input));assert(first.kind==1 && first.value==42 && first.fuel_known);
    let engine::Event second=event(engine::execute_once(ref mut e,b));assert(second.kind==1 && second.value==43 && !second.fuel_known);
    rejected_event(engine::execute_input_once(ref mut e,a,ref input),11);rejected_event(engine::execute_once(ref mut e,b),11);
    same_event(first,event(engine::observe(ref mut e,a)));same_event(second,event(engine::observe(ref mut e,b)));
    assert(id(engine::release_program(ref mut e,p))==p);assert(id(engine::release_program(ref mut e,q))==q);
    assert(id(engine::destroy_instance(ref mut e,a))==a);assert(id(engine::destroy_instance(ref mut e,b))==b);
    counts(ref mut e,0,0,0);assert(id(engine::destroy(ref mut e))==0);
}
fn void released_pinned_reuse(){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){return data[0] as i32;}";
    var engine::Engine e=create(1,3);let usize p=id(engine::compile_input(ref mut e,entry(source,b""),65536));
    let usize a=id(engine::create_instance(ref mut e,p,16000000));let usize b=id(engine::create_instance(ref mut e,p,123));
    let usize c=id(engine::create_instance(ref mut e,p,16000000));assert(id(engine::release_program(ref mut e,p))==p);
    rejected(engine::create_instance(ref mut e,p,1),2);rejected(engine::destroy(ref mut e),3);counts(ref mut e,1,3,3);
    let inputs::Snapshot first=captured(b"*");let inputs::Snapshot second=captured(b"+");
    assert(event(engine::execute_input_once(ref mut e,a,ref first)).value==42);
    let engine::Event cancelled=event(engine::cancel_ready(ref mut e,b));
    assert(cancelled.kind==3 && cancelled.fuel_known && cancelled.remaining==123);
    same_event(cancelled,event(engine::observe(ref mut e,b)));rejected_event(engine::execute_input_once(ref mut e,b,ref second),11);
    assert(id(engine::destroy_instance(ref mut e,a))==a);counts(ref mut e,1,2,2);
    assert(event(engine::execute_input_once(ref mut e,c,ref second)).value==43);
    assert(id(engine::destroy_instance(ref mut e,b))==b);counts(ref mut e,1,1,1);
    assert(id(engine::destroy_instance(ref mut e,c))==c);counts(ref mut e,0,0,0);rejected(engine::release_program(ref mut e,p),2);
    let usize replacement=id(engine::compile_input(ref mut e,entry(source,b""),65536));assert(replacement!=p);
    assert(id(engine::release_program(ref mut e,replacement))==replacement);assert(id(engine::destroy(ref mut e))==0);
}
fn void move_and_mixed_relocation(){
    var engine::Engine original=create(4,3);
    let usize trash=id(engine::compile(ref mut original,plain(b"module app;pub fn i32 chosen(){return 0;}"),65536));
    let usize input=id(engine::compile_input(ref mut original,entry(b"module lib;pub fn ref u8[] tail(ref u8[] data){return data[1..];}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){let ref u8[] part=m::tail(ref data);let ref u8[] marker=b\"*\";return part[0] as i32+marker[0] as i32;}"),65536));
    let usize plain_program=id(engine::compile(ref mut original,plain(b"module app;pub fn i32 chosen(){let ref u8[] b=b\"+\";return b[0] as i32;}"),65536));
    let usize other=id(engine::compile_input(ref mut original,entry(b"module app;pub fn i32 chosen(ref u8[] data){let ref u8[] marker=b\"*\";return data[0] as i32+marker[0] as i32;}",b""),65536));
    let usize a=id(engine::create_instance(ref mut original,input,16000000));let usize b=id(engine::create_instance(ref mut original,plain_program,16000000));
    let usize c=id(engine::create_instance(ref mut original,other,16000000));
    // Removing the leading ordinary Program relocates both input owners and an
    // ordinary owner through scratch storage before moving the entire Engine.
    assert(id(engine::release_program(ref mut original,trash))==trash);assert(id(engine::release_program(ref mut original,input))==input);
    var engine::Engine moved=original;counts(ref mut moved,3,3,3);
    let inputs::Snapshot first=captured(b"\xFF\x00");let inputs::Snapshot second=captured(b"\x02");
    assert(event(engine::execute_input_once(ref mut moved,a,ref first)).value==42);
    assert(id(engine::destroy_instance(ref mut moved,a))==a);counts(ref mut moved,2,2,2);
    assert(id(engine::release_program(ref mut moved,plain_program))==plain_program);
    assert(event(engine::execute_once(ref mut moved,b)).value==43);assert(id(engine::destroy_instance(ref mut moved,b))==b);
    counts(ref mut moved,1,1,1);assert(event(engine::execute_input_once(ref mut moved,c,ref second)).value==44);
    // Owning cleanup must drop this last live input Instance/Program. The caller
    // checks the native heap after run() returns and these owners have left.
}
fn void diagnostic_case(ref u8[] library,ref u8[] application,ref u8[] payload,u8 kind,usize owner,usize offset,ref u8[] token){
    let programs::Program standalone=kept(library,application);let inputs::Snapshot input=captured(payload);
    var engine::Engine e=create(1,1);let usize p=id(engine::compile_input(ref mut e,entry(library,application),65536));
    let usize instance=id(engine::create_instance(ref mut e,p,16000000));
    let engine::Event failed=matches(ref mut e,instance,ref standalone,ref input,16000000);
    let diagnostics::Error d=failed.diagnostic;
    assert(failed.kind==2 && d.code.kind==kind && d.at.source==owner && d.at.start==offset && d.at.end==offset+1);
    switch(sources::view(programs::snapshot(ref standalone),d.at)){
        case .ok(v):{assert(bytes::equal(v,token));}case .err(_):{assert(false);}
    };
    same_event(failed,event(engine::cancel_ready(ref mut e,instance)));
    rejected_event(engine::execute_input_once(ref mut e,instance,ref input),11);
    assert(id(engine::release_program(ref mut e,p))==p);assert(id(engine::destroy_instance(ref mut e,instance))==instance);
    counts(ref mut e,0,0,0);assert(id(engine::destroy(ref mut e))==0);
}
fn void original_diagnostics(){
    var engine::Engine e=create(1,1);
    let ref u8[] library=b"\xEF\xBB\xBFmodule lib;\r\npub fn i32 bad(){return missing;}";
    let ref u8[] application=b"module app;pub fn i32 chosen(ref u8[] data){return 0;}";
    let diagnostics::Error expected=switch(programs::compile(entry(library,application),65536)){
        case .ok(_):{assert(false);diagnostics::absent(errors::make(0,0))}case .err(d):{d}
    };
    switch(engine::compile_input(ref mut e,entry(library,application),65536)){
        case .ok(_):{assert(false);}case .err(failed):{
            assert(failed.status==4 && failed.diagnostic.code.kind==3 && failed.diagnostic.at.source==0);
            same_diagnostic(failed.diagnostic,expected);
        }
    };
    counts(ref mut e,0,0,0);
    switch(engine::compile_input(ref mut e,entry(application,b""),0)){
        case .ok(_):{assert(false);}case .err(failed):{assert(failed.status==4 && failed.diagnostic.code.kind==4);}
    };
    counts(ref mut e,0,0,0);assert(id(engine::destroy(ref mut e))==0);
    diagnostic_case(b"\xEF\xBB\xBFmodule lib;\r\npub fn i32 at(ref u8[] data){return data[4096] as i32;}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){return m::at(ref data);}",b"\x00",14,0,52,b"d");
    diagnostic_case(b"module lib;pub fn i32 divisor(ref u8[] data){return data[0] as i32;}",
        b"\xEF\xBB\xBFmodule app;\r\nimport lib as m;pub fn i32 chosen(ref u8[] data){return 42/m::divisor(ref data);}",b"\x00",7,1,74,b"/");
}
fn void fuel_case(ref mut engine::Engine e,usize p,ref programs::Program standalone,ref inputs::Snapshot input,
    usize budget,bool success,usize remaining){
    let usize instance=id(engine::create_instance(e,p,budget));
    let engine::Event actual=matches(e,instance,standalone,input,budget);
    if(success){assert(actual.kind==1 && actual.value==42 && actual.remaining==remaining);}
    else{assert(actual.kind==2 && actual.diagnostic.code.kind==8 && actual.remaining<=budget);}
    assert(id(engine::destroy_instance(e,instance))==instance);
}
fn void exact_and_one_less_fuel(){
    let ref u8[] library=b"module lib;pub fn ref u8[] tail(ref u8[] data){return data[4096..];}";
    let ref u8[] application=b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){let u8[1] local=[20];let ref u8[] part=m::tail(ref data);return part[0] as i32+local[0] as i32;}";
    let programs::Program standalone=kept(library,application);var bytes::Buffer data=backing(4097);
    bytes::view_mut(ref mut data)[4096]=22;let inputs::Snapshot input=captured(bytes::view(ref data));
    let usize price=switch(programs::run(ref standalone,ref input,16000000)){
        case .ok(v):{assert(v.value==42 && v.remaining<16000000);16000000-v.remaining}
        case .err(_):{assert(false);0}
    };
    assert(price>1);var engine::Engine e=create(1,1);let usize p=id(engine::compile_input(ref mut e,entry(library,application),65536));
    fuel_case(ref mut e,p,ref standalone,ref input,0,false,0);fuel_case(ref mut e,p,ref standalone,ref input,1,false,0);
    fuel_case(ref mut e,p,ref standalone,ref input,price/2,false,0);
    fuel_case(ref mut e,p,ref standalone,ref input,price-1,false,0);
    fuel_case(ref mut e,p,ref standalone,ref input,price,true,0);fuel_case(ref mut e,p,ref standalone,ref input,price+1,true,1);
    assert(inputs::observe(ref input).length==4097 && inputs::view(ref input)[4096]==22);
    counts(ref mut e,1,0,0);assert(id(engine::release_program(ref mut e,p))==p);assert(id(engine::destroy(ref mut e))==0);
}
fn void exhausted_admission_preserves_input_event(){
    var engine::Engine e=create(1,2);let inputs::Snapshot input=captured(b"*");
    let usize p=id(engine::compile_input(ref mut e,entry(b"module app;pub fn i32 chosen(ref u8[] data){return data[0] as i32;}",b""),65536));
    let usize done=id(engine::create_instance(ref mut e,p,16000000));let usize ready=id(engine::create_instance(ref mut e,p,123));
    let engine::Event before=event(engine::execute_input_once(ref mut e,done,ref input));assert(before.kind==1 && before.value==42 && before.fuel_known);
    unsafe{bc_runtime_engine_test_seed(ref mut e as ptr mut void,2)};
    // inspect consumes the final admission epoch; maintenance remains available.
    counts(ref mut e,1,2,2);rejected_event(engine::execute_input_once(ref mut e,ready,ref input),8);
    same_event(before,event(engine::observe(ref mut e,done)));assert(event(engine::observe(ref mut e,ready)).kind==0);
    rejected(engine::create_instance(ref mut e,p,1),8);
    let engine::Event cancelled=event(engine::cancel_ready(ref mut e,ready));
    assert(cancelled.kind==3 && cancelled.fuel_known && cancelled.remaining==123);
    assert(id(engine::release_program(ref mut e,p))==p);assert(id(engine::destroy_instance(ref mut e,done))==done);
    same_event(cancelled,event(engine::observe(ref mut e,ready)));assert(id(engine::destroy_instance(ref mut e,ready))==ready);
    counts(ref mut e,0,0,0);assert(id(engine::destroy(ref mut e))==0);
}
fn void input_fault_quarantines_engine(u32 stage){
    var engine::Engine owner=create(1,3);
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){if(data.len==0){return 0;}return data[0] as i32;}";
    let usize p=id(engine::compile_input(ref mut owner,entry(source,b""),65536));
    let usize prior=id(engine::create_input_instance(ref mut owner,p,captured(b""),16000000));
    let engine::Event completed=event(engine::execute_once(ref mut owner,prior));
    assert(completed.kind==1 && completed.value==0);
    let usize peer=id(engine::create_instance(ref mut owner,p,123));
    let usize target=id(engine::create_input_instance(ref mut owner,p,captured(if(stage==2){b"+"}else{b""}),16000000));
    let inputs::Snapshot substitute=captured(b"*");
    let engine::Event before=event(engine::observe(ref mut owner,target));
    let usize attempts=unsafe{probe_attempts()};
    let usize live=unsafe{probe_live_bytes()};
    unsafe{bc_runtime_engine_test_inject_input_fault(stage)};
    if(stage==3){rejected_event(engine::execute_input_once(ref mut owner,target,ref substitute),14);}
    else{rejected_event(engine::execute_once(ref mut owner,target),14);}
    assert(unsafe{probe_attempts()}==attempts && unsafe{probe_live_bytes()}==live);
    counts(ref mut owner,1,3,3);
    same_event(completed,event(engine::cancel_ready(ref mut owner,prior)));
    let engine::Event terminal=event(engine::observe(ref mut owner,target));
    assert(terminal.kind==2 && terminal.diagnostic.code.kind==errors::engine_poisoned_kind());
    assert(terminal.remaining==before.remaining && terminal.fuel_known);
    let engine::Event stopped=event(engine::observe(ref mut owner,peer));
    assert(stopped.kind==2 && stopped.diagnostic.code.kind==errors::engine_poisoned_kind() && stopped.remaining==123);
    rejected_event(engine::execute_input_once(ref mut owner,peer,ref substitute),14);
    assert(id(engine::destroy_instance(ref mut owner,target))==target);
    assert(id(engine::destroy_instance(ref mut owner,peer))==peer);
    assert(id(engine::destroy_instance(ref mut owner,prior))==prior);
    assert(id(engine::release_program(ref mut owner,p))==p);
    assert(id(engine::destroy(ref mut owner))==0);
}
fn void owning_input_instances(){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){if(data.len!=3){return -1;}let ref u8[] marker=b\"*\";return data[0] as i32+data[1] as i32+data[2] as i32+marker[0] as i32;}";
    var engine::Engine original=create(3,4);
    let usize trash=id(engine::compile(ref mut original,plain(b"module app;pub fn i32 chosen(){return 0;}"),65536));
    let usize p=id(engine::compile_input(ref mut original,entry(source,b""),65536));
    let usize q=id(engine::compile(ref mut original,plain(b"module app;pub fn i32 chosen(){let ref u8[] b=b\"+\";return b[0] as i32;}"),65536));
    let usize a=id(engine::create_input_instance(ref mut original,p,detached_binary(),16000000));
    let usize b=id(engine::create_input_instance(ref mut original,p,captured(b"\x01\x00\x02"),16000000));
    let usize cancelled=id(engine::create_input_instance(ref mut original,p,captured(b"\x00\x07\x00"),123));
    let usize ordinary_instance=id(engine::create_instance(ref mut original,q,16000000));
    counts(ref mut original,3,4,4);assert(id(engine::release_program(ref mut original,trash))==trash);
    assert(id(engine::release_program(ref mut original,p))==p);rejected(engine::create_input_instance(ref mut original,p,captured(b"!"),1),2);
    var engine::Engine moved=original;counts(ref mut moved,2,4,4);
    let inputs::Snapshot substitute=captured(b"\x09\x09\x09");
    let engine::Event ready_a=event(engine::observe(ref mut moved,a));let engine::Event ready_b=event(engine::observe(ref mut moved,b));
    rejected_event(engine::execute_input_once(ref mut moved,a,ref substitute),1);
    rejected_event(engine::execute_input_once(ref mut moved,b,ref substitute),1);
    same_event(ready_a,event(engine::observe(ref mut moved,a)));same_event(ready_b,event(engine::observe(ref mut moved,b)));
    let engine::Event first=event(engine::execute_once(ref mut moved,a));assert(first.kind==1 && first.value==297 && first.fuel_known);
    rejected_event(engine::execute_input_once(ref mut moved,a,ref substitute),11);
    let engine::Event stopped=event(engine::cancel_ready(ref mut moved,cancelled));
    assert(stopped.kind==3 && stopped.fuel_known && stopped.remaining==123);
    rejected_event(engine::execute_once(ref mut moved,cancelled),11);
    assert(id(engine::destroy_instance(ref mut moved,cancelled))==cancelled);counts(ref mut moved,2,3,3);
    assert(id(engine::destroy_instance(ref mut moved,a))==a);counts(ref mut moved,2,2,2);
    let engine::Event second=event(engine::execute_once(ref mut moved,b));assert(second.kind==1 && second.value==45 && second.fuel_known);
    same_event(second,event(engine::observe(ref mut moved,b)));assert(id(engine::destroy_instance(ref mut moved,b))==b);
    // Last input pin reclamation relocates the ordinary literal owner again.
    counts(ref mut moved,1,1,1);assert(event(engine::execute_once(ref mut moved,ordinary_instance)).value==43);
    assert(id(engine::release_program(ref mut moved,q))==q);assert(id(engine::destroy_instance(ref mut moved,ordinary_instance))==ordinary_instance);
    counts(ref mut moved,0,0,0);assert(id(engine::destroy(ref mut moved))==0);
    // Also exercise Ready owning-input teardown through implicit Engine cleanup.
    var engine::Engine pending_engine=create(1,1);let usize last=id(engine::compile_input(ref mut pending_engine,entry(source,b""),65536));
    let usize pending=id(engine::create_input_instance(ref mut pending_engine,last,detached_binary(),16000000));
    counts(ref mut pending_engine,1,1,1);assert(event(engine::observe(ref mut pending_engine,pending)).kind==0);
}
fn void os_input_case(u32 kind,usize length,i64 expected){
    let usize handle=unsafe{bc_runtime_engine_test_input_open(kind,length)};
    var usize fuel=9;
    let inputs::Snapshot input=switch(os_input::handle(handle,1048576,3,ref mut fuel)){
        case .ok(value):{value}case .err(_):{assert(false);return;}
    };
    assert(fuel==6 && inputs::observe(ref input).length==length);
    unsafe{bc_runtime_engine_test_input_close()};
    var engine::Engine e=create(1,1);
    let usize p=id(engine::compile_input(ref mut e,entry(b"module app;pub fn i32 chosen(ref u8[] data){if(data.len==0){return 42;}return data[data.len-1] as i32;}",b""),65536));
    let usize instance=id(engine::create_input_instance(ref mut e,p,input,16000000));
    assert(id(engine::release_program(ref mut e,p))==p);
    let engine::Event done=event(engine::execute_once(ref mut e,instance));
    assert(done.kind==1 && done.value==expected && done.fuel_known);
    assert(id(engine::destroy_instance(ref mut e,instance))==instance);assert(id(engine::destroy(ref mut e))==0);
}
fn void actual_os_input_to_instance(){
    // Windows initializes process/thread I/O bookkeeping on its first use;
    // warm both kinds before comparing each subsequent handle count.
    os_input_case(0,4,3);os_input_case(1,4,3);
    unsafe{bc_runtime_engine_test_input_measure()};
    os_input_case(0,0,42);os_input_case(0,4,3);os_input_case(0,1048576,255);
    os_input_case(1,0,42);os_input_case(1,4097,0);os_input_case(1,1048576,255);
}
fn void allocation_failures(){
    var i64 allocation=0;while(allocation<7){
        unsafe{bc_runtime_engine_test_fail(allocation)};
        switch(engine::create(engine::Limits{.programs=1,.instances=1,.fuel=16000000})){
            case .ok(_):{assert(false);}case .err(e):{assert(e.status==6);}
        };
        unsafe{bc_runtime_engine_test_fail(-1)};unsafe{bc_runtime_engine_test_closed_allocations()};allocation+=1;
    }
    {
        var engine::Engine e=create(1,1);
        let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){return data[0] as i32;}";
        let entries::InputEntry selected=entry(source,b"");
        unsafe{bc_runtime_engine_test_fail(0)};
        rejected(engine::compile_input(ref mut e,selected,65536),6);
        unsafe{bc_runtime_engine_test_fail(-1)};counts(ref mut e,0,0,0);
        let usize p=id(engine::compile_input(ref mut e,entry(source,b""),65536));assert(p==1);
        let inputs::Snapshot input=captured(b"*");
        unsafe{bc_runtime_engine_test_fail(0)};
        rejected(engine::create_input_instance(ref mut e,p,input,16000000),6);
        unsafe{bc_runtime_engine_test_fail(-1)};counts(ref mut e,1,0,0);
        let usize i=id(engine::create_input_instance(ref mut e,p,captured(b"*"),16000000));assert(i==2);
        unsafe{bc_runtime_engine_test_fail(0)};
        let engine::Event failure=event(engine::execute_once(ref mut e,i));
        unsafe{bc_runtime_engine_test_fail(-1)};
        assert(failure.kind==2 && failure.fuel_known && failure.diagnostic.code.kind==15);
        same_event(failure,event(engine::observe(ref mut e,i)));counts(ref mut e,1,1,1);
        assert(id(engine::destroy_instance(ref mut e,i))==i);
        let usize retry=id(engine::create_input_instance(ref mut e,p,captured(b"+"),16000000));
        assert(event(engine::execute_once(ref mut e,retry)).value==43);
        assert(id(engine::destroy_instance(ref mut e,retry))==retry);assert(id(engine::release_program(ref mut e,p))==p);
        assert(id(engine::destroy(ref mut e))==0);
    }
    unsafe{bc_runtime_engine_test_closed_allocations()};
}
pub fn void run(){
    allocation_failures();
    binary_reuse();full_length_and_last_byte();wrong_api_preserves_ready();released_pinned_reuse();
    move_and_mixed_relocation();original_diagnostics();exact_and_one_less_fuel();
    exhausted_admission_preserves_input_event();owning_input_instances();
    input_fault_quarantines_engine(1);input_fault_quarantines_engine(2);input_fault_quarantines_engine(3);
    actual_os_input_to_instance();
}
