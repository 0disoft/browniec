module copy_out;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_replacement as tx;
import buffer_append as append;

fn growth::Limits limits() {return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn void count(Result<usize,owners::Error> r,usize expected) {
    assert(switch(r){case .ok(n):{n==expected}case .err(_):{false}});
}
fn void failed(Result<usize,owners::Error> r,u8 expected) {
    assert(switch(r){case .ok(_):{false}case .err(e):{switch(e){
        case .Token:{expected==1}case .State:{expected==2}case .Bounds:{expected==3}case .Owners:{false}}}});
}
fn void untouched(ref u8[] output) {var usize i=0;while(i<output.len){assert(output[i]==90);i+=1;}}
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
    var u8[10] output=[90;10];
    if(mode==0) {
        count(owners::copy_out(ref table,old,0,ref b,ref mut output[2..8]),6);
        assert(bytes::equal(ref output[2..8],ref data[..]));
        untouched(ref output[..2]);untouched(ref output[8..]);
        output=[90;10];
        count(owners::copy_out(ref table,old,1,ref b,ref mut output[3..6]),3);
        assert(output[3]==0 && output[4]==255 && output[5]==128);
        untouched(ref output[..3]);untouched(ref output[6..]);
        count(owners::copy_out(ref table,old,6,ref b,ref mut output[4..4]),0);
    }else if(mode==1) {
        failed(owners::copy_out(ref table,old,18446744073709551615,ref b,ref mut output[..1]),3);
        failed(owners::copy_out(ref table,old,7,ref b,ref mut output[..0]),3);
        failed(owners::copy_out(ref table,old,6,ref b,ref mut output[..1]),3);
        failed(owners::copy_out(ref table,old,5,ref b,ref mut output[..2]),3);
        failed(owners::copy_out(ref table,old,0,ref b,ref mut output[..7]),3);
        count(owners::copy_out(ref table,old,6,ref b,ref mut output[..0]),0);
        count(owners::copy_out(ref table,old,0,ref b,ref mut output[..0]),0);
        untouched(ref output[..]);
    }else if(mode==2) {
        let bytes::Buffer missing=bytes::empty();
        failed(owners::copy_out(ref table,owners::Token{.slot=16,.generation=0},0,ref missing,ref mut output[..0]),1);
        failed(owners::copy_out(ref table,old,0,ref missing,ref mut output[..1]),2);
        table.slots[15].length=1;
        failed(owners::copy_out(ref table,old,0,ref b,ref mut output[..1]),2);table.slots[15].length=0;
        untouched(ref output[..]);
        let owners::Token fresh=switch(append::within_capacity(ref mut table,old,ref mut b,b"!",limits(),ref l)) {
            case .ok(v):{v}case .err(_):{assert(false);old}
        };
        failed(owners::copy_out(ref table,old,0,ref missing,ref mut output[..1]),1);untouched(ref output[..]);
        count(owners::copy_out(ref table,fresh,6,ref b,ref mut output[4..5]),1);assert(output[4]==33);output[4]=90;
        table.slots[old.slot].generation=18446744073709551615;
        let owners::Token last=owners::Token{.slot=old.slot,.generation=18446744073709551615};
        count(owners::copy_out(ref table,last,0,ref b,ref mut output[2..8]),6);
        assert(bytes::equal(ref output[2..8],ref data[..]) && table.slots[last.slot].generation==last.generation);
        untouched(ref output[..2]);untouched(ref output[8..]);
    }else{
        var tx::Plan plan=tx::empty();
        {let bytes::Buffer discarded=switch(tx::prepare_resize(ref table,old,ref b,257,limits(),ref mut l,ref mut plan)) {
            case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
        };
            assert(bytes::len(ref discarded)==257 && plan.active && l.used==768 && l.engine_used==800);
            let growth::Ledger reserved=l;
            count(owners::copy_out(ref table,old,0,ref b,ref mut output[2..8]),6);
            assert(bytes::equal(ref output[2..8],ref data[..]));untouched(ref output[..2]);untouched(ref output[8..]);
            failed(owners::copy_out(ref table,old,6,ref b,ref mut output[..1]),3);untouched(ref output[..2]);
            same_usage(ref l,ref reserved);
        }
        assert(switch(tx::cancel(ref table,ref mut l,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
        assert(l.engine_used==352 && l.peak==768 && l.engine_peak==800 && l.pending==0 &&
            l.old_capacity==0 && l.new_capacity==0 && l.before_used==0 && l.before_engine_used==0 && !plan.active);
        count(owners::copy_out(ref table,old,0,ref b,ref mut output[2..8]),6);
    }
    if(mode!=3){same_usage(ref l,ref usage);}
    assert(bytes::capacity(ref b)==256 && bytes::len(ref b)==if(mode==2){7}else{6});
    assert(bytes::equal(bytes::view(ref b)[..6],ref data[..]));
    var usize i=0;while(i<16){
        if(i!=old.slot || mode!=2){assert(table.slots[i].live==before.slots[i].live && table.slots[i].generation==before.slots[i].generation &&
            table.slots[i].length==before.slots[i].length && table.slots[i].capacity==before.slots[i].capacity);}
        i+=1;
    }
}
