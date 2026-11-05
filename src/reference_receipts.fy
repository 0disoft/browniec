module reference_receipts;
import reference_words as words;
import reference_access as access;
import static_views as views;
import slice_result_bindings as bindings;
import slice_result_runtime as runtime;
import array_slices as slices;
import fuel as fuel;
import errors as errors;

pub struct Closed { usize live; usize remaining; }
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
// Metadata only. The caller owns the exact live frame/word; payload access
// separately authenticates the complete native generation/root/lease.
pub fn Result<access::Source,errors::Error> source(ref bindings::State held,usize frame,u32 word,usize offset){
    let words::Word value=words::unpack(word,offset)?;
    if(value.argument<16){return .err(invalid(offset));}
    let usize location=switch(bindings::reference_location(frame,value.argument-16)){
        case .ok(v):{v}case .err(_):{return .err(invalid(offset));}
    };
    let usize index=bindings::find(held,location);if(index==47){return .err(invalid(offset));}
    let runtime::Held receipt=held.held[index];
    if(receipt.frame!=frame || receipt.exclusive || receipt.view.element!=10 || receipt.issued.slot>=16 ||
        receipt.issued.generation==0 || receipt.view.start>receipt.view.end){return .err(invalid(offset));}
    let usize length=receipt.view.end-receipt.view.start;
    if(value.span.start>length || value.span.length>length-value.span.start){return .err(invalid(offset));}
    return .ok(access::loan_window(receipt.issued,value.span));
}
// Unpublished metadata until native handoff succeeds. Packing/store validation
// precedes the plain word/live publication; no payload or lease is copied.
pub fn Result<usize,errors::Error> publish(ref mut bindings::State held,usize frame,usize site,
    runtime::Held receipt,views::Span span,ref mut u32[] current,usize live,usize offset){
    let usize one=1;
    if(current.len!=16 || site>=16 || live>=65536 || (live&(one<<site))!=0 ||
        receipt.view.start>receipt.view.end){return .err(invalid(offset));}
    let usize length=receipt.view.end-receipt.view.start;
    if(span.start>length || span.length>length-span.start){return .err(invalid(offset));}
    let u32 word=words::pack_result(site,span,offset)?;
    let usize saved=switch(bindings::retain_reference(held,frame,site,receipt)){
        case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
    };
    current[site]=word;return .ok(live|(one<<site));
}
// Logical aliases share one existing Held receipt. Last close consumes it
// physically using handoff's prepaid reserve; failure leaves the word live.
pub fn Result<Closed,errors::Error> close(ref mut bindings::State held,ref mut runtime::State native,
    usize frame,usize site,ref mut u32[] current,usize live,usize capacity,usize remaining,usize offset){
    let usize one=1;
    if(current.len!=16 || frame>=32 || site>=16 || live>=65536 || (live&(one<<site))==0){return .err(invalid(offset));}
    let usize price=fuel::reference_result_close();if(remaining<price){return .err(errors::make(8,offset));}
    let access::Source selected=source(held,frame,current[site],offset)?;
    let words::Word value=words::unpack(current[site],offset)?;var bool alias=false;var usize i=0;
    while(i<16){if(i!=site && (live&(one<<i))!=0 && words::runtime(current[i])){
        let words::Word other=words::unpack(current[i],offset)?;
        if(other.argument==value.argument){alias=true;}
    }i+=1;}
    if(!alias){let usize location=switch(bindings::reference_location(frame,value.argument-16)){
            case .ok(v):{v}case .err(_):{return .err(invalid(offset));}
        };
        let bindings::Closed closed=switch(bindings::close(held,native,location,selected.ticket,capacity,remaining-price)){
            case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,offset));}
        };
    }
    current[site]=0;return .ok(Closed{.live=live^(one<<site),.remaining=remaining-price});
}
