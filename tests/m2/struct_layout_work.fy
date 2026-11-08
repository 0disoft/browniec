module tests::m2::struct_layout_work;
import struct_layout_work as work;
import struct_layout as records;
import metadata_budget as budget;
import std::vec as vec;

struct Outcome { u8 error; usize dispatches; }
fn u8 error_code(records::Error e){return switch(e){
    case .Limit:{1}case .Fields:{2}case .Type:{3}case .Metadata:{4}
    case .Cycle:{5}case .Depth:{6}case .Overflow:{7}case .Quota:{8}
};}
// Constructor/oracle return slots live in separate short-lived setup frames;
// both large persistent builders and reference Plans remain in SDK storage.
fn vec::Vec<work::State> work_bank(){
    var vec::Vec<work::State> bank=vec::empty<work::State>();assert(vec::reserve<work::State>(ref mut bank,1).is_ok);
    assert(vec::push<work::State>(ref mut bank,work::empty()).is_ok);return bank;
}
fn Result<vec::Vec<records::Plan>,records::Error> oracle_bank(ref records::Catalog c,usize limit){
    let records::Plan expected=records::plan(c,limit)?;var vec::Vec<records::Plan> bank=vec::empty<records::Plan>();
    assert(vec::reserve<records::Plan>(ref mut bank,1).is_ok);assert(vec::push<records::Plan>(ref mut bank,expected).is_ok);return .ok(bank);
}
fn u8 oracle_error(ref records::Catalog c,usize limit){return switch(records::plan(c,limit)){case .ok(_):{0}case .err(e):{error_code(e)}};}
fn void same_plan(ref records::Plan a,ref records::Plan b){
    assert(a.count==b.count);var usize i=0;while(i<32){assert(a.bytes[i]==b.bytes[i] && a.alignments[i]==b.alignments[i] && a.depths[i]==b.depths[i]);i+=1;}
    i=0;while(i<512){assert(a.offsets[i]==b.offsets[i]);i+=1;}
}
fn void same_catalog(ref records::Catalog a,ref records::Catalog b){
    assert(a.count==b.count);var usize i=0;while(i<32){assert(a.fields[i]==b.fields[i]);i+=1;}
    i=0;while(i<512){assert(a.kinds[i]==b.kinds[i] && a.types[i]==b.types[i]);i+=1;}
}
fn void same_work(ref work::State a,ref work::State b){
    assert(a.root==b.root && a.depth==b.depth && a.checked==b.checked && a.limit==b.limit && a.phase==b.phase && a.active==b.active && a.done==b.done);
    same_plan(ref a.plan,ref b.plan);var usize i=0;while(i<32){assert(a.records[i]==b.records[i] && a.fields[i]==b.fields[i] && a.visiting[i]==b.visiting[i]);i+=1;}
}
fn usize reset(ref mut budget::State allowance){return switch(budget::reset(allowance,0)){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn bool pre_admit(ref mut budget::State allowance){return switch(budget::admit(allowance,1,0)){case .ok(v):{v}case .err(_):{assert(false);false}};}
fn Outcome drive(ref mut work::State w,ref records::Catalog c,usize limit,bool check_defer){
    switch(work::begin(w,limit)){case .ok(v):{assert(v==0);}case .err(_):{assert(false);return Outcome{.error=99,.dispatches=0};}};
    assert(w.active && !w.done && w.limit==limit);
    let records::Catalog original=*c;var budget::State allowance=budget::empty();
    var vec::Vec<work::State> saved_storage=work_bank();let ref mut work::State saved=vec::at_mut<work::State>(ref mut saved_storage,0);
    var usize dispatches=0;
    while(dispatches<512){
        let usize ready=reset(ref mut allowance);assert(ready==4096 && allowance.last==0);
        if(check_defer){
            *saved=*w;let usize total=allowance.total;let usize stages=allowance.stages;
            assert(pre_admit(ref mut allowance));
            let bool deferred=switch(work::advance(w,c,ref mut allowance)){case .ok(v):{v}case .err(_):{assert(false);false}};
            assert(!deferred && allowance.last==1 && allowance.total==total+1 && allowance.stages==stages+1);
            same_work(w,saved);same_catalog(c,ref original);
            // A separate outer dispatch resets last; the previous admission is
            // history only and cannot increase the next stage's 4096 allowance.
            let usize fresh=reset(ref mut allowance);assert(fresh==4096 && allowance.last==0 && allowance.total==total+1);
        }
        let usize total=allowance.total;let usize stages=allowance.stages;
        let Result<bool,records::Error> progressed=work::advance(w,c,ref mut allowance);
        var bool finished=false;var u8 failure=0;
        switch(progressed){case .ok(v):{finished=v;}case .err(e):{failure=error_code(e);}};
        dispatches+=1;assert(allowance.last==4096 && allowance.total==total+4096 && allowance.stages==stages+1);
        same_catalog(c,ref original);assert(w.limit==limit);
        if(failure!=0){assert(!w.active && !w.done);return Outcome{.error=failure,.dispatches=dispatches};}
        if(finished){assert(w.done && !w.active && dispatches>1);return Outcome{.error=0,.dispatches=dispatches};}
        assert(w.active && !w.done);
    }
    assert(false);return Outcome{.error=99,.dispatches=dispatches};
}
fn void successful(ref records::Catalog c,usize limit,bool check_defer){
    let vec::Vec<records::Plan> expected_storage=switch(oracle_bank(c,limit)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let ref records::Plan expected=vec::at<records::Plan>(ref expected_storage,0);
    var vec::Vec<work::State> storage=work_bank();let ref mut work::State w=vec::at_mut<work::State>(ref mut storage,0);
    let Outcome actual=drive(w,c,limit,check_defer);assert(actual.error==0);same_plan(expected,ref w.plan);
}
fn void rejected(ref records::Catalog c,usize limit,u8 expected){
    assert(oracle_error(c,limit)==expected);
    var vec::Vec<work::State> storage=work_bank();let ref mut work::State w=vec::at_mut<work::State>(ref mut storage,0);
    let Outcome actual=drive(w,c,limit,false);assert(actual.error==expected && !w.active && !w.done);
}
fn records::Catalog singles(usize count){var records::Catalog c=records::empty();c.count=count;
    var usize i=0;while(i<count && i<32){c.fields[i]=1;c.types[i*16]=10;i+=1;}return c;
}
// Same full-capacity fixture as struct_layout_order: two disjoint depth-16
// forward chains, all 512 fields occupied, optionally reverse every record ID.
fn records::Catalog dense(bool reversed){
    var records::Catalog c=records::empty();c.count=32;var usize record=0;
    while(record<32){let usize id=if(reversed){31-record}else{record};c.fields[id]=16;
        var usize field=0;while(field<16){c.types[id*16+field]=2;field+=1;}
        if(record%16!=15){c.kinds[id*16+15]=1;let usize target=if(reversed){30-record}else{record+1};
            var u8 child=0;while((child as usize)<target){child+=1;}c.types[id*16+15]=child;
        }record+=1;
    }return c;
}
fn records::Catalog shared(){
    var records::Catalog c=singles(4);c.fields[0]=3;c.kinds[0]=1;c.types[0]=1;c.kinds[1]=1;c.types[1]=1;c.types[2]=2;
    c.fields[1]=2;c.types[16]=9;c.kinds[17]=1;c.types[17]=2;
    c.fields[2]=2;c.types[32]=10;c.kinds[33]=1;c.types[33]=3;c.types[48]=1;return c;
}
fn records::Catalog chain(usize links){
    var records::Catalog c=singles(32);var usize i=0;var u8 child=1;
    while(i<links && i<31){c.kinds[i*16]=1;c.types[i*16]=child;i+=1;child+=1;}return c;
}
fn records::Catalog exponential(){
    var records::Catalog c=singles(16);var usize i=0;var u8 child=1;
    while(i<16){c.fields[i]=16;var usize field=0;
        while(field<16){c.kinds[i*16+field]=if(i==15){0}else{1};c.types[i*16+field]=if(i==15){9}else{child};field+=1;}
        i+=1;child+=1;
    }return c;
}

@test fn void complete_dense_catalogs_match_atomic_plan_in_both_dependency_orders(){
    let records::Catalog forward=dense(false);successful(ref forward,241,true);
    let records::Catalog reverse=dense(true);successful(ref reverse,241,true);
    rejected(ref forward,240,8);
}
@test fn void forward_shared_subgraphs_depth_boundary_and_empty_catalog_match(){
    let records::Catalog graph=shared();successful(ref graph,40,true);
    let records::Catalog boundary=chain(15);successful(ref boundary,1,false);
    let records::Catalog empty=records::empty();successful(ref empty,0,true);
}
@test fn void whole_catalog_validation_preserves_first_error_before_any_layout(){
    let u8[12] errors=[1,2,2,4,4,4,3,3,3,4,2,3];var usize mode=0;
    while(mode<12){var records::Catalog c=singles(1);var usize limit=18446744073709551615;
        if(mode==0){c.count=33;c.fields[0]=0;}
        else if(mode==1){c.fields[0]=0;}
        else if(mode==2){c.fields[0]=17;}
        else if(mode==3){c.types[511]=2;}
        else if(mode==4){c.kinds[511]=1;}
        else if(mode==5){c.fields[31]=1;}
        else if(mode==6){c.types[0]=3;}
        else if(mode==7){c.kinds[0]=2;c.types[0]=0;}
        else if(mode==8){c.kinds[0]=1;c.types[0]=1;}
        else if(mode==9){c.kinds[0]=1;c.types[0]=0;c.types[511]=2;}
        else if(mode==10){c.count=2;c.fields[1]=0;limit=0;}
        else{c.types[0]=3;c.fields[31]=1;}
        rejected(ref c,limit,errors[mode]);mode+=1;
    }
}
@test fn void self_disconnected_and_full_capacity_cycles_precede_depth_failures(){
    var records::Catalog self_cycle=singles(1);self_cycle.kinds[0]=1;self_cycle.types[0]=0;rejected(ref self_cycle,1024,5);
    var records::Catalog disconnected=singles(3);disconnected.kinds[16]=1;disconnected.types[16]=2;
    disconnected.kinds[32]=1;disconnected.types[32]=1;rejected(ref disconnected,1024,5);
    var records::Catalog full=chain(31);full.kinds[31*16]=1;full.types[31*16]=0;rejected(ref full,1024,5);
    full.kinds[31*16]=0;full.types[31*16]=10;rejected(ref full,1024,6);
    let records::Catalog deep=chain(16);rejected(ref deep,1,6);
}
@test fn void padding_quota_and_symbolic_overflow_keep_atomic_error_order(){
    var records::Catalog padding=singles(1);padding.fields[0]=3;padding.types[0]=10;padding.types[1]=9;padding.types[2]=2;
    rejected(ref padding,23,8);successful(ref padding,24,true);
    let records::Catalog graph=exponential();rejected(ref graph,18446744073709551615,7);rejected(ref graph,65536,8);
    let records::Catalog one=singles(1);rejected(ref one,0,8);
}
@test fn void builder_reuse_after_failure_and_done_rebuilds_canonical_plan(){
    var vec::Vec<work::State> storage=work_bank();let ref mut work::State w=vec::at_mut<work::State>(ref mut storage,0);
    let records::Catalog graph=exponential();let Outcome failed=drive(w,ref graph,65536,false);assert(failed.error==8);
    let records::Catalog next=shared();let Outcome completed=drive(w,ref next,40,true);assert(completed.error==0);
    let vec::Vec<records::Plan> expected_storage=switch(oracle_bank(ref next,40)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let ref records::Plan expected=vec::at<records::Plan>(ref expected_storage,0);same_plan(expected,ref w.plan);
    let records::Catalog empty=records::empty();let Outcome cleared=drive(w,ref empty,0,true);assert(cleared.error==0 && w.plan.count==0);
    var usize i=0;while(i<32){assert(w.plan.bytes[i]==0 && w.plan.alignments[i]==0 && w.plan.depths[i]==0);i+=1;}
    i=0;while(i<512){assert(w.plan.offsets[i]==0);i+=1;}
}
