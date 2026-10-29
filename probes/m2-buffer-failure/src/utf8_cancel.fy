module utf8_cancel;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_replacement as tx;
import buffer_utf8_scan as scan;
import buffer_utf8_meter as meter;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn u8 code(meter::ControlError e){return switch(e){case .Cancelled:{1}case .Fuel:{2}case .Token:{3}case .State:{4}case .Utf8:{5}};}
fn scan::Cursor started(Result<scan::Cursor,meter::ControlError> r){
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
fn void begin_failed(Result<scan::Cursor,meter::ControlError> r,u8 expected){
    assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});
}
fn void rejected(bool cancel,ref owners::Table table,ref bytes::Buffer b,usize budget,
    ref mut scan::Cursor cursor,ref mut usize fuel,u8 expected){
    let scan::Cursor before=*cursor;let usize prior=*fuel;
    assert(switch(meter::step_cancellable(cancel,table,b,budget,cursor,fuel)){
        case .ok(_):{false}case .err(e):{code(e)==expected}});
    assert(*fuel==if(expected==1 || expected==2){prior}else{prior-meter::step_cost(budget)});
    if(expected==1 || expected==5){var scan::Cursor retired=before;retired.active=false;same(cursor,ref retired);}else{same(cursor,ref before);}
}
fn void advanced(ref owners::Table table,ref bytes::Buffer b,ref mut scan::Cursor cursor,ref mut usize fuel,bool expected){
    let usize prior=*fuel;
    assert(switch(meter::step_cancellable(false,table,b,1,cursor,fuel)){
        case .ok(done):{done==expected}case .err(_):{false}});
    assert(*fuel==prior-132);
}
fn void load(ref mut owners::Table table,owners::Token token,ref mut bytes::Buffer b,ref u8[] input){
    switch(bytes::resize_zeroed(b,0)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(b,input)){case .ok(n):{assert(n==input.len);}case .err(_):{assert(false);}};
    table.slots[token.slot].length=input.len;
}
pub fn void run(u8 mode){
    var growth::Ledger ledger=growth::empty();var bytes::Buffer b=bytes::empty();var owners::Table table=owners::empty();
    b=switch(storage::prepare_growth(ref b,256,limits(),ref mut ledger)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    switch(growth::commit(256,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    ledger.engine_used+=32;ledger.engine_peak+=32;
    let owners::Token token=switch(owners::create(ref mut table,ref b)){case .ok(v):{v}
        case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    let growth::Ledger usage=ledger;let u8[4] scalar=[240,159,141,171];
    if(mode==0){
        let owners::Table before=owners::Table{.slots=table.slots};let bytes::Buffer missing=bytes::empty();var usize fuel=0;
        begin_failed(meter::begin_cancellable(true,ref table,owners::Token{.slot=16,.generation=0},ref missing,ref mut fuel),1);assert(fuel==0);
        fuel=18446744073709551615;begin_failed(meter::begin_cancellable(true,ref table,token,ref b,ref mut fuel),1);
        assert(fuel==18446744073709551615);
        fuel=128;var scan::Cursor cursor=started(meter::begin_cancellable(false,ref table,token,ref b,ref mut fuel));assert(fuel==0);
        rejected(true,ref table,ref b,18446744073709551615,ref mut cursor,ref mut fuel,1);
        assert(cursor.offset==0 && !cursor.active);
        fuel=260;cursor=started(meter::begin_cancellable(false,ref table,token,ref b,ref mut fuel));
        advanced(ref table,ref b,ref mut cursor,ref mut fuel,true);assert(fuel==0);
        rejected(true,ref table,ref b,0,ref mut cursor,ref mut fuel,1);
        same_table(ref table,ref before);assert(bytes::len(ref b)==0 && bytes::capacity(ref b)==256);
    }else if(mode==1){
        load(ref mut table,token,ref mut b,ref scalar[..]);let owners::Table before=owners::Table{.slots=table.slots};
        var usize split=1;while(split<4){
            var usize fuel=128+132*split;var scan::Cursor cursor=started(meter::begin_cancellable(false,ref table,token,ref b,ref mut fuel));
            var usize i=0;while(i<split){advanced(ref table,ref b,ref mut cursor,ref mut fuel,false);i+=1;}
            assert(fuel==0 && cursor.offset==split && cursor.have==split);
            rejected(true,ref table,ref b,18446744073709551615,ref mut cursor,ref mut fuel,1);
            rejected(true,ref table,ref b,0,ref mut cursor,ref mut fuel,1);
            fuel=132;rejected(false,ref table,ref b,1,ref mut cursor,ref mut fuel,4);assert(fuel==0);split+=1;
        }
        var usize fuel=656;var scan::Cursor cursor=started(meter::begin_cancellable(false,ref table,token,ref b,ref mut fuel));
        var usize i=0;while(i<4){advanced(ref table,ref b,ref mut cursor,ref mut fuel,i==3);i+=1;}
        assert(fuel==0 && cursor.offset==4 && !cursor.active);same_table(ref table,ref before);
        assert(bytes::equal(bytes::view(ref b),ref scalar[..]));
    }else if(mode==2){
        load(ref mut table,token,ref mut b,ref scalar[..]);let owners::Table before=owners::Table{.slots=table.slots};
        let bytes::Buffer missing=bytes::empty();let owners::Token invalid=owners::Token{.slot=16,.generation=0};var usize fuel=127;
        begin_failed(meter::begin_cancellable(false,ref table,invalid,ref missing,ref mut fuel),2);assert(fuel==127);
        fuel=128;begin_failed(meter::begin_cancellable(false,ref table,invalid,ref missing,ref mut fuel),3);assert(fuel==0);
        fuel=128;begin_failed(meter::begin_cancellable(false,ref table,token,ref missing,ref mut fuel),4);assert(fuel==0);
        fuel=128;var scan::Cursor cursor=started(meter::begin_cancellable(false,ref table,token,ref b,ref mut fuel));
        let scan::Cursor saved=cursor;cursor.source=invalid;fuel=131;rejected(false,ref table,ref missing,1,ref mut cursor,ref mut fuel,2);
        fuel=132;rejected(false,ref table,ref missing,1,ref mut cursor,ref mut fuel,3);assert(fuel==0);
        cursor.offset=18446744073709551615;rejected(true,ref table,ref missing,0,ref mut cursor,ref mut fuel,1);
        cursor=saved;fuel=132;rejected(false,ref table,ref missing,1,ref mut cursor,ref mut fuel,4);assert(fuel==0);
        cursor.offset=18446744073709551615;fuel=132;rejected(false,ref table,ref b,1,ref mut cursor,ref mut fuel,4);assert(fuel==0);cursor=saved;
        fuel=128;rejected(false,ref table,ref b,0,ref mut cursor,ref mut fuel,4);assert(fuel==0);
        let u8[4] broken=[240,159,0,171];load(ref mut table,token,ref mut b,ref broken[..]);
        fuel=392;cursor=started(meter::begin_cancellable(false,ref table,token,ref b,ref mut fuel));
        advanced(ref table,ref b,ref mut cursor,ref mut fuel,false);advanced(ref table,ref b,ref mut cursor,ref mut fuel,false);
        assert(fuel==0 && cursor.offset==2);rejected(true,ref table,ref b,1,ref mut cursor,ref mut fuel,1);
        fuel=524;cursor=started(meter::begin_cancellable(false,ref table,token,ref b,ref mut fuel));
        advanced(ref table,ref b,ref mut cursor,ref mut fuel,false);advanced(ref table,ref b,ref mut cursor,ref mut fuel,false);
        rejected(false,ref table,ref b,1,ref mut cursor,ref mut fuel,5);assert(fuel==0 && cursor.offset==2);
        same_table(ref table,ref before);assert(bytes::equal(bytes::view(ref b),ref broken[..]));
    }else{
        load(ref mut table,token,ref mut b,ref scalar[..]);let owners::Table before=owners::Table{.slots=table.slots};
        var usize fuel=392;var scan::Cursor cursor=started(meter::begin_cancellable(false,ref table,token,ref b,ref mut fuel));
        advanced(ref table,ref b,ref mut cursor,ref mut fuel,false);var tx::Plan plan=tx::empty();
        {let bytes::Buffer replacement=switch(tx::prepare_resize(ref table,token,ref b,257,limits(),ref mut ledger,ref mut plan)){
            case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
            let growth::Ledger reserved=ledger;let tx::Plan planned=plan;
            advanced(ref table,ref b,ref mut cursor,ref mut fuel,false);assert(fuel==0 && cursor.offset==2);
            rejected(true,ref table,ref replacement,18446744073709551615,ref mut cursor,ref mut fuel,1);
            assert(!cursor.active && plan.active);same_usage(ref ledger,ref reserved);same_table(ref table,ref before);
            assert(plan.active==planned.active && plan.length==planned.length && plan.capacity==planned.capacity &&
                plan.source.slot==planned.source.slot && plan.source.generation==planned.source.generation);
            same_usage(ref plan.reserved,ref planned.reserved);same_table(ref plan.before,ref planned.before);
            assert(bytes::equal(bytes::view(ref replacement)[..4],ref scalar[..]));
        }
        assert(switch(tx::cancel(ref table,ref mut ledger,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
        fuel=132;rejected(false,ref table,ref b,1,ref mut cursor,ref mut fuel,4);assert(fuel==0 && !plan.active);
        fuel=656;cursor=started(meter::begin_cancellable(false,ref table,token,ref b,ref mut fuel));
        var usize i=0;while(i<4){advanced(ref table,ref b,ref mut cursor,ref mut fuel,i==3);i+=1;}
        assert(fuel==0 && cursor.offset==4);same_table(ref table,ref before);assert(bytes::equal(bytes::view(ref b),ref scalar[..]));
    }
    if(mode!=3){same_usage(ref ledger,ref usage);}else{
        assert(ledger.used==320 && ledger.engine_used==352 && ledger.peak==768 && ledger.engine_peak==800 &&
            ledger.pending==0 && ledger.old_capacity==0 && ledger.new_capacity==0 &&
            ledger.before_used==0 && ledger.before_engine_used==0);
    }
}
