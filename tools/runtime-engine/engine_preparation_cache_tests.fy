module engine_preparation_cache_tests;
import runtime_engine as engine;
import module_output_program as programs;
import module_entry as entries;
import module_input_entry as input_entries;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import runtime_input as inputs;
import runtime_output as output;
import slice_result_machine as machine;
import slice_result_execution as execution;
import slice_result_runtime as runtime;
import slice_result_cursor as cursors;
import static_ir as statics;
import verifier as verifier;
import array_list_vm as lists;
import place_dispatch as places;
import struct_call_vm as calls;
import call_capture_plan as capture_plans;
import runtime_execution_memory as execution_heap;
import std::bytes as bytes;

// The parent owns native instrumentation and runner integration. Count actual
// verifier::inspect_output_returns entries, including independent test oracles;
// planner scans are deliberately outside this counter's claim.
unsafe extern C fn void bc_runtime_engine_test_proof_begin();
unsafe extern C fn usize bc_runtime_engine_test_proof_count();
unsafe extern C fn void bc_runtime_engine_test_call_error(u32 status,u8 kind,usize offset);
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
struct Heap { usize blocks; usize bytes; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void same_heap(ref Heap h){assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes);}
fn void proofs(usize expected){assert(unsafe{bc_runtime_engine_test_proof_count()}==expected);}
fn usize budget(){return 16000000;}
fn Result<modules::Index,u8> indexed(ref u8[] source){
    var sources::Builder b=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{return .err(1);}};
    if(!sources::add(ref mut b,b"app.brc",source).is_ok){return .err(2);}
    let sources::Snapshot s=switch(sources::freeze(ref b)){case .ok(v):{v}case .err(_):{return .err(3);}};
    return switch(modules::build(s)){case .ok(v):{.ok(v)}case .err(_):{.err(4)}};
}
fn Result<entries::Entry,u8> selected(ref u8[] source){return switch(entries::select_i32(indexed(source)?,b"app",b"chosen")){
    case .ok(v):{.ok(v)}case .err(_):{.err(5)}
};}
fn Result<input_entries::InputEntry,u8> selected_input(ref u8[] source){return switch(input_entries::select_i32_input(indexed(source)?,b"app",b"chosen")){
    case .ok(v):{.ok(v)}case .err(_):{.err(6)}
};}
fn Result<programs::Program,u8> compiled(ref u8[] source,bool input){
    if(input){return switch(programs::compile_input(selected_input(source)?,65536)){
        case .ok(v):{.ok(v)}case .err(_):{.err(7)}
    };}
    return switch(programs::compile(selected(source)?,65536)){case .ok(v):{.ok(v)}case .err(e):{unsafe{bc_runtime_engine_test_call_error(8,e.code.kind,e.code.offset)};.err(8)}};
}
fn Result<inputs::Snapshot,u8> captured(ref u8[] data){
    var usize fuel=0;return switch(inputs::snapshot(data,inputs::hard_limit(),0,ref mut fuel)){
        case .ok(v):{.ok(v)}case .err(_):{.err(9)}
    };
}
fn ref u8[] rich_source(){
    return b"module app;fn ref u8[] tail(ref u8[] data){return data[1..];}fn i32 rhs(){return 42;}pub fn i32 chosen(ref u8[] data){var a=[0,0];a[1]=rhs();let ref u8[] part=tail(ref data);output::emit(ref part);output::emit(ref b\"*\");return a[1];}";
}
fn void same_sites(ref statics::Sites a,ref statics::Sites b){
    assert(a.count==b.count && a.dynamic==b.dynamic && a.generic==b.generic);
    assert(a.call_profile==b.call_profile && a.output==b.output);
    var usize i=0;while(i<16){
        assert(a.definitions[i]==b.definitions[i] && a.functions[i]==b.functions[i] && a.starts[i]==b.starts[i]);
        assert(a.kinds[i]==b.kinds[i] && a.results[i]==b.results[i] && a.origins[i]==b.origins[i]);
        assert(a.roots[i]==b.roots[i] && a.spans[i].literal==b.spans[i].literal);
        assert(a.spans[i].start==b.spans[i].start && a.spans[i].end==b.spans[i].end);i+=1;
    }
    i=0;while(i<128){assert(a.parameters[i]==b.parameters[i] && a.formal_sites[i]==b.formal_sites[i]);i+=1;}
}
fn void same_preparation(ref programs::Preparation a,ref programs::Preparation b){
    same_sites(ref a.sites,ref b.sites);var usize i=0;
    while(i<16){assert(a.origins[i]==b.origins[i] && a.parameters[i]==b.parameters[i]);i+=1;}
    assert(a.list.length==b.list.length && a.list.bytes==b.list.bytes && a.list.cost==b.list.cost);
    assert(a.place.width==b.place.width && a.place.cost==b.place.cost && a.place.aggregate==b.place.aggregate);
    assert(a.place.slices==b.place.slices && a.place.records==b.place.records);
    assert(a.work==b.work && a.capacity==b.capacity && a.scratch==b.scratch);
    assert(a.calls.ready==b.calls.ready);i=0;
    while(i<32){assert(a.calls.pcs[i]==b.calls.pcs[i] && a.calls.required[i]==b.calls.required[i] && a.calls.absent[i]==b.calls.absent[i]);i+=1;}
    i=0;while(i<256){assert(a.calls.ends[i]==b.calls.ends[i] && a.calls.parents[i]==b.calls.parents[i]);i+=1;}
}
// Exactly one additional proof, then independent non-verifier requirements.
fn Result<usize,u8> independent(ref programs::Program p,usize before){
    let verifier::ReferenceReturnProof proof=switch(verifier::inspect_output_returns(programs::code(p),programs::literals(p),programs::accepts_input(p))){
        case .ok(v):{v}case .err(_):{return .err(10);}
    };
    proofs(before+1);
    let lists::Requirement list=switch(lists::requirement(ref programs::code(p).body)){
        case .ok(v):{v}case .err(_):{return .err(11);}
    };
    let places::Requirement place=switch(places::requirement(ref programs::code(p).body)){
        case .ok(v):{v}case .err(_):{return .err(12);}
    };
    let usize work=switch(calls::cost(ref programs::code(p).body,programs::code(p).body.entry,0)){
        case .ok(v):{v}case .err(_):{return .err(13);}
    };
    let execution_heap::Plan planned=switch(execution_heap::prepare(ref programs::code(p).body,programs::accepts_input(p),true,0)){
        case .ok(v):{v}case .err(_):{return .err(14);}
    };
    let capture_plans::Plan captures=switch(capture_plans::prepare(ref programs::code(p).body)){
        case .ok(v):{v}case .err(_):{return .err(25);}
    };
    let programs::Preparation expected=programs::Preparation{.sites=proof.statics,.origins=proof.recipes.site_origins,
        .list=list,.place=place,.work=work+programs::code(p).body.arities[programs::code(p).body.entry],
        .capacity=if(programs::code(p).body.arrays.count!=0 || programs::code(p).body.records.count!=0){65536}else{0},
        .scratch=planned.scratch,.parameters=[0;16],.calls=captures};
    same_preparation(programs::preparation(p),ref expected);proofs(before+1);return .ok(0);
}
fn void completed(ref programs::Execution run,ref u8[] expected,i64 value,usize emits){
    let programs::Completion c=programs::observe(run);
    assert(c.success && c.value==value && c.remaining<budget() && c.diagnostic.code.kind==0);
    assert(c.output_bytes==expected.len && c.emits==emits && programs::has_output(run));
    assert(bytes::equal(programs::view(run),expected));
}

// Group 1: one owning compile, repeated getters and every owning execution path.
// Check reuse BEFORE deliberately spending a proof on the independent oracle.
pub fn Result<usize,u8> owning_program_reuses_preparation_and_matches_independent_proof(){
    unsafe{bc_runtime_engine_test_proof_begin()};
    let programs::Program p=compiled(rich_source(),true)?;proofs(1);
    let programs::Preparation saved=*programs::preparation(ref p);
    assert(saved.capacity==65536 && saved.list.length>0 && saved.place.width>0 && saved.scratch>65536);
    var bool input_origin=false;var bool static_origin=false;var usize site=0;
    while(site<16){
        if(saved.origins[site]==1){input_origin=true;}
        if(saved.origins[site]==9){static_origin=true;}site+=1;
    }
    assert(input_origin && static_origin);
    let inputs::Snapshot input=captured(b"!\x00I")?;
    var usize i=0;while(i<3){same_preparation(programs::preparation(ref p),ref saved);proofs(1);i+=1;}
    let programs::Execution baseline=programs::complete(ref p,ref input,budget(),16,true);
    completed(ref baseline,b"\x00I*",42,2);proofs(1);
    var cursors::Stats stats=cursors::stats();
    let programs::Execution quantized=programs::complete_quantized(ref p,ref input,budget(),16,true,1,ref mut stats);
    completed(ref quantized,b"\x00I*",42,2);
    assert(programs::observe(ref quantized).remaining==programs::observe(ref baseline).remaining && stats.yields>0);proofs(1);
    let Heap retained=heap();
    {
        var machine::Machine pending=switch(engine::prepare_pending_output(ref p,ref input,budget(),16,true)){
            case .ok(v):{v}case .err(_):{return .err(15);}
        };
        proofs(1);var machine::Meta state=machine::observe(ref pending);var usize ticks=0;
        assert(state.phase==1 && state.stats.dispatched==0);
        while(state.phase==1){
            assert(ticks<1000);state=switch(engine::advance_pending_output(ref mut pending,ref p,ref input,1)){
                case .ok(v):{v}case .err(_):{return .err(16);}
            };proofs(1);ticks+=1;
        }
        assert(state.phase==2 && state.value==42 && ticks>1);
        let output::Published sealed=switch(engine::seal_pending_output(ref mut pending)){
            case .ok(v):{v}case .err(_):{return .err(17);}
        };
        assert(bytes::equal(output::view(ref sealed),programs::view(ref baseline)));
        assert(output::published_observation(ref sealed).fuel==programs::observe(ref baseline).remaining);proofs(1);
    }
    same_heap(ref retained);
    {
        var machine::Machine dropped=switch(engine::prepare_pending_output(ref p,ref input,budget(),16,true)){
            case .ok(v):{v}case .err(_):{return .err(18);}
        };
        let machine::Meta first=switch(engine::advance_pending_output(ref mut dropped,ref p,ref input,1)){
            case .ok(v):{v}case .err(_):{return .err(19);}
        };
        assert(first.phase==1);proofs(1);
    }
    same_heap(ref retained);same_preparation(programs::preparation(ref p),ref saved);
    let usize checked=independent(ref p,1)?;proofs(2);
    same_preparation(programs::preparation(ref p),ref saved);return .ok(0);
}

fn usize id(Result<usize,engine::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn engine::Event event(Result<engine::Event,engine::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,.remaining=0,.fuel_known=false,
        .diagnostic=diagnostics::absent(errors::make(0,0))}}
};}
fn Result<usize,u8> bound(ref mut engine::Engine e,usize p){
    return .ok(id(engine::create_input_output_instance(e,p,captured(b"!\x00I")?,budget(),16,true)));
}
fn void terminal(engine::Event done,ref engine::Output out,usize remaining){
    let programs::Completion c=engine::output_completion(out);
    assert(done.kind==1 && done.value==42 && done.fuel_known && done.remaining==remaining && done.diagnostic.code.kind==0);
    assert(c.success && c.value==42 && c.remaining==remaining && c.output_bytes==3 && c.emits==2);
    assert(c.diagnostic.code.kind==0 && engine::output_available(out));
    assert(bytes::equal(engine::output_view(out),b"\x00I*"));
}
fn Result<engine::Output,u8> taken(ref mut engine::Engine e,usize i){return switch(engine::take_output(e,i)){
    case .ok(v):{.ok(v)}case .err(_):{.err(20)}
};}
// Group 2: one Engine compile, multiple owners, released pins and Engine moves.
// Obtain the exact Fuel oracle from the same Engine's synchronous invocation.
pub fn Result<usize,u8> engine_instances_reuse_proof_across_release_moves_and_resume(){
    unsafe{bc_runtime_engine_test_proof_begin()};
    var engine::Engine original=switch(engine::create(engine::Limits{.programs=2,.instances=4,.fuel=16000000})){
        case .ok(v):{v}case .err(_):{return .err(21);}
    };
    let Heap control_heap=heap();
    let usize p=id(engine::compile_input_output(ref mut original,selected_input(rich_source())?,65536));proofs(1);
    let usize baseline=bound(ref mut original,p)?;
    let engine::Event expected=event(engine::execute_once(ref mut original,baseline));proofs(1);
    assert(expected.kind==1 && expected.value==42 && expected.fuel_known && expected.remaining<budget());
    {
        let engine::Output out=taken(ref mut original,baseline)?;terminal(expected,ref out,expected.remaining);
    }
    assert(id(engine::destroy_instance(ref mut original,baseline))==baseline);proofs(1);
    let usize first=bound(ref mut original,p)?;let usize second=bound(ref mut original,p)?;
    let usize sync=bound(ref mut original,p)?;proofs(1);
    assert(id(engine::required_pending_bytes(ref original,p,16))>0);proofs(1);
    assert(event(engine::prepare_instance(ref mut original,first)).kind==4);proofs(1);
    // Release forbids fresh admissions, but all existing pins retain their cache.
    assert(id(engine::release_program(ref mut original,p))==p);proofs(1);
    var engine::Engine moved=original;
    assert(event(engine::prepare_instance(ref mut moved,second)).kind==4);proofs(1);
    let engine::Event synchronous=event(engine::execute_once(ref mut moved,sync));proofs(1);
    {
        let engine::Output out=taken(ref mut moved,sync)?;terminal(synchronous,ref out,expected.remaining);
    }
    assert(id(engine::destroy_instance(ref mut moved,sync))==sync);
    assert(event(engine::step_instance(ref mut moved,first,1)).kind==4);proofs(1);
    var engine::Engine again=moved;
    let usize[2] owners=[first,second];var usize n=0;
    while(n<2){
        var engine::Event state=event(engine::observe(ref mut again,owners[n]));var usize ticks=0;
        while(state.kind==4){
            assert(ticks<1000);state=event(engine::step_instance(ref mut again,owners[n],if(n==0){1}else{7}));
            proofs(1);ticks+=1;
        }
        {
            let engine::Output out=taken(ref mut again,owners[n])?;terminal(state,ref out,expected.remaining);
        }
        assert(id(engine::destroy_instance(ref mut again,owners[n]))==owners[n]);proofs(1);n+=1;
    }
    switch(engine::inspect(ref mut again)){
        case .ok(v):{assert(v.programs==0 && v.instances==0 && v.pins==0);}case .err(_):{assert(false);}
    };
    same_heap(ref control_heap);
    assert(id(engine::destroy(ref mut again))==0);proofs(1);return .ok(0);
}

// Group 3: independent no-input/input owners with distinct static and scratch
// plans. Interleave execution, move an owner, and compare all cached fields.
pub fn Result<usize,u8> unrelated_programs_keep_separate_immutable_preparations(){
    unsafe{bc_runtime_engine_test_proof_begin()};
    let programs::Program plain=compiled(b"module app;pub fn i32 chosen(){output::emit(ref b\"plain\");return 7;}",false)?;proofs(1);
    let programs::Preparation a=*programs::preparation(ref plain);
    let programs::Program rich=compiled(rich_source(),true)?;proofs(2);
    let programs::Preparation b=*programs::preparation(ref rich);
    assert(a.capacity==0 && a.scratch==0 && a.list.length==0 && a.place.width==0);
    assert(b.capacity==65536 && b.scratch>a.scratch && b.list.length>0 && b.place.width>0 && b.work!=a.work);
    let inputs::Snapshot empty=captured(b"")?;let inputs::Snapshot input=captured(b"!\x00I")?;
    let programs::Program moved=rich;proofs(2);
    var usize n=0;while(n<2){
        {
            let programs::Execution first=programs::complete(ref plain,ref empty,budget(),16,true);
            completed(ref first,b"plain",7,1);
            let programs::Execution second=programs::complete(ref moved,ref input,budget(),16,true);
            completed(ref second,b"\x00I*",42,2);
            assert(bytes::equal(programs::view(ref first),b"plain"));proofs(2);
        }
        same_preparation(programs::preparation(ref plain),ref a);
        same_preparation(programs::preparation(ref moved),ref b);proofs(2);n+=1;
    }
    let usize first_checked=independent(ref plain,2)?;let usize second_checked=independent(ref moved,3)?;
    proofs(4);same_preparation(programs::preparation(ref plain),ref a);
    same_preparation(programs::preparation(ref moved),ref b);return .ok(0);
}

// Fresh invocation state for each raw call. The owning Program is only a source
// of raw IR/image here: its cached proof must not authorize an ABI mismatch.
fn Result<usize,u8> raw_call(ref programs::Program p,ref inputs::Snapshot input,bool abi,bool valid,usize count){
    var usize remaining=budget();
    var output::Transaction staged=switch(output::open_metered(16,true,ref mut remaining)){
        case .ok(v):{v}case .err(_):{return .err(22);}
    };
    let usize before=remaining;let output::Observation prior=output::observe(ref staged);
    var runtime::State state=runtime::empty(0);var u8[1] data=[0];var cursors::Stats stats=cursors::stats();
    let Result<execution::Scalar,errors::Error> result=execution::execute_output_scalar_quantized(
        programs::code(p),programs::literals(p),inputs::view(input),abi,ref mut state,ref mut data[..0],
        ref mut remaining,ref mut staged,1,ref mut stats);
    proofs(count);
    if(!valid){
        switch(result){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
        assert(remaining==before && stats.calls==0 && stats.dispatched==0 && stats.yields==0);
        let output::Observation after=output::observe(ref staged);
        assert(after.phase==prior.phase && after.length==prior.length && after.emits==prior.emits);
        assert(after.fuel==prior.fuel && after.charged==prior.charged);return .ok(0);
    }
    switch(result){case .ok(v):{assert(v.value==42);}case .err(_):{assert(false);return .err(23);}};
    let output::Published sealed=switch(output::seal_metered(ref mut staged,ref mut remaining)){
        case .ok(v):{v}case .err(_):{return .err(24);}
    };
    assert(bytes::equal(output::view(ref sealed),if(abi){inputs::view(input)}else{b"*"}));
    assert(output::published_observation(ref sealed).emits==1);
    // The same owning execution is an exact final-Fuel/output oracle and must
    // add no proof after the raw call has already consumed one.
    let programs::Execution reference=programs::complete(p,input,budget(),16,true);
    assert(programs::observe(ref reference).success && programs::observe(ref reference).value==42);
    assert(programs::observe(ref reference).remaining==remaining);
    assert(bytes::equal(programs::view(ref reference),output::view(ref sealed)));proofs(count);return .ok(0);
}
// Group 4: repeated valid raw calls each verify again. Both wrong ABI directions
// also enter the verifier, reject before dispatch and preserve caller Fuel.
pub fn Result<usize,u8> raw_calls_reverify_and_reject_wrong_input_abi_without_fuel_mutation(){
    unsafe{bc_runtime_engine_test_proof_begin()};
    let programs::Program input_code=compiled(b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}",true)?;proofs(1);
    let programs::Program plain=compiled(b"module app;pub fn i32 chosen(){output::emit(ref b\"*\");return 42;}",false)?;proofs(2);
    let inputs::Snapshot input=captured(b"\x00\xFFI")?;let inputs::Snapshot empty=captured(b"")?;
    let usize first=raw_call(ref input_code,ref input,true,true,3)?;
    let usize repeat=raw_call(ref input_code,ref input,true,true,4)?;
    let usize wrong_plain_abi=raw_call(ref input_code,ref empty,false,false,5)?;
    let usize wrong_input_abi=raw_call(ref plain,ref input,true,false,6)?;
    let usize plain_valid=raw_call(ref plain,ref empty,false,true,7)?;proofs(7);return .ok(0);
}

pub fn void run(){
    let Heap before=heap();
    assert(owning_program_reuses_preparation_and_matches_independent_proof().is_ok);same_heap(ref before);
    assert(engine_instances_reuse_proof_across_release_moves_and_resume().is_ok);same_heap(ref before);
    assert(unrelated_programs_keep_separate_immutable_preparations().is_ok);same_heap(ref before);
    assert(raw_calls_reverify_and_reject_wrong_input_abi_without_fuel_mutation().is_ok);same_heap(ref before);
}
