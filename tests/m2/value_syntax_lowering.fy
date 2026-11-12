module tests::m2::value_syntax_lowering;
import value_syntax_work as work;
import value_arm_syntax as raw;
import lexer as lexer;
import errors as errors;
import metadata_budget as budget;
import std::bytes as bytes;
fn Result<bool,errors::Error> oracle(ref u8[] source,ref lexer::State s,u8 mode){
    if(mode==1){let raw::Conditional v=raw::conditional_atom_raw(source,s)?;return .ok(v.valid);}
    if(mode==2){return raw::conditional_value_raw(source,s);}if(mode==4){return raw::regular_raw(source,s);}return raw::constructor_atom_raw(source,s);
}
fn void compare(ref u8[] source,u8 mode){var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    let lexer::State before=s;let Result<bool,errors::Error> expected=oracle(source,ref s,mode);let bool succeeds=expected.is_ok;
    var work::State w=work::begin(s,mode);var budget::State meter=budget::empty();var usize turns=0;var bool failed=false;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done && !failed){assert(turns<10000);let usize used=w.used;let usize visits=w.visits;let usize cursor=w.look.cursor;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut w,ref mut meter).is_ok && w.used==used && w.visits==visits && w.look.cursor==cursor && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);switch(work::advance(source,ref mut w,ref mut meter)){
            case .ok(_):{}case .err(e):{switch(expected){case .ok(_):{assert(false);}case .err(z):{assert(e.kind==z.kind && e.offset==z.offset);}};failed=true;}};
        assert(w.visits-visits<=1 && meter.last<=4096);turns+=1;
    }
    assert(s.cursor==before.cursor && s.begin==before.begin && s.tokens==before.tokens && s.context==before.context);
    if(failed){assert(!succeeds && !work::prepared(ref w).is_ok);return;}assert(succeeds);
    let bool value=switch(work::prepared(ref w)){case .ok(v):{v}case .err(_):{false}};
    assert(switch(expected){case .ok(v):{value==v}case .err(_):{false}});
    if(mode==1){let raw::Conditional v=switch(raw::conditional_atom_raw(source,ref s)){case .ok(v):{v}case .err(_):{raw::Conditional{.valid=false,.groups=99,.suffix=99}}};
        assert(w.groups==v.groups && w.suffix==v.suffix);}
    let usize total=meter.total;assert(work::advance(source,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void conditional_frames_match_raw_values_suffixes_and_malformed_order(){
    compare(b"((if(true){let i32 n=1; while(false){n=2;} n}else if(false){}else{0}))+22;",1);
    compare(b"(if(true){f(1); if(false){var i32 a=0;} 42}else{0}+22);",1);
    compare(b"if(true){if(false){42}else{0}}else{};",2);
    compare(b"if(true){return 42;}else{break;};",2);
    compare(b"(switch(1){case 1:{42} default:{0}}).is_ok;",1);
    compare(b"if(true){(a[if(true){0}else{1}]).x=2; 42}else{0};",2);
    compare(b"if(true){for(;false;){f();} {let i32 a=0;} continue;}else{}",2);
    compare(b"(if(true){42}else{0}];",1);compare(b"if true){42}",2);
    compare(b"if(true){(a[])=1;42}else{0}",2);compare(b"if(true){(a[(])=1;42}",2);
    compare(b"if(true){let i32 a=0 42}",2);compare(b"if(true){42}else /*",1);
    compare(b"(switch(1){case 1:{42}",1);compare(b"if(true){if(false){}else{42}",2);
}
@test fn void regular_and_constructor_children_preserve_assignment_and_value_boundaries(){
    compare(b"(a[if(true){0}else{1}]).x += 1;",4);compare(b"(a[]) = 1;",4);
    compare(b"a[0] = 1;",4);compare(b"a[0] + 1;",4);compare(b"a.x.y *= 2;",4);
    compare(b"f(1,(2));42",4);compare(b"f(1,(2))+42",4);compare(b"return 42;",4);
    compare(b"((.some(f(42))))}",12);compare(b".none}",12);compare(b".err(42)?}",12);
    compare(b".ok(42) + 1}",12);compare(b".ok 42}",12);compare(b".some( /*",12);
    compare(b"((((((((((((((((((((((((((((((((a))))))))))))))))))))))))))))))))=1;",4);
    compare(b"(((((((((((((((((((((((((((((((((a)))))))))))))))))))))))))))))))))=1;",4);
    compare(b"(a.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x)=1;",4);
    compare(b"(a.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x)=1;",4);
    compare(b"a.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x=1;",4);compare(b"a.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x.x=1;",4);
}

@test fn void conditional_group_body_and_index_depth_boundaries_keep_raw_error_order(){
    var usize groups=31;while(groups<=33){var bytes::Buffer b=bytes::empty();var usize i=0;
        while(i<groups){assert(bytes::append(ref mut b,b"(").is_ok);i+=1;}assert(bytes::append(ref mut b,b"if(true){42}else{0}").is_ok);
        i=0;while(i<groups){assert(bytes::append(ref mut b,b")").is_ok);i+=1;}assert(bytes::append(ref mut b,b";").is_ok);compare(bytes::view(ref b),1);groups+=1;}
    var usize levels=16;while(levels<=17){var bytes::Buffer b=bytes::empty();var usize i=0;
        while(i<levels){assert(bytes::append(ref mut b,b"if(true){").is_ok);i+=1;}assert(bytes::append(ref mut b,b"42").is_ok);
        i=0;while(i<levels){assert(bytes::append(ref mut b,b"}").is_ok);i+=1;}compare(bytes::view(ref b),2);levels+=1;}
    var usize depth=31;while(depth<=32){var bytes::Buffer b=bytes::empty();assert(bytes::append(ref mut b,b"(a[").is_ok);var usize i=0;
        while(i<depth){assert(bytes::append(ref mut b,b"(").is_ok);i+=1;}assert(bytes::append(ref mut b,b"0").is_ok);
        i=0;while(i<depth){assert(bytes::append(ref mut b,b")").is_ok);i+=1;}assert(bytes::append(ref mut b,b"])=1;").is_ok);compare(bytes::view(ref b),4);depth+=1;}
}
