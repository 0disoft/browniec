module utf8;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_replacement as tx;
import buffer_append as append;
import buffer_utf8 as utf8;

fn growth::Limits limits() {return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn void count(Result<usize,utf8::Error> r,usize expected) {
    assert(switch(r){case .ok(n):{n==expected}case .err(_):{false}});
}
fn void failed(Result<usize,utf8::Error> r,u8 expected) {
    assert(switch(r){case .ok(_):{false}case .err(e):{switch(e){
        case .Token:{expected==1}case .State:{expected==2}case .Utf8:{expected==3}}}});
}
fn void same_table(ref owners::Table a,ref owners::Table b) {
    var usize i=0;while(i<16) {
        assert(a.slots[i].generation==b.slots[i].generation && a.slots[i].live==b.slots[i].live &&
            a.slots[i].length==b.slots[i].length && a.slots[i].capacity==b.slots[i].capacity);i+=1;
    }
}
fn void same_usage(ref growth::Ledger a,ref growth::Ledger b) {
    assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);
}
// Caller-trusted fixture loading; every check snapshots the final descriptor.
fn void check(ref mut owners::Table table,owners::Token token,ref mut bytes::Buffer b,ref u8[] input,bool valid) {
    switch(bytes::resize_zeroed(b,0)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(b,input)){case .ok(n):{assert(n==input.len);}case .err(_):{assert(false);}};
    table.slots[token.slot].length=input.len;let owners::Table before=owners::Table{.slots=table.slots};
    if(valid){count(utf8::validate(table,token,b),input.len);}else{failed(utf8::validate(table,token,b),3);}
    same_table(table,ref before);assert(bytes::equal(bytes::view(b),input) && bytes::capacity(b)==256);
}
pub fn void run(u8 mode) {
    var growth::Ledger ledger=growth::empty();var bytes::Buffer b=bytes::empty();
    var owners::Table table=owners::empty();
    if(mode==0) {
        let owners::Token empty=switch(owners::create(ref mut table,ref b)) {
            case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}
        };
        count(utf8::validate(ref table,empty,ref b),0);table=owners::empty();
    }
    b=switch(storage::prepare_growth(ref b,256,limits(),ref mut ledger)) {
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    switch(growth::commit(256,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    ledger.engine_used+=32;ledger.engine_peak+=32;
    let owners::Token token=switch(owners::create(ref mut table,ref b)) {
        case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}
    };
    let growth::Ledger usage=ledger;
    if(mode==0) {
        check(ref mut table,token,ref mut b,b"",true);
        let u8[128] ascii=[0;128];var u8[128] all=ascii;
        var usize i=0;var u8 byte=0;while(i<128){all[i]=byte;byte+=1;i+=1;}
        check(ref mut table,token,ref mut b,ref all[..],true);
        let u8[29] boundaries=[194,128,223,191,224,160,128,237,159,191,238,128,128,239,191,191,
            240,144,128,128,244,143,191,191,239,187,191,0,127];
        check(ref mut table,token,ref mut b,ref boundaries[..],true);
        let u8[13] mixed=[65,237,149,156,234,184,128,240,159,141,171,0,90];
        check(ref mut table,token,ref mut b,ref mixed[..],true);
        let u8[256] full=[65;256];check(ref mut table,token,ref mut b,ref full[..],true);
    }else if(mode==1) {
        // Every isolated byte, including all continuation and illegal lead bytes.
        var usize i=0;var u8 byte=0;while(i<256){let u8[1] one=[byte];
            check(ref mut table,token,ref mut b,ref one[..],i<128);if(i<255){byte+=1;}i+=1;}
        let u8[2] overlong2=[192,128];check(ref mut table,token,ref mut b,ref overlong2[..],false);
        let u8[3] overlong3=[224,159,191];check(ref mut table,token,ref mut b,ref overlong3[..],false);
        let u8[4] overlong4=[240,143,191,191];check(ref mut table,token,ref mut b,ref overlong4[..],false);
        let u8[3] surrogate=[237,160,128];check(ref mut table,token,ref mut b,ref surrogate[..],false);
        let u8[3] last_surrogate=[237,191,191];check(ref mut table,token,ref mut b,ref last_surrogate[..],false);
        let u8[4] above_max=[244,144,128,128];check(ref mut table,token,ref mut b,ref above_max[..],false);
        let u8[4] illegal=[245,128,128,128];check(ref mut table,token,ref mut b,ref illegal[..],false);
        let u8[4] sequence=[240,159,141,171];
        i=1;while(i<4){check(ref mut table,token,ref mut b,ref sequence[..i],false);i+=1;}
        let u8[2] short3=[226,130];check(ref mut table,token,ref mut b,ref short3[..],false);
        let u8[3] broken=[226,0,172];check(ref mut table,token,ref mut b,ref broken[..],false);
        let u8[4] tail=[65,66,67,255];check(ref mut table,token,ref mut b,ref tail[..],false);
        check(ref mut table,token,ref mut b,b"recovered",true);
        // A previous successful result must not authorize newly corrupted content.
        switch(owners::write(ref table,token,8,255,ref mut b)){case .ok(_):{}case .err(_):{assert(false);}};
        let owners::Table before=owners::Table{.slots=table.slots};
        failed(utf8::validate(ref table,token,ref b),3);same_table(ref table,ref before);
        assert(bytes::view(ref b)[8]==255);
    }else if(mode==2) {
        check(ref mut table,token,ref mut b,b"valid",true);
        let owners::Table before=owners::Table{.slots=table.slots};let bytes::Buffer missing=bytes::empty();
        failed(utf8::validate(ref table,owners::Token{.slot=16,.generation=0},ref missing),1);
        failed(utf8::validate(ref table,token,ref missing),2);
        table.slots[15].length=1;failed(utf8::validate(ref table,token,ref b),2);table=before;
        table.slots[token.slot].length=4;failed(utf8::validate(ref table,token,ref b),2);table=before;
        table.slots[token.slot].capacity=320;failed(utf8::validate(ref table,token,ref b),2);table=before;
        same_table(ref table,ref before);assert(bytes::equal(bytes::view(ref b),b"valid"));
        let owners::Token fresh=switch(append::within_capacity(ref mut table,token,ref mut b,b"!",limits(),ref ledger)) {
            case .ok(v):{v}case .err(_):{assert(false);token}
        };
        failed(utf8::validate(ref table,token,ref missing),1);count(utf8::validate(ref table,fresh,ref b),6);
        table.slots[fresh.slot].generation=18446744073709551615;
        count(utf8::validate(ref table,owners::Token{.slot=fresh.slot,.generation=18446744073709551615},ref b),6);
        assert(bytes::equal(bytes::view(ref b),b"valid!"));
    }else{
        check(ref mut table,token,ref mut b,b"old",true);
        let owners::Table before=owners::Table{.slots=table.slots};var tx::Plan plan=tx::empty();
        {var bytes::Buffer replacement=switch(tx::prepare_resize(ref table,token,ref b,257,limits(),ref mut ledger,ref mut plan)) {
            case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
        };
            let growth::Ledger reserved=ledger;
            count(utf8::validate(ref table,token,ref b),3);
            // The old token cannot identify the replacement, even if its text is valid.
            failed(utf8::validate(ref table,token,ref replacement),2);
            let u8[1] invalid=[255];
            assert(switch(tx::write_prepared(ref table,ref mut replacement,0,ref invalid[..],limits(),ref ledger,ref plan)) {
                case .ok(n):{n==1}case .err(_):{false}});
            count(utf8::validate(ref table,token,ref b),3);
            assert(bytes::view(ref replacement)[0]==255 && plan.active && plan.length==257 && plan.capacity==384);
            same_usage(ref ledger,ref reserved);same_table(ref table,ref before);
        }
        assert(switch(tx::cancel(ref table,ref mut ledger,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
        count(utf8::validate(ref table,token,ref b),3);same_table(ref table,ref before);
        assert(bytes::equal(bytes::view(ref b),b"old") && !plan.active);
    }
    if(mode!=3){same_usage(ref ledger,ref usage);}else{
        assert(ledger.used==320 && ledger.engine_used==352 && ledger.peak==768 && ledger.engine_peak==800 &&
            ledger.pending==0 && ledger.old_capacity==0 && ledger.new_capacity==0 &&
            ledger.before_used==0 && ledger.before_engine_used==0);
    }
}
