module tests::m2::slice_result_owned_execution;
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

fn Result<usize,errors::Error> success(ref u8[] source,i64 expected){
    let ir::Program unit=compiler::inspect_slice_result_ir(source)?;
    var u8[256] data=[0;256];var runtime::State state=runtime::empty(256);
    let owners::Token root=create(ref mut state,1,ref mut data);let slices::Ticket parent=open(ref mut state,root,true,256);
    let runtime::Capture[1] args=[runtime::capture(parent,true,true)];let i64[1] values=[0];
    var runtime::Returned result=vm::run_slice_result(ref unit,0,ref args,ref values,ref mut state,ref mut data,1000000000)?;
    assert(read(ref state,result.held.issued,0,ref data)==expected);
    var usize live=0;var usize i=0;while(i<16){if(state.runtime.owners.slots[i].live){live+=1;}i+=1;}assert(live==1);
    let slices::Ticket current=result.held.issued;let runtime::Closed closed=runtime::close(ref mut state,ref mut result.held,current,256,runtime::cost())?;
    drained(ref state);return .ok(0);
}
@test fn void all_scalar_temporary_capture_modes_cleanup_once(){
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){return pick(ref [9;4],ref mut p);}fn ref mut i32[] pick(ref i32[] a,ref mut i32[] b){b[0]=42;return ref mut b;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){return pick(ref mut [9;4],ref mut p);}fn ref mut i32[] pick(ref mut i32[] a,ref mut i32[] b){b[0]=42;return ref mut b;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){return pick(ref [9;4],ref mut p);}fn ref mut i32[] pick(ref i64[] a,ref mut i32[] b){b[0]=42;return ref mut b;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){return pick(ref mut [9;4],ref mut p);}fn ref mut i32[] pick(ref mut i64[] a,ref mut i32[] b){b[0]=42;return ref mut b;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){return pick(ref [9;4],ref mut p);}fn ref mut i32[] pick(ref u8[] a,ref mut i32[] b){b[0]=42;return ref mut b;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){return pick(ref mut [9;4],ref mut p);}fn ref mut i32[] pick(ref mut u8[] a,ref mut i32[] b){b[0]=42;return ref mut b;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){return pick(ref [9;4],ref mut p);}fn ref mut i32[] pick(ref u32[] a,ref mut i32[] b){b[0]=42;return ref mut b;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){return pick(ref mut [9;4],ref mut p);}fn ref mut i32[] pick(ref mut u32[] a,ref mut i32[] b){b[0]=42;return ref mut b;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){return pick(ref [9;4],ref mut p);}fn ref mut i32[] pick(ref usize[] a,ref mut i32[] b){b[0]=42;return ref mut b;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){return pick(ref mut [9;4],ref mut p);}fn ref mut i32[] pick(ref mut usize[] a,ref mut i32[] b){b[0]=42;return ref mut b;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){return pick(ref [true;4],ref mut p);}fn ref mut i32[] pick(ref bool[] a,ref mut i32[] b){b[0]=42;return ref mut b;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){return pick(ref mut [true;4],ref mut p);}fn ref mut i32[] pick(ref mut bool[] a,ref mut i32[] b){b[0]=42;return ref mut b;}fn i32 main(){return 0;}",42).is_ok);
}
@test fn void ordinary_scalar_calls_restore_mutable_formals(){
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){let i32 n=touch(ref mut p,42);p[0]=n;return ref mut p;}fn i32 touch(ref mut i32[] p,i32 n){p[0]=n;return p[0];}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){let i32 n=count(ref mut p,5);p[0]=n;return ref mut p;}fn i32 count(ref mut i32[] p,i32 n){if(n==0){return p[0];}p[0]=p[0]+1;return count(ref mut p,n-1);}fn i32 main(){return 0;}",5).is_ok);
}
@test fn void owned_call_results_become_ranged_temporary_arguments(){
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){return pick(ref mut make()[lo()..3],ref mut p);}fn i32[4] make(){return [9;4];}fn usize lo(){return 1;}fn ref mut i32[] pick(ref mut i32[] a,ref mut i32[] b){b[0]=a[0]+33;return ref mut b;}fn i32 main(){return 0;}",42).is_ok);
}
@test fn void owned_arguments_copy_and_array_returns_move(){
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){let u8[4] a=[65;4];var usize lo=1;if(text::valid_utf8(a[lo..a.len]) && text::valid_utf8(a[0..2])){p[0]=42;}return ref mut p;}fn i32 main(){return 0;}",42).is_ok);
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){let i32[4] a=[3;4];let i32[4] b=bump(a,4);p[0]=a[0]+b[0];return ref mut p;}fn i32[4] bump(i32[4] a,i32 n){var i32[4] b=a;b[0]=n;return b;}fn i32 main(){return 0;}",7).is_ok);
}
@test fn void local_owned_borrows_close_before_drop_and_reuse(){
    assert(success(b"module main;fn ref mut i32[] f(ref mut i32[] p){var i32 n=0;while(n<3){var i32[4] a=make();p[0]=touch(ref mut a,n);n=n+1;}return ref mut p;}fn i32[4] make(){return [9;4];}fn i32 touch(ref mut i32[] p,i32 n){p[0]=n;return p[0];}fn i32 main(){return 0;}",2).is_ok);
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
@test fn void argument_failure_drains_temporary_roots_and_keeps_writes(){
    assert(failure(b"module main;fn ref mut i32[] f(ref mut i32[] p){p[0]=42;return pick(ref mut make()[5..8],ref mut p);}fn i32[4] make(){return [9;4];}fn ref mut i32[] pick(ref mut i32[] a,ref mut i32[] b){return ref mut b;}fn i32 main(){return 0;}",14,256,1000000000).is_ok);
    assert(failure(b"module main;fn ref mut i32[] f(ref mut i32[] p){p[0]=42;return pick(ref mut [9;4],bad(),ref mut p);}fn i32 bad(){return 1/0;}fn ref mut i32[] pick(ref mut i32[] a,i32 n,ref mut i32[] b){return ref mut b;}fn i32 main(){return 0;}",7,256,1000000000).is_ok);
}
@test fn void quota_and_call_fuel_failures_publish_no_result(){
    assert(failure(b"module main;fn ref mut i32[] f(ref mut i32[] p){p[0]=42;return pick(ref [9;4],ref mut p);}fn ref mut i32[] pick(ref i32[] a,ref mut i32[] b){return ref mut b;}fn i32 main(){return 0;}",13,16,1000000000).is_ok);
    assert(failure(b"module main;fn ref mut i32[] f(ref mut i32[] p){p[0]=42;let i32 n=bad();return ref mut p;}fn i32 bad(){return 7;}fn i32 main(){return 0;}",8,256,runtime::cost()+100000).is_ok);
}
