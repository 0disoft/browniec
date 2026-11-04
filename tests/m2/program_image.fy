module tests::m2::program_image;
import program_image as programs;
import static_image as images;
import compiler as compiler;
import slice_result_ir as ir;
import ir as ordinary_ir;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_owners as owners;
import array_slices as slices;
import std::bytes as bytes;
import errors as errors;

fn ir::Program code(ref u8[] source){
    return switch(compiler::inspect_slice_result_ir(source)){
        case .ok(value):{value}case .err(_):{assert(false);ir::Program{.body=ordinary_ir::empty(),.elements=[0;16],.parameters=[0;16]}}
    };
}
fn Result<images::Image,images::Error> image(ref u8[] text){
    var images::Builder b=images::builder(4096)?;
    let usize id=images::intern_text(ref mut b,text)?;return images::freeze(ref b,8192);
}
fn Result<programs::Program,programs::Error> kept(ref ir::Program unit,ref u8[] text,usize limit){
    let images::Image backing=switch(image(text)){
        case .ok(value):{value}case .err(e):{return .err(programs::Error{.kind=.Literal,.code=errors::make(0,0),.literal=e});}
    };return programs::retain(unit,backing,limit);
}
fn bool content(ref programs::Program p,ref u8[] expected){
    let ref images::Image backing=programs::literals(p);
    return switch(images::whole(backing,0)){
        case .ok(span):{switch(images::view(backing,span)){case .ok(value):{bytes::equal(value,expected)}case .err(_):{false}}}
        case .err(_):{false}
    };
}
fn bool quota(images::Error e){return switch(e){
    case .Quota:{true}case .State:{false}case .Limit:{false}case .Literals:{false}
    case .Utf8:{false}case .Kind:{false}case .Bounds:{false}case .Allocation:{false}case .Provider:{false}
};}
fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
fn Result<execution::Scalar,errors::Error> run(ref programs::Program p,usize fuel){
    let ref ir::Program unit=programs::code(p);
    var runtime::State state=runtime::empty(256);var u8[256] data=[0;256];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let Result<execution::Scalar,errors::Error> result=programs::run_scalar(p,unit.body.entry,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,fuel);
    drained(ref state);return result;
}
fn Result<programs::Program,programs::Error> escaped(){
    let ir::Program unit=code(b"module main;fn i32 main(){return 42;}");return kept(ref unit,b"alive",581);
}
@test fn void program_owns_literals_and_code_after_compiler_scope_and_candidate_changes(){
    let programs::Program p=switch(escaped()){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(content(ref p,b"alive"));
    var ir::Program unit=code(b"module main;fn i32 main(){return 42;}");
    let programs::Program snapshot=switch(kept(ref unit,b"abc",579)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    unit.body.constants[0]=0;unit.body.code[0]=255;unit.parameters[0]=8;
    switch(run(ref snapshot,1000000)){case .ok(v):{assert(v.value==42);}case .err(_):{assert(false);}};
    assert(content(ref snapshot,b"abc") && images::payload_capacity(programs::literals(ref snapshot))==3);
}
@test fn void programs_keep_distinct_images_without_global_literal_identity(){
    let ir::Program unit=code(b"module main;fn i32 main(){return 42;}");
    let programs::Program a=switch(kept(ref unit,b"A",577)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Program b=switch(kept(ref unit,b"B",577)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(content(ref a,b"A") && content(ref b,b"B"));
    let ref images::Image first=programs::literals(ref a);let ref images::Image second=programs::literals(ref b);
    let images::Span span=images::Span{.literal=0,.start=0,.end=1};
    switch(images::equal(first,span,second,span)){case .ok(same):{assert(!same);}case .err(_):{assert(false);}};
}
@test fn void retention_checks_exact_image_charge_and_hostile_limits(){
    let ir::Program unit=code(b"module main;fn i32 main(){return 42;}");
    switch(kept(ref unit,b"abc",578)){
        case .ok(_):{assert(false);}case .err(e):{switch(e.kind){case .Literal:{assert(quota(e.literal));}case .Code:{assert(false);}}}
    };
    assert(!kept(ref unit,b"",575).is_ok && !kept(ref unit,b"abc",0).is_ok);
    assert(kept(ref unit,b"",576).is_ok && kept(ref unit,b"abc",579).is_ok);
    assert(kept(ref unit,b"abc",18446744073709551615).is_ok);
}
@test fn void empty_catalog_program_runs_without_literal_payload(){
    let ir::Program unit=code(b"module main;fn i32 main(){return 42;}");
    let images::Builder scratch=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let images::Image no_literals=switch(images::freeze(ref scratch,576)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Program blank=switch(programs::retain(ref unit,no_literals,576)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(images::payload_capacity(programs::literals(ref blank))==0 && !images::whole(programs::literals(ref blank),0).is_ok);
    switch(run(ref blank,1000000)){case .ok(v):{assert(v.value==42);}case .err(_):{assert(false);}};
}
fn void invalid(ref ir::Program unit){
    switch(kept(unit,b"abc",579)){
        case .ok(_):{assert(false);}case .err(e):{switch(e.kind){case .Code:{assert(e.code.kind==5);}case .Literal:{assert(false);}}}
    };
}
@test fn void retention_independently_rejects_forged_ir_and_static_opcode_claims(){
    var ir::Program unit=code(b"module main;fn i32 main(){return 42;}");
    unit.parameters[0]=1;invalid(ref unit);assert(unit.parameters[0]==1);unit.parameters[0]=0;
    unit.body.code[0]=69;invalid(ref unit);unit.body.code[0]=1;
    unit.body.function_count=17;invalid(ref unit);
}
@test fn void scalar_reuse_preserves_exact_fuel_failures_and_immutable_image(){
    let ir::Program unit=code(b"module main;fn i32 main(){return 42;}");
    let programs::Program p=switch(kept(ref unit,b"abc",579)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize fuel=runtime::cost()+runtime::leave_cost()+unit.body.ends[unit.body.entry]-unit.body.starts[unit.body.entry];
    switch(run(ref p,fuel)){case .ok(v):{assert(v.value==42 && v.remaining==0);}case .err(_):{assert(false);}};
    switch(run(ref p,fuel-1)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(run(ref p,fuel)){case .ok(v):{assert(v.value==42 && v.remaining==0);}case .err(_):{assert(false);}};
    assert(content(ref p,b"abc") && images::payload_capacity(programs::literals(ref p))==3);
    let ir::Program bad=code(b"module main;fn i32 main(){return 1/0;}");
    let programs::Program fault=switch(kept(ref bad,b"error",581)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(run(ref fault,1000000)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==7);}};
    switch(run(ref fault,1000000)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==7);}};
    assert(content(ref fault,b"error"));
}
@test fn void retained_program_executes_existing_returned_view_call_cleanup(){
    let ir::Program unit=code(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){let i32[2] a=[42;2];let ref i32[] r=f(ref a);return r[0];}");
    let programs::Program p=switch(kept(ref unit,b"kept",580)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(run(ref p,10000000)){case .ok(v):{assert(v.value==42);}case .err(_):{assert(false);}};
    switch(run(ref p,10000000)){case .ok(v):{assert(v.value==42);}case .err(_):{assert(false);}};
    assert(content(ref p,b"kept"));
}
