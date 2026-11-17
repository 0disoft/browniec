module array_owners;

import array_layout as layouts;
import array_fill_cursor as filling;
import array_storage as storage;
import std::text as text;
import scalar_codec as codec;
import struct_layout as records;
import struct_nested_storage as record_storage;
import struct_range as record_range;
import aggregate_copy as copying;
import call_copy_cursor as calling;

// Instance-local metadata over caller-owned backing bytes. No guest/raw pointer.
pub struct Token { usize slot; usize generation; }
// Private, table-local range descriptor. It owns no storage and pins no root.
// Every use revalidates its token, original shape, range and current backing.
pub struct View { Token root; u8 element; usize length; usize start; usize end; }
// One explicit read session per array root; multiple views may share it.
pub struct ReadLease { Token root; usize generation; }
// A single exclusive session locks the whole root, even for an empty range.
// Read and write sessions share an epoch so neither kind can resurrect a ticket.
pub struct WriteLease { View view; usize generation; }
pub struct Owner {
    usize generation; bool occupied; bool live; bool reading; bool writing; usize mark; usize base; usize end;
    // element 0 denotes a record: length is bytes, record/alignment identify its layout.
    // Arrays retain their scalar element/length and zero record/alignment fields.
    u8 element; usize length; usize record; usize alignment; usize read_generation;
}
pub struct Table { Owner[16] slots; usize[16] order; usize depth; storage::Arena arena; }
// Dense array-argument results, in input order. Scalar arguments are not included.
pub struct Copies { Token[8] tokens; usize count; }
// Dense aggregate arguments in source order. element 0 selects a nominal record
// (length must be zero); arrays use their scalar tag/length and record zero.
pub struct CallArgument { Token source; u8 element; usize length; usize record; }
pub enum Error { Token; Owners; State; Type; Length; Metadata; Overflow; Quota; Bounds; Alignment; Value; }

pub fn Table empty(usize limit) {
    return Table { .slots = [Owner { .generation = 1, .occupied = false, .live = false,
        .reading = false, .writing = false, .read_generation = 1,
        .mark = 0, .base = 0, .end = 0, .element = 0, .length = 0, .record = 0, .alignment = 0 }; 16],
        .order = [0; 16], .depth = 0, .arena = storage::empty(limit) };
}
fn Error storage_error(storage::Error error) {
    return switch (error) {
        case .Type: { .Type } case .Length: { .Length } case .Metadata: { .Metadata }
        case .Overflow: { .Overflow } case .Quota: { .Quota } case .Bounds: { .Bounds }
        case .Alignment: { .Alignment } case .Value: { .Value } case .State: { .State }
    };
}

// Derive a reservation layout, never an array view of a record token.
fn Result<layouts::Array, Error> allocation_layout(ref Owner owner) {
    if (owner.element != 0) {
        if (owner.record != 0 || owner.alignment != 0) { return .err(.State); }
        return switch (layouts::scalar(owner.element, owner.length)) {
            case .ok(value): { .ok(value) } case .err(_): { .err(.State) }
        };
    }
    if (owner.record >= 32 || owner.length == 0 || owner.length > 128) { return .err(.State); }
    if (owner.alignment != 1 && owner.alignment != 4 && owner.alignment != 8) { return .err(.State); }
    if (owner.length % owner.alignment != 0) { return .err(.State); }
    let u8 tag = if (owner.alignment == 1) { 10 } else if (owner.alignment == 4) { 11 } else { 12 };
    return switch (layouts::scalar(tag, owner.length / owner.alignment)) {
        case .ok(value): { .ok(value) } case .err(_): { .err(.State) }
    };
}

// Validate only metadata, never payload. The allocation-order chain proves that
// retained extents cover exactly the published prefix without gaps or overlap.
fn bool valid(ref Table table, usize capacity) {
    if (table.depth > 16 || table.arena.used > table.arena.limit || table.arena.limit > capacity) { return false; }
    // Sixteen owner identities fit one scalar mask; no nested scratch bank.
    var usize seen = 0;let usize one=1;
    var usize cursor = 0;
    var usize i = 0;
    while (i < table.depth) {
        let usize slot = table.order[i];
        if (slot >= 16) { return false; }
        let usize bit=one<<slot;if ((seen&bit)!=0) { return false; }
        seen|=bit;
        let Owner owner = table.slots[slot];
        if (!owner.occupied || owner.mark != cursor || (owner.live && owner.generation == 0)) { return false; }
        if ((owner.reading || owner.writing) && (!owner.live || owner.element == 0 || owner.read_generation == 0)) { return false; }
        if (owner.reading && owner.writing) { return false; }
        let layouts::Array layout = switch (allocation_layout(ref owner)) {
            case .ok(value): { value } case .err(_): { return false; }
        };
        let layouts::Reservation plan = switch (layouts::reserve(ref layout, cursor, table.arena.limit)) {
            case .ok(value): { value } case .err(_): { return false; }
        };
        if (owner.base != plan.offset || owner.end != plan.end) { return false; }
        cursor = owner.end;
        i += 1;
    }
    if (cursor != table.arena.used) { return false; }
    i = 0;
    while (i < 16) {
        let Owner owner=table.slots[i];let bool retained=(seen&(one<<i))!=0;
        if (owner.occupied != retained || (owner.live && !retained)) { return false; }
        if ((owner.reading || owner.writing) && !retained) { return false; }
        i += 1;
    }
    return true;
}
// Token identity only: this does not prove table/arena integrity. Public paths
// use resolve_any below; batch preflight may reuse its initial full validation
// while the original table remains unchanged and reservations stay in planned.
fn Result<Owner, Error> lookup(ref Table table, Token token) {
    if (token.slot >= 16 || token.generation == 0) { return .err(.Token); }
    let Owner owner = table.slots[token.slot];
    if (!owner.occupied || !owner.live || owner.generation != token.generation) { return .err(.Token); }
    return .ok(owner);
}
fn Result<Owner, Error> resolve_any(ref Table table, Token token, usize capacity) {
    let Owner owner = lookup(table, token)?;
    if (!valid(table, capacity)) { return .err(.State); }
    return .ok(owner);
}
// Private RET preparation: resolve identity before table validation, preserving
// raw result error order. No catalog discovery, payload access or authority.
pub fn Result<Owner,Error> inspect_return_owner(ref Table table,Token token,usize capacity){
    return resolve_any(table,token,capacity);
}
// Array entry points must reject record tokens even when their raw size matches.
fn Result<Owner, Error> resolve(ref Table table, Token token, usize capacity) {
    let Owner owner = resolve_any(table, token, capacity)?;
    if (owner.element == 0) { return .err(.Type); }
    if (owner.writing) { return .err(.State); }
    return .ok(owner);
}
fn Result<Owner, Error> writable(ref Table table, Token token, usize capacity) {
    let Owner owner = resolve(table, token, capacity)?;
    if (owner.reading) { return .err(.State); }
    return .ok(owner);
}
fn Result<Owner, Error> resolve_read(ref Table table, ReadLease lease, usize capacity) {
    let Owner owner = resolve(table, lease.root, capacity)?;
    if (!owner.reading || lease.generation == 0 || lease.generation != owner.read_generation) { return .err(.State); }
    return .ok(owner);
}
pub fn Result<ReadLease, Error> begin_read(ref mut Table table, Token root, usize capacity) {
    let Owner owner = writable(table, root, capacity)?;
    if (owner.read_generation == 0) { return .err(.State); }
    table.slots[root.slot].reading = true;
    return .ok(ReadLease { .root = root, .generation = owner.read_generation });
}
pub fn Result<usize, Error> end_read(ref mut Table table, ReadLease lease, usize capacity) {
    let Owner owner = resolve_read(table, lease, capacity)?;
    table.slots[lease.root.slot].reading = false;
    table.slots[lease.root.slot].read_generation = next_generation(owner.read_generation);
    return .ok(lease.root.slot);
}
pub fn Result<i64, Error> leased_read(ref Table table, ReadLease lease, ref View view, usize index, ref u8[] bytes) {
    let Owner owner = resolve_leased_view(table, lease, view, bytes.len)?;
    return read_view_prepared(table, ref owner, view, index, bytes);
}
pub fn Result<bool, Error> leased_utf8(ref Table table, ReadLease lease, ref View view, ref u8[] bytes) {
    let Owner owner = resolve_leased_view(table, lease, view, bytes.len)?;
    return utf8_view_prepared(ref owner, view, bytes);
}
pub fn Result<usize, Error> leased_length(ref Table table, ReadLease lease, ref View view, usize capacity) {
    let Owner owner = resolve_leased_view(table, lease, view, capacity)?;
    return .ok(view.end - view.start);
}
fn Result<Owner, Error> resolve_leased_view(ref Table table, ReadLease lease, ref View view, usize capacity) {
    let Owner owner = resolve_read(table, lease, capacity)?;
    if (view.root.slot != lease.root.slot || view.root.generation != lease.root.generation) { return .err(.Token); }
    // Same immutable table/root: resolve_read already authenticated every slot.
    return view_shape(ref owner, view);
}
pub fn Result<WriteLease, Error> begin_write(ref mut Table table, Token root,
    usize start, usize end, usize capacity) {
    let Owner owner = writable(table, root, capacity)?;
    if (owner.read_generation == 0) { return .err(.State); }
    // Validate before locking: failed range admission preserves the whole table.
    let View selected = view(table, root, start, end, capacity)?;
    table.slots[root.slot].writing = true;
    return .ok(WriteLease { .view = selected, .generation = owner.read_generation });
}
fn Result<Owner, Error> resolve_write(ref Table table, ref WriteLease lease, usize capacity) {
    let Owner owner = resolve_any(table, lease.view.root, capacity)?;
    if (owner.element == 0) { return .err(.Type); }
    if (!owner.writing || lease.generation == 0 || lease.generation != owner.read_generation) { return .err(.State); }
    if (lease.view.element != owner.element) { return .err(.Type); }
    if (lease.view.length != owner.length) { return .err(.Length); }
    if (lease.view.start > lease.view.end || lease.view.end > owner.length) { return .err(.Bounds); }
    return .ok(owner);
}
pub fn Result<usize, Error> end_write(ref mut Table table, ref WriteLease lease, usize capacity) {
    let Owner owner = resolve_write(table, lease, capacity)?;
    table.slots[lease.view.root.slot].writing = false;
    table.slots[lease.view.root.slot].read_generation = next_generation(owner.read_generation);
    return .ok(lease.view.root.slot);
}
pub fn Result<usize, Error> exclusive_length(ref Table table, ref WriteLease lease, usize capacity) {
    let Owner owner = resolve_write(table, lease, capacity)?;
    return .ok(lease.view.end - lease.view.start);
}
pub fn Result<i64, Error> exclusive_read(ref Table table, ref WriteLease lease, usize index, ref u8[] bytes) {
    let Owner owner = resolve_write(table, lease, bytes.len)?;
    if (index >= lease.view.end - lease.view.start) { return .err(.Bounds); }
    let layouts::Array layout = switch (layouts::scalar(owner.element, owner.length)) {
        case .ok(value): { value } case .err(_): { return .err(.State); }
    };
    return switch (storage::read(ref layout, owner.base, lease.view.start + index, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(e): { .err(storage_error(e)) }
    };
}
pub fn Result<usize, Error> exclusive_write(ref Table table, ref WriteLease lease,
    usize index, i64 cell, ref mut u8[] bytes) {
    let Owner owner = resolve_write(table, lease, bytes.len)?;
    if (index >= lease.view.end - lease.view.start) { return .err(.Bounds); }
    let layouts::Array layout = switch (layouts::scalar(owner.element, owner.length)) {
        case .ok(value): { value } case .err(_): { return .err(.State); }
    };
    // The scalar codec stages at most eight bytes before publishing the element.
    return switch (storage::write(ref layout, owner.base, lease.view.start + index, cell, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(e): { .err(storage_error(e)) }
    };
}
pub fn Result<bool, Error> exclusive_utf8(ref Table table, ref WriteLease lease, ref u8[] bytes) {
    let Owner owner = resolve_write(table, lease, bytes.len)?;
    if (owner.element != 10) { return .err(.Type); }
    // Validated u8 shape/range bounds both additions by the initialized extent.
    return .ok(text::validate_utf8(bytes[owner.base + lease.view.start..owner.base + lease.view.end]).is_ok);
}
fn Result<usize, Error> free_slot(ref Table table) {
    var usize i = 0;
    while (i < 16) {
        if (!table.slots[i].occupied && table.slots[i].generation != 0) { return .ok(i); }
        i += 1;
    }
    return .err(.Owners);
}
fn Token publish(ref mut Table table, usize slot, ref layouts::Array layout, usize mark, usize base) {
    let usize generation = table.slots[slot].generation;
    let usize end = table.arena.used;
    let usize depth = table.depth;
    table.slots[slot] = Owner { .generation = generation, .occupied = true, .live = true,
        .reading = false, .writing = false, .read_generation = 1,
        .mark = mark, .base = base, .end = end, .element = layout.element, .length = layout.length, .record = 0, .alignment = 0 };
    table.order[depth] = slot;
    table.depth += 1;
    return Token { .slot = slot, .generation = generation };
}

// Trusted resumable CREATE33/FILL40 metadata bridge. These recipes are private
// owning-execution state, never evidence authorizing arbitrary external/raw IR.
// The parent pins one table/backing region and freezes other guest instructions;
// no table snapshot, payload scan, epoch change or provisional publication occurs.
pub fn Result<filling::State,Error> prepare_fill(ref Table table,u8 op,
    ref layouts::Array layout,Token target,usize capacity){
    if(op!=33 && op!=40){return .err(.State);}
    let usize size=switch(layouts::validate(layout)){
        case .ok(n):{n}
        case .err(e):{return .err(switch(e){
            case .Type:{.Type}case .Length:{.Length}case .Metadata:{.Metadata}
            case .Overflow:{.Overflow}case .Quota:{.Quota}case .Bounds:{.Bounds}
            case .Alignment:{.Alignment}
        });}
    };
    var filling::State work=filling::empty();
    work.active=true;work.op=op;work.element=layout.element;
    work.length=layout.length;work.stride=layout.stride;work.depth=table.depth;
    if(op==33){
        if(!valid(table,capacity)){return .err(.State);}
        work.slot=free_slot(table)?;work.generation=table.slots[work.slot].generation;
        work.mark=table.arena.used;
        let layouts::Reservation plan=switch(layouts::reserve(layout,work.mark,table.arena.limit)){
            case .ok(p):{p}
            case .err(e):{return .err(switch(e){
                case .Type:{.Type}case .Length:{.Length}case .Metadata:{.Metadata}
                case .Overflow:{.Overflow}case .Quota:{.Quota}case .Bounds:{.Bounds}
                case .Alignment:{.Alignment}
            });}
        };
        work.base=plan.offset;work.end=plan.end;
    }else{
        let Owner owner=writable(table,target,capacity)?;
        if(owner.element!=layout.element){return .err(.Type);}
        if(owner.length!=layout.length){return .err(.Length);}
        work.slot=target.slot;work.generation=target.generation;
        work.mark=owner.mark;work.base=owner.base;work.end=owner.end;
    }
    return .ok(work);
}

// Recompute every reservation/shape fact using the private table validators on
// every resume. The saved recipe is a comparison target, not allocation authority.
pub fn Result<usize,Error> validate_fill(ref Table table,ref filling::State work,usize capacity){
    if(!work.active){return .err(.State);}
    let layouts::Array layout=switch(layouts::scalar(work.element,work.length)){
        case .ok(a):{a}case .err(_):{return .err(.State);}
    };
    let filling::State current=prepare_fill(table,work.op,ref layout,
        Token{.slot=work.slot,.generation=work.generation},capacity)?;
    if(current.slot!=work.slot || current.generation!=work.generation ||
        current.mark!=work.mark || current.base!=work.base || current.end!=work.end ||
        current.depth!=work.depth || current.stride!=work.stride){return .err(.State);}
    let usize size=work.end-if(work.op==33){work.mark}else{work.base};
    if(work.written>size || work.written>work.total || work.last>work.total){return .err(.State);}
    return .ok(size);
}

// Only array_fill_work calls this after its final payload write. Completion
// counts are trusted owning state, not a proof that guest-selected bytes exist.
// All metadata is reauthenticated before the first table mutation.
pub fn Result<Token,Error> publish_fill(ref mut Table table,ref filling::State work,usize capacity){
    let usize size=validate_fill(table,work,capacity)?;
    if(work.written!=size){return .err(.State);}
    if(work.op==40){return .ok(Token{.slot=work.slot,.generation=work.generation});}
    let layouts::Array layout=switch(layouts::scalar(work.element,work.length)){
        case .ok(a):{a}case .err(_):{return .err(.State);}
    };
    table.arena.used=work.end;
    return .ok(publish(table,work.slot,ref layout,work.mark,work.base));
}

// Resumable scalar COPY34/ASSIGN38 share the fill cursor and reservation rules.
// Metadata only: source bool validation belongs to array_copy_work::begin.
pub fn Result<filling::State,Error> prepare_copy(ref Table table,u8 op,
    ref layouts::Array layout,Token destination,Token source,usize capacity){
    if(op!=34 && op!=38){return .err(.State);}
    var filling::State work=filling::empty();
    // Match assign admission: reject an unwritable target before the source.
    if(op==38){work=prepare_fill(table,40,layout,destination,capacity)?;}
    let Owner origin=resolve(table,source,capacity)?;
    if(origin.element!=layout.element){return .err(.Type);}
    if(origin.length!=layout.length){return .err(.Length);}
    if(op==34){work=prepare_fill(table,33,layout,destination,capacity)?;}
    let bool same=op==38 && destination.slot==source.slot && destination.generation==source.generation;
    let copying::Mode transfer=switch(copying::prove(work.base,origin.base,layout.bytes,
        if(op==34){work.end}else{table.arena.used},false,0,same)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    work.op=op;work.source_slot=source.slot;work.source_generation=source.generation;
    work.source_base=origin.base;work.source_end=origin.end;
    return .ok(work);
}

// Reauthenticate source, target/reservation, shape, depth and disjointness on
// every chunk. No second cursor/table snapshot and no payload access or rescan.
pub fn Result<usize,Error> validate_copy(ref Table table,ref filling::State work,usize capacity){
    if(!work.active || (work.op!=34 && work.op!=38)){return .err(.State);}
    let layouts::Array layout=switch(layouts::scalar(work.element,work.length)){
        case .ok(a):{a}case .err(_):{return .err(.State);}
    };
    let Owner origin=resolve(table,Token{.slot=work.source_slot,.generation=work.source_generation},capacity)?;
    if(origin.element!=layout.element || origin.length!=layout.length ||
        origin.base!=work.source_base || origin.end!=work.source_end ||
        table.depth!=work.depth || layout.stride!=work.stride){return .err(.State);}
    if(work.op==34){
        let usize slot=free_slot(table)?;
        if(slot!=work.slot || table.slots[slot].generation!=work.generation ||
            table.arena.used!=work.mark){return .err(.State);}
        let layouts::Reservation plan=switch(layouts::reserve(ref layout,work.mark,table.arena.limit)){
            case .ok(p):{p}case .err(_):{return .err(.State);}
        };
        if(plan.offset!=work.base || plan.end!=work.end){return .err(.State);}
    }else{
        let Owner target=writable(table,Token{.slot=work.slot,.generation=work.generation},capacity)?;
        if(target.element!=layout.element || target.length!=layout.length || target.mark!=work.mark ||
            target.base!=work.base || target.end!=work.end){return .err(.State);}
    }
    let bool same=work.op==38 && work.slot==work.source_slot && work.generation==work.source_generation;
    let copying::Mode transfer=switch(copying::prove(work.base,origin.base,layout.bytes,
        if(work.op==34){work.end}else{table.arena.used},false,0,same)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    // begin returns identity inactive; it must never become a write recipe.
    switch(transfer){case .Direct:{}case .NoOp:{return .err(.State);}case .Snapshot:{return .err(.State);}};
    let usize size=work.end-if(work.op==34){work.mark}else{work.base};
    if(work.written>size || work.written>work.total || work.last>work.total){return .err(.State);}
    if(work.element==2 && work.total-work.written<layout.bytes){return .err(.State);}
    return .ok(size);
}

// Completion alone publishes a new COPY owner. ASSIGN retains token/generation.
pub fn Result<Token,Error> publish_copy(ref mut Table table,ref filling::State work,usize capacity){
    let usize size=validate_copy(table,work,capacity)?;
    if(work.written!=size){return .err(.State);}
    if(work.op==38){return .ok(Token{.slot=work.slot,.generation=work.generation});}
    let layouts::Array layout=switch(layouts::scalar(work.element,work.length)){
        case .ok(a):{a}case .err(_):{return .err(.State);}
    };
    table.arena.used=work.end;
    return .ok(publish(table,work.slot,ref layout,work.mark,work.base));
}

pub fn Result<Token, Error> create(ref layouts::Array layout, i64 fill, ref mut u8[] bytes, ref mut Table table) {
    if (!valid(table, bytes.len)) { return .err(.State); }
    let usize slot = free_slot(table)?;
    let usize mark = table.arena.used;
    let usize base = switch (storage::initialize(layout, fill, bytes, ref mut table.arena)) {
        case .ok(value): { value } case .err(e): { return .err(storage_error(e)); }
    };
    return .ok(publish(table, slot, layout, mark, base));
}
// A complete element list is prepared before the owning token is published.
pub fn Result<Token,Error> create_values(ref layouts::Array layout,ref i64[] values,
    ref mut u8[] scratch,ref mut u8[] bytes,ref mut Table table){
    if(!valid(table,bytes.len)){return .err(.State);}
    let usize slot=free_slot(table)?;let usize mark=table.arena.used;
    let usize base=switch(storage::initialize_values(layout,values,scratch,bytes,ref mut table.arena)){
        case .ok(value):{value}case .err(error):{return .err(storage_error(error));}
    };
    return .ok(publish(table,slot,layout,mark,base));
}
pub fn Result<i64, Error> read(ref Table table, Token token, usize index, ref u8[] bytes) {
    let Owner owner = resolve(table, token, bytes.len)?;
    let layouts::Array layout = switch (layouts::scalar(owner.element, owner.length)) {
        case .ok(value): { value } case .err(_): { return .err(.State); }
    };
    return switch (storage::read(ref layout, owner.base, index, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(e): { .err(storage_error(e)) }
    };
}
// Read-only UTF-8 predicate over one exact-shape live u8 array. No cached result.
pub fn Result<bool,Error> utf8_valid(ref Table table,Token token,usize length,ref u8[] bytes){
    let Owner owner=resolve(table,token,bytes.len)?;
    if(owner.element!=10){return .err(.Type);}
    if(owner.length!=length){return .err(.Length);}
    return .ok(text::validate_utf8(bytes[owner.base..owner.end]).is_ok);
}
fn Result<Owner, Error> resolve_view(ref Table table, ref View view, usize capacity) {
    let Owner owner = resolve(table, view.root, capacity)?;
    return view_shape(ref owner, view);
}
// Only private resolvers call this with an authenticated owner from this call.
fn Result<Owner, Error> view_shape(ref Owner owner, ref View view) {
    if (view.element != owner.element) { return .err(.Type); }
    if (view.length != owner.length) { return .err(.Length); }
    if (view.start > view.end || view.end > owner.length) { return .err(.Bounds); }
    return .ok(*owner);
}
pub fn Result<View, Error> view(ref Table table, Token token, usize start, usize end, usize capacity) {
    let Owner owner = resolve(table, token, capacity)?;
    if (start > end || end > owner.length) { return .err(.Bounds); }
    return .ok(View { .root = token, .element = owner.element, .length = owner.length, .start = start, .end = end });
}
pub fn Result<usize, Error> view_length(ref Table table, ref View view, usize capacity) {
    let Owner owner = resolve_view(table, view, capacity)?;
    return .ok(view.end - view.start);
}
pub fn Result<View, Error> subview(ref Table table, ref View parent, usize start, usize end, usize capacity) {
    let Owner owner = resolve_view(table, parent, capacity)?;
    if (start > end || end > parent.end - parent.start) { return .err(.Bounds); }
    return .ok(View { .root = parent.root, .element = parent.element, .length = parent.length,
        .start = parent.start + start, .end = parent.start + end });
}
pub fn Result<i64, Error> view_read(ref Table table, ref View view, usize index, ref u8[] bytes) {
    let Owner owner = resolve_view(table, view, bytes.len)?;
    return read_view_prepared(table, ref owner, view, index, bytes);
}
fn Result<i64, Error> read_view_prepared(ref Table table, ref Owner owner, ref View view, usize index, ref u8[] bytes) {
    if (index >= view.end - view.start) { return .err(.Bounds); }
    let layouts::Array layout = switch (layouts::scalar(owner.element, owner.length)) {
        case .ok(value): { value } case .err(_): { return .err(.State); }
    };
    return switch (storage::read(ref layout, owner.base, view.start + index, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(e): { .err(storage_error(e)) }
    };
}
pub fn Result<bool, Error> view_utf8(ref Table table, ref View view, ref u8[] bytes) {
    let Owner owner = resolve_view(table, view, bytes.len)?;
    return utf8_view_prepared(ref owner, view, bytes);
}
fn Result<bool, Error> utf8_view_prepared(ref Owner owner, ref View view, ref u8[] bytes) {
    if (owner.element != 10) { return .err(.Type); }
    // Valid u8 layout proves both additions are bounded by the initialized end.
    return .ok(text::validate_utf8(bytes[owner.base + view.start..owner.base + view.end]).is_ok);
}
// Rehoming a unique owner needs no allocation or payload write. Validate its
// exact shape and all bool bytes before a caller publishes the existing token.
pub fn Result<usize,Error> validate_result(ref Table table,Token token,u8 element,usize length,ref u8[] bytes) {
    let Owner owner=writable(table,token,bytes.len)?;
    if(owner.element!=element) {return .err(.Type);}
    if(owner.length!=length) {return .err(.Length);}
    if(element==2) {
        var usize at=owner.base;
        while(at<owner.end) {if(bytes[at]>1) {return .err(.Value);}at+=1;}
    }
    return .ok(owner.end-owner.base);
}
// Validate the entire extent and encode once before the first write. Owner and
// arena metadata remain immutable, including when every descriptor is occupied.
pub fn Result<usize,Error> fill(ref Table table,Token token,i64 cell,ref mut u8[] bytes) {
    let Owner owner=writable(table,token,bytes.len)?;
    let layouts::Array layout=switch(layouts::scalar(owner.element,owner.length)) {
        case .ok(a):{a}case .err(_):{return .err(.State);}
    };
    var u8[8] encoded=[0;8];
    let usize size=switch(codec::encode(owner.element,cell,ref mut encoded[..layout.stride])) {
        case .ok(n):{n}case .err(e):{return .err(switch(e){case .Type:{.Type}case .Width:{.Metadata}case .Value:{.Value}});}
    };
    var usize at=owner.base;
    while(at<owner.end) {
        var usize byte=0;
        while(byte<size){bytes[at+byte]=encoded[byte];byte+=1;}
        at+=size;
    }
    return .ok(layout.bytes);
}
// Exact shape and writable ownership precede complete scalar staging. Neither
// success nor failure changes tokens, epochs, allocation order or the arena.
pub fn Result<usize,Error> replace_values(ref layouts::Array layout,Token destination,ref i64[] values,
    ref mut u8[] scratch,ref mut u8[] bytes,ref Table table){
    let Owner target=writable(table,destination,bytes.len)?;
    if(target.element!=layout.element){return .err(.Type);}
    if(target.length!=layout.length){return .err(.Length);}
    return switch(storage::replace_values(layout,target.base,values,scratch,bytes,ref table.arena)){
        case .ok(size):{.ok(size)}case .err(error):{.err(storage_error(error))}
    };
}
pub fn Result<usize, Error> write(ref Table table, Token token, usize index, i64 cell, ref mut u8[] bytes) {
    let Owner owner = writable(table, token, bytes.len)?;
    let layouts::Array layout = switch (layouts::scalar(owner.element, owner.length)) {
        case .ok(value): { value } case .err(_): { return .err(.State); }
    };
    return switch (storage::write(ref layout, owner.base, index, cell, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(e): { .err(storage_error(e)) }
    };
}

// Copy into a fresh, nonoverlapping extent. Validate the entire bool source and
// all destination limits before changing either payload bytes or owner state.
pub fn Result<Token, Error> copy(Token source, ref mut u8[] bytes, ref mut Table table) {
    let Owner owner = resolve(table, source, bytes.len)?;
    let usize slot = free_slot(table)?;
    let layouts::Array layout = switch (layouts::scalar(owner.element, owner.length)) {
        case .ok(value): { value } case .err(_): { return .err(.State); }
    };
    let usize mark = table.arena.used;
    let layouts::Reservation plan = switch (layouts::reserve(ref layout, mark, table.arena.limit)) {
        case .ok(value): { value }
        case .err(e): { return .err(switch (e) {
            case .Type: { .Type } case .Length: { .Length } case .Metadata: { .Metadata }
            case .Overflow: { .Overflow } case .Quota: { .Quota } case .Bounds: { .Bounds }
            case .Alignment: { .Alignment }
        }); }
    };
    let copying::Mode transfer=switch(copying::prove(plan.offset,owner.base,layout.bytes,plan.end,false,0,false)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    if (owner.element == 2) {
        var usize at = owner.base;
        while (at < owner.end) {
            if (bytes[at] > 1) { return .err(.Value); }
            at += 1;
        }
    }
    var usize at = mark;
    while (at < plan.offset) { bytes[at] = 0; at += 1; }
    var usize i = 0;
    while (i < layout.bytes) {
        let u8 byte = bytes[owner.base + i];
        bytes[plan.offset + i] = byte;
        i += 1;
    }
    table.arena.used = plan.end;
    return .ok(publish(table, slot, ref layout, mark, plan.offset));
}
fn usize next_generation(usize generation) {
    return if (generation == 18446744073709551615) { 0 } else { generation + 1 };
}

// Private call-storage foundation. All fallible work precedes payload mutation;
// only a complete batch publishes owners. Resolve sources against the original
// table, so no argument can refer to another argument's provisional destination.
pub fn Result<Copies, Error> copy_arguments(ref Token[] sources, ref layouts::Array[] shapes,
    ref mut u8[] bytes, ref mut Table table) {
    if (sources.len > 8 || sources.len != shapes.len) { return .err(.Metadata); }
    if (!valid(table, bytes.len)) { return .err(.State); }
    var Table planned = Table { .slots = table.slots, .order = table.order,
        .depth = table.depth, .arena = table.arena };
    var Copies result = Copies { .tokens = [Token { .slot = 0, .generation = 0 }; 8], .count = sources.len };
    var usize[8] origins = [0; 8];
    var usize[8] targets = [0; 8];
    var usize[8] marks = [0; 8];
    var usize[8] sizes = [0; 8];
    var usize i = 0;
    while (i < sources.len) {
        let Owner owner = lookup(table, sources[i])?;
        if (owner.writing) { return .err(.State); }
        if (owner.element == 0) { return .err(.Type); }
        let layouts::Array shape = shapes[i];
        if (owner.element != shape.element) { return .err(.Type); }
        if (owner.length != shape.length) { return .err(.Length); }
        let usize slot = free_slot(ref planned)?;
        let usize mark = planned.arena.used;
        let layouts::Reservation plan = switch (layouts::reserve(ref shape, mark, planned.arena.limit)) {
            case .ok(value): { value }
            case .err(e): { return .err(switch (e) {
                case .Type: { .Type } case .Length: { .Length } case .Metadata: { .Metadata }
                case .Overflow: { .Overflow } case .Quota: { .Quota } case .Bounds: { .Bounds }
                case .Alignment: { .Alignment }
            }); }
        };
        if (owner.element == 2) {
            var usize at = owner.base;
            while (at < owner.end) {
                if (bytes[at] > 1) { return .err(.Value); }
                at += 1;
            }
        }
        let copying::Mode transfer=switch(copying::prove(plan.offset,owner.base,shape.bytes,plan.end,false,0,false)){
            case .ok(v):{v}case .err(_):{return .err(.State);}
        };
        origins[i] = owner.base; targets[i] = plan.offset;
        marks[i] = mark; sizes[i] = shape.bytes;
        planned.arena.used = plan.end;
        result.tokens[i] = publish(ref mut planned, slot, ref shape, mark, plan.offset);
        i += 1;
    }
    // Reservations are disjoint and lie beyond every original source extent.
    // No validation, allocation, callback, or recoverable failure follows here.
    i = 0;
    while (i < sources.len) {
        var usize at = marks[i];
        while (at < targets[i]) { bytes[at] = 0; at += 1; }
        var usize byte = 0;
        while (byte < sizes[i]) {
            bytes[targets[i] + byte] = bytes[origins[i] + byte];
            byte += 1;
        }
        i += 1;
    }
    table.slots = planned.slots; table.order = planned.order;
    table.depth = planned.depth; table.arena = planned.arena;
    return .ok(result);
}

// Preflight one mixed array/record transaction against the original table.
// Record snapshots normalize padding and validate every nested bool before any
// backing write. Only the complete batch publishes tokens and arena metadata.
pub fn Result<Copies, Error> copy_call_arguments(ref records::Catalog catalog,
    ref CallArgument[] arguments, ref mut u8[] bytes, ref mut Table table) {
    if (arguments.len > 8) { return .err(.Metadata); }
    if (!valid(table, bytes.len)) { return .err(.State); }
    var Table planned = Table { .slots = table.slots, .order = table.order,
        .depth = table.depth, .arena = table.arena };
    var Copies result = Copies { .tokens = [Token { .slot = 0, .generation = 0 }; 8], .count = arguments.len };
    var u8[1024] snapshots = [0; 1024];
    var usize[8] origins = [0; 8]; var usize[8] targets = [0; 8];
    var usize[8] marks = [0; 8]; var usize[8] sizes = [0; 8];
    var usize i = 0;
    while (i < arguments.len) {
        let CallArgument argument = arguments[i];
        let Owner owner = lookup(table, argument.source)?;
        if (owner.writing) { return .err(.State); }
        if (owner.element != argument.element) { return .err(.Type); }
        if (argument.element == 0) {
            if (argument.length != 0) { return .err(.Metadata); }
            if (owner.record != argument.record) { return .err(.Type); }
            let record_storage::Binding binding = record_storage::Binding { .bytes = owner.length, .alignment = owner.alignment };
            let usize staged = switch (record_storage::snapshot_into_bound(catalog, owner.record, owner.base,
                binding, bytes, ref table.arena, ref mut snapshots[i * 128..i * 128 + owner.length])) {
                case .ok(n): { n } case .err(e): { return .err(record_error(e)); }
            };
        } else {
            if (argument.record != 0) { return .err(.Metadata); }
            if (owner.length != argument.length) { return .err(.Length); }
            if (owner.element == 2) {
                var usize at = owner.base;
                while (at < owner.end) { if (bytes[at] > 1) { return .err(.Value); } at += 1; }
            }
        }
        let layouts::Array layout = allocation_layout(ref owner)?;
        let usize slot = free_slot(ref planned)?;
        let usize mark = planned.arena.used;
        let layouts::Reservation reservation = switch (layouts::reserve(ref layout, mark, planned.arena.limit)) {
            case .ok(p): { p } case .err(e): { return .err(switch (e) {
                case .Type: { .Type } case .Length: { .Length } case .Metadata: { .Metadata }
                case .Overflow: { .Overflow } case .Quota: { .Quota } case .Bounds: { .Bounds }
                case .Alignment: { .Alignment }
            }); }
        };
        let copying::Mode transfer=switch(copying::prove(reservation.offset,owner.base,layout.bytes,reservation.end,false,0,false)){
            case .ok(v):{v}case .err(_):{return .err(.State);}
        };
        origins[i] = owner.base; targets[i] = reservation.offset;
        marks[i] = mark; sizes[i] = layout.bytes;
        planned.arena.used = reservation.end;
        if (argument.element == 0) {
            result.tokens[i] = publish_record(ref mut planned, slot, owner.record,
                owner.length, owner.alignment, mark, reservation.offset);
        } else { result.tokens[i] = publish(ref mut planned, slot, ref layout, mark, reservation.offset); }
        i += 1;
    }
    // Every destination follows the original published prefix. Sources cannot
    // alias a destination, including repeated arguments and provisional slots.
    i = 0;
    while (i < arguments.len) {
        var usize at = marks[i];
        while (at < targets[i]) { bytes[at] = 0; at += 1; }
        var usize byte = 0;
        while (byte < sizes[i]) {
            bytes[targets[i] + byte] = if (arguments[i].element == 0) {
                snapshots[i * 128 + byte]
            } else { bytes[origins[i] + byte] };
            byte += 1;
        }
        i += 1;
    }
    table.slots = planned.slots; table.order = planned.order;
    table.depth = planned.depth; table.arena = planned.arena;
    return .ok(result);
}

// Replace an existing extent. Resolve both tokens and validate the full bool
// source before the first write; valid owners are disjoint unless identical.
pub fn Result<usize, Error> assign(Token destination, Token source, ref mut u8[] bytes, ref Table table) {
    let Owner target = writable(table, destination, bytes.len)?;
    let Owner origin = resolve(table, source, bytes.len)?;
    if (target.element != origin.element) { return .err(.Type); }
    if (target.length != origin.length) { return .err(.Length); }
    if (origin.element == 2) {
        var usize at = origin.base;
        while (at < origin.end) {
            if (bytes[at] > 1) { return .err(.Value); }
            at += 1;
        }
    }
    let usize size = origin.end - origin.base;
    let bool same=destination.slot==source.slot && destination.generation==source.generation;
    let copying::Mode transfer=switch(copying::prove(target.base,origin.base,size,table.arena.used,false,0,same)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    switch(transfer){case .NoOp:{return .ok(size);}case .Direct:{}case .Snapshot:{return .err(.State);}};
    var usize i = 0;
    while (i < size) { bytes[target.base + i] = bytes[origin.base + i]; i += 1; }
    return .ok(size);
}
fn void forget(ref mut Table table, usize slot) {
    table.slots[slot].occupied = false;
    table.slots[slot].live = false;
    table.slots[slot].reading = false; table.slots[slot].writing = false; table.slots[slot].read_generation = 1;
    table.slots[slot].mark = 0; table.slots[slot].base = 0; table.slots[slot].end = 0;
    table.slots[slot].element = 0; table.slots[slot].length = 0;
    table.slots[slot].record = 0; table.slots[slot].alignment = 0;
}
pub fn Result<usize, Error> release(ref mut Table table, Token token, usize capacity) {
    let Owner owner = resolve_any(table, token, capacity)?;
    if (owner.reading || owner.writing) { return .err(.State); }
    let usize before = table.arena.used;
    table.slots[token.slot].live = false;
    table.slots[token.slot].generation = next_generation(owner.generation);
    while (table.depth > 0) {
        let usize top = table.order[table.depth - 1];
        if (table.slots[top].live) { break; }
        table.arena.used = table.slots[top].mark;
        forget(table, top);
        let usize last = table.depth - 1;
        table.order[last] = 0;
        table.depth -= 1;
    }
    return .ok(before - table.arena.used);
}
pub fn Result<usize, Error> clear(ref mut Table table, usize capacity) {
    if (!valid(table, capacity)) { return .err(.State); }
    var usize checked = 0;
    while (checked < 16) { if (table.slots[checked].reading || table.slots[checked].writing) { return .err(.State); } checked += 1; }
    let usize before = table.arena.used;
    var usize i = 0;
    while (i < 16) {
        if (table.slots[i].live) {
            let usize next = next_generation(table.slots[i].generation);
            table.slots[i].generation = next;
        }
        forget(table, i);
        table.order[i] = 0;
        i += 1;
    }
    table.depth = 0; table.arena.used = 0;
    return .ok(before);
}

// Record owners share the same slots, arena, generations and release order as
// arrays. Bind one immutable catalog and backing region to the table lifetime.
fn Error record_error(record_storage::Error error) {
    return switch (error) {
        case .Layout: { .Metadata } case .Bounds: { .Bounds } case .Fields: { .Length }
        case .State: { .State } case .Alignment: { .Alignment } case .Quota: { .Quota }
        case .Overflow: { .Overflow } case .Value: { .Value } case .Type: { .Type }
    };
}
pub fn Result<Token, Error> create_record(ref records::Catalog catalog, usize record,
    ref i64[] fields, ref mut u8[] bytes, ref mut Table table) {
    if (!valid(table, bytes.len)) { return .err(.State); }
    let usize slot = free_slot(table)?;
    let usize mark = table.arena.used;
    let record_storage::Initialized created = switch (record_storage::initialize_described(catalog, record, fields, bytes, ref mut table.arena)) {
        case .ok(value): { value } case .err(error): { return .err(record_error(error)); }
    };
    return .ok(publish_record(table, slot, record, created.size, created.alignment, mark, created.base));
}
// Record initialization/copy have completed every fallible operation.
fn Token publish_record(ref mut Table table, usize slot, usize record, usize bytes,
    usize alignment, usize mark, usize base) {
    let usize generation = table.slots[slot].generation;
    let usize end = table.arena.used;
    let usize depth = table.depth;
    table.slots[slot] = Owner { .generation = generation, .occupied = true, .live = true,
        .reading = false, .writing = false, .read_generation = 1,
        .mark = mark, .base = base, .end = end, .element = 0,
        .length = bytes, .record = record, .alignment = alignment };
    table.order[depth] = slot;
    table.depth += 1;
    return Token { .slot = slot, .generation = generation };
}

// Metadata authentication only; the returned copy does not grant write authority.
// Native selected places use the same immutable catalog/table/backing lifetime.
// The checked storage boundary must still authenticate catalog and owner shape.
pub fn Result<Owner, Error> inspect_record_owner(ref Table table, Token token, usize capacity) {
    let Owner owner = resolve_any(table, token, capacity)?;
    if (owner.element != 0) { return .err(.Type); }
    return .ok(owner);
}
pub fn Result<Owner, Error> resolve_record(ref records::Catalog catalog, ref Table table,
    Token token, usize capacity) {
    let Owner owner = resolve_any(table, token, capacity)?;
    let usize checked = record_metadata(catalog, ref owner)?;
    return .ok(owner);
}
// Layout checks are independent of token/table validation. Batch callers have
// already resolved this owner against the fully validated original table.
fn Result<usize, Error> record_metadata(ref records::Catalog catalog, ref Owner owner) {
    if (owner.element != 0) { return .err(.Type); }
    let records::Plan plan = switch (records::plan(catalog, 18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(.Metadata); }
    };
    return record_metadata_prepared(ref plan,owner);
}
// Private composition only: plan was built from the exact immutable catalog
// in this call. Owner identity/table validation remains the caller's job.
fn Result<usize, Error> record_metadata_prepared(ref records::Plan plan, ref Owner owner) {
    if (owner.element != 0) { return .err(.Type); }
    if (owner.record >= plan.count) { return .err(.Metadata); }
    if (plan.bytes[owner.record] != owner.length || plan.alignments[owner.record] != owner.alignment) {
        return .err(.Metadata);
    }
    return .ok(owner.length);
}
pub fn Result<i64, Error> read_record(ref records::Catalog catalog, ref Table table,
    Token token, ref usize[] path, ref u8[] bytes) {
    let Owner owner = resolve_any(table, token, bytes.len)?;
    if(owner.element!=0){return .err(.Type);}
    let record_storage::Binding binding=record_storage::Binding{.bytes=owner.length,.alignment=owner.alignment};
    return switch (record_storage::read_bound(catalog, owner.record, owner.base, binding, path, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(error): { .err(record_error(error)) }
    };
}
// Validate a unique nominal result without reserving or writing payload. The
// checked storage validator authenticates shape/nominal identity and nested
// bools without copying integer bytes or normalizing discarded scratch.
pub fn Result<usize, Error> validate_record_result(ref records::Catalog catalog,
    ref Table table, Token token, usize nominal, ref u8[] bytes) {
    let Owner owner = resolve_any(table, token, bytes.len)?;
    if (owner.element != 0) { return .err(.Type); }
    let record_storage::Binding binding = record_storage::Binding { .bytes = owner.length, .alignment = owner.alignment };
    return switch (record_storage::validate_result(catalog, owner.record, owner.base,
        binding, nominal, bytes, ref table.arena)) {
        case .ok(n): { .ok(n) } case .err(e): { .err(record_error(e)) }
    };
}
pub fn Result<usize, Error> write_record(ref records::Catalog catalog, ref Table table,
    Token token, ref usize[] path, i64 value, ref mut u8[] bytes) {
    let Owner owner = resolve_any(table, token, bytes.len)?;
    if(owner.element!=0){return .err(.Type);}
    let record_storage::Binding binding=record_storage::Binding{.bytes=owner.length,.alignment=owner.alignment};
    return switch (record_storage::write_bound(catalog, owner.record, owner.base, binding, path, value, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(error): { .err(record_error(error)) }
    };
}

// Copy the exact descriptor-bound record into one new shared owner. The old
// owner/bytes remain live and charged until explicitly released.
pub fn Result<Token, Error> copy_record(ref records::Catalog catalog, Token source,
    ref mut u8[] bytes, ref mut Table table) {
    let Owner owner = resolve_record(catalog, table, source, bytes.len)?;
    let usize slot = free_slot(table)?;
    let usize mark = table.arena.used;
    let usize base = switch (record_storage::copy(catalog, owner.record, owner.base, bytes, ref mut table.arena)) {
        case .ok(value): { value } case .err(error): { return .err(record_error(error)); }
    };
    return .ok(publish_record(table, slot, owner.record, owner.length, owner.alignment, mark, base));
}
// Exact record identity is required even when two declared records have the same
// physical layout. Assignment never reserves an owner/extent or changes tokens.
pub fn Result<usize, Error> assign_record(ref records::Catalog catalog, Token destination,
    Token source, ref mut u8[] bytes, ref Table table) {
    let Owner target = inspect_record_owner(table,destination,bytes.len)?;
    let records::Plan plan = switch (records::plan(catalog,18446744073709551615)) {
        case .ok(p): { p } case .err(_): { return .err(.Metadata); }
    };
    let usize target_checked = record_metadata_prepared(ref plan,ref target)?;
    // Destination admission proved the complete immutable table. Reuse that
    // validation and this fresh plan while still checking source identity/shape.
    let Owner origin = record_owner_prepared(table,ref plan,source)?;
    if (target.record != origin.record) { return .err(.Type); }
    return switch (record_storage::assign(catalog, origin.record, target.base, origin.base, bytes, ref table.arena)) {
        case .ok(value): { .ok(value) } case .err(error): { .err(record_error(error)) }
    };
}

// Both whole owners and exact nominal child ranges are checked before snapshot.
// Exact nominal scalar values replace an existing root without a second owner.
// The table is read-only; callers establish mutability and prepay VM work.
pub fn Result<usize, Error> replace_record(ref records::Catalog catalog, Token destination,
    usize nominal, ref i64[] fields, ref mut u8[] bytes, ref Table table) {
    let Owner target = inspect_record_owner(table,destination,bytes.len)?;
    let record_storage::Binding binding = record_storage::Binding { .bytes = target.length, .alignment = target.alignment };
    return switch (record_storage::replace_record_bound(catalog,target.record,target.base,
        binding,nominal,fields,bytes,ref table.arena)) {
        case .ok(n): { .ok(n) } case .err(error): { .err(record_error(error)) }
    };
}

// Storage assignment stages canonical scalar bytes before its first target write.
pub fn Result<usize, Error> assign_subrecord(ref records::Catalog catalog,
    Token destination, Token source, usize nominal, usize target_leaf, usize source_leaf,
    ref mut u8[] bytes, ref Table table) {
    let Owner target = resolve_any(table,destination,bytes.len)?;
    if (target.element != 0) { return .err(.Type); }
    let records::Plan plan = switch (records::plan(catalog,18446744073709551615)) {
        case .ok(p): { p } case .err(_): { return .err(.Metadata); }
    };
    let usize target_checked = record_metadata_prepared(ref plan,ref target)?;
    // Destination admission already validated the complete immutable table.
    let Owner origin = record_owner_prepared(table,ref plan,source)?;
    // Both owners and nominal paths share this local plan; raw assignment below
    // still independently validates storage before snapshotting or writing.
    let usize target_offset = switch(record_range::offset_prepared(catalog,ref plan,target.record,nominal,target_leaf)) {
        case .ok(n): { n } case .err(_): { return .err(.Type); }
    };
    let usize source_offset = switch(record_range::offset_prepared(catalog,ref plan,origin.record,nominal,source_leaf)) {
        case .ok(n): { n } case .err(_): { return .err(.Type); }
    };
    if (target_offset > target.length || source_offset > origin.length) { return .err(.Bounds); }
    return switch(record_storage::assign(catalog,nominal,target.base+target_offset,
        origin.base+source_offset,bytes,ref table.arena)) {
        case .ok(n): { .ok(n) } case .err(e): { .err(record_error(e)) }
    };
}

// Resolve authority over the whole root and exact nominal child range before
// encoding all replacement values. Only selected bytes (including padding) publish.
pub fn Result<usize, Error> replace_subrecord(ref records::Catalog catalog,
    Token destination, usize nominal, usize target_leaf, ref i64[] fields,
    ref mut u8[] bytes, ref Table table) {
    let Owner target = inspect_record_owner(table,destination,bytes.len)?;
    let record_storage::Binding binding = record_storage::Binding { .bytes = target.length, .alignment = target.alignment };
    return switch(record_storage::replace_subrecord_bound(catalog,target.record,target.base,
        binding,nominal,target_leaf,fields,bytes,ref table.arena)) {
        case .ok(n): { .ok(n) } case .err(e): { .err(record_error(e)) }
    };
}

// Transient checked byte windows, never a second cursor or ownership proof.
// target/source select the nominal subtree; cursor extents always retain roots.
pub struct RecordWork { usize target; usize source; usize size; usize bytes; }
// Private composition after complete table validation, using one fresh plan
// for the exact catalog. Neither table nor catalog changes before this lookup.
fn Result<Owner,Error> record_owner_prepared(ref Table table,ref records::Plan plan,Token token){
    let Owner owner=lookup(table,token)?;
    let usize checked=record_metadata_prepared(plan,ref owner)?;
    return .ok(owner);
}
fn Result<usize,Error> record_offset_prepared(ref records::Catalog catalog,ref records::Plan plan,
    usize root,usize nominal,usize ordinal,bool whole){
    if(whole){
        if(root!=nominal || ordinal!=0){return .err(.Type);}
        return .ok(0);
    }
    return switch(record_range::offset_prepared(catalog,plan,root,nominal,ordinal)){
        case .ok(n):{.ok(n)}case .err(_):{.err(.Type)}
    };
}
fn Result<RecordWork,Error> record_window_prepared(ref records::Catalog catalog,ref records::Plan plan,
    ref filling::State work){
    let usize size=plan.bytes[work.nominal];
    let usize selected=record_offset_prepared(catalog,plan,work.record,work.nominal,
        work.ordinal,work.op!=47 && work.op!=49)?;
    if(selected>work.length || size>work.length-selected){return .err(.Bounds);}
    var usize source=0;
    if(work.op==42 || work.op==46 || work.op==47){
        let usize origin=record_offset_prepared(catalog,plan,work.source_record,work.nominal,
            work.source_ordinal,work.op!=47)?;
        let usize length=work.source_end-work.source_base;
        if(origin>length || size>length-origin){return .err(.Bounds);}
        source=work.source_base+origin;
    }
    return .ok(RecordWork{.target=work.base+selected,.source=source,.size=size,
        .bytes=if(work.op==41 || work.op==42){work.end-work.mark}else{size}});
}
// Caller has planned this exact immutable catalog. Table validation covers all
// root extents/order/loans before private lookup or reservation arithmetic.
fn Result<filling::State,Error> prepare_record_prepared(ref records::Catalog catalog,
    ref records::Plan plan,ref Table table,u8 op,usize nominal,Token target,Token source,
    usize target_ordinal,usize source_ordinal,usize capacity){
    if(op!=41 && op!=42 && op!=46 && op!=47 && op!=48 && op!=49){return .err(.State);}
    if(!valid(table,capacity)){return .err(.State);}
    if(nominal>=plan.count){return .err(.Bounds);}
    if(plan.bytes[nominal]>128){return .err(.Quota);}
    if(op!=47 && op!=49 && (target_ordinal!=0 || source_ordinal!=0)){return .err(.Type);}
    if(op==49 && source_ordinal!=0){return .err(.Type);}
    var filling::State work=filling::empty();
    work.active=true;work.op=op;work.nominal=nominal;work.ordinal=target_ordinal;
    work.depth=table.depth;
    if(op==42){
        // Match atomic copy_record: authenticate the source and nominal type
        // before an owner-slot or arena reservation can fail.
        let Owner origin=record_owner_prepared(table,plan,source)?;
        if(origin.record!=nominal){return .err(.Type);}
        work.source_slot=source.slot;work.source_generation=source.generation;
        work.source_base=origin.base;work.source_end=origin.end;
        work.source_record=origin.record;work.source_ordinal=source_ordinal;
    }
    if(op==41 || op==42){
        work.slot=free_slot(table)?;work.generation=table.slots[work.slot].generation;
        work.record=nominal;work.length=plan.bytes[nominal];work.stride=plan.alignments[nominal];
        work.mark=table.arena.used;
        let usize remainder=work.mark%work.stride;
        let usize padding=if(remainder==0){0}else{work.stride-remainder};
        let usize maximum=18446744073709551615;
        if(padding>maximum-work.mark){return .err(.Overflow);}
        work.base=work.mark+padding;
        if(work.length>maximum-work.base){return .err(.Overflow);}
        work.end=work.base+work.length;
        if(work.end>table.arena.limit){return .err(.Quota);}
    }else{
        let Owner owner=record_owner_prepared(table,plan,target)?;
        work.slot=target.slot;work.generation=target.generation;
        work.mark=owner.mark;work.base=owner.base;work.end=owner.end;
        work.record=owner.record;work.length=owner.length;work.stride=owner.alignment;
    }
    if(op==46 || op==47){
        let Owner origin=record_owner_prepared(table,plan,source)?;
        work.source_slot=source.slot;work.source_generation=source.generation;
        work.source_base=origin.base;work.source_end=origin.end;
        work.source_record=origin.record;work.source_ordinal=source_ordinal;
    }
    let RecordWork window=record_window_prepared(catalog,plan,ref work)?;
    if(op==42 || op==46 || op==47){
        // Always snapshot, including exact identity; padding must normalize.
        let copying::Mode transfer=switch(copying::prove(window.target,window.source,window.size,
            if(op==42){work.end}else{table.arena.used},true,128,false)){
            case .ok(v):{v}case .err(_):{return .err(.State);}
        };
    }
    return .ok(work);
}
// Reservation/metadata admission only. No payload, owner publication or arena
// mutation. The parent freezes other guest operations and pins every input.
pub fn Result<filling::State,Error> prepare_record(ref records::Catalog catalog,ref Table table,
    u8 op,usize nominal,Token target,Token source,usize target_ordinal,usize source_ordinal,usize capacity){
    let records::Plan plan=switch(records::plan(catalog,18446744073709551615)){
        case .ok(p):{p}case .err(_):{return .err(.Metadata);}
    };
    return prepare_record_prepared(catalog,ref plan,table,op,nominal,target,source,
        target_ordinal,source_ordinal,capacity);
}
// Reauthenticate every saved root, generation, reservation and nominal subtree.
// Only metadata is revisited; staged scalar bytes are never read or reencoded.
pub fn Result<RecordWork,Error> validate_record_work(ref records::Catalog catalog,
    ref Table table,ref filling::State work,usize capacity){
    if(!work.active || work.element!=0 || work.list_gathered!=0 || work.list_encoded!=0){return .err(.State);}
    let records::Plan plan=switch(records::plan(catalog,18446744073709551615)){
        case .ok(p):{p}case .err(_):{return .err(.Metadata);}
    };
    let filling::State current=prepare_record_prepared(catalog,ref plan,table,work.op,work.nominal,
        Token{.slot=work.slot,.generation=work.generation},
        Token{.slot=work.source_slot,.generation=work.source_generation},
        work.ordinal,work.source_ordinal,capacity)?;
    if(current.slot!=work.slot || current.generation!=work.generation || current.depth!=work.depth ||
        current.mark!=work.mark || current.base!=work.base || current.end!=work.end ||
        current.record!=work.record || current.length!=work.length || current.stride!=work.stride ||
        current.source_slot!=work.source_slot || current.source_generation!=work.source_generation ||
        current.source_record!=work.source_record || current.source_ordinal!=work.source_ordinal ||
        current.source_base!=work.source_base || current.source_end!=work.source_end){return .err(.State);}
    let RecordWork window=record_window_prepared(catalog,ref plan,ref current)?;
    if(work.written>window.bytes || work.written>work.total || work.last>work.total){return .err(.State);}
    // The fresh plan above still covers this immutable catalog. Share it only
    // within this validation; the next chunk must authenticate metadata again.
    let record_storage::Staging staging=switch(record_storage::staging_prepared(catalog,ref plan,work.nominal)){
        case .ok(s):{s}case .err(e):{return .err(record_error(e));}
    };
    let usize admission=staging.size+staging.scalar_bytes+
        if(work.op==41 || work.op==48 || work.op==49){8*staging.leaves}else{staging.bools};
    if(work.total-work.written<admission){return .err(.State);}
    return .ok(window);
}
// No publication until the final selected/padding byte has been written.
// Existing roots keep their tokens, extent, order and arena prefix unchanged.
pub fn Result<Token,Error> publish_record_work(ref records::Catalog catalog,ref mut Table table,
    ref filling::State work,usize capacity){
    let RecordWork window=validate_record_work(catalog,table,work,capacity)?;
    if(work.written!=window.bytes){return .err(.State);}
    if(work.op!=41 && work.op!=42){return .ok(Token{.slot=work.slot,.generation=work.generation});}
    table.arena.used=work.end;
    return .ok(publish_record(table,work.slot,work.record,work.length,work.stride,work.mark,work.base));
}

// Transient CALL metadata only. A source-valid range may have no reservation:
// checked includes that source, whereas copies.count includes only destinations
// successfully reserved. failure is deferred until phase 0 reaches that argument
// and (for a reservation failure) validates its bools. This preserves the atomic
// mixed API's source/shape/bools/free-slot/reservation diagnostic order.
pub struct CallCopyRange { usize source; usize target; usize mark; usize end; usize size; }
pub struct CallCopyPlan {
    Table planned; Copies copies; CallCopyRange[8] ranges;
    usize mark; usize depth; usize checked; Option<Error> failure;
}
fn Result<Owner,Error> call_copy_source(ref Table table,ref records::Catalog catalog,
    CallArgument argument){
    let Owner owner=lookup(table,argument.source)?;
    if(owner.writing){return .err(.State);}
    if(owner.element!=argument.element){return .err(.Type);}
    if(argument.element==0){
        if(argument.length!=0){return .err(.Metadata);}
        if(owner.record!=argument.record){return .err(.Type);}
        let usize checked=record_metadata(catalog,ref owner)?;
    }else{
        if(argument.record!=0){return .err(.Metadata);}
        if(owner.length!=argument.length){return .err(.Length);}
    }
    return .ok(owner);
}
fn Result<Token,Error> call_copy_target(ref mut Table planned,ref Owner owner){
    let layouts::Array layout=allocation_layout(owner)?;
    let usize slot=free_slot(planned)?;
    let usize mark=planned.arena.used;
    let layouts::Reservation reservation=switch(layouts::reserve(ref layout,mark,planned.arena.limit)){
        case .ok(p):{p}case .err(e):{return .err(switch(e){
            case .Type:{.Type}case .Length:{.Length}case .Metadata:{.Metadata}
            case .Overflow:{.Overflow}case .Quota:{.Quota}case .Bounds:{.Bounds}
            case .Alignment:{.Alignment}
        });}
    };
    // All destinations follow the ORIGINAL prefix. This is stronger than just
    // pairwise argument disjointness and permits repeated original sources.
    let copying::Mode transfer=switch(copying::prove(reservation.offset,owner.base,
        layout.bytes,reservation.end,false,0,false)){
        case .ok(v):{v}case .err(_):{return .err(.State);}
    };
    planned.arena.used=reservation.end;
    if(owner.element==0){return .ok(publish_record(planned,slot,owner.record,
        owner.length,owner.alignment,mark,reservation.offset));}
    return .ok(publish(planned,slot,ref layout,mark,reservation.offset));
}

// Only top-level arity/table errors escape immediately. Later argument errors
// are facts in this transient prefix plan, NEVER eager errors masking an earlier
// invalid bool. Resolve every source against table, not the provisional planned
// table. No payload read/write, allocation, publication or caller mutation.
// Metadata scans/planning remain atomic; bounding them belongs to future R03.
pub fn Result<CallCopyPlan,Error> plan_call_copy(ref Table table,ref records::Catalog catalog,
    ref CallArgument[] arguments,usize capacity){
    if(arguments.len>8){return .err(.Metadata);}
    if(!valid(table,capacity)){return .err(.State);}
    var Table planned=Table{.slots=table.slots,.order=table.order,.depth=table.depth,.arena=table.arena};
    var Copies copies=Copies{.tokens=[Token{.slot=0,.generation=0};8],.count=0};
    var CallCopyRange[8] ranges=[CallCopyRange{.source=0,.target=0,.mark=0,.end=0,.size=0};8];
    let usize original_mark=table.arena.used;var usize checked=0;
    var Option<Error> failure=.none;var usize i=0;
    while(i<arguments.len){
        var Owner owner=table.slots[0];
        switch(call_copy_source(table,catalog,arguments[i])){
            case .ok(o):{owner=o;}case .err(e):{failure=.some(e);break;}
        };
        // valid(table) bounds every original source by this immutable prefix.
        if(owner.end>original_mark){failure=.some(.State);break;}
        ranges[i]=CallCopyRange{.source=owner.base,.target=0,.mark=0,.end=0,.size=owner.end-owner.base};
        checked=i+1;
        let usize mark=planned.arena.used;
        var Token token=Token{.slot=0,.generation=0};
        switch(call_copy_target(ref mut planned,ref owner)){
            case .ok(t):{token=t;}case .err(e):{failure=.some(e);break;}
        };
        let Owner target=planned.slots[token.slot];
        ranges[i]=CallCopyRange{.source=owner.base,.target=target.base,.mark=mark,.end=target.end,.size=owner.end-owner.base};
        copies.tokens[i]=token;copies.count+=1;i+=1;
    }
    return .ok(CallCopyPlan{.planned=planned,.copies=copies,.ranges=ranges,
        .mark=original_mark,.depth=table.depth,.checked=checked,.failure=failure});
}

// Capture only compact comparison facts; no transient planned Table is retained.
// Unreserved targets remain zero. Even invalid source descriptors are captured
// verbatim so their error can be reported at the correct phase-0 position.
pub fn Result<calling::State,Error> capture_call_copy(ref CallCopyPlan plan,ref CallArgument[] arguments){
    if(arguments.len>8 || plan.checked>arguments.len || plan.copies.count>plan.checked){return .err(.State);}
    var calling::State work=calling::empty();
    work.active=arguments.len!=0;work.count=arguments.len;
    work.mark=plan.mark;work.end=plan.planned.arena.used;work.depth=plan.depth;
    var usize i=0;
    while(i<arguments.len){
        work.source_slots[i]=arguments[i].source.slot;
        work.source_generations[i]=arguments[i].source.generation;
        if(i<plan.checked){
            work.source_bases[i]=plan.ranges[i].source;
            work.source_ends[i]=plan.ranges[i].source+plan.ranges[i].size;
        }
        if(i<plan.copies.count){
            work.target_slots[i]=plan.copies.tokens[i].slot;
            work.target_generations[i]=plan.copies.tokens[i].generation;
        }
        i+=1;
    }
    return .ok(work);
}

// Replan exact pinned descriptors on every chunk, reauthenticating table depth,
// arena prefix, source shape/generation and every destination slot/reservation.
// The compact recipe is a comparison target, never independent write authority.
// Empty CALLs have no provisional targets or payload. Authenticate the same
// table/cursor facts without constructing a Table-bearing CallCopyPlan.
pub fn Result<Copies,Error> validate_empty_call_copy(ref Table table,ref calling::State work,usize capacity){
    if(work.count!=0 || work.phase>1 || work.index!=0 || work.last>work.total || work.written>work.total){return .err(.State);}
    if(!valid(table,capacity)){return .err(.State);}
    if(work.mark!=table.arena.used || work.end!=table.arena.used || work.depth!=table.depth){return .err(.State);}
    var usize i=0;while(i<8){
        if(work.source_bases[i]!=0 || work.source_ends[i]!=0 || work.target_slots[i]!=0 || work.target_generations[i]!=0){return .err(.State);}i+=1;
    }
    if(work.active || work.phase!=0 || work.at!=0 || work.written!=0){return .err(.State);}
    return .ok(Copies{.tokens=[Token{.slot=0,.generation=0};8],.count=0});
}
pub fn Result<CallCopyPlan,Error> validate_call_copy(ref Table table,ref records::Catalog catalog,
    ref CallArgument[] arguments,ref calling::State work,usize capacity){
    if(work.count!=arguments.len || work.count>8 || work.phase>1){return .err(.State);}
    if(!work.active && work.count!=0){return .err(.State);}
    if(work.index>work.count || work.last>work.total || work.written>work.total){return .err(.State);}
    var usize i=0;
    while(i<work.count){
        if(arguments[i].source.slot!=work.source_slots[i] ||
            arguments[i].source.generation!=work.source_generations[i]){return .err(.State);}
        i+=1;
    }
    let CallCopyPlan plan=plan_call_copy(table,catalog,arguments,capacity)?;
    if(work.phase==1){switch(plan.failure){case .none:{}case .some(e):{return .err(e);}};}
    if(plan.mark!=work.mark || plan.planned.arena.used!=work.end || plan.depth!=work.depth){return .err(.State);}
    i=0;
    while(i<8){
        let Token target=plan.copies.tokens[i];
        let CallCopyRange origin=plan.ranges[i];
        if(origin.source!=work.source_bases[i] || origin.source+origin.size!=work.source_ends[i]){return .err(.State);}
        if(target.slot!=work.target_slots[i] || target.generation!=work.target_generations[i]){return .err(.State);}
        i+=1;
    }
    if(work.end<work.mark || work.written>work.end-work.mark){return .err(.State);}
    if(work.count==0){
        if(work.active || work.phase!=0 || work.index!=0 || work.at!=0 || work.written!=0){return .err(.State);}
    }else if(work.phase==0){
        if(work.written!=0 || work.index>plan.checked){return .err(.State);}
        if(work.index==plan.checked){if(work.at!=0){return .err(.State);}}
        else if(work.at>plan.ranges[work.index].size){return .err(.State);}
    }else{
        if(plan.copies.count!=work.count || work.index>=work.count){return .err(.State);}
        let CallCopyRange range=plan.ranges[work.index];
        if(work.at>range.end-range.mark || work.written!=range.mark-work.mark+work.at ||
            work.written>=work.end-work.mark){return .err(.State);}
    }
    return .ok(plan);
}

// Owning invocation-only primitives. The parent authenticates/fixes table and
// catalog inputs; raw planning above continues to independently re-prove them.
pub fn Result<usize,Error> inspect_call_copy_table(ref Table table,usize capacity){
    if(!valid(table,capacity)){return .err(.State);}return .ok(table.depth);
}
pub fn Result<Owner,Error> inspect_call_copy_source(ref Table table,CallArgument argument){
    let Owner owner=lookup(table,argument.source)?;
    if(owner.writing){return .err(.State);}if(owner.element!=argument.element){return .err(.Type);}
    if(argument.element==0){if(argument.length!=0){return .err(.Metadata);}if(owner.record!=argument.record){return .err(.Type);}}
    else{if(argument.record!=0){return .err(.Metadata);}if(owner.length!=argument.length){return .err(.Length);}}
    return .ok(owner);
}
pub fn Result<Token,Error> reserve_call_copy_target(ref mut Table planned,ref Owner owner){return call_copy_target(planned,owner);}
