module tests::m2::value_type_source;

import value_type_source as parser;
import value_properties as properties;
import lexer as lexer;
import errors as errors;
import struct_source as structs;

fn lexer::State start(ref u8[] source){
    var lexer::State s=lexer::empty();
    assert(lexer::next(source,ref mut s).is_ok);return s;
}
fn usize parsed(ref u8[] source,ref mut lexer::State s,ref mut properties::Catalog c){
    return switch(parser::parse(source,s,c)){
        case .ok(id):{id}case .err(_):{assert(false);0}
    };
}
fn usize whole(ref u8[] source,ref mut properties::Catalog c){
    var lexer::State s=start(source);let usize id=parsed(source,ref mut s,c);
    assert(s.kind==0);return id;
}
fn void same_state(ref lexer::State a,ref lexer::State b){
    assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end && a.tokens==b.tokens);
    assert(a.kind==b.kind && a.value==b.value && a.min_magnitude==b.min_magnitude && a.context==b.context);
}
fn void same_catalog(ref properties::Catalog a,ref properties::Catalog b){
    assert(a.count==b.count && a.records.count==b.records.count);var usize i=0;
    while(i<64){assert(a.nodes[i].kind==b.nodes[i].kind && a.nodes[i].first==b.nodes[i].first &&
        a.nodes[i].second==b.nodes[i].second && a.nodes[i].extent==b.nodes[i].extent);i+=1;}
    i=0;while(i<32){assert(a.records.fields[i]==b.records.fields[i]);i+=1;}
    i=0;while(i<512){assert(a.records.kinds[i]==b.records.kinds[i] && a.records.types[i]==b.records.types[i]);i+=1;}
}
fn void rejected(ref u8[] source,u8 kind,usize offset,ref mut properties::Catalog c){
    var lexer::State s=start(source);let lexer::State before=lexer::snapshot(ref s);
    let properties::Catalog original=*c;
    switch(parser::parse(source,ref mut s,c)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind && e.offset==offset);}
    };same_state(ref s,ref before);same_catalog(c,ref original);
}
fn properties::Plan plan(ref properties::Catalog c){
    return switch(properties::inspect(c)){
        case .ok(p):{p}case .err(_):{assert(false);properties::Plan{.count=0,
            .properties=[properties::Property{.bytes=0,.alignment=0,.payload_offset=0,
                .wrapper_depth=0,.copyable=false,.contains_buffer=false};64]}}
    };
}
@test fn void scalar_array_buffer_spellings_and_exact_canonical_interning(){
    var properties::Catalog c=properties::empty();
    let usize signed32=whole(b"i32",ref mut c);let usize boolean=whole(b"bool",ref mut c);
    let usize signed64=whole(b"i64",ref mut c);let usize byte=whole(b"u8",ref mut c);
    let usize unsigned32=whole(b"u32",ref mut c);let usize size=whole(b"usize",ref mut c);
    assert(c.count==6 && c.nodes[signed32].first==1 && c.nodes[boolean].first==2 && c.nodes[signed64].first==9);
    assert(c.nodes[byte].first==10 && c.nodes[unsigned32].first==11 && c.nodes[size].first==12);
    let usize a=whole(b"i32[1]",ref mut c);let usize b=whole(b"bool[4096]",ref mut c);
    let usize d=whole(b"i64[4096]",ref mut c);let usize e=whole(b"u8[2]",ref mut c);
    let usize f=whole(b"u32[2]",ref mut c);let usize g=whole(b"usize[2]",ref mut c);
    assert(c.nodes[a].kind==2 && a!=signed32 && c.nodes[b].extent==4096 && c.nodes[g].first==12);
    assert(c.nodes[e].first==10 && c.nodes[f].first==11);
    let usize buffer=whole(b"brownie::bytes::Buffer",ref mut c);
    assert(buffer==whole(b"bytes::Buffer",ref mut c) && buffer==whole(b"Buffer",ref mut c));
    assert(buffer==whole(b"brownie /*x*/ :: bytes :: Buffer",ref mut c) && c.nodes[buffer].kind==4);
    let usize wrapped=whole(b"Result<Option<i64[4096]>,Buffer>",ref mut c);
    let usize count=c.count;
    assert(wrapped==whole(b"Result < Option < i64 [ 4096 ] > , bytes::Buffer >",ref mut c));
    assert(c.count==count && whole(b"Result<Buffer,Option<i64[4096]>>",ref mut c)!=wrapped);
    let properties::Plan p=plan(ref c);
    assert(p.properties[d].bytes==32768 && p.properties[b].bytes==4096);
    assert(p.properties[wrapped].bytes==32784 && p.properties[wrapped].wrapper_depth==2);
    assert(!p.properties[wrapped].copyable && p.properties[wrapped].contains_buffer);
    // Scoped kind5 qualification and ordinary tokenization intern identically.
    let ref u8[] source=b"bytes :: Buffer;";
    var lexer::State s=switch(lexer::scoped(source,0,source.len,false)){
        case .ok(v):{v}case .err(_):{assert(false);lexer::empty()}
    };
    assert(lexer::next(source,ref mut s).is_ok && s.kind==5);
    assert(parsed(source,ref mut s,ref mut c)==buffer && s.kind==59);
}
@test fn void nominal_declarations_keep_exact_identity_and_require_registered_layouts(){
    let ref u8[] source=b"module main;struct A{i32 x;}struct B{i32 x;}fn Option<Result<A,B>> main(){}";
    let structs::Table declarations=switch(structs::scan(source)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var lexer::State s=start(source);
    while(!lexer::equal(source[s.begin..s.end],b"Option")){assert(lexer::next(source,ref mut s).is_ok);}
    let lexer::State before=lexer::snapshot(ref s);var properties::Catalog c=properties::empty();
    c.records=declarations.layouts;
    let usize id=switch(parser::parse(source,ref mut s,ref mut c)){
        case .ok(v):{v}case .err(_):{assert(false);0}
    };
    assert(s.kind==2 && lexer::equal(source[s.begin..s.end],b"main"));
    assert(c.records.count==2 && c.count==4 && c.nodes[0].kind==3 && c.nodes[0].first==0);
    assert(c.nodes[1].kind==3 && c.nodes[1].first==1 && c.nodes[2].first==0 && c.nodes[2].second==1);
    let properties::Plan p=plan(ref c);assert(p.properties[id].copyable && p.properties[id].wrapper_depth==2);
    s=before;let properties::Catalog original=c;
    switch(parser::parse(source,ref mut s,ref mut c)){
        case .ok(v):{assert(v==id);}case .err(_):{assert(false);}
    };same_catalog(ref c,ref original);
    s=before;var properties::Catalog missing=properties::empty();
    let properties::Catalog empty=missing;
    assert(!parser::parse(source,ref mut s,ref mut missing).is_ok);
    same_state(ref s,ref before);same_catalog(ref missing,ref empty);
    // A valid but incomplete registered catalog must not admit nominal ID1.
    missing.records.count=1;missing.records.fields[0]=1;missing.records.types[0]=1;
    let properties::Catalog incomplete=missing;s=before;
    assert(!parser::parse(source,ref mut s,ref mut missing).is_ok);
    same_state(ref s,ref before);same_catalog(ref missing,ref incomplete);
}
@test fn void depth_four_and_adjacent_closers_preserve_exact_lexer_positions(){
    var properties::Catalog c=properties::empty();
    let usize id=whole(b"Option<Result<Option<Result<Buffer,u8[4096]>>,i64>>",ref mut c);
    let properties::Plan p=plan(ref c);assert(p.properties[id].wrapper_depth==4 && !p.properties[id].copyable);
    rejected(b"Option<Option<Option<Option<Option<i32>>>>>",4,28,ref mut c);
    rejected(b"Result<i32,Option<Option<Option<Option<i32>>>>>",4,32,ref mut c);
    let ref u8[] source=b"Option<i32>>tail";var lexer::State s=start(source);
    let usize option=parsed(source,ref mut s,ref mut c);
    assert(c.nodes[option].kind==5 && s.kind==62 && s.begin==11 && s.end==12 && s.cursor==12);
    assert(s.tokens==4 && s.value==0 && !s.min_magnitude);
    assert(lexer::next(source,ref mut s).is_ok && s.kind==2 && s.begin==12 && s.end==16);
    let ref u8[] shift=b"i32 >> 1";s=start(shift);let usize scalar=parsed(shift,ref mut s,ref mut c);
    assert(c.nodes[scalar].kind==1 && s.kind==135 && s.begin==4 && s.end==6);
    rejected(b"Option<i32>=",2,10,ref mut c);
}
@test fn void failures_preserve_full_lexer_catalog_and_original_diagnostic_offsets(){
    var properties::Catalog c=properties::empty();let usize seed=whole(b"bool",ref mut c);
    rejected(b"Result<Buffer,Nope>",3,14,ref mut c);
    rejected(b"Option<i32",2,10,ref mut c);
    rejected(b"Result<i32 bool>",2,11,ref mut c);
    rejected(b"Option<Option<i32>> @",1,20,ref mut c);
    rejected(b"Option<Buffer> /*",1,15,ref mut c);
    rejected(b"i32[0]",3,4,ref mut c);rejected(b"u8[4097]",3,3,ref mut c);
    rejected(b"usize[18446744073709551615]",3,6,ref mut c);
    rejected(b"i32[2][3]",3,6,ref mut c);rejected(b"Buffer[2]",3,6,ref mut c);
    rejected(b"Option<i32>[2]",3,11,ref mut c);rejected(b"ref i32",3,0,ref mut c);
    rejected(b"text",3,0,ref mut c);rejected(b"void",3,0,ref mut c);
    rejected(b"i32[-1]",3,4,ref mut c);rejected(b"i32[]",3,4,ref mut c);
    rejected(b"i32[1+1]",2,5,ref mut c);rejected(b"Option<i32>>=",2,10,ref mut c);
    rejected(b"other::Buffer",3,0,ref mut c);
    // Scoped failures retain absolute offsets/context, including a lexer limit
    // after a complete type, instead of publishing the last successful token.
    let ref u8[] scoped=b"xxx Option<Buffer> @";
    var lexer::State s=switch(lexer::scoped(scoped,4,scoped.len,false)){
        case .ok(v):{v}case .err(_):{assert(false);lexer::empty()}
    };
    assert(lexer::next(scoped,ref mut s).is_ok);
    let lexer::State before=lexer::snapshot(ref s);let properties::Catalog original=c;
    switch(parser::parse(scoped,ref mut s,ref mut c)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==1 && e.offset==19);}
    };same_state(ref s,ref before);same_catalog(ref c,ref original);
    let ref u8[] limited=b"Buffer;";s=start(limited);s.tokens=1024;
    let lexer::State limit=lexer::snapshot(ref s);
    switch(parser::parse(limited,ref mut s,ref mut c)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==4 && e.offset==6);}
    };same_state(ref s,ref limit);same_catalog(ref c,ref original);
    // Fill with distinct canonical array nodes; an existing node still resolves
    // at capacity, while a late child failure rolls back an earlier insertion.
    c=properties::empty();c.count=63;var usize i=0;
    while(i<63){c.nodes[i]=properties::Node{.kind=2,.first=10,.second=0,.extent=i+1};i+=1;}
    rejected(b"Result<Buffer,i32>",4,14,ref mut c);
    let usize buffer=whole(b"Buffer",ref mut c);assert(buffer==63 && c.count==64);
    assert(whole(b"u8[1]",ref mut c)==0 && whole(b"Buffer",ref mut c)==63 && c.count==64);
    rejected(b"i64",4,0,ref mut c);
    c.count=65;rejected(b"i32",5,0,ref mut c);
}
