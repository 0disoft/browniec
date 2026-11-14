module tests::m2::value_root_authentication;
import value_roots as store;
import buffer_owners as owners;
import buffer_growth as growth;
import std::bytes as bytes;
import std::vec as vec;
// Original 2233345 preflight, frozen for acceptance/error parity.
fn Result<usize,store::Error> original(ref store::State s,ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> scratch){
    let usize count=vec::len<bytes::Buffer>(roots);
    if(s.closed || count>16 || vec::len<bytes::Buffer>(scratch)!=0 ||
        vec::capacity<bytes::Buffer>(roots)<16 || vec::capacity<bytes::Buffer>(scratch)<16 ||
        s.closing.active || !growth::settled(ref s.ledger)){return .err(.State);}
    let usize accounted=switch(owners::accounted(ref s.table)){case .ok(v):{v}case .err(_):{return .err(.State);}};
    if(s.external%64!=0 || s.external>18446744073709551615-store::metadata_charge()){return .err(.State);}
    let usize metadata=store::metadata_charge()+s.external;
    if(accounted>18446744073709551615-metadata ||
        s.ledger.used!=metadata+accounted){return .err(.State);}
    var usize occupied=0;var usize i=0;let usize one=1;
    while(i<16){let store::Row row=s.rows[i];
        if(i<count){
            if(row.serial==0 || row.binding>=512 || row.slot>=16 || row.generation==0 ||
                (s.next!=0 && row.serial>=s.next) || (occupied&(one<<row.slot))!=0){return .err(.State);}
            if(!owners::describe(ref s.table,owners::Token{.slot=row.slot,.generation=row.generation}).is_ok){return .err(.State);}
            occupied|=one<<row.slot;var usize j=0;
            while(j<i){if(s.rows[j].serial==row.serial || s.rows[j].binding==row.binding){return .err(.State);}j+=1;}
        }else if(row.serial!=0 || row.binding!=512 || row.slot!=16 || row.generation!=0){return .err(.State);}
        i+=1;
    }
    i=0;while(i<16){if(s.table.slots[i].live!=((occupied&(one<<i))!=0)){return .err(.State);}i+=1;}
    return .ok(count);
}
fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=32768,.engine=32768};}
fn usize ok(Result<usize,store::Error> r){return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};}
fn u8 tag(store::Error e){return switch(e){
    case .Fuel:{1}case .State:{2}case .Binding:{3}case .Serial:{4}
    case .Owners:{5}case .Quota:{6}case .Allocation:{7}case .Bounds:{8}};}
fn void same(ref store::State s,ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> scratch){
    let Result<usize,store::Error> before=original(s,roots,scratch);
    let Result<usize,store::Error> after=store::inspect_store(s,roots,scratch);
    assert(switch(before){case .ok(n):{switch(after){case .ok(m):{n==m}case .err(_):{false}}}
        case .err(e):{switch(after){case .ok(_):{false}case .err(f):{tag(e)==tag(f)}}}});
}
fn void corrupt(ref store::State clean,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize i,usize mode){
    var store::State s=*clean;
    if(mode==0){s.rows[i].serial=0;}
    else if(mode==1){s.rows[i].binding=512;}
    else if(mode==2){s.rows[i].slot=16;}
    else if(mode==3){s.rows[i].generation=0;}
    else if(mode==4){s.rows[i].generation+=1;}
    else if(mode==5){s.rows[i].serial=clean.next;}
    else if(mode==6){s.rows[i].serial=clean.rows[0].serial;}
    else if(mode==7){s.rows[i].binding=clean.rows[0].binding;}
    else if(mode==8){s.rows[i].slot=clean.rows[0].slot;}
    else if(mode==9){s.table.slots[i].generation=0;}
    else if(mode==10){s.table.slots[i].generation+=1;}
    else if(mode==11){let bool live=s.table.slots[i].live;s.table.slots[i].live=!live;}
    else if(mode==12){s.table.slots[i].capacity=1;}
    else if(mode==13){s.table.slots[i].capacity=18446744073709551615;}
    else if(mode==14){let usize capacity=s.table.slots[i].capacity;s.table.slots[i].length=capacity+1;}
    else if(mode==15){s.table.slots[i].reading=true;}
    else if(mode==16){s.external=18446744073709551615;}
    else if(mode==17){s.ledger.used+=64;s.ledger.engine_used+=64;s.ledger.peak+=64;s.ledger.engine_peak+=64;}
    else if(mode==18){s.closing.active=true;}
    else{s.ledger.pending=64;}
    same(ref s,roots,scratch);
}
@test fn void all_owner_slots_and_row_identities_match_original_preflight(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var store::State s=switch(store::open(ref mut roots,ref mut scratch,limits(),ref mut fuel)){
        case .ok(s):{s}case .err(_):{assert(false);all_owner_slots_and_row_identities_match_original_preflight();return;}};
    var usize count=0;while(count<=16){same(ref s,ref roots,ref scratch);
        if(count==0 || count==1 || count==8 || count==16){var usize i=0;while(i<16){
            var usize mode=0;while(mode<20){corrupt(ref s,ref roots,ref scratch,i,mode);mode+=1;}i+=1;}}
        if(count==16){break;}
        let usize serial=ok(store::insert(ref mut s,ref mut roots,ref mut scratch,count,b"x",limits(),ref mut fuel));count+=1;
    }
    assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0);
}
@test fn void full_store_byte_reads_preserve_fuel_leases_bounds_and_cleanup(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var store::State s=switch(store::open(ref mut roots,ref mut scratch,limits(),ref mut fuel)){
        case .ok(s):{s}case .err(_):{assert(false);full_store_byte_reads_preserve_fuel_leases_bounds_and_cleanup();return;}};
    var usize i=0;var usize serial=0;while(i<16){let usize added=ok(store::insert(
        ref mut s,ref mut roots,ref mut scratch,i,b"abc",limits(),ref mut fuel));if(i==15){serial=added;}i+=1;}
    let owners::Token lease=switch(store::begin_read(ref mut s,ref roots,ref scratch,serial,15,ref mut fuel)){
        case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    fuel=4096*store::read_cost();i=0;while(i<4096){assert(switch(store::read(
        ref s,ref roots,ref scratch,serial,15,1,ref mut fuel)){case .ok(v):{v==98}case .err(_):{false}});i+=1;}
    assert(fuel==0);fuel=store::read_cost()-1;
    assert(switch(store::read(ref s,ref roots,ref scratch,serial,15,99,ref mut fuel)){
        case .ok(_):{false}case .err(e):{tag(e)==1}});
    assert(fuel==store::read_cost()-1);fuel=store::read_cost();
    assert(switch(store::read(ref s,ref roots,ref scratch,serial,15,3,ref mut fuel)){
        case .ok(_):{false}case .err(e):{tag(e)==8}});assert(fuel==0);
    fuel=257;assert(switch(store::write(ref s,ref mut roots,ref mut scratch,serial,15,0,b"z",limits(),ref mut fuel)){
        case .ok(_):{false}case .err(e):{tag(e)==2}});assert(fuel==0);
    let usize ended=ok(store::end_read(ref mut s,ref roots,ref scratch,serial,15,lease));
    fuel=store::read_cost();assert(switch(store::read(ref s,ref roots,ref scratch,serial,15,0,ref mut fuel)){
        case .ok(v):{v==97}case .err(_):{false}});assert(fuel==0);
    assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0 && s.ledger.used==0);
}
