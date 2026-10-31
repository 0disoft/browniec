module tests::m2::slice_lifecycle_vm;
import compiler as compiler;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import vm_execution as execution;
import slice_lifecycle_vm as lifecycle;
import slice_call_vm as calls;
import slice_vm as loans;
import array_vm as arrays;
import array_slices as slices;
import array_owners as owners;
import std::bytes as bytes;

fn void cleared(ref calls::Frames frames,ref loans::State loan,ref arrays::State state) {
    var usize i=0;while(i<256){assert(frames.origins[i].slot==16 && frames.origins[i].generation==0);i+=1;}
    i=0;while(i<512){assert(loan.tickets[i].slot==16 && loan.tickets[i].generation==0);i+=1;}
    i=0;while(i<16){assert(!loan.pool.slots[i].live && !state.owners.slots[i].reading);i+=1;}
}
fn void run(ref u8[] source,usize fuel,u8 expected,i64 value,bool corrupt) {
    let ir::Program p=switch(compiler::compile(source)){case .ok(v):{v}case .err(e):{assert(false);ir::empty()}};
    assert(verifier::inspect(ref p).is_ok && verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,0,0)){case .ok(_):{false}case .err(e):{e.kind==8}});
    var arrays::State state=arrays::empty(256);var loans::State loan=loans::empty();var calls::Frames frames=calls::empty();
    var bytes::Buffer data=switch(arrays::prepare(256)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    var u8 kind=0;var usize offset=0;
    let i64 answer=switch(execution::execute(ref p,fuel,ref mut state,ref mut data,ref mut loan,ref mut frames)) {
        case .ok(v):{v}case .err(e):{kind=e.kind;offset=e.offset;0}
    };
    assert(kind==expected);if(kind==0){assert(answer==value);cleared(ref frames,ref loan,ref state);}
    else {var bool active=false;var usize i=8;while(i<256){if(frames.origins[i].generation!=0){active=true;}i+=1;}assert(active);}
    if(corrupt) {
        var usize slot=0;while(slot<16 && !loan.pool.slots[slot].live){slot+=1;}assert(slot<16);
        let slices::Slot saved=loan.pool.slots[slot];var slices::Slot bad=saved;bad.view.end=bad.view.length+1;loan.pool.slots[slot]=bad;
        let calls::Frames old=calls::Frames{.origins=frames.origins};let slices::Ticket first=loan.tickets[0];
        assert(switch(lifecycle::finish(ref mut frames,ref mut loan,ref mut state,ref data,.err(errors::make(kind,offset)))) {
            case .ok(_):{false}case .err(e):{e.kind==14 && e.offset==0}
        });
        var usize i=0;while(i<256){assert(frames.origins[i].slot==old.origins[i].slot && frames.origins[i].generation==old.origins[i].generation);i+=1;}
        assert(loan.pool.slots[slot].live && loan.pool.slots[slot].view.end==bad.view.end && loan.tickets[0].generation==first.generation);
        loan.pool.slots[slot]=saved;
    }
    if(kind==0) {
        assert(switch(lifecycle::finish(ref mut frames,ref mut loan,ref mut state,ref data,.ok(answer))){case .ok(v):{v==value}case .err(_):{false}});
    } else {
        assert(switch(lifecycle::finish(ref mut frames,ref mut loan,ref mut state,ref data,.err(errors::make(kind,offset)))){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==offset}});
    }
    // The public wrapper prepays backing before this same execution budget.
    assert(switch(vm::run_with_array_limit(ref p,fuel+257,256)) {
        case .ok(v):{expected==0 && v==value}
        case .err(e):{e.kind==expected && e.offset==offset}
    });
    cleared(ref frames,ref loan,ref state);
}

@test
fn void nested_dynamic_dispatch_and_reused_frames() {
    run(b"module main;fn i32 leaf(ref u8[] p){let ref u8[] q=ref p[1..];if(text::valid_utf8(q)){return q[q.len-1] as i32;}return 0;}fn i32 mid(ref u8[] p){return leaf(ref p);}fn i32 main(){var u8[4] a=[42;4];var i32 n=0;{let ref u8[] p=ref a;n=mid(ref p)+mid(ref p);}a[0]=1;return n-42;}",3000000,0,42,false);
    run(b"module main;fn i32 f(ref u8[] p){let u8[2] a=[42;2];let ref u8[] own=ref a;return (p[0] as i32)+(own[0] as i32)-42;}fn i32 main(){let u8[2] a=[42;2];let ref u8[] p=ref a;return f(ref p);}",3000000,0,42,false);
}

@test
fn void aggregate_returns_close_origins_before_owner_transfer() {
    run(b"module main;fn u8[2] make(ref u8[] p,u8[2] a){return a;}fn i32 main(){let u8[2] a=[42;2];let ref u8[] p=ref a;let u8[2] b=make(ref p,a);return b[0] as i32;}",3000000,0,42,false);
    run(b"module main;struct P{i32 n;}fn P make(ref u8[] p,P a){return a;}fn i32 main(){let u8[2] a=[42;2];let P v=P{.n=42};let ref u8[] p=ref a;let P b=make(ref p,v);return b.n;}",3000000,0,42,false);
}

@test
fn void question_propagation_and_loop_transfers_close_lexical_loans() {
    run(b"module main;fn Option<i32> f(ref u8[] p,Option<i32> o){let ref u8[] q=ref p;let i32 n=o?;return .some(n+(q[0] as i32));}fn i32 main(){let u8[2] a=[42;2];let ref u8[] p=ref a;switch(f(ref p,.none)){case .some(_):{return 0;}case .none:{}}return switch(f(ref p,.some(0))){case .some(v):{v}case .none:{0}};}",3000000,0,42,false);
    run(b"module main;fn i32 f(ref u8[] p){var i32 n=0;var usize i=0;while(i<3){let ref u8[] q=ref p;i=i+1;if(i==1){continue;}n=n+(q[0] as i32);break;}return n;}fn i32 main(){let u8[2] a=[42;2];let ref u8[] p=ref a;return f(ref p);}",3000000,0,42,false);
    run(b"module main;fn i32 f(ref u8[] p){var i32 n=0;for(var usize i=0;i<3;i=i+1){let ref u8[] q=ref p;if(i==0){continue;}n=n+(q[0] as i32);break;}return n;}fn i32 main(){let u8[2] a=[42;2];let ref u8[] p=ref a;return f(ref p);}",3000000,0,42,false);
}

@test
fn void abort_cleanup_preserves_fuel_bounds_arithmetic_and_nested_errors() {
    run(b"module main;fn i32 f(ref u8[] p){return (p[0] as i32)/0;}fn i32 mid(ref u8[] p){return f(ref p);}fn i32 main(){let u8[2] a=[42;2];let ref u8[] p=ref a;return mid(ref p);}",3000000,7,0,false);
    run(b"module main;fn i32 f(ref u8[] p){return p[9] as i32;}fn i32 main(){let u8[2] a=[42;2];let ref u8[] p=ref a;return f(ref p);}",3000000,14,0,false);
    run(b"module main;fn i32 f(ref u8[] p){return (p[0] as i32)+2147483647;}fn i32 main(){let u8[2] a=[42;2];let ref u8[] p=ref a;return f(ref p);}",3000000,6,0,false);
    run(b"module main;fn i32 f(ref u8[] p){return p[0] as i32;}fn i32 main(){let u8[2] a=[42;2];let ref u8[] p=ref a;return f(ref p);}",200000,8,0,false);
}

@test
fn void failed_cleanup_keeps_bindings_until_successful_repair() {
    run(b"module main;fn i32 f(ref u8[] p){return (p[0] as i32)/0;}fn i32 main(){let u8[2] a=[42;2];let ref u8[] p=ref a;return f(ref p);}",3000000,7,0,true);
}

@test
fn void public_capacity_failures_are_contained_after_borrowed_admission() {
    run(b"module main;fn i32 f(ref u8[] p,i32 n){if(n==0){return p[0] as i32;}return f(ref p,n-1);}fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p,30);}",5000000,13,0,false);
    let ir::Program p=switch(compiler::compile(b"module main;fn i32 f(ref u8[] p,u8[4] a){return a[0] as i32;}fn i32 main(){let u8[4] a=[42;4];let ref u8[] p=ref a;return f(ref p,a);}")){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,1000000,4)){case .ok(_):{false}case .err(e):{e.kind==13}});
}
