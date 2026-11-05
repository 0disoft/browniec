module static_call_ir;
import ir as ir;
import errors as errors;
import static_image as images;

// Recipe proof only. Whole scalar/owner/loan admission and VM integration remain
// mandatory; this module cannot grant executable Program/image authority.
// 77 PARAM: dst=site,a=formal register,b=1 bytes/2 text; entry prelude only.
// 78 CALL: dst=result site or ordinary destination,a=callee,b=CALL map.
// Static actuals use 192+site, never a scalar cell; other actuals retain their
// ordinary signature-selected encoding. 79 RETURN: dst=0,a=sole live site,b=0.
// Bytes4..7 of 77..79 are reserved zero. Static return type is zero in body.
// Origin claims: 1..8 exact input position, 9 Static, 0 ordinary result.
// Separate reference analysis admits PARAM kind 3: shared bytes from image or
// runtime loan actuals. It cannot be a result kind or execute via Static APIs.
pub struct Program { ir::Program body; u8[128] parameters; u8[16] results; u8[16] origins; }
pub struct Proof {
    usize[16] definitions; usize[16] functions; u8[16] kinds;
    u8[128] formal_sites; u8[16] site_origins; u8[16] result_origins;
    usize sites; usize calls; usize returns; usize rounds;
}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
fn Proof empty(){return Proof{.definitions=[256;16],.functions=[16;16],.kinds=[0;16],
    .formal_sites=[0;128],.site_origins=[0;16],.result_origins=[0;16],.sites=0,.calls=0,.returns=0,.rounds=0};}
fn bool reserved(ref ir::Program p,usize at){return p.code[at+4]==0 && p.code[at+5]==0 && p.code[at+6]==0 && p.code[at+7]==0;}
fn bool input(ref Program unit,usize f){
    let ref ir::Program p=ref unit.body;var usize r=p.register_starts[f];
    while(r<p.register_starts[f]+p.arities[f]){if(unit.parameters[r]!=0){return true;}r+=1;}return false;
}
fn Result<usize,errors::Error> header(ref Program unit,bool references){
    let ref ir::Program p=ref unit.body;
    if(p.count==0 || p.count>256 || p.registers==0 || p.registers>128 ||
        p.function_count==0 || p.function_count>16 || p.entry>=p.function_count || p.call_count>32){return .err(invalid(0));}
    var usize code=0;var usize registers=0;var usize f=0;
    while(f<16){let u8 kind=unit.results[f];let u8 origin=unit.origins[f];
        if(f>=p.function_count){if(kind!=0 || origin!=0){return .err(invalid(0));}}
        else{
            if(p.starts[f]!=code || p.ends[f]<=code || p.ends[f]>p.count ||
                p.register_starts[f]!=registers || p.register_ends[f]<registers || p.register_ends[f]>p.registers ||
                p.arities[f]>8 || p.arities[f]>p.register_ends[f]-registers){return .err(invalid(code));}
            if(kind>2 || (kind==0 && origin!=0) || (kind!=0 &&
                (origin==0 || origin>9 || (origin!=9 && origin as usize>p.arities[f]) ||
                p.return_types[f]!=0 || p.array_results[f]!=0 || p.record_results[f]!=0))){return .err(invalid(code));}
            var usize r=registers;
            while(r<p.register_ends[f]){let u8 access=unit.parameters[r];
                if(access>if(references){3}else{2} || (access!=0 && (r>=registers+p.arities[f] || p.types[r]!=0 || p.slots[r] ||
                    p.array_parameters[r]!=0 || p.record_parameters[r]!=0 || p.slice_parameters[r]!=0))){return .err(invalid(code));}r+=1;
            }
            if(kind!=0 && origin!=9 && unit.parameters[registers+origin as usize-1]==0){return .err(invalid(code));}
            code=p.ends[f];registers=p.register_ends[f];
        }f+=1;
    }
    if(code!=p.count || registers!=p.registers || p.arities[p.entry]!=0 || unit.results[p.entry]!=0 || p.return_types[p.entry]!=1){return .err(invalid(0));}
    var usize r=p.registers;while(r<128){if(unit.parameters[r]!=0){return .err(invalid(0));}r+=1;}
    return .ok(p.count);
}
fn Result<usize,errors::Error> define(ref mut Proof proof,usize dst,usize f,u8 kind,usize pc){
    if(dst>=16 || proof.definitions[dst]!=256 || (kind!=1 && kind!=2 && kind!=3)){return .err(invalid(pc));}
    proof.definitions[dst]=pc;proof.functions[dst]=f;proof.kinds[dst]=kind;proof.sites+=1;return .ok(dst);
}
fn bool prior(ref Proof proof,usize site,usize f,usize pc){return site<16 && proof.functions[site]==f && proof.definitions[site]<pc;}
fn Result<usize,errors::Error> definitions(ref Program unit,ref images::Image image,ref mut Proof proof){
    let ref ir::Program p=ref unit.body;var usize f=0;
    while(f<p.function_count){var bool prelude=true;var usize last=0;var bool parameter=false;var usize pc=p.starts[f];
        while(pc<p.ends[f]){let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
            let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
            if(op>=77 && op<=79 && !reserved(p,at)){return .err(invalid(pc));}
            if(op==77){
                if(!prelude || a<p.register_starts[f] || a>=p.register_starts[f]+p.arities[f] ||
                    (parameter && a<=last) || unit.parameters[a]!=p.code[at+3] || (b!=1 && b!=2 && b!=3) || proof.formal_sites[a]!=0){return .err(invalid(pc));}
                let usize made=define(proof,dst,f,p.code[at+3],pc)?;
                // dst <=15; bounded conversion without a narrowing cast.
                var u8 encoded=1;var usize n=0;while(n<dst){encoded+=1;n+=1;}proof.formal_sites[a]=encoded;
                last=a;parameter=true;
            }else{prelude=false;}
            if(op==69){let u8 kind=p.code[at+3];
                let u8 actual=switch(images::kind(image,a)){case .ok(v):{v}case .err(_):{return .err(invalid(pc));}};
                if(kind!=actual){return .err(invalid(pc));}
                let images::Span span=images::Span{.literal=a,.start=p.code[at+4] as usize+256*(p.code[at+5] as usize),
                    .end=p.code[at+6] as usize+256*(p.code[at+7] as usize)};
                switch(images::view(image,span)){case .ok(_):{}case .err(_):{return .err(invalid(pc));}};
                if(kind==2){switch(images::text(image,span)){case .ok(_):{}case .err(_):{return .err(invalid(pc));}};}
                let usize made=define(proof,dst,f,kind,pc)?;
            }else if(op==74 || op==75 || op==76){
                if(!prior(proof,a,f,pc) || (op==74 && proof.kinds[a]!=2) || (op==76 && proof.kinds[a]!=1 && proof.kinds[a]!=3) ||
                    (op!=76 && (b!=0 || !reserved(p,at))) ||
                    (op==76 && (p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0))){return .err(invalid(pc));}
                let u8 kind=if(op==74){1}else{proof.kinds[a]};let usize made=define(proof,dst,f,kind,pc)?;
            }else if(op==78){
                if(a>=p.function_count || a==p.entry || b>=p.call_count){return .err(invalid(pc));}
                if(unit.results[a]!=0){let usize made=define(proof,dst,f,unit.results[a],pc)?;}
            }
            pc+=1;
        }f+=1;
    }
    var usize r=0;while(r<p.registers){if(unit.parameters[r]!=0 && proof.formal_sites[r]==0){return .err(invalid(0));}r+=1;}
    return .ok(proof.sites);
}
fn bool live(ref Proof proof,usize site,usize f,usize bits){
    let usize one=1;return site<16 && proof.functions[site]==f && proof.kinds[site]!=0 && (bits&(one<<site))!=0;
}
fn Result<usize,errors::Error> arguments(ref Program unit,ref Proof proof,usize f,usize pc,usize bits,ref mut bool[] used){
    let ref ir::Program p=ref unit.body;let usize at=pc*8;let usize callee=p.code[at+2] as usize;let usize map=p.code[at+3] as usize;
    if(callee>=p.function_count || map>=p.call_count || used[map] || p.call_arities[map] as usize!=p.arities[callee]){return .err(invalid(pc));}
    let bool extended=unit.results[callee]!=0 || input(unit,callee);
    if((p.code[at]==78)!=extended){return .err(invalid(pc));}
    var usize i=0;while(i<p.arities[callee]){let usize formal=p.register_starts[callee]+i;let usize value=p.call_args[map*8+i] as usize;
        let u8 kind=unit.parameters[formal];
        if(kind!=0){
            if(kind==3 && value>=160 && value<176){
                // Canonical loan proof must still authenticate liveness, owner
                // and exact byte/shared mode. No scalar or image coercion.
            }else{
                if(value<192 || value>=208 || !live(proof,value-192,f,bits)){return .err(invalid(pc));}
                let u8 actual=proof.kinds[value-192];
                if(if(kind==3){actual!=1 && actual!=3}else{actual!=kind}){return .err(invalid(pc));}
            }
        }else if(p.array_parameters[formal]!=0){if(value<128 || value>=144){return .err(invalid(pc));}}
        else if(p.record_parameters[formal]!=0){if(value<144 || value>=160){return .err(invalid(pc));}}
        else if(p.slice_parameters[formal]!=0){if(value<160 || value>=176){return .err(invalid(pc));}}
        else if(value>=128){return .err(invalid(pc));}i+=1;
    }
    while(i<8){if(p.call_args[map*8+i]!=0){return .err(invalid(pc));}i+=1;}
    used[map]=true;return .ok(map);
}
fn Result<usize,errors::Error> merge(ref mut bool[] seen,ref mut usize[] states,usize target,usize bits,usize pc){
    if(seen[target] && states[target]!=bits){return .err(invalid(pc));}seen[target]=true;states[target]=bits;return .ok(target);
}
fn Result<usize,errors::Error> flow(ref Program unit,ref mut Proof proof,usize f,ref mut bool[] calls){
    let ref ir::Program p=ref unit.body;var bool[256] seen=[false;256];var usize[256] states=[0;256];
    seen[p.starts[f]]=true;let usize one=1;var usize pc=p.starts[f];var usize after=p.starts[f];
    while(after<p.ends[f] && p.code[after*8]==77){after+=1;}
    while(pc<p.ends[f]){
        if(!seen[pc]){return .err(invalid(pc));}var usize bits=states[pc];let usize at=pc*8;let u8 op=p.code[at];
        let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
        if(op==0 || op>79){return .err(invalid(pc));}
        if(op==9 || op==64 || op==66 || op==78){let usize checked=arguments(unit,proof,f,pc,bits,calls)?;if(op==78){proof.calls+=1;}}
        let bool definition=op==69 || op==74 || op==75 || op==76 || op==77 || (op==78 && unit.results[a]!=0);
        if(definition){
            if(dst>=16 || proof.definitions[dst]!=pc || (bits&(one<<dst))!=0){return .err(invalid(pc));}
            if((op==74 || op==75 || op==76) && !live(proof,a,f,bits)){return .err(invalid(pc));}
            if(op==76){let usize hi=p.code[at+4] as usize;
                if(b<p.register_starts[f] || b>=p.register_ends[f] || hi<p.register_starts[f] || hi>=p.register_ends[f] ||
                    p.types[b]!=12 || p.types[hi]!=12 || p.slots[b] || p.slots[hi] || unit.parameters[b]!=0 || unit.parameters[hi]!=0){return .err(invalid(pc));}}
            bits|=one<<dst;
        }else if(op==70){
            if(!live(proof,dst,f,bits) || a!=0 || b!=0 || !reserved(p,at)){return .err(invalid(pc));}bits^=one<<dst;
        }else if(op==71 || op==72 || op==73){
            if(!live(proof,a,f,bits) || (op!=73 && proof.kinds[a]!=1 && proof.kinds[a]!=3) ||
                (op==73 && (!live(proof,b,f,bits) || proof.kinds[a]==3 || proof.kinds[b]==3)) ||
                (op==72 && b!=0) || !reserved(p,at)){return .err(invalid(pc));}
        }else if(op==79){
            if(dst!=0 || b!=0 || unit.results[f]==0 || !live(proof,a,f,bits) || bits!=(one<<a) || proof.kinds[a]!=unit.results[f]){return .err(invalid(pc));}
            proof.returns+=1;pc+=1;continue;
        }
        if(op==8 || op==39 || op==50 || op==65){if(bits!=0 || unit.results[f]!=0){return .err(invalid(pc));}pc+=1;continue;}
        if(op==25){pc+=1;continue;}
        if(op==22){if(a<after || a>=pc || !seen[a] || states[a]!=bits){return .err(invalid(pc));}pc+=1;continue;}
        if(op==19 || op==20 || op==21 || op==24){
            let usize target=if(op==19){a}else if(op==24){p.code[at+4] as usize}else{b};
            if(target<=pc || target>=p.ends[f] || target<after){return .err(invalid(pc));}
            let usize linked=merge(ref mut seen,ref mut states,target,bits,pc)?;
            if(op==19){pc+=1;continue;}
        }
        if(pc+1>=p.ends[f]){return .err(invalid(pc));}
        let usize linked=merge(ref mut seen,ref mut states,pc+1,bits,pc)?;pc+=1;
    }return .ok(p.ends[f]);
}
fn Result<usize,errors::Error> origins(ref Program unit,ref mut Proof proof){
    let ref ir::Program p=ref unit.body;var usize round=0;var bool changed=true;
    while(changed && round<16){changed=false;round+=1;var usize f=0;
        while(f<p.function_count){var u8 candidate=0;var usize pc=p.starts[f];
            while(pc<p.ends[f]){let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
                let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
                if(op==69){proof.site_origins[dst]=9;}
                else if(op==77){var u8 position=1;var usize r=p.register_starts[f];while(r<a){position+=1;r+=1;}proof.site_origins[dst]=position;}
                else if(op==74 || op==75 || op==76){let u8 origin=proof.site_origins[a];proof.site_origins[dst]=origin;}
                else if(op==78 && unit.results[a]!=0){let u8 selected=proof.result_origins[a];var u8 origin=0;
                    if(selected==9){origin=9;}else if(selected!=0){let usize actual=p.call_args[b*8+selected as usize-1] as usize;
                        if(actual<192 || actual>=208){return .err(invalid(pc));}origin=proof.site_origins[actual-192];}
                    proof.site_origins[dst]=origin;
                }
                if(op==79){let u8 origin=proof.site_origins[a];if(origin!=0){if(candidate!=0 && candidate!=origin){return .err(invalid(pc));}candidate=origin;}}
                pc+=1;
            }
            if(candidate!=0){if(proof.result_origins[f]!=0 && proof.result_origins[f]!=candidate){return .err(invalid(p.starts[f]));}
                if(proof.result_origins[f]==0){proof.result_origins[f]=candidate;changed=true;}}
            f+=1;
        }
    }
    var usize f=0;while(f<p.function_count){
        if(proof.result_origins[f]!=unit.origins[f]){return .err(invalid(p.starts[f]));}
        var usize pc=p.starts[f];while(pc<p.ends[f]){
            if(p.code[pc*8]==79 && proof.site_origins[p.code[pc*8+2] as usize]!=proof.result_origins[f]){return .err(invalid(pc));}pc+=1;
        }f+=1;
    }proof.rounds=round;return .ok(round);
}
fn Result<Proof,errors::Error> inspect_mode(ref Program unit,ref images::Image image,bool references){
    let usize bounded=header(unit,references)?;
    switch(images::inspect(image)){case .ok(_):{}case .err(_):{return .err(invalid(0));}};
    var Proof proof=empty();let usize defined=definitions(unit,image,ref mut proof)?;
    var bool[32] calls=[false;32];var usize f=0;while(f<unit.body.function_count){let usize checked=flow(unit,ref mut proof,f,ref mut calls)?;f+=1;}
    var usize i=0;while(i<unit.body.call_count){if(!calls[i]){return .err(invalid(0));}i+=1;}
    let usize grounded=origins(unit,ref mut proof)?;return .ok(proof);
}
pub fn Result<Proof,errors::Error> inspect(ref Program unit,ref images::Image image){return inspect_mode(unit,image,false);}
// Kind 3 is a shared byte formal accepting image sites or runtime loan actuals.
// It is not a result kind. This is recipe analysis, never VM admission.
pub fn Result<Proof,errors::Error> inspect_references(ref Program unit,ref images::Image image){return inspect_mode(unit,image,true);}
