module record_fields_work;
import struct_source as raw;
import source_state_work as states;
import source_name_work as names;
import lexer as lexer;
import lexer_work as tokens;
import type_parse_work as primitives;
import locals as locals;
import types as types;
import std::num as num;
import errors as errors;
import metadata_budget as budget;

// One record in the owner's syntax-checked declaration candidate. Every record
// name has already passed the nonreserved-name check; source/table stay pinned.
// Unscoped primitive spellings cannot match those names. Scoped metadata may
// contain forged prefix spans; retain its raw lookup even for primitive words.
pub struct State { states::State state; names::State name; tokens::State scan; primitives::State primitive;
    lexer::State token; usize[16] begins; usize[16] ends; usize record; usize field; usize row;
    usize spelling; usize width; usize compared; usize visits; u8 phase; u8 resume; bool waiting; bool done; }
pub fn State begin(usize record){return State{.state=states::begin(0),.name=names::begin(0,0,true),
    .scan=tokens::begin(lexer::empty()),.primitive=primitives::begin(lexer::empty()),.token=lexer::empty(),
    .begins=[0;16],.ends=[0;16],.record=record,.field=0,.row=0,.spelling=0,.width=0,.compared=0,.visits=0,
    .phase=0,.resume=0,.waiting=false,.done=false};}
fn void next(ref mut State w,u8 phase){let lexer::State current=w.token;w.scan=tokens::begin(current);w.waiting=true;w.resume=phase;}
fn Result<u8,errors::Error> code(usize value,usize at){
    let i64 wide=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{return .err(errors::make(4,at));}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(4,at))}};
}
fn void primitive(ref mut State w){let lexer::State current=w.token;w.primitive=primitives::begin(current);w.phase=7;}
fn Result<bool,errors::Error> nominal(ref mut raw::Table table,ref mut State w,usize id){
    let usize slot=w.record*16+w.field;let u8 encoded=code(id,w.token.begin)?;
    table.layouts.kinds[slot]=1;table.layouts.types[slot]=encoded;next(w,9);return .ok(false);
}
pub fn Result<usize,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,w.token.begin));}return .ok(w.field);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut raw::Table table,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){let Result<bool,errors::Error> result=tokens::advance(source,ref mut w.scan,meter);
        w.token=tokens::observed(ref w.scan);switch(result){case .ok(done):{if(done){w.waiting=false;w.phase=w.resume;}}
            case .err(e):{return .err(e);}};return .ok(false);}
    if(w.phase==1){let bool done=states::advance(source,ref table.context,ref mut w.state,meter)?;
        if(done){w.token=states::prepared(ref w.state)?;next(w,2);}return .ok(false);}
    if(w.phase==3){let bool done=names::advance(source,ref table.context,ref mut w.name,meter)?;
        if(done){let usize id=w.name.result;if(id<32 && id<table.layouts.count){return nominal(table,w,id);}primitive(w);}return .ok(false);}
    if(w.phase==7){let Result<bool,errors::Error> result=primitives::advance(source,ref mut w.primitive,meter);
        w.token=primitives::observed(ref w.primitive);let bool done=result?;
        if(done){let u8 tag=primitives::prepared(ref w.primitive)?;if(!types::scalar(tag)){return .err(errors::make(3,w.token.begin));}
            let usize slot=w.record*16+w.field;table.layouts.types[slot]=tag;w.phase=9;}return .ok(false);}
    if(!budget::admit(meter,4096,w.token.begin)?){return .ok(false);}
    if(w.phase==0){if(w.record>=32 || table.layouts.count>32 || w.record>=table.layouts.count){return .err(errors::make(5,0));}
        w.state=states::begin(table.bodies[w.record]);w.phase=1;return .ok(false);}
    if(w.phase==2){if(w.token.kind==125){let usize record=w.record;let u8 count=code(w.field,w.token.begin)?;
            table.layouts.fields[record]=count;w.done=true;return .ok(true);}
        if(w.field>=16){return .err(errors::make(5,w.token.begin));}
        if(table.context.modules==0 && w.token.kind==2 && locals::reserved(source[w.token.begin..w.token.end])){primitive(w);return .ok(false);}
        if(table.context.modules!=0){w.name=names::begin(w.token.begin,w.token.end,true);w.phase=3;}
        else{w.row=0;w.phase=4;}return .ok(false);}
    if(w.phase==4){if(w.row==table.layouts.count){primitive(w);return .ok(false);}
        let usize a=table.begins[w.row];let usize b=table.ends[w.row];
        if(b-a!=w.token.end-w.token.begin){w.row+=1;return .ok(false);}
        w.spelling=a;w.width=b-a;w.compared=0;w.phase=5;return .ok(false);}
    if(w.phase==5 || w.phase==11){var usize stop=w.compared+64;if(stop>w.width){stop=w.width;}
        while(w.compared<stop){w.visits+=1;if(source[w.token.begin+w.compared]!=source[w.spelling+w.compared]){
                w.row+=1;w.phase=if(w.phase==5){4}else{10};return .ok(false);}w.compared+=1;}
        if(w.compared==w.width){if(w.phase==5){let usize id=w.row;return nominal(table,w,id);}return .err(errors::make(3,w.token.begin));}return .ok(false);}
    if(w.phase==9){w.row=0;w.phase=10;return .ok(false);}
    if(w.phase==10){if(w.row==w.field){w.phase=12;return .ok(false);}
        let usize a=w.begins[w.row];let usize b=w.ends[w.row];
        if(b-a!=w.token.end-w.token.begin){w.row+=1;return .ok(false);}
        w.spelling=a;w.width=b-a;w.compared=0;w.phase=11;return .ok(false);}
    if(w.phase==12){let usize field=w.field;let usize a=w.token.begin;let usize b=w.token.end;w.begins[field]=a;w.ends[field]=b;
        if(w.token.kind!=2 || locals::reserved(source[w.token.begin..w.token.end])){return .err(errors::make(2,w.token.begin));}
        next(w,13);return .ok(false);}
    if(w.phase==13){if(w.token.kind!=59){return .err(errors::make(2,w.token.begin));}next(w,14);return .ok(false);}
    if(w.phase==14){w.field+=1;w.phase=2;return .ok(false);}
    return .err(errors::make(5,w.token.begin));
}
