module tests::m2::module_input_program;
import module_input_program as programs;
import module_input_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import verifier as verifier;
import static_call_ir as candidates;

fn sources::Builder builder(){return switch(sources::builder(4096,4096)){
    case .ok(v):{v}case .err(_):{assert(false);builder()}
};}
fn entries::InputEntry entry(ref u8[] a,ref u8[] b){
    var sources::Builder scratch=builder();assert(sources::add(ref mut scratch,b"library",a).is_ok);
    if(b.len!=0){assert(sources::add(ref mut scratch,b"application",b).is_ok);}
    let sources::Snapshot snapshot=switch(sources::freeze(ref scratch)){
        case .ok(v):{v}case .err(_):{assert(false);return entry(b"module app;pub fn i32 chosen(ref u8[] data){return 0;}",b"");}
    };
    let modules::Index index=switch(modules::build(snapshot)){
        case .ok(v):{v}case .err(_):{assert(false);return entry(b"module app;pub fn i32 chosen(ref u8[] data){return 0;}",b"");}
    };
    return switch(entries::select_i32_input(index,b"app",b"chosen")){
        case .ok(v):{v}case .err(_):{assert(false);entry(b"module app;pub fn i32 chosen(ref u8[] data){return 0;}",b"")}
    };
}
fn programs::Program kept(ref u8[] a,ref u8[] b){return switch(programs::compile(entry(a,b),65536)){
    case .ok(v):{v}case .err(_):{assert(false);kept(b"module app;pub fn i32 chosen(ref u8[] data){return 0;}",b"")}
};}
@test fn void complete_input_body_and_independent_abi_proof_reject_mutations(){
    let programs::Program p=kept(b"module app;fn i32 unused(){return 9;}pub fn i32 chosen(ref u8[] data){if(data.len==0){return 0;}return data[0] as i32;}",b"");
    let ref candidates::Program code=programs::code(ref p);let usize f=code.body.entry;let usize r=code.body.register_starts[f];
    assert(f==1 && code.body.arities[f]==1 && code.parameters[r]==3);
    assert(verifier::inspect_input_returns(code,programs::literals(ref p)).is_ok);
    assert(!verifier::inspect_reference_returns(code,programs::literals(ref p)).is_ok);
    var candidates::Program broken=*code;broken.parameters[r]=0;
    assert(!verifier::inspect_input_returns(ref broken,programs::literals(ref p)).is_ok);
    broken=*code;broken.body.arities[f]=0;
    assert(!verifier::inspect_input_returns(ref broken,programs::literals(ref p)).is_ok);
    broken=*code;broken.body.return_types[f]=2;
    assert(!verifier::inspect_input_returns(ref broken,programs::literals(ref p)).is_ok);
}
@test fn void original_modules_helpers_returned_input_ranges_and_image_origins_are_retained(){
    let programs::Program p=kept(b"module lib;pub fn ref u8[] tail(ref u8[] data){return data[1..];}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){let ref u8[] part=m::tail(ref data);let ref u8[] marker=b\"*\";if(part.len==0){return 0;}return part[0] as i32+marker[0] as i32;}");
    assert(sources::count(programs::snapshot(ref p))==2);
    let ref candidates::Program code=programs::code(ref p);
    assert(code.body.entry==1 && code.results[0]==3 && code.origins[0]==1);
    assert(verifier::inspect_input_returns(code,programs::literals(ref p)).is_ok);
}
@test fn void unused_body_errors_and_image_quota_prevent_input_program_publication(){
    switch(programs::compile(entry(b"module lib;pub fn i32 bad(){return missing;}",
        b"module app;pub fn i32 chosen(ref u8[] data){return 0;}"),65536)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.code.kind==3 && e.at.source==0 && e.at.start<e.at.end);}
    };
    switch(programs::compile(entry(b"module app;pub fn i32 chosen(ref u8[] data){return missing;}",b""),65536)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.code.kind==3 && e.at.source==0);}
    };
    switch(programs::compile(entry(b"module app;pub fn i32 chosen(ref u8[] data){return 0;}",b""),0)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.code.kind==4 && e.at.source==16);}
    };
}
