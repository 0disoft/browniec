module read_lease;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_write as write;
import buffer_append as append;
import buffer_truncate as truncate;
import buffer_resize as resize;
import buffer_close as close;
import buffer_replacement as tx;
import buffer_utf8 as utf8;
import buffer_utf8_scan as scan;
import buffer_utf8_meter as meter;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn owners::Token leased(Result<owners::Token,owners::Error> r){
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn bool state(owners::Error e){return switch(e){case .State:{true}case .Token:{false}case .Owners:{false}case .Bounds:{false}};}
fn void refused(Result<owners::Token,owners::Error> r,bool identity){
    assert(switch(r){case .ok(_):{false}case .err(e):{if(identity){switch(e){case .Token:{true}
        case .State:{false}case .Owners:{false}case .Bounds:{false}}}else{state(e)}}});
}
fn void ended(Result<usize,owners::Error> r,usize slot){assert(switch(r){case .ok(n):{n==slot}case .err(_):{false}});}
fn void same_table(ref owners::Table a,ref owners::Table b){
    var usize i=0;while(i<16){assert(a.slots[i].generation==b.slots[i].generation && a.slots[i].live==b.slots[i].live &&
        a.slots[i].length==b.slots[i].length && a.slots[i].capacity==b.slots[i].capacity && a.slots[i].reading==b.slots[i].reading);i+=1;}
}
fn void same_usage(ref growth::Ledger a,ref growth::Ledger b){
    assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);
}
pub fn void run(u8 mode){
    var growth::Ledger ledger=growth::empty();var bytes::Buffer b=bytes::empty();var owners::Table table=owners::empty();
    b=switch(storage::prepare_growth(ref b,256,limits(),ref mut ledger)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    switch(growth::commit(256,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(ref mut b,b"keep")){case .ok(_):{}case .err(_):{assert(false);}};
    ledger.engine_used+=32;ledger.engine_peak+=32;
    let owners::Token token=leased(owners::create(ref mut table,ref b));
    let owners::Table before=owners::Table{.slots=table.slots};let growth::Ledger usage=ledger;
    if(mode==0){
        let owners::Token lease=leased(owners::begin_read(ref mut table,token,ref b,ref ledger));
        assert(lease.slot==token.slot && lease.generation==token.generation && table.slots[token.slot].reading);
        let owners::Table pinned=owners::Table{.slots=table.slots};
        refused(owners::begin_read(ref mut table,token,ref b,ref ledger),false);same_table(ref table,ref pinned);
        assert(switch(owners::read(ref table,token,0,ref b)){case .ok(v):{v==107}case .err(_):{false}});
        var u8[4] output=[0;4];assert(switch(owners::copy_out(ref table,token,0,ref b,ref mut output[..])){case .ok(n):{n==4}case .err(_):{false}});
        assert(bytes::equal(ref output[..],b"keep"));
        assert(switch(utf8::validate(ref table,token,ref b)){case .ok(n):{n==4}case .err(_):{false}});
        ended(owners::end_read(ref mut table,lease),token.slot);same_table(ref table,ref before);
        assert(switch(owners::end_read(ref mut table,lease)){case .ok(_):{false}case .err(e):{state(e)}});
        table.slots[token.slot].generation=18446744073709551615;
        let owners::Token last=owners::Token{.slot=token.slot,.generation=18446744073709551615};
        let owners::Token final=leased(owners::begin_read(ref mut table,last,ref b,ref ledger));
        assert(final.generation==last.generation);ended(owners::end_read(ref mut table,final),last.slot);
        assert(table.slots[last.slot].generation==last.generation && !table.slots[last.slot].reading);
    }else if(mode==1){
        let owners::Token lease=leased(owners::begin_read(ref mut table,token,ref b,ref ledger));
        let owners::Table pinned=owners::Table{.slots=table.slots};
        assert(switch(owners::write(ref table,token,0,255,ref mut b)){case .ok(_):{false}case .err(e):{state(e)}});
        assert(switch(owners::release(ref mut table,token)){case .ok(_):{false}case .err(e):{state(e)}});
        assert(switch(write::within_length(ref table,token,0,ref mut b,b"!",limits(),ref ledger)){case .ok(_):{false}case .err(_):{true}});
        assert(switch(write::within_length(ref table,token,4,ref mut b,b"",limits(),ref ledger)){case .ok(_):{false}case .err(_):{true}});
        assert(switch(append::within_capacity(ref mut table,token,ref mut b,b"!",limits(),ref ledger)){case .ok(_):{false}case .err(_):{true}});
        assert(switch(append::within_capacity(ref mut table,token,ref mut b,b"",limits(),ref ledger)){case .ok(_):{false}case .err(_):{true}});
        assert(switch(truncate::to_length(ref mut table,token,ref mut b,4,limits(),ref ledger)){case .ok(_):{false}case .err(_):{true}});
        assert(switch(truncate::clear(ref mut table,token,ref mut b,limits(),ref ledger)){case .ok(_):{false}case .err(_):{true}});
        assert(switch(resize::within_capacity(ref mut table,token,ref mut b,4,limits(),ref ledger)){case .ok(_):{false}case .err(_):{true}});
        assert(switch(resize::within_capacity(ref mut table,token,ref mut b,5,limits(),ref ledger)){case .ok(_):{false}case .err(_):{true}});
        var tx::Plan plan=tx::empty();
        assert(switch(tx::prepare(ref table,token,ref b,257,limits(),ref mut ledger,ref mut plan)){case .ok(_):{false}case .err(_):{true}});
        assert(switch(tx::prepare_resize(ref table,token,ref b,257,limits(),ref mut ledger,ref mut plan)){case .ok(_):{false}case .err(_):{true}});
        let u8[253] suffix=[88;253];
        assert(switch(tx::prepare_append(ref table,token,ref b,ref suffix[..],limits(),ref mut ledger,ref mut plan)){case .ok(_):{false}case .err(_):{true}});
        assert(!plan.active);
        var close::Plan closing=close::empty();
        assert(switch(close::begin(ref mut table,token,ref b,ref ledger,ref mut closing)){case .ok(_):{false}case .err(_):{true}});
        assert(!closing.active);same_table(ref table,ref pinned);same_usage(ref ledger,ref usage);
        ended(owners::end_read(ref mut table,lease),token.slot);
        assert(switch(write::within_length(ref table,token,0,ref mut b,b"K",limits(),ref ledger)){case .ok(n):{n==1}case .err(_):{false}});
        assert(bytes::equal(bytes::view(ref b),b"Keep"));same_table(ref table,ref before);
    }else if(mode==2){
        let bytes::Buffer missing=bytes::empty();
        refused(owners::begin_read(ref mut table,owners::Token{.slot=16,.generation=0},ref missing,ref ledger),true);
        refused(owners::begin_read(ref mut table,token,ref missing,ref ledger),false);
        table.slots[15].reading=true;refused(owners::begin_read(ref mut table,token,ref b,ref ledger),false);table=before;
        var usize i=0;while(i<9){
            if(i==0){ledger.used=319;}else if(i==1){ledger.engine_used=319;}else if(i==2){ledger.peak=319;}
            else if(i==3){ledger.engine_peak=319;}else if(i==4){ledger.pending=1;}else if(i==5){ledger.old_capacity=64;}
            else if(i==6){ledger.new_capacity=64;}else if(i==7){ledger.before_used=64;}else{ledger.before_engine_used=64;}
            let growth::Ledger corrupt=ledger;refused(owners::begin_read(ref mut table,token,ref b,ref ledger),false);
            same_usage(ref ledger,ref corrupt);same_table(ref table,ref before);ledger=usage;i+=1;
        }
        var tx::Plan plan=tx::empty();
        {let bytes::Buffer replacement=switch(tx::prepare_resize(ref table,token,ref b,257,limits(),ref mut ledger,ref mut plan)){
            case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
            let growth::Ledger reserved=ledger;let tx::Plan planned=plan;
            refused(owners::begin_read(ref mut table,token,ref b,ref ledger),false);
            same_table(ref table,ref before);same_usage(ref ledger,ref reserved);
            same_table(ref plan.before,ref planned.before);same_usage(ref plan.reserved,ref planned.reserved);
            assert(plan.active==planned.active && plan.length==planned.length && plan.capacity==planned.capacity &&
                plan.source.slot==planned.source.slot && plan.source.generation==planned.source.generation);
            assert(bytes::equal(bytes::view(ref replacement)[..4],b"keep"));
        }
        assert(switch(tx::cancel(ref table,ref mut ledger,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
        let owners::Token lease=leased(owners::begin_read(ref mut table,token,ref b,ref ledger));
        refused(owners::begin_read(ref mut table,token,ref b,ref ledger),false);
        assert(switch(owners::end_read(ref mut table,owners::Token{.slot=token.slot,.generation=token.generation+1})){
            case .ok(_):{false}case .err(e):{switch(e){case .Token:{true}case .State:{false}case .Owners:{false}case .Bounds:{false}}}});
        assert(table.slots[token.slot].reading);ended(owners::end_read(ref mut table,lease),token.slot);same_table(ref table,ref before);
    }else{
        let owners::Token lease=leased(owners::begin_read(ref mut table,token,ref b,ref ledger));
        let owners::Table pinned=owners::Table{.slots=table.slots};var usize fuel=392;
        var scan::Cursor cursor=switch(meter::begin_cancellable(false,ref table,token,ref b,ref mut fuel)){
            case .ok(v):{v}case .err(_):{assert(false);scan::Cursor{.active=false,.source=token,.length=4,.capacity=256,.offset=0,.carry=[0;4],.have=0}}};
        assert(switch(meter::step_cancellable(false,ref table,ref b,1,ref mut cursor,ref mut fuel)){case .ok(done):{!done}case .err(_):{false}});
        assert(switch(write::within_length(ref table,token,0,ref mut b,b"!",limits(),ref ledger)){case .ok(_):{false}case .err(_):{true}});
        assert(switch(meter::step_cancellable(true,ref table,ref b,1,ref mut cursor,ref mut fuel)){case .ok(_):{false}
            case .err(e):{switch(e){case .Cancelled:{true}case .Fuel:{false}case .Token:{false}case .State:{false}case .Utf8:{false}}}});
        assert(fuel==132 && cursor.offset==1 && !cursor.active && table.slots[token.slot].reading);
        assert(switch(owners::write(ref table,token,0,255,ref mut b)){case .ok(_):{false}case .err(e):{state(e)}});
        same_table(ref table,ref pinned);same_usage(ref ledger,ref usage);
        ended(owners::end_read(ref mut table,lease),token.slot);
        assert(switch(owners::write(ref table,token,0,75,ref mut b)){case .ok(n):{n==0}case .err(_):{false}});
        assert(bytes::equal(bytes::view(ref b),b"Keep"));same_table(ref table,ref before);
    }
    if(mode!=1 && mode!=3){assert(bytes::equal(bytes::view(ref b),b"keep"));}
    if(mode!=2){same_usage(ref ledger,ref usage);}else{
        assert(ledger.used==320 && ledger.engine_used==352 && ledger.peak==768 && ledger.engine_peak==800 &&
            ledger.pending==0 && ledger.old_capacity==0 && ledger.new_capacity==0 &&
            ledger.before_used==0 && ledger.before_engine_used==0);
    }
}
