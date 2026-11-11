module tests::m2::struct_scan_work;
import struct_scan_work as work;
import struct_source as raw;
import source_context as context;
import source_snapshot as sources;
import module_index as modules;
import lexer as lexer;
import errors as errors;
import metadata_budget as budget;
import std::bytes as bytes;
fn void table(ref raw::Table a,ref raw::Table b){
    assert(a.layouts.count==b.layouts.count && a.context.modules==b.context.modules && a.context.imports==b.context.imports &&
        a.context.function_count==b.context.function_count && a.context.record_count==b.context.record_count);
    var usize i=0;while(i<32){assert(a.begins[i]==b.begins[i] && a.ends[i]==b.ends[i] && a.bodies[i]==b.bodies[i] &&
        a.layouts.fields[i]==b.layouts.fields[i] && a.context.records[i]==b.context.records[i]);i+=1;}
    i=0;while(i<512){assert(a.layouts.kinds[i]==b.layouts.kinds[i] && a.layouts.types[i]==b.layouts.types[i]);i+=1;}
    i=0;while(i<64){assert(a.context.aliases[i]==b.context.aliases[i]);i+=1;}
    i=0;while(i<16){assert(a.context.ends[i]==b.context.ends[i] && a.context.functions[i]==b.context.functions[i]);i+=1;}
}
fn void same_result(Result<raw::Table,errors::Error> expected,Result<raw::Table,errors::Error> actual){
    switch(expected){case .ok(a):{switch(actual){case .ok(b):{table(ref a,ref b);}case .err(_):{assert(false);}};}
        case .err(e):{switch(actual){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};}};
}
fn Result<raw::Table,errors::Error> run(ref u8[] source,ref context::Table scope,bool scoped){
    var work::State w=if(scoped){work::scoped()}else{work::single()};var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<20000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize record=w.record;let usize count=w.result.layouts.count;let usize visits=w.visits;let usize cursor=w.token.cursor;
        let u8 lexical=w.scan.phase;let u8 declaration=w.declaration.phase;let u8 fields=w.fields.phase;let u8 layout=w.layout.phase;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        let Result<bool,errors::Error> deferred=if(scoped){work::advance_scoped(source,scope,ref mut w,ref mut meter)}else{work::advance_single(source,ref mut w,ref mut meter)};
        assert(deferred.is_ok && w.phase==phase && w.record==record && w.result.layouts.count==count && w.visits==visits &&
            w.token.cursor==cursor && w.scan.phase==lexical && w.declaration.phase==declaration && w.fields.phase==fields && w.layout.phase==layout && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);
        let Result<bool,errors::Error> result=if(scoped){work::advance_scoped(source,scope,ref mut w,ref mut meter)}else{work::advance_single(source,ref mut w,ref mut meter)};
        switch(result){case .ok(done):{assert(done==w.done && meter.last==4096 && w.visits-visits<=64);if(!done){assert(!work::prepared(ref w).is_ok);}}
            case .err(e):{return .err(e);}};turns+=1;
    }
    let usize total=meter.total;let Result<bool,errors::Error> done=if(scoped){work::advance_scoped(source,scope,ref mut w,ref mut meter)}else{work::advance_single(source,ref mut w,ref mut meter)};
    assert(done.is_ok && meter.total==total);return work::prepared(ref w);
}
fn void plain(ref u8[] source){let context::Table scope=context::empty();same_result(raw::scan_single_untyped_raw(source),run(source,ref scope,false));
    same_result(raw::scan_single_untyped_raw(source),raw::scan(source));}
fn void scoped(ref u8[] source,ref context::Table scope){same_result(raw::scan_scoped_untyped_raw(source,scope),run(source,scope,true));
    same_result(raw::scan_scoped_untyped_raw(source,scope),raw::scan_scoped(source,scope));}
fn usize position(ref u8[] source,ref u8[] query){var usize i=0;while(i+query.len<=source.len){
    if(lexer::equal(source[i..i+query.len],query)){return i;}i+=1;}assert(false);return 0;}
fn u32 word(usize a,usize b){var usize value=a|(b<<13);var u32 result=0;var u32 bit=1;
    while(value!=0){if((value&1)!=0){result|=bit;}value>>=1;if(value!=0){bit<<=1;}}return result;}
@test fn void whole_declaration_pass_precedes_field_types_duplicates_and_layouts(){
    plain(b"module main;struct P{i32 x;bool y;}struct Q{P p;u8 b;}fn i32 f(){return 1;}");
    plain(b"module main;struct A{B b;}struct B{i32 x;}");plain(b"module main;fn i32 f(){}");
    plain(b"module main;struct A{Unknown x;}struct B{i32[2] y;}");
    plain(b"module main;struct A{Unknown x;}fn i32 f(){");plain(b"module main;struct A{i32 x;bool x;}");
    plain(b"module main;struct A{i32 x;}struct A{bool b;}");plain(b"module main;struct A{}");
    plain(b"module main;struct Good{i32 x;}struct Bad{Bad x;}");plain(b"module other;");
}
fn modules::Index project(){
    var sources::Builder builder=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{assert(false);return project();}};
    assert(sources::add(ref mut builder,b"a",b"module a;import b as m;struct Local{m::Pair p;i32 x;}fn i32 chosen(){return 1;}").is_ok);
    assert(sources::add(ref mut builder,b"b",b"module b;pub struct Pair{u8 a;bool b;}").is_ok);
    let sources::Snapshot snapshot=switch(sources::freeze(ref builder)){case .ok(v):{v}case .err(_):{assert(false);return project();}};
    return switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);project()}};
}
@test fn void scoped_imports_forged_prefixes_and_failed_root_diagnostics_match(){
    let modules::Index index=project();let context::Input input=switch(context::collect(ref index)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let ref u8[] data=ref input.data;let ref u8[] source=data[..input.used];scoped(source,ref input.context);
    var context::Table scope=input.context;scope.records[1]&=67108863;scoped(source,ref scope);
    let ref u8[] prefix=b"module a;struct i32X{i32 x;}";scope=context::empty();scope.modules=1;scope.ends[0]=word(prefix.len,0);scope.record_count=1;
    let usize at=position(prefix,b"i32X");scope.records[0]=word(at,at+3);scoped(prefix,ref scope);
    scope.records[0]=word(at,at+4);scoped(prefix,ref scope);
    let ref u8[] cycle=b"module a;struct Good{i32 x;}struct Bad{Bad x;}";scope.ends[0]=word(cycle.len,0);scope.record_count=2;
    let usize first=position(cycle,b"Good");let usize second=position(cycle,b"Bad");scope.records[0]=word(first,first+4);scope.records[1]=word(second,second+3);scoped(cycle,ref scope);
    scope=context::empty();scope.modules=1;scope.ends[0]=1;scoped(b"\xff",ref scope);
    scope.modules=17;scoped(b"\xff",ref scope);
}
@test fn void source_record_depth_and_long_duplicate_name_bounds_match(){
    var bytes::Buffer over=switch(bytes::with_capacity(4097)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(bytes::resize_zeroed(ref mut over,4097).is_ok);plain(bytes::view(ref over));
    var u8[4096] source=[32;4096];let ref u8[] header=b"module main;";var usize i=0;
    while(i<header.len){source[i]=header[i];i+=1;}plain(ref source);
    let ref u8[] keyword=b"struct ";let ref u8[] scalar=b"{i32 x;}";var usize record=0;var u8 letter=65;var u8 digit=48;
    while(record<33){var usize j=0;while(j<keyword.len){source[i]=keyword[j];i+=1;j+=1;}
        source[i]=letter;i+=1;source[i]=digit;i+=1;digit+=1;if(digit==58){digit=48;letter+=1;}
        j=0;while(j<scalar.len){source[i]=scalar[j];i+=1;j+=1;}record+=1;}plain(ref source);
    source=[32;4096];i=0;while(i<header.len){source[i]=header[i];i+=1;}record=0;letter=65;
    while(record<17){var usize j=0;while(j<keyword.len){source[i]=keyword[j];i+=1;j+=1;}
        source[i]=letter;i+=1;source[i]=123;i+=1;
        if(record==0){source[i]=105;i+=1;source[i]=51;i+=1;source[i]=50;i+=1;}else{source[i]=letter-1;i+=1;}
        source[i]=32;i+=1;source[i]=120;i+=1;source[i]=59;i+=1;source[i]=125;i+=1;letter+=1;record+=1;}plain(ref source);
    source=[32;4096];i=0;while(i<header.len){source[i]=header[i];i+=1;}record=0;
    while(record<2){var usize j=0;while(j<keyword.len){source[i]=keyword[j];i+=1;j+=1;}
        j=0;while(j<1800){source[i]=65;i+=1;j+=1;}j=0;while(j<scalar.len){source[i]=scalar[j];i+=1;j+=1;}record+=1;}plain(ref source);
}
