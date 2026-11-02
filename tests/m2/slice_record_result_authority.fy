module tests::m2::slice_record_result_authority;
import ir as ir;
import errors as errors;
import verifier as verifier;
import compiler as compiler;
import struct_result_vm as results;
import struct_vm as records;
import struct_layout as layouts;
import array_vm as arrays;
import array_layout as array_layout;
import array_owners as owners;
import array_slices as slices;
import vm_reborrow_execution as runner;
import vm_execution as execution;
import slice_reborrow_ir as proof;
import slice_authority as authority;
import slice_authority_call_vm as calls;
import slice_reborrow_vm as children;
import slice_reborrow_context as context;
import slice_vm as loans;
import slice_call_vm as shared;
import call_frame_vm as control;
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

fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn proof::Sites sites(ref ir::Program p){return switch(runner::inspect(p)){case .ok(s):{s}case .err(_):{assert(false);proof::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};}
fn usize pc(ref ir::Program p){var usize at=p.starts[p.entry];while(at<p.ends[p.entry] && p.code[at*8]!=9){at+=1;}assert(at<p.ends[p.entry]);return at;}
fn usize returned_site(ref ir::Program p){var usize at=p.starts[0];while(at<p.ends[0] && p.code[at*8]!=50){at+=1;}assert(at<p.ends[0]);return p.code[at*8+2] as usize;}
fn Result<i64,errors::Error> execute(ref ir::Program p,usize limit,usize fuel){
 var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(limit);var bytes::Buffer b=buffer(limit);
 let Result<i64,errors::Error> outcome=runner::execute(p,fuel,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links);assert(context::ready(ref auth[0],ref c[0],ref links[0],ref l,ref f).is_ok);if(outcome.is_ok){assert(a.owners.depth==0 && a.owners.arena.used==0);}return outcome;
}
fn void value(ref ir::Program p,usize limit,usize fuel){assert(switch(execute(p,limit,fuel)){case .ok(n):{n==42}case .err(_):{false}});}
fn void failure(ref ir::Program p,usize limit,usize fuel,u8 kind){assert(switch(execute(p,limit,fuel)){case .ok(_):{false}case .err(e):{e.kind==kind}});}
fn void run(ref u8[] source){let ir::Program p=compiled(source);value(ref p,256,20000000);}
fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> result){return switch(result){case .ok(t):{t}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn owners::Token array_create(ref mut arrays::State a,ref mut bytes::Buffer b){let array_layout::Array shape=switch(array_layout::scalar(1,1)){case .ok(v):{v}case .err(_):{assert(false);array_layout::Array{.element=1,.length=1,.stride=4,.alignment=4,.bytes=4}}};return switch(owners::create(ref shape,42,bytes::view_mut(b),ref mut a.owners)){case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}};}
fn ir::Program wide(){
 var ir::Program p=base(9,false);p.records.layouts.fields[0]=16;var usize i=0;while(i<16){p.records.layouts.types[i]=9;i+=1;}
 let usize source=built(ir::record_in(ref mut p,0,0,false,0));p.record_results[0]=1;var usize first=0;i=0;while(i<16){let usize n=cell(ref mut p,9,42);if(i==0){first=n;}i+=1;}
 let usize init=built(ir::record_init(ref mut p,source,first,0));let usize ret=built(ir::record_return(ref mut p,source,73));finish(ref mut p,0);entry(ref mut p);
 let usize dest=built(ir::record_in(ref mut p,1,0,false,0));let usize[1] args=[0];let usize called=built(ir::record_call(ref mut p,0,dest,ref args[..0],0));let usize observed=built(ir::record_read(ref mut p,dest,15,0));let usize expected=cell(ref mut p,9,42);equal(ref mut p,observed,expected);let usize dropped=built(ir::record_drop(ref mut p,dest,0));let usize answer=cell(ref mut p,1,42);let usize done=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,1);return p;
}
@test
fn void six_scalar_edges_nested_depth_and_maximum_size_rehome_one_extent(){
 let u8[6] tags=[1,2,9,10,11,12];let i64[6] fills=[-2147483648,1,-9223372036854775808,255,4294967295,-1];let usize[6] sizes=[4,1,8,1,4,8];var usize i=0;
 while(i<6){let ir::Program p=factory(tags[i],fills[i],false,false,1);value(ref p,sizes[i],1000000);failure(ref p,sizes[i]-1,1000000,13);let ir::Program n=factory(tags[i],fills[i],true,false,1);value(ref n,if(sizes[i]==1){2}else{sizes[i]*2},1000000);i+=1;}
 let ir::Program maximum=wide();value(ref maximum,128,1000000);failure(ref maximum,127,1000000,13);
 var ir::Program deep=factory(2,1,false,false,1);deep.records.layouts=layouts::empty();deep.records.layouts.count=16;deep.records.layouts.fields[0]=1;deep.records.layouts.types[0]=2;i=1;var u8 child=0;while(i<16){deep.records.layouts.fields[i]=1;deep.records.layouts.kinds[i*16]=1;deep.records.layouts.types[i*16]=child;i+=1;child+=1;}deep.records.records[0]=15;deep.records.records[1]=15;value(ref deep,1,1000000);
}
@test
fn void repeated_holes_recursion_and_exact_fuel_preserve_limits(){
 let ir::Program p=factory(1,42,false,false,1);value(ref p,4,129611);failure(ref p,4,129610,8);failure(ref p,4,88260,8);assert(results::cost()==42113);
 let ir::Program repeat=factory(1,42,false,false,24);value(ref repeat,4,16000000);let ir::Program holes=factory(1,42,false,true,24);value(ref holes,8,16000000);failure(ref holes,7,16000000,13);
 let ir::Program deep=recursive(30);value(ref deep,4,16000000);let ir::Program over=recursive(31);failure(ref over,4,16000000,12);
}
@test
fn void source_parameters_constructors_child_paths_and_mixed_results_execute(){
 run(b"module main;struct P{i32 x;}fn P id(P p){return p;}fn i32 main(){var P p=P{.x=42};p=id(p);return p.x;}");
 run(b"module main;struct I{bool ok;i32 x;}struct R{u8 lead;I inner;}fn R f(R r,i32[1] a,ref i32[] q,ref mut i32[] p){p[0]=r.inner.x+a[0]+q[0];return R{.lead=7,.inner=I{.ok=true,.x=p[0]}};}fn i32 main(){let R r=R{.lead=0,.inner=I{.ok=true,.x=20}};let i32[1] a=[21;1];let i32[1] b=[1;1];var i32[1] out=[0;1];let ref i32[] q=ref b;let ref mut i32[] p=ref mut out;let R result=f(r,a,ref q,ref mut p);if(result.inner.ok){return result.inner.x;}return 0;}");
 run(b"module main;struct P{i32 x;}struct R{P p;}fn R make(){return R{.p=P{.x=42}};}fn P pick(R r){return r.p;}fn i32 main(){let P p=pick(make());return p.x;}");
 run(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32[1] array(){let P p=make();return [p.x;1];}fn P record(){let i32[1] a=array();return P{.x=a[0]};}fn i32 main(){let P p=record();return p.x;}");
}
@test
fn void invalid_results_preserve_tokens_owners_backing_and_canonical_maps(){
 let ir::Program good=factory(1,42,true,false,1);let proof::Sites map=sites(ref good);let usize at=pc(ref good);var usize mode=0;
 while(mode<21){var ir::Program p=good;var arrays::State a=arrays::empty(8);var records::State r=records::empty();var bytes::Buffer b=buffer(8);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var authority::State auth=authority::empty();var calls::Bindings c=calls::empty();
  let usize entered=built(calls::enter_owned(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,built(calls::cost(ref p,at,0))));assert(entered==0);
  let i64[2] fields=[42,1];let owners::Token t=create(ref p,ref mut a,ref mut b,1,ref fields);r.tokens[16]=t;
  if(mode==0){r.tokens[16].generation+=1;}else if(mode==1){r.tokens[1]=t;}else if(mode==2){r.tokens[17]=t;}else if(mode==3){bytes::view_mut(ref mut b)[4]=2;}else if(mode==4){a.owners.slots[t.slot].record=0;}else if(mode==5){a.owners.slots[t.slot].alignment=1;}else if(mode==6){a.owners.slots[t.slot].length=4;}else if(mode==7){a.tokens[16]=t;}else if(mode==8){r.tokens[1].slot=1;}else if(mode==9){r.tokens[17].slot=1;}else if(mode==10){a.tokens[16].slot=1;}else if(mode==11){p.records.records[1]=0;}else if(mode==12){p.record_results[0]=0;}else if(mode==13){a.owners.order[0]=16;}else if(mode==14){a.owners.slots[t.slot].live=false;}else if(mode==15){p.records.layouts.types[16]=1;}else if(mode==18){c.pcs[0]=256;}else if(mode==19){auth.reserves[0]+=1;}
  let usize frame=if(mode==16){0}else if(mode==17){32}else{1};let usize destination=if(mode==20){0}else{1};let arrays::State old=a;let records::State prior=r;let usize mapped=c.pcs[0];let usize reserve=auth.reserves[0];var u8[8] saved=[0;8];var usize i=0;while(i<8){saved[i]=bytes::view(ref b)[i];i+=1;}
  assert(switch(calls::return_record(ref p,0,frame,0,destination,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref mut r,ref b,results::cost(),73)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==73}});
  unchanged(ref a,ref old,ref r,ref prior);assert(auth.depth==1 && auth.frame==1 && auth.reserves[0]==reserve && c.pcs[0]==mapped);i=0;while(i<8){assert(bytes::view(ref b)[i]==saved[i]);i+=1;}mode+=1;
 }
 var arrays::State a=arrays::empty(0);var records::State r=records::empty();var loans::State l=loans::empty();var shared::Frames f=shared::empty();var authority::State auth=authority::empty();var calls::Bindings c=calls::empty();let bytes::Buffer b=bytes::empty();assert(switch(calls::return_record(ref good,255,32,255,255,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref mut r,ref b,42112,73)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==73}});
}
@test
fn void late_restoration_failure_preserves_result_then_moves_the_same_owner_once(){
 let ir::Program p=compiled(b"module main;struct I{bool ok;i32 x;}struct R{u8 lead;I inner;}fn R f(ref i32[] q,ref mut i32[] p){return R{.lead=7,.inner=I{.ok=true,.x=42}};}fn i32 main(){let i32[1] a=[42;1];var i32[1] b=[0;1];let ref i32[] q=ref a;let ref mut i32[] p=ref mut b;let R result=f(ref q,ref mut p);return result.inner.x;}");let proof::Sites map=sites(ref p);let usize at=pc(ref p);let usize args=p.code[at*8+3] as usize;
 var arrays::State a=arrays::empty(64);var records::State r=records::empty();var bytes::Buffer b=buffer(64);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var authority::State auth=authority::empty();var calls::Bindings c=calls::empty();var usize i=0;
 while(i<p.arrays.count){if(p.array_functions[i] as usize==p.entry){let owners::Token root=array_create(ref mut a,ref mut b);a.tokens[i]=root;}i+=1;}
 let usize reader=(p.call_args[args*8] as usize)-160;let usize writer=(p.call_args[args*8+1] as usize)-160;let owners::Token read_root=a.tokens[(p.slice_roots[reader] as usize)-1];let owners::Token write_root=a.tokens[(p.slice_roots[writer] as usize)-1];
 let slices::Ticket rt=ticket(slices::open(ref mut l.pool,ref mut a.owners,read_root,0,1,64));l.tickets[reader]=rt;let slices::Ticket wt=ticket(slices::open_exclusive(ref mut l.pool,ref mut a.owners,write_root,0,1,64));l.tickets[writer]=wt;
 let usize entered=built(calls::enter_owned(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref mut r,ref mut b,built(calls::cost(ref p,at,0))));assert(entered==0);
 let usize source=returned_site(ref p);let usize destination=(p.code[at*8+1] as usize)-144;let usize nominal=p.records.records[source] as usize;let i64[3] fields=[7,1,42];let owners::Token t=create(ref p,ref mut a,ref mut b,nominal,ref fields);r.tokens[16+source]=t;
 let usize formal=(p.slice_parameters[p.register_starts[0]+1] as usize)-1;let slices::Ticket current=l.tickets[16+formal];l.pool.slots[current.slot].generation=18446744073709551615;l.tickets[16+formal].generation=18446744073709551615;
 let arrays::State old=a;let records::State prior=r;let slices::Pool pool=l.pool;
 assert(!calls::return_record(ref p,0,1,source,destination,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref mut r,ref b,results::cost(),73).is_ok);unchanged(ref a,ref old,ref r,ref prior);assert(auth.depth==1 && c.pcs[0]==at);i=0;while(i<16){assert(l.pool.slots[i].generation==pool.slots[i].generation && l.pool.slots[i].live==pool.slots[i].live);i+=1;}
 l.pool.slots[current.slot].generation=current.generation;l.tickets[16+formal]=current;
 assert(built(calls::return_record(ref p,0,1,source,destination,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref mut r,ref b,results::cost()+7,73))==7);
 assert(auth.depth==0 && auth.frame==0 && r.tokens[16+source].generation==0 && r.tokens[destination].slot==t.slot && r.tokens[destination].generation==t.generation && a.owners.depth==old.owners.depth && a.owners.arena.used==old.owners.arena.used && a.owners.slots[t.slot].generation==t.generation);
 assert(l.tickets[reader].slot==rt.slot && l.tickets[reader].generation==rt.generation && slices::length(ref l.pool,l.tickets[writer],ref a.owners,64).is_ok);
 assert(!calls::return_record(ref p,0,1,source,destination,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref mut r,ref b,results::cost(),73).is_ok);assert(calls::finish(ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref b,.ok(42)).is_ok);
}
@test
fn void abort_after_record_transfer_keeps_prior_write_result_and_original_error(){
 let ir::Program p=compiled(b"module main;struct P{i32 x;}fn P f(ref mut i32[] p){p[0]=42;return P{.x=1};}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let P result=f(ref mut p);let i32 zero=0;return result.x/zero;}");let proof::Sites map=sites(ref p);
 var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=buffer(64);
 let errors::Error error=switch(execution::execute_canonical(ref p,ref map,1000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(_):{assert(false);errors::make(0,0)}case .err(e):{e}};assert(error.kind==7 && auth[0].depth==0 && a.owners.depth==2);
 assert(switch(context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.err(error))){case .ok(_):{false}case .err(e):{e.kind==7 && e.offset==error.offset}});assert(context::ready(ref auth[0],ref c[0],ref links[0],ref l,ref f).is_ok && a.owners.depth==2 && a.owners.arena.used==8);assert(bytes::view(ref b)[0]==42 && bytes::view(ref b)[4]==1);
}
@test
fn void exact_nominal_signature_control_fuel_and_live_destination_gates_are_atomic(){
 let ir::Program original=factory(1,42,false,false,1);let proof::Sites map=sites(ref original);let usize at=pc(ref original);var usize mode=0;
 while(mode<12){var ir::Program p=original;var arrays::State a=arrays::empty(4);var records::State r=records::empty();var bytes::Buffer b=buffer(4);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var authority::State auth=authority::empty();var calls::Bindings c=calls::empty();
  if(mode==1){p.record_results[0]=255;}else if(mode==2){p.record_functions[1]=0;}else if(mode==3){p.records.layouts.count=3;p.records.layouts.fields[2]=1;p.records.layouts.types[32]=1;p.records.records[1]=2;}else if(mode==4){p.array_results[0]=1;}else if(mode==5){p.records.records[0]=32;}else if(mode==6){p.code[at*8+1]=128;}else if(mode==7){p.record_functions[0]=1;}else if(mode==8){r.tokens[1]=owners::Token{.slot=0,.generation=1};}else if(mode==11){p.return_types[0]=1;}
  var i64[256] registers=[99;256];var usize[32] pcs=[77;32];var usize[32] dsts=[88;32];
  assert(switch(control::step_canonical(ref p,ref map,at,if(mode==10){31}else{0},ref mut c,ref mut auth,ref mut f,ref mut l,ref mut r,ref mut a,ref mut b,ref mut registers,ref mut pcs[..if(mode==9){1}else{32}],ref mut dsts,if(mode==0){0}else{1})){case .ok(_):{false}case .err(e):{e.kind==if(mode==0){8}else if(mode==10){12}else{5}}});
  assert(auth.depth==0 && auth.frame==0 && c.pcs[0]==256 && a.owners.depth==0 && a.owners.arena.used==0 && r.tokens[1].generation==if(mode==8){1}else{0});var usize i=0;while(i<256){assert(registers[i]==99);i+=1;}i=0;while(i<32){assert(pcs[i]==77 && dsts[i]==88);i+=1;}mode+=1;
 }
}
