module runtime_cleanup_work;
import slice_result_runtime as runtime;
import slice_authority as authority;
import array_slices as slices;
import array_owners as owners;
import array_vm as arrays;
import metadata_budget as budget;
import errors as errors;

// Small cursor; the owning Core lends its existing unpublished Runtime bank.
// No payload access, allocation, Fuel debit, callback or live mutation occurs.
pub struct State { usize capacity; usize index; u8 phase; bool active; bool done; }
pub fn State empty(){return State{.capacity=0,.index=0,.phase=0,.active=false,.done=false};}
pub fn Result<usize,errors::Error> begin(ref mut State w,usize capacity){
    if(w.active){return .err(errors::make(5,0));}
    w.capacity=capacity;w.index=0;w.phase=0;w.active=true;w.done=false;return .ok(0);
}
fn Result<usize,errors::Error> count(Result<usize,owners::Error> r){
    return switch(r){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};
}
fn Result<usize,errors::Error> stage(ref mut State w,ref mut runtime::Runtime planned,ref runtime::State live){
    if(w.phase==0){
        let ref runtime::Runtime original=ref live.runtime;
        let ref slices::Pool pool=ref original.pool;let ref owners::Table table=ref original.owners;
        planned.pool=*pool;planned.owners=*table;w.phase=1;return .ok(0);
    }
    if(w.phase==1){
        let usize checked=count(slices::inspect_cleanup_slot(ref planned.pool,ref planned.owners,w.capacity,w.index))?;
        w.index+=1;
        if(w.index==16){w.phase=2;}
        return .ok(0);
    }
    if(w.phase==2){
        if(w.index==0){w.index=0;w.phase=3;return .ok(0);}
        let usize at=w.index-1;
        let ref slices::Pool original_pool=ref planned.pool;let slices::Slot selected=original_pool.slots[at];
        if(selected.live){
            var slices::Pool pool=*original_pool;let ref owners::Table original_table=ref planned.owners;
            var owners::Table table=*original_table;
            let usize closed=count(slices::close_cleanup_slot(ref mut pool,slices::Ticket{.slot=at,.generation=selected.generation},ref mut table,w.capacity))?;
            planned.pool=pool;planned.owners=table;
        }w.index=at;return .ok(0);
    }
    if(w.phase==3){
        // Cleanup intentionally ignores corrupted authority receipts, just like
        // raw finish. Only the authenticated pool/owner sessions are drained.
        authority::reset_cleanup_entry(ref mut planned.authority,w.index);w.index+=1;
        if(w.index==31){planned.authority.depth=0;planned.authority.frame=0;w.phase=4;}
        return .ok(0);
    }
    if(w.phase==4){
        let usize released=count(owners::clear(ref mut planned.owners,w.capacity))?;
        w.active=false;w.done=true;w.phase=5;return .ok(0);
    }return .err(errors::make(5,0));
}
pub fn Result<bool,errors::Error> advance(ref mut State w,ref mut runtime::Runtime planned,
    ref runtime::State live,ref mut budget::State allowance){
    if(!w.active || w.done || w.phase>4 || (w.phase==1 && w.index>=16) || (w.phase==2 && w.index>16) ||
        (w.phase==3 && w.index>=31)){return .err(errors::make(5,0));}
    if(allowance.last!=0){return .ok(false);}
    if(!budget::admit(allowance,4096,0)?){return .ok(false);}
    switch(stage(w,planned,live)){case .ok(_):{}case .err(e):{w.active=false;return .err(e);}};
    return .ok(w.done);
}
// The parent admits a separate fresh publication stage before this infallible
// private operation. The original Runtime must remain pinned and unchanged.
pub fn void publish(ref State w,ref runtime::Runtime planned,ref mut runtime::State live){
    assert(w.done && !w.active);
    let ref authority::State a=ref planned.authority;let ref slices::Pool p=ref planned.pool;let ref owners::Table o=ref planned.owners;
    live.runtime.authority=*a;live.runtime.pool=*p;live.runtime.owners=*o;
}
