module cells;

import errors as errors;
import std::num as num;

// Reversible unsigned bits in the existing signed 64-bit register cells.
// Split at 2^63 before converting; neither path needs an out-of-range cast.
pub fn Result<i64,errors::Error> pack(usize value,usize offset) {
    let bool upper=value>9223372036854775807;
    let usize low=if(upper) {value-9223372036854775808} else {value};
    let i64 converted=switch(num::i64_from_usize(low)) {
        case .ok(n): {n} case .err(_): {return .err(errors::make(5,offset));}
    };
    return .ok(if(upper) {-9223372036854775808+converted} else {converted});
}

pub fn Result<usize,errors::Error> unpack(i64 value,usize offset) {
    let bool upper=value<0;
    let i64 low=if(upper) {value - -9223372036854775808} else {value};
    let usize converted=switch(num::usize_from_i64(low)) {
        case .ok(n): {n} case .err(_): {return .err(errors::make(5,offset));}
    };
    return .ok(if(upper) {9223372036854775808+converted} else {converted});
}
