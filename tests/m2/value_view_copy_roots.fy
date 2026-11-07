module tests::m2::value_view_copy_roots;
import value_buffer_views as views;
import value_roots as roots;
import buffer_growth as growth;
import std::bytes as bytes;
import std::vec as vec;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=32768,.engine=32768};}
fn usize root_ok(Result<usize,roots::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize ok(Result<usize,views::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn views::Ticket ticket(Result<views::Ticket,views::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);views::Ticket{.slot=32,.generation=0}}};}
fn u8 root_code(roots::Error e){return switch(e){case .Fuel:{1}case .State:{2}case .Binding:{3}case .Serial:{4}case .Owners:{5}case .Quota:{6}case .Allocation:{7}case .Bounds:{8}};}
fn u8 code(views::Error e){return switch(e){case .Fuel:{1}case .State:{2}case .Binding:{3}case .Stale:{4}case .Capacity:{5}case .Bounds:{6}case .Quota:{7}case .Allocation:{8}};}
fn void root_error(Result<usize,roots::Error> r,u8 expected){assert(switch(r){case .ok(_):{false}case .err(e):{root_code(e)==expected}});}
fn void error(Result<usize,views::Error> r,u8 expected){assert(switch(r){case .ok(_):{false}case .err(e):{code(e)==expected}});}
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
    var u8[80] output=[0;80];assert(expected.len<=80);var usize fuel=10000;
    assert(root_ok(roots::len(s,data,scratch,serial,binding,ref mut fuel))==expected.len);
    assert(root_ok(roots::copy_out(s,data,scratch,serial,binding,0,ref mut output[..expected.len],ref mut fuel))==expected.len);
    assert(bytes::equal(ref output[..expected.len],expected));assert(vec::len<bytes::Buffer>(scratch)==0);
}
fn void view_content(ref views::Pool p,ref roots::State s,ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,views::Ticket t,usize selected,ref u8[] expected){
    var u8[16] output=[0;16];assert(expected.len<=16);var usize fuel=ok(views::copy_cost(expected.len));
    assert(ok(views::copy_out(p,s,data,scratch,t,selected,ref mut output[..expected.len],ref mut fuel))==expected.len && fuel==0);
    assert(bytes::equal(ref output[..expected.len],expected));
}
fn void unchanged(ref roots::State s,ref roots::State before){
    assert(s.next==before.next && s.closed==before.closed && s.external==before.external && s.closing.active==before.closing.active);
    assert(s.ledger.used==before.ledger.used && s.ledger.engine_used==before.ledger.engine_used &&
        s.ledger.peak==before.ledger.peak && s.ledger.engine_peak==before.ledger.engine_peak &&
        s.ledger.pending==before.ledger.pending && s.ledger.old_capacity==before.ledger.old_capacity &&
        s.ledger.new_capacity==before.ledger.new_capacity && s.ledger.before_used==before.ledger.before_used &&
        s.ledger.before_engine_used==before.ledger.before_engine_used && growth::settled(ref s.ledger));
    var usize i=0;while(i<16){
        assert(s.rows[i].serial==before.rows[i].serial && s.rows[i].binding==before.rows[i].binding &&
            s.rows[i].slot==before.rows[i].slot && s.rows[i].generation==before.rows[i].generation);
        assert(s.table.slots[i].generation==before.table.slots[i].generation && s.table.slots[i].live==before.table.slots[i].live &&
            s.table.slots[i].length==before.table.slots[i].length && s.table.slots[i].capacity==before.table.slots[i].capacity &&
            s.table.slots[i].reading==before.table.slots[i].reading);i+=1;
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

@test fn void nested_and_empty_windows_copy_both_vector_orders_and_keep_source_pinned(){
    var usize mode=0;while(mode<2){
        var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=1000000;
        var roots::State s=opened(ref mut data,ref mut scratch,ref mut fuel);var usize source=0;var usize dest=0;
        if(mode==0){dest=insert(ref mut s,ref mut data,ref mut scratch,2,b"",ref mut fuel);source=insert(ref mut s,ref mut data,ref mut scratch,7,b"abcdef",ref mut fuel);}
        else{source=insert(ref mut s,ref mut data,ref mut scratch,7,b"abcdef",ref mut fuel);dest=insert(ref mut s,ref mut data,ref mut scratch,2,b"!",ref mut fuel);}
        let usize tail=insert(ref mut s,ref mut data,ref mut scratch,3,b"tail",ref mut fuel);
        var views::Pool p=pool_open(ref mut s,ref data,ref scratch,ref mut fuel);
        let views::Ticket parent=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,source,7,10,1,5,ref mut fuel));
        let views::Ticket nested=ticket(views::range(ref mut p,ref mut s,ref data,ref scratch,parent,10,11,1,3,ref mut fuel));
        let views::Ticket empty=ticket(views::range(ref mut p,ref mut s,ref data,ref scratch,nested,11,12,2,2,ref mut fuel));
        let views::Pool before=p;
        assert(root_ok(roots::append_from_cost(0,2))==2312 && root_ok(roots::append_window_cost(0,2))==2312 && ok(views::append_to_cost(0,2))==2568);
        fuel=ok(views::append_to_cost(mode,2));
        assert(ok(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,nested,11,dest,2,limits(),ref mut fuel))==mode+2 && fuel==0);
        pool_unchanged(ref p,ref before);
        if(mode==0){content(ref s,ref data,ref scratch,dest,2,b"cd");}else{content(ref s,ref data,ref scratch,dest,2,b"!cd");}
        content(ref s,ref data,ref scratch,source,7,b"abcdef");content(ref s,ref data,ref scratch,tail,3,b"tail");
        let roots::State copied=s;fuel=ok(views::append_to_cost(mode+2,0));
        assert(ok(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,empty,12,dest,2,limits(),ref mut fuel))==mode+2 && fuel==0);
        unchanged(ref s,ref copied);pool_unchanged(ref p,ref before);
        fuel=root_ok(roots::append_window_cost(mode+2,2));
        assert(root_ok(roots::append_window(ref mut s,ref mut data,ref mut scratch,dest,2,source,7,4,2,limits(),ref mut fuel))==mode+4 && fuel==0);
        if(mode==0){content(ref s,ref data,ref scratch,dest,2,b"cdef");}else{content(ref s,ref data,ref scratch,dest,2,b"!cdef");}
        // End-of-initialized-input empty windows are valid even with spare capacity.
        let roots::State appended=s;fuel=root_ok(roots::append_window_cost(mode+4,0));
        assert(root_ok(roots::append_window(ref mut s,ref mut data,ref mut scratch,dest,2,source,7,6,0,limits(),ref mut fuel))==mode+4 && fuel==0);
        unchanged(ref s,ref appended);fuel=100000;
        assert(root_ok(roots::write(ref s,ref mut data,ref mut scratch,dest,2,0,b"X",limits(),ref mut fuel))==1);
        view_content(ref p,ref s,ref data,ref scratch,nested,11,b"cd");
        let usize dropped=root_ok(roots::drop(ref mut s,ref mut data,ref mut scratch,dest,2,ref mut fuel));
        view_content(ref p,ref s,ref data,ref scratch,parent,10,b"bcde");view_content(ref p,ref s,ref data,ref scratch,nested,11,b"cd");
        let roots::State held=s;
        root_error(roots::write(ref s,ref mut data,ref mut scratch,source,7,0,b"Z",limits(),ref mut fuel),2);unchanged(ref s,ref held);
        let usize a=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,parent,10));
        let usize b=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,nested,11));
        root_error(roots::drop(ref mut s,ref mut data,ref mut scratch,source,7,ref mut fuel),2);unchanged(ref s,ref held);
        fuel=0;let usize c=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,empty,12));assert(fuel==0);
        content(ref s,ref data,ref scratch,source,7,b"abcdef");fuel=10000;
        assert(root_ok(roots::write(ref s,ref mut data,ref mut scratch,source,7,0,b"Z",limits(),ref mut fuel))==1);
        let usize charged=s.ledger.used;let usize engine=s.ledger.engine_used;fuel=0;
        let usize shut=ok(views::shutdown(ref mut p,ref mut s,ref data,ref scratch));
        assert(s.ledger.used==charged-4096 && s.ledger.engine_used==engine-4096);
        assert(root_ok(roots::drain(ref mut s,ref mut data,ref mut scratch))==0 && fuel==0 && s.ledger.used==0 && s.ledger.engine_used==0);
        assert(vec::len<bytes::Buffer>(ref data)==0 && vec::len<bytes::Buffer>(ref scratch)==0);mode+=1;
    }
}

@test fn void rejected_window_bounds_fuel_and_quotas_preserve_bytes_and_full_metadata(){
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var roots::State s=opened(ref mut data,ref mut scratch,ref mut fuel);
    let u8[63] prefix=[90;63];
    let usize dest=insert(ref mut s,ref mut data,ref mut scratch,2,ref prefix,ref mut fuel);
    let usize source=insert(ref mut s,ref mut data,ref mut scratch,7,b"abcdef",ref mut fuel);
    var views::Pool p=pool_open(ref mut s,ref data,ref scratch,ref mut fuel);
    let views::Ticket t=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,source,7,10,2,4,ref mut fuel));
    let roots::State before=s;let views::Pool prior=p;let usize cost=ok(views::append_to_cost(63,2));
    fuel=255;error(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,t,10,dest,2,limits(),ref mut fuel),1);assert(fuel==255);unchanged(ref s,ref before);
    fuel=767;error(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,t,10,dest,2,limits(),ref mut fuel),1);assert(fuel==511);unchanged(ref s,ref before);
    fuel=cost-1;error(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,t,10,dest,2,limits(),ref mut fuel),1);assert(fuel==cost-769);unchanged(ref s,ref before);
    fuel=root_ok(roots::append_window_cost(63,2))-1;
    root_error(roots::append_window(ref mut s,ref mut data,ref mut scratch,dest,2,source,7,2,2,limits(),ref mut fuel),1);assert(fuel==cost-769);unchanged(ref s,ref before);
    // Every invalid endpoint is checked against initialized length, never capacity.
    var usize mode=0;while(mode<4){
        let usize start=if(mode==0){6}else if(mode==1){7}else if(mode==2){18446744073709551615}else{1};
        let usize length=if(mode==1){0}else if(mode==3){18446744073709551615}else{1};fuel=512;
        root_error(roots::append_window(ref mut s,ref mut data,ref mut scratch,dest,2,source,7,start,length,limits(),ref mut fuel),8);assert(fuel==0);
        unchanged(ref s,ref before);content(ref s,ref data,ref scratch,dest,2,ref prefix);content(ref s,ref data,ref scratch,source,7,b"abcdef");mode+=1;
    }
    mode=0;while(mode<3){
        let growth::Limits tight=growth::Limits{.object=if(mode==0){127}else{4096},
            .instance=if(mode==1){s.ledger.used+191}else{32768},.engine=if(mode==2){s.ledger.engine_used+191}else{32768}};
        fuel=cost;error(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,t,10,dest,2,tight,ref mut fuel),7);assert(fuel==0);
        unchanged(ref s,ref before);pool_unchanged(ref p,ref prior);
        content(ref s,ref data,ref scratch,dest,2,ref prefix);view_content(ref p,ref s,ref data,ref scratch,t,10,b"cd");mode+=1;
    }
    let growth::Limits no_op_tight=growth::Limits{.object=4096,.instance=s.ledger.used-1,.engine=32768};
    fuel=root_ok(roots::append_window_cost(63,0));
    root_error(roots::append_window(ref mut s,ref mut data,ref mut scratch,dest,2,source,7,6,0,no_op_tight,ref mut fuel),6);assert(fuel==0);unchanged(ref s,ref before);
    root_error(roots::append_window_cost(18446744073709551615,1),8);
    error(views::append_to_cost(18446744073709551615,1),6);
    // Root price fits here, while the extra 256 view charge would overflow.
    assert(root_ok(roots::append_from_cost(4611686018427387264,0))==18446744073709551360);
    error(views::append_to_cost(4611686018427387264,0),6);
    let growth::Limits exact=growth::Limits{.object=128,.instance=s.ledger.used+192,.engine=s.ledger.engine_used+192};
    fuel=cost;assert(ok(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,t,10,dest,2,exact,ref mut fuel))==65 && fuel==0);
    assert(s.ledger.used==before.ledger.used+64 && s.ledger.engine_used==before.ledger.engine_used+64 &&
        s.ledger.peak==before.ledger.used+192 && s.ledger.engine_peak==before.ledger.engine_used+192 && growth::settled(ref s.ledger));
    var u8[65] expected=[90;65];expected[63]=99;expected[64]=100;
    content(ref s,ref data,ref scratch,dest,2,ref expected);view_content(ref p,ref s,ref data,ref scratch,t,10,b"cd");pool_unchanged(ref p,ref prior);
    let usize shut=ok(views::shutdown(ref mut p,ref mut s,ref data,ref scratch));assert(root_ok(roots::drain(ref mut s,ref mut data,ref mut scratch))==0);
}

@test fn void stale_wrong_binding_and_pinned_empty_destinations_reject_before_copy(){
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=1000000;
    var roots::State s=opened(ref mut data,ref mut scratch,ref mut fuel);
    let usize source=insert(ref mut s,ref mut data,ref mut scratch,7,b"abcdef",ref mut fuel);
    let usize dest=insert(ref mut s,ref mut data,ref mut scratch,2,b"",ref mut fuel);let roots::State unleased=s;
    fuel=512;root_error(roots::append_window(ref mut s,ref mut data,ref mut scratch,source,7,source,7,6,0,limits(),ref mut fuel),3);assert(fuel==0);unchanged(ref s,ref unleased);
    fuel=100000;var views::Pool p=pool_open(ref mut s,ref data,ref scratch,ref mut fuel);
    let views::Ticket stale=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,source,7,10,1,5,ref mut fuel));
    let usize closed=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,stale,10));
    let views::Ticket t=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,source,7,10,2,4,ref mut fuel));
    let views::Ticket empty=ticket(views::range(ref mut p,ref mut s,ref data,ref scratch,t,10,11,2,2,ref mut fuel));
    assert(t.slot==stale.slot && t.generation!=stale.generation);let roots::State before=s;let views::Pool prior=p;
    fuel=256;error(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,stale,10,dest,2,limits(),ref mut fuel),4);assert(fuel==0);unchanged(ref s,ref before);
    fuel=256;error(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,views::Ticket{.slot=32,.generation=t.generation},10,dest,2,limits(),ref mut fuel),4);assert(fuel==0);
    fuel=256;error(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,t,11,dest,2,limits(),ref mut fuel),3);assert(fuel==0);
    fuel=768;error(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,t,10,dest,3,limits(),ref mut fuel),3);assert(fuel==0);
    fuel=512;root_error(roots::append_window(ref mut s,ref mut data,ref mut scratch,dest,2,source,8,2,2,limits(),ref mut fuel),3);assert(fuel==0);
    fuel=768;error(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,empty,11,source,7,limits(),ref mut fuel),2);assert(fuel==0);
    unchanged(ref s,ref before);pool_unchanged(ref p,ref prior);content(ref s,ref data,ref scratch,dest,2,b"");view_content(ref p,ref s,ref data,ref scratch,t,10,b"cd");
    // A different source's empty window still cannot mutate a pinned destination.
    fuel=10000;let views::Ticket pinned=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,dest,2,12,0,0,ref mut fuel));
    let roots::State held=s;fuel=768;
    error(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,empty,11,dest,2,limits(),ref mut fuel),2);assert(fuel==0);unchanged(ref s,ref held);
    // Fault injection in trusted native bookkeeping must fail exact lease checks.
    let usize closed_empty=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,empty,11));
    let views::Row actual=p.rows[t.slot];var views::Row forged=actual;forged.owner_slot=s.rows[1].slot;p.rows[t.slot]=forged;fuel=256;
    error(views::append_to(ref p,ref mut s,ref mut data,ref mut scratch,t,10,dest,2,limits(),ref mut fuel),2);assert(fuel==0);unchanged(ref s,ref held);p.rows[t.slot]=actual;
    fuel=0;let usize unpin=ok(views::close(ref mut p,ref mut s,ref data,ref scratch,pinned,12));
    let usize shut=ok(views::shutdown(ref mut p,ref mut s,ref data,ref scratch));assert(root_ok(roots::drain(ref mut s,ref mut data,ref mut scratch))==0 && fuel==0);
}
