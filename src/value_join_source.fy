module value_join_source;
import ir as ir;
import types as types;
import record_expression_source as records;
import struct_value_source as fields;
import errors as errors;

// Source-lowering recipe only: 0 untyped, 1 scalar/tagged, 2 array, 3 record.
// A missing value is never a live runtime owner. Branches initialize the same
// destination, and the independent CFG verifier still proves every live path.
pub struct Join { u8 kind; u8 tag; usize size; usize value; bool mutable; }
pub fn Join empty(u8 expected,bool mutable){
    return Join{.kind=0,.tag=expected,.size=0,.value=256,.mutable=mutable};
}
pub fn Join array(u8 element,usize length,bool mutable){
    return Join{.kind=2,.tag=element,.size=length,.value=256,.mutable=mutable};
}
pub fn Join record(usize nominal,bool mutable){
    return Join{.kind=3,.tag=0,.size=nominal,.value=256,.mutable=mutable};
}
pub fn Result<usize,errors::Error> scalar(ref mut ir::Program p,ref mut Join join,usize value,usize at){
    if(value>=p.registers || value>=128 || (join.kind!=0 && join.kind!=1) ||
        (join.tag!=0 && join.tag!=p.types[value])){return .err(errors::make(3,at));}
    join.kind=1;join.tag=p.types[value];
    if(join.value==256){join.value=ir::slot(p,join.tag,at)?;}
    return ir::raw(p,18,join.value,value,0,at);
}
// A subsequent arm may construct or CALL straight into an existing recipe.
// Shape must be known exactly; source lookahead itself grants no authority.
pub fn usize array_target(ref Join join,u8 element,usize length){
    return if(join.kind==2 && join.tag==element && join.size==length && join.value!=256){join.value-128}else{16};
}
pub fn usize record_target(ref Join join,usize nominal){
    return if(join.kind==3 && join.size==nominal && join.value!=256){join.value-144}else{16};
}
pub fn Result<usize,errors::Error> accept_array(ref mut ir::Program p,ref mut Join join,
    usize function,usize id,bool owned,usize at){
    if(id>=16 || id>=p.arrays.count || p.array_functions[id] as usize!=function ||
        (join.kind!=0 && join.kind!=2) ||
        (join.kind==2 && ((join.tag!=0 && join.tag!=p.arrays.elements[id]) ||
            (join.size!=0 && join.size!=p.arrays.lengths[id])))){return .err(errors::make(3,at));}
    join.kind=2;join.tag=p.arrays.elements[id];join.size=p.arrays.lengths[id];
    if(join.value==256){
        if(owned){join.value=128+id;p.arrays.mutable[id]=join.mutable;return .ok(id);}
        join.value=128+ir::array_in(p,function,join.tag,join.size,join.mutable,at)?;
    }
    let usize destination=join.value-128;
    if(destination==id){if(!owned){return .err(errors::make(3,at));}return .ok(id);}
    let usize copied=ir::array_copy(p,destination,id,at)?;
    if(owned){let usize dropped=ir::array_drop(p,id,at)?;}return .ok(destination);
}
pub fn Result<usize,errors::Error> accept_record(ref mut ir::Program p,ref mut Join join,
    usize function,ref records::Value value,usize at){
    if(value.tag!=0 || (join.kind!=0 && join.kind!=3) ||
        (join.kind==3 && join.size!=value.record)){return .err(errors::make(3,at));}
    join.kind=3;join.size=value.record;join.tag=0;
    if(join.value==256){
        if(value.owned && records::whole(p,value)){
            join.value=144+value.id;p.records.mutable[value.id]=join.mutable;return .ok(value.id);
        }
        join.value=144+ir::record_in(p,function,value.record,join.mutable,at)?;
    }
    let usize destination=join.value-144;
    if(value.id==destination){if(!value.owned || !records::whole(p,value)){return .err(errors::make(3,at));}return .ok(destination);}
    if(records::whole(p,value)){let usize copied=ir::record_copy(p,destination,value.id,at)?;}
    else{
        let usize count=fields::leaf_count(p,value.record,at)?;let usize first=p.registers;
        var usize i=0;while(i<count){
            let usize read=if(value.id==16){ir::emit(p,17,value.slots[value.ordinal+i],0,at)?}
                else{ir::record_read(p,value.id,value.ordinal+i,at)?};i+=1;
        }
        let usize initialized=ir::record_init(p,destination,first,at)?;
    }
    if(value.owned){let usize dropped=ir::record_drop(p,value.id,at)?;}return .ok(destination);
}
pub fn Result<usize,errors::Error> finish(ref mut ir::Program p,ref Join join,usize at){
    if(join.value==256){return .err(errors::make(3,at));}
    return if(join.kind==1){ir::emit(p,17,join.value,0,at)}else{.ok(join.value)};
}
