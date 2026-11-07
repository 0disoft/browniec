module anchored_source_loader;
import source_snapshot as sources;

// Private native adapter. None of these FFI symbols belong to the public CLI.
unsafe extern C fn ptr mut void bc_asl_open(ptr u8 root,usize length);
unsafe extern C fn u32 bc_asl_member(ptr mut void owner,ptr u8 name,usize length);
unsafe extern C fn u32 bc_asl_collect(ptr mut void owner,usize source_bytes);
unsafe extern C fn usize bc_asl_copy(ptr mut void owner,usize index,u32 part,ptr mut u8 out,usize capacity);
unsafe extern C fn void bc_asl_close(ptr mut void owner);
resource Native { ptr mut void owner; cleanup { unsafe {bc_asl_close(this.owner)}; } }
pub enum Error { Request; Native; Admission; }

// Members are packed exact names and exclusive end offsets, not a delimited
// language. Validate every span before opening the explicit UTF-8 root.
// Both result ownership and native cleanup are independent of caller buffers.
pub fn Result<sources::Snapshot,Error> load(ref u8[] root,ref u8[] names,ref usize[] ends,
                                           usize source_bytes,usize name_bytes){
    if(ends.len==0 || ends.len>16 || names.len>3840 || source_bytes>4096 || name_bytes>4096){return .err(.Request);}
    var usize begin=0;var usize i=0;
    while(i<ends.len){
        if(ends[i]<=begin || ends[i]>names.len || ends[i]-begin>240){return .err(.Request);}
        begin=ends[i];i+=1;
    }
    if(begin!=names.len){return .err(.Request);}
    let ptr mut void address=unsafe {bc_asl_open(root as ptr u8,root.len)};
    if(address==null){return .err(.Native);}
    let Native owner=Native{.owner=address};begin=0;i=0;
    while(i<ends.len){
        let ref u8[] name=names[begin..ends[i]];
        if(unsafe {bc_asl_member(owner.owner,name as ptr u8,name.len)}!=0){return .err(.Native);}
        begin=ends[i];i+=1;
    }
    if(unsafe {bc_asl_collect(owner.owner,source_bytes)}!=0){return .err(.Native);}
    var sources::Builder builder=switch(sources::builder(source_bytes,name_bytes)){
        case .ok(v):{v}case .err(_):{return .err(.Admission);}
    };
    var u8[240] name=[0;240];var u8[4096] data=[0;4096];i=0;
    while(i<ends.len){
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
