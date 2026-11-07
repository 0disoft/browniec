module array_fill_work;

import array_fill_cursor as cursor;
import array_layout as layouts;
import array_owners as owners;
import scalar_codec as codec;

// Metadata/shape/capacity admission and at most eight codec bytes only. No
// payload is borrowed, read or written and no owner/arena state is published.
pub fn Result<cursor::State,owners::Error> begin(ref owners::Table table,u8 op,
    ref layouts::Array layout,owners::Token target,i64 value,usize capacity){
    var cursor::State work=owners::prepare_fill(table,op,layout,target,capacity)?;
    let usize size=switch(codec::encode(layout.element,value,ref mut work.encoded[..layout.stride])){
        case .ok(n):{n}
        case .err(e):{return .err(switch(e){
            case .Type:{.Type}case .Width:{.Metadata}case .Value:{.Value}
        });}
    };
    return .ok(work);
}

// The parent supplies the remaining byte budget of its batch (1..4096), resets
// last once per batch, and carries total/last when installing the next recipe.
// Dropping an unfinished CREATE leaves only unreachable spare bytes; neither
// the arena prefix nor an owner has been published. FILL changes its live bytes
// incrementally and must remain inaccessible to other guest instructions.
pub fn Result<Option<owners::Token>,owners::Error> advance(ref mut cursor::State work,
    ref mut owners::Table table,ref mut u8[] data,usize allowance){
    if(allowance==0 || allowance>cursor::chunk_limit()){return .err(.State);}
    // Defend the shared caller batch even if its remaining allowance is wrong.
    // Check last first so the subtraction cannot underflow; never reset it here.
    if(work.last>cursor::chunk_limit()){return .err(.State);}
    if(allowance>cursor::chunk_limit()-work.last){return .err(.State);}
    let usize size=owners::validate_fill(table,work,data.len)?;
    if(work.written>=size){return .err(.State);}
    let usize left=size-work.written;
    let usize count=if(left<allowance){left}else{allowance};
    // Counter overflow is rejected before changing even a padding byte.
    let usize maximum=18446744073709551615;
    if(count>maximum-work.total || count>maximum-work.last){return .err(.Overflow);}
    let usize start=if(work.op==33){work.mark}else{work.base};
    let usize stop=start+work.written+count;
    var usize at=start+work.written;
    while(at<stop){
        if(at<work.base){data[at]=0;}
        else{data[at]=work.encoded[(at-work.base)%work.stride];}
        at+=1;
    }
    work.written+=count;work.total+=count;work.last+=count;
    if(work.written<size){return .ok(.none);}
    // The authenticated table stayed exclusively borrowed throughout this chunk.
    // Completion rechecks metadata and only then publishes a fully written CREATE.
    let owners::Token token=owners::publish_fill(table,work,data.len)?;
    work.active=false;
    return .ok(.some(token));
}
