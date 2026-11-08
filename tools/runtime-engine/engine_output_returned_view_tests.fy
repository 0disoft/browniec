module engine_output_returned_view_tests;
import runtime_engine as engine;
import runtime_live_memory as live;
import module_output_program as programs;
import module_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import runtime_input as inputs;
import runtime_output as output;
import output_return_proof as proof;
import call_capture_plan as capture_plans;
import static_call_ir as candidates;
import output_return_ir as return_ir;
import slice_result_ir as borrowed_ir;
import slice_result_verifier as borrowed_proof;
import verifier as canonical;
import ir as ir;
import slice_result_execution as execution;
import slice_result_runtime as runtime;
import slice_result_cursor as cursors;
import array_vm as backing;
import std::bytes as bytes;

// Actual source, immutable owning Programs and Engine instances. The parent
// owns runner integration and serial native checks. Owning execution must reuse
// the exact immutable capture plan; the independent raw oracle still scans.
unsafe extern C fn void bc_runtime_engine_test_recipe_begin();
unsafe extern C fn usize bc_runtime_engine_test_recipe_count();
fn void begin_recipes(){unsafe{bc_runtime_engine_test_recipe_begin()};}
fn void no_recipes(){assert(unsafe{bc_runtime_engine_test_recipe_count()}==0);}
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
unsafe extern C fn void bc_runtime_engine_test_call_error(u32 status,u8 kind,usize offset);
struct Heap { usize blocks; usize bytes; }
struct Oracle { i64 value; usize remaining; usize output_bytes; usize emits; }
fn usize budget(){return 16000000;}
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void same_heap(Heap h){assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes);}
fn usize id(Result<usize,engine::Error> r){return switch(r){case .ok(v):{v}case .err(e):{
    unsafe{bc_runtime_engine_test_call_error(e.status,e.diagnostic.code.kind,e.diagnostic.code.offset)};assert(false);0
}};}
fn engine::Event event(Result<engine::Event,engine::Error> r){return switch(r){
    case .ok(v):{v}case .err(e):{unsafe{bc_runtime_engine_test_call_error(e.status,e.diagnostic.code.kind,e.diagnostic.code.offset)};
        assert(false);engine::Event{.kind=0,.value=0,.remaining=0,.fuel_known=false,
        .diagnostic=diagnostics::absent(errors::make(0,0))}}
};}
fn void same_diagnostic(diagnostics::Error a,diagnostics::Error b){
    assert(a.code.kind==b.code.kind && a.code.offset==b.code.offset);
    assert(a.at.source==b.at.source && a.at.start==b.at.start && a.at.end==b.at.end);
}
fn void same_event(engine::Event a,engine::Event b){
    assert(a.kind==b.kind && a.value==b.value && a.remaining==b.remaining && a.fuel_known==b.fuel_known);
    same_diagnostic(a.diagnostic,b.diagnostic);
}
fn void same_completion(programs::Completion a,programs::Completion b){
    assert(a.success==b.success && a.value==b.value && a.remaining==b.remaining);
    assert(a.output_bytes==b.output_bytes && a.emits==b.emits);same_diagnostic(a.diagnostic,b.diagnostic);
}
fn live::Observation memory(ref engine::Engine e){return switch(engine::instance_memory(e)){
    case .ok(v):{v}case .err(_):{assert(false);live::Observation{.instance_limit=0,.instances_limit=0,.current=0,.peak=0,.closed=false}}
};}
fn void ledger(ref engine::Engine e,usize current){
    let live::Observation m=memory(e);assert(m.current==current && current<=m.peak && m.peak<=m.instances_limit && !m.closed);
    switch(engine::program_memory(e)){
        case .ok(v):{assert(v.external_bytes==current && v.tracked_bytes==v.control_bytes+v.program_bytes+current &&
            v.tracked_bytes<=v.tracked_peak && v.tracked_peak<=v.engine_limit && !v.closed);}
        case .err(_):{assert(false);}
    };
}
fn void counts(ref mut engine::Engine e,usize programs,usize instances,usize pins){switch(engine::inspect(e)){
    case .ok(v):{assert(v.programs==programs && v.instances==instances && v.pins==pins && !v.closed);}
    case .err(_):{assert(false);}
};}
fn Result<entries::Entry,u8> selected(ref u8[] source){
    var sources::Builder b=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{return .err(1);}};
    if(!sources::add(ref mut b,b"app.brc",source).is_ok){return .err(2);}
    let sources::Snapshot s=switch(sources::freeze(ref b)){case .ok(v):{v}case .err(_):{return .err(3);}};
    let modules::Index index=switch(modules::build(s)){case .ok(v):{v}case .err(_):{return .err(4);}};
    return switch(entries::select_i32(index,b"app",b"chosen")){case .ok(v):{.ok(v)}case .err(_):{.err(5)}};
}
fn ref u8[] direct_source(){
    return b"module app;fn ref mut u8[] tail(ref mut u8[] x){return ref mut x;}pub fn i32 chosen(){var u8[2] a=[41;2];let ref mut u8[] s=tail(ref mut a[..]);s[0]+=1;output::emit(ref s);return s[0] as i32;}";
}
fn ref u8[] nested_source(){
    return b"module app;fn ref mut u8[] tail(ref mut u8[] x){return ref mut x;}pub fn i32 chosen(){var u8[2] a=[41;2];let ref mut u8[] s=tail(ref mut tail(ref mut a[..])[..]);s[0]+=1;output::emit(ref s);return s[0] as i32;}";
}
fn ref u8[] forward_source(){
    return b"module app;fn ref mut u8[] tail(ref mut u8[] x){return ref mut x;}fn ref mut u8[] forward(ref mut u8[] x){return tail(ref mut x);}pub fn i32 chosen(){var u8[2] a=[41;2];let ref mut u8[] s=forward(ref mut a[..]);s[0]+=1;output::emit(ref s);return s[0] as i32;}";
}
fn ref u8[] pick_source(){
    return b"module app;fn ref mut u8[] pick(ref mut u8[] x,ref mut u8[] y){return ref mut y;}pub fn i32 chosen(){var u8[2] a=[7;2];var u8[2] b=[41;2];let ref mut u8[] s=pick(ref mut a[..],ref mut b[..]);s[0]+=1;output::emit(ref s);return s[0] as i32;}";
}
fn Result<entries::Entry,u8> selected_mode(usize mode){
    if(mode==0){return selected(direct_source());}
    if(mode==1){return selected(nested_source());}
    if(mode==2){return selected(forward_source());}
    return selected(pick_source());
}
fn Result<programs::Program,u8> compiled(usize mode){return switch(programs::compile(selected_mode(mode)?,65536)){
    case .ok(v):{.ok(v)}case .err(e):{unsafe{bc_runtime_engine_test_call_error(0,e.code.kind,e.code.offset)};.err(6)}
};}
fn Result<inputs::Snapshot,u8> empty_input(){var usize fuel=0;return switch(inputs::snapshot(b"",inputs::hard_limit(),0,ref mut fuel)){
    case .ok(v):{.ok(v)}case .err(_):{.err(7)}
};}
fn Result<engine::Engine,u8> created(){return switch(engine::create(engine::Limits{.programs=1,.instances=2,.fuel=16000000})){
    case .ok(v):{.ok(v)}case .err(_):{.err(8)}
};}
fn Result<usize,u8> engine_program(ref mut engine::Engine e,usize mode){return .ok(id(engine::compile_output(e,selected_mode(mode)?,65536)));}
fn usize bound(ref mut engine::Engine e,usize p,usize fuel){return id(engine::create_output_instance(e,p,fuel,16,true));}
fn Result<engine::Output,u8> take(ref mut engine::Engine e,usize i){return switch(engine::take_output(e,i)){
    case .ok(v):{.ok(v)}case .err(_):{.err(9)}
};}
fn void rejected_take(ref mut engine::Engine e,usize i,u32 status){switch(engine::take_output(e,i)){
    case .ok(_):{assert(false);}case .err(v):{assert(v.status==status);}
};}
fn void destroy(ref mut engine::Engine e,usize i){assert(id(engine::destroy_instance(e,i))==i);}
fn void close(ref mut engine::Engine e,usize p){assert(id(engine::release_program(e,p))==p);assert(id(engine::destroy(e))==0);}
fn engine::Event completion(ref engine::Output out){let programs::Completion c=engine::output_completion(out);return engine::Event{
    .kind=if(c.success){1}else{2},.value=c.value,.remaining=c.remaining,.fuel_known=true,.diagnostic=c.diagnostic};}
fn void expected(programs::Completion c,Oracle oracle){
    assert(c.success && c.value==42 && c.value==oracle.value && c.remaining==oracle.remaining && c.diagnostic.code.kind==0);
    assert(c.output_bytes==2 && c.output_bytes==oracle.output_bytes && c.emits==1 && c.emits==oracle.emits);
}
fn void expected_output(ref engine::Output out,Oracle oracle){
    expected(engine::output_completion(out),oracle);assert(engine::output_available(out) && bytes::equal(engine::output_view(out),b"*)"));
}
fn Result<engine::Output,u8> synchronous(ref mut engine::Engine e,usize p,usize fuel){
    let usize i=bound(e,p,fuel);begin_recipes();let engine::Event done=event(engine::execute_once(e,i));no_recipes();
    let engine::Output out=take(e,i)?;same_event(done,completion(ref out));destroy(e,i);return .ok(out);
}
fn usize quantum(usize schedule,usize tick){
    let usize[3] fixed=[1,7,4096];let usize[5] mixed=[1,7,3,4096,2];
    return if(schedule<3){fixed[schedule]}else{mixed[tick%5]};
}
// Every resume, including terminal seal/failure, must make zero SDK allocation
// attempts. Pending retains its charge and physical heap exactly until cleanup.
fn engine::Event tick(ref mut engine::Engine e,usize i,usize q){
    let engine::Event before=event(engine::observe(e,i));let Heap retained=heap();let usize charge=memory(e).current;
    let usize attempts=unsafe{probe_attempts()};begin_recipes();unsafe{bc_runtime_engine_test_fail(0)};
    let Result<engine::Event,engine::Error> result=engine::step_instance(e,i,q);unsafe{bc_runtime_engine_test_fail(-1)};
    let engine::Event after=event(result);no_recipes();assert(unsafe{probe_attempts()}==attempts);
    assert(before.kind==4 && after.fuel_known && after.remaining<=before.remaining && (after.kind==4 || after.kind==1 || after.kind==2));
    same_event(after,event(engine::observe(e,i)));
    if(after.kind==4){same_heap(retained);ledger(e,charge);rejected_take(e,i,11);}return after;
}
fn engine::Event finish(ref mut engine::Engine e,usize i,usize schedule){
    var engine::Event state=event(engine::observe(e,i));var usize ticks=0;
    while(state.kind==4){assert(ticks<1000);state=tick(e,i,quantum(schedule,ticks));ticks+=1;}
    assert(ticks>0);return state;
}
// Assert the source really produced borrowed RETURN recipes and CALL66. A
// shared/static result or a proxy scalar CALL must not satisfy these fixtures.
fn Result<usize,u8> actual_recipes(ref programs::Program p,usize mode){
    assert(!programs::accepts_input(p));
    let proof::Proof checked=switch(proof::inspect(programs::code(p),programs::literals(p),false)){
        case .ok(v):{v}case .err(_):{return .err(10);}
    };
    var usize f=0;while(f<16){assert(programs::preparation(p).parameters[f]==checked.parameters[f]);f+=1;}
    assert(programs::preparation(p).calls.ready);
    var usize required=0;var usize absent=0;
    var usize calls=0;var usize views=0;var usize forwards=0;var usize returns=0;var usize pc=0;
    while(pc<programs::code(p).body.count){let usize at=pc*8;let u8 op=programs::code(p).body.code[at];
        if(op==66){let usize site=programs::code(p).body.code[at+5] as usize;let usize callee=programs::code(p).body.code[at+2] as usize;
            assert(site<16 && (programs::code(p).body.slice_elements[site]&128)!=0);
            assert(callee<16 && checked.elements[callee]==138 && checked.parameters[callee]==if(mode==3){2}else{1});
            let capture_plans::Entry cached=switch(capture_plans::lookup(ref programs::preparation(p).calls,ref programs::code(p).body,pc)){
                case .ok(v):{v}case .err(_):{return .err(10);}
            };
            required|=cached.required;absent|=cached.absent;calls+=1;}
        if(op==63){views+=1;}if(op==64){let usize callee=programs::code(p).body.code[at+2] as usize;
            assert(callee<16 && checked.elements[callee]==138 && checked.parameters[callee]==1);forwards+=1;}
        if(op==65){returns+=1;}pc+=1;
    }
    assert(calls==if(mode==1){2}else{1});assert(views>0 && returns>0);
    if(mode==1){assert(required!=0 && absent!=0);}else{assert(required==0 && absent==0);}
    if(mode==2){assert(forwards>0 && returns>=2);}else{assert(forwards==0);}return .ok(0);
}
// Independent raw verifier/dispatcher oracle, with the same metered output
// transaction, 64KiB owner backing and final seal as the owning invocation.
fn Result<Oracle,u8> raw_oracle(ref programs::Program p){
    var usize remaining=budget();var output::Transaction staged=switch(output::open_metered(16,true,ref mut remaining)){
        case .ok(v):{v}case .err(_):{return .err(11);}
    };
    let usize capacity=65536;assert(programs::preparation(p).capacity==capacity && remaining>1+capacity);
    var bytes::Buffer payload=switch(backing::prepare(capacity)){case .ok(v):{v}case .err(_):{return .err(12);}};
    remaining-=1+capacity;var runtime::State state=runtime::empty(capacity);var cursors::Stats stats=cursors::stats();
    begin_recipes();
    let execution::Scalar result=switch(execution::execute_output_scalar_quantized(
        programs::code(p),programs::literals(p),b"",false,ref mut state,bytes::view_mut(ref mut payload),
        ref mut remaining,ref mut staged,1,ref mut stats)){
        case .ok(v):{v}case .err(_):{return .err(13);}
    };
    assert(unsafe{bc_runtime_engine_test_recipe_count()}>0);
    assert(result.value==42 && result.remaining==remaining && stats.yields>0 && stats.maximum==1);
    let output::Published sealed=switch(output::seal_metered(ref mut staged,ref mut remaining)){
        case .ok(v):{v}case .err(_):{return .err(14);}
    };
    let output::Observation final=output::published_observation(ref sealed);
    assert(final.fuel==remaining && final.length==2 && final.emits==1 && bytes::equal(output::view(ref sealed),b"*)"));
    return .ok(Oracle{.value=result.value,.remaining=remaining,.output_bytes=final.length,.emits=final.emits});
}

// 1. Direct, chained caller capture, callee forwarding and second-input
// selection from real source. Distinct arrays expose a wrong selected input.
pub fn Result<usize,u8> actual_source_borrowed_returns_match_raw_and_synchronous_quanta(){
    var usize mode=0;while(mode<4){let programs::Program original=compiled(mode)?;
        let usize recipes=actual_recipes(ref original,mode)?;let Oracle oracle=raw_oracle(ref original)?;
        let programs::Program p=original;let inputs::Snapshot input=empty_input()?;
        begin_recipes();let programs::Execution baseline=programs::complete(ref p,ref input,budget(),16,true);no_recipes();
        expected(programs::observe(ref baseline),oracle);assert(programs::has_output(ref baseline) && bytes::equal(programs::view(ref baseline),b"*)"));
        var usize schedule=0;while(schedule<3){var cursors::Stats stats=cursors::stats();
            begin_recipes();let programs::Execution run=programs::complete_quantized(ref p,ref input,budget(),16,true,quantum(schedule,0),ref mut stats);no_recipes();
            same_completion(programs::observe(ref run),programs::observe(ref baseline));
            assert(programs::has_output(ref run) && bytes::equal(programs::view(ref run),b"*)"));
            assert(stats.calls>0 && stats.dispatched>0 && stats.maximum<=quantum(schedule,0));
            if(schedule==0){assert(stats.yields>0);}schedule+=1;
        }mode+=1;
    }return .ok(0);
}

// 2. Owning Engine synchronous and all fixed/mixed pending schedules agree
// exactly with the separately verified raw oracle, with no resume allocation.
pub fn Result<usize,u8> engine_pending_fixed_mixed_schedules_match_raw(){
    var usize mode=0;while(mode<4){let programs::Program raw=compiled(mode)?;let Oracle oracle=raw_oracle(ref raw)?;
        var engine::Engine e=created()?;let usize p=engine_program(ref mut e,mode)?;
        {let engine::Output baseline=synchronous(ref mut e,p,budget())?;expected_output(ref baseline,oracle);}ledger(ref e,0);
        var usize schedule=0;while(schedule<4){let usize i=bound(ref mut e,p,budget());
            assert(event(engine::prepare_instance(ref mut e,i)).kind==4);assert(memory(ref e).current>0);
            let engine::Event done=finish(ref mut e,i,schedule);
            {let engine::Output out=take(ref mut e,i)?;same_event(done,completion(ref out));expected_output(ref out,oracle);}
            destroy(ref mut e,i);ledger(ref e,0);counts(ref mut e,1,0,0);schedule+=1;
        }close(ref mut e,p);mode+=1;
    }return .ok(0);
}

// 3. Derive the whole-run price from raw execution. Exact Fuel succeeds at
// zero; one less fails without publishing staged bytes, identically in every
// owning synchronous/pending schedule, including terminal seal diagnostics.
pub fn Result<usize,u8> exact_and_one_less_fuel_preserve_output_and_diagnostics(){
    var usize mode=0;while(mode<4){let programs::Program raw=compiled(mode)?;let Oracle oracle=raw_oracle(ref raw)?;
        let inputs::Snapshot input=empty_input()?;let usize price=budget()-oracle.remaining;assert(price>1);
        var engine::Engine e=created()?;let usize p=engine_program(ref mut e,mode)?;var usize variant=0;
        while(variant<2){let usize fuel=price-variant;
            begin_recipes();let programs::Execution own=programs::complete(ref raw,ref input,fuel,16,true);no_recipes();
            let programs::Completion expected=programs::observe(ref own);
            let engine::Output baseline=synchronous(ref mut e,p,fuel)?;same_completion(engine::output_completion(ref baseline),expected);
            assert(bytes::equal(engine::output_view(ref baseline),programs::view(ref own)));
            if(variant==0){assert(expected.success && expected.value==42 && expected.remaining==0 && expected.output_bytes==2 && expected.emits==1);
                assert(programs::has_output(ref own) && engine::output_available(ref baseline) && bytes::equal(programs::view(ref own),b"*)"));}
            else{assert(!expected.success && expected.diagnostic.code.kind==8 && expected.output_bytes==0);
                assert(!programs::has_output(ref own) && !engine::output_available(ref baseline) && programs::view(ref own).len==0 && engine::output_view(ref baseline).len==0);}
            var usize schedule=0;while(schedule<4){let usize i=bound(ref mut e,p,fuel);assert(event(engine::prepare_instance(ref mut e,i)).kind==4);
                same_event(finish(ref mut e,i,schedule),completion(ref baseline));
                {let engine::Output out=take(ref mut e,i)?;same_completion(engine::output_completion(ref out),expected);
                    assert(engine::output_available(ref out)==engine::output_available(ref baseline));
                    assert(bytes::equal(engine::output_view(ref out),engine::output_view(ref baseline)));}
                destroy(ref mut e,i);ledger(ref e,0);schedule+=1;
            }variant+=1;
        }close(ref mut e,p);mode+=1;
    }return .ok(0);
}

fn void staged_emit(ref mut engine::Engine e,usize i){var usize ticks=0;var bool staged=false;
    while(!staged){assert(ticks<1000);assert(tick(e,i,1).kind==4);ticks+=1;
        switch(engine::output_copy_progress(e,i)){case .ok(v):{assert(v.total<=2);staged=v.total==2;}case .err(_):{assert(false);}};
    }rejected_take(e,i,11);
}
// 4. Two owners survive released Program pins and two Engine moves after real
// borrowed handoff/EMIT. Cancelling one hides its staged bytes and refunds its
// full preparation exactly once; its peer still completes with the raw price.
pub fn Result<usize,u8> pending_moves_released_pins_cancel_and_exact_refunds(){
    var usize mode=0;while(mode<4){let programs::Program raw=compiled(mode)?;let Oracle oracle=raw_oracle(ref raw)?;
        var engine::Engine original=created()?;let usize p=engine_program(ref mut original,mode)?;
        let usize a=bound(ref mut original,p,budget());let usize b=bound(ref mut original,p,budget());
        let usize retained=memory(ref original).current;let Heap ready=heap();
        assert(event(engine::prepare_instance(ref mut original,a)).kind==4);
        let usize pending=memory(ref original).current-retained;let Heap one=heap();assert(pending>0 && one.blocks>ready.blocks && one.bytes>ready.bytes);
        assert(event(engine::prepare_instance(ref mut original,b)).kind==4);ledger(ref original,retained+2*pending);
        staged_emit(ref mut original,a);let engine::Event saved=event(engine::observe(ref mut original,a));
        staged_emit(ref mut original,b);same_event(saved,event(engine::observe(ref mut original,a)));
        assert(id(engine::release_program(ref mut original,p))==p);counts(ref mut original,1,2,2);
        switch(engine::create_output_instance(ref mut original,p,budget(),16,true)){case .ok(_):{assert(false);}case .err(v):{assert(v.status==2);}};
        let Heap held=heap();var engine::Engine moved=original;same_heap(held);same_event(saved,event(engine::observe(ref mut moved,a)));
        assert(tick(ref mut moved,b,1).kind==4);same_event(saved,event(engine::observe(ref mut moved,a)));
        var engine::Engine e=moved;same_heap(held);let usize attempts=unsafe{probe_attempts()};begin_recipes();unsafe{bc_runtime_engine_test_fail(0)};
        let Result<engine::Event,engine::Error> result=engine::cancel_ready(ref mut e,a);unsafe{bc_runtime_engine_test_fail(-1)};
        let engine::Event stopped=event(result);assert(unsafe{probe_attempts()}==attempts && stopped.kind==3 && stopped.value==0 &&
            stopped.fuel_known && stopped.remaining==saved.remaining && stopped.diagnostic.code.kind==0);
        let Heap cancelled=Heap{.blocks=held.blocks-(one.blocks-ready.blocks),.bytes=held.bytes-(one.bytes-ready.bytes)};
        same_heap(cancelled);ledger(ref e,retained+pending);rejected_take(ref mut e,a,2);
        same_event(stopped,event(engine::cancel_ready(ref mut e,a)));same_event(stopped,event(engine::observe(ref mut e,a)));
        assert(unsafe{probe_attempts()}==attempts);same_heap(cancelled);ledger(ref e,retained+pending);
        let engine::Event done=finish(ref mut e,b,3);
        {let engine::Output out=take(ref mut e,b)?;same_event(done,completion(ref out));expected_output(ref out,oracle);}
        same_heap(ready);ledger(ref e,retained);counts(ref mut e,1,2,2);
        destroy(ref mut e,a);counts(ref mut e,1,1,1);destroy(ref mut e,b);counts(ref mut e,0,0,0);ledger(ref e,0);
        assert(id(engine::destroy(ref mut e))==0);mode+=1;
    }return .ok(0);
}

fn ref u8[] escaping_local_source(){
    return b"module app;fn ref mut u8[] bad(){var u8[2] local=[41;2];return ref mut local[..];}pub fn i32 chosen(){let ref mut u8[] s=bad();s[0]+=1;output::emit(ref s);return s[0] as i32;}";
}
fn ref u8[] escaping_input_source(){
    return b"module app;fn ref mut u8[] bad(ref mut u8[] x){var u8[2] local=[41;2];return ref mut local[..];}pub fn i32 chosen(){var u8[2] a=[41;2];let ref mut u8[] s=bad(ref mut a[..]);s[0]+=1;output::emit(ref s);return s[0] as i32;}";
}
fn Result<entries::Entry,u8> bad_selected_mode(usize mode){
    if(mode==0){return selected(escaping_local_source());}
    return selected(escaping_input_source());
}
// 5. A local owner must never escape, with or without a tempting input origin.
// Both owning compilers reject; failed Engine admission retains no program/pin.
pub fn Result<usize,u8> escaping_local_owner_is_rejected_by_both_owning_compilers(){
    var engine::Engine e=created()?;var usize mode=0;while(mode<2){
        switch(programs::compile(bad_selected_mode(mode)?,65536)){
            case .ok(_):{assert(false);}case .err(v):{assert(v.code.kind!=0);}
        };
        switch(engine::compile_output(ref mut e,bad_selected_mode(mode)?,65536)){
            case .ok(_):{assert(false);}case .err(v):{assert(v.diagnostic.code.kind!=0);}
        };counts(ref mut e,0,0,0);ledger(ref e,0);mode+=1;
    }assert(id(engine::destroy(ref mut e))==0);return .ok(0);
}

// A forward PREPARE64 and an ordinary CALL9 normalize to the same scalar
// proxy. The original dialect must still reject substituting CALL9, even when
// supplied the valid original result tags/origins and exact proved proxy.
fn void ordinary_call_cannot_replace_forward(ref programs::Program p){
    let proof::Proof checked=switch(proof::inspect(programs::code(p),programs::literals(p),false)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let return_ir::Signature signature=switch(return_ir::signature(programs::code(p))){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var candidates::Program normalized=*programs::code(p);
    assert(return_ir::normalize(ref mut normalized,ref signature).is_ok);
    let ref ir::Program body=ref programs::code(p).body;
    var borrowed_ir::Program changed=borrowed_ir::Program{.body=*body,.elements=checked.elements,.parameters=checked.parameters};
    var usize pc=0;while(pc<body.count && body.code[pc*8]!=64){pc+=1;}assert(pc<body.count);
    changed.body.code[pc*8]=9;
    switch(borrowed_proof::inspect_output_admitted(ref changed,ref normalized.body)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==pc);}
    };
}
fn void rejected_proof(ref candidates::Program candidate,ref programs::Program original){
    switch(proof::inspect(candidate,programs::literals(original),false)){
        case .ok(_):{assert(false);}case .err(v):{assert(v.kind==5);}
    };
}
// The proxy defines CALL66's usize identity; native capture never writes it.
// Each mutant must pass full canonical proof and fail only the recipe read guard.
fn void rejected_identity_read(ref candidates::Program candidate,ref programs::Program original,usize pc){
    let return_ir::Signature signature=switch(return_ir::signature(candidate)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var candidates::Program normalized=*candidate;
    assert(return_ir::normalize(ref mut normalized,ref signature).is_ok);
    assert(canonical::inspect_output_returns(ref normalized,programs::literals(original),false).is_ok);
    switch(proof::inspect(candidate,programs::literals(original),false)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==pc);}
    };
}
fn Result<usize,u8> call_bind_identity_cannot_feed_static_operands(){
    let ref u8[] source=b"module app;fn ref mut u8[] tail(ref mut u8[] x){return ref mut x;}fn usize width(ref u8[] data,usize n){return data.len+n;}pub fn i32 chosen(){var u8[2] a=[41;2];let ref mut u8[] s=tail(ref mut a[..]);let ref u8[] marker=b\"ABCD\";let usize lo=0;let usize hi=2;let ref u8[] part=marker[lo..hi];let usize n=width(ref part,hi);output::emit(ref part);s[0]+=1;return s[0] as i32;}";
    let programs::Program p=switch(programs::compile(selected(source)?,65536)){
        case .ok(v):{v}case .err(e):{unsafe{bc_runtime_engine_test_call_error(0,e.code.kind,e.code.offset)};return .err(11);}
    };
    let proof::Proof checked=switch(proof::inspect(programs::code(ref p),programs::literals(ref p),false)){
        case .ok(v):{v}case .err(_):{assert(false);return .err(12);}
    };
    let ref candidates::Program unit=programs::code(ref p);let ref ir::Program body=ref unit.body;
    var usize capture=256;var usize range=256;var usize call=256;var usize pc=body.starts[body.entry];
    while(pc<body.ends[body.entry]){let u8 op=body.code[pc*8];
        if(op==66){assert(capture==256);capture=pc;}if(op==76){assert(range==256);range=pc;}
        if(op==78){assert(call==256);call=pc;}pc+=1;
    }
    assert(capture<range && range<call && call<256);
    let usize tail=body.code[capture*8+2] as usize;let usize site=body.code[capture*8+5] as usize;
    assert(checked.elements[tail]==138 && checked.parameters[tail]==1 && site<16 && (body.slice_elements[site]&128)!=0);
    let u8 identity=body.code[capture*8+1];assert(identity<128 && body.types[identity as usize]==12);
    assert(body.code[range*8+3]!=identity && body.code[range*8+4]!=identity);
    let usize target=body.code[call*8+2] as usize;let usize formal=body.register_starts[target];
    let usize map=body.code[call*8+3] as usize;
    assert(body.arities[target]==2 && unit.parameters[formal]==3 && unit.parameters[formal+1]==0 && body.types[formal+1]==12);
    assert(map<body.call_count && body.call_arities[map]==2 && body.call_args[map*8+1]!=identity &&
        body.call_args[map*8+1]<128 && body.types[body.call_args[map*8+1] as usize]==12);
    // Without the RANGE76/CALL78 read checks these canonically valid mutants pass.
    {var candidates::Program bad=*unit;bad.body.code[range*8+3]=identity;rejected_identity_read(ref bad,ref p,range);}
    {var candidates::Program bad=*unit;bad.body.code[range*8+4]=identity;rejected_identity_read(ref bad,ref p,range);}
    {var candidates::Program bad=*unit;bad.body.call_args[map*8+1]=identity;rejected_identity_read(ref bad,ref p,call);}
    assert(proof::inspect(unit,programs::literals(ref p),false).is_ok);return .ok(0);
}
// 6. Mutate only compiler-produced candidates. Independent proof must reject
// false selected origins (wrong input/zero/Static/out of arity), wrong RETURN
// identity, invalid PREPARE_VIEW site and scalar reads of CALL66 identities.
pub fn Result<usize,u8> forged_selected_origins_and_return_recipes_are_rejected(){
    let usize static_reads=call_bind_identity_cannot_feed_static_operands()?;
    var usize mode=0;while(mode<4){let programs::Program p=compiled(mode)?;
        let usize checked=actual_recipes(ref p,mode)?;if(mode==2){ordinary_call_cannot_replace_forward(ref p);}
        var usize call=256;var usize returned=256;var usize prepared=256;var usize pc=0;
        while(pc<programs::code(ref p).body.count){let u8 op=programs::code(ref p).body.code[pc*8];
            if(op==66 && call==256){call=pc;}if(op==65 && returned==256){returned=pc;}if(op==63 && prepared==256){prepared=pc;}pc+=1;
        }assert(call<256 && returned<256 && prepared<256);
        let usize callee=programs::code(ref p).body.code[call*8+2] as usize;
        assert(programs::code(ref p).body.arities[callee]==if(mode==3){2}else{1});
        assert(programs::code(ref p).origins[callee]==if(mode==3){2}else{1});
        // mode 3's wrong origin is still in arity: only independently grounding
        // the original return recipe can reject that otherwise valid claim.
        let u8[4] forged=if(mode==3){[0,1,9,3]}else{[0,2,9,8]};var usize variant=0;while(variant<4){
            var candidates::Program bad=*programs::code(ref p);bad.origins[callee]=forged[variant];rejected_proof(ref bad,ref p);variant+=1;
        }
        {var candidates::Program bad=*programs::code(ref p);bad.body.code[returned*8+2]=127;rejected_proof(ref bad,ref p);}
        {var candidates::Program bad=*programs::code(ref p);bad.body.code[prepared*8+2]=16;rejected_proof(ref bad,ref p);}
        {var candidates::Program bad=*programs::code(ref p);bad.body.code[call*8+6]=16;rejected_proof(ref bad,ref p);}
        // Rejection of detached candidates cannot mutate the owning Program.
        let usize unchanged=actual_recipes(ref p,mode)?;let Oracle oracle=raw_oracle(ref p)?;assert(oracle.value==42);mode+=1;
    }return .ok(0);
}

fn void require_success(Result<usize,u8> result){switch(result){
    case .ok(_):{}case .err(e):{unsafe{bc_runtime_engine_test_call_error(0,e,0)};assert(false);}
};}
pub fn void run(){
    let Heap before=heap();
    require_success(actual_source_borrowed_returns_match_raw_and_synchronous_quanta());same_heap(before);
    require_success(engine_pending_fixed_mixed_schedules_match_raw());same_heap(before);
    require_success(exact_and_one_less_fuel_preserve_output_and_diagnostics());same_heap(before);
    require_success(pending_moves_released_pins_cancel_and_exact_refunds());same_heap(before);
    require_success(escaping_local_owner_is_rejected_by_both_owning_compilers());same_heap(before);
    require_success(forged_selected_origins_and_return_recipes_are_rejected());same_heap(before);
}
