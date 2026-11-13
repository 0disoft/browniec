module aggregate_call_source_work;
import call_operand_work as calls;
import lexer as lexer;
import functions as functions;
import ir as ir;
import reference_call_source as references;
import metadata_budget as budget;
import errors as errors;
// Reuse the pinned CALL continuation without enlarging Pratt/Bank scratch.
// Requests 1/2 are scalar/capture children; 3 explicitly delegates returned-view
// dependency preparation. No one-unit charge is claimed for that legacy child.
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref functions::Table signatures,usize destination,ref mut calls::State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(w.phase!=6 && w.phase!=9){return calls::advance(source,s,p,signatures,w,meter);}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}
    if(w.phase==9){w.done=true;return .ok(true);}
    if(references::result(signatures,w.target) || destination==176){w.request=3;w.phase=9;return .ok(false);}
    w.pc=p.count;
    let usize value=if(destination<16){ir::array_call(p,w.target,destination,ref w.arguments[..w.arity],w.at)?}
        else if(destination>=144 && destination<160){ir::record_call(p,w.target,destination-144,ref w.arguments[..w.arity],w.at)?}
        else{ir::call(p,w.target,ref w.arguments[..w.arity],w.at)?};
    w.value=if(destination<16){128+destination}else if(destination>=144 && destination<160){destination}else{value};
    w.phase=7;return .ok(false);
}
