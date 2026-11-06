module slice_place_ir;
import ir as ir;
import errors as errors;

// Kind 1 in byte4 of SELECT/READ/STORE names an exclusive slice site;
// kind 0 keeps the existing owned-array encoding. END is shared and untagged.
// These builders reserve shape only. They confer neither affine authority nor
// executable admission; the complete independent proof lives in verifier.
fn Result<u8,errors::Error> shape(ref ir::Program p,usize site,usize at) {
    if(!ir::exclusive(p,site)){return .err(errors::make(3,at));}
    return ir::slice_element(p,site,at);
}
fn bool scalar(ref ir::Program p,usize r,u8 tag) {
    return r<128 && r<p.registers && p.types[r]==tag && !p.slots[r] &&
        p.array_parameters[r]==0 && p.record_parameters[r]==0 && p.slice_parameters[r]==0;
}
pub fn Result<usize,errors::Error> select(ref mut ir::Program p,usize place,usize site,usize index,usize at) {
    let u8 tag=shape(p,site,at)?;
    if(place>=16 || !scalar(p,index,12)){return .err(errors::make(3,at));}
    let usize pc=ir::raw(p,83,place,site,index,at)?;p.code[pc*8+4]=1;return .ok(pc);
}
pub fn Result<usize,errors::Error> read(ref mut ir::Program p,usize place,usize site,usize at) {
    let u8 tag=shape(p,site,at)?;
    if(place>=16){return .err(errors::make(3,at));}
    if(p.registers>=128 || p.count>=256){return .err(errors::make(4,at));}
    let usize dst=p.registers;let usize pc=ir::raw(p,84,dst,place,site,at)?;
    p.code[pc*8+4]=1;p.types[dst]=tag;p.registers+=1;return .ok(dst);
}
pub fn Result<usize,errors::Error> store(ref mut ir::Program p,usize place,usize site,usize value,usize at) {
    let u8 tag=shape(p,site,at)?;
    if(place>=16 || !scalar(p,value,tag)){return .err(errors::make(3,at));}
    let usize pc=ir::raw(p,85,place,site,value,at)?;p.code[pc*8+4]=1;return .ok(pc);
}

// Called after canonical partition/catalog/parameter admission. Reconstruct
// exact shape and containing function from the actual slice metadata, never
// from the repeated instruction operand or compiler ownership claims.
pub fn Result<u8,errors::Error> element(ref ir::Program p,usize site,usize f,usize pc) {
    if(f>=p.function_count || f>=16){return .err(errors::make(5,pc));}
    let u8 tag=switch(shape(p,site,pc)){
        case .ok(v):{v}case .err(_):{return .err(errors::make(5,pc));}
    };
    let usize root=p.slice_roots[site] as usize;
    if(if(root!=0){p.array_functions[root-1] as usize!=f}else{p.slice_functions[site] as usize!=f+1}){
        return .err(errors::make(5,pc));
    }
    return .ok(tag);
}
