module tests::m2::metadata_budget;
import metadata_budget as budget;
import errors as errors;

fn bool admitted(ref mut budget::State state,usize bound){
    return switch(budget::admit(state,bound,73)){case .ok(v):{v}case .err(_):{assert(false);false}};
}
fn void rejected(ref mut budget::State state,usize bound){
    let budget::State saved=*state;
    switch(budget::admit(state,bound,73)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==73);}};
    assert(state.total==saved.total && state.last==saved.last && state.stages==saved.stages);
}
@test fn void bounded_stages_share_one_batch_and_never_bank_future_credit(){
    var budget::State state=budget::empty();assert(budget::limit()==4096);
    assert(admitted(ref mut state,1024));assert(admitted(ref mut state,2048));
    assert(!admitted(ref mut state,1025));assert(state.last==3072 && state.total==3072 && state.stages==2);
    assert(admitted(ref mut state,1024));assert(!admitted(ref mut state,1));
    assert(state.last==4096 && state.total==4096 && state.stages==3);
    assert(budget::reset(ref mut state,73).is_ok);
    assert(state.last==0 && state.total==4096 && state.stages==3);
    assert(admitted(ref mut state,4096));assert(state.last==4096 && state.total==8192 && state.stages==4);
}
@test fn void malformed_bounds_and_overflow_preserve_every_counter(){
    var budget::State state=budget::empty();rejected(ref mut state,0);rejected(ref mut state,4097);
    state.last=1;rejected(ref mut state,1);state.last=0;
    state.stages=1;rejected(ref mut state,1);state.stages=0;
    state.total=18446744073709551615;rejected(ref mut state,1);
    state.total=18446744073709551614;assert(admitted(ref mut state,1));rejected(ref mut state,1);
    state.last=4097;let budget::State saved=state;
    switch(budget::reset(ref mut state,73)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==73);}};
    assert(state.total==saved.total && state.last==saved.last && state.stages==saved.stages);
}
