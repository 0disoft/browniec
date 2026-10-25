module propagation;

import errors as errors;
import ir as ir;
import types as types;
import locals as locals;
import array_source as arrays;

// Success payload types may differ. Only the failure family and error payload
// must agree with the enclosing function; there are no implicit conversions.
pub fn Result<usize,errors::Error> lower(ref mut ir::Program p,ref locals::Table table,usize subject,u8 result_type,usize at) {
    let u8 source_type=p.types[subject];
    let bool option=source_type>=3 && source_type<=4 && result_type>=3 && result_type<=4;
    let bool result=source_type>=5 && source_type<=8 && result_type>=5 && result_type<=8
        && types::payload(source_type,0)==types::payload(result_type,0);
    if(!option && !result) {return .err(errors::make(3,at));}
    let ir::Case success=ir::branch_case(p,subject,1,at)?;
    let usize skip=ir::raw(p,19,0,0,0,at)?;
    let usize failure_start=p.count;
    let usize failure_target=ir::patch(p,success.instruction,failure_start,at)?;
    let ir::Case failure=ir::branch_case(p,subject,0,at)?;
    let usize wrapped=ir::construct(p,result_type,0,failure.payload,at)?;
    // Only the failure branch returns. The successful payload keeps its owners.
    let usize dropped=arrays::release_visible(table,p,at)?;
    let usize returned=ir::emit(p,8,wrapped,0,at)?;
    let usize trap=p.count;
    let usize guarded=ir::patch(p,failure.instruction,trap,at)?;
    let usize failed=ir::raw(p,25,0,0,0,at)?;
    let usize continuation=p.count;
    let usize continued=ir::patch(p,skip,continuation,at)?;
    return .ok(success.payload);
}
