module slice_result_source_origins;
import functions as functions;
import errors as errors;
import runtime_clock as clock;
import slice_result_origin_walk as walk;

// Advisory summary fixed point only; execution still requires independent IR proof.
pub fn Result<usize,errors::Error> infer(ref u8[] source,ref mut functions::Table t){
    return infer_until(source,t,0);
}

pub fn Result<usize,errors::Error> infer_until(ref u8[] source,ref mut functions::Table t,usize deadline){
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    if(t.count==0 || t.count>16){return .err(errors::make(3,0));}
    t.return_slice_inputs=[0;16];
    var usize checked=0;while(checked<t.count){
        if(t.arities[checked]>8 || t.bodies[checked]>t.body_ends[checked] || t.body_ends[checked]>source.len){return .err(errors::make(3,0));}checked+=1;
    }
    var usize rounds=0;
    while(rounds<17){rounds+=1;var bool changed=false;var usize unresolved=16;var usize f=0;
        while(f<t.count){if(t.return_slice_elements[f]!=0){
            if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
            let u8 found=walk::body(source,t,ref t.return_slice_inputs,f)?;
            if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
            if(found==0){if(unresolved==16){unresolved=f;}}
            else if(t.return_slice_inputs[f]!=0 && t.return_slice_inputs[f]!=found){return .err(errors::make(3,t.begins[f]));}
            else if(t.return_slice_inputs[f]==0){t.return_slice_inputs[f]=found;changed=true;}
        }f+=1;}
        if(!changed){if(unresolved<16){return .err(errors::make(3,t.begins[unresolved]));}return .ok(rounds);}
    }return .err(errors::make(3,0));
}
