module tests::m2::slice_argument_preflight;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;

// Original f2c1c57 batch algorithm. inspect_cleanup is the original validate.
fn Result<slices::Arguments,owners::Error> original(ref mut slices::Pool pool,
    ref slices::Ticket[] sources,ref owners::Table table,usize capacity){
    if(sources.len>8){return .err(.Length);}
    let usize checked=slices::inspect_cleanup(pool,table,capacity)?;
    var usize[8] lengths=[0;8];var usize i=0;
    while(i<sources.len){
        lengths[i]=slices::length(pool,sources[i],table,capacity)?;
        if(pool.slots[sources[i].slot].exclusive){return .err(.State);}i+=1;
    }
    var slices::Pool planned=slices::Pool{.slots=pool.slots};
    var slices::Arguments result=slices::empty_arguments();i=0;
    while(i<sources.len){
        let slices::Ticket child=slices::subslice(ref mut planned,sources[i],table,0,lengths[i],capacity)?;
        result.tickets[i]=child;i+=1;
    }
    let usize count=sources.len;result.count=count;pool.slots=planned.slots;return .ok(result);
}
fn u8 tag(owners::Error e){return switch(e){
    case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}
    case .Metadata:{6}case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}};
}
fn void same_pool(ref slices::Pool a,ref slices::Pool b){var usize i=0;while(i<16){
    let slices::Slot x=a.slots[i];let slices::Slot y=b.slots[i];
    assert(x.live==y.live && x.exclusive==y.exclusive && x.generation==y.generation);
    assert(x.view.root.slot==y.view.root.slot && x.view.root.generation==y.view.root.generation);
    assert(x.view.element==y.view.element && x.view.length==y.view.length && x.view.start==y.view.start && x.view.end==y.view.end);
    assert(x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation);i+=1;
}}
fn void same_batch(ref slices::Arguments a,ref slices::Arguments b){
    assert(a.count==b.count);var usize i=0;while(i<8){
        assert(a.tickets[i].slot==b.tickets[i].slot && a.tickets[i].generation==b.tickets[i].generation);i+=1;}
}
fn void compare(ref slices::Pool pool,ref owners::Table table,ref slices::Ticket[] sources,usize capacity){
    var slices::Pool before=*pool;var slices::Pool after=*pool;
    let Result<slices::Arguments,owners::Error> a=original(ref mut before,sources,table,capacity);
    let Result<slices::Arguments,owners::Error> b=slices::borrow_arguments(ref mut after,sources,table,capacity);
    switch(a){case .ok(x):{switch(b){case .ok(y):{same_batch(ref x,ref y);}case .err(_):{assert(false);}};}
        case .err(e):{same_pool(ref after,pool);switch(b){case .ok(_):{assert(false);}case .err(f):{assert(tag(e)==tag(f));}};}};
    same_pool(ref before,ref after);
}
fn owners::Token create(ref mut owners::Table table,ref mut u8[] data){
    let layouts::Array shape=switch(layouts::scalar(10,4)){case .ok(a):{a}case .err(_):{
        assert(false);layouts::Array{.element=10,.length=4,.stride=1,.alignment=1,.bytes=4}}};
    return switch(owners::create(ref shape,65,data,table)){case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn slices::Ticket open(ref mut slices::Pool pool,ref mut owners::Table table,owners::Token root,usize i){
    // Include nonzero root-relative offsets and empty ranges.
    return switch(slices::open(pool,table,root,1,if(i%2==0){3}else{1},64)){
        case .ok(t):{t}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};
}
fn void healthy(ref slices::Pool pool,ref owners::Table table,usize count,usize variant){
    var slices::Pool p=*pool;var usize i=0;
    while(i<16){if(variant==1 && i>=count && i%2==0){p.slots[i].generation=0;}
        if(variant==2){p.slots[i].generation=18446744073709551615;}i+=1;}
    var usize pattern=0;while(pattern<2){
        var slices::Ticket[9] sources=[slices::Ticket{.slot=16,.generation=0};9];i=0;
        while(i<9){if(count>0){let usize slot=if(pattern==0){0}else{count-1-i%count};
            sources[i]=slices::Ticket{.slot=slot,.generation=p.slots[slot].generation};}i+=1;}
        var usize n=0;while(n<=9){compare(ref p,table,ref sources[..n],64);n+=1;}pattern+=1;
    }
}
@test fn void all_batch_sizes_pool_occupancies_and_ticket_generations_match_original(){
    var u8[64] data=[0;64];var owners::Table table=owners::empty(64);var slices::Pool pool=slices::empty();
    var owners::Token[16] roots=[owners::Token{.slot=16,.generation=0};16];var usize i=0;
    while(i<16){roots[i]=create(ref mut table,ref mut data);i+=1;}
    var usize count=0;while(count<=16){var usize variant=0;while(variant<3){healthy(ref pool,ref table,count,variant);variant+=1;}
        if(count==16){break;}let slices::Ticket t=open(ref mut pool,ref mut table,roots[count],count);count+=1;}
}
fn void corrupt(ref slices::Pool pool,ref owners::Table table,usize slot,usize mode){
    var slices::Pool p=*pool;var owners::Table t=*table;
    if(mode==0){p.slots[slot].generation=0;}else if(mode==1){p.slots[slot].exclusive=true;}
    else if(mode==2){p.slots[slot].live=false;}else if(mode==3){p.slots[slot].lease.generation=0;}
    else if(mode==4){p.slots[slot].lease.generation+=1;}else if(mode==5){p.slots[slot].lease.root.slot=16;}
    else if(mode==6){p.slots[slot].view.root.generation+=1;}else if(mode==7){p.slots[slot].view.element=2;}
    else if(mode==8){p.slots[slot].view.length=5;}else if(mode==9){p.slots[slot].view.start=4;}
    else if(mode==10){p.slots[slot].view.end=5;}else if(mode==11){t.slots[slot].generation=0;}
    else if(mode==12){t.slots[slot].reading=false;}else if(mode==13){t.slots[slot].writing=true;}
    else if(mode==14){t.slots[slot].read_generation=0;}else if(mode==15){t.slots[slot].base=18446744073709551615;}
    else if(mode==16){t.slots[slot].length=4097;}else if(mode==17){t.order[slot]=16;}
    else if(mode==18){t.arena.used=63;}else{t.depth=17;}
    let slices::Ticket first=slices::Ticket{.slot=0,.generation=pool.slots[0].generation};
    let slices::Ticket[2] good=[first,first];let slices::Ticket[2] late_bad=[first,slices::Ticket{.slot=16,.generation=1}];
    compare(ref p,ref t,ref good,64);compare(ref p,ref t,ref late_bad,64);
    compare(ref p,ref t,ref good[..0],64);compare(ref p,ref t,ref good,0);
}
@test fn void corrupt_unselected_metadata_and_late_forged_sources_preserve_diagnostics_and_rollback(){
    var u8[64] data=[0;64];var owners::Table table=owners::empty(64);var slices::Pool pool=slices::empty();
    var owners::Token[16] roots=[owners::Token{.slot=16,.generation=0};16];var usize i=0;
    while(i<16){roots[i]=create(ref mut table,ref mut data);i+=1;}
    var usize count=0;while(count<16){let slices::Ticket t=open(ref mut pool,ref mut table,roots[count],count);count+=1;
        if(count==1 || count==8 || count==16){var usize slot=0;while(slot<16){var usize mode=0;
            while(mode<20){corrupt(ref pool,ref table,slot,mode);mode+=1;}slot+=1;}
            let slices::Ticket first=slices::Ticket{.slot=0,.generation=pool.slots[0].generation};
            var usize n=1;while(n<=8){var slices::Ticket[8] sources=[first;8];
                // A later source must not be authenticated by an earlier child.
                sources[n-1]=slices::Ticket{.slot=count,.generation=1};compare(ref pool,ref table,ref sources[..n],64);
                sources[n-1]=first;sources[n-1].generation=0;compare(ref pool,ref table,ref sources[..n],64);n+=1;}
        }
    }
}
