module tests::m2::void_execution;
import ir as ir;
import vm as vm;
import verifier as verifier;
import errors as errors;
import static_image as images;
import static_call_ir as calls;
import program_image as programs;
fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn ir::Program unit(usize count){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=13;p.return_types[1]=1;
    let usize returned=built(ir::raw(ref mut p,82,0,0,0,0));
    p.starts[0]=0;p.ends[0]=1;p.register_starts[0]=0;p.register_ends[0]=0;p.starts[1]=1;p.register_starts[1]=0;
    var usize i=0;while(i<count){let usize n=built(ir::literal(ref mut p,42,0));i+=1;}
    let usize[1] args=[0];let usize call=built(ir::call(ref mut p,0,ref args[..0],0));
    assert(call==256 && p.registers==count);
    let usize end=built(ir::emit(ref mut p,8,0,0,0));let usize pc=p.count;let usize registers=p.registers;
    p.ends[1]=pc;p.register_ends[1]=registers;return p;
}
fn images::Image image(){var images::Builder b=switch(images::builder(0)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    return switch(images::freeze(ref b,images::metadata_charge())){case .ok(v):{v}case .err(_):{assert(false);image()}};
}
@test fn void void_returns_write_no_caller_cell_and_use_one_dispatch_unit(){
    let ir::Program p=unit(1);assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run(ref p,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run(ref p,3)){case .ok(_):{false}case .err(e):{e.kind==8}});
    let calls::Program code=calls::Program{.body=p,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    switch(programs::retain_reference_returns(ref code,image(),65536)){
        case .ok(p):{
            assert(switch(programs::run_public_references(ref p,688132)){case .ok(n):{n==42}case .err(_):{false}});
            assert(switch(programs::run_public_references(ref p,688131)){case .ok(_):{false}case .err(e):{e.kind==8}});
        }
        case .err(_):{assert(false);}
    };
}
@test fn void void_calls_still_fit_when_all_128_value_registers_are_used(){
    let ir::Program p=unit(128);assert(p.registers==128 && verifier::verify(ref p).is_ok);
    assert(switch(vm::run(ref p,131)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run(ref p,130)){case .ok(_):{false}case .err(e):{e.kind==8}});
}
@test fn void independent_proof_rejects_void_values_malformed_returns_and_destinations(){
    var ir::Program p=unit(1);p.return_types[0]=1;assert(!verifier::verify(ref p).is_ok);
    p=unit(1);p.code[0]=8;assert(!verifier::verify(ref p).is_ok);
    var usize i=1;while(i<8){p=unit(1);p.code[i]=1;assert(!verifier::verify(ref p).is_ok);i+=1;}
    p=unit(1);p.code[17]=1;assert(!verifier::verify(ref p).is_ok);
    p=unit(1);p.types[0]=13;assert(!verifier::verify(ref p).is_ok);
    p=unit(1);p.code[0]=1;assert(!verifier::verify(ref p).is_ok);
}
