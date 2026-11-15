module tests::m2::static_view_validation;
import static_views as views;
import static_ir as statics;
import static_image as images;
import errors as errors;

// Exact b6e054c static_views oracle; only visibility, type aliases and local
// function names differ. Keep its original packing during validation.
// A packed range is metadata only, never image ownership or a live handle.
// 13 bits each encode an absolute start and length in the <=4096-byte image.
// Caller-owned frame slices have sixteen words; 32 frames use 2048 bytes with
// fixed-width u32 descriptors. Liveness and owning image proof stay separate.
fn errors::Error original_invalid(usize offset){return errors::make(5,offset);}
fn Result<u32,errors::Error> original_pack(usize start,usize length,usize payload,usize offset){
    if(payload>4096 || start>payload || length>payload-start){return .err(original_invalid(offset));}
    // The pinned SDK has no usize-to-u32 narrowing operation. Both fields are
    // bounded above; this exact conversion performs at most 26 iterations.
    var usize rest=start*8192+length;var u32 word=0;var u32 power=1;
    while(rest>0){if(rest%2!=0){word+=power;}rest/=2;if(rest>0){power*=2;}}
    return .ok(word);
}
fn Result<views::Span,errors::Error> original_unpack(u32 word,usize payload,usize offset){
    if(word>=67108864){return .err(original_invalid(offset));}
    let usize start=(word/8192) as usize;let usize length=(word%8192) as usize;
    if(payload>4096 || start>payload || length>payload-start){return .err(original_invalid(offset));}
    return .ok(views::Span{.start=start,.length=length});
}
// Independently admitted Sites supplies the maximum image window and exact
// function/kind. This helper neither validates an Image nor pins a Program.
// Text can only retain its exact already-validated window; byte subranges do
// not become validated text, even when their bytes happen to be valid UTF-8.
fn Result<views::Span,errors::Error> original_inspect(ref statics::Sites sites,usize site,usize function,
    u8 kind,u32 word,usize payload,usize offset){
    if(sites.count==0 || sites.count>16 || site>=16 || function>=16 || kind>2 ||
        sites.definitions[site]>=256 || sites.functions[site]!=function ||
        (sites.kinds[site]!=1 && sites.kinds[site]!=2 && sites.kinds[site]!=3) ||
        (kind!=0 && sites.kinds[site]!=kind && !(kind==1 && sites.kinds[site]==3))){return .err(original_invalid(offset));}
    let usize one=1;
    if((sites.generic&(one<<site))!=0){
        let views::Span actual=original_unpack(word,payload,offset)?;var usize root=0;
        while(root<16){if((sites.roots[site]&(one<<root))!=0){
                if(sites.definitions[root]>=256 || sites.kinds[root]==0 || (sites.generic&(one<<root))!=0){return .err(original_invalid(offset));}
                let usize lo=sites.spans[root].start;let usize hi=sites.spans[root].end;let usize base=sites.starts[root];
                if(hi<lo || hi>4096 || sites.spans[root].literal>=16 || base>payload || hi-lo>payload-base){return .err(original_invalid(offset));}
                let usize size=hi-lo;
                if(actual.start>=base && actual.start<=base+size && actual.length<=base+size-actual.start &&
                    (sites.kinds[site]!=2 || (sites.kinds[root]==2 && actual.start==base && actual.length==size))){return .ok(actual);}
            }root+=1;
        }return .err(original_invalid(offset));
    }
    let usize lo=sites.spans[site].start;let usize hi=sites.spans[site].end;
    if(hi<lo || hi>4096 || sites.spans[site].literal>=16){return .err(original_invalid(offset));}
    let usize base=sites.starts[site];let usize size=hi-lo;
    let u32 bounded=original_pack(base,size,payload,offset)?;
    let views::Span actual=original_unpack(word,payload,offset)?;
    if(actual.start<base || actual.start>base+size || actual.length>base+size-actual.start ||
        (sites.kinds[site]==2 && (actual.start!=base || actual.length!=size))){return .err(original_invalid(offset));}
    return .ok(actual);
}
fn Result<views::Span,errors::Error> original_live(ref statics::Sites sites,usize site,usize function,
    u8 kind,ref u32[] words,usize bits,usize payload,usize offset){
    let usize one=1;
    if(words.len!=16 || site>=16 || bits>=65536 || (bits&(one<<site))==0){return .err(original_invalid(offset));}
    return original_inspect(sites,site,function,kind,words[site],payload,offset);
}
// Guest endpoints are relative to the actual parent, including empty ranges.
// Validate before addition/subtraction, even for forged native views::Span arguments.
// The VM must prepay its complete instruction before invoking this endpoint
// operation or publishing the returned word. No caller storage is mutated here.
fn Result<u32,errors::Error> original_crop(ref views::Span parent,usize lo,usize hi,usize payload,usize offset){
    let u32 valid=original_pack(parent.start,parent.length,payload,offset)?;
    if(lo>hi || hi>parent.length){return .err(errors::make(14,offset));}
    return original_pack(parent.start+lo,hi-lo,payload,offset);
}

fn void same_span(Result<views::Span,errors::Error> actual,Result<views::Span,errors::Error> expected){
    switch(expected){
        case .ok(want):{switch(actual){case .ok(got):{assert(got.start==want.start && got.length==want.length);}case .err(_):{assert(false);}};}
        case .err(want):{switch(actual){case .ok(_):{assert(false);}case .err(got):{assert(got.kind==want.kind && got.offset==want.offset);}};}
    };
}
fn void same_word(Result<u32,errors::Error> actual,Result<u32,errors::Error> expected){
    switch(expected){
        case .ok(want):{switch(actual){case .ok(got):{assert(got==want);}case .err(_):{assert(false);}};}
        case .err(want):{switch(actual){case .ok(_):{assert(false);}case .err(got):{assert(got.kind==want.kind && got.offset==want.offset);}};}
    };
}
fn statics::Sites fixture(usize start,usize length,u8 kind){
    var statics::Sites s=statics::empty();s.count=2;
    s.definitions[0]=0;s.functions[0]=0;s.starts[0]=start;s.kinds[0]=kind;
    s.spans[0]=images::Span{.literal=0,.start=0,.end=length};
    s.definitions[1]=1;s.functions[1]=0;s.kinds[1]=kind;s.generic=2;s.roots[1]=1;
    return s;
}
@test fn void concrete_and_generic_windows_match_original_bounds_errors_and_text_rules(){
    let usize[8] edges=[0,1,2,4095,4096,4097,18446744073709551614,18446744073709551615];
    let u32[12] words=[0,1,4096,8191,8192,8194,16384,33546241,33554432,67108863,67108864,4294967295];
    var usize p=0;while(p<8){var usize a=0;while(a<8){var usize n=0;while(n<8){
        var u8 kind=1;while(kind<=2){let statics::Sites s=fixture(edges[a],edges[n],kind);
            var usize w=0;while(w<12){var usize site=0;while(site<2){
                same_span(views::inspect(ref s,site,0,kind,words[w],edges[p],71),
                    original_inspect(ref s,site,0,kind,words[w],edges[p],71));site+=1;
            }w+=1;}kind+=1;
        }n+=1;
    }a+=1;}p+=1;}
}
@test fn void forged_parent_and_endpoint_matrix_preserves_metadata_error_precedence(){
    let usize[8] edges=[0,1,2,4095,4096,4097,18446744073709551614,18446744073709551615];
    var usize p=0;while(p<8){var usize a=0;while(a<8){var usize n=0;while(n<8){
        let views::Span parent=views::Span{.start=edges[a],.length=edges[n]};
        same_word(views::pack(parent.start,parent.length,edges[p],71),
            original_pack(parent.start,parent.length,edges[p],71));
        var usize lo=0;while(lo<8){var usize hi=0;while(hi<8){
            same_word(views::crop(ref parent,edges[lo],edges[hi],edges[p],71),
                original_crop(ref parent,edges[lo],edges[hi],edges[p],71));hi+=1;
        }lo+=1;}n+=1;
    }a+=1;}p+=1;}
}
@test fn void every_full_image_suffix_and_its_empty_end_remain_representable(){
    var usize start=0;while(start<=4096){let usize length=4096-start;
        let views::Span parent=views::Span{.start=start,.length=length};
        let u32 word=switch(original_pack(start,length,4096,71)){case .ok(v):{v}case .err(_):{assert(false);0}};
        let statics::Sites s=fixture(start,length,1);
        same_span(views::inspect(ref s,0,0,1,word,4096,71),original_inspect(ref s,0,0,1,word,4096,71));
        same_word(views::crop(ref parent,0,length,4096,71),.ok(word));
        same_word(views::crop(ref parent,length,length,4096,71),original_pack(4096,0,4096,71));
        start+=1;
    }
}
