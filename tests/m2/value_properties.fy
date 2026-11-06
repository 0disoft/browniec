module tests::m2::value_properties;
import value_properties as values;

fn values::Node node(u8 kind,u8 first,u8 second,usize extent){
    return values::Node{.kind=kind,.first=first,.second=second,.extent=extent};
}
fn values::Plan plan(ref values::Catalog c){return switch(values::inspect(c)){
    case .ok(p):{p}case .err(_):{assert(false);values::Plan{.count=0,
        .properties=[values::Property{.bytes=0,.alignment=0,.payload_offset=0,
            .wrapper_depth=0,.copyable=false,.contains_buffer=false};64]}}
};}
fn void invalid(ref values::Catalog c){assert(!values::inspect(c).is_ok);}
@test fn void whole_type_copyability_includes_inactive_and_nested_buffer_alternatives(){
    var values::Catalog c=values::empty();c.count=9;
    c.nodes[0]=node(1,1,0,0);c.nodes[1]=node(4,0,0,0);
    c.nodes[2]=node(5,1,0,0); // Option<Buffer>, including none
    c.nodes[3]=node(6,0,1,0);c.nodes[4]=node(6,1,0,0);
    c.nodes[5]=node(5,3,0,0);c.nodes[6]=node(6,0,5,0);
    c.nodes[7]=node(5,6,0,0);c.nodes[8]=node(6,0,0,0);
    let values::Plan p=plan(ref c);assert(p.properties[0].copyable && p.properties[8].copyable);
    var usize i=1;while(i<8){assert(!p.properties[i].copyable && p.properties[i].contains_buffer);i+=1;}
    assert(p.properties[2].bytes==16 && p.properties[2].payload_offset==8);
    assert(p.properties[7].wrapper_depth==4 && p.properties[7].bytes==40);
    c.count=10;c.nodes[9]=node(5,7,0,0);invalid(ref c);
}
@test fn void scalar_array_and_plain_record_layouts_are_independent_of_wrapper_depth(){
    var values::Catalog c=values::empty();c.records.count=16;
    let u8[16] previous=[9,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14];
    var usize i=0;while(i<16){c.records.fields[i]=1;c.records.types[i*16]=previous[i];
        c.records.kinds[i*16]=if(i==0){0}else{1};i+=1;}
    c.count=8;c.nodes[0]=node(1,9,0,0);c.nodes[1]=node(1,11,0,0);
    c.nodes[2]=node(2,9,0,4096);c.nodes[3]=node(6,2,1,0);
    c.nodes[4]=node(3,15,0,0);c.nodes[5]=node(5,4,0,0);
    c.nodes[6]=node(5,5,0,0);c.nodes[7]=node(5,6,0,0);
    let values::Plan p=plan(ref c);
    assert(p.properties[3].bytes==32776 && p.properties[3].payload_offset==8);
    assert(p.properties[7].wrapper_depth==3 && p.properties[7].bytes==32 && p.properties[7].copyable);
    c.records.kinds[0]=1;c.records.types[0]=15;invalid(ref c);
    c.records.kinds[0]=0;c.records.types[0]=3;invalid(ref c); // wrapper field
    c.records.types[0]=14;invalid(ref c); // Buffer/unknown field
}
@test fn void complete_catalog_rejects_forged_unused_reserved_and_cyclic_metadata(){
    var values::Catalog c=values::empty();c.count=2;
    c.nodes[0]=node(1,1,0,0);c.nodes[1]=node(5,0,0,0);let values::Plan p=plan(ref c);
    assert(p.properties[1].copyable && p.properties[1].bytes==8);
    c.nodes[1].first=1;invalid(ref c);c.nodes[1].first=63;invalid(ref c);
    c.nodes[1]=node(6,0,1,0);invalid(ref c);
    c.nodes[1]=node(5,0,1,0);invalid(ref c);
    c.nodes[1]=node(5,0,0,1);invalid(ref c);
    c.nodes[1]=node(4,1,0,0);invalid(ref c);
    c.nodes[1]=node(2,3,0,1);invalid(ref c); // arrays are scalar only
    c.nodes[1]=node(2,1,0,0);invalid(ref c);c.nodes[1].extent=4097;invalid(ref c);
    c.nodes[1].extent=18446744073709551615;invalid(ref c);
    c.nodes[1]=node(7,0,0,0);invalid(ref c);
    c.nodes[1]=node(1,13,0,0);invalid(ref c); // void is not a value
    c.nodes[1]=node(1,1,0,0);c.nodes[63].first=1;invalid(ref c);
    c.nodes[63].first=0;c.count=65;invalid(ref c);
}
@test fn void legacy_tags_and_full_shared_dag_derive_properties_without_payload_inspection(){
    var u8 tag=1;while(tag<=12){let values::Property p=switch(values::legacy(tag)){
        case .ok(v):{v}case .err(_):{assert(false);values::Property{.bytes=0,.alignment=0,
            .payload_offset=0,.wrapper_depth=0,.copyable=false,.contains_buffer=false}}
    };assert(p.copyable && !p.contains_buffer && p.bytes>0);tag+=1;}
    assert(!values::legacy(0).is_ok && !values::legacy(13).is_ok && !values::legacy(255).is_ok);
    var values::Catalog c=values::empty();c.count=64;c.nodes[0]=node(4,0,0,0);
    var usize i=1;while(i<64){c.nodes[i]=node(6,0,0,0);i+=1;}
    let values::Plan p=plan(ref c);assert(p.count==64 && !p.properties[63].copyable);
    assert(p.properties[63].wrapper_depth==1 && p.properties[63].bytes==16);
}
