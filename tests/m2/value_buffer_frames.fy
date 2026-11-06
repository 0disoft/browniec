module tests::m2::value_buffer_frames;
import value_frames as frames;
import value_frame_layout as layouts;
import value_frame_meter as meter;
import value_properties as values;
import value_roots as owners;
import buffer_growth as growth;
import scalar_codec as scalar;
import cells as cells;
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


fn u8 byte(Result<u8,frames::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 code(frames::Error e){return switch(e){case .Fuel:{1}case .State:{2}case .Type:{3}case .Bounds:{4}case .Quota:{5}case .Allocation:{6}case .Value:{7}case .Owner:{8}};}
fn void error(Result<usize,frames::Error> r,u8 expected){assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});}
fn void unchanged(ref frames::State s,ref frames::State before){
    assert(s.depth==before.depth && s.next==before.next && s.used==before.used && s.peak==before.peak && s.closed==before.closed);
    var usize i=0;while(i<32){let frames::Frame a=s.frames[i];let frames::Frame b=before.frames[i];
        assert(a.function==b.function && a.generation==b.generation && a.live==b.live && a.next==b.next && a.charge==b.charge);i+=1;}
    i=0;while(i<512){assert(s.order[i]==before.order[i]);i+=1;}
}

@test fn void addressed_byte_operations_preserve_frame_words_and_initialization_order(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> rs=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut rs,ref mut fuel);
    var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token t=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);let frames::Address a=at(t,10);
    let usize serial=ok(frames::buffer_value(ref p,ref mut s,ref mut data,a,b"abcd",ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel));
    assert(serial==1);let u8[8] word=[1,0,0,0,0,0,0,0];let frames::State before=s;let usize generation=r.rows[0].generation;
    fuel=2336;assert(ok(frames::buffer_len(ref p,ref s,ref data,a,ref r,ref roots,ref rs,ref mut fuel))==4 && fuel==0);
    fuel=2337;assert(byte(frames::buffer_read(ref p,ref s,ref data,a,3,ref r,ref roots,ref rs,ref mut fuel))==100 && fuel==0);
    fuel=2337;assert(ok(frames::buffer_write(ref p,ref s,ref data,a,1,88,ref r,ref mut roots,ref mut rs,limits(),ref mut fuel))==1 && fuel==0);
    assert(r.rows[0].generation==generation);fuel=4144;
    assert(ok(frames::buffer_reserve(ref p,ref s,ref data,a,128,ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel))==128 && fuel==0);
    fuel=4152;assert(ok(frames::buffer_append(ref p,ref s,ref data,a,b"EF",ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel))==6 && fuel==0);
    fuel=4156;assert(ok(frames::buffer_push(ref p,ref s,ref data,a,33,ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel))==7 && fuel==0);
    assert(r.rows[0].generation==generation+3 && r.rows[0].serial==serial && r.rows[0].binding==10);
    unchanged(ref s,ref before);value_bytes(ref p,ref data,a,ref word);content(ref r,ref roots,ref rs,serial,10,b"aXcdEF!");
    assert(ok(frames::leave(ref p,ref mut s,ref mut data,t,ref mut r,ref mut roots,ref mut rs))==before.used-before.frames[t.frame].charge);
    assert(r.ledger.used==owners::metadata_charge() && vec::len<bytes::Buffer>(ref roots)==0);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut rs))==0);
}

@test fn void move_tag_payload_and_cross_activation_keep_serial_but_reject_stale_addresses(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> rs=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut rs,ref mut fuel);
    var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token outer=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);let frames::Address old=at(outer,10);
    let usize serial=ok(frames::buffer_value(ref p,ref mut s,ref mut data,old,b"move",ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel));
    let usize generation=r.rows[0].generation;
    assert(ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,12),old,1,ref mut r,ref mut roots,ref mut rs,ref mut fuel))==16);
    error(frames::buffer_len(ref p,ref s,ref data,old,ref r,ref roots,ref rs,ref mut fuel),2);
    error(frames::buffer_len(ref p,ref s,ref data,at(outer,12),ref r,ref roots,ref rs,ref mut fuel),3);
    let frames::Token inner=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);let frames::Address inside=at(inner,10);
    let frames::Case matched=selected(frames::case_value(ref p,ref mut s,ref mut data,ref mut scratch,at(outer,12),1,inside,ref mut r,ref mut roots,ref mut rs,ref mut fuel));
    assert(matched.matched && matched.payload && r.rows[0].binding==26 && r.rows[0].generation==generation);
    assert(ok(frames::buffer_push(ref p,ref s,ref data,inside,33,ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel))==5);
    assert(ok(frames::transfer(ref p,ref mut s,ref mut data,ref mut scratch,inside,at(outer,11),false,ref mut r,ref mut roots,ref mut rs,ref mut fuel))==8);
    assert(ok(frames::leave(ref p,ref mut s,ref mut data,inner,ref mut r,ref mut roots,ref mut rs))>0);
    let frames::Token again=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    assert(again.frame==inner.frame && again.generation!=inner.generation);
    error(frames::buffer_len(ref p,ref s,ref data,inside,ref r,ref roots,ref rs,ref mut fuel),2);
    error(frames::buffer_len(ref p,ref s,ref data,old,ref r,ref roots,ref rs,ref mut fuel),2);
    assert(r.rows[0].serial==serial && r.rows[0].binding==11 && r.rows[0].generation==generation+1);
    content(ref r,ref roots,ref rs,serial,11,b"move!");
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut rs))==0);
    assert(r.closed && s.closed && r.ledger.used==0 && vec::len<bytes::Buffer>(ref roots)==0);
}

@test fn void fuel_authentication_and_combined_quotas_reject_before_mutation_and_abort_frees(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> rs=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut rs,ref mut fuel);
    var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token t=entered(ref p,ref mut s,ref mut data,ref r,ref mut fuel);let frames::Address a=at(t,10);
    let usize serial=ok(frames::buffer_value(ref p,ref mut s,ref mut data,a,b"safe",ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel));
    assert(ok(frames::scalar_value(ref p,ref mut s,ref mut data,at(t,0),42,ref mut fuel))==4);
    let frames::State before=s;let usize used=r.ledger.used;let usize peak=r.ledger.peak;let usize generation=r.rows[0].generation;
    fuel=2079;error(frames::buffer_len(ref p,ref s,ref data,a,ref r,ref roots,ref rs,ref mut fuel),1);assert(fuel==2079);
    fuel=2335;error(frames::buffer_len(ref p,ref s,ref data,a,ref r,ref roots,ref rs,ref mut fuel),1);assert(fuel==255);
    fuel=2336;error(frames::buffer_write(ref p,ref s,ref data,a,0,88,ref r,ref mut roots,ref mut rs,limits(),ref mut fuel),1);assert(fuel==256);
    fuel=4155;error(frames::buffer_append(ref p,ref s,ref data,a,b"XYZ",ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel),1);assert(fuel==1819);
    fuel=4143;error(frames::buffer_reserve(ref p,ref s,ref data,a,128,ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel),1);assert(fuel==1807);
    fuel=100000;error(frames::buffer_len(ref p,ref s,ref data,at(t,0),ref r,ref roots,ref rs,ref mut fuel),3);
    error(frames::buffer_write(ref p,ref s,ref data,a,4,88,ref r,ref mut roots,ref mut rs,limits(),ref mut fuel),4);
    // The final replacement fits, but old plus new live capacity/owner does not.
    let growth::Limits exact=growth::Limits{.object=4096,.instance=s.used+used+128,.engine=s.used+used+128};
    error(frames::buffer_reserve(ref p,ref s,ref data,a,128,ref mut r,ref mut roots,ref mut rs,exact,ref mut fuel),5);
    assert(r.ledger.used==used && r.ledger.peak==peak && r.rows[0].generation==generation);
    // Changing the canonical word cannot confer another root's authority.
    let usize offset=placed(layouts::offset(ref p,10));
    {let ref mut u8[] all=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,0));all[offset]=0;}
    error(frames::buffer_len(ref p,ref s,ref data,a,ref r,ref roots,ref rs,ref mut fuel),7);
    {let ref mut u8[] all=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,0));all[offset]=2;}
    error(frames::buffer_len(ref p,ref s,ref data,a,ref r,ref roots,ref rs,ref mut fuel),8);
    {let ref mut u8[] all=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,0));all[offset]=1;}
    unchanged(ref s,ref before);content(ref r,ref roots,ref rs,serial,10,b"safe");fuel=2336;
    assert(ok(frames::buffer_len(ref p,ref s,ref data,a,ref r,ref roots,ref rs,ref mut fuel))==4 && fuel==0);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut rs))==0);
    assert(r.closed && s.closed && r.ledger.used==0 && s.used==0 && vec::len<bytes::Buffer>(ref roots)==0 && vec::len<bytes::Buffer>(ref data)==0);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut rs))==0);
}
