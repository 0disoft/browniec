module engine_preparation_reuse_tests;
import runtime_engine as engine;
import module_output_program as programs;
import module_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import runtime_input as inputs;
import runtime_output as output;
import static_call_ir as code;
import static_image as images;
import slice_result_execution as execution;
import slice_result_runtime as runtime;
import slice_result_cursor as cursors;
import std::bytes as bytes;

// Gap tests only. The parent owns native hooks, runner and main integration;
// engine_preparation_cache_tests already owns ordinary reuse/lifecycle cases.
unsafe extern C fn void bc_runtime_engine_test_proof_begin();
unsafe extern C fn usize bc_runtime_engine_test_proof_count();
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
struct Heap { usize blocks; usize bytes; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void same_heap(ref Heap h){assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes);}
fn void proofs(usize count){assert(unsafe{bc_runtime_engine_test_proof_count()}==count);}
fn Result<entries::Entry,u8> selected(ref u8[] source){
    var sources::Builder b=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{return .err(1);}};
    if(!sources::add(ref mut b,b"app.brc",source).is_ok){return .err(2);}
    let sources::Snapshot s=switch(sources::freeze(ref b)){case .ok(v):{v}case .err(_):{return .err(3);}};
    let modules::Index index=switch(modules::build(s)){case .ok(v):{v}case .err(_):{return .err(4);}};
    return switch(entries::select_i32(index,b"app",b"chosen")){case .ok(v):{.ok(v)}case .err(_):{.err(5)}};
}
fn ref u8[] source(){return b"module app;pub fn i32 chosen(){output::emit(ref b\"OK\");return 42;}";}
fn usize id(Result<usize,engine::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void rejected(Result<usize,engine::Error> r,u32 status){switch(r){
    case .ok(_):{assert(false);}case .err(e):{assert(e.status==status);}
};}
fn engine::Event event(Result<engine::Event,engine::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,.remaining=0,.fuel_known=false,
        .diagnostic=diagnostics::absent(errors::make(0,0))}}
};}
fn void counts(ref mut engine::Engine e,usize programs,usize instances,usize pins){switch(engine::inspect(e)){
    case .ok(v):{assert(v.programs==programs && v.instances==instances && v.pins==pins && !v.closed);}
    case .err(_):{assert(false);}
};}

// Group 1: lowering/image/admission rejection never creates a cached proof.
// A released, pinned Program still occupies its slot; final destruction admits
// a fresh compile, which must pay exactly one new full proof of its own.
pub fn Result<usize,u8> rejected_compiles_and_pinned_slot_do_not_publish_or_reuse_a_proof(){
    unsafe{bc_runtime_engine_test_proof_begin()};
    var engine::Engine original=switch(engine::create(engine::Limits{.programs=1,.instances=1,.fuel=16000000})){
        case .ok(v):{v}case .err(_):{return .err(6);}
    };
    let Heap empty=heap();
    rejected(engine::compile_output(ref mut original,selected(b"module app;pub fn i32 chosen(){return missing;}")?,65536),4);
    proofs(0);counts(ref mut original,0,0,0);same_heap(ref empty);
    rejected(engine::compile_output(ref mut original,selected(source())?,0),4);
    proofs(0);counts(ref mut original,0,0,0);same_heap(ref empty);
    let usize p=id(engine::compile_output(ref mut original,selected(source())?,65536));proofs(1);
    let usize i=id(engine::create_output_instance(ref mut original,p,16000000,2,true));
    let Heap pinned=heap();
    rejected(engine::compile_output(ref mut original,selected(source())?,65536),8);
    proofs(1);counts(ref mut original,1,1,1);same_heap(ref pinned);
    assert(id(engine::release_program(ref mut original,p))==p);
    var engine::Engine moved=original;
    rejected(engine::compile_output(ref mut moved,selected(source())?,65536),8);
    proofs(1);counts(ref mut moved,1,1,1);same_heap(ref pinned);
    assert(event(engine::prepare_instance(ref mut moved,i)).kind==4);proofs(1);
    var engine::Event state=event(engine::observe(ref mut moved,i));var usize ticks=0;
    while(state.kind==4){
        assert(ticks<128);state=event(engine::step_instance(ref mut moved,i,1));proofs(1);ticks+=1;
    }
    assert(state.kind==1 && state.value==42 && state.fuel_known && state.diagnostic.code.kind==0);
    {
        let engine::Output result=switch(engine::take_output(ref mut moved,i)){
            case .ok(v):{v}case .err(_):{return .err(7);}
        };
        assert(engine::output_available(ref result) && bytes::equal(engine::output_view(ref result),b"OK"));
        let programs::Completion c=engine::output_completion(ref result);
        assert(c.success && c.remaining==state.remaining && c.emits==1 && c.output_bytes==2);
    }
    assert(id(engine::destroy_instance(ref mut moved,i))==i);proofs(1);
    counts(ref mut moved,0,0,0);same_heap(ref empty);
    let usize fresh=id(engine::compile_output(ref mut moved,selected(source())?,65536));
    assert(fresh!=p);proofs(2);counts(ref mut moved,1,0,0);
    assert(id(engine::release_program(ref mut moved,fresh))==fresh);
    assert(id(engine::destroy(ref mut moved))==0);proofs(2);return .ok(0);
}

// Every invocation receives fresh execution state, but the SAME mutable IR
// owner/address is reused. A prior proof cannot authorize its modified bytes.
fn Result<usize,u8> raw(ref code::Program p,ref images::Image image,bool valid,usize count){
    var usize remaining=16000000;
    var output::Transaction staged=switch(output::open_metered(2,true,ref mut remaining)){
        case .ok(v):{v}case .err(_):{return .err(8);}
    };
    let usize before=remaining;let output::Observation prior=output::observe(ref staged);
    var runtime::State state=runtime::empty(0);var u8[1] data=[0];var cursors::Stats stats=cursors::stats();
    let Result<execution::Scalar,errors::Error> result=execution::execute_output_scalar_quantized(
        p,image,b"",false,ref mut state,ref mut data[..0],ref mut remaining,ref mut staged,1,ref mut stats);
    proofs(count);
    if(!valid){
        switch(result){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
        assert(remaining==before && stats.calls==0 && stats.dispatched==0 && stats.yields==0);
        let output::Observation after=output::observe(ref staged);
        assert(after.phase==prior.phase && after.length==0 && after.emits==0);
        assert(after.fuel==prior.fuel && after.charged==prior.charged);return .ok(0);
    }
    switch(result){case .ok(v):{assert(v.value==42);}case .err(_):{assert(false);return .err(9);}};
    let output::Published sealed=switch(output::seal_metered(ref mut staged,ref mut remaining)){
        case .ok(v):{v}case .err(_):{return .err(10);}
    };
    assert(bytes::equal(output::view(ref sealed),b"OK"));
    let output::Observation final=output::published_observation(ref sealed);
    assert(final.length==2 && final.emits==1 && final.fuel==remaining);return .ok(remaining);
}

// Group 2: a valid raw invocation is followed by a reserved-byte mutation,
// repeated rejection, restoration, and a different malformed return ABI.
// Owning completion stays valid and cached throughout these unrelated edits.
pub fn Result<usize,u8> mutated_raw_code_reverifies_and_refuses_without_dispatch(){
    unsafe{bc_runtime_engine_test_proof_begin()};
    let programs::Program owner=switch(programs::compile(selected(source())?,65536)){
        case .ok(v):{v}case .err(_):{return .err(11);}
    };proofs(1);
    var code::Program candidate=*programs::code(ref owner);
    var usize emit=0;while(emit<candidate.body.count && candidate.body.code[emit*8]!=116){emit+=1;}
    assert(emit<candidate.body.count && candidate.body.code[emit*8+4]==0);
    let Heap retained=heap();
    let usize expected=raw(ref candidate,programs::literals(ref owner),true,2)?;same_heap(ref retained);
    candidate.body.code[emit*8+4]=1;
    let usize bad=raw(ref candidate,programs::literals(ref owner),false,3)?;same_heap(ref retained);
    let usize repeated=raw(ref candidate,programs::literals(ref owner),false,4)?;same_heap(ref retained);
    candidate.body.code[emit*8+4]=0;
    let usize restored=raw(ref candidate,programs::literals(ref owner),true,5)?;
    assert(restored==expected);same_heap(ref retained);
    let usize entry=candidate.body.entry;let u8 result=candidate.body.return_types[entry];
    assert(result==1);candidate.body.return_types[entry]=2;
    let usize wrong_result=raw(ref candidate,programs::literals(ref owner),false,6)?;same_heap(ref retained);
    var usize fuel=0;
    let inputs::Snapshot empty=switch(inputs::snapshot(b"",inputs::hard_limit(),0,ref mut fuel)){
        case .ok(v):{v}case .err(_):{return .err(12);}
    };
    {
        let programs::Execution completed=programs::complete(ref owner,ref empty,16000000,2,true);
        let programs::Completion c=programs::observe(ref completed);
        assert(c.success && c.value==42 && c.remaining==expected && c.emits==1 && c.output_bytes==2);
        assert(programs::has_output(ref completed) && bytes::equal(programs::view(ref completed),b"OK"));proofs(6);
    }
    candidate.body.return_types[entry]=result;
    let usize recovered=raw(ref candidate,programs::literals(ref owner),true,7)?;
    assert(recovered==expected);proofs(7);return .ok(0);
}

pub fn void run(){
    let Heap before=heap();
    assert(rejected_compiles_and_pinned_slot_do_not_publish_or_reuse_a_proof().is_ok);same_heap(ref before);
    assert(mutated_raw_code_reverifies_and_refuses_without_dispatch().is_ok);same_heap(ref before);
}
