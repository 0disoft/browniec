module errors;

// Stable within the experimental slice; offsets are zero-based source bytes.
// Kind18 is the distinct compiler must_use_result diagnostic.
pub struct Error { u8 kind; usize offset; }
pub fn Error make(u8 kind, usize offset) {
    return Error { .kind = kind, .offset = offset };
}
