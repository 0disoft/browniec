module host_exchange;
import arithmetic as arithmetic;
import host_catalog as catalog;
import host_program as programs;
import fuel as prices;
import ir as ir;
import runtime_policy as policy;
import runtime_policy_limits as policy_limits;
import runtime_run_config as runs;
import scalar_codec as scalar;
import types as types;
import host_wire as wire;
import runtime_output as output;
import std::bytes as bytes;
import std::num as num;

// Private native coordinator and scalar VM driver. No public ABI.
// Phase: 0 Ready, 1 Waiting, 2 Install, 3 Terminal, 4 Receiving.
// Cause: 0 None, 1 Cancelled, 2 Deadline, 3 HostFailure, 4 Quota, 5 Fuel, 6 Identity, 7 OutputLimit, 8 OwnerLimit.
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
    bytes::Buffer staging; ptr mut u8 staging_data;
    bytes::Buffer header; ptr mut u8 header_data;
    catalog::Catalog catalog; Binding digest; Grants grants; Limits limits;
    usize deadline; usize reply_owners_left;
    cleanup { }
}
pub resource Output {
    bytes::Buffer backing; wire::Field value; u8 kind;
    usize run; usize request;
    cleanup { }
}
// Pinned Windows x64 Buffer layout: four pointer-width cells. The compiler
// cannot mutate/project owning resource fields. The leading Buffer holds the
// wire envelope and the second owns guest output. Metadata moves only.
@link_name("fy_std_buffer_reserve_v0")
unsafe extern C fn u32 validate_buffer_raw(ptr mut void buffer,usize capacity);
@link_name("fy_std_buffer_append_v0")
unsafe extern C fn u32 append_buffer_raw(ptr mut void buffer,ptr u8 data,usize length);
fn bytes::Buffer replace_at(ref mut Exchange e,usize offset,bytes::Buffer prepared){
    var bytes::Buffer incoming=prepared;var bytes::Buffer old=bytes::empty();
    let ptr mut void from=unsafe { ref mut incoming as ptr mut void };
    let ptr mut void to=unsafe { ref mut old as ptr mut void };
    let ref mut u8[] source=unsafe { byte_slice::from_raw_parts_mut(ref mut incoming,from,32) };
    let ref mut u8[] removed=unsafe { byte_slice::from_raw_parts_mut(ref mut old,to,32) };
    let ref mut u8[] target=unsafe {byte_slice::from_raw_parts_mut(e,e as ptr mut void,64)};
    var usize i=0;while(i<32){removed[i]=target[offset+i];target[offset+i]=source[i];source[i]=0;i+=1;}
    // Explicit SDK companion calls make all raw metadata writes observable to
    // the pinned optimizer before whole-resource moves or automatic cleanup.
    // reserve(0) validates only: no allocation, growth, copy or guest Fuel.
    assert(unsafe {validate_buffer_raw(e as ptr mut void,0)}==0);
    assert(bytes::reserve(ref mut incoming,0).is_ok);
    assert(bytes::reserve(ref mut old,0).is_ok);
    return old;
}
fn bytes::Buffer replace_buffer(ref mut Exchange e,bytes::Buffer prepared){
    return replace_at(e,0,prepared);
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
    let u32[8] digest=switch(catalog::digest(ref c)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    return create_sized(c,allowed,limits,run,fuel,deadline,80,digest,bytes::empty());
}
fn Result<Exchange,Error> create_sized(catalog::Catalog c,ref bool[] allowed,Limits limits,
    usize run,usize fuel,usize deadline,usize size,u32[8] digest,bytes::Buffer output_buffer){
    var Grants grants=Grants{.allowed=[false;64]};var usize i=0;
    while(i<allowed.len){grants.allowed[i]=allowed[i];i+=1;}
    var bytes::Buffer header=switch(bytes::with_capacity(size)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    let usize sized=switch(bytes::resize_zeroed(ref mut header,size)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    let ptr mut u8 address=unsafe { bytes::view_mut(ref mut header) as ptr mut u8 };
    var bytes::Buffer staging=output_buffer;
    let ptr mut u8 staging_data=unsafe{bytes::view_mut(ref mut staging) as ptr mut u8};
    var Exchange e=Exchange{.catalog=c,.digest=Binding{.words=digest},.grants=grants,.limits=limits,
        .deadline=deadline,.reply_owners_left=0,.backing=bytes::empty(),.staging=staging,.staging_data=staging_data,
        .header=header,.header_data=address};
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
    if(is_scalar(e)){return state(e);}
    return poll_exchange(e,now,cancelled);
}
pub fn bool deadline_reached(ref Exchange e,usize now){return e.deadline!=0 && now>=e.deadline;}
pub fn usize deadline(ref Exchange e){return e.deadline;}
pub fn usize reply_limit(ref Exchange e){return e.limits.reply_bytes;}
fn Observation poll_exchange(ref mut Exchange e,usize now,bool cancelled){
    if(state(e).phase!=3){
        if(cancelled){terminate(e,1,now);}
        else if(deadline_reached(e,now)){terminate(e,2,now);}
    }return state(e);
}
fn Result<usize,Error> checkpoint(ref mut Exchange e,usize now,bool cancelled){
    let Observation s=poll_exchange(e,now,cancelled);
    if(s.phase==3){return .err(.Terminated);}return .ok(0);
}
// Debit guest instructions on the same meter that owns host publication.
fn Result<usize,Error> spend_guest(ref mut Exchange e,usize cost,usize now){
    let Observation current=state(e);
    if(current.phase!=0){return .err(.State);}
    if(current.fuel<cost){return stop(e,5,now);}
    var Observation next=current;
    next.fuel-=cost;
    save(e,next);
    return .ok(next.fuel);
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
    if(is_scalar(e)){return .err(.State);}
    return begin_exchange(e,import_id,payload,snapshot_fuel,adapter_cost,now,cancelled);
}
fn Result<usize,Error> begin_exchange(ref mut Exchange e,usize import_id,ref u8[] payload,
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
    let usize admitted=preflight_request(e,payload.len,snapshot_fuel,adapter_cost,now)?;
    let bytes::Buffer prepared=snapshot(payload)?;
    return .ok(commit_request(e,import_id,prepared,payload.len,snapshot_fuel,adapter_cost));
}
fn Result<usize,Error> preflight_request(ref mut Exchange e,usize length,usize fuel,usize adapter_cost,usize now){
    if(state(e).request==18446744073709551615){return stop(e,6,now);}
    if(length>e.limits.request_bytes || state(e).calls>=e.limits.calls || !fits(state(e).requests,length,e.limits.requests_total) ||
        adapter_cost>e.limits.adapter_per_call || !fits(state(e).adapter,adapter_cost,e.limits.adapter_total)){
        return stop(e,4,now);
    }
    if(fuel>state(e).fuel){return stop(e,5,now);}
    return .ok(length);
}
fn usize commit_request(ref mut Exchange e,usize import_id,bytes::Buffer prepared,usize length,usize fuel,usize adapter_cost){
    var Observation s=state(e);s.import_id=import_id;s.request+=1;s.calls+=1;
    s.requests+=length;s.adapter+=adapter_cost;s.fuel-=fuel;s.phase=1;
    let bytes::Buffer old=replace_buffer(e,prepared);save(e,s);
    set_dispatch_claim(e,0);
    return s.request;
}
// Byte 4 of the fixed exchange header tracks the current request's dispatch.
fn void set_dispatch_claim(ref mut Exchange e,u8 value){
    let ref mut u8[] h=unsafe { byte_slice::from_raw_parts_mut(e,e.header_data,80) };h[4]=value;
}
pub fn Result<bool,ScalarError> claim_scalar_dispatch(ref mut Exchange e,usize run,usize request,usize now){
    if(!is_scalar(e)){return .err(.State);}
    if(deadline_reached(e,now) || header(e)[4]!=0){return .ok(false);}
    let Observation s=state(e);
    if(s.phase!=1 || s.run!=run || s.request!=request){return .ok(false);}
    set_dispatch_claim(e,1);
    return .ok(true);
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
    if(is_scalar(e)){return .err(.State);}
    return reply_exchange(e,run,request,kind,payload,snapshot_fuel,now,cancelled);
}
fn Result<usize,Error> reply_exchange(ref mut Exchange e,usize run,usize request,u8 kind,
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
    let usize admitted=reply_budget(e,payload.len,snapshot_fuel,now)?;
    let bytes::Buffer prepared=snapshot(payload)?;
    let bytes::Buffer old=replace_buffer(e,prepared);
    commit_reply(e,kind,payload.len,snapshot_fuel,now);
    return .ok(request);
}
fn Result<usize,Error> reply_budget(ref mut Exchange e,usize length,usize fuel,usize now){
    if(length>e.limits.reply_bytes || !fits(state(e).replies,length,e.limits.replies_total)){
        return stop(e,4,now);
    }
    if(fuel>state(e).fuel){return stop(e,5,now);}
    return .ok(length);
}
fn void commit_reply(ref mut Exchange e,u8 kind,usize length,usize fuel,usize now){
    var Observation s=state(e);s.replies+=length;s.fuel-=fuel;s.phase=2;
    save(e,s);
    save_reply_kind(e,kind);
    if(kind==2){terminate(e,3,now);}
}
fn u8 result_tag(ref Exchange e){
    return switch(catalog::result_tag(bound_catalog(e),state(e).import_id)){
        case .ok(v):{v}case .err(_):{assert(false);0}
    };
}
// The fixed header carries the kind through receipt and installation.
fn void save_reply_kind(ref mut Exchange e,u8 kind){
    let ref mut u8[] h=unsafe { byte_slice::from_raw_parts_mut(e,e.header_data,80) };h[3]=kind;
}
fn u8 reply_kind(ref Exchange e){return bytes::view(ref e.header)[3];}
fn ref u8[] reply_bytes(ref Exchange e){return bytes::view(ref e.backing);}
// Actual native ownership handoff only. Integrator must install the typed Result
// in its independently validated destination; this function dispatches no VM IR.
pub fn Result<Output,Error> take_reply(ref mut Exchange e,usize now,bool cancelled){
    if(is_scalar(e)){return .err(.State);}
    return take_reply_exchange(e,now,cancelled);
}
fn Result<Output,Error> take_reply_exchange(ref mut Exchange e,usize now,bool cancelled){
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


// The scalar driver extends the same owned, fixed header. Standalone exchanges
// keep their 80-byte header and cannot enter the scalar driver.
// 80 PC, 81 terminal phase, 82 VM failure, 83 argument-copy cursor.
// 84..88 result or host error, 88..96 optional call backing offset.
// 96..2144 verified instructions (four operands, four inline literal bytes).
// 2144..2656 mutable i32 register cells (bools use the same storage).
fn usize scalar_header_size(){return 2656;}
fn usize typed_header_size(){return 4192;}
fn ref mut u8[] scalar_header(ref mut Exchange e){
    let usize size=header(e).len;
    return unsafe { byte_slice::from_raw_parts_mut(e,e.header_data,size) };
}
fn ref u8[] header(ref Exchange e){return bytes::view(ref e.header);}
fn bool is_scalar(ref Exchange e){return header(e).len==scalar_header_size() || header(e).len>=typed_header_size();}
fn bool wide(ref u8[] data){return data.len>=typed_header_size();}

pub enum ScalarError { Authority; Binding; Allocation; State; Rejected; }
pub struct ScalarEvent {
    // 0 runnable, 1 waiting, 2 reply ready, 3 done, 4 failed, 5 receiving.
    u8 phase; Observation host; i64 value;
    // 0 none, 1 exchange, 2 arithmetic, 3 unhandled host error, 4 frame limit.
    u8 failure; i64 host_error;
}
pub fn ScalarEvent empty_scalar_event(){
    return ScalarEvent{.phase=0,.host=Observation{.phase=0,.cause=0,.run=0,.request=0,.import_id=0,
        .calls=0,.requests=0,.replies=0,.adapter=0,.fuel=0,.terminal_at=0,.external_effects_unknown=false},
        .value=0,.failure=0,.host_error=0};
}
fn i64 load_cell(ref u8[] data,usize at,u8 tag){
    return switch(scalar::decode(tag,data[at..at+4])){
        case .ok(v):{v}case .err(_):{assert(false);0}
    };
}
fn void store_cell(ref mut u8[] data,usize at,u8 tag,i64 value){
    assert(scalar::encode(tag,value,data[at..at+4]).is_ok);
}
fn i64 wide_cell(ref u8[] data,usize at){
    return switch(scalar::decode(9,data[at..at+8])){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn void store_wide(ref mut u8[] data,usize at,i64 value){assert(scalar::encode(9,value,data[at..at+8]).is_ok);}
// Calls reserve their own suffix after the reply arena. The entry uses the
// existing register bank. Each child has 128 cells and a two-byte continuation.
// The suffix starts with frame capacity/depth and the validated 32x8 argument map.
fn usize frame_stride(){return 1026;}
fn usize frame_prefix(){return 272;}
fn usize call_base(ref u8[] data){return if(wide(data)){read(data,88)}else{0};}
fn usize frame_depth(ref u8[] data,usize base){return if(base==0){0}else{read(data,base+8)};}
fn usize child_frame(usize base,usize depth){return base+frame_prefix()+(depth-1)*frame_stride();}
fn usize wide_register(ref u8[] data,usize index){
    let usize base=call_base(data);
    let usize depth=frame_depth(data,base);
    let usize start=if(depth==0){2144}else{child_frame(base,depth)};
    return start+index*8;
}
fn i64 reg(ref u8[] data,usize index){
    if(wide(data)){return wide_cell(data,wide_register(data,index));}
    return load_cell(data,2144+index*4,1);
}
fn void set_reg(ref mut u8[] data,usize index,i64 value){
    if(wide(data)){let usize at=wide_register(data,index);store_wide(data,at,value);}
    else{store_cell(data,2144+index*4,1,value);}
}
fn u8 image_index(usize index){
    let i64 n=switch(num::i64_from_usize(index)){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(num::u8_from_i64(n)){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn void load_image(ref mut Exchange e,ref ir::Program p,usize arena_end,usize frames){
    let ref mut u8[] data=scalar_header(e);
    data[80]=image_index(p.starts[p.entry]);
    var usize pc=0;
    while(pc<p.count){
        let usize source=pc*8;
        let usize at=96+source;
        data[at]=p.code[source];data[at+1]=p.code[source+1];
        data[at+2]=p.code[source+2];data[at+3]=p.code[source+3];
        if(wide(data)){
            data[at+4]=p.code[source+4];data[at+5]=p.code[source+5];
            data[at+6]=p.code[source+6];data[at+7]=p.code[source+7];
            // The verified destination type selects the checked negate width.
            if(data[at]==7){data[at+4]=p.types[data[at+1] as usize];}
            if(data[at]==8 && p.types[data[at+2] as usize]==types::host_result()){data[at+4]=1;}
            if(data[at]==9){
                let usize target=p.code[source+2] as usize;
                data[at+2]=image_index(p.starts[target]);
                data[at+4]=image_index(p.register_starts[target]);
                data[at+5]=image_index(p.arities[target]);
            }
        }else if(data[at]==1){
            let i64 literal=p.constants[p.code[source+2] as usize];
            store_cell(data,at+4,1,literal);
        }
        pc+=1;
    }
    if(wide(data)){
        var usize i=0;
        while(i<p.constant_count){store_wide(data,3168+i*8,p.constants[i]);i+=1;}
        let usize first=blob_base()+p.list_used;
        write(data,4192,first);
        write(data,4208,arena_end);
        i=0;while(i<p.list_used){data[blob_base()+i]=p.list_operands[i];i+=1;}
        if(p.call_count!=0){
            write(data,88,arena_end);
            write(data,arena_end,frames);
            i=0;
            while(i<p.call_count*8){data[arena_end+16+i]=p.call_args[i];i+=1;}
        }
    }
}
// A typed byte cell packs a header-relative offset and exact length.
// The header contains the output cursors. The staged payload has its own owner.
fn usize blob_base(){return 4224;}
fn usize output_base(ref u8[] data){return if(wide(data)){read(data,4216)}else{0};}
fn usize output_charge(ref programs::Program p,policy_limits::RunLimits limits){
    return if(programs::emits(p)){24+limits.output_bytes}else{0};
}
pub fn bool has_guest_output(ref Exchange e){return header(e)[81]==3 && output_base(header(e))!=0;}
fn usize staging_limit(ref Exchange e){return bytes::view(ref e.staging).len;}
fn usize envelope_capacity(ref Exchange e){return bytes::capacity(ref e.backing);}
fn usize guest_emits(ref Exchange e){
    return if(has_guest_output(e)){read(header(e),output_base(header(e))+16)}else{0};
}
// Only success can move the staged owner. The exchange can then be destroyed
// without affecting the published view.
pub fn Result<output::Published,Error> take_guest_output(ref mut Exchange e){
    if(!has_guest_output(e) || state(e).phase!=0 || envelope_capacity(e)!=0){return .err(.State);}
    let usize base=output_base(header(e));
    let usize used=read(header(e),base);
    if(used>staging_limit(e) || read(header(e),base+8)!=0){return .err(.State);}
    let usize emits=guest_emits(e);
    let usize fuel=state(e).fuel;
    var bytes::Buffer backing=replace_at(e,32,bytes::empty());
    assert(bytes::resize_zeroed(ref mut backing,used).is_ok);
    write(scalar_header(e),4216,0);
    return .ok(output::publish_owned(backing,emits,fuel));
}
fn i64 pack_blob(usize start,usize length){
    return switch(num::i64_from_usize(start*4294967296+length)){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn usize blob_bits(i64 value){
    return switch(num::usize_from_i64(value)){case .ok(v):{v}case .err(_):{assert(false);0}};
}
struct EnvelopeBounds { usize request; usize reply; usize byte_reply; }
fn EnvelopeBounds typed_bounds(ref programs::Program p,policy_limits::RunLimits limits){
    let ref catalog::Catalog c=programs::imports(p);
    let usize required=programs::requirements(p);
    let usize one=1;
    var usize request=0;var usize reply=0;var usize byte_reply=0;var usize id=0;
    while(id<catalog::count(c)){
        if((required&(one<<id))!=0){
            let usize size=request_bound(c,id);
            if(size<=limits.host_request_bytes){
                let usize possible=if(has_byte_arguments(c,id)){limits.host_request_bytes}else{size};
                if(possible>request){request=possible;}
                let u8 tag=success_tag(c,id);
                let usize ok_size=if(tag==7){limits.host_response_bytes}else{8+scalar::width(wire::scalar_tag(tag))};
                if(ok_size>=8 && ok_size<=limits.host_response_bytes && ok_size>reply){reply=ok_size;}
                if(tag==7 && ok_size>=8){byte_reply=ok_size-8;}
                if(limits.host_response_bytes>=12 && reply<12){reply=12;}
            }
        }
        id+=1;
    }
    return EnvelopeBounds{.request=request,.reply=reply,.byte_reply=byte_reply};
}
fn usize arg_count(ref catalog::Catalog c,usize id){
    return switch(catalog::parameter_count(c,id)){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn u8 arg_tag(ref catalog::Catalog c,usize id,usize index){
    return switch(catalog::parameter_tag(c,id,index)){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn u8 success_tag(ref catalog::Catalog c,usize id){
    return switch(catalog::result_tag(c,id)){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn bool has_byte_arguments(ref catalog::Catalog c,usize id){
    let usize count=arg_count(c,id);var usize i=0;
    while(i<count){if(arg_tag(c,id,i)==7){return true;}i+=1;}
    return false;
}
fn usize arena_end(ref ir::Program code,EnvelopeBounds envelope,policy_limits::RunLimits limits){
    let usize owners=if(limits.owner_entries<limits.host_calls){limits.owner_entries}else{limits.host_calls};
    let usize replies=envelope.byte_reply*owners;
    let usize arena=if(replies<limits.object_bytes){replies}else{limits.object_bytes};
    return blob_base()+code.list_used+arena;
}
fn usize frame_storage(ref ir::Program code,usize frames){
    return if(code.call_count==0){0}else{frame_prefix()+(frames-1)*frame_stride()};
}
fn usize request_bound(ref catalog::Catalog c,usize id){
    var usize total=2;var usize i=0;let usize count=arg_count(c,id);
    while(i<count){total+=8+scalar::width(wire::scalar_tag(arg_tag(c,id,i)));i+=1;}
    return total;
}
pub fn Result<Exchange,ScalarError> create_scalar(ref programs::Program p,ref policy::Policy ceiling,
    ref runs::RunConfig run,usize run_id,usize deadline){
    return create_scalar_input(p,ceiling,run,run_id,deadline,b"");
}
pub fn Result<Exchange,ScalarError> create_scalar_input(ref programs::Program p,ref policy::Policy ceiling,
    ref runs::RunConfig run,usize run_id,usize deadline,ref u8[] input){
    if(!programs::allows(p,ceiling,run)){return .err(.Authority);}
    if(run_id==0 || (input.len!=0 && !programs::accepts_input(p))){return .err(.State);}
    let policy_limits::RunLimits limits=runs::run_limits(run);
    if(input.len>limits.input_bytes || input.len>1048576){return .err(.Rejected);}
    let ref catalog::Catalog original=programs::imports(p);
    let catalog::Catalog exact=switch(catalog::duplicate(original)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    var bool[64] allowed=[false;64];
    let usize count=catalog::count(original);
    let usize required=programs::requirements(p);
    let usize one=1;
    var usize i=0;
    while(i<count){allowed[i]=(required&(one<<i))!=0;i+=1;}
    let bool typed=programs::typed(programs::code(p));
    let EnvelopeBounds envelope=if(typed){typed_bounds(p,limits)}else{EnvelopeBounds{.request=14,.reply=12,.byte_reply=0}};
    let Limits bounds=Limits{.request_bytes=limits.host_request_bytes,.reply_bytes=limits.host_response_bytes,
        .requests_total=envelope.request*limits.host_calls,.replies_total=envelope.reply*limits.host_calls,.calls=limits.host_calls,
        .adapter_per_call=0,.adapter_total=0};
    // The only source of the copy is the immutable catalog already bound by retain.
    let u32[8] digest=programs::binding(p);
    let ref ir::Program code=programs::code(p);
    let usize end=if(typed){arena_end(code,envelope,limits)}else{scalar_header_size()};
    let usize size=end+frame_storage(code,limits.call_frames);
    let bool emits=programs::emits(p);
    let bytes::Buffer staging=if(emits){
        var bytes::Buffer reserved=switch(bytes::with_capacity(limits.output_bytes)){
            case .ok(v):{v}case .err(_):{return .err(.Allocation);}
        };
        assert(bytes::resize_zeroed(ref mut reserved,limits.output_bytes).is_ok);
        reserved
    }else{bytes::empty()};
    var Exchange e=switch(create_sized(exact,ref allowed[..count],bounds,run_id,limits.fuel,deadline,
        size+input.len+if(emits){24}else{0},digest,staging)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    load_image(ref mut e,code,end,limits.call_frames);
    e.reply_owners_left=limits.owner_entries;
    if(programs::accepts_input(p)){
        let ref mut u8[] image=scalar_header(ref mut e);
        var usize i=0;
        while(i<input.len){image[size+i]=input[i];i+=1;}
        set_reg(image,code.register_starts[code.entry],pack_blob(size,input.len));
    }
    if(emits){write(scalar_header(ref mut e),4216,size+input.len);}
    return .ok(e);
}
// Reserve the exact maximum heap backing over this admitted scalar run.
pub fn usize scalar_storage_bound(ref programs::Program p,policy_limits::RunLimits limits){
    let usize catalog_bytes=catalog::duplicate_bytes(programs::imports(p));
    if(programs::typed(programs::code(p))){
        let EnvelopeBounds envelope=typed_bounds(p,limits);
        let ref ir::Program code=programs::code(p);
        return arena_end(code,envelope,limits)+frame_storage(code,limits.call_frames)+catalog_bytes+output_charge(p,limits)+
            if(limits.host_calls==0){0}else{envelope.request+envelope.reply};
    }
    let usize base=scalar_header_size()+catalog_bytes;
    if(programs::requirements(p)==0 || limits.host_calls==0 || limits.host_request_bytes<14){return base;}
    // A reply is allocated before replacing the still-live request.
    return base+14+if(limits.host_response_bytes>=12){12}else{0};
}
pub fn Result<ScalarEvent,ScalarError> observe_scalar(ref Exchange e){
    if(!is_scalar(e)){return .err(.State);}
    return .ok(scalar_event(e));
}
pub fn usize current_instruction(ref Exchange e){return header(e)[80] as usize;}
fn ScalarEvent scalar_event(ref Exchange e){
    let ref u8[] data=header(e);
    let Observation host=state(e);
    let u8 phase=if(data[81]!=0){data[81]}else if(host.phase==3){4}else if(host.phase==4){5}else{host.phase};
    let u8 failure=if(host.phase==3){1}else{data[82]};
    return ScalarEvent{.phase=phase,.host=host,.value=if(phase==3){load_cell(data,84,1)}else{0},
        .failure=failure,.host_error=if(failure==3){load_cell(data,84,11)}else{0}};
}
// Compact scalar values can be split inside the TLV body. Validate a final
// fragment without mutating the retained prefix, so a bad value can be retried.
fn bool valid_compact_end(u8 kind,u8 tag,ref u8[] prefix,ref u8[] chunk,usize total){
    var u8[16] message=[0;16];
    var usize i=0;
    while(i<prefix.len){message[i]=prefix[i];i+=1;}
    while(i<total){message[i]=chunk[i-prefix.len];i+=1;}
    return wire::decode_reply(kind,tag,ref message[..total],total).is_ok;
}
// Each call owns its slice only for the duration of the copy. For a nonempty
// envelope the first piece carries the whole TLV header, which pins the total.
pub fn Result<ScalarEvent,ScalarError> receive_scalar_reply(ref mut Exchange e,usize run,usize request,
    u8 kind,usize total,usize offset,ref u8[] chunk,usize now){
    if(!is_scalar(e) || header(e)[81]!=0){return .err(.State);}
    let Observation current=poll_exchange(e,now,false);
    if(current.phase==3){return .ok(scalar_event(e));}
    if((current.phase!=1 && current.phase!=4) || current.run!=run || current.request!=request ||
        chunk.len>4096 || offset>total || chunk.len>total-offset || (chunk.len==0 && total!=0)){
        return .err(.Rejected);
    }
    let bool complete=offset+chunk.len==total;
    let u8 tag=result_tag(e);
    if(current.phase==1){
        if(offset!=0){return .err(.Rejected);}
        if(total>wire::payload_limit()){discard stop(e,4,now);return .ok(scalar_event(e));}
        let bool valid=if(complete){wire::decode_reply(kind,tag,chunk,total).is_ok}
            else{wire::reply_prefix(kind,tag,chunk,total).is_ok};
        if(!valid){return .err(.Rejected);}
        if(!reply_budget(e,total,total,now).is_ok){return .ok(scalar_event(e));}
        var bytes::Buffer prepared=switch(bytes::with_capacity(total)){
            case .ok(v):{v}case .err(_):{return .err(.Allocation);}
        };
        if(!bytes::append(ref mut prepared,chunk).is_ok){return .err(.Allocation);}
        let bytes::Buffer old=replace_buffer(e,prepared);
    }else{
        let ref u8[] prefix=reply_bytes(e);
        if(kind!=reply_kind(e) || offset!=prefix.len || !wire::reply_prefix(kind,tag,prefix,total).is_ok){
            return .err(.Rejected);
        }
        if(complete && (kind!=0 || tag!=7) && !valid_compact_end(kind,tag,prefix,chunk,total)){
            return .err(.Rejected);
        }
        // Exact capacity was reserved before swapping out the waiting request.
        let u32 status=unsafe{append_buffer_raw(e as ptr mut void,chunk as ptr u8,chunk.len)};
        if(status!=0){return .err(.Allocation);}
    }
    if(complete){
        commit_reply(e,kind,total,total,now);
    }else if(current.phase==1){
        save_reply_kind(e,kind);
        var Observation receiving=current;receiving.phase=4;save(e,receiving);
    }
    return .ok(scalar_event(e));
}
fn Result<ScalarEvent,ScalarError> publish_scalar(ref mut Exchange e,usize import_id,i64 value,usize now){
    let wire::Field[1] fields=[wire::Field{.tag=3,.scalar=value,.start=0,.length=0};1];
    var u8[14] message=[0;14];
    assert(wire::encode_request(ref fields,b"",ref mut message,14).is_ok);
    let Result<usize,Error> published=begin_exchange(e,import_id,ref message,1+14,0,now,false);
    if(!published.is_ok && state(e).phase!=3){return .err(.Rejected);}
    return .ok(scalar_event(e));
}
fn Result<ScalarEvent,ScalarError> publish_typed(ref mut Exchange e,usize import_id,usize first,usize now){
    let ref catalog::Catalog c=bound_catalog(e);
    let usize count=arg_count(c,import_id);
    let ref u8[] data=header(e);
    var wire::Field[32] fields=[wire::empty_field();32];
    var usize i=0;
    while(i<count){
        let u8 tag=arg_tag(c,import_id,i);let i64 value=reg(data,first+i);
        let usize bits=if(tag==7){blob_bits(value)}else{0};
        fields[i]=wire::Field{.tag=tag,.scalar=value,.start=bits/4294967296,.length=bits%4294967296};
        i+=1;
    }
    let usize length=switch(wire::request_size(ref fields[..count],data,e.limits.request_bytes)){
        case .ok(v):{v}
        case .err(_):{discard stop(e,4,now);return .ok(scalar_event(e));}
    };
    let usize fuel=1+length;
    if(!preflight_request(e,length,fuel,0,now).is_ok){return .ok(scalar_event(e));}
    var bytes::Buffer message=switch(bytes::with_capacity(length)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    assert(bytes::resize_zeroed(ref mut message,length).is_ok);
    assert(wire::encode_request(ref fields[..count],header(e),bytes::view_mut(ref mut message),length).is_ok);
    discard commit_request(e,import_id,message,length,fuel,0);
    return .ok(scalar_event(e));
}
fn Result<ScalarEvent,ScalarError> install_scalar(ref mut Exchange e,usize dst,usize now){
    let Output output=switch(take_reply_exchange(e,now,false)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    let wire::Field field=output_field(ref output);
    let ref mut u8[] data=scalar_header(e);
    let usize at=96+8*(data[80] as usize);
    let bool failed=output_kind(ref output)==1;
    if(data[at]==programs::value_request_opcode()){
        save_result(data,dst,!failed,field.scalar);data[80]+=1;
    }else if(failed){
        if(data[at]==programs::result_request_opcode()){
            let usize error_dst=data[at+5] as usize;
            let u8 error_target=data[at+6];
            set_reg(data,error_dst,field.scalar);data[80]=error_target;
        }else{
            data[81]=4;data[82]=3;store_cell(data,84,11,field.scalar);
        }
    }else{
        set_reg(data,dst,field.scalar);data[80]+=1;
    }
    return .ok(scalar_event(e));
}
fn void save_result(ref mut u8[] data,usize dst,bool ok,i64 value){
    set_reg(data,dst+1,value);
    set_reg(data,dst,if(ok){1}else{0});
}
// 4192 holds the committed arena end. 4200 is the unpublished reply cursor.
fn Result<ScalarEvent,ScalarError> install_bytes(ref mut Exchange e,usize dst,usize now,ref mut usize work){
    let wire::Field field=switch(wire::decode_reply(0,7,reply_bytes(e),e.limits.reply_bytes)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    let ref u8[] current=header(e);
    let usize start=read(current,4192);
    let usize copied=read(current,4200);
    let usize end=read(current,4208);
    if(start>end || copied>field.length){return .err(.State);}
    if(e.reply_owners_left==0){discard stop(e,8,now);return .ok(scalar_event(e));}
    if(field.length>end-start){discard stop(e,4,now);return .ok(scalar_event(e));}
    let usize left=field.length-copied;
    let usize count=if(left<*work){left}else{*work};
    *work-=if(count==0){1}else{count};

    // Move only Buffer metadata. The source allocation stays immutable, and
    // the arena and source have disjoint owners throughout the copy.
    let bytes::Buffer backing=replace_buffer(e,bytes::empty());
    let usize next=copied+count;
    {
        let ref u8[] source=bytes::view(ref backing);
        let ref mut u8[] data=scalar_header(e);
        var usize i=copied;
        while(i<next){data[start+i]=source[field.start+i];i+=1;}
        if(next==field.length){
            write(data,4192,start+next);
            write(data,4200,0);
            let usize at=96+8*(data[80] as usize);
            let i64 value=pack_blob(start,next);
            if(data[at]==programs::value_request_opcode()){save_result(data,dst,true,value);}
            else{set_reg(data,dst,value);}
            data[80]+=1;
        }else{
            write(data,4200,next);
        }
    }
    if(next<field.length){
        let bytes::Buffer empty=replace_buffer(e,backing);
        return .ok(scalar_event(e));
    }
    // Committed ranges remain in the invocation arena until teardown.
    // Even a zero-length Buffer consumes one owner. Installation debits it once.
    e.reply_owners_left-=1;
    var Observation s=state(e);s.phase=0;save(e,s);
    return .ok(scalar_event(e));
}
fn void enter_call(ref mut u8[] data,usize at){
    let usize base=call_base(data);
    let usize depth=frame_depth(data,base)+1;
    let usize continuation=child_frame(base,depth)+1024;
    data[continuation]=data[80]+1;
    data[continuation+1]=data[at+1];
    write(data,base+8,depth);
    data[83]=0;
    data[80]=data[at+2];
}
fn void copy_call_argument(ref mut u8[] data,usize at){
    let usize base=call_base(data);
    let usize child=child_frame(base,frame_depth(data,base)+1);
    let usize index=(data[83] as usize)-1;
    let usize source=data[base+16+(data[at+3] as usize)*8+index] as usize;
    let usize destination=(data[at+4] as usize)+index;
    let i64 value=reg(data,source);
    store_wide(data,child+destination*8,value);
    if(data[83]==data[at+5]){enter_call(data,at);}
    else{data[83]+=1;}
}
fn void begin_call(ref mut u8[] data,usize at){
    let usize base=call_base(data);
    if(frame_depth(data,base)+1>=read(data,base)){
        data[81]=4;data[82]=4;return;
    }
    if(data[at+5]==0){enter_call(data,at);}
    else{data[83]=1;}
}
fn void return_scalar(ref mut u8[] data,i64 value,bool pair,i64 payload){
    let usize base=call_base(data);
    let usize depth=frame_depth(data,base);
    if(depth==0){store_cell(data,84,1,value);data[81]=3;return;}
    let usize continuation=child_frame(base,depth)+1024;
    let usize dst=data[continuation+1] as usize;
    write(data,base+8,depth-1);
    set_reg(data,dst,value);
    if(pair){set_reg(data,dst+1,payload);}
    data[80]=data[continuation];
}
fn void dispatch_scalar(ref mut u8[] data,u8 op,usize dst,usize a,usize b,usize at){
    if(op==programs::wrap_opcode()){
        let i64 payload=reg(data,a);
        save_result(data,dst,b==1,payload);
        data[80]+=1;return;
    }
    if(op==programs::project_opcode()){
        let i64 tag=reg(data,a);
        if(b!=2 && tag!=if(b==1){1}else{0}){data[81]=4;data[82]=2;return;}
        let i64 value=if(b==2){tag}else{reg(data,a+1)};
        set_reg(data,dst,value);data[80]+=1;return;
    }
    if(op==17 || op==18 || op==programs::copy_opcode()){
        let i64 value=reg(data,a);
        set_reg(data,dst,value);data[80]+=1;return;
    }
    if(op==119){
        let usize start=blob_base()+a+b*256;
        let usize length=data[at+4] as usize+256*(data[at+5] as usize);
        set_reg(data,dst,pack_blob(start,length));data[80]+=1;return;
    }
    if(op==120){
        let usize length=blob_bits(reg(data,a))%4294967296;
        let i64 value=switch(num::i64_from_usize(length)){case .ok(v):{v}case .err(_):{assert(false);0}};
        set_reg(data,dst,value);data[80]+=1;return;
    }
    if(op==19 || op==22){data[80]=data[at+2];return;}
    if(op==20 || op==21){
        let bool taken=(reg(data,a)==0)==(op==20);
        data[80]=if(taken){data[at+3]}else{data[80]+1};return;
    }
    if(op==8){
        let i64 value=reg(data,a);
        let bool pair=data[at+4]!=0;
        let i64 payload=if(pair){reg(data,a+1)}else{0};
        return_scalar(data,value,pair,payload);return;
    }
    let i64 value=if(op==1){if(wide(data)){wide_cell(data,3168+a*8)}else{load_cell(data,at+4,1)}}else{
        assert(op==2 || op==7);
        let i64 right=if(op==7){0}else{reg(data,b)};
        let u8 tag=if(op==7 && wide(data)){data[at+4]}else{1};
        switch(arithmetic::signed(op,reg(data,a),right,tag,0)){
            case .ok(v):{v}
            case .err(_):{data[81]=4;data[82]=2;return;}
        }
    };
    set_reg(data,dst,value);data[80]+=1;
}
// Staged output suffix: committed length, partial copy cursor, emit count.
fn Result<ScalarEvent,ScalarError> emit_guest(ref mut Exchange e,usize argument,usize now,ref mut usize work){
    let ref u8[] current=header(e);
    let usize base=output_base(current);
    if(base==0){return .err(.State);}
    let usize limit=staging_limit(e);
    let usize bits=blob_bits(reg(current,argument));
    let usize source=bits/4294967296;
    let usize length=bits%4294967296;
    if(source>base || length>base-source){return .err(.State);}
    let usize used=read(current,base);
    let usize copied=read(current,base+8);
    if(used>limit || copied>length){return .err(.State);}
    if(length>limit-used){discard stop(e,7,now);return .ok(scalar_event(e));}
    if(copied==0 && !spend_guest(e,prices::output_emit(length),now).is_ok){return .ok(scalar_event(e));}
    let usize left=length-copied;
    let usize count=if(left<*work){left}else{*work};
    *work-=if(count==0){1}else{count};
    let usize next=copied+count;
    if(count!=0){
        let ptr mut u8 address=e.staging_data;
        let ref u8[] input=header(e);
        // Staging and the input image are distinct allocations owned by e.
        var usize staging_scope=limit;
        let ref mut u8[] target=unsafe{byte_slice::from_raw_parts_mut(ref mut staging_scope,address,limit)};
        var usize i=copied;while(i<next){target[used+i]=input[source+i];i+=1;}
    }
    {
        let ref mut u8[] data=scalar_header(e);
        if(next==length){
            write(data,base,used+length);
            write(data,base+8,0);
            let usize emits=read(data,base+16);
            write(data,base+16,emits+1);
            data[80]+=1;
        }else{write(data,base+8,next);}
    }
    return .ok(scalar_event(e));
}
pub fn Result<ScalarEvent,ScalarError> step_scalar(ref mut Exchange e,usize now,bool cancelled){
    var usize work=4096;
    return step_scalar_budget(e,now,cancelled,ref mut work);
}
// One checkpoint executes one instruction or advances one reply. A byte reply
// spends one work unit per copied byte. Fuel was charged at acceptance.
pub fn Result<ScalarEvent,ScalarError> step_scalar_budget(ref mut Exchange e,usize now,bool cancelled,ref mut usize work){
    if(!is_scalar(e) || *work==0 || *work>4096){return .err(.State);}
    if(header(e)[81]!=0){return .ok(scalar_event(e));}
    let Observation host=poll_exchange(e,now,cancelled);
    if(host.phase==1 || host.phase==3 || host.phase==4){return .ok(scalar_event(e));}
    let ref u8[] data=header(e);
    let usize at=96+8*(data[80] as usize);
    let u8 op=data[at];
    let usize dst=data[at+1] as usize;
    let usize a=data[at+2] as usize;
    let usize b=data[at+3] as usize;
    if(host.phase==2){
        if((op!=programs::request_opcode() && !programs::typed_request(op)) || b!=host.import_id){return .err(.State);}
        if(reply_kind(e)==0 && result_tag(e)==7){return install_bytes(e,dst,now,work);}
    };
    let usize output=output_base(data);
    if(output!=0 && data[5]==0){
        let usize limit=staging_limit(e);
        *work-=1;
        if(spend_guest(e,prices::output_prepare(limit),now).is_ok){scalar_header(e)[5]=1;}
        return .ok(scalar_event(e));
    }
    if(host.phase==0 && op==programs::emit_opcode()){return emit_guest(e,a,now,work);}
    let bool seal=op==8 && output!=0 && frame_depth(data,call_base(data))==0;
    *work-=1;
    if(host.phase==2){return install_scalar(e,dst,now);}
    if(programs::typed_request(op)){return publish_typed(e,b,a,now);}
    if(op==programs::request_opcode()){
        let i64 value=reg(data,a);
        return publish_scalar(e,b,value,now);
    }
    if(op==9){
        if(data[83]!=0){copy_call_argument(scalar_header(e),at);}
        else{
            let usize cost=1+(data[at+5] as usize);
            if(spend_guest(e,cost,now).is_ok){begin_call(scalar_header(e),at);}
        }
    }else if(spend_guest(e,1+if(seal){prices::output_seal()}else{0},now).is_ok){
        dispatch_scalar(scalar_header(e),op,dst,a,b,at);
    }
    return .ok(scalar_event(e));
}
