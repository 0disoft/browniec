module buffer_replacement;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_growth as growth;
import buffer_storage as storage;

// Private snapshot, not an authenticated guest handle. Root publication is explicit.
pub struct Plan {
    bool active; owners::Table before; owners::Token source;
    usize capacity; usize length; growth::Ledger reserved;
}
pub enum Error { Token; Owners; State; Overflow; Quota; NoGrowth; Allocation; Provider; }
pub fn Plan empty() {
    return Plan{.active=false,.before=owners::empty(),.source=owners::Token{.slot=16,.generation=0},
        .capacity=0,.length=0,.reserved=growth::empty()};
}
fn Error owner_error(owners::Error e) {
    return switch(e){case .Token:{.Token}case .Owners:{.Owners}case .State:{.State}case .Bounds:{.State}};
}
fn Error storage_error(storage::Error e) {
    return switch(e){case .State:{.State}case .Overflow:{.Overflow}case .Quota:{.Quota}
        case .NoGrowth:{.NoGrowth}case .Allocation:{.Allocation}case .Provider:{.Provider}};
}
fn growth::Ledger snapshot(ref growth::Ledger l) {
    return growth::Ledger{.used=l.used,.engine_used=l.engine_used,.peak=l.peak,.engine_peak=l.engine_peak,
        .pending=l.pending,.old_capacity=l.old_capacity,.new_capacity=l.new_capacity,
        .before_used=l.before_used,.before_engine_used=l.before_engine_used};
}
fn bool same_ledger(ref growth::Ledger a,ref growth::Ledger b) {
    return a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used;
}
fn bool same_table(ref owners::Table a,ref owners::Table b) {
    var usize i=0;while(i<16) {
        let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        if(x.generation!=y.generation || x.live!=y.live || x.length!=y.length || x.capacity!=y.capacity) {return false;}
        i+=1;
    }
    return true;
}
pub fn Result<bytes::Buffer,Error> prepare(ref owners::Table table,owners::Token source,
    ref bytes::Buffer old,usize required,growth::Limits limits,ref mut growth::Ledger ledger,ref mut Plan plan) {
    if(plan.active) {return .err(.State);}
    let owners::Owner owner=switch(owners::describe(table,source)) {
        case .ok(value):{value}case .err(e):{return .err(owner_error(e));}
    };
    if(bytes::len(old)!=owner.length || bytes::capacity(old)!=owner.capacity) {return .err(.State);}
    // No generation can be published after MAX; reject before reserving/allocating.
    if(owner.generation==18446744073709551615) {return .err(.Owners);}
    let bytes::Buffer replacement=switch(storage::prepare_growth(old,required,limits,ledger)) {
        case .ok(value):{value}case .err(e):{return .err(storage_error(e));}
    };
    var usize i=0;while(i<16) {plan.before.slots[i]=table.slots[i];i+=1;}
    plan.source=source;plan.capacity=bytes::capacity(ref replacement);plan.length=owner.length;
    plan.reserved=snapshot(ledger);plan.active=true;
    return .ok(replacement);
}
// A failed helper drops the unpublished replacement before caller-side cancel.
fn Result<bytes::Buffer,Error> extend(bytes::Buffer source,ref u8[] input,usize capacity,usize length) {
    var bytes::Buffer replacement=source;
    let usize actual=switch(bytes::append(ref mut replacement,input)) {
        case .ok(value):{value}case .err(_):{return .err(.Provider);}
    };
    if(actual!=length || bytes::len(ref replacement)!=length || bytes::capacity(ref replacement)!=capacity) {return .err(.Provider);}
    return .ok(replacement);
}
// Growth-only append preparation: use buffer_append for an in-capacity write.
// The old root remains live even when input is a shared view of that same root.
pub fn Result<bytes::Buffer,Error> prepare_append(ref owners::Table table,owners::Token source,
    ref bytes::Buffer old,ref u8[] input,growth::Limits limits,ref mut growth::Ledger ledger,ref mut Plan plan) {
    if(plan.active) {return .err(.State);}
    let owners::Owner owner=switch(owners::describe(table,source)) {
        case .ok(value):{value}case .err(e):{return .err(owner_error(e));}
    };
    if(bytes::len(old)!=owner.length || bytes::capacity(old)!=owner.capacity) {return .err(.State);}
    if(input.len>18446744073709551615-owner.length) {return .err(.Overflow);}
    let usize length=owner.length+input.len;
    let bytes::Buffer replacement=prepare(table,source,old,length,limits,ledger,plan)?;
    let bytes::Buffer ready=switch(extend(replacement,input,plan.capacity,length)) {
        case .ok(value):{value}
        case .err(e): {
            // extend has already destroyed its unpublished replacement.
            switch(cancel(table,ledger,plan)){case .ok(_):{}case .err(_):{return .err(.State);}};
            return .err(e);
        }
    };
    plan.length=length;
    return .ok(ready);
}
// Verify both snapshots and the complete accounting transaction before mutation.
fn Result<owners::Owner,Error> validate(ref owners::Table table,ref growth::Ledger ledger,ref Plan plan) {
    if(!plan.active || !same_table(table,ref plan.before) || !same_ledger(ledger,ref plan.reserved)) {return .err(.State);}
    let owners::Owner owner=switch(owners::describe(table,plan.source)) {
        case .ok(value):{value}case .err(_):{return .err(.State);}
    };
    if(owner.generation==18446744073709551615 || ledger.old_capacity!=owner.capacity ||
        ledger.new_capacity!=plan.capacity || plan.length<owner.length || plan.length>plan.capacity) {return .err(.State);}
    var growth::Ledger checked=snapshot(ledger);
    switch(growth::commit(plan.capacity,ref mut checked)) {
        case .ok(_):{}case .err(_):{return .err(.State);}
    };
    return .ok(owner);
}
// Caller has already replaced its root and dropped the old native allocation.
pub fn Result<owners::Token,Error> commit(ref mut owners::Table table,ref bytes::Buffer published,
    ref mut growth::Ledger ledger,ref mut Plan plan) {
    let owners::Owner owner=validate(table,ledger,plan)?;
    if(bytes::len(published)!=plan.length || bytes::capacity(published)!=plan.capacity) {return .err(.State);}
    var growth::Ledger finished=snapshot(ledger);
    switch(growth::commit(plan.capacity,ref mut finished)) {
        case .ok(_):{}case .err(_):{return .err(.State);}
    };
    let owners::Token next=owners::Token{.slot=plan.source.slot,.generation=owner.generation+1};
    // No allocation, callback or fallible operation follows descriptor publication.
    table.slots[next.slot].capacity=plan.capacity;table.slots[next.slot].length=plan.length;
    table.slots[next.slot].generation=next.generation;
    *ledger=finished;plan.active=false;
    return .ok(next);
}
// Caller must drop any unpublished replacement before cancelling the reservation.
pub fn Result<usize,Error> cancel(ref owners::Table table,ref mut growth::Ledger ledger,ref mut Plan plan) {
    let owners::Owner owner=validate(table,ledger,plan)?;
    var growth::Ledger restored=snapshot(ledger);
    let usize used=switch(growth::cancel(ref mut restored)) {
        case .ok(value):{value}case .err(_):{return .err(.State);}
    };
    *ledger=restored;plan.active=false;
    return .ok(used);
}
