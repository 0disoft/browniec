module static_call_sites;
import static_call_ir as calls;
import static_ir as statics;
import static_image as images;
import ir as ir;
import errors as errors;

// A proof window set contains actual OPEN definition identities, not pointers.
// It permits different literals at different calls without broadening a value.
// Runtime still must transfer authenticated actual words in the exact image.
pub fn Result<statics::Sites,errors::Error> prepare(ref calls::Program unit,ref calls::Proof proof,ref images::Image image){
    let ref ir::Program p=ref unit.body;var statics::Sites sites=statics::empty();
    sites.definitions=proof.definitions;sites.functions=proof.functions;sites.kinds=proof.kinds;
    sites.count=proof.sites;sites.call_profile=true;sites.parameters=unit.parameters;sites.formal_sites=proof.formal_sites;
    sites.results=unit.results;sites.origins=proof.result_origins;
    let usize one=1;var usize site=0;
    while(site<16){if(proof.kinds[site]!=0){let usize pc=proof.definitions[site];let usize at=pc*8;
            if(p.code[at]==69){let images::Span span=images::Span{.literal=p.code[at+2] as usize,
                    .start=p.code[at+4] as usize+256*(p.code[at+5] as usize),.end=p.code[at+6] as usize+256*(p.code[at+7] as usize)};
                sites.spans[site]=span;sites.starts[site]=switch(images::absolute(image,span)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,pc));}};
                sites.roots[site]=one<<site;
            }else{sites.generic|=one<<site;sites.dynamic|=one<<site;}
        }site+=1;
    }
    var bool changed=true;var usize round=0;
    while(changed && round<16){changed=false;round+=1;site=0;
        while(site<16){if(proof.kinds[site]!=0){let usize pc=proof.definitions[site];let usize at=pc*8;let u8 op=p.code[at];
                let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;var usize roots=sites.roots[site];
                if(op==74 || op==75 || op==76){roots|=sites.roots[a];}
                else if(op==77){let usize f=proof.functions[site];let usize position=a-p.register_starts[f];var usize call=0;
                    while(call<p.count){if(p.code[call*8]==78 && p.code[call*8+2] as usize==f){let usize map=p.code[call*8+3] as usize;
                            let usize actual=p.call_args[map*8+position] as usize;
                            if(actual>=192 && actual<208){roots|=sites.roots[actual-192];}
                            else if(unit.parameters[a]!=3 || actual<160 || actual>=176){return .err(errors::make(5,call));}}call+=1;}
                }else if(op==78){let usize selected=proof.result_origins[a] as usize;
                    if(selected==9){var usize ret=p.starts[a];while(ret<p.ends[a]){
                            if(p.code[ret*8]==79){roots|=sites.roots[p.code[ret*8+2] as usize];}ret+=1;}
                    }else{if(selected==0 || selected>p.arities[a]){return .err(errors::make(5,pc));}
                        let usize actual=p.call_args[b*8+selected-1] as usize;
                        if(actual>=192 && actual<208){roots|=sites.roots[actual-192];}
                        else if(unit.results[a]!=3 || actual<160 || actual>=176){return .err(errors::make(5,pc));}}
                }
                if(roots!=sites.roots[site]){sites.roots[site]=roots;changed=true;}
            }site+=1;
        }
    }
    // At most sixteen site nodes: every simple root-reachability path has
    // fifteen edges. Latent or runtime-only reference formals may have no image
    // roots. Runtime provenance belongs to canonical loan proof, not this set.
    return .ok(sites);
}
