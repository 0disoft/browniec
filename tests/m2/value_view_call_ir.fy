module tests::m2::value_view_call_ir;
import value_ir as values;
import value_properties as properties;
import value_flow as owners;
import value_view_flow as views;
import place_ir as places;
import verifier as verifier;
import ir as ir;
import errors as errors;

// Hand-authored bytecode, independent of source candidates and runtime receipts.
// These groups prove admission/rejection only; no guest execution is implied.
fn usize ok(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 byte(usize n){assert(n<256);var u8 b=0;var usize i=0;while(i<n){b+=1;i+=1;}return b;}
fn properties::Node node(u8 kind,u8 first,u8 second){
    return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};
}
fn values::Program base(){
    var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    u.catalog.count=5;u.catalog.nodes[0]=node(4,0,0);u.catalog.nodes[1]=node(1,1,0);
    u.catalog.nodes[2]=node(1,12,0);u.catalog.nodes[3]=node(1,10,0);u.catalog.nodes[4]=node(6,2,3);
    let usize answer=ok(ir::literal(ref mut u.body,42,0));
    let usize zero=ok(ir::integer(ref mut u.body,0,12,0));
    let usize condition=ok(ir::boolean(ref mut u.body,true,0));return u;
}
fn usize emit(ref mut values::Program u,u8 op,usize dst,usize a,usize b){
    return ok(ir::raw(ref mut u.body,op,dst,a,b,0));
}
fn usize window(ref mut values::Program u,u8 op,usize dst,usize a,usize zero){
    let usize pc=emit(u,op,dst,a,zero);u.body.code[pc*8+4]=byte(zero);return pc;
}
fn usize parameter(ref mut values::Program u,u8 encoded,u8 tag){
    let usize r=u.body.registers;u.body.registers+=1;u.body.types[r]=tag;u.parameters[r]=encoded;return r;
}
fn void owner(ref mut values::Program u,usize id,usize f){u.types[id]=1;u.functions[id]=byte(f);}
fn void finish(ref mut values::Program u,usize f,usize pc,usize register,usize arity,u8 result,u8 tag){
    let usize end=u.body.count;let usize registers=u.body.registers;
    u.body.starts[f]=pc;u.body.ends[f]=end;u.body.register_starts[f]=register;
    u.body.register_ends[f]=registers;u.body.arities[f]=arity;u.results[f]=result;u.body.return_types[f]=tag;
}
fn usize call(ref mut values::Program u,u8 op,usize dst,usize target,ref usize[] actuals){
    let usize map=u.body.call_count;u.body.call_count+=1;u.body.call_arities[map]=byte(actuals.len);
    var usize i=0;while(i<actuals.len){u.body.call_args[map*8+i]=byte(actuals[i]);i+=1;}
    return emit(u,op,dst,target,map);
}
fn usize find(ref values::Program u,u8 op,usize ordinal){
    var usize pc=0;var usize n=0;while(pc<u.body.count){if(u.body.code[pc*8]==op){
        if(n==ordinal){return pc;}n+=1;}pc+=1;}assert(false);return 0;
}
fn void jump(ref mut values::Program u,usize pc){
    var usize i=0;while(i<8){u.body.code[pc*8+i]=0;i+=1;}
    u.body.code[pc*8]=19;u.body.code[pc*8+2]=byte(pc+1);
}
fn values::Prepared prepared(ref values::Program u){return switch(values::prepare(u)){
    case .ok(v):{v}case .err(_):{assert(false);prepared(u)}
};}
fn void admitted(ref values::Program u){switch(verifier::inspect_values(u)){
    case .ok(p):{
        assert(p.values.sites.enabled);var usize i=0;
        while(i<128){assert(p.values.sites.parameters[i]==u.parameters[i]);i+=1;}
        i=0;while(i<16){assert(p.values.sites.results[i]==u.results[i]);i+=1;}
    }case .err(_):{assert(false);}
};}
fn void rejected(ref values::Program u){assert(!verifier::inspect_values(u).is_ok);}
fn void origin_error(ref values::Program u,usize pc){
    let values::Prepared p=prepared(u);
    assert(switch(views::inspect(u,ref p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==pc}});
}

fn values::Program transitive(bool selected_place){
    var values::Program u=base();u.body.function_count=3;
    owner(ref mut u,0,0);owner(ref mut u,1,0);owner(ref mut u,3,1);owner(ref mut u,4,2);
    let usize root=emit(ref mut u,95,0,0,0);let usize other=emit(ref mut u,95,1,0,0);
    let usize begin=window(ref mut u,105,0,0,1);
    let usize[3] input=[224,209,2];let usize invoked=call(ref mut u,114,1,1,ref input);
    let usize close0=emit(ref mut u,109,0,0,0);let usize close1=emit(ref mut u,109,1,0,0);
    let usize drop0=emit(ref mut u,90,0,0,0);let usize returned=emit(ref mut u,8,0,0,0);
    finish(ref mut u,0,0,0,0,0,1);
    let usize start=u.body.count;let usize registers=u.body.registers;
    let usize view=parameter(ref mut u,17,0);let usize owned=parameter(ref mut u,4,0);
    let usize condition=parameter(ref mut u,0,2);
    let usize zero=ok(ir::integer(ref mut u.body,0,12,0));
    if(selected_place){
        let usize fill=ok(ir::literal(ref mut u.body,42,0));
        let usize array=ok(ir::array_in(ref mut u.body,1,1,1,true,0));
        let usize init=ok(ir::array_init(ref mut u.body,array,fill,0));
        let usize selected=ok(ir::place_select(ref mut u.body,0,array,zero,0));
    }
    // Both forward and backward edges preserve exact owner and view state.
    let usize loop=u.body.count;let usize exit=emit(ref mut u,20,0,condition,loop+2);
    let usize back=emit(ref mut u,22,0,loop,0);
    let usize[3] forwarded=[224,211,condition];let usize invoked2=call(ref mut u,114,1,2,ref forwarded);
    if(selected_place){let usize ended=emit(ref mut u,86,0,0,0);let usize dropped=emit(ref mut u,37,0,0,0);}
    let usize close=emit(ref mut u,109,0,0,0);let usize moved=emit(ref mut u,108,0,1,0);
    let usize branch=u.body.count;let usize conditional=emit(ref mut u,20,0,condition,branch+4);
    let usize ranged=window(ref mut u,106,1,0,zero);let usize closed=emit(ref mut u,109,0,0,0);
    let usize joined=emit(ref mut u,19,0,branch+5,0);let usize move=emit(ref mut u,108,1,0,0);
    let usize result=emit(ref mut u,113,0,1,0);finish(ref mut u,1,start,registers,3,17,0);
    let usize last=u.body.count;let usize last_register=u.body.registers;
    let usize last_view=parameter(ref mut u,17,0);let usize last_owner=parameter(ref mut u,5,0);
    let usize last_condition=parameter(ref mut u,0,2);
    let usize dropped=emit(ref mut u,90,4,0,0);let usize result2=emit(ref mut u,113,0,0,0);
    finish(ref mut u,2,last,last_register,3,17,0);return u;
}

// Scalar, void and owning results with reference arguments must keep opcode93.
fn values::Program ordinary_result(u8 kind){
    var values::Program u=base();u.body.function_count=2;
    owner(ref mut u,0,0);owner(ref mut u,1,0);owner(ref mut u,2,0);owner(ref mut u,3,1);
    let usize dst=if(kind==0){parameter(ref mut u,0,1)}else if(kind==2){2}else{0};
    let usize root=emit(ref mut u,95,0,0,0);let usize other=emit(ref mut u,95,1,0,0);
    let usize begin=window(ref mut u,105,0,0,1);let usize[2] input=[224,209];
    let usize invoked=call(ref mut u,93,dst,1,ref input);let usize close=emit(ref mut u,109,0,0,0);
    let usize dropped=emit(ref mut u,90,0,0,0);
    if(kind==2){let usize owned=emit(ref mut u,90,2,0,0);}
    let usize returned=emit(ref mut u,8,0,if(kind==0){dst}else{0},0);finish(ref mut u,0,0,0,0,0,1);
    let usize start=u.body.count;let usize registers=u.body.registers;
    let usize view=parameter(ref mut u,17,0);let usize owned=parameter(ref mut u,4,0);
    let usize close2=emit(ref mut u,109,0,0,0);
    if(kind==2){let usize returned2=emit(ref mut u,94,0,3,0);finish(ref mut u,1,start,registers,2,4,0);}
    else{
        let usize dropped2=emit(ref mut u,90,3,0,0);
        if(kind==1){let usize returned2=emit(ref mut u,82,0,0,0);finish(ref mut u,1,start,registers,2,0,13);}
        else{let usize answer=ok(ir::literal(ref mut u.body,42,0));let usize returned2=emit(ref mut u,8,0,answer,0);
            finish(ref mut u,1,start,registers,2,0,1);}
    }return u;
}

fn values::Program two_inputs(bool same_actual){
    var values::Program u=base();u.body.function_count=2;owner(ref mut u,0,0);
    let usize root=emit(ref mut u,95,0,0,0);let usize begin=window(ref mut u,105,0,0,1);
    let usize alias=emit(ref mut u,107,1,0,0);let usize[2] input=[224,if(same_actual){224}else{225}];
    let usize invoked=call(ref mut u,114,2,1,ref input);
    let usize close0=emit(ref mut u,109,0,0,0);let usize close1=emit(ref mut u,109,1,0,0);
    let usize close2=emit(ref mut u,109,2,0,0);let usize dropped=emit(ref mut u,90,0,0,0);
    let usize returned=emit(ref mut u,8,0,0,0);finish(ref mut u,0,0,0,0,0,1);
    let usize start=u.body.count;let usize registers=u.body.registers;
    let usize first=parameter(ref mut u,17,0);let usize second=parameter(ref mut u,18,0);
    let usize closed=emit(ref mut u,109,1,0,0);let usize result=emit(ref mut u,113,0,0,0);
    finish(ref mut u,1,start,registers,2,17,0);return u;
}

fn values::Program recursive(){
    var values::Program u=base();u.body.function_count=2;owner(ref mut u,0,0);
    let usize root=emit(ref mut u,95,0,0,0);let usize begin=window(ref mut u,105,0,0,1);
    let usize[2] input=[224,2];let usize invoked=call(ref mut u,114,1,1,ref input);
    let usize close=emit(ref mut u,109,0,0,0);let usize close1=emit(ref mut u,109,1,0,0);
    let usize dropped=emit(ref mut u,90,0,0,0);let usize returned=emit(ref mut u,8,0,0,0);
    finish(ref mut u,0,0,0,0,0,1);
    let usize start=u.body.count;let usize registers=u.body.registers;
    let usize view=parameter(ref mut u,17,0);let usize condition=parameter(ref mut u,0,2);
    let usize branch=u.body.count;let usize conditional=emit(ref mut u,20,0,condition,branch+4);
    let usize[2] forwarded=[224,condition];let usize recurse=call(ref mut u,114,1,1,ref forwarded);
    let usize closed=emit(ref mut u,109,0,0,0);let usize result=emit(ref mut u,113,0,1,0);
    // A terminal base case, with both paths reachable in the static CFG.
    let usize base_return=emit(ref mut u,113,0,0,0);finish(ref mut u,1,start,registers,2,17,0);return u;
}

fn values::Program local_escape(){
    var values::Program u=base();u.body.function_count=2;owner(ref mut u,0,0);owner(ref mut u,3,1);
    let usize root=emit(ref mut u,95,0,0,0);let usize begin=window(ref mut u,105,0,0,1);
    let usize[1] input=[224];let usize invoked=call(ref mut u,114,1,1,ref input);
    let usize close=emit(ref mut u,109,0,0,0);let usize close1=emit(ref mut u,109,1,0,0);
    let usize dropped=emit(ref mut u,90,0,0,0);let usize returned=emit(ref mut u,8,0,0,0);
    finish(ref mut u,0,0,0,0,0,1);
    let usize start=u.body.count;let usize registers=u.body.registers;let usize view=parameter(ref mut u,17,0);
    let usize zero=ok(ir::integer(ref mut u.body,0,12,0));let usize closed=emit(ref mut u,109,0,0,0);
    let usize local=emit(ref mut u,95,3,0,0);let usize windowed=window(ref mut u,105,1,3,zero);
    let usize result=emit(ref mut u,113,0,1,0);finish(ref mut u,1,start,registers,1,17,0);return u;
}

@test fn void view_call_ir_mixed_transitive_cfg_and_all_result_classes_keep_separate_domains(){
    let values::Program p=transitive(false);admitted(ref p);
    let values::Program with_place=transitive(true);admitted(ref with_place);
    let values::Program repeat=two_inputs(true);admitted(ref repeat);
    let values::Program siblings=two_inputs(false);admitted(ref siblings);
    var u8 kind=0;while(kind<3){let values::Program ordinary=ordinary_result(kind);admitted(ref ordinary);kind+=1;}
    // The returned selector is an argument ordinal, not the callee's view ID.
    var values::Program high=two_inputs(false);let usize first=high.body.register_starts[1];
    high.parameters[first]=32;let usize ret=find(ref high,113,0);high.body.code[ret*8+2]=15;
    admitted(ref high);
    // Every ordinary verifier route continues rejecting the private opcodes.
    assert(!verifier::inspect(ref p.body).is_ok && !verifier::verify(ref p.body).is_ok);
    assert(!verifier::inspect_reborrow_calls(ref p.body).is_ok);
    assert(!verifier::inspect_slice_places(ref p.body).is_ok && !verifier::inspect_aggregate_places(ref p.body).is_ok);
    // Isolate each new opcode from any other private operation on a valid
    // scalar-only program so rejection cannot come from an earlier view opcode.
    var u8 op=113;while(op<=114){var values::Program plain=base();
        let usize returned=emit(ref mut plain,8,0,0,0);plain.body.function_count=1;finish(ref mut plain,0,0,0,0,0,1);
        assert(verifier::inspect(ref plain.body).is_ok);plain.body.code[returned*8]=op;
        assert(!verifier::inspect(ref plain.body).is_ok && !verifier::verify(ref plain.body).is_ok);op+=1;
    }
}

// One constructor site per case keeps large C-backend return temporaries bounded.
fn void forged_case(usize mode){
    var values::Program u=transitive(false);let usize first=u.body.register_starts[1];
    let usize called=find(ref u,114,0);
    if(mode==0){u.parameters[first]=33;}
    else if(mode==1){u.parameters[first+2]=17;u.body.types[first+2]=0;}
    else if(mode==2){u.parameters[first+2]=4;u.body.types[first+2]=0;}
    else if(mode==3){u.results[1]=18;}
    else if(mode==4){u.results[1]=19;}
    else if(mode==5){u.results[1]=20;}
    else if(mode==6){u.results[1]=25;}
    else if(mode==7){u.parameters[first+3]=18;}
    else if(mode==8){u.parameters[127]=17;}
    else if(mode==9){u.results[15]=17;}
    else if(mode==10){u.body.starts[15]=1;}
    else if(mode==11){u.body.call_arities[31]=1;}
    else if(mode==12){u.body.call_args[255]=224;}
    else if(mode==13){u.body.call_args[7]=224;}
    else if(mode==14){u.body.call_count=3;}
    else if(mode==15){u.body.call_args[0]=240;}
    else if(mode==16){u.body.call_args[0]=208;}
    else if(mode==17){u.body.call_args[1]=224;}
    else if(mode==18){u.body.call_args[10]=byte(first);}
    else if(mode==19){u.body.code[called*8]=93;}
    else if(mode==20){u=ordinary_result(2);let usize pc=find(ref u,93,0);u.body.code[pc*8]=114;}
    else if(mode==21){u.body.code[called*8+2]=0;}
    else if(mode==22){u.body.arities[0]=1;u.parameters[0]=17;u.body.types[0]=0;}
    else if(mode<30){let usize ret=find(ref u,113,0);let usize field=mode-22;
        u.body.code[ret*8+field]=if(field==2){16}else{1};}
    else if(mode<34){u.body.code[called*8+mode-26]=1;}
    else if(mode==34){u.body.code[called*8+1]=16;}
    else if(mode==35){
        // Malformed dead instructions are checked before CFG reachability.
        let usize begin=find(ref u,105,0);u.body.code[begin*8]=8;
        u.body.code[begin*8+1]=0;u.body.code[begin*8+2]=0;u.body.code[begin*8+3]=0;u.body.code[begin*8+4]=0;
        u.body.code[called*8+7]=1;let values::Prepared proof=prepared(ref u);
        assert(switch(owners::inspect(ref u,ref proof)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==called}});
        return;
    }else if(mode==36){u.body.call_args[0]=239;origin_error(ref u,called);}
    else if(mode==37){let usize opened=find(ref u,105,0);jump(ref mut u,opened);origin_error(ref u,called);}
    else{u=ordinary_result(1);let usize close=find(ref u,109,1);u.body.code[close*8+1]=15;origin_error(ref u,close);}
    rejected(ref u);
}
@test fn void view_call_ir_forged_metadata_reserved_bytes_and_stale_arguments_reject(){
    var usize mode=0;while(mode<39){forged_case(mode);mode+=1;}
}

@test fn void view_call_ir_conflicts_exact_origins_and_recursive_frame_namespaces_are_independent(){
    var values::Program u=transitive(false);let usize called=find(ref u,114,0);
    u.body.code[called*8+1]=0;origin_error(ref u,called);rejected(ref u); // result cannot overwrite actual
    u=transitive(false);u.body.call_args[1]=208;origin_error(ref u,called);rejected(ref u); // mixed pin + move
    // The reverse argument order also keeps the owner pinned for the entire call.
    u=transitive(false);let usize first=u.body.register_starts[1];u.parameters[first]=4;u.parameters[first+1]=17;
    u.results[1]=18;u.body.call_args[0]=208;u.body.call_args[1]=224;origin_error(ref u,called);rejected(ref u);
    // Aliases from the same caller root remain distinct formal origins inside
    // the callee. Returning its unselected sibling is never authorized.
    u=two_inputs(false);let usize close=find(ref u,109,3);let usize ret=find(ref u,113,0);
    u.body.code[close*8+1]=0;u.body.code[ret*8+2]=1;origin_error(ref u,ret);rejected(ref u);
    u=two_inputs(true);let usize duplicate_close=find(ref u,109,3);let usize duplicate_ret=find(ref u,113,0);
    u.body.code[duplicate_close*8+1]=0;u.body.code[duplicate_ret*8+2]=1;origin_error(ref u,duplicate_ret);rejected(ref u);
    u=two_inputs(false);u.results[1]=18;let usize chosen_close=find(ref u,109,3);let usize chosen_ret=find(ref u,113,0);
    u.body.code[chosen_close*8+1]=0;u.body.code[chosen_ret*8+2]=1;admitted(ref u);
    u=two_inputs(false);let usize leaked=find(ref u,109,3);jump(ref mut u,leaked);
    origin_error(ref u,find(ref u,113,0));rejected(ref u); // unrelated live formal cannot leak
    u=transitive(false);let usize last_drop=find(ref u,90,1);jump(ref mut u,last_drop);rejected(ref u); // owned cell on view return
    // Local Buffer roots cannot escape even when source/result metadata claims
    // an input origin. Verify that rejection in the origin plane itself.
    u=local_escape();let usize local_ret=find(ref u,113,0);
    origin_error(ref u,local_ret);rejected(ref u);
    // CFG joins reject different live IDs/origins rather than merging them.
    u=transitive(false);let usize moved=find(ref u,108,1);u.body.code[moved*8+1]=2;rejected(ref u);
    u=transitive(false);let usize back=find(ref u,22,0);u.body.code[back*8]=109;
    u.body.code[back*8+1]=0;u.body.code[back*8+2]=0;rejected(ref u);
    // Pending places are carried across114 and must end before113.
    u=transitive(true);let usize ended=find(ref u,86,0);jump(ref mut u,ended);
    assert(!places::inspect(ref u.body).is_ok);rejected(ref u);
    let values::Program recursion=recursive();admitted(ref recursion);
    u=recursive();let usize recursive_call=find(ref u,114,1);u.body.code[recursive_call*8+1]=0;
    origin_error(ref u,recursive_call);rejected(ref u);
    u=recursive();u.body.call_args[8]=239;origin_error(ref u,find(ref u,114,1));rejected(ref u);
}
