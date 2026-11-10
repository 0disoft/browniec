module tests::m2::output_static_sites_work;
import output_static_sites_work as work;
import static_call_sites as raw;
import static_call_ir as calls;
import static_ir as statics;
import static_image as images;
import metadata_budget as budget;
import compiler as compiler;
import source_snapshot as sources;
import module_index as modules;
import module_entry as entries;
import ir as ir;

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
fn void same(ref u8[] source){
    var images::Builder b=switch(images::builder(4096)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let calls::Program unit=lowered(source,ref mut b);
    let images::Image image=switch(images::freeze(ref b,8192)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let calls::Proof proof=switch(calls::inspect_output_returns(ref unit,ref image,false)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let statics::Sites expected=switch(raw::prepare(ref unit,ref proof,ref image)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<300);assert(budget::reset(ref mut meter,0).is_ok);
        let work::State saved=w;assert(budget::admit(ref mut meter,1,0).is_ok);let budget::State before=meter;
        switch(work::advance(ref unit,ref proof,ref image,ref mut w,ref mut meter)){case .ok(done):{assert(!done);}case .err(_):{assert(false);return;}};
        compare(ref w.result,ref saved.result);assert(w.phase==saved.phase && w.site==saved.site && w.round==saved.round && w.changed==saved.changed);
        assert(meter.total==before.total && meter.last==before.last && meter.stages==before.stages);
        assert(budget::reset(ref mut meter,0).is_ok);
        assert(work::advance(ref unit,ref proof,ref image,ref mut w,ref mut meter).is_ok);assert(meter.last==4096);turns+=1;
    }
    compare(ref expected,ref w.result);
}
@test fn void plain_and_literal_sites_match_raw_exactly(){
    same(b"module app;pub fn i32 chosen(){return 42;}");
    same(b"module app;pub fn i32 chosen(){output::emit(ref b\"abc\");return 42;}");
}
@test fn void formal_returned_and_forwarded_sites_match_raw(){
    same(b"module app;fn ref u8[] id(ref u8[] p){return ref p;}pub fn i32 chosen(){let ref u8[] a=id(ref b\"abc\");output::emit(ref a);return 42;}");
    same(b"module app;fn ref u8[] literal(){return b\"abc\";}fn ref u8[] forward(){return literal();}pub fn i32 chosen(){let ref u8[] a=forward();output::emit(ref a);return 42;}");
}
