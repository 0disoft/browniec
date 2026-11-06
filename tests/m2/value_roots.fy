module tests::m2::value_roots;
import value_roots as store;
import buffer_growth as growth;
import std::bytes as bytes;
import std::vec as vec;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=32768,.engine=32768};}
fn store::State opened(ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){
    return switch(store::open(roots,scratch,limits(),fuel)){
        case .ok(v):{v}case .err(_):{assert(false);opened(roots,scratch,fuel)}
    };
}
fn usize ok(Result<usize,store::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize inserted(ref mut store::State state,ref mut vec::Vec<bytes::Buffer> roots,
    ref mut vec::Vec<bytes::Buffer> scratch,usize binding,ref u8[] input,ref mut usize fuel){
    return ok(store::insert(state,roots,scratch,binding,input,limits(),fuel));
}
fn void content(ref store::State state,ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> scratch,
    usize serial,usize binding,ref u8[] expected){
    var u8[16] data=[0;16];var usize fuel=1000;
    assert(ok(store::copy_out(state,roots,scratch,serial,binding,0,ref mut data[..expected.len],ref mut fuel))==expected.len);
    assert(bytes::equal(ref data[..expected.len],expected));
}
@test fn void allocated_root_moves_with_exact_token_charge_and_original_data(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
    let usize serial=inserted(ref mut s,ref mut roots,ref mut scratch,0,b"keep",ref mut fuel);
    let store::Snapshot before=store::snapshot(ref s,ref roots);let store::Row original=s.rows[0];
    assert(before.count==1 && before.used==store::metadata_charge()+128);
    fuel=store::move_cost();assert(ok(store::move(ref mut s,ref mut roots,ref mut scratch,serial,0,511,ref mut fuel))==serial && fuel==0);
    assert(s.rows[0].slot==original.slot && s.rows[0].generation==original.generation);
    assert(store::snapshot(ref s,ref roots).used==before.used && store::snapshot(ref s,ref roots).peak==before.peak);
    assert(!store::describe(ref s,ref roots,ref scratch,serial,0).is_ok);
    content(ref s,ref roots,ref scratch,serial,511,b"keep");fuel=store::move_cost()+1;
    assert(ok(store::move(ref mut s,ref mut roots,ref mut scratch,serial,511,3,ref mut fuel))==serial && fuel==1);
    content(ref s,ref roots,ref scratch,serial,3,b"keep");
    assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0);
    assert(store::snapshot(ref s,ref roots).used==0 && store::snapshot(ref s,ref roots).closed);
}
@test fn void middle_removal_preserves_all_other_actual_allocations_and_bindings(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
    var usize[16] serials=[0;16];let u8[16] values=[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15];var usize i=0;
    while(i<16){let u8[1] byte=[values[i]];serials[i]=inserted(ref mut s,ref mut roots,ref mut scratch,i,ref byte,ref mut fuel);i+=1;}
    assert(store::snapshot(ref s,ref roots).count==16);
    assert(!store::insert(ref mut s,ref mut roots,ref mut scratch,16,b"x",limits(),ref mut fuel).is_ok);
    let usize first=serials[0];assert(ok(store::move(ref mut s,ref mut roots,ref mut scratch,first,0,31,ref mut fuel))==first);
    assert(ok(store::drop(ref mut s,ref mut roots,ref mut scratch,serials[7],7,ref mut fuel))==store::metadata_charge()+15*128);
    i=0;while(i<16){if(i!=7){let u8[1] byte=[values[i]];content(ref s,ref roots,ref scratch,serials[i],if(i==0){31}else{i},ref byte);}i+=1;}
    let usize reused=inserted(ref mut s,ref mut roots,ref mut scratch,7,b"new",ref mut fuel);assert(reused>serials[15]);
    assert(!store::describe(ref s,ref roots,ref scratch,serials[7],7).is_ok);
    assert(ok(store::drop(ref mut s,ref mut roots,ref mut scratch,first,31,ref mut fuel))==store::metadata_charge()+15*128);
    content(ref s,ref roots,ref scratch,reused,7,b"new");assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0);
}
@test fn void fuel_boundaries_precede_invalid_handles_and_never_mutate_roots(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=store::setup_cost()-1;assert(!store::open(ref mut roots,ref mut scratch,limits(),ref mut fuel).is_ok);
    assert(fuel==store::setup_cost()-1 && vec::capacity<bytes::Buffer>(ref roots)==0);
    fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
    let usize serial=inserted(ref mut s,ref mut roots,ref mut scratch,0,b"abc",ref mut fuel);let usize used=s.ledger.used;
    fuel=store::move_cost()-1;assert(!store::move(ref mut s,ref mut roots,ref mut scratch,0,0,1,ref mut fuel).is_ok);
    assert(fuel==store::move_cost()-1);fuel=store::move_cost();
    assert(!store::move(ref mut s,ref mut roots,ref mut scratch,serial,1,2,ref mut fuel).is_ok && fuel==0);
    fuel=store::drop_cost()-1;assert(!store::drop(ref mut s,ref mut roots,ref mut scratch,serial,0,ref mut fuel).is_ok);
    assert(fuel==store::drop_cost()-1 && s.ledger.used==used);content(ref s,ref roots,ref scratch,serial,0,b"abc");
    fuel=258;var u8[3] output=[99;3];assert(!store::copy_out(ref s,ref roots,ref scratch,serial,0,0,ref mut output,ref mut fuel).is_ok);
    assert(fuel==258 && output[0]==99);fuel=259;
    assert(!store::copy_out(ref s,ref roots,ref scratch,serial,0,1,ref mut output,ref mut fuel).is_ok && fuel==0 && output[0]==99);
    assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0 && fuel==0);
    assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0);
}
@test fn void quota_and_binding_failures_publish_nothing_and_serials_do_not_wrap(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
    let growth::Limits tight=growth::Limits{.object=64,.instance=store::metadata_charge()+127,.engine=32768};
    assert(!store::insert(ref mut s,ref mut roots,ref mut scratch,0,b"abc",tight,ref mut fuel).is_ok);
    assert(s.ledger.used==store::metadata_charge() && s.next==1 && vec::len<bytes::Buffer>(ref roots)==0);
    assert(!store::insert(ref mut s,ref mut roots,ref mut scratch,512,b"",limits(),ref mut fuel).is_ok);
    s.next=18446744073709551615;let usize serial=inserted(ref mut s,ref mut roots,ref mut scratch,0,b"",ref mut fuel);
    assert(serial==18446744073709551615 && s.next==0 && s.ledger.used==store::metadata_charge()+64);
    assert(!store::insert(ref mut s,ref mut roots,ref mut scratch,1,b"",limits(),ref mut fuel).is_ok);
    assert(ok(store::move(ref mut s,ref mut roots,ref mut scratch,serial,0,1,ref mut fuel))==serial);
    assert(ok(store::drop(ref mut s,ref mut roots,ref mut scratch,serial,1,ref mut fuel))==store::metadata_charge());
    assert(!store::drop(ref mut s,ref mut roots,ref mut scratch,serial,1,ref mut fuel).is_ok);
    assert(!store::create_cost(18446744073709551615).is_ok);assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0);
}
@test fn void corrupt_native_metadata_is_rejected_before_data_or_ownership_changes(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
    let usize a=inserted(ref mut s,ref mut roots,ref mut scratch,0,b"first",ref mut fuel);
    let usize b=inserted(ref mut s,ref mut roots,ref mut scratch,1,b"other",ref mut fuel);let store::State before=s;
    s.rows[1].serial=a;assert(!store::move(ref mut s,ref mut roots,ref mut scratch,a,0,2,ref mut fuel).is_ok);s=before;
    s.rows[1].binding=0;assert(!store::drop(ref mut s,ref mut roots,ref mut scratch,a,0,ref mut fuel).is_ok);s=before;
    s.rows[1].slot=before.rows[0].slot;assert(!store::describe(ref s,ref roots,ref scratch,a,0).is_ok);s=before;
    s.ledger.used-=1;assert(!store::describe(ref s,ref roots,ref scratch,a,0).is_ok);s=before;
    s.table.slots[before.rows[0].slot].length=4;assert(!store::describe(ref s,ref roots,ref scratch,a,0).is_ok);s=before;
    s.closing.active=true;assert(!store::move(ref mut s,ref mut roots,ref mut scratch,a,0,2,ref mut fuel).is_ok);s=before;
    content(ref s,ref roots,ref scratch,a,0,b"first");content(ref s,ref roots,ref scratch,b,1,b"other");
    assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0);
}
