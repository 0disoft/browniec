module tests::m2::array_lease_authentication;
import array_owners as owners;
import array_layout as layouts;
import std::bytes as bytes;

// Original b292981 leased resolver and wrappers, before single-pass reuse.
fn Result<owners::Owner,owners::Error> original(ref owners::Table table,owners::ReadLease lease,
    ref owners::View view,usize capacity){
    let owners::Owner owner=owners::inspect_return_owner(table,lease.root,capacity)?;
    if(owner.element==0){return .err(.Type);}
    if(owner.writing){return .err(.State);}
    if(!owner.reading || lease.generation==0 || lease.generation!=owner.read_generation){return .err(.State);}
    if(view.root.slot!=lease.root.slot || view.root.generation!=lease.root.generation){return .err(.Token);}
    return .ok(owner);
}
fn Result<i64,owners::Error> original_read(ref owners::Table t,owners::ReadLease l,ref owners::View v,usize i,ref u8[] b){
    let owners::Owner owner=original(t,l,v,b.len)?;return owners::view_read(t,v,i,b);
}
fn Result<usize,owners::Error> original_length(ref owners::Table t,owners::ReadLease l,ref owners::View v,usize capacity){
    let owners::Owner owner=original(t,l,v,capacity)?;return owners::view_length(t,v,capacity);
}
fn Result<bool,owners::Error> original_utf8(ref owners::Table t,owners::ReadLease l,ref owners::View v,ref u8[] b){
    let owners::Owner owner=original(t,l,v,b.len)?;return owners::view_utf8(t,v,b);
}
fn u8 tag(owners::Error e){return switch(e){
    case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}
    case .Metadata:{6}case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}};
}
fn void same(ref owners::Table t,owners::ReadLease l,ref owners::View v,usize index,ref u8[] b){
    let Result<i64,owners::Error> a=original_read(t,l,v,index,b);
    let Result<i64,owners::Error> x=owners::leased_read(t,l,v,index,b);
    assert(switch(a){case .ok(n):{switch(x){case .ok(m):{n==m}case .err(_):{false}}}
        case .err(e):{switch(x){case .ok(_):{false}case .err(f):{tag(e)==tag(f)}}}});
    let Result<usize,owners::Error> c=original_length(t,l,v,b.len);
    let Result<usize,owners::Error> y=owners::leased_length(t,l,v,b.len);
    assert(switch(c){case .ok(n):{switch(y){case .ok(m):{n==m}case .err(_):{false}}}
        case .err(e):{switch(y){case .ok(_):{false}case .err(f):{tag(e)==tag(f)}}}});
    let Result<bool,owners::Error> d=original_utf8(t,l,v,b);
    let Result<bool,owners::Error> z=owners::leased_utf8(t,l,v,b);
    assert(switch(d){case .ok(n):{switch(z){case .ok(m):{n==m}case .err(_):{false}}}
        case .err(e):{switch(z){case .ok(_):{false}case .err(f):{tag(e)==tag(f)}}}});
}
fn owners::Token create(ref mut owners::Table t,u8 element,usize n,ref mut u8[] b){
    let layouts::Array shape=switch(layouts::scalar(element,n)){
        case .ok(a):{a}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};
    return switch(owners::create(ref shape,1,b,t)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn owners::ReadLease begin(ref mut owners::Table t,owners::Token root,usize capacity){
    return switch(owners::begin_read(t,root,capacity)){case .ok(v):{v}case .err(_):{assert(false);owners::ReadLease{.root=root,.generation=0}}};
}
fn owners::View view(owners::Token root,u8 element,usize n){
    return owners::View{.root=root,.element=element,.length=n,.start=0,.end=n};
}
fn void corrupt(ref owners::Table clean,owners::ReadLease lease,ref owners::View v,usize slot,usize mode,ref u8[] b){
    var owners::Table t=*clean;
    if(mode==0){t.order[slot]=16;}
    else if(mode==1){t.order[slot]=0;}
    else if(mode==2){t.slots[slot].generation=0;}
    else if(mode==3){t.slots[slot].generation+=1;}
    else if(mode==4){t.slots[slot].occupied=false;}
    else if(mode==5){t.slots[slot].live=false;}
    else if(mode==6){t.slots[slot].mark=18446744073709551615;}
    else if(mode==7){t.slots[slot].base=18446744073709551615;}
    else if(mode==8){t.slots[slot].end=18446744073709551615;}
    else if(mode==9){t.slots[slot].element=255;}
    else if(mode==10){t.slots[slot].length=4097;}
    else if(mode==11){t.slots[slot].record=1;}
    else if(mode==12){t.slots[slot].alignment=3;}
    else if(mode==13){t.slots[slot].writing=true;}
    else if(mode==14){t.slots[slot].read_generation=0;}
    else if(mode==15){t.slots[slot].reading=false;}
    else if(mode==16){t.slots[slot].reading=true;}
    else if(mode==17){t.depth=17;}
    else if(mode==18){t.arena.used+=1;}
    else{t.arena.limit=18446744073709551615;}
    same(ref t,lease,v,0,b);
    // Combined faults must preserve lease/table errors before view/element bounds.
    var owners::View bad=*v;bad.root.slot=16;bad.element=255;bad.start=4097;
    same(ref t,lease,ref bad,4096,b);
}
@test fn void metadata_and_descriptor_errors_match_original_leased_operations(){
    var u8[32] b=[1;32];var owners::Table t=owners::empty(32);
    let owners::Token root=create(ref mut t,10,2,ref mut b);
    let owners::ReadLease lease=begin(ref mut t,root,32);let owners::View v=view(root,10,2);
    var usize count=1;while(count<=16){
        same(ref t,lease,ref v,0,ref b);
        if(count==1 || count==8 || count==16){var usize slot=0;while(slot<16){
            var usize mode=0;while(mode<20){corrupt(ref t,lease,ref v,slot,mode,ref b);mode+=1;}slot+=1;}}
        if(count==16){break;}
        let owners::Token next=create(ref mut t,10,1,ref mut b);count+=1;
    }
    var usize mode=0;while(mode<14){var owners::View bad=v;var owners::ReadLease ticket=lease;
        if(mode==0){bad.root.slot=16;}else if(mode==1){bad.root.generation+=1;}
        else if(mode==2){bad.element=2;}else if(mode==3){bad.length=4096;}
        else if(mode==4){bad.start=3;}else if(mode==5){bad.end=3;}
        else if(mode==6){bad.start=18446744073709551615;bad.end=bad.start;}
        else if(mode==7){bad.start=2;bad.end=2;}else if(mode==8){ticket.generation=0;}
        else if(mode==9){ticket.generation+=1;}else if(mode==10){ticket.root.slot=16;}
        else if(mode==11){ticket.root.generation=0;}else if(mode==12){bad.root.slot=1;}
        else{ticket.root.slot=1;}
        same(ref t,ticket,ref bad,0,ref b);same(ref t,ticket,ref bad,2,ref b);
        same(ref t,ticket,ref bad,0,b"");mode+=1;
    }
}
fn void maximum_case(u8 element,ref mut u8[] b){
    var owners::Table t=owners::empty(b.len);
    let owners::Token root=create(ref mut t,element,4096,b);
    let owners::ReadLease lease=begin(ref mut t,root,b.len);var owners::View v=view(root,element,4096);
    same(ref t,lease,ref v,0,b);same(ref t,lease,ref v,4095,b);same(ref t,lease,ref v,4096,b);
    v.start=4095;same(ref t,lease,ref v,0,b);v.start=4096;same(ref t,lease,ref v,0,b);
    v.start=0;if(element==2 || element==10){b[4095]=255;same(ref t,lease,ref v,4095,b);}
    assert(owners::end_read(ref mut t,lease,b.len).is_ok);
    let owners::ReadLease fresh=begin(ref mut t,root,b.len);
    same(ref t,lease,ref v,0,b);same(ref t,fresh,ref v,0,b);
    assert(owners::end_read(ref mut t,fresh,b.len).is_ok && owners::clear(ref mut t,b.len).is_ok);
    let owners::Token replacement=create(ref mut t,element,1,b);
    same(ref t,fresh,ref v,0,b);
}
@test fn void maximum_leased_arrays_keep_scalar_validation_utf8_and_stale_epoch_guards(){
    var bytes::Buffer backing=switch(bytes::with_capacity(32768)){
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(bytes::resize_zeroed(ref mut backing,32768).is_ok);
    let u8[6] elements=[1,9,10,11,12,2];var usize i=0;
    while(i<6){maximum_case(elements[i],bytes::view_mut(ref mut backing));i+=1;}
}
