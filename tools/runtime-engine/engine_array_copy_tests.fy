module engine_array_copy_tests;
import runtime_engine as engine;
import engine_lifecycle_tests as lifecycle;
import runtime_live_memory as live;
import runtime_input as inputs;
import module_output_program as programs;
import module_input_entry as input_entries;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import array_fill_cursor as fill;
import output_copy_cursor as copy;
import fuel as meter;
import std::bytes as bytes;

// Native Engine fixtures. Parent owns runner, native transport and layout.
// No environment/stack overrides, synthetic cursors or standalone VM oracle.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
struct Heap { usize blocks; usize bytes; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void same_heap(ref Heap h){assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes);}
fn usize id(Result<usize,engine::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn engine::Event event(Result<engine::Event,engine::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,
        .diagnostic=diagnostics::absent(errors::make(0,0)),.remaining=0,.fuel_known=false}}
};}
fn fill::State progress(ref engine::Engine e,usize i){return switch(engine::array_copy_progress(e,i)){
    case .ok(v):{v}case .err(_):{assert(false);fill::empty()}
};}
fn copy::State output_progress(ref engine::Engine e,usize i){return switch(engine::output_copy_progress(e,i)){
    case .ok(v):{v}case .err(_):{assert(false);copy::empty()}
};}
fn void rejected_progress(ref engine::Engine e,usize i,u32 status){switch(engine::array_copy_progress(e,i)){
    case .ok(_):{assert(false);}case .err(v):{assert(v.status==status);}
};}
fn void rejected_take(ref mut engine::Engine e,usize i,u32 status){switch(engine::take_output(e,i)){
    case .ok(_):{assert(false);}case .err(v):{assert(v.status==status);}
};}
fn void same_event(engine::Event a,engine::Event b){
    assert(a.kind==b.kind && a.value==b.value && a.remaining==b.remaining && a.fuel_known==b.fuel_known);
    assert(a.diagnostic.code.kind==b.diagnostic.code.kind && a.diagnostic.code.offset==b.diagnostic.code.offset);
    assert(a.diagnostic.at.source==b.diagnostic.at.source && a.diagnostic.at.start==b.diagnostic.at.start);
    assert(a.diagnostic.at.end==b.diagnostic.at.end);
}
fn void same_recipe(fill::State a,fill::State b){
    assert(a.op==b.op && a.pc==b.pc && a.frame==b.frame && a.destination==b.destination && a.offset==b.offset);
    assert(a.slot==b.slot && a.generation==b.generation && a.mark==b.mark && a.base==b.base && a.end==b.end);
    assert(a.depth==b.depth && a.element==b.element && a.length==b.length && a.stride==b.stride);
    assert(a.source_slot==b.source_slot && a.source_generation==b.source_generation);
    assert(a.source_base==b.source_base && a.source_end==b.source_end);
    var usize n=0;while(n<8){assert(a.encoded[n]==b.encoded[n]);n+=1;}
}
fn void same_progress(fill::State a,fill::State b){
    same_recipe(a,b);assert(a.active==b.active && a.written==b.written && a.total==b.total && a.last==b.last);
}
fn live::Observation instance(ref engine::Engine e){return switch(engine::instance_memory(e)){
    case .ok(v):{v}case .err(_):{assert(false);live::Observation{
        .instance_limit=0,.instances_limit=0,.current=0,.peak=0,.closed=false}}
};}
fn void ledger(ref engine::Engine e,usize current){
    let live::Observation l=instance(e);assert(l.current==current && current<=l.peak && l.peak<=l.instances_limit && !l.closed);
    switch(engine::program_memory(e)){
        case .ok(m):{assert(m.external_bytes==current && m.tracked_bytes==m.control_bytes+m.program_bytes+current);
            assert(m.tracked_bytes<=m.tracked_peak && m.tracked_peak<=m.engine_limit && !m.closed);}
        case .err(_):{assert(false);}
    };
}
fn void counts(ref mut engine::Engine e,usize codes,usize owners,usize pins){switch(engine::inspect(e)){
    case .ok(v):{assert(v.programs==codes && v.instances==owners && v.pins==pins && !v.closed);}
    case .err(_):{assert(false);}
};}
fn Result<engine::Engine,u8> created(){return switch(engine::create(engine::Limits{.programs=2,.instances=2,.fuel=16000000})){
    case .ok(v):{.ok(v)}case .err(_):{.err(1)}
};}
fn Result<input_entries::InputEntry,u8> selected(ref u8[] source){
    var sources::Builder b=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{return .err(2);}};
    if(!sources::add(ref mut b,b"app.brc",source).is_ok){return .err(3);}
    let sources::Snapshot s=switch(sources::freeze(ref b)){case .ok(v):{v}case .err(_):{return .err(4);}};
    let modules::Index index=switch(modules::build(s)){case .ok(v):{v}case .err(_):{return .err(5);}};
    return switch(input_entries::select_i32_input(index,b"app",b"chosen")){case .ok(v):{.ok(v)}case .err(_):{.err(6)}};
}
fn Result<usize,u8> compiled(ref mut engine::Engine e,ref u8[] source){
    return .ok(id(engine::compile_input_output(e,selected(source)?,65536)));
}
fn Result<usize,u8> bound(ref mut engine::Engine e,usize p,ref u8[] data,usize fuel,usize limit){
    var usize spent=0;let inputs::Snapshot input=switch(inputs::snapshot(data,inputs::hard_limit(),0,ref mut spent)){
        case .ok(v):{v}case .err(_):{return .err(7);}
    };
    return .ok(id(engine::create_input_output_instance(e,p,input,fuel,limit,true)));
}
fn Result<engine::Output,u8> take(ref mut engine::Engine e,usize i){return switch(engine::take_output(e,i)){
    case .ok(v):{.ok(v)}case .err(_):{.err(8)}
};}
fn engine::Event completion(ref engine::Output o){
    let programs::Completion c=engine::output_completion(o);return engine::Event{
        .kind=if(c.success){1}else{2},.value=c.value,.remaining=c.remaining,.diagnostic=c.diagnostic,.fuel_known=true};
}
fn void same_output(ref engine::Output a,ref engine::Output b){
    same_event(completion(a),completion(b));
    let programs::Completion x=engine::output_completion(a);let programs::Completion y=engine::output_completion(b);
    assert(x.emits==y.emits && x.output_bytes==y.output_bytes);
    assert(engine::output_available(a)==engine::output_available(b));
    assert(bytes::equal(engine::output_view(a),engine::output_view(b)));
}
fn void destroy(ref mut engine::Engine e,usize i){assert(id(engine::destroy_instance(e,i))==i);}
fn void close(ref mut engine::Engine e,usize p){assert(id(engine::release_program(e,p))==p);assert(id(engine::destroy(e))==0);}
fn Result<engine::Output,u8> synchronous(ref mut engine::Engine e,usize p,ref u8[] data,usize fuel,usize limit){
    let usize i=bound(e,p,data,fuel,limit)?;let engine::Event done=event(engine::execute_once(e,i));
    let engine::Output o=take(e,i)?;same_event(done,completion(ref o));destroy(e,i);return .ok(o);
}
fn void prepare(ref mut engine::Engine e,usize i){
    assert(event(engine::prepare_instance(e,i)).kind==4);lifecycle::warm(e,i);
    let fill::State a=progress(e,i);let copy::State o=output_progress(e,i);
    assert(!a.active && a.written==0 && a.total==0 && a.last==0);
    assert(!o.active && o.copied==0 && o.total==0 && o.last==0);
}
fn usize extent(fill::State a){return a.end-if(a.op==33 || a.op==34){a.mark}else{a.base};}
// Every actual resume denies the next SDK allocation, including terminal seal.
fn engine::Event tick(ref mut engine::Engine e,usize i,usize quantum){
    let engine::Event before=event(engine::observe(e,i));let fill::State prior=progress(e,i);
    let copy::State output_before=output_progress(e,i);let Heap h=heap();let usize charge=instance(e).current;
    let usize attempts=unsafe{probe_attempts()};unsafe{bc_runtime_engine_test_fail(0)};
    let Result<engine::Event,engine::Error> r=engine::step_instance(e,i,quantum);
    unsafe{bc_runtime_engine_test_fail(-1)};
    let engine::Event after=event(r);assert(unsafe{probe_attempts()}==attempts);
    assert(before.kind==4 && after.fuel_known && after.remaining<=before.remaining);
    assert(after.kind==4 || after.kind==1 || after.kind==2);same_event(after,event(engine::observe(e,i)));
    if(after.kind==4){
        let fill::State a=progress(e,i);let copy::State o=output_progress(e,i);
        assert(a.last<=4096 && o.last<=4096 && a.last+o.last<=4096);
        assert(a.total>=prior.total && a.total-prior.total==a.last);
        assert(o.total>=output_before.total && o.total-output_before.total==o.last);
        assert(!(a.active && o.active));
        if(a.active){
            assert((a.op==33 || a.op==34 || a.op==38 || a.op==40) && a.pc<256 && a.frame>0 && a.frame<32 && a.destination<16);
            assert(a.slot<16 && a.generation!=0 && a.mark<=a.base && a.base<a.end);
            assert(a.stride==1 || a.stride==4 || a.stride==8);
            assert(a.length>=1 && a.length<=4096 && a.end-a.base==a.length*a.stride);
            assert(a.written<extent(a));rejected_take(e,i,11);
            if(a.op==34 || a.op==38){
                assert(a.source_slot<16 && a.source_generation!=0);
                assert(a.source_base<a.source_end && a.source_end-a.source_base==a.length*a.stride);
                assert(a.slot!=a.source_slot && (a.end<=a.source_base || a.source_end<=a.base));
            }
        }
        if(prior.active && quantum==1){
            // Even the last continuation is prepaid; no following opcode runs.
            assert(after.remaining==before.remaining && o.total==output_before.total);
            let usize left=extent(prior)-prior.written;
            assert(a.last==if(left>4096){4096}else{left});
            if(a.active){same_recipe(prior,a);assert(a.written==prior.written+a.last);}
        }
        same_heap(ref h);ledger(e,charge);
    }else{rejected_progress(e,i,11);}
    return after;
}
fn engine::Event finish(ref mut engine::Engine e,usize i,usize quantum){
    var engine::Event s=event(engine::observe(e,i));var usize n=0;
    while(s.kind==4){assert(n<512);s=tick(e,i,quantum);n+=1;}return s;
}
fn fill::State seek(ref mut engine::Engine e,usize i,u8 op){
    var usize calls=0;while(true){assert(calls<256);assert(tick(e,i,1).kind==4);calls+=1;
        let fill::State a=progress(e,i);if(a.active && a.op==op){return a;}
    }
    return fill::empty();
}
fn ref u8[] wide_source(){return b"module app;pub fn i32 chosen(ref u8[] data){var i64[4096] a=[-9223372036854775808;4096];var i64[4096] b=a;a[0]=21;a[4095]=21;if(b[0]!=-9223372036854775808 || b[4095]!=-9223372036854775808){return 0;}b=a;a[0]=0;output::emit(ref data);if(b[0]==21 && b[4095]==21 && a[0]==0 && a[4095]==21){return 42;}return 0;}";}

// Group 1: actual COPY34 and source whole-array assignment STORE85(kind 3),
// normalized to recipe 38. Each 32768-byte operation has EIGHT write batches.
// Quantum one isolates final publication from subsequent guest endpoint reads.
fn Result<usize,u8> full_width_copy_and_selected_assignment_eight_batches(){
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,wide_source())?;
    let usize i=bound(ref mut e,p,b"\x00\xFF!",16000000,3)?;prepare(ref mut e,i);
    var engine::Event s=event(engine::observe(ref mut e,i));var usize calls=0;
    var usize creates=0;var usize copies=0;var usize assigns=0;var usize total=0;
    var usize copy_bytes=0;var usize assign_bytes=0;var bool reset=false;
    var fill::State created_array=fill::empty();var fill::State copied_array=fill::empty();
    while(s.kind==4){assert(calls<256);let fill::State before=progress(ref e,i);s=tick(ref mut e,i,1);calls+=1;
        if(s.kind==4){let fill::State a=progress(ref e,i);total=a.total;
            if(a.last!=0){
                assert(a.length==4096 && a.stride==8 && a.element==9 && a.last==4096);
                assert(a.written>0 && a.written%4096==0);
                if(a.op==33){creates+=1;created_array=a;assert(a.mark==0 && a.base==0 && a.end==32768);}
                else if(a.op==34){copies+=1;copy_bytes+=a.written-if(before.active){before.written}else{0};copied_array=a;
                    assert(a.mark==32768 && a.base==32768 && a.end==65536);
                    assert(a.source_slot==created_array.slot && a.source_generation==created_array.generation);
                    assert(a.source_base==0 && a.source_end==32768 && a.slot!=a.source_slot);
                }else{assert(a.op==38);assigns+=1;assign_bytes+=a.written-if(before.active){before.written}else{0};
                    assert(a.slot==copied_array.slot && a.generation==copied_array.generation);
                    assert(a.base==32768 && a.end==65536 && a.source_base==0 && a.source_end==32768);
                    assert(a.source_slot==created_array.slot && a.source_generation==created_array.generation);
                }
                assert(a.active==(a.written<32768));
            }
            if(before.last!=0 && a.last==0){reset=true;}
        }
    }
    assert(s.kind==1 && s.value==42 && creates==8 && copies==8 && assigns==8);
    assert(copy_bytes==32768 && assign_bytes==32768 && total==98304 && reset);
    let engine::Output o=take(ref mut e,i)?;assert(bytes::equal(engine::output_view(ref o),b"\x00\xFF!"));
    destroy(ref mut e,i);ledger(ref e,0);close(ref mut e,p);return .ok(0);
}

// Group 2: fixed/mixed quanta preserve exact Fuel, diagnostics and binary
// output against synchronous Engine execution. Larger host data uses Buffer.
fn Result<usize,u8> fixed_and_mixed_quanta_and_scalar_endpoints(){
    var bytes::Buffer data=switch(bytes::with_capacity(8193)){
        case .ok(v):{v}case .err(_):{return .err(9);}
    };
    assert(bytes::resize_zeroed(ref mut data,8193).is_ok);
    {let ref mut u8[] v=bytes::view_mut(ref mut data);v[0]=255;v[4095]=42;v[4096]=128;v[8192]=1;}
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,wide_source())?;
    let engine::Output baseline=synchronous(ref mut e,p,bytes::view(ref data),16000000,8193)?;
    assert(completion(ref baseline).kind==1 && completion(ref baseline).value==42);
    let usize[3] fixed=[1,7,4096];let usize[5] mixed=[1,2,64,3,4096];var usize variant=0;
    while(variant<4){
        let usize i=bound(ref mut e,p,bytes::view(ref data),16000000,8193)?;prepare(ref mut e,i);
        var engine::Event s=event(engine::observe(ref mut e,i));var usize calls=0;
        while(s.kind==4){assert(calls<256);
            let usize q=if(variant==3){mixed[calls%5]}else{fixed[variant]};s=tick(ref mut e,i,q);calls+=1;
        }
        same_event(s,completion(ref baseline));let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);
        assert(bytes::equal(engine::output_view(ref o),bytes::view(ref data)));destroy(ref mut e,i);ledger(ref e,0);variant+=1;
    }
    assert(id(engine::release_program(ref mut e,p))==p);
    // The wide fixture covers i64; these cover the other five scalar domains.
    variant=0;while(variant<5){
        let ref u8[] source=if(variant==0){b"module app;pub fn i32 chosen(ref u8[] data){var i32[2] a=[-2147483648;2];var i32[2] b=a;a[0]=21;a[1]=21;b=a;a[0]=0;return b[0]+b[1];}"}
        else if(variant==1){b"module app;pub fn i32 chosen(ref u8[] data){var bool[2] a=[true;2];var bool[2] b=a;a[0]=false;if(!b[0]){return 0;}b=a;if(!b[0] && b[1]){return 42;}return 0;}"}
        else if(variant==2){b"module app;pub fn i32 chosen(ref u8[] data){var u8[2] a=[255;2];var u8[2] b=a;a[0]=42;b=a;if(b[1]==255){return b[0] as i32;}return 0;}"}
        else if(variant==3){b"module app;pub fn i32 chosen(ref u8[] data){var u32[2] a=[4294967295;2];var u32[2] b=a;a[0]=0;if(b[0]!=4294967295){return 0;}b=a;if(b[0]==0 && b[1]==4294967295){return 42;}return 0;}"}
        else{b"module app;pub fn i32 chosen(ref u8[] data){var usize[2] a=[18446744073709551615;2];var usize[2] b=a;a[0]=0;if(b[0]!=18446744073709551615){return 0;}b=a;if(b[0]==0 && b[1]==18446744073709551615){return 42;}return 0;}"};
        let usize scalar=compiled(ref mut e,source)?;let engine::Output expected=synchronous(ref mut e,scalar,b"",16000000,0)?;
        assert(completion(ref expected).kind==1 && completion(ref expected).value==42);
        let usize i=bound(ref mut e,scalar,b"",16000000,0)?;prepare(ref mut e,i);
        same_event(finish(ref mut e,i,1),completion(ref expected));let engine::Output result=take(ref mut e,i)?;
        same_output(ref result,ref expected);destroy(ref mut e,i);assert(id(engine::release_program(ref mut e,scalar))==scalar);variant+=1;
    }
    assert(id(engine::destroy(ref mut e))==0);return .ok(0);
}

// Group 3: COPY padding, other array work and output share one allowance.
// Then a complete 4096-byte bool scan must defer after even ONE output byte;
// validation counts as work, not writes, and identity assignment writes zero.
fn Result<usize,u8> shared_padding_output_and_bool_validation_admission(){
    var engine::Engine e=created()?;
    let usize p=compiled(ref mut e,b"module app;pub fn i32 chosen(ref u8[] data){var i64[256] a=[21;256];let u8[1] pad=[80;1];var i64[256] b=a;b=a;output::emit(ref data);if(pad[0]==80 && a[0]==21 && a[255]==21 && b[0]==21 && b[255]==21){return 42;}return 0;}")?;
    let u8[3072] data=[73;3072];let engine::Output baseline=synchronous(ref mut e,p,ref data,16000000,3072)?;
    let usize i=bound(ref mut e,p,ref data,16000000,3072)?;prepare(ref mut e,i);
    assert(tick(ref mut e,i,4096).kind==4);let fill::State a=progress(ref e,i);
    assert(a.active && a.op==34 && a.mark==2049 && a.base==2056 && a.end==4104);
    assert(a.source_base==0 && a.source_end==2048 && a.written==2047 && a.total==4096 && a.last==4096);
    assert(output_progress(ref e,i).last==0);
    assert(tick(ref mut e,i,4096).kind==4);let fill::State b=progress(ref e,i);let copy::State o=output_progress(ref e,i);
    assert(!b.active && b.op==38 && b.written==2048 && b.total==6152 && b.last==2056);
    assert(b.slot==a.slot && b.generation==a.generation && b.source_slot==a.source_slot);
    assert(o.active && o.copied==2040 && o.last==2040 && o.total==2040);
    same_event(finish(ref mut e,i,7),completion(ref baseline));let engine::Output result=take(ref mut e,i)?;
    same_output(ref result,ref baseline);assert(completion(ref result).value==42);destroy(ref mut e,i);
    assert(id(engine::release_program(ref mut e,p))==p);

    var usize variant=0;while(variant<2){
    let ref u8[] bool_source=if(variant==0){b"module app;pub fn i32 chosen(ref u8[] data){var bool[4096] a=[true;4096];output::emit(ref data);let bool[4096] b=a;a=a;if(a[0] && a[4095] && b[0] && b[4095]){return 42;}return 0;}"}
        else{b"module app;pub fn i32 chosen(ref u8[] data){var bool[4096] a=[true;4096];let u8[1] pad=[80;1];let bool[4096] b=a;a=a;output::emit(ref data);if(pad[0]==80 && a[0] && a[4095] && b[0] && b[4095]){return 42;}return 0;}"};
    let usize bools=compiled(ref mut e,bool_source)?;
    let engine::Output expected=synchronous(ref mut e,bools,b"!",16000000,1)?;
    // A quantum-one peer stops immediately AFTER the preceding one-byte work,
    // BEFORE even attempting COPY. Deferral must preserve exactly its Fuel.
    let usize peer=bound(ref mut e,bools,b"!",16000000,1)?;prepare(ref mut e,peer);
    var usize peer_calls=0;var bool reached=false;
    while(!reached){assert(peer_calls<64);assert(tick(ref mut e,peer,1).kind==4);peer_calls+=1;
        reached=if(variant==0){output_progress(ref e,peer).total==1}else{progress(ref e,peer).total==4097};
    }
    let engine::Event uncharged=event(engine::observe(ref mut e,peer));destroy(ref mut e,peer);
    let usize j=bound(ref mut e,bools,b"!",16000000,1)?;prepare(ref mut e,j);
    assert(tick(ref mut e,j,4096).kind==4);let fill::State first=progress(ref e,j);
    assert(!first.active && first.op==33 && first.total==4096 && first.written==4096);
    assert(tick(ref mut e,j,4096).kind==4);let fill::State deferred=progress(ref e,j);
    assert(!deferred.active && deferred.op==33 && deferred.total==4096+variant && deferred.last==variant);
    assert(output_progress(ref e,j).last==1-variant);
    same_event(event(engine::observe(ref mut e,j)),uncharged);
    let engine::Event before=event(engine::observe(ref mut e,j));
    assert(tick(ref mut e,j,1).kind==4);let fill::State scanned=progress(ref e,j);
    assert(scanned.active && scanned.op==34 && scanned.written==0 && scanned.total==8192+variant && scanned.last==4096);
    let usize copy_price=switch(meter::array_instruction(34,1,4096,true)){case .some(v):{v}case .none:{assert(false);0}};
    assert(before.remaining-event(engine::observe(ref mut e,j)).remaining==1+copy_price);
    assert(tick(ref mut e,j,1).kind==4);let fill::State copied=progress(ref e,j);
    assert(!copied.active && copied.op==34 && copied.written==4096 && copied.total==12288+variant && copied.last==4096);
    var usize calls=0;var bool identity=false;
    while(!identity){assert(calls<32);let engine::Event prior=event(engine::observe(ref mut e,j));
        assert(tick(ref mut e,j,1).kind==4);calls+=1;let fill::State current=progress(ref e,j);
        if(current.op==38){
            assert(!current.active && current.written==0 && current.total==16384+variant && current.last==4096);
            assert(current.slot==current.source_slot && current.generation==current.source_generation);
            assert(current.base==current.source_base && current.end==current.source_end);
            let usize price=switch(meter::aggregate_place_instruction(85,false,1,4096,true,false)){
                case .some(v):{v}case .none:{assert(false);0}
            };
            assert(prior.remaining-event(engine::observe(ref mut e,j)).remaining==1+price);identity=true;
        }
    }
    same_event(finish(ref mut e,j,7),completion(ref expected));let engine::Output bool_result=take(ref mut e,j)?;
    same_output(ref bool_result,ref expected);assert(completion(ref bool_result).value==42);
    destroy(ref mut e,j);ledger(ref e,0);assert(id(engine::release_program(ref mut e,bools))==bools);variant+=1;
    }
    assert(id(engine::destroy(ref mut e))==0);return .ok(0);
}

// Group 4: cancellation during unpublished COPY or partially written STORE85
// refunds preparation, retains bound input, hides staged output and is idempotent.
fn Result<usize,u8> partial_copy_and_assignment_cancel_refund(){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"prefix\");var i64[4096] a=[21;4096];var i64[4096] b=a;b=a;output::emit(ref data);if(b[0]==21 && b[4095]==21){return 42;}return 0;}";
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,source)?;let u8[2] ops=[34,38];var usize variant=0;
    while(variant<2){
        let usize i=bound(ref mut e,p,b"\x00!",16000000,8)?;let usize input=instance(ref e).current;let Heap ready=heap();
        prepare(ref mut e,i);let fill::State a=seek(ref mut e,i,ops[variant]);
        assert(a.written==4096 && a.end-a.base==32768 && output_progress(ref e,i).total==6);
        let engine::Event running=event(engine::observe(ref mut e,i));rejected_take(ref mut e,i,11);
        let usize attempts=unsafe{probe_attempts()};
        let engine::Event stopped=lifecycle::stop(ref mut e,i);assert(unsafe{probe_attempts()}==attempts);
        assert(stopped.kind==3 && stopped.value==0 && stopped.fuel_known && stopped.remaining==running.remaining);
        assert(stopped.diagnostic.code.kind==0);same_heap(ref ready);ledger(ref e,input);
        rejected_progress(ref e,i,11);rejected_take(ref mut e,i,2);
        same_event(stopped,event(engine::cancel_ready(ref mut e,i)));same_event(stopped,event(engine::observe(ref mut e,i)));
        same_heap(ref ready);destroy(ref mut e,i);ledger(ref e,0);rejected_progress(ref e,i,2);variant+=1;
    }close(ref mut e,p);return .ok(0);
}

// Group 5: distinct source/destination recipes survive interleaving, release of
// Program handles, two Engine moves and destruction of the completed peer.
fn Result<usize,u8> interleaving_moves_and_released_program_pins(){
    let ref u8[] source=b"module app;pub fn i32 chosen(ref u8[] data){var i64[4096] a=[data[0] as i64;4096];var i64[4096] b=a;a[0]=0;b=a;output::emit(ref data);if(b[0]!=0 || b[4095]!=data[0] as i64){return 0;}return (data[0] as i32)*2;}";
    var engine::Engine original=created()?;let usize p=compiled(ref mut original,source)?;
    let engine::Output baseline=synchronous(ref mut original,p,b"\x15\x00",16000000,2)?;
    let usize a=bound(ref mut original,p,b"\x14\xFF",16000000,2)?;
    let usize b=bound(ref mut original,p,b"\x15\x00",16000000,2)?;
    prepare(ref mut original,a);prepare(ref mut original,b);
    let fill::State first=seek(ref mut original,a,34);let engine::Event saved=event(engine::observe(ref mut original,a));
    let fill::State second=seek(ref mut original,b,38);
    assert(first.written==4096 && second.written==4096);
    same_progress(first,progress(ref original,a));same_event(saved,event(engine::observe(ref mut original,a)));
    assert(id(engine::release_program(ref mut original,p))==p);let Heap held=heap();
    var engine::Engine moved=original;same_heap(ref held);counts(ref mut moved,1,2,2);
    same_progress(first,progress(ref moved,a));same_progress(second,progress(ref moved,b));
    assert(tick(ref mut moved,b,1).kind==4);same_progress(first,progress(ref moved,a));
    var engine::Engine e=moved;same_heap(ref held);
    let engine::Event done_b=finish(ref mut e,b,7);same_event(done_b,completion(ref baseline));
    let engine::Output out_b=take(ref mut e,b)?;same_output(ref out_b,ref baseline);destroy(ref mut e,b);
    counts(ref mut e,1,1,1);same_progress(first,progress(ref e,a));same_event(saved,event(engine::observe(ref mut e,a)));
    let engine::Event done_a=finish(ref mut e,a,4096);assert(done_a.kind==1 && done_a.value==40);
    let engine::Output out_a=take(ref mut e,a)?;destroy(ref mut e,a);ledger(ref e,0);counts(ref mut e,0,0,0);
    assert(id(engine::destroy(ref mut e))==0);
    same_output(ref out_b,ref baseline);assert(bytes::equal(engine::output_view(ref out_a),b"\x14\xFF"));return .ok(0);
}

// Group 6: measure admission at actual COPY34 and STORE85, including SELECT.
// Exact price prepays all eight batches at zero Fuel. One less writes nothing
// for that instruction. Whole-run exact Fuel also completes output sealing.
fn Result<usize,u8> exact_fuel_and_one_less_before_copy_and_selected_store(){
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,wide_source())?;
    let engine::Output full=synchronous(ref mut e,p,b"!",16000000,1)?;
    assert(completion(ref full).kind==1 && completion(ref full).value==42);
    let usize price=16000000-completion(ref full).remaining;
    let usize exact=bound(ref mut e,p,b"!",price,1)?;prepare(ref mut e,exact);
    let engine::Event done=finish(ref mut e,exact,7);assert(done.kind==1 && done.value==42 && done.remaining==0);
    let engine::Output whole=take(ref mut e,exact)?;assert(bytes::equal(engine::output_view(ref whole),b"!"));destroy(ref mut e,exact);
    let u8[2] ops=[34,38];var usize target=0;
    while(target<2){
        let usize measured=bound(ref mut e,p,b"!",16000000,1)?;prepare(ref mut e,measured);
        var usize admission=0;var usize prior_total=0;var usize calls=0;
        while(admission==0){assert(calls<256);let engine::Event before=event(engine::observe(ref mut e,measured));
            let fill::State previous=progress(ref e,measured);assert(tick(ref mut e,measured,1).kind==4);calls+=1;
            let fill::State a=progress(ref e,measured);
            if(a.active && a.op==ops[target]){
                let Option<usize> priced=if(target==0){meter::array_instruction(34,8,4096,false)}
                    else{meter::aggregate_place_instruction(85,false,8,4096,false,false)};
                let usize extra=switch(priced){case .some(v):{v}case .none:{assert(false);0}};
                assert(before.remaining-event(engine::observe(ref mut e,measured)).remaining==1+extra);
                admission=16000000-before.remaining+1+extra;prior_total=previous.total;
            }
        }
        destroy(ref mut e,measured);assert(admission>0 && admission<price);
        var usize short=0;while(short<2){
            let usize budget=admission-short;let engine::Output baseline=synchronous(ref mut e,p,b"!",budget,1)?;
            let usize i=bound(ref mut e,p,b"!",budget,1)?;prepare(ref mut e,i);
            var engine::Event s=event(engine::observe(ref mut e,i));var usize total=0;var usize batches=0;var usize resumes=0;
            while(s.kind==4){assert(resumes<256);s=tick(ref mut e,i,1);resumes+=1;
                if(s.kind==4){let fill::State a=progress(ref e,i);total=a.total;
                    if(short==1){assert(a.total<=prior_total && !(a.active && a.op==ops[target]));}
                    else if(a.total>prior_total){
                        assert(s.remaining==0 && a.op==ops[target]);
                        if(a.last!=0){assert(a.last==4096);batches+=1;}
                    }
                }
            }
            assert(s.kind==2 && s.diagnostic.code.kind==8 && s.diagnostic.code.offset!=0);
            assert(total==prior_total+if(short==0){32768}else{0});assert(batches==if(short==0){8}else{0});
            same_event(s,completion(ref baseline));let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);
            assert(!engine::output_available(ref o) && engine::output_view(ref o).len==0);
            assert(engine::output_completion(ref o).emits==0);destroy(ref mut e,i);ledger(ref e,0);short+=1;
        }target+=1;
    }close(ref mut e,p);return .ok(0);
}
pub fn void run(){
    let Heap before=heap();
    assert(full_width_copy_and_selected_assignment_eight_batches().is_ok);same_heap(ref before);
    assert(fixed_and_mixed_quanta_and_scalar_endpoints().is_ok);same_heap(ref before);
    assert(shared_padding_output_and_bool_validation_admission().is_ok);same_heap(ref before);
    assert(partial_copy_and_assignment_cancel_refund().is_ok);same_heap(ref before);
    assert(interleaving_moves_and_released_program_pins().is_ok);same_heap(ref before);
    assert(exact_fuel_and_one_less_before_copy_and_selected_store().is_ok);same_heap(ref before);
}
