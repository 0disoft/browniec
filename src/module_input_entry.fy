module module_input_entry;
import module_index as modules;
import source_snapshot as sources;
import lexer as lexer;
import locals as locals;

// Private native input signature admission, owning the exact immutable Index.
// This is not body/type/ownership proof or executable Program admission.
pub resource InputEntry { modules::Index index; usize selected; sources::Span signature; sources::Span parameter; sources::Span name; cleanup { } }
struct Checked { usize selected; sources::Span signature; sources::Span parameter; sources::Span name; }
fn modules::Error error(modules::Failure kind,sources::Span at){return modules::Error{.kind=kind,.at=at};}
fn sources::Span token(usize id,ref lexer::State s){return sources::Span{.source=id,.start=s.begin,.end=s.end};}
fn Result<usize,modules::Error> next(ref u8[] source,usize id,ref mut lexer::State s){
    return switch(lexer::next(source,s)){
        case .ok(v):{.ok(v)}
        case .err(e):{.err(error(if(e.kind==4){.Limit}else{.Lexical},
            sources::Span{.source=id,.start=e.offset,.end=if(e.offset<source.len){e.offset+1}else{e.offset}}))}
    };
}
fn Result<usize,modules::Error> word(ref u8[] source,usize id,ref mut lexer::State s,ref u8[] expected){
    if(s.kind!=2 || !lexer::equal(source[s.begin..s.end],expected)){return .err(error(.Kind,token(id,s)));}
    return next(source,id,s);
}
fn Result<usize,modules::Error> punctuation(ref u8[] source,usize id,ref mut lexer::State s,u8 expected){
    if(s.kind!=expected){return .err(error(.Kind,token(id,s)));}return next(source,id,s);
}
fn Result<Checked,modules::Error> signature(ref modules::Index index,usize selected){
    let modules::Symbol declaration=modules::symbol(index,selected)?;
    let ref sources::Snapshot snapshot=modules::snapshot(index);
    let sources::Span whole=switch(sources::whole(snapshot,declaration.owner)){
        case .ok(v):{v}case .err(_):{return .err(error(.Bounds,declaration.definition));}
    };
    let ref u8[] original=switch(sources::view(snapshot,whole)){
        case .ok(v):{v}case .err(_):{return .err(error(.Bounds,declaration.definition));}
    };
    // Retain original file-relative offsets; the fence excludes later declarations.
    let sources::Span definition=declaration.definition;
    if(definition.source!=declaration.owner || definition.start>definition.end || definition.end>original.len){
        return .err(error(.Bounds,definition));
    }
    let ref u8[] source=original[..definition.end];
    var lexer::State s=lexer::empty();s.cursor=definition.start;
    let usize first=next(source,declaration.owner,ref mut s)?;
    let usize public=word(source,declaration.owner,ref mut s,b"pub")?;
    let usize function=word(source,declaration.owner,ref mut s,b"fn")?;
    let usize result=word(source,declaration.owner,ref mut s,b"i32")?;
    if(s.kind!=2 || s.begin!=declaration.name.start || s.end!=declaration.name.end){
        return .err(error(.Kind,token(declaration.owner,ref s)));
    }
    let usize name=next(source,declaration.owner,ref mut s)?;
    let usize open=punctuation(source,declaration.owner,ref mut s,40)?;
    let usize parameter_start=s.begin;
    let usize reference=word(source,declaration.owner,ref mut s,b"ref")?;
    let usize byte=word(source,declaration.owner,ref mut s,b"u8")?;
    let usize array_open=punctuation(source,declaration.owner,ref mut s,91)?;
    let usize array_close=punctuation(source,declaration.owner,ref mut s,93)?;
    if(s.kind!=2 || locals::reserved(source[s.begin..s.end])){
        return .err(error(.Kind,token(declaration.owner,ref s)));
    }
    let sources::Span parameter_name=token(declaration.owner,ref s);
    let sources::Span parameter=sources::Span{.source=definition.source,.start=parameter_start,.end=s.end};
    let usize parameter_end=next(source,declaration.owner,ref mut s)?;
    let usize close=punctuation(source,declaration.owner,ref mut s,41)?;
    if(s.kind!=123){return .err(error(.Kind,token(declaration.owner,ref s)));}
    return .ok(Checked{.selected=selected,.signature=sources::Span{.source=definition.source,.start=definition.start,.end=s.begin},
        .parameter=parameter,.name=parameter_name});
}
// Exactly one named shared byte slice. Ordinary helpers remain unrestricted.
// Signature admission is not executable lowering, input binding or body proof.
fn Result<Checked,modules::Error> checked(ref modules::Index index,ref u8[] path,ref u8[] name){
    let usize selected=modules::entry(index,path,name)?;
    return signature(index,selected);
}
pub fn bool has_i32_input(ref modules::Index index,ref u8[] path,ref u8[] name){
    return checked(index,path,name).is_ok;
}
pub fn bool has_i32_input_symbol(ref modules::Index index,usize selected){
    return signature(index,selected).is_ok;
}
pub fn Result<InputEntry,modules::Error> select_i32_input(modules::Index index,ref u8[] path,ref u8[] name){
    let usize selected=modules::entry(ref index,path,name)?;
    return select_i32_input_symbol(index,selected);
}
pub fn Result<InputEntry,modules::Error> select_i32_input_symbol(modules::Index index,usize selected){
    let Checked proof=signature(ref index,selected)?;
    return .ok(InputEntry{.index=index,.selected=proof.selected,.signature=proof.signature,
        .parameter=proof.parameter,.name=proof.name});
}
pub fn ref modules::Index index(ref InputEntry entry){return ref entry.index;}
pub fn usize selected(ref InputEntry entry){return entry.selected;}
pub fn sources::Span signature_span(ref InputEntry entry){return entry.signature;}
pub fn sources::Span parameter_span(ref InputEntry entry){return entry.parameter;}
pub fn sources::Span parameter_name_span(ref InputEntry entry){return entry.name;}
