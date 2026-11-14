module tests::m2::value_flow_pending;
import value_flow_pending as queue;

fn usize reference(ref mut bool[] pending,usize after,usize end){
    var usize pc=after;while(pc<end){if(pending[pc]){pending[pc]=false;return pc;}pc+=1;}return 256;
}
@test fn void every_word_bit_range_and_small_mask_matches_ascending_flags(){
    var usize id=0;while(id<256){var queue::State w=queue::empty();queue::add(ref mut w,id);
        assert(queue::take(ref mut w,id+1,256)==256);
        assert(queue::take(ref mut w,0,id)==256);
        assert(queue::take(ref mut w,0,256)==id);
        assert(queue::take(ref mut w,0,256)==256);id+=1;
    }
    var usize mask=0;while(mask<256){var usize base=0;while(base<=192){
        var queue::State w=queue::empty();var bool[256] pending=[false;256];
        var usize i=0;let usize one=1;while(i<8){if((mask&(one<<i))!=0){
            queue::add(ref mut w,base+i);queue::add(ref mut w,base+i);pending[base+i]=true;}i+=1;}
        var usize pc=0;while(pc<=256){
            assert(queue::take(ref mut w,pc,256)==reference(ref mut pending,pc,256));pc+=1;
        }base+=64;
    }mask+=1;}
}
@test fn void dynamic_backedges_duplicates_and_same_pc_requeues_preserve_sweeps(){
    var queue::State w=queue::empty();var bool[256] pending=[false;256];var usize cursor=0;
    var usize step=0;while(step<10000){
        let usize a=(step*73+63)%256;let usize b=(step*37+255)%256;
        queue::add(ref mut w,a);queue::add(ref mut w,b);pending[a]=true;pending[b]=true;
        var usize expected=reference(ref mut pending,cursor,256);
        if(expected==256){expected=reference(ref mut pending,0,256);}
        var usize actual=queue::take(ref mut w,cursor,256);
        if(actual==256){actual=queue::take(ref mut w,0,256);}assert(actual==expected);
        queue::add(ref mut w,actual);pending[actual]=true;cursor=actual+1;step+=1;
    }
    while(true){let usize a=queue::take(ref mut w,0,256);let usize b=reference(ref mut pending,0,256);
        assert(a==b);if(a==256){break;}}
}
