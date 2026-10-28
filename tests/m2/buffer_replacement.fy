module tests::m2::buffer_replacement;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_replacement as tx;

fn growth::Limits limits(usize instance) {return growth::Limits{.object=4096,.instance=instance,.engine=8192};}
fn bytes::Buffer initial(ref mut growth::Ledger ledger) {
    var bytes::Buffer b=bytes::empty();
    b=switch(storage::prepare_growth(ref b,256,limits(8192),ledger)) {
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    switch(growth::commit(bytes::capacity(ref b),ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(ref mut b,b"keep")){case .ok(_):{}case .err(_):{assert(false);}};
    return b;
}
fn owners::Token token(Result<owners::Token,owners::Error> r) {
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn owners::Token committed(Result<owners::Token,tx::Error> r) {
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn bytes::Buffer prepared(Result<bytes::Buffer,tx::Error> r) {
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
}
fn u8 code(tx::Error e) {
    return switch(e){case .Token:{1}case .Owners:{2}case .State:{3}case .Overflow:{4}
        case .Quota:{5}case .NoGrowth:{6}case .Allocation:{7}case .Provider:{8}};
}
fn void failed(Result<bytes::Buffer,tx::Error> r,u8 expected) {
    assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});
}
fn void preserved(ref owners::Table table,owners::Token t,ref bytes::Buffer b) {
    assert(bytes::equal(bytes::view(b),b"keep"));
    assert(switch(owners::read(table,t,0,b)){case .ok(v):{v==107}case .err(_):{false}});
}
@test
fn void successful_commit_publishes_next_generation_and_final_charge() {
    var growth::Ledger l=growth::empty();var bytes::Buffer b=initial(ref mut l);
    var owners::Table table=owners::empty();let owners::Token old=token(owners::create(ref mut table,ref b));
    var tx::Plan plan=tx::empty();
    let bytes::Buffer next=prepared(tx::prepare(ref table,old,ref b,257,limits(8192),ref mut l,ref mut plan));
    preserved(ref table,old,ref b);assert(l.used==768 && plan.active && table.slots[old.slot].capacity==256);
    b=next;
    let owners::Token t=committed(tx::commit(ref mut table,ref b,ref mut l,ref mut plan));
    assert(t.slot==old.slot && t.generation==old.generation+1);preserved(ref table,t,ref b);
    assert(l.used==448 && l.engine_used==448 && l.peak==768 && l.pending==0 && !plan.active);
    let bytes::Buffer missing=bytes::empty();
    assert(switch(owners::read(ref table,old,0,ref missing)){case .ok(_):{false}case .err(e):{switch(e){case .Token:{true}case .Owners:{false}case .State:{false}case .Bounds:{false}}}});
    assert(switch(tx::commit(ref mut table,ref b,ref mut l,ref mut plan)){case .ok(_):{false}case .err(e):{code(e)==3}});
}
@test
fn void cancellation_keeps_token_and_allows_minimum_capacity_retry() {
    var growth::Ledger l=growth::empty();var bytes::Buffer b=initial(ref mut l);
    var owners::Table table=owners::empty();let owners::Token old=token(owners::create(ref mut table,ref b));
    var tx::Plan plan=tx::empty();
    {let bytes::Buffer abandoned=prepared(tx::prepare(ref table,old,ref b,257,limits(8192),ref mut l,ref mut plan));
        assert(bytes::capacity(ref abandoned)==384);preserved(ref table,old,ref b);}
    assert(switch(tx::cancel(ref table,ref mut l,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
    assert(l.pending==0 && l.peak==768 && !plan.active);preserved(ref table,old,ref b);
    b=prepared(tx::prepare(ref table,old,ref b,257,limits(704),ref mut l,ref mut plan));
    let owners::Token t=committed(tx::commit(ref mut table,ref b,ref mut l,ref mut plan));
    assert(bytes::capacity(ref b)==320 && l.used==384 && l.peak==768);preserved(ref table,t,ref b);
}
@test
fn void quota_overflow_and_no_growth_do_not_publish_a_plan() {
    var growth::Ledger l=growth::empty();let bytes::Buffer b=initial(ref mut l);
    var owners::Table table=owners::empty();let owners::Token t=token(owners::create(ref mut table,ref b));
    var tx::Plan plan=tx::empty();let growth::Ledger before=l;
    failed(tx::prepare(ref table,t,ref b,257,limits(703),ref mut l,ref mut plan),5);
    failed(tx::prepare(ref table,t,ref b,18446744073709551615,limits(8192),ref mut l,ref mut plan),4);
    failed(tx::prepare(ref table,t,ref b,256,limits(8192),ref mut l,ref mut plan),6);
    assert(!plan.active && l.used==before.used && l.peak==before.peak && l.pending==0);
    preserved(ref table,t,ref b);assert(table.slots[t.slot].generation==t.generation);
}
@test
fn void stale_identity_precedes_native_metadata_and_ledger_checks() {
    var growth::Ledger l=growth::empty();let bytes::Buffer b=initial(ref mut l);
    var owners::Table table=owners::empty();let owners::Token t=token(owners::create(ref mut table,ref b));
    switch(owners::release(ref mut table,t)){case .ok(_):{}case .err(_):{assert(false);}};
    let bytes::Buffer missing=bytes::empty();var tx::Plan plan=tx::empty();l.used=0;
    failed(tx::prepare(ref table,t,ref missing,257,limits(8192),ref mut l,ref mut plan),1);
    assert(l.used==0 && !plan.active && table.slots[t.slot].generation==t.generation+1);
}
@test
fn void exhausted_generation_fails_before_reservation() {
    var growth::Ledger l=growth::empty();let bytes::Buffer b=initial(ref mut l);
    var owners::Table table=owners::empty();let owners::Token t=token(owners::create(ref mut table,ref b));
    table.slots[t.slot].generation=18446744073709551615;
    let owners::Token last=owners::Token{.slot=t.slot,.generation=18446744073709551615};
    var tx::Plan plan=tx::empty();let usize peak=l.peak;
    failed(tx::prepare(ref table,last,ref b,257,limits(8192),ref mut l,ref mut plan),2);
    assert(l.used==320 && l.pending==0 && l.peak==peak && !plan.active);preserved(ref table,last,ref b);
}
@test
fn void wrong_published_capacity_and_replayed_cancellation_do_not_mutate_state() {
    var growth::Ledger l=growth::empty();let bytes::Buffer b=initial(ref mut l);
    var owners::Table table=owners::empty();let owners::Token t=token(owners::create(ref mut table,ref b));
    var tx::Plan plan=tx::empty();
    {let bytes::Buffer abandoned=prepared(tx::prepare(ref table,t,ref b,257,limits(8192),ref mut l,ref mut plan));
        assert(switch(tx::commit(ref mut table,ref b,ref mut l,ref mut plan)){case .ok(_):{false}case .err(e):{code(e)==3}});
        assert(l.used==768 && plan.active && table.slots[t.slot].capacity==256);}
    assert(switch(tx::cancel(ref table,ref mut l,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
    assert(switch(tx::cancel(ref table,ref mut l,ref mut plan)){case .ok(_):{false}case .err(e):{code(e)==3}});
    preserved(ref table,t,ref b);assert(l.used==320 && l.pending==0);
}
@test
fn void changed_ledger_or_unrelated_slot_blocks_completion_without_partial_updates() {
    var growth::Ledger l=growth::empty();let bytes::Buffer b=initial(ref mut l);
    var owners::Table table=owners::empty();let owners::Token t=token(owners::create(ref mut table,ref b));
    var tx::Plan plan=tx::empty();
    {let bytes::Buffer abandoned=prepared(tx::prepare(ref table,t,ref b,257,limits(8192),ref mut l,ref mut plan));
        l.pending-=1;
        assert(switch(tx::commit(ref mut table,ref abandoned,ref mut l,ref mut plan)){case .ok(_):{false}case .err(e):{code(e)==3}});
        assert(table.slots[t.slot].generation==t.generation && l.pending==447 && plan.active);l.pending+=1;
        table.slots[1].generation=2;
        assert(switch(tx::commit(ref mut table,ref abandoned,ref mut l,ref mut plan)){case .ok(_):{false}case .err(e):{code(e)==3}});}
    assert(switch(tx::cancel(ref table,ref mut l,ref mut plan)){case .ok(_):{false}case .err(e):{code(e)==3}});
    assert(l.used==768 && table.slots[1].generation==2 && plan.active);table.slots[1].generation=1;
    assert(switch(tx::cancel(ref table,ref mut l,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
    preserved(ref table,t,ref b);
}
@test
fn void full_table_growth_reuses_slot_and_active_plan_blocks_nested_prepare() {
    var growth::Ledger l=growth::empty();var bytes::Buffer b=initial(ref mut l);
    var owners::Table table=owners::empty();let owners::Token t=token(owners::create(ref mut table,ref b));
    // Descriptor-capacity fixture, not production root registration.
    var usize i=1;while(i<16) {let owners::Token filled=token(owners::create(ref mut table,ref b));i+=1;}
    var tx::Plan plan=tx::empty();
    let bytes::Buffer next=prepared(tx::prepare(ref table,t,ref b,257,limits(8192),ref mut l,ref mut plan));
    failed(tx::prepare(ref table,t,ref b,257,limits(8192),ref mut l,ref mut plan),3);
    assert(l.used==768 && plan.active);b=next;
    let owners::Token fresh=committed(tx::commit(ref mut table,ref b,ref mut l,ref mut plan));
    assert(fresh.slot==t.slot && table.slots[15].generation==1 && l.used==448);
    preserved(ref table,fresh,ref b);
}
