module buffer_transfer;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_growth as growth;
import buffer_close as close;

// Private native ownership handoff. The owning argument moves into exactly one
// result arm, including rejection. The trusted caller binds token/table/ledger
// to this native allocation; length/capacity alone cannot prove that association.
// No allocation, payload copy, owner creation/retirement or charge change occurs.
// A future guest adapter must independently prove and clear its source binding.
pub fn usize cost(){return 128;}
pub fn Result<bytes::Buffer,bytes::Buffer> handoff(bytes::Buffer root,
    owners::Token source,ref owners::Table table,ref growth::Ledger ledger,
    ref close::Plan closing,ref mut usize fuel){
    let usize available=*fuel;
    if(available<cost()){return .err(root);};
    *fuel=available-cost();
    if(closing.active){return .err(root);}
    // Token and whole-table admission precede native backing metadata access.
    let owners::Owner owner=switch(owners::writable(table,source)){
        case .ok(v):{v}case .err(_):{return .err(root);}
    };
    let usize accounted=switch(owners::accounted(table)){
        case .ok(v):{v}case .err(_):{return .err(root);}
    };
    // Covers every existing root, not only the selected resource. An in-flight
    // replacement/close must settle before root ownership can be handed away.
    if(!growth::settled(ledger) || ledger.used<accounted ||
        bytes::len(ref root)!=owner.length || bytes::capacity(ref root)!=owner.capacity){return .err(root);}
    return .ok(root);
}
