module tests::m2::slice_handoff_work;
import slice_handoff_work as work;
import slice_handoff as handoff;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;

struct Fixture { slices::Pool pool; owners::Table table; slices::Ticket[8] inputs; }
fn u8 code(owners::Error e) { return switch(e) {
    case .Token:{1} case .Owners:{2} case .State:{3} case .Type:{4} case .Length:{5}
    case .Metadata:{6} case .Overflow:{7} case .Quota:{8} case .Bounds:{9} case .Alignment:{10} case .Value:{11}
}; }
fn Fixture fixture() {
    var u8[16] bytes=[0;16];var owners::Table table=owners::empty(16);var slices::Pool pool=slices::empty();
    var slices::Ticket[8] inputs=[slices::Ticket{.slot=16,.generation=0};8];
    let layouts::Array shape=switch(layouts::scalar(10,1)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};
    var usize i=0;while(i<8) {
        let owners::Token root=switch(owners::create(ref shape,0,ref mut bytes,ref mut table)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
        inputs[i]=switch(slices::open_exclusive(ref mut pool,ref mut table,root,0,1,16)){case .ok(v):{v}case .err(_):{assert(false);inputs[i]}};
        i+=1;
    }
    return Fixture{.pool=pool,.table=table,.inputs=inputs};
}
fn void same_view(owners::View a,owners::View b) { assert(a.root.slot==b.root.slot && a.root.generation==b.root.generation && a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end); }
fn void same_pool(ref slices::Pool a,ref slices::Pool b) {
    var usize i=0;while(i<16){let slices::Slot x=a.slots[i];let slices::Slot y=b.slots[i];
        assert(x.generation==y.generation && x.live==y.live && x.exclusive==y.exclusive && x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation);
        same_view(x.view,y.view);i+=1;
    }
}
fn void same_batch(ref handoff::Batch a,ref handoff::Batch b) {
    assert(a.count==b.count && a.frame==b.frame);var usize i=0;while(i<8){
        assert(a.tickets[i].slot==b.tickets[i].slot && a.tickets[i].generation==b.tickets[i].generation && a.leases[i].generation==b.leases[i].generation);
        same_view(a.leases[i].view,b.leases[i].view);i+=1;
    }
}
fn void same_arguments(ref slices::Arguments a,ref slices::Arguments b) {
    assert(a.count==b.count);var usize i=0;while(i<8){assert(a.tickets[i].slot==b.tickets[i].slot && a.tickets[i].generation==b.tickets[i].generation);i+=1;}
}
// Return the oracle-compatible error code, or zero on completion.
fn u8 finish(ref mut work::State w,ref slices::Pool original,ref owners::Table table,usize quantum) {
    var usize previous=0;var usize attempts=0;while(attempts<32){
        attempts+=1;
        let Result<bool,owners::Error> result=work::advance(w,original,table,16,quantum);
        assert(w.last>0 && w.last<=quantum && w.total==previous+w.last);previous=w.total;
        if(w.phase==1){same_pool(ref w.planned,original);}
        let bool done=switch(result){case .ok(v):{v}case .err(e):{return code(e);}};
        if(done){assert(w.done && !w.active);return 0;}
    }assert(false);return 11;
}
fn u8 begin_error(Result<handoff::Batch,owners::Error> r) {return switch(r){case .ok(_):{0}case .err(e):{code(e)}};}
fn u8 restore_error(Result<slices::Arguments,owners::Error> r) {return switch(r){case .ok(_):{0}case .err(e):{code(e)}};}
fn u8 start_error(Result<usize,owners::Error> r) {return switch(r){case .ok(_):{0}case .err(e):{code(e)}};}

@test
fn void eight_writers_match_independent_enter_and_restore_at_each_quantum() {
    var usize quantum=1;while(quantum<=2){
        let Fixture f=fixture();var slices::Pool expected_pool=f.pool;
        var handoff::Batch expected=switch(handoff::begin(ref mut expected_pool,ref f.inputs,ref f.table,16,7)){case .ok(v):{v}case .err(_):{assert(false);handoff::empty()}};
        var work::State w=work::empty();assert(work::start_enter(ref mut w,ref f.pool,ref f.inputs,7).is_ok);
        assert(finish(ref mut w,ref f.pool,ref f.table,quantum)==0 && w.total==16);
        same_pool(ref w.planned,ref expected_pool);same_batch(ref w.batch,ref expected);
        let slices::Pool entered=w.planned;let handoff::Batch receipt=w.batch;
        let slices::Arguments oracle=switch(handoff::restore(ref mut expected_pool,ref mut expected,ref receipt.tickets,ref f.table,16)){case .ok(v):{v}case .err(_):{assert(false);slices::empty_arguments()}};
        w=work::empty();assert(work::start_restore(ref mut w,ref entered,ref receipt,ref receipt.tickets).is_ok);
        assert(finish(ref mut w,ref entered,ref f.table,quantum)==0 && w.total==16);
        same_pool(ref w.planned,ref expected_pool);same_batch(ref w.batch,ref expected);same_arguments(ref w.returned,ref oracle);
        quantum+=1;
    }
}

@test
fn void late_bad_sources_and_receipts_match_oracle_without_live_mutation() {
    let Fixture f=fixture();let slices::Pool saved=f.pool;var slices::Ticket[8] bad=f.inputs;
    var usize scenario=0;while(scenario<3){
        bad=f.inputs;
        if(scenario==0){bad[7].generation+=1;}else if(scenario==1){bad[7]=bad[0];bad[7].generation+=1;}else{bad[7]=bad[0];}
        var slices::Pool oracle_pool=f.pool;let u8 expected=begin_error(handoff::begin(ref mut oracle_pool,ref bad,ref f.table,16,0));
        var work::State w=work::empty();assert(work::start_enter(ref mut w,ref f.pool,ref bad,0).is_ok);
        assert(expected!=0 && finish(ref mut w,ref f.pool,ref f.table,2)==expected);same_pool(ref w.planned,ref f.pool);same_pool(ref oracle_pool,ref saved);scenario+=1;
    }
    var slices::Pool entered=f.pool;let handoff::Batch receipt=switch(handoff::begin(ref mut entered,ref f.inputs,ref f.table,16,0)){case .ok(v):{v}case .err(_):{assert(false);handoff::empty()}};
    scenario=0;while(scenario<3){
        var handoff::Batch broken=receipt;var slices::Ticket[8] current=receipt.tickets;
        if(scenario==0){current[7].generation+=1;}else if(scenario==1){broken.leases[7].generation+=1;}else{broken.leases[7].view.start=1;}
        var slices::Pool oracle_pool=entered;var handoff::Batch oracle_batch=broken;
        let u8 expected=restore_error(handoff::restore(ref mut oracle_pool,ref mut oracle_batch,ref current,ref f.table,16));
        var work::State w=work::empty();assert(work::start_restore(ref mut w,ref entered,ref broken,ref current).is_ok);
        assert(expected!=0 && finish(ref mut w,ref entered,ref f.table,2)==expected);same_pool(ref w.planned,ref entered);same_pool(ref oracle_pool,ref entered);same_batch(ref oracle_batch,ref broken);scenario+=1;
    }
    same_pool(ref f.pool,ref saved);
}

@test
fn void unused_tail_zero_count_headers_reserve_and_action_limits() {
    let Fixture f=fixture();var slices::Pool original=f.pool;var owners::Table invalid=f.table;
    // Empty operations deliberately do not authenticate either metadata object.
    original.slots[0].exclusive=true;original.slots[0].live=false;invalid.depth=17;
    let slices::Ticket[1] none=[slices::Ticket{.slot=16,.generation=0}];var work::State w=work::empty();
    assert(work::start_enter(ref mut w,ref original,ref none[..0],0).is_ok);
    assert(finish(ref mut w,ref original,ref invalid,1)==0 && w.total==1);
    var handoff::Batch empty=handoff::empty();w=work::empty();assert(work::start_restore(ref mut w,ref original,ref empty,ref none[..0]).is_ok);
    assert(finish(ref mut w,ref original,ref invalid,2)==0 && w.total==8);
    empty.leases[7].view.root.slot=0;var slices::Pool oracle_pool=original;var handoff::Batch oracle_batch=empty;
    let u8 expected=restore_error(handoff::restore(ref mut oracle_pool,ref mut oracle_batch,ref none[..0],ref invalid,16));
    w=work::empty();assert(work::start_restore(ref mut w,ref original,ref empty,ref none[..0]).is_ok);
    assert(expected!=0 && finish(ref mut w,ref original,ref invalid,2)==expected && w.total==8);
    let slices::Ticket[9] excess=[none[0];9];w=work::empty();assert(start_error(work::start_enter(ref mut w,ref f.pool,ref excess,31))==5);
    empty.count=9;empty.frame=31;assert(start_error(work::start_restore(ref mut w,ref f.pool,ref empty,ref none[..0]))==5);
    w=work::empty();assert(work::start_enter(ref mut w,ref f.pool,ref f.inputs,0).is_ok);
    assert(!work::advance(ref mut w,ref f.pool,ref f.table,16,0).is_ok && !work::advance(ref mut w,ref f.pool,ref f.table,16,3).is_ok && !work::advance(ref mut w,ref f.pool,ref f.table,16,4).is_ok && w.total==0);
    var slices::Pool near=f.pool;var slices::Ticket[8] sources=f.inputs;
    near.slots[sources[7].slot].generation=18446744073709551614;sources[7].generation=18446744073709551614;
    var slices::Pool near_oracle=near;let u8 reserve=begin_error(handoff::begin(ref mut near_oracle,ref sources,ref f.table,16,0));
    w=work::empty();assert(work::start_enter(ref mut w,ref near,ref sources,0).is_ok);
    assert(reserve!=0 && finish(ref mut w,ref near,ref f.table,2)==reserve);same_pool(ref w.planned,ref near);
}
