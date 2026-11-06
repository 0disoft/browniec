module tests::m2::constructor_join_source;
import compiler as compiler;
import program_image as programs;
import ir as ir;
import vm as vm;
import verifier as verifier;
fn void value(ref u8[] source){switch(compiler::compile_program(source,65536)){
    case .ok(p):{switch(programs::run_public(ref p,16000000)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};}
    case .err(_):{assert(false);}
};}
fn void rejected(ref u8[] source){assert(!compiler::compile_program(source,65536).is_ok);}
@test fn void none_first_and_result_domains_are_inferred_from_other_continuing_arms(){
    value(b"module main;fn i32 main(){let o=if(true){.none}else{.some(false)};switch(o){case .none:{return 42;}case .some(v):{return 0;}}}");
    value(b"module main;fn i32 main(){var o=switch(.some(true)){case .none:{.none}case .some(_):{.some(42)}};let old=o;o=.none;switch(old){case .some(v):{return v;}case .none:{return 0;}}}");
    value(b"module main;fn i32 main(){let r=if(true){.ok(42)}else{.err(true)};switch(r){case .ok(v):{return v;}case .err(_):{return 0;}}}");
    value(b"module main;fn i32 main(){let r=if(false){.err(42)}else{.ok(true)};switch(r){case .ok(v):{if(v){return 42;}return 0;}case .err(v):{return v;}}}");
    value(b"module main;fn i32 main(){let r=switch(.some(1)){case .none:{.err(42)}case .some(_):{.ok(42)}};switch(r){case .ok(v):{return v;}case .err(v):{return v;}}}");
    value(b"module main;fn i32 main(){let r=switch(.some(1)){case .none:{.ok(true)}case .some(_):{.err(true)}};switch(r){case .ok(v):{if(v){return 42;}return 0;}case .err(v):{if(v){return 42;}return 0;}}}");
}
@test fn void known_values_groups_and_mixed_nested_tails_constrain_the_same_result(){
    value(b"module main;fn Option<bool> known(){return .some(true);}fn i32 main(){let o=if(false){((.none))}else{known()};switch(o){case .some(v):{if(v){return 42;}return 0;}case .none:{return 0;}}}");
    value(b"module main;fn i32 main(){let Option<bool> known=.some(true);let o=switch(.some(1)){case .none:{.none}case .some(_):{known}};switch(o){case .some(v):{if(v){return 42;}return 0;}case .none:{return 0;}}}");
    value(b"module main;fn i32 main(){let o=if(true){switch(.some(1)){case .none:{.none}case .some(_):{if(true){(.none)}else{.some(false)}}}}else{.some(true)};switch(o){case .none:{return 42;}case .some(_):{return 0;}}}");
    value(b"module main;fn i32 main(){let r=if(true){switch(.some(1)){case .none:{return 0;}case .some(_):{.ok(42)}}}else{(.err(true))};switch(r){case .ok(v):{return v;}case .err(_):{return 0;}}}");
}
@test fn void payload_effects_captures_and_early_exits_are_not_replayed_for_inference(){
    value(b"module main;fn bool choose(ref mut i32[] c){c[0]=c[0]+1;return true;}fn i32 main(){var c=[0];let o=if(true){.none}else{.some(choose(ref mut c))};let r=if(true){.ok(choose(ref mut c))}else{.err(0)};switch(r){case .ok(v):{if(v){return c[0]+41;}return 0;}case .err(_):{return 0;}}}");
    value(b"module main;fn bool read(i32[1] a){return a[0]==42;}fn i32 main(){let o=if(false){.none}else{.some(read([42]))};switch(o){case .some(v):{if(v){return 42;}return 0;}case .none:{return 0;}}}");
    value(b"module main;fn i32 take(i32[1] a,Result<i32,bool> r){return 0;}fn i32 main(){let n=take([0],if(true){.ok(if(true){return 42;}else{0})}else{.err(true)});return n;}");
    value(b"module main;fn i32 main(){let ref u8[] marker=b\"*\";let o=if(false){.none}else{.some(marker.len==1)};switch(o){case .some(v):{if(v){return 42;}return 0;}case .none:{return 0;}}}");
}
@test fn void unresolved_domains_conflicts_and_unsupported_payloads_stay_rejected(){
    rejected(b"module main;fn i32 main(){let o=if(true){.none}else{.none};return 0;}");
    rejected(b"module main;fn i32 main(){let r=if(true){.ok(42)}else{.ok(0)};return 0;}");
    rejected(b"module main;fn i32 main(){let r=if(true){.err(true)}else{.err(false)};return 0;}");
    rejected(b"module main;fn i32 main(){let r=if(true){.none}else{.ok(42)};return 0;}");
    rejected(b"module main;fn i32 main(){let o=if(true){.some(42)}else{.some(true)};return 0;}");
    rejected(b"module main;fn i32 main(){let Option<i32> o=if(true){.none}else{.some(true)};return 0;}");
    rejected(b"module main;fn i32 main(){let o=if(true){.none}else{.some(42 as i64)};return 0;}");
    rejected(b"module main;fn i32 main(){let r=if(true){.ok(42)}else{.err(b\"*\"[0])};return 0;}");
    rejected(b"module main;fn i32 main(){let o=if(true){.none}else{.some(.some(42))};return 0;}");
    rejected(b"module main;fn i32 main(){let o=switch(.some(1)){case .none:{.none}case .some(_):{return 0;}};return 0;}");
    rejected(b"module main;fn i32 main(){for(let o=if(true){.none}else{.some(42)};false;){}return 0;}");
}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
@test fn void inferred_and_annotated_types_keep_identical_ir_and_exact_nine_unit_fuel(){
    let ir::Program a=compiled(b"module main;fn i32 main(){let Option<bool> o=if(true){.none}else{.some(false)};switch(o){case .none:{return 42;}case .some(_):{return 0;}}}");
    let ir::Program b=compiled(b"module main;fn i32 main(){let o=if(true){.none}else{.some(false)};switch(o){case .none:{return 42;}case .some(_):{return 0;}}}");
    assert(verifier::verify(ref b).is_ok && a.count==b.count && a.registers==b.registers && a.constant_count==b.constant_count);
    var usize i=0;while(i<a.count*8){assert(a.code[i]==b.code[i]);i+=1;}
    i=0;while(i<a.registers){assert(a.types[i]==b.types[i] && a.slots[i]==b.slots[i]);i+=1;}
    i=0;while(i<a.constant_count){assert(a.constants[i]==b.constants[i]);i+=1;}
    assert(switch(vm::run(ref b,9)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run(ref b,8)){case .ok(_):{false}case .err(e):{e.kind==8}});
}
