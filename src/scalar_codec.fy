module scalar_codec;

import types as types;
import cells as cells;
import std::num as num;

pub enum Error { Type; Width; Value; }

pub fn usize width(u8 tag) {
    if (tag == 2 || tag == 10) { return 1; }
    if (tag == 1 || tag == 11) { return 4; }
    if (tag == 9 || tag == 12) { return 8; }
    return 0;
}

// Scalar register cells use signed i64, including the packed upper usize half.
pub fn bool fits(u8 tag, i64 cell) {
    if (tag == 2) { return cell == 0 || cell == 1; }
    return width(tag) != 0 && types::fits(tag, cell);
}

// Build the full encoding in scratch first: every error preserves output bytes.
pub fn Result<usize, Error> encode(u8 tag, i64 cell, ref mut u8[] output) {
    let usize size = width(tag);
    if (size == 0) { return .err(.Type); }
    if (output.len != size) { return .err(.Width); }
    if (!fits(tag, cell)) { return .err(.Value); }
    var u8[8] encoded = [0; 8];
    var i64 remaining = cell;
    var usize i = 0;
    while (i < size) {
        let i64 remainder = remaining % 256;
        let i64 digit = if (remainder < 0) { remainder + 256 } else { remainder };
        encoded[i] = switch (num::u8_from_i64(digit)) {
            case .ok(value): { value } case .err(_): { return .err(.Value); }
        };
        remaining /= 256;
        if (remainder < 0) { remaining -= 1; }
        i += 1;
    }
    i = 0;
    while (i < size) { output[i] = encoded[i]; i += 1; }
    return .ok(size);
}

pub fn Result<i64, Error> decode(u8 tag, ref u8[] input) {
    let usize size = width(tag);
    if (size == 0) { return .err(.Type); }
    if (input.len != size) { return .err(.Width); }
    if (tag == 2 && input[0] > 1) { return .err(.Value); }
    if (types::signed(tag)) {
        // Sign-extended accumulation stays in range, including the final i64 MIN.
        var i64 value = if (input[size - 1] >= 128) { -1 } else { 0 };
        var usize i = size;
        while (i > 0) { i -= 1; value = value * 256 + input[i] as i64; }
        return .ok(value);
    }
    var usize bits = 0;
    var usize i = size;
    while (i > 0) { i -= 1; bits = bits * 256 + input[i] as usize; }
    return switch (cells::pack(bits, 0)) {
        case .ok(value): { .ok(value) } case .err(_): { .err(.Value) }
    };
}
