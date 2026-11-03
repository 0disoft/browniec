module tests::m2::slice_result_record_execution;
import vm as vm;
import compiler as compiler;
import slice_result_ir as ir;
import slice_result_runtime as runtime;
import slice_authority as authority;
import array_slices as slices;
import array_owners as owners;
import array_layout as layout;
import errors as errors;
fn owners::Token create(ref mut runtime::State state,u8 tag,ref mut u8[] data){
    let layout::Array shape=switch(layout::scalar(tag,4)){case .ok(v):{v}case .err(_):{assert(false);layout::Array{.element=1,.length=4,.stride=4,.alignment=4,.bytes=16}}};
    return switch(owners::create(ref shape,0,data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn slices::Ticket open(ref mut runtime::State state,owners::Token root,bool exclusive,usize capacity){
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket t=switch(if(exclusive){slices::open_exclusive(ref mut pool,ref mut table,root,0,4,capacity)}else{slices::open(ref mut pool,ref mut table,root,0,4,capacity)}){
        case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}
    };state.runtime.pool=pool;state.runtime.owners=table;return t;
}
fn i64 read(ref runtime::State state,slices::Ticket t,usize index,ref u8[] data){return switch(slices::read(ref state.runtime.pool,t,ref state.runtime.owners,index,data)){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}

fn Result<usize,errors::Error> success_at(ref u8[] source,i64 expected,usize capacity){
    let ir::Program unit=compiler::inspect_slice_result_ir(source)?;
    var u8[256] data=[0;256];var runtime::State state=runtime::empty(capacity);
    let owners::Token root=create(ref mut state,1,ref mut data[..capacity]);let slices::Ticket parent=open(ref mut state,root,true,capacity);
    let runtime::Capture[1] args=[runtime::capture(parent,true,true)];let i64[1] values=[0];
    var runtime::Returned result=vm::run_slice_result(ref unit,0,ref args,ref values,ref mut state,ref mut data[..capacity],1000000000)?;
    assert(read(ref state,result.held.issued,0,ref data)==expected);
    var usize live=0;var usize i=0;while(i<16){if(state.runtime.owners.slots[i].live){live+=1;}i+=1;}assert(live==1);
    let slices::Ticket current=result.held.issued;let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,capacity,runtime::cost())?;
    drained(ref state);return .ok(0);
}
fn Result<usize,errors::Error> success(ref u8[] source,i64 expected){return success_at(source,expected,256);}
@test fn void record_return_moves_without_a_second_payload_extent(){
    assert(success_at(b"module main;struct P{i32 x;}fn ref mut i32[] f(ref mut i32[] p){let P a=make();p[0]=a.x;return ref mut p;}fn P make(){return P{.x=42};}fn i32 main(){return 0;}",42,20).is_ok);
}
@test fn void nested_record_locals_use_shared_owner_table(){
    assert(success(b"module main;struct P{i32 x;}struct R{P a;P b;}fn ref mut i32[] f(ref mut i32[] p){var R a=R{.a=P{.x=1},.b=P{.x=2}};var R b=a;b.a.x=20;a=b;a.a=b.b;a.b=P{.x=22};a=R{.a=P{.x=20},.b=P{.x=22}};p[0]=a.a.x+a.b.x;return ref mut p;}fn i32 main(){return 0;}",42).is_ok);
}
@test fn void mixed_record_array_scalar_and_borrowed_arguments_copy_values(){
    assert(success(b"module main;struct P{i32 x;}fn ref mut i32[] f(ref mut i32[] p){let P a=P{.x=3};let i32[4] b=[4;4];p[0]=sum(a,a,b,ref mut p,2)+a.x+b[0];return ref mut p;}fn i32 sum(P a,P b,i32[4] c,ref mut i32[] p,i32 n){var P q=a;q.x=20;var i32[4] d=c;d[0]=10;p[0]=1;return q.x+b.x+d[0]+n;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;struct P{bool a;u8 b;i32 c;i64 d;u32 e;usize f;}fn ref mut i32[] run(ref mut i32[] p){let P a=P{.a=true,.b=255,.c=-2147483648,.d=-9223372036854775808,.e=4294967295,.f=18446744073709551615};p[0]=check(a);return ref mut p;}fn i32 check(P a){if(a.a && a.b==255 && a.c==-2147483648 && a.d==-9223372036854775808 && a.e==4294967295 && a.f==18446744073709551615){return 42;}return 0;}fn i32 main(){return 0;}",42).is_ok);
}
@test fn void record_results_move_across_calls_and_restore_writers(){
    assert(success(b"module main;struct P{i32 x;}fn ref mut i32[] f(ref mut i32[] p){let P a=make(ref mut p);let P b=id(a);p[0]=p[0]+b.x;return ref mut p;}fn P make(ref mut i32[] p){p[0]=20;return P{.x=22};}fn P id(P p){return p;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;struct P{i32 x;}fn ref mut i32[] f(ref mut i32[] p){let P a=count(P{.x=40},2);p[0]=a.x;return ref mut p;}fn P count(P p,i32 n){if(n==0){return p;}return count(P{.x=p.x+1},n-1);}fn i32 main(){return 0;}",42).is_ok);
}
@test fn void lexical_records_reuse_slots_and_forwarded_cleanup_is_atomic(){
    assert(success(b"module main;struct P{i32 x;}fn ref mut i32[] f(ref mut i32[] p){var i32 n=0;while(n<20){let P a=make(n);p[0]=a.x;n=n+1;}let P local=P{.x=42};let i32[4] a=[1;4];return pass(ref mut p,local,a);}fn P make(i32 n){return P{.x=n};}fn ref mut i32[] pass(ref mut i32[] p,P q,i32[4] a){p[0]=q.x;return ref mut p;}fn i32 main(){return 0;}",42).is_ok);
}
@test fn void ordinary_array_and_scalar_returns_drop_record_locals(){
    assert(success(b"module main;struct P{i32 x;}fn ref mut i32[] f(ref mut i32[] p){let i32[4] a=make();p[0]=a[0]+get();return ref mut p;}fn i32[4] make(){let P a=P{.x=20};return [a.x;4];}fn i32 get(){let P a=P{.x=22};return a.x;}fn i32 main(){return 0;}",42).is_ok);
}
fn Result<usize,errors::Error> failure(ref u8[] source,u8 kind,usize capacity,usize fuel){
    let ir::Program unit=compiler::inspect_slice_result_ir(source)?;
    var u8[256] data=[0;256];var runtime::State state=runtime::empty(capacity);
    let owners::Token root=create(ref mut state,1,ref mut data[..capacity]);let slices::Ticket parent=open(ref mut state,root,true,capacity);
    let runtime::Capture[1] args=[runtime::capture(parent,true,true)];let i64[1] values=[0];
    switch(vm::run_slice_result(ref unit,0,ref args,ref values,ref mut state,ref mut data[..capacity],fuel)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
    };assert(data[0]==42);drained(ref state);return .ok(0);
}
@test fn void record_failures_keep_first_error_writes_and_drain_invocation(){
    assert(failure(b"module main;struct P{i32 x;}fn ref mut i32[] f(ref mut i32[] p){p[0]=42;let P a=P{.x=1};let i32 n=bad(a);return ref mut p;}fn i32 bad(P a){return a.x/0;}fn i32 main(){return 0;}",7,256,1000000000).is_ok);
    assert(failure(b"module main;struct P{i32 x;}fn ref mut i32[] f(ref mut i32[] p){p[0]=42;let P a=P{.x=1};let i32 n=use(a);return ref mut p;}fn i32 use(P a){return a.x;}fn i32 main(){return 0;}",13,20,1000000000).is_ok);
    assert(failure(b"module main;struct P{i32 x;}fn ref mut i32[] f(ref mut i32[] p){p[0]=42;let P a=P{.x=1};return ref mut p;}fn i32 main(){return 0;}",8,256,runtime::cost()+100000).is_ok);
}
