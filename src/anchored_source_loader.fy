module anchored_source_loader;
import source_snapshot as sources;

// Native adapter. No Fairy resource layout crosses the C boundary.
unsafe extern C fn ptr mut void bc_asl_open(ptr u8 root,usize length);
unsafe extern C fn ptr mut void bc_asl_open_project(ptr u8 path,usize length,ptr mut u8 out,
    usize capacity,ptr mut usize used,ptr mut u32 status);
unsafe extern C fn u32 bc_asl_member(ptr mut void owner,ptr u8 name,usize length);
unsafe extern C fn u32 bc_asl_collect_until(ptr mut void owner,usize source_bytes,usize deadline);
unsafe extern C fn usize bc_asl_copy(ptr mut void owner,usize index,u32 part,ptr mut u8 out,usize capacity);
unsafe extern C fn void bc_asl_close(ptr mut void owner);
pub resource Root { ptr mut void owner; usize manifest_bytes; cleanup { unsafe {bc_asl_close(this.owner)}; } }
pub enum Error { Request; Native; Admission; Limit; Deadline; }
pub enum ProjectOpen { Input; Limit; Allocation; }

pub fn Result<Root,ProjectOpen> open_project(ref u8[] path,ref mut u8[] data){
    var usize used=0;var u32 status=0;
    let ptr mut void owner=unsafe{bc_asl_open_project(path as ptr u8,path.len,data as ptr mut u8,
        data.len,ref mut used as ptr mut usize,ref mut status as ptr mut u32)};
    if(owner==null){
        return .err(if(status==3){.Limit}else if(status==9){.Allocation}else{.Input});
    }
    assert(used<=data.len);
    return .ok(Root{.owner=owner,.manifest_bytes=used});
}
pub fn usize manifest_bytes(ref Root root){return root.manifest_bytes;}

// Packed names use exclusive end offsets. Validate before opening the root.
fn bool valid(ref u8[] names,ref usize[] ends,usize source_bytes,usize name_bytes){
    if(ends.len==0 || ends.len>16 || names.len>3840 || source_bytes>4096 || name_bytes>4096){return false;}
    var usize begin=0;var usize i=0;
    while(i<ends.len){
        if(ends[i]<=begin || ends[i]>names.len || ends[i]-begin>240){return false;}
        begin=ends[i];i+=1;
    }
    return begin==names.len;
}
pub fn Result<sources::Snapshot,Error> load(ref u8[] root,ref u8[] names,ref usize[] ends,
                                           usize source_bytes,usize name_bytes){
    return load_until(root,names,ends,source_bytes,name_bytes,0);
}
pub fn Result<sources::Snapshot,Error> load_until(ref u8[] root,ref u8[] names,ref usize[] ends,
                                                 usize source_bytes,usize name_bytes,usize deadline){
    if(!valid(names,ends,source_bytes,name_bytes)){return .err(.Request);}
    let ptr mut void address=unsafe {bc_asl_open(root as ptr u8,root.len)};
    if(address==null){return .err(.Native);}
    var Root owner=Root{.owner=address,.manifest_bytes=0};
    return collect(ref mut owner,names,ends,source_bytes,name_bytes,deadline);
}
pub fn Result<sources::Snapshot,Error> load_from(ref mut Root owner,ref u8[] names,ref usize[] ends,
                                                usize source_bytes,usize name_bytes){
    return load_from_until(owner,names,ends,source_bytes,name_bytes,0);
}
pub fn Result<sources::Snapshot,Error> load_from_until(ref mut Root owner,ref u8[] names,ref usize[] ends,
                                                      usize source_bytes,usize name_bytes,usize deadline){
    if(!valid(names,ends,source_bytes,name_bytes)){return .err(.Request);}
    return collect(owner,names,ends,source_bytes,name_bytes,deadline);
}
fn Result<sources::Snapshot,Error> collect(ref mut Root owner,ref u8[] names,ref usize[] ends,
                                          usize source_bytes,usize name_bytes,usize deadline){
    var usize begin=0;var usize i=0;
    while(i<ends.len){
        let ref u8[] name=names[begin..ends[i]];
        if(unsafe {bc_asl_member(owner.owner,name as ptr u8,name.len)}!=0){return .err(.Native);}
        begin=ends[i];i+=1;
    }
    let u32 status=unsafe {bc_asl_collect_until(owner.owner,source_bytes,deadline)};
    if(status!=0){return .err(if(status==3){.Limit}else if(status==11){.Deadline}else{.Native});}
    return copy_collected(owner,ends.len,source_bytes,name_bytes);
}

// Copies the bounded, already acquired bytes for source diagnostics.
pub fn Result<sources::Snapshot,Error> copy_collected(ref Root owner,usize count,usize source_bytes,usize name_bytes){
    if(count==0 || count>sources::file_limit()){return .err(.Request);}
    var sources::Builder builder=switch(sources::builder(source_bytes,name_bytes)){
        case .ok(v):{v}case .err(_):{return .err(.Admission);}
    };
    var u8[240] name=[0;240];var u8[4096] data=[0;4096];var usize i=0;
    while(i<count){
        let usize nl=unsafe {bc_asl_copy(owner.owner,i,0,ref mut name[..] as ptr mut u8,240)};
        let usize dl=unsafe {bc_asl_copy(owner.owner,i,1,ref mut data[..] as ptr mut u8,4096)};
        if(nl==0 || nl>240 || dl>4096){return .err(.Native);}
        if(!sources::add(ref mut builder,ref name[..nl],ref data[..dl]).is_ok){return .err(.Admission);}
        i+=1;
    }
    return switch(sources::freeze(ref builder)){
        case .ok(v):{.ok(v)}case .err(_):{.err(.Admission)}
    };
}
