module engine_instance_memory;
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

// Native fixture only. Reuse heap-observer.c and compile-test-host.inc.
// Admission-only boundaries keep their original small ceilings. Successful
// execution separately accounts cached scratch, retained output and measured take Vec8 bytes.
// Replacement remains max(old,new)+transient, not old+new+transient.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_peak_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void probe_rebase();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
unsafe extern C fn usize bc_runtime_engine_test_compile_epoch(ptr void owner);
unsafe extern C fn usize bc_runtime_engine_test_compile_next(ptr void owner);

struct Heap { usize blocks; usize bytes; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void physical(ref Heap before,usize blocks,usize size){
    assert(unsafe{probe_live()}==before.blocks+blocks);
    assert(unsafe{probe_live_bytes()}==before.bytes+size);
}
fn usize transport(){return 320;}
fn usize maximum(usize a,usize b){return if(a>b){a}else{b};}
fn usize execution_bound(u32 mode,usize limit){
    let usize scratch=if(mode==1 || mode==3){24576}else{0};
    return scratch+if(mode==2 || mode==3){616+limit}else{0};
}
fn usize id(Result<usize,engine::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn void rejected(Result<usize,engine::Error> result,u32 status){switch(result){
    case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}
};}
fn engine::Event event(Result<engine::Event,engine::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,
        .diagnostic=diagnostics::absent(errors::make(0,0)),.remaining=0,.fuel_known=false}}
};}
fn live::Observation instance(ref engine::Engine e){return switch(engine::instance_memory(e)){
    case .ok(v):{v}case .err(_):{assert(false);live::Observation{
        .instance_limit=0,.instances_limit=0,.current=0,.peak=0,.closed=false}}
};}
fn memory::Observation programs(ref engine::Engine e){return switch(engine::program_memory(e)){
    case .ok(v):{v}case .err(_):{assert(false);memory::Observation{
        .engine_limit=0,.program_limit=0,.programs_limit=0,.control_bytes=0,
        .program_bytes=0,.program_peak=0,.tracked_bytes=0,.tracked_peak=0,
        .closed=false,.working_limit=0,.working_peak=0,.external_bytes=0,.compile_source_bytes=0}}
};}
fn void ledger(ref engine::Engine e,usize current,usize peak,bool closed){
    let live::Observation l=instance(e);let memory::Observation p=programs(e);
    assert(l.current==current && l.peak==peak && l.closed==closed);
    assert(l.current<=l.peak && l.peak<=l.instances_limit);
    assert(p.external_bytes==current && p.closed==closed);
    assert(p.tracked_bytes==p.control_bytes+p.program_bytes+current);
    assert(p.tracked_peak>=p.tracked_bytes && p.tracked_peak<=p.engine_limit);
}
fn void unchanged(ref engine::Engine e,ref live::Observation before,ref memory::Observation prior){
    let live::Observation l=instance(e);let memory::Observation p=programs(e);
    assert(l.instance_limit==before.instance_limit && l.instances_limit==before.instances_limit);
    assert(l.current==before.current && l.peak==before.peak && l.closed==before.closed);
    assert(p.engine_limit==prior.engine_limit && p.program_limit==prior.program_limit);
    assert(p.programs_limit==prior.programs_limit && p.control_bytes==prior.control_bytes);
    assert(p.program_bytes==prior.program_bytes && p.program_peak==prior.program_peak);
    assert(p.external_bytes==prior.external_bytes && p.tracked_bytes==prior.tracked_bytes);
    assert(p.tracked_peak==prior.tracked_peak && p.working_limit==prior.working_limit);
    assert(p.working_peak==prior.working_peak && p.closed==prior.closed);
}
fn void counts(ref mut engine::Engine e,usize codes,usize owners,usize pins){switch(engine::inspect(e)){
    case .ok(v):{assert(v.programs==codes && v.instances==owners && v.pins==pins && !v.closed);}
    case .err(_):{assert(false);}
};}
fn usize epoch(ref engine::Engine e){return unsafe{bc_runtime_engine_test_compile_epoch(e as ptr void)};}
fn usize next(ref engine::Engine e){return unsafe{bc_runtime_engine_test_compile_next(e as ptr void)};}
fn usize execution(ref engine::Engine e,usize p,u32 mode,usize limit){
    let Heap before=heap();let usize attempts=unsafe{probe_attempts()};
    let usize admission=epoch(e);let usize object=next(e);
    let usize cached=id(engine::required_execution_bytes(e,p,limit));
    assert(cached==execution_bound(mode,limit));physical(ref before,0,0);
    assert(unsafe{probe_attempts()}==attempts && epoch(e)==admission && next(e)==object);
    return cached;
}
fn void execution_quota_preserves_ready(ref mut engine::Engine e,usize i){
    let engine::Event ready=event(engine::observe(e,i));assert(ready.kind==0);
    let live::Observation before=instance(e);let memory::Observation prior=programs(e);
    let Heap stored=heap();unsafe{probe_rebase()};
    switch(engine::execute_once(e,i)){
        case .ok(_):{assert(false);}case .err(error):{assert(error.status==8);}
    };
    assert(unsafe{probe_attempts()}==0);physical(ref stored,0,0);unchanged(e,ref before,ref prior);
    let engine::Event after=event(engine::observe(e,i));
    assert(after.kind==ready.kind && after.value==ready.value && after.remaining==ready.remaining);
    assert(after.fuel_known==ready.fuel_known && after.diagnostic.code.kind==ready.diagnostic.code.kind);
    assert(after.diagnostic.code.offset==ready.diagnostic.code.offset);
    assert(after.diagnostic.at.source==ready.diagnostic.at.source);
    assert(after.diagnostic.at.start==ready.diagnostic.at.start && after.diagnostic.at.end==ready.diagnostic.at.end);
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
fn usize compiled(ref mut engine::Engine e,u32 mode){
    if(mode==1 || mode==3){
        let ref u8[] source=if(mode==1){
            b"module app;pub fn i32 chosen(ref u8[] data){if(data.len==0){return 42;}return data[0] as i32;}"
        }else{b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}"};
        let modules::Index index=switch(indexed(source)){
            case .ok(v):{v}case .err(_):{assert(false);return 0;}
        };
        let input_entries::InputEntry entry=switch(input_entries::select_i32_input(index,b"app",b"chosen")){
            case .ok(v):{v}case .err(_):{assert(false);return 0;}
        };
        return if(mode==1){id(engine::compile_input(e,entry,65536))}
            else{id(engine::compile_input_output(e,entry,65536))};
    }
    let modules::Index index=switch(indexed(b"module app;pub fn i32 chosen(){return 42;}")){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}
    };
    let entries::Entry entry=switch(entries::select_i32(index,b"app",b"chosen")){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}
    };
    return if(mode==0){id(engine::compile(e,entry,65536))}
        else{id(engine::compile_output(e,entry,65536))};
}
fn Result<engine::Engine,engine::Error> created(usize single,usize aggregate){
    return engine::create_with_instance_memory(
        engine::Limits{.programs=4,.instances=4,.fuel=16000000},4194304,
        memory::defaults(),268435456,live::Limits{.instance=single,.instances=aggregate});
}
// Build payloads through the real immutable Snapshot API. Its private backing
// is never constructed or patched by the test transport.
fn Result<inputs::Snapshot,u8> payload(usize reserve,ref u8[] text){
    var bytes::Buffer data=switch(bytes::with_capacity(reserve)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    if(!bytes::append(ref mut data,text).is_ok){return .err(2);}
    if(!bytes::resize_zeroed(ref mut data,reserve).is_ok){return .err(2);}
    var usize fuel=0;
    return switch(inputs::snapshot(bytes::view(ref data),inputs::hard_limit(),0,ref mut fuel)){
        case .ok(v):{.ok(v)}case .err(_):{.err(3)}
    };
}
fn usize capacity(usize reserve){
    let inputs::Snapshot input=switch(payload(reserve,b"*")){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}
    };
    let usize size=inputs::capacity(ref input);assert(size>=reserve && size>1);return size;
}
fn usize bound(ref mut engine::Engine e,usize p,usize reserve,ref u8[] text,u32 mode,usize fuel){
    let inputs::Snapshot input=switch(payload(reserve,text)){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}
    };
    return if(mode==1){id(engine::create_input_instance(e,p,input,fuel))}
        else{id(engine::create_input_output_instance(e,p,input,fuel,reserve,true))};
}
fn void release(ref mut engine::Engine e,usize p){assert(id(engine::release_program(e,p))==p);}
fn void destroy(ref mut engine::Engine e,usize i){assert(id(engine::destroy_instance(e,i))==i);}
fn void close(ref mut engine::Engine e){assert(id(engine::destroy(e))==0);}

fn void instance_boundary(bool short,u32 mode){
    let Heap baseline=heap();let usize size=capacity(64);let usize ceiling=size+transport();
    {
        var engine::Engine e=switch(created(if(short){ceiling-1}else{ceiling},2*ceiling)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut e,mode);let Heap stored=heap();
        let inputs::Snapshot input=switch(payload(64,b"*")){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        assert(inputs::observe(ref input).length==size && inputs::capacity(ref input)==size);
        let live::Observation before=instance(ref e);let memory::Observation prior=programs(ref e);
        let usize admission=epoch(ref e);let usize object=next(ref e);unsafe{probe_rebase()};
        if(short){
            let Result<usize,engine::Error> result=if(mode==1){
                engine::create_input_instance(ref mut e,p,input,16000000)
            }else{engine::create_input_output_instance(ref mut e,p,input,16000000,64,true)};
            rejected(result,8);
            assert(unsafe{probe_attempts()}==0);physical(ref stored,0,0);
            assert(epoch(ref e)==admission && next(ref e)==object);
            unchanged(ref e,ref before,ref prior);counts(ref mut e,1,0,0);
        }else{
            let usize i=if(mode==1){id(engine::create_input_instance(ref mut e,p,input,16000000))}
                else{id(engine::create_input_output_instance(ref mut e,p,input,16000000,64,true))};
            assert(i==object);
            assert(unsafe{probe_attempts()}==1 && unsafe{probe_peak_bytes()}==stored.bytes+ceiling);
            physical(ref stored,1,size);ledger(ref e,size,ceiling,false);
            let live::Observation l=instance(ref e);
            assert(l.instance_limit==ceiling && l.instances_limit==2*ceiling);
            assert(execution(ref e,p,mode,if(mode==3){64}else{0})>ceiling);
            execution_quota_preserves_ready(ref mut e,i);
            assert(event(engine::cancel_ready(ref mut e,i)).kind==3);
            ledger(ref e,size,ceiling,false);destroy(ref mut e,i);physical(ref stored,0,0);
            ledger(ref e,0,ceiling,false);
        }
        release(ref mut e,p);close(ref mut e);
    }
    physical(ref baseline,0,0);
}
// Group 1: payload fits both limits, but one byte missing for Vec8 must reject.
pub fn void exact_and_one_less_instance_capacity_plus_transport(){
    instance_boundary(false,1);instance_boundary(true,1);
    instance_boundary(false,3);instance_boundary(true,3);
}

fn void aggregate_boundary(bool short){
    let Heap baseline=heap();let usize size=capacity(256);let usize ceiling=2*size+transport();
    {
        var engine::Engine e=switch(created(size+transport(),if(short){ceiling-1}else{ceiling})){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize peer=compiled(ref mut e,0);let usize p=compiled(ref mut e,1);
        let usize peer_instance=id(engine::create_instance(ref mut e,peer,16000000));
        let memory::Observation stored=programs(ref e);let Heap owner_heap=heap();
        let usize first=bound(ref mut e,p,256,b"*",1,16000000);
        ledger(ref e,size,size+transport(),false);physical(ref owner_heap,1,size);
        let inputs::Snapshot input=switch(payload(256,b"+")){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let live::Observation before=instance(ref e);let memory::Observation prior=programs(ref e);
        let usize admission=epoch(ref e);let usize object=next(ref e);unsafe{probe_rebase()};
        if(short){
            rejected(engine::create_input_instance(ref mut e,p,input,16000000),8);
            assert(unsafe{probe_attempts()}==0);physical(ref owner_heap,1,size);
            assert(epoch(ref e)==admission && next(ref e)==object);
            unchanged(ref e,ref before,ref prior);counts(ref mut e,2,2,2);
        }else{
            let usize second=id(engine::create_input_instance(ref mut e,p,input,16000000));assert(second==object);
            ledger(ref e,2*size,ceiling,false);physical(ref owner_heap,2,2*size);
            assert(unsafe{probe_peak_bytes()}==owner_heap.bytes+ceiling);
            counts(ref mut e,2,3,3);
            // Real compilation while both inputs remain retained includes the
            // same external baseline; publishing a peer cannot reset it.
            let usize extra=compiled(ref mut e,0);let memory::Observation added=programs(ref e);
            assert(added.program_bytes>stored.program_bytes && added.external_bytes==2*size);
            ledger(ref e,2*size,ceiling,false);release(ref mut e,extra);
            assert(programs(ref e).program_bytes==stored.program_bytes);
            assert(execution(ref e,p,1,0)==24576);
            execution_quota_preserves_ready(ref mut e,second);
            assert(event(engine::cancel_ready(ref mut e,second)).kind==3);
            destroy(ref mut e,second);ledger(ref e,size,ceiling,false);
        }
        assert(programs(ref e).program_bytes==stored.program_bytes);
        assert(event(engine::execute_once(ref mut e,peer_instance)).value==42);
        execution_quota_preserves_ready(ref mut e,first);
        assert(event(engine::cancel_ready(ref mut e,first)).kind==3);
        destroy(ref mut e,first);destroy(ref mut e,peer_instance);
        ledger(ref e,0,if(short){size+transport()}else{ceiling},false);
        release(ref mut e,p);release(ref mut e,peer);close(ref mut e);
    }
    physical(ref baseline,0,0);
}
// Group 2: simultaneously retained inputs share aggregate headroom with peers.
pub fn void aggregate_exact_and_one_less_keep_peer_programs_and_external_baseline(){
    aggregate_boundary(false);aggregate_boundary(true);
}

// Group 3: cancellation and Program release do not end input ownership.
// Removing a middle owner refunds only that capacity and rejects a second drop.
pub fn void cancel_release_and_destroy_refund_each_retained_owner_once(){
    let Heap baseline=heap();let usize size=capacity(128);let usize admission_peak=3*size+transport();
    let usize peak=3*size+execution_bound(1,0);
    {
        var engine::Engine e=switch(created(size+execution_bound(1,0),peak)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut e,1);let Heap stored_heap=heap();
        let usize scratch=execution(ref e,p,1,0);assert(peak==3*size+scratch);
        let usize kept=programs(ref e).program_bytes;
        let usize a=bound(ref mut e,p,128,b"*",1,123);
        let usize b=bound(ref mut e,p,128,b"+",1,16000000);
        let usize c=bound(ref mut e,p,128,b",",1,16000000);
        ledger(ref e,3*size,admission_peak,false);physical(ref stored_heap,3,3*size);
        let engine::Event cancelled=event(engine::cancel_ready(ref mut e,a));
        assert(cancelled.kind==3 && cancelled.remaining==123 && cancelled.fuel_known);
        release(ref mut e,p);ledger(ref e,3*size,admission_peak,false);
        assert(programs(ref e).program_bytes==kept);physical(ref stored_heap,3,3*size);
        counts(ref mut e,1,3,3);rejected(engine::destroy(ref mut e),3);
        assert(event(engine::execute_once(ref mut e,b)).value==43);
        ledger(ref e,3*size,peak,false);destroy(ref mut e,b);
        ledger(ref e,2*size,peak,false);physical(ref stored_heap,2,2*size);
        let live::Observation before=instance(ref e);let memory::Observation prior=programs(ref e);
        rejected(engine::destroy_instance(ref mut e,b),2);unchanged(ref e,ref before,ref prior);
        assert(event(engine::execute_once(ref mut e,c)).value==44);
        destroy(ref mut e,a);ledger(ref e,size,peak,false);
        assert(programs(ref e).program_bytes==kept);destroy(ref mut e,c);
        ledger(ref e,0,peak,false);assert(programs(ref e).program_bytes==0);
        counts(ref mut e,0,0,0);close(ref mut e);ledger(ref e,0,peak,true);
    }
    physical(ref baseline,0,0);
}

// Group 4: moving the owning Engine and compacting its front input cannot
// detach peer bytes or lose ledger history; closed observations move as well.
pub fn void engine_moves_preserve_inputs_external_bytes_and_peak_history(){
    let Heap baseline=heap();let usize small=capacity(64);let usize large=capacity(512);
    let usize admission_peak=small+large+transport();let usize peak=large+execution_bound(1,0);
    {
        var engine::Engine original=switch(created(peak,peak)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut original,1);
        assert(peak==large+execution(ref original,p,1,0));
        let usize a=bound(ref mut original,p,64,b"*",1,16000000);
        let usize b=bound(ref mut original,p,512,b"+",1,16000000);
        release(ref mut original,p);let Heap physical_before=heap();
        var engine::Engine moved=original;physical(ref physical_before,0,0);
        ledger(ref moved,small+large,admission_peak,false);counts(ref mut moved,1,2,2);
        destroy(ref mut moved,a);ledger(ref moved,large,admission_peak,false);
        var engine::Engine again=moved;ledger(ref again,large,admission_peak,false);
        assert(event(engine::execute_once(ref mut again,b)).value==43);
        ledger(ref again,large,peak,false);
        destroy(ref mut again,b);close(ref mut again);ledger(ref again,0,peak,true);
        var engine::Engine closed=again;ledger(ref closed,0,peak,true);
    }
    physical(ref baseline,0,0);
}

// Group 5: both owning APIs retain their actual Snapshot backing allocation.
// Output stays charged beside input until take; take refunds only output.
pub fn void input_and_input_output_own_payload_until_instance_destruction(){
    let Heap baseline=heap();let usize size=capacity(64);let usize admission_peak=2*size+transport();
    let usize peak=2*size+execution_bound(3,64);let usize retained_output=576+64;
    {
        var engine::Engine e=switch(created(size+execution_bound(3,64),peak)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut e,1);let usize q=compiled(ref mut e,3);
        let usize input_scratch=execution(ref e,p,1,0);let usize output_scratch=execution(ref e,q,3,64);
        assert(peak==2*size+output_scratch);
        let usize a=bound(ref mut e,p,64,b"*",1,16000000);
        let usize b=bound(ref mut e,q,64,b"\x00\xFF\x00",3,16000000);
        ledger(ref e,2*size,admission_peak,false);release(ref mut e,p);release(ref mut e,q);
        assert(event(engine::execute_once(ref mut e,a)).value==42);
        ledger(ref e,2*size,2*size+input_scratch,false);
        let engine::Event done=event(engine::execute_once(ref mut e,b));
        assert(done.kind==1 && done.value==42 && done.fuel_known);
        ledger(ref e,2*size+retained_output,peak,false);
        let usize take_peak=maximum(peak,2*size+retained_output+engine::output_transport_bytes());
        {
            let engine::Output output=switch(engine::take_output(ref mut e,b)){
                case .ok(v):{v}case .err(_):{assert(false);return;}
            };
            assert(engine::output_available(ref output));
            assert(engine::output_view(ref output).len==size);
            assert(bytes::equal(engine::output_view(ref output)[0..3],b"\x00\xFF\x00"));
            ledger(ref e,2*size,take_peak,false);destroy(ref mut e,b);ledger(ref e,size,take_peak,false);
            assert(bytes::equal(engine::output_view(ref output)[0..3],b"\x00\xFF\x00"));
        }
        destroy(ref mut e,a);ledger(ref e,0,take_peak,false);close(ref mut e);
    }
    physical(ref baseline,0,0);
}

fn void empty_mode(u32 mode){
    let Heap baseline=heap();
    {
        var engine::Engine e=switch(created(transport(),transport())){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut e,mode);let Heap stored=heap();var usize fuel=0;
        var usize i=0;
        if(mode==1 || mode==3){
            let inputs::Snapshot empty=switch(inputs::snapshot(b"",0,0,ref mut fuel)){
                case .ok(v):{v}case .err(_):{assert(false);return;}
            };
            assert(inputs::capacity(ref empty)==0);unsafe{probe_rebase()};
            i=if(mode==1){id(engine::create_input_instance(ref mut e,p,empty,16000000))}
                else{id(engine::create_input_output_instance(ref mut e,p,empty,16000000,0,true))};
            assert(unsafe{probe_attempts()}==1 && unsafe{probe_peak_bytes()}==stored.bytes+transport());
        }else{
            unsafe{probe_rebase()};
            i=if(mode==0){id(engine::create_instance(ref mut e,p,16000000))}
                else{id(engine::create_output_instance(ref mut e,p,16000000,0,true))};
            assert(unsafe{probe_attempts()}==0);
        }
        let usize peak=if(mode==1 || mode==3){transport()}else{0};
        physical(ref stored,0,0);ledger(ref e,0,peak,false);
        let usize scratch=execution(ref e,p,mode,0);release(ref mut e,p);
        if(scratch==0){assert(event(engine::execute_once(ref mut e,i)).value==42);}
        else{
            assert(scratch>transport());execution_quota_preserves_ready(ref mut e,i);
            assert(event(engine::cancel_ready(ref mut e,i)).kind==3);
        }
        ledger(ref e,0,peak,false);destroy(ref mut e,i);close(ref mut e);ledger(ref e,0,peak,true);
    }
    physical(ref baseline,0,0);
}
// Keep the exact 320/319 admission cases above. A separate owner supplies only
// the cached execution headroom needed to preserve successful zero-byte modes.
fn void empty_execution_mode(u32 mode){
    let Heap baseline=heap();let usize ceiling=maximum(transport(),execution_bound(mode,0));
    {
        var engine::Engine e=switch(created(ceiling,ceiling)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut e,mode);let usize scratch=execution(ref e,p,mode,0);
        var usize fuel=0;var usize i=0;
        if(mode==1 || mode==3){
            let inputs::Snapshot empty=switch(inputs::snapshot(b"",0,0,ref mut fuel)){
                case .ok(v):{v}case .err(_):{assert(false);return;}
            };
            i=if(mode==1){id(engine::create_input_instance(ref mut e,p,empty,16000000))}
                else{id(engine::create_input_output_instance(ref mut e,p,empty,16000000,0,true))};
        }else{
            i=if(mode==0){id(engine::create_instance(ref mut e,p,16000000))}
                else{id(engine::create_output_instance(ref mut e,p,16000000,0,true))};
        }
        let usize admission_peak=if(mode==1 || mode==3){transport()}else{0};
        ledger(ref e,0,admission_peak,false);release(ref mut e,p);
        let engine::Event done=event(engine::execute_once(ref mut e,i));assert(done.kind==1 && done.value==42);
        let usize retained=if(mode==2 || mode==3){576}else{0};
        let usize peak=maximum(admission_peak,scratch);
        ledger(ref e,retained,peak,false);destroy(ref mut e,i);
        ledger(ref e,0,peak,false);close(ref mut e);ledger(ref e,0,peak,true);
    }
    physical(ref baseline,0,0);
}
fn void empty_transport_one_less(u32 mode){
    let Heap baseline=heap();
    {
        var engine::Engine e=switch(created(transport()-1,transport()-1)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut e,mode);let Heap stored=heap();var usize fuel=0;
        let inputs::Snapshot empty=switch(inputs::snapshot(b"",0,0,ref mut fuel)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        assert(inputs::capacity(ref empty)==0);
        let live::Observation before=instance(ref e);let memory::Observation prior=programs(ref e);
        let usize admission=epoch(ref e);let usize object=next(ref e);unsafe{probe_rebase()};
        let Result<usize,engine::Error> result=if(mode==1){
            engine::create_input_instance(ref mut e,p,empty,16000000)
        }else{engine::create_input_output_instance(ref mut e,p,empty,16000000,0,true)};
        rejected(result,8);assert(unsafe{probe_attempts()}==0);physical(ref stored,0,0);
        assert(epoch(ref e)==admission && next(ref e)==object);
        unchanged(ref e,ref before,ref prior);release(ref mut e,p);close(ref mut e);
    }
    physical(ref baseline,0,0);
}
// Group 6: zero-byte input still needs transport, whereas ordinary/output-only
// creation does not. No synthetic one-byte owner charge is introduced.
pub fn void empty_input_and_zero_payload_modes_distinguish_transport_from_retention(){
    empty_mode(0);empty_mode(1);empty_mode(2);empty_mode(3);
    empty_transport_one_less(1);empty_transport_one_less(3);
    empty_execution_mode(0);empty_execution_mode(1);empty_execution_mode(2);empty_execution_mode(3);
}

fn void transport_oom(u32 mode){
    let Heap baseline=heap();let usize small=capacity(64);let usize large=capacity(512);
    let usize admission_peak=small+large+transport();
    let usize peak=small+large+execution_bound(mode,512);
    {
        var engine::Engine e=switch(created(large+execution_bound(mode,512),peak)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut e,mode);let usize peer=compiled(ref mut e,0);
        assert(peak==small+large+execution(ref e,p,mode,if(mode==1){0}else{512}));
        let usize first=bound(ref mut e,p,64,b"*",mode,16000000);
        let usize pin=id(engine::create_instance(ref mut e,peer,16000000));
        ledger(ref e,small,small+transport(),false);let Heap stored=heap();
        let inputs::Snapshot input=switch(payload(512,b"+")){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let memory::Observation prior=programs(ref e);
        let usize admission=epoch(ref e);let usize object=next(ref e);
        // Construct the owning input before injection. Only the Vec8 reserve
        // fails; preflight already records the admitted reservation pressure.
        unsafe{probe_rebase()};unsafe{bc_runtime_engine_test_fail(0)};
        let Result<usize,engine::Error> result=if(mode==1){
            engine::create_input_instance(ref mut e,p,input,16000000)
        }else{engine::create_input_output_instance(ref mut e,p,input,16000000,64,true)};
        unsafe{bc_runtime_engine_test_fail(-1)};rejected(result,6);
        assert(unsafe{probe_attempts()}==1);physical(ref stored,0,0);
        assert(epoch(ref e)==admission && next(ref e)==object);
        ledger(ref e,small,admission_peak,false);
        let memory::Observation after=programs(ref e);
        assert(after.program_bytes==prior.program_bytes && after.program_peak==prior.program_peak);
        assert(after.external_bytes==prior.external_bytes && after.tracked_bytes==prior.tracked_bytes);
        assert(after.working_peak==prior.working_peak);
        assert(after.tracked_peak==maximum(prior.tracked_peak,prior.control_bytes+prior.program_bytes+admission_peak));
        counts(ref mut e,2,2,2);assert(event(engine::observe(ref mut e,first)).kind==0);
        // Fresh caller-owned input succeeds with exactly the unspent object ID.
        let usize retry=bound(ref mut e,p,512,b"+",mode,16000000);assert(retry==object);
        ledger(ref e,small+large,admission_peak,false);
        let engine::Event completed=event(engine::execute_once(ref mut e,retry));
        assert(completed.kind==1 && completed.value==if(mode==1){43}else{42});
        let usize retained_output=if(mode==3){576+512}else{0};
        ledger(ref e,small+large+retained_output,peak,false);
        assert(event(engine::execute_once(ref mut e,pin)).value==42);
        ledger(ref e,small+large+retained_output,peak,false);
        destroy(ref mut e,retry);ledger(ref e,small,peak,false);
        destroy(ref mut e,first);destroy(ref mut e,pin);
        release(ref mut e,p);release(ref mut e,peer);close(ref mut e);ledger(ref e,0,peak,true);
    }
    physical(ref baseline,0,0);
}
// Group 7: failed transport allocation consumes neither ID nor epoch, refunds
// the moved argument, preserves peer owners, and retains peak-only reservations.
pub fn void transport_oom_preserves_current_peers_and_ids_but_records_reservation_peak(){
    transport_oom(1);transport_oom(3);
}

// Group 8: automatic Engine cleanup must reclaim Ready, Cancelled and Complete
// input owners plus released-but-pinned Programs without explicit destroy calls.
pub fn void owning_cleanup_returns_all_sdk_blocks_and_bytes_to_entry_baseline(){
    let Heap baseline=heap();let usize size=capacity(128);
    let usize admission_peak=3*size+transport();let usize peak=3*size+execution_bound(3,128);
    {
        var engine::Engine e=switch(created(size+execution_bound(3,128),peak)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        let usize p=compiled(ref mut e,1);let usize q=compiled(ref mut e,3);
        assert(peak==3*size+execution(ref e,q,3,128));
        let usize ready=bound(ref mut e,p,128,b"*",1,16000000);
        let usize cancelled=bound(ref mut e,p,128,b"+",1,123);
        let usize completed=bound(ref mut e,q,128,b"\x00\xFF",3,16000000);
        assert(event(engine::observe(ref mut e,ready)).kind==0);
        assert(event(engine::cancel_ready(ref mut e,cancelled)).kind==3);
        ledger(ref e,3*size,admission_peak,false);
        assert(event(engine::execute_once(ref mut e,completed)).kind==1);
        release(ref mut e,p);release(ref mut e,q);counts(ref mut e,2,3,3);
        ledger(ref e,3*size+576+128,peak,false);
    }
    physical(ref baseline,0,0);
}

// Group 9: the combined Engine ceiling includes the same retained input plus
// transport, independent of the more generous per-Instance/set ceilings.
pub fn void combined_engine_exact_and_one_less_admit_before_transport_allocation(){
    let Heap baseline=heap();let usize size=capacity(1048576);var usize total=0;var usize owners=2;
    let engine::Limits count_limits=engine::Limits{.programs=4,.instances=64,.fuel=16000000};
    {
        var engine::Engine sample=switch(engine::create_with_instance_memory(count_limits,4194304,memory::defaults(),268435456,
            live::Limits{.instance=268435456,.instances=536870912})){
            case .ok(v):{v}case .err(_):{assert(false);return;}};
        let usize p=compiled(ref mut sample,1);let memory::Observation stored=programs(ref sample);
        total=stored.control_bytes+stored.program_bytes+owners*size+transport();
        while(total<=stored.tracked_peak){owners+=1;assert(owners<=64);total+=size;}
        release(ref mut sample,p);close(ref mut sample);
    }
    var usize short=0;while(short<2){
        {
            let usize ceiling=total-short;let usize per=if(ceiling>67108864){67108864}else{ceiling};
            var engine::Engine e=switch(engine::create_with_instance_memory(count_limits,4194304,
                memory::Limits{.engine=ceiling,.program=per,.programs=ceiling},268435456,
                live::Limits{.instance=268435456,.instances=536870912})){
                case .ok(v):{v}case .err(_):{assert(false);return;}};
            let usize p=compiled(ref mut e,1);var usize[64] ids=[0;64];var usize n=0;
            while(n+1<owners){ids[n]=bound(ref mut e,p,1048576,b"*",1,16000000);n+=1;}
            let Heap stored=heap();let inputs::Snapshot input=switch(payload(1048576,b"*")){
                case .ok(v):{v}case .err(_):{assert(false);return;}};
            let live::Observation before=instance(ref e);let memory::Observation prior=programs(ref e);
            let usize admission=epoch(ref e);let usize object=next(ref e);unsafe{probe_rebase()};
            if(short==1){rejected(engine::create_input_instance(ref mut e,p,input,16000000),8);assert(unsafe{probe_attempts()}==0);
                physical(ref stored,0,0);unchanged(ref e,ref before,ref prior);assert(epoch(ref e)==admission && next(ref e)==object);}
            else{let usize i=id(engine::create_input_instance(ref mut e,p,input,16000000));
                assert(i==object && unsafe{probe_attempts()}==1);
                assert(programs(ref e).tracked_peak==total);
                ledger(ref e,owners*size,owners*size+transport(),false);physical(ref stored,1,size);
                destroy(ref mut e,i);}
            n=0;while(n+1<owners){destroy(ref mut e,ids[n]);n+=1;}release(ref mut e,p);close(ref mut e);
        }physical(ref baseline,0,0);short+=1;
    }
}

pub fn void run(){
    exact_and_one_less_instance_capacity_plus_transport();
    aggregate_exact_and_one_less_keep_peer_programs_and_external_baseline();
    cancel_release_and_destroy_refund_each_retained_owner_once();
    engine_moves_preserve_inputs_external_bytes_and_peak_history();
    input_and_input_output_own_payload_until_instance_destruction();
    empty_input_and_zero_payload_modes_distinguish_transport_from_retention();
    transport_oom_preserves_current_peers_and_ids_but_records_reservation_peak();
    owning_cleanup_returns_all_sdk_blocks_and_bytes_to_entry_baseline();
    combined_engine_exact_and_one_less_admit_before_transport_allocation();
}
