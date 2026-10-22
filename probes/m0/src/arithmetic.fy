module arithmetic;

pub enum Error { Overflow; ZeroDivisor; Shift; Width; Operand; }
pub enum Op { Add; Sub; Mul; Div; Rem; Neg; Shl; Shr; }

fn Result<i64, Error> add(i64 a, i64 b) {
    if (b > 0 && a > 9223372036854775807 - b) { return .err(.Overflow); }
    if (b < 0 && a < -9223372036854775808 - b) { return .err(.Overflow); }
    return .ok(a + b);
}

fn Result<i64, Error> sub(i64 a, i64 b) {
    if (b < 0 && a > 9223372036854775807 + b) { return .err(.Overflow); }
    if (b > 0 && a < -9223372036854775808 + b) { return .err(.Overflow); }
    return .ok(a - b);
}

fn Result<i64, Error> mul(i64 a, i64 b) {
    if (a > 0) {
        if (b > 0 && a > 9223372036854775807 / b) { return .err(.Overflow); }
        if (b < 0 && b < -9223372036854775808 / a) { return .err(.Overflow); }
    }
    if (a < 0) {
        if (b > 0 && a < -9223372036854775808 / b) { return .err(.Overflow); }
        if (b < 0 && a < 9223372036854775807 / b) { return .err(.Overflow); }
    }
    return .ok(a * b);
}

fn Result<i64, Error> divide(i64 a, i64 b, bool remainder) {
    if (b == 0) { return .err(.ZeroDivisor); }
    if (a == -9223372036854775808 && b == -1) { return .err(.Overflow); }
    return .ok(if (remainder) { a % b } else { a / b });
}

fn Result<i64, Error> negate(i64 a) {
    if (a == -9223372036854775808) { return .err(.Overflow); }
    return .ok(-a);
}

// Register values remain wide; the VM codec owns their narrower storage.
pub fn Result<i64, Error> signed(Op op, i64 a, i64 b, usize width) {
    if (width != 32 && width != 64) { return .err(.Width); }
    let i64 minimum = if (width == 32) { -2147483648 } else { -9223372036854775808 };
    let i64 maximum = if (width == 32) { 2147483647 } else { 9223372036854775807 };
    if (a < minimum || a > maximum) { return .err(.Operand); }
    let bool shift = switch (op) { case .Shl: { true } case .Shr: { true } case .Add: { false } case .Sub: { false } case .Mul: { false } case .Div: { false } case .Rem: { false } case .Neg: { false } };
    let bool unary = switch (op) { case .Neg: { true } case .Add: { false } case .Sub: { false } case .Mul: { false } case .Div: { false } case .Rem: { false } case .Shl: { false } case .Shr: { false } };
    if (!shift && !unary && (b < minimum || b > maximum)) { return .err(.Operand); }
    if (shift && (b < 0 || b >= if (width == 32) { 32 } else { 64 })) { return .err(.Shift); }
    let i64 result = switch (op) {
        case .Add: { add(a, b)? }
        case .Sub: { sub(a, b)? }
        case .Mul: { mul(a, b)? }
        case .Div: {
            if (a == minimum && b == -1) { return .err(.Overflow); }
            divide(a, b, false)?
        }
        case .Rem: {
            if (a == minimum && b == -1) { return .err(.Overflow); }
            divide(a, b, true)?
        }
        case .Neg: { negate(a)? }
        case .Shl: {
            var i64 value = a;
            var i64 at = 0;
            while (at < b) { value = mul(value, 2)?; at += 1; }
            value
        }
        case .Shr: {
            var i64 value = a;
            var i64 at = 0;
            while (at < b) {
                let bool round_down = value < 0 && value % 2 != 0;
                value /= 2;
                if (round_down) { value -= 1; }
                at += 1;
            }
            value
        }
    };
    if (result < minimum || result > maximum) { return .err(.Overflow); }
    return .ok(result);
}

pub fn Result<usize, Error> unsigned(Op op, usize a, usize b, usize width) {
    if (width != 8 && width != 32 && width != 64) { return .err(.Width); }
    let usize maximum = if (width == 8) { 255 } else if (width == 32) { 4294967295 } else { 18446744073709551615 };
    if (a > maximum) { return .err(.Operand); }
    let bool shift = switch (op) { case .Shl: { true } case .Shr: { true } case .Add: { false } case .Sub: { false } case .Mul: { false } case .Div: { false } case .Rem: { false } case .Neg: { false } };
    if (!shift && b > maximum) { return .err(.Operand); }
    if (shift && b >= width) { return .err(.Shift); }
    switch (op) {
        case .Add: {
            if (a > maximum - b) { return .err(.Overflow); }
            return .ok(a + b);
        }
        case .Sub: {
            if (a < b) { return .err(.Overflow); }
            return .ok(a - b);
        }
        case .Mul: {
            if (b != 0 && a > maximum / b) { return .err(.Overflow); }
            return .ok(a * b);
        }
        case .Div: {
            if (b == 0) { return .err(.ZeroDivisor); }
            return .ok(a / b);
        }
        case .Rem: {
            if (b == 0) { return .err(.ZeroDivisor); }
            return .ok(a % b);
        }
        case .Neg: { return .err(.Operand); }
        case .Shl: {
            var usize value = a;
            var usize at = 0;
            while (at < b) {
                if (value > maximum / 2) { return .err(.Overflow); }
                value *= 2;
                at += 1;
            }
            return .ok(value);
        }
        case .Shr: {
            var usize value = a;
            var usize at = 0;
            while (at < b) { value /= 2; at += 1; }
            return .ok(value);
        }
    };
    return .err(.Operand);
}
