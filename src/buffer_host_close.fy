module buffer_host_close;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_growth as growth;
import buffer_close as close;
import buffer_utf8_pool as pools;
import buffer_utf8_meter as meter;

// Consume one caller-bound native root. Err returns ownership to the host.
// A failed post-destruction finish returns an empty root and retains Plan.
// Pool/table/ledger/Plan associations remain private trusted host state.
pub fn Result<usize,bytes::Buffer> shutdown(bytes::Buffer root,owners::Token source,
    ref mut pools::Pool pool,ref mut owners::Table table,ref mut growth::Ledger ledger,
    ref mut close::Plan plan){
    if(plan.active){
        if(pool.phase!=2 || pool.admitted){return .err(root);}
    }else{
        switch(pools::shutdown(pool,table,ledger)){case .ok(_):{}case .err(_):{return .err(root);}};
    }
    return close_stopped(root,source,pool,table,ledger,plan);
}
// An explicit host visits its roots after Pool shutdown has started. A failed
// lease on another root does not prevent closing an independently writable root.
// Share exactly one Plan: a failed final refund blocks all other root mutations.
pub fn Result<usize,bytes::Buffer> close_stopped(bytes::Buffer root,owners::Token source,
    ref pools::Pool pool,ref mut owners::Table table,ref mut growth::Ledger ledger,
    ref mut close::Plan plan){
    if((pool.phase!=1 && pool.phase!=2) || (pool.phase==2 && pool.admitted)){return .err(root);}
    if(plan.active){
        // Accounting-only retry must never destroy a replacement or another root.
        if(source.slot!=plan.source.slot || source.generation!=plan.source.generation ||
            bytes::len(ref root)!=0 || bytes::capacity(ref root)!=0){return .err(root);}
        switch(close::finish(table,ledger,plan)){case .ok(n):{return .ok(n);}case .err(_):{return .err(root);}};
    }
    let usize roots=switch(owners::accounted(table)){case .ok(n):{n}case .err(_):{return .err(root);}};
    let usize metadata=if(pool.admitted){pools::metadata_charge()}else{0};
    if(roots>18446744073709551615-metadata || ledger.used<roots+metadata){return .err(root);}
    switch(close::begin(table,source,ref root,ledger,plan)){case .ok(_):{}case .err(_):{return .err(root);}};
    // The owning resource's real scope cleanup runs before releasing its charge.
    {let bytes::Buffer disposed=root;}
    return switch(close::finish(table,ledger,plan)){case .ok(n):{.ok(n)}case .err(_):{.err(bytes::empty())}};
}
// Finalize only after every tracked owner and the shared close Plan are retired.
// Unrelated background usage remains in the returned Instance counter.
pub fn Result<usize,meter::ControlError> finish_all(ref mut pools::Pool pool,
    ref mut owners::Table table,ref mut growth::Ledger ledger,ref close::Plan plan){
    if(plan.active || (pool.phase!=1 && pool.phase!=2) || !growth::settled(ledger)){return .err(.State);}
    let usize remaining=switch(owners::accounted(table)){case .ok(n):{n}case .err(_):{return .err(.State);}};
    if(remaining!=0){return .err(.State);}
    let usize released=pools::shutdown(pool,table,ledger)?;
    return .ok(ledger.used);
}
