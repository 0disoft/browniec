module literal_collection_work;
import literal_collection as raw;
import literal_source as literals;
import literal_source_work as decoding;
import literal_intern_work as interning;
import static_image as images;
import source_context as context;
import source_context_check_work as checking;
import source_state_work as states;
import source_utf8_work as utf8;
import lexer as lexer;
import lexer_work as tokens;
import metadata_budget as budget;
import errors as errors;

// The owner pins source/scope/original builder and supplies a separate private
// candidate builder. Original bytes/metadata remain untouched through failure.
// Candidate banks and this continuation are separate to avoid payload copies
// when bridging the compiler's sibling mutable-loan restrictions.
pub struct State { raw::Index result; checking::State check; utf8::State utf8;
    states::State state; tokens::State scan; decoding::State decoded; interning::State intern;
    lexer::State token; usize file; usize base; usize end; usize row; usize cursor; usize clear;
    usize literal; usize visits; u8 phase; u8 resume; bool waiting; bool done; }
pub fn State empty(){return State{.result=raw::empty(),.check=checking::empty(),.utf8=utf8::empty(),.state=states::begin(0),
    .scan=tokens::begin(lexer::empty()),.decoded=decoding::empty(0),.intern=interning::begin(false),.token=lexer::empty(),
    .file=0,.base=0,.end=0,.row=0,.cursor=0,.clear=0,.literal=0,.visits=0,.phase=0,.resume=0,.waiting=false,.done=false};}
fn literals::Error source_error(errors::Error e){return literals::Error{.kind=.Source,.source=e,.image=.State};}
fn literals::Error source(u8 kind,usize at){return source_error(errors::make(kind,at));}
fn literals::Error image_error(images::Error e){return literals::Error{.kind=.Image,.source=errors::make(0,0),.image=e};}
fn void next(ref mut State w,u8 phase){let lexer::State current=w.token;w.scan=tokens::begin(current);w.waiting=true;w.resume=phase;}
fn void reset_decoded(ref mut State w){let usize begin=w.token.begin;
    w.decoded.result.begin=begin;w.decoded.result.end=begin;w.decoded.result.length=0;w.decoded.result.text=false;
    w.decoded.cursor=begin;w.decoded.checked=0;w.decoded.visits=0;w.decoded.phase=0;w.decoded.done=false;w.clear=0;}
pub fn Result<raw::Index,literals::Error> prepared(ref State w){if(!w.done){return .err(source(5,0));}return .ok(w.result);}
pub fn Result<bool,literals::Error> advance(ref u8[] input,ref context::Table scope,ref images::Builder original,
    ref mut images::Builder candidate,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==0 && scope.modules!=0){let bool done=switch(checking::advance(input,scope,ref mut w.check,meter)){
            case .ok(v):{v}case .err(e):{return .err(source_error(e));}};
        if(done){if(!w.check.result){return .err(source(5,0));}w.phase=1;}return .ok(false);}
    if(w.phase==2){let bool done=switch(utf8::advance(input,ref mut w.utf8,meter)){
            case .ok(v):{v}case .err(_):{return .err(source(1,0));}};
        if(done){w.phase=3;}return .ok(false);}
    if(w.waiting){let Result<bool,errors::Error> result=tokens::advance(input,ref mut w.scan,meter);
        w.token=tokens::observed(ref w.scan);switch(result){case .ok(done):{if(done){w.waiting=false;w.phase=w.resume;}}
            case .err(e):{return .err(source_error(e));}};return .ok(false);}
    if(w.phase==7){let bool done=switch(states::advance(input,scope,ref mut w.state,meter)){
            case .ok(v):{v}case .err(e):{return .err(source_error(e));}};
        if(done){w.token=switch(states::prepared(ref w.state)){case .ok(v):{v}case .err(e):{return .err(source_error(e));}};next(w,8);}return .ok(false);}
    if(w.phase==10){let usize end=w.end;let bool done=switch(decoding::advance(input[..end],ref mut w.decoded,meter)){
            case .ok(v):{v}case .err(e):{return .err(source_error(e));}};
        if(done){let bool text=w.decoded.result.text;w.intern=interning::begin(text);w.phase=11;}return .ok(false);}
    if(w.phase==11){var interning::State frame=w.intern;let usize length=w.decoded.result.length;
        let ref u8[] data=ref w.decoded.result.data;
        let Result<bool,images::Error> result=interning::advance(candidate,data[..length],ref mut frame,meter);w.intern=frame;
        switch(result){case .ok(done):{if(done){w.literal=switch(interning::prepared(ref w.intern)){
                        case .ok(v):{v}case .err(e):{return .err(image_error(e));}};w.phase=12;}}
            case .err(e):{return .err(image_error(e));}};return .ok(false);}
    let bool admitted=switch(budget::admit(meter,4096,0)){case .ok(v):{v}case .err(e):{return .err(source_error(e));}};
    if(!admitted){return .ok(false);}
    if(w.phase==0){w.phase=1;return .ok(false);}
    if(w.phase==1){if(input.len>4096){return .err(source(4,4096));}w.phase=2;return .ok(false);}
    if(w.phase==3){candidate.limit=original.limit;candidate.catalog.count=original.catalog.count;candidate.catalog.used=original.catalog.used;
        w.row=0;w.phase=4;return .ok(false);}
    if(w.phase==4){if(w.row==16){w.cursor=0;w.phase=5;return .ok(false);}
        let usize row=w.row;candidate.catalog.starts[row]=original.catalog.starts[row];candidate.catalog.ends[row]=original.catalog.ends[row];
        candidate.catalog.text[row]=original.catalog.text[row];w.row+=1;return .ok(false);}
    if(w.phase==5){let usize stop=w.cursor+64;
        while(w.cursor<stop){let usize at=w.cursor;candidate.data[at]=original.data[at];w.cursor+=1;w.visits+=1;}
        if(w.cursor==4096){w.phase=6;}return .ok(false);}
    if(w.phase==6){let usize count=if(scope.modules==0){1}else{scope.modules};
        if(w.file==count){w.result.enabled=true;w.done=true;return .ok(true);}
        w.end=if(scope.modules==0){input.len}else{scope.ends[w.file] as usize};w.state=states::begin(w.base);w.phase=7;return .ok(false);}
    if(w.phase==8){if(w.token.kind==0){w.base=w.end;w.file+=1;w.phase=6;return .ok(false);}
        if(w.token.kind==3 || w.token.kind==4){if(w.result.count==16){return .err(source(4,w.token.begin));}
            reset_decoded(w);w.phase=9;return .ok(false);}next(w,8);return .ok(false);}
    if(w.phase==9){let usize stop=w.clear+64;
        while(w.clear<stop){let usize at=w.clear;w.decoded.result.data[at]=0;w.clear+=1;w.visits+=1;}
        if(w.clear==4096){w.phase=10;}return .ok(false);}
    if(w.phase==12){let usize row=w.result.count;let usize begin=w.decoded.result.begin;let usize end=w.decoded.result.end;
        let usize length=w.decoded.result.length;let usize id=w.literal;let u8 kind=if(w.decoded.result.text){2}else{1};
        if(end!=w.token.end){return .err(source(1,w.token.begin));}
        w.result.begins[row]=begin;w.result.ends[row]=end;w.result.literals[row]=id;w.result.lengths[row]=length;w.result.kinds[row]=kind;
        w.result.count+=1;next(w,8);return .ok(false);}
    return .err(source(5,0));
}
