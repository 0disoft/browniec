module runtime_output;
import std::bytes as bytes;
import std::num as num;
import fuel as prices;

// Native staging only. Nothing here decides VM success or writes to a sink.
// Phase: 0 Open, 1 Sealed, 2 Failed, 3 Cancelled, 4 Disabled. First terminal state freezes.
pub enum Error { State; Denied; Limit; Fuel; Allocation; }
pub struct Observation { u8 phase; usize length; usize emits; usize fuel; usize charged; }
pub resource Transaction {
    bytes::Buffer backing;
    bytes::Buffer header; ptr mut u8 header_data;
    usize limit; bool allowed;
    bool reserved;
    usize pending; usize copied; bool copying;
    cleanup { }
}
pub resource Published { bytes::Buffer backing; Observation final; cleanup { } }
pub fn usize hard_limit(){return 1048576;}
// Allocation-free sink placeholder for unchanged legacy invocation paths.
pub fn Transaction disabled(){
    return Transaction{.backing=bytes::empty(),.header=bytes::empty(),.header_data=null,
        .limit=0,.allowed=false,.reserved=false,.pending=0,.copied=0,.copying=false};
}

// Same pinned-Windows-x64 ownership seam as host_exchange. Buffer is exactly
// four pointer-width cells. Executed generated-C guards own this assumption.
@link_name("fy_std_buffer_reserve_v0")
unsafe extern C fn u32 validate_buffer_raw(ptr mut void buffer,usize capacity);
@link_name("fy_std_buffer_append_v0")
unsafe extern C fn u32 append_buffer_raw(ptr mut void buffer,ptr u8 data,usize length);
fn bytes::Buffer replace(ref mut Transaction t,bytes::Buffer prepared){
    var bytes::Buffer incoming=prepared;var bytes::Buffer old=bytes::empty();
    let ptr mut void from=unsafe {ref mut incoming as ptr mut void};
    let ptr mut void to=unsafe {ref mut old as ptr mut void};
    let ref mut u8[] source=unsafe {byte_slice::from_raw_parts_mut(ref mut incoming,from,32)};
    let ref mut u8[] target=unsafe {byte_slice::from_raw_parts_mut(t,t as ptr mut void,32)};
    let ref mut u8[] removed=unsafe {byte_slice::from_raw_parts_mut(ref mut old,to,32)};
    var usize i=0;while(i<32){removed[i]=target[i];target[i]=source[i];source[i]=0;i+=1;}
    // Required native visibility/ownership barriers before whole-value moves and
    // cleanup. reserve(0) only validates; no allocation, copy, growth or charge.
    assert(unsafe {validate_buffer_raw(t as ptr mut void,0)}==0);
    assert(bytes::reserve(ref mut incoming,0).is_ok);
    assert(bytes::reserve(ref mut old,0).is_ok);
    return old;
}
fn usize read(ref u8[] data,usize at){
    var usize n=0;var usize i=8;while(i>0){i-=1;n=n*256+data[at+i] as usize;}return n;
}
fn void write(ref mut u8[] data,usize at,usize value){
    var usize n=value;var usize i=0;while(i<8){
        let i64 digit=switch(num::i64_from_usize(n%256)){case .ok(v):{v}case .err(_):{assert(false);0}};
        data[at+i]=switch(num::u8_from_i64(digit)){case .ok(v):{v}case .err(_):{assert(false);0}};
        n/=256;i+=1;
    }
}
pub fn Observation observe(ref Transaction t){
    if(t.header_data==null){return Observation{.phase=4,.length=0,.emits=0,.fuel=0,.charged=0};}
    let ref u8[] h=bytes::view(ref t.header);
    return Observation{.phase=h[0],.length=read(h,8),.emits=read(h,16),.fuel=read(h,24),.charged=read(h,32)};
}
fn void save(ref mut Transaction t,Observation s){
    // Captured from the owned fixed header, which never moves/reallocates its
    // allocation. Raw storage and mutable pointers never escape this module.
    let ref mut u8[] h=unsafe {byte_slice::from_raw_parts_mut(t,t.header_data,40)};
    h[0]=s.phase;write(h,8,s.length);write(h,16,s.emits);write(h,24,s.fuel);write(h,32,s.charged);
}
pub fn Result<Transaction,Error> open(usize limit,bool allowed,usize fuel){
    if(limit>hard_limit()){return .err(.Limit);}
    var bytes::Buffer header=switch(bytes::with_capacity(40)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    let usize resized=switch(bytes::resize_zeroed(ref mut header,40)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    let ptr mut u8 data=unsafe {bytes::view_mut(ref mut header) as ptr mut u8};
    var Transaction t=Transaction{.backing=bytes::empty(),.header=header,.header_data=data,.limit=limit,.allowed=allowed,
        .reserved=false,.pending=0,.copied=0,.copying=false};
    save(ref mut t,Observation{.phase=0,.length=0,.emits=0,.fuel=fuel,.charged=0});return .ok(t);
}
fn ref u8[] staged(ref Transaction t){return bytes::view(ref t.backing);}
fn Result<bytes::Buffer,Error> prepare(ref Transaction t,ref u8[] data,usize total){
    var bytes::Buffer next=switch(bytes::with_capacity(total)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    let usize prefix=switch(bytes::append(ref mut next,staged(t))){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    let usize suffix=switch(bytes::append(ref mut next,data)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };return .ok(next);
}
// Each nonempty append prepares the complete new prefix+suffix off to the side.
// Quotas/Fuel/checked sums precede allocation; no fallible publication follows.
// Cost is supplied by the trusted owner and must account for actual copied bytes.
pub fn Result<usize,Error> emit(ref mut Transaction t,ref u8[] data,usize charge){
    var Observation s=observe(t);
    if(s.phase!=0 || t.reserved){return .err(.State);}if(!t.allowed){return .err(.Denied);}
    if(s.length>t.limit || data.len>t.limit-s.length || s.emits==18446744073709551615){return .err(.Limit);}
    if(charge>s.fuel){return .err(.Fuel);}
    let usize total=s.length+data.len;
    if(data.len!=0){
        let bytes::Buffer next=prepare(t,data,total)?;
        let bytes::Buffer old=replace(t,next);
    }
    // charged+fuel equals the initial supplied Fuel, so this addition cannot wrap.
    s.length=total;s.emits+=1;s.fuel-=charge;s.charged+=charge;save(t,s);return .ok(total);
}
// Caller must already have decided success. This explicit native owner operation
// is not a guest-visible authority or a proof that any VM/Instance succeeded.
pub fn Result<Published,Error> seal(ref mut Transaction t,usize charge){
    var Observation s=observe(t);if(s.phase!=0 || t.reserved){return .err(.State);}
    if(charge>s.fuel){return .err(.Fuel);}
    s.fuel-=charge;s.charged+=charge;s.phase=1;
    let bytes::Buffer backing=replace(t,bytes::empty());save(t,s);
    return .ok(Published{.backing=backing,.final=s});
}
fn Observation discard_pending(ref mut Transaction t,u8 phase){
    var Observation s=observe(t);if(s.phase!=0){return s;}
    let bytes::Buffer dropped=replace(t,bytes::empty());
    t.pending=0;t.copied=0;t.copying=false;s.phase=phase;s.length=0;save(t,s);return s;
}
pub fn Observation fail(ref mut Transaction t){return discard_pending(t,2);}
pub fn Observation cancel(ref mut Transaction t){return discard_pending(t,3);}
pub fn Observation published_observation(ref Published output){return output.final;}
pub fn ref u8[] view(ref Published output){return bytes::view(ref output.backing);}

// Actual owned SDK bytes, excluding the inline resource and allocator overhead.
// A reserved backing remains owned even when the logical output is empty.
pub fn usize published_heap_bytes(ref Published output){return bytes::capacity(ref output.backing);}
pub fn usize transaction_heap_bytes(ref Transaction t){
    return bytes::capacity(ref t.header)+bytes::capacity(ref t.backing);
}

// Shared-Fuel reserved mode. No guest/host staging view or publication authority
// is added: only the trusted VM owner may choose success and call seal_metered.
// Each open operation samples caller Fuel; terminal snapshots freeze first.
pub fn Result<Transaction,Error> open_metered(usize limit,bool allowed,ref mut usize remaining){
    if(limit>hard_limit()){return .err(.Limit);}
    let usize charge=prices::output_prepare(limit);
    if(charge>*remaining){return .err(.Fuel);}
    var Transaction t=open(limit,allowed,*remaining)?;
    let bytes::Buffer prepared=switch(bytes::with_capacity(limit)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    let bytes::Buffer old=replace(ref mut t,prepared);
    t.reserved=true;*remaining-=charge;
    save(ref mut t,Observation{.phase=0,.length=0,.emits=0,.fuel=*remaining,.charged=charge});
    return .ok(t);
}
fn Result<Observation,Error> sample_metered(ref mut Transaction t,usize remaining){
    var Observation s=observe(t);
    if(s.phase!=0 || !t.reserved || t.copying){return .err(.State);}
    s.fuel=remaining;save(t,s);return .ok(s);
}
// Prepay the whole emit before any source bytes are copied. The returned total
// is prospective until the last chunk; observations expose only committed bytes.
pub fn Result<usize,Error> begin_emit_metered(ref mut Transaction t,usize length,ref mut usize remaining){
    var Observation s=sample_metered(t,*remaining)?;
    if(!t.allowed){return .err(.Denied);}
    if(s.length>t.limit || length>t.limit-s.length || s.emits==18446744073709551615){return .err(.Limit);}
    let usize charge=prices::output_emit(length);
    if(charge>*remaining || charge>18446744073709551615-s.charged){return .err(.Fuel);};
    *remaining-=charge;s.fuel=*remaining;s.charged+=charge;
    if(length==0){s.emits+=1;}else{t.pending=length;t.copied=0;t.copying=true;}
    save(t,s);return .ok(s.length+length);
}
pub fn usize emit_remaining(ref Transaction t){
    return if(t.copying){t.pending-t.copied}else{0};
}
fn bool chunk_backing(ref Transaction t,usize committed){
    return bytes::view(ref t.backing).len==committed+t.copied &&
        bytes::capacity(ref t.backing)>=committed+t.pending;
}
// Only the already-reserved owning Buffer is touched. Invalid chunks leave both
// physical and logical state intact; no allocation or additional Fuel is needed.
pub fn Result<bool,Error> append_emit_chunk(ref mut Transaction t,ref u8[] data){
    var Observation s=observe(t);
    if(s.phase!=0 || !t.reserved || !t.copying || t.copied>=t.pending){return .err(.State);}
    if(data.len==0 || data.len>4096 || data.len>t.pending-t.copied){return .err(.Limit);}
    if(s.length>t.limit || t.pending>t.limit-s.length){return .err(.State);}
    if(!chunk_backing(t,s.length)){return .err(.State);}
    let u32 status=unsafe {append_buffer_raw(t as ptr mut void,data as ptr u8,data.len)};
    assert(status==0);
    assert(unsafe {validate_buffer_raw(t as ptr mut void,0)}==0);
    t.copied+=data.len;
    if(t.copied!=t.pending){return .ok(false);}
    s.length+=t.pending;s.emits+=1;save(t,s);
    t.pending=0;t.copied=0;t.copying=false;return .ok(true);
}
pub fn Result<usize,Error> emit_metered(ref mut Transaction t,ref u8[] data,ref mut usize remaining){
    var Observation s=sample_metered(t,*remaining)?;
    if(!t.allowed){return .err(.Denied);}
    if(s.length>t.limit || data.len>t.limit-s.length || s.emits==18446744073709551615){return .err(.Limit);}
    let usize charge=prices::output_emit(data.len);
    if(charge>*remaining || charge>18446744073709551615-s.charged){return .err(.Fuel);}
    // The first 32 bytes are the actual owning Buffer, not a forged descriptor.
    // open reserved all capacity; SDK append cannot allocate or recopy prefix.
    // Extern calls retain the same /O2 visibility barrier as ownership replace.
    if(data.len!=0){
        let u32 status=unsafe {append_buffer_raw(t as ptr mut void,data as ptr u8,data.len)};
        assert(status==0);
        assert(unsafe {validate_buffer_raw(t as ptr mut void,0)}==0);
    };
    *remaining-=charge;s.length+=data.len;s.emits+=1;s.fuel=*remaining;s.charged+=charge;
    save(t,s);return .ok(s.length);
}
pub fn Result<Published,Error> seal_metered(ref mut Transaction t,ref mut usize remaining){
    var Observation s=sample_metered(t,*remaining)?;
    let usize charge=prices::output_seal();
    if(charge>*remaining || charge>18446744073709551615-s.charged){return .err(.Fuel);}
    let bytes::Buffer backing=replace(t,bytes::empty());
    *remaining-=charge;s.fuel=*remaining;s.charged+=charge;s.phase=1;save(t,s);
    return .ok(Published{.backing=backing,.final=s});
}
