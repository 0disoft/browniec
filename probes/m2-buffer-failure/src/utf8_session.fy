module utf8_session;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_utf8_meter as meter;
import buffer_utf8_session as sessions;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn u8 code(meter::ControlError e){return switch(e){case .Cancelled:{1}case .Fuel:{2}case .Token:{3}case .State:{4}case .Utf8:{5}};}
fn sessions::Session started(Result<sessions::Session,meter::ControlError> r){
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);sessions::empty()}};
}
fn void same(ref sessions::Session a,ref sessions::Session b){
    assert(a.held==b.held && a.source.slot==b.source.slot && a.source.generation==b.source.generation &&
        a.cursor.active==b.cursor.active && a.cursor.source.slot==b.cursor.source.slot && a.cursor.source.generation==b.cursor.source.generation &&
        a.cursor.offset==b.cursor.offset && a.cursor.length==b.cursor.length && a.cursor.capacity==b.cursor.capacity && a.cursor.have==b.cursor.have);
    var usize i=0;while(i<4){assert(a.cursor.carry[i]==b.cursor.carry[i]);i+=1;}
}
fn void same_table(ref owners::Table a,ref owners::Table b){
    var usize i=0;while(i<16){assert(a.slots[i].generation==b.slots[i].generation && a.slots[i].live==b.slots[i].live &&
        a.slots[i].length==b.slots[i].length && a.slots[i].capacity==b.slots[i].capacity && a.slots[i].reading==b.slots[i].reading);i+=1;}
}
fn void same_usage(ref growth::Ledger a,ref growth::Ledger b){
    assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);
}
fn void begin_failed(Result<sessions::Session,meter::ControlError> r,u8 expected){
    assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});
}
fn void failed(Result<bool,meter::ControlError> r,u8 expected){
    assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});
}
fn void advanced(ref mut owners::Table table,ref bytes::Buffer b,usize budget,
    ref mut sessions::Session session,ref mut usize fuel,bool expected){
    let usize prior=*fuel;
    assert(switch(sessions::step(false,table,b,budget,session,fuel)){case .ok(done):{done==expected}case .err(_):{false}});
    assert(*fuel==prior-sessions::step_cost(budget));
}
fn void abandoned(ref mut owners::Table table,ref mut sessions::Session session){
    assert(switch(sessions::abandon(table,session)){case .ok(n):{n==0}case .err(_):{false}});
    assert(!session.held && !session.cursor.active);
}
fn void load(ref mut owners::Table table,owners::Token token,ref mut bytes::Buffer b,ref u8[] input){
    switch(bytes::resize_zeroed(b,0)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(b,input)){case .ok(n):{assert(n==input.len);}case .err(_):{assert(false);}};
    table.slots[token.slot].length=input.len;
}
pub fn void run(u8 mode){
    assert(sessions::begin_cost()==256 && sessions::step_cost(0)==256 && sessions::step_cost(1)==260 &&
        sessions::step_cost(256)==1280 && sessions::step_cost(18446744073709551615)==1280);
    var growth::Ledger ledger=growth::empty();var bytes::Buffer b=bytes::empty();var owners::Table table=owners::empty();
    if(mode==0){
        let owners::Token empty=switch(owners::create(ref mut table,ref b)){case .ok(v):{v}
            case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
        var usize fuel=516;var sessions::Session session=started(sessions::begin(false,ref mut table,empty,ref b,ref ledger,ref mut fuel));
        assert(session.held && table.slots[empty.slot].reading && fuel==260);
        advanced(ref mut table,ref b,1,ref mut session,ref mut fuel,true);
        assert(fuel==0 && !session.held && !table.slots[empty.slot].reading);table=owners::empty();
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
        var usize fuel=1811;var sessions::Session session=started(sessions::begin(false,ref mut table,token,ref b,ref ledger,ref mut fuel));
        assert(fuel==1555 && session.held && table.slots[token.slot].reading);
        assert(switch(owners::write(ref table,token,0,255,ref mut b)){case .ok(_):{false}case .err(_):{true}});
        advanced(ref mut table,ref b,18446744073709551615,ref mut session,ref mut fuel,false);
        assert(session.cursor.offset==256 && session.cursor.have==1 && fuel==275 && session.held);
        advanced(ref mut table,ref b,3,ref mut session,ref mut fuel,true);
        assert(fuel==7 && session.cursor.offset==259 && !session.held && !session.cursor.active);
        same_table(ref table,ref before);assert(bytes::equal(bytes::view(ref b),ref long[..]));
        assert(switch(owners::write(ref table,token,0,66,ref mut b)){case .ok(n):{n==0}case .err(_):{false}});
        assert(bytes::view(ref b)[0]==66);abandoned(ref mut table,ref mut session);
    }else if(mode==1){
        load(ref mut table,token,ref mut b,ref scalar[..]);let owners::Table before=owners::Table{.slots=table.slots};var usize fuel=255;
        begin_failed(sessions::begin(false,ref mut table,token,ref b,ref ledger,ref mut fuel),2);assert(fuel==255);same_table(ref table,ref before);
        fuel=256;var sessions::Session session=started(sessions::begin(false,ref mut table,token,ref b,ref ledger,ref mut fuel));
        let owners::Table pinned=owners::Table{.slots=table.slots};let sessions::Session initial=session;
        fuel=259;failed(sessions::step(false,ref mut table,ref b,1,ref mut session,ref mut fuel),2);
        same(ref session,ref initial);same_table(ref table,ref pinned);assert(fuel==259);
        fuel=260;advanced(ref mut table,ref b,1,ref mut session,ref mut fuel,false);
        let sessions::Session partial=session;fuel=259;
        failed(sessions::step(false,ref mut table,ref b,1,ref mut session,ref mut fuel),2);
        same(ref session,ref partial);same_table(ref table,ref pinned);assert(fuel==259 && session.cursor.have==1);
        assert(switch(owners::write(ref table,token,0,0,ref mut b)){case .ok(_):{false}case .err(_):{true}});
        fuel=268;advanced(ref mut table,ref b,3,ref mut session,ref mut fuel,true);assert(fuel==0);
        same_table(ref table,ref before);let sessions::Session done=session;
        fuel=259;failed(sessions::step(false,ref mut table,ref b,1,ref mut session,ref mut fuel),2);same(ref session,ref done);assert(fuel==259);
        fuel=260;failed(sessions::step(false,ref mut table,ref b,1,ref mut session,ref mut fuel),4);same(ref session,ref done);assert(fuel==0);
        assert(bytes::equal(bytes::view(ref b),ref scalar[..]));
    }else if(mode==2){
        load(ref mut table,token,ref mut b,ref scalar[..]);let owners::Table before=owners::Table{.slots=table.slots};
        let bytes::Buffer missing=bytes::empty();let owners::Token invalid=owners::Token{.slot=16,.generation=0};var usize fuel=0;
        begin_failed(sessions::begin(true,ref mut table,invalid,ref missing,ref ledger,ref mut fuel),1);assert(fuel==0);
        fuel=256;begin_failed(sessions::begin(false,ref mut table,invalid,ref missing,ref ledger,ref mut fuel),3);assert(fuel==0);
        fuel=256;begin_failed(sessions::begin(false,ref mut table,token,ref missing,ref ledger,ref mut fuel),4);assert(fuel==0);
        ledger.pending=1;fuel=256;begin_failed(sessions::begin(false,ref mut table,token,ref b,ref ledger,ref mut fuel),4);
        assert(fuel==0 && ledger.pending==1);ledger=usage;same_table(ref table,ref before);
        let owners::Token manual=switch(owners::begin_read(ref mut table,token,ref b,ref ledger)){case .ok(v):{v}case .err(_):{assert(false);token}};
        fuel=256;begin_failed(sessions::begin(false,ref mut table,token,ref b,ref ledger,ref mut fuel),4);assert(fuel==0 && table.slots[token.slot].reading);
        switch(owners::end_read(ref mut table,manual)){case .ok(_):{}case .err(_):{assert(false);}};
        fuel=256;var sessions::Session session=started(sessions::begin(false,ref mut table,token,ref b,ref ledger,ref mut fuel));
        fuel=260;failed(sessions::step(false,ref mut table,ref missing,1,ref mut session,ref mut fuel),4);
        assert(fuel==0 && !session.held && !session.cursor.active);same_table(ref table,ref before);
        fuel=256;session=started(sessions::begin(false,ref mut table,token,ref b,ref ledger,ref mut fuel));
        session.cursor.source=invalid;fuel=260;failed(sessions::step(false,ref mut table,ref b,1,ref mut session,ref mut fuel),4);
        assert(fuel==0 && !session.held);same_table(ref table,ref before);
        fuel=256;session=started(sessions::begin(false,ref mut table,token,ref b,ref ledger,ref mut fuel));
        fuel=256;failed(sessions::step(false,ref mut table,ref b,0,ref mut session,ref mut fuel),4);
        assert(fuel==0 && !session.held);same_table(ref table,ref before);
        let u8[4] broken=[240,159,0,171];load(ref mut table,token,ref mut b,ref broken[..]);
        fuel=1036;session=started(sessions::begin(false,ref mut table,token,ref b,ref ledger,ref mut fuel));
        advanced(ref mut table,ref b,1,ref mut session,ref mut fuel,false);advanced(ref mut table,ref b,1,ref mut session,ref mut fuel,false);
        failed(sessions::step(false,ref mut table,ref b,1,ref mut session,ref mut fuel),5);
        assert(fuel==0 && !session.held && session.cursor.offset==2 && session.cursor.have==2 && !session.cursor.active);
        same_table(ref table,ref before);assert(bytes::equal(bytes::view(ref b),ref broken[..]));
        fuel=256;session=started(sessions::begin(false,ref mut table,token,ref b,ref ledger,ref mut fuel));
        let owners::Table pinned=owners::Table{.slots=table.slots};table.slots[15].reading=true;
        fuel=260;failed(sessions::step(false,ref mut table,ref b,1,ref mut session,ref mut fuel),4);
        assert(fuel==0 && session.held && !session.cursor.active && table.slots[token.slot].reading);
        table=pinned;abandoned(ref mut table,ref mut session);abandoned(ref mut table,ref mut session);same_table(ref table,ref before);
    }else{
        load(ref mut table,token,ref mut b,ref scalar[..]);let owners::Table before=owners::Table{.slots=table.slots};
        let bytes::Buffer missing=bytes::empty();var usize split=1;
        while(split<4){
            var usize fuel=256+260*split;var sessions::Session session=started(sessions::begin(false,ref mut table,token,ref b,ref ledger,ref mut fuel));
            var usize i=0;while(i<split){advanced(ref mut table,ref b,1,ref mut session,ref mut fuel,false);i+=1;}
            assert(fuel==0 && session.held && session.cursor.offset==split && session.cursor.have==split);
            failed(sessions::step(true,ref mut table,ref missing,18446744073709551615,ref mut session,ref mut fuel),1);
            assert(fuel==0 && !session.held && !session.cursor.active && session.cursor.offset==split && session.cursor.have==split);
            failed(sessions::step(true,ref mut table,ref missing,0,ref mut session,ref mut fuel),1);same_table(ref table,ref before);split+=1;
        }
        var usize fuel=256;var sessions::Session session=started(sessions::begin(false,ref mut table,token,ref b,ref ledger,ref mut fuel));
        abandoned(ref mut table,ref mut session);assert(fuel==0);same_table(ref table,ref before);
        assert(switch(owners::write(ref table,token,0,65,ref mut b)){case .ok(n):{n==0}case .err(_):{false}});
        assert(bytes::view(ref b)[0]==65);
    }
    same_usage(ref ledger,ref usage);
}
