module bits;

import cells as cells;
import errors as errors;

// Work only on unsigned bit patterns, never native signed bitwise/shift results.
pub fn usize width(u8 tag) {return if(tag==10) {8} else if(tag==1 || tag==11) {32} else {64};}
pub fn usize mask(u8 tag) {return if(tag==10) {255} else if(tag==1 || tag==11) {4294967295} else {18446744073709551615};}
pub fn Result<i64,errors::Error> encoded(usize value,u8 tag,usize offset) {
    let usize pattern=if(tag==1 && value>2147483647) {value | 18446744069414584320} else {value};
    return cells::pack(pattern,offset);
}
pub fn Result<i64,errors::Error> apply(u8 op,i64 left,i64 right,u8 tag,usize offset) {
    let usize limit=mask(tag);
    let usize a=cells::unpack(left,offset)? & limit;
    let usize b=cells::unpack(right,offset)? & limit;
    let usize value=if(op==27) {limit ^ a} else if(op==28) {a & b} else if(op==29) {a ^ b} else {a | b};
    return encoded(value,tag,offset);
}
