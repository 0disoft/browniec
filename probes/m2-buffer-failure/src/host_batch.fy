module host_batch;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_close as close;
import buffer_host_close as host;
import buffer_utf8_pool as pools;
import buffer_utf8_meter as meter;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn bytes::Buffer rejected(Result<usize,bytes::Buffer> r){return switch(r){case .ok(_):{assert(false);bytes::empty()}case .err(b):{b}};}
fn bytes::Buffer closed(Result<usize,bytes::Buffer> r,usize expected){
    return switch(r){case .ok(n):{assert(n==expected);bytes::empty()}case .err(b):{assert(false);b}};
}
fn void failed(Result<usize,meter::ControlError> r){assert(switch(r){case .ok(_):{false}case .err(e):{
    switch(e){case .State:{true}case .Cancelled:{false}case .Fuel:{false}case .Token:{false}case .Utf8:{false}}}});}
fn void same(ref growth::Ledger a,ref growth::Ledger b){
    assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak && a.pending==b.pending &&
        a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity && a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);
}
fn void kept(ref bytes::Buffer a,ref bytes::Buffer b){assert(bytes::capacity(a)==256 && bytes::equal(bytes::view(a),b"keep") &&
    bytes::capacity(b)==64 && bytes::equal(bytes::view(b),b"other"));}
fn owners::Token registered(ref mut owners::Table table,ref bytes::Buffer b){return switch(owners::create(table,b)){
    case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};}
fn void leased(ref mut pools::Pool pool,ref mut owners::Table table,owners::Token token,ref bytes::Buffer root,ref growth::Ledger ledger){
    var usize fuel=256;assert(switch(pools::begin(false,pool,table,token,root,ledger,ref mut fuel)){case .ok(_):{true}case .err(_):{false}});assert(fuel==0);
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
    ledger.engine_used+=32;ledger.engine_peak+=32;
    var owners::Table table=owners::empty();let owners::Token first=registered(ref mut table,ref a);let owners::Token second=registered(ref mut table,ref b);
    var pools::Pool pool=pools::empty();switch(pools::admit(ref mut pool,limits(),ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    var close::Plan plan=close::empty();assert(ledger.used==2560 && ledger.engine_used==2592);
    if(mode==0){
        leased(ref mut pool,ref mut table,first,ref a,ref ledger);leased(ref mut pool,ref mut table,second,ref b,ref ledger);
        pool.s0.session.source.generation+=1;let growth::Ledger charged=ledger;
        a=rejected(host::shutdown(a,first,ref mut pool,ref mut table,ref mut ledger,ref mut plan));
        kept(ref a,ref b);same(ref ledger,ref charged);
        assert(pool.phase==1 && pool.admitted && pool.s0.live && !pool.s1.live && table.slots[first.slot].reading && !table.slots[second.slot].reading);
        b=closed(host::close_stopped(b,second,ref pool,ref mut table,ref mut ledger,ref mut plan),2432);
        assert(ledger.engine_used==2464 && !plan.active && pool.admitted && pool.s0.session.held && table.slots[first.slot].live && !table.slots[second.slot].live);
        assert(bytes::equal(bytes::view(ref a),b"keep"));failed(host::finish_all(ref mut pool,ref mut table,ref mut ledger,ref plan));
        pool.s0.session.source.generation=first.generation;
        a=closed(host::shutdown(a,first,ref mut pool,ref mut table,ref mut ledger,ref mut plan),0);
    }else if(mode==1){
        let growth::Ledger before=ledger;
        b=rejected(host::close_stopped(b,second,ref pool,ref mut table,ref mut ledger,ref mut plan));
        kept(ref a,ref b);same(ref ledger,ref before);assert(pool.phase==0 && !plan.active);
        failed(host::finish_all(ref mut pool,ref mut table,ref mut ledger,ref plan));
        switch(pools::shutdown(ref mut pool,ref mut table,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
        failed(host::finish_all(ref mut pool,ref mut table,ref mut ledger,ref plan));
        table.slots[second.slot].length=4;let growth::Ledger stopped=ledger;
        b=rejected(host::close_stopped(b,second,ref pool,ref mut table,ref mut ledger,ref mut plan));
        kept(ref a,ref b);same(ref ledger,ref stopped);assert(!plan.active);
        a=closed(host::close_stopped(a,first,ref pool,ref mut table,ref mut ledger,ref mut plan),128);
        assert(ledger.engine_used==160 && table.slots[second.slot].live);table.slots[second.slot].length=5;
        b=closed(host::close_stopped(b,second,ref pool,ref mut table,ref mut ledger,ref mut plan),0);
    }else if(mode==2){
        switch(pools::shutdown(ref mut pool,ref mut table,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
        switch(close::begin(ref mut table,first,ref a,ref ledger,ref mut plan)){case .ok(_):{}case .err(_):{assert(false);}};
        {let bytes::Buffer disposed=a;}a=bytes::empty();let growth::Ledger charged=ledger;
        ledger.used-=1;let growth::Ledger broken=ledger;
        a=rejected(host::close_stopped(a,first,ref pool,ref mut table,ref mut ledger,ref mut plan));
        b=rejected(host::close_stopped(b,second,ref pool,ref mut table,ref mut ledger,ref mut plan));
        same(ref ledger,ref broken);assert(plan.active && table.slots[second.slot].live && bytes::equal(bytes::view(ref b),b"other"));
        failed(host::finish_all(ref mut pool,ref mut table,ref mut ledger,ref plan));ledger=charged;
        a=closed(host::close_stopped(a,first,ref pool,ref mut table,ref mut ledger,ref mut plan),128);
        assert(!plan.active && table.slots[second.slot].live);
        b=closed(host::close_stopped(b,second,ref pool,ref mut table,ref mut ledger,ref mut plan),0);
    }else{
        switch(pools::shutdown(ref mut pool,ref mut table,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
        let growth::Ledger funded=ledger;ledger.used-=1;let growth::Ledger short_usage=ledger;
        a=rejected(host::close_stopped(a,first,ref pool,ref mut table,ref mut ledger,ref mut plan));
        kept(ref a,ref b);same(ref ledger,ref short_usage);assert(!plan.active && table.slots[first.slot].live);ledger=funded;
        // Overflow in the aggregate charge must reject before root access/retirement.
        table.slots[first.slot].capacity=18446744073709551488;
        a=rejected(host::close_stopped(a,first,ref pool,ref mut table,ref mut ledger,ref mut plan));
        kept(ref a,ref b);same(ref ledger,ref funded);assert(!plan.active);table.slots[first.slot].capacity=256;
        pool.phase=255;b=rejected(host::close_stopped(b,second,ref pool,ref mut table,ref mut ledger,ref mut plan));
        kept(ref a,ref b);same(ref ledger,ref funded);pool.phase=2;
        a=closed(host::close_stopped(a,first,ref pool,ref mut table,ref mut ledger,ref mut plan),128);
        b=closed(host::close_stopped(b,second,ref pool,ref mut table,ref mut ledger,ref mut plan),0);
    }
    assert(!plan.active && !table.slots[first.slot].live && !table.slots[second.slot].live && ledger.used==0 && ledger.engine_used==32);
    assert(ledger.peak==2560 && ledger.engine_peak==2592 && bytes::capacity(ref a)==0 && bytes::capacity(ref b)==0);
    assert(table.slots[first.slot].generation==first.generation+1 && table.slots[second.slot].generation==second.generation+1);
    let growth::Ledger finished=ledger;ledger.pending=1;
    failed(host::finish_all(ref mut pool,ref mut table,ref mut ledger,ref plan));ledger=finished;
    assert(switch(host::finish_all(ref mut pool,ref mut table,ref mut ledger,ref plan)){case .ok(n):{n==0}case .err(_):{false}});
    assert(switch(host::finish_all(ref mut pool,ref mut table,ref mut ledger,ref plan)){case .ok(n):{n==0}case .err(_):{false}});
    a=rejected(host::close_stopped(a,first,ref pool,ref mut table,ref mut ledger,ref mut plan));same(ref ledger,ref finished);
    assert(pool.phase==2 && !pool.admitted && !plan.active);
}
