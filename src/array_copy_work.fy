module array_copy_work;

import array_fill_cursor as cursor;
import array_layout as layouts;
import array_owners as owners;

// Metadata admission never reads payload or publishes an owner/arena prefix.
// The parent admits the entire bool scan into its shared batch before calling,
// carries total/last into this recipe, and debits the instruction price only
// after success. No non-bool payload is accessed here, including identity.
pub fn Result<cursor::State,owners::Error> begin(ref owners::Table table,u8 op,
    ref layouts::Array layout,owners::Token destination,owners::Token source,ref u8[] data){
    var cursor::State work=owners::prepare_copy(table,op,layout,destination,source,data.len)?;
    if(work.element==2){
        let usize size=work.source_end-work.source_base;
        if(size>cursor::chunk_limit()){return .err(.State);}
        var usize at=work.source_base;
        while(at<work.source_end){
            if(data[at]>1){return .err(.Value);}
            at+=1;
        }
        work.total=size;work.last=size;
    }
    // Exact identity has still passed writable-target and full bool validation.
    if(op==38 && work.slot==work.source_slot && work.generation==work.source_generation){
        work.active=false;
    }
    return .ok(work);
}

// The table/backing/source stay pinned and all other guest opcodes are frozen.
// COPY cancellation abandons unpublished spare bytes; ASSIGN changes live bytes
// incrementally. The parent resets last once per batch, never on each resume.
// A transfer byte costs one unit (read+write); padding costs one zero write.
pub fn Result<Option<owners::Token>,owners::Error> advance(ref mut cursor::State work,
    ref mut owners::Table table,ref mut u8[] data,usize allowance){
    if(allowance==0 || allowance>cursor::chunk_limit()){return .err(.State);}
    if(work.last>cursor::chunk_limit()){return .err(.State);}
    if(allowance>cursor::chunk_limit()-work.last){return .err(.State);}
    let usize size=owners::validate_copy(table,work,data.len)?;
    if(work.written>=size){return .err(.State);}
    let usize left=size-work.written;
    let usize count=if(left<allowance){left}else{allowance};
    let usize maximum=18446744073709551615;
    if(count>maximum-work.total || count>maximum-work.last){return .err(.Overflow);}
    let usize start=if(work.op==34){work.mark}else{work.base};
    // Metadata proves start+written+count <= end and every source offset is
    // within source_end. No bool rescan or fallible operation in this loop.
    let usize stop=start+work.written+count;
    var usize at=start+work.written;
    while(at<stop){
        if(at<work.base){data[at]=0;}
        else{data[at]=data[work.source_base+(at-work.base)];}
        at+=1;
    }
    work.written+=count;work.total+=count;work.last+=count;
    if(work.written<size){return .ok(.none);}
    let owners::Token token=owners::publish_copy(table,work,data.len)?;
    work.active=false;
    return .ok(.some(token));
}
