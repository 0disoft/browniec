module tests::m2::value_frame_meter;
import value_frame_meter as meter;
import buffer_growth as growth;

fn usize ok(Result<usize,meter::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn u8 code(meter::Error e){return switch(e){
    case .Fuel:{1}case .Bounds:{2}case .Quota:{3}case .State:{4}
};}
fn void error(Result<usize,meter::Error> result,u8 expected){
    assert(switch(result){case .ok(_):{false}case .err(e):{code(e)==expected}});
}
fn growth::Limits limits(usize object,usize instance,usize engine){
    return growth::Limits{.object=object,.instance=instance,.engine=engine};
}
fn growth::Ledger accounted(usize used,usize engine){
    var growth::Ledger ledger=growth::unowned();
    ledger.used=used;ledger.engine_used=engine;ledger.peak=used;ledger.engine_peak=engine;return ledger;
}
fn bool same(ref growth::Ledger a,ref growth::Ledger b){
    return a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used;
}
fn void budget_error(usize used,growth::Limits cap){
    assert(switch(meter::remaining(used,cap)){case .ok(_):{false}case .err(e):{code(e)==3}});
}
@test fn void numerical_limits_rounding_and_private_prices(){
    assert(meter::metadata_charge()==12288);
    assert(ok(meter::capacity(0))==0 && ok(meter::charge(0))==64);
    assert(ok(meter::capacity(1))==64 && ok(meter::capacity(63))==64);
    assert(ok(meter::capacity(64))==64 && ok(meter::capacity(65))==128);
    assert(ok(meter::capacity(1048575))==1048576 && ok(meter::capacity(1048576))==1048576);
    assert(ok(meter::charge(1048576))==1048640);
    error(meter::capacity(1048577),2);error(meter::charge(1048577),2);
    error(meter::capacity(18446744073709551615),2);error(meter::charge(18446744073709551615),2);
    assert(ok(meter::setup_cost(0))==16384 && ok(meter::setup_cost(65536))==278528);
    assert(ok(meter::enter_cost(0))==32768 && ok(meter::enter_cost(1048576))==8421376);
    assert(ok(meter::operation_cost(0))==2048 && ok(meter::operation_cost(65536))==264192);
    error(meter::setup_cost(65537),2);error(meter::enter_cost(1048577),2);error(meter::operation_cost(65537),2);
    error(meter::setup_cost(18446744073709551615),2);
    error(meter::enter_cost(18446744073709551615),2);error(meter::operation_cost(18446744073709551615),2);
}
@test fn void fuel_combined_quota_overflow_and_rejection_preserve_state(){
    var usize fuel=63;error(meter::pay(64,ref mut fuel),1);assert(fuel==63);
    assert(ok(meter::pay(63,ref mut fuel))==63 && fuel==0);
    assert(ok(meter::pay(0,ref mut fuel))==0 && fuel==0);
    error(meter::pay(1,ref mut fuel),1);assert(fuel==0);
    fuel=18446744073709551615;
    assert(ok(meter::pay(18446744073709551615,ref mut fuel))==18446744073709551615 && fuel==0);
    fuel=64;assert(ok(meter::pay(63,ref mut fuel))==63 && fuel==1);
    error(meter::pay(18446744073709551615,ref mut fuel),1);assert(fuel==1);
    var growth::Ledger roots=accounted(128,192);let growth::Ledger before=roots;
    let growth::Limits exact=limits(0,384,448);
    assert(ok(meter::admit(64,192,ref roots,exact))==256 && same(ref roots,ref before));
    error(meter::admit(64,193,ref roots,exact),3);
    error(meter::admit(64,192,ref roots,limits(0,383,448)),3);
    error(meter::admit(64,192,ref roots,limits(0,384,447)),3);
    error(meter::admit(0,0,ref roots,limits(0,127,448)),3);
    error(meter::admit(0,0,ref roots,limits(0,384,191)),3);
    let growth::Limits maximum=limits(0,18446744073709551615,18446744073709551615);
    error(meter::admit(18446744073709551615,1,ref roots,maximum),2);
    error(meter::admit(18446744073709551424,0,ref roots,maximum),2);
    assert(same(ref roots,ref before));
    roots=accounted(18446744073709551615,18446744073709551615);let growth::Ledger full=roots;
    assert(ok(meter::admit(0,0,ref roots,maximum))==0);
    error(meter::admit(0,1,ref roots,maximum),2);assert(same(ref roots,ref full));
    roots=before;roots.pending=64;let growth::Ledger pending=roots;
    error(meter::admit(0,1,ref roots,exact),4);assert(same(ref roots,ref pending));
    roots=before;roots.peak=127;let growth::Ledger corrupt=roots;
    error(meter::admit(0,1,ref roots,exact),4);assert(same(ref roots,ref corrupt));
    roots=accounted(193,192);let growth::Ledger reversed=roots;
    error(meter::admit(0,1,ref roots,exact),4);assert(same(ref roots,ref reversed));
    let growth::Limits rest=switch(meter::remaining(256,limits(7,384,448))){
        case .ok(v):{v}case .err(_):{assert(false);limits(0,0,0)}
    };
    assert(rest.object==7 && rest.instance==128 && rest.engine==192);
    let growth::Limits zero=switch(meter::remaining(256,limits(7,256,256))){
        case .ok(v):{v}case .err(_):{assert(false);limits(0,0,0)}
    };
    assert(zero.object==7 && zero.instance==0 && zero.engine==0);
    budget_error(257,limits(7,256,448));budget_error(257,limits(7,384,256));
    budget_error(18446744073709551615,limits(7,384,448));
}
