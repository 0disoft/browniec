module runtime_lifecycle_work;
import runtime_setup_work as setup;
import runtime_preparation_work as proof;
import runtime_cleanup_work as cleaning;
// Control only. Large unpublished cleanup uses Core's existing transaction bank.
// 0 proof, 1 buffers, 2 input, 3 typed Core, 4 entry, 5 guest, 6 seal-ready,
// 7 cleanup start, 8 sessions, 9 places, 10 publication, 11 terminal.
pub struct State { setup::State setup; proof::State proof; cleaning::State cleaning;
    usize phase; usize index; usize place; u8 terminal; }
pub fn State empty(){return State{.setup=setup::empty(),.proof=proof::empty(),.cleaning=cleaning::empty(),
    .phase=0,.index=0,.place=0,.terminal=0};}
