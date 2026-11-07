module output_copy_cursor;

// Trusted saved emit recipe. The exact Program/input/arena and source loan stay
// pinned while active; the dispatcher does not advance any other guest opcode.
// total counts actual copied bytes; last is reset once per dispatch batch.
pub struct State {
    bool active; u8 storage; usize start; usize length; usize copied;
    usize offset; usize total; usize last;
}
pub fn usize chunk_limit(){return 4096;}
pub fn State empty(){return State{.active=false,.storage=0,.start=0,.length=0,
    .copied=0,.offset=0,.total=0,.last=0};}
