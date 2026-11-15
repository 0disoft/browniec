module tests::m2::value_view_call_pool;
import value_buffer_views as views;
import value_roots as roots;
import buffer_growth as growth;
import buffer_owners as owners;
import std::bytes as bytes;
import std::vec as vec;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=32768,.engine=32768};}
fn usize root_ok(Result<usize,roots::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize ok(Result<usize,views::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn views::Ticket ticket(Result<views::Ticket,views::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);views::Ticket{.slot=32,.generation=0}}};}
fn u8 code(views::Error e){return switch(e){case .Fuel:{1}case .State:{2}case .Binding:{3}case .Stale:{4}case .Capacity:{5}case .Bounds:{6}case .Quota:{7}case .Allocation:{8}};}
fn void error(Result<usize,views::Error> r,u8 expected){assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});}
fn void ticket_error(Result<views::Ticket,views::Error> r,u8 expected){assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});}
fn roots::State opened(ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){
    return switch(roots::open(data,scratch,limits(),fuel)){case .ok(v):{v}case .err(_):{assert(false);opened(data,scratch,fuel)}};
}
fn views::Pool pool_open(ref mut roots::State s,ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){
    return switch(views::open(s,data,scratch,limits(),fuel)){case .ok(v):{v}case .err(_):{assert(false);pool_open(s,data,scratch,fuel)}};
}
fn usize insert(ref mut roots::State s,ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,usize binding,ref u8[] input,ref mut usize fuel){
    return root_ok(roots::insert(s,data,scratch,binding,input,limits(),fuel));
}
fn void content(ref roots::State s,ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,ref u8[] expected){
    var u8[16] output=[0;16];assert(expected.len<=16);var usize fuel=10000;
    assert(root_ok(roots::len(s,data,scratch,serial,binding,ref mut fuel))==expected.len);
    assert(root_ok(roots::copy_out(s,data,scratch,serial,binding,0,ref mut output[..expected.len],ref mut fuel))==expected.len);
    assert(bytes::equal(ref output[..expected.len],expected));assert(vec::len<bytes::Buffer>(scratch)==0);
}
fn void view_content(ref views::Pool p,ref roots::State s,ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,views::Ticket t,usize selected,ref u8[] expected){
    var u8[16] output=[0;16];assert(expected.len<=16);var usize fuel=ok(views::copy_cost(expected.len));
    assert(ok(views::copy_out(p,s,data,scratch,t,selected,ref mut output[..expected.len],ref mut fuel))==expected.len && fuel==0);
    assert(bytes::equal(ref output[..expected.len],expected));
}
// Only small native metadata is snapshotted. Buffers/vectors are never cloned.
fn void ledger_unchanged(ref growth::Ledger a,ref growth::Ledger b){
    assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);
}
fn void table_unchanged(ref owners::Table a,ref owners::Table b){
    var usize i=0;while(i<16){
        assert(a.slots[i].generation==b.slots[i].generation && a.slots[i].live==b.slots[i].live &&
            a.slots[i].length==b.slots[i].length && a.slots[i].capacity==b.slots[i].capacity &&
            a.slots[i].reading==b.slots[i].reading);i+=1;
    }
}
fn void unchanged(ref roots::State s,ref roots::State before){
    assert(s.next==before.next && s.closed==before.closed && s.external==before.external);
    ledger_unchanged(ref s.ledger,ref before.ledger);table_unchanged(ref s.table,ref before.table);
    assert(s.closing.active==before.closing.active && s.closing.source.slot==before.closing.source.slot &&
        s.closing.source.generation==before.closing.source.generation && s.closing.capacity==before.closing.capacity &&
        s.closing.charge==before.closing.charge);
    ledger_unchanged(ref s.closing.before,ref before.closing.before);table_unchanged(ref s.closing.after,ref before.closing.after);
    var usize i=0;while(i<16){
        assert(s.rows[i].serial==before.rows[i].serial && s.rows[i].binding==before.rows[i].binding &&
            s.rows[i].slot==before.rows[i].slot && s.rows[i].generation==before.rows[i].generation);i+=1;
    }
}
fn void pool_unchanged(ref views::Pool p,ref views::Pool before){
    assert(p.closed==before.closed);var usize i=0;while(i<32){
        assert(p.rows[i].generation==before.rows[i].generation && p.rows[i].live==before.rows[i].live &&
            p.rows[i].binding==before.rows[i].binding && p.rows[i].serial==before.rows[i].serial &&
            p.rows[i].owner_binding==before.rows[i].owner_binding && p.rows[i].owner_slot==before.rows[i].owner_slot &&
            p.rows[i].owner_generation==before.rows[i].owner_generation && p.rows[i].start==before.rows[i].start &&
            p.rows[i].length==before.rows[i].length);i+=1;
    }
}
fn void finish(ref mut views::Pool p,ref mut roots::State s,ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch){
    let usize shut=ok(views::shutdown(p,s,data,scratch));assert(root_ok(roots::drain(s,data,scratch))==0);
    assert(s.ledger.used==0 && s.ledger.engine_used==0 && vec::len<bytes::Buffer>(data)==0 && vec::len<bytes::Buffer>(scratch)==0);
}

@test fn void atomic_duplicate_sources_exact_fuel_and_late_failures_publish_nothing(){
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var roots::State s=opened(ref mut data,ref mut scratch,ref mut fuel);
    let usize serial=insert(ref mut s,ref mut data,ref mut scratch,7,b"abcdef",ref mut fuel);
    var views::Pool p=pool_open(ref mut s,ref data,ref scratch,ref mut fuel);
    let views::Ticket parent=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,10,1,5,ref mut fuel));
    let views::Ticket nested=ticket(views::range(ref mut p,ref mut s,ref data,ref scratch,parent,10,11,1,3,ref mut fuel));
    let roots::State held=s;let views::Pool initial=p;
    var usize[8] sources=[10;8];sources[7]=11;var usize[8] destinations=[0;8];
    var usize i=0;while(i<8){destinations[i]=20+i;i+=1;}
    fuel=4095;error(views::aliases(ref mut p,ref s,ref data,ref scratch,ref sources,ref destinations,ref mut fuel),1);
    assert(fuel==4095);pool_unchanged(ref p,ref initial);unchanged(ref s,ref held);
    fuel=4096;assert(ok(views::aliases(ref mut p,ref s,ref data,ref scratch,ref sources,ref destinations,ref mut fuel))==8 && fuel==0);
    unchanged(ref s,ref held);assert(views::snapshot(ref p).live==10);
    i=0;while(i<8){
        let views::Ticket added=ticket(views::lookup(ref p,ref s,ref data,ref scratch,20+i));
        assert(added.generation==initial.rows[added.slot].generation);
        if(i==7){view_content(ref p,ref s,ref data,ref scratch,added,20+i,b"cd");}
        else{view_content(ref p,ref s,ref data,ref scratch,added,20+i,b"bcde");}i+=1;
    }
    view_content(ref p,ref s,ref data,ref scratch,parent,10,b"bcde");view_content(ref p,ref s,ref data,ref scratch,nested,11,b"cd");
    let views::Pool published=p;fuel=0;
    assert(ok(views::aliases(ref mut p,ref s,ref data,ref scratch,ref sources[..0],ref destinations[..0],ref mut fuel))==0 && fuel==0);
    pool_unchanged(ref p,ref published);unchanged(ref s,ref held);
    error(views::aliases(ref mut p,ref s,ref data,ref scratch,ref sources[..1],ref destinations[..0],ref mut fuel),3);assert(fuel==0);
    let usize[9] too_many=[10;9];let usize[9] too_many_destinations=[100;9];fuel=4608;
    error(views::aliases(ref mut p,ref s,ref data,ref scratch,ref too_many,ref too_many_destinations,ref mut fuel),5);assert(fuel==4608);
    pool_unchanged(ref p,ref published);unchanged(ref s,ref held);
    // Fail only after one successful staged alias. A staged destination must
    // never become an admissible source in the same batch.
    var usize mode=0;while(mode<6){
        var usize[2] from=[10,11];var usize[2] to=[30,31];
        if(mode==0){from[1]=511;}else if(mode==1){from[1]=30;}
        else if(mode==2){to[1]=30;}else if(mode==3){to[1]=20;}
        else if(mode==4){to[1]=512;}else{from[1]=512;}
        fuel=1024;error(views::aliases(ref mut p,ref s,ref data,ref scratch,ref from,ref to,ref mut fuel),3);assert(fuel==0);
        pool_unchanged(ref p,ref published);unchanged(ref s,ref held);mode+=1;
    }
    // A valid header alone is insufficient: authenticate the exact source
    // window against initialized bytes, including a late invalid operand.
    let views::Row actual=p.rows[nested.slot];var views::Row forged=actual;forged.start=6;forged.length=1;p.rows[nested.slot]=forged;
    let views::Pool invalid=p;let usize[2] from=[10,11];let usize[2] to=[30,31];fuel=1024;
    error(views::aliases(ref mut p,ref s,ref data,ref scratch,ref from,ref to,ref mut fuel),2);assert(fuel==0);
    pool_unchanged(ref p,ref invalid);unchanged(ref s,ref held);p.rows[nested.slot]=actual;
    i=10;fuel=100000;while(i<31){let views::Ticket extra=ticket(views::alias(ref mut p,ref mut s,ref data,ref scratch,parent,10,100+i,ref mut fuel));i+=1;}
    let views::Pool almost_full=p;assert(views::snapshot(ref p).live==31);fuel=1024;
    error(views::aliases(ref mut p,ref s,ref data,ref scratch,ref from,ref to,ref mut fuel),5);assert(fuel==0);
    pool_unchanged(ref p,ref almost_full);unchanged(ref s,ref held);content(ref s,ref data,ref scratch,serial,7,b"abcdef");
    finish(ref mut p,ref mut s,ref mut data,ref mut scratch);
}

@test fn void contained_ranges_and_empty_boundaries_retain_exact_lease_after_caller_close(){
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var roots::State s=opened(ref mut data,ref mut scratch,ref mut fuel);
    let usize serial=insert(ref mut s,ref mut data,ref mut scratch,7,b"abcdef",ref mut fuel);
    var views::Pool p=pool_open(ref mut s,ref data,ref scratch,ref mut fuel);
    let views::Ticket origin=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,10,1,5,ref mut fuel));
    let usize[2] sources=[10,10];let usize[2] destinations=[20,23];fuel=1024;
    assert(ok(views::aliases(ref mut p,ref s,ref data,ref scratch,ref sources,ref destinations,ref mut fuel))==2 && fuel==0);
    let views::Ticket callee=ticket(views::lookup(ref p,ref s,ref data,ref scratch,20));
    let views::Ticket equal=ticket(views::lookup(ref p,ref s,ref data,ref scratch,23));fuel=1024;
    let views::Ticket nested=ticket(views::range(ref mut p,ref mut s,ref data,ref scratch,callee,20,21,1,3,ref mut fuel));
    let views::Ticket empty=ticket(views::range(ref mut p,ref mut s,ref data,ref scratch,callee,20,22,4,4,ref mut fuel));assert(fuel==0);
    let roots::State held=s;var views::Pool expected=p;expected.rows[nested.slot].binding=30;fuel=256;
    let views::Ticket result=ticket(views::handoff(ref mut p,ref mut s,ref data,ref scratch,nested,21,30,origin,10,ref mut fuel));
    assert(result.slot==nested.slot && result.generation==nested.generation && fuel==0);
    pool_unchanged(ref p,ref expected);unchanged(ref s,ref held);expected.rows[empty.slot].binding=31;fuel=256;
    let views::Ticket empty_result=ticket(views::handoff(ref mut p,ref mut s,ref data,ref scratch,empty,22,31,origin,10,ref mut fuel));
    assert(empty_result.slot==empty.slot && empty_result.generation==empty.generation && fuel==0);
    pool_unchanged(ref p,ref expected);unchanged(ref s,ref held);expected.rows[equal.slot].binding=32;fuel=256;
    let views::Ticket equal_result=ticket(views::handoff(ref mut p,ref mut s,ref data,ref scratch,equal,23,32,origin,10,ref mut fuel));
    assert(equal_result.slot==equal.slot && equal_result.generation==equal.generation && fuel==0);
    pool_unchanged(ref p,ref expected);unchanged(ref s,ref held);
    error(views::length(ref p,ref s,ref data,ref scratch,result,21,ref mut fuel),1);assert(fuel==0);
    fuel=256;error(views::length(ref p,ref s,ref data,ref scratch,result,21,ref mut fuel),3);assert(fuel==0);
    let usize caller_closed=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,origin,10));
    let usize callee_closed=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,callee,20));unchanged(ref s,ref held);
    view_content(ref p,ref s,ref data,ref scratch,result,30,b"cd");view_content(ref p,ref s,ref data,ref scratch,empty_result,31,b"");
    view_content(ref p,ref s,ref data,ref scratch,equal_result,32,b"bcde");content(ref s,ref data,ref scratch,serial,7,b"abcdef");
    fuel=10000;assert(!roots::write(ref s,ref mut data,ref mut scratch,serial,7,0,b"X",limits(),ref mut fuel).is_ok);
    assert(!roots::drop(ref mut s,ref mut data,ref mut scratch,serial,7,ref mut fuel).is_ok);unchanged(ref s,ref held);
    let usize equal_closed=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,equal_result,32));
    let usize nested_closed=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,result,30));unchanged(ref s,ref held);
    view_content(ref p,ref s,ref data,ref scratch,empty_result,31,b"");
    assert(!roots::write(ref s,ref mut data,ref mut scratch,serial,7,0,b"X",limits(),ref mut fuel).is_ok);unchanged(ref s,ref held);
    fuel=0;let usize empty_closed=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,empty_result,31));assert(empty_closed==0 && fuel==0);
    var roots::State released=held;released.table.slots[held.rows[0].slot].reading=false;unchanged(ref s,ref released);
    content(ref s,ref data,ref scratch,serial,7,b"abcdef");
    // An empty caller origin at the root's initialized end also admits an
    // exactly equal empty return; neither capacity nor a +end check is used.
    fuel=10000;let views::Ticket end_origin=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,40,6,6,ref mut fuel));
    let usize[1] end_from=[40];let usize[1] end_to=[41];fuel=512;
    assert(ok(views::aliases(ref mut p,ref s,ref data,ref scratch,ref end_from,ref end_to,ref mut fuel))==1 && fuel==0);
    let views::Ticket end_source=ticket(views::lookup(ref p,ref s,ref data,ref scratch,41));let roots::State end_held=s;fuel=256;
    let views::Ticket end_result=ticket(views::handoff(ref mut p,ref mut s,ref data,ref scratch,end_source,41,42,end_origin,40,ref mut fuel));
    assert(end_result.slot==end_source.slot && end_result.generation==end_source.generation && fuel==0);unchanged(ref s,ref end_held);
    let usize end_caller_closed=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,end_origin,40));unchanged(ref s,ref end_held);
    view_content(ref p,ref s,ref data,ref scratch,end_result,42,b"");
    let usize end_closed=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,end_result,42));unchanged(ref s,ref released);
    content(ref s,ref data,ref scratch,serial,7,b"abcdef");fuel=10000;
    assert(root_ok(roots::write(ref s,ref mut data,ref mut scratch,serial,7,0,b"X",limits(),ref mut fuel))==1);
    content(ref s,ref data,ref scratch,serial,7,b"Xbcdef");finish(ref mut p,ref mut s,ref mut data,ref mut scratch);
}

@test fn void rejected_handoffs_and_exhausted_aliases_preserve_every_metadata_field_and_bytes(){
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var roots::State s=opened(ref mut data,ref mut scratch,ref mut fuel);
    let usize serial=insert(ref mut s,ref mut data,ref mut scratch,7,b"abcdef",ref mut fuel);
    let usize other_serial=insert(ref mut s,ref mut data,ref mut scratch,8,b"UVWXYZ",ref mut fuel);
    var views::Pool p=pool_open(ref mut s,ref data,ref scratch,ref mut fuel);
    let views::Ticket origin=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,10,1,5,ref mut fuel));
    let views::Ticket stale=ticket(views::alias(ref mut p,ref mut s,ref data,ref scratch,origin,10,11,ref mut fuel));
    let usize retired=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,stale,11));
    let views::Ticket occupied=ticket(views::alias(ref mut p,ref mut s,ref data,ref scratch,origin,10,11,ref mut fuel));
    assert(occupied.slot==stale.slot && occupied.generation!=stale.generation);
    let views::Ticket narrow=ticket(views::range(ref mut p,ref mut s,ref data,ref scratch,origin,10,12,1,3,ref mut fuel));
    let views::Ticket source=ticket(views::alias(ref mut p,ref mut s,ref data,ref scratch,origin,10,20,ref mut fuel));
    let views::Ticket other=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,other_serial,8,21,1,5,ref mut fuel));
    let views::Ticket lower=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,22,0,2,ref mut fuel));
    let views::Ticket upper=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,23,4,6,ref mut fuel));
    let views::Ticket empty=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,7,24,6,6,ref mut fuel));
    let roots::State held=s;let views::Row source_row=p.rows[source.slot];let views::Row origin_row=p.rows[origin.slot];
    var usize mode=0;while(mode<21){
        var views::Ticket selected_ticket=source;var usize selected=20;var usize destination=30;
        var views::Ticket caller=origin;var usize caller_binding=10;var u8 expected=3;
        if(mode==0){selected_ticket=stale;selected=11;expected=4;}
        else if(mode==1){caller=stale;caller_binding=11;expected=4;}
        else if(mode==2){selected=19;}
        else if(mode==3){caller_binding=11;}
        else if(mode==4){caller=other;caller_binding=21;}
        else if(mode==5){selected_ticket=other;selected=21;}
        else if(mode==6){selected_ticket=lower;selected=22;expected=6;}
        else if(mode==7){selected_ticket=upper;selected=23;expected=6;}
        else if(mode==8){selected_ticket=empty;selected=24;expected=6;}
        else if(mode==9){caller=narrow;caller_binding=12;expected=6;}
        else if(mode==10){destination=11;}
        else if(mode==11){destination=20;}
        else if(mode==12){destination=512;}
        else if(mode==13){expected=1;}
        else if(mode==14){caller=stale;caller_binding=11;expected=1;}
        else if(mode==15){selected_ticket=views::Ticket{.slot=32,.generation=source.generation};expected=4;}
        else if(mode==16){caller=views::Ticket{.slot=origin.slot,.generation=0};expected=4;}
        else if(mode==17){var views::Row forged=source_row;forged.owner_slot=held.rows[1].slot;p.rows[source.slot]=forged;expected=2;}
        else if(mode==18){var views::Row forged=source_row;forged.start=18446744073709551615;forged.length=0;p.rows[source.slot]=forged;expected=2;}
        else if(mode==19){var views::Row forged=origin_row;forged.start=18446744073709551615;forged.length=0;p.rows[origin.slot]=forged;expected=2;}
        else{s.table.slots[held.rows[0].slot].reading=false;expected=2;}
        let views::Pool before=p;let roots::State root_before=s;
        fuel=if(mode==13){255}else if(mode==14){0}else{256};let usize remaining=if(mode==13){255}else{0};
        ticket_error(views::handoff(ref mut p,ref mut s,ref data,ref scratch,selected_ticket,selected,destination,caller,caller_binding,ref mut fuel),expected);
        assert(fuel==remaining);pool_unchanged(ref p,ref before);unchanged(ref s,ref root_before);
        p.rows[source.slot]=source_row;p.rows[origin.slot]=origin_row;s.table.slots[held.rows[0].slot].reading=true;
        unchanged(ref s,ref held);content(ref s,ref data,ref scratch,serial,7,b"abcdef");content(ref s,ref data,ref scratch,other_serial,8,b"UVWXYZ");mode+=1;
    }
    // Retired descriptor generations cannot provide alias capacity.
    var usize i=0;while(i<32){if(!p.rows[i].live){p.rows[i].generation=0;}i+=1;}
    let views::Pool retired_pool=p;let usize[1] from=[20];let usize[1] to=[400];fuel=512;
    error(views::aliases(ref mut p,ref s,ref data,ref scratch,ref from,ref to,ref mut fuel),5);assert(fuel==0);
    pool_unchanged(ref p,ref retired_pool);unchanged(ref s,ref held);
    // Restore only free metadata, fill the registry, and prove RETURN requires
    // no spare descriptor while CALL aliases fail without changing anything.
    i=0;while(i<32){if(!p.rows[i].live){p.rows[i].generation=1;}i+=1;}
    fuel=100000;i=views::snapshot(ref p).live;while(i<32){
        let views::Ticket extra=ticket(views::alias(ref mut p,ref mut s,ref data,ref scratch,source,20,200+i,ref mut fuel));i+=1;
    }
    let views::Pool full=p;fuel=512;
    error(views::aliases(ref mut p,ref s,ref data,ref scratch,ref from,ref to,ref mut fuel),5);assert(fuel==0);
    pool_unchanged(ref p,ref full);unchanged(ref s,ref held);var views::Pool moved=full;moved.rows[source.slot].binding=400;fuel=256;
    let views::Ticket returned=ticket(views::handoff(ref mut p,ref mut s,ref data,ref scratch,source,20,400,origin,10,ref mut fuel));
    assert(returned.slot==source.slot && returned.generation==source.generation && fuel==0);
    pool_unchanged(ref p,ref moved);unchanged(ref s,ref held);view_content(ref p,ref s,ref data,ref scratch,returned,400,b"bcde");
    content(ref s,ref data,ref scratch,serial,7,b"abcdef");content(ref s,ref data,ref scratch,other_serial,8,b"UVWXYZ");
    let usize shut=ok(views::shutdown(ref mut p,ref mut s,ref data,ref scratch));let views::Pool closed=p;let roots::State released=s;fuel=0;
    error(views::aliases(ref mut p,ref s,ref data,ref scratch,ref from[..0],ref to[..0],ref mut fuel),2);assert(fuel==0);
    fuel=256;ticket_error(views::handoff(ref mut p,ref mut s,ref data,ref scratch,returned,400,401,origin,10,ref mut fuel),2);assert(fuel==0);
    pool_unchanged(ref p,ref closed);unchanged(ref s,ref released);assert(root_ok(roots::drain(ref mut s,ref mut data,ref mut scratch))==0);
}

@test fn void eight_aliases_fill_last_rows_preserve_source_windows_and_shared_leases(){
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var roots::State s=opened(ref mut data,ref mut scratch,ref mut fuel);
    let usize a=insert(ref mut s,ref mut data,ref mut scratch,7,b"abcdef",ref mut fuel);
    let usize b=insert(ref mut s,ref mut data,ref mut scratch,8,b"UVWXYZ",ref mut fuel);
    var views::Pool p=pool_open(ref mut s,ref data,ref scratch,ref mut fuel);
    let views::Ticket left=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,a,7,10,1,5,ref mut fuel));
    let views::Ticket right=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,b,8,11,1,5,ref mut fuel));
    var usize i=2;while(i<24){
        let views::Ticket extra=ticket(views::alias(ref mut p,ref mut s,ref data,ref scratch,
            if(i%2==0){left}else{right},if(i%2==0){10}else{11},20+i,ref mut fuel));i+=1;
    }
    assert(views::snapshot(ref p).live==24 && views::snapshot(ref p).roots==2);
    let views::Pool initial=p;let roots::State held=s;
    let usize[8] sources=[10,11,10,11,10,11,10,11];let usize[8] destinations=[100,101,102,103,104,105,106,107];
    fuel=4095;error(views::aliases(ref mut p,ref s,ref data,ref scratch,ref sources,ref destinations,ref mut fuel),1);
    assert(fuel==4095);pool_unchanged(ref p,ref initial);unchanged(ref s,ref held);
    fuel=4096;assert(ok(views::aliases(ref mut p,ref s,ref data,ref scratch,ref sources,ref destinations,ref mut fuel))==8 && fuel==0);
    assert(views::snapshot(ref p).live==32 && views::snapshot(ref p).roots==2);unchanged(ref s,ref held);
    i=0;while(i<24){var views::Pool expected=p;expected.rows[i]=initial.rows[i];pool_unchanged(ref p,ref expected);i+=1;}
    i=0;while(i<8){let views::Row row=p.rows[24+i];let views::Row source=initial.rows[i%2];
        assert(row.live && row.binding==destinations[i] && row.generation==initial.rows[24+i].generation &&
            row.serial==source.serial && row.owner_binding==source.owner_binding && row.owner_slot==source.owner_slot &&
            row.owner_generation==source.owner_generation && row.start==source.start && row.length==source.length);
        view_content(ref p,ref s,ref data,ref scratch,views::Ticket{.slot=24+i,.generation=row.generation},destinations[i],
            if(i%2==0){b"bcde"}else{b"VWXY"});i+=1;
    }
    fuel=0;finish(ref mut p,ref mut s,ref mut data,ref mut scratch);assert(fuel==0);
}
