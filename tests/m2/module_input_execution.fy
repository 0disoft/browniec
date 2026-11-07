module tests::m2::module_input_execution;
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
fn bytes::Buffer backing(usize length){
    var bytes::Buffer b=switch(bytes::with_capacity(length)){
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    assert(bytes::resize_zeroed(ref mut b,length).is_ok);return b;
}
fn inputs::Snapshot captured(ref u8[] data){
    var usize fuel=11;
    return switch(inputs::snapshot(data,inputs::hard_limit(),1,ref mut fuel)){
        case .ok(v):{assert(fuel==10);v}case .err(_):{assert(false);captured(b"")}
    };
}
fn void value(ref programs::Program p,ref inputs::Snapshot input,i64 expected){
    switch(programs::run(p,input,16000000)){
        case .ok(v):{assert(v.value==expected && v.remaining<16000000);}case .err(_):{assert(false);}
    };
}
fn void length_case(ref programs::Program p,usize length,i64 expected){
    var bytes::Buffer data=backing(length);
    if(length!=0){bytes::view_mut(ref mut data)[length-1]=255;}
    let inputs::Snapshot input=captured(bytes::view(ref data));
    value(p,ref input,expected);assert(inputs::observe(ref input).length==length);
}

@test fn void input_lengths_and_last_bytes_cross_image_limit_through_one_program(){
    let programs::Program p=kept(b"module lib;pub fn i32 unused(){return 9;}",
        b"module app;pub fn i32 chosen(ref u8[] data){if(data.len==0){return 0;}if(data.len==4096){return 1+data[data.len-1] as i32;}if(data.len==4097){return 2+data[data.len-1] as i32;}if(data.len==1048576){return 3+data[data.len-1] as i32;}return -1;}");
    assert(programs::code(ref p).body.entry==1);
    length_case(ref p,0,0);length_case(ref p,4096,256);
    length_case(ref p,4097,257);length_case(ref p,1048576,258);
}
@test fn void hard_limit_plus_one_snapshot_rejects_without_charge_or_partial_input(){
    assert(inputs::hard_limit()==1048576);
    let bytes::Buffer data=backing(1048577);var usize fuel=11;
    switch(inputs::snapshot(bytes::view(ref data),inputs::hard_limit(),1,ref mut fuel)){
        case .ok(_):{assert(false);}case .err(e):{switch(e){
            case .Limit:{}case .Fuel:{assert(false);}case .Allocation:{assert(false);}case .Bounds:{assert(false);}
        };}
    };
    assert(fuel==11 && bytes::len(ref data)==1048577);
    let inputs::Snapshot empty=captured(b"");assert(inputs::observe(ref empty).length==0);
}
@test fn void nested_ranges_cross_4096_and_empty_ranges_at_end_remain_valid(){
    let programs::Program p=kept(b"module lib;pub fn ref u8[] cross(ref u8[] data){let ref u8[] outer=data[4094..4098];return outer[1..3];}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){let ref u8[] part=m::cross(ref data);let ref u8[] end=data[data.len..];let ref u8[] empty=end[0..0];if(part.len==2 && empty.len==0){return part[0] as i32+part[1] as i32;}return 0;}");
    var bytes::Buffer data=backing(4098);
    bytes::view_mut(ref mut data)[4095]=20;bytes::view_mut(ref mut data)[4096]=22;
    let inputs::Snapshot input=captured(bytes::view(ref data));value(ref p,ref input,42);
}
@test fn void returned_second_formal_subrange_keeps_input_origin_through_another_call(){
    let programs::Program p=kept(b"module lib;fn ref u8[] pick(ref u8[] marker,ref u8[] data){return data[4095..];}pub fn ref u8[] tail(ref u8[] data){return pick(ref b\"!\",ref data);}pub fn i32 first(ref u8[] data){return data[0] as i32;}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){let ref u8[] part=m::tail(ref data);return m::first(ref part);}");
    var bytes::Buffer data=backing(4097);bytes::view_mut(ref mut data)[4095]=42;
    let inputs::Snapshot input=captured(bytes::view(ref data));value(ref p,ref input,42);
}
fn void empty_view(owners::View v){
    assert(v.root.slot==16 && v.root.generation==0 && v.element==0 && v.length==0 && v.start==0 && v.end==0);
}
fn void empty_ticket(slices::Ticket v){assert(v.slot==16 && v.generation==0);}
fn void untouched_empty_native(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0);
    assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0 && state.runtime.owners.arena.limit==0);
    var usize i=0;while(i<16){
        let slot=state.runtime.pool.slots[i];empty_view(slot.view);
        assert(slot.generation==1 && !slot.live && !slot.exclusive);
        assert(slot.lease.root.slot==16 && slot.lease.root.generation==0 && slot.lease.generation==0);
        let owner=state.runtime.owners.slots[i];
        assert(owner.generation==1 && owner.read_generation==1 && !owner.occupied && !owner.live && !owner.reading && !owner.writing);
        assert(owner.mark==0 && owner.base==0 && owner.end==0 && owner.element==0 && owner.length==0 && owner.record==0 && owner.alignment==0);
        assert(state.runtime.owners.order[i]==0);i+=1;
    }
    i=0;while(i<31){
        assert(state.runtime.authority.counts[i]==0 && state.runtime.authority.reserves[i]==0);
        assert(state.runtime.authority.kinds[i]==0 && state.runtime.authority.frames[i]==0);
        let child=state.runtime.authority.children[i];empty_view(child.parent.view);empty_view(child.selected);empty_ticket(child.issued);
        assert(child.parent.generation==0 && child.depth==0 && !child.active);i+=1;
    }
    i=0;while(i<248){
        empty_ticket(state.runtime.authority.tickets[i]);empty_view(state.runtime.authority.leases[i].view);
        assert(state.runtime.authority.leases[i].generation==0);i+=1;
    }
}
fn void invalid_before_native(ref programs::Program p,ref candidates::Program code,ref inputs::Snapshot input){
    var runtime::State state=runtime::empty(0);var bytes::Buffer array_data=bytes::empty();
    untouched_empty_native(ref state);
    switch(execution::execute_input_scalar(code,programs::literals(p),inputs::view(input),
        ref mut state,bytes::view_mut(ref mut array_data),16000000)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}
    };
    untouched_empty_native(ref state);assert(bytes::len(ref array_data)==0 && bytes::capacity(ref array_data)==0);
}
@test fn void overlapping_input_actuals_preserve_second_origin_and_reject_mutations_before_native_entry(){
    let programs::Program p=kept(b"module lib;pub fn ref u8[] second(ref u8[] first,ref u8[] second){return second[1..];}pub fn i32 read(ref u8[] data){return data[0] as i32;}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){let ref u8[] first=data[4094..4098];let ref u8[] second=data[4095..4099];let ref u8[] selected=m::second(ref first,ref second);if(selected.len!=3){return -1;}return m::read(ref selected);}");
    var bytes::Buffer data=backing(4099);bytes::view_mut(ref mut data)[4095]=11;bytes::view_mut(ref mut data)[4096]=42;
    let inputs::Snapshot input=captured(bytes::view(ref data));value(ref p,ref input,42);
    var candidates::Program candidate=*programs::code(ref p);
    assert(candidate.body.arities[0]==2 && candidate.results[0]==3 && candidate.origins[0]==2);
    // Both claims name real shared formals, so recipe proof must distinguish
    // their overlapping windows instead of trusting the common input backing.
    candidate.origins[0]=1;invalid_before_native(ref p,ref candidate,ref input);
    candidate=*programs::code(ref p);let usize second=candidate.body.register_starts[0]+1;candidate.parameters[second]=0;
    invalid_before_native(ref p,ref candidate,ref input);value(ref p,ref input,42);
}
@test fn void literal_array_borrow_and_large_input_actuals_keep_distinct_roots(){
    let programs::Program p=kept(b"module lib;pub fn i32 mix(ref u8[] literal,ref u8[] local,ref u8[] data){return literal[0] as i32+local[0] as i32+data[4096] as i32;}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){let u8[1] local=[11];return m::mix(ref b\"\\x09\",ref local,ref data);}");
    var bytes::Buffer data=backing(4097);bytes::view_mut(ref mut data)[4096]=22;
    let inputs::Snapshot input=captured(bytes::view(ref data));value(ref p,ref input,42);
}
fn inputs::Snapshot detached_binary(){
    var bytes::Buffer data=backing(3);bytes::view_mut(ref mut data)[1]=255;
    let inputs::Snapshot input=captured(bytes::view(ref data));
    bytes::view_mut(ref mut data)[1]=1;assert(bytes::resize_zeroed(ref mut data,0).is_ok);
    return input;
}
@test fn void reused_program_observes_independent_snapshots_with_binary_nuls(){
    let programs::Program p=kept(b"module app;pub fn i32 chosen(ref u8[] data){if(data.len!=3){return -1;}return 3+data[0] as i32+data[1] as i32+data[data.len-1] as i32;}",b"");
    let inputs::Snapshot a=detached_binary();let inputs::Snapshot b=captured(b"*\x00\x01");
    value(ref p,ref a,258);value(ref p,ref b,46);value(ref p,ref a,258);
    assert(bytes::equal(inputs::view(ref a),b"\x00\xFF\x00"));
    assert(bytes::equal(inputs::view(ref b),b"*\x00\x01"));
    assert(inputs::observe(ref a).charged==1 && inputs::observe(ref b).charged==1);
}
fn void failure(ref programs::Program p,ref inputs::Snapshot input,u8 kind,usize owner,ref u8[] token,usize expected_offset){
    switch(programs::run(p,input,16000000)){
        case .ok(_):{assert(false);}case .err(e):{
            assert(e.code.kind==kind && e.at.source==owner && e.at.start==expected_offset && e.at.end==expected_offset+1);
            var usize base=0;var usize i=0;while(i<owner){
                switch(sources::whole(programs::snapshot(p),i)){case .ok(v):{base+=v.end;}case .err(_):{assert(false);}};
                i+=1;
            }assert(e.code.offset==base+expected_offset);
            switch(sources::view(programs::snapshot(p),e.at)){
                case .ok(v):{assert(bytes::equal(v,token));}case .err(_):{assert(false);}
            };
            switch(sources::name(programs::snapshot(p),owner)){
                case .ok(v):{assert(bytes::equal(v,if(owner==0){b"library"}else{b"application"}));}
                case .err(_):{assert(false);}
            };
        }
    };
}
fn void bounds_failure(){
    let programs::Program p=kept(b"\xEF\xBB\xBFmodule lib;\r\npub fn i32 at(ref u8[] data){return data[4096] as i32;}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){return m::at(ref data);}");
    let inputs::Snapshot short=captured(b"\x00");failure(ref p,ref short,14,0,b"d",52);
    var bytes::Buffer data=backing(4097);bytes::view_mut(ref mut data)[4096]=42;
    let inputs::Snapshot full=captured(bytes::view(ref data));value(ref p,ref full,42);
    failure(ref p,ref short,14,0,b"d",52);
}
fn void division_failure(){
    let programs::Program p=kept(b"module lib;pub fn i32 divisor(ref u8[] data){return data[0] as i32;}",
        b"\xEF\xBB\xBFmodule app;\r\nimport lib as m;pub fn i32 chosen(ref u8[] data){return 42/m::divisor(ref data);}");
    let inputs::Snapshot zero=captured(b"\x00");failure(ref p,ref zero,7,1,b"/",74);
    let inputs::Snapshot one=captured(b"\x01");value(ref p,ref one,42);
    failure(ref p,ref zero,7,1,b"/",74);
}
@test fn void runtime_bounds_and_division_errors_use_original_source_local_spans(){
    bounds_failure();division_failure();
}
fn void range_failure(ref u8[] source,usize expected_offset){
    let programs::Program p=kept(source,b"");let inputs::Snapshot input=captured(b"\x00\x01");
    failure(ref p,ref input,14,0,b"[",expected_offset);
}
@test fn void reversed_and_maximum_input_range_endpoints_report_runtime_bounds(){
    range_failure(b"module app;pub fn i32 chosen(ref u8[] data){let ref u8[] part=data[data.len..0];if(part.len==0){return 42;}return 0;}",66);
    range_failure(b"module app;pub fn i32 chosen(ref u8[] data){let usize end=18446744073709551615;let ref u8[] part=data[..end];if(part.len==0){return 42;}return 0;}",101);
}
fn void fuel_failure(ref programs::Program p,ref inputs::Snapshot input,usize fuel){
    switch(programs::run(p,input,fuel)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.code.kind==8);}
    };
}
fn void exact(ref programs::Program p,ref inputs::Snapshot input,usize fuel,usize remaining){
    switch(programs::run(p,input,fuel)){
        case .ok(v):{assert(v.value==42 && v.remaining==remaining);}case .err(_):{assert(false);}
    };
}
@test fn void zero_and_tight_fuel_abort_returned_input_and_array_borrows_cleanly(){
    let programs::Program p=kept(b"module lib;pub fn ref u8[] tail(ref u8[] data){return data[4096..];}",
        b"module app;import lib as m;pub fn i32 chosen(ref u8[] data){let u8[1] local=[20];let ref u8[] part=m::tail(ref data);return part[0] as i32+local[0] as i32;}");
    var bytes::Buffer data=backing(4097);bytes::view_mut(ref mut data)[4096]=22;
    let inputs::Snapshot input=captured(bytes::view(ref data));
    let usize price=switch(programs::run(ref p,ref input,16000000)){
        case .ok(v):{assert(v.value==42 && v.remaining<16000000);16000000-v.remaining}
        case .err(_):{assert(false);0}
    };
    assert(price>1);fuel_failure(ref p,ref input,0);fuel_failure(ref p,ref input,1);
    fuel_failure(ref p,ref input,price/2);fuel_failure(ref p,ref input,price-1);
    exact(ref p,ref input,price,0);exact(ref p,ref input,price+1,1);
    assert(inputs::observe(ref input).length==4097 && inputs::view(ref input)[4096]==22);
}
