module tests::m2::value_view_join_bindings;
import value_view_bindings as views;
import value_source_bindings as bindings;
import value_ir as values;
import value_properties as properties;
import ir as ir;
import errors as errors;

fn usize ok(Result<usize,errors::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn values::Program base(){
    var values::Program unit=values::Program{.body=ir::empty(),.catalog=properties::empty(),
        .types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};
    unit.body.function_count=1;unit.body.arities[0]=1;unit.body.registers=1;return unit;
}

fn void join_destination_reservation_survives_alternative_selection_without_live_authority(){
    var values::Program unit=base();var bindings::State state=bindings::empty();
    let usize formal=ok(views::formal(ref mut unit,ref mut state.views,0,0,0));
    let bindings::Snapshot entry=bindings::snapshot(ref state);
    let usize destination=ok(views::reserve(ref unit,ref mut state.views,1));
    assert(destination==1 && state.views.reserved==2 && !views::live(ref state.views,destination));
    assert(unit.body.count==0 && views::count(ref state.views)==1);
    let usize left=ok(views::alias(ref mut unit,ref mut state.views,formal,2));
    assert(left==2);let usize moved=ok(views::move_to(ref mut unit,ref mut state.views,left,destination,3));
    let bindings::Snapshot exit=bindings::snapshot(ref state);
    let usize selected=ok(bindings::select_path(ref unit,ref mut state,ref entry,4));
    assert(state.views.reserved==2 && !views::live(ref state.views,destination));
    let usize right=ok(views::alias(ref mut unit,ref mut state.views,formal,5));
    assert(right==left);let usize published=ok(views::move_to(ref mut unit,ref mut state.views,right,destination,6));
    let usize merged=ok(bindings::merge(ref unit,ref mut state,ref exit,7));
    let usize released=ok(views::unreserve(ref mut state.views,destination,8));
    assert(state.views.reserved==0 && views::live(ref state.views,destination));
    let usize closed=ok(views::close_all(ref mut unit,ref mut state.views,9));
    assert(closed==2 && views::count(ref state.views)==0);
}

fn void bounded_reservations_reject_exhaustion_and_invalid_release_before_mutation(){
    var values::Program unit=base();var views::State state=views::empty();
    var usize i=0;while(i<16){assert(ok(views::reserve(ref unit,ref mut state,i))==i);i+=1;}
    let views::State full=state;assert(!views::reserve(ref unit,ref mut state,16).is_ok);
    assert(views::same(ref state,ref full) && unit.body.count==0 && views::count(ref state)==0);
    assert(!views::unreserve(ref mut state,16,17).is_ok && views::same(ref state,ref full));
    let usize released=ok(views::unreserve(ref mut state,7,18));
    let views::State freed=state;assert(!views::unreserve(ref mut state,7,19).is_ok);
    assert(views::same(ref state,ref freed));assert(ok(views::reserve(ref unit,ref mut state,20))==7);
    state.reserved=65536;assert(!views::validate(ref state,21).is_ok);
}

fn void retention_join_meets_shared_roots_and_unions_different_origins_without_losing_reservations(){
    var values::Program unit=base();var views::State state=views::empty();
    let usize formal=ok(views::formal(ref mut unit,ref mut state,0,0,0));
    let usize alias=ok(views::alias(ref mut unit,ref mut state,formal,1));
    let views::State direct=state;state.retained=2;
    assert(!views::same(ref state,ref direct));let usize merged=ok(views::merge(ref mut state,ref direct,2));
    assert(state.retained==0 && views::same(ref state,ref direct));
    var views::State wrong=state;wrong.origins[alias]=18;
    let usize joined=ok(views::merge(ref mut state,ref wrong,3));
    assert(state.origins[alias]==25 && state.sets[alias]==196608);
    assert(ok(views::roots(ref state,alias,3))==196608 && !views::origin(ref state,alias,3).is_ok);
    let views::State union_state=state;wrong=state;wrong.reserved=2;
    assert(!views::merge(ref mut state,ref wrong,4).is_ok && views::same(ref state,ref union_state));
}

fn values::Program local_base(){
    var values::Program unit=base();unit.catalog.count=1;
    unit.catalog.nodes[0]=properties::Node{.kind=4,.first=0,.second=0,.extent=0};
    unit.types[0]=1;unit.types[1]=1;return unit;
}
fn views::State local_union(){
    var views::State state=views::empty();state.origins[0]=25;state.sets[0]=3;return state;
}
fn void rejected(Result<usize,errors::Error> result,usize at){
    assert(switch(result){case .ok(_):{false}case .err(e):{e.kind==3 && e.offset==at}});
}

fn void origin_set_merge_normalizes_singletons_unions_and_preserves_exact_loop_state(){
    var views::State state=views::empty();state.origins[0]=1;state.retained=1;
    let views::State singleton=state;let usize identical=ok(views::merge(ref mut state,ref singleton,10));
    assert(views::same(ref state,ref singleton) && state.sets[0]==0 && state.retained_sets[0]==0);
    assert(ok(views::origin(ref state,0,11))==0 && ok(views::roots(ref state,0,11))==1);
    var views::State other=state;other.origins[0]=2;
    let usize joined=ok(views::merge(ref mut state,ref other,12));
    assert(state.origins[0]==25 && state.sets[0]==3 && views::retained_roots(ref state,0)==3);
    assert(state.retained==1 && state.retained_sets[0]==0 && !views::same(ref state,ref singleton));
    other.origins[0]=24;let usize extended=ok(views::merge(ref mut state,ref other,13));
    assert(ok(views::roots(ref state,0,14))==8388611 && views::local_roots(ref state,0)==3);
    assert(views::retained_roots(ref state,0)==8388611 && !views::origin(ref state,0,14).is_ok);
    let views::State exact=state;let usize repeated=ok(views::merge(ref mut state,ref exact,15));
    assert(views::same(ref state,ref exact));state.retained=0;state.retained_sets[0]=1;
    assert(!views::same(ref state,ref exact) && ok(views::validate(ref state,16))==1);
}

fn void retention_is_per_origin_for_named_and_retained_anonymous_joins(){
    var views::State left=views::empty();left.origins[0]=1;
    var views::State right=left;right.origins[0]=2;right.retained=1;
    let views::State original_left=left;let views::State original_right=right;
    let usize joined=ok(views::merge(ref mut left,ref right,20));
    assert(ok(views::roots(ref left,0,20))==3 && views::retained_roots(ref left,0)==2);
    assert(left.retained==0 && left.retained_sets[0]==2 && !views::retainable(ref left,0));
    let usize reversed=ok(views::merge(ref mut right,ref original_left,21));
    assert(views::same(ref left,ref right));
    let usize repeated=ok(views::merge(ref mut left,ref original_right,22));
    assert(views::retained_roots(ref left,0)==2);
    right=original_right;right.retained=0;
    let usize unretained_path=ok(views::merge(ref mut left,ref right,23));
    assert(views::retained_roots(ref left,0)==0 && left.retained_sets[0]==0 && left.retained==0);
    left=original_left;left.retained=1;right=original_right;
    let usize fully_retained=ok(views::merge(ref mut left,ref right,24));
    assert(left.retained==1 && left.retained_sets[0]==0 && views::retained_roots(ref left,0)==3);
}

fn void retention_meet_is_associative_for_overlapping_and_absent_dependencies(){
    var views::State a=local_union();a.retained_sets[0]=2;
    var views::State b=local_union();b.sets[0]=6;b.retained=1;
    var views::State c=views::empty();c.origins[0]=2;
    var views::State ab=a;let usize first=ok(views::merge(ref mut ab,ref b,25));
    assert(views::retained_roots(ref ab,0)==6);
    let usize second=ok(views::merge(ref mut ab,ref c,26));
    var views::State bc=b;let usize third=ok(views::merge(ref mut bc,ref c,27));
    let usize fourth=ok(views::merge(ref mut a,ref bc,28));
    assert(views::same(ref a,ref ab) && ok(views::roots(ref a,0,29))==7);
    assert(views::retained_roots(ref a,0)==4 && a.retained==0 && a.retained_sets[0]==4);
}

fn void alias_range_move_and_call_preserve_complete_dependencies_and_retention(){
    var values::Program unit=local_base();var views::State state=local_union();state.retained_sets[0]=2;
    state.names[0]=1;state.reserved=32;
    let usize lo=ok(ir::integer(ref mut unit.body,0,12,30));
    let usize hi=ok(ir::integer(ref mut unit.body,0,12,30));
    let usize alias=ok(views::alias(ref mut unit,ref mut state,0,31));
    let usize window=ok(views::range(ref mut unit,ref mut state,alias,lo,hi,32));
    assert(ok(views::roots(ref state,alias,33))==3 && views::retained_roots(ref state,alias)==2);
    assert(views::retained_roots(ref state,window)==2 && views::pinned(ref state,0) && views::pinned(ref state,1));
    state.names[1]=3;let usize moved=ok(views::move_to(ref mut unit,ref mut state,window,5,34));
    assert(moved==5 && state.names[1]==6 && state.reserved==32);
    assert(state.origins[window]==0 && state.sets[window]==0 && state.retained_sets[window]==0);
    assert(ok(views::roots(ref state,moved,35))==3 && views::retained_roots(ref state,moved)==2);
    let usize length=ok(views::scalar(ref mut unit,ref state,110,moved,0,36));
    let usize read=ok(views::scalar(ref mut unit,ref state,111,moved,lo,37));
    assert(unit.body.types[length]==12 && unit.body.types[read]==10);
    let usize before=unit.body.count;let usize result=ok(views::call_result(ref mut unit,ref mut state,moved,38));
    assert(unit.body.count==before && ok(views::roots(ref state,result,39))==3);
    assert(views::retained_roots(ref state,result)==3 && views::retainable(ref state,result));
    assert(state.retained_sets[result]==0 && !views::pinned(ref state,2));
    let usize closed=ok(views::close(ref mut unit,ref mut state,moved,40));
    assert(state.names[1]==0 && state.sets[moved]==0 && state.retained_sets[moved]==0);
    let usize all=ok(views::close_all(ref mut unit,ref mut state,41));
    assert(all==3 && views::count(ref state)==0 && state.retained==0 && state.reserved==32);
    assert(!views::pinned(ref state,0) && !views::pinned(ref state,1));
}

fn void anonymous_cleanup_preserves_baseline_exact_union_and_partial_retention(){
    var values::Program unit=local_base();var views::State state=local_union();state.retained_sets[0]=2;
    state.names[0]=1;let views::State baseline=state;
    let usize alias=ok(views::alias(ref mut unit,ref mut state,0,50));
    let usize result=ok(views::call_result(ref mut unit,ref mut state,alias,51));
    assert(ok(views::anonymous_since(ref state,ref baseline,52))==6);
    let views::State before=state;state.sets[0]=5;
    // Keep the changed descriptor canonical while changing its baseline roots.
    state.retained_sets[0]=4;
    rejected(views::anonymous_since(ref state,ref baseline,53),53);
    let usize count=unit.body.count;rejected(views::close_since(ref mut unit,ref mut state,ref baseline,54),54);
    assert(unit.body.count==count && state.sets[0]==5);state=before;state.retained_sets[0]=1;
    rejected(views::anonymous_since(ref state,ref baseline,55),55);state=before;
    assert(ok(views::close_since(ref mut unit,ref mut state,ref baseline,56))==2);
    assert(views::same(ref state,ref baseline) && state.sets[alias]==0 && state.retained_sets[result]==0);
}

fn void authentication_checks_every_local_and_formal_member_in_the_current_function(){
    var values::Program unit=local_base();var views::State state=local_union();
    assert(ok(views::authenticate(ref unit,ref state,60))==0);
    unit.types[1]=0;rejected(views::authenticate(ref unit,ref state,61),61);unit.types[1]=1;
    unit.body.function_count=2;unit.functions[1]=1;
    rejected(views::authenticate(ref unit,ref state,62),62);unit.functions[1]=0;
    unit.parameters[0]=17;state.sets[0]=65537;
    assert(ok(views::authenticate(ref unit,ref state,63))==0 && views::local_roots(ref state,0)==1);
    unit.parameters[0]=0;rejected(views::authenticate(ref unit,ref state,64),64);unit.parameters[0]=17;
    state.sets[0]=8388609;rejected(views::authenticate(ref unit,ref state,65),65);
    unit.body.arities[0]=8;unit.body.registers=8;unit.parameters[7]=18;
    assert(ok(views::authenticate(ref unit,ref state,66))==0);
    unit.body.types[7]=12;rejected(views::authenticate(ref unit,ref state,67),67);
    unit.body.types[7]=0;unit.body.slots[7]=true;rejected(views::authenticate(ref unit,ref state,68),68);
    unit.body.slots[7]=false;state.function=1;unit.body.arities[1]=8;
    rejected(views::authenticate(ref unit,ref state,69),69);
}

fn void return_requires_exact_selected_formal_and_detaches_without_emitting_close(){
    var values::Program unit=local_base();unit.body.arities[0]=2;unit.body.registers=2;
    unit.parameters[0]=17;unit.parameters[1]=18;unit.results[0]=17;
    var views::State state=views::empty();state.origins[0]=25;state.sets[0]=196608;state.retained=1;
    let views::State before=state;rejected(views::take_return(ref unit,ref mut state,0,70),70);
    assert(views::same(ref state,ref before) && unit.body.count==0);
    state.sets[0]=65537;rejected(views::take_return(ref unit,ref mut state,0,71),71);
    state.origins[0]=18;state.sets[0]=0;rejected(views::take_return(ref unit,ref mut state,0,72),72);
    state.origins[0]=17;state.names[0]=1;
    assert(ok(views::take_return(ref unit,ref mut state,0,73))==0);
    assert(unit.body.count==0 && views::count(ref state)==0 && state.retained==0);
    assert(state.names[0]==0 && state.sets[0]==0 && state.retained_sets[0]==0);
}

fn void reject_malformed(views::State bad){
    var values::Program unit=local_base();unit.body.code[0]=177;unit.body.offsets[0]=999;
    var views::State state=bad;let views::State baseline=views::empty();
    rejected(views::validate(ref state,80),80);rejected(views::roots(ref state,0,81),81);
    rejected(views::alias(ref mut unit,ref mut state,0,82),82);
    rejected(views::range(ref mut unit,ref mut state,0,0,0,83),83);
    rejected(views::move_to(ref mut unit,ref mut state,0,1,84),84);
    rejected(views::call_result(ref mut unit,ref mut state,0,85),85);
    rejected(views::close(ref mut unit,ref mut state,0,86),86);
    rejected(views::scalar(ref mut unit,ref state,110,0,0,87),87);
    rejected(views::close_all(ref mut unit,ref mut state,88),88);
    rejected(views::close_since(ref mut unit,ref mut state,ref baseline,89),89);
    rejected(views::reserve(ref unit,ref mut state,90),90);
    rejected(views::begin(ref mut unit,ref mut state,0,0,0,91),91);
    rejected(views::formal(ref mut unit,ref mut state,0,0,92),92);
    rejected(views::take_return(ref unit,ref mut state,0,93),93);
    rejected(views::merge(ref mut state,ref baseline,94),94);
    assert(views::same(ref state,ref bad) && unit.body.count==0 && unit.body.registers==1);
    assert(unit.body.code[0]==177 && unit.body.offsets[0]==999 && unit.parameters[0]==0);
}

fn void forged_masks_and_noncanonical_singleton_encodings_reject_atomically(){
    var views::State bad=views::empty();bad.sets[0]=1;reject_malformed(bad);
    bad.origins[0]=1;reject_malformed(bad);
    bad.origins[0]=25;bad.sets[0]=0;reject_malformed(bad);
    bad.sets[0]=1;reject_malformed(bad);bad.sets[0]=8388608;reject_malformed(bad);
    bad.sets[0]=16777219;reject_malformed(bad);
    bad.origins[0]=26;bad.sets[0]=0;reject_malformed(bad);
    assert(views::local_roots(ref bad,0)==0 && views::retained_roots(ref bad,0)==0);
    assert(views::local_roots(ref bad,16)==0 && views::retained_roots(ref bad,16)==0);
}

fn void forged_partial_retention_and_duplicate_names_reject_atomically(){
    var views::State bad=views::empty();bad.retained_sets[0]=1;reject_malformed(bad);
    bad.origins[0]=1;reject_malformed(bad);
    bad=local_union();bad.retained_sets[0]=4;reject_malformed(bad);
    bad.retained_sets[0]=3;reject_malformed(bad);
    bad.retained_sets[0]=1;bad.retained=1;reject_malformed(bad);
    bad=local_union();bad.names[0]=1;bad.names[1]=1;reject_malformed(bad);
    bad=local_union();bad.retained=65536;reject_malformed(bad);
    bad=local_union();bad.retained_sets[0]=2;
    assert(ok(views::validate(ref bad,95))==1 && views::retained_roots(ref bad,0)==2);
}

fn void merge_rejects_late_shape_or_encoding_errors_before_publishing_any_union(){
    var views::State state=views::empty();state.origins[0]=1;state.origins[15]=2;
    state.names[0]=1;state.reserved=4;let views::State before=state;
    var views::State other=state;other.origins[0]=2;other.origins[15]=0;
    rejected(views::merge(ref mut state,ref other,100),100);assert(views::same(ref state,ref before));
    other=before;other.origins[0]=2;other.sets[15]=3;
    rejected(views::merge(ref mut state,ref other,101),101);assert(views::same(ref state,ref before));
    other=before;other.origins[0]=2;other.names[0]=0;
    rejected(views::merge(ref mut state,ref other,102),102);assert(views::same(ref state,ref before));
    other=before;other.origins[0]=2;other.function=1;
    rejected(views::merge(ref mut state,ref other,103),103);assert(views::same(ref state,ref before));
    other=before;other.origins[0]=2;other.reserved=0;
    rejected(views::merge(ref mut state,ref other,104),104);assert(views::same(ref state,ref before));
    other=before;other.origins[0]=2;let usize joined=ok(views::merge(ref mut state,ref other,105));
    assert(state.sets[0]==3 && state.origins[15]==2 && state.names[0]==1 && state.reserved==4);
}

fn void local_accessors_are_bounded_descriptor_reads_and_roots_remains_whole_state_checked(){
    var views::State state=local_union();state.sets[0]=16777215;state.retained_sets[0]=8388608;
    assert(ok(views::roots(ref state,0,110))==16777215 && views::local_roots(ref state,0)==65535);
    assert(views::retained_roots(ref state,0)==8388608 && !views::pinned(ref state,16));
    state.names[63]=17;rejected(views::roots(ref state,0,111),111);
    // Callers must authenticate first: local reads intentionally ignore another
    // plane's malformed name, avoiding a 64-name scan per queried descriptor.
    assert(views::local_roots(ref state,0)==65535 && views::retained_roots(ref state,0)==8388608);
    state.names[63]=0;state.sets[0]=16777216;
    assert(views::local_roots(ref state,0)==0 && views::retained_roots(ref state,0)==0);
    state=views::empty();rejected(views::roots(ref state,16,112),112);
    rejected(views::roots(ref state,0,113),113);
    assert(views::local_roots(ref state,0)==0 && views::retained_roots(ref state,0)==0);
}

// Keep fourteen independent helper scopes in four native test images.
@test fn void reservation_and_normalized_origin_merges(){
    join_destination_reservation_survives_alternative_selection_without_live_authority();
    bounded_reservations_reject_exhaustion_and_invalid_release_before_mutation();
    retention_join_meets_shared_roots_and_unions_different_origins_without_losing_reservations();
    origin_set_merge_normalizes_singletons_unions_and_preserves_exact_loop_state();
}
@test fn void partial_retention_propagation_and_anonymous_cleanup(){
    retention_is_per_origin_for_named_and_retained_anonymous_joins();
    retention_meet_is_associative_for_overlapping_and_absent_dependencies();
    alias_range_move_and_call_preserve_complete_dependencies_and_retention();
    anonymous_cleanup_preserves_baseline_exact_union_and_partial_retention();
}
@test fn void namespace_return_and_bounded_accessor_contracts(){
    authentication_checks_every_local_and_formal_member_in_the_current_function();
    return_requires_exact_selected_formal_and_detaches_without_emitting_close();
    local_accessors_are_bounded_descriptor_reads_and_roots_remains_whole_state_checked();
}
@test fn void malformed_masks_and_late_merge_rejections_are_atomic(){
    forged_masks_and_noncanonical_singleton_encodings_reject_atomically();
    forged_partial_retention_and_duplicate_names_reject_atomically();
    merge_rejects_late_shape_or_encoding_errors_before_publishing_any_union();
}
