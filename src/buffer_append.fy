module buffer_append;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_growth as growth;

// Private append into already-admitted capacity. No implicit reserve/retry.
pub enum Error { Token; Owners; State; Overflow; Quota; Capacity; Provider; }
pub fn Result<owners::Token,Error> within_capacity(ref mut owners::Table table,
    owners::Token source,ref mut bytes::Buffer buffer,ref u8[] input,
    growth::Limits limits,ref growth::Ledger ledger) {
    let owners::Owner owner=switch(owners::describe(table,source)) {
        case .ok(value):{value}
        case .err(e):{return .err(switch(e){case .Token:{.Token}case .Owners:{.Owners}
            case .State:{.State}case .Bounds:{.State}});}
    };
    if(bytes::len(buffer)!=owner.length || bytes::capacity(buffer)!=owner.capacity) {return .err(.State);}
    // Also reject pending reservations and corrupt/over-limit accounting for no-growth writes.
    switch(growth::plan(owner.capacity,owner.capacity,limits,ledger)) {
        case .ok(_):{}
        case .err(e):{return .err(switch(e){case .State:{.State}case .Overflow:{.Overflow}
            case .Quota:{.Quota}case .NoGrowth:{.State}});}
    };
    if(input.len>owner.capacity-owner.length) {return .err(.Capacity);}
    if(input.len==0) {return .ok(source);}
    if(owner.generation==18446744073709551615) {return .err(.Owners);}
    let usize length=owner.length+input.len;
    let usize actual=switch(bytes::append(buffer,input)) {
        case .ok(value):{value}case .err(_):{return .err(.Provider);}
    };
    if(actual!=length || bytes::len(buffer)!=length || bytes::capacity(buffer)!=owner.capacity) {return .err(.Provider);}
    // Native SDK append succeeded; no allocation or fallible operation follows.
    let owners::Token next=owners::Token{.slot=source.slot,.generation=owner.generation+1};
    table.slots[next.slot].length=length;table.slots[next.slot].generation=next.generation;
    return .ok(next);
}
