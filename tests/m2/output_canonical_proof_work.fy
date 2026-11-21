module tests::m2::output_canonical_proof_work;
import output_canonical_proof_work as work;
import verifier as raw;
import static_call_ir as calls;
import static_ir as statics;
import static_image as images;
import metadata_budget as budget;
import compiler as compiler;
import source_snapshot as sources;
import module_index as modules;
import module_entry as entries;
import module_input_entry as inputs;
import ir as ir;
import errors as errors;
fn calls::Program lowered(ref u8[] source,ref mut images::Builder b,bool ordinary){
    var sources::Builder build=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{assert(false);return lowered(source,b,ordinary);}};
    assert(sources::add(ref mut build,b"test",source).is_ok);
    let sources::Snapshot snapshot=switch(sources::freeze(ref build)){case .ok(v):{v}case .err(_):{assert(false);return lowered(source,b,ordinary);}};
    let modules::Index index=switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);return lowered(source,b,ordinary);}};
    let entries::Entry entry=switch(entries::select_i32(index,b"app",b"chosen")){case .ok(v):{v}case .err(_):{assert(false);return lowered(source,b,ordinary);}};
    var calls::Program unit=calls::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    if(ordinary){assert(compiler::lower_modules(ref entry,b,ref mut unit).is_ok);}
    else{assert(compiler::lower_output_modules(ref entry,b,ref mut unit).is_ok);}
    return unit;
}
fn void compare(ref statics::Sites a,ref statics::Sites b){
    assert(a.count==b.count && a.dynamic==b.dynamic && a.generic==b.generic && a.call_profile==b.call_profile && a.output==b.output);
    var usize i=0;while(i<16){
        assert(a.definitions[i]==b.definitions[i] && a.functions[i]==b.functions[i] && a.starts[i]==b.starts[i] && a.kinds[i]==b.kinds[i] &&
            a.results[i]==b.results[i] && a.origins[i]==b.origins[i] && a.roots[i]==b.roots[i]);
        assert(a.spans[i].literal==b.spans[i].literal && a.spans[i].start==b.spans[i].start && a.spans[i].end==b.spans[i].end);i+=1;
    }
    i=0;while(i<128){assert(a.parameters[i]==b.parameters[i] && a.formal_sites[i]==b.formal_sites[i]);i+=1;}
}
fn Result<raw::ReferenceReturnProof,errors::Error> staged(ref calls::Program unit,ref images::Image image,bool ordinary){
    var work::State w=if(ordinary){work::empty_ordinary()}else{work::empty(false)};var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<10000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize pc=w.flow.pc;let usize total=meter.total;
        assert(budget::admit(ref mut meter,1,0).is_ok);
        let bool deferred=work::advance(unit,image,ref mut w,ref mut meter)?;
        assert(!deferred && w.phase==phase && w.flow.pc==pc && meter.total==total+1 && meter.last==1);
        assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(unit,image,ref mut w,ref mut meter)?;
        assert(done==w.done && meter.last==4096);turns+=1;
    }
    let usize saved=meter.total;assert(work::advance(unit,image,ref mut w,ref mut meter).is_ok && meter.total==saved);
    return work::prepared(ref w);
}
fn void same(ref calls::Program unit,ref images::Image image,bool ordinary){
    let Result<raw::ReferenceReturnProof,errors::Error> expected=if(ordinary){raw::inspect_reference_returns(unit,image)}
        else{raw::inspect_output_returns(unit,image,false)};
    switch(expected){
        case .ok(expected):{switch(staged(unit,image,ordinary)){
            case .ok(actual):{compare(ref expected.statics,ref actual.statics);
                assert(expected.loans.count==actual.loans.count && expected.recipes.rounds==actual.recipes.rounds &&
                    expected.recipes.calls==actual.recipes.calls && expected.recipes.returns==actual.recipes.returns);
                var usize i=0;while(i<16){assert(expected.owner_roots[i]==actual.owner_roots[i] &&
                    expected.loans.parents[i]==actual.loans.parents[i] && expected.loans.newer[i]==actual.loans.newer[i] &&
                    expected.recipes.site_origins[i]==actual.recipes.site_origins[i] &&
                    expected.recipes.result_origins[i]==actual.recipes.result_origins[i]);i+=1;}}
            case .err(_):{assert(false);}};}
        case .err(expected):{switch(staged(unit,image,ordinary)){case .ok(_):{assert(false);}
            case .err(actual):{assert(actual.kind==expected.kind && actual.offset==expected.offset);}};}
    };
}
fn void source(ref u8[] text){
    var images::Builder b=switch(images::builder(4096)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let calls::Program unit=lowered(text,ref mut b,false);
    let images::Image image=switch(images::freeze(ref b,8192)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    same(ref unit,ref image,false);
}
@test fn void canonical_scalar_calls_lists_records_and_places_match(){
    source(b"module app;pub fn i32 chosen(){return 42;}");
    source(b"module app;fn i32 id(i32 p){return p;}pub fn i32 chosen(){return id(42);}");
    source(b"module app;pub fn i32 chosen(){var u8[3] a=[1,2,3];a[0]=4;return 42;}");
    source(b"module app;struct Pair{u8 a;u8 b;}pub fn i32 chosen(){var Pair p=Pair{.a=1,.b=2};p.a=3;return 42;}");
}
@test fn void canonical_static_returns_and_output_match(){
    source(b"module app;fn ref u8[] id(ref u8[] p){return ref p;}pub fn i32 chosen(){let ref u8[] a=id(ref b\"abc\");output::emit(ref a);return 42;}");
    source(b"module app;fn ref u8[] literal(){return b\"abc\";}fn ref u8[] forward(){return literal();}pub fn i32 chosen(){let ref u8[] a=forward();output::emit(ref a);return 42;}");
}
@test fn void canonical_diagnostic_precedence_matches(){
    var images::Builder b=switch(images::builder(4096)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let calls::Program good=lowered(b"module app;pub fn i32 chosen(){return 42;}",ref mut b,false);
    let images::Image image=switch(images::freeze(ref b,8192)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var calls::Program unit=good;unit.body.list_operands[4095]=1;unit.body.code[0]=0;same(ref unit,ref image,false);
    unit=good;unit.body.register_ends[0]=0;same(ref unit,ref image,false);
    unit=good;unit.body.records.layouts.types[511]=1;same(ref unit,ref image,false);
    unit=good;unit.body.code[8]=25;same(ref unit,ref image,false);
    unit=good;unit.body.call_count=1;same(ref unit,ref image,false);
}
fn calls::Program lowered_input(ref u8[] source,ref mut images::Builder b){
    var sources::Builder build=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{assert(false);return lowered_input(source,b);}};
    assert(sources::add(ref mut build,b"test",source).is_ok);
    let sources::Snapshot snapshot=switch(sources::freeze(ref build)){case .ok(v):{v}case .err(_):{assert(false);return lowered_input(source,b);}};
    let modules::Index index=switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);return lowered_input(source,b);}};
    let inputs::InputEntry entry=switch(inputs::select_i32_input(index,b"app",b"chosen")){case .ok(v):{v}case .err(_):{assert(false);return lowered_input(source,b);}};
    var calls::Program unit=calls::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    assert(compiler::lower_input_modules(ref entry,b,ref mut unit).is_ok);return unit;
}
@test fn void separate_input_abi_matches_and_keeps_output_closed(){
    var images::Builder b=switch(images::builder(4096)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let calls::Program unit=lowered_input(b"module app;pub fn i32 chosen(ref u8[] p){return 42;}",ref mut b);
    let images::Image image=switch(images::freeze(ref b,8192)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let raw::ReferenceReturnProof expected=switch(raw::inspect_input_returns(ref unit,ref image)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let raw::ReferenceReturnProof actual=switch(work::inspect_input(ref unit,ref image)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    compare(ref expected.statics,ref actual.statics);assert(!actual.statics.output);
    var calls::Program emit=unit;emit.body.code[8]=116;emit.body.code[9]=0;emit.body.code[10]=0;emit.body.code[11]=1;
    switch(raw::inspect_input_returns(ref emit,ref image)){case .ok(_):{assert(false);}case .err(e):{
        switch(work::inspect_input(ref emit,ref image)){case .ok(_):{assert(false);}case .err(a):{assert(e.kind==a.kind && e.offset==a.offset);}};}};
}

@test fn void ordinary_abi_matches_and_keeps_output_closed(){
    var images::Builder b=images::full_builder();
    var calls::Program unit=lowered(b"module app;fn ref u8[] id(ref u8[] p){return ref p;}pub fn i32 chosen(){let ref u8[] a=id(ref b\"M\");return a[0] as i32;}",ref mut b,true);
    let images::Image image=switch(images::freeze(ref b,8192)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(raw::inspect_reference_returns(ref unit,ref image).is_ok);
    same(ref unit,ref image,true);
    let usize first=unit.body.starts[unit.body.entry]*8;
    unit.body.code[first]=116;
    unit.body.code[first+1]=0;
    unit.body.code[first+2]=0;
    unit.body.code[first+3]=1;
    unit.body.code[first+4]=0;
    unit.body.code[first+5]=0;
    unit.body.code[first+6]=0;
    unit.body.code[first+7]=0;
    assert(!raw::inspect_reference_returns(ref unit,ref image).is_ok);
    assert(!staged(ref unit,ref image,true).is_ok);
}
