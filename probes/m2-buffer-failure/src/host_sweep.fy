module host_sweep;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_close as close;
import buffer_host_sweep as sweeps;
import buffer_utf8_pool as pools;
import buffer_utf8_meter as meter;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn bytes::Buffer rejected(Result<usize,bytes::Buffer> r){return switch(r){case .ok(_):{assert(false);bytes::empty()}case .err(b):{b}};}
fn bytes::Buffer closed(Result<usize,bytes::Buffer> r,usize expected){return switch(r){case .ok(n):{assert(n==expected);bytes::empty()}case .err(b):{assert(false);b}};}
fn void failed(Result<usize,meter::ControlError> r){assert(switch(r){case .ok(_):{false}case .err(e):{switch(e){
    case .State:{true}case .Cancelled:{false}case .Fuel:{false}case .Token:{false}case .Utf8:{false}}}});}
fn void next_failed(Result<Option<owners::Token>,meter::ControlError> r){assert(switch(r){case .ok(_):{false}case .err(_):{true}});}
fn owners::Token next(ref mut sweeps::Sweep sweep,ref owners::Table table){return switch(sweeps::next(sweep,table)){
    case .ok(value):{switch(value){case .some(t):{t}case .none:{assert(false);owners::Token{.slot=16,.generation=0}}}}
    case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};}
fn void exhausted(ref mut sweeps::Sweep sweep,ref owners::Table table){assert(switch(sweeps::next(sweep,table)){
    case .ok(v):{switch(v){case .none:{true}case .some(_):{false}}}case .err(_):{false}});}
fn void token(owners::Token actual,owners::Token expected){assert(actual.slot==expected.slot && actual.generation==expected.generation);}
fn void same(ref growth::Ledger a,ref growth::Ledger b){assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak &&
    a.engine_peak==b.engine_peak && a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
    a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);}
fn owners::Token registered(ref mut owners::Table table,ref bytes::Buffer b){return switch(owners::create(table,b)){
    case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};}
fn void lease(ref mut pools::Pool pool,ref mut owners::Table table,owners::Token t,ref bytes::Buffer b,ref growth::Ledger ledger){
    var usize fuel=256;assert(switch(pools::begin(false,pool,table,t,b,ledger,ref mut fuel)){case .ok(_):{true}case .err(_):{false}});assert(fuel==0);
}
pub fn void run(u8 mode){
    var growth::Ledger ledger=growth::empty();var bytes::Buffer a=bytes::empty();var bytes::Buffer b=bytes::empty();
    a=switch(storage::prepare_growth(ref a,256,limits(),ref mut ledger)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    switch(growth::commit(256,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(ref mut a,b"keep")){case .ok(_):{}case .err(_):{assert(false);}};
    switch(growth::admit_empty(limits(),ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    b=switch(storage::prepare_growth(ref b,64,limits(),ref mut ledger)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    switch(growth::commit(64,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(ref mut b,b"other")){case .ok(_):{}case .err(_):{assert(false);}};
    ledger.engine_used+=32;ledger.engine_peak+=32;var owners::Table table=owners::empty();
    let owners::Token first=registered(ref mut table,ref a);var owners::Token second=registered(ref mut table,ref b);
    if(mode==0){let owners::Owner saved=table.slots[second.slot];table.slots[15]=saved;
        table.slots[second.slot]=owners::Owner{.generation=1,.live=false,.length=0,.capacity=0,.reading=false};second.slot=15;}
    var pools::Pool pool=pools::empty();switch(pools::admit(ref mut pool,limits(),ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    var sweeps::Sweep sweep=sweeps::empty();let growth::Ledger initial=ledger;
    b=rejected(sweeps::close_current(b,ref mut sweep,ref pool,ref mut table,ref mut ledger));same(ref ledger,ref initial);
    assert(bytes::equal(bytes::view(ref b),b"other"));next_failed(sweeps::next(ref mut sweep,ref table));
    failed(sweeps::finish(ref mut sweep,ref mut pool,ref mut table,ref mut ledger));
    if(mode==2){lease(ref mut pool,ref mut table,second,ref b,ref ledger);lease(ref mut pool,ref mut table,first,ref a,ref ledger);
        pool.s0.session.source.generation+=1;failed(sweeps::begin(ref mut sweep,ref mut pool,ref mut table,ref mut ledger));
        assert(sweep.phase==1 && pool.phase==1 && pool.admitted);
    }else{assert(switch(sweeps::begin(ref mut sweep,ref mut pool,ref mut table,ref mut ledger)){case .ok(n):{n==0}case .err(_):{false}});}
    failed(sweeps::begin(ref mut sweep,ref mut pool,ref mut table,ref mut ledger));
    token(next(ref mut sweep,ref table),second);token(next(ref mut sweep,ref table),second);
    failed(sweeps::retry(ref mut sweep,ref table));failed(sweeps::finish(ref mut sweep,ref mut pool,ref mut table,ref mut ledger));
    if(mode==0){
        sweep.visited=65536;next_failed(sweeps::next(ref mut sweep,ref table));sweep.visited=0;
        table.slots[second.slot].generation+=1;next_failed(sweeps::next(ref mut sweep,ref table));
        assert(sweep.offered && sweep.current.generation==second.generation);table.slots[second.slot].generation=second.generation;
        b=closed(sweeps::close_current(b,ref mut sweep,ref pool,ref mut table,ref mut ledger),320);
        token(next(ref mut sweep,ref table),first);a=closed(sweeps::close_current(a,ref mut sweep,ref pool,ref mut table,ref mut ledger),0);
    }else if(mode==1 || mode==2){
        if(mode==1){table.slots[second.slot].length=4;}
        let growth::Ledger before=ledger;
        b=rejected(sweeps::close_current(b,ref mut sweep,ref pool,ref mut table,ref mut ledger));same(ref ledger,ref before);
        assert(!sweep.offered && !sweep.plan.active && bytes::equal(bytes::view(ref b),b"other"));
        // An unvisited root must be attempted before explicitly restarting a pass.
        failed(sweeps::retry(ref mut sweep,ref table));token(next(ref mut sweep,ref table),first);
        a=closed(sweeps::close_current(a,ref mut sweep,ref pool,ref mut table,ref mut ledger),if(mode==1){128}else{2240});
        exhausted(ref mut sweep,ref table);failed(sweeps::finish(ref mut sweep,ref mut pool,ref mut table,ref mut ledger));
        if(mode==1){table.slots[second.slot].length=5;}else{
            assert(pool.admitted && table.slots[second.slot].reading);pool.s0.session.source.generation=second.generation;
            switch(pools::shutdown(ref mut pool,ref mut table,ref mut ledger)){case .ok(n):{assert(n==1);}case .err(_):{assert(false);}};
        }
        switch(sweeps::retry(ref mut sweep,ref table)){case .ok(_):{}case .err(_):{assert(false);}};
        token(next(ref mut sweep,ref table),second);b=closed(sweeps::close_current(b,ref mut sweep,ref pool,ref mut table,ref mut ledger),0);
    }else{
        // A constructed failed-finish state retains its offered token even though
        // the owner is already retired, and freezes enumeration of other roots.
        switch(close::begin(ref mut table,second,ref b,ref ledger,ref mut sweep.plan)){case .ok(_):{}case .err(_):{assert(false);}};
        {let bytes::Buffer disposed=b;}b=bytes::empty();let growth::Ledger charged=ledger;ledger.used-=1;let growth::Ledger broken=ledger;
        b=rejected(sweeps::close_current(b,ref mut sweep,ref pool,ref mut table,ref mut ledger));
        token(next(ref mut sweep,ref table),second);a=rejected(sweeps::close_current(a,ref mut sweep,ref pool,ref mut table,ref mut ledger));
        same(ref ledger,ref broken);assert(sweep.offered && sweep.plan.active && bytes::equal(bytes::view(ref a),b"keep"));
        failed(sweeps::retry(ref mut sweep,ref table));failed(sweeps::finish(ref mut sweep,ref mut pool,ref mut table,ref mut ledger));
        ledger=charged;b=closed(sweeps::close_current(b,ref mut sweep,ref pool,ref mut table,ref mut ledger),320);
        token(next(ref mut sweep,ref table),first);a=closed(sweeps::close_current(a,ref mut sweep,ref pool,ref mut table,ref mut ledger),0);
    }
    exhausted(ref mut sweep,ref table);
    assert(switch(sweeps::finish(ref mut sweep,ref mut pool,ref mut table,ref mut ledger)){case .ok(n):{n==0}case .err(_):{false}});
    assert(switch(sweeps::finish(ref mut sweep,ref mut pool,ref mut table,ref mut ledger)){case .ok(n):{n==0}case .err(_):{false}});
    next_failed(sweeps::next(ref mut sweep,ref table));failed(sweeps::retry(ref mut sweep,ref table));
    failed(sweeps::begin(ref mut sweep,ref mut pool,ref mut table,ref mut ledger));
    assert(sweep.phase==2 && !sweep.offered && !sweep.plan.active && sweep.visited==0 && pool.phase==2 && !pool.admitted);
    assert(ledger.used==0 && ledger.engine_used==32 && ledger.peak==2560 && ledger.engine_peak==2592 && bytes::capacity(ref a)==0 && bytes::capacity(ref b)==0);
    assert(table.slots[first.slot].generation==first.generation+1 && table.slots[second.slot].generation==second.generation+1);
}
