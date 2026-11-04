module tests::m2::slice_result_source_origins;
import functions as functions;
import slice_result_source_origins as origins;
import errors as errors;

fn Result<usize,errors::Error> inferred(ref u8[] source,usize function,u8 expected){
    var functions::Table t=functions::scan(source)?;let usize rounds=origins::infer(source,ref mut t)?;
    assert(rounds<=17 && t.return_slice_inputs[function]==expected);return .ok(rounds);
}
fn bool rejected(ref u8[] source){
    var functions::Table t=switch(functions::scan(source)){case .ok(v):{v}case .err(_):{return true;}};
    return !origins::infer(source,ref mut t).is_ok;
}
@test fn void typed_aliases_and_reordered_multi_input_calls_ground_exact_origins(){
    assert(inferred(b"module main;fn ref i32[] g(ref i32[] p,ref i32[] q){return ref q;}fn ref i32[] f(ref i32[] a,ref i32[] b){let ref i32[] r=g(ref b,ref a);return ref r;}fn i32 main(){return 0;}",1,1).is_ok);
    assert(inferred(b"module main;fn ref mut usize[] g(ref mut usize[] p,ref mut usize[] q){return ref mut q;}fn ref mut usize[] f(ref mut usize[] a,ref mut usize[] b){let ref mut usize[] r=g(ref mut a,ref mut b);return ref mut r;}fn i32 main(){return 0;}",1,2).is_ok);
    assert(inferred(b"module main;fn ref u8[] f(ref u8[] p){{let ref u8[] r=ref p;}let ref u8[] r=ref p[0..];return ref r;}fn i32 main(){return 0;}",0,1).is_ok);
}
@test fn void grounded_recursion_and_nested_value_argument_returns_are_revisited(){
    assert(inferred(b"module main;fn ref i32[] f(ref i32[] p,i32 n){if(n==0){return ref p;}let ref i32[] q=f(ref p,n-1);return ref q;}fn i32 main(){return 0;}",0,1).is_ok);
    assert(inferred(b"module main;fn ref i32[] g(i32 n,ref i32[] p){return ref p;}fn ref i32[] f(ref i32[] p,bool b){let ref i32[] q=g(switch(b){case true:{return ref p;}case false:{0}},ref p);return ref q;}fn i32 main(){return 0;}",1,1).is_ok);
}
@test fn void ungrounded_cycles_owned_roots_type_changes_and_ambiguous_returns_reject(){
    assert(rejected(b"module main;fn ref i32[] f(ref i32[] p){let ref i32[] q=f(ref p);return ref q;}fn i32 main(){return 0;}"));
    assert(rejected(b"module main;fn ref i32[] f(ref i32[] p){return g(ref p);}fn ref i32[] g(ref i32[] p){return f(ref p);}fn i32 main(){return 0;}"));
    assert(rejected(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q,bool b){if(b){return ref p;}return ref q;}fn i32 main(){return 0;}"));
    assert(rejected(b"module main;fn ref i32[] f(ref i32[] p){let i32[1] a=[42;1];let ref i32[] q=ref a;return ref q;}fn i32 main(){return 0;}"));
    assert(rejected(b"module main;fn ref i32[] f(ref u8[] p){return ref p;}fn i32 main(){return 0;}"));
    let ref u8[] cycle=b"module main;fn ref i32[] f(ref i32[] p){let ref i32[] q=f(ref p);return ref q;}fn i32 main(){return 0;}";
    var functions::Table stale=switch(functions::scan(cycle)){case .ok(v):{v}case .err(_):{assert(false);functions::empty()}};
    stale.return_slice_inputs[0]=1;assert(!origins::infer(cycle,ref mut stale).is_ok);
}

@test fn void nested_selected_actuals_ground_origins_without_trusting_owned_roots(){
    assert(inferred(b"module main;fn ref i32[] select(ref i32[] a,ref i32[] b){return ref b;}fn ref i32[] forward(ref i32[] a,ref i32[] b){return select(ref a,ref select(ref b,ref a));}fn i32 main(){return 0;}",1,1).is_ok);
    assert(inferred(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn ref mut i32[] rec(ref mut i32[] p,i32 n){if(n==0){return ref mut p;}return rec(ref mut id(ref mut p),n-1);}fn i32 main(){return 0;}",1,1).is_ok);
    assert(rejected(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn ref i32[] bad(ref i32[] p){return id(ref id(ref [42;1]));}fn i32 main(){return 0;}"));
}
