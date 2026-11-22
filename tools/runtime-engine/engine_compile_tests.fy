module engine_compile_tests;
import runtime_engine as engine;
import runtime_program_memory as memory;
import module_budgeted_compile as bounded;
import module_entry as entries;
import module_input_entry as input_entries;
import module_index as modules;
import source_snapshot as sources;
import std::bytes as bytes;

// Dedicated native fixture only; compile-test-host.inc supplies the two readers.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_peak_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn usize probe_retention_start();
unsafe extern C fn void probe_rebase();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
unsafe extern C fn void bc_runtime_engine_test_seed(ptr mut void owner,u32 kind);
unsafe extern C fn usize bc_runtime_engine_test_compile_epoch(ptr void owner);
unsafe extern C fn usize bc_runtime_engine_test_compile_next(ptr void owner);

fn Result<modules::Index,u8> indexed(ref u8[] source){
    var sources::Builder b=switch(sources::builder(4096,4096)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    if(!sources::add(ref mut b,b"app.brc",source).is_ok){return .err(2);}
    let sources::Snapshot snapshot=switch(sources::freeze(ref b)){
        case .ok(v):{v}case .err(_):{return .err(3);}
    };
    return switch(modules::build(snapshot)){case .ok(v):{.ok(v)}case .err(_):{.err(4)}};
}
fn Result<entries::Entry,u8> selected(ref u8[] source){
    return switch(entries::select_i32(indexed(source)?,b"app",b"chosen")){
        case .ok(v):{.ok(v)}case .err(_):{.err(5)}
    };
}
fn Result<input_entries::InputEntry,u8> selected_input(ref u8[] source){
    return switch(input_entries::select_i32_input(indexed(source)?,b"app",b"chosen")){
        case .ok(v):{.ok(v)}case .err(_):{.err(6)}
    };
}
fn usize id(Result<usize,engine::Error> result){
    return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn void rejected(Result<usize,engine::Error> result,u32 status){
    switch(result){case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}};
}
fn usize maximum(usize a,usize b){return if(a>b){a}else{b};}
fn usize fixed(u32 mode){
    return switch(memory::fixed(if(mode==3){2}else{mode})){
        case .ok(v):{v}case .err(_):{assert(false);0}
    };
}
fn engine::Limits count_limits(){return engine::Limits{.programs=3,.instances=3,.fuel=16000000};}
fn usize control(){return id(engine::required_control_bytes(count_limits()));}
fn Result<engine::Engine,engine::Error> created(memory::Limits limits,usize work){
    return engine::create_with_compilation(count_limits(),control(),limits,work);
}
fn void clean(){assert(unsafe{probe_live()}==0 && unsafe{probe_live_bytes()}==0);}
fn void physical(usize blocks,usize bytes){
    assert(unsafe{probe_live()}==blocks && unsafe{probe_live_bytes()}==bytes);
}
fn usize epoch(ref engine::Engine e){return unsafe{bc_runtime_engine_test_compile_epoch(e as ptr void)};}
fn usize next(ref engine::Engine e){return unsafe{bc_runtime_engine_test_compile_next(e as ptr void)};}
fn void counters(ref engine::Engine e,usize admission,usize object){
    assert(epoch(e)==admission && next(e)==object);
}
fn void counts(ref mut engine::Engine e,usize programs,usize instances,usize pins){
    switch(engine::inspect(e)){
        case .ok(v):{assert(v.programs==programs && v.instances==instances && v.pins==pins && !v.closed);}
        case .err(_):{assert(false);}
    };
}
fn void ready(ref mut engine::Engine e,usize instance){
    switch(engine::observe(e,instance)){
        case .ok(v):{assert(v.kind==0 && v.remaining==123 && v.fuel_known);}
        case .err(_):{assert(false);}
    };
}
fn void ledger(ref engine::Engine e,usize work_limit,usize live,usize retained_peak,
    usize work_peak,usize tracked_peak,bool closed){
    switch(engine::program_memory(e)){
        case .ok(v):{
            let usize backing=if(closed){0}else{control()};
            assert(v.control_bytes==backing && v.program_bytes==live && v.program_peak==retained_peak);
            assert(v.working_limit==work_limit && v.working_peak==work_peak);
            assert(v.tracked_bytes==backing+live && v.tracked_peak==tracked_peak && v.closed==closed);
            assert(v.tracked_peak<=v.engine_limit && v.program_peak<=v.programs_limit);
        }
        case .err(_):{assert(false);}
    };
}
fn ref u8[] plain(u32 mode){
    if(mode==1 || mode==3){return b"module app;pub fn i32 chosen(ref u8[] data){return 42;}";}
    return b"module app;pub fn i32 chosen(){return 42;}";
}
fn ref u8[] source(u32 mode,bool malformed){
    // Conditional values exercise all three compiler scratch kinds. The reused
    // cells retain legacy list scratch; the literal forces persistent Image.
    if(malformed){
        if(mode==1 || mode==3){return b"module app;pub fn i32 chosen(ref u8[] data){let i32 x=if(true){21}else{0};let a=[x,x,x,x,x,x,x,x,x];return missing;}";}
        return b"module app;pub fn i32 chosen(){let i32 x=if(true){21}else{0};let a=[x,x,x,x,x,x,x,x,x];return missing;}";
    }
    if(mode==1){return b"module app;pub fn i32 chosen(ref u8[] data){let ref u8[] marker=b\"*\";let i32 x=if(true){21}else{0};let a=[x,x,x,x,x,x,x,x,x];return a[0]+a[8];}";}
    if(mode==3){return b"module app;pub fn i32 chosen(ref u8[] data){let ref u8[] marker=b\"*\";let i32 x=if(true){21}else{0};let a=[x,x,x,x,x,x,x,x,x];output::emit(ref marker);return a[0]+a[8];}";}
    if(mode==2){return b"module app;pub fn i32 chosen(){let ref u8[] marker=b\"*\";let i32 x=if(true){21}else{0};let a=[x,x,x,x,x,x,x,x,x];output::emit(ref marker);return a[0]+a[8];}";}
    return b"module app;pub fn i32 chosen(){let ref u8[] marker=b\"*\";let i32 x=if(true){21}else{0};let a=[x,x,x,x,x,x,x,x,x];return a[0]+a[8];}";
}
fn usize required(u32 mode){
    if(mode==1 || mode==3){
        let input_entries::InputEntry entry=switch(selected_input(plain(mode))){
            case .ok(v):{v}case .err(_):{assert(false);return 0;}
        };
        return id(engine::required_input_compile_bytes(ref entry));
    }
    let entries::Entry entry=switch(selected(plain(mode))){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}
    };
    return id(engine::required_compile_bytes(ref entry));
}
// Selection allocates before the measurement/injection. Each owning selection
// Result is switched once. Both compile routes consume Entry exactly once.
fn Result<usize,engine::Error> attempt(ref mut engine::Engine e,u32 mode,ref u8[] text,i64 fault){
    if(mode==1 || mode==3){
        let input_entries::InputEntry entry=switch(selected_input(text)){
            case .ok(v):{v}case .err(_):{assert(false);return .ok(0);}
        };
        unsafe{probe_rebase()};unsafe{bc_runtime_engine_test_fail(fault)};
        let Result<usize,engine::Error> result=if(mode==1){engine::compile_input(e,entry,65536)}else{engine::compile_input_output(e,entry,65536)};
        unsafe{bc_runtime_engine_test_fail(-1)};return result;
    }
    let entries::Entry entry=switch(selected(text)){
        case .ok(v):{v}case .err(_):{assert(false);return .ok(0);}
    };
    unsafe{probe_rebase()};unsafe{bc_runtime_engine_test_fail(fault)};
    let Result<usize,engine::Error> result=if(mode==0){engine::compile(e,entry,65536)}else{engine::compile_output(e,entry,65536)};
    unsafe{bc_runtime_engine_test_fail(-1)};return result;
}
fn usize compiled(ref mut engine::Engine e,u32 mode){return id(attempt(e,mode,source(mode,false),-1));}
fn usize phase_peak(usize prior,usize requirement,usize retained){
    return control()+prior+requirement-bounded::working_bound()+maximum(bounded::working_bound(),retained);
}
fn void release(ref mut engine::Engine e,usize program){assert(id(engine::release_program(e,program))==program);}
fn i64 fault_at(usize ordinal){
    assert(ordinal<=64);var usize at=0;var i64 value=0;
    while(at<ordinal){at+=1;value+=1;}return value;
}

// Group 1: the requirement follows the typed selected owner, not source length.
pub fn void requirements_follow_typed_layouts_and_default_working_cap(){
    clean();let usize ordinary=required(0);let usize input=required(1);
    assert(bounded::working_bound()==66630144);
    // Eight Index slots also retain the Fuel and semantic depth words.
    assert(ordinary==66804672 && input==66805056 && input-ordinary==384);
    assert(required(2)==ordinary && required(3)==input);clean();
    {
        var engine::Engine e=switch(engine::create(count_limits())){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        ledger(ref e,268435456,0,0,0,control(),false);
        let usize blocks=unsafe{probe_live()};let usize bytes=unsafe{probe_live_bytes()};
        let usize admission=epoch(ref e);let usize object=next(ref e);
        assert(required(0)==ordinary && required(1)==input);
        physical(blocks,bytes);counters(ref e,admission,object);
        assert(id(engine::destroy(ref mut e))==0);
        ledger(ref e,268435456,0,0,0,control(),true);
    }
    clean();
}

fn void working_boundary(u32 mode,bool short){
    let usize requirement=required(mode);let usize cap=if(short){requirement-1}else{requirement};
    var engine::Engine e=switch(created(memory::defaults(),cap)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let usize blocks=unsafe{probe_live()};let usize bytes=unsafe{probe_live_bytes()};
    let usize admission=epoch(ref e);let usize object=next(ref e);
    if(short){
        rejected(attempt(ref mut e,mode,source(mode,false),0),8);
        assert(unsafe{probe_attempts()}==0);physical(blocks,bytes);
        counters(ref e,admission,object);ledger(ref e,cap,0,0,0,control(),false);
    }else{
        let usize p=compiled(ref mut e,mode);let usize retained=fixed(mode)+1;
        assert(p==object && epoch(ref e)==admission+1 && next(ref e)==object+1);
        assert(unsafe{probe_attempts()}>=5 && unsafe{probe_peak_bytes()}<=phase_peak(0,requirement,retained));
        assert(unsafe{probe_live_bytes()}==bytes+retained);
        ledger(ref e,cap,retained,retained,requirement,phase_peak(0,requirement,retained),false);
        release(ref mut e,p);physical(blocks,bytes);
    }
    assert(id(engine::destroy(ref mut e))==0);
}
pub fn void four_modes_exact_and_one_less_working_preflight(){
    clean();var u32 mode=0;while(mode<4){
        working_boundary(mode,true);clean();working_boundary(mode,false);clean();mode+=1;
    }
}

fn void combined_boundary(u32 mode,bool short){
    let usize requirement=required(mode);let usize old=fixed(0);let usize fresh=fixed(mode)+1;
    assert(fresh<=bounded::working_bound());
    let usize exact=control()+old+requirement;
    let memory::Limits limits=memory::Limits{.engine=if(short){exact-1}else{exact},
        .program=maximum(old,fresh),.programs=old+fresh};
    var engine::Engine e=switch(created(limits,268435456)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let usize p=id(attempt(ref mut e,0,plain(0),-1));
    let usize pin=id(engine::create_instance(ref mut e,p,123));assert(p==1 && pin==2);
    let usize blocks=unsafe{probe_live()};let usize bytes=unsafe{probe_live_bytes()};
    let usize admission=epoch(ref e);let usize object=next(ref e);
    if(short){
        rejected(attempt(ref mut e,mode,source(mode,false),0),8);
        assert(unsafe{probe_attempts()}==0);physical(blocks,bytes);counters(ref e,admission,object);
        ledger(ref e,268435456,old,old,required(0),phase_peak(0,required(0),old),false);
    }else{
        let usize q=compiled(ref mut e,mode);assert(q==object);
        assert(epoch(ref e)==admission+1 && next(ref e)==object+1);
        ledger(ref e,268435456,old+fresh,old+fresh,maximum(required(0),requirement),exact,false);
        release(ref mut e,q);physical(blocks,bytes);
    }
    counts(ref mut e,1,1,1);ready(ref mut e,pin);
    switch(engine::execute_once(ref mut e,pin)){
        case .ok(v):{assert(v.kind==1 && v.value==42);}case .err(_):{assert(false);}
    };
    release(ref mut e,p);assert(id(engine::destroy_instance(ref mut e,pin))==pin);
    assert(id(engine::destroy(ref mut e))==0);
}
pub fn void combined_exact_and_one_less_preserve_peer_program_and_pin(){
    clean();var u32 mode=0;while(mode<4){
        combined_boundary(mode,true);clean();combined_boundary(mode,false);clean();mode+=1;
    }
}

fn void source_failure(u32 mode){
    let usize requirement=required(mode);let usize old=fixed(0);let usize fresh=fixed(mode)+1;
    var engine::Engine e=switch(created(memory::defaults(),268435456)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let usize p=id(attempt(ref mut e,0,plain(0),-1));let usize pin=id(engine::create_instance(ref mut e,p,123));
    let usize blocks=unsafe{probe_live()};let usize bytes=unsafe{probe_live_bytes()};
    let usize admission=epoch(ref e);let usize object=next(ref e);
    switch(attempt(ref mut e,mode,source(mode,true),-1)){
        case .ok(_):{assert(false);}
        case .err(v):{assert(v.status==4 && v.diagnostic.code.kind==3 && v.diagnostic.at.source==0);}
    };
    assert(unsafe{probe_attempts()}>=3);physical(blocks,bytes);
    assert(epoch(ref e)==admission+1 && next(ref e)==object);
    let usize work_peak=maximum(required(0),requirement);
    let usize tracked=maximum(phase_peak(0,required(0),old),control()+old+requirement);
    ledger(ref e,268435456,old,old,work_peak,tracked,false);
    counts(ref mut e,1,1,1);ready(ref mut e,pin);
    let usize q=compiled(ref mut e,mode);assert(q==object);
    ledger(ref e,268435456,old+fresh,old+fresh,work_peak,
        maximum(tracked,phase_peak(old,requirement,fresh)),false);
    release(ref mut e,q);release(ref mut e,p);
    assert(id(engine::destroy_instance(ref mut e,pin))==pin);assert(id(engine::destroy(ref mut e))==0);
}
pub fn void source_failure_releases_scratch_and_preserves_reservation_peak(){
    clean();var u32 mode=0;while(mode<4){source_failure(mode);clean();mode+=1;}
}

fn void oom_mode(u32 mode){
    let usize requirement=required(mode);let usize old=fixed(0);let usize fresh=fixed(mode)+1;
    var engine::Engine e=switch(created(memory::defaults(),268435456)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let usize p=id(attempt(ref mut e,0,plain(0),-1));let usize pin=id(engine::create_instance(ref mut e,p,123));
    // Calibrate the real wrapper+scratch+Image+Stored+outer-handle sequence.
    let usize calibration=compiled(ref mut e,mode);let usize allocations=unsafe{probe_attempts()};
    assert(allocations>=5 && allocations<=64);release(ref mut e,calibration);
    let usize blocks=unsafe{probe_live()};let usize bytes=unsafe{probe_live_bytes()};
    let usize work_peak=maximum(required(0),requirement);
    let usize tracked=maximum(phase_peak(0,required(0),old),phase_peak(old,requirement,fresh));
    var usize ordinal=0;while(ordinal<allocations){
        let usize admission=epoch(ref e);let usize object=next(ref e);
        rejected(attempt(ref mut e,mode,source(mode,false),fault_at(ordinal)),6);
        assert(unsafe{probe_attempts()}==ordinal+1);physical(blocks,bytes);
        counters(ref e,if(ordinal==0){admission}else{admission+1},object);
        ledger(ref e,268435456,old,old+fresh,work_peak,tracked,false);
        counts(ref mut e,1,1,1);ready(ref mut e,pin);ordinal+=1;
    }
    let usize object=next(ref e);let usize q=compiled(ref mut e,mode);assert(q==object);
    ledger(ref e,268435456,old+fresh,old+fresh,work_peak,tracked,false);
    release(ref mut e,q);release(ref mut e,p);
    assert(id(engine::destroy_instance(ref mut e,pin))==pin);assert(id(engine::destroy(ref mut e))==0);
}
// Fresh owners prove failed admitted retention itself raises program_peak; the
// sweep above separately proves every actual allocation ordinal and peer safety.
fn usize image_ordinal(u32 mode,ref u8[] text){
    var engine::Engine sample=switch(created(memory::defaults(),268435456)){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}};
    let usize p=id(attempt(ref mut sample,mode,text,-1));let usize ordinal=unsafe{probe_retention_start()};
    assert(ordinal>0 && ordinal<64);release(ref mut sample,p);assert(id(engine::destroy(ref mut sample))==0);return ordinal;
}
fn void admitted_oom_peak(u32 mode){
    let usize requirement=required(mode);let usize fresh=fixed(mode)+1;
    var engine::Engine e=switch(created(memory::defaults(),268435456)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    // Calibrate the actual admission boundary; compiler scratch precedes Image.
    let ref u8[] text=if(mode==1 || mode==3){
        b"module app;pub fn i32 chosen(ref u8[] data){let ref u8[] marker=b\"*\";return 42;}"
    }else{b"module app;pub fn i32 chosen(){let ref u8[] marker=b\"*\";return 42;}"};
    let usize image=image_ordinal(mode,text);
    let usize blocks=unsafe{probe_live()};let usize bytes=unsafe{probe_live_bytes()};
    let usize admission=epoch(ref e);let usize object=next(ref e);
    rejected(attempt(ref mut e,mode,text,0),6);
    assert(unsafe{probe_attempts()}==1);physical(blocks,bytes);counters(ref e,admission,object);
    ledger(ref e,268435456,0,0,requirement,control()+requirement,false);
    rejected(attempt(ref mut e,mode,text,fault_at(image)),6);
    assert(unsafe{probe_attempts()}==image+1);physical(blocks,bytes);counters(ref e,admission+1,object);
    ledger(ref e,268435456,0,fresh,requirement,phase_peak(0,requirement,fresh),false);
    let usize q=id(attempt(ref mut e,mode,text,-1));assert(q==object);
    release(ref mut e,q);assert(id(engine::destroy(ref mut e))==0);
}
pub fn void allocator_failures_release_owners_preserve_peaks_and_recover(){
    clean();var u32 mode=0;while(mode<4){
        admitted_oom_peak(mode);clean();oom_mode(mode);clean();mode+=1;
    }
}

fn void closed_move(){
    let usize requirement=required(0);let usize retained=fixed(0)+1;
    var engine::Engine original=switch(created(memory::defaults(),requirement)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let usize p=compiled(ref mut original,0);let usize pin=id(engine::create_instance(ref mut original,p,123));
    release(ref mut original,p);var engine::Engine e=original;
    let usize tracked=phase_peak(0,requirement,retained);
    ledger(ref e,requirement,retained,retained,requirement,tracked,false);ready(ref mut e,pin);
    assert(id(engine::destroy_instance(ref mut e,pin))==pin);assert(id(engine::destroy(ref mut e))==0);
    var engine::Engine moved=e;
    let usize admission=epoch(ref moved);let usize object=next(ref moved);
    var u32 mode=0;while(mode<4){
        rejected(attempt(ref mut moved,mode,source(mode,false),0),2);
        assert(unsafe{probe_attempts()}==0);counters(ref moved,admission,object);clean();mode+=1;
    }
    unsafe{probe_rebase()};unsafe{bc_runtime_engine_test_fail(0)};
    ledger(ref moved,requirement,0,retained,requirement,tracked,true);
    ledger(ref moved,requirement,0,retained,requirement,tracked,true);
    assert(unsafe{probe_attempts()}==0);unsafe{bc_runtime_engine_test_fail(-1)};
}
fn void exhausted_preflight(){
    var engine::Engine e=switch(created(memory::defaults(),268435456)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    // Existing fixture sets the last usable admission; inspect consumes it.
    unsafe{bc_runtime_engine_test_seed(ref mut e as ptr mut void,2)};counts(ref mut e,0,0,0);
    assert(epoch(ref e)==0);let usize object=next(ref e);
    let usize blocks=unsafe{probe_live()};let usize bytes=unsafe{probe_live_bytes()};
    rejected(attempt(ref mut e,3,source(3,false),0),8);
    assert(unsafe{probe_attempts()}==0);physical(blocks,bytes);counters(ref e,0,object);
    ledger(ref e,268435456,0,0,0,control(),false);assert(id(engine::destroy(ref mut e))==0);
}
pub fn void moved_closed_and_exhausted_owners_keep_observations_without_allocation(){
    clean();closed_move();clean();exhausted_preflight();clean();
}

fn void append(ref mut bytes::Buffer text,ref u8[] fragment){assert(bytes::append(text,fragment).is_ok);}
fn void engine_depth(usize depth,bool pass){
    var bytes::Buffer text=bytes::empty();
    append(ref mut text,b"module app;fn i32 id(i32 x,i32[1] a){return x;}pub fn i32 chosen(){let i32[1] a=[0;1];let ref u8[] marker=b\"*\";return ");
    var usize i=0;while(i<depth){append(ref mut text,b"id(");i+=1;}
    append(ref mut text,b"42");i=0;while(i<depth){append(ref mut text,b",a)");i+=1;}append(ref mut text,b";}");
    var engine::Engine e=switch(created(memory::defaults(),268435456)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    switch(attempt(ref mut e,0,bytes::view(ref text),-1)){
        case .ok(p):{
            assert(pass);let usize instance=id(engine::create_instance(ref mut e,p,16000000));
            switch(engine::execute_once(ref mut e,instance)){
                case .ok(v):{assert(v.kind==1 && v.value==42);}case .err(_):{assert(false);}
            };
            assert(id(engine::destroy_instance(ref mut e,instance))==instance);release(ref mut e,p);
        }
        case .err(error):{assert(!pass && error.status==4 && error.diagnostic.code.kind==4);}
    };
    assert(id(engine::destroy(ref mut e))==0);
}
pub fn void engine_keeps_captured_call_depth32_and_rejects33(){
    clean();engine_depth(32,true);clean();engine_depth(33,false);clean();
}

pub fn void run(){
    requirements_follow_typed_layouts_and_default_working_cap();
    four_modes_exact_and_one_less_working_preflight();
    combined_exact_and_one_less_preserve_peer_program_and_pin();
    source_failure_releases_scratch_and_preserves_reservation_peak();
    allocator_failures_release_owners_preserve_peaks_and_recover();
    moved_closed_and_exhausted_owners_keep_observations_without_allocation();
    engine_keeps_captured_call_depth32_and_rejects33();
}
