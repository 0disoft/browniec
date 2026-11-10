module output_normalize_work;
import static_call_ir as programs;
import output_return_ir as returns;
import slice_result_call_ir as calls;
import ir as ir;
import errors as errors;
import metadata_budget as budget;

// Mutate only the private, completely copied candidate. Original recipes stay
// immutable. One stage visits one PC/function row; CALL_BIND may inspect a
// <=256-PC binding and mark <=256 interior entries in the same fresh stage.
pub struct State { bool[256] interior; usize pc; usize function; usize rewritten; u8 phase; bool done; }
pub fn State empty(){return State{.interior=[false;256],.pc=0,.function=0,.rewritten=0,.phase=0,.done=false};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
pub fn Result<bool,errors::Error> advance(ref mut programs::Program unit,ref returns::Signature signature,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(!budget::admit(meter,4096,w.pc)?){return .ok(false);}
    if(w.phase==0){
        if(unit.body.count>256 || unit.body.function_count>16){return .err(invalid(0));}
        w.phase=1;return .ok(false);
    }
    let usize pc=w.pc;
    if(w.phase==1){
        if(pc==unit.body.count){w.phase=2;w.function=0;return .ok(false);}
        let usize at=pc*8;
        if(unit.body.code[at]==66){let usize end=calls::binding(ref unit.body,pc)?;
            if(unit.body.code[at+7]!=0 || unit.body.code[end*8+1]!=unit.body.code[at+5] ||
                unit.body.code[end*8+2]!=unit.body.code[at+6]){return .err(invalid(pc));}
            var usize i=pc+1;while(i<=end){if(w.interior[i]){return .err(invalid(i));}w.interior[i]=true;i+=1;}
            w.rewritten+=1;
        }w.pc+=1;return .ok(false);
    }
    if(w.phase==2){let usize f=w.function;
        if(f==unit.body.function_count){w.phase=3;w.pc=0;return .ok(false);}
        if(unit.body.starts[f]<unit.body.count && w.interior[unit.body.starts[f]]){return .err(invalid(unit.body.starts[f]));}
        w.function+=1;return .ok(false);
    }
    if(w.phase==3){
        if(pc==unit.body.count){w.phase=4;w.pc=0;return .ok(false);}
        let usize at=pc*8;let u8 op=unit.body.code[at];
        if((op==67 || op==68) && !w.interior[pc]){return .err(invalid(pc));}
        let usize target=if(op==19 || op==22){unit.body.code[at+2] as usize}else if(op==20 || op==21){unit.body.code[at+3] as usize}
            else if(op==24){unit.body.code[at+4] as usize}else{256};
        if(target<unit.body.count && w.interior[target]){return .err(invalid(pc));}
        if(op==66){unit.body.code[at]=9;unit.body.code[at+4]=0;unit.body.code[at+5]=0;unit.body.code[at+6]=0;}
        else if(op==67){let usize site=unit.body.code[at+1] as usize;if(site>=16){return .err(invalid(pc));}
            let u8 rewritten=if(ir::exclusive(ref unit.body,site)){61}else{59};unit.body.code[at]=rewritten;
        }else if(op==68){unit.body.code[at]=62;}
        w.pc+=1;return .ok(false);
    }
    if(w.phase==4){
        if(pc==unit.body.count){w.phase=5;w.function=0;return .ok(false);}
        let usize at=pc*8;let u8 op=unit.body.code[at];
        if(op==63){unit.body.code[at]=57;}else if(op==64){unit.body.code[at]=9;}else if(op==65){unit.body.code[at]=8;}
        w.pc+=1;return .ok(false);
    }
    if(w.phase==5){let usize f=w.function;
        if(f==16){w.done=true;return .ok(true);}
        if(signature.elements[f]!=0){unit.origins[f]=0;}w.function+=1;return .ok(false);
    }
    return .err(invalid(pc));
}
