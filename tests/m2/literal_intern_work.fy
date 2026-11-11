module tests::m2::literal_intern_work;
import literal_intern_work as work;
import static_image as images;
import metadata_budget as budget;
import std::bytes as bytes;
fn u8 tag(images::Error e){return switch(e){case .State:{0}case .Limit:{1}case .Quota:{2}case .Literals:{3}
    case .Utf8:{4}case .Kind:{5}case .Bounds:{6}case .Allocation:{7}case .Provider:{8}};}
fn images::Builder fresh(usize limit){return switch(images::builder(limit)){case .ok(v):{v}case .err(_):{assert(false);fresh(0)}};}
fn void same_builder(ref images::Builder a,ref images::Builder b){
    assert(a.limit==b.limit && a.catalog.count==b.catalog.count && a.catalog.used==b.catalog.used);
    var usize i=0;while(i<16){assert(a.catalog.starts[i]==b.catalog.starts[i] && a.catalog.ends[i]==b.catalog.ends[i] && a.catalog.text[i]==b.catalog.text[i]);i+=1;}
    i=0;while(i<4096){assert(a.data[i]==b.data[i]);i+=1;}
}
fn Result<usize,images::Error> run(ref mut images::Builder candidate,ref u8[] payload,bool text){
    var work::State w=work::begin(text);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<2000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize row=w.row;let usize cursor=w.cursor;let usize visits=w.visits;
        let usize count=candidate.catalog.count;let usize used=candidate.catalog.used;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        let bool deferred=work::advance(candidate,payload,ref mut w,ref mut meter)?;
        assert(!deferred && meter.total==total && w.phase==phase && w.row==row && w.cursor==cursor && w.visits==visits &&
            candidate.catalog.count==count && candidate.catalog.used==used);
        assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(candidate,payload,ref mut w,ref mut meter)?;
        assert(done==w.done && meter.last==4096 && w.visits-visits<=64);
        if(!done){assert(!work::prepared(ref w).is_ok && candidate.catalog.count==count && candidate.catalog.used==used);}
        turns+=1;
    }
    let usize total=meter.total;assert(work::advance(candidate,payload,ref mut w,ref mut meter).is_ok && meter.total==total);
    return work::prepared(ref w);
}
fn void same(ref images::Builder original,ref u8[] payload,bool text){
    var images::Builder expected=*original;var images::Builder actual=*original;
    let Result<usize,images::Error> raw=if(text){images::intern_text(ref mut expected,payload)}else{images::intern_bytes(ref mut expected,payload)};
    switch(raw){case .ok(a):{switch(run(ref mut actual,payload,text)){case .ok(b):{assert(a==b);}case .err(_):{assert(false);}};}
        case .err(a):{switch(run(ref mut actual,payload,text)){case .ok(_):{assert(false);}case .err(b):{assert(tag(a)==tag(b));}};same_builder(original,ref actual);}};
    same_builder(ref expected,ref actual);
}
@test fn void payload_copy_long_dedup_and_kind_distinction_match(){
    var images::Builder b=fresh(4096);same(ref b,b"",false);same(ref b,b"",true);same(ref b,b"hi",true);
    var u8[2048] payload=[65;2048];same(ref b,ref payload,false);assert(images::intern_bytes(ref mut b,ref payload).is_ok);
    same(ref b,ref payload,false);same(ref b,ref payload,true);payload[2047]=66;same(ref b,ref payload,false);
    b=fresh(4096);var u8[4096] full=[65;4096];same(ref b,ref full,true);
    full[255]=240;full[256]=144;full[257]=128;full[258]=128;same(ref b,ref full,true);
}
@test fn void shape_limit_quota_utf8_precedence_and_rollback_match(){
    var images::Builder b=fresh(0);same(ref b,b"",true);same(ref b,b"x",false);same(ref b,b"\xff",true);
    b=fresh(1);same(ref b,b"\xff",true);same(ref b,b"\xc2\xa2",true);
    assert(images::intern_bytes(ref mut b,b"x").is_ok);same(ref b,b"x",false);same(ref b,b"y",false);
    same(ref b,b"\xff",true);b.catalog.ends[0]=0;same(ref b,b"\xff",true);
    b=fresh(4096);b.limit=4097;same(ref b,b"",false);b=fresh(4096);b.catalog.count=17;same(ref b,b"",true);
    b=fresh(4096);b.catalog.used=1;same(ref b,b"",false);b=fresh(4096);b.catalog.starts[15]=1;same(ref b,b"",true);
    b=fresh(4096);b.catalog.text[15]=true;same(ref b,b"",false);
    var bytes::Buffer over=bytes::empty();assert(bytes::resize_zeroed(ref mut over,4097).is_ok);
    b=fresh(0);same(ref b,bytes::view(ref over),true);
}
@test fn void full_catalog_duplicates_precede_capacity_errors(){
    var images::Builder b=fresh(4096);var u8[1] payload=[65;1];var usize i=0;
    while(i<16){assert(images::intern_bytes(ref mut b,ref payload).is_ok);payload[0]+=1;i+=1;}
    same(ref b,b"A",false);same(ref b,b"Q",false);same(ref b,b"A",true);same(ref b,b"\xff",true);
    b.limit=16;same(ref b,b"Q",false);same(ref b,b"longer than the limit",false);
}
