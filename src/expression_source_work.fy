module expression_source_work;
import lexer as lexer;
import functions as functions;
import locals as locals;
import call_operand_work as calls;
import operand_tail_work as tails;
import operand_preflight_work as probes;
import operand_route_work as routes;
import value_syntax_work as syntax;
import aggregate_probe_work as aggregates;
import array_operand_work as array_values;
import lexer_work as tokens;
import ir as ir;
import types as types;
import errors as errors;
import metadata_budget as budget;
// Private Pratt/group/CALL/unary/tail coordinator. Converted preflight,
// conditional/aggregate bodies and argument protocols remain legacy children.
// Source, names, capture bank and candidate IR stay pinned across advances.
pub struct Frame { usize environment; usize target; usize arity; usize count; usize operand_at; usize depth; usize left; usize slot; usize jump; usize at;
    u8 context; u8 minimum; u8 expected; u8 kind; u8 operation; u8 phase; }
// Active CALL contexts only append hidden bindings. One shared 64-row prefix
// suffices: frame counts/pending masks restore the enclosing lexical view after
// child cleanup. Unused rows are scratch; original caller names stay immutable.
// The owner pins this bank separately from semantic State construction.
// List cells contain checked register IDs 0..127, not source offsets or values.
pub struct Bank { calls::Frame[34] calls; usize[64] begins; usize[64] ends; usize[64] registers; bool[64] mutability; tails::State tail; probes::State probe; routes::State route; syntax::State syntax; aggregates::State aggregate; array_values::Frame[34] arrays; u8[1024] cells; }
pub fn Bank empty_bank(){return Bank{.calls=[calls::empty_frame();34],.begins=[0;64],.ends=[0;64],.registers=[0;64],.mutability=[false;64],.tail=tails::begin(lexer::empty(),0,0,false),.probe=probes::begin(lexer::empty(),0,false),.route=routes::begin(lexer::empty(),0),.syntax=syntax::begin(lexer::empty(),1),.aggregate=aggregates::begin(lexer::empty(),1),.arrays=[array_values::begin(0,0,0,0,false,64,0);34],.cells=[0;1024]};}
pub struct State { usize[272] arguments; u8[272] parameters; Frame[34] frames; tokens::State token; usize used; usize value; usize cell_used;
    usize visits; u8 request; bool waiting; bool lexing; bool done; }
fn Frame frame(usize depth,u8 minimum,u8 expected){return Frame{.environment=34,.target=0,.arity=0,.count=0,.operand_at=0,.depth=depth,.left=0,.slot=0,.jump=0,.at=0,
    .context=expected,.minimum=minimum,.expected=expected,.kind=0,.operation=0,.phase=0};}
pub fn State begin(usize depth,u8 minimum,u8 expected){var State w=State{.arguments=[0;272],.parameters=[0;272],.frames=[frame(0,1,0);34],
    .token=tokens::begin(lexer::empty()),.used=1,.value=0,.cell_used=0,.visits=0,.request=0,.waiting=false,.lexing=false,.done=false};
    w.frames[0]=frame(depth,minimum,expected);return w;}
pub fn Frame current(ref State w){let ref Frame[] frames=ref w.frames;return frames[w.used-1];}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,0));}return .ok(w.value);}
pub fn Result<usize,errors::Error> resume(ref mut State w,usize value){
    if(w.done || !w.waiting || (w.request!=1 && w.request!=2)){return .err(errors::make(5,0));}w.waiting=false;w.request=0;w.value=value;return .ok(value);}
pub fn Result<usize,errors::Error> tail(ref mut State w,ref mut Bank bank,lexer::State token,usize value,u8 result_type){
    if(w.done || !w.waiting || (w.request!=1 && w.request!=2)){return .err(errors::make(5,token.begin));}
    let usize i=w.used-1;let bool primary=w.frames[i].minimum==0;
    bank.tail=tails::begin(token,value,result_type,primary);w.frames[i].phase=50;w.waiting=false;w.request=0;return .ok(0);
}
// Child classification does not evaluate or consume the grouped expression.
pub fn Result<usize,errors::Error> group(ref mut State w,u8 context){
    if(w.done || !w.waiting || w.request!=1){return .err(errors::make(5,0));}
    let usize i=w.used-1;w.frames[i].context=context;w.frames[i].phase=10;w.waiting=false;w.request=0;return .ok(0);
}
// minimum==0 is a primary-only child: postfixes precede the unary operation,
// but casts and binary operators belong to the enclosing converted expression.
pub fn Result<usize,errors::Error> unary(ref mut State w,u8 kind,u8 context,usize at){
    if(w.done || !w.waiting || w.request!=1 || (kind!=45 && kind!=33 && kind!=126)){return .err(errors::make(5,at));}
    let usize i=w.used-1;w.frames[i].kind=kind;w.frames[i].context=context;w.frames[i].operand_at=at;
    w.frames[i].phase=40;w.waiting=false;w.request=0;return .ok(0);
}
// The fixed eight-row formal plan is advisory; CALL emission rechecks IR limits.
pub fn Result<usize,errors::Error> call(ref mut State w,usize target,usize arity,ref u8[] tags,usize at){
    if(w.done || !w.waiting || w.request!=1 || target>=16 || arity>8 || tags.len!=8){return .err(errors::make(5,at));}
    let usize index=w.used-1;w.frames[index].target=target;w.frames[index].arity=arity;w.frames[index].operand_at=at;
    var usize i=0;while(i<8){w.parameters[index*8+i]=tags[i];i+=1;}
    w.frames[index].phase=20;w.waiting=false;w.request=0;return .ok(0);
}
// Flat banks avoid nested array-valued frame borrows in the pinned toolchain.
// A CALL stage loads/stores 64 binding rows and eight arguments in fixed scratch.
fn void save_call(ref mut State w,ref mut Bank bank,usize index,ref calls::State active){
    bank.calls[index]=calls::framing(active);var usize row=0;
    while(row<64){let usize slot=row;bank.begins[slot]=active.names.begins[row];bank.ends[slot]=active.names.ends[row];
        bank.registers[slot]=active.names.registers[row];bank.mutability[slot]=active.names.mutable[row];row+=1;}
    row=0;while(row<8){w.arguments[index*8+row]=active.arguments[row];row+=1;}
}
pub fn Result<usize,errors::Error> names_into(ref Bank bank,usize index,ref mut locals::Table names){
    if(index>=34){return .err(errors::make(5,0));}let calls::Frame f=bank.calls[index];
    names.count=f.names_count;names.function=f.names_function;names.pending_places=f.names_pending;
    var usize row=0;while(row<64){let usize slot=row;names.begins[row]=bank.begins[slot];names.ends[row]=bank.ends[slot];
        names.registers[row]=bank.registers[slot];names.mutable[row]=bank.mutability[slot];row+=1;}return .ok(0);
}
fn void save_environment(ref mut Bank bank,usize i,ref locals::Table names){
    bank.calls[i].names_count=names.count;bank.calls[i].names_function=names.function;bank.calls[i].names_pending=names.pending_places;
    var usize row=0;while(row<64){bank.begins[row]=names.begins[row];bank.ends[row]=names.ends[row];bank.registers[row]=names.registers[row];bank.mutability[row]=names.mutable[row];row+=1;}
}
pub fn Result<usize,errors::Error> array_operand(ref mut State w,ref mut Bank bank,usize groups,u8 expected,bool literal,usize binding,usize at){
    if(!w.waiting || w.request!=1 || w.done){return .err(errors::make(5,at));}let usize i=w.used-1;let usize depth=w.frames[i].depth;let usize start=w.cell_used;
    bank.arrays[i]=array_values::begin(at,depth,groups,expected,literal,binding,start);w.frames[i].phase=70;w.waiting=false;w.request=0;return .ok(0);
}
fn Result<usize,errors::Error> load_call(ref State w,ref Bank bank,usize index,ref mut calls::State active){
    let calls::Frame f=bank.calls[index];calls::restore(active,f);let usize copied=names_into(bank,index,ref mut active.names)?;
    var usize row=0;while(row<8){active.arguments[row]=w.arguments[index*8+row];row+=1;}return .ok(0);
}
pub fn Result<usize,errors::Error> captured(ref mut State w,ref mut Bank bank,ref locals::Table names,lexer::State token,usize target,usize at,usize depth){
    if(w.done || !w.waiting || w.request!=1){return .err(errors::make(5,at));}
    let usize i=w.used-1;var calls::State active=calls::begin(names,token,target,at,depth);save_call(w,bank,i,ref active);
    w.frames[i].phase=32;w.waiting=false;w.request=0;return .ok(0);
}
pub fn Result<usize,errors::Error> environment_into(ref State w,ref Bank bank,ref mut locals::Table names){
    let Frame f=current(w);return names_into(bank,f.environment,names);
}
pub fn Result<usize,errors::Error> captured_argument(ref mut State w,ref mut Bank bank,ref locals::Table names,usize value,bool prefix){
    if(w.done || !w.waiting || w.request!=3){return .err(errors::make(5,0));}
    let usize i=w.used-1;var calls::State active=calls::empty();let usize loaded=load_call(w,bank,i,ref mut active)?;
    if(names.count<active.names.count || names.function!=active.names.function){return .err(errors::make(5,0));}
    var usize row=0;while(row<active.names.count){if(names.begins[row]!=active.names.begins[row] || names.ends[row]!=active.names.ends[row] ||
        names.registers[row]!=active.names.registers[row] || names.mutable[row]!=active.names.mutable[row]){return .err(errors::make(5,0));}row+=1;}
    let usize accepted=calls::argument(ref mut active,names,value,prefix)?;save_call(w,bank,i,ref active);
    w.waiting=false;w.request=0;return .ok(accepted);
}
fn Result<bool,errors::Error> take(ref mut State w,ref lexer::State s,u8 kind,u8 phase){
    if(s.kind!=kind){return .err(errors::make(2,s.begin));}
    let usize i=w.used-1;w.frames[i].phase=phase;w.token=tokens::begin(*s);w.lexing=true;return .ok(false);
}
fn u8 precedence(u8 kind) {
    if (kind == 133) { return 1; }
    if (kind == 132) { return 2; }
    if (kind == 124) { return 3; }
    if (kind == 94) { return 4; }
    if (kind == 38) { return 5; }
    if (kind == 128 || kind == 129) { return 6; }
    if (kind == 60 || kind == 62 || kind == 130 || kind == 131) { return 7; }
    if (kind == 134 || kind == 135) { return 8; }
    if (kind == 43 || kind == 45) { return 9; }
    if (kind == 42 || kind == 47 || kind == 37) { return 10; }
    return 0;
}
fn u8 opcode(u8 kind) {
    if (kind == 134) { return 31; }
    if (kind == 135) { return 32; }
    if (kind == 38) { return 28; }
    if (kind == 94) { return 29; }
    if (kind == 124) { return 30; }
    if (kind == 128) { return 11; }
    if (kind == 129) { return 12; }
    if (kind == 60) { return 13; }
    if (kind == 130) { return 14; }
    if (kind == 62) { return 15; }
    if (kind == 131) { return 16; }
    if (kind == 43) { return 2; }
    if (kind == 45) { return 3; }
    if (kind == 42) { return 4; }
    if (kind == 47) { return 5; }
    return 6;
}

// A captured dispatch restores at most 64 lexical rows within the 4096-unit
// conservative stage bound, including a single child advance.
fn Result<bool,errors::Error> projection(ref u8[] source,ref ir::Program p,ref locals::Table names,
    ref functions::Table signatures,ref mut Bank bank,usize environment,ref mut budget::State meter){
    if(environment==34){return aggregates::advance(source,p,names,signatures,ref mut bank.aggregate,meter);}
    var locals::Table active=locals::empty();let usize copied=names_into(bank,environment,ref mut active)?;
    return aggregates::advance(source,p,ref active,signatures,ref mut bank.aggregate,meter);
}
fn void request(ref mut State w,usize caller){w.frames[caller].phase=1;w.waiting=true;w.request=1;}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref locals::Table names,ref functions::Table signatures,ref mut Bank bank,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.waiting){return .ok(false);}
    if(w.lexing){switch(tokens::advance(source,ref mut w.token,meter)){
        case .err(e):{*s=tokens::observed(ref w.token);return .err(e);}
        case .ok(done):{if(done){*s=tokens::prepared(ref w.token)?;w.lexing=false;}return .ok(false);}};}
    let usize caller=w.used-1;
    if(w.frames[caller].phase==60){let bool done=probes::advance(source,ref mut bank.probe,meter)?;
        if(done){w.frames[caller].context=probes::prepared(ref bank.probe)?;let usize depth=w.frames[caller].depth;bank.route=routes::begin(*s,depth);w.frames[caller].phase=61;}return .ok(false);}
    if(w.frames[caller].phase==61){let usize environment=w.frames[caller].environment;var bool done=false;
        if(environment==34){done=routes::advance(source,names,signatures,ref mut bank.route,meter)?;}
        else{var locals::Table active=locals::empty();let usize copied=names_into(bank,environment,ref mut active)?;
            done=routes::advance(source,ref active,signatures,ref mut bank.route,meter)?;}
        if(done){if(bank.route.lane==0 && s.kind==40){bank.syntax=syntax::begin(*s,1);w.frames[caller].phase=62;}
            else if(bank.route.lane==0 && s.kind==91){bank.aggregate=aggregates::begin(*s,3);w.frames[caller].phase=65;}else{request(w,caller);}}return .ok(false);}
    if(w.frames[caller].phase==62){let bool done=syntax::advance(source,ref mut bank.syntax,meter)?;
        if(done){if(syntax::prepared(ref bank.syntax)?){bank.route.lane=5;request(w,caller);}
            else{bank.aggregate=aggregates::begin(*s,1);w.frames[caller].phase=63;}}return .ok(false);}
    if(w.frames[caller].phase>=63 && w.frames[caller].phase<=66){let usize environment=w.frames[caller].environment;
        let bool done=projection(source,p,names,signatures,bank,environment,meter)?;if(!done){return .ok(false);}
        let aggregates::Plan plan=aggregates::prepared(ref bank.aggregate)?;let u8 phase=w.frames[caller].phase;
        if(phase==63){if(plan.kind!=0 && plan.tag!=0){bank.route.lane=6;request(w,caller);}
            else{bank.aggregate=aggregates::begin(*s,2);w.frames[caller].phase=64;}}
        else if(phase==64){if(plan.kind>1 && (plan.suffix==91 || plan.suffix==46)){bank.route.lane=7;request(w,caller);}
            else{bank.aggregate=aggregates::begin(*s,3);w.frames[caller].phase=65;}}
        else if(phase==65){if(plan.suffix==91 || plan.suffix==46){bank.route.lane=8;request(w,caller);}
            else if(s.kind==91){bank.route.lane=10;request(w,caller);}
            else if(signatures.literals.enabled){bank.aggregate=aggregates::begin(*s,4);w.frames[caller].phase=66;}
            else{bank.route.lane=1;request(w,caller);}}
        else{bank.route.lane=if(plan.kind!=0){9}else{1};request(w,caller);}return .ok(false);}

    if(w.frames[caller].phase==71){let bool done=aggregates::advance_syntax(source,names,ref mut bank.aggregate,meter)?;
        if(done){let bool repeated=bank.aggregate.result.kind!=0;bank.arrays[caller].repeated=repeated;w.frames[caller].phase=70;}return .ok(false);}
    if(w.frames[caller].phase==72){let usize value=w.value;bank.arrays[caller].value=value;bank.arrays[caller].request=0;w.frames[caller].phase=70;return .ok(false);}
    if(w.frames[caller].phase==70){let usize environment=w.frames[caller].environment;var locals::Table active=locals::empty();
        if(environment==34){active=locals::snapshot(names);}else{let usize copied=names_into(bank,environment,ref mut active)?;}
        var array_values::Frame a=bank.arrays[caller];let bool done=array_values::advance(source,s,p,ref active,ref mut a,ref mut bank.cells,ref mut w.cell_used,meter)?;
        if(done){w.frames[caller].left=a.value;w.frames[caller].phase=13;}
        else if(a.request==1){a.request=0;w.token=tokens::begin(*s);w.lexing=true;}
        else if(a.request==4){a.request=0;bank.aggregate=aggregates::begin(*s,5);w.frames[caller].phase=71;}
        else if(a.request==3){a.request=0;let usize hidden=locals::declare(ref mut active,a.at,a.at,128+a.id,false)?;save_environment(bank,caller,ref active);}
        else if(a.request==2){if(w.used>=34){return .err(errors::make(4,s.begin));}let usize next=w.used;
            w.frames[next]=frame(a.child_depth,1,a.expected);w.frames[next].environment=if(a.owned && a.phase==26){caller}else{environment};
            w.frames[caller].phase=72;w.used+=1;}
        bank.arrays[caller]=a;return .ok(false);}
    if(w.frames[caller].phase==50){let usize environment=w.frames[caller].environment;var bool done=false;
        if(environment==34){done=tails::advance(source,s,p,names,ref mut bank.tail,meter)?;}
        else{var locals::Table active=locals::empty();let usize copied=names_into(bank,environment,ref mut active)?;
            done=tails::advance(source,s,p,ref active,ref mut bank.tail,meter)?;}
        if(done){w.value=tails::prepared(ref bank.tail)?;w.frames[caller].phase=1;}return .ok(false);}
    if(w.frames[caller].phase==30){var calls::State active=calls::empty();let usize loaded=load_call(w,bank,caller,ref mut active)?;
        let bool done=calls::advance(source,s,p,signatures,ref mut active,meter)?;save_call(w,bank,caller,ref active);
        if(done){w.frames[caller].left=calls::prepared(ref active)?;w.frames[caller].phase=13;}
        else if(active.request==1){if(w.used>=34){return .err(errors::make(4,s.begin));}
            let usize depth=w.frames[caller].depth+1;let u8 tag=active.tag;let usize next=w.used;
            w.frames[caller].phase=31;w.frames[next]=frame(depth,1,tag);w.frames[next].environment=caller;w.used+=1;
        }else if(active.request==2){w.waiting=true;w.request=3;}return .ok(false);}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}
    let usize i=w.used-1;let Frame f=current(w);let usize value=w.value;w.visits+=1;
    if(f.phase==0){
        // Keep the native primary preflight order at the default ceiling.
        let usize limit=signatures.expression_depth;
        if(f.depth>limit && (f.minimum!=0 || limit<32)){return .err(errors::make(4,s.begin));}
        bank.probe=probes::begin(*s,f.expected,f.minimum==0);w.frames[i].phase=60;return .ok(false);}
    if(f.phase==1){w.frames[i].left=value;w.frames[i].phase=2;return .ok(false);}
    if(f.phase==2){if(f.minimum==0 || precedence(s.kind)<f.minimum){w.value=f.left;w.used-=1;w.done=w.used==0;return .ok(w.done);}
        w.frames[i].kind=s.kind;w.frames[i].operation=opcode(s.kind);w.frames[i].at=s.begin;
        w.frames[i].phase=3;w.token=tokens::begin(*s);w.lexing=true;return .ok(false);}
    if(f.phase==3){let bool logical=f.kind==132 || f.kind==133;
        if(logical){if(p.types[f.left]!=2){return .err(errors::make(3,f.at));}
            let usize slot=ir::slot(p,2,f.at)?;let usize initial=ir::raw(p,18,slot,f.left,0,f.at)?;
            let usize jump=ir::raw(p,if(f.kind==132){20}else{21},0,f.left,0,f.at)?;
            w.frames[i].slot=slot;w.frames[i].jump=jump;}
        if(w.used>=34){return .err(errors::make(4,s.begin));}
        let usize next=w.used;let u8 expected=if(logical){f.expected}else{p.types[f.left]};
        w.frames[i].phase=4;w.frames[next]=frame(f.depth+1,precedence(f.kind)+1,expected);w.frames[next].environment=f.environment;w.used+=1;return .ok(false);}
    if(f.phase==4){var usize result=0;
        if(f.kind==132 || f.kind==133){if(p.types[value]!=2){return .err(errors::make(3,f.at));}
            let usize stored=ir::raw(p,18,f.slot,value,0,f.at)?;let usize target=p.count;
            let usize patched=ir::patch(p,f.jump,target,f.at)?;result=ir::emit(p,17,f.slot,0,f.at)?;
        }else{
            if(!types::scalar(p.types[f.left]) || p.types[f.left]!=p.types[value] ||
                ((f.operation<11 || f.operation>12) && !types::integer(p.types[f.left]))){return .err(errors::make(3,f.at));}
            result=ir::emit(p,f.operation,f.left,value,f.at)?;
        }w.frames[i].left=result;w.frames[i].phase=2;return .ok(false);}
    if(f.phase==10){return take(w,s,40,11);}
    if(f.phase==11){if(w.used>=34){return .err(errors::make(4,s.begin));}
        let usize next=w.used;w.frames[i].phase=12;w.frames[next]=frame(f.depth+1,1,f.context);w.frames[next].environment=f.environment;w.used+=1;return .ok(false);}
    if(f.phase==12){w.frames[i].left=value;return take(w,s,41,13);}
    if(f.phase==13){w.value=f.left;w.frames[i].phase=1;w.waiting=true;w.request=2;return .ok(false);}
    if(f.phase==20){return take(w,s,s.kind,21);}
    if(f.phase==21){return take(w,s,40,22);}
    if(f.phase==22){if(s.kind==41){w.frames[i].phase=27;return .ok(false);}
        if(f.count>=8){return .err(errors::make(4,s.begin));}
        if(w.used>=34){return .err(errors::make(4,s.begin));}
        let usize next=w.used;let u8 tag=if(f.count<f.arity){w.parameters[i*8+f.count]}else{0};
        w.frames[i].phase=23;w.frames[next]=frame(f.depth+1,1,tag);w.frames[next].environment=f.environment;w.used+=1;return .ok(false);}
    if(f.phase==23){if(f.count>=f.arity || p.types[value]!=w.parameters[i*8+f.count]){return .err(errors::make(3,f.operand_at));}
        w.arguments[i*8+f.count]=value;w.frames[i].count=f.count+1;w.frames[i].phase=24;return .ok(false);}
    if(f.phase==24){if(s.kind==41){w.frames[i].phase=27;return .ok(false);}return take(w,s,44,25);}
    if(f.phase==25){if(s.kind==41){return .err(errors::make(2,s.begin));}w.frames[i].phase=22;return .ok(false);}
    if(f.phase==27){if(f.count!=f.arity){return .err(errors::make(3,f.operand_at));}return take(w,s,41,28);}
    if(f.phase==28){let usize result=ir::call(p,f.target,ref w.arguments[i*8..i*8+f.count],f.operand_at)?;
        w.frames[i].left=result;w.frames[i].phase=29;return .ok(false);}
    if(f.phase==29){w.value=f.left;w.frames[i].phase=1;w.waiting=true;w.request=2;return .ok(false);}
    if(f.phase==31){var calls::State active=calls::empty();let usize loaded=load_call(w,bank,i,ref mut active)?;let usize accepted=calls::resume(ref mut active,1,value)?;save_call(w,bank,i,ref active);w.frames[i].phase=30;return .ok(false);}
    if(f.phase==32){return take(w,s,s.kind,30);}
    if(f.phase==40){if(f.kind==45 && types::unsigned(f.context)){return .err(errors::make(3,f.operand_at));}
        return take(w,s,f.kind,41);}
    if(f.phase==41){if(f.kind==45 && s.kind==1){
            if(s.min_magnitude){if(f.context!=9){return .err(errors::make(3,f.operand_at));}return take(w,s,1,44);}
            if(s.value==2147483648 && f.context!=9){return take(w,s,1,45);}}
        if(w.used>=34){return .err(errors::make(4,s.begin));}
        let usize next=w.used;w.frames[i].phase=42;w.frames[next]=frame(f.depth+1,0,f.context);w.frames[next].environment=f.environment;w.used+=1;return .ok(false);}
    if(f.phase==42){if((f.kind==45 && !types::signed(p.types[value])) || (f.kind==126 && !types::integer(p.types[value])) ||
            (f.kind==33 && p.types[value]!=2)){return .err(errors::make(3,f.operand_at));}
        w.frames[i].left=value;w.frames[i].phase=43;return .ok(false);}
    if(f.phase==43){let usize result=ir::emit(p,if(f.kind==45){7}else if(f.kind==126){27}else{10},f.left,0,f.operand_at)?;
        w.frames[i].left=result;w.frames[i].phase=13;return .ok(false);}
    if(f.phase==44 || f.phase==45){let usize result=if(f.phase==44){ir::integer(p,-9223372036854775808,9,f.operand_at)?}else{ir::literal(p,-2147483648,f.operand_at)?};
        w.frames[i].left=result;w.frames[i].phase=13;return .ok(false);}
    return .err(errors::make(5,s.begin));
}
