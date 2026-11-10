module output_static_sites_work;
import static_call_ir as calls;
import static_ir as statics;
import static_image as images;
import ir as ir;
import errors as errors;
import metadata_budget as budget;

// Analysis after the exact recipe/image proof. Pin that Program, Proof and
// immutable Image. One stage initializes fixed rows or visits one site. A site
// may inspect <=256 CALL/RETURN PCs, below the conservative fresh 4096 bound.
pub struct State { statics::Sites result; usize site; usize round; u8 phase; bool changed; bool done; }
pub fn State empty(){return State{.result=statics::empty(),.site=0,.round=0,.phase=0,.changed=false,.done=false};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
pub fn Result<bool,errors::Error> advance(ref calls::Program unit,ref calls::Proof proof,ref images::Image image,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(!budget::admit(meter,4096,0)?){return .ok(false);}
    let ref ir::Program p=ref unit.body;let usize one=1;
    if(w.phase==0){
        w.result=statics::empty();w.result.definitions=proof.definitions;w.result.functions=proof.functions;w.result.kinds=proof.kinds;
        w.result.count=proof.sites;w.result.call_profile=true;w.result.parameters=unit.parameters;w.result.formal_sites=proof.formal_sites;
        w.result.results=unit.results;w.result.origins=proof.result_origins;w.site=0;w.phase=1;return .ok(false);
    }
    let usize site=w.site;
    if(w.phase==1){
        if(site==16){w.phase=2;w.site=0;w.round=0;w.changed=false;return .ok(false);}
        if(proof.kinds[site]!=0){let usize pc=proof.definitions[site];let usize at=pc*8;
            if(p.code[at]==69){let images::Span span=images::Span{.literal=p.code[at+2] as usize,
                .start=p.code[at+4] as usize+256*(p.code[at+5] as usize),.end=p.code[at+6] as usize+256*(p.code[at+7] as usize)};
                let usize start=switch(images::absolute(image,span)){case .ok(v):{v}case .err(_):{return .err(invalid(pc));}};
                w.result.spans[site]=span;w.result.starts[site]=start;w.result.roots[site]=one<<site;
            }else{w.result.generic|=one<<site;w.result.dynamic|=one<<site;}
        }w.site+=1;return .ok(false);
    }
    if(w.phase!=2){return .err(invalid(0));}
    if(site==16){
        w.round+=1;
        if(!w.changed || w.round==16){w.done=true;return .ok(true);}
        w.site=0;w.changed=false;return .ok(false);
    }
    if(proof.kinds[site]!=0){let usize pc=proof.definitions[site];let usize at=pc*8;let u8 op=p.code[at];
        let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;var usize roots=w.result.roots[site];
        if(op==74 || op==75 || op==76){roots|=w.result.roots[a];}
        else if(op==77){let usize f=proof.functions[site];let usize position=a-p.register_starts[f];var usize call=0;
            while(call<p.count){if(p.code[call*8]==78 && p.code[call*8+2] as usize==f){let usize map=p.code[call*8+3] as usize;
                let usize actual=p.call_args[map*8+position] as usize;
                if(actual>=192 && actual<208){roots|=w.result.roots[actual-192];}
                else if(unit.parameters[a]!=3 || actual<160 || actual>=176){return .err(invalid(call));}
            }call+=1;}
        }else if(op==78){let usize selected=proof.result_origins[a] as usize;
            if(selected==9){var usize ret=p.starts[a];while(ret<p.ends[a]){
                if(p.code[ret*8]==79){roots|=w.result.roots[p.code[ret*8+2] as usize];}ret+=1;
            }}else{
                if(selected==0 || selected>p.arities[a]){return .err(invalid(pc));}
                let usize actual=p.call_args[b*8+selected-1] as usize;
                if(actual>=192 && actual<208){roots|=w.result.roots[actual-192];}
                else if(unit.results[a]!=3 || actual<160 || actual>=176){return .err(invalid(pc));}
            }
        }
        if(roots!=w.result.roots[site]){w.result.roots[site]=roots;w.changed=true;}
    }
    w.site+=1;return .ok(false);
}
