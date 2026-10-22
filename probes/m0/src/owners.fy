module owners;

import std::bytes as bytes;

pub enum Error { Token; Bounds; Full; }
pub struct Token { usize slot; usize generation; }
pub struct Owner { usize generation; bool live; usize start; usize length; }
// Four native metadata slots suffice for M0. This is not the VM's capacity policy.
pub struct Table { Owner[4] slots; usize payload_reads; }

pub fn Table empty() {
    return Table { .slots = [Owner { .generation = 1, .live = false, .start = 0, .length = 0 }; 4], .payload_reads = 0 };
}

pub fn Result<Token, Error> create(ref mut Table table, usize start, usize length, usize storage_length) {
    if (start > storage_length || length > storage_length - start) { return .err(.Bounds); }
    var usize at = 0;
    while (at < 4) {
        let Owner owner = table.slots[at];
        if (!owner.live && owner.generation != 0) {
            table.slots[at].live = true;
            table.slots[at].start = start;
            table.slots[at].length = length;
            return .ok(Token { .slot = at, .generation = owner.generation });
        }
        at += 1;
    }
    return .err(.Full);
}

fn Result<Owner, Error> resolve(ref Table table, Token token) {
    if (token.slot >= 4 || token.generation == 0) { return .err(.Token); }
    let Owner owner = table.slots[token.slot];
    if (!owner.live || owner.generation != token.generation) { return .err(.Token); }
    return .ok(owner);
}

pub fn Result<usize, Error> release(ref mut Table table, Token token) {
    let Owner owner = resolve(table, token)?;
    table.slots[token.slot].live = false;
    table.slots[token.slot].start = 0;
    table.slots[token.slot].length = 0;
    // Never wrap and make an ancient token valid again. Retire the slot at MAX.
    table.slots[token.slot].generation = if (owner.generation == 18446744073709551615) { 0 } else { owner.generation + 1 };
    return .ok(token.slot);
}

// storage belongs to the trusted Instance; guest input supplies only token/index.
pub fn Result<u8, Error> read(ref mut Table table, Token token, usize index, ref bytes::Buffer storage) {
    let Owner owner = resolve(table, token)?;
    let usize length = bytes::len(storage);
    if (owner.start > length || owner.length > length - owner.start || index >= owner.length) { return .err(.Bounds); }
    if (table.payload_reads == 18446744073709551615) { return .err(.Bounds); }
    table.payload_reads += 1;
    let ref u8[] view = bytes::view(storage);
    return .ok(view[owner.start + index]);
}
