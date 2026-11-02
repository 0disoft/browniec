module slice_authority_call_vm;
import ir as ir;
import types as types;
import errors as errors;
import array_vm as arrays;
import array_owners as owners;
import array_slices as slices;
import struct_vm as records;
import slice_vm as loans;
import slice_call_vm as shared;
import slice_authority as authority;
import slice_reborrow_ir as proof;
import std::bytes as bytes;

// PC derives caller/target/argument positions from immutable inspected IR.
// These maps never own a duplicate Batch or Loan. Canonical receipts stay in authority.
pub struct Bindings { usize[31] pcs; slices::Ticket[248] detached; }
pub struct Call { usize caller; usize target; usize args; usize count; }
fn slices::Ticket none(){return slices::Ticket{.slot=16,.generation=0};}
fn bool absent(slices::Ticket t){return t.slot==16 && t.generation==0;}
fn bool same(owners::Token a,owners::Token b){return a.slot==b.slot && a.generation==b.generation;}
pub fn Bindings empty(){return Bindings{.pcs=[256;31],.detached=[none();248]};}
fn Result<Call,errors::Error> info(ref ir::Program p,usize pc,usize offset){
    if(p.function_count==0 || p.function_count>16 || p.registers>128 || pc>=p.count || pc>=256 || p.code[pc*8]!=9){return .err(errors::make(5,offset));}
    let usize target=p.code[pc*8+2] as usize;let usize args=p.code[pc*8+3] as usize;
    if(target>=p.function_count || args>=p.call_count || args>=32 || p.arities[target]>8 || p.call_arities[args] as usize!=p.arities[target] ||
        p.register_starts[target]>p.registers || p.arities[target]>p.registers-p.register_starts[target] || p.array_results[target]!=0 || p.record_results[target]!=0){return .err(errors::make(5,offset));}
    var usize caller=0;while(caller<p.function_count && (pc<p.starts[caller] || pc>=p.ends[caller])){caller+=1;}
    if(caller==p.function_count){return .err(errors::make(5,offset));}
    var usize count=0;var usize seen=0;let usize one=1;var usize i=0;
    while(i<p.arities[target]){
        let usize r=p.register_starts[target]+i;let usize encoded=p.slice_parameters[r] as usize;let usize source=p.call_args[args*8+i] as usize;
        // This private bridge handles scalar plus exclusive formals only.
        if(p.array_parameters[r]!=0 || p.record_parameters[r]!=0 || p.slots[r]){return .err(errors::make(5,offset));}
        if(encoded!=0){
            if(encoded>16 || p.types[r]!=0 || !ir::exclusive(p,encoded-1) || p.slice_roots[encoded-1]!=0 ||
                p.slice_origins[encoded-1] as usize!=encoded || p.slice_functions[encoded-1] as usize!=target+1 ||
                !types::scalar(ir::borrow_element(p,encoded-1)) || (seen&(one<<(encoded-1)))!=0 || source<160 || source>=176){return .err(errors::make(5,offset));}
            seen|=one<<(encoded-1);count+=1;
        }else if(!types::valid(p.types[r]) || source>=p.registers || source<p.register_starts[caller] || source>=p.register_ends[caller] ||
            p.types[source]!=p.types[r] || p.slots[source] || p.array_parameters[source]!=0 || p.record_parameters[source]!=0 || p.slice_parameters[source]!=0){return .err(errors::make(5,offset));}
        i+=1;
    }
    return .ok(Call{.caller=caller,.target=target,.args=args,.count=count});
}
pub fn Result<usize,errors::Error> cost(ref ir::Program p,usize pc,usize offset){
    let Call call=info(p,pc,offset)?;
    return .ok(1+p.arities[call.target]+if(call.count==0){0}else{65537*(1+2*call.count)});
}
fn Result<usize,errors::Error> index(ref authority::State receipts,usize frame,usize offset){
    if(frame==0 || frame>=32 || receipts.depth>31){return .err(errors::make(5,offset));}
    var usize i=0;while(i<receipts.depth && !(receipts.kinds[i]==1 && receipts.frames[i]==frame-1)){i+=1;}
    if(i==receipts.depth){return .err(errors::make(5,offset));}return .ok(i);
}
fn Result<usize,errors::Error> writer(ref ir::Program p,Call call,usize site,usize offset){
    var usize j=0;var usize position=0;while(position<p.arities[call.target]){
        let usize encoded=p.slice_parameters[p.register_starts[call.target]+position] as usize;
        if(encoded!=0){if(encoded==site+1){return .ok(j);}j+=1;}position+=1;
    }return .err(errors::make(5,offset));
}
// A root binding survives release/forwarding. Immutable argument positions,
// canonical leases and shared origin cells must agree even without a live ticket.
pub fn Result<owners::Token,errors::Error> origin(ref ir::Program p,usize function,usize frame,usize site,
    ref Bindings bindings,ref authority::State receipts,ref shared::Frames frames,ref arrays::State state,usize offset){
    if(function>=p.function_count || function>=16 || frame>=32 || site>=16 || !ir::exclusive(p,site)){return .err(errors::make(5,offset));}
    let u8 tag=ir::slice_element(p,site,offset)?;let usize owned=p.slice_roots[site] as usize;
    if(owned!=0){if(owned>16 || owned>p.arrays.count || p.array_functions[owned-1] as usize!=function){return .err(errors::make(5,offset));}return .ok(state.tokens[frame*16+owned-1]);}
    if(p.slice_origins[site] as usize!=site+1 || p.slice_functions[site] as usize!=function+1){return .err(errors::make(5,offset));}
    let usize i=index(receipts,frame,offset)?;let Call call=info(p,bindings.pcs[i],offset)?;
    if(call.target!=function || call.count!=receipts.counts[i]){return .err(errors::make(5,offset));}
    let usize j=writer(p,call,site,offset)?;let owners::WriteLease lease=receipts.leases[i*8+j];var usize pos=0;
    while(pos<p.arities[function] && p.slice_parameters[p.register_starts[function]+pos] as usize!=site+1){pos+=1;}
    if(pos==p.arities[function] || !same(frames.origins[frame*8+pos],lease.view.root) || lease.view.element!=tag){return .err(errors::make(5,offset));}
    return .ok(lease.view.root);
}
pub fn Result<usize,errors::Error> inspect(ref ir::Program p,ref Bindings bindings,ref authority::State receipts,
    ref shared::Frames frames,ref loans::State loan,ref arrays::State state,usize offset){
    let usize depth=switch(authority::inspect(receipts)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    var usize i=0;while(i<31){
        if(receipts.kinds[i]==1 && (receipts.counts[i]!=0 || bindings.pcs[i]!=256)){
            let Call call=info(p,bindings.pcs[i],offset)?;if(call.count!=receipts.counts[i]){return .err(errors::make(5,offset));}
            let usize parent=receipts.frames[i];var usize j=0;var usize pos=0;
            while(pos<8){
                let usize encoded=if(pos<p.arities[call.target]){p.slice_parameters[p.register_starts[call.target]+pos] as usize}else{0};
                if(encoded!=0){
                    let usize source=(p.call_args[call.args*8+pos] as usize)-160;let owners::WriteLease lease=receipts.leases[i*8+j];
                    let owners::Token expected=origin(p,call.caller,parent,source,bindings,receipts,frames,state,offset)?;
                    if(!same(expected,lease.view.root) || !same(frames.origins[(parent+1)*8+pos],lease.view.root) ||
                        lease.view.element!=ir::borrow_element(p,encoded-1) || !absent(loan.tickets[parent*16+source]) ||
                        (!absent(loan.tickets[(parent+1)*16+encoded-1]) && !absent(bindings.detached[i*8+j]))){return .err(errors::make(5,offset));}j+=1;
                }else{let owners::Token token=frames.origins[(parent+1)*8+pos];if(token.slot!=16 || token.generation!=0){return .err(errors::make(5,offset));}}
                pos+=1;
            }
        }else if(bindings.pcs[i]!=256){return .err(errors::make(5,offset));}
        var usize j=if(receipts.kinds[i]==1){receipts.counts[i]}else{0};while(j<8){if(!absent(bindings.detached[i*8+j])){return .err(errors::make(5,offset));}j+=1;}i+=1;
    }
    return .ok(depth);
}
// Authenticate the first lexical child's suspended formal against its CALL.
// Readonly snapshots are not another persistent owner of either receipt.
pub fn Result<usize,errors::Error> suspended(ref ir::Program p,usize function,usize frame,usize site,
    owners::WriteLease parent,slices::Ticket issued,ref Bindings bindings,ref authority::State receipts,
    ref shared::Frames frames,ref arrays::State state,usize offset){
    let owners::Token expected=origin(p,function,frame,site,bindings,receipts,frames,state,offset)?;
    let usize i=index(receipts,frame,offset)?;let Call call=info(p,bindings.pcs[i],offset)?;let usize j=writer(p,call,site,offset)?;
    let owners::WriteLease lease=receipts.leases[i*8+j];let slices::Ticket original=receipts.tickets[i*8+j];
    if(!absent(bindings.detached[i*8+j]) || !same(expected,parent.view.root) || parent.generation!=lease.generation ||
        parent.view.element!=lease.view.element || parent.view.length!=lease.view.length ||
        parent.view.start!=lease.view.start || parent.view.end!=lease.view.end ||
        issued.slot!=original.slot || issued.generation<=original.generation){return .err(errors::make(5,offset));}
    return .ok(i);
}
fn Result<owners::View,errors::Error> authenticated(ref ir::Program p,usize function,usize frame,usize site,slices::Ticket ticket,
    ref Bindings bindings,ref authority::State receipts,ref shared::Frames frames,ref loans::State loan,ref arrays::State state,usize capacity,usize offset){
    let owners::Token expected=origin(p,function,frame,site,bindings,receipts,frames,state,offset)?;
    let usize length=switch(slices::length(ref loan.pool,ticket,ref state.owners,capacity)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    let slices::Slot entry=loan.pool.slots[ticket.slot];let u8 tag=ir::slice_element(p,site,offset)?;
    let usize owned=p.slice_roots[site] as usize;
    if(!entry.exclusive || !same(entry.view.root,expected) || entry.view.element!=tag || entry.view.length==0 || entry.view.length>4096 ||
        (owned!=0 && entry.view.length!=p.arrays.lengths[owned-1])){return .err(errors::make(5,offset));}
    if(owned==0){let usize i=index(receipts,frame,offset)?;let Call call=info(p,bindings.pcs[i],offset)?;let usize j=writer(p,call,site,offset)?;
        let slices::Ticket issued=receipts.tickets[i*8+j];let owners::WriteLease lease=receipts.leases[i*8+j];
        if(ticket.slot!=issued.slot || ticket.generation<issued.generation || entry.lease.generation!=lease.generation ||
            entry.view.start!=lease.view.start || entry.view.end!=lease.view.end || entry.view.length!=lease.view.length){return .err(errors::make(5,offset));}
    }return .ok(entry.view);
}
pub fn Result<owners::View,errors::Error> view(ref ir::Program p,usize function,usize frame,usize site,
    ref Bindings bindings,ref authority::State receipts,ref shared::Frames frames,ref loans::State loan,ref arrays::State state,usize capacity,usize offset){
    let usize depth=inspect(p,bindings,receipts,frames,loan,state,offset)?;
    if(frame!=receipts.frame || site>=16 || p.slice_roots[site]!=0){return .err(errors::make(5,offset));}
    let usize i=index(receipts,frame,offset)?;let Call call=info(p,bindings.pcs[i],offset)?;let usize j=writer(p,call,site,offset)?;
    if(!absent(bindings.detached[i*8+j])){return .err(errors::make(5,offset));}
    return authenticated(p,function,frame,site,loan.tickets[frame*16+site],bindings,receipts,frames,loan,state,capacity,offset);
}
// Scalar/control copies are the coordinator's responsibility. No fallible work
// follows the one canonical handoff publication; all original inputs check first.
pub fn Result<usize,errors::Error> enter(ref ir::Program p,ref proof::Sites sites,usize pc,usize parent,
    ref mut Bindings bindings,ref mut authority::State receipts,ref mut shared::Frames frames,
    ref mut loans::State loan,ref arrays::State state,ref records::State record_state,ref bytes::Buffer buffer,usize fuel){
    let usize offset=if(pc<p.count && pc<256){p.offsets[pc]}else{0};let Call call=info(p,pc,offset)?;let usize charge=cost(p,pc,offset)?;
    if(fuel<charge){return .err(errors::make(8,offset));}
    let usize depth=inspect(p,bindings,receipts,frames,loan,state,offset)?;
    if(parent>=31 || depth>=31){return .err(errors::make(12,offset));}if(parent!=receipts.frame){return .err(errors::make(5,offset));}
    let usize child=parent+1;var usize i=0;while(i<16){if(!absent(loan.tickets[child*16+i]) || state.tokens[child*16+i].generation!=0 || record_state.tokens[child*16+i].generation!=0){return .err(errors::make(5,offset));}i+=1;}
    i=0;while(i<8){let owners::Token root=frames.origins[child*8+i];if(root.slot!=16 || root.generation!=0){return .err(errors::make(5,offset));}i+=1;}
    var slices::Ticket[8] sources=[none();8];var owners::Token[8] roots=[owners::Token{.slot=16,.generation=0};8];var usize n=0;i=0;
    while(i<p.arities[call.target]){let usize encoded=p.slice_parameters[p.register_starts[call.target]+i] as usize;if(encoded!=0){
        let usize source=(p.call_args[call.args*8+i] as usize)-160;
        if(sites.parents[source]!=16){return .err(errors::make(5,offset));}
        let slices::Ticket current=loan.tickets[parent*16+source];let owners::View selected=authenticated(p,call.caller,parent,source,current,bindings,receipts,frames,loan,state,bytes::len(buffer),offset)?;
        if(selected.element!=ir::borrow_element(p,encoded-1)){return .err(errors::make(5,offset));}sources[n]=current;roots[n]=selected.root;n+=1;}i+=1;}
    let slices::Arguments issued=switch(authority::enter_call(receipts,ref mut loan.pool,ref sources[..n],ref state.owners,bytes::len(buffer),parent)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    bindings.pcs[depth]=pc;n=0;i=0;while(i<p.arities[call.target]){let usize encoded=p.slice_parameters[p.register_starts[call.target]+i] as usize;if(encoded!=0){
        let usize source=(p.call_args[call.args*8+i] as usize)-160;loan.tickets[parent*16+source]=none();loan.tickets[child*16+encoded-1]=issued.tickets[n];frames.origins[child*8+i]=roots[n];n+=1;}i+=1;}
    return .ok(fuel-charge);
}
pub fn Result<usize,errors::Error> release(ref ir::Program p,usize function,usize frame,usize site,
    ref mut Bindings bindings,ref authority::State receipts,ref shared::Frames frames,ref mut loans::State loan,
    ref arrays::State state,ref bytes::Buffer buffer,usize fuel,usize offset){
    if(fuel<4097){return .err(errors::make(8,offset));}
    let owners::View selected=view(p,function,frame,site,bindings,receipts,frames,loan,state,bytes::len(buffer),offset)?;
    let usize i=index(receipts,frame,offset)?;let Call call=info(p,bindings.pcs[i],offset)?;let usize j=writer(p,call,site,offset)?;
    bindings.detached[i*8+j]=loan.tickets[frame*16+site];loan.tickets[frame*16+site]=none();return .ok(fuel-4097);
}
// Every exclusive formal must be live OR detached. All other frame loans and
// owned values must already be cleaned by the VM coordinator before return.
pub fn Result<usize,errors::Error> leave(ref ir::Program p,usize function,usize frame,ref mut Bindings bindings,
    ref mut authority::State receipts,ref mut shared::Frames frames,ref mut loans::State loan,
    ref arrays::State state,ref records::State record_state,ref bytes::Buffer buffer,usize offset){
    let usize depth=inspect(p,bindings,receipts,frames,loan,state,offset)?;
    if(depth==0 || frame==0 || frame!=receipts.frame || receipts.kinds[depth-1]!=1){return .err(errors::make(5,offset));}
    let usize i=depth-1;let Call call=info(p,bindings.pcs[i],offset)?;if(function!=call.target){return .err(errors::make(5,offset));}
    var slices::Ticket[8] current=[none();8];var usize j=0;var usize pos=0;var usize allowed=0;let usize one=1;
    while(pos<p.arities[function]){let usize encoded=p.slice_parameters[p.register_starts[function]+pos] as usize;if(encoded!=0){
        let usize site=encoded-1;allowed|=one<<site;let slices::Ticket live=loan.tickets[frame*16+site];let slices::Ticket saved=bindings.detached[i*8+j];
        current[j]=if(absent(live)){saved}else{live};let owners::View selected=authenticated(p,function,frame,site,current[j],bindings,receipts,frames,loan,state,bytes::len(buffer),offset)?;j+=1;}pos+=1;}
    var usize slot=0;while(slot<16){if(((allowed&(one<<slot))==0 && !absent(loan.tickets[frame*16+slot])) || state.tokens[frame*16+slot].generation!=0 || record_state.tokens[frame*16+slot].generation!=0){return .err(errors::make(5,offset));}slot+=1;}
    let slices::Arguments restored=switch(authority::leave_call(receipts,ref mut loan.pool,ref current[..j],ref state.owners,bytes::len(buffer),frame)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    j=0;pos=0;while(pos<p.arities[function]){let usize encoded=p.slice_parameters[p.register_starts[function]+pos] as usize;if(encoded!=0){let usize source=(p.call_args[call.args*8+pos] as usize)-160;loan.tickets[(frame-1)*16+source]=restored.tickets[j];j+=1;}pos+=1;}
    bindings.pcs[i]=256;slot=0;while(slot<8){bindings.detached[i*8+slot]=none();frames.origins[frame*8+slot]=owners::Token{.slot=16,.generation=0};slot+=1;}slot=0;while(slot<16){loan.tickets[frame*16+slot]=none();slot+=1;}
    return .ok(j);
}
// Drain before clearing maps. Both standalone CALL and lexical coordinators use
// this one cleanup transaction; a failed drain preserves all diagnostic maps.
pub fn Result<usize,errors::Error> drain(ref mut Bindings bindings,ref mut authority::State receipts,
    ref mut shared::Frames frames,ref mut loans::State loan,ref mut arrays::State state,ref bytes::Buffer buffer){
    let usize count=switch(authority::finish(receipts,ref mut loan.pool,ref mut state.owners,bytes::len(buffer))){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}};
    var usize i=0;while(i<31){bindings.pcs[i]=256;i+=1;}i=0;while(i<248){bindings.detached[i]=none();i+=1;}i=0;while(i<512){loan.tickets[i]=none();i+=1;}i=0;while(i<256){frames.origins[i]=owners::Token{.slot=16,.generation=0};i+=1;}
    return .ok(count);
}
pub fn Result<i64,errors::Error> finish(ref mut Bindings bindings,ref mut authority::State receipts,
    ref mut shared::Frames frames,ref mut loans::State loan,ref mut arrays::State state,ref bytes::Buffer buffer,Result<i64,errors::Error> outcome){
    var bool failed=false;var errors::Error failure=errors::make(0,0);let i64 value=switch(outcome){case .ok(v):{v}case .err(e):{failed=true;failure=e;0}};
    let usize count=drain(bindings,receipts,frames,loan,state,buffer)?;if(failed){return .err(failure);}return .ok(value);
}
