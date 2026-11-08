module call_copy_prepared_work;

import call_copy_plan_work as plans;
import call_copy_cursor as cursor;
import array_owners as owners;
import metadata_budget as budget;

// Private owning path. The caller pins every source and authenticates the plan
// before each invocation; ready is a one-invocation proof, not public authority.
struct Preview { usize bytes; usize metadata; }
fn owners::Error failure(ref plans::State w){
    let ref plans::Plan p=ref w.plan;
    return if(p.failed){plans::failure(p)}else{.State};
}
fn owners::CallCopyRange range(ref plans::State w,usize i){
    let ref plans::Plan p=ref w.plan;return p.ranges[i];
}
fn usize position(ref plans::State w,usize i,usize at){
    let ref u8[] values=ref w.positions[..];let usize index=i*128+at;
    return values[index] as usize;
}
fn u8 mask(ref plans::State w,usize i,usize at){
    let ref u8[] values=ref w.masks[..];let usize index=i*128+at;
    return values[index];
}
fn Result<usize,owners::Error> admit(ref mut budget::State b,usize count){
    if(count==0){return .ok(0);}
    let usize max=18446744073709551615;
    if(b.last>4096 || b.last>b.total || b.stages>b.total){return .err(.State);}
    if(count>max-b.total || b.stages==max){return .err(.Overflow);}
    return switch(budget::admit(b,count,0)){
        case .ok(v):{if(v){.ok(count)}else{.err(.State)}}case .err(_):{.err(.State)}
    };
}
// Numerically preview at most eight arguments. Never read positions or payload.
// Stop at the same deferred error boundary the validation loop will encounter.
fn Preview validation_preview(ref plans::State w,ref cursor::State copy,
    ref owners::CallArgument[] args,usize room){
    var Preview out=Preview{.bytes=0,.metadata=0};var usize left=room;
    let ref plans::Plan p=ref w.plan;let usize checked=p.checked;let usize reserved=p.copies.count;
    var usize i=copy.index;
    while(i<copy.count && i<checked && (!copy.reserve_first || i<reserved)){
        let owners::CallArgument arg=args[i];let owners::CallCopyRange r=p.ranges[i];
        var usize count=0;var usize unit=1;
        if(arg.element==2){let usize at=if(i==copy.index){copy.at}else{0};count=r.size-at;}
        else if(arg.element==0){let usize at=if(i==copy.index){w.bool_index}else{0};count=w.bools[i]-at;unit=2;}
        let usize take=if(count<left/unit){count}else{left/unit};
        out.bytes+=take;if(unit==2){out.metadata+=take;}left-=take*unit;
        if(take<count){return out;}
        if(i>=reserved){return out;}i+=1;
    }return out;
}
// Padding and array bytes cost one; record bytes also visit one cached mask.
fn Preview write_preview(ref plans::State w,ref cursor::State copy,
    ref owners::CallArgument[] args,usize room){
    var Preview out=Preview{.bytes=0,.metadata=0};var usize left=room;var usize i=copy.index;
    let ref plans::Plan p=ref w.plan;
    while(i<copy.count){let owners::CallCopyRange r=p.ranges[i];
        let usize at=if(i==copy.index){copy.at}else{0};let usize absolute=r.mark+at;
        let usize padding=if(absolute<r.target){r.target-absolute}else{0};
        let usize pad=if(padding<left){padding}else{left};out.bytes+=pad;left-=pad;
        if(pad<padding){return out;}
        let usize start=absolute+pad;let usize rest=r.end-start;let bool record=args[i].element==0;
        let usize unit=if(record){2}else{1};let usize take=if(rest<left/unit){rest}else{left/unit};
        out.bytes+=take;if(record){out.metadata+=take;}left-=take*unit;
        if(take<rest){return out;}i+=1;
    }return out;
}
// A short room must not purchase an entry stage that cannot reach any work.
// Zero also means the next action is a deferred error or a phase transition.
fn usize first_cost(ref plans::State w,ref cursor::State copy,ref owners::CallArgument[] args){
    let ref plans::Plan p=ref w.plan;var usize i=copy.index;
    if(copy.phase==0){
        while(i<copy.count){if(i>=p.checked || (copy.reserve_first && i>=p.copies.count)){return 0;}
            let u8 element=args[i].element;let owners::CallCopyRange r=p.ranges[i];
            let usize at=if(i==copy.index){copy.at}else{0};
            let usize ordinal=if(i==copy.index){w.bool_index}else{0};
            if(element==2 && at<r.size){return 1;}
            if(element==0 && ordinal<w.bools[i]){return 2;}
            if(i>=p.copies.count){return 0;}i+=1;
        }return 0;
    }
    while(i<copy.count){let owners::CallCopyRange r=p.ranges[i];
        let usize at=if(i==copy.index){copy.at}else{0};let usize pos=r.mark+at;
        if(pos<r.end){return if(pos<r.target || args[i].element!=0){1}else{2};}i+=1;
    }return 0;
}
fn Result<usize,owners::Error> counters(ref cursor::State copy,usize bytes){
    let usize max=18446744073709551615;
    if(bytes>max-copy.total || bytes>max-copy.last){return .err(.Overflow);}
    return .ok(bytes);
}

// One invocation consumes its own 1024-unit entry plus each actual position or
// mask visit, in the same shared room as payload bytes. No credit crosses yields.
pub fn Result<Option<owners::Copies>,owners::Error> advance(ref mut plans::State w,
    ref mut cursor::State copy,ref mut owners::Table table,ref owners::CallArgument[] args,
    ref mut u8[] data,ref mut usize remaining,usize room,ref mut budget::State allowance){
    if(!w.ready || w.active || !w.done || w.count!=args.len || copy.count!=args.len ||
        copy.count>8 || copy.phase>1 || copy.index>copy.count || copy.last>copy.total ||
        copy.written>copy.total || room>4096 || allowance.last>4096 || room>4096-allowance.last){return .err(.State);}
    if(copy.count!=0 && !copy.active){return .err(.State);}
    if(room<1024){return .ok(.none);}
    let usize available=room-1024;
    let usize needed=first_cost(w,copy,args);if(needed>available){return .ok(.none);}
    let usize fixed=admit(allowance,1024)?;var usize used=0;
    if(copy.count==0){
        if(!copy.charged){*remaining=copy.remaining;copy.charged=true;}
        let ref plans::Plan p=ref w.plan;return .ok(.some(p.copies));
    }
    if(copy.phase==0){
        let Preview preview=validation_preview(w,copy,args,available);
        let usize checked=counters(copy,preview.bytes)?;
        let usize admitted=admit(allowance,preview.metadata)?;
        var usize read=0;
        while(copy.index<copy.count){
            let usize i=copy.index;let ref plans::Plan p=ref w.plan;
            let usize checked_count=p.checked;let usize reserved=p.copies.count;
            if(i>=checked_count || (copy.reserve_first && i>=reserved)){return .err(failure(w));}
            let owners::CallCopyRange r=p.ranges[i];let u8 element=args[i].element;
            if(element==2){
                while(copy.at<r.size){if(read==preview.bytes){return .ok(.none);}
                    let usize at=copy.at;let u8 value=data[r.source+at];copy.at+=1;
                    copy.total+=1;copy.last+=1;w.read_left-=1;read+=1;used+=1;
                    if(value>1){copy.active=false;return .err(.Value);}
                }
            }else if(element==0){
                let usize count=w.bools[i];
                while(w.bool_index<count){if(read==preview.bytes){return .ok(.none);}
                    let usize ordinal=w.bool_index;let usize at=position(w,i,ordinal);
                    let u8 value=data[r.source+at];w.bool_index+=1;copy.at=at+1;
                    copy.total+=1;copy.last+=1;w.read_left-=1;read+=1;used+=2;
                    if(value>1){copy.active=false;return .err(.Value);}
                }
                copy.at=r.size;
            }
            if(i>=reserved){return .err(failure(w));}
            copy.index+=1;copy.at=0;w.bool_index=0;
        }
        copy.phase=1;copy.index=0;copy.at=0;
    }
    if(!copy.charged){*remaining=copy.remaining;copy.charged=true;}
    let usize write_room=available-used;
    let Preview preview=write_preview(w,copy,args,write_room);
    let usize checked=counters(copy,preview.bytes)?;
    let usize admitted=admit(allowance,preview.metadata)?;
    var usize written=0;
    while(copy.index<copy.count){
        let usize i=copy.index;let owners::CallCopyRange r=range(w,i);
        let u8 element=args[i].element;let usize length=r.end-r.mark;
        while(copy.at<length && written<preview.bytes){
            let usize at=r.mark+copy.at;
            if(at<r.target){data[at]=0;}
            else{let usize offset=at-r.target;
                if(element==0 && mask(w,i,offset)==0){data[at]=0;}
                else{data[at]=data[r.source+offset];}
            }
            copy.at+=1;copy.written+=1;copy.total+=1;copy.last+=1;written+=1;
        }
        if(copy.at<length){return .ok(.none);}copy.index+=1;copy.at=0;
    }
    let ref plans::Plan p=ref w.plan;let ref owners::Table planned=ref p.planned;
    table.slots=planned.slots;table.order=planned.order;table.depth=planned.depth;table.arena=planned.arena;
    copy.active=false;return .ok(.some(p.copies));
}
