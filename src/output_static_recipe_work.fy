module output_static_recipe_work;
import ir as ir;
import errors as errors;
import static_image as images;
import aggregate_place_ir as aggregates;
import output_ir as output_ir;
import static_call_ir as recipes;
import output_image_work as image_work;
import metadata_budget as budget;

// Resumable analysis-only mirror of static_call_ir::inspect_output_returns.
// The caller pins the exact Program and immutable Image until completion. One
// fresh 4096-unit stage visits one PC (or one fixed header/coverage row). The
// image validator is independently staged. No allowance is retained.
pub struct State {
    image_work::State image;
    recipes::Proof result;
    bool[32] calls;
    bool[256] seen;
    usize[256] states;
    usize count; usize functions; usize entry; usize calls_used;
    usize image_bytes; usize image_literals; usize work;
    usize function; usize pc; usize round; usize code; usize registers;
    u8 phase; bool prelude; bool parameter; bool changed; bool input;
    bool output; bool active; bool done;
}

pub fn State empty(){
    return State{.image=image_work::empty(),.result=blank(),.calls=[false;32],
        .seen=[false;256],.states=[0;256],.count=0,.functions=0,.entry=0,.calls_used=0,
        .image_bytes=0,.image_literals=0,.work=0,.function=0,.pc=0,.round=0,.code=0,.registers=0,
        .phase=0,.prelude=false,.parameter=false,.changed=false,.input=false,.output=true,
        .active=false,.done=false};
}
fn recipes::Proof blank(){return recipes::Proof{.definitions=[256;16],.functions=[16;16],
    .kinds=[0;16],.formal_sites=[0;128],.site_origins=[0;16],.result_origins=[0;16],
    .sites=0,.calls=0,.returns=0,.rounds=0};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
// The analysis recipe uses the same reserved-tail rule as the synchronous
// recipe. Aggregate opcodes defer only their aggregate-specific tails; the
// remaining 77..87 rows retain this tighter shape.
fn bool reserved(ref ir::Program p,usize at){
    if(p.code[at]==87 || (p.code[at+4]>=3 && p.code[at]>=83)){return aggregates::reserved(p,at/8);}
    let u8 op=p.code[at];let bool record=op>=83 && op<=85 && p.code[at+4]==2;
    return (if(op>=83 && op<=85){p.code[at+4]<=2}else{p.code[at+4]==0}) &&
        (if(record){p.code[at+5]<128 && (op!=83 || p.code[at+3]==0)}else{p.code[at+5]==0}) &&
        p.code[at+6]==0 && p.code[at+7]==0;
}
fn bool boundary(ref u8[] literal,usize offset){
    return offset==literal.len || (literal[offset]&192)!=128;
}

// Begin stores only shape values used to reject a paired Program/Image
// substitution. It reads no PC and installs no image or recipe proof.
pub fn Result<usize,errors::Error> begin(ref mut State w,ref recipes::Program unit,ref images::Image image,bool input){
    if(w.active){return .err(invalid(0));}
    w.image=image_work::empty();w.result=blank();w.calls=[false;32];w.seen=[false;256];w.states=[0;256];
    w.count=unit.body.count;w.functions=unit.body.function_count;w.entry=unit.body.entry;
    w.calls_used=unit.body.call_count;w.image_bytes=images::payload_bytes(image);
    w.image_literals=images::catalog(image).count;w.work=0;w.function=0;w.pc=0;w.round=0;
    w.code=0;w.registers=0;w.phase=0;w.prelude=false;w.parameter=false;w.changed=false;
    w.input=input;w.output=true;w.active=true;w.done=false;return .ok(0);
}
// Both ordinary and input-only programs reject EMIT.
pub fn Result<usize,errors::Error> begin_without_output(ref mut State w,ref recipes::Program unit,ref images::Image image,bool input){
    let usize begun=begin(w,unit,image,input)?;w.output=false;return .ok(begun);
}
pub fn Result<usize,errors::Error> begin_input(ref mut State w,ref recipes::Program unit,ref images::Image image){
    return begin_without_output(w,unit,image,true);
}
fn bool same_pair(ref State w,ref recipes::Program unit,ref images::Image image){
    return w.count==unit.body.count && w.functions==unit.body.function_count &&
        w.entry==unit.body.entry && w.calls_used==unit.body.call_count &&
        w.image_bytes==images::payload_bytes(image) && w.image_literals==images::catalog(image).count;
}

// Phase 0: dimensions. The complete header follows before image validation.
fn Result<usize,errors::Error> opening(ref mut State w,ref recipes::Program unit,ref mut budget::State meter){
    let ref ir::Program p=ref unit.body;
    if(!budget::admit(meter,4096,0)?){return .ok(0);}
    if(p.count==0 || p.count>256 || p.registers==0 || p.registers>128 ||
        p.function_count==0 || p.function_count>16 || p.entry>=p.function_count || p.call_count>32){
        return .err(invalid(0));
    }
    w.phase=1;w.function=0;w.code=0;w.registers=0;
    return .ok(0);
}

// Phase 1: the raw header's sixteen rows. One row visits every register access
// in its fixed function interval, so this remains bounded by 128 logical reads.
fn Result<usize,errors::Error> header(ref mut State w,ref recipes::Program unit){
    let ref ir::Program p=ref unit.body;let usize f=w.function;let u8 kind=unit.results[f];let u8 origin=unit.origins[f];
    if(f>=p.function_count){
        if(kind!=0 || origin!=0){return .err(invalid(0));}
        w.function+=1;
        if(w.function==16){w.phase=2;w.function=0;}
        return .ok(0);
    }
    if(p.starts[f]!=w.code || p.ends[f]<=w.code || p.ends[f]>p.count ||
        p.register_starts[f]!=w.registers || p.register_ends[f]<w.registers || p.register_ends[f]>p.registers ||
        p.arities[f]>8 || p.arities[f]>p.register_ends[f]-w.registers){return .err(invalid(w.code));}
    if(kind>3 || (kind==0 && origin!=0) || (kind!=0 &&
        (origin==0 || origin>9 || (origin!=9 && origin as usize>p.arities[f]) ||
        p.return_types[f]!=0 || p.array_results[f]!=0 || p.record_results[f]!=0))){return .err(invalid(w.code));}
    var usize r=w.registers;
    while(r<p.register_ends[f]){
        let u8 access=unit.parameters[r];
        if(access>3 || (access!=0 && (r>=w.registers+p.arities[f] || p.types[r]!=0 || p.slots[r] ||
            p.array_parameters[r]!=0 || p.record_parameters[r]!=0 || p.slice_parameters[r]!=0))){
            return .err(invalid(w.code));
        }
        r+=1;
    }
    if(kind!=0 && origin!=9 && unit.parameters[w.registers+origin as usize-1]==0){
        let usize loan=p.slice_parameters[w.registers+origin as usize-1] as usize;
        if(kind!=3 || loan==0 || loan>16 || p.slice_elements[loan-1]!=10){return .err(invalid(w.code));}
    }
    w.code=p.ends[f];w.registers=p.register_ends[f];w.function+=1;
    if(w.function==16){w.phase=2;w.function=0;}
    return .ok(0);
}
fn Result<usize,errors::Error> header_finish(ref mut State w,ref recipes::Program unit){
    let ref ir::Program p=ref unit.body;
    if(w.code!=p.count || w.registers!=p.registers || unit.results[p.entry]!=0 || p.return_types[p.entry]!=1){
        return .err(invalid(0));
    }
    if(w.input){if(p.arities[p.entry]!=1 || unit.parameters[p.register_starts[p.entry]]!=3){return .err(invalid(0));}}
    else if(p.arities[p.entry]!=0){return .err(invalid(0));}
    var usize r=p.registers;while(r<128){if(unit.parameters[r]!=0){return .err(invalid(0));}r+=1;}
    w.phase=3;w.function=0;w.pc=p.starts[0];w.code=0;w.registers=0;w.prelude=true;w.parameter=false;return .ok(0);
}
fn Result<usize,errors::Error> define(ref mut State w,usize dst,usize f,u8 kind,usize pc){
    if(dst>=16 || w.result.definitions[dst]!=256 || (kind!=1 && kind!=2 && kind!=3)){return .err(invalid(pc));}
    w.result.definitions[dst]=pc;w.result.functions[dst]=f;w.result.kinds[dst]=kind;w.result.sites+=1;return .ok(dst);
}
fn Result<u8,errors::Error> encoded_origin(usize value){
    var u8 encoded=0;var usize n=0;
    while(n<value){if(encoded==255){return .err(invalid(0));}encoded+=1;n+=1;}
    return .ok(encoded);
}
fn bool prior(ref State w,usize site,usize f,usize pc){
    return site<16 && w.result.functions[site]==f && w.result.definitions[site]<pc;
}

// Phase 3: exactly one raw definition visit per stage. Site identity, image
// kind/span/text, prelude order, and conversion/range rules retain raw order.
fn Result<usize,errors::Error> definition(ref mut State w,ref recipes::Program unit,ref images::Image image){
    let ref ir::Program p=ref unit.body;let usize f=w.function;let usize pc=w.pc;let usize at=pc*8;
    let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
    let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    if(op>=77 && op<=87 && !reserved(p,at)){return .err(invalid(pc));}
    if(op==77){
        if(!w.prelude || a<p.register_starts[f] || a>=p.register_starts[f]+p.arities[f] ||
            (w.parameter && a<=w.code) || unit.parameters[a]!=p.code[at+3] ||
            (b!=1 && b!=2 && b!=3) || w.result.formal_sites[a]!=0){return .err(invalid(pc));}
        let usize made=define(w,dst,f,p.code[at+3],pc)?;
        var u8 encoded=1;var usize n=0;while(n<dst){encoded+=1;n+=1;}
        w.result.formal_sites[a]=encoded;w.code=a;w.parameter=true;
    }else{w.prelude=false;}
    if(op==69){
        let u8 kind=p.code[at+3];
        let u8 actual=switch(images::kind(image,a)){case .ok(v):{v}case .err(_):{return .err(invalid(pc));}};
        if(kind!=actual){return .err(invalid(pc));}
        let images::Span span=images::Span{.literal=a,.start=p.code[at+4] as usize+256*(p.code[at+5] as usize),
            .end=p.code[at+6] as usize+256*(p.code[at+7] as usize)};
        switch(images::view(image,span)){case .ok(_):{}case .err(_):{return .err(invalid(pc));}};
        if(kind==2){
            let usize begin=images::catalog(image).starts[a];let usize stop=images::catalog(image).ends[a];
            let ref u8[] literal=images::payload(image)[begin..stop];
            if(!boundary(literal,span.start) || !boundary(literal,span.end)){return .err(invalid(pc));}
        }
        let usize made=define(w,dst,f,kind,pc)?;
    }else if(op==74 || op==75 || op==76){
        if(!prior(w,a,f,pc) || (op==74 && w.result.kinds[a]!=2) ||
            (op==76 && w.result.kinds[a]!=1 && w.result.kinds[a]!=3) ||
            (op!=76 && (b!=0 || !reserved(p,at))) ||
            (op==76 && (p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0))){return .err(invalid(pc));}
        let u8 kind=if(op==74){1}else{w.result.kinds[a]};let usize made=define(w,dst,f,kind,pc)?;
    }else if(op==78){
        if(a>=p.function_count || a==p.entry || b>=p.call_count){return .err(invalid(pc));}
        if(unit.results[a]!=0){let usize made=define(w,dst,f,unit.results[a],pc)?;}
    }
    w.pc+=1;
    if(w.pc==p.ends[f]){w.function+=1;w.code=0;w.parameter=false;w.prelude=true;
        if(w.function==p.function_count){w.phase=5;w.function=0;}}
    return .ok(0);
}
fn Result<usize,errors::Error> definitions_finish(ref mut State w,ref recipes::Program unit){
    let ref ir::Program p=ref unit.body;var usize r=0;
    while(r<p.registers){
        if(unit.parameters[r]!=0 && w.result.formal_sites[r]==0){return .err(invalid(0));}
        r+=1;
    }
    w.phase=6;w.function=0;w.pc=p.starts[0];w.code=p.starts[0];w.seen=[false;256];w.states=[0;256];
    return .ok(0);
}
fn bool live(ref State w,usize site,usize f,usize bits){
    let usize one=1;return site<16 && w.result.functions[site]==f && w.result.kinds[site]!=0 && (bits&(one<<site))!=0;
}
fn bool input(ref recipes::Program unit,usize f){
    let ref ir::Program p=ref unit.body;var usize r=p.register_starts[f];
    while(r<p.register_starts[f]+p.arities[f]){if(unit.parameters[r]!=0){return true;}r+=1;}return false;
}
fn Result<usize,errors::Error> arguments(ref mut State w,ref recipes::Program unit,usize f,usize pc,usize bits){
    let ref ir::Program p=ref unit.body;let usize at=pc*8;let usize callee=p.code[at+2] as usize;let usize map=p.code[at+3] as usize;
    if(callee>=p.function_count || map>=p.call_count || w.calls[map] ||
        p.call_arities[map] as usize!=p.arities[callee]){return .err(invalid(pc));}
    let bool extended=unit.results[callee]!=0 || input(unit,callee);
    if((p.code[at]==78)!=extended){return .err(invalid(pc));}
    var usize i=0;
    while(i<p.arities[callee]){
        let usize formal=p.register_starts[callee]+i;let usize value=p.call_args[map*8+i] as usize;
        let u8 kind=unit.parameters[formal];
        if(kind!=0){
            if(kind==3 && value>=160 && value<176){}
            else{
                if(value<192 || value>=208 || !live(w,value-192,f,bits)){return .err(invalid(pc));}
                let u8 actual=w.result.kinds[value-192];
                if(if(kind==3){actual!=1 && actual!=3}else{actual!=kind}){return .err(invalid(pc));}
            }
        }else if(p.array_parameters[formal]!=0){if(value<128 || value>=144){return .err(invalid(pc));}}
        else if(p.record_parameters[formal]!=0){if(value<144 || value>=160){return .err(invalid(pc));}}
        else if(p.slice_parameters[formal]!=0){if(value<160 || value>=176){return .err(invalid(pc));}}
        else if(value>=128){return .err(invalid(pc));}
        i+=1;
    }
    while(i<8){if(p.call_args[map*8+i]!=0){return .err(invalid(pc));}i+=1;}
    w.calls[map]=true;return .ok(map);
}
fn Result<usize,errors::Error> merge(ref mut State w,usize target,usize bits,usize pc){
    if(w.seen[target] && w.states[target]!=bits){return .err(invalid(pc));}
    w.seen[target]=true;w.states[target]=bits;return .ok(target);
}

// Phase 5/6: one PC from the raw static CFG proof. Function state is reset in
// its own fixed stage. Every successor is checked before its join is stored.
fn Result<usize,errors::Error> flow_function(ref mut State w,ref recipes::Program unit){
    let ref ir::Program p=ref unit.body;let usize f=w.function;
    if(w.phase==6){
        w.seen=[false;256];w.states=[0;256];w.seen[p.starts[f]]=true;w.pc=p.starts[f];
        var usize after=p.starts[f];while(after<p.ends[f] && p.code[after*8]==77){after+=1;}
        w.code=after;w.round=after;w.phase=7;return .ok(0);
    }
    let usize pc=w.pc;let usize at=pc*8;let usize one=1;
    if(!w.seen[pc]){return .err(invalid(pc));}
    var usize bits=w.states[pc];let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
    let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    if(op==0 || (op>87 && op!=116)){return .err(invalid(pc));}
    if(op==116 && (!w.output || !output_ir::canonical(p,pc) || (b==1 && (!live(w,a,f,bits) ||
        (w.result.kinds[a]!=1 && w.result.kinds[a]!=3))))){return .err(invalid(pc));}
    if(op==9 || op==64 || op==66 || op==78){let usize checked=arguments(w,unit,f,pc,bits)?;if(op==78){w.result.calls+=1;}}
    let bool definition=op==69 || op==74 || op==75 || op==76 || op==77 || (op==78 && unit.results[a]!=0);
    if(definition){
        if(dst>=16 || w.result.definitions[dst]!=pc || (bits&(one<<dst))!=0){return .err(invalid(pc));}
        if((op==74 || op==75 || op==76) && !live(w,a,f,bits)){return .err(invalid(pc));}
        if(op==76){let usize hi=p.code[at+4] as usize;
            if(b<p.register_starts[f] || b>=p.register_ends[f] || hi<p.register_starts[f] || hi>=p.register_ends[f] ||
                p.types[b]!=12 || p.types[hi]!=12 || p.slots[b] || p.slots[hi] ||
                unit.parameters[b]!=0 || unit.parameters[hi]!=0){return .err(invalid(pc));}}
        bits|=one<<dst;
    }else if(op==70){
        if(!live(w,dst,f,bits) || a!=0 || b!=0 || !reserved(p,at)){return .err(invalid(pc));}bits^=one<<dst;
    }else if(op==71 || op==72 || op==73){
        if(!live(w,a,f,bits) || (op!=73 && w.result.kinds[a]!=1 && w.result.kinds[a]!=3) ||
            (op==73 && (!live(w,b,f,bits) || w.result.kinds[a]==3 || w.result.kinds[b]==3)) ||
            (op==72 && b!=0) || !reserved(p,at)){return .err(invalid(pc));}
    }else if(op==79){
        if(dst!=0 || b!=0 || unit.results[f]==0 || !live(w,a,f,bits) || bits!=(one<<a) ||
            (w.result.kinds[a]!=unit.results[f] && !(unit.results[f]==3 && w.result.kinds[a]==1))){return .err(invalid(pc));}
        w.result.returns+=1;w.pc+=1;return .ok(0);
    }
    if(op==8 || op==39 || op==50 || op==65 || op==82){
        if(bits!=0 || unit.results[f]!=0){return .err(invalid(pc));}w.pc+=1;return .ok(0);
    }
    if(op==25){w.pc+=1;return .ok(0);}
    if(op==22){
        if(a<w.code || a>=pc || !w.seen[a] || w.states[a]!=bits){return .err(invalid(pc));}
        w.pc+=1;return .ok(0);
    }
    if(op==19 || op==20 || op==21 || op==24){
        let usize target=if(op==19){a}else if(op==24){p.code[at+4] as usize}else{b};
        if(target<=pc || target>=p.ends[f] || target<w.code){return .err(invalid(pc));}
        let usize linked=merge(w,target,bits,pc)?;
        if(op==19){w.pc+=1;return .ok(0);}
    }
    if(pc+1>=p.ends[f]){return .err(invalid(pc));}
    let usize linked=merge(w,pc+1,bits,pc)?;w.pc+=1;return .ok(0);
}
fn Result<usize,errors::Error> flow_step(ref mut State w,ref recipes::Program unit){
    let ref ir::Program p=ref unit.body;
    let usize checked=flow_function(w,unit)?;
    if(w.phase==7 && w.pc==p.ends[w.function]){w.function+=1;w.phase=6;
        if(w.function==p.function_count){w.phase=8;w.function=0;}}
    return .ok(0);
}

// Phase 7: one call-map row per stage. A fixed zero-call image completes in a
// single stage after the preceding definitions/flow proof.
fn Result<usize,errors::Error> coverage(ref mut State w,ref recipes::Program unit){
    let ref ir::Program p=ref unit.body;
    if(w.function==p.call_count){w.phase=9;w.function=0;w.pc=p.starts[0];w.round=0;w.changed=false;return .ok(0);}
    if(!w.calls[w.function]){return .err(invalid(0));}
    w.function+=1;
    if(w.function==p.call_count){w.phase=9;w.function=0;w.pc=p.starts[0];w.round=0;w.changed=false;}
    return .ok(0);
}
fn Result<u8,errors::Error> runtime_origin(ref recipes::Program unit,usize f,usize actual,usize pc){
    let ref ir::Program p=ref unit.body;
    if(actual<160 || actual>=176){return .err(invalid(pc));}
    let usize site=actual-160;
    let u8 element=switch(ir::slice_element(p,site,pc)){case .ok(v):{v}case .err(_):{return .err(invalid(pc));}};
    if(element!=10 || ir::exclusive(p,site)){return .err(invalid(pc));}
    if(p.slice_roots[site]!=0){return .ok(10);}
    let usize ancestor=p.slice_origins[site] as usize;
    if(ancestor==0 || ancestor>16){return .err(invalid(pc));}
    var u8 position=1;var usize i=0;
    while(i<p.arities[f]){
        if(p.slice_parameters[p.register_starts[f]+i] as usize==ancestor){return .ok(position);}
        if(position==255){return .err(invalid(pc));}
        position+=1;i+=1;
    }return .err(invalid(pc));
}

// Phase 8-10: one origin PC per stage, then one fixed round boundary. Site and
// result origins commit only after a candidate's complete raw checks.
fn Result<usize,errors::Error> origin_pc(ref mut State w,ref recipes::Program unit){
    let ref ir::Program p=ref unit.body;let usize f=w.function;let usize pc=w.pc;let usize at=pc*8;
    let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
    let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    if(op==69){w.result.site_origins[dst]=9;}
    else if(op==77){
        var u8 position=1;var usize r=p.register_starts[f];while(r<a){position+=1;r+=1;}
        w.result.site_origins[dst]=position;
    }else if(op==74 || op==75 || op==76){
        let u8 inherited=w.result.site_origins[a];w.result.site_origins[dst]=inherited;
    }else if(op==78 && unit.results[a]!=0){
        let u8 selected=w.result.result_origins[a];var u8 origin=0;
        if(selected==9){origin=9;}
        else if(selected!=0){
            let usize actual=p.call_args[b*8+selected as usize-1] as usize;
            if(actual>=192 && actual<208){let u8 copied=w.result.site_origins[actual-192];origin=copied;}
            else if(unit.results[a]==3){origin=runtime_origin(unit,f,actual,pc)?;}
            else{return .err(invalid(pc));}
        }
        w.result.site_origins[dst]=origin;
    }
    if(op==79){
        let u8 origin=w.result.site_origins[a];
        if(origin!=0){if(w.code!=0 && w.code!=origin as usize){return .err(invalid(pc));}w.code=origin as usize;}
    }
    w.pc+=1;return .ok(0);
}
fn Result<usize,errors::Error> origin_step(ref mut State w,ref recipes::Program unit){
    let ref ir::Program p=ref unit.body;
    if(w.phase==9){w.phase=10;w.function=0;w.pc=p.starts[0];w.code=0;return .ok(0);}
    if(w.phase==10){
        let usize checked=origin_pc(w,unit)?;
        if(w.pc==p.ends[w.function]){
            let usize f=w.function;
            if(w.code!=0){
                if(w.result.result_origins[f]!=0 && w.result.result_origins[f] as usize!=w.code){return .err(invalid(p.starts[f]));}
                if(w.result.result_origins[f]==0){let u8 committed=switch(encoded_origin(w.code)){case .ok(v):{v}case .err(_):{return .err(invalid(p.starts[f]));}};
                    w.result.result_origins[f]=committed;w.changed=true;}
            }
            w.function+=1;w.code=0;
            if(w.function==p.function_count){w.phase=11;w.function=0;}
        }
        return .ok(0);
    }
    if(w.phase==11){
        w.round+=1;
        if(!w.changed || w.round>=16){w.phase=12;w.function=0;}
        else{w.changed=false;w.phase=10;w.function=0;w.pc=p.starts[0];w.code=0;}
        return .ok(0);
    }
    return .err(invalid(0));
}
fn Result<usize,errors::Error> final_rows(ref mut State w,ref recipes::Program unit){
    let ref ir::Program p=ref unit.body;let usize f=w.function;
    if(f==p.function_count){w.result.rounds=w.round;w.phase=14;w.active=false;w.done=true;return .ok(0);}
    if(w.result.result_origins[f]!=unit.origins[f]){return .err(invalid(p.starts[f]));}
    w.pc=p.starts[f];w.phase=13;return .ok(0);
}
fn Result<usize,errors::Error> final_returns(ref mut State w,ref recipes::Program unit){
    let ref ir::Program p=ref unit.body;let usize f=w.function;
    if(w.pc==p.ends[f]){w.function+=1;w.phase=12;return .ok(0);}
    if(p.code[w.pc*8]==79 && w.result.site_origins[p.code[w.pc*8+2] as usize]!=w.result.result_origins[f]){return .err(invalid(w.pc));}
    w.pc+=1;return .ok(0);
}

pub fn Result<bool,errors::Error> advance(ref mut State w,ref recipes::Program unit,ref images::Image image,
    ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(meter.last!=0){return .ok(false);}
    if(!w.active || !same_pair(w,unit,image)){w.active=false;return .err(invalid(0));}
    if(w.phase==0){let Result<usize,errors::Error> opened=opening(w,unit,meter);
        switch(opened){case .ok(_):{return .ok(w.done);}case .err(e):{w.active=false;return .err(e);}}}
    if(w.phase==3){let bool image_done=switch(image_work::advance(image,ref mut w.image,meter)){
            case .ok(v):{v}case .err(_):{w.active=false;return .err(invalid(0));}
        };if(image_done){w.phase=4;w.function=0;w.pc=unit.body.starts[0];w.code=0;w.registers=0;}
        return .ok(false);}
    if(!budget::admit(meter,4096,0)?){return .ok(false);}
    w.work+=1;
    let Result<usize,errors::Error> checked=if(w.phase==1){header(w,unit)}
        else if(w.phase==2){header_finish(w,unit)}
        else if(w.phase==4){definition(w,unit,image)}
        else if(w.phase==5){definitions_finish(w,unit)}
        else if(w.phase==6 || w.phase==7){flow_step(w,unit)}
        else if(w.phase==8){coverage(w,unit)}
        else if(w.phase==9 || w.phase==10 || w.phase==11){origin_step(w,unit)}
        else if(w.phase==12){final_rows(w,unit)}
        else if(w.phase==13){final_returns(w,unit)}
        else{.err(invalid(0))};
    switch(checked){case .ok(_):{}case .err(e):{w.active=false;return .err(e);}};
    return .ok(w.done);
}
pub fn Result<recipes::Proof,errors::Error> prepared(ref State w){
    if(w.active || !w.done || w.phase!=14){return .err(invalid(0));}return .ok(w.result);
}
