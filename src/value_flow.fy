module value_flow;
import value_ir as values;
import ir as ir;
import errors as errors;

// Independent definitely/possibly initialized planes over the canonical CFG.
// Only exact Buffer nodes may be uncertain at forward joins. Scalar definitions,
// ordinary owners/loans/places and CALL depth still require verifier.
struct State { usize definite; usize possible; }
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
fn usize bit(usize id){let usize one=1;return one<<id;}
fn bool live(usize bits,usize id){return (bits&bit(id))!=0;}
fn Result<State,errors::Error> publish(State bits,usize dst,usize pc){
    if(live(bits.possible,dst)){return .err(invalid(pc));}
    return .ok(State{.definite=bits.definite|bit(dst),.possible=bits.possible|bit(dst)});
}
fn Result<State,errors::Error> consume(State bits,usize source,usize pc){
    if(!live(bits.definite,source)){return .err(invalid(pc));}
    return .ok(State{.definite=bits.definite^bit(source),.possible=bits.possible^bit(source)});
}
fn Result<State,errors::Error> arguments(ref values::Program unit,ref values::Prepared proof,
    usize pc,usize f,State bits,ref bool[] used){
    let ref ir::Program p=ref unit.body;let usize at=pc*8;let usize target=p.code[at+2] as usize;
    let usize map=p.code[at+3] as usize;
    let usize checked=values::call(unit,proof,pc,f)?;
    if(used[map]){return .err(invalid(pc));}
    // Stage every owning move locally. A later bad argument or occupied result
    // must not mutate either owner plane or mark the CALL map as used.
    var State next=bits;var usize i=0;while(i<8){let usize actual=p.call_args[map*8+i] as usize;
        if(i<p.arities[target]){let usize formal=unit.parameters[p.register_starts[target]+i] as usize;
            if(formal!=0 && formal<=16){
                if(actual<208 || actual>=224 || !values::slot(unit,actual-208,f) ||
                    !values::same(unit,proof,actual-208,formal-1) || !live(next.definite,actual-208)){return .err(invalid(pc));}
                if(!values::copyable(unit,proof,actual-208)){next=consume(next,actual-208,pc)?;}
            }else if(formal>=17){
                // The separate view CFG authenticates shared actuals.
                if(actual<224 || actual>=240){return .err(invalid(pc));}
            }else if(actual>=208){return .err(invalid(pc));}
        }else if(actual!=0){return .err(invalid(pc));}i+=1;
    }
    return .ok(next);
}
fn Result<usize,errors::Error> merge(ref mut usize[] definite,ref mut usize[] possible,
    ref mut bool[] seen,usize target,State bits,usize buffers,usize start,usize end,usize pc,bool back){
    if(target<start || target>=end || (back && !seen[target])){return .err(invalid(pc));}
    if(back){
        // No owner loop inference: both header planes must be restored exactly.
        if(definite[target]!=bits.definite || possible[target]!=bits.possible){return .err(invalid(pc));}
    }else{
        let usize must=if(seen[target]){definite[target]&bits.definite}else{bits.definite};
        let usize may=if(seen[target]){possible[target]|bits.possible}else{bits.possible};
        let usize uncertain=may^must;
        if((uncertain&buffers)!=uncertain){return .err(invalid(pc));}
        definite[target]=must;possible[target]=may;seen[target]=true;
    }return .ok(target);
}
fn Result<usize,errors::Error> function(ref values::Program unit,ref values::Prepared proof,
    usize f,ref mut bool[] used){
    let ref ir::Program p=ref unit.body;let usize start=p.starts[f];let usize end=p.ends[f];
    var usize[256] definite=[0;256];var usize[256] possible=[0;256];
    var bool[256] seen=[false;256];var usize initial=0;var usize buffers=0;var usize i=0;
    while(i<16){if(values::slot(unit,i,f) && unit.catalog.nodes[values::type_id(unit,i)].kind==4){buffers|=bit(i);}i+=1;}i=0;
    while(i<p.arities[f]){let usize value=unit.parameters[p.register_starts[f]+i] as usize;
        if(value!=0 && value<=16){initial|=bit(value-1);}i+=1;}
    definite[start]=initial;possible[start]=initial;seen[start]=true;var usize pc=start;
    while(pc<end){let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
        let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
        if(values::operation(op)){let usize checked=values::instruction(unit,proof,pc,f)?;}
        if(!seen[pc]){return .err(invalid(pc));}var State bits=State{.definite=definite[pc],.possible=possible[pc]};
        if(op==9 || op==93 || op==114){bits=arguments(unit,proof,pc,f,bits,used)?;
            if(unit.results[a]!=0 && unit.results[a]<=16){bits=publish(bits,dst,pc)?;}
            used[b]=true;
        }else if(op==88 || op==89){
            if(!live(bits.definite,a)){return .err(invalid(pc));}
            let State fresh=publish(bits,dst,pc)?;bits=if(op==88){consume(fresh,a,pc)?}else{fresh};
        }else if(op==90){bits=consume(bits,dst,pc)?;}
        else if(op==115){
            // Clearing either physical case establishes definite Dead.
            if(live(bits.definite,dst)){bits.definite^=bit(dst);}
            if(live(bits.possible,dst)){bits.possible^=bit(dst);}
        }
        else if(op==91){let usize child=values::payload(unit,dst,b,pc)?;
            let State fresh=publish(bits,dst,pc)?;bits=fresh;
            if(child!=0){if(!live(bits.definite,a)){return .err(invalid(pc));}
                if(!values::copyable(unit,proof,a)){bits=consume(bits,a,pc)?;}}
        }else if(op==92){
            if(!live(bits.definite,a)){return .err(invalid(pc));}
            let usize mismatch=merge(ref mut definite,ref mut possible,ref mut seen,p.code[at+4] as usize,bits,buffers,start,end,pc,false)?;
            if(!values::copyable(unit,proof,a)){bits=consume(bits,a,pc)?;}
            if(values::payload(unit,a,b,pc)?!=0){bits=publish(bits,dst,pc)?;}
        }else if(op==94){
            if(bits.definite!=bit(a) || bits.possible!=bit(a)){return .err(invalid(pc));}pc+=1;continue;
        }else if(op==113){
            if(bits.possible!=0){return .err(invalid(pc));}pc+=1;continue;
        }else if(op==95 || op==97){bits=publish(bits,dst,pc)?;}
        else if(op==96 || op==98 || op==99 || op==100 || op==105){if(!live(bits.definite,a)){return .err(invalid(pc));}}
        else if(op==101){if(!live(bits.definite,dst)){return .err(invalid(pc));}}
        else if((op>=102 && op<=104) || op==112){
            if(!live(bits.definite,a) || (op==104 && (a==b || !live(bits.definite,b)))){return .err(invalid(pc));}
            bits=publish(bits,dst,pc)?;
        }
        if(op==8 || op==39 || op==50 || op==82){
            if(bits.possible!=0 || unit.results[f]!=0){return .err(invalid(pc));}pc+=1;continue;
        }
        if(op==25){pc+=1;continue;} // Failure drains runtime ledgers, not guest drops.
        if(op==22){if(a>=pc){return .err(invalid(pc));}
            let usize checked=merge(ref mut definite,ref mut possible,ref mut seen,a,bits,buffers,start,end,pc,true)?;pc+=1;continue;}
        if(op==19 || op==20 || op==21 || op==24){
            let usize target=if(op==19){a}else if(op==24){p.code[at+4] as usize}else{b};
            if(target<=pc){return .err(invalid(pc));}
            let usize checked=merge(ref mut definite,ref mut possible,ref mut seen,target,bits,buffers,start,end,pc,false)?;
            if(op==19){pc+=1;continue;}
        }
        let usize checked=merge(ref mut definite,ref mut possible,ref mut seen,pc+1,bits,buffers,start,end,pc,false)?;pc+=1;
    }return .ok(end-start);
}
pub fn Result<usize,errors::Error> inspect(ref values::Program unit,ref values::Prepared proof){
    // Validate every extended instruction and call descriptor before following
    // any edge. Unreachable code cannot hide malformed reserved bytes or maps.
    var usize f=0;while(f<unit.body.function_count){var usize pc=unit.body.starts[f];
        while(pc<unit.body.ends[f]){let u8 op=unit.body.code[pc*8];
            if(values::operation(op)){let usize checked=values::instruction(unit,proof,pc,f)?;}
            else if(op==9){let usize checked=values::call(unit,proof,pc,f)?;}pc+=1;
        }f+=1;
    }
    var bool[32] used=[false;32];f=0;
    while(f<unit.body.function_count){let usize checked=function(unit,proof,f,ref mut used)?;f+=1;}
    var usize i=0;while(i<unit.body.call_count){if(!used[i]){return .err(invalid(0));}i+=1;}
    return .ok(unit.body.count);
}
