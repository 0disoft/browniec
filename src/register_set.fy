module register_set;

// The private IR has at most 128 absolute register IDs on the 64-bit target.
pub struct Set { usize low; usize high; }
pub fn Set empty() { return Set { .low = 0, .high = 0 }; }
pub fn bool contains(ref Set set, usize register) {
    let usize one = 1;
    if (register < 64) { return (set.low & (one << register)) != 0; }
    if (register < 128) { return (set.high & (one << (register - 64))) != 0; }
    return false;
}
// Callers validate the function's register range before defining a value.
pub fn void insert(ref mut Set set, usize register) {
    let usize one = 1;
    if (register < 64) { set.low |= one << register; }
    else { assert(register < 128); set.high |= one << (register - 64); }
}
