module utf8_pool;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_create as create;
import buffer_close as close;
import buffer_utf8_pool as pools;
import buffer_utf8_meter as meter;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn u8 code(meter::ControlError e){return switch(e){case .Cancelled:{1}case .Fuel:{2}case .Token:{3}case .State:{4}case .Utf8:{5}};}
fn pools::Ticket opened(Result<pools::Ticket,meter::ControlError> r){
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);pools::Ticket{.slot=16,.generation=0}}};
}
fn void begin_failed(Result<pools::Ticket,meter::ControlError> r,u8 expected){
    assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});
}
fn void step_failed(Result<bool,meter::ControlError> r,u8 expected){
    assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});
}
fn void failed(Result<usize,meter::ControlError> r,u8 expected){
    assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});
}
fn void count(Result<usize,meter::ControlError> r,usize expected){
    assert(switch(r){case .ok(v):{v==expected}case .err(_):{false}});
}
fn void phase(ref pools::Pool pool,u8 expected){
    assert(pool.phase==expected);
}
fn void same_slot(ref pools::Slot a,ref pools::Slot b){
    assert(a.generation==b.generation && a.live==b.live && a.session.held==b.session.held &&
        a.session.source.slot==b.session.source.slot && a.session.source.generation==b.session.source.generation &&
        a.session.cursor.active==b.session.cursor.active && a.session.cursor.source.slot==b.session.cursor.source.slot &&
        a.session.cursor.source.generation==b.session.cursor.source.generation && a.session.cursor.offset==b.session.cursor.offset &&
        a.session.cursor.length==b.session.cursor.length && a.session.cursor.capacity==b.session.cursor.capacity &&
        a.session.cursor.have==b.session.cursor.have);
    var usize i=0;while(i<4){assert(a.session.cursor.carry[i]==b.session.cursor.carry[i]);i+=1;}
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
fn void released_usage(ref growth::Ledger a,ref growth::Ledger b){
    let growth::Ledger expected=growth::Ledger{.used=b.used-pools::metadata_charge(),.engine_used=b.engine_used-pools::metadata_charge(),
        .peak=b.peak,.engine_peak=b.engine_peak,.pending=b.pending,.old_capacity=b.old_capacity,.new_capacity=b.new_capacity,
        .before_used=b.before_used,.before_engine_used=b.before_engine_used};
    same_usage(a,ref expected);
}
fn void admission_failed(Result<usize,growth::Error> r,u8 expected){
    assert(switch(r){case .ok(_):{false}case .err(e):{switch(e){case .State:{expected==1}
        case .Overflow:{expected==2}case .Quota:{expected==3}case .NoGrowth:{false}}}});
}
fn void admitted(ref mut pools::Pool pool,growth::Limits policy,ref mut growth::Ledger ledger){
    assert(switch(pools::admit(pool,policy,ledger)){case .ok(n):{n==ledger.used}case .err(_):{false}});
    assert(pool.admitted);
}
pub fn void admission(u8 mode){
    var growth::Ledger ledger=growth::empty();var bytes::Buffer b=bytes::empty();var owners::Table table=owners::empty();
    b=switch(storage::prepare_growth(ref b,256,limits(),ref mut ledger)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    switch(growth::commit(256,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(ref mut b,b"keep")){case .ok(_):{}case .err(_):{assert(false);}};
    ledger.engine_used+=32;ledger.engine_peak+=32;
    let owners::Token token=switch(owners::create(ref mut table,ref b)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    let growth::Ledger before=ledger;var pools::Pool pool=pools::empty();var usize fuel=256;
    begin_failed(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel),4);
    same_usage(ref ledger,ref before);assert(fuel==256 && !table.slots[token.slot].reading);
    if(mode==0){
        // Fixed metadata admission ignores the Buffer payload object ceiling.
        admitted(ref mut pool,growth::Limits{.object=0,.instance=2432,.engine=2464},ref mut ledger);
        assert(ledger.used==2432 && ledger.engine_used==2464 && ledger.peak==2432 && ledger.engine_peak==2464);
        let growth::Ledger paid=ledger;
        admission_failed(pools::admit(ref mut pool,limits(),ref mut ledger),1);same_usage(ref ledger,ref paid);
        let pools::Ticket ticket=opened(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel));
        count(pools::abandon(ref mut pool,ticket,ref mut table),0);count(pools::drain(ref mut pool,ref mut table),0);
        same_usage(ref ledger,ref paid);count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),0);
        released_usage(ref ledger,ref paid);assert(!pool.admitted && ledger.used==before.used && ledger.engine_used==before.engine_used);
        let growth::Ledger released=ledger;count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),0);same_usage(ref ledger,ref released);
        admission_failed(pools::admit(ref mut pool,limits(),ref mut ledger),1);
    }else if(mode==1){
        admission_failed(pools::admit(ref mut pool,growth::Limits{.object=0,.instance=2431,.engine=2464},ref mut ledger),3);
        admission_failed(pools::admit(ref mut pool,growth::Limits{.object=0,.instance=2432,.engine=2463},ref mut ledger),3);
        admission_failed(pools::admit(ref mut pool,growth::Limits{.object=0,.instance=319,.engine=8192},ref mut ledger),3);
        same_usage(ref ledger,ref before);assert(!pool.admitted && pool.phase==0);
        ledger.used=18446744073709549504;ledger.engine_used=18446744073709549504;
        ledger.peak=ledger.used;ledger.engine_peak=ledger.engine_used;let growth::Ledger huge=ledger;
        admission_failed(pools::admit(ref mut pool,limits(),ref mut ledger),2);same_usage(ref ledger,ref huge);
        ledger.used=0;ledger.peak=0;let growth::Ledger engine_only=ledger;
        admission_failed(pools::admit(ref mut pool,limits(),ref mut ledger),2);same_usage(ref ledger,ref engine_only);ledger=before;
        admitted(ref mut pool,limits(),ref mut ledger);count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),0);
    }else if(mode==2){
        var usize i=0;while(i<9){
            if(i==0){ledger.pending=1;}else if(i==1){ledger.old_capacity=64;}else if(i==2){ledger.new_capacity=64;}
            else if(i==3){ledger.before_used=64;}else if(i==4){ledger.before_engine_used=64;}else if(i==5){ledger.used=ledger.engine_used+1;}
            else if(i==6){ledger.peak=ledger.used-1;}else if(i==7){ledger.engine_peak=ledger.engine_used-1;}else{ledger.peak=ledger.engine_peak+1;}
            let growth::Ledger malformed=ledger;admission_failed(pools::admit(ref mut pool,limits(),ref mut ledger),1);
            same_usage(ref ledger,ref malformed);assert(!pool.admitted && pool.phase==0);ledger=before;i+=1;
        }
        let pools::Slot vacant=pool.s15;pool.s15.session.held=true;
        admission_failed(pools::admit(ref mut pool,limits(),ref mut ledger),1);pool.s15=vacant;same_usage(ref ledger,ref before);
        switch(growth::begin(256,257,limits(),ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
        let growth::Ledger reserved=ledger;admission_failed(pools::admit(ref mut pool,limits(),ref mut ledger),1);same_usage(ref ledger,ref reserved);
        switch(growth::cancel(ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
        admitted(ref mut pool,limits(),ref mut ledger);count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),0);
        // Admission also works before any Buffer root exists.
        var pools::Pool standalone=pools::empty();var growth::Ledger zero=growth::unowned();var owners::Table none=owners::empty();
        admitted(ref mut standalone,growth::Limits{.object=0,.instance=2112,.engine=2112},ref mut zero);
        count(pools::shutdown(ref mut standalone,ref mut none,ref mut zero),0);
        assert(zero.used==0 && zero.engine_used==0 && zero.peak==2112 && zero.engine_peak==2112);
    }else{
        admitted(ref mut pool,limits(),ref mut ledger);let growth::Ledger paid=ledger;
        let pools::Ticket ticket=opened(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel));
        ledger.used-=1;let growth::Ledger short_usage=ledger;
        begin_failed(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel),4);assert(fuel==0);
        failed(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),4);
        same_usage(ref ledger,ref short_usage);assert(pool.phase==1 && pool.admitted && !pool.s0.live && !table.slots[token.slot].reading);
        ledger=paid;ledger.pending=1;let growth::Ledger pending=ledger;
        failed(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),4);same_usage(ref ledger,ref pending);assert(pool.admitted);
        ledger=paid;table.slots[15].reading=true;
        failed(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),4);same_usage(ref ledger,ref paid);assert(pool.admitted);
        table.slots[15].reading=false;count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),0);
        released_usage(ref ledger,ref paid);assert(!pool.admitted && pool.phase==2 && pool.s0.generation==2);
        failed(pools::abandon(ref mut pool,ticket,ref mut table),3);
        let growth::Ledger released=ledger;count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),0);same_usage(ref ledger,ref released);
    }
    assert(bytes::equal(bytes::view(ref b),b"keep") && !table.slots[token.slot].reading && !pool.admitted);
}
fn pools::Ticket empty_ticket(ref mut pools::Pool pool,ref mut owners::Table table,ref bytes::Buffer root,ref mut growth::Ledger ledger){
    let owners::Token token=switch(create::empty(table,root,limits(),ledger)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    var usize fuel=256;let pools::Ticket ticket=opened(pools::begin(false,pool,table,token,root,ledger,ref mut fuel));assert(fuel==0);return ticket;
}
pub fn void run(u8 mode){
    var growth::Ledger ledger=growth::empty();var bytes::Buffer b=bytes::empty();var owners::Table table=owners::empty();
    b=switch(storage::prepare_growth(ref b,256,limits(),ref mut ledger)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    switch(growth::commit(256,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    let u8[4] scalar=[240,159,141,171];switch(bytes::append(ref mut b,ref scalar[..])){case .ok(_):{}case .err(_):{assert(false);}};
    ledger.engine_used+=32;ledger.engine_peak+=32;
    let owners::Token token=switch(owners::create(ref mut table,ref b)){case .ok(v):{v}
        case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    let owners::Table before=owners::Table{.slots=table.slots};
    var pools::Pool pool=pools::empty();
    assert(switch(pools::admit(ref mut pool,limits(),ref mut ledger)){case .ok(_):{true}case .err(_):{false}});
    let growth::Ledger usage=ledger;var usize fuel=0;
    if(mode==0){
        let pools::Slot vacant=pool.s0;
        begin_failed(pools::begin(true,ref mut pool,ref mut table,owners::Token{.slot=16,.generation=0},ref b,ref ledger,ref mut fuel),1);
        begin_failed(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel),2);
        same_slot(ref pool.s0,ref vacant);same_table(ref table,ref before);assert(fuel==0);
        fuel=256;let pools::Ticket ticket=opened(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel));
        assert(ticket.slot==0 && ticket.generation==1 && pool.s0.live && table.slots[token.slot].reading && fuel==0);
        let pools::Slot initial=pool.s0;
        step_failed(pools::step(false,ref mut pool,ticket,ref mut table,ref b,1,ref mut fuel),2);same_slot(ref pool.s0,ref initial);
        fuel=260;assert(switch(pools::step(false,ref mut pool,ticket,ref mut table,ref b,1,ref mut fuel)){case .ok(done):{!done}case .err(_):{false}});
        assert(fuel==0 && pool.s0.session.cursor.offset==1 && pool.s0.session.cursor.have==1);
        let pools::Slot partial=pool.s0;fuel=259;
        step_failed(pools::step(false,ref mut pool,ticket,ref mut table,ref b,1,ref mut fuel),2);same_slot(ref pool.s0,ref partial);assert(fuel==259);
        assert(switch(owners::write(ref table,token,0,0,ref mut b)){case .ok(_):{false}case .err(_):{true}});
        fuel=268;assert(switch(pools::step(false,ref mut pool,ticket,ref mut table,ref b,3,ref mut fuel)){case .ok(done):{done}case .err(_):{false}});
        assert(fuel==0 && !pool.s0.live && pool.s0.generation==2 && !pool.s0.session.held);
        same_table(ref table,ref before);fuel=7;step_failed(pools::step(true,ref mut pool,ticket,ref mut table,ref b,1,ref mut fuel),3);assert(fuel==7);
        count(pools::drain(ref mut pool,ref mut table),0);same_usage(ref ledger,ref usage);
    }else if(mode==1){
        let bytes::Buffer missing=bytes::empty();fuel=256;
        let pools::Ticket old=opened(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel));
        count(pools::abandon(ref mut pool,old,ref mut table),0);assert(pool.s0.generation==2);
        fuel=256;let pools::Ticket fresh=opened(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel));
        assert(fresh.slot==old.slot && fresh.generation==old.generation+1);let pools::Slot held=pool.s0;
        step_failed(pools::step(true,ref mut pool,old,ref mut table,ref missing,0,ref mut fuel),3);
        failed(pools::abandon(ref mut pool,old,ref mut table),3);same_slot(ref pool.s0,ref held);assert(table.slots[token.slot].reading && fuel==0);
        let pools::Slot inactive=pool.s15;pool.s15.session.held=true;
        step_failed(pools::step(true,ref mut pool,pools::Ticket{.slot=16,.generation=0},ref mut table,ref missing,0,ref mut fuel),3);
        step_failed(pools::step(true,ref mut pool,fresh,ref mut table,ref missing,0,ref mut fuel),4);same_slot(ref pool.s0,ref held);pool.s15=inactive;
        fuel=260;step_failed(pools::step(false,ref mut pool,fresh,ref mut table,ref missing,1,ref mut fuel),4);
        assert(fuel==0 && !pool.s0.live && pool.s0.generation==3);same_table(ref table,ref before);
        fuel=256;let pools::Ticket next=opened(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel));
        pool.s1=pool.s0;failed(pools::drain(ref mut pool,ref mut table),4);assert(table.slots[token.slot].reading);
        pool.s1=inactive;step_failed(pools::step(true,ref mut pool,next,ref mut table,ref missing,18446744073709551615,ref mut fuel),1);
        assert(fuel==0 && !pool.s0.live && pool.s0.generation==4);same_table(ref table,ref before);same_usage(ref ledger,ref usage);
    }else if(mode==2){
        var pools::Ticket[16] tickets=[pools::Ticket{.slot=16,.generation=0};16];pool.s0.generation=18446744073709551615;
        fuel=256;tickets[0]=opened(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel));
        var bytes::Buffer b1=bytes::empty();tickets[1]=empty_ticket(ref mut pool,ref mut table,ref b1,ref mut ledger);
        var bytes::Buffer b2=bytes::empty();tickets[2]=empty_ticket(ref mut pool,ref mut table,ref b2,ref mut ledger);
        var bytes::Buffer b3=bytes::empty();tickets[3]=empty_ticket(ref mut pool,ref mut table,ref b3,ref mut ledger);
        var bytes::Buffer b4=bytes::empty();tickets[4]=empty_ticket(ref mut pool,ref mut table,ref b4,ref mut ledger);
        var bytes::Buffer b5=bytes::empty();tickets[5]=empty_ticket(ref mut pool,ref mut table,ref b5,ref mut ledger);
        var bytes::Buffer b6=bytes::empty();tickets[6]=empty_ticket(ref mut pool,ref mut table,ref b6,ref mut ledger);
        var bytes::Buffer b7=bytes::empty();tickets[7]=empty_ticket(ref mut pool,ref mut table,ref b7,ref mut ledger);
        var bytes::Buffer b8=bytes::empty();tickets[8]=empty_ticket(ref mut pool,ref mut table,ref b8,ref mut ledger);
        var bytes::Buffer b9=bytes::empty();tickets[9]=empty_ticket(ref mut pool,ref mut table,ref b9,ref mut ledger);
        var bytes::Buffer b10=bytes::empty();tickets[10]=empty_ticket(ref mut pool,ref mut table,ref b10,ref mut ledger);
        var bytes::Buffer b11=bytes::empty();tickets[11]=empty_ticket(ref mut pool,ref mut table,ref b11,ref mut ledger);
        var bytes::Buffer b12=bytes::empty();tickets[12]=empty_ticket(ref mut pool,ref mut table,ref b12,ref mut ledger);
        var bytes::Buffer b13=bytes::empty();tickets[13]=empty_ticket(ref mut pool,ref mut table,ref b13,ref mut ledger);
        var bytes::Buffer b14=bytes::empty();tickets[14]=empty_ticket(ref mut pool,ref mut table,ref b14,ref mut ledger);
        var bytes::Buffer b15=bytes::empty();tickets[15]=empty_ticket(ref mut pool,ref mut table,ref b15,ref mut ledger);
        assert(ledger.used==3392 && ledger.engine_used==3424 && pool.s15.live && tickets[0].generation==18446744073709551615);
        let growth::Ledger full=ledger;var usize i=0;while(i<16){assert(table.slots[i].reading);i+=1;}
        fuel=0;begin_failed(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel),4);assert(fuel==0);
        count(pools::abandon(ref mut pool,tickets[0],ref mut table),0);assert(pool.s0.generation==0 && !pool.s0.live && !table.slots[token.slot].reading);
        fuel=256;begin_failed(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel),4);assert(fuel==256);
        count(pools::abandon(ref mut pool,tickets[15],ref mut table),0);
        let pools::Ticket reused=opened(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel));
        assert(reused.slot==15 && reused.generation==2 && fuel==0 && table.slots[token.slot].reading);
        step_failed(pools::step(true,ref mut pool,tickets[0],ref mut table,ref b,1,ref mut fuel),3);assert(table.slots[token.slot].reading);
        count(pools::drain(ref mut pool,ref mut table),15);count(pools::drain(ref mut pool,ref mut table),0);
        i=0;while(i<16){assert(!table.slots[i].reading);i+=1;}assert(pool.s0.generation==0);same_usage(ref ledger,ref full);
    }else if(mode==3 || mode==5){
        var bytes::Buffer second=bytes::empty();fuel=256;
        let pools::Ticket first=opened(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel));
        let pools::Ticket other=empty_ticket(ref mut pool,ref mut table,ref second,ref mut ledger);
        let growth::Ledger admitted=ledger;let owners::Table pinned=owners::Table{.slots=table.slots};
        table.slots[token.slot].generation+=1;
        if(mode==3){failed(pools::drain(ref mut pool,ref mut table),4);}else{
            failed(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),4);phase(ref pool,1);
            assert(pool.admitted);same_usage(ref ledger,ref admitted);
            fuel=1000;let pools::Slot held=pool.s0;
            begin_failed(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel),4);
            step_failed(pools::step(false,ref mut pool,first,ref mut table,ref b,4,ref mut fuel),4);
            step_failed(pools::step(true,ref mut pool,first,ref mut table,ref second,0,ref mut fuel),4);
            same_slot(ref pool.s0,ref held);assert(fuel==1000 && table.slots[token.slot].reading);
        }
        assert(pool.s0.live && pool.s0.session.held && !pool.s0.session.cursor.active && !pool.s1.live && pool.s1.generation==2);
        assert(table.slots[token.slot].reading && !table.slots[1].reading);
        failed(pools::abandon(ref mut pool,other,ref mut table),3);
        table.slots[token.slot].generation=token.generation;
        if(mode==3){count(pools::drain(ref mut pool,ref mut table),1);}else{
            count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),1);phase(ref pool,2);
            count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),0);phase(ref pool,2);
        }
        count(pools::drain(ref mut pool,ref mut table),0);
        assert(!pool.s0.live && pool.s0.generation==2 && !table.slots[token.slot].reading && !table.slots[1].reading);
        failed(pools::abandon(ref mut pool,first,ref mut table),3);
        if(mode==3){same_usage(ref ledger,ref admitted);}else{released_usage(ref ledger,ref admitted);}
        var owners::Table expected=owners::Table{.slots=pinned.slots};expected.slots[token.slot].reading=false;expected.slots[1].reading=false;same_table(ref table,ref expected);
    }else if(mode==4){
        phase(ref pool,0);fuel=256;
        let pools::Ticket ticket=opened(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel));
        fuel=260;assert(switch(pools::step(false,ref mut pool,ticket,ref mut table,ref b,1,ref mut fuel)){case .ok(v):{!v}case .err(_):{false}});
        var close::Plan plan=close::empty();
        assert(switch(close::begin(ref mut table,token,ref b,ref ledger,ref mut plan)){case .ok(_):{false}case .err(_):{true}});
        count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),1);phase(ref pool,2);assert(fuel==0);
        same_table(ref table,ref before);released_usage(ref ledger,ref usage);
        assert(!pool.s0.live && pool.s0.generation==2 && !pool.s0.session.cursor.active);
        fuel=1000;begin_failed(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel),4);
        begin_failed(pools::begin(true,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel),1);
        step_failed(pools::step(true,ref mut pool,ticket,ref mut table,ref b,4,ref mut fuel),3);assert(fuel==1000);
        count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),0);assert(pool.s0.generation==2);
        // Actual root destruction is caller-ordered, after every session is released.
        assert(switch(close::begin(ref mut table,token,ref b,ref ledger,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
        b=bytes::empty();assert(switch(close::finish(ref table,ref mut ledger,ref mut plan)){case .ok(n):{n==0}case .err(_):{false}});
        assert(ledger.used==0 && ledger.engine_used==32 && !table.slots[token.slot].live);return;
    }else if(mode==6){
        // Closing an already completed registry never advances generations again.
        fuel=256;let pools::Ticket ticket=opened(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel));
        fuel=272;assert(switch(pools::step(false,ref mut pool,ticket,ref mut table,ref b,4,ref mut fuel)){case .ok(v):{v}case .err(_):{false}});
        count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),0);phase(ref pool,2);
        count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),0);assert(pool.s0.generation==2 && fuel==0);
        failed(pools::abandon(ref mut pool,ticket,ref mut table),3);
        same_table(ref table,ref before);released_usage(ref ledger,ref usage);
    }else{
        fuel=256;let pools::Ticket ticket=opened(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel));
        let pools::Slot vacant=pool.s15;pool.s15.session.held=true;
        failed(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),4);phase(ref pool,1);
        assert(table.slots[token.slot].reading && pool.s0.live);
        pool.s15=vacant;fuel=1000;
        begin_failed(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel),4);assert(fuel==1000);
        // Individual recovery remains available; drain alone never reopens the Pool.
        count(pools::abandon(ref mut pool,ticket,ref mut table),0);phase(ref pool,1);
        count(pools::drain(ref mut pool,ref mut table),0);phase(ref pool,1);
        count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),0);phase(ref pool,2);
        // Malformed Closed state must not be silently accepted as idempotent success.
        pool.s15.session.held=true;failed(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),4);phase(ref pool,2);
        pool.s15=vacant;count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),0);
        pool.phase=255;failed(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),4);phase(ref pool,255);
        begin_failed(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel),4);
        pool.phase=2;count(pools::shutdown(ref mut pool,ref mut table,ref mut ledger),0);assert(fuel==1000);
        same_table(ref table,ref before);released_usage(ref ledger,ref usage);
    }
    assert(bytes::equal(bytes::view(ref b),ref scalar[..]));
}
