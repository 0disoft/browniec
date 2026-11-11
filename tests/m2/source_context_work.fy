module tests::m2::source_context_work;
import source_context_work as work;
import source_context as raw;
import module_index as modules;
import module_entry as entries;
import source_snapshot as sources;
import metadata_budget as budget;

fn entries::Entry entry(ref u8[] a,ref u8[] b){
    var sources::Builder build=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{assert(false);return entry(a,b);}};
    assert(sources::add(ref mut build,b"a",a).is_ok);
    if(b.len!=0){assert(sources::add(ref mut build,b"b",b).is_ok);}
    let sources::Snapshot snap=switch(sources::freeze(ref build)){case .ok(v):{v}case .err(_):{assert(false);return entry(a,b);}};
    let modules::Index index=switch(modules::build(snap)){case .ok(v):{v}case .err(_):{assert(false);return entry(a,b);}};
    return switch(entries::select_i32(index,b"a",b"chosen")){case .ok(v):{v}case .err(_):{assert(false);entry(a,b)}};
}
fn void compare(ref raw::Input a,ref raw::Input b){
    assert(a.used==b.used);let ref raw::Table x=ref a.context;let ref raw::Table y=ref b.context;
    assert(x.modules==y.modules && x.imports==y.imports && x.function_count==y.function_count && x.record_count==y.record_count);
    var usize i=0;while(i<4096){assert(a.data[i]==b.data[i]);i+=1;}
    i=0;while(i<64){assert(x.aliases[i]==y.aliases[i]);i+=1;}
    i=0;while(i<32){assert(x.records[i]==y.records[i]);i+=1;}
    i=0;while(i<16){assert(x.functions[i]==y.functions[i] && x.ends[i]==y.ends[i]);i+=1;}
}
fn void same(ref entries::Entry e){
    let ref modules::Index index=entries::index(e);
    let raw::Input expected=switch(raw::collect(index)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<256);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize cursor=w.cursor;let usize used=w.result.used;let usize visits=w.visits;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        switch(work::advance(index,ref mut w,ref mut meter)){case .ok(done):{assert(!done);}case .err(_):{assert(false);return;}};
        assert(w.phase==phase && w.cursor==cursor && w.result.used==used && w.visits==visits && meter.total==total && meter.last==1);
        assert(budget::reset(ref mut meter,0).is_ok);
        assert(work::advance(index,ref mut w,ref mut meter).is_ok);assert(w.visits-visits<=64 && meter.last==4096);turns+=1;
        if(!w.done){assert(!work::prepared(ref w).is_ok);}
    }
    let raw::Input actual=switch(work::prepared(ref w)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    compare(ref expected,ref actual);let usize total=meter.total;
    assert(work::advance(index,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void separate_files_import_aliases_and_pub_names_match_raw(){
    let entries::Entry e=entry(b"module a;import b as m;struct Local{i32 n;}pub fn i32 chosen(){return m::answer();}//tail",
        b"\xef\xbb\xbfmodule b;pub struct Pair{i32 x;i32 y;}fn i32 hidden(){return 0;}pub fn i32 answer(){return 42;}");same(ref e);
}
@test fn void maximum_source_copy_resumes_without_replaying_prefixes(){
    var u8[4096] source=[32;4096];let ref u8[] prefix=b"module a;pub fn i32 chosen(){return 42;}";
    var usize i=0;while(i<prefix.len){source[i]=prefix[i];i+=1;}
    let entries::Entry e=entry(ref source,b"");same(ref e);
}
