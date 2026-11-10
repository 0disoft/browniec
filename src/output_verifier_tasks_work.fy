module output_verifier_tasks_work;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
import register_set as registers;
import struct_meta as records;
import struct_layout as layouts;
import static_ir as statics;
import output_call_arguments_work as arguments;
import output_record_copy_work as copies;
import output_record_range_work as ranges;
import output_list_operands_work as lists;
import aggregate_place_ir as aggregates;
import copy_ir as copying;
import slice_verifier as loans;
import array_parameters as parameters;

// Private analysis task requested by the canonical CFG heart. All inputs and
// independently prepared catalogs remain fixed until the task succeeds/fails.
// No scan is replayed in exchange for saved allowance. Span chunks contain at
// most sixteen scalar rows; nominal walks and lists use their own bounded work.
pub struct Request { usize function; usize pc; usize live; registers::Set defined; u8 kind; }
pub struct State {
    Request request; arguments::State args; copies::State copy; ranges::State range; lists::State list;
    usize root; usize nominal; usize leaf; usize first; usize count; usize index; usize output;
    u8 phase; bool active; bool done;
}
pub fn State empty(){return State{.request=Request{.function=0,.pc=0,.live=0,.defined=registers::empty(),.kind=0},
    .args=arguments::empty(),.copy=copies::empty(),.range=ranges::empty(),.list=lists::empty(0,0),
    .root=0,.nominal=0,.leaf=0,.first=0,.count=0,.index=0,.output=0,.phase=0,.active=false,.done=false};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
pub fn Result<usize,errors::Error> begin(ref mut State w,Request request){
    if(w.active || request.kind==0 || request.kind>6){return .err(invalid(request.pc));}
    w.request=request;w.phase=0;w.root=0;w.nominal=0;w.leaf=0;w.first=0;w.count=0;w.index=0;
    w.output=request.live;w.active=true;w.done=false;return .ok(0);
}
fn bool value(ref ir::Program p,usize r,usize f,u8 tag){return r>=p.register_starts[f] && r<p.register_ends[f] && r<128 &&
    !p.slots[r] && p.array_parameters[r]==0 && p.record_parameters[r]==0 && p.slice_parameters[r]==0 && p.types[r]==tag;}
fn Result<usize,errors::Error> copy_begin(ref mut State w,usize root,usize source,usize nominal,usize to,usize from,bool fresh,bool subtree){
    let Request r=w.request;
    let copies::Arguments args=copies::Arguments{.destination=root,.source=source,.destination_function=r.function,
        .source_function=r.function,.fresh=fresh,.same_frame=true,.subtree=subtree,.nominal=nominal,
        .destination_leaf=to,.source_leaf=from,.pc=r.pc};
    return copies::begin(ref mut w.copy,args);
}
fn Result<usize,errors::Error> list_begin(ref ir::Program p,ref mut State w){
    let Request r=w.request;let usize id=p.code[r.pc*8+1] as usize;let usize one=1;
    let u8 op=p.code[r.pc*8];
    if(id>=p.arrays.count || p.array_functions[id] as usize!=r.function || loans::exclusive(p,id,r.live) ||
        (op==81 && loans::borrowed(p,id,r.live))){return .err(invalid(r.pc));}
    let usize mask=one<<id;
    if(op==80){if((r.live&mask)!=0 || (parameters::initial(p,r.function)&mask)!=0){return .err(invalid(r.pc));}w.output=r.live|mask;}
    else if(op!=81 || (r.live&mask)==0 || !p.arrays.mutable[id]){return .err(invalid(r.pc));}
    w.list=lists::empty(r.pc,r.function);w.phase=2;return .ok(0);
}
fn Result<usize,errors::Error> span_begin(ref ir::Program p,ref records::Prepared shapes,ref mut State w){
    let Request r=w.request;
    if(w.leaf>shapes.leaves[w.root] || w.count>shapes.leaves[w.root]-w.leaf ||
        w.first>p.register_ends[r.function] || w.count>p.register_ends[r.function]-w.first){return .err(invalid(r.pc));}
    w.index=0;return .ok(0);
}
fn Result<usize,errors::Error> span(ref ir::Program p,ref records::Prepared shapes,ref mut State w,bool definitions){
    let Request r=w.request;var usize stop=w.index+16;if(stop>w.count){stop=w.count;}
    while(w.index<stop){let usize scalar=w.first+w.index;
        if(!value(p,scalar,r.function,shapes.tags[w.root*128+w.leaf+w.index]) ||
            (definitions && !registers::contains(ref r.defined,scalar))){return .err(invalid(r.pc));}
        w.index+=1;
    }return .ok(0);
}
fn Result<usize,errors::Error> aggregate_header(ref ir::Program p,ref mut State w){
    let Request r=w.request;let usize pc=r.pc;let usize f=r.function;let usize at=pc*8;
    if(p.count>256 || pc>=p.count || p.function_count>16 || f>=p.function_count || pc<p.starts[f] ||
        pc>=p.ends[f] || p.ends[f]>p.count || p.register_ends[f]>128 || !aggregates::reserved(p,pc)){return .err(invalid(pc));}
    let u8 op=p.code[at];let usize root=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    if(p.code[at+1]>=16 || (op!=83 && op!=85 && op!=87)){return .err(invalid(pc));}
    w.root=root;
    if(p.code[at+4]==3){
        let copying::Plan selected=copying::array_assignment(p,root,root,f,pc)?;
        if(op==83){if(b!=0 || pc+1>=p.ends[f]){return .err(invalid(pc));}}
        if(op==85){let copying::Plan source=copying::array_assignment(p,root,b,f,pc)?;}
        if(op==87 && p.code[at+5]==0 && !value(p,b,f,p.arrays.elements[root])){return .err(invalid(pc));}
        if(op==87 && p.code[at+5]==1){
            w.list=lists::empty(pc,f);w.phase=13;return .ok(0);
        }
        w.phase=11;return .ok(0);
    }
    if(p.code[at+4]!=4){return .err(invalid(pc));}
    let usize nominal=if(op==83){b}else{p.code[at+6] as usize};let usize leaf=p.code[at+5] as usize;
    w.nominal=nominal;w.leaf=leaf;w.first=b;
    let usize started=copy_begin(w,root,root,nominal,leaf,leaf,false,true)?;w.phase=7;return .ok(0);
}
fn Result<usize,errors::Error> aggregate_live(ref ir::Program p,ref mut State w){
    let Request r=w.request;let usize at=r.pc*8;let bool record=p.code[at+4]==4;let usize one=1;
    let usize bit=one<<(w.root+if(record){16}else{0});
    if((r.live&bit)==0 || (!record && (loans::borrowed(p,w.root,r.live) || loans::exclusive(p,w.root,r.live)))){return .err(invalid(r.pc));}
    if(p.code[at]==85){let usize source=p.code[at+3] as usize;let usize source_bit=one<<(source+if(record){16}else{0});
        if((r.live&source_bit)==0 || (!record && loans::exclusive(p,source,r.live))){return .err(invalid(r.pc));}
    }else if(p.code[at]==87){
        if(!record && p.code[at+5]==1){w.list=lists::empty(r.pc,r.function);w.phase=14;return .ok(0);}
        if(record){w.index=0;w.phase=12;return .ok(0);}
        if(!registers::contains(ref r.defined,p.code[at+3] as usize)){return .err(invalid(r.pc));}
    }
    w.active=false;w.done=true;return .ok(0);
}
pub fn Result<bool,errors::Error> advance(ref ir::Program p,ref records::Prepared shapes,ref layouts::Plan plan,
    ref statics::Sites sites,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(!w.active){return .err(invalid(w.request.pc));}
    let Request r=w.request;let usize at=r.pc*8;let u8 op=p.code[at];
    if(w.phase==1){
        let bool done=arguments::advance(p,plan,sites,ref r.defined,ref mut w.args,meter)?;
        if(done){w.active=false;w.done=true;}return .ok(w.done);
    }
    if(w.phase==2 || w.phase==13 || w.phase==14){
        let registers::Set full=registers::Set{.low=18446744073709551615,.high=18446744073709551615};
        let registers::Set defined=if(w.phase==13){full}else{r.defined};
        let bool done=lists::advance(p,ref defined,ref mut w.list,meter)?;
        if(done){if(w.phase==13){w.phase=11;}else{w.active=false;w.done=true;}}return .ok(w.done);
    }
    if(w.phase==3 || w.phase==7 || w.phase==8){
        let bool done=copies::advance(p,plan,ref mut w.copy,meter)?;
        if(!done){return .ok(false);}
        if(w.phase==3){let copying::Plan copy=copies::prepared(ref w.copy)?;let usize one=1;
            let usize destination=one<<(16+copy.destination);let usize source=one<<(16+copy.source);
            var bool formal=false;var usize i=0;while(i<p.arities[r.function]){
                if(p.record_parameters[p.register_starts[r.function]+i] as usize==copy.destination+1){formal=true;}i+=1;
            }
            if((r.live&source)==0 || if(copy.fresh){(r.live&destination)!=0 || formal}else{(r.live&destination)==0}){return .err(invalid(r.pc));}
            w.output=if(copy.fresh){r.live|destination}else{r.live};w.active=false;w.done=true;return .ok(true);
        }
        if(w.phase==8){w.phase=11;return .ok(false);}
        if(op==83){if(p.code[at+6]!=0 || p.code[at+7]!=0 || r.pc+1>=p.ends[r.function]){return .err(invalid(r.pc));}w.phase=11;}
        else if(op==85){
            let usize root=w.root;let usize nominal=w.nominal;let usize leaf=w.leaf;
            let usize started=copy_begin(w,root,p.code[at+3] as usize,nominal,leaf,p.code[at+7] as usize,false,true)?;w.phase=8;
        }else{
            if(p.code[at+7]!=0){return .err(invalid(r.pc));}
            let usize nominal=w.nominal;let usize started=ranges::begin_leaves(ref mut w.range,nominal)?;w.phase=9;
        }return .ok(false);
    }
    if(w.phase==4 || w.phase==5 || w.phase==9){
        let bool done=ranges::advance(ref mut w.range,ref p.records.layouts,plan,meter)?;
        if(!done){return .ok(false);}
        if(w.phase==4){let usize nominal=w.nominal;let usize started=ranges::begin_leaves(ref mut w.range,nominal)?;w.phase=5;return .ok(false);}
        let usize count=w.range.output;w.count=count;let usize checked=span_begin(p,shapes,w)?;
        w.phase=if(w.phase==9){10}else{6};return .ok(false);
    }
    if(!budget::admit(meter,4096,r.pc)?){return .ok(false);}
    if(w.phase==0){
        if(r.kind==1 || r.kind==2){let usize started=arguments::begin(ref mut w.args,p.code[at+2] as usize,p.code[at+3] as usize,
            r.function,r.live,r.pc,r.kind==2)?;w.phase=1;}
        else if(r.kind==3){let usize checked=list_begin(p,w)?;}
        else if(r.kind==4){let usize started=copy_begin(w,p.code[at+1] as usize,p.code[at+2] as usize,p.code[at+3] as usize,
            p.code[at+4] as usize,p.code[at+5] as usize,op==42,op==47)?;w.phase=3;}
        else if(r.kind==5){
            let usize root=p.code[at+1] as usize;let usize one=1;
            if(root>=p.records.count || p.record_functions[root] as usize!=r.function || (r.live&(one<<(16+root)))==0 || !p.records.mutable[root]){return .err(invalid(r.pc));}
            let usize nominal=p.code[at+3] as usize;let usize leaf=p.code[at+4] as usize;
            w.root=root;w.nominal=nominal;w.leaf=leaf;w.first=p.code[at+2] as usize;
            let usize started=ranges::begin_offset(ref mut w.range,p.records.records[root] as usize,nominal,leaf)?;w.phase=4;
        }else{let usize checked=aggregate_header(p,w)?;}
    }else if(w.phase==6 || w.phase==10 || w.phase==12){
        let bool definitions=w.phase!=10;let usize checked=span(p,shapes,w,definitions)?;
        if(w.index==w.count){if(w.phase==10){w.phase=11;}else{w.active=false;w.done=true;}}
    }else if(w.phase==11){let usize checked=aggregate_live(p,w)?;}
    else{return .err(invalid(r.pc));}
    return .ok(w.done);
}
