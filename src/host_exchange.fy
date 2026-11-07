module host_exchange;
import host_catalog as catalog;
import host_wire as wire;
import std::bytes as bytes;
import std::num as num;

// Internal native coordinator, not a VM Instance, opcode or public ABI.
// Phase: 0 Ready, 1 Waiting, 2 Install, 3 Terminal.
// Cause: 0 None, 1 Cancelled, 2 Deadline, 3 HostFailure, 4 Quota, 5 Fuel, 6 Identity.
pub enum Error { State; Identity; Catalog; Denied; Malformed; Allocation; Terminated; }
pub struct Limits {
    usize request_bytes; usize reply_bytes; usize requests_total; usize replies_total;
    usize calls; usize adapter_per_call; usize adapter_total;
}
// Detached observations carry no authority and cannot mutate a live exchange.
pub struct Observation {
    u8 phase; u8 cause; usize run; usize request; usize import_id;
    usize calls; usize requests; usize replies; usize adapter; usize fuel;
    usize terminal_at; bool external_effects_unknown;
}
pub struct Binding { u32[8] words; }
struct Grants { bool[64] allowed; }
pub resource Exchange {
    bytes::Buffer backing;
    bytes::Buffer header; ptr mut u8 header_data;
    catalog::Catalog catalog; Binding digest; Grants grants; Limits limits;
    usize deadline;
    cleanup { }
}
pub resource Output {
    bytes::Buffer backing; wire::Field value; u8 kind;
    usize run; usize request;
    cleanup { }
}
// Pinned Windows x64 Buffer layout: four pointer-width cells. The compiler
// cannot mutate/project owning resource fields. One leading Buffer owns either
// the waiting request or committed reply. Metadata moves only, never payload.
@link_name("fy_std_buffer_reserve_v0")
unsafe extern C fn u32 validate_buffer_raw(ptr mut void buffer,usize capacity);
fn bytes::Buffer replace_buffer(ref mut Exchange e,bytes::Buffer prepared){
    var bytes::Buffer incoming=prepared;var bytes::Buffer old=bytes::empty();
    let ptr mut void from=unsafe { ref mut incoming as ptr mut void };
    let ptr mut void to=unsafe { ref mut old as ptr mut void };
    let ref mut u8[] source=unsafe { byte_slice::from_raw_parts_mut(ref mut incoming,from,32) };
    let ref mut u8[] target=unsafe { byte_slice::from_raw_parts_mut(e,e as ptr mut void,32) };
    let ref mut u8[] removed=unsafe { byte_slice::from_raw_parts_mut(ref mut old,to,32) };
    var usize i=0;while(i<32){removed[i]=target[i];target[i]=source[i];source[i]=0;i+=1;}
    // Explicit SDK companion calls make all raw metadata writes observable to
    // the pinned optimizer before whole-resource moves or automatic cleanup.
    // reserve(0) validates only: no allocation, growth, copy or guest Fuel.
    assert(unsafe {validate_buffer_raw(e as ptr mut void,0)}==0);
    assert(bytes::reserve(ref mut incoming,0).is_ok);
    assert(bytes::reserve(ref mut old,0).is_ok);
    return old;
}
fn usize read(ref u8[] data,usize at){
    var usize result=0;var usize i=8;
    while(i>0){i-=1;result=result*256+data[at+i] as usize;}return result;
}
fn void write(ref mut u8[] data,usize at,usize n){
    var usize value=n;var usize i=0;
    while(i<8){
        let i64 digit=switch(num::i64_from_usize(value%256)){case .ok(v):{v}case .err(_):{assert(false);0}};
        data[at+i]=switch(num::u8_from_i64(digit)){case .ok(v):{v}case .err(_):{assert(false);0}};
        value/=256;i+=1;
    }
}
fn Observation state(ref Exchange e){
    let ref u8[] h=bytes::view(ref e.header);
    return Observation{.phase=h[0],.cause=h[1],.external_effects_unknown=h[2]!=0,
        .run=read(h,8),.request=read(h,16),.import_id=read(h,24),.calls=read(h,32),
        .requests=read(h,40),.replies=read(h,48),.adapter=read(h,56),.fuel=read(h,64),.terminal_at=read(h,72)};
}
fn void save(ref mut Exchange e,Observation s){
    // Pointer is captured only from the owned, fixed-length header at creation;
    // the header never grows/moves/reallocates while Exchange is alive.
    let ref mut u8[] h=unsafe { byte_slice::from_raw_parts_mut(e,e.header_data,80) };
    h[0]=s.phase;h[1]=s.cause;h[2]=if(s.external_effects_unknown){1}else{0};
    write(h,8,s.run);write(h,16,s.request);write(h,24,s.import_id);write(h,32,s.calls);
    write(h,40,s.requests);write(h,48,s.replies);write(h,56,s.adapter);write(h,64,s.fuel);write(h,72,s.terminal_at);
}
fn bool valid(Limits l){return l.request_bytes<=wire::payload_limit() && l.reply_bytes<=wire::payload_limit();}

// Consumes the admitted immutable catalog. Grants are explicit host decisions,
// never inferred from effect/capability metadata. run must be unique in its owner.
// Fuel charges below are supplied by the integrating native owner, not new prices.
pub fn Result<Exchange,Error> create(catalog::Catalog c,ref bool[] allowed,Limits limits,
    usize run,usize fuel,usize deadline){
    if(run==0){return .err(.Identity);}
    if(!valid(limits) || allowed.len!=catalog::count(ref c)){return .err(.Catalog);}
    var Grants grants=Grants{.allowed=[false;64]};var usize i=0;
    while(i<allowed.len){grants.allowed[i]=allowed[i];i+=1;}
    let u32[8] digest=switch(catalog::digest(ref c)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    var bytes::Buffer header=switch(bytes::with_capacity(80)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    let usize sized=switch(bytes::resize_zeroed(ref mut header,80)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    let ptr mut u8 address=unsafe { bytes::view_mut(ref mut header) as ptr mut u8 };
    var Exchange e=Exchange{.catalog=c,.digest=Binding{.words=digest},.grants=grants,.limits=limits,
        .deadline=deadline,.backing=bytes::empty(),.header=header,.header_data=address};
    save(ref mut e,Observation{.phase=0,.cause=0,.run=run,.request=0,.import_id=0,
        .calls=0,.requests=0,.replies=0,.adapter=0,.fuel=fuel,.terminal_at=0,.external_effects_unknown=false});
    return .ok(e);
}
pub fn Observation observe(ref Exchange e){return state(e);}
pub fn ref catalog::Catalog bound_catalog(ref Exchange e){return ref e.catalog;}
pub fn Binding binding(ref Exchange e){return e.digest;}
fn void terminate(ref mut Exchange e,u8 cause,usize now){
    if(state(e).phase==3){return;}
    var Observation s=state(e);s.phase=3;s.cause=cause;s.terminal_at=now;
    s.external_effects_unknown=s.calls!=0;save(e,s);
    let bytes::Buffer discarded=replace_buffer(e,bytes::empty());
}
// Owner supplies a monotonic timestamp and sampled cancellation. No OS timer,
// callback, guest execution or hidden work happens here. Terminal polls freeze.
pub fn Observation poll(ref mut Exchange e,usize now,bool cancelled){
    if(state(e).phase!=3){
        if(cancelled){terminate(e,1,now);}
        else if(e.deadline!=0 && now>=e.deadline){terminate(e,2,now);}
    }return state(e);
}
fn Result<usize,Error> checkpoint(ref mut Exchange e,usize now,bool cancelled){
    let Observation s=poll(e,now,cancelled);
    if(s.phase==3){return .err(.Terminated);}return .ok(0);
}
fn Result<usize,Error> stop(ref mut Exchange e,u8 cause,usize now){
    terminate(e,cause,now);return .err(.Terminated);
}
fn bool fits(usize used,usize extra,usize limit){return used<=limit && extra<=limit-used;}
fn Result<bytes::Buffer,Error> snapshot(ref u8[] input){
    // with_capacity prepares the entire bounded allocation. append cannot grow.
    // An SDK failure still drops only unpublished storage, retaining all state.
    var bytes::Buffer out=switch(bytes::with_capacity(input.len)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    let usize copied=switch(bytes::append(ref mut out,input)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };return .ok(out);
}
// Request bytes already use the real typed wire codec; descriptors are rebuilt
// against this exact envelope and live only with the owned immutable snapshot.
pub fn Result<usize,Error> begin(ref mut Exchange e,usize import_id,ref u8[] payload,
    usize snapshot_fuel,usize adapter_cost,usize now,bool cancelled){
    let usize checked=checkpoint(e,now,cancelled)?;
    if(state(e).phase!=0){return .err(.State);}
    if(import_id>=catalog::count(bound_catalog(e))){return .err(.Catalog);}
    if(!e.grants.allowed[import_id]){return .err(.Denied);}
    let usize argc=switch(catalog::parameter_count(bound_catalog(e),import_id)){
        case .ok(v):{v}case .err(_):{return .err(.Catalog);}
    };
    var u8[32] tags=[0;32];var usize i=0;
    while(i<argc){tags[i]=switch(catalog::parameter_tag(bound_catalog(e),import_id,i)){
        case .ok(v):{v}case .err(_):{return .err(.Catalog);}
    };i+=1;}
    // Per-message hard limit checked independently of the codec and before copy.
    if(payload.len>e.limits.request_bytes){return stop(e,4,now);}
    let wire::Request arguments=switch(wire::decode_request(payload,ref tags[..argc],e.limits.request_bytes)){
        case .ok(v):{v}case .err(_):{return .err(.Malformed);}
    };
    let u8 result=switch(catalog::result_tag(bound_catalog(e),import_id)){
        case .ok(v):{v}case .err(_):{return .err(.Catalog);}
    };
    if(state(e).request==18446744073709551615){return stop(e,6,now);}
    if(state(e).calls>=e.limits.calls || !fits(state(e).requests,payload.len,e.limits.requests_total) ||
        adapter_cost>e.limits.adapter_per_call || !fits(state(e).adapter,adapter_cost,e.limits.adapter_total)){
        return stop(e,4,now);
    }
    if(snapshot_fuel>state(e).fuel){return stop(e,5,now);}
    let bytes::Buffer prepared=snapshot(payload)?;
    // No fallible operation after publication. This synchronous transaction
    // charges once at publication, not resumable copy/step accounting.
    var Observation s=state(e);s.import_id=import_id;s.request+=1;s.calls+=1;
    s.requests+=payload.len;s.adapter+=adapter_cost;s.fuel-=snapshot_fuel;s.phase=1;
    let bytes::Buffer old=replace_buffer(e,prepared);save(e,s);
    return .ok(state(e).request);
}
pub fn Result<ref u8[],Error> request_bytes(ref Exchange e){
    if(state(e).phase!=1){return .err(.State);}return .ok(bytes::view(ref e.backing));
}
pub fn Result<wire::Request,Error> request_fields(ref Exchange e){
    if(state(e).phase!=1){return .err(.State);}let Observation s=state(e);let ref catalog::Catalog c=bound_catalog(e);
    let usize argc=switch(catalog::parameter_count(c,s.import_id)){case .ok(v):{v}case .err(_):{return .err(.Catalog);}};
    var u8[32] tags=[0;32];var usize i=0;
    while(i<argc){tags[i]=switch(catalog::parameter_tag(c,s.import_id,i)){case .ok(v):{v}case .err(_):{return .err(.Catalog);}};i+=1;}
    return switch(wire::decode_request(bytes::view(ref e.backing),ref tags[..argc],e.limits.request_bytes)){
        case .ok(v):{.ok(v)}case .err(_):{.err(.Malformed)}
    };
}
// Checkpoint precedes state/identity/shape. Invalid or preparation-failed replies
// retain the exact request backing, Fuel and counters. No adapter is invoked.
pub fn Result<usize,Error> reply(ref mut Exchange e,usize run,usize request,u8 kind,
    ref u8[] payload,usize snapshot_fuel,usize now,bool cancelled){
    let usize checked=checkpoint(e,now,cancelled)?;
    if(state(e).phase!=1){return .err(.State);}
    if(run!=state(e).run || request!=state(e).request){return .err(.Identity);}
    if(payload.len>wire::payload_limit()){return stop(e,4,now);}
    // A syntactically valid reply exceeding a reduced policy is terminal. The
    // hard wire ceiling rejects metadata before trusting any payload length.
    let wire::Field value=switch(wire::decode_reply(kind,result_tag(e),payload,wire::payload_limit())){
        case .ok(v):{v}case .err(_):{return .err(.Malformed);}
    };
    if(payload.len>e.limits.reply_bytes || !fits(state(e).replies,payload.len,e.limits.replies_total)){
        return stop(e,4,now);
    }
    if(snapshot_fuel>state(e).fuel){return stop(e,5,now);}
    // All nonfatal replies retain a single exact TLV snapshot. Output borrows
    // only its checked payload range; scalar and empty headers are also owned.
    let bytes::Buffer prepared=snapshot(payload)?;
    var Observation s=state(e);s.replies+=payload.len;s.fuel-=snapshot_fuel;s.phase=2;
    let bytes::Buffer old=replace_buffer(e,prepared);
    save(e,s);
    // Reply kind is in the unused fixed header byte, with identical authority.
    let ref mut u8[] h=unsafe { byte_slice::from_raw_parts_mut(e,e.header_data,80) };h[3]=kind;
    if(kind==2){terminate(e,3,now);}
    return .ok(request);
}
fn u8 result_tag(ref Exchange e){
    return switch(catalog::result_tag(bound_catalog(e),state(e).import_id)){
        case .ok(v):{v}case .err(_):{assert(false);0}
    };
}
fn u8 reply_kind(ref Exchange e){return bytes::view(ref e.header)[3];}
fn ref u8[] reply_bytes(ref Exchange e){return bytes::view(ref e.backing);}
// Actual native ownership handoff only. Integrator must install the typed Result
// in its independently validated destination; this function dispatches no VM IR.
pub fn Result<Output,Error> take_reply(ref mut Exchange e,usize now,bool cancelled){
    let usize checked=checkpoint(e,now,cancelled)?;
    if(state(e).phase!=2){return .err(.State);}
    let u8 kind=reply_kind(e);
    let wire::Field value=switch(wire::decode_reply(kind,result_tag(e),reply_bytes(e),e.limits.reply_bytes)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    let bytes::Buffer backing=replace_buffer(e,bytes::empty());
    var Observation s=state(e);s.phase=0;save(e,s);
    return .ok(Output{.backing=backing,.value=value,.kind=kind,.run=state(e).run,.request=state(e).request});
}
pub fn wire::Field output_field(ref Output o){return o.value;}
pub fn u8 output_kind(ref Output o){return o.kind;}
pub fn usize output_run(ref Output o){return o.run;}
pub fn usize output_request(ref Output o){return o.request;}
pub fn ref u8[] output_bytes(ref Output o){
    let ref u8[] all=bytes::view(ref o.backing);
    if(o.value.tag!=7 || o.value.length==0){return all[..0];}
    return all[o.value.start..o.value.start+o.value.length];
}

