module tests::cells;

import cells as cells;

fn i64 packed(usize n) {
    return switch(cells::pack(n,0)) {case .ok(value): {value} case .err(_): {assert(false);0}};
}
fn usize unpacked(i64 n) {
    return switch(cells::unpack(n,0)) {case .ok(value): {value} case .err(_): {assert(false);0}};
}
@test
fn void canonical_unsigned_cell_edges() {
    let usize[8] inputs=[0,1,255,4294967295,9223372036854775807,9223372036854775808,9223372036854775809,18446744073709551615];
    let i64[8] expected=[0,1,255,4294967295,9223372036854775807,-9223372036854775808,-9223372036854775807,-1];
    var usize i=0;
    while(i<inputs.len) {
        assert(packed(inputs[i])==expected[i]);
        assert(unpacked(expected[i])==inputs[i]);
        i+=1;
    }
}
@test
fn void unsigned_cells_roundtrip_every_bit() {
    var usize power=1;
    var usize bit=0;
    while(bit<64) {
        assert(unpacked(packed(power))==power);
        assert(unpacked(packed(power-1))==power-1);
        let usize complement=18446744073709551615-power;
        assert(unpacked(packed(complement))==complement);
        bit+=1;
        if(bit<64) {power*=2;}
    }
}
