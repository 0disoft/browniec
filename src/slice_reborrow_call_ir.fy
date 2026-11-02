module slice_reborrow_call_ir;
import ir as ir;
import errors as errors;
import slice_reborrow_ir as forest;
import slice_parameters as parameters;

// Analysis only, after whole-program metadata and forest validation. CALL is
// synchronous: a successful return preserves the caller's entire live word.
// This does not authenticate native receipts, reserve depth, or admit execution.
pub fn Result<usize,errors::Error> inspect(ref ir::Program p,ref forest::Sites sites,
    usize pc,usize caller,usize live){
    if(pc>=p.count || pc>=256 || p.code[pc*8]!=9 || caller>=p.function_count){return .err(errors::make(5,pc));}
    let usize target=p.code[pc*8+2] as usize;let usize args=p.code[pc*8+3] as usize;
    if(target>=p.function_count || args>=p.call_count || args>=32 ||
        p.call_arities[args] as usize!=p.arities[target] || p.arities[target]>8){return .err(errors::make(5,pc));}
    let usize available=(live>>32)&65535;let usize suspended=live>>48;
    let usize pending=available|suspended;let usize one=1;
    if((available&suspended)!=0){return .err(errors::make(5,pc));}
    var usize site=0;
    while(site<16){
        let usize bit=one<<site;
        if((pending&bit)!=0){
            let usize root=p.slice_roots[site] as usize;
            if(root!=0){
                if(root>p.arrays.count || p.array_functions[root-1] as usize!=caller){return .err(errors::make(5,pc));}
            }else if(p.slice_origins[site]==0 || p.slice_functions[site] as usize!=caller+1){return .err(errors::make(5,pc));}
            let usize parent=sites.parents[site];
            if(parent!=16 && (parent>=16 || (suspended&(one<<parent))==0)){return .err(errors::make(5,pc));}
            var usize children=0;var usize child=0;
            while(child<16){if(sites.parents[child]==site && (pending&(one<<child))!=0){children+=1;}child+=1;}
            if(children!=if((suspended&bit)!=0){1}else{0}){return .err(errors::make(5,pc));}
        }
        site+=1;
    }
    var usize writers=0;var usize roots=0;var usize origins=0;var usize arg=0;
    while(arg<p.arities[target]){
        let usize formal=p.register_starts[target]+arg;
        if(p.slice_parameters[formal]!=0){
            let usize source=parameters::argument(p,formal,p.call_args[args*8+arg] as usize,caller,live,pc)?;
            let usize bit=one<<source;
            if((suspended&bit)!=0){return .err(errors::make(5,pc));}
            if(ir::exclusive(p,source)){
                let usize root=p.slice_roots[source] as usize;let usize origin=p.slice_origins[source] as usize;
                let usize root_bit=if(root==0){0}else{one<<(root-1)};
                let usize origin_bit=if(origin==0){0}else{one<<(origin-1)};
                if((writers&bit)!=0 || (roots&root_bit)!=0 || (origins&origin_bit)!=0){return .err(errors::make(5,pc));}
                writers|=bit;roots|=root_bit;origins|=origin_bit;
            }
        }
        arg+=1;
    }
    return .ok(live);
}
