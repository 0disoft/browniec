module tests::m2::struct_function_vm;
import ir as ir;
import vm as vm;
import verifier as verifier;
import struct_vm as records;
import struct_meta as meta;
import array_vm as arrays;
import array_owners as owners;
import array_layout as layouts;
import errors as errors;
import std::bytes as bytes;
import std::num as num;

fn i64 wide(usize n) {
 return switch(num::i64_from_usize(n)){case .ok(n):{n}case .err(_):{assert(false);0}};
}
fn u8 small(usize n) {
 return switch(num::u8_from_i64(wide(n))){case .ok(n):{n}case .err(_):{assert(false);0}};
}

fn usize built(Result<usize,errors::Error> r) {
 return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};
}
fn bool failed(Result<usize,errors::Error> r,u8 kind) {
 return switch(r){case .err(e):{e.kind==kind && e.offset==123}case .ok(_):{false}};
}
fn bytes::Buffer payload(usize size) {
 return switch(arrays::prepare(size)){case .ok(b):{b}case .err(_):{assert(false);bytes::empty()}};
}
fn meta::Catalog catalog() {
 var meta::Catalog c=meta::empty();c.count=2;c.mutable[0]=true;c.mutable[1]=true;
 c.layouts.count=2;c.layouts.fields[0]=2;c.layouts.types[0]=1;c.layouts.kinds[1]=1;
 c.layouts.types[1]=1;c.layouts.fields[1]=1;c.layouts.types[16]=1;return c;
}
fn Result<usize,errors::Error> perform(u8 op,usize dst,usize a,usize b,usize frame,
 ref meta::Catalog c,ref mut records::State s,ref mut arrays::State shared,
 ref mut bytes::Buffer data,ref mut i64[] cells,usize fuel) {
 if(op==47){return records::subassign(dst,a,1,1,1,frame,c,s,shared,data,fuel,123);}
 if(op==49){return records::subreplace(dst,a,1,1,frame,c,s,shared,data,cells,fuel,123);}
 return records::step(op,dst,a,b,frame,c,s,shared,data,cells,fuel,123);
}
fn void step(u8 op,usize dst,usize a,usize b,usize frame,ref meta::Catalog c,
 ref mut records::State s,ref mut arrays::State shared,ref mut bytes::Buffer data,ref mut i64[] cells) {
 assert(built(perform(op,dst,a,b,frame,c,s,shared,data,cells,built(records::cost(op,0))))==0);
}
fn void same(ref records::State s,ref records::State before,ref arrays::State a,ref arrays::State old) {
 var usize i=0;while(i<512){
  assert(s.tokens[i].slot==before.tokens[i].slot && s.tokens[i].generation==before.tokens[i].generation);i+=1;
 }
 assert(a.owners.depth==old.owners.depth && a.owners.arena.used==old.owners.arena.used);
 i=0;while(i<16){
  let owners::Owner x=a.owners.slots[i];let owners::Owner y=old.owners.slots[i];
  assert(x.generation==y.generation && x.occupied==y.occupied && x.live==y.live);
  assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element);
  assert(x.length==y.length && x.record==y.record && x.alignment==y.alignment && a.owners.order[i]==old.owners.order[i]);i+=1;
 }
}
@test
fn void every_opcode_addresses_frame_zero_one_and_thirty_one_independently() {
 let meta::Catalog c=catalog();var records::State s=records::empty();var arrays::State a=arrays::empty(128);
 var bytes::Buffer data=payload(128);var i64[4] cells=[20,22,42,0];let usize[3] frames=[0,1,31];
 var usize i=0;while(i<3){let usize f=frames[i];cells[0]=20+wide(i);cells[1]=22+wide(i);cells[2]=42+wide(i);
  step(41,0,0,0,f,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
  step(42,1,0,0,f,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
  step(44,0,1,2,f,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
  step(46,0,1,0,f,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
  step(47,0,1,0,f,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
  step(48,0,0,0,f,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
  step(49,0,2,0,f,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);i+=1;
 }
 assert(a.owners.depth==6 && a.owners.arena.used==48);
 i=3;while(i>0){i-=1;let usize f=frames[i];
  step(43,3,0,1,f,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);assert(cells[3]==42+wide(i));
  step(43,3,1,1,f,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);assert(cells[3]==22+wide(i));
  step(45,1,0,0,f,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
  step(45,0,0,0,f,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
 }
 assert(a.owners.depth==0 && a.owners.arena.used==0 && s.tokens[496].generation==0);
 step(41,0,0,0,31,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
 assert(s.tokens[496].generation==2 && s.tokens[0].generation==0);
}
@test
fn void prepayment_invalid_frames_and_foreign_dead_bindings_preserve_every_frame() {
 let meta::Catalog c=catalog();var records::State s=records::empty();var arrays::State a=arrays::empty(128);
 var bytes::Buffer data=payload(128);var i64[4] cells=[20,22,42,-7];
 step(41,0,0,0,0,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
 let records::State before=s;let arrays::State old=a;var u8[128] saved=[0;128];
 {let ref u8[] view=bytes::view(ref data);var usize i=0;while(i<128){saved[i]=view[i];i+=1;}}
 let u8[9] ops=[41,42,43,44,45,46,47,48,49];var usize i=0;
 while(i<9){let u8 op=ops[i];let usize fuel=built(records::cost(op,0));
  assert(failed(perform(op,0,0,0,31,ref c,ref mut s,ref mut a,ref mut data,ref mut cells,fuel-1),8));
  assert(failed(perform(op,0,0,0,32,ref c,ref mut s,ref mut a,ref mut data,ref mut cells,fuel),5));
  assert(failed(perform(op,0,0,0,18446744073709551615,ref c,ref mut s,ref mut a,ref mut data,ref mut cells,fuel),5));
  if(op!=41){assert(failed(perform(op,0,0,0,1,ref c,ref mut s,ref mut a,ref mut data,ref mut cells,fuel),5));}
  same(ref s,ref before,ref a,ref old);assert(cells[0]==20 && cells[1]==22 && cells[2]==42 && cells[3]==-7);i+=1;
 }
 {let ref u8[] view=bytes::view(ref data);i=0;while(i<128){assert(view[i]==saved[i]);i+=1;}}
}
@test
fn void mixed_array_record_owners_and_payload_limits_are_shared_across_frames() {
 let meta::Catalog c=catalog();var records::State s=records::empty();var arrays::State a=arrays::empty(256);
 var bytes::Buffer data=payload(256);var i64[4] cells=[20,22,42,0];
 let layouts::Array shape=switch(layouts::scalar(10,1)){case .ok(x):{x}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};
 let owners::Token array=switch(owners::create(ref shape,1,bytes::view_mut(ref mut data),ref mut a.owners)){
  case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}};
 var usize i=0;while(i<15){step(41,0,0,0,i,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);i+=1;}
 let records::State before=s;let arrays::State old=a;
 assert(failed(perform(41,0,0,0,15,ref c,ref mut s,ref mut a,ref mut data,ref mut cells,built(records::cost(41,0))),13));
 same(ref s,ref before,ref a,ref old);
 while(i>0){i-=1;step(45,0,0,0,i,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);}
 let usize released=switch(owners::release(ref mut a.owners,array,256)){case .ok(n):{n}case .err(_):{assert(false);0}};
 assert(a.owners.depth==0 && a.owners.arena.used==0);
 a=arrays::empty(15);data=payload(15);
 step(41,0,0,0,0,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
 let records::State full=s;let arrays::State prior=a;
 assert(failed(perform(41,0,0,0,1,ref c,ref mut s,ref mut a,ref mut data,ref mut cells,built(records::cost(41,0))),13));
 same(ref s,ref full,ref a,ref prior);
}
@test
fn void stale_child_tokens_cannot_resolve_after_frame_slot_reuse() {
 let meta::Catalog c=catalog();var records::State s=records::empty();var arrays::State a=arrays::empty(32);
 var bytes::Buffer data=payload(32);var i64[4] cells=[20,22,42,-7];
 step(41,0,0,0,0,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
 step(41,0,0,0,1,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);let owners::Token stale=s.tokens[16];
 step(45,0,0,0,1,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
 step(41,0,0,0,1,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);let owners::Token fresh=s.tokens[16];
 assert(fresh.generation!=stale.generation);s.tokens[16]=stale;
 assert(failed(perform(43,3,0,1,1,ref c,ref mut s,ref mut a,ref mut data,ref mut cells,built(records::cost(43,0))),5));
 assert(cells[3]==-7);step(43,3,0,1,0,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);assert(cells[3]==22);
 s.tokens[16]=fresh;step(45,0,0,0,1,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);
 step(45,0,0,0,0,ref c,ref mut s,ref mut a,ref mut data,ref mut cells);assert(a.owners.depth==0);
}
fn void finish(ref mut ir::Program p,usize f) {
 let usize end=p.count;let usize registers=p.registers;p.ends[f]=end;p.register_ends[f]=registers;
}
fn ir::Program recursive(i64 depth,bool hold,usize repeats) {
 var ir::Program p=ir::empty();p.function_count=2;p.return_types[0]=1;p.return_types[1]=1;p.arities[1]=1;
 p.records.layouts.count=1;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=1;
 let usize record=built(ir::record_in(ref mut p,1,0,true,0));let usize n=built(ir::literal(ref mut p,depth,0));
 let usize[1] args=[n];var usize called=0;var usize i=0;
 while(i<repeats){called=built(ir::call(ref mut p,1,ref args,0));i+=1;}
 let usize ret=built(ir::emit(ref mut p,8,called,0,0));finish(ref mut p,0);
 let usize start=p.count;let usize parameter=p.registers;p.starts[1]=start;p.register_starts[1]=parameter;
 p.types[parameter]=1;p.registers+=1;
 let usize init=built(ir::record_init(ref mut p,record,parameter,0));let usize zero=built(ir::literal(ref mut p,0,0));
 let usize condition=built(ir::emit(ref mut p,11,parameter,zero,0));var usize saved=0;
 if(!hold){saved=built(ir::record_read(ref mut p,record,0,0));let usize drop=built(ir::record_drop(ref mut p,record,0));}
 let usize guard=built(ir::raw(ref mut p,20,0,condition,0,0));
 let usize base=if(hold){built(ir::record_read(ref mut p,record,0,0))}else{saved};
 if(hold){let usize drop=built(ir::record_drop(ref mut p,record,0));}
 let usize returned=built(ir::emit(ref mut p,8,base,0,0));let usize target=p.count;p.code[guard*8+3]=small(target);
 let usize one=built(ir::literal(ref mut p,1,0));let usize lower=built(ir::emit(ref mut p,3,parameter,one,0));
 let usize[1] child_args=[lower];let usize child=built(ir::call(ref mut p,1,ref child_args,0));
 let usize own=if(hold){built(ir::record_read(ref mut p,record,0,0))}else{saved};
 let usize total=built(ir::emit(ref mut p,2,own,child,0));
 if(hold){let usize drop=built(ir::record_drop(ref mut p,record,0));}
 let usize end=built(ir::emit(ref mut p,8,total,0,0));finish(ref mut p,1);return p;
}
fn void result(ref ir::Program p,usize fuel,usize capacity,i64 expected) {
 assert(verifier::verify(p).is_ok);
 assert(switch(vm::run_with_array_limit(p,fuel,capacity)){case .ok(n):{n==expected}case .err(_):{false}});
}
fn void trap(ref ir::Program p,usize fuel,usize capacity,u8 kind) {
 assert(verifier::verify(p).is_ok);
 assert(switch(vm::run_with_array_limit(p,fuel,capacity)){case .err(e):{e.kind==kind}case .ok(_):{false}});
}
@test
fn void recursive_records_preserve_parent_values_and_exact_fuel_payload_and_owner_bounds() {
 let ir::Program p=recursive(15,true,1);result(ref p,1400064,64,120);trap(ref p,1400063,64,8);trap(ref p,4000000,63,13);
 let ir::Program overflow=recursive(16,true,1);trap(ref overflow,4000000,68,13);
 let ir::Program repeated=recursive(15,true,3);result(ref repeated,5000000,64,120);
}
@test
fn void released_records_allow_all_32_frames_then_fail_at_the_call_depth_limit() {
 let ir::Program p=recursive(30,false,1);result(ref p,4000000,4,465);
 let ir::Program overflow=recursive(31,false,1);trap(ref overflow,4000000,4,12);
 let ir::Program repeated=recursive(30,false,3);result(ref repeated,10000000,4,465);
}
@test
fn void helper_record_cleanup_allows_array_result_transfer_beside_a_live_parent_record() {
 var ir::Program p=ir::empty();p.function_count=2;p.return_types[0]=1;p.return_types[1]=1;
 p.records.layouts.count=1;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=1;
 let usize parent=built(ir::record_in(ref mut p,0,0,false,0));let usize local=built(ir::record_in(ref mut p,1,0,false,0));
 let usize destination=built(ir::array_in(ref mut p,0,1,1,false,0));let usize source=built(ir::array_in(ref mut p,1,1,1,false,0));
 p.array_results[1]=small(source+1);
 let usize n=built(ir::literal(ref mut p,42,0));let usize init=built(ir::record_init(ref mut p,parent,n,0));
 let usize[1] args=[0];let usize call=built(ir::array_call(ref mut p,1,destination,ref args[..0],0));
 let usize index=built(ir::integer(ref mut p,0,12,0));let usize read=built(ir::array_read(ref mut p,destination,index,0));
 let usize drop=built(ir::array_drop(ref mut p,destination,0));let usize own=built(ir::record_read(ref mut p,parent,0,0));
 let usize gone=built(ir::record_drop(ref mut p,parent,0));let usize equal=built(ir::emit(ref mut p,11,read,own,0));
 let usize answer=built(ir::literal(ref mut p,42,0));let usize no=built(ir::literal(ref mut p,0,0));let usize target=p.count+2;let usize branch=built(ir::raw(ref mut p,20,0,equal,target,0));
 let usize ret=built(ir::emit(ref mut p,8,answer,0,0));let usize fail=built(ir::emit(ref mut p,8,no,0,0));finish(ref mut p,0);
 let usize start=p.count;let usize registers=p.registers;p.starts[1]=start;p.register_starts[1]=registers;
 let usize value=built(ir::literal(ref mut p,42,0));let usize root=built(ir::record_init(ref mut p,local,value,0));
 let usize fill=built(ir::record_read(ref mut p,local,0,0));let usize array=built(ir::array_init(ref mut p,source,fill,0));
 let usize dropped=built(ir::record_drop(ref mut p,local,0));let usize returned=built(ir::array_return(ref mut p,source,0));finish(ref mut p,1);
 result(ref p,1000000,12,42);trap(ref p,1000000,11,13);
}
