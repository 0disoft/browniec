module tests::m2::struct_function_ir;
import ir as ir;
import verifier as verifier;
import vm as vm;
import compiler as compiler;
import errors as errors;
fn usize built(Result<usize,errors::Error> r) {
 return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};
}
fn void body(ref mut ir::Program p,usize f,usize destination,usize copy) {
 let usize start=p.count;let usize registers=p.registers;
 let usize head=built(ir::literal(p,20,0));let usize value=built(ir::literal(p,42,0));
 let usize init=built(ir::record_init(p,destination,head,0));
 let usize copied=built(ir::record_copy(p,copy,destination,0));
 let usize written=built(ir::record_write(p,destination,1,value,0));
 let usize assigned=built(ir::record_assign(p,destination,copy,0));
 let usize child=built(ir::record_subassign(p,destination,copy,1,1,1,0));
 let usize root=built(ir::record_replace(p,destination,head,0,0));
 let usize part=built(ir::record_subreplace(p,destination,value,1,1,0));
 let usize read=built(ir::record_read(p,destination,1,0));
 let usize drop_copy=built(ir::record_drop(p,copy,0));let usize drop_root=built(ir::record_drop(p,destination,0));
 var usize result=read;
 if(f==0){let usize[1] arguments=[0];result=built(ir::call(p,1,ref arguments[..0],0));}
 let usize ret=built(ir::emit(p,8,result,0,0));
 p.starts[f]=start;let usize end=p.count;p.ends[f]=end;
 p.register_starts[f]=registers;let usize register_end=p.registers;p.register_ends[f]=register_end;p.return_types[f]=1;
}
fn ir::Program program() {
 var ir::Program p=ir::empty();p.function_count=2;
 p.records.layouts.count=2;p.records.layouts.fields[0]=2;p.records.layouts.types[0]=1;
 p.records.layouts.kinds[1]=1;p.records.layouts.types[1]=1;p.records.layouts.fields[1]=1;p.records.layouts.types[16]=1;
 let usize a=built(ir::record_in(ref mut p,0,0,true,0));let usize b=built(ir::record_in(ref mut p,1,0,true,0));
 let usize c=built(ir::record_in(ref mut p,0,0,true,0));let usize d=built(ir::record_in(ref mut p,1,0,true,0));
 p.return_types[1]=1;body(ref mut p,0,a,c);body(ref mut p,1,b,d);return p;
}
@test
fn void builders_default_to_entry_and_reject_bad_function_ids_without_catalog_changes() {
 var ir::Program p=ir::empty();p.records.layouts.count=1;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=1;p.entry=1;
 assert(built(ir::record(ref mut p,0,true,0))==0 && p.record_functions[0]==1);
 assert(!ir::record_in(ref mut p,16,0,true,0).is_ok && p.records.count==1 && p.record_functions[1]==0);
 p.function_count=2;assert(!ir::record_in(ref mut p,2,0,true,0).is_ok && p.records.count==1);
 assert(built(ir::record_in(ref mut p,0,0,false,0))==1 && p.record_functions[1]==0);
}
@test
fn void every_record_opcode_is_verified_in_its_declared_function() {
 let ir::Program p=program();assert(verifier::verify(ref p).is_ok && p.record_functions[1]==1 && p.record_functions[3]==1);
 // Frame-local record dispatch now executes the verified helper.
 assert(switch(vm::run(ref p,2000000)){case .err(_):{false}case .ok(n):{n==42}});
}
@test
fn void destination_and_source_ownership_are_independent_of_layout_and_liveness() {
 let ir::Program original=program();var usize i=0;
 while(i<10){var ir::Program p=original;
  if(i<4){p.record_functions[i]=if(i==0 || i==2){1}else{0};}
  else if(i==4){p.code[3*8+2]=1;} // Foreign SCOPY input.
  else if(i==5){p.code[5*8+2]=3;} // Foreign SASSIGN input.
  else if(i==6){p.code[6*8+2]=3;} // Foreign SSUBASSIGN input.
  else if(i==7){p.code[9*8+2]=1;} // Foreign SREAD binding.
  else if(i==8){p.code[8*8+1]=1;} // Foreign SSUBREPLACE target.
  else{p.code[7*8+1]=1;} // Foreign SREPLACE target.
  assert(!verifier::verify(ref p).is_ok);i+=1;
 }
}
@test
fn void undeclared_functions_and_dirty_unused_metadata_fail_even_without_instructions() {
 let ir::Program original=program();var ir::Program p=original;
 p.record_functions[0]=2;assert(!verifier::verify(ref p).is_ok);
 p=original;p.record_functions[4]=1;assert(!verifier::verify(ref p).is_ok);
 p=original;p.record_functions[15]=255;assert(!verifier::verify(ref p).is_ok);
 p=original;p.record_functions[1]=255;assert(!verifier::verify(ref p).is_ok);
}
@test
fn void helper_leaks_double_drops_and_missing_cleanup_remain_invalid() {
 let ir::Program original=program();let usize start=original.starts[1];var ir::Program p=original;
 p.code[(start+11)*8]=44;p.code[(start+11)*8+2]=1;p.code[(start+11)*8+3]=5;
 assert(!verifier::verify(ref p).is_ok); // Return still has a live record.
 p=original;p.code[(start+10)*8+1]=1;assert(!verifier::verify(ref p).is_ok); // Double release.
 p=original;p.code[(start+2)*8]=45;p.code[(start+2)*8+2]=0;assert(!verifier::verify(ref p).is_ok); // Dead release.
}
@test
fn void helper_source_syntax_remains_gated_and_entry_records_still_execute() {
 let ir::Program p=switch(compiler::compile(b"module main;struct P{i32 x;}fn i32 helper(i32 n){return n;}fn i32 main(){let P p=P{.x=42};return helper(p.x);}")){
  case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};
 assert(p.entry==1 && p.record_functions[0]==1 && verifier::verify(ref p).is_ok);
 assert(switch(vm::run(ref p,2000000)){case .ok(n):{n==42}case .err(_):{false}});
 assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 helper(){let P p=P{.x=42};return p.x;}fn i32 main(){return helper();}").is_ok);
 assert(!compiler::compile(b"module main;struct P{i32 x;}fn i32 helper(P p){return p.x;}fn i32 main(){return 42;}").is_ok);
 assert(!compiler::compile(b"module main;struct P{i32 x;}fn P helper(){return P{.x=42};}fn i32 main(){return 42;}").is_ok);
}
