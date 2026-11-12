module tests::m2::aggregate_probe_lowering;
import aggregate_probe_work as work;
import record_expression_source as records;
import array_expression_source as arrays;
import array_local_source as literals;
import static_source as statics;
import lexer as lexer;
import ir as ir;
import locals as locals;
import functions as functions;
import errors as errors;
import metadata_budget as budget;
import std::bytes as bytes;
import expression_source_work as expressions;
fn Result<work::Plan,errors::Error> oracle(ref u8[] source,ref lexer::State s,ref ir::Program p,ref locals::Table names,ref functions::Table signatures,u8 mode){
    if(mode==1){let records::Plan v=records::inspect_raw(source,s,p,names,signatures)?;return .ok(work::Plan{.groups=v.groups,.record=v.record,.kind=v.kind,.tag=v.tag,.suffix=v.suffix});}
    if(mode==2){let arrays::Plan v=arrays::inspect_raw(source,s,p,names,signatures)?;return .ok(work::Plan{.groups=v.groups,.record=0,.kind=v.kind,.tag=0,.suffix=v.suffix});}
    if(mode==3){let literals::Projection v=literals::projection_raw(source,s)?;return .ok(work::Plan{.groups=v.groups,.record=0,.kind=v.kind,.tag=0,.suffix=0});}
    let bool value=if(mode==4){statics::grouped_projection_raw(source,s,names)?}else{literals::is_repeated_raw(source,s)?};
    return .ok(work::Plan{.groups=0,.record=0,.kind=if(value){1}else{0},.tag=0,.suffix=0});
}
fn void compare(ref u8[] tail,u8 mode,usize encoding){compare_case(tail,mode,encoding,false);}
fn void compare_case(ref u8[] tail,u8 mode,usize encoding,bool scoped){let ref u8[] prefix=b"module main; struct Inner { i32 x; } struct Pair { Inner a; i32 y; } fn i32 main(){return ";
    var bytes::Buffer buffer=bytes::empty();assert(bytes::append(ref mut buffer,prefix).is_ok && bytes::append(ref mut buffer,tail).is_ok && bytes::append(ref mut buffer,b"}").is_ok);
    compare_source(bytes::view(ref buffer),mode,encoding,scoped);
}
fn void compare_source(ref u8[] source,u8 mode,usize encoding,bool scoped){
    var lexer::State s=lexer::empty();while(s.kind!=2 || !lexer::equal(source[s.begin..s.end],b"return")){assert(lexer::next(source,ref mut s).is_ok);}
    assert(lexer::next(source,ref mut s).is_ok);let lexer::State before=s;var lexer::State root=s;
    while(root.kind==40){assert(lexer::next(source,ref mut root).is_ok);}if(root.kind==2 && lexer::equal(source[root.begin..root.end],b"ref")){assert(lexer::next(source,ref mut root).is_ok);}
    var locals::Table names=locals::empty();if(encoding<256){names.count=1;names.begins[0]=root.begin;names.ends[0]=root.end;names.registers[0]=encoding;}
    var functions::Table signatures=functions::empty();signatures.count=1;signatures.begins[0]=root.begin;signatures.ends[0]=root.end;signatures.return_records[0]=2;signatures.return_lengths[0]=1;
    if(scoped){signatures.context.modules=1;signatures.context.ends[0]=word(0,0,source.len);signatures.context.record_count=2;
        var lexer::State t=lexer::empty();var usize count=0;while(count<2){assert(lexer::next(source,ref mut t).is_ok);
            if(t.kind==2 && lexer::equal(source[t.begin..t.end],b"struct")){assert(lexer::next(source,ref mut t).is_ok);signatures.context.records[count]=word(t.begin,t.end,0);count+=1;}}
        signatures.context.function_count=1;signatures.context.functions[0]=word(root.begin,root.end,0);
    }
    var ir::Program p=ir::empty();p.records.layouts.count=2;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=1;
    p.records.layouts.fields[1]=2;p.records.layouts.kinds[16]=1;p.records.layouts.types[16]=0;p.records.layouts.types[17]=1;
    p.records.count=1;p.records.records[0]=1;p.arrays.count=1;
    let Result<work::Plan,errors::Error> expected=oracle(source,ref s,ref p,ref names,ref signatures,mode);let bool succeeds=expected.is_ok;
    var work::State w=work::begin(s,mode);var budget::State meter=budget::empty();var usize turns=0;var bool failed=false;
    assert(!work::prepared(ref w).is_ok);while(!w.done && !failed){assert(turns<20000);let usize visits=w.visits;let usize cursor=w.look.cursor;let u8 phase=w.phase;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref p,ref names,ref signatures,ref mut w,ref mut meter).is_ok && w.visits==visits && w.look.cursor==cursor && w.phase==phase && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);switch(work::advance(source,ref p,ref names,ref signatures,ref mut w,ref mut meter)){
            case .ok(_):{}case .err(e):{switch(expected){case .ok(_):{assert(false);}case .err(z):{assert(e.kind==z.kind && e.offset==z.offset);}};failed=true;}};
        assert(w.visits-visits<=1 && meter.last<=4096);turns+=1;}
    assert(s.cursor==before.cursor && s.tokens==before.tokens && s.context==before.context && p.count==0 && p.registers==0 && names.count==if(encoding<256){1}else{0});
    if(failed){assert(!succeeds && !work::prepared(ref w).is_ok);return;}assert(succeeds);
    let work::Plan v=switch(work::prepared(ref w)){case .ok(v):{v}case .err(_):{work::Plan{.groups=99,.record=99,.kind=99,.tag=99,.suffix=99}}};
    switch(expected){case .err(_):{assert(false);}case .ok(z):{
        if(mode==1){assert(v.kind==z.kind && v.record==z.record && v.groups==z.groups && v.tag==z.tag && v.suffix==z.suffix);}
        else if(mode==2){assert(v.kind==z.kind && v.groups==z.groups && v.suffix==z.suffix);}
        else if(mode==3){assert(v.groups==z.groups && z.kind==if(v.suffix==91 || v.suffix==46){v.suffix}else{0});}else{assert(v.kind==z.kind);}}};
    let usize total=meter.total;assert(work::advance(source,ref p,ref names,ref signatures,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void record_and_array_probes_stage_nominal_fields_groups_and_owner_checks(){
    compare(b"(Pair{.a=Inner{.x=1},.y=42}).y;",1,256);compare(b"((Pair{.a=Inner{.x=1},.y=42}).a).x;",1,256);
    compare(b"(p).a.x;",1,144);compare(b"(p).a.bad;",1,144);compare(b"(p).y.x;",1,144);compare(b"(p).y..;",1,144);
    compare(b"((p).a).x;",1,144);compare(b"(p+1).y;",1,144);compare(b"(p).y;",1,159);
    compare(b"(make()).a.x;",1,256);compare(b"(Pair{.a=Inner{.x=1},.y=42}).;",1,256);
    compare(b"((a))[0];",2,128);compare(b"(a).len;",2,128);compare(b"(a+1)[0];",2,128);compare(b"(a)[0];",2,143);
    compare(b"(make(1,(2)))[0];",2,256);compare(b"([1,[2]])[0];",2,256);compare(b"(a /*",2,128);
}
@test fn void literal_static_and_separator_probes_preserve_suffixes_and_error_offsets(){
    compare(b"(([1,2]))[0];",3,256);compare(b"([1;f(2)])[0];",3,256);compare(b"([1]+1)[0];",3,256);compare(b"[1,2]+1;",3,256);
    compare(b"([1,2);",3,256);compare(b"(a)[0];",3,128);
    compare(b"((ref v))[0];",4,192);compare(b"(v+1).len;",4,208);compare(b"(1)[0];",4,256);
    compare(b"(text(\"abc\"))[0];",4,256);compare(b"(\"abc\")[0];",4,256);compare(b"(ref v",4,192);
    compare(b"[if(true){1}else{2};3];",5,256);compare(b"[f(1,2),3];",5,256);compare(b"[];",5,256);compare(b"[};",5,256);
}

fn u32 word(usize a,usize b,usize extra){var usize value=a|(b<<13)|extra;var u32 result=0;var u32 bit=1;
    while(value!=0){if((value&1)!=0){result|=bit;}value>>=1;if(value!=0){bit<<=1;}}return result;}
@test fn void scoped_nominal_location_and_field_restores_match_raw_classification(){
    compare_case(b"(Pair{.a=Inner{.x=1},.y=42}).a.x;",1,256,true);
    compare_case(b"(p).a.x;",1,144,true);compare_case(b"(p).a.missing;",1,144,true);
    compare_case(b"(make()).y;",1,256,true);compare_case(b"(make())[0];",2,256,true);
}
fn void first_dispatch(ref u8[] source,usize encoding,u8 lane){var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    let lexer::State before=s;var ir::Program p=ir::empty();p.arrays.count=1;
    var functions::Table signatures=functions::empty();signatures.literals.enabled=true;var locals::Table names=locals::empty();
    if(encoding<256){names.count=1;names.begins[0]=1;names.ends[0]=2;names.registers[0]=encoding;}
    var expressions::Bank bank=expressions::empty_bank();var expressions::State w=expressions::begin(0,1,1);var budget::State meter=budget::empty();var usize turns=0;
    while(!w.waiting){assert(turns<10000);let expressions::Frame before_frame=expressions::current(ref w);let usize visits=w.visits;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(expressions::advance(source,ref mut s,ref mut p,ref names,ref signatures,ref mut bank,ref mut w,ref mut meter).is_ok);
        let expressions::Frame after_frame=expressions::current(ref w);assert(before_frame.phase==after_frame.phase && visits==w.visits && total==meter.total);
        assert(budget::reset(ref mut meter,0).is_ok && expressions::advance(source,ref mut s,ref mut p,ref names,ref signatures,ref mut bank,ref mut w,ref mut meter).is_ok);
        assert(s.cursor==before.cursor && s.tokens==before.tokens && p.count==0 && p.registers==0);turns+=1;}
    assert(turns>6 && w.request==1 && bank.route.lane==lane);
}
@test fn void common_driver_yields_before_conditional_and_projection_dispatch(){
    first_dispatch(b"(if(true){42}else{0});",256,5);first_dispatch(b"(a)[0];",128,7);
    first_dispatch(b"([1,2])[0];",256,8);first_dispatch(b"[1,2][0];",256,8);first_dispatch(b"[1,2];",256,10);
    first_dispatch(b"(b\"ab\")[0];",256,9);first_dispatch(b"(if(true){20}else{0}+22);",256,1);
}

@test fn void long_field_names_resume_across_chunks_in_single_and_scoped_catalogs(){
    var bytes::Buffer b=bytes::empty();assert(bytes::append(ref mut b,b"module main;struct Inner{i32 x;}struct Pair{Inner a;i32 ").is_ok);
    var usize i=0;while(i<200){assert(bytes::append(ref mut b,b"a").is_ok);i+=1;}
    assert(bytes::append(ref mut b,b";}fn i32 main(){return (p).").is_ok);i=0;while(i<200){assert(bytes::append(ref mut b,b"a").is_ok);i+=1;}
    assert(bytes::append(ref mut b,b";}").is_ok);compare_source(bytes::view(ref b),1,144,false);compare_source(bytes::view(ref b),1,144,true);
}
