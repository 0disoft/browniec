module buffer_owners;

import std::bytes as bytes;

// Private descriptors. The trusted Instance binds each slot to its owning root.
// Tokens are table-local; this module neither owns nor frees native allocations.
pub struct Token { usize slot; usize generation; }
pub struct Owner { usize generation; bool live; usize length; usize capacity; }
pub struct Table { Owner[16] slots; }
pub enum Error { Token; Owners; State; Bounds; }

pub fn Table empty() {
    return Table{.slots=[Owner{.generation=1,.live=false,.length=0,.capacity=0};16]};
}
fn bool valid(ref Table table) {
    var usize i=0;
    while(i<16) {
        let Owner owner=table.slots[i];
        if(owner.live) {
            if(owner.generation==0 || owner.capacity%64!=0 ||
                owner.capacity>18446744073709551551 || owner.length>owner.capacity) {return false;}
        } else if(owner.length!=0 || owner.capacity!=0) {return false;}
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
    let Owner owner=resolve(table,token)?;
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
pub fn Result<usize,Error> write(ref Table table,Token token,usize index,u8 value,ref mut bytes::Buffer buffer) {
    let usize at=address(table,token,index,buffer)?;
    let ref mut u8[] view=bytes::view_mut(buffer);view[at]=value;
    return .ok(at);
}
