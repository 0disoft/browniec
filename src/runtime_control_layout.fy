module runtime_control_layout;
import runtime_control_budget as control;

// Typed native sizeof facts only. All quota/growth arithmetic stays in Fairy.
@link_name("bc_runtime_engine_control_layout")
unsafe extern C fn usize layout_raw(u32 kind);
pub fn usize capacity(usize count){
    if(count==0 || count>64){return 0;}
    var usize n=8;while(n<count){n*=2;}return n;
}
fn Result<usize,control::Error> add(usize total,usize size,usize count){
    let usize maximum=18446744073709551615;
    if(size==0 || count==0){return .err(.Invalid);}
    if(size>maximum/count){return .err(.Quota);}
    let usize bytes=size*count;
    if(bytes>maximum-total){return .err(.Quota);}return .ok(total+bytes);
}
pub fn Result<usize,control::Error> required(usize programs,usize instances){
    let usize p=capacity(programs);let usize i=capacity(instances);
    if(p==0 || i==0){return .err(.Invalid);}
    var usize bytes=unsafe{layout_raw(0)};
    if(bytes==0){return .err(.Invalid);}
    bytes=add(bytes,unsafe{layout_raw(1)},2*p)?;
    bytes=add(bytes,unsafe{layout_raw(2)},i)?;
    bytes=add(bytes,unsafe{layout_raw(3)},2*i)?;
    bytes=add(bytes,unsafe{layout_raw(4)},2*i)?;
    bytes=add(bytes,unsafe{layout_raw(5)},capacity(1))?;
    bytes=add(bytes,unsafe{layout_raw(6)},capacity(1))?;
    return .ok(bytes);
}
