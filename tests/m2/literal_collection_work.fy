module tests::m2::literal_collection_work;
import literal_collection_work as work;
import literal_collection as raw;
import literal_source as literals;
import static_image as images;
import source_context as context;
import metadata_budget as budget;
import std::bytes as bytes;
fn images::Builder fresh(usize limit){return switch(images::builder(limit)){case .ok(v):{v}case .err(_):{assert(false);fresh(0)}};}
fn u8 image_tag(images::Error e){return switch(e){case .State:{0}case .Limit:{1}case .Quota:{2}case .Literals:{3}
    case .Utf8:{4}case .Kind:{5}case .Bounds:{6}case .Allocation:{7}case .Provider:{8}};}
fn u8 failure_tag(literals::Failure e){return switch(e){case .Source:{0}case .Image:{1}};}
fn void same_builder(ref images::Builder a,ref images::Builder b){
    assert(a.limit==b.limit && a.catalog.count==b.catalog.count && a.catalog.used==b.catalog.used);
    var usize i=0;while(i<16){assert(a.catalog.starts[i]==b.catalog.starts[i] && a.catalog.ends[i]==b.catalog.ends[i] && a.catalog.text[i]==b.catalog.text[i]);i+=1;}
    i=0;while(i<4096){assert(a.data[i]==b.data[i]);i+=1;}
}
fn void same_index(ref raw::Index a,ref raw::Index b){assert(a.count==b.count && a.enabled==b.enabled);
    var usize i=0;while(i<16){assert(a.begins[i]==b.begins[i] && a.ends[i]==b.ends[i] && a.literals[i]==b.literals[i] && a.lengths[i]==b.lengths[i] && a.kinds[i]==b.kinds[i]);i+=1;}}
fn void same_result(Result<raw::Index,literals::Error> a,Result<raw::Index,literals::Error> b){
    switch(a){case .ok(x):{switch(b){case .ok(y):{same_index(ref x,ref y);}case .err(_):{assert(false);}};}
        case .err(x):{switch(b){case .ok(_):{assert(false);}case .err(y):{assert(failure_tag(x.kind)==failure_tag(y.kind) &&
            x.source.kind==y.source.kind && x.source.offset==y.source.offset && image_tag(x.image)==image_tag(y.image));}};}};
}
fn Result<raw::Index,literals::Error> run(ref u8[] source,ref context::Table scope,ref images::Builder original,ref mut images::Builder candidate){
    var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<50000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize cursor=w.cursor;let usize clear=w.clear;let usize visits=w.visits;let usize file=w.file;
        let usize count=w.result.count;let usize token=w.token.cursor;let bool waiting=w.waiting;
        let usize checked=w.utf8.cursor;let usize compared=w.intern.visits;let usize decoded=w.decoded.visits;
        let usize bank_count=candidate.catalog.count;let usize bank_used=candidate.catalog.used;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        let bool deferred=work::advance(source,scope,original,candidate,ref mut w,ref mut meter)?;
        assert(!deferred && meter.total==total && w.phase==phase && w.cursor==cursor && w.clear==clear && w.visits==visits &&
            w.file==file && w.result.count==count && w.token.cursor==token && w.waiting==waiting && w.utf8.cursor==checked &&
            w.intern.visits==compared && w.decoded.visits==decoded && candidate.catalog.count==bank_count && candidate.catalog.used==bank_used);
        assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(source,scope,original,candidate,ref mut w,ref mut meter)?;
        assert(done==w.done && meter.last==4096 && w.visits-visits<=64);
        if(phase==11){assert(w.intern.visits-compared<=64);}if(phase==10){assert(w.decoded.visits-decoded<=16);}
        if(!done){assert(!work::prepared(ref w).is_ok && !w.result.enabled);}turns+=1;
    }
    let usize total=meter.total;assert(work::advance(source,scope,original,candidate,ref mut w,ref mut meter).is_ok && meter.total==total);
    return work::prepared(ref w);
}
fn void same(ref u8[] source,ref context::Table scope,ref images::Builder original){
    var images::Builder expected=*original;var images::Builder actual=fresh(0);var images::Builder observed=*original;
    let Result<raw::Index,literals::Error> reference=raw::collect_scoped_raw(ref mut expected,source,scope);
    let Result<raw::Index,literals::Error> staged=run(source,scope,ref observed,ref mut actual);
    same_builder(original,ref observed);same_result(reference,staged);
    if(reference.is_ok){same_builder(ref expected,ref actual);}else{same_builder(original,ref expected);}
    var images::Builder adapter=*original;same_result(reference,raw::collect_scoped(ref mut adapter,source,scope));same_builder(ref expected,ref adapter);
}
@test fn void cooked_dedup_comments_unicode_and_scoped_eof_match(){
    var images::Builder b=fresh(4096);assert(images::intern_bytes(ref mut b,b"seed").is_ok);let context::Table empty=context::empty();
    same(b"b\"A\" b\"\\x41\" \"A\" \"\\u{1f600}\" // b\"ignored\"\n b\"\" \"\"",ref empty,ref b);
    same(b"/* b\"ignored\" */",ref empty,ref b);same(b"",ref empty,ref b);
    let ref u8[] source=b"module a; b\"A\" // first\n\xef\xbb\xbfmodule b; \"\\u{41}\" b\"B\"";
    var context::Table scope=context::empty();scope.modules=2;scope.ends[0]=24;scope.ends[1]=50;
    var images::Builder checked=b;assert(raw::collect_scoped(ref mut checked,source,ref scope).is_ok);
    same(source,ref scope,ref b);scope.ends[0]=25;same(source,ref scope,ref b);
    scope.ends[0]=15;scope.ends[1]=29;
    same(b"module a; b\"openmodule b; b\"B\"",ref scope,ref b);
}
@test fn void whole_source_utf8_context_and_source_image_error_order_match(){
    var images::Builder b=fresh(4);assert(images::intern_bytes(ref mut b,b"seed").is_ok);let context::Table empty=context::empty();
    same(b"b\"x\" \\q",ref empty,ref b);same(b"b\"x\" \xff",ref empty,ref b);
    same(b"b\"\\q\" b\"x\"",ref empty,ref b);same(b"b\"seed\" b\"\\q\"",ref empty,ref b);
    same(b"b\"seed\" b\"x\"",ref empty,ref b);same(b"\"\\xff\"",ref empty,ref b);
    var context::Table scope=context::empty();scope.modules=17;same(b"\xff",ref scope,ref b);
    scope.modules=1;scope.ends[0]=1;same(b"\xff",ref scope,ref b);
    scope.imports=1;scope.aliases[0]=0;same(b"\xff",ref scope,ref b);
    b.catalog.count=17;same(b"/* none */",ref empty,ref b);same(b"b\"x\"",ref empty,ref b);same(b"b\"\\q\"",ref empty,ref b);
}
@test fn void sixteen_occurrences_long_banks_and_profile_limits_match(){
    let context::Table scope=context::empty();var images::Builder b=fresh(4096);var u8[4096] source=[32;4096];
    source[0]=98;source[1]=34;var usize i=2;while(i<4095){source[i]=65;i+=1;}source[4095]=34;same(ref source,ref scope,ref b);
    source=[32;4096];i=0;var usize count=0;
    while(count<17){source[i]=98;source[i+1]=34;source[i+2]=65;source[i+3]=34;i+=5;count+=1;
        if(count==16){same(ref source[..i],ref scope,ref b);}}
    same(ref source[..i],ref scope,ref b);
    var bytes::Buffer over=bytes::empty();assert(bytes::resize_zeroed(ref mut over,4097).is_ok);same(bytes::view(ref over),ref scope,ref b);
    var context::Table scoped=context::empty();scoped.modules=1;scoped.ends[0]=4097;same(bytes::view(ref over),ref scoped,ref b);
}
