module host_exchange;
import arithmetic as arithmetic;
import host_catalog as catalog;
import host_program as programs;
import ir as ir;
import runtime_policy as policy;
import runtime_policy_limits as policy_limits;
import runtime_run_config as runs;
import scalar_codec as scalar;
import host_wire as wire;
import std::bytes as bytes;
import std::num as num;

// Private native coordinator and scalar VM driver. No public ABI.
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
    let u32[8] digest=switch(catalog::digest(ref c)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    return create_sized(c,allowed,limits,run,fuel,deadline,80,digest);
}
fn Result<Exchange,Error> create_sized(catalog::Catalog c,ref bool[] allowed,Limits limits,
    usize run,usize fuel,usize deadline,usize size,u32[8] digest){
    var Grants grants=Grants{.allowed=[false;64]};var usize i=0;
    while(i<allowed.len){grants.allowed[i]=allowed[i];i+=1;}
    var bytes::Buffer header=switch(bytes::with_capacity(size)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    let usize sized=switch(bytes::resize_zeroed(ref mut header,size)){
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
    if(is_scalar(e)){return state(e);}
    return poll_exchange(e,now,cancelled);
}
fn Observation poll_exchange(ref mut Exchange e,usize now,bool cancelled){
    if(state(e).phase!=3){
        if(cancelled){terminate(e,1,now);}
        else if(e.deadline!=0 && now>=e.deadline){terminate(e,2,now);}
    }return state(e);
}
fn Result<usize,Error> checkpoint(ref mut Exchange e,usize now,bool cancelled){
    let Observation s=poll_exchange(e,now,cancelled);
    if(s.phase==3){return .err(.Terminated);}return .ok(0);
}
// Debit guest instructions on the same meter that owns host publication.
fn Result<usize,Error> spend_guest(ref mut Exchange e,usize now){
    let Observation current=state(e);
    if(current.phase!=0){return .err(.State);}
    if(current.fuel==0){return stop(e,5,now);}
    var Observation next=current;
    next.fuel-=1;
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
// 80 PC, 81 terminal phase, 82 VM failure, 84..88 result or host error.
// 96..2144 verified instructions (four operands, four inline literal bytes).
// 2144..2656 mutable i32 register cells (bools use the same storage).
fn usize scalar_header_size(){return 2656;}
fn ref mut u8[] scalar_header(ref mut Exchange e){
    return unsafe { byte_slice::from_raw_parts_mut(e,e.header_data,scalar_header_size()) };
}
fn ref u8[] header(ref Exchange e){return bytes::view(ref e.header);}
fn bool is_scalar(ref Exchange e){return header(e).len==scalar_header_size();}

pub enum ScalarError { Authority; Binding; Allocation; State; Rejected; }
pub struct ScalarEvent {
    // 0 runnable, 1 waiting, 2 reply ready, 3 done, 4 failed.
    u8 phase; Observation host; i64 value;
    // 0 none, 1 exchange, 2 arithmetic, 3 host error (guest error arm is still gated).
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
fn void load_image(ref mut Exchange e,ref ir::Program p){
    let ref mut u8[] data=scalar_header(e);
    var usize pc=0;
    while(pc<p.count){
        let usize source=pc*8;
        let usize at=96+source;
        data[at]=p.code[source];data[at+1]=p.code[source+1];
        data[at+2]=p.code[source+2];data[at+3]=p.code[source+3];
        if(data[at]==1){
            let i64 literal=p.constants[p.code[source+2] as usize];
            store_cell(data,at+4,1,literal);
        }
        pc+=1;
    }
}
pub fn Result<Exchange,ScalarError> create_scalar(ref programs::Program p,ref policy::Policy ceiling,
    ref runs::RunConfig run,usize run_id,usize deadline){
    if(!programs::allows(p,ceiling,run)){return .err(.Authority);}
    if(run_id==0){return .err(.State);}
    let policy_limits::RunLimits limits=runs::run_limits(run);
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
    let Limits bounds=Limits{.request_bytes=limits.host_request_bytes,.reply_bytes=limits.host_response_bytes,
        .requests_total=14*limits.host_calls,.replies_total=12*limits.host_calls,.calls=limits.host_calls,
        .adapter_per_call=0,.adapter_total=0};
    // The only source of the copy is the immutable catalog already bound by retain.
    let u32[8] digest=programs::binding(p);
    var Exchange e=switch(create_sized(exact,ref allowed[..count],bounds,run_id,limits.fuel,deadline,scalar_header_size(),digest)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    load_image(ref mut e,programs::code(p));
    return .ok(e);
}
// Reserve the exact maximum heap backing over this admitted scalar run.
pub fn usize scalar_storage_bound(ref programs::Program p,policy_limits::RunLimits limits){
    let usize base=scalar_header_size()+catalog::duplicate_bytes(programs::imports(p));
    if(programs::requirements(p)==0 || limits.host_calls==0 || limits.host_request_bytes<14){return base;}
    // A reply is allocated before replacing the still-live request.
    return base+14+if(limits.host_response_bytes>=12){12}else{0};
}
pub fn Result<ScalarEvent,ScalarError> observe_scalar(ref Exchange e){
    if(!is_scalar(e)){return .err(.State);}
    return .ok(scalar_event(e));
}
fn ScalarEvent scalar_event(ref Exchange e){
    let ref u8[] data=header(e);
    let Observation host=state(e);
    let u8 phase=if(data[81]!=0){data[81]}else if(host.phase==3){4}else{host.phase};
    let u8 failure=if(host.phase==3){1}else{data[82]};
    return ScalarEvent{.phase=phase,.host=host,.value=if(phase==3){load_cell(data,84,1)}else{0},
        .failure=failure,.host_error=if(failure==3){load_cell(data,84,11)}else{0}};
}
pub fn Result<ScalarEvent,ScalarError> reply_scalar(ref mut Exchange e,usize run,usize request,u8 kind,
    ref u8[] payload,usize now,bool cancelled){
    if(!is_scalar(e) || header(e)[81]!=0){return .err(.State);}
    let Result<usize,Error> committed=reply_exchange(e,run,request,kind,payload,payload.len,now,cancelled);
    if(!committed.is_ok && state(e).phase!=3){return .err(.Rejected);}
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
fn Result<ScalarEvent,ScalarError> install_scalar(ref mut Exchange e,usize dst,usize now){
    let Output output=switch(take_reply_exchange(e,now,false)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    let wire::Field field=output_field(ref output);
    let ref mut u8[] data=scalar_header(e);
    if(output_kind(ref output)==1){
        data[81]=4;data[82]=3;store_cell(data,84,11,field.scalar);
    }else{
        store_cell(data,2144+dst*4,1,field.scalar);data[80]+=1;
    }
    return .ok(scalar_event(e));
}
fn void dispatch_scalar(ref mut u8[] data,u8 op,usize dst,usize a,usize b,usize at){
    if(op==19 || op==22){data[80]=data[at+2];return;}
    if(op==20 || op==21){
        let bool taken=(load_cell(data,2144+a*4,1)==0)==(op==20);
        data[80]=if(taken){data[at+3]}else{data[80]+1};return;
    }
    if(op==8){
        let i64 value=load_cell(data,2144+a*4,1);
        store_cell(data,84,1,value);data[81]=3;return;
    }
    let i64 value=if(op==1){load_cell(data,at+4,1)}else{
        assert(op==2);
        switch(arithmetic::signed(2,load_cell(data,2144+a*4,1),load_cell(data,2144+b*4,1),1,0)){
            case .ok(v):{v}
            case .err(_):{data[81]=4;data[82]=2;return;}
        }
    };
    store_cell(data,2144+dst*4,1,value);data[80]+=1;
}
// One step executes one instruction or installs one reply. Waiting performs
// one checkpoint, without moving the PC, spending Fuel or calling an adapter.
pub fn Result<ScalarEvent,ScalarError> step_scalar(ref mut Exchange e,usize now,bool cancelled){
    if(!is_scalar(e)){return .err(.State);}
    if(header(e)[81]!=0){return .ok(scalar_event(e));}
    let Observation host=poll_exchange(e,now,cancelled);
    if(host.phase==1 || host.phase==3){return .ok(scalar_event(e));}
    let ref u8[] data=header(e);
    let usize at=96+8*(data[80] as usize);
    let u8 op=data[at];
    let usize dst=data[at+1] as usize;
    let usize a=data[at+2] as usize;
    let usize b=data[at+3] as usize;
    if(host.phase==2){
        if(op!=programs::request_opcode() || b!=host.import_id){return .err(.State);}
        return install_scalar(e,dst,now);
    }
    if(op==programs::request_opcode()){
        let i64 value=load_cell(data,2144+a*4,1);
        return publish_scalar(e,b,value,now);
    }
    if(spend_guest(e,now).is_ok){dispatch_scalar(scalar_header(e),op,dst,a,b,at);}
    return .ok(scalar_event(e));
}
