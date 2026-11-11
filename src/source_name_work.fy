module source_name_work;
import source_context as context;
import source_context_check_work as checking;
import lexer as lexer;
import lexer_work as tokens;
import metadata_budget as budget;
import errors as errors;
// Copyable analysis only. Pin exact source/context/query. Scope authentication,
// query lexing, alias selection and name comparisons each resume independently.
pub struct State {
    checking::State check; tokens::State scan; lexer::State token;
    usize begin; usize end; usize first; usize last; usize qualifier_begin; usize qualifier_end;
    usize caller; usize target; usize row; usize candidate; usize compared; usize spelling;
    usize width; usize result; usize visits; u8 phase; u8 resume;
    bool exported; bool record; bool waiting; bool done;
}
pub fn State begin(usize a,usize b,bool record){return State{.check=checking::empty(),.scan=tokens::begin(lexer::empty()),.token=lexer::empty(),
    .begin=a,.end=b,.first=0,.last=0,.qualifier_begin=0,.qualifier_end=0,.caller=16,.target=16,
    .row=0,.candidate=0,.compared=0,.spelling=0,.width=0,.result=if(record){32}else{16},.visits=0,
    .phase=0,.resume=0,.exported=false,.record=record,.waiting=false,.done=false};}
fn usize owner(ref context::Table t,usize at){var usize i=0;while(i<t.modules){if(at<t.ends[i] as usize){return i;}i+=1;}return 16;}
fn Result<bool,errors::Error> absent(ref mut State w){w.done=true;return .ok(true);}
fn void next(ref mut State w,u8 phase){let lexer::State current=w.token;w.scan=tokens::begin(current);w.resume=phase;w.waiting=true;}
fn lexer::State scanned(ref tokens::State w){return w.head;}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref context::Table t,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==0){let bool done=checking::advance(source,t,ref mut w.check,meter)?;
        if(done){if(!w.check.result){return absent(w);}w.phase=1;}return .ok(false);}
    if(w.waiting){let usize a=w.begin;let usize b=w.end;
        switch(tokens::advance(source[a..b],ref mut w.scan,meter)){
            case .ok(done):{if(done){w.token=scanned(ref w.scan);w.phase=w.resume;w.waiting=false;}}
            case .err(_):{return absent(w);}};return .ok(false);}
    if(!budget::admit(meter,4096,w.begin)?){return .ok(false);}
    if(w.phase==1){if(w.begin>=w.end||w.end>source.len){return absent(w);}w.caller=owner(t,w.begin);
        if(w.caller==16||w.end>t.ends[w.caller] as usize){return absent(w);}w.target=w.caller;next(w,2);return .ok(false);}
    let lexer::State token=w.token;
    if(w.phase==2){if(token.kind!=2){return absent(w);}w.first=token.begin;w.last=token.end;
        if(token.end==w.end-w.begin){w.phase=9;}else{w.qualifier_begin=token.begin;w.qualifier_end=token.end;next(w,3);}return .ok(false);}
    if(w.phase==3||w.phase==4){if(token.kind!=58){return absent(w);}let u8 phase=if(w.phase==3){4}else{5};next(w,phase);return .ok(false);}
    if(w.phase==5){if(token.kind!=2){return absent(w);}w.first=token.begin;w.last=token.end;next(w,6);return .ok(false);}
    if(w.phase==6){if(token.kind!=0){return absent(w);}w.row=0;w.phase=7;return .ok(false);}
    if(w.phase==7){if(w.row==t.imports){return absent(w);}let u32 item=t.aliases[w.row];
        let usize a=context::begin(item);let usize b=context::end(item);
        if(owner(t,a)==w.caller && b-a==w.qualifier_end-w.qualifier_begin){
            w.candidate=item as usize>>26;w.spelling=a;w.width=b-a;w.compared=0;w.phase=8;
        }else{w.row+=1;}return .ok(false);}
    if(w.phase==8||w.phase==10){let usize query=w.begin+if(w.phase==8){w.qualifier_begin}else{w.first};
        var usize stop=w.compared+64;if(stop>w.width){stop=w.width;}
        while(w.compared<stop){w.visits+=1;if(source[query+w.compared]!=source[w.spelling+w.compared]){
                w.row+=1;w.phase=if(w.phase==8){7}else{9};return .ok(false);}w.compared+=1;}
        if(w.compared==w.width){if(w.phase==8){w.target=w.candidate;w.row=0;w.phase=9;}
            else{if(w.target!=w.caller && !w.exported){return absent(w);}w.result=w.row;w.done=true;return .ok(true);}}
        return .ok(false);
    }
    if(w.phase==9){let usize count=if(w.record){t.record_count}else{t.function_count};if(w.row==count){return absent(w);}
        let u32 item=if(w.record){t.records[w.row]}else{t.functions[w.row]};let usize a=context::begin(item);let usize b=context::end(item);
        if(owner(t,a)==w.target && b-a==w.last-w.first){w.spelling=a;w.width=b-a;w.compared=0;w.exported=(item&67108864)!=0;w.phase=10;}
        else{w.row+=1;}return .ok(false);
    }
    return .err(errors::make(5,w.begin));
}
