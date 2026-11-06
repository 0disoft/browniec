module array_list_vm;
import ir as ir;
import array_list_ir as lists;
import array_vm as arrays;
import array_layout as layouts;
import array_owners as owners;
import errors as errors;
import fuel as meter;
import std::vec as vec;
import std::bytes as bytes;

// Invocation-local scratch stays in two separate owning locals, outside the
// copyable owner/token plans. Loop/CALL executions reuse initialized storage.
pub struct Requirement { usize length; usize bytes; usize cost; }
pub fn Result<Requirement,errors::Error> requirement(ref ir::Program p){
    if(p.count>256 || p.list_used>4096){return .err(errors::make(5,0));}
    if(p.list_used==0){return .ok(Requirement{.length=0,.bytes=0,.cost=0});}
    var usize length=0;var usize size=0;var usize pc=0;
    while(pc<p.count){if(lists::operation(p,pc)){let usize id=lists::destination(p,pc);
        if(id>=16 || id>=p.arrays.count){return .err(errors::make(5,pc));}
        let layouts::Array layout=switch(layouts::scalar(p.arrays.elements[id],p.arrays.lengths[id])){
            case .ok(v):{v}case .err(_):{return .err(errors::make(5,pc));}
        };
        if(layout.length>length){length=layout.length;}if(layout.bytes>size){size=layout.bytes;}
    }pc+=1;}
    if(length==0){return .err(errors::make(5,0));}
    // At most 256 instruction visits, cell initialization and prepaid vector
    // destruction, plus byte zeroing. No setup charge for existing programs.
    return .ok(Requirement{.length=length,.bytes=size,.cost=meter::list_prepare(length,size)});
}
pub fn Result<vec::Vec<i64>,errors::Error> prepare_values(ref Requirement plan){
    if(plan.length>4096 || plan.bytes>32768 || (plan.length==0)!=(plan.bytes==0)){
        return .err(errors::make(5,0));}
    var vec::Vec<i64> values=vec::empty<i64>();
    if(plan.length!=0){
        let usize reserved=switch(vec::reserve<i64>(ref mut values,plan.length)){
            case .ok(v):{v}case .err(_):{return .err(errors::make(15,0));}
        };
        var usize i=0;while(i<plan.length){let usize pushed=switch(vec::push<i64>(ref mut values,0)){
            case .ok(v):{v}case .err(_):{return .err(errors::make(15,0));}
        };i+=1;}
    }
    return .ok(values);
}
pub fn Result<bytes::Buffer,errors::Error> prepare_encoded(ref Requirement plan){
    if(plan.length>4096 || plan.bytes>32768 || (plan.length==0)!=(plan.bytes==0)){
        return .err(errors::make(5,0));}
    return if(plan.bytes==0){.ok(bytes::empty())}else{arrays::prepare(plan.bytes)};
}
pub fn Result<usize,errors::Error> cost(ref ir::Program p,usize pc){
    if(pc>=p.count || pc>=256 || (p.code[pc*8]!=80 && p.code[pc*8]!=81)){return .err(errors::make(5,pc));}
    let usize id=p.code[pc*8+1] as usize;
    if(id>=16 || id>=p.arrays.count){return .err(errors::make(5,pc));}
    let layouts::Array layout=switch(layouts::scalar(p.arrays.elements[id],p.arrays.lengths[id])){
        case .ok(v):{v}case .err(_):{return .err(errors::make(5,pc));}
    };
    // Register gathering, full codec staging and final byte copy. Replacement
    // keeps the existing-owner envelope; creation also prepays seven padding bytes.
    // Both ordinary prices include dispatch.
    return .ok(meter::list_instruction(p.code[pc*8]==81,layout.length,layout.bytes));
}
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize pc,usize frame,
    ref mut arrays::State state,ref mut u8[] data,ref i64[] registers,
    ref mut vec::Vec<i64> cells,ref mut bytes::Buffer scratch,usize fuel){
    if(pc<p.count && pc<256 && p.code[pc*8]==81){
        return replace(p,pc,frame,ref state.owners,ref state.tokens,data,registers,cells,scratch,fuel);
    }
    let usize price=cost(p,pc)?;let usize offset=p.offsets[pc];
    if(fuel<price){return .err(errors::make(8,offset));}
    let usize id=p.code[pc*8+1] as usize;
    if(frame>=32 || state.tokens[frame*16+id].generation!=0){return .err(errors::make(5,offset));}
    let layouts::Array layout=gather(p,pc,registers,cells,scratch)?;
    let ref i64[] values=vec::view_i64(cells);let ref mut u8[] encoded=bytes::view_mut(scratch);
    let owners::Token token=switch(owners::create_values(ref layout,values[..layout.length],encoded[..layout.bytes],data,ref mut state.owners)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    state.tokens[frame*16+id]=token;return .ok(fuel-price);
}
// Replacement cannot publish owner/token metadata. The retained driver therefore
// passes read-only bindings directly instead of copying a 512-token owner plan.
pub fn Result<usize,errors::Error> replace(ref ir::Program p,usize pc,usize frame,
    ref owners::Table table,ref owners::Token[] tokens,ref mut u8[] data,ref i64[] registers,
    ref mut vec::Vec<i64> cells,ref mut bytes::Buffer scratch,usize fuel){
    let usize price=cost(p,pc)?;let usize offset=p.offsets[pc];
    if(fuel<price){return .err(errors::make(8,offset));}
    let usize id=p.code[pc*8+1] as usize;
    if(p.code[pc*8]!=81 || frame>=32 || tokens.len!=512 || tokens[frame*16+id].generation==0){
        return .err(errors::make(5,offset));}
    let layouts::Array layout=gather(p,pc,registers,cells,scratch)?;
    let ref i64[] values=vec::view_i64(cells);let ref mut u8[] encoded=bytes::view_mut(scratch);
    let usize changed=switch(owners::replace_values(ref layout,tokens[frame*16+id],values[..layout.length],
        encoded[..layout.bytes],data,table)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    return .ok(fuel-price);
}
fn Result<layouts::Array,errors::Error> gather(ref ir::Program p,usize pc,ref i64[] registers,
    ref mut vec::Vec<i64> cells,ref bytes::Buffer scratch){
    let usize offset=p.offsets[pc];let usize id=p.code[pc*8+1] as usize;let usize begin=lists::start(p,pc);
    let layouts::Array layout=switch(layouts::scalar(p.arrays.elements[id],p.arrays.lengths[id])){
        case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}
    };
    if(p.list_used>4096 || begin>p.list_used || layout.length>p.list_used-begin ||
        vec::len<i64>(cells)<layout.length || bytes::len(scratch)<layout.bytes){return .err(errors::make(5,offset));}
    let ref mut i64[] values=vec::view_mut_i64(cells);
    var usize i=0;while(i<layout.length){let usize r=p.list_operands[begin+i] as usize;
        if(r>=128 || r>=registers.len){return .err(errors::make(5,offset));}values[i]=registers[r];i+=1;
    }
    return .ok(layout);
}
