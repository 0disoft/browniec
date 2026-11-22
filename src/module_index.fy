module module_index;
import source_snapshot as sources;
import lexer as lexer;
import lexer_work as staged;
import errors as errors;
import runtime_clock as clock;
import metadata_budget as budget;
import locals as locals;
import std::bytes as bytes;
import std::vec as vec;

// Sealed header/name binding, not typed executable admission. Every span refers
// to the exact Snapshot moved into Index. No filesystem or builtin fallback.
pub enum Failure { Lexical; Syntax; Limit; Duplicate; Missing; Private; Reserved; Bounds; Kind; Allocation; Deadline; }
pub struct Error { Failure kind; sources::Span at; }
pub struct Module { sources::Span path; usize begin; usize end; }
pub struct Import { usize owner; usize target; sources::Span alias; sources::Span path; usize begin; usize end; }
pub struct Symbol { usize owner; u8 kind; bool exported; sources::Span name; sources::Span definition; }
struct ScanBudget { usize remaining; usize deadline; }
struct Path { sources::Span at; usize begin; usize end; }
struct Table {
    u8[4096] names; usize used;
    Module[16] modules; Import[64] imports; Symbol[48] symbols;
    usize count; usize import_count; usize symbol_count; usize functions; usize records;
}
// Large immutable binding data stays behind one private typed owner.
resource Stored { sources::Snapshot sources; Table table; usize semantic_depth; cleanup { } }
pub resource Index { vec::Vec<Stored> stored; usize fuel; cleanup { } }
fn Error error(Failure kind,sources::Span at){return Error{.kind=kind,.at=at};}
fn Error timed_out(){return error(.Deadline,sources::no_source());}
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
fn Result<usize,Error> next(ref u8[] source,usize id,ref mut lexer::State s,ref mut ScanBudget fuel){
    if(clock::expired(fuel.deadline)){return .err(timed_out());}
    if(fuel.remaining==0){return .err(error(.Limit,span(id,s.cursor,s.cursor)));}
    fuel.remaining-=1;
    return switch(staged::next_until(source,s,fuel.deadline)){
        case .ok(v):{.ok(v)}
        case .err(e):{
            if(e.kind==errors::deadline_kind()){.err(timed_out())}
            else{.err(error(if(e.kind==4){.Limit}else{.Lexical},span(id,e.offset,if(e.offset<source.len){e.offset+1}else{e.offset})))}
        }
    };
}
fn Result<usize,Error> punctuation(ref u8[] source,usize id,ref mut lexer::State s,u8 expected,ref mut ScanBudget fuel){
    if(s.kind!=expected){return .err(error(.Syntax,token(id,s)));}return next(source,id,s,fuel);
}
fn Result<Path,Error> path(ref u8[] source,usize id,ref mut lexer::State s,ref mut Table t,ref mut ScanBudget fuel){
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
        let usize advanced=next(source,id,s,fuel)?;
        if(s.kind!=58){break;}
        let usize a=next(source,id,s,fuel)?;let usize b=punctuation(source,id,s,58,fuel)?;
    }
    return .ok(Path{.at=span(id,start,end),.begin=begin,.end=t.used});
}
fn Result<usize,Error> body(ref u8[] source,usize id,ref mut lexer::State s,usize nesting_limit,ref mut ScanBudget fuel){
    var usize nesting=0;
    let usize open=punctuation(source,id,s,123,fuel)?;var usize depth=1;
    while(depth!=0){
        if(s.kind==0){return .err(error(.Syntax,token(id,s)));}
        if(s.kind==123){depth+=1;if(depth>33){return .err(error(.Limit,token(id,s)));}}
        if(s.kind==125){depth-=1;if(depth==0){let usize end=s.end;let usize advanced=next(source,id,s,fuel)?;return .ok(end);}}
        if(s.kind==40 || s.kind==91 || s.kind==123){
            if(nesting==nesting_limit){return .err(error(.Limit,token(id,s)));}
            nesting+=1;
        }else if((s.kind==41 || s.kind==93 || s.kind==125) && nesting!=0){nesting-=1;}
        let usize advanced=next(source,id,s,fuel)?;
    }
    return .err(error(.Syntax,token(id,s)));
}
fn Result<usize,Error> declaration(ref u8[] source,usize id,ref mut lexer::State s,ref mut Table t,usize nesting_limit,ref mut ScanBudget fuel){
    let usize begin=s.begin;var bool exported=false;
    if(word(source,s,b"pub")){exported=true;let usize advanced=next(source,id,s,fuel)?;}
    let bool function=word(source,s,b"fn");
    if(!function && !word(source,s,b"struct")){return .err(error(.Syntax,token(id,s)));}
    if(t.symbol_count==48 || (function && t.functions==16) || (!function && t.records==32)){return .err(error(.Limit,token(id,s)));}
    let usize advanced=next(source,id,s,fuel)?;var sources::Span name=token(id,s);
    if(function){
        var u8 previous=0;
        while(s.kind!=40){
            if(s.kind==0 || s.kind==123 || s.kind==125 || s.kind==59){return .err(error(.Syntax,token(id,s)));}
            if(s.kind==2){name=token(id,s);}previous=s.kind;let usize advanced=next(source,id,s,fuel)?;
        }
        if(previous!=2 || locals::reserved(source[name.start..name.end])){return .err(error(.Syntax,name));}
        var usize depth=1;let usize advanced=next(source,id,s,fuel)?;
        while(depth!=0){
            if(s.kind==0 || s.kind==123 || s.kind==125 || s.kind==59){return .err(error(.Syntax,token(id,s)));}
            if(s.kind==40){depth+=1;if(depth>32){return .err(error(.Limit,token(id,s)));}}
            if(s.kind==41){depth-=1;}
            let usize advanced=next(source,id,s,fuel)?;
        }
    }else{
        if(s.kind!=2 || locals::reserved(source[s.begin..s.end])){return .err(error(.Syntax,token(id,s)));}
        let usize advanced=next(source,id,s,fuel)?;
    }
    if(name.end-name.start>64){return .err(error(.Limit,name));}
    var usize i=0;while(i<t.symbol_count){let Symbol prior=t.symbols[i];
        if(prior.owner==id && bytes::equal(source[name.start..name.end],source[prior.name.start..prior.name.end])){return .err(error(.Duplicate,name));}i+=1;
    }
    let usize end=body(source,id,s,nesting_limit,fuel)?;
    let usize at=t.symbol_count;t.symbols[at]=Symbol{.owner=id,.kind=if(function){1}else{2},.exported=exported,
        .name=name,.definition=span(id,begin,end)};t.symbol_count=at+1;
    if(function){t.functions+=1;}else{t.records+=1;}return .ok(at);
}
fn Result<usize,Error> file(ref u8[] source,usize id,ref mut Table t,bool host,usize nesting_limit,ref mut ScanBudget fuel){
    var lexer::State s=lexer::empty();let usize first=next(source,id,ref mut s,fuel)?;
    if(!word(source,ref s,b"module")){return .err(error(.Syntax,token(id,ref s)));}
    let usize advanced=next(source,id,ref mut s,fuel)?;
    let bool reserved=word(source,ref s,b"std") || word(source,ref s,b"brownie") || (host && word(source,ref s,b"host"));
    let Path name=path(source,id,ref mut s,t,fuel)?;
    if(reserved){return .err(error(.Reserved,name.at));}
    let usize semicolon=punctuation(source,id,ref mut s,59,fuel)?;
    let ref u8[] names=ref t.names;
    var usize i=0;while(i<t.count){let Module prior=t.modules[i];
        if(bytes::equal(names[name.begin..name.end],names[prior.begin..prior.end])){return .err(error(.Duplicate,name.at));}i+=1;
    }
    t.modules[id]=Module{.path=name.at,.begin=name.begin,.end=name.end};t.count+=1;
    var bool declarations=false;
    while(s.kind!=0){
        if(word(source,ref s,b"import") && !declarations){
            if(t.import_count==64){return .err(error(.Limit,token(id,ref s)));}
            let usize advance_1=next(source,id,ref mut s,fuel)?;let Path target=path(source,id,ref mut s,t,fuel)?;
            if(!word(source,ref s,b"as")){return .err(error(.Syntax,token(id,ref s)));}
            let usize advance_2=next(source,id,ref mut s,fuel)?;
            if(s.kind!=2 || locals::reserved(source[s.begin..s.end]) || (host && word(source,ref s,b"host"))){return .err(error(.Syntax,token(id,ref s)));}
            let sources::Span alias=token(id,ref s);if(alias.end-alias.start>64){return .err(error(.Limit,alias));}
            i=0;while(i<t.import_count){let Import prior=t.imports[i];
                if(prior.owner==id && bytes::equal(source[alias.start..alias.end],source[prior.alias.start..prior.alias.end])){return .err(error(.Duplicate,alias));}i+=1;
            }
            let usize advance_3=next(source,id,ref mut s,fuel)?;let usize semicolon=punctuation(source,id,ref mut s,59,fuel)?;
            let usize at=t.import_count;
            t.imports[at]=Import{.owner=id,.target=16,.alias=alias,.path=target.at,.begin=target.begin,.end=target.end};t.import_count=at+1;
        }else{declarations=true;let usize added=declaration(source,id,ref mut s,t,nesting_limit,fuel)?;}
    }
    return .ok(s.tokens);
}
fn Result<usize,Error> prepare(ref sources::Snapshot snapshot,ref mut Table t,bool host,usize token_limit,usize nesting_limit,usize budget,usize deadline){
    var ScanBudget fuel=ScanBudget{.remaining=budget,.deadline=deadline};
    let usize count=sources::count(snapshot);if(count==0){return .err(error(.Missing,sources::no_source()));}
    var usize id=0;var usize tokens=0;
    while(id<count){
        if(clock::expired(deadline)){return .err(timed_out());}
        let sources::Span all=switch(sources::whole(snapshot,id)){case .ok(v):{v}case .err(_):{return .err(error(.Bounds,sources::no_source()));}};
        let ref u8[] source=switch(sources::view(snapshot,all)){case .ok(v):{v}case .err(_):{return .err(error(.Bounds,all));}};
        // Prepay the full member before scanning whitespace, comments or literals.
        if(source.len>fuel.remaining){return .err(error(.Limit,span(id,0,0)));}
        fuel.remaining-=source.len;
        let usize scanned=file(source,id,t,host,nesting_limit,ref mut fuel)?;
        let usize used=scanned-1;
        if(used>token_limit-tokens || (!host && scanned>1024-tokens-id)){
            return .err(error(.Limit,span(id,source.len,source.len)));
        }
        tokens+=used;id+=1;
    }
    var Import[64] bound=t.imports;
    let ref u8[] names=ref t.names;
    var usize i=0;while(i<t.import_count){
        if(clock::expired(deadline)){return .err(timed_out());}
        let Import candidate=t.imports[i];var usize target=16;id=0;
        while(id<t.count){let Module m=t.modules[id];if(bytes::equal(names[candidate.begin..candidate.end],names[m.begin..m.end])){target=id;break;}id+=1;}
        if(target==16 && !(host && candidate.end-candidate.begin>6 &&
            bytes::equal(names[candidate.begin..candidate.begin+6],b"host::"))){
            return .err(error(.Missing,candidate.path));
        }
        bound[i]=Import{.owner=candidate.owner,.target=target,.alias=candidate.alias,.path=candidate.path,.begin=candidate.begin,.end=candidate.end};i+=1;
    }
    t.imports=bound;
    return .ok(if(budget==budget::unlimited()){budget}else{fuel.remaining});
}
pub fn Result<Index,Error> build(sources::Snapshot snapshot){
    return build_mode(snapshot,false,1024,1024,budget::unlimited(),0);
}
pub fn Result<Index,Error> build_host(sources::Snapshot snapshot,usize token_limit){
    return build_metered(snapshot,true,token_limit,1024,budget::unlimited(),0);
}
pub fn Result<Index,Error> build_metered(sources::Snapshot snapshot,bool host,
    usize token_limit,usize nesting_limit,usize fuel,usize deadline){
    return build_mode(snapshot,host,if(token_limit<1024){token_limit}else{1024},nesting_limit,fuel,deadline);
}
fn Result<Index,Error> build_mode(sources::Snapshot snapshot,bool host,usize token_limit,usize nesting_limit,usize fuel,usize deadline){
    var Table t=empty();let usize remaining=prepare(ref snapshot,ref mut t,host,token_limit,nesting_limit,fuel,deadline)?;
    if(clock::expired(deadline)){return .err(timed_out());}
    var vec::Vec<Stored> stored=vec::empty<Stored>();
    let usize capacity=switch(vec::reserve<Stored>(ref mut stored,1)){
        case .ok(v):{v}case .err(_):{return .err(error(.Allocation,sources::no_source()));}
    };
    let usize count=switch(vec::push<Stored>(ref mut stored,Stored{.sources=snapshot,.table=t,
        .semantic_depth=if(nesting_limit<32){nesting_limit}else{32}})){
        case .ok(v):{v}case .err(_):{return .err(error(.Allocation,sources::no_source()));}
    };
    if(clock::expired(deadline)){return .err(timed_out());}
    return .ok(Index{.stored=stored,.fuel=remaining});
}
fn ref Stored stored(ref Index p){return vec::at<Stored>(ref p.stored,0);}
pub fn usize compile_fuel(ref Index p){return p.fuel;}
pub fn usize semantic_depth(ref Index p){return stored(p).semantic_depth;}
pub fn ref sources::Snapshot snapshot(ref Index p){return ref stored(p).sources;}
fn ref Table table(ref Index p){return ref stored(p).table;}
pub fn usize count(ref Index p){return table(p).count;}
pub fn usize symbol_count(ref Index p){return table(p).symbol_count;}
pub fn usize function_count(ref Index p){return table(p).functions;}
pub fn usize record_count(ref Index p){return table(p).records;}
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
    var usize fuel=budget::unlimited();
    return match_source_names_metered(p,0,ref mut fuel);
}
fn Result<usize,Error> binding_visit(ref mut usize fuel,usize deadline,sources::Span at){
    return switch(budget::visit(fuel,deadline,at.start)){
        case .ok(v):{.ok(v)}
        case .err(e):{.err(if(e.kind==errors::deadline_kind()){timed_out()}else{error(.Limit,at)})}
    };
}
fn Result<usize,Error> match_source_names_metered(ref Index p,usize deadline,ref mut usize fuel){
    let ref sources::Snapshot input=snapshot(p);
    let usize count=count(p);
    var usize row=0;
    while(row<count){
        let Module declared=module_at(p,row)?;
        discard binding_visit(fuel,deadline,declared.path)?;
        let ref u8[] actual=module_name(p,row)?;
        let ref u8[] supplied=switch(sources::name(input,row)){
            case .ok(v):{v}case .err(_):{return .err(error(.Bounds,declared.path));}
        };
        if(!bytes::equal(actual,supplied)){return .err(error(.Kind,declared.path));}
        row+=1;
    }
    if(clock::expired(deadline)){return .err(timed_out());}
    return .ok(count);
}
pub fn Result<usize,Error> find(ref Index p,ref u8[] path){
    var usize fuel=budget::unlimited();
    return find_metered(p,path,0,ref mut fuel);
}
fn Result<usize,Error> find_metered(ref Index p,ref u8[] path,usize deadline,ref mut usize fuel){
    let ref Table t=table(p);let ref u8[] names=ref t.names;var usize i=0;
    while(i<t.count){
        let Module m=t.modules[i];
        discard binding_visit(fuel,deadline,m.path)?;
        if(bytes::equal(path,names[m.begin..m.end])){return .ok(i);}
        i+=1;
    }
    return .err(error(.Missing,sources::no_source()));
}
fn bool matches(ref Index p,sources::Span span,ref u8[] name){
    return switch(sources::view(snapshot(p),span)){case .ok(v):{bytes::equal(v,name)}case .err(_):{false}};
}
pub fn Result<usize,Error> resolve(ref Index p,usize caller,ref u8[] qualifier,ref u8[] name){
    var usize fuel=budget::unlimited();
    return resolve_metered(p,caller,qualifier,name,0,ref mut fuel);
}
fn Result<usize,Error> resolve_metered(ref Index p,usize caller,ref u8[] qualifier,ref u8[] name,
    usize deadline,ref mut usize fuel){
    let ref Table t=table(p);if(caller>=t.count){return .err(error(.Bounds,sources::no_source()));}
    var usize target=caller;var usize i=0;
    if(qualifier.len!=0){target=16;
        while(i<t.import_count){let Import candidate=t.imports[i];
            discard binding_visit(fuel,deadline,candidate.alias)?;
            if(candidate.owner==caller && matches(p,candidate.alias,qualifier)){target=candidate.target;break;}i+=1;
        }
        if(target==16){return .err(error(.Missing,t.modules[caller].path));}
    }
    i=0;while(i<t.symbol_count){let Symbol candidate=t.symbols[i];
        discard binding_visit(fuel,deadline,candidate.name)?;
        if(candidate.owner==target && matches(p,candidate.name,name)){
            if(target!=caller && !candidate.exported){return .err(error(.Private,candidate.name));}return .ok(i);
        }i+=1;
    }
    return .err(error(.Missing,t.modules[caller].path));
}
// Binding only: the full compiler must still check entry parameter/result types.
pub fn Result<usize,Error> entry(ref Index p,ref u8[] path,ref u8[] name){
    var usize fuel=budget::unlimited();
    return entry_metered(p,path,name,0,ref mut fuel);
}
fn Result<usize,Error> entry_metered(ref Index p,ref u8[] path,ref u8[] name,usize deadline,ref mut usize fuel){
    let usize owner=find_metered(p,path,deadline,fuel)?;
    let usize id=resolve_metered(p,owner,b"",name,deadline,fuel)?;
    let Symbol selected=symbol(p,id)?;
    if(selected.kind!=1){return .err(error(.Kind,selected.name));}
    if(!selected.exported){return .err(error(.Private,selected.name));}return .ok(id);
}

pub fn Result<usize,Error> bind_preview_entry(ref mut Index p,ref u8[] path,ref u8[] name,usize deadline){
    var usize remaining=compile_fuel(p);
    discard match_source_names_metered(p,deadline,ref mut remaining)?;
    let usize selected=entry_metered(p,path,name,deadline,ref mut remaining)?;
    if(clock::expired(deadline)){return .err(timed_out());}
    p.fuel=remaining;
    return .ok(selected);
}
