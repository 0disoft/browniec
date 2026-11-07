module tests::m2::value_view_call_execution;
import value_ir as values;
import value_properties as properties;
import verifier as verifier;
import vm as vm;
import ir as ir;
import errors as errors;
import buffer_growth as growth;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn usize ok(Result<usize,errors::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 byte(usize n){assert(n<256);var u8 b=0;var usize i=0;while(i<n){b+=1;i+=1;}return b;}
fn properties::Node node(u8 kind,u8 first,u8 second){return properties::Node{.kind=kind,.first=first,.second=second,.extent=0};}
fn usize emit(ref mut values::Program u,u8 op,usize d,usize a,usize b){return ok(ir::raw(ref mut u.body,op,d,a,b,71));}
fn usize scalar(ref mut values::Program u,u8 op,u8 tag,usize a,usize b){
    let usize d=u.body.registers;u.body.registers+=1;u.body.types[d]=tag;let usize pc=emit(u,op,d,a,b);return d;
}
fn usize window(ref mut values::Program u,u8 op,usize d,usize a,usize lo,usize hi){
    let usize pc=emit(u,op,d,a,lo);u.body.code[pc*8+4]=byte(hi);return pc;
}
fn void close(ref mut values::Program u,usize id){let usize pc=emit(u,109,id,0,0);}
fn void drop(ref mut values::Program u,usize id){let usize pc=emit(u,90,id,0,0);}
fn void check(ref mut values::Program u,usize actual,usize expected){
    let usize eq=ok(ir::emit(ref mut u.body,11,actual,expected,71));
    let usize destination=u.body.count+2;let usize branch=emit(u,21,0,eq,destination);let usize trap=emit(u,25,0,0,0);
}
fn values::Program base(){
    var values::Program u=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[1,4,0,1,1,0,0,0,0,0,0,0,0,0,0,0],.functions=[0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0],
        .parameters=[0;128],.results=[0;16]};
    u.catalog.count=4;u.catalog.nodes[0]=node(4,0,0);u.catalog.nodes[1]=node(1,12,0);
    u.catalog.nodes[2]=node(1,10,0);u.catalog.nodes[3]=node(6,1,2);
    // r0 answer42, r1..4 usize0..3, r5=10u8, r6=42u8.
    let usize answer=ok(ir::literal(ref mut u.body,42,71));let usize zero=ok(ir::integer(ref mut u.body,0,12,71));
    let usize one=ok(ir::integer(ref mut u.body,1,12,71));let usize two=ok(ir::integer(ref mut u.body,2,12,71));
    let usize three=ok(ir::integer(ref mut u.body,3,12,71));let usize ten=ok(ir::integer(ref mut u.body,10,10,71));
    let usize forty_two=ok(ir::integer(ref mut u.body,42,10,71));
    let usize root=emit(ref mut u,95,0,0,0);let usize spare=emit(ref mut u,95,3,0,0);
    let usize a=emit(ref mut u,102,1,0,5);drop(ref mut u,1);
    let usize b=emit(ref mut u,102,1,0,6);drop(ref mut u,1);
    let usize c=emit(ref mut u,102,1,0,5);drop(ref mut u,1);
    let usize view=window(ref mut u,105,0,0,1,4);return u;
}
fn void finish_main(ref mut values::Program u){
    drop(u,0);let usize ret=emit(u,8,0,0,0);
    let usize end=u.body.count;let usize registers=u.body.registers;
    u.body.ends[0]=end;u.body.register_ends[0]=registers;u.body.return_types[0]=1;
}
fn usize formals(ref mut values::Program u,usize f,usize arity){
    let usize start=u.body.registers;let usize pc=u.body.count;u.body.starts[f]=pc;u.body.register_starts[f]=start;
    u.body.arities[f]=arity;u.body.registers+=arity;return start;
}
fn void finish_function(ref mut values::Program u,usize f){
    let usize end=u.body.count;let usize registers=u.body.registers;
    u.body.ends[f]=end;u.body.register_ends[f]=registers;
}
fn void runs(ref values::Program u){
    assert(verifier::inspect_values(u).is_ok);
    assert(switch(vm::run_values(u,8000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void fails(ref values::Program u,usize fuel,growth::Limits quota,u8 kind){
    assert(verifier::inspect_values(u).is_ok);
    assert(switch(vm::run_values(u,fuel,0,quota)){case .ok(_):{false}case .err(e):{e.kind==kind}});
}
// mode0 view result,1 scalar,2 void,3 owning Buffer,4 nested view result.
// Every call mixes a shared actual, two scalar endpoints, an owning move and
// an ordinary answer scalar. Only view results use114; all other modes use93.
fn values::Program mixed(u8 mode,bool bad_bounds,bool empty){
    var values::Program u=base();
    let usize beyond=if(bad_bounds){ok(ir::integer(ref mut u.body,4,12,71))}else{0};
    let usize out=if(mode==1){u.body.registers}else{0};
    if(mode==1){u.body.types[out]=1;u.body.registers+=1;}
    let usize call=emit(ref mut u,if(mode==0 || mode==4){114}else{93},
        if(mode==0 || mode==4){1}else if(mode==3){3}else{out},1,0);
    close(ref mut u,0);
    if(mode==0 || mode==4){
        let usize length=scalar(ref mut u,110,12,1,0);check(ref mut u,length,if(empty){1}else{2});
        if(!empty){let usize read=scalar(ref mut u,111,10,1,1);check(ref mut u,read,6);}
        close(ref mut u,1);
    }else if(mode==1){check(ref mut u,out,0);}
    else if(mode==3){drop(ref mut u,3);}
    // The last returned alias must unpin the root before actual mutation/drop.
    let usize write=emit(ref mut u,101,0,1,6);let usize read=scalar(ref mut u,100,10,0,1);check(ref mut u,read,6);
    finish_main(ref mut u);
    let usize start=formals(ref mut u,1,5);u.parameters[start+1]=17;u.parameters[start+4]=5;
    u.body.types[start]=1;u.body.types[start+2]=12;u.body.types[start+3]=12;
    if(mode==0 || mode==4){
        let usize range=window(ref mut u,106,1,0,start+2,start+3);close(ref mut u,0);drop(ref mut u,4);
        if(mode==4){let usize inner=emit(ref mut u,114,2,2,1);close(ref mut u,1);}
        let usize ret=emit(ref mut u,113,0,if(mode==4){2}else{1},0);u.results[1]=18;
    }else{
        close(ref mut u,0);
        if(mode==3){let usize ret=emit(ref mut u,94,0,4,0);u.results[1]=5;}
        else{drop(ref mut u,4);let usize ret=emit(ref mut u,if(mode==2){82}else{8},0,if(mode==2){0}else{start},0);
            u.body.return_types[1]=if(mode==2){13}else{1};}
    }
    finish_function(ref mut u,1);u.body.function_count=if(mode==4){3}else{2};
    u.body.call_count=if(mode==4){2}else{1};u.body.call_arities[0]=5;
    u.body.call_args[0]=0;u.body.call_args[1]=224;u.body.call_args[2]=if(empty){3}else{2};
    u.body.call_args[3]=if(bad_bounds){byte(beyond)}else{3};u.body.call_args[4]=211;
    if(mode==4){
        let usize inner=formals(ref mut u,2,1);u.parameters[inner]=17;u.results[2]=17;
        let usize zero=ok(ir::integer(ref mut u.body,0,12,71));let usize one=ok(ir::integer(ref mut u.body,if(empty){0}else{1},12,71));
        let usize range=window(ref mut u,106,1,0,zero,one);close(ref mut u,0);
        let usize ret=emit(ref mut u,113,0,1,0);finish_function(ref mut u,2);
        u.body.call_arities[1]=1;u.body.call_args[8]=225;
    }return u;
}
@test fn void mixed_scalar_void_owned_and_view_calls_use_actual_retained_dispatch(){
    var u8 mode=0;while(mode<4){let values::Program u=mixed(mode,false,false);runs(ref u);mode+=1;}
}
@test fn void transitive_return_windows_and_empty_end_outlive_caller_actual_close(){
    let values::Program nested=mixed(4,false,false);runs(ref nested);
    let values::Program empty=mixed(4,false,true);runs(ref empty);
    let values::Program direct=mixed(0,false,false);runs(ref direct);
}
fn values::Program recursive(i64 count,bool repeated){
    var values::Program u=base();drop(ref mut u,3);
    // This fixture has no owning callee formal; avoid an unused slot declaration.
    u.types[4]=0;u.functions[4]=0;
    let usize depth=ok(ir::integer(ref mut u.body,count,12,71));let usize call=emit(ref mut u,114,1,1,0);
    close(ref mut u,0);let usize read=scalar(ref mut u,111,10,1,2);check(ref mut u,read,6);close(ref mut u,1);
    let usize write=emit(ref mut u,101,0,1,6);finish_main(ref mut u);
    let usize arity=if(repeated){3}else{2};let usize start=formals(ref mut u,1,arity);
    let usize counter=start+arity-1;u.parameters[start]=17;
    if(repeated){u.parameters[start+1]=18;}u.body.types[counter]=12;
    let usize zero=ok(ir::integer(ref mut u.body,0,12,71));let usize one=ok(ir::integer(ref mut u.body,1,12,71));
    let usize eq=ok(ir::emit(ref mut u.body,11,counter,zero,71));let usize branch=emit(ref mut u,21,0,eq,0);
    let usize next=ok(ir::emit(ref mut u.body,3,counter,one,71));
    let usize nested=emit(ref mut u,114,if(repeated){2}else{1},1,1);
    close(ref mut u,0);if(repeated){close(ref mut u,1);}
    let usize ret=emit(ref mut u,113,0,if(repeated){2}else{1},0);
    let usize base_pc=u.body.count;if(repeated){close(ref mut u,1);}
    let usize base_ret=emit(ref mut u,113,0,0,0);
    u.body.code[branch*8+3]=byte(base_pc);finish_function(ref mut u,1);
    u.body.function_count=2;u.results[1]=17;u.body.call_count=2;
    u.body.call_arities[0]=byte(arity);u.body.call_args[0]=224;
    u.body.call_arities[1]=byte(arity);u.body.call_args[8]=224;
    if(repeated){u.body.call_args[1]=224;u.body.call_args[9]=224;}
    u.body.call_args[arity-1]=byte(depth);u.body.call_args[8+arity-1]=byte(next);return u;
}
// Keep independently retained large IR candidates in separate native scopes.
// The guest recursion remains bounded VM execution with the default stack.
fn void fuel_and_bounds_edges(){
    let values::Program good=mixed(4,false,false);let values::Program bounds=mixed(0,true,false);
    fails(ref bounds,8000000,limits(),14);runs(ref good);
    var usize low=0;var usize high=8000000;
    while(low+1<high){let usize middle=low+(high-low)/2;
        if(vm::run_values(ref good,middle,0,limits()).is_ok){high=middle;}else{low=middle;}}
    fails(ref good,high-1,limits(),8);runs(ref good);
    // Locate the exact return boundary with a matching trap prefix. At this
    // point the callee's selected descriptor and caller origin are both live.
    var values::Program trapped=mixed(0,false,false);var usize pc=trapped.body.starts[1];
    while(pc<trapped.body.ends[1] && trapped.body.code[pc*8]!=113){pc+=1;}
    assert(pc<trapped.body.ends[1]);trapped.body.code[pc*8]=25;trapped.body.code[pc*8+2]=0;
    assert(verifier::inspect_values(ref trapped).is_ok);
    low=0;high=8000000;
    while(low+1<high){let usize middle=low+(high-low)/2;
        let bool reached=switch(vm::run_values(ref trapped,middle,0,limits())){case .ok(_):{false}case .err(e):{e.kind==5}};
        if(reached){high=middle;}else{low=middle;}}
    fails(ref trapped,high,limits(),5);
    let values::Program direct=mixed(0,false,false);fails(ref direct,high,limits(),8);fails(ref direct,high-1,limits(),8);runs(ref direct);
}
fn void quota_edges(){
    let values::Program good=mixed(4,false,false);var usize low=0;var usize high=1048576;
    while(low+1<high){let usize middle=low+(high-low)/2;
        if(vm::run_values(ref good,8000000,0,growth::Limits{.object=4096,.instance=middle,.engine=middle}).is_ok){high=middle;}else{low=middle;}}
    fails(ref good,8000000,growth::Limits{.object=4096,.instance=high-1,.engine=high-1},13);runs(ref good);
}
fn void frame_edges(){
    let values::Program admitted=recursive(30,false);runs(ref admitted);
    let values::Program too_deep=recursive(31,false);fails(ref too_deep,8000000,limits(),12);runs(ref admitted);
}
fn void registry_edges(){
    // Repeated actuals create distinct formal aliases. At31 live rows the
    // first staged alias fits but the second fails; the batch must not publish.
    let values::Program shared=recursive(14,true);runs(ref shared);
    let values::Program full=recursive(15,true);fails(ref full,8000000,limits(),13);runs(ref shared);
}
@test fn void fuel_bounds_quota_and_recursive_frame_capacity_cleanup_allow_fresh_success(){
    fuel_and_bounds_edges();quota_edges();frame_edges();registry_edges();
}
