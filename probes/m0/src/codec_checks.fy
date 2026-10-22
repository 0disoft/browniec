module codec_checks;

import codec as codec;

fn void signed(i64 input, u8[8] expected) {
    var u8[8] output = [85; 8];
    switch (codec::encode_i64(input, ref mut output)) {
        case .ok(length): { assert(length == 8); }
        case .err(_): { assert(false); }
    };
    var usize at = 0;
    while (at < 8) { assert(output[at] == expected[at]); at += 1; }
    switch (codec::decode_i64(ref expected)) {
        case .ok(value): { assert(value == input); }
        case .err(_): { assert(false); }
    };
}

fn void unsigned(usize input, u8[8] expected) {
    var u8[8] output = [85; 8];
    switch (codec::encode_usize(input, ref mut output)) {
        case .ok(length): { assert(length == 8); }
        case .err(_): { assert(false); }
    };
    var usize at = 0;
    while (at < 8) { assert(output[at] == expected[at]); at += 1; }
    switch (codec::decode_usize(ref expected)) {
        case .ok(value): { assert(value == input); }
        case .err(_): { assert(false); }
    };
}

pub fn void run() {
    signed(-9223372036854775808, [0, 0, 0, 0, 0, 0, 0, 128]);
    signed(9223372036854775807, [255, 255, 255, 255, 255, 255, 255, 127]);
    signed(-1, [255; 8]);
    signed(-256, [0, 255, 255, 255, 255, 255, 255, 255]);
    signed(-257, [255, 254, 255, 255, 255, 255, 255, 255]);
    signed(0, [0; 8]);
    signed(256, [0, 1, 0, 0, 0, 0, 0, 0]);
    signed(72623859790382856, [8, 7, 6, 5, 4, 3, 2, 1]);
    unsigned(18446744073709551615, [255; 8]);
    unsigned(9223372036854775808, [0, 0, 0, 0, 0, 0, 0, 128]);
    unsigned(0, [0; 8]);
    unsigned(72623859790382856, [8, 7, 6, 5, 4, 3, 2, 1]);
    // Every possible byte position is checked against an independent bit pattern.
    var usize byte = 0;
    while (byte < 256) {
        let usize value = byte * 72340172838076673;
        var u8[8] output = [0; 8];
        switch (codec::encode_usize(value, ref mut output)) {
            case .ok(_): { }
            case .err(_): { assert(false); }
        };
        var usize at = 0;
        while (at < 8) { assert(output[at] as usize == byte); at += 1; }
        switch (codec::decode_usize(ref output)) {
            case .ok(decoded): { assert(decoded == value); }
            case .err(_): { assert(false); }
        };
        byte += 1;
    }
    var u8[9] bad = [85; 9];
    var usize width = 0;
    while (width <= 9) {
        if (width != 8) {
            switch (codec::encode_i64(-1, ref mut bad[..width])) {
                case .ok(_): { assert(false); }
                case .err(_): { }
            };
            switch (codec::encode_usize(18446744073709551615, ref mut bad[..width])) {
                case .ok(_): { assert(false); }
                case .err(_): { }
            };
            switch (codec::decode_i64(ref bad[..width])) {
                case .ok(_): { assert(false); }
                case .err(_): { }
            };
            switch (codec::decode_usize(ref bad[..width])) {
                case .ok(_): { assert(false); }
                case .err(_): { }
            };
        }
        width += 1;
    }
    var usize at = 0;
    while (at < 9) { assert(bad[at] == 85); at += 1; }
}
