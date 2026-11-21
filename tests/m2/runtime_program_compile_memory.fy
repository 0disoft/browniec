module tests::m2::runtime_program_compile_memory;
import runtime_program_memory as budget;
import compile_memory as memory;
import module_budgeted_compile as compiler;
import retention_plan as retained;

// Trusted scalar fixtures only: fixed()/native layout is not available to the
// source-test interpreter. Peers enter through publish, never a native Program.
// Synthetic retained charges straddle the current work reservation, so their
// ordering survives compiler scratch changes without resetting any history.
fn budget::Budget seed(usize engine,usize control,usize working){
    return budget::Budget{.engine=engine,.program=engine,.programs=engine,
        .control=control,.control_peak=control,.retained=0,.peak=0,.closed=false,
        .working_limit=working,.working_peak=0,.tracked_peak=control,.external=0,.compile_source=0};
}
fn u8 error_code(budget::Error e){
    return switch(e){case .Invalid:{1}case .Quota:{2}case .State:{3}};
}
fn void value(Result<usize,budget::Error> r,usize expected){
    switch(r){case .ok(v):{assert(v==expected);}case .err(_):{assert(false);return;}};
}
fn void phase_value(Result<usize,memory::Error> r,usize expected){
    switch(r){case .ok(v):{assert(v==expected);}case .err(_):{assert(false);return;}};
}
fn void rejected(Result<usize,budget::Error> r,u8 expected){
    switch(r){case .ok(_):{assert(false);return;}case .err(e):{assert(error_code(e)==expected);}};
}
fn void same(ref budget::Budget b,ref budget::Budget before){
    assert(b.engine==before.engine && b.program==before.program && b.programs==before.programs);
    assert(b.control==before.control && b.control_peak==before.control_peak);
    assert(b.retained==before.retained && b.peak==before.peak && b.closed==before.closed);
    assert(b.working_limit==before.working_limit && b.working_peak==before.working_peak);
    assert(b.tracked_peak==before.tracked_peak && b.external==before.external && b.compile_source==before.compile_source);
}
fn budget::Budget snapshot(ref budget::Budget b){
    return budget::Budget{.engine=b.engine,.program=b.program,.programs=b.programs,
        .control=b.control,.control_peak=b.control_peak,.retained=b.retained,.peak=b.peak,
        .closed=b.closed,.working_limit=b.working_limit,.working_peak=b.working_peak,
        .tracked_peak=b.tracked_peak,.external=b.external,.compile_source=b.compile_source};
}
fn void denied_prepare(ref mut budget::Budget b,usize overhead,u8 expected){
    let budget::Budget before=snapshot(b);
    switch(budget::prepare_compile(b,overhead)){
        case .ok(_):{assert(false);return;}case .err(e):{assert(error_code(e)==expected);}
    };
    same(b,ref before);
}
fn void create_rejected(budget::Limits limits,usize control,usize working,u8 expected){
    switch(budget::create_with_working(limits,control,working)){
        case .ok(_):{assert(false);return;}case .err(e):{assert(error_code(e)==expected);}
    };
}
fn void observed(ref budget::Budget b,usize control,usize programs,usize program_peak,
    usize tracked_peak,usize working_peak,bool closed){
    let budget::Observation o=budget::observe(b);
    assert(o.engine_limit==b.engine && o.program_limit==b.program && o.programs_limit==b.programs);
    assert(o.control_bytes==control && o.program_bytes==programs && o.program_peak==program_peak);
    assert(o.tracked_bytes==control+programs+b.external+b.compile_source && o.tracked_peak==tracked_peak);
    assert(o.external_bytes==b.external && o.compile_source_bytes==b.compile_source);
    assert(o.working_limit==b.working_limit && o.working_peak==working_peak && o.closed==closed);
}

@test
fn void defaults_and_private_working_limits_preserve_existing_limits(){
    let usize maximum=18446744073709551615;
    let budget::Limits limits=budget::defaults();
    assert(limits.engine==1073741824 && limits.program==67108864 && limits.programs==536870912);
    let budget::Budget original=switch(budget::create(limits,7)){
        case .ok(b):{b}case .err(_):{assert(false);return;}
    };
    let budget::Budget explicit=switch(budget::create_with_working(limits,7,268435456)){
        case .ok(b):{b}case .err(_):{assert(false);return;}
    };
    same(ref original,ref explicit);
    assert(original.working_limit==268435456 && original.control_peak==7);
    observed(ref original,7,0,0,7,0,false);
    let budget::Budget minimum=switch(budget::create_with_working(limits,0,1)){
        case .ok(b):{b}case .err(_):{assert(false);return;}
    };
    assert(minimum.working_limit==1);
    create_rejected(limits,maximum,0,1);
    create_rejected(limits,0,268435457,1);
    create_rejected(limits,0,maximum,1);
    create_rejected(limits,1073741825,1,2);
    create_rejected(limits,maximum,1,2);
    create_rejected(budget::Limits{.engine=0,.program=1,.programs=1},0,1,1);
    create_rejected(budget::Limits{.engine=1073741825,.program=1,.programs=1},0,1,1);
    create_rejected(budget::Limits{.engine=1073741824,.program=0,.programs=1},0,1,1);
    create_rejected(budget::Limits{.engine=1073741824,.program=67108865,.programs=536870912},0,1,1);
    create_rejected(budget::Limits{.engine=1073741824,.program=1,.programs=0},0,1,1);
    create_rejected(budget::Limits{.engine=1073741824,.program=1,.programs=536870913},0,1,1);
    create_rejected(budget::Limits{.engine=7,.program=2,.programs=1},0,1,1);
    create_rejected(budget::Limits{.engine=7,.program=1,.programs=8},0,1,1);
    let budget::Budget full=switch(budget::create_with_working(
        budget::Limits{.engine=7,.program=1,.programs=7},7,268435456)){
        case .ok(b):{b}case .err(_):{assert(false);return;}
    };
    observed(ref full,7,0,0,7,0,false);
}

@test
fn void overhead_plus_scratch_exact_and_one_less_limits_return_original_phase_zero(){
    let usize work=compiler::working_bound();assert(work==66630144);
    var budget::Budget exact=seed(work+15,7,work+5);
    value(budget::publish(ref mut exact,3),3);
    var memory::Plan plan=switch(budget::prepare_compile(ref mut exact,5)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    assert(plan.working_limit==work && plan.combined_limit==work+15 && plan.baseline==15);
    assert(plan.phase==0 && plan.working_bytes==0 && plan.persistent_bytes==0);
    assert(plan.current==15 && plan.peak==15);
    observed(ref exact,7,3,3,work+15,work+5,false);
    // The actual wrapper can still reserve the original phase-0 plan itself.
    phase_value(memory::reserve_work(ref mut plan,work),work+15);
    phase_value(memory::abort(ref mut plan),15);
    value(budget::record_compile(ref mut exact,ref plan),work+15);
    observed(ref exact,7,3,3,work+15,work+5,false);
    var budget::Budget working_short=seed(work+15,7,work+4);
    value(budget::publish(ref mut working_short,3),3);
    denied_prepare(ref mut working_short,5,2);
    var budget::Budget combined_short=seed(work+14,7,work+5);
    value(budget::publish(ref mut combined_short,3),3);
    denied_prepare(ref mut combined_short,5,2);
    // overhead itself exact at the working limit leaves no scratch allowance.
    denied_prepare(ref mut working_short,work+4,2);
    denied_prepare(ref mut working_short,work+5,2);
}

@test
fn void overflow_and_rejected_baselines_preserve_every_budget_field(){
    let usize maximum=18446744073709551615;
    var budget::Budget b=seed((compiler::working_bound()+400000),7,268435456);
    value(budget::publish(ref mut b,11),11);
    let memory::Plan prepared=switch(budget::prepare_compile(ref mut b,13)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    denied_prepare(ref mut b,maximum,2);
    // These pass the working check but fail combined/baseline checks.
    b.engine=30;denied_prepare(ref mut b,13,2);
    b.engine=(compiler::working_bound()+400000);b.control=maximum;denied_prepare(ref mut b,0,2);
    b.control=7;b.retained=maximum;denied_prepare(ref mut b,0,2);
    b.retained=11;b.working_limit=0;denied_prepare(ref mut b,0,2);
    b.closed=true;denied_prepare(ref mut b,maximum,3);
    let budget::Budget before=b;
    rejected(budget::record_compile(ref mut b,ref prepared),3);
    same(ref b,ref before);
}

@test
fn void published_peers_share_combined_allowance_and_release_restores_headroom(){
    let usize work=compiler::working_bound();
    var budget::Budget b=seed(work+130,10,work+20);
    value(budget::publish(ref mut b,100),100);
    let memory::Plan first=switch(budget::prepare_compile(ref mut b,20)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    assert(first.baseline==130 && first.phase==0);
    observed(ref b,10,100,100,work+130,work+20,false);
    value(budget::publish(ref mut b,1),101);
    denied_prepare(ref mut b,20,2);
    value(budget::release(ref mut b,101),0);
    let memory::Plan next=switch(budget::prepare_compile(ref mut b,20)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    assert(next.baseline==30 && next.working_limit==work);
    observed(ref b,10,0,101,work+130,work+20,false);
}

@test
fn void compilation_and_program_high_water_marks_are_independent_histories(){
    let usize work=compiler::working_bound();
    var budget::Budget b=seed((compiler::working_bound()+400000),7,268435456);
    var memory::Plan plan=switch(budget::prepare_compile(ref mut b,0)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    observed(ref b,7,0,0,work+7,work,false);
    let retained::Plan reservation=retained::Plan{.fixed=1,.limit=(compiler::working_bound()+400000),.bytes=(compiler::working_bound()+100000),.admitted=true};
    value(budget::record(ref mut b,ref reservation),(compiler::working_bound()+100000));
    observed(ref b,7,0,(compiler::working_bound()+100000),(compiler::working_bound()+100007),work,false);
    phase_value(memory::reserve_work(ref mut plan,work),work+7);
    phase_value(memory::begin_retention(ref mut plan,(compiler::working_bound()+300000)),(compiler::working_bound()+300007));
    phase_value(memory::abort(ref mut plan),7);
    value(budget::record_compile(ref mut b,ref plan),(compiler::working_bound()+300007));
    observed(ref b,7,0,(compiler::working_bound()+100000),(compiler::working_bound()+300007),work,false);
    value(budget::publish(ref mut b,10000),10000);
    value(budget::release(ref mut b,10000),0);
    observed(ref b,7,0,(compiler::working_bound()+100000),(compiler::working_bound()+300007),work,false);
    var memory::Plan smaller=switch(budget::prepare_compile(ref mut b,1)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    phase_value(memory::reserve_work(ref mut smaller,work),work+8);
    phase_value(memory::abort(ref mut smaller),8);
    value(budget::record_compile(ref mut b,ref smaller),work+8);
    observed(ref b,7,0,(compiler::working_bound()+100000),(compiler::working_bound()+300007),work+1,false);
}

@test
fn void aborted_work_and_admitted_oom_preserve_reservations_without_publishing(){
    let usize work=compiler::working_bound();
    var budget::Budget b=seed((compiler::working_bound()+400000),7,268435456);
    value(budget::publish(ref mut b,11),11);
    var memory::Plan source_failure=switch(budget::prepare_compile(ref mut b,13)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    phase_value(memory::reserve_work(ref mut source_failure,work),work+31);
    phase_value(memory::abort(ref mut source_failure),31);
    value(budget::record_compile(ref mut b,ref source_failure),work+31);
    observed(ref b,7,11,11,work+31,work+13,false);
    var memory::Plan oom=switch(budget::prepare_compile(ref mut b,13)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    phase_value(memory::reserve_work(ref mut oom,work),work+31);
    phase_value(memory::begin_retention(ref mut oom,(compiler::working_bound()+200000)),(compiler::working_bound()+200031));
    phase_value(memory::abort(ref mut oom),31);
    assert(oom.phase==3 && oom.current==31 && oom.persistent_bytes==0);
    value(budget::record_compile(ref mut b,ref oom),(compiler::working_bound()+200031));
    // Engine records an admitted Program attempt independently, even on OOM.
    let retained::Plan admitted=retained::Plan{.fixed=1,.limit=(compiler::working_bound()+400000),.bytes=(compiler::working_bound()+200000),.admitted=true};
    value(budget::record(ref mut b,ref admitted),(compiler::working_bound()+200000));
    observed(ref b,7,11,(compiler::working_bound()+200011),(compiler::working_bound()+200031),work+13,false);
}

@test
fn void successful_phase_records_before_separate_program_publication(){
    let usize work=compiler::working_bound();
    var budget::Budget b=seed((compiler::working_bound()+400000),7,268435456);
    value(budget::publish(ref mut b,11),11);
    var memory::Plan plan=switch(budget::prepare_compile(ref mut b,13)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    phase_value(memory::reserve_work(ref mut plan,work),work+31);
    phase_value(memory::begin_retention(ref mut plan,(compiler::working_bound()+100000)),(compiler::working_bound()+100031));
    phase_value(memory::finish(ref mut plan),(compiler::working_bound()+100031));
    assert(plan.phase==3 && plan.current==(compiler::working_bound()+100031) && plan.persistent_bytes==(compiler::working_bound()+100000));
    value(budget::record_compile(ref mut b,ref plan),(compiler::working_bound()+100031));
    observed(ref b,7,11,11,(compiler::working_bound()+100031),work+13,false);
    let retained::Plan admitted=retained::Plan{.fixed=1,.limit=(compiler::working_bound()+400000),.bytes=(compiler::working_bound()+100000),.admitted=true};
    value(budget::record(ref mut b,ref admitted),(compiler::working_bound()+100000));
    value(budget::publish(ref mut b,(compiler::working_bound()+100000)),(compiler::working_bound()+100011));
    observed(ref b,7,(compiler::working_bound()+100011),(compiler::working_bound()+100011),(compiler::working_bound()+100031),work+13,false);
    value(budget::release(ref mut b,(compiler::working_bound()+100000)),11);
    value(budget::release(ref mut b,11),0);
    observed(ref b,7,0,(compiler::working_bound()+100011),(compiler::working_bound()+100031),work+13,false);
}

@test
fn void direct_program_record_and_publish_track_actual_aggregate_and_reject_atomically(){
    var budget::Budget b=seed(107,7,268435456);
    value(budget::publish(ref mut b,20),20);
    observed(ref b,7,20,20,27,0,false);
    let retained::Plan empty=retained::Plan{.fixed=1,.limit=100,.bytes=80,.admitted=false};
    let budget::Budget before=b;
    value(budget::record(ref mut b,ref empty),0);same(ref b,ref before);
    let retained::Plan too_large=retained::Plan{.fixed=1,.limit=107,.bytes=81,.admitted=true};
    rejected(budget::record(ref mut b,ref too_large),3);same(ref b,ref before);
    rejected(budget::publish(ref mut b,81),3);same(ref b,ref before);
    rejected(budget::release(ref mut b,18446744073709551615),3);same(ref b,ref before);
    let retained::Plan exact=retained::Plan{.fixed=1,.limit=100,.bytes=80,.admitted=true};
    value(budget::record(ref mut b,ref exact),80);
    observed(ref b,7,20,100,107,0,false);
    value(budget::publish(ref mut b,80),100);
    value(budget::release(ref mut b,100),0);
    observed(ref b,7,0,100,107,0,false);
}

@test
fn void moves_and_close_release_control_preserve_peaks_and_reject_further_operations(){
    let usize work=compiler::working_bound();
    var budget::Budget original=seed((compiler::working_bound()+400000),7,268435456);
    value(budget::publish(ref mut original,11),11);
    let memory::Plan original_plan=switch(budget::prepare_compile(ref mut original,13)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    var budget::Budget moved=original;
    var memory::Plan moved_plan=original_plan;
    phase_value(memory::reserve_work(ref mut moved_plan,work),work+31);
    phase_value(memory::begin_retention(ref mut moved_plan,(compiler::working_bound()+100000)),(compiler::working_bound()+100031));
    phase_value(memory::abort(ref mut moved_plan),31);
    value(budget::record_compile(ref mut moved,ref moved_plan),(compiler::working_bound()+100031));
    let budget::Budget nonempty=moved;
    rejected(budget::close(ref mut moved),3);same(ref moved,ref nonempty);
    value(budget::release(ref mut moved,11),0);
    value(budget::close(ref mut moved),0);
    assert(moved.control==0 && moved.control_peak==7);
    observed(ref moved,0,0,11,(compiler::working_bound()+100031),work+13,true);
    let budget::Budget closed=moved;
    denied_prepare(ref mut moved,0,3);
    rejected(budget::record_compile(ref mut moved,ref moved_plan),3);
    let retained::Plan reservation=retained::Plan{.fixed=1,.limit=(compiler::working_bound()+400000),.bytes=0,.admitted=false};
    rejected(budget::record(ref mut moved,ref reservation),3);
    rejected(budget::publish(ref mut moved,0),3);
    rejected(budget::release(ref mut moved,0),3);
    rejected(budget::close(ref mut moved),3);
    same(ref moved,ref closed);
}

@test
fn void external_exact_and_one_less_combined_limits_reject_without_mutation(){
    let usize maximum=18446744073709551615;
    var budget::Budget exact=seed(107,7,268435456);
    value(budget::publish(ref mut exact,20),20);
    value(budget::prepare_external(ref mut exact,80),107);
    // Preparing a peak does not publish an external owner.
    assert(exact.external==0);
    observed(ref exact,7,20,20,107,0,false);
    value(budget::commit_external(ref mut exact,80),80);
    observed(ref exact,7,20,20,107,0,false);
    let budget::Budget full=snapshot(ref exact);
    rejected(budget::prepare_external(ref mut exact,81),2);same(ref exact,ref full);
    rejected(budget::commit_external(ref mut exact,81),3);same(ref exact,ref full);
    rejected(budget::prepare_external(ref mut exact,79),3);same(ref exact,ref full);
    rejected(budget::prepare_external(ref mut exact,maximum),2);same(ref exact,ref full);
    rejected(budget::commit_external(ref mut exact,maximum),3);same(ref exact,ref full);
    var budget::Budget short=seed(106,7,268435456);
    value(budget::publish(ref mut short,20),20);
    let budget::Budget before=snapshot(ref short);
    rejected(budget::prepare_external(ref mut short,80),2);same(ref short,ref before);
    rejected(budget::commit_external(ref mut short,80),3);same(ref short,ref before);
    observed(ref short,7,20,20,27,0,false);
    value(budget::commit_external(ref mut exact,0),0);
    observed(ref exact,7,20,20,107,0,false);
}

@test
fn void external_current_is_in_compile_phase_zero_baseline_and_combined_admission(){
    let usize work=compiler::working_bound();
    var budget::Budget exact=seed(work+24,7,work+5);
    value(budget::publish(ref mut exact,3),3);
    value(budget::prepare_external(ref mut exact,9),19);
    value(budget::commit_external(ref mut exact,9),9);
    var memory::Plan plan=switch(budget::prepare_compile(ref mut exact,5)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    assert(plan.baseline==24 && plan.combined_limit==work+24 && plan.working_limit==work);
    assert(plan.phase==0 && plan.current==24 && plan.peak==24);
    assert(plan.working_bytes==0 && plan.persistent_bytes==0 && exact.external==9);
    observed(ref exact,7,3,3,work+24,work+5,false);
    phase_value(memory::reserve_work(ref mut plan,work),work+24);
    phase_value(memory::abort(ref mut plan),24);
    value(budget::record_compile(ref mut exact,ref plan),work+24);
    assert(exact.external==9);
    observed(ref exact,7,3,3,work+24,work+5,false);
    var budget::Budget short=seed(work+23,7,work+5);
    value(budget::publish(ref mut short,3),3);
    value(budget::commit_external(ref mut short,9),9);
    denied_prepare(ref mut short,5,2);
    // Guard the external subtraction before constructing an overflowing baseline.
    var budget::Budget overflow=seed((compiler::working_bound()+400000),7,268435456);
    value(budget::publish(ref mut overflow,3),3);
    overflow.external=18446744073709551615;
    denied_prepare(ref mut overflow,0,2);
}

@test
fn void external_current_limits_retained_publication_and_survives_program_release(){
    var budget::Budget b=seed(107,7,268435456);
    value(budget::publish(ref mut b,20),20);
    value(budget::prepare_external(ref mut b,30),57);
    value(budget::commit_external(ref mut b,30),30);
    let budget::Budget before=snapshot(ref b);
    let retained::Plan too_large=retained::Plan{.fixed=1,.limit=107,.bytes=51,.admitted=true};
    rejected(budget::record(ref mut b,ref too_large),3);same(ref b,ref before);
    rejected(budget::publish(ref mut b,51),3);same(ref b,ref before);
    let retained::Plan exact=retained::Plan{.fixed=1,.limit=107,.bytes=50,.admitted=true};
    value(budget::record(ref mut b,ref exact),50);
    observed(ref b,7,20,70,107,0,false);
    value(budget::publish(ref mut b,50),70);
    observed(ref b,7,70,70,107,0,false);
    value(budget::release(ref mut b,70),0);
    assert(b.external==30);
    observed(ref b,7,0,70,107,0,false);
    let budget::Budget released=snapshot(ref b);
    // Releasing Programs restores only their own headroom, not the external 30.
    rejected(budget::publish(ref mut b,71),3);same(ref b,ref released);
    value(budget::publish(ref mut b,70),70);
    value(budget::release(ref mut b,70),0);
    observed(ref b,7,0,70,107,0,false);
}

@test
fn void external_owner_blocks_close_and_refunds_and_moves_preserve_all_peaks(){
    let usize work=compiler::working_bound();
    var budget::Budget original=seed((compiler::working_bound()+400000),7,268435456);
    value(budget::publish(ref mut original,11),11);
    value(budget::prepare_external(ref mut original,work+250000),work+250018);
    value(budget::commit_external(ref mut original,17),17);
    let memory::Plan plan=switch(budget::prepare_compile(ref mut original,13)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    assert(plan.baseline==48 && plan.phase==0);
    var budget::Budget moved=original;
    same(ref moved,ref original);
    observed(ref moved,7,11,11,work+250018,work+13,false);
    value(budget::release(ref mut moved,11),0);
    assert(moved.external==17);
    let budget::Budget external_only=snapshot(ref moved);
    rejected(budget::close(ref mut moved),3);same(ref moved,ref external_only);
    value(budget::commit_external(ref mut moved,0),0);
    observed(ref moved,7,0,11,work+250018,work+13,false);
    value(budget::close(ref mut moved),0);
    assert(moved.control_peak==7 && moved.external==0);
    observed(ref moved,0,0,11,work+250018,work+13,true);
    let budget::Budget closed=snapshot(ref moved);
    rejected(budget::prepare_external(ref mut moved,0),3);same(ref moved,ref closed);
    rejected(budget::commit_external(ref mut moved,0),3);same(ref moved,ref closed);
    rejected(budget::prepare_external(ref mut moved,18446744073709551615),3);
    rejected(budget::commit_external(ref mut moved,18446744073709551615),3);
    same(ref moved,ref closed);
}

@test
fn void compile_source_shares_limits_and_refunds_only_its_own_charge(){
    let usize work=compiler::working_bound();
    var budget::Budget b=seed(work+28,7,work+15);
    value(budget::publish(ref mut b,2),2);
    value(budget::commit_external(ref mut b,4),4);
    let budget::Budget before=snapshot(ref b);
    rejected(budget::hold_compile_source(ref mut b,work+16),2);same(ref b,ref before);
    value(budget::hold_compile_source(ref mut b,15),15);
    observed(ref b,7,2,2,28,15,false);
    let budget::Budget held=snapshot(ref b);
    rejected(budget::hold_compile_source(ref mut b,1),3);same(ref b,ref held);
    rejected(budget::release_compile_source(ref mut b,14),3);same(ref b,ref held);
    denied_prepare(ref mut b,1,2);
    switch(budget::prepare_compile(ref mut b,0)){
        case .ok(plan):{assert(plan.baseline==28 && plan.working_limit==work);}
        case .err(_):{assert(false);return;}
    };
    value(budget::prepare_external(ref mut b,work+4),work+28);
    rejected(budget::prepare_external(ref mut b,work+5),2);
    rejected(budget::publish(ref mut b,work+1),3);
    value(budget::publish(ref mut b,work),work+2);
    rejected(budget::close(ref mut b),3);
    value(budget::release_compile_source(ref mut b,15),0);
    observed(ref b,7,work+2,work+2,work+28,work+15,false);
    assert(b.external==4);
    rejected(budget::release_compile_source(ref mut b,15),3);
    value(budget::release(ref mut b,work+2),0);
    value(budget::commit_external(ref mut b,0),0);
    value(budget::close(ref mut b),0);

    var budget::Budget exact=seed(26,7,15);
    value(budget::commit_external(ref mut exact,4),4);
    value(budget::hold_compile_source(ref mut exact,15),15);
    var budget::Budget short=seed(25,7,15);
    value(budget::commit_external(ref mut short,4),4);
    let budget::Budget snapshot_short=snapshot(ref short);
    rejected(budget::hold_compile_source(ref mut short,15),2);same(ref short,ref snapshot_short);
}
