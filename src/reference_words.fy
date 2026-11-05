module reference_words;
import static_views as views;
import errors as errors;

// A frame-local selector, never a ticket or authority. Image words keep their
// existing low 26 bits. Runtime words add a tag and 3-bit logical formal index;
// the exact full-generation ticket stays in the existing native Call receipt.
pub struct Word { usize argument; views::Span span; }
pub fn bool runtime(u32 word){return word>=2147483648;}
pub fn Result<u32,errors::Error> pack(usize argument,views::Span span,usize offset){
    if(argument>=8){return .err(errors::make(5,offset));}
    let u32 range=views::pack(span.start,span.length,4096,offset)?;
    var u32 word=2147483648;var usize i=0;while(i<argument){word+=67108864;i+=1;}
    return .ok(word+range);
}
pub fn Result<Word,errors::Error> unpack(u32 word,usize offset){
    // Bits 29/30 are reserved; packed-zero is a valid empty relative range.
    if(word<2147483648 || word>=2684354560){return .err(errors::make(5,offset));}
    let u32 value=word-2147483648;
    let views::Span span=views::unpack(value%67108864,4096,offset)?;
    return .ok(Word{.argument=(value/67108864) as usize,.span=span});
}
