module errors;

// Stable within the experimental slice; offsets are zero-based source bytes.
// Kind18 is the distinct compiler must_use_result diagnostic.
// Private run diagnostic for an elapsed deadline.
pub fn u8 deadline_kind(){return 30;}
pub struct Error { u8 kind; usize offset; }
pub fn Error make(u8 kind, usize offset) {
    return Error { .kind = kind, .offset = offset };
}
