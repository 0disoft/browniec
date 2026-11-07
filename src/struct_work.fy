module struct_work;

import array_fill_cursor as cursor;
import array_owners as owners;
import struct_layout as layouts;
import struct_nested_storage as storage;

fn owners::Error storage_error(storage::Error error){
    return switch(error){
        case .Layout:{.Metadata}case .Bounds:{.Bounds}case .Fields:{.Length}
        case .State:{.State}case .Alignment:{.Alignment}case .Quota:{.Quota}
        case .Overflow:{.Overflow}case .Value:{.Value}case .Type:{.Type}
    };
}

// Exact admission byte work: zero the selected scratch, then gather/encode
// fields or snapshot scalar bytes plus the separate canonical bool read.
// Metadata only; a complete <=128-byte record costs at most 1280 units.
pub fn Result<usize,owners::Error> measure(ref layouts::Catalog catalog,usize nominal,bool fields){
    let storage::Staging staging=switch(storage::staging(catalog,nominal)){
        case .ok(s):{s}case .err(e):{return .err(storage_error(e));}
    };
    return .ok(staging.size+staging.scalar_bytes+if(fields){8*staging.leaves}else{staging.bools});
}

// The parent admits the WHOLE measure into its remaining shared 4096-byte
// batch before calling. It pins catalog/values/table/backing, prechecks Fuel,
// and debits Fuel only after admission succeeds. Pending admission is uncharged.
// This stages all canonical bytes without touching a destination or publishing
// an owner. Copy operations require empty fields, even for exact identity.
pub fn Result<cursor::State,owners::Error> begin(ref layouts::Catalog catalog,
    ref owners::Table table,u8 op,usize nominal,owners::Token target,owners::Token source,
    usize target_ordinal,usize source_ordinal,ref i64[] fields,ref u8[] data){
    var cursor::State work=owners::prepare_record(catalog,table,op,nominal,target,source,
        target_ordinal,source_ordinal,data.len)?;
    let bool values=op==41 || op==48 || op==49;
    if(!values && fields.len!=0){return .err(.Length);}
    let usize admission=measure(catalog,nominal,values)?;
    if(admission>1280){return .err(.Quota);}
    work.total=admission;work.last=admission;
    let owners::RecordWork window=owners::validate_record_work(catalog,table,ref work,data.len)?;
    let usize staged=if(values){
        switch(storage::encode_into(catalog,nominal,fields,ref mut work.record_encoded[..window.size])){
            case .ok(n):{n}case .err(e):{return .err(storage_error(e));}
        }
    }else{
        switch(storage::snapshot_into(catalog,nominal,window.source,data,ref table.arena,
            ref mut work.record_encoded[..window.size])){
            case .ok(n):{n}case .err(e):{return .err(storage_error(e));}
        }
    };
    if(staged!=window.size){return .err(.Metadata);}
    return .ok(work);
}

// Other guest opcodes remain frozen until completion. Only the parent resets
// last per batch or sets pc/frame/destination/offset. Every call reauthenticates
// metadata without rescanning payload, gathering values or reencoding scratch.
// written counts final destination bytes; total/last also include admission.
pub fn Result<Option<owners::Token>,owners::Error> advance(ref mut cursor::State work,
    ref layouts::Catalog catalog,ref mut owners::Table table,ref mut u8[] data,usize allowance){
    if(allowance==0 || allowance>cursor::chunk_limit()){return .err(.State);}
    if(work.last>cursor::chunk_limit()){return .err(.State);}
    if(allowance>cursor::chunk_limit()-work.last){return .err(.State);}
    let owners::RecordWork window=owners::validate_record_work(catalog,table,work,data.len)?;
    if(work.written>=window.bytes){return .err(.State);}
    let usize left=window.bytes-work.written;
    let usize count=if(left<allowance){left}else{allowance};
    let usize maximum=18446744073709551615;
    if(count>maximum-work.total || count>maximum-work.last){return .err(.Overflow);}
    let usize start=if(work.op==41 || work.op==42){work.mark}else{window.target};
    let usize stop=start+work.written+count;
    var usize at=start+work.written;
    while(at<stop){
        if(at<window.target){data[at]=0;}
        else{data[at]=work.record_encoded[at-window.target];}
        at+=1;
    }
    work.written+=count;work.total+=count;work.last+=count;
    if(work.written<window.bytes){return .ok(.none);}
    let owners::Token token=owners::publish_record_work(catalog,table,work,data.len)?;
    work.active=false;
    return .ok(.some(token));
}
