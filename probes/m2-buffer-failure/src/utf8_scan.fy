module utf8_scan;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_replacement as tx;
import buffer_append as append;
import buffer_utf8 as utf8;
import buffer_utf8_scan as scan;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn scan::Cursor started(Result<scan::Cursor,scan::Error> r){
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);
        scan::Cursor{.active=false,.source=owners::Token{.slot=16,.generation=0},.length=0,.capacity=0,.offset=0,.carry=[0;4],.have=0}}};
}
fn void same(ref scan::Cursor a,ref scan::Cursor b){
    assert(a.active==b.active && a.source.slot==b.source.slot && a.source.generation==b.source.generation &&
        a.length==b.length && a.capacity==b.capacity && a.offset==b.offset && a.have==b.have);
    var usize i=0;while(i<4){assert(a.carry[i]==b.carry[i]);i+=1;}
}
fn void same_table(ref owners::Table a,ref owners::Table b){
    var usize i=0;while(i<16){assert(a.slots[i].generation==b.slots[i].generation && a.slots[i].live==b.slots[i].live &&
        a.slots[i].length==b.slots[i].length && a.slots[i].capacity==b.slots[i].capacity);i+=1;}
}
fn void same_usage(ref growth::Ledger a,ref growth::Ledger b){
    assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);
}
fn void rejected(ref owners::Table table,ref bytes::Buffer b,usize budget,ref mut scan::Cursor c,u8 code){
    let scan::Cursor before=*c;
    assert(switch(scan::step(table,b,budget,c)){case .ok(_):{false}case .err(e):{switch(e){
        case .State:{code==1}case .Token:{code==2}case .Utf8:{false}}}});
    same(c,ref before);
}
fn void load(ref mut owners::Table table,owners::Token token,ref mut bytes::Buffer b,ref u8[] input){
    switch(bytes::resize_zeroed(b,0)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(b,input)){case .ok(n):{assert(n==input.len);}case .err(_):{assert(false);}};
    table.slots[token.slot].length=input.len;
}
fn void compare(ref mut owners::Table table,owners::Token token,ref mut bytes::Buffer b,ref u8[] input,bool expected){
    load(table,token,b,input);let owners::Table before=owners::Table{.slots=table.slots};
    assert(switch(utf8::validate(table,token,b)){case .ok(n):{expected && n==input.len}
        case .err(e):{switch(e){case .Utf8:{!expected}case .Token:{false}case .State:{false}}}});
    var usize choice=0;while(choice<6){
        let usize budget=if(choice==5){18446744073709551615}else{choice+1};
        var scan::Cursor cursor=started(scan::begin(table,token,b));var bool accepted=false;var usize calls=0;
        while(cursor.active){
            let scan::Cursor saved=cursor;
            switch(scan::step(table,b,budget,ref mut cursor)){
                case .ok(done):{
                    var usize amount=input.len-saved.offset;if(amount>budget){amount=budget;}if(amount>256){amount=256;}
                    assert(cursor.offset==saved.offset+amount && done==!cursor.active && cursor.have<=3);
                    assert(done || amount>0);accepted=done;
                }
                case .err(e):{
                    assert(switch(e){case .Utf8:{!expected}case .Token:{false}case .State:{false}});
                    var scan::Cursor retired=saved;retired.active=false;same(ref cursor,ref retired);
                }
            };
            calls+=1;assert(calls<=input.len+1);
        }
        assert(accepted==expected);rejected(table,b,1,ref mut cursor,1);
        same_table(table,ref before);assert(bytes::equal(bytes::view(b),input));choice+=1;
    }
}
pub fn void run(u8 mode){
    var growth::Ledger ledger=growth::empty();var bytes::Buffer b=bytes::empty();var owners::Table table=owners::empty();
    if(mode==0){
        let owners::Token empty=switch(owners::create(ref mut table,ref b)){case .ok(v):{v}
            case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
        var scan::Cursor cursor=started(scan::begin(ref table,empty,ref b));
        assert(switch(scan::step(ref table,ref b,1,ref mut cursor)){case .ok(done):{done}case .err(_):{false}});
        assert(cursor.offset==0 && !cursor.active);table=owners::empty();
    }
    let usize capacity=if(mode==0){512}else{256};
    b=switch(storage::prepare_growth(ref b,capacity,limits(),ref mut ledger)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    switch(growth::commit(capacity,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    ledger.engine_used+=32;ledger.engine_peak+=32;
    let owners::Token token=switch(owners::create(ref mut table,ref b)){case .ok(v):{v}
        case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    let growth::Ledger usage=ledger;let u8[4] scalar=[240,159,141,171];
    if(mode==0){
        compare(ref mut table,token,ref mut b,b"",true);
        let u8[29] edges=[194,128,223,191,224,160,128,237,159,191,238,128,128,239,191,191,
            240,144,128,128,244,143,191,191,239,187,191,0,127];
        compare(ref mut table,token,ref mut b,ref edges[..],true);
        let u8[13] mixed=[65,237,149,156,234,184,128,240,159,141,171,0,90];
        compare(ref mut table,token,ref mut b,ref mixed[..],true);
        var u8[259] long=[65;259];long[255]=240;long[256]=159;long[257]=141;long[258]=171;
        compare(ref mut table,token,ref mut b,ref long[..],true);
    }else if(mode==1){
        var usize i=0;var u8 byte=0;while(i<256){let u8[1] one=[byte];
            compare(ref mut table,token,ref mut b,ref one[..],i<128);if(i<255){byte+=1;}i+=1;}
        let u8[2] overlong2=[192,128];compare(ref mut table,token,ref mut b,ref overlong2[..],false);
        let u8[3] overlong3=[224,159,191];compare(ref mut table,token,ref mut b,ref overlong3[..],false);
        let u8[4] overlong4=[240,143,191,191];compare(ref mut table,token,ref mut b,ref overlong4[..],false);
        let u8[3] surrogate=[237,160,128];compare(ref mut table,token,ref mut b,ref surrogate[..],false);
        let u8[4] high=[244,144,128,128];compare(ref mut table,token,ref mut b,ref high[..],false);
        let u8[4] lead=[245,128,128,128];compare(ref mut table,token,ref mut b,ref lead[..],false);
        i=1;while(i<4){compare(ref mut table,token,ref mut b,ref scalar[..i],false);i+=1;}
        let u8[3] short=[226,130,172];compare(ref mut table,token,ref mut b,ref short[..2],false);
        let u8[4] broken=[240,159,0,171];compare(ref mut table,token,ref mut b,ref broken[..],false);
        let u8[3] stray=[65,128,66];compare(ref mut table,token,ref mut b,ref stray[..],false);
        let u8[5] continuations=[128;5];compare(ref mut table,token,ref mut b,ref continuations[..],false);
        let u8[5] tail=[240,159,141,171,255];compare(ref mut table,token,ref mut b,ref tail[..],false);
        compare(ref mut table,token,ref mut b,b"recovered",true);
    }else if(mode==2){
        load(ref mut table,token,ref mut b,ref scalar[..]);var scan::Cursor cursor=started(scan::begin(ref table,token,ref b));
        assert(switch(scan::step(ref table,ref b,1,ref mut cursor)){case .ok(done):{!done}case .err(_):{false}});
        assert(cursor.offset==1 && cursor.have==1);let scan::Cursor saved=cursor;
        let owners::Table before=owners::Table{.slots=table.slots};let bytes::Buffer missing=bytes::empty();
        rejected(ref table,ref b,0,ref mut cursor,1);rejected(ref table,ref missing,1,ref mut cursor,1);
        var usize i=0;while(i<9){
            if(i==0){cursor.active=false;}else if(i==1){cursor.source.slot=16;}else if(i==2){cursor.source.generation+=1;}
            else if(i==3){cursor.length+=1;}else if(i==4){cursor.capacity+=64;}else if(i==5){cursor.offset=18446744073709551615;}
            else if(i==6){cursor.have=4;}else if(i==7){cursor.carry[0]=0;}else{cursor.carry[2]=1;}
            rejected(ref table,ref b,1,ref mut cursor,if(i==1 || i==2){2}else{1});cursor=saved;i+=1;
        }
        table.slots[15].length=1;rejected(ref table,ref b,1,ref mut cursor,1);table=before;
        table.slots[token.slot].length=3;rejected(ref table,ref b,1,ref mut cursor,1);table=before;
        assert(bytes::equal(bytes::view(ref b),ref scalar[..]));same_table(ref table,ref before);
        let owners::Token fresh=switch(append::within_capacity(ref mut table,token,ref mut b,b"!",limits(),ref ledger)){
            case .ok(v):{v}case .err(_):{assert(false);token}};
        rejected(ref table,ref missing,1,ref mut cursor,2);
        table.slots[fresh.slot].generation=18446744073709551615;
        cursor=started(scan::begin(ref table,owners::Token{.slot=fresh.slot,.generation=18446744073709551615},ref b));
        assert(switch(scan::step(ref table,ref b,18446744073709551615,ref mut cursor)){case .ok(done):{done}case .err(_):{false}});
        assert(cursor.offset==5 && !cursor.active && bytes::view(ref b)[4]==33);
    }else{
        load(ref mut table,token,ref mut b,ref scalar[..]);var scan::Cursor cursor=started(scan::begin(ref table,token,ref b));
        assert(switch(scan::step(ref table,ref b,1,ref mut cursor)){case .ok(done):{!done}case .err(_):{false}});
        let owners::Table before=owners::Table{.slots=table.slots};var tx::Plan plan=tx::empty();
        {let bytes::Buffer replacement=switch(tx::prepare_resize(ref table,token,ref b,257,limits(),ref mut ledger,ref mut plan)){
            case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
            let growth::Ledger reserved=ledger;let tx::Plan planned=plan;
            assert(switch(scan::step(ref table,ref b,1,ref mut cursor)){case .ok(done):{!done}case .err(_):{false}});
            assert(cursor.offset==2 && cursor.have==2);rejected(ref table,ref replacement,1,ref mut cursor,1);
            same_usage(ref ledger,ref reserved);same_table(ref table,ref before);
            assert(plan.active==planned.active && plan.length==planned.length && plan.capacity==planned.capacity &&
                plan.source.slot==planned.source.slot && plan.source.generation==planned.source.generation);
            same_usage(ref plan.reserved,ref planned.reserved);same_table(ref plan.before,ref planned.before);
        }
        assert(switch(tx::cancel(ref table,ref mut ledger,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
        assert(switch(scan::step(ref table,ref b,1,ref mut cursor)){case .ok(done):{!done}case .err(_):{false}});
        assert(switch(scan::step(ref table,ref b,1,ref mut cursor)){case .ok(done):{done}case .err(_):{false}});
        assert(cursor.offset==4 && !cursor.active && !plan.active && bytes::equal(bytes::view(ref b),ref scalar[..]));
        same_table(ref table,ref before);
    }
    if(mode!=3){same_usage(ref ledger,ref usage);}else{
        assert(ledger.used==320 && ledger.engine_used==352 && ledger.peak==768 && ledger.engine_peak==800 &&
            ledger.pending==0 && ledger.old_capacity==0 && ledger.new_capacity==0 &&
            ledger.before_used==0 && ledger.before_engine_used==0);
    }
}
