module tests::m2::value_root_leases;
import value_roots as store;
import buffer_owners as owners;
import buffer_growth as growth;
import std::bytes as bytes;
import std::vec as vec;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=32768,.engine=32768};}
fn usize ok(Result<usize,store::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn owners::Token lease(Result<owners::Token,store::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}
};}
fn u8 code(store::Error e){return switch(e){case .Fuel:{1}case .State:{2}case .Binding:{3}
    case .Serial:{4}case .Owners:{5}case .Quota:{6}case .Allocation:{7}case .Bounds:{8}};}
fn void error(Result<usize,store::Error> r,u8 expected){assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});}
fn void lease_error(Result<owners::Token,store::Error> r,u8 expected){assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});}
fn store::State opened(ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){
    return switch(store::open(roots,scratch,limits(),fuel)){case .ok(v):{v}case .err(_):{assert(false);opened(roots,scratch,fuel)}};
}
fn usize insert(ref mut store::State s,ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,
    usize binding,ref u8[] input,ref mut usize fuel){return ok(store::insert(s,roots,scratch,binding,input,limits(),fuel));}
fn void unchanged(ref store::State s,ref store::State before){
    assert(s.external==before.external && s.next==before.next && s.closed==before.closed && s.closing.active==before.closing.active);
    let growth::Ledger a=s.ledger;let growth::Ledger b=before.ledger;
    assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);
    var usize i=0;while(i<16){let store::Row x=s.rows[i];let store::Row y=before.rows[i];
        let owners::Owner p=s.table.slots[i];let owners::Owner q=before.table.slots[i];
        assert(x.serial==y.serial && x.binding==y.binding && x.slot==y.slot && x.generation==y.generation);
        assert(p.generation==q.generation && p.live==q.live && p.length==q.length && p.capacity==q.capacity && p.reading==q.reading);i+=1;
    }
}
fn void content(ref store::State s,ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> scratch,
    usize serial,usize binding,ref u8[] expected){
    var u8[16] output=[0;16];var usize fuel=4096;
    assert(ok(store::len(s,roots,scratch,serial,binding,ref mut fuel))==expected.len);
    assert(ok(store::copy_out(s,roots,scratch,serial,binding,0,ref mut output[..expected.len],ref mut fuel))==expected.len);
    assert(bytes::equal(ref output[..expected.len],expected));
}

@test fn void metadata_admission_refund_quota_fuel_overflow_and_legacy_defaults(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
    assert(s.external==0 && store::read_lease_cost()==256 && store::setup_cost()==32768 && store::metadata_charge()==4096);
    let usize serial=insert(ref mut s,ref mut roots,ref mut scratch,7,b"seed",ref mut fuel);
    let store::Snapshot initial=store::snapshot(ref s,ref roots);let store::State before=s;
    assert(initial.used==4224 && initial.count==1 && ok(store::write_cost(0))==256 && store::move_cost()==1024 && store::drop_cost()==1024);
    fuel=255;error(store::admit_metadata(ref mut s,ref roots,ref scratch,0,limits(),ref mut fuel),1);
    assert(fuel==255);unchanged(ref s,ref before);
    fuel=256;error(store::admit_metadata(ref mut s,ref roots,ref scratch,0,limits(),ref mut fuel),2);assert(fuel==0);
    fuel=256;error(store::admit_metadata(ref mut s,ref roots,ref scratch,65,limits(),ref mut fuel),2);assert(fuel==0);
    let growth::Limits instance=growth::Limits{.object=0,.instance=initial.used+63,.engine=32768};
    let growth::Limits engine=growth::Limits{.object=0,.instance=32768,.engine=initial.used+63};
    fuel=512;error(store::admit_metadata(ref mut s,ref roots,ref scratch,64,instance,ref mut fuel),6);
    error(store::admit_metadata(ref mut s,ref roots,ref scratch,64,engine,ref mut fuel),6);assert(fuel==0);unchanged(ref s,ref before);
    let growth::Limits unlimited=growth::Limits{.object=18446744073709551615,.instance=18446744073709551615,.engine=18446744073709551615};
    fuel=256;error(store::admit_metadata(ref mut s,ref roots,ref scratch,18446744073709551552,unlimited,ref mut fuel),8);
    assert(fuel==0);unchanged(ref s,ref before);
    // Independently checked engine overflow, malformed external alignment, base
    // metadata overflow and base+external+owner overflow all publish nothing.
    s.ledger.engine_used=18446744073709551615;s.ledger.engine_peak=18446744073709551615;let store::State engine_full=s;
    fuel=256;error(store::admit_metadata(ref mut s,ref roots,ref scratch,64,unlimited,ref mut fuel),8);
    unchanged(ref s,ref engine_full);s=before;
    var usize mode=0;while(mode<3){s.external=if(mode==0){1}else if(mode==1){18446744073709551552}else{18446744073709547456};
        s.ledger.used=18446744073709551552;s.ledger.engine_used=s.ledger.used;s.ledger.peak=s.ledger.used;s.ledger.engine_peak=s.ledger.used;
        let store::State corrupt=s;fuel=256;error(store::admit_metadata(ref mut s,ref roots,ref scratch,64,unlimited,ref mut fuel),2);
        unchanged(ref s,ref corrupt);s=before;mode+=1;
    }
    let growth::Limits exact=growth::Limits{.object=0,.instance=initial.used+64,.engine=initial.used+64};
    fuel=257;assert(ok(store::admit_metadata(ref mut s,ref roots,ref scratch,64,exact,ref mut fuel))==initial.used+64 && fuel==1);
    fuel=256;assert(ok(store::admit_metadata(ref mut s,ref roots,ref scratch,128,limits(),ref mut fuel))==initial.used+192 && fuel==0);
    let store::State admitted=s;assert(s.external==192 && s.ledger.peak==initial.used+192);
    error(store::release_metadata(ref mut s,ref roots,ref scratch,0),2);
    error(store::release_metadata(ref mut s,ref roots,ref scratch,1),2);
    error(store::release_metadata(ref mut s,ref roots,ref scratch,256),2);unchanged(ref s,ref admitted);
    assert(ok(store::release_metadata(ref mut s,ref roots,ref scratch,64))==initial.used+128 && s.external==128 && fuel==0);
    assert(ok(store::release_metadata(ref mut s,ref roots,ref scratch,128))==initial.used && s.external==0 && fuel==0);
    assert(s.ledger.peak==admitted.ledger.peak && s.ledger.engine_peak==admitted.ledger.engine_peak);
    let store::State refunded=s;error(store::release_metadata(ref mut s,ref roots,ref scratch,64),2);unchanged(ref s,ref refunded);
    content(ref s,ref roots,ref scratch,serial,7,b"seed");
    assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0 && fuel==0);
    let store::State closed=s;error(store::release_metadata(ref mut s,ref roots,ref scratch,64),2);
    fuel=256;error(store::admit_metadata(ref mut s,ref roots,ref scratch,64,limits(),ref mut fuel),2);
    unchanged(ref s,ref closed);assert(fuel==0 && ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0);
}

@test fn void exact_native_leases_block_mutation_and_prepaid_cleanup_orders_drain(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
    let usize a=insert(ref mut s,ref mut roots,ref mut scratch,7,b"seed",ref mut fuel);
    let usize b=insert(ref mut s,ref mut roots,ref mut scratch,9,b"B",ref mut fuel);
    let usize base=s.ledger.used;
    assert(ok(store::admit_metadata(ref mut s,ref roots,ref scratch,128,limits(),ref mut fuel))==base+128);
    let store::State before=s;let store::Row row=s.rows[0];
    fuel=255;lease_error(store::begin_read(ref mut s,ref roots,ref scratch,0,512,ref mut fuel),1);assert(fuel==255);
    fuel=256;lease_error(store::begin_read(ref mut s,ref roots,ref scratch,a,9,ref mut fuel),3);assert(fuel==0);
    fuel=256;lease_error(store::begin_read(ref mut s,ref roots,ref scratch,999,7,ref mut fuel),4);assert(fuel==0);
    s.table.slots[row.slot].length=3;let store::State wrong_extent=s;fuel=256;
    lease_error(store::begin_read(ref mut s,ref roots,ref scratch,a,7,ref mut fuel),2);unchanged(ref s,ref wrong_extent);s=before;
    fuel=256;let owners::Token token=lease(store::begin_read(ref mut s,ref roots,ref scratch,a,7,ref mut fuel));
    assert(fuel==0 && token.slot==row.slot && token.generation==row.generation && s.table.slots[row.slot].reading);
    let store::State reading=s;fuel=256;
    lease_error(store::begin_read(ref mut s,ref roots,ref scratch,a,7,ref mut fuel),2);assert(fuel==0);
    error(store::end_read(ref mut s,ref roots,ref scratch,a,9,token),3);
    error(store::end_read(ref mut s,ref roots,ref scratch,999,7,token),4);
    error(store::end_read(ref mut s,ref roots,ref scratch,b,9,token),2);
    error(store::end_read(ref mut s,ref roots,ref scratch,a,7,owners::Token{.slot=token.slot,.generation=token.generation+1}),2);
    s.table.slots[row.slot].length=3;error(store::end_read(ref mut s,ref roots,ref scratch,a,7,token),2);s=reading;
    content(ref s,ref roots,ref scratch,a,7,b"seed");fuel=100000;
    error(store::write(ref s,ref mut roots,ref mut scratch,a,7,0,b"X",limits(),ref mut fuel),2);
    error(store::write(ref s,ref mut roots,ref mut scratch,a,7,4,b"",limits(),ref mut fuel),2);
    error(store::append(ref mut s,ref mut roots,ref mut scratch,a,7,b"X",limits(),ref mut fuel),2);
    error(store::append(ref mut s,ref mut roots,ref mut scratch,a,7,b"",limits(),ref mut fuel),2);
    error(store::reserve(ref mut s,ref mut roots,ref mut scratch,a,7,64,limits(),ref mut fuel),2);
    error(store::reserve(ref mut s,ref mut roots,ref mut scratch,a,7,128,limits(),ref mut fuel),2);
    error(store::append_from(ref mut s,ref mut roots,ref mut scratch,a,7,b,9,limits(),ref mut fuel),2);
    error(store::move(ref mut s,ref mut roots,ref mut scratch,a,7,8,ref mut fuel),2);
    error(store::move(ref mut s,ref mut roots,ref mut scratch,a,7,7,ref mut fuel),2);
    error(store::drop(ref mut s,ref mut roots,ref mut scratch,a,7,ref mut fuel),2);
    // A writable tail would otherwise be destroyed before the leased first root.
    error(store::drain(ref mut s,ref mut roots,ref mut scratch),2);unchanged(ref s,ref reading);
    assert(vec::len<bytes::Buffer>(ref roots)==2 && vec::len<bytes::Buffer>(ref scratch)==0);
    fuel=0;assert(ok(store::end_read(ref mut s,ref roots,ref scratch,a,7,token))==token.slot && fuel==0);
    unchanged(ref s,ref before);error(store::end_read(ref mut s,ref roots,ref scratch,a,7,token),2);
    // Ordinary root operations preserve the admitted registry balance.
    fuel=100000;assert(ok(store::write(ref s,ref mut roots,ref mut scratch,a,7,0,b"S",limits(),ref mut fuel))==1);
    assert(ok(store::reserve(ref mut s,ref mut roots,ref mut scratch,a,7,128,limits(),ref mut fuel))==128);
    assert(ok(store::append(ref mut s,ref mut roots,ref mut scratch,a,7,b"!",limits(),ref mut fuel))==5);
    assert(ok(store::append_from(ref mut s,ref mut roots,ref mut scratch,a,7,b,9,limits(),ref mut fuel))==6);
    let owners::Token fresh=lease(store::begin_read(ref mut s,ref roots,ref scratch,a,7,ref mut fuel));
    error(store::end_read(ref mut s,ref roots,ref scratch,a,7,token),2);assert(s.table.slots[fresh.slot].reading);
    fuel=0;assert(ok(store::end_read(ref mut s,ref roots,ref scratch,a,7,fresh))==fresh.slot && fuel==0);
    fuel=100000;assert(ok(store::move(ref mut s,ref mut roots,ref mut scratch,a,7,8,ref mut fuel))==a);
    content(ref s,ref roots,ref scratch,a,8,b"Seed!B");assert(s.external==128);
    let usize remaining=s.ledger.used-192;
    assert(ok(store::drop(ref mut s,ref mut roots,ref mut scratch,a,8,ref mut fuel))==remaining && s.external==128);
    let usize c=insert(ref mut s,ref mut roots,ref mut scratch,8,b"C",ref mut fuel);assert(s.external==128);
    error(store::end_read(ref mut s,ref roots,ref scratch,a,8,fresh),4);
    let owners::Token last=lease(store::begin_read(ref mut s,ref roots,ref scratch,c,8,ref mut fuel));
    let store::State pending=s;error(store::drain(ref mut s,ref mut roots,ref mut scratch),2);unchanged(ref s,ref pending);
    fuel=0;let usize used=s.ledger.used;
    assert(ok(store::release_metadata(ref mut s,ref roots,ref scratch,128))==used-128 && s.external==0);
    let store::State unregistered=s;error(store::drain(ref mut s,ref mut roots,ref mut scratch),2);unchanged(ref s,ref unregistered);
    assert(ok(store::end_read(ref mut s,ref roots,ref scratch,c,8,last))==last.slot && fuel==0);
    content(ref s,ref roots,ref scratch,b,9,b"B");assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0 && fuel==0);
    assert(s.closed && s.external==0 && s.ledger.used==0 && vec::len<bytes::Buffer>(ref roots)==0);
}
