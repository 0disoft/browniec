module array_list_work;

import array_fill_cursor as cursor;
import array_layout as layouts;
import array_owners as owners;
import scalar_codec as codec;

// Metadata only: reuse CREATE/FILL reservation admission without publishing an
// owner or accessing payload. The parent pins operands/registers/cells/scratch
// and the owner/backing storage, freezing all other guest execution until done.
pub fn Result<cursor::State,owners::Error> begin(ref owners::Table table,u8 op,
    ref layouts::Array layout,owners::Token destination,usize capacity){
    if(op!=80 && op!=81){return .err(.State);}
    var cursor::State work=owners::prepare_fill(table,if(op==80){33}else{40},
        layout,destination,capacity)?;
    work.op=op;
    return .ok(work);
}

// operands starts at this instruction's first list operand; registers is its
// scalar register bank. cells/scratch are already initialized and may be larger
// than this list. No allocation, payload snapshot, reevaluation or codec rescan.
// Gather transfers cost eight bytes per i64 cell, encoding costs one stride,
// and final padding/payload copies cost one byte. Only the parent resets last.
pub fn Result<Option<owners::Token>,owners::Error> advance(ref mut cursor::State work,
    ref mut owners::Table table,ref mut u8[] data,ref u8[] operands,ref i64[] registers,
    ref mut i64[] cells,ref mut u8[] scratch,usize allowance){
    if(allowance==0 || allowance>cursor::chunk_limit()){return .err(.State);}
    if(work.last>cursor::chunk_limit()){return .err(.State);}
    if(allowance>cursor::chunk_limit()-work.last){return .err(.State);}
    if(work.op!=80 && work.op!=81){return .err(.State);}
    // Normalize only a local metadata recipe. Never change the saved opcode or
    // borrow the table's private reservation facts as independent authority.
    var cursor::State normalized=*work;
    normalized.op=if(work.op==80){33}else{40};
    normalized.list_gathered=0;normalized.list_encoded=0;
    let usize size=owners::validate_fill(table,ref normalized,data.len)?;
    if(work.written>=size || work.list_gathered>work.length || work.list_encoded>work.length){
        return .err(.State);
    }
    if((work.list_encoded!=0 && work.list_gathered!=work.length) ||
        (work.written!=0 && work.list_encoded!=work.length)){return .err(.State);}
    let usize payload=work.end-work.base;
    if(operands.len<work.length || cells.len<work.length || scratch.len<payload){return .err(.Bounds);}
    // Canonical metadata bounds each product/sum below by 98311 bytes. total
    // may include earlier instructions, but must cover this recipe's work.
    let usize done=work.list_gathered*8+work.list_encoded*work.stride+work.written;
    if(work.total<done){return .err(.State);}

    // Plan the entire call in constant time, including transitions. An atomic
    // cell/encoding that does not fit leaves the remaining allowance unused.
    // Preflight counter headroom before changing cells, scratch or destination.
    var usize left=allowance;
    let usize gather_left=work.length-work.list_gathered;
    let usize gather_count=if(gather_left<left/8){gather_left}else{left/8};
    let usize gathered=work.list_gathered+gather_count;
    left-=gather_count*8;
    let usize encode_left=work.length-work.list_encoded;
    let usize encode_count=if(gathered!=work.length){0}
        else if(encode_left<left/work.stride){encode_left}else{left/work.stride};
    let usize encoded=work.list_encoded+encode_count;
    left-=encode_count*work.stride;
    let usize copy_left=size-work.written;
    let usize count=if(encoded!=work.length){0}else if(copy_left<left){copy_left}else{left};
    left-=count;
    let usize charge=allowance-left;
    let usize maximum=18446744073709551615;
    if(charge>maximum-work.total || charge>maximum-work.last){return .err(.Overflow);}

    while(work.list_gathered<gathered){
        let usize r=operands[work.list_gathered] as usize;
        if(r>=128 || r>=registers.len){return .err(.Bounds);}
        cells[work.list_gathered]=registers[r];
        work.list_gathered+=1;work.total+=8;work.last+=8;
    }
    // No destination byte (even padding) is touched until every operand and
    // scalar has succeeded. A failure may leave partial cells/encoded scratch.
    while(work.list_encoded<encoded){
        let usize at=work.list_encoded*work.stride;
        let usize width=switch(codec::encode(work.element,cells[work.list_encoded],
            scratch[at..at+work.stride])){
            case .ok(n):{n}
            case .err(e):{return .err(switch(e){
                case .Type:{.Type}case .Width:{.Metadata}case .Value:{.Value}
            });}
        };
        work.list_encoded+=1;work.total+=work.stride;work.last+=work.stride;
    }
    if(count==0){return .ok(.none);}
    let usize start=if(work.op==80){work.mark}else{work.base};
    let usize stop=start+work.written+count;
    var usize at=start+work.written;
    while(at<stop){
        if(at<work.base){data[at]=0;}
        else{data[at]=scratch[at-work.base];}
        at+=1;
    }
    work.written+=count;work.total+=count;work.last+=count;
    if(work.written<size){return .ok(.none);}
    normalized.written=work.written;normalized.total=work.total;normalized.last=work.last;
    let owners::Token token=owners::publish_fill(table,ref normalized,data.len)?;
    work.active=false;
    return .ok(.some(token));
}
