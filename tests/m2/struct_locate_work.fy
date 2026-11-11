module tests::m2::struct_locate_work;
import struct_locate_work as work;
import struct_source as raw;
import metadata_budget as budget;
import errors as errors;
@test fn void declarations_function_skips_and_selected_early_returns_match(){
    same(b"module main;struct P{i32 x;}fn i32 f(){return 1;}struct Q{P p;}",0,0,0);
    same(b"module main;struct P{i32 x;}fn i32 f(){return 1;}struct Q{P p;}",0,0,1);
    same(b"module main;struct P{i32 x;}fn i32 f(){return 1;}struct Q{P p;}",0,0,2);
    same(b"module main;struct P{}",19,20,32);
    same(b"module main;struct if{i32 x;}",0,0,0);
    same(b"module main;struct P{Option<i32> x;}",0,0,0);
    same(b"module main;",0,0,0);
}
@test fn void absent_queries_and_exact_header_or_prior_declaration_errors_match(){
    same(b"module other;struct P{i32 x;}",0,0,0);same(b"module main struct P{i32 x;}",0,0,0);
    same(b"module main;struct P{Option<i32> x;}",0,0,1);
    same(b"module main;struct P{i32 x;",0,0,1);
    same(b"module main;fn i32 f(){return 1;",0,0,0);
    same(b"module main;let x;",0,0,0);
    same(b"module main;struct P{i32 x;}fn Q f(){}",30,31,32);
    same(b"module main;struct P{Option<i32> x;}fn Q f(){}",38,39,32);
    same(b"module main;struct P{\xff}",0,0,0);
}
@test fn void long_nominal_spelling_comparisons_and_late_mismatch_resume(){
    var u8[4096] source=[32;4096];let ref u8[] prefix=b"module main;struct ";let ref u8[] middle=b"{i32 x;}//";
    var usize i=0;while(i<prefix.len){source[i]=prefix[i];i+=1;}
    let usize first=prefix.len;while(i<first+1800){source[i]=65;i+=1;}
    var usize j=0;while(j<middle.len){source[i]=middle[j];i+=1;j+=1;}
    let usize query=i;while(i<query+1800){source[i]=65;i+=1;}
    same(ref source,query,query+1800,32);source[query+1799]=66;same(ref source,query,query+1800,32);
}
fn Result<work::Location,errors::Error> run(ref u8[] source,usize a,usize b,usize selected){
    var work::State w=work::begin(a,b,selected);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<5000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize cursor=w.token.cursor;let usize compared=w.compared;let usize visits=w.visits;
        let u8 lexical=w.scan.phase;let u8 skip=w.skip.phase;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.token.cursor==cursor && w.compared==compared && w.visits==visits &&
            w.scan.phase==lexical && w.skip.phase==skip && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);
        switch(work::advance(source,ref mut w,ref mut meter)){
            case .ok(done):{assert(done==w.done && meter.last==4096 && w.visits-visits<=64);}
            case .err(e):{return .err(e);}
        };turns+=1;
    }
    let usize total=meter.total;assert(work::advance(source,ref mut w,ref mut meter).is_ok && meter.total==total);
    return work::prepared(ref w);
}
fn void same(ref u8[] source,usize a,usize b,usize selected){
    let Result<raw::Location,errors::Error> expected=raw::locate(source,a,b,selected);
    let Result<work::Location,errors::Error> actual=run(source,a,b,selected);
    switch(expected){case .ok(v):{switch(actual){case .ok(w):{assert(w.record==v.record && w.body==v.body);}case .err(_):{assert(false);}};}
        case .err(e):{switch(actual){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};}};
}
