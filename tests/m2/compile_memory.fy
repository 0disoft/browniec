module tests::m2::compile_memory;
import compile_memory as memory;

fn u8 error_code(memory::Error error) {
    return switch(error) {
        case .Invalid: { 1 } case .Quota: { 2 } case .State: { 3 }
    };
}

fn void value(Result<usize,memory::Error> result,usize expected) {
    switch(result) {
        case .ok(actual): { assert(actual==expected); }
        case .err(_): { assert(false); return; }
    };
}

fn void rejected(Result<usize,memory::Error> result,u8 expected) {
    switch(result) {
        case .ok(_): { assert(false); return; }
        case .err(error): { assert(error_code(error)==expected); }
    };
}

fn void create_rejected(usize working,usize combined,usize baseline,u8 expected) {
    switch(memory::create(memory::Limits{.working=working,.combined=combined},baseline)) {
        case .ok(_): { assert(false); return; }
        case .err(error): { assert(error_code(error)==expected); }
    };
}

fn void state(ref memory::Plan plan,usize baseline,usize work,usize persistent,
    usize current,usize peak,u8 phase) {
    let memory::Observation actual=memory::observe(plan);
    assert(actual.baseline==baseline && actual.working_bytes==work);
    assert(actual.persistent_bytes==persistent && actual.current==current);
    assert(actual.peak==peak && actual.phase==phase);
    assert(plan.working_limit==actual.working_limit);
    assert(plan.combined_limit==actual.combined_limit && plan.baseline==baseline);
    assert(plan.working_bytes==work && plan.persistent_bytes==persistent);
    assert(plan.current==current && plan.peak==peak && plan.phase==phase);
}

fn void unchanged(ref memory::Plan plan,ref memory::Observation before) {
    state(plan,before.baseline,before.working_bytes,before.persistent_bytes,
        before.current,before.peak,before.phase);
    assert(plan.working_limit==before.working_limit);
    assert(plan.combined_limit==before.combined_limit);
}

@test
fn void exact_and_one_less_working_and_combined_limits_allow_retry() {
    var memory::Plan exact=switch(memory::create(memory::Limits{.working=5,.combined=8},3)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    var memory::Plan work_short=switch(memory::create(memory::Limits{.working=4,.combined=8},3)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    var memory::Plan combined_short=switch(memory::create(memory::Limits{.working=5,.combined=7},3)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    value(memory::reserve_work(ref mut exact,5),8);
    state(ref exact,3,5,0,8,8,1);
    let memory::Observation before_work=memory::observe(ref work_short);
    rejected(memory::reserve_work(ref mut work_short,5),2);
    unchanged(ref work_short,ref before_work);
    value(memory::reserve_work(ref mut work_short,4),7);
    let memory::Observation before_combined=memory::observe(ref combined_short);
    rejected(memory::reserve_work(ref mut combined_short,5),2);
    unchanged(ref combined_short,ref before_combined);
    value(memory::reserve_work(ref mut combined_short,4),7);
    state(ref combined_short,3,4,0,7,7,1);
}

@test
fn void retention_exact_and_one_less_ignore_working_ceiling_and_allow_retry() {
    var memory::Plan exact=switch(memory::create(memory::Limits{.working=1,.combined=8},3)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    var memory::Plan short=switch(memory::create(memory::Limits{.working=1,.combined=7},3)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    value(memory::reserve_work(ref mut exact,1),4);
    value(memory::begin_retention(ref mut exact,5),8);
    state(ref exact,3,0,5,8,8,2);
    value(memory::finish(ref mut exact),8);
    state(ref exact,3,0,5,8,8,3);
    value(memory::reserve_work(ref mut short,1),4);
    let memory::Observation before=memory::observe(ref short);
    rejected(memory::begin_retention(ref mut short,5),2);
    unchanged(ref short,ref before);
    value(memory::begin_retention(ref mut short,4),7);
    value(memory::finish(ref mut short),7);
    state(ref short,3,0,4,7,7,3);
}

@test
fn void exclusive_phases_use_maximum_peak_and_finish_keeps_published_bytes() {
    var memory::Plan work_peak=switch(memory::create(memory::Limits{.working=9,.combined=12},3)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    value(memory::reserve_work(ref mut work_peak,9),12);
    value(memory::begin_retention(ref mut work_peak,8),11);
    state(ref work_peak,3,0,8,11,12,2);
    value(memory::finish(ref mut work_peak),11);
    state(ref work_peak,3,0,8,11,12,3);
    var memory::Plan retention_peak=switch(memory::create(memory::Limits{.working=8,.combined=12},3)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    value(memory::reserve_work(ref mut retention_peak,8),11);
    value(memory::begin_retention(ref mut retention_peak,9),12);
    value(memory::finish(ref mut retention_peak),12);
    state(ref retention_peak,3,0,9,12,12,3);
}

@test
fn void maximum_usize_never_wraps_in_either_phase_or_peak() {
    let usize maximum=18446744073709551615;
    var memory::Plan edge=switch(memory::create(memory::Limits{.working=maximum,.combined=maximum},1)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    let memory::Observation initial=memory::observe(ref edge);
    rejected(memory::reserve_work(ref mut edge,maximum),2);
    unchanged(ref edge,ref initial);
    value(memory::reserve_work(ref mut edge,maximum-1),maximum);
    let memory::Observation working=memory::observe(ref edge);
    rejected(memory::begin_retention(ref mut edge,maximum),2);
    unchanged(ref edge,ref working);
    value(memory::begin_retention(ref mut edge,maximum-1),maximum);
    value(memory::finish(ref mut edge),maximum);
    state(ref edge,1,0,maximum-1,maximum,maximum,3);
    var memory::Plan zero=switch(memory::create(memory::Limits{.working=maximum,.combined=maximum},0)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    value(memory::reserve_work(ref mut zero,maximum),maximum);
    value(memory::begin_retention(ref mut zero,maximum),maximum);
    value(memory::abort(ref mut zero),0);
    state(ref zero,0,0,0,0,maximum,3);
    var memory::Plan full=switch(memory::create(memory::Limits{.working=maximum,.combined=maximum},maximum)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    let memory::Observation full_initial=memory::observe(ref full);
    rejected(memory::reserve_work(ref mut full,1),2);
    unchanged(ref full,ref full_initial);
    value(memory::reserve_work(ref mut full,0),maximum);
    let memory::Observation full_work=memory::observe(ref full);
    rejected(memory::begin_retention(ref mut full,1),2);
    unchanged(ref full,ref full_work);
    value(memory::begin_retention(ref mut full,0),maximum);
    value(memory::finish(ref mut full),maximum);
    state(ref full,maximum,0,0,maximum,maximum,3);
}

@test
fn void denied_transitions_preserve_every_field_and_valid_next_step_still_works() {
    let usize maximum=18446744073709551615;
    var memory::Plan plan=switch(memory::create(memory::Limits{.working=5,.combined=8},3)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    let memory::Observation initial=memory::observe(ref plan);
    rejected(memory::begin_retention(ref mut plan,maximum),3);
    unchanged(ref plan,ref initial);
    rejected(memory::finish(ref mut plan),3);
    unchanged(ref plan,ref initial);
    rejected(memory::abort(ref mut plan),3);
    unchanged(ref plan,ref initial);
    value(memory::reserve_work(ref mut plan,5),8);
    let memory::Observation working=memory::observe(ref plan);
    rejected(memory::reserve_work(ref mut plan,0),3);
    unchanged(ref plan,ref working);
    rejected(memory::reserve_work(ref mut plan,maximum),3);
    unchanged(ref plan,ref working);
    rejected(memory::finish(ref mut plan),3);
    unchanged(ref plan,ref working);
    value(memory::begin_retention(ref mut plan,4),7);
    let memory::Observation retained=memory::observe(ref plan);
    rejected(memory::reserve_work(ref mut plan,maximum),3);
    unchanged(ref plan,ref retained);
    rejected(memory::begin_retention(ref mut plan,0),3);
    unchanged(ref plan,ref retained);
    rejected(memory::begin_retention(ref mut plan,maximum),3);
    unchanged(ref plan,ref retained);
    value(memory::finish(ref mut plan),7);
    let memory::Observation finished=memory::observe(ref plan);
    rejected(memory::reserve_work(ref mut plan,0),3);
    unchanged(ref plan,ref finished);
    rejected(memory::begin_retention(ref mut plan,0),3);
    unchanged(ref plan,ref finished);
    rejected(memory::finish(ref mut plan),3);
    unchanged(ref plan,ref finished);
    rejected(memory::abort(ref mut plan),3);
    unchanged(ref plan,ref finished);
}

@test
fn void abort_releases_each_live_phase_keeps_external_baseline_and_historical_peak() {
    var memory::Plan work=switch(memory::create(memory::Limits{.working=5,.combined=8},3)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    value(memory::reserve_work(ref mut work,5),8);
    value(memory::abort(ref mut work),3);
    state(ref work,3,0,0,3,8,3);
    let memory::Observation aborted=memory::observe(ref work);
    rejected(memory::abort(ref mut work),3);
    unchanged(ref work,ref aborted);
    rejected(memory::finish(ref mut work),3);
    unchanged(ref work,ref aborted);
    rejected(memory::reserve_work(ref mut work,0),3);
    unchanged(ref work,ref aborted);
    rejected(memory::begin_retention(ref mut work,0),3);
    unchanged(ref work,ref aborted);
    var memory::Plan retained=switch(memory::create(memory::Limits{.working=1,.combined=8},3)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    value(memory::reserve_work(ref mut retained,1),4);
    value(memory::begin_retention(ref mut retained,5),8);
    value(memory::abort(ref mut retained),3);
    state(ref retained,3,0,0,3,8,3);
}

@test
fn void invalid_limits_precede_baseline_quota_and_zero_reservations_are_valid() {
    let usize maximum=18446744073709551615;
    var memory::Plan unlimited=memory::unlimited();
    assert(unlimited.working_limit==maximum && unlimited.combined_limit==maximum);
    state(ref unlimited,0,0,0,0,0,0);
    value(memory::reserve_work(ref mut unlimited,maximum),maximum);
    value(memory::begin_retention(ref mut unlimited,maximum),maximum);
    value(memory::finish(ref mut unlimited),maximum);
    state(ref unlimited,0,0,maximum,maximum,maximum,3);
    create_rejected(0,0,0,1);
    create_rejected(0,1,maximum,1);
    create_rejected(1,0,maximum,1);
    create_rejected(0,maximum,0,1);
    create_rejected(maximum,0,0,1);
    create_rejected(1,1,2,2);
    create_rejected(maximum,maximum-1,maximum,2);
    var memory::Plan empty=switch(memory::create(memory::Limits{.working=maximum,.combined=1},0)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    assert(empty.working_limit==maximum && empty.combined_limit==1);
    state(ref empty,0,0,0,0,0,0);
    value(memory::reserve_work(ref mut empty,0),0);
    value(memory::begin_retention(ref mut empty,0),0);
    value(memory::finish(ref mut empty),0);
    state(ref empty,0,0,0,0,0,3);
    var memory::Plan baseline=switch(memory::create(memory::Limits{.working=1,.combined=1},1)) {
        case .ok(plan): { plan } case .err(_): { assert(false); return; }
    };
    state(ref baseline,1,0,0,1,1,0);
    value(memory::reserve_work(ref mut baseline,0),1);
    value(memory::begin_retention(ref mut baseline,0),1);
    value(memory::abort(ref mut baseline),1);
    state(ref baseline,1,0,0,1,1,3);
}
