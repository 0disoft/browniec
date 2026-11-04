module tests::m2::slice_result_call_ir;
import ir as ir;
import errors as errors;
import functions as functions;
import slice_result_ir as results;
import slice_result_verifier as proof;
import slice_result_call_ir as calls;
import slice_reborrow_ir as reborrow;
import verifier as verifier;
import vm as vm;
import compiler as compiler;
import static_image as images;
import program_image as programs;
import slice_result_execution as execution;
import slice_authority as authority;
import slice_result_runtime as runtime;
import array_owners as owners;
import array_slices as slices;
import array_layout as layout;

// Three functions: a second-input selector, its ordinary/reference caller, main.
// Build the recipe directly: source lowering intentionally stays unavailable.
fn Result<results::Program,errors::Error> build(u8 tag,bool captures,bool borrowed){
    var ir::Program p=ir::empty();p.function_count=3;p.entry=2;
    p.arities[0]=2;p.arities[1]=2;p.return_types=[12,12,1,0,0,0,0,0,0,0,0,0,0,0,0,0];
    p.slice_origins=[1,2,3,4,4,0,0,0,0,0,0,0,0,0,0,0];
    p.slice_functions=[1,1,2,2,2,0,0,0,0,0,0,0,0,0,0,0];
    p.slice_elements[0]=tag;p.slice_elements[1]=tag;p.slice_elements[2]=tag;p.slice_elements[3]=tag;p.slice_elements[4]=tag;
    p.registers=2;p.slice_parameters[0]=1;p.slice_parameters[1]=2;
    let usize selected=ir::slice_length(ref mut p,1,0)?;
    let usize close_q=ir::slice_close(ref mut p,1,0)?;let usize close_p=ir::slice_close(ref mut p,0,0)?;
    let usize ret=ir::emit(ref mut p,8,selected,0,0)?;let usize end0=p.count;let usize regs0=p.registers;p.ends[0]=end0;p.register_ends[0]=regs0;
    p.starts[1]=end0;p.register_starts[1]=regs0;
    p.slice_parameters[3]=3;p.slice_parameters[4]=4;p.registers=5;
    let usize zero=ir::integer(ref mut p,0,12,0)?;
    if(captures){
        p.slice_origins[5]=3;p.slice_origins[6]=4;p.slice_functions[5]=2;p.slice_functions[6]=2;p.slice_elements[5]=tag;p.slice_elements[6]=tag;
        let usize begin_a=reborrow::begin(ref mut p,5,2,zero,zero,0)?;
        let usize begin_b=reborrow::begin(ref mut p,6,3,zero,zero,0)?;
    }
    let usize call=p.count;let usize[2] args=if(captures){[165,166]}else{[162,163]};
    let usize opaque=ir::call(ref mut p,0,ref args,0)?;
    p.code[call*8]=66;p.code[call*8+4]=if(captures){3}else{0};p.code[call*8+5]=4;p.code[call*8+6]=3;
    if(captures){let usize end_b=ir::raw(ref mut p,68,6,3,0,0)?;let usize end_a=ir::raw(ref mut p,68,5,2,0,0)?;}
    let usize bound=ir::raw(ref mut p,67,4,3,zero,0)?;
    // zero is register 5; these are normalization witnesses, not runtime bounds.
    p.code[bound*8+4]=5;
    let usize value=ir::slice_length(ref mut p,4,0)?;
    if((tag&128)!=0){let usize ended=reborrow::end(ref mut p,4,3,0)?;}
    else{let usize closed=ir::slice_close(ref mut p,4,0)?;}
    let usize parent_q=ir::slice_close(ref mut p,3,0)?;let usize parent_p=ir::slice_close(ref mut p,2,0)?;
    let usize returned=ir::emit(ref mut p,8,value,0,0)?;let usize end1=p.count;let usize regs1=p.registers;p.ends[1]=end1;p.register_ends[1]=regs1;
    p.starts[2]=end1;p.register_starts[2]=regs1;
    let usize answer=ir::literal(ref mut p,42,0)?;let usize done=ir::emit(ref mut p,8,answer,0,0)?;
    let usize end2=p.count;let usize regs2=p.registers;p.ends[2]=end2;p.register_ends[2]=regs2;
    var functions::Table signatures=functions::empty();signatures.count=3;signatures.entry=2;signatures.arities=p.arities;
    signatures.return_slice_elements[0]=tag;if(borrowed){signatures.return_slice_elements[1]=tag;}
    return results::from_proxy(p,ref signatures);
}
fn results::Program unit(u8 tag,bool captures,bool borrowed){return switch(build(tag,captures,borrowed)){
    case .ok(v):{v}case .err(_):{assert(false);results::Program{.body=ir::empty(),.elements=[0;16],.parameters=[0;16]}}
};}
fn usize opcode(ref results::Program p,u8 op){var usize pc=0;while(pc<p.body.count){if(p.body.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;}
fn void accepted(ref results::Program p){assert(proof::inspect(p).is_ok);assert(!verifier::verify(ref p.body).is_ok);}
fn void rejected(ref results::Program p){switch(proof::inspect(p)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};}

@test
fn void bindings_prove_shared_and_exclusive_six_scalar_types(){
    let u8[12] tags=[1,129,2,130,9,137,10,138,11,139,12,140];var usize i=0;
    while(i<tags.len){let results::Program p=unit(tags[i],false,false);accepted(ref p);assert(p.parameters[0]==2 && p.parameters[1]==0);i+=1;}
}
@test
fn void selected_result_provenance_traces_calls_and_anonymous_capture_definitions(){
    let results::Program shared=unit(1,false,true);accepted(ref shared);assert(shared.parameters[1]==2);
    let results::Program writer=unit(129,true,true);accepted(ref writer);assert(writer.parameters[1]==2);
}
fn ir::Program normalized(ref results::Program p){
    var ir::Program proxy=p.body;let usize changed=switch(calls::rewrite(ref mut proxy)){case .ok(v):{v}case .err(_):{assert(false);0}};
    var usize pc=0;while(pc<proxy.count){let u8 op=proxy.code[pc*8];
        if(op==63){proxy.code[pc*8]=57;}else if(op==64){proxy.code[pc*8]=9;}else if(op==65){proxy.code[pc*8]=8;}pc+=1;
    }return proxy;
}
fn void proxy_valid(ref results::Program p){let ir::Program proxy=normalized(p);assert(verifier::verify(ref proxy).is_ok);}

@test
fn void selected_actual_and_exact_access_cannot_be_forged(){
    var results::Program p=unit(1,false,false);let usize call=opcode(ref p,66);let usize map=p.body.code[call*8+3] as usize;
    p.body.call_args[map*8+1]=162;proxy_valid(ref p);rejected(ref p);
    p=unit(1,false,false);p.parameters[0]=1;rejected(ref p);
    p=unit(1,false,false);p.elements[0]=129;rejected(ref p);
    p=unit(1,false,false);p.elements[0]=2;rejected(ref p);
    p=unit(1,false,false);p.elements[0]=0;p.parameters[0]=0;rejected(ref p);
}
@test
fn void flattened_origin_claims_cannot_ground_a_recursive_call_binding(){
    var results::Program p=unit(1,false,true);let usize call=opcode(ref p,66);
    p.body.code[call*8+2]=1;proxy_valid(ref p);rejected(ref p);
    p=unit(129,true,true);let usize writer=opcode(ref p,66);p.body.code[writer*8+2]=1;proxy_valid(ref p);rejected(ref p);
}
@test
fn void opaque_call_id_cannot_be_observed_as_a_scalar(){
    var results::Program p=unit(1,false,false);let usize call=opcode(ref p,66);let u8 id=p.body.code[call*8+1];
    let usize bind=opcode(ref p,67);let u8 zero=p.body.code[bind*8+3];let usize value=bind+1;
    p.body.code[value*8]=2;p.body.code[value*8+2]=id;p.body.code[value*8+3]=zero;
    proxy_valid(ref p);rejected(ref p);
    p=unit(1,false,false);let usize terminal=p.body.ends[1]-1;p.body.code[terminal*8+2]=id;proxy_valid(ref p);rejected(ref p);
}
@test
fn void end_capture_mask_must_match_exact_preexisting_children(){
    var results::Program p=unit(129,true,false);let usize call=opcode(ref p,66);p.body.code[call*8+4]=1;proxy_valid(ref p);rejected(ref p);
    p=unit(129,true,false);p.body.code[call*8+4]=4;rejected(ref p);
    p=unit(129,true,false);p.body.code[call*8+6]=2;rejected(ref p);
    p=unit(129,true,false);let usize end=opcode(ref p,68);p.body.code[end*8+2]=2;rejected(ref p);
    p=unit(129,true,false);p.body.code[end*8+1]=5;p.body.code[end*8+2]=2;rejected(ref p);
}
@test
fn void recipes_reject_missing_finalizers_orphans_and_reserved_bytes(){
    var results::Program p=unit(1,false,false);let usize call=opcode(ref p,66);let usize bind=opcode(ref p,67);
    p.body.code[call*8+7]=1;rejected(ref p);
    p=unit(1,false,false);p.body.code[bind*8+1]=3;rejected(ref p);
    p=unit(1,false,false);p.body.code[bind*8]=59;rejected(ref p);
    p=unit(1,false,false);p.body.code[call*8]=9;rejected(ref p);
    p=unit(129,true,false);let usize end=opcode(ref p,68);p.body.code[end*8]=62;rejected(ref p);
    p=unit(1,false,false);p.body.code[bind*8+5]=1;rejected(ref p);
    p=unit(1,false,false);p.body.code[bind*8+1]=16;p.body.code[call*8+5]=16;rejected(ref p);
}
@test
fn void control_flow_cannot_enter_between_call_and_finalizer(){
    var results::Program p=unit(1,false,false);let usize call=opcode(ref p,66);let usize bind=opcode(ref p,67);
    p.body.code[(call-1)*8]=19;p.body.code[(call-1)*8+1]=0;
    // CALL's result site is 4; bind PC is 6 in this fixture.
    p.body.code[(call-1)*8+2]=6;
    assert(bind==6);assert(!calls::rewrite(ref mut p.body).is_ok);
    p=unit(129,true,false);let usize end=opcode(ref p,68);p.body.starts[1]=end;rejected(ref p);
}
fn slices::Ticket native_input(ref mut runtime::State state,ref mut u8[] data){
    let layout::Array shape=switch(layout::scalar(1,1)){case .ok(v):{v}case .err(_):{assert(false);layout::Array{.element=1,.length=1,.stride=4,.alignment=4,.bytes=4}}};
    let owners::Token root=switch(owners::create(ref shape,42,data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket ticket=switch(slices::open(ref mut pool,ref mut table,root,0,1,4)){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};
    state.runtime.pool=pool;state.runtime.owners=table;return ticket;
}
fn void dispatch_checked(ref results::Program p,bool valid){
    var runtime::State state=runtime::empty(4);var u8[4] data=[42;4];
    let slices::Ticket ticket=native_input(ref mut state,ref mut data);
    let owners::Token root=state.runtime.pool.slots[ticket.slot].view.root;
    let runtime::Capture[2] captures=[runtime::capture(ticket,false,false),runtime::capture(ticket,false,false)];let i64[2] values=[0,0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let result=vm::run_slice_scalar(p,1,ref captures,ref values,ref inputs[..0],ref mut state,ref mut data,1000000);
    if(valid){switch(result){case .ok(v):{assert(v.value==1 && v.remaining>0);}case .err(_):{assert(false);}};}
    else{switch(result){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};}
    assert(state.runtime.authority.frame==0 && state.runtime.authority.depth==0 && state.runtime.owners.depth==1);
    assert(owners::view(ref state.runtime.owners,root,0,1,4).is_ok);
    assert(state.runtime.pool.slots[ticket.slot].live && state.runtime.pool.slots[ticket.slot].generation==ticket.generation);
    assert(data[0]==42 && data[1]==0 && data[2]==0 && data[3]==0);
}

@test
fn void proved_binding_dispatch_runs_and_invalid_recipes_preserve_native_inputs(){
    var results::Program p=unit(1,false,false);dispatch_checked(ref p,true);
    let usize call=opcode(ref p,66);p.body.code[call*8+7]=1;dispatch_checked(ref p,false);
}

// Branch-free fixture insertion preserves scalar/CALL-map/site identities.
// Only these known straight-line recipes use this helper.
fn void insert_static(ref mut ir::Program p,usize pc,u8 op,u8 kind){
    let usize count=p.count;assert(count<256 && pc<count);
    var usize i=count;
    while(i>pc){i-=1;var usize j=0;while(j<8){
        let u8 value=p.code[i*8+j];p.code[(i+1)*8+j]=value;j+=1;
    }let usize offset=p.offsets[i];p.offsets[i+1]=offset;}
    var usize j=0;while(j<8){p.code[pc*8+j]=0;j+=1;}
    p.code[pc*8]=op;
    if(op==69){p.code[pc*8+3]=kind;p.code[pc*8+6]=1;}
    p.count=count+1;let usize functions=p.function_count;var usize f=0;
    while(f<functions){let usize start=p.starts[f];let usize end=p.ends[f];
        if(start>pc){p.starts[f]=start+1;}if(end>pc){p.ends[f]=end+1;}f+=1;
    }
}
fn Result<images::Image,images::Error> literal(bool text){
    var images::Builder b=images::builder(1)?;
    let usize id=if(text){images::intern_text(ref mut b,b"*")?}else{images::intern_bytes(ref mut b,b"*")?};
    return images::freeze(ref b,577);
}
@test fn void static_index_cannot_observe_call_bind_proof_identities(){
    let images::Image image=switch(literal(false)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var results::Program p=unit(1,false,false);
    let usize call=opcode(ref p,66);let u8 opaque=p.body.code[call*8+1];
    let usize bind=opcode(ref p,67);let u8 zero=p.body.code[bind*8+3];
    let usize at=bind+1;insert_static(ref mut p.body,at,69,1);
    let usize read=at+1;let usize dst=p.body.code[read*8+1] as usize;
    p.body.code[read*8]=71;p.body.code[read*8+2]=0;p.body.code[read*8+3]=zero;
    p.body.types[dst]=10;p.body.return_types[1]=10;
    insert_static(ref mut p.body,read+1,70,0);
    assert(proof::inspect_image(ref p,ref image).is_ok);
    p.body.code[read*8+3]=opaque;
    let ir::Program proxy=normalized(ref p);
    // The normalized scalar proof alone accepts this input. Full recipe proof
    // must reject it: runtime never publishes a scalar into CALL_BIND's dst.
    assert(verifier::verify_statics(ref proxy,ref image).is_ok);
    switch(proof::inspect_image(ref p,ref image)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==read);}
    };
}
@test fn void retained_image_executes_static_close_inside_prepared_return_cleanup(){
    var results::Program p=switch(compiler::inspect_slice_result_ir(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){let i32[2] a=[42;2];let ref i32[] r=f(ref a);return r[0];}")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let usize prepare=opcode(ref p,63);
    insert_static(ref mut p.body,prepare,69,2);
    insert_static(ref mut p.body,prepare+2,70,0);
    let images::Image image=switch(literal(true)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Program retained=switch(programs::retain(ref p,image,577)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var runtime::State state=runtime::empty(16);var u8[16] data=[0;16];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let ref ir::Program body=ref p.body;let usize function=body.entry;
    let Result<execution::Scalar,errors::Error> result=programs::run_scalar(ref retained,function,
        ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,10000000);
    switch(result){case .ok(v):{assert(v.value==42);}case .err(_):{assert(false);}};
    let ref runtime::Runtime current=ref state.runtime;
    let ref authority::State stack=ref current.authority;
    let ref owners::Table table=ref current.owners;let ref slices::Pool pool=ref current.pool;
    assert(stack.depth==0 && stack.frame==0 && table.arena.used==0);
    var usize i=0;while(i<16){assert(!pool.slots[i].live);i+=1;}
    let ref images::Image backing=programs::literals(ref retained);
    assert(images::text(backing,images::Span{.literal=0,.start=0,.end=1}).is_ok);
}
