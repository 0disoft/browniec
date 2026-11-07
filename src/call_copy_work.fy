module call_copy_work;

import call_copy_cursor as cursor;
import array_owners as owners;
import struct_layout as records;
import struct_nested_storage as storage;

fn owners::Error storage_error(storage::Error error){
    return switch(error){
        case .Layout:{.Metadata}case .Bounds:{.Bounds}case .Fields:{.Length}
        case .State:{.State}case .Alignment:{.Alignment}case .Quota:{.Quota}
        case .Overflow:{.Overflow}case .Value:{.Value}case .Type:{.Type}
    };
}
fn owners::Error deferred_error(ref owners::CallCopyPlan plan){
    return switch(plan.failure){case .some(e):{e}case .none:{.State}};
}
fn Result<usize,owners::Error> record_mask(ref records::Catalog catalog,
    usize record,usize size,ref mut u8[] mask){
    return switch(storage::byte_kinds(catalog,record,mask[..size])){
        case .ok(n):{.ok(n)}case .err(e):{.err(storage_error(e))}
    };
}

// Count only pending bool validation reads, using metadata alone. At most eight
// arrays of 4096 bools or eight records of 128 bytes. Rebuilt masks are tiny local
// metadata, never payload snapshots. These scans remain atomic (future R03).
fn Result<usize,owners::Error> validation_left(ref owners::CallCopyPlan plan,
    ref records::Catalog catalog,ref owners::CallArgument[] arguments,ref cursor::State work){
    var usize result=0;var usize i=work.index;
    var u8[128] mask=[0;128];
    while(i<plan.checked){
        let owners::CallArgument argument=arguments[i];
        let usize size=plan.ranges[i].size;
        var usize at=if(i==work.index){work.at}else{0};
        if(argument.element==2){result+=size-at;}
        else if(argument.element==0){
            let usize checked=record_mask(catalog,argument.record,size,ref mut mask[..])?;
            while(at<size){if(mask[at]==2){result+=1;}at+=1;}
        }
        i+=1;
    }
    return .ok(result);
}

// Metadata only. Arity/table errors are immediate; per-argument source, shape
// and reservation errors are deferred to advance so earlier invalid bools retain
// the atomic mixed copy_call_arguments API's first-error priority. That existing
// API is already transactional; this kernel adds bounded payload work only.
// Pin the exact table/catalog/arguments/backing and immutable original sources
// until completion or cancellation; no other guest instruction may execute.
pub fn Result<cursor::State,owners::Error> begin(ref owners::Table table,
    ref records::Catalog catalog,ref owners::CallArgument[] arguments,usize capacity){
    let owners::CallCopyPlan plan=owners::plan_call_copy(table,catalog,arguments,capacity)?;
    return owners::capture_call_copy(ref plan,arguments);
}

// Private VM array-only boundary; no payload is inspected here. Records have
// no array diagnostic contract, and array descriptors carry no nominal record.
fn Result<usize,owners::Error> arrays_only(ref owners::CallArgument[] arguments){
    if(arguments.len>8){return .err(.Metadata);}
    var usize i=0;while(i<arguments.len){
        if(arguments[i].element==0){return .err(.Type);}
        if(arguments[i].record!=0){return .err(.Metadata);}
        i+=1;
    }
    return .ok(arguments.len);
}
// Match copy_arguments: source/shape, free slot/reservation, then source bools.
// The parent pins this mode along with the existing immutable recipe inputs.
pub fn Result<cursor::State,owners::Error> begin_arrays(ref owners::Table table,
    ref records::Catalog catalog,ref owners::CallArgument[] arguments,usize capacity){
    let usize checked=arrays_only(arguments)?;
    var cursor::State work=begin(table,catalog,arguments,capacity)?;
    work.reserve_first=true;
    return .ok(work);
}

// Each validation read costs one unit; each transfer (read+write) or zero write
// costs one. ALL bools succeed in phase 0 before even allocation padding is
// touched in phase 1. Records copy scalar bytes directly and zero every padding
// byte, without payload rescanning or reencoding after phase 0. Repeated sources
// are legitimate: all reserved destinations follow every ORIGINAL source.
// Only the parent resets last per shared batch; allowance must fit 4096-last.
// Cancelling drops private progress/spare bytes, never published owners/prefix.
// Zero arguments begin inactive; a valid advance returns Some(count=0) without
// payload/counter/table mutation. It is safe to observe that empty result again.
pub fn Result<Option<owners::Copies>,owners::Error> advance(ref mut cursor::State work,
    ref mut owners::Table table,ref records::Catalog catalog,
    ref owners::CallArgument[] arguments,ref mut u8[] data,usize allowance){
    return advance_impl(work,table,catalog,arguments,data,allowance,false);
}
// Finish source validation without touching destination bytes. Phase 1 is the
// parent's price boundary: charge CALL once, then resume advance to copy.
pub fn Result<Option<owners::Copies>,owners::Error> validate(ref mut cursor::State work,
    ref mut owners::Table table,ref records::Catalog catalog,
    ref owners::CallArgument[] arguments,ref mut u8[] data,usize allowance){
    return advance_impl(work,table,catalog,arguments,data,allowance,true);
}
fn Result<Option<owners::Copies>,owners::Error> advance_impl(ref mut cursor::State work,
    ref mut owners::Table table,ref records::Catalog catalog,
    ref owners::CallArgument[] arguments,ref mut u8[] data,usize allowance,bool validation_only){
    if(allowance==0 || allowance>cursor::chunk_limit()){return .err(.State);}
    if(work.last>cursor::chunk_limit()){return .err(.State);}
    if(allowance>cursor::chunk_limit()-work.last){return .err(.State);}
    let owners::CallCopyPlan plan=owners::validate_call_copy(table,catalog,arguments,work,data.len)?;
    if(work.reserve_first){let usize checked=arrays_only(arguments)?;}
    if(work.count==0){return .ok(.some(plan.copies));}
    if(validation_only && work.phase==1){return .ok(.none);}

    let usize reads=if(work.phase==0){validation_left(ref plan,catalog,arguments,work)?}else{0};
    let usize writes=if(plan.copies.count==work.count){work.end-work.mark-work.written}else{0};
    // Both sums are bounded by eight (32768+7)-byte reservations plus 32768
    // validation reads. Preflight EXACT chunk headroom before any counter,
    // progress or destination mutation, including the phase transition.
    let usize pending=reads+if(validation_only){0}else{writes};
    let usize charge=if(pending<allowance){pending}else{allowance};
    let usize maximum=18446744073709551615;
    if(charge>maximum-work.total || charge>maximum-work.last){return .err(.Overflow);}
    var usize spent=0;
    var u8[128] mask=[0;128];

    if(work.phase==0){
        while(work.index<work.count){
            let usize i=work.index;
            // A source/shape error always precedes this argument's target.
            // Array mode checks reservations before bools; mixed mode after.
            if(i>=plan.checked){return .err(deferred_error(ref plan));}
            if(work.reserve_first && i>=plan.copies.count){return .err(deferred_error(ref plan));}
            let owners::CallCopyRange range=plan.ranges[i];
            let owners::CallArgument argument=arguments[i];
            if(argument.element==2){
                while(work.at<range.size){
                    if(spent==charge){return .ok(.none);}
                    let u8 value=data[range.source+work.at];
                    work.at+=1;work.total+=1;work.last+=1;spent+=1;
                    if(value>1){work.active=false;return .err(.Value);}
                }
            }else if(argument.element==0){
                let usize checked=record_mask(catalog,argument.record,range.size,ref mut mask[..])?;
                while(work.at<range.size){
                    if(mask[work.at]==2){
                        if(spent==charge){return .ok(.none);}
                        let u8 value=data[range.source+work.at];
                        work.at+=1;work.total+=1;work.last+=1;spent+=1;
                        if(value>1){work.active=false;return .err(.Value);}
                    }else{work.at+=1;}
                }
            }
            if(i>=plan.copies.count){return .err(deferred_error(ref plan));}
            work.index+=1;work.at=0;
        }
        work.phase=1;work.index=0;work.at=0;
    }
    if(validation_only){return .ok(.none);}

    // The complete plan has authenticated ALL source/target generations,
    // original extents, shapes, reservations and table depth before these writes.
    // Masks revisit metadata only; every scalar byte comes from immutable source.
    while(work.index<work.count && spent<charge){
        let usize i=work.index;
        let owners::CallCopyRange range=plan.ranges[i];
        let owners::CallArgument argument=arguments[i];
        if(argument.element==0){
            let usize checked=record_mask(catalog,argument.record,range.size,ref mut mask[..])?;
        }
        let usize left=range.end-range.mark-work.at;
        let usize budget=charge-spent;
        let usize count=if(left<budget){left}else{budget};
        let usize stop=range.mark+work.at+count;
        var usize at=range.mark+work.at;
        while(at<stop){
            if(at<range.target){data[at]=0;}
            else{
                let usize offset=at-range.target;
                if(argument.element==0 && mask[offset]==0){data[at]=0;}
                else{data[at]=data[range.source+offset];}
            }
            at+=1;
        }
        work.at+=count;work.written+=count;work.total+=count;work.last+=count;spent+=count;
        if(work.at==range.end-range.mark){work.index+=1;work.at=0;}
    }
    if(work.index<work.count){return .ok(.none);}
    // One complete-batch publication AFTER its final byte. No per-argument owner
    // or arena prefix becomes visible; the transient plan owns no payload.
    table.slots=plan.planned.slots;table.order=plan.planned.order;
    table.depth=plan.planned.depth;table.arena=plan.planned.arena;
    work.active=false;
    return .ok(.some(plan.copies));
}
