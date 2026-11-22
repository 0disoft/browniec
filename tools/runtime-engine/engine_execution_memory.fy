module engine_execution_memory;
import runtime_engine as engine;
import runtime_live_memory as live;
import runtime_program_memory as memory;
import runtime_input as inputs;
import module_entry as entries;
import module_input_entry as input_entries;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import std::bytes as bytes;

// Native fixture only. Link heap-observer.c and compile-test-host.inc.
// Requirements include scratch and output preparation, excluding bound input.
// No private resource fields, synthetic Snapshot owners or native stack claims.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_peak_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void probe_rebase();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
unsafe extern C fn usize bc_runtime_engine_test_compile_next(ptr void owner);

struct Heap { usize blocks; usize bytes; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void physical(ref Heap expected){
    assert(unsafe{probe_live()}==expected.blocks && unsafe{probe_live_bytes()}==expected.bytes);
}
fn void clean(){assert(unsafe{probe_live()}==0 && unsafe{probe_live_bytes()}==0);}
fn usize maximum(usize a,usize b){return if(a>b){a}else{b};}
fn usize id(Result<usize,engine::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn engine::Event event(Result<engine::Event,engine::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,
        .diagnostic=diagnostics::absent(errors::make(0,0)),.remaining=0,.fuel_known=false}}
};}
fn void rejected_event(Result<engine::Event,engine::Error> result,u32 status){switch(result){
    case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}
};}
fn void rejected_take(Result<engine::Output,engine::Error> result,u32 status){switch(result){
    case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}
};}
fn void same_event(engine::Event a,engine::Event b){
    assert(a.kind==b.kind && a.value==b.value && a.remaining==b.remaining && a.fuel_known==b.fuel_known);
    assert(a.diagnostic.code.kind==b.diagnostic.code.kind && a.diagnostic.code.offset==b.diagnostic.code.offset);
    assert(a.diagnostic.at.source==b.diagnostic.at.source && a.diagnostic.at.start==b.diagnostic.at.start);
    assert(a.diagnostic.at.end==b.diagnostic.at.end);
}
fn live::Observation instance(ref engine::Engine e){return switch(engine::instance_memory(e)){
    case .ok(v):{v}case .err(_):{assert(false);instance(e)}
};}
fn memory::Observation programs(ref engine::Engine e){return switch(engine::program_memory(e)){
    case .ok(v):{v}case .err(_):{assert(false);programs(e)}
};}
fn void ledger(ref engine::Engine e,usize current,usize peak){
    let live::Observation l=instance(e);let memory::Observation p=programs(e);
    assert(l.current==current && l.peak==peak && !l.closed);
    assert(l.current<=l.peak && l.peak<=l.instances_limit);
    assert(p.external_bytes==current && !p.closed);
    assert(p.tracked_bytes==p.control_bytes+p.program_bytes+current);
    assert(p.tracked_peak>=p.tracked_bytes && p.tracked_peak<=p.engine_limit);
}
fn void unchanged(ref engine::Engine e,ref live::Observation before,ref memory::Observation prior){
    ledger(e,before.current,before.peak);let memory::Observation p=programs(e);
    assert(p.control_bytes==prior.control_bytes && p.program_bytes==prior.program_bytes);
    assert(p.program_peak==prior.program_peak && p.tracked_bytes==prior.tracked_bytes);
    assert(p.tracked_peak==prior.tracked_peak && p.working_peak==prior.working_peak);
}
fn void counts(ref mut engine::Engine e,usize code,usize owners,usize pins){switch(engine::inspect(e)){
    case .ok(v):{assert(v.programs==code && v.instances==owners && v.pins==pins && !v.closed);}
    case .err(_):{assert(false);}
};}
fn usize next(ref engine::Engine e){return unsafe{bc_runtime_engine_test_compile_next(e as ptr void)};}
fn Result<engine::Engine,engine::Error> created(usize single,usize aggregate,memory::Limits limits){
    return engine::create_with_instance_memory(
        engine::Limits{.programs=4,.instances=64,.fuel=16000000},4194304,limits,
        268435456,live::Limits{.instance=single,.instances=aggregate});
}
fn Result<modules::Index,u8> indexed(ref u8[] source){
    var sources::Builder b=switch(sources::builder(4096,4096)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    if(!sources::add(ref mut b,b"app.brc",source).is_ok){return .err(2);}
    let sources::Snapshot s=switch(sources::freeze(ref b)){
        case .ok(v):{v}case .err(_):{return .err(3);}
    };
    return switch(modules::build(s)){case .ok(v):{.ok(v)}case .err(_):{.err(4)}};
}
fn usize compiled(ref mut engine::Engine e,u32 mode,ref u8[] source){
    let modules::Index index=switch(indexed(source)){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}
    };
    if(mode==1 || mode==3){
        let input_entries::InputEntry entry=switch(input_entries::select_i32_input(index,b"app",b"chosen")){
            case .ok(v):{v}case .err(_):{assert(false);return 0;}
        };
        return if(mode==1){id(engine::compile_input(e,entry,65536))}
            else{id(engine::compile_input_output(e,entry,65536))};
    }
    let entries::Entry entry=switch(entries::select_i32(index,b"app",b"chosen")){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}
    };
    return if(mode==0){id(engine::compile(e,entry,65536))}
        else{id(engine::compile_output(e,entry,65536))};
}
// Scalar, explicit array list, and indexed compound-place lowering.
fn ref u8[] source(u32 mode,u32 shape){
    if(shape==1){
        if(mode==1 || mode==3){return b"module app;pub fn i32 chosen(ref u8[] data){let i32 x=21;let a=[x,x,x,x,x,x,x,x,x];return a[0]+a[8];}";}
        return b"module app;pub fn i32 chosen(){let i32 x=21;let a=[x,x,x,x,x,x,x,x,x];return a[0]+a[8];}";
    }
    if(shape==2){
        if(mode==1 || mode==3){return b"module app;pub fn i32 chosen(ref u8[] data){var i32[1] a=[41];a[0]+=1;return a[0];}";}
        return b"module app;pub fn i32 chosen(){var i32[1] a=[41];a[0]+=1;return a[0];}";
    }
    if(mode==3){return b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}";}
    if(mode==1){return b"module app;pub fn i32 chosen(ref u8[] data){return 42;}";}
    if(mode==2){return b"module app;pub fn i32 chosen(){output::emit(ref b\"*\");return 42;}";}
    return b"module app;pub fn i32 chosen(){return 42;}";
}
fn Result<inputs::Snapshot,u8> payload(usize length){
    var bytes::Buffer data=switch(bytes::with_capacity(length)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    if(!bytes::resize_zeroed(ref mut data,length).is_ok){return .err(2);}
    if(length>0){bytes::view_mut(ref mut data)[0]=42;}
    var usize budget=0;
    return switch(inputs::snapshot(bytes::view(ref data),inputs::hard_limit(),0,ref mut budget)){
        case .ok(v):{.ok(v)}case .err(_):{.err(3)}
    };
}
fn usize capacity(usize length){
    let inputs::Snapshot p=switch(payload(length)){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}
    };
    let usize size=inputs::capacity(ref p);assert(size>=length);return size;
}
fn usize bound(ref mut engine::Engine e,usize code,u32 mode,usize length,usize budget,usize limit){
    if(mode==1 || mode==3){
        let inputs::Snapshot p=switch(payload(length)){
            case .ok(v):{v}case .err(_):{assert(false);return 0;}
        };
        return if(mode==1){id(engine::create_input_instance(e,code,p,budget))}
            else{id(engine::create_input_output_instance(e,code,p,budget,limit,true))};
    }
    return if(mode==0){id(engine::create_instance(e,code,budget))}
        else{id(engine::create_output_instance(e,code,budget,limit,true))};
}
fn usize requirement(ref engine::Engine e,usize p,usize limit){return id(engine::required_execution_bytes(e,p,limit));}
fn usize retained(u32 mode,usize limit){return if(mode>=2){576+limit}else{0};}
fn usize input_size(u32 mode){return if(mode==1 || mode==3){capacity(64)}else{0};}
fn void release(ref mut engine::Engine e,usize p){assert(id(engine::release_program(e,p))==p);}
fn void destroy(ref mut engine::Engine e,usize i){assert(id(engine::destroy_instance(e,i))==i);}
fn void close(ref mut engine::Engine e){assert(id(engine::destroy(e))==0);}
fn void published(ref engine::Output output,usize length){
    assert(engine::output_available(output));assert(engine::output_completion(output).success);
    assert(engine::output_completion(output).value==42 && engine::output_view(output).len==length);
    if(length>0){assert(engine::output_view(output)[0]==42);}
}
fn usize measured(u32 mode,u32 shape,usize limit){
    var engine::Engine e=switch(created(268435456,536870912,memory::defaults())){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}
    };
    let usize p=compiled(ref mut e,mode,source(mode,shape));let Heap before=heap();
    let live::Observation l=instance(ref e);let memory::Observation m=programs(ref e);
    let usize object=next(ref e);unsafe{probe_rebase()};
    let usize result=requirement(ref e,p,if(mode>=2){limit}else{0});
    assert(unsafe{probe_attempts()}==0 && next(ref e)==object);
    unchanged(ref e,ref l,ref m);physical(ref before);release(ref mut e,p);close(ref mut e);return result;
}

fn void instance_boundary(u32 mode,u32 shape,bool short){
    let Heap baseline=heap();let usize limit=64;let usize input=input_size(mode);
    let usize required=measured(mode,shape,limit);let usize exact=input+required;
    assert(required>320 && required>retained(mode,limit));
    {
        var engine::Engine e=switch(created(if(short){exact-1}else{exact},2*exact,memory::defaults())){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut e,mode,source(mode,shape));
        let usize i=bound(ref mut e,p,mode,64,16000000,limit);
        let engine::Event ready=event(engine::observe(ref mut e,i));let Heap before=heap();
        let live::Observation l=instance(ref e);let memory::Observation m=programs(ref e);
        let usize object=next(ref e);unsafe{probe_rebase()};
        if(short){
            rejected_event(engine::execute_once(ref mut e,i),8);
            assert(unsafe{probe_attempts()}==0 && next(ref e)==object);physical(ref before);
            unchanged(ref e,ref l,ref m);same_event(ready,event(engine::observe(ref mut e,i)));
            counts(ref mut e,1,1,1);
            let engine::Event cancelled=event(engine::cancel_ready(ref mut e,i));
            assert(cancelled.kind==3 && cancelled.remaining==ready.remaining && cancelled.fuel_known);
            ledger(ref e,input,l.peak);
        }else{
            let engine::Event done=event(engine::execute_once(ref mut e,i));assert(done.kind==1 && done.value==42);
            assert(unsafe{probe_attempts()}>0 && unsafe{probe_peak_bytes()}==before.bytes+required);
            assert(unsafe{probe_live_bytes()}==before.bytes+retained(mode,limit));
            ledger(ref e,input+retained(mode,limit),exact);
            assert(programs(ref e).tracked_peak==maximum(m.tracked_peak,m.control_bytes+m.program_bytes+exact));
            same_event(done,event(engine::observe(ref mut e,i)));counts(ref mut e,1,1,1);
        }
        let usize peak=instance(ref e).peak;destroy(ref mut e,i);ledger(ref e,0,peak);
        release(ref mut e,p);close(ref mut e);
    }
    physical(ref baseline);
}
// Group 1: four compile/execution modes, array-list and place scratch. Querying
// the planner is allocation-free; exact admission and one-less Ready rollback.
// Ordinary scalar execution has no heap and therefore no one-less boundary.
fn void zero_heap_scalar(){
    var engine::Engine e=switch(created(1,1,memory::defaults())){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let usize p=compiled(ref mut e,0,source(0,0));let usize i=bound(ref mut e,p,0,0,16000000,0);
    let Heap before=heap();unsafe{probe_rebase()};assert(requirement(ref e,p,0)==0);
    let engine::Event done=event(engine::execute_once(ref mut e,i));assert(done.kind==1 && done.value==42);
    assert(unsafe{probe_attempts()}==0);physical(ref before);ledger(ref e,0,0);
    destroy(ref mut e,i);release(ref mut e,p);close(ref mut e);
}
pub fn void four_modes_and_layouts_exact_and_one_less(){
    clean();zero_heap_scalar();clean();
    assert(measured(0,0,0)==0);assert(measured(1,0,0)==18432);
    assert(measured(2,0,64)==616+64);assert(measured(3,0,64)==18432+616+64);
    // Nine i32 operands: 65536-byte arena, Vec16<i64>, 36 encoded bytes.
    let usize array_bytes=65536+128+36;
    assert(measured(0,1,0)==array_bytes);assert(measured(1,1,0)==array_bytes+18432);
    assert(measured(2,1,64)==array_bytes+616+64);
    assert(measured(3,1,64)==array_bytes+18432+616+64);
    var u32 mode=0;while(mode<4){var u32 shape=if(mode==0){1}else{0};while(shape<3){
        instance_boundary(mode,shape,true);clean();instance_boundary(mode,shape,false);clean();shape+=1;
    }mode+=1;}
}

fn void aggregate_boundary(bool short){
    let Heap baseline=heap();let usize input=capacity(64);let usize limit=64;
    let usize required=measured(3,0,limit);let usize keep=retained(3,limit);
    let usize exact=2*input+keep+required;
    {
        var engine::Engine e=switch(created(input+required,if(short){exact-1}else{exact},memory::defaults())){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut e,3,source(3,0));
        let usize a=bound(ref mut e,p,3,64,16000000,limit);
        let usize b=bound(ref mut e,p,3,64,16000000,limit);
        assert(event(engine::execute_once(ref mut e,a)).kind==1);
        let live::Observation l=instance(ref e);let memory::Observation m=programs(ref e);
        ledger(ref e,2*input+keep,2*input+required);
        let engine::Event ready=event(engine::observe(ref mut e,b));let Heap before=heap();unsafe{probe_rebase()};
        if(short){
            rejected_event(engine::execute_once(ref mut e,b),8);assert(unsafe{probe_attempts()}==0);
            physical(ref before);unchanged(ref e,ref l,ref m);
            same_event(ready,event(engine::observe(ref mut e,b)));counts(ref mut e,1,2,2);
            // Removing only the peer output/input frees enough to retry the
            // original Ready instance with its unchanged Fuel and Program pin.
            destroy(ref mut e,a);assert(event(engine::execute_once(ref mut e,b)).kind==1);
            ledger(ref e,input+keep,l.peak);
        }else{
            assert(event(engine::execute_once(ref mut e,b)).kind==1);
            assert(unsafe{probe_peak_bytes()}<=before.bytes+required);
            ledger(ref e,2*(input+keep),exact);destroy(ref mut e,a);
            ledger(ref e,input+keep,exact);
        }
        destroy(ref mut e,b);release(ref mut e,p);close(ref mut e);
    }
    physical(ref baseline);
}
// Group 2: retained peer output and both actual input capacities stay in the
// aggregate baseline. Quota failure does not steal the pending owner's pin.
pub fn void simultaneous_input_and_peer_output_exact_and_one_less(){aggregate_boundary(true);aggregate_boundary(false);}

fn usize combined_ceiling(ref mut usize peers){
    var engine::Engine sample=switch(created(268435456,536870912,memory::defaults())){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}};
    let usize peer=compiled(ref mut sample,0,source(0,0));let usize p=compiled(ref mut sample,3,source(3,0));
    let memory::Observation m=programs(ref sample);
    let usize unit=capacity(1048576)+576+1048576;
    var usize count=0;var usize total=m.control_bytes+m.program_bytes+capacity(64)+requirement(ref sample,p,1048576);
    while(total<=m.tracked_peak){count+=1;assert(count<63);total+=unit;}
    *peers=count;release(ref mut sample,peer);release(ref mut sample,p);close(ref mut sample);return total;
}
fn void combined_boundary(bool short){
    let Heap baseline=heap();var usize peers=0;let usize exact=combined_ceiling(ref mut peers);
    let usize peer_kept=capacity(1048576)+576+1048576;
    {
        let usize ceiling=exact-if(short){1}else{0};let usize per=if(ceiling>67108864){67108864}else{ceiling};
        var engine::Engine e=switch(created(268435456,536870912,memory::Limits{.engine=ceiling,.program=per,.programs=ceiling})){
            case .ok(v):{v}case .err(_):{assert(false);return;}};
        let usize peer=compiled(ref mut e,0,source(0,0));let usize p=compiled(ref mut e,3,source(3,0));
        let usize pin=bound(ref mut e,peer,0,0,123,0);var usize[64] ids=[0;64];var usize n=0;
        while(n<peers){ids[n]=bound(ref mut e,p,3,1048576,16000000,1048576);assert(event(engine::execute_once(ref mut e,ids[n])).kind==1);n+=1;}
        let usize i=bound(ref mut e,p,3,64,16000000,1048576);
        let engine::Event ready=event(engine::observe(ref mut e,i));let live::Observation l=instance(ref e);let memory::Observation m=programs(ref e);
        let Heap before=heap();let usize object=next(ref e);unsafe{probe_rebase()};
        if(short){rejected_event(engine::execute_once(ref mut e,i),8);assert(unsafe{probe_attempts()}==0);physical(ref before);unchanged(ref e,ref l,ref m);same_event(ready,event(engine::observe(ref mut e,i)));}
        else{let usize required=requirement(ref e,p,1048576);assert(event(engine::execute_once(ref mut e,i)).kind==1);
            assert(unsafe{probe_peak_bytes()}<=before.bytes+required);assert(programs(ref e).tracked_peak==exact);
            ledger(ref e,peers*peer_kept+capacity(64)+576+1048576,peers*peer_kept+capacity(64)+required);}
        assert(next(ref e)==object);counts(ref mut e,2,peers+2,peers+2);
        let engine::Event peer_ready=event(engine::observe(ref mut e,pin));assert(peer_ready.kind==0 && peer_ready.remaining==123 && peer_ready.fuel_known);
        destroy(ref mut e,i);n=0;while(n<peers){destroy(ref mut e,ids[n]);n+=1;}
        destroy(ref mut e,pin);release(ref mut e,p);release(ref mut e,peer);close(ref mut e);
    }physical(ref baseline);
}
// Group 3: combined Engine bytes independently reject execution with generous
// Instance limits. Compilation history and another Program/pin remain intact.
pub fn void combined_engine_exact_and_one_less(){combined_boundary(true);combined_boundary(false);}

fn void failure_case(bool early){
    let Heap baseline=heap();let usize input=capacity(64);let usize limit=64;
    {
        var engine::Engine e=switch(created(268435456,536870912,memory::defaults())){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut e,3,
            b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"prefix\");return 42/((data[1]) as i32);}");
        let usize i=bound(ref mut e,p,3,64,16000000,limit);
        let usize required=requirement(ref e,p,limit);let Heap before=heap();unsafe{probe_rebase()};
        if(early){unsafe{bc_runtime_engine_test_fail(0)};}
        let Result<engine::Event,engine::Error> attempted=engine::execute_once(ref mut e,i);
        unsafe{bc_runtime_engine_test_fail(-1)};let engine::Event failed=event(attempted);
        assert(failed.kind==2 && failed.fuel_known);
        assert(failed.diagnostic.code.kind==if(early){15}else{7});
        let usize keep=if(early){0}else{576};
        ledger(ref e,input+keep,input+required);
        assert(unsafe{probe_live_bytes()}==before.bytes+keep);
        assert(unsafe{probe_peak_bytes()}<=before.bytes+required);
        if(early){assert(unsafe{probe_attempts()}==1 && failed.remaining==16000000);physical(ref before);}
        same_event(failed,event(engine::observe(ref mut e,i)));rejected_event(engine::execute_once(ref mut e,i),11);
        {
            let engine::Output output=switch(engine::take_output(ref mut e,i)){
                case .ok(v):{v}case .err(_):{assert(false);return;}
            };
            assert(!engine::output_available(ref output) && engine::output_view(ref output).len==0);
            assert(!engine::output_completion(ref output).success);
            assert(engine::output_completion(ref output).emits==if(early){0}else{1});
            assert(engine::output_completion(ref output).diagnostic.code.kind==failed.diagnostic.code.kind);
            ledger(ref e,input,maximum(input+required,input+keep+engine::output_transport_bytes()));
        }
        destroy(ref mut e,i);release(ref mut e,p);close(ref mut e);
    }
    physical(ref baseline);
}
// Group 4: late divide-by-zero keeps the empty Published Vec8 (576), discards
// the emitted prefix, and early Published allocation failure keeps zero bytes.
pub fn void late_failure_and_early_oom_have_distinct_retained_bytes(){failure_case(false);failure_case(true);}

fn i64 ordinal(usize index){var usize n=0;var i64 value=0;while(n<index){n+=1;value+=1;}return value;}
fn void allocator_sweep(u32 mode){
    let Heap baseline=heap();let usize input=input_size(mode);let usize limit=64;
    {
        var engine::Engine e=switch(created(268435456,536870912,memory::defaults())){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut e,mode,source(mode,2));
        let usize required=requirement(ref e,p,if(mode>=2){limit}else{0});
        let usize calibration=bound(ref mut e,p,mode,64,16000000,limit);let Heap stored=heap();
        unsafe{probe_rebase()};assert(event(engine::execute_once(ref mut e,calibration)).kind==1);
        let usize allocations=unsafe{probe_attempts()};assert(allocations>0 && allocations<=64);
        assert(unsafe{probe_peak_bytes()}<=stored.bytes+required);destroy(ref mut e,calibration);
        var usize at=0;while(at<allocations){
            let usize i=bound(ref mut e,p,mode,64,16000000,limit);let Heap before=heap();
            let usize prior_peak=instance(ref e).peak;let usize object=next(ref e);
            unsafe{probe_rebase()};unsafe{bc_runtime_engine_test_fail(ordinal(at))};
            let Result<engine::Event,engine::Error> attempted=engine::execute_once(ref mut e,i);
            unsafe{bc_runtime_engine_test_fail(-1)};let engine::Event failed=event(attempted);
            assert(failed.kind==2 && failed.diagnostic.code.kind==15);
            assert(unsafe{probe_attempts()}==at+1 && unsafe{probe_peak_bytes()}<=before.bytes+required);
            let usize keep=instance(ref e).current-input;
            assert(keep==0 || (mode>=2 && keep==576));
            assert(unsafe{probe_live_bytes()}==before.bytes+keep);
            ledger(ref e,input+keep,maximum(prior_peak,input+required));assert(next(ref e)==object);
            same_event(failed,event(engine::observe(ref mut e,i)));counts(ref mut e,1,1,1);
            destroy(ref mut e,i);ledger(ref e,0,maximum(prior_peak,input+required));at+=1;
        }
        // Fresh owner recovery, then explicit cleanup must return all physical
        // allocations; neither a failed scratch owner nor a charge may leak.
        let usize retry=bound(ref mut e,p,mode,64,16000000,limit);let Heap before=heap();unsafe{probe_rebase()};
        let engine::Event done=event(engine::execute_once(ref mut e,retry));assert(done.kind==1 && done.value==42);
        assert(unsafe{probe_peak_bytes()}<=before.bytes+required);
        assert(unsafe{probe_live_bytes()}==before.bytes+retained(mode,limit));
        destroy(ref mut e,retry);release(ref mut e,p);close(ref mut e);
    }
    physical(ref baseline);
}
// Group 5: calibrate actual allocation ordinals, fail every one in each of the
// four modes with array/place scratch, and bound physical peak by reservation.
pub fn void every_allocator_failure_fits_reservation_and_cleans_up(){
    var u32 mode=0;while(mode<4){allocator_sweep(mode);clean();mode+=1;}
}

fn Result<engine::Output,u8> detached(bool short){
    let usize input=capacity(64);let usize peer_input=capacity(1048576);let usize limit=64;
    let usize keep=retained(3,limit);let usize exact=input+keep+peer_input+engine::output_transport_bytes();
    var engine::Engine e=switch(created(exact-1,if(short){exact-1}else{exact},memory::defaults())){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    let usize p=compiled(ref mut e,3,source(3,0));let usize q=compiled(ref mut e,1,source(1,0));
    let usize i=bound(ref mut e,p,3,64,16000000,limit);
    let engine::Event done=event(engine::execute_once(ref mut e,i));assert(done.kind==1);
    // Add the large peer only after execution: its 320-byte bind transport
    // fits, but extraction needs the measured output transport bytes of aggregate room.
    let usize peer=bound(ref mut e,q,1,1048576,123,0);
    let live::Observation l=instance(ref e);let memory::Observation m=programs(ref e);
    let Heap before=heap();unsafe{probe_rebase()};
    if(short){
        rejected_take(engine::take_output(ref mut e,i),8);
        assert(unsafe{probe_attempts()}==0);physical(ref before);unchanged(ref e,ref l,ref m);
        same_event(done,event(engine::observe(ref mut e,i)));counts(ref mut e,2,2,2);
        destroy(ref mut e,peer);
    }
    let live::Observation retry=instance(ref e);unsafe{probe_rebase()};
    let engine::Output output=switch(engine::take_output(ref mut e,i)){
        case .ok(v):{v}case .err(_):{return .err(2);}
    };
    assert(unsafe{probe_attempts()}==1);
    assert(unsafe{probe_peak_bytes()}==if(short){before.bytes-peer_input+engine::output_transport_bytes()}else{before.bytes+engine::output_transport_bytes()});
    assert(unsafe{probe_live_bytes()}==if(short){before.bytes-peer_input}else{before.bytes});
    let usize current=if(short){input}else{input+peer_input};
    ledger(ref e,current,maximum(retry.peak,retry.current+engine::output_transport_bytes()));
    if(!short){assert(instance(ref e).peak==exact);}
    published(ref output,64);same_event(done,event(engine::observe(ref mut e,i)));
    rejected_take(engine::take_output(ref mut e,i),2);
    release(ref mut e,p);release(ref mut e,q);destroy(ref mut e,i);
    ledger(ref e,if(short){0}else{peer_input},instance(ref e).peak);
    if(!short){
        let engine::Event ready=event(engine::observe(ref mut e,peer));assert(ready.kind==0 && ready.remaining==123);
        destroy(ref mut e,peer);
    }
    counts(ref mut e,0,0,0);close(ref mut e);published(ref output,64);return .ok(output);
}
// Group 6: measured outgoing Vec8 exact/one-less preflight runs before allocation. A
// successful transfer drops only retained output charge; detached bytes survive
// Instance, Program, Engine destruction and the Engine resource leaving scope.
pub fn void output_transport_preflight_charge_transfer_and_detached_lifetime(){
    clean();var usize pass=0;while(pass<2){
        {
            let engine::Output output=switch(detached(pass==1)){
                case .ok(v):{v}case .err(_):{assert(false);return;}
            };
            published(ref output,64);assert(unsafe{probe_live_bytes()}==640 && unsafe{probe_live()}==2);
        }
        clean();pass+=1;
    }
}

// Group 7: release closes new admissions for this Program but preserves every
// pin. Engine moves and Ready cancellation must keep input/retained-output
// ownership and historical peaks, including implicit cleanup of mixed phases.
pub fn void moves_cancel_and_released_program_pins_preserve_owners(){
    let Heap baseline=heap();let usize input=capacity(64);let usize limit=64;
    {
        var engine::Engine original=switch(created(268435456,536870912,memory::defaults())){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut original,3,source(3,0));let usize required=requirement(ref original,p,limit);
        let usize ready=bound(ref mut original,p,3,64,123,limit);
        let usize done=bound(ref mut original,p,3,64,16000000,limit);
        let usize pending=bound(ref mut original,p,3,64,16000000,limit);
        release(ref mut original,p);let Heap before=heap();var engine::Engine moved=original;
        counts(ref mut moved,1,3,3);physical(ref before);
        assert(event(engine::execute_once(ref mut moved,done)).kind==1);
        let usize peak=3*input+required;ledger(ref moved,3*input+retained(3,limit),peak);
        let engine::Event cancelled=event(engine::cancel_ready(ref mut moved,ready));
        assert(cancelled.kind==3 && cancelled.remaining==123 && cancelled.fuel_known);
        rejected_take(engine::take_output(ref mut moved,ready),2);
        rejected_event(engine::execute_once(ref mut moved,ready),11);
        let Heap retained_heap=heap();var engine::Engine again=moved;physical(ref retained_heap);
        ledger(ref again,3*input+retained(3,limit),peak);counts(ref mut again,1,3,3);
        same_event(cancelled,event(engine::observe(ref mut again,ready)));
        destroy(ref mut again,ready);ledger(ref again,2*input+retained(3,limit),peak);counts(ref mut again,1,2,2);
        assert(event(engine::execute_once(ref mut again,pending)).kind==1);
        let usize final_peak=maximum(peak,2*input+retained(3,limit)+required);
        ledger(ref again,2*(input+retained(3,limit)),final_peak);
        destroy(ref mut again,done);ledger(ref again,input+retained(3,limit),final_peak);counts(ref mut again,1,1,1);
        // Leave the released pinned Program and its untaken completed output
        // to owning Engine cleanup. The physical baseline proves both drops.
    }
    physical(ref baseline);
}

pub fn void run(){
    four_modes_and_layouts_exact_and_one_less();clean();
    simultaneous_input_and_peer_output_exact_and_one_less();clean();
    combined_engine_exact_and_one_less();clean();
    late_failure_and_early_oom_have_distinct_retained_bytes();clean();
    every_allocator_failure_fits_reservation_and_cleans_up();clean();
    output_transport_preflight_charge_transfer_and_detached_lifetime();clean();
    moves_cancel_and_released_program_pins_preserve_owners();clean();
}
