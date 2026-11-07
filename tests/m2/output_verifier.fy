module tests::m2::output_verifier;
import compiler as compiler;
import source_snapshot as sources;
import module_index as modules;
import module_entry as entries;
import static_image as images;
import static_call_ir as calls;
import ir as ir;
import verifier as verifier;

fn images::Builder builder(){return switch(images::builder(4096)){case .ok(v):{v}case .err(_):{assert(false);builder()}};}
fn images::Image image(ref images::Builder b){return switch(images::freeze(b,65536)){case .ok(v):{v}case .err(_):{assert(false);return image(b);}};}
fn calls::Program lowered(ref u8[] source,ref mut images::Builder b){
    var sources::Builder build=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{assert(false);return lowered(source,b);}};
    assert(sources::add(ref mut build,b"test",source).is_ok);
    let sources::Snapshot snapshot=switch(sources::freeze(ref build)){case .ok(v):{v}case .err(_):{assert(false);return lowered(source,b);}};
    let modules::Index index=switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);return lowered(source,b);}};
    let entries::Entry e=switch(entries::select_i32(index,b"app",b"chosen")){case .ok(v):{v}case .err(_):{assert(false);return lowered(source,b);}};
    var calls::Program p=calls::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    assert(compiler::lower_output_modules(ref e,b,ref mut p).is_ok);return p;
}
fn usize find(ref calls::Program p,u8 op,usize start){var usize pc=start;while(pc<p.body.count){if(p.body.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;}
fn void fail(ref calls::Program p,ref images::Image literal){assert(!verifier::inspect_output_returns(p,literal,false).is_ok);}
fn void replace(ref mut calls::Program p,usize pc,u8 op,u8 dst,u8 a,u8 b){let usize at=pc*8;
    p.body.code[at]=op;p.body.code[at+1]=dst;p.body.code[at+2]=a;p.body.code[at+3]=b;
    p.body.code[at+4]=0;p.body.code[at+5]=0;p.body.code[at+6]=0;p.body.code[at+7]=0;
}
@test fn void emit_canonical_operands_reserved_bytes_and_mixed_namespaces(){
    var images::Builder b=builder();let calls::Program p=lowered(b"module app;pub fn i32 chosen(){output::emit(ref b\"ab\");return 0;}",ref mut b);
    let images::Image literal=image(ref b);assert(verifier::inspect_output_returns(ref p,ref literal,false).is_ok);
    let usize at=find(ref p,116,0)*8;var calls::Program bad=p;
    bad.body.code[at+1]=1;fail(ref bad,ref literal);
    bad=p;bad.body.code[at+2]=16;fail(ref bad,ref literal);
    bad=p;bad.body.code[at+2]=255;fail(ref bad,ref literal);
    var usize i=0;while(i<4){bad=p;bad.body.code[at+3]=if(i==0){0}else if(i==1){2}else if(i==2){3}else{255};fail(ref bad,ref literal);i+=1;}
    i=4;while(i<8){bad=p;bad.body.code[at+i]=1;fail(ref bad,ref literal);i+=1;}
    assert(!verifier::inspect_reference_returns(ref p,ref literal).is_ok);
    assert(!verifier::inspect_reference_calls(ref p,ref literal).is_ok);
    assert(!verifier::verify_static_calls(ref p,ref literal).is_ok);
    assert(!verifier::inspect_input_returns(ref p,ref literal).is_ok);
    assert(!verifier::inspect_statics(ref p.body,ref literal).is_ok);
    assert(!verifier::verify(ref p.body).is_ok);
}
@test fn void stale_or_nonbyte_views_and_foreign_function_sites_are_rejected(){
    var images::Builder b=builder();let calls::Program p=lowered(b"module app;fn void helper(){output::emit(ref b\"h\");}pub fn i32 chosen(){let ref str text=\"abc\";let ref u8[] bytes=b\"ab\";output::emit(ref bytes);output::emit(ref bytes);return 0;}",ref mut b);
    let images::Image literal=image(ref b);assert(verifier::inspect_output_returns(ref p,ref literal,false).is_ok);
    let usize first=find(ref p,116,p.body.starts[p.body.entry]);let usize second=find(ref p,116,first+1);
    let u8 site=p.body.code[first*8+2];var calls::Program bad=p;
    replace(ref mut bad,first,70,site,0,0);fail(ref bad,ref literal);
    bad=p;bad.body.code[second*8+2]=p.body.code[find(ref p,116,0)*8+2];fail(ref bad,ref literal);
    bad=p;bad.body.code[second*8+2]=p.body.code[find(ref p,69,p.body.starts[p.body.entry])*8+1];fail(ref bad,ref literal);
}
@test fn void live_loan_type_initialization_and_suspension_are_required(){
    var images::Builder b=builder();let calls::Program p=lowered(b"module app;pub fn i32 chosen(){let u8[2] a=[65;2];let ref u8[] part=ref a;output::emit(ref part);output::emit(ref part);return 0;}",ref mut b);
    let images::Image literal=image(ref b);assert(verifier::inspect_output_returns(ref p,ref literal,false).is_ok);
    let usize first=find(ref p,116,0);let usize second=find(ref p,116,first+1);let u8 site=p.body.code[first*8+2];var calls::Program bad=p;
    bad.body.code[first*8+3]=1;fail(ref bad,ref literal);
    bad=p;replace(ref mut bad,first,56,site,0,0);fail(ref bad,ref literal);
    bad=p;replace(ref mut bad,find(ref p,54,0),116,0,site,2);fail(ref bad,ref literal);
    bad=p;bad.body.code[second*8+2]=15;fail(ref bad,ref literal);
    bad=p;bad.body.arrays.elements[0]=1;fail(ref bad,ref literal);
    var images::Builder c=builder();let calls::Program q=lowered(b"module app;pub fn i32 chosen(){var u8[2] a=[65;2];let ref mut u8[] part=ref mut a;output::emit(ref part[0..1]);return 0;}",ref mut c);
    let images::Image other=image(ref c);assert(verifier::inspect_output_returns(ref q,ref other,false).is_ok);
    var calls::Program wrong=q;wrong.body.code[find(ref q,116,0)*8+2]=q.body.code[find(ref q,61,0)*8+2];fail(ref wrong,ref other);
}
@test fn void full_scalar_owner_and_return_proof_and_dead_blocks_are_preserved(){
    var images::Builder b=builder();let calls::Program p=lowered(b"module app;pub fn i32 chosen(){output::emit(ref b\"ab\");return 7;}",ref mut b);
    let images::Image literal=image(ref b);let usize emit=find(ref p,116,0);var calls::Program bad=p;
    bad.body.return_types[p.body.entry]=2;fail(ref bad,ref literal);
    bad=p;bad.body.code[find(ref p,1,0)*8+2]=127;fail(ref bad,ref literal);
    // Jump over the canonical EMIT and its OPEN; every dead PC is still inspected.
    bad=p;let usize ret=find(ref p,1,emit+1);var u8 target=0;var usize n=0;while(n<ret){target+=1;n+=1;}
    replace(ref mut bad,0,19,0,target,0);fail(ref bad,ref literal);
    bad=p;replace(ref mut bad,0,116,0,0,1);fail(ref bad,ref literal);
    bad=p;bad.body.code[emit*8]=117;fail(ref bad,ref literal);
}
