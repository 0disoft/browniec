module operand_route_work;
import lexer as lexer;
import lexer_work as tokens;
import source_name_work as scoped;
import locals as locals;
import functions as functions;
import reference_call_source as references;
import errors as errors;
import metadata_budget as budget;
// Advisory scalar routes only: 0 legacy child, 1 group, 2 unary, 3 plain CALL,
// 4 captured CALL. Conditional/aggregate protocols retain their own classifier
// and validation before any guest evaluation. No route grants IR authority.
pub struct State { lexer::State start; lexer::State look; tokens::State scan; scoped::State name;
    usize depth; usize groups; usize begin; usize end; usize row; usize compared; usize width; usize spelling;
    usize target; usize local; usize visits; u8 phase; u8 next; u8 lane;
    bool group; bool waiting; bool naming; bool plain; bool done; }
pub fn State begin(lexer::State token,usize depth){return State{.start=token,.look=token,.scan=tokens::begin(token),.name=scoped::begin(0,0,false),
    .depth=depth,.groups=0,.begin=token.begin,.end=token.end,.row=0,.compared=0,.width=0,.spelling=0,.target=16,.local=64,.visits=0,
    .phase=0,.next=0,.lane=0,.group=false,.waiting=false,.naming=false,.plain=true,.done=false};}
fn Result<bool,errors::Error> finish(ref mut State w,u8 lane){w.lane=lane;w.done=true;return .ok(true);}
fn void next(ref mut State w,u8 phase){let lexer::State s=w.look;w.scan=tokens::begin(s);w.next=phase;w.waiting=true;}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref locals::Table names,ref functions::Table signatures,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){switch(tokens::advance(source,ref mut w.scan,meter)){
        case .err(e):{return .err(e);}case .ok(done):{if(done){w.look=tokens::prepared(ref w.scan)?;w.waiting=false;w.phase=w.next;}return .ok(false);}};}
    if(w.naming){let bool done=scoped::advance(source,ref signatures.context,ref mut w.name,meter)?;
        if(done){w.target=if(w.name.result<signatures.count){w.name.result}else{16};w.naming=false;w.phase=40;}return .ok(false);}
    if(!budget::admit(meter,4096,w.start.begin)?){return .ok(false);}w.visits+=1;let lexer::State s=w.look;let u8 phase=w.phase;
    if(phase==0){if(w.depth>32){return .err(errors::make(4,w.start.begin));}
        if(s.kind==45 || s.kind==33 || s.kind==126){return finish(w,2);}
        if(s.kind==40){w.group=true;w.phase=10;return .ok(false);}
        if((s.kind!=2 && s.kind!=5) || locals::reserved(source[s.begin..s.end])){return finish(w,0);}
        next(w,11);return .ok(false);}
    if(phase==10){if(s.kind==40){if(w.groups>=32){return .err(errors::make(4,s.begin));}w.groups+=1;next(w,10);return .ok(false);}
        if(word(source,ref s,b"if") || word(source,ref s,b"switch") || word(source,ref s,b"ref") || word(source,ref s,b"text") || s.kind==3 || s.kind==4 || s.kind==91){return finish(w,0);}
        if(s.kind!=2 && s.kind!=5){return finish(w,1);}w.begin=s.begin;w.end=s.end;next(w,11);return .ok(false);}
    if(phase==11){if(s.kind==123){return finish(w,0);}if(!w.group && s.kind!=40){return finish(w,0);}w.row=0;w.phase=20;return .ok(false);}
    if(phase==20){if(w.row==names.count){w.phase=30;w.row=0;return .ok(false);}let usize a=names.begins[w.row];let usize b=names.ends[w.row];
        if(b-a==w.end-w.begin){w.spelling=a;w.width=b-a;w.compared=0;w.phase=21;}else{w.row+=1;}return .ok(false);}
    if(phase==21 || phase==32){let usize query=w.begin;var usize stop=w.compared+64;if(stop>w.width){stop=w.width;}
        while(w.compared<stop){if(source[query+w.compared]!=source[w.spelling+w.compared]){w.row+=1;w.phase=if(phase==21){20}else{31};return .ok(false);}w.compared+=1;}
        if(w.compared==w.width){if(phase==21){w.local=w.row;w.phase=30;}else{w.target=w.row;w.phase=40;}}return .ok(false);}
    if(phase==30){if(w.local!=64){if(!w.group){return finish(w,0);}let usize encoded=names.registers[w.local];
            if(encoded>=192){return finish(w,0);}
            if(encoded>=144 && encoded<160 && s.kind==46){w.phase=50;return .ok(false);}
            if(encoded>=128 && encoded<160 && s.kind==41){w.phase=53;return .ok(false);}
            return finish(w,1);}
        if(signatures.count>16){let u8 lane=if(w.group){1}else{0};return finish(w,lane);}
        if(signatures.context.modules!=0){let usize a=w.begin;let usize b=w.end;w.name=scoped::begin(a,b,false);w.naming=true;return .ok(false);}
        w.row=0;w.phase=31;return .ok(false);}
    if(phase==31){if(w.row==signatures.count){w.phase=40;return .ok(false);}let usize a=signatures.begins[w.row];let usize b=signatures.ends[w.row];
        if(b-a==w.end-w.begin){w.spelling=a;w.width=b-a;w.compared=0;w.phase=32;}else{w.row+=1;}return .ok(false);}
    if(phase==40){let usize target=w.target;if(w.group){if(target<16 && (signatures.return_lengths[target]!=0 || signatures.return_records[target]!=0)){return finish(w,0);}return finish(w,1);}
        if(target==16 || signatures.return_types[target]==13 || references::result(signatures,target) || signatures.return_slice_elements[target]!=0 ||
            signatures.return_lengths[target]!=0 || signatures.return_records[target]!=0){return finish(w,0);}
        w.row=0;w.phase=41;return .ok(false);}
    if(phase==41){if(w.row==signatures.arities[w.target]){let u8 lane=if(w.plain){3}else{4};return finish(w,lane);}let usize at=w.target*8+w.row;
        if(signatures.param_slices[at] || signatures.param_lengths[at]!=0 || signatures.param_records[at]!=0){w.plain=false;}w.row+=1;return .ok(false);}
    // A local record path emits nothing until its nominal fields are validated
    // by the selected child. A binary tail keeps the outer group on shared frames.
    if(phase==50){next(w,51);return .ok(false);}
    if(phase==51){if(s.kind!=2){return finish(w,0);}next(w,52);return .ok(false);}
    if(phase==52){w.phase=if(s.kind==46){50}else{53};return .ok(false);}
    if(phase==53){if(w.groups==0){return finish(w,0);}if(s.kind!=41){return finish(w,1);}w.groups-=1;next(w,53);return .ok(false);}
    return .err(errors::make(5,w.start.begin));
}
