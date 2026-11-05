module tests::m2::reference_call_execution;
import static_call_ir as calls;
import ir as ir;
import static_image as images;
import program_image as programs;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_slices as slices;
import array_owners as owners;
import errors as errors;
import std::num as num;
import reference_execution as references;
import reference_words as words;
import reference_access as access;
import static_views as views;
import slice_result_frames as frames;
import array_layout as layouts;
import verifier as verifier;

fn usize built(Result<usize,errors::Error> value){return switch(value){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 byte(usize value){return switch(num::u8_from_i64(switch(num::i64_from_usize(value)){
    case .ok(v):{v}case .err(_):{assert(false);0}
})){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize fresh(ref mut ir::Program p,u8 tag){let usize r=p.registers;p.types[r]=tag;p.registers+=1;return r;}
fn void end(ref mut ir::Program p,usize f){let usize pc=p.count;let usize r=p.registers;p.ends[f]=pc;p.register_ends[f]=r;
    if(f+1<p.function_count){p.starts[f+1]=pc;p.register_starts[f+1]=r;}}
fn images::Image image(){
    var images::Builder b=switch(images::builder(3)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    let usize id=switch(images::intern_bytes(ref mut b,b"x*y")){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(images::freeze(ref b,579)){case .ok(v):{v}case .err(_):{assert(false);image()}};
}
// Main calls the same formal with image bytes and then runtime bytes. The
// different byte values make losing or guessing the backing observable.
fn calls::Program unit(usize arity,bool prefix,u8 projection,bool length,bool forward,bool image_only){
    var ir::Program p=ir::empty();p.function_count=if(forward){3}else{2};p.return_types[0]=1;
    let u8 result_type=if(length){12}else{1};p.return_types[1]=result_type;if(forward){p.return_types[2]=result_type;}
    let usize fill=built(ir::integer(ref mut p,24,10,0));
    if(!image_only){let usize root=built(ir::array_in(ref mut p,0,10,3,false,0));let usize init=built(ir::array_init(ref mut p,root,fill,0));
        let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,3,12,0));
        let usize loan=built(ir::slice(ref mut p,root,0));let usize opened=built(ir::slice_open(ref mut p,loan,lo,hi,0));}
    let usize literal=built(ir::raw(ref mut p,69,0,0,1,0));p.code[literal*8+6]=3;
    var usize[8] actuals=[192;8];if(prefix){actuals[0]=fill;}
    let usize first=p.count;let usize a=built(ir::call(ref mut p,1,ref actuals[..arity],0));p.code[first*8]=78;
    var usize i=0;while(i<arity){actuals[i]=if(prefix && i==0){fill}else if(image_only){192}else{160};i+=1;}
    let usize second=p.count;let usize b=built(ir::call(ref mut p,1,ref actuals[..arity],0));p.code[second*8]=78;
    let usize closed=built(ir::raw(ref mut p,70,0,0,0,0));
    if(!image_only){let usize ended=built(ir::slice_close(ref mut p,0,0));let usize dropped=built(ir::array_drop(ref mut p,0,0));}
    if(length){let usize expected=built(ir::integer(ref mut p,if(projection==2){1}else if(projection==3){0}else{3},12,0));
        let usize left=built(ir::emit(ref mut p,11,a,expected,0));let usize branch=p.count;let usize jump=built(ir::raw(ref mut p,20,0,left,0,0));
        let usize right=built(ir::emit(ref mut p,11,b,expected,0));let usize other=p.count;let usize jump2=built(ir::raw(ref mut p,20,0,right,0,0));
        let usize answer=built(ir::literal(ref mut p,42,0));let usize done=built(ir::emit(ref mut p,8,answer,0,0));let usize bad=p.count;
        let usize zero=built(ir::literal(ref mut p,0,0));let usize failed=built(ir::emit(ref mut p,8,zero,0,0));
        let usize x=built(ir::patch(ref mut p,branch,bad,0));let usize y=built(ir::patch(ref mut p,other,bad,0));
    }else{let usize total=built(ir::emit(ref mut p,2,a,b,0));let usize done=built(ir::emit(ref mut p,8,total,0,0));}end(ref mut p,0);
    var u8[128] parameters=[0;128];p.arities[1]=arity;i=0;var usize count=0;
    if(prefix){let usize scalar=fresh(ref mut p,10);i=1;}
    let usize start=p.registers;while(i<arity){let usize formal=fresh(ref mut p,0);parameters[formal]=3;i+=1;count+=1;}
    i=0;while(i<count){let usize param=built(ir::raw(ref mut p,77,i+1,start+i,3,0));i+=1;}
    var usize selected=1;
    if(projection==1){let usize alias=built(ir::raw(ref mut p,75,count+1,1,0,0));selected=count+1;}
    if(projection>=2){let usize lo=built(ir::integer(ref mut p,1,12,0));let usize hi=built(ir::integer(ref mut p,if(projection==3){1}else{2},12,0));
        let usize range=built(ir::raw(ref mut p,76,count+1,1,lo,0));p.code[range*8+4]=byte(hi);selected=count+1;}
    // End the original logical formal before accessing or forwarding its alias.
    if(selected!=1){let usize close=built(ir::raw(ref mut p,70,1,0,0,0));}
    var usize result=0;
    if(forward){let usize[1] refs=[192+selected];let usize at=p.count;result=built(ir::call(ref mut p,2,ref refs,0));p.code[at*8]=78;}
    else if(length){result=fresh(ref mut p,12);let usize len=built(ir::raw(ref mut p,72,result,selected,0,0));}
    else{let usize index=built(ir::integer(ref mut p,0,12,0));let usize value=fresh(ref mut p,10);
        let usize read=built(ir::raw(ref mut p,71,value,selected,index,0));result=built(ir::widen(ref mut p,value,1,0));}
    i=1;while(i<=count){if(i!=1 || selected==1){let usize close=built(ir::raw(ref mut p,70,i,0,0,0));}i+=1;}
    if(selected!=1){let usize close=built(ir::raw(ref mut p,70,selected,0,0,0));}
    let usize returned=built(ir::emit(ref mut p,8,result,0,0));end(ref mut p,1);
    if(forward){let usize formal=fresh(ref mut p,0);parameters[formal]=3;p.arities[2]=1;
        let usize param=built(ir::raw(ref mut p,77,count+2,formal,3,0));
        if(length){result=fresh(ref mut p,12);let usize len=built(ir::raw(ref mut p,72,result,count+2,0,0));}
        else{let usize index=built(ir::integer(ref mut p,0,12,0));let usize value=fresh(ref mut p,10);
            let usize read=built(ir::raw(ref mut p,71,value,count+2,index,0));result=built(ir::widen(ref mut p,value,1,0));}
        let usize close=built(ir::raw(ref mut p,70,count+2,0,0,0));let usize ret=built(ir::emit(ref mut p,8,result,0,0));end(ref mut p,2);
    }
    return calls::Program{.body=p,.parameters=parameters,.results=[0;16],.origins=[0;16]};
}
fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
fn Result<execution::Scalar,errors::Error> run(ref programs::ReferenceProgram p,ref mut runtime::State state,ref mut u8[] data,usize budget,usize entry){
    let runtime::Capture[1] none=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];let i64[1] values=[0];
    let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    return programs::run_reference_scalar(p,entry,ref none[..0],ref values[..0],ref inputs[..0],state,data,budget);
}
// Independent numeric oracle for the fixtures' executed straight-line paths.
// Each selected reference has the same backing within one helper invocation.
fn usize price(ref calls::Program unit,usize f,bool loan){
    let ref ir::Program p=ref unit.body;var usize total=344064+p.arities[f];var usize pc=p.starts[f];
    while(pc<p.ends[f]){let usize at=pc*8;let u8 op=p.code[at];total+=1;
        if(op==8){return total;}
        if(op==33){total+=61;}else if(op==37){total+=49;}else if(op==54){total+=65537;}else if(op==56){total+=4097;}
        else if(op==69 || op==75){total+=16;}else if(op==76){total+=127;}
        else if(op==77){total+=16+if(loan){4097}else{0};}
        else if(op==71){total+=if(loan){4131}else{17};}else if(op==72){total+=if(loan){4097}else{16};}
        else if(op==78){let usize target=p.code[at+2] as usize;let usize map=p.code[at+3] as usize;var usize refs=0;var usize runtime=0;var usize i=0;
            while(i<p.arities[target]){if(unit.parameters[p.register_starts[target]+i]!=0){refs+=1;let usize actual=p.call_args[map*8+i] as usize;
                if((actual>=160 && actual<176) || (f!=0 && loan)){runtime+=1;}}i+=1;}
            total+=32+32*refs+4097*runtime+price(unit,target,runtime!=0);
        }else{assert(op<33 || op==70);}pc+=1;
    }assert(false);return 0;
}
fn void trial(ref programs::ReferenceProgram p,usize budget,i64 expected,usize left,u8 error,bool image_only){
    var runtime::State state=runtime::empty(if(image_only){0}else{4});var u8[4] data=[99;4];
    switch(run(p,ref mut state,ref mut data[..if(image_only){0}else{4}],budget,0)){
        case .ok(v):{assert(error==0 && v.value==expected && v.remaining==left);}
        case .err(e):{assert(error!=0 && e.kind==error);}
    };drained(ref state);
}
fn void example(usize arity,bool prefix,u8 projection,bool length,bool forward,bool image_only){
    let calls::Program code=unit(arity,prefix,projection,length,forward,image_only);let usize required=price(ref code,0,false);
    let programs::ReferenceProgram p=switch(programs::retain_references(ref code,image(),579)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let i64 expected=if(length){42}else if(projection==2){if(image_only){84}else{66}}else{if(image_only){240}else{144}};
    trial(ref p,required-1,expected,0,8,image_only);trial(ref p,required,expected,0,0,image_only);trial(ref p,required+1,expected,1,0,image_only);
}
@test fn void the_same_formal_executes_image_and_runtime_bytes_at_exact_fuel(){example(1,false,0,false,false,false);}
@test fn void aliases_and_narrowed_ranges_survive_logical_parent_close_and_forwarding(){
    example(1,false,1,false,false,false);example(1,false,2,false,true,false);example(2,true,2,false,true,false);
}
@test fn void length_and_empty_ranges_use_actual_backing_and_keep_zero_backing_images(){
    example(1,false,0,true,false,false);example(1,false,2,true,true,false);example(1,false,3,true,false,false);
    example(1,false,2,false,true,true);
}
@test fn void all_eight_runtime_actuals_and_scalar_prefixes_keep_receipt_positions(){example(8,false,0,false,false,false);example(8,true,2,false,true,false);}
@test fn void range_and_index_failures_drain_native_call_owners_and_loans(){
    var calls::Program code=unit(1,false,2,false,false,false);var usize pc=code.body.starts[1];
    while(pc<code.body.ends[1]){if(code.body.code[pc*8]==1 && code.body.constants[code.body.code[pc*8+2] as usize]==2){
        let usize constant=code.body.code[pc*8+2] as usize;code.body.constants[constant]=4;}pc+=1;}
    let programs::ReferenceProgram p=switch(programs::retain_references(ref code,image(),579)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    trial(ref p,10000000,0,0,14,false);trial(ref p,1,0,0,8,false);
    code=unit(1,false,0,false,false,false);pc=code.body.starts[1];
    while(pc<code.body.ends[1]){if(code.body.code[pc*8]==1){let usize constant=code.body.code[pc*8+2] as usize;code.body.constants[constant]=-1;}pc+=1;}
    let programs::ReferenceProgram q=switch(programs::retain_references(ref code,image(),579)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    trial(ref q,10000000,0,0,14,false);
}
@test fn void retained_reference_code_is_immutable_and_external_generic_entries_reject(){
    var calls::Program code=unit(1,false,2,false,true,false);let usize budget=price(ref code,0,false);
    let programs::ReferenceProgram p=switch(programs::retain_references(ref code,image(),579)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    code.body.code[0]=255;code.parameters=[0;128];trial(ref p,budget,66,0,0,false);
    var runtime::State state=runtime::empty(4);var u8[4] data=[99;4];
    switch(run(ref p,ref mut state,ref mut data,10000000,1)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};drained(ref state);
}
@test fn void runtime_words_require_the_exact_formal_receipt_and_cannot_resurrect_a_returned_call(){
    let calls::Program code=unit(1,false,0,false,false,false);let images::Image image=image();
    let verifier::ReferenceCallProof proof=switch(verifier::inspect_reference_calls(ref code,ref image)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var runtime::State state=runtime::empty(4);var u8[4] data=[0;4];
    let layouts::Array shape=switch(layouts::scalar(10,3)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let owners::Token root=switch(owners::create(ref shape,24,ref mut data,ref mut state.runtime.owners)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket ticket=switch(slices::open(ref mut pool,ref mut table,root,0,3,4)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    state.runtime.pool=pool;state.runtime.owners=table;
    var runtime::Contract contract=runtime::Contract{.tags=[0;8],.arity=1,.selected=0};contract.tags[0]=10;
    let runtime::Capture[1] captures=[runtime::capture(ticket,false,false)];
    var runtime::Call call=switch(runtime::enter_call(ref mut state,contract,ref captures,4,147456)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var frames::Frames bindings=frames::empty(ref state);let usize pushed=built(frames::push(ref code.body,ref mut bindings,call,1,128,32,0));
    var u32[16] current=[0;16];current[1]=switch(words::pack(0,views::Span{.start=1,.length=1},77)){case .ok(v):{v}case .err(_):{assert(false);0}};
    let access::Source source=switch(references::source(ref code.body,ref proof.statics,1,1,ref current,2,ref bindings,3,77)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    switch(access::read(ref source,ref proof.statics,1,ref current,2,images::payload(ref image),ref state.runtime.pool,ref state.runtime.owners,ref data,0,4131,77)){
        case .ok(v):{assert(v.value==24 && v.remaining==0);}case .err(_):{assert(false);}
    };
    bindings.tags[8]=0;assert(!references::source(ref code.body,ref proof.statics,1,1,ref current,2,ref bindings,3,77).is_ok);bindings.tags[8]=10;
    current[1]=switch(words::pack(1,views::Span{.start=1,.length=1},77)){case .ok(v):{v}case .err(_):{assert(false);0}};
    assert(!references::source(ref code.body,ref proof.statics,1,1,ref current,2,ref bindings,3,77).is_ok);
    let runtime::Resumed resumed=switch(runtime::leave_call(ref mut state,ref mut call,4,196608)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(access::read(ref source,ref proof.statics,1,ref current,2,images::payload(ref image),ref state.runtime.pool,ref state.runtime.owners,ref data,0,4130,77)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}
    };
    switch(access::read(ref source,ref proof.statics,1,ref current,2,images::payload(ref image),ref state.runtime.pool,ref state.runtime.owners,ref data,0,4131,77)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}
    };
    assert(runtime::abort(ref mut state,4,0).is_ok);drained(ref state);
}
