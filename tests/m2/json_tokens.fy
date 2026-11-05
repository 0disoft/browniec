module tests::m2::json_tokens;
import json_tokens as json;
import std::bytes as bytes;
fn json::State first(ref u8[] source){
    return switch(json::start(source)){case .ok(s):{s}case .err(_):{assert(false);json::empty()}};
}
fn bool rejected(ref u8[] source){return switch(json::start(source)){case .err(_):{true}case .ok(_):{false}};}
fn void advance(ref u8[] source,ref mut json::State s){
    assert(switch(json::next(source,s)){case .ok(_):{true}case .err(_):{false}});
}
@test fn void unicode_surrogates_and_simple_escapes_decode_exactly(){
    let ref u8[] source=b"\"a\\u0062\\u00e9\\uD83D\\uDE00\\n\\t\\b\\f\\r\\/\\\\\\\"\"";
    let json::State s=first(source);var u8[32] out=[0;32];
    let usize size=switch(json::decode(source,s,ref mut out)){case .ok(n):{n}case .err(_):{assert(false);0}};
    let ref u8[] view=ref out;
    assert(bytes::equal(view[..size],b"ab\xc3\xa9\xf0\x9f\x98\x80\n\t\x08\x0c\r/\\\""));
    assert(rejected(b"\"\\uD800\"") && rejected(b"\"\\uDC00\""));
    assert(rejected(b"\"\\uD800\\u0041\"") && rejected(b"\"\\uZZZZ\""));
    assert(rejected(b"\"\\x41\"") && rejected(b"\"a\nb\""));
}
@test fn void number_grammar_rejects_prefixes_and_accepts_json_numbers(){
    assert(first(b"-12.5e+2").kind==2 && first(b"0").kind==2 && first(b"-0").kind==2);
    assert(rejected(b"01") && rejected(b"-01") && rejected(b"+1") && rejected(b"1."));
    assert(rejected(b"1e") && rejected(b"1e+") && rejected(b"-") && rejected(b"1x"));
    assert(rejected(b"NaN") && rejected(b"Infinity") && rejected(b"truex"));
}
@test fn void tokens_are_bounded_and_state_publication_is_transactional(){
    let ref u8[] source=b" \r\n{\"x\":[true,false,null,2]} ";
    var json::State s=first(source);assert(s.kind==123 && s.begin==3);
    advance(source,ref mut s);assert(s.kind==34);
    advance(source,ref mut s);assert(s.kind==58);
    advance(source,ref mut s);assert(s.kind==91);
    advance(source,ref mut s);assert(s.kind==3);
    let json::State saved=s;
    assert(switch(json::next(b"",ref mut s)){case .err(e):{e.kind==4}case .ok(_):{false}});
    assert(s.begin==saved.begin && s.end==saved.end && s.cursor==saved.cursor && s.kind==saved.kind);
}
@test fn void invalid_utf8_raw_controls_bom_and_small_output_fail(){
    assert(rejected(b"\xff") && rejected(b"\xef\xbb\xbf{}") && rejected(b"\"a\x00b\""));
    let ref u8[] source=b"\"abcd\"";let json::State s=first(source);var u8[3] out=[0;3];
    assert(switch(json::decode(source,s,ref mut out)){case .err(e):{e.kind==2}case .ok(_):{false}});
    let json::State forged=json::State{.kind=34,.begin=0,.end=65537,.cursor=0};
    assert(switch(json::decode(source,forged,ref mut out)){case .err(e):{e.kind==4}case .ok(_):{false}});
}
@test fn void input_byte_limit_is_inclusive_and_escaped_nul_is_json_data(){
    var bytes::Buffer source=switch(bytes::with_capacity(65537)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(bytes::resize_zeroed(ref mut source,65537).is_ok);
    let ref mut u8[] data=bytes::view_mut(ref mut source);var usize i=0;
    while(i<data.len){data[i]=32;i+=1;}
    assert(json::start(data[..65536]).is_ok);
    assert(switch(json::start(data)){case .err(e):{e.kind==2 && e.offset==65536}case .ok(_):{false}});
    let ref u8[] escaped=b"\"\\u0000\"";let json::State s=first(escaped);
    var u8[1] out=[99;1];
    assert(switch(json::decode(escaped,s,ref mut out)){case .ok(n):{n==1}case .err(_):{false}});
    assert(out[0]==0);
}
