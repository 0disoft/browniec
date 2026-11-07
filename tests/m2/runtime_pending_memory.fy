module tests::m2::runtime_pending_memory;
import runtime_pending_memory as memory;

fn void planned(usize scratch,usize output_limit,usize core_size,usize machine_size,usize expected){
    switch(memory::prepare(scratch,output_limit,core_size,machine_size)){
        case .ok(v):{assert(v.retained==expected && v.peak==expected);}
        case .err(_):{assert(false);}
    };
}
fn void rejected(usize scratch,usize output_limit,usize core_size,usize machine_size){
    switch(memory::prepare(scratch,output_limit,core_size,machine_size)){
        case .ok(_):{assert(false);}
        case .err(e):{assert(e.kind==5 && e.offset==0);}
    };
}

@test
fn void fixed_oracles_count_cached_scratch_exact_core_and_eight_inline_machines(){
    // Literal independent totals distinguish exact Core storage from rounding,
    // Vec8 Machine storage from one element, and scratch from duplicate input.
    planned(0,0,1,1,625);
    planned(0,1,1,1,626);
    planned(12345,37,1001,73,14583);
    planned(24576,64,4097,257,31409);
    planned(90112,1048576,131073,4097,1303153);
}

@test
fn void output_payload_zero_and_limit_boundaries_keep_the_fixed_header(){
    planned(0,0,1,1,625);
    planned(0,1048575,1,1,1049200);
    planned(0,1048576,1,1,1049201);
    rejected(0,1048577,1,1);
    rejected(0,18446744073709551615,1,1);
}

@test
fn void either_zero_native_size_is_invalid_even_with_valid_output(){
    rejected(0,0,0,1);
    rejected(0,0,1,0);
    rejected(0,0,0,0);
    rejected(24576,1048576,0,73);
    rejected(24576,1048576,1001,0);
}

@test
fn void machine_capacity_multiplication_and_combined_overflow_are_checked(){
    // 2^61 cannot be multiplied by eight in usize. One less multiplies
    // safely but cannot coexist with the header and one-byte Core.
    rejected(0,0,1,2305843009213693952);
    rejected(0,0,1,18446744073709551615);
    rejected(0,0,1,2305843009213693951);
    planned(0,0,1,2305843009213693874,18446744073709551609);
    rejected(0,0,1,2305843009213693875);
}

@test
fn void each_addition_rejects_overflow_without_wrapping(){
    rejected(18446744073709551615,0,1,1);
    // scratch + header overflows by one.
    rejected(18446744073709551000,0,1,1);
    // scratch + header fits exactly; adding payload overflows by one.
    rejected(18446744073709550999,1,1,1);
    // Header + Core overflows by one.
    rejected(0,0,18446744073709551000,1);
    // Header + Core fits exactly; adding Machine storage overflows.
    rejected(0,0,18446744073709550999,1);
}

@test
fn void exact_usize_totals_succeed_and_one_more_byte_fails(){
    planned(18446744073709550990,0,1,1,18446744073709551615);
    rejected(18446744073709550991,0,1,1);
    planned(0,0,18446744073709550991,1,18446744073709551615);
    rejected(0,0,18446744073709550992,1);
    planned(18446744073708502414,1048576,1,1,18446744073709551615);
    rejected(18446744073708502415,1048576,1,1);
}

@test
fn void trusted_native_sizes_and_scratch_have_no_extra_policy_cap(){
    planned(4294967296,0,1073741824,536870912,9663677032);
}
