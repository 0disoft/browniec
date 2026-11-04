module tests::m2::static_views;
import static_views as views;
import static_ir as statics;
import static_image as images;
import errors as errors;
import compiler as compiler;
import program_image as programs;
import slice_result_ir as ir;
import verifier as verifier;

fn u32 packed(usize start,usize length,usize payload){
    return switch(views::pack(start,length,payload,71)){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn views::Span span(Result<views::Span,errors::Error> result){
    return switch(result){case .ok(v):{v}case .err(_):{assert(false);views::Span{.start=0,.length=0}}};
}
fn void bad_span(Result<views::Span,errors::Error> result,u8 kind){
    switch(result){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind && e.offset==71);}};
}
fn void bad_word(Result<u32,errors::Error> result,u8 kind){
    switch(result){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind && e.offset==71);}};
}
fn statics::Sites fixture(u8 kind){
    var statics::Sites s=statics::empty();s.count=1;s.definitions[0]=0;s.functions[0]=0;s.starts[0]=10;
    s.kinds[0]=kind;s.spans[0]=images::Span{.literal=0,.start=2,.end=6};return s;
}
@test fn void packed_ranges_round_trip_zero_empty_and_full_payload_edges(){
    let usize[4] values=[0,1,4095,4096];var usize i=0;
    while(i<4){var usize j=0;while(j<4){let usize a=values[i];let usize n=values[j];
        if(a+n<=4096){let u32 word=packed(a,n,4096);assert((word as usize)==a*8192+n);
            let views::Span v=span(views::unpack(word,4096,71));assert(v.start==a && v.length==n);}
        j+=1;}i+=1;}
    assert(packed(0,0,0)==0);
    let views::Span empty=span(views::unpack(packed(4096,0,4096),4096,71));assert(empty.start==4096 && empty.length==0);
}
@test fn void forged_payloads_high_bits_and_host_sized_values_fail_before_arithmetic(){
    bad_word(views::pack(18446744073709551615,1,4096,71),5);
    bad_word(views::pack(1,18446744073709551615,4096,71),5);
    bad_word(views::pack(0,0,18446744073709551615,71),5);
    bad_word(views::pack(4096,1,4096,71),5);bad_word(views::pack(4097,0,4096,71),5);
    bad_span(views::unpack(67108864,4096,71),5);bad_span(views::unpack(4294967295,4096,71),5);
    bad_span(views::unpack(4097,4096,71),5);bad_span(views::unpack(8191,4096,71),5);
    bad_span(views::unpack(0,4097,71),5);
}
@test fn void byte_windows_can_narrow_but_never_cross_the_proved_image_window(){
    var statics::Sites s=fixture(1);
    let views::Span full=span(views::inspect(ref s,0,0,1,packed(10,4,20),20,71));assert(full.start==10 && full.length==4);
    let views::Span child=span(views::inspect(ref s,0,0,0,packed(11,2,20),20,71));assert(child.start==11 && child.length==2);
    let views::Span empty=span(views::inspect(ref s,0,0,1,packed(14,0,20),20,71));assert(empty.length==0);
    bad_span(views::inspect(ref s,0,0,1,packed(9,4,20),20,71),5);
    bad_span(views::inspect(ref s,0,0,1,packed(12,3,20),20,71),5);
    bad_span(views::inspect(ref s,0,0,1,packed(15,0,20),20,71),5);
    bad_span(views::inspect(ref s,0,1,1,packed(10,4,20),20,71),5);
    bad_span(views::inspect(ref s,0,0,2,packed(10,4,20),20,71),5);
    bad_span(views::inspect(ref s,16,0,0,0,20,71),5);
    s.spans[0]=images::Span{.literal=0,.start=4,.end=2};bad_span(views::inspect(ref s,0,0,0,0,20,71),5);
    s=fixture(1);s.starts[0]=18446744073709551615;bad_span(views::inspect(ref s,0,0,0,0,20,71),5);
}
@test fn void text_words_preserve_exact_validated_ranges_and_cannot_coerce_bytes(){
    let statics::Sites text=fixture(2);let u32 exact=packed(10,4,20);
    let views::Span v=span(views::inspect(ref text,0,0,2,exact,20,71));assert(v.length==4);
    bad_span(views::inspect(ref text,0,0,2,packed(11,2,20),20,71),5);
    bad_span(views::inspect(ref text,0,0,0,packed(10,3,20),20,71),5);
    bad_span(views::inspect(ref text,0,0,1,exact,20,71),5);
    let statics::Sites bytes=fixture(1);bad_span(views::inspect(ref bytes,0,0,2,exact,20,71),5);
}
@test fn void physical_frames_and_liveness_remain_separate_from_valid_range_words(){
    let statics::Sites s=fixture(1);var u32[512] words=[0;512];
    words[0]=packed(10,4,20);words[31*16]=packed(11,2,20);
    let views::Span parent=span(views::live(ref s,0,0,1,ref words[..16],1,20,71));assert(parent.start==10 && parent.length==4);
    let views::Span child=span(views::live(ref s,0,0,1,ref words[31*16..32*16],1,20,71));assert(child.start==11 && child.length==2);
    bad_span(views::live(ref s,0,0,1,ref words[31*16..32*16],0,20,71),5);
    bad_span(views::live(ref s,0,0,1,ref words[..16],65537,20,71),5);
    bad_span(views::live(ref s,0,0,1,ref words[..15],1,20,71),5);
    bad_span(views::live(ref s,16,0,1,ref words[..16],1,20,71),5);
    assert(words[0]==packed(10,4,20) && words[31*16]==packed(11,2,20));
}
@test fn void guest_crop_is_relative_and_reports_bounds_without_mutating_its_parent(){
    let views::Span parent=views::Span{.start=10,.length=4};
    let u32 child=switch(views::crop(ref parent,1,3,20,71)){case .ok(v):{v}case .err(_):{assert(false);0}};
    let views::Span selected=span(views::unpack(child,20,71));assert(selected.start==11 && selected.length==2);
    let u32 end=switch(views::crop(ref parent,4,4,20,71)){case .ok(v):{v}case .err(_):{assert(false);0}};
    assert(span(views::unpack(end,20,71)).length==0);
    bad_word(views::crop(ref parent,3,2,20,71),14);bad_word(views::crop(ref parent,0,5,20,71),14);
    bad_word(views::crop(ref parent,0,18446744073709551615,20,71),14);
    let views::Span forged=views::Span{.start=18446744073709551615,.length=4};
    bad_word(views::crop(ref forged,0,0,20,71),5);assert(parent.start==10 && parent.length==4);
}
@test fn void packed_byte_subranges_use_real_retained_image_proof_without_pinning_it(){
    let programs::Program p=switch(compiler::compile_image(b"module main;fn i32 main(){let ref u8[] a=b\"abcd\";return a[0] as i32;}",580)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let ref ir::Program code=programs::code(ref p);let ref images::Image image=programs::literals(ref p);
    let statics::Sites s=switch(verifier::inspect_statics(ref code.body,image)){
        case .ok(v):{v}case .err(_):{assert(false);statics::empty()}
    };
    let usize size=images::payload(image).len;
    let views::Span selected=span(views::inspect(ref s,0,0,1,packed(1,2,size),size,71));assert(selected.start==1 && selected.length==2);
    bad_span(views::inspect(ref s,0,0,2,packed(1,2,size),size,71),5);
}
