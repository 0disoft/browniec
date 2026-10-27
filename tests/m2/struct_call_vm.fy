module tests::m2::struct_call_vm;
import ir as ir;
import errors as errors;
import verifier as verifier;
import vm as vm;
import struct_call_vm as calls;
import array_call_vm as array_calls;
import array_vm as arrays;
import struct_vm as records;
import array_owners as owners;
import array_layout as layouts;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};}
fn usize cell(ref mut ir::Program p,u8 tag,i64 n){if(tag==2){return built(ir::boolean(p,n!=0,0));}return built(ir::integer(p,n,tag,0));}
fn void finish(ref mut ir::Program p,usize f){let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;}
fn void entry(ref mut ir::Program p){let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;}
fn ir::Program base(u8 tag){var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=tag;p.return_types[1]=1;p.records.layouts.count=1;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=tag;return p;}
fn void answer(ref mut ir::Program p,usize actual,usize expected){
 let usize equal=built(ir::emit(p,11,actual,expected,0));let usize yes=cell(p,1,42);let usize no=cell(p,1,0);
 let usize target=p.count+2;let usize branch=built(ir::raw(p,20,0,equal,target,0));let usize ret=built(ir::emit(p,8,yes,0,0));let usize bad=built(ir::emit(p,8,no,0,0));
}
fn ir::Program scalar(u8 tag,i64 value){
 var ir::Program p=base(tag);p.arities[0]=1;let usize formal=built(ir::record_parameter(ref mut p,0,0,0));
 let usize read=built(ir::record_read(ref mut p,formal,0,0));let usize drop=built(ir::record_drop(ref mut p,formal,0));let usize ret=built(ir::emit(ref mut p,8,read,0,0));finish(ref mut p,0);entry(ref mut p);
 let usize source=built(ir::record_in(ref mut p,1,0,false,0));let usize fill=cell(ref mut p,tag,value);let usize init=built(ir::record_init(ref mut p,source,fill,0));
 let usize[1] args=[144+source];var usize got=0;var usize i=0;while(i<3){got=built(ir::call(ref mut p,0,ref args,0));i+=1;}
 let usize original=built(ir::record_read(ref mut p,source,0,0));let usize gone=built(ir::record_drop(ref mut p,source,0));
 answer(ref mut p,got,original);finish(ref mut p,1);return p;
}
fn ir::Program mixed(bool result,u8 tag){
 var ir::Program p=base(1);p.arities[0]=3;
 let usize r=built(ir::record_parameter(ref mut p,0,0,0));let usize a=built(ir::array_parameter(ref mut p,0,tag,1,0));p.types[2]=1;p.registers=3;
 if(result){p.array_results[0]=1;}
 let usize field=built(ir::record_read(ref mut p,r,0,0));let usize index=cell(ref mut p,12,0);let usize element=built(ir::array_read(ref mut p,a,index,0));
 let usize sum=built(ir::emit(ref mut p,2,field,if(tag==2){2}else{element},0));
 let usize drop=built(ir::record_drop(ref mut p,r,0));
 if(result){let usize ret=built(ir::array_return(ref mut p,a,0));}
 else{let usize drop_array=built(ir::array_drop(ref mut p,a,0));let usize ret=built(ir::emit(ref mut p,8,sum,0,0));}
 finish(ref mut p,0);entry(ref mut p);
 let usize source=built(ir::record_in(ref mut p,1,0,false,0));let usize array=built(ir::array_in(ref mut p,1,tag,1,false,0));
 let usize x=cell(ref mut p,1,20);let usize init=built(ir::record_init(ref mut p,source,x,0));let usize y=cell(ref mut p,tag,if(result){42}else if(tag==2){1}else{22});
 let usize init_array=built(ir::array_init(ref mut p,array,y,0));let usize extra=cell(ref mut p,1,22);let usize[3] args=[144+source,128+array,extra];
 var usize got=0;
 if(result){let usize destination=built(ir::array_in(ref mut p,1,tag,1,false,0));let usize call=built(ir::array_call(ref mut p,0,destination,ref args,0));let usize idx=cell(ref mut p,12,0);got=built(ir::array_read(ref mut p,destination,idx,0));let usize gone=built(ir::array_drop(ref mut p,destination,0));}
 else{var usize i=0;while(i<3){got=built(ir::call(ref mut p,0,ref args,0));i+=1;}}
 let usize da=built(ir::array_drop(ref mut p,array,0));let usize dr=built(ir::record_drop(ref mut p,source,0));let usize ret=built(ir::emit(ref mut p,8,got,0,0));finish(ref mut p,1);return p;
}
fn ir::Program recursive(i64 n){
 var ir::Program p=base(1);p.arities[0]=2;let usize r=built(ir::record_parameter(ref mut p,0,0,0));p.types[1]=1;p.registers=2;
 let usize zero=cell(ref mut p,1,0);let usize slot=built(ir::slot(ref mut p,1,0));let usize init=built(ir::raw(ref mut p,18,slot,zero,0,0));let usize more=built(ir::emit(ref mut p,15,1,zero,0));
 let usize branch=built(ir::raw(ref mut p,20,0,more,0,0));let usize one=cell(ref mut p,1,1);let usize smaller=built(ir::emit(ref mut p,3,1,one,0));
 let usize[2] args=[144+r,smaller];let usize child=built(ir::call(ref mut p,0,ref args,0));let usize save=built(ir::raw(ref mut p,18,slot,child,0,0));let usize target=p.count;let usize patched=built(ir::patch(ref mut p,branch,target,0));
 let usize own=built(ir::record_read(ref mut p,r,0,0));let usize loaded=built(ir::emit(ref mut p,17,slot,0,0));let usize total=built(ir::emit(ref mut p,2,own,loaded,0));let usize drop=built(ir::record_drop(ref mut p,r,0));let usize ret=built(ir::emit(ref mut p,8,total,0,0));finish(ref mut p,0);entry(ref mut p);
 let usize source=built(ir::record_in(ref mut p,1,0,false,0));let usize fill=cell(ref mut p,1,7);let usize count=cell(ref mut p,1,n);let usize create=built(ir::record_init(ref mut p,source,fill,0));
 let usize[2] root=[144+source,count];let usize got=built(ir::call(ref mut p,0,ref root,0));let usize dr=built(ir::record_drop(ref mut p,source,0));let usize end=built(ir::emit(ref mut p,8,got,0,0));finish(ref mut p,1);return p;
}
fn void success(ref ir::Program p,usize limit,i64 expected){assert(verifier::verify(p).is_ok);assert(switch(vm::run_with_array_limit(p,4000000,limit)){case .ok(n):{n==expected}case .err(_):{false}});}
fn bool failed(Result<usize,errors::Error> r,u8 kind){return switch(r){case .err(e):{e.kind==kind && e.offset==77}case .ok(_):{false}};}
fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}};}
fn bytes::Buffer buffer(){return switch(arrays::prepare(128)){case .ok(b):{b}case .err(_):{assert(false);bytes::empty()}};}
fn void sources(ref ir::Program p,ref mut records::State rs,ref mut arrays::State state,ref mut bytes::Buffer b){
 let ref mut u8[] data=bytes::view_mut(b);let i64[1] fields=[20];rs.tokens[1]=token(owners::create_record(ref p.records.layouts,0,ref fields,data,ref mut state.owners));
 let layouts::Array a=switch(layouts::scalar(p.arrays.elements[1],1)){case .ok(x):{x}case .err(_):{assert(false);layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}};
 let i64 fill=if(a.element==2){1}else{22};let owners::Token t=token(owners::create(ref a,fill,data,ref mut state.owners));state.tokens[1]=t;
}
fn void same(ref arrays::State a,ref arrays::State before,ref records::State r,ref records::State rb,ref u8[] data,ref u8[] old){
 assert(a.owners.depth==before.owners.depth && a.owners.arena.used==before.owners.arena.used && a.owners.arena.limit==before.owners.arena.limit);
 var usize i=0;while(i<512){assert(a.tokens[i].slot==before.tokens[i].slot && a.tokens[i].generation==before.tokens[i].generation);assert(r.tokens[i].slot==rb.tokens[i].slot && r.tokens[i].generation==rb.tokens[i].generation);i+=1;}
 i=0;while(i<16){let owners::Owner x=a.owners.slots[i];let owners::Owner y=before.owners.slots[i];assert(a.owners.order[i]==before.owners.order[i]);assert(x.generation==y.generation && x.occupied==y.occupied && x.live==y.live);assert(x.base==y.base && x.end==y.end && x.mark==y.mark);assert(x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment);i+=1;}
 assert(data.len==old.len);i=0;while(i<data.len){assert(data[i]==old[i]);i+=1;}
}
@test
fn void all_scalar_record_bits_survive_repeated_calls_and_parameter_drops(){
 let u8[6] tags=[1,2,9,10,11,12];let i64[6] values=[-2147483648,1,-9223372036854775808,255,4294967295,-1];var usize i=0;
 while(i<6){let ir::Program p=scalar(tags[i],values[i]);success(ref p,32,42);i+=1;}
}
@test
fn void mixed_calls_scalar_results_and_array_owner_returns_execute(){
 let ir::Program p=mixed(false,1);success(ref p,32,42);let ir::Program b=mixed(false,2);success(ref b,32,42);let ir::Program r=mixed(true,1);success(ref r,32,42);
}
@test
fn void recursive_record_frames_keep_sources_live_and_share_owner_and_payload_limits(){
 let ir::Program p=recursive(5);success(ref p,64,42);let ir::Program full=recursive(14);success(ref full,64,105);
 let ir::Program too_many=recursive(15);assert(verifier::verify(ref too_many).is_ok);
 assert(switch(vm::run_with_array_limit(ref too_many,4000000,128)){case .err(e):{e.kind==13}case .ok(_):{false}});
 assert(switch(vm::run_with_array_limit(ref full,4000000,63)){case .err(e):{e.kind==13}case .ok(_):{false}});
}
@test
fn void exact_fuel_prepays_both_kinds_before_any_token_or_payload_mutation(){
 let ir::Program p=mixed(false,1);assert(verifier::verify(ref p).is_ok);let usize charged=4+built(calls::cost(ref p,0,77));
 assert(built(calls::cost(ref p,0,77))==2048+43008+built(array_calls::cost(ref p,0,77)));
 var arrays::State a=arrays::empty(128);var records::State r=records::empty();var bytes::Buffer b=buffer();sources(ref p,ref mut r,ref mut a,ref mut b);
 let arrays::State before=a;let records::State rb=r;var u8[128] old=[0;128];let ref u8[] view=bytes::view(ref b);var usize i=0;while(i<128){old[i]=view[i];i+=1;}
 assert(failed(calls::step(ref p,0,0,0,ref mut r,ref mut a,ref mut b,charged-1,77),8));same(ref a,ref before,ref r,ref rb,bytes::view(ref b),ref old);
 assert(built(calls::step(ref p,0,0,0,ref mut r,ref mut a,ref mut b,charged,77))==0);
 assert(a.owners.depth==4 && a.owners.arena.used==16 && a.tokens[16].generation!=0 && r.tokens[16].generation!=0);
 assert(a.tokens[1].generation==before.tokens[1].generation && r.tokens[1].generation==rb.tokens[1].generation);
}
@test
fn void late_bad_bool_and_quota_failures_preserve_both_token_tables_and_all_bytes(){
 let ir::Program p=mixed(false,2);assert(verifier::verify(ref p).is_ok);
 var arrays::State a=arrays::empty(128);var records::State r=records::empty();var bytes::Buffer b=buffer();sources(ref p,ref mut r,ref mut a,ref mut b);
 let arrays::State before=a;let records::State rb=r;var u8[128] old=[0;128];var usize i=0;
 {let ref mut u8[] data=bytes::view_mut(ref mut b);data[4]=2;while(i<128){old[i]=data[i];i+=1;}}
 assert(failed(calls::step(ref p,0,0,0,ref mut r,ref mut a,ref mut b,1000000,77),5));same(ref a,ref before,ref r,ref rb,bytes::view(ref b),ref old);
 {let ref mut u8[] data=bytes::view_mut(ref mut b);data[4]=1;}a.owners.arena.limit=9;let arrays::State small=a;old[4]=1;
 // Prefix5 -> record at8..12 cannot fit, and the later array is never published.
 assert(failed(calls::step(ref p,0,0,0,ref mut r,ref mut a,ref mut b,1000000,77),13));same(ref a,ref small,ref r,ref rb,bytes::view(ref b),ref old);
}
@test
fn void stale_sources_dirty_child_slots_and_frame_admission_fail_without_publication(){
 let ir::Program p=mixed(false,1);var arrays::State a=arrays::empty(128);var records::State r=records::empty();var bytes::Buffer b=buffer();sources(ref p,ref mut r,ref mut a,ref mut b);
 r.tokens[1].generation+=1;let arrays::State before=a;let records::State rb=r;var u8[128] old=[0;128];let ref u8[] data=bytes::view(ref b);var usize i=0;while(i<128){old[i]=data[i];i+=1;}
 assert(failed(calls::step(ref p,0,0,0,ref mut r,ref mut a,ref mut b,1000000,77),5));same(ref a,ref before,ref r,ref rb,bytes::view(ref b),ref old);
 r.tokens[1].generation-=1;let owners::Token live=r.tokens[1];r.tokens[31]=live;let records::State dirty=r;
 assert(failed(calls::step(ref p,0,0,0,ref mut r,ref mut a,ref mut b,1000000,77),5));same(ref a,ref before,ref r,ref dirty,bytes::view(ref b),ref old);
 assert(failed(calls::step(ref p,0,0,31,ref mut r,ref mut a,ref mut b,1000000,77),12));same(ref a,ref before,ref r,ref dirty,bytes::view(ref b),ref old);
 assert(failed(calls::step(ref p,0,0,31,ref mut r,ref mut a,ref mut b,0,77),8));
}
@test
fn void eight_record_formals_use_the_last_site_and_full_owner_capacity(){
 var ir::Program p=base(9);p.arities[0]=8;p.records.layouts.fields[0]=16;var usize i=0;while(i<16){p.records.layouts.types[i]=9;i+=1;}
 i=0;while(i<8){let usize id=built(ir::record_parameter(ref mut p,0,0,0));i+=1;}
 let usize field=built(ir::record_read(ref mut p,7,15,0));i=8;while(i>0){i-=1;let usize drop=built(ir::record_drop(ref mut p,i,0));}
 let usize ret=built(ir::emit(ref mut p,8,field,0,0));finish(ref mut p,0);entry(ref mut p);
 let usize first=p.registers;i=0;while(i<16){let usize fill=cell(ref mut p,9,42);i+=1;}
 var usize[8] args=[0;8];i=0;while(i<8){let usize id=built(ir::record_in(ref mut p,1,0,false,0));let usize init=built(ir::record_init(ref mut p,id,first,0));args[i]=144+id;i+=1;}
 let usize got=built(ir::call(ref mut p,0,ref args,0));i=16;while(i>8){i-=1;let usize drop=built(ir::record_drop(ref mut p,i,0));}answer(ref mut p,got,first);finish(ref mut p,1);
 success(ref p,2048,42);assert(switch(vm::run_with_array_limit(ref p,4000000,2047)){case .err(e):{e.kind==13}case .ok(_):{false}});
}
@test
fn void scalar_only_prices_stay_exact_and_malformed_record_metadata_fails_first(){
 var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;let usize n=cell(ref mut p,1,42);let usize ret=built(ir::emit(ref mut p,8,n,0,0));finish(ref mut p,0);assert(built(calls::cost(ref p,0,0))==0);
 assert(switch(vm::run(ref p,2)){case .ok(n):{n==42}case .err(_):{false}});
 p=scalar(1,42);p.record_parameters[0]=17;assert(switch(vm::run_with_array_limit(ref p,0,18446744073709551615)){case .err(e):{e.kind==5}case .ok(_):{false}});
}
