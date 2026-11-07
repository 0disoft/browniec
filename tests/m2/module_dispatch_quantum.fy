module tests::m2::module_dispatch_quantum;
import module_output_program as programs;
import slice_result_cursor as cursor;
import module_entry as entries;
import module_input_entry as input_entries;
import module_index as modules;
import source_snapshot as sources;
import runtime_input as inputs;
import runtime_output as output;
import fuel as meter;
import std::bytes as bytes;

// Native fixture: link the existing runtime-engine/heap-observer.c counters.
// Only canonical dispatch counts are bounded. Bulk operations, preparation and
// cleanup remain atomic; this is not a work bound or persistent Engine.step.
// Source forms below come from module_output_execution and module_program.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();

struct Heap { usize blocks; usize bytes; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void same_heap(ref Heap before){
    assert(unsafe{probe_live()}==before.blocks && unsafe{probe_live_bytes()}==before.bytes);
}
fn Result<modules::Index,u8> indexed(ref u8[] library,ref u8[] application){
    var sources::Builder b=switch(sources::builder(4096,4096)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    if(!sources::add(ref mut b,b"library",library).is_ok){return .err(2);}
    if(application.len!=0 && !sources::add(ref mut b,b"application",application).is_ok){return .err(3);}
    let sources::Snapshot s=switch(sources::freeze(ref b)){
        case .ok(v):{v}case .err(_):{return .err(4);}
    };
    return switch(modules::build(s)){case .ok(v):{.ok(v)}case .err(_):{.err(5)}};
}
fn Result<programs::Program,u8> kept(ref u8[] library,ref u8[] application,bool input){
    let modules::Index index=indexed(library,application)?;
    if(input){
        let input_entries::InputEntry entry=switch(input_entries::select_i32_input(index,b"app",b"chosen")){
            case .ok(v):{v}case .err(_):{return .err(6);}
        };
        return switch(programs::compile_input(entry,65536)){case .ok(v):{.ok(v)}case .err(_):{.err(7)}};
    }
    let entries::Entry entry=switch(entries::select_i32(index,b"app",b"chosen")){
        case .ok(v):{v}case .err(_):{return .err(8);}
    };
    return switch(programs::compile(entry,65536)){case .ok(v):{.ok(v)}case .err(_):{.err(9)}};
}
fn Result<inputs::Snapshot,u8> captured(ref u8[] data){
    var usize fuel=0;
    return switch(inputs::snapshot(data,inputs::hard_limit(),0,ref mut fuel)){
        case .ok(v):{.ok(v)}case .err(_):{.err(10)}
    };
}
fn void same(ref programs::Execution actual,ref programs::Execution baseline){
    let programs::Completion a=programs::observe(actual);let programs::Completion b=programs::observe(baseline);
    assert(a.success==b.success && a.value==b.value && a.remaining==b.remaining);
    assert(a.output_bytes==b.output_bytes && a.emits==b.emits);
    assert(a.diagnostic.code.kind==b.diagnostic.code.kind && a.diagnostic.code.offset==b.diagnostic.code.offset);
    assert(a.diagnostic.at.source==b.diagnostic.at.source);
    assert(a.diagnostic.at.start==b.diagnostic.at.start && a.diagnostic.at.end==b.diagnostic.at.end);
    assert(programs::has_output(actual)==programs::has_output(baseline));
    assert(bytes::equal(programs::view(actual),programs::view(baseline)));
    assert(programs::heap_bytes(actual)==programs::heap_bytes(baseline));
}
fn void stats_same(ref cursor::Stats a,ref cursor::Stats b){
    assert(a.calls==b.calls && a.yields==b.yields && a.dispatched==b.dispatched);
    assert(a.last==b.last && a.maximum==b.maximum);
}
fn void bounded(ref cursor::Stats s,usize quantum,bool success,usize minimum){
    assert(s.maximum<=quantum && s.last<=quantum && s.last<=s.maximum);
    assert(s.dispatched>=minimum && s.calls>=s.yields);
    if(s.dispatched!=0){assert(s.calls!=0 && s.maximum!=0);}
    if(success){
        assert(s.calls==s.yields+1 && s.dispatched!=0 && s.last!=0);
        if(s.dispatched>quantum){assert(s.yields!=0 && s.maximum==quantum);}
    }
}
// Each completion runs the same real dispatcher with a fresh cursor. Holding
// the reference result also proves later runs cannot overwrite earlier output.
fn void matrix(ref programs::Program p,ref inputs::Snapshot input,usize budget,usize limit,bool allowed,
    bool success,i64 value,ref u8[] expected,usize emits,u8 kind,usize minimum){
    var cursor::Stats reference=cursor::stats();
    let programs::Execution baseline=programs::complete_quantized(p,input,budget,limit,allowed,4096,ref mut reference);
    let programs::Completion completed=programs::observe(ref baseline);
    assert(completed.success==success && completed.value==value && completed.diagnostic.code.kind==kind);
    assert(completed.emits==emits && completed.output_bytes==expected.len);
    assert(bytes::equal(programs::view(ref baseline),expected));bounded(ref reference,4096,success,minimum);
    let programs::Execution legacy=programs::complete(p,input,budget,limit,allowed);same(ref legacy,ref baseline);
    let usize[6] quanta=[1,2,3,7,64,4096];var usize i=0;
    while(i<quanta.len){
        let Heap before=heap();var cursor::Stats statistics=cursor::stats();
        {
            let programs::Execution actual=programs::complete_quantized(p,input,budget,limit,allowed,quanta[i],ref mut statistics);
            same(ref actual,ref baseline);bounded(ref statistics,quanta[i],success,minimum);
            assert(statistics.dispatched==reference.dispatched);
            if(quanta[i]==1 && minimum>2){assert(statistics.yields>1);}
        }
        same_heap(ref before);i+=1;
    }
    assert(bytes::equal(programs::view(ref baseline),expected));
}

@test
fn void loop_and_nested_void_output_resumes_without_replaying_emits(){
    let Heap before=heap();
    {
        let programs::Program p=switch(kept(
            b"module lib;fn void inner(){output::emit(ref b\"B\");}pub fn void outer(){output::emit(ref b\"A\");inner();output::emit(ref b\"C\");}",
            b"module app;import lib as m;pub fn i32 chosen(){var i32 i=0;while(i<12){m::outer();i+=1;}output::emit(ref b\"Z\");return 42;}",false)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
        var bytes::Buffer expected=bytes::empty();var usize i=0;
        while(i<12){assert(bytes::append(ref mut expected,b"ABC").is_ok);i+=1;}
        assert(bytes::append(ref mut expected,b"Z").is_ok);
        matrix(ref p,ref input,16000000,37,true,true,42,bytes::view(ref expected),37,0,100);
    }
    same_heap(ref before);
}

@test
fn void returned_input_and_static_ranges_keep_frame_maps_and_binary_loans(){
    let Heap before=heap();
    {
        let programs::Program p=switch(kept(
            b"module lib;fn ref u8[] tail(ref u8[] data){return data[1..];}pub fn ref u8[] cross(ref u8[] data){return tail(ref data);}pub fn ref u8[] marker(){return b\"\\x00\\xFF\";}",
            b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){let ref u8[] part=m::cross(ref data);output::emit(ref part);let ref u8[] marker=m::marker();output::emit(ref marker);let u8[3] local=[0,255,33];output::emit(ref local[1..]);return 42;}",true)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let inputs::Snapshot input=switch(captured(b"!\x00I")){case .ok(v):{v}case .err(_):{assert(false);return;}};
        matrix(ref p,ref input,16000000,6,true,true,42,b"\x00I\x00\xFF\xFF!",3,0,20);
        assert(bytes::equal(inputs::view(ref input),b"!\x00I"));
    }
    same_heap(ref before);
}

@test
fn void array_list_indexed_places_and_record_calls_preserve_owners_between_batches(){
    let Heap before=heap();
    {
        let programs::Program array=switch(kept(
            b"module lib;pub fn i32 rhs(){var a=[20;1];a[0]+=22;return a[0];}",
            b"module app;import lib as m;pub fn i32 chosen(){var a=[0,0];a[1]=m::rhs();output::emit(ref b\"*\");return a[1];}",false)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let programs::Program record=switch(kept(
            b"module lib;pub struct P{i32 x;}pub struct Box{P inner;}pub fn i32[2] make(i32 n){return [n;2];}pub fn Box pack(P p){return Box{.inner=p};}",
            b"module app;import lib as m;pub fn i32 chosen(){let a=m::make(21);let box=m::pack(m::P{.x=a[0]});let p=box.inner;output::emit(ref b\"R\");return p.x+a[1];}",false)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
        matrix(ref array,ref input,16000000,1,true,true,42,b"*",1,0,10);
        matrix(ref record,ref input,16000000,1,true,true,42,b"R",1,0,10);
    }
    same_heap(ref before);
}

@test
fn void runtime_errors_and_fuel_exhaustion_keep_exact_diagnostics_and_no_partial_output(){
    let Heap before=heap();
    {
        let programs::Program division=switch(kept(
            b"module lib;pub fn i32 divisor(ref u8[] data){return data[0] as i32;}",
            b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"prefix\");return 42/m::divisor(ref data);}",true)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let programs::Program loop=switch(kept(
            b"module app;pub fn i32 chosen(){output::emit(ref b\"prefix\");var i32 n=0;while(n<64){n+=1;}return 42;}",b"",false)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let inputs::Snapshot zero=switch(captured(b"\x00")){case .ok(v):{v}case .err(_):{assert(false);return;}};
        let inputs::Snapshot empty=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
        matrix(ref division,ref zero,16000000,6,true,false,0,b"",1,7,5);
        matrix(ref loop,ref zero,16000000,6,true,false,0,b"",0,5,0);
        matrix(ref loop,ref empty,16000000,output::hard_limit()+1,true,false,0,b"",0,20,0);
        matrix(ref loop,ref empty,0,6,true,false,0,b"",0,8,0);
        var usize price=0;
        {
            let programs::Execution full=programs::complete(ref loop,ref empty,16000000,6,true);
            assert(programs::observe(ref full).success);price=16000000-programs::observe(ref full).remaining;
        }
        assert(price>meter::output_seal()+17+meter::output_prepare(6));
        matrix(ref loop,ref empty,price-meter::output_seal()-17,6,true,false,0,b"",1,8,100);
        matrix(ref loop,ref empty,price-1,6,true,false,0,b"",1,8,100);
        matrix(ref loop,ref empty,price,6,true,true,42,b"prefix",1,0,100);
        matrix(ref loop,ref empty,16000000,6,false,false,0,b"",0,19,1);
    }
    same_heap(ref before);
}

@test
fn void invalid_quanta_reject_before_output_prepare_without_touching_stats_fuel_or_heap(){
    let Heap before=heap();
    {
        let programs::Program p=switch(kept(b"module app;pub fn i32 chosen(){return 42;}",b"",false)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
        let usize[3] quanta=[0,4097,18446744073709551615];var usize i=0;
        while(i<quanta.len){
            var usize pass=0;while(pass<2){
                var cursor::Stats statistics=cursor::stats();
                statistics.calls=9;statistics.yields=8;statistics.dispatched=27;statistics.last=3;statistics.maximum=7;
                let cursor::Stats prior=statistics;let Heap stored=heap();let usize attempts=unsafe{probe_attempts()};
                let usize budget=if(pass==0){16000000}else{0};
                {
                    // The second pass also collides with invalid output limit
                    // and insufficient Fuel, proving invalid quantum wins first.
                    let usize limit=if(pass==0){64}else{output::hard_limit()+1};
                    let programs::Execution run=programs::complete_quantized(ref p,ref input,budget,limit,false,quanta[i],ref mut statistics);
                    let programs::Completion c=programs::observe(ref run);
                    assert(!c.success && c.value==0 && c.diagnostic.code.kind==5 && c.remaining==budget);
                    assert(c.output_bytes==0 && c.emits==0 && !programs::has_output(ref run));
                    assert(programs::view(ref run).len==0 && programs::heap_bytes(ref run)==0);
                    stats_same(ref statistics,ref prior);same_heap(ref stored);
                    assert(unsafe{probe_attempts()}==attempts);
                }
                same_heap(ref stored);pass+=1;
            }
            i+=1;
        }
    }
    same_heap(ref before);
}

fn Result<programs::Execution,u8> detached(usize quantum,ref mut cursor::Stats statistics){
    let programs::Program p=kept(
        b"module lib;pub fn ref u8[] tail(ref u8[] data){return data[1..];}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){let ref u8[] part=m::tail(ref data);output::emit(ref part);output::emit(ref b\"\\x00\");return 42;}",true)?;
    let inputs::Snapshot input=captured(b"!\x00\xFF")?;
    return .ok(programs::complete_quantized(ref p,ref input,16000000,64,true,quantum,statistics));
}
@test
fn void detached_quantized_publications_outlive_program_and_input_and_move_without_replay(){
    let Heap before=heap();
    {
        var cursor::Stats reference=cursor::stats();
        let programs::Execution baseline=switch(detached(4096,ref mut reference)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize[6] quanta=[1,2,3,7,64,4096];var usize i=0;
        while(i<quanta.len){
            let Heap stored=heap();var cursor::Stats statistics=cursor::stats();
            {
                let programs::Execution result=switch(detached(quanta[i],ref mut statistics)){
                    case .ok(v):{v}case .err(_):{assert(false);return;}
                };
                bounded(ref statistics,quanta[i],true,10);same(ref result,ref baseline);
                assert(statistics.dispatched==reference.dispatched);
                let cursor::Stats completed=statistics;let usize attempts=unsafe{probe_attempts()};
                let programs::Execution moved=result;let programs::Completion c=programs::observe(ref moved);
                assert(c.success && c.value==42 && c.emits==2 && c.output_bytes==3);
                assert(bytes::equal(programs::view(ref moved),b"\x00\xFF\x00"));
                assert(programs::heap_bytes(ref moved)==576+64 && unsafe{probe_attempts()}==attempts);
                stats_same(ref statistics,ref completed);same(ref moved,ref baseline);
            }
            same_heap(ref stored);i+=1;
        }
    }
    same_heap(ref before);
}
