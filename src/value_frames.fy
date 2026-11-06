module value_frames;
import value_frame_layout as layouts;
import value_frame_meter as meter;
import value_codec as codec;
import value_properties as properties;
import value_roots as owners;
import buffer_growth as growth;
import scalar_codec as scalar;
import cells as cells;
import fuel as fuel;
import std::bytes as bytes;
import std::vec as vec;

// Private native coordinator storage, not guest/Engine handles. The coordinator
// retains the immutable Plan, matching State, frame/scratch vectors and owning
// root state/vectors together; no native contents/metadata may be transplanted.
pub struct Frame { usize function; usize generation; usize live; usize next; usize charge; }
pub struct State {
    usize depth; usize next; usize used; usize peak; bool closed;
    Frame[32] frames; usize[512] order;
}
pub struct Token { usize frame; usize generation; }
pub struct Address { usize frame; usize generation; usize slot; }
pub enum Error { Fuel; State; Type; Bounds; Quota; Allocation; Value; Owner; }
pub struct Slot { usize type_id; usize offset; usize width; usize binding; bool copyable; }
pub struct Case { bool matched; bool payload; }
fn Frame blank(){return Frame{.function=0,.generation=0,.live=0,.next=0,.charge=0};}
fn Error metered(meter::Error e){return switch(e){case .Fuel:{.Fuel}case .Bounds:{.Bounds}case .Quota:{.Quota}case .State:{.State}};}
fn Error owned(owners::Error e){return switch(e){
    case .Fuel:{.Fuel}case .Quota:{.Quota}case .Allocation:{.Allocation}case .Bounds:{.Bounds}
    case .State:{.State}case .Binding:{.Owner}case .Serial:{.Owner}case .Owners:{.Owner}
};}
fn Result<usize,Error> paid(usize cost,ref mut usize fuel){return switch(meter::pay(cost,fuel)){
    case .ok(v):{.ok(v)}case .err(e):{.err(metered(e))}
};}
fn Result<usize,Error> operation(usize width){return switch(meter::operation_cost(width)){
    case .ok(v):{.ok(v)}case .err(e):{.err(metered(e))}
};}
fn usize capacity(usize width){return switch(meter::capacity(width)){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize charge(usize width){return switch(meter::charge(width)){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn Result<bytes::Buffer,Error> backing(usize width){
    var bytes::Buffer b=switch(bytes::with_capacity(capacity(width))){case .ok(v):{v}case .err(_):{return .err(.Allocation);}};
    if(bytes::capacity(ref b)!=capacity(width) || !bytes::resize_zeroed(ref mut b,width).is_ok ||
        bytes::len(ref b)!=width){return .err(.State);}return .ok(b);
}
pub fn Result<State,Error> open(ref layouts::Plan plan,ref mut vec::Vec<bytes::Buffer> frames,
    ref mut vec::Vec<bytes::Buffer> scratch,ref owners::State roots,growth::Limits limits,ref mut usize fuel){
    let usize largest=layouts::largest(plan);
    let usize cost=switch(meter::setup_cost(largest)){case .ok(v):{v}case .err(e):{return .err(metered(e));}};
    let usize spent=paid(cost,fuel)?;
    if(roots.closed || vec::len<bytes::Buffer>(frames)!=0 || vec::len<bytes::Buffer>(scratch)!=0){return .err(.State);}
    let usize used=switch(meter::admit(0,meter::metadata_charge()+charge(largest),ref roots.ledger,limits)){
        case .ok(v):{v}case .err(e):{return .err(metered(e));}
    };
    if(!vec::reserve<bytes::Buffer>(frames,32).is_ok || !vec::reserve<bytes::Buffer>(scratch,1).is_ok){return .err(.Allocation);}
    let bytes::Buffer temp=backing(largest)?;
    switch(vec::push<bytes::Buffer>(scratch,temp)){case .ok(_):{}case .err(_):{return .err(.State);}};
    return .ok(State{.depth=0,.next=1,.used=used,.peak=used,.closed=false,.frames=[blank();32],.order=[0;512]});
}
fn Result<usize,Error> ready(ref layouts::Plan plan,ref State state,ref vec::Vec<bytes::Buffer> frames){
    if(state.closed || state.depth>32 || state.depth!=vec::len<bytes::Buffer>(frames) ||
        vec::capacity<bytes::Buffer>(frames)<32 || state.used>state.peak){return .err(.State);}
    var usize expected=meter::metadata_charge()+charge(layouts::largest(plan));
    var usize previous=0;var usize i=0;
    while(i<32){let Frame f=state.frames[i];
        if(i<state.depth){
            if(f.function>=layouts::functions(plan) || f.generation<=previous ||
                (state.next!=0 && f.generation>=state.next) || f.next==0 || f.live>65535){return .err(.State);}
            let usize width=switch(layouts::width(plan,f.function)){case .ok(v):{v}case .err(_):{return .err(.State);}};
            if(f.charge!=charge(width)){return .err(.State);}expected+=f.charge;previous=f.generation;
        }else if(f.function!=0 || f.generation!=0 || f.live!=0 || f.next!=0 || f.charge!=0){return .err(.State);}
        i+=1;
    }
    if(state.used!=expected){return .err(.State);}
    return .ok(state.depth);
}
fn Result<usize,Error> active_frame(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,usize frame,usize generation){
    let usize depth=ready(plan,state,frames)?;
    if(frame>=depth || generation==0){return .err(.State);}
    let Frame f=state.frames[frame];
    if(f.generation!=generation || f.next==0 || f.function>=layouts::functions(plan) || f.live>65535){return .err(.State);}
    let usize width=switch(layouts::width(plan,f.function)){case .ok(v):{v}case .err(_):{return .err(.State);}};
    let ref bytes::Buffer b=vec::at<bytes::Buffer>(frames,frame);
    if(f.charge!=charge(width) || bytes::len(b)!=width || bytes::capacity(b)!=capacity(width)){return .err(.State);}
    return .ok(width);
}
fn Result<Slot,Error> address(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Address at,bool live){
    let usize frame_width=active_frame(plan,state,frames,at.frame,at.generation)?;
    if(at.slot>=16){return .err(.Bounds);}let Frame f=state.frames[at.frame];let usize one=1;
    let bool initialized=(f.live&(one<<at.slot))!=0;
    if(initialized!=live || (initialized && (state.order[at.frame*16+at.slot]==0 || state.order[at.frame*16+at.slot]>=f.next)) ||
        (!initialized && (state.order[at.frame*16+at.slot]!=0 || f.next==18446744073709551615))){return .err(.State);}
    let usize id=switch(layouts::type_id(plan,at.slot,f.function)){case .ok(v):{v}case .err(_):{return .err(.Type);}};
    let usize offset=switch(layouts::offset(plan,at.slot)){case .ok(v):{v}case .err(_):{return .err(.Type);}};
    let properties::Property p=switch(codec::shape(layouts::layout(plan),id)){case .ok(v):{v}case .err(_):{return .err(.Type);}};
    if(offset>frame_width || p.bytes>frame_width-offset){return .err(.State);}
    return .ok(Slot{.type_id=id,.offset=offset,.width=p.bytes,.binding=at.frame*16+at.slot,.copyable=p.copyable});
}
pub fn Result<Token,Error> enter(ref layouts::Plan plan,ref mut State state,ref mut vec::Vec<bytes::Buffer> frames,
    usize function,ref owners::State roots,growth::Limits limits,ref mut usize fuel){
    let usize width=switch(layouts::width(plan,function)){case .ok(v):{v}case .err(_):{return .err(.Type);}};
    let usize cost=switch(meter::enter_cost(width)){case .ok(v):{v}case .err(e):{return .err(metered(e));}};
    let usize spent=paid(cost,fuel)?;let usize depth=ready(plan,state,frames)?;
    if(roots.closed || depth==32 || state.next==0){return .err(.State);}
    let usize used=switch(meter::admit(state.used,charge(width),ref roots.ledger,limits)){
        case .ok(v):{v}case .err(e):{return .err(metered(e));}
    };
    let bytes::Buffer b=backing(width)?;
    switch(vec::push<bytes::Buffer>(frames,b)){case .ok(_):{}case .err(_):{return .err(.State);}};
    let usize generation=state.next;
    state.frames[depth]=Frame{.function=function,.generation=generation,.live=0,.next=1,.charge=charge(width)};
    var usize i=depth*16;while(i<depth*16+16){state.order[i]=0;i+=1;}
    state.depth=depth+1;state.next=if(generation==18446744073709551615){0}else{generation+1};
    state.used=used;if(used>state.peak){state.peak=used;}
    return .ok(Token{.frame=depth,.generation=generation});
}
fn void publish(ref mut State state,Address at){
    let usize sequence=state.frames[at.frame].next;let usize one=1;
    let usize mask=state.frames[at.frame].live|(one<<at.slot);
    state.order[at.frame*16+at.slot]=sequence;state.frames[at.frame].next=sequence+1;state.frames[at.frame].live=mask;
}
fn void dead(ref mut State state,Address at){
    let usize one=1;let usize mask=state.frames[at.frame].live&(~(one<<at.slot));
    state.frames[at.frame].live=mask;state.order[at.frame*16+at.slot]=0;
}
fn void copy(ref u8[] source,ref mut u8[] destination){
    assert(source.len==destination.len);var usize i=0;while(i<source.len){destination[i]=source[i];i+=1;}
}
fn void erase(ref mut vec::Vec<bytes::Buffer> frames,Address at,Slot slot){
    let ref mut u8[] data=bytes::view_mut(vec::at_mut<bytes::Buffer>(frames,at.frame));
    var usize i=slot.offset;while(i<slot.offset+slot.width){data[i]=0;i+=1;}
}
// Import only whole-type-copyable bytes. An inactive Buffer alternative is still
// move-only and cannot be smuggled in by native bytes/serials through this path.
pub fn Result<usize,Error> initialize(ref layouts::Plan plan,ref mut State state,
    ref mut vec::Vec<bytes::Buffer> frames,Address destination,ref u8[] input,ref mut usize fuel){
    if(input.len>65536){return .err(.Bounds);}let usize spent=paid(operation(input.len)?,fuel)?;
    let Slot dst=address(plan,state,frames,destination,false)?;
    if(!dst.copyable){return .err(.Type);}if(input.len!=dst.width){return .err(.Bounds);}
    let codec::Active checked=switch(codec::inspect(layouts::layout(plan),dst.type_id,input)){
        case .ok(v):{v}case .err(_):{return .err(.Value);}
    };
    if(checked.present){return .err(.Owner);}
    let ref mut u8[] data=bytes::view_mut(vec::at_mut<bytes::Buffer>(frames,destination.frame));
    copy(input,data[dst.offset..dst.offset+dst.width]);publish(state,destination);return .ok(dst.width);
}
pub fn Result<usize,Error> scalar_value(ref layouts::Plan plan,ref mut State state,
    ref mut vec::Vec<bytes::Buffer> frames,Address destination,i64 value,ref mut usize fuel){
    // All scalar domains are at most eight bytes; reject before any backing work.
    let usize spent=paid(operation(8)?,fuel)?;let Slot dst=address(plan,state,frames,destination,false)?;
    let ref mut u8[] data=bytes::view_mut(vec::at_mut<bytes::Buffer>(frames,destination.frame));
    let usize size=switch(codec::write_scalar(layouts::layout(plan),dst.type_id,value,data[dst.offset..dst.offset+dst.width])){
        case .ok(v):{v}case .err(_):{return .err(.Value);}
    };
    publish(state,destination);return .ok(size);
}
pub fn Result<i64,Error> scalar_read(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Address source,ref mut usize fuel){
    let usize spent=paid(operation(8)?,fuel)?;let Slot src=address(plan,state,frames,source,true)?;
    let ref u8[] data=bytes::view(vec::at<bytes::Buffer>(frames,source.frame));
    return switch(codec::read_scalar(layouts::layout(plan),src.type_id,data[src.offset..src.offset+src.width])){
        case .ok(v):{.ok(v)}case .err(_):{.err(.Value)}
    };
}
pub fn Result<usize,Error> buffer_value(ref layouts::Plan plan,ref mut State state,
    ref mut vec::Vec<bytes::Buffer> frames,Address destination,ref u8[] input,
    ref mut owners::State root_state,ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,
    growth::Limits limits,ref mut usize fuel){
    var usize root_cost=switch(owners::create_cost(input.len)){case .ok(v):{v}case .err(_):{return .err(.Bounds);}};
    let usize cost=operation(8)?;if(root_cost>18446744073709551615-cost){return .err(.Bounds);}
    let usize spent=paid(cost+root_cost,fuel)?;let Slot dst=address(plan,state,frames,destination,false)?;
    let properties::Node n=switch(codec::node(layouts::layout(plan),dst.type_id)){case .ok(v):{v}case .err(_):{return .err(.Type);}};
    if(n.kind!=4){return .err(.Type);}
    let growth::Limits remaining=switch(meter::remaining(state.used,limits)){case .ok(v):{v}case .err(e):{return .err(metered(e));}};
    let i64 word=switch(cells::pack(root_state.next,0)){case .ok(v):{v}case .err(_):{return .err(.State);}};
    var u8[8] encoded=[0;8];if(!scalar::encode(12,word,ref mut encoded).is_ok){return .err(.State);}
    let usize serial=switch(owners::insert(root_state,roots,root_scratch,dst.binding,input,remaining,ref mut root_cost)){
        case .ok(v):{v}case .err(e):{return .err(owned(e));}
    };
    let ref mut u8[] data=bytes::view_mut(vec::at_mut<bytes::Buffer>(frames,destination.frame));
    copy(ref encoded,data[dst.offset..dst.offset+8]);publish(state,destination);return .ok(serial);
}
fn Result<codec::Active,Error> inspected(ref layouts::Plan plan,ref State state,ref vec::Vec<bytes::Buffer> frames,
    Address source,Slot src,ref owners::State root_state,ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> root_scratch){
    let ref u8[] data=bytes::view(vec::at<bytes::Buffer>(frames,source.frame));
    let codec::Active active=switch(codec::inspect(layouts::layout(plan),src.type_id,data[src.offset..src.offset+src.width])){
        case .ok(v):{v}case .err(_):{return .err(.Value);}
    };
    if(active.present && !owners::describe(root_state,roots,root_scratch,active.serial,src.binding).is_ok){return .err(.Owner);}
    return .ok(active);
}
// Instruction-local Buffer access authenticates exact declared type, native
// activation, canonical serial bytes and the store-local root binding. No view
// or mutable root escapes. Mutation keeps the slot word and init order unchanged.
pub struct BufferKey { usize serial; usize binding; }
fn Result<BufferKey,Error> buffer_key(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Address source,ref owners::State root_state,
    ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> root_scratch){
    let Slot src=address(plan,state,frames,source,true)?;
    let properties::Node n=switch(codec::node(layouts::layout(plan),src.type_id)){
        case .ok(v):{v}case .err(_):{return .err(.Type);}
    };
    if(n.kind!=4){return .err(.Type);}
    let codec::Active active=inspected(plan,state,frames,source,src,root_state,roots,root_scratch)?;
    if(!active.present){return .err(.Owner);}
    return .ok(BufferKey{.serial=active.serial,.binding=src.binding});
}
// Internal retained-view coordinator only. Authenticate the activation, exact
// Buffer type, canonical slot and root store before exposing a native key.
// This key must never be copied into guest scalar/value registers.
pub fn Result<BufferKey,Error> buffer_view_key(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Address source,ref owners::State root_state,
    ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> root_scratch,ref mut usize fuel){
    let usize spent=paid(operation(8)?,fuel)?;
    return buffer_key(plan,state,frames,source,root_state,roots,root_scratch);
}
pub fn Result<usize,Error> buffer_len(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Address source,ref owners::State root_state,
    ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> root_scratch,ref mut usize fuel){
    let usize spent=paid(operation(8)?,fuel)?;
    let BufferKey key=buffer_key(plan,state,frames,source,root_state,roots,root_scratch)?;
    return switch(owners::len(root_state,roots,root_scratch,key.serial,key.binding,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(owned(e))}
    };
}
pub fn Result<u8,Error> buffer_read(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Address source,usize index,ref owners::State root_state,
    ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> root_scratch,ref mut usize fuel){
    let usize spent=paid(operation(8)?,fuel)?;
    let BufferKey key=buffer_key(plan,state,frames,source,root_state,roots,root_scratch)?;
    return switch(owners::read(root_state,roots,root_scratch,key.serial,key.binding,index,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(owned(e))}
    };
}
pub fn Result<usize,Error> buffer_write(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Address source,usize index,u8 value,ref owners::State root_state,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,
    growth::Limits limits,ref mut usize fuel){
    let usize spent=paid(operation(8)?,fuel)?;
    let BufferKey key=buffer_key(plan,state,frames,source,root_state,roots,root_scratch)?;
    let growth::Limits remaining=switch(meter::remaining(state.used,limits)){
        case .ok(v):{v}case .err(e):{return .err(metered(e));}
    };
    let u8[1] input=[value];
    return switch(owners::write(root_state,roots,root_scratch,key.serial,key.binding,index,ref input,remaining,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(owned(e))}
    };
}
pub fn Result<usize,Error> buffer_append(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Address source,ref u8[] input,ref mut owners::State root_state,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,
    growth::Limits limits,ref mut usize fuel){
    let usize spent=paid(operation(8)?,fuel)?;
    let BufferKey key=buffer_key(plan,state,frames,source,root_state,roots,root_scratch)?;
    let growth::Limits remaining=switch(meter::remaining(state.used,limits)){
        case .ok(v):{v}case .err(e):{return .err(metered(e));}
    };
    return switch(owners::append(root_state,roots,root_scratch,key.serial,key.binding,input,remaining,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(owned(e))}
    };
}
pub fn Result<usize,Error> buffer_append_from(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Address destination,Address source,
    ref mut owners::State root_state,ref mut vec::Vec<bytes::Buffer> roots,
    ref mut vec::Vec<bytes::Buffer> root_scratch,growth::Limits limits,ref mut usize fuel){
    let usize spent=paid(operation(8)?,fuel)?;
    let BufferKey dst=buffer_key(plan,state,frames,destination,root_state,roots,root_scratch)?;
    let BufferKey src=buffer_key(plan,state,frames,source,root_state,roots,root_scratch)?;
    let growth::Limits remaining=switch(meter::remaining(state.used,limits)){
        case .ok(v):{v}case .err(e):{return .err(metered(e));}
    };
    return switch(owners::append_from(root_state,roots,root_scratch,dst.serial,dst.binding,
        src.serial,src.binding,remaining,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(owned(e))}
    };
}
pub fn Result<usize,Error> buffer_push(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Address source,u8 value,ref mut owners::State root_state,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,
    growth::Limits limits,ref mut usize fuel){
    let u8[1] input=[value];return buffer_append(plan,state,frames,source,ref input,root_state,roots,root_scratch,limits,fuel);
}
pub fn Result<usize,Error> buffer_reserve(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Address source,usize required,ref mut owners::State root_state,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,
    growth::Limits limits,ref mut usize fuel){
    let usize spent=paid(operation(8)?,fuel)?;
    let BufferKey key=buffer_key(plan,state,frames,source,root_state,roots,root_scratch)?;
    let growth::Limits remaining=switch(meter::remaining(state.used,limits)){
        case .ok(v):{v}case .err(e):{return .err(metered(e));}
    };
    return switch(owners::reserve(root_state,roots,root_scratch,key.serial,key.binding,required,remaining,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(owned(e))}
    };
}
fn Result<usize,Error> scratch_ready(ref layouts::Plan plan,ref vec::Vec<bytes::Buffer> scratch){
    if(vec::len<bytes::Buffer>(scratch)!=1){return .err(.State);}
    let ref bytes::Buffer b=vec::at<bytes::Buffer>(scratch,0);let usize width=layouts::largest(plan);
    if(bytes::len(b)!=width || bytes::capacity(b)!=capacity(width)){return .err(.State);}return .ok(width);
}
fn Result<properties::Property,Error> declared(ref layouts::Plan plan,ref State state,Address at){
    if(at.slot>=16 || at.frame>=32){return .err(.Bounds);}
    let usize id=switch(layouts::type_id(plan,at.slot,state.frames[at.frame].function)){
        case .ok(v):{v}case .err(_):{return .err(.Type);}
    };
    return switch(codec::shape(layouts::layout(plan),id)){case .ok(v):{.ok(v)}case .err(_):{.err(.Type)}};
}
fn Result<usize,Error> handoff(codec::Active active,usize source,usize destination,
    ref mut owners::State root_state,ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch){
    if(active.present){var usize prepaid=owners::move_cost();
        if(!owners::move(root_state,roots,root_scratch,active.serial,source,destination,ref mut prepaid).is_ok){return .err(.Owner);}
    }return .ok(destination);
}
fn void unstaged(ref mut vec::Vec<bytes::Buffer> frames,ref vec::Vec<bytes::Buffer> scratch,Address destination,Slot dst){
    let ref u8[] temp=bytes::view(vec::at<bytes::Buffer>(scratch,0));
    let ref mut u8[] data=bytes::view_mut(vec::at_mut<bytes::Buffer>(frames,destination.frame));
    copy(temp[..dst.width],data[dst.offset..dst.offset+dst.width]);
}
// Logical some/ok1 and none/err0 translate explicitly to the canonical byte tags.
// Inactive resource alternatives affect copyability, never active-root discovery.
pub fn Result<usize,Error> build_tag(ref layouts::Plan plan,ref mut State state,
    ref mut vec::Vec<bytes::Buffer> frames,ref mut vec::Vec<bytes::Buffer> scratch,
    Address destination,Address source,u8 variant,ref mut owners::State root_state,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,ref mut usize fuel){
    let properties::Property p=declared(plan,state,destination)?;let usize spent=paid(operation(p.bytes)?,fuel)?;
    let Slot dst=address(plan,state,frames,destination,false)?;
    let properties::Node n=switch(codec::node(layouts::layout(plan),dst.type_id)){case .ok(v):{v}case .err(_):{return .err(.Type);}};
    if((n.kind!=5 && n.kind!=6) || variant>1){return .err(.Type);}
    let usize available=scratch_ready(plan,scratch)?;if(dst.width>available){return .err(.State);}
    let bool payload=n.kind==6 || variant==1;
    var Slot src=Slot{.type_id=0,.offset=0,.width=0,.binding=0,.copyable=true};
    var codec::Active active=codec::Active{.present=false,.offset=0,.serial=0};
    if(payload){
        src=address(plan,state,frames,source,true)?;let usize child=if(variant==1){n.first as usize}else{n.second as usize};
        if(!switch(codec::same(layouts::layout(plan),child,src.type_id)){case .ok(v):{v}case .err(_):{false}}){return .err(.Type);}
        active=inspected(plan,state,frames,source,src,root_state,roots,root_scratch)?;
    }
    {let ref mut u8[] temp=bytes::view_mut(vec::at_mut<bytes::Buffer>(scratch,0));var usize i=0;
        while(i<dst.width){temp[i]=0;i+=1;}
        temp[0]=if(n.kind==6){if(variant==1){0}else{1}}else{variant};
        if(payload){let ref u8[] data=bytes::view(vec::at<bytes::Buffer>(frames,source.frame));
            copy(data[src.offset..src.offset+src.width],temp[p.payload_offset..p.payload_offset+src.width]);}
        if(!codec::inspect(layouts::layout(plan),dst.type_id,temp[..dst.width]).is_ok){return .err(.Value);}
    }
    let usize rebound=handoff(active,src.binding,dst.binding,root_state,roots,root_scratch)?;
    unstaged(frames,scratch,destination,dst);
    if(payload && !src.copyable){erase(frames,source,src);dead(state,source);}
    publish(state,destination);return .ok(dst.width);
}
// Read-only inspection of the whole live wrapper, including active Buffer root
// authentication. codec::select repeats the canonical scan; the explicit price
// covers both scans. Neither a match nor a mismatch extracts/consumes payloads.
pub fn Result<bool,Error> tag_test(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Address source,u8 variant,
    ref owners::State root_state,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> root_scratch,ref mut usize remaining){
    let properties::Property p=declared(plan,state,source)?;
    let usize spent=paid(fuel::value_tag_test(p.bytes),remaining)?;
    let Slot src=address(plan,state,frames,source,true)?;
    let codec::Active active=inspected(plan,state,frames,source,src,root_state,roots,root_scratch)?;
    let codec::Selection selected=switch(codec::select(layouts::layout(plan),src.type_id,variant,
        bytes::view(vec::at<bytes::Buffer>(frames,source.frame))[src.offset..src.offset+src.width])){
        case .ok(v):{v}case .err(_):{return .err(.Type);}
    };
    return .ok(selected.matched);
}
pub fn Result<Case,Error> case_value(ref layouts::Plan plan,ref mut State state,
    ref mut vec::Vec<bytes::Buffer> frames,ref mut vec::Vec<bytes::Buffer> scratch,
    Address source,u8 variant,Address destination,ref mut owners::State root_state,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,ref mut usize fuel){
    let properties::Property p=declared(plan,state,source)?;let usize spent=paid(operation(p.bytes)?,fuel)?;
    let Slot src=address(plan,state,frames,source,true)?;
    let codec::Active active=inspected(plan,state,frames,source,src,root_state,roots,root_scratch)?;
    let codec::Selection selected=switch(codec::select(layouts::layout(plan),src.type_id,variant,
        bytes::view(vec::at<bytes::Buffer>(frames,source.frame))[src.offset..src.offset+src.width])){
        case .ok(v):{v}case .err(_):{return .err(.Type);}
    };
    if(!selected.matched){return .ok(Case{.matched=false,.payload=false});}
    if(selected.payload){
        let Slot dst=address(plan,state,frames,destination,false)?;
        if(!switch(codec::same(layouts::layout(plan),selected.type_id,dst.type_id)){case .ok(v):{v}case .err(_):{false}}){return .err(.Type);}
        let usize available=scratch_ready(plan,scratch)?;
        if(selected.bytes!=dst.width || selected.bytes>available){return .err(.State);}
        {let ref u8[] data=bytes::view(vec::at<bytes::Buffer>(frames,source.frame));
            let ref mut u8[] temp=bytes::view_mut(vec::at_mut<bytes::Buffer>(scratch,0));
            copy(data[src.offset+selected.offset..src.offset+selected.offset+selected.bytes],temp[..dst.width]);}
        let usize rebound=handoff(active,src.binding,dst.binding,root_state,roots,root_scratch)?;
        unstaged(frames,scratch,destination,dst);publish(state,destination);
    }else if(active.present){return .err(.Owner);}
    // Whole-wrapper ownership decides consumption even for scalar/none matches.
    if(!src.copyable){erase(frames,source,src);dead(state,source);}
    return .ok(Case{.matched=true,.payload=selected.payload});
}
// Covers distinct activations, including recursive ones with identical static
// slot IDs. COPY retains the source; MOVE transfers its sole active root binding.
// Pure preflights for the trusted invocation coordinator. It prepays their work
// and must allow no intervening mutation before publishing the checked batch.
pub fn Result<usize,Error> inspect_frame(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Token token){
    return active_frame(plan,state,frames,token.frame,token.generation);
}
pub fn Result<Slot,Error> inspect_destination(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,Address destination){
    return address(plan,state,frames,destination,false);
}
pub fn Result<usize,Error> inspect_transfer(ref layouts::Plan plan,ref State state,
    ref vec::Vec<bytes::Buffer> frames,ref vec::Vec<bytes::Buffer> scratch,
    Address source,Address destination,bool copying,ref owners::State root_state,
    ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> root_scratch){
    let Slot src=address(plan,state,frames,source,true)?;let Slot dst=address(plan,state,frames,destination,false)?;
    if((copying && !src.copyable) || !switch(codec::same(layouts::layout(plan),src.type_id,dst.type_id)){
        case .ok(v):{v}case .err(_):{false}}){return .err(.Type);}
    let usize available=scratch_ready(plan,scratch)?;if(src.width>available || src.width!=dst.width){return .err(.State);}
    let codec::Active active=inspected(plan,state,frames,source,src,root_state,roots,root_scratch)?;
    if(active.present){var usize i=0;while(i<vec::len<bytes::Buffer>(roots)){
        if(root_state.rows[i].binding==dst.binding){return .err(.Owner);}i+=1;
    }}
    return .ok(src.width);
}
pub fn Result<usize,Error> transfer(ref layouts::Plan plan,ref mut State state,
    ref mut vec::Vec<bytes::Buffer> frames,ref mut vec::Vec<bytes::Buffer> scratch,
    Address source,Address destination,bool copying,ref mut owners::State root_state,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch,ref mut usize fuel){
    // Derive a bounded template from immutable metadata before live/native checks.
    if(source.slot>=16 || source.frame>=32){return .err(.Bounds);}
    let usize id=switch(layouts::type_id(plan,source.slot,state.frames[source.frame].function)){
        case .ok(v):{v}case .err(_):{return .err(.Type);}
    };
    let properties::Property p=switch(codec::shape(layouts::layout(plan),id)){case .ok(v):{v}case .err(_):{return .err(.Type);}};
    let usize spent=paid(operation(p.bytes)?,fuel)?;
    let Slot src=address(plan,state,frames,source,true)?;let Slot dst=address(plan,state,frames,destination,false)?;
    if((copying && !src.copyable) || !switch(codec::same(layouts::layout(plan),src.type_id,dst.type_id)){
        case .ok(v):{v}case .err(_):{false}}){return .err(.Type);}
    let usize available=scratch_ready(plan,scratch)?;if(src.width>available || src.width!=dst.width){return .err(.State);}
    let codec::Active active=inspected(plan,state,frames,source,src,root_state,roots,root_scratch)?;
    {let ref u8[] data=bytes::view(vec::at<bytes::Buffer>(frames,source.frame));
        let ref mut u8[] temp=bytes::view_mut(vec::at_mut<bytes::Buffer>(scratch,0));
        copy(data[src.offset..src.offset+src.width],temp[..src.width]);}
    if(active.present){var usize prepaid=owners::move_cost();
        if(!owners::move(root_state,roots,root_scratch,active.serial,src.binding,dst.binding,ref mut prepaid).is_ok){return .err(.Owner);}
    }
    {let ref u8[] temp=bytes::view(vec::at<bytes::Buffer>(scratch,0));
        let ref mut u8[] data=bytes::view_mut(vec::at_mut<bytes::Buffer>(frames,destination.frame));
        copy(temp[..src.width],data[dst.offset..dst.offset+dst.width]);}
    if(!copying){erase(frames,source,src);dead(state,source);}
    publish(state,destination);return .ok(src.width);
}
fn Result<usize,Error> retire(ref layouts::Plan plan,ref mut State state,ref mut vec::Vec<bytes::Buffer> frames,
    Address source,ref mut owners::State root_state,ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch){
    let Slot src=address(plan,state,frames,source,true)?;
    let codec::Active active=inspected(plan,state,frames,source,src,root_state,roots,root_scratch)?;
    if(active.present){var usize prepaid=owners::drop_cost();
        if(!owners::drop(root_state,roots,root_scratch,active.serial,src.binding,ref mut prepaid).is_ok){return .err(.Owner);}
    }
    erase(frames,source,src);dead(state,source);return .ok(src.width);
}
pub fn Result<usize,Error> drop(ref layouts::Plan plan,ref mut State state,ref mut vec::Vec<bytes::Buffer> frames,
    Address source,ref mut owners::State root_state,ref mut vec::Vec<bytes::Buffer> roots,
    ref mut vec::Vec<bytes::Buffer> root_scratch,ref mut usize fuel){
    if(source.slot>=16 || source.frame>=32){return .err(.Bounds);}
    let usize id=switch(layouts::type_id(plan,source.slot,state.frames[source.frame].function)){case .ok(v):{v}case .err(_):{return .err(.Type);}};
    let properties::Property p=switch(codec::shape(layouts::layout(plan),id)){case .ok(v):{v}case .err(_):{return .err(.Type);}};
    let usize spent=paid(operation(p.bytes)?,fuel)?;return retire(plan,state,frames,source,root_state,roots,root_scratch);
}
// Frame entry prepaid reverse initialization-order cleanup and backing release.
// No guest callback or additional Fuel is required, even at zero remaining Fuel.
pub fn Result<usize,Error> leave(ref layouts::Plan plan,ref mut State state,
    ref mut vec::Vec<bytes::Buffer> frames,Token token,ref mut owners::State root_state,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch){
    let usize width=active_frame(plan,state,frames,token.frame,token.generation)?;
    if(token.frame+1!=state.depth){return .err(.State);}
    let usize one=1;
    while(state.frames[token.frame].live!=0){var usize selected=16;var usize last=0;var usize i=0;
        while(i<16){if((state.frames[token.frame].live&(one<<i))!=0){let usize order=state.order[token.frame*16+i];
            if(order>last){last=order;selected=i;}}i+=1;}
        if(selected==16){return .err(.State);}
        let usize removed=retire(plan,state,frames,Address{.frame=token.frame,.generation=token.generation,.slot=selected},root_state,roots,root_scratch)?;
    }
    {let bytes::Buffer disposed=switch(vec::pop<bytes::Buffer>(frames)){case .some(v):{v}case .none:{assert(false);bytes::empty()}};}
    state.used-=charge(width);state.frames[token.frame]=blank();state.depth-=1;return .ok(state.used);
}
// Failure cleanup trusts only native ledgers/owners, never guest value bytes,
// tags, initialized masks or source-program cleanup instructions.
pub fn Result<usize,Error> abort(ref mut State state,ref mut vec::Vec<bytes::Buffer> frames,
    ref mut vec::Vec<bytes::Buffer> scratch,ref mut owners::State root_state,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> root_scratch){
    if(state.closed){return .ok(0);}
    if(!owners::drain(root_state,roots,root_scratch).is_ok){return .err(.Owner);}
    let usize removed=vec::clear<bytes::Buffer>(frames);let usize cleared=vec::clear<bytes::Buffer>(scratch);
    state.depth=0;state.used=0;state.closed=true;var usize i=0;
    while(i<32){state.frames[i]=blank();i+=1;}i=0;while(i<512){state.order[i]=0;i+=1;}
    return .ok(0);
}
