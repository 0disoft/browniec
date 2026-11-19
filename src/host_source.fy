module host_source;

import errors as errors;
import host_catalog as catalog;
import host_program as programs;
import ir as ir;
import lexer as lexer;

pub struct Name { usize begin; usize scope_end; usize symbol; usize end; }

pub fn Result<bool,errors::Error> qualified(ref u8[] source,ref lexer::State s){
    if(s.kind!=2 || !lexer::equal(source[s.begin..s.end],b"host")){return .ok(false);}
    var lexer::State next=lexer::snapshot(s);
    let usize read=lexer::next(source,ref mut next)?;
    return .ok(next.kind==58);
}

pub fn Result<Name,errors::Error> name(ref u8[] source,ref mut lexer::State s){
    let usize begin=s.begin;
    let usize root=lexer::word(source,s,b"host")?;
    var usize scope_end=s.begin;
    var usize segments=0;
    while(s.kind==58){
        scope_end=s.begin;
        let usize colon=lexer::punctuation(source,s,58)?;
        let usize separator=lexer::punctuation(source,s,58)?;
        if(s.kind!=2){return .err(errors::make(2,s.begin));}
        let usize symbol=s.begin;
        let usize end=s.end;
        let usize next=lexer::next(source,s)?;
        segments+=1;
        if(s.kind!=58){
            if(segments<2 || s.kind!=40){return .err(errors::make(2,s.begin));}
            return .ok(Name{.begin=begin,.scope_end=scope_end,.symbol=symbol,.end=end});
        }
    }
    return .err(errors::make(2,s.begin));
}

fn Result<u8,errors::Error> import_id(ref u8[] source,Name item,ref catalog::Catalog imports){
    var u8 id=0;
    while((id as usize)<catalog::count(imports)){
        let usize i=id as usize;
        let ref u8[] scope=switch(catalog::module_name(imports,i)){case .ok(v):{v}case .err(_):{assert(false);b""}};
        let ref u8[] symbol=switch(catalog::symbol(imports,i)){case .ok(v):{v}case .err(_):{assert(false);b""}};
        if(lexer::equal(scope,source[item.begin..item.scope_end]) && lexer::equal(symbol,source[item.symbol..item.end])){
            if(!programs::scalar_signature(imports,i)){return .err(errors::make(3,item.begin));}
            return .ok(id);
        }
        id+=1;
    }
    return .err(errors::make(3,item.begin));
}

// Candidate offsets are authored by the source lowerer. Resolve them before the
// independent host verifier sees the Program or any authority is retained.
pub fn Result<usize,errors::Error> bind(ref u8[] source,ref mut ir::Program code,ref catalog::Catalog imports){
    var usize pc=0;
    while(pc<code.count){
        let usize at=pc*8;
        if(code.code[at]==programs::request_opcode()){
            var lexer::State s=lexer::empty();
            s.cursor=code.offsets[pc];
            let usize first=lexer::next(source,ref mut s)?;
            let Name item=name(source,ref mut s)?;
            code.code[at+3]=import_id(source,item,imports)?;
        }
        pc+=1;
    }
    return .ok(pc);
}
