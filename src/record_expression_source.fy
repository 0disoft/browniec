module record_expression_source;
import lexer as lexer;
import aggregate_probe_work as probes;
import locals as locals;
import functions as functions;
import ir as ir;
import struct_value_source as records;
import errors as errors;

// Advisory only. Zero kind is a scalar/unrecognized expression; 1 constructor,
// 2 named owner, 3 record CALL. No source classification grants IR authority.
pub struct Plan { u8 kind; usize groups; usize record; u8 tag; u8 suffix; }
// id==16 is unpublished scalar constructor staging, never an owner token.
pub struct Staged { usize[16] slots; usize count; }
pub struct Value { usize id; bool owned; usize record; usize ordinal; u8 tag; usize[16] slots; usize depth; }
fn Plan none(){return Plan{.kind=0,.groups=0,.record=0,.tag=0,.suffix=0};}
pub fn Result<Plan,errors::Error> inspect_raw(ref u8[] source,ref lexer::State s,
    ref ir::Program p,ref locals::Table names,ref functions::Table signatures){
    var lexer::State look=lexer::snapshot(s);var usize groups=0;
    while(look.kind==40){if(groups>=32){return .err(errors::make(4,look.begin));}
        let usize next=lexer::next(source,ref mut look)?;groups+=1;}
    if(look.kind!=2 && look.kind!=5){return .ok(none());}
    let lexer::State name=lexer::snapshot(ref look);
    let usize local=locals::find(source,names,look.begin,look.end);
    let usize target=functions::find(source,signatures,look.begin,look.end);
    let usize next=lexer::next(source,ref mut look)?;var usize record=32;var u8 kind=0;
    if(look.kind==123){kind=1;record=records::named(source,ref name,ref signatures.context)?;}
    else if(look.kind==40 && local==64 && target<signatures.count && signatures.return_records[target]!=0){kind=3;record=signatures.return_records[target] as usize-1;}
    else if(records::binding(names,local)){
        let usize id=names.registers[local]-144;
        if(id>=16 || id>=p.records.count || p.record_functions[id] as usize!=names.function){return .err(errors::make(3,s.begin));}
        kind=2;record=p.records.records[id] as usize;
    }else{return .ok(none());}
    if(kind==1 || kind==3){let u8 open=look.kind;let u8 close=if(open==123){125}else{41};
        var usize depth=1;let usize first=lexer::next(source,ref mut look)?;
        while(depth!=0){if(look.kind==0){return .err(errors::make(2,look.begin));}
            if(look.kind==open){depth+=1;}else if(look.kind==close){depth-=1;}
            let usize next=lexer::next(source,ref mut look)?;}
    }
    var usize left=groups;var u8 tag=0;
    while(true){
        if(tag==0 && look.kind==46){let records::Leaf leaf=records::path(source,ref mut look,p,record,s.begin,ref signatures.context)?;
            record=leaf.record;tag=leaf.tag;}
        if(left==0){break;}
        if(look.kind!=41){return .ok(none());}
        let usize close=lexer::next(source,ref mut look)?;left-=1;
    }
    return .ok(Plan{.kind=kind,.groups=groups,.record=record,.tag=tag,.suffix=look.kind});
}
// Keep the plan outside recursive scalar frames. Existing bare-name/CALL field
// syntax retains its original parser; constructors also gain direct projections.
pub fn Result<bool,errors::Error> projected(ref u8[] source,ref lexer::State s,
    ref ir::Program p,ref locals::Table names,ref functions::Table signatures){
    if(s.kind!=40){if(s.kind!=2 && s.kind!=5){return .ok(false);}
        var lexer::State look=lexer::snapshot(s);let usize next=lexer::next(source,ref mut look)?;
        if(look.kind!=123){return .ok(false);}}
    let Plan plan=inspect(source,s,p,names,signatures)?;
    return .ok(plan.kind!=0 && plan.tag!=0);
}
pub fn bool whole(ref ir::Program p,ref Value value){
    return value.id<16 && value.id<p.records.count && value.ordinal==0 && value.tag==0 && p.records.records[value.id] as usize==value.record;
}
pub fn Result<usize,errors::Error> scalar(ref mut ir::Program p,ref Value value,usize at){
    if(value.tag==0){return .err(errors::make(3,at));}
    let usize result=if(value.id==16){ir::emit(p,17,value.slots[value.ordinal],0,at)?}
        else{ir::record_read(p,value.id,value.ordinal,at)?};
    if(value.owned){let usize dropped=ir::record_drop(p,value.id,at)?;}
    return .ok(result);
}
// Materialize only contexts requiring an independent complete record value.
pub fn Result<usize,errors::Error> materialize(ref mut ir::Program p,usize function,ref Value value,bool mutable,usize at){
    if(value.tag!=0){return .err(errors::make(3,at));}
    if(value.id==16){let usize count=records::leaf_count(p,value.record,at)?;let usize first=p.registers;
        var usize i=0;while(i<count){let usize read=ir::emit(p,17,value.slots[value.ordinal+i],0,at)?;i+=1;}
        let usize id=ir::record_in(p,function,value.record,mutable,at)?;
        let usize init=ir::record_init(p,id,first,at)?;return .ok(id);}
    if(whole(p,value)){
        if(value.owned){return .ok(value.id);}
        let usize id=ir::record_in(p,function,value.record,mutable,at)?;
        let usize copied=ir::record_copy(p,id,value.id,at)?;return .ok(id);}
    let records::Leaf leaf=records::Leaf{.ordinal=value.ordinal,.tag=0,.record=value.record};
    return records::extract_part(p,function,value.id,leaf,mutable,at,at,value.owned);
}
pub fn Result<usize,errors::Error> assign(ref mut ir::Program p,usize destination,records::Leaf target,ref Value value,usize at){
    if(destination>=p.records.count || !p.records.mutable[destination] || target.tag!=0 || value.tag!=0 || target.record!=value.record){return .err(errors::make(3,at));}
    let bool root=target.ordinal==0 && p.records.records[destination] as usize==target.record;
    if(value.id==16){let usize count=records::leaf_count(p,value.record,at)?;let usize first=p.registers;
        var usize i=0;while(i<count){let usize loaded=ir::emit(p,17,value.slots[value.ordinal+i],0,at)?;i+=1;}
        return if(root){ir::record_replace(p,destination,first,target.record,at)}else{ir::record_subreplace(p,destination,first,target.record,target.ordinal,at)};
    }
    let usize assigned=if(root && whole(p,value)){ir::record_assign(p,destination,value.id,at)?}
        else{ir::record_subassign(p,destination,value.id,target.record,target.ordinal,value.ordinal,at)?};
    if(value.owned){let usize dropped=ir::record_drop(p,value.id,at)?;}return .ok(assigned);
}
// Unpublished constructor slots can feed a parent directly. They cannot be named
// or changed by a later guest field expression, so no second staging copy exists.
pub fn Result<usize,errors::Error> stage(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut records::Initializer state,ref mut usize[] slots,usize first,ref Value value,usize at){
    if(state.depth==0 || value.tag!=0){return .err(errors::make(3,at));}
    let usize level=state.depth-1;let usize expected=p.records.layouts.types[state.records[level]*16+state.fields[level]] as usize;
    if(value.record!=expected){return .err(errors::make(3,at));}
    if(value.id!=16){let records::Leaf leaf=records::Leaf{.ordinal=value.ordinal,.tag=0,.record=value.record};
        let usize count=records::stage_part(source,s,p,state,slots,first,value.id,leaf,at)?;
        if(value.owned){let usize dropped=ir::record_drop(p,value.id,at)?;}return .ok(count);}
    if(s.kind!=44 && s.kind!=125){return .err(errors::make(2,s.begin));}
    let usize count=records::leaf_count(p,value.record,at)?;
    if(first>slots.len || count>slots.len-first || value.ordinal>16 || count>16-value.ordinal){return .err(errors::make(4,at));}
    var usize i=0;while(i<count){slots[first+i]=value.slots[value.ordinal+i];i+=1;}
    let usize advanced=records::advance(source,s,p,state)?;return .ok(count);
}

pub fn Result<Plan,errors::Error> inspect(ref u8[] source,ref lexer::State s,ref ir::Program p,ref locals::Table names,ref functions::Table signatures){
    let probes::Plan plan=probes::inspect(source,*s,p,names,signatures,1)?;
    return .ok(Plan{.kind=plan.kind,.groups=plan.groups,.record=plan.record,.tag=plan.tag,.suffix=plan.suffix});
}
