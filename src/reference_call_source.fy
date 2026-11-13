module reference_call_source;
import functions as functions;
import lexer as lexer;
import locals as locals;
import ir as ir;
import static_source as statics;
import static_builders as builders;
import errors as errors;
import argument_name_work as names_work;

pub fn bool parameter(ref functions::Table signatures,usize at){
    return signatures.reference_calls && at<128 && signatures.param_slices[at] && signatures.param_slice_elements[at]==10;
}
pub fn bool target(ref functions::Table signatures,usize f){
    if(f>=signatures.count){return false;}var usize i=0;
    while(i<signatures.arities[f]){if(parameter(signatures,f*8+i)){return true;}i+=1;}return false;
}
pub fn Result<usize,errors::Error> bind(ref functions::Table signatures,usize at,ref mut ir::Program p,ref mut locals::Table names){
    if(!parameter(signatures,at)){return .err(errors::make(3,0));}
    let usize site=builders::parameter(p,signatures.param_begins[at])?;
    return locals::declare(names,signatures.param_begins[at],signatures.param_ends[at],192+site,false);
}
// Pure lookahead leaves ordinary rooted/formal/owned temporary captures on their
// established path. Actual view lowering still requires explicit shared access.
pub fn Result<bool,errors::Error> image_argument_raw(ref u8[] source,ref lexer::State s,ref locals::Table names){
    if(s.kind!=2 || !lexer::equal(source[s.begin..s.end],b"ref")){return .ok(false);}
    var lexer::State look=lexer::snapshot(s);let usize prefix=lexer::next(source,ref mut look)?;
    if(look.kind==3 || look.kind==4 || look.kind==40){return .ok(true);}
    if(look.kind!=2){return .ok(false);}
    if(statics::binding(names,locals::find(source,names,look.begin,look.end))){return .ok(true);}
    if(!lexer::equal(source[look.begin..look.end],b"text")){return .ok(false);}
    let usize next=lexer::next(source,ref mut look)?;return .ok(look.kind==58);
}
pub fn Result<bool,errors::Error> image_argument(ref u8[] source,ref lexer::State s,ref locals::Table names){
    if(s.kind!=2 || !lexer::equal(source[s.begin..s.end],b"ref")){return .ok(false);}
    var lexer::State look=lexer::snapshot(s);let usize prefix=lexer::next(source,ref mut look)?;
    if(look.kind==3 || look.kind==4 || look.kind==40){return .ok(true);}
    if(look.kind!=2){return .ok(false);}
    if(statics::binding(names,names_work::local(source,names,look.begin,look.end)?)){return .ok(true);}
    if(!lexer::equal(source[look.begin..look.end],b"text")){return .ok(false);}
    let usize next=lexer::next(source,ref mut look)?;return .ok(look.kind==58);
}
// Existing CALL builders own checked arity/register/aggregate construction. Only
// a generic target changes opcode after the exact CALL has been emitted.
pub fn Result<usize,errors::Error> promote(ref mut ir::Program p,usize pc,usize offset){
    if(pc>=p.count || p.code[pc*8]!=9){return .err(errors::make(3,offset));}
    p.code[pc*8]=78;return .ok(pc);
}

pub fn bool result(ref functions::Table signatures,usize f){
    return signatures.reference_returns && f<signatures.count && signatures.return_slice_elements[f]==10;
}
pub fn Result<bool,errors::Error> returned_atom_raw(ref u8[] source,ref lexer::State s,ref locals::Table names,ref functions::Table signatures){
    var lexer::State look=lexer::snapshot(s);
    if(look.kind==2 && lexer::equal(source[look.begin..look.end],b"ref")){let usize prefix=lexer::next(source,ref mut look)?;}
    if((look.kind!=2 && look.kind!=5) || locals::find(source,names,look.begin,look.end)!=64){return .ok(false);}
    let usize f=functions::find(source,signatures,look.begin,look.end);if(!result(signatures,f)){return .ok(false);}
    let usize next=lexer::next(source,ref mut look)?;return .ok(look.kind==40);
}
pub fn Result<bool,errors::Error> returned_atom(ref u8[] source,ref lexer::State s,ref locals::Table names,ref functions::Table signatures){
    var lexer::State look=lexer::snapshot(s);
    if(look.kind==2 && lexer::equal(source[look.begin..look.end],b"ref")){let usize prefix=lexer::next(source,ref mut look)?;}
    if((look.kind!=2 && look.kind!=5) || names_work::local(source,names,look.begin,look.end)?!=64){return .ok(false);}
    let usize f=names_work::target(source,signatures,look.begin,look.end)?;if(!result(signatures,f)){return .ok(false);}
    let usize next=lexer::next(source,ref mut look)?;return .ok(look.kind==40);
}
pub fn Result<bool,errors::Error> declaration(ref u8[] source,ref lexer::State s,ref locals::Table names,ref functions::Table signatures){
    if(!signatures.reference_returns){return .ok(false);}
    var lexer::State look=lexer::snapshot(s);let usize prefix=lexer::next(source,ref mut look)?;
    if(look.kind!=2 || !lexer::equal(source[look.begin..look.end],b"u8")){return .ok(false);}
    let usize tag=lexer::next(source,ref mut look)?;
    if(look.kind!=91){return .ok(false);}let usize open=lexer::next(source,ref mut look)?;
    if(look.kind!=93){return .ok(false);}let usize close=lexer::next(source,ref mut look)?;
    if(look.kind!=2){return .ok(false);}let usize name=lexer::next(source,ref mut look)?;
    if(look.kind!=61){return .ok(false);}let usize equal=lexer::next(source,ref mut look)?;
    return returned_atom(source,ref look,names,signatures);
}
