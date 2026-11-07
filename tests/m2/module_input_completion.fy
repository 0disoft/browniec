module tests::m2::module_input_completion;
import module_input_program as programs;
import module_input_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import runtime_input as inputs;
import static_call_ir as candidates;
import slice_result_execution as execution;
import slice_result_runtime as runtime;
import array_owners as owners;
import array_slices as slices;
import std::bytes as bytes;

import fuel as meter;
import errors as errors;
import ir as ir;

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
fn inputs::Snapshot captured(ref u8[] data){
    var usize fuel=11;
    return switch(inputs::snapshot(data,inputs::hard_limit(),1,ref mut fuel)){
        case .ok(v):{assert(fuel==10);v}case .err(_):{assert(false);captured(b"")}
    };
}

// Static schedule oracle for these straight-line, single-use function fixtures.
// This sums declared instruction prices, never evaluates registers or executes
// the VM. Each helper is reached exactly once; ancestors stop at their CALL
// when testing a terminal leaf error. No branches, arrays or runtime loans.
fn usize instruction(u8 op){
    if(op==77){return meter::reference_parameter(false)+meter::input_metadata();}
    if(op==70){return meter::input_metadata();}
    if(op==71 || op==72 || op==75 || op==76){return meter::static_instruction(op,0,0)+meter::input_metadata();}
    if(op==78){return meter::input_frame()+meter::reference_call(1,0)+meter::input_arguments(1);}
    if(op==79){return meter::input_frame()+meter::reference_return()+meter::input_metadata()+runtime::leave_cost();}
    if(op==8){return meter::input_frame()+runtime::leave_cost();}
    assert(op<33);return 0;
}
fn usize schedule(ref ir::Program body,u8 terminal,bool stop_calls){
    var usize total=meter::input_prepare();var usize f=0;var bool found=false;
    while(f<body.function_count){assert(body.arities[f]==1);
        total+=runtime::cost()+1;var usize pc=body.starts[f];
        while(pc<body.ends[f]){let u8 op=body.code[pc*8];total+=1;
            if(op==terminal){
                // READ already commits input metadata before its atomic checked
                // byte. RANGE and scalar failure commit no helper price.
                if(op==71){total+=meter::input_metadata();}found=true;break;
            }
            total+=instruction(op);
            if(stop_calls && op==78){break;}pc+=1;
        }f+=1;
    }if(terminal!=0){assert(found);}return total;
}
fn usize token(ref u8[] text,ref u8[] needle){
    var usize i=0;while(i+needle.len<=text.len){if(bytes::equal(text[i..i+needle.len],needle)){return i;}i+=1;}
    assert(false);return 0;
}
fn void successful(ref programs::Program p,ref inputs::Snapshot input,usize fuel,usize remaining){
    let programs::Completion v=programs::complete(p,input,fuel);
    assert(v.success && v.value==42 && v.remaining==remaining && v.diagnostic.code.kind==0);
    switch(programs::run(p,input,fuel)){
        case .ok(old):{assert(old.value==v.value && old.remaining==v.remaining);}case .err(_):{assert(false);}
    };
}
@test fn void zero_preflight_dispatch_and_atomic_parameter_boundaries_keep_real_balance(){
    let programs::Program p=kept(b"module app;pub fn i32 chosen(ref u8[] data){return 42;}",b"");
    let inputs::Snapshot input=captured(b"*");let usize minimum=meter::input_prepare()+runtime::cost()+1;
    let usize[3] budgets=[0,1,minimum-1];var usize i=0;
    while(i<3){let usize fuel=budgets[i];let programs::Completion v=programs::complete(ref p,ref input,fuel);
        assert(!v.success && v.value==0 && v.remaining==fuel && v.diagnostic.code.kind==8 && v.diagnostic.code.offset==0);i+=1;}
    let programs::Completion entered=programs::complete(ref p,ref input,minimum);
    assert(!entered.success && entered.remaining==0 && entered.diagnostic.code.kind==8);
    let programs::Completion dispatched=programs::complete(ref p,ref input,minimum+2);
    assert(!dispatched.success && dispatched.remaining==1 && dispatched.diagnostic.code.kind==8);
    let ref ir::Program body=ref programs::code(ref p).body;
    assert(dispatched.diagnostic.code.offset==body.offsets[body.starts[body.entry]]);
}
@test fn void exact_and_one_less_return_keep_atomic_leave_and_prepaid_abort_prices(){
    let programs::Program p=kept(b"module app;pub fn i32 chosen(ref u8[] data){return 42;}",b"");
    let inputs::Snapshot input=captured(b"*");let ref ir::Program body=ref programs::code(ref p).body;
    let usize price=schedule(body,0,false);
    let programs::Completion short=programs::complete(ref p,ref input,price-1);
    assert(!short.success && short.diagnostic.code.kind==8 && short.remaining==runtime::leave_cost()-1);
    assert(short.diagnostic.code.offset==body.offsets[body.ends[body.entry]-1]);
    successful(ref p,ref input,price,0);successful(ref p,ref input,price+1,1);
}
@test fn void nested_returned_input_calls_match_static_prices_at_exact_fuel(){
    let programs::Program p=kept(b"module lib;fn ref u8[] tail(ref u8[] data){return data[1..];}pub fn ref u8[] pass(ref u8[] data){return tail(ref data);}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){let ref u8[] part=m::pass(ref data);return part[0] as i32;}");
    let inputs::Snapshot input=captured(b"!*");let ref ir::Program body=ref programs::code(ref p).body;
    assert(body.function_count==3);let usize price=schedule(body,0,false);
    let programs::Completion short=programs::complete(ref p,ref input,price-1);
    assert(!short.success && short.diagnostic.code.kind==8 && short.remaining==runtime::leave_cost()-1);
    successful(ref p,ref input,price,0);successful(ref p,ref input,price+7,7);
}
fn void nested_failure(ref u8[] library,ref u8[] needle,u8 terminal,u8 kind){
    let programs::Program p=kept(library,
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){return m::middle(ref data);}");
    let inputs::Snapshot input=captured(b"\x00\x01");let ref ir::Program body=ref programs::code(ref p).body;
    assert(body.function_count==3);let usize charged=schedule(body,terminal,true);
    let programs::Completion v=programs::complete(ref p,ref input,16000000);
    assert(!v.success && v.value==0 && v.remaining==16000000-charged && v.remaining!=0 && v.diagnostic.code.kind==kind);
    let usize at=token(library,needle);
    assert(v.diagnostic.at.source==0 && v.diagnostic.at.start==at && v.diagnostic.at.end==at+1 && v.diagnostic.code.offset==at);
    switch(sources::view(programs::snapshot(ref p),v.diagnostic.at)){
        case .ok(span):{assert(span[0]==needle[0]);}case .err(_):{assert(false);}
    };
    let usize reserve=if(terminal==71){meter::static_instruction(71,0,0)}else if(terminal==76){instruction(76)}else{0};
    let usize required=charged+reserve;
    let programs::Completion exact=programs::complete(ref p,ref input,required);
    assert(!exact.success && exact.diagnostic.code.kind==kind && exact.remaining==reserve && exact.diagnostic.at.start==at);
    let programs::Completion short=programs::complete(ref p,ref input,required-1);
    let usize short_balance=if(terminal==71){reserve-1+meter::input_metadata()}else if(reserve==0){0}else{reserve-1};
    assert(!short.success && short.diagnostic.code.kind==8 && short.remaining==short_balance && short.diagnostic.at.start==at);
    // Each is a separate invocation: legacy API keeps exactly the diagnostic.
    switch(programs::run(ref p,ref input,16000000)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.code.kind==v.diagnostic.code.kind && e.code.offset==v.diagnostic.code.offset && e.at.start==at);}
    };
}
@test fn void nested_division_failure_preserves_all_call_and_prior_read_debits(){
    nested_failure(b"\xEF\xBB\xBFmodule lib;\r\nfn i32 leaf(ref u8[] data){return 42/(data[0] as i32);}pub fn i32 middle(ref u8[] data){return leaf(ref data);}",b"/",5,7);
}
@test fn void nested_read_failure_preserves_metadata_but_not_atomic_read_price(){
    nested_failure(b"\xEF\xBB\xBFmodule lib;\r\nfn i32 leaf(ref u8[] data){return data[2] as i32;}pub fn i32 middle(ref u8[] data){return leaf(ref data);}",b"data[2]",71,14);
}
@test fn void nested_range_failure_preserves_dispatch_without_committing_atomic_range(){
    nested_failure(b"\xEF\xBB\xBFmodule lib;\r\nfn i32 leaf(ref u8[] data){let ref u8[] part=data[2..0];return part[0] as i32;}pub fn i32 middle(ref u8[] data){return leaf(ref data);}",b"[2..0]",76,14);
}

@test fn void call_preflight_commits_only_dispatch_then_input_frame_before_argument_reservation(){
    let programs::Program p=kept(b"module lib;pub fn i32 leaf(ref u8[] data){return data[0] as i32;}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){return m::leaf(ref data);}");
    let inputs::Snapshot input=captured(b"*");let ref ir::Program body=ref programs::code(ref p).body;
    var usize prefix=meter::input_prepare()+runtime::cost()+1;var usize pc=body.starts[body.entry];
    while(pc<body.ends[body.entry]){let u8 op=body.code[pc*8];prefix+=1;if(op==78){break;}prefix+=instruction(op);pc+=1;}
    assert(pc<body.ends[body.entry] && body.code[pc*8]==78);
    let usize threshold=prefix+meter::input_frame()+runtime::cost();
    let programs::Completion short=programs::complete(ref p,ref input,threshold-1);
    assert(!short.success && short.diagnostic.code.kind==8 && short.remaining==meter::input_frame()+runtime::cost()-1);
    let programs::Completion next=programs::complete(ref p,ref input,threshold);
    assert(!next.success && next.diagnostic.code.kind==8 && next.remaining==runtime::cost());
    assert(short.diagnostic.code.offset==body.offsets[pc] && next.diagnostic.code.offset==body.offsets[pc]);
    let usize admitted=threshold+meter::reference_call(1,0)+meter::input_arguments(1)+1;
    let programs::Completion entered=programs::complete(ref p,ref input,admitted);
    assert(!entered.success && entered.diagnostic.code.kind==8 && entered.remaining==0);
    assert(entered.diagnostic.code.offset==body.offsets[body.starts[0]]);
}
