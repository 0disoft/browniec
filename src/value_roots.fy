module value_roots;
import std::bytes as bytes;
import std::vec as vec;
import buffer_owners as owners;
import buffer_growth as growth;
import buffer_create as create;
import buffer_storage as storage;
import buffer_transfer as transfer;
import buffer_close as close;
import buffer_append as buffer_append;
import buffer_write as buffer_write;
import buffer_replacement as replacement;

// Trusted native invocation state, not guest authority. Its coordinator owns
// the two vectors for this exact lifetime and never transplants their contents
// or this copyable metadata. No API accepts an external root/owner association.
// All root creation, binding, handoff and retirement go through this module.
pub struct Row { usize serial; usize binding; usize slot; usize generation; }
pub struct State {
    Row[16] rows; owners::Table table; growth::Ledger ledger;
    close::Plan closing; usize next; bool closed;
}
pub enum Error { Fuel; State; Binding; Serial; Owners; Quota; Allocation; Bounds; }
pub struct Snapshot { usize count; usize used; usize peak; usize next; bool closed; }
// Logical policy charges, not native sizeof/RAM. Setup includes bounded failure
// sweeping of all sixteen roots, without guest code or further Fuel admission.
pub fn usize metadata_charge(){return 4096;}
pub fn usize setup_cost(){return 32768;}
pub fn usize move_cost(){return 1024;}
pub fn usize drop_cost(){return 1024;}
pub fn usize len_cost(){return 256;}
pub fn usize read_cost(){return 257;}
pub fn Result<usize,Error> write_cost(usize length){
    if(length>18446744073709551359){return .err(.Bounds);}return .ok(256+length);
}
pub fn Result<usize,Error> reserve_cost(usize old_length){
    if(old_length>4611686018427387391){return .err(.Bounds);}return .ok(2048+4*old_length);
}
pub fn Result<usize,Error> append_cost(usize old_length,usize input_length){
    if(input_length>18446744073709551615-old_length){return .err(.Bounds);}
    return reserve_cost(old_length+input_length);
}
pub fn Result<usize,Error> create_cost(usize length){
    if(length>4611686018427387391){return .err(.Bounds);}return .ok(2048+4*length);
}
fn Result<usize,Error> pay(usize amount,ref mut usize fuel){
    let usize available=*fuel;if(available<amount){return .err(.Fuel);};
    *fuel=available-amount;return .ok(amount);
}
fn Row blank(){return Row{.serial=0,.binding=512,.slot=16,.generation=0};}
pub fn Result<State,Error> open(ref mut vec::Vec<bytes::Buffer> roots,
    ref mut vec::Vec<bytes::Buffer> scratch,growth::Limits limits,ref mut usize fuel){
    let usize paid=pay(setup_cost(),fuel)?;
    var growth::Ledger ledger=growth::unowned();
    if(!growth::admit_metadata(metadata_charge(),limits,ref mut ledger).is_ok){return .err(.Quota);}
    if(vec::len<bytes::Buffer>(roots)!=0 || vec::len<bytes::Buffer>(scratch)!=0){return .err(.State);}
    if(!vec::reserve<bytes::Buffer>(roots,16).is_ok ||
        !vec::reserve<bytes::Buffer>(scratch,16).is_ok){return .err(.Allocation);}
    return .ok(State{.rows=[blank();16],
        .table=owners::empty(),.ledger=ledger,.closing=close::empty(),.next=1,.closed=false});
}
pub fn Snapshot snapshot(ref State s,ref vec::Vec<bytes::Buffer> roots){return Snapshot{.count=vec::len<bytes::Buffer>(roots),
    .used=s.ledger.used,.peak=s.ledger.peak,.next=s.next,.closed=s.closed};}
fn Result<usize,Error> ready(ref State s,ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> scratch){
    let usize count=vec::len<bytes::Buffer>(roots);
    if(s.closed || count>16 || vec::len<bytes::Buffer>(scratch)!=0 ||
        vec::capacity<bytes::Buffer>(roots)<16 || vec::capacity<bytes::Buffer>(scratch)<16 ||
        s.closing.active || !growth::settled(ref s.ledger)){return .err(.State);}
    let usize accounted=switch(owners::accounted(ref s.table)){case .ok(v):{v}case .err(_):{return .err(.State);}};
    if(accounted>18446744073709551615-metadata_charge() ||
        s.ledger.used!=accounted+metadata_charge()){return .err(.State);}
    var usize occupied=0;var usize i=0;let usize one=1;
    while(i<16){let Row row=s.rows[i];
        if(i<count){
            if(row.serial==0 || row.binding>=512 || row.slot>=16 || row.generation==0 ||
                (s.next!=0 && row.serial>=s.next) || (occupied&(one<<row.slot))!=0){return .err(.State);}
            if(!owners::describe(ref s.table,owners::Token{.slot=row.slot,.generation=row.generation}).is_ok){return .err(.State);}
            occupied|=one<<row.slot;var usize j=0;
            while(j<i){if(s.rows[j].serial==row.serial || s.rows[j].binding==row.binding){return .err(.State);}j+=1;}
        }else if(row.serial!=0 || row.binding!=512 || row.slot!=16 || row.generation!=0){return .err(.State);}
        i+=1;
    }
    i=0;while(i<16){if(s.table.slots[i].live!=((occupied&(one<<i))!=0)){return .err(.State);}i+=1;}
    return .ok(count);
}
fn bool available(ref State s,ref vec::Vec<bytes::Buffer> roots,usize binding){
    if(binding>=512){return false;}var usize i=0;while(i<vec::len<bytes::Buffer>(roots)){
        if(s.rows[i].binding==binding){return false;}i+=1;
    }return true;
}
fn Result<usize,Error> resolve_mode(ref State s,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,bool writing){
    let usize count=ready(s,roots,scratch)?;if(serial==0 || binding>=512){return .err(.Binding);}
    var usize i=0;while(i<count){let Row row=s.rows[i];
        if(row.serial==serial){
            if(row.binding!=binding){return .err(.Binding);}
            let owners::Token token=owners::Token{.slot=row.slot,.generation=row.generation};
            let Result<owners::Owner,owners::Error> checked=if(writing){owners::writable(ref s.table,token)}
                else{owners::describe(ref s.table,token)};
            let owners::Owner owner=switch(checked){
                case .ok(v):{v}case .err(_):{return .err(.State);}
            };
            let ref bytes::Buffer root=vec::at<bytes::Buffer>(roots,i);
            if(bytes::len(root)!=owner.length || bytes::capacity(root)!=owner.capacity){return .err(.State);}
            return .ok(i);
        }i+=1;
    }return .err(.Serial);
}
// Shared read leases do not weaken identity or native extent authentication.
// Every mutation, including extent-preserving no-ops, retains the writable gate.
fn Result<usize,Error> resolve(ref State s,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding){
    return resolve_mode(s,roots,scratch,serial,binding,true);
}
// Metadata access remains store-local; no native root/view escapes this owner.
pub fn Result<owners::Owner,Error> describe(ref State s,ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding){
    let usize i=resolve_mode(s,roots,scratch,serial,binding,false)?;
    return switch(owners::describe(ref s.table,owners::Token{.slot=s.rows[i].slot,.generation=s.rows[i].generation})){case .ok(v):{.ok(v)}case .err(_):{.err(.State)}};
}
pub fn Result<usize,Error> copy_out(ref State s,ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,usize start,
    ref mut u8[] output,ref mut usize fuel){
    if(output.len>18446744073709551359){return .err(.Bounds);}
    let usize paid=pay(256+output.len,fuel)?;let usize i=resolve_mode(s,roots,scratch,serial,binding,false)?;
    return switch(owners::copy_out(ref s.table,owners::Token{.slot=s.rows[i].slot,.generation=s.rows[i].generation},start,
        vec::at<bytes::Buffer>(roots,i),output)){case .ok(v):{.ok(v)}case .err(_):{.err(.Bounds)}};
}
// Input is copied from a trusted native borrow, never a supplied owner word or
// descriptor. All fallible construction is staged; rejection publishes no root.
pub fn Result<usize,Error> insert(ref mut State s,ref mut vec::Vec<bytes::Buffer> roots,
    ref mut vec::Vec<bytes::Buffer> scratch,usize binding,ref u8[] input,
    growth::Limits limits,ref mut usize fuel){
    let usize cost=create_cost(input.len)?;let usize paid=pay(cost,fuel)?;
    let usize count=ready(s,roots,scratch)?;if(!available(s,roots,binding)){return .err(.Binding);}
    if(count==16){return .err(.Owners);}if(s.next==0){return .err(.Serial);}
    var owners::Table table=s.table;var growth::Ledger ledger=s.ledger;
    var bytes::Buffer root=bytes::empty();
    let owners::Token token=switch(create::empty(ref mut table,ref root,limits,ref mut ledger)){
        case .ok(v):{v}case .err(_):{return .err(.Quota);}
    };
    if(input.len>0){
        root=switch(storage::prepare_growth(ref root,input.len,limits,ref mut ledger)){
            case .ok(v):{v}case .err(e):{return .err(switch(e){case .Allocation:{.Allocation}
                case .Quota:{.Quota}case .State:{.State}case .Overflow:{.Bounds}
                case .NoGrowth:{.State}case .Provider:{.State}});}
        };
        if(!growth::commit(bytes::capacity(ref root),ref mut ledger).is_ok ||
            !bytes::append(ref mut root,input).is_ok){return .err(.State);}
        table.slots[token.slot].length=bytes::len(ref root);
        table.slots[token.slot].capacity=bytes::capacity(ref root);
    }
    var usize handoff_fuel=transfer::cost();
    let bytes::Buffer admitted=switch(transfer::handoff(root,token,ref table,ref ledger,ref s.closing,ref mut handoff_fuel)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    switch(vec::push<bytes::Buffer>(roots,admitted)){
        case .ok(_):{}case .err(_):{return .err(.State);}
    };
    let usize serial=s.next;s.rows[count]=Row{.serial=serial,.binding=binding,.slot=token.slot,.generation=token.generation};
    s.table=table;s.ledger=ledger;s.next=if(serial==18446744073709551615){0}else{serial+1};
    return .ok(serial);
}
// Both vectors were pre-reserved. These internal transfers cannot allocate.
fn void push(ref mut vec::Vec<bytes::Buffer> target,bytes::Buffer root){
    switch(vec::push<bytes::Buffer>(target,root)){case .ok(_):{}case .err(_):{assert(false);}};
}
fn bytes::Buffer pop(ref mut vec::Vec<bytes::Buffer> target){
    return switch(vec::pop<bytes::Buffer>(target)){case .some(v):{v}case .none:{assert(false);bytes::empty()}};
}
fn bytes::Buffer take(ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,usize index){
    while(vec::len<bytes::Buffer>(roots)>index+1){let bytes::Buffer root=pop(roots);push(scratch,root);}
    return pop(roots);
}
fn void restore(ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch){
    while(vec::len<bytes::Buffer>(scratch)>0){let bytes::Buffer root=pop(scratch);push(roots,root);}
}
fn Error growth_error(growth::Error e){
    return switch(e){case .Quota:{.Quota}case .Overflow:{.Bounds}
        case .State:{.State}case .NoGrowth:{.State}};
}
fn Error replacement_error(replacement::Error e){
    return switch(e){case .Quota:{.Quota}case .Allocation:{.Allocation}case .Overflow:{.Bounds}
        case .Owners:{.Owners}case .Token:{.State}case .State:{.State}
        case .NoGrowth:{.State}case .Provider:{.State}};
}
// Validate the exact commit against disposable metadata copies while the old
// allocation is still live. This changes no live owner or accounting and makes
// no refund. The private plan/provider must then commit identically after publish;
// failure there is a fatal invariant violation, never a retryable rejection.
fn bool preflight_publication(ref owners::Table table,ref bytes::Buffer prepared,
    ref growth::Ledger ledger,ref replacement::Plan plan){
    var owners::Table checked_table=*table;var growth::Ledger checked_ledger=*ledger;
    var replacement::Plan checked_plan=*plan;
    return replacement::commit(ref mut checked_table,prepared,ref mut checked_ledger,ref mut checked_plan).is_ok;
}
pub fn Result<usize,Error> len(ref State s,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,ref mut usize fuel){
    let usize paid=pay(len_cost(),fuel)?;let usize i=resolve_mode(s,roots,scratch,serial,binding,false)?;
    return .ok(bytes::len(vec::at<bytes::Buffer>(roots,i)));
}
pub fn Result<u8,Error> read(ref State s,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,usize index,ref mut usize fuel){
    let usize paid=pay(read_cost(),fuel)?;let usize i=resolve_mode(s,roots,scratch,serial,binding,false)?;
    return switch(owners::read(ref s.table,owners::Token{.slot=s.rows[i].slot,.generation=s.rows[i].generation},
        index,vec::at<bytes::Buffer>(roots,i))){
        case .ok(v):{.ok(v)}case .err(e):{.err(switch(e){case .Bounds:{.Bounds}
            case .Owners:{.Owners}case .Token:{.State}case .State:{.State}})}
    };
}
// The coordinator supplies a distinct native input borrow, never a view of any
// root backing. No view or owning Buffer is exposed by these operations.
pub fn Result<usize,Error> write(ref State s,ref mut vec::Vec<bytes::Buffer> roots,
    ref mut vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,usize start,
    ref u8[] input,growth::Limits limits,ref mut usize fuel){
    let usize cost=write_cost(input.len)?;let usize paid=pay(cost,fuel)?;
    let usize i=resolve(s,roots,scratch,serial,binding)?;
    var bytes::Buffer root=take(roots,scratch,i);
    let Result<usize,buffer_write::Error> result=buffer_write::within_length(ref s.table,
        owners::Token{.slot=s.rows[i].slot,.generation=s.rows[i].generation},start,
        ref mut root,input,limits,ref s.ledger);
    push(roots,root);restore(roots,scratch);
    return switch(result){case .ok(v):{.ok(v)}case .err(e):{.err(switch(e){
        case .Quota:{.Quota}case .Overflow:{.Bounds}case .Bounds:{.Bounds}
        case .Owners:{.Owners}case .Token:{.State}case .State:{.State}})}};
}
pub fn Result<usize,Error> reserve(ref mut State s,ref mut vec::Vec<bytes::Buffer> roots,
    ref mut vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,usize required,
    growth::Limits limits,ref mut usize fuel){
    let usize metadata=pay(256,fuel)?;let usize i=resolve(s,roots,scratch,serial,binding)?;
    let usize cost=reserve_cost(bytes::len(vec::at<bytes::Buffer>(roots,i)))?;
    let usize paid=pay(cost-256,fuel)?;
    let usize capacity=bytes::capacity(vec::at<bytes::Buffer>(roots,i));
    if(required<=capacity){
        return switch(growth::plan(capacity,required,limits,ref s.ledger)){
            case .ok(v):{.ok(v)}case .err(e):{.err(growth_error(e))}
        };
    }
    let owners::Token token=owners::Token{.slot=s.rows[i].slot,.generation=s.rows[i].generation};
    // Exhaustion rejects before extraction, allocation or reservation.
    if(token.generation==18446744073709551615){return .err(.Owners);}
    var growth::Ledger ledger=s.ledger;var replacement::Plan plan=replacement::empty();
    var bytes::Buffer root=take(roots,scratch,i);
    let bytes::Buffer prepared=switch(replacement::prepare(ref s.table,token,ref root,required,
        limits,ref mut ledger,ref mut plan)){
        case .ok(v):{v}case .err(e):{
            push(roots,root);restore(roots,scratch);return .err(replacement_error(e));
        }
    };
    if(!preflight_publication(ref s.table,ref prepared,ref ledger,ref plan)){
        push(roots,root);restore(roots,scratch);return .err(.State);
    }
    // Publication boundary: whole-local assignment drops old before its refund.
    // No recoverable rejection is permitted after this point.
    root=prepared;
    let owners::Token next=switch(replacement::commit(ref mut s.table,ref root,ref mut ledger,ref mut plan)){
        case .ok(v):{v}case .err(_):{
            assert(false);owners::Token{.slot=token.slot,.generation=token.generation+1}
        }
    };
    let usize actual=bytes::capacity(ref root);
    push(roots,root);restore(roots,scratch);
    s.ledger=ledger;s.rows[i].generation=next.generation;return .ok(actual);
}
pub fn Result<usize,Error> append(ref mut State s,ref mut vec::Vec<bytes::Buffer> roots,
    ref mut vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,ref u8[] input,
    growth::Limits limits,ref mut usize fuel){
    let usize metadata=pay(256,fuel)?;let usize i=resolve(s,roots,scratch,serial,binding)?;
    let usize old_length=bytes::len(vec::at<bytes::Buffer>(roots,i));
    let usize cost=append_cost(old_length,input.len)?;let usize paid=pay(cost-256,fuel)?;
    let usize length=old_length+input.len;
    let usize capacity=bytes::capacity(vec::at<bytes::Buffer>(roots,i));
    let owners::Token token=owners::Token{.slot=s.rows[i].slot,.generation=s.rows[i].generation};
    if(input.len>0 && token.generation==18446744073709551615){return .err(.Owners);}
    var bytes::Buffer root=take(roots,scratch,i);
    if(length<=capacity){
        let growth::Ledger admitted=s.ledger;
        let Result<owners::Token,buffer_append::Error> result=buffer_append::within_capacity(
            ref mut s.table,token,ref mut root,input,limits,ref admitted);
        let owners::Token next=switch(result){case .ok(v):{v}case .err(e):{
            let Error error=switch(e){case .Quota:{.Quota}case .Overflow:{.Bounds}case .Capacity:{.Bounds}
                case .Owners:{.Owners}case .Token:{.State}case .State:{.State}
                // SDK failure may follow native mutation: never expose a rejected
                // operation with changed bytes as a recoverable store result.
                case .Provider:{assert(false);.State}};
            push(roots,root);restore(roots,scratch);return .err(error);
        }};
        push(roots,root);restore(roots,scratch);
        s.rows[i].generation=next.generation;return .ok(length);
    }
    // Only successful publication updates the original ledger, including peaks.
    var growth::Ledger ledger=s.ledger;var replacement::Plan plan=replacement::empty();
    let bytes::Buffer prepared=switch(replacement::prepare_append(ref s.table,token,ref root,input,
        limits,ref mut ledger,ref mut plan)){
        case .ok(v):{v}case .err(e):{
            push(roots,root);restore(roots,scratch);return .err(replacement_error(e));
        }
    };
    if(!preflight_publication(ref s.table,ref prepared,ref ledger,ref plan)){
        push(roots,root);restore(roots,scratch);return .err(.State);
    }
    // Publication is irreversible; commit failure is a fatal provider invariant.
    root=prepared;
    let owners::Token next=switch(replacement::commit(ref mut s.table,ref root,ref mut ledger,ref mut plan)){
        case .ok(v):{v}case .err(_):{
            assert(false);owners::Token{.slot=token.slot,.generation=token.generation+1}
        }
    };
    push(roots,root);restore(roots,scratch);
    s.ledger=ledger;s.rows[i].generation=next.generation;return .ok(length);
}
// Move the actual allocation through the existing owning handoff. Restore on
// rejection before changing its logical binding; token/generation/charge stay.
pub fn Result<usize,Error> move(ref mut State s,ref mut vec::Vec<bytes::Buffer> roots,
    ref mut vec::Vec<bytes::Buffer> scratch,usize serial,usize source,usize destination,ref mut usize fuel){
    let usize paid=pay(move_cost(),fuel)?;let usize i=resolve(s,roots,scratch,serial,source)?;
    if(!available(s,roots,destination)){return .err(.Binding);}
    let bytes::Buffer root=take(roots,scratch,i);var usize handoff_fuel=transfer::cost();
    var bool accepted=true;
    let bytes::Buffer moved=switch(transfer::handoff(root,owners::Token{.slot=s.rows[i].slot,.generation=s.rows[i].generation},ref s.table,ref s.ledger,ref s.closing,ref mut handoff_fuel)){
        case .ok(v):{v}case .err(v):{accepted=false;v}
    };
    push(roots,moved);restore(roots,scratch);
    if(!accepted){return .err(.State);}s.rows[i].binding=destination;return .ok(serial);
}
fn Result<usize,Error> destroy(ref mut State s,ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,usize i){
    let usize count=vec::len<bytes::Buffer>(roots);
    var owners::Table table=s.table;let growth::Ledger before=s.ledger;
    var close::Plan closing=s.closing;let owners::Token token=owners::Token{.slot=s.rows[i].slot,.generation=s.rows[i].generation};
    switch(close::begin(ref mut table,token,vec::at<bytes::Buffer>(roots,i),ref before,ref mut closing)){
        case .ok(_):{}case .err(_):{return .err(.State);}
    };
    {let bytes::Buffer disposed=take(roots,scratch,i);}
    // Actual destruction precedes refund. Scratch restoration allocates nothing.
    var growth::Ledger ledger=before;
    let usize used=switch(close::finish(ref table,ref mut ledger,ref mut closing)){
        case .ok(v):{v}case .err(_):{assert(false);0}
    };
    s.table=table;s.ledger=ledger;s.closing=closing;
    restore(roots,scratch);var usize at=i;while(at+1<count){let Row next=s.rows[at+1];s.rows[at]=next;at+=1;}
    s.rows[count-1]=blank();return .ok(used);
}
pub fn Result<usize,Error> drop(ref mut State s,ref mut vec::Vec<bytes::Buffer> roots,
    ref mut vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,ref mut usize fuel){
    let usize paid=pay(drop_cost(),fuel)?;let usize i=resolve(s,roots,scratch,serial,binding)?;return destroy(s,roots,scratch,i);
}
// Normal completion and failure use the same native-only reverse root drain.
// Setup paid this bounded work; an exhausted guest Fuel cannot prevent cleanup.
// Native vector resource cleanup also frees roots if the coordinator exits early.
pub fn Result<usize,Error> drain(ref mut State s,ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch){
    if(s.closed){return .ok(0);}let usize count=ready(s,roots,scratch)?;var usize remaining=count;
    while(remaining>0){remaining-=1;let usize used=destroy(s,roots,scratch,remaining)?;}
    let usize released=switch(growth::release_metadata(metadata_charge(),ref mut s.ledger)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    s.closed=true;return .ok(released);
}
