module tests::m2::slice_element_source;
import compiler as compiler;
import functions as functions;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    return switch(compiler::compile(source)) {case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};
}
fn void accepted(ref u8[] source) {
    let ir::Program p=compiled(source); assert(verifier::inspect(ref p).is_ok);
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,0,0)) {case .ok(_):{false}case .err(e):{e.kind==8}});
}
fn void rejected(ref u8[] source) {
    assert(switch(compiler::compile(source)) {case .ok(_):{false}case .err(e):{e.kind==3 || e.kind==2}});
}

@test
fn void forward_signature_pass_keeps_six_borrow_tags_separate_from_scalar_and_owned_positions() {
    let ref u8[] source=b"module main;fn i32 main(){return 42;}fn i32 f(ref i32[] a,ref bool[] b,ref i64[] c,ref u8[] d,ref u32[] e,ref usize[] f,i32 n,u8[1] own){return n;}";
    let functions::Table t=switch(functions::scan(source)) {case .ok(v):{v}case .err(_):{assert(false);functions::empty()}};
    let u8[6] tags=[1,2,9,10,11,12]; let ir::Program p=compiled(source);
    var usize i=0;
    while(i<6) {
        assert(t.param_slices[8+i] && t.param_slice_elements[8+i]==tags[i] && t.param_types[8+i]==0 && t.param_lengths[8+i]==0);
        let usize r=p.register_starts[1]+i; let usize site=(p.slice_parameters[r] as usize)-1;
        assert(p.slice_elements[site]==tags[i] && p.types[r]==0 && p.array_parameters[r]==0);
        i+=1;
    }
    assert(!t.param_slices[14] && t.param_slice_elements[14]==0 && t.param_types[14]==1);
    assert(!t.param_slices[15] && t.param_slice_elements[15]==0 && t.param_lengths[15]==1);
    accepted(source);
}

@test
fn void aliases_computed_open_empty_and_nested_ranges_preserve_exact_read_types() {
    accepted(b"module main;fn i32 f(ref i32[] p){let ref i32[] q=ref p;let ref i32[] r=ref q[0..q.len];return r[0];}fn i32 main(){return 42;}");
    accepted(b"module main;fn bool f(ref bool[] p){let ref bool[] q=ref p[..];let ref bool[] r=ref q[0..];return r[0];}fn i32 main(){return 42;}");
    accepted(b"module main;fn i64 f(ref i64[] p,usize n){let ref i64[] q=ref p[n+0..p.len];return q[0];}fn i32 main(){return 42;}");
    accepted(b"module main;fn u32 f(ref u32[] p){let ref u32[] q=ref p[0..0];let usize n=q.len;return p[0];}fn i32 main(){return 42;}");
    accepted(b"module main;fn usize f(ref usize[] p){let ref usize[] q=ref p[..p.len];return q[0]+q.len;}fn i32 main(){return 42;}");
}

@test
fn void forward_recursive_and_mixed_calls_check_signature_types_before_formal_site_allocation() {
    accepted(b"module main;fn i32 f(ref i32[] p){return g(ref p);}fn i32 g(ref i32[] p){let ref i32[] q=ref p;return q[0];}fn i32 main(){return 42;}");
    accepted(b"module main;fn bool f(ref bool[] p,i32 n){if(n==0){return p[0];}let ref bool[] q=ref p[..];return f(ref q,n-1);}fn i32 main(){return 42;}");
    accepted(b"module main;struct R{i32 x;}fn i64 f(i32 n,ref i64[] p,u8[1] a,R r,ref i64[] q){return p[0]+q[0]+r.x as i64+n as i64+a[0] as i64;}fn i32 main(){return 42;}");
    accepted(b"module main;fn u32 f(ref u32[] p,ref u32[] q){return p[0]+q[0];}fn u32 g(ref u32[] p){return f(ref p,ref p);}fn i32 main(){return 42;}");
    accepted(b"module main;fn usize f(ref usize[] p){return g(ref p);}fn usize g(ref usize[] p){return p.len;}fn i32 main(){return 42;}");
}

@test
fn void mismatched_alias_call_read_utf8_and_unsupported_roots_fail_during_source_lowering() {
    rejected(b"module main;fn i32 f(ref i32[] p){let ref u32[] q=ref p;return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref i32[] p){return g(ref p);}fn i32 g(ref u32[] p){return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref i32[] p){let bool n=p[0];return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref bool[] p){return p[0];}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref i64[] p){if(text::valid_utf8(p)){return 42;}return 0;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref mut mut i32[] p){return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref Option<i32>[] p){return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref i32[] p){p[0]=1;return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 g(ref i32[] p){return f(p);}fn i32 main(){return 42;}");
    accepted(b"module main;fn i32 main(){let i32[1] a=[42;1];let ref i32[] p=ref a;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref i32[] p=ref a;return 42;}");
    accepted(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){let i32[1] a=[42;1];return f(ref a);}");
    rejected(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){return f(ref [true;1]);}");
}

@test
fn void exits_propagation_and_aggregate_results_keep_reverse_borrow_cleanup() {
    accepted(b"module main;fn Option<i32> f(ref i32[] p,Option<i32> o){let ref i32[] q=ref p;let i32 n=o?;return .some(n+q[0]);}fn i32 main(){return 42;}");
    accepted(b"module main;fn i32 f(ref i32[] p){var i32 n=0;while(n<2){let ref i32[] q=ref p;n=n+1;continue;}while(true){let ref i32[] q=ref p;break;}return p[0];}fn i32 main(){return 42;}");
    accepted(b"module main;fn i32[1] f(ref i32[] p){return [p[0];1];}fn i32 main(){return 42;}");
    accepted(b"module main;struct R{i64 x;}fn R f(ref i64[] p){return R{.x=p[0]};}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref i32[] p){{let ref i32[] q=ref p;}return q[0];}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref i32[] p){return p;}fn i32 main(){return 42;}");
}
