module tests::m2::slice_cleanup_preflight;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
fn u8 tag(owners::Error e){return switch(e){
    case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}
    case .Metadata:{6}case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}};
}
fn void same_result(Result<usize,owners::Error> a,Result<usize,owners::Error> b){
    assert(switch(a){case .ok(n):{switch(b){case .ok(m):{n==m}case .err(_):{false}}}
        case .err(e):{switch(b){case .ok(_):{false}case .err(f):{tag(e)==tag(f)}}}});
}
fn void same_pool(ref slices::Pool a,ref slices::Pool b){var usize i=0;while(i<16){
    let slices::Slot x=a.slots[i];let slices::Slot y=b.slots[i];
    assert(x.live==y.live && x.exclusive==y.exclusive && x.generation==y.generation);
    assert(x.view.root.slot==y.view.root.slot && x.view.root.generation==y.view.root.generation);
    assert(x.view.element==y.view.element && x.view.length==y.view.length && x.view.start==y.view.start && x.view.end==y.view.end);
    assert(x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation);i+=1;
}}
fn void same_table(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live);
        assert(x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length);
        assert(x.record==y.record && x.alignment==y.alignment);i+=1;}
}
fn void same_batch(ref slices::Arguments a,ref slices::Arguments b){
    assert(a.count==b.count);var usize i=0;while(i<8){
        assert(a.tickets[i].slot==b.tickets[i].slot && a.tickets[i].generation==b.tickets[i].generation);i+=1;}
}
fn void compare_clear(ref slices::Pool pool,ref owners::Table table,usize capacity){
    var slices::Pool a=*pool;var slices::Pool b=*pool;var owners::Table x=*table;var owners::Table y=*table;
    let Result<usize,owners::Error> before=original_clear(ref mut a,ref mut x,capacity);
    let Result<usize,owners::Error> after=slices::clear(ref mut b,ref mut y,capacity);
    same_result(before,after);same_pool(ref a,ref b);same_table(ref x,ref y);
    if(!after.is_ok){same_pool(ref b,pool);same_table(ref y,table);}
}
fn void compare_batch(ref slices::Pool pool,ref owners::Table table,ref slices::Arguments batch,usize capacity){
    var slices::Pool a=*pool;var slices::Pool b=*pool;var owners::Table x=*table;var owners::Table y=*table;
    var slices::Arguments c=*batch;var slices::Arguments d=*batch;
    let Result<usize,owners::Error> before=original_close_arguments(ref mut a,ref mut c,ref mut x,capacity);
    let Result<usize,owners::Error> after=slices::close_arguments(ref mut b,ref mut d,ref mut y,capacity);
    same_result(before,after);same_pool(ref a,ref b);same_table(ref x,ref y);same_batch(ref c,ref d);
    if(!after.is_ok){same_pool(ref b,pool);same_table(ref y,table);same_batch(ref d,batch);}
}
fn owners::Token create(ref mut owners::Table table,ref mut u8[] data){
    let layouts::Array shape=switch(layouts::scalar(10,4)){case .ok(a):{a}case .err(_):{
        assert(false);layouts::Array{.element=10,.length=4,.stride=1,.alignment=1,.bytes=4}}};
    return switch(owners::create(ref shape,65,data,table)){case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn slices::Ticket open(ref mut slices::Pool pool,ref mut owners::Table table,owners::Token root,usize i,bool exclusive){
    let usize end=if(i%2==0){3}else{1};
    let Result<slices::Ticket,owners::Error> r=if(exclusive){slices::open_exclusive(pool,table,root,1,end,64)}
        else{slices::open(pool,table,root,1,end,64)};
    return switch(r){case .ok(t):{t}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};
}
fn void healthy(ref slices::Pool pool,ref owners::Table table,usize count,usize generation){
    var slices::Pool p=*pool;var owners::Table t=*table;var usize i=0;
    if(generation==1){while(i<count){let usize root=p.slots[i].lease.root.slot;
        p.slots[i].generation=18446744073709551615;p.slots[i].lease.generation=18446744073709551615;
        t.slots[root].read_generation=18446744073709551615;i+=1;}}
    compare_clear(ref p,ref t,64);var usize pattern=0;
    while(pattern<2){var slices::Arguments batch=slices::empty_arguments();var usize n=0;
        while(n<=8){compare_batch(ref p,ref t,ref batch,64);if(n==8){break;}
            if(pattern==0 && n<count){batch.tickets[n]=slices::Ticket{.slot=n,.generation=p.slots[n].generation};}
            else if(pattern==1){var usize slot=16;var usize ordinal=0;var usize j=0;
                while(j<count){if(!p.slots[j].exclusive){if(ordinal==n){slot=j;break;}ordinal+=1;}j+=1;}
                if(slot<16){batch.tickets[n]=slices::Ticket{.slot=slot,.generation=p.slots[slot].generation};}}
            batch.count=n+1;n+=1;
        }pattern+=1;
    }
}
@test fn void shared_aliases_mixed_writers_and_exhausted_epochs_match_original_cleanup(){
    var usize mode=0;while(mode<3){var u8[64] data=[0;64];var owners::Table t=owners::empty(64);var slices::Pool p=slices::empty();
        var owners::Token[16] roots=[owners::Token{.slot=16,.generation=0};16];var usize i=0;
        while(i<16){roots[i]=create(ref mut t,ref mut data);i+=1;}
        var usize count=0;while(count<=16){healthy(ref p,ref t,count,0);healthy(ref p,ref t,count,1);
            if(count==16){break;}
            let slices::Ticket ticket=open(ref mut p,ref mut t,roots[if(mode==1){0}else{count}],count,mode==2 && count%2==1);count+=1;}
        mode+=1;
    }
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
    var slices::Arguments batch=slices::empty_arguments();batch.count=1;
    batch.tickets[0]=slices::Ticket{.slot=0,.generation=pool.slots[0].generation};
    compare_clear(ref p,ref t,64);compare_batch(ref p,ref t,ref batch,64);compare_batch(ref p,ref t,ref batch,0);
    batch.tickets[0].generation+=1;compare_batch(ref p,ref t,ref batch,64);
    batch=slices::empty_arguments();compare_batch(ref p,ref t,ref batch,64);
}
@test fn void corrupt_late_state_and_stale_batches_keep_errors_and_all_metadata_atomic(){
    var u8[64] data=[0;64];var owners::Table t=owners::empty(64);var slices::Pool p=slices::empty();
    var owners::Token[16] roots=[owners::Token{.slot=16,.generation=0};16];var usize i=0;
    while(i<16){roots[i]=create(ref mut t,ref mut data);i+=1;}
    var usize count=0;while(count<16){let slices::Ticket ticket=open(ref mut p,ref mut t,roots[count],count,false);count+=1;
        if(count==1 || count==8 || count==16){var usize slot=0;while(slot<16){var usize mode=0;
            while(mode<20){corrupt(ref p,ref t,slot,mode);mode+=1;}slot+=1;}}
    }
    // Stale ticket at each reverse-cleanup position after earlier valid closes.
    var usize position=0;while(position<8){var slices::Arguments batch=slices::empty_arguments();batch.count=8;i=0;
        while(i<8){batch.tickets[i]=slices::Ticket{.slot=i,.generation=p.slots[i].generation};i+=1;}
        batch.tickets[position].generation+=1;compare_batch(ref p,ref t,ref batch,64);
        batch.tickets[position].generation-=1;batch.tickets[position].slot=16;compare_batch(ref p,ref t,ref batch,64);position+=1;
    }
}
// Original 2b4fe75 cleanup algorithms. Public close retains its full preflight.
fn Result<usize, owners::Error> original_clear(ref mut slices::Pool pool, ref mut owners::Table table, usize capacity) {
    let usize count = slices::inspect_cleanup(pool, table, capacity)?;
    // Stage metadata only. Never partially end sessions if a later root fails.
    var slices::Pool planned = slices::Pool { .slots = pool.slots };
    var owners::Table planned_table = owners::Table { .slots = table.slots,
        .order = table.order, .depth = table.depth, .arena = table.arena };
    var usize i = 16;
    while (i > 0) {
        i -= 1;
        let slices::Slot entry = planned.slots[i];
        if (entry.live) {
            let usize closed = slices::close(ref mut planned, slices::Ticket { .slot = i, .generation = entry.generation },
                ref mut planned_table, capacity)?;
        }
    }
    pool.slots = planned.slots;
    table.slots = planned_table.slots;
    return .ok(count);
}
fn Result<usize, owners::Error> original_close_arguments(ref mut slices::Pool pool,
    ref mut slices::Arguments arguments, ref mut owners::Table table, usize capacity) {
    if (arguments.count > 8) { return .err(.Length); }
    var usize i = 0;
    while (i < 8) {
        let slices::Ticket ticket = arguments.tickets[i];
        if (i < arguments.count) {
            if (ticket.slot >= 16 || ticket.generation == 0) { return .err(.Token); }
            if (pool.slots[ticket.slot].exclusive) { return .err(.State); }
            var usize j = 0;
            while (j < i) {
                if (arguments.tickets[j].slot == ticket.slot) { return .err(.State); }
                j += 1;
            }
        } else if (ticket.slot != 16 || ticket.generation != 0) { return .err(.State); }
        i += 1;
    }
    let usize checked = slices::inspect_cleanup(pool, table, capacity)?;
    var slices::Pool planned = slices::Pool { .slots = pool.slots };
    var owners::Table planned_table = owners::Table { .slots = table.slots,
        .order = table.order, .depth = table.depth, .arena = table.arena };
    let usize count = arguments.count;
    i = count;
    while (i > 0) {
        i -= 1;
        let usize closed = slices::close(ref mut planned, arguments.tickets[i], ref mut planned_table, capacity)?;
    }
    pool.slots = planned.slots;
    table.slots = planned_table.slots;
    arguments.tickets = [slices::Ticket { .slot = 16, .generation = 0 }; 8];
    arguments.count = 0;
    return .ok(count);
}
