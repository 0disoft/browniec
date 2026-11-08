module engine_output_chunk_tests;
import runtime_engine as engine;
import runtime_live_memory as live;
import runtime_input as inputs;
import module_output_program as programs;
import slice_result_machine as machine;
import output_copy_cursor as copy;
import module_input_entry as input_entries;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import fuel as meter;
import std::bytes as bytes;

// Native fixtures only. Parent owns runner, bindings and integration.
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
fn copy::State progress(ref engine::Engine e,usize i){return switch(engine::output_copy_progress(e,i)){
    case .ok(v):{v}case .err(_):{assert(false);copy::empty()}
};}
fn void rejected_progress(ref engine::Engine e,usize i,u32 status){switch(engine::output_copy_progress(e,i)){
    case .ok(_):{assert(false);}case .err(v):{assert(v.status==status);}
};}
fn void rejected_take(ref mut engine::Engine e,usize i,u32 status){switch(engine::take_output(e,i)){
    case .ok(_):{assert(false);}case .err(v):{assert(v.status==status);}
};}
fn void same_event(engine::Event a,engine::Event b){
    assert(a.kind==b.kind && a.value==b.value && a.remaining==b.remaining && a.fuel_known==b.fuel_known);
    assert(a.diagnostic.code.kind==b.diagnostic.code.kind && a.diagnostic.code.offset==b.diagnostic.code.offset);
    assert(a.diagnostic.at.source==b.diagnostic.at.source && a.diagnostic.at.start==b.diagnostic.at.start);
    assert(a.diagnostic.at.end==b.diagnostic.at.end);
}
fn live::Observation instance(ref engine::Engine e){return switch(engine::instance_memory(e)){
    case .ok(v):{v}case .err(_):{assert(false);live::Observation{
        .instance_limit=0,.instances_limit=0,.current=0,.peak=0,.closed=false}}
};}
fn void ledger(ref engine::Engine e,usize current){
    let live::Observation l=instance(e);assert(l.current==current && current<=l.peak && l.peak<=l.instances_limit && !l.closed);
    switch(engine::program_memory(e)){
        case .ok(m):{assert(m.external_bytes==current && m.tracked_bytes==m.control_bytes+m.program_bytes+current);
            assert(m.tracked_bytes<=m.tracked_peak && m.tracked_peak<=m.engine_limit && !m.closed);}
        case .err(_):{assert(false);}
    };
}
fn Result<engine::Engine,u8> created(){return switch(engine::create(engine::Limits{.programs=2,.instances=2,.fuel=16000000})){
    case .ok(v):{.ok(v)}case .err(_):{.err(1)}
};}
fn Result<input_entries::InputEntry,u8> selected(ref u8[] source){
    var sources::Builder b=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{return .err(2);}};
    if(!sources::add(ref mut b,b"app.brc",source).is_ok){return .err(3);}
    let sources::Snapshot s=switch(sources::freeze(ref b)){case .ok(v):{v}case .err(_):{return .err(4);}};
    let modules::Index index=switch(modules::build(s)){case .ok(v):{v}case .err(_):{return .err(5);}};
    return switch(input_entries::select_i32_input(index,b"app",b"chosen")){case .ok(v):{.ok(v)}case .err(_):{.err(6)}};
}
fn Result<usize,u8> compiled(ref mut engine::Engine e,ref u8[] source){
    return .ok(id(engine::compile_input_output(e,selected(source)?,65536)));
}
fn Result<inputs::Snapshot,u8> captured(ref u8[] data){
    var usize fuel=0;return switch(inputs::snapshot(data,inputs::hard_limit(),0,ref mut fuel)){
        case .ok(v):{.ok(v)}case .err(_):{.err(7)}
    };
}
fn Result<usize,u8> bound(ref mut engine::Engine e,usize p,ref u8[] data,usize fuel,usize limit){
    return .ok(id(engine::create_input_output_instance(e,p,captured(data)?,fuel,limit,true)));
}
fn bytes::Buffer binary(usize length){
    var bytes::Buffer data=switch(bytes::with_capacity(length)){
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    assert(bytes::resize_zeroed(ref mut data,length).is_ok);
    // A repeating binary block, with distinct chunk boundaries and endpoints.
    var usize n=0;while(n<length){
        bytes::view_mut(ref mut data)[n]=if(n%4096==0){255}else if(n%257==0){73}else{0};n+=1;
    }
    if(length!=0){bytes::view_mut(ref mut data)[length-1]=33;}return data;
}
fn void destroy(ref mut engine::Engine e,usize i){assert(id(engine::destroy_instance(e,i))==i);}
fn void close(ref mut engine::Engine e,usize p){assert(id(engine::release_program(e,p))==p);assert(id(engine::destroy(e))==0);}
fn Result<engine::Output,u8> take(ref mut engine::Engine e,usize i){return switch(engine::take_output(e,i)){
    case .ok(v):{.ok(v)}case .err(_):{.err(8)}
};}
fn engine::Event completion(ref engine::Output o){
    let programs::Completion c=engine::output_completion(o);return engine::Event{
        .kind=if(c.success){1}else{2},.value=c.value,.remaining=c.remaining,.diagnostic=c.diagnostic,.fuel_known=true};
}
fn void same_output(ref engine::Output a,ref engine::Output b){
    same_event(completion(a),completion(b));
    let programs::Completion x=engine::output_completion(a);let programs::Completion y=engine::output_completion(b);
    assert(x.emits==y.emits && x.output_bytes==y.output_bytes);
    assert(engine::output_available(a)==engine::output_available(b));
    assert(bytes::equal(engine::output_view(a),engine::output_view(b)));
}
fn Result<engine::Output,u8> synchronous(ref mut engine::Engine e,usize p,ref u8[] data,usize fuel,usize limit){
    let usize i=bound(e,p,data,fuel,limit)?;let engine::Event done=event(engine::execute_once(e,i));
    let engine::Output o=take(e,i)?;same_event(done,completion(ref o));destroy(e,i);return .ok(o);
}
fn void prepare(ref mut engine::Engine e,usize i){
    assert(event(engine::prepare_instance(e,i)).kind==4);let copy::State c=progress(e,i);
    assert(!c.active && c.total==0 && c.last==0 && c.copied==0);
}
// Deny even the first SDK allocation on every resume, including terminal seal.
fn engine::Event tick(ref mut engine::Engine e,usize i,usize quantum){
    let engine::Event before=event(engine::observe(e,i));let copy::State prior=progress(e,i);
    let Heap h=heap();let usize charge=instance(e).current;let usize attempts=unsafe{probe_attempts()};
    unsafe{bc_runtime_engine_test_fail(0)};
    let Result<engine::Event,engine::Error> r=engine::step_instance(e,i,quantum);
    unsafe{bc_runtime_engine_test_fail(-1)};
    let engine::Event after=event(r);assert(unsafe{probe_attempts()}==attempts);
    assert(before.kind==4 && after.fuel_known && after.remaining<=before.remaining);
    assert(after.kind==4 || after.kind==1 || after.kind==2);same_event(after,event(engine::observe(e,i)));
    if(after.kind==4){
        let copy::State c=progress(e,i);assert(c.last<=4096 && c.total>=prior.total);
        assert(c.total-prior.total==c.last && c.copied<=c.length);
        if(c.active){assert(c.copied<c.length && c.storage>=1 && c.storage<=3 && c.offset!=0);}
        same_heap(ref h);ledger(e,charge);
    }else{rejected_progress(e,i,11);}
    return after;
}
fn engine::Event finish(ref mut engine::Engine e,usize i,usize quantum){
    var engine::Event s=event(engine::observe(e,i));var usize n=0;
    while(s.kind==4){assert(n<4096);s=tick(e,i,quantum);n+=1;}return s;
}

// Group 1: an actual 1MiB input, not a synthetic descriptor or an inferred bound.
fn Result<usize,u8> megabyte_exact_bytes_and_bounded_batches(){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}";
    let bytes::Buffer data=binary(1048576);var engine::Engine e=created()?;
    let usize p=compiled(ref mut e,source)?;let usize i=bound(ref mut e,p,bytes::view(ref data),16000000,1048576)?;
    prepare(ref mut e,i);var engine::Event s=event(engine::observe(ref mut e,i));
    var usize batches=0;var usize copied_batches=0;var usize total=0;var usize prepaid=0;
    while(s.kind==4){
        assert(batches<512);let copy::State before=progress(ref e,i);s=tick(ref mut e,i,4096);batches+=1;
        if(s.kind==4){let copy::State c=progress(ref e,i);total=c.total;
            if(c.last!=0){copied_batches+=1;assert(c.last==4096 && c.storage==3 && c.start==0 && c.length==1048576);}
            if(before.active){assert(s.remaining==prepaid);}
            if(c.active){prepaid=s.remaining;assert(c.copied==c.total);rejected_take(ref mut e,i,11);}
        }
    }
    assert(s.kind==1 && s.value==42 && copied_batches==256 && batches>=256 && total==1048576);
    let engine::Output o=take(ref mut e,i)?;
    assert(engine::output_completion(ref o).emits==1 && engine::output_completion(ref o).output_bytes==1048576);
    assert(bytes::equal(engine::output_view(ref o),bytes::view(ref data)));
    destroy(ref mut e,i);ledger(ref e,0);close(ref mut e,p);return .ok(0);
}

// Group 2: four bounded schedules; the canonical carrier exposes visits and PC.
// Pending can end before quantum on the byte cap. Continuations prepay nothing.
fn Result<usize,u8> fixed_mixed_quanta_fuel_and_cursor_parity(){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}";
    let bytes::Buffer data=binary(8193);let inputs::Snapshot input=captured(bytes::view(ref data))?;
    let programs::Program code=switch(programs::compile_input(selected(source)?,65536)){
        case .ok(v):{v}case .err(_):{return .err(9);}
    };
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,source)?;
    let engine::Output baseline=synchronous(ref mut e,p,bytes::view(ref data),16000000,8193)?;
    assert(completion(ref baseline).kind==1 && completion(ref baseline).value==42);
    let usize[3] quanta=[1,7,4096];let usize[5] mixed=[1,2,64,3,4096];var usize variant=0;
    while(variant<4){
        var machine::Machine oracle=switch(engine::prepare_pending_output(ref code,ref input,16000000,8193,true)){
            case .ok(v):{v}case .err(_):{return .err(10);}
        };
        let usize i=bound(ref mut e,p,bytes::view(ref data),16000000,8193)?;prepare(ref mut e,i);
        var engine::Event s=event(engine::observe(ref mut e,i));var usize calls=0;var bool reset=false;var bool byte_yield=false;
        while(s.kind==4){
            assert(calls<128);let usize q=if(variant==3){mixed[calls%5]}else{quanta[variant]};
            let machine::Meta before=machine::observe(ref oracle);let usize attempts=unsafe{probe_attempts()};
            let machine::Meta expected=switch(engine::advance_pending_output(ref mut oracle,ref code,ref input,q)){
                case .ok(v):{v}case .err(_):{return .err(11);}
            };
            assert(unsafe{probe_attempts()}==attempts);
            assert(expected.stats.calls==before.stats.calls+1 && expected.stats.last<=q);
            assert(expected.stats.dispatched==before.stats.dispatched+expected.stats.last);
            s=tick(ref mut e,i,q);calls+=1;
            if(expected.phase==1){
                assert(s.kind==4 && s.remaining==expected.remaining);let copy::State c=progress(ref e,i);
                assert(c.total==expected.cursor.output.total && c.last==expected.cursor.output.last);
                assert(c.active==expected.cursor.output.active && c.copied==expected.cursor.output.copied);
                if(expected.stats.last<q){
                    assert(c.last==4096 || expected.cursor.metadata.last==4096 || expected.cursor.return_metadata.pending);
                    if(c.last==4096){byte_yield=true;}
                }
                if(before.cursor.output.active && c.active){
                    assert(expected.cursor.pc==before.cursor.pc && expected.remaining==before.remaining && expected.stats.last==1);
                    assert(c.offset==before.cursor.output.offset && c.storage==before.cursor.output.storage);
                }
                if(q==1 && before.cursor.output.active){
                    assert(expected.remaining==before.remaining && expected.stats.last==1);
                    if(!c.active){assert(expected.cursor.pc==before.cursor.pc+1);}
                }
                if(c.last==0 && before.cursor.output.last!=0){reset=true;}
            }else{assert(expected.phase==2 && s.kind==1 && s.remaining+meter::output_seal()==expected.remaining);}
        }
        if(variant==0){assert(reset);}if(variant==2){assert(byte_yield);}
        same_event(s,completion(ref baseline));let engine::Output o=take(ref mut e,i)?;
        same_output(ref o,ref baseline);destroy(ref mut e,i);ledger(ref e,0);variant+=1;
    }
    close(ref mut e,p);return .ok(0);
}

// Group 3: the second and third emit share each drive's remaining byte budget.
fn Result<usize,u8> multiple_emits_share_one_batch_cap(){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);output::emit(ref data);output::emit(ref data);output::emit(ref b\"\");return 42;}";
    let bytes::Buffer data=binary(3072);var engine::Engine e=created()?;let usize p=compiled(ref mut e,source)?;
    let engine::Output baseline=synchronous(ref mut e,p,bytes::view(ref data),16000000,9216)?;
    let usize i=bound(ref mut e,p,bytes::view(ref data),16000000,9216)?;prepare(ref mut e,i);
    assert(tick(ref mut e,i,4096).kind==4);let copy::State a=progress(ref e,i);
    assert(a.last==4096 && a.total==4096 && a.active && a.length==3072 && a.copied==1024);
    assert(tick(ref mut e,i,4096).kind==4);let copy::State b=progress(ref e,i);
    assert(b.last==4096 && b.total==8192 && b.active && b.length==3072 && b.copied==2048 && b.offset!=a.offset);
    let engine::Event done=finish(ref mut e,i,4096);same_event(done,completion(ref baseline));
    let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);
    assert(engine::output_completion(ref o).emits==4 && engine::output_view(ref o).len==9216);
    assert(bytes::equal(engine::output_view(ref o)[..3072],bytes::view(ref data)));
    assert(bytes::equal(engine::output_view(ref o)[3072..6144],bytes::view(ref data)));
    assert(bytes::equal(engine::output_view(ref o)[6144..],bytes::view(ref data)));
    destroy(ref mut e,i);close(ref mut e,p);return .ok(0);
}

// Group 4: drop both a committed prefix and an incomplete second emit; refund
// prepared backing once, retain input, preserve spent Fuel and freeze cancel.
fn Result<usize,u8> mid_copy_cancel_hides_prefix_and_refunds(){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"prefix\");output::emit(ref data);return 42;}";
    let bytes::Buffer data=binary(16385);var engine::Engine e=created()?;let usize p=compiled(ref mut e,source)?;
    let usize i=bound(ref mut e,p,bytes::view(ref data),16000000,16391)?;
    let usize input=instance(ref e).current;let Heap ready=heap();prepare(ref mut e,i);
    let engine::Event running=tick(ref mut e,i,4096);assert(running.kind==4);
    let copy::State c=progress(ref e,i);assert(c.active && c.total==4096 && c.copied==4090 && c.length==16385);
    rejected_take(ref mut e,i,11);let usize attempts=unsafe{probe_attempts()};
    let engine::Event stopped=event(engine::cancel_ready(ref mut e,i));
    assert(stopped.kind==3 && stopped.value==0 && stopped.fuel_known && stopped.remaining==running.remaining);
    assert(stopped.diagnostic.code.kind==0);same_heap(ref ready);ledger(ref e,input);
    rejected_progress(ref e,i,11);rejected_take(ref mut e,i,2);
    same_event(stopped,event(engine::cancel_ready(ref mut e,i)));same_event(stopped,event(engine::observe(ref mut e,i)));
    assert(unsafe{probe_attempts()}==attempts);same_heap(ref ready);ledger(ref e,input);
    destroy(ref mut e,i);ledger(ref e,0);rejected_progress(ref e,i,2);close(ref mut e,p);return .ok(0);
}

// Group 5: distinguish whole-run exact Fuel from exact EMIT preadmission. With
// only enough for EMIT, all continuations finish at zero Fuel; the next opcode
// fails. One less never begins copying, even the first byte.
fn Result<usize,u8> exact_fuel_and_one_less_emit_preadmission(){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}";
    let bytes::Buffer data=binary(8193);var engine::Engine e=created()?;let usize p=compiled(ref mut e,source)?;
    let engine::Output full=synchronous(ref mut e,p,bytes::view(ref data),16000000,8193)?;
    assert(completion(ref full).kind==1);let usize price=16000000-completion(ref full).remaining;
    let usize measured=bound(ref mut e,p,bytes::view(ref data),16000000,8193)?;prepare(ref mut e,measured);
    var usize admission=0;var usize visits=0;
    while(progress(ref e,measured).total==0){
        assert(visits<64);let engine::Event before=event(engine::observe(ref mut e,measured));
        assert(tick(ref mut e,measured,1).kind==4);visits+=1;
        if(progress(ref e,measured).total!=0){
            let engine::Event after=event(engine::observe(ref mut e,measured));
            assert(before.remaining-after.remaining==1+meter::output_access()+meter::output_emit(8193));
            admission=16000000-before.remaining+1+meter::output_access()+meter::output_emit(8193);
        }
    }
    assert(admission>0 && admission<price);destroy(ref mut e,measured);
    let usize exact=bound(ref mut e,p,bytes::view(ref data),price,8193)?;prepare(ref mut e,exact);
    let engine::Event done=finish(ref mut e,exact,7);assert(done.kind==1 && done.value==42 && done.remaining==0);
    let engine::Output exact_output=take(ref mut e,exact)?;
    assert(bytes::equal(engine::output_view(ref exact_output),bytes::view(ref data)));
    assert(engine::output_completion(ref exact_output).emits==1);destroy(ref mut e,exact);
    var usize variant=0;while(variant<2){
        let usize budget=admission-variant;let engine::Output baseline=synchronous(ref mut e,p,bytes::view(ref data),budget,8193)?;
        let usize i=bound(ref mut e,p,bytes::view(ref data),budget,8193)?;prepare(ref mut e,i);
        var engine::Event s=event(engine::observe(ref mut e,i));var usize total=0;var usize calls=0;
        while(s.kind==4){
            assert(calls<128);s=tick(ref mut e,i,1);calls+=1;
            if(s.kind==4){let copy::State c=progress(ref e,i);total=c.total;
                if(variant==1){assert(c.total==0 && !c.active);}
                else if(c.total!=0){assert(s.remaining==0);}
            }
        }
        assert(s.kind==2 && s.diagnostic.code.kind==8 && s.diagnostic.code.offset!=0);
        assert(total==if(variant==0){8193}else{0});same_event(s,completion(ref baseline));
        let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);
        assert(!engine::output_available(ref o) && engine::output_view(ref o).len==0);
        assert(engine::output_completion(ref o).emits==if(variant==0){1}else{0});
        destroy(ref mut e,i);variant+=1;
    }
    close(ref mut e,p);return .ok(0);
}

fn Result<usize,u8> small_parity(ref u8[] source,ref u8[] data,usize limit,u8 error,ref u8[] expected,usize emits){
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,source)?;
    let engine::Output baseline=synchronous(ref mut e,p,data,16000000,limit)?;
    assert(completion(ref baseline).diagnostic.code.kind==error);
    let usize i=bound(ref mut e,p,data,16000000,limit)?;prepare(ref mut e,i);
    var engine::Event s=event(engine::observe(ref mut e,i));var usize calls=0;var usize stores=0;
    while(s.kind==4){assert(calls<256);s=tick(ref mut e,i,1);calls+=1;
        if(s.kind==4){let copy::State c=progress(ref e,i);
            if(c.last!=0){let usize one=1;stores|=one<<(c.storage as usize);}
        }
    }
    same_event(s,completion(ref baseline));let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);
    assert(bytes::equal(engine::output_view(ref o),expected) && engine::output_completion(ref o).emits==emits);
    if(error==0){assert(s.kind==1 && s.value==42 && stores==14);}
    else{assert(s.kind==2 && s.diagnostic.code.offset!=0 && !engine::output_available(ref o));}
    destroy(ref mut e,i);close(ref mut e,p);return .ok(0);
}
// Group 6: all three source stores, returned/nested windows, empty emits, binary
// literal/arena ranges; trap, quota and invalid range preserve diagnostics and
// hide previously staged bytes. Keep the existing small-emit behavior.
fn Result<usize,u8> storage_ranges_and_failure_parity(){
    let usize valid=small_parity(
        b"module app;fn ref u8[] tail(ref u8[] data){return data[1..];}pub fn i32 chosen(ref u8[] data){let ref u8[] part=tail(ref data);output::emit(ref part[1..]);let ref u8[] marker=b\"L\\x00\\xFF\";output::emit(ref marker[1..]);let u8[3] local=[0,255,33];output::emit(ref local[1..]);output::emit(ref local[3..]);return 42;}",
        b"!?\x00I",16,0,b"\x00I\x00\xFF\xFF!",4)?;
    let usize trap=small_parity(
        b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"prefix\");return 42/(data[0] as i32);}",
        b"\x00",16,7,b"",1)?;
    let usize quota=small_parity(
        b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"P\");output::emit(ref data);return 42;}",
        b"12345",5,20,b"",1)?;
    return small_parity(
        b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"prefix\");output::emit(ref data[2..0]);return 42;}",
        b"\x00!",16,14,b"",1);
}
pub fn void run(){
    let Heap before=heap();
    assert(megabyte_exact_bytes_and_bounded_batches().is_ok);same_heap(ref before);
    assert(fixed_mixed_quanta_fuel_and_cursor_parity().is_ok);same_heap(ref before);
    assert(multiple_emits_share_one_batch_cap().is_ok);same_heap(ref before);
    assert(mid_copy_cancel_hides_prefix_and_refunds().is_ok);same_heap(ref before);
    assert(exact_fuel_and_one_less_emit_preadmission().is_ok);same_heap(ref before);
    assert(storage_ranges_and_failure_parity().is_ok);same_heap(ref before);
}
