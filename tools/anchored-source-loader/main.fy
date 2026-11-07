module main;
import anchored_source_loader as loader;
import source_snapshot as sources;
import std::bytes as bytes;
import std::process as process;
unsafe extern C fn void asl_test_start();
unsafe extern C fn void asl_test_clean();
unsafe extern C fn void asl_test_failure(u32 mode);
unsafe extern C fn void asl_test_rewrite(ptr u8 root,usize length,u32 mode);
unsafe extern C fn void asl_test_bridge(ptr u8 root,usize length);
fn sources::Snapshot loaded(ref u8[] root,ref u8[] names,ref usize[] ends,usize limit,usize names_limit){
    return switch(loader::load(root,names,ends,limit,names_limit)){
        case .ok(v):{v}case .err(_):{assert(false);loaded(root,names,ends,limit,names_limit)}
    };
}
fn void rejected(Result<sources::Snapshot,loader::Error> result,u8 kind){
    switch(result){case .ok(_):{assert(false);}case .err(e):{switch(e){
        case .Request:{assert(kind==0);}case .Native:{assert(kind==1);}case .Admission:{assert(kind==2);}
    };}};
    unsafe {asl_test_clean()};
}
fn ref u8[] name(ref sources::Snapshot s,usize id){return switch(sources::name(s,id)){case .ok(v):{v}case .err(_):{assert(false);b""}};}
fn ref u8[] data(ref sources::Snapshot s,usize id){
    let sources::Span span=switch(sources::whole(s,id)){case .ok(v):{v}case .err(_):{assert(false);sources::no_source()}};
    return switch(sources::view(s,span)){case .ok(v):{v}case .err(_):{assert(false);b""}};
}
fn void exact(ref u8[] root){
    let usize[2] ends=[9,17];
    let sources::Snapshot s=loaded(root,b"empty.brcsub/a.fy",ref ends,4096,4096);
    unsafe {asl_test_clean()};
    assert(sources::count(ref s)==2 && bytes::equal(name(ref s,0),b"empty.brc") && data(ref s,0).len==0);
    assert(bytes::equal(name(ref s,1),b"sub/a.fy") && bytes::equal(data(ref s,1),b"module a;\r\n// \xc3\xa9\x00"));
    unsafe {asl_test_rewrite(root as ptr u8,root.len,1)};
    assert(bytes::equal(data(ref s,1),b"module a;\r\n// \xc3\xa9\x00"));
    let sources::Snapshot moved=s;assert(sources::count(ref moved)==2);
    unsafe {asl_test_rewrite(root as ptr u8,root.len,0)};
}
fn void failures(ref u8[] root){
    let usize[1] one=[10];let usize[2] partial=[8,18];
    rejected(loader::load(root,b"invalid.fy",ref one,4096,4096),2);
    rejected(loader::load(root,b"sub/a.fyinvalid.fy",ref partial,4096,4096),2);
    let usize[1] valid=[8];
    rejected(loader::load(root,b"sub/a.fy",ref valid,4096,7),2);
    rejected(loader::load(root,b"sub/a.fy",ref valid,0,4096),1);
    let usize[1] missing=[10];rejected(loader::load(root,b"missing.fy",ref missing,4096,4096),1);
    let usize[1] escape=[7];rejected(loader::load(root,b"../a.fy",ref escape,4096,4096),1);
    let usize[2] duplicate=[8,16];rejected(loader::load(root,b"sub/a.fysub/a.fy",ref duplicate,4096,4096),1);
    let usize[1] alias=[8];rejected(loader::load(root,b"alias.fy",ref alias,4096,4096),1);
    rejected(loader::load(b"\xff",b"sub/a.fy",ref valid,4096,4096),1);
    rejected(loader::load(b"C:\\\x00",b"sub/a.fy",ref valid,4096,4096),1);
    let usize[1] bad=[18446744073709551615];rejected(loader::load(root,b"sub/a.fy",ref bad,4096,4096),0);
    let usize[2] backwards=[8,7];rejected(loader::load(root,b"sub/a.fy",ref backwards,4096,4096),0);
    rejected(loader::load(root,b"sub/a.fyx",ref valid,4096,4096),0);
    rejected(loader::load(root,b"sub/a.fy",ref valid,4097,4096),0);
}
fn void bounds(ref u8[] root){
    let usize[1] end=[8];let sources::Snapshot s=loaded(root,b"bound.fy",ref end,4096,8);
    assert(data(ref s,0).len==4096 && data(ref s,0)[0]==97 && data(ref s,0)[4095]==97);
    rejected(loader::load(root,b"large.fy",ref end,4096,4096),1);
    var u8[96] names=[0;96];var usize[16] ends=[0;16];var usize i=0;
    let ref u8[] packed=b"f00.fyf01.fyf02.fyf03.fyf04.fyf05.fyf06.fyf07.fyf08.fyf09.fyf10.fyf11.fyf12.fyf13.fyf14.fyf15.fy";
    while(i<96){names[i]=packed[i];i+=1;}i=0;while(i<16){ends[i]=(i+1)*6;i+=1;}
    let sources::Snapshot many=loaded(root,ref names,ref ends,0,96);assert(sources::count(ref many)==16);
    i=0;while(i<16){assert(bytes::equal(name(ref many,i),packed[i*6..i*6+6]) && data(ref many,i).len==0);i+=1;}
    let usize[17] too_many=[0;17];rejected(loader::load(root,ref names,ref too_many,4096,4096),0);
    unsafe {asl_test_clean()};
}
fn void oom(ref u8[] root){
    let usize[1] ends=[8];var u32 mode=1;
    while(mode<=3){unsafe {asl_test_failure(mode)};rejected(loader::load(root,b"sub/a.fy",ref ends,4096,4096),1);
        unsafe {asl_test_failure(0)};mode+=1;}
    let sources::Snapshot s=loaded(root,b"sub/a.fy",ref ends,4096,4096);assert(data(ref s,0).len==17);
    unsafe {asl_test_clean()};
}
fn i32 main(){
    var u8[3072] root=[0;3072];let usize length=switch(process::arg(1,ref mut root)){case .ok(v):{v}case .err(_):{return 2;}};
    let ref u8[] path=ref root[..length];unsafe {asl_test_start()};
    exact(path);failures(path);bounds(path);oom(path);
    var usize i=0;while(i<32){failures(path);i+=1;}
    unsafe {asl_test_bridge(path as ptr u8,path.len)};unsafe {asl_test_clean()};return 0;
}
