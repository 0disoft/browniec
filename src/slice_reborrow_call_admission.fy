module slice_reborrow_call_admission;
import ir as ir;
import errors as errors;
import array_vm as arrays;
import array_owners as owners;
import array_slices as slices;
import struct_vm as records;
import slice_vm as loans;
import slice_call_vm as shared;
import slice_authority as authority;
import slice_authority_call_vm as calls;
import slice_reborrow_ir as proof;
import slice_reborrow_vm as children;
import slice_formal_reborrow_vm as source;
import std::bytes as bytes;

// Unpublished, single-use native staging only. No canonical receipt is copied.
// Immutable independently inspected IR/Sites and one unchanged invocation are
// prerequisites. This module exposes no publication operation. The synchronous
// handoff must finish owned copying before publishing its loan plan.
pub struct Prepared { slices::Pool pool; authority::Entry receipt;
    slices::Arguments retained; owners::Token[8] roots;
    usize pc; usize frame; usize depth; usize remaining; }
fn slices::Ticket none(){return slices::Ticket{.slot=16,.generation=0};}
fn bool absent(slices::Ticket t){return t.slot==16 && t.generation==0;}

pub fn Result<Prepared,errors::Error> prepare(ref ir::Program p,ref proof::Sites sites,usize pc,usize frame,
    ref children::Bindings child_sites,ref calls::Bindings call_sites,ref authority::State receipts,
    ref shared::Frames frames,ref loans::State loan,ref arrays::State state,
    ref records::State record_state,ref bytes::Buffer buffer,usize fuel){
    let usize offset=if(pc<p.count && pc<256){p.offsets[pc]}else{0};
    let calls::Call call=calls::info(p,pc,offset)?;
    // Loan staging does not copy owned arguments. The mutable handoff performs
    // atomic copying as its last fallible operation before publishing this plan.
    let usize charge=calls::cost(p,pc,offset)?;
    if(fuel<charge){return .err(errors::make(8,offset));}
    // A pending result must not overwrite a caller owner, even if no argument
    // copying is needed. Check before loan staging or payload publication.
    if(p.array_results[call.target]!=0 && frame<32){
        let usize destination=(p.code[pc*8+1] as usize)-128;
        let owners::Token current=state.tokens[frame*16+destination];
        if(current.slot!=0 || current.generation!=0){return .err(errors::make(5,offset));}
    }
    if(p.record_results[call.target]!=0 && frame<32){
        let usize destination=(p.code[pc*8+1] as usize)-144;
        let owners::Token current=record_state.tokens[frame*16+destination];
        if(current.slot!=0 || current.generation!=0){return .err(errors::make(5,offset));}
    }
    let usize depth=source::checked(p,sites,child_sites,call_sites,receipts,frames,loan,state,bytes::len(buffer),offset)?;
    if(frame>=31 || depth>=31){return .err(errors::make(12,offset));}
    if(frame!=receipts.frame){return .err(errors::make(5,offset));}
    let usize child=frame+1;var usize i=0;
    while(i<16){
        let owners::Token array=state.tokens[child*16+i];let owners::Token record=record_state.tokens[child*16+i];
        if(!absent(loan.tickets[child*16+i]) || array.slot!=0 || array.generation!=0 || record.slot!=0 || record.generation!=0){return .err(errors::make(5,offset));}
        i+=1;
    }
    i=0;while(i<8){let owners::Token root=frames.origins[child*8+i];if(root.slot!=16 || root.generation!=0){return .err(errors::make(5,offset));}i+=1;}
    var slices::Ticket[8] writers=[none();8];var slices::Ticket[8] readers=[none();8];
    var owners::Token[8] roots=[owners::Token{.slot=16,.generation=0};8];
    var usize nw=0;var usize nr=0;i=0;
    while(i<p.arities[call.target]){
        let usize encoded=p.slice_parameters[p.register_starts[call.target]+i] as usize;
        if(encoded!=0){
            let usize site=(p.call_args[call.args*8+i] as usize)-160;
            if(ir::exclusive(p,encoded-1)){
                let owners::View selected=source::view(p,sites,call.caller,frame,site,child_sites,call_sites,receipts,frames,loan,state,bytes::len(buffer),offset)?;
                if(selected.element!=ir::borrow_element(p,encoded-1)){return .err(errors::make(5,offset));}
                writers[nw]=loan.tickets[frame*16+site];roots[i]=selected.root;nw+=1;
            }else{
                roots[i]=shared::checked(p,call.caller,frame,site,frames,loan,state,bytes::len(buffer),offset)?;
                let slices::Ticket current=loan.tickets[frame*16+site];
                if(loan.pool.slots[current.slot].view.element!=ir::borrow_element(p,encoded-1)){return .err(errors::make(5,offset));}
                readers[nr]=current;nr+=1;
            }
        }
        i+=1;
    }
    // Resolve every original argument before staging either retention or rotation.
    var slices::Pool planned=slices::Pool{.slots=loan.pool.slots};
    let slices::Arguments retained=switch(slices::borrow_arguments(ref mut planned,ref readers[..nr],ref state.owners,bytes::len(buffer))){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    let authority::Entry receipt=switch(authority::prepare_call(receipts,ref mut planned,ref writers[..nw],ref state.owners,bytes::len(buffer),frame)){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
    return .ok(Prepared{.pool=planned,.receipt=receipt,.retained=retained,.roots=roots,.pc=pc,.frame=frame,.depth=depth,.remaining=fuel-charge});
}
