module buffer_write;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_growth as growth;

// Replace initialized bytes from distinct caller-owned input, without resizing.
pub enum Error { Token; Owners; State; Overflow; Quota; Bounds; }
pub fn Result<usize,Error> within_length(ref owners::Table table,owners::Token source,
    usize start,ref mut bytes::Buffer buffer,ref u8[] input,growth::Limits limits,ref growth::Ledger ledger) {
    let owners::Owner owner=switch(owners::writable(table,source)) {
        case .ok(value):{value}
        case .err(e):{return .err(switch(e){case .Token:{.Token}case .Owners:{.Owners}
            case .State:{.State}case .Bounds:{.State}});}
    };
    if(bytes::len(buffer)!=owner.length || bytes::capacity(buffer)!=owner.capacity) {return .err(.State);}
    // A pending replacement must not lose changes made after its prefix was copied.
    switch(growth::plan(owner.capacity,owner.capacity,limits,ledger)) {
        case .ok(_):{}
        case .err(e):{return .err(switch(e){case .State:{.State}case .Overflow:{.Overflow}
            case .Quota:{.Quota}case .NoGrowth:{.State}});}
    };
    if(start>owner.length) {return .err(.Bounds);}
    if(input.len>owner.length-start) {return .err(.Bounds);}
    let ref mut u8[] view=bytes::view_mut(buffer);
    var usize i=0;
    while(i<input.len) {view[start+i]=input[i];i+=1;}
    // Content writes keep the same token and extent, matching owners::write.
    return .ok(input.len);
}
