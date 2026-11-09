module tests::m2::runtime_seal_work;
import runtime_seal_work as work;
import runtime_output as output;
import output_execution as execution;
import metadata_budget as budget;
import fuel as prices;
import errors as errors;
import std::vec as vec;
import std::bytes as bytes;

fn void same(output::Observation a,output::Observation b){
    assert(a.phase==b.phase && a.length==b.length && a.emits==b.emits && a.fuel==b.fuel && a.charged==b.charged);
}
fn Result<output::Transaction,output::Error> filled(usize length,bool allowed,ref mut usize fuel){
    var output::Transaction t=output::open_metered(length,allowed,fuel)?;
    var u8[4096] chunk=[0;4096];var usize i=0;var u8 digit=0;
    while(i<4096){chunk[i]=digit;if(digit==255){digit=0;}else{digit+=1;}i+=1;}
    var usize at=0;while(at<length){let usize left=length-at;let usize count=if(left<4096){left}else{4096};
        let usize emitted=output::emit_metered(ref mut t,ref chunk[..count],fuel)?;at+=count;assert(emitted==at);}
    return .ok(t);
}
fn vec::Vec<output::Published> publication(){
    var vec::Vec<output::Published> slot=vec::empty<output::Published>();
    assert(vec::reserve<output::Published>(ref mut slot,1).is_ok);return slot;
}
fn Result<usize,errors::Error> probe_room(ref mut output::Transaction t,
    ref mut vec::Vec<output::Published> slot,ref mut usize remaining,ref mut budget::State allowance){
    let output::Observation before=output::observe(t);let usize fuel=*remaining;
    let usize retained=output::transaction_heap_bytes(t);let usize pending=output::emit_remaining(t);
    let usize length=vec::len<output::Published>(slot);let usize capacity=vec::capacity<output::Published>(slot);
    let usize fresh=budget::reset(allowance,0)?;assert(fresh==4096);
    let usize total=allowance.total;let usize stages=allowance.stages;
    let bool admitted=budget::admit(allowance,1,0)?;assert(admitted);
    let bool done=work::advance(t,slot,remaining,allowance)?;
    assert(!done && *remaining==fuel && allowance.last==1 && allowance.total==total+1 && allowance.stages==stages+1);
    same(before,output::observe(t));assert(output::transaction_heap_bytes(t)==retained && output::emit_remaining(t)==pending);
    assert(vec::len<output::Published>(slot)==length && vec::capacity<output::Published>(slot)==capacity);
    return .ok(total+1);
}
fn Result<usize,output::Error> success_parity(usize length,bool allowed,bool exact){
    var usize raw_fuel=16000000;var usize staged_fuel=16000000;
    var output::Transaction raw=filled(length,allowed,ref mut raw_fuel)?;
    var output::Transaction staged=filled(length,allowed,ref mut staged_fuel)?;
    if(exact){raw_fuel=prices::output_seal();staged_fuel=raw_fuel;}
    let output::Observation initial=output::observe(ref staged);same(initial,output::observe(ref raw));
    let usize heap=output::transaction_heap_bytes(ref staged);
    var vec::Vec<output::Published> slot=publication();let usize capacity=vec::capacity<output::Published>(ref slot);
    var budget::State allowance=budget::empty();assert(probe_room(ref mut staged,ref mut slot,ref mut staged_fuel,ref mut allowance).is_ok);
    let output::Published expected=output::seal_metered(ref mut raw,ref mut raw_fuel)?;
    assert(budget::reset(ref mut allowance,0).is_ok);let usize total=allowance.total;let usize stages=allowance.stages;
    let bool done=switch(work::advance(ref mut staged,ref mut slot,ref mut staged_fuel,ref mut allowance)){
        case .ok(v):{v}case .err(_):{assert(false);false}};
    assert(done && allowance.last==4096 && allowance.total==total+4096 && allowance.stages==stages+1);
    assert(raw_fuel==staged_fuel && vec::len<output::Published>(ref slot)==1 && vec::capacity<output::Published>(ref slot)==capacity);
    {
        let ref output::Published actual=vec::at<output::Published>(ref slot,0);
        same(output::published_observation(ref expected),output::published_observation(actual));
        same(output::observe(ref raw),output::observe(ref staged));same(output::observe(ref staged),output::published_observation(actual));
        assert(bytes::equal(output::view(ref expected),output::view(actual)) && output::view(actual).len==length);
        assert(output::transaction_heap_bytes(ref staged)+output::published_heap_bytes(actual)==heap);
        let ref u8[] data=output::view(actual);var usize i=0;var u8 digit=0;
        while(i<data.len){assert(data[i]==digit);if(digit==255){digit=0;}else{digit+=1;}i+=1;}
    }
    // A second terminal attempt must preserve the first Published owner and
    // terminal observation even after the caller changes its external Fuel.
    let output::Observation sealed=output::observe(ref staged);raw_fuel=9999;staged_fuel=9999;
    switch(output::seal_metered(ref mut raw,ref mut raw_fuel)){
        case .ok(_):{assert(false);}case .err(e):{assert(execution::failure(e,0).kind==5);}};
    assert(budget::reset(ref mut allowance,0).is_ok);
    switch(work::advance(ref mut staged,ref mut slot,ref mut staged_fuel,ref mut allowance)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==0);}};
    same(sealed,output::observe(ref staged));assert(raw_fuel==9999 && staged_fuel==9999 && vec::len<output::Published>(ref slot)==1);
    let ref output::Published kept=vec::at<output::Published>(ref slot,0);same(sealed,output::published_observation(kept));
    assert(bytes::equal(output::view(ref expected),output::view(kept)));return .ok(length);
}
// Invalid raw states: disabled, legacy/unreserved, failed, cancelled, and an
// unfinished metered emit. None may yield a Published owner on a full stage.
fn Result<output::Transaction,output::Error> invalid_transaction(usize mode,ref mut usize fuel){
    if(mode==0){return .ok(output::disabled());}
    if(mode==1){return output::open(8,true,77);}
    if(mode==4){
        var output::Transaction pending=output::open_metered(8,true,fuel)?;
        let usize total=output::begin_emit_metered(ref mut pending,2,fuel)?;assert(total==2);
        let bool done=output::append_emit_chunk(ref mut pending,b"x")?;assert(!done);return .ok(pending);
    }
    var output::Transaction t=filled(8,true,fuel)?;
    if(mode==2){discard output::fail(ref mut t);}
    if(mode==3){discard output::cancel(ref mut t);}
    return .ok(t);
}
fn Result<usize,output::Error> invalid_parity(usize mode){
    var usize raw_fuel=1000000;var usize staged_fuel=1000000;
    var output::Transaction raw=invalid_transaction(mode,ref mut raw_fuel)?;
    var output::Transaction staged=invalid_transaction(mode,ref mut staged_fuel)?;
    let output::Observation before=output::observe(ref staged);same(before,output::observe(ref raw));
    var vec::Vec<output::Published> slot=publication();let usize capacity=vec::capacity<output::Published>(ref slot);
    var budget::State allowance=budget::empty();assert(probe_room(ref mut staged,ref mut slot,ref mut staged_fuel,ref mut allowance).is_ok);
    var u8 error=0;switch(output::seal_metered(ref mut raw,ref mut raw_fuel)){
        case .ok(_):{assert(false);}case .err(e):{error=execution::failure(e,0).kind;}};
    assert(error==5);assert(budget::reset(ref mut allowance,0).is_ok);
    switch(work::advance(ref mut staged,ref mut slot,ref mut staged_fuel,ref mut allowance)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==error && e.offset==0);}};
    assert(raw_fuel==staged_fuel && allowance.last==4096 && vec::len<output::Published>(ref slot)==0 && vec::capacity<output::Published>(ref slot)==capacity);
    same(before,output::observe(ref staged));same(output::observe(ref raw),output::observe(ref staged));
    assert(output::emit_remaining(ref raw)==output::emit_remaining(ref staged));
    return .ok(mode);
}
fn Result<usize,output::Error> short_fuel_parity(){
    var usize a=1000000;var usize b=1000000;
    var output::Transaction raw=filled(7,true,ref mut a)?;var output::Transaction staged=filled(7,true,ref mut b)?;
    let usize charged=output::observe(ref staged).charged;a=prices::output_seal()-1;b=a;
    var vec::Vec<output::Published> slot=publication();var budget::State allowance=budget::empty();
    assert(probe_room(ref mut staged,ref mut slot,ref mut b,ref mut allowance).is_ok);
    switch(output::seal_metered(ref mut raw,ref mut a)){
        case .ok(_):{assert(false);}case .err(e):{assert(execution::failure(e,0).kind==8);}};
    assert(budget::reset(ref mut allowance,0).is_ok);
    switch(work::advance(ref mut staged,ref mut slot,ref mut b,ref mut allowance)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8 && e.offset==0);}};
    assert(a==prices::output_seal()-1 && a==b && vec::len<output::Published>(ref slot)==0 && allowance.last==4096);
    let output::Observation sampled=output::observe(ref staged);same(sampled,output::observe(ref raw));
    assert(sampled.phase==0 && sampled.fuel==b && sampled.length==7 && sampled.charged==charged);
    // Retry is an explicitly authorized fresh stage after the caller restores
    // Fuel; the failed attempt never consumed the reserved backing or slot.
    a=prices::output_seal();b=a;let output::Published expected=output::seal_metered(ref mut raw,ref mut a)?;
    assert(budget::reset(ref mut allowance,0).is_ok);
    let bool done=switch(work::advance(ref mut staged,ref mut slot,ref mut b,ref mut allowance)){
        case .ok(v):{v}case .err(_):{assert(false);false}};assert(done && a==0 && b==0);
    let ref output::Published actual=vec::at<output::Published>(ref slot,0);
    same(output::published_observation(ref expected),output::published_observation(actual));assert(bytes::equal(output::view(ref expected),output::view(actual)));
    return .ok(charged);
}
@test fn void empty_denied_and_binary_boundary_outputs_match_raw_seal_and_double_seal(){
    assert(success_parity(0,false,true).is_ok);assert(success_parity(7,true,true).is_ok);
    assert(success_parity(8193,true,false).is_ok);
}
@test fn void maximum_reserved_output_moves_without_capacity_growth_or_byte_changes(){
    assert(success_parity(output::hard_limit(),true,false).is_ok);
}
@test fn void one_less_fuel_keeps_raw_sampling_and_can_seal_on_fresh_exact_fuel(){assert(short_fuel_parity().is_ok);}
@test fn void invalid_states_defer_unchanged_then_match_raw_terminal_errors(){
    var usize mode=0;while(mode<5){assert(invalid_parity(mode).is_ok);mode+=1;}
}
@test fn void missing_publication_capacity_and_invalid_budget_never_consume_transaction(){
    var usize fuel=1000000;var output::Transaction t=switch(filled(7,true,ref mut fuel)){
        case .ok(v):{v}case .err(_):{assert(false);output::disabled()}};
    let output::Observation before=output::observe(ref t);let usize balance=fuel;
    var vec::Vec<output::Published> missing=vec::empty<output::Published>();var budget::State allowance=budget::empty();
    assert(probe_room(ref mut t,ref mut missing,ref mut fuel,ref mut allowance).is_ok);
    assert(budget::reset(ref mut allowance,0).is_ok);
    switch(work::advance(ref mut t,ref mut missing,ref mut fuel,ref mut allowance)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==0);}};
    assert(fuel==balance && vec::len<output::Published>(ref missing)==0 && vec::capacity<output::Published>(ref missing)==0);same(before,output::observe(ref t));
    var vec::Vec<output::Published> slot=publication();allowance=budget::State{.total=18446744073709551615,.last=0,.stages=0};
    switch(work::advance(ref mut t,ref mut slot,ref mut fuel,ref mut allowance)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==0);}};
    assert(fuel==balance && allowance.total==18446744073709551615 && allowance.last==0 && allowance.stages==0 && vec::len<output::Published>(ref slot)==0);
    same(before,output::observe(ref t));
}
