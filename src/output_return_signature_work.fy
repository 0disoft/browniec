module output_return_signature_work;
import static_call_ir as images;
import output_return_ir as recipes;
import metadata_budget as budget;
import ir as ir;
import types as types;
import errors as errors;

// Staged analysis of the immutable recipe image. The caller keeps the exact
// Program alive and unchanged from begin through completion. This metadata is
// not executable authority and is not a substitute for output_return_proof.
// Each admitted advance visits at most sixteen function/PC positions or logical
// forwarding edges and allocates nothing. A short allowance is a deferral and
// leaves both the cursor and the result untouched.
pub struct State {
    recipes::Signature output;
    bool[16] used;
    usize pinned_count; usize pinned_functions; usize pinned_entry; usize work;
    u8 phase; usize function; usize pc; usize round;
    bool changed; bool borrowed; bool active; bool done;
}
pub fn State empty(){return State{.output=recipes::empty(),.used=[false;16],
    .pinned_count=0,.pinned_functions=0,.pinned_entry=0,.work=0,
    .phase=0,.function=0,.pc=0,.round=0,.changed=false,.borrowed=false,
    .active=false,.done=false};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}

// Begin stores only shape values needed to reject an accidental substitution.
// The exact Program, image and input stay pinned by the owning continuation.
pub fn Result<usize,errors::Error> begin(ref mut State w,ref images::Program unit){
    if(w.active){return .err(invalid(0));}
    w.output=recipes::empty();w.used=[false;16];w.pinned_count=unit.body.count;
    w.pinned_functions=unit.body.function_count;w.pinned_entry=unit.body.entry;
    w.work=0;w.phase=0;w.function=0;w.pc=0;w.round=0;w.changed=false;w.borrowed=false;
    w.active=true;w.done=false;return .ok(0);
}
fn bool same_program(ref State w,ref images::Program unit){
    return w.pinned_count==unit.body.count && w.pinned_functions==unit.body.function_count &&
        w.pinned_entry==unit.body.entry;
}
fn Result<usize,errors::Error> header(ref mut State w,ref images::Program unit){
    let ref ir::Program p=ref unit.body;
    if(p.count==0 || p.count>256 || p.function_count==0 || p.function_count>16 ||
        p.entry>=p.function_count){return .err(invalid(0));}
    w.phase=1;w.function=0;w.pc=p.starts[0];return .ok(0);
}

// This pass preserves the raw oracle's function-major, PC-major diagnostics.
// One loop iteration examines one instruction; at most sixteen iterations run.
fn Result<usize,errors::Error> scan(ref mut State w,ref images::Program unit){
    let ref ir::Program p=ref unit.body;
    var usize steps=0;
    while(steps<16 && w.function<p.function_count){
        let usize f=w.function;let usize start=p.starts[f];let usize end=p.ends[f];
        if(w.pc==start && (start>=end || end>p.count)){return .err(invalid(0));}
        let usize pc=w.pc;let usize at=pc*8;let u8 op=p.code[at];
        if(op==63 || op==64 || op==65){w.used[f]=true;w.borrowed=true;w.output.borrowed=true;}
        if(op==63){
            let usize site=p.code[at+2] as usize;
            if(site>=16){return .err(invalid(pc));}
            let u8 tag=p.slice_elements[site];
            if(!types::scalar(tag&127) || (w.output.elements[f]!=0 && w.output.elements[f]!=tag)){
                return .err(invalid(pc));
            }
            w.output.elements[f]=tag;
        }
        if(op==64 && p.code[at+2] as usize>=p.function_count){return .err(invalid(pc));}
        w.work+=1;steps+=1;w.pc+=1;
        if(w.pc==end){w.function+=1;
            if(w.function<p.function_count){w.pc=p.starts[w.function];}
        }
    }
    if(w.function==p.function_count){
        if(w.borrowed){
            w.phase=2;w.function=0;w.pc=p.starts[0];w.round=0;w.changed=false;
        }else{
            w.phase=3;w.function=0;w.done=true;w.active=false;
        }
    }
    return .ok(0);
}

// Forwarding uses the raw oracle's Gauss-Seidel order and stopping rule. A
// round boundary costs no code position; every counted unit is one PC edge.
fn Result<usize,errors::Error> forwarding(ref mut State w,ref images::Program unit){
    let ref ir::Program p=ref unit.body;
    var usize steps=0;
    while(steps<16 && w.phase==2){
        if(w.function==p.function_count){
            w.round+=1;
            if(w.round>=16 || !w.changed){
                w.phase=3;w.function=0;
            }else{
                w.changed=false;w.function=0;w.pc=p.starts[0];
            }
            continue;
        }
        let usize f=w.function;let usize pc=w.pc;let usize at=pc*8;
        if(p.code[at]==64){
            let usize target=p.code[at+2] as usize;let u8 tag=w.output.elements[target];
            if(!w.used[target] ||
                (tag!=0 && w.output.elements[f]!=0 && tag!=w.output.elements[f])){
                return .err(invalid(pc));
            }
            if(tag!=0 && w.output.elements[f]==0){w.output.elements[f]=tag;w.changed=true;}
        }
        w.work+=1;steps+=1;w.pc+=1;
        if(w.pc==p.ends[f]){w.function+=1;
            if(w.function<p.function_count){w.pc=p.starts[w.function];}
        }
    }
    // A batch can end exactly at the last function. Settle that round here so
    // the next admission never spends its full charge on a boundary-only visit.
    if(w.phase==2 && w.function==p.function_count){
        w.round+=1;
        if(w.round>=16 || !w.changed){w.phase=3;w.function=0;}
        else{w.changed=false;w.function=0;w.pc=p.starts[0];}
    }
    return .ok(0);
}

// The final pass examines at most sixteen function rows in numeric order. It
// checks before committing the selected one-based input position.
fn Result<usize,errors::Error> finalize(ref mut State w,ref images::Program unit){
    let ref ir::Program p=ref unit.body;
    var usize steps=0;
    while(steps<16 && w.function<16){
        let usize f=w.function;
        if(w.used[f]){
            let u8 selected=unit.origins[f];
            if(f==p.entry || w.output.elements[f]==0 || selected==0 || selected>8 ||
                selected as usize>p.arities[f] || unit.results[f]!=0 || p.return_types[f]!=12){
                return .err(invalid(p.starts[f]));
            }
            w.output.parameters[f]=selected;
        }
        w.work+=1;steps+=1;w.function+=1;
    }
    if(w.function==16){w.done=true;w.active=false;}
    return .ok(0);
}

// A nonempty meter is refused before any read or write. The full 4096-unit
// charge is then followed immediately by this state's bounded work, never by
// an atomic rescan or a banked credit redeemed for a later large operation.
pub fn Result<bool,errors::Error> advance(ref mut State w,ref images::Program unit,
    ref mut budget::State allowance){
    if(w.done){return .ok(true);}
    if(!w.active || w.phase>3 || !same_program(w,unit)){return .err(invalid(0));}
    if(allowance.last!=0){return .ok(false);}
    if(!budget::admit(allowance,4096,0)?){return .ok(false);}
    let Result<usize,errors::Error> result=if(w.phase==0){header(w,unit)}
        else if(w.phase==1){scan(w,unit)}
        else if(w.phase==2){forwarding(w,unit)}else{finalize(w,unit)};
    switch(result){case .ok(_):{}case .err(e):{w.active=false;return .err(e);}};
    return .ok(w.done);
}
