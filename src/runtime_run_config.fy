module runtime_run_config;
import runtime_policy as policy;
import runtime_policy_limits as limits;
import runtime_policy_json as j;
import std::bytes as bytes;

struct Entry { j::Span scope; j::Span function; }
pub resource RunConfig {
    bytes::Buffer strings; Entry entry; j::Capabilities requires; j::Capabilities grants; limits::RunLimits limits;
    cleanup { }
}
fn Result<Entry,j::Error> entry(ref u8[] source,ref mut j::Cursor c,ref mut bytes::Buffer strings){
    let j::Span no=j::Span{.begin=0,.end=0};var j::Span scope=no;var j::Span function=no;
    var bool[2] seen=[false;2];let usize open=j::take(source,c,123)?;
    if(c.token.kind!=125){while(true){
        let usize at=c.token.begin;let usize field=j::field(source,c,b"module|function")?;
        let usize unique=j::mark(ref mut seen,field,at)?;
        if(field==0){scope=j::entry_name(source,c,strings,true)?;}else{function=j::entry_name(source,c,strings,false)?;}
        if(c.token.kind==125){break;}let usize comma=j::take(source,c,44)?;
    }}
    let usize complete=j::complete(ref seen,c.token.begin)?;let usize close=j::take(source,c,125)?;
    return .ok(Entry{.scope=scope,.function=function});
}
// A successful parse is narrowed against this Policy at admission. Recheck
// against the actual Engine policy when integration binds the run to an Engine.
pub fn Result<RunConfig,j::Error> parse(ref u8[] source,ref policy::Policy p){
    var j::Cursor c=j::start(source)?;let usize open=j::take(source,ref mut c,123)?;
    let j::Span no=j::Span{.begin=0,.end=0};var Entry selected=Entry{.scope=no,.function=no};
    var bytes::Buffer strings=bytes::empty();var j::Capabilities requires=j::empty_capabilities();
    var j::Capabilities grants=j::empty_capabilities();var limits::RunLimits requested=policy::run_limits(p);
    var bool[5] seen=[false;5];
    if(c.token.kind!=125){while(true){
        let usize at=c.token.begin;let usize field=j::field(source,ref mut c,b"schema|entry|requires|grants|limits")?;
        let usize unique=j::mark(ref mut seen,field,at)?;
        if(field==0){let usize schema=j::constant(source,ref mut c,b"brownie.run/0.3")?;}
        else if(field==1){selected=entry(source,ref mut c,ref mut strings)?;}
        else if(field==2){requires=j::capabilities(source,ref mut c)?;}
        else if(field==3){grants=j::capabilities(source,ref mut c)?;}
        else{requested=limits::run(source,ref mut c)?;}
        if(c.token.kind==125){break;}let usize comma=j::take(source,ref mut c,44)?;
    }}
    let usize complete=j::complete(ref seen,c.token.begin)?;let usize close=j::take(source,ref mut c,125)?;
    if(c.token.kind!=0){return .err(j::error(.Json,c.token.begin));}
    if(!limits::run_relations(requested)){return .err(j::error(.Relation,0));}
    if(!policy::allows_run(p,requested) || !j::subset(ref requires,ref grants) || !policy::allows(p,ref grants)){
        return .err(j::error(.Authority,0));
    }
    return .ok(RunConfig{.strings=strings,.entry=selected,.requires=requires,.grants=grants,.limits=requested});
}
pub fn usize heap_bytes(ref RunConfig c){
    return bytes::capacity(ref c.strings)+j::heap_bytes(ref c.requires)+j::heap_bytes(ref c.grants);
}
pub fn ref u8[] module_name(ref RunConfig c){return j::view(ref c.strings,c.entry.scope);}
pub fn ref u8[] function_name(ref RunConfig c){return j::view(ref c.strings,c.entry.function);}
pub fn limits::RunLimits run_limits(ref RunConfig c){return c.limits;}
pub fn usize requires_count(ref RunConfig c){return j::count(ref c.requires);}
pub fn usize grants_count(ref RunConfig c){return j::count(ref c.grants);}
pub fn Result<ref u8[],j::Error> requirement(ref RunConfig c,usize i){return j::capability(ref c.requires,i);}
pub fn Result<ref u8[],j::Error> grant(ref RunConfig c,usize i){return j::capability(ref c.grants,i);}
pub fn bool declares(ref RunConfig c,ref u8[] name){return j::contains(ref c.requires,name);}
pub fn bool grants(ref RunConfig c,ref u8[] name){return j::contains(ref c.grants,name);}
pub fn bool narrowed_to(ref RunConfig c,ref policy::Policy p){
    return policy::allows_run(p,c.limits) && j::subset(ref c.requires,ref c.grants) && policy::allows(p,ref c.grants);
}
