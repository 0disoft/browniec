module tests::m2::value_view_origin_sets_ir;
import value_ir as values;
import value_properties as properties;
import value_view_flow as views;
import verifier as verifier;
import ir as ir;
import errors as errors;

// Hand-authored guest encodings; no compiler inference or native VM authority.
// Small helper scopes keep Program temporaries off a single native test frame.
fn usize ok(Result<usize,errors::Error> r){return switch(r){
    case .ok(n):{n}case .err(_):{assert(false);0}
};}
fn u8 byte(usize n){assert(n<256);var usize i=0;var u8 b=0;while(i<n){i+=1;b+=1;}return b;}
fn properties::Node node(u8 kind,u8 first,u8 second){
    return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};
}
fn values::Program base(){
    var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[1,1,1,1,4,5,0,0,0,0,0,0,0,0,0,0],.functions=[0;16],
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
fn void drop(ref mut values::Program u,usize root){let usize pc=emit(u,90,root,0,0);}
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
fn void admitted(ref values::Program u){assert(verifier::inspect_values(u).is_ok);}
fn void origin_error(ref values::Program u,usize pc){
    let values::Prepared p=prepared(u);
    assert(switch(views::inspect(u,ref p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});
    assert(!verifier::inspect_values(u).is_ok);
}
fn void shape_error(ref values::Program u,usize pc){
    let values::Prepared p=prepared(u);assert(!values::instruction(u,ref p,pc,0).is_ok);
    origin_error(u,pc);
}

// Both paths establish view2, but its root is either owner0 or owner1.
// alias0: direct; alias106/107/108: range/alias/move to view3 then close view2.
fn values::Program joined(u8 alias){
    var values::Program u=base();u.body.function_count=1;
    let usize root=emit(ref mut u,95,0,0,0);let usize other=emit(ref mut u,95,1,0,0);
    let usize third=emit(ref mut u,95,2,0,0);
    let usize branch=u.body.count;let usize test=emit(ref mut u,20,0,2,branch+4);
    let usize left=begin(ref mut u,0,0);let usize moved=emit(ref mut u,108,2,0,0);
    let usize jump=emit(ref mut u,19,0,branch+6,0);
    let usize right=begin(ref mut u,0,1);let usize other_move=emit(ref mut u,108,2,0,0);
    if(alias!=0){let usize copy=emit(ref mut u,alias,3,2,if(alias==106){1}else{0});
        if(alias==106){u.body.code[copy*8+4]=1;}if(alias!=108){close(ref mut u,2);}}
    let usize marker=u.body.count;let usize action=emit(ref mut u,19,0,marker+1,0);
    close(ref mut u,if(alias==0){2}else{3});
    drop(ref mut u,0);drop(ref mut u,1);drop(ref mut u,2);
    let usize ret=emit(ref mut u,8,0,0,0);finish(ref mut u,0,0,0,0,0,1);return u;
}
fn void union_case(u8 alias,usize owner,bool allowed){
    var values::Program u=joined(alias);let usize pc=find(ref u,19,1);
    rewrite(ref mut u,pc,101,owner,1,3);
    if(allowed){admitted(ref u);}else{origin_error(ref u,pc);}
}
@test fn void candidate_roots_survive_range_alias_move_and_only_unrelated_owners_can_write(){
    var usize kind=0;while(kind<4){let u8 alias=if(kind==0){0}else{byte(105+kind)};
        union_case(alias,0,false);union_case(alias,1,false);union_case(alias,2,true);kind+=1;}
}
fn void owning_action(u8 op,usize owner){
    var values::Program u=joined(0);let usize pc=find(ref u,19,1);
    if(op==90){rewrite(ref mut u,pc,op,owner,0,0);}
    else if(op==88){rewrite(ref mut u,pc,op,3,owner,0);}
    else if(op==91){rewrite(ref mut u,pc,op,5,owner,1);}
    else{rewrite(ref mut u,pc,op,4,owner,if(op==102){3}else if(op==103){1}else{2});}
    let values::Prepared p=prepared(ref u);assert(values::instruction(ref u,ref p,pc,0).is_ok);
    origin_error(ref u,pc);
}
@test fn void every_candidate_is_pinned_against_drop_move_payload_push_reserve_and_append(){
    var usize owner=0;while(owner<2){owning_action(90,owner);owning_action(88,owner);
        owning_action(91,owner);owning_action(102,owner);owning_action(103,owner);owning_action(104,owner);owner+=1;}
}
fn void append_view_case(usize owner){
    var values::Program u=joined(0);let usize pc=find(ref u,19,1);
    rewrite(ref mut u,pc,112,4,owner,2);
    if(owner<2){origin_error(ref u,pc);}else{
        // APPEND_VIEW's Result is live until failure cleanup. No return obligation
        // is bypassed: this positive control ends with canonical native failure.
        let usize ret=find(ref u,8,0);rewrite(ref mut u,ret,25,0,0,0);admitted(ref u);
    }
}
@test fn void append_view_reads_the_union_but_cannot_mutate_any_candidate_root(){
    append_view_case(0);append_view_case(1);append_view_case(2);
}

// Header first sees {root0}. The backedge replaces view0 with root1; an earlier
// write of root1 must then be rechecked. With two descriptors the root2 pin only
// reaches view0 on the second backedge; the exit closes its sibling first.
fn values::Program loop(bool delayed,bool write,bool escaped_write){
    var values::Program u=base();u.body.function_count=1;
    let usize root=emit(ref mut u,95,0,0,0);let usize other=emit(ref mut u,95,1,0,0);
    let usize third=emit(ref mut u,95,2,0,0);let usize view=begin(ref mut u,0,0);
    if(delayed){let usize sibling=begin(ref mut u,1,0);}
    let usize header=u.body.count;let usize condition=emit(ref mut u,20,0,2,0);
    if(write){let usize action=emit(ref mut u,101,if(delayed){2}else{1},1,3);}
    if(delayed){
        close(ref mut u,0);let usize shift=emit(ref mut u,108,0,1,0);
        let usize seed=begin(ref mut u,1,2);
    }else{close(ref mut u,0);let usize replacement=begin(ref mut u,0,1);}
    let usize back=emit(ref mut u,22,0,header,0);let usize exit=u.body.count;
    u.body.code[condition*8+3]=byte(exit);
    if(escaped_write){
        if(delayed){close(ref mut u,1);}let usize action=emit(ref mut u,101,if(delayed){2}else{1},1,3);
    }else if(delayed){close(ref mut u,1);}
    close(ref mut u,0);drop(ref mut u,0);drop(ref mut u,1);drop(ref mut u,2);
    let usize ret=emit(ref mut u,8,0,0,0);finish(ref mut u,0,0,0,0,0,1);return u;
}
fn void loop_case(bool delayed,bool write,bool escaped){
    let values::Program u=loop(delayed,write,escaped);
    if(write || escaped){origin_error(ref u,find(ref u,101,0));}else{admitted(ref u);}
}
@test fn void loop_widening_rechecks_earlier_writes_and_already_processed_exit_successors(){
    loop_case(false,true,false);loop_case(false,false,true);
    loop_case(true,true,false);loop_case(true,false,true);
}
@test fn void repeated_loop_origin_widening_reaches_a_finite_fixed_point(){
    loop_case(false,false,false);loop_case(true,false,false);
}

fn void callee(ref mut values::Program u,usize kind,bool reverse){
    let usize start=u.body.count;let usize registers=u.body.registers;
    if(kind==0){let usize view=parameter(u,17);let usize ret=emit(u,113,0,0,0);
        finish(u,1,start,registers,1,17,0);
    }else if(kind==1){
        let usize owned=parameter(u,7);drop(u,6);let usize ret=emit(u,82,0,0,0);
        finish(u,1,start,registers,1,0,13);
    }else{
        let usize first=parameter(u,if(reverse){7}else{17});let usize second=parameter(u,if(reverse){17}else{7});
        drop(u,6);let usize ret=emit(u,113,0,0,0);finish(u,1,start,registers,2,if(reverse){18}else{17},0);
    }
}
fn void call_case(usize kind,bool reverse){
    var values::Program u=joined(0);u.body.function_count=2;u.types[6]=1;u.functions[6]=1;
    let usize pc=find(ref u,19,1);u.body.call_count=1;
    if(kind==0){
        rewrite(ref mut u,pc,114,3,1,0);u.body.call_arities[0]=1;u.body.call_args[0]=226;
        // Closing the original must not remove the result's complete root set.
        let usize after=find(ref u,90,0);rewrite(ref mut u,after,101,1,1,3);
    }else if(kind==1){
        rewrite(ref mut u,pc,93,0,1,0);u.body.call_arities[0]=1;u.body.call_args[0]=209;
    }else{
        rewrite(ref mut u,pc,114,3,1,0);u.body.call_arities[0]=2;
        u.body.call_args[0]=if(reverse){209}else{226};u.body.call_args[1]=if(reverse){226}else{209};
    }
    callee(ref mut u,kind,reverse);
    origin_error(ref u,if(kind==0){find(ref u,101,0)}else{pc});
}
@test fn void call_results_inherit_complete_masks_and_ordinary_or_mixed_owning_args_cannot_bypass_pins(){
    call_case(0,false);call_case(1,false);call_case(2,false);call_case(2,true);
}
fn void malformed(usize mode){
    var values::Program u=joined(0);let usize pc=find(ref u,105,0);
    if(mode<4){u.body.code[pc*8+4+mode]=255;shape_error(ref u,pc);}
    else if(mode==4){u.body.code[pc*8+1]=24;shape_error(ref u,pc);}
    else if(mode==5){u.body.code[pc*8+2]=24;shape_error(ref u,pc);}
    else if(mode==6){u.parameters[127]=24;assert(!values::prepare(ref u).is_ok);}
    else if(mode==7){u.results[0]=24;assert(!values::prepare(ref u).is_ok);}
    else{
        // Well-shaped dead code still violates canonical reachability, even
        // after all leases and owners have closed on the live path.
        let usize ret=find(ref u,8,0);rewrite(ref mut u,ret,19,0,ret+2,0);
        let usize dead=emit(ref mut u,109,15,0,0);let usize end=emit(ref mut u,8,0,0,0);
        let usize count=u.body.count;u.body.ends[0]=count;origin_error(ref u,dead);
    }
    assert(!verifier::inspect_values(ref u).is_ok);
}
@test fn void origin_masks_are_internal_and_cannot_be_injected_through_guest_bytes_or_metadata(){
    var usize mode=0;while(mode<9){malformed(mode);mode+=1;}
    let values::Program u=joined(0);admitted(ref u);
    assert(!verifier::inspect(ref u.body).is_ok && !verifier::verify(ref u.body).is_ok);
    assert(!verifier::inspect_reborrow_calls(ref u.body).is_ok);
    assert(!verifier::inspect_slice_places(ref u.body).is_ok && !verifier::inspect_aggregate_places(ref u.body).is_ok);
}
