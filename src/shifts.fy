module shifts;

import bits as bits;
import cells as cells;
import types as types;
import errors as errors;

pub fn Result<i64,errors::Error> apply(u8 op,i64 left,i64 right,u8 tag,usize offset) {
    let usize width=bits::width(tag);
    let usize amount=cells::unpack(right,offset)?;
    // Negative signed counts decode above the width as well. Reject first,
    // before performing any host shift or testing left-shift overflow.
    if(amount>=width) {return .err(errors::make(6,offset));}
    let usize mask=bits::mask(tag);
    let usize a=cells::unpack(left,offset)? & mask;
    if(op==32) {
        var usize value=a >> amount;
        if(types::signed(tag) && left<0 && amount!=0) {value=value | (mask ^ (mask >> amount));}
        return bits::encoded(value,tag,offset);
    }
    if(types::signed(tag)) {
        let usize one=1;
        let usize sign=one << (width-1);
        let usize magnitude=if(left<0) {(mask ^ a)+1} else {a};
        let usize ceiling=if(left<0) {sign} else {sign-1};
        if(magnitude>(ceiling >> amount)) {return .err(errors::make(6,offset));}
    } else if(a>(mask >> amount)) {return .err(errors::make(6,offset));}
    // Discard only sign-extension bits before the native *unsigned* shift,
    // so Fairy's own checked shift cannot overflow even for negative guests.
    return bits::encoded((a & (mask >> amount)) << amount,tag,offset);
}
