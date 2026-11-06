module value_join_source;
import ir as ir;
import types as types;
import record_expression_source as records;
import struct_value_source as fields;
import errors as errors;

// Source-lowering recipe only: 0 untyped, 1 scalar/tagged, 2 array, 3 record.
// A missing value is never a live runtime owner. Branches initialize the same
// destination, and the independent CFG verifier still proves every live path.
pub struct Join { u8 kind; u8 tag; usize size; usize value; bool mutable;
    // Compiler-only candidates for existing tags 3..8. Provisional constructor
    // registers cannot escape the join before a unique type is established.
    u8 candidates; usize[2] pending;
}
pub fn Join empty(u8 expected,bool mutable){
    return Join{.kind=0,.tag=expected,.size=0,.value=256,.mutable=mutable,.candidates=0,.pending=[0;2]};
}
pub fn Join array(u8 element,usize length,bool mutable){
    return Join{.kind=2,.tag=element,.size=length,.value=256,.mutable=mutable,.candidates=0,.pending=[0;2]};
}
pub fn Join record(usize nominal,bool mutable){
    return Join{.kind=3,.tag=0,.size=nominal,.value=256,.mutable=mutable,.candidates=0,.pending=[0;2]};
}
fn u8 bit(u8 tag){return if(tag==3){1}else if(tag==4){2}else if(tag==5){4}
    else if(tag==6){8}else if(tag==7){16}else if(tag==8){32}else{0};}
fn u8 first(u8 mask){return if((mask&1)!=0){3}else if((mask&2)!=0){4}else if((mask&4)!=0){5}
    else if((mask&8)!=0){6}else if((mask&16)!=0){7}else if((mask&32)!=0){8}else{0};}
fn bool unique(u8 mask){return mask!=0 && (mask&(mask-1))==0;}
fn Result<usize,errors::Error> constrained(ref mut ir::Program p,ref mut Join join,
    usize value,u8 allowed,bool provisional,usize at){
    if(value>=128 || value>=p.registers || allowed==0 || allowed>63 ||
        (join.kind!=0 && join.kind!=1)){return .err(errors::make(3,at));}
    let u8 prior=if(join.candidates!=0){join.candidates}else if(join.tag!=0){bit(join.tag)}else{63};
    let u8 mask=prior&allowed;if(mask==0){return .err(errors::make(3,at));}
    join.kind=1;join.candidates=mask;join.tag=if(unique(mask)){first(mask)}else{0};
    if(provisional){let usize one=1;join.pending[value/64]|=one<<(value%64);}
    if(join.value==256){join.value=ir::slot(p,first(mask),at)?;}
    return ir::raw(p,18,join.value,value,0,at);
}
// Missing domains remain alternatives until another continuing arm constrains
// them. Only existing i32/bool wrappers are candidates; no runtime type is added.
pub fn Result<usize,errors::Error> constructor(ref mut ir::Program p,ref mut Join join,
    bool option,u8 variant,usize payload,usize at){
    if(variant>1 || (option && variant==0 && payload!=0)){return .err(errors::make(3,at));}
    let u8 tag=if(option && variant==0){0}else{
        if(payload>=128 || payload>=p.registers){return .err(errors::make(3,at));}p.types[payload]};
    let u8 mask=if(option){if(variant==0){3}else if(tag==1){1}else if(tag==2){2}else{0}}
        else if(variant==1){if(tag==1){12}else if(tag==2){48}else{0}}
        else{if(tag==1){20}else if(tag==2){40}else{0}};
    if(mask==0){return .err(errors::make(3,at));}
    let usize value=ir::construct(p,first(mask),variant,payload,at)?;
    return constrained(p,join,value,mask,true,at);
}
pub fn Result<usize,errors::Error> scalar(ref mut ir::Program p,ref mut Join join,usize value,usize at){
    if(join.candidates!=0){
        if(value>=128 || value>=p.registers){return .err(errors::make(3,at));}
        let u8 allowed=bit(p.types[value]);return constrained(p,join,value,allowed,false,at);
    }
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
    if(join.candidates!=0){
        if(join.kind!=1 || !unique(join.candidates) || join.value>=p.registers || p.registers>128){return .err(errors::make(3,at));}
        let u8 tag=first(join.candidates);let usize one=1;var usize r=0;
        while(r<p.registers){if((join.pending[r/64]&(one<<(r%64)))!=0){p.types[r]=tag;}r+=1;}
        p.types[join.value]=tag;
    }
    return if(join.kind==1){ir::emit(p,17,join.value,0,at)}else{.ok(join.value)};
}
