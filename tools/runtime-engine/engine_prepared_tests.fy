module engine_prepared_tests;
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
import std::num as num;
import std::bytes as bytes;

// Native Engine-owned preparation only: no step, guest execution or publication.
// Reuse heap-observer.c, test-host.inc and compile-test-host.inc. The parent
// owns guard/owner transport probes, layout fixtures and runner integration.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
unsafe extern C fn void bc_runtime_engine_test_seed(ptr mut void owner,u32 kind);
unsafe extern C fn usize bc_runtime_engine_test_compile_epoch(ptr void owner);
unsafe extern C fn usize bc_runtime_engine_test_compile_next(ptr void owner);
unsafe extern C fn void bc_runtime_engine_test_inject_output_fault(u32 stage);

struct Heap { usize blocks; usize bytes; }
struct Plan { usize pending; usize input; usize combined; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void same_heap(ref Heap before){
    assert(unsafe{probe_live()}==before.blocks && unsafe{probe_live_bytes()}==before.bytes);
}
fn engine::Limits limits(){return engine::Limits{.programs=4,.instances=64,.fuel=16000000};}
fn Result<engine::Engine,u8> created(usize single,usize aggregate,memory::Limits retained){
    let usize control=switch(engine::required_control_bytes(limits())){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    // Never recover a failed quota factory by recursing with the same ceiling.
    return switch(engine::create_with_instance_memory(limits(),control,retained,268435456,
        live::Limits{.instance=single,.instances=aggregate})){
        case .ok(v):{.ok(v)}case .err(_):{.err(2)}
    };
}
fn Result<engine::Engine,u8> generous(){return created(268435456,536870912,memory::defaults());}
fn usize id(Result<usize,engine::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn engine::Event event(Result<engine::Event,engine::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,
        .diagnostic=diagnostics::absent(errors::make(0,0)),.remaining=0,.fuel_known=false}}
};}
fn void rejected(Result<engine::Event,engine::Error> result,u32 status){switch(result){
    case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}
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
fn memory::Observation retained(ref engine::Engine e){return switch(engine::program_memory(e)){
    case .ok(v):{v}case .err(_):{assert(false);memory::Observation{
        .engine_limit=0,.program_limit=0,.programs_limit=0,.control_bytes=0,
        .program_bytes=0,.program_peak=0,.tracked_bytes=0,.tracked_peak=0,
        .closed=false,.working_limit=0,.working_peak=0,.external_bytes=0}}
};}
fn void ledger(ref engine::Engine e,usize current){
    let live::Observation l=instance(e);let memory::Observation m=retained(e);
    assert(l.current==current && l.current<=l.peak && l.peak<=l.instances_limit && !l.closed);
    assert(m.external_bytes==current && m.tracked_bytes==m.control_bytes+m.program_bytes+current && !m.closed);
    assert(m.tracked_bytes<=m.tracked_peak && m.tracked_peak<=m.engine_limit);
}
fn void unchanged(ref engine::Engine e,ref live::Observation before,ref memory::Observation prior){
    let live::Observation l=instance(e);let memory::Observation m=retained(e);
    assert(l.instance_limit==before.instance_limit && l.instances_limit==before.instances_limit);
    assert(l.current==before.current && l.peak==before.peak && l.closed==before.closed);
    assert(m.control_bytes==prior.control_bytes && m.program_bytes==prior.program_bytes);
    assert(m.program_peak==prior.program_peak && m.external_bytes==prior.external_bytes);
    assert(m.tracked_bytes==prior.tracked_bytes && m.tracked_peak==prior.tracked_peak);
    assert(m.working_peak==prior.working_peak && m.closed==prior.closed);
}
fn void counts(ref mut engine::Engine e,usize codes,usize owners,usize pins){switch(engine::inspect(e)){
    case .ok(v):{assert(v.programs==codes && v.instances==owners && v.pins==pins && !v.closed);}
    case .err(_):{assert(false);}
};}
fn void release(ref mut engine::Engine e,usize p){assert(id(engine::release_program(e,p))==p);}
fn void destroy(ref mut engine::Engine e,usize i){assert(id(engine::destroy_instance(e,i))==i);}
fn void close(ref mut engine::Engine e){assert(id(engine::destroy(e))==0);}
fn Result<modules::Index,u8> indexed(ref u8[] source){
    var sources::Builder b=switch(sources::builder(4096,4096)){
        case .ok(v):{v}case .err(_):{return .err(3);}
    };
    if(!sources::add(ref mut b,b"app.brc",source).is_ok){return .err(4);}
    let sources::Snapshot s=switch(sources::freeze(ref b)){
        case .ok(v):{v}case .err(_):{return .err(5);}
    };
    return switch(modules::build(s)){case .ok(v):{.ok(v)}case .err(_):{.err(6)}};
}
fn Result<entries::Entry,u8> entry(ref u8[] source){
    let modules::Index index=indexed(source)?;
    return switch(entries::select_i32(index,b"app",b"chosen")){
        case .ok(v):{.ok(v)}case .err(_):{.err(7)}
    };
}
fn Result<usize,u8> compiled(ref mut engine::Engine e,u32 mode,ref u8[] source){
    if(mode==1 || mode==3){
        let modules::Index index=indexed(source)?;
        let input_entries::InputEntry selected=switch(input_entries::select_i32_input(index,b"app",b"chosen")){
            case .ok(v):{v}case .err(_):{return .err(8);}
        };
        return .ok(if(mode==1){id(engine::compile_input(e,selected,65536))}
            else{id(engine::compile_input_output(e,selected,65536))});
    }
    let entries::Entry selected=entry(source)?;
    return .ok(if(mode==0){id(engine::compile(e,selected,65536))}
        else{id(engine::compile_output(e,selected,65536))});
}
fn ref u8[] input_source(){
    // Input windows, payload arena, list scratch and compound-place storage all
    // belong to the saved VM, even though none of these opcodes has run yet.
    return b"module app;pub fn i32 chosen(ref u8[] data){var a=[1,2];a[1]+=1;output::emit(ref data);return a[1];}";
}
fn Result<inputs::Snapshot,u8> captured(){
    var usize fuel=0;
    return switch(inputs::snapshot(b"!\x00\xFFinput",inputs::hard_limit(),0,ref mut fuel)){
        case .ok(v):{.ok(v)}case .err(_):{.err(9)}
    };
}
fn Result<usize,u8> bound(ref mut engine::Engine e,usize p,usize output_limit){
    let inputs::Snapshot input=captured()?;
    return .ok(id(engine::create_input_output_instance(e,p,input,16000000,output_limit,true)));
}
fn usize requirement(ref engine::Engine e,usize p,usize output_limit){
    let Heap before=heap();let usize attempts=unsafe{probe_attempts()};
    let usize epoch=unsafe{bc_runtime_engine_test_compile_epoch(e as ptr void)};
    let usize next=unsafe{bc_runtime_engine_test_compile_next(e as ptr void)};
    let live::Observation l=instance(e);let memory::Observation m=retained(e);
    let usize size=id(engine::required_pending_bytes(e,p,output_limit));
    assert(size>0 && unsafe{probe_attempts()}==attempts);same_heap(ref before);unchanged(e,ref l,ref m);
    assert(unsafe{bc_runtime_engine_test_compile_epoch(e as ptr void)}==epoch);
    assert(unsafe{bc_runtime_engine_test_compile_next(e as ptr void)}==next);return size;
}
fn engine::Event prepare(ref mut engine::Engine e,usize i,usize required){
    let Heap before=heap();let usize current=instance(e).current;
    let engine::Event pending=event(engine::prepare_instance(e,i));
    assert(pending.kind==4 && pending.value==0 && pending.fuel_known);
    assert(pending.remaining>0 && pending.remaining<16000000);
    assert(pending.diagnostic.code.kind==0 && pending.diagnostic.code.offset==0);
    assert(unsafe{probe_live()}>before.blocks && unsafe{probe_live_bytes()}==before.bytes+required);
    ledger(e,current+required);same_event(pending,event(engine::observe(e,i)));return pending;
}
fn void no_replay(ref mut engine::Engine e,usize i,engine::Event pending){
    let Heap before=heap();let usize attempts=unsafe{probe_attempts()};
    let live::Observation l=instance(e);let memory::Observation m=retained(e);
    rejected(engine::prepare_instance(e,i),3);same_event(pending,event(engine::observe(e,i)));
    rejected(engine::execute_once(e,i),3);same_event(pending,event(engine::observe(e,i)));
    switch(engine::take_output(e,i)){case .ok(_):{assert(false);}case .err(e):{assert(e.status==11);}};
    assert(unsafe{probe_attempts()}==attempts);same_heap(ref before);unchanged(e,ref l,ref m);
}

// Group 1: pre-entry Fuel matches the saved-VM carrier with setup still pending.
// The first guest statements would emit and trap; preparation must do neither.
pub fn Result<usize,u8> pending_without_dispatch_and_replay(){
    let ref u8[] source=b"module app;pub fn i32 chosen(){output::emit(ref b\"prefix\");return 42/0;}";
    let programs::Program reference=switch(programs::compile(entry(source)?,65536)){
        case .ok(v):{v}case .err(_):{return .err(10);}
    };
    var usize empty_fuel=0;
    let inputs::Snapshot empty=switch(inputs::snapshot(b"",inputs::hard_limit(),0,ref mut empty_fuel)){
        case .ok(v):{v}case .err(_):{return .err(11);}
    };
    let machine::Machine oracle=switch(engine::prepare_pending_output(ref reference,ref empty,16000000,64,true)){
        case .ok(v):{v}case .err(_):{return .err(12);}
    };
    let machine::Meta expected=machine::observe(ref oracle);
    assert(expected.phase==1 && expected.cursor.active && expected.stats.dispatched==0);
    assert(expected.stats.calls==0 && expected.stats.yields==0);
    var engine::Engine e=generous()?;let usize p=compiled(ref mut e,2,source)?;
    let usize required=requirement(ref e,p,64);
    let usize i=id(engine::create_output_instance(ref mut e,p,16000000,64,true));
    let Heap ready_heap=heap();let engine::Event pending=prepare(ref mut e,i,required);
    assert(pending.remaining==expected.remaining);no_replay(ref mut e,i,pending);
    let engine::Event cancelled=event(engine::cancel_ready(ref mut e,i));
    assert(cancelled.kind==3 && cancelled.value==0 && cancelled.fuel_known);
    assert(cancelled.remaining==pending.remaining && cancelled.diagnostic.code.kind==0);
    ledger(ref e,0);same_heap(ref ready_heap);
    let usize attempts=unsafe{probe_attempts()};
    same_event(cancelled,event(engine::cancel_ready(ref mut e,i)));
    same_event(cancelled,event(engine::observe(ref mut e,i)));
    assert(unsafe{probe_attempts()}==attempts);same_heap(ref ready_heap);
    destroy(ref mut e,i);release(ref mut e,p);close(ref mut e);
    // Keep the original immutable owners live through every comparison.
    assert(machine::observe(ref oracle).remaining==expected.remaining && inputs::view(ref empty).len==0);
    assert(sources::count(programs::snapshot(ref reference))==1);
    return .ok(0);
}

fn Result<usize,u8> input_remaining(ref inputs::Snapshot input){
    let modules::Index index=indexed(input_source())?;
    let input_entries::InputEntry selected=switch(input_entries::select_i32_input(index,b"app",b"chosen")){
        case .ok(v):{v}case .err(_):{return .err(14);}
    };
    let programs::Program code=switch(programs::compile_input(selected,65536)){
        case .ok(v):{v}case .err(_):{return .err(15);}
    };
    let machine::Machine oracle=switch(engine::prepare_pending_output(ref code,input,16000000,64,true)){
        case .ok(v):{v}case .err(_):{return .err(16);}
    };
    let machine::Meta expected=machine::observe(ref oracle);
    assert(expected.phase==1 && expected.cursor.active && expected.stats.dispatched==0);
    assert(expected.stats.calls==0 && expected.stats.yields==0);return .ok(expected.remaining);
}

// Group 2: released Program pins, bound input and saved machines survive a move.
// Cancel frees only preparation; direct prepared destruction also frees input.
pub fn Result<usize,u8> released_pins_move_cancel_and_direct_destroy(){
    let inputs::Snapshot original=captured()?;let usize input=inputs::capacity(ref original);
    let usize remaining=input_remaining(ref original)?;
    var engine::Engine e=generous()?;let usize p=compiled(ref mut e,3,input_source())?;
    let usize required=requirement(ref e,p,64);
    let usize a=bound(ref mut e,p,64)?;let usize b=bound(ref mut e,p,64)?;
    let Heap ready_heap=heap();let usize code_bytes=retained(ref e).program_bytes;
    release(ref mut e,p);counts(ref mut e,1,2,2);
    let engine::Event first=prepare(ref mut e,a,required);
    let engine::Event second=prepare(ref mut e,b,required);
    assert(first.remaining==remaining && second.remaining==remaining);
    let Heap saved_heap=heap();var engine::Engine moved=e;same_heap(ref saved_heap);
    ledger(ref moved,2*(input+required));counts(ref mut moved,1,2,2);
    no_replay(ref mut moved,b,second);
    let engine::Event stopped=event(engine::cancel_ready(ref mut moved,a));
    assert(stopped.kind==3 && stopped.remaining==first.remaining && stopped.fuel_known);
    ledger(ref moved,2*input+required);
    assert(unsafe{probe_live_bytes()}==ready_heap.bytes+required);
    let Heap cancelled_heap=heap();let usize attempts=unsafe{probe_attempts()};
    same_event(stopped,event(engine::cancel_ready(ref mut moved,a)));
    assert(unsafe{probe_attempts()}==attempts);same_heap(ref cancelled_heap);
    destroy(ref mut moved,a);ledger(ref moved,input+required);counts(ref mut moved,1,1,1);
    assert(unsafe{probe_live_bytes()}+input==ready_heap.bytes+required);
    assert(retained(ref moved).program_bytes==code_bytes);
    same_event(second,event(engine::observe(ref mut moved,b)));
    // The final pin is still prepared when it reclaims the released Program.
    destroy(ref mut moved,b);ledger(ref moved,0);counts(ref mut moved,0,0,0);
    assert(retained(ref moved).program_bytes==0);close(ref mut moved);
    assert(bytes::equal(inputs::view(ref original),b"!\x00\xFFinput"));return .ok(0);
}

fn Result<Plan,u8> measured(usize output_limit){
    let inputs::Snapshot original=captured()?;let usize input=inputs::capacity(ref original);
    var engine::Engine e=generous()?;let usize p=compiled(ref mut e,3,input_source())?;
    let usize a=bound(ref mut e,p,output_limit)?;let usize b=bound(ref mut e,p,output_limit)?;
    let usize required=requirement(ref e,p,output_limit);ledger(ref e,2*input);
    let memory::Observation m=retained(ref e);
    assert(m.control_bytes==id(engine::required_control_bytes(limits())));
    let usize combined=m.control_bytes+m.program_bytes+2*(input+required);
    if(output_limit==1048576){assert(combined<=67108864);}
    destroy(ref mut e,a);destroy(ref mut e,b);release(ref mut e,p);close(ref mut e);
    assert(bytes::equal(inputs::view(ref original),b"!\x00\xFFinput"));
    return .ok(Plan{.pending=required,.input=input,.combined=combined});
}
fn void quota_rejection(ref mut engine::Engine e,usize i){
    let engine::Event ready=event(engine::observe(e,i));assert(ready.kind==0 && ready.remaining==16000000);
    let Heap before=heap();let usize attempts=unsafe{probe_attempts()};
    let live::Observation l=instance(e);let memory::Observation m=retained(e);
    rejected(engine::prepare_instance(e,i),8);
    assert(unsafe{probe_attempts()}==attempts);same_heap(ref before);unchanged(e,ref l,ref m);
    same_event(ready,event(engine::observe(e,i)));
}
// Keep the combined runtime boundary above the compilation high-water mark.
// These are actual separately pinned owners, never a seeded ledger or reset peak.
fn Result<Plan,u8> measured_many(ref mut usize owners){
    let inputs::Snapshot original=captured()?;let usize input=inputs::capacity(ref original);
    var engine::Engine e=generous()?;let usize p=compiled(ref mut e,3,input_source())?;
    let usize required=requirement(ref e,p,1048576);let memory::Observation m=retained(ref e);
    var usize count=2;var usize combined=m.control_bytes+m.program_bytes+count*(input+required);
    while(combined<=m.tracked_peak){count+=1;assert(count<=64);combined=m.control_bytes+m.program_bytes+count*(input+required);}
    assert(combined<=268435456);*owners=count;release(ref mut e,p);close(ref mut e);
    return .ok(Plan{.pending=required,.input=input,.combined=combined});
}
fn Result<usize,u8> combined_many(bool short){
    var usize owners=0;let Plan plan=measured_many(ref mut owners)?;
    let usize cap=plan.combined-if(short){1}else{0};
    let usize per=if(cap>67108864){67108864}else{cap};
    var engine::Engine e=created(268435456,536870912,memory::Limits{.engine=cap,.program=per,.programs=cap})?;
    let inputs::Snapshot original=captured()?;let usize p=compiled(ref mut e,3,input_source())?;
    var usize[64] ids=[0;64];var usize n=0;
    while(n<owners){ids[n]=bound(ref mut e,p,1048576)?;n+=1;}
    n=0;while(n+1<owners){assert(prepare(ref mut e,ids[n],plan.pending).kind==4);n+=1;}
    let usize last=ids[owners-1];
    if(short){quota_rejection(ref mut e,last);counts(ref mut e,1,owners,owners);
        assert(event(engine::cancel_ready(ref mut e,ids[0])).kind==3);
        assert(prepare(ref mut e,last,plan.pending).kind==4);
    }else{assert(prepare(ref mut e,last,plan.pending).kind==4);
        assert(instance(ref e).current==owners*(plan.input+plan.pending));
        assert(retained(ref e).tracked_bytes==plan.combined);}
    n=0;while(n<owners){destroy(ref mut e,ids[n]);n+=1;}ledger(ref e,0);release(ref mut e,p);close(ref mut e);
    assert(bytes::equal(inputs::view(ref original),b"!\x00\xFFinput"));return .ok(0);
}
fn Result<usize,u8> quota_boundary(u32 kind,bool short){
    if(kind==2){return combined_many(short);}
    let usize output_limit=if(kind==2){1048576}else{64};let Plan plan=measured(output_limit)?;
    let usize exact=plan.input+plan.pending;let usize aggregate=2*exact;
    let usize single=if(kind==0 && short){exact-1}else{if(kind<2){exact}else{268435456}};
    let usize all=if(kind==1){if(short){aggregate-1}else{aggregate}}else{536870912};
    let usize combined=if(short){plan.combined-1}else{plan.combined};
    let memory::Limits budget=if(kind==2){memory::Limits{.engine=combined,.program=combined,.programs=combined}}
        else{memory::defaults()};
    // This Snapshot remains live across every probe, including the rejected call.
    let inputs::Snapshot original=captured()?;assert(inputs::capacity(ref original)==plan.input);
    var engine::Engine e=created(single,all,budget)?;
    let usize p=compiled(ref mut e,3,input_source())?;assert(requirement(ref e,p,output_limit)==plan.pending);
    let usize a=bound(ref mut e,p,output_limit)?;let usize b=bound(ref mut e,p,output_limit)?;
    if(kind!=0){let engine::Event peer=prepare(ref mut e,a,plan.pending);assert(peer.kind==4);}
    if(short){
        quota_rejection(ref mut e,b);counts(ref mut e,1,2,2);
        if(kind!=0){
            // Refund only the peer's saved state; both original inputs stay bound.
            assert(event(engine::cancel_ready(ref mut e,a)).kind==3);
            let engine::Event retry=prepare(ref mut e,b,plan.pending);assert(retry.kind==4);
        }
    }else{
        let engine::Event pending=prepare(ref mut e,b,plan.pending);assert(pending.kind==4);
        if(kind!=0){assert(instance(ref e).current==aggregate);}
        if(kind==2){assert(retained(ref e).tracked_bytes==combined);}
    }
    destroy(ref mut e,a);destroy(ref mut e,b);ledger(ref e,0);release(ref mut e,p);close(ref mut e);
    assert(bytes::equal(inputs::view(ref original),b"!\x00\xFFinput"));return .ok(0);
}
// Group 3: one representative input/output layout, three independent ceilings.
pub fn Result<usize,u8> exact_and_one_less_instance_aggregate_and_combined(){
    var u32 kind=0;while(kind<3){
        let usize exact=quota_boundary(kind,false)?;let usize short=quota_boundary(kind,true)?;kind+=1;
    }
    return .ok(0);
}

// Group 4: discover this recipe's allocation count instead of pinning ordinals.
// Every failed allocation must map NativeOOM, drop partial state and allow retry.
pub fn Result<usize,u8> native_oom_rolls_back_every_preparation_allocation(){
    let inputs::Snapshot original=captured()?;let usize input=inputs::capacity(ref original);
    var engine::Engine e=generous()?;let usize p=compiled(ref mut e,3,input_source())?;
    let usize required=requirement(ref e,p,64);let usize sample=bound(ref mut e,p,64)?;
    let usize before=unsafe{probe_attempts()};let engine::Event measured=prepare(ref mut e,sample,required);
    let usize attempts=unsafe{probe_attempts()}-before;assert(attempts>3);destroy(ref mut e,sample);
    var usize ordinal=0;while(ordinal<attempts){
        let usize i=bound(ref mut e,p,64)?;let engine::Event ready=event(engine::observe(ref mut e,i));
        let Heap stored=heap();let memory::Observation prior=retained(ref e);
        let i64 position=switch(num::i64_from_usize(ordinal)){
            case .ok(v):{v}case .err(_):{return .err(13);}
        };
        unsafe{bc_runtime_engine_test_fail(position)};
        let Result<engine::Event,engine::Error> failed=engine::prepare_instance(ref mut e,i);
        unsafe{bc_runtime_engine_test_fail(-1)};
        switch(failed){case .ok(_):{assert(false);}case .err(e):{assert(e.status==6);}};
        same_heap(ref stored);ledger(ref e,input);
        let memory::Observation after=retained(ref e);
        assert(after.program_bytes==prior.program_bytes && after.control_bytes==prior.control_bytes);
        assert(after.tracked_bytes==prior.tracked_bytes);same_event(ready,event(engine::observe(ref mut e,i)));
        counts(ref mut e,1,1,1);
        let engine::Event retry=prepare(ref mut e,i,required);assert(retry.remaining==measured.remaining);
        destroy(ref mut e,i);ledger(ref e,0);ordinal+=1;
    }
    release(ref mut e,p);close(ref mut e);
    assert(bytes::equal(inputs::view(ref original),b"!\x00\xFFinput"));return .ok(attempts);
}

// Group 5: wrong Program mode and exhausted admission cannot prepare; maintenance
// still cancels/destroys an already prepared owner after the final epoch.
pub fn Result<usize,u8> wrong_mode_and_exhausted_epoch_preserve_owners(){
    var engine::Engine e=generous()?;
    let usize plain=compiled(ref mut e,0,b"module app;pub fn i32 chosen(){return 42;}")?;
    let usize ordinary=id(engine::create_instance(ref mut e,plain,16000000));
    let engine::Event ready=event(engine::observe(ref mut e,ordinary));
    let Heap stored=heap();let usize attempts=unsafe{probe_attempts()};
    rejected(engine::prepare_instance(ref mut e,ordinary),1);
    same_event(ready,event(engine::observe(ref mut e,ordinary)));
    assert(unsafe{probe_attempts()}==attempts);same_heap(ref stored);
    destroy(ref mut e,ordinary);release(ref mut e,plain);
    let usize p=compiled(ref mut e,3,input_source())?;let usize required=requirement(ref e,p,64);
    let usize a=bound(ref mut e,p,64)?;let usize b=bound(ref mut e,p,64)?;
    let engine::Event pending=prepare(ref mut e,a,required);
    unsafe{bc_runtime_engine_test_seed(ref mut e as ptr mut void,2)};
    counts(ref mut e,1,2,2);quota_rejection(ref mut e,b);
    same_event(pending,event(engine::observe(ref mut e,a)));
    let engine::Event stopped=event(engine::cancel_ready(ref mut e,a));
    assert(stopped.kind==3 && stopped.remaining==pending.remaining && stopped.fuel_known);
    same_event(stopped,event(engine::cancel_ready(ref mut e,a)));
    release(ref mut e,p);destroy(ref mut e,a);destroy(ref mut e,b);
    ledger(ref e,0);assert(retained(ref e).program_bytes==0);close(ref mut e);return .ok(0);
}

// Group 6: ordinary resource destruction owns the same complete cleanup as
// explicit Instance destruction, even with two pending owners and a released pin.
pub fn Result<usize,u8> engine_drop_reclaims_prepared_owners(){
    let inputs::Snapshot original=captured()?;let Heap before=heap();
    {
        var engine::Engine e=generous()?;let usize p=compiled(ref mut e,3,input_source())?;
        let usize required=requirement(ref e,p,64);
        let usize a=bound(ref mut e,p,64)?;let usize b=bound(ref mut e,p,64)?;
        release(ref mut e,p);let engine::Event first=prepare(ref mut e,a,required);
        let engine::Event second=prepare(ref mut e,b,required);
        assert(first.kind==4 && second.kind==4);counts(ref mut e,1,2,2);
    }
    same_heap(ref before);assert(bytes::equal(inputs::view(ref original),b"!\x00\xFFinput"));return .ok(0);
}
fn Result<usize,u8> preparation_invariant_quarantines_engine(bool during_open){
    var engine::Engine e=generous()?;let usize p=compiled(ref mut e,3,input_source())?;
    let usize prior=bound(ref mut e,p,64)?;let usize peer=bound(ref mut e,p,64)?;let usize target=bound(ref mut e,p,64)?;
    let engine::Event cancelled=event(engine::cancel_ready(ref mut e,prior));
    assert(cancelled.kind==3);
    let usize charged=instance(ref e).current;
    let usize next=unsafe{bc_runtime_engine_test_compile_next(ref e as ptr void)};
    let usize attempts=unsafe{probe_attempts()};let Heap before=heap();
    unsafe{bc_runtime_engine_test_inject_output_fault(if(during_open){4}else{3})};
    rejected(engine::prepare_instance(ref mut e,target),14);
    assert(unsafe{probe_attempts()}==attempts+if(during_open){2}else{0});
    same_heap(ref before);ledger(ref e,charged);counts(ref mut e,1,3,3);
    assert(unsafe{bc_runtime_engine_test_compile_next(ref e as ptr void)}==next);
    same_event(cancelled,event(engine::observe(ref mut e,prior)));
    let engine::Event quarantined=event(engine::observe(ref mut e,target));
    assert(quarantined.kind==2 && quarantined.diagnostic.code.kind==errors::engine_poisoned_kind() &&
        quarantined.remaining==16000000 && quarantined.fuel_known);
    same_event(quarantined,event(engine::observe(ref mut e,peer)));
    rejected(engine::prepare_instance(ref mut e,peer),14);
    release(ref mut e,p);
    destroy(ref mut e,prior);destroy(ref mut e,peer);destroy(ref mut e,target);
    counts(ref mut e,0,0,0);ledger(ref e,0);close(ref mut e);return .ok(0);
}
pub fn void run(){
    let Heap before=heap();
    assert(pending_without_dispatch_and_replay().is_ok);same_heap(ref before);
    assert(released_pins_move_cancel_and_direct_destroy().is_ok);same_heap(ref before);
    assert(exact_and_one_less_instance_aggregate_and_combined().is_ok);same_heap(ref before);
    assert(native_oom_rolls_back_every_preparation_allocation().is_ok);same_heap(ref before);
    assert(wrong_mode_and_exhausted_epoch_preserve_owners().is_ok);same_heap(ref before);
    assert(engine_drop_reclaims_prepared_owners().is_ok);same_heap(ref before);
    assert(preparation_fuel_failure_preserves_diagnostic_and_ready_state().is_ok);same_heap(ref before);
    assert(preparation_invariant_quarantines_engine(false).is_ok);same_heap(ref before);
    assert(preparation_invariant_quarantines_engine(true).is_ok);same_heap(ref before);
}
// Group 7: failed preparation returns its original diagnostic while preserving
// the Ready Instance, Fuel, pins and current balance after partial allocation.
pub fn Result<usize,u8> preparation_fuel_failure_preserves_diagnostic_and_ready_state(){
    var engine::Engine e=generous()?;
    let usize p=compiled(ref mut e,2,b"module app;pub fn i32 chosen(){return 42;}")?;
    let usize i=id(engine::create_output_instance(ref mut e,p,0,64,true));
    let engine::Event ready=event(engine::observe(ref mut e,i));let Heap before=heap();
    switch(engine::prepare_instance(ref mut e,i)){
        case .ok(_):{assert(false);}
        case .err(e):{assert(e.status==4 && e.diagnostic.code.kind==8 && e.diagnostic.code.offset==0);}
    };
    same_heap(ref before);ledger(ref e,0);same_event(ready,event(engine::observe(ref mut e,i)));
    counts(ref mut e,1,1,1);destroy(ref mut e,i);release(ref mut e,p);close(ref mut e);return .ok(0);
}
