module signature_parse_work;
import value_signature_work as value_signatures;
import value_properties as value_properties;
import functions as functions;
import lexer as lexer;
import lexer_work as tokens;
import signature_type_work as annotations;
import source_name_work as names;
import struct_locate_work as discovery;
import declaration_skip_work as skipping;
import locals as locals;
import errors as errors;
import host_source as host_source;
import metadata_budget as budget;

// One untyped function signature. The owner pins source and private Table.
// Annotation/discovery/name/token/body children each consume separate advances;
// duplicate-name comparisons inspect at most 64 source bytes in a stage.
pub struct State { tokens::State scan; annotations::State annotation; names::State name;
    discovery::State locate; skipping::State body; lexer::State token;
    annotations::Annotation result; annotations::Annotation parameter;
    usize function; usize arity; usize row; usize compared; usize spelling; usize width; usize visits;
    u8 phase; u8 resume; bool waiting; bool resolving; bool main; bool done; }
fn annotations::Annotation scalar(){return annotations::Annotation{.tag=0,.record=0,.length=0,.slice=false,.element=0};}
pub fn State begin(lexer::State token){return State{.scan=tokens::begin(token),.annotation=annotations::begin(token,true),
    .name=names::begin(0,0,false),.locate=discovery::begin(0,0,32),.body=skipping::body(token),.token=token,
    .result=scalar(),.parameter=scalar(),.function=0,.arity=0,.row=0,.compared=0,.spelling=0,.width=0,.visits=0,
    .phase=0,.resume=0,.waiting=false,.resolving=false,.main=false,.done=false};}
fn void next(ref mut State w,u8 phase){let lexer::State current=w.token;
    w.scan=tokens::begin(current);w.waiting=true;w.resume=phase;}
fn bool name(ref u8[] source,ref lexer::State s){return s.kind==2 && !locals::reserved(source[s.begin..s.end]);}
pub fn lexer::State observed(ref State w){return w.token;}
pub fn Result<usize,errors::Error> prepared(ref State w){
    if(!w.done){return .err(errors::make(5,w.token.begin));}return .ok(w.function);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut functions::Table table,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){let Result<bool,errors::Error> result=tokens::advance(source,ref mut w.scan,meter);
        w.token=tokens::observed(ref w.scan);
        switch(result){case .ok(done):{if(done){w.waiting=false;w.phase=w.resume;}}
            case .err(e):{return .err(e);}};return .ok(false);}
    if(w.resolving){let bool done=discovery::advance(source,ref mut w.locate,meter)?;
        if(done){let discovery::Location result=discovery::prepared(ref w.locate)?;
            let bool response=annotations::resolved_record(ref mut w.annotation,result.record)?;w.resolving=false;}
        return .ok(false);}
    if(w.phase==2 || w.phase==8){
        if(w.annotation.request_record){if(!budget::admit(meter,4096,w.token.begin)?){return .ok(false);}
            w.locate=discovery::begin(w.token.begin,w.token.end,32);w.resolving=true;return .ok(false);}
        let Result<bool,errors::Error> result=annotations::advance(source,ref table.context,ref mut w.annotation,meter);
        w.token=annotations::observed(ref w.annotation);let bool done=result?;
        if(done){let annotations::Annotation value=annotations::prepared(ref w.annotation)?;
            if(w.phase==2){w.result=value;w.phase=3;}else{w.parameter=value;w.phase=9;}}
        return .ok(false);
    }
    if(w.phase==4){let bool done=names::advance(source,ref table.context,ref mut w.name,meter)?;
        if(done){if(w.name.result<table.count){return .err(errors::make(3,w.token.begin));}w.phase=5;}return .ok(false);}
    if(w.phase==19){let Result<bool,errors::Error> result=skipping::advance(source,ref mut w.body,meter);
        w.token=skipping::observed(ref w.body);
        if(w.body.depth==0){let usize f=w.function;table.body_ends[f]=w.body.end;}
        let bool done=result?;if(done){table.count+=1;w.done=true;return .ok(true);}return .ok(false);}
    if(!budget::admit(meter,4096,w.token.begin)?){return .ok(false);}
    if(w.phase==0){if(table.count>=16){return .err(errors::make(4,w.token.begin));}
        if(w.token.kind!=2 || !lexer::equal(source[w.token.begin..w.token.end],b"fn")){return .err(errors::make(2,w.token.begin));}
        w.function=table.count;next(w,1);return .ok(false);}
    if(w.phase==1){
        if(table.scalar_host_calls && w.token.kind==2 && lexer::equal(source[w.token.begin..w.token.end],b"Result")){
            let u8 success=host_source::annotation(source,ref mut w.token)?;
            w.result.tag=128+success;
            w.phase=3;return .ok(false);
        }
        let lexer::State current=w.token;w.annotation=annotations::begin(current,true);w.phase=2;return .ok(false);
    }
    if(w.phase==3){if(!name(source,ref w.token)){return .err(errors::make(2,w.token.begin));}
        if(table.context.modules!=0){w.name=names::begin(w.token.begin,w.token.end,false);w.phase=4;}
        else{w.row=0;w.phase=20;}return .ok(false);}
    if(w.phase==5){let usize f=w.function;
        table.return_types[f]=w.result.tag;table.return_lengths[f]=w.result.length;table.return_records[f]=w.result.record;
        table.return_slice_elements[f]=w.result.element;table.begins[f]=w.token.begin;table.ends[f]=w.token.end;
        w.main=table.context.modules==0 && lexer::equal(source[w.token.begin..w.token.end],b"main");next(w,6);return .ok(false);}
    if(w.phase==6){if(w.token.kind!=40){return .err(errors::make(2,w.token.begin));}next(w,7);return .ok(false);}
    if(w.phase==7){if(w.token.kind==41){w.phase=16;return .ok(false);}
        if(w.arity>=8){return .err(errors::make(4,w.token.begin));}
        let lexer::State current=w.token;w.annotation=annotations::begin(current,false);w.phase=8;return .ok(false);}
    if(w.phase==9){if(!name(source,ref w.token)){return .err(errors::make(2,w.token.begin));}w.row=0;w.phase=10;return .ok(false);}
    if(w.phase==10 || w.phase==20){let usize count=if(w.phase==10){w.arity}else{table.count};
        if(w.row==count){w.phase=if(w.phase==10){12}else{5};return .ok(false);}
        let usize slot=if(w.phase==10){w.function*8+w.row}else{w.row};
        let usize a=if(w.phase==10){table.param_begins[slot]}else{table.begins[slot]};
        let usize b=if(w.phase==10){table.param_ends[slot]}else{table.ends[slot]};
        if(b-a!=w.token.end-w.token.begin){w.row+=1;return .ok(false);}
        w.spelling=a;w.width=b-a;w.compared=0;w.phase=if(w.phase==10){11}else{21};return .ok(false);}
    if(w.phase==11 || w.phase==21){var usize stop=w.compared+64;if(stop>w.width){stop=w.width;}
        while(w.compared<stop){w.visits+=1;
            if(source[w.token.begin+w.compared]!=source[w.spelling+w.compared]){w.row+=1;w.phase=if(w.phase==11){10}else{20};return .ok(false);}w.compared+=1;}
        if(w.compared==w.width){return .err(errors::make(3,w.token.begin));}return .ok(false);}
    if(w.phase==12){let usize f=w.function;let usize slot=f*8+w.arity;
        table.param_begins[slot]=w.token.begin;table.param_ends[slot]=w.token.end;
        table.param_types[slot]=w.parameter.tag;table.param_lengths[slot]=w.parameter.length;table.param_records[slot]=w.parameter.record;
        table.param_slices[slot]=w.parameter.slice;table.param_slice_elements[slot]=w.parameter.element;
        if(w.result.slice && w.parameter.slice && w.result.element==w.parameter.element){
            var u8 bit=1;var usize n=0;while(n<w.arity){bit<<=1;n+=1;}table.return_slice_candidates[f]|=bit;}
        w.arity+=1;next(w,13);return .ok(false);}
    if(w.phase==13){if(w.token.kind==41){w.phase=16;return .ok(false);}
        if(w.token.kind!=44){return .err(errors::make(2,w.token.begin));}next(w,14);return .ok(false);}
    if(w.phase==14){if(w.token.kind==41){return .err(errors::make(2,w.token.begin));}w.phase=7;return .ok(false);}
    if(w.phase==16){let usize f=w.function;
        if(w.result.slice && table.return_slice_candidates[f]==0 && !(table.reference_returns && w.result.element==10)){
            return .err(errors::make(3,table.begins[f]));}
        if(w.main && (w.arity!=0 || w.result.tag!=1 || w.result.length!=0 || w.result.record!=0 || w.result.slice)){
            return .err(errors::make(3,table.begins[f]));}
        if(w.main){table.entry=f;}table.arities[f]=w.arity;
        if(w.token.kind!=41){return .err(errors::make(2,w.token.begin));}next(w,17);return .ok(false);}
    if(w.phase==17){if(w.token.kind!=123){return .err(errors::make(2,w.token.begin));}next(w,18);return .ok(false);}
    if(w.phase==18){let usize f=w.function;table.bodies[f]=w.token.begin;let lexer::State current=w.token;
        w.body=skipping::body(current);w.phase=19;return .ok(false);}
    return .err(errors::make(5,w.token.begin));
}

// The external value parser bank is reused per annotation. Legacy signature
// metadata, duplicate names and body skipping keep their original continuations.
pub fn Result<bool,errors::Error> advance_values(ref u8[] source,ref mut functions::Table table,
    ref mut value_properties::Catalog catalog,ref mut value_signatures::State value,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==2 || w.phase==8){let Result<bool,errors::Error> result=annotations::advance_values(source,ref table.context,catalog,value,ref mut w.annotation,meter);
        w.token=annotations::observed(ref w.annotation);let bool done=result?;
        if(done){let annotations::Annotation annotation=annotations::prepared(ref w.annotation)?;
            if(w.phase==2){w.result=annotation;w.phase=3;}else{w.parameter=annotation;w.phase=9;}}return .ok(false);}
    return advance(source,table,w,meter);
}
