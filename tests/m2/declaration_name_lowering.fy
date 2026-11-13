module tests::m2::declaration_name_lowering;
import declaration_name_work as work;
import local_inference as inferred;
import lexer as lexer;
import locals as locals;
import errors as errors;
import metadata_budget as budget;
import std::bytes as bytes;
fn void token(ref lexer::State a,ref lexer::State b){assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end && a.tokens==b.tokens &&
    a.kind==b.kind && a.value==b.value && a.min_magnitude==b.min_magnitude && a.context==b.context);}
fn void header_result(Result<inferred::Header,errors::Error> x,Result<inferred::Header,errors::Error> y){switch(x){
    case .ok(a):{assert(switch(y){case .ok(b):{a.begin==b.begin && a.end==b.end}case .err(_):{false}});}
    case .err(a):{assert(switch(y){case .ok(_):{false}case .err(b):{a.kind==b.kind && a.offset==b.offset}});}};}
fn void compare(ref u8[] source,usize count,bool duplicate){var lexer::State a=lexer::empty();assert(lexer::next(source,ref mut a).is_ok);var lexer::State b=a;
    var locals::Table names=locals::empty();names.count=count;var usize i=0;
    while(i<count){names.begins[i]=if(duplicate){a.begin}else{a.end};names.ends[i]=a.end;i+=1;}
    header_result(inferred::header_raw(source,ref mut a,ref names),inferred::header(source,ref mut b,ref names));token(ref a,ref b);assert(names.count==count);}
@test fn void inferred_headers_preserve_tokens_errors_and_duplicate_before_capacity(){
    compare(b"alpha = 42",0,false);compare(b"alpha 42",0,false);compare(b"alpha = @",0,false);
    compare(b"alpha @",0,false);compare(b"return = 42",0,false);compare(b"42 = 1",0,false);
    compare(b"alpha = 42",1,true);compare(b"alpha = 42",64,true);compare(b"alpha = 42",64,false);
}
fn void follow(ref u8[] source){var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);let lexer::State before=s;
    let Result<bool,errors::Error> x=inferred::follows_raw(source,ref s);let Result<bool,errors::Error> y=inferred::follows(source,ref s);
    switch(x){case .ok(a):{assert(switch(y){case .ok(b):{a==b}case .err(_):{false}});}
        case .err(a):{assert(switch(y){case .ok(_):{false}case .err(b):{a.kind==b.kind && a.offset==b.offset}});}};token(ref before,ref s);}
@test fn void inferred_lookahead_never_publishes_its_cursor(){follow(b"alpha = 42");follow(b"alpha 42");follow(b"alpha @");follow(b"i32 x=42");follow(b"42");var bytes::Buffer large=bytes::empty();assert(bytes::append(ref mut large,b"x=").is_ok);let u8[256] padding=[32;256];var usize i=0;
    while(i<16){assert(bytes::append(ref mut large,ref padding).is_ok);i+=1;}follow(bytes::view(ref large));compare(bytes::view(ref large),0,false);}
@test fn void binder_work_chunks_long_names_and_guards_denied_and_completed_steps(){
    let ref u8[] source=b"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab = 42";var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    let usize first=s.begin;let usize end=s.end;assert(lexer::next(source,ref mut s).is_ok);
    var locals::Table names=locals::empty();names.count=1;names.begins[0]=first;names.ends[0]=end;
    var work::State w=work::begin(s,false,0);var budget::State meter=budget::empty();var usize turns=0;var usize chunks=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<100);let u8 phase=w.phase;let usize row=w.name.row;let usize compared=w.name.compared;let lexer::State before=s;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut s,ref names,ref mut w,ref mut meter).is_ok && w.phase==phase && w.name.row==row && w.name.compared==compared && meter.total==total);token(ref before,ref s);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(source,ref mut s,ref names,ref mut w,ref mut meter).is_ok);
        if(w.name.compared>compared){assert(w.name.compared-compared<=64);chunks+=1;}turns+=1;}
    assert(chunks==4 && names.count==1 && work::prepared(ref w).is_ok && s.kind==1 && s.value==42);
    let lexer::State before=s;let usize total=meter.total;assert(work::advance(source,ref mut s,ref names,ref mut w,ref mut meter).is_ok && meter.total==total);token(ref before,ref s);
}
