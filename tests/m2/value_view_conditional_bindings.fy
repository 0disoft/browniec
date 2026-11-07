module tests::m2::value_view_conditional_bindings;
import value_source_bindings as bindings;
import value_source_control as branches;
import value_source_loops as loops;
import value_source_ops as ops;
import value_source_context as context;
import value_buffer_source as buffers;
import value_buffer_source_ops as buffer_ops;
import value_source_propagation as propagation;
import value_view_source as view_source;
import value_view_bindings as views;
import value_ir as values;
import value_properties as properties;
import ir as ir;
import errors as errors;
import lexer as lexer;
import locals as locals;
import std::vec as vec;

// Compiler metadata helpers only: no executable ownership proof is claimed.
fn usize ok(Result<usize,errors::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn void rejected(Result<usize,errors::Error> result,u8 kind,usize at){
    assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}});
}
fn values::Program base(){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.body.function_count=2;unit.catalog.count=4;
    unit.catalog.nodes[0]=properties::Node{.kind=4,.first=0,.second=0,.extent=0};
    unit.catalog.nodes[1]=properties::Node{.kind=1,.first=1,.second=0,.extent=0};
    unit.catalog.nodes[2]=properties::Node{.kind=1,.first=10,.second=0,.extent=0};
    unit.catalog.nodes[3]=properties::Node{.kind=6,.first=0,.second=2,.extent=0};
    return unit;
}
fn usize arm(ref mut values::Program unit,ref mut bindings::State state,
    usize destination,usize zero,bool retained,usize at){
    let usize root=ok(ops::empty_buffer(unit,state,0,at));
    let usize actual=ok(views::begin(unit,ref mut state.views,root,zero,zero,at));
    var usize result=actual;
    if(retained){result=ok(views::call_result(unit,ref mut state.views,actual,at));
        let usize closed=ok(bindings::close_view(unit,state,actual,at));}
    let usize moved=ok(views::move_to(unit,ref mut state.views,result,destination,at));
    return root;
}
fn usize conditional(ref mut values::Program unit,ref mut bindings::State state,
    usize zero,bool retained,usize at){
    let usize destination=ok(views::reserve(unit,ref mut state.views,at));
    let bindings::Snapshot entry=bindings::snapshot(state);
    var vec::Vec<bindings::Snapshot> paths=vec::empty<bindings::Snapshot>();
    let usize left_root=arm(unit,state,destination,zero,retained,at);
    let usize left_jump=ok(ir::raw(ref mut unit.body,19,0,0,0,at));
    let branches::Exit left=switch(branches::capture(ref mut paths,state,false,left_jump,at)){
        case .ok(v):{v}case .err(_):{assert(false);branches::Exit{.path=128,.terminal=true,.jump=0}}
    };
    let usize selected=ok(bindings::begin_alternative(unit,state,ref entry,at));
    let usize right_root=arm(unit,state,destination,zero,retained,at);
    let usize right_jump=ok(ir::raw(ref mut unit.body,19,0,0,0,at));
    let branches::Exit right=switch(branches::capture(ref mut paths,state,false,right_jump,at)){
        case .ok(v):{v}case .err(_):{assert(false);branches::Exit{.path=128,.terminal=true,.jump=0}}
    };
    assert(switch(branches::join(unit,state,ref mut paths,ref left,ref right,at)){
        case .ok(terminal):{!terminal}case .err(_):{false}
    });
    let usize released=ok(views::unreserve(ref mut state.views,destination,at));
    assert(left_root!=right_root && views::local_roots(ref state.views,destination)!=0);
    return destination;
}
fn void canonical(ref values::Program unit,usize pc,u8 op,usize owner){
    assert(unit.body.code[pc*8]==op && unit.body.code[pc*8+1] as usize==owner);
    var usize i=2;while(i<8){assert(unit.body.code[pc*8+i]==0);i+=1;}
}

@test fn void unretained_conditional_roots_survive_join_and_last_alias_releases_each_possible_slot(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize zero=ok(ir::integer(ref mut unit.body,0,12,1));
    let usize joined=conditional(ref mut unit,ref mut state,zero,false,2);
    assert(state.live==0 && state.maybe==3 && state.next==2);
    assert(views::local_roots(ref state.views,joined)==3 && views::retained_roots(ref state.views,joined)==0);
    assert(ops::preflight(ref unit,ref state,3).is_ok);
    let usize alias=ok(views::alias(ref mut unit,ref mut state.views,joined,4));
    let usize before=unit.body.count;
    let usize closed=ok(bindings::close_view(ref mut unit,ref mut state,joined,5));
    assert(unit.body.count==before+1 && state.maybe==3);
    let usize last=ok(bindings::close_view(ref mut unit,ref mut state,alias,6));
    assert(unit.body.count==before+4 && state.live==0 && state.maybe==0);
    canonical(ref unit,before+2,115,1);canonical(ref unit,before+3,115,0);
    let usize repeated=ok(bindings::drop(ref mut unit,ref mut state,0,7));
    assert(unit.body.count==before+4 && views::count(ref state.views)==0);
}

@test fn void retained_conditional_snapshots_and_nested_cleanup_preserve_the_outer_possible_roots(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize zero=ok(ir::integer(ref mut unit.body,0,12,10));
    let usize outer=conditional(ref mut unit,ref mut state,zero,true,11);
    let bindings::Snapshot baseline=bindings::snapshot(ref state);
    assert(baseline.state.maybe==3 && views::retained_roots(ref state.views,outer)==3);
    let usize named=ok(bindings::declare_view(ref unit,ref mut state,b"view",0,4,outer,false));
    let bindings::Snapshot named_baseline=bindings::snapshot(ref state);
    let usize inner=conditional(ref mut unit,ref mut state,zero,false,12);
    assert(state.live==0 && state.maybe==15 && views::local_roots(ref state.views,inner)==12);
    let usize before=unit.body.count;
    let usize closed=ok(bindings::close_views_since(ref mut unit,ref mut state,ref named_baseline.state.views,13));
    assert(closed==1 && unit.body.count==before+3 && state.maybe==3);
    canonical(ref unit,before+1,115,3);canonical(ref unit,before+2,115,2);
    let usize scope=ok(bindings::leave_scope(ref mut unit,ref mut state,0,14));
    assert(scope==2 && state.names.count==0 && state.maybe==0);
    let usize restored=ok(bindings::select_path(ref unit,ref mut state,ref named_baseline,15));
    assert(state.maybe==3 && state.live==0 && state.next==4 && state.views.names[named]!=0);
    let usize reset=ok(bindings::begin_alternative(ref unit,ref mut state,ref named_baseline,16));
    assert(state.maybe==3 && views::retained_roots(ref state.views,outer)==3);
    let usize final=ok(bindings::close_views(ref mut unit,ref mut state,17));
    assert(final==1 && state.maybe==0 && state.live==0);
}

@test fn void possible_owner_is_never_a_definite_operand_or_a_publish_destination(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize a=ok(ops::empty_buffer(ref mut unit,ref mut state,0,20));
    let usize b=ok(ops::empty_buffer(ref mut unit,ref mut state,0,20));
    state.live=2;state.maybe=1;let usize before=unit.body.count;
    rejected(bindings::initialize(ref unit,ref mut state,a,21),3,21);
    rejected(bindings::move_value(ref mut unit,ref mut state,a,b,22),3,22);
    rejected(bindings::move_value(ref mut unit,ref mut state,b,a,23),3,23);
    rejected(bindings::consume(ref unit,ref mut state,a,24),3,24);
    rejected(bindings::handle(ref unit,ref mut state,a,25),3,25);
    rejected(bindings::enter_function(ref unit,ref mut state,1,26),3,26);
    rejected(bindings::declare(ref unit,ref mut state,b"owner",0,5,a,0),3,0);
    rejected(buffer_ops::scalar(ref mut unit,ref state,99,a,0,27),3,27);
    let context::Value owner=context::owned(0,a);
    assert(!buffers::begin(ref unit,ref mut state,owner,false,28).is_ok);
    assert(!buffers::begin(ref unit,ref mut state,owner,true,29).is_ok);
    assert(state.live==2 && state.maybe==1 && state.reads==0 && state.writes==0 && unit.body.count==before);
    let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,a,30));
    canonical(ref unit,before,115,a);
    let usize moved=ok(bindings::move_value(ref mut unit,ref mut state,a,b,31));
    assert(state.live==1 && state.maybe==0);
    let usize definite=ok(bindings::drop(ref mut unit,ref mut state,a,32));
    canonical(ref unit,before+2,90,a);
}

fn void malformed(ref mut values::Program unit,ref mut bindings::State state){
    let bindings::Snapshot before=bindings::snapshot(state);
    let usize pc=unit.body.count;unit.body.code[pc*8]=177;unit.body.offsets[pc]=999;
    rejected(bindings::authenticate(unit,state,40),3,40);
    assert(!ops::preflight(unit,state,41).is_ok);
    rejected(bindings::drop(unit,state,0,42),3,42);
    rejected(bindings::close_views(unit,state,43),3,43);
    rejected(bindings::leave_scope(unit,state,0,44),3,44);
    assert(unit.body.count==pc && unit.body.code[pc*8]==177 && unit.body.offsets[pc]==999);
    assert(state.live==before.state.live && state.maybe==before.state.maybe && state.pending==before.state.pending);
    assert(state.reads==before.state.reads && state.writes==before.state.writes && state.names.count==before.state.names.count);
    assert(views::same(ref state.views,ref before.state.views));
}
@test fn void malformed_possible_masks_loans_results_names_types_and_functions_reject_atomically(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize a=ok(ops::empty_buffer(ref mut unit,ref mut state,0,39));
    let bindings::Snapshot valid=bindings::snapshot(ref state);
    state.maybe=1;malformed(ref mut unit,ref mut state);
    state.live=0;state.maybe=65536;malformed(ref mut unit,ref mut state);
    state.maybe=2;malformed(ref mut unit,ref mut state);
    state.maybe=1;state.reads=1;malformed(ref mut unit,ref mut state);
    state.reads=0;state.writes=1;malformed(ref mut unit,ref mut state);
    state.writes=0;state.enforce_results=true;state.pending=1;malformed(ref mut unit,ref mut state);
    state.pending=0;state.enforce_results=false;
    unit.types[0]=2;malformed(ref mut unit,ref mut state);
    unit.types[0]=1;unit.functions[0]=1;malformed(ref mut unit,ref mut state);unit.functions[0]=0;
    let usize restored=ok(bindings::select_path(ref unit,ref mut state,ref valid,45));
    let usize named=ok(bindings::declare_mut(ref unit,ref mut state,b"root",0,4,a,0));
    state.live=0;state.maybe=1;malformed(ref mut unit,ref mut state);
}

@test fn void final_alias_capacity_and_loan_failures_leave_all_descriptors_and_owner_bits_unchanged(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize zero=ok(ir::integer(ref mut unit.body,0,12,50));
    let usize joined=conditional(ref mut unit,ref mut state,zero,false,51);
    let bindings::Snapshot before=bindings::snapshot(ref state);
    let usize count=unit.body.count;unit.body.count=254;
    unit.body.code[254*8]=177;unit.body.offsets[254]=999;
    rejected(bindings::close_view(ref mut unit,ref mut state,joined,52),4,52);
    rejected(bindings::close_views(ref mut unit,ref mut state,53),4,53);
    assert(unit.body.count==254 && unit.body.code[254*8]==177 && unit.body.offsets[254]==999);
    assert(state.maybe==3 && views::same(ref state.views,ref before.state.views));
    unit.body.count=count;state.reads=1;
    rejected(bindings::close_view(ref mut unit,ref mut state,joined,54),3,54);
    assert(unit.body.count==count && state.maybe==3 && views::same(ref state.views,ref before.state.views));
    state.reads=0;let usize closed=ok(bindings::close_view(ref mut unit,ref mut state,joined,55));
    assert(state.maybe==0 && unit.body.count==count+3);
}

@test fn void named_owner_uncertainty_and_unreferenced_differences_reject_without_join_resurrection(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize root=ok(ops::empty_buffer(ref mut unit,ref mut state,0,60));
    let usize named=ok(bindings::declare_mut(ref unit,ref mut state,b"root",0,4,root,0));
    let usize zero=ok(ir::integer(ref mut unit.body,0,12,60));
    let usize view=ok(views::begin(ref mut unit,ref mut state.views,root,zero,zero,61));
    let bindings::Snapshot left=bindings::snapshot(ref state);
    let usize closed=ok(bindings::close_view(ref mut unit,ref mut state,view,62));
    let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,root,63));
    let bindings::Snapshot right=bindings::snapshot(ref state);
    let usize pc=unit.body.count;rejected(bindings::merge(ref unit,ref mut state,ref left,64),3,64);
    assert(state.live==0 && state.maybe==0 && unit.body.count==pc && views::same(ref state.views,ref right.state.views));
    // Same descriptor shape can still not turn a named owner into possible-only.
    state.views=left.state.views;state.live=1;
    var bindings::Snapshot forged=bindings::snapshot(ref state);forged.state.live=0;
    rejected(bindings::merge(ref unit,ref mut state,ref forged,65),3,65);
    assert(state.live==1 && state.maybe==0);
    let usize detached=ok(bindings::close_view(ref mut unit,ref mut state,view,66));
    let bindings::Snapshot present=bindings::snapshot(ref state);
    let usize consumed=ok(bindings::drop(ref mut unit,ref mut state,root,67));
    rejected(bindings::merge(ref unit,ref mut state,ref present,68),3,68);
    assert(state.live==0 && state.maybe==0);
}

@test fn void valid_arm_states_cannot_merge_a_named_owner_into_possible_liveness_or_escape_its_scope(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize root=ok(ops::empty_buffer(ref mut unit,ref mut state,0,70));
    let usize named=ok(bindings::declare_mut(ref unit,ref mut state,b"root",0,4,root,0));
    let usize zero=ok(ir::integer(ref mut unit.body,0,12,70));
    let usize destination=ok(views::reserve(ref unit,ref mut state.views,71));
    let bindings::Snapshot entry=bindings::snapshot(ref state);
    let usize direct=ok(views::begin(ref mut unit,ref mut state.views,root,zero,zero,72));
    let usize moved=ok(views::move_to(ref mut unit,ref mut state.views,direct,destination,72));
    let bindings::Snapshot left=bindings::snapshot(ref state);
    let usize pc=unit.body.count;
    rejected(bindings::leave_scope(ref mut unit,ref mut state,0,73),3,73);
    assert(unit.body.count==pc && state.names.count==1 && state.live==1 && state.maybe==0);
    let usize selected=ok(bindings::begin_alternative(ref unit,ref mut state,ref entry,74));
    let usize anonymous=arm(ref mut unit,ref mut state,destination,zero,false,75);
    let usize dropped=ok(bindings::drop(ref mut unit,ref mut state,root,76));
    assert(bindings::authenticate(ref unit,ref state,77).is_ok);
    let bindings::Snapshot right=bindings::snapshot(ref state);
    rejected(bindings::merge(ref unit,ref mut state,ref left,78),3,78);
    assert(state.live==2 && state.maybe==0 && views::same(ref state.views,ref right.state.views));
}

@test fn void loop_backedges_compare_possible_bits_exactly_and_never_restore_a_missing_owner(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize root=ok(ops::empty_buffer(ref mut unit,ref mut state,0,80));
    state.live=0;state.maybe=1;
    var vec::Vec<bindings::Snapshot> paths=vec::empty<bindings::Snapshot>();
    var loops::State flow=loops::empty();
    let usize begun=ok(loops::begin(ref unit,ref mut state,ref mut paths,ref mut flow,0,false,81));
    state.maybe=0;let usize before=unit.body.count;
    rejected(loops::repeat(ref mut unit,ref mut state,ref paths,ref mut flow,82),3,82);
    assert(state.live==0 && state.maybe==0 && unit.body.count==before);
    let usize selected=ok(branches::select(ref unit,ref mut state,ref paths,flow.frames[0].entry,83));
    assert(state.live==0 && state.maybe==1);
    let usize repeated=ok(loops::repeat(ref mut unit,ref mut state,ref paths,ref mut flow,84));
    assert(state.maybe==1 && state.live==0 && unit.body.code[before*8]==22);
}

@test fn void mixed_definite_and_possible_roots_preserve_per_origin_retention_and_use_the_right_drop(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize common=ok(ops::empty_buffer(ref mut unit,ref mut state,0,90));
    let usize zero=ok(ir::integer(ref mut unit.body,0,12,90));
    let usize destination=ok(views::reserve(ref unit,ref mut state.views,91));
    let bindings::Snapshot entry=bindings::snapshot(ref state);
    let usize direct=ok(views::begin(ref mut unit,ref mut state.views,common,zero,zero,92));
    let usize moved=ok(views::move_to(ref mut unit,ref mut state.views,direct,destination,92));
    let bindings::Snapshot left=bindings::snapshot(ref state);
    let usize selected=ok(bindings::begin_alternative(ref unit,ref mut state,ref entry,93));
    let usize possible=arm(ref mut unit,ref mut state,destination,zero,true,94);
    let usize merged=ok(bindings::merge(ref unit,ref mut state,ref left,95));
    assert(state.live==1 && state.maybe==2 && views::local_roots(ref state.views,destination)==3);
    assert(views::retained_roots(ref state.views,destination)==2);
    let bindings::Snapshot before=bindings::snapshot(ref state);
    var bindings::Snapshot bad=bindings::snapshot(ref state);bad.state.maybe=65536;
    rejected(bindings::select_path(ref unit,ref mut state,ref bad,96),3,96);
    rejected(bindings::begin_alternative(ref unit,ref mut state,ref bad,97),3,97);
    assert(state.live==1 && state.maybe==2 && views::same(ref state.views,ref before.state.views));
    let usize pc=unit.body.count;
    let usize closed=ok(bindings::close_views(ref mut unit,ref mut state,98));
    assert(closed==1 && state.live==0 && state.maybe==0 && unit.body.count==pc+3);
    canonical(ref unit,pc+1,115,possible);canonical(ref unit,pc+2,90,common);
}

// Snapshot only the mutable scalar/type planes, never the large Program or
// record catalogs. Poisoned instruction storage is deliberately not executable:
// every byte/offset must survive rejected compiler-helper admission untouched.
struct RejectionMark {
    usize count; usize registers; usize constants; usize catalog;
    i64[128] constant_values; u8[128] scalar_types; bool[128] slots;
    u8[16] value_types; u8[16] functions;
}
fn RejectionMark rejection_mark(ref mut values::Program unit){
    {
        let ref mut ir::Program body=ref mut unit.body;
        var usize i=0;while(i<2048){body.code[i]=177;i+=1;}
        i=0;while(i<256){body.offsets[i]=999;i+=1;}
    }
    let ref ir::Program body=ref unit.body;
    let ref properties::Catalog catalog=ref unit.catalog;
    return RejectionMark{.count=body.count,.registers=body.registers,
        .constants=body.constant_count,.catalog=catalog.count,
        .constant_values=body.constants,.scalar_types=body.types,.slots=body.slots,
        .value_types=unit.types,.functions=unit.functions};
}
fn void rejected_unchanged(ref values::Program unit,ref bindings::State state,
    ref bindings::Snapshot before,ref RejectionMark mark){
    let ref ir::Program body=ref unit.body;let ref properties::Catalog catalog=ref unit.catalog;
    assert(body.count==mark.count && body.registers==mark.registers &&
        body.constant_count==mark.constants && catalog.count==mark.catalog);
    var usize i=0;while(i<2048){assert(body.code[i]==177);i+=1;}
    i=0;while(i<256){assert(body.offsets[i]==999);i+=1;}
    i=0;while(i<128){assert(body.constants[i]==mark.constant_values[i] &&
        body.types[i]==mark.scalar_types[i] && body.slots[i]==mark.slots[i]);i+=1;}
    i=0;while(i<16){assert(unit.types[i]==mark.value_types[i] && unit.functions[i]==mark.functions[i]);i+=1;}
    let ref bindings::State prior=ref before.state;
    let ref locals::Table names=ref state.names;let ref locals::Table prior_names=ref prior.names;
    assert(state.next==prior.next && state.live==prior.live && state.maybe==prior.maybe &&
        state.reads==prior.reads && state.writes==prior.writes && state.pending==prior.pending &&
        state.enforce_results==prior.enforce_results && state.tracking==prior.tracking &&
        state.kills==prior.kills && state.generated==prior.generated && state.required==prior.required);
    assert(names.count==prior_names.count && names.function==prior_names.function &&
        names.pending_places==prior_names.pending_places && views::same(ref state.views,ref prior.views));
    i=0;while(i<64){assert(state.bindings[i]==prior.bindings[i] &&
        names.begins[i]==prior_names.begins[i] && names.ends[i]==prior_names.ends[i] &&
        names.registers[i]==prior_names.registers[i] && names.mutable[i]==prior_names.mutable[i]);i+=1;}
}
fn void rejected_value(Result<context::Value,errors::Error> result,u8 kind,usize at){
    assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}});
}
fn void reject_function_exit(ref mut values::Program unit,ref mut bindings::State state,u8 kind,usize at){
    let bindings::Snapshot before=bindings::snapshot(state);
    let RejectionMark mark=rejection_mark(unit);
    rejected(propagation::finish_function(unit,state,16,at),kind,at);
    rejected_unchanged(unit,state,ref before,ref mark);
}

fn void function_exit_preflights_possible_loans_and_capacity_before_resetting_valid_loans(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize root=ok(ops::empty_buffer(ref mut unit,ref mut state,0,100));
    state.live=0;state.maybe=1;state.reads=1;
    reject_function_exit(ref mut unit,ref mut state,3,101);
    state.reads=0;state.writes=1;
    reject_function_exit(ref mut unit,ref mut state,3,102);
    // A valid outstanding loan must also survive cleanup-capacity rejection.
    state.live=1;state.maybe=0;state.reads=1;state.writes=0;
    let usize count=unit.body.count;unit.body.count=256;
    reject_function_exit(ref mut unit,ref mut state,4,103);
    unit.body.count=count;state.reads=0;state.writes=1;
    unit.body.count=256;reject_function_exit(ref mut unit,ref mut state,4,104);
    unit.body.count=count;state.writes=0;
    let buffers::Reference loan=switch(buffers::begin(ref unit,ref mut state,context::owned(0,root),false,105)){
        case .ok(v):{v}case .err(_):{assert(false);buffers::none()}
    };
    assert(state.reads==1 && !loan.writing);
    let usize finished=ok(propagation::finish_function(ref mut unit,ref mut state,16,106));
    assert(state.live==0 && state.maybe==0 && state.reads==0 && state.writes==0 &&
        state.pending==0 && state.names.count==0 && unit.body.count==count+1);
    canonical(ref unit,count,90,root);
}

fn void reject_loan_end(ref mut values::Program unit,ref mut bindings::State state,buffers::Reference loan,usize at){
    let bindings::Snapshot before=bindings::snapshot(state);
    let RejectionMark mark=rejection_mark(unit);
    rejected(buffers::end(state,loan,at),3,at);
    rejected_unchanged(unit,state,ref before,ref mark);
}
fn void loan_end_rejects_possible_current_restored_and_out_of_cursor_masks_then_restores_valid_nested_loans(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize first=ok(ops::empty_buffer(ref mut unit,ref mut state,0,110));
    let usize second=ok(ops::empty_buffer(ref mut unit,ref mut state,0,110));
    var buffers::Reference loan=buffers::Reference{.slot=first,.temporary=true,.writing=false,.reads=2,.writes=0};
    state.live=1;state.maybe=2;state.reads=3;
    reject_loan_end(ref mut unit,ref mut state,loan,111);
    state.reads=1;reject_loan_end(ref mut unit,ref mut state,loan,112);
    loan.reads=0;state.maybe=4;
    reject_loan_end(ref mut unit,ref mut state,loan,113);
    state.maybe=0;state.next=17;
    reject_loan_end(ref mut unit,ref mut state,loan,114);
    state.next=0;reject_loan_end(ref mut unit,ref mut state,loan,115);
    state.next=2;state.live=1;state.maybe=2;state.reads=2;state.writes=1;
    loan.writing=true;loan.reads=2;
    reject_loan_end(ref mut unit,ref mut state,loan,116);
    state.live=3;state.maybe=0;state.reads=0;state.writes=0;
    let buffers::Reference outer=switch(buffers::begin(ref unit,ref mut state,context::owned(0,first),false,117)){
        case .ok(v):{v}case .err(_):{assert(false);buffers::none()}
    };
    let buffers::Reference inner=switch(buffers::begin(ref unit,ref mut state,context::owned(0,second),true,118)){
        case .ok(v):{v}case .err(_):{assert(false);buffers::none()}
    };
    assert(state.reads==1 && state.writes==2);
    let usize count=unit.body.count;
    let usize inner_closed=ok(buffers::end(ref mut state,inner,119));
    assert(state.reads==1 && state.writes==0 && unit.body.count==count);
    let usize outer_closed=ok(buffers::end(ref mut state,outer,120));
    assert(state.reads==0 && state.writes==0 && state.live==3 && unit.body.count==count);
    let usize finished=ok(propagation::finish_function(ref mut unit,ref mut state,16,121));
    assert(state.live==0 && state.maybe==0 && unit.body.count==count+2);
    canonical(ref unit,count,90,second);canonical(ref unit,count+1,90,first);
}

fn void reject_capture(ref mut values::Program unit,ref mut bindings::State state,context::Value input,usize at){
    let bindings::Snapshot before=bindings::snapshot(state);
    let RejectionMark mark=rejection_mark(unit);
    rejected(view_source::capture(unit,state,input,at),3,at);
    rejected_unchanged(unit,state,ref before,ref mark);
}
fn void reject_view_begin(ref mut values::Program unit,ref mut bindings::State state,buffers::Reference loan,usize at){
    let bindings::Snapshot before=bindings::snapshot(state);
    let RejectionMark mark=rejection_mark(unit);
    rejected_value(view_source::begin(unit,state,loan,65,at),3,at);
    rejected_unchanged(unit,state,ref before,ref mark);
}
fn void frontend_view_capture_and_begin_authenticate_before_alias_publication_or_loan_reset(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize root=ok(ops::empty_buffer(ref mut unit,ref mut state,0,130));
    let usize zero=ok(ir::integer(ref mut unit.body,0,12,130));
    let usize view=ok(views::begin(ref mut unit,ref mut state.views,root,zero,zero,131));
    let usize name=ok(bindings::declare_view(ref unit,ref mut state,b"v",0,1,view,false));
    state.maybe=65536;
    reject_capture(ref mut unit,ref mut state,view_source::value(view,name),132);
    reject_capture(ref mut unit,ref mut state,view_source::value(view,64),133);
    state.reads=1;
    let buffers::Reference loan=buffers::Reference{.slot=root,.temporary=true,.writing=false,.reads=0,.writes=0};
    reject_view_begin(ref mut unit,ref mut state,loan,134);
    state.maybe=1;
    reject_view_begin(ref mut unit,ref mut state,loan,135);
}

fn void reject_view_length(ref mut values::Program unit,ref mut bindings::State state,context::Value input){
    let ref u8[] text=b".len";var lexer::State s=lexer::empty();
    let usize next=ok(lexer::next(text,ref mut s));
    let lexer::State parser=lexer::snapshot(ref s);
    let bindings::Snapshot before=bindings::snapshot(state);
    let RejectionMark mark=rejection_mark(unit);
    rejected_value(view_source::length(text,ref mut s,unit,state,input),3,0);
    rejected_unchanged(unit,state,ref before,ref mark);
    assert(s.cursor==parser.cursor && s.begin==parser.begin && s.end==parser.end &&
        s.tokens==parser.tokens && s.kind==parser.kind && s.value==parser.value &&
        s.min_magnitude==parser.min_magnitude && s.context==parser.context);
}
fn void reject_view_index(ref mut values::Program unit,ref mut bindings::State state,
    usize view,usize zero,bool range,usize at){
    let bindings::Snapshot before=bindings::snapshot(state);
    let RejectionMark mark=rejection_mark(unit);
    rejected_value(view_source::indexed(unit,state,view,zero,zero,range,at),3,at);
    rejected_unchanged(unit,state,ref before,ref mark);
}
fn void frontend_view_length_read_and_range_reject_possible_state_before_ir_descriptor_or_parser_changes(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize root=ok(ops::empty_buffer(ref mut unit,ref mut state,0,140));
    let usize zero=ok(ir::integer(ref mut unit.body,0,12,140));
    let usize view=ok(views::begin(ref mut unit,ref mut state.views,root,zero,zero,141));
    let usize name=ok(bindings::declare_view(ref unit,ref mut state,b"v",0,1,view,false));
    state.maybe=65536;
    reject_view_length(ref mut unit,ref mut state,view_source::value(view,name));
    reject_view_length(ref mut unit,ref mut state,view_source::value(view,64));
    reject_view_index(ref mut unit,ref mut state,view,zero,false,142);
    reject_view_index(ref mut unit,ref mut state,view,zero,true,143);
    state.maybe=1;
    reject_view_index(ref mut unit,ref mut state,view,zero,false,144);
    reject_view_index(ref mut unit,ref mut state,view,zero,true,145);
}

// Retain separate Program scopes while keeping this focused batch within its
// thirty-group limit. These wrappers create no large local snapshots.
@test fn void loan_and_function_exit_admission_is_atomic_for_possible_owners(){
    function_exit_preflights_possible_loans_and_capacity_before_resetting_valid_loans();
    loan_end_rejects_possible_current_restored_and_out_of_cursor_masks_then_restores_valid_nested_loans();
}
@test fn void frontend_view_admission_precedes_parser_ir_and_descriptor_changes(){
    frontend_view_capture_and_begin_authenticate_before_alias_publication_or_loan_reset();
    frontend_view_length_read_and_range_reject_possible_state_before_ir_descriptor_or_parser_changes();
}
