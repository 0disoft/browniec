module tests::m2::runtime_output_chunks;
import runtime_output as o;import fuel as prices;import std::bytes as bytes;

// Native fixture: link the existing runtime-engine/heap-observer.c counters.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
unsafe extern C fn void bc_runtime_engine_test_fail(i64 count);

fn o::Transaction opened(usize limit,bool allowed,ref mut usize remaining){
 return switch(o::open_metered(limit,allowed,remaining)){
 case .ok(v):{v}case .err(_):{assert(false);opened(0,false,remaining)}};
}
fn o::Published sealed(ref mut o::Transaction t,ref mut usize remaining){
 return switch(o::seal_metered(t,remaining)){
 case .ok(v):{v}case .err(_):{assert(false);sealed(t,remaining)}};
}
fn usize emitted(Result<usize,o::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn bool appended(Result<bool,o::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);false}};}
fn u8 kind(o::Error e){return switch(e){
 case .State:{1}case .Denied:{2}case .Limit:{3}case .Fuel:{4}case .Allocation:{5}
};}
fn void rejected(Result<usize,o::Error> r,u8 expected){
 switch(r){case .ok(_):{assert(false);}case .err(e):{assert(kind(e)==expected);}};
}
fn void rejected_chunk(Result<bool,o::Error> r,u8 expected){
 switch(r){case .ok(_):{assert(false);}case .err(e):{assert(kind(e)==expected);}};
}
fn void same(o::Observation a,o::Observation b){
 assert(a.phase==b.phase && a.length==b.length && a.emits==b.emits && a.fuel==b.fuel && a.charged==b.charged);
}

@test fn void multi_chunk_commits_once_after_the_last_byte_and_prepays_once(){
 var usize remaining=100000;var o::Transaction t=opened(8202,true,ref mut remaining);
 assert(emitted(o::emit_metered(ref mut t,b"P\x00\xff",ref mut remaining))==3);
 let o::Observation prefix=o::observe(ref t);let usize before=remaining;
 assert(emitted(o::begin_emit_metered(ref mut t,8195,ref mut remaining))==8198);
 assert(remaining==before-prices::output_emit(8195) && o::emit_remaining(ref t)==8195);
 let o::Observation paid=o::observe(ref t);
 assert(paid.length==3 && paid.emits==1 && paid.fuel==remaining);
 assert(paid.charged==prefix.charged+prices::output_emit(8195));
 var u8[4096] first=[0;4096];let u8[4096] second=[255;4096];
 assert(!appended(o::append_emit_chunk(ref mut t,ref first)) && o::emit_remaining(ref t)==4099);
 same(paid,o::observe(ref t));first[0]=42;
 assert(!appended(o::append_emit_chunk(ref mut t,ref second)) && o::emit_remaining(ref t)==3);
 same(paid,o::observe(ref t));
 assert(appended(o::append_emit_chunk(ref mut t,b"a\x00b")) && o::emit_remaining(ref t)==0);
 let o::Observation committed=o::observe(ref t);
 assert(committed.length==8198 && committed.emits==2 && committed.fuel==paid.fuel && committed.charged==paid.charged);
 assert(emitted(o::begin_emit_metered(ref mut t,2,ref mut remaining))==8200);
 assert(appended(o::append_emit_chunk(ref mut t,b"cd")));
 assert(emitted(o::emit_metered(ref mut t,b"ef",ref mut remaining))==8202);
 let o::Published p=sealed(ref mut t,ref mut remaining);let ref u8[] data=o::view(ref p);
 assert(data.len==8202 && bytes::equal(data[..3],b"P\x00\xff"));
 var usize i=3;while(i<4099){assert(data[i]==0);i+=1;}
 while(i<8195){assert(data[i]==255);i+=1;}
 assert(bytes::equal(data[8195..],b"a\x00bcdef"));
 assert(o::published_observation(ref p).emits==4 && o::emit_remaining(ref t)==0);
}

@test fn void fuel_and_quota_preflight_sample_without_copying_or_debit_on_rejection(){
 var usize remaining=10000;var o::Transaction t=opened(4,true,ref mut remaining);
 assert(emitted(o::emit_metered(ref mut t,b"a",ref mut remaining))==1);
 let usize paid=o::observe(ref t).charged;remaining=prices::output_emit(3)-1;
 rejected(o::begin_emit_metered(ref mut t,3,ref mut remaining),4);
 assert(remaining==prices::output_emit(3)-1 && o::emit_remaining(ref t)==0);
 var o::Observation s=o::observe(ref t);
 assert(s.length==1 && s.emits==1 && s.fuel==remaining && s.charged==paid);
 rejected_chunk(o::append_emit_chunk(ref mut t,b"bad"),1);same(s,o::observe(ref t));
 remaining=9999;
 rejected(o::begin_emit_metered(ref mut t,4,ref mut remaining),3);
 rejected(o::begin_emit_metered(ref mut t,18446744073709551615,ref mut remaining),3);
 assert(remaining==9999 && o::emit_remaining(ref t)==0);
 s=o::observe(ref t);assert(s.length==1 && s.emits==1 && s.fuel==9999 && s.charged==paid);
 assert(o::transaction_heap_bytes(ref t)==44);
 remaining=prices::output_emit(3);
 assert(emitted(o::begin_emit_metered(ref mut t,3,ref mut remaining))==4 && remaining==0);
 assert(!appended(o::append_emit_chunk(ref mut t,b"b")));
 assert(appended(o::append_emit_chunk(ref mut t,b"cd")) && remaining==0);
 s=o::observe(ref t);assert(!o::seal_metered(ref mut t,ref mut remaining).is_ok);same(s,o::observe(ref t));
 remaining=prices::output_seal();let o::Published p=sealed(ref mut t,ref mut remaining);
 assert(remaining==0 && bytes::equal(o::view(ref p),b"abcd"));
 var usize denied_fuel=10000;var o::Transaction denied=opened(1,false,ref mut denied_fuel);
 let usize denied_paid=o::observe(ref denied).charged;denied_fuel=7000;
 rejected(o::begin_emit_metered(ref mut denied,0,ref mut denied_fuel),2);
 rejected(o::begin_emit_metered(ref mut denied,1,ref mut denied_fuel),2);
 s=o::observe(ref denied);
 assert(denied_fuel==7000 && s.fuel==7000 && s.charged==denied_paid && s.length==0 && s.emits==0);
 assert(o::emit_remaining(ref denied)==0);rejected_chunk(o::append_emit_chunk(ref mut denied,b"x"),1);
}

@test fn void invalid_chunks_and_interleaved_operations_cannot_mutate_a_pending_emit(){
 var usize remaining=10000;var o::Transaction t=opened(8,true,ref mut remaining);
 assert(emitted(o::emit_metered(ref mut t,b"p",ref mut remaining))==1);
 rejected_chunk(o::append_emit_chunk(ref mut t,b"x"),1);
 assert(emitted(o::begin_emit_metered(ref mut t,4,ref mut remaining))==5);
 let o::Observation paid=o::observe(ref t);remaining=12345;
 let u8[4096] block=[99;4096];
 var bytes::Buffer oversized=switch(bytes::with_capacity(4097)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
 assert(bytes::append(ref mut oversized,ref block).is_ok && bytes::append(ref mut oversized,b"x").is_ok);
 rejected_chunk(o::append_emit_chunk(ref mut t,b""),3);
 rejected_chunk(o::append_emit_chunk(ref mut t,bytes::view(ref oversized)),3);
 rejected_chunk(o::append_emit_chunk(ref mut t,b"12345"),3);
 rejected(o::begin_emit_metered(ref mut t,0,ref mut remaining),1);
 rejected(o::emit_metered(ref mut t,b"bad",ref mut remaining),1);
 assert(!o::seal_metered(ref mut t,ref mut remaining).is_ok);
 assert(!o::emit(ref mut t,b"bad",0).is_ok && !o::seal(ref mut t,0).is_ok);
 assert(remaining==12345 && o::emit_remaining(ref t)==4);same(paid,o::observe(ref t));
 assert(!appended(o::append_emit_chunk(ref mut t,b"ab")));
 rejected_chunk(o::append_emit_chunk(ref mut t,b"xyz"),3);
 rejected_chunk(o::append_emit_chunk(ref mut t,b""),3);
 rejected(o::begin_emit_metered(ref mut t,1,ref mut remaining),1);
 rejected(o::emit_metered(ref mut t,b"",ref mut remaining),1);
 assert(!o::seal_metered(ref mut t,ref mut remaining).is_ok);
 assert(remaining==12345 && o::emit_remaining(ref t)==2);same(paid,o::observe(ref t));
 assert(appended(o::append_emit_chunk(ref mut t,b"cd")));
 rejected_chunk(o::append_emit_chunk(ref mut t,b"!"),1);
 let o::Published p=sealed(ref mut t,ref mut remaining);
 assert(bytes::equal(o::view(ref p),b"pabcd") && o::published_observation(ref p).emits==2);
}

@test fn void cancel_and_fail_discard_partial_bytes_and_freeze_first_cause_and_spent_fuel(){
 var usize mode=0;while(mode<4){
  var usize remaining=10000;var o::Transaction t=opened(16,true,ref mut remaining);
  assert(emitted(o::emit_metered(ref mut t,b"keep",ref mut remaining))==4);
  assert(emitted(o::begin_emit_metered(ref mut t,6,ref mut remaining))==10);
  if(mode%2!=0){assert(!appended(o::append_emit_chunk(ref mut t,b"sec")));}
  let o::Observation paid=o::observe(ref t);let usize spent_remaining=remaining;
  let o::Observation terminal=if(mode<2){o::cancel(ref mut t)}else{o::fail(ref mut t)};
  assert(terminal.phase==if(mode<2){3}else{2});
  assert(terminal.length==0 && terminal.emits==1 && terminal.fuel==spent_remaining && terminal.charged==paid.charged);
  assert(remaining==spent_remaining && o::emit_remaining(ref t)==0 && o::transaction_heap_bytes(ref t)==40);
  remaining=12345;
  rejected(o::begin_emit_metered(ref mut t,1,ref mut remaining),1);
  rejected_chunk(o::append_emit_chunk(ref mut t,b"ret"),1);
  rejected(o::emit_metered(ref mut t,b"!",ref mut remaining),1);
  assert(!o::seal_metered(ref mut t,ref mut remaining).is_ok && remaining==12345);
  same(terminal,o::observe(ref t));same(terminal,o::fail(ref mut t));same(terminal,o::cancel(ref mut t));mode+=1;
 }
}

@test fn void empty_emit_commits_immediately_and_sealed_disabled_and_legacy_states_are_inactive(){
 var usize remaining=1536;var o::Transaction t=opened(0,true,ref mut remaining);
 assert(emitted(o::begin_emit_metered(ref mut t,0,ref mut remaining))==0);
 assert(remaining==512 && o::emit_remaining(ref t)==0);
 let o::Observation empty=o::observe(ref t);assert(empty.length==0 && empty.emits==1 && empty.charged==1024);
 rejected_chunk(o::append_emit_chunk(ref mut t,b""),1);same(empty,o::observe(ref t));
 let o::Published p=sealed(ref mut t,ref mut remaining);assert(remaining==0 && o::view(ref p).len==0);
 let o::Observation terminal=o::observe(ref t);remaining=9999;
 rejected(o::begin_emit_metered(ref mut t,0,ref mut remaining),1);
 rejected_chunk(o::append_emit_chunk(ref mut t,b"x"),1);
 same(terminal,o::cancel(ref mut t));same(terminal,o::fail(ref mut t));
 var o::Transaction disabled=o::disabled();let o::Observation off=o::observe(ref disabled);
 assert(o::emit_remaining(ref disabled)==0 && o::transaction_heap_bytes(ref disabled)==0);
 rejected(o::begin_emit_metered(ref mut disabled,0,ref mut remaining),1);
 rejected_chunk(o::append_emit_chunk(ref mut disabled,b"x"),1);
 same(off,o::cancel(ref mut disabled));same(off,o::fail(ref mut disabled));
 var o::Transaction legacy=switch(o::open(1,true,77)){
  case .ok(v):{v}case .err(_):{assert(false);opened(0,false,ref mut remaining)}
 };
 let o::Observation old=o::observe(ref legacy);
 rejected(o::begin_emit_metered(ref mut legacy,1,ref mut remaining),1);
 rejected_chunk(o::append_emit_chunk(ref mut legacy,b"x"),1);
 assert(remaining==9999 && o::emit_remaining(ref legacy)==0);same(old,o::observe(ref legacy));
 assert(emitted(o::emit(ref mut legacy,b"x",0))==1);
}

@test fn void exact_byte_chunk_and_one_mebibyte_boundaries_preserve_prices_and_header_size(){
 let usize[6] lengths=[1,4095,4096,4097,8192,1048576];let u8[4096] block=[255;4096];
 var usize n=0;while(n<6){
  let usize length=lengths[n];
  var usize remaining=prices::output_prepare(length)+prices::output_emit(length)+prices::output_seal();
  var o::Transaction t=opened(length,true,ref mut remaining);
  assert(o::transaction_heap_bytes(ref t)==40+length);
  assert(emitted(o::begin_emit_metered(ref mut t,length,ref mut remaining))==length && remaining==512);
  var usize copied=0;while(copied<length){
   let usize width=if(length-copied>4096){4096}else{length-copied};
   assert(appended(o::append_emit_chunk(ref mut t,ref block[..width]))==(copied+width==length));
   copied+=width;assert(o::emit_remaining(ref t)==length-copied && remaining==512);
   let o::Observation s=o::observe(ref t);
   assert(s.length==if(copied==length){length}else{0});assert(s.emits==if(copied==length){1}else{0});
  }
  rejected(o::begin_emit_metered(ref mut t,1,ref mut remaining),3);assert(remaining==512);
  let o::Published p=sealed(ref mut t,ref mut remaining);let ref u8[] data=o::view(ref p);
  assert(remaining==0 && data.len==length && o::transaction_heap_bytes(ref t)==40);
  assert(o::published_heap_bytes(ref p)==length && o::published_observation(ref p).emits==1);
  var usize i=0;while(i<length){assert(data[i]==255);i+=1;}n+=1;
 }
}

@test fn void pending_transactions_interleave_and_move_without_losing_their_copy_cursor(){
 var usize left_fuel=10000;var usize right_fuel=10000;
 var o::Transaction first=opened(4,true,ref mut left_fuel);
 var o::Transaction right=opened(4,true,ref mut right_fuel);
 assert(emitted(o::begin_emit_metered(ref mut first,4,ref mut left_fuel))==4);
 assert(!appended(o::append_emit_chunk(ref mut first,b"a\x00")));
 var o::Transaction left=first;
 assert(emitted(o::begin_emit_metered(ref mut right,3,ref mut right_fuel))==3);
 assert(!appended(o::append_emit_chunk(ref mut right,b"x")));
 let o::Observation right_paid=o::observe(ref right);
 assert(o::emit_remaining(ref left)==2 && o::emit_remaining(ref right)==2);
 assert(appended(o::append_emit_chunk(ref mut left,b"b\xff")));same(right_paid,o::observe(ref right));
 let o::Published a=sealed(ref mut left,ref mut left_fuel);
 assert(appended(o::append_emit_chunk(ref mut right,b"yz")));
 let o::Published b=sealed(ref mut right,ref mut right_fuel);
 assert(bytes::equal(o::view(ref a),b"a\x00b\xff") && bytes::equal(o::view(ref b),b"xyz"));
 assert(left_fuel==10000-prices::output_prepare(4)-prices::output_emit(4)-prices::output_seal());
 assert(right_fuel==10000-prices::output_prepare(4)-prices::output_emit(3)-prices::output_seal());
}

@test fn void begin_chunks_and_seal_make_zero_allocation_attempts_after_reservation(){
 var usize remaining=prices::output_prepare(8193)+prices::output_emit(8193)+prices::output_seal();
 var o::Transaction t=opened(8193,true,ref mut remaining);let u8[4096] block=[17;4096];
 let usize blocks=unsafe{probe_live()};let usize size=unsafe{probe_live_bytes()};
 let usize attempts=unsafe{probe_attempts()};unsafe{bc_runtime_engine_test_fail(0)};
 assert(emitted(o::begin_emit_metered(ref mut t,8193,ref mut remaining))==8193);
 assert(!appended(o::append_emit_chunk(ref mut t,ref block)));
 assert(o::emit_remaining(ref t)==4097 && o::transaction_heap_bytes(ref t)==40+8193);
 assert(unsafe{probe_attempts()}==attempts);
 rejected_chunk(o::append_emit_chunk(ref mut t,b""),3);
 assert(!appended(o::append_emit_chunk(ref mut t,ref block)));
 assert(o::emit_remaining(ref t)==1 && unsafe{probe_attempts()}==attempts);
 assert(appended(o::append_emit_chunk(ref mut t,b"\xff")));
 assert(o::emit_remaining(ref t)==0 && remaining==prices::output_seal());
 let o::Published p=sealed(ref mut t,ref mut remaining);
 unsafe{bc_runtime_engine_test_fail(-1)};
 assert(unsafe{probe_attempts()}==attempts && unsafe{probe_live()}==blocks && unsafe{probe_live_bytes()}==size);
 assert(remaining==0 && o::transaction_heap_bytes(ref t)==40 && o::published_heap_bytes(ref p)==8193);
 let ref u8[] data=o::view(ref p);assert(data.len==8193 && data[8192]==255);
 var usize i=0;while(i<8192){assert(data[i]==17);i+=1;}
}
