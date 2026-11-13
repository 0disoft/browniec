module slice_result_call_source;
import ir as ir;
import functions as functions;
import locals as locals;
import errors as errors;
import array_source as arrays;
import slice_builders as builders;
import slice_reborrow_ir as reborrow;
import slice_result_call_ir as calls;
import std::num as num;
import slice_result_dependency_work as work;
import metadata_budget as budget;

fn Result<u8,errors::Error> byte(usize value,usize at){
    let i64 wide=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{return .err(errors::make(4,at));}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(4,at))}};
}
fn usize captured(ref locals::Table names,usize first,usize value){var usize i=first;while(i<names.count){if(names.registers[i]==value){return i;}i+=1;}return 64;}
// Shared SUBSLICE dependencies also need lexical retention. This is construction
// metadata only; independent definition/CFG proof authenticates the final IR.
fn usize ancestor(ref ir::Program p,usize site){
    var usize pc=0;while(pc<p.count && pc<256){let u8 op=p.code[pc*8];
        if((op==59 || op==61 || op==67) && p.code[pc*8+1] as usize==site){return p.code[pc*8+2] as usize;}pc+=1;
    }return 16;
}
fn bool contains(ref ir::Program p,usize value,usize item){
    if(value<160 || value>=176){return false;}var usize site=value-160;var usize steps=0;
    while(site<16 && steps<16){if(item==160+site){return true;}site=ancestor(p,site);steps+=1;}return false;
}
// Keep the selected dependency suffix, including every shared returned parent
// and its hidden owned backing. Exclusive anonymous children collapse to anchor.
fn Result<usize,errors::Error> retain(ref ir::Program p,ref locals::Table captures,
    usize first,usize site,ref mut bool[] keep,usize at){
    var usize parent=site;var usize steps=0;
    while(parent<16){
        let usize i=captured(captures,first,160+parent);if(i==64){return .ok(steps);}
        if(steps>=16){return .err(errors::make(4,at));}steps+=1;keep[i]=true;
        let usize root=p.slice_roots[parent] as usize;
        if(root!=0){let usize owner=captured(captures,first,127+root);if(owner!=64){keep[owner]=true;}}
        parent=ancestor(p,parent);
    }return .ok(steps);
}
// Names remain unpublished during argument evaluation. Keep exactly the selected
// anonymous view and its temporary owner, or end an anonymous exclusive child
// and bind the returned view under its surviving parent. Hints only guide this
// construction: independent recipe/definition/CFG proof remains mandatory.
pub fn Result<usize,errors::Error> finish_raw(ref mut ir::Program p,ref locals::Table names,
    ref locals::Table captures,ref functions::Table signatures,usize target,ref usize[] args,usize zero,usize at){
    let usize chosen=signatures.return_slice_inputs[target] as usize;
    if(chosen==0 || chosen>args.len || signatures.return_slice_elements[target]==0 || p.return_types[target]!=12){return .err(errors::make(3,at));}
    let usize value=args[chosen-1];if(value<160 || value>=176){return .err(errors::make(3,at));}
    let usize source=value-160;var usize parent=source;let usize first=names.count;
    var usize steps=0;
    while(captured(captures,first,160+parent)!=64 && ir::exclusive(p,parent)){
        let usize made=calls::creator(p,parent);if(made==256){break;}
        if(steps>=16){return .err(errors::make(4,at));}steps+=1;parent=p.code[made*8+2] as usize;
        if(parent>=16){return .err(errors::make(3,at));}
    }
    var bool[64] keep=[false;64];let usize retained=retain(p,captures,first,parent,ref mut keep,at)?;
    let usize parent_root=p.slice_roots[parent] as usize;
    let usize site=if(ir::exclusive(p,parent)){reborrow::derived(p,parent,at)?}
        else if(p.slice_origins[parent]!=0){builders::derived(p,parent,names.function,at)?}
        else{ir::slice(p,parent_root-1,at)?};
    let usize call=p.count;let usize opaque=ir::call(p,target,args,at)?;
    p.code[call*8]=66;p.code[call*8+5]=byte(site,at)?;p.code[call*8+6]=byte(parent,at)?;
    var usize mask=0;var usize i=captures.count;let usize one=1;
    while(i>first){i-=1;let usize item=captures.registers[i];
        if(!keep[i]){
            let usize end=p.count;let usize released=arrays::release_at(captures,p,i,at)?;
            if(released!=0 && p.code[end*8]==62){
                var usize arg=0;var bool matched=false;
                while(arg<args.len){if(contains(p,args[arg],item)){mask|=one<<arg;matched=true;}arg+=1;}
                if(!matched){return .err(errors::make(3,at));}p.code[end*8]=68;
            }
        }
    }
    p.code[call*8+4]=byte(mask,at)?;
    let usize bound=ir::raw(p,67,site,parent,zero,at)?;p.code[bound*8+4]=byte(zero,at)?;
    return .ok(160+site);
}

// Called only after CALL/cleanup/finalizer and the complete initializer finish.
// Recover the retained anonymous parent/owner from the finalizer, keeping every
// recursive scalar CALL's lexical table shared and its stack frame unchanged.
pub fn Result<usize,errors::Error> publish_raw(ref ir::Program p,ref mut locals::Table names,usize value,usize at){
    if(p.count==0 || p.code[(p.count-1)*8]!=67 || value!=160+p.code[(p.count-1)*8+1] as usize){return .err(errors::make(3,at));}
    var usize parent=p.code[(p.count-1)*8+2] as usize;var usize[16] chain=[16;16];var usize count=0;
    while(parent<16 && captured(names,0,160+parent)==64){
        if(count>=16){return .err(errors::make(4,at));}chain[count]=parent;count+=1;parent=ancestor(p,parent);
    }
    let usize total=count;
    while(count>0){count-=1;let usize site=chain[count];let usize root=p.slice_roots[site] as usize;
        if(root!=0 && captured(names,0,127+root)==64){let usize owner=locals::declare(names,at,at,127+root,p.arrays.mutable[root-1])?;}
        let usize view=locals::declare(names,at,at,160+site,ir::exclusive(p,site))?;
    }return .ok(total);
}

// The adapter drains private work synchronously. The requested builder and
// release operations retain their original checks and mutation order.
pub fn Result<usize,errors::Error> finish(ref mut ir::Program p,ref locals::Table names,
    ref locals::Table captures,ref functions::Table signatures,usize target,ref usize[] args,usize zero,usize at){
    var work::State w=work::finish_begin(names.count,captures.count,target,zero,at);
    var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,at)?;
        let bool done=work::finish_advance(p,names,captures,signatures,args,ref mut w,ref mut meter)?;
        if(w.request==1){let usize root=p.slice_roots[w.parent] as usize;
            let usize site=if(ir::exclusive(p,w.parent)){reborrow::derived(p,w.parent,at)?}
                else if(p.slice_origins[w.parent]!=0){builders::derived(p,w.parent,names.function,at)?}
                else{ir::slice(p,root-1,at)?};let usize resumed=work::resume(ref mut w,site)?;}
        else if(w.request==2){let usize pc=p.count;let usize value=ir::call(p,target,args,at)?;
            let usize resumed=work::resume(ref mut w,pc)?;}
        else if(w.request==3){let usize released=arrays::release_at(captures,p,w.index,at)?;
            let usize resumed=work::resume(ref mut w,released)?;}
    }return work::prepared(ref w);
}
pub fn Result<usize,errors::Error> publish(ref ir::Program p,ref mut locals::Table names,usize value,usize at){
    var work::State w=work::publish_begin(value,at);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,at)?;
        let bool done=work::publish_advance(p,names,ref mut w,ref mut meter)?;}
    return work::prepared(ref w);
}
