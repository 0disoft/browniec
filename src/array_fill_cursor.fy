module array_fill_cursor;

// Trusted owning-execution recipe, never guest/raw-IR authority. The parent pins
// the table/backing region and freezes every other guest opcode while active.
// written counts this instruction, including CREATE/COPY alignment padding. total is
// carried across instructions by the parent; last accumulates until it resets
// the caller batch. pc/frame/destination/offset belong to the parent dispatcher.
pub struct State {
    bool active; u8 op; usize pc; usize frame; usize destination; usize offset;
    usize slot; usize generation; usize mark; usize base; usize end; usize depth;
    usize source_slot; usize source_generation; usize source_base; usize source_end;
    u8 element; usize length; usize stride; u8[8] encoded;
    usize written; usize total; usize last;
}
pub fn usize chunk_limit(){return 4096;}
pub fn State empty(){
    return State{.active=false,.op=0,.pc=0,.frame=0,.destination=0,.offset=0,
        .slot=0,.generation=0,.mark=0,.base=0,.end=0,.depth=0,
        .source_slot=0,.source_generation=0,.source_base=0,.source_end=0,
        .element=0,.length=0,.stride=0,.encoded=[0;8],.written=0,.total=0,.last=0};
}
