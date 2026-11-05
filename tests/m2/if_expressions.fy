module tests::m2::if_expressions;
import compiler as compiler;
import program_image as programs;
import ir as ir;
import vm as vm;
import std::bytes as bytes;
fn void value(ref u8[] source){switch(compiler::compile_program(source,65536)){
    case .ok(p):{switch(programs::run_public(ref p,16000000)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};}
    case .err(_):{assert(false);}
};}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
};}
@test fn void inferred_typed_tagged_and_all_scalar_domains_compose_with_operators_and_calls(){
    value(b"module main;fn i32 id(i32 x){return x;}fn i32 main(){let n=if(true){20}else{1/0};return id(if(false){0}else{n+22});}");
    value(b"module main;fn i32 main(){let i64 x=if(true){-9223372036854775808}else{0};let u32 y=if(false){0}else{4294967295};let usize z=if(true){18446744073709551615}else{0};let u8 b=if(true){42}else{0};let yes=if(false){false}else{true};if(x==-9223372036854775808 && y==4294967295 && z==18446744073709551615 && yes){return b as i32;}return 0;}");
    value(b"module main;fn i32 main(){let o=if(true){.some(42)}else{.none};return switch(o){case .some(v):{v}case .none:{0}};}");
    value(b"module main;fn Option<i32> work(bool b){return if(b){.some(42)}else{.none};}fn i32 main(){return switch(work(true)){case .some(v):{v}case .none:{0}};}");
    value(b"module main;fn i32 main(){let i64 n=if(false){0}else{42} as i64;if(n==42){return 42;}return 0;}");
    value(b"module main;fn Result<bool,i32> f(bool b){return if(b){.ok(true)}else{.err(42)};}fn i32 main(){switch(f(false)){case .ok(v):{return 0;}case .err(v):{return v;}}}");
}
@test fn void nested_tail_conditionals_coexist_with_statement_blocks_loops_and_else_if(){
    value(b"module main;fn i32 main(){let n=if(true){if(false){0}else{if(true){42}else{0}}}else{0};return n;}");
    value(b"module main;fn i32 main(){let n=if(false){0}else if(false){1}else if(true){42}else{2};return n;}");
    value(b"module main;fn i32 main(){var n=0;let x=if(true){if(true){n=20;}else{n=0;}while(n<21){n=n+1;}for(var k=0;k<1;k=k+1){n=n+1;}{let local=20;n=n+local;}n}else{0};return x;}");
    value(b"module main;fn i32 main(){let Option<i32> o=.none;return switch(o){case .some(v):{if(false){0}else{v}}case .none:{if(true){if(false){0}else{20}+22}else{0}}};}");
    value(b"module main;fn i32 main(){return if(true){if(false){return 0;}42}else if(true){return 0;}else{return 0;};}");
}
@test fn void conditions_branches_and_arm_locals_keep_once_only_order_and_scope(){
    value(b"module main;fn bool condition(ref mut i32[] c){c[0]=c[0]+1;return true;}fn i32 main(){var c=[0];let x=if(condition(ref mut c)){let local=20;local}else{c[0]=99;let local=0;local};return x+c[0]+21;}");
    value(b"module main;fn i32 main(){var n=0;let x=if(false){n=99;0}else if(if(true){n=n+1;true}else{false}){n=n+1;40}else{n=99;0};return x+n;}");
    value(b"module main;fn i32 main(){var n=0;if(false && if(true){n=99;true}else{false}){return 0;}if(true || if(true){n=99;false}else{true}){return n+42;}return 0;}");
    value(b"module main;fn i32 main(){let n=if(true){let a=[20,22];let ref u8[] marker=b\"*\";(a)[0]+(a)[1]}else{let a=[0];a[0]};return n;}");
}
@test fn void return_propagation_and_loop_transfers_preserve_capture_and_owner_cleanup(){
    value(b"module main;fn i32 take(i32[1] a,i32 n){return n;}fn i32 main(){let ref u8[] marker=b\"*\";let n=take([0],if(true){let p=[0];return 42;}else{0});return n;}");
    value(b"module main;fn Option<i32> work(Option<i32> o){let n=if(true){let a=[0];o?}else{0};return .some(n);}fn i32 main(){switch(work(.none)){case .some(v):{return 0;}case .none:{}}switch(work(.some(42))){case .some(v):{return v;}case .none:{return 0;}}}");
    value(b"module main;fn i32 take(i32[1] a,i32 n){return n;}fn i32 main(){var n=0;let Option<i32> o=.none;while(n<42){let x=take([0],if(true){let a=[0];n=n+1;continue;}else{0});}while(true){let x=take([0],if(true){let a=[0];break;}else{0});}return n;}");
    value(b"module main;fn i32 main(){var n=0;while(if(n<42){n=n+1;continue;}else{false}){return 0;}return n;}");
}
fn void fuel(ref u8[] source,usize exact){
    let ir::Program p=switch(compiler::compile(source)){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};
    assert(switch(vm::run(ref p,exact)){case .ok(v):{v==42}case .err(_):{false}});
    assert(switch(vm::run(ref p,exact-1)){case .ok(_):{false}case .err(e):{e.kind==8}});
}
@test fn void branch_fuel_uses_the_existing_instruction_schedule_and_bad_joins_stay_rejected(){
    fuel(b"module main;fn i32 main(){return if(true){42}else{0};}",7);
    fuel(b"module main;fn i32 main(){return if(false){0}else{42};}",6);
    rejected(b"module main;fn i32 main(){return if(1){42}else{0};}",3);
    rejected(b"module main;fn i32 main(){let x=if(true){42}else{false};return 0;}",3);
    rejected(b"module main;fn i32 main(){return if(true){42};}",2);
    rejected(b"module main;fn i32 main(){let n=if(true){return 42;}else{return 0;};return n;}",3);
    rejected(b"module main;fn i32 main(){let n=if(true){let x=42;x}else{0};return x;}",3);
    rejected(b"module main;fn i32 main(){for(var i=if(true){0}else{0};i<1;i=i+1){}return 42;}",3);
    rejected(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42];let p=id(ref a);let n=if(true){a=[0];42}else{0};return p[0] as i32;}",5);
}
fn void append(ref mut bytes::Buffer b,ref u8[] source){assert(bytes::append(b,source).is_ok);}
fn void depth(usize count,bool pass,bool arms){
    var bytes::Buffer s=bytes::empty();append(ref mut s,b"module main;fn i32 main(){return ");
    var usize i=0;while(i<count){append(ref mut s,if(arms){b"if(true){"}else{b"if(if(true){true}else{false}){"});i+=1;}
    append(ref mut s,b"42");i=0;while(i<count){append(ref mut s,b"}else{0}");i+=1;}append(ref mut s,b";}");
    if(pass){value(bytes::view(ref s));}else{rejected(bytes::view(ref s),4);}
}
@test fn void combined_condition_arm_and_existing_expression_depth_is_bounded(){
    depth(16,true,true);depth(17,false,true);depth(15,true,false);depth(16,false,false);
}
