module engine_pending_tests;
import runtime_engine as engine;
import slice_result_machine as machine;
import module_output_program as programs;
import module_entry as entries;
import module_input_entry as input_entries;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import runtime_input as inputs;
import runtime_output as output;
import source_error as source_error;
import fuel as meter;
import std::bytes as bytes;
import std::num as num;

// Native fixture only. The exact Program and input owners outlive every step.
// These checks exercise the trusted pending carrier, not Engine pinning/step.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
struct Heap { usize blocks; usize bytes; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void same_heap(ref Heap before){
    assert(unsafe{probe_live()}==before.blocks && unsafe{probe_live_bytes()}==before.bytes);
}
// Source construction follows module_dispatch_quantum; failures unwind owners.
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
fn void same_meta(machine::Meta a,machine::Meta b){
    assert(a.phase==b.phase && a.remaining==b.remaining && a.value==b.value);
    assert(a.failure.kind==b.failure.kind && a.failure.offset==b.failure.offset);
    assert(a.cursor.pc==b.cursor.pc && a.cursor.active==b.cursor.active);
    assert(a.stats.calls==b.stats.calls && a.stats.yields==b.stats.yields);
    assert(a.stats.dispatched==b.stats.dispatched && a.stats.last==b.stats.last && a.stats.maximum==b.stats.maximum);
}
fn void rejected_seal(ref mut machine::Machine m){
    let machine::Meta before=machine::observe(m);let Heap stored=heap();
    switch(engine::seal_pending_output(m)){case .ok(_):{assert(false);}case .err(_):{}};
    same_meta(before,machine::observe(m));same_heap(ref stored);
}
fn Result<machine::Machine,u8> prepared(ref programs::Program p,ref inputs::Snapshot input,usize budget,usize limit){
    var machine::Machine m=switch(engine::prepare_pending_output(p,input,budget,limit,true)){
        case .ok(v):{v}case .err(_):{return .err(11);}
    };
    let machine::Meta initial=machine::observe(ref m);
    assert(initial.phase==1 && initial.cursor.active && initial.remaining<budget);
    assert(initial.value==0 && initial.failure.kind==0 && initial.failure.offset==0);
    assert(initial.stats.calls==0 && initial.stats.yields==0 && initial.stats.dispatched==0);
    assert(initial.stats.last==0 && initial.stats.maximum==0);
    assert(machine::core_heap_bytes(ref m,engine::pending_core_stride())==engine::pending_core_stride());
    rejected_seal(ref mut m);return .ok(m);
}
// Exactly one native call returns to its caller; no hidden completion loop.
fn Result<machine::Meta,u8> tick(ref mut machine::Machine m,ref programs::Program p,ref inputs::Snapshot input,usize quantum){
    let machine::Meta before=machine::observe(m);assert(before.phase==1);
    let usize attempts=unsafe{probe_attempts()};
    let machine::Meta after=switch(engine::advance_pending_output(m,p,input,quantum)){
        case .ok(v):{v}case .err(_):{return .err(12);}
    };
    assert(unsafe{probe_attempts()}==attempts);
    same_meta(after,machine::observe(m));
    assert(after.phase==1 || after.phase==2 || after.phase==3);
    assert(after.stats.calls==before.stats.calls+1 && after.remaining<=before.remaining);
    assert(after.stats.last<=quantum && after.stats.maximum<=4096);
    assert(after.stats.maximum==if(after.stats.last>before.stats.maximum){after.stats.last}else{before.stats.maximum});
    assert(after.stats.dispatched==before.stats.dispatched+after.stats.last);
    if(after.phase==1){
        // Authority stages may yield before exhausting the opcode quantum.
        assert(after.cursor.active && after.stats.last>0 && after.stats.last<=quantum);
        assert(after.stats.yields==before.stats.yields+1);
    }
    return .ok(after);
}
fn Result<machine::Machine,u8> moved_step(machine::Machine owner,ref programs::Program p,ref inputs::Snapshot input){
    var machine::Machine moved=owner;
    let machine::Meta progress=tick(ref mut moved,p,input,1)?;
    assert(progress.phase==1);return .ok(moved);
}
fn Result<machine::Meta,u8> finish(ref mut machine::Machine m,ref programs::Program p,ref inputs::Snapshot input){
    var machine::Meta state=machine::observe(m);var usize calls=0;
    while(state.phase==1){
        // Fixture bound, not a timing or bulk-helper work guarantee.
        assert(calls<10000);state=tick(m,p,input,1)?;calls+=1;
    }
    return .ok(state);
}
fn Result<machine::Meta,u8> cancelled(ref mut machine::Machine m){
    return switch(engine::cancel_pending_output(m)){
        case .ok(v):{same_meta(v,machine::observe(m));.ok(v)}case .err(_):{.err(13)}
    };
}
fn Result<usize,u8> publish_matches(ref mut machine::Machine m,ref programs::Execution baseline,ref u8[] expected,usize emits){
    let programs::Completion c=programs::observe(baseline);let machine::Meta done=machine::observe(m);
    assert(c.success && done.phase==2 && !done.cursor.active && done.value==c.value && done.failure.kind==0);
    assert(done.stats.calls==done.stats.yields+1 && done.stats.last>0 && done.stats.last<=done.stats.maximum && done.stats.maximum<=4096);
    // Cancelling success must not steal the still-unsealed publication.
    same_meta(done,cancelled(m)?);
    let output::Published published=switch(engine::seal_pending_output(m)){
        case .ok(v):{v}case .err(_):{return .err(14);}
    };
    let output::Observation result=output::published_observation(ref published);
    assert(result.phase==1 && result.length==expected.len && result.emits==emits);
    assert(c.output_bytes==result.length && c.emits==result.emits);
    assert(result.fuel==c.remaining && machine::observe(m).remaining==c.remaining);
    assert(done.remaining==result.fuel+meter::output_seal());
    assert(bytes::equal(output::view(ref published),expected));
    assert(bytes::equal(output::view(ref published),programs::view(baseline)));
    let machine::Meta sealed=machine::observe(m);rejected_seal(m);rejected_seal(m);
    same_meta(sealed,cancelled(m)?);same_meta(sealed,cancelled(m)?);
    assert(bytes::equal(output::view(ref published),expected));return .ok(0);
}
fn Result<usize,u8> success(ref programs::Program p,ref inputs::Snapshot input,usize limit,ref u8[] expected,usize emits){
    let programs::Execution baseline=programs::complete(p,input,16000000,limit,true);
    assert(programs::observe(ref baseline).success && programs::observe(ref baseline).value==42);
    let Heap stored=heap();
    {
        var machine::Machine first=prepared(p,input,16000000,limit)?;
        let machine::Meta one=tick(ref mut first,p,input,1)?;
        assert(one.phase==1 && one.stats.calls==1 && one.stats.dispatched==1);
        // Move only the carrier; Program and Snapshot remain the same owners.
        let machine::Machine transfer=first;
        var machine::Machine active=moved_step(transfer,p,input)?;
        let machine::Meta two=machine::observe(ref active);
        assert(two.stats.calls==2 && two.stats.dispatched==2);rejected_seal(ref mut active);
        let machine::Meta terminal=finish(ref mut active,p,input)?;
        assert(terminal.phase==2 && terminal.stats.yields>1);
        let usize checked=publish_matches(ref mut active,ref baseline,expected,emits)?;
    }
    same_heap(ref stored);assert(bytes::equal(programs::view(ref baseline),expected));return .ok(0);
}

// Group 1: repeated real returns, moves while Pending, nested CALL/RET and emits.
fn Result<usize,u8> nested_output_and_moves(){
    let programs::Program p=kept(
        b"module lib;fn void inner(){output::emit(ref b\"B\");}pub fn void outer(){output::emit(ref b\"A\");inner();output::emit(ref b\"C\");}",
        b"module app;import lib as m;pub fn i32 chosen(){var i32 i=0;while(i<12){m::outer();i+=1;}output::emit(ref b\"Z\");return 42;}",false)?;
    let inputs::Snapshot input=captured(b"")?;
    var bytes::Buffer expected=bytes::empty();var usize i=0;
    while(i<12){if(!bytes::append(ref mut expected,b"ABC").is_ok){return .err(15);}i+=1;}
    if(!bytes::append(ref mut expected,b"Z").is_ok){return .err(15);}
    return success(ref p,ref input,37,bytes::view(ref expected),37);
}
// Group 2: indexed destination survives RHS CALL; array/record results survive RET.
fn Result<usize,u8> aggregate_places_and_calls(){
    let programs::Program array=kept(
        b"module lib;pub fn i32 rhs(){var a=[20;1];a[0]+=22;return a[0];}",
        b"module app;import lib as m;pub fn i32 chosen(){var a=[0,0];a[1]=m::rhs();output::emit(ref b\"*\");return a[1];}",false)?;
    let programs::Program record=kept(
        b"module lib;pub struct P{i32 x;}pub struct Box{P inner;}pub fn i32[2] make(i32 n){return [n;2];}pub fn Box pack(P p){return Box{.inner=p};}",
        b"module app;import lib as m;pub fn i32 chosen(){let a=m::make(21);let box=m::pack(m::P{.x=a[0]});let p=box.inner;output::emit(ref b\"R\");return p.x+a[1];}",false)?;
    let inputs::Snapshot input=captured(b"")?;
    let usize arrays=success(ref array,ref input,1,b"*",1)?;
    return success(ref record,ref input,1,b"R",1);
}
// Group 3: returned binary input/static ranges retain their canonical frame maps.
fn Result<usize,u8> returned_ranges(){
    let programs::Program p=kept(
        b"module lib;fn ref u8[] tail(ref u8[] data){return data[1..];}pub fn ref u8[] cross(ref u8[] data){return tail(ref data);}pub fn ref u8[] marker(){return b\"\\x00\\xFF\";}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){let ref u8[] part=m::cross(ref data);output::emit(ref part);let ref u8[] marker=m::marker();output::emit(ref marker);let u8[3] local=[0,255,33];output::emit(ref local[1..]);return 42;}",true)?;
    let inputs::Snapshot input=captured(b"!\x00I")?;
    let usize checked=success(ref p,ref input,6,b"\x00I\x00\xFF\xFF!",3)?;
    assert(bytes::equal(inputs::view(ref input),b"!\x00I"));return .ok(0);
}
fn Result<usize,u8> failure_matches(ref programs::Program p,ref inputs::Snapshot input,usize budget,u8 kind){
    let programs::Execution baseline=programs::complete(p,input,budget,6,true);
    let programs::Completion c=programs::observe(ref baseline);
    assert(!c.success && c.diagnostic.code.kind==kind && c.diagnostic.code.offset!=0 && c.emits==1);
    assert(c.output_bytes==0 && !programs::has_output(ref baseline) && programs::view(ref baseline).len==0);
    let Heap stored=heap();
    {
        var machine::Machine m=prepared(p,input,budget,6)?;
        let machine::Meta failed=finish(ref mut m,p,input)?;
        assert(failed.phase==3 && !failed.cursor.active && failed.remaining==c.remaining && failed.value==c.value);
        assert(failed.failure.kind==c.diagnostic.code.kind && failed.failure.offset==c.diagnostic.code.offset);
        let diagnostics::Error mapped=diagnostics::map(programs::snapshot(p),failed.failure,16);
        assert(mapped.at.source==c.diagnostic.at.source);
        assert(mapped.at.start==c.diagnostic.at.start && mapped.at.end==c.diagnostic.at.end);
        rejected_seal(ref mut m);same_meta(failed,cancelled(ref mut m)?);
        same_meta(failed,cancelled(ref mut m)?);rejected_seal(ref mut m);
    }
    same_heap(ref stored);return .ok(0);
}
// Group 4: emitted prefix is never publishable after trap or dispatch Fuel failure.
fn Result<usize,u8> trap_and_fuel_first_cause(){
    let programs::Program division=kept(
        b"module lib;pub fn i32 divisor(ref u8[] data){return data[0] as i32;}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"prefix\");return 42/m::divisor(ref data);}",true)?;
    let programs::Program loop=kept(
        b"module app;pub fn i32 chosen(){output::emit(ref b\"prefix\");var i32 n=0;while(n<64){n+=1;}return 42;}",b"",false)?;
    let inputs::Snapshot zero=captured(b"\x00")?;let inputs::Snapshot empty=captured(b"")?;
    let usize trapped=failure_matches(ref division,ref zero,16000000,7)?;
    var usize price=0;
    {
        let programs::Execution full=programs::complete(ref loop,ref empty,16000000,6,true);
        assert(programs::observe(ref full).success);price=16000000-programs::observe(ref full).remaining;
    }
    assert(price>meter::output_prepare(6)+meter::output_seal()+17);
    return failure_matches(ref loop,ref empty,price-meter::output_seal()-17,8);
}
// Group 5: reject before allocation/mutation, both before dispatch and mid-loop.
fn Result<usize,u8> invalid_quanta_unchanged(){
    let programs::Program p=kept(
        b"module app;pub fn i32 chosen(){output::emit(ref b\"prefix\");var i32 n=0;while(n<64){n+=1;}return 42;}",b"",false)?;
    let inputs::Snapshot input=captured(b"")?;
    let programs::Execution baseline=programs::complete(ref p,ref input,16000000,6,true);
    var machine::Machine m=prepared(ref p,ref input,16000000,6)?;
    let usize[3] quanta=[0,4097,18446744073709551615];var usize pass=0;
    while(pass<2){
        var usize i=0;while(i<quanta.len){
            let machine::Meta before=machine::observe(ref m);let Heap stored=heap();
            let usize attempts=unsafe{probe_attempts()};
            switch(engine::advance_pending_output(ref mut m,ref p,ref input,quanta[i])){
                case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==0);}
            };
            same_meta(before,machine::observe(ref m));same_heap(ref stored);
            assert(unsafe{probe_attempts()}==attempts);i+=1;
        }
        if(pass==0){var usize i=0;while(i<32){let machine::Meta progress=tick(ref mut m,ref p,ref input,1)?;assert(progress.phase==1);i+=1;}}
        pass+=1;
    }
    // Complete afterward to expose hidden register/owner/output mutation too.
    let machine::Meta terminal=finish(ref mut m,ref p,ref input)?;
    assert(terminal.phase==2);return publish_matches(ref mut m,ref baseline,b"prefix",1);
}
// Group 6: cancel and implicit Pending drop both unwind live input/array owners.
fn Result<usize,u8> cancellation_and_pending_drop(){
    let programs::Program p=kept(
        b"module lib;pub fn ref u8[] tail(ref u8[] data){return data[1..];}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){var a=[1,2];let ref u8[] part=m::tail(ref data);output::emit(ref part);var i32 n=0;while(n<64){a[0]+=1;n+=1;}return a[0];}",true)?;
    let inputs::Snapshot input=captured(b"!prefix")?;var usize pass=0;
    while(pass<2){
        let Heap stored=heap();
        {
            var machine::Machine m=prepared(ref p,ref input,16000000,6)?;
            var usize i=0;while(i<64){let machine::Meta progress=tick(ref mut m,ref p,ref input,1)?;assert(progress.phase==1);i+=1;}
            let machine::Meta pending=machine::observe(ref m);
            assert(pending.stats.dispatched==64 && pending.stats.yields==64);rejected_seal(ref mut m);
            if(pass==0){
                let machine::Meta stopped=cancelled(ref mut m)?;
                assert(stopped.phase==4 && !stopped.cursor.active && stopped.remaining==pending.remaining);
                rejected_seal(ref mut m);same_meta(stopped,cancelled(ref mut m)?);
                same_meta(stopped,cancelled(ref mut m)?);rejected_seal(ref mut m);
            }
            // Second pass leaves a genuinely running, prefix-staged owner here.
        }
        same_heap(ref stored);assert(bytes::equal(inputs::view(ref input),b"!prefix"));pass+=1;
    }
    return .ok(0);
}
fn Result<usize,u8> prepare_allocation_failures(){
    let programs::Program p=kept(b"module app;pub fn i32 chosen(ref u8[] data){var a=[1,2];a[1]+=1;output::emit(ref data);return a[1];}",b"",true)?;
    let inputs::Snapshot input=captured(b"!input")?;
    let usize before=unsafe{probe_attempts()};
    {let machine::Machine measured=prepared(ref p,ref input,16000000,6)?;assert(machine::observe(ref measured).phase==1);}
    let usize attempts=unsafe{probe_attempts()}-before;
    assert(attempts>3);
    var usize ordinal=0;while(ordinal<attempts){
        let Heap stored=heap();
        let i64 position=switch(num::i64_from_usize(ordinal)){case .ok(v):{v}case .err(_):{return .err(90);}};
        unsafe{bc_runtime_engine_test_fail(position)};
        let Result<machine::Machine,source_error::Error> rejected=engine::prepare_pending_output(ref p,ref input,16000000,6,true);
        unsafe{bc_runtime_engine_test_fail(-1)};
        switch(rejected){case .ok(_):{assert(false);}case .err(e):{assert(e.code.kind==15);}};
        same_heap(ref stored);ordinal+=1;
    }
    return .ok(attempts);
}
// Owning state must also survive changes of quantum between calls, including
// a whole-program quantum and small boundaries through CALL/RET and emits.
fn Result<usize,u8> variable_quantum_matches_exact_terminal(){
    let programs::Program p=kept(
        b"module lib;fn ref u8[] tail(ref u8[] data){return data[1..];}pub fn void send(ref u8[] data){let ref u8[] part=tail(ref data);output::emit(ref part);}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){var i32 i=0;while(i<12){m::send(ref data);i+=1;}return 42;}",true)?;
    let inputs::Snapshot input=captured(b"!*X")?;
    let programs::Execution baseline=programs::complete(ref p,ref input,16000000,24,true);
    assert(programs::observe(ref baseline).success);
    var bytes::Buffer expected=bytes::empty();var usize i=0;
    while(i<12){assert(bytes::append(ref mut expected,b"*X").is_ok);i+=1;}
    let usize[6] quanta=[1,2,3,7,64,4096];var usize variant=0;
    while(variant<7){
        let Heap stored=heap();
        {
            var machine::Machine m=prepared(ref p,ref input,16000000,24)?;var usize calls=0;
            var machine::Meta progress=machine::observe(ref m);
            while(progress.phase==1){
                assert(calls<10000);
                let usize quantum=if(variant==6){quanta[calls%6]}else{quanta[variant]};
                progress=tick(ref mut m,ref p,ref input,quantum)?;calls+=1;
            }
            let usize checked=publish_matches(ref mut m,ref baseline,bytes::view(ref expected),12)?;
            if(variant==5){assert(calls>1);}
        }
        same_heap(ref stored);variant+=1;
    }
    return .ok(0);
}
pub fn void run(){
    let Heap before=heap();
    assert(nested_output_and_moves().is_ok);same_heap(ref before);
    assert(aggregate_places_and_calls().is_ok);same_heap(ref before);
    assert(returned_ranges().is_ok);same_heap(ref before);
    assert(trap_and_fuel_first_cause().is_ok);same_heap(ref before);
    assert(invalid_quanta_unchanged().is_ok);same_heap(ref before);
    assert(cancellation_and_pending_drop().is_ok);same_heap(ref before);
    assert(prepare_allocation_failures().is_ok);same_heap(ref before);
    assert(variable_quantum_matches_exact_terminal().is_ok);same_heap(ref before);
}
