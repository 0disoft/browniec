module tagged;

// The low bit is 1 for some/ok and 0 for none/err. Scalar payloads fit in
// signed 33 bits after packing. Subtract the tag before signed division so
// negative odd encodings decode correctly with truncation toward zero.
pub fn i64 pack(i64 payload,u8 variant) {return payload*2+(variant as i64);}
pub fn u8 variant(i64 value) {return if(value%2==0) {0} else {1};}
pub fn i64 unpack(i64 value,u8 variant) {return (value-(variant as i64))/2;}
