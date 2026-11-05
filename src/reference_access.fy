module reference_access;
import static_ir as statics;
import static_views as views;
import array_slices as slices;
import array_owners as owners;
import array_vm as arrays;
import fuel as fuel;
import cells as cells;
import errors as errors;
import std::num as num;

// An invocation-local access selector, not a retained descriptor or authority.
// The caller still holds its proved frame, exact image borrow and native leases.
// Inactive fields are canonical; no integer/pointer coercion chooses storage.
pub struct Source { u8 storage; usize site; slices::Ticket ticket; bool window; views::Span span; }
pub struct Value { i64 value; usize remaining; }
pub fn Source image(usize site){return Source{.storage=1,.site=site,.ticket=slices::Ticket{.slot=16,.generation=0},.window=false,.span=views::Span{.start=0,.length=0}};}
pub fn Source loan(slices::Ticket ticket){return Source{.storage=2,.site=16,.ticket=ticket,.window=false,.span=views::Span{.start=0,.length=0}};}
pub fn Source loan_window(slices::Ticket ticket,views::Span span){return Source{.storage=2,.site=16,.ticket=ticket,.window=true,.span=span};}
fn bool canonical(ref Source source){
    let bool inactive=!source.window && source.span.start==0 && source.span.length==0;
    if(source.storage==1){return source.site<16 && source.ticket.slot==16 && source.ticket.generation==0 && inactive;}
    return source.storage==2 && source.site==16 &&
        (inactive || (source.window && source.span.start<=4096 && source.span.length<=4096-source.span.start));
}
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
fn Result<usize,errors::Error> byte_ticket(ref slices::Pool pool,slices::Ticket ticket,usize offset){
    if(ticket.slot>=16 || pool.slots[ticket.slot].view.element!=10){return .err(invalid(offset));}
    // Full generation, root, lease and pool validation follows in slices access.
    return .ok(ticket.slot);
}
// Shared bounds/codec after complete prepayment and image/span authentication.
// Keep the compatibility Static executor and canonical selector identical.
pub fn Result<i64,errors::Error> checked_byte(ref u8[] payload,views::Span span,i64 index,usize offset){
    if(span.start>payload.len || span.length>payload.len-span.start){return .err(invalid(offset));}
    let usize selected=switch(num::usize_from_i64(index)){
        case .ok(v):{v}case .err(_):{return .err(errors::make(14,offset));}
    };
    if(selected>=span.length){return .err(errors::make(14,offset));}
    return .ok(payload[span.start+selected] as i64);
}
// One byte-reference contract across both backing kinds. Source validation is
// bounded metadata; complete Fuel precedes index checks and any payload read.
pub fn Result<Value,errors::Error> read(ref Source source,ref statics::Sites sites,usize function,
    ref u32[] words,usize live,ref u8[] payload,ref slices::Pool pool,ref owners::Table table,
    ref u8[] data,i64 index,usize remaining,usize offset){
    if(!canonical(source)){return .err(invalid(offset));}
    if(source.storage==1){
        let views::Span span=views::live(sites,source.site,function,1,words,live,payload.len,offset)?;
        let usize price=fuel::static_instruction(71,span.length,0);
        if(remaining<price){return .err(errors::make(8,offset));}
        return .ok(Value{.value=checked_byte(payload,span,index,offset)?,.remaining=remaining-price});
    }
    let usize price=fuel::slice_base(58,1);
    if(remaining<price){return .err(errors::make(8,offset));}
    let usize selected=cells::unpack(index,offset)?;
    let usize slot=byte_ticket(pool,source.ticket,offset)?;
    let i64 value=switch(if(source.window){slices::read_window(pool,source.ticket,table,source.span.start,source.span.length,selected,data)}
        else{slices::read(pool,source.ticket,table,selected,data)}){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
    };
    return .ok(Value{.value=value,.remaining=remaining-price});
}
pub fn Result<Value,errors::Error> length(ref Source source,ref statics::Sites sites,usize function,
    ref u32[] words,usize live,ref u8[] payload,ref slices::Pool pool,ref owners::Table table,
    usize capacity,usize remaining,usize offset){
    if(!canonical(source)){return .err(invalid(offset));}
    var usize length=0;var usize price=0;
    if(source.storage==1){
        let views::Span span=views::live(sites,source.site,function,1,words,live,payload.len,offset)?;
        length=span.length;price=fuel::static_instruction(72,length,0);
        if(remaining<price){return .err(errors::make(8,offset));}
    }else{
        price=fuel::slice_base(57,0);
        if(remaining<price){return .err(errors::make(8,offset));}
        let usize slot=byte_ticket(pool,source.ticket,offset)?;
        length=switch(slices::length(pool,source.ticket,table,capacity)){
            case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,offset));}
        };
        if(source.window){if(source.span.start>length || source.span.length>length-source.span.start){return .err(invalid(offset));}
            length=source.span.length;}
    }
    return .ok(Value{.value=cells::pack(length,offset)?,.remaining=remaining-price});
}
