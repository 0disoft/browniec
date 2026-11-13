module tests::m2::record_declaration_lowering;
import struct_value_source as values;
import ir as ir;
import locals as locals;
import lexer as lexer;
import source_context as context;
import errors as errors;
fn void same(Result<usize,errors::Error> x,Result<usize,errors::Error> y,bool success){switch(x){
    case .ok(v):{assert(success);switch(y){case .ok(z):{assert(v==z);}case .err(_):{assert(false);}};}
    case .err(e):{assert(!success);switch(y){case .ok(_):{assert(false);}case .err(z):{assert(e.kind==z.kind && e.offset==z.offset);}};}};}
fn u32 word(usize a,usize b,usize extra){var usize value=a|(b<<13)|extra;var u32 result=0;var u32 bit=1;
    while(value!=0){if((value&1)!=0){result|=bit;}value>>=1;if(value!=0){bit<<=1;}}return result;}
@test fn void nominal_lookup_keeps_raw_single_scoped_and_invalid_context_results(){
    let ref u8[] source=b"module main;struct P{i32 x;}fn i32 main(){return 42;}";
    var lexer::State name=lexer::empty();while(name.kind!=2 || !lexer::equal(source[name.begin..name.end],b"P")){assert(lexer::next(source,ref mut name).is_ok);}
    var context::Table scope=context::empty();same(values::named_raw(source,ref name,ref scope),values::named(source,ref name,ref scope),true);
    scope.modules=1;scope.ends[0]=word(0,0,source.len);scope.record_count=1;scope.records[0]=word(name.begin,name.end,0);
    same(values::named_raw(source,ref name,ref scope),values::named(source,ref name,ref scope),true);
    scope.ends[0]=0;same(values::named_raw(source,ref name,ref scope),values::named(source,ref name,ref scope),false);
}
@test fn void declaration_layout_keeps_raw_limit_and_error_precedence(){
    let locals::Table names=locals::empty();var usize mode=0;while(mode<5){var ir::Program p=ir::empty();p.function_count=1;
        p.records.layouts.count=1;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=1;
        if(mode==1){p.records.layouts.kinds[511]=1;}
        if(mode==2){p.records.layouts.kinds[0]=1;p.records.layouts.types[0]=0;}
        if(mode==3){p.records.layouts.count=2;p.records.layouts.fields[0]=16;p.records.layouts.fields[1]=16;
            var usize i=0;while(i<16){p.records.layouts.kinds[i]=1;p.records.layouts.types[i]=1;p.records.layouts.types[16+i]=9;i+=1;}}
        if(mode==4){p.function_count=0;}
        same(values::declaration_limit_raw(ref p,ref names,0,59,1,7),values::declaration_limit(ref p,ref names,0,59,1,7),mode==0);mode+=1;}
}
