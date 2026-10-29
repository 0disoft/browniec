module buffer_truncate;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_growth as growth;

// Private logical shortening. Capacity and its admitted charge are retained.
pub enum Error { Token; Owners; State; Overflow; Quota; Bounds; Provider; }
pub fn Result<owners::Token,Error> to_length(ref mut owners::Table table,
    owners::Token source,ref mut bytes::Buffer buffer,usize length,
    growth::Limits limits,ref growth::Ledger ledger) {
    let owners::Owner owner=switch(owners::writable(table,source)) {
        case .ok(value):{value}
        case .err(e):{return .err(switch(e){case .Token:{.Token}case .Owners:{.Owners}
            case .State:{.State}case .Bounds:{.State}});}
    };
    if(bytes::len(buffer)!=owner.length || bytes::capacity(buffer)!=owner.capacity) {return .err(.State);}
    // Shortening retains the allocation: require clean, currently admitted usage.
    switch(growth::plan(owner.capacity,owner.capacity,limits,ledger)) {
        case .ok(_):{}
        case .err(e):{return .err(switch(e){case .State:{.State}case .Overflow:{.Overflow}
            case .Quota:{.Quota}case .NoGrowth:{.State}});}
    };
    if(length>owner.length) {return .err(.Bounds);}
    if(length==owner.length) {return .ok(source);}
    if(owner.generation==18446744073709551615) {return .err(.Owners);}
    let usize actual=switch(bytes::truncate(buffer,length)) {
        case .ok(value):{value}case .err(_):{return .err(.Provider);}
    };
    if(actual!=length || bytes::len(buffer)!=length || bytes::capacity(buffer)!=owner.capacity) {return .err(.Provider);}
    // The trusted SDK has shortened the root; no fallible operation follows.
    let owners::Token next=owners::Token{.slot=source.slot,.generation=owner.generation+1};
    table.slots[next.slot].length=length;table.slots[next.slot].generation=next.generation;
    return .ok(next);
}
// Logical clear is not secure erasure of retained allocation bytes.
pub fn Result<owners::Token,Error> clear(ref mut owners::Table table,
    owners::Token source,ref mut bytes::Buffer buffer,growth::Limits limits,ref growth::Ledger ledger) {
    return to_length(table,source,buffer,0,limits,ledger);
}
