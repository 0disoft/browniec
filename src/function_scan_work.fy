module function_scan_work;
import value_signature_work as value_signatures;
import value_properties as value_properties;
import functions as raw;
import signature_parse_work as signatures;
import declaration_skip_work as declarations;
import source_state_work as states;
import source_context_check_work as checking;
import source_context as context;
import module_index as modules;
import lexer as lexer;
import lexer_work as tokens;
import errors as errors;
import metadata_budget as budget;

// Complete untyped declaration/signature candidate. Source, scope and Index
// stay immutable; the private Table is available only after all checks pass.
pub struct State { raw::Table result; signatures::State signature; declarations::State declaration;
    states::State state; checking::State check; tokens::State scan; lexer::State token;
    usize row; usize selected; usize active; u8 mode; u8 phase; u8 resume;
    bool waiting; bool parsing; bool skipping; bool done; }
fn State seed(u8 mode,usize selected,bool returns){var raw::Table table=raw::empty();table.reference_returns=returns;
    return State{.result=table,.signature=signatures::begin(lexer::empty()),.declaration=declarations::structure(lexer::empty()),
        .state=states::begin(0),.check=checking::empty(),.scan=tokens::begin(lexer::empty()),.token=lexer::empty(),
        .row=0,.selected=selected,.active=0,.mode=mode,.phase=0,.resume=0,.waiting=false,.parsing=false,.skipping=false,.done=false};}
pub fn State single(bool returns){return seed(0,0,returns);}
pub fn State indexed(usize selected,bool returns){return seed(1,selected,returns);}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn void next(ref mut State w,u8 phase){let lexer::State current=w.token;w.scan=tokens::begin(current);w.resume=phase;w.waiting=true;}
pub fn Result<raw::Table,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,0));}return .ok(w.result);
}
fn Result<bool,errors::Error> child(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.waiting){let Result<bool,errors::Error> result=tokens::advance(source,ref mut w.scan,meter);
        w.token=tokens::observed(ref w.scan);
        switch(result){case .ok(done):{if(done){w.waiting=false;w.phase=w.resume;}}
            case .err(e):{return .err(e);}};return .ok(false);}
    if(w.skipping){let Result<bool,errors::Error> result=declarations::advance(source,ref mut w.declaration,meter);
        w.token=declarations::observed(ref w.declaration);let bool done=result?;
        if(done){w.skipping=false;w.phase=4;}return .ok(false);}
    // Fixed scratch framing bridges the compiler's sibling mutable-loan limit;
    // no source/table scan is replayed and no work credit is carried forward.
    if(w.parsing){var signatures::State frame=w.signature;
        let Result<bool,errors::Error> result=signatures::advance(source,ref mut w.result,ref mut frame,meter);w.signature=frame;
        w.token=signatures::observed(ref w.signature);let bool done=result?;
        if(done){if(w.mode!=1){w.phase=4;}else{
                let usize f=signatures::prepared(ref w.signature)?;let ref context::Table scope=ref w.result.context;
                if(f>=scope.function_count || w.result.begins[f]!=context::begin(scope.functions[f]) || w.result.ends[f]!=context::end(scope.functions[f])){
                    return .err(errors::make(5,w.active));}
                if(w.row==w.selected){w.result.entry=f;}w.row+=1;w.phase=10;
            }w.parsing=false;}return .ok(false);}
    return .err(errors::make(5,0));
}
pub fn Result<bool,errors::Error> advance_single(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.mode==1){return .err(errors::make(5,0));}
    if(w.waiting || w.parsing || w.skipping){return child(source,w,meter);}
    if(!budget::admit(meter,4096,w.token.begin)?){return .ok(false);}
    if(w.phase==0){next(w,1);return .ok(false);}
    if(w.phase==1){if(!word(source,ref w.token,b"module")){return .err(errors::make(2,w.token.begin));}next(w,2);return .ok(false);}
    if(w.phase==2){if(!word(source,ref w.token,b"main")){return .err(errors::make(2,w.token.begin));}next(w,3);return .ok(false);}
    if(w.phase==3){if(w.token.kind!=59){return .err(errors::make(2,w.token.begin));}next(w,4);return .ok(false);}
    if(w.phase==4){if(w.token.kind==0){if(w.mode==2){w.result.entry=eval_entry(source,ref w.result)?;}if(w.result.entry==16){return .err(errors::make(3,source.len));}w.done=true;return .ok(true);}
        let lexer::State current=w.token;
        if(word(source,ref w.token,b"struct")){w.declaration=declarations::structure(current);w.skipping=true;}
        else{w.signature=signatures::begin(current);w.parsing=true;}return .ok(false);}
    return .err(errors::make(5,w.token.begin));
}
pub fn Result<bool,errors::Error> advance_indexed(ref u8[] source,ref context::Table scope,ref modules::Index index,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.mode!=1){return .err(errors::make(5,0));}
    if(w.waiting || w.parsing){return child(source,w,meter);}
    if(w.phase==0){let bool done=checking::advance(source,scope,ref mut w.check,meter)?;
        if(done){if(!w.check.result){return .err(errors::make(5,0));}w.result.context=*scope;w.phase=10;}return .ok(false);}
    if(w.phase==11){let bool done=states::advance(source,scope,ref mut w.state,meter)?;
        if(done){w.token=states::prepared(ref w.state)?;next(w,12);}return .ok(false);}
    if(!budget::admit(meter,4096,w.active)?){return .ok(false);}
    if(w.phase==10){if(w.row==modules::symbol_count(index)){
            if(w.result.count!=scope.function_count || w.result.entry>=w.result.count){return .err(errors::make(5,0));}
            w.done=true;return .ok(true);}
        let modules::Symbol item=switch(modules::symbol(index,w.row)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,0));}};
        if(item.kind!=1){w.row+=1;return .ok(false);}
        let usize base=if(item.owner==0){0}else{scope.ends[item.owner-1] as usize};
        w.active=base+item.definition.start;w.state=states::begin(w.active);w.phase=11;return .ok(false);}
    if(w.phase==12){if(word(source,ref w.token,b"pub")){next(w,13);}else{w.phase=13;}return .ok(false);}
    if(w.phase==13){let lexer::State current=w.token;w.signature=signatures::begin(current);w.parsing=true;return .ok(false);}
    return .err(errors::make(5,w.active));
}
fn Result<usize,errors::Error> eval_entry(ref u8[] source,ref raw::Table table){
    var usize f=0;
    while(f<table.count){
        let usize at=table.begins[f];
        if(lexer::equal(source[at..table.ends[f]],b"evaluate")){
            if(table.arities[f]!=1 || table.param_types[f*8]!=1 || table.param_lengths[f*8]!=0 ||
                table.param_records[f*8]!=0 || table.param_slices[f*8] ||
                table.return_types[f]!=1 || table.return_lengths[f]!=0 || table.return_records[f]!=0 ||
                table.return_slice_elements[f]!=0){return .err(errors::make(3,at));}
            return .ok(f);
        }
        f+=1;
    }
    return .err(errors::make(3,source.len));
}
pub fn Result<raw::Table,errors::Error> scan_eval(ref u8[] source){
    var State w=seed(2,0,false);
    var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,0)?;let bool done=advance_single(source,ref mut w,ref mut meter)?;}
    return prepared(ref w);
}

// Owning compatibility adapters; no public Pending compiler protocol.
pub fn Result<raw::Table,errors::Error> scan_single(ref u8[] source,bool returns){
    return scan_from(source,0,returns,false);
}
pub fn Result<raw::Table,errors::Error> scan_host_from(ref u8[] source,usize start){
    return scan_from(source,start,false,true);
}
fn Result<raw::Table,errors::Error> scan_from(ref u8[] source,usize start,bool returns,bool host){
    var State w=single(returns);var budget::State meter=budget::empty();
    w.result.scalar_host_calls=host;
    if(start!=0){w.token.cursor=start;next(ref mut w,4);}
    while(!w.done){let usize allowance=budget::reset(ref mut meter,0)?;let bool done=advance_single(source,ref mut w,ref mut meter)?;}
    return prepared(ref w);
}
pub fn Result<raw::Table,errors::Error> scan_indexed(ref u8[] source,ref context::Table scope,ref modules::Index index,usize selected,bool returns){
    return scan_indexed_mode(source,scope,index,selected,returns,false);
}
pub fn Result<raw::Table,errors::Error> scan_host_indexed(ref u8[] source,ref context::Table scope,ref modules::Index index,usize selected){
    return scan_indexed_mode(source,scope,index,selected,false,true);
}
fn Result<raw::Table,errors::Error> scan_indexed_mode(ref u8[] source,ref context::Table scope,ref modules::Index index,
    usize selected,bool returns,bool host){
    var State w=indexed(selected,returns);var budget::State meter=budget::empty();
    w.result.scalar_host_calls=host;
    while(!w.done){let usize allowance=budget::reset(ref mut meter,0)?;let bool done=advance_indexed(source,scope,index,ref mut w,ref mut meter)?;}
    return prepared(ref w);
}

// Typed single-source declarations share the proven signature/table coordinator;
// only annotation preparation receives the separate private value catalog bank.
pub fn Result<bool,errors::Error> advance_values(ref u8[] source,ref mut value_properties::Catalog catalog,
    ref mut value_signatures::State value,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}if(w.mode!=0){return .err(errors::make(5,0));}
    if(w.parsing){var signatures::State frame=w.signature;
        let Result<bool,errors::Error> result=signatures::advance_values(source,ref mut w.result,catalog,value,ref mut frame,meter);w.signature=frame;
        w.token=signatures::observed(ref w.signature);let bool done=result?;if(done){w.parsing=false;w.phase=4;}return .ok(false);}
    return advance_single(source,w,meter);
}
