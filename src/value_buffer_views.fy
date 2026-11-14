module value_buffer_views;
import value_roots as roots;
import buffer_owners as owners;
import buffer_growth as growth;
import std::bytes as bytes;
import std::vec as vec;

// One registry belongs to one native invocation's exact root store/vectors.
// Tickets and this copyable bookkeeping are private coordinator metadata, never
// guest words, native views or executable authority. Like value_roots::State,
// the coordinator must not clone/transplant it or mix invocation stores.
pub struct Ticket { usize slot; usize generation; }
pub struct Row { usize generation; bool live; usize binding; usize serial;
    usize owner_binding; usize owner_slot; usize owner_generation; usize start; usize length; }
pub struct Pool { Row[32] rows; bool closed; }
pub struct Snapshot { usize live; usize roots; bool closed; }
pub enum Error { Fuel; State; Binding; Stale; Capacity; Bounds; Quota; Allocation; }
pub fn usize capacity(){return 32;}
pub fn usize metadata_charge(){return 4096;}
pub fn usize begin_cost(){return 512;}
pub fn usize range_cost(){return 512;}
pub fn usize move_cost(){return 256;}
pub fn usize length_cost(){return 256;}
pub fn usize read_cost(){return 513;}
pub fn Result<usize,Error> copy_cost(usize length){
    if(length>18446744073709551103){return .err(.Bounds);}return .ok(512+length);
}
pub fn Result<usize,Error> append_to_cost(usize old_length,usize length){
    let usize cost=switch(roots::append_from_cost(old_length,length)){
        case .ok(v):{v}case .err(e):{return .err(root_error(e));}
    };
    if(cost>18446744073709551359){return .err(.Bounds);}return .ok(256+cost);
}
fn Error root_error(roots::Error e){return switch(e){case .Fuel:{.Fuel}case .State:{.State}
    case .Binding:{.Binding}case .Serial:{.Stale}case .Owners:{.Capacity}
    case .Quota:{.Quota}case .Allocation:{.Allocation}case .Bounds:{.Bounds}};}
fn Result<usize,Error> pay(usize charge,ref mut usize fuel){
    let usize available=*fuel;if(available<charge){return .err(.Fuel);};*fuel=available-charge;return .ok(charge);
}
fn Row blank(usize generation){return Row{.generation=generation,.live=false,.binding=512,
    .serial=0,.owner_binding=512,.owner_slot=16,.owner_generation=0,.start=0,.length=0};}
fn owners::Token token(Row row){return owners::Token{.slot=row.owner_slot,.generation=row.owner_generation};}

fn Row get(ref Pool pool,usize slot){assert(slot<32);return pool.rows[slot];}
fn void put(ref mut Pool pool,usize slot,Row row){assert(slot<32);pool.rows[slot]=row;}
pub fn Result<Pool,Error> open(ref mut roots::State store,ref vec::Vec<bytes::Buffer> data,
    ref vec::Vec<bytes::Buffer> scratch,growth::Limits limits,ref mut usize fuel){
    switch(roots::admit_metadata(store,data,scratch,metadata_charge(),limits,fuel)){
        case .ok(_):{}case .err(e):{return .err(root_error(e));}
    };
    return .ok(Pool{.rows=[blank(1);32],.closed=false});
}
fn Result<usize,Error> header(ref Pool pool){
    if(pool.closed){return .err(.State);}var usize i=0;
    while(i<32){let Row row=get(pool,i);
        if(row.live){
            if(row.generation==0 || row.binding>=512 || row.serial==0 || row.owner_binding>=512 ||
                row.owner_slot>=16 || row.owner_generation==0){return .err(.State);}
            var usize j=0;while(j<i){let Row other=get(pool,j);if(other.live){
                if(other.binding==row.binding || (other.serial==row.serial &&
                    (other.owner_binding!=row.owner_binding || other.owner_slot!=row.owner_slot ||
                        other.owner_generation!=row.owner_generation))){return .err(.State);}
            }j+=1;}
        }else if(row.binding!=512 || row.serial!=0 || row.owner_binding!=512 ||
            row.owner_slot!=16 || row.owner_generation!=0 || row.start!=0 || row.length!=0){return .err(.State);}
        i+=1;
    }return .ok(0);
}
fn Result<usize,Error> binding(ref Pool pool,usize destination,usize except){
    if(destination>=512){return .err(.Binding);}var usize i=0;
    while(i<32){if(i!=except && get(pool,i).live &&
        get(pool,i).binding==destination){return .err(.Binding);}i+=1;}return .ok(destination);
}
fn Result<usize,Error> vacant(ref Pool pool,usize destination){
    let usize checked=header(pool)?;let usize available=binding(pool,destination,32)?;
    var usize i=0;while(i<32){if(!get(pool,i).live && get(pool,i).generation!=0){return .ok(i);}i+=1;}
    return .err(.Capacity);
}
fn Result<Row,Error> resolve(ref Pool pool,ref roots::State store,ref vec::Vec<bytes::Buffer> data,
    ref vec::Vec<bytes::Buffer> scratch,Ticket ticket,usize selected){
    let usize checked=header(pool)?;
    if(ticket.slot>=32 || ticket.generation==0){return .err(.Stale);}
    let Row row=get(pool,ticket.slot);
    if(!row.live || row.generation!=ticket.generation){return .err(.Stale);}
    if(row.binding!=selected){return .err(.Binding);}
    let owners::Owner owner=switch(roots::describe(store,data,scratch,row.serial,row.owner_binding)){
        case .ok(v):{v}case .err(e):{return .err(root_error(e));}
    };
    if(!owner.reading || owner.generation!=row.owner_generation || row.start>owner.length ||
        row.length>owner.length-row.start){return .err(.State);}
    var bool matched=false;var usize i=0;while(i<16){let roots::Row actual=store.rows[i];
        if(actual.serial==row.serial && actual.binding==row.owner_binding &&
            actual.slot==row.owner_slot && actual.generation==row.owner_generation){matched=true;}i+=1;}
    if(!matched){return .err(.State);}return .ok(row);
}
// Invocation-local lookup by a coordinator binding, never a guest-provided
// ticket or serial. Authenticate the exact lease/root/backing before returning.
pub fn Result<Ticket,Error> lookup(ref Pool pool,ref roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,usize selected){
    // resolve checks the complete header before any ticket/root/native access.
    // The bounded search only reads metadata; avoid validating twice on a hit.
    if(selected>=512){let usize checked=header(pool)?;return .err(.Binding);}var usize i=0;
    while(i<32){let Row row=get(pool,i);if(row.live && row.binding==selected){
        let Ticket ticket=Ticket{.slot=i,.generation=row.generation};
        let Row authenticated=resolve(pool,store,data,scratch,ticket,selected)?;
        return .ok(ticket);
    }i+=1;}
    // Preserve State-before-Binding diagnostics when no row matches as well.
    let usize checked=header(pool)?;return .err(.Binding);
}
fn Ticket publish(ref mut Pool pool,usize slot,usize destination,usize serial,usize owner_binding,
    owners::Token owner,usize start,usize length){
    let usize generation=get(pool,slot).generation;
    put(pool,slot,Row{.generation=generation,.live=true,.binding=destination,
        .serial=serial,.owner_binding=owner_binding,.owner_slot=owner.slot,.owner_generation=owner.generation,.start=start,.length=length});
    return Ticket{.slot=slot,.generation=generation};
}
pub fn Result<Ticket,Error> begin(ref mut Pool pool,ref mut roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,usize serial,
    usize owner_binding,usize destination,usize lo,usize hi,ref mut usize fuel){
    let usize paid=pay(begin_cost(),fuel)?;let usize slot=vacant(pool,destination)?;
    let owners::Owner described=switch(roots::describe(store,data,scratch,serial,owner_binding)){
        case .ok(v):{v}case .err(e):{return .err(root_error(e));}
    };
    if(lo>hi || hi>described.length){return .err(.Bounds);}
    var usize shared=32;var usize i=0;while(i<32){if(get(pool,i).live &&
        get(pool,i).serial==serial){shared=i;break;}i+=1;}
    var owners::Token owner=owners::Token{.slot=16,.generation=0};
    if(shared!=32){let Row prior=get(pool,shared);
        let Row valid=resolve(pool,store,data,scratch,Ticket{.slot=shared,.generation=prior.generation},prior.binding)?;
        if(valid.owner_binding!=owner_binding){return .err(.Binding);}owner=token(valid);
    }else{owner=switch(roots::begin_read(store,data,scratch,serial,owner_binding,fuel)){
        case .ok(v):{v}case .err(e):{return .err(root_error(e));}
    };}
    return .ok(publish(pool,slot,destination,serial,owner_binding,owner,lo,hi-lo));
}
pub fn Result<Ticket,Error> range(ref mut Pool pool,ref mut roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,Ticket source,
    usize selected,usize destination,usize lo,usize hi,ref mut usize fuel){
    let usize paid=pay(range_cost(),fuel)?;let Row parent=resolve(pool,store,data,scratch,source,selected)?;
    let usize slot=vacant(pool,destination)?;
    if(lo>hi || hi>parent.length){return .err(.Bounds);}
    return .ok(publish(pool,slot,destination,parent.serial,parent.owner_binding,token(parent),parent.start+lo,hi-lo));
}
pub fn Result<Ticket,Error> alias(ref mut Pool pool,ref mut roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,Ticket source,
    usize selected,usize destination,ref mut usize fuel){
    let usize paid=pay(range_cost(),fuel)?;let Row parent=resolve(pool,store,data,scratch,source,selected)?;
    let usize slot=vacant(pool,destination)?;
    return .ok(publish(pool,slot,destination,parent.serial,parent.owner_binding,token(parent),parent.start,parent.length));
}
// Atomic native CALL bindings. Resolve every source against the original pool,
// never against an earlier staged destination. The fixed pool copy contains no
// payload or owning root; all aliases retain the existing physical read lease.
pub fn Result<usize,Error> aliases(ref mut Pool pool,ref roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,
    ref usize[] sources,ref usize[] destinations,ref mut usize fuel){
    if(sources.len!=destinations.len){return .err(.Binding);}
    if(sources.len>8){return .err(.Capacity);}
    let usize paid=pay(range_cost()*sources.len,fuel)?;
    let usize checked=header(pool)?;
    if(sources.len==0){return .ok(0);}
    var Pool staged=*pool;var usize i=0;
    while(i<sources.len){
        let Ticket source=lookup(pool,store,data,scratch,sources[i])?;
        let Row row=resolve(pool,store,data,scratch,source,sources[i])?;
        let usize slot=vacant(ref staged,destinations[i])?;
        let Ticket added=publish(ref mut staged,slot,destinations[i],row.serial,
            row.owner_binding,token(row),row.start,row.length);
        i+=1;
    }
    *pool=staged;return .ok(sources.len);
}
pub fn Result<Ticket,Error> move(ref mut Pool pool,ref mut roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,Ticket source,
    usize selected,usize destination,ref mut usize fuel){
    let usize paid=pay(move_cost(),fuel)?;let Row row=resolve(pool,store,data,scratch,source,selected)?;
    let usize checked=binding(pool,destination,source.slot)?;
    var Row moved=row;moved.binding=destination;put(pool,source.slot,moved);return .ok(source);
}
// Native RETURN bookkeeping only. The outer frame coordinator authenticates
// caller tokens/adjacency and cleanup; tickets/bindings confer no guest authority.
pub fn Result<Ticket,Error> handoff(ref mut Pool pool,ref mut roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,Ticket source,
    usize selected,usize destination,Ticket origin,usize origin_binding,ref mut usize fuel){
    let usize paid=pay(move_cost(),fuel)?;
    let Row row=resolve(pool,store,data,scratch,source,selected)?;
    let Row caller=resolve(pool,store,data,scratch,origin,origin_binding)?;
    if(row.serial!=caller.serial || row.owner_binding!=caller.owner_binding ||
        row.owner_slot!=caller.owner_slot || row.owner_generation!=caller.owner_generation){return .err(.Binding);}
    if(row.start<caller.start){return .err(.Bounds);}
    let usize offset=row.start-caller.start;
    if(offset>caller.length || row.length>caller.length-offset){return .err(.Bounds);}
    if(destination==selected){return .err(.Binding);}
    var usize prepaid=move_cost();
    return move(pool,store,data,scratch,source,selected,destination,ref mut prepaid);
}
pub fn Result<usize,Error> length(ref Pool pool,ref roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,Ticket source,
    usize selected,ref mut usize fuel){
    let usize paid=pay(length_cost(),fuel)?;let Row row=resolve(pool,store,data,scratch,source,selected)?;
    return .ok(row.length);
}
pub fn Result<u8,Error> read(ref Pool pool,ref roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,Ticket source,
    usize selected,usize index,ref mut usize fuel){
    let usize paid=pay(256,fuel)?;let Row row=resolve(pool,store,data,scratch,source,selected)?;
    if(index>=row.length){return .err(.Bounds);}
    return switch(roots::read(store,data,scratch,row.serial,row.owner_binding,row.start+index,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(root_error(e))}
    };
}
pub fn Result<usize,Error> copy_out(ref Pool pool,ref roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,Ticket source,
    usize selected,ref mut u8[] output,ref mut usize fuel){
    let usize bounded=copy_cost(output.len)?;let usize paid=pay(256,fuel)?;
    let Row row=resolve(pool,store,data,scratch,source,selected)?;
    if(output.len!=row.length){return .err(.Bounds);}
    return switch(roots::copy_out(store,data,scratch,row.serial,row.owner_binding,row.start,output,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(root_error(e))}
    };
}
// Authenticate the exact registry row and root lease before asking roots to
// copy. No ticket mutation, intermediate payload or escaping native view.
pub fn Result<usize,Error> append_to(ref Pool pool,ref mut roots::State store,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,
    Ticket ticket,usize selected,usize dest_serial,usize dest_binding,
    growth::Limits limits,ref mut usize fuel){
    let usize paid=pay(256,fuel)?;let Row row=resolve(pool,store,data,scratch,ticket,selected)?;
    return switch(roots::append_window(store,data,scratch,dest_serial,dest_binding,
        row.serial,row.owner_binding,row.start,row.length,limits,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(root_error(e))}
    };
}
// Opening prepays bounded close. The last sibling releases the one actual root
// lease; failed authentication leaves the row live so explicit repair can retry.
pub fn Result<usize,Error> close(ref mut Pool pool,ref mut roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,Ticket source,usize selected){
    let Row row=resolve(pool,store,data,scratch,source,selected)?;var usize siblings=0;var usize i=0;
    while(i<32){if(i!=source.slot && get(pool,i).live &&
        get(pool,i).serial==row.serial){siblings+=1;}i+=1;}
    if(siblings==0){switch(roots::end_read(store,data,scratch,row.serial,row.owner_binding,token(row))){
        case .ok(_):{}case .err(e):{return .err(root_error(e));}
    };}
    put(pool,source.slot,blank(if(row.generation==18446744073709551615){0}else{row.generation+1}));
    return .ok(siblings);
}
pub fn Snapshot snapshot(ref Pool pool){
    var usize live=0;var usize count=0;var usize i=0;
    while(i<32){let Row row=get(pool,i);if(row.live){live+=1;var bool first=true;var usize j=0;
        while(j<i){if(get(pool,j).live && get(pool,j).serial==row.serial){first=false;}j+=1;}
        if(first){count+=1;}
    }i+=1;}return Snapshot{.live=live,.roots=count,.closed=pool.closed};
}
pub fn Result<usize,Error> shutdown(ref mut Pool pool,ref mut roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch){
    if(pool.closed){return .ok(0);}let usize checked=header(pool)?;var usize i=0;
    while(i<32){let Row row=get(pool,i);if(row.live){
        let usize closed=close(pool,store,data,scratch,Ticket{.slot=i,.generation=row.generation},row.binding)?;
    }i+=1;}
    switch(roots::release_metadata(store,data,scratch,metadata_charge())){
        case .ok(_):{}case .err(e):{return .err(root_error(e));}
    };
    pool.closed=true;return .ok(0);
}
