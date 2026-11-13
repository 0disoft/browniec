module aggregate_place_ir;
import ir as ir;
import destination_record_work as destination;
import copy_ir as copies;
import errors as errors;
import struct_meta as records;
import struct_range as ranges;
import register_set as registers;
import slice_verifier as loans;
import array_list_ir as lists;
import std::num as num;

// Analysis-only kinds 3 (whole array) and 4 (nominal record subtree).
// SELECT83: dst=place,a=root,b=0/nominal,byte5=0/target leaf,byte6..7=0.
// STORE85: dst=place,a=root,b=source root. Array tails5..7=0; record tails
// 5=target leaf,6=nominal,7=source leaf. No aggregate READ instruction exists.
// REPLACE87: dst=place,a=root,b=scalar/pool-low/first scalar. Array byte5
// 0=fill or1=list (byte6=pool-high); records repeat target leaf/nominal in5/6.
// Byte7 is always zero on REPLACE. END86 remains shared and untagged.
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
// Recipe preflight authenticates only this encoding; whole-Program proof below
// still establishes exact shapes, nominal paths, scalar roles and lifetimes.
pub fn bool reserved(ref ir::Program p,usize pc){
    if(p.count>256 || pc>=p.count){return false;}
    let usize at=pc*8;let u8 op=p.code[at];let u8 kind=p.code[at+4];
    if((op!=83 && op!=85 && op!=87) || p.code[at+1]>=16 || p.code[at+2]>=16){return false;}
    if(kind==3){
        if(op==83 && p.code[at+3]!=0){return false;}if(op==85 && p.code[at+3]>=16){return false;}
        return if(op==87){p.code[at+5]<=1 && (p.code[at+5]!=0 || p.code[at+6]==0) && p.code[at+7]==0}
            else{p.code[at+5]==0 && p.code[at+6]==0 && p.code[at+7]==0};
    }
    if(kind!=4 || p.code[at+5]>=128){return false;}
    return if(op==83){p.code[at+3]<32 && p.code[at+6]==0 && p.code[at+7]==0}
        else{p.code[at+6]<32 && if(op==85){p.code[at+3]<16 && p.code[at+7]<128}else{p.code[at+7]==0}};
}
fn Result<u8,errors::Error> byte(usize n,usize at){
    let i64 wide=switch(num::i64_from_usize(n)){case .ok(v):{v}case .err(_):{return .err(invalid(at));}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(invalid(at))}};
}
fn void tail(ref mut ir::Program p,usize pc,u8 kind,u8 x,u8 y,u8 z){
    p.code[pc*8+4]=kind;p.code[pc*8+5]=x;p.code[pc*8+6]=y;p.code[pc*8+7]=z;
}
fn Result<copies::Plan,errors::Error> array_shape(ref ir::Program p,usize root,usize at){
    if(root>=16 || root>=p.arrays.count){return .err(invalid(at));}
    return copies::array_assignment(p,root,root,p.array_functions[root] as usize,at);
}
fn Result<copies::Plan,errors::Error> record_shape(ref ir::Program p,usize root,usize nominal,usize leaf,usize at){
    if(root>=16 || root>=p.records.count){return .err(invalid(at));}
    return copies::record_assignment(p,root,root,nominal,leaf,leaf,p.record_functions[root] as usize,at);
}
pub fn Result<usize,errors::Error> select_array(ref mut ir::Program p,usize place,usize root,usize at){
    let copies::Plan shape=array_shape(p,root,at)?;if(place>=16){return .err(invalid(at));}
    let usize pc=ir::raw(p,83,place,root,0,at)?;tail(p,pc,3,0,0,0);return .ok(pc);
}
pub fn Result<usize,errors::Error> select_record_raw(ref mut ir::Program p,usize place,usize root,usize nominal,usize leaf,usize at){
    let copies::Plan shape=record_shape(p,root,nominal,leaf,at)?;if(place>=16){return .err(invalid(at));}
    let u8 target=byte(leaf,at)?;let usize pc=ir::raw(p,83,place,root,nominal,at)?;
    tail(p,pc,4,target,0,0);return .ok(pc);
}
pub fn Result<usize,errors::Error> select_record(ref mut ir::Program p,usize place,usize root,usize nominal,usize leaf,usize at){
    let u8 checked=destination::prepare(p,4,root,nominal,leaf,at)?;if(place>=16){return .err(invalid(at));}
    let u8 target=byte(leaf,at)?;let usize pc=ir::raw(p,83,place,root,nominal,at)?;
    tail(p,pc,4,target,0,0);return .ok(pc);
}
pub fn Result<usize,errors::Error> store_array(ref mut ir::Program p,usize place,usize root,usize source,usize at){
    let copies::Plan shape=array_shape(p,root,at)?;if(place>=16){return .err(invalid(at));}
    let copies::Plan checked=copies::array_assignment(p,root,source,p.array_functions[root] as usize,at)?;
    let usize pc=ir::raw(p,85,place,root,source,at)?;tail(p,pc,3,0,0,0);return .ok(pc);
}
pub fn Result<usize,errors::Error> store_record(ref mut ir::Program p,usize place,usize root,usize source,
    usize nominal,usize target_leaf,usize source_leaf,usize at){
    let copies::Plan shape=record_shape(p,root,nominal,target_leaf,at)?;if(place>=16){return .err(invalid(at));}
    let copies::Plan checked=copies::record_assignment(p,root,source,nominal,target_leaf,source_leaf,p.record_functions[root] as usize,at)?;
    let u8 target=byte(target_leaf,at)?;let u8 node=byte(nominal,at)?;let u8 origin=byte(source_leaf,at)?;
    let usize pc=ir::raw(p,85,place,root,source,at)?;tail(p,pc,4,target,node,origin);return .ok(pc);
}
pub fn Result<usize,errors::Error> fill_array(ref mut ir::Program p,usize place,usize root,usize scalar,usize at){
    let copies::Plan shape=array_shape(p,root,at)?;if(place>=16){return .err(invalid(at));}
    let usize pc=ir::raw(p,87,place,root,scalar,at)?;tail(p,pc,3,0,0,0);return .ok(pc);
}
pub fn Result<usize,errors::Error> replace_array(ref mut ir::Program p,usize place,usize root,ref usize[] values,usize at){
    let copies::Plan shape=array_shape(p,root,at)?;
    if(place>=16){return .err(invalid(at));}let u8 id=byte(place,at)?;let u8 owner=byte(root,at)?;
    // Reuse the original checked dense-pool builder, then encode its actual span.
    let usize pc=ir::array_replace_values(p,root,values,at)?;
    let u8 low=p.code[pc*8+2];let u8 high=p.code[pc*8+3];
    p.code[pc*8]=87;p.code[pc*8+1]=id;p.code[pc*8+2]=owner;p.code[pc*8+3]=low;
    tail(p,pc,3,1,high,0);return .ok(pc);
}
pub fn Result<usize,errors::Error> replace_record(ref mut ir::Program p,usize place,usize root,
    usize nominal,usize target_leaf,usize first,usize at){
    let copies::Plan shape=record_shape(p,root,nominal,target_leaf,at)?;if(place>=16){return .err(invalid(at));}
    let u8 target=byte(target_leaf,at)?;let u8 node=byte(nominal,at)?;
    let usize pc=ir::raw(p,87,place,root,first,at)?;tail(p,pc,4,target,node,0);return .ok(pc);
}
fn bool value(ref ir::Program p,usize r,usize f,u8 tag){
    return r>=p.register_starts[f] && r<p.register_ends[f] && r<128 && !p.slots[r] &&
        p.array_parameters[r]==0 && p.record_parameters[r]==0 && p.slice_parameters[r]==0 && p.types[r]==tag;
}
fn Result<usize,errors::Error> record_values(ref ir::Program p,ref records::Prepared shapes,
    usize root,usize nominal,usize leaf,usize first,usize f,usize pc){
    let usize count=switch(ranges::leaves(ref p.records.layouts,nominal)){
        case .ok(v):{v}case .err(_):{return .err(invalid(pc));}
    };
    if(leaf>shapes.leaves[root] || count>shapes.leaves[root]-leaf || first>p.register_ends[f] ||
        count>p.register_ends[f]-first){return .err(invalid(pc));}
    var usize i=0;while(i<count){if(!value(p,first+i,f,shapes.tags[root*128+leaf+i])){return .err(invalid(pc));}i+=1;}
    return .ok(count);
}
// Complete structural/domain/shape/operand checks; no builder claim is trusted.
pub fn Result<usize,errors::Error> metadata(ref ir::Program p,ref records::Prepared shapes,usize pc,usize f){
    if(p.count>256 || pc>=p.count || p.function_count>16 || f>=p.function_count || pc<p.starts[f] ||
        pc>=p.ends[f] || p.ends[f]>p.count || p.register_ends[f]>128){return .err(invalid(pc));}
    if(!reserved(p,pc)){return .err(invalid(pc));}
    let usize at=pc*8;let u8 op=p.code[at];let usize root=p.code[at+2] as usize;
    let usize b=p.code[at+3] as usize;let u8 kind=p.code[at+4];
    if(p.code[at+1]>=16 || (op!=83 && op!=85 && op!=87)){return .err(invalid(pc));}
    if(kind==3){
        let copies::Plan selected=copies::array_assignment(p,root,root,f,pc)?;
        if(op==83){if(b!=0 || pc+1>=p.ends[f]){return .err(invalid(pc));}}
        if(op==85){let copies::Plan copy=copies::array_assignment(p,root,b,f,pc)?;}
        if(op!=87){if(p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0){return .err(invalid(pc));}}
        else if(p.code[at+5]==0){
            if(p.code[at+6]!=0 || p.code[at+7]!=0 || !value(p,b,f,p.arrays.elements[root])){return .err(invalid(pc));}
        }else if(p.code[at+5]==1){
            let usize start=lists::start(p,pc);let usize length=p.arrays.lengths[root];
            if(p.code[at+7]!=0 || p.list_used>4096 || start>p.list_used || length>p.list_used-start){return .err(invalid(pc));}
            var usize i=0;while(i<length){if(!value(p,p.list_operands[start+i] as usize,f,p.arrays.elements[root])){return .err(invalid(pc));}i+=1;}
        }else{return .err(invalid(pc));}
    }else if(kind==4){
        let usize nominal=if(op==83){b}else{p.code[at+6] as usize};let usize leaf=p.code[at+5] as usize;
        let copies::Plan selected=copies::record_assignment(p,root,root,nominal,leaf,leaf,f,pc)?;
        if(op==83){if(p.code[at+6]!=0 || p.code[at+7]!=0 || pc+1>=p.ends[f]){return .err(invalid(pc));}}
        else if(op==85){let copies::Plan copy=copies::record_assignment(p,root,b,nominal,leaf,p.code[at+7] as usize,f,pc)?;}
        else{if(p.code[at+7]!=0){return .err(invalid(pc));}
            let usize count=record_values(p,shapes,root,nominal,leaf,b,f,pc)?;
        }
    }else{return .err(invalid(pc));}
    return .ok(root);
}
pub fn Result<usize,errors::Error> step(ref ir::Program p,ref records::Prepared shapes,usize pc,usize f,
    ref registers::Set defined,usize live){
    let usize root=metadata(p,shapes,pc,f)?;let usize at=pc*8;let u8 op=p.code[at];
    let bool record=p.code[at+4]==4;let usize one=1;let usize bit=one<<(root+if(record){16}else{0});
    if((live&bit)==0 || (!record && (loans::borrowed(p,root,live) || loans::exclusive(p,root,live)))){return .err(invalid(pc));}
    let usize source=p.code[at+3] as usize;
    if(op==85){let usize source_bit=one<<(source+if(record){16}else{0});
        if((live&source_bit)==0 || (!record && loans::exclusive(p,source,live))){return .err(invalid(pc));}
    }else if(op==87 && !record && p.code[at+5]==1){let usize count=lists::operands(p,pc,f,defined)?;}
    else if(op==87){
        let usize count=if(record){record_values(p,shapes,root,p.code[at+6] as usize,p.code[at+5] as usize,source,f,pc)?}else{1};
        var usize i=0;while(i<count){if(!registers::contains(defined,source+i)){return .err(invalid(pc));}i+=1;}
    }
    return .ok(live);
}
pub fn bool same_selection(ref ir::Program p,usize selected,usize pc){
    if(p.count>256 || selected>=p.count || pc>=p.count){return false;}
    let usize a=selected*8;let usize b=pc*8;
    return p.code[a]==83 && (p.code[b]==85 || p.code[b]==87) && p.code[a+4]==p.code[b+4] &&
        p.code[a+2]==p.code[b+2] && (p.code[a+4]==3 || (p.code[a+4]==4 &&
        p.code[a+3]==p.code[b+6] && p.code[a+5]==p.code[b+5]));
}
