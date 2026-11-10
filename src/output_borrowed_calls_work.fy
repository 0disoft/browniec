module output_borrowed_calls_work;
import ir as ir;
import errors as errors;
import types as types;
import slice_result_call_ir as calls;
import slice_result_verifier as loans;
import output_return_ir as returns;
import slice_result_origins as origins;
import struct_layout as layouts;
import output_record_range_work as ranges;
import array_list_ir as lists;
import metadata_budget as budget;

// Original CALL66 and borrowed terminal proof after the complete normalized
// canonical proof and origin solution. Inputs/Plan are pinned by the owner.
// A stage visits one PC/chain edge, <=64 list cells or <=16 nominal DFS rows.
// Creator/binding/terminal searches are individually bounded by 256 PCs.
pub struct State {
    ranges::State range; loans::Proof result; bool[256] matched;
    usize pc; usize target; usize map; usize end; usize chosen; usize mask;
    usize argument; usize expected; usize parent; usize chain; usize scan;
    usize previous; usize seen; usize read_pc; usize list; usize index; usize count;
    usize first; usize function; u8 phase; bool done;
}
pub fn State empty(){return State{.range=ranges::empty(),
    .result=loans::Proof{.parameters=[0;16],.preparations=0,.forwards=0,.returns=0,.rounds=0},
    .matched=[false;256],.pc=0,.target=0,.map=0,.end=0,.chosen=0,.mask=0,
    .argument=0,.expected=0,.parent=0,.chain=0,.scan=0,.previous=256,.seen=0,
    .read_pc=0,.list=0,.index=0,.count=0,.first=0,.function=0,.phase=0,.done=false};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
fn Result<usize,errors::Error> start_chain(ref ir::Program p,ref mut State w,usize argument,u8 phase){
    if(p.count>256 || w.pc>=p.count || p.code[w.pc*8]!=66 || p.call_count>32 ||
        w.map>=p.call_count || w.map>=32 || argument>=8 || p.call_arities[w.map]>8 ||
        argument>=p.call_arities[w.map] as usize){return .err(invalid(w.pc));}
    let usize value=p.call_args[w.map*8+argument] as usize;
    if(value<160 || value>=176){return .err(invalid(w.pc));}
    w.parent=value-160;w.chain=0;w.scan=w.pc+1;w.phase=phase;return .ok(0);
}
fn Result<usize,errors::Error> chain_step(ref ir::Program p,ref mut State w){
    let usize at=w.scan;
    if(p.code[at*8]==68 && p.code[at*8+1] as usize==w.parent){
        let usize made=calls::creator(p,w.parent);
        if(made>=w.pc || p.code[at*8+2]!=p.code[made*8+2] || w.chain>=16){return .err(invalid(w.pc));}
        let usize parent=p.code[at*8+2] as usize;
        if(parent>=16){return .err(invalid(w.pc));}w.parent=parent;w.chain+=1;
    }w.scan+=1;return .ok(0);
}
fn bool simple_read(ref ir::Program p,usize pc,usize r){
    let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
    let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    if(op==83 || op==85){return (if(op==83){p.code[at+4]<=1}else{p.code[at+4]<=2}) && b==r;}
    if(op==87 && p.code[at+4]==3){return b==r;}
    if((op>=2 && op<=6) || (op>=11 && op<=16) || (op>=28 && op<=32) || op==36 || op==54 || op==60){return a==r || b==r;}
    if(op==7 || op==8 || op==10 || op==17 || op==18 || op==20 || op==21 || op==24 || op==26 || op==27 || op==33 || op==40){return a==r;}
    if(op==71){return b==r;}
    if(op==23){return a==r && b<=1 && types::payload(p.types[dst],p.code[at+3])!=0;}
    if(op==9 || op==78){var usize i=0;while(i<p.call_arities[b] as usize){if(p.call_args[b*8+i] as usize==r){return true;}i+=1;}}
    if(op==35 || op==58 || op==44){return b==r;}
    if(op==53 || op==59 || op==61 || op==76){return b==r || p.code[at+4] as usize==r;}
    return false;
}
fn Result<usize,errors::Error> terminal(ref ir::Program p,usize f,usize pc){
    let u8 identity=p.code[pc*8+1];var usize at=pc+1;
    while(at<p.ends[f]){let u8 op=p.code[at*8];
        if(op==65){if(p.code[at*8+2]!=identity){return .err(invalid(at));}return .ok(at);}
        if(op!=37 && op!=45 && op!=56 && op!=62 && op!=70 && op!=86){return .err(invalid(at));}at+=1;
    }return .err(invalid(pc));
}
pub fn Result<bool,errors::Error> advance(ref ir::Program normalized,ref ir::Program recipes,
    ref returns::Signature signature,ref origins::Summary grounded,ref layouts::Plan plan,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==7){let bool done=ranges::advance(ref mut w.range,ref normalized.records.layouts,plan,meter)?;
        if(done){let usize identity=recipes.code[w.pc*8+1] as usize;
            if(identity>=w.first && identity-w.first<w.range.output){return .err(invalid(w.read_pc));}
            w.read_pc+=1;w.phase=5;}return .ok(false);}
    if(!budget::admit(meter,4096,w.pc)?){return .ok(false);}
    let usize pc=w.pc;let usize at=pc*8;let usize one=1;
    if(w.phase==0){
        if(pc==recipes.count){w.phase=8;return .ok(false);}
        if(recipes.code[at]!=66){w.pc+=1;return .ok(false);}
        let usize target=recipes.code[at+2] as usize;let usize map=recipes.code[at+3] as usize;
        let usize end=calls::binding(recipes,pc)?;let usize site=recipes.code[at+5] as usize;
        let usize chosen=grounded.parameters[target] as usize;let usize mask=recipes.code[at+4] as usize;
        if(signature.elements[target]==0 || chosen==0 || chosen>normalized.arities[target] ||
            ir::slice_element(normalized,site,pc)?!=(signature.elements[target]&127) ||
            ir::exclusive(normalized,site)!=((signature.elements[target]&128)!=0)){return .err(invalid(pc));}
        if(mask>=(one<<normalized.arities[target])){return .err(invalid(pc));}
        w.target=target;w.map=map;w.end=end;w.chosen=chosen;w.mask=mask;w.argument=0;w.expected=0;w.phase=1;
    }else if(w.phase==1){
        let usize arg=w.argument;
        if(arg==normalized.arities[w.target]){let usize chosen=w.chosen-1;
            let usize actual=normalized.call_args[w.map*8+chosen] as usize;
            if(actual<160 || actual>=176){return .err(invalid(pc));}
            let usize begun=start_chain(recipes,w,chosen,3)?;
        }else{let usize source=normalized.call_args[w.map*8+arg] as usize;
            if(source>=160 && source<176){let usize begun=start_chain(recipes,w,arg,2)?;}
            else{if((w.mask&(one<<arg))!=0){return .err(invalid(pc));}w.argument+=1;}
        }
    }else if(w.phase==2 || w.phase==3){
        if(w.scan<w.end){let usize checked=chain_step(recipes,w)?;}
        else if(w.phase==2){if(((w.mask&(one<<w.argument))!=0)!=(w.chain!=0)){return .err(invalid(pc));}
            w.expected+=w.chain;w.argument+=1;w.phase=1;
        }else{if(recipes.code[at+6] as usize!=w.parent){return .err(invalid(pc));}
            w.seen=0;w.previous=256;w.scan=pc+1;w.phase=4;}
    }else if(w.phase==4){
        let usize step=w.scan;
        if(step==w.end){if(w.seen!=w.expected){return .err(invalid(pc));}w.read_pc=0;w.phase=5;}
        else{if(recipes.code[step*8]==68){let usize child=recipes.code[step*8+1] as usize;
            if(child>=16 || !ir::exclusive(normalized,child)){return .err(invalid(step));}
            let usize made=calls::creator(recipes,child);
            if(made>=pc || made>=w.previous){return .err(invalid(step));}w.previous=made;w.seen+=1;
        }w.scan+=1;}
    }else if(w.phase==5){
        let usize step=w.read_pc;
        if(step==normalized.count){w.pc+=1;w.phase=0;return .ok(false);}
        let usize offset=step*8;let u8 op=normalized.code[offset];
        let usize identity=recipes.code[at+1] as usize;
        if(lists::operation(normalized,step)){let usize root=lists::destination(normalized,step);
            w.list=lists::start(normalized,step);w.count=normalized.arrays.lengths[root];w.index=0;w.phase=6;
        }else if((op==87 && normalized.code[offset+4]!=3) || op==41 || op==48 || op==49){
            let usize nominal=if(op==87){normalized.code[offset+6] as usize}else if(op==49){normalized.code[offset+3] as usize}
                else{normalized.records.records[normalized.code[offset+1] as usize] as usize};
            w.first=normalized.code[offset+if(op==87){3}else{2}] as usize;
            let usize begun=ranges::begin_leaves(ref mut w.range,nominal)?;w.phase=7;
        }else{if(simple_read(normalized,step,identity)){return .err(invalid(step));}w.read_pc+=1;}
    }else if(w.phase==6){
        var usize stop=w.index+64;if(stop>w.count){stop=w.count;}
        let u8 identity=recipes.code[at+1];
        while(w.index<stop){if(normalized.list_operands[w.list+w.index]==identity){return .err(invalid(w.read_pc));}w.index+=1;}
        if(w.index==w.count){w.read_pc+=1;w.phase=5;}
    }else if(w.phase==8){
        var usize f=0;while(f<16){if(grounded.parameters[f]!=signature.parameters[f]){return .err(invalid(0));}f+=1;}
        w.result.parameters=grounded.parameters;w.result.rounds=grounded.rounds;w.function=0;w.pc=recipes.starts[0];w.phase=9;
    }else if(w.phase==9){
        let usize f=w.function;
        if(pc==recipes.ends[f]){w.function+=1;if(w.function==recipes.function_count){w.pc=0;w.phase=10;}
            else{w.pc=recipes.starts[w.function];}return .ok(false);}
        let u8 op=recipes.code[at];
        if(op==8 && signature.elements[f]!=0){return .err(invalid(pc));}
        if(op==65){if(signature.elements[f]==0){return .err(invalid(pc));}w.result.returns+=1;}
        if(op==63 || op==64){if(signature.elements[f]==0){return .err(invalid(pc));}
            if(op==64){let usize callee=recipes.code[at+2] as usize;
                if(callee>=recipes.function_count || signature.elements[callee]!=signature.elements[f]){return .err(invalid(pc));}w.result.forwards+=1;}
            let usize end=terminal(recipes,f,pc)?;if(w.matched[end]){return .err(invalid(end));}
            w.matched[end]=true;w.result.preparations+=1;
        }w.pc+=1;
    }else if(w.phase==10){
        if(pc==recipes.count){w.done=true;return .ok(true);}
        if(recipes.code[at]==65 && !w.matched[pc]){return .err(invalid(pc));}w.pc+=1;
    }else{return .err(invalid(pc));}
    return .ok(false);
}
