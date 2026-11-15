module tests::m2::value_root_write;
import value_roots as store;
import buffer_owners as owners;
import buffer_write as writes;
import buffer_growth as growth;
import std::bytes as bytes;
import std::vec as vec;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=32768,.engine=32768};}
fn usize ok(Result<usize,store::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 code(store::Error e){return switch(e){case .Fuel:{1}case .State:{2}case .Binding:{3}case .Serial:{4}
    case .Owners:{5}case .Quota:{6}case .Allocation:{7}case .Bounds:{8}};}
fn store::State opened(ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){
    return switch(store::open(roots,scratch,limits(),fuel)){case .ok(v):{v}case .err(_):{assert(false);opened(roots,scratch,fuel)}};
}
fn bytes::Buffer pop(ref mut vec::Vec<bytes::Buffer> roots,ref mut usize transfers){
    let usize previous=*transfers;*transfers=previous+1;return switch(vec::pop<bytes::Buffer>(roots)){case .some(v):{v}case .none:{assert(false);bytes::empty()}};
}
fn void push(ref mut vec::Vec<bytes::Buffer> roots,bytes::Buffer root,ref mut usize transfers){
    let usize previous=*transfers;*transfers=previous+1;assert(vec::push<bytes::Buffer>(roots,root).is_ok);
}
// Baseline 524ca70 preflight and owning-vector transfer sequence, with counted
// push/pop calls. inspect_store is the unchanged complete store preflight.
fn Result<usize,store::Error> original(ref store::State s,ref mut vec::Vec<bytes::Buffer> roots,
    ref mut vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,usize start,
    ref u8[] input,growth::Limits cap,ref mut usize fuel,ref mut usize transfers){
    let usize cost=store::write_cost(input.len)?;let usize available=*fuel;
    if(available<cost){return .err(.Fuel);};*fuel=available-cost;
    let usize count=store::inspect_store(s,roots,scratch)?;
    if(serial==0 || binding>=512){return .err(.Binding);}
    var usize i=0;while(i<count && s.rows[i].serial!=serial){i+=1;}
    if(i==count){return .err(.Serial);}let store::Row row=s.rows[i];
    if(row.binding!=binding){return .err(.Binding);}let owners::Owner owner=s.table.slots[row.slot];
    if(owner.reading){return .err(.State);}
    {let ref bytes::Buffer root=vec::at<bytes::Buffer>(roots,i);
        if(bytes::len(root)!=owner.length || bytes::capacity(root)!=owner.capacity){return .err(.State);}}
    while(vec::len<bytes::Buffer>(roots)>i+1){let bytes::Buffer root=pop(roots,transfers);push(scratch,root,transfers);}
    var bytes::Buffer root=pop(roots,transfers);
    let Result<usize,writes::Error> result=writes::within_length(ref s.table,
        owners::Token{.slot=row.slot,.generation=row.generation},start,ref mut root,input,cap,ref s.ledger);
    push(roots,root,transfers);
    while(vec::len<bytes::Buffer>(scratch)>0){let bytes::Buffer root=pop(scratch,transfers);push(roots,root,transfers);}
    return switch(result){case .ok(v):{.ok(v)}case .err(e):{.err(switch(e){
        case .Quota:{.Quota}case .Overflow:{.Bounds}case .Bounds:{.Bounds}
        case .Owners:{.Owners}case .Token:{.State}case .State:{.State}})}};
}
fn void equal(ref store::State s,ref vec::Vec<bytes::Buffer> a,ref vec::Vec<bytes::Buffer> b,
    ref vec::Vec<bytes::Buffer> x,ref vec::Vec<bytes::Buffer> y){
    assert(vec::len<bytes::Buffer>(a)==16 && vec::len<bytes::Buffer>(b)==16 &&
        vec::len<bytes::Buffer>(x)==0 && vec::len<bytes::Buffer>(y)==0);
    assert(vec::capacity<bytes::Buffer>(a)==vec::capacity<bytes::Buffer>(b) &&
        vec::capacity<bytes::Buffer>(x)==vec::capacity<bytes::Buffer>(y));
    assert(store::inspect_store(s,a,x).is_ok && store::inspect_store(s,b,y).is_ok);var usize i=0;
    while(i<16){let ref bytes::Buffer left=vec::at<bytes::Buffer>(a,i);let ref bytes::Buffer right=vec::at<bytes::Buffer>(b,i);
        assert(bytes::capacity(left)==bytes::capacity(right) && bytes::equal(bytes::view(left),bytes::view(right)));i+=1;}
}
fn void compare(ref store::State s,ref store::State other,ref mut vec::Vec<bytes::Buffer> a,ref mut vec::Vec<bytes::Buffer> b,
    ref mut vec::Vec<bytes::Buffer> x,ref mut vec::Vec<bytes::Buffer> y,usize selected,usize serial,usize binding,
    usize start,ref u8[] input,growth::Limits cap,bool short_fuel,u8 expected){
    var u8[1040] before=[0;1040];var usize i=0;
    while(i<16){let ref u8[] data=bytes::view(vec::at<bytes::Buffer>(b,i));var usize j=0;
        while(j<65){before[i*65+j]=data[j];j+=1;}i+=1;}
    var usize old_fuel=256+input.len;if(short_fuel){old_fuel-=1;}var usize new_fuel=old_fuel;var usize transfers=0;
    let Result<usize,store::Error> old=original(s,a,x,serial,binding,start,input,cap,ref mut old_fuel,ref mut transfers);
    let Result<usize,store::Error> got=store::write(other,b,y,serial,binding,start,input,cap,ref mut new_fuel);
    assert(old_fuel==new_fuel);assert(new_fuel==(if(short_fuel){255+input.len}else{0}));
    assert(switch(old){case .ok(v):{switch(got){case .ok(w):{v==w && w==input.len && expected==0}case .err(_):{false}}}
        case .err(e):{switch(got){case .ok(_):{false}case .err(f):{code(e)==code(f) && code(f)==expected}}}});
    if(expected==0 || expected==6 || expected==8){assert(transfers==4*(15-selected)+2);}else{assert(transfers==0);}
    equal(s,a,b,x,y);i=0;while(i<16){let ref u8[] data=bytes::view(vec::at<bytes::Buffer>(b,i));var usize j=0;
        while(j<65){let u8 wanted=if(expected==0 && i==selected && j>=start && j-start<input.len){input[j-start]}else{before[i*65+j]};
            assert(data[j]==wanted);j+=1;}i+=1;}
}
@test fn void every_root_position_preserves_bytes_bounds_quota_fuel_and_read_leases_without_extraction(){
    var vec::Vec<bytes::Buffer> a=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> b=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> x=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> y=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut a,ref mut x,ref mut fuel);
    var store::State other=opened(ref mut b,ref mut y,ref mut fuel);var u8[65] input=[0;65];var usize i=0;var u8 value=0;
    while(i<65){input[i]=value;value+=1;i+=1;}i=0;var u8 tag=100;
    while(i<16){var u8[65] seed=[tag;65];tag+=1;
        assert(ok(store::insert(ref mut s,ref mut a,ref mut x,i,ref seed,limits(),ref mut fuel))==
            ok(store::insert(ref mut other,ref mut b,ref mut y,i,ref seed,limits(),ref mut fuel)));i+=1;}
    equal(ref s,ref a,ref b,ref x,ref y);i=0;while(i<16){let store::Row row=s.rows[i];
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,i,0,ref input,limits(),false,0);
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,i,1,ref input[..63],limits(),false,0);
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,i,65,b"",limits(),false,0);
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,i,64,b"Z",limits(),false,0);
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,i,65,b"Z",limits(),false,8);
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,i,64,b"ZZ",limits(),false,8);
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,i,18446744073709551615,b"",limits(),false,8);
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,i,0,ref input,limits(),true,1);
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,511,0,b"Z",limits(),false,3);
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,18446744073709551615,i,0,b"Z",limits(),false,4);
        let growth::Limits object=growth::Limits{.object=127,.instance=32768,.engine=32768};
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,i,18446744073709551615,b"Z",object,false,6);
        let growth::Limits instance=growth::Limits{.object=4096,.instance=s.ledger.used-1,.engine=32768};
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,i,0,b"Z",instance,false,6);
        let owners::Token token=switch(store::begin_read(ref mut s,ref a,ref x,row.serial,i,ref mut fuel)){
            case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
        let owners::Token other_token=switch(store::begin_read(ref mut other,ref b,ref y,row.serial,i,ref mut fuel)){
            case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
        assert(token.slot==other_token.slot && token.generation==other_token.generation);
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,i,65,b"",limits(),false,2);
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,i,0,b"Z",limits(),false,2);
        fuel=0;assert(ok(store::end_read(ref mut s,ref a,ref x,row.serial,i,token))==row.slot);
        assert(ok(store::end_read(ref mut other,ref b,ref y,row.serial,i,other_token))==row.slot && fuel==0);fuel=1000000;
        s.rows[i].generation=18446744073709551615;s.table.slots[row.slot].generation=18446744073709551615;
        other.rows[i].generation=18446744073709551615;other.table.slots[row.slot].generation=18446744073709551615;
        compare(ref s,ref other,ref mut a,ref mut b,ref mut x,ref mut y,i,row.serial,i,0,b"Z",limits(),false,0);i+=1;
    }
    let store::Snapshot before=store::snapshot(ref s,ref a);var usize transfers=0;
    var usize old_fuel=4096*257;var usize new_fuel=old_fuel;i=0;
    while(i<4096){assert(ok(original(ref s,ref mut a,ref mut x,s.rows[0].serial,0,0,b"R",limits(),ref mut old_fuel,ref mut transfers))==1);
        assert(ok(store::write(ref other,ref mut b,ref mut y,s.rows[0].serial,0,0,b"R",limits(),ref mut new_fuel))==1);i+=1;}
    assert(old_fuel==0 && new_fuel==0 && transfers==4096*62);equal(ref s,ref a,ref b,ref x,ref y);
    let store::Snapshot after=store::snapshot(ref s,ref a);assert(before.used==after.used && before.peak==after.peak && before.next==after.next);
    fuel=0;assert(ok(store::drain(ref mut s,ref mut a,ref mut x))==0 && fuel==0);
    assert(ok(store::drain(ref mut other,ref mut b,ref mut y))==0 && fuel==0 && s.ledger.used==0 && other.ledger.used==0);
}
@test fn void empty_root_write_retains_zero_extent_and_rejects_past_initialized_end(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
    let usize serial=ok(store::insert(ref mut s,ref mut roots,ref mut scratch,0,b"",limits(),ref mut fuel));
    let store::Snapshot before=store::snapshot(ref s,ref roots);
    fuel=256;assert(ok(store::write(ref s,ref mut roots,ref mut scratch,serial,0,0,b"",limits(),ref mut fuel))==0 && fuel==0);
    fuel=257;assert(switch(store::write(ref s,ref mut roots,ref mut scratch,serial,0,0,b"X",limits(),ref mut fuel)){
        case .ok(_):{false}case .err(e):{code(e)==8}});assert(fuel==0);
    fuel=256;assert(switch(store::write(ref s,ref mut roots,ref mut scratch,serial,0,1,b"",limits(),ref mut fuel)){
        case .ok(_):{false}case .err(e):{code(e)==8}});assert(fuel==0);
    {let ref bytes::Buffer root=vec::at<bytes::Buffer>(ref roots,0);assert(bytes::len(root)==0 && bytes::capacity(root)==0);}
    let store::Snapshot after=store::snapshot(ref s,ref roots);assert(before.used==after.used && before.peak==after.peak && before.next==after.next);
    assert(vec::len<bytes::Buffer>(ref scratch)==0);assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0 && fuel==0);
}
