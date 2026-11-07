module tests::m2::value_view_join_ir;
import value_ir as values;
import value_properties as properties;
import value_view_flow as views;
import verifier as verifier;
import ir as ir;
import errors as errors;

// Hand-authored CFGs, independent of source origin inference and lowering.
// Admission evidence only: ranges use distinct scalar endpoints but no VM runs.
// Keep one large Program constructor per helper, for default development stacks.
fn usize ok(Result<usize,errors::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn u8 byte(usize n){assert(n<256);var usize i=0;var u8 b=0;while(i<n){i+=1;b+=1;}return b;}
fn properties::Node node(u8 kind,u8 first,u8 second){
    return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};
}
fn values::Program base(){
    var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0],.functions=[0;16],
        .parameters=[0;128],.results=[0;16]};
    u.catalog.count=1;u.catalog.nodes[0]=node(4,0,0);
    // r0=answer, r1=0usize, r2=1usize, r3=2usize, r4=condition, r5=42u8.
    let usize answer=ok(ir::literal(ref mut u.body,42,0));
    let usize zero=ok(ir::integer(ref mut u.body,0,12,0));
    let usize one=ok(ir::integer(ref mut u.body,1,12,0));
    let usize two=ok(ir::integer(ref mut u.body,2,12,0));
    let usize condition=ok(ir::boolean(ref mut u.body,true,0));
    let usize value=ok(ir::integer(ref mut u.body,42,10,0));return u;
}
fn usize emit(ref mut values::Program u,u8 op,usize dst,usize a,usize b){
    return ok(ir::raw(ref mut u.body,op,dst,a,b,0));
}
fn usize window(ref mut values::Program u,u8 op,usize dst,usize a,usize lo,usize hi){
    let usize pc=emit(u,op,dst,a,lo);u.body.code[pc*8+4]=byte(hi);return pc;
}
fn void close(ref mut values::Program u,usize id){let usize pc=emit(u,109,id,0,0);}
fn void drop(ref mut values::Program u,usize id){let usize pc=emit(u,90,id,0,0);}
fn void finish(ref mut values::Program u,usize f,usize pc,usize register,usize arity,u8 result){
    let usize end=u.body.count;let usize registers=u.body.registers;
    u.body.starts[f]=pc;u.body.ends[f]=end;u.body.register_starts[f]=register;
    u.body.register_ends[f]=registers;u.body.arities[f]=arity;u.results[f]=result;
    u.body.return_types[f]=if(f==0){1}else{0};
}
fn usize parameter(ref mut values::Program u,u8 encoded,u8 tag){
    let usize r=u.body.registers;u.body.registers+=1;u.body.types[r]=tag;u.parameters[r]=encoded;return r;
}
fn usize find(ref values::Program u,u8 op,usize ordinal){
    var usize pc=0;var usize n=0;while(pc<u.body.count){if(u.body.code[pc*8]==op){
        if(n==ordinal){return pc;}n+=1;}pc+=1;}assert(false);return 0;
}
fn void jump(ref mut values::Program u,usize pc,usize target){
    var usize i=0;while(i<8){u.body.code[pc*8+i]=0;i+=1;}
    u.body.code[pc*8]=19;u.body.code[pc*8+2]=byte(target);
}
fn values::Prepared prepared(ref values::Program u){return switch(values::prepare(u)){
    case .ok(p):{p}case .err(_):{assert(false);prepared(u)}
};}
fn void admitted(ref values::Program u){assert(verifier::inspect_values(u).is_ok);}
fn void rejected(ref values::Program u){assert(!verifier::inspect_values(u).is_ok);}
fn void origin_error(ref values::Program u,usize pc){
    let values::Prepared p=prepared(u);
    assert(switch(views::inspect(u,ref p)){
        case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}
    });rejected(u);
}
fn void shape_error(ref values::Program u,usize pc,usize f){
    let values::Prepared p=prepared(u);
    assert(!values::instruction(u,ref p,pc,f).is_ok);rejected(u);
}

// Both arms normalize their temporary into view2 with MOVE108. At the join,
// view0/view1 are Dead and view2 carries root0; windows [0,1] and [1,2] differ.
fn void diamond(ref mut values::Program u,usize condition,usize zero,usize one,usize two,
    usize parent,usize scratch){
    let usize branch=u.body.count;let usize test=emit(u,20,0,condition,branch+5);
    let usize left=window(u,106,scratch,parent,zero,one);close(u,parent);
    let usize moved=emit(u,108,2,scratch,0);let usize joined=emit(u,19,0,branch+8,0);
    let usize right=window(u,106,scratch,parent,one,two);close(u,parent);
    let usize other=emit(u,108,2,scratch,0);
}
fn void cycle(ref mut values::Program u,usize condition){
    let usize header=u.body.count;let usize exit=emit(u,20,0,condition,header+4);
    let usize alias=emit(u,107,3,2,0);close(u,3);let usize back=emit(u,22,0,header,0);
}
fn values::Program local(bool loop){
    var values::Program u=base();u.body.function_count=1;
    let usize root=emit(ref mut u,95,0,0,0);let usize other=emit(ref mut u,95,1,0,0);
    let usize begin=window(ref mut u,105,0,0,1,3);
    diamond(ref mut u,4,1,2,3,0,1);if(loop){cycle(ref mut u,4);}
    close(ref mut u,2);drop(ref mut u,0);drop(ref mut u,1);
    let usize returned=emit(ref mut u,8,0,0,0);finish(ref mut u,0,0,0,0,0);return u;
}

@test fn void same_root_different_windows_join_into_dead_destination_and_keep_public_gates(){
    let values::Program u=local(false);admitted(ref u);
    assert(!verifier::inspect(ref u.body).is_ok && !verifier::verify(ref u.body).is_ok);
    assert(!verifier::inspect_reborrow_calls(ref u.body).is_ok);
    assert(!verifier::inspect_slice_places(ref u.body).is_ok);
}
fn void divergent_case(usize mode){
    var values::Program u=local(false);let usize right=find(ref u,106,1);
    let usize move=find(ref u,108,1);let usize join=move+1;
    if(mode==0){u.body.code[right*8]=105;u.body.code[right*8+2]=1;}
    else if(mode==1){jump(ref mut u,move,join);}
    else{u.body.code[move*8+1]=3;}
    // Reject at the edge into the already established destination state;
    // even a later CLOSE/RETURN must never erase an inconsistent join.
    origin_error(ref u,move);
}
@test fn void joins_reject_different_roots_missing_origin_and_different_live_ids(){
    var usize mode=0;while(mode<3){divergent_case(mode);mode+=1;}
}
fn void stale_case(usize mode){
    var values::Program u=local(false);let usize moved=find(ref u,108,1);
    if(mode==0){u.body.code[moved*8+2]=15;origin_error(ref u,moved);}
    else if(mode==1){let usize closed=moved-1;jump(ref mut u,closed,moved);
        u.body.code[moved*8+1]=0;origin_error(ref u,moved);}
    else{
        let usize pc=find(ref u,109,2);let usize dst=u.body.registers;
        u.body.registers+=1;u.body.register_ends[0]+=1;u.body.types[dst]=12;
        u.body.code[pc*8]=110;u.body.code[pc*8+1]=byte(dst);u.body.code[pc*8+2]=1;
        origin_error(ref u,pc); // scratch1 was moved on both paths
    }
}
@test fn void joins_reject_stale_move_stale_read_and_moving_over_a_live_parent(){
    var usize mode=0;while(mode<3){stale_case(mode);mode+=1;}
}

// Replace the last CLOSE with a pinned owner action. Each operation is valid
// in shape and reaches the origin plane, rather than failing on its encoding.
fn void pinned_case(u8 op){
    var values::Program u=local(false);let usize pc=find(ref u,109,2);
    jump(ref mut u,pc,pc+1);u.body.code[pc*8]=op;
    if(op==101){u.body.code[pc*8+1]=0;u.body.code[pc*8+2]=1;u.body.code[pc*8+3]=5;}
    else if(op==90){u.body.code[pc*8+1]=0;u.body.code[pc*8+2]=0;}
    else{u.body.code[pc*8+1]=2;u.body.code[pc*8+2]=0;}
    let values::Prepared proof=prepared(ref u);assert(values::instruction(ref u,ref proof,pc,0).is_ok);
    origin_error(ref u,pc);
}
@test fn void joined_views_pin_the_owner_against_write_drop_and_move(){
    pinned_case(101);pinned_case(90);pinned_case(88);
    // Positive control: the same owner can be moved once the joined alias closes.
    var values::Program u=local(false);let usize pc=find(ref u,90,0);
    u.body.code[pc*8]=88;u.body.code[pc*8+1]=2;u.body.code[pc*8+2]=0;
    let usize next=pc+1;u.body.code[next*8+1]=2;
    // owner1 remains live; turn RETURN into native failure (which drains it).
    let usize returned=find(ref u,8,0);u.body.code[returned*8]=25;admitted(ref u);
}

fn void malformed_case(usize mode){
    var values::Program u=local(false);let usize moved=find(ref u,108,0);
    if(mode<4){u.body.code[moved*8+4+mode]=1;shape_error(ref u,moved,0);}
    else if(mode==4){u.body.code[moved*8+3]=1;shape_error(ref u,moved,0);}
    else if(mode==5){u.body.code[moved*8+1]=16;shape_error(ref u,moved,0);}
    else if(mode==6){u.body.code[moved*8+2]=16;shape_error(ref u,moved,0);}
    else if(mode==7){let u8 source=u.body.code[moved*8+2];u.body.code[moved*8+1]=source;shape_error(ref u,moved,0);}
    else if(mode==8){u.parameters[127]=17;assert(!values::prepare(ref u).is_ok);rejected(ref u);}
    else{
        // Scalar register zero is live but is not authority for view15.
        u.body.code[moved*8+2]=15;origin_error(ref u,moved);
    }
}
@test fn void join_move_reserved_bytes_and_scalar_view_namespaces_are_independent(){
    var usize mode=0;while(mode<10){malformed_case(mode);mode+=1;}
}
fn void loop_case(usize mode){
    var values::Program u=local(true);let usize back=find(ref u,22,0);
    if(mode==0){admitted(ref u);return;}
    if(mode==1){let usize close=find(ref u,109,2);u.body.code[close*8+1]=2;}
    else if(mode==2){let usize alias=find(ref u,107,0);u.body.code[alias*8]=108;}
    else{u.body.code[back*8+2]=byte(back+1);}
    if(mode<3){origin_error(ref u,back);}else{rejected(ref u);}
}
@test fn void loop_backedges_require_the_exact_joined_origin_and_live_set(){
    var usize mode=0;while(mode<4){loop_case(mode);mode+=1;}
}

// Two actuals can share one caller root but remain distinct formal origins.
// selected is the argument ordinal (0/1), not the local view destination (2).
fn void formal_diamond(ref mut values::Program u,usize condition,usize zero,usize one,usize two,
    usize selected,bool conflict){
    let usize branch=u.body.count;let usize test=emit(u,20,0,condition,branch+6);
    let usize left=window(u,106,3,selected,zero,one);close(u,0);close(u,1);
    let usize moved=emit(u,108,2,3,0);let usize joined=emit(u,19,0,branch+10,0);
    let usize right=window(u,106,3,if(conflict){1-selected}else{selected},one,two);
    close(u,0);close(u,1);let usize other=emit(u,108,2,3,0);
}
fn values::Program formal(usize selected,bool same_actual,bool conflict){
    var values::Program u=base();u.body.function_count=2;
    let usize root=emit(ref mut u,95,0,0,0);let usize other=emit(ref mut u,95,1,0,0);
    let usize first=window(ref mut u,105,0,0,1,3);
    let usize second=window(ref mut u,105,1,if(same_actual){0}else{1},1,3);
    u.body.call_count=1;u.body.call_arities[0]=3;
    u.body.call_args[0]=224;u.body.call_args[1]=225;u.body.call_args[2]=4;
    let usize called=emit(ref mut u,114,2,1,0);
    close(ref mut u,0);close(ref mut u,1);close(ref mut u,2);
    drop(ref mut u,0);drop(ref mut u,1);let usize returned=emit(ref mut u,8,0,0,0);
    finish(ref mut u,0,0,0,0,0);
    let usize start=u.body.count;let usize registers=u.body.registers;
    let usize formal0=parameter(ref mut u,17,0);let usize formal1=parameter(ref mut u,18,0);
    let usize condition=parameter(ref mut u,0,2);
    let usize zero=ok(ir::integer(ref mut u.body,0,12,0));
    let usize one=ok(ir::integer(ref mut u.body,1,12,0));
    let usize two=ok(ir::integer(ref mut u.body,2,12,0));
    formal_diamond(ref mut u,condition,zero,one,two,selected,conflict);
    let usize result=emit(ref mut u,113,0,2,0);
    finish(ref mut u,1,start,registers,3,byte(selected+17));return u;
}
fn void formal_accepted(usize selected,bool same_actual){let values::Program u=formal(selected,same_actual,false);admitted(ref u);}
@test fn void selected_formal_windows_join_return_and_call_result_inherit_the_actual_root(){
    formal_accepted(0,false);formal_accepted(1,false);formal_accepted(0,true);formal_accepted(1,true);
}
fn void formal_case(usize mode){
    var values::Program u=formal(0,mode==1 || mode==12,mode>=11);let usize ret=find(ref u,113,0);
    let usize called=find(ref u,114,0);let usize start=u.body.register_starts[1];
    if(mode<2){u.results[1]=18;origin_error(ref u,ret);}
    else if(mode==2){u.body.call_args[0]=239;origin_error(ref u,called);}
    else if(mode==3){u.body.code[called*8+1]=0;origin_error(ref u,called);}
    else if(mode==4){let usize close=find(ref u,109,2);jump(ref mut u,close,close+1);
        origin_error(ref u,find(ref u,90,0));}
    else if(mode==5){u.parameters[start+1]=17;assert(!values::prepare(ref u).is_ok);rejected(ref u);}
    else if(mode==6){u.results[1]=19;assert(!values::prepare(ref u).is_ok);rejected(ref u);}
    else if(mode==7){u.body.call_args[0]=208;shape_error(ref u,called,0);}
    else if(mode==8){u.body.code[ret*8+7]=1;shape_error(ref u,ret,1);}
    else if(mode==9){u.body.code[called*8+6]=1;shape_error(ref u,called,0);}
    else if(mode==10){u.body.code[ret*8+2]=15;origin_error(ref u,ret);}
    else{origin_error(ref u,find(ref u,108,1));} // distinct formals, same live IDs
}
@test fn void joined_returns_reject_wrong_selected_formal_stale_actuals_and_forged_metadata(){
    var usize mode=0;while(mode<13){formal_case(mode);mode+=1;}
}
