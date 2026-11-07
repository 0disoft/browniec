module retention_plan;

// Trusted compiler admission for fixed Program/source storage plus image bytes.
// Keep fields flat: nested private state violates pinned compiler composition.
pub enum Error { Invalid; Quota; State; }
pub struct Plan { usize fixed; usize limit; usize bytes; bool admitted; }

// Legacy compiler callers admit one bounded image (<=4096 bytes) without denial.
pub fn Plan unlimited() {
    return Plan{.fixed=0,.limit=18446744073709551615,.bytes=0,.admitted=false};
}

pub fn Result<Plan,Error> create(usize fixed,usize limit) {
    if(fixed==0 || limit==0){return .err(.Invalid);}
    if(fixed>limit){return .err(.Quota);}
    return .ok(Plan{.fixed=fixed,.limit=limit,.bytes=0,.admitted=false});
}

// Admit before image/storage allocation. Failure leaves every field unchanged.
// create/unlimited establish fixed<=limit; subtract before adding to avoid wrap.
pub fn Result<usize,Error> admit(ref mut Plan plan,usize payload) {
    if(plan.admitted){return .err(.State);}
    if(payload>plan.limit-plan.fixed){return .err(.Quota);}
    let usize bytes=plan.fixed+payload;
    plan.bytes=bytes;
    plan.admitted=true;
    return .ok(bytes);
}

// Private source diagnostic; Engine maps kind 21 to resource-limit status 8.
pub fn u8 quota_kind() { return 21; }
