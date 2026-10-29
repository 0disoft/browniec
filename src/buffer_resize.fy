module buffer_resize;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_growth as growth;

// Private length change within admitted capacity; newly exposed bytes are zero.
pub enum Error { Token; Owners; State; Overflow; Quota; Capacity; Provider; }
pub fn Result<owners::Token,Error> within_capacity(ref mut owners::Table table,
    owners::Token source,ref mut bytes::Buffer buffer,usize length,
    growth::Limits limits,ref growth::Ledger ledger) {
    let owners::Owner owner=switch(owners::writable(table,source)) {
        case .ok(value):{value}
        case .err(e):{return .err(switch(e){case .Token:{.Token}case .Owners:{.Owners}
            case .State:{.State}case .Bounds:{.State}});}
    };
    if(bytes::len(buffer)!=owner.length || bytes::capacity(buffer)!=owner.capacity) {return .err(.State);}
    switch(growth::plan(owner.capacity,owner.capacity,limits,ledger)) {
        case .ok(_):{}
        case .err(e):{return .err(switch(e){case .State:{.State}case .Overflow:{.Overflow}
            case .Quota:{.Quota}case .NoGrowth:{.State}});}
    };
    if(length>owner.capacity) {return .err(.Capacity);}
    if(length==owner.length) {return .ok(source);}
    if(owner.generation==18446744073709551615) {return .err(.Owners);}
    let usize actual=switch(bytes::resize_zeroed(buffer,length)) {
        case .ok(value):{value}case .err(_):{return .err(.Provider);}
    };
    if(actual!=length || bytes::len(buffer)!=length || bytes::capacity(buffer)!=owner.capacity) {return .err(.Provider);}
    // No allocation, callback or fallible operation follows descriptor publication.
    let owners::Token next=owners::Token{.slot=source.slot,.generation=owner.generation+1};
    table.slots[next.slot].length=length;table.slots[next.slot].generation=next.generation;
    return .ok(next);
}
