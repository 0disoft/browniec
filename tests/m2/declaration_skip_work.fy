module tests::m2::declaration_skip_work;
import declaration_skip_work as work;
import struct_source as records;
import lexer as lexer;
import errors as errors;
import metadata_budget as budget;
fn Result<usize,errors::Error> body_raw(ref u8[] source,ref mut lexer::State s,u8 mode,ref mut usize end){
    if(mode==2){let usize keyword=lexer::word(source,s,b"fn")?;
        while(s.kind!=123){if(s.kind==0 || s.kind==125){return .err(errors::make(2,s.begin));}let usize next=lexer::next(source,s)?;}
        let usize open=lexer::next(source,s)?;}
    var usize depth=1;
    while(depth!=0){if(s.kind==0){return .err(errors::make(2,s.begin));}
        if(s.kind==123){depth+=1;if(depth>33){return .err(errors::make(4,s.begin));}}
        if(s.kind==125){depth-=1;if(depth==0){*end=s.begin;}}
        let usize next=lexer::next(source,s)?;}
    return .ok(0);
}
fn void state(ref lexer::State a,ref lexer::State b){
    assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end && a.kind==b.kind && a.tokens==b.tokens &&
        a.value==b.value && a.min_magnitude==b.min_magnitude && a.context==b.context);
}
fn Result<usize,errors::Error> run(ref u8[] source,ref mut lexer::State s,u8 mode,ref mut usize end){
    var work::State w=if(mode==1){work::structure(*s)}else if(mode==2){work::function(*s)}else{work::body(*s)};
    var budget::State meter=budget::empty();var usize turns=0;assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<4000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize cursor=w.token.cursor;let usize fields=w.fields;let usize depth=w.depth;
        let usize visits=w.scan.scan.visits;let u8 lexical=w.scan.phase;let usize inner=w.scan.scan.inner;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.token.cursor==cursor && w.fields==fields && w.depth==depth &&
            w.scan.scan.visits==visits && w.scan.phase==lexical && w.scan.scan.inner==inner && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);
        switch(work::advance(source,ref mut w,ref mut meter)){
            case .ok(done):{assert(done==w.done && meter.last==4096);}
            case .err(e):{*s=work::observed(ref w);return .err(e);}};turns+=1;
    }
    let usize total=meter.total;assert(work::advance(source,ref mut w,ref mut meter).is_ok && meter.total==total);
    *end=w.end;*s=work::observed(ref w);return work::prepared(ref w);
}
fn void compare(ref u8[] source,u8 mode,bool scoped){
    var lexer::State a=lexer::empty();if(scoped){a=switch(lexer::scoped(source,0,source.len,false)){
        case .ok(v):{v}case .err(_):{assert(false);lexer::empty()}};}
    assert(lexer::next(source,ref mut a).is_ok);var lexer::State b=a;var usize expected_end=0;var usize actual_end=0;
    let Result<usize,errors::Error> expected=if(mode==1){records::skip(source,ref mut a)}else{body_raw(source,ref mut a,mode,ref mut expected_end)};
    let Result<usize,errors::Error> actual=run(source,ref mut b,mode,ref mut actual_end);state(ref a,ref b);
    switch(expected){case .ok(value):{switch(actual){case .ok(got):{assert(got==value);if(mode!=1){assert(expected_end==actual_end);}}
            case .err(_):{assert(false);}};}
        case .err(e):{switch(actual){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};}};
}
@test fn void struct_skip_fields_and_exact_syntax_diagnostics_match(){
    compare(b"struct S{i32 x;P p;} after",1,false);compare(b"struct S{m::P p;} after",1,true);
    compare(b"struct S{}",1,false);compare(b"struct if{i32 x;}",1,false);compare(b"struct S i32 x;",1,false);
    compare(b"struct S{Option<i32> x;}",1,false);compare(b"struct S{i32[2] x;}",1,false);
    compare(b"struct S{123 x;}",1,false);compare(b"struct S{i32 if;}",1,false);compare(b"struct S{i32 x}",1,false);
    compare(b"struct S{i32 x;",1,false);compare(b"struct S{i32 x;} \xff",1,false);
    compare(b"struct S{i32 a;i32 b;i32 c;i32 d;i32 e;i32 f;i32 g;i32 h;i32 i;i32 j;i32 k;i32 l;i32 m;i32 n;i32 o;i32 p;}",1,false);
    compare(b"struct S{i32 a;i32 b;i32 c;i32 d;i32 e;i32 f;i32 g;i32 h;i32 i;i32 j;i32 k;i32 l;i32 m;i32 n;i32 o;i32 p;i32 q;}",1,false);
}
@test fn void function_and_signature_body_skip_preserve_braces_and_depth_limit(){
    compare(b"fn i32 f(){return b\"}\";/*}*/{}} after",2,false);compare(b"fn ignored ? x(){} after",2,false);
    compare(b"fn i32 f()",2,false);compare(b"fn }",2,false);compare(b"fn f(){",2,false);
    compare(b"{x;} } after",3,false);compare(b"} \xff",3,false);compare(b"{",3,false);
    var u8[67] source=[32;67];var usize i=0;while(i<32){source[i]=123;i+=1;}
    while(i<65){source[i]=125;i+=1;}compare(ref source,3,false);
    source[32]=123;compare(ref source,3,false);
}
@test fn void long_field_names_and_comment_scans_yield_inside_skip(){
    var u8[4096] source=[65;4096];let ref u8[] prefix=b"struct S{i32 ";var usize i=0;
    while(i<prefix.len){source[i]=prefix[i];i+=1;}source[4094]=59;source[4095]=125;compare(ref source,1,false);
    source=[32;4096];source[0]=47;source[1]=42;source[4093]=42;source[4094]=47;source[4095]=125;
    compare(ref source,3,false);
}
