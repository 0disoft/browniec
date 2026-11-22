module errors;

import std::num as num;

// The offset stays numeric for v1 consumers. Location records its domain.
// Location tags: 0 source byte, 1 instruction index, 2 absent.
pub fn u8 instruction_location(){return 1;}
pub fn u8 absent_location(){return 2;}
// Kind18 is the distinct compiler must_use_result diagnostic.
pub fn u8 deadline_kind(){return 30;}
pub fn u8 memory_limit_kind(){return 32;}
pub fn u8 cancelled_kind(){return 33;}
pub fn u8 output_io_kind(){return 34;}
pub fn u8 output_encoding_kind(){return 35;}
pub fn u8 engine_poisoned_kind(){return 36;}
pub fn u8 host_failure_kind(){return 37;}
// Detail fills part of the alignment padding before offset on the native targets.
pub struct Error { u8 kind; u8 location; u8 expected; u8 actual; u8 related_low; u8 related_high; usize offset; }
pub fn Error make(u8 kind, usize offset) {
    return Error{.kind=kind,.location=0,.expected=0,.actual=0,.related_low=0,.related_high=0,.offset=offset};
}
pub fn Error argument_type(usize at,u8 expected,u8 actual,usize declaration){
    var Error error=make(3,at);
    let i64 wide=switch(num::i64_from_usize(declaration)){case .ok(n):{n} case .err(_):{return error;}};
    let u8 low=switch(num::u8_from_i64(wide%256)){case .ok(n):{n} case .err(_):{return error;}};
    let u8 high=switch(num::u8_from_i64(wide/256)){case .ok(n):{n} case .err(_):{return error;}};
    error.expected=expected;
    error.actual=actual;
    error.related_low=low;
    error.related_high=high;
    return error;
}
pub fn usize related_offset(Error error){
    return error.related_low as usize+256*(error.related_high as usize);
}
// The instruction index is zero-based; 0 is a valid location.
// JSON v1 keeps the index in byte_offset for compatibility.
pub fn Error instruction(usize pc){
    var Error error=make(5,pc);error.location=instruction_location();return error;
}
pub fn Error absent(u8 kind,usize legacy_offset){
    var Error error=make(kind,legacy_offset);error.location=absent_location();return error;
}
