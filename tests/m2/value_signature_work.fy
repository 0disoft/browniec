module tests::m2::value_signature_work;
import value_signature_work as work;
import value_signature_source as raw;
import value_type_source as syntax;
import value_properties as properties;
import lexer as lexer;
import errors as errors;
import metadata_budget as budget;
fn void catalog(ref properties::Catalog a,ref properties::Catalog b){assert(a.count==b.count && a.records.count==b.records.count);var usize i=0;
    while(i<64){assert(a.nodes[i].kind==b.nodes[i].kind && a.nodes[i].first==b.nodes[i].first && a.nodes[i].second==b.nodes[i].second && a.nodes[i].extent==b.nodes[i].extent);i+=1;}
    i=0;while(i<32){assert(a.records.fields[i]==b.records.fields[i]);i+=1;}i=0;
    while(i<512){assert(a.records.kinds[i]==b.records.kinds[i] && a.records.types[i]==b.records.types[i]);i+=1;}}
fn void token(lexer::State a,lexer::State b){assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end && a.tokens==b.tokens && a.kind==b.kind &&
    a.value==b.value && a.min_magnitude==b.min_magnitude && a.context==b.context);}
fn Result<raw::Type,errors::Error> run(ref u8[] source,ref mut lexer::State cursor,ref mut properties::Catalog c){
    var work::State w=work::begin(*cursor);var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<30000);assert(!work::prepared(ref w).is_ok);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize count=c.count;let usize at=w.token.cursor;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,c,ref mut w,ref mut meter).is_ok && phase==w.phase && count==c.count && at==w.token.cursor && total==meter.total);
        assert(budget::reset(ref mut meter,0).is_ok);let bool done=work::advance(source,c,ref mut w,ref mut meter)?;
        assert(done==w.done && meter.last==4096);if(!done){assert(c.count==count);}turns+=1;}
    let usize total=meter.total;assert(work::advance(source,c,ref mut w,ref mut meter).is_ok && total==meter.total);
    *cursor=work::observed(ref w);return work::prepared(ref w);
}
fn void result(Result<raw::Type,errors::Error> expected,Result<raw::Type,errors::Error> actual){
    switch(expected){case .ok(a):{switch(actual){case .ok(b):{assert(a.tag==b.tag && a.length==b.length && a.record==b.record);}case .err(_):{assert(false);}};}
        case .err(a):{switch(actual){case .ok(_):{assert(false);}case .err(b):{assert(a.kind==b.kind && a.offset==b.offset);}};}};
}
fn void same(ref u8[] source,ref properties::Catalog initial){var lexer::State start=lexer::empty();assert(lexer::next(source,ref mut start).is_ok);
    var lexer::State a=start;var lexer::State b=start;var lexer::State c=start;var properties::Catalog x=*initial;var properties::Catalog y=*initial;var properties::Catalog z=*initial;
    let Result<raw::Type,errors::Error> reference=raw::parse_raw(source,ref mut a,ref mut x);
    result(reference,run(source,ref mut b,ref mut y));result(reference,raw::parse(source,ref mut c,ref mut z));token(a,b);token(a,c);catalog(ref x,ref y);catalog(ref x,ref z);
    a=start;b=start;x=*initial;y=*initial;
    switch(syntax::parse_raw(source,ref mut a,ref mut x)){case .ok(id):{switch(syntax::parse(source,ref mut b,ref mut y)){case .ok(other):{assert(id==other);}case .err(_):{assert(false);}};}
        case .err(e):{switch(syntax::parse(source,ref mut b,ref mut y)){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};}};
    token(a,b);catalog(ref x,ref y);
}
@test fn void staged_annotation_tags_catalog_rollback_and_adapter_results_match(){let properties::Catalog initial=properties::empty();
    same(b"i32",ref initial);same(b"u8[4096]",ref initial);same(b"Result<Option<i64[4096]>,Buffer>",ref initial);
    same(b"brownie::bytes::Buffer;",ref initial);same(b"Option<i32>>tail",ref initial);same(b"i32[2][3]",ref initial);
    same(b"Result<Buffer,Nope>",ref initial);same(b"Option<Option<Option<Option<Option<i32>>>>>",ref initial);same(b"Buffer @",ref initial);
    var properties::Catalog bad=initial;bad.count=65;same(b"i32",ref bad);
}
