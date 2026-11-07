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

@test fn void join_destination_reservation_survives_alternative_selection_without_live_authority(){
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

@test fn void bounded_reservations_reject_exhaustion_and_invalid_release_before_mutation(){
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

@test fn void retention_join_intersects_hints_and_rejects_different_origins_without_mutation(){
    var values::Program unit=base();var views::State state=views::empty();
    let usize formal=ok(views::formal(ref mut unit,ref mut state,0,0,0));
    let usize alias=ok(views::alias(ref mut unit,ref mut state,formal,1));
    let views::State direct=state;state.retained=2;
    assert(!views::same(ref state,ref direct));let usize merged=ok(views::merge(ref mut state,ref direct,2));
    assert(state.retained==0 && views::same(ref state,ref direct));
    var views::State wrong=state;wrong.origins[alias]=18;
    assert(!views::merge(ref mut state,ref wrong,3).is_ok && views::same(ref state,ref direct));
    wrong=state;wrong.reserved=2;
    assert(!views::merge(ref mut state,ref wrong,4).is_ok && views::same(ref state,ref direct));
}
