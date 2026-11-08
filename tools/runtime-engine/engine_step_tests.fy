module engine_step_tests;
import runtime_engine as engine;
import runtime_live_memory as live;
import runtime_program_memory as memory;
import runtime_input as inputs;
import module_output_program as programs;
import slice_result_machine as machine;
import module_entry as entries;
import module_input_entry as input_entries;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import fuel as meter;
import std::bytes as bytes;

// Engine.step fixtures only. The parent owns native transport and integration.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
struct Heap { usize blocks; usize bytes; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void same_heap(ref Heap h){assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes);}
fn usize id(Result<usize,engine::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn engine::Event event(Result<engine::Event,engine::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,
        .diagnostic=diagnostics::absent(errors::make(0,0)),.remaining=0,.fuel_known=false}}
};}
fn void rejected(Result<engine::Event,engine::Error> r,u32 status){switch(r){
    case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}
};}
fn void rejected_take(Result<engine::Output,engine::Error> r,u32 status){switch(r){
    case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}
};}
fn void same_diagnostic(diagnostics::Error a,diagnostics::Error b){
    assert(a.code.kind==b.code.kind && a.code.offset==b.code.offset);
    assert(a.at.source==b.at.source && a.at.start==b.at.start && a.at.end==b.at.end);
}
fn void same_event(engine::Event a,engine::Event b){
    assert(a.kind==b.kind && a.value==b.value && a.remaining==b.remaining && a.fuel_known==b.fuel_known);
    same_diagnostic(a.diagnostic,b.diagnostic);
}
fn live::Observation instance(ref engine::Engine e){return switch(engine::instance_memory(e)){
    case .ok(v):{v}case .err(_):{assert(false);live::Observation{
        .instance_limit=0,.instances_limit=0,.current=0,.peak=0,.closed=false}}
};}
fn memory::Observation retained(ref engine::Engine e){return switch(engine::program_memory(e)){
    case .ok(v):{v}case .err(_):{assert(false);memory::Observation{
        .engine_limit=0,.program_limit=0,.programs_limit=0,.control_bytes=0,.program_bytes=0,
        .program_peak=0,.tracked_bytes=0,.tracked_peak=0,.closed=false,.working_limit=0,.working_peak=0,.external_bytes=0}}
};}
fn void ledger(ref engine::Engine e,usize current){
    let live::Observation l=instance(e);let memory::Observation m=retained(e);
    assert(l.current==current && current<=l.peak && l.peak<=l.instances_limit && !l.closed);
    assert(m.external_bytes==current && m.tracked_bytes==m.control_bytes+m.program_bytes+current);
    assert(m.tracked_bytes<=m.tracked_peak && m.tracked_peak<=m.engine_limit && !m.closed);
}
fn void unchanged(ref engine::Engine e,live::Observation l,memory::Observation m){
    let live::Observation a=instance(e);let memory::Observation b=retained(e);
    assert(a.current==l.current && a.peak==l.peak && a.closed==l.closed);
    assert(a.instance_limit==l.instance_limit && a.instances_limit==l.instances_limit);
    assert(b.control_bytes==m.control_bytes && b.program_bytes==m.program_bytes && b.program_peak==m.program_peak);
    assert(b.external_bytes==m.external_bytes && b.tracked_bytes==m.tracked_bytes && b.tracked_peak==m.tracked_peak);
    assert(b.working_peak==m.working_peak && b.closed==m.closed);
}
fn void counts(ref mut engine::Engine e,usize codes,usize owners,usize pins){switch(engine::inspect(e)){
    case .ok(v):{assert(v.programs==codes && v.instances==owners && v.pins==pins && !v.closed);}
    case .err(_):{assert(false);}
};}
fn void destroy(ref mut engine::Engine e,usize i){assert(id(engine::destroy_instance(e,i))==i);}
fn void release(ref mut engine::Engine e,usize p){assert(id(engine::release_program(e,p))==p);}
fn void close(ref mut engine::Engine e){assert(id(engine::destroy(e))==0);}
fn Result<engine::Engine,u8> created(){return switch(engine::create(
    engine::Limits{.programs=4,.instances=4,.fuel=16000000})){
    case .ok(v):{.ok(v)}case .err(_):{.err(1)}
};}
fn Result<modules::Index,u8> indexed(ref u8[] source){
    var sources::Builder b=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{return .err(2);}};
    if(!sources::add(ref mut b,b"app.brc",source).is_ok){return .err(3);}
    let sources::Snapshot s=switch(sources::freeze(ref b)){case .ok(v):{v}case .err(_):{return .err(4);}};
    return switch(modules::build(s)){case .ok(v):{.ok(v)}case .err(_):{.err(5)}};
}
fn Result<entries::Entry,u8> selected(ref u8[] source){return switch(entries::select_i32(indexed(source)?,b"app",b"chosen")){
    case .ok(v):{.ok(v)}case .err(_):{.err(6)}
};}
fn Result<input_entries::InputEntry,u8> selected_input(ref u8[] source){return switch(input_entries::select_i32_input(indexed(source)?,b"app",b"chosen")){
    case .ok(v):{.ok(v)}case .err(_):{.err(7)}
};}
fn Result<usize,u8> compiled(ref mut engine::Engine e,ref u8[] source,bool input){
    if(input){return .ok(id(engine::compile_input_output(e,selected_input(source)?,65536)));}
    return .ok(id(engine::compile_output(e,selected(source)?,65536)));
}
fn Result<inputs::Snapshot,u8> captured(ref u8[] data){
    var usize fuel=0;return switch(inputs::snapshot(data,inputs::hard_limit(),0,ref mut fuel)){
        case .ok(v):{.ok(v)}case .err(_):{.err(8)}
    };
}
fn Result<usize,u8> bound(ref mut engine::Engine e,usize p,ref u8[] data,usize fuel,usize limit){
    return .ok(id(engine::create_input_output_instance(e,p,captured(data)?,fuel,limit,true)));
}
fn Result<engine::Output,u8> take(ref mut engine::Engine e,usize i){return switch(engine::take_output(e,i)){
    case .ok(v):{.ok(v)}case .err(_):{.err(9)}
};}
fn engine::Event completion(ref engine::Output o){
    let programs::Completion c=engine::output_completion(o);
    return engine::Event{.kind=if(c.success){1}else{2},.value=c.value,.remaining=c.remaining,
        .diagnostic=c.diagnostic,.fuel_known=true};
}
fn void output_matches(ref engine::Output a,ref engine::Output b){
    same_event(completion(a),completion(b));
    let programs::Completion x=engine::output_completion(a);let programs::Completion y=engine::output_completion(b);
    assert(x.emits==y.emits && x.output_bytes==y.output_bytes);
    assert(engine::output_available(a)==engine::output_available(b));
    assert(bytes::equal(engine::output_view(a),engine::output_view(b)));
}
fn Result<engine::Output,u8> synchronous(ref mut engine::Engine e,usize p,ref u8[] data,usize fuel,usize limit){
    let usize i=bound(e,p,data,fuel,limit)?;
    let engine::Event done=event(engine::execute_once(e,i));let engine::Output o=take(e,i)?;
    same_event(done,completion(ref o));destroy(e,i);return .ok(o);
}
fn engine::Event prepare(ref mut engine::Engine e,usize i,usize p,usize limit){
    let usize before=instance(e).current;let usize charge=id(engine::required_pending_bytes(e,p,limit));
    let engine::Event pending=event(engine::prepare_instance(e,i));
    assert(pending.kind==4 && pending.value==0 && pending.fuel_known && pending.diagnostic.code.kind==0);
    same_event(pending,event(engine::observe(e,i)));ledger(e,before+charge);return pending;
}
// Deny even the first SDK allocation on every resume, including terminal seal.
fn engine::Event tick(ref mut engine::Engine e,usize i,usize quantum){
    let engine::Event before=event(engine::observe(e,i));assert(before.kind==4);
    let Heap h=heap();let usize attempts=unsafe{probe_attempts()};let usize charge=instance(e).current;
    unsafe{bc_runtime_engine_test_fail(0)};
    let Result<engine::Event,engine::Error> r=engine::step_instance(e,i,quantum);
    unsafe{bc_runtime_engine_test_fail(-1)};
    let engine::Event after=event(r);assert(unsafe{probe_attempts()}==attempts);
    assert(after.kind==4 || after.kind==1 || after.kind==2);
    assert(after.fuel_known && after.remaining<=before.remaining);
    same_event(after,event(engine::observe(e,i)));
    if(after.kind==4){same_heap(ref h);ledger(e,charge);assert(after.value==0 && after.diagnostic.code.kind==0);}
    return after;
}
fn engine::Event finish(ref mut engine::Engine e,usize i,usize quantum){
    var engine::Event state=event(engine::observe(e,i));var usize calls=0;
    while(state.kind==4){assert(calls<10000);state=tick(e,i,quantum);calls+=1;}return state;
}
fn void sealed_balance(ref engine::Engine e,ref Heap ready,usize input,bool success,usize limit){
    let usize bytes=576+if(success){limit}else{0};ledger(e,input+bytes);
    assert(unsafe{probe_live_bytes()}==ready.bytes+bytes);
    assert(unsafe{probe_live()}==ready.blocks+1+if(success && limit!=0){1}else{0});
}
fn void frozen(ref mut engine::Engine e,usize i,engine::Event first){
    let Heap h=heap();let usize attempts=unsafe{probe_attempts()};
    let live::Observation l=instance(e);let memory::Observation m=retained(e);var usize n=0;
    while(n<2){
        rejected(engine::step_instance(e,i,1),11);rejected(engine::step_instance(e,i,4096),11);
        rejected(engine::execute_once(e,i),11);same_event(first,event(engine::cancel_ready(e,i)));
        same_event(first,event(engine::observe(e,i)));n+=1;
    }
    assert(unsafe{probe_attempts()}==attempts);same_heap(ref h);unchanged(e,l,m);
}
fn void invalid(ref mut engine::Engine e,usize i){
    let engine::Event before=event(engine::observe(e,i));let Heap h=heap();
    let live::Observation l=instance(e);let memory::Observation m=retained(e);
    let usize attempts=unsafe{probe_attempts()};let usize[3] quanta=[0,4097,18446744073709551615];
    var usize n=0;while(n<quanta.len){
        rejected(engine::step_instance(e,i,quanta[n]),1);
        same_event(before,event(engine::observe(e,i)));same_heap(ref h);unchanged(e,l,m);n+=1;
    }
    assert(unsafe{probe_attempts()}==attempts);
}

// Group 1: fixed and mixed dispatch budgets, CALL/RET, array places and binary
// input. Lockstep with the saved carrier detects over-dispatch before terminal.
fn Result<usize,u8> fixed_and_mixed_quanta(){
    let ref u8[] source=b"module app;fn ref u8[] tail(ref u8[] data){return data[1..];}fn i32 rhs(){return 42;}pub fn i32 chosen(ref u8[] data){var a=[0,0];a[1]=rhs();var i32 n=0;while(n<4){let ref u8[] part=tail(ref data);output::emit(ref part);n+=1;}return a[1];}";
    let programs::Program code=switch(programs::compile_input(selected_input(source)?,65536)){
        case .ok(v):{v}case .err(_):{return .err(10);}
    };
    let inputs::Snapshot input=captured(b"!\x00I")?;
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,source,true)?;
    let engine::Output baseline=synchronous(ref mut e,p,b"!\x00I",16000000,16)?;
    assert(completion(ref baseline).kind==1 && completion(ref baseline).value==42);
    assert(bytes::equal(engine::output_view(ref baseline),b"\x00I\x00I\x00I\x00I"));
    let usize[6] quanta=[1,2,3,7,64,4096];var usize variant=0;
    while(variant<7){
        var machine::Machine oracle=switch(engine::prepare_pending_output(ref code,ref input,16000000,16,true)){
            case .ok(v):{v}case .err(_):{return .err(11);}
        };
        let usize i=bound(ref mut e,p,b"!\x00I",16000000,16)?;
        let usize input_charge=instance(ref e).current;let Heap ready=heap();
        var engine::Event state=prepare(ref mut e,i,p,16);
        assert(state.remaining==machine::observe(ref oracle).remaining);var usize calls=0;
        while(state.kind==4){
            assert(calls<10000);let usize q=if(variant==6){quanta[calls%6]}else{quanta[variant]};
            let machine::Meta before=machine::observe(ref oracle);
            let machine::Meta expected=switch(engine::advance_pending_output(ref mut oracle,ref code,ref input,q)){
                case .ok(v):{v}case .err(_):{return .err(12);}
            };
            assert(expected.stats.last<=q && expected.stats.calls==before.stats.calls+1);
            assert(expected.stats.dispatched==before.stats.dispatched+expected.stats.last);
            state=tick(ref mut e,i,q);calls+=1;
            if(expected.phase==1){assert(state.kind==4 && state.remaining==expected.remaining && expected.stats.last>0 && expected.stats.last<=q);}
            else{assert(expected.phase==2 && state.kind==1 && state.remaining+meter::output_seal()==expected.remaining);}
        }
        if(variant==5){assert(calls>1);}if(variant==0){assert(calls>2);}
        same_event(state,completion(ref baseline));sealed_balance(ref e,ref ready,input_charge,true,16);
        frozen(ref mut e,i,state);let engine::Output result=take(ref mut e,i)?;
        ledger(ref e,input_charge);rejected_take(engine::take_output(ref mut e,i),2);
        output_matches(ref result,ref baseline);destroy(ref mut e,i);ledger(ref e,0);
        output_matches(ref result,ref baseline);variant+=1;
    }
    release(ref mut e,p);close(ref mut e);assert(inputs::view(ref input).len==3);return .ok(0);
}

// Group 2: invalid calls preserve Ready and running VMs, then completion still
// agrees with execute_once. A synchronous terminal also rejects step.
fn Result<usize,u8> wrong_state_and_invalid_quanta(){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);var i32 n=0;while(n<64){n+=1;}return 42;}";
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,source,true)?;
    let engine::Output baseline=synchronous(ref mut e,p,b"prefix",16000000,9)?;
    let usize i=bound(ref mut e,p,b"prefix",16000000,9)?;
    let engine::Event ready=event(engine::observe(ref mut e,i));let Heap h=heap();
    let live::Observation ready_memory=instance(ref e);let memory::Observation ready_retained=retained(ref e);
    let usize attempts=unsafe{probe_attempts()};
    rejected(engine::step_instance(ref mut e,i,1),3);same_event(ready,event(engine::observe(ref mut e,i)));
    same_heap(ref h);unchanged(ref e,ready_memory,ready_retained);
    assert(unsafe{probe_attempts()}==attempts);invalid(ref mut e,i);
    let engine::Event pending=prepare(ref mut e,i,p,9);invalid(ref mut e,i);
    rejected(engine::prepare_instance(ref mut e,i),3);rejected(engine::execute_once(ref mut e,i),3);
    same_event(pending,event(engine::observe(ref mut e,i)));rejected_take(engine::take_output(ref mut e,i),11);
    var usize n=0;while(n<32){assert(tick(ref mut e,i,1).kind==4);n+=1;}invalid(ref mut e,i);
    let engine::Event done=finish(ref mut e,i,7);same_event(done,completion(ref baseline));frozen(ref mut e,i,done);
    let engine::Output result=take(ref mut e,i)?;output_matches(ref result,ref baseline);destroy(ref mut e,i);
    let usize sync=bound(ref mut e,p,b"prefix",16000000,9)?;
    let engine::Event synchronous_done=event(engine::execute_once(ref mut e,sync));frozen(ref mut e,sync,synchronous_done);
    destroy(ref mut e,sync);rejected(engine::step_instance(ref mut e,sync,1),2);
    let usize cancelled=bound(ref mut e,p,b"prefix",16000000,9)?;
    let engine::Event stopped=event(engine::cancel_ready(ref mut e,cancelled));frozen(ref mut e,cancelled,stopped);
    destroy(ref mut e,cancelled);release(ref mut e,p);close(ref mut e);return .ok(0);
}

// Group 3: independent saved states survive two Engine moves and released pins.
// Taking/destroying a middle owner must not alter still-running peers.
fn Result<usize,u8> interleaved_moves_and_detached_output(){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){var i32 n=0;while(n<12){n+=1;}output::emit(ref data);return 42;}";
    var engine::Engine original=created()?;let usize p=compiled(ref mut original,source,true)?;
    let engine::Output baseline=synchronous(ref mut original,p,b"B\x00",16000000,7)?;
    let usize a=bound(ref mut original,p,b"A\xFF",16000000,5)?;
    let usize before_b=instance(ref original).current;
    let usize b=bound(ref mut original,p,b"B\x00",16000000,7)?;
    let usize b_input=instance(ref original).current-before_b;
    let usize c=bound(ref mut original,p,b"C!",16000000,9)?;
    let usize inputs_charge=instance(ref original).current;
    let engine::Event pa=prepare(ref mut original,a,p,5);
    let engine::Event pb=prepare(ref mut original,b,p,7);
    let engine::Event pc=prepare(ref mut original,c,p,9);
    release(ref mut original,p);var engine::Engine moved=original;counts(ref mut moved,1,3,3);
    assert(tick(ref mut moved,a,1).kind==4);same_event(pb,event(engine::observe(ref mut moved,b)));
    assert(tick(ref mut moved,b,2).kind==4);same_event(pc,event(engine::observe(ref mut moved,c)));
    assert(tick(ref mut moved,c,3).kind==4);let engine::Event ea=event(engine::observe(ref mut moved,a));
    assert(ea.remaining<pa.remaining);var engine::Engine e=moved;
    let engine::Event eb=finish(ref mut e,b,7);same_event(eb,completion(ref baseline));
    same_event(ea,event(engine::observe(ref mut e,a)));let engine::Event ec_pending=event(engine::observe(ref mut e,c));
    let engine::Output middle=take(ref mut e,b)?;output_matches(ref middle,ref baseline);
    rejected_take(engine::take_output(ref mut e,b),2);frozen(ref mut e,b,eb);destroy(ref mut e,b);
    same_event(ec_pending,event(engine::observe(ref mut e,c)));counts(ref mut e,1,2,2);
    let engine::Event ec=finish(ref mut e,c,1);let engine::Event done_a=finish(ref mut e,a,4096);
    assert(ec.kind==1 && done_a.kind==1);frozen(ref mut e,c,ec);frozen(ref mut e,a,done_a);
    let engine::Output tail=take(ref mut e,c)?;let engine::Output front=take(ref mut e,a)?;
    assert(bytes::equal(engine::output_view(ref tail),b"C!") && bytes::equal(engine::output_view(ref front),b"A\xFF"));
    ledger(ref e,inputs_charge-b_input);destroy(ref mut e,c);destroy(ref mut e,a);
    ledger(ref e,0);counts(ref mut e,0,0,0);close(ref mut e);
    output_matches(ref middle,ref baseline);assert(bytes::equal(engine::output_view(ref front),b"A\xFF"));
    assert(bytes::equal(engine::output_view(ref tail),b"C!"));return .ok(0);
}

// Group 4: emit executes before the long loop. Cancellation drops the staged
// prefix, Core/Machine/scratch and publication slot but retains bound input.
fn Result<usize,u8> running_cancel_refund_and_first_cause(){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);var a=[1,2];var i32 n=0;while(n<64){a[0]+=1;n+=1;}return a[0];}";
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,source,true)?;
    let usize i=bound(ref mut e,p,b"prefix",16000000,12)?;
    let usize input=instance(ref e).current;let Heap ready=heap();let engine::Event pending=prepare(ref mut e,i,p,12);
    var usize n=0;while(n<64){assert(tick(ref mut e,i,1).kind==4);n+=1;}
    let engine::Event running=event(engine::observe(ref mut e,i));assert(running.remaining<pending.remaining);
    rejected_take(engine::take_output(ref mut e,i),11);let usize attempts=unsafe{probe_attempts()};
    let engine::Event stopped=event(engine::cancel_ready(ref mut e,i));
    assert(stopped.kind==3 && stopped.value==0 && stopped.fuel_known && stopped.remaining==running.remaining);
    assert(stopped.diagnostic.code.kind==0 && unsafe{probe_attempts()}==attempts);
    same_heap(ref ready);ledger(ref e,input);frozen(ref mut e,i,stopped);rejected_take(engine::take_output(ref mut e,i),2);
    destroy(ref mut e,i);ledger(ref e,0);release(ref mut e,p);close(ref mut e);return .ok(0);
}

fn Result<engine::Event,u8> parity(ref u8[] source,ref u8[] data,usize budget,usize limit,usize quantum,u8 kind,u8 error,usize emits){
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,source,true)?;
    let engine::Output baseline=synchronous(ref mut e,p,data,budget,limit)?;
    assert(completion(ref baseline).kind==kind && completion(ref baseline).diagnostic.code.kind==error);
    assert(engine::output_completion(ref baseline).emits==emits);
    let usize i=bound(ref mut e,p,data,budget,limit)?;let usize input=instance(ref e).current;
    let Heap ready=heap();let engine::Event pending=prepare(ref mut e,i,p,limit);
    assert(pending.remaining<=budget);let engine::Event done=finish(ref mut e,i,quantum);
    same_event(done,completion(ref baseline));sealed_balance(ref e,ref ready,input,kind==1,limit);
    frozen(ref mut e,i,done);let engine::Output result=take(ref mut e,i)?;
    ledger(ref e,input);output_matches(ref result,ref baseline);rejected_take(engine::take_output(ref mut e,i),2);
    destroy(ref mut e,i);ledger(ref e,0);release(ref mut e,p);close(ref mut e);
    output_matches(ref result,ref baseline);
    if(kind==2){assert(!engine::output_available(ref result) && engine::output_view(ref result).len==0);}
    return .ok(done);
}
// Group 5: trap diagnostics retain offsets/spans and the emitted prefix never
// escapes. Exact Fuel succeeds; one less fails at seal; less again at dispatch.
fn Result<usize,u8> failures_and_exact_fuel(){
    let ref u8[] trap=b"module app;fn i32 divisor(ref u8[] data){return data[0] as i32;}pub fn i32 chosen(ref u8[] data){output::emit(ref b\"prefix\");return 42/divisor(ref data);}";
    let engine::Event failed=parity(trap,b"\x00",16000000,16,1,2,7,1)?;
    assert(failed.diagnostic.code.offset!=0 && failed.remaining>0);
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);var i32 n=0;while(n<64){n+=1;}return 42;}";
    var usize price=0;
    {
        var engine::Engine e=created()?;let usize p=compiled(ref mut e,source,true)?;
        let engine::Output full=synchronous(ref mut e,p,b"prefix",16000000,16)?;
        assert(completion(ref full).kind==1);price=16000000-completion(ref full).remaining;
        release(ref mut e,p);close(ref mut e);
    }
    assert(price>meter::output_seal()+17);
    let engine::Event exact=parity(source,b"prefix",price,16,1,1,0,1)?;
    assert(exact.remaining==0 && exact.value==42);
    let engine::Event seal=parity(source,b"prefix",price-1,16,4096,2,8,1)?;
    assert(seal.diagnostic.code.offset==0 && seal.remaining==meter::output_seal()-1);
    let engine::Event dispatch=parity(source,b"prefix",price-meter::output_seal()-17,16,7,2,8,1)?;
    assert(dispatch.diagnostic.code.offset!=0);
    let engine::Event quota=parity(source,b"prefix",16000000,5,2,2,20,0)?;
    assert(quota.diagnostic.code.offset!=0);return .ok(0);
}

// Group 6: zero output capacity still keeps the normal publication Vec on
// success. Ordinary Engine destruction also reclaims a genuinely running VM.
fn Result<usize,u8> empty_output_and_running_drop(){
    let ref u8[] quiet=b"module app;pub fn i32 chosen(ref u8[] data){return 42;}";
    let engine::Event done=parity(quiet,b"",16000000,0,4096,1,0,0)?;assert(done.value==42);
    let Heap before=heap();
    {
        var engine::Engine e=created()?;
        let usize p=compiled(ref mut e,b"module app;pub fn i32 chosen(){output::emit(ref b\"prefix\");var i32 n=0;while(n<64){n+=1;}return 42;}",false)?;
        let usize i=id(engine::create_output_instance(ref mut e,p,16000000,12,true));
        let engine::Event pending=prepare(ref mut e,i,p,12);release(ref mut e,p);
        var usize n=0;while(n<32){assert(tick(ref mut e,i,1).kind==4);n+=1;}
        assert(event(engine::observe(ref mut e,i)).remaining<pending.remaining);counts(ref mut e,1,1,1);
    }
    same_heap(ref before);return .ok(0);
}
pub fn void run(){
    let Heap before=heap();
    assert(fixed_and_mixed_quanta().is_ok);same_heap(ref before);
    assert(wrong_state_and_invalid_quanta().is_ok);same_heap(ref before);
    assert(interleaved_moves_and_detached_output().is_ok);same_heap(ref before);
    assert(running_cancel_refund_and_first_cause().is_ok);same_heap(ref before);
    assert(failures_and_exact_fuel().is_ok);same_heap(ref before);
    assert(empty_output_and_running_drop().is_ok);same_heap(ref before);
}
