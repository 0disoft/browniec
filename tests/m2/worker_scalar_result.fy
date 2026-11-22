module tests::m2::worker_scalar_result;

import errors as errors;
import source_snapshot as sources;
import worker_project_wire as project;
import worker_scalar_result as worker;
import std::bytes as bytes;

fn worker::Outcome round_trip(worker::Outcome original,worker::Expected expected){
    let bytes::Buffer wire=switch(worker::encode(original,expected)){
        case .ok(buffer):{buffer}case .err(_):{assert(false);bytes::empty()}
    };
    return switch(worker::parse(bytes::view(ref wire),expected)){
        case .ok(result):{result}case .err(_):{assert(false);worker::checked()}
    };
}

fn bool accepts(ref u8[] wire,worker::Expected expected){
    return worker::parse(wire,expected).is_ok;
}

@test
fn void strict_scalar_result_contract(){
    let worker::Expected check_case=worker::Expected{.run=false,.output=false,.source_bytes=9,.instructions=2};
    let worker::Expected run_case=worker::Expected{.run=true,.output=false,.source_bytes=9,.instructions=2};
    let worker::Outcome passed=round_trip(worker::checked(),check_case);
    assert(switch(passed.status){case .Checked:{true}case .Completed:{false}case .Failed:{false}});
    let worker::Outcome minimum=round_trip(worker::completed(-2147483648),run_case);
    let worker::Outcome maximum=round_trip(worker::completed(2147483647),run_case);
    let worker::Outcome verifier=round_trip(worker::failed(errors::instruction(0)),check_case);
    let worker::Outcome syntax=round_trip(worker::failed(errors::make(2,9)),check_case);
    let errors::Error location=verifier.error;
    let errors::Error eof=syntax.error;
    assert(minimum.value== -2147483648 && maximum.value==2147483647);
    assert(location.location==1 && location.offset==0 && eof.offset==9);
    assert(!worker::encode(worker::completed(2147483648),run_case).is_ok);
    assert(!worker::encode(worker::failed(errors::instruction(2)),check_case).is_ok);
    assert(!worker::encode(worker::failed(errors::absent(8,0)),check_case).is_ok);
    assert(accepts(b"{\"return_i32\":77,\"status\":\"completed\",\"schema\":\"browniec.worker-result/v1\"}",run_case));
    assert(!accepts(b"{\"schema\":\"browniec.worker-result/v1\",\"status\":\"checked\"}",run_case));
    assert(!accepts(b"{\"schema\":\"browniec.worker-result/v1\",\"status\":\"completed\",\"return_i32\":1e2}",run_case));
    assert(!accepts(b"{\"schema\":\"browniec.worker-result/v1\",\"status\":\"completed\",\"return_i32\":2147483648}",run_case));
    assert(!accepts(b"{\"schema\":\"browniec.worker-result/v1\",\"status\":\"completed\"}",run_case));
    assert(!accepts(b"{\"schema\":\"browniec.worker-result/v1\",\"status\":\"checked\",\"st\\u0061tus\":\"checked\"}",check_case));
    assert(!accepts(b"{\"schema\":\"browniec.worker-result/v1\",\"status\":\"checked\",\"extra\":{}}",check_case));
    assert(!accepts(b"{\"schema\":\"browniec.worker-result/v1\",\"status\":\"checked\",}",check_case));
    assert(!accepts(b"{\"schema\":\"browniec.worker-result/v1\",\"status\":\"checked\"}{}",check_case));
    assert(!accepts(b"{\"schema\":\"browniec.worker-result/v2\",\"status\":\"checked\"}",check_case));
    assert(!accepts(b"{\"schema\":\"browniec.worker-result/v1\",\"status\":\"error\",\"kind\":5,\"location\":1,\"offset\":2}",check_case));
    assert(!accepts(b"{\"schema\":\"browniec.worker-result/v1\",\"status\":\"error\",\"kind\":2,\"location\":0,\"offset\":10}",check_case));
    assert(!accepts(b"{\"schema\":\"browniec.worker-result/v1\",\"status\":\"error\",\"kind\":2,\"location\":2,\"offset\":1}",check_case));
    let u8[257] oversized=[32;257];
    assert(!accepts(ref oversized,check_case));
    assert(!worker::parse_profiled(ref oversized,check_case).is_ok);
    assert(!worker::parse_profiled(b"\x07",check_case).is_ok);
    assert(!worker::parse_profiled(b"\x09{\"schema\":\"browniec.worker-result/v1\",\"status\":\"checked\"}",check_case).is_ok);
    let worker::Profiled retained=worker::Profiled{.outcome=worker::checked(),.profile=8};
    let bytes::Buffer framed=switch(worker::encode_profiled(retained,check_case)){
        case .ok(buffer):{buffer}case .err(_):{assert(false);bytes::empty()}
    };
    let worker::Profiled parsed=switch(worker::parse_profiled(bytes::view(ref framed),check_case)){
        case .ok(value):{value}case .err(_):{assert(false);retained}
    };
    assert(parsed.profile==8);
    assert(!worker::parse_profiled(bytes::view(ref framed),run_case).is_ok);
}

@test
fn void project_output_requires_an_authorized_successful_frame(){
    let project::Outcome passed=project::Outcome{.value=worker::completed(77),.profile=8,.span=sources::no_source()};
    let project::Outcome failed=project::Outcome{
        .value=worker::failed(errors::absent(20,0)),.profile=8,.span=sources::no_source()};
    let ref u8[] lengths=b"\x09\x00";
    let bytes::Buffer frame=switch(project::encode_output(passed,b"\x00\xFF")){
        case .ok(buffer):{buffer}case .err(_):{assert(false);bytes::empty()}
    };
    let ref u8[] payload=bytes::view(ref frame);
    let project::ResultFrame parsed=switch(project::parse_frame(payload,true,lengths,true,2)){
        case .ok(result):{result}
        case .err(_):{assert(false);return;}
    };
    assert(parsed.has_output && parsed.outcome.value.value==77);
    assert(bytes::equal(payload[parsed.output_start..payload.len],b"\x00\xFF"));
    assert(!project::parse_frame(payload,true,lengths,true,1).is_ok);
    assert(!project::parse_frame(payload,true,lengths,false,2).is_ok);
    assert(!project::parse_frame(payload,false,lengths,true,2).is_ok);
    assert(!project::parse_frame(payload[..4],true,lengths,true,2).is_ok);
    assert(!project::encode_output(failed,b"x").is_ok);
    let bytes::Buffer legacy=switch(project::encode_result(passed,true,false)){
        case .ok(buffer):{buffer}case .err(_):{assert(false);bytes::empty()}
    };
    assert(project::parse_frame(bytes::view(ref legacy),true,lengths,false,0).is_ok);
    assert(!project::parse_frame(bytes::view(ref legacy),true,lengths,true,2).is_ok);
    let bytes::Buffer error_frame=switch(project::encode_result(failed,true,true)){
        case .ok(buffer):{buffer}case .err(_):{assert(false);bytes::empty()}
    };
    assert(project::parse_frame(bytes::view(ref error_frame),true,lengths,true,2).is_ok);
    assert(!project::parse_frame(bytes::view(ref error_frame),true,lengths,false,0).is_ok);
    let bytes::Buffer empty=switch(project::encode_output(passed,b"")){
        case .ok(buffer):{buffer}case .err(_):{assert(false);bytes::empty()}
    };
    assert(project::parse_frame(bytes::view(ref empty),true,lengths,true,0).is_ok);
}
