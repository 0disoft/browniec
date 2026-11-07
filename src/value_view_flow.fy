module value_view_flow;
import value_ir as values;
import ir as ir;
import errors as errors;

// Independent origin sets, never guest encodings: low bits0..15 identify local
// Buffer slots, bits16..23 identify formal argument ordinals. Zero is Dead.
// Endpoints remain checked runtime scalar values; ranges/aliases inherit the
// authenticated origin. No source binding metadata participates in this proof.
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
fn usize bit(usize id){let usize one=1;return one<<id;}
fn bool empty(ref usize[] origins){
    var usize i=0;while(i<16){if(origins[i]!=0){return false;}i+=1;}return true;
}
fn Result<usize,errors::Error> unpinned(ref usize[] origins,usize owner,usize pc){
    var usize i=0;while(i<16){if((origins[i]&bit(owner))!=0){return .err(invalid(pc));}i+=1;}
    return .ok(owner);
}
// A descriptor must be live on every incoming edge or dead on every edge.
// Only its candidate roots widen. Check all live sets before publishing a union.
fn Result<usize,errors::Error> merge(ref mut usize[] states,ref mut bool[] seen,
    ref mut bool[] pending,usize target,ref usize[] origins,usize start,usize end,usize pc,bool back){
    if(target<start || target>=end || (back && !seen[target])){return .err(invalid(pc));}
    var usize i=0;while(i<16){
        if(seen[target] && (states[target*16+i]==0)!=(origins[i]==0)){return .err(invalid(pc));}i+=1;
    }
    var bool changed=!seen[target];i=0;while(i<16){
        let usize joined=states[target*16+i]|origins[i];
        if(joined!=states[target*16+i]){changed=true;states[target*16+i]=joined;}i+=1;
    }
    seen[target]=true;if(changed){pending[target]=true;}return .ok(target);
}
fn Result<usize,errors::Error> function(ref values::Program unit,ref values::Prepared proof,usize f){
    let ref ir::Program p=ref unit.body;let usize start=p.starts[f];let usize end=p.ends[f];
    // 32KiB states plus bounded worklist flags; no recursion/native stack override.
    var usize[4096] states=[0;4096];var bool[256] seen=[false;256];
    var bool[256] pending=[false;256];seen[start]=true;pending[start]=true;
    var usize arg=0;
    while(arg<p.arities[f]){let usize formal=unit.parameters[p.register_starts[f]+arg] as usize;
        if(formal>=17){states[start*16+formal-17]=bit(16+arg);}arg+=1;
    }
    // Ascending pending-PC worklist, repeated after a backedge widens an input.
    // Each PC is discovered once and can gain at most16*24 origin bits. Every
    // changed successor is queued, including an already processed forward PC.
    var usize steps=0;var bool again=true;var usize pc=start;
    while(again){again=false;pc=start;
    while(pc<end){if(!pending[pc]){pc+=1;continue;}pending[pc]=false;again=true;
        steps+=1;if(steps>98560){return .err(invalid(pc));} // 256*(1+16*24)
        let usize at=pc*8;let u8 op=p.code[at];
        let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;
        let usize b=p.code[at+3] as usize;
        var usize[16] origins=[0;16];var usize i=0;
        while(i<16){origins[i]=states[pc*16+i];i+=1;}
        if(op==105){
            if(origins[dst]!=0){return .err(invalid(pc));}
            // Shape and Buffer liveness were proved by value_ir/value_flow.
            origins[dst]=bit(a);
        }else if(op==106 || op==107 || op==108){
            if(origins[dst]!=0 || origins[a]==0){return .err(invalid(pc));}
            origins[dst]=origins[a];if(op==108){origins[a]=0;}
        }else if(op==109){
            if(origins[dst]==0){return .err(invalid(pc));}origins[dst]=0;
        }else if(op==112){
            if(origins[b]==0){return .err(invalid(pc));}
            let usize checked=unpinned(ref origins,a,pc)?;
        }else if(op==110 || op==111){
            if(origins[a]==0){return .err(invalid(pc));}
        }else if(op==88 || op==89 || op==90 || op==101 || op==102 || op==103 || op==104){
            let usize owner=if(op==90 || op==101){dst}else{a};
            let usize checked=unpinned(ref origins,owner,pc)?;
        }else if(op==91){
            if(values::payload(unit,dst,b,pc)?!=0 && !values::copyable(unit,proof,a)){
                let usize checked=unpinned(ref origins,a,pc)?;
            }
        }else if(op==92){
            if(!values::copyable(unit,proof,a)){let usize checked=unpinned(ref origins,a,pc)?;}
            let usize checked=merge(ref mut states,ref mut seen,ref mut pending,p.code[at+4] as usize,
                ref origins,start,end,pc,false)?;
        }else if(op==9 || op==93 || op==114){
            // Validate against the complete pre-call state. In particular an
            // owning move cannot bypass a pin by preceding its view actual.
            i=0;while(i<p.call_arities[b] as usize){let usize actual=p.call_args[b*8+i] as usize;
                if(actual>=224 && actual<240){if(origins[actual-224]==0){return .err(invalid(pc));}}
                else if(actual>=208 && actual<224){let usize checked=unpinned(ref origins,actual-208,pc)?;}i+=1;
            }
            if(op==114){
                if(origins[dst]!=0){return .err(invalid(pc));}
                let usize selected=(unit.results[a] as usize)-17;
                let usize actual=(p.call_args[b*8+selected] as usize)-224;
                if(origins[actual]==0){return .err(invalid(pc));}origins[dst]=origins[actual];
            }
        }else if(op==113){
            if(origins[a]!=bit(16+(unit.results[f] as usize)-17)){return .err(invalid(pc));}
            i=0;while(i<16){if(i!=a && origins[i]!=0){return .err(invalid(pc));}i+=1;}
            pc+=1;continue;
        }
        if(op==8 || op==39 || op==50 || op==82 || op==94){
            if(!empty(ref origins)){return .err(invalid(pc));}pc+=1;continue;
        }
        if(op==25){pc+=1;continue;} // Native failure cleanup closes all leases.
        if(op==22){if(a>=pc){return .err(invalid(pc));}let usize checked=merge(ref mut states,ref mut seen,ref mut pending,a,ref origins,start,end,pc,true)?;
            pc+=1;continue;
        }
        if(op==19 || op==20 || op==21 || op==24){
            let usize target=if(op==19){a}else if(op==24){p.code[at+4] as usize}else{b};
            if(target<=pc){return .err(invalid(pc));}
            let usize checked=merge(ref mut states,ref mut seen,ref mut pending,target,ref origins,start,end,pc,false)?;
            if(op==19){pc+=1;continue;}
        }
        let usize checked=merge(ref mut states,ref mut seen,ref mut pending,pc+1,ref origins,start,end,pc,false)?;pc+=1;
    }}
    // Canonical code cannot hide unreachable instructions behind a valid path.
    pc=start;while(pc<end){if(!seen[pc]){return .err(invalid(pc));}pc+=1;}
    return .ok(end-start);
}
pub fn Result<usize,errors::Error> inspect(ref values::Program unit,ref values::Prepared proof){
    // Guest bytes name slots/ordinals, never masks. Validate every extended
    // encoding before following edges, including unreachable malformed sites.
    var usize check_f=0;while(check_f<unit.body.function_count){var check_pc=unit.body.starts[check_f];
        while(check_pc<unit.body.ends[check_f]){let u8 op=unit.body.code[check_pc*8];
            if(values::operation(op)){let usize checked=values::instruction(unit,proof,check_pc,check_f)?;}
            else if(op==9){let usize checked=values::call(unit,proof,check_pc,check_f)?;}check_pc+=1;
        }check_f+=1;
    }
    // No-view programs retain their previous verifier stack path.
    var usize f=0;while(f<unit.body.function_count){var usize pc=unit.body.starts[f];var bool needed=false;
        var usize arg=0;while(arg<unit.body.arities[f]){
            if(unit.parameters[unit.body.register_starts[f]+arg]>=17){needed=true;}arg+=1;
        }
        while(pc<unit.body.ends[f]){let usize at=pc*8;let u8 op=unit.body.code[at];
            if(op>=105 && op<=114){needed=true;break;}
            if(op==9 || op==93){let usize map=unit.body.code[at+3] as usize;arg=0;
                while(arg<unit.body.call_arities[map] as usize){
                    if(unit.body.call_args[map*8+arg]>=224){needed=true;}arg+=1;
                }
            }pc+=1;
        }
        if(needed){let usize checked=function(unit,proof,f)?;}f+=1;
    }
    return .ok(unit.body.count);
}
