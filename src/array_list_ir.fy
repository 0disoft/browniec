module array_list_ir;
import ir as ir;
import errors as errors;
import register_set as registers;

pub fn usize start(ref ir::Program p,usize pc){
    return p.code[pc*8+2] as usize+256*(p.code[pc*8+3] as usize);
}
// Reconstruct dense nonoverlapping spans from actual instructions. Unused pool
// bytes must be zero; dangling/overlapping/forged operand metadata cannot hide.
pub fn Result<usize,errors::Error> metadata(ref ir::Program p){
    if(p.count>256 || p.arrays.count>16 || p.list_used>4096){return .err(errors::make(5,0));}
    var usize cursor=0;var usize pc=0;
    while(pc<p.count){if(p.code[pc*8]==80){let usize id=p.code[pc*8+1] as usize;
        if(id>=p.arrays.count || start(p,pc)!=cursor){return .err(errors::make(5,pc));}
        let usize length=p.arrays.lengths[id];
        if(length==0 || length>4096 || cursor>p.list_used || length>p.list_used-cursor){return .err(errors::make(5,pc));}
        cursor+=length;
    }pc+=1;}
    if(cursor!=p.list_used){return .err(errors::make(5,0));}
    while(cursor<4096){if(p.list_operands[cursor]!=0){return .err(errors::make(5,0));}cursor+=1;}
    return .ok(p.list_used);
}
// Called in the canonical function CFG with independently reconstructed scalar
// definitions. A slot, aggregate/formal marker or cross-function value is not a cell.
pub fn Result<usize,errors::Error> operands(ref ir::Program p,usize pc,usize f,ref registers::Set defined){
    let usize id=p.code[pc*8+1] as usize;
    if(f>=p.function_count || id>=p.arrays.count || id>=16){return .err(errors::make(5,pc));}
    let usize at=start(p,pc);let usize length=p.arrays.lengths[id];
    if(p.list_used>4096 || at>p.list_used || length>p.list_used-at){return .err(errors::make(5,pc));}
    var usize i=0;while(i<length){let usize r=p.list_operands[at+i] as usize;
        if(r<p.register_starts[f] || r>=p.register_ends[f] || r>=128 || p.slots[r] ||
            p.types[r]!=p.arrays.elements[id] || p.array_parameters[r]!=0 || p.record_parameters[r]!=0 ||
            p.slice_parameters[r]!=0 || !registers::contains(defined,r)){return .err(errors::make(5,pc));}i+=1;
    }return .ok(length);
}
