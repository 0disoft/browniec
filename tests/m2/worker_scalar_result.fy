module tests::m2::worker_scalar_result;

import errors as errors;
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
}
