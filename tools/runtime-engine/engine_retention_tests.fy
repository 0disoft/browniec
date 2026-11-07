module engine_retention_tests;
import runtime_engine as engine;
import runtime_program_memory as memory;
import module_entry as entries;
import module_input_entry as input_entries;
import module_index as modules;
import source_snapshot as sources;

unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void bc_runtime_engine_test_closed_allocations();
unsafe extern C fn void bc_runtime_engine_test_program_probe();
unsafe extern C fn void bc_runtime_engine_test_program_no_retention_allocations();
unsafe extern C fn void bc_runtime_engine_test_program_storage(ptr void owner,usize ledger_bytes);

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
fn usize id(Result<usize,engine::Error> r){
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn usize fixed(u32 mode){
    return switch(memory::fixed(if(mode==3){2}else{mode})){
        case .ok(v):{v}case .err(_):{assert(false);0}
    };
}
fn engine::Limits counts_limit(){return engine::Limits{.programs=3,.instances=3,.fuel=16000000};}
fn usize control(){return id(engine::required_control_bytes(counts_limit()));}
fn memory::Limits budget(usize per,usize total){
    return memory::Limits{.engine=1073741824,.program=per,.programs=total};
}
fn Result<engine::Engine,engine::Error> created(memory::Limits limits){
    return engine::create_with_retention(counts_limit(),control(),limits);
}
fn void rejected(Result<usize,engine::Error> r,u32 status){
    switch(r){case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}};
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
fn void ledger(ref engine::Engine e,memory::Limits limits,usize live,usize peak,bool closed){
    switch(engine::program_memory(e)){
        case .ok(v):{
            let usize backing=if(closed){0}else{control()};
            assert(v.engine_limit==limits.engine && v.program_limit==limits.program && v.programs_limit==limits.programs);
            assert(v.control_bytes==backing && v.program_bytes==live && v.program_peak==peak);
            assert(v.tracked_bytes==backing+live && v.closed==closed);
            assert(v.tracked_peak>=control()+peak && v.tracked_peak<=control()+peak+v.working_peak);
        }
        case .err(_):{assert(false);}
    };
}
fn void storage(ref engine::Engine e,usize bytes){
    // Entry construction/transport has returned; no input or Output owner exists.
    unsafe{bc_runtime_engine_test_program_storage(e as ptr void,bytes)};
}
fn ref u8[] empty_source(u32 mode){
    if(mode==1 || mode==3){return b"module app;pub fn i32 chosen(ref u8[] data){return 42;}";}
    return b"module app;pub fn i32 chosen(){return 42;}";
}
fn ref u8[] literal_source(u32 mode){
    // Decoded binary bytes 00 FF 2A occur twice with different spellings.
    // One distinct two-byte literal plus empty = 3+2+0, NOT 3+3+2.
    if(mode==0){return b"module app;pub fn i32 chosen(){let ref u8[] a=b\"\\x00\\xFF*\";let ref u8[] b=b\"\\x00\\xFF\\x2A\";let ref u8[] c=b\"xy\";let ref u8[] d=b\"\";if(a.len+b.len+c.len+d.len==8){return 42;}return 0;}";}
    if(mode==1){return b"module app;pub fn i32 chosen(ref u8[] data){let ref u8[] a=b\"\\x00\\xFF*\";let ref u8[] b=b\"\\x00\\xFF\\x2A\";let ref u8[] c=b\"xy\";let ref u8[] d=b\"\";if(a.len+b.len+c.len+d.len==8){return 42;}return 0;}";}
    if(mode==2){return b"module app;pub fn i32 chosen(){output::emit(ref b\"\\x00\\xFF*\");output::emit(ref b\"\\x00\\xFF\\x2A\");output::emit(ref b\"xy\");output::emit(ref b\"\");return 42;}";}
    return b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"\\x00\\xFF*\");output::emit(ref b\"\\x00\\xFF\\x2A\");output::emit(ref b\"xy\");output::emit(ref b\"\");return 42;}";
}
fn ref u8[] malformed_source(u32 mode){
    if(mode==1 || mode==3){return b"module app;pub fn i32 chosen(ref u8[] data){return missing;}";}
    return b"module app;pub fn i32 chosen(){return missing;}";
}
// Prepare selection BEFORE arming failure/probe. Always restore the allocator
// before returning, even when the Engine wrapper itself cannot allocate.
fn Result<usize,engine::Error> attempt(ref mut engine::Engine e,u32 mode,ref u8[] source,i64 fault,bool probe){
    if(mode==1 || mode==3){
        let input_entries::InputEntry entry=switch(selected_input(source)){
            case .ok(v):{v}case .err(_):{assert(false);return .ok(0);}
        };
        if(probe){unsafe{bc_runtime_engine_test_program_probe()};}
        unsafe{bc_runtime_engine_test_fail(fault)};
        let Result<usize,engine::Error> r=if(mode==1){engine::compile_input(e,entry,65536)}else{engine::compile_input_output(e,entry,65536)};
        unsafe{bc_runtime_engine_test_fail(-1)};return r;
    }
    let entries::Entry entry=switch(selected(source)){
        case .ok(v):{v}case .err(_):{assert(false);return .ok(0);}
    };
    if(probe){unsafe{bc_runtime_engine_test_program_probe()};}
    unsafe{bc_runtime_engine_test_fail(fault)};
    let Result<usize,engine::Error> r=if(mode==0){engine::compile(e,entry,65536)}else{engine::compile_output(e,entry,65536)};
    unsafe{bc_runtime_engine_test_fail(-1)};return r;
}
fn usize compile(ref mut engine::Engine e,u32 mode,bool literals){
    return id(attempt(e,mode,if(literals){literal_source(mode)}else{empty_source(mode)},-1,false));
}
fn void close(ref mut engine::Engine e,memory::Limits limits,usize peak){
    counts(e,0,0,0);ledger(e,limits,0,peak,false);storage(e,0);
    assert(id(engine::destroy(e))==0);ledger(e,limits,0,peak,true);
}

// Group 1: actual Engine retention for all four compilers, empty image and
// decoded/deduplicated payload. Fixed already includes StoredVec8+HandleVec8.
fn void exact_mode(u32 mode){
    let usize base=fixed(mode);let usize bytes=base+5;
    let memory::Limits limits=budget(bytes,bytes);
    var engine::Engine e=switch(created(limits)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    ledger(ref e,limits,0,0,false);storage(ref e,0);
    let usize a=compile(ref mut e,mode,false);assert(a==1);
    ledger(ref e,limits,base,base,false);storage(ref e,base);
    assert(id(engine::release_program(ref mut e,a))==a);
    let usize b=compile(ref mut e,mode,true);assert(b==2);
    ledger(ref e,limits,bytes,bytes,false);storage(ref e,bytes);
    assert(id(engine::release_program(ref mut e,b))==b);close(ref mut e,limits,bytes);
}
fn void exact_four_modes(){var u32 mode=0;while(mode<4){exact_mode(mode);unsafe{bc_runtime_engine_test_closed_allocations()};mode+=1;}}

// Group 2: one byte short returns quota8 with only wrapper allocation. Exact
// admission reaches the image OOM6; reservation peak survives that rollback.
fn void per_program_boundary(u32 mode,bool short){
    let usize bytes=fixed(mode)+5;let usize per=if(short){bytes-1}else{bytes};
    let memory::Limits limits=budget(per,bytes*2);
    var engine::Engine e=switch(created(limits)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    rejected(attempt(ref mut e,mode,literal_source(mode),1,true),if(short){8}else{6});
    if(short){unsafe{bc_runtime_engine_test_program_no_retention_allocations()};}
    let usize peak=if(short){0}else{bytes};
    counts(ref mut e,0,0,0);ledger(ref e,limits,0,peak,false);storage(ref e,0);
    let usize p=compile(ref mut e,mode,!short);assert(p==1);
    let usize actual=if(short){fixed(mode)}else{bytes};
    ledger(ref e,limits,actual,actual,false);storage(ref e,actual);
    assert(id(engine::release_program(ref mut e,p))==p);close(ref mut e,limits,actual);
}
fn void per_program_exact_and_short(){
    var u32 mode=0;while(mode<4){
        per_program_boundary(mode,true);unsafe{bc_runtime_engine_test_closed_allocations()};
        per_program_boundary(mode,false);unsafe{bc_runtime_engine_test_closed_allocations()};mode+=1;
    }
}

// Groups 3/4: retained bytes and full incoming compilation reach total-program
// and combined-control
// boundaries independently. Three slots prevent count quota masking byte quota.
fn usize input_work_requirement(){
    let input_entries::InputEntry entry=switch(selected_input(literal_source(1))){
        case .ok(v):{v}case .err(_):{assert(false);return 0;}
    };
    return id(engine::required_input_compile_bytes(ref entry));
}
fn void aggregate_boundary(bool combined,bool short){
    let usize old=fixed(0)+5;let usize fresh=fixed(1)+5;let usize sum=old+fresh;
    let usize full=if(combined){old+input_work_requirement()}else{sum};
    let usize cap=if(short){full-1}else{full};
    let usize per=if(old>fresh){old}else{fresh};
    let memory::Limits limits=memory::Limits{.engine=if(combined){control()+cap}else{1073741824},.program=per,.programs=if(combined){sum}else{cap}};
    var engine::Engine e=switch(created(limits)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize a=compile(ref mut e,0,true);assert(a==1);
    if(short){
        rejected(attempt(ref mut e,1,literal_source(1),1,true),8);
        if(combined){assert(unsafe{probe_attempts()}==0);}else{unsafe{bc_runtime_engine_test_program_no_retention_allocations()};}
        counts(ref mut e,1,0,0);ledger(ref e,limits,old,old,false);storage(ref e,old);
        assert(id(engine::release_program(ref mut e,a))==a);
        let usize b=compile(ref mut e,1,true);assert(b==2);
        let usize peak=if(old>fresh){old}else{fresh};
        ledger(ref e,limits,fresh,peak,false);storage(ref e,fresh);
        assert(id(engine::release_program(ref mut e,b))==b);close(ref mut e,limits,peak);
    }else{
        let usize b=compile(ref mut e,1,true);assert(b==2);
        ledger(ref e,limits,sum,sum,false);storage(ref e,sum);
        assert(id(engine::release_program(ref mut e,a))==a);
        ledger(ref e,limits,fresh,sum,false);storage(ref e,fresh);
        assert(id(engine::release_program(ref mut e,b))==b);close(ref mut e,limits,sum);
    }
}
fn void total_program_budget(){
    aggregate_boundary(false,true);unsafe{bc_runtime_engine_test_closed_allocations()};
    aggregate_boundary(false,false);unsafe{bc_runtime_engine_test_closed_allocations()};
}
fn void combined_budget(){
    aggregate_boundary(true,true);unsafe{bc_runtime_engine_test_closed_allocations()};
    aggregate_boundary(true,false);unsafe{bc_runtime_engine_test_closed_allocations()};
}

// Group 5: release does not refund either pin. Move the owner, remove a middle
// Program and front Instance, then reclaim only on the final pin destruction.
fn void pins_move_and_peers(){
    let memory::Limits limits=memory::defaults();
    var engine::Engine original=switch(created(limits)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize p=compile(ref mut original,0,true);let usize q=compile(ref mut original,1,true);
    let usize r=compile(ref mut original,0,false);
    let usize a=id(engine::create_instance(ref mut original,p,123));
    let usize b=id(engine::create_instance(ref mut original,p,123));
    let usize c=id(engine::create_instance(ref mut original,r,123));
    let usize pb=fixed(0)+5;let usize qb=fixed(1)+5;let usize rb=fixed(0);let usize peak=pb+qb+rb;
    assert(id(engine::release_program(ref mut original,p))==p);
    rejected(engine::create_instance(ref mut original,p,123),2);
    ledger(ref original,limits,peak,peak,false);storage(ref original,peak);
    var engine::Engine e=original;counts(ref mut e,3,3,3);
    assert(id(engine::release_program(ref mut e,q))==q);
    ledger(ref e,limits,pb+rb,peak,false);storage(ref e,pb+rb);
    assert(id(engine::destroy_instance(ref mut e,a))==a);counts(ref mut e,2,2,2);
    ledger(ref e,limits,pb+rb,peak,false);ready(ref mut e,b);ready(ref mut e,c);
    assert(id(engine::destroy_instance(ref mut e,b))==b);counts(ref mut e,1,1,1);
    ledger(ref e,limits,rb,peak,false);storage(ref e,rb);ready(ref mut e,c);
    switch(engine::execute_once(ref mut e,c)){
        case .ok(v):{assert(v.kind==1 && v.value==42);}case .err(_):{assert(false);}
    };
    assert(id(engine::release_program(ref mut e,r))==r);ledger(ref e,limits,rb,peak,false);
    assert(id(engine::destroy_instance(ref mut e,c))==c);
    rejected(engine::release_program(ref mut e,p),2);rejected(engine::destroy_instance(ref mut e,b),2);
    let usize next=compile(ref mut e,0,false);assert(p==1 && q==2 && r==3 && a==4 && b==5 && c==6 && next==7);
    assert(id(engine::release_program(ref mut e,next))==next);close(ref mut e,limits,peak);
}

// Group 6: valid signature/index but malformed body reaches real sourcefailure4
// in every mode, without consuming IDs, changing a ready pin or recording a plan.
fn void malformed_mode(u32 mode){
    let memory::Limits limits=memory::defaults();
    var engine::Engine e=switch(created(limits)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize old=compile(ref mut e,0,false);let usize pin=id(engine::create_instance(ref mut e,old,123));
    switch(attempt(ref mut e,mode,malformed_source(mode),1,true)){
        case .ok(_):{assert(false);}
        case .err(v):{assert(v.status==4 && v.diagnostic.code.kind!=0 && v.diagnostic.at.source==0);}
    };
    unsafe{bc_runtime_engine_test_program_no_retention_allocations()};
    counts(ref mut e,1,1,1);ready(ref mut e,pin);ledger(ref e,limits,fixed(0),fixed(0),false);storage(ref e,fixed(0));
    let usize next=compile(ref mut e,mode,true);assert(old==1 && pin==2 && next==3);
    let usize peak=fixed(0)+fixed(mode)+5;ledger(ref e,limits,peak,peak,false);
    assert(id(engine::release_program(ref mut e,next))==next);
    assert(id(engine::release_program(ref mut e,old))==old);
    assert(id(engine::destroy_instance(ref mut e,pin))==pin);close(ref mut e,limits,peak);
}
fn void malformed_rollback(){var u32 mode=0;while(mode<4){malformed_mode(mode);unsafe{bc_runtime_engine_test_closed_allocations()};mode+=1;}}

// Group 7: wrapper, Image, StoredVec8 and outer HandleVec8 OOM seams. Each
// rollback preserves old storage/ready pin; admitted failures still raise peak.
fn void oom_mode(u32 mode){
    let memory::Limits limits=memory::defaults();
    var engine::Engine e=switch(created(limits)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize old=compile(ref mut e,0,false);let usize pin=id(engine::create_instance(ref mut e,old,123));
    let usize planned=fixed(0)+fixed(mode)+5;
    var i64 seam=0;while(seam<4){
        rejected(attempt(ref mut e,mode,literal_source(mode),seam,true),6);
        counts(ref mut e,1,1,1);ready(ref mut e,pin);
        ledger(ref e,limits,fixed(0),if(seam==0){fixed(0)}else{planned},false);storage(ref e,fixed(0));seam+=1;
    }
    let usize next=compile(ref mut e,mode,true);assert(old==1 && pin==2 && next==3);
    counts(ref mut e,2,1,1);ledger(ref e,limits,planned,planned,false);storage(ref e,planned);
    assert(id(engine::release_program(ref mut e,next))==next);
    assert(id(engine::release_program(ref mut e,old))==old);
    assert(id(engine::destroy_instance(ref mut e,pin))==pin);close(ref mut e,limits,planned);
}
fn void oom_rollback(){var u32 mode=0;while(mode<4){oom_mode(mode);unsafe{bc_runtime_engine_test_closed_allocations()};mode+=1;}}

// Group 8: implicit teardown drains released pins and live peer storage. Closed
// owner queries succeed without allocation, retain limits/peak, and survive move.
fn void implicit_cleanup(){
    let memory::Limits limits=memory::defaults();
    var engine::Engine e=switch(created(limits)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize p=compile(ref mut e,0,true);let usize q=compile(ref mut e,1,true);
    let usize pin=id(engine::create_instance(ref mut e,p,123));
    assert(id(engine::release_program(ref mut e,p))==p);counts(ref mut e,2,1,1);ready(ref mut e,pin);
    let usize bytes=fixed(0)+fixed(1)+10;ledger(ref e,limits,bytes,bytes,false);storage(ref e,bytes);
    // Intentionally leave both Programs and the released pin owned by e.
}
fn void closed_owner_query(){
    let usize bytes=fixed(2)+5;let memory::Limits limits=budget(bytes,bytes);
    var engine::Engine e=switch(created(limits)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize p=compile(ref mut e,2,true);assert(id(engine::release_program(ref mut e,p))==p);
    close(ref mut e,limits,bytes);
    let engine::Engine moved=e;
    unsafe{bc_runtime_engine_test_fail(0)};
    ledger(ref moved,limits,0,bytes,true);ledger(ref moved,limits,0,bytes,true);
    unsafe{bc_runtime_engine_test_fail(-1)};
}
fn void cleanup_and_closed_query(){
    implicit_cleanup();unsafe{bc_runtime_engine_test_closed_allocations()};
    closed_owner_query();unsafe{bc_runtime_engine_test_closed_allocations()};
}

pub fn void run(){
    exact_four_modes();unsafe{bc_runtime_engine_test_closed_allocations()};
    per_program_exact_and_short();unsafe{bc_runtime_engine_test_closed_allocations()};
    total_program_budget();unsafe{bc_runtime_engine_test_closed_allocations()};
    combined_budget();unsafe{bc_runtime_engine_test_closed_allocations()};
    pins_move_and_peers();unsafe{bc_runtime_engine_test_closed_allocations()};
    malformed_rollback();unsafe{bc_runtime_engine_test_closed_allocations()};
    oom_rollback();unsafe{bc_runtime_engine_test_closed_allocations()};
    cleanup_and_closed_query();unsafe{bc_runtime_engine_test_closed_allocations()};
}
