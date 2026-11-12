module tests::m2::module_compile_memory;
import module_budgeted_compile as compile;
import compile_memory as memory;
import retention_plan as retention;
import module_entry as entries;
import module_input_entry as input_entries;
import module_index as modules;
import source_snapshot as sources;
import module_program as ordinary;
import module_input_program as inputs;
import module_output_program as outputs;
import std::bytes as bytes;

// These symbols exist only in the dedicated --suite compile-memory runtime.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_peak_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void probe_rebase();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);

// A trusted conservative test charge, not a measurement of total native heap.
fn usize fixed(){return compile::working_bound()+1048576;}
fn usize baseline(){return 73;}
fn i64 fault_at(usize ordinal){
    assert(ordinal<=128);var usize at=0;var i64 value=0;
    while(at<ordinal){at+=1;value+=1;}return value;
}
fn retention::Plan retained(){return retention::Plan{
    .fixed=fixed(),.limit=18446744073709551615,.bytes=0,.admitted=false};}
fn memory::Plan budget(usize work,usize combined){return switch(memory::create(
    memory::Limits{.working=work,.combined=combined},baseline())){
    case .ok(v):{v}case .err(_):{assert(false);memory::unlimited()}
};}

fn Result<modules::Index,u8> indexed(ref u8[] source){
    var sources::Builder b=switch(sources::builder(4096,4096)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    if(!sources::add(ref mut b,b"app.brc",source).is_ok){return .err(2);}
    let sources::Snapshot s=switch(sources::freeze(ref b)){
        case .ok(v):{v}case .err(_):{return .err(3);}
    };
    return switch(modules::build(s)){case .ok(v):{.ok(v)}case .err(_):{.err(4)}};
}
fn Result<entries::Entry,u8> selected(ref u8[] source){
    return switch(entries::select_i32(indexed(source)?,b"app",b"chosen")){
        case .ok(v):{.ok(v)}case .err(_):{.err(5)}
    };
}
fn Result<input_entries::InputEntry,u8> selected_input(ref u8[] source){
    return switch(input_entries::select_i32_input(indexed(source)?,b"app",b"chosen")){
        case .ok(v):{.ok(v)}case .err(_):{.err(6)}
    };
}
fn ref u8[] source(u8 mode,bool malformed){
    // Nine references to one register force Vec8 -> Vec16 growth without nine
    // fresh scalar registers. The marker forces the retained-image route.
    if(malformed){
        if(mode==1 || mode==3){return b"module app;pub fn i32 chosen(ref u8[] data){let i32 x=21;let a=[x,x,x,x,x,x,x,x,x];return missing;}";}
        return b"module app;pub fn i32 chosen(){let i32 x=21;let a=[x,x,x,x,x,x,x,x,x];return missing;}";
    }
    if(mode==1){return b"module app;pub fn i32 chosen(ref u8[] data){let ref u8[] marker=b\"*\";let i32 x=21;let a=[x,x,x,x,x,x,x,x,x];return a[0]+a[8];}";}
    if(mode==3){return b"module app;pub fn i32 chosen(ref u8[] data){let ref u8[] marker=b\"*\";let i32 x=21;let a=[x,x,x,x,x,x,x,x,x];output::emit(ref marker);return a[0]+a[8];}";}
    if(mode==2){return b"module app;pub fn i32 chosen(){let ref u8[] marker=b\"*\";let i32 x=21;let a=[x,x,x,x,x,x,x,x,x];output::emit(ref marker);return a[0]+a[8];}";}
    return b"module app;pub fn i32 chosen(){let ref u8[] marker=b\"*\";let i32 x=21;let a=[x,x,x,x,x,x,x,x,x];return a[0]+a[8];}";
}

struct Stats { bool success; u8 kind; usize attempts; usize peak_bytes; usize entry_bytes; usize live_bytes; }
fn Stats observed(bool success,u8 kind,usize entry_bytes){
    return Stats{.success=success,.kind=kind,.attempts=unsafe{probe_attempts()},
        .peak_bytes=unsafe{probe_peak_bytes()},.entry_bytes=entry_bytes,
        .live_bytes=unsafe{probe_live_bytes()}};
}
// Construct Entry BEFORE rebase and fault injection. Consume each owning
// Result exactly once in a switch; all Program/Entry resources die in this frame.
fn Stats attempt(u8 mode,ref u8[] text,ref mut retention::Plan r,
    ref mut memory::Plan m,i64 fault){
    let usize before_live=unsafe{probe_live()};
    let usize before_bytes=unsafe{probe_live_bytes()};
    var Stats result=Stats{.success=false,.kind=255,.attempts=0,
        .peak_bytes=0,.entry_bytes=0,.live_bytes=0};
    if(mode==1 || mode==3){
        let input_entries::InputEntry entry=switch(selected_input(text)){
            case .ok(v):{v}case .err(_):{assert(false);return result;}
        };
        let usize entry_bytes=unsafe{probe_live_bytes()};
        unsafe{probe_rebase()};unsafe{bc_runtime_engine_test_fail(fault)};
        if(mode==1){
            result=switch(compile::compile_input(entry,65536,r,m)){
                case .ok(p):{
                    assert(inputs::code(ref p).body.count!=0);
                    observed(true,0,entry_bytes)
                }
                case .err(e):{observed(false,e.code.kind,entry_bytes)}
            };
        }else{
            result=switch(compile::compile_input_output(entry,65536,r,m)){
                case .ok(p):{
                    assert(outputs::accepts_input(ref p) && outputs::code(ref p).body.count!=0);
                    observed(true,0,entry_bytes)
                }
                case .err(e):{observed(false,e.code.kind,entry_bytes)}
            };
        }
    }else{
        let entries::Entry entry=switch(selected(text)){
            case .ok(v):{v}case .err(_):{assert(false);return result;}
        };
        let usize entry_bytes=unsafe{probe_live_bytes()};
        unsafe{probe_rebase()};unsafe{bc_runtime_engine_test_fail(fault)};
        if(mode==0){
            result=switch(compile::compile(entry,65536,r,m)){
                case .ok(p):{
                    assert(ordinary::body(ref p).count!=0 && ordinary::profile(ref p)==8);
                    observed(true,0,entry_bytes)
                }
                case .err(e):{observed(false,e.code.kind,entry_bytes)}
            };
        }else{
            result=switch(compile::compile_output(entry,65536,r,m)){
                case .ok(p):{
                    assert(!outputs::accepts_input(ref p) && outputs::code(ref p).body.count!=0);
                    observed(true,0,entry_bytes)
                }
                case .err(e):{observed(false,e.code.kind,entry_bytes)}
            };
        }
    }
    unsafe{bc_runtime_engine_test_fail(-1)};
    assert(unsafe{probe_live()}==before_live);
    assert(unsafe{probe_live_bytes()}==before_bytes);
    return result;
}
fn void clean(){assert(unsafe{probe_live()}==0 && unsafe{probe_live_bytes()}==0);}
fn void same_retention(ref retention::Plan r,ref retention::Plan before){
    assert(r.fixed==before.fixed && r.limit==before.limit);
    assert(r.bytes==before.bytes && r.admitted==before.admitted);
}
fn void same_memory(ref memory::Plan m,ref memory::Observation before){
    let memory::Observation now=memory::observe(m);
    assert(now.working_limit==before.working_limit && now.combined_limit==before.combined_limit);
    assert(now.baseline==before.baseline && now.working_bytes==before.working_bytes);
    assert(now.persistent_bytes==before.persistent_bytes && now.current==before.current);
    assert(now.peak==before.peak && now.phase==before.phase);
}
fn void terminal(ref memory::Plan m,usize persistent,usize peak){
    let memory::Observation o=memory::observe(m);
    assert(o.phase==3 && o.baseline==baseline() && o.working_bytes==0);
    assert(o.persistent_bytes==persistent && o.current==baseline()+persistent);
    assert(o.peak==baseline()+peak);
}
fn void admitted(ref retention::Plan r){
    assert(r.fixed==fixed() && r.limit==18446744073709551615);
    assert(r.admitted && r.bytes==fixed()+1);
}
fn void denied(ref Stats s,u8 kind){assert(!s.success && s.kind==kind);}
fn void no_allocation(ref Stats s){
    assert(s.attempts==0 && s.peak_bytes==s.entry_bytes);
}
fn void scratch_peak(ref Stats s){
    assert(s.peak_bytes>=s.entry_bytes);
    assert(s.peak_bytes-s.entry_bytes<=compile::working_bound());
}
fn void recovery(u8 mode){
    var retention::Plan r=retained();
    var memory::Plan m=budget(compile::working_bound(),baseline()+fixed()+1);
    let Stats s=attempt(mode,source(mode,false),ref mut r,ref mut m,-1);
    assert(s.success && s.kind==0 && s.attempts>=4);
    admitted(ref r);terminal(ref m,fixed()+1,fixed()+1);
    assert(s.live_bytes<=s.entry_bytes+fixed()+1);
    assert(s.peak_bytes<=s.entry_bytes+fixed()+1);
}

@test fn void all_four_compilers_admit_nine_reused_cells_at_exact_work_and_persistent_limits(){
    clean();assert(compile::working_bound()==66630144);
    var u8 mode=0;while(mode<4){recovery(mode);clean();mode+=1;}
}

@test fn void work_one_less_and_invalid_preconditions_deny_before_any_allocation(){
    clean();var u8 mode=0;while(mode<4){
        var retention::Plan r=retained();let retention::Plan original=r;
        var memory::Plan m=budget(compile::working_bound()-1,baseline()+fixed()+1);
        let memory::Observation initial=memory::observe(ref m);
        let Stats s=attempt(mode,source(mode,false),ref mut r,ref mut m,0);
        denied(ref s,21);no_allocation(ref s);
        same_memory(ref m,ref initial);same_retention(ref r,ref original);
        // Reuse the untouched retention plan with an exact working ceiling.
        var memory::Plan exact=budget(compile::working_bound(),baseline()+fixed()+1);
        let Stats good=attempt(mode,source(mode,false),ref mut r,ref mut exact,-1);
        assert(good.success);admitted(ref r);terminal(ref exact,fixed()+1,fixed()+1);
        // Invalid trusted state is rejected before reserve_work as kind 5.
        var u8 bad=0;while(bad<4){
            var retention::Plan invalid=retained();
            var memory::Plan idle=budget(compile::working_bound(),baseline()+fixed()+1);
            if(bad==0){invalid.fixed=0;}
            if(bad==1){invalid.admitted=true;invalid.bytes=fixed();}
            if(bad==2){invalid.limit=invalid.fixed-1;}
            if(bad==3){idle.baseline=idle.combined_limit+1;}
            let retention::Plan saved=invalid;
            let memory::Observation before=memory::observe(ref idle);
            let Stats rejected=attempt(mode,source(mode,false),ref mut invalid,ref mut idle,0);
            denied(ref rejected,5);no_allocation(ref rejected);
            same_retention(ref invalid,ref saved);same_memory(ref idle,ref before);bad+=1;
        }
        // Work fits, but even fixed retention cannot fit the narrowed limit.
        var retention::Plan too_large=retained();
        var memory::Plan narrowed=budget(compile::working_bound(),baseline()+fixed()-1);
        let Stats early=attempt(mode,source(mode,false),ref mut too_large,ref mut narrowed,0);
        denied(ref early,21);no_allocation(ref early);
        same_retention(ref too_large,ref original);
        terminal(ref narrowed,0,compile::working_bound());
        clean();mode+=1;
    }
}

// Calibrate exactly the compiler scratch prefix: quota occurs after lowering
// and before image copy or Stored reserve. No allocation ordinal is hardcoded.
fn usize scratch_attempts(u8 mode){
    var retention::Plan r=retained();let retention::Plan original=r;
    var memory::Plan m=budget(compile::working_bound(),baseline()+fixed());
    let Stats s=attempt(mode,source(mode,false),ref mut r,ref mut m,-1);
    denied(ref s,21);assert(s.attempts>=2);scratch_peak(ref s);
    same_retention(ref r,ref original);terminal(ref m,0,compile::working_bound());
    return s.attempts;
}

@test fn void combined_persistent_one_less_precedes_image_and_stored_allocation(){
    clean();var u8 mode=0;while(mode<4){
        let usize scratch=scratch_attempts(mode);
        var retention::Plan r=retained();let retention::Plan original=r;
        var memory::Plan short=budget(compile::working_bound(),baseline()+fixed());
        // Arm failure precisely where a forbidden image allocation would occur.
        let Stats denied_image=attempt(mode,source(mode,false),ref mut r,ref mut short,fault_at(scratch));
        denied(ref denied_image,21);assert(denied_image.attempts==scratch);
        same_retention(ref r,ref original);terminal(ref short,0,compile::working_bound());
        var memory::Plan exact=budget(compile::working_bound(),baseline()+fixed()+1);
        let Stats image_oom=attempt(mode,source(mode,false),ref mut r,ref mut exact,fault_at(scratch));
        denied(ref image_oom,15);assert(image_oom.attempts==scratch+1);
        admitted(ref r);terminal(ref exact,0,fixed()+1);
        recovery(mode);clean();mode+=1;
    }
}

@test fn void malformed_bodies_abort_work_without_admission_and_allow_fresh_plan_recovery(){
    clean();var u8 mode=0;while(mode<4){
        var retention::Plan r=retained();let retention::Plan original=r;
        var memory::Plan m=budget(compile::working_bound(),baseline()+fixed()+1);
        let Stats bad=attempt(mode,source(mode,true),ref mut r,ref mut m,-1);
        denied(ref bad,3);assert(bad.attempts>=2);scratch_peak(ref bad);
        same_retention(ref r,ref original);terminal(ref m,0,compile::working_bound());
        var memory::Plan retry=budget(compile::working_bound(),baseline()+fixed()+1);
        let Stats good=attempt(mode,source(mode,false),ref mut r,ref mut retry,-1);
        assert(good.success);admitted(ref r);terminal(ref retry,fixed()+1,fixed()+1);
        clean();mode+=1;
    }
}

@test fn void first_scratch_image_and_stored_oom_release_every_owner_and_recover(){
    clean();var u8 mode=0;while(mode<4){
        let usize scratch=scratch_attempts(mode);
        var usize stage=0;while(stage<3){
            var retention::Plan r=retained();let retention::Plan original=r;
            var memory::Plan m=budget(compile::working_bound(),baseline()+fixed()+1);
            let usize ordinal=if(stage==0){0}else{if(stage==1){scratch}else{scratch+1}};
            let Stats failed=attempt(mode,source(mode,false),ref mut r,ref mut m,fault_at(ordinal));
            denied(ref failed,15);assert(failed.attempts==ordinal+1);
            if(stage==0){same_retention(ref r,ref original);terminal(ref m,0,compile::working_bound());}
            else{admitted(ref r);terminal(ref m,0,fixed()+1);}
            recovery(mode);clean();stage+=1;
        }
        var retention::Plan r=retained();
        var memory::Plan m=budget(compile::working_bound(),baseline()+fixed()+1);
        let Stats success=attempt(mode,source(mode,false),ref mut r,ref mut m,-1);
        // The calibrated prefix is followed by exactly image and Stored.
        assert(success.success && success.attempts==scratch+2);
        admitted(ref r);terminal(ref m,fixed()+1,fixed()+1);
        clean();mode+=1;
    }
}

fn void append(ref mut bytes::Buffer text,ref u8[] fragment){assert(bytes::append(text,fragment).is_ok);}
fn void wrapper_depth(usize depth,bool pass){
    var bytes::Buffer text=bytes::empty();
    append(ref mut text,b"module app;fn i32 id(i32 x,i32[1] a){return x;}pub fn i32 chosen(){let i32[1] a=[0;1];let ref u8[] marker=b\"*\";return ");
    var usize i=0;while(i<depth){append(ref mut text,b"id(");i+=1;}
    append(ref mut text,b"42");i=0;while(i<depth){append(ref mut text,b",a)");i+=1;}
    append(ref mut text,b";}");
    var retention::Plan r=retained();let retention::Plan original=r;
    var memory::Plan m=budget(compile::working_bound(),baseline()+fixed()+1);
    let Stats s=attempt(0,bytes::view(ref text),ref mut r,ref mut m,-1);
    if(pass){assert(s.success);admitted(ref r);terminal(ref m,fixed()+1,fixed()+1);}
    else{denied(ref s,4);same_retention(ref r,ref original);terminal(ref m,0,compile::working_bound());}
}
@test fn void wrapper_keeps_owned_second_formal_depth32_and_rejects_depth33(){
    clean();wrapper_depth(32,true);clean();wrapper_depth(33,false);clean();
}
