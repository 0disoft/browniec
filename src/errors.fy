module errors;

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
pub struct Error { u8 kind; u8 location; usize offset; }
pub fn Error make(u8 kind, usize offset) {
    return Error{.kind=kind,.offset=offset,.location=0};
}
// The instruction index is zero-based; 0 is a valid location.
// JSON v1 keeps the index in byte_offset for compatibility.
pub fn Error instruction(usize pc){
    return Error{.kind=5,.offset=pc,.location=instruction_location()};
}
pub fn Error absent(u8 kind,usize legacy_offset){
    return Error{.kind=kind,.offset=legacy_offset,.location=absent_location()};
}
