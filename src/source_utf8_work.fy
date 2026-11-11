module source_utf8_work;
import std::text as utf8;
import errors as errors;
import metadata_budget as budget;
// One fresh source stage validates <=259 bytes, extending a 256-byte cut
// only over continuation bytes. Callers pin the exact immutable byte view.
pub struct State { usize cursor; bool done; }
pub fn State empty(){return State{.cursor=0,.done=false};}
pub fn Result<usize,errors::Error> chunk(ref u8[] source,usize cursor){
    if(source.len>4096){return .err(errors::make(4,4096));}
    if(cursor>source.len){return .err(errors::make(5,0));}
    var usize end=cursor+256;if(end>source.len){end=source.len;}
    var usize extra=0;while(end<source.len && extra<3 && (source[end]&192)==128){end+=1;extra+=1;}
    if(!utf8::validate_utf8(source[cursor..end]).is_ok){return .err(errors::make(1,0));}
    return .ok(end);
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(!budget::admit(meter,4096,0)?){return .ok(false);}
    w.cursor=chunk(source,w.cursor)?;w.done=w.cursor==source.len;return .ok(w.done);
}
