module tests::m2::value_view_conditional_native;
import value_frames as frames;
import value_frame_layout as layouts;
import value_frame_meter as meter;
import value_properties as values;
import value_roots as owners;
import buffer_owners as leases;
import buffer_growth as growth;
import value_ir as ir_values;
import value_program as programs;
import value_runtime as runtime;
import errors as errors;
import ir as ir;
import vm as vm;
import std::bytes as bytes;
import std::vec as vec;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn layouts::Plan plan(){
    var values::Catalog c=values::empty();c.count=3;
    c.nodes[0]=values::Node{.kind=4,.first=0,.second=0,.extent=0};
    c.nodes[1]=values::Node{.kind=1,.first=12,.second=0,.extent=0};
    c.nodes[2]=values::Node{.kind=5,.first=0,.second=0,.extent=0};
    let u8[16] types=[1,1,2,3,0,0,0,0,0,0,0,0,0,0,0,0];let u8[16] functions=[0;16];
    return switch(layouts::retain(ref c,ref types,ref functions,1)){
        case .ok(v):{v}case .err(_):{assert(false);plan()}
    };
}
fn usize ok(Result<usize,frames::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize root_ok(Result<usize,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize price(){return switch(meter::operation_cost(8)){case .ok(v):{assert(v==2080);v}case .err(_):{assert(false);0}};}
fn u8 code(frames::Error e){return switch(e){case .Fuel:{1}case .State:{2}case .Type:{3}case .Bounds:{4}
    case .Quota:{5}case .Allocation:{6}case .Value:{7}case .Owner:{8}};}
fn owners::State root_open(ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){
    return switch(owners::open(roots,scratch,limits(),fuel)){case .ok(v):{v}case .err(_):{assert(false);root_open(roots,scratch,fuel)}};
}
fn frames::State opened(ref layouts::Plan p,ref mut vec::Vec<bytes::Buffer> data,
    ref mut vec::Vec<bytes::Buffer> scratch,ref owners::State r,ref mut usize fuel){
    return switch(frames::open(p,data,scratch,r,limits(),fuel)){case .ok(v):{v}case .err(_):{assert(false);opened(p,data,scratch,r,fuel)}};
}
fn frames::Token enter(ref layouts::Plan p,ref mut frames::State s,ref mut vec::Vec<bytes::Buffer> data,ref owners::State r,ref mut usize fuel){
    return switch(frames::enter(p,s,data,0,r,limits(),fuel)){case .ok(v):{v}case .err(_):{assert(false);frames::Token{.frame=32,.generation=0}}};
}
fn frames::Address at(frames::Token t,usize slot){return frames::Address{.frame=t.frame,.generation=t.generation,.slot=slot};}
fn void unchanged(ref frames::State s,ref frames::State before,ref owners::State r,ref owners::State old){
    assert(s.depth==before.depth && s.next==before.next && s.used==before.used && s.peak==before.peak && s.closed==before.closed);
    var usize i=0;while(i<32){let frames::Frame a=s.frames[i];let frames::Frame b=before.frames[i];
        assert(a.function==b.function && a.generation==b.generation && a.live==b.live && a.next==b.next && a.charge==b.charge);i+=1;}
    i=0;while(i<512){assert(s.order[i]==before.order[i]);i+=1;}
    assert(r.next==old.next && r.external==old.external && r.closed==old.closed && r.closing.active==old.closing.active);
    let growth::Ledger a=r.ledger;let growth::Ledger b=old.ledger;
    assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);
    i=0;while(i<16){let owners::Row x=r.rows[i];let owners::Row y=old.rows[i];
        let leases::Owner xowner=r.table.slots[i];let leases::Owner yowner=old.table.slots[i];
        assert(x.serial==y.serial && x.binding==y.binding && x.slot==y.slot && x.generation==y.generation);
        assert(xowner.live==yowner.live && xowner.generation==yowner.generation && xowner.reading==yowner.reading &&
            xowner.length==yowner.length && xowner.capacity==yowner.capacity);i+=1;}
}
fn void rejected(ref layouts::Plan p,ref mut frames::State s,ref mut vec::Vec<bytes::Buffer> data,frames::Address address,
    ref mut owners::State r,ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> rs,usize allowance,u8 expected){
    let frames::State before=*s;let owners::State old=*r;
    let usize count=vec::len<bytes::Buffer>(roots);var u8[40] saved=[0;40];
    let ref u8[] all=bytes::view(vec::at<bytes::Buffer>(data,0));assert(all.len==40);
    var usize i=0;while(i<40){saved[i]=all[i];i+=1;}
    var usize fuel=allowance;
    assert(switch(frames::drop_if_live(p,s,data,address,r,roots,rs,ref mut fuel)){
        case .ok(_):{false}case .err(e):{code(e)==expected}});
    assert(fuel==if(allowance<price() || expected==4){allowance}else{allowance-price()});
    unchanged(s,ref before,r,ref old);assert(vec::len<bytes::Buffer>(roots)==count);
    assert(bytes::equal(bytes::view(vec::at<bytes::Buffer>(data,0)),ref saved));
}
fn void content(ref owners::State r,ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> rs,usize serial){
    var u8[4] out=[0;4];var usize fuel=260;
    assert(root_ok(owners::copy_out(r,roots,rs,serial,0,0,ref mut out,ref mut fuel))==4 && fuel==0);
    assert(bytes::equal(ref out,b"keep"));
}

@test fn void live_and_dead_cleanup_pay_exactly_one_buffer_operation_and_preserve_other_slots(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> rs=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var owners::State r=root_open(ref mut roots,ref mut rs,ref mut fuel);
    var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token t=enter(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    rejected(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,price()-1,1);
    let usize next=s.frames[0].next;let usize serial_next=r.next;fuel=price();
    assert(ok(frames::drop_if_live(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,ref mut fuel))==8 && fuel==0);
    assert(s.frames[0].next==next && r.next==serial_next && vec::len<bytes::Buffer>(ref roots)==0);
    fuel=1000000;let usize serial=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(t,0),b"keep",ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel));
    let usize other=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(t,1),b"other",ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel));
    rejected(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,price()-1,1);content(ref r,ref roots,ref rs,serial);
    let usize used=r.ledger.used;let usize order=s.order[1];fuel=price();
    assert(ok(frames::drop_if_live(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,ref mut fuel))==8 && fuel==0);
    assert(s.frames[0].live==2 && s.order[0]==0 && s.order[1]==order && r.ledger.used<used);
    assert(vec::len<bytes::Buffer>(ref roots)==1 && r.rows[0].serial==other && r.rows[0].binding==1);
    let u8[8] zero=[0;8];assert(bytes::equal(bytes::view(vec::at<bytes::Buffer>(ref data,0))[..8],ref zero));
    fuel=price()+1;assert(ok(frames::drop_if_live(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,ref mut fuel))==8 && fuel==1);
    fuel=price();assert(!frames::drop(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,ref mut fuel).is_ok);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut rs))==0);
}

@test fn void dead_cleanup_authenticates_types_activation_order_bytes_and_root_store(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> rs=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var owners::State r=root_open(ref mut roots,ref mut rs,ref mut fuel);
    var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token stale=enter(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    let usize left=ok(frames::leave(ref p,ref mut s,ref mut data,stale,ref mut r,ref mut roots,ref mut rs));
    let frames::Token t=enter(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    rejected(ref p,ref mut s,ref mut data,at(stale,0),ref mut r,ref mut roots,ref mut rs,price(),2);
    rejected(ref p,ref mut s,ref mut data,at(t,16),ref mut r,ref mut roots,ref mut rs,price(),4);
    rejected(ref p,ref mut s,ref mut data,frames::Address{.frame=1,.generation=t.generation,.slot=0},ref mut r,ref mut roots,ref mut rs,price(),2);
    rejected(ref p,ref mut s,ref mut data,frames::Address{.frame=32,.generation=t.generation,.slot=0},ref mut r,ref mut roots,ref mut rs,price(),4);
    var usize slot=2;while(slot<5){rejected(ref p,ref mut s,ref mut data,at(t,slot),ref mut r,ref mut roots,ref mut rs,price(),3);slot+=1;}
    s.order[0]=1;rejected(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,price(),2);s.order[0]=0;
    {let ref mut u8[] all=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,0));all[7]=1;}
    rejected(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,price(),7);
    {let ref mut u8[] all=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,0));all[7]=0;}
    r.closed=true;rejected(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,price(),2);r.closed=false;
    r.rows[15].binding=0;rejected(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,price(),2);r.rows[15].binding=512;
    fuel=1000000;let usize serial=root_ok(owners::insert(ref mut r,ref mut roots,ref mut rs,0,b"keep",limits(),ref mut fuel));
    rejected(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,price(),8);content(ref r,ref roots,ref rs,serial);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut rs))==0);
}

@test fn void live_cleanup_rejects_wrong_types_corrupt_serial_binding_and_pins_without_retiring(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> rs=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var owners::State r=root_open(ref mut roots,ref mut rs,ref mut fuel);
    var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token t=enter(ref p,ref mut s,ref mut data,ref r,ref mut fuel);
    let usize scalar=ok(frames::scalar_value(ref p,ref mut s,ref mut data,at(t,2),42,ref mut fuel));
    let usize none=ok(frames::build_tag(ref p,ref mut s,ref mut data,ref mut scratch,at(t,3),at(t,0),0,ref mut r,ref mut roots,ref mut rs,ref mut fuel));
    rejected(ref p,ref mut s,ref mut data,at(t,2),ref mut r,ref mut roots,ref mut rs,price(),3);
    rejected(ref p,ref mut s,ref mut data,at(t,3),ref mut r,ref mut roots,ref mut rs,price(),3);
    let usize serial=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(t,0),b"keep",ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel));
    let u8 first=bytes::view(vec::at<bytes::Buffer>(ref data,0))[0];
    {let ref mut u8[] all=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,0));all[0]=0;}
    rejected(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,price(),7);
    {let ref mut u8[] all=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,0));all[0]=first;}
    r.rows[0].binding=1;rejected(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,price(),8);r.rows[0].binding=0;
    let leases::Token pin=switch(owners::begin_read(ref mut r,ref roots,ref rs,serial,0,ref mut fuel)){
        case .ok(v):{v}case .err(_):{assert(false);leases::Token{.slot=16,.generation=0}}};
    rejected(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,price(),8);content(ref r,ref roots,ref rs,serial);
    let usize released=root_ok(owners::end_read(ref mut r,ref roots,ref rs,serial,0,pin));fuel=price();
    assert(ok(frames::drop_if_live(ref p,ref mut s,ref mut data,at(t,0),ref mut r,ref mut roots,ref mut rs,ref mut fuel))==8 && fuel==0);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut rs))==0);
}

fn usize emitted(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn ir_values::Program unit(){
    var ir_values::Program u=ir_values::Program{.body=ir::empty(),.catalog=values::empty(),
        .types=[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    u.catalog.count=1;u.catalog.nodes[0]=values::Node{.kind=4,.first=0,.second=0,.extent=0};
    let usize answer=emitted(ir::literal(ref mut u.body,42,71));
    let usize dead=emitted(ir::raw(ref mut u.body,115,0,0,0,71));
    let usize live=emitted(ir::raw(ref mut u.body,95,0,0,0,71));
    let usize drop=emitted(ir::raw(ref mut u.body,115,0,0,0,71));
    let usize again=emitted(ir::raw(ref mut u.body,115,0,0,0,71));
    let usize ret=emitted(ir::raw(ref mut u.body,8,answer,0,0,71));
    let usize end=u.body.count;let usize registers=u.body.registers;
    u.body.function_count=1;u.body.ends[0]=end;u.body.register_ends[0]=registers;u.body.return_types[0]=1;
    return u;
}
fn programs::Program retained(ref ir_values::Program u){return switch(programs::retain(u)){
    case .ok(v):{v}case .err(_):{assert(false);retained(u)}};
}
fn runtime::Step step(Result<runtime::Step,errors::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);runtime::Step{.pc=0,.remaining=0}}};
}
@test fn void opcode115_dispatches_both_paths_and_zero_fuel_failure_still_drains_backing(){
    let ir_values::Program u=unit();let programs::Program p=retained(ref u);
    var vec::Vec<frames::State> states=vec::empty<frames::State>();var vec::Vec<owners::State> stores=vec::empty<owners::State>();
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> rs=vec::empty<bytes::Buffer>();
    let usize setup=emitted(runtime::setup(ref p,ref mut states,ref mut stores,ref mut data,ref mut scratch,ref mut roots,ref mut rs,limits(),4000000));
    var i64[128] registers=[0;128];
    let runtime::Step dead=step(runtime::instruction(ref p,1,0,ref mut states,ref mut stores,ref mut data,ref mut scratch,ref mut roots,ref mut rs,ref mut registers,limits(),price()));
    assert(dead.pc==2 && dead.remaining==0 && vec::len<bytes::Buffer>(ref roots)==0);
    let runtime::Step live=step(runtime::instruction(ref p,2,0,ref mut states,ref mut stores,ref mut data,ref mut scratch,ref mut roots,ref mut rs,ref mut registers,limits(),setup));
    let runtime::Step dropped=step(runtime::instruction(ref p,3,0,ref mut states,ref mut stores,ref mut data,ref mut scratch,ref mut roots,ref mut rs,ref mut registers,limits(),price()));
    assert(dropped.pc==4 && dropped.remaining==0 && vec::len<bytes::Buffer>(ref roots)==0);
    let runtime::Step recreated=step(runtime::instruction(ref p,2,0,ref mut states,ref mut stores,ref mut data,ref mut scratch,ref mut roots,ref mut rs,ref mut registers,limits(),setup));
    assert(switch(runtime::instruction(ref p,3,0,ref mut states,ref mut stores,ref mut data,ref mut scratch,ref mut roots,ref mut rs,ref mut registers,limits(),0)){
        case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==71}});
    assert(vec::len<bytes::Buffer>(ref roots)==1 && vec::at<frames::State>(ref states,0).frames[0].live==1);
    assert(switch(runtime::finish(ref mut states,ref mut stores,ref mut data,ref mut scratch,ref mut roots,ref mut rs,.err(errors::make(8,71)))){
        case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==71}});
    assert(vec::len<bytes::Buffer>(ref data)==0 && vec::len<bytes::Buffer>(ref scratch)==0 &&
        vec::len<bytes::Buffer>(ref roots)==0 && vec::len<bytes::Buffer>(ref rs)==0);
    assert(vec::at<frames::State>(ref states,0).closed && vec::at<owners::State>(ref stores,0).closed &&
        vec::at<owners::State>(ref stores,0).ledger.used==0);
}

@test fn void retained_vm_dispatch_reaches_conditional_cleanup_for_live_and_dead_slots(){
    let ir_values::Program u=unit();
    assert(switch(vm::run_values(ref u,4000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
