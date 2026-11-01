module tests::m2::slice_mutable_calls;
import ir as ir;
import errors as errors;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import slice_builders as builders;
import array_parameters as arguments;
import register_set as registers;
import slice_call_vm as calls;
import mixed_call_vm as mixed;
import call_frame_vm as frames;
import slice_vm as loans;
import array_vm as arrays;
import struct_vm as records;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn ir::Program compiled(ref u8[] s){return switch(compiler::compile(s)){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};}
fn void error(Result<usize,errors::Error> r,usize pc){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});}
fn usize opcode(ref ir::Program p,u8 op,usize f){var usize pc=p.starts[f];while(pc<p.ends[f]){if(p.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;}
fn void finish(ref mut ir::Program p,usize f){let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;}
fn void mark(ref mut ir::Program p){var usize i=0;while(i<16){if(p.slice_roots[i]!=0 || p.slice_origins[i]!=0){let u8 value=p.slice_elements[i];p.slice_elements[i]=value|128;}i+=1;}}
fn void accepted(ref ir::Program p){assert(built(verifier::inspect(p))==p.count);assert(built(verifier::verify(p))==p.count);assert(switch(vm::run_with_array_limit(p,0,0)){case .ok(_):{false}case .err(e):{e.kind==8}});}
fn void rejected(ref ir::Program p,usize pc){error(verifier::inspect(p),pc);error(verifier::verify(p),pc);assert(switch(vm::run_with_array_limit(p,0,0)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});}
fn void aggregate(ref u8[] source){var ir::Program p=compiled(source);mark(ref mut p);accepted(ref p);let usize pc=opcode(ref p,9,p.entry);let usize base=(p.code[pc*8+3] as usize)*8;let u8 first=p.call_args[base];p.call_args[base+1]=first;rejected(ref p,pc);}
fn usize constant(ref mut ir::Program p,u8 tag,i64 value){return built(if(tag==2){ir::boolean(p,value==1,77)}else{ir::integer(p,value,tag,77)});}
fn ir::Program owned(u8 tag,i64 cell){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.arities[0]=1;p.return_types[0]=1;p.return_types[1]=1;
    let usize formal=built(builders::parameter_exclusive(ref mut p,0,tag,77));let usize index=constant(ref mut p,12,0);let usize value=constant(ref mut p,tag,cell);
    let usize write=built(ir::slice_write(ref mut p,formal,index,value,77));let usize read=built(ir::slice_read(ref mut p,formal,index,77));let usize close=built(ir::slice_close(ref mut p,formal,77));let usize answer=constant(ref mut p,1,42);let usize ret=built(ir::emit(ref mut p,8,answer,0,77));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize root=built(ir::array_in(ref mut p,1,tag,2,true,77));let usize site=built(ir::exclusive_slice(ref mut p,root,77));let usize fill=constant(ref mut p,tag,cell);let usize init=built(ir::array_init(ref mut p,root,fill,77));
    let usize lo=constant(ref mut p,12,0);let usize hi=constant(ref mut p,12,2);let usize open=built(ir::slice_open(ref mut p,site,lo,hi,77));let usize one=1;
    let usize[1] args=[built(builders::argument(ref p,0,site,1,1|(one<<(32+site)),77))];let usize result=built(ir::call(ref mut p,0,ref args,77));
    let usize after=built(ir::slice_read(ref mut p,site,lo,77));let usize len=built(ir::slice_length(ref mut p,site,77));let usize closed=built(ir::slice_close(ref mut p,site,77));let usize drop=built(ir::array_drop(ref mut p,root,77));let usize done=built(ir::emit(ref mut p,8,result,0,77));finish(ref mut p,1);return p;
}

@test
fn void all_six_exact_owned_mutable_arguments_inspect_and_caller_lifetimes_resume_after_call(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] cells=[-2147483648,1,-9223372036854775807-1,255,4294967295,-1];var usize i=0;
    while(i<6){let ir::Program p=owned(tags[i],cells[i]);accepted(ref p);assert(p.call_args[0]==161 && p.slice_elements[0]==(tags[i]|128) && p.slice_elements[1]==128);i+=1;}
}

@test
fn void formal_forwarding_recursion_and_mutual_calls_inspect_without_public_execution(){
    var ir::Program recursive=compiled(b"module main;fn i32 f(ref u8[] p,i32 n){if(n==0){return p[0] as i32;}return f(ref p,n-1);}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p,2);}");mark(ref mut recursive);accepted(ref recursive);
    var ir::Program mutual=compiled(b"module main;fn i32 f(ref u8[] p,i32 n){if(n==0){return p[0] as i32;}return g(ref p,n-1);}fn i32 g(ref u8[] p,i32 n){if(n==0){return p[0] as i32;}return f(ref p,n-1);}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p,2);}");mark(ref mut mutual);accepted(ref mutual);
    var ir::Program forwarded=compiled(b"module main;fn i32 f(ref u8[] p){return g(ref p);}fn i32 g(ref u8[] q){return 42;}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p);}");mark(ref mut forwarded);accepted(ref forwarded);let usize call=opcode(ref forwarded,9,0);let usize destination=(forwarded.slice_parameters[forwarded.register_starts[1]] as usize)-1;var ir::Program wrong=forwarded;wrong.slice_elements[destination]=139;rejected(ref wrong,call);wrong=forwarded;wrong.slice_elements[destination]=10;rejected(ref wrong,call);
    let usize pc=opcode(ref recursive,9,0);
    // A forwarded formal must have its own live bit, even during recursion.
    let usize source=recursive.call_args[(recursive.code[pc*8+3] as usize)*8] as usize;error(builders::argument(ref recursive,0,source-160,0,0,77),77);
}

@test
fn void eight_distinct_writers_fit_and_duplicates_reject_while_shared_duplicates_stay_legal(){
    let ir::Program shared=compiled(b"module main;fn i32 consume(ref u8[] a,ref u8[] b,ref u8[] c,ref u8[] d,ref u8[] e,ref u8[] f,ref u8[] g,ref u8[] h){return 42;}fn i32 main(){var u8[1] a=[1;1];var u8[1] b=[1;1];var u8[1] c=[1;1];var u8[1] d=[1;1];var u8[1] e=[1;1];var u8[1] f=[1;1];var u8[1] g=[1;1];var u8[1] h=[1;1];let ref u8[] p=ref a;let ref u8[] q=ref b;let ref u8[] r=ref c;let ref u8[] s=ref d;let ref u8[] t=ref e;let ref u8[] u=ref f;let ref u8[] v=ref g;let ref u8[] w=ref h;return consume(ref p,ref q,ref r,ref s,ref t,ref u,ref v,ref w);}");
    let usize pc=opcode(ref shared,9,1);let usize base=(shared.code[pc*8+3] as usize)*8;var ir::Program p=shared;mark(ref mut p);accepted(ref p);
    var usize i=1;while(i<8){var ir::Program bad=p;bad.call_args[base+i]=p.call_args[base];rejected(ref bad,pc);i+=1;}
    var ir::Program duplicate=shared;let u8 first=shared.call_args[base];duplicate.call_args[base+1]=first;assert(verifier::verify(ref duplicate).is_ok);
    // Distinct sites for one owned root must also fail, even with forged live
    // bits supplied directly to the batch checker rather than whole-IR flow.
    var ir::Program same_root=p;let usize a=(p.call_args[base] as usize)-160;let usize b=(p.call_args[base+1] as usize)-160;let u8 root=p.slice_roots[a];same_root.slice_roots[b]=root;var registers::Set defs=registers::empty();let usize one=1;var usize live=255;i=8;while(i<16){live|=one<<(32+i);i+=1;}
    error(arguments::arguments(ref same_root,0,p.code[pc*8+3] as usize,1,ref defs,live,pc),pc);
    var ir::Program forwarded=compiled(b"module main;fn i32 f(ref u8[] p,ref u8[] q){return f(ref p,ref q);}fn i32 main(){return 42;}");mark(ref mut forwarded);accepted(ref forwarded);let usize call=opcode(ref forwarded,9,0);let usize index=(forwarded.code[call*8+3] as usize)*8;let u8 token=forwarded.call_args[index];forwarded.call_args[index+1]=token;rejected(ref forwarded,call);
}

@test
fn void mode_tag_dead_source_foreign_function_and_reserved_argument_checks_remain_exact(){
    var ir::Program p=compiled(b"module main;fn i32 f(ref u8[] p){return 42;}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p);}");mark(ref mut p);accepted(ref p);let usize pc=opcode(ref p,9,1);let usize base=(p.code[pc*8+3] as usize)*8;let usize site=(p.call_args[base] as usize)-160;
    var ir::Program bad=p;bad.slice_elements[site]=0;rejected(ref bad,pc);bad=p;bad.slice_elements[0]=10;rejected(ref bad,pc);bad=p;bad.slice_elements[0]=139;rejected(ref bad,pc);
    bad=p;bad.call_args[base]=176;rejected(ref bad,pc);bad=p;bad.call_args[base+1]=1;rejected(ref bad,pc);
    bad=p;let usize open=opcode(ref p,54,1);bad.code[open*8]=19;bad.code[open*8+1]=0;bad.code[open*8+3]=0;let usize patched=built(ir::patch(ref mut bad,open,open+1,77));rejected(ref bad,pc);
    let usize one=1;error(builders::argument(ref p,0,site,0,1|(one<<(32+site)),77),77);error(builders::argument(ref p,0,site,1,one<<(32+site),77),77);error(builders::argument(ref p,0,site,1,1,77),77);
}

@test
fn void mixed_scalar_owned_array_record_shared_and_exclusive_positions_are_checked_together(){
    var ir::Program p=compiled(b"module main;struct P{i32 x;}fn i32 f(ref u8[] w,i32 n,u8[1] a,P r,ref u8[] s){return w[0] as i32+n+a[0] as i32+r.x+s[0] as i32;}fn i32 main(){var u8[1] a=[1;1];let u8[1] b=[1;1];let ref u8[] w=ref a;let ref u8[] s=ref b;let P r=P{.x=40};return f(ref w,0,b,r,ref s);}");
    let usize pc=opcode(ref p,9,1);let usize base=(p.code[pc*8+3] as usize)*8;let usize source=(p.call_args[base] as usize)-160;let usize formal=(p.slice_parameters[p.register_starts[0]] as usize)-1;let u8 old=p.slice_elements[formal];p.slice_elements[formal]=old|128;p.slice_elements[source]=128;accepted(ref p);
    aggregate(b"module main;fn u8[1] f(ref u8[] p,ref u8[] q){return [p[0];1];}fn i32 main(){var u8[1] a=[42;1];var u8[1] b=[1;1];let ref u8[] p=ref a;let ref u8[] q=ref b;let u8[1] r=f(ref p,ref q);return r[0] as i32;}");
    aggregate(b"module main;struct P{i32 x;}fn P f(ref u8[] p,ref u8[] q){return P{.x=p[0] as i32};}fn i32 main(){var u8[1] a=[42;1];var u8[1] b=[1;1];let ref u8[] p=ref a;let ref u8[] q=ref b;let P r=f(ref p,ref q);return r.x;}");
    let u8 writer=p.call_args[base];var usize i=1;while(i<5){var ir::Program bad=p;bad.call_args[base+i]=writer;rejected(ref bad,pc);i+=1;}
}

@test
fn void legacy_runtime_call_adapters_reject_mutable_calls_before_any_publication(){
    let ir::Program p=owned(10,42);accepted(ref p);let usize pc=opcode(ref p,9,1);var calls::Frames f=calls::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(0);var records::State s=records::empty();var bytes::Buffer b=bytes::empty();var i64[256] r=[99;256];var usize[32] pcs=[77;32];var usize[32] dsts=[88;32];
    error(calls::cost(ref p,0,77),77);error(mixed::cost(ref p,0,77),77);
    assert(!calls::prepare(ref p,pc,0,ref f,ref l,ref a,ref b,10000000).is_ok);
    error(frames::step(ref p,pc,0,ref mut f,ref mut l,ref mut s,ref mut a,ref mut b,ref mut r,ref mut pcs,ref mut dsts,10000000),77);
    assert(a.owners.depth==0 && a.owners.arena.used==0 && bytes::len(ref b)==0);var usize i=0;while(i<256){assert(r[i]==99 && f.origins[i].generation==0);i+=1;}i=0;while(i<32){assert(pcs[i]==77 && dsts[i]==88);i+=1;}i=0;while(i<512){assert(l.tickets[i].generation==0 && a.tokens[i].generation==0 && s.tokens[i].generation==0);i+=1;}i=0;while(i<16){assert(!l.pool.slots[i].live);i+=1;}
    let ir::Program source=switch(compiler::compile(b"module main;fn i32 f(ref mut u8[] p){return 42;}fn i32 main(){return 42;}")){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};
    assert(verifier::inspect(ref source).is_ok && verifier::verify(ref source).is_ok);
}
