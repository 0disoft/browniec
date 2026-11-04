module static_views;
import static_ir as statics;
import errors as errors;

// A packed range is metadata only, never image ownership or a live handle.
// 13 bits each encode an absolute start and length in the <=4096-byte image.
// Caller-owned frame slices have sixteen words; 32 frames use 2048 bytes with
// fixed-width u32 descriptors. Liveness and owning image proof stay separate.
pub struct Span { usize start; usize length; }
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
pub fn Result<u32,errors::Error> pack(usize start,usize length,usize payload,usize offset){
    if(payload>4096 || start>payload || length>payload-start){return .err(invalid(offset));}
    // The pinned SDK has no usize-to-u32 narrowing operation. Both fields are
    // bounded above; this exact conversion performs at most 26 iterations.
    var usize rest=start*8192+length;var u32 word=0;var u32 power=1;
    while(rest>0){if(rest%2!=0){word+=power;}rest/=2;if(rest>0){power*=2;}}
    return .ok(word);
}
pub fn Result<Span,errors::Error> unpack(u32 word,usize payload,usize offset){
    if(word>=67108864){return .err(invalid(offset));}
    let usize start=(word/8192) as usize;let usize length=(word%8192) as usize;
    if(payload>4096 || start>payload || length>payload-start){return .err(invalid(offset));}
    return .ok(Span{.start=start,.length=length});
}
// Independently admitted Sites supplies the maximum image window and exact
// function/kind. This helper neither validates an Image nor pins a Program.
// Text can only retain its exact already-validated window; byte subranges do
// not become validated text, even when their bytes happen to be valid UTF-8.
pub fn Result<Span,errors::Error> inspect(ref statics::Sites sites,usize site,usize function,
    u8 kind,u32 word,usize payload,usize offset){
    if(sites.count==0 || sites.count>16 || site>=16 || function>=16 || kind>2 ||
        sites.definitions[site]>=256 || sites.functions[site]!=function ||
        (sites.kinds[site]!=1 && sites.kinds[site]!=2) ||
        (kind!=0 && sites.kinds[site]!=kind)){return .err(invalid(offset));}
    let usize one=1;
    if((sites.generic&(one<<site))!=0){
        let Span actual=unpack(word,payload,offset)?;var usize root=0;
        while(root<16){if((sites.roots[site]&(one<<root))!=0){
                if(sites.definitions[root]>=256 || sites.kinds[root]==0 || (sites.generic&(one<<root))!=0){return .err(invalid(offset));}
                let usize lo=sites.spans[root].start;let usize hi=sites.spans[root].end;let usize base=sites.starts[root];
                if(hi<lo || hi>4096 || sites.spans[root].literal>=16 || base>payload || hi-lo>payload-base){return .err(invalid(offset));}
                let usize size=hi-lo;
                if(actual.start>=base && actual.start<=base+size && actual.length<=base+size-actual.start &&
                    (sites.kinds[site]!=2 || (sites.kinds[root]==2 && actual.start==base && actual.length==size))){return .ok(actual);}
            }root+=1;
        }return .err(invalid(offset));
    }
    let usize lo=sites.spans[site].start;let usize hi=sites.spans[site].end;
    if(hi<lo || hi>4096 || sites.spans[site].literal>=16){return .err(invalid(offset));}
    let usize base=sites.starts[site];let usize size=hi-lo;
    let u32 bounded=pack(base,size,payload,offset)?;
    let Span actual=unpack(word,payload,offset)?;
    if(actual.start<base || actual.start>base+size || actual.length>base+size-actual.start ||
        (sites.kinds[site]==2 && (actual.start!=base || actual.length!=size))){return .err(invalid(offset));}
    return .ok(actual);
}
pub fn Result<Span,errors::Error> live(ref statics::Sites sites,usize site,usize function,
    u8 kind,ref u32[] words,usize bits,usize payload,usize offset){
    let usize one=1;
    if(words.len!=16 || site>=16 || bits>=65536 || (bits&(one<<site))==0){return .err(invalid(offset));}
    return inspect(sites,site,function,kind,words[site],payload,offset);
}
// Guest endpoints are relative to the actual parent, including empty ranges.
// Validate before addition/subtraction, even for forged native Span arguments.
// The VM must prepay its complete instruction before invoking this endpoint
// operation or publishing the returned word. No caller storage is mutated here.
pub fn Result<u32,errors::Error> crop(ref Span parent,usize lo,usize hi,usize payload,usize offset){
    let u32 valid=pack(parent.start,parent.length,payload,offset)?;
    if(lo>hi || hi>parent.length){return .err(errors::make(14,offset));}
    return pack(parent.start+lo,hi-lo,payload,offset);
}
