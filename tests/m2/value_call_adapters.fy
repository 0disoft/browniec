module tests::m2::value_call_adapters;
import ir as ir;
import errors as errors;
import value_ir as values;
import value_properties as properties;
import verifier as verifier;
import program_image as images;
import call_frame_vm as calls;
import mixed_call_vm as mixed;
import slice_authority_call_vm as canonical;
import slice_authority as authority;
import slice_reborrow_ir as forest;
import slice_reborrow_call_vm as derived;
import slice_reborrow_vm as children;
import slice_call_vm as shared;
import slice_vm as loans;
import array_vm as arrays;
import struct_vm as records;
import std::bytes as bytes;

fn usize ok(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void emit(ref mut ir::Program p,u8 op,usize dst,usize a,usize b){let usize pc=ok(ir::raw(p,op,dst,a,b,77));}
fn values::Program program(){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.catalog.count=1;unit.catalog.nodes[0]=properties::Node{.kind=4,.first=0,.second=0,.extent=0};
    unit.types[0]=1;unit.types[15]=1;unit.types[2]=1;unit.functions[2]=1;
    let usize first=ok(ir::literal(ref mut unit.body,42,77));let usize last=ok(ir::literal(ref mut unit.body,7,77));
    emit(ref mut unit.body,95,0,0,0);emit(ref mut unit.body,93,15,1,0);
    emit(ref mut unit.body,90,15,0,0);emit(ref mut unit.body,8,0,first,0);
    let usize end=unit.body.count;unit.body.ends[0]=end;unit.body.register_ends[0]=2;unit.body.return_types[0]=1;
    unit.body.starts[1]=end;emit(ref mut unit.body,94,0,2,0);let usize final_end=unit.body.count;unit.body.ends[1]=final_end;
    unit.body.function_count=2;unit.body.registers=5;unit.body.register_starts[1]=2;unit.body.register_ends[1]=5;
    unit.body.arities[1]=3;unit.body.types[2]=1;unit.body.types[3]=0;unit.body.types[4]=1;
    unit.parameters[3]=3;unit.results[1]=3;unit.body.call_count=1;unit.body.call_arities[0]=3;
    unit.body.call_args[0]=0;unit.body.call_args[1]=208;unit.body.call_args[2]=1;
    assert(verifier::inspect_values(ref unit).is_ok);return unit;
}
fn forest::Sites sites(){return forest::Sites{.parents=[16;16],.newer=[0;16],.count=0};}
fn void entered(ref ir::Program p,ref forest::Sites s,bool canonical_path,usize fuel,usize remaining){
    var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(0);
    var records::State r=records::empty();var canonical::Bindings c=canonical::empty();var authority::State auth=authority::empty();
    let children::Bindings child=children::empty();var i64[256] regs=[-91;256];var usize[2] pcs=[99;2];var usize[2] dsts=[98;2];
    var bytes::Buffer b=bytes::empty();regs[0]=42;regs[1]=7;
    let usize left=ok(if(canonical_path){calls::step_canonical_derived(p,s,3,0,ref child,ref mut c,ref mut auth,
        ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,ref mut regs,ref mut pcs,ref mut dsts,fuel)
    }else{calls::step(p,3,0,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,ref mut regs,ref mut pcs,ref mut dsts,fuel)});
    assert(left==remaining && regs[130]==42 && regs[131]==-91 && regs[132]==7);
    assert(regs[208]==-91 && regs[0]==42 && regs[1]==7 && pcs[1]==4 && dsts[1]==15);
    if(canonical_path){assert(auth.depth==1 && c.pcs[0]==3);}
}
@test fn void verified_value_call_preserves_scalar_positions_and_separate_result_namespace(){
    let values::Program unit=program();let forest::Sites s=sites();
    assert(!verifier::verify(ref unit.body).is_ok && !images::retain_public_legacy(ref unit.body).is_ok);
    assert(ok(mixed::cost(ref unit.body,1,77))==4 && ok(canonical::cost(ref unit.body,3,77))==4);
    entered(ref unit.body,ref s,false,11,7);entered(ref unit.body,ref s,true,11,7);
    // A forest can suspend a caller even when none of its loans is passed.
    var forest::Sites suspended=sites();suspended.count=1;
    assert(derived::required(ref unit.body,ref suspended,3));
    entered(ref unit.body,ref suspended,true,4,0);
}
fn void rejected(ref ir::Program p){
    var shared::Frames f=shared::empty();var loans::State l=loans::empty();var arrays::State a=arrays::empty(0);
    var records::State r=records::empty();var i64[256] regs=[-91;256];var usize[2] pcs=[99;2];var usize[2] dsts=[98;2];
    var bytes::Buffer b=bytes::empty();
    assert(switch(calls::step(p,3,0,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,
        ref mut regs,ref mut pcs,ref mut dsts,10)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==77}});
    assert(!canonical::info(p,3,77).is_ok);
    assert(regs[130]==-91 && regs[131]==-91 && regs[132]==-91 && pcs[1]==99 && dsts[1]==98);
}
@test fn void value_adapter_exceptions_do_not_apply_to_ordinary_calls_or_scalar_arguments(){
    var values::Program unit=program();unit.body.code[3*8+1]=16;rejected(ref unit.body);
    unit=program();unit.body.call_args[1]=224;rejected(ref unit.body);
    unit=program();unit.body.call_args[0]=208;rejected(ref unit.body);
    unit=program();unit.body.code[3*8]=9;unit.body.return_types[1]=1;unit.body.code[3*8+1]=0;rejected(ref unit.body);
    let forest::Sites s=sites();assert(!derived::required(ref unit.body,ref s,3));
}
