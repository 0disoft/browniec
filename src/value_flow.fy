module value_flow;
import value_ir as values;
import ir as ir;
import errors as errors;

// Independent initialized/Dead plane over the actual canonical CFG. Scalar
// definitions, ordinary owners/loans/places and CALL depth still require verifier.
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
fn usize bit(usize id){let usize one=1;return one<<id;}
fn bool live(usize bits,usize id){return (bits&bit(id))!=0;}
fn Result<usize,errors::Error> publish(usize bits,usize dst,usize pc){
    if(live(bits,dst)){return .err(invalid(pc));}return .ok(bits|bit(dst));
}
fn Result<usize,errors::Error> consume(usize bits,usize source,usize pc){
    if(!live(bits,source)){return .err(invalid(pc));}return .ok(bits^bit(source));
}
fn bool extended(ref values::Program unit,usize target){
    let ref ir::Program p=ref unit.body;if(unit.results[target]!=0){return true;}
    var usize i=0;while(i<p.arities[target]){if(unit.parameters[p.register_starts[target]+i]!=0){return true;}i+=1;}
    return false;
}
fn Result<usize,errors::Error> arguments(ref values::Program unit,ref values::Prepared proof,
    usize pc,usize f,usize bits,ref mut bool[] used){
    let ref ir::Program p=ref unit.body;let usize at=pc*8;let usize target=p.code[at+2] as usize;
    let usize map=p.code[at+3] as usize;
    if(target>=p.function_count || map>=p.call_count || used[map] || p.call_arities[map] as usize!=p.arities[target] ||
        (p.code[at]==93)!=extended(unit,target)){return .err(invalid(pc));}
    var usize next=bits;var usize i=0;while(i<8){let usize actual=p.call_args[map*8+i] as usize;
        if(i<p.arities[target]){let usize formal=unit.parameters[p.register_starts[target]+i] as usize;
            if(formal!=0){
                if(actual<208 || actual>=224 || !values::slot(unit,actual-208,f) ||
                    !values::same(unit,proof,actual-208,formal-1) || !live(next,actual-208)){return .err(invalid(pc));}
                if(!values::copyable(unit,proof,actual-208)){next=consume(next,actual-208,pc)?;}
            }else if(actual>=208){return .err(invalid(pc));}
        }else if(actual!=0){return .err(invalid(pc));}i+=1;
    }
    used[map]=true;return .ok(next);
}
fn Result<usize,errors::Error> merge(ref mut usize[] states,ref mut bool[] seen,
    usize target,usize bits,usize start,usize end,usize pc,bool back){
    if(target<start || target>=end || (back && !seen[target]) ||
        (seen[target] && states[target]!=bits)){return .err(invalid(pc));}
    if(!back){states[target]=bits;seen[target]=true;}return .ok(bits);
}
fn Result<usize,errors::Error> function(ref values::Program unit,ref values::Prepared proof,
    usize f,ref mut bool[] used){
    let ref ir::Program p=ref unit.body;let usize start=p.starts[f];let usize end=p.ends[f];
    var usize[256] states=[0;256];var bool[256] seen=[false;256];var usize initial=0;var usize i=0;
    while(i<p.arities[f]){let usize value=unit.parameters[p.register_starts[f]+i] as usize;
        if(value!=0){initial|=bit(value-1);}i+=1;}
    states[start]=initial;seen[start]=true;var usize pc=start;
    while(pc<end){let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
        let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
        if(values::operation(op)){let usize checked=values::instruction(unit,proof,pc,f)?;}
        if(!seen[pc]){return .err(invalid(pc));}var usize bits=states[pc];
        if(op==9 || op==93){bits=arguments(unit,proof,pc,f,bits,used)?;
            if(unit.results[a]!=0){bits=publish(bits,dst,pc)?;}
        }else if(op==88 || op==89){
            if(!live(bits,a)){return .err(invalid(pc));}
            let usize fresh=publish(bits,dst,pc)?;bits=if(op==88){consume(fresh,a,pc)?}else{fresh};
        }else if(op==90){bits=consume(bits,dst,pc)?;}
        else if(op==91){let usize child=values::payload(unit,dst,b,pc)?;
            let usize fresh=publish(bits,dst,pc)?;bits=fresh;
            if(child!=0){if(!live(bits,a)){return .err(invalid(pc));}
                if(!values::copyable(unit,proof,a)){bits=consume(bits,a,pc)?;}}
        }else if(op==92){
            if(!live(bits,a)){return .err(invalid(pc));}
            let usize mismatch=merge(ref mut states,ref mut seen,p.code[at+4] as usize,bits,start,end,pc,false)?;
            if(!values::copyable(unit,proof,a)){bits=consume(bits,a,pc)?;}
            if(values::payload(unit,a,b,pc)?!=0){bits=publish(bits,dst,pc)?;}
        }else if(op==94){
            if(bits!=bit(a)){return .err(invalid(pc));}pc+=1;continue;
        }else if(op==95 || op==97){bits=publish(bits,dst,pc)?;}
        else if(op==96 || op==98 || op==99 || op==100 || op==105){if(!live(bits,a)){return .err(invalid(pc));}}
        else if(op==101){if(!live(bits,dst)){return .err(invalid(pc));}}
        else if((op>=102 && op<=104) || op==112){
            if(!live(bits,a) || (op==104 && (a==b || !live(bits,b)))){return .err(invalid(pc));}
            bits=publish(bits,dst,pc)?;
        }
        if(op==8 || op==39 || op==50 || op==82){
            if(bits!=0 || unit.results[f]!=0){return .err(invalid(pc));}pc+=1;continue;
        }
        if(op==25){pc+=1;continue;} // Failure drains runtime ledgers, not guest drops.
        if(op==22){if(a>=pc){return .err(invalid(pc));}
            let usize checked=merge(ref mut states,ref mut seen,a,bits,start,end,pc,true)?;pc+=1;continue;}
        if(op==19 || op==20 || op==21 || op==24){
            let usize target=if(op==19){a}else if(op==24){p.code[at+4] as usize}else{b};
            if(target<=pc){return .err(invalid(pc));}
            let usize checked=merge(ref mut states,ref mut seen,target,bits,start,end,pc,false)?;
            if(op==19){pc+=1;continue;}
        }
        let usize checked=merge(ref mut states,ref mut seen,pc+1,bits,start,end,pc,false)?;pc+=1;
    }return .ok(end-start);
}
pub fn Result<usize,errors::Error> inspect(ref values::Program unit,ref values::Prepared proof){
    var bool[32] used=[false;32];var usize f=0;
    while(f<unit.body.function_count){let usize checked=function(unit,proof,f,ref mut used)?;f+=1;}
    var usize i=0;while(i<unit.body.call_count){if(!used[i]){return .err(invalid(0));}i+=1;}
    return .ok(unit.body.count);
}
