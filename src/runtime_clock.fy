module runtime_clock;

@link_name("bc_runtime_engine_monotonic_ticks") unsafe extern C fn usize monotonic_ticks_raw();
@link_name("bc_runtime_engine_deadline_reached") unsafe extern C fn u32 deadline_reached_raw(usize deadline);

pub fn usize now(){return unsafe{monotonic_ticks_raw()};}
pub fn bool expired(usize deadline){return unsafe{deadline_reached_raw(deadline)}!=0;}
