module tests::m2::value_root_append;
import value_roots as store;
import buffer_owners as owners;
import buffer_growth as growth;
import std::bytes as bytes;
import std::vec as vec;

struct Query { usize dest; usize binding; usize source; usize source_binding; usize start; usize length; bool window; }
fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=32768,.engine=32768};}
fn usize ok(Result<usize,store::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 code(store::Error e){return switch(e){case .Fuel:{1}case .State:{2}case .Binding:{3}case .Serial:{4}
    case .Owners:{5}case .Quota:{6}case .Allocation:{7}case .Bounds:{8}};}
fn store::State opened(ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){
    return switch(store::open(roots,scratch,limits(),fuel)){case .ok(v):{v}case .err(_):{assert(false);opened(roots,scratch,fuel)}};
}
fn Result<usize,store::Error> pay(usize amount,ref mut usize fuel){let usize before=*fuel;
    if(before<amount){return .err(.Fuel);};*fuel=before-amount;return .ok(amount);
}
// Frozen 7a540e2 resolver; inspect_store is the unchanged complete preflight.
// Each original lookup repeats it before identity, lease and backing checks.
fn Result<usize,store::Error> original_resolve(ref store::State s,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,bool writing){
    let usize count=store::inspect_store(s,roots,scratch)?;if(serial==0 || binding>=512){return .err(.Binding);}
    var usize i=0;while(i<count){let store::Row row=s.rows[i];if(row.serial==serial){
        if(row.binding!=binding){return .err(.Binding);}let owners::Owner owner=s.table.slots[row.slot];
        if(writing && owner.reading){return .err(.State);}
        let ref bytes::Buffer root=vec::at<bytes::Buffer>(roots,i);
        if(bytes::len(root)!=owner.length || bytes::capacity(root)!=owner.capacity){return .err(.State);}
        return .ok(i);
    }i+=1;}return .err(.Serial);
}
// Original two-lookup order, errors and Fuel. The unchanged append transaction
// uses standalone append with test-only copied input (fixtures <= 65 bytes).
fn Result<usize,store::Error> original(ref mut store::State s,ref mut vec::Vec<bytes::Buffer> roots,
    ref mut vec::Vec<bytes::Buffer> scratch,Query q,growth::Limits cap,ref mut usize fuel){
    let usize metadata=pay(512,fuel)?;let usize i=original_resolve(s,roots,scratch,q.dest,q.binding,true)?;
    let usize source=original_resolve(s,roots,scratch,q.source,q.source_binding,false)?;
    if(i==source){return .err(.Binding);}let usize initialized=bytes::len(vec::at<bytes::Buffer>(roots,source));
    let usize start=if(q.window){q.start}else{0};let usize length=if(q.window){q.length}else{initialized};
    if(q.window && (start>initialized || length>initialized-start)){return .err(.Bounds);}
    let usize cost=store::append_from_cost(bytes::len(vec::at<bytes::Buffer>(roots,i)),length)?;
    let usize paid=pay(cost-512,fuel)?;assert(length<=65);var u8[65] input=[0;65];
    {let ref u8[] data=bytes::view(vec::at<bytes::Buffer>(roots,source));var usize at=0;
        while(at<length){input[at]=data[start+at];at+=1;}}
    var usize local_fuel=cost-256;let Result<usize,store::Error> result=store::append(
        s,roots,scratch,q.dest,q.binding,ref input[..length],cap,ref mut local_fuel);
    assert(local_fuel==0);return result;
}
fn void ledger(ref growth::Ledger a,ref growth::Ledger b){
    assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);
}
fn void table(ref owners::Table a,ref owners::Table b){var usize i=0;while(i<16){
    let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
    assert(x.generation==y.generation && x.live==y.live && x.length==y.length && x.capacity==y.capacity && x.reading==y.reading);i+=1;}}
fn void state(ref store::State a,ref store::State b){
    assert(a.next==b.next && a.external==b.external && a.closed==b.closed);ledger(ref a.ledger,ref b.ledger);table(ref a.table,ref b.table);
    assert(a.closing.active==b.closing.active && a.closing.source.slot==b.closing.source.slot &&
        a.closing.source.generation==b.closing.source.generation && a.closing.capacity==b.closing.capacity && a.closing.charge==b.closing.charge);
    ledger(ref a.closing.before,ref b.closing.before);table(ref a.closing.after,ref b.closing.after);var usize i=0;while(i<16){
        let store::Row x=a.rows[i];let store::Row y=b.rows[i];
        assert(x.serial==y.serial && x.binding==y.binding && x.slot==y.slot && x.generation==y.generation);i+=1;}
}
fn void vectors(ref vec::Vec<bytes::Buffer> a,ref vec::Vec<bytes::Buffer> b){
    assert(vec::len<bytes::Buffer>(a)==vec::len<bytes::Buffer>(b) && vec::capacity<bytes::Buffer>(a)==vec::capacity<bytes::Buffer>(b));
    var usize i=0;while(i<vec::len<bytes::Buffer>(a)){let ref bytes::Buffer x=vec::at<bytes::Buffer>(a,i);
        let ref bytes::Buffer y=vec::at<bytes::Buffer>(b,i);
        assert(bytes::capacity(x)==bytes::capacity(y) && bytes::equal(bytes::view(x),bytes::view(y)));i+=1;}
}
fn void compare(ref mut store::State s,ref mut store::State other,ref mut vec::Vec<bytes::Buffer> a,
    ref mut vec::Vec<bytes::Buffer> b,ref mut vec::Vec<bytes::Buffer> x,ref mut vec::Vec<bytes::Buffer> y,
    Query q,growth::Limits cap,usize budget,u8 expected,ref mut usize comparisons){
    let store::State before=*s;var usize old_fuel=budget;var usize new_fuel=budget;
    let Result<usize,store::Error> wanted=original(s,a,x,q,cap,ref mut old_fuel);
    let Result<usize,store::Error> got=if(q.window){store::append_window(other,b,y,q.dest,q.binding,q.source,q.source_binding,q.start,q.length,cap,ref mut new_fuel)}
        else{store::append_from(other,b,y,q.dest,q.binding,q.source,q.source_binding,cap,ref mut new_fuel)};
    assert(old_fuel==new_fuel);assert(switch(wanted){case .ok(v):{switch(got){case .ok(w):{v==w && expected==0}case .err(_):{false}}}
        case .err(e):{switch(got){case .ok(_):{false}case .err(f):{code(e)==code(f) && (expected==255 || code(f)==expected)}}}});
    state(s,other);vectors(a,b);vectors(x,y);assert(vec::len<bytes::Buffer>(x)==0);
    if(!got.is_ok){state(s,ref before);}let usize previous=*comparisons;*comparisons=previous+1;
}
fn owners::Token begin(ref mut store::State s,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize selected){var usize fuel=256;let store::Row row=s.rows[selected];
    return switch(store::begin_read(s,roots,scratch,row.serial,row.binding,ref mut fuel)){
        case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
@test fn void every_destination_matches_original_for_growth_leases_bounds_fuel_and_quota(){
    var usize comparisons=0;var usize selected=0;while(selected<16){
        var vec::Vec<bytes::Buffer> a=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> b=vec::empty<bytes::Buffer>();
        var vec::Vec<bytes::Buffer> x=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> y=vec::empty<bytes::Buffer>();
        var usize fuel=1000000;var store::State s=opened(ref mut a,ref mut x,ref mut fuel);
        var store::State other=opened(ref mut b,ref mut y,ref mut fuel);let u8[63] seed=[90;63];var usize i=0;
        while(i<16){let ref u8[] input=if(i==selected){ref seed[..]}else{b"abcdef"};
            assert(ok(store::insert(ref mut s,ref mut a,ref mut x,i,input,limits(),ref mut fuel))==
                ok(store::insert(ref mut other,ref mut b,ref mut y,i,input,limits(),ref mut fuel)));i+=1;}
        let usize source=(selected+1)%16;var Query q=Query{.dest=s.rows[selected].serial,.binding=selected,
            .source=s.rows[source].serial,.source_binding=source,.start=6,.length=0,.window=true};
        compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),2556,0,ref mut comparisons);
        q.start=2;q.length=2;compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),2564,0,ref mut comparisons);
        q.window=false;compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),2588,0,ref mut comparisons);
        let owners::Token lease=begin(ref mut s,ref a,ref x,source);let owners::Token other_lease=begin(ref mut other,ref b,ref y,source);
        q.window=true;q.start=1;q.length=2;compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),2597,0,ref mut comparisons);
        assert(s.table.slots[lease.slot].reading && other.table.slots[other_lease.slot].reading);
        q.window=false;compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),2620,0,ref mut comparisons);
        let usize ended=ok(store::end_read(ref mut s,ref a,ref x,q.source,source,lease));
        assert(ended==ok(store::end_read(ref mut other,ref b,ref y,q.source,source,other_lease)));
        q.window=true;q.start=18446744073709551615;q.length=0;
        compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),512,8,ref mut comparisons);
        q.start=5;q.length=2;compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),512,8,ref mut comparisons);
        q.start=0;q.length=2;compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),511,1,ref mut comparisons);
        compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),2627,1,ref mut comparisons);
        let growth::Limits tight=growth::Limits{.object=127,.instance=32768,.engine=32768};
        compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,tight,2628,6,ref mut comparisons);
        let owners::Token held=begin(ref mut s,ref a,ref x,selected);let owners::Token other_held=begin(ref mut other,ref b,ref y,selected);
        q.length=0;compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),512,2,ref mut comparisons);
        q.window=false;compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),512,2,ref mut comparisons);
        let usize released=ok(store::end_read(ref mut s,ref a,ref x,q.dest,selected,held));
        assert(released==ok(store::end_read(ref mut other,ref b,ref y,q.dest,selected,other_held)));
        let usize slot=s.rows[selected].slot;s.rows[selected].generation=18446744073709551615;s.table.slots[slot].generation=18446744073709551615;
        other=s;q.window=true;q.start=6;q.length=0;
        compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),2620,0,ref mut comparisons);
        q.window=false;compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),2644,5,ref mut comparisons);
        q.window=true;q.source=q.dest;q.source_binding=selected;q.start=0;q.length=0;
        compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),512,3,ref mut comparisons);
        fuel=0;assert(ok(store::drain(ref mut s,ref mut a,ref mut x))==0 && ok(store::drain(ref mut other,ref mut b,ref mut y))==0 && fuel==0);
        selected+=1;
    }assert(comparisons==240);
}
fn store::State fault(ref store::State clean,usize slot,usize mode){var store::State s=*clean;
    if(mode==0){s.rows[slot].serial=0;}else if(mode==1){s.rows[slot].binding=512;}
    else if(mode==2){s.rows[slot].slot=16;}else if(mode==3){s.rows[slot].generation=0;}
    else if(mode==4){s.rows[slot].generation+=1;}else if(mode==5){s.rows[slot].serial=clean.rows[0].serial;}
    else if(mode==6){s.rows[slot].binding=clean.rows[0].binding;}else if(mode==7){s.rows[slot].slot=clean.rows[0].slot;}
    else if(mode==8){s.table.slots[slot].generation=0;}else if(mode==9){s.table.slots[slot].generation+=1;}
    else if(mode==10){s.table.slots[slot].live=false;}else if(mode==11){s.table.slots[slot].capacity=1;}
    else if(mode==12){s.table.slots[slot].length=65;}else if(mode==13){s.table.slots[slot].reading=true;}
    else if(mode==14){s.table.slots[slot].length=5;}else if(mode==15){s.ledger.used+=1;}
    else if(mode==16){s.closing.active=true;}else if(mode==17){s.ledger.pending=64;}
    else if(mode==18){s.external=1;}else if(mode==19){s.closed=true;}
    else if(mode==20){s.table.slots[slot].capacity+=64;s.ledger.used+=64;s.ledger.engine_used+=64;s.ledger.peak+=64;s.ledger.engine_peak+=64;}
    else{s.rows[slot].serial=clean.next;}return s;
}
@test fn void two_operand_preflight_matches_original_for_all_slots_faults_and_error_priority(){
    var vec::Vec<bytes::Buffer> a=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> b=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> x=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> y=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut a,ref mut x,ref mut fuel);
    var store::State other=opened(ref mut b,ref mut y,ref mut fuel);var usize i=0;
    while(i<16){assert(ok(store::insert(ref mut s,ref mut a,ref mut x,i,b"abcdef",limits(),ref mut fuel))==
        ok(store::insert(ref mut other,ref mut b,ref mut y,i,b"abcdef",limits(),ref mut fuel)));i+=1;}
    let store::State clean=s;var usize comparisons=0;i=0;while(i<16){var usize mode=0;while(mode<22){
        var usize api=0;while(api<2){s=fault(ref clean,i,mode);other=s;
            let Query q=Query{.dest=clean.rows[0].serial,.binding=0,.source=clean.rows[15].serial,
                .source_binding=15,.start=6,.length=0,.window=api==0};
            compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),512,255,ref mut comparisons);
            compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),511,1,ref mut comparisons);api+=1;
        }mode+=1;}i+=1;}s=clean;other=clean;
    var usize mode=0;while(mode<6){var usize api=0;while(api<2){
        var Query q=Query{.dest=clean.rows[0].serial,.binding=0,.source=clean.rows[15].serial,
            .source_binding=15,.start=18446744073709551615,.length=0,.window=api==0};
        if(mode==0){q.dest=0;q.source=0;}else if(mode==1){q.binding=512;q.source_binding=512;}
        else if(mode==2){q.dest=999;q.source_binding=512;}else if(mode==3){q.binding=511;q.source=0;}
        else if(mode==4){q.source=0;}else{q.source=999;}
        compare(ref mut s,ref mut other,ref mut a,ref mut b,ref mut x,ref mut y,q,limits(),512,255,ref mut comparisons);api+=1;
    }mode+=1;}assert(comparisons==1420);
    state(ref s,ref clean);state(ref other,ref clean);fuel=0;
    assert(ok(store::drain(ref mut s,ref mut a,ref mut x))==0 && ok(store::drain(ref mut other,ref mut b,ref mut y))==0 && fuel==0);
}
