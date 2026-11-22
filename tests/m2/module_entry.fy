module tests::m2::module_entry;
import module_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import std::bytes as bytes;

fn sources::Builder builder(){return switch(sources::builder(4096,4096)){
    case .ok(v):{v}case .err(_):{assert(false);builder()}
};}
fn usize added(Result<usize,sources::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn modules::Index index(ref u8[] a,ref u8[] b){
    var sources::Builder scratch=builder();let usize x=added(sources::add(ref mut scratch,b"first",a));
    if(b.len!=0){let usize y=added(sources::add(ref mut scratch,b"second",b));}
    let sources::Snapshot snapshot=switch(sources::freeze(ref scratch)){
        case .ok(v):{v}case .err(_):{assert(false);return index(b"module a;",b"");}
    };
    return switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);index(b"module a;",b"")}};
}
fn entries::Entry kept(ref u8[] a,ref u8[] b,ref u8[] path,ref u8[] name){
    return switch(entries::select_i32(index(a,b),path,name)){
        case .ok(v):{v}case .err(_):{assert(false);kept(b"module a;pub fn i32 f(){}",b"",b"a",b"f")}
    };
}
fn u8 kind(modules::Failure e){return switch(e){
    case .Lexical:{0}case .Syntax:{1}case .Limit:{2}case .Duplicate:{3}case .Missing:{4}
    case .Private:{5}case .Reserved:{6}case .Bounds:{7}case .Kind:{8}case .Allocation:{9}case .Deadline:{10}case .DeclarationLimit:{11}
};}
fn void wrong(ref u8[] source,ref u8[] spelling){
    let modules::Index candidate=index(source,b"");
    let sources::Span expected=switch(entries::select_i32(index(source,b""),b"a",b"chosen")){
        case .ok(_):{assert(false);sources::no_source()}
        case .err(e):{assert(kind(e.kind)==8);e.at}
    };
    assert(expected.source==0);
    switch(sources::view(modules::snapshot(ref candidate),expected)){
        case .ok(v):{assert(bytes::equal(v,spelling));}case .err(_):{assert(false);}
    };
}
fn void binding(ref u8[] source,ref u8[] path,ref u8[] name,u8 expected){
    switch(entries::select_i32(index(source,b""),path,name)){
        case .ok(_):{assert(false);}
        case .err(e):{assert(kind(e.kind)==if(expected==0){4}else{if(expected==1){5}else{8}});}
    };
}

@test fn void explicit_public_i32_entry_keeps_its_own_module_and_symbol(){
    let entries::Entry entry=kept(
        b"module client;import util as u;pub fn bool chosen(i32 x){return true;}",
        b"module util;fn bool helper(i32 x){return true;}pub fn i32 chosen(){return 42;}",b"util",b"chosen");
    let ref modules::Index p=entries::index(ref entry);
    let modules::Symbol symbol=switch(modules::symbol(p,entries::selected(ref entry))){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    assert(symbol.owner==1 && symbol.exported && symbol.kind==1);
    assert(entries::signature_span(ref entry).source==1);
    switch(sources::view(modules::snapshot(p),entries::signature_span(ref entry))){
        case .ok(v):{assert(bytes::equal(v,b"pub fn i32 chosen()"));}case .err(_):{assert(false);}
    };
}

@test fn void non_i32_and_reference_or_aggregate_result_abis_are_rejected(){
    wrong(b"module a;pub fn bool chosen(){return true;}",b"bool");
    wrong(b"module a;pub fn i64 chosen(){return 42;}",b"i64");
    wrong(b"module a;pub fn u8 chosen(){return 42;}",b"u8");
    wrong(b"module a;pub fn u32 chosen(){return 42;}",b"u32");
    wrong(b"module a;pub fn usize chosen(){return 42;}",b"usize");
    wrong(b"module a;pub fn void chosen(){}",b"void");
    wrong(b"module a;pub fn ref u8[] chosen(){return data;}",b"ref");
    wrong(b"module a;pub fn ref mut i32[] chosen(){return data;}",b"ref");
    wrong(b"module a;pub fn i32[2] chosen(){return data;}",b"[");
    wrong(b"module a;struct Point{i32 x;}pub fn Point chosen(){return data;}",b"Point");
    wrong(b"module a;pub fn Result<i32,i32> chosen(){return data;}",b"Result");
}

@test fn void parameters_and_header_ambiguity_cannot_pass_name_binding_as_signature_proof(){
    wrong(b"module a;pub fn i32 chosen(i32 x){return x;}",b"i32");
    wrong(b"module a;pub fn i32 chosen(ref u8[] x){return 0;}",b"ref");
    wrong(b"module a;pub fn i32 chosen(ref mut i32[] x){return 0;}",b"ref");
    wrong(b"module a;pub fn i32 chosen(,){return 0;}",b",");
    wrong(b"module a;pub fn i32 chosen(( )){return 0;}",b"(");
    wrong(b"module a;pub fn i32 extra chosen(){return 0;}",b"extra");
    wrong(b"module a;pub fn nonsense i32 chosen(){return 0;}",b"nonsense");
}

@test fn void absent_private_and_struct_selections_preserve_original_binding_failures(){
    let ref u8[] source=b"module a;fn i32 hidden(){return 0;}pub struct Point{i32 x;}pub fn i32 chosen(){return 42;}";
    binding(source,b"missing",b"chosen",0);binding(source,b"a",b"missing",0);
    binding(source,b"a",b"hidden",1);binding(source,b"a",b"Point",2);
    binding(source,b"a",b"",0);
}

@test fn void bom_utf8_comments_and_crlf_keep_original_selected_file_spans(){
    let entries::Entry entry=kept(b"module first;",
        b"\xEF\xBB\xBFmodule util;//\xED\x95\x9C\r\npub /*\xED\x95\x9C*/ fn i32 chosen /*name*/ ( /*empty*/ ) {return 42;}",b"util",b"chosen");
    let sources::Span span=entries::signature_span(ref entry);assert(span.source==1 && span.start==22);
    let ref sources::Snapshot snapshot=modules::snapshot(entries::index(ref entry));
    switch(sources::view(snapshot,span)){
        case .ok(v):{assert(bytes::equal(v,b"pub /*\xED\x95\x9C*/ fn i32 chosen /*name*/ ( /*empty*/ ) "));}case .err(_):{assert(false);}
    };
    switch(sources::position(snapshot,span)){case .ok(v):{assert(v.line==2 && v.byte_column==1);}case .err(_):{assert(false);}};
    switch(entries::select_i32(index(b"module first;",b"\xEF\xBB\xBFmodule util;//\xED\x95\x9C\r\npub fn bool chosen(){return true;}"),b"util",b"chosen")){
        case .ok(_):{assert(false);}case .err(e):{
            assert(e.at.source==1 && e.at.start==29 && e.at.end==33);
            assert(kind(e.kind)==8);
        }
    };
}

@test fn void selection_retains_frozen_source_and_does_not_claim_body_or_ir_admission(){
    var sources::Builder scratch=builder();
    let ref u8[] original=b"module own;pub fn i32 chosen(){return unresolved();}";
    let usize id=added(sources::add(ref mut scratch,b"opaque-identity",original));
    let sources::Snapshot snapshot=switch(sources::freeze(ref scratch)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let modules::Index indexed=switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    scratch.data[0]=0;scratch.names[0]=0;scratch.count=0;
    let entries::Entry entry=switch(entries::select_i32(indexed,b"own",b"chosen")){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let ref sources::Snapshot retained=modules::snapshot(entries::index(ref entry));
    switch(sources::name(retained,0)){case .ok(v):{assert(bytes::equal(v,b"opaque-identity"));}case .err(_):{assert(false);}};
    switch(sources::view(retained,sources::Span{.source=0,.start=0,.end=original.len})){
        case .ok(v):{assert(bytes::equal(v,original));}case .err(_):{assert(false);}
    };
    assert(entries::selected(ref entry)==0);
}
