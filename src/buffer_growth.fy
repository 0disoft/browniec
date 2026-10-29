module buffer_growth;

// Private admission accounting only: callers own allocation, copying and roots.
// The checkpoint charges 64 logical bytes for each old or pending owner record.
pub struct Limits { usize object; usize instance; usize engine; }
pub struct Ledger {
    usize used; usize engine_used; usize peak; usize engine_peak;
    usize pending; usize old_capacity; usize new_capacity;
    usize before_used; usize before_engine_used;
}
pub enum Error { State; Overflow; Quota; NoGrowth; }

// No Buffer owner has been admitted yet; also valid after final close.
pub fn Ledger unowned() {
    return Ledger { .used=0, .engine_used=0, .peak=0, .engine_peak=0,
        .pending=0, .old_capacity=0, .new_capacity=0, .before_used=0, .before_engine_used=0 };
}
// One empty Buffer owner is already accounted; no payload is allocated here.
pub fn Ledger empty() {
    return Ledger { .used=64, .engine_used=64, .peak=64, .engine_peak=64,
        .pending=0, .old_capacity=0, .new_capacity=0, .before_used=0, .before_engine_used=0 };
}
fn bool counters(ref Ledger ledger) {
    return ledger.used<=ledger.engine_used && ledger.used<=ledger.peak &&
        ledger.engine_used<=ledger.engine_peak && ledger.peak<=ledger.engine_peak;
}
fn bool idle(ref Ledger ledger) {
    return counters(ledger) && ledger.pending==0 && ledger.old_capacity==0 && ledger.new_capacity==0 &&
        ledger.before_used==0 && ledger.before_engine_used==0;
}
fn bool clean(ref Ledger ledger,usize old) {
    return old%64==0 && old<=18446744073709551551 && idle(ledger) && ledger.used>=old+64;
}
fn Result<usize,Error> rounded(usize value) {
    if(value>18446744073709551552) {return .err(.Overflow);}
    return .ok(((value+63)/64)*64);
}
fn bool fits(usize capacity,Limits limits,ref Ledger ledger) {
    if(capacity>limits.object || capacity>18446744073709551551) {return false;}
    let usize charge=capacity+64;
    return ledger.used<=limits.instance && ledger.engine_used<=limits.engine &&
        charge<=limits.instance-ledger.used && charge<=limits.engine-ledger.engine_used;
}
// Admit one additional empty owner, preserving background usage and prior peaks.
pub fn Result<usize,Error> admit_empty(Limits limits,ref mut Ledger ledger) {
    if(!idle(ledger)) {return .err(.State);}
    if(ledger.used>18446744073709551551 || ledger.engine_used>18446744073709551551) {return .err(.Overflow);}
    if(!fits(0,limits,ledger)) {return .err(.Quota);}
    ledger.used+=64;ledger.engine_used+=64;
    if(ledger.used>ledger.peak) {ledger.peak=ledger.used;}
    if(ledger.engine_used>ledger.engine_peak) {ledger.engine_peak=ledger.engine_used;}
    return .ok(ledger.used);
}
pub fn Result<usize,Error> plan(usize old,usize required,Limits limits,ref Ledger ledger) {
    if(!clean(ledger,old)) {return .err(.State);}
    if(old>limits.object || ledger.used>limits.instance || ledger.engine_used>limits.engine) {return .err(.Quota);}
    if(required<=old) {return .ok(old);}
    let usize minimum=rounded(required)?;
    if(minimum>18446744073709551551) {return .err(.Overflow);}
    var usize preferred=minimum;
    if(old<=18446744073709551615-old/2) {
        let usize grown=old+old/2;
        if(grown>required) {
            preferred=switch(rounded(grown)){case .ok(n):{n}case .err(_):{minimum}};
        }
    }
    if(fits(preferred,limits,ledger)) {return .ok(preferred);}
    if(fits(minimum,limits,ledger)) {return .ok(minimum);}
    return .err(.Quota);
}
// Reserve the full new payload AND owner while the old allocation stays live.
// Allocator OOM must cancel this reservation, never silently choose/replay work.
pub fn Result<usize,Error> begin(usize old,usize required,Limits limits,ref mut Ledger ledger) {
    let usize capacity=plan(old,required,limits,ledger)?;
    if(capacity==old) {return .err(.NoGrowth);}
    let usize charge=capacity+64;
    ledger.before_used=ledger.used;ledger.before_engine_used=ledger.engine_used;
    ledger.old_capacity=old;ledger.new_capacity=capacity;ledger.pending=charge;
    ledger.used+=charge;ledger.engine_used+=charge;
    if(ledger.used>ledger.peak) {ledger.peak=ledger.used;}
    if(ledger.engine_used>ledger.engine_peak) {ledger.engine_peak=ledger.engine_used;}
    return .ok(capacity);
}
// Revalidate a pending transaction before subtraction, addition or publication.
fn bool pending(ref Ledger ledger) {
    if(!counters(ledger) || ledger.old_capacity%64!=0 || ledger.new_capacity%64!=0 ||
        ledger.old_capacity>18446744073709551551 || ledger.new_capacity>18446744073709551551 ||
        ledger.new_capacity<=ledger.old_capacity) {return false;}
    if(ledger.pending!=ledger.new_capacity+64 || ledger.before_used<ledger.old_capacity+64 ||
        ledger.before_engine_used<ledger.before_used || ledger.before_used>18446744073709551615-ledger.pending ||
        ledger.before_engine_used>18446744073709551615-ledger.pending) {return false;}
    return ledger.used==ledger.before_used+ledger.pending &&
        ledger.engine_used==ledger.before_engine_used+ledger.pending;
}
fn void clear_pending(ref mut Ledger ledger) {
    ledger.pending=0;ledger.old_capacity=0;ledger.new_capacity=0;
    ledger.before_used=0;ledger.before_engine_used=0;
}
// Call only after the replacement is published and the old allocation dropped.
pub fn Result<usize,Error> commit(usize current_capacity,ref mut Ledger ledger) {
    if(!pending(ledger) || current_capacity!=ledger.new_capacity) {return .err(.State);}
    ledger.used=ledger.before_used-ledger.old_capacity+ledger.new_capacity;
    ledger.engine_used=ledger.before_engine_used-ledger.old_capacity+ledger.new_capacity;
    clear_pending(ledger);
    return .ok(current_capacity);
}
// Call only after any unpublished replacement allocation has been dropped.
pub fn Result<usize,Error> cancel(ref mut Ledger ledger) {
    if(!pending(ledger)) {return .err(.State);}
    ledger.used=ledger.before_used;ledger.engine_used=ledger.before_engine_used;
    clear_pending(ledger);
    return .ok(ledger.used);
}
