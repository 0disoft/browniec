module tests::m2::runtime_output_metered;
import runtime_output as o;import fuel as prices;
import std::bytes as bytes;import std::process as process;
fn o::Transaction opened(usize limit,bool allowed,ref mut usize remaining){
 return switch(o::open_metered(limit,allowed,remaining)){
 case .ok(v):{v}case .err(_):{assert(false);opened(0,false,remaining)}};
}
fn o::Published sealed(ref mut o::Transaction t,ref mut usize remaining){
 return switch(o::seal_metered(t,remaining)){
 case .ok(v):{v}case .err(_):{assert(false);sealed(t,remaining)}};
}
fn usize emitted(Result<usize,o::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void same(o::Observation a,o::Observation b){
 assert(a.phase==b.phase && a.length==b.length && a.emits==b.emits && a.fuel==b.fuel && a.charged==b.charged);
}
fn bool injecting(){return process::arg_count()>1;}
@test fn void output_prices_are_additive_and_bounded(){
 assert(prices::output_prepare(0)==512 && prices::output_prepare(1048576)==2097664);
 assert(prices::output_emit(0)==512 && prices::output_emit(1048576)==2097664);
 assert(prices::output_seal()==512 && prices::output_access()==8192);
 assert(prices::cli_default()==256 && prices::cli_limit()==16000000);
}
@test fn void one_shared_fuel_commits_setup_emit_and_seal_only(){
 var usize remaining=10000;var o::Transaction t=opened(6,true,ref mut remaining);
 assert(remaining==9476);let o::Observation start=o::observe(ref t);
 assert(start.phase==0 && start.length==0 && start.emits==0 && start.fuel==remaining && start.charged==524);
 remaining-=17;
 assert(emitted(o::emit_metered(ref mut t,b"\x00a\xff",ref mut remaining))==3 && remaining==8941);
 assert(emitted(o::emit_metered(ref mut t,b"",ref mut remaining))==3 && remaining==8429);
 remaining-=19;
 assert(emitted(o::emit_metered(ref mut t,b"b\x00c",ref mut remaining))==6 && remaining==7892);
 let o::Published p=sealed(ref mut t,ref mut remaining);assert(remaining==7380);
 let o::Observation s=o::published_observation(ref p);
 assert(s.phase==1 && s.length==6 && s.emits==3 && s.fuel==7380 && s.charged==2584);
 assert(bytes::equal(o::view(ref p),b"\x00a\xffb\x00c"));same(s,o::observe(ref t));
}
@test fn void preflight_has_no_debit_and_samples_current_shared_remaining(){
 var usize remaining=10000;
 assert(!o::open_metered(1048577,true,ref mut remaining).is_ok && remaining==10000);
 assert(!o::open_metered(18446744073709551615,true,ref mut remaining).is_ok && remaining==10000);
 var usize low=519;assert(!o::open_metered(4,true,ref mut low).is_ok && low==519);
 var o::Transaction t=opened(4,true,ref mut remaining);
 assert(emitted(o::emit_metered(ref mut t,b"a\x00",ref mut remaining))==2);
 let usize paid=o::observe(ref t).charged;remaining=3;
 assert(!o::emit_metered(ref mut t,b"x",ref mut remaining).is_ok && remaining==3);
 var o::Observation s=o::observe(ref t);assert(s.length==2 && s.emits==1 && s.fuel==3 && s.charged==paid);
 assert(!o::seal_metered(ref mut t,ref mut remaining).is_ok && remaining==3);
 same(s,o::observe(ref t));remaining=1000;
 assert(!o::emit_metered(ref mut t,b"xyz",ref mut remaining).is_ok && remaining==1000);
 s=o::observe(ref t);assert(s.fuel==1000 && s.charged==paid && s.length==2 && s.emits==1);
 let o::Published p=sealed(ref mut t,ref mut remaining);assert(remaining==488 && bytes::equal(o::view(ref p),b"a\x00"));
}
@test fn void first_terminal_freezes_and_unpublished_prefix_is_discarded(){
 var usize mode=0;while(mode<2){
  var usize remaining=10000;var o::Transaction t=opened(32,true,ref mut remaining);
  assert(emitted(o::emit_metered(ref mut t,b"secret\x00unpublished",ref mut remaining))==18);
  let o::Observation s=if(mode==0){o::fail(ref mut t)}else{o::cancel(ref mut t)};
  assert(s.phase==if(mode==0){2}else{3});assert(s.length==0 && s.emits==1 && s.charged==1124 && s.fuel==8876);
  remaining=9000;assert(!o::emit_metered(ref mut t,b"bad",ref mut remaining).is_ok && remaining==9000);
  assert(!o::seal_metered(ref mut t,ref mut remaining).is_ok && remaining==9000);
  same(s,o::observe(ref t));same(s,o::cancel(ref mut t));same(s,o::fail(ref mut t));mode+=1;
 }
 var usize remaining=1024;var o::Transaction t=opened(0,true,ref mut remaining);
 let o::Published p=sealed(ref mut t,ref mut remaining);assert(remaining==0 && o::view(ref p).len==0);
 let o::Observation s=o::observe(ref t);remaining=8000;
 assert(!o::seal_metered(ref mut t,ref mut remaining).is_ok && remaining==8000);same(s,o::cancel(ref mut t));
}
@test fn void denied_empty_and_legacy_mode_cannot_bypass_metering(){
 var usize remaining=2048;var o::Transaction denied=opened(0,false,ref mut remaining);
 assert(remaining==1536 && !o::emit_metered(ref mut denied,b"",ref mut remaining).is_ok && remaining==1536);
 assert(!o::emit(ref mut denied,b"",0).is_ok && !o::seal(ref mut denied,0).is_ok);
 let o::Published p=sealed(ref mut denied,ref mut remaining);assert(remaining==1024 && o::view(ref p).len==0);
 var o::Transaction legacy=switch(o::open(1,true,77)){case .ok(v):{v}case .err(_):{assert(false);opened(0,false,ref mut remaining)}};
 assert(!o::emit_metered(ref mut legacy,b"x",ref mut remaining).is_ok && remaining==1024);
 assert(!o::seal_metered(ref mut legacy,ref mut remaining).is_ok && remaining==1024);
 assert(o::observe(ref legacy).fuel==77 && o::observe(ref legacy).charged==0);
}
@test fn void reserved_many_small_emits_are_exact_at_one_mebibyte(){
 var usize remaining=16000000;var o::Transaction t=opened(1048576,true,ref mut remaining);
 let u8[256] chunk=[255;256];var usize i=0;
 while(i<4096){assert(emitted(o::emit_metered(ref mut t,ref chunk,ref mut remaining))==(i+1)*256);i+=1;}
 let usize before=remaining;assert(!o::emit_metered(ref mut t,b"x",ref mut remaining).is_ok && remaining==before);
 let o::Published p=sealed(ref mut t,ref mut remaining);let ref u8[] data=o::view(ref p);
 assert(data.len==1048576);i=0;while(i<data.len){assert(data[i]==255);i+=1;}
 let o::Observation s=o::published_observation(ref p);
 assert(s.emits==4096 && s.charged==6292480 && remaining==9707520 && s.fuel==remaining);
}
@test fn void allocator_open_failure_preserves_fuel_and_existing_transaction(){
 var usize remaining=10000;var o::Transaction keep=opened(8,true,ref mut remaining);
 assert(emitted(o::emit_metered(ref mut keep,b"keep\x00",ref mut remaining))==5);
 let usize before=remaining;let o::Observation observed=o::observe(ref keep);
 if(injecting()){
  switch(o::open_metered(384,true,ref mut remaining)){
   case .ok(_):{assert(false);}case .err(e):{switch(e){case .Allocation:{}case .State:{assert(false);}case .Denied:{assert(false);}case .Limit:{assert(false);}case .Fuel:{assert(false);}};}
  };assert(remaining==before);same(observed,o::observe(ref keep));
 }
 var o::Transaction added=opened(384,true,ref mut remaining);assert(remaining==before-1280);
 discard o::cancel(ref mut added);let o::Published p=sealed(ref mut keep,ref mut remaining);
 assert(bytes::equal(o::view(ref p),b"keep\x00"));
}

@test fn void disabled_is_allocation_free_terminal_and_stable(){
 var o::Transaction t=o::disabled();let o::Observation s=o::observe(ref t);
 assert(s.phase==4 && s.length==0 && s.emits==0 && s.fuel==0 && s.charged==0);
 var usize remaining=9999;
 assert(!o::emit_metered(ref mut t,b"x",ref mut remaining).is_ok && remaining==9999);
 assert(!o::seal_metered(ref mut t,ref mut remaining).is_ok && remaining==9999);
 assert(!o::emit(ref mut t,b"x",0).is_ok && !o::seal(ref mut t,0).is_ok);
 same(s,o::fail(ref mut t));same(s,o::cancel(ref mut t));same(s,o::observe(ref t));
}
