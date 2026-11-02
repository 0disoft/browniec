module tests::m2::slice_shared_call_authority;
import ir as ir;
import compiler as compiler;
import errors as errors;
import vm_reborrow_execution as runner;
import vm_execution as execution;
import slice_reborrow_ir as proof;
import slice_authority as authority;
import slice_authority_call_vm as calls;
import slice_reborrow_vm as children;
import slice_reborrow_context as context;
import slice_vm as loans;
import slice_call_vm as shared;
import array_vm as arrays;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import struct_vm as records;
import slice_mutable_call_vm as mixed;
import std::bytes as bytes;

fn ir::Program compiled(ref u8[] s){return switch(compiler::compile(s)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 answer(Result<i64,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn bytes::Buffer backing(){return switch(arrays::prepare(64)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};}
fn usize pc(ref ir::Program p){var usize at=p.starts[p.entry];while(at<p.ends[p.entry] && p.code[at*8]!=9){at+=1;}assert(at<p.ends[p.entry]);return at;}
fn proof::Sites sites(ref ir::Program p){return switch(runner::inspect(p)){case .ok(v):{v}case .err(_):{assert(false);proof::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};}
fn ir::Program fixture(){return compiled(b"module main;fn i32 f(ref i32[] q,ref mut i32[] p,ref i32[] r){p[0]=q[0]+r[0];return p[0];}fn i32 main(){let i32[2] a=[21;2];var i32[2] b=[0;2];let ref i32[] q=ref a[1..2];let ref mut i32[] p=ref mut b;return f(ref q,ref mut p,ref q);}");}
fn void initialize(ref ir::Program p,ref mut arrays::State a,ref mut loans::State l,ref mut bytes::Buffer b){
    var usize i=0;while(i<p.arrays.count){let layouts::Array shape=switch(layouts::scalar(p.arrays.elements[i],p.arrays.lengths[i])){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=1,.length=2,.stride=4,.alignment=4,.bytes=8}}};
        let owners::Token created=switch(owners::create(ref shape,21,bytes::view_mut(b),ref mut a.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};a.tokens[i]=created;i+=1;}
    let usize at=pc(p);let usize args=p.code[at*8+3] as usize;i=0;while(i<3){let usize site=(p.call_args[args*8+i] as usize)-160;if(l.tickets[site].generation==0){let owners::Token root=a.tokens[(p.slice_roots[site] as usize)-1];
        let slices::Ticket opened=if(ir::exclusive(p,site)){ticket(slices::open_exclusive(ref mut l.pool,ref mut a.owners,root,0,2,64))}else{ticket(slices::open(ref mut l.pool,ref mut a.owners,root,1,2,64))};l.tickets[site]=opened;}i+=1;}
}
fn void same_pool(ref slices::Pool a,ref slices::Pool b){var usize i=0;while(i<16){let slices::Slot x=a.slots[i];let slices::Slot y=b.slots[i];assert(x.generation==y.generation && x.live==y.live && x.exclusive==y.exclusive && x.lease.generation==y.lease.generation && x.view.root.slot==y.view.root.slot && x.view.root.generation==y.view.root.generation && x.view.start==y.view.start && x.view.end==y.view.end);i+=1;}}
fn void execute(ref ir::Program p,i64 expected){
    let proof::Sites map=sites(p);var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();
    assert(answer(runner::execute(p,10000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==expected);assert(context::ready(ref auth[0],ref c[0],ref links[0],ref l,ref f).is_ok && a.owners.depth==0);
}

fn void run(ref u8[] source,i64 expected){let ir::Program p=compiled(source);execute(ref p,expected);}

@test
fn void all_six_scalar_tags_duplicates_empty_ranges_and_utf8_execute(){
    run(b"module main;fn i32 f(ref i32[] a,ref bool[] b,ref i64[] c,ref u8[] d,ref u32[] e,ref usize[] g){if(a[0]!=-2147483648 || !b[0] || c[0]!=-9223372036854775808 || d[0]!=255 || e[0]!=4294967295 || g[0]!=18446744073709551615){return 0;}return 42;}fn i32 main(){let i32[1] a=[-2147483648;1];let bool[1] b=[true;1];let i64[1] c=[-9223372036854775808;1];let u8[1] d=[255;1];let u32[1] e=[4294967295;1];let usize[1] g=[18446744073709551615;1];let ref i32[] p=ref a;let ref bool[] q=ref b;let ref i64[] r=ref c;let ref u8[] s=ref d;let ref u32[] t=ref e;let ref usize[] u=ref g;return f(ref p,ref q,ref r,ref s,ref t,ref u);}",42);
    run(b"module main;fn i32 f(ref u8[] a,ref u8[] b,ref u8[] c,ref u8[] d,ref u8[] e,ref u8[] f,ref u8[] g,ref u8[] h){return a[0] as i32+h[0] as i32;}fn i32 main(){let u8[1] a=[21;1];let ref u8[] p=ref a;return f(ref p,ref p,ref p,ref p,ref p,ref p,ref p,ref p);}",42);
    run(b"module main;fn i32 f(ref u8[] p){if(p.len==0 && text::valid_utf8(p)){return 42;}return 0;}fn i32 main(){let u8[1] a=[65;1];let ref u8[] p=ref a[1..1];return f(ref p);}",42);
}
@test
fn void shared_derived_forwarding_close_before_child_use_and_recursion(){
    var ir::Program p=compiled(b"module main;fn i32 read(ref i32[] p){return p[0];}fn i32 f(ref i32[] p){let ref i32[] q=ref p[1..2];return read(ref q);}fn i32 main(){let i32[2] a=[42;2];let ref i32[] p=ref a;return f(ref p);}");
    let usize formal=(p.slice_parameters[p.register_starts[1]] as usize)-1;var usize call=p.starts[1];while(p.code[call*8]!=9){call+=1;}
    var usize close=call+1;while(!(p.code[close*8]==56 && p.code[close*8+1] as usize==formal)){close+=1;}assert(close<p.ends[1]);
    var u8[8] saved=[0;8];var usize i=0;while(i<8){saved[i]=p.code[close*8+i];i+=1;}let usize offset=p.offsets[close];
    while(close>call){i=0;while(i<8){let u8 moved=p.code[(close-1)*8+i];p.code[close*8+i]=moved;i+=1;}let usize moved_offset=p.offsets[close-1];p.offsets[close]=moved_offset;close-=1;}
    i=0;while(i<8){p.code[call*8+i]=saved[i];i+=1;}p.offsets[call]=offset;execute(ref p,42);
    run(b"module main;fn i32 f(ref i32[] p,i32 n){if(n==0){return p[0];}return f(ref p,n-1);}fn i32 main(){let i32[1] a=[42;1];let ref i32[] p=ref a;return f(ref p,10);}",42);
}
@test
fn void mixed_readers_writers_and_scalar_helpers_preserve_argument_positions(){
    run(b"module main;fn i32 add(i32 a,i32 b){return a+b;}fn i32 f(ref i32[] q,ref mut i32[] p,ref i32[] r){p[0]=add(q[0],r[0]);return p[0];}fn i32 main(){let i32[1] a=[21;1];var i32[1] b=[0;1];let ref i32[] q=ref a;let ref mut i32[] p=ref mut b;return f(ref q,ref mut p,ref q);}",42);
}
@test
fn void short_fuel_late_writer_reserve_and_shared_pool_exhaustion_are_atomic(){
    let ir::Program p=fixture();let proof::Sites map=sites(ref p);let usize at=pc(ref p);let usize price=built(calls::cost(ref p,at,77));assert(price==4+5*65537 && price==built(mixed::cost(ref p,0,77)));
    var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var records::State s=records::empty();var bytes::Buffer b=backing();initialize(ref p,ref mut a,ref mut l,ref mut b);
    let usize args=p.code[at*8+3] as usize;let usize w=(p.call_args[args*8+1] as usize)-160;let usize q=(p.call_args[args*8] as usize)-160;let slices::Ticket original=l.tickets[w];
    let slices::Pool before=l.pool;assert(switch(calls::enter(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref a,ref s,ref b,price-1)){case .ok(_):{false}case .err(e):{e.kind==8}});same_pool(ref l.pool,ref before);
    l.pool.slots[original.slot].generation=18446744073709551615;l.tickets[w].generation=18446744073709551615;let slices::Pool exhausted=l.pool;
    assert(!calls::enter(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref a,ref s,ref b,price).is_ok);same_pool(ref l.pool,ref exhausted);assert(auth.depth==0 && c.pcs[0]==256 && f.origins[8].generation==0);
    l.pool.slots[original.slot].generation=original.generation;l.tickets[w]=original;let slices::Ticket reader=l.tickets[q];var usize n=0;while(n<13){let slices::Ticket extra=ticket(slices::subslice(ref mut l.pool,reader,ref a.owners,0,1,64));n+=1;}
    let slices::Pool full=l.pool;assert(!calls::enter(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref a,ref s,ref b,price).is_ok);same_pool(ref l.pool,ref full);assert(auth.depth==0 && l.tickets[w].generation==original.generation);
    assert(answer(calls::finish(ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref b,.ok(42)))==42);
}
@test
fn void return_closes_readers_atomically_and_preserves_caller_ticket(){
    let ir::Program p=fixture();let proof::Sites map=sites(ref p);let usize at=pc(ref p);var arrays::State a=arrays::empty(64);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var records::State s=records::empty();var bytes::Buffer b=backing();initialize(ref p,ref mut a,ref mut l,ref mut b);
    let usize args=p.code[at*8+3] as usize;let usize q=(p.call_args[args*8] as usize)-160;let slices::Ticket caller=l.tickets[q];let usize remaining=built(calls::enter(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref a,ref s,ref b,built(calls::cost(ref p,at,77))));assert(remaining==0 && auth.counts[0]==1);
    let usize x=(p.slice_parameters[0] as usize)-1;let usize y=(p.slice_parameters[2] as usize)-1;assert(l.tickets[16+x].slot!=l.tickets[16+y].slot && l.tickets[q].generation==caller.generation);
    // The higher shared site closes in the staged pool before this stale one fails.
    let usize low=if(x<y){x}else{y};let usize generation=l.tickets[16+low].generation;l.tickets[16+low].generation+=1;let slices::Pool saved=l.pool;
    assert(!calls::leave(ref p,0,1,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref s,ref b,77).is_ok);same_pool(ref l.pool,ref saved);assert(auth.depth==1 && c.pcs[0]==at);
    l.tickets[16+low].generation=generation;let owners::Token origin=f.origins[8];f.origins[8].generation+=1;assert(!calls::leave(ref p,0,1,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref s,ref b,77).is_ok);same_pool(ref l.pool,ref saved);f.origins[8]=origin;
    assert(built(calls::leave(ref p,0,1,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref s,ref b,77))==1);assert(auth.depth==0 && l.tickets[q].slot==caller.slot && l.tickets[q].generation==caller.generation && slices::length(ref l.pool,caller,ref a.owners,64).is_ok);
    assert(answer(calls::finish(ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref b,.ok(42)))==42);
}
@test
fn void mixed_abort_preserves_writes_original_error_and_failed_cleanup_maps(){
    let ir::Program p=compiled(b"module main;fn i32 f(ref i32[] q,ref mut i32[] p,i32 z){p[0]=q[0];return 1/z;}fn i32 main(){let i32[1] a=[42;1];var i32[1] b=[0;1];let ref i32[] q=ref a;let ref mut i32[] p=ref mut b;return f(ref q,ref mut p,0);}");let proof::Sites map=sites(ref p);
    var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=backing();
    let errors::Error failure=switch(execution::execute_canonical(ref p,ref map,1000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(_):{assert(false);errors::make(0,0)}case .err(e):{e}};assert(failure.kind==7 && auth[0].depth==1);
    let usize epoch=a.owners.slots[0].read_generation;a.owners.slots[0].read_generation+=1;assert(!context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.err(failure)).is_ok);assert(auth[0].depth==1 && c[0].pcs[0]!=256);a.owners.slots[0].read_generation=epoch;
    assert(switch(context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.err(failure))){case .ok(_):{false}case .err(e):{e.kind==7 && e.offset==failure.offset}});assert(context::ready(ref auth[0],ref c[0],ref links[0],ref l,ref f).is_ok);
    assert(switch(owners::read(ref a.owners,a.tokens[1],0,bytes::view(ref b))){case .ok(v):{v==42}case .err(_):{false}});
}
