module tests::m2::literal_source;

import literal_source as literals;
import lexer as lexer;
import static_image as images;
import std::bytes as bytes;
import errors as errors;

fn void rejected_scan(Result<usize,errors::Error> actual,u8 kind,usize offset) {
    assert(switch(actual) {
        case .ok(_): { false }
        case .err(error): { error.kind==kind && error.offset==offset }
    });
}

fn void rejected_decode(Result<literals::Decoded,errors::Error> actual,u8 kind,usize offset) {
    assert(switch(actual) {
        case .ok(_): { false }
        case .err(error): { error.kind==kind && error.offset==offset }
    });
}

fn usize scanned(ref u8[] source,usize begin) {
    return switch(literals::scan(source,begin)) {
        case .ok(value): { value }
        case .err(_): { assert(false); 0 }
    };
}

fn literals::Decoded decoded(ref u8[] source,usize begin) {
    return switch(literals::decode(source,begin)) {
        case .ok(value): { value }
        case .err(_): {
            assert(false);
            literals::Decoded { .data=[0;4096],.begin=0,.end=0,.length=0,.text=false }
        }
    };
}

fn bool matches(ref literals::Decoded value,bool text,ref u8[] expected) {
    let ref u8[] data=ref value.data;
    return value.text==text && value.end>=value.begin && value.length<=data.len &&
        value.length==expected.len && bytes::equal(data[..value.length],expected);
}

fn usize advanced(ref u8[] source,ref mut lexer::State state) {
    return switch(lexer::next(source,state)) {
        case .ok(value): { value }
        case .err(_): { assert(false); 0 }
    };
}

fn void lexical_error(ref u8[] source,ref mut lexer::State state,u8 kind,usize offset) {
    assert(switch(lexer::next(source,state)) {
        case .ok(_): { false }
        case .err(error): { error.kind==kind && error.offset==offset }
    });
}

fn images::Builder scratch(usize limit) {
    return switch(images::builder(limit)) {
        case .ok(value): { value }
        case .err(_): {
            assert(false);
            images::Builder {
                .data=[0;4096],
                .catalog=images::Catalog {
                    .starts=[0;16],.ends=[0;16],.text=[false;16],.count=0,.used=0
                },
                .limit=0
            }
        }
    };
}

fn usize intern(ref mut images::Builder builder,ref u8[] source,usize at,usize end) {
    return switch(literals::intern(builder,source,at)){
        case .ok(value):{assert(value.begin==at && value.end==end);value.literal}
        case .err(_):{assert(false);16}
    };
}

fn bool same(ref images::Builder a,ref images::Builder b) {
    if(a.limit!=b.limit || a.catalog.count!=b.catalog.count || a.catalog.used!=b.catalog.used) {
        return false;
    }
    var usize i=0;
    while(i<16) {
        if(a.catalog.starts[i]!=b.catalog.starts[i] || a.catalog.ends[i]!=b.catalog.ends[i] ||
            a.catalog.text[i]!=b.catalog.text[i]) { return false; }
        i+=1;
    }
    let ref u8[] left=ref a.data;
    let ref u8[] right=ref b.data;
    return bytes::equal(left,right);
}

fn bool content(ref images::Image image,usize id,ref u8[] expected) {
    return switch(images::whole(image,id)) {
        case .ok(span): { switch(images::view(image,span)) {
            case .ok(value): { bytes::equal(value,expected) }
            case .err(_): { false }
        } }
        case .err(_): { false }
    };
}

fn bool text_literal(ref images::Image image,usize id) {
    return switch(images::whole(image,id)) {
        case .ok(span): { images::text(image,span).is_ok }
        case .err(_): { false }
    };
}

@test fn void longest_match_raw_spans_lexer_snapshots_and_adjacent_literals_stay_exact() {
    let ref u8[] source=b"\"a\\n\"b\"b\"\"c\"\"\"";
    assert(source.len==14);
    assert(literals::kind(source,0)==4 && literals::kind(source,5)==3);
    assert(literals::kind(source,9)==4 && literals::kind(source,12)==4);
    // kind tests a spelling prefix at a caller-supplied position; it does not
    // reconstruct whether that position was inside an earlier token.
    assert(literals::kind(source,7)==3 && literals::kind(source,10)==0);
    assert(scanned(source,0)==5 && scanned(source,5)==9);
    assert(scanned(source,9)==12 && scanned(source,12)==14);

    let literals::Decoded first=decoded(source,0);
    assert(first.begin==0 && first.end==5 && first.length==2);
    assert(matches(ref first,true,b"a\n"));

    var lexer::State state=lexer::empty();
    assert(advanced(source,ref mut state)==0);
    assert(state.kind==4 && state.begin==0 && state.end==5 && state.tokens==1);
    assert(state.cursor==5 && state.value==0 && !state.min_magnitude);
    let lexer::State saved=lexer::snapshot(ref state);

    assert(advanced(source,ref mut state)==0);
    assert(state.kind==3 && state.begin==5 && state.end==9 && state.tokens==2);
    assert(advanced(source,ref mut state)==0);
    assert(state.kind==4 && state.begin==9 && state.end==12 && state.tokens==3);
    assert(advanced(source,ref mut state)==0);
    assert(state.kind==4 && state.begin==12 && state.end==14 && state.tokens==4);
    assert(saved.cursor==5 && saved.begin==0 && saved.end==5 && saved.tokens==1);
    assert(saved.kind==4 && saved.value==0 && !saved.min_magnitude);

    assert(advanced(source,ref mut state)==0);
    assert(state.kind==0 && state.begin==14 && state.end==14 && state.tokens==5);

    let ref u8[] escaped_quote=b"\"\\\"\"";
    assert(escaped_quote.len==4 && scanned(escaped_quote,0)==4);
    let literals::Decoded quote=decoded(escaped_quote,0);
    assert(matches(ref quote,true,b"\""));
}

@test fn void byte_escapes_allow_nul_and_invalid_utf8_while_unicode_stays_text_only() {
    let u8[27] source=[98,34,92,48,92,110,92,114,92,116,92,92,92,34,92,120,52,49,
        92,120,102,102,92,120,48,48,34];
    let u8[9] expected=[0,10,13,9,92,34,65,255,0];
    let literals::Decoded value=decoded(ref source,0);
    assert(matches(ref value,false,ref expected));
    assert(scanned(ref source,0)==27);

    var lexer::State state=lexer::empty();
    assert(advanced(ref source,ref mut state)==0);
    assert(state.kind==3 && state.begin==0 && state.end==27);

    let ref u8[] unicode=b"b\"\\u{41}\"";
    rejected_decode(literals::decode(unicode,0),1,2);
    var rejected=lexer::empty();
    lexical_error(unicode,ref mut rejected,1,2);
}

@test fn void raw_and_escaped_unicode_copy_complete_scalars_and_zero_the_output_tail() {
    let ref u8[] raw_text=b"\"가😀\"";
    let u8[7] raw_expected=[234,176,128,240,159,152,128];
    let literals::Decoded raw=decoded(raw_text,0);
    assert(matches(ref raw,true,ref raw_expected));

    let ref u8[] escaped=b"\"\\u{0}\\u{7f}\\u{80}\\u{7ff}\\u{800}\\u{d7ff}\\u{e000}\\u{ffff}\\u{10000}\\u{10ffff}\\u{000041}\"";
    let u8[27] expected=[0,127,194,128,223,191,224,160,128,237,159,191,238,128,
        128,239,191,191,240,144,128,128,244,143,191,191,65];
    let literals::Decoded value=decoded(escaped,0);
    assert(value.begin==0 && value.end==escaped.len && value.length==27);
    assert(matches(ref value,true,ref expected));
    let ref u8[] data=ref value.data;
    var usize i=value.length;
    while(i<4096) { assert(data[i]==0); i+=1; }
}

@test fn void malformed_escapes_surrogates_oversized_scalars_and_unterminated_forms_fail_at_defined_offsets() {
    let ref u8[] bad_escape=b"\"a\\q\"";
    rejected_decode(literals::decode(bad_escape,0),1,2);

    let ref u8[] truncated_hex=b"\"a\\x4\"";
    rejected_decode(literals::decode(truncated_hex,0),1,2);

    let ref u8[] bad_hex=b"\"a\\xz1\"";
    rejected_decode(literals::decode(bad_hex,0),1,2);

    let ref u8[] empty_unicode=b"\"\\u{}\"";
    rejected_decode(literals::decode(empty_unicode,0),1,1);

    let ref u8[] seven_digits=b"\"\\u{1234567}\"";
    rejected_decode(literals::decode(seven_digits,0),1,1);

    let ref u8[] low_surrogate=b"\"\\u{D800}\"";
    rejected_decode(literals::decode(low_surrogate,0),1,1);

    let ref u8[] high_surrogate=b"\"\\u{DFFF}\"";
    rejected_decode(literals::decode(high_surrogate,0),1,1);

    let ref u8[] outside=b"\"\\u{110000}\"";
    rejected_decode(literals::decode(outside,0),1,1);

    let ref u8[] nonhex=b"\"\\u{FFFFFZ}\"";
    rejected_decode(literals::decode(nonhex,0),1,1);

    let ref u8[] unterminated=b"\"abc";
    rejected_decode(literals::decode(unterminated,0),1,0);

    let ref u8[] unterminated_byte=b"b\"abc";
    rejected_decode(literals::decode(unterminated_byte,0),1,0);
}

@test fn void cooked_text_accepts_complete_utf8_and_rejects_every_invalid_byte_shape() {
    let ref u8[] valid=b"\"A\\xc2\\x80\\xe0\\xa0\\x80\\xf0\\x90\\x80\\x80Z\"";
    let u8[11] expected=[65,194,128,224,160,128,240,144,128,128,90];
    let literals::Decoded value=decoded(valid,0);
    assert(matches(ref value,true,ref expected));

    let ref u8[] overlong_two=b"\"\\xc0\\x80\"";
    let ref u8[] overlong_three=b"\"\\xe0\\x80\\x80\"";
    let ref u8[] overlong_four=b"\"\\xf0\\x80\\x80\\x80\"";
    let ref u8[] truncated_two=b"\"\\xc2\"";
    let ref u8[] truncated_three=b"\"\\xe1\\x80\"";
    let ref u8[] truncated_four=b"\"\\xf0\\x90\\x80\"";
    let ref u8[] surrogate=b"\"\\xed\\xa0\\x80\"";
    let ref u8[] beyond=b"\"\\xf4\\x90\\x80\\x80\"";
    let ref u8[] lone=b"\"\\x80\"";
    let ref u8[] continuation=b"\"\\xc2\\x20\"";
    let ref u8[] overlong_scalar=b"\"\\xe0\\x9f\\xbf\"";
    let ref u8[] offset=b"x=\"\\xc0\\x80\"";

    rejected_decode(literals::decode(overlong_two,0),1,0);
    rejected_decode(literals::decode(overlong_three,0),1,0);
    rejected_decode(literals::decode(overlong_four,0),1,0);
    rejected_decode(literals::decode(truncated_two,0),1,0);
    rejected_decode(literals::decode(truncated_three,0),1,0);
    rejected_decode(literals::decode(truncated_four,0),1,0);
    rejected_decode(literals::decode(surrogate,0),1,0);
    rejected_decode(literals::decode(beyond,0),1,0);
    rejected_decode(literals::decode(lone,0),1,0);
    rejected_decode(literals::decode(continuation,0),1,0);
    rejected_decode(literals::decode(overlong_scalar,0),1,0);
    rejected_decode(literals::decode(offset,2),1,2);
}

@test fn void raw_invalid_utf8_nul_cr_lf_and_bom_fail_inside_both_literal_kinds() {
    let ref u8[] invalid_text=b"\"a\xffb\"";
    let ref u8[] truncated_text=b"\"a\xc2\"";
    let ref u8[] invalid_byte=b"b\"\xff\"";
    let ref u8[] nul=b"\"a\x00b\"";
    let ref u8[] cr=b"\"a\rb\"";
    let ref u8[] lf=b"\"a\nb\"";
    let ref u8[] bom=b"\"a\xef\xbb\xbfb\"";
    let ref u8[] escaped_bom=b"\"\\u{feff}\"";
    let ref u8[] byte_lf=b"b\"a\n\"";

    rejected_decode(literals::decode(invalid_text,0),1,0);
    rejected_decode(literals::decode(truncated_text,0),1,0);
    rejected_decode(literals::decode(invalid_byte,0),1,0);
    rejected_decode(literals::decode(nul,0),1,2);
    rejected_decode(literals::decode(cr,0),1,2);
    rejected_decode(literals::decode(lf,0),1,2);
    rejected_decode(literals::decode(bom,0),1,2);
    rejected_decode(literals::decode(byte_lf,0),1,3);
    let u8[3] feff=[239,187,191];
    let literals::Decoded escaped_value=decoded(escaped_bom,0);
    assert(matches(ref escaped_value,true,ref feff));

    var text_state=lexer::empty();
    var byte_state=lexer::empty();
    lexical_error(lf,ref mut text_state,1,2);
    lexical_error(byte_lf,ref mut byte_state,1,3);

    assert(literals::kind(b"c\"x\"",0)==0);
    assert(literals::kind(b"r\"x\"",0)==0);
    assert(literals::kind(b"br\"x\"",0)==0);
    assert(literals::kind(b"B\"x\"",0)==0);
    assert(literals::kind(b"'x'",0)==0);
    var c_state=lexer::empty();
    var char_state=lexer::empty();
    lexical_error(b"c\"x\"",ref mut c_state,1,0);
    lexical_error(b"'x'",ref mut char_state,1,0);
}

@test fn void offsets_nonliterals_exact_source_end_and_token_limit_keep_bounds_distinct() {
    let ref u8[] offset=b"x=\"ok\"";
    assert(literals::kind(offset,0)==0 && literals::kind(offset,1)==0);
    assert(literals::kind(offset,2)==4 && scanned(offset,2)==6);
    let literals::Decoded selected=decoded(offset,2);
    assert(matches(ref selected,true,b"ok"));
    rejected_scan(literals::scan(offset,0),1,0);
    rejected_decode(literals::decode(offset,1),1,1);

    let ref u8[] empty=b"";
    assert(literals::kind(empty,0)==0 && literals::kind(empty,100)==0);
    rejected_scan(literals::scan(empty,0),1,0);
    rejected_decode(literals::decode(empty,0),1,0);

    let ref u8[] end=b"\"x\"";
    assert(literals::kind(end,2)==4 && literals::kind(end,3)==0);
    rejected_scan(literals::scan(end,2),1,2);
    rejected_decode(literals::decode(end,3),1,3);

    var u8[4096] maximum=[65;4096];
    maximum[0]=34;
    maximum[4095]=34;
    assert(scanned(ref maximum,0)==4096);
    let literals::Decoded largest=decoded(ref maximum,0);
    let ref u8[] largest_data=ref largest.data;
    let ref u8[] largest_source=ref maximum[1..4095];
    assert(largest.text && largest.begin==0 && largest.end==4096 && largest.length==4094);
    assert(bytes::equal(largest_data[..largest.length],largest_source));

    var bytes::Buffer oversized=switch(bytes::with_capacity(4097)) {
        case .ok(value): { value }
        case .err(_): { assert(false); bytes::empty() }
    };
    assert(bytes::resize_zeroed(ref mut oversized,4097).is_ok);
    // Reach the literal scanner rather than the ordinary raw-NUL rejection.
    {let ref mut u8[] data=bytes::view_mut(ref mut oversized);data[0]=34;}
    let ref u8[] oversized_source=bytes::view(ref oversized);
    rejected_scan(literals::scan(oversized_source,0),4,4096);
    rejected_decode(literals::decode(oversized_source,0),4,4096);
    var oversized_state=lexer::empty();
    lexical_error(oversized_source,ref mut oversized_state,4,4096);

    var u8[2048] adjacent=[34;2048];
    var lexer::State state=lexer::empty();
    var usize count=0;
    while(count<1024) {
        assert(advanced(ref adjacent,ref mut state)==0);
        assert(state.kind==4 && state.begin==count*2 && state.end==count*2+2);
        count+=1;
    }
    lexical_error(ref adjacent,ref mut state,4,2048);
}

@test fn void decoded_values_freeze_into_exact_deduplicated_image_and_failed_decode_rolls_back() {
    let ref u8[] source=b"b\"A\\n\"\"가\"b\"A\\n\"\"A\\n\"";
    assert(source.len==22);
    assert(literals::kind(source,0)==3 && literals::kind(source,6)==4);
    assert(literals::kind(source,11)==3 && literals::kind(source,17)==4);

    let literals::Decoded byte=decoded(source,0);
    let literals::Decoded korean=decoded(source,6);
    let literals::Decoded duplicate_byte=decoded(source,11);
    let literals::Decoded duplicate_kind=decoded(source,17);
    let u8[2] newline=[65,10];
    assert(matches(ref byte,false,ref newline));
    assert(matches(ref duplicate_byte,false,ref newline));
    assert(matches(ref duplicate_kind,true,ref newline));

    var images::Builder builder=scratch(8);
    assert(intern(ref mut builder,source,0,6)==0 && builder.catalog.used==2);
    assert(intern(ref mut builder,source,6,11)==1 && builder.catalog.used==5);
    assert(intern(ref mut builder,source,11,17)==0 && builder.catalog.used==5);

    let images::Builder before=builder;
    let ref u8[] invalid=b"\"\\xc0\\x80\"";
    switch(literals::intern(ref mut builder,invalid,0)){
        case .ok(_):{assert(false);}
        case .err(error):{switch(error.kind){
            case .Source:{assert(error.source.kind==1 && error.source.offset==0);}
            case .Image:{assert(false);}
        }}
    };
    assert(same(ref builder,ref before));

    assert(intern(ref mut builder,source,17,22)==2 && builder.catalog.used==7);
    assert(builder.catalog.count==3);
    let images::Builder full=builder;
    switch(literals::intern(ref mut builder,b"b\"XY\"",0)){
        case .ok(_):{assert(false);}
        case .err(error):{switch(error.kind){
            case .Source:{assert(false);}
            case .Image:{assert(quota(error.image));}
        }}
    };
    assert(same(ref builder,ref full));
    let images::Image image=switch(images::freeze(ref builder,images::metadata_charge()+7)) {
        case .ok(value): { value }
        case .err(_): { assert(false); return; }
    };
    assert(images::inspect(ref image).is_ok);
    assert(images::payload_bytes(ref image)==7 && images::payload_capacity(ref image)==7);
    assert(content(ref image,0,ref newline));
    assert(content(ref image,1,b"가") && content(ref image,2,ref newline));
    assert(switch(images::kind(ref image,0)) {case .ok(value):{value==1}case .err(_):{false}});
    assert(switch(images::kind(ref image,1)) {case .ok(value):{value==2}case .err(_):{false}});
    assert(switch(images::kind(ref image,2)) {case .ok(value):{value==2}case .err(_):{false}});
    assert(text_literal(ref image,1));
}

fn bool quota(images::Error e){return switch(e){
    case .Quota:{true}case .State:{false}case .Limit:{false}case .Literals:{false}
    case .Utf8:{false}case .Kind:{false}case .Bounds:{false}case .Allocation:{false}case .Provider:{false}
};}
