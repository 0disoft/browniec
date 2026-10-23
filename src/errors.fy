module errors;

// Stable within the experimental M1 slice; offsets are zero-based source bytes.
pub struct Error { u8 kind; usize offset; }
pub fn Error make(u8 kind, usize offset) {
    return Error { .kind = kind, .offset = offset };
}
