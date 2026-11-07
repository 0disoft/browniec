module tests::m2::module_output_execution;
import module_output_program as programs;
import module_entry as entries;
import module_input_entry as input_entries;
import module_program as ordinary;
import module_input_program as input_programs;
import module_index as modules;
import source_snapshot as sources;
import runtime_input as inputs;
import fuel as meter;
import std::bytes as bytes;

// Fallible fixture construction has no recursive fallback: helper stack use
// cannot turn an admission failure into a misleading native stack overflow.
fn Result<modules::Index,u8> indexed(ref u8[] a,ref u8[] b){
    var sources::Builder scratch=switch(sources::builder(4096,4096)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    if(!sources::add(ref mut scratch,b"library",a).is_ok){return .err(2);}
    if(b.len!=0 && !sources::add(ref mut scratch,b"application",b).is_ok){return .err(3);}
    let sources::Snapshot snapshot=switch(sources::freeze(ref scratch)){
        case .ok(v):{v}case .err(_):{return .err(4);}
    };
    return switch(modules::build(snapshot)){case .ok(v):{.ok(v)}case .err(_):{.err(5)}};
}
fn Result<entries::Entry,u8> entry(ref u8[] a,ref u8[] b){
    return switch(entries::select_i32(indexed(a,b)?,b"app",b"chosen")){
        case .ok(v):{.ok(v)}case .err(_):{.err(6)}
    };
}
fn Result<input_entries::InputEntry,u8> input_entry(ref u8[] a,ref u8[] b){
    return switch(input_entries::select_i32_input(indexed(a,b)?,b"app",b"chosen")){
        case .ok(v):{.ok(v)}case .err(_):{.err(7)}
    };
}
fn Result<programs::Program,u8> kept(ref u8[] a,ref u8[] b){
    return switch(programs::compile(entry(a,b)?,65536)){
        case .ok(v):{.ok(v)}case .err(_):{.err(8)}
    };
}
fn Result<programs::Program,u8> kept_input(ref u8[] a,ref u8[] b){
    return switch(programs::compile_input(input_entry(a,b)?,65536)){
        case .ok(v):{.ok(v)}case .err(_):{.err(9)}
    };
}
fn Result<inputs::Snapshot,u8> captured(ref u8[] data){
    var usize fuel=11;
    return switch(inputs::snapshot(data,inputs::hard_limit(),1,ref mut fuel)){
        case .ok(v):{assert(fuel==10);.ok(v)}case .err(_):{.err(10)}
    };
}
fn void success(ref programs::Execution result,i64 expected,ref u8[] output,usize emits){
    let programs::Completion v=programs::observe(result);
    assert(v.success && v.value==expected && v.diagnostic.code.kind==0);
    assert(v.output_bytes==output.len && v.emits==emits);
    assert(programs::has_output(result));
    assert(bytes::equal(programs::view(result),output));
    // Borrowing the published view is read-only, repeatable and unmetered.
    assert(bytes::equal(programs::view(result),output));
    assert(programs::observe(result).remaining==v.remaining);
}
fn void failed(ref programs::Execution result,u8 kind){
    let programs::Completion v=programs::observe(result);
    assert(!v.success && v.value==0 && v.diagnostic.code.kind==kind);
    assert(v.output_bytes==0 && !programs::has_output(result));
    assert(programs::view(result).len==0 && programs::view(result).len==0);
    assert(programs::observe(result).remaining==v.remaining);
}

@test fn void denied_empty_emit_is_checked_even_with_zero_output_limit(){
    let programs::Program p=switch(kept(b"module app;pub fn i32 chosen(){output::emit(ref b\"\");return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution result=programs::complete(ref p,ref input,16000000,0,false);
    failed(ref result,19);assert(programs::observe(ref result).remaining>0);
}
@test fn void denied_nonempty_emit_cannot_publish_and_program_can_be_reused_with_grant(){
    let programs::Program p=switch(kept(b"module app;pub fn i32 chosen(){output::emit(ref b\"*\");return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution denied=programs::complete(ref p,ref input,16000000,1,false);failed(ref denied,19);
    let programs::Execution granted=programs::complete(ref p,ref input,16000000,1,true);success(ref granted,42,b"*",1);
    failed(ref denied,19);
}
@test fn void no_emit_needs_no_grant_and_success_owns_an_empty_publication(){
    let programs::Program p=switch(kept(b"module app;pub fn i32 chosen(){return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution result=programs::complete(ref p,ref input,16000000,0,false);success(ref result,42,b"",0);
}
@test fn void granted_empty_emit_counts_once_at_zero_limit(){
    let programs::Program p=switch(kept(b"module app;pub fn i32 chosen(){output::emit(ref b\"\");return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution result=programs::complete(ref p,ref input,16000000,0,true);success(ref result,42,b"",1);
}
@test fn void literal_text_ranges_and_returned_helper_bytes_preserve_binary_order(){
    let programs::Program p=switch(kept(
        b"module lib;pub fn ref u8[] tail(ref u8[] data){return data[1..];}pub fn ref u8[] marker(){return b\"\\x00\\xFF\";}",
        b"module app;import lib as m;pub fn i32 chosen(){output::emit(ref b\"A\\x00\");let ref u8[] text=text::bytes(\"BC\");output::emit(ref text[1..]);let ref u8[] part=m::tail(ref b\"!D\");output::emit(ref part);let ref u8[] marker=m::marker();output::emit(ref marker);return 42;}")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution result=programs::complete(ref p,ref input,16000000,6,true);
    success(ref result,42,b"A\x00CD\x00\xFF",4);
}
@test fn void nested_void_calls_and_loops_emit_in_execution_order(){
    let programs::Program p=switch(kept(
        b"module lib;fn void inner(){output::emit(ref b\"B\");}pub fn void outer(){output::emit(ref b\"A\");inner();output::emit(ref b\"C\");}",
        b"module app;import lib as m;pub fn i32 chosen(){var i32 i=0;while(i<2){m::outer();i+=1;}output::emit(ref b\"Z\");return 42;}")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution result=programs::complete(ref p,ref input,16000000,7,true);success(ref result,42,b"ABCABCZ",7);
}
@test fn void input_literal_and_native_array_loans_concatenate_without_origin_confusion(){
    let programs::Program p=switch(kept_input(
        b"module lib;pub fn void send(ref u8[] data){output::emit(ref data);}pub fn ref u8[] tail(ref u8[] data){return data[1..];}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){let u8[3] local=[0,255,33];m::send(ref b\"L\\x00\");let ref u8[] tail=m::tail(ref data);m::send(ref tail);m::send(ref local);output::emit(ref local[1..2]);return 42;}")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"!\x00I")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution result=programs::complete(ref p,ref input,16000000,8,true);
    success(ref result,42,b"L\x00\x00I\x00\xFF!\xFF",4);
    assert(bytes::equal(inputs::view(ref input),b"!\x00I"));
}
@test fn void output_limit_zero_exact_and_one_over_are_atomic_across_multiple_emits(){
    let programs::Program p=switch(kept(b"module app;pub fn i32 chosen(){output::emit(ref b\"A\");output::emit(ref b\"\\x00B\");return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution zero=programs::complete(ref p,ref input,16000000,0,true);failed(ref zero,20);
    let programs::Execution short=programs::complete(ref p,ref input,16000000,2,true);failed(ref short,20);
    let programs::Execution exact=programs::complete(ref p,ref input,16000000,3,true);success(ref exact,42,b"A\x00B",2);
    let programs::Execution extra=programs::complete(ref p,ref input,16000000,4,true);success(ref extra,42,b"A\x00B",2);
    failed(ref short,20);
}
@test fn void division_after_emit_discards_prefix_and_preserves_nonzero_error_balance(){
    let programs::Program p=switch(kept_input(b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"prefix\");return 42/(data[0] as i32);}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"\x00")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution result=programs::complete(ref p,ref input,16000000,6,true);failed(ref result,7);
    assert(programs::observe(ref result).remaining>0 && programs::observe(ref result).remaining<16000000);
    // DIV failure commits dispatch after its argument read, with no successful
    // return or output seal. The observed debit must be the shared VM debit.
    let usize charged=16000000-programs::observe(ref result).remaining;
    let programs::Execution exact=programs::complete(ref p,ref input,charged,6,true);failed(ref exact,7);
    assert(programs::observe(ref exact).remaining==0);
    let programs::Execution extra=programs::complete(ref p,ref input,charged+7,6,true);failed(ref extra,7);
    assert(programs::observe(ref extra).remaining==7);
    let programs::Execution short=programs::complete(ref p,ref input,charged-1,6,true);failed(ref short,8);
}
@test fn void invalid_input_range_after_emit_never_publishes_staged_bytes(){
    let programs::Program p=switch(kept_input(b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref b\"prefix\");output::emit(ref data[2..0]);return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"\x00!")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution result=programs::complete(ref p,ref input,16000000,8,true);failed(ref result,14);
    assert(programs::observe(ref result).remaining>0);
}
@test fn void fuel_exhaustion_after_emit_discards_prefix_without_replay(){
    let programs::Program p=switch(kept(b"module app;pub fn i32 chosen(){output::emit(ref b\"prefix\");var i32 n=0;while(n<1000){n+=1;}return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution full=programs::complete(ref p,ref input,16000000,6,true);success(ref full,42,b"prefix",1);
    let usize price=16000000-programs::observe(ref full).remaining;
    let programs::Execution short=programs::complete(ref p,ref input,price-meter::output_seal()-100,6,true);failed(ref short,8);
    success(ref full,42,b"prefix",1);
}
@test fn void output_seal_is_atomic_at_exact_and_one_less_fuel(){
    let programs::Program p=switch(kept(b"module app;pub fn i32 chosen(){output::emit(ref b\"A\\x00B\");return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution full=programs::complete(ref p,ref input,16000000,3,true);success(ref full,42,b"A\x00B",1);
    let usize price=16000000-programs::observe(ref full).remaining;assert(price>meter::output_seal());
    let programs::Execution before=programs::complete(ref p,ref input,price-meter::output_seal(),3,true);failed(ref before,8);
    assert(programs::observe(ref before).remaining==0);
    let programs::Execution short=programs::complete(ref p,ref input,price-1,3,true);failed(ref short,8);
    assert(programs::observe(ref short).remaining==meter::output_seal()-1);
    let programs::Execution exact=programs::complete(ref p,ref input,price,3,true);success(ref exact,42,b"A\x00B",1);
    assert(programs::observe(ref exact).remaining==0);
    let programs::Execution extra=programs::complete(ref p,ref input,price+1,3,true);success(ref extra,42,b"A\x00B",1);
    assert(programs::observe(ref extra).remaining==1);failed(ref short,8);
}
@test fn void output_schedule_is_explicit_and_capacity_charge_is_shared_with_vm(){
    assert(meter::output_prepare(0)==512 && meter::output_prepare(1)==514 && meter::output_prepare(1048576)==2097664);
    assert(meter::output_emit(0)==512 && meter::output_emit(3)==518 && meter::output_access()==8192 && meter::output_seal()==512);
    let programs::Program p=switch(kept(b"module app;pub fn i32 chosen(){output::emit(ref b\"*\");return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution small=programs::complete(ref p,ref input,16000000,1,true);success(ref small,42,b"*",1);
    let programs::Execution larger=programs::complete(ref p,ref input,16000000,11,true);success(ref larger,42,b"*",1);
    assert(programs::observe(ref small).remaining-programs::observe(ref larger).remaining==20);
    let programs::Execution zero=programs::complete(ref p,ref input,0,1,true);failed(ref zero,8);
    assert(programs::observe(ref zero).remaining==0);
}
@test fn void reused_program_retains_independent_binary_outputs_and_input_snapshots(){
    let programs::Program p=switch(kept_input(b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot a=switch(captured(b"\x00\xFF\x00")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let inputs::Snapshot b=switch(captured(b"B\x00")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution first=programs::complete(ref p,ref a,16000000,3,true);
    let programs::Execution second=programs::complete(ref p,ref b,16000000,2,true);
    let programs::Execution denied=programs::complete(ref p,ref a,16000000,3,false);failed(ref denied,19);
    success(ref first,42,b"\x00\xFF\x00",1);success(ref second,42,b"B\x00",1);
    let programs::Execution again=programs::complete(ref p,ref a,16000000,3,true);success(ref again,42,b"\x00\xFF\x00",1);
    success(ref first,42,b"\x00\xFF\x00",1);success(ref second,42,b"B\x00",1);
}
fn void large_case(ref programs::Program p,usize length){
    var bytes::Buffer data=switch(bytes::with_capacity(length)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(bytes::resize_zeroed(ref mut data,length).is_ok);
    bytes::view_mut(ref mut data)[0]=42;bytes::view_mut(ref mut data)[length-1]=255;
    let inputs::Snapshot input=switch(captured(bytes::view(ref data))){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution result=programs::complete(p,ref input,16000000,length,true);
    success(ref result,42,bytes::view(ref data),1);
    let programs::Execution short=programs::complete(p,ref input,16000000,length-1,true);failed(ref short,20);
    success(ref result,42,bytes::view(ref data),1);
}
@test fn void input_output_lengths_cross_4096_through_one_mib_without_image_growth(){
    let programs::Program p=switch(kept_input(b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    large_case(ref p,4096);large_case(ref p,4097);large_case(ref p,1048576);
}
@test fn void ordinary_output_program_rejects_nonempty_snapshot_before_execution(){
    let programs::Program p=switch(kept(b"module app;pub fn i32 chosen(){output::emit(ref b\"*\");return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let inputs::Snapshot input=switch(captured(b"unexpected")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Execution result=programs::complete(ref p,ref input,16000000,1,true);failed(ref result,5);
}
@test fn void legacy_ordinary_and_input_programs_do_not_gain_output_admission(){
    let entries::Entry plain=switch(entry(b"module app;pub fn i32 chosen(){output::emit(ref b\"*\");return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    assert(!ordinary::compile(plain,65536).is_ok);
    let input_entries::InputEntry input=switch(input_entry(b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 42;}",b"")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    assert(!input_programs::compile(input,65536).is_ok);
}
