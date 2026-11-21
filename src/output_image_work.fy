module output_image_work;
import static_image as images;
import std::text as utf8;
import metadata_budget as budget;
import errors as errors;
import runtime_clock as clock;

// Independent immutable-image analysis. Catalog validation precedes every UTF-8
// byte, just as in images::inspect. A text stage checks <=259 bytes, extending a
// 256-byte cut by <=3 continuation bytes to keep valid scalars together.
pub struct State { u8 phase; usize literal; usize cursor; usize count; bool done; }
pub fn State empty(){return State{.phase=0,.literal=0,.cursor=0,.count=0,.done=false};}
pub fn Result<bool,images::Error> advance(ref images::Image image,ref mut State w,ref mut budget::State meter){
    return advance_catalog(images::catalog(image),images::payload(image),images::payload_capacity(image),w,meter);
}
// Keep ordinary verification on the same bounded image work when timed.
pub fn Result<usize,errors::Error> inspect_until(ref images::Image image,usize deadline){
    if(deadline==0){
        return switch(images::inspect(image)){case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(5,0))}};
    }
    var State w=empty();var budget::State meter=budget::empty();
    while(!w.done){
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        let usize allowance=budget::reset(ref mut meter,0)?;
        switch(advance(image,ref mut w,ref mut meter)){
            case .ok(_):{}case .err(_):{return .err(errors::make(5,0));}
        };
    }
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    return .ok(w.count);
}
// Candidate-data analysis remains separate from owning immutable Image proof.
pub fn Result<bool,images::Error> advance_catalog(ref images::Catalog c,ref u8[] data,usize capacity,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}
    let bool admitted=switch(budget::admit(meter,4096,0)){case .ok(v):{v}case .err(_):{return .err(.State);}};
    if(!admitted){return .ok(false);}
    if(w.phase==0){
        if(capacity!=data.len || c.count>16 || c.used>4096 || c.used!=data.len){return .err(.State);}
        var usize last=0;var usize i=0;
        while(i<16){
            if(i<c.count){if(c.starts[i]!=last || c.ends[i]<last || c.ends[i]>c.used){return .err(.State);}last=c.ends[i];}
            else if(c.starts[i]!=0 || c.ends[i]!=0 || c.text[i]){return .err(.State);}i+=1;
        }
        if(last!=c.used){return .err(.State);}
        w.phase=1;w.count=c.count;return .ok(false);
    }
    if(w.phase!=1){return .err(.State);}
    if(w.literal==w.count){w.done=true;return .ok(true);}
    let usize literal=w.literal;
    if(!c.text[literal]){w.literal+=1;w.cursor=0;return .ok(false);}
    let ref u8[] text=data[c.starts[literal]..c.ends[literal]];
    let usize end=images::text_chunk_end(text,w.cursor);
    if(!utf8::validate_utf8(text[w.cursor..end]).is_ok){return .err(.Utf8);}
    w.cursor=end;
    if(end==text.len){w.literal+=1;w.cursor=0;}
    return .ok(false);
}
