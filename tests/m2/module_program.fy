module tests::m2::module_program;
import module_program as programs;
import module_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import std::bytes as bytes;

fn sources::Builder builder(){return switch(sources::builder(4096,4096)){
    case .ok(v):{v}case .err(_):{assert(false);builder()}
};}
fn usize added(Result<usize,sources::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn entries::Entry entry(ref u8[] a,ref u8[] b){
    var sources::Builder scratch=builder();let usize x=added(sources::add(ref mut scratch,b"library",a));
    if(b.len!=0){let usize y=added(sources::add(ref mut scratch,b"application",b));}
    let sources::Snapshot snapshot=switch(sources::freeze(ref scratch)){case .ok(v):{v}case .err(_):{assert(false);return entry(b"module app;pub fn i32 chosen(){return 0;}",b"");}};
    let modules::Index index=switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);return entry(b"module app;pub fn i32 chosen(){return 0;}",b"");}};
    return switch(entries::select_i32(index,b"app",b"chosen")){case .ok(v):{v}case .err(_):{assert(false);entry(b"module app;pub fn i32 chosen(){return 0;}",b"")}};
}
fn programs::Program kept(ref u8[] a,ref u8[] b){return switch(programs::compile(entry(a,b),65536)){
    case .ok(v):{v}case .err(_):{assert(false);kept(b"module app;pub fn i32 chosen(){return 0;}",b"")}
};}
fn void result(Result<i64,diagnostics::Error> r,i64 expected){switch(r){case .ok(v):{assert(v==expected);}case .err(_):{assert(false);}};}
fn void value(ref u8[] a,ref u8[] b,i64 expected){let programs::Program p=kept(a,b);result(programs::run(ref p,16000000),expected);result(programs::run(ref p,16000000),expected);}
fn void rejected(ref u8[] a,ref u8[] b,usize owner){switch(programs::compile(entry(a,b),65536)){
    case .ok(_):{assert(false);}case .err(e):{
        assert(e.code.kind==2 || e.code.kind==3 || e.code.kind==4);
        assert(e.at.source==owner && e.at.start<=e.at.end && e.at.end<=if(owner==0){a.len}else{b.len});
    }
};}

@test fn void selected_nonfirst_entry_and_private_helpers_execute_with_exact_scalar_fuel(){
    let programs::Program p=kept(b"module lib;pub fn i32 answer(){return 42;}",b"module app;import lib as m;pub fn i32 chosen(){return m::answer();}");
    assert(programs::body(ref p).entry==1 && programs::profile(ref p)==0);
    result(programs::run(ref p,4),42);result(programs::run(ref p,5),42);
    switch(programs::run(ref p,3)){case .ok(_):{assert(false);}case .err(e):{assert(e.code.kind==8);}};
    value(b"module lib;fn i32 hidden(){return 20;}pub fn i32 add(i32 x){return hidden()+x;}",
        b"module app;import lib as m;fn bool main(bool x){return x;}fn i32 hidden(){return 0;}pub fn i32 chosen(){let i32 m=900;return m::add(22);}",42);
}

@test fn void qualified_owned_array_calls_and_exclusive_borrows_keep_ownership(){
    value(b"module lib;pub fn i32[2] make(){return [20;2];}pub fn i32 sum(i32[2] a){return a[0]+a[1];}pub fn i32 bump(ref mut i32[] a){a[0]=a[0]+2;return 0;}",
        b"module app;import lib as m;pub fn i32 chosen(){var i32[2] a=m::make();let i32 n=m::bump(ref mut a);return m::sum(a);}",42);
}
@test fn void inferred_scalar_locals_resolve_qualified_calls_and_original_error_sources(){
    value(b"module lib;pub fn i64 answer(){return 40;}pub struct P{i32 x;}pub fn P point(){return P{.x=2};}",
        b"module app;import lib as m;pub fn i32 chosen(){let n=m::answer();let m::P p=m::point();let x=p.x;if(n==40){return x+40;}return 0;}",42);
    rejected(b"module lib;pub fn i32 bad(){let n=missing;return n;}",
        b"module app;pub fn i32 chosen(){return 42;}",0);
}
@test fn void inferred_aggregate_calls_constructors_and_child_paths_keep_scoped_nominal_types(){
    value(b"module lib;pub struct P{i32 x;}pub struct Box{P inner;}pub fn i32[2] make(i32 n){return [n;2];}pub fn Box pack(P p){return Box{.inner=p};}",
        b"module app;import lib as m;pub fn i32 chosen(){let a=m::make(21);let box=m::pack(m::P{.x=a[0]});let p=box.inner;return p.x+a[1];}",42);
    rejected(b"module lib;pub struct P{i32 x;}pub fn P make(){return P{.x=1};}",
        b"module app;import lib as m;struct P{i32 x;}pub fn i32 chosen(){var p=m::make();p=P{.x=2};return p.x;}",1);
}
@test fn void inferred_reference_aliases_and_return_origins_keep_qualified_resolution(){
    value(b"module lib;pub fn ref u8[] tail(ref u8[] p){let q=p;return ref q[1..];}",
        b"module app;import lib as m;pub fn i32 chosen(){let p=m::tail(ref [42;3]);let q=p;let text=\"*\";let b=text::bytes(text);if(q.len==2 && b[0]==42){return q[0] as i32;}return 0;}",42);
    rejected(b"module lib;pub fn ref u8[] bad(ref u8[] p){let q=missing;return ref q;}",
        b"module app;pub fn i32 chosen(){return 42;}",0);
}

@test fn void qualified_record_constructors_arguments_results_and_fields_keep_nominal_identity(){
    value(b"module lib;pub struct Point{i32 x;i32 y;}pub struct Box{Point inner;}pub fn Point make(){return Point{.x=20,.y=22};}pub fn Box pack(Point p){return Box{.inner=p};}",
        b"module app;import lib as m;struct Point{i64 other;}pub fn i32 chosen(){var m::Point p=m::make();let m::Box box=m::pack(p);p.x=1;return box.inner.x+box.inner.y;}",42);
    value(b"module lib;pub struct P{i32 x;}pub struct R{P a;P b;}pub fn P make(i32 x){return P{.x=x};}",
        b"module app;import lib as m;pub fn i32 chosen(){var m::R r=m::R{.a=m::make(20),.b=m::P{.x=22}};r.a=m::make(21);r.a.x=20;let m::P p=r.b;return r.a.x+p.x;}",42);
}

@test fn void shared_byte_returns_literals_ranges_and_text_cross_real_module_calls(){
    value(b"module lib;pub fn ref u8[] tail(ref u8[] p){return ref p[1..];}pub fn ref u8[] own(){return b\"*\";}",
        b"module app;import lib as m;pub fn i32 chosen(){let ref u8[] a=m::tail(ref b\"abc\");if(a.len==2 && a[0]==98 && a[1]==99){let ref u8[] b=m::own();return b[0] as i32;}return 0;}",42);
    value(b"module lib;pub fn ref u8[] data(){return text::bytes(\"\xED\x95\x9C\");}",
        b"module app;import lib as m;pub fn i32 chosen(){return m::data()[0] as i32;}",237);
    value(b"module lib;pub fn ref u8[] same(ref u8[] p){return ref p;}",
        b"module app;import lib as m;pub fn i32 chosen(){return m::same(ref [42;1])[0] as i32;}",42);
}

@test fn void private_unknown_wrong_typed_and_unreachable_bad_bodies_fail_before_publication(){
    rejected(b"module lib;fn i32 hidden(){return 42;}",b"module app;import lib as m;pub fn i32 chosen(){return m::hidden();}",1);
    rejected(b"module lib;pub fn i32 add(i32 a,i32 b){return a+b;}",b"module app;import lib as m;pub fn i32 chosen(){return m::add(1);}",1);
    rejected(b"module lib;pub struct P{i32 x;}pub fn i32 take(P p){return p.x;}",b"module app;import lib as m;struct P{i32 x;}pub fn i32 chosen(){let P p=P{.x=42};return m::take(p);}",1);
    rejected(b"module lib;fn i32 bad(){return true;}",b"module app;pub fn i32 chosen(){return 42;}",0);
    rejected(b"module lib;pub fn i32 answer(){return 42;}",b"module app;import lib as m;pub fn i32 chosen(){let i32 m::bad=1;return 42;}",1);
    rejected(b"module lib;struct Hidden{i32 x;}",b"module app;import lib as m;pub fn i32 chosen(){let m::Hidden x=m::Hidden{.x=42};return 42;}",1);
}

@test fn void retained_original_sources_map_runtime_errors_and_disambiguate_file_eof(){
    let ref u8[] a=b"\xEF\xBB\xBFmodule lib;\r\npub fn i32 fail(i32 x){return 42/x;}//tail";
    let ref u8[] b=b"\xEF\xBB\xBFmodule app;import lib as m;pub fn i32 chosen(){return m::fail(0);}";
    let programs::Program p=kept(a,b);
    switch(programs::run(ref p,16000000)){case .ok(_):{assert(false);}case .err(e):{
        assert(e.code.kind==7 && e.at.source==0);
        switch(sources::view(programs::snapshot(ref p),e.at)){case .ok(v):{assert(bytes::equal(v,b"/"));}case .err(_):{assert(false);}};
    }};
    let diagnostics::Error eof=diagnostics::map(programs::snapshot(ref p),errors::make(2,a.len),0);
    assert(eof.at.source==0 && eof.at.start==a.len && eof.at.end==a.len);
    let diagnostics::Error following=diagnostics::map(programs::snapshot(ref p),errors::make(2,a.len),16);
    assert(following.at.source==1 && following.at.start==0);
    switch(sources::name(programs::snapshot(ref p),1)){case .ok(v):{assert(bytes::equal(v,b"application"));}case .err(_):{assert(false);}};
}

@test fn void import_cycles_and_explicit_text_aliases_execute_without_builtin_or_transitive_fallback(){
    value(b"module lib;import app as a;pub fn i32 n(){return a::base()+2;}",b"module app;import lib as text;pub fn i32 base(){return 40;}pub fn i32 chosen(){return text::n();}",42);
    rejected(b"module lib;pub fn i32 answer(){return 42;}",b"module app;pub fn i32 chosen(){return lib::answer();}",1);
}

fn void append(ref mut bytes::Buffer b,ref u8[] v){assert(bytes::append(b,v).is_ok);}
fn void depth(usize n,bool retained,bool pass){
    var bytes::Buffer b=bytes::empty();append(ref mut b,b"module app;import lib as m;pub fn i32 chosen(){");
    if(retained){append(ref mut b,b"let ref u8[] marker=b\"*\";");}append(ref mut b,b"return ");
    var usize i=0;while(i<n){append(ref mut b,b"m::id(");i+=1;}append(ref mut b,b"42");
    i=0;while(i<n){append(ref mut b,b")");i+=1;}append(ref mut b,b";}");
    let ref u8[] lib=b"module lib;pub fn i32 id(i32 x){return x;}";
    if(pass){value(lib,bytes::view(ref b),42);}else{rejected(lib,bytes::view(ref b),1);}
}
@test fn void both_compiler_routes_keep_the_32_deep_call_limit_without_native_stack_overrides(){
    depth(32,false,true);depth(32,true,true);depth(33,false,false);depth(33,true,false);
}
@test fn void scalar_element_lists_cross_qualified_calls_and_owned_results(){
    let ref u8[] library=b"module lib;pub fn u8[2] make(){return [20,22];}pub fn i32 take(u8[2] a){return a[0] as i32+a[1] as i32;}";
    value(library,b"module app;import lib as m;pub fn i32 chosen(){let a=m::make();return m::take([a[0],a[1]]);}",42);
    value(library,b"module app;import lib as m;pub fn i32 chosen(){let ref u8[] marker=b\"*\";let a=m::make();return m::take([a[0],a[1]]);}",42);
}
@test fn void scalar_list_replacements_cross_qualified_calls_with_existing_destinations(){
    let ref u8[] library=b"module lib;pub fn u8[2] make(){var u8[2] a=[0;2];a=[20,22];return a;}pub fn u8 first(){return 22;}";
    value(library,b"module app;import lib as m;pub fn i32 chosen(){var a=m::make();a=[m::first(),a[0]];return a[0] as i32+a[1] as i32;}",42);
    value(library,b"module app;import lib as m;pub fn i32 chosen(){let ref u8[] marker=b\"*\";var a=m::make();a=[m::first(),a[0]];return a[0] as i32+a[1] as i32;}",42);
}
@test fn void array_literal_projections_execute_across_both_qualified_compiler_routes(){
    let ref u8[] library=b"module lib;pub fn i32 answer(){return [20,42][1];}";
    value(library,b"module app;import lib as m;pub fn i32 chosen(){let n=[m::answer(),0][0];let size=([true,false]).len;if(size==2){return n;}return 0;}",42);
    value(library,b"module app;import lib as m;pub fn i32 chosen(){let ref u8[] marker=b\"*\";let n=[m::answer(),0][0];let size=([true,false]).len;if(size==2){return n;}return 0;}",42);
}

fn void admission_rejected(ref u8[] a,ref u8[] b,usize limit,u8 kind,usize owner){
    switch(programs::compile(entry(a,b),limit)){case .ok(_):{assert(false);}case .err(e):{
        assert(e.code.kind==kind && e.at.source==owner);
        if(owner==1){assert(e.at.start<b.len && b[e.at.start]==116);}
    }};
}
@test fn void image_quotas_have_no_source_span_and_proof_offsets_map_through_original_instructions(){
    let ref u8[] library=b"module lib;pub fn ref u8[] own(){return b\"*\";}";
    let ref u8[] app=b"module app;import lib as m;pub fn i32 chosen(){return m::own()[0] as i32;}";
    let programs::Program exact=switch(programs::compile(entry(library,app),577)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    result(programs::run(ref exact,16000000),42);
    admission_rejected(library,app,576,4,16);
    let ref u8[] generic=b"module lib;pub fn ref u8[] same(ref u8[] p){return ref p;}";
    let ref u8[] equality=b"module app;import lib as m;pub fn i32 chosen(){let ref u8[] p=m::same(ref b\"x\");if(text::equal(p,b\"x\")){return 42;}return 0;}";
    admission_rejected(generic,equality,65536,5,1);
}

fn void declaration_error(ref u8[] a,ref u8[] b,u8 kind,u8 first){
    switch(programs::compile(entry(a,b),65536)){case .ok(_):{assert(false);}case .err(e):{
        assert(e.code.kind==kind && e.at.source==1 && e.at.start<b.len && b[e.at.start]==first);
    }};
}
@test fn void unresolved_origins_cycles_and_deep_layouts_identify_the_actual_later_file(){
    let ref u8[] library=b"module lib;pub struct Ok{i32 x;}pub fn i32 ok(){return 0;}";
    declaration_error(library,b"module app;pub fn i32 chosen(){return 0;}pub fn ref u8[] loop(){return loop();}",3,108);
    declaration_error(library,b"module app;pub struct A{B b;}pub struct B{A a;}pub fn i32 chosen(){return 0;}",3,65);
    var bytes::Buffer deep=bytes::empty();append(ref mut deep,b"module app;");
    let ref u8[] letters=b"ABCDEFGHIJKLMNOPQ";var usize id=0;
    while(id<17){append(ref mut deep,b"pub struct ");append(ref mut deep,letters[id..id+1]);append(ref mut deep,b"{");
        if(id+1<17){append(ref mut deep,letters[id+1..id+2]);append(ref mut deep,b" child;");}
        else{append(ref mut deep,b"i32 x;");}append(ref mut deep,b"}");id+=1;
    }append(ref mut deep,b"pub fn i32 chosen(){return 0;}");
    declaration_error(library,bytes::view(ref deep),4,65);
}
