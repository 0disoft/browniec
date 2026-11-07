module tests::m2::input_reference_views;
import input_reference_views as input;
import static_views as views;
import errors as errors;
import std::bytes as bytes;
import std::process as process;

fn input::State opened(usize length){
    return switch(input::open(length)){case .ok(v):{v}case .err(_):{assert(false);input::disabled()}};
}
fn usize ok(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);1}};}
fn void error(Result<usize,errors::Error> r,u8 kind,usize offset){
    switch(r){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind && e.offset==offset);}};
}
fn views::Span span(usize start,usize length){return views::Span{.start=start,.length=length};}
fn views::Span read(Result<views::Span,errors::Error> r){
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);span(0,0)}};
}
fn void rejected(Result<views::Span,errors::Error> r,u8 kind,usize offset){
    switch(r){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind && e.offset==offset);}};
}
fn void same(views::Span a,usize start,usize length){assert(a.start==start && a.length==length);}
fn bool injecting(){
    if(process::arg_count()<2){return false;}var u8[16] data=[0;16];
    let usize length=switch(process::arg(1,ref mut data)){case .ok(v):{v}case .err(_):{assert(false);0}};
    return bytes::equal(ref data[..length],b"inject");
}
@test fn void exact_zero_4096_4097_and_mebibyte_spans_need_no_codec_or_payload(){
    let usize[4] sizes=[0,4096,4097,1048576];var usize i=0;
    while(i<4){let usize n=sizes[i];var input::State state=opened(n);assert(input::enabled(ref state));
        assert(ok(input::put(ref mut state,1,0,span(0,n),71))==0);
        same(read(input::get(ref state,1,0,72)),0,n);
        assert(ok(input::put(ref mut state,31,15,span(n,0),73))==0);
        same(read(input::get(ref state,31,15,74)),n,0);
        error(input::put(ref mut state,1,1,span(n,1),75),5,75);
        error(input::put(ref mut state,1,1,span(n+1,0),76),5,76);i+=1;
    }
}
@test fn void alias_crop_and_selected_formal_grant_preserve_absolute_containment(){
    var input::State state=opened(1048576);let views::Span full=span(0,1048576);
    let views::Span child=read(input::crop(ref full,4096,1048575,81));
    same(child,4096,1044479);assert(ok(input::put(ref mut state,1,0,child,82))==0);
    let views::Span alias=read(input::get(ref state,1,0,83));
    assert(ok(input::put(ref mut state,1,1,alias,84))==0);
    assert(ok(input::put_grant(ref mut state,2,0,span(4096,4097),85))==0);
    assert(ok(input::put_grant(ref mut state,2,7,span(9000,12),86))==0);
    let views::Span selected=read(input::grant(ref state,2,0,87));
    let views::Span other=read(input::grant(ref state,2,7,88));
    let views::Span end=read(input::crop(ref selected,4097,4097,89));same(end,8193,0);
    assert(input::contains(ref alias,ref selected) && input::contains(ref selected,ref end));
    assert(!input::contains(ref selected,ref other));
    assert(ok(input::close(ref mut state,1,0,90))==0);
    same(read(input::get(ref state,1,1,91)),4096,1044479);
    error(input::put_grant(ref mut state,2,0,other,92),5,92);
    same(read(input::grant(ref state,2,0,93)),4096,4097);
}
@test fn void all_live_frame_slots_clear_exactly_the_selected_frame_and_reuse(){
    var input::State state=opened(4097);var usize f=1;
    while(f<32){var usize i=0;while(i<16){assert(ok(input::put(ref mut state,f,i,span(f,i),1))==0);i+=1;}
        i=0;while(i<8){assert(ok(input::put_grant(ref mut state,f,i,span(f,i),2))==0);i+=1;}f+=1;
    }
    assert(ok(input::clear_frame(ref mut state,16,3))==0);f=1;
    while(f<32){var usize i=0;while(i<16){
            if(f==16){rejected(input::get(ref state,f,i,4),5,4);}else{same(read(input::get(ref state,f,i,4)),f,i);}i+=1;
        }i=0;while(i<8){
            if(f==16){rejected(input::grant(ref state,f,i,5),5,5);}else{same(read(input::grant(ref state,f,i,5)),f,i);}i+=1;
        }f+=1;
    }
    error(input::close(ref mut state,16,0,6),5,6);
    assert(ok(input::put(ref mut state,16,0,span(4097,0),7))==0);
    assert(ok(input::put_grant(ref mut state,16,7,span(0,4097),8))==0);
    assert(ok(input::clear_frame(ref mut state,16,9))==0);
    assert(ok(input::clear_frame(ref mut state,16,10))==0);
    assert(ok(input::put(ref mut state,16,0,span(0,4097),11))==0);
    same(read(input::get(ref state,16,0,12)),0,4097);
}
@test fn void disabled_bounds_and_overwrite_reject_without_publishing(){
    var input::State off=input::disabled();assert(!input::enabled(ref off));
    assert(ok(input::clear_frame(ref mut off,31,1))==0);
    error(input::put(ref mut off,1,0,span(0,0),2),5,2);
    error(input::put_grant(ref mut off,1,0,span(0,0),3),5,3);
    rejected(input::get(ref off,1,0,4),5,4);rejected(input::grant(ref off,1,0,5),5,5);
    error(input::close(ref mut off,1,0,6),5,6);
    var input::State state=opened(4097);
    error(input::put(ref mut state,0,0,span(0,0),7),5,7);
    error(input::put(ref mut state,32,0,span(0,0),8),5,8);
    error(input::put(ref mut state,1,16,span(0,0),9),5,9);
    error(input::put_grant(ref mut state,1,8,span(0,0),10),5,10);
    error(input::clear_frame(ref mut state,0,11),5,11);
    error(input::clear_frame(ref mut state,18446744073709551615,12),5,12);
    error(input::put(ref mut state,1,0,span(18446744073709551615,2),13),5,13);
    assert(ok(input::put(ref mut state,1,0,span(4096,1),14))==0);
    error(input::put(ref mut state,1,0,span(0,4097),15),5,15);
    same(read(input::get(ref state,1,0,16)),4096,1);
    assert(ok(input::close(ref mut state,1,0,17))==0);error(input::close(ref mut state,1,0,18),5,18);
    assert(ok(input::put(ref mut state,1,0,span(0,4097),19))==0);
    switch(input::open(1048577)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==0);}};
    switch(input::open(18446744073709551615)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==0);}};
}
@test fn void max_arithmetic_and_marker_equality_do_not_wrap_or_imply_authority(){
    let usize max=18446744073709551615;let views::Span end=span(max,0);let views::Span last=span(max-1,1);
    assert(input::contains(ref last,ref end) && input::contains(ref end,ref end));
    same(read(input::crop(ref last,1,1,21)),max,0);same(read(input::crop(ref end,0,0,22)),max,0);
    let views::Span forged=span(max,1);assert(!input::contains(ref forged,ref end));
    assert(!input::contains(ref last,ref forged) && !input::contains(ref end,ref last));
    rejected(input::crop(ref forged,0,0,23),14,23);
    rejected(input::crop(ref last,1,0,24),14,24);rejected(input::crop(ref last,0,2,25),14,25);
    rejected(input::crop(ref last,max,max,26),14,26);
    let views::Span all=span(0,max);same(read(input::crop(ref all,max,max,27)),max,0);
    assert(input::marker()==1073741824 && input::is_input(1073741824));
    assert(!input::is_input(0) && !input::is_input(1073741823) && !input::is_input(1073741825) && !input::is_input(4294967295));
    let input::State off=input::disabled();rejected(input::get(ref off,1,0,28),5,28);
}
// The ordinary focused suite executes the success route. The existing explicit
// allocator helper executes the OOM branch in a separate native process.
@test fn void allocator_open_failure_is_transactional_and_explicit_retry_succeeds(){
    let input::State off=input::disabled();assert(!input::enabled(ref off));
    if(injecting()){switch(input::open(1048576)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==15 && e.offset==0);}
    };assert(!input::enabled(ref off));}
    var input::State state=opened(1048576);assert(input::enabled(ref state));
    assert(ok(input::put(ref mut state,31,15,span(0,1048576),29))==0);
    same(read(input::get(ref state,31,15,30)),0,1048576);
}
