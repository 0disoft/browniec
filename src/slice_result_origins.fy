module slice_result_origins;
import ir as ir;
import functions as functions;
import verifier as verifier;
import errors as errors;
import types as types;

// Input positions are one-based, zero means no grounded result summary. These
// source-analysis facts contain no runtime ticket, view, owner or executable IR.
pub struct Summary { u8[16] parameters; usize rounds; }

fn Result<u8,errors::Error> origin(ref ir::Program p,ref functions::Table t,
    usize f,usize site,usize at){
    if(site>=16 || p.slice_roots[site]!=0 || p.slice_functions[site] as usize!=f+1 ||
        p.slice_elements[site]!=t.return_slice_elements[f]){return .err(errors::make(5,at));}
    let usize anchor=p.slice_origins[site] as usize;
    if(anchor==0 || anchor>16){return .err(errors::make(5,at));}
    var usize i=0;
    while(i<p.arities[f]){
        let usize r=p.register_starts[f]+i;
        if(p.slice_parameters[r] as usize==anchor){
            return .ok(if(i==0){1}else if(i==1){2}else if(i==2){3}else if(i==3){4}
                else if(i==4){5}else if(i==5){6}else if(i==6){7}else{8});
        }
        i+=1;
    }
    return .err(errors::make(5,at));
}

fn Result<u8,errors::Error> returned(ref ir::Program p,ref functions::Table t,
    ref Summary summaries,usize f,usize pc){
    let usize r=p.code[pc*8+2] as usize;
    var usize definition=256;var usize at=p.starts[f];
    while(at<pc){
        if((p.code[at*8]==57 || p.code[at*8]==9) && p.code[at*8+1] as usize==r){
            if(definition!=256){return .err(errors::make(5,p.offsets[pc]));}
            definition=at;
        }
        at+=1;
    }
    if(definition==256){return .err(errors::make(5,p.offsets[pc]));}
    at=definition*8;
    if(p.code[at]==57){return origin(p,t,f,p.code[at+2] as usize,p.offsets[pc]);}
    let usize target=p.code[at+2] as usize;
    if(t.return_slice_elements[target]!=t.return_slice_elements[f]){return .err(errors::make(5,p.offsets[pc]));}
    let usize selected=summaries.parameters[target] as usize;
    if(selected==0){return .ok(0);}
    if(selected>p.arities[target]){return .err(errors::make(5,p.offsets[pc]));}
    let usize call=p.code[at+3] as usize;
    let usize actual=p.call_args[call*8+selected-1] as usize;
    if(actual<160 || actual>=176){return .err(errors::make(5,p.offsets[pc]));}
    return origin(p,t,f,actual-160,p.offsets[pc]);
}

// Reuse independent CFG/type/loan proof before indexing or trusting definitions.
// Every emitted return must agree, conservatively including constant branches.
pub fn Result<Summary,errors::Error> inspect(ref ir::Program p,ref functions::Table t){
    let usize valid=verifier::verify(p)?;
    if(t.count!=p.function_count || t.entry!=p.entry){return .err(errors::make(5,0));}
    var usize f=0;
    while(f<t.count){
        if(t.arities[f]!=p.arities[f]){return .err(errors::make(5,0));}
        if(t.return_slice_elements[f]!=0 && (!types::scalar(t.return_slice_elements[f] & 127) ||
            p.return_types[f]!=12 || p.array_results[f]!=0 || p.record_results[f]!=0)){
            return .err(errors::make(5,0));
        }
        f+=1;
    }
    var Summary result=Summary{.parameters=[0;16],.rounds=0};
    while(result.rounds<17){
        result.rounds+=1;var bool changed=false;var bool pending=false;f=0;
        while(f<t.count){
            if(t.return_slice_elements[f]!=0){
                var u8 selected=result.parameters[f];var usize returns=0;var usize pc=p.starts[f];
                while(pc<p.ends[f]){
                    if(p.code[pc*8]==8){
                        returns+=1;let u8 found=returned(p,t,ref result,f,pc)?;
                        if(found==0){pending=true;}
                        else if(selected!=0 && selected!=found){return .err(errors::make(5,p.offsets[pc]));}
                        else{selected=found;}
                    }
                    pc+=1;
                }
                if(returns==0){return .err(errors::make(5,t.begins[f]));}
                if(selected!=0 && result.parameters[f]==0){result.parameters[f]=selected;changed=true;}
            }
            f+=1;
        }
        if(!changed){if(pending){return .err(errors::make(5,0));}return .ok(result);}
    }
    return .err(errors::make(5,0));
}
