module tests::m2::slice_places;

import slice_places as places;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import slice_handoff as handoff;
import slice_reborrow as reborrow;

fn slices::Ticket opened(Result<slices::Ticket,owners::Error> result) {
    return switch(result) {
        case .ok(value): { value }
        case .err(_): { assert(false); slices::Ticket { .slot = 16, .generation = 0 } }
    };
}
fn slices::Arguments returned(Result<slices::Arguments,owners::Error> result) {
    return switch(result) {
        case .ok(value): { value }
        case .err(_): { assert(false); slices::empty_arguments() }
    };
}
fn handoff::Batch batch(Result<handoff::Batch,owners::Error> result) {
    return switch(result) {
        case .ok(value): { value }
        case .err(_): { assert(false); handoff::empty() }
    };
}
fn reborrow::Loan loan(Result<reborrow::Loan,owners::Error> result) {
    return switch(result) {
        case .ok(value): { value }
        case .err(_): { assert(false); reborrow::empty() }
    };
}
fn usize stored(Result<usize,owners::Error> result) {
    return switch(result) {
        case .ok(value): { value }
        case .err(_): { assert(false); 0 }
    };
}
fn i64 cell(Result<i64,owners::Error> result) {
    return switch(result) {
        case .ok(value): { value }
        case .err(_): { assert(false); 0 }
    };
}
fn owners::WriteLease empty_lease() {
    let owners::Token none = owners::Token { .slot = 16, .generation = 0 };
    return owners::WriteLease { .view = owners::View { .root = none, .element = 0,
        .length = 0, .start = 0, .end = 0 }, .generation = 0 };
}
fn places::Place selected(Result<places::Place,owners::Error> result) {
    return switch(result) {
        case .ok(value): { value }
        case .err(_): { assert(false); places::Place { .lease = empty_lease(),
            .ticket = slices::Ticket { .slot = 16, .generation = 0 }, .mark = 0,
            .base = 0, .end = 0, .index = 0, .offset = 0 } }
    };
}
fn owners::Token created(ref mut owners::Table table,u8 tag,usize length,i64 fill,
    ref mut u8[] data) {
    let layouts::Array shape = switch(layouts::scalar(tag,length)) {
        case .ok(value): { value }
        case .err(_): { assert(false); layouts::Array { .element = 10, .length = 1,
            .stride = 1, .alignment = 1, .bytes = 1 } }
    };
    return switch(owners::create(ref shape,fill,data,table)) {
        case .ok(value): { value }
        case .err(_): { assert(false); owners::Token { .slot = 16, .generation = 0 } }
    };
}
fn bool same_view(owners::View a,owners::View b) {
    return a.root.slot == b.root.slot && a.root.generation == b.root.generation &&
        a.element == b.element && a.length == b.length && a.start == b.start && a.end == b.end;
}
fn void same_pool(ref slices::Pool a,ref slices::Pool b) {
    var usize i = 0;
    while (i < 16) {
        let slices::Slot x = a.slots[i]; let slices::Slot y = b.slots[i];
        assert(x.generation == y.generation && x.live == y.live && x.exclusive == y.exclusive &&
            x.lease.root.slot == y.lease.root.slot &&
            x.lease.root.generation == y.lease.root.generation &&
            x.lease.generation == y.lease.generation && same_view(x.view,y.view));
        i += 1;
    }
}
fn void same_owners(ref owners::Table a,ref owners::Table b) {
    assert(a.depth == b.depth && a.arena.used == b.arena.used && a.arena.limit == b.arena.limit);
    var usize i = 0;
    while (i < 16) {
        let owners::Owner x = a.slots[i]; let owners::Owner y = b.slots[i];
        assert(a.order[i] == b.order[i] && x.generation == y.generation &&
            x.occupied == y.occupied && x.live == y.live && x.reading == y.reading &&
            x.writing == y.writing && x.read_generation == y.read_generation &&
            x.mark == y.mark && x.base == y.base && x.end == y.end &&
            x.element == y.element && x.length == y.length && x.record == y.record &&
            x.alignment == y.alignment);
        i += 1;
    }
}
fn void same_bytes(ref u8[] a,ref u8[] b) {
    assert(a.len == b.len);
    let usize count = if (a.len < b.len) { a.len } else { b.len };
    var usize i = 0;
    while (i < count) { assert(a[i] == b[i]); i += 1; }
}

@test
fn void descriptor_and_index_changes_preserve_the_captured_slice_cell() {
    var u8[8] data = [20; 8]; var owners::Table table = owners::empty(8);
    var slices::Pool pool = slices::empty();
    let owners::Token target = created(ref mut table,10,4,20,ref mut data);
    let owners::Token other = created(ref mut table,10,2,99,ref mut data);
    var usize index = 1;
    let slices::Ticket original = opened(slices::open_exclusive(ref mut pool,ref mut table,target,1,4,8));
    let slices::Pool selected_pool = pool; let owners::Table selected_table = table;
    let places::Place place = selected(places::select(ref pool,original,ref table,index,8));
    same_pool(ref pool,ref selected_pool); same_owners(ref table,ref selected_table);
    assert(place.mark == 0 && place.base == 0 && place.end == 4 &&
        place.index == 1 && place.offset == 2);
    index = 3;
    var slices::Ticket descriptor = original;
    descriptor = opened(slices::open_exclusive(ref mut pool,ref mut table,other,0,2,8));
    let slices::Pool before_store = pool; let owners::Table owners_before = table;
    assert(stored(places::store(ref pool,original,ref table,ref place,42,ref mut data)) == 1);
    same_pool(ref pool,ref before_store); same_owners(ref table,ref owners_before);
    assert(index == 3 && cell(slices::read(ref pool,original,ref table,1,ref data)) == 42);
    assert(cell(slices::read(ref pool,original,ref table,0,ref data)) == 20);
    assert(cell(slices::read(ref pool,descriptor,ref table,0,ref data)) == 99);
    assert(cell(places::read(ref pool,original,ref table,ref place,ref data)) == 42);
}

@test
fn void six_scalar_widths_keep_the_read_before_rhs_mutation() {
    let u8[6] tags = [1,2,9,10,11,12];
    let i64[6] values = [-2147483648,1,-9223372036854775807-1,255,4294967295,-1];
    let usize[6] widths = [4,1,8,1,4,8];
    var usize i = 0;
    while (i < 6) {
        var u8[40] data = [0; 40]; var owners::Table table = owners::empty(40);
        var slices::Pool pool = slices::empty();
        let i64 initial = if (tags[i] == 2) { 0 } else { 7 };
        let owners::Token root = created(ref mut table,tags[i],5,initial,ref mut data);
        let slices::Ticket ticket = opened(slices::open_exclusive(
            ref mut pool,ref mut table,root,1,4,40));
        let places::Place place = selected(places::select(ref pool,ticket,ref table,1,40));
        let i64 old = cell(places::read(ref pool,ticket,ref table,ref place,ref data));
        assert(old == initial);
        assert(stored(slices::write(ref pool,ticket,ref table,1,values[i],ref mut data)) == widths[i]);
        assert(cell(places::read(ref pool,ticket,ref table,ref place,ref data)) == values[i]);
        let slices::Pool before_store = pool; let owners::Table owners_before = table;
        assert(stored(places::store(ref pool,ticket,ref table,ref place,old+1,ref mut data)) == widths[i]);
        same_pool(ref pool,ref before_store); same_owners(ref table,ref owners_before);
        let i64 expected = if (tags[i] == 2) { 1 } else { 8 };
        assert(cell(places::read(ref pool,ticket,ref table,ref place,ref data)) == expected);
        assert(cell(slices::read(ref pool,ticket,ref table,0,ref data)) == initial);
        assert(cell(slices::read(ref pool,ticket,ref table,2,ref data)) == initial);
        i += 1;
    }
}

@test
fn void bool_selection_is_metadata_only_and_store_encoding_is_atomic() {
    var u8[8] data = [0; 8]; var owners::Table table = owners::empty(8);
    var slices::Pool pool = slices::empty();
    let owners::Token boolean = created(ref mut table,2,4,0,ref mut data);
    let slices::Ticket ticket = opened(slices::open_exclusive(
        ref mut pool,ref mut table,boolean,0,4,8));
    data[2] = 7;
    let places::Place place = selected(places::select(ref pool,ticket,ref table,2,8));
    let slices::Pool before = pool; let owners::Table owners_before = table;
    assert(!places::read(ref pool,ticket,ref table,ref place,ref data).is_ok);
    assert(!places::store(ref pool,ticket,ref table,ref place,2,ref mut data).is_ok);
    assert(data[2] == 7); same_pool(ref pool,ref before); same_owners(ref table,ref owners_before);
    assert(stored(places::store(ref pool,ticket,ref table,ref place,1,ref mut data)) == 1);
    assert(data[2] == 1);

    var u8[32] wide = [85; 32]; var owners::Table wide_table = owners::empty(32);
    var slices::Pool wide_pool = slices::empty();
    let owners::Token integer = created(ref mut wide_table,1,2,20,ref mut wide);
    let slices::Ticket wide_ticket = opened(slices::open_exclusive(
        ref mut wide_pool,ref mut wide_table,integer,0,2,32));
    let places::Place wide_place = selected(places::select(
        ref wide_pool,wide_ticket,ref wide_table,0,32));
    var u8[32] saved = [0; 32]; var usize i = 0;
    while (i < 32) { saved[i] = wide[i]; i += 1; }
    let slices::Pool wide_before = wide_pool; let owners::Table wide_owners = wide_table;
    assert(!places::store(ref wide_pool,wide_ticket,ref wide_table,ref wide_place,
        2147483648,ref mut wide).is_ok);
    same_bytes(ref wide,ref saved); same_pool(ref wide_pool,ref wide_before);
    same_owners(ref wide_table,ref wide_owners);
}

fn void range_boundaries() {
    var u8[4096] data = [7; 4096]; var owners::Table table = owners::empty(4096);
    var slices::Pool pool = slices::empty();
    let owners::Token root = created(ref mut table,10,4096,7,ref mut data);
    let slices::Ticket full = opened(slices::open_exclusive(
        ref mut pool,ref mut table,root,0,4096,4096));
    let places::Place last = selected(places::select(ref pool,full,ref table,4095,4096));
    assert(last.offset == 4095 && last.end == 4096 && last.index == 4095);
    let slices::Pool before = pool; let owners::Table owners_before = table;
    assert(!places::select(ref pool,full,ref table,4096,4096).is_ok);
    assert(!places::select(ref pool,full,ref table,18446744073709551615,4096).is_ok);
    assert(!places::select(ref pool,full,ref table,0,4095).is_ok);
    same_pool(ref pool,ref before); same_owners(ref table,ref owners_before);
    assert(!places::store(ref pool,full,ref table,ref last,42,ref mut data[..4095]).is_ok);
    assert(data[4095] == 7);
    assert(stored(places::store(ref pool,full,ref table,ref last,42,ref mut data)) == 1);
    assert(data[4095] == 42);
    assert(slices::close(ref mut pool,full,ref mut table,4096).is_ok);

    let slices::Ticket nonzero = opened(slices::open_exclusive(
        ref mut pool,ref mut table,root,5,4096,4096));
    let places::Place first = selected(places::select(ref pool,nonzero,ref table,0,4096));
    assert(first.offset == 5 && first.index == 0 && first.end == 4096);
    assert(stored(places::store(ref pool,nonzero,ref table,ref first,9,ref mut data)) == 1);
    assert(data[5] == 9);
    assert(slices::close(ref mut pool,nonzero,ref mut table,4096).is_ok);

    let slices::Ticket empty = opened(slices::open_exclusive(
        ref mut pool,ref mut table,root,4096,4096,4096));
    assert(!places::select(ref pool,empty,ref table,0,4096).is_ok);
    assert(slices::close(ref mut pool,empty,ref mut table,4096).is_ok);
}

@test
fn void empty_nonzero_last_host_max_and_short_capacity_are_bounded() {
    range_boundaries();
}

@test
fn void completed_call_and_lexical_rotations_accept_current_full_views() {
    var u8[8] data = [0; 8]; var owners::Table table = owners::empty(8);
    var slices::Pool pool = slices::empty();
    let owners::Token call_root = created(ref mut table,10,4,0,ref mut data);
    let owners::Token lexical_root = created(ref mut table,10,3,0,ref mut data);
    let slices::Ticket call_parent = opened(slices::open_exclusive(
        ref mut pool,ref mut table,call_root,0,4,8));
    let places::Place call_place = selected(places::select(
        ref pool,call_parent,ref table,1,8));
    let slices::Ticket[1] call_sources = [call_parent];
    var handoff::Batch call_receipt = batch(handoff::begin(
        ref mut pool,ref call_sources,ref table,8,0));
    let slices::Ticket call_child = call_receipt.tickets[0];
    let slices::Pool call_before = pool; let owners::Table call_owners = table;
    assert(stored(slices::write(ref pool,call_child,ref table,1,11,ref mut data)) == 1);
    same_pool(ref pool,ref call_before); same_owners(ref table,ref call_owners);
    let slices::Ticket[1] call_current = [call_child];
    let slices::Arguments call_back = returned(handoff::restore(
        ref mut pool,ref mut call_receipt,ref call_current,ref table,8));
    let slices::Ticket call_resumed = call_back.tickets[0];
    assert(cell(places::read(ref pool,call_resumed,ref table,ref call_place,ref data)) == 11);
    assert(stored(places::store(ref pool,call_resumed,ref table,ref call_place,
        12,ref mut data)) == 1);
    assert(cell(places::read(ref pool,call_resumed,ref table,ref call_place,ref data)) == 12);

    let slices::Ticket lexical_parent = opened(slices::open_exclusive(
        ref mut pool,ref mut table,lexical_root,0,3,8));
    let places::Place lexical_place = selected(places::select(
        ref pool,lexical_parent,ref table,2,8));
    var reborrow::Loan lexical_receipt = loan(reborrow::begin(
        ref mut pool,lexical_parent,ref table,1,3,8,0));
    let slices::Ticket lexical_child = lexical_receipt.issued;
    let slices::Ticket lexical_resumed = opened(reborrow::restore(
        ref mut pool,ref mut lexical_receipt,lexical_child,ref table,8));
    let slices::Pool lexical_before = pool; let owners::Table lexical_owners = table;
    assert(cell(places::read(ref pool,lexical_resumed,ref table,ref lexical_place,ref data)) == 0);
    assert(stored(places::store(ref pool,lexical_resumed,ref table,ref lexical_place,
        21,ref mut data)) == 1);
    same_pool(ref pool,ref lexical_before); same_owners(ref table,ref lexical_owners);
    assert(cell(places::read(ref pool,lexical_resumed,ref table,ref lexical_place,ref data)) == 21);
    assert(slices::close(ref mut pool,call_resumed,ref mut table,8).is_ok);
    assert(slices::close(ref mut pool,lexical_resumed,ref mut table,8).is_ok);
}

@test
fn void stale_original_and_still_narrowed_child_tickets_reject_atomically() {
    var u8[8] data = [5; 8]; var owners::Table table = owners::empty(8);
    var slices::Pool pool = slices::empty();
    let owners::Token call_root = created(ref mut table,10,4,5,ref mut data);
    let owners::Token lexical_root = created(ref mut table,10,3,5,ref mut data);
    let slices::Ticket call_parent = opened(slices::open_exclusive(
        ref mut pool,ref mut table,call_root,0,4,8));
    let places::Place call_place = selected(places::select(
        ref pool,call_parent,ref table,1,8));
    let slices::Ticket[1] call_sources = [call_parent];
    var handoff::Batch call_receipt = batch(handoff::begin(
        ref mut pool,ref call_sources,ref table,8,0));
    let slices::Ticket call_child = call_receipt.tickets[0];
    let slices::Pool call_before = pool; let owners::Table call_owners = table;
    assert(!places::read(ref pool,call_parent,ref table,ref call_place,ref data).is_ok);
    assert(!places::store(ref pool,call_parent,ref table,ref call_place,42,ref mut data).is_ok);
    same_pool(ref pool,ref call_before); same_owners(ref table,ref call_owners);
    let slices::Ticket[1] call_current = [call_child];
    let slices::Arguments call_back = returned(handoff::restore(
        ref mut pool,ref mut call_receipt,ref call_current,ref table,8));
    let slices::Ticket call_resumed = call_back.tickets[0];
    let slices::Pool after_call = pool; let owners::Table owners_after_call = table;
    assert(!places::store(ref pool,call_parent,ref table,ref call_place,42,ref mut data).is_ok);
    same_pool(ref pool,ref after_call); same_owners(ref table,ref owners_after_call);

    let slices::Ticket lexical_parent = opened(slices::open_exclusive(
        ref mut pool,ref mut table,lexical_root,0,3,8));
    let places::Place lexical_place = selected(places::select(
        ref pool,lexical_parent,ref table,1,8));
    var reborrow::Loan lexical_receipt = loan(reborrow::begin(
        ref mut pool,lexical_parent,ref table,1,3,8,0));
    let slices::Ticket narrowed = lexical_receipt.issued;
    // The same relative index is in bounds in BOTH views, but points to a
    // different root element. Rejection must authenticate the original view.
    assert(cell(slices::read(ref pool,narrowed,ref table,1,ref data)) == 5);
    let slices::Pool lexical_before = pool; let owners::Table lexical_owners = table;
    assert(!places::read(ref pool,narrowed,ref table,ref lexical_place,ref data).is_ok);
    assert(!places::store(ref pool,narrowed,ref table,ref lexical_place,42,ref mut data).is_ok);
    assert(!places::store(ref pool,lexical_parent,ref table,ref lexical_place,42,ref mut data).is_ok);
    same_pool(ref pool,ref lexical_before); same_owners(ref table,ref lexical_owners);
    let slices::Ticket lexical_resumed = opened(reborrow::restore(
        ref mut pool,ref mut lexical_receipt,narrowed,ref table,8));
    let u8[8] expected = [5; 8]; same_bytes(ref data,ref expected);
    assert(slices::close(ref mut pool,call_resumed,ref mut table,8).is_ok);
    assert(slices::close(ref mut pool,lexical_resumed,ref mut table,8).is_ok);
}

@test
fn void closed_and_reopened_owner_session_cannot_revive_a_place() {
    var u8[4] data = [11; 4]; var owners::Table table = owners::empty(4);
    var slices::Pool pool = slices::empty();
    let owners::Token root = created(ref mut table,10,3,11,ref mut data);
    let slices::Ticket original = opened(slices::open_exclusive(
        ref mut pool,ref mut table,root,0,3,4));
    let places::Place old = selected(places::select(ref pool,original,ref table,1,4));
    let usize old_epoch = table.slots[root.slot].read_generation;
    assert(slices::close(ref mut pool,original,ref mut table,4).is_ok);
    assert(table.slots[root.slot].read_generation != old_epoch);
    let slices::Ticket fresh = opened(slices::open_exclusive(
        ref mut pool,ref mut table,root,0,3,4));
    let slices::Pool before = pool; let owners::Table owners_before = table;
    assert(!places::store(ref pool,fresh,ref table,ref old,42,ref mut data).is_ok);
    assert(!places::read(ref pool,fresh,ref table,ref old,ref data).is_ok);
    same_pool(ref pool,ref before); same_owners(ref table,ref owners_before);
    let u8[4] unchanged = [11; 4]; same_bytes(ref data,ref unchanged);
    let places::Place current = selected(places::select(ref pool,fresh,ref table,1,4));
    assert(stored(places::store(ref pool,fresh,ref table,ref current,33,ref mut data)) == 1);
    assert(data[1] == 33);
    assert(slices::close(ref mut pool,fresh,ref mut table,4).is_ok);
    assert(owners::release(ref mut table,root,4).is_ok);
    let owners::Token reused = created(ref mut table,10,3,77,ref mut data);
    assert(reused.slot == root.slot && reused.generation != root.generation);
    let slices::Ticket replacement = opened(slices::open_exclusive(
        ref mut pool,ref mut table,reused,0,3,4));
    assert(!places::read(ref pool,replacement,ref table,ref current,ref data).is_ok);
    assert(!places::store(ref pool,replacement,ref table,ref old,42,ref mut data).is_ok);
    assert(data[0] == 77 && data[1] == 77 && data[2] == 77 && data[3] == 11);
    assert(slices::clear(ref mut pool,ref mut table,4).is_ok);
    assert(owners::clear(ref mut table,4).is_ok);
    assert(!places::store(ref pool,replacement,ref table,ref current,42,ref mut data).is_ok);
}

@test
fn void full_owner_pool_and_backing_need_no_extra_slot_or_reservation() {
    var u8[16] data = [0;16]; var owners::Table table = owners::empty(16);
    var slices::Pool pool = slices::empty();
    var slices::Ticket[16] tickets = [slices::Ticket{.slot=16,.generation=0};16];
    var usize i = 0;
    while(i<16){
        let owners::Token root=created(ref mut table,10,1,0,ref mut data);
        tickets[i]=opened(slices::open_exclusive(ref mut pool,ref mut table,root,0,1,16));
        i+=1;
    }
    let slices::Pool before=pool; let owners::Table owners_before=table;
    i=0;
    while(i<16){
        let places::Place place=selected(places::select(ref pool,tickets[i],ref table,0,16));
        assert(cell(places::read(ref pool,tickets[i],ref table,ref place,ref data))==0);
        assert(stored(places::store(ref pool,tickets[i],ref table,ref place,42,ref mut data))==1);
        assert(data[i]==42);i+=1;
    }
    same_pool(ref pool,ref before);same_owners(ref table,ref owners_before);
    assert(table.depth==16 && table.arena.used==16 && table.arena.limit==16);
    assert(slices::clear(ref mut pool,ref mut table,16).is_ok);
    assert(owners::clear(ref mut table,16).is_ok);
}

@test
fn void malformed_snapshot_and_pool_owner_ledgers_fail_atomically() {
    var u8[8] data = [85; 8]; var owners::Table table = owners::empty(8);
    var slices::Pool pool = slices::empty();
    let owners::Token root = created(ref mut table,10,4,5,ref mut data);
    let owners::Token observer = created(ref mut table,10,2,9,ref mut data);
    let slices::Ticket ticket = opened(slices::open_exclusive(
        ref mut pool,ref mut table,root,0,4,8));
    let slices::Ticket reader = opened(slices::open(
        ref mut pool,ref mut table,observer,0,2,8));
    let places::Place place = selected(places::select(ref pool,ticket,ref table,1,8));
    let slices::Pool pristine = pool; let owners::Table owners_pristine = table;
    let u8[8] pristine_data = [5,5,5,5,9,9,85,85];
    assert(!places::select(ref pool,reader,ref table,0,8).is_ok);
    same_pool(ref pool,ref pristine); same_owners(ref table,ref owners_pristine);

    var places::Place bad = place; bad.ticket.slot = 16;
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    bad = place; bad.ticket.generation = 0;
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    bad = place; bad.ticket.generation += 1;
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    bad = place; bad.lease.generation += 1;
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    bad = place; bad.lease.view.root.generation += 1;
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    bad = place; bad.lease.view.element = 1;
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    bad = place; bad.lease.view.length += 1;
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    bad = place; bad.lease.view.start = 1;
    assert(!places::read(ref pool,ticket,ref table,ref bad,ref data).is_ok);
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    bad = place; bad.lease.view.end = 3;
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    bad = place; bad.mark = 1;
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    bad = place; bad.base = 1;
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    bad = place; bad.end = 3;
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    bad = place; bad.index = 0;
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    bad = place; bad.offset = 0;
    assert(!places::store(ref pool,ticket,ref table,ref bad,42,ref mut data).is_ok);
    same_pool(ref pool,ref pristine); same_owners(ref table,ref owners_pristine);
    same_bytes(ref data,ref pristine_data);

    let usize slot = place.ticket.slot; let usize start = pool.slots[slot].view.start;
    let usize generation = pool.slots[slot].generation;
    let usize lease_generation = pool.slots[slot].lease.generation;
    pool.slots[slot].view.start = start + 1;
    assert(!places::store(ref pool,ticket,ref table,ref place,42,ref mut data).is_ok);
    pool.slots[slot].view.start = start;
    pool.slots[slot].exclusive = false;
    assert(!places::store(ref pool,ticket,ref table,ref place,42,ref mut data).is_ok);
    pool.slots[slot].exclusive = true;
    pool.slots[slot].lease.generation = lease_generation + 1;
    assert(!places::store(ref pool,ticket,ref table,ref place,42,ref mut data).is_ok);
    pool.slots[slot].lease.generation = lease_generation;
    pool.slots[slot].generation = generation + 1;
    assert(!places::store(ref pool,ticket,ref table,ref place,42,ref mut data).is_ok);
    pool.slots[slot].generation = generation;
    pool.slots[slot].live = false;
    assert(!places::store(ref pool,ticket,ref table,ref place,42,ref mut data).is_ok);
    pool.slots[slot].live = true;
    same_pool(ref pool,ref pristine);

    let usize mark = table.slots[root.slot].mark; let usize base = table.slots[root.slot].base;
    let usize end = table.slots[root.slot].end;
    let usize epoch = table.slots[root.slot].read_generation;
    let usize depth = table.depth; let usize order = table.order[0];
    table.slots[root.slot].mark = mark + 1;
    assert(!places::store(ref pool,ticket,ref table,ref place,42,ref mut data).is_ok);
    table.slots[root.slot].mark = mark;
    table.slots[root.slot].base = base + 1;
    assert(!places::store(ref pool,ticket,ref table,ref place,42,ref mut data).is_ok);
    table.slots[root.slot].base = base;
    table.slots[root.slot].end = end - 1;
    assert(!places::store(ref pool,ticket,ref table,ref place,42,ref mut data).is_ok);
    table.slots[root.slot].end = end;
    table.slots[root.slot].read_generation = epoch + 1;
    assert(!places::store(ref pool,ticket,ref table,ref place,42,ref mut data).is_ok);
    table.slots[root.slot].read_generation = epoch;
    table.depth = 0;
    assert(!places::store(ref pool,ticket,ref table,ref place,42,ref mut data).is_ok);
    table.depth = depth;
    table.order[0] = 16;
    assert(!places::store(ref pool,ticket,ref table,ref place,42,ref mut data).is_ok);
    table.order[0] = order;
    same_pool(ref pool,ref pristine); same_owners(ref table,ref owners_pristine);
    same_bytes(ref data,ref pristine_data);
    let slices::Pool before_store = pool; let owners::Table before_owners = table;
    assert(stored(places::store(ref pool,ticket,ref table,ref place,42,ref mut data)) == 1);
    same_pool(ref pool,ref before_store); same_owners(ref table,ref before_owners);
    assert(data[1] == 42);
    assert(slices::close(ref mut pool,ticket,ref mut table,8).is_ok);
    assert(slices::close(ref mut pool,reader,ref mut table,8).is_ok);
}
