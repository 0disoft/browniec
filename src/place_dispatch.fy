module place_dispatch;
import ir as ir;
import place_ir as graph;
import place_vm as frames;
import slice_place_vm as slices;
import record_place_vm as records;
import aggregate_place_vm as aggregates;
import array_owners as owners;
import array_slices as loans;
import errors as errors;
import fuel as meter;
import std::vec as vec;
import std::bytes as bytes;

// One shared namespace, counter and allocation for every pending location.
// Existing invocations retain their exact original storage and setup prices.
pub struct Requirement { usize width; usize cost; bool aggregate; bool slices; bool records; }
pub fn Result<Requirement,errors::Error> requirement(ref ir::Program p){
    return requirement_until(p,0);
}
pub fn Result<Requirement,errors::Error> requirement_until(ref ir::Program p,usize deadline){
    let aggregates::Requirement extended=aggregates::requirement_until(p,deadline)?;
    if(extended.width!=0){return .ok(Requirement{.width=extended.width,.cost=extended.cost,
        .aggregate=true,.slices=false,.records=false});}
    let records::Requirement old=records::requirement_until(p,deadline)?;
    return .ok(Requirement{.width=old.width,.cost=old.cost,.aggregate=false,.slices=old.slices,.records=old.records});
}
pub fn Result<vec::Vec<usize>,errors::Error> prepare_metered(ref Requirement plan,usize fuel){
    if(plan.aggregate){
        if(plan.width==0 || plan.slices || plan.records){return .err(errors::make(5,0));}
        let aggregates::Requirement selected=aggregates::Requirement{.width=plan.width,.cost=plan.cost};
        return aggregates::prepare_metered(ref selected,fuel);
    }
    let records::Requirement old=records::Requirement{.width=plan.width,.slices=plan.slices,.records=plan.records,.cost=plan.cost};
    return records::prepare_metered(ref old,fuel);
}
pub fn Result<usize,errors::Error> empty_frame(ref vec::Vec<usize> state,usize frame,usize at){
    return frames::empty_frame(state,frame,at);
}
// No payload/owners are inspected. END routes through the selected row, never
// through its untagged instruction or the caller's current destination binding.
fn Result<bool,errors::Error> aggregate(ref ir::Program p,usize pc,usize frame,ref vec::Vec<usize> state){
    if(p.count>256 || pc>=p.count || frame>=32 || !graph::operation(p.code[pc*8])){return .err(errors::make(5,pc));}
    let usize at=pc*8;let frames::Format shape=frames::format(state,p.offsets[pc])?;
    let usize id=p.code[at+if(p.code[at]==84){2}else{1}] as usize;
    if(id>=shape.width){return .err(errors::make(5,p.offsets[pc]));}
    if(p.code[at]!=86){return .ok(p.code[at+4]>=3);}
    return .ok(shape.prefix==3 && vec::view_usize(state)[4+frame*(18*shape.width+1)+18*id+15]>=3);
}
pub fn Result<usize,errors::Error> price(ref ir::Program p,usize pc,usize function,usize frame,ref vec::Vec<usize> state){
    let bool selected=aggregate(p,pc,frame,state)?;
    if(selected){return aggregates::cost(p,pc,function);}
    let frames::Format shape=frames::format(state,p.offsets[pc])?;
    if(p.code[pc*8+4]==2 || (p.code[pc*8]==86 && shape.prefix>=2)){return records::price(p,pc,function,state);}
    return slices::cost(p,pc,shape.row>=14);
}
// Current record bindings come from the coordinator after its own price
// preflight. Array/slice maps are read only after this identical preflight.
// Native token/session/generation/window authentication remains in each adapter.
pub fn Result<usize,errors::Error> bound(ref ir::Program p,usize pc,usize function,usize frame,
    ref mut vec::Vec<usize> state,ref owners::Table table,ref owners::Token[] arrays,
    owners::Token record,owners::Token record_source,ref loans::Pool pool,ref loans::Ticket[] bindings,
    ref mut u8[] data,ref mut i64[] registers,ref mut vec::Vec<i64> cells,ref mut bytes::Buffer scratch,usize fuel){
    let usize work=price(p,pc,function,frame,state)?;let usize at=pc*8;let usize offset=p.offsets[pc];
    if(fuel<work){return .err(errors::make(8,offset));}
    let bool selected=aggregate(p,pc,frame,state)?;
    if(selected){let u8 op=p.code[at];let bool array=p.code[at+4]==3;
        var owners::Token current=record;var owners::Token source=record_source;
        if(array && (op==83 || op==85)){
            if(arrays.len!=512){return .err(errors::make(5,offset));}
            if(op==83){current=arrays[frame*16+p.code[at+2] as usize];}
            else{source=arrays[frame*16+p.code[at+3] as usize];}
        }
        return aggregates::bound(p,pc,function,frame,state,table,current,source,data,registers,cells,scratch,fuel);
    }
    let frames::Format shape=frames::format(state,offset)?;
    if(p.code[at+4]==2 || (p.code[at]==86 && shape.prefix>=2)){
        return records::bound(p,pc,function,frame,state,table,record,data,registers,fuel);
    }
    return slices::bound(p,pc,function,frame,state,table,arrays,pool,bindings,data,registers,fuel);
}
// Setup prices already include bounded metadata destruction. Zero-Fuel failure
// cleanup touches no owners or payload; exact formats keep their own prefixes.
pub fn void abort(ref mut vec::Vec<usize> state){
    let usize count=vec::len<usize>(state);let usize prefix=count%32;
    let ref mut usize[] words=vec::view_mut_usize(state);var usize i=prefix;
    while(i<count){words[i]=0;i+=1;}
}
