module tests::m2::signature_type_work;
import signature_type_work as work;
import lexer as lexer;
import types as types;
import locals as locals;
import source_context as context;
import struct_source as records;
import array_source as arrays;
import cells as cells;
import std::num as num;
import errors as errors;
import metadata_budget as budget;
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn Result<work::Annotation,errors::Error> raw(ref u8[] source,ref context::Table scope,ref mut lexer::State s,bool allow_void){
    let bool nothing=allow_void && word(source,s,b"void");let bool slice=word(source,s,b"ref");var u8 element=0;
    if(slice){let usize next=lexer::next(source,s)?;let bool exclusive=word(source,s,b"mut");
        if(exclusive){let usize access=lexer::next(source,s)?;}element=types::parse_raw(source,s)?;
        if(!types::scalar(element)){return .err(errors::make(3,s.begin));}if(exclusive){element|=128;}
        let usize open=lexer::punctuation(source,s,91)?;let usize close=lexer::punctuation(source,s,93)?;}
    var u8 tag=0;var u8 record=0;var usize length=0;
    if(!slice){if(nothing){let usize next=lexer::next(source,s)?;tag=13;}
        else{if((s.kind==2 || s.kind==5) && !locals::reserved(source[s.begin..s.end])){
                let usize id=if(scope.modules!=0){context::lookup_raw(source,scope,s.begin,s.end,true)}
                    else{let records::Location found=records::locate(source,s.begin,s.end,32)?;found.record};
                if(id>=32){return .err(errors::make(3,s.begin));}
                record=switch(num::u8_from_i64(cells::pack(id+1,s.begin)?)){case .ok(v):{v}case .err(_):{return .err(errors::make(4,s.begin));}};
            }
            if(record==0){tag=types::parse_raw(source,s)?;}else{let usize next=lexer::next(source,s)?;}
            if(record!=0 && s.kind==60){return .err(errors::make(3,s.begin));}
        }}
    if(s.kind==91){if(!types::scalar(tag)){return .err(errors::make(3,s.begin));}length=arrays::length(source,s)?;}
    return .ok(work::Annotation{.tag=tag,.record=record,.length=length,.slice=slice,.element=element});
}
fn void state(ref lexer::State a,ref lexer::State b){
    assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end && a.kind==b.kind && a.tokens==b.tokens &&
        a.value==b.value && a.min_magnitude==b.min_magnitude && a.context==b.context);
}
fn Result<work::Annotation,errors::Error> run(ref u8[] source,ref context::Table scope,ref mut lexer::State s,bool allow_void,usize unscoped_record){
    var work::State w=work::begin(*s,allow_void);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<2000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize cursor=w.token.cursor;let u8 lexical=w.scan.phase;
        let u8 primitive=w.primitive.phase;let u8 name=w.name.phase;let bool request=w.request_record;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,scope,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.token.cursor==cursor && w.scan.phase==lexical && w.primitive.phase==primitive &&
            w.name.phase==name && w.request_record==request && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);
        if(w.request_record){assert(work::advance(source,scope,ref mut w,ref mut meter).is_ok && meter.last==0);
            // Inject the explicit discovery response; production discovery is
            // deliberately not called or claimed bounded by this leaf test.
            assert(budget::admit(ref mut meter,4096,0).is_ok);
            switch(work::resolved_record(ref mut w,unscoped_record)){case .ok(_):{}case .err(e):{*s=work::observed(ref w);return .err(e);}};
        }else{switch(work::advance(source,scope,ref mut w,ref mut meter)){
            case .ok(done):{assert(done==w.done && meter.last==4096);}
            case .err(e):{*s=work::observed(ref w);return .err(e);}};}
        turns+=1;
    }
    let usize total=meter.total;assert(work::advance(source,scope,ref mut w,ref mut meter).is_ok && meter.total==total);
    *s=work::observed(ref w);return work::prepared(ref w);
}
fn void same(ref u8[] source,ref context::Table scope,usize cursor,bool allow_void,usize supplied){
    var lexer::State a=lexer::empty();
    if(scope.modules!=0){a=switch(lexer::scoped(source,0,source.len,false)){case .ok(v):{v}case .err(_):{assert(false);lexer::empty()}};}
    a.cursor=cursor;assert(lexer::next(source,ref mut a).is_ok);var lexer::State b=a;
    let Result<work::Annotation,errors::Error> expected=raw(source,scope,ref mut a,allow_void);
    let Result<work::Annotation,errors::Error> actual=run(source,scope,ref mut b,allow_void,supplied);state(ref a,ref b);
    switch(expected){case .ok(v):{switch(actual){case .ok(w):{assert(v.tag==w.tag && v.record==w.record && v.length==w.length && v.slice==w.slice && v.element==w.element);}
            case .err(_):{assert(false);}};}
        case .err(e):{switch(actual){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};}};
}
fn void plain(ref u8[] source,bool nothing){let context::Table scope=context::empty();same(source,ref scope,0,nothing,32);}
fn u32 word_span(usize a,usize b){var usize value=a|(b<<13);var u32 result=0;var u32 bit=1;
    while(value!=0){if((value&1)!=0){result|=bit;}value>>=1;if(value!=0){bit<<=1;}}return result;}
fn void nominal(ref u8[] source){var context::Table scope=context::empty();scope.modules=1;scope.ends[0]=word_span(source.len,0);
    scope.record_count=1;scope.records[0]=word_span(source.len-1,source.len);scope.imports=1;scope.aliases[0]=word_span(0,1);
    same(source,ref scope,0,false,32);}
@test fn void scalar_wrapper_array_void_and_borrow_annotations_match(){
    plain(b"i32 x",false);plain(b"Result<bool,i32> x",true);plain(b"u8[4096] x",false);
    plain(b"u32[3][4] x",false);plain(b"void x",true);plain(b"void x",false);
    plain(b"ref mut usize[] x",false);plain(b"ref bool[] x",true);plain(b"ref u8[] x",true);
    plain(b"ref Option<i32>[] x",true);plain(b"ref i32[3] x",false);plain(b"ref i32[] [2] x",false);
    plain(b"Option<i32>[2] x",false);plain(b"void[2] x",true);plain(b"i32[0] x",false);
    plain(b"i32[4097] x",false);plain(b"i32[-1] x",false);plain(b"i32[18446744073709551615] x",false);
    plain(b"i32[3 x",false);plain(b"i32[3] \xff",false);plain(b"ref mut i32[] \xff",true);
}
@test fn void scoped_nominal_queries_and_unscoped_discovery_requests_match(){
    nominal(b"m::P x P");nominal(b"m::P< i32 > x P");nominal(b"m::P[2] x P");nominal(b"m::Q x P");
    nominal(b"m::P x \"\\q\" P");
    let ref u8[] source=b"module main;struct P{i32 x;}fn P f(){}";let context::Table scope=context::empty();
    same(source,ref scope,30,false,0);
    let ref u8[] absent=b"module main;fn Q f(){}";same(absent,ref scope,15,false,32);
}
@test fn void annotations_resume_through_long_intertoken_comments(){
    var u8[4096] source=[32;4096];source[0]=117;source[1]=56;source[2]=47;source[3]=42;
    source[4094]=42;source[4095]=47;plain(ref source,false);
    source[4094]=32;plain(ref source,false);
}
