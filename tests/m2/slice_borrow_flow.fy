module tests::m2::slice_borrow_flow;
import ir as ir;
import compiler as compiler;
import errors as errors;
import slice_builders as builders;
import verifier as verifier;
import vm as vm;

fn usize built(Result<usize, errors::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } }; }
fn ir::Program compiled(ref u8[] source) { return switch(compiler::compile(source)) { case .ok(v): { v } case .err(_): { assert(false); ir::empty() } }; }
fn void accepted(ref ir::Program p) {
    assert(built(verifier::inspect(p))==p.count);
    assert(built(verifier::verify(p))==p.count);
    assert(switch(vm::run_with_array_limit(p,0,0)) { case .ok(_): { false } case .err(e): { e.kind==8 } });
}
fn void rejected(ref ir::Program p, usize pc) {
    assert(switch(verifier::inspect(p)) { case .ok(_): { false } case .err(e): { e.kind==5 && e.offset==pc } });
    assert(switch(verifier::verify(p)) { case .ok(_): { false } case .err(e): { e.kind==5 && e.offset==pc } });
    assert(switch(vm::run_with_array_limit(p,0,0)) { case .ok(_): { false } case .err(e): { e.kind==5 && e.offset==pc } });
}
fn void finish(ref mut ir::Program p, usize f) { let usize end=p.count; let usize regs=p.registers; p.ends[f]=end; p.register_ends[f]=regs; }
fn void entry(ref mut ir::Program p) {
    let usize start=p.count; let usize regs=p.registers; p.starts[1]=start; p.register_starts[1]=regs;
    let usize value=built(ir::literal(p,42,0)); let usize ret=built(ir::emit(p,8,value,0,0)); finish(p,1);
}
fn ir::Program retained(bool call) {
    var ir::Program p=ir::empty(); p.function_count=2; p.entry=1; p.arities[0]=1; p.return_types[0]=1; p.return_types[1]=1;
    let usize formal=built(builders::parameter(ref mut p,0,0)); let usize child=built(builders::derived(ref mut p,formal,0,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0)); let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize sub=built(ir::slice_sub(ref mut p,child,formal,lo,hi,0)); let usize close=built(ir::slice_close(ref mut p,formal,0));
    var usize value=0;
    if(call) { let usize[1] args=[160+child]; value=built(ir::call(ref mut p,0,ref args,0)); }
    else { value=built(ir::slice_read(ref mut p,child,lo,0)); }
    let usize drop=built(ir::slice_close(ref mut p,child,0));
    if(!call) { value=built(ir::widen(ref mut p,value,1,0)); }
    let usize ret=built(ir::emit(ref mut p,8,value,0,0)); finish(ref mut p,0); entry(ref mut p); return p;
}
fn ir::Program branched(bool loop) {
    var ir::Program p=ir::empty(); p.function_count=2; p.entry=1; p.arities[0]=2; p.return_types[0]=1; p.return_types[1]=1;
    let usize formal=built(builders::parameter(ref mut p,0,0)); p.types[1]=2; p.registers=2;
    let usize child=built(builders::derived(ref mut p,formal,0,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0)); let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize branch=built(ir::raw(ref mut p,20,0,1,if(loop){6}else{5},0));
    let usize sub=built(ir::slice_sub(ref mut p,child,formal,lo,hi,0)); let usize close=built(ir::slice_close(ref mut p,child,0));
    if(loop) { let usize back=built(ir::raw(ref mut p,22,0,2,0,0)); }
    let usize drop=built(ir::slice_close(ref mut p,formal,0)); let usize value=built(ir::literal(ref mut p,42,0));
    let usize ret=built(ir::emit(ref mut p,8,value,0,0)); finish(ref mut p,0); entry(ref mut p); return p;
}
fn usize opcode(ref ir::Program p, u8 op, usize f) { var usize pc=p.starts[f]; while(pc<p.ends[f]) { if(p.code[pc*8]==op) { return pc; } pc+=1; } assert(false); return 0; }
fn void skip(ref mut ir::Program p, usize pc) {
    p.code[pc*8]=19; p.code[pc*8+1]=0; p.code[pc*8+3]=0;
    let usize patched=built(ir::patch(p,pc,pc+1,0));
}

@test
fn void retained_children_are_readable_and_forwardable_after_anchor_close_with_public_verification() {
    let ir::Program p=retained(false); accepted(ref p); let ir::Program call=retained(true); accepted(ref call);
    let ir::Program source=compiled(b"module main;fn i32 f(ref u8[] p,i32 n){if(n==0){return p[0] as i32;}let ref u8[] q=ref p;return f(ref q,n-1);}fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p,2);}"); accepted(ref source);
    let ir::Program ordinary=compiled(b"module main;fn i32 f(u8[1] a){return a[0] as i32;}fn i32 main(){let u8[1] a=[42;1];return f(a);}");
    assert(built(verifier::inspect(ref ordinary))==built(verifier::verify(ref ordinary)));
    assert(switch(vm::run(ref ordinary,1000000)) { case .ok(v): { v==42 } case .err(_): { false } });
}

@test
fn void use_after_close_double_close_illegal_open_missing_cleanup_and_non_scalar_bounds_are_rejected() {
    let ir::Program p=retained(false); accepted(ref p);
    var ir::Program bad=p; bad.code[34]=0; rejected(ref bad,4);
    bad=p; bad.code[25]=1; rejected(ref bad,4);
    bad=p; bad.code[41]=0; rejected(ref bad,5);
    bad=p; bad.code[17]=0; rejected(ref bad,2);
    bad=p; bad.code[20]=0; rejected(ref bad,2);
    bad=p; bad.code[21]=1; rejected(ref bad,2);
    bad=p; bad.code[33]=0; rejected(ref bad,4);
    bad=p; bad.code[24]=54; rejected(ref bad,3);
    bad=p; bad.code[35]=5; rejected(ref bad,4);
    bad=p; skip(ref mut bad,5); rejected(ref bad,7);
}

@test
fn void branch_joins_and_backedges_require_exact_borrow_live_sets() {
    let ir::Program branch=branched(false); accepted(ref branch);
    var ir::Program bad=branch; skip(ref mut bad,4); rejected(ref bad,4);
    bad=branch; bad.code[19]=4; rejected(ref bad,3);
    let ir::Program loop=branched(true); accepted(ref loop);
    bad=loop; skip(ref mut bad,4); rejected(ref bad,5);
    bad=loop; bad.code[33]=0; rejected(ref bad,5);
}

@test
fn void call_checks_each_parameter_kind_live_source_function_and_unused_argument_byte() {
    let ir::Program p=compiled(b"module main;struct P{i32 x;}fn i32 f(ref u8[] p,i32 n,u8[1] a,P r){return p[0] as i32+n+a[0] as i32+r.x;}fn i32 main(){let u8[1] a=[1;1];let ref u8[] p=ref a;let P r=P{.x=40};return f(ref p,0,a,r);}"); accepted(ref p);
    let usize pc=opcode(ref p,9,1); let usize site=p.code[pc*8+3] as usize; let usize base=site*8;
    var usize i=0; while(i<9) {
        var ir::Program bad=p;
        if(i==0) { bad.call_args[base]=p.call_args[base+1]; } else if(i==1) { bad.call_args[base]=p.call_args[base+2]; }
        else if(i==2) { bad.call_args[base]=p.call_args[base+3]; } else if(i==3) { bad.call_args[base]=176; }
        else if(i==4) { bad.call_args[base]=160; } else if(i==5) { bad.call_args[base+1]=p.call_args[base]; }
        else if(i==6) { bad.call_args[base+2]=p.call_args[base]; } else if(i==7) { bad.call_args[base+3]=p.call_args[base]; }
        else { bad.call_args[base+4]=1; }
        rejected(ref bad,pc); i+=1;
    }
    var ir::Program dead=p; let usize before=pc-1;
    dead.code[before*8]=56; dead.code[before*8+1]=1; dead.code[before*8+2]=0; dead.code[before*8+3]=0; rejected(ref dead,pc);
    let ir::Program duplicate=compiled(b"module main;fn i32 f(ref u8[] p,ref u8[] q){return p[0] as i32;}fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p,ref p);}"); accepted(ref duplicate);
}

@test
fn void aggregate_returns_require_all_borrows_closed_and_borrowed_positions_never_escape_as_scalars() {
    let ir::Program array=compiled(b"module main;fn u8[1] f(ref u8[] p){return [p[0];1];}fn i32 main(){return 42;}"); accepted(ref array);
    let usize ret=opcode(ref array,39,0); let usize close=opcode(ref array,56,0);
    var ir::Program bad=array; skip(ref mut bad,close); rejected(ref bad,ret);
    let ir::Program record=compiled(b"module main;struct P{i32 x;}fn P f(ref u8[] p){let P r=P{.x=p[0] as i32};return r;}fn i32 main(){return 42;}"); accepted(ref record);
    let ir::Program p=retained(false); bad=p; bad.code[58]=0; rejected(ref bad,7);
    bad=p; bad.types[0]=1; rejected(ref bad,0);
}
