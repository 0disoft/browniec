module output_borrowed_origins_work;

import ir as ir;
import functions as functions;
import slice_result_origins as origins;
import types as types;
import errors as errors;
import metadata_budget as budget;

// Resumable mirror of slice_result_origins::inspect_output_admitted. The
// owning parent pins the already verified normalized Program, its signature
// Table and the original immutable recipe Program. This pass performs no
// verifier or raw-origin analysis and publishes analysis metadata only.
pub struct State {
    pub origins::Summary result;
    usize program_count;
    usize function_count;
    usize signature_count;
    usize signature_entry;
    usize recipe_count;
    usize recipe_pc;
    usize function;
    usize pc;
    usize return_pc;
    usize definition_pc;
    usize origin_site;
    usize origin_steps;
    usize origin_scan;
    usize recipe_back;
    usize returns;
    u8 selected;
    u8 identity;
    u8 phase;
    bool bindings;
    bool pending;
    bool changed;
    bool function_started;
    bool active;
    bool done;
    pub usize work;
}

pub fn State empty(){
    return State{
        .result=origins::Summary{.parameters=[0;16],.rounds=0},
        .program_count=0,.function_count=0,.signature_count=0,.signature_entry=0,
        .recipe_count=0,.recipe_pc=0,.function=0,.pc=0,.return_pc=0,
        .definition_pc=0,.origin_site=0,.origin_steps=0,.origin_scan=0,
        .recipe_back=0,.returns=0,.selected=0,.identity=0,.phase=0,
        .bindings=false,.pending=false,.changed=false,.function_started=false,
        .active=false,.done=false,.work=0};
}

// Start or restart one independent inspection. No Program is retained. The
// same State can be reused after a completed or failed inspection.
pub fn Result<usize,errors::Error> begin(ref mut State w,ref ir::Program p,
    ref functions::Table t,ref ir::Program recipes){
    if(w.active){return .err(invalid(0));}
    let State fresh=empty();*w=fresh;w.active=true;
    return .ok(0);
}

fn errors::Error invalid(usize at){return errors::make(5,at);}
fn u8 formal(usize position){
    return if(position==0){1}else if(position==1){2}else if(position==2){3}
        else if(position==3){4}else if(position==4){5}else if(position==5){6}
        else if(position==6){7}else{8};
}
fn bool same_shape(ref State w,ref ir::Program p,ref functions::Table t,ref ir::Program recipes){
    return w.program_count==p.count && w.function_count==p.function_count &&
        w.recipe_count==recipes.count;
}

fn Result<bool,errors::Error> resolved(ref mut State w,ref ir::Program p,u8 found){
    let usize pc=w.return_pc;w.returns+=1;
    if(found==0){w.pending=true;}
    else if(w.selected!=0 && w.selected!=found){return .err(invalid(p.offsets[pc]));}
    else{w.selected=found;}
    w.pc=pc+1;w.phase=4;return .ok(false);
}

fn Result<bool,errors::Error> origin_step(ref mut State w,ref ir::Program p,
    ref functions::Table t,ref ir::Program recipes,ref mut usize visits){
    let usize f=w.function;let usize site=w.origin_site;let usize at=p.offsets[w.return_pc];
    if(!w.bindings){
        *visits=*visits+1;
        if(site>=16 || p.slice_roots[site]!=0 || p.slice_functions[site] as usize!=f+1 ||
            p.slice_elements[site]!=t.return_slice_elements[f]){return .err(invalid(at));}
        let usize anchor=p.slice_origins[site] as usize;
        if(anchor==0 || anchor>16){return .err(invalid(at));}
        var usize i=0;
        while(i<p.arities[f]){
            let usize r=p.register_starts[f]+i;
            if(p.slice_parameters[r] as usize==anchor){return resolved(w,p,formal(i));}
            i+=1;
        }
        return .err(invalid(at));
    }
    if(w.origin_steps>=16){return .err(invalid(at));}
    w.origin_steps+=1;*visits=*visits+1;
    if(site>=16 || p.slice_roots[site]!=0 || p.slice_functions[site] as usize!=f+1 ||
        p.slice_elements[site]!=t.return_slice_elements[f]){return .err(invalid(at));}
    var usize i=0;
    while(i<p.arities[f]){
        let usize r=p.register_starts[f]+i;
        if(p.slice_parameters[r] as usize==site+1){return resolved(w,p,formal(i));}
        i+=1;
    }
    w.definition_pc=256;w.origin_scan=p.starts[f];w.phase=7;return .ok(false);
}

fn Result<bool,errors::Error> step(ref mut State w,ref ir::Program p,
    ref functions::Table t,ref ir::Program recipes,ref mut usize visits){
    if(w.phase==1){
        while(w.recipe_pc<p.count && *visits<16){
            if(recipes.code[w.recipe_pc*8]==66){w.bindings=true;}
            w.recipe_pc+=1;*visits=*visits+1;
        }
        if(w.recipe_pc==p.count){w.phase=2;}
        return .ok(false);
    }
    if(w.phase==2){
        if(w.signature_count!=p.function_count || w.signature_entry!=p.entry){return .err(invalid(0));}
        if(w.function<t.count){
            let usize f=w.function;
            if(t.arities[f]!=p.arities[f]){return .err(invalid(0));}
            if(t.return_slice_elements[f]!=0 &&
                (!types::scalar(t.return_slice_elements[f]&127) || p.return_types[f]!=12 ||
                p.array_results[f]!=0 || p.record_results[f]!=0)){return .err(invalid(0));}
            w.function+=1;
        }
        if(w.function==t.count){w.function=0;w.phase=3;}
        return .ok(false);
    }
    if(w.phase==3){
        if(w.result.rounds>=17){return .err(invalid(0));}
        w.result.rounds+=1;w.changed=false;w.pending=false;
        w.function=0;w.function_started=false;w.phase=4;return .ok(false);
    }
    if(w.phase==4){
        if(w.function==t.count){
            if(!w.changed){if(w.pending){return .err(invalid(0));}
                w.active=false;w.done=true;return .ok(true);}
            w.phase=3;w.function=0;return .ok(false);
        }
        let usize f=w.function;
        if(t.return_slice_elements[f]==0){w.function+=1;w.function_started=false;return .ok(false);}
        if(!w.function_started){
            w.pc=p.starts[f];w.selected=w.result.parameters[f];w.returns=0;
            w.function_started=true;
        }
        if(w.pc>=p.ends[f]){
            if(w.returns==0){return .err(invalid(t.begins[f]));}
            let u8 chosen=w.selected;
            if(chosen!=0 && w.result.parameters[f]==0){
                w.result.parameters[f]=chosen;w.changed=true;
            }
            w.function+=1;w.function_started=false;return .ok(false);
        }
        let usize pc=w.pc;*visits=*visits+1;
        if(p.code[pc*8]==8){
            w.return_pc=pc;w.identity=p.code[pc*8+2];w.definition_pc=p.starts[f];
            w.origin_site=256;w.phase=5;
        }else{w.pc+=1;}
        return .ok(false);
    }
    if(w.phase==5){
        let usize f=w.function;let usize stop=w.return_pc;let usize at=p.offsets[stop];
        if(w.definition_pc<stop){
            let usize candidate=w.definition_pc;let u8 op=p.code[candidate*8];*visits=*visits+1;
            if((op==57 || op==9) && p.code[candidate*8+1]==w.identity){
                if(w.origin_site!=256){return .err(invalid(at));}
                w.origin_site=candidate;
            }
            w.definition_pc+=1;return .ok(false);
        }
        if(w.origin_site==256){return .err(invalid(at));}
        let usize definition=w.origin_site;let usize code=definition*8;
        if(p.code[code]==57){
            w.origin_site=p.code[code+2] as usize;w.origin_steps=0;w.phase=6;return .ok(false);
        }
        let usize target=p.code[code+2] as usize;
        if(t.return_slice_elements[target]!=t.return_slice_elements[f]){return .err(invalid(at));}
        let u8 selected=w.result.parameters[target];
        if(selected==0){return resolved(w,p,0);}
        if(selected as usize>p.arities[target]){return .err(invalid(at));}
        let usize call=p.code[code+3] as usize;
        let usize actual=p.call_args[call*8+selected as usize-1] as usize;
        if(actual<160 || actual>=176){return .err(invalid(at));}
        w.origin_site=actual-160;w.origin_steps=0;w.phase=6;return .ok(false);
    }
    if(w.phase==6){return origin_step(w,p,t,recipes,visits);}
    if(w.phase==7){
        let usize f=w.function;let usize at=p.offsets[w.return_pc];
        if(w.origin_scan<p.ends[f]){
            let usize pc=w.origin_scan;let u8 op=p.code[pc*8];*visits=*visits+1;
            if((op==59 || op==61) && p.code[pc*8+1] as usize==w.origin_site){
                if(w.definition_pc!=256){return .err(invalid(at));}
                w.definition_pc=pc;
            }
            w.origin_scan+=1;return .ok(false);
        }
        if(w.definition_pc==256){return .err(invalid(at));}
        if(recipes.code[w.definition_pc*8]==67){
            w.recipe_back=w.definition_pc;w.phase=8;return .ok(false);
        }
        w.origin_site=p.code[w.definition_pc*8+2] as usize;w.phase=6;return .ok(false);
    }
    if(w.phase==8){
        let usize f=w.function;let usize at=p.offsets[w.return_pc];
        if(w.recipe_back>p.starts[f] && recipes.code[w.recipe_back*8]!=66){
            w.recipe_back-=1;*visits=*visits+1;return .ok(false);
        }
        if(recipes.code[w.recipe_back*8]!=66){return .err(invalid(at));}
        let usize target=p.code[w.recipe_back*8+2] as usize;
        let u8 selected=w.result.parameters[target];
        if(selected==0){return resolved(w,p,0);}
        if(selected as usize>p.arities[target]){return .err(invalid(at));}
        let usize map=p.code[w.recipe_back*8+3] as usize;
        let usize actual=p.call_args[map*8+selected as usize-1] as usize;
        if(actual<160 || actual>=176){return .err(invalid(at));}
        w.origin_site=actual-160;w.phase=6;return .ok(false);
    }
    return .err(invalid(0));
}

pub fn Result<bool,errors::Error> advance(ref ir::Program p,ref functions::Table t,
    ref ir::Program recipes,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(meter.last!=0){return .ok(false);}
    let bool admitted=budget::admit(meter,4096,0)?;
    if(!admitted){return .ok(false);}
    if(w.phase==0){
        if(recipes.count!=p.count){w.active=false;return .err(invalid(0));}
        w.program_count=p.count;w.function_count=p.function_count;
        w.signature_count=t.count;w.signature_entry=t.entry;w.recipe_count=recipes.count;
        w.recipe_pc=0;w.function=0;w.pc=0;w.return_pc=0;w.definition_pc=0;
        w.origin_site=0;w.origin_steps=0;w.origin_scan=0;w.recipe_back=0;
        w.returns=0;w.selected=0;w.identity=0;w.bindings=false;
        w.pending=false;w.changed=false;w.function_started=false;
        w.result=origins::Summary{.parameters=[0;16],.rounds=0};
        w.phase=1;
    }else if(!same_shape(w,p,t,recipes)){w.active=false;return .err(invalid(0));}
    else if(w.phase>=2 && (w.signature_count!=t.count || w.signature_entry!=t.entry)){
        w.active=false;return .err(invalid(0));
    }
    var usize visits=0;
    while(visits<16){
        let Result<bool,errors::Error> progressed=step(w,p,t,recipes,ref mut visits);
        switch(progressed){
            case .ok(done):{if(done){w.work+=visits;return .ok(true);}}
            case .err(e):{w.work+=visits;w.active=false;return .err(e);}
        };
    }
    w.work+=visits;return .ok(false);
}
