module tests::m2::value_view_loop_origins_bindings;
import value_view_bindings as views;
import errors as errors;

fn usize ok(Result<usize,errors::Error> result){return switch(result){
    case .ok(v):{v}case .err(_):{assert(false);0}
};}
fn views::State seed(){var views::State state=views::empty();
    state.origins[0]=1;state.names[0]=1;state.retained=1;return state;
}
fn void projection_keeps_names_and_live_shape_exact(){
    let views::State entry=seed();var views::State current=seed();
    current.origins[0]=2;current.retained=0;
    let views::State projected=switch(views::loop_baseline(ref current,ref entry,10)){
        case .ok(v):{v}case .err(_):{assert(false);views::empty()}
    };
    assert(projected.origins[0]==2 && projected.names[0]==1 && projected.retained==0);
    assert(entry.origins[0]==1 && entry.retained==1);
    assert(!views::anonymous_since(ref current,ref entry,11).is_ok);
    assert(ok(views::anonymous_since(ref current,ref projected,12))==0);
    current.names[0]=0;current.names[1]=1;
    assert(!views::loop_baseline(ref current,ref entry,13).is_ok);
    current=seed();current.reserved=2;
    assert(!views::loop_baseline(ref current,ref entry,14).is_ok);
    current=views::empty();assert(!views::loop_baseline(ref current,ref entry,15).is_ok);
}
fn void inference_preserves_partial_retention_and_rejects_shape_changes_atomically(){
    var views::State state=seed();var usize[16] roots=[0;16];var usize[16] missing=[0;16];
    roots[0]=3;missing[0]=2;
    let usize joined=ok(views::inferred(ref mut state,ref roots,ref missing,20));
    assert(joined==1 && state.names[0]==1 && views::roots(ref state,0,21).is_ok);
    assert(views::local_roots(ref state,0)==3 && views::retained_roots(ref state,0)==1);
    missing[0]=4;
    assert(!views::inferred(ref mut state,ref roots,ref missing,22).is_ok);
    assert(views::local_roots(ref state,0)==3 && views::retained_roots(ref state,0)==1);
    roots[0]=0;missing[0]=0;
    assert(!views::inferred(ref mut state,ref roots,ref missing,23).is_ok);
    roots[0]=7;missing[0]=3;
    let usize widened=ok(views::inferred(ref mut state,ref roots,ref missing,24));
    assert(views::local_roots(ref state,0)==7 && views::retained_roots(ref state,0)==4);
    assert(state.names[0]==1 && views::count(ref state)==1);
}
@test fn void loop_projection_and_origin_publication_preserve_exact_descriptors(){
    projection_keeps_names_and_live_shape_exact();
    inference_preserves_partial_retention_and_rejects_shape_changes_atomically();
}
