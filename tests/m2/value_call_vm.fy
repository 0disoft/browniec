module tests::m2::value_call_vm;
import value_call_vm as calls;
import value_ir as values;
import value_properties as properties;
import value_frame_layout as layouts;
import value_frame_meter as meter;
import value_frames as frames;
import value_roots as owners;
import buffer_growth as growth;
import ir as ir;
import errors as errors;
import std::vec as vec;
import std::bytes as bytes;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn usize ok(Result<usize,frames::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize measured(Result<usize,meter::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize paid(Result<usize,errors::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn bool invalid(Result<calls::Prepared,errors::Error> result){return switch(result){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==71}};}
fn frames::Address at(frames::Token token,usize slot){return frames::Address{.frame=token.frame,.generation=token.generation,.slot=slot};}
fn values::Program unit(bool copying,bool repeated,bool reuse){
    var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    u.catalog.count=2;
    u.catalog.nodes[0]=properties::Node{.kind=1,.first=1,.second=0,.extent=0};
    u.catalog.nodes[1]=properties::Node{.kind=4,.first=0,.second=0,.extent=0};
    let u8 encoded=if(copying){1}else{2};u.types[0]=encoded;u.types[1]=encoded;u.types[2]=encoded;
    u.types[3]=encoded;u.types[4]=encoded;u.functions[3]=1;u.functions[4]=1;
    u.body.function_count=2;u.body.count=2;u.body.registers=3;
    u.body.starts[0]=0;u.body.ends[0]=1;u.body.starts[1]=1;u.body.ends[1]=2;
    u.body.register_starts[1]=1;u.body.register_ends[0]=1;u.body.register_ends[1]=3;
    u.body.arities[1]=2;u.body.call_count=1;u.body.call_arities[0]=2;
    u.parameters[1]=4;u.parameters[2]=5;u.results[1]=4;
    u.body.call_args[0]=208;u.body.call_args[1]=if(repeated){208}else{209};
    u.body.code[0]=93;u.body.code[1]=if(reuse){0}else{2};u.body.code[2]=1;u.body.offsets[0]=71;
    return u;
}
fn layouts::Plan retained(ref values::Program u){return switch(layouts::retain(ref u.catalog,ref u.types,ref u.functions,2)){
    case .ok(v):{v}case .err(_):{assert(false);retained(u)}
};}
fn owners::State root_open(ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){
    return switch(owners::open(roots,scratch,limits(),fuel)){case .ok(v):{v}case .err(_):{assert(false);root_open(roots,scratch,fuel)}};
}
fn frames::State opened(ref layouts::Plan p,ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,
    ref owners::State roots,ref mut usize fuel){return switch(frames::open(p,data,scratch,roots,limits(),fuel)){
        case .ok(v):{v}case .err(_):{assert(false);opened(p,data,scratch,roots,fuel)}};
}
fn frames::Token entered(ref layouts::Plan p,ref mut frames::State s,ref mut vec::Vec<bytes::Buffer> data,
    usize f,ref owners::State roots,ref mut usize fuel){return switch(frames::enter(p,s,data,f,roots,limits(),fuel)){
        case .ok(v):{v}case .err(_):{assert(false);frames::Token{.frame=0,.generation=0}}};
}
fn void publish(Result<calls::Prepared,errors::Error> result,ref layouts::Plan p,ref mut frames::State s,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,ref mut owners::State r,
    ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> rs){switch(result){
        case .ok(batch):{calls::publish(p,ref batch,s,data,scratch,r,roots,rs);}case .err(_):{assert(false);}
    };
}
fn void content(ref owners::State r,ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> rs,usize serial,usize binding){
    var u8[4] output=[0;4];var usize fuel=260;
    assert(switch(owners::copy_out(r,roots,rs,serial,binding,0,ref mut output,ref mut fuel)){case .ok(v):{v==4}case .err(_):{false}});
    assert(bytes::equal(ref output,b"keep"));
}

@test fn void repeated_copy_actuals_publish_twice_but_live_result_destination_is_rejected(){
    var values::Program u=unit(true,true,false);let layouts::Plan p=retained(ref u);
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> rs=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut rs,ref mut fuel);var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token caller=entered(ref p,ref mut s,ref mut data,0,ref r,ref mut fuel);
    assert(ok(frames::scalar_value(ref p,ref mut s,ref mut data,at(caller,0),42,ref mut fuel))==4);
    let usize charge=paid(calls::cost(ref u,ref p,0));assert(charge==measured(meter::enter_cost(8))+8192+4*measured(meter::operation_cost(4)));
    let usize before=fuel;assert(measured(meter::pay(charge,ref mut fuel))==charge);
    var usize local=measured(meter::enter_cost(8));let frames::Token callee=entered(ref p,ref mut s,ref mut data,1,ref r,ref mut local);assert(local==0);
    u.body.code[1]=0;assert(invalid(calls::prepare(ref u,ref p,0,0,caller,callee,ref s,ref data,ref scratch,ref r,ref roots,ref rs)));
    assert(s.frames[0].live==1 && s.frames[1].live==0);u.body.code[1]=2;
    publish(calls::prepare(ref u,ref p,0,0,caller,callee,ref s,ref data,ref scratch,ref r,ref roots,ref rs),ref p,ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut rs);
    assert(fuel==before-charge && s.frames[0].live==1 && s.frames[1].live==24);
    var usize read_fuel=10000;assert(switch(frames::scalar_read(ref p,ref s,ref data,at(callee,3),ref mut read_fuel)){case .ok(v):{v==42}case .err(_):{false}});
    assert(switch(frames::scalar_read(ref p,ref s,ref data,at(callee,4),ref mut read_fuel)){case .ok(v):{v==42}case .err(_):{false}});
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut rs))==0);
}

@test fn void repeated_move_and_late_invalid_root_leave_all_caller_data_and_roots_unchanged(){
    var values::Program u=unit(false,true,false);let layouts::Plan p=retained(ref u);
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> rs=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut rs,ref mut fuel);var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token caller=entered(ref p,ref mut s,ref mut data,0,ref r,ref mut fuel);
    let usize a=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(caller,0),b"keep",ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel));
    let usize b=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(caller,1),b"keep",ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel));
    let frames::Token callee=entered(ref p,ref mut s,ref mut data,1,ref r,ref mut fuel);let usize before=fuel;let usize used=r.ledger.used;
    assert(invalid(calls::prepare(ref u,ref p,0,0,caller,callee,ref s,ref data,ref scratch,ref r,ref roots,ref rs)));
    u.body.call_args[1]=209;let usize generation=r.rows[1].generation;r.rows[1].generation=0;
    assert(invalid(calls::prepare(ref u,ref p,0,0,caller,callee,ref s,ref data,ref scratch,ref r,ref roots,ref rs)));r.rows[1].generation=generation;
    // Corrupt only the late source's canonical root word: the first root still
    // validates, so this exercises failure after a successful first inspection.
    {let ref mut u8[] raw=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,0));raw[8]=0;}
    assert(invalid(calls::prepare(ref u,ref p,0,0,caller,callee,ref s,ref data,ref scratch,ref r,ref roots,ref rs)));
    {let ref mut u8[] raw=bytes::view_mut(vec::at_mut<bytes::Buffer>(ref mut data,0));raw[8]=2;}
    assert(s.frames[0].live==3 && s.frames[1].live==0 && r.ledger.used==used && fuel==before);
    content(ref r,ref roots,ref rs,a,0);content(ref r,ref roots,ref rs,b,1);
    // Rejection leaves the empty callee available for the parent's abort path.
    assert(frames::leave(ref p,ref mut s,ref mut data,callee,ref mut r,ref mut roots,ref mut rs).is_ok);
    assert(s.depth==1 && s.frames[0].live==3);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut rs))==0);
}

@test fn void consumed_actual_result_slot_and_cross_frame_roots_keep_identity_data_charge_and_exact_fuel(){
    let values::Program u=unit(false,false,true);let layouts::Plan p=retained(ref u);
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> rs=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var owners::State r=root_open(ref mut roots,ref mut rs,ref mut fuel);var frames::State s=opened(ref p,ref mut data,ref mut scratch,ref r,ref mut fuel);
    let frames::Token caller=entered(ref p,ref mut s,ref mut data,0,ref r,ref mut fuel);
    let usize a=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(caller,0),b"keep",ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel));
    let usize b=ok(frames::buffer_value(ref p,ref mut s,ref mut data,at(caller,1),b"keep",ref mut r,ref mut roots,ref mut rs,limits(),ref mut fuel));
    let owners::Row first=r.rows[0];let owners::Row second=r.rows[1];let usize used=r.ledger.used;let usize peak=r.ledger.peak;
    let usize before=fuel;let usize charge=paid(calls::cost(ref u,ref p,0));assert(charge==measured(meter::enter_cost(16))+8192+4*measured(meter::operation_cost(8)));
    assert(measured(meter::pay(charge,ref mut fuel))==charge);var usize local=measured(meter::enter_cost(16));
    let frames::Token callee=entered(ref p,ref mut s,ref mut data,1,ref r,ref mut local);assert(local==0);
    publish(calls::prepare(ref u,ref p,0,0,caller,callee,ref s,ref data,ref scratch,ref r,ref roots,ref rs),ref p,ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut rs);
    assert(fuel==before-charge && s.frames[0].live==0 && s.frames[1].live==24);
    assert(r.ledger.used==used && r.ledger.peak==peak && vec::len<bytes::Buffer>(ref roots)==2);
    assert(r.rows[0].serial==first.serial && r.rows[0].slot==first.slot && r.rows[0].generation==first.generation);
    assert(r.rows[1].serial==second.serial && r.rows[1].slot==second.slot && r.rows[1].generation==second.generation);
    content(ref r,ref roots,ref rs,a,19);content(ref r,ref roots,ref rs,b,20);
    let u8[16] zeros=[0;16];assert(bytes::equal(bytes::view(vec::at<bytes::Buffer>(ref data,0))[..16],ref zeros));
    assert(frames::inspect_destination(ref p,ref s,ref data,at(caller,0)).is_ok);
    assert(ok(frames::abort(ref mut s,ref mut data,ref mut scratch,ref mut r,ref mut roots,ref mut rs))==0);
}
