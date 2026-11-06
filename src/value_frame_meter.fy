module value_frame_meter;
import buffer_growth as growth;

pub enum Error { Fuel; Bounds; Quota; State; }
// Private template policy charges, not native sizeof/RAM or guest prices.
pub fn usize metadata_charge(){return 12288;}
pub fn Result<usize,Error> capacity(usize width){
    if(width>1048576){return .err(.Bounds);}
    return .ok(((width+63)/64)*64);
}
pub fn Result<usize,Error> charge(usize width){
    let usize rounded=capacity(width)?;return .ok(rounded+64);
}
pub fn Result<usize,Error> setup_cost(usize largest){
    if(largest>65536){return .err(.Bounds);}return .ok(16384+4*largest);
}
// Includes bounded native cleanup prepaid by frame admission.
pub fn Result<usize,Error> enter_cost(usize width){
    if(width>1048576){return .err(.Bounds);}return .ok(32768+8*width);
}
pub fn Result<usize,Error> operation_cost(usize width){
    if(width>65536){return .err(.Bounds);}return .ok(2048+4*width);
}
pub fn Result<usize,Error> pay(usize amount,ref mut usize fuel){
    let usize available=*fuel;if(available<amount){return .err(.Fuel);};
    *fuel=available-amount;return .ok(amount);
}
// The coordinator owns frame usage separately. This preflight never changes
// root counters/peaks, and frame backing does not consume a Buffer object cap.
pub fn Result<usize,Error> admit(usize current,usize additional,
    ref growth::Ledger roots,growth::Limits limits){
    if(!growth::settled(roots)){return .err(.State);}
    if(additional>18446744073709551615-current){return .err(.Bounds);}
    let usize next=current+additional;
    if(next>18446744073709551615-roots.used ||
        next>18446744073709551615-roots.engine_used){return .err(.Bounds);}
    if(roots.used+next>limits.instance || roots.engine_used+next>limits.engine){return .err(.Quota);}
    return .ok(next);
}
// Pass the resulting root budget to Buffer admission without changing its
// independent per-object policy. Subtraction cannot wrap on a rejected budget.
pub fn Result<growth::Limits,Error> remaining(usize frame_used,growth::Limits limits){
    if(frame_used>limits.instance || frame_used>limits.engine){return .err(.Quota);}
    return .ok(growth::Limits{.object=limits.object,
        .instance=limits.instance-frame_used,.engine=limits.engine-frame_used});
}
