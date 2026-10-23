module tests::bools;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch (compiler::compile(source)) { case .ok(p): { p } case .err(_): { assert(false); ir::empty() } };
}
@test
fn void typed_boolean_pipeline() {
    let ir::Program p = compiled(b"module main; fn bool f(i32 x,bool b) { var bool v=x+1<=42; v=!(v==b); return v!=false; } fn i32 sink(bool b) { return 42; } fn i32 main() { let bool v=f(41,true); return sink(v); }");
    assert(verifier::verify(ref p).is_ok);
    assert(switch (vm::run(ref p,256)) { case .ok(n): { n==42 } case .err(_): { false } });
    assert(compiler::compile(b"module main; fn bool f(i32 x) { return x<0==false; } fn i32 main() { let bool a=1>0; let bool b=1>=1; return 0; }").is_ok);
}
@test
fn void boolean_type_rejections() {
    assert(!compiler::compile(b"module main; fn bool main() { return true; }").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() { let bool b=1; return 0; }").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() { var bool b=true; b=1; return 0; }").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() { let bool b=true+1; return 0; }").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() { let bool b=true==1; return 0; }").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() { let bool b=true<false; return 0; }").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() { let bool b=!1; return 0; }").is_ok);
    assert(!compiler::compile(b"module main; fn bool f(bool b) { return b; } fn i32 main() { let bool b=f(1); return 0; }").is_ok);
    assert(!compiler::compile(b"module main; fn bool f() { return 1; } fn i32 main() { return 0; }").is_ok);
}
@test
fn void boolean_metadata_rejections() {
    let ir::Program good=compiled(b"module main; fn i32 main() { let bool b=true; return 42; }");
    var ir::Program bad=good;
    bad.constants[0]=2; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.types[0]=0; assert(!verifier::verify(ref bad).is_ok);
    bad=good; bad.return_types[0]=2; assert(!verifier::verify(ref bad).is_ok);
    let ir::Program compare=compiled(b"module main; fn i32 main() { let bool b=1<2; return 42; }");
    bad=compare; bad.types[2]=1; assert(!verifier::verify(ref bad).is_ok);
    let ir::Program call=compiled(b"module main; fn i32 main() { return f(true); } fn i32 f(bool b) { return 42; }");
    bad=call; bad.types[0]=1; assert(!verifier::verify(ref bad).is_ok);
}
