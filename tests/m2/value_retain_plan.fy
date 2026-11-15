module tests::m2::value_retain_plan;
import value_properties as values;
import struct_layout as records;
import value_codec as codec;

fn values::Node node(u8 kind,u8 first,u8 second,usize extent){
    return values::Node{.kind=kind,.first=first,.second=second,.extent=extent};
}
fn values::Catalog catalog(){
    var values::Catalog c=values::empty();c.count=24;c.records.count=3;
    c.records.fields[0]=3;c.records.types[0]=10;c.records.types[1]=9;c.records.types[2]=2;
    c.records.fields[1]=2;c.records.kinds[16]=1;c.records.types[16]=0;c.records.types[17]=11;
    c.records.fields[2]=3;c.records.types[32]=10;c.records.types[33]=9;c.records.types[34]=2;
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<6){c.nodes[i]=node(1,tags[i],0,0);i+=1;}
    c.nodes[6]=node(2,2,0,4096);c.nodes[7]=node(2,9,0,4096);
    c.nodes[8]=node(3,0,0,0);c.nodes[9]=node(3,1,0,0);c.nodes[10]=node(4,0,0,0);
    c.nodes[11]=node(5,10,0,0);c.nodes[12]=node(6,8,10,0);c.nodes[13]=node(5,12,0,0);
    c.nodes[14]=node(5,13,0,0);c.nodes[15]=node(5,14,0,0);c.nodes[16]=node(4,0,0,0);
    c.nodes[17]=node(5,16,0,0);c.nodes[18]=node(6,8,16,0);c.nodes[19]=node(5,18,0,0);
    c.nodes[20]=node(5,19,0,0);c.nodes[21]=node(5,20,0,0);c.nodes[22]=node(3,0,0,0);
    c.nodes[23]=node(3,2,0,0);return c;
}
fn u8 code(values::Error e){return switch(e){case .Metadata:{1}case .Type:{2}case .Depth:{3}case .Size:{4}};}
fn void same_property(values::Property a,values::Property b){
    assert(a.bytes==b.bytes && a.alignment==b.alignment && a.payload_offset==b.payload_offset);
    assert(a.wrapper_depth==b.wrapper_depth && a.copyable==b.copyable && a.contains_buffer==b.contains_buffer);
}
fn u8 compare(ref values::Catalog c){
    let Result<values::Plan,values::Error> original=values::inspect(c);
    let Result<values::Inspected,values::Error> described=values::inspect_described(c);
    return switch(original){case .err(e):{
        assert(switch(described){case .ok(_):{false}case .err(f):{code(e)==code(f)}});
        assert(!codec::retain(c).is_ok);code(e)
    }case .ok(expected):{
        let values::Inspected actual=switch(described){case .ok(v):{v}case .err(_):{assert(false);return 255;}};
        let records::Plan plain=switch(records::plan(ref c.records,4096)){
            case .ok(v):{v}case .err(_):{assert(false);return 255;}};
        let codec::Layout retained=switch(codec::retain(c)){case .ok(v):{v}case .err(_):{assert(false);return 255;}};
        assert(actual.shapes.count==expected.count && actual.records.count==plain.count);
        var usize i=0;while(i<64){same_property(expected.properties[i],actual.shapes.properties[i]);
            if(i<expected.count){let values::Property shape=switch(codec::shape(ref retained,i)){
                case .ok(v):{v}case .err(_):{assert(false);return 255;}};same_property(shape,expected.properties[i]);}i+=1;}
        i=0;while(i<32){assert(actual.records.bytes[i]==plain.bytes[i] && actual.records.alignments[i]==plain.alignments[i]);
            assert(actual.records.depths[i]==plain.depths[i]);i+=1;}
        i=0;while(i<512){assert(actual.records.offsets[i]==plain.offsets[i]);i+=1;}0
    }};
}
@test fn void fresh_inspection_preserves_complete_catalog_rejections_and_error_precedence(){
    let values::Catalog clean=catalog();assert(compare(ref clean)==0);var usize i=0;
    while(i<512){var values::Catalog c=clean;c.records.kinds[i]=2;assert(compare(ref c)==2);
        c=clean;c.records.types[i]=255;assert(compare(ref c)==2);i+=1;}
    i=0;while(i<32){var values::Catalog c=clean;c.records.fields[i]=17;assert(compare(ref c)==2);i+=1;}
    i=0;while(i<64){var usize mode=0;while(mode<4){var values::Catalog c=clean;
        if(mode==0){c.nodes[i].kind=255;}else if(mode==1){c.nodes[i].first=255;}
        else if(mode==2){c.nodes[i].second=255;}else{c.nodes[i].extent=18446744073709551615;}
        assert(compare(ref c)!=0);mode+=1;}i+=1;}
    var values::Catalog c=clean;c.count=65;c.records.types[511]=2;assert(compare(ref c)==1);
    c=clean;c.nodes[0].kind=255;c.records.types[511]=2;assert(compare(ref c)==2);
    c.records=clean.records;assert(compare(ref c)==1);
    c=values::empty();assert(compare(ref c)==0);c.records.types[511]=2;assert(compare(ref c)==2);
    c=clean;c.records.kinds[32]=1;c.records.types[32]=2;assert(compare(ref c)==2);
}
@test fn void shared_plans_preserve_full_dags_nominal_identity_and_combined_limits(){
    var values::Catalog c=catalog();c.count=64;var usize i=24;while(i<64){c.nodes[i]=node(6,8,10,0);i+=1;}
    assert(compare(ref c)==0);let codec::Layout retained=switch(codec::retain(ref c)){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(switch(codec::same(ref retained,15,21)){case .ok(v):{v}case .err(_):{false}});
    assert(switch(codec::same(ref retained,8,22)){case .ok(v):{v}case .err(_):{false}});
    assert(switch(codec::same(ref retained,8,23)){case .ok(v):{!v}case .err(_):{false}});
    var usize depth=1;while(depth<=17){c=values::empty();c.count=5;c.records.count=depth;
        c.nodes[0]=node(3,0,0,0);c.nodes[1]=node(5,0,0,0);c.nodes[2]=node(5,1,0,0);
        c.nodes[3]=node(5,2,0,0);c.nodes[4]=node(5,3,0,0);i=0;var u8 next=1;while(i<depth){
            c.records.fields[i]=1;c.records.kinds[i*16]=if(i+1<depth){1}else{0};
            c.records.types[i*16]=if(i+1<depth){next}else{2};i+=1;next+=1;}
        assert(compare(ref c)==if(depth<=16){0}else{2});depth+=1;}
    c=values::empty();c.count=5;c.records.count=3;c.records.fields[0]=16;c.records.fields[1]=16;c.records.fields[2]=2;
    i=0;while(i<16){c.records.types[i]=9;c.records.kinds[16+i]=1;c.records.types[16+i]=0;i+=1;}
    c.records.kinds[32]=1;c.records.types[32]=1;c.records.kinds[33]=1;c.records.types[33]=1;
    c.nodes[0]=node(3,2,0,0);c.nodes[1]=node(5,0,0,0);c.nodes[2]=node(6,0,1,0);
    c.nodes[3]=node(5,2,0,0);c.nodes[4]=node(5,3,0,0);assert(compare(ref c)==0);
    c.count=6;c.nodes[5]=node(5,4,0,0);assert(compare(ref c)==3);
    c.count=5;c.nodes[5]=node(0,0,0,0);c.records.fields[2]=3;c.records.kinds[34]=1;c.records.types[34]=1;
    assert(compare(ref c)==2);
}
