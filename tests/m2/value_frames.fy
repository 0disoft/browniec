module tests::m2::value_frames;
import value_frames as frames;
import value_frame_layout as layouts;
import value_frame_meter as meter;
import value_properties as values;
import value_roots as owners;
import buffer_growth as growth;
import scalar_codec as scalar;
import cells as cells;
import value_codec as codec;
import std::bytes as bytes;
import std::vec as vec;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn values::Node node(u8 kind,u8 first,u8 second,usize extent){return values::Node{.kind=kind,.first=first,.second=second,.extent=extent};}
fn layouts::Plan plan(){
    var values::Catalog c=values::empty();c.count=8;
    c.nodes[0]=node(1,1,0,0);c.nodes[1]=node(1,2,0,0);c.nodes[2]=node(1,9,0,0);
    c.nodes[3]=node(2,1,0,2);c.nodes[4]=node(3,0,0,0);c.nodes[5]=node(4,0,0,0);
    c.nodes[6]=node(5,5,0,0);c.nodes[7]=node(6,0,5,0);
    c.records.count=1;c.records.fields[0]=2;c.records.types[0]=2;c.records.types[1]=9;
    let u8[16] types=[1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8];let u8[16] functions=[0;16];
    return switch(layouts::retain(ref c,ref types,ref functions,1)){
        case .ok(v):{v}case .err(_):{assert(false);plan()}
    };
}
fn usize ok(Result<usize,frames::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize measured(Result<usize,meter::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize placed(Result<usize,layouts::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn bool fuel_error(frames::Error error){return switch(error){case .Fuel:{true}case .State:{false}case .Type:{false}case .Bounds:{false}case .Quota:{false}case .Allocation:{false}case .Value:{false}case .Owner:{false}};}
fn bool is_fuel(Result<usize,frames::Error> result){return switch(result){case .ok(_):{false}case .err(e):{fuel_error(e)}};}
fn bool is_type(Result<usize,frames::Error> result){return switch(result){case .ok(_):{false}case .err(e):{switch(e){case .Fuel:{false}case .State:{false}case .Type:{true}case .Bounds:{false}case .Quota:{false}case .Allocation:{false}case .Value:{false}case .Owner:{false}}}};}
fn frames::Case selected(Result<frames::Case,frames::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);frames::Case{.matched=false,.payload=false}}};}
fn i64 read(Result<i64,frames::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn owners::State root_open(ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){
    return switch(owners::open(roots,scratch,limits(),fuel)){
        case .ok(v):{v}case .err(_):{assert(false);root_open(roots,scratch,fuel)}
    };
}
fn frames::State opened(ref layouts::Plan p,ref mut vec::Vec<bytes::Buffer> data,
    ref mut vec::Vec<bytes::Buffer> scratch,ref owners::State roots,ref mut usize fuel){
    return switch(frames::open(p,data,scratch,roots,limits(),fuel)){
        case .ok(v):{v}case .err(_):{assert(false);opened(p,data,scratch,roots,fuel)}
    };
}
fn frames::Token entered(ref layouts::Plan p,ref mut frames::State state,
    ref mut vec::Vec<bytes::Buffer> data,ref owners::State roots,ref mut usize fuel){
    return switch(frames::enter(p,state,data,0,roots,limits(),fuel)){
        case .ok(v):{v}case .err(_):{assert(false);frames::Token{.frame=0,.generation=0}}
    };
}
fn frames::Address at(frames::Token token,usize slot){return frames::Address{.frame=token.frame,.generation=token.generation,.slot=slot};}
fn void content(ref owners::State state,ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> scratch,
    usize serial,usize binding,ref u8[] expected){
    var u8[16] data=[0;16];var usize fuel=1000;
    assert(switch(owners::copy_out(state,roots,scratch,serial,binding,0,ref mut data[..expected.len],ref mut fuel)){
        case .ok(v):{v==expected.len}case .err(_):{false}});
    assert(bytes::equal(ref data[..expected.len],expected));
}
fn void value_bytes(ref layouts::Plan p,ref vec::Vec<bytes::Buffer> data,frames::Address source,ref u8[] expected){
    let usize offset=placed(layouts::offset(p,source.slot));
    let ref u8[] all=bytes::view(vec::at<bytes::Buffer>(data,source.frame));
    assert(bytes::equal(all[offset..offset+expected.len],expected));
}

@test fn void recursive_buffer_moves_preserve_owner_token_charge_data_and_reject_copy_overwrite_double_drop(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> root_scratch=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut root_scratch,ref mut fuel);
    var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token outer=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    let usize serial=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(outer,10),b"keep",ref mut r,ref mut roots,ref mut root_scratch,limits(),ref mut fuel));
    let owners::Row original=r.rows[0];let usize used=r.ledger.used;let usize peak=r.ledger.peak;
    let frames::Token inner=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    assert(is_type(frames::transfer(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,10),at(inner,10),true,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel)));
    assert(ok(frames::transfer(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,10),at(inner,10),false,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==8);
    assert(r.rows[0].serial==serial && r.rows[0].slot==original.slot && r.rows[0].generation==original.generation);
    assert(r.ledger.used==used && r.ledger.peak==peak && vec::len<bytes::Buffer>(ref roots)==1);
    assert(!owners::describe(ref r,ref roots,ref root_scratch,serial,10).is_ok);
    content(ref r,ref roots,ref root_scratch,serial,26,b"keep");let u8[8] zero=[0;8];value_bytes(ref p,ref data,at(outer,10),ref zero);
    assert(!frames::drop(ref p,ref mut s,ref mut data,at(outer,10),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel).is_ok);
    assert(!frames::buffer_value(ref p,ref mut s,ref mut data,at(inner,10),b"overwrite",ref mut r,ref mut roots,ref mut root_scratch,limits(),ref mut fuel).is_ok);
    content(ref r,ref roots,ref root_scratch,serial,26,b"keep");
    assert(ok(frames::transfer(ref p,ref mut s,ref mut data,ref mut scratch,at(inner,10),at(outer,11),false,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==8);
    content(ref r,ref roots,ref root_scratch,serial,11,b"keep");
    let usize left=ok(frames::leave(ref p,ref mut s,ref mut data,inner,ref mut r,ref mut roots,ref mut root_scratch));
    assert(ok(frames::drop(ref p,ref mut s,ref mut data,at(outer,11),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==8);
    assert(!frames::drop(ref p,ref mut s,ref mut data,at(outer,11),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel).is_ok);
    assert(r.ledger.used==owners::metadata_charge() && vec::len<bytes::Buffer>(ref roots)==0);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut root_scratch))==0);
}

@test fn void scalar_array_record_copies_validate_canonical_bytes_and_remain_independent(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> root_scratch=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut root_scratch,ref mut fuel);
    var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token t=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    assert(ok(frames::scalar_value(ref p,ref mut s,ref mut data,at(t,0),-2147483648,ref mut fuel))==4);
    assert(ok(frames::scalar_value(ref p,ref mut s,ref mut data,at(t,4),-9223372036854775808,ref mut fuel))==8);
    assert(!frames::scalar_value(ref p,ref mut s,ref mut data,at(t,2),2,ref mut fuel).is_ok);
    let u8[1] bad_bool=[2];assert(!frames::initialize(ref p,ref mut s,ref mut data,at(t,2),ref bad_bool,ref mut fuel).is_ok);
    assert(ok(frames::scalar_value(ref p,ref mut s,ref mut data,at(t,2),1,ref mut fuel))==1);
    let u8[8] array=[255,255,255,255,42,0,0,0];var u8[16] record=[0;16];record[0]=1;
    assert(scalar::encode(9,-9223372036854775808,ref mut record[8..16]).is_ok);
    assert(!frames::initialize(ref p,ref mut s,ref mut data,at(t,6),ref array[..7],ref mut fuel).is_ok);
    assert(ok(frames::initialize(ref p,ref mut s,ref mut data,at(t,6),ref array,ref mut fuel))==8);
    record[1]=1;assert(!frames::initialize(ref p,ref mut s,ref mut data,at(t,8),ref record,ref mut fuel).is_ok);
    record[1]=0;record[0]=2;assert(!frames::initialize(ref p,ref mut s,ref mut data,at(t,8),ref record,ref mut fuel).is_ok);
    record[0]=1;assert(ok(frames::initialize(ref p,ref mut s,ref mut data,at(t,8),ref record,ref mut fuel))==16);
    let usize[5] sources=[0,2,4,6,8];let usize[5] targets=[1,3,5,7,9];var usize i=0;
    while(i<5){let usize copied=ok(frames::transfer(ref p,ref mut s,ref mut data,ref mut scratch,at(t,sources[i]),at(t,targets[i]),true,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel));i+=1;}
    assert(read(frames::scalar_read(ref p,ref s,ref data,at(t,1),ref mut fuel))==-2147483648);
    assert(read(frames::scalar_read(ref p,ref s,ref data,at(t,3),ref mut fuel))==1);
    assert(read(frames::scalar_read(ref p,ref s,ref data,at(t,5),ref mut fuel))==-9223372036854775808);
    value_bytes(ref p,ref data,at(t,7),ref array);value_bytes(ref p,ref data,at(t,9),ref record);
    // Explicit guest-byte corruption fixture: already copied values stay independent.
    {let ref mut u8[] all=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,t.frame));
        all[placed(layouts::offset(ref p,0))]=9;all[placed(layouts::offset(ref p,6))]=9;all[placed(layouts::offset(ref p,8))]=2;}
    assert(read(frames::scalar_read(ref p,ref s,ref data,at(t,1),ref mut fuel))==-2147483648);
    value_bytes(ref p,ref data,at(t,7),ref array);value_bytes(ref p,ref data,at(t,9),ref record);
    let u8[16] none=[0;16];assert(is_type(frames::initialize(ref p,ref mut s,ref mut data,at(t,12),ref none,ref mut fuel)));
    assert(vec::len<bytes::Buffer>(ref roots)==0);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut root_scratch))==0);
}

@test fn void all_thirty_two_activations_reject_thirty_third_and_reuse_only_with_new_generation(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> root_scratch=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut root_scratch,ref mut fuel);
    var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    var frames::Token[32] tokens=[frames::Token{.frame=0,.generation=0};32];var usize i=0;
    while(i<32){tokens[i]=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);assert(tokens[i].frame==i);i+=1;}
    let usize used=s.used;let usize next=s.next;
    assert(s.depth==32 && vec::len<bytes::Buffer>(ref data)==32);
    assert(!frames::enter(ref p,ref mut s,ref mut data,0,ref r,limits(),ref mut fuel).is_ok);
    assert(s.depth==32 && s.used==used && s.next==next);
    assert(!frames::leave(ref p,ref mut s,ref mut data,tokens[0],ref mut r,ref mut roots,ref mut root_scratch).is_ok);
    let frames::Address stale=at(tokens[31],0);let usize left=ok(frames::leave(ref p,ref mut s,ref mut data,tokens[31],ref mut r,ref mut roots,ref mut root_scratch));
    let frames::Token replacement=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    assert(replacement.frame==31 && replacement.generation>tokens[31].generation && s.used==used);
    assert(!frames::scalar_value(ref p,ref mut s,ref mut data,stale,7,ref mut fuel).is_ok);
    assert(ok(frames::scalar_value(ref p,ref mut s,ref mut data,at(replacement,0),8,ref mut fuel))==4);
    assert(!frames::scalar_read(ref p,ref s,ref data,stale,ref mut fuel).is_ok);
    assert(!frames::leave(ref p,ref mut s,ref mut data,tokens[31],ref mut r,ref mut roots,ref mut root_scratch).is_ok);
    tokens[31]=replacement;fuel=0;i=32;
    while(i>0){i-=1;let usize remaining=ok(frames::leave(ref p,ref mut s,ref mut data,tokens[i],ref mut r,ref mut roots,ref mut root_scratch));}
    assert(s.depth==0 && vec::len<bytes::Buffer>(ref data)==0 && fuel==0 && s.peak==used);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut root_scratch))==0);
}

@test fn void combined_frame_root_quotas_and_exact_fuel_boundaries_do_not_publish_rejected_work(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> root_scratch=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut root_scratch,ref mut fuel);
    let usize setup=measured(meter::setup_cost(layouts::largest(ref p)));fuel=setup-1;
    assert(switch(frames::open(ref p,ref mut data,ref mut scratch,ref r,limits(),ref mut fuel)){
        case .ok(_):{false}case .err(e):{fuel_error(e)}});
    assert(fuel==setup-1 && vec::capacity<bytes::Buffer>(ref data)==0 && vec::len<bytes::Buffer>(ref scratch)==0);
    fuel=setup;var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);assert(fuel==0);
    let usize entry=measured(meter::enter_cost(placed(layouts::width(ref p,0))));fuel=entry-1;
    assert(!frames::enter(ref p,ref mut s,ref mut data,0,ref r,limits(),ref mut fuel).is_ok);
    assert(fuel==entry-1 && s.depth==0);fuel=entry;
    let frames::Token t=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);assert(fuel==0);
    let usize operation=measured(meter::operation_cost(8));fuel=operation-1;
    assert(is_fuel(frames::scalar_value(ref p,ref mut s,ref mut data,at(t,0),42,ref mut fuel)) && fuel==operation-1);
    fuel=operation;assert(ok(frames::scalar_value(ref p,ref mut s,ref mut data,at(t,0),42,ref mut fuel))==4 && fuel==0);
    fuel=operation+1;assert(read(frames::scalar_read(ref p,ref s,ref data,at(t,0),ref mut fuel))==42 && fuel==1);
    let usize creation=switch(owners::create_cost(3)){case .ok(v):{v}case .err(_):{assert(false);0}};
    fuel=operation+creation-1;assert(is_fuel(frames::buffer_value(ref p,ref mut s,ref mut data,at(t,10),b"abc",ref mut r,ref mut roots,ref mut root_scratch,limits(),ref mut fuel)));
    assert(fuel==operation+creation-1 && r.next==1 && vec::len<bytes::Buffer>(ref roots)==0);
    // Growing the empty root prepays both old 64 and replacement 128 charges.
    let usize combined=s.used+r.ledger.used+192;
    let growth::Limits tight_instance=growth::Limits{.object=64,.instance=combined-1,.engine=1048576};
    let growth::Limits tight_engine=growth::Limits{.object=64,.instance=1048576,.engine=combined-1};
    fuel=operation+creation;
    assert(!frames::buffer_value(ref p,ref mut s,ref mut data,at(t,10),b"abc",ref mut r,ref mut roots,ref mut root_scratch,tight_instance,ref mut fuel).is_ok && fuel==0);
    fuel=operation+creation;
    assert(!frames::buffer_value(ref p,ref mut s,ref mut data,at(t,10),b"abc",ref mut r,ref mut roots,ref mut root_scratch,tight_engine,ref mut fuel).is_ok && fuel==0);
    assert(r.next==1 && r.ledger.used==owners::metadata_charge() && vec::len<bytes::Buffer>(ref roots)==0);
    let growth::Limits exact=growth::Limits{.object=64,.instance=combined,.engine=combined};fuel=operation+creation;
    let usize serial=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(t,10),b"abc",ref mut r,ref mut roots,ref mut root_scratch,exact,ref mut fuel));
    assert(fuel==0 && s.used+r.ledger.used==combined-64 && s.used+r.ledger.peak==combined);content(ref r,ref roots,ref root_scratch,serial,10,b"abc");
    fuel=entry+1;assert(!frames::enter(ref p,ref mut s,ref mut data,0,ref r,exact,ref mut fuel).is_ok && fuel==1);
    assert(s.depth==1 && s.used+r.ledger.used==combined-64);
    fuel=operation-1;assert(is_fuel(frames::transfer(ref p,ref mut s,ref mut data,ref mut scratch,at(t,10),at(t,11),false,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel)));
    fuel=operation;assert(ok(frames::transfer(ref p,ref mut s,ref mut data,ref mut scratch,at(t,10),at(t,11),false,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==8 && fuel==0);
    fuel=operation-1;assert(is_fuel(frames::drop(ref p,ref mut s,ref mut data,at(t,11),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel)));
    fuel=operation+1;assert(ok(frames::drop(ref p,ref mut s,ref mut data,at(t,11),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==8 && fuel==1);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut root_scratch))==0);
}

@test fn void inactive_and_active_move_only_tags_refuse_copy_and_consume_matches_with_exact_payload_bindings(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> root_scratch=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut root_scratch,ref mut fuel);
    var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token outer=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    let frames::Token inner=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    let frames::Address ignored=frames::Address{.frame=99,.generation=0,.slot=99};
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,12),ignored,0,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==16);
    assert(is_type(frames::transfer(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,12),at(outer,13),true,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel)));
    let frames::Case miss=selected(frames::case_value(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,12),1,ignored,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel));
    assert(!miss.matched && !miss.payload);
    assert(ok(frames::transfer(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,12),at(outer,13),false,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==16);
    let frames::Case none=selected(frames::case_value(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,13),0,ignored,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel));
    assert(none.matched && !none.payload);
    assert(!frames::case_value(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,13),0,ignored,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel).is_ok);
    let usize serial=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(outer,10),b"tagged",ref mut r,ref mut roots,ref mut root_scratch,limits(),ref mut fuel));
    let owners::Row original=r.rows[0];let usize used=r.ledger.used;let usize peak=r.ledger.peak;
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,12),at(outer,10),1,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==16);
    assert(!owners::describe(ref r,ref roots,ref root_scratch,serial,10).is_ok);content(ref r,ref roots,ref root_scratch,serial,12,b"tagged");
    assert(is_type(frames::transfer(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,12),at(outer,13),true,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel)));
    let frames::Case some=selected(frames::case_value(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,12),1,at(inner,10),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel));
    assert(some.matched && some.payload);content(ref r,ref roots,ref root_scratch,serial,26,b"tagged");
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,14),at(inner,10),0,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==16);
    content(ref r,ref roots,ref root_scratch,serial,14,b"tagged");
    let frames::Case err=selected(frames::case_value(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,14),0,at(outer,11),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel));
    assert(err.matched && err.payload);content(ref r,ref roots,ref root_scratch,serial,11,b"tagged");
    assert(r.rows[0].serial==serial && r.rows[0].slot==original.slot && r.rows[0].generation==original.generation);
    assert(r.ledger.used==used && r.ledger.peak==peak);
    assert(ok(frames::scalar_value(ref p,ref mut s,ref mut data,at(outer,0),42,ref mut fuel))==4);
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,15),at(outer,0),1,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==16);
    assert(read(frames::scalar_read(ref p,ref s,ref data,at(outer,0),ref mut fuel))==42);
    assert(is_type(frames::transfer(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,15),at(outer,14),true,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel)));
    let frames::Case scalar_payload=selected(frames::case_value(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,15),1,at(outer,1),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel));
    assert(scalar_payload.matched && scalar_payload.payload && read(frames::scalar_read(ref p,ref s,ref data,at(outer,1),ref mut fuel))==42);
    assert(!frames::case_value(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,15),1,at(outer,1),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel).is_ok);
    fuel=0;let usize child_left=ok(frames::leave(ref p,ref mut s,ref mut data,inner,ref mut r,ref mut roots,ref mut root_scratch));
    let usize parent_left=ok(frames::leave(ref p,ref mut s,ref mut data,outer,ref mut r,ref mut roots,ref mut root_scratch));
    assert(r.ledger.used==owners::metadata_charge() && vec::len<bytes::Buffer>(ref roots)==0 && fuel==0);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut root_scratch))==0);
}

@test fn void zero_fuel_leave_and_abort_release_native_roots_despite_corrupt_guest_bytes_and_live_masks(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> root_scratch=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut root_scratch,ref mut fuel);
    var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token normal=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    let usize a=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(normal,10),b"normal",ref mut r,ref mut roots,ref mut root_scratch,limits(),ref mut fuel));
    assert(ok(frames::scalar_value(ref p,ref mut s,ref mut data,at(normal,0),3,ref mut fuel))==4);
    let usize b=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(normal,11),b"last",ref mut r,ref mut roots,ref mut root_scratch,limits(),ref mut fuel));
    fuel=0;let usize left=ok(frames::leave(ref p,ref mut s,ref mut data,normal,ref mut r,ref mut roots,ref mut root_scratch));
    assert(fuel==0 && s.depth==0 && r.ledger.used==owners::metadata_charge() && vec::len<bytes::Buffer>(ref roots)==0);
    // A failed leave proves reverse initialization order: newer slot10 drops
    // before corrupt older slot11, rather than merely visiting slot numbers.
    fuel=10000000;let frames::Token ordered=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    let usize old=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(ordered,11),b"old",ref mut r,ref mut roots,ref mut root_scratch,limits(),ref mut fuel));
    let usize recent=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(ordered,10),b"recent",ref mut r,ref mut roots,ref mut root_scratch,limits(),ref mut fuel));
    {let usize offset=placed(layouts::offset(ref p,11));let ref mut u8[] all=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,ordered.frame));
        var usize i=0;while(i<8){all[offset+i]=0;i+=1;}}
    fuel=0;assert(!frames::leave(ref p,ref mut s,ref mut data,ordered,ref mut r,ref mut roots,ref mut root_scratch).is_ok);
    assert(vec::len<bytes::Buffer>(ref roots)==1 && r.rows[0].serial==old);
    assert(!owners::describe(ref r,ref roots,ref root_scratch,recent,10).is_ok);
    // Restore only the fixture's corrupted serial, then finish the partial leave.
    {let usize offset=placed(layouts::offset(ref p,11));let ref mut u8[] all=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,ordered.frame));
        let i64 word=switch(cells::pack(old,0)){case .ok(v):{v}case .err(_):{assert(false);0}};
        assert(scalar::encode(12,word,all[offset..offset+8]).is_ok);}
    let usize ordered_left=ok(frames::leave(ref p,ref mut s,ref mut data,ordered,ref mut r,ref mut roots,ref mut root_scratch));
    fuel=10000000;let frames::Token outer=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    let usize c=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(outer,10),b"outer",ref mut r,ref mut roots,ref mut root_scratch,limits(),ref mut fuel));
    let frames::Token inner=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    let usize d=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(inner,11),b"inner",ref mut r,ref mut roots,ref mut root_scratch,limits(),ref mut fuel));
    // Deliberately corrupt guest serial bytes and native activation masks/orders.
    {let ref mut u8[] all=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,outer.frame));var usize i=0;while(i<all.len){all[i]=255;i+=1;}}
    {let ref mut u8[] all=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,inner.frame));var usize i=0;while(i<all.len){all[i]=0;i+=1;}}
    s.frames[outer.frame].live=0;s.frames[inner.frame].live=65535;s.order=[0;512];fuel=0;
    assert(!frames::leave(ref p,ref mut s,ref mut data,inner,ref mut r,ref mut roots,ref mut root_scratch).is_ok);
    assert(vec::len<bytes::Buffer>(ref roots)==2);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut root_scratch))==0);
    assert(fuel==0 && s.closed && s.depth==0 && s.used==0 && r.closed && r.ledger.used==0 && r.ledger.engine_used==0);
    assert(vec::len<bytes::Buffer>(ref data)==0 && vec::len<bytes::Buffer>(ref scratch)==0);
    assert(vec::len<bytes::Buffer>(ref roots)==0 && vec::len<bytes::Buffer>(ref root_scratch)==0);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut root_scratch))==0);
}

fn layouts::Plan wide_plan(){
    var values::Catalog c=values::empty();c.count=6;
    c.nodes[0]=node(2,9,0,4096);c.nodes[1]=node(4,0,0,0);c.nodes[2]=node(6,0,1,0);
    c.nodes[3]=node(5,2,0,0);c.nodes[4]=node(5,3,0,0);c.nodes[5]=node(5,4,0,0);
    let u8[16] types=[1,1,2,3,4,5,6,6,5,4,3,1,2,0,0,0];let u8[16] functions=[0;16];
    return switch(layouts::retain(ref c,ref types,ref functions,1)){
        case .ok(v):{v}case .err(_):{assert(false);wide_plan()}
    };
}
fn void dirty_scratch(ref mut vec::Vec<bytes::Buffer> scratch){
    let ref mut u8[] raw=bytes::view_mut(vec::at_mut<bytes::Buffer>(scratch,0));var usize i=0;
    while(i<raw.len){raw[i]=173;i+=1;}
}
@test fn void dirty_tag_scratch_preserves_full_small_and_absent_payloads_at_exact_fuel(){
    let layouts::Plan p=wide_plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> root_scratch=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut root_scratch,ref mut fuel);
    var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token t=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    var bytes::Buffer array=switch(bytes::with_capacity(32768)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(bytes::resize_zeroed(ref mut array,32768).is_ok);
    {let ref mut u8[] raw=bytes::view_mut(ref mut array);var usize i=0;var u8 value=3;
        while(i<raw.len){raw[i]=value;if(value==250){value=0;}else{value+=1;}i+=1;}}
    assert(ok(frames::initialize(ref p,ref mut s,ref mut data,at(t,0),bytes::view(ref array),ref mut fuel))==32768);
    dirty_scratch(ref mut scratch);let usize cost=measured(meter::operation_cost(32776));fuel=cost-1;
    assert(is_fuel(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(t,3),at(t,0),1,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel)));
    assert(fuel==cost-1 && s.frames[t.frame].live==1 && s.frames[t.frame].next==2);
    {let ref u8[] raw=bytes::view(vec::at<bytes::Buffer>(ref scratch,0));var usize i=0;while(i<raw.len){assert(raw[i]==173);i+=1;}}
    fuel=cost;assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(t,3),at(t,0),1,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==32776 && fuel==0);
    {let usize offset=placed(layouts::offset(ref p,3));let ref u8[] raw=bytes::view(vec::at<bytes::Buffer>(ref data,t.frame));
        assert(codec::inspect(layouts::layout(ref p),2,raw[offset..offset+32776]).is_ok);
        assert(bytes::equal(raw[offset+8..offset+32776],bytes::view(ref array)));}
    value_bytes(ref p,ref data,at(t,0),bytes::view(ref array));fuel=1000000;
    assert(ok(frames::drop(ref p,ref mut s,ref mut data,at(t,3),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==32776);
    let usize serial=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(t,2),b"live",ref mut r,ref mut roots,ref mut root_scratch,limits(),ref mut fuel));
    let usize used=r.ledger.used;let usize peak=r.ledger.peak;dirty_scratch(ref mut scratch);fuel=cost;
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(t,3),at(t,2),0,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==32776 && fuel==0);
    {let usize offset=placed(layouts::offset(ref p,3));let ref u8[] raw=bytes::view(vec::at<bytes::Buffer>(ref data,t.frame));
        assert(codec::inspect(layouts::layout(ref p),2,raw[offset..offset+32776]).is_ok);assert(raw[offset]==1);
        var usize i=offset+16;while(i<offset+32776){assert(raw[i]==0);i+=1;}}
    assert(r.ledger.used==used && r.ledger.peak==peak);content(ref r,ref roots,ref root_scratch,serial,3,b"live");
    dirty_scratch(ref mut scratch);fuel=measured(meter::operation_cost(32784));
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(t,4),frames::Address{.frame=31,.generation=0,.slot=99},0,
        ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==32784 && fuel==0);
    {let usize offset=placed(layouts::offset(ref p,4));let ref u8[] raw=bytes::view(vec::at<bytes::Buffer>(ref data,t.frame));
        var usize i=offset;while(i<offset+32784){assert(raw[i]==0);i+=1;}}
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut root_scratch))==0);
    assert(r.ledger.used==0 && r.ledger.engine_used==0 && fuel==0);
}
@test fn void maximum_array_and_four_wrappers_preserve_late_bytes_and_sole_active_root(){
    let layouts::Plan p=wide_plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> root_scratch=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut root_scratch,ref mut fuel);
    var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token t=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    var bytes::Buffer array=switch(bytes::with_capacity(32768)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(bytes::resize_zeroed(ref mut array,32768).is_ok);
    {let ref mut u8[] raw=bytes::view_mut(ref mut array);assert(scalar::encode(9,-1,raw[32760..32768]).is_ok);}
    assert(layouts::largest(ref p)==32800);
    assert(ok(frames::initialize(ref p,ref mut s,ref mut data,at(t,0),bytes::view(ref array),ref mut fuel))==32768);
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(t,3),at(t,0),1,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==32776);
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(t,4),at(t,3),1,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==32784);
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(t,5),at(t,4),1,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==32792);
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(t,6),at(t,5),1,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==32800);
    assert(is_type(frames::transfer(ref p,ref mut s,ref mut data,ref mut scratch,at(t,6),at(t,7),true,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel)));
    assert(ok(frames::transfer(ref p,ref mut s,ref mut data,ref mut scratch,at(t,6),at(t,7),false,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==32800);
    let frames::Case a=selected(frames::case_value(ref p,ref mut s,ref mut data,ref mut scratch,at(t,7),1,at(t,8),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel));
    let frames::Case b=selected(frames::case_value(ref p,ref mut s,ref mut data,ref mut scratch,at(t,8),1,at(t,9),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel));
    let frames::Case c=selected(frames::case_value(ref p,ref mut s,ref mut data,ref mut scratch,at(t,9),1,at(t,10),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel));
    let frames::Case d=selected(frames::case_value(ref p,ref mut s,ref mut data,ref mut scratch,at(t,10),1,at(t,11),ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel));
    assert(a.matched && b.matched && c.matched && d.matched && d.payload);
    value_bytes(ref p,ref data,at(t,11),bytes::view(ref array));assert(vec::len<bytes::Buffer>(ref roots)==0);
    let usize serial=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(t,2),b"wide",ref mut r,ref mut roots,ref mut root_scratch,limits(),ref mut fuel));
    let usize used=r.ledger.used;let usize peak=r.ledger.peak;
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(t,3),at(t,2),0,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==32776);
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(t,4),at(t,3),1,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==32784);
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(t,5),at(t,4),1,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==32792);
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(t,6),at(t,5),1,ref mut r,ref mut roots,ref mut root_scratch,ref mut fuel))==32800);
    assert(r.ledger.used==used && r.ledger.peak==peak);content(ref r,ref roots,ref root_scratch,serial,6,b"wide");
    fuel=0;let usize left=ok(frames::leave(ref p,ref mut s,ref mut data,t,ref mut r,ref mut roots,ref mut root_scratch));
    assert(r.ledger.used==owners::metadata_charge() && fuel==0);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut root_scratch))==0);
}
