module main;
import store as store;
unsafe extern C fn void reset_trace();
unsafe extern C fn usize trace_word(usize index);
unsafe extern C fn usize trace_count();
fn i32 main(){
    store::retain_helpers();unsafe{reset_trace()};
    {
        var store::Store s=store::open();assert(store::size(ref s)==0);
        assert(store::push(ref mut s,11)==1);assert(store::push(ref mut s,22)==2);
        assert(store::mutate(ref mut s,0,42)==2);assert(store::pop(ref mut s)==22);
        assert(unsafe{trace_count()}==1 && unsafe{trace_word(0)}==22);
        let store::Store moved=s;
        assert(store::size(ref moved)==1);
    }
    assert(unsafe{trace_count()}==2 && unsafe{trace_word(1)}==11);
    {var store::Store s=store::open();assert(store::pop(ref mut s)==0);assert(store::push(ref mut s,33)==1);}
    assert(unsafe{trace_count()}==3 && unsafe{trace_word(2)}==33);
    return 0;
}
