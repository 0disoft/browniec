module tests::m2::slice_result_origins;
import compiler as compiler;
import slice_result_origins as origins;

fn origins::Summary analyzed(ref u8[] source){return switch(compiler::inspect_slice_results(source)){case .ok(v):{v}case .err(_):{assert(false);origins::Summary{.parameters=[0;16],.rounds=0}}};}
fn void closed(ref u8[] source){assert(!compiler::compile(source).is_ok);}
fn void proved(ref u8[] source,usize f,u8 parameter){let origins::Summary result=analyzed(source);assert(result.parameters[f]==parameter && result.rounds>0 && result.rounds<=17);closed(source);}
fn void rejected(ref u8[] source){assert(!compiler::inspect_slice_results(source).is_ok);closed(source);}
@test
fn void six_scalar_modes_return_exact_input_origins(){
    proved(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref bool[] f(ref bool[] p){return ref p;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref mut bool[] f(ref mut bool[] p){return ref mut p;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref i64[] f(ref i64[] p){return ref p;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref mut i64[] f(ref mut i64[] p){return ref mut p;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref u8[] f(ref u8[] p){return ref p;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref mut u8[] f(ref mut u8[] p){return ref mut p;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref u32[] f(ref u32[] p){return ref p;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref mut u32[] f(ref mut u32[] p){return ref mut p;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref usize[] f(ref usize[] p){return ref p;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref mut usize[] f(ref mut usize[] p){return ref mut p;}fn i32 main(){return 42;}",0,1);
}

@test
fn void lexical_shared_and_exclusive_subviews_preserve_origins(){
    proved(b"module main;fn ref i32[] f(ref i32[] p){let ref i32[] q=ref p[1..p.len];let ref i32[] r=ref q[..];return ref r;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref mut i32[] f(ref mut i32[] p){let ref mut i32[] q=ref mut p[1..];let ref mut i32[] r=ref mut q;return ref mut r;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref i32[] f(i32 n,ref i32[] p){return ref p;}fn i32 main(){return 42;}",0,2);
}

@test
fn void branches_switches_and_loops_agree_on_one_input(){
    proved(b"module main;fn ref i32[] f(ref i32[] p,bool b){if(b){return ref p;}else{let ref i32[] q=ref p;return ref q;}}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref i32[] f(ref i32[] p,Option<i32> o){switch(o){case .some(_):{return ref p;}case .none:{return ref p;}}}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref mut i32[] f(ref mut i32[] p,bool b){while(b){let ref mut i32[] q=ref mut p;return ref mut q;}return ref mut p;}fn i32 main(){return 42;}",0,1);
    rejected(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q,bool b){if(b){return ref p;}return ref q;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q){if(true){return ref p;}return ref q;}fn i32 main(){return 42;}");
}

@test
fn void forward_calls_remap_only_the_selected_actual_argument(){
    proved(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q){return g(ref q,ref p);}fn ref i32[] g(ref i32[] a,ref i32[] b){return ref b;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref mut i32[] f(ref mut i32[] p,ref mut i32[] q){return g(ref mut q,ref mut p);}fn ref mut i32[] g(ref mut i32[] a,ref mut i32[] b){return ref mut b;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref i32[] f(ref i32[] p){return g(ref p[..]);}fn ref i32[] g(ref i32[] p){return h(ref p);}fn ref i32[] h(ref i32[] p){return ref p;}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref i32[] f(ref i32[] p){return g(ref [42;1],ref p);}fn ref i32[] g(ref i32[] a,ref i32[] b){return ref b;}fn i32 main(){return 42;}",0,1);
}

@test
fn void grounded_recursive_summaries_converge_and_permutations_cannot_change_origin(){
    proved(b"module main;fn ref i32[] f(ref i32[] p,i32 n){if(n==0){return ref p;}return f(ref p,n-1);}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref mut i32[] f(ref mut i32[] p,i32 n){if(n==0){return ref mut p;}return f(ref mut p,n-1);}fn i32 main(){return 42;}",0,1);
    proved(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q,bool b){if(b){return ref p;}return g(ref q,ref p,b);}fn ref i32[] g(ref i32[] p,ref i32[] q,bool b){if(b){return ref q;}return f(ref q,ref p,b);}fn i32 main(){return 42;}",0,1);
    rejected(b"module main;fn ref i32[] f(ref i32[] p){return f(ref p);}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p){return g(ref p);}fn ref i32[] g(ref i32[] p){return f(ref p);}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q,bool b){if(b){return ref p;}return f(ref q,ref p,b);}fn i32 main(){return 42;}");
}

@test
fn void owned_roots_temporaries_and_wrong_modes_never_become_input_origins(){
    rejected(b"module main;fn ref i32[] f(ref i32[] p){let i32[1] a=[42;1];let ref i32[] q=ref a;return ref q;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p,i32[1] a){let ref i32[] q=ref a;return ref q;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p){return g(ref [42;1]);}fn ref i32[] g(ref i32[] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p){return ref [42;1];}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p,ref mut i32[] q){return ref mut q;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p,ref u32[] q){return ref q;}fn i32 main(){return 42;}");
}

@test
fn void existing_flow_proof_rejects_suspended_parents_and_scalar_proxy_use(){
    rejected(b"module main;fn ref mut i32[] f(ref mut i32[] p){let ref mut i32[] q=ref mut p;return ref mut p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p){let usize n=g(ref p);return ref p;}fn ref i32[] g(ref i32[] p){return ref p;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p){return p.len;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p){return g(ref p);}fn usize g(ref i32[] p){return p.len;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p){return ref p[..];}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref i32[] f(ref i32[] p){if(true){return ref p;}}fn i32 main(){return 42;}");
}

@test
fn void ordinary_programs_keep_zero_summaries_and_unreachable_borrow_bodies_are_checked(){
    let origins::Summary r=analyzed(b"module main;fn i32 main(){return 42;}");var usize i=0;while(i<16){assert(r.parameters[i]==0);i+=1;}
    proved(b"module main;fn i32 main(){return 42;}fn ref i32[] unused(ref i32[] p){return ref p;}",1,1);
    rejected(b"module main;fn i32 main(){return 42;}fn ref i32[] unused(ref i32[] p,ref i32[] q,bool b){if(b){return ref p;}return ref q;}");
}
