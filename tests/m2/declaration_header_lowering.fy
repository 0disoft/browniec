module tests::m2::declaration_header_lowering;
import declaration_header_work as headers;
import struct_value_source as records;
import slice_source as slices;
import static_source as statics;
import lexer as lexer;
import locals as locals;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import std::bytes as bytes;
fn void token(ref lexer::State a,ref lexer::State b){assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end && a.tokens==b.tokens &&
    a.kind==b.kind && a.value==b.value && a.min_magnitude==b.min_magnitude && a.context==b.context);}
fn ir::Program fixture(){var ir::Program p=ir::empty();p.function_count=1;p.records.layouts.count=1;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=1;return p;}
fn Result<headers::Prepared,errors::Error> old(ref u8[] source,ref mut lexer::State s,ref locals::Table names,ref ir::Program p,u8 mode,bool mutable,u8 terminator,u8 result_type){
    if(mode==1){return headers::typed_raw(source,s,names,terminator,result_type);}
    if(mode==2){let slices::Header h=slices::declaration_raw(source,s,names,mutable,terminator,result_type)?;
        return .ok(headers::Prepared{.begin=h.begin,.end=h.end,.length=0,.tag=h.element,.exclusive=h.exclusive});}
    if(mode==3){let statics::Header h=statics::header_raw(source,s,names,mutable,terminator,result_type)?;
        return .ok(headers::Prepared{.begin=h.begin,.end=h.end,.length=0,.tag=h.kind,.exclusive=false});}
    let records::Header h=records::header_raw(source,s,p,names,0,mutable,terminator,result_type)?;
    return .ok(headers::Prepared{.begin=h.begin,.end=h.end,.length=0,.tag=0,.exclusive=false});
}
fn Result<headers::Prepared,errors::Error> current(ref u8[] source,ref mut lexer::State s,ref locals::Table names,ref ir::Program p,u8 mode,bool mutable,u8 terminator,u8 result_type){
    if(mode!=4){return headers::prepare(source,s,names,mode,mutable,terminator,result_type);}
    let records::Header h=records::header(source,s,p,names,0,mutable,terminator,result_type)?;
    return .ok(headers::Prepared{.begin=h.begin,.end=h.end,.length=0,.tag=0,.exclusive=false});
}
fn void result(Result<headers::Prepared,errors::Error> x,Result<headers::Prepared,errors::Error> y){switch(x){
    case .ok(a):{assert(switch(y){case .ok(b):{a.begin==b.begin && a.end==b.end && a.length==b.length && a.tag==b.tag && a.exclusive==b.exclusive}case .err(_):{false}});}
    case .err(a):{assert(switch(y){case .ok(_):{false}case .err(b):{a.kind==b.kind && a.offset==b.offset}});}};}
fn void compare(ref u8[] source,u8 mode,usize scenario){var lexer::State a=lexer::empty();assert(lexer::next(source,ref mut a).is_ok);var lexer::State b=a;
    var ir::Program p=fixture();var locals::Table names=locals::empty();var bool mutable=false;var u8 terminator=59;var u8 result_type=1;
    var usize x=0;while(x<source.len && source[x]!=120){x+=1;}
    if(scenario==1 || scenario==3){names.count=if(scenario==1){1}else{64};var usize i=0;while(i<names.count){names.begins[i]=x;names.ends[i]=x+1;i+=1;}}
    if(scenario==2){names.count=64;}if(scenario==4){p.records.count=16;}if(scenario==5){result_type=0;}
    if(scenario==6){terminator=44;}if(scenario==7){mutable=true;}if(scenario==8){p.records.layouts.kinds[511]=1;}if(scenario==9){p.function_count=0;}
    result(old(source,ref mut a,ref names,ref p,mode,mutable,terminator,result_type),current(source,ref mut b,ref names,ref p,mode,mutable,terminator,result_type));token(ref a,ref b);assert(p.count==0 && p.registers==0);
}
@test fn void typed_and_array_headers_keep_raw_delimiters_offsets_and_context_priority(){
    compare(b"i32 x=42",1,0);compare(b"Result<i32,bool> x=.ok(42)",1,0);compare(b"i32[4096] x=42",1,0);
    compare(b"i32[0] x=42",1,0);compare(b"i32[4097] x=42",1,0);compare(b"i32[-1] x=42",1,0);
    compare(b"Option<i32>[2] x=42",1,0);compare(b"i32[2 x=42",1,0);compare(b"i32 x @",1,0);compare(b"i32 x=@",1,0);
    compare(b"Result<i32,usize> x=42",1,0);compare(b"i32 return=42",1,0);
    var usize mode=0;while(mode<8){compare(b"i32[2] x=42",1,mode);mode+=1;}
}
@test fn void reference_and_nominal_headers_preserve_raw_error_order_and_tokens(){
    var usize scenario=0;while(scenario<10){compare(b"ref mut i32[] x=42",2,scenario);compare(b"ref str x=42",3,scenario);
        compare(b"P x=42",4,scenario);scenario+=1;}
    compare(b"ref Option<i32>[] x=42",2,0);compare(b"ref i32[2] x=42",2,0);
    compare(b"ref u8[] x=@",3,0);compare(b"ref mut u8[] x=42",3,0);compare(b"P x @",4,0);compare(b"P x=@",4,0);
}
@test fn void header_protocol_guards_budget_children_and_completion_without_publication(){
    var u8 mode=1;while(mode<=4){let ref u8[] source=if(mode==1){b"Option<i32> x=42"}else if(mode==2){b"ref mut i32[] x=42"}else if(mode==3){b"ref str x=42"}else{b"P x=42"};
        var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);let locals::Table names=locals::empty();let ir::Program p=fixture();
        var headers::State w=headers::begin(s,mode,false,59,1,false);var budget::State meter=budget::empty();var usize turns=0;var bool requested=false;
        assert(!headers::prepared(ref w).is_ok && !headers::resume(ref mut w).is_ok);
        while(!w.done){assert(turns<1000);let u8 phase=w.phase;let lexer::State before=s;let usize compared=w.name.name.compared;
            assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
            assert(headers::advance(source,ref mut s,ref names,ref mut w,ref mut meter).is_ok && w.phase==phase && w.name.name.compared==compared && meter.total==total);token(ref before,ref s);
            assert(budget::reset(ref mut meter,0).is_ok && headers::advance(source,ref mut s,ref names,ref mut w,ref mut meter).is_ok);
            if(w.request==1){requested=true;let lexer::State saved=s;
                assert(budget::reset(ref mut meter,0).is_ok && headers::advance(source,ref mut s,ref names,ref mut w,ref mut meter).is_ok && meter.last==0);token(ref saved,ref s);
                assert(records::declaration_limit(ref p,ref names,0,59,1,w.at).is_ok && headers::resume(ref mut w).is_ok && !headers::resume(ref mut w).is_ok);}
            if(!w.done){assert(!headers::prepared(ref w).is_ok);}assert(names.count==0 && p.count==0 && p.registers==0);turns+=1;}
        assert(requested==(mode==4) && s.kind==1 && s.value==42 && headers::prepared(ref w).is_ok);
        let lexer::State before=s;let usize total=meter.total;assert(headers::advance(source,ref mut s,ref names,ref mut w,ref mut meter).is_ok && meter.total==total);token(ref before,ref s);mode+=1;}
}
fn void executes(ref u8[] source){switch(compiler::compile(source)){case .err(_):{assert(false);}case .ok(p):{
    assert(verifier::verify(ref p).is_ok);assert(switch(vm::run(ref p,16000000)){case .ok(v):{v==42}case .err(_):{false}});}};}
@test fn void source_declarations_publish_after_initializers_and_execute_to_42(){
    let ref u8[] source=b"module main;struct P{i32 x;}fn i32 main(){let i32 a=20;let b=22;var i32[2] numbers=[a,b];let P p=P{.x=numbers[0]+numbers[1]};{let ref i32[] s=ref numbers;if(s[0]!=20){return 0;}}return p.x;}";
    executes(source);
    assert(!compiler::compile(b"module main;fn i32 main(){let i32 x=x;return 42;}").is_ok);
    assert(!compiler::compile(b"module main;fn i32 main(){let x=x;return 42;}").is_ok);
    var bytes::Buffer deep=bytes::empty();assert(bytes::append(ref mut deep,b"module main;fn i32 main(){").is_ok);var usize i=0;
    while(i<32){assert(bytes::append(ref mut deep,b"if(true){").is_ok);i+=1;}
    assert(bytes::append(ref mut deep,b"let Option<i32> x=.some(42);return 42;").is_ok);i=0;
    while(i<32){assert(bytes::append(ref mut deep,b"}else{return 42;}").is_ok);i+=1;}
    assert(bytes::append(ref mut deep,b"}").is_ok);executes(bytes::view(ref deep));

}
