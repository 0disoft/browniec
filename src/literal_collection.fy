module literal_collection;
import lexer as lexer;
import literal_source as literals;
import static_image as images;
import errors as errors;
import std::text as text;

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
    if(source.len>4096){return .err(source_error(4,4096));}
    if(!text::validate_utf8(source).is_ok){return .err(source_error(1,0));}
    var images::Builder staged=*builder;var Index index=empty();
    var lexer::State token=lexer::empty();
    var usize next=switch(lexer::next(source,ref mut token)){
        case .ok(v):{v}case .err(e):{return .err(source_error(e.kind,e.offset));}
    };
    while(token.kind!=0){
        if(token.kind==3 || token.kind==4){
            if(index.count==16){return .err(source_error(4,token.begin));}
            let literals::Interned value=literals::intern(ref mut staged,source,token.begin)?;
            if(value.end!=token.end){return .err(source_error(1,token.begin));}
            let usize row=index.count;index.begins[row]=value.begin;index.ends[row]=value.end;
            index.literals[row]=value.literal;index.lengths[row]=value.length;
            index.kinds[row]=if(value.text){2}else{1};index.count+=1;
        }
        next=switch(lexer::next(source,ref mut token)){
            case .ok(v):{v}case .err(e):{return .err(source_error(e.kind,e.offset));}
        };
    }
    index.enabled=true;*builder=staged;return .ok(index);
}
pub fn Result<usize,errors::Error> find(ref Index index,usize begin,usize end){
    if(!index.enabled || index.count>16){return .err(errors::make(2,begin));}
    var usize i=0;while(i<index.count){
        if(index.begins[i]==begin && index.ends[i]==end){return .ok(i);}i+=1;
    }return .err(errors::make(3,begin));
}
