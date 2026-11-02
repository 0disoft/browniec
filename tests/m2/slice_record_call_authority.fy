module tests::m2::slice_record_call_authority;
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
import slice_mutable_call_vm as legacy;
import call_frame_vm as control;
import std::bytes as bytes;
import struct_layout as layouts_record;

fn ir::Program compiled(ref u8[] s){return switch(compiler::compile(s)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 answer(Result<i64,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize done(Result<usize,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn bytes::Buffer backing(){return switch(arrays::prepare(256)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};}
fn layouts::Array shape(u8 tag,usize n){return switch(layouts::scalar(tag,n)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=1,.length=1,.stride=4,.alignment=4,.bytes=4}}};}
fn owners::Token create(ref mut arrays::State a,ref mut bytes::Buffer b,u8 tag,usize n,i64 value){let layouts::Array s=shape(tag,n);return switch(owners::create(ref s,value,bytes::view_mut(b),ref mut a.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}};}
fn usize pc(ref ir::Program p){var usize at=p.starts[p.entry];while(at<p.ends[p.entry] && p.code[at*8]!=9){at+=1;}assert(at<p.ends[p.entry]);return at;}
fn proof::Sites sites(ref ir::Program p){return switch(runner::inspect(p)){case .ok(v):{v}case .err(_):{assert(false);proof::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};}
fn ir::Program fixture(){return compiled(b"module main;struct I{bool ok;i32 x;}struct R{u8 lead;I inner;i64 edge;}fn i32 f(u8[2] a,ref u8[] q,ref mut i32[] p,R r,ref u8[] s,R t){if(r.inner.ok && t.inner.ok){p[0]=a[0] as i32+t.inner.x;}return p[0];}fn i32 main(){let u8[2] a=[21;2];var i32[2] c=[0;2];let R r=R{.lead=7,.inner=I{.ok=true,.x=21},.edge=-9223372036854775808};let R t=R{.lead=7,.inner=I{.ok=true,.x=21},.edge=-9223372036854775808};let ref u8[] q=ref a;let ref mut i32[] p=ref mut c;return f(a,ref q,ref mut p,r,ref q,t);}");}
fn layouts_record::Plan record_plan(ref ir::Program p){return switch(layouts_record::plan(ref p.records.layouts,18446744073709551615)){case .ok(v):{v}case .err(_):{assert(false);layouts_record::Plan{.count=0,.bytes=[0;32],.alignments=[0;32],.depths=[0;32],.offsets=[0;512]}}};}
fn void initialize(ref ir::Program p,ref mut arrays::State a,ref mut records::State rs,ref mut loans::State l,ref mut bytes::Buffer b){
    var usize i=0;while(i<p.arrays.count){if(p.array_functions[i] as usize==p.entry){let owners::Token root=create(a,b,p.arrays.elements[i],p.arrays.lengths[i],21);a.tokens[i]=root;}i+=1;}
    i=0;let i64[4] values=[7,1,21,-9223372036854775808];while(i<p.records.count){if(p.record_functions[i] as usize==p.entry){let owners::Token root=switch(owners::create_record(ref p.records.layouts,p.records.records[i] as usize,ref values,bytes::view_mut(b),ref mut a.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}};rs.tokens[i]=root;}i+=1;}
    let usize args=p.code[pc(p)*8+3] as usize;i=0;while(i<6){let usize source=p.call_args[args*8+i] as usize;if(source>=160){let usize site=source-160;if(l.tickets[site].generation==0){let owners::Token root=a.tokens[(p.slice_roots[site] as usize)-1];
        let slices::Ticket t=if(ir::exclusive(p,site)){ticket(slices::open_exclusive(ref mut l.pool,ref mut a.owners,root,0,2,256))}else{ticket(slices::open(ref mut l.pool,ref mut a.owners,root,0,2,256))};l.tickets[site]=t;}}i+=1;}
}
fn arrays::State saved_arrays(ref arrays::State a){return arrays::State{.owners=owners::Table{.slots=a.owners.slots,.order=a.owners.order,.depth=a.owners.depth,.arena=a.owners.arena},.tokens=a.tokens};}
fn loans::State saved_loans(ref loans::State l){return loans::State{.pool=slices::Pool{.slots=l.pool.slots},.tickets=l.tickets};}
fn u8[256] saved_bytes(ref bytes::Buffer b){var u8[256] v=[0;256];let ref u8[] data=bytes::view(b);var usize i=0;while(i<256){v[i]=data[i];i+=1;}return v;}
fn void unchanged(ref arrays::State a,ref arrays::State old,ref loans::State l,ref loans::State previous,ref bytes::Buffer b,ref u8[] data,ref authority::State auth,ref calls::Bindings c,ref shared::Frames f){
    assert(auth.depth==0 && auth.frame==0 && a.owners.depth==old.owners.depth && a.owners.arena.used==old.owners.arena.used && a.owners.arena.limit==old.owners.arena.limit);
    var usize i=0;while(i<512){assert(a.tokens[i].slot==old.tokens[i].slot && a.tokens[i].generation==old.tokens[i].generation && l.tickets[i].slot==previous.tickets[i].slot && l.tickets[i].generation==previous.tickets[i].generation);i+=1;}
    i=0;while(i<16){let slices::Slot x=l.pool.slots[i];let slices::Slot y=previous.pool.slots[i];let owners::Owner u=a.owners.slots[i];let owners::Owner v=old.owners.slots[i];
        assert(x.live==y.live && x.exclusive==y.exclusive && x.generation==y.generation && x.lease.generation==y.lease.generation && x.view.root.slot==y.view.root.slot && x.view.root.generation==y.view.root.generation && x.view.start==y.view.start && x.view.end==y.view.end);
        assert(u.generation==v.generation && u.occupied==v.occupied && u.live==v.live && u.reading==v.reading && u.writing==v.writing && u.read_generation==v.read_generation && u.record==v.record && u.length==v.length && u.alignment==v.alignment && u.mark==v.mark && u.base==v.base && u.end==v.end && a.owners.order[i]==old.owners.order[i]);i+=1;}
    i=0;while(i<31){assert(c.pcs[i]==256);i+=1;}i=0;while(i<248){assert(c.detached[i].slot==16 && c.detached[i].generation==0);i+=1;}i=0;while(i<256){assert(f.origins[i].slot==16 && f.origins[i].generation==0 && bytes::view(b)[i]==data[i]);i+=1;}
}
fn void run(ref u8[] source,i64 expected){let ir::Program p=compiled(source);var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(256);var bytes::Buffer b=backing();
    assert(answer(runner::execute(ref p,10000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links))==expected);assert(context::ready(ref auth[0],ref c[0],ref links[0],ref l,ref f).is_ok && a.owners.depth==0 && a.owners.arena.used==0);
}

fn void same_records(ref records::State a,ref records::State b){var usize i=0;while(i<512){assert(a.tokens[i].slot==b.tokens[i].slot && a.tokens[i].generation==b.tokens[i].generation);i+=1;}}
fn i64 field(ref ir::Program p,ref arrays::State a,owners::Token t,ref usize[] path,ref bytes::Buffer b){return switch(owners::read_record(ref p.records.layouts,ref a.owners,t,path,bytes::view(b))){case .ok(v):{v}case .err(_):{assert(false);0}};}

@test
fn void six_record_tags_repeated_sources_and_recursive_frames_execute(){
    run(b"module main;struct W{i32 a;bool b;i64 c;u8 d;u32 e;usize f;}fn i32 f(W w){if(w.a!=-2147483648 || !w.b || w.c!=-9223372036854775808 || w.d!=255 || w.e!=4294967295 || w.f!=18446744073709551615){return 0;}return 42;}fn i32 main(){let W w=W{.a=-2147483648,.b=true,.c=-9223372036854775808,.d=255,.e=4294967295,.f=18446744073709551615};return f(w);}",42);
    run(b"module main;struct R{i32 x;}fn i32 f(R a,R b,R c,R d,R e,R f,R g,R h){return a.x+h.x;}fn i32 main(){let R r=R{.x=21};return f(r,r,r,r,r,r,r,r);}",42);
    run(b"module main;struct R{i32 x;}fn i32 f(R r,i32 n){if(n==0){return r.x;}return f(r,n-1);}fn i32 main(){let R r=R{.x=21};return f(r,5)+f(r,5);}",42);
}
@test
fn void mixed_record_array_loans_normalize_padding_and_keep_copies_independent(){
    let ir::Program p=fixture();let proof::Sites map=sites(ref p);let layouts_record::Plan layout=record_plan(ref p);var arrays::State a=arrays::empty(256);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var records::State s=records::empty();var bytes::Buffer b=backing();initialize(ref p,ref mut a,ref mut s,ref mut l,ref mut b);
    let usize at=pc(ref p);let usize args=p.code[at*8+3] as usize;let usize source=(p.call_args[args*8+3] as usize)-144;let owners::Token original=s.tokens[source];let usize root=p.records.records[source] as usize;let usize nested=layout.offsets[root*16+1];let usize base=a.owners.slots[original.slot].base;bytes::view_mut(ref mut b)[base+1]=201;bytes::view_mut(ref mut b)[base+nested+1]=202;
    let usize used=a.owners.arena.used;let usize depth=a.owners.depth;let usize price=built(calls::cost(ref p,at,77));assert(price==built(legacy::cost(ref p,0,77)) && price==7+265+2048+2*43008+5*65537);
    assert(built(calls::enter_owned(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref mut s,ref mut b,price))==0);let usize id=(p.record_parameters[3] as usize)-1;let owners::Token child=s.tokens[16+id];let usize child_base=a.owners.slots[child.slot].base;
    assert(a.owners.depth==depth+3 && child.slot!=original.slot && bytes::view(ref b)[child_base+1]==0 && bytes::view(ref b)[child_base+nested+1]==0 && bytes::view(ref b)[base+1]==201 && bytes::view(ref b)[base+nested+1]==202);
    let usize[2] path=[1,1];let usize written=done(owners::write_record(ref p.records.layouts,ref a.owners,child,ref path,99,bytes::view_mut(ref mut b)));assert(field(ref p,ref a,original,ref path,ref b)==21 && field(ref p,ref a,child,ref path,ref b)==99);
    assert(!calls::leave(ref p,0,1,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref s,ref b,77).is_ok && auth.depth==1);
    var usize arg=6;while(arg>0){arg-=1;let usize r=p.record_parameters[arg] as usize;let usize arr=p.array_parameters[arg] as usize;if(r!=0){let usize pos=16+r-1;let owners::Token t=s.tokens[pos];let usize released=done(owners::release(ref mut a.owners,t,256));s.tokens[pos]=owners::Token{.slot=0,.generation=0};}else if(arr!=0){let usize pos=16+arr-1;let owners::Token t=a.tokens[pos];let usize released=done(owners::release(ref mut a.owners,t,256));a.tokens[pos]=owners::Token{.slot=0,.generation=0};}}
    assert(built(calls::leave(ref p,0,1,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref s,ref b,77))==1 && a.owners.depth==depth && a.owners.arena.used==used);assert(answer(calls::finish(ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref b,.ok(42)))==42);
}
@test
fn void late_record_failures_and_loan_failures_preserve_all_originals(){
    let ir::Program p=fixture();let proof::Sites map=sites(ref p);let layouts_record::Plan layout=record_plan(ref p);let usize at=pc(ref p);let usize args=p.code[at*8+3] as usize;let usize price=built(calls::cost(ref p,at,77));var usize mode=0;
    while(mode<9){var arrays::State a=arrays::empty(256);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var records::State s=records::empty();var bytes::Buffer b=backing();initialize(ref p,ref mut a,ref mut s,ref mut l,ref mut b);
        let usize source=(p.call_args[args*8+5] as usize)-144;let owners::Token token=s.tokens[source];let usize root=p.records.records[source] as usize;let usize q=(p.call_args[args*8+1] as usize)-160;let usize w=(p.call_args[args*8+2] as usize)-160;
        if(mode==1){let usize limit=a.owners.arena.used+2;a.owners.arena.limit=limit;}
        else if(mode==2){let usize pos=a.owners.slots[token.slot].base+layout.offsets[root*16+1];bytes::view_mut(ref mut b)[pos]=2;}
        else if(mode==3){s.tokens[source].generation+=1;}
        else if(mode==4){while(a.owners.depth<16){let owners::Token extra=create(ref mut a,ref mut b,1,1,0);}}
        else if(mode==5){let slices::Ticket source=l.tickets[q];var usize i=0;while(i<13){let slices::Ticket extra=ticket(slices::subslice(ref mut l.pool,source,ref a.owners,0,2,256));i+=1;}}
        else if(mode==6){let usize slot=l.tickets[w].slot;l.pool.slots[slot].generation=18446744073709551615;l.tickets[w].generation=18446744073709551615;}
        else if(mode==7){s.tokens[16]=owners::Token{.slot=0,.generation=1};}
        else if(mode==8){let usize wrong=p.records.layouts.types[root*16+1] as usize;a.owners.slots[token.slot].record=wrong;}
        let arrays::State old=saved_arrays(ref a);let loans::State previous=saved_loans(ref l);let records::State old_records=records::State{.tokens=s.tokens};let u8[256] data=saved_bytes(ref b);
        assert(switch(calls::enter_owned(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref mut s,ref mut b,if(mode==0){price-1}else{price})){case .ok(_):{false}case .err(e):{e.kind==if(mode==0){8}else{if(mode==1 || mode==4 || mode==5){13}else{5}}}});
        unchanged(ref a,ref old,ref l,ref previous,ref b,ref data,ref auth,ref c,ref f);same_records(ref s,ref old_records);mode+=1;
    }
}
@test
fn void control_and_exact_nominal_gates_fail_before_publication(){
    let ir::Program p=fixture();let proof::Sites map=sites(ref p);let usize at=pc(ref p);let usize price=built(calls::cost(ref p,at,77));var arrays::State a=arrays::empty(256);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var calls::Bindings c=calls::empty();var authority::State auth=authority::empty();var records::State s=records::empty();var bytes::Buffer b=backing();initialize(ref p,ref mut a,ref mut s,ref mut l,ref mut b);let arrays::State old=saved_arrays(ref a);let loans::State previous=saved_loans(ref l);let records::State old_records=records::State{.tokens=s.tokens};let u8[256] data=saved_bytes(ref b);var i64[256] r=[99;256];var usize[32] pcs=[77;32];var usize[32] dsts=[88;32];
    assert(!control::step_canonical(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut s,ref mut a,ref mut b,ref mut r[..128],ref mut pcs,ref mut dsts,price).is_ok);assert(!calls::enter(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref a,ref s,ref b,price).is_ok);unchanged(ref a,ref old,ref l,ref previous,ref b,ref data,ref auth,ref c,ref f);same_records(ref s,ref old_records);
    var usize i=0;while(i<256){assert(r[i]==99);i+=1;}i=0;while(i<32){assert(pcs[i]==77 && dsts[i]==88);i+=1;}
    var ir::Program bad=p;let usize id=(p.record_parameters[3] as usize)-1;bad.records.mutable[id]=true;assert(!runner::inspect(ref bad).is_ok && !calls::cost(ref bad,at,77).is_ok);bad=p;bad.records.records[id]=0;assert(!calls::cost(ref bad,at,77).is_ok);bad=p;bad.call_args[(p.code[at*8+3] as usize)*8+3]=128;assert(!calls::cost(ref bad,at,77).is_ok);
    // Canonical record-result delivery promotes this previously rejected signature.
    let ir::Program result=compiled(b"module main;struct R{i32 x;}fn R f(R r){return r;}fn i32 main(){let R r=f(R{.x=42});return r.x;}");assert(runner::inspect(ref result).is_ok);
}
@test
fn void constructors_child_paths_mutable_snapshots_and_tagged_scalar_results_execute(){
    run(b"module main;struct I{i32 x;}struct R{I inner;}fn i32 f(I i){return i.x;}fn i32 main(){let R r=R{.inner=I{.x=21}};return f(r.inner)+f(I{.x=21});}",42);
    run(b"module main;struct R{i32 x;}fn i32 f(R r){return r.x;}fn i32 main(){var R r=R{.x=21};return f(r)+f(r);}",42);
    run(b"module main;struct R{i32 x;}fn Option<i32> f(R r,bool yes){if(yes){return .some(r.x);}return .none;}fn i32 main(){return switch(f(R{.x=42},true)){case .some(v):{v}case .none:{0}};}",42);
}
@test
fn void mixed_abort_retains_copied_records_writes_and_original_error(){
    let ir::Program p=compiled(b"module main;struct R{i32 x;}fn i32 f(u8[1] a,ref u8[] q,ref mut i32[] p,R r,i32 z){p[0]=a[0] as i32+r.x;return 1/z;}fn i32 main(){let u8[1] a=[21;1];var i32[1] c=[0;1];let R r=R{.x=21};let ref u8[] q=ref a;let ref mut i32[] p=ref mut c;return f(a,ref q,ref mut p,r,0);}");let proof::Sites map=sites(ref p);var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(256);var bytes::Buffer b=backing();
    let errors::Error failure=switch(execution::execute_canonical(ref p,ref map,1000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(_):{assert(false);errors::make(0,0)}case .err(e):{e}};assert(failure.kind==7 && auth[0].depth==1 && a.owners.depth==5);
    let usize source=(p.call_args[(p.code[pc(ref p)*8+3] as usize)*8] as usize)-128;let usize slot=a.tokens[source].slot;let usize epoch=a.owners.slots[slot].read_generation;a.owners.slots[slot].read_generation+=1;assert(!context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.err(failure)).is_ok);assert(auth[0].depth==1 && c[0].pcs[0]!=256);a.owners.slots[slot].read_generation=epoch;
    assert(switch(context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.err(failure))){case .ok(_):{false}case .err(e):{e.kind==7 && e.offset==failure.offset}});assert(a.owners.depth==5 && context::ready(ref auth[0],ref c[0],ref links[0],ref l,ref f).is_ok);
    let usize writer=(p.call_args[(p.code[pc(ref p)*8+3] as usize)*8+2] as usize)-160;let usize root=(p.slice_roots[writer] as usize)-1;assert(switch(owners::read(ref a.owners,a.tokens[root],0,bytes::view(ref b))){case .ok(v):{v==42}case .err(_):{false}});
    // Raw core record maps are local; shared owner descriptors retain both record copies.
    var usize records_live=0;var usize i=0;let usize[1] path=[0];while(i<16){let owners::Owner o=a.owners.slots[i];if(o.live && o.element==0){let owners::Token t=owners::Token{.slot=i,.generation=o.generation};assert(field(ref p,ref a,t,ref path,ref b)==21);records_live+=1;}i+=1;}assert(records_live==2);
}
