module tests::m2::static_call_admission;
import static_call_ir as calls;
import ir as ir;
import static_image as images;
import errors as errors;
import std::num as num;
import static_views as views;
import static_execution as execution;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import program_image as programs;
import slice_result_ir as borrowed;
fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize fresh(ref mut ir::Program p,u8 kind){let usize r=p.registers;p.types[r]=kind;p.registers+=1;return r;}
fn void end(ref mut ir::Program p,usize f){let usize pc=p.count;let usize r=p.registers;p.ends[f]=pc;p.register_ends[f]=r;
    if(f+1<p.function_count){p.starts[f+1]=pc;p.register_starts[f+1]=r;}}
fn usize open(ref mut ir::Program p,usize dst,u8 kind){let usize pc=built(ir::raw(p,69,dst,if(kind==1){0}else{1},kind as usize,0));p.code[pc*8+6]=1;return pc;}
fn void close(ref mut ir::Program p,usize site){let usize pc=built(ir::raw(p,70,site,0,0,0));}
fn void returned(ref mut ir::Program p,usize site){let usize pc=built(ir::raw(p,79,0,site,0,0));}
fn void answer(ref mut ir::Program p,usize site,u8 kind){
    var usize bytes=site;if(kind==2){let usize pc=built(ir::raw(p,74,4,site,0,0));close(p,site);bytes=4;}
    let usize index=built(ir::integer(p,0,12,0));let usize byte=fresh(p,10);let usize read=built(ir::raw(p,71,byte,bytes,index,0));
    close(p,bytes);let usize value=built(ir::widen(p,byte,1,0));let usize pc=built(ir::emit(p,8,value,0,0));
}
fn images::Image image(){
    var images::Builder b=switch(images::builder(6)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    let usize raw=switch(images::intern_bytes(ref mut b,b"*")){case .ok(v):{v}case .err(_):{assert(false);0}};
    let usize text=switch(images::intern_text(ref mut b,b"*")){case .ok(v):{v}case .err(_):{assert(false);0}};
    let usize raw_tail=switch(images::intern_bytes(ref mut b,b"x*")){case .ok(v):{v}case .err(_):{assert(false);0}};
    let usize text_tail=switch(images::intern_text(ref mut b,b"x*")){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(images::freeze(ref b,8192)){case .ok(v):{v}case .err(_):{assert(false);image()}};
}
fn calls::Proof accepted(ref calls::Program p){let images::Image data=image();return switch(verifier::verify_static_calls(p,ref data)){
    case .ok(v):{v.recipes}case .err(_):{assert(false);calls::Proof{.definitions=[256;16],.functions=[16;16],.kinds=[0;16],
        .formal_sites=[0;128],.site_origins=[0;16],.result_origins=[0;16],.sites=0,.calls=0,.returns=0,.rounds=0}}
};}
fn void rejected(ref calls::Program p){let images::Image data=image();switch(verifier::verify_static_calls(p,ref data)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}
};}
fn usize find(ref ir::Program p,u8 op,usize nth){var usize pc=0;var usize n=0;while(pc<p.count){
    if(p.code[pc*8]==op){if(n==nth){return pc;}n+=1;}pc+=1;}assert(false);return 0;}
// Modes: direct bytes/text, alias, range, or text->bytes. All origins still
// identify the exact logical input position, regardless of storage projections.
fn calls::Program parameter(u8 kind,u8 mode,bool scalar_prefix){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=0;p.return_types[0]=1;p.return_types[1]=0;
    var u8[128] parameters=[0;128];var u8[16] results=[0;16];var u8[16] origins=[0;16];
    results[1]=if(mode==3){1}else{kind};origins[1]=if(scalar_prefix){2}else{1};
    let usize root=open(ref mut p,0,kind);p.call_count=1;p.call_arities[0]=if(scalar_prefix){2}else{1};
    if(scalar_prefix){let usize scalar=built(ir::literal(ref mut p,42,0));p.call_args[0]=0;p.call_args[1]=192;}
    else{p.call_args[0]=192;}
    let usize call=built(ir::raw(ref mut p,78,1,1,0,0));close(ref mut p,0);answer(ref mut p,1,results[1]);end(ref mut p,0);
    if(scalar_prefix){let usize scalar=fresh(ref mut p,1);}
    let usize formal=fresh(ref mut p,0);parameters[formal]=kind;p.arities[1]=if(scalar_prefix){2}else{1};
    let usize param=built(ir::raw(ref mut p,77,2,formal,kind as usize,0));var usize selected=2;
    if(mode==1){let usize alias=built(ir::raw(ref mut p,75,3,2,0,0));selected=3;}
    if(mode==2){let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
        let usize range=built(ir::raw(ref mut p,76,3,2,lo,0));p.code[range*8+4]=switch(num::u8_from_i64(switch(num::i64_from_usize(hi)){case .ok(v):{v}case .err(_):{assert(false);0}})){case .ok(v):{v}case .err(_):{assert(false);0}};selected=3;}
    if(mode==3){let usize bytes=built(ir::raw(ref mut p,74,3,2,0,0));selected=3;}
    if(selected!=2){close(ref mut p,2);}returned(ref mut p,selected);end(ref mut p,1);
    return calls::Program{.body=p,.parameters=parameters,.results=results,.origins=origins};
}
fn calls::Program literal(bool recursive,bool grounded){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=0;p.return_types[0]=1;p.return_types[1]=0;
    let usize condition=built(ir::boolean(ref mut p,false,0));p.call_count=if(recursive){2}else{1};p.call_arities[0]=if(recursive && grounded){1}else{0};
    if(recursive && grounded){p.call_args[0]=0;}
    let usize call=built(ir::raw(ref mut p,78,0,1,0,0));answer(ref mut p,0,1);end(ref mut p,0);
    var usize branch=0;var usize formal=0;
    if(recursive && grounded){formal=fresh(ref mut p,2);p.arities[1]=1;branch=built(ir::raw(ref mut p,20,0,formal,0,0));}
    if(recursive){p.call_arities[1]=if(grounded){1}else{0};if(grounded){p.call_args[8]=switch(num::u8_from_i64(switch(num::i64_from_usize(formal)){case .ok(v):{v}case .err(_):{assert(false);0}})){case .ok(v):{v}case .err(_):{assert(false);0}};}
        let usize self=built(ir::raw(ref mut p,78,2,1,1,0));returned(ref mut p,2);}
    if(!recursive || grounded){let usize base=p.count;let usize root=open(ref mut p,1,1);returned(ref mut p,1);
        if(recursive){let usize patched=built(ir::patch(ref mut p,branch,base,0));}}
    end(ref mut p,1);var u8[16] results=[0;16];var u8[16] origins=[0;16];results[1]=1;origins[1]=9;
    return calls::Program{.body=p,.parameters=[0;128],.results=results,.origins=origins};
}
fn verifier::StaticCallProof proved(ref calls::Program p,ref images::Image data){
    return switch(verifier::verify_static_calls(p,data)){case .ok(v):{v}case .err(_):{assert(false);return proved(p,data);}};
}
fn void recipe(ref calls::Program p){let images::Image data=image();assert(calls::inspect(p,ref data).is_ok);}
@test fn void complete_admission_checks_scalar_types_and_all_static_result_shapes(){
    let calls::Program a=parameter(1,0,false);let calls::Proof pa=accepted(ref a);assert(pa.result_origins[1]==1);
    let calls::Program b=parameter(1,1,false);let calls::Proof pb=accepted(ref b);assert(pb.site_origins[3]==1);
    let calls::Program c=parameter(1,2,false);let calls::Proof pc=accepted(ref c);assert(pc.site_origins[3]==1);
    let calls::Program d=parameter(2,0,false);let calls::Proof pd=accepted(ref d);assert(pd.kinds[1]==2);
    let calls::Program e=parameter(2,3,false);let calls::Proof pe=accepted(ref e);assert(pe.kinds[3]==1);
    let calls::Program f=parameter(1,0,true);let calls::Proof pf=accepted(ref f);assert(pf.result_origins[1]==2);
    let calls::Program g=literal(true,true);let calls::Proof pg=accepted(ref g);assert(pg.result_origins[1]==9);
}
fn calls::Program scalar_result(){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=0;p.return_types[0]=1;p.return_types[1]=1;p.arities[1]=1;
    let usize root=open(ref mut p,0,1);let usize dst=fresh(ref mut p,1);p.call_count=1;p.call_arities[0]=1;p.call_args[0]=192;
    let usize call=built(ir::raw(ref mut p,78,dst,1,0,0));close(ref mut p,0);let usize done=built(ir::emit(ref mut p,8,dst,0,0));end(ref mut p,0);
    let usize formal=fresh(ref mut p,0);let usize param=built(ir::raw(ref mut p,77,1,formal,1,0));close(ref mut p,1);
    let usize answer=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,answer,0,0));end(ref mut p,1);
    var u8[128] parameters=[0;128];parameters[formal]=1;
    return calls::Program{.body=p,.parameters=parameters,.results=[0;16],.origins=[0;16]};
}
@test fn void static_formal_positions_never_become_scalar_values_or_destinations(){
    var calls::Program p=scalar_result();let calls::Proof good=accepted(ref p);
    let usize ret=find(ref p.body,8,1);let usize formal=p.body.register_starts[1];
    p.body.code[ret*8+2]=switch(num::u8_from_i64(switch(num::i64_from_usize(formal)){case .ok(v):{v}case .err(_):{assert(false);0}})){case .ok(v):{v}case .err(_):{assert(false);0}};
    recipe(ref p);rejected(ref p);
    p=scalar_result();let usize constant=find(ref p.body,1,0);
    p.body.code[constant*8+1]=switch(num::u8_from_i64(switch(num::i64_from_usize(formal)){case .ok(v):{v}case .err(_):{assert(false);0}})){case .ok(v):{v}case .err(_):{assert(false);0}};
    recipe(ref p);rejected(ref p);
}
@test fn void ordinary_argument_and_register_proof_is_not_replaced_by_recipe_liveness(){
    var calls::Program p=parameter(1,0,true);p.body.types[0]=12;recipe(ref p);rejected(ref p);
    p=parameter(1,0,false);let usize read=find(ref p.body,71,0);p.body.code[read*8+3]=1;recipe(ref p);rejected(ref p);
}
fn calls::Program owned(bool drop){
    var calls::Program p=parameter(1,2,false);let usize ret=find(ref p.body,79,0);let usize range=find(ref p.body,76,0);
    let usize fill=p.body.code[range*8+3] as usize;let usize id=built(ir::array_in(ref mut p.body,1,12,1,false,0));assert(id==0);
    p.body.code[ret*8]=33;p.body.code[ret*8+1]=0;
    p.body.code[ret*8+2]=switch(num::u8_from_i64(switch(num::i64_from_usize(fill)){case .ok(v):{v}case .err(_):{assert(false);0}})){case .ok(v):{v}case .err(_):{assert(false);0}};
    if(drop){let usize closed=built(ir::array_drop(ref mut p.body,id,0));}
    returned(ref mut p.body,3);let usize end=p.body.count;p.body.ends[1]=end;return p;
}
@test fn void returning_static_storage_cannot_leak_an_ordinary_owned_array(){
    let calls::Program clean=owned(true);let calls::Proof checked=accepted(ref clean);
    let calls::Program leak=owned(false);recipe(ref leak);rejected(ref leak);
}
fn calls::Program windows(u8 kind){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=0;p.return_types[0]=1;p.return_types[1]=0;p.arities[1]=1;
    let usize a=open(ref mut p,0,kind);let usize b=open(ref mut p,1,kind);p.code[b*8+2]=if(kind==1){2}else{3};p.code[b*8+6]=2;
    p.call_count=2;p.call_arities[0]=1;p.call_arities[1]=1;p.call_args[0]=192;p.call_args[8]=193;
    let usize first=built(ir::raw(ref mut p,78,2,1,0,0));close(ref mut p,2);
    let usize second=built(ir::raw(ref mut p,78,3,1,1,0));close(ref mut p,0);close(ref mut p,1);
    var usize bytes=3;if(kind==2){let usize converted=built(ir::raw(ref mut p,74,5,3,0,0));close(ref mut p,3);bytes=5;}
    let usize index=built(ir::integer(ref mut p,1,12,0));let usize value=fresh(ref mut p,10);let usize read=built(ir::raw(ref mut p,71,value,bytes,index,0));
    close(ref mut p,bytes);let usize wide=built(ir::widen(ref mut p,value,1,0));let usize done=built(ir::emit(ref mut p,8,wide,0,0));end(ref mut p,0);
    let usize formal=fresh(ref mut p,0);let usize param=built(ir::raw(ref mut p,77,4,formal,kind as usize,0));returned(ref mut p,4);end(ref mut p,1);
    var u8[128] parameters=[0;128];parameters[formal]=kind;var u8[16] results=[0;16];var u8[16] origins=[0;16];results[1]=kind;origins[1]=1;
    return calls::Program{.body=p,.parameters=parameters,.results=results,.origins=origins};
}
fn void word(ref verifier::StaticCallProof proof,u32 packed,bool valid){
    switch(views::inspect(ref proof.statics,4,1,0,packed,6,0)){case .ok(_):{assert(valid);}case .err(e):{assert(!valid && e.kind==5);}};
}
@test fn void one_parameter_accepts_distinct_root_windows_without_admitting_other_image_bytes(){
    let calls::Program p=windows(1);let images::Image data=image();let verifier::StaticCallProof proof=proved(ref p,ref data);
    assert(proof.statics.roots[2]==1 && proof.statics.roots[3]==2 && proof.statics.roots[4]==3);
    word(ref proof,1,true);word(ref proof,16386,true);word(ref proof,8193,false);word(ref proof,4,false);
}
@test fn void text_parameters_preserve_each_exact_validated_window(){
    let calls::Program p=windows(2);let images::Image data=image();let verifier::StaticCallProof proof=proved(ref p,ref data);
    word(ref proof,8193,true);word(ref proof,32770,true);word(ref proof,32769,false);word(ref proof,1,false);
}
fn void ordinary(ref u8[] source){
    let ir::Program body=switch(compiler::compile(source)){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};
    let calls::Program p=calls::Program{.body=body,.parameters=[0;128],.results=[0;16],.origins=[0;16]};let calls::Proof checked=accepted(ref p);
}
@test fn void existing_array_record_and_runtime_loan_arguments_keep_their_canonical_proof(){
    ordinary(b"module main;fn i32 f(u8[1] a,i32 n){return (a[0] as i32)+n;}fn i32 main(){let u8[1] a=[20;1];return f(a,22);}");
    ordinary(b"module main;struct P{i32 x;}fn i32 f(P p,i32 n){return p.x+n;}fn i32 main(){let P p=P{.x=20};return f(p,22);}");
    ordinary(b"module main;fn i32 f(ref i32[] p){return p[0]+35;}fn i32 main(){let i32[1] a=[7;1];let ref i32[] r=ref a;return f(ref r);}");
}
@test fn void bare_verifier_and_legacy_frame_step_do_not_admit_the_call_profile(){
    var ir::Program body=ir::empty();body.function_count=2;body.entry=0;body.return_types[0]=1;body.return_types[1]=1;
    let usize[1] none=[0];let usize call=built(ir::call(ref mut body,1,ref none[..0],0));let usize done=built(ir::emit(ref mut body,8,call,0,0));end(ref mut body,0);
    let usize value=built(ir::literal(ref mut body,42,0));let usize ret=built(ir::emit(ref mut body,8,value,0,0));end(ref mut body,1);body.code[0]=78;
    assert(!verifier::verify(ref body).is_ok);
    let calls::Program p=parameter(1,0,false);let images::Image data=image();let verifier::StaticCallProof proof=proved(ref p,ref data);let usize pc=find(ref p.body,77,0);
    var i64[128] values=[99;128];var u32[16] words=[1;16];
    switch(execution::step_frame(ref p.body,ref proof.statics,images::payload(ref data),pc,1,ref mut values,0,16000000,ref mut words)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}
    };assert(values[2]==99 && words[2]==1);
}
