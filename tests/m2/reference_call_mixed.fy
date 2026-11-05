module tests::m2::reference_call_mixed;
import compiler as compiler;
import ir as ir;
import static_call_ir as calls;
import static_image as images;
import verifier as verifier;
import program_image as programs;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_owners as owners;
import array_slices as slices;
import errors as errors;
import std::num as num;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 byte(usize n){return switch(num::u8_from_i64(switch(num::i64_from_usize(n)){case .ok(v):{v}case .err(_):{assert(false);0}})){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn images::Image image(){
    var images::Builder b=switch(images::builder(1)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    let usize id=switch(images::intern_bytes(ref mut b,b"*")){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(images::freeze(ref b,577)){case .ok(v):{v}case .err(_):{assert(false);image()}};
}
// The fixtures are straight-line compiler output. Add a private universal byte formal
// in place of the deliberately unused first scalar; preserve all ordinary
// aggregate/loan operands, cleanup instructions and canonical result metadata.
fn void insert(ref mut ir::Program p,usize at,u8 op,usize dst,usize a,usize b){
    let usize appended=built(ir::raw(p,op,dst,a,b,0));var u8[8] code=[0;8];var usize i=0;
    while(i<8){code[i]=p.code[appended*8+i];i+=1;}
    var usize pc=appended;while(pc>at){let usize offset=p.offsets[pc-1];p.offsets[pc]=offset;
        i=0;while(i<8){let u8 value=p.code[(pc-1)*8+i];p.code[pc*8+i]=value;i+=1;}pc-=1;
    }
    i=0;while(i<8){p.code[at*8+i]=code[i];i+=1;}p.offsets[at]=0;
    var usize f=0;while(f<p.function_count){if(p.starts[f]>=at){p.starts[f]+=1;}if(p.ends[f]>at){p.ends[f]+=1;}f+=1;}
    // Inserting the first instruction extends that function at its old start.
}
fn usize call(ref ir::Program p){var usize pc=0;while(pc<p.count){if(p.code[pc*8]==9){return pc;}pc+=1;}assert(false);return 0;}
fn calls::Program wired(ref u8[] source){
    var ir::Program p=switch(compiler::compile(source)){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};
    assert(p.call_count==1);var usize pc=0;while(pc<p.count){assert(p.code[pc*8]<19 || p.code[pc*8]>25);pc+=1;}
    let usize target=p.code[call(ref p)*8+2] as usize;let usize formal=p.register_starts[target];
    assert(p.arities[target]==2 && p.types[formal]==1);p.types[formal]=0;
    let usize start=p.starts[target];insert(ref mut p,start,77,1,formal,3);p.starts[target]=start;
    let usize terminal=p.ends[target]-1;let u8 op=p.code[terminal*8];assert(op==8 || op==39 || op==50);
    insert(ref mut p,terminal,70,1,0,0);
    let usize before=call(ref p);insert(ref mut p,before,69,0,0,1);p.code[before*8+6]=1;
    let usize at=before+1;let usize map=p.code[at*8+3] as usize;p.code[at*8]=78;p.call_args[map*8]=192;
    insert(ref mut p,at+1,70,0,0,0);
    var u8[128] parameters=[0;128];parameters[formal]=3;
    return calls::Program{.body=p,.parameters=parameters,.results=[0;16],.origins=[0;16]};
}
fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
fn Result<execution::Scalar,errors::Error> run(ref programs::ReferenceProgram p,ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let usize entry=programs::reference_code(p).body.entry;
    return programs::run_reference_scalar(p,entry,ref captures[..0],ref values[..0],ref inputs[..0],state,data,fuel);
}
fn void example(ref u8[] source){
    let calls::Program unit=wired(source);
    let programs::ReferenceProgram program=switch(programs::retain_references(ref unit,image(),577)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var runtime::State state=runtime::empty(64);var u8[64] data=[99;64];let usize allowance=10000000;
    let execution::Scalar first=switch(run(ref program,ref mut state,ref mut data,allowance)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Scalar{.value=0,.remaining=allowance,.resumed=[slices::Ticket{.slot=16,.generation=0};8]}}
    };assert(first.value==42);drained(ref state);
    // Measured whole-invocation boundaries, in addition to independent oracles
    // in static_call_execution: all paths must charge once and clean on failure.
    let usize required=allowance-first.remaining;
    switch(run(ref program,ref mut state,ref mut data,required-1)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};drained(ref state);
    let execution::Scalar exact=switch(run(ref program,ref mut state,ref mut data,required)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Scalar{.value=0,.remaining=99,.resumed=[slices::Ticket{.slot=16,.generation=0};8]}}
    };assert(exact.value==42 && exact.remaining==0);drained(ref state);
}
@test fn void static_arguments_coexist_with_record_values_and_owned_array_and_record_results(){
    example(b"module main;struct P{i32 x;}fn i32 f(i32 unused,P p){return p.x+22;}fn i32 main(){let P p=P{.x=20};return f(0,p);}");
    example(b"module main;fn i32[1] f(i32 unused,i32[1] a){return a;}fn i32 main(){let i32[1] a=[42;1];let i32[1] b=f(0,a);return b[0];}");
    example(b"module main;struct P{i32 x;}fn P f(i32 unused,P p){return p;}fn i32 main(){let P p=P{.x=42};let P q=f(0,p);return q.x;}");
}
@test fn void static_arguments_coexist_with_shared_and_exclusive_runtime_loans(){
    example(b"module main;fn i32 f(i32 unused,ref u8[] p){return (p[0] as i32)+22;}fn i32 main(){let u8[1] a=[20;1];let ref u8[] r=ref a;return f(0,ref r);}");
    example(b"module main;fn i32 f(i32 unused,ref mut u8[] p){p[0]=42;return p[0] as i32;}fn i32 main(){var u8[1] a=[0;1];let ref mut u8[] r=ref mut a;return f(0,ref mut r);}");
}
@test fn void mixed_argument_kind_confusion_is_rejected_before_native_effects(){
    var calls::Program unit=wired(b"module main;struct P{i32 x;}fn i32 f(i32 unused,P p){return p.x+22;}fn i32 main(){let P p=P{.x=20};return f(0,p);}");
    let images::Image data=image();var usize pc=0;while(pc<unit.body.count && unit.body.code[pc*8]!=78){pc+=1;}
    let usize map=unit.body.code[pc*8+3] as usize;unit.body.call_args[map*8+1]=192;
    switch(verifier::inspect_reference_calls(ref unit,ref data)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
}
