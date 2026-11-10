module tests::m2::output_record_range_work;

import output_record_range_work as work;
import struct_range as raw;
import struct_layout as layouts;
import metadata_budget as budget;
import errors as errors;
import std::vec as vec;

struct Outcome { bool ok; usize value; u8 kind; usize dispatches; }

// Large state and plan values stay in SDK-owned single-slot banks so the native
// test-driver frame remains below the default stack commit.
fn vec::Vec<work::State> work_bank(){
    var vec::Vec<work::State> bank=vec::empty<work::State>();
    assert(vec::reserve<work::State>(ref mut bank,1).is_ok);
    assert(vec::push<work::State>(ref mut bank,work::empty()).is_ok);
    return bank;
}
fn vec::Vec<layouts::Plan> plan_bank(layouts::Catalog c){
    let layouts::Plan plan=switch(layouts::plan(ref c,18446744073709551615)){
        case .ok(v):{v}case .err(_):{assert(false);return vec::empty<layouts::Plan>();}
    };
    var vec::Vec<layouts::Plan> bank=vec::empty<layouts::Plan>();
    assert(vec::reserve<layouts::Plan>(ref mut bank,1).is_ok);
    assert(vec::push<layouts::Plan>(ref mut bank,plan).is_ok);
    return bank;
}
fn usize reset(ref mut budget::State meter){
    return switch(budget::reset(meter,0)){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn bool pre_admit(ref mut budget::State meter){
    return switch(budget::admit(meter,1,0)){case .ok(v):{v}case .err(_):{assert(false);false}};
}
fn void same_state(ref work::State a,ref work::State b){
    assert(a.root==b.root && a.nominal==b.nominal && a.ordinal==b.ordinal &&
        a.leaf==b.leaf && a.count==b.count && a.visits==b.visits &&
        a.output==b.output && a.mode==b.mode && a.prepared==b.prepared &&
        a.active==b.active && a.done==b.done && a.depth==b.depth);
    var usize i=0;
    while(i<16){assert(a.records[i]==b.records[i] && a.fields[i]==b.fields[i] &&
        a.bases[i]==b.bases[i]);i+=1;}
}

fn Outcome continue_drive(ref mut work::State w,ref layouts::Catalog c,ref layouts::Plan plan,
    ref mut budget::State meter,bool defers){
    var vec::Vec<work::State> saved_storage=work_bank();
    let ref mut work::State saved=vec::at_mut<work::State>(ref mut saved_storage,0);
    var usize dispatches=0;
    while(dispatches<600){
        let usize ready=reset(meter);assert(ready==4096 && meter.last==0);
        if(defers){
            *saved=*w;let usize total=meter.total;let usize stages=meter.stages;
            assert(pre_admit(meter));
            switch(work::advance(w,c,plan,meter)){
                case .ok(done):{assert(!done);}
                case .err(_):{assert(false);return Outcome{.ok=false,.value=0,.kind=98,.dispatches=dispatches};}
            };
            same_state(w,saved);assert(meter.total==total+1 && meter.stages==stages+1);
            let usize fresh=reset(meter);assert(fresh==4096 && meter.last==0);
        }
        let usize total=meter.total;let usize stages=meter.stages;
        let Result<bool,errors::Error> progressed=work::advance(w,c,plan,meter);
        dispatches+=1;
        assert(meter.total==total+4096 && meter.stages==stages+1 && meter.last==4096);
        switch(progressed){
            case .ok(done):{
                if(done){assert(w.done && !w.active);
                    return Outcome{.ok=true,.value=w.output,.kind=0,.dispatches=dispatches};}
            }
            case .err(e):{assert(!w.active && !w.done);
                return Outcome{.ok=false,.value=0,.kind=e.kind,.dispatches=dispatches};}
        };
        assert(w.active && !w.done);
    }
    assert(false);return Outcome{.ok=false,.value=0,.kind=97,.dispatches=dispatches};
}

fn Outcome drive_offset(ref mut work::State w,ref layouts::Catalog c,ref layouts::Plan plan,
    usize root,usize nominal,usize ordinal,bool defers){
    switch(work::begin_offset(w,root,nominal,ordinal)){
        case .ok(_):{}case .err(_):{assert(false);
            return Outcome{.ok=false,.value=0,.kind=99,.dispatches=0};}
    };
    var budget::State meter=budget::empty();
    return continue_drive(w,c,plan,ref mut meter,defers);
}
fn Outcome drive_leaves(ref mut work::State w,ref layouts::Catalog c,ref layouts::Plan plan,
    usize nominal,bool defers){
    switch(work::begin_leaves(w,nominal)){
        case .ok(_):{}case .err(_):{assert(false);
            return Outcome{.ok=false,.value=0,.kind=99,.dispatches=0};}
    };
    var budget::State meter=budget::empty();
    return continue_drive(w,c,plan,ref mut meter,defers);
}

fn void same_offset(ref layouts::Catalog c,ref layouts::Plan plan,usize root,usize nominal,
    usize ordinal,bool defers){
    let Result<usize,errors::Error> expected=raw::offset_prepared(c,plan,root,nominal,ordinal);
    var vec::Vec<work::State> storage=work_bank();
    let ref mut work::State w=vec::at_mut<work::State>(ref mut storage,0);
    let Outcome actual=drive_offset(w,c,plan,root,nominal,ordinal,defers);
    switch(expected){
        case .ok(v):{assert(actual.ok);assert(actual.kind==0);assert(actual.value==v);}
        case .err(_):{assert(!actual.ok);assert(actual.kind==5);}
    };
}
fn void same_leaves(ref layouts::Catalog c,ref layouts::Plan plan,usize nominal,bool defers){
    let Result<usize,errors::Error> expected=raw::leaves(c,nominal);
    var vec::Vec<work::State> storage=work_bank();
    let ref mut work::State w=vec::at_mut<work::State>(ref mut storage,0);
    let Outcome actual=drive_leaves(w,c,plan,nominal,defers);
    switch(expected){
        case .ok(v):{assert(actual.ok);assert(actual.kind==0);assert(actual.value==v);}
        case .err(_):{assert(!actual.ok);assert(actual.kind==5);}
    };
}

fn layouts::Catalog nested(){
    var layouts::Catalog c=layouts::empty();c.count=3;
    c.fields[0]=3;c.kinds[0]=1;c.types[0]=1;c.types[1]=9;c.types[2]=2;
    c.fields[1]=2;c.kinds[16]=1;c.types[16]=2;c.types[17]=12;
    c.fields[2]=2;c.types[32]=9;c.types[33]=9;
    return c;
}
fn layouts::Catalog chain(usize links){
    var layouts::Catalog c=layouts::empty();c.count=32;var usize i=0;var u8 child=1;
    while(i<32){c.fields[i]=1;c.types[i*16]=10;i+=1;}
    i=0;while(i<links && i<31){c.kinds[i*16]=1;c.types[i*16]=child;i+=1;child+=1;}
    return c;
}
fn layouts::Catalog over_limit(){
    var layouts::Catalog c=layouts::empty();c.count=2;
    c.fields[0]=16;var usize i=0;while(i<16){c.types[i]=9;i+=1;}
    c.fields[1]=2;c.kinds[16]=1;c.kinds[17]=1;c.types[16]=0;c.types[17]=0;
    return c;
}
fn layouts::Catalog shared_expansion(){
    var layouts::Catalog c=layouts::empty();c.count=2;
    c.fields[0]=16;var usize i=0;
    while(i<16){c.kinds[i]=1;c.types[i]=1;i+=1;}
    c.fields[1]=1;c.types[16]=9;
    return c;
}

@test fn void nested_offsets_and_leaf_counts_match_prepared_raw_oracles(){
    let layouts::Catalog c=nested();let vec::Vec<layouts::Plan> plans=plan_bank(c);
    let ref layouts::Plan plan=vec::at<layouts::Plan>(ref plans,0);
    same_offset(ref c,plan,0,0,0,true);same_offset(ref c,plan,0,2,0,true);
    same_offset(ref c,plan,0,1,0,true);same_offset(ref c,plan,0,2,1,false);
    same_offset(ref c,plan,0,1,1,false);same_offset(ref c,plan,0,0,1,true);
    same_leaves(ref c,plan,0,true);same_leaves(ref c,plan,1,false);same_leaves(ref c,plan,2,true);
}

@test fn void two_offset_callers_reuse_one_state_and_preserve_bounds(){
    let layouts::Catalog c=nested();let vec::Vec<layouts::Plan> plans=plan_bank(c);
    let ref layouts::Plan plan=vec::at<layouts::Plan>(ref plans,0);
    var vec::Vec<work::State> storage=work_bank();
    let ref mut work::State w=vec::at_mut<work::State>(ref mut storage,0);
    let Outcome first=drive_offset(w,ref c,plan,0,1,0,true);
    let Outcome second=drive_offset(w,ref c,plan,0,2,0,true);
    assert(first.ok && second.ok);
    switch(raw::offset_prepared(ref c,plan,0,1,0)){
        case .ok(v):{assert(first.value==v);}case .err(_):{assert(false);}
    };
    switch(raw::offset_prepared(ref c,plan,0,2,0)){
        case .ok(v):{assert(second.value==v);}case .err(_):{assert(false);}
    };
    same_offset(ref c,plan,3,0,0,false);same_offset(ref c,plan,0,3,0,false);
    same_offset(ref c,plan,0,0,128,false);
}

@test fn void unrelated_oversized_plan_record_stays_allowed(){
    let layouts::Catalog c=over_limit();let vec::Vec<layouts::Plan> plans=plan_bank(c);
    let ref layouts::Plan plan=vec::at<layouts::Plan>(ref plans,0);
    assert(plan.bytes[1]>128);
    same_leaves(ref c,plan,0,true);same_offset(ref c,plan,0,0,0,false);
    same_leaves(ref c,plan,1,false);same_offset(ref c,plan,1,0,0,true);
}

@test fn void depth_sixteen_completes_and_shared_graph_uses_fresh_visit_chunks(){
    let layouts::Catalog deep=chain(15);let vec::Vec<layouts::Plan> deep_plans=plan_bank(deep);
    let ref layouts::Plan deep_plan=vec::at<layouts::Plan>(ref deep_plans,0);
    same_leaves(ref deep,deep_plan,0,true);same_offset(ref deep,deep_plan,0,15,0,true);

    let layouts::Catalog graph=shared_expansion();
    let vec::Vec<layouts::Plan> graph_plans=plan_bank(graph);
    let ref layouts::Plan graph_plan=vec::at<layouts::Plan>(ref graph_plans,0);
    same_offset(ref graph,graph_plan,0,1,0,true);same_leaves(ref graph,graph_plan,0,true);
}

@test fn void partial_room_and_invalid_preflight_defer_without_state_or_credit_changes(){
    let layouts::Catalog c=nested();let vec::Vec<layouts::Plan> plans=plan_bank(c);
    let ref layouts::Plan plan=vec::at<layouts::Plan>(ref plans,0);
    var vec::Vec<work::State> storage=work_bank();
    let ref mut work::State w=vec::at_mut<work::State>(ref mut storage,0);
    switch(work::begin_offset(w,3,0,0)){case .ok(_):{}case .err(_):{assert(false);return;}};
    var budget::State meter=budget::empty();assert(budget::reset(ref mut meter,0).is_ok);
    var vec::Vec<work::State> saved_storage=work_bank();
    let ref mut work::State saved=vec::at_mut<work::State>(ref mut saved_storage,0);
    *saved=*w;assert(pre_admit(ref mut meter));
    switch(work::advance(w,ref c,plan,ref mut meter)){
        case .ok(done):{assert(!done);}case .err(_):{assert(false);return;}
    };
    same_state(w,saved);assert(meter.last==1 && w.active);
    assert(budget::reset(ref mut meter,0).is_ok);
    switch(work::advance(w,ref c,plan,ref mut meter)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && !w.active);}
    };
    assert(meter.last==4096);
}
