module tests::m2::buffer_transfer;
import std::bytes as bytes;
import buffer_transfer as transfer;
import buffer_storage as storage;
import buffer_growth as growth;
import buffer_owners as owners;
import buffer_close as close;
import buffer_create as create;

fn bytes::Buffer root(ref mut growth::Ledger ledger){
    var bytes::Buffer b=bytes::empty();
    b=switch(storage::prepare_growth(ref b,256,
        growth::Limits{.object=4096,.instance=8192,.engine=8192},ledger)){
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    assert(growth::commit(bytes::capacity(ref b),ledger).is_ok);
    assert(bytes::append(ref mut b,b"keep").is_ok);return b;
}
fn owners::Token register(ref mut owners::Table table,ref bytes::Buffer b){
    return switch(owners::create(table,b)){case .ok(v):{v}case .err(_):{assert(false);
        owners::Token{.slot=16,.generation=0}}};
}
fn bytes::Buffer accepted(Result<bytes::Buffer,bytes::Buffer> result){return switch(result){
    case .ok(b):{b}case .err(b):{assert(false);b}
};}
fn bytes::Buffer rejected(Result<bytes::Buffer,bytes::Buffer> result){return switch(result){
    case .ok(b):{assert(false);b}case .err(b):{b}
};}
fn void unchanged(ref owners::Table table,ref owners::Table before,
    ref growth::Ledger ledger,ref growth::Ledger old){
    var usize i=0;while(i<16){let owners::Owner a=table.slots[i];let owners::Owner b=before.slots[i];
        assert(a.live==b.live && a.generation==b.generation && a.length==b.length &&
            a.capacity==b.capacity && a.reading==b.reading);i+=1;}
    assert(ledger.used==old.used && ledger.engine_used==old.engine_used && ledger.peak==old.peak &&
        ledger.engine_peak==old.engine_peak && ledger.pending==old.pending &&
        ledger.old_capacity==old.old_capacity && ledger.new_capacity==old.new_capacity &&
        ledger.before_used==old.before_used && ledger.before_engine_used==old.before_engine_used);
}
@test fn void real_native_root_moves_twice_then_closes_with_one_owner_charge(){
    var growth::Ledger ledger=growth::empty();let bytes::Buffer first=root(ref mut ledger);
    var owners::Table table=owners::empty();let owners::Token t=register(ref mut table,ref first);
    let owners::Table before=table;let growth::Ledger old=ledger;var close::Plan closing=close::empty();var usize fuel=256;
    let bytes::Buffer second=accepted(transfer::handoff(first,t,ref table,ref ledger,ref closing,ref mut fuel));
    var bytes::Buffer final_root=accepted(transfer::handoff(second,t,ref table,ref ledger,ref closing,ref mut fuel));
    assert(fuel==0 && bytes::len(ref final_root)==4 && bytes::capacity(ref final_root)==256);
    unchanged(ref table,ref before,ref ledger,ref old);
    assert(owners::write(ref table,t,3,88,ref mut final_root).is_ok);
    assert(bytes::equal(bytes::view(ref final_root),b"keeX"));
    assert(close::begin(ref mut table,t,ref final_root,ref ledger,ref mut closing).is_ok);
    {let bytes::Buffer disposed=final_root;}
    assert(close::finish(ref table,ref mut ledger,ref mut closing).is_ok);
    assert(ledger.used==0 && ledger.engine_used==0 && !owners::describe(ref table,t).is_ok);
}
@test fn void fuel_token_and_backing_rejection_return_the_original_owning_root(){
    var growth::Ledger ledger=growth::empty();var bytes::Buffer b=root(ref mut ledger);
    var owners::Table table=owners::empty();let owners::Token t=register(ref mut table,ref b);
    let owners::Table before=table;let growth::Ledger old=ledger;var close::Plan closing=close::empty();var usize fuel=127;
    b=rejected(transfer::handoff(b,owners::Token{.slot=16,.generation=0},ref table,ref ledger,ref closing,ref mut fuel));
    assert(fuel==127);fuel=128;
    b=rejected(transfer::handoff(b,owners::Token{.slot=t.slot,.generation=t.generation+1},ref table,ref ledger,ref closing,ref mut fuel));
    assert(fuel==0);unchanged(ref table,ref before,ref ledger,ref old);
    // Corrupting a selected descriptor or any unrelated row cannot mutate root.
    table.slots[t.slot].length=3;fuel=128;
    b=rejected(transfer::handoff(b,t,ref table,ref ledger,ref closing,ref mut fuel));assert(fuel==0);
    table.slots[t.slot].length=4;table.slots[15].capacity=1;fuel=128;
    b=rejected(transfer::handoff(b,t,ref table,ref ledger,ref closing,ref mut fuel));assert(fuel==0);
    table.slots[15].capacity=0;
    table.slots[t.slot].capacity=128;fuel=128;
    b=rejected(transfer::handoff(b,t,ref table,ref ledger,ref closing,ref mut fuel));assert(fuel==0);
    table.slots[t.slot].capacity=256;
    assert(bytes::equal(bytes::view(ref b),b"keep"));unchanged(ref table,ref before,ref ledger,ref old);
    fuel=129;b=accepted(transfer::handoff(b,t,ref table,ref ledger,ref closing,ref mut fuel));assert(fuel==1);
}
@test fn void live_read_leases_pending_growth_and_underaccounting_block_handoff(){
    var growth::Ledger ledger=growth::empty();var bytes::Buffer b=root(ref mut ledger);
    var owners::Table table=owners::empty();let owners::Token t=register(ref mut table,ref b);
    assert(owners::begin_read(ref mut table,t,ref b,ref ledger).is_ok);
    var close::Plan closing=close::empty();var usize fuel=128;b=rejected(transfer::handoff(b,t,ref table,ref ledger,ref closing,ref mut fuel));
    assert(fuel==0 && table.slots[t.slot].reading && bytes::equal(bytes::view(ref b),b"keep"));
    assert(owners::end_read(ref mut table,t).is_ok);
    assert(growth::begin(256,257,growth::Limits{.object=4096,.instance=8192,.engine=8192},ref mut ledger).is_ok);
    let owners::Table before=table;let growth::Ledger pending=ledger;
    fuel=128;b=rejected(transfer::handoff(b,t,ref table,ref ledger,ref closing,ref mut fuel));
    assert(fuel==0);unchanged(ref table,ref before,ref ledger,ref pending);
    assert(growth::cancel(ref mut ledger).is_ok);
    ledger.used=319;fuel=128;b=rejected(transfer::handoff(b,t,ref table,ref ledger,ref closing,ref mut fuel));
    assert(fuel==0 && ledger.used==319);ledger.used=320;
    // A real close of another root holds a charge while its descriptor is
    // already retired. Settled ledger counters alone cannot detect this phase.
    let bytes::Buffer other=bytes::empty();
    let owners::Token other_token=switch(create::empty(ref mut table,ref other,
        growth::Limits{.object=4096,.instance=8192,.engine=8192},ref mut ledger)){
        case .ok(v):{v}case .err(_):{assert(false);t}
    };
    assert(close::begin(ref mut table,other_token,ref other,ref ledger,ref mut closing).is_ok);
    assert(closing.active && growth::settled(ref ledger) && ledger.used==384);
    fuel=128;b=rejected(transfer::handoff(b,t,ref table,ref ledger,ref closing,ref mut fuel));
    assert(fuel==0 && closing.active && ledger.used==384);
    {let bytes::Buffer disposed=other;}
    assert(close::finish(ref table,ref mut ledger,ref mut closing).is_ok);
    fuel=128;b=accepted(transfer::handoff(b,t,ref table,ref ledger,ref closing,ref mut fuel));
    assert(fuel==0 && bytes::equal(bytes::view(ref b),b"keep"));
}
@test fn void no_spare_owner_slot_or_generation_is_needed_for_empty_or_allocated_moves(){
    var growth::Ledger ledger=growth::empty();var bytes::Buffer b=root(ref mut ledger);
    var owners::Table table=owners::empty();let owners::Token registered=register(ref mut table,ref b);
    // Full-descriptor capacity fixture; the other rows are metadata-only.
    var usize i=1;while(i<16){table.slots[i].live=true;i+=1;}
    ledger.used=1280;ledger.engine_used=1280;ledger.peak=1280;ledger.engine_peak=1280;
    table.slots[registered.slot].generation=18446744073709551615;
    let owners::Token t=owners::Token{.slot=registered.slot,.generation=18446744073709551615};
    let owners::Table before=table;let growth::Ledger old=ledger;var close::Plan closing=close::empty();var usize fuel=128;
    b=accepted(transfer::handoff(b,t,ref table,ref ledger,ref closing,ref mut fuel));
    assert(fuel==0 && bytes::equal(bytes::view(ref b),b"keep"));unchanged(ref table,ref before,ref ledger,ref old);
    var owners::Table empty_table=owners::empty();var growth::Ledger empty_ledger=growth::empty();
    let bytes::Buffer empty_root=bytes::empty();let owners::Token e=register(ref mut empty_table,ref empty_root);
    fuel=128;let bytes::Buffer moved_empty=accepted(transfer::handoff(empty_root,e,ref empty_table,ref empty_ledger,ref closing,ref mut fuel));
    assert(fuel==0 && bytes::len(ref moved_empty)==0 && bytes::capacity(ref moved_empty)==0 && empty_ledger.used==64);
}
