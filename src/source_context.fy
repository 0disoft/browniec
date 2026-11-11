module source_context;
import module_index as modules;
import source_snapshot as sources;
import lexer as lexer;
import errors as errors;
import source_name_work as staged_names;
import metadata_budget as budget;

// Copyable compiler scratch, never executable authority. Packed original spans
// use 13-bit offsets; names carry one pub bit, aliases carry a 4-bit target.
pub struct Table { u32[16] ends; u32[64] aliases; u32[16] functions; u32[32] records;
    usize modules; usize imports; usize function_count; usize record_count; }
pub struct Input { u8[4096] data; usize used; Table context; }
pub fn Table empty(){return Table{.ends=[0;16],.aliases=[0;64],.functions=[0;16],.records=[0;32],
    .modules=0,.imports=0,.function_count=0,.record_count=0};}
fn modules::Error error(sources::Span at){return modules::Error{.kind=.Bounds,.at=at};}
fn Result<u32,modules::Error> word(usize value,sources::Span at){
    if(value>1073741823){return .err(error(at));}
    var usize rest=value;var u32 packed=0;var u32 power=1;
    while(rest!=0){if((rest&1)!=0){packed|=power;}rest>>=1;if(rest!=0){power<<=1;}}
    return .ok(packed);
}
pub fn usize begin(u32 word){return word as usize & 8191;}
pub fn usize end(u32 word){return (word as usize >> 13)&8191;}
fn bool shape(ref Table t,usize length){
    if(t.modules==0 || t.modules>16 || t.imports>64 || t.function_count>16 || t.record_count>32 || length>4096){return false;}
    var usize prior=0;var usize i=0;
    while(i<t.modules){let usize last=t.ends[i] as usize;if(last<=prior || last>length){return false;}prior=last;i+=1;}
    return prior==length;
}
// Callers validate shape first. Source EOF has no token owner.
fn usize owner(ref Table t,usize offset){
    var usize i=0;while(i<t.modules){if(offset<t.ends[i] as usize){return i;}i+=1;}return 16;
}
fn bool name(ref u8[] source,ref Table t,u32 item){
    let usize a=begin(item);let usize b=end(item);
    return a<b && b<=source.len && owner(t,a)==owner(t,b-1) && lexer::simple(source,a,b);
}
pub fn bool valid(ref u8[] source,ref Table t){
    if(!shape(t,source.len)){return false;}var usize i=0;
    while(i<t.imports){let u32 item=t.aliases[i];if((item>>30)!=0 || (item as usize>>26)>=t.modules || !name(source,t,item)){return false;}i+=1;}
    i=0;while(i<t.function_count){if((t.functions[i]>>27)!=0 || !name(source,t,t.functions[i])){return false;}i+=1;}
    i=0;while(i<t.record_count){if((t.records[i]>>27)!=0 || !name(source,t,t.records[i])){return false;}i+=1;}return true;
}
pub fn Result<Input,modules::Error> collect(ref modules::Index index){
    let ref sources::Snapshot snapshot=modules::snapshot(index);let usize count=modules::count(index);
    var u8[4096] data=[0;4096];var usize used=0;var u32[16] ends=[0;16];var u32[64] aliases=[0;64];
    var u32[16] functions=[0;16];var u32[32] records=[0;32];var usize fc=0;var usize rc=0;var usize i=0;
    if(count==0 || count>16 || modules::import_count(index)>64 || modules::symbol_count(index)>48){return .err(error(sources::no_source()));}
    while(i<count){
        let sources::Span all=switch(sources::whole(snapshot,i)){case .ok(v):{v}case .err(_):{return .err(error(sources::no_source()));}};
        let ref u8[] source=switch(sources::view(snapshot,all)){case .ok(v):{v}case .err(_):{return .err(error(all));}};
        if(source.len==0 || source.len>4096-used){return .err(error(all));}
        var usize j=0;while(j<source.len){data[used+j]=source[j];j+=1;}used+=source.len;ends[i]=word(used,all)?;i+=1;
    }
    i=0;while(i<modules::import_count(index)){
        let modules::Import item=modules::import_at(index,i)?;
        if(item.owner>=count || item.target>=count){return .err(error(item.alias));}
        let usize base=if(item.owner==0){0}else{ends[item.owner-1] as usize};
        aliases[i]=word((base+item.alias.start) | ((base+item.alias.end)<<13) | (item.target<<26),item.alias)?;i+=1;
    }
    i=0;while(i<modules::symbol_count(index)){
        let modules::Symbol item=modules::symbol(index,i)?;if(item.owner>=count){return .err(error(item.name));}
        let usize base=if(item.owner==0){0}else{ends[item.owner-1] as usize};
        let u32 packed=word((base+item.name.start) | ((base+item.name.end)<<13) | if(item.exported){67108864}else{0},item.name)?;
        if(item.kind==1){if(fc==16){return .err(error(item.name));}functions[fc]=packed;fc+=1;}
        else{if(item.kind!=2 || rc==32){return .err(error(item.name));}records[rc]=packed;rc+=1;}i+=1;
    }
    let Table context=Table{.ends=ends,.aliases=aliases,.functions=functions,.records=records,
        .modules=count,.imports=modules::import_count(index),.function_count=fc,.record_count=rc};
    let ref u8[] initialized=ref data;
    if(!valid(initialized[..used],ref context)){return .err(error(sources::no_source()));}
    return .ok(Input{.data=data,.used=used,.context=context});
}
fn usize alias(ref u8[] source,ref Table t,usize caller,ref u8[] spelling){
    var usize i=0;while(i<t.imports){let u32 item=t.aliases[i];
        if(owner(t,begin(item))==caller && lexer::equal(source[begin(item)..end(item)],spelling)){return item as usize>>26;}i+=1;
    }return 16;
}
pub fn Result<lexer::State,errors::Error> state(ref u8[] source,ref Table t,usize offset){
    if(t.modules==0){var lexer::State s=lexer::empty();s.cursor=offset;return .ok(s);}
    if(!valid(source,t) || offset>=source.len){return .err(errors::make(5,offset));}
    let usize caller=owner(t,offset);let usize start=if(caller==0){0}else{t.ends[caller-1] as usize};
    var lexer::State s=lexer::scoped(source,start,t.ends[caller] as usize,alias(source,t,caller,b"text")!=16)?;
    s.cursor=offset;return .ok(s);
}
// A real import alias takes precedence over a private builtin spelling.
pub fn bool imported(ref u8[] source,ref Table t,usize at,ref u8[] spelling){
    return valid(source,t) && at<source.len && alias(source,t,owner(t,at),spelling)!=16;
}
pub fn usize lookup_raw(ref u8[] source,ref Table t,usize a,usize b,bool record){
    let usize absent=if(record){32}else{16};
    if(!valid(source,t) || a>=b || b>source.len){return absent;}
    let usize caller=owner(t,a);if(caller==16 || b>t.ends[caller] as usize){return absent;}
    let ref u8[] query=source[a..b];var lexer::State s=lexer::empty();
    if(!lexer::next(query,ref mut s).is_ok || s.kind!=2){return absent;}
    var usize target=caller;var usize first=s.begin;var usize last=s.end;
    if(s.end!=query.len){
        let usize qualifier_begin=s.begin;let usize qualifier_end=s.end;
        if(!lexer::next(query,ref mut s).is_ok || s.kind!=58){return absent;}
        if(!lexer::next(query,ref mut s).is_ok || s.kind!=58){return absent;}
        if(!lexer::next(query,ref mut s).is_ok || s.kind!=2){return absent;}
        first=s.begin;last=s.end;
        if(!lexer::next(query,ref mut s).is_ok || s.kind!=0){return absent;}
        target=alias(source,t,caller,query[qualifier_begin..qualifier_end]);if(target==16){return absent;}
    }
    var usize i=0;let usize count=if(record){t.record_count}else{t.function_count};
    while(i<count){let u32 item=if(record){t.records[i]}else{t.functions[i]};let usize selected=owner(t,begin(item));
        if(selected==target && lexer::equal(query[first..last],source[begin(item)..end(item)])){
            if(selected!=caller && (item&67108864)==0){return absent;}return i;
        }i+=1;
    }return absent;
}
// Owning source-name adapter; scope and spelling checks resume independently.
pub fn usize lookup(ref u8[] source,ref Table t,usize a,usize b,bool record){
    let usize absent=if(record){32}else{16};
    var staged_names::State w=staged_names::begin(a,b,record);var budget::State meter=budget::empty();
    while(!w.done){if(!budget::reset(ref mut meter,0).is_ok){return absent;}
        if(!staged_names::advance(source,t,ref mut w,ref mut meter).is_ok){return absent;}}
    return w.result;
}
pub fn Result<usize,errors::Error> definition(ref u8[] source,ref Table t,usize id,bool record){
    if(!valid(source,t) || (record && id>=t.record_count) || (!record && id>=t.function_count)){return .err(errors::make(5,0));}
    return .ok(begin(if(record){t.records[id]}else{t.functions[id]}));
}
pub fn Result<sources::Span,modules::Error> location(ref u8[] source,ref Table t,usize offset){
    if(!valid(source,t) || offset>source.len){return .err(error(sources::no_source()));}
    let usize id=if(offset==source.len){t.modules-1}else{owner(t,offset)};
    let usize base=if(id==0){0}else{t.ends[id-1] as usize};let usize start=offset-base;
    return .ok(sources::Span{.source=id,.start=start,.end=start});
}
