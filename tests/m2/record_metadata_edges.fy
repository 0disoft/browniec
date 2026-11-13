module tests::m2::record_metadata_edges;
import struct_value_source as values;
import record_field_source_work as fields;
import source_context as context;
import lexer as lexer;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
import std::bytes as bytes;
fn u32 word(usize a,usize b,usize extra){var usize value=a|(b<<13)|extra;var u32 result=0;var u32 bit=1;
    while(value!=0){if((value&1)!=0){result|=bit;}value>>=1;if(value!=0){bit<<=1;}}return result;}
@test fn void long_field_lookup_yields_in_single_and_scoped_sources(){
    var bytes::Buffer data=bytes::empty();assert(bytes::append(ref mut data,b"module main;struct P{i32 ").is_ok);
    var usize i=0;while(i<200){assert(bytes::append(ref mut data,b"a").is_ok);i+=1;}
    assert(bytes::append(ref mut data,b";}fn i32 main(){return ").is_ok);let usize begin=bytes::view(ref data).len;
    i=0;while(i<200){assert(bytes::append(ref mut data,b"a").is_ok);i+=1;}
    let usize end=bytes::view(ref data).len;assert(bytes::append(ref mut data,b";}").is_ok);let ref u8[] source=bytes::view(ref data);
    var ir::Program p=ir::empty();p.records.layouts.count=1;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=1;
    var context::Table scope=context::empty();var usize mode=0;
    while(mode<2){if(mode==1){scope.modules=1;scope.ends[0]=word(0,0,source.len);scope.record_count=1;scope.records[0]=word(19,20,0);}
        assert(values::field_raw(source,ref p,0,begin,end,ref scope).is_ok);
        var fields::State w=fields::begin(0,begin,end);var budget::State meter=budget::empty();var usize turns=0;var usize spelling_steps=0;
        assert(!fields::prepared(ref w).is_ok);
        while(!w.done){assert(turns<100000);let u8 phase=w.phase;let usize row=w.row;let usize compared=w.compared;
            assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);
            assert(fields::advance(source,ref p,ref scope,ref mut w,ref mut meter).is_ok && w.phase==phase && w.row==row && w.compared==compared);
            assert(budget::reset(ref mut meter,0).is_ok && fields::advance(source,ref p,ref scope,ref mut w,ref mut meter).is_ok);
            if(phase==5){assert(w.compared-compared<=64);spelling_steps+=1;}turns+=1;}
        assert(w.result==0 && spelling_steps==4);let usize total=meter.total;
        assert(fields::advance(source,ref p,ref scope,ref mut w,ref mut meter).is_ok && meter.total==total);mode+=1;}
}
fn void path_case(ref u8[] tail,usize hops,bool scalar,bool success){
    var bytes::Buffer data=bytes::empty();assert(bytes::append(ref mut data,b"module main;struct P{P a;}fn i32 main(){return p").is_ok);
    var usize i=0;while(i<hops){assert(bytes::append(ref mut data,b".a").is_ok);i+=1;}
    assert(bytes::append(ref mut data,tail).is_ok && bytes::append(ref mut data,b";}").is_ok);let ref u8[] source=bytes::view(ref data);
    var lexer::State a=lexer::empty();while(a.kind!=2 || !lexer::equal(source[a.begin..a.end],b"return")){assert(lexer::next(source,ref mut a).is_ok);}
    assert(lexer::next(source,ref mut a).is_ok && lexer::next(source,ref mut a).is_ok);var lexer::State b=a;
    var ir::Program p=ir::empty();p.records.layouts.count=1;p.records.layouts.fields[0]=1;p.records.layouts.kinds[0]=if(scalar){0}else{1};p.records.layouts.types[0]=if(scalar){1}else{0};
    let context::Table scope=context::empty();let Result<values::Leaf,errors::Error> x=values::path_raw(source,ref mut a,ref p,0,7,ref scope);
    let Result<values::Leaf,errors::Error> y=values::path(source,ref mut b,ref p,0,7,ref scope);
    assert(x.is_ok==success && y.is_ok==success && a.kind==b.kind && a.begin==b.begin && a.end==b.end && a.cursor==b.cursor && a.tokens==b.tokens);
    switch(x){case .ok(v):{switch(y){case .ok(z):{assert(v.ordinal==z.ordinal && v.tag==z.tag && v.record==z.record);}case .err(_):{assert(false);}};}
        case .err(e):{switch(y){case .ok(_):{assert(false);}case .err(z):{assert(e.kind==z.kind && e.offset==z.offset);}};}};
}
@test fn void path_depth_double_dot_and_lookahead_errors_keep_raw_tokens(){
    path_case(b"",16,false,true);path_case(b"",17,false,false);
    path_case(b"..",1,true,true);path_case(b".missing",1,true,false);path_case(b".@",1,true,false);
}
