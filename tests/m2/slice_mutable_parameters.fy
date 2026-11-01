module tests::m2::slice_mutable_parameters;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import compiler as compiler;
import slice_builders as builders;
import slice_parameters as parameters;
import slice_call_vm as calls;
import slice_frame_vm as shared;
import slice_exclusive_vm as exclusive;
import slice_vm as loans;
import array_vm as arrays;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void error(Result<usize,errors::Error> r,u8 kind,usize offset){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==offset}});}
fn usize constant(ref mut ir::Program p,u8 tag,i64 cell){return built(if(tag==2){ir::boolean(p,cell==1,77)}else{ir::integer(p,cell,tag,77)});}
fn void finish(ref mut ir::Program p,usize f){let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;}
fn usize pc(ref ir::Program p,u8 op){var usize i=0;while(i<p.count){if(p.code[i*8]==op){return i;}i+=1;}assert(false);return 0;}
fn ir::Program header(u8 tag,i64 cell){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.arities[0]=1;p.return_types[0]=1;p.return_types[1]=1;
    let usize site=built(builders::parameter_exclusive(ref mut p,0,tag,77));assert(site==0 && p.registers==1 && p.types[0]==0);
    let usize index=constant(ref mut p,12,0);let usize value=constant(ref mut p,tag,cell);
    let usize written=built(ir::slice_write(ref mut p,site,index,value,77));
    let usize read=built(ir::slice_read(ref mut p,site,index,77));assert(p.types[read]==tag);
    let usize length=built(ir::slice_length(ref mut p,site,77));assert(p.types[length]==12);
    if(tag==10){let usize valid=built(ir::slice_utf8(ref mut p,site,77));assert(p.types[valid]==2);}
    let usize closed=built(ir::slice_close(ref mut p,site,77));let usize answer=constant(ref mut p,1,42);let usize returned=built(ir::emit(ref mut p,8,answer,0,77));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;return p;
}
fn ir::Program program(u8 tag,i64 cell){var ir::Program p=header(tag,cell);let usize answer=constant(ref mut p,1,42);let usize returned=built(ir::emit(ref mut p,8,answer,0,77));finish(ref mut p,1);return p;}
fn void invalid(ref ir::Program p){assert(!verifier::inspect(p).is_ok);assert(!verifier::verify(p).is_ok);assert(switch(vm::run_with_array_limit(p,0,65537)){case .ok(_):{false}case .err(e):{e.kind==5}});}
fn void builder_error(ref mut ir::Program p,usize f,u8 tag,u8 kind){
    let usize regs=p.registers;let usize count=p.count;let usize constants=p.constant_count;
    let u8[128] parameters=p.slice_parameters;let u8[16] roots=p.slice_roots;let u8[16] origins=p.slice_origins;let u8[16] functions=p.slice_functions;let u8[16] elements=p.slice_elements;
    error(builders::parameter_exclusive(p,f,tag,77),kind,77);assert(p.registers==regs && p.count==count && p.constant_count==constants);
    var usize i=0;while(i<128){assert(p.slice_parameters[i]==parameters[i]);i+=1;}i=0;while(i<16){assert(p.slice_roots[i]==roots[i] && p.slice_origins[i]==origins[i] && p.slice_functions[i]==functions[i] && p.slice_elements[i]==elements[i]);i+=1;}
}

@test
fn void six_scalar_formals_inspect_reads_stores_lengths_and_utf8_and_public_admission_is_proved(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] cells=[-2147483648,1,-9223372036854775807-1,255,4294967295,-1];var usize i=0;let usize one=1;
    while(i<6){let ir::Program p=program(tags[i],cells[i]);assert(p.slice_elements[0]==(tags[i]|128) && ir::exclusive(ref p,0) && p.slice_roots[0]==0 && p.slice_origins[0]==1 && p.slice_functions[0]==1);
        assert(switch(ir::slice_element(ref p,0,77)){case .ok(v):{v==tags[i]}case .err(_):{false}});
        assert(built(parameters::metadata(ref p))==1 && built(parameters::initial(ref p,0))==(one<<32));
        assert(built(verifier::inspect(ref p))==p.count);assert(built(verifier::verify(ref p))==p.count);
        assert(switch(vm::run_with_array_limit(ref p,0,65537)){case .ok(_):{false}case .err(e):{e.kind==8}});i+=1;
    }
}

@test
fn void invalid_tags_positions_and_capacity_reject_without_publishing_a_descriptor(){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.arities[0]=1;
    let u8[5] tags=[0,3,128,129,255];var usize i=0;while(i<5){builder_error(ref mut p,0,tags[i],3);i+=1;}
    builder_error(ref mut p,1,10,3);builder_error(ref mut p,16,10,3);
    p.arities[0]=0;builder_error(ref mut p,0,10,3);p.arities[0]=9;builder_error(ref mut p,0,10,3);p.arities[0]=1;
    p.types[0]=1;builder_error(ref mut p,0,10,3);p.types[0]=0;p.slots[0]=true;builder_error(ref mut p,0,10,3);p.slots[0]=false;
    p.slice_parameters[0]=1;builder_error(ref mut p,0,10,3);p.slice_parameters[0]=0;
    p.registers=128;builder_error(ref mut p,0,10,4);p.registers=0;
    i=0;while(i<16){p.slice_elements[i]=10;i+=1;}builder_error(ref mut p,0,10,4);
}

@test
fn void metadata_rejects_orphans_owned_tag_flags_derived_writers_and_duplicate_parameters(){
    let ir::Program p=program(10,42);var ir::Program bad=p;
    bad.slice_elements[0]=128;invalid(ref bad);bad=p;bad.slice_elements[0]=255;invalid(ref bad);bad=p;bad.slice_elements[0]=0;invalid(ref bad);
    bad=p;bad.slice_origins[0]=0;invalid(ref bad);bad=p;bad.slice_functions[0]=2;invalid(ref bad);
    bad=p;bad.slice_parameters[0]=0;invalid(ref bad);bad=p;bad.types[0]=10;invalid(ref bad);
    bad=p;bad.slice_origins[1]=1;bad.slice_functions[1]=1;bad.slice_elements[1]=138;invalid(ref bad);
    bad=p;let usize root=built(ir::array_in(ref mut bad,1,10,1,true,77));bad.slice_roots[0]=1;invalid(ref bad);
    // All sixteen site ordinals fit across two eight-argument helpers; this is
    // metadata evidence only, not a claim of mutable CALL or VM execution.
    var ir::Program full=ir::empty();full.function_count=3;full.entry=2;full.registers=16;full.arities[0]=8;full.arities[1]=8;full.register_ends[0]=8;full.register_starts[1]=8;full.register_ends[1]=16;full.register_starts[2]=16;full.register_ends[2]=16;
    var usize i=0;var u8 ordinal=1;while(i<16){full.slice_parameters[i]=ordinal;full.slice_origins[i]=ordinal;full.slice_functions[i]=if(i<8){1}else{2};full.slice_elements[i]=138;i+=1;ordinal+=1;}
    assert(built(parameters::metadata(ref full))==65535);full.slice_parameters[1]=1;assert(!parameters::metadata(ref full).is_ok);
}

@test
fn void stores_require_exact_defined_operands_and_balanced_function_lifetimes(){
    let ir::Program p=program(1,42);let usize store=pc(ref p,60);let usize read=pc(ref p,58);let usize close=pc(ref p,56);var ir::Program bad=p;
    bad.types[2]=11;invalid(ref bad);bad=p;bad.types[1]=2;invalid(ref bad);
    bad=p;bad.code[store*8+3]=p.code[read*8+1];invalid(ref bad);
    bad=p;bad.code[store*8+2]=0;invalid(ref bad);
    bad=p;bad.code[close*8]=19;bad.code[close*8+1]=0;bad.code[close*8+3]=0;let usize patched=built(ir::patch(ref mut bad,close,close+1,77));invalid(ref bad);
    bad=p;bad.slice_elements[0]=1;invalid(ref bad);
    var ir::Program derived=p;let usize count=derived.count;let usize regs=derived.registers;
    error(builders::derived(ref mut derived,0,0,77),3,77);assert(derived.count==count && derived.registers==regs && derived.slice_origins[1]==0);
    error(ir::slice_open(ref mut derived,0,1,1,77),3,77);error(ir::slice_sub(ref mut derived,0,0,1,1,77),3,77);
}

@test
fn void exact_mutable_call_proof_is_public_and_readonly_coercions_are_rejected(){
    var ir::Program p=header(10,42);let usize root=built(ir::array_in(ref mut p,1,10,1,true,77));let usize site=built(ir::exclusive_slice(ref mut p,root,77));
    let usize fill=constant(ref mut p,10,42);let usize init=built(ir::array_init(ref mut p,root,fill,77));let usize lo=constant(ref mut p,12,0);let usize hi=constant(ref mut p,12,1);let usize opened=built(ir::slice_open(ref mut p,site,lo,hi,77));
    let usize one=1;let usize live=1|(one<<33);
    assert(built(builders::argument(ref p,0,site,1,live,77))==161);
    p.slice_elements[site]=0;error(builders::argument(ref p,0,site,1,live,77),5,77);
    p.slice_elements[0]=10;assert(built(builders::argument(ref p,0,site,1,live,77))==161);
    p.slice_elements[site]=128;error(builders::argument(ref p,0,site,1,live,77),5,77);p.slice_elements[0]=138;
    let usize[1] args=[161];let usize result=built(ir::call(ref mut p,0,ref args,77));let usize call_pc=pc(ref p,9);
    let usize closed=built(ir::slice_close(ref mut p,site,77));let usize drop=built(ir::array_drop(ref mut p,root,77));let usize returned=built(ir::emit(ref mut p,8,result,0,77));finish(ref mut p,1);
    assert(built(verifier::inspect(ref p))==p.count);assert(built(verifier::verify(ref p))==p.count);
}

@test
fn void runtime_adapters_reject_private_formals_while_existing_owned_mutable_source_stays_public(){
    let ir::Program p=program(10,42);var calls::Frames f=calls::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(0);var bytes::Buffer b=bytes::empty();var i64[128] r=[99;128];
    error(calls::cost(ref p,0,77),5,77);
    assert(switch(calls::root(ref p,0,0,0,ref f,ref a,77)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==77}});
    let usize read=pc(ref p,58);error(shared::step(ref p,0,read,0,ref f,ref mut l,ref mut a,ref b,ref mut r,0),5,77);
    error(exclusive::step(ref p,0,read,0,ref mut l,ref mut a,ref mut b,ref mut r,0),5,77);
    assert(a.owners.depth==0 && bytes::len(ref b)==0);var usize i=0;while(i<128){assert(r[i]==99);i+=1;}i=0;while(i<16){assert(!l.pool.slots[i].live);i+=1;}
    let ir::Program owned=switch(compiler::compile(b"module main;fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;p[0]=42;return p[0];}")){case .ok(v):{v}case .err(_):{assert(false);ir::empty()}};
    assert(verifier::verify(ref owned).is_ok);assert(switch(vm::run_with_array_limit(ref owned,1000000,4)){case .ok(v):{v==42}case .err(_):{false}});
}
