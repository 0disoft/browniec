module host_close;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_close as close;
import buffer_host_close as host;
import buffer_utf8_pool as pools;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn bytes::Buffer rejected(Result<usize,bytes::Buffer> outcome){
    return switch(outcome){case .ok(_):{assert(false);bytes::empty()}case .err(root):{root}};
}
fn void same_ledger(ref growth::Ledger a,ref growth::Ledger b){
    assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);
}
fn void kept(ref bytes::Buffer root){assert(bytes::capacity(root)==256 && bytes::len(root)==4 && bytes::equal(bytes::view(root),b"keep"));}
pub fn void run(u8 mode){
    var growth::Ledger ledger=growth::empty();var bytes::Buffer b=bytes::empty();
    b=switch(storage::prepare_growth(ref b,256,limits(),ref mut ledger)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    switch(growth::commit(256,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(ref mut b,b"keep")){case .ok(_):{}case .err(_):{assert(false);}};
    ledger.engine_used+=32;ledger.engine_peak+=32;
    var owners::Table table=owners::empty();
    let owners::Token token=switch(owners::create(ref mut table,ref b)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    var pools::Pool pool=pools::empty();switch(pools::admit(ref mut pool,limits(),ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    var close::Plan plan=close::empty();var usize fuel=256;
    if(mode==0 || mode==1){
        let pools::Ticket ticket=switch(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel)){
            case .ok(v):{v}case .err(_):{assert(false);pools::Ticket{.slot=16,.generation=0}}};
        fuel=260;assert(switch(pools::step(false,ref mut pool,ticket,ref mut table,ref b,1,ref mut fuel)){
            case .ok(done):{!done}case .err(_):{false}});
        assert(fuel==0 && table.slots[token.slot].reading);
        if(mode==1){
            let growth::Ledger before=ledger;table.slots[token.slot].generation+=1;
            b=rejected(host::shutdown(b,token,ref mut pool,ref mut table,ref mut ledger,ref mut plan));
            kept(ref b);same_ledger(ref ledger,ref before);
            assert(!plan.active && pool.phase==1 && pool.admitted && pool.s0.live && pool.s0.session.held && table.slots[token.slot].reading);
            table.slots[token.slot].generation=token.generation;
        }
    }else if(mode==2){
        // Pool cleanup commits first; failed close preflight returns the root.
        table.slots[token.slot].length=3;
        b=rejected(host::shutdown(b,token,ref mut pool,ref mut table,ref mut ledger,ref mut plan));
        kept(ref b);assert(pool.phase==2 && !pool.admitted && !plan.active && table.slots[token.slot].live && ledger.used==320 && ledger.engine_used==352);
        table.slots[token.slot].length=4;
        switch(growth::begin(256,257,limits(),ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
        let growth::Ledger reserved=ledger;
        b=rejected(host::shutdown(b,token,ref mut pool,ref mut table,ref mut ledger,ref mut plan));
        kept(ref b);same_ledger(ref ledger,ref reserved);assert(!plan.active && table.slots[token.slot].live);
        switch(growth::cancel(ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    }else{
        // Manufacture the documented post-destruction retry state without races.
        switch(pools::shutdown(ref mut pool,ref mut table,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
        switch(close::begin(ref mut table,token,ref b,ref ledger,ref mut plan)){case .ok(_):{}case .err(_):{assert(false);}};
        let growth::Ledger charged=ledger;
        // An active Plan must not destroy a still-live or unrelated nonempty root.
        b=rejected(host::shutdown(b,token,ref mut pool,ref mut table,ref mut ledger,ref mut plan));
        kept(ref b);same_ledger(ref ledger,ref charged);assert(plan.active);
        {let bytes::Buffer disposed=b;}b=bytes::empty();
        ledger.used=319;let growth::Ledger broken=ledger;
        b=rejected(host::shutdown(b,token,ref mut pool,ref mut table,ref mut ledger,ref mut plan));
        assert(bytes::capacity(ref b)==0 && plan.active);same_ledger(ref ledger,ref broken);
        ledger=charged;pool.phase=1;
        b=rejected(host::shutdown(b,token,ref mut pool,ref mut table,ref mut ledger,ref mut plan));
        same_ledger(ref ledger,ref charged);assert(plan.active);pool.phase=2;
        b=rejected(host::shutdown(b,owners::Token{.slot=token.slot,.generation=token.generation+1},ref mut pool,ref mut table,ref mut ledger,ref mut plan));
        same_ledger(ref ledger,ref charged);assert(plan.active);
    }
    // Every successful call consumes the actual root (empty for accounting retry).
    b=switch(host::shutdown(b,token,ref mut pool,ref mut table,ref mut ledger,ref mut plan)){
        case .ok(used):{assert(used==0);bytes::empty()}case .err(root):{assert(false);root}};
    assert(bytes::capacity(ref b)==0 && bytes::len(ref b)==0 && !plan.active && pool.phase==2 && !pool.admitted && fuel==if(mode<=1){0}else{256});
    assert(ledger.used==0 && ledger.engine_used==32 && ledger.pending==0 && ledger.peak==2432 && ledger.engine_peak==2464);
    assert(!table.slots[token.slot].live && !table.slots[token.slot].reading && table.slots[token.slot].generation==token.generation+1);
    let growth::Ledger closed=ledger;
    b=rejected(host::shutdown(b,token,ref mut pool,ref mut table,ref mut ledger,ref mut plan));
    same_ledger(ref ledger,ref closed);assert(bytes::capacity(ref b)==0 && !plan.active && table.slots[token.slot].generation==token.generation+1);
}
