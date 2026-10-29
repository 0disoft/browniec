module buffer_create;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_growth as growth;

// Register a distinct caller-owned empty root and admit its logical owner charge.
pub enum Error { Owners; State; Overflow; Quota; }
pub fn Result<owners::Token,Error> empty(ref mut owners::Table table,
    ref bytes::Buffer root,growth::Limits limits,ref mut growth::Ledger ledger) {
    var owners::Table staged=owners::Table{.slots=table.slots};
    let owners::Token next=switch(owners::create(ref mut staged,root)) {
        case .ok(value):{value}
        case .err(e):{return .err(switch(e){case .Owners:{.Owners}case .Token:{.State}
            case .State:{.State}case .Bounds:{.State}});}
    };
    if(staged.slots[next.slot].length!=0 || staged.slots[next.slot].capacity!=0) {return .err(.State);}
    // Existing descriptors must already be covered, even when other usage exists.
    var usize total=0;var usize i=0;
    while(i<16) {
        if(table.slots[i].live) {
            let usize charge=table.slots[i].capacity+64;
            if(charge>18446744073709551615-total) {return .err(.Overflow);}
            total+=charge;
        }
        i+=1;
    }
    if(ledger.used<total) {return .err(.State);}
    switch(growth::admit_empty(limits,ledger)) {
        case .ok(_):{}
        case .err(e):{return .err(switch(e){case .State:{.State}case .Overflow:{.Overflow}
            case .Quota:{.Quota}case .NoGrowth:{.State}});}
    };
    // The charge is admitted; no fallible operation precedes slot publication.
    table.slots[next.slot]=staged.slots[next.slot];
    return .ok(next);
}
