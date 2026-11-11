module tests::m2::value_function_work;
import value_function_work as work;
import functions as raw;
import value_properties as properties;
import errors as errors;
import metadata_budget as budget;
fn void table(ref raw::Table a,ref raw::Table b){
    assert(a.count==b.count && a.entry==b.entry && a.reference_calls==b.reference_calls && a.reference_returns==b.reference_returns && a.output==b.output);
    assert(a.context.modules==b.context.modules && a.context.imports==b.context.imports && a.context.function_count==b.context.function_count && a.context.record_count==b.context.record_count);
    assert(a.literals.count==b.literals.count && a.literals.enabled==b.literals.enabled);
    var usize i=0;while(i<16){assert(a.begins[i]==b.begins[i] && a.ends[i]==b.ends[i] && a.bodies[i]==b.bodies[i] && a.body_ends[i]==b.body_ends[i] &&
        a.arities[i]==b.arities[i] && a.return_types[i]==b.return_types[i] && a.return_lengths[i]==b.return_lengths[i] && a.return_records[i]==b.return_records[i] &&
        a.return_slice_elements[i]==b.return_slice_elements[i] && a.return_slice_inputs[i]==b.return_slice_inputs[i] && a.return_slice_candidates[i]==b.return_slice_candidates[i]);
        assert(a.context.ends[i]==b.context.ends[i] && a.context.functions[i]==b.context.functions[i] && a.literals.begins[i]==b.literals.begins[i] &&
            a.literals.ends[i]==b.literals.ends[i] && a.literals.literals[i]==b.literals.literals[i] && a.literals.lengths[i]==b.literals.lengths[i] && a.literals.kinds[i]==b.literals.kinds[i]);i+=1;}
    i=0;while(i<128){assert(a.param_begins[i]==b.param_begins[i] && a.param_ends[i]==b.param_ends[i] && a.param_types[i]==b.param_types[i] &&
        a.param_lengths[i]==b.param_lengths[i] && a.param_arrays[i]==b.param_arrays[i] && a.param_records[i]==b.param_records[i] &&
        a.param_slices[i]==b.param_slices[i] && a.param_slice_elements[i]==b.param_slice_elements[i]);i+=1;}
    i=0;while(i<64){assert(a.context.aliases[i]==b.context.aliases[i]);i+=1;}
    i=0;while(i<32){assert(a.context.records[i]==b.context.records[i]);i+=1;}
}
fn void same_result(Result<raw::Table,errors::Error> expected,Result<raw::Table,errors::Error> actual){
    switch(expected){case .ok(a):{switch(actual){case .ok(b):{table(ref a,ref b);}case .err(_):{assert(false);}};}
        case .err(e):{switch(actual){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};}};
}
fn void catalog(ref properties::Catalog a,ref properties::Catalog b){assert(a.count==b.count && a.records.count==b.records.count);var usize i=0;
    while(i<64){assert(a.nodes[i].kind==b.nodes[i].kind && a.nodes[i].first==b.nodes[i].first && a.nodes[i].second==b.nodes[i].second && a.nodes[i].extent==b.nodes[i].extent);i+=1;}
    i=0;while(i<32){assert(a.records.fields[i]==b.records.fields[i]);i+=1;}i=0;
    while(i<512){assert(a.records.kinds[i]==b.records.kinds[i] && a.records.types[i]==b.records.types[i]);i+=1;}}
fn Result<raw::Table,errors::Error> run(ref u8[] source,ref mut properties::Catalog original){
    var work::State w=work::empty();var properties::Catalog candidate=properties::empty();var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<100000);assert(!work::prepared(ref w).is_ok);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize row=w.row;let usize count=w.functions.result.count;let u8 signature=w.functions.signature.phase;
        let u8 annotation=w.annotation.phase;let usize nodes=candidate.count;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut candidate,ref mut w,ref mut meter).is_ok && w.phase==phase && w.row==row && w.functions.result.count==count &&
            w.functions.signature.phase==signature && w.annotation.phase==annotation && candidate.count==nodes && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);let bool done=work::advance(source,ref mut candidate,ref mut w,ref mut meter)?;
        assert(done==w.done && meter.last==4096);turns+=1;}
    let usize total=meter.total;assert(work::advance(source,ref mut candidate,ref mut w,ref mut meter).is_ok && total==meter.total);
    let raw::Table result=work::prepared(ref w)?;*original=candidate;return .ok(result);
}
fn void same(ref u8[] source,ref properties::Catalog initial){var properties::Catalog a=*initial;var properties::Catalog b=*initial;
    same_result(raw::scan_values_raw(source,ref mut a),run(source,ref mut b));catalog(ref a,ref b);
}
@test fn void complete_value_signatures_declaration_order_and_catalog_rollback(){
    var properties::Catalog seed=properties::empty();seed.count=1;seed.nodes[0]=properties::Node{.kind=4,.first=0,.second=0,.extent=0};
    same(b"module main;struct Point{i32 x;}fn Option<Buffer> maybe(Result<i64,u8> x,u8[4] data,Point p){return .none;}fn i32 main(){return 42;}",ref seed);
    same(b"module main;fn void consume(brownie::bytes::Buffer data,ref mut u8[] output){}fn Result<Option<usize>,bytes::Buffer> make(){return .err(bytes::empty());}fn i32 main(){return 42;}",ref seed);
    same(b"module main;fn ref u8[] f(ref u8[] a,ref u8[] b){return ref a;}fn i32 main(){return 42;}",ref seed);
    same(b"module main;fn Buffer take(Buffer x,Buffer x){return x;}fn i32 main(){return 42;}",ref seed);
    same(b"module main;fn Option<Option<Option<Option<Option<i32>>>>> f(){}fn i32 main(){return 42;}",ref seed);
    same(b"module main;fn Buffer main(){return bytes::empty();}",ref seed);
    same(b"module main;fn u8[2][3] f(){}fn i32 main(){return 42;}",ref seed);
    same(b"module main;fn void f(Unknown x){}fn i32 main(){return 42;}",ref seed);
    same(b"module main;fn Buffer f(){}fn Buffer f(){}fn i32 main(){return 42;}",ref seed);
    same(b"module main;struct P{Unknown x;}fn Option< f(){}",ref seed);
    same(b"module main;struct P{i32 x;}struct Q{Q x;}fn Option< f(){}",ref seed);
    same(b"module main;fn void f(ref Option<i32>[] x){}fn i32 main(){return 42;}",ref seed);
    same(b"module main;fn void[2] f(){}fn i32 main(){return 42;}",ref seed);
    same(b"module main;fn ref u8[] f(){}fn i32 main(){return 42;}",ref seed);
    same(b"module main;fn i32 main(i32 x){}",ref seed);same(b"module main;",ref seed);
    // Incoming catalogs are deliberately ignored by scan_values, including malformed ones.
    seed.count=65;same(b"module main;fn i32 main(){return 42;}",ref seed);
}
