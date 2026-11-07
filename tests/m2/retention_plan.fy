module tests::m2::retention_plan;
import retention_plan as retention;

fn u8 error_code(retention::Error error) {
    return switch (error) {
        case .Invalid: { 1 } case .Quota: { 2 } case .State: { 3 }
    };
}

fn void value(Result<usize,retention::Error> result,usize expected) {
    switch (result) {
        case .ok(actual): { assert(actual==expected); }
        case .err(_): { assert(false); return; }
    };
}

fn void rejected(Result<usize,retention::Error> result,u8 expected) {
    switch (result) {
        case .ok(_): { assert(false); return; }
        case .err(error): { assert(error_code(error)==expected); }
    };
}

fn void create_rejected(usize fixed,usize limit,u8 expected) {
    switch (retention::create(fixed,limit)) {
        case .ok(_): { assert(false); return; }
        case .err(error): { assert(error_code(error)==expected); }
    };
}

fn void state(ref retention::Plan plan,usize fixed,usize limit,usize bytes,bool admitted) {
    assert(plan.fixed==fixed && plan.limit==limit);
    assert(plan.bytes==bytes && plan.admitted==admitted);
}

@test
fn void exact_and_one_less_are_atomic_and_rejection_allows_retry() {
    var retention::Plan exact=switch (retention::create(96,4192)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    var retention::Plan short=switch (retention::create(96,4191)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    state(ref exact,96,4192,0,false);
    state(ref short,96,4191,0,false);
    value(retention::admit(ref mut exact,4096),4192);
    state(ref exact,96,4192,4192,true);
    rejected(retention::admit(ref mut short,4096),2);
    state(ref short,96,4191,0,false);
    value(retention::admit(ref mut short,4095),4191);
    state(ref short,96,4191,4191,true);
}

@test
fn void maximum_usize_rejects_overflow_before_addition_without_mutation() {
    let usize maximum=18446744073709551615;
    var retention::Plan edge=switch (retention::create(maximum-1,maximum)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    rejected(retention::admit(ref mut edge,2),2);
    state(ref edge,maximum-1,maximum,0,false);
    rejected(retention::admit(ref mut edge,maximum),2);
    state(ref edge,maximum-1,maximum,0,false);
    value(retention::admit(ref mut edge,1),maximum);
    state(ref edge,maximum-1,maximum,maximum,true);
    var retention::Plan payload_edge=switch (retention::create(1,maximum)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    rejected(retention::admit(ref mut payload_edge,maximum),2);
    state(ref payload_edge,1,maximum,0,false);
    value(retention::admit(ref mut payload_edge,maximum-1),maximum);
    state(ref payload_edge,1,maximum,maximum,true);
    var retention::Plan full=switch (retention::create(maximum,maximum)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    rejected(retention::admit(ref mut full,1),2);
    state(ref full,maximum,maximum,0,false);
    value(retention::admit(ref mut full,0),maximum);
    state(ref full,maximum,maximum,maximum,true);
}

@test
fn void double_admit_is_state_even_for_zero_unlimited_and_overquota_payload() {
    let usize maximum=18446744073709551615;
    var retention::Plan bounded=switch (retention::create(8,8)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    value(retention::admit(ref mut bounded,0),8);
    rejected(retention::admit(ref mut bounded,0),3);
    state(ref bounded,8,8,8,true);
    rejected(retention::admit(ref mut bounded,maximum),3);
    state(ref bounded,8,8,8,true);
    var retention::Plan zero=retention::unlimited();
    state(ref zero,0,maximum,0,false);
    value(retention::admit(ref mut zero,0),0);
    state(ref zero,0,maximum,0,true);
    rejected(retention::admit(ref mut zero,0),3);
    state(ref zero,0,maximum,0,true);
    rejected(retention::admit(ref mut zero,4096),3);
    state(ref zero,0,maximum,0,true);
    var retention::Plan image=retention::unlimited();
    value(retention::admit(ref mut image,4096),4096);
    state(ref image,0,maximum,4096,true);
    rejected(retention::admit(ref mut image,0),3);
    state(ref image,0,maximum,4096,true);
}

@test
fn void creation_invalid_precedes_quota_and_private_diagnostic_is_stable() {
    let usize maximum=18446744073709551615;
    create_rejected(0,0,1);
    create_rejected(0,1,1);
    create_rejected(0,maximum,1);
    create_rejected(1,0,1);
    create_rejected(maximum,0,1);
    create_rejected(2,1,2);
    create_rejected(maximum,maximum-1,2);
    let retention::Plan smallest=switch (retention::create(1,1)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    state(ref smallest,1,1,0,false);
    let retention::Plan largest=switch (retention::create(maximum,maximum)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    state(ref largest,maximum,maximum,0,false);
    assert(retention::quota_kind()==21);
}
