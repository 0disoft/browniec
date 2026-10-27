module tests::m2::struct_results_ir;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import struct_results as results;
fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};}
fn usize cell(ref mut ir::Program p,u8 tag){return if(tag==2){built(ir::boolean(p,true,0))}else{built(ir::integer(p,42,tag,0))};}
fn void finish(ref mut ir::Program p,usize f){let usize n=p.count;let usize r=p.registers;p.ends[f]=n;p.register_ends[f]=r;}
fn bool invalid(ref ir::Program p){return switch(verifier::verify(p)){case .err(e):{e.kind==5}case .ok(_):{false}};}
// Modes: local, parameter, recursive forwarding, nested, extra record, extra
// array, dead source, live caller destination, distinct matching/wrong source.
fn ir::Program program(u8 tag,u8 mode){
 var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[1]=1;
 p.records.layouts.count=3;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=tag;
 p.records.layouts.fields[1]=1;p.records.layouts.types[16]=tag;
 p.records.layouts.fields[2]=2;p.records.layouts.kinds[32]=1;p.records.layouts.types[32]=0;p.records.layouts.types[33]=2;
 let usize nominal=if(mode==3){2}else{0};
 let usize anchor=if(mode==1){p.arities[0]=1;built(ir::record_parameter(ref mut p,0,nominal,0))}
  else{built(ir::record_in(ref mut p,0,nominal,mode==0,0))};p.record_results[0]=1;
 var usize source=anchor;
 if(mode==8 || mode==9){source=built(ir::record_in(ref mut p,0,if(mode==9){1}else{nominal},false,0));}
 if(mode==2){let usize[1] args=[0;1];let usize c=built(ir::record_call(ref mut p,0,source,ref args[..0],0));}
 else if(mode!=1){let usize fill=cell(ref mut p,tag);if(mode==3){let usize flag=cell(ref mut p,2);}let usize init=built(ir::record_init(ref mut p,source,fill,0));
  if(mode==4){let usize extra=built(ir::record_in(ref mut p,0,nominal,false,0));let usize init_extra=built(ir::record_init(ref mut p,extra,fill,0));}
  if(mode==5){let usize extra=built(ir::array_in(ref mut p,0,tag,1,false,0));let usize init_extra=built(ir::array_init(ref mut p,extra,fill,0));}
  if(mode==6){let usize drop=built(ir::record_drop(ref mut p,source,0));}
 }
 let usize ret=built(ir::record_return(ref mut p,source,0));finish(ref mut p,0);
 let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
 var usize original=0;var usize[1] args=[0;1];
 if(mode==1){original=built(ir::record_in(ref mut p,1,nominal,false,0));let usize fill=cell(ref mut p,tag);let usize init=built(ir::record_init(ref mut p,original,fill,0));args[0]=144+original;}
 let usize destination=built(ir::record_in(ref mut p,1,nominal,true,0));
 if(mode==7){let usize fill=cell(ref mut p,tag);let usize init=built(ir::record_init(ref mut p,destination,fill,0));}
 let usize argc=p.arities[0];let usize called=built(ir::record_call(ref mut p,0,destination,ref args[..argc],0));
 let usize read=built(ir::record_read(ref mut p,destination,0,0));let usize drop=built(ir::record_drop(ref mut p,destination,0));
 if(mode==1){let usize drop_original=built(ir::record_drop(ref mut p,original,0));}
 let usize answer=cell(ref mut p,1);let usize done=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,1);return p;
}
fn usize call_pc(ref ir::Program p){var usize pc=p.starts[1];while(p.code[pc*8]!=9){pc+=1;}return pc;}
fn ir::Program flow(u8 mode){
 var ir::Program p=program(1,0);p.count=p.starts[1];p.registers=p.register_starts[1];p.call_count=0;
 let usize cond=cell(ref mut p,2);let usize branch=built(ir::raw(ref mut p,20,0,cond,0,0));let usize[1] args=[0;1];
 let usize left=built(ir::record_call(ref mut p,0,1,ref args[..0],0));
 if(mode<2){let usize jump=built(ir::raw(ref mut p,19,0,0,0,0));let usize alternate=p.count;let usize patched=built(ir::patch(ref mut p,branch,alternate,0));
  if(mode==0){let usize right=built(ir::record_call(ref mut p,0,1,ref args[..0],0));}
  else{let usize next=p.count+1;let usize right=built(ir::raw(ref mut p,19,0,next,0,0));}
  let usize joined=p.count;let usize patched_join=built(ir::patch(ref mut p,jump,joined,0));let usize drop=built(ir::record_drop(ref mut p,1,0));
 }else{if(mode==2){let usize drop=built(ir::record_drop(ref mut p,1,0));}let usize back=built(ir::raw(ref mut p,22,0,branch,0,0));let usize exit=p.count;let usize patched=built(ir::patch(ref mut p,branch,exit,0));}
 let usize answer=cell(ref mut p,1);let usize ret=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,1);return p;
}
@test
fn void all_leaf_tags_nested_and_forwarded_results_verify_without_scalar_placeholders(){
 let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<6){let ir::Program p=program(tags[i],0);assert(verifier::verify(ref p).is_ok);assert(p.return_types[0]==0 && p.record_results[0]==1);i+=1;}
 let ir::Program nested=program(1,3);assert(verifier::verify(ref nested).is_ok);
 let ir::Program forwarded=program(1,2);assert(verifier::verify(ref forwarded).is_ok);
 let ir::Program distinct=program(1,8);assert(verifier::verify(ref distinct).is_ok);
 let ir::Program empty=ir::empty();i=0;while(i<16){assert(empty.record_results[i]==0);i+=1;}
}
@test
fn void malformed_metadata_entry_results_and_mixed_result_kinds_fail(){
 let ir::Program good=program(1,0);var ir::Program p=good;
 p.record_results[0]=17;assert(invalid(ref p));p=good;p.record_results[0]=255;assert(invalid(ref p));
 p=good;p.record_results[0]=2;assert(invalid(ref p));p=good;p.record_results[1]=2;assert(invalid(ref p));
 p=good;p.record_results[15]=1;assert(invalid(ref p));p=good;p.return_types[0]=1;assert(invalid(ref p));
 p=good;p.array_results[0]=1;assert(invalid(ref p));p=good;p.record_results[0]=0;assert(invalid(ref p));
 p=good;p.record_functions[0]=1;assert(invalid(ref p));
}
@test
fn void result_calls_require_dead_caller_owned_exact_nominal_destinations_and_valid_arguments(){
 let ir::Program good=program(1,0);let usize pc=call_pc(ref good);var ir::Program p=good;
 let u8[6] bad=[0,128,143,144,160,255];var usize i=0;while(i<6){p=good;p.code[pc*8+1]=bad[i];assert(invalid(ref p));i+=1;}
 p=good;p.records.records[1]=1;assert(invalid(ref p));p=good;p.record_functions[1]=0;assert(invalid(ref p));
 p=good;p.call_arities[0]=1;assert(invalid(ref p));p=good;p.call_args[0]=1;assert(invalid(ref p));
 p=good;p.code[(pc+1)*8]=9;p.code[(pc+1)*8+1]=145;p.code[(pc+1)*8+2]=0;p.code[(pc+1)*8+3]=0;assert(invalid(ref p));
 let ir::Program live=program(1,7);assert(invalid(ref live));
}
@test
fn void returns_require_the_sole_live_callee_record_and_reserved_operands(){
 let ir::Program good=program(1,0);let usize ret=good.ends[0]-1;var ir::Program p=good;
 let u8[3] bad=[1,16,255];var usize i=0;while(i<3){p=good;p.code[ret*8+2]=bad[i];assert(invalid(ref p));i+=1;}
 i=0;while(i<8){if(i!=0 && i!=2){p=good;p.code[ret*8+i]=1;assert(invalid(ref p));}i+=1;}
 p=good;p.code[ret*8]=8;assert(invalid(ref p));p=good;p.code[ret*8]=39;assert(invalid(ref p));
 let ir::Program extra_record=program(1,4);assert(invalid(ref extra_record));let ir::Program extra_array=program(1,5);assert(invalid(ref extra_array));
 let ir::Program dead=program(1,6);assert(invalid(ref dead));let ir::Program wrong=program(1,9);assert(invalid(ref wrong));
}
@test
fn void record_parameter_results_are_valid_but_dropped_formals_are_not_call_destinations(){
 let ir::Program p=program(1,1);assert(verifier::verify(ref p).is_ok);
 assert(switch(results::call(ref p,0,144,0,0,0)){case .err(e):{e.kind==5}case .ok(_):{false}});
 var ir::Program mixed=ir::empty();mixed.function_count=2;mixed.entry=1;mixed.return_types[1]=1;mixed.arities[0]=3;
 mixed.records.layouts.count=1;mixed.records.layouts.fields[0]=1;mixed.records.layouts.types[0]=1;
 let usize record=built(ir::record_parameter(ref mut mixed,0,0,0));let usize array=built(ir::array_parameter(ref mut mixed,0,1,1,0));mixed.types[2]=1;mixed.registers=3;mixed.record_results[0]=1;
 let usize drop=built(ir::array_drop(ref mut mixed,array,0));let usize ret=built(ir::record_return(ref mut mixed,record,0));finish(ref mut mixed,0);
 let usize start=mixed.count;let usize regs=mixed.registers;mixed.starts[1]=start;mixed.register_starts[1]=regs;
 let usize origin=built(ir::record_in(ref mut mixed,1,0,false,0));let usize original_array=built(ir::array_in(ref mut mixed,1,1,1,false,0));let usize fill=cell(ref mut mixed,1);
 let usize init_record=built(ir::record_init(ref mut mixed,origin,fill,0));let usize init_array=built(ir::array_init(ref mut mixed,original_array,fill,0));
 let usize dest=built(ir::record_in(ref mut mixed,1,0,false,0));let usize[3] args=[144+origin,128+original_array,fill];let usize call=built(ir::record_call(ref mut mixed,0,dest,ref args,0));
 let usize drop_dest=built(ir::record_drop(ref mut mixed,dest,0));let usize drop_array=built(ir::array_drop(ref mut mixed,original_array,0));let usize drop_record=built(ir::record_drop(ref mut mixed,origin,0));
 let usize done=built(ir::emit(ref mut mixed,8,fill,0,0));finish(ref mut mixed,1);assert(verifier::verify(ref mixed).is_ok);
 mixed.call_args[0]=129;assert(invalid(ref mixed));
}
@test
fn void call_results_preserve_exact_join_and_backedge_lifetimes(){
 let ir::Program joined=flow(0);assert(verifier::verify(ref joined).is_ok);let ir::Program looped=flow(2);assert(verifier::verify(ref looped).is_ok);
 let ir::Program mismatch=flow(1);assert(invalid(ref mismatch));let ir::Program leak=flow(3);assert(invalid(ref leak));
}
@test
fn void final_site_uses_live_bit_31_and_builders_reject_capacity_overflow_before_writes(){
 var ir::Program p=program(1,0);p.records.layouts.count=32;var usize i=0;while(i<32){p.records.layouts.fields[i]=1;p.records.layouts.types[i*16]=1;p.records.layouts.kinds[i*16]=0;i+=1;}
 p.records.layouts.types[33]=0;p.records.count=16;i=0;while(i<16){p.records.records[i]=31;p.records.mutable[i]=false;p.record_functions[i]=0;i+=1;}p.record_functions[15]=1;
 p.record_results[0]=15;p.code[1*8+1]=14;p.code[2*8+2]=14;let usize pc=p.starts[1];p.code[pc*8+1]=159;p.code[(pc+1)*8+2]=15;p.code[(pc+2)*8+1]=15;
 assert(verifier::verify(ref p).is_ok);let usize one=1;assert(built(results::call(ref p,0,159,1,0,0))==(one<<31));
 var ir::Program empty=ir::empty();let usize[1] args=[0;1];assert(!ir::record_call(ref mut empty,0,16,ref args[..0],0).is_ok && empty.call_count==0 && empty.count==0);
 let usize[2] bad=[1,256];assert(!ir::record_call(ref mut empty,0,0,ref bad,0).is_ok && empty.call_args[0]==0 && empty.call_count==0);
 empty.count=256;assert(!ir::record_call(ref mut empty,0,0,ref args[..0],0).is_ok && empty.call_count==0);
 empty.count=0;empty.call_count=32;assert(!ir::record_call(ref mut empty,0,0,ref args[..0],0).is_ok && empty.count==0);
}
@test
fn void record_result_execution_checks_verification_before_fuel_and_payload(){
 let ir::Program good=program(1,0);
 assert(switch(vm::run(ref good,1000000)){case .err(_):{false}case .ok(n):{n==42}});
 assert(switch(vm::run_with_array_limit(ref good,0,18446744073709551615)){case .err(e):{e.kind==13 && e.offset==0}case .ok(_):{false}});
 assert(switch(vm::run(ref good,0)){case .err(e):{e.kind==8 && e.offset==0}case .ok(_):{false}});
 var ir::Program p=good;p.record_results[0]=17;assert(switch(vm::run(ref p,0)){case .err(e):{e.kind==5}case .ok(_):{false}});
 p=good;p.code[2*8+4]=1;assert(switch(vm::run(ref p,0)){case .err(e):{e.kind==5}case .ok(_):{false}});
}
