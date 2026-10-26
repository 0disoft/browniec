module tests::m2::struct_atomic_source;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
import struct_vm as records;
import struct_meta as meta;
import array_vm as arrays;
import std::bytes as bytes;
import errors as errors;
fn usize size(Result<usize,errors::Error> r) {
 return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};
}
fn ir::Program compiled() {
 return switch(compiler::compile(b"module main;struct I{i32 x;}struct J{i32 x;}struct R{I i;}fn i32 main(){let R q=R{.i=I{.x=42}};var R p=R{.i=I{.x=0}};p.i=q.i;return p.i.x;}")){
  case .ok(p):{p}case .err(_):{assert(false);ir::empty()}
 };
}
fn meta::Catalog catalog() {
 var meta::Catalog c=meta::empty();c.count=2;c.mutable[0]=true;
 c.layouts.count=2;c.layouts.fields[0]=1;c.layouts.kinds[0]=1;c.layouts.types[0]=1;
 c.layouts.fields[1]=2;c.layouts.types[16]=9;c.layouts.types[17]=2;return c;
}
fn bytes::Buffer payload() {
 return switch(arrays::prepare(64)){case .ok(b):{b}case .err(_):{assert(false);bytes::empty()}};
}
fn void init(ref meta::Catalog c,ref mut records::State s,ref mut arrays::State a,ref mut bytes::Buffer b) {
 var i64[2] values=[42,1];
 assert(size(records::step(41,1,0,0,0,c,s,a,b,ref mut values,46145,123))==0);
 values[0]=0;values[1]=0;
 assert(size(records::step(41,0,0,0,0,c,s,a,b,ref mut values,46145,123))==0);
}
fn void unchanged(ref bytes::Buffer b,ref u8[] before,ref records::State s,ref records::State prior,
    ref arrays::State a,ref arrays::State old) {
 let ref u8[] data=bytes::view(b);var usize i=0;
 while(i<64){assert(data[i]==before[i]);i+=1;}
 assert(a.owners.depth==old.owners.depth && a.owners.arena.used==old.owners.arena.used && a.owners.arena.limit==old.owners.arena.limit);
 i=0;while(i<16){
  assert(s.tokens[i].slot==prior.tokens[i].slot && s.tokens[i].generation==prior.tokens[i].generation);
  assert(a.owners.order[i]==old.owners.order[i]);
  assert(a.owners.slots[i].generation==old.owners.slots[i].generation && a.owners.slots[i].live==old.owners.slots[i].live);
  assert(a.owners.slots[i].base==old.owners.slots[i].base && a.owners.slots[i].end==old.owners.slots[i].end);i+=1;
 }
}
@test
fn void frontend_uses_one_copy_without_scalar_snapshot_registers() {
 let ir::Program p=compiled();assert(verifier::verify(ref p).is_ok);
 var usize pc=0;var usize copies=0;while(pc<p.count){if(p.code[pc*8]==47){copies+=1;}pc+=1;}
 assert(copies==1 && p.registers==7 && p.records.count==2);
 assert(switch(vm::run_with_array_limit(ref p,1000000,8)){case .ok(n):{n==42}case .err(_):{false}});
}
@test
fn void verifier_rejects_bad_nominal_ranges_operands_liveness_and_mutability() {
 let ir::Program original=compiled();var usize pc=0;while(pc<original.count && original.code[pc*8]!=47){pc+=1;}
 assert(pc<original.count);let usize at=pc*8;var usize i=0;
 while(i<11){var ir::Program p=original;
  if(i==0){p.code[at+1]=16;}else if(i==1){p.code[at+2]=16;}
  else if(i==2){p.code[at+3]=1;}else if(i==3){p.code[at+3]=32;}
  else if(i==4){p.code[at+4]=1;}else if(i==5){p.code[at+5]=1;}
  else if(i==6){p.code[at+6]=1;}else if(i==7){p.code[at+7]=1;}
  else if(i==8){p.records.mutable[1]=false;}
  else {p.records.count=3;p.records.records[2]=2;p.records.mutable[2]=true;
   if(i==9){p.code[at+1]=2;}else{p.code[at+2]=2;}}
  assert(!verifier::verify(ref p).is_ok);i+=1;
 }
}
@test
fn void full_fuel_is_prepaid_and_one_less_preserves_bytes_and_owners() {
 let meta::Catalog c=catalog();var records::State s=records::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=payload();
 init(ref c,ref mut s,ref mut a,ref mut b);let records::State prior=s;let arrays::State old=a;
 var u8[64] before=[0;64];{let ref u8[] data=bytes::view(ref b);var usize i=0;while(i<64){before[i]=data[i];i+=1;}}
 assert(switch(records::subassign(0,1,1,0,0,0,ref c,ref mut s,ref mut a,ref mut b,131071,123)){case .err(e):{e.kind==8 && e.offset==123}case .ok(_):{false}});
 unchanged(ref b,ref before,ref s,ref prior,ref a,ref old);
 assert(size(records::subassign(0,1,1,0,0,0,ref c,ref mut s,ref mut a,ref mut b,131072,123))==0);
 var i64[1] value=[0;1];let usize read=size(records::step(43,0,0,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut value,41281,123));
 assert(value[0]==42 && s.tokens[0].generation==prior.tokens[0].generation && a.owners.arena.used==32);
}
@test
fn void invalid_bool_ranges_frame_and_authority_fail_before_commit() {
 var meta::Catalog c=catalog();var records::State s=records::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=payload();
 init(ref c,ref mut s,ref mut a,ref mut b);let records::State prior=s;let arrays::State old=a;
 var u8[64] before=[0;64];{let ref u8[] data=bytes::view(ref b);var usize i=0;while(i<64){before[i]=data[i];i+=1;}}
 assert(!records::subassign(0,1,1,1,0,0,ref c,ref mut s,ref mut a,ref mut b,131072,123).is_ok);
 assert(!records::subassign(0,1,1,0,0,1,ref c,ref mut s,ref mut a,ref mut b,131072,123).is_ok);
 c.mutable[0]=false;assert(!records::subassign(0,1,1,0,0,0,ref c,ref mut s,ref mut a,ref mut b,131072,123).is_ok);c.mutable[0]=true;
 s.tokens[1].generation+=1;assert(!records::subassign(0,1,1,0,0,0,ref c,ref mut s,ref mut a,ref mut b,131072,123).is_ok);s=prior;
 unchanged(ref b,ref before,ref s,ref prior,ref a,ref old);
 {let ref mut u8[] data=bytes::view_mut(ref mut b);data[8]=2;before[8]=2;}
 assert(!records::subassign(0,1,1,0,0,0,ref c,ref mut s,ref mut a,ref mut b,131072,123).is_ok);
 unchanged(ref b,ref before,ref s,ref prior,ref a,ref old);
}
