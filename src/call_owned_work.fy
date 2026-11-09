module call_owned_work;
import slice_result_owned_execution as owned;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import slice_result_bindings as held;
import slice_result_record_bindings as records;
import array_owners as owners;
import array_layout as layouts;
import array_meta as array_meta;
import struct_meta as record_meta;
import struct_call_vm as calls;
import call_capture_plan as captures;
import ir as ir;
import metadata_budget as budget;
import errors as errors;

// Invocation-private scratch. The parent pins the exact Program/cache/frame and
// supplied captures. Raw prepare_enter[_cached] remains an independent oracle.
pub struct State { owned::Prepared result; captures::Entry entry;
    usize phase; usize index; bool active; bool done; }
fn owned::Prepared blank(){
    let owners::Token token=owners::Token{.slot=0,.generation=0};
    let layouts::Array shape=layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0};
    let owners::CallArgument argument=owners::CallArgument{.source=token,.element=0,.length=0,.record=0};
    return owned::Prepared{.captures=[runtime::capture(frames::none(),false,false);8],
        .sources=[token;8],.shapes=[shape;8],.arguments=[argument;8],.destinations=[0;8],
        .record_args=[false;8],.count=0,.owned=0,.records=false};
}
pub fn State empty(){return State{.result=blank(),
    .entry=captures::Entry{.ends=[0;8],.parents=[16;8],.required=0,.absent=0},
    .phase=0,.index=0,.active=false,.done=false};}
pub fn Result<usize,errors::Error> begin(ref mut State w){
    if(w.active){return .err(errors::make(5,0));}
    w.phase=0;w.index=0;w.active=true;w.done=false;return .ok(0);
}
fn Result<usize,errors::Error> header(ref mut State w,ref ir::Program p,usize pc,
    runtime::Contract contract,usize fuel,ref runtime::Capture[] supplied,ref captures::Plan plan){
    let usize offset=p.offsets[pc];let usize target=p.code[pc*8+2] as usize;
    let usize price=calls::cost(p,target,offset)?+contract.arity;
    if(fuel<runtime::cost()+price){return .err(errors::make(8,offset));}
    if(supplied.len!=0 && supplied.len!=contract.arity){return .err(errors::make(5,offset));}
    // Owning CALL66 always has the Program's proved immutable cache. Never hide
    // whole-IR recipe discovery in a supposedly bounded preparation stage.
    if(p.code[pc*8]==66){
        if(!plan.ready){return .err(errors::make(5,offset));}
        w.entry=captures::lookup(plan,p,pc)?;
    }
    w.result=blank();w.result.owned=price;w.index=0;
    w.phase=if(contract.arity!=0){1}else if(p.code[pc*8]==66){2}else{3};
    return .ok(0);
}
fn Result<usize,errors::Error> capture_one(ref mut State w,ref ir::Program p,usize pc,
    runtime::Contract contract,ref frames::Frames bindings,ref runtime::Capture[] supplied){
    let usize i=w.index;let usize map=p.code[pc*8+3] as usize;
    let usize source=p.call_args[map*8+i] as usize;
    if(supplied.len!=0){w.result.captures[i]=supplied[i];}
    else if(contract.tags[i]!=0){
        let usize mask=if(p.code[pc*8]==66){p.code[pc*8+4] as usize}else{0};let usize one=1;
        let ref captures::Entry entry=ref w.entry;
        let usize count=if((mask&(one<<i))!=0){entry.ends[i] as usize}else{0};
        if(count>16){return .err(errors::make(5,p.offsets[pc]));}
        w.result.captures[i]=runtime::chain_capture(bindings.sites[bindings.frame*16+source-160],count);
    }
    w.index+=1;if(w.index==contract.arity){w.index=0;w.phase=if(p.code[pc*8]==66){2}else{3};}
    return .ok(0);
}
fn Result<usize,errors::Error> held_one(ref mut State w,usize parent,
    ref frames::Frames bindings,usize offset){
    let usize site=w.index;let usize one=1;let usize bit=one<<site;
    let ref captures::Entry entry=ref w.entry;
    if(((entry.required|entry.absent)&bit)!=0){
        let ref held::State loans=ref bindings.loans;
        let usize found=held::find(loans,parent*16+site);
        if((entry.required&bit)!=0){
            if(found==47){return .err(errors::make(5,offset));}
            let runtime::Held receipt=loans.held[found];
            if(!receipt.exclusive || receipt.close_parent || receipt.drop){return .err(errors::make(5,offset));}
        }
        if((entry.absent&bit)!=0 && found!=47){return .err(errors::make(5,offset));}
    }
    w.index+=1;if(w.index==16){w.index=0;w.phase=3;}return .ok(0);
}
fn Result<usize,errors::Error> descriptor_one(ref mut State w,ref ir::Program p,usize pc,
    runtime::Contract contract,ref frames::Frames bindings){
    if(w.index==contract.arity){w.active=false;w.done=true;w.phase=4;return .ok(0);}
    let usize target=p.code[pc*8+2] as usize;let usize map=p.code[pc*8+3] as usize;
    let usize parent=bindings.frame;let usize i=w.index;let usize formal=p.register_starts[target]+i;
    let usize encoded=p.array_parameters[formal] as usize;let usize offset=p.offsets[pc];
    if(encoded!=0){
        let usize id=encoded-1;let usize destination=(parent+1)*16+id;
        if(bindings.tokens[destination].generation!=0){return .err(errors::make(5,offset));}
        let ref owned::Prepared prepared=ref w.result;let usize count=prepared.count;
        if(count>=8){return .err(errors::make(5,offset));}
        let usize source=p.call_args[map*8+i] as usize-128;
        let owners::Token token=bindings.tokens[parent*16+source];
        let ref array_meta::Catalog arrays=ref p.arrays;
        let layouts::Array shape=switch(layouts::scalar(arrays.elements[id],arrays.lengths[id])){
            case .ok(v):{v}case .err(_):{return .err(errors::make(5,offset));}
        };
        w.result.sources[count]=token;w.result.shapes[count]=shape;
        w.result.arguments[count]=owners::CallArgument{.source=token,.element=shape.element,.length=shape.length,.record=0};
        w.result.destinations[count]=destination;w.result.count+=1;
    }
    let usize r=p.record_parameters[formal] as usize;
    if(r!=0){
        let usize destination=(parent+1)*16+r-1;let ref records::State bound=ref bindings.records;
        if(records::get(bound,destination).generation!=0){return .err(errors::make(5,offset));}
        let ref owned::Prepared prepared=ref w.result;let usize count=prepared.count;
        if(count>=8){return .err(errors::make(5,offset));}
        let usize source=p.call_args[map*8+i] as usize-144;
        let owners::Token token=records::get(bound,parent*16+source);
        let ref record_meta::Catalog catalog=ref p.records;
        w.result.arguments[count]=owners::CallArgument{.source=token,.element=0,.length=0,.record=catalog.records[r-1] as usize};
        w.result.record_args[count]=true;w.result.records=true;
        w.result.destinations[count]=destination;w.result.count+=1;
    }
    w.index+=1;if(w.index==contract.arity){w.active=false;w.done=true;w.phase=4;}return .ok(0);
}
pub fn Result<bool,errors::Error> advance(ref mut State w,ref ir::Program p,usize pc,
    runtime::Contract contract,ref frames::Frames bindings,usize fuel,ref runtime::Capture[] supplied,
    ref captures::Plan plan,ref mut budget::State allowance){
    if(!w.active || w.done || w.phase>3){return .err(errors::make(5,0));}
    if(allowance.last!=0){return .ok(false);}
    if(!budget::admit(allowance,4096,0)?){return .ok(false);}
    if(pc>=p.count || pc>=256 || contract.arity>8 || bindings.frame==0 || bindings.frame>=31 ||
        (w.phase==1 && w.index>=contract.arity) || (w.phase==2 && w.index>=16) ||
        (w.phase==3 && w.index>contract.arity)){w.active=false;return .err(errors::make(5,0));}
    let Result<usize,errors::Error> result=if(w.phase==0){header(w,p,pc,contract,fuel,supplied,plan)}
        else if(w.phase==1){capture_one(w,p,pc,contract,bindings,supplied)}
        else if(w.phase==2){held_one(w,bindings.frame,bindings,p.offsets[pc])}
        else{descriptor_one(w,p,pc,contract,bindings)};
    switch(result){case .ok(_):{}case .err(e):{w.active=false;return .err(e);}};
    return .ok(w.done);
}
