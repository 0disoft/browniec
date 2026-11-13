module aggregate_copy_source_work;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
// 1 stage owner leaves; 2 materialize slots/subrecord; 3 transfer staging slots;
// 4 clone record; 5 clone array; 6 load consecutive constructor registers.
// Metadata request 1 remains an explicit child, never a fictitious unit of work.
pub struct State { usize source; usize record; usize ordinal; usize first; usize function;
    usize offset; usize at; usize count; usize row; usize value; usize start; usize destination;
    usize slot; usize length; usize visits; u8 element; u8 mode; u8 phase; u8 request;
    bool mutable; bool consume; bool done; }
pub fn State begin(u8 mode,usize source,usize record,usize ordinal,usize first,usize function,
    bool mutable,bool consume,usize offset,usize at){return State{.source=source,.record=record,.ordinal=ordinal,.first=first,
    .function=function,.offset=offset,.at=at,.count=0,.row=0,.value=0,.start=0,.destination=16,.slot=0,.length=0,.visits=0,
    .element=0,.mode=mode,.phase=if(mode==4 || mode==5){20}else{0},.request=0,.mutable=mutable,.consume=consume,.done=false};}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.value);}
pub fn Result<usize,errors::Error> resume(ref mut State w,usize count){if(w.done || w.request!=1){return .err(errors::make(5,w.at));}
    w.request=0;w.count=count;return .ok(count);}
pub fn Result<bool,errors::Error> advance(ref mut ir::Program p,ref usize[] input,ref mut usize[] slots,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0 || w.request!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}w.visits+=1;
    if(w.phase==0){w.request=1;w.phase=1;return .ok(false);}
    if(w.phase==1){if((w.mode==1 || w.mode==3) && (w.first>slots.len || w.count>slots.len-w.first)){return .err(errors::make(4,w.at));}
        if(w.mode==3 && (w.ordinal>16 || w.count>16-w.ordinal)){return .err(errors::make(4,w.at));}
        w.start=p.registers;w.phase=2;return .ok(false);}
    if(w.phase==2){if(w.row==w.count){w.phase=5;return .ok(false);}
        if(w.mode==3){slots[w.first+w.row]=input[w.ordinal+w.row];w.row+=1;return .ok(false);}
        if(w.mode==1){w.value=ir::record_read(p,w.source,w.ordinal+w.row,w.at)?;w.phase=3;return .ok(false);}
        let usize loaded=if(w.source==16){ir::emit(p,17,input[w.ordinal+w.row],0,w.at)?}
            else{ir::record_read(p,w.source,w.ordinal+w.row,w.at)?};w.row+=1;return .ok(false);}
    if(w.phase==3){let u8 tag=p.types[w.value];w.slot=ir::slot(p,tag,w.at)?;
        slots[w.first+w.row]=w.slot;w.phase=4;return .ok(false);}
    if(w.phase==4){let usize stored=ir::raw(p,18,w.slot,w.value,0,w.at)?;w.row+=1;w.phase=2;return .ok(false);}
    if(w.phase==5){if(w.mode==1 || w.mode==3 || w.mode==6){w.value=if(w.mode==6){w.start}else{w.count};w.done=true;return .ok(true);}
        if(w.consume && w.source!=16){let usize dropped=ir::record_drop(p,w.source,w.at)?;}w.phase=6;return .ok(false);}
    if(w.phase==6){w.destination=ir::record_in(p,w.function,w.record,w.mutable,w.offset)?;w.phase=7;return .ok(false);}
    if(w.phase==7){let usize initialized=ir::record_init(p,w.destination,w.start,w.offset)?;w.value=w.destination;w.done=true;return .ok(true);}
    if(w.phase==20){if(w.mode==5){let usize source=w.source;
            if(source>=16 || source>=p.arrays.count || p.arrays.elements[source]!=w.element || p.arrays.lengths[source]!=w.length ||
                p.array_functions[source] as usize!=w.function){return .err(errors::make(3,w.at));}
            w.destination=ir::array_in(p,w.function,w.element,w.length,w.mutable,w.offset)?;
        }else{w.destination=ir::record_in(p,w.function,w.record,w.mutable,w.offset)?;}w.phase=21;return .ok(false);}
    if(w.phase==21){let usize copied=if(w.mode==5){ir::array_copy(p,w.destination,w.source,w.offset)?}
            else{ir::record_copy(p,w.destination,w.source,w.offset)?};w.value=w.destination;w.done=true;return .ok(true);}
    return .err(errors::make(5,w.at));
}
// Clone adapters have no metadata request or expression child. No heap scratch.
pub fn Result<usize,errors::Error> clone(ref mut ir::Program p,ref mut State w){
    let usize[1] input=[0];var usize[1] slots=[0];var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,w.at)?;let bool done=advance(p,ref input,ref mut slots,w,ref mut meter)?;}
    return prepared(w);
}
