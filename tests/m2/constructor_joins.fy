module tests::m2::constructor_joins;
import value_join_source as joins;
import ir as ir;
import types as types;
import errors as errors;
import verifier as verifier;
import vm as vm;
fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize payload(ref mut ir::Program p,u8 tag){return if(tag==0){0}else if(tag==1){built(ir::literal(p,42,0))}else{built(ir::boolean(p,true,0))};}
fn void finish(ref mut ir::Program p){let usize end=p.count;let usize registers=p.registers;
    p.function_count=1;p.entry=0;p.starts[0]=0;p.ends[0]=end;
    p.register_starts[0]=0;p.register_ends[0]=registers;p.return_types[0]=1;
}
fn ir::Program program(u8 tag,bool selected,bool reverse,usize prefix,bool known){
    var ir::Program p=ir::empty();var joins::Join join=joins::empty(0,false);var usize i=0;
    while(i<prefix){let usize n=built(ir::literal(ref mut p,0,0));i+=1;}
    let usize condition=built(ir::boolean(ref mut p,selected,0));
    let usize branch=built(ir::raw(ref mut p,20,0,condition,0,0));
    let u8 first=if(reverse){1}else{0};let u8 second=1-first;
    let usize a=payload(ref mut p,types::payload(tag,first));
    let usize accepted=built(joins::constructor(ref mut p,ref mut join,tag<=4,first,a,0));
    let usize skip=built(ir::raw(ref mut p,19,0,0,0,0));let usize otherwise=p.count;
    let usize patched_else=built(ir::patch(ref mut p,branch,otherwise,0));
    let usize b=payload(ref mut p,types::payload(tag,second));
    if(known){let usize value=built(ir::construct(ref mut p,tag,second,b,0));
        let usize accepted=built(joins::scalar(ref mut p,ref mut join,value,0));}
    else{let usize accepted=built(joins::constructor(ref mut p,ref mut join,tag<=4,second,b,0));}
    if(prefix==64){assert(join.pending[1]!=0);}
    let usize merge=p.count;let usize patched_merge=built(ir::patch(ref mut p,skip,merge,0));
    let usize value=built(joins::finish(ref mut p,ref join,0));assert(p.types[value]==tag);
    let u8 variant=if(selected){first}else{second};
    let ir::Case check=switch(ir::branch_case(ref mut p,value,variant,0)){case .ok(v):{v}case .err(_):{assert(false);return p;}};
    var usize test=256;
    if(types::payload(tag,variant)!=0){let usize condition=if(types::payload(tag,variant)==1){
            let usize expected=built(ir::literal(ref mut p,42,0));built(ir::emit(ref mut p,11,check.payload,expected,0))
        }else{check.payload};test=built(ir::raw(ref mut p,20,0,condition,0,0));}
    let usize answer=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,answer,0,0));
    let usize failure=p.count;let usize patched_case=built(ir::patch(ref mut p,check.instruction,failure,0));
    if(test!=256){let usize patched=built(ir::patch(ref mut p,test,failure,0));}
    let usize zero=built(ir::literal(ref mut p,0,0));let usize returned_zero=built(ir::emit(ref mut p,8,zero,0,0));
    finish(ref mut p);return p;
}
fn void run(u8 tag,bool selected,bool reverse,usize prefix,bool known){let ir::Program p=program(tag,selected,reverse,prefix,known);
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run(ref p,1000)){case .ok(n):{n==42}case .err(_):{false}});
}
@test fn void all_six_existing_wrappers_unify_in_both_branch_orders_and_selected_paths(){
    var u8 tag=3;while(tag<=8){run(tag,true,false,0,false);run(tag,false,false,0,false);
        run(tag,true,true,0,false);run(tag,false,true,0,false);tag+=1;}
}
@test fn void complete_values_constrain_pending_constructors_and_both_register_bitsets(){
    run(4,true,false,0,true);run(6,false,false,0,true);run(7,true,true,64,true);run(4,true,false,64,false);
}
fn void ambiguous(bool option,u8 variant){var ir::Program p=ir::empty();var joins::Join join=joins::empty(0,false);
    let usize value=payload(ref mut p,if(option){0}else{1});
    let usize accepted=built(joins::constructor(ref mut p,ref mut join,option,variant,value,0));
    let usize count=p.count;assert(!joins::finish(ref mut p,ref join,0).is_ok && p.count==count);
}
@test fn void missing_domains_and_conflicting_constructor_families_fail_without_a_result(){
    ambiguous(true,0);ambiguous(false,0);ambiguous(false,1);
    var ir::Program p=ir::empty();var joins::Join join=joins::empty(0,false);
    let usize a=built(joins::constructor(ref mut p,ref mut join,true,0,0,0));
    let usize n=built(ir::literal(ref mut p,42,0));assert(!joins::constructor(ref mut p,ref mut join,false,1,n,0).is_ok);
    assert(!joins::finish(ref mut p,ref join,0).is_ok);
}
@test fn void inference_metadata_does_not_replace_independent_tagged_cfg_admission(){
    var ir::Program p=program(4,true,false,0,false);var usize r=0;
    while(r<p.registers && p.types[r]!=4){r+=1;}assert(r<p.registers);p.types[r]=3;
    assert(!verifier::verify(ref p).is_ok);
}
