module tests::m2::aggregate_place_assignment;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
import program_image as programs;
import errors as errors;
import std::bytes as bytes;

fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){
    case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn void done(Result<i64,errors::Error> r){assert(switch(r){case .ok(n):{n==42}case .err(_):{false}});}
fn void shortage(Result<i64,errors::Error> r){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==8}});}
fn void both(ref u8[] source){let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);done(vm::run(ref p,16000000));
    switch(compiler::compile_reference_returns(source,65536)){
        case .ok(code):{done(programs::run_public_references(ref code,16000000));}case .err(_):{assert(false);}
    };
}
fn void oracle(ref u8[] source,usize ordinary,usize retained,u8 mode){
    let ir::Program p=compiled(source);assert(verifier::verify(ref p).is_ok);
    var usize select=256;var usize store=256;var usize pc=0;
    while(pc<p.count){let u8 op=p.code[pc*8];
        if(op==83){assert(select==256);select=pc;assert(p.code[pc*8+4]==if(mode<3){3}else{4});}
        if(op==85 || op==87){assert(store==256);store=pc;assert(p.code[pc*8+4]==if(mode<3){3}else{4});}
        assert(op!=38 && op!=40 && op!=46 && op!=47 && op!=48 && op!=49 && op!=81);pc+=1;
    }
    assert(select<store && p.code[(store+1)*8]==86 && p.code[select*8+1]==p.code[store*8+1]);
    if(mode==0 || mode==3){assert(p.code[store*8]==85);}else{assert(p.code[store*8]==87);}
    if(mode==1 || mode==2){assert(p.arrays.count==1 && p.code[store*8+5]==if(mode==2){1}else{0});}
    if(mode==4){assert(p.records.count==1 && p.code[(store-1)*8]==17 && p.code[(store-2)*8]==17);}
    shortage(vm::run(ref p,ordinary-1));done(vm::run(ref p,ordinary));done(vm::run(ref p,ordinary+1));
    switch(compiler::compile_reference_returns(source,65536)){
        case .ok(code):{shortage(programs::run_public_references(ref code,retained-1));
            done(programs::run_public_references(ref code,retained));done(programs::run_public_references(ref code,retained+1));}
        case .err(_):{assert(false);}
    };
}
@test fn void five_forms_have_ordered_ir_no_extra_owner_and_independent_exact_fuel(){
    oracle(b"module main;fn i32 main(){var a=[0;2];let b=[42;2];a=b;return a[0];}",72496,416568,0);
    oracle(b"module main;fn i32 main(){var a=[0;2];a=[42;2];return a[0];}",72351,416421,1);
    oracle(b"module main;fn i32 main(){var a=[0;2];a=[20,22];return a[0]+a[1];}",72670,416741,2);
    oracle(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=0,.y=0};let P q=P{.x=20,.y=22};p=q;return p.x+p.y;}",460112,804185,3);
    oracle(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=0,.y=0};p=P{.x=20,.y=22};return p.x+p.y;}",369935,714006,4);
}
@test fn void original_targets_survive_nested_writes_calls_grouping_and_all_place_kinds(){
    both(b"module main;fn i32[1] make(){var b=[0];b=[42];return b;}fn i32 main(){var a=[0];((a))=((make()));return a[0];}");
    both(b"module main;fn i32 main(){var a=[0];var b=[0];a=[if(true){b[0]+=42;42}else{0};1];if(b[0]==42){return a[0];}return 0;}");
    both(b"module main;fn i32 main(){var a=[0];var b=[20];let ref mut i32[] s=ref mut b;a=[if(true){s[0]+=22;42}else{0};1];if(s[0]==42){return a[0];}return 0;}");
    both(b"module main;struct P{i32 x;i32 y;}fn i32 main(){var P p=P{.x=20,.y=0};p.x+=if(true){((p))=P{.x=100,.y=99};22}else{0};if(p.y==99){return p.x;}return 0;}");
    both(b"module main;struct I{i32 x;i32 y;}struct R{I a;I b;}fn R make(){return R{.a=I{.x=20,.y=22},.b=I{.x=0,.y=0}};}fn i32 main(){var R p=R{.a=I{.x=0,.y=0},.b=I{.x=0,.y=0}};((p).b)=((make()).a);return p.b.x+p.b.y;}");
    both(b"module main;struct I{i32 x;i32 y;}struct R{I a;I b;}fn i32 main(){var R p=R{.a=I{.x=20,.y=22},.b=I{.x=0,.y=0}};p.b=if(true){p.a}else{I{.x=0,.y=0}};return p.b.x+p.b.y;}");
}
@test fn void all_nonlocal_exits_end_aggregate_selections_before_owner_and_loan_cleanup(){
    both(b"module main;fn i32 main(){var a=[0];a=[if(true){return 42;}else{0};1];return 0;}");
    both(b"module main;struct P{i32 x;}fn i32 main(){var P p=P{.x=0};p=P{.x=if(true){return 42;}else{0}};return 0;}");
    both(b"module main;fn i32[1] make(){var a=[0];a=[if(true){return [42];}else{0};1];return [0];}fn i32 main(){let a=make();return a[0];}");
    both(b"module main;struct P{i32 x;}fn P make(){var P p=P{.x=42};p=P{.x=if(true){return p;}else{0}};return p;}fn i32 main(){let p=make();return p.x;}");
    both(b"module main;fn void work(){var a=[0];a=[if(true){return;}else{0};1];}fn i32 main(){work();return 42;}");
    both(b"module main;fn Option<i32> work(Option<i32> o){var a=[0,0];a=[o?,0];return .some(a[0]);}fn i32 main(){switch(work(.none)){case .some(_):{return 0;}case .none:{}}switch(work(.some(42))){case .some(n):{return n;}case .none:{return 0;}}}");
    both(b"module main;fn i32 main(){var a=[0];while(true){a=[if(true){break;}else{0};1];}return 42;}");
    both(b"module main;fn i32 main(){var a=[0];var n=0;while(n<3){n+=1;a=[if(true){continue;}else{0};1];}return n+39;}");
    both(b"module main;fn i32 main(){var a=[0];var b=[0];a=[if(true){while(true){b=[if(true){break;}else{0};1];}42}else{0};1];return a[0]+b[0];}");
}
fn void rejected(ref u8[] source){assert(!compiler::compile(source).is_ok);}
@test fn void destination_types_borrows_and_full_lexical_capacity_keep_their_limits(){
    rejected(b"module main;fn i32 main(){let a=[0];a=[42];return 0;}");
    rejected(b"module main;fn i32 main(){var a=[0];a=[true];return 0;}");
    rejected(b"module main;fn i32 main(){var a=[0];a=[20,22];return 0;}");
    rejected(b"module main;fn i32 main(){var a=[0];let ref i32[] s=ref a;a=[42];return s[0];}");
    rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}fn i32 main(){var P p=P{.x=0};p=Q{.x=42};return 0;}");
    var bytes::Buffer text=bytes::empty();assert(bytes::append(ref mut text,b"module main;fn i32 main(){var a=[42];").is_ok);
    let ref u8[] letters=b"abcdefghijklmnopqrstuvwxyz";
    var usize i=0;while(i<63){let u8[2] suffix=[letters[i/26],letters[i%26]];
        assert(bytes::append(ref mut text,b"let item_").is_ok);assert(bytes::append(ref mut text,ref suffix).is_ok);
        assert(bytes::append(ref mut text,b"=0;").is_ok);i+=1;}
    assert(bytes::append(ref mut text,b"a=a;return a[0];}").is_ok);both(bytes::view(ref text));
}
