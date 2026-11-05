module reference_words;
import static_views as views;
import errors as errors;

// A frame-local selector, never a ticket or authority. Image words keep their
// existing low 26 bits. Runtime selectors name either a logical formal or a
// returned receipt site. Full tickets remain in native Call/Held receipts.
// argument 0..7 selects a formal; 16..31 selects a returned receipt site.
pub struct Word { usize argument; views::Span span; }
pub fn bool runtime(u32 word){return word>=2147483648;}
pub fn Result<u32,errors::Error> pack(usize argument,views::Span span,usize offset){
    if(argument>=8){return .err(errors::make(5,offset));}
    let u32 range=views::pack(span.start,span.length,4096,offset)?;
    var u32 word=2147483648;var usize i=0;while(i<argument){word+=67108864;i+=1;}
    return .ok(word+range);
}
pub fn Result<u32,errors::Error> pack_result(usize site,views::Span span,usize offset){
    if(site>=16){return .err(errors::make(5,offset));}
    let u32 range=views::pack(span.start,span.length,4096,offset)?;
    var u32 word=3221225472;var usize i=0;while(i<site){word+=67108864;i+=1;}
    return .ok(word+range);
}
pub fn bool returned(u32 word){return word>=3221225472;}
pub fn Result<Word,errors::Error> unpack(u32 word,usize offset){
    // Formal bit 29 remains reserved. Returned words use bits 26..29 for site.
    if(word<2147483648 || (word>=2684354560 && !returned(word))){return .err(errors::make(5,offset));}
    let u32 value=word-if(returned(word)){3221225472}else{2147483648};
    let views::Span span=views::unpack(value%67108864,4096,offset)?;
    let usize base=if(returned(word)){16}else{0};
    return .ok(Word{.argument=base+(value/67108864) as usize,.span=span});
}
