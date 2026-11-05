module tests::m2::aggregate_inference;
import compiler as compiler;
import program_image as programs;
import ir as ir;
import verifier as verifier;
import std::bytes as bytes;

fn void value(ref u8[] source,i64 expected){
    let programs::PublicProgram p=switch(compiler::compile_program(source,65536)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var usize i=0;while(i<2){
        switch(programs::run_public(ref p,16000000)){case .ok(n):{assert(n==expected);}case .err(_):{assert(false);}};
        i+=1;
    }
}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
};}
@test fn void repeated_arrays_infer_exact_shapes_and_scalar_elements_with_independent_copies(){
    value(b"module main;fn i32 main(){var a=[21;2];let copy=a;a[0]=0;return copy[0]+copy[1];}",42);
    value(b"module main;fn i32 main(){var a=[true;2];a[0]=false;if(!a[0] && a[1]){return 42;}return 0;}",42);
    value(b"module main;fn i64 big(){return -9223372036854775808;}fn i32 main(){let a=[big();1];if(a[0]==-9223372036854775808){return 42;}return 0;}",42);
    value(b"module main;fn u8 byte(){return 42;}fn u32 word(){return 4294967295;}fn usize size(){return 18446744073709551615;}fn i32 main(){let a=[byte();1];let b=[word();1];let c=[size();1];if(b[0]==4294967295 && c[0]==18446744073709551615){return a[0] as i32;}return 0;}",42);
}
@test fn void record_constructors_shorthand_and_subrecords_keep_exact_nominal_copies(){
    value(b"module main;struct P{i32 x;i32 y;}fn i32 main(){let x=20;let y=22;let p=P{.x,.y};var copy=p;copy.x=0;return p.x+p.y;}",42);
    value(b"module main;struct P{i32 x;}struct Box{P a;P b;}fn i32 main(){let box=Box{.a=P{.x=20},.b=P{.x=22}};var p=box.a;p.x=0;return box.a.x+box.b.x;}",42);
    value(b"module main;struct P{i32 x;}fn P make(){let p=P{.x=42};return p;}fn i32 main(){let p=make();return p.x;}",42);
    value(b"module main;fn i32[2] make(){let a=[21;2];return a;}fn i32 main(){let a=make();return a[0]+a[1];}",42);
}
@test fn void aggregate_calls_and_repeated_fillers_evaluate_once_in_source_order(){
    value(b"module main;fn i32 bump(ref mut i32[] c){c[0]=c[0]+1;return 21;}fn i32 main(){var c=[0;1];let a=[bump(ref mut c);2];return a[0]+a[1]+c[0]-1;}",42);
    value(b"module main;fn i32[2] make(ref mut i32[] c){c[0]=c[0]+1;return [21;2];}fn i32 main(){var c=[0;1];let a=make(ref mut c);return a[0]+a[1]+c[0]-1;}",42);
    value(b"module main;struct P{i32 x;}fn P make(ref mut i32[] c){c[0]=c[0]+1;return P{.x=42};}fn i32 main(){var c=[0;1];let p=make(ref mut c);return p.x+c[0]-1;}",42);
    value(b"module main;fn i32[2] make(i32 n){return [n;2];}fn i32 id(i32 n){return n;}fn i32 main(){let Option<i32> o=.none;let a=make(switch(o){case .some(v):{v}case .none:{id(21)}});return a[0]+a[1];}",42);
}
@test fn void call_and_local_paths_distinguish_scalar_projections_from_owned_children(){
    value(b"module main;fn i32[2] make(){return [21;2];}fn i32 main(){let n=make()[0];let size=make().len;if(size==2){return n+21;}return 0;}",42);
    value(b"module main;struct P{i32 x;}struct Box{P inner;}fn Box make(){return Box{.inner=P{.x=42}};}fn i32 main(){let n=make().inner.x;var p=make().inner;p.x=0;return n+p.x;}",42);
    value(b"module main;struct P{i32 x;}struct B{P inner;}struct Box{B middle;}fn Box make(){return Box{.middle=B{.inner=P{.x=42}}};}fn i32 main(){let p=make().middle.inner;return p.x;}",42);
}
@test fn void early_initializer_exits_do_not_publish_pending_array_or_record_owners(){
    value(b"module main;fn Option<i32> work(){let Option<i32> o=.none;let a=[switch(o){case .some(v):{v}case .none:{return .some(42);}};2];return .some(a[0]);}fn i32 main(){let o=work();switch(o){case .some(v):{return v;}case .none:{return 0;}}}",42);
    value(b"module main;fn i32[1] take(i32[1] a){return a;}fn i32 main(){let prior=[7;1];let Option<i32> o=.none;let a=take([switch(o){case .some(v):{v}case .none:{return 42;}};1]);return a[0];}",42);
    value(b"module main;struct P{i32 x;}fn i32 main(){let prior=[7;1];let Option<i32> o=.none;let p=P{.x=switch(o){case .some(v):{v}case .none:{return 42;}}};return p.x;}",42);
}
@test fn void invalid_shapes_names_mutation_and_nominal_changes_still_fail_admission(){
    rejected(b"module main;fn i32 main(){let a=[a[0];2];return 0;}",3);
    rejected(b"module main;fn i32 main(){var a=[1;2];a=[1;3];return 0;}",3);
    rejected(b"module main;struct A{i32 x;}struct B{i32 x;}fn i32 main(){var p=A{.x=1};p=B{.x=2};return p.x;}",3);
    rejected(b"module main;fn i32 main(){let a=[1;0];return 0;}",3);
    rejected(b"module main;fn i32 main(){let Option<i32> o=.some(1);let a=[o;2];return 0;}",3);
    rejected(b"module main;fn i32 main(){for(var a=[1;1];false;){}return 0;}",3);
    rejected(b"module main;struct P{i32 x;}fn i32 main(){let p=P{.x=1};let q=p.missing;return 0;}",3);
    rejected(b"module main;struct P{i32 x;}fn i32 main(){let p=P{.x=1};let p=P{.x=2};return 0;}",3);
}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){
    case .ok(p):{p}case .err(_):{assert(false);ir::empty()}
};}
@test fn void annotated_and_inferred_aggregate_initializers_emit_identical_executable_bytes(){
    let ir::Program a=compiled(b"module main;struct P{i32 x;}fn i32 main(){var i32[2] a=[21;2];let i32[2] b=a;let P p=P{.x=0};var P q=p;q.x=0;return b[0]+b[1]+q.x;}");
    let ir::Program b=compiled(b"module main;struct P{i32 x;}fn i32 main(){var a=[21;2];let b=a;let p=P{.x=0};var q=p;q.x=0;return b[0]+b[1]+q.x;}");
    assert(verifier::verify(ref a).is_ok && verifier::verify(ref b).is_ok);
    assert(a.count==b.count && a.registers==b.registers && a.constant_count==b.constant_count);
    assert(a.arrays.count==b.arrays.count && a.records.count==b.records.count);
    var usize i=0;while(i<a.count*8){assert(a.code[i]==b.code[i]);i+=1;}
    i=0;while(i<a.registers){assert(a.types[i]==b.types[i] && a.slots[i]==b.slots[i]);i+=1;}
    i=0;while(i<a.constant_count){assert(a.constants[i]==b.constants[i]);i+=1;}
    i=0;while(i<a.arrays.count){assert(a.arrays.elements[i]==b.arrays.elements[i] && a.arrays.lengths[i]==b.arrays.lengths[i] && a.arrays.mutable[i]==b.arrays.mutable[i]);i+=1;}
    i=0;while(i<a.records.count){assert(a.records.records[i]==b.records.records[i] && a.records.mutable[i]==b.records.mutable[i]);i+=1;}
}
fn void append(ref mut bytes::Buffer b,ref u8[] s){assert(bytes::append(b,s).is_ok);}
fn void catalog(usize count,bool record,bool pass){
    var bytes::Buffer b=bytes::empty();append(ref mut b,b"module main;");
    if(record){append(ref mut b,b"struct P{i32 x;}");}append(ref mut b,b"fn i32 main(){");
    let ref u8[] names=b"abcdefghijklmnopq";var usize i=0;
    while(i<count){append(ref mut b,b"let ");append(ref mut b,names[i..i+1]);append(ref mut b,if(record){b"=P{.x=1};"}else{b"=[1;1];"});i+=1;}
    append(ref mut b,b"return 42;}");if(pass){value(bytes::view(ref b),42);}else{rejected(bytes::view(ref b),4);}
}
@test fn void inferred_owners_preserve_the_original_sixteen_site_catalog_limits(){
    catalog(16,false,true);catalog(17,false,false);catalog(16,true,true);catalog(17,true,false);
}
