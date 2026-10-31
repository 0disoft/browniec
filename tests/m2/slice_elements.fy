module tests::m2::slice_elements;
import ir as ir;
import errors as errors;
import types as types;
import slice_builders as builders;
import slice_parameters as parameters;
import verifier as verifier;
import vm as vm;
import compiler as compiler;

fn usize built(Result<usize,errors::Error> r) {
    return switch(r) { case .ok(v):{v} case .err(_):{assert(false);0} };
}
fn void rejected(Result<usize,errors::Error> r,u8 kind,usize at) {
    assert(switch(r) { case .ok(_):{false} case .err(e):{e.kind==kind && e.offset==at} });
}
fn void finish(ref mut ir::Program p,usize f) {
    let usize end=p.count; let usize registers=p.registers;
    p.ends[f]=end; p.register_ends[f]=registers;
}
// A complete helper with a retained child read after closing its formal anchor.
// Entry deliberately does not call it: even an unused typed signature is gated.
fn ir::Program program(u8 element) {
    var ir::Program p=ir::empty(); p.function_count=2; p.entry=1; p.arities[0]=1;
    p.return_types[0]=1; p.return_types[1]=1;
    let usize formal=built(builders::parameter_typed(ref mut p,0,element,0));
    let usize child=built(builders::derived(ref mut p,formal,0,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));
    let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize sub=built(ir::slice_sub(ref mut p,child,formal,lo,hi,0));
    let usize close=built(ir::slice_close(ref mut p,formal,0));
    let usize read=built(ir::slice_read(ref mut p,child,lo,0)); assert(p.types[read]==element);
    let usize length=built(ir::slice_length(ref mut p,child,0)); assert(p.types[length]==12);
    let usize drop=built(ir::slice_close(ref mut p,child,0));
    let usize answer=built(ir::literal(ref mut p,42,0)); let usize ret=built(ir::emit(ref mut p,8,answer,0,0));
    finish(ref mut p,0);
    let usize start=p.count; let usize registers=p.registers;
    p.starts[1]=start; p.register_starts[1]=registers;
    let usize value=built(ir::literal(ref mut p,42,0)); let usize done=built(ir::emit(ref mut p,8,value,0,0));
    finish(ref mut p,1); return p;
}
fn usize read_register(ref ir::Program p) { return p.code[4*8+1] as usize; }

@test
fn void six_scalar_kinds_have_typed_reads_and_flow_but_only_u8_executes() {
    let u8[6] tags=[1,2,9,10,11,12]; var usize i=0;
    while(i<6) {
        let u8 element=tags[i]; let ir::Program p=program(element);
        assert(p.slice_elements[0]==element && p.slice_elements[1]==element);
        assert(built(parameters::metadata(ref p))==1 && built(verifier::inspect(ref p))==p.count);
        if(element==10) { assert(built(verifier::verify(ref p))==p.count); }
        else {
            rejected(verifier::verify(ref p),5,0);
            assert(switch(vm::run_with_array_limit(ref p,0,0)) {case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});
        }
        i+=1;
    }
    let ir::Program ordinary=program(10);
    assert(switch(vm::run(ref ordinary,1000000)) {case .ok(v):{v==42}case .err(_):{false}});
}

@test
fn void owned_and_forwarded_arguments_require_exact_elements_for_all_36_pairs() {
    let u8[6] tags=[1,2,9,10,11,12]; let usize one=1; var usize target=0;
    while(target<6) {
        var usize source=0;
        while(source<6) {
            var ir::Program p=program(tags[target]);
            let usize root=built(ir::array_in(ref mut p,1,tags[source],1,false,0));
            let usize local=built(ir::slice(ref mut p,root,0)); assert(local==2);
            assert(built(parameters::metadata(ref p))==1);
            if(source==target) { assert(built(builders::argument(ref p,0,local,1,1|(one<<34),77))==162); }
            else { rejected(builders::argument(ref p,0,local,1,1|(one<<34),77),5,77); }
            // Add another formal in the helper and retain a derived forwarding site.
            // Its register is inserted before scalar scratch in a metadata-only plan.
            var ir::Program forward=ir::empty(); forward.function_count=2; forward.entry=1; forward.arities[0]=2;
            let usize a=built(builders::parameter_typed(ref mut forward,0,tags[target],0));
            let usize b=built(builders::parameter_typed(ref mut forward,0,tags[source],0));
            let usize child=built(builders::derived(ref mut forward,b,0,0));
            forward.register_ends[0]=2; forward.register_starts[1]=2; forward.register_ends[1]=2;
            assert(built(parameters::metadata(ref forward))==3);
            if(source==target) { assert(built(builders::argument(ref forward,0,child,0,one<<34,77))==162); }
            else { rejected(builders::argument(ref forward,0,child,0,one<<34,77),5,77); }
            source+=1;
        }
        target+=1;
    }
}

@test
fn void corrupt_types_reads_and_utf8_are_rejected_without_publishing_ir() {
    let u8[6] tags=[1,2,9,10,11,12]; var usize i=0;
    while(i<6) {
        let ir::Program p=program(tags[i]); var u8 tag=0;
        while(tag<14) {
            var ir::Program bad=p; bad.slice_elements[0]=tag; bad.slice_elements[1]=tag;
            if(!types::scalar(tag)) { rejected(parameters::metadata(ref bad),5,0); rejected(verifier::inspect(ref bad),5,0); }
            if(tag!=tags[i]) {
                bad=p; bad.slice_elements[1]=tag; rejected(parameters::metadata(ref bad),5,0);
                if(types::valid(tag)) {
                    bad=p; let usize dst=read_register(ref bad); bad.types[dst]=tag;
                    rejected(verifier::inspect(ref bad),5,4);
                }
            }
            tag+=1;
        }
        if(tags[i]!=10) {
            var ir::Program bad=p; let usize count=bad.count; let usize registers=bad.registers;
            rejected(ir::slice_utf8(ref mut bad,1,77),3,77);
            assert(bad.count==count && bad.registers==registers);
            // A fabricated UTF-8 instruction cannot pass the independent proof.
            bad=p; bad.code[32]=55; bad.code[35]=0; let usize dst=read_register(ref bad); bad.types[dst]=2;
            rejected(verifier::inspect(ref bad),5,4);
        }
        i+=1;
    }
    var ir::Program orphan=program(10); orphan.slice_elements[15]=1;
    rejected(parameters::metadata(ref orphan),5,0);
}

@test
fn void invalid_tags_capacity_and_derived_corruption_preserve_declarations() {
    var u8 tag=0;
    while(tag<14) {
        if(!types::scalar(tag)) {
            var ir::Program p=ir::empty(); p.function_count=2; p.entry=1; p.arities[0]=1;
            rejected(builders::parameter_typed(ref mut p,0,tag,77),3,77);
            assert(p.registers==0 && p.slice_parameters[0]==0 && p.slice_origins[0]==0 && p.slice_elements[0]==0);
        }
        tag+=1;
    }
    var ir::Program full=program(9); var usize i=2;
    while(i<16) { assert(built(builders::derived(ref mut full,1,0,0))==i); i+=1; }
    let usize registers=full.registers; let usize count=full.count;
    rejected(builders::derived(ref mut full,1,0,77),4,77);
    assert(full.registers==registers && full.count==count && full.slice_elements[15]==9);
    var ir::Program bad=program(9); bad.slice_elements[1]=1;
    rejected(builders::derived(ref mut bad,1,0,77),3,77);
    assert(bad.slice_origins[2]==0 && bad.slice_elements[2]==0);
    // Source lowers typed signatures; public VM admission still rejects them.
    let ir::Program source=switch(compiler::compile(b"module main;fn i32 f(ref i32[] p){return 42;}fn i32 main(){return 42;}")) {
        case .ok(v):{v} case .err(_):{assert(false);ir::empty()}
    };
    assert(verifier::inspect(ref source).is_ok); rejected(verifier::verify(ref source),5,0);
}
