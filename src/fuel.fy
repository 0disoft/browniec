module fuel;

// Abstract work units, not machine instructions or elapsed time. See
// docs/engineering/m2-slice-result-fuel.md for the bounded metadata audit.
pub fn usize cli_default(){return 256;}
pub fn usize cli_limit(){return 16000000;}
pub fn usize metadata_visit_budget(){return 2048;}
pub fn usize transaction_base(){return 32768;}
pub fn usize cleanup_reserve(){return 65536;}
pub fn usize result_enter(){return transaction_base()+24*metadata_visit_budget()+cleanup_reserve();}
pub fn usize result_handoff(){return transaction_base()+96*metadata_visit_budget()+cleanup_reserve();}
pub fn usize result_leave(){return transaction_base()+80*metadata_visit_budget();}

// Callers authenticate scalar layouts (stride 1/4/8, length 1..4096) before
// pricing. Invalid opcodes have no price; dispatch remains included here.
pub fn Option<usize> array_instruction(u8 op,usize stride,usize length,bool boolean){
    let usize size=stride*length;
    if(op==51){return .some(33+4*length);}
    if(op==33){return .some(49+2*stride+size+7);}
    if(op==34){return .some(49+size+7+if(boolean){length}else{0});}
    if(op==35){return .some(33+stride);}
    if(op==36){return .some(33+2*stride);}
    if(op==37){return .some(49);}
    if(op==38){return .some(81+size+if(boolean){length}else{0});}
    if(op==40){return .some(49+2*stride+size);}
    return .none;
}
// Fixed record envelopes cover complete catalog planning, bounded traversal,
// codec staging, padding and owner scans, not machine-instruction counts.
pub fn Option<usize> record_instruction(u8 op){
    if(op==41 || op==48){return .some(2*18432+2*4096+1024+65);}
    if(op==42){return .some(2*18432+4096+1024+65);}
    if(op==43 || op==44){return .some(2*18432+4096+256+65);}
    if(op==45){return .some(65);}
    if(op==46){return .some(3*18432+4096+1024+129);}
    if(op==47){return .some(131072);}
    if(op==49){return .some(4*18432+3*4096+1024+65);}
    return .none;
}
// Preparation is paid once per invocation; list operands reuse their scratch.
// Validated maxima are 4096 cells and 32768 bytes; no-list setup is free.
pub fn usize list_prepare(usize cells,usize size){return if(cells==0){0}else{257+2*cells+size};}
pub fn usize list_instruction(bool replacement,usize cells,usize size){return (if(replacement){49}else{56})+cells+3*size;}

// Shared and exclusive calls prepay retention/restoration and abort work.
// Callers validate readers+writers <= 8 before pricing. No payload term here.
pub fn usize slice_call(usize readers,usize writers){
    return if(readers+writers==0){0}else{slice_base(54,0)*(1+readers+2*writers)};
}

// The existing public slice schedule. Payload width and UTF-8 scans are charged
// separately from metadata. Callers prove stride <= 8 and root length <= 4096.
pub fn usize slice_base(u8 op,usize stride){
    if(op==54 || op==59 || op==61 || op==62){return 65537;}
    if(op==58){return 4130+stride;}
    if(op==60){return 4130+2*stride;}
    return 4097;
}
pub fn usize utf8_scan(usize root_length){return 4*root_length;}

// Private immutable-image operations. Driver charges dispatch separately;
// OPEN/BYTES/ALIAS have bounded metadata cost. Lengths are proved <=4096
// before this arithmetic; no owner/loan table scans.
pub fn usize static_instruction(u8 op,usize left,usize right){
    if(op==70){return 0;}
    if(op==76){return 127;}
    return 16+if(op==71){1}else if(op==73){left+right}else{0};
}

// Private image CALLs move at most eight descriptors, never payload bytes.
// Base covers clearing/staging frame words; each actual checks both root sets.
// Native ownership entry/leave, argument copies and dispatch remain additive.
pub fn usize static_call(usize arguments){return 32+32*arguments;}
// Two bounded root scans plus clearing the sixteen consumed child words.
pub fn usize static_return(){return 48;}

// Generic formals additionally authenticate each runtime actual once; native
// entry/leave and owned value copies remain their existing separate charges.
pub fn usize reference_call(usize arguments,usize runtime){return static_call(arguments)+4097*runtime;}
pub fn usize reference_parameter(bool runtime){return 16+if(runtime){4097}else{0};}
// Two sparse receipt lookups (47 each) and one alias scan (16), rounded up.
// Physical close remains prepaid by the native handoff that issued Held.
pub fn usize reference_result_close(){return 128;}
// Returned-selector lookup/publication work is additive to existing prices.
pub fn usize reference_result_lookup(){return 64;}
pub fn usize reference_return(){return 512;}

// Selected-place metadata is invocation-local. Width is independently bounded
// to 0..16; 32 frames have one counter plus nine 64-bit words per location.
// Prepay byte initialization plus publication/destruction visits; old programs pay 0.
pub fn usize place_prepare(usize width){return if(width==0){0}else{257+10*32*(9*width+1)};}
// Ordinary prices include dispatch. Retained execution adds its existing unit.
// SELECT/READ/STORE cover 32 owner visits plus snapshot/slot metadata; the codec
// reads stride bytes or stages+writes twice that width. END clears one slot.
pub fn usize place_instruction(u8 op,usize stride){
    if(op==86){return 17;}if(op==84){return 65+stride;}if(op==85){return 65+2*stride;}return 65;
}

// New mixed/slice frames keep a format word and fourteen words per location.
// Existing array-only setup and instruction prices above remain unchanged.
pub fn usize slice_place_prepare(usize width){return if(width==0){0}else{257+10*(1+32*(14*width+1))};}
// Reuse the complete sixteen-slot pool/session envelope, then add 32 visits for
// decoding/publishing the larger snapshot and frame state. No payload scan.
pub fn usize slice_place_instruction(u8 op,usize stride){
    if(op==86){return 22;}
    if(op==84){return slice_base(58,stride)+32;}
    if(op==85){return slice_base(60,stride)+32;}
    return slice_base(57,0)+32;
}

// Record-capable mixed frames add a second authenticated format word. Existing
// array/slice rows and prices are unchanged. Width is proved <=16 before use.
pub fn usize record_place_prepare(usize width){return if(width==0){0}else{257+10*(2+32*(14*width+1))};}
// Two complete catalog plans, bounded depth-first leaf resolution, owner-ledger
// authentication and snapshot work fit the existing transaction envelope plus
// four metadata budgets. Only the selected scalar contributes payload work.
pub fn usize record_place_instruction(u8 op,usize stride){
    if(op==86){return 22;}
    let usize metadata=transaction_base()+4*metadata_visit_budget()+65;
    return metadata+if(op==84){stride}else if(op==85){2*stride}else{0};
}
