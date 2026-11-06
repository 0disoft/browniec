module tests::m2::copy_ir;
import copy_ir as copies;
import compiler as compiler;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import program_image as programs;

fn ir::Program compile(ref u8[] source){return switch(compiler::compile(source)){
    case .ok(p):{p}case .err(_):{assert(false);ir::empty()}
};}
fn usize site(ref ir::Program p,u8 op,usize ordinal){var usize pc=0;var usize n=0;
    while(pc<p.count){if(p.code[pc*8]==op){if(n==ordinal){return pc;}n+=1;}pc+=1;}
    assert(false);return 0;
}
fn usize mode(ref copies::Plan p){return switch(p.mode){case .Direct:{0}case .NoOp:{1}case .Snapshot:{2}};}
fn usize relation(ref copies::Plan p){return switch(p.relation){case .Disjoint:{0}case .Identical:{1}case .Overlap:{2}};}
fn copies::Plan plan(ref ir::Program p,usize pc){return switch(copies::instruction(p,pc,p.entry)){
    case .ok(v):{v}case .err(_):{assert(false);copies::Plan{.domain=.Array,.mode=.Direct,.relation=.Disjoint,
        .destination=0,.source=0,.bytes=0,.destination_offset=0,.source_offset=0,.fresh=false,.same_frame=false}}
};}
fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};}
fn void ordinary(ref u8[] source){let ir::Program p=compile(source);assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run(ref p,16000000)){case .ok(n):{n==42}case .err(_):{false}});
}
fn void retained(ref u8[] source){switch(compiler::compile_reference_returns(source,65536)){
    case .ok(p):{assert(switch(programs::run_public_references(ref p,16000000)){case .ok(n):{n==42}case .err(_):{false}});}
    case .err(_):{assert(false);}
};}
fn void both(ref u8[] source){ordinary(source);retained(source);}
fn ir::Program arrays(){return compile(b"module main;fn i32 main(){var a=[20;2];let b=a;a=b;a=a;return a[0]+22;}");}
fn ir::Program records(){return compile(b"module main;struct P{i32 x;bool b;}fn i32 main(){var P p=P{.x=20,.b=true};let P q=p;p=q;p=p;return p.x+22;}");}
fn ir::Program nested(){return compile(b"module main;struct I{i32 x;}struct O{I a;I b;}fn i32 main(){var O p=O{.a=I{.x=20},.b=I{.x=42}};p.a=p.b;p.a=p.a;return p.a.x;}");}

@test fn void array_fresh_independent_and_identity_strategies_are_reconstructed(){
    let ir::Program p=arrays();let copies::Plan fresh=plan(ref p,site(ref p,34,0));
    assert(fresh.fresh && fresh.same_frame && fresh.bytes==8 && mode(ref fresh)==0 && relation(ref fresh)==0);
    let copies::Plan independent=plan(ref p,site(ref p,38,0));
    assert(!independent.fresh && independent.destination!=independent.source && mode(ref independent)==0);
    let copies::Plan identity=plan(ref p,site(ref p,38,1));
    assert(!identity.fresh && identity.destination==identity.source && mode(ref identity)==1 && relation(ref identity)==1);
    assert(built(copies::metadata(ref p))==3);
}
@test fn void record_copies_and_identical_subtrees_always_keep_complete_snapshots(){
    let ir::Program p=records();let copies::Plan fresh=plan(ref p,site(ref p,42,0));
    assert(fresh.fresh && fresh.bytes==8 && mode(ref fresh)==2 && relation(ref fresh)==0);
    let copies::Plan assigned=plan(ref p,site(ref p,46,0));assert(mode(ref assigned)==2 && !assigned.fresh);
    let copies::Plan identity=plan(ref p,site(ref p,46,1));
    assert(mode(ref identity)==2 && relation(ref identity)==1 && identity.bytes==8);
}
@test fn void same_owner_subtrees_resolve_nominal_byte_windows_in_both_directions(){
    var ir::Program p=nested();let usize pc=site(ref p,47,0);let copies::Plan first=plan(ref p,pc);
    assert(first.destination==first.source && first.destination_offset==0 && first.source_offset==4);
    assert(first.bytes==4 && mode(ref first)==2 && relation(ref first)==0);
    p.code[pc*8+4]=1;p.code[pc*8+5]=0;let copies::Plan reverse=plan(ref p,pc);
    assert(reverse.destination_offset==4 && reverse.source_offset==0 && mode(ref reverse)==2);
    p.code[pc*8+4]=0;p.code[pc*8+5]=0;let copies::Plan identity=plan(ref p,pc);
    assert(relation(ref identity)==1 && mode(ref identity)==2);
    p.code[pc*8+4]=2;assert(!copies::metadata(ref p).is_ok && !verifier::verify(ref p).is_ok);
}
@test fn void copy_lifetimes_require_live_sources_and_fresh_or_writable_destinations(){
    var ir::Program p=arrays();let usize fresh=site(ref p,34,0);let usize assign=site(ref p,38,0);
    assert(built(copies::step(ref p,fresh,0,1))==3);
    assert(!copies::step(ref p,fresh,0,0).is_ok && !copies::step(ref p,fresh,0,3).is_ok);
    assert(built(copies::step(ref p,assign,0,3))==3);
    assert(!copies::step(ref p,assign,0,1).is_ok && !copies::step(ref p,assign,0,2).is_ok);
    p.arrays.mutable[0]=false;assert(!copies::step(ref p,assign,0,3).is_ok);
    p.arrays.mutable[0]=true;p.slice_roots[0]=1;p.slice_elements[0]=128;
    let usize one=1;let usize loan=one<<32;
    assert(!copies::step(ref p,fresh,0,1|loan).is_ok && !copies::step(ref p,assign,0,3|loan).is_ok);
    p.slice_elements[0]=0;assert(copies::step(ref p,fresh,0,1|loan).is_ok);
    assert(!copies::step(ref p,assign,0,3|loan).is_ok);
}
@test fn void foreign_roots_reserved_bytes_and_exact_shapes_reject_before_execution(){
    var ir::Program p=arrays();let usize pc=site(ref p,34,0);
    p.array_functions[0]=1;assert(!copies::metadata(ref p).is_ok);
    p.array_functions[0]=0;p.arrays.lengths[1]=3;assert(!copies::metadata(ref p).is_ok);
    p.arrays.lengths[1]=2;p.arrays.elements[1]=2;assert(!copies::metadata(ref p).is_ok);
    p.arrays.elements[1]=1;var usize byte=3;
    while(byte<8){p.code[pc*8+byte]=1;assert(!copies::metadata(ref p).is_ok && !verifier::verify(ref p).is_ok);
        p.code[pc*8+byte]=0;byte+=1;}
    p.code[pc*8+2]=16;assert(!copies::metadata(ref p).is_ok);
    p.code[pc*8+2]=0;p.code[pc*8+1]=16;assert(!copies::metadata(ref p).is_ok);
    p.code[pc*8+1]=1;p.count=257;assert(!copies::metadata(ref p).is_ok);
}
@test fn void same_layout_distinct_nominals_and_cross_function_copy_sources_are_rejected(){
    var ir::Program p=records();let usize pc=site(ref p,42,0);
    p.records.layouts.count=2;p.records.layouts.fields[1]=2;
    p.records.layouts.types[16]=1;p.records.layouts.types[17]=2;p.records.records[1]=1;
    assert(!copies::metadata(ref p).is_ok && !verifier::verify(ref p).is_ok);
    p.records.records[1]=0;p.record_functions[0]=1;assert(!copies::instruction(ref p,pc,0).is_ok);
    p.record_functions[0]=0;p.records.mutable[0]=false;let usize assigned=site(ref p,46,0);
    assert(!copies::instruction(ref p,assigned,0).is_ok);
}
fn void recursive_array(){
    let ir::Program p=compile(b"module main;fn i32 f(i32[1] a,i32 n){if(n==0){return a[0];}return f(a,n-1);}fn i32 main(){let a=[42;1];return f(a,2);}");
    let copies::Plan argument=switch(copies::argument(ref p,0,0,128,0,1,0)){case .ok(v):{v}case .err(_):{assert(false);plan(ref p,0)}};
    assert(argument.source==argument.destination && argument.fresh && !argument.same_frame && mode(ref argument)==0);
    assert(!copies::argument(ref p,0,0,128,0,0,0).is_ok && !copies::argument(ref p,0,0,144,0,1,0).is_ok);
    assert(switch(vm::run(ref p,16000000)){case .ok(n):{n==42}case .err(_):{false}});
}
fn void recursive_record(){
    let ir::Program p=compile(b"module main;struct P{i32 x;}fn i32 f(P p,i32 n){if(n==0){return p.x;}return f(p,n-1);}fn i32 main(){let P p=P{.x=42};return f(p,2);}");
    let usize one=1;let usize live=one<<16;
    let copies::Plan argument=switch(copies::argument(ref p,0,0,144,0,live,0)){case .ok(v):{v}case .err(_):{assert(false);plan(ref p,0)}};
    assert(argument.source==argument.destination && argument.fresh && !argument.same_frame && mode(ref argument)==2);
    assert(!copies::argument(ref p,0,0,144,0,0,0).is_ok && !copies::argument(ref p,0,0,128,0,live,0).is_ok);
    assert(switch(vm::run(ref p,16000000)){case .ok(n):{n==42}case .err(_):{false}});
}
@test fn void recursive_calls_never_treat_equal_static_ids_as_same_frame_identity(){recursive_array();recursive_record();}

@test fn void both_drivers_execute_existing_copy_forms_and_mixed_repeated_arguments(){
    both(b"module main;fn i32 main(){var a=[20;2];let b=a;a=b;a=a;return a[0]+22;}");
    both(b"module main;struct P{i32 x;bool b;}fn i32 main(){var P p=P{.x=20,.b=true};let P q=p;p=q;p=p;return p.x+22;}");
    both(b"module main;struct I{i32 x;}struct O{I a;I b;}fn i32 main(){var O p=O{.a=I{.x=20},.b=I{.x=42}};p.a=p.b;p.b=p.a;p.a=p.a;return p.a.x;}");
    both(b"module main;struct P{i32 x;}fn i32 use(i32[1] a,P p,i32[1] b,P q){return a[0]+p.x+b[0]+q.x;}fn i32 main(){let a=[10;1];let P p=P{.x=11};return use(a,p,a,p);}");
}
