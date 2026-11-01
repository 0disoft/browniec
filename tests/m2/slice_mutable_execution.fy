module tests::m2::slice_mutable_execution;
import ir as ir;
import errors as errors;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import vm_execution as execution;
import call_frame_vm as control;
import slice_builders as builders;
import slice_mutable_call_vm as calls;
import slice_mutable_frame_vm as dispatch;
import slice_call_vm as shared;
import slice_vm as loans;
import array_vm as arrays;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import struct_vm as records;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize count(Result<usize,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 cell(Result<i64,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};}
fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn bytes::Buffer backing(){return switch(arrays::prepare(256)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};}
fn ir::Program compiled(ref u8[] s){return switch(compiler::compile(s)){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};}
fn usize pc(ref ir::Program p,u8 op,usize f){var usize i=p.starts[f];while(i<p.ends[f] && p.code[i*8]!=op){i+=1;}assert(i<p.ends[f]);return i;}
fn void finish(ref mut ir::Program p,usize f){let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;}
fn usize constant(ref mut ir::Program p,u8 tag,i64 value){return built(if(tag==2){ir::boolean(p,value==1,77)}else{ir::integer(p,value,tag,77)});}
fn void mark(ref mut ir::Program p){var usize i=0;while(i<16){if(p.slice_roots[i]!=0 || p.slice_origins[i]!=0){let u8 tag=p.slice_elements[i];p.slice_elements[i]=tag|128;}i+=1;}}
fn void mark_call(ref mut ir::Program p){let usize call=pc(p,9,p.entry);let usize target=p.code[call*8+2] as usize;let usize base=(p.code[call*8+3] as usize)*8;let usize source=(p.call_args[base] as usize)-160;let usize formal=(p.slice_parameters[p.register_starts[target]] as usize)-1;let u8 tag=p.slice_elements[formal];p.slice_elements[formal]=tag|128;p.slice_elements[source]=128;}
fn void inspected(ref ir::Program p){assert(verifier::inspect(p).is_ok && verifier::verify(p).is_ok);assert(switch(vm::run_with_array_limit(p,0,0)){case .ok(_):{false}case .err(e):{e.kind==8}});}
fn void cleared(ref calls::Frame[] receipts,ref shared::Frames f,ref loans::State l,ref arrays::State a){var usize i=0;while(i<receipts.len){assert(!receipts[i].active && receipts[i].batch.count==0);i+=1;}i=0;while(i<256){assert(f.origins[i].slot==16 && f.origins[i].generation==0);i+=1;}i=0;while(i<512){assert(l.tickets[i].slot==16 && l.tickets[i].generation==0);i+=1;}i=0;while(i<16){assert(!l.pool.slots[i].live && !a.owners.slots[i].reading && !a.owners.slots[i].writing);i+=1;}}
fn void run(ref ir::Program p,usize fuel,u8 expected){
    inspected(p);var calls::Frame[32] receipts=[calls::empty();32];var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(256);var bytes::Buffer b=backing();var errors::Error failure=errors::make(0,0);var bool failed=false;
    let i64 answer=switch(execution::execute_mutable(p,fuel,ref mut a,ref mut b,ref mut l,ref mut f,ref mut receipts)){case .ok(v):{assert(expected==0 && v==42);v}case .err(e):{assert(e.kind==expected);failed=true;failure=e;0}};
    if(!failed){cleared(ref receipts,ref f,ref l,ref a);}
    let Result<i64,errors::Error> outcome=if(failed){.err(failure)}else{.ok(answer)};
    assert(switch(calls::finish(ref mut receipts,ref mut f,ref mut l,ref mut a,ref b,outcome)){case .ok(v):{expected==0 && v==42}case .err(e):{e.kind==expected && e.offset==failure.offset}});cleared(ref receipts,ref f,ref l,ref a);
}
fn ir::Program program(u8 tag,i64 value,u8 mode){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.arities[0]=1;p.return_types[0]=1;p.return_types[1]=1;
    let usize formal=built(builders::parameter_exclusive(ref mut p,0,tag,77));let usize index=constant(ref mut p,12,if(mode==1){2}else{0});let usize wanted=constant(ref mut p,tag,value);let usize store=built(ir::slice_write(ref mut p,formal,index,wanted,77));
    if(mode==2){let usize one=constant(ref mut p,1,1);let usize zero=constant(ref mut p,1,0);let usize fault=built(ir::emit(ref mut p,5,one,zero,77));}
    let usize read=built(ir::slice_read(ref mut p,formal,index,77));let usize equal=built(ir::emit(ref mut p,11,read,wanted,77));let usize length=built(ir::slice_length(ref mut p,formal,77));if(tag==10){let usize valid=built(ir::slice_utf8(ref mut p,formal,77));}let usize close=built(ir::slice_close(ref mut p,formal,77));let usize branch=built(ir::raw(ref mut p,20,0,equal,0,77));let usize yes=constant(ref mut p,1,42);let usize ret=built(ir::emit(ref mut p,8,yes,0,77));let usize no_pc=p.count;let usize no=constant(ref mut p,1,0);let usize bad=built(ir::emit(ref mut p,8,no,0,77));let usize patch=built(ir::patch(ref mut p,branch,no_pc,77));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;let usize root=built(ir::array_in(ref mut p,1,tag,4,true,77));let usize site=built(ir::exclusive_slice(ref mut p,root,77));let usize fill=constant(ref mut p,tag,0);let usize init=built(ir::array_init(ref mut p,root,fill,77));let usize lo=constant(ref mut p,12,if(mode==3){3}else{1});let usize hi=constant(ref mut p,12,3);let usize opened=built(ir::slice_open(ref mut p,site,lo,hi,77));let usize[1] args=[160+site];let usize result=built(ir::call(ref mut p,0,ref args,77));let usize zero=constant(ref mut p,12,0);let usize after=built(ir::slice_read(ref mut p,site,zero,77));let usize expected=constant(ref mut p,tag,value);let usize same=built(ir::emit(ref mut p,11,after,expected,77));let usize closed=built(ir::slice_close(ref mut p,site,77));let usize drop=built(ir::array_drop(ref mut p,root,77));let usize choose=built(ir::raw(ref mut p,20,0,same,0,77));let usize done=built(ir::emit(ref mut p,8,result,0,77));let usize error_pc=p.count;let usize error=constant(ref mut p,1,0);let usize failed=built(ir::emit(ref mut p,8,error,0,77));let usize patched=built(ir::patch(ref mut p,choose,error_pc,77));finish(ref mut p,1);inspected(ref p);return p;
}
fn void initialize(ref ir::Program p,ref mut loans::State l,ref mut arrays::State a,ref mut bytes::Buffer b){var usize i=0;while(i<p.arrays.count){if(p.array_functions[i] as usize==p.entry){let layouts::Array shape=switch(layouts::scalar(p.arrays.elements[i],p.arrays.lengths[i])){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};let owners::Token created=token(owners::create(ref shape,if(p.arrays.elements[i]==2){1}else{0},bytes::view_mut(b),ref mut a.owners));a.tokens[i]=created;}i+=1;}let usize call=pc(p,9,p.entry);let usize source=(p.call_args[(p.code[call*8+3] as usize)*8] as usize)-160;let usize root=(p.slice_roots[source] as usize)-1;let owners::Token owner=a.tokens[root];let usize n=p.arrays.lengths[root];let slices::Ticket opened=ticket(slices::open_exclusive(ref mut l.pool,ref mut a.owners,owner,if(n==4){1}else{0},if(n==4){3}else{n},256));l.tickets[source]=opened;}

@test
fn void six_scalar_mutable_calls_write_read_restore_and_return_through_the_shared_loop(){let u8[6] tags=[1,2,9,10,11,12];let i64[6] values=[-2147483648,1,-9223372036854775807-1,255,4294967295,-1];var usize i=0;while(i<6){let ir::Program p=program(tags[i],values[i],0);run(ref p,2000000,0);i+=1;}}

@test
fn void formal_instruction_prices_one_short_payload_guards_utf8_and_release_are_checked(){
    let u8[6] tags=[1,2,9,10,11,12];var usize t=0;while(t<6){let i64 value=if(tags[t]==2){1}else{42};let ir::Program p=program(tags[t],value,0);var calls::Frame receipt=calls::empty();var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(256);var records::State s=records::empty();var bytes::Buffer b=backing();initialize(ref p,ref mut l,ref mut a,ref mut b);let usize entered=built(calls::enter(ref p,pc(ref p,9,1),0,ref mut receipt,ref mut f,ref mut l,ref mut s,ref mut a,ref mut b,2000000));var i64[128] r=[99;128];let usize store=pc(ref p,60,0);let usize index=p.code[store*8+2] as usize;let usize input=p.code[store*8+3] as usize;r[index]=0;r[input]=value;let layouts::Array shape=switch(layouts::scalar(tags[t],1)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};let u8[5] ops=[60,58,57,55,56];var usize i=0;
        while(i<5){let u8 op=ops[i];if(op==55 && tags[t]!=10){i+=1;continue;}let usize at=pc(ref p,op,0);let usize cost=if(op==60){4130+2*shape.stride}else if(op==58){4130+shape.stride}else if(op==55){4113}else{4097};let i64[128] old=r;let usize generation=l.pool.slots[l.tickets[16].slot].generation;var u8[256] olddata=[0;256];{let ref u8[] data=bytes::view(ref b);var usize j=0;while(j<256){olddata[j]=data[j];j+=1;}}
            assert(switch(dispatch::step(ref p,0,at,1,ref mut receipt,ref f,ref mut l,ref a,ref mut b,ref mut r,cost-1)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==77}});var usize j=0;while(j<128){assert(r[j]==old[j]);j+=1;}let ref u8[] data=bytes::view(ref b);j=0;while(j<256){assert(data[j]==olddata[j]);j+=1;}assert(l.pool.slots[l.tickets[16].slot].generation==generation);
            assert(built(dispatch::step(ref p,0,at,1,ref mut receipt,ref f,ref mut l,ref a,ref mut b,ref mut r,cost))==0);if(op==58){assert(r[p.code[at*8+1] as usize]==value);}if(op==57){assert(r[p.code[at*8+1] as usize]==2);}if(op==55){assert(r[p.code[at*8+1] as usize]==1);}i+=1;
        }
        assert(l.tickets[16].generation==0 && receipt.detached[0].generation!=0 && !dispatch::step(ref p,0,pc(ref p,58,0),1,ref mut receipt,ref f,ref mut l,ref a,ref mut b,ref mut r,5000).is_ok);assert(built(calls::leave(ref p,0,1,ref mut receipt,ref mut f,ref mut l,ref mut a,ref b,77))==1);let usize drained=count(slices::clear(ref mut l.pool,ref mut a.owners,256));t+=1;
    }
}

@test
fn void recursive_mutual_and_reused_mutable_frames_reach_depth32_without_native_recursion(){
    var ir::Program p=compiled(b"module main;fn i32 f(ref u8[] p,i32 n){if(n==0){return p[0] as i32;}return f(ref p,n-1);}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p,30);}");mark(ref mut p);run(ref p,16000000,0);
    var ir::Program deep=compiled(b"module main;fn i32 f(ref u8[] p,i32 n){if(n==0){return p[0] as i32;}return f(ref p,n-1);}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p,31);}");mark(ref mut deep);run(ref deep,16000000,12);
    var ir::Program mutual=compiled(b"module main;fn i32 f(ref u8[] p,i32 n){if(n==0){return p[0] as i32;}return g(ref p,n-1);}fn i32 g(ref u8[] p,i32 n){if(n==0){return p[0] as i32;}return f(ref p,n-1);}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p,3)+f(ref p,3)-42;}");mark(ref mut mutual);run(ref mutual,16000000,0);
}

@test
fn void mixed_readonly_helpers_owned_arguments_and_scalar_array_record_tagged_returns_execute(){
    var ir::Program mixed=compiled(b"module main;struct P{i32 x;}fn i32 read(ref u8[] p){return p[0] as i32;}fn i32 f(ref u8[] w,i32 n,u8[1] a,P r,ref u8[] s){return read(ref s)+(w[0] as i32)+n+(a[0] as i32)+r.x;}fn i32 main(){var u8[1] a=[1;1];let u8[1] b=[1;1];let P r=P{.x=39};let ref u8[] w=ref a;let ref u8[] s=ref b;return f(ref w,0,b,r,ref s);}");mark_call(ref mut mixed);run(ref mixed,3000000,0);
    var ir::Program array=compiled(b"module main;fn u8[1] f(ref u8[] p,u8[1] a){return a;}fn i32 main(){var u8[1] a=[42;1];let u8[1] b=[42;1];let ref u8[] p=ref a;let u8[1] r=f(ref p,b);return r[0] as i32;}");mark_call(ref mut array);run(ref array,3000000,0);
    var ir::Program record=compiled(b"module main;struct P{i32 x;}fn P f(ref u8[] p,P a){return a;}fn i32 main(){var u8[1] a=[42;1];let P v=P{.x=42};let ref u8[] p=ref a;let P r=f(ref p,v);return r.x;}");mark_call(ref mut record);run(ref record,3000000,0);
    var ir::Program tagged=compiled(b"module main;fn Option<i32> f(ref u8[] p,Option<i32> n){let i32 x=n?;return .some(x+(p[0] as i32));}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;switch(f(ref p,.none)){case .some(_):{return 0;}case .none:{}}return switch(f(ref p,.some(0))){case .some(v):{v}case .none:{0}};}");mark(ref mut tagged);run(ref tagged,3000000,0);
}

@test
fn void fuel_bounds_arithmetic_and_failed_abort_cleanup_preserve_writes_and_receipts(){
    let ir::Program bounds=program(10,42,1);run(ref bounds,2000000,14);let ir::Program empty=program(10,42,3);run(ref empty,2000000,14);let ir::Program good=program(10,42,0);run(ref good,0,8);run(ref good,270000,8);
    let ir::Program p=program(10,42,2);var calls::Frame[32] receipts=[calls::empty();32];var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(256);var bytes::Buffer b=backing();assert(switch(execution::execute_mutable(ref p,2000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut receipts)){case .ok(_):{false}case .err(e):{e.kind==7 && e.offset==77}});assert(receipts[1].active && cell(slices::read(ref l.pool,l.tickets[16],ref a.owners,0,bytes::view(ref b)))==42);let usize slot=l.tickets[16].slot;let slices::Slot saved=l.pool.slots[slot];var slices::Slot bad=saved;bad.view.end=bad.view.length+1;l.pool.slots[slot]=bad;
    assert(switch(calls::finish(ref mut receipts,ref mut f,ref mut l,ref mut a,ref b,.err(errors::make(7,77)))){case .ok(_):{false}case .err(e):{e.kind==14}});assert(receipts[1].active && f.origins[8].generation!=0 && l.pool.slots[slot].live);l.pool.slots[slot]=saved;assert(switch(calls::finish(ref mut receipts,ref mut f,ref mut l,ref mut a,ref b,.err(errors::make(7,77)))){case .ok(_):{false}case .err(e):{e.kind==7 && e.offset==77}});assert(cell(owners::read(ref a.owners,a.tokens[0],1,bytes::view(ref b)))==42);cleared(ref receipts,ref f,ref l,ref a);
}

@test
fn void scalar_control_preflight_and_late_owned_failure_publish_nothing_before_success(){
    var ir::Program p=compiled(b"module main;fn i32 f(ref u8[] p,bool[1] a,i32 n){return n;}fn i32 main(){var u8[1] a=[0;1];let bool[1] b=[true;1];let ref u8[] p=ref a;return f(ref p,b,42);}");mark_call(ref mut p);let usize at=pc(ref p,9,1);p.offsets[at]=77;inspected(ref p);let usize base=(p.code[at*8+3] as usize)*8;let usize source=(p.call_args[base] as usize)-160;let usize scalar=p.call_args[base+2] as usize;let usize charge=built(calls::cost(ref p,0,77));var calls::Frame[1] all=[calls::empty();1];var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(256);var records::State s=records::empty();var bytes::Buffer b=backing();initialize(ref p,ref mut l,ref mut a,ref mut b);var i64[256] r=[99;256];r[scalar]=42;var usize[32] pcs=[77;32];var usize[32] dsts=[88;32];let slices::Ticket original=l.tickets[source];let usize used=a.owners.arena.used;let usize depth=a.owners.depth;let usize bool_root=(p.call_args[base+1] as usize)-128;let usize bool_at=a.owners.slots[a.tokens[bool_root].slot].base;
    var usize mode=0;while(mode<4){if(mode==3){let ref mut u8[] data=bytes::view_mut(ref mut b);data[bool_at]=2;}let usize span=if(mode==1){128}else{256};let usize controls=if(mode==2){1}else{32};let usize fuel=if(mode==0){charge-1}else{charge};assert(switch(control::step_mutable(ref p,at,0,ref mut all[0],ref mut f,ref mut l,ref mut s,ref mut a,ref mut b,ref mut r[..span],ref mut pcs[..controls],ref mut dsts,fuel)){case .ok(_):{false}case .err(e):{e.kind==if(mode==0){8}else{5} && e.offset==77}});
        assert(!all[0].active && l.tickets[source].generation==original.generation && l.pool.slots[original.slot].generation==original.generation && a.owners.depth==depth && a.owners.arena.used==used);var usize i=0;while(i<256){assert(r[i]==if(i==scalar){42}else{99} && f.origins[i].generation==0);i+=1;}i=0;while(i<32){assert(pcs[i]==77 && dsts[i]==88);i+=1;}mode+=1;
    }
    {let ref mut u8[] data=bytes::view_mut(ref mut b);data[bool_at]=1;}assert(built(control::step_mutable(ref p,at,0,ref mut all[0],ref mut f,ref mut l,ref mut s,ref mut a,ref mut b,ref mut r,ref mut pcs,ref mut dsts,charge))==0);assert(all[0].active && r[128]==99 && r[129]==99 && r[130]==42 && pcs[1]==at+1 && dsts[1]==p.code[at*8+1] as usize);
    assert(switch(calls::finish(ref mut all,ref mut f,ref mut l,ref mut a,ref b,.ok(42))){case .ok(v):{v==42}case .err(_):{false}});
}
