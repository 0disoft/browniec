module tests::m2::buffer_storage;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;

fn growth::Limits limits(usize object,usize instance,usize engine) {
    return growth::Limits{.object=object,.instance=instance,.engine=engine};
}
fn bytes::Buffer replacement(ref bytes::Buffer old,usize required,growth::Limits cap,
    ref mut growth::Ledger ledger,usize expected) {
    let bytes::Buffer next=switch(storage::prepare_growth(old,required,cap,ledger)) {
        case .ok(value):{value}case .err(_):{assert(false);bytes::empty()}
    };
    assert(bytes::capacity(ref next)==expected);
    return next;
}
fn void committed(ref bytes::Buffer b,ref mut growth::Ledger l) {
    switch(growth::commit(bytes::capacity(b),l)) {
        case .ok(_):{}case .err(_):{assert(false);}
    };
}
fn u8 code(storage::Error e) {
    return switch(e){case .State:{1}case .Overflow:{2}case .Quota:{3}
        case .NoGrowth:{4}case .Allocation:{5}case .Provider:{6}};
}
fn void error(Result<bytes::Buffer,storage::Error> r,u8 expected) {
    assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});
}
fn bool same(ref growth::Ledger a,ref growth::Ledger b) {
    return a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used;
}
fn void seed(ref mut bytes::Buffer b) {
    switch(bytes::append(b,b"keep")){case .ok(n):{assert(n==4);}case .err(_):{assert(false);}};
}
fn void kept(ref bytes::Buffer b,usize capacity) {
    assert(bytes::capacity(b)==capacity && bytes::len(b)==4);
    assert(bytes::equal(bytes::view(b),b"keep"));
}
@test
fn void empty_root_grows_and_commits_real_capacity() {
    var bytes::Buffer b=bytes::empty();var growth::Ledger l=growth::empty();
    b=replacement(ref b,1,limits(1024,2048,4096),ref mut l,64);committed(ref b,ref mut l);
    assert(bytes::len(ref b)==0 && bytes::capacity(ref b)==64);
    assert(l.used==128 && l.engine_used==128 && l.peak==192 && l.pending==0);
    seed(ref mut b);kept(ref b,64);
}
@test
fn void preferred_growth_copies_only_initialized_bytes() {
    var bytes::Buffer b=bytes::empty();var growth::Ledger l=growth::empty();
    b=replacement(ref b,256,limits(4096,8192,8192),ref mut l,256);committed(ref b,ref mut l);
    seed(ref mut b);l.engine_used+=32;l.engine_peak+=32;
    b=replacement(ref b,257,limits(4096,8192,8192),ref mut l,384);committed(ref b,ref mut l);
    kept(ref b,384);
    assert(l.used==448 && l.engine_used==480 && l.peak==768 && l.engine_peak==800 && l.pending==0);
    assert(l.old_capacity==0 && l.new_capacity==0 && l.before_used==0 && l.before_engine_used==0);
}
@test
fn void every_quota_dimension_can_choose_minimum_real_allocation() {
    var usize dimension=0;
    while(dimension<3) {
        var bytes::Buffer b=bytes::empty();var growth::Ledger l=growth::empty();
        b=replacement(ref b,256,limits(4096,8192,8192),ref mut l,256);committed(ref b,ref mut l);seed(ref mut b);
        let growth::Limits cap=if(dimension==0){limits(352,8192,8192)}else{
            if(dimension==1){limits(4096,704,8192)}else{limits(4096,8192,704)}};
        b=replacement(ref b,257,cap,ref mut l,320);committed(ref b,ref mut l);kept(ref b,320);
        assert(l.used==384 && l.engine_used==384 && l.peak==704 && l.pending==0);
        dimension+=1;
    }
}
@test
fn void quota_overflow_and_no_growth_leave_root_and_ledger_unchanged() {
    var bytes::Buffer b=bytes::empty();var growth::Ledger l=growth::empty();
    b=replacement(ref b,256,limits(4096,8192,8192),ref mut l,256);committed(ref b,ref mut l);seed(ref mut b);
    let growth::Ledger before=l;
    error(storage::prepare_growth(ref b,257,limits(4096,703,8192),ref mut l),3);
    kept(ref b,256);assert(same(ref l,ref before));
    error(storage::prepare_growth(ref b,18446744073709551615,limits(4096,8192,8192),ref mut l),2);
    kept(ref b,256);assert(same(ref l,ref before));
    error(storage::prepare_growth(ref b,256,limits(4096,8192,8192),ref mut l),4);
    kept(ref b,256);assert(same(ref l,ref before));
}
@test
fn void invalid_and_pending_ledgers_are_rejected_before_root_replacement() {
    var bytes::Buffer b=bytes::empty();var growth::Ledger l=growth::empty();
    b=replacement(ref b,256,limits(4096,8192,8192),ref mut l,256);committed(ref b,ref mut l);seed(ref mut b);
    l.used=319;let growth::Ledger bad=l;
    error(storage::prepare_growth(ref b,257,limits(4096,8192,8192),ref mut l),1);
    kept(ref b,256);assert(same(ref l,ref bad));
    l=growth::empty();l.used=320;l.engine_used=320;l.peak=384;l.engine_peak=384;
    switch(growth::begin(256,257,limits(4096,8192,8192),ref mut l)) {
        case .ok(_):{}case .err(_):{assert(false);}
    };
    let growth::Ledger pending=l;
    error(storage::prepare_growth(ref b,257,limits(4096,8192,8192),ref mut l),1);
    kept(ref b,256);assert(same(ref l,ref pending));
}
@test
fn void repeated_growth_and_native_move_keep_one_owning_root() {
    var bytes::Buffer b=bytes::empty();var growth::Ledger l=growth::empty();
    b=replacement(ref b,64,limits(4096,8192,8192),ref mut l,64);committed(ref b,ref mut l);seed(ref mut b);
    var usize i=0;
    while(i<6) {
        let usize before=bytes::capacity(ref b);
        b=switch(storage::prepare_growth(ref b,before+1,limits(4096,8192,8192),ref mut l)) {
            case .ok(value):{value}case .err(_):{assert(false);bytes::empty()}
        };
        committed(ref b,ref mut l);let usize after=bytes::capacity(ref b);
        assert(after>before && after%64==0);kept(ref b,after);
        assert(l.used==after+64 && l.engine_used==l.used && l.pending==0);i+=1;
    }
    let usize capacity=bytes::capacity(ref b);
    let bytes::Buffer moved=b;kept(ref moved,capacity);
}

@test
fn void abandoned_copy_drops_before_cancellation_and_old_root_survives() {
    var bytes::Buffer b=bytes::empty();var growth::Ledger l=growth::empty();
    b=replacement(ref b,256,limits(4096,8192,8192),ref mut l,256);committed(ref b,ref mut l);seed(ref mut b);
    {
        let bytes::Buffer abandoned=replacement(ref b,257,limits(4096,8192,8192),ref mut l,384);
        kept(ref abandoned,384);kept(ref b,256);
        assert(l.used==768 && l.engine_used==768 && l.pending==448);
        let growth::Ledger pending=l;
        error(storage::prepare_growth(ref b,300,limits(4096,8192,8192),ref mut l),1);
        assert(same(ref l,ref pending));
    }
    switch(growth::cancel(ref mut l)){case .ok(n):{assert(n==320);}case .err(_):{assert(false);}};
    kept(ref b,256);assert(l.used==320 && l.engine_used==320 && l.peak==768 && l.pending==0);
    b=replacement(ref b,257,limits(352,704,704),ref mut l,320);committed(ref b,ref mut l);kept(ref b,320);
    assert(l.used==384 && l.peak==768);
}
