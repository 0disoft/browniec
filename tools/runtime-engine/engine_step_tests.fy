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
import engine_lifecycle_tests as lifecycle;
import runtime_policy as policy;
import runtime_run_config as configs;
import project_manifest as projects;
import anchored_source_loader as anchored;
import literal_collection as literals;
import literal_source as literal_source;
import static_image as images;
import source_context as context;

// Engine.step fixtures only. The parent owns native transport and integration.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void bc_runtime_engine_test_proof_begin();
unsafe extern C fn void bc_runtime_engine_test_expire_in_proof(usize deadline);
unsafe extern C fn void bc_runtime_engine_test_expire_in_context(usize deadline);
unsafe extern C fn usize bc_runtime_engine_test_context_bytes();
unsafe extern C fn void bc_runtime_engine_test_expire_in_literal(usize deadline);
unsafe extern C fn void bc_runtime_engine_test_literal_stopped();
unsafe extern C fn void bc_runtime_engine_test_expire_in_signature(usize deadline,u32 pass);
unsafe extern C fn void bc_runtime_engine_test_signature_stopped();
unsafe extern C fn void bc_runtime_engine_test_expire_in_origin(usize deadline,u32 pass);
unsafe extern C fn void bc_runtime_engine_test_origin_stopped();
unsafe extern C fn void bc_runtime_engine_test_expire_in_body(usize deadline);
unsafe extern C fn void bc_runtime_engine_test_body_stopped();
unsafe extern C fn usize bc_runtime_engine_test_proof_count();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
unsafe extern C fn void bc_runtime_engine_test_inject_cleanup_fault();
unsafe extern C fn void bc_runtime_engine_test_inject_output_fault(u32 stage);
unsafe extern C fn usize bc_runtime_engine_test_project_path(ptr mut u8 out,usize capacity);
unsafe extern C fn usize bc_runtime_engine_monotonic_ticks();
unsafe extern C fn void bc_runtime_engine_test_set_clock(usize ticks);
unsafe extern C fn void bc_runtime_engine_test_clock_advance(usize read,usize ticks);
unsafe extern C fn usize bc_runtime_engine_test_handle_count();
unsafe extern C fn void bc_runtime_engine_test_use_os_clock();
unsafe extern C fn void bc_runtime_engine_test_wait_for_clock(usize start,usize elapsed);
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
fn u8 state_number(engine::InstanceState state){
    return switch(state){
        case .Ready:{0}case .Running:{1}case .WaitingHost:{2}case .Stopping:{3}case .Terminal:{4}
    };
}
fn engine::Event status_event(ref engine::Engine e,usize i,engine::InstanceState expected){
    return switch(engine::instance_status(e,i)){
        case .ok(v):{assert(state_number(v.state)==state_number(expected));v.event}
        case .err(e):{event(.err(e))}
    };
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
        same_event(first,event(engine::observe(e,i)));
        same_event(first,status_event(e,i,.Terminal));n+=1;
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
    lifecycle::warm(ref mut moved,a);
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
    let usize input=instance(ref e).current;let Heap ready=heap();
    same_event(event(engine::observe(ref mut e,i)),status_event(ref e,i,.Ready));
    let engine::Event pending=prepare(ref mut e,i,p,12);
    lifecycle::warm(ref mut e,i);
    var usize n=0;while(n<64){assert(tick(ref mut e,i,1).kind==4);n+=1;}
    let engine::Event running=event(engine::observe(ref mut e,i));assert(running.remaining<pending.remaining);
    rejected_take(engine::take_output(ref mut e,i),11);let usize attempts=unsafe{probe_attempts()};
    let engine::Event stopped=lifecycle::stop(ref mut e,i);
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
    assert(pending.remaining<=budget);var engine::Event done=pending;
    if(kind==2){
        // Once failure is latched, repeated cancellation must preserve its
        // diagnostic and Fuel and finish cleanup, rather than spin Pending.
        var usize visits=0;while(done.kind==4){assert(visits<8192);
            let usize phase=id(engine::lifecycle_phase(ref e,i));
            if(phase>=7){let usize fuel=done.remaining;let usize attempts=unsafe{probe_attempts()};
                same_event(completion(ref baseline),status_event(ref e,i,.Stopping));
                rejected_take(engine::take_output(ref mut e,i),11);
                unsafe{bc_runtime_engine_test_fail(0)};let Result<engine::Event,engine::Error> stopped=engine::cancel_ready(ref mut e,i);
                unsafe{bc_runtime_engine_test_fail(-1)};done=event(stopped);
                assert(done.remaining==fuel && unsafe{probe_attempts()}==attempts);
            }else{done=tick(ref mut e,i,quantum);}visits+=1;
        }
    }else{done=finish(ref mut e,i,quantum);}
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
        lifecycle::warm(ref mut e,i);
        var usize n=0;while(n<32){assert(tick(ref mut e,i,1).kind==4);n+=1;}
        assert(event(engine::observe(ref mut e,i)).remaining<pending.remaining);counts(ref mut e,1,1,1);
    }
    same_heap(ref before);return .ok(0);
}

fn Result<policy::Policy,u8> output_policy(bool allow){
    return switch(policy::parse(if(allow){b"{\"schema\":\"brownie.policy/0.3\",\"compile\":{\"source_bytes\":262144,\"modules\":32,\"depth\":128,\"tokens\":131072,\"functions\":4096,\"types\":4096,\"instructions\":262144,\"registers_per_function\":1024,\"working_bytes\":67108864,\"fuel\":10000000,\"deadline_ms\":2000,\"diagnostics\":32},\"engine\":{\"memory_bytes\":134217728,\"control_bytes\":1048576,\"program_bytes\":8388608,\"total_program_bytes\":67108864,\"instances_bytes\":67108864,\"max_programs\":64,\"max_instances\":64,\"max_compiles\":1},\"run\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000},\"worker\":{\"memory_bytes\":201326592,\"user_cpu_time_ms\":5000,\"max_processes\":1,\"transport_bytes\":4194304,\"startup_ms\":2000,\"io_idle_ms\":1000,\"shutdown_grace_ms\":250,\"session_ms\":10000},\"capabilities\":[\"brownie.output.emit\"]}"}else{b"{\"schema\":\"brownie.policy/0.3\",\"compile\":{\"source_bytes\":262144,\"modules\":32,\"depth\":128,\"tokens\":131072,\"functions\":4096,\"types\":4096,\"instructions\":262144,\"registers_per_function\":1024,\"working_bytes\":67108864,\"fuel\":10000000,\"deadline_ms\":2000,\"diagnostics\":32},\"engine\":{\"memory_bytes\":134217728,\"control_bytes\":1048576,\"program_bytes\":8388608,\"total_program_bytes\":67108864,\"instances_bytes\":67108864,\"max_programs\":64,\"max_instances\":64,\"max_compiles\":1},\"run\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":1048576,\"output_bytes\":1048576,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000},\"worker\":{\"memory_bytes\":201326592,\"user_cpu_time_ms\":5000,\"max_processes\":1,\"transport_bytes\":4194304,\"startup_ms\":2000,\"io_idle_ms\":1000,\"shutdown_grace_ms\":250,\"session_ms\":10000},\"capabilities\":[]}"})){
        case .ok(v):{.ok(v)}case .err(_):{.err(1)}
    };
}
fn Result<configs::RunConfig,u8> run_config(ref policy::Policy ceiling,usize which){
    let ref u8[] source=if(which==0){b"{\"schema\":\"brownie.run/0.3\",\"entry\":{\"module\":\"app\",\"function\":\"chosen\"},\"requires\":[\"brownie.output.emit\"],\"grants\":[\"brownie.output.emit\"],\"limits\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":2,\"output_bytes\":2,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000}}"}else if(which==1){b"{\"schema\":\"brownie.run/0.3\",\"entry\":{\"module\":\"app\",\"function\":\"chosen\"},\"requires\":[],\"grants\":[\"brownie.output.emit\"],\"limits\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":2,\"output_bytes\":2,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000}}"}
        else if(which==2){b"{\"schema\":\"brownie.run/0.3\",\"entry\":{\"module\":\"app\",\"function\":\"other\"},\"requires\":[\"brownie.output.emit\"],\"grants\":[\"brownie.output.emit\"],\"limits\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":2,\"output_bytes\":2,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":10000000,\"deadline_ms\":1000}}"}else{b"{\"schema\":\"brownie.run/0.3\",\"entry\":{\"module\":\"app\",\"function\":\"chosen\"},\"requires\":[\"brownie.output.emit\"],\"grants\":[\"brownie.output.emit\"],\"limits\":{\"memory_bytes\":16777216,\"object_bytes\":4194304,\"call_frames\":128,\"input_bytes\":2,\"output_bytes\":1,\"host_request_bytes\":1048576,\"host_response_bytes\":1048576,\"host_calls\":256,\"owner_entries\":16384,\"descriptor_entries\":16384,\"fuel\":7000000,\"deadline_ms\":1000}}"};
    return switch(configs::parse(source,ceiling)){
        case .ok(v):{.ok(v)}case .err(_):{.err(2)}
    };
}
fn Result<engine::Engine,u8> configured_engine(policy::Policy ceiling){
    return switch(engine::create_with_policy(ceiling)){
        case .ok(v):{.ok(v)}case .err(_):{.err(3)}
    };
}
fn void rejected_id(Result<usize,engine::Error> r,u32 status){
    switch(r){case .ok(_):{assert(false);}case .err(failure):{assert(failure.status==status);}};
}
fn Result<usize,u8> configured_output(){
    let policy::Policy ceiling=output_policy(true)?;
    let configs::RunConfig granted=run_config(ref ceiling,0)?;
    let configs::RunConfig missing=run_config(ref ceiling,1)?;
    let configs::RunConfig other=run_config(ref ceiling,2)?;
    let configs::RunConfig narrow=run_config(ref ceiling,3)?;
    let ref u8[] source=b"module app;fn void send(ref u8[] data){output::emit(ref data);}pub fn i32 other(ref u8[] data){return 0;}pub fn i32 chosen(ref u8[] data){send(ref data);return 42;}";
    {
        var engine::Engine denied=configured_engine(output_policy(false)?)?;
        rejected_id(engine::compile_granted_output(ref mut denied,indexed(source)?,ref granted,65536),5);
        counts(ref mut denied,0,0,0);
        close(ref mut denied);
    }
    var engine::Engine e=configured_engine(ceiling)?;
    let Heap idle=heap();
    unsafe{bc_runtime_engine_test_proof_begin()};
    let usize p=id(engine::compile_granted_output(ref mut e,indexed(source)?,ref granted,65536));
    let usize proofs=unsafe{bc_runtime_engine_test_proof_count()};
    assert(proofs==1);
    counts(ref mut e,1,0,0);
    let Heap retained=heap();
    rejected_id(engine::prepare_granted_instance(ref mut e,p,ref missing,captured(b"AB")?),5);
    rejected_id(engine::prepare_granted_instance(ref mut e,p,ref other,captured(b"AB")?),5);
    rejected_id(engine::prepare_granted_instance(ref mut e,p,ref granted,captured(b"ABC")?),8);
    rejected_id(engine::create_input_output_instance(ref mut e,p,captured(b"AB")?,10000000,2,true),5);
    counts(ref mut e,1,0,0);
    same_heap(ref retained);
    let usize i=id(engine::prepare_granted_instance(ref mut e,p,ref granted,captured(b"A\x00")?));
    let usize j=id(engine::prepare_granted_instance(ref mut e,p,ref narrow,captured(b"Z")?));
    counts(ref mut e,1,2,2);
    assert(event(engine::observe(ref mut e,i)).remaining==10000000-meter::output_prepare(2)-meter::input_prepare());
    assert(event(engine::observe(ref mut e,j)).remaining==7000000-meter::output_prepare(1)-meter::input_prepare());
    release(ref mut e,p);
    rejected_id(engine::prepare_granted_instance(ref mut e,p,ref granted,captured(b"OK")?),2);
    assert(tick(ref mut e,i,1).kind==4);
    assert(tick(ref mut e,j,1).kind==4);
    let engine::Event second=finish(ref mut e,j,2);
    let engine::Event first=finish(ref mut e,i,1);
    assert(first.kind==1 && second.kind==1 && first.value==42 && second.value==42);
    {
        let engine::Output first_output=take(ref mut e,i)?;
        let engine::Output second_output=take(ref mut e,j)?;
        assert(bytes::equal(engine::output_view(ref first_output),b"A\x00"));
        assert(bytes::equal(engine::output_view(ref second_output),b"Z"));
    }
    assert(unsafe{bc_runtime_engine_test_proof_count()}==proofs);
    destroy(ref mut e,j);
    counts(ref mut e,1,1,1);
    destroy(ref mut e,i);
    counts(ref mut e,0,0,0);
    same_heap(ref idle);
    close(ref mut e);
    return .ok(0);
}

fn Result<projects::Project,u8> project(ref u8[] source){
    return switch(projects::parse(source)){case .ok(v):{.ok(v)}case .err(_):{.err(4)}};
}
fn Result<usize,u8> anchored_output(ref mut engine::Engine e,ref u8[] root,
    ref configs::RunConfig granted,ref configs::RunConfig omitted,ref configs::RunConfig wrong_entry){
    var bytes::Buffer path=bytes::empty();
    if(!bytes::append(ref mut path,root).is_ok || !bytes::append(ref mut path,b"\\output.json").is_ok){return .err(4);}
    var u8[512] data=[0;512];
    var anchored::Root anchor=switch(anchored::open_project(bytes::view(ref path),ref mut data[..])){
        case .ok(v):{v}case .err(_):{return .err(4);}
    };
    let projects::Project manifest=project(ref data[..anchored::manifest_bytes(ref anchor)])?;
    rejected_id(engine::compile_anchored_project_output(e,ref manifest,ref mut anchor,omitted,65536),5);
    rejected_id(engine::compile_anchored_project_output(e,ref manifest,ref mut anchor,wrong_entry,65536),5);
    let usize program=id(engine::compile_anchored_project_output(e,ref manifest,ref mut anchor,granted,65536));
    rejected_id(engine::compile_anchored_project_output(e,ref manifest,ref mut anchor,granted,65536),1);
    return .ok(program);
}
fn Result<usize,u8> project_output(){
    let ref u8[] declared=b"{\"schema\":\"brownie.project/0.3\",\"name\":\"fixture\",\"entry\":{\"module\":\"app\",\"function\":\"chosen\"},\"sources\":[{\"module\":\"app\",\"path\":\"output.brc\"}],\"requires\":[\"brownie.output.emit\"]}";
    let ref u8[] undeclared=b"{\"schema\":\"brownie.project/0.3\",\"name\":\"fixture\",\"entry\":{\"module\":\"app\",\"function\":\"chosen\"},\"sources\":[{\"module\":\"app\",\"path\":\"output.brc\"}],\"requires\":[]}";
    let ref u8[] quiet=b"{\"schema\":\"brownie.project/0.3\",\"name\":\"fixture\",\"entry\":{\"module\":\"app\",\"function\":\"chosen\"},\"sources\":[{\"module\":\"app\",\"path\":\"quiet.brc\"}],\"requires\":[\"brownie.output.emit\"]}";
    let projects::Project unfinished=project(b"{\"schema\":\"brownie.project/0.3\",\"name\":\"fixture\",\"entry\":{\"module\":\"app\",\"function\":\"chosen\"},\"sources\":[{\"module\":\"app\",\"path\":\"output.brc\"},{\"module\":\"missing\",\"path\":\"absent.brc\"}],\"requires\":[\"brownie.output.emit\"]}")?;
    let projects::Project manifest=project(declared)?;
    let projects::Project missing=project(undeclared)?;
    let projects::Project quiet_manifest=project(quiet)?;
    let policy::Policy ceiling=output_policy(true)?;
    let configs::RunConfig granted=run_config(ref ceiling,0)?;
    let configs::RunConfig omitted=run_config(ref ceiling,1)?;
    let configs::RunConfig wrong_entry=run_config(ref ceiling,2)?;
    let configs::RunConfig narrow=run_config(ref ceiling,3)?;
    {
        var engine::Engine denied=configured_engine(output_policy(false)?)?;
        rejected_id(engine::compile_project_output(ref mut denied,ref manifest,b"",ref granted,65536),5);
        close(ref mut denied);
    }
    var engine::Engine e=configured_engine(ceiling)?;
    let Heap idle=heap();
    var u8[3072] path=[0;3072];
    let usize length=unsafe{bc_runtime_engine_test_project_path(ref mut path[..] as ptr mut u8,3072)};
    let ref u8[] root=ref path[..length];
    rejected_id(engine::compile_project_output(ref mut e,ref manifest,b"",ref omitted,65536),5);
    rejected_id(engine::compile_project_output(ref mut e,ref manifest,b"",ref wrong_entry,65536),5);
    rejected_id(engine::compile_project_output(ref mut e,ref manifest,b"",ref granted,65536),1);
    rejected_id(engine::compile_project_output(ref mut e,ref missing,root,ref omitted,65536),5);
    counts(ref mut e,0,0,0);
    same_heap(ref idle);
    unsafe{bc_runtime_engine_test_set_clock(100)};
    rejected_id(engine::compile_project_output(ref mut e,ref unfinished,root,ref granted,65536),1);
    let usize handles=unsafe{bc_runtime_engine_test_handle_count()};
    // The fourth sample is between the real first file and the missing second.
    unsafe{bc_runtime_engine_test_clock_advance(4,20000100)};
    rejected_compile_deadline(engine::compile_project_output(ref mut e,ref unfinished,root,ref granted,65536));
    assert(unsafe{bc_runtime_engine_test_handle_count()}==handles);
    counts(ref mut e,0,0,0);same_heap(ref idle);
    // A separate deadline expires before the first source context batch.
    unsafe{bc_runtime_engine_test_clock_advance(8,40000100)};
    rejected_compile_deadline(engine::compile_project_output(ref mut e,ref manifest,root,ref granted,65536));
    assert(unsafe{bc_runtime_engine_test_handle_count()}==handles);
    unsafe{bc_runtime_engine_test_use_os_clock()};
    counts(ref mut e,0,0,0);same_heap(ref idle);
    let usize q=id(engine::compile_project_output(ref mut e,ref quiet_manifest,root,ref granted,65536));
    assert(q==1);
    rejected_id(engine::prepare_granted_instance(ref mut e,q,ref omitted,captured(b"")?),5);
    let usize quiet_run=id(engine::prepare_granted_instance(ref mut e,q,ref granted,captured(b"")?));
    let engine::Event quiet_event=finish(ref mut e,quiet_run,2);
    assert(quiet_event.kind==1 && quiet_event.value==0);
    release(ref mut e,q);
    destroy(ref mut e,quiet_run);
    let usize p=anchored_output(ref mut e,root,ref granted,ref omitted,ref wrong_entry)?;
    rejected_id(engine::prepare_granted_instance(ref mut e,p,ref omitted,captured(b"A")?),5);
    let usize i=id(engine::prepare_granted_instance(ref mut e,p,ref granted,captured(b"A\x00")?));
    let usize j=id(engine::prepare_granted_instance(ref mut e,p,ref narrow,captured(b"Z")?));
    counts(ref mut e,1,2,2);
    release(ref mut e,p);
    let engine::Event first=finish(ref mut e,i,1);
    let engine::Event second=finish(ref mut e,j,2);
    assert(first.kind==1 && first.value==2 && second.kind==1 && second.value==1);
    {
        let engine::Output a=take(ref mut e,i)?;
        let engine::Output b=take(ref mut e,j)?;
        assert(bytes::equal(engine::output_view(ref a),b"A\x00"));
        assert(bytes::equal(engine::output_view(ref b),b"Z"));
    }
    destroy(ref mut e,i);
    destroy(ref mut e,j);
    counts(ref mut e,0,0,0);
    same_heap(ref idle);
    close(ref mut e);
    return .ok(0);
}
fn void rejected_compile_deadline(Result<usize,engine::Error> r){
    switch(r){
        case .ok(_):{assert(false);}
        case .err(failure):{assert(failure.status==4 && failure.diagnostic.code.kind==errors::deadline_kind() &&
            failure.diagnostic.code.location==errors::absent_location() && failure.diagnostic.at.source==sources::no_source().source);}
    };
}
fn Result<usize,u8> compile_deadline(ref mut engine::Engine e,ref configs::RunConfig run){
    let ref u8[] ordinary=b"module app;pub fn i32 chosen(){return 42;}";
    let ref u8[] input=b"module app;pub fn i32 chosen(ref u8[] data){return 42;}";
    let Heap idle=heap();
    var usize mode=0;
    while(mode<4){
        unsafe{bc_runtime_engine_test_set_clock(100+mode*20000000)};
        unsafe{bc_runtime_engine_test_clock_advance(3,100+(mode+1)*20000000)};
        let Result<usize,engine::Error> result=if(mode==0){engine::compile(e,selected(ordinary)?,65536)}
            else if(mode==1){engine::compile_input(e,selected_input(input)?,65536)}
            else if(mode==2){engine::compile_output(e,selected(ordinary)?,65536)}
            else{engine::compile_granted_output(e,indexed(input)?,run,65536)};
        rejected_compile_deadline(result);
        counts(e,0,0,0);same_heap(ref idle);
        assert(retained(e).program_bytes==0);
        mode+=1;
    }
    // Advance to the exact deadline from inside the canonical proof. Both
    // variants must stop at the next proof boundary and reclaim the image.
    mode=2;
    while(mode<4){
        let usize start=100+(mode+3)*20000000;
        unsafe{bc_runtime_engine_test_set_clock(start)};
        unsafe{bc_runtime_engine_test_proof_begin()};
        unsafe{bc_runtime_engine_test_expire_in_proof(start+20000000)};
        let Result<usize,engine::Error> result=if(mode==2){engine::compile_output(e,selected(ordinary)?,65536)}
            else{engine::compile_granted_output(e,indexed(input)?,run,65536)};
        rejected_compile_deadline(result);
        assert(unsafe{bc_runtime_engine_test_proof_count()}==1);
        counts(e,0,0,0);same_heap(ref idle);
        assert(retained(e).program_bytes==0);
        mode+=1;
    }
    unsafe{bc_runtime_engine_test_clock_advance(3,100+8*20000000-1)};
    let usize p=id(engine::compile_granted_output(e,indexed(input)?,run,65536));
    assert(p==1);
    unsafe{bc_runtime_engine_test_use_os_clock()};
    release(e,p);counts(e,0,0,0);same_heap(ref idle);return .ok(0);
}
fn Result<usize,u8> compile_context_deadline(ref mut engine::Engine e,ref configs::RunConfig run){
    let ref u8[] ordinary=b"module app;pub fn i32 chosen(){                                return 42;}";
    let ref u8[] input=b"module app;pub fn i32 chosen(ref u8[] data){                     return 42;}";
    let Heap idle=heap();
    var usize mode=0;
    while(mode<2){
        let usize start=100+mode*20000000;
        unsafe{bc_runtime_engine_test_set_clock(start)};
        unsafe{bc_runtime_engine_test_proof_begin()};
        unsafe{bc_runtime_engine_test_expire_in_context(start+20000000)};
        let Result<usize,engine::Error> result=if(mode==0){engine::compile_output(e,selected(ordinary)?,65536)}
            else{engine::compile_granted_output(e,indexed(input)?,run,65536)};
        rejected_compile_deadline(result);
        assert(unsafe{bc_runtime_engine_test_context_bytes()}==64);
        assert(unsafe{bc_runtime_engine_test_proof_count()}==0);
        counts(e,0,0,0);same_heap(ref idle);
        assert(retained(e).program_bytes==0);
        mode+=1;
    }
    unsafe{bc_runtime_engine_test_use_os_clock()};
    return .ok(0);
}
fn void literal_transaction_deadline(){
    var images::Builder b=images::full_builder();
    assert(images::intern_bytes(ref mut b,b"seed").is_ok);
    let context::Table scope=context::empty();
    unsafe{bc_runtime_engine_test_set_clock(100)};
    unsafe{bc_runtime_engine_test_expire_in_literal(200)};
    let Result<literals::Index,literal_source::Error> result=literals::collect_scoped_until(
        ref mut b,b"b\"one\" b\"two\"",ref scope,200);
    switch(result){
        case .ok(_):{assert(false);}
        case .err(e):{
            switch(e.kind){
                case .Source:{assert(e.source.kind==errors::deadline_kind() &&
                    e.source.location==errors::absent_location());}
                case .Image:{assert(false);}
            };
        }
    };
    unsafe{bc_runtime_engine_test_literal_stopped()};
    assert(b.limit==4096 && b.catalog.count==1 && b.catalog.used==4 &&
        b.catalog.starts[0]==0 && b.catalog.ends[0]==4 && !b.catalog.text[0]);
    let ref u8[] data=ref b.data;
    assert(bytes::equal(data[..4],b"seed") && data[4]==0);
    unsafe{bc_runtime_engine_test_use_os_clock()};
}
fn Result<usize,u8> compile_literal_deadline(ref mut engine::Engine e,ref configs::RunConfig run){
    let ref u8[] ordinary=b"module app;pub fn i32 chosen(){output::emit(ref b\"one\");output::emit(ref b\"two\");return 42;}";
    let ref u8[] input=b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"one\");output::emit(ref b\"two\");return 42;}";
    let Heap idle=heap();
    var usize mode=0;
    while(mode<2){
        let usize start=100+mode*20000000;
        unsafe{bc_runtime_engine_test_set_clock(start)};
        unsafe{bc_runtime_engine_test_proof_begin()};
        unsafe{bc_runtime_engine_test_expire_in_literal(start+20000000)};
        let Result<usize,engine::Error> result=if(mode==0){engine::compile_output(e,selected(ordinary)?,65536)}
            else{engine::compile_granted_output(e,indexed(input)?,run,65536)};
        rejected_compile_deadline(result);
        unsafe{bc_runtime_engine_test_literal_stopped()};
        assert(unsafe{bc_runtime_engine_test_proof_count()}==0);
        counts(e,0,0,0);same_heap(ref idle);
        assert(retained(e).program_bytes==0);
        mode+=1;
    }
    unsafe{bc_runtime_engine_test_use_os_clock()};
    return .ok(0);
}
fn Result<usize,u8> compile_signature_deadline(ref mut engine::Engine e,ref configs::RunConfig run){
    let ref u8[] ordinary=b"module app;fn i32 helper(){return 42;}pub fn i32 chosen(){return helper();}";
    let ref u8[] input=b"module app;fn i32 helper(){return 42;}pub fn i32 chosen(ref u8[] data){return helper();}";
    let Heap idle=heap();
    var usize mode=0;
    while(mode<3){
        let usize start=100+mode*20000000;
        unsafe{bc_runtime_engine_test_set_clock(start)};
        unsafe{bc_runtime_engine_test_proof_begin()};
        unsafe{bc_runtime_engine_test_expire_in_signature(start+20000000,if(mode==2){2}else{1})};
        let Result<usize,engine::Error> result=if(mode==1){engine::compile_granted_output(e,indexed(input)?,run,65536)}
            else{engine::compile_output(e,selected(ordinary)?,65536)};
        rejected_compile_deadline(result);
        unsafe{bc_runtime_engine_test_signature_stopped()};
        assert(unsafe{bc_runtime_engine_test_proof_count()}==0);
        counts(e,0,0,0);same_heap(ref idle);
        assert(retained(e).program_bytes==0);
        mode+=1;
    }
    unsafe{bc_runtime_engine_test_use_os_clock()};
    return .ok(0);
}
fn Result<usize,u8> compile_origin_deadline(ref mut engine::Engine e,ref configs::RunConfig run){
    let ref u8[] ordinary=b"module app;fn ref u8[] tail(ref u8[] data){return data[1..];}pub fn i32 chosen(){return 42;}";
    let ref u8[] input=b"module app;fn ref u8[] tail(ref u8[] data){return data[1..];}pub fn i32 chosen(ref u8[] data){return 42;}";
    let Heap idle=heap();
    var usize mode=0;
    while(mode<3){
        let usize start=100+mode*20000000;
        unsafe{bc_runtime_engine_test_set_clock(start)};
        unsafe{bc_runtime_engine_test_proof_begin()};
        unsafe{bc_runtime_engine_test_expire_in_origin(start+20000000,if(mode==2){2}else{1})};
        let Result<usize,engine::Error> result=if(mode==1){engine::compile_granted_output(e,indexed(input)?,run,65536)}
            else{engine::compile_output(e,selected(ordinary)?,65536)};
        rejected_compile_deadline(result);
        unsafe{bc_runtime_engine_test_origin_stopped()};
        assert(unsafe{bc_runtime_engine_test_proof_count()}==0);
        counts(e,0,0,0);same_heap(ref idle);
        assert(retained(e).program_bytes==0);
        mode+=1;
    }
    unsafe{bc_runtime_engine_test_use_os_clock()};
    return .ok(0);
}

fn Result<usize,u8> compile_body_deadline(ref mut engine::Engine e,ref configs::RunConfig run){
    let ref u8[] ordinary=b"module app;pub fn i32 chosen(){let i32 x=20+22;return x;}";
    let ref u8[] input=b"module app;pub fn i32 chosen(ref u8[] data){let i32 x=20+22;return x;}";
    let Heap idle=heap();
    var usize mode=0;
    while(mode<2){
        let usize start=100+mode*20000000;
        unsafe{bc_runtime_engine_test_set_clock(start)};
        unsafe{bc_runtime_engine_test_proof_begin()};
        unsafe{bc_runtime_engine_test_expire_in_body(start+20000000)};
        let Result<usize,engine::Error> result=if(mode==0){engine::compile_output(e,selected(ordinary)?,65536)}
            else{engine::compile_granted_output(e,indexed(input)?,run,65536)};
        rejected_compile_deadline(result);
        unsafe{bc_runtime_engine_test_body_stopped()};
        assert(unsafe{bc_runtime_engine_test_proof_count()}==0);
        counts(e,0,0,0);same_heap(ref idle);
        assert(retained(e).program_bytes==0);
        mode+=1;
    }
    unsafe{bc_runtime_engine_test_use_os_clock()};
    return .ok(0);
}
fn Result<usize,u8> configured_compile_deadline(){
    let policy::Policy ceiling=output_policy(true)?;
    let configs::RunConfig granted=run_config(ref ceiling,0)?;
    var engine::Engine e=configured_engine(ceiling)?;
    let usize context_checked=compile_context_deadline(ref mut e,ref granted)?;
    literal_transaction_deadline();
    let usize literal_checked=compile_literal_deadline(ref mut e,ref granted)?;
    let usize signature_checked=compile_signature_deadline(ref mut e,ref granted)?;
    let usize origin_checked=compile_origin_deadline(ref mut e,ref granted)?;
    let usize body_checked=compile_body_deadline(ref mut e,ref granted)?;
    let usize checked=compile_deadline(ref mut e,ref granted)?;
    close(ref mut e);return .ok(0);
}
fn void deadline_result(ref mut engine::Engine e,usize i,engine::Event done,usize remaining){
    assert(done.kind==2 && done.value==0 && done.remaining==remaining && done.fuel_known);
    assert(done.diagnostic.code.kind==errors::deadline_kind() && done.diagnostic.at.source==sources::no_source().source);
    frozen(e,i,done);
    switch(engine::take_output(e,i)){
        case .ok(o):{assert(!engine::output_available(ref o) && engine::output_view(ref o).len==0);}
        case .err(_):{assert(false);}
    };
}
fn Result<usize,u8> configured_deadline(){
    let policy::Policy ceiling=output_policy(true)?;
    let configs::RunConfig granted=run_config(ref ceiling,0)?;
    var engine::Engine e=configured_engine(ceiling)?;
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);var i32 n=0;while(n<64){n+=1;}return 42;}";
    let usize p=id(engine::compile_granted_output(ref mut e,indexed(source)?,ref granted,65536));
    unsafe{bc_runtime_engine_test_set_clock(100)};
    let usize a=id(engine::prepare_granted_instance(ref mut e,p,ref granted,captured(b"A\x00")?));
    let usize b=id(engine::prepare_granted_instance(ref mut e,p,ref granted,captured(b"B")?));
    let usize c=id(engine::prepare_granted_instance(ref mut e,p,ref granted,captured(b"C")?));
    lifecycle::warm(ref mut e,a);
    lifecycle::warm(ref mut e,b);
    let engine::Event success=finish(ref mut e,c,4096);
    assert(success.kind==1 && success.value==42);
    var usize n=0;
    while(n<16){assert(tick(ref mut e,a,1).kind==4 && tick(ref mut e,b,1).kind==4);n+=1;}
    unsafe{bc_runtime_engine_test_set_clock(10000099)};
    let engine::Event before=tick(ref mut e,a,1);
    assert(before.kind==4 && id(engine::lifecycle_phase(ref e,a))==5);
    same_event(before,status_event(ref e,a,.Running));
    let engine::Event cancelling=event(engine::cancel_ready(ref mut e,b));
    assert(cancelling.kind==4);
    let engine::Event cancel_cause=status_event(ref e,b,.Stopping);
    assert(cancel_cause.kind==3 && cancel_cause.remaining==cancelling.remaining);
    rejected_take(engine::take_output(ref mut e,b),11);
    unsafe{bc_runtime_engine_test_set_clock(10000100)};
    let engine::Event expiring=event(engine::cancel_ready(ref mut e,a));
    assert(expiring.kind==4 && expiring.remaining==before.remaining);
    let engine::Event expiry_cause=status_event(ref e,a,.Stopping);
    assert(expiry_cause.kind==2 && expiry_cause.diagnostic.code.kind==errors::deadline_kind());
    same_event(expiry_cause,status_event(ref e,a,.Stopping));
    same_event(cancel_cause,status_event(ref e,b,.Stopping));
    rejected_take(engine::take_output(ref mut e,a),11);
    let engine::Event expired_first=finish(ref mut e,a,1);
    same_event(expiry_cause,expired_first);
    deadline_result(ref mut e,a,expired_first,before.remaining);
    let engine::Event cancelled=lifecycle::stop(ref mut e,b);
    same_event(cancel_cause,cancelled);
    frozen(ref mut e,b,cancelled);
    rejected_take(engine::take_output(ref mut e,b),2);
    frozen(ref mut e,c,success);
    {
        let engine::Output result=take(ref mut e,c)?;
        assert(bytes::equal(engine::output_view(ref result),b"C"));
    }
    destroy(ref mut e,a);destroy(ref mut e,b);destroy(ref mut e,c);ledger(ref e,0);
    unsafe{bc_runtime_engine_test_use_os_clock()};
    let usize real=id(engine::prepare_granted_instance(ref mut e,p,ref granted,captured(b"D")?));
    let engine::Event prepared=event(engine::observe(ref mut e,real));
    let usize now=unsafe{bc_runtime_engine_monotonic_ticks()};
    unsafe{bc_runtime_engine_test_wait_for_clock(now,10000000)};
    let engine::Event expired=tick(ref mut e,real,1);
    deadline_result(ref mut e,real,expired,prepared.remaining);
    destroy(ref mut e,real);ledger(ref e,0);release(ref mut e,p);
    close(ref mut e);return .ok(0);
}
fn Result<usize,u8> rejected_poisoned_compile(ref mut engine::Engine e,ref u8[] source){
    switch(engine::compile_input_output(e,selected_input(source)?,65536)){
        case .ok(_):{assert(false);}case .err(err):{assert(err.status==14);}
    };
    return .ok(0);
}
fn Result<usize,u8> cleanup_fault_quarantines_engine(bool through_cancel){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}";
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,source,true)?;
    let usize complete=bound(ref mut e,p,b"done",16000000,8)?;
    let usize retiring=bound(ref mut e,p,b"discard",16000000,8)?;
    let usize stopping=bound(ref mut e,p,b"stop",16000000,8)?;
    let usize ready=bound(ref mut e,p,b"ready",16000000,8)?;
    discard prepare(ref mut e,complete,p,8);
    let engine::Event prior=finish(ref mut e,complete,4096);assert(prior.kind==1 && prior.value==42);
    discard prepare(ref mut e,retiring,p,8);lifecycle::warm(ref mut e,retiring);
    discard prepare(ref mut e,stopping,p,8);lifecycle::warm(ref mut e,stopping);
    assert(event(engine::cancel_ready(ref mut e,stopping)).kind==4);
    let engine::Event sibling_cause=status_event(ref e,stopping,.Stopping);
    assert(event(engine::cancel_ready(ref mut e,retiring)).kind==4);
    let engine::Event trigger=status_event(ref e,retiring,.Stopping);
    let usize attempts=unsafe{probe_attempts()};
    unsafe{bc_runtime_engine_test_inject_cleanup_fault()};
    var engine::Event done=event(engine::observe(ref mut e,retiring));
    var usize ticks=0;
    while(done.kind==4){
        assert(ticks<128);
        done=event(if(through_cancel){engine::cancel_ready(ref mut e,retiring)}
            else{engine::step_instance(ref mut e,retiring,4096)});
        ticks+=1;
    }
    assert(unsafe{probe_attempts()}==attempts);
    same_event(trigger,done);same_event(trigger,status_event(ref e,retiring,.Terminal));
    same_event(sibling_cause,status_event(ref e,stopping,.Terminal));
    same_event(sibling_cause,event(engine::cancel_ready(ref mut e,stopping)));
    same_event(prior,event(engine::observe(ref mut e,complete)));
    let engine::Event poisoned=status_event(ref e,ready,.Terminal);
    assert(poisoned.kind==2 && poisoned.diagnostic.code.kind==errors::engine_poisoned_kind() &&
        poisoned.remaining==16000000);
    rejected(engine::step_instance(ref mut e,ready,1),14);
    rejected(engine::execute_once(ref mut e,ready),14);
    rejected(engine::prepare_instance(ref mut e,ready),14);
    switch(engine::create_instance(ref mut e,p,16000000)){
        case .ok(_):{assert(false);}case .err(err):{assert(err.status==14);}
    };
    discard rejected_poisoned_compile(ref mut e,source)?;
    rejected_take(engine::take_output(ref mut e,retiring),2);
    rejected_take(engine::take_output(ref mut e,stopping),2);
    rejected_take(engine::take_output(ref mut e,ready),2);
    let engine::Output saved=take(ref mut e,complete)?;
    assert(bytes::equal(engine::output_view(ref saved),b"done"));
    same_event(prior,event(engine::observe(ref mut e,complete)));
    release(ref mut e,p);
    destroy(ref mut e,retiring);destroy(ref mut e,stopping);
    destroy(ref mut e,ready);destroy(ref mut e,complete);
    ledger(ref e,0);counts(ref mut e,0,0,0);close(ref mut e);return .ok(0);
}
fn Result<usize,u8> output_fault_quarantines_engine(bool through_cancel){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}";
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,source,true)?;
    let usize complete=bound(ref mut e,p,b"done",16000000,8)?;
    let usize running=bound(ref mut e,p,b"private",16000000,8)?;
    let usize sibling=bound(ref mut e,p,b"stop",16000000,8)?;
    discard prepare(ref mut e,complete,p,8);
    let engine::Event prior=finish(ref mut e,complete,4096);
    assert(prior.kind==1 && prior.value==42);
    discard prepare(ref mut e,running,p,8);lifecycle::warm(ref mut e,running);
    discard prepare(ref mut e,sibling,p,8);lifecycle::warm(ref mut e,sibling);
    assert(event(engine::cancel_ready(ref mut e,sibling)).kind==4);
    let engine::Event sibling_cause=status_event(ref e,sibling,.Stopping);

    if(through_cancel){assert(event(engine::cancel_ready(ref mut e,running)).kind==4);}
    let engine::Event before=status_event(ref e,running,if(through_cancel){.Stopping}else{.Running});
    let usize attempts=unsafe{probe_attempts()};
    unsafe{bc_runtime_engine_test_inject_output_fault(if(through_cancel){2}else{1})};
    if(through_cancel){rejected(engine::cancel_ready(ref mut e,running),14);}
    else{
        var bool contained=false;var usize ticks=0;
        while(!contained){
            assert(ticks<128);ticks+=1;
            switch(engine::step_instance(ref mut e,running,4096)){
                case .ok(v):{assert(v.kind==4);}
                case .err(e):{assert(e.status==14);contained=true;}
            };
        }
    }
    assert(unsafe{probe_attempts()}==attempts);
    let engine::Event terminal=status_event(ref e,running,.Terminal);
    if(through_cancel){same_event(before,terminal);}
    else{assert(terminal.kind==2 && terminal.diagnostic.code.kind==errors::engine_poisoned_kind());}
    same_event(terminal,event(engine::cancel_ready(ref mut e,running)));
    same_event(sibling_cause,status_event(ref e,sibling,.Terminal));
    same_event(prior,event(engine::observe(ref mut e,complete)));
    rejected(engine::step_instance(ref mut e,sibling,1),14);
    rejected_take(engine::take_output(ref mut e,running),2);
    let engine::Output saved=take(ref mut e,complete)?;
    assert(bytes::equal(engine::output_view(ref saved),b"done"));
    release(ref mut e,p);
    destroy(ref mut e,running);destroy(ref mut e,sibling);destroy(ref mut e,complete);
    ledger(ref e,0);counts(ref mut e,0,0,0);close(ref mut e);return .ok(0);
}
pub fn void run(){
    let Heap before=heap();
    assert(fixed_and_mixed_quanta().is_ok);same_heap(ref before);
    assert(wrong_state_and_invalid_quanta().is_ok);same_heap(ref before);
    assert(interleaved_moves_and_detached_output().is_ok);same_heap(ref before);
    assert(running_cancel_refund_and_first_cause().is_ok);same_heap(ref before);
    assert(failures_and_exact_fuel().is_ok);same_heap(ref before);
    assert(empty_output_and_running_drop().is_ok);same_heap(ref before);
    assert(configured_output().is_ok);same_heap(ref before);
    assert(project_output().is_ok);same_heap(ref before);
    assert(configured_compile_deadline().is_ok);same_heap(ref before);
    assert(configured_deadline().is_ok);same_heap(ref before);
    assert(cleanup_fault_quarantines_engine(false).is_ok);same_heap(ref before);
    assert(cleanup_fault_quarantines_engine(true).is_ok);same_heap(ref before);
    assert(output_fault_quarantines_engine(false).is_ok);same_heap(ref before);
    assert(output_fault_quarantines_engine(true).is_ok);same_heap(ref before);
}
