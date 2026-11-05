module tests::m2::reference_call_admission;
import static_call_ir as calls;
import ir as ir;
import static_image as images;
import verifier as verifier;
import program_image as programs;
import errors as errors;
import std::num as num;
import compiler as compiler;

fn usize built(Result<usize,errors::Error> value){return switch(value){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 byte(usize value){return switch(num::u8_from_i64(switch(num::i64_from_usize(value)){
    case .ok(v):{v}case .err(_):{assert(false);0}
})){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize fresh(ref mut ir::Program p,u8 tag){let usize r=p.registers;p.types[r]=tag;p.registers+=1;return r;}
fn void end(ref mut ir::Program p,usize f){let usize pc=p.count;let usize r=p.registers;p.ends[f]=pc;p.register_ends[f]=r;
    if(f+1<p.function_count){p.starts[f+1]=pc;p.register_starts[f+1]=r;}}
fn images::Image image(){
    var images::Builder b=switch(images::builder(2)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    let usize id=switch(images::intern_bytes(ref mut b,b"*")){case .ok(v):{v}case .err(_):{assert(false);0}};
    let usize text=switch(images::intern_text(ref mut b,b"*")){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(images::freeze(ref b,578)){case .ok(v):{v}case .err(_):{assert(false);image()}};
}
// Two CALLs target one signature. The first uses an image byte site; the
// second uses a live shared runtime byte slice, including repeated actuals.
fn calls::Program program(usize arity,bool prefix,u8 projection){
    var ir::Program p=ir::empty();p.function_count=if(projection==3){3}else{2};p.return_types[0]=1;p.return_types[1]=1;
    if(projection==3){p.return_types[2]=1;}
    let usize root=built(ir::array_in(ref mut p,0,10,1,false,0));let usize fill=built(ir::integer(ref mut p,42,10,0));
    let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize loan=built(ir::slice(ref mut p,root,0));let usize opened=built(ir::slice_open(ref mut p,loan,lo,hi,0));
    let usize literal=built(ir::raw(ref mut p,69,0,0,1,0));p.code[literal*8+6]=1;
    var usize[8] actuals=[192;8];if(prefix){actuals[0]=fill;}
    let usize first=p.count;let usize a=built(ir::call(ref mut p,1,ref actuals[..arity],0));p.code[first*8]=78;
    let usize closed=built(ir::raw(ref mut p,70,0,0,0,0));
    var usize i=0;while(i<arity){actuals[i]=if(prefix && i==0){fill}else{160+loan};i+=1;}
    let usize second=p.count;let usize b=built(ir::call(ref mut p,1,ref actuals[..arity],0));p.code[second*8]=78;
    let usize ended=built(ir::slice_close(ref mut p,loan,0));let usize dropped=built(ir::array_drop(ref mut p,root,0));
    let usize done=built(ir::emit(ref mut p,8,b,0,0));end(ref mut p,0);
    var u8[128] parameters=[0;128];p.arities[1]=arity;i=0;var usize count=0;
    if(prefix){let usize scalar=fresh(ref mut p,10);i=1;}
    // Reserve the complete formal register prefix before emitting PARAMs.
    let usize start=p.registers;while(i<arity){let usize formal=fresh(ref mut p,0);parameters[formal]=3;i+=1;count+=1;}
    i=0;while(i<count){let usize param=built(ir::raw(ref mut p,77,i+1,start+i,3,0));i+=1;}
    var usize selected=1;
    if(projection==1){let usize alias=built(ir::raw(ref mut p,75,count+1,1,0,0));selected=count+1;}
    if(projection==2){let usize low=built(ir::integer(ref mut p,0,12,0));let usize high=built(ir::integer(ref mut p,1,12,0));
        let usize range=built(ir::raw(ref mut p,76,count+1,1,low,0));p.code[range*8+4]=byte(high);selected=count+1;}
    if(projection==3){
        let usize[1] refs=[193];let usize at=p.count;let usize result=built(ir::call(ref mut p,2,ref refs,0));p.code[at*8]=78;
        let usize close=built(ir::raw(ref mut p,70,1,0,0,0));let usize returned=built(ir::emit(ref mut p,8,result,0,0));end(ref mut p,1);
        let usize formal=fresh(ref mut p,0);parameters[formal]=3;p.arities[2]=1;
        let usize param=built(ir::raw(ref mut p,77,2,formal,3,0));selected=2;count=0;
    }
    let usize index=built(ir::integer(ref mut p,0,12,0));let usize value=fresh(ref mut p,10);
    let usize read=built(ir::raw(ref mut p,71,value,selected,index,0));let usize length=fresh(ref mut p,12);
    let usize len=built(ir::raw(ref mut p,72,length,selected,0,0));
    i=1;while(i<=count){let usize close=built(ir::raw(ref mut p,70,i,0,0,0));i+=1;}
    if(selected!=1){let usize close=built(ir::raw(ref mut p,70,selected,0,0,0));}
    let usize wide=built(ir::widen(ref mut p,value,1,0));let usize returned=built(ir::emit(ref mut p,8,wide,0,0));end(ref mut p,if(projection==3){2}else{1});
    return calls::Program{.body=p,.parameters=parameters,.results=[0;16],.origins=[0;16]};
}
fn usize find(ref ir::Program p,u8 op,usize nth){var usize n=0;var usize pc=0;
    while(pc<p.count){if(p.code[pc*8]==op){if(n==nth){return pc;}n+=1;}pc+=1;}assert(false);return 0;}
fn void accepted(ref calls::Program p,usize refs){let images::Image data=image();
    switch(verifier::inspect_reference_calls(p,ref data)){
        case .ok(v):{assert(v.recipes.calls==2 && v.statics.count==refs+1 && v.recipes.kinds[1]==3);
            assert(v.statics.roots[1]==1 && v.statics.parameters[p.body.register_starts[1]]==3);}
        case .err(_):{assert(false);}
    };
}
fn void rejected(ref calls::Program p){let images::Image data=image();switch(verifier::inspect_reference_calls(p,ref data)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}
};}
@test fn void one_byte_formal_accepts_both_backing_kinds_with_alias_and_range_proof(){
    let calls::Program direct=program(1,false,0);accepted(ref direct,1);
    let calls::Program alias=program(1,false,1);accepted(ref alias,2);
    let calls::Program range=program(1,false,2);accepted(ref range,2);
}
@test fn void eight_shared_actuals_and_scalar_prefixes_preserve_logical_positions(){
    let images::Image data=image();let calls::Program all=program(8,false,0);accepted(ref all,8);
    let calls::Program prefixed=program(8,true,2);
    switch(verifier::inspect_reference_calls(ref prefixed,ref data)){
        case .ok(v):{let usize start=prefixed.body.register_starts[1];assert(v.statics.parameters[start]==0 && v.statics.parameters[start+1]==3);
            assert(v.recipes.site_origins[1]==2 && v.recipes.site_origins[8]==2 && v.statics.roots[8]==1);}
        case .err(_):{assert(false);}
    };
}
@test fn void runtime_actuals_require_canonical_live_shared_byte_owners(){
    let images::Image data=image();var calls::Program p=program(1,false,0);
    p.body.arrays.elements[0]=1;p.body.types[0]=1;
    assert(calls::inspect_references(ref p,ref data).is_ok);rejected(ref p);
    p=program(1,false,0);p.body.arrays.mutable[0]=true;p.body.slice_elements[0]=128;
    assert(calls::inspect_references(ref p,ref data).is_ok);rejected(ref p);
    p=program(1,false,0);let usize call=find(ref p.body,78,1);var usize i=0;
    while(i<8){let u8 temp=p.body.code[call*8+i];let u8 next=p.body.code[(call+1)*8+i];
        p.body.code[call*8+i]=next;p.body.code[(call+1)*8+i]=temp;i+=1;}
    assert(calls::inspect_references(ref p,ref data).is_ok);rejected(ref p);
}
@test fn void scalar_owned_and_unknown_actual_encodings_cannot_manufacture_references(){
    let usize[5] invalid=[0,128,144,176,208];var usize i=0;while(i<5){
        var calls::Program p=program(1,false,0);p.body.call_args[8]=byte(invalid[i]);rejected(ref p);i+=1;
    }
    var calls::Program p=program(1,false,0);let usize open=find(ref p.body,69,0);
    p.body.code[open*8+2]=1;p.body.code[open*8+3]=2;rejected(ref p);
}
@test fn void reference_formals_never_become_scalar_cells_or_escaping_results(){
    var calls::Program p=program(1,false,0);let usize ret=find(ref p.body,8,1);let usize formal=p.body.register_starts[1];
    p.body.code[ret*8+2]=byte(formal);rejected(ref p);
    p=program(1,false,0);p.results[1]=3;p.origins[1]=1;p.body.return_types[1]=0;rejected(ref p);
    p=program(1,false,0);let usize close=find(ref p.body,70,1);p.body.code[close*8]=72;p.body.code[close*8+1]=byte(formal);
    p.body.code[close*8+2]=1;p.body.types[formal]=12;rejected(ref p);
}
@test fn void legacy_image_and_public_admission_stay_closed_to_unexecuted_reference_calls(){
    let calls::Program p=program(1,false,0);let images::Image data=image();
    assert(!calls::inspect(ref p,ref data).is_ok && !verifier::verify_static_calls(ref p,ref data).is_ok);
    assert(!verifier::verify(ref p.body).is_ok && !programs::retain_calls(ref p,image(),1024).is_ok);
}
@test fn void universal_byte_formals_forward_without_losing_image_root_or_logical_origin(){
    let calls::Program p=program(1,false,3);let images::Image data=image();
    switch(verifier::inspect_reference_calls(ref p,ref data)){
        case .ok(v):{assert(v.recipes.calls==3 && v.recipes.kinds[2]==3 && v.statics.roots[2]==1 && v.recipes.site_origins[2]==1);}
        case .err(_):{assert(false);}
    };
}
fn void insert(ref mut ir::Program p,usize at,u8 op,usize dst,usize a,usize b){
    let usize appended=built(ir::raw(p,op,dst,a,b,0));var u8[8] code=[0;8];var usize i=0;
    while(i<8){code[i]=p.code[appended*8+i];i+=1;}
    var usize pc=appended;while(pc>at){let usize offset=p.offsets[pc-1];p.offsets[pc]=offset;
        i=0;while(i<8){let u8 value=p.code[(pc-1)*8+i];p.code[pc*8+i]=value;i+=1;}pc-=1;}
    i=0;while(i<8){p.code[at*8+i]=code[i];i+=1;}p.offsets[at]=0;
    var usize f=0;while(f<p.function_count){if(p.starts[f]>=at){p.starts[f]+=1;}if(p.ends[f]>at){p.ends[f]+=1;}f+=1;}
}
@test fn void rootless_runtime_formals_reuse_canonical_caller_lifetime_proof(){
    var ir::Program p=switch(compiler::compile(b"module main;fn i32 f(i32 marker,ref u8[] a){return a[0] as i32;}fn i32 outer(ref u8[] p){return f(0,ref p);}fn i32 main(){let u8[1] a=[42;1];return outer(ref a);}")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let usize formal=p.register_starts[0];p.types[formal]=0;var u8[128] parameters=[0;128];parameters[formal]=3;
    let usize start=p.starts[0];insert(ref mut p,start,77,0,formal,3);p.starts[0]=start;
    let usize ret=p.ends[0]-1;insert(ref mut p,ret,70,0,0,0);
    let usize read=find(ref p,58,0);p.code[read*8]=71;p.code[read*8+2]=0;
    let usize call=find(ref p,9,0);let usize map=p.code[call*8+3] as usize;let u8 actual=p.call_args[map*8+1];
    p.call_args[map*8]=actual;p.code[call*8]=78;
    let calls::Program unit=calls::Program{.body=p,.parameters=parameters,.results=[0;16],.origins=[0;16]};
    let images::Image data=image();assert(verifier::inspect_reference_calls(ref unit,ref data).is_ok);
}
