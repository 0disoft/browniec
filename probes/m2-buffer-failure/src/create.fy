module create;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_create as registration;
import buffer_owners as owners;
import buffer_replacement as tx;
import buffer_close as close;

fn growth::Limits limits() {return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn owners::Token created(Result<owners::Token,registration::Error> r) {
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn void failed(Result<owners::Token,registration::Error> r,u8 expected) {
    assert(switch(r){case .ok(_):{false}case .err(e):{switch(e){
        case .Owners:{expected==1}case .State:{expected==2}case .Overflow:{expected==3}case .Quota:{expected==4}}}});
}
fn void same(ref owners::Table a,ref owners::Table b,ref growth::Ledger x,ref growth::Ledger y) {
    var usize i=0;while(i<16){assert(a.slots[i].live==b.slots[i].live && a.slots[i].generation==b.slots[i].generation &&
        a.slots[i].length==b.slots[i].length && a.slots[i].capacity==b.slots[i].capacity);i+=1;}
    assert(x.used==y.used && x.engine_used==y.engine_used && x.peak==y.peak && x.engine_peak==y.engine_peak &&
        x.pending==y.pending && x.old_capacity==y.old_capacity && x.new_capacity==y.new_capacity &&
        x.before_used==y.before_used && x.before_engine_used==y.before_engine_used);
}
fn bytes::Buffer seed(ref mut owners::Table table,ref mut growth::Ledger ledger) {
    var bytes::Buffer b=bytes::empty();
    let owners::Token old=created(registration::empty(table,ref b,limits(),ledger));
    assert(old.slot==0 && old.generation==1 && ledger.used==64 && ledger.engine_used==96);
    var tx::Plan plan=tx::empty();
    b=switch(tx::prepare(table,old,ref b,256,limits(),ledger,ref mut plan)) {
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    let owners::Token fresh=switch(tx::commit(table,ref b,ledger,ref mut plan)) {
        case .ok(v):{v}case .err(_):{assert(false);old}
    };
    assert(fresh.generation==2 && ledger.used==320 && ledger.engine_used==352 && ledger.peak==384 && ledger.engine_peak==416);
    return b;
}
fn void success() {
    var owners::Table table=owners::empty();var growth::Ledger l=growth::unowned();l.engine_used=32;l.engine_peak=32;
    var bytes::Buffer b=seed(ref mut table,ref mut l);
    let owners::Token first=owners::Token{.slot=0,.generation=2};
    let bytes::Buffer second=bytes::empty();let owners::Token next=created(registration::empty(ref mut table,ref second,limits(),ref mut l));
    assert(next.slot==1 && l.used==384 && l.engine_used==416 && l.peak==384 && l.engine_peak==416);
    var close::Plan closing=close::empty();
    assert(switch(close::begin(ref mut table,first,ref b,ref l,ref mut closing)){case .ok(n):{n==320}case .err(_):{false}});
    {let bytes::Buffer disposed=b;}
    assert(switch(close::finish(ref table,ref mut l,ref mut closing)){case .ok(n):{n==64}case .err(_):{false}});
    assert(l.engine_used==96 && table.slots[next.slot].live);
    assert(switch(close::begin(ref mut table,next,ref second,ref l,ref mut closing)){case .ok(n):{n==64}case .err(_):{false}});
    {let bytes::Buffer disposed=second;}
    assert(switch(close::finish(ref table,ref mut l,ref mut closing)){case .ok(n):{n==0}case .err(_):{false}});
    assert(l.engine_used==32);
    let bytes::Buffer third=bytes::empty();let owners::Token again=created(registration::empty(ref mut table,ref third,limits(),ref mut l));
    assert(again.slot==0 && again.generation==3 && l.used==64 && l.engine_used==96 && l.peak==384 && l.engine_peak==416);
    assert(switch(owners::describe(ref table,first)){case .ok(_):{false}case .err(e):{
        switch(e){case .Token:{true}case .Owners:{false}case .State:{false}case .Bounds:{false}}}});
    assert(switch(close::begin(ref mut table,again,ref third,ref l,ref mut closing)){case .ok(n):{n==64}case .err(_):{false}});
    {let bytes::Buffer disposed=third;}
    assert(switch(close::finish(ref table,ref mut l,ref mut closing)){case .ok(n):{n==0}case .err(_):{false}});
    assert(l.engine_used==32 && l.peak==384 && l.engine_peak==416 && !closing.active);
}
fn void reject(u8 mode) {
    var owners::Table table=owners::empty();var growth::Ledger l=growth::unowned();l.engine_used=32;l.engine_peak=32;
    let bytes::Buffer b=seed(ref mut table,ref mut l);let bytes::Buffer extra=bytes::empty();
    let owners::Table before=owners::Table{.slots=table.slots};let growth::Ledger prior=l;
    if(mode==1) {
        failed(registration::empty(ref mut table,ref extra,growth::Limits{.object=4096,.instance=383,.engine=8192},ref mut l),4);
        failed(registration::empty(ref mut table,ref extra,growth::Limits{.object=4096,.instance=8192,.engine=415},ref mut l),4);
        failed(registration::empty(ref mut table,ref b,limits(),ref mut l),2);
        same(ref table,ref before,ref l,ref prior);
        let owners::Token fresh=created(registration::empty(ref mut table,ref extra,growth::Limits{.object=0,.instance=8192,.engine=8192},ref mut l));
        assert(fresh.slot==1 && l.used==384 && l.engine_used==416 && bytes::capacity(ref extra)==0);
    }else if(mode==2) {
        var usize i=0;while(i<9){
            if(i==0){l.pending=1;}else if(i==1){l.old_capacity=64;}else if(i==2){l.new_capacity=64;}
            else if(i==3){l.before_used=64;}else if(i==4){l.before_engine_used=64;}else if(i==5){l.used=319;}
            else if(i==6){l.engine_used=319;}else if(i==7){l.peak=319;}else{l.engine_peak=319;}
            let growth::Ledger corrupt=l;failed(registration::empty(ref mut table,ref extra,limits(),ref mut l),2);
            same(ref table,ref before,ref l,ref corrupt);l=prior;i+=1;
        }
        table.slots[1].length=1;let owners::Table malformed=owners::Table{.slots=table.slots};
        failed(registration::empty(ref mut table,ref extra,limits(),ref mut l),2);same(ref table,ref malformed,ref l,ref prior);
        table.slots[1]=before.slots[1];
        table.slots[1].live=true;table.slots[1].capacity=18446744073709551488;
        let owners::Table huge=owners::Table{.slots=table.slots};
        failed(registration::empty(ref mut table,ref extra,limits(),ref mut l),3);same(ref table,ref huge,ref l,ref prior);
        table.slots[1]=before.slots[1];
        l.used=18446744073709551552;l.engine_used=l.used;l.peak=l.used;l.engine_peak=l.used;
        let growth::Ledger overflowing=l;failed(registration::empty(ref mut table,ref extra,limits(),ref mut l),3);
        same(ref table,ref before,ref l,ref overflowing);
        l.used=18446744073709551551;l.engine_used=l.used;l.peak=l.used;l.engine_peak=l.used;
        let owners::Token boundary=created(registration::empty(ref mut table,ref extra,growth::Limits{
            .object=0,.instance=18446744073709551615,.engine=18446744073709551615},ref mut l));
        assert(boundary.slot==1 && l.used==18446744073709551615 && l.engine_used==l.used && l.peak==l.used && l.engine_peak==l.used);
    }else{
        var usize i=1;while(i<16){table.slots[i].live=true;i+=1;}
        l.used=1280;l.engine_used=1312;l.peak=1280;l.engine_peak=1312;
        let owners::Table full=owners::Table{.slots=table.slots};let growth::Ledger full_usage=l;
        failed(registration::empty(ref mut table,ref extra,limits(),ref mut l),1);same(ref table,ref full,ref l,ref full_usage);
        table.slots[1].live=false;table.slots[1].generation=0;
        let owners::Table retired=owners::Table{.slots=table.slots};
        failed(registration::empty(ref mut table,ref extra,limits(),ref mut l),1);same(ref table,ref retired,ref l,ref full_usage);
        table.slots[2].live=false;table.slots[2].generation=18446744073709551615;
        let owners::Token last=created(registration::empty(ref mut table,ref extra,limits(),ref mut l));
        assert(last.slot==2 && last.generation==18446744073709551615 && l.used==1344 && l.engine_used==1376);
        var close::Plan closing=close::empty();
        assert(switch(close::begin(ref mut table,last,ref extra,ref l,ref mut closing)){case .ok(n):{n==64}case .err(_):{false}});
        {let bytes::Buffer disposed=extra;}
        assert(switch(close::finish(ref table,ref mut l,ref mut closing)){case .ok(n):{n==1280}case .err(_):{false}});
        assert(table.slots[2].generation==0 && l.engine_used==1312);
        let bytes::Buffer another=bytes::empty();failed(registration::empty(ref mut table,ref another,limits(),ref mut l),1);
        return;
    }
}
pub fn void run(u8 mode) {if(mode==0){success();}else{reject(mode);}}
