module tests::m2::value_view_call_bindings;
import value_view_bindings as views;
import value_source_bindings as bindings;
import value_view_source as view_source;
import value_source_ops as ops;
import value_source_propagation as propagation;
import value_ir as values;
import value_properties as properties;
import ir as ir;
import errors as errors;

// Compile-only helper candidates: these tests confer no executable IR authority.
fn usize ok(Result<usize,errors::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn void rejected(Result<usize,errors::Error> result,u8 kind,usize at){
    assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==at}});
}
fn usize named_id(ref bindings::State state,usize index,usize at){
    return switch(view_source::named(state,index,at)){
        case .ok(v):{assert(view_source::reference(v));v.value}
        case .err(_):{assert(false);0}
    };
}
fn values::Program base(){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.body.function_count=2;unit.catalog.count=1;
    unit.catalog.nodes[0]=properties::Node{.kind=4,.first=0,.second=0,.extent=0};
    return unit;
}
fn void enter_formals(ref mut values::Program unit,ref mut bindings::State state){
    let usize entered=ok(bindings::enter_function(unit,state,1,10));
    // Match the parent: enter first, then reserve the complete formal register span.
    let usize start=unit.body.registers;unit.body.register_starts[1]=start;
    unit.body.arities[1]=2;unit.body.registers=start+2;
}

@test fn void formal_authentication_alias_range_and_return_preserve_selected_metadata(){
    let ref u8[] names=b"p q r";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize preceding=ok(ir::integer(ref mut unit.body,0,12,11));
    enter_formals(ref mut unit,ref mut state);let usize entry_count=unit.body.count;
    let usize selected=ok(views::formal(ref mut unit,ref mut state.views,1,1,12));
    let usize other=ok(views::formal(ref mut unit,ref mut state.views,1,0,13));
    assert(selected==0 && other==1 && unit.body.count==entry_count);
    assert(unit.parameters[2]==17 && unit.parameters[1]==18);
    assert(ok(views::origin(ref state.views,selected,14))==17);
    assert(ok(views::origin(ref state.views,other,14))==16);
    assert(ok(views::authenticate(ref unit,ref state.views,14))==1);
    assert(state.next==0 && state.live==0 && !views::pinned(ref state.views,16));
    let usize p=ok(bindings::declare_view(ref unit,ref mut state,names,0,1,selected,false));
    assert(named_id(ref state,p,15)==selected);
    assert(ok(view_source::lexical_origin(ref state,selected,15))==17);
    let usize alias=ok(views::alias(ref mut unit,ref mut state.views,selected,16));
    let usize lo=ok(ir::integer(ref mut unit.body,0,12,17));
    let usize hi=ok(ir::integer(ref mut unit.body,0,12,17));
    let usize range_pc=unit.body.count;
    let usize child=ok(views::range(ref mut unit,ref mut state.views,alias,lo,hi,18));
    assert(unit.body.code[range_pc*8]==106 && unit.body.code[range_pc*8+2] as usize==alias);
    assert(ok(views::origin(ref state.views,child,19))==17);
    let usize q=ok(bindings::declare_view(ref unit,ref mut state,names,2,3,child,true));
    let usize before_call=unit.body.count;
    let usize returned=ok(views::call_result(ref mut unit,ref mut state.views,child,20));
    assert(unit.body.count==before_call && views::retainable(ref state.views,returned));
    let usize r=ok(bindings::declare_view(ref unit,ref mut state,names,4,5,returned,false));
    assert(named_id(ref state,q,21)==child && named_id(ref state,r,21)==returned);
    let usize length=ok(views::scalar(ref mut unit,ref state.views,110,child,0,22));
    let usize read=ok(views::scalar(ref mut unit,ref state.views,111,child,lo,23));
    assert(unit.body.types[length]==12 && unit.body.types[read]==10);
    let bindings::Snapshot saved=bindings::snapshot(ref state);
    assert(views::same(ref state.views,ref saved.state.views));
    unit.results[1]=18;let usize before_return=unit.body.count;let usize registers=unit.body.registers;
    assert(ok(views::take_return(ref unit,ref mut state.views,returned,24))==returned);
    assert(unit.body.count==before_return && !views::live(ref state.views,returned));
    assert(state.views.names[r]==0 && views::live(ref saved.state.views,returned));
    // Cleanup must not emit CLOSE for the detached runtime return descriptor.
    let usize cleaned=ok(propagation::finish_function(ref mut unit,ref mut state,16,25));
    assert(unit.body.count==before_return+4 && state.names.count==0 && state.live==0);
    var usize pc=before_return;while(pc<unit.body.count){
        assert(unit.body.code[pc*8]==109 && unit.body.code[pc*8+1] as usize!=returned);pc+=1;
    }
    let usize terminal=ok(ir::raw(ref mut unit.body,113,0,returned,0,26));
    assert(unit.body.code[terminal*8]==113 && unit.body.code[terminal*8+2] as usize==returned);
    assert(unit.body.registers==registers && unit.parameters[2]==17 && unit.results[1]==18);
    assert(views::count(ref state.views)==0 && state.views.retained==0);
}

@test fn void retained_anonymous_call_origin_survives_aliases_snapshots_rebind_and_last_close(){
    let ref u8[] names=b"r";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize root=ok(ops::empty_buffer(ref mut unit,ref mut state,0,30));
    let usize zero=ok(ir::integer(ref mut unit.body,0,12,31));
    let usize actual=ok(views::begin(ref mut unit,ref mut state.views,root,zero,zero,32));
    let usize before_call=unit.body.count;
    let usize returned=ok(views::call_result(ref mut unit,ref mut state.views,actual,33));
    assert(unit.body.count==before_call && views::retainable(ref state.views,returned));
    let usize actual_closed=ok(bindings::close_view(ref mut unit,ref mut state,actual,34));
    assert(unit.body.count==before_call+1 && state.live==1 && views::pinned(ref state.views,root));
    assert(ok(view_source::lexical_origin(ref state,returned,35))==root);
    let usize name=ok(bindings::declare_view(ref unit,ref mut state,names,0,1,returned,true));
    let bindings::Snapshot baseline=bindings::snapshot(ref state);
    let usize alias=ok(views::alias(ref mut unit,ref mut state.views,returned,36));
    let usize child=ok(views::range(ref mut unit,ref mut state.views,alias,zero,zero,37));
    let usize moved=ok(views::move_to(ref mut unit,ref mut state.views,child,3,38));
    assert(views::retainable(ref state.views,alias) && views::retainable(ref state.views,moved));
    assert(!views::live(ref state.views,child) && !views::retainable(ref state.views,child));
    let usize before_cleanup=unit.body.count;
    assert(ok(bindings::close_views_since(ref mut unit,ref mut state,ref baseline.state.views,39))==2);
    assert(unit.body.count==before_cleanup+2 && state.live==1);
    assert(views::same(ref state.views,ref baseline.state.views));
    let usize merged=ok(bindings::merge(ref unit,ref mut state,ref baseline,40));
    let usize restored=ok(bindings::begin_alternative(ref unit,ref mut state,ref baseline,40));
    assert(views::retainable(ref state.views,returned));
    let usize replacement=ok(views::call_result(ref mut unit,ref mut state.views,returned,41));
    let usize before_assign=unit.body.count;
    assert(ok(bindings::assign_view(ref mut unit,ref mut state,name,replacement,42))==returned);
    assert(unit.body.count==before_assign+2 && state.live==1 && named_id(ref state,name,43)==returned);
    assert(views::retainable(ref state.views,returned) && !views::live(ref state.views,replacement));
    let usize last=ok(views::alias(ref mut unit,ref mut state.views,returned,44));
    let usize before_scope=unit.body.count;
    assert(ok(bindings::leave_scope(ref mut unit,ref mut state,0,45))==0);
    assert(unit.body.count==before_scope+1 && state.names.count==0 && state.live==1);
    assert(views::pinned(ref state.views,root) && views::retainable(ref state.views,last));
    let usize before_last=unit.body.count;
    let usize closed=ok(bindings::close_view(ref mut unit,ref mut state,last,46));
    assert(unit.body.count==before_last+2 && unit.body.code[before_last*8]==109);
    assert(unit.body.code[(before_last+1)*8]==90 && unit.body.code[(before_last+1)*8+1] as usize==root);
    assert(state.live==0 && views::count(ref state.views)==0 && state.views.retained==0);
    // If the last descriptor itself has a lexical name, scope exit owns the DROP.
    let usize next_root=ok(ops::empty_buffer(ref mut unit,ref mut state,0,47));
    let usize next_actual=ok(views::begin(ref mut unit,ref mut state.views,next_root,zero,zero,48));
    let usize next_result=ok(views::call_result(ref mut unit,ref mut state.views,next_actual,49));
    let usize next_closed=ok(bindings::close_view(ref mut unit,ref mut state,next_actual,50));
    let usize next_name=ok(bindings::declare_view(ref unit,ref mut state,names,0,1,next_result,false));
    let usize before_final=unit.body.count;
    assert(ok(bindings::leave_scope(ref mut unit,ref mut state,0,51))==1);
    assert(unit.body.count==before_final+2 && unit.body.code[before_final*8]==109);
    assert(unit.body.code[(before_final+1)*8]==90 && state.live==0 && state.views.retained==0);
}

@test fn void wrong_formal_function_and_legacy_direct_temporary_reject_without_publication(){
    let ref u8[] names=b"bad";
    var values::Program unit=base();var bindings::State state=bindings::empty();
    enter_formals(ref mut unit,ref mut state);
    let usize selected=ok(views::formal(ref mut unit,ref mut state.views,1,0,60));
    let usize other=ok(views::formal(ref mut unit,ref mut state.views,1,1,61));
    let usize wrong=ok(views::alias(ref mut unit,ref mut state.views,other,62));
    let usize name=ok(bindings::declare_view(ref unit,ref mut state,names,0,3,wrong,false));
    unit.results[1]=17;let bindings::Snapshot before=bindings::snapshot(ref state);
    let usize count=unit.body.count;unit.body.code[count*8]=177;unit.body.offsets[count]=999;
    rejected(views::take_return(ref unit,ref mut state.views,wrong,63),3,63);
    rejected(views::formal(ref mut unit,ref mut state.views,0,0,64),3,64);
    rejected(views::formal(ref mut unit,ref mut state.views,1,0,65),3,65);
    rejected(views::formal(ref mut unit,ref mut state.views,1,2,66),3,66);
    assert(views::same(ref state.views,ref before.state.views) && named_id(ref state,name,67)==wrong);
    assert(unit.parameters[0]==17 && unit.parameters[1]==18 && unit.body.count==count);
    unit.parameters[0]=0;
    rejected(views::call_result(ref mut unit,ref mut state.views,selected,68),3,68);
    unit.parameters[0]=17;state.views.function=0;
    rejected(views::alias(ref mut unit,ref mut state.views,selected,69),3,69);
    rejected(bindings::close_views(ref mut unit,ref mut state,70),3,70);
    assert(!view_source::named(ref state,name,70).is_ok);
    state.views.function=1;
    assert(views::same(ref state.views,ref before.state.views) && unit.body.count==count);
    assert(unit.body.code[count*8]==177 && unit.body.offsets[count]==999);
    let usize cleaned=ok(propagation::finish_function(ref mut unit,ref mut state,16,71));
    let usize entered=ok(bindings::enter_function(ref unit,ref mut state,0,72));
    assert(state.views.function==0 && state.views.retained==0);
    let usize register_start=unit.body.registers;unit.body.register_starts[0]=register_start;
    let usize root=ok(ops::empty_buffer(ref mut unit,ref mut state,0,73));
    let usize zero=ok(ir::integer(ref mut unit.body,0,12,74));
    let usize direct=ok(views::begin(ref mut unit,ref mut state.views,root,zero,zero,75));
    let usize alias=ok(views::alias(ref mut unit,ref mut state.views,direct,76));
    let usize before_rejection=unit.body.count;let views::State direct_state=state.views;
    // This is the lexical admission used by bytes::view(ref bytes::empty()).
    rejected(view_source::lexical_origin(ref state,direct,77),3,77);
    rejected(view_source::lexical_origin(ref state,alias,78),3,78);
    unit.results[0]=17;
    rejected(views::take_return(ref unit,ref mut state.views,direct,79),3,79);
    assert(unit.body.count==before_rejection && views::same(ref state.views,ref direct_state));
    assert(!views::retainable(ref state.views,direct) && !views::retainable(ref state.views,alias));
    let usize first_closed=ok(bindings::close_view(ref mut unit,ref mut state,direct,80));
    assert(state.live==1 && views::pinned(ref state.views,root));
    let usize last_closed=ok(bindings::close_view(ref mut unit,ref mut state,alias,81));
    assert(state.live==0 && views::count(ref state.views)==0 && state.names.count==0);
}
