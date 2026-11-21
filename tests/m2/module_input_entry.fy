module tests::m2::module_input_entry;
import module_input_entry as entries;
import module_entry as zero;
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
fn entries::InputEntry kept(ref u8[] a,ref u8[] b,ref u8[] path,ref u8[] name){
    return switch(entries::select_i32_input(index(a,b),path,name)){
        case .ok(v):{v}case .err(_):{assert(false);kept(b"module a;pub fn i32 f(ref u8[] x){}",b"",b"a",b"f")}
    };
}
fn u8 kind(modules::Failure e){return switch(e){
    case .Lexical:{0}case .Syntax:{1}case .Limit:{2}case .Duplicate:{3}case .Missing:{4}
    case .Private:{5}case .Reserved:{6}case .Bounds:{7}case .Kind:{8}case .Allocation:{9}case .Deadline:{10}
};}
fn void wrong(ref u8[] source,ref u8[] spelling){
    let modules::Index candidate=index(source,b"");
    let sources::Span expected=switch(entries::select_i32_input(index(source,b""),b"a",b"chosen")){
        case .ok(_):{assert(false);sources::no_source()}
        case .err(e):{assert(kind(e.kind)==8);e.at}
    };
    assert(expected.source==0);
    switch(sources::view(modules::snapshot(ref candidate),expected)){
        case .ok(v):{assert(bytes::equal(v,spelling));}case .err(_):{assert(false);}
    };
}
fn void binding(ref u8[] source,ref u8[] path,ref u8[] name,u8 expected){
    switch(entries::select_i32_input(index(source,b""),path,name)){
        case .ok(_):{assert(false);}
        case .err(e):{assert(kind(e.kind)==if(expected==0){4}else{if(expected==1){5}else{8}});}
    };
}

@test fn void exact_module_name_symbol_and_parameter_spans(){
    let entries::InputEntry entry=kept(
        b"module client;import util as u;pub fn bool chosen(i32 x){return true;}",
        b"module util;fn void helper(){}pub fn i32 chosen(ref u8[] input){return unresolved();}",b"util",b"chosen");
    let ref modules::Index p=entries::index(ref entry);
    let modules::Symbol symbol=switch(modules::symbol(p,entries::selected(ref entry))){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(symbol.owner==1 && symbol.exported && symbol.kind==1 && entries::selected(ref entry)==2);
    assert(entries::signature_span(ref entry).source==1);
    switch(sources::view(modules::snapshot(p),entries::signature_span(ref entry))){
        case .ok(v):{assert(bytes::equal(v,b"pub fn i32 chosen(ref u8[] input)"));}case .err(_):{assert(false);}};
    switch(sources::view(modules::snapshot(p),entries::parameter_span(ref entry))){
        case .ok(v):{assert(bytes::equal(v,b"ref u8[] input"));}case .err(_):{assert(false);}};
    switch(sources::view(modules::snapshot(p),entries::parameter_name_span(ref entry))){
        case .ok(v):{assert(bytes::equal(v,b"input"));}case .err(_):{assert(false);}};
}

@test fn void non_i32_results_and_header_ambiguity_are_rejected(){
    wrong(b"module a;pub fn bool chosen(ref u8[] x){}",b"bool");
    wrong(b"module a;pub fn i64 chosen(ref u8[] x){}",b"i64");
    wrong(b"module a;pub fn u8 chosen(ref u8[] x){}",b"u8");
    wrong(b"module a;pub fn u32 chosen(ref u8[] x){}",b"u32");
    wrong(b"module a;pub fn usize chosen(ref u8[] x){}",b"usize");
    wrong(b"module a;pub fn void chosen(ref u8[] x){}",b"void");
    wrong(b"module a;pub fn ref u8[] chosen(ref u8[] x){}",b"ref");
    wrong(b"module a;pub fn i32[2] chosen(ref u8[] x){}",b"[");
    wrong(b"module a;struct Point{}pub fn Point chosen(ref u8[] x){}",b"Point");
    wrong(b"module a;pub fn Result<i32,i32> chosen(ref u8[] x){}",b"Result");
    wrong(b"module a;pub fn i32 extra chosen(ref u8[] x){}",b"extra");
}

@test fn void only_one_shared_byte_slice_with_valid_name_is_admitted(){
    wrong(b"module a;pub fn i32 chosen(){}",b")");
    wrong(b"module a;pub fn i32 chosen(u8[] x){}",b"u8");
    wrong(b"module a;pub fn i32 chosen(ref mut u8[] x){}",b"mut");
    wrong(b"module a;pub fn i32 chosen(ref i32[] x){}",b"i32");
    wrong(b"module a;pub fn i32 chosen(ref bool[] x){}",b"bool");
    wrong(b"module a;pub fn i32 chosen(ref u8 x){}",b"x");
    wrong(b"module a;pub fn i32 chosen(ref u8[1] x){}",b"1");
    wrong(b"module a;pub fn i32 chosen(ref u8[][] x){}",b"[");
    wrong(b"module a;pub fn i32 chosen(ref u8[]){}",b")");
    wrong(b"module a;pub fn i32 chosen(ref u8[] _){}",b"_");
    wrong(b"module a;pub fn i32 chosen(ref u8[] return){}",b"return");
    wrong(b"module a;pub fn i32 chosen(ref u8[] u8){}",b"u8");
    wrong(b"module a;pub fn i32 chosen(ref u8[] mut x){}",b"mut");
    wrong(b"module a;pub fn i32 chosen(ref u8[] x,){}",b",");
    wrong(b"module a;pub fn i32 chosen(ref u8[] x,i32 n){}",b",");
    wrong(b"module a;pub fn i32 chosen(ref u8[] x,ref u8[] y){}",b",");
    wrong(b"module a;pub fn i32 chosen(ref u8[] x=0){}",b"=");
    wrong(b"module a;pub fn i32 chosen((ref u8[] x)){}",b"(");
}

@test fn void exact_names_privacy_missing_and_nonfunction_rejections(){
    let ref u8[] source=b"module a;fn i32 hidden(ref u8[] x){}pub struct Point{}pub fn i32 chosen(ref u8[] x){}pub fn i32 Chosen(){}";
    binding(source,b"missing",b"chosen",0);binding(source,b"A",b"chosen",0);
    binding(source,b"a",b"missing",0);binding(source,b"a",b"chosenExtra",0);
    binding(source,b"a",b"hidden",1);binding(source,b"a",b"Point",2);binding(source,b"a",b"",0);
    assert(!entries::select_i32_input(index(source,b""),b"a",b"Chosen").is_ok);
    assert(entries::select_i32_input(index(source,b""),b"a",b"chosen").is_ok);
}

@test fn void bom_comments_crlf_and_nonzero_source_offsets_are_original(){
    let entries::InputEntry entry=kept(b"module first;",
        b"\xEF\xBB\xBFmodule util;//\xED\x95\x9C\r\npub /*\xED\x95\x9C*/ fn i32 chosen /*name*/ ( /*p*/ ref /*r*/ u8 [ ] data /*end*/ ) {return 42;}",b"util",b"chosen");
    let sources::Span span=entries::signature_span(ref entry);assert(span.source==1 && span.start==22);
    let ref sources::Snapshot snapshot=modules::snapshot(entries::index(ref entry));
    switch(sources::view(snapshot,span)){
        case .ok(v):{assert(bytes::equal(v,b"pub /*\xED\x95\x9C*/ fn i32 chosen /*name*/ ( /*p*/ ref /*r*/ u8 [ ] data /*end*/ ) "));}case .err(_):{assert(false);}};
    switch(sources::view(snapshot,entries::parameter_span(ref entry))){
        case .ok(v):{assert(bytes::equal(v,b"ref /*r*/ u8 [ ] data"));}case .err(_):{assert(false);}};
    switch(sources::view(snapshot,entries::parameter_name_span(ref entry))){
        case .ok(v):{assert(bytes::equal(v,b"data"));}case .err(_):{assert(false);}};
    switch(sources::position(snapshot,span)){case .ok(v):{assert(v.line==2 && v.byte_column==1);}case .err(_):{assert(false);}};
}

fn entries::InputEntry moved(entries::InputEntry entry){return entry;}
@test fn void owned_snapshot_survives_builder_mutation_and_entry_move(){
    var sources::Builder scratch=builder();
    let ref u8[] original=b"module own;pub fn i32 arbitrary(ref u8[] payload){return unresolved();}";
    let usize id=added(sources::add(ref mut scratch,b"opaque-identity",original));
    let sources::Snapshot snapshot=switch(sources::freeze(ref scratch)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let modules::Index indexed=switch(modules::build(snapshot)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    scratch.data[0]=0;scratch.names[0]=0;scratch.count=0;
    let entries::InputEntry entry=moved(switch(entries::select_i32_input(indexed,b"own",b"arbitrary")){
        case .ok(v):{v}case .err(_):{assert(false);return;}});
    let ref sources::Snapshot retained=modules::snapshot(entries::index(ref entry));
    switch(sources::name(retained,0)){case .ok(v):{assert(bytes::equal(v,b"opaque-identity"));}case .err(_):{assert(false);}};
    switch(sources::view(retained,sources::Span{.source=0,.start=0,.end=original.len})){
        case .ok(v):{assert(bytes::equal(v,original));}case .err(_):{assert(false);}};
    assert(entries::selected(ref entry)==0);
}

@test fn void zero_arg_selection_remains_separate_and_rejects_input(){
    let ref u8[] source=b"module a;pub fn i32 zero(){}pub fn i32 input(ref u8[] bytes){}";
    let zero::Entry entry=switch(zero::select_i32(index(source,b""),b"a",b"zero")){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(zero::selected(ref entry)==0);
    assert(!zero::select_i32(index(source,b""),b"a",b"input").is_ok);
    assert(!entries::select_i32_input(index(source,b""),b"a",b"zero").is_ok);
    assert(entries::select_i32_input(index(source,b""),b"a",b"input").is_ok);
}
