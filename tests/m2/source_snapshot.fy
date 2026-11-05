module tests::m2::source_snapshot;
import source_snapshot as snapshots;
import std::bytes as bytes;

fn snapshots::Builder builder(usize source,usize names){
    return switch(snapshots::builder(source,names)){case .ok(v):{v}case .err(_):{assert(false);builder(0,0)}};
}
fn snapshots::Snapshot frozen(ref snapshots::Builder b){
    return switch(snapshots::freeze(b)){case .ok(v):{v}case .err(_):{assert(false);frozen(b)}};
}
fn usize made(Result<usize,snapshots::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 kind(snapshots::Error e){return switch(e){case .State:{0}case .Limit:{1}case .Name:{2}case .Duplicate:{3}case .Utf8:{4}case .Bounds:{5}};}
fn void fail(Result<usize,snapshots::Error> r,u8 expected){
    switch(r){case .ok(_):{assert(false);}case .err(e):{assert(kind(e)==expected);}};
}
fn void bad(ref snapshots::Builder b,u8 expected){
    switch(snapshots::freeze(b)){case .ok(_):{assert(false);}case .err(e):{assert(kind(e)==expected);}};
}
fn snapshots::Span whole(ref snapshots::Snapshot p,usize id){
    return switch(snapshots::whole(p,id)){case .ok(v):{v}case .err(_):{assert(false);snapshots::no_source()}};
}
fn bool content(ref snapshots::Snapshot p,snapshots::Span span,ref u8[] expected){
    return switch(snapshots::view(p,span)){case .ok(v):{bytes::equal(v,expected)}case .err(_):{false}};
}
fn void invalid(ref snapshots::Snapshot p,snapshots::Span span){
    switch(snapshots::view(p,span)){case .ok(_):{assert(false);}case .err(e):{assert(kind(e)==5);}};
    switch(snapshots::position(p,span)){case .ok(_):{assert(false);}case .err(e):{assert(kind(e)==5);}};
}
fn void at(ref snapshots::Snapshot p,usize start,usize line,usize column){
    switch(snapshots::position(p,snapshots::Span{.source=0,.start=start,.end=start})){
        case .ok(v):{assert(v.line==line && v.byte_column==column);}
        case .err(_):{assert(false);}
    };
}

@test fn void snapshot_owns_exact_source_names_and_bytes_after_all_scratch_changes(){
    var snapshots::Builder b=builder(4096,4096);
    var u8[3] name=[97,46,98];var u8[3] source=[49,50,51];
    assert(made(snapshots::add(ref mut b,ref name,ref source))==0);
    name[0]=120;source[0]=57;
    assert(made(snapshots::add(ref mut b,b"second",b"module main;"))==1);
    let snapshots::Snapshot p=frozen(ref b);
    b.names[0]=0;b.data[0]=0;b.starts[0]=4096;b.count=0;
    assert(snapshots::count(ref p)==2);
    assert(content(ref p,whole(ref p,0),b"123"));
    assert(content(ref p,whole(ref p,1),b"module main;"));
    switch(snapshots::name(ref p,0)){case .ok(v):{assert(bytes::equal(v,b"a.b"));}case .err(_):{assert(false);}};
    assert(snapshots::initialized_bytes(ref p)==24);
}

@test fn void rejected_append_preserves_both_pools_and_stable_source_indices(){
    var snapshots::Builder b=builder(3,12);
    assert(made(snapshots::add(ref mut b,b"a",b"12"))==0);
    fail(snapshots::add(ref mut b,b"b",b"xx"),1);
    fail(snapshots::add(ref mut b,b"a",b""),3);
    fail(snapshots::add(ref mut b,b"\x1B",b""),2);
    fail(snapshots::add(ref mut b,b"\xFF",b""),2);
    fail(snapshots::add(ref mut b,b"b",b"\xFF"),4);
    assert(snapshots::pending(ref b)==1 && snapshots::source_bytes(ref b)==2 && snapshots::name_bytes(ref b)==1);
    assert(made(snapshots::add(ref mut b,b"b",b"x"))==1);
    let snapshots::Snapshot p=frozen(ref b);
    assert(content(ref p,whole(ref p,0),b"12") && content(ref p,whole(ref p,1),b"x"));
}

@test fn void exact_independent_pool_and_file_limits_allow_empty_sources(){
    assert(!snapshots::builder(4097,0).is_ok && !snapshots::builder(0,4097).is_ok);
    var snapshots::Builder b=builder(4096,4096);let u8[4096] payload=[65;4096];
    assert(made(snapshots::add(ref mut b,b"all",ref payload))==0);
    fail(snapshots::add(ref mut b,b"extra",b"x"),1);
    var u8[1] name=[65];var usize i=1;
    while(i<16){assert(made(snapshots::add(ref mut b,ref name,b""))==i);name[0]+=1;i+=1;}
    fail(snapshots::add(ref mut b,b"last",b""),1);
    let snapshots::Snapshot p=frozen(ref b);assert(snapshots::count(ref p)==16);
    assert(content(ref p,whole(ref p,0),ref payload) && content(ref p,whole(ref p,15),b""));
    var snapshots::Builder names=builder(0,4096);var u8[256] key=[97;256];i=0;
    while(i<16){key[255]+=1;assert(made(snapshots::add(ref mut names,ref key,b""))==i);i+=1;}
    assert(snapshots::name_bytes(ref names)==4096);
    let snapshots::Snapshot all_names=frozen(ref names);assert(snapshots::count(ref all_names)==16);
    var snapshots::Builder small=builder(0,3);let usize first=made(snapshots::add(ref mut small,b"abc",b""));
    fail(snapshots::add(ref mut small,b"x",b""),1);assert(snapshots::name_bytes(ref small)==3);
}

@test fn void hostile_scratch_is_independently_rejected_before_access_or_subtraction(){
    var snapshots::Builder b=builder(4096,4096);
    let usize a=made(snapshots::add(ref mut b,b"a",b"A"));let usize c=made(snapshots::add(ref mut b,b"b",b"B"));
    b.names[1]=97;bad(ref b,3);b.names[1]=98;
    b.data[0]=255;bad(ref b,4);b.data[0]=65;
    b.names[0]=0;bad(ref b,2);b.names[0]=97;
    b.starts[0]=18446744073709551615;bad(ref b,0);b.starts[0]=0;
    b.ends[0]=18446744073709551615;bad(ref b,0);b.ends[0]=1;
    b.starts[2]=1;bad(ref b,0);b.starts[2]=0;
    b.used=18446744073709551615;fail(snapshots::add(ref mut b,b"c",b"C"),0);bad(ref b,0);b.used=2;
    b.name_limit=18446744073709551615;bad(ref b,0);b.name_limit=4096;
    b.count=17;bad(ref b,0);b.count=2;
    let snapshots::Snapshot p=frozen(ref b);assert(content(ref p,whole(ref p,0),b"A"));
}

@test fn void source_local_half_open_spans_cannot_cross_files_or_parent_ranges(){
    var snapshots::Builder b=builder(4096,4096);
    let usize a=made(snapshots::add(ref mut b,b"a",b"0123"));let usize c=made(snapshots::add(ref mut b,b"b",b"XYZ"));
    let snapshots::Snapshot p=frozen(ref b);let snapshots::Span root=whole(ref p,0);
    let snapshots::Span parent=switch(snapshots::subspan(ref p,root,1,3)){case .ok(v):{v}case .err(_):{assert(false);root}};
    let snapshots::Span part=switch(snapshots::subspan(ref p,parent,0,1)){case .ok(v):{v}case .err(_):{assert(false);root}};
    assert(part.source==0 && part.start==1 && part.end==2 && content(ref p,part,b"1"));
    assert(!snapshots::subspan(ref p,parent,0,3).is_ok);
    assert(!snapshots::subspan(ref p,parent,2,1).is_ok);
    assert(!snapshots::subspan(ref p,parent,0,18446744073709551615).is_ok);
    invalid(ref p,snapshots::no_source());
    invalid(ref p,snapshots::Span{.source=18446744073709551615,.start=0,.end=0});
    invalid(ref p,snapshots::Span{.source=0,.start=3,.end=2});
    invalid(ref p,snapshots::Span{.source=0,.start=0,.end=18446744073709551615});
    assert(!snapshots::whole(ref p,2).is_ok && !snapshots::name(ref p,2).is_ok);
    assert(content(ref p,snapshots::Span{.source=0,.start=4,.end=4},b""));
}

@test fn void positions_preserve_original_bom_utf8_crlf_and_eof_byte_offsets(){
    var snapshots::Builder b=builder(4096,4096);
    let usize a=made(snapshots::add(ref mut b,b"unicode",b"\xEF\xBB\xBF\xED\x95\x9C\r\nxy\n"));
    let usize c=made(snapshots::add(ref mut b,b"empty",b""));
    let snapshots::Snapshot p=frozen(ref b);
    at(ref p,0,1,1);at(ref p,3,1,4);at(ref p,4,1,5);at(ref p,6,1,7);at(ref p,7,1,8);
    at(ref p,8,2,1);at(ref p,9,2,2);at(ref p,10,2,3);at(ref p,11,3,1);
    switch(snapshots::position(ref p,whole(ref p,1))){case .ok(v):{assert(v.line==1 && v.byte_column==1);}case .err(_):{assert(false);}};
    var snapshots::Builder empty=builder(0,0);let snapshots::Snapshot none=frozen(ref empty);
    assert(snapshots::count(ref none)==0 && !snapshots::whole(ref none,0).is_ok);
}
