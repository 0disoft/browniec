module tests::m2::array_layout;

import array_layout as arrays;

fn u8 error_code(arrays::Error error) {
    return switch (error) {
        case .Type: { 1 } case .Length: { 2 } case .Metadata: { 3 }
        case .Overflow: { 4 } case .Quota: { 5 } case .Bounds: { 6 } case .Alignment: { 7 }
    };
}
fn arrays::Array layout(u8 element, usize length) {
    return switch (arrays::scalar(element, length)) {
        case .ok(value): { value }
        case .err(_): { assert(false); arrays::Array { .element = 0, .length = 0, .stride = 0, .alignment = 0, .bytes = 0 } }
    };
}
fn arrays::Reservation reserved(ref arrays::Array array, usize used, usize limit) {
    return switch (arrays::reserve(array, used, limit)) {
        case .ok(value): { value }
        case .err(_): { assert(false); arrays::Reservation { .offset = 0, .end = 0, .charge = 0 } }
    };
}
fn usize located(ref arrays::Array array, usize base, usize index, usize storage) {
    return switch (arrays::offset(array, base, index, storage)) {
        case .ok(value): { value } case .err(_): { assert(false); 0 }
    };
}

@test
fn void compact_scalar_widths_and_full_array_lengths() {
    let u8[6] tags = [1, 2, 9, 10, 11, 12];
    let usize[6] widths = [4, 1, 8, 1, 4, 8];
    var usize i = 0;
    while (i < tags.len) {
        let arrays::Array one = layout(tags[i], 1);
        let arrays::Array full = layout(tags[i], 4096);
        assert(one.stride == widths[i] && one.alignment == widths[i] && one.bytes == widths[i]);
        assert(full.bytes == widths[i] * 4096 && full.length == 4096);
        assert(arrays::validate(ref full).is_ok);
        assert(located(ref full, 0, 4095, full.bytes) == full.bytes - widths[i]);
        i += 1;
    }
}

@test
fn void reject_non_scalar_tags_and_invalid_lengths() {
    var u8 byte = 0;
    while (true) {
        if (byte != 1 && byte != 2 && byte != 9 && byte != 10 && byte != 11 && byte != 12) {
            assert(switch (arrays::scalar(byte, 1)) { case .ok(_): { false } case .err(e): { error_code(e) == 1 } });
        }
        if (byte == 255) { break; }
        byte += 1;
    }
    let usize[3] lengths = [0, 4097, 18446744073709551615];
    var usize i = 0;
    while (i < lengths.len) {
        assert(switch (arrays::scalar(9, lengths[i])) { case .ok(_): { false } case .err(e): { error_code(e) == 2 } });
        i += 1;
    }
}

@test
fn void metadata_is_revalidated_before_arithmetic() {
    var arrays::Array array = layout(9, 3);
    array.alignment = 0;
    assert(switch (arrays::reserve(ref array, 1, 100)) { case .ok(_): { false } case .err(e): { error_code(e) == 3 } });
    assert(switch (arrays::offset(ref array, 0, 0, 100)) { case .ok(_): { false } case .err(e): { error_code(e) == 3 } });
    array.alignment = 8; array.stride = 18446744073709551615;
    assert(!arrays::validate(ref array).is_ok);
    assert(!arrays::offset(ref array, 0, 2, 100).is_ok);
    array.stride = 8; array.bytes = 1;
    assert(!arrays::reserve(ref array, 0, 100).is_ok);
    assert(!arrays::offset(ref array, 0, 0, 100).is_ok);
    array.bytes = 24; array.length = 18446744073709551615;
    assert(switch (arrays::reserve(ref array, 0, 100)) { case .ok(_): { false } case .err(e): { error_code(e) == 2 } });
    array.length = 3; array.element = 3;
    assert(switch (arrays::offset(ref array, 0, 0, 100)) { case .ok(_): { false } case .err(e): { error_code(e) == 1 } });
}

@test
fn void reservations_charge_padding_and_preserve_previous_plans() {
    let arrays::Array bytes = layout(10, 3);
    let arrays::Array words = layout(9, 2);
    let arrays::Reservation first = reserved(ref bytes, 0, 24);
    let arrays::Reservation second = reserved(ref words, first.end, 24);
    assert(first.offset == 0 && first.end == 3 && first.charge == 3);
    assert(second.offset == 8 && second.end == 24 && second.charge == 21);
    assert(switch (arrays::reserve(ref words, first.end, 23)) { case .ok(_): { false } case .err(e): { error_code(e) == 5 } });
    let arrays::Reservation retry = reserved(ref words, first.end, 24);
    assert(retry.offset == second.offset && retry.end == second.end && retry.charge == second.charge);
    assert(first.end == 3 && words.bytes == 16);
    assert(switch (arrays::reserve(ref bytes, 25, 24)) { case .ok(_): { false } case .err(e): { error_code(e) == 5 } });
}

@test
fn void reservation_overflow_is_an_error_before_addition() {
    let arrays::Array word = layout(12, 1);
    assert(switch (arrays::reserve(ref word, 18446744073709551615, 18446744073709551615)) {
        case .ok(_): { false } case .err(e): { error_code(e) == 4 }
    });
    assert(switch (arrays::reserve(ref word, 18446744073709551608, 18446744073709551615)) {
        case .ok(_): { false } case .err(e): { error_code(e) == 4 }
    });
    let arrays::Array byte = layout(10, 1);
    let arrays::Reservation edge = reserved(ref byte, 18446744073709551614, 18446744073709551615);
    assert(edge.end == 18446744073709551615 && edge.charge == 1);
}

@test
fn void index_requires_alignment_and_complete_storage_extent() {
    let arrays::Array array = layout(11, 3);
    assert(located(ref array, 4, 0, 16) == 4);
    assert(located(ref array, 4, 2, 16) == 12);
    assert(switch (arrays::offset(ref array, 4, 3, 16)) { case .ok(_): { false } case .err(e): { error_code(e) == 6 } });
    assert(switch (arrays::offset(ref array, 4, 18446744073709551615, 16)) { case .ok(_): { false } case .err(e): { error_code(e) == 6 } });
    assert(switch (arrays::offset(ref array, 2, 0, 16)) { case .ok(_): { false } case .err(e): { error_code(e) == 7 } });
    assert(switch (arrays::offset(ref array, 4, 0, 15)) { case .ok(_): { false } case .err(e): { error_code(e) == 6 } });
    assert(!arrays::offset(ref array, 20, 0, 16).is_ok);
    assert(!arrays::offset(ref array, 18446744073709551612, 0, 18446744073709551615).is_ok);
    assert(located(ref array, 18446744073709551600, 2, 18446744073709551615) == 18446744073709551608);
}
