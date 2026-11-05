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
