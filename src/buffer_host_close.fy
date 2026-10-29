module buffer_host_close;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_growth as growth;
import buffer_close as close;
import buffer_utf8_pool as pools;

// Consume one caller-bound native root. Err returns ownership to the host.
// A failed post-destruction finish returns an empty root and retains Plan.
// Pool/table/ledger/Plan associations remain private trusted host state.
pub fn Result<usize,bytes::Buffer> shutdown(bytes::Buffer root,owners::Token source,
    ref mut pools::Pool pool,ref mut owners::Table table,ref mut growth::Ledger ledger,
    ref mut close::Plan plan){
    if(plan.active){
        // Accounting-only retry must never destroy a replacement or another root.
        if(pool.phase!=2 || pool.admitted || source.slot!=plan.source.slot || source.generation!=plan.source.generation ||
            bytes::len(ref root)!=0 || bytes::capacity(ref root)!=0){return .err(root);}
        switch(close::finish(table,ledger,plan)){case .ok(n):{return .ok(n);}case .err(_):{return .err(root);}};
    }
    switch(pools::shutdown(pool,table,ledger)){case .ok(_):{}case .err(_):{return .err(root);}};
    switch(close::begin(table,source,ref root,ledger,plan)){case .ok(_):{}case .err(_):{return .err(root);}};
    // The owning resource's real scope cleanup runs before releasing its charge.
    {let bytes::Buffer disposed=root;}
    return switch(close::finish(table,ledger,plan)){case .ok(n):{.ok(n)}case .err(_):{.err(bytes::empty())}};
}
