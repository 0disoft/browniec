module struct_scan_work;
import struct_source as raw;
import struct_layout as layouts;
import struct_layout_work as planning;
import record_fields_work as fields;
import declaration_skip_work as declarations;
import source_state_work as states;
import source_context_check_work as checking;
import source_context as context;
import lexer as lexer;
import lexer_work as tokens;
import locals as locals;
import errors as errors;
import metadata_budget as budget;

// Preserve the raw two passes: validate every declaration before resolving any
// field type, then validate all layouts. Private candidates are never authority.
pub struct State { raw::Table result; fields::State fields; declarations::State declaration;
    states::State state; checking::State check; planning::State layout; tokens::State scan;
    lexer::State token; lexer::State saved; usize record; usize row; usize spelling; usize width;
    usize compared; usize visits; u8 mode; u8 phase; u8 resume;
    bool waiting; bool skipping; bool new_record; bool resolving; bool planning; bool done; }
fn raw::Table blank(){return raw::Table{.context=context::empty(),.layouts=layouts::empty(),.begins=[0;32],.ends=[0;32],.bodies=[0;32]};}
fn State seed(u8 mode){return State{.result=blank(),.fields=fields::begin(0),.declaration=declarations::structure(lexer::empty()),
    .state=states::begin(0),.check=checking::empty(),.layout=planning::empty(),.scan=tokens::begin(lexer::empty()),
    .token=lexer::empty(),.saved=lexer::empty(),.record=0,.row=0,.spelling=0,.width=0,.compared=0,.visits=0,
    .mode=mode,.phase=0,.resume=0,.waiting=false,.skipping=false,.new_record=false,.resolving=false,.planning=false,.done=false};}
pub fn State single(){return seed(0);}
pub fn State scoped(){return seed(1);}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn bool name(ref u8[] source,ref lexer::State s){return s.kind==2 && !locals::reserved(source[s.begin..s.end]);}
fn void next(ref mut State w,u8 phase){let lexer::State current=w.token;w.scan=tokens::begin(current);w.waiting=true;w.resume=phase;}
fn errors::Error layout_error(ref State w,layouts::Error e){
    let u8 kind=switch(e){case .Depth:{4}case .Overflow:{4}case .Quota:{4}case .Limit:{4}
        case .Fields:{3}case .Type:{3}case .Metadata:{3}case .Cycle:{3}};
    let usize at=if(w.mode==0){w.result.begins[0]}else if(w.layout.phase>=2){w.result.begins[w.layout.root]}else{0};
    return errors::make(kind,at);
}
pub fn Result<raw::Table,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,0));}return .ok(w.result);
}
fn Result<bool,errors::Error> child(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.waiting){let Result<bool,errors::Error> result=tokens::advance(source,ref mut w.scan,meter);
        w.token=tokens::observed(ref w.scan);switch(result){case .ok(done):{if(done){w.waiting=false;w.phase=w.resume;}}
            case .err(e):{return .err(e);}};return .ok(false);}
    if(w.skipping){let Result<bool,errors::Error> result=declarations::advance(source,ref mut w.declaration,meter);
        w.token=declarations::observed(ref w.declaration);let bool done=result?;
        if(done){if(w.mode==0){if(w.new_record){w.result.layouts.count+=1;}w.phase=4;}
            else{w.record+=1;w.phase=10;}w.skipping=false;}return .ok(false);}
    if(w.resolving){var fields::State frame=w.fields;
        let Result<bool,errors::Error> result=fields::advance(source,ref mut w.result,ref mut frame,meter);w.fields=frame;
        let bool done=result?;if(done){w.record+=1;w.resolving=false;w.phase=20;}return .ok(false);}
    if(w.planning){let layouts::Catalog catalog=w.result.layouts;
        switch(planning::advance(ref mut w.layout,ref catalog,meter)){
            case .ok(done):{if(done){w.done=true;}return .ok(done);}
            case .err(e):{return .err(layout_error(w,e));}};}
    return .err(errors::make(5,0));
}
fn Result<bool,errors::Error> metadata(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(!budget::admit(meter,4096,w.token.begin)?){return .ok(false);}
    if(w.phase==5){if(!name(source,ref w.token)){return .err(errors::make(2,w.token.begin));}
        w.row=0;w.phase=15;return .ok(false);}
    if(w.phase==15){if(w.row==w.result.layouts.count){w.phase=6;return .ok(false);}
        let usize a=w.result.begins[w.row];let usize b=w.result.ends[w.row];
        if(b-a!=w.token.end-w.token.begin){w.row+=1;return .ok(false);}
        w.spelling=a;w.width=b-a;w.compared=0;w.phase=16;return .ok(false);}
    if(w.phase==16){var usize stop=w.compared+64;if(stop>w.width){stop=w.width;}
        while(w.compared<stop){w.visits+=1;if(source[w.token.begin+w.compared]!=source[w.spelling+w.compared]){
                w.row+=1;w.phase=15;return .ok(false);}w.compared+=1;}
        if(w.compared==w.width){return .err(errors::make(3,w.token.begin));}return .ok(false);}
    if(w.phase==6){let usize id=if(w.mode==0){w.result.layouts.count}else{w.record};let usize a=w.token.begin;let usize b=w.token.end;
        w.result.begins[id]=a;w.result.ends[id]=b;next(w,7);return .ok(false);}
    if(w.phase==7){if(w.token.kind!=123){return .err(errors::make(2,w.token.begin));}
        if(w.mode==1){w.saved=w.token;}next(w,8);return .ok(false);}
    if(w.phase==8){let usize id=if(w.mode==0){w.result.layouts.count}else{w.record};let usize at=w.token.begin;w.result.bodies[id]=at;
        let lexer::State saved=w.saved;
        w.declaration=if(w.mode==0){declarations::structure(saved)}else{declarations::members(saved)};
        w.new_record=true;w.skipping=true;return .ok(false);}
    if(w.phase==20){if(w.record==w.result.layouts.count){
            switch(planning::begin(ref mut w.layout,18446744073709551615)){case .ok(_):{}case .err(e):{return .err(layout_error(w,e));}};
            w.planning=true;return .ok(false);}
        w.fields=fields::begin(w.record);w.resolving=true;return .ok(false);}
    return .err(errors::make(5,w.token.begin));
}
pub fn Result<bool,errors::Error> advance_single(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}if(w.mode!=0){return .err(errors::make(5,0));}
    if(w.waiting || w.skipping || w.resolving || w.planning){return child(source,w,meter);}
    if(w.phase>=5){return metadata(source,w,meter);}
    if(!budget::admit(meter,4096,w.token.begin)?){return .ok(false);}
    if(w.phase==0){if(source.len>4096){return .err(errors::make(4,4096));}next(w,1);return .ok(false);}
    if(w.phase==1){if(!word(source,ref w.token,b"module")){return .err(errors::make(2,w.token.begin));}next(w,2);return .ok(false);}
    if(w.phase==2){if(!word(source,ref w.token,b"main")){return .err(errors::make(2,w.token.begin));}next(w,3);return .ok(false);}
    if(w.phase==3){if(w.token.kind!=59){return .err(errors::make(2,w.token.begin));}next(w,4);return .ok(false);}
    if(w.phase==4){if(w.token.kind==0){w.record=0;w.phase=20;return .ok(false);}
        if(word(source,ref w.token,b"struct")){if(w.result.layouts.count>=32){return .err(errors::make(4,w.token.begin));}
            w.saved=w.token;next(w,5);}
        else{let lexer::State current=w.token;w.declaration=declarations::function(current);w.new_record=false;w.skipping=true;}
        return .ok(false);}
    return .err(errors::make(5,w.token.begin));
}
pub fn Result<bool,errors::Error> advance_scoped(ref u8[] source,ref context::Table scope,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}if(w.mode!=1){return .err(errors::make(5,0));}
    if(w.waiting || w.skipping || w.resolving || w.planning){return child(source,w,meter);}
    if(w.phase==0){let bool done=checking::advance(source,scope,ref mut w.check,meter)?;
        if(done){if(!w.check.result){return .err(errors::make(5,0));}w.result.context=*scope;w.result.layouts.count=scope.record_count;w.phase=10;}
        return .ok(false);}
    if(w.phase==11){let bool done=states::advance(source,scope,ref mut w.state,meter)?;
        if(done){w.token=states::prepared(ref w.state)?;next(w,12);}return .ok(false);}
    if(w.phase==12){if(!budget::admit(meter,4096,w.token.begin)?){return .ok(false);}
        if(!name(source,ref w.token)){return .err(errors::make(2,w.token.begin));}w.phase=6;return .ok(false);}
    if(w.phase==10){if(!budget::admit(meter,4096,0)?){return .ok(false);}
        if(w.record==scope.record_count){w.record=0;w.phase=20;return .ok(false);}
        let usize at=context::begin(scope.records[w.record]);w.state=states::begin(at);w.phase=11;return .ok(false);}
    return metadata(source,w,meter);
}
// Owning synchronous drains. The Table remains private until all layout checks.
pub fn Result<raw::Table,errors::Error> scan_single(ref u8[] source){
    var State w=single();var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,0)?;let bool done=advance_single(source,ref mut w,ref mut meter)?;}
    return prepared(ref w);
}
pub fn Result<raw::Table,errors::Error> scan_scoped(ref u8[] source,ref context::Table scope){
    var State w=scoped();var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,0)?;let bool done=advance_scoped(source,scope,ref mut w,ref mut meter)?;}
    return prepared(ref w);
}
