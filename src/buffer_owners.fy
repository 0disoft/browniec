module buffer_owners;

import std::bytes as bytes;
import buffer_growth as growth;

// Private descriptors. The trusted Instance binds each slot to its owning root.
// Tokens are table-local; this module neither owns nor frees native allocations.
pub struct Token { usize slot; usize generation; }
pub struct Owner { usize generation; bool live; usize length; usize capacity; bool reading; }
pub struct Table { Owner[16] slots; }
pub enum Error { Token; Owners; State; Bounds; }

pub fn Table empty() {
    return Table{.slots=[Owner{.generation=1,.live=false,.length=0,.capacity=0,.reading=false};16]};
}
fn bool valid(ref Table table) {
    var usize i=0;
    while(i<16) {
        let Owner owner=table.slots[i];
        if(owner.live) {
            if(owner.generation==0 || owner.capacity%64!=0 ||
                owner.capacity>18446744073709551551 || owner.length>owner.capacity) {return false;}
        } else if(owner.length!=0 || owner.capacity!=0 || owner.reading) {return false;}
        i+=1;
    }
    return true;
}
// Check identity before inspecting any native buffer or its initialized view.
fn Result<Owner,Error> resolve(ref Table table,Token token) {
    if(token.slot>=16 || token.generation==0) {return .err(.Token);}
    let Owner owner=table.slots[token.slot];
    if(!owner.live || owner.generation!=token.generation) {return .err(.Token);}
    if(!valid(table)) {return .err(.State);}
    return .ok(owner);
}
// Metadata-only preflight for storage transactions, before native buffer access.
pub fn Result<usize,Error> accounted(ref Table table) {
    if(!valid(table)){return .err(.State);}
    var usize total=0;var usize i=0;
    while(i<16){
        if(table.slots[i].live){
            let usize charge=table.slots[i].capacity+64;
            if(charge>18446744073709551615-total){return .err(.State);}
            total+=charge;
        }
        i+=1;
    }
    return .ok(total);
}
// Metadata-only preflight for storage transactions, before native buffer access.
pub fn Result<Owner,Error> describe(ref Table table,Token token) {
    return resolve(table,token);
}
// All descriptor-aware mutation paths must use this gate before native mutation.
pub fn Result<Owner,Error> writable(ref Table table,Token token) {
    let Owner owner=resolve(table,token)?;
    if(owner.reading){return .err(.State);}
    return .ok(owner);
}
// One private read lease per root. No payload copy, allocation or usage change.
pub fn Result<Token,Error> begin_read(ref mut Table table,Token token,
    ref bytes::Buffer buffer,ref growth::Ledger ledger) {
    let Owner owner=writable(table,token)?;
    if(bytes::len(buffer)!=owner.length || bytes::capacity(buffer)!=owner.capacity){return .err(.State);}
    // Do not alter descriptor snapshots while a replacement reservation is active.
    switch(growth::plan(owner.capacity,owner.capacity,growth::Limits{
        .object=18446744073709551615,.instance=18446744073709551615,.engine=18446744073709551615},ledger)) {
        case .ok(_):{}case .err(_):{return .err(.State);}
    };
    table.slots[token.slot].reading=true;
    return .ok(token);
}
pub fn Result<usize,Error> end_read(ref mut Table table,Token token) {
    let Owner owner=resolve(table,token)?;
    if(!owner.reading){return .err(.State);}
    table.slots[token.slot].reading=false;
    return .ok(token.slot);
}
pub fn Result<Token,Error> create(ref mut Table table,ref bytes::Buffer buffer) {
    if(!valid(table)) {return .err(.State);}
    let usize length=bytes::len(buffer);let usize capacity=bytes::capacity(buffer);
    if(capacity%64!=0 || capacity>18446744073709551551 || length>capacity) {return .err(.State);}
    var usize i=0;
    while(i<16) {
        if(!table.slots[i].live && table.slots[i].generation!=0) {
            table.slots[i].live=true;table.slots[i].length=length;table.slots[i].capacity=capacity;
            return .ok(Token{.slot=i,.generation=table.slots[i].generation});
        }
        i+=1;
    }
    return .err(.Owners);
}
pub fn Result<usize,Error> release(ref mut Table table,Token token) {
    let Owner owner=writable(table,token)?;
    table.slots[token.slot].live=false;
    table.slots[token.slot].length=0;table.slots[token.slot].capacity=0;
    // Exhausted generations retire a slot permanently rather than wrapping.
    table.slots[token.slot].generation=if(owner.generation==18446744073709551615){0}else{owner.generation+1};
    return .ok(token.slot);
}
fn Result<usize,Error> address(ref Table table,Token token,usize index,ref bytes::Buffer buffer) {
    let Owner owner=resolve(table,token)?;
    if(bytes::len(buffer)!=owner.length || bytes::capacity(buffer)!=owner.capacity) {return .err(.State);}
    if(index>=owner.length) {return .err(.Bounds);}
    return .ok(index);
}
pub fn Result<u8,Error> read(ref Table table,Token token,usize index,ref bytes::Buffer buffer) {
    let usize at=address(table,token,index,buffer)?;
    let ref u8[] view=bytes::view(buffer);
    return .ok(view[at]);
}
// Read into distinct caller-owned storage; validate the complete range before writes.
pub fn Result<usize,Error> copy_out(ref Table table,Token token,usize start,
    ref bytes::Buffer buffer,ref mut u8[] output) {
    let Owner owner=resolve(table,token)?;
    if(bytes::len(buffer)!=owner.length || bytes::capacity(buffer)!=owner.capacity) {return .err(.State);}
    if(start>owner.length) {return .err(.Bounds);}
    if(output.len>owner.length-start) {return .err(.Bounds);}
    let ref u8[] view=bytes::view(buffer);
    var usize i=0;
    while(i<output.len) {
        // start + i is below initialized length; the subtraction check excludes overflow.
        output[i]=view[start+i];i+=1;
    }
    return .ok(output.len);
}
pub fn Result<usize,Error> write(ref Table table,Token token,usize index,u8 value,ref mut bytes::Buffer buffer) {
    let Owner checked=writable(table,token)?;
    if(bytes::len(buffer)!=checked.length || bytes::capacity(buffer)!=checked.capacity){return .err(.State);}
    if(index>=checked.length){return .err(.Bounds);}
    let ref mut u8[] view=bytes::view_mut(buffer);view[index]=value;
    return .ok(index);
}
