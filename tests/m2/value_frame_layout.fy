module tests::m2::value_frame_layout;
import value_frame_layout as frames;
import value_codec as codec;
import value_properties as values;

fn values::Node node(u8 kind,u8 first,u8 second,usize extent){return values::Node{.kind=kind,.first=first,.second=second,.extent=extent};}
fn values::Catalog catalog(){
    var values::Catalog c=values::empty();c.count=9;
    c.nodes[0]=node(1,10,0,0);c.nodes[1]=node(1,9,0,0);c.nodes[2]=node(2,1,0,3);
    c.nodes[3]=node(3,0,0,0);c.nodes[4]=node(3,1,0,0);c.nodes[5]=node(4,0,0,0);
    c.nodes[6]=node(5,5,0,0);c.nodes[7]=node(6,0,5,0);c.nodes[8]=node(5,6,0,0);
    c.records.count=2;c.records.fields[0]=2;c.records.fields[1]=2;
    c.records.types[0]=10;c.records.types[1]=9;c.records.types[16]=10;c.records.types[17]=9;
    return c;
}
fn frames::Plan retained(ref values::Catalog c,ref u8[] types,ref u8[] functions,usize count){
    return switch(frames::retain(c,types,functions,count)){
        case .ok(v):{v}case .err(_):{assert(false);retained(c,types,functions,count)}
    };
}
fn usize ok(Result<usize,frames::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn bool rejected(ref values::Catalog c,ref u8[] types,ref u8[] functions,usize count){
    return !frames::retain(c,types,functions,count).is_ok;
}
@test fn void independent_functions_align_slots_and_trailing_bytes_with_empty_functions_preserved(){
    let values::Catalog c=catalog();
    let u8[16] types=[1,2,1,3,4,6,7,8,9,1,0,0,0,0,0,0];
    let u8[16] functions=[0,1,1,0,2,2,2,3,3,3,0,0,0,0,0,0];
    let frames::Plan p=retained(ref c,ref types,ref functions,5);
    assert(frames::functions(ref p)==5 && frames::largest(ref p)==24);
    assert(ok(frames::offset(ref p,0))==0 && ok(frames::offset(ref p,3))==4);
    assert(ok(frames::offset(ref p,1))==0 && ok(frames::offset(ref p,2))==8);
    assert(ok(frames::offset(ref p,4))==0 && ok(frames::offset(ref p,5))==16 && ok(frames::offset(ref p,6))==24);
    assert(ok(frames::offset(ref p,7))==0 && ok(frames::offset(ref p,8))==16 && ok(frames::offset(ref p,9))==40);
    assert(ok(frames::width(ref p,0))==16 && ok(frames::width(ref p,1))==16);
    assert(ok(frames::width(ref p,2))==40 && ok(frames::width(ref p,3))==48 && ok(frames::width(ref p,4))==0);
    assert(ok(frames::type_id(ref p,5,2))==5 && ok(frames::type_id(ref p,8,3))==8);
    assert(!frames::type_id(ref p,1,0).is_ok && !frames::offset(ref p,10).is_ok);
}
@test fn void retained_catalog_and_slot_snapshots_preserve_nominal_identity_after_inputs_change(){
    var values::Catalog c=catalog();var u8[16] types=[0;16];var u8[16] functions=[0;16];
    types[0]=4;types[1]=5;functions[1]=1;
    let frames::Plan p=retained(ref c,ref types,ref functions,2);
    c.records.types[1]=10;c.nodes[3]=node(1,10,0,0);types[0]=1;functions[1]=0;
    assert(ok(frames::type_id(ref p,0,0))==3 && ok(frames::type_id(ref p,1,1))==4);
    assert(!frames::type_id(ref p,1,0).is_ok && ok(frames::width(ref p,0))==16 && frames::largest(ref p)==16);
    assert(switch(codec::same(frames::layout(ref p),3,4)){case .ok(v):{!v}case .err(_):{false}});
    assert(switch(codec::shape(frames::layout(ref p),3)){case .ok(v):{v.bytes==16 && v.alignment==8}case .err(_):{false}});
    assert(switch(codec::node(frames::layout(ref p),3)){case .ok(v):{v.kind==3 && v.first==0}case .err(_):{false}});
}
@test fn void malformed_metadata_and_extreme_query_bounds_are_rejected_without_losing_empty_layouts(){
    var values::Catalog c=catalog();var u8[16] types=[0;16];var u8[16] functions=[0;16];
    assert(rejected(ref c,ref types[..15],ref functions,1));
    assert(rejected(ref c,ref types,ref functions[..15],1));
    assert(rejected(ref c,ref types,ref functions,0) && rejected(ref c,ref types,ref functions,17));
    functions[15]=1;assert(rejected(ref c,ref types,ref functions,2));functions[15]=0;
    types[15]=1;functions[15]=2;assert(rejected(ref c,ref types,ref functions,2));functions[15]=0;
    types[15]=10;assert(rejected(ref c,ref types,ref functions,1));
    types[15]=255;assert(rejected(ref c,ref types,ref functions,1));types[15]=0;
    let frames::Plan empty=retained(ref c,ref types,ref functions,16);
    assert(frames::largest(ref empty)==0 && ok(frames::width(ref empty,15))==0);
    assert(!frames::type_id(ref empty,0,0).is_ok && !frames::offset(ref empty,0).is_ok);
    assert(!frames::offset(ref empty,16).is_ok && !frames::offset(ref empty,18446744073709551615).is_ok);
    assert(!frames::type_id(ref empty,16,0).is_ok && !frames::type_id(ref empty,0,18446744073709551615).is_ok);
    assert(!frames::width(ref empty,16).is_ok && !frames::width(ref empty,18446744073709551615).is_ok);
    c.nodes[8]=node(5,8,0,0);assert(rejected(ref c,ref types,ref functions,1));
    c=values::empty();let frames::Plan no_types=retained(ref c,ref types,ref functions,1);
    assert(codec::count(frames::layout(ref no_types))==0 && ok(frames::width(ref no_types,0))==0);
    c.count=1;c.nodes[0]=node(2,9,0,4096);types=[1;16];
    let frames::Plan maximum=retained(ref c,ref types,ref functions,1);
    assert(frames::largest(ref maximum)==32768 && ok(frames::offset(ref maximum,15))==491520 && ok(frames::width(ref maximum,0))==524288);
}
