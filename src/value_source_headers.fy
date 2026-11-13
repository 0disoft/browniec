module value_source_headers;
import value_ir as values;
import lexer as lexer;
import value_probe_work as probes;
import ir as ir;
import errors as errors;
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
// Match the existing pure scalar classic-for contract before emitting anything.
// Nested parentheses are permitted; source control, calls and typed projections
// are not. This lookahead validates no IR and never grants source authority.
pub fn Result<usize,errors::Error> pure_raw(ref u8[] source,ref lexer::State cursor,u8 terminator){
    var lexer::State look=lexer::snapshot(cursor);var usize parens=0;var bool name=false;
    while(look.kind!=0){
        if(parens==0 && look.kind==terminator){return .ok(look.begin);}
        if(look.kind==63 || look.kind==46 || look.kind==58 || look.kind==91 || look.kind==123 ||
            word(source,ref look,b"if") || word(source,ref look,b"switch") || word(source,ref look,b"while") ||
            word(source,ref look,b"for") || word(source,ref look,b"return") || word(source,ref look,b"break") ||
            word(source,ref look,b"continue") || word(source,ref look,b"ref")){
            return .err(errors::make(3,look.begin));
        }
        if(look.kind==40){if(name){return .err(errors::make(3,look.begin));}parens+=1;}
        else if(look.kind==41){if(parens==0){return .err(errors::make(2,look.begin));}parens-=1;}
        name=look.kind==2;let usize next=lexer::next(source,ref mut look)?;
    }return .err(errors::make(2,look.begin));
}
pub struct Scratch { usize code; usize registers; usize constants; }
pub fn Scratch scratch(ref values::Program unit){let ref ir::Program body=ref unit.body;
    return Scratch{.code=body.count,.registers=body.registers,.constants=body.constant_count};}
// Only pure scalar post-validation uses this scratch rollback. It never rewinds
// a typed slot, name, owner, CALL, snapshot or native allocator.
pub fn Result<usize,errors::Error> rewind(ref mut values::Program unit,Scratch before,usize at){
    let ref mut ir::Program p=ref mut unit.body;
    if(before.code>p.count || p.count>256 || before.registers>p.registers || p.registers>128 ||
        before.constants>p.constant_count || p.constant_count>128){return .err(errors::make(3,at));}
    var usize i=before.registers;while(i<p.registers){p.types[i]=0;p.slots[i]=false;i+=1;}
    i=before.constants;while(i<p.constant_count){p.constants[i]=0;i+=1;}
    i=before.code;while(i<p.count){var usize byte=i*8;while(byte<(i+1)*8){p.code[byte]=0;byte+=1;}p.offsets[i]=0;i+=1;}
    p.count=before.code;p.registers=before.registers;p.constant_count=before.constants;return .ok(before.code);
}

pub fn Result<usize,errors::Error> pure(ref u8[] source,ref lexer::State cursor,u8 terminator){
    if(source.len>4096){return pure_raw(source,cursor,terminator);}return probes::prepare(source,cursor,4,terminator);
}
