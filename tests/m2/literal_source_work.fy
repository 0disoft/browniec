module tests::m2::literal_source_work;
import literal_source_work as work;
import literal_source as raw;
import source_utf8_work as utf8_work;
import std::text as utf8;
import std::bytes as bytes;
import metadata_budget as budget;
import errors as errors;

fn Result<raw::Decoded,errors::Error> staged(ref u8[] source,usize begin){
    var work::State w=work::empty(begin);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<512);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize cursor=w.cursor;let usize checked=w.checked;let usize visits=w.visits;let usize length=w.result.length;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        let bool deferred=work::advance(source,ref mut w,ref mut meter)?;
        assert(!deferred && w.phase==phase && w.cursor==cursor && w.checked==checked && w.visits==visits && w.result.length==length);
        assert(meter.total==total && meter.last==1);assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(source,ref mut w,ref mut meter)?;
        assert(done==w.done && meter.last==4096 && w.visits-visits<=16);turns+=1;
        if(!done){assert(!work::prepared(ref w).is_ok);}
    }
    let usize total=meter.total;assert(work::advance(source,ref mut w,ref mut meter).is_ok && meter.total==total);
    return work::prepared(ref w);
}
fn void same(ref u8[] source,usize begin){
    switch(raw::decode(source,begin)){
        case .ok(a):{switch(staged(source,begin)){
            case .ok(b):{assert(a.begin==b.begin && a.end==b.end && a.length==b.length && a.text==b.text);
                var usize i=0;while(i<4096){assert(a.data[i]==b.data[i]);i+=1;}}
            case .err(_):{assert(false);}};}
        case .err(a):{switch(staged(source,begin)){case .ok(_):{assert(false);}
            case .err(b):{assert(a.kind==b.kind && a.offset==b.offset);}};}
    };
}
@test fn void decoded_bytes_unicode_escapes_and_exact_end_match_raw(){
    same(b"b\"a\\x00\\xff\\\\\\\"\\n\\r\\t\\0\";",0);
    same(b"prefix \"a\\u{1f600}\\u{0}\\u{10ffff}\\xc2\\xa2\" suffix",7);
    same(b"\"\"",0);same(b"b\"\"",0);same(b"\"okay\"\xff",0);
    var u8[4096] source=[65;4096];source[0]=34;source[4095]=34;
    source[255]=240;source[256]=144;source[257]=128;source[258]=128;same(ref source,0);
}
@test fn void literal_error_kind_offset_and_precedence_match_raw(){
    same(b"nothing",0);same(b"b\"open",0);same(b"\"open\\",0);same(b"\"a\n\"",0);
    same(b"b\"\\u{41}\"",0);same(b"\"\\u{}\"",0);same(b"\"\\u{110000}\"",0);
    same(b"\"\\u{d800}\"",0);same(b"\"\\u{0000000}\"",0);same(b"\"\\x0\"",0);
    same(b"\"\\q\"",0);same(b"\"\\xff\"",0);same(b"\"\xff\"",0);
    same(b"xx\"\xff\\q\"",2);same(b"\"\xef\xbb\xbf\"",0);same(b"\"\x00\"",0);
    var bytes::Buffer oversized=bytes::empty();assert(bytes::reserve(ref mut oversized,4097).is_ok);
    assert(bytes::resize_zeroed(ref mut oversized,4097).is_ok);same(bytes::view(ref oversized),0);
}
fn void utf8_same(ref u8[] source){
    var utf8_work::State w=utf8_work::empty();var budget::State meter=budget::empty();var usize turns=0;var bool accepted=true;
    while(!w.done){assert(turns<32);assert(budget::reset(ref mut meter,0).is_ok);
        let usize cursor=w.cursor;assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(utf8_work::advance(source,ref mut w,ref mut meter).is_ok && w.cursor==cursor && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);
        switch(utf8_work::advance(source,ref mut w,ref mut meter)){case .ok(_):{}
            case .err(e):{assert(e.kind==1 && e.offset==0);accepted=false;break;}};
        assert(w.cursor-cursor<=259);turns+=1;
    }
    assert(accepted==utf8::validate_utf8(source).is_ok);
}
@test fn void source_utf8_boundaries_match_whole_validation(){
    var u8[4096] source=[65;4096];utf8_same(ref source);utf8_same(b"");
    source[255]=240;source[256]=144;source[257]=128;source[258]=128;utf8_same(ref source);
    source[256]=128;utf8_same(ref source);source=[65;4096];source[4095]=128;utf8_same(ref source);
    utf8_same(b"\xf0\x90\x80");utf8_same(b"\xed\xa0\x80");utf8_same(b"\xf4\x90\x80\x80");
}
