module tests::m2::value_buffer_roots;
import value_roots as store;
import buffer_owners as owners;
import buffer_growth as growth;
import std::bytes as bytes;
import std::vec as vec;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=32768,.engine=32768};}
fn usize ok(Result<usize,store::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 byte(Result<u8,store::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 code(store::Error e){return switch(e){case .Fuel:{1}case .State:{2}case .Binding:{3}case .Serial:{4}case .Owners:{5}case .Quota:{6}case .Allocation:{7}case .Bounds:{8}};}
fn void error(Result<usize,store::Error> r,u8 expected){assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});}
fn void byte_error(Result<u8,store::Error> r,u8 expected){assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});}
fn store::State opened(ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){
    return switch(store::open(roots,scratch,limits(),fuel)){case .ok(v):{v}case .err(_):{assert(false);opened(roots,scratch,fuel)}};
}
fn usize insert(ref mut store::State s,ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,usize binding,ref u8[] input,ref mut usize fuel){
    return ok(store::insert(s,roots,scratch,binding,input,limits(),fuel));
}
fn owners::Token token(store::Row row){return owners::Token{.slot=row.slot,.generation=row.generation};}
fn bool ledger(ref growth::Ledger a,ref growth::Ledger b){
    return a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used;
}
fn void unchanged(ref store::State s,ref store::State before){
    assert(s.next==before.next && s.closed==before.closed && s.closing.active==before.closing.active);
    assert(ledger(ref s.ledger,ref before.ledger));var usize i=0;
    while(i<16){let store::Row a=s.rows[i];let store::Row b=before.rows[i];
        let owners::Owner x=s.table.slots[i];let owners::Owner y=before.table.slots[i];
        assert(a.serial==b.serial && a.binding==b.binding && a.slot==b.slot && a.generation==b.generation);
        assert(x.generation==y.generation && x.live==y.live && x.length==y.length && x.capacity==y.capacity && x.reading==y.reading);i+=1;
    }
}
fn void content(ref store::State s,ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,ref u8[] expected){
    var u8[512] output=[0;512];var usize fuel=4096;assert(expected.len<=512);
    assert(ok(store::len(s,roots,scratch,serial,binding,ref mut fuel))==expected.len);
    assert(ok(store::copy_out(s,roots,scratch,serial,binding,0,ref mut output[..expected.len],ref mut fuel))==expected.len);
    assert(bytes::equal(ref output[..expected.len],expected));
}
fn void settled(ref store::State s,ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> scratch,usize count){
    assert(growth::settled(ref s.ledger) && !s.closing.active && vec::len<bytes::Buffer>(roots)==count && vec::len<bytes::Buffer>(scratch)==0);
}

@test fn void byte_operations_preserve_serial_binding_and_refresh_only_structural_tokens(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
    let usize left=insert(ref mut s,ref mut roots,ref mut scratch,1,b"left",ref mut fuel);
    let usize serial=insert(ref mut s,ref mut roots,ref mut scratch,7,b"abcd",ref mut fuel);
    let usize right=insert(ref mut s,ref mut roots,ref mut scratch,9,b"right",ref mut fuel);
    let store::State initial=s;let owners::Token original=token(s.rows[1]);
    fuel=256;assert(ok(store::len(ref s,ref roots,ref scratch,serial,7,ref mut fuel))==4 && fuel==0);
    fuel=257;assert(byte(store::read(ref s,ref roots,ref scratch,serial,7,3,ref mut fuel))==100 && fuel==0);
    fuel=258;assert(ok(store::write(ref s,ref mut roots,ref mut scratch,serial,7,1,b"XY",limits(),ref mut fuel))==2 && fuel==0);
    unchanged(ref s,ref initial);content(ref s,ref roots,ref scratch,serial,7,b"aXYd");
    fuel=2064;assert(ok(store::reserve(ref mut s,ref mut roots,ref mut scratch,serial,7,128,limits(),ref mut fuel))==128 && fuel==0);
    assert(s.rows[1].serial==serial && s.rows[1].binding==7 && s.rows[1].slot==original.slot && s.rows[1].generation==original.generation+1);
    assert(!owners::describe(ref s.table,original).is_ok);content(ref s,ref roots,ref scratch,serial,7,b"aXYd");
    let owners::Token reserved=token(s.rows[1]);fuel=2072;
    assert(ok(store::append(ref mut s,ref mut roots,ref mut scratch,serial,7,b"EF",limits(),ref mut fuel))==6 && fuel==0);
    assert(s.rows[1].generation==reserved.generation+1 && !owners::describe(ref s.table,reserved).is_ok);
    let store::State changed=s;content(ref s,ref roots,ref scratch,serial,7,b"aXYdEF");
    fuel=2072;assert(ok(store::append(ref mut s,ref mut roots,ref mut scratch,serial,7,b"",limits(),ref mut fuel))==6 && fuel==0);
    fuel=2072;assert(ok(store::reserve(ref mut s,ref mut roots,ref mut scratch,serial,7,64,limits(),ref mut fuel))==128 && fuel==0);
    fuel=256;assert(ok(store::write(ref s,ref mut roots,ref mut scratch,serial,7,6,b"",limits(),ref mut fuel))==0 && fuel==0);
    unchanged(ref s,ref changed);
    // A legitimate shared read lease permits immutable observations only. Even
    // no-op mutations must authenticate writable ownership before native access.
    let owners::Token shared=token(s.rows[1]);let growth::Ledger lease_ledger=s.ledger;
    assert(owners::begin_read(ref mut s.table,shared,vec::at<bytes::Buffer>(ref roots,1),ref lease_ledger).is_ok);
    let store::State leased=s;fuel=100000;
    assert(ok(store::len(ref s,ref roots,ref scratch,serial,7,ref mut fuel))==6);
    assert(byte(store::read(ref s,ref roots,ref scratch,serial,7,4,ref mut fuel))==69);
    error(store::write(ref s,ref mut roots,ref mut scratch,serial,7,0,b"Z",limits(),ref mut fuel),2);
    error(store::write(ref s,ref mut roots,ref mut scratch,serial,7,6,b"",limits(),ref mut fuel),2);
    error(store::append(ref mut s,ref mut roots,ref mut scratch,serial,7,b"",limits(),ref mut fuel),2);
    error(store::reserve(ref mut s,ref mut roots,ref mut scratch,serial,7,128,limits(),ref mut fuel),2);
    unchanged(ref s,ref leased);content(ref s,ref roots,ref scratch,serial,7,b"aXYdEF");
    assert(owners::end_read(ref mut s.table,shared).is_ok);unchanged(ref s,ref changed);
    content(ref s,ref roots,ref scratch,left,1,b"left");content(ref s,ref roots,ref scratch,right,9,b"right");
    settled(ref s,ref roots,ref scratch,3);assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0);
}

@test fn void growth_fallback_and_transient_quotas_preserve_actual_roots_on_rejection(){
    // Three independent minimum fallbacks and one ordinary preferred growth.
    // These are policy boundaries with real allocations, never injected OOM.
    var usize mode=0;while(mode<4){
        var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
        var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
        let usize left=insert(ref mut s,ref mut roots,ref mut scratch,1,b"L",ref mut fuel);
        let usize serial=insert(ref mut s,ref mut roots,ref mut scratch,7,b"seed",ref mut fuel);
        let usize right=insert(ref mut s,ref mut roots,ref mut scratch,9,b"R",ref mut fuel);
        assert(ok(store::reserve(ref mut s,ref mut roots,ref mut scratch,serial,7,256,limits(),ref mut fuel))==256);
        let store::State before=s;let usize used=s.ledger.used;let owners::Token old=token(s.rows[1]);
        let growth::Limits instance=growth::Limits{.object=4096,.instance=used+383,.engine=32768};
        let growth::Limits engine=growth::Limits{.object=4096,.instance=32768,.engine=used+383};
        let growth::Limits object=growth::Limits{.object=319,.instance=32768,.engine=32768};
        error(store::reserve(ref mut s,ref mut roots,ref mut scratch,serial,7,257,instance,ref mut fuel),6);
        error(store::reserve(ref mut s,ref mut roots,ref mut scratch,serial,7,257,engine,ref mut fuel),6);
        error(store::reserve(ref mut s,ref mut roots,ref mut scratch,serial,7,257,object,ref mut fuel),6);
        let u8[253] suffix=[90;253];
        error(store::append(ref mut s,ref mut roots,ref mut scratch,serial,7,ref suffix,instance,ref mut fuel),6);
        unchanged(ref s,ref before);settled(ref s,ref roots,ref scratch,3);
        content(ref s,ref roots,ref scratch,serial,7,b"seed");
        let growth::Limits cap=if(mode==0){growth::Limits{.object=320,.instance=32768,.engine=32768}}
            else if(mode==1){growth::Limits{.object=4096,.instance=used+384,.engine=32768}}
            else if(mode==2){growth::Limits{.object=4096,.instance=32768,.engine=used+384}}else{limits()};
        let usize capacity=if(mode<3){320}else{384};
        assert(ok(store::reserve(ref mut s,ref mut roots,ref mut scratch,serial,7,257,cap,ref mut fuel))==capacity);
        assert(s.ledger.used==used-256+capacity && s.ledger.peak==used+capacity+64 && growth::settled(ref s.ledger));
        assert(s.rows[1].serial==serial && s.rows[1].binding==7 && s.rows[1].generation==old.generation+1);
        assert(!owners::describe(ref s.table,old).is_ok);
        assert(ok(store::append(ref mut s,ref mut roots,ref mut scratch,serial,7,ref suffix,cap,ref mut fuel))==257);
        var u8[257] expected=[90;257];expected[0]=115;expected[1]=101;expected[2]=101;expected[3]=100;
        content(ref s,ref roots,ref scratch,serial,7,ref expected);
        content(ref s,ref roots,ref scratch,left,1,b"L");content(ref s,ref roots,ref scratch,right,9,b"R");
        settled(ref s,ref roots,ref scratch,3);assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0);mode+=1;
    }
}

@test fn void fuel_authentication_generation_exhaustion_and_repeated_retirement_are_atomic(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
    let usize serial=insert(ref mut s,ref mut roots,ref mut scratch,7,b"abc",ref mut fuel);let store::State initial=s;
    fuel=255;error(store::len(ref s,ref roots,ref scratch,0,512,ref mut fuel),1);assert(fuel==255);
    fuel=256;byte_error(store::read(ref s,ref roots,ref scratch,0,512,0,ref mut fuel),1);assert(fuel==256);
    fuel=256;error(store::write(ref s,ref mut roots,ref mut scratch,0,512,0,b"X",limits(),ref mut fuel),1);assert(fuel==256);
    fuel=2059;error(store::reserve(ref mut s,ref mut roots,ref mut scratch,serial,7,128,limits(),ref mut fuel),1);assert(fuel==1803);
    fuel=2063;error(store::append(ref mut s,ref mut roots,ref mut scratch,serial,7,b"X",limits(),ref mut fuel),1);assert(fuel==1807);
    unchanged(ref s,ref initial);content(ref s,ref roots,ref scratch,serial,7,b"abc");
    fuel=256;error(store::len(ref s,ref roots,ref scratch,0,7,ref mut fuel),3);assert(fuel==0);
    fuel=257;byte_error(store::read(ref s,ref roots,ref scratch,serial,9,0,ref mut fuel),3);assert(fuel==0);
    fuel=257;error(store::write(ref s,ref mut roots,ref mut scratch,serial,9,0,b"X",limits(),ref mut fuel),3);assert(fuel==0);
    fuel=9999;error(store::reserve(ref mut s,ref mut roots,ref mut scratch,999,7,128,limits(),ref mut fuel),4);assert(fuel==9743);
    fuel=9999;error(store::append(ref mut s,ref mut roots,ref mut scratch,serial,9,b"X",limits(),ref mut fuel),3);assert(fuel==9743);
    fuel=257;byte_error(store::read(ref s,ref roots,ref scratch,serial,7,3,ref mut fuel),8);assert(fuel==0);
    fuel=258;error(store::write(ref s,ref mut roots,ref mut scratch,serial,7,2,b"XY",limits(),ref mut fuel),8);assert(fuel==0);
    fuel=256;error(store::write(ref s,ref mut roots,ref mut scratch,serial,7,18446744073709551615,b"",limits(),ref mut fuel),8);
    unchanged(ref s,ref initial);fuel=256;assert(ok(store::len(ref s,ref roots,ref scratch,serial,7,ref mut fuel))==3 && fuel==0);
    fuel=257;assert(byte(store::read(ref s,ref roots,ref scratch,serial,7,0,ref mut fuel))==97 && fuel==0);
    fuel=257;assert(ok(store::write(ref s,ref mut roots,ref mut scratch,serial,7,0,b"A",limits(),ref mut fuel))==1 && fuel==0);
    fuel=2060;assert(ok(store::reserve(ref mut s,ref mut roots,ref mut scratch,serial,7,128,limits(),ref mut fuel))==128 && fuel==0);
    fuel=2064;assert(ok(store::append(ref mut s,ref mut roots,ref mut scratch,serial,7,b"!",limits(),ref mut fuel))==4 && fuel==0);
    content(ref s,ref roots,ref scratch,serial,7,b"Abc!");
    // Trusted fixture advances both current token records to their terminal
    // generation. Structural mutations reject before touching native storage.
    let usize slot=s.rows[0].slot;s.rows[0].generation=18446744073709551615;s.table.slots[slot].generation=18446744073709551615;
    let store::State exhausted=s;fuel=100000;
    error(store::reserve(ref mut s,ref mut roots,ref mut scratch,serial,7,129,limits(),ref mut fuel),5);
    error(store::append(ref mut s,ref mut roots,ref mut scratch,serial,7,b"?",limits(),ref mut fuel),5);
    unchanged(ref s,ref exhausted);content(ref s,ref roots,ref scratch,serial,7,b"Abc!");
    assert(ok(store::reserve(ref mut s,ref mut roots,ref mut scratch,serial,7,128,limits(),ref mut fuel))==128);
    assert(ok(store::append(ref mut s,ref mut roots,ref mut scratch,serial,7,b"",limits(),ref mut fuel))==4);
    assert(ok(store::write(ref s,ref mut roots,ref mut scratch,serial,7,3,b"?",limits(),ref mut fuel))==1);
    assert(s.rows[0].generation==18446744073709551615);
    let growth::Ledger before_moves=s.ledger;var usize current=7;var usize i=0;
    while(i<8){let usize destination=if(current==7){511}else{7};fuel=1024;
        assert(ok(store::move(ref mut s,ref mut roots,ref mut scratch,serial,current,destination,ref mut fuel))==serial && fuel==0);
        fuel=256;error(store::len(ref s,ref roots,ref scratch,serial,current,ref mut fuel),3);
        assert(s.rows[0].serial==serial && s.rows[0].generation==18446744073709551615 && ledger(ref s.ledger,ref before_moves));
        current=destination;content(ref s,ref roots,ref scratch,serial,current,b"Abc?");settled(ref s,ref roots,ref scratch,1);i+=1;
    }
    fuel=1024;assert(ok(store::drop(ref mut s,ref mut roots,ref mut scratch,serial,current,ref mut fuel))==store::metadata_charge() && fuel==0);
    assert(s.table.slots[slot].generation==0 && !s.table.slots[slot].live);fuel=256;
    error(store::len(ref s,ref roots,ref scratch,serial,current,ref mut fuel),4);
    fuel=1024;error(store::drop(ref mut s,ref mut roots,ref mut scratch,serial,current,ref mut fuel),4);
    fuel=100000;let usize replacement=insert(ref mut s,ref mut roots,ref mut scratch,current,b"new",ref mut fuel);
    assert(replacement>serial && s.rows[0].slot!=slot);fuel=256;
    error(store::len(ref s,ref roots,ref scratch,serial,current,ref mut fuel),4);content(ref s,ref roots,ref scratch,replacement,current,b"new");
    fuel=0;assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0 && fuel==0);
    assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0 && s.closed && s.ledger.used==0 && s.ledger.engine_used==0);
    settled(ref s,ref roots,ref scratch,0);
}
