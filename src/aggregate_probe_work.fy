module aggregate_probe_work;
import lexer as lexer;
import lexer_work as tokens;
import locals as locals;
import functions as functions;
import ir as ir;
import source_name_work as names;
import record_location_work as locations;
import source_state_work as states;
import errors as errors;
import metadata_budget as budget;
// Advisory plans only: 1 record atom, 2 array atom, 3 literal projection,
// 4 grouped static projection, 5 repeated/list separator. No guest evaluation.
pub struct Plan { usize groups; usize record; u8 kind; u8 tag; u8 suffix; }
pub struct State { Plan result; lexer::State original; lexer::State look; lexer::State query; lexer::State field; lexer::State saved;
    tokens::State scan; names::State name; locations::State location; states::State state;
    usize[16] records; usize[16] fields; usize groups; usize left; usize depth; usize row; usize compared;
    usize spelling; usize width; usize local; usize target; usize record; usize path_depth; usize selected;
    usize prior; usize ordinal; usize leaves; usize leaf_depth; usize leaf_visits; usize visits;
    u8 mode; u8 phase; u8 kind; u8 tag; u8 open; u8 close; u8 resume; u8 lookup;
    bool waiting; bool field_scan; bool scalar; bool done; }
fn Plan none(){return Plan{.groups=0,.record=0,.kind=0,.tag=0,.suffix=0};}
pub fn State begin(lexer::State s,u8 mode){return State{.result=none(),.original=s,.look=s,.query=s,.field=s,.saved=s,
    .scan=tokens::begin(s),.name=names::begin(0,0,false),.location=locations::begin(0,0,32),.state=states::begin(0),
    .records=[0;16],.fields=[0;16],.groups=0,.left=0,.depth=0,.row=0,.compared=0,.spelling=0,.width=0,
    .local=64,.target=16,.record=32,.path_depth=0,.selected=0,.prior=0,.ordinal=0,.leaves=0,.leaf_depth=0,.leaf_visits=0,.visits=0,
    .mode=mode,.phase=0,.kind=0,.tag=0,.open=0,.close=0,.resume=0,.lookup=0,.waiting=false,.field_scan=false,.scalar=false,.done=false};}
pub fn Result<Plan,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.original.begin));}return .ok(w.result);}
fn Result<bool,errors::Error> finish(ref mut State w,bool valid){if(valid){w.result=Plan{.groups=w.groups,.record=w.record,.kind=w.kind,.tag=w.tag,.suffix=w.look.kind};}
    w.done=true;return .ok(true);}
fn void next(ref mut State w,u8 phase,bool field){let lexer::State s=if(field){w.field}else{w.look};
    w.scan=tokens::begin(s);w.waiting=true;w.field_scan=field;w.resume=phase;}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] value){return s.kind==2 && lexer::equal(source[s.begin..s.end],value);}
fn bool record_binding(ref locals::Table t,usize i){return i<t.count && t.registers[i]>=144 && t.registers[i]<160;}
fn bool array_binding(ref locals::Table t,usize i){return i<t.count && t.registers[i]>=128 && t.registers[i]<144;}
fn bool static_binding(ref locals::Table t,usize i){return i<t.count && t.registers[i]>=192 && t.registers[i]<224;}
fn void lookup(ref mut State w,u8 kind){w.lookup=kind;w.row=0;w.phase=3;}
fn void located(ref mut State w,usize selected,u8 phase){w.location=locations::begin(w.query.begin,w.query.end,selected);w.phase=phase;}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref ir::Program p,ref locals::Table table,
    ref functions::Table signatures,ref mut State w,ref mut budget::State meter){
    if(w.mode>=3){return advance_syntax(source,table,w,meter);}
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){let bool done=tokens::advance(source,ref mut w.scan,meter)?;if(done){let lexer::State s=tokens::prepared(ref w.scan)?;
            if(w.field_scan){w.field=s;}else{w.look=s;}w.waiting=false;w.phase=w.resume;}return .ok(false);}
    if(w.phase==5){let bool done=names::advance(source,ref signatures.context,ref mut w.name,meter)?;
        if(done){w.target=if(w.name.result<signatures.count){w.name.result}else{16};next(w,6,false);}return .ok(false);}
    if(w.phase==7 || w.phase==18){let bool done=locations::advance(source,ref signatures.context,ref mut w.location,meter)?;
        if(done){if(w.phase==7){w.record=w.location.record;w.phase=10;}else{w.phase=23;}}return .ok(false);}
    if(w.phase==24){let bool done=states::advance(source,ref signatures.context,ref mut w.state,meter)?;
        if(done){w.field=states::prepared(ref w.state)?;next(w,25,true);}return .ok(false);}
    if(!budget::admit(meter,4096,w.original.begin)?){return .ok(false);}w.visits+=1;let lexer::State s=w.look;
    if(w.phase==0){if(s.kind==40){if(w.groups>=32){return .err(errors::make(4,s.begin));}w.groups+=1;next(w,0,false);return .ok(false);}
        w.left=w.groups;if(w.mode==2 && s.kind==91){w.kind=1;w.open=91;w.close=93;w.phase=10;return .ok(false);}
        if(s.kind!=2 && s.kind!=5){return finish(w,false);}w.query=s;lookup(w,0);return .ok(false);}
    if(w.phase==3){let usize count=if(w.lookup==0){table.count}else{signatures.count};
        if(w.lookup==1 && signatures.context.modules!=0 && signatures.count<=16){w.name=names::begin(w.query.begin,w.query.end,false);w.phase=5;return .ok(false);}
        if(w.row==count || w.lookup==1 && signatures.count>16){if(w.lookup==0){lookup(w,1);}else{next(w,6,false);}return .ok(false);}
        let usize a=if(w.lookup==0){table.begins[w.row]}else{signatures.begins[w.row]};let usize b=if(w.lookup==0){table.ends[w.row]}else{signatures.ends[w.row]};
        if(b-a!=w.query.end-w.query.begin){w.row+=1;return .ok(false);}w.spelling=a;w.width=b-a;w.compared=0;w.phase=4;return .ok(false);}
    if(w.phase==4){var usize stop=w.compared+64;if(stop>w.width){stop=w.width;}
        while(w.compared<stop){if(source[w.query.begin+w.compared]!=source[w.spelling+w.compared]){w.row+=1;w.phase=3;return .ok(false);}w.compared+=1;}
        if(w.compared==w.width){if(w.lookup==0){w.local=w.row;lookup(w,1);}else{w.target=w.row;next(w,6,false);}}return .ok(false);}
    if(w.phase==6){if(w.mode==1){
            if(s.kind==123){w.kind=1;w.open=123;w.close=125;located(w,32,7);return .ok(false);}
            if(s.kind==40 && w.local==64 && w.target<signatures.count && signatures.return_records[w.target]!=0){w.kind=3;w.record=signatures.return_records[w.target] as usize-1;w.open=40;w.close=41;w.phase=10;return .ok(false);}
            if(!record_binding(table,w.local)){return finish(w,false);}let usize id=table.registers[w.local]-144;
            if(id>=16 || id>=p.records.count || p.record_functions[id] as usize!=table.function){return .err(errors::make(3,w.original.begin));}
            w.record=p.records.records[id] as usize;w.kind=2;w.phase=15;return .ok(false);}
        if(s.kind==40){if(w.local!=64 || w.target>=signatures.count || signatures.return_lengths[w.target]==0){return finish(w,false);}
            w.kind=3;w.open=40;w.close=41;w.phase=10;return .ok(false);}
        if(!array_binding(table,w.local)){return finish(w,false);}let usize id=table.registers[w.local]-128;
        if(id>=16 || id>=p.arrays.count || p.array_functions[id] as usize!=table.function){return .err(errors::make(3,w.original.begin));}w.kind=2;w.phase=15;return .ok(false);}
    if(w.phase==10){w.depth=1;next(w,11,false);return .ok(false);}
    if(w.phase==11){if(s.kind==0){return .err(errors::make(2,s.begin));}if(s.kind==w.open){w.depth+=1;}else if(s.kind==w.close){w.depth-=1;}
        next(w,12,false);return .ok(false);}
    if(w.phase==12){w.phase=if(w.depth==0){15}else{11};return .ok(false);}
    if(w.phase==15){if(w.mode==1 && w.tag==0 && s.kind==46){w.path_depth=0;w.phase=16;return .ok(false);}w.phase=22;return .ok(false);}
    if(w.phase==22){if(w.left==0){return finish(w,true);}if(s.kind!=41){return finish(w,false);}w.left-=1;next(w,15,false);return .ok(false);}
    if(w.phase==16){if(w.path_depth>=16){return .err(errors::make(4,s.begin));}w.path_depth+=1;next(w,17,false);return .ok(false);}
    if(w.phase==17){if(s.kind!=2){return .err(errors::make(2,s.begin));}w.query=s;let usize record=w.record;located(w,record,18);return .ok(false);}
    if(w.phase==23){if(w.record>=p.records.layouts.count || w.location.record!=w.record){return .err(errors::make(3,s.begin));}
        w.state=states::begin(w.location.body);w.selected=0;w.phase=24;return .ok(false);}
    if(w.phase==25){if(w.selected>=p.records.layouts.fields[w.record] as usize){return .err(errors::make(3,s.begin));}next(w,26,true);return .ok(false);}
    if(w.phase==26){if(w.field.end-w.field.begin!=s.end-s.begin){next(w,28,true);return .ok(false);}w.compared=0;w.phase=27;return .ok(false);}
    if(w.phase==27){var usize stop=w.compared+64;let usize width=s.end-s.begin;if(stop>width){stop=width;}
        while(w.compared<stop){if(source[s.begin+w.compared]!=source[w.field.begin+w.compared]){next(w,28,true);return .ok(false);}w.compared+=1;}
        if(w.compared==width){w.prior=0;w.phase=30;}return .ok(false);}
    if(w.phase==28){if(w.field.kind!=59){return .err(errors::make(2,w.field.begin));}w.selected+=1;next(w,25,true);return .ok(false);}
    if(w.phase==30){if(w.prior==w.selected){let usize slot=w.record*16+w.selected;w.scalar=p.records.layouts.kinds[slot]==0;
            if(w.scalar){w.tag=p.records.layouts.types[slot];}else{w.record=p.records.layouts.types[slot] as usize;}next(w,20,false);return .ok(false);}
        let usize slot=w.record*16+w.prior;if(p.records.layouts.kinds[slot]==0){w.ordinal+=1;w.prior+=1;return .ok(false);}
        w.records[0]=p.records.layouts.types[slot] as usize;w.fields[0]=0;w.leaf_depth=1;w.leaves=0;w.leaf_visits=0;w.phase=31;return .ok(false);}
    if(w.phase==31){if(w.leaf_depth==0){w.ordinal+=w.leaves;w.prior+=1;w.phase=30;return .ok(false);}
        if(w.leaf_visits>=4096){return .err(errors::make(4,w.original.begin));}w.leaf_visits+=1;
        let usize level=w.leaf_depth-1;let usize record=w.records[level];if(record>=p.records.layouts.count){return .err(errors::make(3,w.original.begin));}
        if(w.fields[level]>=p.records.layouts.fields[record] as usize){w.leaf_depth-=1;return .ok(false);}let usize slot=record*16+w.fields[level];let usize field=w.fields[level];w.fields[level]=field+1;
        if(p.records.layouts.kinds[slot]==0){if(w.leaves>=16){return .err(errors::make(4,w.original.begin));}w.leaves+=1;}
        else{if(w.leaf_depth>=16){return .err(errors::make(4,w.original.begin));}let usize next=w.leaf_depth;w.records[next]=p.records.layouts.types[slot] as usize;w.fields[next]=0;w.leaf_depth+=1;}return .ok(false);}
    if(w.phase==20){if(w.scalar){if(s.kind==46){w.saved=s;next(w,21,false);return .ok(false);}w.phase=22;}
        else{w.phase=if(s.kind==46){16}else{22};}return .ok(false);}
    if(w.phase==21){if(s.kind!=46){return .err(errors::make(2,w.saved.begin));}w.look=w.saved;w.phase=22;return .ok(false);}
    return .err(errors::make(5,s.begin));
}
pub fn Result<Plan,errors::Error> inspect(ref u8[] source,lexer::State s,ref ir::Program p,ref locals::Table table,ref functions::Table signatures,u8 mode){
    var State w=begin(s,mode);var budget::State meter=budget::empty();while(!w.done){let usize allowance=budget::reset(ref mut meter,s.begin)?;
        let bool done=advance(source,p,table,signatures,ref mut w,ref mut meter)?;}return prepared(ref w);
}

// Literal/static adapters need no dummy Program or function catalog on the stack.
pub fn Result<bool,errors::Error> advance_syntax(ref u8[] source,ref locals::Table table,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.waiting){let bool done=tokens::advance(source,ref mut w.scan,meter)?;
        if(done){w.look=tokens::prepared(ref w.scan)?;w.waiting=false;w.phase=w.resume;}return .ok(false);}
    if(!budget::admit(meter,4096,w.original.begin)?){return .ok(false);}w.visits+=1;let lexer::State s=w.look;
    if(w.phase==0){if(w.mode==5){if(s.kind!=91){return .err(errors::make(2,s.begin));}next(w,60,false);return .ok(false);}
        if(w.mode==4 && w.groups==0 && s.kind!=40){return finish(w,false);}
        if(s.kind==40){if(w.groups>=32){return .err(errors::make(4,if(w.mode==4){w.original.begin}else{s.begin}));}w.groups+=1;next(w,0,false);return .ok(false);}
        w.left=w.groups;if(w.mode==4){if(word(source,ref s,b"ref")){next(w,40,false);}else{w.phase=40;}return .ok(false);}
        if(s.kind!=91){return finish(w,false);}w.kind=1;w.open=91;w.close=93;w.phase=10;return .ok(false);}
    if(w.phase==10){w.depth=1;next(w,11,false);return .ok(false);}
    if(w.phase==11){if(s.kind==0){return .err(errors::make(2,s.begin));}if(s.kind==91){w.depth+=1;}else if(s.kind==93){w.depth-=1;}next(w,12,false);return .ok(false);}
    if(w.phase==12){w.phase=if(w.depth==0){15}else{11};return .ok(false);}
    if(w.phase==15){if(w.left==0){return finish(w,true);}if(s.kind!=41){return finish(w,false);}w.left-=1;next(w,15,false);return .ok(false);}
    if(w.phase==40){if(s.kind==3 || s.kind==4){w.phase=42;return .ok(false);}if(s.kind!=2){return finish(w,false);}w.query=s;lookup(w,0);return .ok(false);}
    if(w.phase==3){if(w.row==table.count){w.phase=41;return .ok(false);}let usize a=table.begins[w.row];let usize b=table.ends[w.row];
        if(b-a!=w.query.end-w.query.begin){w.row+=1;return .ok(false);}w.spelling=a;w.width=b-a;w.compared=0;w.phase=4;return .ok(false);}
    if(w.phase==4){var usize stop=w.compared+64;if(stop>w.width){stop=w.width;}
        while(w.compared<stop){if(source[w.query.begin+w.compared]!=source[w.spelling+w.compared]){w.row+=1;w.phase=3;return .ok(false);}w.compared+=1;}
        if(w.compared==w.width){w.local=w.row;w.phase=41;}return .ok(false);}
    if(w.phase==41){if(!static_binding(table,w.local) && !word(source,ref s,b"text")){return finish(w,false);}w.phase=42;return .ok(false);}
    if(w.phase==42){w.look=w.original;w.depth=1;next(w,43,false);return .ok(false);}
    if(w.phase==43){if(s.kind==0){return .err(errors::make(2,w.original.begin));}if(s.kind==40){w.depth+=1;}else if(s.kind==41){w.depth-=1;}
        let u8 phase=if(w.depth==0){44}else{43};next(w,phase,false);return .ok(false);}
    if(w.phase==44){w.kind=if(s.kind==91 || s.kind==46){1}else{0};return finish(w,true);}
    if(w.phase==60){if(s.kind==0){return .err(errors::make(2,s.begin));}
        if(w.depth==0 && (s.kind==59 || s.kind==44 || s.kind==93)){w.kind=if(s.kind==59){1}else{0};return finish(w,true);}
        if(s.kind==40 || s.kind==91 || s.kind==123){w.depth+=1;}else if(s.kind==41 || s.kind==93 || s.kind==125){if(w.depth==0){return .err(errors::make(2,s.begin));}w.depth-=1;}
        next(w,60,false);return .ok(false);}
    return .err(errors::make(5,s.begin));
}
pub fn Result<Plan,errors::Error> inspect_syntax(ref u8[] source,lexer::State s,ref locals::Table table,u8 mode){
    var State w=begin(s,mode);var budget::State meter=budget::empty();while(!w.done){let usize allowance=budget::reset(ref mut meter,s.begin)?;
        let bool done=advance_syntax(source,table,ref mut w,ref mut meter)?;}return prepared(ref w);
}
