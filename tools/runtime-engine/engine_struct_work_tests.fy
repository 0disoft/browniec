module engine_struct_work_tests;
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

// Actual-source Engine fixtures. Parent owns transport, runner and integration.
// Shape arithmetic below describes these small records, never synthetic IR.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);
struct Heap { usize blocks; usize bytes; }
struct Admission { usize before; usize after; fill::State recipe; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()}};}
fn void same_heap(Heap h){assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes);}
fn usize id(Result<usize,engine::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn engine::Event event(Result<engine::Event,engine::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);engine::Event{.kind=0,.value=0,.remaining=0,.fuel_known=false,.diagnostic=diagnostics::absent(errors::make(0,0))}}};}
fn fill::State progress(ref engine::Engine e,usize i){return switch(engine::array_fill_progress(e,i)){case .ok(v):{v}case .err(_):{assert(false);fill::empty()}};}
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
    assert(a.record==b.record && a.nominal==b.nominal && a.ordinal==b.ordinal && a.source_record==b.source_record && a.source_ordinal==b.source_ordinal);
    var usize n=0;while(n<8){assert(a.encoded[n]==b.encoded[n]);n+=1;}
    n=0;while(n<128){assert(a.record_encoded[n]==b.record_encoded[n]);n+=1;}}
fn void same_progress(fill::State a,fill::State b){same_recipe(a,b);assert(a.active==b.active && a.written==b.written && a.total==b.total && a.last==b.last && a.list_gathered==b.list_gathered && a.list_encoded==b.list_encoded);}
fn void rejected_take(ref mut engine::Engine e,usize i,u32 status){switch(engine::take_output(e,i)){case .ok(_):{assert(false);}case .err(v):{assert(v.status==status);}};}
fn void rejected_progress(ref engine::Engine e,usize i,u32 status){switch(engine::array_fill_progress(e,i)){case .ok(_):{assert(false);}case .err(v):{assert(v.status==status);}};}
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
    assert(!a.active && a.written==0 && a.total==0 && a.last==0 && !o.active && o.total==0 && o.last==0);}
fn bool record(u8 op){return op==41 || op==42 || op==46 || op==47 || op==48 || op==49;}
fn usize extent(fill::State a){return a.end-if(a.op==41 || a.op==42){a.mark}else{a.base};}
// ALL step_instance calls deny the next SDK allocation, including final seal.
fn engine::Event tick(ref mut engine::Engine e,usize i,usize q){let engine::Event before=event(engine::observe(e,i));let fill::State prior=progress(e,i);let copy::State old=output(e,i);
    let Heap h=heap();let usize charge=memory(e).current;let usize attempts=unsafe{probe_attempts()};unsafe{bc_runtime_engine_test_fail(0)};
    let Result<engine::Event,engine::Error> r=engine::step_instance(e,i,q);unsafe{bc_runtime_engine_test_fail(-1)};let engine::Event after=event(r);
    assert(unsafe{probe_attempts()}==attempts && before.kind==4 && after.fuel_known && after.remaining<=before.remaining);same_event(after,event(engine::observe(e,i)));
    if(after.kind==4){let fill::State a=progress(e,i);let copy::State o=output(e,i);
        assert(a.last+o.last<=4096 && a.total>=prior.total && a.total-prior.total==a.last && o.total>=old.total && o.total-old.total==o.last && !(a.active && o.active));
        if(a.active){assert(record(a.op) && a.pc<256 && a.frame>0 && a.frame<32 && a.destination<16 && a.slot<16 && a.generation!=0 && a.written<extent(a));
            assert(a.nominal<32 && a.record<32 && a.ordinal<128 && a.list_gathered==0 && a.list_encoded==0);rejected_take(e,i,11);}
        if(prior.active && q==1){same_recipe(prior,a);assert(after.remaining==before.remaining && o.total==old.total && a.written>=prior.written && a.last==a.written-prior.written);}
        same_heap(h);ledger(e,charge);
    }else{assert(after.kind==1 || after.kind==2);rejected_progress(e,i,11);}return after;}
fn engine::Event finish(ref mut engine::Engine e,usize i,usize q){var engine::Event s=event(engine::observe(e,i));var usize n=0;while(s.kind==4){assert(n<512);s=tick(e,i,q);n+=1;}return s;}
fn void append(ref mut bytes::Buffer b,ref u8[] text){assert(bytes::append(b,text).is_ok);}
// 0 CREATE; 1 COPY; 2 whole copy; 3 child copy; 4 whole constructor;
// 5 child constructor; 6 bool/padding identity copy; 7 same-owner siblings;
// 8 same-owner constructor self reads with two observable RHS evaluations.
fn Result<bytes::Buffer,u8> source(usize mode){assert(mode<9);var bytes::Buffer b=bytes::empty();
    append(ref mut b,b"module app;struct I{i64 x;}struct R{i64 head;I child;i64 tail;}struct P{bool flag;i64 x;}struct S{i64 head;I left;I right;i64 tail;}struct U{i64 x;i64 y;}struct V{i64 head;U child;i64 tail;}pub fn i32 chosen(ref u8[] data){let u8[1] pad=[80;1];let shadow=pad;");
    if(mode==1 || mode==2){append(ref mut b,b"let I a=I{.x=data[0] as i64};");}
    if(mode==2 || mode==4){append(ref mut b,b"var I p=I{.x=0};");}
    if(mode==3){append(ref mut b,b"let R a=R{.head=9,.child=I{.x=data[0] as i64},.tail=10};");}
    if(mode==3 || mode==5){append(ref mut b,b"var R p=R{.head=17,.child=I{.x=0},.tail=23};");}
    if(mode==6){append(ref mut b,b"var P p=P{.flag=true,.x=data[0] as i64};");}
    if(mode==7){append(ref mut b,b"var S p=S{.head=17,.left=I{.x=data[0] as i64},.right=I{.x=0},.tail=23};");}
    if(mode==8){append(ref mut b,b"var V p=V{.head=17,.child=U{.x=20,.y=22},.tail=23};var i32 n=0;let Option<i32> f=.some(1);");}
    append(ref mut b,b"output::emit(ref data);");
    if(mode==0){append(ref mut b,b"let I p=I{.x=data[0] as i64};");}
    else if(mode==1){append(ref mut b,b"let I p=a;");}
    else if(mode==2){append(ref mut b,b"p=a;");}
    else if(mode==3){append(ref mut b,b"p.child=a.child;");}
    else if(mode==4){append(ref mut b,b"p=I{.x=data[0] as i64};");}
    else if(mode==5){append(ref mut b,b"p.child=I{.x=data[0] as i64};");}
    else if(mode==6){append(ref mut b,b"p=p;");}
    else if(mode==7){append(ref mut b,b"p.right=p.left;");}
    else{append(ref mut b,b"p.child=U{.x=switch(f){case .some(_):{n=n+1;p.child.y}case .none:{0}},.y=switch(f){case .some(_):{n=n+1;p.child.x}case .none:{0}}};");}
    append(ref mut b,b"output::emit(ref b\"\\x00\\xFF!\");if(pad[0]!=80 || shadow[0]!=80");
    if(mode==3 || mode==5){append(ref mut b,b" || p.head!=17 || p.tail!=23 || p.child.x!=data[0] as i64");}
    else if(mode==7){append(ref mut b,b" || p.head!=17 || p.tail!=23 || p.left.x!=data[0] as i64 || p.right.x!=data[0] as i64");}
    else if(mode==8){append(ref mut b,b" || n!=2 || p.head!=17 || p.tail!=23 || p.child.x!=22 || p.child.y!=20");}
    else{append(ref mut b,b" || p.x!=data[0] as i64");if(mode==6){append(ref mut b,b" || !p.flag");}}
    append(ref mut b,b"){return 0;}return 42;}");return .ok(b);}
fn Result<bytes::Buffer,u8> binary(usize length){assert(length>0 && length<=4096);var bytes::Buffer b=switch(bytes::with_capacity(length)){case .ok(v):{v}case .err(_):{return .err(9);}};
    assert(bytes::resize_zeroed(ref mut b,length).is_ok);let ref mut u8[] v=bytes::view_mut(ref mut b);v[0]=42;v[length/2]=255;v[length-1]=128;return .ok(b);}
// I: size/scalars=8, leaves=1. R:24/24/3. P:16/9/2, one bool.
// S,V:32/32/4. First record follows two u8 owners: six padding bytes.
fn usize initial(usize mode){return if(mode==0){2}else if(mode==1 || mode==4){40}else if(mode==2){72}else if(mode==3){200}else if(mode==5){104}else if(mode==6){65}else{136};}
fn usize staging(usize mode){return if(mode==0 || mode==4 || mode==5){8+8+8}else if(mode==6){16+9+1}else if(mode==8){16+16+16}else{8+8};}
fn usize destination_bytes(usize mode){return if(mode==0){14}else if(mode==6 || mode==8){16}else{8};}
fn u8 opcode(usize mode){return if(mode==0){41}else if(mode==1){42}else if(mode==4 || mode==5 || mode==8){49}else{47};}
fn usize price(usize mode){return switch(if(mode<2){meter::record_instruction(opcode(mode))}else{meter::aggregate_place_instruction(if(opcode(mode)==47){85}else{87},true,0,0,false,false)}){
    case .some(v):{v}case .none:{assert(false);0}};}
fn void binary_output(ref engine::Output o,ref u8[] data){let ref u8[] v=engine::output_view(o);assert(engine::output_available(o) && v.len==data.len+3 && bytes::equal(v[..data.len],data) && bytes::equal(v[data.len..],b"\x00\xFF!") && engine::output_completion(o).emits==2);}
fn void shape(fill::State a,usize mode){assert(a.op==opcode(mode) && a.end-a.base==if(mode==7 || mode==8){32}else if(mode==3 || mode==5){24}else if(mode==6){16}else{8});
    assert(a.ordinal==if(mode==7){2}else if(mode==3 || mode==5 || mode==8){1}else{0});
    if(mode==3 || mode==7){assert(a.source_ordinal==1 && a.source_record==a.record);}
    if(mode==6 || mode==7){assert(a.slot==a.source_slot && a.generation==a.source_generation);}
    if(mode==6){assert(a.record_encoded[0]==1);var usize n=1;while(n<8){assert(a.record_encoded[n]==0);n+=1;}}
    let usize size=if(mode==6 || mode==8){16}else{8};var usize n=size;while(n<128){assert(a.record_encoded[n]==0);n+=1;}}
// Locate the target after the first output, using actual quantum-one dispatch.
// This also proves the fixed source-shape work and the original selected price.
fn Result<Admission,u8> admission(ref mut engine::Engine e,usize p,ref u8[] data,usize mode){let usize i=bound(e,p,data,16000000)?;prepare(e,i);var usize n=0;
    while(n<256){let engine::Event before=event(engine::observe(e,i));let copy::State old=output(e,i);let fill::State prior=progress(e,i);assert(tick(e,i,1).kind==4);let fill::State a=progress(e,i);
        if(old.total==data.len && a.total>prior.total){assert(prior.total==initial(mode) && !a.active && a.written==destination_bytes(mode));shape(a,mode);
            assert(a.total==initial(mode)+staging(mode)+destination_bytes(mode));let engine::Event after=event(engine::observe(e,i));assert(before.remaining-after.remaining==1+price(mode));
            destroy(e,i);ledger(e,0);return .ok(Admission{.before=before.remaining,.after=after.remaining,.recipe=a});}n+=1;
    }assert(false);return .err(10);}

// 1. Whole staging is indivisible: one less defers BEFORE the unit/Fuel/begin;
// exact staging leaves zero destination bytes, one extra byte commits padding
// or payload. A q=1 continuation preserves the entire original SELECT recipe.
fn Result<usize,u8> shared_allowance_admission_and_commit(){var usize mode=0;while(mode<9){let bytes::Buffer text=source(mode)?;var engine::Engine e=created()?;let usize p=compiled(ref mut e,bytes::view(ref text))?;
    var usize boundary=0;while(boundary<3){let usize room=staging(mode)-1+boundary;let bytes::Buffer data=binary(4096-initial(mode)-room)?;let Admission paid=admission(ref mut e,p,bytes::view(ref data),mode)?;
        let engine::Output baseline=synchronous(ref mut e,p,bytes::view(ref data),16000000)?;assert(completion(ref baseline).value==42);
        let usize i=bound(ref mut e,p,bytes::view(ref data),16000000)?;prepare(ref mut e,i);let engine::Event first=tick(ref mut e,i,4096);assert(first.kind==4);
        let fill::State a=progress(ref e,i);let copy::State o=output(ref e,i);assert(!o.active && o.total==bytes::len(ref data) && o.last==o.total);rejected_take(ref mut e,i,11);
        if(boundary==0){assert(!a.active && a.total==initial(mode) && a.last==initial(mode) && first.remaining==paid.before && a.last+o.last==4096-room);}
        else{assert(a.active && a.written==boundary-1 && a.total==initial(mode)+room && a.last==a.total && a.last+o.last==4096 && first.remaining==paid.after);shape(a,mode);}
        assert(tick(ref mut e,i,1).kind==4);let fill::State b=progress(ref e,i);shape(b,mode);assert(!b.active && b.written==destination_bytes(mode) && b.total==initial(mode)+staging(mode)+destination_bytes(mode));
        if(boundary>0){same_recipe(a,b);}assert(event(engine::observe(ref mut e,i)).remaining==paid.after);
        same_event(finish(ref mut e,i,7),completion(ref baseline));let engine::Output result=take(ref mut e,i)?;same_output(ref result,ref baseline);binary_output(ref result,bytes::view(ref data));destroy(ref mut e,i);ledger(ref e,0);boundary+=1;
    }close(ref mut e,p);mode+=1;}return .ok(0);}

// 2. CREATE/COPY plus whole/child STORE85->47 and REPLACE87->49, including
// canonical bool/padding identity and same-owner source fields, match sync.
fn Result<usize,u8> fixed_and_mixed_quanta_binary_parity(){var usize mode=0;while(mode<9){let bytes::Buffer text=source(mode)?;let bytes::Buffer data=binary(4093)?;
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,bytes::view(ref text))?;let engine::Output baseline=synchronous(ref mut e,p,bytes::view(ref data),16000000)?;assert(completion(ref baseline).kind==1 && completion(ref baseline).value==42);
    let usize[3] fixed=[1,7,4096];let usize[5] mixed=[1,7,3,4096,2];var usize variant=0;while(variant<4){let usize i=bound(ref mut e,p,bytes::view(ref data),16000000)?;prepare(ref mut e,i);var engine::Event s=event(engine::observe(ref mut e,i));var usize n=0;
        while(s.kind==4){assert(n<512);s=tick(ref mut e,i,if(variant==3){mixed[n%5]}else{fixed[variant]});n+=1;}
        same_event(s,completion(ref baseline));let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);binary_output(ref o,bytes::view(ref data));destroy(ref mut e,i);ledger(ref e,0);variant+=1;
    }close(ref mut e,p);mode+=1;}return .ok(0);}

// 3. Cancellation after full staging and after a partial destination write
// hides prior staged output and refunds the exact pending-memory backing.
fn Result<usize,u8> cancel_staging_and_partial_commit_refunds(){var usize mode=0;while(mode<9){let bytes::Buffer text=source(mode)?;var engine::Engine e=created()?;let usize p=compiled(ref mut e,bytes::view(ref text))?;
    var usize written=0;while(written<2){let bytes::Buffer data=binary(4096-initial(mode)-staging(mode)-written)?;let usize i=bound(ref mut e,p,bytes::view(ref data),16000000)?;
        let usize retained=memory(ref e).current;let Heap ready=heap();prepare(ref mut e,i);assert(tick(ref mut e,i,4096).kind==4);let fill::State a=progress(ref e,i);assert(a.active && a.written==written);shape(a,mode);
        let engine::Event running=event(engine::observe(ref mut e,i));rejected_take(ref mut e,i,11);let usize attempts=unsafe{probe_attempts()};
        let engine::Event stopped=lifecycle::stop(ref mut e,i);
        assert(unsafe{probe_attempts()}==attempts && stopped.kind==3 && stopped.value==0 && stopped.fuel_known && stopped.remaining==running.remaining && stopped.diagnostic.code.kind==0);
        same_heap(ready);ledger(ref e,retained);rejected_progress(ref e,i,11);rejected_take(ref mut e,i,2);same_event(stopped,event(engine::cancel_ready(ref mut e,i)));same_event(stopped,event(engine::observe(ref mut e,i)));same_heap(ready);
        destroy(ref mut e,i);ledger(ref e,0);rejected_progress(ref e,i,2);written+=1;
    }close(ref mut e,p);mode+=1;}return .ok(0);}

// 4. Exact whole-program Fuel succeeds at zero. Exact target admission prepays
// once, then q=1 completes its partial commit at zero Fuel BEFORE the gate.
// One less cannot stage the target; failure parity includes diagnostics/output.
fn Result<usize,u8> exact_and_one_less_fuel_zero_continuation(){var usize mode=0;while(mode<9){let bytes::Buffer text=source(mode)?;let bytes::Buffer data=binary(4096-initial(mode)-staging(mode)-1)?;
    var engine::Engine e=created()?;let usize p=compiled(ref mut e,bytes::view(ref text))?;let Admission paid=admission(ref mut e,p,bytes::view(ref data),mode)?;
    let engine::Output full=synchronous(ref mut e,p,bytes::view(ref data),16000000)?;assert(completion(ref full).kind==1 && completion(ref full).value==42);let usize whole_price=16000000-completion(ref full).remaining;
    let usize exact=bound(ref mut e,p,bytes::view(ref data),whole_price)?;prepare(ref mut e,exact);let engine::Event done=finish(ref mut e,exact,7);assert(done.kind==1 && done.value==42 && done.remaining==0);
    let engine::Output whole=take(ref mut e,exact)?;binary_output(ref whole,bytes::view(ref data));destroy(ref mut e,exact);assert(16000000-paid.after<whole_price);
    var usize short=0;while(short<2){let usize budget=16000000-paid.after-short;let engine::Output baseline=synchronous(ref mut e,p,bytes::view(ref data),budget)?;
        let usize i=bound(ref mut e,p,bytes::view(ref data),budget)?;prepare(ref mut e,i);var engine::Event s=tick(ref mut e,i,4096);
        if(short==0){assert(s.kind==4 && s.remaining==0);let fill::State a=progress(ref e,i);assert(a.active && a.written==1 && a.total==initial(mode)+staging(mode)+1);shape(a,mode);
            assert(tick(ref mut e,i,1).kind==4);let fill::State b=progress(ref e,i);same_recipe(a,b);assert(!b.active && b.written==destination_bytes(mode) && b.total==initial(mode)+staging(mode)+destination_bytes(mode));
            assert(event(engine::observe(ref mut e,i)).remaining==0);s=finish(ref mut e,i,1);}
        if(s.kind==4){s=finish(ref mut e,i,1);}
        assert(s.kind==2 && s.diagnostic.code.kind==8 && s.diagnostic.code.offset!=0);same_event(s,completion(ref baseline));let engine::Output o=take(ref mut e,i)?;same_output(ref o,ref baseline);
        assert(!engine::output_available(ref o) && engine::output_view(ref o).len==0);destroy(ref mut e,i);ledger(ref e,0);short+=1;
    }close(ref mut e,p);mode+=1;}return .ok(0);}

// 5. Distinct instances retain independent canonical stages and selected
// targets while peers progress, program handles release and Engine moves twice.
fn Result<usize,u8> interleaving_moves_and_released_pins(){let usize mode=3;let bytes::Buffer text=source(mode)?;var engine::Engine original=created()?;let usize p=compiled(ref mut original,bytes::view(ref text))?;
    let bytes::Buffer left=binary(4096-initial(mode)-staging(mode))?;var bytes::Buffer right=binary(4096-initial(mode)-staging(mode)-1)?;bytes::view_mut(ref mut right)[0]=43;
    let engine::Output baseline=synchronous(ref mut original,p,bytes::view(ref right),16000000)?;let usize a=bound(ref mut original,p,bytes::view(ref left),16000000)?;let usize b=bound(ref mut original,p,bytes::view(ref right),16000000)?;
    prepare(ref mut original,a);prepare(ref mut original,b);assert(tick(ref mut original,a,4096).kind==4);let fill::State first=progress(ref original,a);let engine::Event saved=event(engine::observe(ref mut original,a));assert(first.active && first.written==0);shape(first,mode);
    assert(tick(ref mut original,b,4096).kind==4);let fill::State second=progress(ref original,b);assert(second.active && second.written==1);shape(second,mode);same_progress(first,progress(ref original,a));assert(first.record_encoded[0]==42 && second.record_encoded[0]==43);
    assert(id(engine::release_program(ref mut original,p))==p);let Heap held=heap();var engine::Engine moved=original;same_heap(held);same_progress(first,progress(ref moved,a));same_progress(second,progress(ref moved,b));
    assert(tick(ref mut moved,b,1).kind==4);same_progress(first,progress(ref moved,a));var engine::Engine e=moved;same_heap(held);
    same_event(finish(ref mut e,b,7),completion(ref baseline));let engine::Output out_b=take(ref mut e,b)?;same_output(ref out_b,ref baseline);destroy(ref mut e,b);
    same_progress(first,progress(ref e,a));same_event(saved,event(engine::observe(ref mut e,a)));assert(finish(ref mut e,a,4096).value==42);let engine::Output out_a=take(ref mut e,a)?;destroy(ref mut e,a);ledger(ref e,0);
    switch(engine::inspect(ref mut e)){case .ok(v):{assert(v.programs==0 && v.instances==0 && v.pins==0);}case .err(_):{assert(false);}};assert(id(engine::destroy(ref mut e))==0);
    binary_output(ref out_a,bytes::view(ref left));same_output(ref out_b,ref baseline);return .ok(0);}
pub fn void run(){let Heap before=heap();
    assert(shared_allowance_admission_and_commit().is_ok);same_heap(before);
    assert(fixed_and_mixed_quanta_binary_parity().is_ok);same_heap(before);
    assert(cancel_staging_and_partial_commit_refunds().is_ok);same_heap(before);
    assert(exact_and_one_less_fuel_zero_continuation().is_ok);same_heap(before);
    assert(interleaving_moves_and_released_pins().is_ok);same_heap(before);
}
