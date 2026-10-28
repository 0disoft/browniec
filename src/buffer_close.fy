module buffer_close;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_growth as growth;

// One-way private retirement. Caller drops the root between begin and finish.
pub struct Plan {
    bool active; owners::Table after; growth::Ledger before;
    owners::Token source; usize capacity; usize charge;
}
pub enum Error { Token; State; }
pub fn Plan empty() {
    return Plan{.active=false,.after=owners::empty(),.before=growth::empty(),
        .source=owners::Token{.slot=16,.generation=0},.capacity=0,.charge=0};
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
// Cleanup must still work after policy limits are reduced; only accounting is checked.
fn bool clean(usize capacity,ref growth::Ledger ledger) {
    return switch(growth::plan(capacity,capacity,growth::Limits{
        .object=18446744073709551615,.instance=18446744073709551615,.engine=18446744073709551615},ledger)) {
        case .ok(_):{true}case .err(_):{false}
    };
}
pub fn Result<usize,Error> begin(ref mut owners::Table table,owners::Token source,
    ref bytes::Buffer root,ref growth::Ledger ledger,ref mut Plan plan) {
    if(plan.active) {return .err(.State);}
    let owners::Owner owner=switch(owners::describe(table,source)) {
        case .ok(value):{value}
        case .err(e):{return .err(switch(e){case .Token:{.Token}case .Owners:{.State}case .State:{.State}case .Bounds:{.State}});}
    };
    if(bytes::len(root)!=owner.length || bytes::capacity(root)!=owner.capacity || !clean(owner.capacity,ledger)) {return .err(.State);}
    var owners::Table retired=owners::Table{.slots=table.slots};
    switch(owners::release(ref mut retired,source)){case .ok(_):{}case .err(_):{return .err(.State);}};
    var usize i=0;while(i<16) {plan.after.slots[i]=retired.slots[i];i+=1;}
    plan.before=snapshot(ledger);plan.source=source;plan.capacity=owner.capacity;plan.charge=owner.capacity+64;
    // No fallible work follows token invalidation; retain the complete charge.
    table.slots[source.slot]=retired.slots[source.slot];plan.active=true;
    return .ok(plan.charge);
}
// Caller has dropped the native owning root. This API cannot prove that event.
pub fn Result<usize,Error> finish(ref owners::Table table,ref mut growth::Ledger ledger,ref mut Plan plan) {
    if(!plan.active || !same_table(table,ref plan.after) || !same_ledger(ledger,ref plan.before) ||
        plan.source.slot>=16 || plan.source.generation==0 || plan.capacity>18446744073709551551 ||
        plan.charge!=plan.capacity+64 || !clean(plan.capacity,ledger)) {return .err(.State);}
    let owners::Owner retired=table.slots[plan.source.slot];
    let usize generation=if(plan.source.generation==18446744073709551615){0}else{plan.source.generation+1};
    if(retired.live || retired.length!=0 || retired.capacity!=0 || retired.generation!=generation) {return .err(.State);}
    // Underflow was excluded by clean; observed peaks and pending fields stay intact.
    ledger.used-=plan.charge;ledger.engine_used-=plan.charge;plan.active=false;
    return .ok(ledger.used);
}
