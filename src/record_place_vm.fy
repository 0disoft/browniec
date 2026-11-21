module record_place_vm;
import ir as ir;
import place_ir as proof;
import record_place_ir as typing;
import place_vm as frames;
import slice_place_vm as mixed;
import record_places as places;
import struct_meta as records;
import scalar_codec as codec;
import array_owners as owners;
import array_vm as failures;
import errors as errors;
import runtime_clock as clock;
import metadata_budget as budget;
import fuel as meter;
import std::vec as vec;

// Private adapter only. This plan is storage metadata, never execution admission.
pub struct Requirement { usize width; bool slices; bool records; usize cost; }
fn Result<usize,errors::Error> kind(ref ir::Program p,usize pc){
    if(p.count>256 || pc>=p.count || pc>=256){return .err(errors::make(5,pc));}
    let usize at=pc*8;let u8 op=p.code[at];let usize mode=p.code[at+4] as usize;
    let usize id=p.code[at+if(op==84){2}else{1}] as usize;
    if(!proof::operation(op) || mode>2 || id>=16 || p.code[at+6]!=0 || p.code[at+7]!=0 ||
        (mode!=2 && p.code[at+5]!=0) || (mode==2 && (p.code[at+5]>=128 || (op==83 && p.code[at+3]!=0))) ||
        (op==86 && (mode!=0 || p.code[at+2]!=0 || p.code[at+3]!=0))){return .err(errors::make(5,pc));}
    return .ok(mode);
}
pub fn Result<Requirement,errors::Error> requirement(ref ir::Program p){
    return requirement_until(p,0);
}
pub fn Result<Requirement,errors::Error> requirement_until(ref ir::Program p,usize deadline){
    var usize fuel=budget::unlimited();
    return requirement_with_compile_fuel(p,deadline,ref mut fuel);
}
pub fn Result<Requirement,errors::Error> requirement_with_compile_fuel(ref ir::Program p,usize deadline,ref mut usize fuel){
    if(p.count>256){return .err(errors::make(5,0));}
    var usize width=0;var bool slices=false;var bool records=false;var usize pc=0;
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    discard budget::charge(fuel,p.count,0)?;
    while(pc<p.count){
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        if(proof::operation(p.code[pc*8])){
        let usize mode=kind(p,pc)?;let usize id=p.code[pc*8+if(p.code[pc*8]==84){2}else{1}] as usize;
        if(mode==1){slices=true;}if(mode==2){records=true;}if(width<=id){width=id+1;}
    }pc+=1;}
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    let usize price=if(records){meter::record_place_prepare(width)}else if(slices){meter::slice_place_prepare(width)}else{meter::place_prepare(width)};
    return .ok(Requirement{.width=width,.slices=slices,.records=records,.cost=price});
}
pub fn Result<vec::Vec<usize>,errors::Error> prepare(ref Requirement plan){
    if(plan.width>16 || (plan.width==0 && (plan.slices || plan.records)) ||
        plan.cost!=if(plan.records){meter::record_place_prepare(plan.width)}else if(plan.slices){meter::slice_place_prepare(plan.width)}else{meter::place_prepare(plan.width)}){
        return .err(errors::make(5,0));
    }
    if(!plan.records){return frames::prepare_format(plan.width,plan.slices);}
    var vec::Vec<usize> state=vec::empty<usize>();let usize count=2+32*(14*plan.width+1);
    let usize reserved=switch(vec::reserve<usize>(ref mut state,count)){
        case .ok(n):{n}case .err(_):{return .err(errors::make(15,0));}
    };
    var usize i=0;while(i<count){let usize pushed=switch(vec::push<usize>(ref mut state,0)){
        case .ok(n):{n}case .err(_):{return .err(errors::make(15,0));}
    };i+=1;}
    let ref mut usize[] words=vec::view_mut_usize(ref mut state);words[0]=18432+plan.width;words[1]=2;
    return .ok(state);
}
// Explicit metered setup for callers: insufficient Fuel precedes allocation.
// Publication happens by returning the Vec; caller debits plan.cost on success.
pub fn Result<vec::Vec<usize>,errors::Error> prepare_metered(ref Requirement plan,usize fuel){
    if(fuel<plan.cost){return .err(errors::make(8,0));}return prepare(plan);
}
pub fn Result<usize,errors::Error> cost(ref ir::Program p,ref records::Prepared shapes,
    usize pc,usize function,ref vec::Vec<usize> state){
    let usize mode=kind(p,pc)?;let frames::Format shape=frames::format(state,p.offsets[pc])?;
    if(mode!=2){return .ok(mixed::cost(p,pc,shape.row>=14)?+if(p.code[pc*8]==86 && shape.row==18){4}else{0});}
    if(shape.prefix<2){return .err(errors::make(5,pc));}
    let usize at=pc*8;let usize site=p.code[at+if(p.code[at]==84){3}else{2}] as usize;
    let u8 element=typing::element(p,shapes,site,p.code[at+5] as usize,function,pc)?;
    return .ok(meter::record_place_instruction(p.code[at],codec::width(element)));
}
// The coordinator supplies the current canonical record token for SELECT only.
// READ/STORE use the captured original token and nominal reservation; later
// descriptor changes cannot redirect the selected target. No token-table copy.
pub fn Result<usize,errors::Error> step(ref ir::Program p,ref records::Prepared shapes,
    usize pc,usize function,usize frame,ref mut vec::Vec<usize> state,
    ref owners::Table table,owners::Token current,ref mut u8[] data,ref mut i64[] registers,usize fuel){
    let usize mode=kind(p,pc)?;let usize at=pc*8;let u8 op=p.code[at];
    if(mode!=2 && op!=86){return .err(errors::make(5,pc));}
    let usize price=cost(p,shapes,pc,function,state)?;
    let u8 element=if(op==86){0}else{typing::element(p,shapes,p.code[at+if(op==84){3}else{2}] as usize,p.code[at+5] as usize,function,pc)?};
    return apply(p,pc,function,frame,state,table,current,data,registers,fuel,price,element);
}
// Complete immutable Program admission already proved ordinal/type identity.
// Use its exact scalar register type for codec pricing; SELECT has no payload
// term and discovers its tag only AFTER prepayment through native selection.
fn Result<u8,errors::Error> executable_element(ref ir::Program p,usize pc,usize function){
    let usize mode=kind(p,pc)?;let usize at=pc*8;let u8 op=p.code[at];
    if(op==86){return .ok(0);}if(mode!=2){return .err(errors::make(5,pc));}
    let usize site=p.code[at+if(op==84){3}else{2}] as usize;
    if(function>=16 || function>=p.function_count || site>=16 || site>=p.records.count ||
        p.record_functions[site] as usize!=function || !p.records.mutable[site]){return .err(errors::make(5,pc));}
    if(op==83){return .ok(0);}let usize r=p.code[at+if(op==84){1}else{3}] as usize;
    if(r>=128 || r>=p.registers || codec::width(p.types[r])==0){return .err(errors::make(5,pc));}
    return .ok(p.types[r]);
}
pub fn Result<usize,errors::Error> price(ref ir::Program p,usize pc,usize function,ref vec::Vec<usize> state){
    let u8 element=executable_element(p,pc,function)?;let frames::Format shape=frames::format(state,p.offsets[pc])?;
    if(shape.prefix<2){return .err(errors::make(5,pc));}
    return .ok(meter::record_place_instruction(p.code[pc*8],codec::width(element))+if(p.code[pc*8]==86 && shape.row==18){4}else{0});
}
// Coordinator-only executable adapter. Resolve current SELECT tokens from its
// canonical frame/site map after this same price preflight, never a saved row.
pub fn Result<usize,errors::Error> bound(ref ir::Program p,usize pc,usize function,usize frame,
    ref mut vec::Vec<usize> state,ref owners::Table table,owners::Token current,
    ref mut u8[] data,ref mut i64[] registers,usize fuel){
    let usize work=price(p,pc,function,state)?;let u8 element=executable_element(p,pc,function)?;
    return apply(p,pc,function,frame,state,table,current,data,registers,fuel,work,element);
}
fn Result<usize,errors::Error> apply(ref ir::Program p,usize pc,usize function,usize frame,
    ref mut vec::Vec<usize> state,ref owners::Table table,owners::Token current,
    ref mut u8[] data,ref mut i64[] registers,usize fuel,usize price,u8 element){
    let usize at=pc*8;let u8 op=p.code[at];let usize offset=p.offsets[pc];
    if(fuel<price){return .err(errors::make(8,offset));}
    let frames::Format shape=frames::format(state,offset)?;
    let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    let usize id=if(op==84){a}else{dst};
    if(shape.prefix<2 || frame>=32 || id>=shape.width || function>=p.function_count || function>=16 ||
        pc<p.starts[function] || pc>=p.ends[function]){return .err(errors::make(5,offset));}
    let usize header=shape.prefix+frame*(shape.row*shape.width+1);let usize base=header+1+shape.row*id;let usize tail=base+shape.row-1;
    let ref mut usize[] words=vec::view_mut_usize(state);
    let usize active=words[header];let usize packed=words[tail];let usize phase=(packed>>8)&3;
    if(active>shape.width || packed>3071){return .err(errors::make(5,offset));}
    var usize extra=if(op==86){13}else{10};
    while(extra<shape.row-1){if(words[base+extra]!=0){return .err(errors::make(5,offset));}extra+=1;}
    if(op==86){
        if(active==0 || phase==0){return .err(errors::make(5,offset));}
        var usize i=0;while(i<shape.row){words[base+i]=0;i+=1;}words[header]=active-1;
        return .ok(fuel-price);
    }
    let usize site=if(op==84){b}else{a};let usize ordinal=p.code[at+5] as usize;
    if(op==83){
        if(phase!=0 || packed!=0 || active>=shape.width){return .err(errors::make(5,offset));}
        var usize i=0;while(i<shape.row-1){if(words[base+i]!=0){return .err(errors::make(5,offset));}i+=1;}
        let places::Place selected=switch(places::select(ref p.records.layouts,table,current,ordinal,data.len)){
            case .ok(v):{v}case .err(e):{return .err(failures::failure(e,offset));}
        };
        if(selected.record!=p.records.records[site] as usize || (element!=0 && selected.element!=element)){return .err(errors::make(5,offset));}
        words[base]=selected.root.slot;words[base+1]=selected.root.generation;words[base+2]=selected.record;
        words[base+3]=selected.length;words[base+4]=selected.alignment;words[base+5]=selected.mark;
        words[base+6]=selected.base;words[base+7]=selected.end;words[base+8]=selected.ordinal;
        words[base+9]=selected.offset;
        words[tail]=(selected.element as usize)|(site<<4)|256|2048;words[header]=active+1;
    }else{
        if(active==0 || phase==0 || (packed&3072)!=2048 || ((packed>>4)&15)!=site ||
            (packed&15)!=(element as usize) || words[base+2]!=p.records.records[site] as usize ||
            words[base+8]!=ordinal || words[base+10]!=0 || words[base+11]!=0 || words[base+12]!=0){return .err(errors::make(5,offset));}
        let places::Place selected=places::Place{.root=owners::Token{.slot=words[base],.generation=words[base+1]},
            .record=words[base+2],.length=words[base+3],.alignment=words[base+4],.mark=words[base+5],
            .base=words[base+6],.end=words[base+7],.ordinal=words[base+8],.element=element,.offset=words[base+9]};
        if(op==84){
            if(phase!=1 || dst>=registers.len){return .err(errors::make(5,offset));}
            let i64 cell=switch(places::read(ref p.records.layouts,table,ref selected,data)){
                case .ok(v):{v}case .err(e):{return .err(failures::failure(e,offset));}
            };words[tail]=(packed&2303)|512;registers[dst]=cell;
        }else{
            if(phase==3 || b>=registers.len){return .err(errors::make(5,offset));}
            let usize written=switch(places::store(ref p.records.layouts,table,ref selected,registers[b],data)){
                case .ok(v):{v}case .err(e):{return .err(failures::failure(e,offset));}
            };words[tail]=(packed&2303)|768;
        }
    }
    return .ok(fuel-price);
}
