module reference_lifetimes;
import ir as ir;
import static_ir as statics;
import errors as errors;

fn errors::Error invalid(usize pc){return errors::make(5,pc);}
// Call only after complete recipe, scalar/owner/loan and CFG proof. Dependencies
// name owners of THIS frame, never same-numbered owners in an ancestor frame.
// A callee result remaps its proved logical origin through this CALL's actual.
fn Result<usize,errors::Error> actual(ref ir::Program p,ref usize[] roots,usize value,usize pc){
    if(value>=192 && value<208){return .ok(roots[value-192]);}
    if(value<160 || value>=176){return .err(invalid(pc));}
    let usize root=p.slice_roots[value-160] as usize;let usize one=1;
    if(root>16 || root>p.arrays.count){return .err(invalid(pc));}
    return .ok(if(root==0){0}else{one<<(root-1)});
}
pub fn Result<usize[16],errors::Error> prepare(ref ir::Program p,ref statics::Sites sites){
    var usize[16] roots=[0;16];var usize pc=0;
    while(pc<p.count){let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
        let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
        if((op==75 || op==76) && sites.kinds[dst]==3){roots[dst]=roots[a];}
        else if(op==78 && sites.results[a]==3){let usize origin=sites.origins[a] as usize;
            if(origin==0 || origin>9 || (origin!=9 && origin>p.arities[a])){return .err(invalid(pc));}
            if(origin!=9){roots[dst]=actual(p,ref roots,p.call_args[b*8+origin-1] as usize,pc)?;}
        }
        // PARAMs have no local-owner dependency. Recursive invocation locals
        // remain distinct even when they share the same catalog/site index.
        pc+=1;
    }return .ok(roots);
}
fn Result<usize,errors::Error> guard(ref ir::Program p,usize pc,usize protected){
    let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
    let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;let usize one=1;
    if(op==36 || op==37 || op==38 || op==40 || op==81){
        if((protected&(one<<dst))!=0){return .err(invalid(pc));}
    }else if(op==60 || op==61 || (op==54 && ir::exclusive(p,dst))){
        let usize root=p.slice_roots[dst] as usize;
        if(root!=0 && (protected&(one<<(root-1)))!=0){return .err(invalid(pc));}
    }else if(op==9 || op==64 || op==66 || op==78){var usize i=0;
        while(i<p.arities[a]){let usize formal=p.slice_parameters[p.register_starts[a]+i] as usize;
            if(formal!=0 && ir::exclusive(p,formal-1)){let usize source=p.call_args[b*8+i] as usize;
                if(source<160 || source>=176){return .err(invalid(pc));}
                let usize root=p.slice_roots[source-160] as usize;
                if(root!=0 && (protected&(one<<(root-1)))!=0){return .err(invalid(pc));}
            }i+=1;
        }
    }return .ok(protected);
}
fn Result<usize,errors::Error> merge(ref mut bool[] seen,ref mut usize[] states,usize target,usize bits,usize pc){
    if(seen[target] && states[target]!=bits){return .err(invalid(pc));}
    seen[target]=true;states[target]=bits;return .ok(target);
}
// A separate view-live plane keeps all aliases protected until their last
// logical close. Closing an ordinary source loan does not end a returned view.
pub fn Result<usize,errors::Error> inspect(ref ir::Program p,ref statics::Sites sites,ref usize[] roots){
    if(roots.len!=16){return .err(invalid(0));}let usize one=1;var usize f=0;
    while(f<p.function_count){var bool[256] seen=[false;256];var usize[256] states=[0;256];seen[p.starts[f]]=true;
        var usize pc=p.starts[f];while(pc<p.ends[f]){
            if(!seen[pc]){return .err(invalid(pc));}var usize bits=states[pc];var usize protected=0;var usize site=0;
            while(site<16){if((bits&(one<<site))!=0){protected|=roots[site];}site+=1;}
            let usize checked=guard(p,pc,protected)?;let usize at=pc*8;let u8 op=p.code[at];
            let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
            if((op>=74 && op<=77) || op==69 || (op==78 && sites.results[a]!=0)){bits|=one<<dst;}
            else if(op==70){bits^=one<<dst;}
            if(op==8 || op==39 || op==50 || op==65 || op==79 || op==25){pc+=1;continue;}
            if(op==22){if(!seen[a] || states[a]!=bits){return .err(invalid(pc));}pc+=1;continue;}
            if(op==19 || op==20 || op==21 || op==24){
                let usize target=if(op==19){a}else if(op==24){p.code[at+4] as usize}else{b};
                let usize linked=merge(ref mut seen,ref mut states,target,bits,pc)?;
                if(op==19){pc+=1;continue;}
            }
            if(pc+1>=p.ends[f]){return .err(invalid(pc));}
            let usize linked=merge(ref mut seen,ref mut states,pc+1,bits,pc)?;pc+=1;
        }f+=1;
    }return .ok(p.count);
}
