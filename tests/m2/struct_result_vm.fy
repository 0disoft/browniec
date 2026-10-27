module tests::m2::struct_result_vm;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import struct_result_vm as results;
import struct_vm as records;
import array_vm as arrays;
import array_owners as owners;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};}
fn usize cell(ref mut ir::Program p,u8 tag,i64 n){return if(tag==2){built(ir::boolean(p,n==1,0))}else{built(ir::integer(p,n,tag,0))};}
fn void finish(ref mut ir::Program p,usize f){let usize n=p.count;let usize r=p.registers;p.ends[f]=n;p.register_ends[f]=r;}
fn void entry(ref mut ir::Program p){let usize n=p.count;let usize r=p.registers;p.starts[1]=n;p.register_starts[1]=r;}
fn ir::Program base(u8 tag,bool nested){
 var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[1]=1;
 p.records.layouts.count=2;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=tag;
 p.records.layouts.fields[1]=2;p.records.layouts.kinds[16]=1;p.records.layouts.types[16]=0;p.records.layouts.types[17]=2;
 return p;
}
fn void equal(ref mut ir::Program p,usize actual,usize expected){
 let usize same=built(ir::emit(p,11,actual,expected,0));let usize branch=built(ir::raw(p,21,0,same,0,0));
 let usize trap=built(ir::raw(p,25,0,0,0,0));let usize at=p.count;let usize patched=built(ir::patch(p,branch,at,0));
}
fn ir::Program factory(u8 tag,i64 fill,bool nested,bool hole,usize repetitions){
 var ir::Program p=base(tag,nested);let usize nominal=if(nested){1}else{0};
 var usize temporary=0;if(hole){temporary=built(ir::record_in(ref mut p,0,nominal,false,0));}
 let usize source=built(ir::record_in(ref mut p,0,nominal,false,0));p.record_results[0]=if(hole){2}else{1};
 let usize value=cell(ref mut p,tag,fill);if(nested){let usize flag=cell(ref mut p,2,1);}
 if(hole){let usize first=built(ir::record_init(ref mut p,temporary,value,0));}
 let usize init=built(ir::record_init(ref mut p,source,value,0));
 if(hole){let usize drop=built(ir::record_drop(ref mut p,temporary,0));}
 let usize ret=built(ir::record_return(ref mut p,source,73));finish(ref mut p,0);entry(ref mut p);
 let usize dest=built(ir::record_in(ref mut p,1,nominal,true,0));let usize expected=cell(ref mut p,tag,fill);
 let usize[1] args=[0;1];var usize i=0;
 while(i<repetitions){
  let usize call=built(ir::record_call(ref mut p,0,dest,ref args[..0],0));let usize actual=built(ir::record_read(ref mut p,dest,0,0));
  equal(ref mut p,actual,expected);let usize drop=built(ir::record_drop(ref mut p,dest,0));i+=1;
 }
 let usize answer=cell(ref mut p,1,42);let usize done=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,1);return p;
}
fn void value(ref ir::Program p,usize limit,usize fuel){
 assert(verifier::verify(p).is_ok);assert(switch(vm::run_with_array_limit(p,fuel,limit)){case .ok(n):{n==42}case .err(_):{false}});
}
fn void failure(ref ir::Program p,usize limit,usize fuel,u8 kind){
 assert(verifier::verify(p).is_ok);assert(switch(vm::run_with_array_limit(p,fuel,limit)){case .ok(_):{false}case .err(e):{e.kind==kind}});
}
fn bytes::Buffer buffer(usize capacity){return switch(arrays::prepare(capacity)){case .ok(b):{b}case .err(_):{assert(false);bytes::empty()}};}
fn owners::Token create(ref ir::Program p,ref mut arrays::State state,ref mut bytes::Buffer data,usize nominal,ref i64[] fields){
 return switch(owners::create_record(ref p.records.layouts,nominal,fields,bytes::view_mut(data),ref mut state.owners)){
  case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}
 };
}
fn void unchanged(ref arrays::State a,ref arrays::State b,ref records::State r,ref records::State s){
 assert(a.owners.depth==b.owners.depth && a.owners.arena.used==b.owners.arena.used && a.owners.arena.limit==b.owners.arena.limit);
 var usize i=0;while(i<512){assert(a.tokens[i].slot==b.tokens[i].slot && a.tokens[i].generation==b.tokens[i].generation);
  assert(r.tokens[i].slot==s.tokens[i].slot && r.tokens[i].generation==s.tokens[i].generation);i+=1;}
 i=0;while(i<16){assert(a.owners.order[i]==b.owners.order[i]);let owners::Owner x=a.owners.slots[i];let owners::Owner y=b.owners.slots[i];
  assert(x.generation==y.generation && x.occupied==y.occupied && x.live==y.live && x.mark==y.mark && x.base==y.base && x.end==y.end &&
   x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment);i+=1;}
}

@test
fn void six_scalar_edges_and_nested_results_need_only_their_original_extent(){
 let u8[6] tags=[1,2,9,10,11,12];let i64[6] fills=[-2147483648,1,-9223372036854775808,255,4294967295,-1];let usize[6] sizes=[4,1,8,1,4,8];
 var usize i=0;while(i<6){let ir::Program p=factory(tags[i],fills[i],false,false,1);value(ref p,sizes[i],1000000);failure(ref p,sizes[i]-1,1000000,13);
  let ir::Program nested=factory(tags[i],fills[i],true,false,1);let usize n=if(sizes[i]==1){2}else{sizes[i]*2};value(ref nested,n,1000000);i+=1;}
}
@test
fn void repeated_calls_reclaim_returned_extents_and_deferred_callee_holes(){
 let ir::Program p=factory(1,42,false,false,24);value(ref p,4,16000000);value(ref p,4,16000000);
 let ir::Program holes=factory(1,42,false,true,24);value(ref holes,8,16000000);failure(ref holes,7,16000000,13);
}
fn ir::Program recursive(i64 depth){
 var ir::Program p=base(1,false);p.arities[0]=1;p.types[0]=1;p.registers=1;
 let usize local=built(ir::record_in(ref mut p,0,0,false,0));p.record_results[0]=1;
 let usize result=built(ir::record_in(ref mut p,0,0,false,0));let usize zero=cell(ref mut p,1,0);let usize more=built(ir::emit(ref mut p,15,0,zero,0));
 let usize branch=built(ir::raw(ref mut p,20,0,more,0,0));let usize one=cell(ref mut p,1,1);let usize less=built(ir::emit(ref mut p,3,0,one,0));
 let usize[1] child=[less];let usize call=built(ir::record_call(ref mut p,0,result,ref child,0));let usize forwarded=built(ir::record_return(ref mut p,result,0));
 let usize at=p.count;let usize patched=built(ir::patch(ref mut p,branch,at,0));let usize fill=cell(ref mut p,1,42);let usize init=built(ir::record_init(ref mut p,local,fill,0));
 let usize returned=built(ir::record_return(ref mut p,local,0));finish(ref mut p,0);entry(ref mut p);
 let usize dest=built(ir::record_in(ref mut p,1,0,false,0));let usize n=cell(ref mut p,1,depth);let usize[1] args=[n];
 let usize entered=built(ir::record_call(ref mut p,0,dest,ref args,0));let usize actual=built(ir::record_read(ref mut p,dest,0,0));let usize drop=built(ir::record_drop(ref mut p,dest,0));
 let usize done=built(ir::emit(ref mut p,8,actual,0,0));finish(ref mut p,1);return p;
}
@test
fn void recursive_forwarding_uses_one_owner_through_all_32_frames(){
 let ir::Program p=recursive(30);value(ref p,4,16000000);failure(ref p,3,16000000,13);
 let ir::Program over=recursive(31);failure(ref over,4,16000000,12);value(ref p,4,16000000);
}
@test
fn void mixed_arguments_return_an_independent_parameter_into_mutable_caller_storage(){
 var ir::Program p=base(1,false);p.arities[0]=3;
 let usize formal=built(ir::record_parameter(ref mut p,0,0,0));let usize array=built(ir::array_parameter(ref mut p,0,1,1,0));p.types[2]=1;p.registers=3;p.record_results[0]=1;
 let usize drop_array=built(ir::array_drop(ref mut p,array,0));let usize ret=built(ir::record_return(ref mut p,formal,0));finish(ref mut p,0);entry(ref mut p);
 let usize original=built(ir::record_in(ref mut p,1,0,false,0));let usize dest=built(ir::record_in(ref mut p,1,0,true,0));let usize original_array=built(ir::array_in(ref mut p,1,1,1,false,0));
 let usize fill=cell(ref mut p,1,42);let usize init=built(ir::record_init(ref mut p,original,fill,0));let usize init_array=built(ir::array_init(ref mut p,original_array,fill,0));
 let usize[3] args=[144+original,128+original_array,fill];let usize call=built(ir::record_call(ref mut p,0,dest,ref args,0));
 let usize zero=cell(ref mut p,1,0);let usize write=built(ir::record_write(ref mut p,dest,0,zero,0));let usize actual=built(ir::record_read(ref mut p,original,0,0));
 let usize drop_dest=built(ir::record_drop(ref mut p,dest,0));let usize da=built(ir::array_drop(ref mut p,original_array,0));let usize dr=built(ir::record_drop(ref mut p,original,0));
 let usize done=built(ir::emit(ref mut p,8,actual,0,0));finish(ref mut p,1);value(ref p,16,1000000);failure(ref p,15,1000000,13);
}
@test
fn void failed_transfer_preserves_every_token_owner_field_and_payload_byte(){
 let ir::Program good=factory(1,42,true,false,1);var usize mode=0;
 while(mode<18){
  var ir::Program p=good;var arrays::State state=arrays::empty(8);var records::State r=records::empty();var bytes::Buffer data=buffer(8);
  let i64[2] fields=[42,1];let owners::Token t=create(ref p,ref mut state,ref mut data,1,ref fields);r.tokens[16]=t;
  if(mode==0){r.tokens[16].generation+=1;}if(mode==1){r.tokens[1]=t;}if(mode==2){r.tokens[17]=t;}
  if(mode==3){let ref mut u8[] view=bytes::view_mut(ref mut data);view[4]=2;}
  if(mode==4){state.owners.slots[t.slot].record=0;}if(mode==5){state.owners.slots[t.slot].alignment=1;}
  if(mode==6){state.owners.slots[t.slot].length=4;}if(mode==7){state.tokens[16]=t;}
  if(mode==8){r.tokens[1].slot=1;}if(mode==9){r.tokens[17].slot=1;}if(mode==10){state.tokens[16].slot=1;}
  if(mode==11){p.records.records[1]=0;}if(mode==12){p.record_results[0]=0;}
  if(mode==13){state.owners.order[0]=16;}if(mode==14){state.owners.slots[t.slot].live=false;}
  if(mode==15){p.records.layouts.kinds[16]=1;p.records.layouts.types[16]=1;}
  let usize frame=if(mode==16){0}else if(mode==17){32}else{1};
  let arrays::State prior=state;let records::State before=r;var u8[8] saved=[0;8];
  {let ref u8[] view=bytes::view(ref data);var usize i=0;while(i<8){saved[i]=view[i];i+=1;}}
  assert(switch(results::step(ref p,0,0,1,frame,ref mut r,ref state,ref data,results::cost(),73)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==73}});
  unchanged(ref state,ref prior,ref r,ref before);
  {let ref u8[] view=bytes::view(ref data);var usize i=0;while(i<8){assert(view[i]==saved[i]);i+=1;}}
  mode+=1;
 }
}
@test
fn void full_owner_table_and_payload_return_without_copy_or_generation_change(){
 var ir::Program p=factory(1,42,true,false,1);p.records.count=16;var usize i=0;while(i<16){p.records.records[i]=1;i+=1;}
 p.record_functions[15]=1;var arrays::State state=arrays::empty(128);var records::State r=records::empty();var bytes::Buffer data=buffer(128);
 let i64[2] fields=[42,1];var owners::Token last=owners::Token{.slot=0,.generation=0};i=0;
 while(i<16){last=create(ref p,ref mut state,ref mut data,1,ref fields);if(i<15){r.tokens[i]=last;}i+=1;}
 r.tokens[31*16]=last;{let ref mut u8[] view=bytes::view_mut(ref mut data);view[127]=99;}
 let arrays::State prior=state;let records::State before=r;
 assert(built(results::step(ref p,0,0,15,31,ref mut r,ref state,ref data,results::cost()+7,73))==7);
 assert(r.tokens[31*16].generation==0 && r.tokens[30*16+15].slot==last.slot && r.tokens[30*16+15].generation==last.generation);
 var records::State expected=before;expected.tokens[31*16]=owners::Token{.slot=0,.generation=0};expected.tokens[30*16+15]=last;
 unchanged(ref state,ref prior,ref r,ref expected);{let ref u8[] view=bytes::view(ref data);assert(view[127]==99);}
 assert(owners::release(ref mut state.owners,last,128).is_ok);i=15;while(i>0){i-=1;assert(owners::release(ref mut state.owners,r.tokens[i],128).is_ok);}
 assert(state.owners.depth==0 && state.owners.arena.used==0);
}
@test
fn void result_work_is_prepaid_with_exact_vm_fuel_boundaries(){
 let ir::Program p=factory(1,42,false,false,1);assert(results::cost()==42113);
 // Preparation 5, entry/callee constants and CALL 3, SINIT 46145,
 // SRET 42113, read 41281, compare/branch 2, drop 65, final constant/RET 2.
 value(ref p,4,129616);failure(ref p,4,129615,8);
 assert(switch(vm::run_with_array_limit(ref p,88265,4)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==73}});
 var arrays::State state=arrays::empty(0);var records::State r=records::empty();let bytes::Buffer data=bytes::empty();let records::State prior=r;
 assert(switch(results::step(ref p,255,255,255,32,ref mut r,ref state,ref data,42112,73)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==73}});
 unchanged(ref state,ref state,ref r,ref prior);
}
@test
fn void nominal_mismatch_and_array_tokens_cannot_be_returned_as_records(){
 let ir::Program p=factory(1,42,true,false,1);var arrays::State state=arrays::empty(8);var bytes::Buffer data=buffer(8);
 let i64[2] fields=[42,1];let owners::Token t=create(ref p,ref mut state,ref mut data,1,ref fields);
 assert(!owners::validate_record_result(ref p.records.layouts,ref state.owners,t,0,bytes::view(ref data)).is_ok);
 var records::State r=records::empty();r.tokens[16]=t;state.owners.slots[t.slot].element=1;state.owners.slots[t.slot].length=2;state.owners.slots[t.slot].record=0;state.owners.slots[t.slot].alignment=0;
 let arrays::State prior=state;let records::State before=r;
 assert(!results::step(ref p,0,0,1,1,ref mut r,ref state,ref data,results::cost(),73).is_ok);unchanged(ref state,ref prior,ref r,ref before);
}
