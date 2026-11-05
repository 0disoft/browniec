module tests::m2::module_index;
import module_index as modules;
import source_snapshot as sources;
import std::bytes as bytes;

fn sources::Builder builder(){return switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{assert(false);builder()}};}
fn usize added(Result<usize,sources::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn Result<modules::Index,modules::Error> pair(ref u8[] a,ref u8[] b){
    var sources::Builder scratch=builder();let usize x=added(sources::add(ref mut scratch,b"first",a));
    if(b.len!=0){let usize y=added(sources::add(ref mut scratch,b"second",b));}
    let sources::Snapshot snapshot=switch(sources::freeze(ref scratch)){case .ok(v):{v}case .err(_):{assert(false);return pair(a,b);}};
    return modules::build(snapshot);
}
fn modules::Index kept(ref u8[] a,ref u8[] b){return switch(pair(a,b)){case .ok(v):{v}case .err(_):{assert(false);kept(b"module main;",b"")}};}
fn u8 kind(modules::Failure e){return switch(e){case .Lexical:{0}case .Syntax:{1}case .Limit:{2}case .Duplicate:{3}case .Missing:{4}case .Private:{5}case .Reserved:{6}case .Bounds:{7}case .Kind:{8}case .Allocation:{9}};}
fn modules::Error rejected(ref u8[] a,ref u8[] b,u8 expected){
    return switch(pair(a,b)){case .ok(_):{assert(false);modules::Error{.kind=.Bounds,.at=sources::no_source()}}
        case .err(e):{assert(kind(e.kind)==expected);e}};
}
fn usize resolved(Result<usize,modules::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void denied(Result<usize,modules::Error> r,u8 expected){switch(r){case .ok(_):{assert(false);}case .err(e):{assert(kind(e.kind)==expected);}};}
fn modules::Symbol symbol(ref modules::Index p,usize id){return switch(modules::symbol(p,id)){
    case .ok(v):{v}case .err(_):{assert(false);modules::Symbol{.owner=16,.kind=0,.exported=false,.name=sources::no_source(),.definition=sources::no_source()}}
};}
fn bool text(ref modules::Index p,sources::Span span,ref u8[] expected){
    return switch(sources::view(modules::snapshot(p),span)){case .ok(v):{bytes::equal(v,expected)}case .err(_):{false}};
}

@test fn void normalized_paths_forward_imports_and_symbols_retain_exact_source_locations(){
    let modules::Index p=kept(
        b"module client;import util::math as m;fn i32 secret(){return 7;}pub fn i32 main(){return m::answer();}",
        b"module util /*split*/ :: math;pub struct Point{i32 x;i32 y;}fn i32 secret(){return 9;}pub fn i32 answer(){return 42;}");
    assert(modules::count(ref p)==2 && modules::symbol_count(ref p)==5);
    assert(resolved(modules::find(ref p,b"client"))==0 && resolved(modules::find(ref p,b"util::math"))==1);
    switch(modules::module_name(ref p,1)){case .ok(v):{assert(bytes::equal(v,b"util::math"));}case .err(_):{assert(false);}};
    let usize id=resolved(modules::resolve(ref p,0,b"m",b"answer"));let modules::Symbol answer=symbol(ref p,id);
    assert(answer.owner==1 && answer.kind==1 && answer.exported && answer.name.source==1);
    assert(text(ref p,answer.name,b"answer") && text(ref p,answer.definition,b"pub fn i32 answer(){return 42;}"));
    assert(resolved(modules::entry(ref p,b"client",b"main"))==1);
    let modules::Symbol point=symbol(ref p,resolved(modules::resolve(ref p,0,b"m",b"Point")));
    assert(point.kind==2 && point.owner==1 && point.exported);
    let modules::Module m=switch(modules::module_at(ref p,1)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(text(ref p,m.path,b"util /*split*/ :: math"));
}

@test fn void alias_scopes_visibility_public_entry_and_pure_import_cycles_are_bounded(){
    let modules::Index p=kept(
        b"module a;import b as other;fn i32 secret(){return 1;}pub fn i32 main(){return other::visible();}",
        b"module b;import a as peer;fn i32 hidden(){return 2;}pub fn i32 visible(){return peer::main();}pub struct Value{i32 x;}");
    assert(symbol(ref p,resolved(modules::resolve(ref p,0,b"",b"secret"))).owner==0);
    denied(modules::resolve(ref p,0,b"other",b"hidden"),5);
    denied(modules::resolve(ref p,1,b"peer",b"secret"),5);
    denied(modules::resolve(ref p,0,b"b",b"visible"),4);
    denied(modules::resolve(ref p,0,b"",b"visible"),4);
    assert(symbol(ref p,resolved(modules::resolve(ref p,0,b"other",b"visible"))).owner==1);
    denied(modules::entry(ref p,b"a",b"secret"),5);
    denied(modules::entry(ref p,b"b",b"Value"),8);
    denied(modules::resolve(ref p,16,b"",b"main"),7);
    assert(!modules::module_at(ref p,2).is_ok && !modules::symbol(ref p,48).is_ok);
    let modules::Index self=kept(b"module own;import own as me;fn i32 hidden(){return 0;}pub fn bool chosen(i32 x){return true;}",b"");
    assert(symbol(ref self,resolved(modules::resolve(ref self,0,b"me",b"hidden"))).owner==0);
    assert(symbol(ref self,resolved(modules::entry(ref self,b"own",b"chosen"))).exported);
}

@test fn void missing_ambiguous_duplicate_and_reserved_names_fail_at_original_source_spans(){
    let modules::Error missing=rejected(b"module a; import none as n;",b"",4);
    assert(missing.at.source==0 && missing.at.start==17 && missing.at.end==21);
    let modules::Error duplicate=rejected(b"module a::b;",b"module a /*same*/ :: b;",3);assert(duplicate.at.source==1);
    let modules::Error alias=rejected(b"module a;import b as x;import b as x;",b"module b;",3);assert(alias.at.source==0);
    let modules::Error symbol=rejected(b"module a;fn i32 same(){return 0;}pub struct same{i32 x;}",b"",3);
    let modules::Error reserved=rejected(b"module std::guest;",b"",6);
    let modules::Error reserved_other=rejected(b"module brownie;",b"",6);
    let modules::Error late=rejected(b"module a;fn i32 f(){return 0;}import a as self;",b"",1);
    let modules::Error implicit=rejected(b"module a;import a;",b"",1);
}

@test fn void lexing_balanced_bodies_and_empty_input_report_checked_source_spans(){
    let modules::Index p=kept(b"\xEF\xBB\xBFmodule a;pub fn i32 f(){/* { } */let ref str t=\"module fake;pub fn i32 x(){}\";return 42;}",b"");
    assert(modules::count(ref p)==1 && modules::symbol_count(ref p)==1);
    let modules::Error nul=rejected(b"module a;\x00",b"",0);assert(nul.at.source==0 && nul.at.start==9 && nul.at.end==10);
    let modules::Error open=rejected(b"module a;fn i32 f(){",b"",1);assert(open.at.start==20 && open.at.end==20);
    let modules::Error missing_semicolon=rejected(b"module a fn i32 f(){}",b"",1);
    let modules::Error name=rejected(b"module a;import a as fn;",b"",1);
    var sources::Builder scratch=builder();let sources::Snapshot empty=switch(sources::freeze(ref scratch)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    switch(modules::build(empty)){case .ok(_):{assert(false);}case .err(e):{assert(kind(e.kind)==4 && e.at.source==16);}};
}

fn void append(ref mut bytes::Buffer b,ref u8[] text){assert(bytes::append(b,text).is_ok);}
fn void symbol_limit(bool functions){
    var bytes::Buffer source=bytes::empty();append(ref mut source,b"module a;");
    var u8[2] name=[97,65];var usize i=0;let usize limit=if(functions){17}else{33};
    while(i<limit){append(ref mut source,if(functions){b"fn i32 "}else{b"struct "});
        append(ref mut source,ref name);append(ref mut source,if(functions){b"(){return 0;}"}else{b"{}"});
        if(name[1]==90){name[1]=65;name[0]+=1;}else{name[1]+=1;}i+=1;
    }
    let modules::Error failure=rejected(bytes::view(ref source),b"",2);
}
@test fn void global_function_record_and_token_budgets_reject_before_table_overflow(){
    symbol_limit(true);symbol_limit(false);
    var bytes::Buffer a=bytes::empty();var bytes::Buffer b=bytes::empty();
    append(ref mut a,b"module a;fn i32 f(){");append(ref mut b,b"module b;fn i32 f(){");
    var usize i=0;while(i<300){append(ref mut a,b"1;");append(ref mut b,b"1;");i+=1;}
    append(ref mut a,b"}");append(ref mut b,b"}");
    let modules::Error failure=rejected(bytes::view(ref a),bytes::view(ref b),2);
    assert(failure.at.source==1 && failure.at.start==bytes::len(ref b) && failure.at.end==bytes::len(ref b));
}

@test fn void source_owner_survives_input_changes_and_queries_never_reopen_names(){
    var sources::Builder scratch=builder();
    let ref u8[] source=b"module a;pub fn i32 f(){return 42;}";
    let usize id=added(sources::add(ref mut scratch,b"not/a/path",source));
    let sources::Snapshot snapshot=switch(sources::freeze(ref scratch)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let modules::Index p=switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    scratch.data[0]=0;scratch.names[0]=0;scratch.count=0;
    let modules::Symbol f=symbol(ref p,resolved(modules::entry(ref p,b"a",b"f")));
    assert(text(ref p,f.definition,source[9..]));
    switch(sources::name(modules::snapshot(ref p),0)){case .ok(v):{assert(bytes::equal(v,b"not/a/path"));}case .err(_):{assert(false);}};
    denied(modules::find(ref p,b"not/a/path"),4);
}
