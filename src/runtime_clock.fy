module runtime_clock;

@link_name("bc_runtime_engine_monotonic_ticks") unsafe extern C fn usize monotonic_ticks_raw();

pub fn usize now(){return unsafe{monotonic_ticks_raw()};}
pub fn bool expired(usize deadline){return deadline!=0 && now()>=deadline;}
