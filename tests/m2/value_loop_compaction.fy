module tests::m2::value_loop_compaction;
import value_source_loops as looping;
import value_source_bindings as bindings;
import value_source_control as branches;
import value_view_bindings as views;
import errors as errors;
import std::vec as vec;
fn Result<usize,errors::Error> original(ref mut vec::Vec<bindings::Snapshot> paths,
    ref mut looping::State loops,usize mark,usize at){
    let usize count=branches::mark(paths);if(mark>count){return .err(errors::make(3,at));}
    var usize write=mark;var usize read=mark;
    while(read<count){
        var bool retained=false;var usize pc=0;
        while(pc<256){if(loops.owners[pc]!=0 && loops.paths[pc]==read+1){retained=true;}pc+=1;}
        if(retained){
            if(write!=read){
                let bindings::Snapshot saved=bindings::snapshot(ref vec::at<bindings::Snapshot>(paths,read).state);
                let ref mut bindings::Snapshot target=vec::at_mut<bindings::Snapshot>(paths,write);target.state=saved.state;
            }
            pc=0;while(pc<256){if(loops.owners[pc]!=0 && loops.paths[pc]==read+1){loops.paths[pc]=write+1;}pc+=1;}
            write+=1;
        }read+=1;
    }
    return branches::release(paths,write,at);
}

fn void same_state(ref bindings::State a,ref bindings::State b){
    assert(a.next==b.next && a.live==b.live && a.maybe==b.maybe && a.loop_roots==b.loop_roots && a.reads==b.reads && a.writes==b.writes);
    assert(a.enforce_results==b.enforce_results && a.pending==b.pending && a.tracking==b.tracking && a.kills==b.kills && a.generated==b.generated && a.required==b.required);
    assert(a.names.count==b.names.count && a.names.function==b.names.function && a.names.pending_places==b.names.pending_places && views::same(ref a.views,ref b.views));
    var usize i=0;while(i<64){assert(a.bindings[i]==b.bindings[i] && a.names.begins[i]==b.names.begins[i] && a.names.ends[i]==b.names.ends[i] && a.names.registers[i]==b.names.registers[i] && a.names.mutable[i]==b.names.mutable[i]);i+=1;}
}
fn void compare(usize count,usize mark,usize mask,u8 mode){
    var vec::Vec<bindings::Snapshot> a=vec::empty<bindings::Snapshot>();var vec::Vec<bindings::Snapshot> b=vec::empty<bindings::Snapshot>();
    assert(vec::reserve<bindings::Snapshot>(ref mut a,count).is_ok && vec::reserve<bindings::Snapshot>(ref mut b,count).is_ok);
    var usize i=0;while(i<count){var bindings::State row=bindings::empty();row.next=i;row.live=i*3;row.maybe=i*5;row.pending=i*7;row.loop_roots=i*11;row.reads=i*13;row.writes=i*17;row.kills=i*19;row.generated=i*23;row.required=i*29;
        row.names.count=i;row.names.function=i+1;row.names.pending_places=i+2;row.enforce_results=i%2==0;row.tracking=i%3==0;row.views.function=i;row.views.reserved=i*31;row.views.retained=i*37;
        var usize j=0;while(j<64){row.names.begins[j]=i*64+j;row.names.ends[j]=i*64+j+1;row.names.registers[j]=i+j;row.names.mutable[j]=(i+j)%2==0;j+=1;}
        // Payloads are opaque tags, not authenticated guest/compiler owner state.
        assert(vec::push<bindings::Snapshot>(ref mut a,bindings::snapshot(ref row)).is_ok && vec::push<bindings::Snapshot>(ref mut b,bindings::snapshot(ref row)).is_ok);i+=1;}
    var looping::State left=looping::empty();left.depth=2;i=0;while(i<256){
        if(mode==0){left.owners[i]=1+i%2;left.paths[i]=if(count==0){0}else{i%count+1};}
        else if(mode==1){let usize one=1;left.owners[i]=if((mask&(one<<(i%8)))!=0){1+i%2}else{0};left.paths[i]=i%8+1;}
        else{left.owners[i]=i%3;left.paths[i]=(i*37)%(count+3);}
        left.leaves[i]=i%2==0;i+=1;}
    var looping::State right=left;
    let Result<usize,errors::Error> x=original(ref mut a,ref mut left,mark,77);let Result<usize,errors::Error> y=looping::release(ref mut b,ref mut right,mark,77);
    switch(x){case .ok(n):{assert(switch(y){case .ok(m):{n==m}case .err(_):{false}});}case .err(e):{assert(switch(y){case .ok(_):{false}case .err(q):{e.kind==q.kind && e.offset==q.offset}});}};
    let usize n=vec::len<bindings::Snapshot>(ref a);assert(n==vec::len<bindings::Snapshot>(ref b) && left.depth==right.depth);
    i=0;while(i<n){same_state(ref vec::at<bindings::Snapshot>(ref a,i).state,ref vec::at<bindings::Snapshot>(ref b,i).state);i+=1;}
    i=0;while(i<256){assert(left.owners[i]==right.owners[i] && left.paths[i]==right.paths[i] && left.leaves[i]==right.leaves[i]);i+=1;}
    i=0;while(i<32){let looping::Frame p=left.frames[i];let looping::Frame q=right.frames[i];assert(p.entry==q.entry && p.names==q.names && p.head==q.head && p.classic==q.classic && p.outer_tracking==q.outer_tracking && p.outer_kills==q.outer_kills && p.outer_generated==q.outer_generated && p.outer_required==q.outer_required && p.generated==q.generated && p.outer_roots==q.outer_roots);i+=1;}
}
@test fn void all_small_retention_masks_preserve_stable_snapshot_and_edge_identity(){var usize mask=0;while(mask<256){compare(8,mask%9,mask,1);mask+=1;}}
@test fn void maximum_prefix_stale_duplicate_and_legacy_oversized_pools_match_original(){
    compare(128,0,0,0);compare(128,43,0,0);compare(128,128,0,0);compare(128,29,0,2);compare(129,64,0,0);compare(8,9,0,2);compare(0,0,0,2);
}
