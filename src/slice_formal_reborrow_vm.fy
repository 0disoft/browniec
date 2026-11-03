module slice_formal_reborrow_vm;
import ir as ir;
import errors as errors;
import fuel as meter;
import cells as cells;
import array_layout as layouts;
import array_vm as arrays;
import array_owners as owners;
import array_slices as slices;
import slice_vm as loans;
import slice_call_vm as shared;
import slice_authority as authority;
import slice_authority_call_vm as calls;
import slice_reborrow_ir as proof;
import slice_reborrow_vm as owned;
import std::bytes as bytes;

// Reuse the owned adapter's site-map layout. Canonical receipts exist only in
// authority; CALL PCs and detached formals exist only in calls::Bindings.
fn slices::Ticket none(){return slices::Ticket{.slot=16,.generation=0};}
fn bool absent(slices::Ticket t){return t.slot==16 && t.generation==0;}
fn bool same(owners::View a,owners::View b){
    return a.root.slot==b.root.slot && a.root.generation==b.root.generation && a.element==b.element &&
        a.length==b.length && a.start==b.start && a.end==b.end;
}
// 0..15 are owned roots; 16..31 are canonical formal anchors. Static only.
fn Result<usize,errors::Error> key(ref ir::Program p,ref proof::Sites sites,usize function,usize site,usize offset){
    if(p.function_count>16 || function>=p.function_count || function>=16 || site>=16 || !ir::exclusive(p,site)){return .err(errors::make(5,offset));}
    let u8 tag=ir::slice_element(p,site,offset)?;let usize root=p.slice_roots[site] as usize;
    if(root!=0){if(root>16 || root>p.arrays.count || p.slice_origins[site]!=0 || p.slice_functions[site]!=0 ||
        p.array_functions[root-1] as usize!=function || !p.arrays.mutable[root-1]){return .err(errors::make(5,offset));}return .ok(root-1);}
    let usize encoded=p.slice_origins[site] as usize;
    if(encoded==0 || encoded>16 || p.slice_functions[site] as usize!=function+1){return .err(errors::make(5,offset));}
    let usize anchor=encoded-1;
    if(p.slice_roots[anchor]!=0 || p.slice_origins[anchor] as usize!=encoded || p.slice_functions[anchor] as usize!=function+1 ||
        !ir::exclusive(p,anchor) || ir::borrow_element(p,anchor)!=tag || sites.parents[anchor]!=16){return .err(errors::make(5,offset));}
    var usize cursor=site;var usize count=0;while(cursor!=anchor){
        if(cursor>=16 || count>=15 || sites.parents[cursor]>=16){return .err(errors::make(5,offset));}cursor=sites.parents[cursor];count+=1;
    }return .ok(16+anchor);
}
pub fn Result<usize,errors::Error> checked(ref ir::Program p,ref proof::Sites sites,ref owned::Bindings bindings,
    ref calls::Bindings call_bindings,ref authority::State receipts,ref shared::Frames frames,
    ref loans::State loan,ref arrays::State state,usize capacity,usize offset){
    let usize depth=calls::inspect(p,call_bindings,receipts,frames,loan,state,offset)?;
    var usize i=0;while(i<31){
        if(receipts.kinds[i]==2){
            let usize child=bindings.children[i];let usize parent=bindings.parents[i];let usize function=bindings.functions[i];let usize frame=receipts.frames[i];
            if(child>=16 || parent>=16 || child==parent || sites.parents[child]!=parent || !absent(loan.tickets[frame*16+parent])){return .err(errors::make(5,offset));}
            let usize identity=key(p,sites,function,parent,offset)?;
            if(identity!=key(p,sites,function,child,offset)?){return .err(errors::make(5,offset));}
            let owners::WriteLease source=receipts.children[i].parent;let owners::View selected=receipts.children[i].selected;let slices::Ticket issued=receipts.children[i].issued;
            let usize length=switch(owners::exclusive_length(ref state.owners,ref source,capacity)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
            if(issued.slot>=16 || issued.generation==0 || selected.root.slot!=source.view.root.slot || selected.root.generation!=source.view.root.generation ||
                selected.element!=source.view.element || selected.element!=ir::slice_element(p,child,offset)? || selected.length!=source.view.length ||
                selected.start<source.view.start || selected.start>selected.end || selected.end>source.view.end){return .err(errors::make(5,offset));}
            var usize previous=31;var usize j=0;while(j<i){
                if(receipts.kinds[j]==2 && receipts.frames[j]==frame){
                    if(bindings.children[j]==child){return .err(errors::make(5,offset));}
                    if(bindings.children[j]==parent && bindings.functions[j]==function){previous=j;}
                }j+=1;
            }
            if(previous!=31){if(!same(source.view,receipts.children[previous].selected) || source.generation!=receipts.children[previous].parent.generation ||
                issued.slot!=receipts.children[previous].issued.slot || issued.generation<=receipts.children[previous].issued.generation){return .err(errors::make(5,offset));}}
            else{
                if(sites.parents[parent]!=16){return .err(errors::make(5,offset));}
                if(identity>=16){let usize entry=calls::suspended(p,function,frame,identity-16,source,issued,call_bindings,receipts,frames,state,offset)?;}
                else{let owners::Token token=state.tokens[frame*16+identity];if(source.view.root.slot!=token.slot || source.view.root.generation!=token.generation ||
                    source.view.length!=p.arrays.lengths[identity]){return .err(errors::make(5,offset));}}
            }
        }else if(bindings.parents[i]!=16 || bindings.children[i]!=16 || bindings.functions[i]!=16){return .err(errors::make(5,offset));}
        i+=1;
    }return .ok(depth);
}
fn Result<owners::View,errors::Error> selected(ref ir::Program p,ref proof::Sites sites,usize function,usize frame,usize site,
    ref owned::Bindings bindings,ref calls::Bindings call_bindings,ref authority::State receipts,ref shared::Frames frames,
    ref loans::State loan,ref arrays::State state,usize capacity,usize offset){
    let usize identity=key(p,sites,function,site,offset)?;
    if(sites.parents[site]==16 && identity>=16){return calls::view(p,function,frame,site,call_bindings,receipts,frames,loan,state,capacity,offset);}
    let slices::Ticket ticket=loan.tickets[frame*16+site];
    let usize length=switch(slices::length(ref loan.pool,ticket,ref state.owners,capacity)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    let slices::Slot entry=loan.pool.slots[ticket.slot];
    if(!entry.exclusive || entry.view.element!=ir::slice_element(p,site,offset)?){return .err(errors::make(5,offset));}
    if(sites.parents[site]!=16){
        var usize i=0;while(i<receipts.depth && !(receipts.kinds[i]==2 && receipts.frames[i]==frame && bindings.children[i]==site && bindings.functions[i]==function)){i+=1;}
        if(i==receipts.depth || ticket.slot!=receipts.children[i].issued.slot || ticket.generation<receipts.children[i].issued.generation ||
            !same(entry.view,receipts.children[i].selected) || entry.lease.generation!=receipts.children[i].parent.generation){return .err(errors::make(5,offset));}
    }else{let owners::Token token=state.tokens[frame*16+identity];if(entry.view.root.slot!=token.slot || entry.view.root.generation!=token.generation ||
        entry.view.length!=p.arrays.lengths[identity]){return .err(errors::make(5,offset));}}
    return .ok(entry.view);
}
pub fn Result<owners::View,errors::Error> view(ref ir::Program p,ref proof::Sites sites,usize function,usize frame,usize site,
    ref owned::Bindings bindings,ref calls::Bindings call_bindings,ref authority::State receipts,ref shared::Frames frames,
    ref loans::State loan,ref arrays::State state,usize capacity,usize offset){
    let usize depth=checked(p,sites,bindings,call_bindings,receipts,frames,loan,state,capacity,offset)?;
    if(frame>=32 || frame!=receipts.frame){return .err(errors::make(5,offset));}
    return selected(p,sites,function,frame,site,bindings,call_bindings,receipts,frames,loan,state,capacity,offset);
}
// Static admission precedes Fuel; runtime maps, bounds and capabilities follow it.
pub fn Result<usize,errors::Error> step(ref ir::Program p,ref proof::Sites sites,usize function,usize pc,usize frame,
    ref mut owned::Bindings bindings,ref calls::Bindings call_bindings,ref mut authority::State receipts,ref shared::Frames frames,
    ref mut loans::State loan,ref arrays::State state,ref bytes::Buffer buffer,ref i64[] registers,usize fuel){
    if(pc>=p.count || pc>=256){return .err(errors::make(5,0));}
    let usize at=pc*8;let usize offset=p.offsets[pc];let u8 op=p.code[at];let usize child=p.code[at+1] as usize;let usize parent=p.code[at+2] as usize;let usize lo=p.code[at+3] as usize;let usize hi=p.code[at+4] as usize;
    if((op!=61 && op!=62) || function>=p.function_count || function>=16 || pc<p.starts[function] || pc>=p.ends[function] || frame>=32 || registers.len>128 ||
        child>=16 || parent>=16 || sites.parents[child]!=parent || p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0 ||
        (op==62 && (lo!=0 || hi!=0)) || (op==61 && (lo>=registers.len || hi>=registers.len || p.types[lo]!=12 || p.types[hi]!=12 ||
        p.slots[lo] || p.slots[hi] || p.array_parameters[lo]!=0 || p.array_parameters[hi]!=0 || p.record_parameters[lo]!=0 || p.record_parameters[hi]!=0 ||
        p.slice_parameters[lo]!=0 || p.slice_parameters[hi]!=0 || lo<p.register_starts[function] || hi<p.register_starts[function] || lo>=p.register_ends[function] || hi>=p.register_ends[function]))){return .err(errors::make(5,offset));}
    let usize child_key=key(p,sites,function,child,offset)?;if(child_key!=key(p,sites,function,parent,offset)?){return .err(errors::make(5,offset));}
    if(fuel<65537){return .err(errors::make(8,offset));}
    let usize depth=checked(p,sites,bindings,call_bindings,receipts,frames,loan,state,bytes::len(buffer),offset)?;
    if(frame!=receipts.frame){return .err(errors::make(5,offset));}
    let usize a=frame*16+parent;let usize c=frame*16+child;let usize capacity=bytes::len(buffer);
    if(op==61){
        if(depth>=31){return .err(errors::make(12,offset));}if(!absent(loan.tickets[c])){return .err(errors::make(5,offset));}
        var usize i=0;while(i<depth){if(receipts.kinds[i]==2 && receipts.frames[i]==frame && bindings.children[i]==child){return .err(errors::make(5,offset));}i+=1;}
        let owners::View parent_view=selected(p,sites,function,frame,parent,bindings,call_bindings,receipts,frames,loan,state,capacity,offset)?;
        let usize start=cells::unpack(registers[lo],offset)?;let usize end=cells::unpack(registers[hi],offset)?;
        let slices::Ticket source=loan.tickets[a];let slices::Ticket issued=switch(authority::enter_child(receipts,ref mut loan.pool,source,ref state.owners,start,end,capacity,frame)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
        bindings.parents[depth]=parent;bindings.children[depth]=child;bindings.functions[depth]=function;loan.tickets[a]=none();loan.tickets[c]=issued;
    }else{
        if(depth==0 || receipts.kinds[depth-1]!=2 || bindings.parents[depth-1]!=parent || bindings.children[depth-1]!=child || bindings.functions[depth-1]!=function || !absent(loan.tickets[a])){return .err(errors::make(5,offset));}
        let owners::View child_view=selected(p,sites,function,frame,child,bindings,call_bindings,receipts,frames,loan,state,capacity,offset)?;
        let slices::Ticket source=loan.tickets[c];let slices::Ticket resumed=switch(authority::leave_child(receipts,ref mut loan.pool,source,ref state.owners,capacity,frame)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
        bindings.parents[depth-1]=16;bindings.children[depth-1]=16;bindings.functions[depth-1]=16;loan.tickets[c]=none();loan.tickets[a]=resumed;
    }return .ok(fuel-65537);
}
// Data access only. Derived close must use op62, formal close uses calls::release.
pub fn Result<usize,errors::Error> access(ref ir::Program p,ref proof::Sites sites,usize function,usize pc,usize frame,
    ref owned::Bindings bindings,ref calls::Bindings call_bindings,ref authority::State receipts,ref shared::Frames frames,
    ref loans::State loan,ref arrays::State state,ref mut bytes::Buffer buffer,ref mut i64[] registers,usize fuel){
    if(pc>=p.count || pc>=256){return .err(errors::make(5,0));}let usize at=pc*8;let usize offset=p.offsets[pc];let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    let usize site=if(op==60){dst}else{a};
    if(function>=p.function_count || function>=16 || pc<p.starts[function] || pc>=p.ends[function] || frame>=32 || registers.len>128 ||
        (op!=55 && op!=57 && op!=58 && op!=60) || p.code[at+4]!=0 || p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0 ||
        ((op==55 || op==57) && (dst>=registers.len || b!=0)) || (op==58 && (dst>=registers.len || b>=registers.len)) || (op==60 && (a>=registers.len || b>=registers.len))){return .err(errors::make(5,offset));}
    let usize identity=key(p,sites,function,site,offset)?;let u8 tag=ir::slice_element(p,site,offset)?;
    let layouts::Array shape=switch(layouts::scalar(tag,1)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}};
    if(op==55 && tag!=10){return .err(errors::make(5,offset));}
    let usize base=meter::slice_base(op,shape.stride);if(fuel<base){return .err(errors::make(8,offset));}
    let owners::View current=view(p,sites,function,frame,site,bindings,call_bindings,receipts,frames,loan,state,bytes::len(buffer),offset)?;
    let usize price=base+if(op==55){meter::utf8_scan(current.length)}else{0};if(fuel<price){return .err(errors::make(8,offset));}
    let slices::Ticket ticket=loan.tickets[frame*16+site];
    if(op==60){let usize index=cells::unpack(registers[a],offset)?;let usize n=switch(slices::write(ref loan.pool,ticket,ref state.owners,index,registers[b],bytes::view_mut(buffer))){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};}
    else if(op==58){let usize index=cells::unpack(registers[b],offset)?;let i64 value=switch(slices::read(ref loan.pool,ticket,ref state.owners,index,bytes::view(buffer))){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};registers[dst]=value;}
    else if(op==57){registers[dst]=cells::pack(current.end-current.start,offset)?;}
    else{let bool valid=switch(slices::utf8(ref loan.pool,ticket,ref state.owners,bytes::view(buffer))){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};registers[dst]=if(valid){1}else{0};}
    return .ok(fuel-price);
}
pub fn Result<i64,errors::Error> finish(ref mut owned::Bindings bindings,ref mut calls::Bindings call_bindings,
    ref mut authority::State receipts,ref mut shared::Frames frames,ref mut loans::State loan,ref mut arrays::State state,
    ref bytes::Buffer buffer,Result<i64,errors::Error> outcome){
    var bool failed=false;var errors::Error failure=errors::make(0,0);let i64 value=switch(outcome){case .ok(v):{v}case .err(e):{failed=true;failure=e;0}};
    let usize n=calls::drain(call_bindings,receipts,frames,loan,state,buffer)?;
    var usize i=0;while(i<31){bindings.parents[i]=16;bindings.children[i]=16;bindings.functions[i]=16;i+=1;}if(failed){return .err(failure);}return .ok(value);
}
