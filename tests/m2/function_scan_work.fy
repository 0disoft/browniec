module tests::m2::function_scan_work;
import function_scan_work as work;
import functions as raw;
import source_context as context;
import source_snapshot as sources;
import module_index as modules;
import lexer as lexer;
import errors as errors;
import metadata_budget as budget;
fn void table(ref raw::Table a,ref raw::Table b){
    assert(a.count==b.count && a.entry==b.entry && a.reference_calls==b.reference_calls && a.reference_returns==b.reference_returns && a.output==b.output);
    assert(a.context.modules==b.context.modules && a.context.imports==b.context.imports && a.context.function_count==b.context.function_count && a.context.record_count==b.context.record_count);
    assert(a.literals.count==b.literals.count && a.literals.enabled==b.literals.enabled);
    var usize i=0;while(i<16){assert(a.begins[i]==b.begins[i] && a.ends[i]==b.ends[i] && a.bodies[i]==b.bodies[i] && a.body_ends[i]==b.body_ends[i] &&
        a.arities[i]==b.arities[i] && a.return_types[i]==b.return_types[i] && a.return_lengths[i]==b.return_lengths[i] && a.return_records[i]==b.return_records[i] &&
        a.return_slice_elements[i]==b.return_slice_elements[i] && a.return_slice_inputs[i]==b.return_slice_inputs[i] && a.return_slice_candidates[i]==b.return_slice_candidates[i]);
        assert(a.context.ends[i]==b.context.ends[i] && a.context.functions[i]==b.context.functions[i] && a.literals.begins[i]==b.literals.begins[i] &&
            a.literals.ends[i]==b.literals.ends[i] && a.literals.literals[i]==b.literals.literals[i] && a.literals.lengths[i]==b.literals.lengths[i] && a.literals.kinds[i]==b.literals.kinds[i]);i+=1;}
    i=0;while(i<128){assert(a.param_begins[i]==b.param_begins[i] && a.param_ends[i]==b.param_ends[i] && a.param_types[i]==b.param_types[i] &&
        a.param_lengths[i]==b.param_lengths[i] && a.param_arrays[i]==b.param_arrays[i] && a.param_records[i]==b.param_records[i] &&
        a.param_slices[i]==b.param_slices[i] && a.param_slice_elements[i]==b.param_slice_elements[i]);i+=1;}
    i=0;while(i<64){assert(a.context.aliases[i]==b.context.aliases[i]);i+=1;}
    i=0;while(i<32){assert(a.context.records[i]==b.context.records[i]);i+=1;}
}
fn void same_result(Result<raw::Table,errors::Error> expected,Result<raw::Table,errors::Error> actual){
    switch(expected){case .ok(a):{switch(actual){case .ok(b):{table(ref a,ref b);}case .err(_):{assert(false);}};}
        case .err(e):{switch(actual){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};}};
}
fn Result<raw::Table,errors::Error> single(ref u8[] source,bool returns){
    var work::State w=work::single(returns);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<15000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize count=w.result.count;let usize cursor=w.token.cursor;
        let u8 signature=w.signature.phase;let u8 declaration=w.declaration.phase;let u8 lexical=w.scan.phase;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance_single(source,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.result.count==count && w.token.cursor==cursor && w.signature.phase==signature &&
            w.declaration.phase==declaration && w.scan.phase==lexical && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);
        switch(work::advance_single(source,ref mut w,ref mut meter)){
            case .ok(done):{assert(done==w.done && meter.last==4096);if(!done){assert(!work::prepared(ref w).is_ok);}}
            case .err(e):{return .err(e);}};turns+=1;
    }
    let usize total=meter.total;assert(work::advance_single(source,ref mut w,ref mut meter).is_ok && meter.total==total);
    return work::prepared(ref w);
}
fn Result<raw::Table,errors::Error> indexed(ref u8[] source,ref context::Table scope,ref modules::Index index,usize selected,bool returns){
    var work::State w=work::indexed(selected,returns);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<15000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize row=w.row;let usize count=w.result.count;let usize cursor=w.token.cursor;
        let u8 signature=w.signature.phase;let u8 checked=w.check.phase;let u8 state=w.state.phase;let u8 lexical=w.scan.phase;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance_indexed(source,scope,index,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.row==row && w.result.count==count && w.token.cursor==cursor && w.signature.phase==signature &&
            w.check.phase==checked && w.state.phase==state && w.scan.phase==lexical && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);
        switch(work::advance_indexed(source,scope,index,ref mut w,ref mut meter)){
            case .ok(done):{assert(done==w.done && meter.last==4096);if(!done){assert(!work::prepared(ref w).is_ok);}}
            case .err(e):{return .err(e);}};turns+=1;
    }
    let usize total=meter.total;assert(work::advance_indexed(source,scope,index,ref mut w,ref mut meter).is_ok && meter.total==total);
    return work::prepared(ref w);
}
fn void plain(ref u8[] source,bool returns){
    same_result(raw::scan_single_untyped_raw(source,returns),single(source,returns));
    let Result<raw::Table,errors::Error> adapter=if(returns){raw::scan_reference_returns(source)}else{raw::scan(source)};
    same_result(raw::scan_single_untyped_raw(source,returns),adapter);
}
@test fn void unscoped_declarations_forward_records_and_exact_failures_match(){
    plain(b"module main;fn i32 main(){return 1;}",false);
    plain(b"module main;fn P f(P p){return p;}struct P{i32 x;}fn i32 main(){return 1;}",false);
    plain(b"module main;fn ref u8[] f(){return b\"x\";}fn i32 main(){return 1;}",true);
    plain(b"module main;fn ref u8[] f(){return b\"x\";}fn i32 main(){return 1;}",false);
    plain(b"",false);plain(b"module other;fn i32 main(){}",false);plain(b"module main;",false);
    plain(b"module main;struct P{}fn i32 main(){}",false);plain(b"module main;fn i32 helper(){}",false);
    plain(b"module main;fn i32 main(){}fn i32 main(){}",false);plain(b"module main;fn Q main(){}",false);
}
fn modules::Index project(){
    var sources::Builder builder=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{assert(false);return project();}};
    assert(sources::add(ref mut builder,b"a",b"module a;import b as m;struct Local{i32 x;}fn i32 helper(){return 1;}pub fn i32 chosen(){return m::answer();}//tail").is_ok);
    assert(sources::add(ref mut builder,b"b",b"\xef\xbb\xbfmodule b;pub struct Pair{i32 x;}pub fn i32 answer(){return 42;}").is_ok);
    let sources::Snapshot snapshot=switch(sources::freeze(ref builder)){case .ok(v):{v}case .err(_):{assert(false);return project();}};
    return switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);project()}};
}
fn usize chosen(ref modules::Index index){var usize i=0;while(i<modules::symbol_count(index)){
        let modules::Symbol symbol=switch(modules::symbol(index,i)){case .ok(v):{v}case .err(_):{assert(false);return 0;}};
        let ref u8[] name=switch(sources::view(modules::snapshot(index),symbol.name)){case .ok(v):{v}case .err(_):{assert(false);return 0;}};
        if(lexer::equal(name,b"chosen")){return i;}i+=1;}assert(false);return 0;}
fn void scoped(ref modules::Index index,ref context::Input input,ref context::Table scope,usize selected){
    let ref u8[] bytes=ref input.data;let ref u8[] source=bytes[..input.used];
    same_result(raw::scan_index_untyped_raw(source,scope,index,selected,true),indexed(source,scope,index,selected,true));
}
@test fn void indexed_module_declarations_visibility_and_selection_match(){
    let modules::Index index=project();let context::Input input=switch(context::collect(ref index)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    scoped(ref index,ref input,ref input.context,chosen(ref index));scoped(ref index,ref input,ref input.context,0);
    scoped(ref index,ref input,ref input.context,99);
    var context::Table scope=input.context;scope.function_count=0;scoped(ref index,ref input,ref scope,chosen(ref index));
    scope=input.context;scope.modules=17;scoped(ref index,ref input,ref scope,chosen(ref index));
}
@test fn void maximum_source_and_sixteen_function_limit_match(){
    var u8[4096] source=[32;4096];let ref u8[] start=b"module main;fn i32 main(){}";var usize i=0;
    while(i<start.len){source[i]=start[i];i+=1;}plain(ref source,false);
    source=[32;4096];let ref u8[] header=b"module main;";i=0;while(i<header.len){source[i]=header[i];i+=1;}
    let ref u8[] prefix=b"fn i32 ";let ref u8[] suffix=b"(){}";var u8 name=65;var usize function=0;
    while(function<17){var usize j=0;while(j<prefix.len){source[i]=prefix[j];i+=1;j+=1;}
        source[i]=name;i+=1;name+=1;j=0;while(j<suffix.len){source[i]=suffix[j];i+=1;j+=1;}function+=1;}
    plain(ref source,false);
}
