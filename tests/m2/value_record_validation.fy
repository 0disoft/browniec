module tests::m2::value_record_validation;
import value_codec as codec;
import value_properties as properties;
import struct_layout as records;
import scalar_codec as scalar;
import std::bytes as bytes;
import std::num as num;

struct Cursor { usize depth; usize[16] records; usize[16] fields; usize[16] bases; usize[16] ends; }
fn bool zero(ref u8[] data,usize first,usize last){
    var usize i=first;while(i<last){if(data[i]!=0){return false;}i+=1;}return true;
}
// Frozen original record walker from eb4df78; only type and field aliases change.
fn Result<usize,codec::Error> original(ref records::Catalog catalog,ref records::Plan plan,usize id,ref u8[] data){
    var Cursor c=Cursor{.depth=1,.records=[0;16],.fields=[0;16],.bases=[0;16],.ends=[0;16]};c.records[0]=id;
    while(c.depth>0){let usize level=c.depth-1;let usize nominal=c.records[level];
        let usize field=c.fields[level];let usize base=c.bases[level];
        if(field==catalog.fields[nominal] as usize){
            if(!zero(data,base+c.ends[level],base+plan.bytes[nominal])){return .err(.Value);}
            c.depth-=1;
        }else{
            let usize slot=nominal*16+field;let usize at=plan.offsets[slot];
            let u8 tag=catalog.types[slot];let bool nested=catalog.kinds[slot]==1;
            let usize width=if(nested){plan.bytes[tag as usize]}else{scalar::width(tag)};
            if(!zero(data,base+c.ends[level],base+at)){return .err(.Value);}
            c.fields[level]+=1;c.ends[level]=at+width;
            if(nested){let usize child=c.depth;
                if(child>=16){return .err(.Layout);}
                c.records[child]=tag as usize;c.fields[child]=0;c.bases[child]=base+at;c.ends[child]=0;c.depth+=1;
            }else if(!scalar::decode(tag,data[base+at..base+at+width]).is_ok){return .err(.Value);}
        }
    }return .ok(data.len);
}
fn u8 code(codec::Error e){return switch(e){case .Layout:{1}case .Type:{2}case .Bounds:{3}case .Value:{4}case .Overlap:{5}};}
fn codec::Layout retained(ref properties::Catalog c){return switch(codec::retain(c)){
    case .ok(v):{v}case .err(_):{assert(false);retained(c)}
};}
fn records::Plan planned(ref properties::Catalog c){return switch(records::plan(ref c.records,4096)){
    case .ok(v):{v}case .err(_):{assert(false);planned(c)}
};}
fn u8 octet(usize value){let i64 n=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(num::u8_from_i64(n)){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn properties::Node node(u8 kind,u8 first){return properties::Node{.kind=kind,.first=first,.second=0,.extent=0};}
fn void same(ref properties::Catalog c,ref records::Plan p,ref codec::Layout l,ref u8[] data){
    let usize root=c.nodes[0].first as usize;
    let Result<usize,codec::Error> wanted=if(data.len!=p.bytes[root]){.err(.Bounds)}else{original(ref c.records,p,root,data)};
    let Result<codec::Active,codec::Error> actual=codec::inspect(l,0,data);
    assert(switch(wanted){case .ok(n):{switch(actual){
        case .ok(a):{n==data.len && !a.present && a.offset==0 && a.serial==0}case .err(_):{false}}}
        case .err(e):{switch(actual){case .ok(_):{false}case .err(f):{code(e)==code(f)}}}});
}
fn void accepted(ref codec::Layout l,usize id,ref u8[] data){
    assert(switch(codec::inspect(l,id,data)){case .ok(a):{!a.present && a.offset==0 && a.serial==0}case .err(_):{false}});
}
fn void invalid(ref codec::Layout l,usize id,ref u8[] data){
    assert(switch(codec::inspect(l,id,data)){case .ok(_):{false}case .err(e):{code(e)==4}});
}
fn bytes::Buffer backing(usize size){var bytes::Buffer b=switch(bytes::with_capacity(size)){
    case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(bytes::resize_zeroed(ref mut b,size).is_ok);return b;
}
fn properties::Catalog repeated(u8 tag){
    var properties::Catalog c=properties::empty();c.count=1;c.nodes[0]=node(3,2);
    c.records.count=3;c.records.fields[0]=16;c.records.fields[1]=16;c.records.fields[2]=octet(16/scalar::width(tag));
    var usize i=0;while(i<16){c.records.types[i]=tag;c.records.kinds[16+i]=1;
        if(i<c.records.fields[2] as usize){c.records.kinds[32+i]=1;c.records.types[32+i]=1;}i+=1;}return c;
}
fn void fill(ref mut u8[] data,usize stride,usize pattern){var usize i=0;while(i<data.len){var usize value=0;
    if(pattern==1){value=255;}else if(pattern==2){value=if(i%stride==stride-1){128}else{0};}
    else if(pattern==3){value=if(i%stride==stride-1){127}else{255};}
    else if(pattern==4){value=(i*73+19)%256;}else if(pattern==5){value=(i*29+239)%256;}
    data[i]=octet(value);i+=1;}}
@test fn void maximum_repeated_integer_records_match_original_for_all_tags_patterns_and_exact_lengths(){
    let u8[5] tags=[1,9,10,11,12];var usize i=0;while(i<5){
        var properties::Catalog c=repeated(tags[i]);let records::Plan p=planned(ref c);let codec::Layout l=retained(ref c);
        assert(p.bytes[2]==4096);var bytes::Buffer b=backing(4097);var usize pattern=0;
        while(pattern<6){fill(bytes::view_mut(ref mut b),scalar::width(tags[i]),pattern);
            same(ref c,ref p,ref l,bytes::view(ref b)[..4096]);pattern+=1;}
        same(ref c,ref p,ref l,bytes::view(ref b)[..4095]);same(ref c,ref p,ref l,bytes::view(ref b));
        // Analysis mutations cannot turn the retained integer fields into bool.
        c.records.types[0]=2;accepted(ref l,0,bytes::view(ref b)[..4096]);i+=1;
    }
}
fn properties::Catalog mixed(){var properties::Catalog c=properties::empty();c.count=1;c.nodes[0]=node(3,1);
    c.records.count=2;c.records.fields[0]=7;c.records.fields[1]=2;let u8[7] tags=[10,9,2,1,11,12,2];
    var usize i=0;while(i<7){c.records.types[i]=tags[i];i+=1;}c.records.kinds[16]=1;c.records.kinds[17]=1;return c;
}
@test fn void every_nested_byte_mutation_matches_original_and_late_bool_padding_errors_preserve_copy_target(){
    let properties::Catalog c=mixed();let records::Plan p=planned(ref c);let codec::Layout l=retained(ref c);
    assert(p.bytes[0]==48 && p.bytes[1]==96);var u8[192] data=[0;192];var usize at=0;
    while(at<96){var usize value=0;while(value<256){data[at]=octet(value);same(ref c,ref p,ref l,ref data[..96]);value+=1;}
        data[at]=0;at+=1;}
    at=96;while(at<192){data[at]=85;at+=1;}let usize[3] late=[88,95,49];var usize i=0;
    while(i<3){data[late[i]]=2;invalid(ref l,0,ref data[..96]);
        assert(switch(codec::copy_at(ref l,0,0,96,ref mut data)){case .ok(_):{false}case .err(e):{code(e)==4}});
        at=96;while(at<192){assert(data[at]==85);at+=1;}data[late[i]]=0;i+=1;}
    assert(codec::copy_at(ref l,0,0,96,ref mut data).is_ok && bytes::equal(ref data[..96],ref data[96..192]));
}
@test fn void depth_sixteen_and_four_wrappers_keep_bool_tag_inactive_padding_and_catalog_admission_checks(){
    var properties::Catalog c=properties::empty();c.count=5;c.nodes[0]=node(3,0);c.records.count=16;var usize i=0;
    while(i<16){c.records.fields[i]=1;c.records.kinds[i*16]=if(i<15){1}else{0};
        c.records.types[i*16]=if(i<15){octet(i+1)}else{2};i+=1;}
    i=1;while(i<5){c.nodes[i]=node(5,octet(i-1));i+=1;}
    let codec::Layout deep=retained(ref c);var u8[5] data=[1;5];accepted(ref deep,4,ref data);
    data[4]=2;invalid(ref deep,4,ref data);data[4]=1;data[0]=2;invalid(ref deep,4,ref data);
    c.records.kinds[15*16]=1;c.records.types[15*16]=0;assert(!codec::retain(ref c).is_ok);
    data[0]=1;accepted(ref deep,4,ref data);
    c=repeated(9);c.count=5;i=1;while(i<5){c.nodes[i]=node(5,octet(i-1));i+=1;}
    let codec::Layout wide=retained(ref c);var bytes::Buffer wrapped=backing(4128);
    {let ref mut u8[] raw=bytes::view_mut(ref mut wrapped);i=0;while(i<4){raw[i*8]=1;i+=1;}
        i=32;while(i<4128){raw[i]=255;i+=1;}}
    accepted(ref wide,4,bytes::view(ref wrapped));
    {let ref mut u8[] raw=bytes::view_mut(ref mut wrapped);raw[0]=0;}invalid(ref wide,4,bytes::view(ref wrapped));
    {let ref mut u8[] raw=bytes::view_mut(ref mut wrapped);raw[0]=1;raw[1]=1;}invalid(ref wide,4,bytes::view(ref wrapped));
    {let ref mut u8[] raw=bytes::view_mut(ref mut wrapped);raw[1]=0;}accepted(ref wide,4,bytes::view(ref wrapped));
    c.records.types[0]=13;assert(!codec::retain(ref c).is_ok);accepted(ref wide,4,bytes::view(ref wrapped));
}
