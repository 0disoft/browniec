module write;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_replacement as tx;
import buffer_append as append;
import buffer_write as write;

fn growth::Limits limits() {return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn void count(Result<usize,write::Error> r,usize expected) {
    assert(switch(r){case .ok(n):{n==expected}case .err(_):{false}});
}
fn void failed(Result<usize,write::Error> r,u8 expected) {
    assert(switch(r){case .ok(_):{false}case .err(e):{switch(e){case .Token:{expected==1}
        case .State:{expected==2}case .Bounds:{expected==3}case .Quota:{expected==4}
        case .Owners:{expected==5}case .Overflow:{expected==6}}}});
}
fn void same_usage(ref growth::Ledger a,ref growth::Ledger b) {
    assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);
}
pub fn void run(u8 mode) {
    var growth::Ledger l=growth::empty();var bytes::Buffer b=bytes::empty();
    b=switch(storage::prepare_growth(ref b,256,limits(),ref mut l)) {
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    switch(growth::commit(256,ref mut l)){case .ok(_):{}case .err(_):{assert(false);}};
    let u8[6] data=[107,0,255,128,101,112];
    switch(bytes::append(ref mut b,ref data[..])){case .ok(n):{assert(n==6);}case .err(_):{assert(false);}};
    l.engine_used+=32;l.engine_peak+=32;
    var owners::Table table=owners::empty();table.slots[15].generation=7;
    let owners::Token old=switch(owners::create(ref mut table,ref b)) {
        case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}
    };
    let owners::Table before=owners::Table{.slots=table.slots};let growth::Ledger usage=l;
    if(mode==0) {
        let u8[3] input=[0,254,129];let u8[6] middle=[107,0,254,129,101,112];
        count(write::within_length(ref table,old,1,ref mut b,ref input[..],limits(),ref l),3);
        assert(bytes::equal(bytes::view(ref b),ref middle[..]) && input[0]==0 && input[1]==254 && input[2]==129);
        let u8[6] all=[255,0,128,1,2,3];
        count(write::within_length(ref table,old,0,ref mut b,ref all[..],limits(),ref l),6);
        assert(bytes::equal(bytes::view(ref b),ref all[..]));
        count(write::within_length(ref table,old,6,ref mut b,b"",limits(),ref l),0);
        assert(bytes::equal(bytes::view(ref b),ref all[..]));
        var u8[6] output=[90;6];
        assert(switch(owners::copy_out(ref table,old,0,ref b,ref mut output[..])){case .ok(n):{n==6}case .err(_):{false}});
        assert(bytes::equal(ref output[..],ref all[..]));
    }else if(mode==1) {
        failed(write::within_length(ref table,old,18446744073709551615,ref mut b,b"!",limits(),ref l),3);
        failed(write::within_length(ref table,old,7,ref mut b,b"",limits(),ref l),3);
        failed(write::within_length(ref table,old,6,ref mut b,b"!",limits(),ref l),3);
        failed(write::within_length(ref table,old,5,ref mut b,b"!!",limits(),ref l),3);
        failed(write::within_length(ref table,old,0,ref mut b,b"1234567",limits(),ref l),3);
        count(write::within_length(ref table,old,6,ref mut b,b"",limits(),ref l),0);
        assert(bytes::equal(bytes::view(ref b),ref data[..]));
    }else if(mode==2) {
        var bytes::Buffer missing=bytes::empty();
        failed(write::within_length(ref table,owners::Token{.slot=16,.generation=0},0,ref mut missing,b"",limits(),ref l),1);
        failed(write::within_length(ref table,old,0,ref mut missing,b"!",limits(),ref l),2);
        table.slots[15].length=1;
        failed(write::within_length(ref table,old,0,ref mut b,b"!",limits(),ref l),2);table.slots[15].length=0;
        assert(bytes::equal(bytes::view(ref b),ref data[..]));
        let owners::Token fresh=switch(append::within_capacity(ref mut table,old,ref mut b,b"!",limits(),ref l)) {
            case .ok(v):{v}case .err(_):{assert(false);old}
        };
        failed(write::within_length(ref table,old,0,ref mut missing,b"!",limits(),ref l),1);
        count(write::within_length(ref table,fresh,6,ref mut b,b"?",limits(),ref l),1);
        assert(bytes::view(ref b)[6]==63 && table.slots[fresh.slot].generation==fresh.generation);
        table.slots[old.slot].generation=18446744073709551615;
        let owners::Token last=owners::Token{.slot=old.slot,.generation=18446744073709551615};
        count(write::within_length(ref table,last,6,ref mut b,b"!",limits(),ref l),1);
        assert(bytes::view(ref b)[6]==33 && table.slots[last.slot].generation==last.generation);
        assert(bytes::equal(bytes::view(ref b)[..6],ref data[..]));
    }else{
        var usize i=0;while(i<9) {
            if(i==0){l.pending=1;}else if(i==1){l.old_capacity=64;}else if(i==2){l.new_capacity=64;}
            else if(i==3){l.before_used=64;}else if(i==4){l.before_engine_used=64;}else if(i==5){l.used=319;}
            else if(i==6){l.engine_used=319;}else if(i==7){l.peak=319;}else{l.engine_peak=319;}
            let growth::Ledger corrupt=l;
            failed(write::within_length(ref table,old,0,ref mut b,b"!",limits(),ref l),2);
            same_usage(ref l,ref corrupt);assert(bytes::equal(bytes::view(ref b),ref data[..]));l=usage;i+=1;
        }
        failed(write::within_length(ref table,old,0,ref mut b,b"!",growth::Limits{.object=4096,.instance=319,.engine=8192},ref l),4);
        failed(write::within_length(ref table,old,6,ref mut b,b"",growth::Limits{.object=4096,.instance=8192,.engine=351},ref l),4);
        failed(write::within_length(ref table,old,6,ref mut b,b"",growth::Limits{.object=255,.instance=8192,.engine=8192},ref l),4);
        same_usage(ref l,ref usage);assert(bytes::equal(bytes::view(ref b),ref data[..]));
        var tx::Plan plan=tx::empty();
        {let bytes::Buffer discarded=switch(tx::prepare_resize(ref table,old,ref b,257,limits(),ref mut l,ref mut plan)) {
            case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
        };
            assert(bytes::len(ref discarded)==257 && plan.active);
            let growth::Ledger reserved=l;
            failed(write::within_length(ref table,old,0,ref mut b,b"!",limits(),ref l),2);
            failed(write::within_length(ref table,old,6,ref mut b,b"",limits(),ref l),2);
            same_usage(ref l,ref reserved);assert(bytes::equal(bytes::view(ref b),ref data[..]));
            assert(bytes::equal(bytes::view(ref discarded)[..6],ref data[..]));
        }
        assert(switch(tx::cancel(ref table,ref mut l,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
        assert(l.engine_used==352 && l.peak==768 && l.engine_peak==800 && l.pending==0 &&
            l.old_capacity==0 && l.new_capacity==0 && l.before_used==0 && l.before_engine_used==0 && !plan.active);
    }
    if(mode!=3){same_usage(ref l,ref usage);}
    assert(bytes::capacity(ref b)==256 && bytes::len(ref b)==if(mode==2){7}else{6});
    var usize i=0;while(i<16){
        if(i!=old.slot || mode!=2){assert(table.slots[i].live==before.slots[i].live && table.slots[i].generation==before.slots[i].generation &&
            table.slots[i].length==before.slots[i].length && table.slots[i].capacity==before.slots[i].capacity);}
        i+=1;
    }
}
