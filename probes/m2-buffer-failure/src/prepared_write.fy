module prepared_write;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_replacement as tx;

fn growth::Limits limits() {return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn void count(Result<usize,tx::WriteError> r,usize n) {
    assert(switch(r){case .ok(v):{v==n}case .err(_):{false}});
}
fn void failed(Result<usize,tx::WriteError> r,u8 code) {
    assert(switch(r){case .ok(_):{false}case .err(e):{switch(e){
        case .State:{code==1}case .Quota:{code==2}case .Bounds:{code==3}}}});
}
fn void same_usage(ref growth::Ledger a,ref growth::Ledger b) {
    assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);
}
fn void same_table(ref owners::Table a,ref owners::Table b) {
    var usize i=0;while(i<16) {
        assert(a.slots[i].generation==b.slots[i].generation && a.slots[i].live==b.slots[i].live &&
            a.slots[i].length==b.slots[i].length && a.slots[i].capacity==b.slots[i].capacity);i+=1;
    }
}
fn void same_plan(ref tx::Plan a,ref tx::Plan b) {
    assert(a.active==b.active && a.source.slot==b.source.slot && a.source.generation==b.source.generation &&
        a.capacity==b.capacity && a.length==b.length);
    same_usage(ref a.reserved,ref b.reserved);same_table(ref a.before,ref b.before);
}
fn void seeded(ref bytes::Buffer b) {
    assert(bytes::len(b)==257 && bytes::capacity(b)==384);
    let ref u8[] v=bytes::view(b);assert(v[0]==107 && v[1]==0 && v[2]==255 && v[3]==128);
    var usize i=4;while(i<257) {assert(v[i]==0);i+=1;}
}
pub fn void run(u8 mode) {
    var growth::Ledger ledger=growth::empty();var bytes::Buffer old=bytes::empty();
    old=switch(storage::prepare_growth(ref old,256,limits(),ref mut ledger)) {
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    switch(growth::commit(256,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    let u8[4] data=[107,0,255,128];
    switch(bytes::append(ref mut old,ref data[..])){case .ok(n):{assert(n==4);}case .err(_):{assert(false);}};
    ledger.engine_used+=32;ledger.engine_peak+=32;
    var owners::Table table=owners::empty();
    let owners::Token token=switch(owners::create(ref mut table,ref old)) {
        case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}
    };
    let owners::Table before=owners::Table{.slots=table.slots};var tx::Plan plan=tx::empty();
    {
        var bytes::Buffer replacement=switch(tx::prepare_resize(ref table,token,ref old,257,limits(),ref mut ledger,ref mut plan)) {
            case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
        };
        let growth::Ledger reserved=ledger;let tx::Plan saved=plan;seeded(ref replacement);
        if(mode==0 || mode==3) {
            let u8[3] binary=[0,254,129];
            count(tx::write_prepared(ref table,ref mut replacement,1,ref binary[..],limits(),ref ledger,ref plan),3);
            count(tx::write_prepared(ref table,ref mut replacement,253,bytes::view(ref old),limits(),ref ledger,ref plan),4);
            count(tx::write_prepared(ref table,ref mut replacement,257,b"",limits(),ref ledger,ref plan),0);
            let ref u8[] v=bytes::view(ref replacement);
            assert(v[0]==107 && v[1]==0 && v[2]==254 && v[3]==129 && binary[2]==129);
            var usize i=4;while(i<253){assert(v[i]==0);i+=1;}
            assert(bytes::equal(v[253..],ref data[..]));
        }else if(mode==1) {
            failed(tx::write_prepared(ref table,ref mut replacement,18446744073709551615,b"!",limits(),ref ledger,ref plan),3);
            failed(tx::write_prepared(ref table,ref mut replacement,258,b"",limits(),ref ledger,ref plan),3);
            failed(tx::write_prepared(ref table,ref mut replacement,257,b"!",limits(),ref ledger,ref plan),3);
            failed(tx::write_prepared(ref table,ref mut replacement,256,b"!!",limits(),ref ledger,ref plan),3);
            let u8[258] oversized=[1;258];
            failed(tx::write_prepared(ref table,ref mut replacement,0,ref oversized[..],limits(),ref ledger,ref plan),3);
            count(tx::write_prepared(ref table,ref mut replacement,257,b"",limits(),ref ledger,ref plan),0);
            seeded(ref replacement);
            let u8[257] whole=[255;257];
            count(tx::write_prepared(ref table,ref mut replacement,0,ref whole[..],limits(),ref ledger,ref plan),257);
            assert(bytes::equal(bytes::view(ref replacement),ref whole[..]));
        }else{
            var usize i=0;while(i<9) {
                if(i==0){ledger.used+=1;}else if(i==1){ledger.engine_used+=1;}else if(i==2){ledger.peak+=1;}
                else if(i==3){ledger.engine_peak+=1;}else if(i==4){ledger.pending+=1;}else if(i==5){ledger.old_capacity+=1;}
                else if(i==6){ledger.new_capacity+=1;}else if(i==7){ledger.before_used+=1;}else{ledger.before_engine_used+=1;}
                let growth::Ledger corrupt=ledger;
                failed(tx::write_prepared(ref table,ref mut replacement,0,b"!",limits(),ref ledger,ref plan),1);
                failed(tx::write_prepared(ref table,ref mut replacement,257,b"",limits(),ref ledger,ref plan),1);
                same_usage(ref ledger,ref corrupt);same_plan(ref plan,ref saved);seeded(ref replacement);ledger=reserved;i+=1;
            }
            i=0;while(i<8) {
                if(i==0){plan.active=false;}else if(i==1){plan.source.slot=16;}else if(i==2){plan.source.generation+=1;}
                else if(i==3){plan.capacity=18446744073709551615;}else if(i==4){plan.length=3;}
                else if(i==5){plan.length=385;}else if(i==6){plan.before.slots[15].generation+=1;}else{plan.reserved.pending+=1;}
                let tx::Plan corrupt=plan;
                failed(tx::write_prepared(ref table,ref mut replacement,0,b"!",limits(),ref ledger,ref plan),1);
                same_plan(ref plan,ref corrupt);same_usage(ref ledger,ref reserved);seeded(ref replacement);plan=saved;i+=1;
            }
            // Matching forged snapshots must still satisfy transaction arithmetic.
            ledger.pending+=1;plan.reserved=ledger;let tx::Plan forged=plan;
            failed(tx::write_prepared(ref table,ref mut replacement,0,b"!",limits(),ref ledger,ref plan),1);
            same_usage(ref ledger,ref forged.reserved);same_plan(ref plan,ref forged);ledger=reserved;plan=saved;
            table.slots[15].generation+=1;let owners::Table changed=owners::Table{.slots=table.slots};
            failed(tx::write_prepared(ref table,ref mut replacement,0,b"!",limits(),ref ledger,ref plan),1);
            same_table(ref table,ref changed);table=before;
            table.slots[15].length=1;plan.before.slots[15].length=1;
            failed(tx::write_prepared(ref table,ref mut replacement,0,b"!",limits(),ref ledger,ref plan),1);
            table=before;plan=saved;
            failed(tx::write_prepared(ref table,ref mut old,0,b"!",limits(),ref ledger,ref plan),1);
            // Equal capacity with a different initialized length also fails.
            switch(bytes::resize_zeroed(ref mut replacement,256)){case .ok(_):{}case .err(_):{assert(false);}};
            failed(tx::write_prepared(ref table,ref mut replacement,0,b"!",limits(),ref ledger,ref plan),1);
            switch(bytes::resize_zeroed(ref mut replacement,257)){case .ok(_):{}case .err(_):{assert(false);}};
            failed(tx::write_prepared(ref table,ref mut replacement,0,b"!",growth::Limits{.object=383,.instance=8192,.engine=8192},ref ledger,ref plan),2);
            failed(tx::write_prepared(ref table,ref mut replacement,257,b"",growth::Limits{.object=4096,.instance=767,.engine=8192},ref ledger,ref plan),2);
            failed(tx::write_prepared(ref table,ref mut replacement,257,b"",growth::Limits{.object=4096,.instance=8192,.engine=799},ref ledger,ref plan),2);
            count(tx::write_prepared(ref table,ref mut replacement,257,b"",growth::Limits{.object=384,.instance=768,.engine=800},ref ledger,ref plan),0);
            seeded(ref replacement);
        }
        assert(bytes::equal(bytes::view(ref old),ref data[..]));
        same_table(ref table,ref before);same_usage(ref ledger,ref reserved);same_plan(ref plan,ref saved);
        if(mode!=3) {
            old=replacement;
            let owners::Token fresh=switch(tx::commit(ref mut table,ref old,ref mut ledger,ref mut plan)) {
                case .ok(v):{v}case .err(_):{assert(false);token}
            };
            assert(fresh.slot==token.slot && fresh.generation==token.generation+1 && !plan.active);
            assert(ledger.used==448 && ledger.engine_used==480 && ledger.pending==0);
            assert(table.slots[fresh.slot].length==257 && table.slots[fresh.slot].capacity==384);
            failed(tx::write_prepared(ref table,ref mut old,257,b"",limits(),ref ledger,ref plan),1);
            assert(switch(owners::read(ref table,token,0,ref old)){case .ok(_):{false}case .err(e):{
                switch(e){case .Token:{true}case .Owners:{false}case .State:{false}case .Bounds:{false}}}});
            if(mode==0){assert(bytes::view(ref old)[3]==129 && bytes::view(ref old)[255]==255);}
            else if(mode==1){var usize j=0;while(j<257){assert(bytes::view(ref old)[j]==255);j+=1;}}
            else{seeded(ref old);}
        }else{let bytes::Buffer discarded=replacement;}
    }
    if(mode==3) {
        assert(switch(tx::cancel(ref table,ref mut ledger,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
        same_table(ref table,ref before);assert(ledger.engine_used==352 && ledger.pending==0 && !plan.active);
        failed(tx::write_prepared(ref table,ref mut old,0,b"",limits(),ref ledger,ref plan),1);
        assert(bytes::equal(bytes::view(ref old),ref data[..]));
    }
    assert(ledger.peak==768 && ledger.engine_peak==800);
}
