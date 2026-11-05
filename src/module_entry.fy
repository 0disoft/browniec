module module_entry;
import module_index as modules;
import source_snapshot as sources;
import lexer as lexer;

// A selected entry signature, bound to the exact immutable Index it owns.
// This is not body/type/ownership proof or executable Program admission.
pub resource Entry { modules::Index index; usize selected; sources::Span signature; cleanup { } }
struct Checked { usize selected; sources::Span signature; }
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
fn Result<sources::Span,modules::Error> signature(ref modules::Index index,usize selected){
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
    let usize close=punctuation(source,declaration.owner,ref mut s,41)?;
    if(s.kind!=123){return .err(error(.Kind,token(declaration.owner,ref s)));}
    return .ok(sources::Span{.source=definition.source,.start=definition.start,.end=s.begin});
}
// Explicit first-profile convention: public zero-argument i32, any selected name.
// Unsupported entry ABIs do not restrict ordinary helper declarations in Index.
fn Result<Checked,modules::Error> checked(ref modules::Index index,ref u8[] path,ref u8[] name){
    let usize selected=modules::entry(index,path,name)?;
    let sources::Span signature=signature(index,selected)?;
    return .ok(Checked{.selected=selected,.signature=signature});
}
pub fn Result<Entry,modules::Error> select_i32(modules::Index index,ref u8[] path,ref u8[] name){
    let Checked proof=checked(ref index,path,name)?;
    return .ok(Entry{.index=index,.selected=proof.selected,.signature=proof.signature});
}
pub fn ref modules::Index index(ref Entry entry){return ref entry.index;}
pub fn usize selected(ref Entry entry){return entry.selected;}
pub fn sources::Span signature_span(ref Entry entry){return entry.signature;}
