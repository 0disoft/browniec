module tests::m2::static_image;
import static_image as images;
import std::bytes as bytes;

fn bool number(Result<usize,images::Error> actual,usize expected){return switch(actual){case .ok(value):{value==expected}case .err(_):{false}};}
fn bool answer(Result<bool,images::Error> actual,bool expected){return switch(actual){case .ok(value):{value==expected}case .err(_):{false}};}
fn bool byte(Result<u8,images::Error> actual,u8 expected){return switch(actual){case .ok(value):{value==expected}case .err(_):{false}};}


fn images::Builder scratch(usize limit){return switch(images::builder(limit)){case .ok(value):{value}case .err(_):{assert(false);images::Builder{.data=[0;4096],.catalog=images::Catalog{.starts=[0;16],.ends=[0;16],.text=[false;16],.count=0,.used=0},.limit=0}}};}
fn images::Span whole(ref images::Image image,usize id){return switch(images::whole(image,id)){case .ok(value):{value}case .err(_):{assert(false);images::Span{.literal=16,.start=0,.end=0}}};}
fn images::Span sub(ref images::Image image,images::Span span,usize lo,usize hi){return switch(images::subspan(image,span,lo,hi)){case .ok(value):{value}case .err(_):{assert(false);span}};}
fn bool content(ref images::Image image,images::Span span,ref u8[] expected){return switch(images::view(image,span)){case .ok(value):{bytes::equal(value,expected)}case .err(_):{false}};}
fn bool same(ref images::Builder a,ref images::Builder b){
    if(a.limit!=b.limit || a.catalog.count!=b.catalog.count || a.catalog.used!=b.catalog.used){return false;}
    var usize i=0;while(i<16){if(a.catalog.starts[i]!=b.catalog.starts[i] || a.catalog.ends[i]!=b.catalog.ends[i] || a.catalog.text[i]!=b.catalog.text[i]){return false;}i+=1;}
    let ref u8[] x=ref a.data;let ref u8[] y=ref b.data;return bytes::equal(x,y);
}

@test fn void full_capacity_builder_matches_checked_constructor(){
    let images::Builder full=images::full_builder();
    let images::Builder checked=scratch(images::byte_limit());
    assert(same(ref full,ref checked));
    assert(!images::builder(images::byte_limit()+1).is_ok);
}
fn Result<images::Image,images::Error> from_local_scratch(){
    var images::Builder b=images::builder(4)?;let usize id=images::intern_text(ref mut b,b"kept")?;
    return images::freeze(ref b,images::metadata_charge()+4);
}
@test fn void frozen_images_own_exact_deduplicated_bytes_independent_of_compiler_scratch(){
    let images::Image escaped=switch(from_local_scratch()){case .ok(value):{value}case .err(_):{assert(false);return;}};
    assert(content(ref escaped,whole(ref escaped,0),b"kept"));
    var images::Builder b=scratch(4096);var u8[3] source=[65,0,66];
    let usize id=switch(images::intern_text(ref mut b,ref source)){case .ok(value):{value}case .err(_):{assert(false);16}};
    assert(id==0 && b.catalog.count==1 && b.catalog.used==3);
    assert(images::intern_text(ref mut b,ref source).is_ok && b.catalog.count==1 && b.catalog.used==3);
    source[0]=90;
    let images::Image first=switch(images::freeze(ref b,8192)){case .ok(value):{value}case .err(_):{assert(false);return;}};let images::Span span=whole(ref first,id);
    b.data[0]=88;
    let images::Image second=switch(images::freeze(ref b,8192)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    let u8[3] original=[65,0,66];let u8[3] changed=[88,0,66];
    assert(content(ref first,span,ref original) && content(ref second,whole(ref second,id),ref changed));
    assert(images::payload_bytes(ref first)==3 && images::payload_capacity(ref first)==3);
    assert(number(images::charge(ref first),images::metadata_charge()+3));
    assert(images::inspect(ref first).is_ok && images::text(ref first,span).is_ok);
}
@test fn void admission_and_failed_interning_preserve_exact_limits_and_scratch(){
    assert(!images::builder(4097).is_ok && !images::builder(18446744073709551615).is_ok);
    var images::Builder b=scratch(3);assert(number(images::intern_text(ref mut b,b"abc"),0));
    let images::Builder before=b;assert(!images::intern_bytes(ref mut b,b"z").is_ok && same(ref b,ref before));
    assert(number(images::intern_text(ref mut b,b"abc"),0) && same(ref b,ref before));
    assert(!images::freeze(ref b,images::metadata_charge()+2).is_ok && same(ref b,ref before));
    let images::Image exact=switch(images::freeze(ref b,images::metadata_charge()+3)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    assert(content(ref exact,whole(ref exact,0),b"abc"));
    var images::Builder full=scratch(16);var u8[1] value=[0];var usize i=0;
    let u8[16] samples=[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15];
    while(i<16){value[0]=samples[i];assert(images::intern_bytes(ref mut full,ref value).is_ok);i+=1;}
    let images::Builder old=full;value[0]=16;assert(!images::intern_bytes(ref mut full,ref value).is_ok && same(ref full,ref old));value[0]=0;assert(number(images::intern_bytes(ref mut full,ref value),0));
    var u8[4096] payload=[42;4096];var images::Builder large=scratch(4096);assert(number(images::intern_bytes(ref mut large,ref payload),0));
    let images::Image image=switch(images::freeze(ref large,8192)){case .ok(value):{value}case .err(_):{assert(false);return;}};assert(images::payload_capacity(ref image)==4096 && number(images::charge(ref image),images::metadata_charge()+4096));
}
@test fn void utf8_is_validated_from_bytes_and_text_ranges_require_character_boundaries(){
    var images::Builder b=scratch(32);let u8[9] korean=[237,149,156,234,184,128,33,0,65];
    assert(number(images::intern_text(ref mut b,ref korean),0));let images::Builder old=b;
    let u8[2] overlong=[192,128];let u8[3] surrogate=[237,160,128];let u8[4] outside=[244,144,128,128];let u8[2] truncated=[226,130];
    assert(!images::intern_text(ref mut b,ref overlong).is_ok && same(ref b,ref old));
    assert(!images::intern_text(ref mut b,ref surrogate).is_ok && same(ref b,ref old));
    assert(!images::intern_text(ref mut b,ref outside).is_ok && same(ref b,ref old));
    assert(!images::intern_text(ref mut b,ref truncated).is_ok && same(ref b,ref old));
    assert(number(images::intern_bytes(ref mut b,ref overlong),1));let images::Image image=switch(images::freeze(ref b,8192)){case .ok(value):{value}case .err(_):{assert(false);return;}};let images::Span all=whole(ref image,0);
    assert(images::text(ref image,all).is_ok && images::text(ref image,sub(ref image,all,0,3)).is_ok);
    assert(!images::text(ref image,sub(ref image,all,1,3)).is_ok && !images::text(ref image,sub(ref image,all,1,1)).is_ok);
    assert(images::text(ref image,sub(ref image,all,3,3)).is_ok && images::text(ref image,sub(ref image,all,9,9)).is_ok);
    assert(images::view(ref image,sub(ref image,all,1,2)).is_ok && !images::text(ref image,whole(ref image,1)).is_ok);
}
@test fn void relative_ranges_empty_literals_binary_equality_and_hostile_bounds_are_checked(){
    var images::Builder b=scratch(16);assert(number(images::intern_text(ref mut b,b"abcd"),0));assert(number(images::intern_bytes(ref mut b,b"cd"),1));assert(number(images::intern_text(ref mut b,b""),2));
    let images::Image image=switch(images::freeze(ref b,8192)){case .ok(value):{value}case .err(_):{assert(false);return;}};let images::Span all=whole(ref image,0);let images::Span tail=sub(ref image,all,1,4);let images::Span selected=sub(ref image,tail,1,3);
    assert(content(ref image,selected,b"cd") && answer(images::equal(ref image,selected,ref image,whole(ref image,1)),true));
    assert(answer(images::equal(ref image,all,ref image,selected),false));
    assert(number(images::length(ref image,whole(ref image,2)),0) && images::text(ref image,whole(ref image,2)).is_ok);
    assert(!images::whole(ref image,16).is_ok && !images::whole(ref image,18446744073709551615).is_ok);
    assert(!images::subspan(ref image,all,3,2).is_ok && !images::subspan(ref image,all,0,5).is_ok);
    assert(!images::subspan(ref image,all,18446744073709551615,18446744073709551615).is_ok);
    assert(!images::view(ref image,images::Span{.literal=0,.start=0,.end=18446744073709551615}).is_ok);
    assert(!images::read(ref image,all,4).is_ok && !images::read(ref image,whole(ref image,2),0).is_ok);
    assert(byte(images::read(ref image,selected,0),99));
}
@test fn void sealing_rejects_forged_shapes_utf8_flags_and_unused_rows(){
    var images::Builder b=scratch(8);let u8[2] invalid=[192,128];assert(images::intern_bytes(ref mut b,ref invalid).is_ok);
    b.catalog.text[0]=true;assert(!images::freeze(ref b,8192).is_ok);b.catalog.text[0]=false;
    b.catalog.starts[0]=18446744073709551615;assert(!images::freeze(ref b,8192).is_ok);b.catalog.starts[0]=0;
    b.catalog.ends[0]=3;assert(!images::freeze(ref b,8192).is_ok);b.catalog.ends[0]=2;
    b.catalog.starts[1]=1;assert(!images::freeze(ref b,8192).is_ok);b.catalog.starts[1]=0;
    b.catalog.text[15]=true;assert(!images::freeze(ref b,8192).is_ok);b.catalog.text[15]=false;
    b.catalog.count=17;assert(!images::freeze(ref b,8192).is_ok);b.catalog.count=1;
    b.catalog.used=4097;assert(!images::freeze(ref b,8192).is_ok);b.catalog.used=2;
    b.limit=1;let images::Builder overquota=b;
    assert(!images::intern_bytes(ref mut b,b"z").is_ok && same(ref b,ref overquota));
    assert(!images::freeze(ref b,8192).is_ok && same(ref b,ref overquota));b.limit=8;
    let images::Image image=switch(images::freeze(ref b,8192)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    assert(images::inspect(ref image).is_ok && !images::text(ref image,whole(ref image,0)).is_ok);
}
@test fn void empty_image_has_zero_payload_capacity_and_byte_and_text_literals_stay_distinct(){
    var images::Builder b=scratch(0);assert(number(images::intern_bytes(ref mut b,b""),0));assert(number(images::intern_text(ref mut b,b""),1));
    assert(number(images::intern_bytes(ref mut b,b""),0) && number(images::intern_text(ref mut b,b""),1));
    let images::Image image=switch(images::freeze(ref b,images::metadata_charge())){case .ok(value):{value}case .err(_):{assert(false);return;}};
    assert(number(images::inspect(ref image),2) && images::payload_capacity(ref image)==0);
    assert(number(images::charge(ref image),images::metadata_charge()) && !images::text(ref image,whole(ref image,0)).is_ok && images::text(ref image,whole(ref image,1)).is_ok);
}
