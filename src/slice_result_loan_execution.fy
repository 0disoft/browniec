module slice_result_loan_execution;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import slice_authority as authority;
import array_slices as slices;
import array_owners as owners;
import array_vm as arrays;
import ir as ir;
import cells as cells;
import errors as errors;
import fuel as meter;
import array_layout as layouts;

// Private rootless-formal/subview dialect. IR and frame/site bounds are proved
// before execution. Physical metadata mutations stage independently of payload.
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize pc,
    ref mut frames::Frames bindings,ref mut runtime::State state,
    ref mut i64[] registers,ref mut u8[] data,usize fuel){
    let usize at=pc*8;let usize offset=p.offsets[pc];let u8 op=p.code[at];
    let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    let usize base=bindings.frame*16;
    let usize site=if(op==60){dst}else{a};
    var usize stride=0;
    if(op==58 || op==60){
        let u8 tag=ir::slice_element(p,site,offset)?;
        let layouts::Array shape=switch(layouts::scalar(tag,1)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}};
        stride=shape.stride;
    }
    var usize cost=meter::slice_base(op,stride);
    if(fuel<cost){return .err(errors::make(8,offset));}
    if(op==56 && p.slice_roots[dst]==0 && p.slice_origins[dst] as usize==dst+1){
        // Formal sessions belong to the CALL transaction. Source CLOSE ends the
        // logical site; physical release/restoration is performed at return.
        bindings.sites[base+dst]=frames::none();return .ok(fuel-cost);
    }
    if(op==55){
        // Authenticate under the base reserve before pricing the bounded scan.
        let slices::Ticket current=bindings.sites[base+a];
        let usize length=switch(slices::length(ref state.runtime.pool,current,ref state.runtime.owners,data.len)){
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
        };
        cost+=meter::utf8_scan(state.runtime.pool.slots[current.slot].view.length);
        if(fuel<cost){return .err(errors::make(8,offset));}
        let bool value=switch(slices::utf8(ref state.runtime.pool,bindings.sites[base+a],ref state.runtime.owners,data)){
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
        };registers[dst]=if(value){1}else{0};
    }else if(op==57){
        let usize value=switch(slices::length(ref state.runtime.pool,bindings.sites[base+a],ref state.runtime.owners,data.len)){
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
        };registers[dst]=cells::pack(value,offset)?;
    }else if(op==58){
        let usize index=cells::unpack(registers[b],offset)?;
        registers[dst]=switch(slices::read(ref state.runtime.pool,bindings.sites[base+a],ref state.runtime.owners,index,data)){
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
        };
    }else if(op==60){
        let usize index=cells::unpack(registers[a],offset)?;
        let usize wrote=switch(slices::write(ref state.runtime.pool,bindings.sites[base+dst],ref state.runtime.owners,index,registers[b],data)){
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
        };
    }else{
        var authority::State stack=state.runtime.authority;var slices::Pool pool=state.runtime.pool;
        var owners::Table table=state.runtime.owners;var slices::Ticket issued=frames::none();
        if(op==54){
            if(bindings.sites[base+dst].slot!=16){return .err(errors::make(5,offset));}
            let usize root=p.slice_roots[dst] as usize-1;let owners::Token token=bindings.tokens[base+root];
            let usize lo=cells::unpack(registers[a],offset)?;let usize hi=cells::unpack(registers[b],offset)?;
            issued=switch(if(ir::exclusive(p,dst)){slices::open_exclusive(ref mut pool,ref mut table,token,lo,hi,data.len)}else{slices::open(ref mut pool,ref mut table,token,lo,hi,data.len)}){
                case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
            };
        }else if(op==56){
            let usize closed=switch(slices::close(ref mut pool,bindings.sites[base+dst],ref mut table,data.len)){
                case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
            };
        }else if(op==59 || op==61){
            let usize lo=cells::unpack(registers[b],offset)?;let usize hi=cells::unpack(registers[p.code[at+4] as usize],offset)?;
            if(bindings.sites[base+dst].slot!=16){return .err(errors::make(5,offset));}
            let slices::Ticket parent=bindings.sites[base+a];
            if(op==61 && stack.depth>=31){return .err(errors::make(12,offset));}
            issued=switch(if(op==59){slices::subslice(ref mut pool,parent,ref table,lo,hi,data.len)}else{
                authority::enter_child(ref mut stack,ref mut pool,parent,ref table,lo,hi,data.len,bindings.frame)
            }){case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}};
        }else if(op==62){
            issued=switch(authority::leave_child(ref mut stack,ref mut pool,bindings.sites[base+dst],ref table,data.len,bindings.frame)){
                case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
            };
        }else{return .err(errors::make(5,offset));}
        state.runtime=runtime::Runtime{.authority=stack,.pool=pool,.owners=table};
        if(op==62){bindings.sites[base+a]=issued;bindings.sites[base+dst]=frames::none();}
        else{bindings.sites[base+dst]=issued;if(op==61){bindings.sites[base+a]=frames::none();}}
    }
    return .ok(fuel-cost);
}
