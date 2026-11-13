module slice_capture_source_work;
import lexer as lexer;
import lexer_work as tokens;
import locals as locals;
import ir as ir;
import array_source as arrays;
import slice_source as slices;
import slice_builders as builders;
import slice_reborrow_ir as reborrow;
import types as types;
import errors as errors;
import metadata_budget as budget;
// 0 named capture, 2 acquire a completed endpoint pair.
// Lookup visits one row or <=64 spelling bytes; token work has its own bound.
pub struct State { tokens::State token; usize at; usize row;
    usize compared; usize begin; usize end; usize spelling; usize width;
    usize root; usize parent; usize site; usize lo; usize hi; usize value;
    u8 encoded; u8 mode; u8 phase; bool exclusive; bool waiting; bool done; }
pub fn State begin(lexer::State s,u8 mode,u8 encoded,usize at){
    return State{.token=tokens::begin(s),.at=at,.row=0,.compared=0,
        .begin=s.begin,.end=s.end,.spelling=0,.width=0,.root=16,.parent=16,.site=16,
        .lo=0,.hi=0,.value=0,.encoded=encoded,.mode=mode,.phase=if(mode==2){30}else{0},
        .exclusive=(encoded&128)!=0,.waiting=false,.done=false};
}
fn void next(ref mut State w,lexer::State s,u8 phase){w.token=tokens::begin(s);w.waiting=true;w.phase=phase;}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){switch(tokens::advance(source,ref mut w.token,meter)){
        case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}
        case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.waiting=false;}return .ok(false);}};}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}
    if(w.phase==0){if(s.kind!=2){return .err(errors::make(3,s.begin));}w.phase=1;return .ok(false);}
    if(w.phase==1){if(w.row==names.count){return .err(errors::make(3,s.begin));}
        let usize a=names.begins[w.row];let usize b=names.ends[w.row];
        if(b-a!=w.end-w.begin){w.row+=1;return .ok(false);}w.spelling=a;w.width=b-a;w.compared=0;w.phase=2;return .ok(false);}
    if(w.phase==2){var usize stop=w.compared+64;if(stop>w.width){stop=w.width;}
        while(w.compared<stop){if(source[w.begin+w.compared]!=source[w.spelling+w.compared]){w.row+=1;w.phase=1;return .ok(false);}w.compared+=1;}
        if(w.compared==w.width){w.phase=3;}return .ok(false);}
    if(w.phase==3){let usize index=w.row;let u8 element=w.encoded&127;
        if(arrays::binding(names,index)){
            if(names.count>=64){return .err(errors::make(4,w.at));}
            let usize root=names.registers[index]-128;
            if(w.exclusive && (!names.mutable[index] || !p.arrays.mutable[root])){return .err(errors::make(3,w.at));}
            if(!types::scalar(element) || root>=16 || root>=p.arrays.count || p.arrays.elements[root]!=element ||
                p.array_functions[root] as usize!=names.function){return .err(errors::make(3,s.begin));}
            w.root=root;next(w,*s,10);return .ok(false);}
        if(!slices::binding(names,index)){return .err(errors::make(3,s.begin));}
        let usize site=names.registers[index]-160;
        if(ir::exclusive(p,site)!=w.exclusive){return .err(errors::make(3,w.at));}
        let usize root=p.slice_roots[site] as usize;let usize origin=p.slice_origins[site] as usize;
        if(root!=0){if(root>16 || root>p.arrays.count || p.arrays.elements[root-1]!=element ||
            p.array_functions[root-1] as usize!=names.function || origin!=0 || p.slice_functions[site]!=0){return .err(errors::make(3,w.at));}}
        else{if(origin==0 || origin>16 || p.slice_functions[site] as usize!=names.function+1 ||
            p.slice_roots[origin-1]!=0 || p.slice_origins[origin-1] as usize!=origin ||
            p.slice_functions[origin-1]!=p.slice_functions[site]){return .err(errors::make(3,w.at));}}
        let u8 actual=ir::slice_element(p,site,w.at)?;if(actual!=element){return .err(errors::make(3,w.at));}
        w.site=site;next(w,*s,11);return .ok(false);}
    if(w.phase==10 || w.phase==11){if(s.kind==91){if(w.phase==11){w.parent=w.site;}w.done=true;return .ok(true);}
        if(s.kind!=44 && s.kind!=41){return .err(errors::make(3,s.begin));}
        if(w.phase==11){w.value=160+w.site;w.done=true;return .ok(true);}w.phase=12;return .ok(false);}
    if(w.phase==12){w.lo=ir::integer(p,0,12,w.at)?;w.phase=13;return .ok(false);}
    if(w.phase==13){w.hi=arrays::length_value(p,w.root,w.at)?;w.phase=30;return .ok(false);}
    if(w.phase==30){if(names.count>=64){return .err(errors::make(4,w.at));}
        let usize parent=w.parent;let usize root=if(parent<16){p.slice_roots[parent] as usize}else{0};
        w.site=if(parent==16){if(w.exclusive){ir::exclusive_slice(p,w.root,w.at)?}else{ir::slice(p,w.root,w.at)?}}
            else if(w.exclusive){reborrow::derived(p,parent,w.at)?}
            else if(p.slice_origins[parent]!=0){builders::derived(p,parent,names.function,w.at)?}
            else{ir::slice(p,root-1,w.at)?};w.phase=31;return .ok(false);}
    if(w.phase==31){let usize made=if(w.parent==16){ir::slice_open(p,w.site,w.lo,w.hi,w.at)?}
        else if(w.exclusive){reborrow::begin(p,w.site,w.parent,w.lo,w.hi,w.at)?}
        else{ir::slice_sub(p,w.site,w.parent,w.lo,w.hi,w.at)?};w.phase=32;return .ok(false);}
    if(w.phase==32){let usize anonymous=locals::declare(names,w.at,w.at,160+w.site,w.exclusive)?;
        w.value=160+w.site;w.root=16;w.parent=16;w.done=true;return .ok(true);}
    return .err(errors::make(5,w.at));
}
