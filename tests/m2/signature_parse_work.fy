module tests::m2::signature_parse_work;
import signature_parse_work as work;
import functions as raw;
import lexer as lexer;
import source_context as context;
import errors as errors;
import metadata_budget as budget;
fn void table(ref raw::Table a,ref raw::Table b){
    assert(a.count==b.count && a.entry==b.entry && a.reference_calls==b.reference_calls && a.reference_returns==b.reference_returns && a.output==b.output);
    var usize i=0;while(i<16){assert(a.begins[i]==b.begins[i] && a.ends[i]==b.ends[i] && a.bodies[i]==b.bodies[i] && a.body_ends[i]==b.body_ends[i] &&
        a.arities[i]==b.arities[i] && a.return_types[i]==b.return_types[i] && a.return_lengths[i]==b.return_lengths[i] &&
        a.return_records[i]==b.return_records[i] && a.return_slice_elements[i]==b.return_slice_elements[i] &&
        a.return_slice_inputs[i]==b.return_slice_inputs[i] && a.return_slice_candidates[i]==b.return_slice_candidates[i]);i+=1;}
    i=0;while(i<128){assert(a.param_begins[i]==b.param_begins[i] && a.param_ends[i]==b.param_ends[i] && a.param_types[i]==b.param_types[i] &&
        a.param_lengths[i]==b.param_lengths[i] && a.param_arrays[i]==b.param_arrays[i] && a.param_records[i]==b.param_records[i] &&
        a.param_slices[i]==b.param_slices[i] && a.param_slice_elements[i]==b.param_slice_elements[i]);i+=1;}
}
fn void state(ref lexer::State a,ref lexer::State b){
    assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end && a.kind==b.kind && a.tokens==b.tokens &&
        a.value==b.value && a.min_magnitude==b.min_magnitude && a.context==b.context);
}
fn Result<usize,errors::Error> run(ref u8[] source,ref mut raw::Table t,ref mut lexer::State s){
    var work::State w=work::begin(*s);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<9000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize cursor=w.token.cursor;let usize arity=w.arity;let usize row=w.row;let usize visits=w.visits;
        let u8 lexical=w.scan.phase;let u8 annotation=w.annotation.phase;let u8 locate=w.locate.phase;let u8 body=w.body.phase;
        let usize count=t.count;let usize compared=w.compared;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,t,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.token.cursor==cursor && w.arity==arity && w.row==row && w.visits==visits && w.compared==compared &&
            w.scan.phase==lexical && w.annotation.phase==annotation && w.locate.phase==locate && w.body.phase==body &&
            t.count==count && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);
        switch(work::advance(source,t,ref mut w,ref mut meter)){
            case .ok(done):{assert(done==w.done && meter.last==4096 && w.visits-visits<=64);if(!done){assert(!work::prepared(ref w).is_ok);}}
            case .err(e):{*s=work::observed(ref w);return .err(e);}};turns+=1;
    }
    let usize total=meter.total;assert(work::advance(source,t,ref mut w,ref mut meter).is_ok && meter.total==total);
    *s=work::observed(ref w);return work::prepared(ref w);
}
fn bool one(ref u8[] source,ref mut raw::Table a,ref mut raw::Table b,ref mut lexer::State x,ref mut lexer::State y){
    let Result<usize,errors::Error> expected=raw::signature_untyped_raw(source,x,a);
    let Result<usize,errors::Error> actual=run(source,b,y);state(x,y);table(a,b);
    switch(expected){case .ok(v):{switch(actual){case .ok(w):{assert(v==w);}case .err(_):{assert(false);}};return true;}
        case .err(e):{switch(actual){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};return false;}};return false;
}
fn usize position(ref u8[] source,ref u8[] query){var usize i=0;
    while(i+query.len<=source.len){if(lexer::equal(source[i..i+query.len],query)){return i;}i+=1;}assert(false);return 0;}
fn void trace(ref u8[] source,ref context::Table scope,bool returns,usize count){
    var raw::Table a=raw::empty();a.context=*scope;a.reference_returns=returns;a.count=count;var raw::Table b=a;
    var lexer::State x=lexer::empty();if(scope.modules!=0){x=switch(lexer::scoped(source,0,source.len,false)){
        case .ok(v):{v}case .err(_):{assert(false);lexer::empty()}};}
    x.cursor=position(source,b"fn ");assert(lexer::next(source,ref mut x).is_ok);var lexer::State y=x;
    var usize functions=0;while(x.kind!=0 && functions<18){if(!one(source,ref mut a,ref mut b,ref mut x,ref mut y)){return;}functions+=1;}
    assert(x.kind==0);
}
fn void plain(ref u8[] source,bool returns){let context::Table scope=context::empty();trace(source,ref scope,returns,0);}
fn u32 word(usize a,usize b){var usize value=a|(b<<13);var u32 result=0;var u32 bit=1;
    while(value!=0){if((value&1)!=0){result|=bit;}value>>=1;if(value!=0){bit<<=1;}}return result;}
@test fn void signatures_arrays_wrappers_records_borrows_and_body_spans_match(){
    plain(b"fn i32 main(){return 42;}",false);plain(b"fn void helper(){}fn i32 main(){helper();return 1;}",false);
    plain(b"fn Result<bool,i32> f(i32 a,bool b,u8[3] c){return .ok(b);}",false);
    plain(b"fn ref mut i32[] f(ref mut i32[] a,ref mut i32[] b){return a;}",false);
    plain(b"fn ref u8[] f(){return b\"x\";}",true);
    plain(b"module main;struct P{i32 x;}fn P f(P p){return p;}fn i32 main(){return 1;}",false);
    let ref u8[] source=b"module a;struct P{i32 x;}fn P a(P p){return p;}fn i32 b(){return 1;}";
    var context::Table scope=context::empty();scope.modules=1;scope.ends[0]=word(source.len,0);
    scope.function_count=2;let usize a=position(source,b"a(");let usize b=position(source,b"b(");
    scope.functions[0]=word(a,a+1);scope.functions[1]=word(b,b+1);
    scope.record_count=1;let usize p=position(source,b"P{");scope.records[0]=word(p,p+1);trace(source,ref scope,false,0);
}
@test fn void exact_error_order_partial_metadata_and_late_lexer_state_match(){
    plain(b"fn void main(){}",false);plain(b"fn i32 main(i32 x){}",false);
    plain(b"fn ref u8[] f(){}",false);plain(b"fn ref mut u8[] f(){}",true);
    plain(b"fn i32 f(i32 x,bool x){}",false);plain(b"fn i32 f(i32 x,){}",false);
    plain(b"fn i32 f(i32 a,i32 b,i32 c,i32 d,i32 e,i32 f,i32 g,i32 h,i32 i){}",false);
    plain(b"fn i32 f(){}fn i32 f(){}",false);plain(b"fn Q f(){}",false);
    plain(b"fn Option<u8> f(){}",false);plain(b"fn i32[0] f(){}",false);
    plain(b"fn i32 f(){",false);plain(b"fn i32 f(){} \xff",false);plain(b"fn i32 f(){} \"\\q\"",false);
    let context::Table scope=context::empty();trace(b"fn i32 f(){}",ref scope,false,16);
}
@test fn void long_parameter_and_function_duplicate_comparisons_resume(){
    var u8[4096] source=[32;4096];let ref u8[] prefix=b"fn i32 f(i32 ";let ref u8[] middle=b",i32 ";let ref u8[] end=b"){}";
    var usize i=0;while(i<prefix.len){source[i]=prefix[i];i+=1;}var usize j=0;
    while(j<1000){source[i]=65;i+=1;j+=1;}j=0;while(j<middle.len){source[i]=middle[j];i+=1;j+=1;}
    j=0;while(j<1000){source[i]=65;i+=1;j+=1;}j=0;while(j<end.len){source[i]=end[j];i+=1;j+=1;}
    plain(ref source,false);
    source=[32;4096];let ref u8[] keyword=b"fn i32 ";let ref u8[] body=b"(){}";i=0;var usize f=0;
    while(f<2){j=0;while(j<keyword.len){source[i]=keyword[j];i+=1;j+=1;}
        j=0;while(j<1000){source[i]=65;i+=1;j+=1;}j=0;while(j<body.len){source[i]=body[j];i+=1;j+=1;}f+=1;}
    plain(ref source,false);
}
