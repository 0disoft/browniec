module codec;

import std::num as num;

pub enum Error { Width; Conversion; }

// A complete fixed-width value is required. No partial writes on a width error.
pub fn Result<usize, Error> encode_i64(i64 input, ref mut u8[] output) {
    if (output.len != 8) { return .err(.Width); }
    var i64 remaining = input;
    var usize at = 0;
    while (at < 8) {
        let i64 remainder = remaining % 256;
        let i64 digit = if (remainder < 0) { remainder + 256 } else { remainder };
        let u8 byte = switch (num::u8_from_i64(digit)) {
            case .ok(value): { value }
            case .err(_): { return .err(.Conversion); }
        };
        output[at] = byte;
        remaining /= 256;
        // Floor division supplies two's-complement sign extension without negating MIN.
        if (remainder < 0) { remaining -= 1; }
        at += 1;
    }
    return .ok(8);
}

pub fn Result<i64, Error> decode_i64(ref u8[] input) {
    if (input.len != 8) { return .err(.Width); }
    var i64 value = if (input[7] >= 128) { -1 } else { 0 };
    var usize at = 8;
    while (at > 0) {
        at -= 1;
        // Sign extension bounds each intermediate, including MIN's final multiply.
        value = value * 256 + input[at] as i64;
    }
    return .ok(value);
}

pub fn Result<usize, Error> encode_usize(usize input, ref mut u8[] output) {
    if (output.len != 8) { return .err(.Width); }
    var usize remaining = input;
    var usize at = 0;
    while (at < 8) {
        let i64 digit = switch (num::i64_from_usize(remaining % 256)) {
            case .ok(value): { value }
            case .err(_): { return .err(.Conversion); }
        };
        let u8 byte = switch (num::u8_from_i64(digit)) {
            case .ok(value): { value }
            case .err(_): { return .err(.Conversion); }
        };
        output[at] = byte;
        remaining /= 256;
        at += 1;
    }
    return .ok(8);
}

pub fn Result<usize, Error> decode_usize(ref u8[] input) {
    if (input.len != 8) { return .err(.Width); }
    var usize value = 0;
    var usize at = 8;
    while (at > 0) {
        at -= 1;
        value = value * 256 + input[at] as usize;
    }
    return .ok(value);
}
