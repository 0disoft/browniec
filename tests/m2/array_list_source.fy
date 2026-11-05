module tests::m2::array_list_source;
import compiler as compiler;
import program_image as programs;
import ir as ir;
import verifier as verifier;
import vm as vm;
import lexer as lexer;
import array_local_source as source_lists;
import std::bytes as bytes;

fn void value(ref u8[] source,i64 expected){
    // Consume the owning result in its arm, without another full Program local.
    switch(compiler::compile_program(source,65536)){
        case .ok(p):{var usize i=0;while(i<2){switch(programs::run_public(ref p,16000000)){
            case .ok(n):{assert(n==expected);}case .err(_):{assert(false);}
        };i+=1;}}
        case .err(_):{assert(false);}
    };
}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
};}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){
    case .ok(p):{p}case .err(_):{assert(false);ir::empty()}
};}
@test fn void annotated_and_inferred_lists_preserve_all_six_exact_scalar_domains(){
    value(b"module main;fn i32 main(){let a=[20,22];let i32[1] b=[42];let c=[42,];return a[0]+a[1]+b[0]+c[0]-84;}",42);
    value(b"module main;fn i32 main(){let a=[true,false];let bool[2] b=[false,true];if(a[0] && !a[1] && !b[0] && b[1]){return 42;}return 0;}",42);
    value(b"module main;fn i64 big(){return -9223372036854775808;}fn i32 main(){let a=[big(),9223372036854775807];let i64[1] b=[-9223372036854775808];if(a[0]==b[0] && a[1]==9223372036854775807){return 42;}return 0;}",42);
    value(b"module main;fn u8 byte(){return 255;}fn u32 word(){return 4294967295;}fn usize size(){return 18446744073709551615;}fn i32 main(){let a=[byte(),42];let b=[word(),0];let c=[size(),0];let u8[2] d=[255,42];if(a[0]==d[0] && b[0]==4294967295 && c[0]==18446744073709551615){return a[1] as i32;}return 0;}",42);
}
@test fn void list_elements_run_once_left_to_right_and_keep_scalar_snapshots(){
    value(b"module main;fn i32 bump(ref mut i32[] c){c[0]=c[0]+1;return c[0];}fn i32 main(){var c=[0];let a=[bump(ref mut c),bump(ref mut c)];return a[0]*10+a[1]+c[0]*15;}",42);
    value(b"module main;fn i32 bump(ref mut i32[] c){c[0]=c[0]+1;return 22;}fn i32 main(){var c=[20];let i32[2] a=[c[0],bump(ref mut c)];return a[0]+a[1];}",42);
    value(b"module main;fn i32[1] make(i32 n){return [n;1];}fn i32 main(){var n=20;let a=[n,make(22)[0]];n=0;var b=a;b[0]=0;return a[0]+a[1]+b[0];}",42);
}
@test fn void named_lists_copy_borrow_and_return_through_both_public_routes(){
    value(b"module main;fn i32[2] make(){let a=[20,22];return a;}fn i32 take(i32[2] a){var b=a;b[0]=0;return a[0]+a[1];}fn i32 main(){let a=make();return take(a);}",42);
    value(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32[2] make(){let a=[20,22];return a;}fn i32 main(){let marker=same(ref b\"*\");let a=make();let p=ref a;return p[0]+p[1];}",42);
}
fn void classification(ref u8[] text,bool repeated){
    var lexer::State s=lexer::empty();assert(lexer::next(text,ref mut s).is_ok);
    let lexer::State before=lexer::snapshot(ref s);
    switch(source_lists::is_repeated(text,ref s)){case .ok(v):{assert(v==repeated);}case .err(_):{assert(false);}};
    assert(s.cursor==before.cursor && s.begin==before.begin && s.end==before.end && s.tokens==before.tokens && s.kind==before.kind);
}
@test fn void lookahead_ignores_nested_separators_literals_and_comments_without_evaluation(){
    classification(b"[f(20,22);2]",true);classification(b"[f(20,22),1]",false);
    classification(b"[switch(o){case .some(v):{let a=[1,2];a[0]}case .none:{0}};2]",true);
    classification(b"[b\";],\"[0] as i32,22]",false);classification(b"[1/* [,; ] /* ; */ */;2]",true);
    value(b"module main;fn i32 add(i32 x,i32 y){return x+y;}fn i32 main(){let a=[add(20,22)/* ;, */;1];let b=[a[0],b\";],\"[0] as i32];return b[0];}",42);
    value(b"module main;fn i32 main(){let Option<i32> o=.some(20);let a=[switch(o){case .some(v):{let b=[v,22];b[0]+b[1]}case .none:{0}},0];return a[0]+a[1];}",42);
}
@test fn void return_and_propagation_in_later_elements_do_not_publish_partial_owners(){
    value(b"module main;fn i32 main(){let prior=[7,8];let Option<i32> o=.none;let a=[20,switch(o){case .some(v):{v}case .none:{return 42;}}];return a[0];}",42);
    value(b"module main;fn Option<i32> f(Option<i32> o){let prior=[7,8];let a=[20,o?];return .some(a[0]+a[1]);}fn i32 main(){switch(f(.none)){case .some(_):{return 0;}case .none:{}}switch(f(.some(22))){case .some(v):{return v;}case .none:{return 0;}}}",42);
    value(b"module main;fn ref u8[] same(ref u8[] p){return ref p;}fn i32 main(){let prior=[7];let Option<i32> o=.none;let a=[20,same(ref [42;2])[switch(o){case .some(v):{0}case .none:{return 42;}}] as i32];return a[0];}",42);
}
@test fn void break_continue_and_loop_reentry_release_only_completed_owners(){
    value(b"module main;fn i32 main(){let Option<i32> o=.none;var n=0;while(n<42){let prior=[1,2];let a=[prior[0],switch(o){case .some(v):{v}case .none:{n=n+1;continue;}}];}return n;}",42);
    value(b"module main;fn i32 main(){let Option<i32> o=.none;while(true){let prior=[1];let a=[20,switch(o){case .some(v):{v}case .none:{break;}}];}let b=[20,22];return b[0]+b[1];}",42);
    value(b"module main;fn i32 main(){var n=0;var sum=0;while(n<42){let a=[1,2];sum=sum+a[0];n=n+1;continue;}return sum;}",42);
}
@test fn void invalid_arity_types_names_syntax_and_mutation_fail_honestly(){
    rejected(b"module main;fn i32 main(){let i32[2] a=[42];return 0;}",3);
    rejected(b"module main;fn i32 main(){let i32[1] a=[20,22];return 0;}",3);
    rejected(b"module main;fn i32 main(){let a=[1,true];return 0;}",3);
    rejected(b"module main;fn u8 byte(){return 42;}fn i32 main(){let a=[1,byte()];return 0;}",3);
    rejected(b"module main;fn i32 main(){let a=[.some(42),.some(0)];return 0;}",3);
    rejected(b"module main;fn i32 main(){let a=[a[0],22];return 0;}",3);
    rejected(b"module main;fn i32 main(){let a=[];return 0;}",3);
    rejected(b"module main;fn i32 main(){let a=[1,,2];return 0;}",2);
    rejected(b"module main;fn i32 main(){let a=[1,2;2];return 0;}",2);
    rejected(b"module main;fn i32 main(){let a=[1,2];a[0]=42;return 0;}",3);
    rejected(b"module main;fn i32 main(){let a=[1,2];let a=[3,4];return 0;}",3);
    rejected(b"module main;fn i32 main(){for(var a=[1,2];false;){}return 0;}",3);
}
@test fn void source_list_ir_has_one_complete_pool_span_and_exact_independent_fuel(){
    let ir::Program a=compiled(b"module main;fn i32 main(){let i32[2] a=[20,22];return a[0]+a[1];}");
    let ir::Program b=compiled(b"module main;fn i32 main(){let a=[20,22];return a[0]+a[1];}");
    assert(verifier::verify(ref a).is_ok && verifier::verify(ref b).is_ok);
    assert(a.count==b.count && a.registers==b.registers && a.list_used==2 && b.list_used==2);
    var usize i=0;while(i<a.count*8){assert(a.code[i]==b.code[i]);i+=1;}
    i=0;while(i<4096){assert(a.list_operands[i]==b.list_operands[i]);i+=1;}
    // Backing 8: 9; list scratch: 269; two CONST: 2; list: 82;
    // two CONST indices + two READ: 76; ADD + DROP + RETURN: 51.
    let usize exact=489;
    switch(vm::run_with_array_limit(ref b,exact,8)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
    switch(vm::run_with_array_limit(ref b,exact-1,8)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(vm::run_with_array_limit(ref b,exact+1,8)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
}
fn void append(ref mut bytes::Buffer b,ref u8[] s){assert(bytes::append(b,s).is_ok);}
fn void many_cells(usize count,bool pass){
    var bytes::Buffer b=bytes::empty();append(ref mut b,b"module main;fn i32 main(){let x=42;let a=[");var usize i=0;
    while(i<count){if(i!=0){append(ref mut b,b",");}append(ref mut b,b"x");i+=1;}
    append(ref mut b,b"];return a[0];}");if(pass){value(bytes::view(ref b),42);}else{rejected(bytes::view(ref b),4);}
}
fn void nested_call(usize count,bool retained,bool pass){
    var bytes::Buffer b=bytes::empty();append(ref mut b,b"module main;fn i32 id(i32 x,i32[1] a){return x;}fn i32 main(){let i32[1] a=[0;1];");
    if(retained){append(ref mut b,b"let ref u8[] marker=b\"*\";");}append(ref mut b,b"let b=[");
    var usize i=0;while(i<count){append(ref mut b,b"id(");i+=1;}append(ref mut b,b"42");
    i=0;while(i<count){append(ref mut b,b",a)");i+=1;}append(ref mut b,b"];return b[0];}");
    if(pass){value(bytes::view(ref b),42);}else{rejected(bytes::view(ref b),4);}
}
fn void literal_cells(usize count,bool pass){
    var bytes::Buffer b=bytes::empty();append(ref mut b,b"module main;fn i32 main(){let a=[");var usize i=0;
    while(i<count){if(i!=0){append(ref mut b,b",");}append(ref mut b,b"42");i+=1;}
    append(ref mut b,b"];return a[0];}");if(pass){value(bytes::view(ref b),42);}else{rejected(bytes::view(ref b),4);}
}
@test fn void lists_keep_existing_source_register_and_32_deep_call_limits(){
    many_cells(256,true);many_cells(2048,false);
    literal_cells(126,true);literal_cells(127,false);
    nested_call(32,false,true);nested_call(33,false,false);
    nested_call(32,true,true);nested_call(33,true,false);
}
