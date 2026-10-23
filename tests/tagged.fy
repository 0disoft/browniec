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
fn void value(ref u8[] source,i64 expected) {
    let ir::Program p=compiled(source);
    assert(switch(vm::run(ref p,10000)) {case .ok(n): {n==expected} case .err(_): {false}});
}
fn usize instruction(ref ir::Program p,u8 op,usize start) {
    var usize pc=start;
    while(pc<p.count) {if(p.code[pc*8]==op) {return pc*8;} pc+=1;}
    assert(false);return 0;
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

@test
fn void switch_scalar_payload_edges() {
    value(b"module main; fn i32 main() {let Option<i32> x=.some(-2147483648); switch(x) {case .some(v): {return v;} case .none: {return 0;}}}",-2147483648);
    value(b"module main; fn i32 main() {let Option<i32> x=.some(2147483647); switch(x) {case .none: {return 0;} case .some(v): {return v;}}}",2147483647);
    value(b"module main; fn i32 main() {let Result<i32,i32> x=.err(-1); switch(x) {case .ok(v): {return v;} case .err(e): {return e;}}}",-1);
    value(b"module main; fn i32 main() {let Option<bool> x=.some(false); switch(x) {case .some(v): {if(v) {return 1;} return 42;} case .none: {return 0;}}}",42);
    value(b"module main; fn i32 main() {let Result<bool,i32> x=.ok(true); switch(x) {case .err(e): {return e;} case .ok(v): {if(v) {return 42;} return 0;}}}",42);
    value(b"module main; fn i32 main() {let Result<i32,bool> x=.err(false); switch(x) {case .ok(v): {return v;} case .err(e): {if(e) {return 0;} return 42;}}}",42);
    value(b"module main; fn i32 main() {let Result<bool,bool> x=.err(true); switch(x) {case .ok(v): {return 0;} case .err(e): {if(e) {return 42;} return 0;}}}",42);
}
@test
fn void tagged_snapshots_calls_and_loop_transfers() {
    value(b"module main; fn Option<i32> f(Option<i32> x) {return x;} fn i32 main() {var Option<i32> x=.some(42); let Option<i32> old=x; x=.none; switch(f(old)) {case .some(v): {return v;} case .none: {return 1/0;}}}",42);
    value(b"module main; fn Result<i32,bool> f(bool yes) {if(yes) {return .ok(42);} return .err(false);} fn i32 main() {switch(f(true)) {case .ok(v): {return v;} case .err(_): {return 1/0;}}}",42);
    value(b"module main; fn i32 main() {var i32 out=0; var Option<i32> x=.none; if(true) {x=.some(42);} switch(x) {case .none: {out=1;} case .some(v): {out=v;}} return out;}",42);
    value(b"module main; fn i32 main() {var i32 sum=0; for(var i32 i=0;i<3;i=i+1) {var Result<i32,bool> x=.ok(i); if(i==2) {x=.err(true);} switch(x) {case .ok(v): {sum=sum+v; continue;} case .err(_): {break;}}} return sum;}",1);
    value(b"module main; fn i32 main() {var Option<i32> x=.some(0); var i32 sum=0; while(sum<3) {switch(x) {case .some(v): {sum=sum+v; x=.none;} case .none: {x=.some(1);}}} return sum;}",3);
}
@test
fn void switch_source_rejections() {
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; switch(x) {case .some(v): {return v;}}}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; switch(x) {case .none: {return 0;} case .none: {return 1;}}}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {switch(1) {case .none: {return 0;}}}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; switch(x) {case .some(v): {} case .none: {}} return v;}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; switch(x) {case .some(v): {v=1; return v;} case .none: {return 0;}}}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; let i32 v=1; switch(x) {case .some(v): {return v;} case .none: {return 0;}}}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; switch(x) {case .ok(v): {return v;} case .err(e): {return e;}}}").is_ok);
    assert(!compiler::compile(b"module main; fn i32 main() {let Option<i32> x=.none; switch(x) {case .some(.none): {return 1;} case .none: {return 0;}}}").is_ok);
}
@test
fn void guarded_case_initialization_fuel_and_failure() {
    let ir::Program p=compiled(b"module main; fn i32 main() {let Option<i32> x=.some(42); switch(x) {case .some(v): {return v;} case .none: {return 0;}}}");
    assert(switch(vm::run(ref p,3)) {case .ok(_): {false} case .err(e): {e.kind==8}});
    assert(switch(vm::run(ref p,4)) {case .ok(n): {n==42} case .err(_): {false}});
    assert(switch(vm::run(ref p,4)) {case .ok(n): {n==42} case .err(_): {false}});
    let usize branch=instruction(ref p,24,0);
    var ir::Program bad=p;
    bad.code[branch+4]=0; assert(!verifier::verify(ref bad).is_ok);
    bad=p; bad.code[branch+4]=255; assert(!verifier::verify(ref bad).is_ok);
    bad=p; bad.code[branch+3]=2; assert(!verifier::verify(ref bad).is_ok);
    bad=p; bad.code[branch+5]=1; assert(!verifier::verify(ref bad).is_ok);
    bad=p; bad.code[branch+2]=0; assert(!verifier::verify(ref bad).is_ok);
    // Sending mismatch straight to the payload's return must not initialize it.
    assert(branch==16);
    bad=p; bad.code[branch+4]=3; assert(!vm::run(ref bad,256).is_ok);
    let ir::Program result=compiled(b"module main; fn i32 main() {let Result<i32,i32> x=.err(42); switch(x) {case .ok(v): {return v;} case .err(e): {return e;}}}");
    let usize second=instruction(ref result,24,3);
    bad=result; bad.code[second+3]=1;
    assert(verifier::verify(ref bad).is_ok);
    assert(switch(vm::run(ref bad,256)) {case .ok(_): {false} case .err(e): {e.kind==5}});
}
