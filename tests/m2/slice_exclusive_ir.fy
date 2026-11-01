module tests::m2::slice_exclusive_ir;
import ir as ir;
import compiler as compiler;
import errors as errors;
import verifier as verifier;
import vm as vm;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};}
fn usize opcode(ref ir::Program p,u8 op){var usize pc=0;while(pc<p.count){if(p.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;}
fn void rejected(ref ir::Program p){assert(switch(verifier::inspect(p)){case .ok(_):{false}case .err(e):{e.kind==5}});assert(!verifier::verify(p).is_ok);assert(switch(vm::run_with_array_limit(p,0,65537)){case .ok(_):{false}case .err(e):{e.kind==5}});}
fn void rejected_at(ref ir::Program p,usize pc){assert(switch(verifier::inspect(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});assert(switch(verifier::verify(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});assert(switch(vm::run_with_array_limit(p,0,65537)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});}
fn void admitted(ref ir::Program p){
    assert(built(verifier::inspect(p))==p.count);
    assert(built(verifier::verify(p))==p.count);
    assert(switch(vm::run_with_array_limit(p,4000000,64)){case .ok(v):{v==42}case .err(_):{false}});
}
fn void skip(ref mut ir::Program p,usize pc){p.code[pc*8]=19;p.code[pc*8+1]=0;p.code[pc*8+3]=0;let usize patched=built(ir::patch(p,pc,pc+1,0));}
fn void typed(ref u8[] source){var ir::Program p=compiled(source);p.slice_elements[0]=128;admitted(ref p);}

@test
fn void all_scalar_owned_exclusive_sites_verify_and_execute_with_checked_dispatch(){
    typed(b"module main;fn i32 main(){var i32[1] a=[42;1];{let ref i32[] p=ref a;let i32 x=p[0];}a[0]=0;return 42;}");
    typed(b"module main;fn i32 main(){var bool[1] a=[true;1];{let ref bool[] p=ref a;let bool x=p[0];}a[0]=false;return 42;}");
    typed(b"module main;fn i32 main(){var i64[1] a=[42;1];{let ref i64[] p=ref a;let i64 x=p[0];}a[0]=0;return 42;}");
    typed(b"module main;fn i32 main(){var u8[1] a=[42;1];{let ref u8[] p=ref a;let u8 x=p[0];let usize n=p.len;let bool b=text::valid_utf8(p);}a[0]=0;return 42;}");
    typed(b"module main;fn i32 main(){var u32[1] a=[42;1];{let ref u32[] p=ref a;let u32 x=p[0];}a[0]=0;return 42;}");
    typed(b"module main;fn i32 main(){var usize[1] a=[42;1];{let ref usize[] p=ref a;let usize x=p[0];}a[0]=0;return 42;}");
    var ir::Program p=compiled(b"module main;fn i32 main(){var u8[1] a=[42;1];{let ref u8[] p=ref a[1..1];let usize n=p.len;}return 42;}");
    p.slice_elements[0]=128;admitted(ref p);
}

@test
fn void read_write_and_write_write_conflicts_are_root_wide_and_end_at_close(){
    let ir::Program p=compiled(b"module main;fn i32 main(){var u8[2] a=[42;2];let ref u8[] p=ref a[0..1];let ref u8[] q=ref a[1..2];return 42;}");
    let usize first=opcode(ref p,54);var usize second=first+1;while(p.code[second*8]!=54){second+=1;}
    var ir::Program bad=p;bad.slice_elements[0]=128;rejected_at(ref bad,second);
    bad=p;bad.slice_elements[1]=128;rejected_at(ref bad,second);
    bad.slice_elements[0]=128;rejected_at(ref bad,second);
    var ir::Program sequential=compiled(b"module main;fn i32 main(){var u8[1] a=[42;1];{let ref u8[] p=ref a;let u8 x=p[0];}{let ref u8[] q=ref a;let u8 y=q[0];}return 42;}");
    sequential.slice_elements[0]=128;sequential.slice_elements[1]=128;admitted(ref sequential);
    var ir::Program unrelated=compiled(b"module main;fn i32 main(){var u8[1] a=[42;1];var u8[1] b=[42;1];let ref u8[] p=ref a;let ref u8[] q=ref b;return 42;}");
    unrelated.slice_elements[0]=128;unrelated.slice_elements[1]=128;admitted(ref unrelated);
}

@test
fn void ordinary_reads_copies_assignment_sources_and_utf8_cannot_bypass_exclusivity(){
    var ir::Program read=compiled(b"module main;fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;let u8 x=a[0];return 42;}");
    read.slice_elements[0]=128;rejected_at(ref read,opcode(ref read,35));
    var ir::Program copy=compiled(b"module main;fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;let u8[1] b=a;return 42;}");
    copy.slice_elements[0]=128;rejected_at(ref copy,opcode(ref copy,34));
    var ir::Program assign=compiled(b"module main;fn i32 main(){var u8[1] a=[42;1];var u8[1] b=[0;1];let ref u8[] p=ref a;b=a;return 42;}");
    assign.slice_elements[0]=128;rejected_at(ref assign,opcode(ref assign,38));
    var ir::Program utf8=compiled(b"module main;fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;let bool b=text::valid_utf8(a);return 42;}");
    utf8.slice_elements[0]=128;rejected_at(ref utf8,opcode(ref utf8,51));
    var ir::Program range=compiled(b"module main;fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;let bool b=text::valid_utf8(a[..]);return 42;}");
    range.slice_elements[0]=128;rejected_at(ref range,opcode(ref range,52));
    var ir::Program dynamic=compiled(b"module main;fn i32 main(){var u8[1] a=[42;1];let usize n=1;let ref u8[] p=ref a;let bool b=text::valid_utf8(a[0..n]);return 42;}");
    dynamic.slice_elements[0]=128;rejected_at(ref dynamic,opcode(ref dynamic,53));
}

@test
fn void exclusive_aliases_subranges_calls_and_rootless_flags_remain_rejected(){
    let ir::Program aliases=compiled(b"module main;fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;let ref u8[] q=ref p;return 42;}");
    var ir::Program bad=aliases;bad.slice_elements[0]=128;rejected_at(ref bad,opcode(ref bad,59));
    bad=aliases;bad.slice_elements[1]=128;rejected_at(ref bad,opcode(ref bad,59));
    let usize before=bad.count;let usize regs=bad.registers;
    assert(!ir::slice_sub(ref mut bad,1,0,0,0,0).is_ok && bad.count==before && bad.registers==regs);
    var ir::Program call=compiled(b"module main;fn i32 f(ref u8[] p){return p[0] as i32;}fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;return f(ref p);}");
    call.slice_elements[1]=128;rejected_at(ref call,opcode(ref call,9));
    call.slice_elements[1]=0;call.slice_elements[0]=128;rejected_at(ref call,0);
}

@test
fn void exclusive_metadata_and_builder_failures_do_not_publish_or_reuse_sites(){
    var ir::Program p=compiled(b"module main;fn i32 main(){let u8[1] a=[42;1];let ref u8[] p=ref a;return 42;}");
    let usize count=p.count;let usize regs=p.registers;
    assert(!ir::exclusive_slice(ref mut p,0,17).is_ok && p.count==count && p.registers==regs && p.slice_roots[1]==0);
    p.slice_elements[0]=128;rejected_at(ref p,0);
    p.slice_elements[0]=0;p.slice_elements[15]=128;rejected_at(ref p,0);
    p.slice_elements[15]=0;p.arrays.mutable[0]=true;
    let usize site=built(ir::exclusive_slice(ref mut p,0,0));assert(site==1 && ir::exclusive(ref p,site));
    var usize i=2;while(i<16){let usize next=built(ir::exclusive_slice(ref mut p,0,0));assert(next==i);i+=1;}
    assert(!ir::exclusive_slice(ref mut p,0,0).is_ok && p.count==count && p.registers==regs);
    assert(!ir::exclusive_slice(ref mut p,16,0).is_ok);
}

@test
fn void branches_backedges_and_returns_require_balanced_exclusive_live_sets(){
    var ir::Program branch=compiled(b"module main;fn i32 main(){var u8[1] a=[42;1];if(true){let ref u8[] p=ref a;let u8 x=p[0];}return 42;}");
    branch.slice_elements[0]=128;admitted(ref branch);
    var ir::Program bad=branch;let usize branch_close=opcode(ref bad,56);skip(ref mut bad,branch_close);rejected(ref bad);
    var ir::Program loop=compiled(b"module main;fn i32 main(){var u8[1] a=[42;1];var usize n=0;while(n<2){let ref u8[] p=ref a;let u8 x=p[0];n=n+1;}return 42;}");
    loop.slice_elements[0]=128;admitted(ref loop);
    bad=loop;let usize loop_close=opcode(ref bad,56);skip(ref mut bad,loop_close);rejected(ref bad);
    var ir::Program returned=compiled(b"module main;fn i32 main(){var u8[1] a=[42;1];let ref u8[] p=ref a;return 42;}");
    returned.slice_elements[0]=128;admitted(ref returned);
    bad=returned;let usize return_close=opcode(ref bad,56);skip(ref mut bad,return_close);rejected(ref bad);
    bad=returned;let usize close=opcode(ref bad,56);bad.code[close*8]=37;bad.code[close*8+1]=0;rejected_at(ref bad,close);
}
