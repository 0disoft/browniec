module tests::m2::output_borrowed_calls_work;
import output_borrowed_calls_work as work;
import slice_result_verifier as raw;
import slice_result_ir as borrowed;
import output_return_ir as returns;
import slice_result_origins as origins;
import functions as functions;
import struct_layout as layouts;
import static_call_ir as calls;
import static_image as images;
import metadata_budget as budget;
import compiler as compiler;
import source_snapshot as sources;
import module_index as modules;
import module_entry as entries;
import ir as ir;
import errors as errors;
fn calls::Program lowered(ref u8[] source,ref mut images::Builder b){
    var sources::Builder build=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{assert(false);return lowered(source,b);}};
    assert(sources::add(ref mut build,b"test",source).is_ok);
    let sources::Snapshot snapshot=switch(sources::freeze(ref build)){case .ok(v):{v}case .err(_):{assert(false);return lowered(source,b);}};
    let modules::Index index=switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);return lowered(source,b);}};
    let entries::Entry entry=switch(entries::select_i32(index,b"app",b"chosen")){case .ok(v):{v}case .err(_):{assert(false);return lowered(source,b);}};
    var calls::Program unit=calls::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    assert(compiler::lower_output_modules(ref entry,b,ref mut unit).is_ok);return unit;
}
fn Result<raw::Proof,errors::Error> staged(ref calls::Program unit,ref calls::Program normalized,
    ref returns::Signature signature,ref origins::Summary grounded,ref layouts::Plan plan){
    var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<20000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize pc=w.pc;let usize scan=w.scan;let usize total=meter.total;
        assert(budget::admit(ref mut meter,1,0).is_ok);
        let bool deferred=work::advance(ref normalized.body,ref unit.body,signature,grounded,plan,ref mut w,ref mut meter)?;
        assert(!deferred && w.phase==phase && w.pc==pc && w.scan==scan && meter.total==total+1 && meter.last==1);
        assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(ref normalized.body,ref unit.body,signature,grounded,plan,ref mut w,ref mut meter)?;
        assert(done==w.done && meter.last==4096);turns+=1;
    }return .ok(w.result);
}
fn void same(ref calls::Program unit,ref calls::Program normalized,ref returns::Signature signature){
    var functions::Table table=functions::empty();table.count=normalized.body.function_count;table.entry=normalized.body.entry;
    table.arities=normalized.body.arities;table.return_slice_elements=signature.elements;
    let origins::Summary grounded=switch(origins::inspect_output_admitted(ref normalized.body,ref table,ref unit.body)){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    let layouts::Plan plan=switch(layouts::plan(ref normalized.body.records.layouts,18446744073709551615)){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    let borrowed::Program original=borrowed::Program{.body=unit.body,.elements=signature.elements,.parameters=signature.parameters};
    switch(raw::inspect_output_admitted(ref original,ref normalized.body)){
        case .ok(expected):{switch(staged(unit,normalized,signature,ref grounded,ref plan)){
            case .ok(actual):{assert(expected.preparations==actual.preparations && expected.forwards==actual.forwards &&
                expected.returns==actual.returns && expected.rounds==actual.rounds);var usize i=0;
                while(i<16){assert(expected.parameters[i]==actual.parameters[i]);i+=1;}}
            case .err(_):{assert(false);}};}
        case .err(expected):{switch(staged(unit,normalized,signature,ref grounded,ref plan)){case .ok(_):{assert(false);}
            case .err(actual):{assert(expected.kind==actual.kind && expected.offset==actual.offset);}};}
    };
}
fn void source(ref u8[] text,bool mutate){
    var images::Builder b=switch(images::builder(4096)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let calls::Program good=lowered(text,ref mut b);
    let returns::Signature signature=switch(returns::signature(ref good)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var calls::Program normalized=good;assert(returns::normalize(ref mut normalized,ref signature).is_ok);
    same(ref good,ref normalized,ref signature);
    if(mutate){var calls::Program unit=good;var usize pc=0;
        while(pc<good.body.count){if(good.body.code[pc*8]==66){unit=good;unit.body.code[pc*8+4]=255;same(ref unit,ref normalized,ref signature);
            unit=good;unit.body.code[pc*8+6]=15;same(ref unit,ref normalized,ref signature);}pc+=1;}
        var returns::Signature wrong=signature;var usize f=0;while(f<good.body.function_count){
            if(signature.elements[f]!=0){wrong.parameters[f]=8;same(ref good,ref normalized,ref wrong);}f+=1;}
    }
}
@test fn void shared_exclusive_and_forwarded_call_recipes_match_raw(){
    source(b"module app;fn ref i32[] tail(ref i32[] p){return ref p;}pub fn i32 chosen(){let i32[2] a=[20,22];let ref i32[] b=tail(ref a);return b[0]+20;}",true);
    source(b"module app;fn ref mut i32[] tail(ref mut i32[] p){return ref mut p;}pub fn i32 chosen(){var i32[2] a=[20,22];let ref mut i32[] b=tail(ref mut a);b[0]=42;return b[0];}",true);
    source(b"module app;fn ref i32[] first(ref i32[] p){return ref p;}fn ref i32[] forward(ref i32[] p){return first(ref p);}pub fn i32 chosen(){let i32[1] a=[42];let ref i32[] b=forward(ref a);return b[0];}",false);
}
@test fn void list_and_record_reads_use_bounded_operand_and_nominal_stages(){
    source(b"module app;fn ref i32[] tail(ref i32[] p){return ref p;}struct Pair{i32 a;i32 b;}pub fn i32 chosen(){let i32[1] a=[42];let ref i32[] b=tail(ref a);let i32[3] c=[1,2,3];let Pair p=Pair{.a=1,.b=2};return b[0]+c[0]-p.a;}",false);
}
