module engine_call_copy_tests;
import runtime_engine as engine;
import runtime_live_memory as live;
import runtime_input as inputs;
import module_output_program as programs;
import module_input_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import array_fill_cursor as fill;
import output_copy_cursor as copy;
import call_copy_cursor as calls;
import metadata_budget as metadata_budget;
import std::bytes as bytes;

// Actual-source saved-VM tests. Parent owns runner/API integration and serial
// syntax/native checks. No fabricated CALL IR or kernel-only execution oracle.
unsafe extern C fn void bc_runtime_engine_test_call_error(u32 status,u8 kind,usize offset);
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
struct Heap { usize blocks; usize bytes; }
struct Admission { usize fuel; usize remaining; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void same_heap(Heap h){assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes);}
fn usize id(Result<usize,engine::Error> r){return switch(r){case .ok(v):{v}case .err(e):{unsafe{bc_runtime_engine_test_call_error(e.status,e.diagnostic.code.kind,e.diagnostic.code.offset)};assert(false);0}};}
fn engine::Event event(Result<engine::Event,engine::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,.remaining=0,
        .fuel_known=false,.diagnostic=diagnostics::absent(errors::make(0,0))}}
};}
fn fill::State array(ref engine::Engine e,usize i){return switch(engine::array_copy_progress(e,i)){
    case .ok(v):{v}case .err(_):{assert(false);fill::empty()}
};}
fn copy::State output(ref engine::Engine e,usize i){return switch(engine::output_copy_progress(e,i)){
    case .ok(v):{v}case .err(_):{assert(false);copy::empty()}
};}
fn calls::State call(ref engine::Engine e,usize i){return switch(engine::call_copy_progress(e,i)){
    case .ok(v):{v}case .err(_):{assert(false);calls::empty()}
};}
fn usize call_phase(ref engine::Engine e,usize i){return switch(engine::call_metadata_phase(e,i)){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn metadata_budget::State metadata(ref engine::Engine e,usize i){return switch(engine::authority_metadata_progress(e,i)){
    case .ok(v):{v}case .err(_):{assert(false);metadata_budget::empty()}
};}
fn void same_recipe(calls::State a,calls::State b){
    assert(a.pc==b.pc && a.frame==b.frame && a.offset==b.offset && a.target==b.target && a.fuel_before==b.fuel_before && a.captured==b.captured);
    assert(a.mark==b.mark && a.end==b.end && a.depth==b.depth && a.count==b.count && a.reserve_first==b.reserve_first);
    var usize n=0;while(n<8){assert(a.source_slots[n]==b.source_slots[n] && a.source_generations[n]==b.source_generations[n]);
        assert(a.source_bases[n]==b.source_bases[n] && a.source_ends[n]==b.source_ends[n]);
        assert(a.target_slots[n]==b.target_slots[n] && a.target_generations[n]==b.target_generations[n]);n+=1;}
}
fn void same_progress(calls::State a,calls::State b){same_recipe(a,b);
    assert(a.pending==b.pending && a.charged==b.charged && a.active==b.active && a.phase==b.phase);
    assert(a.index==b.index && a.at==b.at && a.written==b.written && a.total==b.total && a.last==b.last && a.remaining==b.remaining);}
fn void rejected_progress(ref engine::Engine e,usize i,u32 status){switch(engine::call_copy_progress(e,i)){
    case .ok(_):{assert(false);}case .err(v):{assert(v.status==status);}
};}
fn live::Observation memory(ref engine::Engine e){return switch(engine::instance_memory(e)){
    case .ok(v):{v}case .err(_):{assert(false);live::Observation{
        .instance_limit=0,.instances_limit=0,.current=0,.peak=0,.closed=false}}
};}
fn void ledger(ref engine::Engine e,usize current){let live::Observation m=memory(e);
    assert(m.current==current && current<=m.peak && m.peak<=m.instances_limit && !m.closed);
    switch(engine::program_memory(e)){case .ok(v):{
        assert(v.external_bytes==current && v.tracked_bytes==v.control_bytes+v.program_bytes+current);
        assert(v.tracked_bytes<=v.tracked_peak && v.tracked_peak<=v.engine_limit && !v.closed);
    }case .err(_):{assert(false);}};
}
fn void counts(ref mut engine::Engine e,usize p,usize i,usize pins){switch(engine::inspect(e)){
    case .ok(v):{assert(v.programs==p && v.instances==i && v.pins==pins && !v.closed);}
    case .err(_):{assert(false);}
};}
fn void rejected_take(ref mut engine::Engine e,usize i,u32 status){switch(engine::take_output(e,i)){
    case .ok(_):{assert(false);}case .err(v):{assert(v.status==status);}
};}
fn void same_event(engine::Event a,engine::Event b){
    assert(a.kind==b.kind && a.value==b.value && a.remaining==b.remaining && a.fuel_known==b.fuel_known);
    assert(a.diagnostic.code.kind==b.diagnostic.code.kind && a.diagnostic.code.offset==b.diagnostic.code.offset);
    assert(a.diagnostic.at.source==b.diagnostic.at.source && a.diagnostic.at.start==b.diagnostic.at.start && a.diagnostic.at.end==b.diagnostic.at.end);
}
fn Result<engine::Engine,u8> created(){return switch(engine::create(engine::Limits{.programs=2,.instances=2,.fuel=16000000})){
    case .ok(v):{.ok(v)}case .err(_):{.err(1)}
};}
fn Result<usize,u8> compiled(ref mut engine::Engine e,ref u8[] source){
    var sources::Builder b=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{return .err(2);}};
    if(!sources::add(ref mut b,b"app.brc",source).is_ok){return .err(3);}
    let sources::Snapshot s=switch(sources::freeze(ref b)){case .ok(v):{v}case .err(_):{return .err(4);}};
    let modules::Index index=switch(modules::build(s)){case .ok(v):{v}case .err(_):{return .err(5);}};
    let entries::InputEntry chosen=switch(entries::select_i32_input(index,b"app",b"chosen")){
        case .ok(v):{v}case .err(_):{return .err(6);}};
    return .ok(id(engine::compile_input_output(e,chosen,65536)));
}
fn Result<usize,u8> bound(ref mut engine::Engine e,usize p,ref u8[] data,usize fuel){var usize spent=0;
    let inputs::Snapshot input=switch(inputs::snapshot(data,inputs::hard_limit(),0,ref mut spent)){
        case .ok(v):{v}case .err(_):{return .err(7);}};
    return .ok(id(engine::create_input_output_instance(e,p,input,fuel,data.len+3,true)));
}
fn Result<engine::Output,u8> take(ref mut engine::Engine e,usize i){return switch(engine::take_output(e,i)){
    case .ok(v):{.ok(v)}case .err(_):{.err(8)}
};}
fn engine::Event completion(ref engine::Output o){let programs::Completion c=engine::output_completion(o);
    return engine::Event{.kind=if(c.success){1}else{2},.value=c.value,.remaining=c.remaining,.fuel_known=true,.diagnostic=c.diagnostic};}
fn void same_output(ref engine::Output a,ref engine::Output b){same_event(completion(a),completion(b));
    let programs::Completion x=engine::output_completion(a);let programs::Completion y=engine::output_completion(b);
    assert(x.emits==y.emits && x.output_bytes==y.output_bytes && engine::output_available(a)==engine::output_available(b));
    assert(bytes::equal(engine::output_view(a),engine::output_view(b)));}
fn void binary_output(ref engine::Output o,ref u8[] data){let ref u8[] v=engine::output_view(o);
    assert(engine::output_available(o) && v.len==data.len+3 && bytes::equal(v[..3],b"\x00\xFF!") && bytes::equal(v[3..],data));
    assert(engine::output_completion(o).emits==2);}
fn void destroy(ref mut engine::Engine e,usize i){assert(id(engine::destroy_instance(e,i))==i);}
fn void close(ref mut engine::Engine e,usize p){assert(id(engine::release_program(e,p))==p);assert(id(engine::destroy(e))==0);}
fn Result<engine::Output,u8> synchronous(ref mut engine::Engine e,usize p,ref u8[] data,usize fuel){
    let usize i=bound(e,p,data,fuel)?;let engine::Event done=event(engine::execute_once(e,i));
    let engine::Output o=take(e,i)?;same_event(done,completion(ref o));destroy(e,i);return .ok(o);}
fn void prepare(ref mut engine::Engine e,usize i){assert(event(engine::prepare_instance(e,i)).kind==4);
    let fill::State a=array(e,i);let copy::State o=output(e,i);let calls::State c=call(e,i);
    assert(!a.active && a.total==0 && a.last==0 && !o.active && o.total==0 && o.last==0);
    assert(!c.pending && !c.active && !c.charged && c.written==0 && c.total==0 && c.last==0);}
// Every resume, including terminal seal, denies the next SDK allocation.
fn engine::Event tick(ref mut engine::Engine e,usize i,usize q){
    let engine::Event before=event(engine::observe(e,i));let fill::State old=array(e,i);let copy::State prior=output(e,i);
    let calls::State previous=call(e,i);let usize previous_phase=call_phase(e,i);let metadata_budget::State previous_metadata=metadata(e,i);
    let Heap held=heap();let usize charge=memory(e).current;let usize attempts=unsafe{probe_attempts()};
    unsafe{bc_runtime_engine_test_fail(0)};let Result<engine::Event,engine::Error> r=engine::step_instance(e,i,q);
    unsafe{bc_runtime_engine_test_fail(-1)};let engine::Event after=event(r);
    assert(unsafe{probe_attempts()}==attempts && before.kind==4 && after.fuel_known && after.remaining<=before.remaining);
    same_event(after,event(engine::observe(e,i)));
    if(after.kind==4){let fill::State a=array(e,i);let copy::State o=output(e,i);let calls::State c=call(e,i);let usize phase=call_phase(e,i);let metadata_budget::State m=metadata(e,i);
        assert(m.total>=previous_metadata.total && m.total-previous_metadata.total==m.last && m.last<=4096);
        assert(a.total>=old.total && a.total-old.total==a.last && o.total>=prior.total && o.total-prior.total==o.last);
        assert(c.total>=previous.total && c.total-previous.total==c.last && c.last+a.last+o.last+m.last<=4096);
        assert(!(a.active && o.active) && !(c.pending && (a.active || o.active)));
        if(c.pending){assert(c.pc<256 && c.frame>0 && c.frame<32 && c.target<16 && phase<=5);
            if(phase<4){assert(!c.active && !c.charged && c.count==0 && c.written==0);}
            else{assert(c.count>0 && c.count<=8 && c.mark<c.end && c.phase<=1);
                if(phase==5){assert(!c.active && c.charged && c.written==c.end-c.mark);}
                else{assert(c.active && c.written<c.end-c.mark);
                    if(c.phase==0){assert(!c.charged && c.written==0);}else{assert(c.charged);}}
            }rejected_take(e,i,11);}
        if(previous.pending && q==1){assert(a.total==old.total && o.total==prior.total);
            if(previous.charged){assert(after.remaining==before.remaining && c.written>=previous.written && c.last==c.written-previous.written);}
            else if(c.pending && !c.charged && previous_phase>=1 && phase>=1){assert(after.remaining==before.remaining);}
            if(c.pending && previous_phase>=4 && phase>=4){same_recipe(previous,c);}}
        same_heap(held);ledger(e,charge);
    }else{assert(after.kind==1 || after.kind==2);rejected_progress(e,i,11);}return after;
}
fn engine::Event finish(ref mut engine::Engine e,usize i,usize mode){
    let usize[5] mixed=[1,7,3,4096,2];var engine::Event s=event(engine::observe(e,i));var usize n=0;
    while(s.kind==4){assert(n<512);s=tick(e,i,if(mode==0){1}else if(mode==1){7}else{mixed[n%5]});n+=1;}return s;
}
fn ref u8[] wide_source(){return b"module app;fn i32 use(i64[4096] a){if(a[0]!=21 || a[4095]!=21){return 0;}return 42;}pub fn i32 chosen(ref u8[] data){output::emit(ref b\"\\x00\\xFF!\");let i64[4096] a=[data[0] as i64;4096];let i32 r=use(a);output::emit(ref data);return r;}";}
// First paid 4096-byte batch of the actual maximum-width CALL. Neither pending
// validation nor an array CREATE is mistaken for a prepaid CALL continuation.
fn Admission seek_call(ref mut engine::Engine e,usize i,usize budget){var usize n=0;
    while(n<256){assert(tick(e,i,1).kind==4);
        let engine::Event after=event(engine::observe(e,i));let calls::State c=call(e,i);
        if(c.pending && c.charged && c.written>0){
            assert(c.phase==1 && c.count==1 && c.mark==32768 && c.end==65536 && c.written==1024 && c.last==1024 && metadata(e,i).last==3072);
            rejected_take(e,i,11);return Admission{.fuel=budget-after.remaining,.remaining=after.remaining};}n+=1;
    }assert(false);return Admission{.fuel=0,.remaining=0};
}

// 1. One immutable maximum i64 source and its CALL copy occupy exactly 65536
// owner bytes. q=1, q=7 and mixed batches retain sync result/Fuel/binary output.
fn Result<usize,u8> wide_call_fixed_and_mixed_quanta(){var engine::Engine e=created()?;
    let usize p=compiled(ref mut e,wide_source())?;let engine::Output baseline=synchronous(ref mut e,p,b"\x15\x00\xFF",16000000)?;
    assert(completion(ref baseline).kind==1 && completion(ref baseline).value==42);binary_output(ref baseline,b"\x15\x00\xFF");
    var usize mode=0;while(mode<3){let usize i=bound(ref mut e,p,b"\x15\x00\xFF",16000000)?;prepare(ref mut e,i);
        if(mode==0){let Admission paid=seek_call(ref mut e,i,16000000);assert(paid.fuel>0 && paid.remaining>0);
            var usize batches=1;var usize ticks=0;var usize written=call(ref e,i).written;
            while(written<32768){assert(ticks<64);assert(tick(ref mut e,i,1).kind==4);ticks+=1;
                let calls::State c=call(ref e,i);let metadata_budget::State m=metadata(ref e,i);
                if(c.last==0){assert(m.last==4096 && c.written==written);}
                else{batches+=1;assert(c.written==written+c.last && c.last+m.last<=4096);
                    if(c.written<32768){assert(c.last+m.last==4096);}written=c.written;}
                assert(c.pending && c.active==(c.written<32768));assert(event(engine::observe(ref mut e,i)).remaining==paid.remaining);
            }
            assert(batches>8);
            assert(call_phase(ref e,i)==5 && metadata(ref e,i).last==3072);
            assert(tick(ref mut e,i,1).kind==4);let calls::State published=call(ref e,i);
            assert(!published.pending && !published.active && published.last==0 && published.written==32768);
            assert(metadata(ref e,i).last==4096 && output(ref e,i).total==3);}
        same_event(finish(ref mut e,i,mode),completion(ref baseline));let engine::Output o=take(ref mut e,i)?;
        same_output(ref o,ref baseline);destroy(ref mut e,i);ledger(ref e,0);mode+=1;
    }close(ref mut e,p);return .ok(0);
}

// 2. Bool validation/copy, canonical padded record, scalar/reference positions
// and a mutable record capture before a later actual's side effect. Reference
// arguments use the existing source-level slice syntax, not a synthetic ticket.
fn Result<usize,u8> mixed_record_bool_reference_and_capture(){var engine::Engine e=created()?;
    let usize p=compiled(ref mut e,b"module app;struct P{bool ok;i64 x;}fn i32 use(P before,bool[4096] flags,i32 stamp,ref u8[] data,P after){output::emit(ref data);if(!before.ok || !after.ok || !flags[0] || !flags[4095] || before.x!=2 || after.x!=4 || stamp!=18){return 0;}return 42;}pub fn i32 chosen(ref u8[] data){output::emit(ref b\"\\x00\\xFF!\");var P p=P{.ok=true,.x=2};let bool[4096] flags=[true;4096];let u8[4093] local=[data[0];4093];let Option<i32> o=.none;let i32 r=use(p,flags,switch(o){case .some(v):{v}case .none:{p.x=4;18}},ref local,p);if(p.x!=4){return 0;}return r;}")?;
    let u8[4093] data=[255;4093];let engine::Output baseline=synchronous(ref mut e,p,ref data,16000000)?;
    assert(completion(ref baseline).kind==1 && completion(ref baseline).value==42);binary_output(ref baseline,ref data);
    var usize mode=0;while(mode<3){let usize i=bound(ref mut e,p,ref data,16000000)?;prepare(ref mut e,i);
        if(mode==0){var bool validated=false;var bool charged=false;var usize n=0;
            while(!charged){assert(n<256 && tick(ref mut e,i,1).kind==4);n+=1;let calls::State c=call(ref e,i);
                if(c.pending && call_phase(ref e,i)>=4 && c.total>0){assert(c.count==3);if(c.phase==0){assert(!c.charged && c.written==0);validated=true;}
                    else{assert(validated && c.charged && c.written>0);charged=true;}}
            }}
        same_event(finish(ref mut e,i,mode),completion(ref baseline));let engine::Output o=take(ref mut e,i)?;
        same_output(ref o,ref baseline);destroy(ref mut e,i);ledger(ref e,0);mode+=1;
    }close(ref mut e,p);return .ok(0);
}

// 3. Exact whole-program Fuel succeeds at zero; one less matches synchronous
// failure. Exact CALL admission must finish prepaid copy at zero BEFORE Fuel
// gating, whereas one less cannot enter that unpaid CALL continuation.
fn Result<usize,u8> exact_and_one_less_fuel_zero_continuation(){var engine::Engine e=created()?;
    let usize p=compiled(ref mut e,wide_source())?;let engine::Output full=synchronous(ref mut e,p,b"\x15",16000000)?;
    assert(completion(ref full).kind==1 && completion(ref full).value==42);let usize price=16000000-completion(ref full).remaining;
    var usize short=0;while(short<2){let usize fuel=price-short;let engine::Output baseline=synchronous(ref mut e,p,b"\x15",fuel)?;
        let usize i=bound(ref mut e,p,b"\x15",fuel)?;prepare(ref mut e,i);let engine::Event done=finish(ref mut e,i,1);
        same_event(done,completion(ref baseline));assert(done.kind==if(short==0){1}else{2});
        if(short==0){assert(done.value==42 && done.remaining==0);}else{assert(done.diagnostic.code.kind==8);}
        let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);destroy(ref mut e,i);short+=1;
    }
    let usize measured=bound(ref mut e,p,b"\x15",16000000)?;prepare(ref mut e,measured);
    let Admission paid=seek_call(ref mut e,measured,16000000);destroy(ref mut e,measured);assert(paid.fuel<price);
    short=0;while(short<2){let usize fuel=paid.fuel-short;let engine::Output baseline=synchronous(ref mut e,p,b"\x15",fuel)?;
        let usize i=bound(ref mut e,p,b"\x15",fuel)?;prepare(ref mut e,i);
        if(short==0){let Admission zero=seek_call(ref mut e,i,fuel);assert(zero.remaining==0 && zero.fuel==fuel);
            // Seven prepaid batches remain after the first admission batch.
            assert(tick(ref mut e,i,1).kind==4 && event(engine::observe(ref mut e,i)).remaining==0);}
        let engine::Event done=finish(ref mut e,i,0);assert(done.kind==2 && done.diagnostic.code.kind==8);
        same_event(done,completion(ref baseline));let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);
        assert(!engine::output_available(ref o) && engine::output_view(ref o).len==0);destroy(ref mut e,i);ledger(ref e,0);short+=1;
    }close(ref mut e,p);return .ok(0);
}

// 4. Interleave distinct real CALL continuations, move Engine twice, cancel
// one halfway through its unpublished copy and complete the other. Releasing
// the Program handle retains exactly the live Instance pins until destruction.
fn Result<usize,u8> cancel_midcopy_refund_moves_and_program_release(){var engine::Engine original=created()?;
    let usize p=compiled(ref mut original,wide_source())?;let engine::Output baseline=synchronous(ref mut original,p,b"\x15\x00",16000000)?;
    let usize a=bound(ref mut original,p,b"\x14\xFF",16000000)?;let usize b=bound(ref mut original,p,b"\x15\x00",16000000)?;
    let usize retained=memory(ref original).current;let Heap ready=heap();prepare(ref mut original,a);
    let usize pending=memory(ref original).current-retained;let Heap one=heap();assert(pending>0);
    let usize pending_blocks=one.blocks-ready.blocks;let usize pending_bytes=one.bytes-ready.bytes;
    assert(pending_blocks>0 && pending_bytes>0);prepare(ref mut original,b);
    let Admission first=seek_call(ref mut original,a,16000000);let engine::Event saved=event(engine::observe(ref mut original,a));
    let calls::State frozen=call(ref original,a);
    let Admission second=seek_call(ref mut original,b,16000000);assert(first.fuel==second.fuel);
    same_event(saved,event(engine::observe(ref mut original,a)));same_progress(frozen,call(ref original,a));assert(id(engine::release_program(ref mut original,p))==p);
    counts(ref mut original,1,2,2);let Heap held=heap();var engine::Engine moved=original;same_heap(held);
    same_progress(frozen,call(ref moved,a));assert(tick(ref mut moved,b,1).kind==4);same_event(saved,event(engine::observe(ref mut moved,a)));
    var engine::Engine e=moved;same_heap(held);same_progress(frozen,call(ref e,a));let usize attempts=unsafe{probe_attempts()};unsafe{bc_runtime_engine_test_fail(0)};
    let Result<engine::Event,engine::Error> r=engine::cancel_ready(ref mut e,a);unsafe{bc_runtime_engine_test_fail(-1)};
    let engine::Event stopped=event(r);assert(unsafe{probe_attempts()}==attempts && stopped.kind==3 && stopped.remaining==saved.remaining && stopped.fuel_known);
    assert(stopped.value==0 && stopped.diagnostic.code.kind==0);rejected_take(ref mut e,a,2);
    rejected_progress(ref e,a,11);
    same_heap(Heap{.blocks=held.blocks-pending_blocks,.bytes=held.bytes-pending_bytes});ledger(ref e,retained+pending);
    same_event(stopped,event(engine::cancel_ready(ref mut e,a)));same_event(stopped,event(engine::observe(ref mut e,a)));
    // Complete peer before comparing to pre-preparation heap: only bound inputs
    // remain; cancellation must have freed a's entire pending backing as well.
    same_event(finish(ref mut e,b,1),completion(ref baseline));
    {let engine::Output o=take(ref mut e,b)?;same_output(ref o,ref baseline);}
    same_heap(ready);ledger(ref e,retained);counts(ref mut e,1,2,2);
    destroy(ref mut e,a);counts(ref mut e,1,1,1);destroy(ref mut e,b);ledger(ref e,0);counts(ref mut e,0,0,0);
    assert(id(engine::destroy(ref mut e))==0);return .ok(0);
}
pub fn void run(){let Heap before=heap();
    assert(wide_call_fixed_and_mixed_quanta().is_ok);same_heap(before);
    assert(mixed_record_bool_reference_and_capture().is_ok);same_heap(before);
    assert(exact_and_one_less_fuel_zero_continuation().is_ok);same_heap(before);
    assert(cancel_midcopy_refund_moves_and_program_release().is_ok);same_heap(before);
}
