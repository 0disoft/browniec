module tests::m2::scalar_codec;

import scalar_codec as codec;
import cells as cells;

fn void vector(u8 tag, i64 value, ref u8[] expected) {
    var u8[10] output = [85; 10];
    assert(codec::encode(tag, value, ref mut output[1..1 + expected.len]).is_ok);
    var usize i = 0;
    while (i < expected.len) { assert(output[i + 1] == expected[i]); i += 1; }
    assert(output[0] == 85 && output[1 + expected.len] == 85);
    assert(switch (codec::decode(tag, expected)) { case .ok(n): { n == value } case .err(_): { false } });
}

@test
fn void exact_little_endian_signed_unsigned_and_bool_vectors() {
    vector(2, 0, b"\x00"); vector(2, 1, b"\x01"); vector(10, 255, b"\xff");
    vector(1, -2147483648, b"\x00\x00\x00\x80");
    vector(1, 2147483647, b"\xff\xff\xff\x7f");
    vector(1, -1, b"\xff\xff\xff\xff");
    vector(11, 4294967295, b"\xff\xff\xff\xff");
    vector(11, 16909060, b"\x04\x03\x02\x01");
    vector(9, -9223372036854775808, b"\x00\x00\x00\x00\x00\x00\x00\x80");
    vector(9, 9223372036854775807, b"\xff\xff\xff\xff\xff\xff\xff\x7f");
    vector(9, -257, b"\xff\xfe\xff\xff\xff\xff\xff\xff");
    vector(9, 72623859790382856, b"\x08\x07\x06\x05\x04\x03\x02\x01");
    // The upper unsigned half stays in the existing signed register-cell encoding.
    vector(12, -1, b"\xff\xff\xff\xff\xff\xff\xff\xff");
    vector(12, -9223372036854775808, b"\x00\x00\x00\x00\x00\x00\x00\x80");
    vector(12, 0, b"\x00\x00\x00\x00\x00\x00\x00\x00");
}

@test
fn void every_repeated_byte_pattern_roundtrips_full_cells() {
    var u8 byte = 0;
    while (true) {
        let usize bits = (byte as usize) * 72340172838076673;
        let i64 cell = switch (cells::pack(bits, 0)) { case .ok(n): { n } case .err(_): { assert(false); 0 } };
        let u8[8] expected = [byte; 8];
        vector(9, cell, ref expected); vector(12, cell, ref expected);
        if (byte == 255) { break; }
        byte += 1;
    }
}

@test
fn void width_and_unknown_type_errors_preserve_all_output() {
    let u8[6] tags = [1, 2, 9, 10, 11, 12];
    var u8[10] output = [85; 10];
    var usize t = 0;
    while (t < tags.len) {
        var usize size = 0;
        while (size <= 9) {
            if (size != codec::width(tags[t])) {
                assert(!codec::encode(tags[t], 0, ref mut output[..size]).is_ok);
                assert(!codec::decode(tags[t], ref output[..size]).is_ok);
            }
            size += 1;
        }
        t += 1;
    }
    assert(!codec::encode(3, 0, ref mut output[..1]).is_ok);
    assert(!codec::decode(255, ref output[..1]).is_ok);
    var usize i = 0;
    while (i < output.len) { assert(output[i] == 85); i += 1; }
}

@test
fn void out_of_range_writes_and_noncanonical_bool_are_rejected() {
    let u8[8] tags = [2, 2, 10, 10, 1, 1, 11, 11];
    let i64[8] values = [-1, 2, -1, 256, -2147483649, 2147483648, -1, 4294967296];
    var u8[8] output = [85; 8];
    var usize i = 0;
    while (i < tags.len) {
        assert(!codec::encode(tags[i], values[i], ref mut output[..codec::width(tags[i])]).is_ok);
        i += 1;
    }
    i = 0;
    while (i < output.len) { assert(output[i] == 85); i += 1; }
    var u8 byte = 2;
    while (true) {
        let u8[1] input = [byte];
        assert(!codec::decode(2, ref input).is_ok);
        if (byte == 255) { break; }
        byte += 1;
    }
}
