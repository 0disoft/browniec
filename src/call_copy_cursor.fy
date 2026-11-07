module call_copy_cursor;

// Trusted owning-execution recipe, never guest/raw-IR authority. The parent pins
// the exact table, catalog, argument descriptors and backing region, keeps every
// original source immutable, and runs no other guest instruction until finished.
// The parent also freezes reserve_first: it selects diagnostic order, never
// external/raw authority. Metadata revalidation cannot infer the chosen mode.
// No table, payload snapshot, pointer or provisional owner lives in this state.
// phase 0 validates ALL source bools; phase 1 copies unpublished destinations.
// index selects an argument. at counts source payload bytes in phase 0, or
// destination bytes INCLUDING reservation padding in phase 1. written counts
// destination bytes only. total/last also count each bool validation read.
// The parent carries total across instructions and resets last once per batch.
pub struct State {
    bool active; bool reserve_first; u8 phase; usize index; usize at;
    usize mark; usize end; usize depth; usize count;
    usize written; usize total; usize last;
    usize[8] source_slots; usize[8] source_generations;
    usize[8] source_bases; usize[8] source_ends;
    usize[8] target_slots; usize[8] target_generations;
    // Trusted VM bookkeeping only; ignored by the copy kernel and never source
    // or reservation authority. pending lasts until frame publication; active
    // tracks only kernel progress (zero arguments start inactive).
    bool pending; bool charged;
    usize pc; usize frame; usize offset; usize target;
    usize fuel_before; usize captured; usize remaining;
}
pub fn usize chunk_limit(){return 4096;}
pub fn State empty(){
    return State{.active=false,.reserve_first=false,.phase=0,.index=0,.at=0,
        .mark=0,.end=0,.depth=0,.count=0,.written=0,.total=0,.last=0,
        .source_slots=[0;8],.source_generations=[0;8],
        .source_bases=[0;8],.source_ends=[0;8],
        .target_slots=[0;8],.target_generations=[0;8],
        .pending=false,.charged=false,.pc=0,.frame=0,.offset=0,.target=0,
        .fuel_before=0,.captured=0,.remaining=0};
}
