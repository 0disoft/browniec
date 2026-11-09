module tests::m2::runtime_setup_work;
import runtime_setup_work as setup;
import input_reference_views as windows;
import static_views as views;
import metadata_budget as budget;
import std::bytes as bytes;
import std::vec as vec;

fn bytes::Buffer buffer(usize capacity){
    return switch(bytes::with_capacity(capacity)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
}
fn setup::Plan plan(u8 kind){
    let usize prefix=if(kind==3){3}else if(kind==2){2}else if(kind==1){1}else{0};
    let usize row=if(kind==3){18}else if(kind==0){9}else{14};
    let usize marker=if(kind==3){22530}else if(kind==2){18434}else if(kind==1){14338}else{0};
    return setup::Plan{.core=2051,.payload=4101,.list_length=300,.scratch=1200,
        .places=prefix+32*(row*2+1),.prefix=prefix,.marker=marker,.kind=kind};
}
fn void run(u8 kind){
    let setup::Plan p=plan(kind);var setup::State w=setup::empty();assert(setup::begin(ref mut w,p).is_ok);
    var bytes::Buffer core=buffer(p.core);var bytes::Buffer payload=buffer(p.payload);
    var bytes::Buffer scratch=buffer(p.scratch);var vec::Vec<i64> cells=vec::empty<i64>();
    var vec::Vec<usize> places=vec::empty<usize>();
    assert(vec::reserve<i64>(ref mut cells,p.list_length).is_ok);
    assert(vec::reserve<usize>(ref mut places,p.places).is_ok);
    let usize cap0=bytes::capacity(ref core);let usize cap1=bytes::capacity(ref payload);
    let usize cap2=bytes::capacity(ref scratch);let usize cap3=vec::capacity<i64>(ref cells);
    let usize cap4=vec::capacity<usize>(ref places);
    var budget::State b=budget::empty();assert(budget::admit(ref mut b,1,0).is_ok);
    let bool deferred=switch(setup::advance(ref mut w,ref mut core,ref mut payload,ref mut cells,ref mut scratch,ref mut places,ref mut b)){
        case .ok(v):{v}case .err(_):{assert(false);true}};
    assert(!deferred);
    assert(bytes::view(ref core).len==0 && w.phase==0 && w.at==0);
    var bool done=false;var usize stages=0;
    while(!done){assert(budget::reset(ref mut b,0).is_ok);
        done=switch(setup::advance(ref mut w,ref mut core,ref mut payload,ref mut cells,ref mut scratch,ref mut places,ref mut b)){
            case .ok(v):{v}case .err(_):{assert(false);false}};
        stages+=1;assert(stages<100);
    }
    assert(w.done && !w.active && bytes::view(ref core).len==p.core && bytes::view(ref payload).len==p.payload);
    assert(bytes::view(ref scratch).len==p.scratch && vec::len<i64>(ref cells)==p.list_length && vec::len<usize>(ref places)==p.places);
    assert(bytes::capacity(ref core)==cap0 && bytes::capacity(ref payload)==cap1 && bytes::capacity(ref scratch)==cap2);
    assert(vec::capacity<i64>(ref cells)==cap3 && vec::capacity<usize>(ref places)==cap4);
    let ref u8[] a=bytes::view(ref core);let ref u8[] d=bytes::view(ref payload);let ref u8[] s=bytes::view(ref scratch);
    var usize i=0;while(i<a.len){assert(a[i]==0);i+=1;}i=0;while(i<d.len){assert(d[i]==0);i+=1;}
    i=0;while(i<s.len){assert(s[i]==0);i+=1;}let ref i64[] c=vec::view_i64(ref cells);
    i=0;while(i<c.len){assert(c[i]==0);i+=1;}let ref usize[] words=vec::view_usize(ref places);
    i=0;while(i<words.len){let usize expected=if(i==0 && kind!=0){p.marker}
        else if(i==1 && kind==2){2}else if(i==1 && kind==3){18}else if(i==2 && kind==3){1}else{0};
        assert(words[i]==expected);i+=1;}
}
@test fn void initializes_all_place_formats_without_growth(){run(0);run(1);run(2);run(3);}
@test fn void rejects_bad_plan_and_undersized_reservation_before_writing(){
    var setup::State w=setup::empty();var setup::Plan p=plan(3);p.marker=0;
    assert(!setup::begin(ref mut w,p).is_ok);p=plan(3);assert(setup::begin(ref mut w,p).is_ok);
    var bytes::Buffer core=buffer(0);var bytes::Buffer payload=buffer(p.payload);var bytes::Buffer scratch=buffer(p.scratch);
    var vec::Vec<i64> cells=vec::empty<i64>();var vec::Vec<usize> places=vec::empty<usize>();
    assert(vec::reserve<i64>(ref mut cells,p.list_length).is_ok);assert(vec::reserve<usize>(ref mut places,p.places).is_ok);
    var budget::State b=budget::empty();
    assert(!setup::advance(ref mut w,ref mut core,ref mut payload,ref mut cells,ref mut scratch,ref mut places,ref mut b).is_ok);
    assert(bytes::view(ref core).len==0 && w.at==0 && b.total==0);
}
@test fn void input_cells_initialize_in_bounded_stages(){
    var windows::State staged=switch(windows::reserve(99)){case .ok(v):{v}case .err(_):{assert(false);windows::disabled()}};
    let windows::State oracle=switch(windows::open(99)){case .ok(v):{v}case .err(_):{assert(false);windows::disabled()}};
    var budget::State b=budget::empty();var usize i=0;
    while(i<48){assert(budget::reset(ref mut b,0).is_ok);
        let bool done=switch(windows::initialize_chunk(ref mut staged,ref mut b)){case .ok(v):{v}case .err(_):{assert(false);false}};
        assert(done==(i==47));assert(windows::enabled(ref staged)==done);i+=1;
    }
    assert(windows::enabled(ref oracle));let views::Span span=views::Span{.start=2,.length=7};
    assert(windows::put(ref mut staged,1,2,span,0).is_ok);
    let views::Span found=switch(windows::get(ref staged,1,2,0)){case .ok(v):{v}case .err(_):{assert(false);span}};
    assert(found.start==2 && found.length==7);assert(!windows::reserve(1048577).is_ok);
}
