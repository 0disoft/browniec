module runtime_control_budget;

// Trusted Engine-owned control-storage ledger, never a guest capability.
// Charges are explicit caller policy: no allocation, implicit heap tracking,
// synchronization or full Engine memory/work (R02) accounting is provided.
pub enum Error { Invalid; Quota; State; }
pub struct Observation { usize limit; usize reserved; usize peak; bool closed; }
pub struct Budget { usize limit; usize reserved; usize peak; bool closed; }

// Preflight before publishing a value; zero limit takes precedence over quota.
pub fn Result<Budget,Error> create(usize limit,usize initial){
    if(limit==0){return .err(.Invalid);}
    if(initial>limit){return .err(.Quota);}
    return .ok(Budget{
        .limit=limit,.reserved=initial,.peak=initial,.closed=false});
}

pub fn Observation observe(ref Budget b){
    return Observation{.limit=b.limit,.reserved=b.reserved,
        .peak=b.peak,.closed=b.closed};
}

// create/reserve/release preserve reserved <= peak <= limit. Subtract before
// adding, so even a maximum-usize request cannot wrap. Failure changes nothing.
pub fn Result<usize,Error> reserve(ref mut Budget b,usize bytes){
    if(b.closed){return .err(.State);}
    if(bytes>b.limit-b.reserved){return .err(.Quota);}
    let usize next=b.reserved+bytes;
    b.reserved=next;
    if(next>b.peak){b.peak=next;}
    return .ok(next);
}

// Zero-byte operations succeed while open; peak is historical, never reset.
pub fn Result<usize,Error> release(ref mut Budget b,usize bytes){
    if(b.closed){return .err(.State);}
    if(bytes>b.reserved){return .err(.State);}
    b.reserved-=bytes;
    return .ok(b.reserved);
}

// Caller releases all charges explicitly; close never discards a reservation.
pub fn Result<usize,Error> close(ref mut Budget b){
    if(b.closed || b.reserved!=0){return .err(.State);}
    b.closed=true;
    return .ok(0);
}
