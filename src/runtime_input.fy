module runtime_input;
import std::bytes as bytes;

// Private native input owner, not an Instance, source loader or entry dispatcher.
pub enum Error { Limit; Fuel; Allocation; Bounds; }
pub struct Observation { usize length; usize charged; }
pub resource Snapshot { bytes::Buffer backing; usize charged; cleanup { } }
pub fn usize hard_limit(){return 1048576;}

// Caller supplies its trusted charge. No existing guest price is introduced.
// All preparation is unpublished; every error preserves caller Fuel and bytes.
pub fn Result<Snapshot,Error> snapshot(ref u8[] input,usize limit,usize charge,ref mut usize fuel){
    if(limit>hard_limit() || input.len>limit){return .err(.Limit);}
    if(charge>*fuel){return .err(.Fuel);}
    let bytes::Buffer backing=switch(bytes::copy(input)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    *fuel-=charge;return .ok(Snapshot{.backing=backing,.charged=charge});
}
pub fn Observation observe(ref Snapshot input){
    return Observation{.length=bytes::len(ref input.backing),.charged=input.charged};
}
pub fn usize capacity(ref Snapshot input){return bytes::capacity(ref input.backing);}
pub fn ref u8[] view(ref Snapshot input){return bytes::view(ref input.backing);}
pub fn Result<ref u8[],Error> range(ref Snapshot input,usize begin,usize length){
    let ref u8[] data=view(input);
    if(begin>data.len || length>data.len-begin){return .err(.Bounds);}
    return .ok(data[begin..begin+length]);
}
