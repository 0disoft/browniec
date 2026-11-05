module tests::m2::source_context;
import source_context as context;
import module_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import functions as functions;
import struct_source as records;
import lexer as lexer;
import std::bytes as bytes;

fn sources::Builder builder(){return switch(sources::builder(4096,4096)){
    case .ok(v):{v}case .err(_):{assert(false);builder()}
};}
fn usize added(Result<usize,sources::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn entries::Entry entry(ref u8[] a,ref u8[] b){
    var sources::Builder scratch=builder();let usize x=added(sources::add(ref mut scratch,b"first",a));
    if(b.len!=0){let usize y=added(sources::add(ref mut scratch,b"second",b));}
    let sources::Snapshot snapshot=switch(sources::freeze(ref scratch)){case .ok(v):{v}case .err(_):{assert(false);return entry(b"module a;pub fn i32 chosen(){}",b"");}};
    let modules::Index index=switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);return entry(b"module a;pub fn i32 chosen(){}",b"");}};
    return switch(entries::select_i32(index,b"a",b"chosen")){case .ok(v):{v}case .err(_):{assert(false);entry(b"module a;pub fn i32 chosen(){}",b"")}};
}
fn context::Input input(ref entries::Entry e){return switch(context::collect(entries::index(e))){
    case .ok(v):{v}case .err(_):{assert(false);context::Input{.data=[0;4096],.used=0,.context=context::empty()}}
};}
fn lexer::State state(ref u8[] source,ref context::Table scope,usize offset){
    return switch(context::state(source,scope,offset)){case .ok(v):{v}case .err(_):{assert(false);lexer::empty()}};
}
fn usize next(ref u8[] source,ref mut lexer::State s){return switch(lexer::next(source,s)){
    case .ok(_):{s.kind as usize}case .err(_):{assert(false);0}
};}
fn functions::Table signatures(ref u8[] source,ref context::Table scope,ref entries::Entry e){
    return switch(functions::scan_scoped(source,scope,e,false)){case .ok(v):{v}case .err(_):{assert(false);functions::empty()}};
}

@test fn void exact_files_have_independent_bom_comment_and_eof_fences(){
    let ref u8[] a=b"module a;pub fn i32 chosen(){return 42;}//tail";
    let ref u8[] b=b"\xEF\xBB\xBFmodule b;pub fn i32 answer(){return 42;}";
    let entries::Entry e=entry(a,b);let context::Input packed=input(ref e);
    let ref u8[] data=ref packed.data;let ref u8[] source=data[..packed.used];
    assert(bytes::equal(source[..a.len],a) && bytes::equal(source[a.len..],b));
    var lexer::State s=state(source,ref packed.context,0);while(s.kind!=0 || s.cursor==0){let usize token=next(source,ref mut s);}
    assert(s.cursor==a.len && s.begin==a.len);
    s=state(source,ref packed.context,a.len);assert(next(source,ref mut s)==2);
    assert(s.begin==a.len+3 && bytes::equal(source[s.begin..s.end],b"module"));
    let functions::Table f=signatures(source,ref packed.context,ref e);assert(f.count==2 && f.entry==0);
    switch(context::location(source,ref packed.context,s.begin)){case .ok(v):{assert(v.source==1 && v.start==3);}case .err(_):{assert(false);}};
}

@test fn void duplicate_function_spellings_are_local_and_explicit_aliases_enforce_pub(){
    let entries::Entry e=entry(
        b"module a;import b as m;fn bool main(bool x){return x;}fn i32 hidden(){return 1;}pub fn i32 chosen(){m /*c*/ :: answer();m::hidden();hidden();}",
        b"module b;fn i32 hidden(){return 2;}pub fn i32 answer(){return 42;}");
    let context::Input packed=input(ref e);let ref u8[] data=ref packed.data;let ref u8[] source=data[..packed.used];
    let functions::Table f=signatures(source,ref packed.context,ref e);assert(f.count==5 && f.entry==2 && f.arities[0]==1);
    var lexer::State s=state(source,ref packed.context,f.bodies[2]);assert(next(source,ref mut s)==5 && s.kind==5);
    assert(functions::find(source,ref f,s.begin,s.end)==4);
    while(s.kind!=59){let usize token=next(source,ref mut s);}assert(next(source,ref mut s)==5);
    assert(functions::find(source,ref f,s.begin,s.end)==16);
    while(s.kind!=59){let usize token=next(source,ref mut s);}assert(next(source,ref mut s)==2);
    assert(functions::find(source,ref f,s.begin,s.end)==1);
}

@test fn void qualified_record_signatures_and_fields_preserve_nominal_ids(){
    let entries::Entry e=entry(
        b"module a;import b as m;pub struct Point{i32 value;}pub fn m::Point relay(m /*x*/ :: Point p){return p;}pub fn i32 chosen(){return 42;}",
        b"module b;pub struct Point{i64 value;}pub struct Box{Point item;}pub fn Box make(Point p){return p;}");
    let context::Input packed=input(ref e);let ref u8[] data=ref packed.data;let ref u8[] source=data[..packed.used];
    let functions::Table f=signatures(source,ref packed.context,ref e);assert(f.return_records[0]==2 && f.param_records[0]==2 && f.return_records[2]==3);
    let records::Table r=switch(records::scan_scoped(source,ref packed.context)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(r.layouts.count==3 && r.layouts.kinds[32]==1 && r.layouts.types[32]==1);
    var lexer::State s=state(source,ref packed.context,context::begin(packed.context.functions[0]));
    let usize at=f.param_begins[0];s=state(source,ref packed.context,at);assert(next(source,ref mut s)==2 && bytes::equal(source[s.begin..s.end],b"p"));
    // Local labels and plain parameter names stay plain identifiers.
    assert(records::find(source,ref r,r.begins[0],r.ends[0])==0 && records::find(source,ref r,r.begins[1],r.ends[1])==1);
}

@test fn void cross_module_record_cycles_private_types_and_qualified_binders_fail(){
    let entries::Entry cyclic=entry(b"module a;import b as m;pub struct A{m::B child;}pub fn i32 chosen(){return 0;}",
        b"module b;import a as m;pub struct B{m::A child;}");
    let context::Input cycle=input(ref cyclic);let ref u8[] cd=ref cycle.data;assert(!records::scan_scoped(cd[..cycle.used],ref cycle.context).is_ok);
    let entries::Entry private=entry(b"module a;import b as m;pub fn m::Hidden take(){return x;}pub fn i32 chosen(){return 0;}",b"module b;struct Hidden{i32 x;}");
    let context::Input hidden=input(ref private);let ref u8[] hd=ref hidden.data;
    assert(!functions::scan_scoped(hd[..hidden.used],ref hidden.context,ref private,false).is_ok);
    let entries::Entry binder=entry(b"module a;struct A{i32 m::field;}pub fn i32 chosen(){return 0;}",b"");
    let context::Input bad=input(ref binder);let ref u8[] bd=ref bad.data;assert(!records::scan_scoped(bd[..bad.used],ref bad.context).is_ok);
}

@test fn void text_namespace_alias_is_distinct_from_builtin_text_operations(){
    let entries::Entry explicit=entry(b"module a;import b as text;pub fn i32 chosen(){text::bytes();}",b"module b;pub fn i32 bytes(){return 42;}");
    let context::Input yes=input(ref explicit);let ref u8[] yd=ref yes.data;let ref u8[] ys=yd[..yes.used];
    let functions::Table yf=signatures(ys,ref yes.context,ref explicit);
    var lexer::State s=state(ys,ref yes.context,yf.bodies[yf.entry]);assert(next(ys,ref mut s)==5);
    assert(functions::find(ys,ref yf,s.begin,s.end)==1);
    let entries::Entry builtin=entry(b"module a;pub fn i32 chosen(){text::bytes(value);}",b"");
    let context::Input no=input(ref builtin);let ref u8[] nd=ref no.data;let ref u8[] ns=nd[..no.used];
    let functions::Table nf=signatures(ns,ref no.context,ref builtin);s=state(ns,ref no.context,nf.bodies[nf.entry]);
    assert(next(ns,ref mut s)==2 && bytes::equal(ns[s.begin..s.end],b"text"));assert(next(ns,ref mut s)==58);
}

@test fn void forged_context_metadata_and_file_crossing_queries_fail_closed(){
    let entries::Entry e=entry(b"module a;pub fn i32 chosen(){return 42;}",b"module b;pub struct P{i32 x;}");
    let context::Input packed=input(ref e);let ref u8[] data=ref packed.data;let ref u8[] source=data[..packed.used];
    var context::Table candidate=packed.context;candidate.imports=65;
    assert(!context::valid(source,ref candidate) && context::lookup(source,ref candidate,0,1,false)==16);
    assert(!context::state(source,ref candidate,0).is_ok);
    candidate=packed.context;candidate.modules=17;assert(!context::valid(source,ref candidate));
    candidate=packed.context;candidate.ends[0]=4097;assert(!context::valid(source,ref candidate));
    candidate=packed.context;candidate.functions[0]=4294967295;assert(!context::valid(source,ref candidate));
    assert(context::lookup(source,ref packed.context,0,source.len,false)==16);
    assert(!context::location(source,ref packed.context,source.len+1).is_ok);
    var lexer::State s=state(source,ref packed.context,0);s.cursor=source.len;assert(!lexer::next(source,ref mut s).is_ok);
}
