module tests::m2::value_signature_source;
import functions as functions;
import value_signature_source as signatures;
import value_properties as properties;
import errors as errors;

fn functions::Table scanned(ref u8[] source,ref mut properties::Catalog catalog){
    return switch(functions::scan_values(source,catalog)){
        case .ok(v):{v}case .err(_):{assert(false);functions::empty()}
    };
}
fn usize id(u8 tag,ref properties::Catalog catalog){return switch(signatures::type_id(tag,catalog,0)){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
@test fn void typed_signatures_share_canonical_types_with_scalar_array_and_nominal_positions(){
    let ref u8[] source=b"module main;struct Point{i32 x;}fn Option<Buffer> maybe(Result<i64,u8> x,u8[4] data,Point p){return .none;}fn i32 main(){return 42;}";
    var properties::Catalog catalog=properties::empty();let functions::Table table=scanned(source,ref mut catalog);
    assert(table.count==2 && table.entry==1 && table.arities[0]==3);
    let usize result=id(table.return_types[0],ref catalog);let usize parameter=id(table.param_types[0],ref catalog);
    assert(catalog.nodes[result].kind==5 && catalog.nodes[catalog.nodes[result].first as usize].kind==4);
    assert(catalog.nodes[parameter].kind==6 && catalog.nodes[catalog.nodes[parameter].first as usize].first==9);
    assert(table.param_types[1]==10 && table.param_lengths[1]==4 && table.param_records[2]==1);
    assert(table.return_types[1]==1 && table.return_lengths[1]==0 && catalog.records.count==1);
    assert(!functions::scan(source).is_ok); // Legacy entry never opts in by retry.
}
@test fn void nested_and_qualified_signatures_preserve_void_and_reference_candidates(){
    let ref u8[] source=b"module main;fn void consume(brownie::bytes::Buffer data,ref mut u8[] output){}fn Result<Option<usize>,bytes::Buffer> make(){return .err(bytes::empty());}fn i32 main(){return 42;}";
    var properties::Catalog catalog=properties::empty();let functions::Table table=scanned(source,ref mut catalog);
    assert(table.count==3 && table.entry==2 && table.return_types[0]==13 && table.arities[0]==2);
    assert(catalog.nodes[id(table.param_types[0],ref catalog)].kind==4);
    assert(table.param_slices[1] && table.param_slice_elements[1]==138);
    let usize result=id(table.return_types[1],ref catalog);
    assert(catalog.nodes[result].kind==6 && catalog.nodes[catalog.nodes[result].first as usize].kind==5);
    assert(catalog.nodes[catalog.nodes[result].second as usize].kind==4);
}
fn void rejected(ref u8[] source,ref mut properties::Catalog catalog){
    switch(functions::scan_values(source,catalog)){case .ok(_):{assert(false);}case .err(_):{}};
    assert(catalog.count==1 && catalog.nodes[0].kind==4 && catalog.records.count==0);
}
@test fn void failed_signature_collection_never_publishes_a_partial_catalog(){
    var properties::Catalog catalog=properties::empty();catalog.count=1;
    catalog.nodes[0]=properties::Node{.kind=4,.first=0,.second=0,.extent=0};
    rejected(b"module main;fn Buffer take(Buffer x,Buffer x){return x;}fn i32 main(){return 42;}",ref mut catalog);
    rejected(b"module main;fn Option<Option<Option<Option<Option<i32>>>>> f(){return .none;}fn i32 main(){return 42;}",ref mut catalog);
    rejected(b"module main;fn Buffer main(){return bytes::empty();}",ref mut catalog);
    rejected(b"module main;fn u8[2][3] f(){return [0;3];}fn i32 main(){return 42;}",ref mut catalog);
    rejected(b"module main;fn void f(Unknown x){}fn i32 main(){return 42;}",ref mut catalog);
}
