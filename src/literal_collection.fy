module literal_collection;
import lexer as lexer;
import literal_source as literals;
import static_image as images;
import errors as errors;
import runtime_clock as clock;
import std::text as text;
import literal_collection_work as staged;
import metadata_budget as budget;
import source_context as context;

// Source offsets and image-local IDs only; no retained bytes or runtime authority.
pub struct Index { usize[16] begins; usize[16] ends; usize[16] literals;
    usize[16] lengths; u8[16] kinds; usize count; bool enabled; }
pub fn Index empty(){return Index{.begins=[0;16],.ends=[0;16],.literals=[0;16],
    .lengths=[0;16],.kinds=[0;16],.count=0,.enabled=false};}
fn literals::Error source_error(u8 kind,usize offset){
    return literals::Error{.kind=.Source,.source=errors::make(kind,offset),.image=.State};
}
// Stage the entire collection. Neither builder nor index is published on failure.
// Sixteen occurrences match the current global Static definition capacity.
pub fn Result<Index,literals::Error> collect(ref mut images::Builder builder,ref u8[] source){
    let context::Table scope=context::empty();return collect_scoped(builder,source,ref scope);
}
fn Result<bool,literals::Error> next_batch(ref u8[] source,ref context::Table scope,ref images::Builder builder,
    ref mut images::Builder candidate,ref mut staged::State w,ref mut budget::State meter){
    switch(budget::reset(meter,0)){case .ok(_):{}case .err(e):{return .err(source_error(e.kind,e.offset));}};
    return staged::advance(source,scope,builder,candidate,w,meter);
}

// Drain private collection children; publish caller-visible state only at success.
pub fn Result<Index,literals::Error> collect_scoped(ref mut images::Builder builder,ref u8[] source,ref context::Table scope){
    var images::Builder candidate=images::Builder{.data=[0;4096],.catalog=images::Catalog{
        .starts=[0;16],.ends=[0;16],.text=[false;16],.count=0,.used=0},.limit=0};
    var staged::State w=staged::empty();var budget::State meter=budget::empty();
    while(!w.done){let bool done=next_batch(source,scope,builder,ref mut candidate,ref mut w,ref mut meter)?;}
    let Index index=staged::prepared(ref w)?;*builder=candidate;return .ok(index);
}

// The absolute Engine deadline also covers the final publication boundary.
pub fn Result<Index,literals::Error> collect_scoped_until(ref mut images::Builder builder,ref u8[] source,
    ref context::Table scope,usize deadline){
    var images::Builder candidate=images::Builder{.data=[0;4096],.catalog=images::Catalog{
        .starts=[0;16],.ends=[0;16],.text=[false;16],.count=0,.used=0},.limit=0};
    var staged::State w=staged::empty();var budget::State meter=budget::empty();
    while(!w.done){
        if(clock::expired(deadline)){return .err(deadline_error());}
        let bool done=next_batch(source,scope,builder,ref mut candidate,ref mut w,ref mut meter)?;
    }
    if(clock::expired(deadline)){return .err(deadline_error());}
    let Index index=staged::prepared(ref w)?;*builder=candidate;return .ok(index);
}

fn literals::Error deadline_error(){
    return literals::Error{.kind=.Source,.source=errors::absent(errors::deadline_kind(),0),.image=.State};
}

// Independent whole-collection comparison path.
pub fn Result<Index,literals::Error> collect_scoped_raw(ref mut images::Builder builder,ref u8[] source,ref context::Table scope){
    if(scope.modules!=0 && !context::valid(source,scope)){return .err(source_error(5,0));}
    if(source.len>4096){return .err(source_error(4,4096));}
    if(!text::validate_utf8(source).is_ok){return .err(source_error(1,0));}
    var images::Builder staged=*builder;var Index index=empty();
    var usize file=0;var usize base=0;let usize count=if(scope.modules==0){1}else{scope.modules};
    while(file<count){
    let usize end=if(scope.modules==0){source.len}else{scope.ends[file] as usize};
    var lexer::State token=switch(context::state(source,scope,base)){
        case .ok(v):{v}case .err(e):{return .err(source_error(e.kind,e.offset));}
    };
    var usize next=switch(lexer::next(source,ref mut token)){
        case .ok(v):{v}case .err(e):{return .err(source_error(e.kind,e.offset));}
    };
    while(token.kind!=0){
        if(token.kind==3 || token.kind==4){
            if(index.count==16){return .err(source_error(4,token.begin));}
            let literals::Interned value=literals::intern(ref mut staged,source[..end],token.begin)?;
            if(value.end!=token.end){return .err(source_error(1,token.begin));}
            let usize row=index.count;index.begins[row]=value.begin;index.ends[row]=value.end;
            index.literals[row]=value.literal;index.lengths[row]=value.length;
            index.kinds[row]=if(value.text){2}else{1};index.count+=1;
        }
        next=switch(lexer::next(source,ref mut token)){
            case .ok(v):{v}case .err(e):{return .err(source_error(e.kind,e.offset));}
        };
    }
    base=end;file+=1;
    }
    index.enabled=true;*builder=staged;return .ok(index);
}
pub fn Result<usize,errors::Error> find(ref Index index,usize begin,usize end){
    if(!index.enabled || index.count>16){return .err(errors::make(2,begin));}
    var usize i=0;while(i<index.count){
        if(index.begins[i]==begin && index.ends[i]==end){return .ok(i);}i+=1;
    }return .err(errors::make(3,begin));
}
