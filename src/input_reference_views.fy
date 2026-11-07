module input_reference_views;
import errors as errors;
import static_views as views;
import std::vec as vec;
import std::num as num;

// Metadata only. Frame zero is reserved, including its 16 sites and 8 grants.
struct Cell { usize start; usize length; bool active; }
pub resource State { vec::Vec<Cell> cells; ptr mut void data; usize length; cleanup { } }
pub fn State disabled(){return State{.cells=vec::empty<Cell>(),.data=null,.length=0};}
pub fn bool enabled(ref State state){return vec::len<Cell>(ref state.cells)==768;}
pub fn u32 marker(){return 1073741824;}
pub fn bool is_input(u32 word){return word==marker();}
fn errors::Error invalid(usize offset){return errors::make(5,offset);}

// Automatic resource destruction releases the entire unpublished vector on any
// failure. No partially initialized State escapes, including for empty input.
pub fn Result<State,errors::Error> open(usize length){
    if(length>1048576){return .err(invalid(0));}
    var vec::Vec<Cell> cells=vec::empty<Cell>();
    if(!vec::reserve<Cell>(ref mut cells,768).is_ok){return .err(errors::make(15,0));}
    var usize i=0;while(i<768){
        if(!vec::push<Cell>(ref mut cells,Cell{.start=0,.length=0,.active=false}).is_ok){
            return .err(errors::make(15,0));
        }i+=1;
    }
    let ref mut Cell first=vec::at_mut<Cell>(ref mut cells,0);
    let ptr mut void data=unsafe {first as ptr mut void};
    assert(data!=null);
    return .ok(State{.cells=cells,.data=data,.length=length});
}
fn Result<usize,errors::Error> index(usize frame,usize slot,bool formal,usize offset){
    let usize width=if(formal){8}else{16};
    if(frame==0 || frame>=32 || slot>=width){return .err(invalid(offset));}
    return .ok(if(formal){512+frame*8+slot}else{frame*16+slot});
}
fn Result<views::Span,errors::Error> read(ref State state,usize at,usize offset){
    if(!enabled(state)){return .err(invalid(offset));}
    let ref Cell cell=vec::at<Cell>(ref state.cells,at);
    if(!cell.active){return .err(invalid(offset));}
    return .ok(views::Span{.start=cell.start,.length=cell.length});
}
pub fn Result<views::Span,errors::Error> get(ref State state,usize frame,usize site,usize offset){
    return read(state,index(frame,site,false,offset)?,offset);
}
pub fn Result<views::Span,errors::Error> grant(ref State state,usize frame,usize argument,usize offset){
    return read(state,index(frame,argument,true,offset)?,offset);
}
// The pinned compiler cannot mutably project resource fields. Capture only the
// fixed allocation's address at open; Vec remains its sole owner, never grows,
// and this owner-scoped mutable view cannot escape the private helper.
// Cell layout is pinned to Windows AMD64: usize at 0/8, bool at 16,
// stride 24. The native verifier independently asserts generated layout.
fn void word(ref mut u8[] bytes,usize at,usize value){
    var usize n=value;var usize i=0;while(i<8){
        let i64 digit=switch(num::i64_from_usize(n%256)){case .ok(v):{v}case .err(_):{assert(false);0}};
        bytes[at+i]=switch(num::u8_from_i64(digit)){case .ok(v):{v}case .err(_):{assert(false);0}};
        n/=256;i+=1;
    }
}
fn void save(ref mut State state,usize at,Cell value){
    let ref mut u8[] slots=unsafe {byte_slice::from_raw_parts_mut(state,state.data,18432)};
    word(slots,at*24,value.start);word(slots,at*24+8,value.length);
    slots[at*24+16]=if(value.active){1}else{0};
}
fn Result<usize,errors::Error> publish(ref mut State state,usize at,views::Span span,usize offset){
    if(!enabled(state) || span.start>state.length || span.length>state.length-span.start){return .err(invalid(offset));}
    if(read(state,at,offset).is_ok){return .err(invalid(offset));}
    save(state,at,Cell{.start=span.start,.length=span.length,.active=true});return .ok(0);
}
pub fn Result<usize,errors::Error> put(ref mut State state,usize frame,usize site,views::Span span,usize offset){
    let usize at=index(frame,site,false,offset)?;return publish(state,at,span,offset);
}
pub fn Result<usize,errors::Error> put_grant(ref mut State state,usize frame,usize argument,views::Span span,usize offset){
    let usize at=index(frame,argument,true,offset)?;return publish(state,at,span,offset);
}
pub fn Result<usize,errors::Error> close(ref mut State state,usize frame,usize site,usize offset){
    let usize at=index(frame,site,false,offset)?;
    if(!enabled(state)){return .err(invalid(offset));}
    if(!read(state,at,offset).is_ok){return .err(invalid(offset));}
    save(state,at,Cell{.start=0,.length=0,.active=false});return .ok(0);
}
pub fn Result<usize,errors::Error> clear_frame(ref mut State state,usize frame,usize offset){
    let usize base=index(frame,0,false,offset)?;
    if(!enabled(state)){return .ok(0);}
    var usize i=0;while(i<16){
        save(state,base+i,Cell{.start=0,.length=0,.active=false});i+=1;
    }
    i=0;while(i<8){
        save(state,512+frame*8+i,Cell{.start=0,.length=0,.active=false});i+=1;
    }return .ok(0);
}
// Reject forged overflowing absolute intervals without computing their ends.
fn bool valid(ref views::Span span){return span.length<=18446744073709551615-span.start;}
pub fn bool contains(ref views::Span outer,ref views::Span inner){
    if(!valid(outer) || !valid(inner) || inner.start<outer.start){return false;}
    let usize delta=inner.start-outer.start;
    return delta<=outer.length && inner.length<=outer.length-delta;
}
pub fn Result<views::Span,errors::Error> crop(ref views::Span parent,usize lo,usize hi,usize offset){
    if(!valid(parent) || lo>hi || hi>parent.length){return .err(errors::make(14,offset));}
    return .ok(views::Span{.start=parent.start+lo,.length=hi-lo});
}
