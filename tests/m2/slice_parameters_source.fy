module tests::m2::slice_parameters_source;
import compiler as compiler;
import functions as functions;
import ir as ir;
import slice_parameters as parameters;
import verifier as verifier;
import vm as vm;

fn ir::Program compiled(ref u8[] source) {
    let ir::Program p=switch(compiler::compile(source)) { case .ok(v): { v } case .err(_): { assert(false); ir::empty() } };
    assert(verifier::inspect(ref p).is_ok); return p;
}
fn void accepted(ref u8[] source) {
    let ir::Program p=compiled(source);
    assert(switch(parameters::metadata(ref p)) { case .ok(mask): { mask!=0 } case .err(_): { false } });
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,0,0)) { case .ok(_): { false } case .err(e): { e.kind==8 } });
}
fn void rejected(ref u8[] source) { assert(!compiler::compile(source).is_ok); }

@test
fn void signature_kinds_forward_names_and_non_scalar_formal_positions_are_distinct() {
    let ref u8[] source=b"module main;struct P{i32 x;}fn i32 main(){return 42;}fn i32 f(i32 n,ref u8[] bytes,u8[2] a,P p){return bytes[0] as i32+n+p.x+a[0] as i32;}";
    let functions::Table t=switch(functions::scan(source)) { case .ok(v): { v } case .err(_): { assert(false); functions::empty() } };
    assert(t.entry==0 && t.arities[1]==4 && t.param_slices[9] && !t.param_slices[8]);
    assert(t.param_types[9]==0 && t.param_lengths[9]==0 && t.param_records[9]==0);
    let ir::Program p=compiled(source); let usize r=p.register_starts[1]+1;
    assert(p.slice_parameters[r]!=0 && p.types[r]==0 && !p.slots[r] && p.array_parameters[r]==0 && p.record_parameters[r]==0);
    accepted(source);
}

@test
fn void read_length_utf8_aliases_and_nested_subranges_lower_without_owned_root_invention() {
    accepted(b"module main;fn i32 read(ref u8[] p){if(text::valid_utf8(p) && p.len==1){return p[0] as i32;}return 0;}fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return read(ref p);}");
    accepted(b"module main;fn i32 read(ref u8[] p){let ref u8[] q=ref p;let ref u8[] r=ref q[0..q.len];return r[0] as i32;}fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return read(ref p);}");
    let ir::Program p=compiled(b"module main;fn i32 read(ref u8[] p){let ref u8[] q=ref p[..];return q[0] as i32;}fn i32 main(){return 42;}");
    assert(p.arrays.count==0 && p.slice_roots[0]==0 && p.slice_roots[1]==0 && p.slice_origins[0]==1 && p.slice_origins[1]==1);
    var usize pc=p.ends[0]; var usize closes=0;
    while(pc>p.starts[0]) { pc-=1; if(p.code[pc*8]==56) { assert(p.code[pc*8+1] as usize==closes); closes+=1; } }
    assert(closes==2);
}

@test
fn void forward_recursive_duplicate_and_mixed_arguments_keep_the_existing_call_encoding() {
    accepted(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return later(ref p);}fn i32 later(ref u8[] p){return p[0] as i32;}");
    accepted(b"module main;fn i32 f(ref u8[] p,i32 n){if(n==0){return p[0] as i32;}let ref u8[] q=ref p;return f(ref q,n-1);}fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p,2);}");
    accepted(b"module main;struct P{i32 x;}fn i32 f(i32 n,ref u8[] p,u8[1] a,P r,ref u8[] q){return n+p[0] as i32+a[0] as i32+r.x+q[0] as i32;}fn i32 main(){let u8[1] a=[1;1];let ref u8[] p=ref a;let P r=P{.x=38};return f(1,ref p,a,r,ref p);}");
    let ir::Program p=compiled(b"module main;fn i32 f(ref u8[] p,ref u8[] q){return 42;}fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p,ref p);}");
    assert(p.call_count==1 && p.call_arities[0]==2 && p.call_args[0]==162 && p.call_args[1]==162);
}

@test
fn void function_exit_paths_close_formals_and_derived_bindings_without_closing_caller_arguments() {
    accepted(b"module main;fn Option<i32> f(ref u8[] p,Option<i32> o){let ref u8[] q=ref p;let i32 n=o?;return .some(n+q[0] as i32);}fn i32 main(){return 42;}");
    accepted(b"module main;fn i32 f(ref u8[] p){var i32 n=0;while(n<2){let ref u8[] q=ref p;n=n+1;continue;}while(true){let ref u8[] r=ref p;break;}return p[0] as i32;}fn i32 main(){return 42;}");
    accepted(b"module main;fn u8[1] f(ref u8[] p){return [p[0];1];}fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let u8[1] b=f(ref p);return b[0] as i32;}");
    let ir::Program p=compiled(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;let i32 n=f(ref p);return n+p[0] as i32;}");
    var usize pc=p.starts[1]; var bool called=false; var bool read_after=false;
    while(pc<p.ends[1]) { let u8 op=p.code[pc*8]; if(op==9) { called=true; } if(op==58 && called) { read_after=true; } if(op==56) { assert(read_after); } pc+=1; }
    assert(called && read_after);
}

@test
fn void unsupported_signatures_arguments_escapes_and_borrowed_root_mutation_are_rejected() {
    rejected(b"module main;fn i32 f(ref mut mut u8[] p){return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref Option<i32>[] p){return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref u8[1] p){return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] f(ref u8[] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 main(ref u8[] p){return 42;}");
    rejected(b"module main;fn i32 f(ref u8[] p,i32 p){return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return f(p);}");
    accepted(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){let u8[1] a=[42;1];return f(ref a);}");
    rejected(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){return f(ref [true;1]);}");
    accepted(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p[..]);}");
    rejected(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){{let u8[1] a=[42;1];let ref u8[] p=ref a;}return f(ref p);}");
    rejected(b"module main;fn i32 f(ref u8[] p){p[0]=1;return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref u8[] p){let u8[1] a=p;return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref u8[] p){return p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){return f();}");
    rejected(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p,ref p);}");
    rejected(b"module main;fn i32 f(ref u8[] p,i32 n){return n;}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;let Option<i32> o=.none;return f(ref p,switch(o){case .some(v):{v}case .none:{a[0]=0;42}});}");
}
