module tests::m2::value_type_work;
import value_type_work as work;
import value_type_source as raw;
import value_properties as properties;
import struct_source as structs;
import lexer as lexer;
import metadata_budget as budget;
import errors as errors;
fn void catalog(ref properties::Catalog a,ref properties::Catalog b){assert(a.count==b.count && a.records.count==b.records.count);var usize i=0;
    while(i<64){assert(a.nodes[i].kind==b.nodes[i].kind && a.nodes[i].first==b.nodes[i].first && a.nodes[i].second==b.nodes[i].second && a.nodes[i].extent==b.nodes[i].extent);i+=1;}
    i=0;while(i<32){assert(a.records.fields[i]==b.records.fields[i]);i+=1;}i=0;
    while(i<512){assert(a.records.kinds[i]==b.records.kinds[i] && a.records.types[i]==b.records.types[i]);i+=1;}}
fn void token(lexer::State a,lexer::State b){assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end && a.tokens==b.tokens && a.kind==b.kind &&
    a.value==b.value && a.min_magnitude==b.min_magnitude && a.context==b.context);}
fn Result<usize,errors::Error> run(ref u8[] source,ref mut lexer::State cursor,ref mut properties::Catalog original){
    var properties::Catalog candidate=properties::empty();var work::State w=work::begin(*cursor);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<30000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize row=w.row;let usize depth=w.depth;let usize visits=w.visits;let lexer::State before=w.token;let usize count=candidate.count;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,original,ref mut candidate,ref mut w,ref mut meter).is_ok && meter.total==total &&
            w.phase==phase && w.row==row && w.depth==depth && w.visits==visits && candidate.count==count);token(before,w.token);
        assert(budget::reset(ref mut meter,0).is_ok);let bool done=work::advance(source,original,ref mut candidate,ref mut w,ref mut meter)?;
        assert(done==w.done && meter.last==4096 && w.visits-visits<=1);if(!done){assert(!work::prepared(ref w).is_ok);}turns+=1;}
    let usize total=meter.total;assert(work::advance(source,original,ref mut candidate,ref mut w,ref mut meter).is_ok && total==meter.total);
    let usize id=work::prepared(ref w)?;*cursor=work::observed(ref w);*original=candidate;return .ok(id);
}
fn void compare(ref u8[] source,lexer::State start,ref properties::Catalog initial){
    var lexer::State a=start;var lexer::State b=start;var properties::Catalog x=*initial;var properties::Catalog y=*initial;
    switch(raw::parse(source,ref mut a,ref mut x)){
        case .ok(id):{switch(run(source,ref mut b,ref mut y)){case .ok(other):{assert(id==other);}case .err(_):{assert(false);}};}
        case .err(e):{switch(run(source,ref mut b,ref mut y)){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};}
    };token(a,b);catalog(ref x,ref y);
}
fn void plain(ref u8[] source,ref properties::Catalog initial){var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);compare(source,s,initial);}
@test fn void wrapper_stack_catalog_transactions_qualification_and_exact_errors(){
    var properties::Catalog c=properties::empty();plain(b"i32",ref c);plain(b"bool[4096]",ref c);plain(b"i64[1]",ref c);
    plain(b"Buffer",ref c);plain(b"bytes::Buffer",ref c);plain(b"brownie /*c*/ :: bytes :: Buffer",ref c);
    plain(b"Result<Option<i64[4096]>,Buffer>",ref c);plain(b"Option<Result<Option<Result<Buffer,u8[4096]>>,i64>>",ref c);
    plain(b"Option<i32>>tail",ref c);plain(b"i32 >> 1",ref c);
    plain(b"Option<Option<Option<Option<Option<i32>>>>>",ref c);plain(b"Result<i32,Option<Option<Option<Option<i32>>>>>",ref c);
    plain(b"Result<Buffer,Nope>",ref c);plain(b"Option<i32",ref c);plain(b"Result<i32 bool>",ref c);plain(b"Option<Option<i32>> @",ref c);
    plain(b"i32[0]",ref c);plain(b"u8[4097]",ref c);plain(b"usize[18446744073709551615]",ref c);plain(b"i32[2][3]",ref c);
    plain(b"Buffer[2]",ref c);plain(b"Option<i32>[2]",ref c);plain(b"ref i32",ref c);plain(b"void",ref c);plain(b"i32[-1]",ref c);
    plain(b"i32[]",ref c);plain(b"Option<i32>=",ref c);plain(b"other::Buffer",ref c);plain(b"bytes x",ref c);plain(b"bytes:Buffer",ref c);
    plain(b"brownie::other::Buffer",ref c);plain(b"bytes::Buffer::tail",ref c);plain(b"bytes /*",ref c);
    let ref u8[] qualified=b"xxx bytes :: Buffer;";var lexer::State s=switch(lexer::scoped(qualified,4,qualified.len,false)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(lexer::next(qualified,ref mut s).is_ok && s.kind==5);compare(qualified,s,ref c);
    let ref u8[] bad=b"xxx bytes :: Buffer::tail;";s=switch(lexer::scoped(bad,4,bad.len,false)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(lexer::next(bad,ref mut s).is_ok && s.kind==5);compare(bad,s,ref c);
    let ref u8[] nominal=b"module main;struct A{i32 x;}struct B{A a;}fn Option<Result<A,B>> main(){}";
    let structs::Table records=switch(structs::scan(nominal)){case .ok(v):{v}case .err(_):{assert(false);return;}};c.records=records.layouts;s=lexer::empty();
    assert(lexer::next(nominal,ref mut s).is_ok);while(!lexer::equal(nominal[s.begin..s.end],b"Option")){assert(lexer::next(nominal,ref mut s).is_ok);}compare(nominal,s,ref c);
    c=properties::empty();c.count=64;var usize i=0;while(i<64){c.nodes[i]=properties::Node{.kind=1,.first=1,.second=0,.extent=0};i+=1;}
    plain(b"i32",ref c);plain(b"Option<i32>",ref c);c.nodes[63].second=1;plain(b"Unknown",ref c);c.count=65;plain(b"i32",ref c);
}
