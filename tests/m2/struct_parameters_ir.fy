module tests::m2::struct_parameters_ir;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import struct_parameters as parameters;

fn usize built(Result<usize,errors::Error> r) {return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};}
fn usize cell(ref mut ir::Program p,u8 tag,i64 n) {
 if(tag==2){return built(ir::boolean(p,n!=0,0));}return built(ir::integer(p,n,tag,0));
}
fn void finish(ref mut ir::Program p,usize f) {let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;}
fn ir::Program catalog(u8 tag) {
 var ir::Program p=ir::empty();p.function_count=2;p.entry=1;
 p.return_types[0]=tag;p.return_types[1]=1;
 p.records.layouts.count=2;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=tag;
 p.records.layouts.fields[1]=1;p.records.layouts.types[16]=tag;return p;
}
// Modes cover joins, backedges, recursion, explicit mutable snapshots and rebinds.
fn ir::Program program(u8 tag,u8 mode) {
 var ir::Program p=catalog(tag);p.arities[0]=1;
 let usize parameter=built(ir::record_parameter(ref mut p,0,0,0));
 if(mode==1) {
  let usize cond=cell(ref mut p,2,1);
  let usize branch=built(ir::raw(ref mut p,20,0,cond,4,0));
  let usize left=built(ir::record_drop(ref mut p,parameter,0));
  let usize join=built(ir::raw(ref mut p,19,0,5,0,0));
  let usize right=built(ir::record_drop(ref mut p,parameter,0));
  let usize answer=cell(ref mut p,1,42);let usize ret=built(ir::emit(ref mut p,8,answer,0,0));
 } else if(mode==2) {
  let usize cond=cell(ref mut p,2,1);let usize branch=built(ir::raw(ref mut p,20,0,cond,4,0));
  let usize read=built(ir::record_read(ref mut p,parameter,0,0));
  let usize back=built(ir::raw(ref mut p,22,0,1,0,0));
  let usize drop=built(ir::record_drop(ref mut p,parameter,0));
  let usize answer=cell(ref mut p,1,42);let usize ret=built(ir::emit(ref mut p,8,answer,0,0));
 } else {
  var usize answer=built(ir::record_read(ref mut p,parameter,0,0));
  if(mode==3){let usize[1] args=[144+parameter];answer=built(ir::call(ref mut p,0,ref args,0));}
  let usize drop=built(ir::record_drop(ref mut p,parameter,0));
  if(mode==5){let usize rebound=built(ir::record_init(ref mut p,parameter,answer,0));let usize drop_again=built(ir::record_drop(ref mut p,parameter,0));}
  let usize ret=built(ir::emit(ref mut p,8,answer,0,0));
 }
 finish(ref mut p,0);let usize start=p.count;let usize regs=p.registers;
 p.starts[1]=start;p.register_starts[1]=regs;
 let usize source=built(ir::record_in(ref mut p,1,0,mode==4,0));
 let usize fill=cell(ref mut p,tag,0);let usize init=built(ir::record_init(ref mut p,source,fill,0));
 var usize captured=source;
 if(mode==4){captured=built(ir::record_in(ref mut p,1,0,false,0));let usize copy=built(ir::record_copy(ref mut p,captured,source,0));}
 let usize[1] args=[144+captured];let usize called=built(ir::call(ref mut p,0,ref args,0));
 if(mode==4){let usize drop_copy=built(ir::record_drop(ref mut p,captured,0));}
 let usize drop=built(ir::record_drop(ref mut p,source,0));
 let usize answer=cell(ref mut p,1,42);let usize ret=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,1);return p;
}
fn ir::Program mixed(bool result) {
 var ir::Program p=catalog(1);p.arities[0]=3;
 let usize record=built(ir::record_parameter(ref mut p,0,0,0));
 let usize array=built(ir::array_parameter(ref mut p,0,1,1,0));p.types[2]=1;p.registers=3;
 if(result){p.array_results[0]=1;}
 let usize field=built(ir::record_read(ref mut p,record,0,0));let usize index=cell(ref mut p,12,0);
 let usize element=built(ir::array_read(ref mut p,array,index,0));let usize sum=built(ir::emit(ref mut p,2,field,element,0));
 let usize answer=built(ir::emit(ref mut p,2,sum,2,0));
 let usize drop_record=built(ir::record_drop(ref mut p,record,0));
 if(result){let usize ret=built(ir::array_return(ref mut p,array,0));}
 else{let usize drop_array=built(ir::array_drop(ref mut p,array,0));let usize ret=built(ir::emit(ref mut p,8,answer,0,0));}
 finish(ref mut p,0);let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
 let usize source=built(ir::record_in(ref mut p,1,0,false,0));let usize a=built(ir::array_in(ref mut p,1,1,1,false,0));
 let usize x=cell(ref mut p,1,20);let usize init_record=built(ir::record_init(ref mut p,source,x,0));
 let usize y=cell(ref mut p,1,if(result){42}else{22});let usize init_array=built(ir::array_init(ref mut p,a,y,0));
 let usize zero=cell(ref mut p,1,0);let usize[3] args=[144+source,128+a,zero];
 if(result){let usize dest=built(ir::array_in(ref mut p,1,1,1,false,0));let usize called=built(ir::array_call(ref mut p,0,dest,ref args,0));let usize drop=built(ir::array_drop(ref mut p,dest,0));}
 else{let usize called=built(ir::call(ref mut p,0,ref args,0));}
 let usize drop_array=built(ir::array_drop(ref mut p,a,0));let usize drop_source=built(ir::record_drop(ref mut p,source,0));
 let usize final_answer=cell(ref mut p,1,42);let usize ret=built(ir::emit(ref mut p,8,final_answer,0,0));finish(ref mut p,1);return p;
}
fn bool fails_at(ref ir::Program p,usize pc) {return switch(verifier::verify(p)){case .err(e):{e.kind==5 && e.offset==pc}case .ok(_):{false}};}
fn usize call_pc(ref ir::Program p) {var usize pc=p.starts[1];while(pc<p.ends[1] && p.code[pc*8]!=9){pc+=1;}assert(pc<p.ends[1]);return pc;}
@test
fn void builders_and_metadata_keep_sites_placeholders_and_arrays_independent() {
 let ir::Program good=program(1,0);assert(verifier::verify(ref good).is_ok);
 assert(good.record_parameters[0]==1 && good.types[0]==0 && good.array_parameters[0]==0 && !good.records.mutable[0]);
 var ir::Program p=good;p.record_parameters[127]=1;assert(!verifier::verify(ref p).is_ok);
 p=good;p.record_parameters[0]=17;assert(!verifier::verify(ref p).is_ok);
 p=good;p.record_parameters[1]=1;assert(!verifier::verify(ref p).is_ok);
 p=good;p.record_parameters[0]=0;assert(!verifier::verify(ref p).is_ok);
 p=good;p.types[0]=1;assert(!verifier::verify(ref p).is_ok);
 p=good;p.slots[0]=true;assert(!verifier::verify(ref p).is_ok);
 p=good;p.records.mutable[0]=true;assert(!verifier::verify(ref p).is_ok);
 p=good;p.record_functions[0]=1;assert(!verifier::verify(ref p).is_ok);
 p=mixed(false);p.array_parameters[0]=1;assert(!verifier::verify(ref p).is_ok);
 p=catalog(1);p.registers=128;assert(!ir::record_parameter(ref mut p,0,0,9).is_ok && p.records.count==0 && p.registers==128);
 p=catalog(1);assert(!ir::record_parameter(ref mut p,2,0,9).is_ok && p.records.count==0 && p.registers==0);
 assert(!ir::record_parameter(ref mut p,0,2,9).is_ok && p.records.count==0 && p.registers==0);
}
@test
fn void call_arguments_require_live_immutable_caller_owned_exact_nominal_records() {
 let ir::Program good=program(1,0);let usize pc=call_pc(ref good);var ir::Program p=good;
 let usize site=(good.call_count-1)*8;
 let u8[6] wrong=[0,128,143,144,160,255];var usize i=0;
 while(i<6){p=good;p.call_args[site]=wrong[i];assert(fails_at(ref p,pc));i+=1;}
 p=good;p.records.mutable[1]=true;assert(fails_at(ref p,pc));
 p=good;p.records.records[1]=1;assert(fails_at(ref p,pc));
 p=good;p.record_functions[1]=0;assert(!verifier::verify(ref p).is_ok);
 p=good;p.call_args[site+1]=1;assert(fails_at(ref p,pc));
 p=good;var usize b=0;while(b<8){let u8 saved=p.code[pc*8+b];let u8 following=p.code[(pc+1)*8+b];p.code[pc*8+b]=following;p.code[(pc+1)*8+b]=saved;b+=1;}assert(fails_at(ref p,pc+1));
 let ir::Program captured=program(1,4);assert(verifier::verify(ref captured).is_ok);
}
@test
fn void placeholders_are_never_scalar_operands_or_mutable_record_destinations() {
 let ir::Program good=program(1,0);var ir::Program p=good;
 p.code[0]=2;p.code[2]=0;p.code[3]=0;assert(fails_at(ref p,0));
 p=good;p.code[2*8+2]=0;assert(fails_at(ref p,2));
 p=good;p.code[0]=44;p.code[1]=0;p.code[2]=0;p.code[3]=1;assert(fails_at(ref p,0));
 p=good;p.code[0]=46;p.code[1]=0;p.code[2]=0;p.code[3]=0;assert(fails_at(ref p,0));
 p=good;p.code[0]=48;p.code[1]=0;p.code[2]=1;p.code[3]=0;assert(fails_at(ref p,0));
 let ir::Program rebound=program(1,5);assert(fails_at(ref rebound,2));
}
@test
fn void returns_joins_and_backedges_preserve_parameter_lifetimes() {
 var ir::Program p=program(1,0);p.code[8]=19;p.code[9]=0;p.code[10]=2;p.code[11]=0;assert(fails_at(ref p,2));
 p=program(1,0);p.code[16]=45;p.code[17]=0;p.code[18]=0;p.code[19]=0;assert(fails_at(ref p,2));
 p=program(1,1);assert(verifier::verify(ref p).is_ok);p.code[32]=19;p.code[33]=0;p.code[34]=5;p.code[35]=0;assert(fails_at(ref p,4));
 p=program(1,2);assert(verifier::verify(ref p).is_ok);p.code[16]=45;p.code[17]=0;p.code[18]=0;p.code[19]=0;assert(fails_at(ref p,3));
}
@test
fn void mixed_array_scalar_record_calls_array_results_and_recursion_verify() {
 var ir::Program p=mixed(false);assert(verifier::verify(ref p).is_ok);
 let usize pc=call_pc(ref p);let u8 first=p.call_args[0];let u8 second=p.call_args[1];p.call_args[0]=second;p.call_args[1]=first;assert(fails_at(ref p,pc));
 p=mixed(true);assert(verifier::verify(ref p).is_ok);
 p.code[5*8]=19;p.code[5*8+1]=0;p.code[5*8+2]=6;p.code[5*8+3]=0;assert(fails_at(ref p,6));
 p=program(1,3);assert(verifier::verify(ref p).is_ok && p.call_count==2);
}
@test
fn void last_record_site_and_parameter_register_use_the_high_live_bit() {
 var ir::Program p=catalog(1);p.entry=0;p.arities[1]=8;
 var usize i=0;while(i<15){let usize id=built(ir::record_in(ref mut p,0,0,false,0));i+=1;}
 i=0;while(i<119){let usize value=cell(ref mut p,1,1);i+=1;}
 let usize init=built(ir::record_init(ref mut p,14,0,0));let usize[8] args=[0,0,0,0,0,0,0,158];
 let usize answer=built(ir::call(ref mut p,1,ref args,0));let usize drop=built(ir::record_drop(ref mut p,14,0));let usize ret=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,0);
 let usize start=p.count;p.starts[1]=start;p.register_starts[1]=120;
 i=0;while(i<7){p.types[120+i]=1;i+=1;}p.registers=127;
 let usize parameter=built(ir::record_parameter(ref mut p,1,0,0));assert(parameter==15 && p.record_parameters[127]==16);
 let usize drop_parameter=built(ir::record_drop(ref mut p,parameter,0));let usize returned=built(ir::emit(ref mut p,8,120,0,0));finish(ref mut p,1);
 let usize one=1;assert(parameters::initial(ref p,1)==(one<<31) && verifier::verify(ref p).is_ok);
 p.call_args[7]=159;assert(!verifier::verify(ref p).is_ok);
}
@test
fn void all_scalar_leaf_tags_verify_but_the_vm_refuses_the_unimplemented_abi() {
 let u8[6] tags=[1,2,9,10,11,12];var usize i=0;
 while(i<6){let ir::Program p=program(tags[i],0);assert(verifier::verify(ref p).is_ok);
  assert(switch(vm::run_with_array_limit(ref p,0,18446744073709551615)){case .err(e):{e.kind==11 && e.offset==0}case .ok(_):{false}});
  i+=1;
 }
 var ir::Program bad=program(1,0);bad.record_parameters[0]=17;
 assert(switch(vm::run(ref bad,1000000)){case .err(e):{e.kind==5}case .ok(_):{false}});
}
