module reference_result_source;
import ir as ir;
import functions as functions;
import locals as locals;
import array_source as arrays;
import static_builders as builders;
import reference_call_source as calls;
import errors as errors;
import std::num as num;

fn Result<u8,errors::Error> byte(usize value,usize at){
    let i64 wide=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{return .err(errors::make(4,at));}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(4,at))}};
}
// Compiler construction metadata only: selected local owners, never authority.
// Every claim is reconstructed from the final IR by complete lifetime proof.
pub fn Result<usize,errors::Error> owners(ref ir::Program p,ref functions::Table signatures,usize value,usize depth,usize at){
    if(depth>32){return .err(errors::make(4,at));}
    let usize one=1;
    if(value>=160 && value<176){let usize root=p.slice_roots[value-160] as usize;
        if(root>16){return .err(errors::make(3,at));}return .ok(if(root==0){0}else{one<<(root-1)});}
    if(value<192 || value>=208){return .err(errors::make(3,at));}
    let usize site=value-192;var usize pc=0;
    while(pc<p.count){let usize code=pc*8;let u8 op=p.code[code];let usize a=p.code[code+2] as usize;
        if(p.code[code+1] as usize==site){
            if(op==69 || op==77){return .ok(0);}
            if(op==74 || op==75 || op==76){return owners(p,signatures,192+a,depth+1,at);}
            if(op==78 && calls::result(signatures,a)){
                let usize chosen=signatures.return_slice_inputs[a] as usize;
                if(chosen==9){return .ok(0);}let usize map=p.code[code+3] as usize;
                if(chosen==0 || chosen>p.arities[a] || map>=p.call_count){return .err(errors::make(3,at));}
                return owners(p,signatures,p.call_args[map*8+chosen-1] as usize,depth+1,at);
            }
        }pc+=1;
    }return .err(errors::make(3,at));
}
fn bool present(ref locals::Table names,usize value){var usize i=0;while(i<names.count){if(names.registers[i]==value){return true;}i+=1;}return false;}
// Native handoff issues an independent receipt: source temporary views can close
// immediately. Only a selected owned temporary must survive in caller names.
pub fn Result<usize,errors::Error> release(ref mut ir::Program p,ref locals::Table captures,usize first,usize keep,usize at){
    let usize one=1;var usize i=captures.count;var usize dropped=0;
    while(i>first){i-=1;let usize value=captures.registers[i];
        if(value>=128 && value<144 && (keep&(one<<(value-128)))!=0){}else{dropped+=arrays::release_at(captures,p,i,at)?;}
    }return .ok(dropped);
}
pub fn Result<usize,errors::Error> publish(ref ir::Program p,ref functions::Table signatures,ref mut locals::Table names,usize site,usize at){
    let usize mask=owners(p,signatures,192+site,0,at)?;let usize one=1;var usize root=0;var usize count=0;
    while(root<16){if((mask&(one<<root))!=0 && !present(names,128+root)){
        if(root>=p.arrays.count){return .err(errors::make(3,at));}
        let usize hidden=locals::declare(names,at,at,128+root,p.arrays.mutable[root])?;count+=1;
    }root+=1;}return .ok(count);
}
pub fn Result<usize,errors::Error> call(ref mut ir::Program p,ref functions::Table signatures,
    ref locals::Table names,ref locals::Table captures,usize target,ref usize[] arguments,usize at){
    if(!calls::result(signatures,target) || p.call_count>=32 || arguments.len>8){return .err(errors::make(3,at));}
    let usize site=builders::fresh(p,at)?;let usize map=p.call_count;var usize i=0;
    while(i<arguments.len){p.call_args[map*8+i]=byte(arguments[i],at)?;i+=1;}
    p.call_arities[map]=byte(arguments.len,at)?;p.call_count+=1;
    let usize pc=ir::raw(p,78,site,target,map,at)?;
    let usize keep=owners(p,signatures,192+site,0,at)?;
    let usize dropped=release(p,captures,names.count,keep,at)?;
    return .ok(192+site);
}
