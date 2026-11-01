module slice_mutable_call_vm;
import ir as ir;
import errors as errors;
import types as types;
import slice_call_vm as shared;
import slice_handoff as handoff;
import slice_vm as loans;
import array_slices as slices;
import array_owners as owners;
import array_vm as arrays;
import struct_vm as records;
import struct_call_vm as owned;
import std::bytes as bytes;

// Private invocation-owned receipt, one per active mutable CALL. The VM caller
// retains it across the child frame; cloning or unrelated session mutation is
// outside this protocol. No Program or shared Frames fields are added.
pub struct Frame {
    handoff::Batch batch; slices::Ticket[8] detached;
    usize[8] sources; usize[8] sites; usize[8] positions;
    usize parent; usize caller; usize target; bool active;
}
fn slices::Ticket none(){return slices::Ticket{.slot=16,.generation=0};}
fn bool absent(slices::Ticket t){return t.slot==16 && t.generation==0;}
fn bool same(owners::Token a,owners::Token b){return a.slot==b.slot && a.generation==b.generation;}
pub fn Frame empty(){return Frame{.batch=handoff::empty(),.detached=[none();8],.sources=[16;8],.sites=[16;8],.positions=[8;8],.parent=32,.caller=16,.target=16,.active=false};}

fn void store(ref mut Frame dst,ref Frame src){
    dst.batch=src.batch;dst.detached=src.detached;dst.sources=src.sources;
    dst.sites=src.sites;dst.positions=src.positions;dst.parent=src.parent;
    dst.caller=src.caller;dst.target=src.target;dst.active=src.active;
}
fn bool session(ref Frame receipt,usize i,slices::Ticket ticket,ref slices::Pool pool){
    let slices::Ticket issued=receipt.batch.tickets[i];let owners::WriteLease lease=receipt.batch.leases[i];let slices::Slot entry=pool.slots[ticket.slot];
    return issued.generation!=0 && ticket.slot==issued.slot && ticket.generation>=issued.generation && entry.exclusive && entry.lease.generation==lease.generation &&
        same(entry.view.root,lease.view.root) && entry.view.element==lease.view.element && entry.view.length==lease.view.length && entry.view.start==lease.view.start && entry.view.end==lease.view.end;
}

// Logical bounded reserves: one frame cleanup plus one shared retain or two
// exclusive transfer/restore reserves per formal. Existing public prices stay
// unchanged; this private boundary requires at least one mutable formal.
fn Result<usize,errors::Error> reserve(ref ir::Program p,usize target,usize offset){
    if(p.function_count==0 || p.function_count>16 || target>=p.function_count || p.registers>128 || p.arities[target]>8 ||
        p.register_starts[target]>p.registers || p.arities[target]>p.registers-p.register_starts[target]){return .err(errors::make(5,offset));}
    var usize readers=0;var usize writers=0;var usize seen=0;let usize one=1;var usize i=0;
    while(i<p.arities[target]){
        let usize r=p.register_starts[target]+i;let usize encoded=p.slice_parameters[r] as usize;
        if(encoded!=0){
            if(encoded>16 || p.types[r]!=0 || p.slots[r] || p.array_parameters[r]!=0 || p.record_parameters[r]!=0){return .err(errors::make(5,offset));}
            let usize site=encoded-1;
            if(p.slice_roots[site]!=0 || p.slice_origins[site] as usize!=encoded || p.slice_functions[site] as usize!=target+1 || !types::scalar(ir::borrow_element(p,site)) || (seen&(one<<site))!=0){return .err(errors::make(5,offset));}
            seen|=one<<site;if(ir::exclusive(p,site)){writers+=1;}else{readers+=1;}
        }i+=1;
    }
    if(writers==0){return .err(errors::make(5,offset));}
    return .ok(65537*(1+readers+2*writers));
}
pub fn Result<usize,errors::Error> cost(ref ir::Program p,usize target,usize offset){
    let usize work=reserve(p,target,offset)?;let usize copies=owned::cost(p,target,offset)?;
    return .ok(1+p.arities[target]+copies+work);
}
fn Result<owners::Token,errors::Error> root(ref ir::Program p,usize function,usize frame,usize site,
    ref shared::Frames frames,ref arrays::State state,usize offset){
    if(function>=p.function_count || function>=16 || frame>=32 || site>=16){return .err(errors::make(5,offset));}
    if(!ir::exclusive(p,site)){return shared::root(p,function,frame,site,frames,state,offset);}
    let u8 tag=switch(ir::slice_element(p,site,offset)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}};
    let usize owned_root=p.slice_roots[site] as usize;
    if(owned_root!=0){
        if(p.array_functions[owned_root-1] as usize!=function){return .err(errors::make(5,offset));}
        return .ok(state.tokens[frame*16+owned_root-1]);
    }
    if(p.slice_origins[site] as usize!=site+1 || p.slice_functions[site] as usize!=function+1){return .err(errors::make(5,offset));}
    var usize i=0;while(i<p.arities[function]){if(p.slice_parameters[p.register_starts[function]+i] as usize==site+1){return .ok(frames.origins[frame*8+i]);}i+=1;}
    return .err(errors::make(5,offset));
}
fn Result<owners::Token,errors::Error> checked(ref ir::Program p,usize function,usize frame,usize site,
    slices::Ticket ticket,ref shared::Frames frames,ref loans::State loan,ref arrays::State state,usize capacity,usize offset){
    let owners::Token expected=root(p,function,frame,site,frames,state,offset)?;
    let usize length=switch(slices::length(ref loan.pool,ticket,ref state.owners,capacity)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    let slices::Slot entry=loan.pool.slots[ticket.slot];
    let u8 tag=switch(ir::slice_element(p,site,offset)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}};
    let usize owned_root=p.slice_roots[site] as usize;
    if(entry.exclusive!=ir::exclusive(p,site) || !same(entry.view.root,expected) || entry.view.element!=tag || entry.view.length==0 || entry.view.length>4096 ||
        (owned_root!=0 && entry.view.length!=p.arrays.lengths[owned_root-1])){return .err(errors::make(5,offset));}
    return .ok(expected);
}

// Prepay before runtime lookup. Validate every original source before staging
// either shared retention or generation rotation. Owned copying is the last
// fallible step; only bounded metadata publication follows it.
pub fn Result<usize,errors::Error> enter(ref ir::Program p,usize pc,usize parent,ref mut Frame receipt,
    ref mut shared::Frames frames,ref mut loans::State loan,ref mut records::State record_state,
    ref mut arrays::State state,ref mut bytes::Buffer buffer,usize fuel){
    if(pc>=p.count || pc>=256 || p.code[pc*8]!=9){return .err(errors::make(5,0));}
    let usize offset=p.offsets[pc];let usize target=p.code[pc*8+2] as usize;let usize call=p.code[pc*8+3] as usize;
    let usize charge=cost(p,target,offset)?;
    if(call>=p.call_count || call>=32 || p.call_arities[call] as usize!=p.arities[target]){return .err(errors::make(5,offset));}
    if(fuel<charge){return .err(errors::make(8,offset));}if(parent>=31){return .err(errors::make(12,offset));}
    if(receipt.active){return .err(errors::make(5,offset));}
    let usize child=parent+1;var usize caller=0;
    while(caller<p.function_count && (pc<p.starts[caller] || pc>=p.ends[caller])){caller+=1;}
    if(caller==p.function_count){return .err(errors::make(5,offset));}
    var usize i=0;while(i<16){if(!absent(loan.tickets[child*16+i]) || state.tokens[child*16+i].generation!=0 || record_state.tokens[child*16+i].generation!=0){return .err(errors::make(5,offset));}i+=1;}
    i=0;while(i<8){let owners::Token token=frames.origins[child*8+i];if(token.slot!=16 || token.generation!=0){return .err(errors::make(5,offset));}i+=1;}
    var Frame staged=empty();staged.parent=parent;staged.caller=caller;staged.target=target;
    var slices::Ticket[8] sources=[none();8];var slices::Ticket[8] readers=[none();8];var slices::Ticket[8] writers=[none();8];
    var usize[8] reader_positions=[0;8];var usize[8] writer_positions=[0;8];var usize nr=0;var usize nw=0;
    var owners::Token[8] roots=[owners::Token{.slot=16,.generation=0};8];i=0;
    while(i<p.arities[target]){
        let usize encoded=p.slice_parameters[p.register_starts[target]+i] as usize;
        if(encoded!=0){
            let usize source=p.call_args[call*8+i] as usize;if(source<160 || source>=176){return .err(errors::make(5,offset));}
            let usize site=source-160;let slices::Ticket ticket=loan.tickets[parent*16+site];
            roots[i]=checked(p,caller,parent,site,ticket,frames,loan,state,bytes::len(buffer),offset)?;
            let slices::Slot entry=loan.pool.slots[ticket.slot];
            if(entry.exclusive!=ir::exclusive(p,encoded-1) || entry.view.element!=ir::borrow_element(p,encoded-1)){return .err(errors::make(5,offset));}
            sources[i]=ticket;
            if(entry.exclusive){writers[nw]=ticket;writer_positions[nw]=i;staged.sources[nw]=site;staged.sites[nw]=encoded-1;staged.positions[nw]=i;nw+=1;}
            else{readers[nr]=ticket;reader_positions[nr]=i;nr+=1;}
        }i+=1;
    }
    var slices::Pool planned=slices::Pool{.slots=loan.pool.slots};
    let slices::Arguments retained=switch(slices::borrow_arguments(ref mut planned,ref readers[..nr],ref state.owners,bytes::len(buffer))){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    staged.batch=switch(handoff::begin(ref mut planned,ref writers[..nw],ref state.owners,bytes::len(buffer),parent)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    i=0;while(i<nr){sources[reader_positions[i]]=retained.tickets[i];i+=1;}i=0;while(i<nw){sources[writer_positions[i]]=staged.batch.tickets[i];i+=1;}
    let usize work=reserve(p,target,offset)?;
    let usize remaining=owned::step(p,target,call,parent,record_state,state,buffer,fuel-work,offset)?;
    loan.pool.slots=planned.slots;
    i=0;while(i<nw){loan.tickets[parent*16+staged.sources[i]]=none();i+=1;}
    i=0;while(i<p.arities[target]){let usize encoded=p.slice_parameters[p.register_starts[target]+i] as usize;if(encoded!=0){loan.tickets[child*16+encoded-1]=sources[i];frames.origins[child*8+i]=roots[i];}i+=1;}
    staged.active=true;store(receipt,ref staged);return .ok(remaining);
}

// Closing a mutable formal relinquishes its binding, not the caller's owner
// session. Keep the current capability in the private receipt until return.
pub fn Result<usize,errors::Error> release(ref ir::Program p,usize function,usize frame,usize site,
    ref mut Frame receipt,ref shared::Frames frames,ref mut loans::State loan,ref arrays::State state,
    ref bytes::Buffer buffer,usize fuel,usize offset){
    if(fuel<4097){return .err(errors::make(8,offset));}
    if(!receipt.active || frame==0 || frame>=32 || receipt.parent!=frame-1 || receipt.target!=function || site>=16 || receipt.batch.count==0 || receipt.batch.count>8 || receipt.batch.frame!=receipt.parent){return .err(errors::make(5,offset));}
    var usize i=0;while(i<receipt.batch.count){if(receipt.sites[i]==site){
        if(!absent(receipt.detached[i])){return .err(errors::make(5,offset));}
        let slices::Ticket ticket=loan.tickets[frame*16+site];let owners::Token token=checked(p,function,frame,site,ticket,frames,loan,state,bytes::len(buffer),offset)?;
        if(!same(token,receipt.batch.leases[i].view.root) || !session(receipt,i,ticket,ref loan.pool)){return .err(errors::make(5,offset));}
        receipt.detached[i]=ticket;loan.tickets[frame*16+site]=none();return .ok(fuel-4097);
    }i+=1;}return .err(errors::make(5,offset));
}

// Return work was prepaid on entry. Close ordinary child loans in staged owner
// metadata, restore all exclusive generations, then publish everything at once.
pub fn Result<usize,errors::Error> leave(ref ir::Program p,usize function,usize frame,
    ref mut Frame receipt,ref mut shared::Frames frames,ref mut loans::State loan,
    ref mut arrays::State state,ref bytes::Buffer buffer,usize offset){
    let usize work=reserve(p,function,offset)?;
    if(!receipt.active || frame==0 || frame>=32 || receipt.parent!=frame-1 || receipt.target!=function || receipt.batch.count==0 || receipt.batch.count>8 || receipt.batch.frame!=receipt.parent){return .err(errors::make(5,offset));}
    var usize sites_seen=0;var usize sources_seen=0;var usize positions_seen=0;var usize index=0;let usize bit=1;
    while(index<8){
        let usize site=receipt.sites[index];let usize source=receipt.sources[index];let usize position=receipt.positions[index];
        if(index<receipt.batch.count){
            if(site>=16 || source>=16 || position>=8 || (sites_seen&(bit<<site))!=0 || (sources_seen&(bit<<source))!=0 || (positions_seen&(bit<<position))!=0){return .err(errors::make(5,offset));}
            sites_seen|=bit<<site;sources_seen|=bit<<source;positions_seen|=bit<<position;
        }else if(site!=16 || source!=16 || position!=8 || !absent(receipt.detached[index])){return .err(errors::make(5,offset));}
        index+=1;
    }
    let usize capacity=bytes::len(buffer);var slices::Ticket[8] current=[none();8];var usize i=0;var usize seen=0;let usize one=1;
    while(i<8){
        let owners::Token token=frames.origins[frame*8+i];let bool borrowed=i<p.arities[function] && p.slice_parameters[p.register_starts[function]+i]!=0;
        if(!borrowed){if(token.slot!=16 || token.generation!=0){return .err(errors::make(5,offset));}}
        else{let usize site=(p.slice_parameters[p.register_starts[function]+i] as usize)-1;
            if(ir::exclusive(p,site)){
                var usize j=0;while(j<receipt.batch.count && receipt.positions[j]!=i){j+=1;}
                if(j==receipt.batch.count || receipt.sites[j]!=site || !same(token,receipt.batch.leases[j].view.root)){return .err(errors::make(5,offset));}
                seen|=one<<j;
            }else{let owners::View view=switch(owners::view(ref state.owners,token,0,0,capacity)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};if(view.element!=ir::borrow_element(p,site) || view.length==0 || view.length>4096){return .err(errors::make(5,offset));}}
        }i+=1;
    }
    if(seen!=(one<<receipt.batch.count)-1){return .err(errors::make(5,offset));}
    i=0;while(i<receipt.batch.count){
        let usize site=receipt.sites[i];let usize source=receipt.sources[i];
        if(site>=16 || source>=16 || !absent(loan.tickets[receipt.parent*16+source])){return .err(errors::make(5,offset));}
        let owners::Token expected=root(p,receipt.caller,receipt.parent,source,frames,state,offset)?;
        if(!ir::exclusive(p,source) || !same(expected,receipt.batch.leases[i].view.root)){return .err(errors::make(5,offset));}
        let slices::Ticket live=loan.tickets[frame*16+site];let slices::Ticket detached=receipt.detached[i];
        if(!absent(live) && !absent(detached)){return .err(errors::make(5,offset));}
        current[i]=if(absent(live)){detached}else{live};
        let owners::Token valid=checked(p,function,frame,site,current[i],frames,loan,state,capacity,offset)?;i+=1;
    }
    var slices::Pool planned=slices::Pool{.slots=loan.pool.slots};var owners::Table planned_owners=owners::Table{.slots=state.owners.slots,.order=state.owners.order,.depth=state.owners.depth,.arena=state.owners.arena};var usize count=receipt.batch.count;i=16;
    while(i>0){i-=1;let slices::Ticket ticket=loan.tickets[frame*16+i];if(absent(ticket)){continue;}
        var bool returning=false;var usize j=0;while(j<receipt.batch.count){if(receipt.sites[j]==i){returning=true;}j+=1;}
        if(!returning){let owners::Token valid=checked(p,function,frame,i,ticket,frames,loan,state,capacity,offset)?;let usize closed=switch(slices::close(ref mut planned,ticket,ref mut planned_owners,capacity)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};count+=1;}
    }
    var handoff::Batch batch=receipt.batch;let slices::Arguments restored=switch(handoff::restore(ref mut planned,ref mut batch,ref current[..receipt.batch.count],ref planned_owners,capacity)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    loan.pool.slots=planned.slots;state.owners.slots=planned_owners.slots;
    i=0;while(i<restored.count){loan.tickets[receipt.parent*16+receipt.sources[i]]=restored.tickets[i];i+=1;}
    i=0;while(i<16){loan.tickets[frame*16+i]=none();i+=1;}i=0;while(i<8){frames.origins[frame*8+i]=owners::Token{.slot=16,.generation=0};i+=1;}
    let Frame cleared=empty();store(receipt,ref cleared);return .ok(count);
}

// Invocation abort: do not restore suspended frames. One atomic pool drain ends
// all sessions, including detached formals. Clear receipts only after success.
pub fn Result<i64,errors::Error> finish(ref mut Frame[] receipts,ref mut shared::Frames frames,
    ref mut loans::State loan,ref mut arrays::State state,ref bytes::Buffer buffer,Result<i64,errors::Error> outcome){
    var bool failed=false;var errors::Error failure=errors::make(0,0);
    let i64 value=switch(outcome){case .ok(v):{v}case .err(e):{failed=true;failure=e;0}};
    if(receipts.len>32){return .err(errors::make(5,0));}
    let usize count=loans::drain(loan,state,buffer)?;var usize i=0;while(i<receipts.len){receipts[i]=empty();i+=1;}
    i=0;while(i<256){frames.origins[i]=owners::Token{.slot=16,.generation=0};i+=1;}
    if(failed){return .err(failure);}return .ok(value);
}
