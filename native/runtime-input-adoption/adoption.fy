module runtime_input_adoption;
import runtime_input as input;

// Private synchronous Windows transport, not guest authority or public ABI.
unsafe extern C fn ptr mut void bc_ria_read_handle(usize handle,usize limit,ptr mut u32 status,ptr mut u32 os);
unsafe extern C fn ptr mut void bc_ria_read_path(ptr u8 path,usize length,usize limit,ptr mut u32 status,ptr mut u32 os);
unsafe extern C fn usize bc_ria_length(ptr mut void owner);
unsafe extern C fn ptr u8 bc_ria_bytes(ptr mut void owner);
unsafe extern C fn void bc_ria_close(ptr mut void owner);
resource Native { ptr mut void owner; cleanup { unsafe {bc_ria_close(this.owner)}; } }
pub enum Error { Limit; Fuel; Allocation; Native; }
pub struct Failure { Error kind; u32 reader; u32 os; }
fn Failure failure(Error kind,u32 reader,u32 os){return Failure{.kind=kind,.reader=reader,.os=os};}
fn Result<bool,Failure> admit(usize limit,usize charge,usize fuel){
    if(limit>input::hard_limit()){return .err(failure(.Limit,0,0));}
    if(charge>fuel){return .err(failure(.Fuel,0,0));}return .ok(true);
}
fn Failure rejected(u32 status,u32 os){
    return failure(if(status==2){.Limit}else{if(status==5){.Allocation}else{.Native}},status,os);
}
// A real SDK allocation and exact payload copy; never reinterpret native owner
// memory as Snapshot/Buffer. The temporary native owner drops on every return.
fn Result<input::Snapshot,Failure> finish(Native owner,usize limit,usize charge,ref mut usize fuel){
    let usize length=unsafe{bc_ria_length(owner.owner)};
    let ptr u8 data=unsafe{bc_ria_bytes(owner.owner)};
    let ref u8[] view=unsafe{byte_slice::from_raw_parts(ref owner,data,length)};
    return switch(input::snapshot(view,limit,charge,fuel)){
        case .ok(v):{.ok(v)}
        case .err(e):{.err(failure(switch(e){case .Limit:{.Limit}case .Fuel:{.Fuel}case .Allocation:{.Allocation}case .Bounds:{.Native}},0,0))}
    };
}
pub fn Result<input::Snapshot,Failure> handle(usize handle,usize limit,usize charge,ref mut usize fuel){
    switch(admit(limit,charge,*fuel)){case .ok(_):{}case .err(e):{return .err(e);}};
    var u32 status=0;var u32 os=0;
    let ptr mut void address=unsafe{bc_ria_read_handle(handle,limit,ref mut status as ptr mut u32,ref mut os as ptr mut u32)};
    if(address==null){return .err(rejected(status,os));}
    return finish(Native{.owner=address},limit,charge,fuel);
}
// Exact UTF16LE bytes, without a terminator; odd lengths are rejected natively.
pub fn Result<input::Snapshot,Failure> path_utf16le(ref u8[] path,usize limit,usize charge,ref mut usize fuel){
    switch(admit(limit,charge,*fuel)){case .ok(_):{}case .err(e):{return .err(e);}};
    var u32 status=0;var u32 os=0;
    let ptr mut void address=unsafe{bc_ria_read_path(path as ptr u8,path.len,limit,ref mut status as ptr mut u32,ref mut os as ptr mut u32)};
    if(address==null){return .err(rejected(status,os));}
    return finish(Native{.owner=address},limit,charge,fuel);
}
