module source_error;
import source_snapshot as sources;
import errors as errors;
import module_index as modules;

pub struct Error { errors::Error code; sources::Span at; }
pub fn Error absent(errors::Error code){return Error{.code=code,.at=sources::no_source()};}
pub fn errors::Error binding(modules::Error e){
    let u8 kind=switch(e.kind){
        case .Lexical:{1}case .Syntax:{2}case .Limit:{4}case .Allocation:{15}
        case .Duplicate:{3}case .Missing:{3}case .Private:{3}case .Reserved:{3}case .Bounds:{3}case .Kind:{3}
    };
    return if(e.at.source==sources::no_source().source){errors::absent(kind,0)}else{errors::make(kind,e.at.start)};
}
// Active identity disambiguates a previous file's EOF from the next file's start.
pub fn Error map(ref sources::Snapshot snapshot,errors::Error code,usize active){
    let usize count=sources::count(snapshot);var usize base=0;var usize id=0;
    if(active<count){
        while(id<=active){let sources::Span all=switch(sources::whole(snapshot,id)){
            case .ok(v):{v}case .err(_):{return absent(code);}
        };
            if(id==active && code.offset>=base && code.offset-base<=all.end){
                let usize start=code.offset-base;return Error{.code=code,.at=sources::Span{.source=id,.start=start,.end=if(start<all.end){start+1}else{start}}};
            }base+=all.end;id+=1;
        }
    }
    base=0;id=0;
    while(id<count){let sources::Span all=switch(sources::whole(snapshot,id)){
        case .ok(v):{v}case .err(_):{return absent(code);}
    };
        if(code.offset>=base && (code.offset-base<all.end || (id+1==count && code.offset-base==all.end))){
            let usize start=code.offset-base;return Error{.code=code,.at=sources::Span{.source=id,.start=start,.end=if(start<all.end){start+1}else{start}}};
        }base+=all.end;id+=1;
    }return absent(code);
}
