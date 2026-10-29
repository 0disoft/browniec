module buffer_utf8_pool;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_growth as growth;
import buffer_utf8_session as sessions;
import buffer_utf8_meter as meter;

// Caller-owned host bookkeeping; not a guest handle table or native root owner.
pub struct Ticket { usize slot; usize generation; }
pub struct Slot { usize generation; bool live; sessions::Session session; }
// Explicit fields avoid unsupported mutation of nested-record array elements.
pub struct Pool {
    u8 phase; // 0 Open, 1 Closing, 2 Closed; reject all other values.
    bool admitted;
    Slot s0;
    Slot s1;
    Slot s2;
    Slot s3;
    Slot s4;
    Slot s5;
    Slot s6;
    Slot s7;
    Slot s8;
    Slot s9;
    Slot s10;
    Slot s11;
    Slot s12;
    Slot s13;
    Slot s14;
    Slot s15;
}
fn Slot fresh(){return Slot{.generation=1,.live=false,.session=sessions::empty()};}
pub fn Pool empty(){return Pool{.phase=0,.admitted=false,.s0=fresh(),.s1=fresh(),.s2=fresh(),.s3=fresh(),.s4=fresh(),.s5=fresh(),.s6=fresh(),.s7=fresh(),.s8=fresh(),.s9=fresh(),.s10=fresh(),.s11=fresh(),.s12=fresh(),.s13=fresh(),.s14=fresh(),.s15=fresh()};}
// Logical policy: 64-byte registry header plus sixteen 128-byte metadata slots.
// Not sizeof(Pool), native allocation size, or a charge for external Ticket copies.
pub fn usize metadata_charge(){return 2112;}
fn bool open(ref Pool pool){return pool.phase==0;}
// Internal indices are always checked against the fixed 16-slot bound.
fn Slot at(ref Pool pool,usize index){
    if(index==0){return pool.s0;}
    if(index==1){return pool.s1;}
    if(index==2){return pool.s2;}
    if(index==3){return pool.s3;}
    if(index==4){return pool.s4;}
    if(index==5){return pool.s5;}
    if(index==6){return pool.s6;}
    if(index==7){return pool.s7;}
    if(index==8){return pool.s8;}
    if(index==9){return pool.s9;}
    if(index==10){return pool.s10;}
    if(index==11){return pool.s11;}
    if(index==12){return pool.s12;}
    if(index==13){return pool.s13;}
    if(index==14){return pool.s14;}
    return pool.s15;
}
fn void put(ref mut Pool pool,usize index,Slot entry){
    if(index==0){pool.s0=entry;return;}
    if(index==1){pool.s1=entry;return;}
    if(index==2){pool.s2=entry;return;}
    if(index==3){pool.s3=entry;return;}
    if(index==4){pool.s4=entry;return;}
    if(index==5){pool.s5=entry;return;}
    if(index==6){pool.s6=entry;return;}
    if(index==7){pool.s7=entry;return;}
    if(index==8){pool.s8=entry;return;}
    if(index==9){pool.s9=entry;return;}
    if(index==10){pool.s10=entry;return;}
    if(index==11){pool.s11=entry;return;}
    if(index==12){pool.s12=entry;return;}
    if(index==13){pool.s13=entry;return;}
    if(index==14){pool.s14=entry;return;}
    pool.s15=entry;
}
fn bool valid(ref Pool pool){
    if(pool.phase>2 || (pool.phase==2 && pool.admitted)){return false;}
    var usize i=0;while(i<16){
        let Slot entry=at(pool,i);
        if(entry.live){
            if(pool.phase==2 || !pool.admitted){return false;}
            if(entry.generation==0 || !entry.session.held || entry.session.source.slot>=16 || entry.session.source.generation==0){return false;}
            var usize j=0;while(j<i){
                let Slot earlier=at(pool,j);
                if(earlier.live && earlier.session.source.slot==entry.session.source.slot){return false;}j+=1;
            }
        }else if(entry.session.held || entry.session.cursor.active){return false;}
        i+=1;
    }
    return true;
}
pub fn Result<usize,growth::Error> admit(ref mut Pool pool,growth::Limits limits,ref mut growth::Ledger ledger){
    if(!open(pool) || pool.admitted || !valid(pool)){return .err(.State);}
    let usize used=growth::admit_metadata(metadata_charge(),limits,ledger)?;
    pool.admitted=true;return .ok(used);
}
fn bool covered(ref owners::Table table,ref growth::Ledger ledger){
    let usize roots=switch(owners::accounted(table)){case .ok(n):{n}case .err(_):{return false;}};
    return roots<=18446744073709551615-metadata_charge() && ledger.used>=roots+metadata_charge();
}
fn Result<usize,meter::ControlError> resolve(ref Pool pool,Ticket ticket){
    if(ticket.slot>=16 || ticket.generation==0){return .err(.Token);}
    let Slot entry=at(pool,ticket.slot);
    if(!entry.live || entry.generation!=ticket.generation){return .err(.Token);}
    if(!valid(pool)){return .err(.State);}
    return .ok(ticket.slot);
}
fn void retire(ref mut Pool pool,usize index){
    let Slot entry=at(pool,index);
    put(pool,index,Slot{.generation=if(entry.generation==18446744073709551615){0}else{entry.generation+1},
        .live=false,.session=sessions::empty()});
}
pub fn Result<Ticket,meter::ControlError> begin(bool cancel_requested,ref mut Pool pool,
    ref mut owners::Table table,owners::Token source,ref bytes::Buffer b,ref growth::Ledger ledger,ref mut usize fuel){
    if(cancel_requested){return .err(.Cancelled);}
    if(!open(pool) || !pool.admitted){return .err(.State);}
    if(!valid(pool)){return .err(.State);}
    if(!covered(table,ledger)){return .err(.State);}
    var usize index=0;while(index<16){let Slot entry=at(pool,index);if(!entry.live && entry.generation!=0){break;}index+=1;}
    if(index==16){return .err(.State);}
    let sessions::Session session=sessions::begin(false,table,source,b,ledger,fuel)?;
    // A lease exists; publication is infallible and no further admission occurs.
    var Slot entry=at(pool,index);entry.session=session;entry.live=true;
    put(pool,index,entry);return .ok(Ticket{.slot=index,.generation=entry.generation});
}
pub fn Result<bool,meter::ControlError> step(bool cancel_requested,ref mut Pool pool,Ticket ticket,
    ref mut owners::Table table,ref bytes::Buffer b,usize max_bytes,ref mut usize fuel){
    let usize index=resolve(pool,ticket)?;var Slot entry=at(pool,index);
    if(!open(pool)){return .err(.State);}
    let Result<bool,meter::ControlError> outcome=sessions::step(cancel_requested,table,b,max_bytes,ref mut entry.session,fuel);
    if(entry.session.held){put(pool,index,entry);}else{retire(pool,index);}
    return outcome;
}
pub fn Result<usize,meter::ControlError> abandon(ref mut Pool pool,Ticket ticket,ref mut owners::Table table){
    let usize index=resolve(pool,ticket)?;var Slot entry=at(pool,index);
    let Result<usize,meter::ControlError> outcome=sessions::abandon(table,ref mut entry.session);
    if(entry.session.held){put(pool,index,entry);}else{retire(pool,index);}
    return outcome;
}
// Continue independent cleanup after an error; unresolved leases stay registered.
pub fn Result<usize,meter::ControlError> drain(ref mut Pool pool,ref mut owners::Table table){
    if(!valid(pool)){return .err(.State);}
    var bool failed=false;var usize count=0;var usize i=0;
    while(i<16){
        var Slot entry=at(pool,i);
        if(entry.live){
            switch(sessions::abandon(table,ref mut entry.session)){
                case .ok(_):{retire(pool,i);count+=1;}case .err(_):{put(pool,i,entry);failed=true;}
            };
        }
        i+=1;
    }
    if(failed){return .err(.State);}
    return .ok(count);
}
// One-way host shutdown entry point. Failure retains Closing and retryable leases.
// This explicit hook does not install an automatic destructor or own native roots.
pub fn Result<usize,meter::ControlError> shutdown(ref mut Pool pool,ref mut owners::Table table,ref mut growth::Ledger ledger){
    if(pool.phase==0){pool.phase=1;}
    let usize count=drain(pool,table)?;
    if(pool.admitted){
        if(!covered(table,ledger)){return .err(.State);}
        switch(growth::release_metadata(metadata_charge(),ledger)){case .ok(_):{}case .err(_):{return .err(.State);}};
        pool.admitted=false;
    }
    pool.phase=2;
    return .ok(count);
}
