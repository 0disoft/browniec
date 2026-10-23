module array_layout;

import types as types;

// Private compact payload layout, separate from scalar VM register cells.
// Planning only: no source arrays, allocation, publication, or mutable ledger.
pub enum Error { Type; Length; Metadata; Overflow; Quota; Bounds; Alignment; }
pub struct Array { u8 element; usize length; usize stride; usize alignment; usize bytes; }
pub struct Reservation { usize offset; usize end; usize charge; }

fn usize width(u8 element) {
    if (element == 2 || element == 10) { return 1; }
    if (element == 1 || element == 11) { return 4; }
    if (element == 9 || element == 12) { return 8; }
    return 0;
}

pub fn Result<Array, Error> scalar(u8 element, usize length) {
    if (!types::scalar(element)) { return .err(.Type); }
    if (length == 0 || length > 4096) { return .err(.Length); }
    let usize stride = width(element);
    // The admitted length and width prove the multiplication <= 32768.
    return .ok(Array { .element = element, .length = length, .stride = stride,
        .alignment = stride, .bytes = length * stride });
}

// Recompute rather than trusting cached metadata at a future IR boundary.
pub fn Result<usize, Error> validate(ref Array layout) {
    let Array canonical = scalar(layout.element, layout.length)?;
    if (layout.stride != canonical.stride || layout.alignment != canonical.alignment ||
        layout.bytes != canonical.bytes) { return .err(.Metadata); }
    return .ok(canonical.bytes);
}

// 'used' includes all existing bytes. Padding counts toward the arena ceiling.
// Success is a plan; the caller must not publish or advance a ledger yet.
pub fn Result<Reservation, Error> reserve(ref Array layout, usize used, usize limit) {
    let usize size = validate(layout)?;
    if (used > limit) { return .err(.Quota); }
    let usize remainder = used % layout.alignment;
    let usize padding = if (remainder == 0) { 0 } else { layout.alignment - remainder };
    if (padding > 18446744073709551615 - used) { return .err(.Overflow); }
    let usize offset = used + padding;
    if (size > 18446744073709551615 - offset) { return .err(.Overflow); }
    let usize end = offset + size;
    if (end > limit) { return .err(.Quota); }
    return .ok(Reservation { .offset = offset, .end = end, .charge = end - used });
}

// Validate the entire array extent before selecting an element. No pointer is
// formed here. All additions are bounded by the supplied storage length.
pub fn Result<usize, Error> offset(ref Array layout, usize base, usize index, usize storage_bytes) {
    let usize size = validate(layout)?;
    if (index >= layout.length) { return .err(.Bounds); }
    if (base % layout.alignment != 0) { return .err(.Alignment); }
    if (base > storage_bytes || size > storage_bytes - base) { return .err(.Bounds); }
    return .ok(base + index * layout.stride);
}
