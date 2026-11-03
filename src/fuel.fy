module fuel;

// Abstract work units, not machine instructions or elapsed time. See
// docs/engineering/m2-slice-result-fuel.md for the bounded metadata audit.
pub fn usize cli_default(){return 256;}
pub fn usize cli_limit(){return 1000000;}
pub fn usize metadata_visit_budget(){return 2048;}
pub fn usize transaction_base(){return 32768;}
pub fn usize cleanup_reserve(){return 65536;}
pub fn usize result_enter(){return transaction_base()+24*metadata_visit_budget()+cleanup_reserve();}
pub fn usize result_handoff(){return transaction_base()+96*metadata_visit_budget()+cleanup_reserve();}
pub fn usize result_leave(){return transaction_base()+80*metadata_visit_budget();}

// The existing public slice schedule. Payload width and UTF-8 scans are charged
// separately from metadata. Callers prove stride <= 8 and root length <= 4096.
pub fn usize slice_base(u8 op,usize stride){
    if(op==54 || op==59 || op==61 || op==62){return 65537;}
    if(op==58){return 4130+stride;}
    if(op==60){return 4130+2*stride;}
    return 4097;
}
pub fn usize utf8_scan(usize root_length){return 4*root_length;}
