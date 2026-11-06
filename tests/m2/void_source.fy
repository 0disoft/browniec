module tests::m2::void_source;
import compiler as compiler;
import program_image as programs;
import ir as ir;
import vm as vm;
import verifier as verifier;
fn void value(ref u8[] source){switch(compiler::compile_program(source,65536)){
    case .ok(p):{switch(programs::run_public(ref p,16000000)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};}
    case .err(_):{assert(false);}
};}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
};}
@test fn void explicit_and_implicit_returns_calls_and_recursive_control_flow_compose(){
    value(b"module main;fn void noop(){}fn i32 main(){let n=42;noop();return n;}");
    value(b"module main;fn void noop(){return;}fn void call(){noop();return;}fn i32 main(){call();return 42;}");
    value(b"module main;fn void write(ref mut i32[] a){a[0]=a[0]+1;}fn i32 main(){var a=[40];write(ref mut a);write(ref mut a);return a[0];}");
    value(b"module main;fn void count(i32 n,ref mut i32[] a){if(n==0){return;}a[0]=a[0]+1;count(n-1,ref mut a);}fn i32 main(){var a=[22];count(20,ref mut a);return a[0];}");
}
@test fn void call_statements_precede_if_and_switch_value_tails_without_becoming_values(){
    value(b"module main;fn void write(ref mut i32[] a){a[0]=20;}fn i32 main(){var a=[0];let n=if(true){write(ref mut a);22}else{0};return n+a[0];}");
    value(b"module main;fn void write(ref mut i32[] a){a[0]=20;}fn i32 main(){let Option<i32> o=.none;var a=[0];let n=switch(o){case .some(v):{0}case .none:{write(ref mut a);22}};return n+a[0];}");
    value(b"module main;fn void noop(){}fn void work(ref mut i32[] a){for(var i=0;i<2;i=i+1){noop();a[0]=a[0]+1;}}fn i32 main(){var a=[40];work(ref mut a);return a[0];}");
}
@test fn void owned_parameters_locals_and_argument_snapshots_use_existing_cleanup(){
    value(b"module main;struct P{i32 x;}fn void work(i32[1] a,P p,ref mut i32[] c){let b=[a[0]];let q=P{.x=p.x};c[0]=b[0]+q.x;}fn i32 main(){var c=[0];work([20],P{.x=22},ref mut c);return c[0];}");
    value(b"module main;struct P{i32 x;}fn void use(P p,i32 n,ref mut i32[] c){c[0]=p.x+n;}fn i32 main(){var P p=P{.x=20};var c=[0];use(p,if(true){p.x=22;0}else{0},ref mut c);return c[0]+p.x;}");
    value(b"module main;fn void take(i32[1] a,i32 n){}fn void work(ref mut i32[] c){take([0],if(true){c[0]=42;return;}else{0});c[0]=0;}fn i32 main(){var c=[0];work(ref mut c);return c[0];}");
}
@test fn void retained_image_runtime_and_returned_views_close_before_void_return(){
    value(b"module main;fn void inspect(ref u8[] p){let n=p[0];if(n==0){return;}}fn i32 main(){inspect(ref b\"*\");return 42;}");
    value(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn void inspect(ref u8[] p){let q=id(ref p);let n=q[0];}fn i32 main(){var u8[1] a=[42];inspect(ref a);return a[0] as i32;}");
    value(b"module main;struct P{i32 x;}fn void work(ref mut i32[] a){let ref u8[] marker=b\"*\";let p=P{.x=42};let b=[0];a[0]=p.x;return;}fn i32 main(){var a=[0];work(ref mut a);return a[0];}");
}
@test fn void early_argument_exits_and_loop_transfers_close_only_published_captures(){
    value(b"module main;fn void take(i32[1] a,i32 n){}fn void work(ref mut i32[] c){while(c[0]<42){take([0],if(true){c[0]=c[0]+1;continue;}else{0});}while(true){take([0],if(true){break;}else{0});}}fn i32 main(){var c=[0];work(ref mut c);return c[0];}");
    value(b"module main;fn void take(i32[1] a,i32 n){}fn i32 main(){let ref u8[] marker=b\"*\";take([0],if(true){return 42;}else{0});return 0;}");
}
@test fn void values_bad_signatures_missing_semicolons_and_pure_headers_stay_rejected(){
    rejected(b"module main;fn void f(){return 1;}fn i32 main(){return 0;}",3);
    rejected(b"module main;fn void f(){}fn i32 main(){let n=f();return 0;}",3);
    rejected(b"module main;fn void f(){}fn i32 main(){return f();}",3);
    rejected(b"module main;fn void main(){}",3);
    rejected(b"module main;fn void f(void x){}fn i32 main(){return 0;}",3);
    rejected(b"module main;fn void[1] f(){}fn i32 main(){return 0;}",3);
    rejected(b"module main;fn i32 f(){return 0;}fn i32 main(){f();return 42;}",3);
    rejected(b"module main;fn void f(){}fn i32 main(){for(f();true;){}return 0;}",3);
    rejected(b"module main;fn void f(Option<i32> o){let n=o?;}fn i32 main(){return 0;}",3);
    rejected(b"module main;fn void f(){}fn i32 main(){f() return 0;}",2);
    rejected(b"module main;fn void f(){return;let n=0;}fn i32 main(){return 0;}",2);
}
@test fn void no_dummy_result_register_is_created_and_four_fuel_is_exact(){
    let ir::Program p=switch(compiler::compile(b"module main;fn void noop(){}fn i32 main(){let n=42;noop();return n;}")){
        case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
    assert(verifier::verify(ref p).is_ok && p.registers==1 && p.count==4);
    assert(switch(vm::run(ref p,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run(ref p,3)){case .ok(_):{false}case .err(e):{e.kind==8}});
}
