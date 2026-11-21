module module_index;
import source_snapshot as sources;
import lexer as lexer;
import locals as locals;
import std::bytes as bytes;
import std::vec as vec;

// Sealed header/name binding, not typed executable admission. Every span refers
// to the exact Snapshot moved into Index. No filesystem or builtin fallback.
pub enum Failure { Lexical; Syntax; Limit; Duplicate; Missing; Private; Reserved; Bounds; Kind; Allocation; }
pub struct Error { Failure kind; sources::Span at; }
pub struct Module { sources::Span path; usize begin; usize end; }
pub struct Import { usize owner; usize target; sources::Span alias; sources::Span path; usize begin; usize end; }
pub struct Symbol { usize owner; u8 kind; bool exported; sources::Span name; sources::Span definition; }
struct Path { sources::Span at; usize begin; usize end; }
struct Table {
    u8[4096] names; usize used;
    Module[16] modules; Import[64] imports; Symbol[48] symbols;
    usize count; usize import_count; usize symbol_count; usize functions; usize records;
}
// Large immutable binding data stays behind one private typed owner.
resource Stored { sources::Snapshot sources; Table table; cleanup { } }
pub resource Index { vec::Vec<Stored> stored; cleanup { } }
fn Error error(Failure kind,sources::Span at){return Error{.kind=kind,.at=at};}
fn Table empty(){
    let sources::Span none=sources::no_source();
    return Table{.names=[0;4096],.used=0,
        .modules=[Module{.path=none,.begin=0,.end=0};16],
        .imports=[Import{.owner=16,.target=16,.alias=none,.path=none,.begin=0,.end=0};64],
        .symbols=[Symbol{.owner=16,.kind=0,.exported=false,.name=none,.definition=none};48],
        .count=0,.import_count=0,.symbol_count=0,.functions=0,.records=0};
}
fn sources::Span span(usize id,usize begin,usize end){return sources::Span{.source=id,.start=begin,.end=end};}
fn sources::Span token(usize id,ref lexer::State s){return span(id,s.begin,s.end);}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] value){return s.kind==2 && lexer::equal(source[s.begin..s.end],value);}
fn Result<usize,Error> next(ref u8[] source,usize id,ref mut lexer::State s){
    return switch(lexer::next(source,s)){
        case .ok(v):{.ok(v)}case .err(e):{.err(error(if(e.kind==4){.Limit}else{.Lexical},
            span(id,e.offset,if(e.offset<source.len){e.offset+1}else{e.offset})))}
    };
}
fn Result<usize,Error> punctuation(ref u8[] source,usize id,ref mut lexer::State s,u8 expected){
    if(s.kind!=expected){return .err(error(.Syntax,token(id,s)));}return next(source,id,s);
}
fn Result<Path,Error> path(ref u8[] source,usize id,ref mut lexer::State s,ref mut Table t){
    let usize begin=t.used;let usize start=s.begin;var usize end=start;var bool first=true;
    while(true){
        if(s.kind!=2 || locals::reserved(source[s.begin..s.end])){return .err(error(.Syntax,token(id,s)));}
        let usize size=s.end-s.begin;let usize separator=if(first){0}else{2};
        if(separator>128-(t.used-begin) || size>128-(t.used-begin)-separator ||
            separator>4096-t.used || size>4096-t.used-separator){return .err(error(.Limit,token(id,s)));}
        let usize at=t.used;
        if(!first){t.names[at]=58;t.names[at+1]=58;}
        let usize start=at+separator;
        var usize i=0;while(i<size){t.names[start+i]=source[s.begin+i];i+=1;}
        t.used=start+size;end=s.end;first=false;
        let usize advanced=next(source,id,s)?;
        if(s.kind!=58){break;}
        let usize a=next(source,id,s)?;let usize b=punctuation(source,id,s,58)?;
    }
    return .ok(Path{.at=span(id,start,end),.begin=begin,.end=t.used});
}
fn Result<usize,Error> body(ref u8[] source,usize id,ref mut lexer::State s){
    let usize open=punctuation(source,id,s,123)?;var usize depth=1;
    while(depth!=0){
        if(s.kind==0){return .err(error(.Syntax,token(id,s)));}
        if(s.kind==123){depth+=1;if(depth>33){return .err(error(.Limit,token(id,s)));}}
        if(s.kind==125){depth-=1;if(depth==0){let usize end=s.end;let usize advanced=next(source,id,s)?;return .ok(end);}}
        let usize advanced=next(source,id,s)?;
    }
    return .err(error(.Syntax,token(id,s)));
}
fn Result<usize,Error> declaration(ref u8[] source,usize id,ref mut lexer::State s,ref mut Table t){
    let usize begin=s.begin;var bool exported=false;
    if(word(source,s,b"pub")){exported=true;let usize advanced=next(source,id,s)?;}
    let bool function=word(source,s,b"fn");
    if(!function && !word(source,s,b"struct")){return .err(error(.Syntax,token(id,s)));}
    if(t.symbol_count==48 || (function && t.functions==16) || (!function && t.records==32)){return .err(error(.Limit,token(id,s)));}
    let usize advanced=next(source,id,s)?;var sources::Span name=token(id,s);
    if(function){
        var u8 previous=0;
        while(s.kind!=40){
            if(s.kind==0 || s.kind==123 || s.kind==125 || s.kind==59){return .err(error(.Syntax,token(id,s)));}
            if(s.kind==2){name=token(id,s);}previous=s.kind;let usize advanced=next(source,id,s)?;
        }
        if(previous!=2 || locals::reserved(source[name.start..name.end])){return .err(error(.Syntax,name));}
        var usize depth=1;let usize advanced=next(source,id,s)?;
        while(depth!=0){
            if(s.kind==0 || s.kind==123 || s.kind==125 || s.kind==59){return .err(error(.Syntax,token(id,s)));}
            if(s.kind==40){depth+=1;if(depth>32){return .err(error(.Limit,token(id,s)));}}
            if(s.kind==41){depth-=1;}
            let usize advanced=next(source,id,s)?;
        }
    }else{
        if(s.kind!=2 || locals::reserved(source[s.begin..s.end])){return .err(error(.Syntax,token(id,s)));}
        let usize advanced=next(source,id,s)?;
    }
    if(name.end-name.start>64){return .err(error(.Limit,name));}
    var usize i=0;while(i<t.symbol_count){let Symbol prior=t.symbols[i];
        if(prior.owner==id && bytes::equal(source[name.start..name.end],source[prior.name.start..prior.name.end])){return .err(error(.Duplicate,name));}i+=1;
    }
    let usize end=body(source,id,s)?;
    let usize at=t.symbol_count;t.symbols[at]=Symbol{.owner=id,.kind=if(function){1}else{2},.exported=exported,
        .name=name,.definition=span(id,begin,end)};t.symbol_count=at+1;
    if(function){t.functions+=1;}else{t.records+=1;}return .ok(at);
}
fn Result<usize,Error> file(ref u8[] source,usize id,ref mut Table t,bool host){
    var lexer::State s=lexer::empty();let usize first=next(source,id,ref mut s)?;
    if(!word(source,ref s,b"module")){return .err(error(.Syntax,token(id,ref s)));}
    let usize advanced=next(source,id,ref mut s)?;
    let bool reserved=word(source,ref s,b"std") || word(source,ref s,b"brownie") || (host && word(source,ref s,b"host"));
    let Path name=path(source,id,ref mut s,t)?;
    if(reserved){return .err(error(.Reserved,name.at));}
    let usize semicolon=punctuation(source,id,ref mut s,59)?;
    let ref u8[] names=ref t.names;
    var usize i=0;while(i<t.count){let Module prior=t.modules[i];
        if(bytes::equal(names[name.begin..name.end],names[prior.begin..prior.end])){return .err(error(.Duplicate,name.at));}i+=1;
    }
    t.modules[id]=Module{.path=name.at,.begin=name.begin,.end=name.end};t.count+=1;
    var bool declarations=false;
    while(s.kind!=0){
        if(word(source,ref s,b"import") && !declarations){
            if(t.import_count==64){return .err(error(.Limit,token(id,ref s)));}
            let usize advance_1=next(source,id,ref mut s)?;let Path target=path(source,id,ref mut s,t)?;
            if(!word(source,ref s,b"as")){return .err(error(.Syntax,token(id,ref s)));}
            let usize advance_2=next(source,id,ref mut s)?;
            if(s.kind!=2 || locals::reserved(source[s.begin..s.end]) || (host && word(source,ref s,b"host"))){return .err(error(.Syntax,token(id,ref s)));}
            let sources::Span alias=token(id,ref s);if(alias.end-alias.start>64){return .err(error(.Limit,alias));}
            i=0;while(i<t.import_count){let Import prior=t.imports[i];
                if(prior.owner==id && bytes::equal(source[alias.start..alias.end],source[prior.alias.start..prior.alias.end])){return .err(error(.Duplicate,alias));}i+=1;
            }
            let usize advance_3=next(source,id,ref mut s)?;let usize semicolon=punctuation(source,id,ref mut s,59)?;
            let usize at=t.import_count;
            t.imports[at]=Import{.owner=id,.target=16,.alias=alias,.path=target.at,.begin=target.begin,.end=target.end};t.import_count=at+1;
        }else{declarations=true;let usize added=declaration(source,id,ref mut s,t)?;}
    }
    return .ok(s.tokens);
}
fn Result<usize,Error> prepare(ref sources::Snapshot snapshot,ref mut Table t,bool host,usize token_limit){
    let usize count=sources::count(snapshot);if(count==0){return .err(error(.Missing,sources::no_source()));}
    var usize id=0;var usize tokens=0;
    while(id<count){
        let sources::Span all=switch(sources::whole(snapshot,id)){case .ok(v):{v}case .err(_):{return .err(error(.Bounds,sources::no_source()));}};
        let ref u8[] source=switch(sources::view(snapshot,all)){case .ok(v):{v}case .err(_):{return .err(error(.Bounds,all));}};
        let usize scanned=file(source,id,t,host)?;
        let usize used=if(host){scanned-1}else{scanned};
        if(used>token_limit-tokens){return .err(error(.Limit,span(id,source.len,source.len)));}tokens+=used;id+=1;
    }
    var Import[64] bound=t.imports;
    let ref u8[] names=ref t.names;
    var usize i=0;while(i<t.import_count){let Import candidate=t.imports[i];var usize target=16;id=0;
        while(id<t.count){let Module m=t.modules[id];if(bytes::equal(names[candidate.begin..candidate.end],names[m.begin..m.end])){target=id;break;}id+=1;}
        if(target==16 && !(host && candidate.end-candidate.begin>6 &&
            bytes::equal(names[candidate.begin..candidate.begin+6],b"host::"))){
            return .err(error(.Missing,candidate.path));
        }
        bound[i]=Import{.owner=candidate.owner,.target=target,.alias=candidate.alias,.path=candidate.path,.begin=candidate.begin,.end=candidate.end};i+=1;
    }
    t.imports=bound;
    return .ok(t.count);
}
pub fn Result<Index,Error> build(sources::Snapshot snapshot){
    return build_mode(snapshot,false,1024);
}
pub fn Result<Index,Error> build_host(sources::Snapshot snapshot,usize token_limit){
    return build_mode(snapshot,true,if(token_limit<1024){token_limit}else{1024});
}
fn Result<Index,Error> build_mode(sources::Snapshot snapshot,bool host,usize token_limit){
    var Table t=empty();let usize ready=prepare(ref snapshot,ref mut t,host,token_limit)?;
    var vec::Vec<Stored> stored=vec::empty<Stored>();
    let usize capacity=switch(vec::reserve<Stored>(ref mut stored,1)){
        case .ok(v):{v}case .err(_):{return .err(error(.Allocation,sources::no_source()));}
    };
    let usize count=switch(vec::push<Stored>(ref mut stored,Stored{.sources=snapshot,.table=t})){
        case .ok(v):{v}case .err(_):{return .err(error(.Allocation,sources::no_source()));}
    };
    return .ok(Index{.stored=stored});
}
fn ref Stored stored(ref Index p){return vec::at<Stored>(ref p.stored,0);}
pub fn ref sources::Snapshot snapshot(ref Index p){return ref stored(p).sources;}
fn ref Table table(ref Index p){return ref stored(p).table;}
pub fn usize count(ref Index p){return table(p).count;}
pub fn usize symbol_count(ref Index p){return table(p).symbol_count;}
pub fn usize import_count(ref Index p){return table(p).import_count;}
pub fn Result<Import,Error> import_at(ref Index p,usize id){
    let ref Table t=table(p);if(id>=t.import_count){return .err(error(.Bounds,sources::no_source()));}return .ok(t.imports[id]);
}
pub fn Result<ref u8[],Error> import_path(ref Index p,usize id){
    let Import item=import_at(p,id)?;let ref Table t=table(p);let ref u8[] names=ref t.names;
    return .ok(names[item.begin..item.end]);
}
pub fn Result<Module,Error> module_at(ref Index p,usize id){
    let ref Table t=table(p);if(id>=t.count){return .err(error(.Bounds,sources::no_source()));}return .ok(t.modules[id]);
}
pub fn Result<Symbol,Error> symbol(ref Index p,usize id){
    let ref Table t=table(p);if(id>=t.symbol_count){return .err(error(.Bounds,sources::no_source()));}return .ok(t.symbols[id]);
}
pub fn Result<ref u8[],Error> module_name(ref Index p,usize id){
    let Module m=module_at(p,id)?;let ref Table t=table(p);let ref u8[] names=ref t.names;return .ok(names[m.begin..m.end]);
}
// Embedding source identities are canonical module names in caller order.
pub fn Result<usize,Error> match_source_names(ref Index p){
    let ref sources::Snapshot input=snapshot(p);
    let usize count=count(p);
    var usize row=0;
    while(row<count){
        let Module declared=module_at(p,row)?;
        let ref u8[] actual=module_name(p,row)?;
        let ref u8[] supplied=switch(sources::name(input,row)){
            case .ok(v):{v}case .err(_):{return .err(error(.Bounds,declared.path));}
        };
        if(!bytes::equal(actual,supplied)){return .err(error(.Kind,declared.path));}
        row+=1;
    }
    return .ok(count);
}
pub fn Result<usize,Error> find(ref Index p,ref u8[] path){
    let ref Table t=table(p);let ref u8[] names=ref t.names;var usize i=0;
    while(i<t.count){let Module m=t.modules[i];if(bytes::equal(path,names[m.begin..m.end])){return .ok(i);}i+=1;}
    return .err(error(.Missing,sources::no_source()));
}
fn bool matches(ref Index p,sources::Span span,ref u8[] name){
    return switch(sources::view(snapshot(p),span)){case .ok(v):{bytes::equal(v,name)}case .err(_):{false}};
}
pub fn Result<usize,Error> resolve(ref Index p,usize caller,ref u8[] qualifier,ref u8[] name){
    let ref Table t=table(p);if(caller>=t.count){return .err(error(.Bounds,sources::no_source()));}
    var usize target=caller;var usize i=0;
    if(qualifier.len!=0){target=16;
        while(i<t.import_count){let Import candidate=t.imports[i];
            if(candidate.owner==caller && matches(p,candidate.alias,qualifier)){target=candidate.target;break;}i+=1;
        }
        if(target==16){return .err(error(.Missing,t.modules[caller].path));}
    }
    i=0;while(i<t.symbol_count){let Symbol candidate=t.symbols[i];
        if(candidate.owner==target && matches(p,candidate.name,name)){
            if(target!=caller && !candidate.exported){return .err(error(.Private,candidate.name));}return .ok(i);
        }i+=1;
    }
    return .err(error(.Missing,t.modules[caller].path));
}
// Binding only: the full compiler must still check entry parameter/result types.
pub fn Result<usize,Error> entry(ref Index p,ref u8[] path,ref u8[] name){
    let usize owner=find(p,path)?;let usize id=resolve(p,owner,b"",name)?;let Symbol selected=symbol(p,id)?;
    if(selected.kind!=1){return .err(error(.Kind,selected.name));}
    if(!selected.exported){return .err(error(.Private,selected.name));}return .ok(id);
}
