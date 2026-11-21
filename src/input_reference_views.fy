module input_reference_views;
import errors as errors;
import static_views as views;
import std::bytes as bytes;
import std::num as num;
import metadata_budget as budget;

// Metadata only. Frame zero is reserved, including its 16 sites and 8 grants.
struct Cell { usize start; usize length; bool active; }
pub resource State { bytes::Buffer cells; ptr mut u8 data; usize length; usize descriptor_limit; usize live_sites; cleanup { } }
pub fn State disabled(){return State{.cells=bytes::empty(),.data=null,.length=0,.descriptor_limit=512,.live_sites=0};}
pub fn bool enabled(ref State state){return bytes::view(ref state.cells).len==18432;}
// Bounds-only preflight for unpublished child-frame grants; no cell access.
pub fn bool accepts(ref State state,views::Span span){
    return enabled(state) && span.start<=state.length && span.length<=state.length-span.start;
}
pub fn u32 marker(){return 1073741824;}
pub fn bool is_input(u32 word){return word==marker();}
fn errors::Error invalid(usize offset){return errors::make(5,offset);}

// Private setup alternative. The backing is reserved once before any resumes;
// no cell is exposed through the public API until all 768 are initialized.
pub fn Result<State,errors::Error> reserve(usize length){
    return reserve_with_limit(length,512);
}
pub fn Result<State,errors::Error> reserve_with_limit(usize length,usize limit){
    if(length>1048576 || limit==0 || limit>512){return .err(invalid(0));}
    // Vec<Cell>::reserve(768) formerly rounded to 1024 cells (24576 bytes).
    var bytes::Buffer cells=switch(bytes::with_capacity(24576)){
        case .ok(v):{v}case .err(_):{return .err(errors::make(15,0));}};
    let ptr mut u8 data=unsafe {bytes::view_mut(ref mut cells) as ptr mut u8};
    if(data==null){return .err(invalid(0));}
    return .ok(State{.cells=cells,.data=data,.length=length,.descriptor_limit=limit,.live_sites=0});
}
// Public Buffer ABI, with the same first-field ownership seam as runtime_output.
@link_name("fy_std_buffer_append_v0") unsafe extern C fn u32 append_cells_raw(ptr mut void buffer,ptr u8 data,usize length);
@link_name("fy_std_buffer_reserve_v0") unsafe extern C fn u32 validate_cells_raw(ptr mut void buffer,usize capacity);
fn usize initialized_cells(ref State state){return bytes::view(ref state.cells).len;}
fn usize reserved_cells(ref State state){return bytes::capacity(ref state.cells);}
pub fn Result<bool,errors::Error> initialize_chunk(ref mut State state,ref mut budget::State allowance){
    if(allowance.last!=0){return .ok(false);}
    let usize length=initialized_cells(state);
    if(length>18432 || length%24!=0 || reserved_cells(state)<24576 || state.length>1048576){return .err(invalid(0));}
    if(length==18432){if(state.data==null){return .err(invalid(0));}return .ok(true);}
    if(state.data==null){return .err(invalid(0));}
    if(!budget::admit(allowance,4096,0)?){return .ok(false);}
    // At most 16 cells: 384 initialized scratch bytes and 384 appended bytes,
    // leaving room for owning Cursor/frame visits. This bounds logical entries,
    // without a CPU, wall-time or peak-stack claim.
    let usize count=if(18432-length<384){18432-length}else{384};
    let u8[384] zero=[0;384];let ref u8[] chunk=ref zero[..count];
    assert(unsafe {append_cells_raw(state as ptr mut void,chunk as ptr u8,count)}==0);
    assert(unsafe {validate_cells_raw(state as ptr mut void,0)}==0);
    return .ok(length+count==18432);
}

// Automatic resource destruction releases the entire unpublished vector on any
// failure. No partially initialized State escapes, including for empty input.
pub fn Result<State,errors::Error> open(usize length){
    if(length>1048576){return .err(invalid(0));}
    var bytes::Buffer cells=switch(bytes::with_capacity(24576)){
        case .ok(v):{v}case .err(_):{return .err(errors::make(15,0));}};
    if(!bytes::resize_zeroed(ref mut cells,18432).is_ok){return .err(errors::make(15,0));}
    let ptr mut u8 data=unsafe {bytes::view_mut(ref mut cells) as ptr mut u8};
    assert(data!=null);
    return .ok(State{.cells=cells,.data=data,.length=length,.descriptor_limit=512,.live_sites=0});
}
// Formal grants are provenance for the matching sites. Only live sites and
// array tickets consume descriptor entries; grants retain their memory charge.
pub fn bool configured_quota(ref State state){return state.descriptor_limit<512;}
pub fn Result<usize,errors::Error> check_descriptors(ref State state,usize tickets,usize added,usize offset){
    if(state.live_sites+tickets+added>state.descriptor_limit){return .err(errors::make(13,offset));}
    return .ok(0);
}
fn Result<usize,errors::Error> index(usize frame,usize slot,bool formal,usize offset){
    let usize width=if(formal){8}else{16};
    if(frame==0 || frame>=32 || slot>=width){return .err(invalid(offset));}
    return .ok(if(formal){512+frame*8+slot}else{frame*16+slot});
}
fn Result<views::Span,errors::Error> read(ref State state,usize at,usize offset){
    if(!enabled(state)){return .err(invalid(offset));}
    let ref u8[] cells=bytes::view(ref state.cells);let usize base=at*24;
    if(cells[base+16]==0){return .err(invalid(offset));}
    var usize start=0;var usize length=0;var usize i=8;
    while(i>0){i-=1;start=start*256+cells[base+i] as usize;length=length*256+cells[base+8+i] as usize;}
    return .ok(views::Span{.start=start,.length=length});
}
pub fn Result<views::Span,errors::Error> get(ref State state,usize frame,usize site,usize offset){
    return read(state,index(frame,site,false,offset)?,offset);
}
pub fn Result<views::Span,errors::Error> grant(ref State state,usize frame,usize argument,usize offset){
    return read(state,index(frame,argument,true,offset)?,offset);
}
// The pinned compiler cannot mutably project resource fields. Capture only the
// fixed allocation's address at open; Buffer remains its sole owner, never grows,
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
    let usize at=index(frame,site,false,offset)?;
    let usize installed=publish(state,at,span,offset)?;state.live_sites+=1;
    return .ok(installed);
}
pub fn Result<usize,errors::Error> put_grant(ref mut State state,usize frame,usize argument,views::Span span,usize offset){
    let usize at=index(frame,argument,true,offset)?;return publish(state,at,span,offset);
}
pub fn Result<usize,errors::Error> close(ref mut State state,usize frame,usize site,usize offset){
    let usize at=index(frame,site,false,offset)?;
    if(!enabled(state)){return .err(invalid(offset));}
    if(!read(state,at,offset).is_ok){return .err(invalid(offset));}
    assert(state.live_sites!=0);
    save(state,at,Cell{.start=0,.length=0,.active=false});state.live_sites-=1;
    return .ok(0);
}
fn bool occupied(ref State state,usize at){
    let ref u8[] cells=bytes::view(ref state.cells);
    return cells[at*24+16]!=0;
}
pub fn Result<usize,errors::Error> clear_frame(ref mut State state,usize frame,usize offset){
    let usize base=index(frame,0,false,offset)?;
    if(!enabled(state)){return .ok(0);}
    var usize i=0;while(i<16){
        if(occupied(state,base+i)){assert(state.live_sites!=0);state.live_sites-=1;}
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
