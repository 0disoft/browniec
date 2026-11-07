module tests::m2::module_output_memory;
import module_output_program as programs;
import module_entry as entries;
import module_input_entry as input_entries;
import module_index as modules;
import source_snapshot as sources;
import runtime_input as inputs;
import runtime_output as output;
import fuel as meter;
import std::bytes as bytes;

// Native-ready tests. Link the existing runtime-engine/heap-observer.c so
// physical deltas exclude allocator headers and include every SDK allocation.
// All owners are constructed through their real APIs, never private fields.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void probe_rebase();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);

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
fn Result<programs::Program,u8> kept(ref u8[] source,bool input){
    let modules::Index index=indexed(source)?;
    if(input){
        let input_entries::InputEntry entry=switch(input_entries::select_i32_input(index,b"app",b"chosen")){
            case .ok(v):{v}case .err(_):{return .err(5);}
        };
        return switch(programs::compile_input(entry,65536)){case .ok(v):{.ok(v)}case .err(_):{.err(6)}};
    }
    let entries::Entry entry=switch(entries::select_i32(index,b"app",b"chosen")){
        case .ok(v):{v}case .err(_):{return .err(7);}
    };
    return switch(programs::compile(entry,65536)){case .ok(v):{.ok(v)}case .err(_):{.err(8)}};
}
fn Result<inputs::Snapshot,u8> captured(ref u8[] data){
    var usize fuel=0;
    return switch(inputs::snapshot(data,inputs::hard_limit(),0,ref mut fuel)){
        case .ok(v):{.ok(v)}case .err(_):{.err(9)}
    };
}
fn void physical(usize blocks,usize size){
    assert(unsafe{probe_live()}==blocks && unsafe{probe_live_bytes()}==size);
}
fn void failed(ref programs::Execution run,u8 kind){
    let programs::Completion c=programs::observe(run);
    assert(!c.success && c.value==0 && c.diagnostic.code.kind==kind);
    assert(c.output_bytes==0 && !programs::has_output(run) && programs::view(run).len==0);
}
fn void success(ref programs::Execution run,ref u8[] expected,usize emits){
    let programs::Completion c=programs::observe(run);
    assert(c.success && c.value==42 && c.diagnostic.code.kind==0);
    assert(c.output_bytes==expected.len && c.emits==emits && programs::has_output(run));
    assert(bytes::equal(programs::view(run),expected));
}
// Repeated observation must allocate nothing even when every allocation fails.
fn void execution_heap(ref programs::Execution run,usize expected){
    let usize blocks=unsafe{probe_live()};let usize size=unsafe{probe_live_bytes()};
    let usize attempts=unsafe{probe_attempts()};let programs::Completion before=programs::observe(run);
    unsafe{bc_runtime_engine_test_fail(0)};
    let usize first=programs::heap_bytes(run);let usize second=programs::heap_bytes(run);
    unsafe{bc_runtime_engine_test_fail(-1)};
    assert(first==expected && second==expected && unsafe{probe_attempts()}==attempts);
    physical(blocks,size);let programs::Completion after=programs::observe(run);
    assert(after.success==before.success && after.remaining==before.remaining);
    assert(after.output_bytes==before.output_bytes && after.emits==before.emits);
}

@test
fn void early_limit_input_and_prepare_fuel_failures_retain_zero_heap(){
    let programs::Program p=switch(kept(b"module app;pub fn i32 chosen(){return 42;}",false)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot empty=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let inputs::Snapshot wrong=switch(captured(b"!")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize blocks=unsafe{probe_live()};let usize size=unsafe{probe_live_bytes()};
    unsafe{probe_rebase()};
    let programs::Execution limit=programs::complete(ref p,ref empty,16000000,output::hard_limit()+1,true);
    failed(ref limit,20);execution_heap(ref limit,0);physical(blocks,size);
    let programs::Execution input=programs::complete(ref p,ref wrong,16000000,64,true);
    failed(ref input,5);execution_heap(ref input,0);physical(blocks,size);
    let usize fuel=meter::output_prepare(64)-1;
    let programs::Execution starved=programs::complete(ref p,ref empty,fuel,64,true);
    failed(ref starved,8);assert(programs::observe(ref starved).remaining==fuel);
    execution_heap(ref starved,0);physical(blocks,size);assert(unsafe{probe_attempts()}==0);
}

@test
fn void result_reserve_header_and_backing_oom_release_every_prepared_owner(){
    let programs::Program p=switch(kept(b"module app;pub fn i32 chosen(){return 42;}",false)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize blocks=unsafe{probe_live()};let usize size=unsafe{probe_live_bytes()};
    var i64 fault=0;var usize attempts=1;
    while(fault<3){
        // The first three allocations are Published Vec8, fixed header, backing.
        unsafe{probe_rebase()};unsafe{bc_runtime_engine_test_fail(fault)};
        let programs::Execution run=programs::complete(ref p,ref input,16000000,64,true);
        unsafe{bc_runtime_engine_test_fail(-1)};
        failed(ref run,15);assert(programs::observe(ref run).remaining==16000000);
        assert(unsafe{probe_attempts()}==attempts);execution_heap(ref run,0);physical(blocks,size);
        fault+=1;attempts+=1;
    }
    {
        let programs::Execution retry=programs::complete(ref p,ref input,16000000,64,true);
        success(ref retry,b"",0);execution_heap(ref retry,576+64);physical(blocks+2,size+576+64);
    }
    physical(blocks,size);
}

@test
fn void late_vm_and_seal_failures_keep_empty_vec8_capacity_without_payload(){
    let programs::Program bad=switch(kept(
        b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"prefix\");return 42/(data[0] as i32);}",true)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let programs::Program p=switch(kept(
        b"module app;pub fn i32 chosen(){output::emit(ref b\"A\\x00B\");return 42;}",false)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot zero=switch(captured(b"\x00")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let inputs::Snapshot empty=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var usize price=0;
    {
        let programs::Execution full=programs::complete(ref p,ref empty,16000000,64,true);
        success(ref full,b"A\x00B",1);price=16000000-programs::observe(ref full).remaining;
    }
    assert(price>meter::output_seal());
    let usize blocks=unsafe{probe_live()};let usize size=unsafe{probe_live_bytes()};
    {
        let programs::Execution vm=programs::complete(ref bad,ref zero,16000000,64,true);
        failed(ref vm,7);assert(programs::observe(ref vm).emits==1);
        execution_heap(ref vm,576);physical(blocks+1,size+576);
    }
    physical(blocks,size);
    {
        let programs::Execution denied=programs::complete(ref p,ref empty,16000000,64,false);
        failed(ref denied,19);execution_heap(ref denied,576);physical(blocks+1,size+576);
    }
    physical(blocks,size);
    {
        let programs::Execution short=programs::complete(ref p,ref empty,price-1,64,true);
        failed(ref short,8);assert(programs::observe(ref short).remaining==meter::output_seal()-1);
        assert(programs::observe(ref short).emits==1);execution_heap(ref short,576);physical(blocks+1,size+576);
    }
    physical(blocks,size);
}

fn void successful_case(ref programs::Program p,ref inputs::Snapshot input,usize limit,ref u8[] expected,usize emits){
    let usize blocks=unsafe{probe_live()};let usize size=unsafe{probe_live_bytes()};
    {
        let programs::Execution run=programs::complete(p,input,16000000,limit,true);
        success(ref run,expected,emits);execution_heap(ref run,576+limit);
        physical(blocks+1+if(limit==0){0}else{1},size+576+limit);
    }
    physical(blocks,size);
}
@test
fn void success_counts_reserved_backing_even_for_empty_emit_and_no_emit(){
    let programs::Program binary=switch(kept(
        b"module app;pub fn i32 chosen(){output::emit(ref b\"A\\x00B\");return 42;}",false)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let programs::Program empty=switch(kept(
        b"module app;pub fn i32 chosen(){output::emit(ref b\"\");return 42;}",false)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let programs::Program silent=switch(kept(b"module app;pub fn i32 chosen(){return 42;}",false)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    successful_case(ref binary,ref input,3,b"A\x00B",1);
    successful_case(ref binary,ref input,64,b"A\x00B",1);
    successful_case(ref empty,ref input,0,b"",1);
    successful_case(ref empty,ref input,64,b"",1);
    successful_case(ref silent,ref input,0,b"",0);
    successful_case(ref silent,ref input,64,b"",0);
}

fn Result<programs::Execution,u8> detached(bool trap){
    let programs::Program p=kept(
        b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42/(data[0] as i32);}",true)?;
    let inputs::Snapshot input=captured(if(trap){b"\x00\x00\xFF"}else{b"\x01\x00\xFF"})?;
    return .ok(programs::complete(ref p,ref input,16000000,64,true));
}
@test
fn void detached_results_move_without_allocating_and_cleanup_returns_to_baseline(){
    let usize blocks=unsafe{probe_live()};let usize size=unsafe{probe_live_bytes()};
    {
        let programs::Execution first=switch(detached(false)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        // Both the source Program and input Snapshot have already left scope.
        success(ref first,b"\x01\x00\xFF",1);execution_heap(ref first,640);physical(blocks+2,size+640);
        unsafe{probe_rebase()};let programs::Execution moved=first;
        success(ref moved,b"\x01\x00\xFF",1);execution_heap(ref moved,640);
        assert(unsafe{probe_attempts()}==0);physical(blocks+2,size+640);
        {
            let programs::Execution failure=switch(detached(true)){
                case .ok(v):{v}case .err(_):{assert(false);return;}
            };
            failed(ref failure,7);execution_heap(ref failure,576);physical(blocks+3,size+640+576);
            unsafe{probe_rebase()};let programs::Execution moved_failure=failure;
            failed(ref moved_failure,7);execution_heap(ref moved_failure,576);
            assert(unsafe{probe_attempts()}==0);success(ref moved,b"\x01\x00\xFF",1);
        }
        physical(blocks+2,size+640);
    }
    physical(blocks,size);
}

fn void transaction_heap(ref output::Transaction t,usize expected){
    let usize attempts=unsafe{probe_attempts()};let output::Observation before=output::observe(t);
    unsafe{bc_runtime_engine_test_fail(0)};
    let usize first=output::transaction_heap_bytes(t);let usize second=output::transaction_heap_bytes(t);
    unsafe{bc_runtime_engine_test_fail(-1)};
    assert(first==expected && second==expected && unsafe{probe_attempts()}==attempts);
    let output::Observation after=output::observe(t);
    assert(after.phase==before.phase && after.length==before.length && after.fuel==before.fuel);
}
@test
fn void published_and_transaction_queries_follow_seal_transfer_and_cancel_cleanup(){
    let usize blocks=unsafe{probe_live()};let usize size=unsafe{probe_live_bytes()};
    {
        let output::Transaction disabled=output::disabled();transaction_heap(ref disabled,0);physical(blocks,size);
        var usize fuel=16000000;
        var output::Transaction t=switch(output::open_metered(64,true,ref mut fuel)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        transaction_heap(ref t,40+64);physical(blocks+2,size+40+64);
        assert(output::emit_metered(ref mut t,b"",ref mut fuel).is_ok);
        {
            let output::Published published=switch(output::seal_metered(ref mut t,ref mut fuel)){
                case .ok(v):{v}case .err(_):{assert(false);return;}
            };
            assert(output::view(ref published).len==0 && output::published_observation(ref published).emits==1);
            let usize attempts=unsafe{probe_attempts()};unsafe{bc_runtime_engine_test_fail(0)};
            let usize first=output::published_heap_bytes(ref published);
            let usize second=output::published_heap_bytes(ref published);
            unsafe{bc_runtime_engine_test_fail(-1)};
            assert(first==64 && second==64 && unsafe{probe_attempts()}==attempts);
            transaction_heap(ref t,40);physical(blocks+2,size+40+64);
        }
        transaction_heap(ref t,40);physical(blocks+1,size+40);
    }
    physical(blocks,size);
    {
        var usize fuel=16000000;
        var output::Transaction t=switch(output::open_metered(64,true,ref mut fuel)){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        assert(output::cancel(ref mut t).phase==3);
        transaction_heap(ref t,40);physical(blocks+1,size+40);
    }
    physical(blocks,size);
}
