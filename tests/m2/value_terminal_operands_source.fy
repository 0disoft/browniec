module tests::m2::value_terminal_operands_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;
import ir as ir;

fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(p):{p}case .err(_):{assert(false);compiled(input)}
};}
// A compact, per-function opcode histogram outlives compilation. Never retain
// two full Programs on the default native stack. Catalog interning is allowed.
struct Snapshot { usize[128] ops; }
fn Snapshot snapshot(ref u8[] input,usize function){
    let values::Program p=compiled(input);
    assert(verifier::inspect_values(ref p).is_ok);
    let growth::Limits limits=growth::Limits{.object=4096,.instance=1048576,.engine=1048576};
    assert(switch(vm::run_values(ref p,10000000,0,limits)){case .ok(v):{v==42}case .err(_):{false}});
    let ref ir::Program body=ref p.body;
    assert(function<body.function_count);
    var Snapshot out=Snapshot{.ops=[0;128]};var usize i=body.starts[function];
    while(i<body.ends[function]){let usize op=body.code[i*8] as usize;
        assert(op<128);out.ops[op]+=1;i+=1;
    }
    return out;
}
fn void value(ref u8[] input){let Snapshot checked=snapshot(input,0);}
fn void omitted(ref u8[] input,usize function,u8 op,bool owner,bool view){
    let Snapshot out=snapshot(input,function);
    assert(out.ops[op as usize]==0 && out.ops[26]==0);
    if(owner){assert(out.ops[90]>0);}
    if(view){assert(out.ops[109]>0);}
}
fn void equivalent(ref u8[] outer,ref u8[] plain){
    let Snapshot a=snapshot(outer,0);let Snapshot b=snapshot(plain,0);
    // Scalar reads/captures, all owning/view ops, calls and returns must agree.
    // Literal registers, source offsets and pre-interned exact types may differ.
    assert(a.ops[8]==b.ops[8] && a.ops[26]==0 && b.ops[26]==0 && a.ops[82]==b.ops[82]);
    var usize op=88;while(op<=115){assert(a.ops[op]==b.ops[op]);op+=1;}
}
fn void rejected(ref u8[] input){assert(switch(source::compile(input)){
    case .ok(_):{false}case .err(e):{e.offset<=input.len}
});}

@test fn void sole_reference_receivers_skip_len_copy_view_in_both_namespaces(){
    // Both selected return arms execute across the two namespaces. No Buffer,
    // copy destination, view, scalar capture or outer return can be invented.
    equivalent(b"module main;fn i32 main(){_ = bytes::len(ref if(true){return 42;}else{return 0;});}",
        b"module main;fn i32 main(){_ = if(true){return 42;}else{return 0;};}");
    equivalent(b"module main;fn i32 main(){_ = brownie::bytes::len(ref if(false){return 0;}else{return 42;});}",
        b"module main;fn i32 main(){_ = if(false){return 0;}else{return 42;};}");
    equivalent(b"module main;fn i32 main(){_ = bytes::copy(ref if(false){return 0;}else{return 42;});}",
        b"module main;fn i32 main(){_ = if(false){return 0;}else{return 42;};}");
    equivalent(b"module main;fn i32 main(){_ = brownie::bytes::copy(ref if(true){return 42;}else{return 0;});}",
        b"module main;fn i32 main(){_ = if(true){return 42;}else{return 0;};}");
    equivalent(b"module main;fn i32 main(){_ = bytes::view(ref if(true){return 42;}else{return 0;});}",
        b"module main;fn i32 main(){_ = if(true){return 42;}else{return 0;};}");
    equivalent(b"module main;fn i32 main(){let Option<i32> o=.none;_ = brownie::bytes::view(ref switch(o){case .some(_):{return 0;}case .none:{return 42;}});}",
        b"module main;fn i32 main(){let Option<i32> o=.none;_ = switch(o){case .some(_):{return 0;}case .none:{return 42;}};}");
    // Real terminal edges may transfer owners, tags or a selected shared input.
    omitted(b"module main;fn Buffer make(bool c){let scratch=bytes::empty();_ = bytes::len(ref if(c){return bytes::empty();}else{return bytes::empty();});}fn i32 main(){let a=make(true);let b=make(false);if(bytes::len(ref a)==0 && bytes::len(ref b)==0){return 42;}return 0;}",0,99,true,false);
    omitted(b"module main;fn Option<Buffer> make(bool c){_ = bytes::copy(ref if(c){return .some(bytes::empty());}else{return .none;});}fn i32 main(){switch(make(true)){case .some(b):{if(bytes::len(ref b)!=0){return 0;}}case .none:{return 0;}}switch(make(false)){case .some(_):{return 0;}case .none:{return 42;}}}",0,104,false,false);
    omitted(b"module main;fn ref u8[] pick(ref u8[] v,bool c){_ = bytes::view(ref if(c){return v;}else{return v[..];});}fn i32 main(){let b=bytes::empty();let a=pick(ref bytes::view(ref b),true);let z=pick(ref bytes::view(ref b),false);if(a.len==0 && z.len==0){return 42;}return 0;}",0,105,false,false);
}

@test fn void final_buffer_operands_preserve_temporary_receivers_and_once_only_index_effects(){
    omitted(b"module main;fn i32 main(){let b=bytes::empty();_ = bytes::read(ref b,if(true){return 42;}else{return 0;});}",0,100,true,false);
    omitted(b"module main;fn i32 main(){_ = brownie::bytes::read(ref bytes::empty(),if(false){return 0;}else{return 42;});}",0,100,true,false);
    omitted(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,if(false){return 0;}else{return 42;});}",0,102,true,false);
    omitted(b"module main;fn i32 main(){_ = brownie::bytes::push(ref mut bytes::empty(),if(true){return 42;}else{return 0;});}",0,102,true,false);
    omitted(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::reserve(ref mut b,if(true){return 42;}else{return 0;});}",0,103,true,false);
    omitted(b"module main;fn i32 main(){_ = brownie::bytes::reserve(ref mut bytes::empty(),if(false){return 0;}else{return 42;});}",0,103,true,false);
    omitted(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::append(ref mut b,ref if(false){return 0;}else{return 42;});}",0,104,true,false);
    omitted(b"module main;fn i32 main(){_ = brownie::bytes::append(ref mut bytes::empty(),ref if(true){return 42;}else{return 0;});}",0,104,true,false);
    // make's real call must execute exactly once before the index effect; an
    // invalid enclosing WRITE would trap on the empty receiver if it survived.
    let Snapshot write=snapshot(b"module main;fn Buffer make(){return bytes::empty();}fn i32 work(bool c){var seen=bytes::empty();bytes::write(ref mut make(),if(true){_ = bytes::push(ref mut seen,7);0}else{0},if(c){if(bytes::len(ref seen)!=1 || bytes::read(ref seen,0)!=7){return 0;}return 42;}else{if(bytes::len(ref seen)!=1 || bytes::read(ref seen,0)!=7){return 0;}return 42;});}fn i32 main(){if(work(true)==42 && work(false)==42){return 42;}return 0;}",1);
    assert(write.ops[101]==0 && write.ops[93]==1 && write.ops[102]==1 && write.ops[90]>0);
    omitted(b"module main;fn i32 main(){var b=bytes::empty();bytes::write(ref mut b,0,if(false){return 0;}else{return 42;});}",0,101,true,false);
    // A genuine failing propagation inside a terminal byte operand must retire
    // the already-created anonymous mutation receiver and its active loan.
    omitted(b"module main;fn Result<u8,u8> fail(){return .err(7);}fn Result<i32,u8> work(){_ = bytes::push(ref mut bytes::empty(),if(true){let u8 n=fail()?;return .ok(0);}else{return .ok(0);});}fn i32 main(){switch(work()){case .ok(_):{return 0;}case .err(e):{if(e==7){return 42;}return 0;}}}",1,102,true,false);
}

@test fn void final_view_index_and_upper_endpoints_close_real_captures_without_read_or_range(){
    omitted(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);_ = v[if(true){return 42;}else{return 0;}];}",0,111,true,true);
    omitted(b"module main;fn i32 main(){_ = bytes::view(ref bytes::empty())[if(false){return 0;}else{return 42;}];}",0,111,true,true);
    omitted(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);_ = v[..if(false){return 0;}else{return 42;}];}",0,106,true,true);
    omitted(b"module main;fn i32 main(){_ = brownie::bytes::view(ref bytes::empty())[0..if(true){return 42;}else{return 0;}];}",0,106,true,true);
    // A lower-endpoint effect precedes the final endpoint once. The view alias
    // was genuinely captured; terminal cleanup must close it before its root.
    let Snapshot range=snapshot(b"module main;fn i32 work(bool c){let b=bytes::empty();var seen=bytes::empty();let v=bytes::view(ref b);_ = v[if(true){_ = bytes::push(ref mut seen,9);0}else{0}..if(c){if(bytes::len(ref seen)!=1 || bytes::read(ref seen,0)!=9){return 0;}return 42;}else{if(bytes::len(ref seen)!=1 || bytes::read(ref seen,0)!=9){return 0;}return 42;}];}fn i32 main(){if(work(true)==42 && work(false)==42){return 42;}return 0;}",0);
    assert(range.ops[106]==0 && range.ops[111]==0 && range.ops[105]==1 && range.ops[107]>0);
    assert(range.ops[102]==1 && range.ops[109]>0 && range.ops[90]>0);
    // Baseline explicitly captures the same view before the terminal choice.
    equivalent(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);_ = v[if(false){return 0;}else{return 42;}];}",
        b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);let captured=v;_ = if(false){return 0;}else{return 42;};}");
}

@test fn void while_for_break_continue_and_void_returns_release_loans_before_post_loop_mutation(){
    omitted(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);var n=0;while(n<2){let v=bytes::view(ref b);_ = bytes::reserve(ref mut bytes::empty(),if(n==0){n+=1;continue;}else{n+=41;break;});}bytes::write(ref mut b,0,42);if(n==42 && bytes::read(ref b,0)==42){return 42;}return 0;}",0,103,true,true);
    omitted(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);var n=0;while(n<2){_ = bytes::append(ref mut b,ref if(n==0){n+=1;continue;}else{n+=41;break;});}bytes::write(ref mut b,0,42);if(n==42 && bytes::read(ref b,0)==42){return 42;}return 0;}",0,104,true,false);
    let Snapshot loop=snapshot(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);var n=0;for(var i=0;i<2;i+=1){bytes::write(ref mut b,if(true){n+=21;0}else{0},if(i==0){continue;}else{break;});}bytes::write(ref mut b,0,42);if(n==42 && bytes::read(ref b,0)==42){return 42;}return 0;}",0);
    assert(loop.ops[101]==1 && loop.ops[102]==1 && loop.ops[90]>0);
    omitted(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);var n=0;for(var i=0;i<2;i+=1){let v=bytes::view(ref b);_ = v[0..if(i==0){n+=21;continue;}else{n+=21;break;}];}bytes::write(ref mut b,0,42);if(n==42 && bytes::read(ref b,0)==42){return 42;}return 0;}",0,106,true,true);
    omitted(b"module main;fn void work(bool c){_ = bytes::read(ref bytes::empty(),if(c){return;}else{return;});}fn i32 main(){work(true);work(false);return 42;}",0,100,true,false);
    omitted(b"module main;fn void work(bool c){bytes::write(ref mut bytes::empty(),0,if(c){return;}else{return;});}fn i32 main(){work(true);work(false);return 42;}",0,101,true,false);
    omitted(b"module main;fn void work(bool c){_ = bytes::view(ref bytes::empty())[if(c){return;}else{return;}];}fn i32 main(){work(true);work(false);return 42;}",0,111,true,true);
}

@test fn void nonfinal_void_malformed_prefix_loan_and_result_errors_stay_rejected(){
    value(b"module main;fn i32 main(){_ = bytes::len(ref if(true){return 42;}else{return 0;});}");
    // Early bottom never repairs a wrong arity or a nonfinal operand.
    rejected(b"module main;fn i32 main(){_ = bytes::read(ref if(true){return 42;}else{return 0;},0);}");
    rejected(b"module main;fn i32 main(){_ = bytes::push(ref mut if(true){return 42;}else{return 0;},1);}");
    rejected(b"module main;fn i32 main(){_ = bytes::reserve(ref mut if(true){return 42;}else{return 0;},0);}");
    rejected(b"module main;fn i32 main(){_ = bytes::append(ref mut if(true){return 42;}else{return 0;},ref bytes::empty());}");
    rejected(b"module main;fn i32 main(){bytes::write(ref mut if(true){return 42;}else{return 0;},0,1);}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();bytes::write(ref mut b,if(true){return 42;}else{return 0;},1);}");
    rejected(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);_ = v[if(true){return 42;}else{return 0;}..0];}");
    rejected(b"module main;fn i32 main(){_ = bytes::read(ref if(true){return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){_ = bytes::push(ref mut if(true){return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){_ = bytes::reserve(ref mut if(true){return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){_ = bytes::append(ref mut if(true){return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){bytes::write(ref mut if(true){return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){_ = bytes::len(ref if(true){return 42;}else{return 0;},0);}");
    rejected(b"module main;fn i32 main(){_ = bytes::copy(ref if(true){return 42;}else{return 0;},0);}");
    rejected(b"module main;fn i32 main(){_ = bytes::view(ref if(true){return 42;}else{return 0;},0);}");
    // Closing delimiters and suffixes must still be parsed after bottom.
    rejected(b"module main;fn i32 main(){_ = bytes::len(ref if(true){return 42;}else{return 0;};}");
    rejected(b"module main;fn i32 main(){_ = bytes::copy(ref if(true){return 42;}else{return 0;}];}");
    rejected(b"module main;fn i32 main(){_ = bytes::view(ref if(true){return 42;}else{return 0;})garbage;}");
    rejected(b"module main;fn i32 main(){_ = bytes::read(ref bytes::empty(),if(true){return 42;}else{return 0;},0);}");
    rejected(b"module main;fn i32 main(){_ = bytes::push(ref mut bytes::empty(),if(true){return 42;}else{return 0;}];}");
    rejected(b"module main;fn i32 main(){_ = bytes::reserve(ref mut bytes::empty(),if(true){return 42;}else{return 0;};}");
    rejected(b"module main;fn i32 main(){bytes::write(ref mut bytes::empty(),0,if(true){return 42;}else{return 0;},1);}");
    rejected(b"module main;fn i32 main(){_ = bytes::append(ref mut bytes::empty(),ref if(true){return 42;}else{return 0;},ref bytes::empty());}");
    rejected(b"module main;fn i32 main(){_ = bytes::view(ref bytes::empty())[if(true){return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){_ = bytes::view(ref bytes::empty())[..if(true){return 42;}else{return 0;};}");
    rejected(b"module main;fn i32 main(){_ = bytes::view(ref bytes::empty())[0..if(true){return 42;}else{return 0;},0];}");
    rejected(b"module main;fn i32 main(){_ = bytes::view(ref bytes::empty())[if(true){return 42;}else{return 0;}].bad;}");
    // A void call is not bottom, in receiver, scalar, source or endpoint form.
    rejected(b"module main;fn void noop(){}fn i32 main(){_ = bytes::len(ref noop());return 42;}");
    rejected(b"module main;fn void noop(){}fn i32 main(){_ = bytes::read(ref bytes::empty(),noop());return 42;}");
    rejected(b"module main;fn void noop(){}fn i32 main(){_ = bytes::push(ref mut bytes::empty(),noop());return 42;}");
    rejected(b"module main;fn void noop(){}fn i32 main(){_ = bytes::reserve(ref mut bytes::empty(),noop());return 42;}");
    rejected(b"module main;fn void noop(){}fn i32 main(){bytes::write(ref mut bytes::empty(),0,noop());return 42;}");
    rejected(b"module main;fn void noop(){}fn i32 main(){_ = bytes::append(ref mut bytes::empty(),ref noop());return 42;}");
    rejected(b"module main;fn void noop(){}fn i32 main(){_ = bytes::view(ref bytes::empty())[noop()];return 42;}");
    rejected(b"module main;fn void noop(){}fn i32 main(){_ = bytes::view(ref bytes::empty())[..noop()];return 42;}");
    rejected(b"module main;fn i32 main(){_ = bytes::len(if(true){return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref b,if(true){return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::append(ref mut b,if(true){return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){let b=bytes::empty();_ = bytes::push(ref mut b,if(true){return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let v=bytes::view(ref b);_ = bytes::reserve(ref mut b,if(true){return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,if(true){_ = bytes::len(ref b);return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){let Result<i32,u8> pending=.ok(1);_ = bytes::len(ref if(true){return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){let Result<i32,u8> pending=.ok(1);_ = bytes::push(ref mut bytes::empty(),if(true){return 42;}else{return 0;});}");
    rejected(b"module main;fn i32 main(){let Result<i32,u8> pending=.ok(1);_ = bytes::view(ref bytes::empty())[..if(true){return 42;}else{return 0;}];}");
}
