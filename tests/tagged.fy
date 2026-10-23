module tests::tagged;
import compiler as compiler;
import ir as ir;
import tagged as tagged;
import verifier as verifier;
import vm as vm;

@test
fn void packed_scalar_edges() {
    let i64[5] values=[-2147483648,-1,0,1,2147483647];
    var usize i=0;
    while(i<5) {
        var u8 tag=0;
        while(tag<2) {
            let i64 encoded=tagged::pack(values[i],tag);
            assert(tagged::variant(encoded)==tag);
            assert(tagged::unpack(encoded,tag)==values[i]);
            tag+=1;
        }
        i+=1;
    }
    assert(tagged::pack(-2147483648,1)==-4294967295);
    assert(tagged::pack(2147483647,1)==4294967295);
}
fn ir::Program compiled(ref u8[] source) {
    return switch(compiler::compile(source)) {case .ok(p): {p} case .err(_): {assert(false);ir::empty()}};
}
@test
fn void wrapper_types_copies_and_calls() {
    let ir::Program p=compiled(b"module main; fn Option<i32> f(Option<i32> x) {return x;} fn i32 sink(Option<i32> x,Result<bool,i32> y) {return 42;} fn i32 main() {var Option<i32> x=.some(-2147483648); let Option<i32> old=x; x=.none; return sink(f(old),.err(2147483647));}");
    assert(switch(vm::run(ref p,256)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.some(true); return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<bool> x=.ok(true); return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Result<i32,bool> x=.none; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<Option<i32>> x=.none; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; let bool b=x==x; return 0;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {for(var Option<i32> x=.none;false;) {} return 0;}").is_ok);
}
@test
fn void wrapper_metadata_rejections() {
    let ir::Program p=compiled(b"module main; fn i32 main() {let Option<i32> x=.some(42); return 0;}");
    var ir::Program bad=p;
    bad.code[11]=2; assert(!verifier::verify(ref bad).is_ok);
    bad=p; bad.types[1]=4; assert(!verifier::verify(ref bad).is_ok);
    bad=p; bad.types[0]=3; assert(!verifier::verify(ref bad).is_ok);
    bad=p; bad.code[10]=127; assert(!vm::run(ref bad,256).is_ok);
    let ir::Program none=compiled(b"module main; fn i32 main() {let Option<bool> x=.none; return 0;}");
    bad=none; bad.code[2]=1; assert(!verifier::verify(ref bad).is_ok);
}
