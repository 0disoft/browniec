module call_copy_cursor;

// Trusted owning-execution recipe, never guest/raw-IR authority. The parent pins
// the exact table, catalog, argument descriptors and backing region, keeps every
// original source immutable, and runs no other guest instruction until finished.
// No table, payload snapshot, pointer or provisional owner lives in this state.
// phase 0 validates ALL source bools; phase 1 copies unpublished destinations.
// index selects an argument. at counts source payload bytes in phase 0, or
// destination bytes INCLUDING reservation padding in phase 1. written counts
// destination bytes only. total/last also count each bool validation read.
// The parent carries total across instructions and resets last once per batch.
pub struct State {
    bool active; u8 phase; usize index; usize at;
    usize mark; usize end; usize depth; usize count;
    usize written; usize total; usize last;
    usize[8] source_slots; usize[8] source_generations;
    usize[8] source_bases; usize[8] source_ends;
    usize[8] target_slots; usize[8] target_generations;
}
pub fn usize chunk_limit(){return 4096;}
pub fn State empty(){
    return State{.active=false,.phase=0,.index=0,.at=0,
        .mark=0,.end=0,.depth=0,.count=0,.written=0,.total=0,.last=0,
        .source_slots=[0;8],.source_generations=[0;8],
        .source_bases=[0;8],.source_ends=[0;8],
        .target_slots=[0;8],.target_generations=[0;8]};
}
