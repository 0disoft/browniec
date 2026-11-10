module tests::m2::output_image_work;
import output_image_work as work;
import static_image as images;
import metadata_budget as budget;

fn u8 code(images::Error e){return switch(e){case .State:{1}case .Limit:{2}case .Quota:{3}case .Literals:{4}
    case .Utf8:{5}case .Kind:{6}case .Bounds:{7}case .Allocation:{8}case .Provider:{9}};}
fn Result<usize,images::Error> staged(ref images::Catalog catalog,ref u8[] data){
    var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<50);assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance_catalog(catalog,data,data.len,ref mut w,ref mut meter)?;assert(done==w.done && meter.last==4096);turns+=1;
    }
    let usize total=meter.total;assert(work::advance_catalog(catalog,data,data.len,ref mut w,ref mut meter).is_ok);assert(total==meter.total);
    return .ok(w.count);
}
fn void same(ref images::Catalog catalog,ref u8[] data){
    switch(images::inspect_catalog(catalog,data,data.len)){
        case .ok(n):{switch(staged(catalog,data)){case .ok(m):{assert(n==m);}case .err(_):{assert(false);}};}
        case .err(e):{switch(staged(catalog,data)){case .ok(_):{assert(false);}case .err(a):{assert(code(e)==code(a));}};}
    };
}
fn images::Catalog catalog(usize length,bool text){
    return images::Catalog{.starts=[0;16],.ends=[length,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],.text=[text,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false],.count=1,.used=length};
}
fn void sample(ref u8[] data,bool text){let images::Catalog c=catalog(data.len,text);same(ref c,data);}
@test fn void long_text_and_unicode_crossing_chunk_boundaries_match_raw(){
    var u8[4096] data=[65;4096];sample(ref data,true);
    // Four-byte scalar straddles the first cut; three-byte scalar the next.
    data[255]=240;data[256]=144;data[257]=128;data[258]=128;
    data[514]=224;data[515]=160;data[516]=128;
    sample(ref data,true);
    sample(b"",true);
    sample(b"\xff\xff",false);
}
@test fn void owning_immutable_image_uses_the_same_staged_catalog_and_bytes(){
    var images::Builder b=switch(images::builder(4096)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(images::intern_text(ref mut b,b"immutable image").is_ok);
    let images::Image image=switch(images::freeze(ref b,8192)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(images::inspect(ref image).is_ok);
    var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(budget::reset(ref mut meter,0).is_ok);
        assert(work::advance(ref image,ref mut w,ref mut meter).is_ok);turns+=1;assert(turns<5);
    }assert(w.count==1);
}
@test fn void forged_utf8_and_catalog_error_precedence_match_raw(){
    var u8[4096] data=[65;4096];data[4095]=128;sample(ref data,true);
    data=[65;4096];data[255]=240;data[256]=128;data[257]=128;data[258]=128;
    sample(ref data,true);
    data=[65;4096];data[255]=237;data[256]=160;data[257]=128;sample(ref data,true);
    data=[65;4096];data[255]=244;data[256]=144;data[257]=128;data[258]=128;
    sample(ref data,true);
    sample(b"\xf0\x90\x80",true);
    var images::Catalog malformed=catalog(1,true);malformed.text[15]=true;same(ref malformed,b"\xff");
    malformed.text[15]=false;malformed.ends[0]=2;same(ref malformed,b"\xff");
}
@test fn void partial_room_preserves_text_cursor_and_meter_at_every_yield(){
    let u8[4096] data=[65;4096];let images::Catalog literal=catalog(4096,true);
    var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(budget::reset(ref mut meter,0).is_ok);assert(budget::admit(ref mut meter,1,0).is_ok);
        let work::State saved=w;let budget::State before=meter;
        switch(work::advance_catalog(ref literal,ref data,4096,ref mut w,ref mut meter)){case .ok(v):{assert(!v);}case .err(_):{assert(false);}};
        assert(w.phase==saved.phase && w.literal==saved.literal && w.cursor==saved.cursor && w.count==saved.count && w.done==saved.done);
        assert(meter.total==before.total && meter.last==before.last && meter.stages==before.stages);
        assert(budget::reset(ref mut meter,0).is_ok);assert(work::advance_catalog(ref literal,ref data,4096,ref mut w,ref mut meter).is_ok);
        turns+=1;assert(turns<25);
    }assert(turns==18);
}
