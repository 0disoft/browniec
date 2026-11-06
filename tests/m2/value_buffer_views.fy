module tests::m2::value_buffer_views;
import value_buffer_views as views;
import value_roots as roots;
import buffer_growth as growth;
import std::bytes as bytes;
import std::vec as vec;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=32768,.engine=32768};}
fn usize root_ok(Result<usize,roots::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize ok(Result<usize,views::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn views::Ticket ticket(Result<views::Ticket,views::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);views::Ticket{.slot=32,.generation=0}}};}
fn u8 byte(Result<u8,views::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 code(views::Error e){return switch(e){case .Fuel:{1}case .State:{2}case .Binding:{3}case .Stale:{4}case .Capacity:{5}case .Bounds:{6}case .Quota:{7}case .Allocation:{8}};}
fn void error(Result<usize,views::Error> r,u8 expected){assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});}
fn void ticket_error(Result<views::Ticket,views::Error> r,u8 expected){assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});}
fn void byte_error(Result<u8,views::Error> r,u8 expected){assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});}
fn void pool_error(Result<views::Pool,views::Error> r,u8 expected){switch(r){case .ok(_):{assert(false);}case .err(e):{assert(code(e)==expected);}};}
fn roots::State root_open(ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){return switch(roots::open(data,scratch,limits(),fuel)){case .ok(v):{v}case .err(_):{assert(false);root_open(data,scratch,fuel)}};}
fn views::Pool opened(ref mut roots::State s,ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){return switch(views::open(s,data,scratch,limits(),fuel)){case .ok(v):{v}case .err(_):{assert(false);opened(s,data,scratch,fuel)}};}
fn usize insert(ref mut roots::State s,ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,usize binding,ref u8[] input,ref mut usize fuel){return root_ok(roots::insert(s,data,scratch,binding,input,limits(),fuel));}
fn void state(ref views::Pool p,usize live,usize count,bool closed){let views::Snapshot v=views::snapshot(p);assert(v.live==live && v.roots==count && v.closed==closed);}
fn void content(ref views::Pool p,ref roots::State s,ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,views::Ticket t,usize binding,ref u8[] expected){
    var u8[16] out=[0;16];assert(expected.len<=16);var usize fuel=views::length_cost();assert(ok(views::length(p,s,data,scratch,t,binding,ref mut fuel))==expected.len && fuel==0);
    fuel=ok(views::copy_cost(expected.len));assert(ok(views::copy_out(p,s,data,scratch,t,binding,ref mut out[..expected.len],ref mut fuel))==expected.len && fuel==0);
    assert(bytes::equal(ref out[..expected.len],expected));
    var usize i=0;while(i<expected.len){fuel=views::read_cost();assert(byte(views::read(p,s,data,scratch,t,binding,i,ref mut fuel))==expected[i] && fuel==0);i+=1;}
}
fn void unchanged(ref roots::State s,ref roots::State before){
    assert(s.next==before.next && s.closed==before.closed && s.external==before.external && s.ledger.used==before.ledger.used && s.ledger.engine_used==before.ledger.engine_used && s.ledger.peak==before.ledger.peak && s.ledger.engine_peak==before.ledger.engine_peak && growth::settled(ref s.ledger));
    var usize i=0;while(i<16){assert(s.rows[i].serial==before.rows[i].serial && s.rows[i].binding==before.rows[i].binding && s.rows[i].slot==before.rows[i].slot && s.rows[i].generation==before.rows[i].generation);
    assert(s.table.slots[i].reading==before.table.slots[i].reading && s.table.slots[i].generation==before.table.slots[i].generation && s.table.slots[i].live==before.table.slots[i].live);i+=1;}
}

@test fn void actual_nested_ranges_aliases_and_compaction_pin_until_last_close(){
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var roots::State s=root_open(ref mut data,ref mut scratch,ref mut fuel);let usize left=insert(ref mut s,ref mut data,ref mut scratch,1,b"L",ref mut fuel);
    let usize serial=insert(ref mut s,ref mut data,ref mut scratch,7,b"abcdef",ref mut fuel);
    var views::Pool p=opened(ref mut s,ref data,ref scratch,ref mut fuel);
    assert(views::capacity()==32 && views::metadata_charge()==4096 && views::begin_cost()==512 && views::range_cost()==512 && views::move_cost()==256 && views::length_cost()==256 && views::read_cost()==513 && ok(views::copy_cost(4))==516);
    fuel=768;let views::Ticket parent=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,7,1,5,ref mut fuel));assert(fuel==0);
    fuel=512;let views::Ticket full=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,8,0,6,ref mut fuel));assert(fuel==0);state(ref p,2,1,false);
    fuel=512;let views::Ticket nested=ticket(views::range(ref mut p,ref mut s,ref data,ref scratch,parent,7,9,1,3,ref mut fuel));assert(fuel==0);
    fuel=512;let views::Ticket empty=ticket(views::range(ref mut p,ref mut s,ref data,ref scratch,nested,9,0,2,2,ref mut fuel));assert(fuel==0);
    fuel=512;let views::Ticket alias=ticket(views::alias(ref mut p,ref mut s,ref data,ref scratch,nested,9,11,ref mut fuel));assert(fuel==0);
    fuel=256;let views::Ticket moved=ticket(views::move(ref mut p,ref mut s,ref data,ref scratch,alias,11,511,ref mut fuel));assert(fuel==0);fuel=256;
    error(views::length(ref p,ref s,ref data,ref scratch,moved,11,ref mut fuel),3);
    content(ref p,ref s,ref data,ref scratch,parent,7,b"bcde");content(ref p,ref s,ref data,ref scratch,nested,9,b"cd");content(ref p,ref s,ref data,ref scratch,empty,0,b"");
    content(ref p,ref s,ref data,ref scratch,moved,511,b"cd");
    fuel=513;byte_error(views::read(ref p,ref s,ref data,ref scratch,empty,0,0,ref mut fuel),6);assert(fuel==257);
    fuel=100000;let usize dropped=root_ok(roots::drop(ref mut s,ref mut data,ref mut scratch,left,1,ref mut fuel));assert(s.rows[0].serial==serial);
    content(ref p,ref s,ref data,ref scratch,moved,511,b"cd");
    let usize a=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,parent,7));let usize b=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,full,8));
    let usize c=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,nested,9));state(ref p,2,1,false);
    content(ref p,ref s,ref data,ref scratch,moved,511,b"cd");let roots::State pinned=s;fuel=100000;
    assert(!roots::write(ref s,ref mut data,ref mut scratch,serial,7,0,b"X",limits(),ref mut fuel).is_ok);
    assert(!roots::write(ref s,ref mut data,ref mut scratch,serial,7,6,b"",limits(),ref mut fuel).is_ok);
    assert(!roots::reserve(ref mut s,ref mut data,ref mut scratch,serial,7,0,limits(),ref mut fuel).is_ok);
    assert(!roots::append(ref mut s,ref mut data,ref mut scratch,serial,7,b"",limits(),ref mut fuel).is_ok);
    assert(!roots::append(ref mut s,ref mut data,ref mut scratch,serial,7,b"!",limits(),ref mut fuel).is_ok);assert(!roots::move(ref mut s,ref mut data,ref mut scratch,serial,7,13,ref mut fuel).is_ok);
    assert(!roots::drop(ref mut s,ref mut data,ref mut scratch,serial,7,ref mut fuel).is_ok);unchanged(ref s,ref pinned);
    let usize d=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,moved,511));state(ref p,1,1,false);content(ref p,ref s,ref data,ref scratch,empty,0,b"");
    assert(!roots::write(ref s,ref mut data,ref mut scratch,serial,7,0,b"X",limits(),ref mut fuel).is_ok);
    fuel=0;let usize e=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,empty,0));assert(fuel==0);state(ref p,0,0,false);fuel=100000;
    assert(root_ok(roots::write(ref s,ref mut data,ref mut scratch,serial,7,0,b"X",limits(),ref mut fuel))==1);
    let usize reserved=root_ok(roots::reserve(ref mut s,ref mut data,ref mut scratch,serial,7,0,limits(),ref mut fuel));
    assert(root_ok(roots::append(ref mut s,ref mut data,ref mut scratch,serial,7,b"!",limits(),ref mut fuel))==7);
    assert(root_ok(roots::move(ref mut s,ref mut data,ref mut scratch,serial,7,13,ref mut fuel))==serial);
    let usize removed=root_ok(roots::drop(ref mut s,ref mut data,ref mut scratch,serial,13,ref mut fuel));let usize shut=ok(views::shutdown(ref mut p,ref mut s,ref data,ref scratch));
    assert(root_ok(roots::drain(ref mut s,ref mut data,ref mut scratch))==0);
}

@test fn void rejected_fuel_bindings_bounds_and_descriptor_exhaustion_roll_back(){
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var roots::State s=root_open(ref mut data,ref mut scratch,ref mut fuel);let usize serial=insert(ref mut s,ref mut data,ref mut scratch,7,b"abcd",ref mut fuel);
    let usize other=insert(ref mut s,ref mut data,ref mut scratch,9,b"other",ref mut fuel);let roots::State unopened=s;
    fuel=255;pool_error(views::open(ref mut s,ref data,ref scratch,limits(),ref mut fuel),1);assert(fuel==255);unchanged(ref s,ref unopened);
    var usize mode=0;while(mode<2){let growth::Limits tight=growth::Limits{.object=4096,.instance=if(mode==0){s.ledger.used+4095}else{32768},.engine=if(mode==1){s.ledger.engine_used+4095}else{32768}};
    fuel=256;pool_error(views::open(ref mut s,ref data,ref scratch,tight,ref mut fuel),7);assert(fuel==0);unchanged(ref s,ref unopened);mode+=1;}
    fuel=256;var views::Pool p=opened(ref mut s,ref data,ref scratch,ref mut fuel);assert(fuel==0);let roots::State unleased=s;
    fuel=511;ticket_error(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,7,0,4,ref mut fuel),1);assert(fuel==511);
    fuel=767;ticket_error(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,7,0,4,ref mut fuel),1);assert(fuel==255);state(ref p,0,0,false);unchanged(ref s,ref unleased);
    fuel=100000;ticket_error(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,8,7,0,4,ref mut fuel),3);
    ticket_error(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,512,0,4,ref mut fuel),3);
    ticket_error(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,7,3,2,ref mut fuel),6);
    ticket_error(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,7,0,5,ref mut fuel),6);
    ticket_error(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,7,0,18446744073709551615,ref mut fuel),6);unchanged(ref s,ref unleased);
    fuel=768;let views::Ticket first=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,7,0,4,ref mut fuel));assert(fuel==0);fuel=512;
    let views::Ticket second=ticket(views::alias(ref mut p,ref mut s,ref data,ref scratch,first,7,8,ref mut fuel));assert(fuel==0);let roots::State before=s;
    fuel=100000;ticket_error(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,8,0,4,ref mut fuel),3);
    ticket_error(views::alias(ref mut p,ref mut s,ref data,ref scratch,first,8,10,ref mut fuel),3);ticket_error(views::move(ref mut p,ref mut s,ref data,ref scratch,first,7,8,ref mut fuel),3);
    ticket_error(views::range(ref mut p,ref mut s,ref data,ref scratch,first,7,10,4,3,ref mut fuel),6);
    ticket_error(views::range(ref mut p,ref mut s,ref data,ref scratch,first,7,10,0,5,ref mut fuel),6);
    ticket_error(views::range(ref mut p,ref mut s,ref data,ref scratch,first,7,10,18446744073709551615,18446744073709551615,ref mut fuel),6);
    fuel=511;ticket_error(views::range(ref mut p,ref mut s,ref data,ref scratch,first,7,10,0,4,ref mut fuel),1);assert(fuel==511);
    ticket_error(views::alias(ref mut p,ref mut s,ref data,ref scratch,first,7,10,ref mut fuel),1);assert(fuel==511);
    fuel=255;ticket_error(views::move(ref mut p,ref mut s,ref data,ref scratch,first,7,10,ref mut fuel),1);assert(fuel==255);
    error(views::length(ref p,ref s,ref data,ref scratch,first,7,ref mut fuel),1);assert(fuel==255);
    // Root admission is a second payment; already consumed view Fuel stays spent.
    fuel=512;byte_error(views::read(ref p,ref s,ref data,ref scratch,first,7,0,ref mut fuel),1);assert(fuel==256);fuel=513;
    byte_error(views::read(ref p,ref s,ref data,ref scratch,first,7,4,ref mut fuel),6);assert(fuel==257);
    var u8[5] output=[85;5];let u8[5] untouched=[85;5];fuel=515;error(views::copy_out(ref p,ref s,ref data,ref scratch,first,7,ref mut output[..4],ref mut fuel),1);assert(fuel==259);
    fuel=100000;error(views::copy_out(ref p,ref s,ref data,ref scratch,first,7,ref mut output[..3],ref mut fuel),6);
    error(views::copy_out(ref p,ref s,ref data,ref scratch,first,7,ref mut output[..5],ref mut fuel),6);assert(bytes::equal(ref output,ref untouched));error(views::copy_cost(18446744073709551615),6);
    error(views::length(ref p,ref s,ref data,ref scratch,views::Ticket{.slot=32,.generation=first.generation},7,ref mut fuel),4);
    error(views::length(ref p,ref s,ref data,ref scratch,views::Ticket{.slot=first.slot,.generation=0},7,ref mut fuel),4);error(views::close(ref mut p,ref mut s,ref data,ref scratch,first,8),3);
    state(ref p,2,1,false);unchanged(ref s,ref before);content(ref p,ref s,ref data,ref scratch,first,7,b"abcd");
    var usize i=2;fuel=100000;while(i<32){let views::Ticket extra=ticket(views::alias(ref mut p,ref mut s,ref data,ref scratch,first,7,20+i,ref mut fuel));i+=1;}state(ref p,32,1,false);
    let roots::State full=s;
    ticket_error(views::alias(ref mut p,ref mut s,ref data,ref scratch,first,7,100,ref mut fuel),5);ticket_error(views::begin(ref mut p,ref mut s,ref data,ref scratch,other,9,100,0,5,ref mut fuel),5);
    state(ref p,32,1,false);unchanged(ref s,ref full);
    let usize closed=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,first,7));
    let views::Ticket replacement=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,other,9,7,0,5,ref mut fuel));
    assert(replacement.slot==first.slot && replacement.generation>first.generation);
    // Forged generations reject before the native metadata retirement probe.
    error(views::length(ref p,ref s,ref data,ref scratch,first,7,ref mut fuel),4);error(views::close(ref mut p,ref mut s,ref data,ref scratch,first,7),4);
    error(views::length(ref p,ref s,ref data,ref scratch,views::Ticket{.slot=replacement.slot,.generation=18446744073709551615},7,ref mut fuel),4);
    content(ref p,ref s,ref data,ref scratch,replacement,7,b"other");content(ref p,ref s,ref data,ref scratch,second,8,b"abcd");state(ref p,32,2,false);
    // Trusted native fault injection reaches exhaustion without 2^64 closes.
    var views::Row terminal=p.rows[replacement.slot];terminal.generation=18446744073709551615;p.rows[replacement.slot]=terminal;
    let views::Ticket last=views::Ticket{.slot=replacement.slot,.generation=18446744073709551615};
    content(ref p,ref s,ref data,ref scratch,last,7,b"other");
    let usize retired=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,last,7));
    assert(p.rows[replacement.slot].generation==0 && !p.rows[replacement.slot].live);state(ref p,31,1,false);
    ticket_error(views::begin(ref mut p,ref mut s,ref data,ref scratch,other,9,7,0,5,ref mut fuel),5);
    error(views::length(ref p,ref s,ref data,ref scratch,last,7,ref mut fuel),4);fuel=0;
    let usize shut=ok(views::shutdown(ref mut p,ref mut s,ref data,ref scratch));assert(root_ok(roots::drain(ref mut s,ref mut data,ref mut scratch))==0 && fuel==0);
}

@test fn void zero_fuel_shutdown_refunds_metadata_and_restores_actual_root_quota(){
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var roots::State s=root_open(ref mut data,ref mut scratch,ref mut fuel);let usize first=insert(ref mut s,ref mut data,ref mut scratch,7,b"keep",ref mut fuel);
    let usize second=insert(ref mut s,ref mut data,ref mut scratch,9,b"next",ref mut fuel);let usize used=s.ledger.used;let usize engine=s.ledger.engine_used;
    fuel=256;var views::Pool p=opened(ref mut s,ref data,ref scratch,ref mut fuel);assert(fuel==0 && s.ledger.used==used+4096 && s.ledger.engine_used==engine+4096);state(ref p,0,0,false);
    fuel=100000;let views::Ticket a=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,first,7,7,0,4,ref mut fuel));
    let views::Ticket b=ticket(views::alias(ref mut p,ref mut s,ref data,ref scratch,a,7,8,ref mut fuel));
    let views::Ticket c=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,second,9,9,1,4,ref mut fuel));state(ref p,3,2,false);
    let growth::Limits tight=growth::Limits{.object=4096,.instance=used+64,.engine=engine+64};let roots::State held=s;
    assert(!roots::insert(ref mut s,ref mut data,ref mut scratch,11,b"",tight,ref mut fuel).is_ok);assert(!roots::drain(ref mut s,ref mut data,ref mut scratch).is_ok);unchanged(ref s,ref held);
    fuel=0;let usize released=ok(views::shutdown(ref mut p,ref mut s,ref data,ref scratch));assert(fuel==0 && s.ledger.used==used && s.ledger.engine_used==engine && growth::settled(ref s.ledger));
    state(ref p,0,0,true);
    let roots::State closed=s;let usize again=ok(views::shutdown(ref mut p,ref mut s,ref data,ref scratch));assert(fuel==0);unchanged(ref s,ref closed);state(ref p,0,0,true);
    fuel=100000;error(views::length(ref p,ref s,ref data,ref scratch,b,8,ref mut fuel),2);ticket_error(views::begin(ref mut p,ref mut s,ref data,ref scratch,first,7,7,0,4,ref mut fuel),2);
    error(views::close(ref mut p,ref mut s,ref data,ref scratch,c,9),2);
    let usize admitted=root_ok(roots::insert(ref mut s,ref mut data,ref mut scratch,11,b"",tight,ref mut fuel));assert(admitted>second && s.ledger.used==used+64 && s.ledger.engine_used==engine+64);
    assert(root_ok(roots::write(ref s,ref mut data,ref mut scratch,first,7,0,b"K",limits(),ref mut fuel))==1);
    assert(root_ok(roots::write(ref s,ref mut data,ref mut scratch,second,9,0,b"N",limits(),ref mut fuel))==1);
    fuel=0;assert(root_ok(roots::drain(ref mut s,ref mut data,ref mut scratch))==0 && fuel==0 && s.closed && s.ledger.used==0 && s.ledger.engine_used==0);
    assert(vec::len<bytes::Buffer>(ref data)==0 && vec::len<bytes::Buffer>(ref scratch)==0);let usize final=ok(views::shutdown(ref mut p,ref mut s,ref data,ref scratch));
    assert(root_ok(roots::drain(ref mut s,ref mut data,ref mut scratch))==0 && fuel==0);
}
