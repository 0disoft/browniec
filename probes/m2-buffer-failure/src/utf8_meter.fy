module utf8_meter;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_replacement as tx;
import buffer_utf8_scan as scan;
import buffer_utf8_meter as meter;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn scan::Cursor started(Result<scan::Cursor,meter::Error> r){
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);
        scan::Cursor{.active=false,.source=owners::Token{.slot=16,.generation=0},.length=0,.capacity=0,.offset=0,.carry=[0;4],.have=0}}};
}
fn u8 code(meter::Error e){return switch(e){case .Fuel:{1}case .Token:{2}case .State:{3}case .Utf8:{4}};}
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
fn void begin_failed(Result<scan::Cursor,meter::Error> r,u8 expected){
    assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});
}
fn void rejected(ref owners::Table table,ref bytes::Buffer b,usize budget,
    ref mut scan::Cursor cursor,ref mut usize fuel,u8 expected){
    let scan::Cursor before=*cursor;let usize prior=*fuel;
    assert(switch(meter::step(table,b,budget,cursor,fuel)){case .ok(_):{false}case .err(e):{code(e)==expected}});
    assert(*fuel==if(expected==1){prior}else{prior-meter::step_cost(budget)});
    if(expected==4){var scan::Cursor retired=before;retired.active=false;same(cursor,ref retired);}else{same(cursor,ref before);}
}
fn void advanced(ref owners::Table table,ref bytes::Buffer b,usize budget,
    ref mut scan::Cursor cursor,ref mut usize fuel,bool expected){
    let usize before=*fuel;
    assert(switch(meter::step(table,b,budget,cursor,fuel)){case .ok(done):{done==expected}case .err(_):{false}});
    assert(*fuel==before-meter::step_cost(budget));
}
fn void load(ref mut owners::Table table,owners::Token token,ref mut bytes::Buffer b,ref u8[] input){
    switch(bytes::resize_zeroed(b,0)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(b,input)){case .ok(n):{assert(n==input.len);}case .err(_):{assert(false);}};
    table.slots[token.slot].length=input.len;
}
pub fn void run(u8 mode){
    assert(meter::begin_cost()==128 && meter::step_cost(0)==128 && meter::step_cost(1)==132 &&
        meter::step_cost(256)==1152 && meter::step_cost(257)==1152 && meter::step_cost(18446744073709551615)==1152);
    var growth::Ledger ledger=growth::empty();var bytes::Buffer b=bytes::empty();var owners::Table table=owners::empty();
    if(mode==0){
        let owners::Token empty=switch(owners::create(ref mut table,ref b)){case .ok(v):{v}
            case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
        var usize fuel=260;var scan::Cursor cursor=started(meter::begin(ref table,empty,ref b,ref mut fuel));
        assert(fuel==132);advanced(ref table,ref b,1,ref mut cursor,ref mut fuel,true);
        assert(fuel==0 && cursor.offset==0 && !cursor.active);table=owners::empty();
    }
    let usize capacity=if(mode==0){512}else{256};
    b=switch(storage::prepare_growth(ref b,capacity,limits(),ref mut ledger)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    switch(growth::commit(capacity,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    ledger.engine_used+=32;ledger.engine_peak+=32;
    let owners::Token token=switch(owners::create(ref mut table,ref b)){case .ok(v):{v}
        case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    let growth::Ledger usage=ledger;let u8[4] scalar=[240,159,141,171];
    if(mode==0){
        var u8[259] long=[65;259];long[255]=240;long[256]=159;long[257]=141;long[258]=171;
        load(ref mut table,token,ref mut b,ref long[..]);let owners::Table before=owners::Table{.slots=table.slots};
        var usize fuel=1427;var scan::Cursor cursor=started(meter::begin(ref table,token,ref b,ref mut fuel));
        assert(fuel==1299);advanced(ref table,ref b,18446744073709551615,ref mut cursor,ref mut fuel,false);
        assert(cursor.offset==256 && cursor.have==1 && fuel==147);
        advanced(ref table,ref b,3,ref mut cursor,ref mut fuel,true);assert(cursor.offset==259 && fuel==7);
        fuel=34316;cursor=started(meter::begin(ref table,token,ref b,ref mut fuel));
        var usize calls=0;while(cursor.active){advanced(ref table,ref b,1,ref mut cursor,ref mut fuel,calls==258);calls+=1;}
        assert(calls==259 && cursor.offset==259 && fuel==0);
        same_table(ref table,ref before);assert(bytes::equal(bytes::view(ref b),ref long[..]));
    }else if(mode==1){
        load(ref mut table,token,ref mut b,ref scalar[..]);let owners::Table before=owners::Table{.slots=table.slots};
        let bytes::Buffer missing=bytes::empty();var usize fuel=127;
        begin_failed(meter::begin(ref table,owners::Token{.slot=16,.generation=0},ref missing,ref mut fuel),1);assert(fuel==127);
        fuel=128;var scan::Cursor cursor=started(meter::begin(ref table,token,ref b,ref mut fuel));assert(fuel==0);
        rejected(ref table,ref b,1,ref mut cursor,ref mut fuel,1);
        fuel=131;rejected(ref table,ref b,1,ref mut cursor,ref mut fuel,1);
        fuel=132;advanced(ref table,ref b,1,ref mut cursor,ref mut fuel,false);assert(cursor.offset==1 && cursor.have==1 && fuel==0);
        fuel=131;rejected(ref table,ref b,1,ref mut cursor,ref mut fuel,1);
        fuel=1151;rejected(ref table,ref b,18446744073709551615,ref mut cursor,ref mut fuel,1);
        fuel=18446744073709551615;advanced(ref table,ref b,18446744073709551615,ref mut cursor,ref mut fuel,true);
        assert(fuel==18446744073709550463 && cursor.offset==4 && !cursor.active);
        fuel=131;rejected(ref table,ref b,1,ref mut cursor,ref mut fuel,1);
        fuel=132;rejected(ref table,ref b,1,ref mut cursor,ref mut fuel,3);assert(fuel==0);
        same_table(ref table,ref before);assert(bytes::equal(bytes::view(ref b),ref scalar[..]));
    }else if(mode==2){
        load(ref mut table,token,ref mut b,ref scalar[..]);let owners::Table before=owners::Table{.slots=table.slots};
        let bytes::Buffer missing=bytes::empty();var usize fuel=128;
        begin_failed(meter::begin(ref table,owners::Token{.slot=16,.generation=0},ref missing,ref mut fuel),2);assert(fuel==0);
        fuel=128;begin_failed(meter::begin(ref table,token,ref missing,ref mut fuel),3);assert(fuel==0);
        fuel=128;var scan::Cursor cursor=started(meter::begin(ref table,token,ref b,ref mut fuel));
        let scan::Cursor saved=cursor;
        fuel=128;rejected(ref table,ref b,0,ref mut cursor,ref mut fuel,3);assert(fuel==0);
        cursor.source.slot=16;fuel=132;rejected(ref table,ref missing,1,ref mut cursor,ref mut fuel,2);assert(fuel==0);cursor=saved;
        cursor.offset=18446744073709551615;fuel=132;rejected(ref table,ref b,1,ref mut cursor,ref mut fuel,3);assert(fuel==0);cursor=saved;
        table.slots[15].length=1;fuel=132;rejected(ref table,ref b,1,ref mut cursor,ref mut fuel,3);assert(fuel==0);table=before;
        fuel=132;rejected(ref table,ref missing,1,ref mut cursor,ref mut fuel,3);assert(fuel==0);
        let u8[4] broken=[240,159,0,171];load(ref mut table,token,ref mut b,ref broken[..]);
        fuel=128;cursor=started(meter::begin(ref table,token,ref b,ref mut fuel));
        fuel=132;advanced(ref table,ref b,1,ref mut cursor,ref mut fuel,false);
        fuel=132;advanced(ref table,ref b,1,ref mut cursor,ref mut fuel,false);
        assert(cursor.offset==2 && cursor.have==2);fuel=132;rejected(ref table,ref b,1,ref mut cursor,ref mut fuel,4);assert(fuel==0);
        same_table(ref table,ref before);assert(bytes::equal(bytes::view(ref b),ref broken[..]));
        let u8[1] truncated=[240];load(ref mut table,token,ref mut b,ref truncated[..]);
        fuel=128;cursor=started(meter::begin(ref table,token,ref b,ref mut fuel));
        fuel=132;rejected(ref table,ref b,1,ref mut cursor,ref mut fuel,4);assert(fuel==0 && cursor.offset==0);
        assert(bytes::equal(bytes::view(ref b),ref truncated[..]));
    }else{
        load(ref mut table,token,ref mut b,ref scalar[..]);let owners::Table before=owners::Table{.slots=table.slots};
        var usize fuel=788;var scan::Cursor cursor=started(meter::begin(ref table,token,ref b,ref mut fuel));
        advanced(ref table,ref b,1,ref mut cursor,ref mut fuel,false);
        var tx::Plan plan=tx::empty();
        {let bytes::Buffer replacement=switch(tx::prepare_resize(ref table,token,ref b,257,limits(),ref mut ledger,ref mut plan)){
            case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
            let growth::Ledger reserved=ledger;let tx::Plan planned=plan;
            advanced(ref table,ref b,1,ref mut cursor,ref mut fuel,false);
            assert(cursor.offset==2 && cursor.have==2);rejected(ref table,ref replacement,1,ref mut cursor,ref mut fuel,3);
            same_usage(ref ledger,ref reserved);same_table(ref table,ref before);
            assert(plan.active==planned.active && plan.length==planned.length && plan.capacity==planned.capacity &&
                plan.source.slot==planned.source.slot && plan.source.generation==planned.source.generation);
            same_usage(ref plan.reserved,ref planned.reserved);same_table(ref plan.before,ref planned.before);
        }
        assert(switch(tx::cancel(ref table,ref mut ledger,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
        advanced(ref table,ref b,1,ref mut cursor,ref mut fuel,false);advanced(ref table,ref b,1,ref mut cursor,ref mut fuel,true);
        assert(fuel==0 && cursor.offset==4 && !cursor.active && !plan.active && bytes::equal(bytes::view(ref b),ref scalar[..]));
        same_table(ref table,ref before);
    }
    if(mode!=3){same_usage(ref ledger,ref usage);}else{
        assert(ledger.used==320 && ledger.engine_used==352 && ledger.peak==768 && ledger.engine_peak==800 &&
            ledger.pending==0 && ledger.old_capacity==0 && ledger.new_capacity==0 &&
            ledger.before_used==0 && ledger.before_engine_used==0);
    }
}
