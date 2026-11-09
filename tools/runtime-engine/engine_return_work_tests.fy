module engine_return_work_tests;
import runtime_engine as engine;
import engine_lifecycle_tests as lifecycle;
import runtime_live_memory as live;
import runtime_input as inputs;
import module_output_program as programs;
import module_input_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import return_work_cursor as returns;
import metadata_budget as metadata;
import array_fill_cursor as fill;
import output_copy_cursor as copy;
import call_copy_cursor as calls;
import struct_nested_storage as records;
import std::bytes as bytes;

// Actual source/owning Engine only. Parent owns API, runner and native checks.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
struct Heap { usize blocks; usize bytes; }
struct Admission { usize before; usize after; usize chunks; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void same_heap(Heap h){assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes);}
fn usize id(Result<usize,engine::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn engine::Event event(Result<engine::Event,engine::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,.remaining=0,.fuel_known=false,.diagnostic=diagnostics::absent(errors::make(0,0))}}};}
fn returns::State progress(ref engine::Engine e,usize i){return switch(engine::return_work_progress(e,i)){case .ok(v):{v}case .err(_):{assert(false);returns::State{.total=0,.last=0,.pc=0,.frame=0,.required=0,.op=0}}};}
fn fill::State array(ref engine::Engine e,usize i){return switch(engine::array_copy_progress(e,i)){case .ok(v):{v}case .err(_):{assert(false);fill::empty()}};}
fn copy::State output(ref engine::Engine e,usize i){return switch(engine::output_copy_progress(e,i)){case .ok(v):{v}case .err(_):{assert(false);copy::empty()}};}
fn calls::State call(ref engine::Engine e,usize i){return switch(engine::call_copy_progress(e,i)){case .ok(v):{v}case .err(_):{assert(false);calls::empty()}};}
fn metadata::State authority(ref engine::Engine e,usize i){return switch(engine::authority_metadata_progress(e,i)){
    case .ok(v):{v}case .err(_):{assert(false);metadata::empty()}};}
fn usize phase(ref engine::Engine e,usize i){return switch(engine::return_metadata_phase(e,i)){
    case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void same_progress(returns::State a,returns::State b){assert(a.total==b.total && a.last==b.last && a.pc==b.pc && a.frame==b.frame && a.required==b.required && a.op==b.op);}
fn void rejected_progress(ref engine::Engine e,usize i,u32 status){switch(engine::return_work_progress(e,i)){case .ok(_):{assert(false);}case .err(v):{assert(v.status==status);}};}
fn void rejected_take(ref mut engine::Engine e,usize i,u32 status){switch(engine::take_output(e,i)){case .ok(_):{assert(false);}case .err(v):{assert(v.status==status);}};}
fn live::Observation memory(ref engine::Engine e){return switch(engine::instance_memory(e)){case .ok(v):{v}case .err(_):{assert(false);live::Observation{.instance_limit=0,.instances_limit=0,.current=0,.peak=0,.closed=false}}};}
fn void ledger(ref engine::Engine e,usize current){let live::Observation m=memory(e);assert(m.current==current && current<=m.peak && m.peak<=m.instances_limit && !m.closed);
    switch(engine::program_memory(e)){case .ok(v):{assert(v.external_bytes==current && v.tracked_bytes==v.control_bytes+v.program_bytes+current && v.tracked_bytes<=v.tracked_peak && v.tracked_peak<=v.engine_limit && !v.closed);}case .err(_):{assert(false);}};}
fn void counts(ref mut engine::Engine e,usize p,usize i,usize pins){switch(engine::inspect(e)){case .ok(v):{assert(v.programs==p && v.instances==i && v.pins==pins && !v.closed);}case .err(_):{assert(false);}};}
fn void same_event(engine::Event a,engine::Event b){assert(a.kind==b.kind && a.value==b.value && a.remaining==b.remaining && a.fuel_known==b.fuel_known);
    assert(a.diagnostic.code.kind==b.diagnostic.code.kind && a.diagnostic.code.offset==b.diagnostic.code.offset && a.diagnostic.at.source==b.diagnostic.at.source && a.diagnostic.at.start==b.diagnostic.at.start && a.diagnostic.at.end==b.diagnostic.at.end);}
fn Result<engine::Engine,u8> created(){return switch(engine::create(engine::Limits{.programs=2,.instances=2,.fuel=16000000})){case .ok(v):{.ok(v)}case .err(_):{.err(1)}};}
fn Result<entries::InputEntry,u8> selected(ref u8[] source){var sources::Builder b=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{return .err(2);}};
    if(!sources::add(ref mut b,b"app.brc",source).is_ok){return .err(3);}let sources::Snapshot s=switch(sources::freeze(ref b)){case .ok(v):{v}case .err(_):{return .err(4);}};
    let modules::Index index=switch(modules::build(s)){case .ok(v):{v}case .err(_):{return .err(5);}};
    return switch(entries::select_i32_input(index,b"app",b"chosen")){case .ok(v):{.ok(v)}case .err(_):{.err(6)}};}
fn Result<usize,u8> compiled(ref mut engine::Engine e,ref u8[] source){return .ok(id(engine::compile_input_output(e,selected(source)?,65536)));}
fn Result<usize,u8> bound(ref mut engine::Engine e,usize p,ref u8[] data,usize fuel){var usize spent=0;
    let inputs::Snapshot input=switch(inputs::snapshot(data,inputs::hard_limit(),0,ref mut spent)){case .ok(v):{v}case .err(_):{return .err(7);}};
    return .ok(id(engine::create_input_output_instance(e,p,input,fuel,data.len+1,true)));}
fn Result<engine::Output,u8> take(ref mut engine::Engine e,usize i){return switch(engine::take_output(e,i)){case .ok(v):{.ok(v)}case .err(_):{.err(8)}};}
fn engine::Event completion(ref engine::Output o){let programs::Completion c=engine::output_completion(o);return engine::Event{.kind=if(c.success){1}else{2},.value=c.value,.remaining=c.remaining,.fuel_known=true,.diagnostic=c.diagnostic};}
fn void same_output(ref engine::Output a,ref engine::Output b){same_event(completion(a),completion(b));let programs::Completion x=engine::output_completion(a);let programs::Completion y=engine::output_completion(b);
    assert(x.emits==y.emits && x.output_bytes==y.output_bytes && engine::output_available(a)==engine::output_available(b) && bytes::equal(engine::output_view(a),engine::output_view(b)));}
fn void binary_output(ref engine::Output o,ref u8[] data){let ref u8[] v=engine::output_view(o);assert(engine::output_available(o) && v.len==data.len+1 && bytes::equal(v[..1],b"x") && bytes::equal(v[1..],data) && engine::output_completion(o).emits==2);}
fn void destroy(ref mut engine::Engine e,usize i){assert(id(engine::destroy_instance(e,i))==i);}
fn void close(ref mut engine::Engine e,usize p){assert(id(engine::release_program(e,p))==p);assert(id(engine::destroy(e))==0);}
fn Result<engine::Output,u8> synchronous(ref mut engine::Engine e,usize p,ref u8[] data,usize fuel){let usize i=bound(e,p,data,fuel)?;
    let engine::Event done=event(engine::execute_once(e,i));let engine::Output o=take(e,i)?;same_event(done,completion(ref o));destroy(e,i);return .ok(o);}
fn void prepare(ref mut engine::Engine e,usize i){rejected_progress(e,i,11);assert(event(engine::prepare_instance(e,i)).kind==4);lifecycle::warm(e,i);
    same_progress(progress(e,i),returns::State{.total=0,.last=0,.pc=0,.frame=0,.required=0,.op=0});}
// Every resume denies SDK allocations, including terminal/error sealing. Only
// phase 3 exposes progress; totals/last measure reads, never a payload copy.
fn engine::Event tick(ref mut engine::Engine e,usize i,usize q){let engine::Event before=event(engine::observe(e,i));let returns::State old=progress(e,i);
    let metadata::State m0=authority(e,i);let fill::State a0=array(e,i);let copy::State o0=output(e,i);let calls::State c0=call(e,i);let Heap h=heap();let usize charge=memory(e).current;let usize attempts=unsafe{probe_attempts()};
    unsafe{bc_runtime_engine_test_fail(0)};let Result<engine::Event,engine::Error> r=engine::step_instance(e,i,q);unsafe{bc_runtime_engine_test_fail(-1)};let engine::Event after=event(r);
    assert(before.kind==4 && after.fuel_known && after.remaining<=before.remaining && unsafe{probe_attempts()}==attempts);same_event(after,event(engine::observe(e,i)));
    if(after.kind==4){let returns::State v=progress(e,i);let fill::State a=array(e,i);let copy::State o=output(e,i);let calls::State c=call(e,i);
        assert(v.total>=old.total && v.total-old.total==v.last && a.total>=a0.total && a.total-a0.total==a.last && o.total>=o0.total && o.total-o0.total==o.last && c.total>=c0.total && c.total-c0.total==c.last);
        let metadata::State m=authority(e,i);assert(m.total>=m0.total && m.total-m0.total==m.last);
        assert(v.last+c.last+a.last+o.last+m.last<=4096);assert(v.required<=4096);if(v.op!=0){assert(v.pc<256 && v.frame>0 && v.frame<32);}
        same_heap(h);ledger(e,charge);
    }else{assert(after.kind==1 || after.kind==2);rejected_progress(e,i,11);}return after;}
fn engine::Event finish(ref mut engine::Engine e,usize i,usize mode){let usize[5] mixed=[1,7,3,4096,2];var usize n=0;var engine::Event s=event(engine::observe(e,i));
    while(s.kind==4){assert(n<512);s=tick(e,i,if(mode==0){1}else if(mode==1){7}else{mixed[n%5]});n+=1;}return s;}
fn ref u8[] bool_source(){return b"module app;fn bool[4096] make(ref u8[] data){let bool[4096] a=[true;4096];output::emit(ref b\"x\");return a;}pub fn i32 chosen(ref u8[] data){let bool[4096] a=make(ref data);if(!a[0] || !a[4095]){return 0;}output::emit(ref data);return 42;}";}

// Observe prefix Fuel separately from validation, then wait through authority
// restoration to derive the same full return Fuel price as the atomic oracle.
fn Admission accepted(ref mut engine::Engine e,usize i,usize measure,u8 op){var usize n=0;var usize admitted=0;var usize prefix=0;
    while(n<256){let engine::Event before=event(engine::observe(e,i));let fill::State a=array(e,i);let copy::State o=output(e,i);let calls::State c=call(e,i);
        let engine::Event after=tick(e,i,1);n+=1;assert(after.kind==4);let returns::State r=progress(e,i);
        if(r.total==0 && before.remaining>after.remaining){prefix=before.remaining;}
        if(r.total!=0){assert(r.total==measure && r.required==measure && r.op==op);
            if(admitted==0){assert(r.last==measure && before.remaining==after.remaining && prefix>before.remaining);admitted=prefix;}
            else{assert(r.last==0);}
            assert(array(e,i).total==a.total && output(e,i).total==o.total && call(e,i).total==c.total);
            if(phase(e,i)==4){assert(authority(e,i).last==4096 && after.remaining<before.remaining);
                return Admission{.before=admitted,.after=after.remaining,.chunks=n};}
        }}
    assert(false);return Admission{.before=0,.after=0,.chunks=0};}
// A q=4096 batch must stop after the one-byte prefix with no accepted RET.
// Later q=1 steps prepare the RET, then admit the whole bool scan.
// CALL context preparation now yields before the return-prefix fixture.
// Keep a finite scheduling bound while allowing those admitted stages.
fn Admission deferred(ref mut engine::Engine e,usize i){var usize n=0;
    while(n<64){let engine::Event s=tick(e,i,4096);n+=1;assert(s.kind==4);let returns::State r=progress(e,i);assert(r.total==0 && r.last==0);
        if(output(e,i).total==1){assert(output(e,i).last==1 && !output(e,i).active && array(e,i).total==4096 && !array(e,i).active);
            same_progress(r,returns::State{.total=0,.last=0,.pc=0,.frame=0,.required=0,.op=0});
            same_event(s,event(engine::observe(e,i)));same_progress(r,progress(e,i));rejected_take(e,i,11);
            return Admission{.before=s.remaining,.after=s.remaining,.chunks=n};}}
    assert(false);return Admission{.before=0,.after=0,.chunks=0};}

// 1. Real bool[4096] ARET: fixed/mixed parity, whole-byte admission after an
// earlier emit, exact/one-less whole-run Fuel and exact/one-less RET admission.
fn Result<usize,u8> bool_return_quanta_admission_and_fuel(){var engine::Engine e=created()?;let usize p=compiled(ref mut e,bool_source())?;
    let engine::Output baseline=synchronous(ref mut e,p,b"\x00\xFF!",16000000)?;assert(completion(ref baseline).kind==1 && completion(ref baseline).value==42);binary_output(ref baseline,b"\x00\xFF!");
    let usize measured=bound(ref mut e,p,b"\x00\xFF!",16000000)?;prepare(ref mut e,measured);let Admission paid=accepted(ref mut e,measured,4096,39);
    assert(paid.chunks>0 && paid.before>paid.after);destroy(ref mut e,measured);let usize price=16000000-completion(ref baseline).remaining;let usize admission=16000000-paid.after;assert(admission<price);
    var usize mode=0;while(mode<3){let usize i=bound(ref mut e,p,b"\x00\xFF!",16000000)?;prepare(ref mut e,i);
        if(mode==0){let Admission wait=deferred(ref mut e,i);assert(wait.before==paid.before && wait.chunks>=2);
            let Admission done=accepted(ref mut e,i,4096,39);assert(done.chunks>1 && done.before==paid.before && done.after==paid.after);}
        same_event(finish(ref mut e,i,mode),completion(ref baseline));let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);destroy(ref mut e,i);ledger(ref e,0);mode+=1;}
    var usize variant=0;while(variant<4){let usize budget=if(variant<2){price-variant}else{admission-(variant-2)};
        let engine::Output sync=synchronous(ref mut e,p,b"\x00\xFF!",budget)?;let usize i=bound(ref mut e,p,b"\x00\xFF!",budget)?;prepare(ref mut e,i);
        if(variant==2){let Admission zero=accepted(ref mut e,i,4096,39);assert(zero.after==0 && zero.before==paid.before-paid.after);}
        var engine::Event s=event(engine::observe(ref mut e,i));var usize n=0;while(s.kind==4){assert(n<256);s=tick(ref mut e,i,1);n+=1;
            if(s.kind==4 && variant==3){assert(progress(ref e,i).total==0);}}
        same_event(s,completion(ref sync));if(variant==0){assert(s.kind==1 && s.value==42 && s.remaining==0);}else{assert(s.kind==2 && s.diagnostic.code.kind==8);}
        let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref sync);if(variant==0){binary_output(ref o,b"\x00\xFF!");}else{assert(!engine::output_available(ref o) && engine::output_view(ref o).len==0);}
        destroy(ref mut e,i);ledger(ref e,0);variant+=1;}
    close(ref mut e,p);return .ok(0);}

fn ref u8[] record_source(){return b"module app;struct P{bool flag;i64 x;}struct R{bool flag;P child;u8 tail;}fn R make(ref u8[] data){let R r=R{.flag=true,.child=P{.flag=true,.x=data[0] as i64},.tail=255};output::emit(ref b\"x\");return r;}pub fn i32 chosen(ref u8[] data){let R r=make(ref data);if(!r.flag || !r.child.flag || r.child.x!=data[0] as i64 || r.tail!=255){return 0;}output::emit(ref data);return 42;}";}
fn Result<usize,u8> compile_small(ref mut engine::Engine e,usize mode){
    if(mode==0){return compiled(e,record_source());}
    if(mode==1){return compiled(e,b"module app;fn i32 make(ref u8[] data){output::emit(ref b\"x\");return 42;}pub fn i32 chosen(ref u8[] data){let i32 n=make(ref data);output::emit(ref data);return n;}");}
    if(mode==2){return compiled(e,b"module app;fn void make(ref u8[] data){output::emit(ref b\"x\");return;}pub fn i32 chosen(ref u8[] data){make(ref data);output::emit(ref data);return 42;}");}
    return compiled(e,b"module app;fn i64[2] make(ref u8[] data){let i64[2] a=[data[0] as i64;2];output::emit(ref b\"x\");return a;}pub fn i32 chosen(ref u8[] data){let i64[2] a=make(ref data);if(a[0]!=data[0] as i64 || a[1]!=data[0] as i64){return 0;}output::emit(ref data);return 42;}");
}
// Derive from the ACTUAL root-selected source catalog, never hand-built IR or
// an invented Expected layout. Scratch clear + size + scalar bytes + bool reads.
fn Result<usize,u8> record_measure(){let programs::Program p=switch(programs::compile_input(selected(record_source())?,65536)){case .ok(v):{v}case .err(_):{return .err(9);}};
    var usize pc=0;var usize measure=0;var usize found=0;while(pc<programs::code(ref p).body.count){if(programs::code(ref p).body.code[pc*8]==50){
        let usize site=programs::code(ref p).body.code[pc*8+2] as usize;let usize nominal=programs::code(ref p).body.records.records[site] as usize;
        let records::Staging s=switch(records::staging(ref programs::code(ref p).body.records.layouts,nominal)){case .ok(v):{v}case .err(_):{return .err(10);}};
        assert(s.size>s.scalar_bytes && s.bools==2 && s.leaves==4);measure=128+s.size+s.scalar_bytes+s.bools;assert(measure>128 && measure<=512);found+=1;}pc+=1;}
    assert(found==1);return .ok(measure);}

// 2. Nested bool/padding SRET validates a small snapshot then moves its token.
// Ordinary scalar, void and non-bool ARET have zero return payload work.
fn Result<usize,u8> padded_record_and_zero_payload_returns(){let usize measure=record_measure()?;var usize mode=0;
    while(mode<4){var engine::Engine e=created()?;let usize p=compile_small(ref mut e,mode)?;
        let engine::Output baseline=synchronous(ref mut e,p,b"\x2A\x00\xFF",16000000)?;assert(completion(ref baseline).kind==1 && completion(ref baseline).value==42);binary_output(ref baseline,b"\x2A\x00\xFF");
        var usize schedule=0;while(schedule<3){let usize i=bound(ref mut e,p,b"\x2A\x00\xFF",16000000)?;prepare(ref mut e,i);
            if(mode==0 && schedule==0){let Admission paid=accepted(ref mut e,i,measure,50);assert(paid.chunks>0 && paid.before>paid.after);}
            let usize[5] mixed=[1,7,3,4096,2];var engine::Event s=event(engine::observe(ref mut e,i));var usize n=0;var bool seen_void=false;var bool seen_scalar=false;var bool seen_array=false;
            while(s.kind==4){assert(n<256);s=tick(ref mut e,i,if(schedule==0){1}else if(schedule==1){7}else{mixed[n%5]});n+=1;
                if(s.kind==4){let returns::State r=progress(ref e,i);if(mode!=0){assert(r.total==0 && r.last==0 && r.required==0);}
                    if(r.op==82){seen_void=true;}if(r.op==8){seen_scalar=true;}if(r.op==39){seen_array=true;}
                    if(mode==0){assert(r.total==0 || r.total==measure);if(schedule==0){assert(r.total==measure);}} }}
            if(schedule==0){if(mode==1){assert(seen_scalar);}if(mode==2){assert(seen_void);}if(mode==3){assert(seen_array);}}
            same_event(s,completion(ref baseline));let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);destroy(ref mut e,i);ledger(ref e,0);schedule+=1;}
        close(ref mut e,p);mode+=1;}return .ok(0);}

// 3. Cancel a deferred, unaccepted bool return after prefix staging. Interleave
// its peer, move Engine twice and release Program: pins keep both sources alive.
fn Result<usize,u8> cancel_deferred_return_refund_moves_and_pins(){var engine::Engine original=created()?;let usize p=compiled(ref mut original,bool_source())?;
    let engine::Output baseline=synchronous(ref mut original,p,b"\x00\xFF!",16000000)?;
    let usize a=bound(ref mut original,p,b"\x01\x00!",16000000)?;let usize b=bound(ref mut original,p,b"\x00\xFF!",16000000)?;let usize retained=memory(ref original).current;let Heap ready=heap();
    prepare(ref mut original,a);let usize pending=memory(ref original).current-retained;let Heap one=heap();assert(pending>0 && one.blocks>ready.blocks && one.bytes>ready.bytes);prepare(ref mut original,b);
    let Admission left=deferred(ref mut original,a);let engine::Event saved=event(engine::observe(ref mut original,a));let returns::State frozen=progress(ref original,a);
    let Admission right=deferred(ref mut original,b);assert(left.chunks==right.chunks);same_event(saved,event(engine::observe(ref mut original,a)));same_progress(frozen,progress(ref original,a));
    assert(id(engine::release_program(ref mut original,p))==p);counts(ref mut original,1,2,2);let Heap held=heap();var engine::Engine moved=original;same_heap(held);same_progress(frozen,progress(ref moved,a));
    let Admission accepted_peer=accepted(ref mut moved,b,4096,39);assert(accepted_peer.chunks>1);same_event(saved,event(engine::observe(ref mut moved,a)));same_progress(frozen,progress(ref moved,a));
    var engine::Engine e=moved;same_heap(held);same_progress(frozen,progress(ref e,a));let usize attempts=unsafe{probe_attempts()};
    let engine::Event stopped=lifecycle::stop(ref mut e,a);
    assert(unsafe{probe_attempts()}==attempts && stopped.kind==3 && stopped.value==0 && stopped.fuel_known && stopped.remaining==saved.remaining && stopped.diagnostic.code.kind==0);
    rejected_progress(ref e,a,11);rejected_take(ref mut e,a,2);same_heap(Heap{.blocks=held.blocks-(one.blocks-ready.blocks),.bytes=held.bytes-(one.bytes-ready.bytes)});ledger(ref e,retained+pending);
    same_event(stopped,event(engine::cancel_ready(ref mut e,a)));same_event(stopped,event(engine::observe(ref mut e,a)));same_event(finish(ref mut e,b,0),completion(ref baseline));
    {let engine::Output o=take(ref mut e,b)?;same_output(ref o,ref baseline);}same_heap(ready);ledger(ref e,retained);counts(ref mut e,1,2,2);
    destroy(ref mut e,a);counts(ref mut e,1,1,1);rejected_progress(ref e,a,2);destroy(ref mut e,b);ledger(ref e,0);counts(ref mut e,0,0,0);assert(id(engine::destroy(ref mut e))==0);return .ok(0);}
// 4. RET publication consumes a fresh metadata allowance. Its following
// COPY/SNAPSHOT starts in a later batch, after both validation and publication.
fn Result<usize,u8> compile_following_copy(ref mut engine::Engine e,bool record){
    if(record){return compiled(e,b"module app;struct R{i64 a;i64 b;i64 c;i64 d;i64 e;i64 f;i64 g;i64 h;}fn bool[3920] make(ref u8[] data){let bool[3920] a=[true;3920];return a;}pub fn i32 chosen(ref u8[] data){let R prior=R{.a=42,.b=42,.c=42,.d=42,.e=42,.f=42,.g=42,.h=42};let bool[3920] a=make(ref data);let R copy=prior;if(!a[3919] || copy.h!=42){return 0;}return 42;}");}
    return compiled(e,b"module app;fn bool[4000] make(ref u8[] data){let bool[4000] a=[true;4000];return a;}pub fn i32 chosen(ref u8[] data){let i64[64] prior=[42;64];let bool[4000] a=make(ref data);let i64[64] copy=prior;if(!a[3999] || copy[63]!=42){return 0;}return 42;}");}
fn Result<usize,u8> return_publication_defers_following_array_and_record_copy(){var usize mode=0;
    while(mode<2){var engine::Engine e=created()?;let usize p=compile_following_copy(ref mut e,mode==1)?;
        let engine::Output baseline=synchronous(ref mut e,p,b"!",16000000)?;assert(completion(ref baseline).kind==1 && completion(ref baseline).value==42);
        var usize schedule=0;while(schedule<4){let usize i=bound(ref mut e,p,b"!",16000000)?;prepare(ref mut e,i);
            let usize[5] mixed=[1,7,3,4096,2];var engine::Event s=event(engine::observe(ref mut e,i));var usize n=0;var bool validation=false;var bool published=false;var bool separated=false;
            while(s.kind==4){assert(n<256);let usize q=if(schedule==0){4096}else if(schedule==1){1}else if(schedule==2){7}else{mixed[n%5]};s=tick(ref mut e,i,q);n+=1;
                if(s.kind==4){let returns::State r=progress(ref e,i);let fill::State a=array(ref e,i);
                    let metadata::State m=authority(ref e,i);
                    if(r.last!=0 && r.op==39){validation=true;assert(m.last+r.last==4096);}
                    if(!published && r.op==39 && phase(ref e,i)==4){published=true;assert(m.last==4096 && a.last==0);}
                    if(a.last!=0 && a.op==if(mode==0){34}else{42} && r.total!=0){separated=true;assert(validation && published && r.last==0 && m.last==0 && a.written>0);}}}
            if(schedule==0){assert(validation && published && separated);}same_event(s,completion(ref baseline));let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);destroy(ref mut e,i);ledger(ref e,0);schedule+=1;}
        close(ref mut e,p);mode+=1;}return .ok(0);}
pub fn void run(){let Heap before=heap();
    assert(bool_return_quanta_admission_and_fuel().is_ok);same_heap(before);
    assert(padded_record_and_zero_payload_returns().is_ok);same_heap(before);
    assert(cancel_deferred_return_refund_moves_and_pins().is_ok);same_heap(before);
    assert(return_publication_defers_following_array_and_record_copy().is_ok);same_heap(before);
}
