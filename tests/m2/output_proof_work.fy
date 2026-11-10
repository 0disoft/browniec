module tests::m2::output_proof_work;
import output_proof_work as work;
import output_return_proof as raw;
import static_call_ir as calls;
import static_ir as statics;
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
fn void compare(ref statics::Sites a,ref statics::Sites b){
    assert(a.count==b.count && a.dynamic==b.dynamic && a.generic==b.generic && a.call_profile==b.call_profile && a.output==b.output);
    var usize i=0;while(i<16){
        assert(a.definitions[i]==b.definitions[i] && a.functions[i]==b.functions[i] && a.starts[i]==b.starts[i] && a.kinds[i]==b.kinds[i] &&
            a.results[i]==b.results[i] && a.origins[i]==b.origins[i] && a.roots[i]==b.roots[i]);
        assert(a.spans[i].literal==b.spans[i].literal && a.spans[i].start==b.spans[i].start && a.spans[i].end==b.spans[i].end);i+=1;
    }
    i=0;while(i<128){assert(a.parameters[i]==b.parameters[i] && a.formal_sites[i]==b.formal_sites[i]);i+=1;}
}
fn Result<raw::Proof,errors::Error> staged(ref calls::Program unit,ref images::Image image){
    var work::State w=work::empty(false);var budget::State meter=budget::empty();var usize turns=0;
    var calls::Program normalized=calls::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<20000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize pc=w.canonical.flow.pc;let usize total=meter.total;let usize count=normalized.body.count;
        assert(budget::admit(ref mut meter,1,0).is_ok);
        let bool deferred=work::advance(unit,image,ref mut normalized,ref mut w,ref mut meter)?;
        assert(!deferred && w.phase==phase && w.canonical.flow.pc==pc && normalized.body.count==count && meter.total==total+1 && meter.last==1);
        assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(unit,image,ref mut normalized,ref mut w,ref mut meter)?;
        assert(done==w.done && meter.last==4096);turns+=1;
    }
    let usize saved=meter.total;assert(work::advance(unit,image,ref mut normalized,ref mut w,ref mut meter).is_ok && meter.total==saved);
    return work::prepared(ref w);
}
fn void same(ref calls::Program unit,ref images::Image image){
    switch(raw::inspect(unit,image,false)){
        case .ok(expected):{switch(staged(unit,image)){
            case .ok(actual):{compare(ref expected.ordinary.statics,ref actual.ordinary.statics);
                assert(expected.ordinary.loans.count==actual.ordinary.loans.count);
                var usize i=0;while(i<16){assert(expected.parameters[i]==actual.parameters[i] && expected.elements[i]==actual.elements[i] &&
                    expected.ordinary.owner_roots[i]==actual.ordinary.owner_roots[i] &&
                    expected.ordinary.loans.parents[i]==actual.ordinary.loans.parents[i] &&
                    expected.ordinary.loans.newer[i]==actual.ordinary.loans.newer[i] &&
                    expected.ordinary.recipes.site_origins[i]==actual.ordinary.recipes.site_origins[i]);i+=1;}}
            case .err(_):{assert(false);}};}
        case .err(expected):{switch(staged(unit,image)){case .ok(_):{assert(false);}
            case .err(actual):{assert(actual.kind==expected.kind && actual.offset==expected.offset);}};}
    };
}
fn void source(ref u8[] text){
    var images::Builder b=switch(images::builder(4096)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let calls::Program unit=lowered(text,ref mut b);
    let images::Image image=switch(images::freeze(ref b,8192)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    same(ref unit,ref image);
}
@test fn void full_scalar_static_and_place_proof_matches_oracle(){
    source(b"module app;pub fn i32 chosen(){output::emit(ref b\"abc\");return 42;}");
    source(b"module app;pub fn i32 chosen(){var u8[3] a=[1,2,3];a[0]=4;output::emit(ref a);return 42;}");
}
@test fn void full_borrowed_shared_exclusive_and_forwarding_proof_matches_oracle(){
    source(b"module app;fn ref i32[] tail(ref i32[] p){return ref p;}pub fn i32 chosen(){let i32[2] a=[20,22];let ref i32[] b=tail(ref a);return b[0]+20;}");
    source(b"module app;fn ref mut i32[] tail(ref mut i32[] p){return ref mut p;}pub fn i32 chosen(){var i32[2] a=[20,22];let ref mut i32[] b=tail(ref mut a);b[0]=42;return b[0];}");
    source(b"module app;fn ref i32[] first(ref i32[] p){return ref p;}fn ref i32[] forward(ref i32[] p){return first(ref p);}pub fn i32 chosen(){let i32[1] a=[42];let ref i32[] b=forward(ref a);return b[0];}");
}
@test fn void full_proof_signature_and_binding_error_precedence_matches(){
    var images::Builder b=switch(images::builder(4096)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let calls::Program good=lowered(b"module app;fn ref i32[] tail(ref i32[] p){return ref p;}pub fn i32 chosen(){let i32[2] a=[20,22];let ref i32[] b=tail(ref a);return b[0]+20;}",ref mut b);
    let images::Image image=switch(images::freeze(ref b,8192)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var calls::Program unit=good;unit.origins[0]=0;same(ref unit,ref image);
    unit=good;unit.body.list_operands[4095]=1;same(ref unit,ref image);
    var usize pc=0;while(pc<good.body.count){if(good.body.code[pc*8]==66){unit=good;unit.body.code[pc*8+7]=1;same(ref unit,ref image);
        unit=good;unit.body.code[pc*8+6]=15;same(ref unit,ref image);}pc+=1;}
}
