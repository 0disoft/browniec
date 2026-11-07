module tests::m2::value_view_conditional_ir;
import value_ir as values;
import value_properties as properties;
import value_flow as owners;
import value_view_flow as views;
import verifier as verifier;
import ir as ir;
import errors as errors;

// Independent eight-byte IR fixtures, with no compiler liveness metadata.
// Each helper holds at most one Program; tests keep native frames small.
fn usize ok(Result<usize,errors::Error> r){return switch(r){
    case .ok(n):{n}case .err(_):{assert(false);0}
};}
fn u8 byte(usize n){assert(n<256);var usize i=0;var u8 b=0;while(i<n){i+=1;b+=1;}return b;}
fn properties::Node node(u8 kind,u8 first,u8 second){
    return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};
}
fn values::Program base(){
    var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[1,1,1,1,4,5,2,0,0,0,0,0,0,0,0,0],.functions=[0;16],
        .parameters=[0;128],.results=[0;16]};
    u.catalog.count=5;u.catalog.nodes[0]=node(4,0,0);u.catalog.nodes[1]=node(1,12,0);
    u.catalog.nodes[2]=node(1,10,0);u.catalog.nodes[3]=node(6,1,2);u.catalog.nodes[4]=node(5,0,0);
    let usize answer=ok(ir::literal(ref mut u.body,42,0));
    let usize zero=ok(ir::integer(ref mut u.body,0,12,0));
    let usize condition=ok(ir::boolean(ref mut u.body,true,0));
    let usize value=ok(ir::integer(ref mut u.body,42,10,0));return u;
}
fn usize emit(ref mut values::Program u,u8 op,usize dst,usize a,usize b){
    return ok(ir::raw(ref mut u.body,op,dst,a,b,0));
}
fn void rewrite(ref mut values::Program u,usize pc,u8 op,usize dst,usize a,usize b){
    var usize i=0;while(i<8){u.body.code[pc*8+i]=0;i+=1;}
    u.body.code[pc*8]=op;u.body.code[pc*8+1]=byte(dst);
    u.body.code[pc*8+2]=byte(a);u.body.code[pc*8+3]=byte(b);
}
fn usize begin(ref mut values::Program u,usize view,usize root){
    let usize pc=emit(u,105,view,root,1);u.body.code[pc*8+4]=1;return pc;
}
fn void close(ref mut values::Program u,usize view){let usize pc=emit(u,109,view,0,0);}
fn void retire(ref mut values::Program u,usize root){let usize pc=emit(u,115,root,0,0);}
fn usize find(ref values::Program u,u8 op,usize ordinal){
    var usize pc=0;var usize n=0;while(pc<u.body.count){if(u.body.code[pc*8]==op){
        if(n==ordinal){return pc;}n+=1;}pc+=1;}assert(false);return 0;
}
fn void finish(ref mut values::Program u,usize f,usize start,usize registers,usize arity,u8 result,u8 tag){
    let usize end=u.body.count;let usize regs=u.body.registers;
    u.body.starts[f]=start;u.body.ends[f]=end;u.body.register_starts[f]=registers;
    u.body.register_ends[f]=regs;u.body.arities[f]=arity;u.results[f]=result;u.body.return_types[f]=tag;
}
fn usize parameter(ref mut values::Program u,u8 encoded){
    let usize r=u.body.registers;u.body.registers+=1;u.body.types[r]=0;u.parameters[r]=encoded;return r;
}
fn values::Prepared prepared(ref values::Program u){return switch(values::prepare(u)){
    case .ok(p):{p}case .err(_):{assert(false);prepared(u)}
};}
fn void admitted(ref values::Program u){
    let values::Prepared p=prepared(u);assert(owners::inspect(u,ref p).is_ok);
    assert(views::inspect(u,ref p).is_ok);assert(verifier::inspect_values(u).is_ok);
}
fn void owner_error(ref values::Program u,usize pc){
    let values::Prepared p=prepared(u);
    assert(switch(owners::inspect(u,ref p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});
    assert(!verifier::inspect_values(u).is_ok);
}
fn void pin_error(ref values::Program u,usize pc){
    let values::Prepared p=prepared(u);assert(owners::inspect(u,ref p).is_ok);
    assert(switch(views::inspect(u,ref p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});
    assert(!verifier::inspect_values(u).is_ok);
}

// Both paths publish view0; its actual owner is branch-local slot0 OR slot1.
// A surviving alias proves that cleanup waits for the last descriptor CLOSE.
fn values::Program joined(){
    var values::Program u=base();u.body.function_count=1;
    let usize branch=u.body.count;let usize test=emit(ref mut u,20,0,2,branch+4);
    let usize left=emit(ref mut u,95,0,0,0);let usize lv=begin(ref mut u,0,0);
    let usize jump=emit(ref mut u,19,0,branch+6,0);
    let usize right=emit(ref mut u,95,1,0,0);let usize rv=begin(ref mut u,0,1);
    let usize marker=u.body.count;let usize action=emit(ref mut u,19,0,marker+1,0);
    let usize alias=emit(ref mut u,107,1,0,0);close(ref mut u,0);
    let usize still=u.body.count;let usize pinned=emit(ref mut u,19,0,still+1,0);
    close(ref mut u,1);retire(ref mut u,0);retire(ref mut u,1);
    let usize ret=emit(ref mut u,8,0,0,0);finish(ref mut u,0,0,0,0,0,1);return u;
}
@test fn void distinct_branch_local_owner_views_union_and_last_close_allows_conditional_retire(){
    let values::Program u=joined();admitted(ref u);
    assert(!verifier::inspect(ref u.body).is_ok && !verifier::verify(ref u.body).is_ok);
    assert(!verifier::inspect_reborrow_calls(ref u.body).is_ok);
    assert(!verifier::inspect_slice_places(ref u.body).is_ok);
}
fn void pinned_case(usize owner,bool alias){
    var values::Program u=joined();let usize pc=if(alias){find(ref u,109,0)+1}else{find(ref u,107,0)-1};
    rewrite(ref mut u,pc,115,owner,0,0);pin_error(ref u,pc);
}
@test fn void conditional_cleanup_rejects_every_candidate_even_after_original_descriptor_closes(){
    pinned_case(0,false);pinned_case(1,false);pinned_case(0,true);pinned_case(1,true);
}
fn values::Program conditional(bool source){
    var values::Program u=base();u.body.function_count=1;
    if(source){let usize live=emit(ref mut u,95,2,0,0);}
    let usize branch=u.body.count;let usize test=emit(ref mut u,20,0,2,branch+3);
    let usize left=emit(ref mut u,95,0,0,0);let usize jump=emit(ref mut u,19,0,branch+4,0);
    let usize right=emit(ref mut u,19,0,branch+4,0);
    let usize marker=u.body.count;let usize action=emit(ref mut u,19,0,marker+1,0);
    retire(ref mut u,0);if(source){retire(ref mut u,2);}
    let usize ret=emit(ref mut u,8,0,0,0);finish(ref mut u,0,0,0,0,0,1);return u;
}
fn void misuse(u8 op){
    var values::Program u=conditional(false);let usize pc=find(ref u,115,0)-1;
    if(op==99 || op==100){rewrite(ref mut u,pc,op,if(op==99){1}else{3},0,if(op==99){0}else{1});}
    else if(op==101){rewrite(ref mut u,pc,op,0,1,3);}
    else if(op==88){rewrite(ref mut u,pc,op,1,0,0);}
    else if(op==91){rewrite(ref mut u,pc,op,5,0,1);}
    else if(op==105){rewrite(ref mut u,pc,op,0,0,1);u.body.code[pc*8+4]=1;}
    else if(op==102 || op==103 || op==104){rewrite(ref mut u,pc,op,4,0,if(op==102){3}else{1});}
    else{rewrite(ref mut u,pc,op,0,0,0);}
    let values::Prepared p=prepared(ref u);assert(values::instruction(ref u,ref p,pc,0).is_ok);
    owner_error(ref u,pc);
}
@test fn void uncertain_owners_cannot_read_move_drop_mutate_wrap_or_begin_another_view(){
    misuse(99);misuse(100);misuse(101);misuse(88);misuse(90);misuse(91);
    misuse(102);misuse(103);misuse(104);misuse(105);
}
fn void overwrite_case(bool moved){
    var values::Program u=conditional(true);let usize pc=find(ref u,115,0)-1;
    rewrite(ref mut u,pc,if(moved){88}else{95},0,if(moved){2}else{0},0);owner_error(ref u,pc);
}
@test fn void publication_needs_definite_dead_even_when_a_different_owner_is_definitely_live(){
    overwrite_case(false);overwrite_case(true);
}
fn void missing_retire(bool first){
    var values::Program u=joined();let usize pc=find(ref u,115,if(first){0}else{1});
    rewrite(ref mut u,pc,19,0,pc+1,0);owner_error(ref u,find(ref u,8,0));
}
@test fn void terminal_success_requires_no_possible_owner_on_either_branch(){
    missing_retire(true);missing_retire(false);
}
fn void cleanup_case(bool live,bool twice,bool reuse){
    var values::Program u=base();u.body.function_count=1;
    if(live){let usize root=emit(ref mut u,95,0,0,0);}retire(ref mut u,0);
    if(twice){retire(ref mut u,0);}
    if(reuse){let usize fresh=emit(ref mut u,95,0,0,0);let usize drop=emit(ref mut u,90,0,0,0);}
    let usize ret=emit(ref mut u,8,0,0,0);finish(ref mut u,0,0,0,0,0,1);admitted(ref u);
}
@test fn void cleanup_accepts_dead_live_and_repeated_cleanup_then_allows_fresh_publication(){
    cleanup_case(false,false,false);cleanup_case(true,false,false);
    cleanup_case(false,true,true);cleanup_case(true,true,true);
}
fn void nonbuffer_case(bool wrapper){
    var values::Program u=conditional(false);let usize left=find(ref u,95,0);
    rewrite(ref mut u,left,if(wrapper){91}else{97},if(wrapper){5}else{6},if(wrapper){0}else{1},0);
    // The second incoming edge must reject, even if the eventual terminator fails.
    owner_error(ref u,left+2);
}
@test fn void forward_joins_reject_scalar_and_buffer_containing_wrapper_uncertainty(){
    nonbuffer_case(false);nonbuffer_case(true);
}
fn void callee(ref mut values::Program u,usize arity){
    u.body.function_count=2;u.types[8]=1;u.functions[8]=1;
    let usize start=u.body.count;let usize registers=u.body.registers;
    let usize first=parameter(u,9);
    if(arity==2){u.types[9]=1;u.functions[9]=1;let usize second=parameter(u,10);
        let usize drop=emit(u,90,9,0,0);}
    let usize ret=emit(u,94,0,8,0);finish(u,1,start,registers,arity,9,0);
}
fn void call_case(usize mode){
    var values::Program u=conditional(true);let usize pc=find(ref u,115,0)-1;
    rewrite(ref mut u,pc,93,if(mode==2){0}else{1},1,0);
    u.body.call_count=1;u.body.call_arities[0]=if(mode==2){1}else{2};
    u.body.call_args[0]=if(mode==1){208}else{210};
    if(mode!=2){u.body.call_args[1]=if(mode==1){210}else{208};}
    callee(ref mut u,if(mode==2){1}else{2});
    // mode0 fails after staging the first move, mode1 before staging it;
    // mode2 stages a valid move then fails result publication into uncertainty.
    owner_error(ref u,pc);owner_error(ref u,pc);
}
@test fn void call_rejects_uncertain_actuals_in_both_orders_and_uncertain_results_after_staged_moves(){
    call_case(0);call_case(1);call_case(2);
}
fn void map_case(bool duplicate,bool unused){
    var values::Program u=base();u.body.function_count=1;
    let usize root=emit(ref mut u,95,0,0,0);let usize call=emit(ref mut u,93,0,1,0);
    if(duplicate){let usize again=emit(ref mut u,93,0,1,0);}
    retire(ref mut u,0);let usize ret=emit(ref mut u,8,0,0,0);finish(ref mut u,0,0,0,0,0,1);
    u.body.call_count=if(unused){2}else{1};u.body.call_arities[0]=1;u.body.call_args[0]=208;
    if(unused){u.body.call_arities[1]=1;u.body.call_args[8]=208;}callee(ref mut u,1);
    if(duplicate || unused){owner_error(ref u,if(duplicate){call+1}else{0});}else{admitted(ref u);}
}
@test fn void call_maps_still_require_one_live_site_and_allow_result_into_consumed_actual(){
    map_case(false,false);map_case(true,false);map_case(false,true);
}
fn void return_case(bool uncertain,bool extra){
    var values::Program u=base();u.body.function_count=2;u.types[0]=0;u.types[1]=0;
    u.types[8]=1;u.functions[8]=1;u.types[9]=1;u.functions[9]=1;
    let usize main=emit(ref mut u,8,0,0,0);finish(ref mut u,0,0,0,0,0,1);
    let usize start=u.body.count;let usize regs=u.body.registers;
    let usize truth=ok(ir::boolean(ref mut u.body,true,0));
    if(!uncertain){let usize definite=emit(ref mut u,95,8,0,0);}
    let usize branch=u.body.count;let usize test=emit(ref mut u,20,0,truth,branch+3);
    let usize root=emit(ref mut u,95,if(uncertain){8}else{9},0,0);
    let usize jump=emit(ref mut u,19,0,branch+4,0);let usize right=emit(ref mut u,19,0,branch+4,0);
    if(!uncertain && !extra){retire(ref mut u,9);}
    let usize ret=emit(ref mut u,94,0,8,0);finish(ref mut u,1,start,regs,0,9,0);
    if(uncertain || extra){owner_error(ref u,ret);}else{admitted(ref u);}
}
@test fn void return94_needs_a_definite_returned_owner_and_no_other_possible_owner(){
    return_case(true,false);return_case(false,true);return_case(false,false);
}
fn void nested(ref mut values::Program u){
    let usize outer=u.body.count;let usize test=emit(u,20,0,2,0);
    let usize inner=u.body.count;let usize test2=emit(u,20,0,2,inner+4);
    let usize a=emit(u,95,0,0,0);let usize av=begin(u,0,0);let usize j=emit(u,19,0,inner+6,0);
    let usize b=emit(u,95,1,0,0);let usize bv=begin(u,0,1);
    let usize out=emit(u,19,0,0,0);let usize third=u.body.count;
    let usize c=emit(u,95,2,0,0);let usize cv=begin(u,0,2);let usize join=u.body.count;
    u.body.code[outer*8+3]=byte(third);u.body.code[out*8+2]=byte(join);
    close(u,0);retire(u,0);retire(u,1);retire(u,2);
}
fn void nested_loop(bool repeat){
    var values::Program u=base();u.body.function_count=1;let usize header=u.body.count;
    if(repeat){let usize test=emit(ref mut u,20,0,2,0);}
    nested(ref mut u);
    if(repeat){let usize back=emit(ref mut u,22,0,header,0);let usize exit=u.body.count;
        u.body.code[header*8+3]=byte(exit);}
    let usize ret=emit(ref mut u,8,0,0,0);finish(ref mut u,0,0,0,0,0,1);admitted(ref u);
}
@test fn void nested_branch_local_roots_clean_before_exact_dead_loop_backedges(){
    nested_loop(false);nested_loop(true);
}
fn void backedge_case(bool possible_only,bool restore){
    var values::Program u=conditional(false);let usize pc=find(ref u,115,0)-1;
    if(possible_only){
        // Header at the join has must=0, may={0}. Cleanup changes only may.
        rewrite(ref mut u,pc,115,0,0,0);let usize back=find(ref u,115,1);
        rewrite(ref mut u,back,22,0,pc,0);owner_error(ref u,back);
    }else{
        // Header before the diamond has must=may=0; a possibly live backedge
        // cannot widen it. Restoring Dead first is the positive control.
        let usize back=find(ref u,8,0);rewrite(ref mut u,back,22,0,4,0);
        if(!restore){let usize clear=find(ref u,115,0);rewrite(ref mut u,clear,19,0,clear+1,0);owner_error(ref u,back);}
        else{admitted(ref u);}
    }
}
@test fn void loop_backedges_must_restore_both_owner_planes_without_inference(){
    backedge_case(true,false);backedge_case(false,false);backedge_case(false,true);
}
fn void malformed(usize mode){
    var values::Program u=conditional(false);let usize pc=find(ref u,115,0);
    if(mode<6){u.body.code[pc*8+2+mode]=1;}
    else if(mode==6){u.body.code[pc*8+1]=16;}
    else if(mode==7){u.body.code[pc*8+1]=5;} // Option<Buffer> is not Buffer.
    else if(mode==8){u.body.code[pc*8+1]=6;} // Scalar is not Buffer.
    else if(mode==9){u.body.code[pc*8+1]=15;} // Absent site.
    else if(mode==10){u.body.function_count=2;u.types[8]=1;u.functions[8]=1;u.body.code[pc*8+1]=8;
        let usize start=u.body.count;let usize regs=u.body.registers;
        let usize ret=emit(ref mut u,82,0,0,0);finish(ref mut u,1,start,regs,0,0,13);
    }else{
        // Malformed cleanup must reject even if an earlier jump hides it.
        rewrite(ref mut u,pc-1,19,0,pc+1,0);u.body.code[pc*8+7]=1;
    }
    let values::Prepared p=prepared(ref u);assert(!values::instruction(ref u,ref p,pc,0).is_ok);
    owner_error(ref u,pc);
}
@test fn void cleanup115_requires_exact_local_buffer_and_zero_operands_and_reserved_bytes(){
    assert(values::operation(115) && !values::operation(116));
    var usize mode=0;while(mode<12){malformed(mode);mode+=1;}
}
