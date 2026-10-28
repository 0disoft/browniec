module tests::m2::buffer_growth;
import buffer_growth as growth;
fn growth::Limits limits(usize object,usize instance,usize engine) {
 return growth::Limits{.object=object,.instance=instance,.engine=engine};
}
fn growth::Ledger accounted(usize used,usize engine) {
 var growth::Ledger l=growth::empty();l.used=used;l.engine_used=engine;l.peak=used;l.engine_peak=engine;return l;
}
fn usize ok(Result<usize,growth::Error> r) {return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};}
fn u8 code(growth::Error e) {return switch(e){case .State:{1}case .Overflow:{2}case .Quota:{3}case .NoGrowth:{4}};}
fn void error(Result<usize,growth::Error> r,u8 expected) {assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});}
fn bool same(ref growth::Ledger a,ref growth::Ledger b) {
 return a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
 a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
 a.before_used==b.before_used && a.before_engine_used==b.before_engine_used;
}
@test
fn void growth_rounds_to_sixty_four_and_prefers_one_and_a_half() {
 let growth::Limits cap=limits(2048,4096,8192);
 let growth::Ledger empty=growth::empty();assert(ok(growth::plan(0,1,cap,ref empty))==64);
 assert(ok(growth::plan(0,65,cap,ref empty))==128);
 let growth::Ledger l=accounted(320,320);
 assert(ok(growth::plan(256,257,cap,ref l))==384);
 assert(ok(growth::plan(256,449,cap,ref l))==512);
 let growth::Ledger other=accounted(384,384);
 assert(ok(growth::plan(320,321,cap,ref other))==512);
}
@test
fn void object_instance_and_engine_each_allow_minimum_fallback() {
 let growth::Ledger l=accounted(320,320);
 assert(ok(growth::plan(256,257,limits(352,2048,4096),ref l))==320);
 assert(ok(growth::plan(256,257,limits(1024,736,4096),ref l))==320);
 assert(ok(growth::plan(256,257,limits(1024,2048,736),ref l))==320);
 error(growth::plan(256,257,limits(319,2048,4096),ref l),3);
 error(growth::plan(256,257,limits(1024,703,4096),ref l),3);
 error(growth::plan(256,257,limits(1024,2048,703),ref l),3);
}
@test
fn void exact_peak_boundaries_include_both_owner_records() {
 let growth::Ledger l=accounted(320,320);var usize ceiling=640;
 while(ceiling<=800) {
  if(ceiling<704) {error(growth::plan(256,257,limits(1024,ceiling,4096),ref l),3);}
  else {assert(ok(growth::plan(256,257,limits(1024,ceiling,4096),ref l))==if(ceiling<768){320}else{384});}
  ceiling+=1;
 }
 let growth::Ledger e=accounted(320,352);
 error(growth::plan(256,257,limits(1024,704,735),ref e),3);
 assert(ok(growth::plan(256,257,limits(1024,704,736),ref e))==320);
}
@test
fn void begin_and_commit_keep_old_plus_new_until_publication() {
 var growth::Ledger l=accounted(320,352);let growth::Limits cap=limits(1024,2048,4096);
 assert(ok(growth::begin(256,257,cap,ref mut l))==384);
 assert(l.used==768 && l.engine_used==800 && l.pending==448 && l.peak==768 && l.engine_peak==800);
 let growth::Ledger before=l;error(growth::commit(320,ref mut l),1);assert(same(ref l,ref before));
 assert(ok(growth::commit(384,ref mut l))==384);
 assert(l.used==448 && l.engine_used==480 && l.peak==768 && l.engine_peak==800 && l.pending==0);
 assert(l.before_used==0 && l.before_engine_used==0 && l.old_capacity==0 && l.new_capacity==0);
 error(growth::commit(384,ref mut l),1);error(growth::cancel(ref mut l),1);
 assert(ok(growth::plan(384,385,cap,ref l))==576);
}
@test
fn void cancellation_no_growth_and_nested_admission_preserve_accounting() {
 var growth::Ledger l=accounted(320,352);let growth::Ledger initial=l;
 let growth::Limits cap=limits(1024,704,736);
 assert(ok(growth::plan(256,256,cap,ref l))==256);
 error(growth::begin(256,200,cap,ref mut l),4);assert(same(ref l,ref initial));
 assert(ok(growth::begin(256,257,cap,ref mut l))==320);
 let growth::Ledger pending=l;error(growth::begin(256,257,cap,ref mut l),1);assert(same(ref l,ref pending));
 assert(ok(growth::cancel(ref mut l))==320);
 assert(l.used==320 && l.engine_used==352 && l.peak==704 && l.engine_peak==736 && l.pending==0);
 assert(ok(growth::begin(256,257,cap,ref mut l))==320);assert(ok(growth::cancel(ref mut l))==320);
 let growth::Ledger restored=l;error(growth::begin(256,257,limits(319,704,736),ref mut l),3);
 assert(same(ref l,ref restored));error(growth::cancel(ref mut l),1);
}
@test
fn void malformed_clean_counters_and_policy_do_not_bypass_preflight() {
 let growth::Limits cap=limits(1024,2048,4096);
 var growth::Ledger l=accounted(320,320);error(growth::plan(255,256,cap,ref l),1);
 l.used=0;let growth::Ledger a=l;error(growth::begin(0,1,cap,ref mut l),1);assert(same(ref l,ref a));
 l=accounted(320,319);error(growth::plan(256,257,cap,ref l),1);
 l=accounted(320,320);l.peak=319;error(growth::plan(256,257,cap,ref l),1);
 l=accounted(320,320);l.before_used=1;error(growth::plan(256,0,cap,ref l),1);
 l=accounted(320,320);error(growth::plan(256,0,limits(255,2048,4096),ref l),3);
 error(growth::plan(256,0,limits(1024,319,4096),ref l),3);
}
@test
fn void corrupted_pending_transactions_cannot_change_counters() {
 var growth::Ledger base=accounted(320,320);
 assert(ok(growth::begin(256,257,limits(1024,2048,4096),ref mut base))==384);
 var growth::Ledger l=base;l.pending=18446744073709551615;
 let growth::Ledger a=l;error(growth::cancel(ref mut l),1);assert(same(ref l,ref a));
 l=base;l.before_used=18446744073709551615;let growth::Ledger b=l;
 error(growth::commit(384,ref mut l),1);assert(same(ref l,ref b));
 l=base;l.engine_used-=1;let growth::Ledger c=l;error(growth::cancel(ref mut l),1);assert(same(ref l,ref c));
 l=base;l.new_capacity=320;let growth::Ledger d=l;error(growth::commit(320,ref mut l),1);assert(same(ref l,ref d));
}
@test
fn void usize_extremes_fail_without_native_arithmetic_traps() {
 let growth::Limits cap=limits(18446744073709551615,18446744073709551615,18446744073709551615);
 let growth::Ledger empty=growth::empty();
 error(growth::plan(0,18446744073709551615,cap,ref empty),2);
 error(growth::plan(0,18446744073709551552,cap,ref empty),2);
 let usize old=13835058055282163712;var growth::Ledger l=accounted(old+64,old+64);
 let growth::Ledger before=l;error(growth::begin(old,old+1,cap,ref mut l),3);assert(same(ref l,ref before));
 error(growth::plan(18446744073709551615,0,cap,ref empty),1);
}
