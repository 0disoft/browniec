module arithmetic_checks;

import arithmetic as math;
import std::io as io;

@effects(console)
fn void mark(ref str text) { switch (io::write(text)) { case .ok(_): { } case .err(_): { assert(false); } }; }

fn i32 error_code(math::Error value) {
    return switch(value) { case .Overflow: { 1 } case .ZeroDivisor: { 2 } case .Shift: { 3 } case .Width: { 4 } case .Operand: { 5 } };
}

@effects(console)
fn void signed_ok(math::Op op, i64 a, i64 b, usize width, i64 expected) {
    switch (math::signed(op, a, b, width)) {
        case .ok(value): { assert(value == expected); }
        case .err(_): { mark("unexpected error\n"); assert(false); }
    };
}
@effects(console)
fn void signed_error(math::Op op, i64 a, i64 b, usize width, math::Error expected) {
    switch (math::signed(op, a, b, width)) {
        case .ok(_): { mark("unexpected ok\n"); assert(false); }
        case .err(value): { assert(error_code(value) == error_code(expected)); }
    };
}
@effects(console)
fn void unsigned_ok(math::Op op, usize a, usize b, usize width, usize expected) {
    switch (math::unsigned(op, a, b, width)) {
        case .ok(value): { assert(value == expected); }
        case .err(_): { mark("unexpected error\n"); assert(false); }
    };
}
@effects(console)
fn void unsigned_error(math::Op op, usize a, usize b, usize width, math::Error expected) {
    switch (math::unsigned(op, a, b, width)) {
        case .ok(_): { mark("unexpected ok\n"); assert(false); }
        case .err(value): { assert(error_code(value) == error_code(expected)); }
    };
}

@effects(console)
pub fn void run() {
    let i64 minimum = -9223372036854775808;
    let i64 maximum = 9223372036854775807;
    let usize umax = 18446744073709551615;
    signed_ok(.Add, minimum, maximum, 64, -1);
    signed_ok(.Add, maximum, 0, 64, maximum);
    signed_ok(.Sub, minimum, minimum, 64, 0);
    signed_ok(.Sub, -1, minimum, 64, maximum);
    signed_ok(.Mul, minimum, 0, 64, 0);
    signed_ok(.Mul, minimum, 1, 64, minimum);
    signed_ok(.Mul, -3, -7, 64, 21);
    signed_ok(.Mul, -3, 7, 64, -21);
    signed_ok(.Mul, 3, -7, 64, -21);
    signed_ok(.Mul, 3037000499, 3037000499, 64, 9223372030926249001);
    signed_ok(.Div, minimum, 1, 64, minimum);
    signed_ok(.Div, -7, 3, 64, -2);
    signed_ok(.Rem, -7, 3, 64, -1);
    signed_ok(.Rem, 7, -3, 64, 1);
    signed_ok(.Neg, maximum, 0, 64, -9223372036854775807);
    signed_ok(.Shl, -1, 63, 64, minimum);
    signed_ok(.Shl, minimum, 0, 64, minimum);
    signed_ok(.Shr, minimum, 63, 64, -1);
    signed_ok(.Shr, -3, 1, 64, -2);
    signed_ok(.Shr, maximum, 63, 64, 0);
    signed_error(.Add, maximum, 1, 64, .Overflow);
    signed_error(.Add, minimum, -1, 64, .Overflow);
    signed_error(.Sub, maximum, -1, 64, .Overflow);
    signed_error(.Sub, minimum, 1, 64, .Overflow);
    signed_error(.Mul, minimum, -1, 64, .Overflow);
    signed_error(.Mul, -1, minimum, 64, .Overflow);
    signed_error(.Mul, maximum, 2, 64, .Overflow);
    signed_error(.Mul, 3037000500, 3037000500, 64, .Overflow);
    signed_error(.Div, minimum, -1, 64, .Overflow);
    signed_error(.Rem, minimum, -1, 64, .Overflow);
    signed_error(.Div, 1, 0, 64, .ZeroDivisor);
    signed_error(.Rem, 1, 0, 64, .ZeroDivisor);
    signed_error(.Neg, minimum, 0, 64, .Overflow);
    signed_error(.Shl, 1, 63, 64, .Overflow);
    signed_error(.Shl, 1, -1, 64, .Shift);
    signed_error(.Shr, 1, 64, 64, .Shift);
    signed_error(.Add, 1, 2, 16, .Width);
    signed_ok(.Shl, -1, 31, 32, -2147483648);
    signed_ok(.Add, 2147483646, 1, 32, 2147483647);
    signed_error(.Add, 2147483647, 1, 32, .Overflow);
    signed_error(.Sub, -2147483648, 1, 32, .Overflow);
    signed_error(.Div, -2147483648, -1, 32, .Overflow);
    signed_error(.Rem, -2147483648, -1, 32, .Overflow);
    signed_error(.Neg, -2147483648, 0, 32, .Overflow);
    signed_error(.Shr, 1, 32, 32, .Shift);
    signed_error(.Add, 2147483648, 0, 32, .Operand);
    unsigned_ok(.Add, umax - 1, 1, 64, umax);
    unsigned_ok(.Sub, umax, umax, 64, 0);
    unsigned_ok(.Mul, umax, 0, 64, 0);
    unsigned_ok(.Div, umax, 2, 64, 9223372036854775807);
    unsigned_ok(.Rem, umax, 2, 64, 1);
    unsigned_ok(.Shl, 1, 63, 64, 9223372036854775808);
    unsigned_ok(.Shr, umax, 63, 64, 1);
    unsigned_error(.Add, umax, 1, 64, .Overflow);
    unsigned_error(.Sub, 0, 1, 64, .Overflow);
    unsigned_error(.Mul, umax, 2, 64, .Overflow);
    unsigned_error(.Div, 1, 0, 64, .ZeroDivisor);
    unsigned_error(.Rem, 1, 0, 64, .ZeroDivisor);
    unsigned_error(.Shl, 2, 63, 64, .Overflow);
    unsigned_error(.Shr, 1, 64, 64, .Shift);
    unsigned_error(.Neg, 1, 0, 64, .Operand);
    unsigned_ok(.Add, 254, 1, 8, 255);
    unsigned_ok(.Mul, 15, 17, 8, 255);
    unsigned_ok(.Shr, 255, 7, 8, 1);
    unsigned_error(.Add, 255, 1, 8, .Overflow);
    unsigned_error(.Shl, 1, 8, 8, .Shift);
    unsigned_error(.Add, 256, 0, 8, .Operand);
    unsigned_ok(.Add, 4294967294, 1, 32, 4294967295);
    unsigned_ok(.Shl, 1, 31, 32, 2147483648);
    unsigned_error(.Add, 4294967295, 1, 32, .Overflow);
    unsigned_error(.Shr, 1, 32, 32, .Shift);
    unsigned_error(.Add, 0, 0, 16, .Width);
}
