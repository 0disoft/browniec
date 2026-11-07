module tests::m2::output_source;
import compiler as compiler;
import source_snapshot as sources;
import module_index as modules;
import module_entry as entries;
import module_input_entry as inputs;
import static_image as images;
import static_call_ir as calls;
import ir as ir;
import verifier as verifier;

fn modules::Index index(ref u8[] a,ref u8[] b){
    var sources::Builder build=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{assert(false);return index(a,b);}};
    assert(sources::add(ref mut build,b"first",a).is_ok);
    if(b.len!=0){assert(sources::add(ref mut build,b"second",b).is_ok);}
    let sources::Snapshot snap=switch(sources::freeze(ref build)){case .ok(v):{v}case .err(_):{assert(false);return index(a,b);}};
    return switch(modules::build(snap)){case .ok(v):{v}case .err(_):{assert(false);index(a,b)}};
}
fn images::Builder builder(){return switch(images::builder(4096)){case .ok(v):{v}case .err(_):{assert(false);builder()}};}
fn images::Image image(ref images::Builder b){return switch(images::freeze(b,65536)){case .ok(v):{v}case .err(_):{assert(false);return image(b);}};}
fn calls::Program empty(){return calls::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};}
fn entries::Entry entry(ref u8[] a,ref u8[] b){return switch(entries::select_i32(index(a,b),b"app",b"chosen")){
    case .ok(v):{v}case .err(_):{assert(false);entry(a,b)}
};}
fn calls::Program lowered(ref u8[] a,ref u8[] b,ref mut images::Builder build){
    let entries::Entry selected=entry(a,b);var calls::Program code=empty();
    switch(compiler::lower_output_modules(ref selected,build,ref mut code)){
        case .ok(v):{assert(v==code.body.count);}case .err(_):{assert(false);}
    };return code;
}
fn usize count(ref calls::Program p,u8 op){var usize i=0;var usize n=0;while(i<p.body.count){if(p.body.code[i*8]==op){n+=1;}i+=1;}return n;}
fn void accepted(ref u8[] source,usize emits){
    var images::Builder b=builder();let calls::Program p=lowered(source,b"",ref mut b);let images::Image literal=image(ref b);
    assert(count(ref p,116)==emits);assert(verifier::inspect_output_returns(ref p,ref literal,false).is_ok);
    if(emits!=0){assert(!verifier::inspect_reference_returns(ref p,ref literal).is_ok);assert(!verifier::verify(ref p.body).is_ok);}
}
fn void rejected(ref u8[] source){
    var images::Builder b=builder();var calls::Program p=empty();let entries::Entry e=entry(source,b"");
    assert(!compiler::lower_output_modules(ref e,ref mut b,ref mut p).is_ok);
}
@test fn void literals_named_views_and_void_helpers_keep_ordinary_control_flow(){
    accepted(b"module app;fn void show(ref u8[] bytes){output::emit(ref bytes);}pub fn i32 chosen(){let ref u8[] bytes=b\"abc\";show(ref bytes);if(true){output::emit(ref b\"\");}return 3;}",2);
    accepted(b"module app;fn ref u8[] tail(ref u8[] bytes){return bytes[1..];}pub fn i32 chosen(){output::emit(ref tail(ref b\"abc\"));return 0;}",1);
    accepted(b"module app;pub fn i32 chosen(){output::emit(ref text::bytes(\"abc\"));return 0;}",1);
}
@test fn void arrays_shared_and_exclusive_loans_and_owned_temporaries_are_proved(){
    accepted(b"module app;pub fn i32 chosen(){let u8[3] bytes=[65;3];output::emit(ref bytes);let ref u8[] part=ref bytes[1..];output::emit(ref part);return 0;}",2);
    accepted(b"module app;pub fn i32 chosen(){var u8[3] bytes=[65;3];let ref mut u8[] part=ref mut bytes;output::emit(ref part);output::emit(ref part[1..]);part[0]=66;return 0;}",2);
    accepted(b"module app;fn u8[2] make(){return [65;2];}pub fn i32 chosen(){output::emit(ref make());output::emit(ref [66,67]);return 0;}",2);
    accepted(b"module app;fn ref u8[] same(ref u8[] x){return x;}pub fn i32 chosen(){output::emit(ref same(ref [65;2]));return 0;}",1);
    accepted(b"module app;pub fn i32 chosen(){let u8[2] text=[65;2];output :: emit(ref text);return 0;}",1);
}
@test fn void endpoint_and_receiver_calls_are_lowered_once_and_captures_close(){
    var images::Builder b=builder();let calls::Program p=lowered(b"module app;fn usize lo(){return 0;}fn usize hi(){return 2;}fn ref u8[] data(){return b\"abc\";}pub fn i32 chosen(){output::emit(ref data()[lo()..hi()]);return 0;}",b"",ref mut b);
    let images::Image literal=image(ref b);assert(verifier::inspect_output_returns(ref p,ref literal,false).is_ok);
    assert(count(ref p,9)+count(ref p,78)==3);assert(count(ref p,116)==1);assert(count(ref p,70)==2);
}
@test fn void explicit_ref_byte_type_void_use_and_ordinary_lowering_gates(){
    rejected(b"module app;pub fn i32 chosen(){output::emit(b\"abc\");return 0;}");
    rejected(b"module app;pub fn i32 chosen(){let i32 output=1;output::emit(ref b\"a\");return 0;}");
    rejected(b"module app;fn i32[2] wrong(){return [1;2];}pub fn i32 chosen(){output::emit(ref wrong());return 0;}");
    rejected(b"module app;pub fn i32 chosen(){output::emit(ref \"abc\");return 0;}");
    rejected(b"module app;pub fn i32 chosen(){let i32[2] a=[1;2];output::emit(ref a);return 0;}");
    rejected(b"module app;pub fn i32 chosen(){let i32 x=output::emit(ref b\"a\");return x;}");
    rejected(b"module app;pub fn i32 chosen(){output::emit(ref b\"a\",ref b\"b\");return 0;}");
    var images::Builder b=builder();var calls::Program p=empty();let entries::Entry e=entry(b"module app;pub fn i32 chosen(){output::emit(ref b\"a\");return 0;}",b"");
    assert(!compiler::lower_modules(ref e,ref mut b,ref mut p).is_ok);
}
@test fn void imported_output_name_and_other_aliases_resolve_user_functions(){
    var images::Builder b=builder();let calls::Program p=lowered(b"module lib;pub fn void emit(ref u8[] data){}",b"module app;import lib as output;pub fn i32 chosen(){output::emit(ref b\"a\");return 0;}",ref mut b);
    let images::Image literal=image(ref b);assert(count(ref p,116)==0);assert(count(ref p,78)==1);
    assert(verifier::inspect_reference_returns(ref p,ref literal).is_ok);
    var images::Builder c=builder();let calls::Program q=lowered(b"module lib;pub fn void emit(ref u8[] data){}",b"module app;import lib as x;pub fn i32 chosen(){x::emit(ref b\"a\");return 0;}",ref mut c);
    assert(count(ref q,116)==0 && count(ref q,78)==1);
    var images::Builder d=builder();var calls::Program r=empty();let entries::Entry e=entry(b"module lib;pub fn void other(){}",b"module app;import lib as output;pub fn i32 chosen(){output::emit(ref b\"a\");return 0;}");
    assert(!compiler::lower_output_modules(ref e,ref mut d,ref mut r).is_ok);
}
@test fn void input_abi_is_explicit_and_ordinary_input_admission_stays_closed(){
    let inputs::InputEntry e=switch(inputs::select_i32_input(index(b"module app;pub fn i32 chosen(ref u8[] input){output::emit(ref input[1..]);return 0;}",b""),b"app",b"chosen")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var images::Builder b=builder();var calls::Program p=empty();assert(compiler::lower_input_output_modules(ref e,ref mut b,ref mut p).is_ok);
    let images::Image literal=image(ref b);assert(verifier::inspect_output_returns(ref p,ref literal,true).is_ok);
    assert(!verifier::inspect_output_returns(ref p,ref literal,false).is_ok);
    assert(!verifier::inspect_input_returns(ref p,ref literal).is_ok);
    var images::Builder c=builder();var calls::Program q=empty();assert(!compiler::lower_input_modules(ref e,ref mut c,ref mut q).is_ok);
}
