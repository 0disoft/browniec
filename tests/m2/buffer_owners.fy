module tests::m2::buffer_owners;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_storage as storage;
import buffer_growth as growth;

fn bytes::Buffer buffer(usize capacity) {
    var bytes::Buffer b=bytes::empty();var growth::Ledger l=growth::empty();
    b=switch(storage::prepare_growth(ref b,capacity,
        growth::Limits{.object=4096,.instance=8192,.engine=8192},ref mut l)) {
        case .ok(value):{value}case .err(_):{assert(false);bytes::empty()}
    };
    switch(growth::commit(bytes::capacity(ref b),ref mut l)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(ref mut b,b"keep")){case .ok(_):{}case .err(_):{assert(false);}};
    return b;
}
fn owners::Token token(Result<owners::Token,owners::Error> r) {
    return switch(r){case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn usize ok(Result<usize,owners::Error> r) {
    return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};
}
fn u8 code(owners::Error e) {
    return switch(e){case .Token:{1}case .Owners:{2}case .State:{3}case .Bounds:{4}};
}
fn void read_error(ref owners::Table table,owners::Token t,usize at,ref bytes::Buffer b,u8 expected) {
    assert(switch(owners::read(table,t,at,b)){case .ok(_):{false}case .err(e):{code(e)==expected}});
}
fn void write_error(ref owners::Table table,owners::Token t,usize at,ref mut bytes::Buffer b,u8 expected) {
    assert(switch(owners::write(table,t,at,88,b)){case .ok(_):{false}case .err(e):{code(e)==expected}});
}
@test
fn void initialized_byte_access_never_exposes_spare_capacity() {
    var bytes::Buffer b=buffer(64);var owners::Table table=owners::empty();
    let owners::Token t=token(owners::create(ref mut table,ref b));
    assert(switch(owners::read(ref table,t,0,ref b)){case .ok(n):{n==107}case .err(_):{false}});
    assert(ok(owners::write(ref table,t,3,88,ref mut b))==3);
    assert(bytes::equal(bytes::view(ref b),b"keeX"));
    read_error(ref table,t,4,ref b,4);read_error(ref table,t,18446744073709551615,ref b,4);
    write_error(ref table,t,4,ref mut b,4);assert(bytes::equal(bytes::view(ref b),b"keeX"));
}
@test
fn void released_descriptor_is_rejected_after_backing_scope_exits() {
    var owners::Table table=owners::empty();var owners::Token stale=owners::Token{.slot=16,.generation=0};
    {
        let bytes::Buffer live=buffer(64);stale=token(owners::create(ref mut table,ref live));
        assert(ok(owners::release(ref mut table,stale))==0);
    }
    var bytes::Buffer missing=bytes::empty();
    read_error(ref table,stale,0,ref missing,1);write_error(ref table,stale,0,ref mut missing,1);
    assert(switch(owners::release(ref mut table,stale)){case .ok(_):{false}case .err(e):{code(e)==1}});
}
@test
fn void slot_reuse_changes_generation_and_rejects_old_token() {
    let bytes::Buffer b=buffer(64);var owners::Table table=owners::empty();
    let owners::Token old=token(owners::create(ref mut table,ref b));
    assert(ok(owners::release(ref mut table,old))==0);
    let owners::Token next=token(owners::create(ref mut table,ref b));
    assert(next.slot==old.slot && next.generation==old.generation+1);
    read_error(ref table,old,0,ref b,1);
    assert(switch(owners::read(ref table,next,3,ref b)){case .ok(n):{n==112}case .err(_):{false}});
}
@test
fn void invalid_slot_zero_and_wrong_generation_precede_buffer_checks() {
    var bytes::Buffer missing=bytes::empty();var owners::Table table=owners::empty();
    let owners::Token[3] invalid=[owners::Token{.slot=16,.generation=1},
        owners::Token{.slot=0,.generation=0},owners::Token{.slot=0,.generation=2}];
    var usize i=0;while(i<3) {
        read_error(ref table,invalid[i],0,ref missing,1);
        write_error(ref table,invalid[i],0,ref mut missing,1);i+=1;
    }
}
@test
fn void mismatched_backing_metadata_requires_explicit_descriptor_replacement() {
    let bytes::Buffer b=buffer(64);var owners::Table table=owners::empty();
    let owners::Token t=token(owners::create(ref mut table,ref b));
    var bytes::Buffer larger=buffer(128);
    read_error(ref table,t,0,ref larger,3);write_error(ref table,t,0,ref mut larger,3);
    switch(bytes::append_byte(ref mut larger,33)){case .ok(_):{}case .err(_):{assert(false);}};
    read_error(ref table,t,0,ref larger,3);assert(bytes::equal(bytes::view(ref larger),b"keep!"));
    assert(ok(owners::release(ref mut table,t))==0);
    let owners::Token next=token(owners::create(ref mut table,ref larger));
    assert(switch(owners::read(ref table,next,4,ref larger)){case .ok(n):{n==33}case .err(_):{false}});
}
@test
fn void full_table_is_bounded_and_generation_exhaustion_retires_slot() {
    let bytes::Buffer b=buffer(64);var owners::Table table=owners::empty();
    // Descriptor-capacity fixture only; production callers register each root once.
    var usize i=0;while(i<16) {assert(token(owners::create(ref mut table,ref b)).slot==i);i+=1;}
    assert(switch(owners::create(ref mut table,ref b)){case .ok(_):{false}case .err(e):{code(e)==2}});
    table.slots[0].generation=18446744073709551615;
    assert(ok(owners::release(ref mut table,owners::Token{.slot=0,.generation=18446744073709551615}))==0);
    assert(table.slots[0].generation==0 && !table.slots[0].live);
    assert(switch(owners::create(ref mut table,ref b)){case .ok(_):{false}case .err(e):{code(e)==2}});
    assert(ok(owners::release(ref mut table,owners::Token{.slot=1,.generation=1}))==1);
    assert(token(owners::create(ref mut table,ref b)).slot==1);
}
@test
fn void malformed_table_is_rejected_without_payload_or_descriptor_mutation() {
    var bytes::Buffer b=buffer(64);var owners::Table table=owners::empty();
    let owners::Token t=token(owners::create(ref mut table,ref b));
    table.slots[1].capacity=64;
    read_error(ref table,t,0,ref b,3);write_error(ref table,t,0,ref mut b,3);
    assert(switch(owners::release(ref mut table,t)){case .ok(_):{false}case .err(e):{code(e)==3}});
    assert(table.slots[0].live && table.slots[0].generation==1 && table.slots[1].capacity==64);
    assert(switch(owners::create(ref mut table,ref b)){case .ok(_):{false}case .err(e):{code(e)==3}});
    table.slots[1].capacity=0;table.slots[0].capacity=18446744073709551615;
    read_error(ref table,t,0,ref b,3);write_error(ref table,t,0,ref mut b,3);
    assert(bytes::equal(bytes::view(ref b),b"keep"));
}
@test
fn void empty_buffer_descriptor_rejects_all_payload_access() {
    var bytes::Buffer b=bytes::empty();var owners::Table table=owners::empty();
    let owners::Token t=token(owners::create(ref mut table,ref b));
    read_error(ref table,t,0,ref b,4);write_error(ref table,t,0,ref mut b,4);
    assert(ok(owners::release(ref mut table,t))==0 && bytes::len(ref b)==0);
}
