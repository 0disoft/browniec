module arithmetic;

import errors as errors;
import cells as cells;

// Guards follow the M0 signed arithmetic probe. Never evaluate a native signed
// operation until its full-width result is known to fit. No host trap is a guest error.
pub fn Result<i64,errors::Error> signed(u8 op,i64 a,i64 b,u8 tag,usize offset) {
    let i64 minimum=if(tag==1) {-2147483648} else {-9223372036854775808};
    var i64 value=0;
    if(op==2) {
        if((b>0 && a>9223372036854775807-b) || (b<0 && a < -9223372036854775808-b)) {return .err(errors::make(6,offset));}
        value=a+b;
    } else if(op==3) {
        if((b<0 && a>9223372036854775807+b) || (b>0 && a < -9223372036854775808+b)) {return .err(errors::make(6,offset));}
        value=a-b;
    } else if(op==4) {
        if(a>0) {
            if((b>0 && a>9223372036854775807/b) || (b<0 && b < -9223372036854775808/a)) {return .err(errors::make(6,offset));}
        }
        if(a<0) {
            if((b>0 && a < -9223372036854775808/b) || (b<0 && a<9223372036854775807/b)) {return .err(errors::make(6,offset));}
        }
        value=a*b;
    } else if(op==7) {
        if(a==minimum) {return .err(errors::make(6,offset));}
        value=-a;
    } else {
        if(b==0) {return .err(errors::make(7,offset));}
        if(a==minimum && b == -1) {return .err(errors::make(6,offset));}
        value=if(op==5) {a/b} else {a%b};
    }
    if(tag==1 && (value < -2147483648 || value>2147483647)) {return .err(errors::make(6,offset));}
    return .ok(value);
}

// M0 unsigned guards apply before the corresponding native unsigned operation.
pub fn Result<i64,errors::Error> unsigned(u8 op,i64 left,i64 right,u8 tag,usize offset) {
    let usize a=cells::unpack(left,offset)?;
    let usize b=cells::unpack(right,offset)?;
    let usize maximum=if(tag==10) {255} else if(tag==11) {4294967295} else {18446744073709551615};
    var usize value=0;
    if(op==2) {
        if(a>maximum-b) {return .err(errors::make(6,offset));}
        value=a+b;
    } else if(op==3) {
        if(a<b) {return .err(errors::make(6,offset));}
        value=a-b;
    } else if(op==4) {
        if(b!=0 && a>maximum/b) {return .err(errors::make(6,offset));}
        value=a*b;
    } else {
        if(b==0) {return .err(errors::make(7,offset));}
        value=if(op==5) {a/b} else {a%b};
    }
    return cells::pack(value,offset);
}

pub fn Result<i64,errors::Error> ordering(u8 op,i64 left,i64 right,usize offset) {
    let usize a=cells::unpack(left,offset)?;
    let usize b=cells::unpack(right,offset)?;
    let bool result=if(op==13) {a<b} else if(op==14) {a<=b} else if(op==15) {a>b} else {a>=b};
    return .ok(if(result) {1} else {0});
}
