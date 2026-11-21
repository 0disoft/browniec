module aggregate_place_source;
import aggregate_place_ir as stores;
import place_source as places;
import ir as ir;
import locals as locals;
import record_expression_source as expressions;
import struct_value_source as records;
import errors as errors;
import aggregate_copy_source_work as copies;
import runtime_clock as clock;

// Parser callers select into their lexical snapshot BEFORE evaluating RHS.
// End the captured destination before releasing any anonymous result owner.
pub fn Result<usize,errors::Error> copy_array(ref mut ir::Program p,ref mut locals::Table names,
    usize place,usize root,usize source,bool owned,usize at){
    if(owned && source==root){return .err(errors::make(3,at));}
    let usize stored=stores::store_array(p,place,root,source,at)?;
    let usize ended=places::end(p,names,place,at)?;
    if(owned){let usize dropped=ir::array_drop(p,source,at)?;}return .ok(stored);
}
pub fn Result<usize,errors::Error> fill_array(ref mut ir::Program p,ref mut locals::Table names,
    usize place,usize root,usize scalar,usize at){
    let usize stored=stores::fill_array(p,place,root,scalar,at)?;
    let usize ended=places::end(p,names,place,at)?;return .ok(stored);
}
pub fn Result<usize,errors::Error> list_array(ref mut ir::Program p,ref mut locals::Table names,
    usize place,usize root,ref usize[] values,usize at){
    let usize stored=stores::replace_array(p,place,root,values,at)?;
    let usize ended=places::end(p,names,place,at)?;return .ok(stored);
}
pub fn Result<usize,errors::Error> record(ref mut ir::Program p,ref mut locals::Table names,
    usize place,usize root,records::Leaf target,ref expressions::Value value,usize at,usize deadline,ref mut usize fuel){
    if(root>=p.records.count || !p.records.mutable[root] || target.tag!=0 || value.tag!=0 ||
        target.record!=value.record || (value.owned && (value.id==root || value.id==16))){return .err(errors::make(3,at));}
    var usize stored=0;
    if(value.id==16){let usize count=records::leaf_count_metered(p,value.record,at,deadline,fuel)?;
        if(value.ordinal>16 || count>16-value.ordinal){return .err(errors::make(4,at));}
        var copies::State w=copies::begin(6,16,value.record,value.ordinal,0,0,false,false,at,at);
        // Reuse the validated count rather than scanning metadata a second time.
        w.count=count;w.phase=1;var usize[1] slots=[0];
        let usize first=records::copy_work_metered(p,ref value.slots,ref mut slots,ref mut w,deadline,fuel)?;
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        stored=stores::replace_record(p,place,root,target.record,target.ordinal,first,at)?;
    }else{stored=stores::store_record(p,place,root,value.id,target.record,target.ordinal,value.ordinal,at)?;}
    let usize ended=places::end(p,names,place,at)?;
    if(value.owned){let usize dropped=ir::record_drop(p,value.id,at)?;}return .ok(stored);
}
