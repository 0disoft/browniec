module tests::m2::struct_replace_vm;
import ir as ir;
import vm as vm;
import verifier as verifier;
import array_source as profiles;
import struct_vm as records;
import struct_meta as meta;
import array_vm as arrays;
import array_owners as owners;
import array_layout as layouts;
import errors as errors;
import std::bytes as bytes;

fn usize size(Result<usize, errors::Error> value) {
    return switch (value) { case .ok(n): { n } case .err(_): { assert(false); 0 } };
}
fn usize work(u8 op) { return size(records::cost(op, 0)); }
fn bytes::Buffer payload(usize capacity) {
    return switch (arrays::prepare(capacity)) { case .ok(n): { n } case .err(_): { assert(false); bytes::empty() } };
}
fn meta::Catalog catalog(u8 tag) {
    var meta::Catalog c = meta::empty(); c.count = 2;
    c.layouts.count = 2; c.layouts.fields[0] = 2; c.layouts.kinds[0] = 1; c.layouts.types[0] = 1;
    c.layouts.types[1] = 2; c.layouts.fields[1] = 1; c.layouts.types[16] = tag;
    c.mutable[0] = true; c.mutable[1] = true; return c;
}
fn void step(u8 op, usize dst, usize a, usize b, ref meta::Catalog c,
    ref mut records::State state, ref mut arrays::State shared, ref mut bytes::Buffer data, ref mut i64[] cells) {
    assert(size(records::step(op, dst, a, b, 0, c, state, shared, data, cells, work(op), 123)) == 0);
}
fn bool failure(Result<usize, errors::Error> value, u8 kind) {
    return switch (value) { case .ok(_): { false } case .err(e): { e.kind == kind && e.offset == 123 } };
}
fn void unchanged(ref records::State now, ref records::State before, ref arrays::State shared, ref arrays::State prior) {
    assert(shared.owners.depth == prior.owners.depth && shared.owners.arena.used == prior.owners.arena.used && shared.owners.arena.limit == prior.owners.arena.limit);
    var usize i = 0;
    while (i < 16) {
        assert(now.tokens[i].slot == before.tokens[i].slot && now.tokens[i].generation == before.tokens[i].generation);
        let owners::Owner a = shared.owners.slots[i]; let owners::Owner b = prior.owners.slots[i];
        assert(a.generation == b.generation && a.occupied == b.occupied && a.live == b.live);
        assert(a.mark == b.mark && a.base == b.base && a.end == b.end && a.element == b.element);
        assert(a.length == b.length && a.record == b.record && a.alignment == b.alignment);
        assert(shared.owners.order[i] == prior.owners.order[i]); i += 1;
    }
}

fn void finish(ref mut ir::Program p) {
 let usize count=p.count;let usize registers=p.registers;
 p.function_count=1;p.entry=0;p.starts[0]=0;p.ends[0]=count;
 p.register_starts[0]=0;p.register_ends[0]=registers;p.return_types[0]=1;
}
fn ir::Program basic() {
 var ir::Program p=ir::empty();p.records=catalog(1);p.records.count=1;p.records.mutable[1]=false;
 p.records.layouts.count=3;p.records.layouts.fields[2]=2;p.records.layouts.kinds[32]=1;p.records.layouts.types[32]=1;p.records.layouts.types[33]=2;
 let usize first=size(ir::literal(ref mut p,0,0));let usize zero=size(ir::boolean(ref mut p,false,0));
 let usize init=size(ir::record_init(ref mut p,0,first,0));
 let usize value=size(ir::literal(ref mut p,42,0));let usize flag=size(ir::boolean(ref mut p,true,0));
 let usize replace=size(ir::record_replace(ref mut p,0,value,0,123));
 let usize read=size(ir::record_read(ref mut p,0,0,0));
 let usize drop=size(ir::record_drop(ref mut p,0,0));let usize ret=size(ir::emit(ref mut p,8,read,0,0));
 finish(ref mut p);return p;
}
fn void same_bytes(ref bytes::Buffer data,ref u8[] saved) {
 let ref u8[] view=bytes::view(data);assert(view.len==saved.len);var usize i=0;
 while(i<view.len){assert(view[i]==saved[i]);i+=1;}
}
@test
fn void builder_verifier_and_vm_execute_with_one_root_and_exact_fuel() {
 let ir::Program p=basic();assert(p.records.count==1 && p.registers==5 && p.code[40]==48 && profiles::profile(ref p)==7);
 assert(verifier::verify(ref p).is_ok);
 assert(switch(vm::run_with_array_limit(ref p,133650,8)){case .ok(n):{n==42}case .err(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,133649,8)){case .err(e):{e.kind==8}case .ok(_):{false}});
 assert(switch(vm::run_with_array_limit(ref p,1000000,7)){case .err(e):{e.kind==13}case .ok(_):{false}});
 var ir::Program flat=ir::empty();flat.records.count=1;flat.records.mutable[0]=true;flat.records.layouts.count=1;flat.records.layouts.fields[0]=1;flat.records.layouts.types[0]=1;
 let usize fill=size(ir::literal(ref mut flat,42,0));let usize init=size(ir::record_init(ref mut flat,0,fill,0));
 let usize replace=size(ir::record_replace(ref mut flat,0,fill,0,0));let usize drop=size(ir::record_drop(ref mut flat,0,0));let usize ret=size(ir::emit(ref mut flat,8,fill,0,0));
 finish(ref mut flat);assert(profiles::profile(ref flat)==6 && verifier::verify(ref flat).is_ok);
 assert(switch(vm::run(ref flat,1000000)){case .ok(n):{n==42}case .err(_):{false}});
}
@test
fn void verifier_checks_nominal_identity_types_slots_reserved_bytes_and_liveness() {
 let ir::Program original=basic();var usize i=0;
 while(i<14){var ir::Program p=original;
  if(i==0){p.code[41]=16;}else if(i==1){p.code[42]=128;}
  else if(i==2){p.code[43]=2;}else if(i==3){p.code[43]=32;}
  else if(i<8){p.code[40+i]=1;}
  else if(i==8){p.records.mutable[0]=false;}
  else if(i==9){p.code[42]=4;}
  else if(i==10){p.types[2]=9;}
  else if(i==11){p.slots[2]=true;}
  else if(i==12){p.code[16]=48;}
  else{p.records.count=2;p.records.mutable[1]=true;p.code[41]=1;}
  assert(!verifier::verify(ref p).is_ok);i+=1;
 }
 var ir::Program helper=original;let usize first=helper.registers;let usize start=helper.count;
 let usize n=size(ir::literal(ref mut helper,42,0));let usize flag=size(ir::boolean(ref mut helper,true,0));
 let usize replaced=size(ir::record_replace(ref mut helper,0,n,0,0));let usize ret=size(ir::emit(ref mut helper,8,n,0,0));
 let usize end=helper.count;let usize registers=helper.registers;
 helper.function_count=2;helper.starts[1]=start;helper.ends[1]=end;helper.register_starts[1]=first;helper.register_ends[1]=registers;helper.return_types[1]=1;
 assert(!verifier::verify(ref helper).is_ok);
}
@test
fn void fuel_is_prepaid_and_failed_values_authority_and_metadata_preserve_state() {
 var meta::Catalog c=catalog(1);var records::State s=records::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=payload(64);
 var i64[2] cells=[20,0];step(41,0,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells);
 let records::State before=s;let arrays::State prior=a;
 var u8[64] saved=[0;64];{let ref u8[] view=bytes::view(ref b);var usize i=0;while(i<64){saved[i]=view[i];i+=1;}}
 cells[0]=42;cells[1]=1;assert(work(48)==46145);
 assert(failure(records::step(48,0,0,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells,46144,123),8));
 cells[1]=2;assert(failure(records::step(48,0,0,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells,46145,123),5));cells[1]=1;
 assert(failure(records::step(48,0,0,0,1,ref c,ref mut s,ref mut a,ref mut b,ref mut cells,46145,123),5));
 assert(failure(records::step(48,0,0,1,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells,46145,123),5));
 assert(failure(records::step(48,0,1,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells,46145,123),5));
 assert(failure(records::step(48,16,0,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells,46145,123),5));
 c.mutable[0]=false;assert(failure(records::step(48,0,0,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells,46145,123),5));c.mutable[0]=true;
 s.tokens[0].generation+=1;assert(failure(records::step(48,0,0,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells,46145,123),5));s=before;
 a.owners.slots[s.tokens[0].slot].length+=1;assert(failure(records::step(48,0,0,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells,46145,123),5));a=prior;
 c.layouts.types[511]=1;assert(failure(records::step(48,0,0,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells,46145,123),5));c.layouts.types[511]=0;
 unchanged(ref s,ref before,ref a,ref prior);same_bytes(ref b,ref saved);assert(cells[0]==42 && cells[1]==1);
 assert(size(records::step(48,0,0,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells,46145,123))==0);
 unchanged(ref s,ref before,ref a,ref prior);assert(cells[0]==42 && cells[1]==1);
 var i64[1] out=[0];step(43,0,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut out);assert(out[0]==42);
}
@test
fn void all_scalar_types_replace_nested_values_and_zero_padding() {
 let u8[6] tags=[1,2,9,10,11,12];let i64[6] values=[-2147483648,1,-9223372036854775808,255,4294967295,-1];
 var usize i=0;while(i<6){
  let meta::Catalog c=catalog(tags[i]);var records::State s=records::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=payload(64);
  var i64[3] cells=[0,0,0];step(41,0,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells);
  let records::State before=s;let arrays::State prior=a;
  {let ref mut u8[] view=bytes::view_mut(ref mut b);var usize j=0;while(j<a.owners.arena.used){view[j]=85;j+=1;}}
  cells[0]=values[i];cells[1]=1;step(48,0,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells);
  unchanged(ref s,ref before,ref a,ref prior);
  step(43,2,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells);assert(cells[2]==values[i]);
  {let ref u8[] view=bytes::view(ref b);var usize j=if(tags[i]==1 || tags[i]==11){5}else if(tags[i]==9 || tags[i]==12){9}else{2};while(j<a.owners.arena.used){assert(view[j]==0);j+=1;}}
  i+=1;
 }
}
@test
fn void all_128_leaves_replace_at_full_owner_and_payload_capacity() {
 var meta::Catalog c=meta::empty();c.count=16;c.layouts.count=2;c.layouts.fields[0]=8;c.layouts.fields[1]=16;
 var usize i=0;while(i<16){c.mutable[i]=true;c.layouts.types[16+i]=2;if(i<8){c.layouts.kinds[i]=1;c.layouts.types[i]=1;}i+=1;}
 var records::State s=records::empty();var arrays::State a=arrays::empty(2048);var bytes::Buffer b=payload(2048);var i64[128] cells=[0;128];
 i=0;while(i<16){step(41,i,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells);i+=1;}
 let records::State before=s;let arrays::State prior=a;i=0;while(i<128){cells[i]=1;i+=1;}
 step(48,7,0,0,ref c,ref mut s,ref mut a,ref mut b,ref mut cells);
 unchanged(ref s,ref before,ref a,ref prior);assert(a.owners.depth==16 && a.owners.arena.used==2048);
 let ref u8[] view=bytes::view(ref b);i=0;while(i<2048){assert(view[i]==if(i>=896 && i<1024){1}else{0});i+=1;}
 i=0;while(i<128){assert(cells[i]==1);i+=1;}
}
@test
fn void joins_and_backedges_preserve_scalar_definitions_and_live_owner_sets() {
 var ir::Program p=ir::empty();p.records=catalog(1);p.records.count=1;p.records.mutable[1]=false;
 let usize zero=size(ir::literal(ref mut p,0,0));let usize condition=size(ir::boolean(ref mut p,false,0));
 let usize init=size(ir::record_init(ref mut p,0,zero,0));let usize value=size(ir::literal(ref mut p,42,0));let usize flag=size(ir::boolean(ref mut p,true,0));
 let usize head=p.count;let usize replaced=size(ir::record_replace(ref mut p,0,value,0,123));
 let usize jump=size(ir::raw(ref mut p,20,0,condition,0,0));let usize back=size(ir::raw(ref mut p,22,0,head,0,0));
 let usize target=p.count;let usize patched=size(ir::patch(ref mut p,jump,target,0));let usize read=size(ir::record_read(ref mut p,0,0,0));
 let usize drop=size(ir::record_drop(ref mut p,0,0));let usize ret=size(ir::emit(ref mut p,8,read,0,0));finish(ref mut p);
 assert(verifier::verify(ref p).is_ok);
 assert(switch(vm::run(ref p,1000000)){case .ok(n):{n==42}case .err(_):{false}});
}
