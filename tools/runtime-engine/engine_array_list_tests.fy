module engine_array_list_tests;
import runtime_engine as engine;
import engine_lifecycle_tests as lifecycle;
import runtime_live_memory as live;
import runtime_input as inputs;
import module_output_program as programs;
import module_input_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import array_fill_cursor as fill;
import output_copy_cursor as copy;
import fuel as meter;
import std::bytes as bytes;

// Actual-source Engine fixtures only. Parent owns runner/transport/integration.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
struct Heap { usize blocks; usize bytes; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void same_heap(Heap h){assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes);}
fn usize id(Result<usize,engine::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn engine::Event event(Result<engine::Event,engine::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,.remaining=0,.fuel_known=false,.diagnostic=diagnostics::absent(errors::make(0,0))}}};}
fn fill::State progress(ref engine::Engine e,usize i){return switch(engine::array_copy_progress(e,i)){case .ok(v):{v}case .err(_):{assert(false);fill::empty()}};}
fn copy::State output(ref engine::Engine e,usize i){return switch(engine::output_copy_progress(e,i)){case .ok(v):{v}case .err(_):{assert(false);copy::empty()}};}
fn live::Observation memory(ref engine::Engine e){return switch(engine::instance_memory(e)){case .ok(v):{v}case .err(_):{assert(false);live::Observation{.instance_limit=0,.instances_limit=0,.current=0,.peak=0,.closed=false}}};}
fn void ledger(ref engine::Engine e,usize current){let live::Observation l=memory(e);assert(l.current==current && current<=l.peak && l.peak<=l.instances_limit && !l.closed);
    switch(engine::program_memory(e)){case .ok(m):{assert(m.external_bytes==current && m.tracked_bytes==m.control_bytes+m.program_bytes+current && m.tracked_bytes<=m.tracked_peak && m.tracked_peak<=m.engine_limit && !m.closed);}case .err(_):{assert(false);}};}
fn void same_event(engine::Event a,engine::Event b){assert(a.kind==b.kind && a.value==b.value && a.remaining==b.remaining && a.fuel_known==b.fuel_known);
    assert(a.diagnostic.code.kind==b.diagnostic.code.kind && a.diagnostic.code.offset==b.diagnostic.code.offset);
    assert(a.diagnostic.at.source==b.diagnostic.at.source && a.diagnostic.at.start==b.diagnostic.at.start && a.diagnostic.at.end==b.diagnostic.at.end);}
fn void same_recipe(fill::State a,fill::State b){assert(a.op==b.op && a.pc==b.pc && a.frame==b.frame && a.destination==b.destination && a.offset==b.offset);
    assert(a.slot==b.slot && a.generation==b.generation && a.mark==b.mark && a.base==b.base && a.end==b.end && a.depth==b.depth);
    assert(a.element==b.element && a.length==b.length && a.stride==b.stride && a.source_slot==b.source_slot && a.source_generation==b.source_generation && a.source_base==b.source_base && a.source_end==b.source_end);
    var usize n=0;while(n<8){assert(a.encoded[n]==b.encoded[n]);n+=1;}}
fn void same_progress(fill::State a,fill::State b){same_recipe(a,b);assert(a.active==b.active && a.list_gathered==b.list_gathered && a.list_encoded==b.list_encoded && a.written==b.written && a.total==b.total && a.last==b.last);}
fn void rejected_take(ref mut engine::Engine e,usize i,u32 status){switch(engine::take_output(e,i)){case .ok(_):{assert(false);}case .err(v):{assert(v.status==status);}};}
fn void rejected_progress(ref engine::Engine e,usize i,u32 status){switch(engine::array_copy_progress(e,i)){case .ok(_):{assert(false);}case .err(v):{assert(v.status==status);}};}
fn Result<engine::Engine,u8> created(){return switch(engine::create(engine::Limits{.programs=2,.instances=2,.fuel=16000000})){case .ok(v):{.ok(v)}case .err(_):{.err(1)}};}
fn Result<usize,u8> compiled(ref mut engine::Engine e,ref u8[] source){
    var sources::Builder b=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{return .err(2);}};
    if(!sources::add(ref mut b,b"app.brc",source).is_ok){return .err(3);}
    let sources::Snapshot s=switch(sources::freeze(ref b)){case .ok(v):{v}case .err(_):{return .err(4);}};
    let modules::Index index=switch(modules::build(s)){case .ok(v):{v}case .err(_):{return .err(5);}};
    let entries::InputEntry chosen=switch(entries::select_i32_input(index,b"app",b"chosen")){case .ok(v):{v}case .err(_):{return .err(6);}};
    return .ok(id(engine::compile_input_output(e,chosen,65536)));}
fn Result<usize,u8> bound(ref mut engine::Engine e,usize p,ref u8[] data,usize fuel){var usize spent=0;
    let inputs::Snapshot input=switch(inputs::snapshot(data,inputs::hard_limit(),0,ref mut spent)){case .ok(v):{v}case .err(_):{return .err(7);}};
    return .ok(id(engine::create_input_output_instance(e,p,input,fuel,data.len+3,true)));}
fn Result<engine::Output,u8> take(ref mut engine::Engine e,usize i){return switch(engine::take_output(e,i)){case .ok(v):{.ok(v)}case .err(_):{.err(8)}};}
fn engine::Event completion(ref engine::Output o){let programs::Completion c=engine::output_completion(o);return engine::Event{.kind=if(c.success){1}else{2},.value=c.value,.remaining=c.remaining,.fuel_known=true,.diagnostic=c.diagnostic};}
fn void same_output(ref engine::Output a,ref engine::Output b){same_event(completion(a),completion(b));let programs::Completion x=engine::output_completion(a);let programs::Completion y=engine::output_completion(b);
    assert(x.emits==y.emits && x.output_bytes==y.output_bytes && engine::output_available(a)==engine::output_available(b) && bytes::equal(engine::output_view(a),engine::output_view(b)));}
fn void destroy(ref mut engine::Engine e,usize i){assert(id(engine::destroy_instance(e,i))==i);}
fn void close(ref mut engine::Engine e,usize p){assert(id(engine::release_program(e,p))==p);assert(id(engine::destroy(e))==0);}
fn Result<engine::Output,u8> synchronous(ref mut engine::Engine e,usize p,ref u8[] data,usize fuel){
    let usize i=bound(e,p,data,fuel)?;let engine::Event done=event(engine::execute_once(e,i));let engine::Output o=take(e,i)?;same_event(done,completion(ref o));destroy(e,i);return .ok(o);}
fn void prepare(ref mut engine::Engine e,usize i){assert(event(engine::prepare_instance(e,i)).kind==4);lifecycle::warm(e,i);let fill::State a=progress(e,i);let copy::State o=output(e,i);
    assert(!a.active && a.written==0 && a.total==0 && a.last==0 && a.list_gathered==0 && a.list_encoded==0 && !o.active && o.total==0 && o.last==0);}
fn usize extent(fill::State a){return a.end-if(a.op==33 || a.op==34 || a.op==80){a.mark}else{a.base};}
// Every step, including final seal, denies the next SDK allocation.
fn engine::Event tick(ref mut engine::Engine e,usize i,usize q){let engine::Event before=event(engine::observe(e,i));let fill::State prior=progress(e,i);let copy::State old=output(e,i);
    let Heap h=heap();let usize charge=memory(e).current;let usize attempts=unsafe{probe_attempts()};unsafe{bc_runtime_engine_test_fail(0)};
    let Result<engine::Event,engine::Error> r=engine::step_instance(e,i,q);unsafe{bc_runtime_engine_test_fail(-1)};let engine::Event after=event(r);
    assert(unsafe{probe_attempts()}==attempts && before.kind==4 && after.fuel_known && after.remaining<=before.remaining);same_event(after,event(engine::observe(e,i)));
    if(after.kind==4){let fill::State a=progress(e,i);let copy::State o=output(e,i);
        assert(a.last+o.last<=4096 && a.total>=prior.total && a.total-prior.total==a.last && o.total>=old.total && o.total-old.total==o.last && !(a.active && o.active));
        if(a.active){assert(a.pc<256 && a.frame>0 && a.frame<32 && a.destination<16 && a.slot<16 && a.generation!=0 && a.written<extent(a));rejected_take(e,i,11);}
        if(a.op==80 || a.op==81){assert(a.length>0 && a.length<=64 && a.stride==8 && a.list_gathered<=a.length && a.list_encoded<=a.length);
            assert(a.list_encoded==0 || a.list_gathered==a.length);assert(a.written==0 || a.list_encoded==a.length);
            assert(a.total>=a.list_gathered*8+a.list_encoded*a.stride+a.written);}
        if(prior.active && q==1){same_recipe(prior,a);assert(after.remaining==before.remaining && o.total==old.total);
            assert(a.list_gathered>=prior.list_gathered && a.list_encoded>=prior.list_encoded && a.written>=prior.written);
            assert(a.last==(a.list_gathered-prior.list_gathered)*8+(a.list_encoded-prior.list_encoded)*a.stride+a.written-prior.written);}
        same_heap(h);ledger(e,charge);
    }else{assert(after.kind==1 || after.kind==2);rejected_progress(e,i,11);}return after;}
fn engine::Event finish(ref mut engine::Engine e,usize i,usize q){var engine::Event s=event(engine::observe(e,i));var usize n=0;while(s.kind==4){assert(n<512);s=tick(e,i,q);n+=1;}return s;}
fn void append(ref mut bytes::Buffer b,ref u8[] text){assert(bytes::append(b,text).is_ok);}
fn Result<bytes::Buffer,u8> source(bool replace,usize length){assert(length==32 || length==64);var bytes::Buffer b=bytes::empty();
    append(ref mut b,b"module app;pub fn i32 chosen(ref u8[] data){let u8[1] pad=[80;1];let shadow=pad;");
    if(replace){append(ref mut b,if(length==32){b"var i64[32] a=[0;32];"}else{b"var i64[64] a=[0;64];"});}
    append(ref mut b,b"output::emit(ref data);");
    append(ref mut b,if(replace){b"a=["}else if(length==32){b"var i64[32] a=["}else{b"var i64[64] a=["});
    append(ref mut b,b"-9223372036854775808,data[0] as i64,");var usize n=2;while(n+1<length){append(ref mut b,b"21,");n+=1;}
    append(ref mut b,b"9223372036854775807];output::emit(ref b\"\\x00\\xFF!\");if(pad[0]!=80 || shadow[0]!=80 || a[0]!=-9223372036854775808 || a[1]!=data[0] as i64");
    append(ref mut b,if(length==32){b" || a[30]!=21 || a[31]!=9223372036854775807){return 0;}return 42;}"}else{b" || a[62]!=21 || a[63]!=9223372036854775807){return 0;}return 42;}"});return .ok(b);}
fn Result<bytes::Buffer,u8> binary(usize length){var bytes::Buffer b=switch(bytes::with_capacity(length)){case .ok(v):{v}case .err(_):{return .err(9);}};
    assert(length>0 && bytes::resize_zeroed(ref mut b,length).is_ok);let ref mut u8[] v=bytes::view_mut(ref mut b);v[0]=21;v[length/2]=255;v[length-1]=128;return .ok(b);}
fn usize initial(bool replace){return if(replace){264}else{2};}
fn usize list_work(bool replace){return if(replace){768}else{774};}
fn usize price(bool replace){return if(!replace){meter::list_instruction(false,32,256)}else{switch(meter::aggregate_place_instruction(87,false,8,32,false,true)){case .some(v):{v}case .none:{assert(false);0}}};}
fn void binary_output(ref engine::Output o,ref u8[] data){let ref u8[] v=engine::output_view(o);assert(engine::output_available(o) && v.len==data.len+3);
    assert(bytes::equal(v[..data.len],data) && bytes::equal(v[data.len..],b"\x00\xFF!") && engine::output_completion(o).emits==2);}
// 1. One allowance covers pad fill, shadow COPY, output and all list stages.
// Three remaining bytes admit/prepay an active recipe without gathering a cell.
fn Result<usize,u8> stages_padding_and_frozen_publication(){var usize target=0;while(target<2){let bool replace=target==1;
    let bytes::Buffer text=source(replace,32)?;var engine::Engine e=created()?;let usize p=compiled(ref mut e,bytes::view(ref text))?;
    let usize[4] room=[3,128,384,576];var usize stage=0;while(stage<4){let bytes::Buffer data=binary(4096-initial(replace)-room[stage])?;
        let engine::Output baseline=synchronous(ref mut e,p,bytes::view(ref data),16000000)?;let usize i=bound(ref mut e,p,bytes::view(ref data),16000000)?;prepare(ref mut e,i);
        assert(tick(ref mut e,i,4096).kind==4);let fill::State a=progress(ref e,i);let copy::State o=output(ref e,i);
        assert(a.active && a.op==if(replace){81}else{80} && a.length==32 && a.mark==2 && a.base==8 && a.end==264);
        assert(a.list_gathered==if(stage==0){0}else if(stage==1){16}else{32});assert(a.list_encoded==if(stage<2){0}else if(stage==2){16}else{32});
        assert(a.written==if(stage==3){64}else{0} && a.total==initial(replace)+if(stage==0){0}else{room[stage]});
        assert(a.last==a.total && !o.active && o.total==bytes::len(ref data) && a.last+o.last==4096-if(stage==0){3}else{0});
        let engine::Event prepaid=event(engine::observe(ref mut e,i));rejected_take(ref mut e,i,11);
        assert(tick(ref mut e,i,1).kind==4);let fill::State b=progress(ref e,i);same_recipe(a,b);
        assert(!b.active && b.list_gathered==32 && b.list_encoded==32 && b.written==extent(b) && b.total==initial(replace)+list_work(replace));
        assert(event(engine::observe(ref mut e,i)).remaining==prepaid.remaining);
        same_event(finish(ref mut e,i,7),completion(ref baseline));let engine::Output result=take(ref mut e,i)?;same_output(ref result,ref baseline);
        assert(completion(ref result).value==42);binary_output(ref result,bytes::view(ref data));destroy(ref mut e,i);ledger(ref e,0);stage+=1;
    }close(ref mut e,p);target+=1;}return .ok(0);}

// 2. Both actual CREATE80 and selected REPLACE87(kind3/mode1)->81, 32/64 cells.
fn Result<usize,u8> fixed_and_mixed_quanta_binary_parity(){var usize target=0;while(target<2){let bool replace=target==1;
    let bytes::Buffer text=source(replace,if(replace){64}else{32})?;let bytes::Buffer data=binary(4093)?;
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,bytes::view(ref text))?;let engine::Output baseline=synchronous(ref mut e,p,bytes::view(ref data),16000000)?;
    assert(completion(ref baseline).kind==1 && completion(ref baseline).value==42);let usize[3] fixed=[1,7,4096];let usize[5] mixed=[1,7,3,4096,2];var usize variant=0;
    while(variant<4){let usize i=bound(ref mut e,p,bytes::view(ref data),16000000)?;prepare(ref mut e,i);var engine::Event s=event(engine::observe(ref mut e,i));var usize n=0;
        while(s.kind==4){assert(n<512);s=tick(ref mut e,i,if(variant==3){mixed[n%5]}else{fixed[variant]});n+=1;}
        same_event(s,completion(ref baseline));let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);binary_output(ref o,bytes::view(ref data));destroy(ref mut e,i);ledger(ref e,0);variant+=1;
    }close(ref mut e,p);target+=1;}return .ok(0);}

// 3. Cancel in gather, encode and commit for EACH opcode; private output stays hidden.
fn Result<usize,u8> cancel_each_stage_refunds_backing(){var usize target=0;while(target<2){let bool replace=target==1;
    let bytes::Buffer text=source(replace,32)?;var engine::Engine e=created()?;let usize p=compiled(ref mut e,bytes::view(ref text))?;
    let usize[3] room=[128,384,576];var usize stage=0;while(stage<3){let bytes::Buffer data=binary(4096-initial(replace)-room[stage])?;
        let usize i=bound(ref mut e,p,bytes::view(ref data),16000000)?;let usize retained=memory(ref e).current;let Heap ready=heap();prepare(ref mut e,i);
        assert(tick(ref mut e,i,4096).kind==4);let fill::State a=progress(ref e,i);assert(a.active && a.op==if(replace){81}else{80});
        assert(a.list_gathered==if(stage==0){16}else{32} && a.list_encoded==if(stage==0){0}else if(stage==1){16}else{32} && a.written==if(stage==2){64}else{0});
        let engine::Event running=event(engine::observe(ref mut e,i));rejected_take(ref mut e,i,11);let usize attempts=unsafe{probe_attempts()};
        let engine::Event stopped=lifecycle::stop(ref mut e,i);
        assert(unsafe{probe_attempts()}==attempts && stopped.kind==3 && stopped.value==0 && stopped.fuel_known && stopped.remaining==running.remaining && stopped.diagnostic.code.kind==0);
        same_heap(ready);ledger(ref e,retained);rejected_progress(ref e,i,11);rejected_take(ref mut e,i,2);
        same_event(stopped,event(engine::cancel_ready(ref mut e,i)));same_event(stopped,event(engine::observe(ref mut e,i)));same_heap(ready);
        destroy(ref mut e,i);ledger(ref e,0);rejected_progress(ref e,i,2);stage+=1;
    }close(ref mut e,p);target+=1;}return .ok(0);}

// 4. Measure exact admission with quantum one, then force zero-Fuel gather/
// encode/commit continuations using a partial first batch. One less admits none.
fn Result<usize,u8> exact_and_one_less_fuel_at_both_ops(){var usize target=0;while(target<2){let bool replace=target==1;
    let bytes::Buffer text=source(replace,32)?;let bytes::Buffer data=binary(4096-initial(replace)-128)?;
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,bytes::view(ref text))?;let engine::Output full=synchronous(ref mut e,p,bytes::view(ref data),16000000)?;
    assert(completion(ref full).kind==1 && completion(ref full).value==42);let usize whole_price=16000000-completion(ref full).remaining;
    let usize exact=bound(ref mut e,p,bytes::view(ref data),whole_price)?;prepare(ref mut e,exact);let engine::Event done=finish(ref mut e,exact,7);
    assert(done.kind==1 && done.value==42 && done.remaining==0);let engine::Output whole=take(ref mut e,exact)?;binary_output(ref whole,bytes::view(ref data));destroy(ref mut e,exact);
    let usize measured=bound(ref mut e,p,bytes::view(ref data),16000000)?;prepare(ref mut e,measured);var usize admission=0;var usize n=0;
    while(admission==0){assert(n<256);let engine::Event before=event(engine::observe(ref mut e,measured));assert(tick(ref mut e,measured,1).kind==4);n+=1;let fill::State a=progress(ref e,measured);
        if(a.op==if(replace){81}else{80}){assert(!a.active && a.list_gathered==32 && a.list_encoded==32 && a.written==extent(a));
            assert(before.remaining-event(engine::observe(ref mut e,measured)).remaining==1+price(replace));admission=16000000-before.remaining+1+price(replace);}}
    destroy(ref mut e,measured);assert(admission<whole_price);var usize short=0;while(short<2){let usize budget=admission-short;
        let engine::Output baseline=synchronous(ref mut e,p,bytes::view(ref data),budget)?;let usize i=bound(ref mut e,p,bytes::view(ref data),budget)?;prepare(ref mut e,i);
        var engine::Event s=tick(ref mut e,i,4096);var usize total=initial(replace);
        if(short==0){assert(s.kind==4 && s.remaining==0);let fill::State a=progress(ref e,i);assert(a.active && a.list_gathered==16 && a.list_encoded==0 && a.written==0);
            assert(tick(ref mut e,i,1).kind==4);let fill::State b=progress(ref e,i);same_recipe(a,b);assert(!b.active && b.list_gathered==32 && b.list_encoded==32 && b.written==extent(b));total=b.total;s=finish(ref mut e,i,1);}
        if(s.kind==4){s=finish(ref mut e,i,1);}
        assert(s.kind==2 && s.diagnostic.code.kind==8 && s.diagnostic.code.offset!=0 && total==initial(replace)+if(short==0){list_work(replace)}else{0});
        same_event(s,completion(ref baseline));let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);assert(!engine::output_available(ref o) && engine::output_view(ref o).len==0);
        destroy(ref mut e,i);ledger(ref e,0);short+=1;
    }close(ref mut e,p);target+=1;}return .ok(0);}

// 5. Shared Program scratch requirements never alias per-Instance scratch;
// frozen recipes survive peer progress, released handles and two Engine moves.
fn Result<usize,u8> interleaving_moves_and_released_pins(){let bytes::Buffer text=source(true,32)?;var engine::Engine original=created()?;let usize p=compiled(ref mut original,bytes::view(ref text))?;
    let bytes::Buffer left=binary(4096-264-128)?;var bytes::Buffer right=binary(4096-264-384)?;bytes::view_mut(ref mut right)[0]=22;
    let engine::Output baseline=synchronous(ref mut original,p,bytes::view(ref right),16000000)?;
    let usize a=bound(ref mut original,p,bytes::view(ref left),16000000)?;let usize b=bound(ref mut original,p,bytes::view(ref right),16000000)?;prepare(ref mut original,a);prepare(ref mut original,b);
    assert(tick(ref mut original,a,4096).kind==4);let fill::State first=progress(ref original,a);let engine::Event saved=event(engine::observe(ref mut original,a));assert(first.active && first.list_gathered==16 && first.list_encoded==0);
    assert(tick(ref mut original,b,4096).kind==4);let fill::State second=progress(ref original,b);assert(second.active && second.list_gathered==32 && second.list_encoded==16);same_progress(first,progress(ref original,a));
    assert(id(engine::release_program(ref mut original,p))==p);let Heap held=heap();var engine::Engine moved=original;same_heap(held);same_progress(first,progress(ref moved,a));same_progress(second,progress(ref moved,b));
    assert(tick(ref mut moved,b,1).kind==4);same_progress(first,progress(ref moved,a));var engine::Engine e=moved;same_heap(held);
    same_event(finish(ref mut e,b,7),completion(ref baseline));let engine::Output out_b=take(ref mut e,b)?;same_output(ref out_b,ref baseline);destroy(ref mut e,b);
    same_progress(first,progress(ref e,a));same_event(saved,event(engine::observe(ref mut e,a)));assert(finish(ref mut e,a,4096).value==42);
    let engine::Output out_a=take(ref mut e,a)?;destroy(ref mut e,a);ledger(ref e,0);switch(engine::inspect(ref mut e)){case .ok(v):{assert(v.programs==0 && v.instances==0 && v.pins==0);}case .err(_):{assert(false);}};
    assert(id(engine::destroy(ref mut e))==0);binary_output(ref out_a,bytes::view(ref left));same_output(ref out_b,ref baseline);return .ok(0);}
pub fn void run(){let Heap before=heap();
    assert(stages_padding_and_frozen_publication().is_ok);same_heap(before);
    assert(fixed_and_mixed_quanta_binary_parity().is_ok);same_heap(before);
    assert(cancel_each_stage_refunds_backing().is_ok);same_heap(before);
    assert(exact_and_one_less_fuel_at_both_ops().is_ok);same_heap(before);
    assert(interleaving_moves_and_released_pins().is_ok);same_heap(before);
}
