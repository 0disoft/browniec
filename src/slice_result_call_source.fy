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

fn Result<u8,errors::Error> byte(usize value,usize at){
    let i64 wide=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{return .err(errors::make(4,at));}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(4,at))}};
}
fn usize captured(ref locals::Table names,usize first,usize value){var usize i=first;while(i<names.count){if(names.registers[i]==value){return i;}i+=1;}return 64;}
// Names remain unpublished during argument evaluation. Keep exactly the selected
// anonymous view and its temporary owner, or end an anonymous exclusive child
// and bind the returned view under its surviving parent. Hints only guide this
// construction: independent recipe/definition/CFG proof remains mandatory.
pub fn Result<usize,errors::Error> finish(ref mut ir::Program p,ref locals::Table names,
    ref locals::Table captures,ref functions::Table signatures,usize target,ref usize[] args,usize zero,usize at){
    let usize chosen=signatures.return_slice_inputs[target] as usize;
    if(chosen==0 || chosen>args.len || signatures.return_slice_elements[target]==0 || p.return_types[target]!=12){return .err(errors::make(3,at));}
    let usize value=args[chosen-1];if(value<160 || value>=176){return .err(errors::make(3,at));}
    let usize source=value-160;var usize parent=source;let usize first=names.count;
    let bool temporary=captured(captures,first,value)!=64;
    let usize made=calls::creator(p,source);let bool ended=temporary && made!=256;
    if(ended){parent=p.code[made*8+2] as usize;}
    let usize retained=if(temporary && !ended){value}else{176};
    let usize root=p.slice_roots[source] as usize;let usize owner=if(retained!=176 && root!=0){127+root}else{176};
    let usize parent_root=p.slice_roots[parent] as usize;
    let usize site=if(ir::exclusive(p,parent)){reborrow::derived(p,parent,at)?}
        else if(p.slice_origins[parent]!=0){builders::derived(p,parent,names.function,at)?}
        else{ir::slice(p,parent_root-1,at)?};
    let usize call=p.count;let usize opaque=ir::call(p,target,args,at)?;
    p.code[call*8]=66;p.code[call*8+5]=byte(site,at)?;p.code[call*8+6]=byte(parent,at)?;
    var usize mask=0;var usize i=captures.count;let usize one=1;
    while(i>first){i-=1;let usize item=captures.registers[i];
        if(item!=retained && item!=owner){
            let usize end=p.count;let usize released=arrays::release_at(captures,p,i,at)?;
            if(released!=0 && p.code[end*8]==62){
                var usize arg=0;var bool matched=false;
                while(arg<args.len){if(args[arg]==item){mask|=one<<arg;matched=true;}arg+=1;}
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
pub fn Result<usize,errors::Error> publish(ref ir::Program p,ref mut locals::Table names,usize value,usize at){
    if(p.count==0 || p.code[(p.count-1)*8]!=67 || value!=160+p.code[(p.count-1)*8+1] as usize){return .err(errors::make(3,at));}
    let usize parent=p.code[(p.count-1)*8+2] as usize;
    if(captured(names,0,160+parent)!=64){return .ok(0);}
    let usize root=p.slice_roots[parent] as usize;
    if(root!=0 && captured(names,0,127+root)==64){let usize owner=locals::declare(names,at,at,127+root,p.arrays.mutable[root-1])?;}
    let usize view=locals::declare(names,at,at,160+parent,ir::exclusive(p,parent))?;
    return .ok(view);
}
