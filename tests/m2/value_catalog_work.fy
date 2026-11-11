module tests::m2::value_catalog_work;
import value_catalog_work as work;
import value_source_functions as raw;
import value_properties as properties;
import functions as functions;
import errors as errors;
import metadata_budget as budget;
fn Result<raw::Plan,errors::Error> run(ref properties::Catalog c,ref functions::Table t){var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<3000);assert(!work::prepared(ref w).is_ok);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize f=w.function;let usize p=w.parameter;let usize row=w.row;let usize visits=w.visits;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(c,t,ref mut w,ref mut meter).is_ok && phase==w.phase && f==w.function && p==w.parameter && row==w.row && visits==w.visits && total==meter.total);
        assert(budget::reset(ref mut meter,0).is_ok);let bool done=work::advance(c,t,ref mut w,ref mut meter)?;
        assert(done==w.done && meter.last==4096 && w.visits-visits<=1);turns+=1;}
    let usize total=meter.total;assert(work::advance(c,t,ref mut w,ref mut meter).is_ok && total==meter.total);return work::prepared(ref w);
}
fn void same(ref properties::Catalog c,ref functions::Table t){switch(raw::prepare_raw(c,t)){
    case .ok(a):{switch(run(c,t)){case .ok(b):{var usize i=0;while(i<16){assert(a.results[i]==b.results[i]);i+=1;}
        i=0;while(i<128){assert(a.parameters[i]==b.parameters[i]);i+=1;}}case .err(_):{assert(false);}};}
    case .err(e):{switch(run(c,t)){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};}
};}
fn functions::Table scanned(ref u8[] source,ref mut properties::Catalog c){return switch(functions::scan_values(source,c)){case .ok(v):{v}case .err(_):{assert(false);functions::empty()}};}
@test fn void exact_catalog_mapping_reference_modes_reserved_rows_and_error_order(){
    var properties::Catalog c=properties::empty();var functions::Table t=scanned(b"module main;struct P{i32 x;}fn Option<Buffer> f(Result<i64,u8> x,u8[4] y,P p){}fn i32 main(){return 42;}",ref mut c);
    same(ref c,ref t);let functions::Table before=t;let properties::Catalog original=c;
    t.param_types[0]=190;same(ref c,ref t);t=before;t.param_lengths[0]=1;same(ref c,ref t);t=before;t.arities[0]=9;same(ref c,ref t);
    t=before;t.param_types[8]=13;same(ref c,ref t);t=before;t.return_slice_inputs[15]=255;t.return_slice_candidates[15]=255;same(ref c,ref t);
    t.return_types[15]=1;same(ref c,ref t);t=before;t.count=17;c.count=65;same(ref c,ref t);c=original;same(ref c,ref t);
    t=before;t.entry=16;same(ref c,ref t);t=before;t.return_types[1]=13;same(ref c,ref t);c.count=0;same(ref c,ref t);
    c=properties::empty();t=scanned(b"module main;fn ref u8[] f(ref u8[] a){return ref a;}fn i32 main(){return 42;}",ref mut c);
    same(ref c,ref t);t.return_slice_inputs[0]=1;same(ref c,ref t);t.param_slice_elements[0]=138;same(ref c,ref t);
    t.param_slice_elements[0]=10;t.return_slice_elements[0]=138;same(ref c,ref t);
    c=properties::empty();t=scanned(b"module main;fn void f(i32 x){}fn i32 main(){return 42;}",ref mut c);same(ref c,ref t);
    t.param_slice_elements[0]=10;same(ref c,ref t);t.param_slice_elements[0]=0;t.param_records[0]=1;same(ref c,ref t);
}
