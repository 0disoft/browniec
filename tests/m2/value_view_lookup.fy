module tests::m2::value_view_lookup;
import value_buffer_views as views;
import value_roots as roots;
import buffer_owners as owners;
import buffer_growth as growth;
import std::bytes as bytes;
import std::vec as vec;
// Frozen original 9256469 header, resolver and lookup for diagnostic parity.
fn views::Error root_error(roots::Error e){return switch(e){case .Fuel:{.Fuel}case .State:{.State}
    case .Binding:{.Binding}case .Serial:{.Stale}case .Owners:{.Capacity}
    case .Quota:{.Quota}case .Allocation:{.Allocation}case .Bounds:{.Bounds}};}

fn views::Row get(ref views::Pool pool,usize slot){assert(slot<32);return pool.rows[slot];}

fn Result<usize,views::Error> header(ref views::Pool pool){
    if(pool.closed){return .err(.State);}var usize i=0;
    while(i<32){let views::Row row=get(pool,i);
        if(row.live){
            if(row.generation==0 || row.binding>=512 || row.serial==0 || row.owner_binding>=512 ||
                row.owner_slot>=16 || row.owner_generation==0){return .err(.State);}
            var usize j=0;while(j<i){let views::Row other=get(pool,j);if(other.live){
                if(other.binding==row.binding || (other.serial==row.serial &&
                    (other.owner_binding!=row.owner_binding || other.owner_slot!=row.owner_slot ||
                        other.owner_generation!=row.owner_generation))){return .err(.State);}
            }j+=1;}
        }else if(row.binding!=512 || row.serial!=0 || row.owner_binding!=512 ||
            row.owner_slot!=16 || row.owner_generation!=0 || row.start!=0 || row.length!=0){return .err(.State);}
        i+=1;
    }return .ok(0);
}

fn Result<views::Row,views::Error> resolve(ref views::Pool pool,ref roots::State store,ref vec::Vec<bytes::Buffer> data,
    ref vec::Vec<bytes::Buffer> scratch,views::Ticket ticket,usize selected){
    let usize checked=header(pool)?;
    if(ticket.slot>=32 || ticket.generation==0){return .err(.Stale);}
    let views::Row row=get(pool,ticket.slot);
    if(!row.live || row.generation!=ticket.generation){return .err(.Stale);}
    if(row.binding!=selected){return .err(.Binding);}
    let owners::Owner owner=switch(roots::describe(store,data,scratch,row.serial,row.owner_binding)){
        case .ok(v):{v}case .err(e):{return .err(root_error(e));}
    };
    if(!owner.reading || owner.generation!=row.owner_generation || row.start>owner.length ||
        row.length>owner.length-row.start){return .err(.State);}
    var bool matched=false;var usize i=0;while(i<16){let roots::Row actual=store.rows[i];
        if(actual.serial==row.serial && actual.binding==row.owner_binding &&
            actual.slot==row.owner_slot && actual.generation==row.owner_generation){matched=true;}i+=1;}
    if(!matched){return .err(.State);}return .ok(row);
}

fn Result<views::Ticket,views::Error> original(ref views::Pool pool,ref roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,usize selected){
    let usize checked=header(pool)?;
    if(selected>=512){return .err(.Binding);}var usize i=0;
    while(i<32){let views::Row row=get(pool,i);if(row.live && row.binding==selected){
        let views::Ticket ticket=views::Ticket{.slot=i,.generation=row.generation};
        let views::Row authenticated=resolve(pool,store,data,scratch,ticket,selected)?;
        return .ok(ticket);
    }i+=1;}return .err(.Binding);
}
fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=32768,.engine=32768};}
fn usize root_ok(Result<usize,roots::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize ok(Result<usize,views::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn views::Ticket ticket(Result<views::Ticket,views::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);views::Ticket{.slot=32,.generation=0}}};}
fn u8 code(views::Error e){return switch(e){case .Fuel:{1}case .State:{2}case .Binding:{3}case .Stale:{4}
    case .Capacity:{5}case .Bounds:{6}case .Quota:{7}case .Allocation:{8}};}
fn void same(ref views::Pool p,ref roots::State s,ref vec::Vec<bytes::Buffer> data,
    ref vec::Vec<bytes::Buffer> scratch,usize selected){
    let Result<views::Ticket,views::Error> before=original(p,s,data,scratch,selected);
    let Result<views::Ticket,views::Error> after=views::lookup(p,s,data,scratch,selected);
    assert(switch(before){case .ok(a):{switch(after){case .ok(b):{a.slot==b.slot && a.generation==b.generation}case .err(_):{false}}}
        case .err(a):{switch(after){case .ok(_):{false}case .err(b):{code(a)==code(b)}}}});
}
// Baseline 209267c batch: retain complete staged header validation. Standalone
// lookup is independently checked against the frozen header/resolver above.
fn Result<usize,views::Error> original_aliases(ref mut views::Pool pool,ref roots::State store,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,
    ref usize[] sources,ref usize[] destinations,ref mut usize fuel){
    if(sources.len!=destinations.len){return .err(.Binding);}
    if(sources.len>8){return .err(.Capacity);}
    let usize charge=views::range_cost()*sources.len;let usize available=*fuel;
    if(available<charge){return .err(.Fuel);};*fuel=available-charge;
    let usize checked=header(pool)?;if(sources.len==0){return .ok(0);}
    var views::Pool staged=*pool;var usize i=0;
    while(i<sources.len){let views::Ticket source=views::lookup(pool,store,data,scratch,sources[i])?;
        let views::Row row=get(pool,source.slot);let usize staged_checked=header(ref staged)?;
        if(destinations[i]>=512){return .err(.Binding);}var usize j=0;
        while(j<32){if(staged.rows[j].live && staged.rows[j].binding==destinations[i]){return .err(.Binding);}j+=1;}
        var usize slot=0;while(slot<32){if(!staged.rows[slot].live && staged.rows[slot].generation!=0){break;}slot+=1;}
        if(slot==32){return .err(.Capacity);}let usize generation=staged.rows[slot].generation;
        staged.rows[slot]=views::Row{.generation=generation,.live=true,.binding=destinations[i],.serial=row.serial,
            .owner_binding=row.owner_binding,.owner_slot=row.owner_slot,.owner_generation=row.owner_generation,
            .start=row.start,.length=row.length};i+=1;
    }
    *pool=staged;return .ok(sources.len);
}
fn void same_pool(ref views::Pool a,ref views::Pool b){
    assert(a.closed==b.closed);var usize i=0;while(i<32){let views::Row x=a.rows[i];let views::Row y=b.rows[i];
        assert(x.generation==y.generation && x.live==y.live && x.binding==y.binding && x.serial==y.serial &&
            x.owner_binding==y.owner_binding && x.owner_slot==y.owner_slot && x.owner_generation==y.owner_generation &&
            x.start==y.start && x.length==y.length);i+=1;}
}
fn void alias_same(ref views::Pool p,ref roots::State s,ref vec::Vec<bytes::Buffer> data,
    ref vec::Vec<bytes::Buffer> scratch,ref usize[] sources,ref usize[] destinations,usize fuel){
    var views::Pool before=*p;var views::Pool after=*p;var usize old_fuel=fuel;var usize new_fuel=fuel;
    let Result<usize,views::Error> old=original_aliases(ref mut before,s,data,scratch,sources,destinations,ref mut old_fuel);
    let Result<usize,views::Error> got=views::aliases(ref mut after,s,data,scratch,sources,destinations,ref mut new_fuel);
    assert(old_fuel==new_fuel);
    assert(switch(old){case .ok(a):{switch(got){case .ok(b):{a==b}case .err(_):{false}}}
        case .err(a):{switch(got){case .ok(_):{false}case .err(b):{code(a)==code(b)}}}});
    same_pool(ref before,ref after);if(!got.is_ok){same_pool(ref after,p);}
}
fn void alias_queries(ref views::Pool p,ref roots::State s,ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch){
    var usize[8] from=[16;8];var usize[8] to=[128,129,130,131,132,133,134,135];let usize[4] sizes=[0,1,2,8];var usize i=0;
    while(i<4){let usize n=sizes[i];alias_same(p,s,data,scratch,ref from[..n],ref to[..n],512*n);i+=1;}
    alias_same(p,s,data,scratch,ref from,ref to,4095);
    alias_same(p,s,data,scratch,ref from[..1],ref to[..0],0);
    let usize[9] too_many=[16;9];let usize[9] destinations=[128;9];alias_same(p,s,data,scratch,ref too_many,ref destinations,0);
    from[7]=128;alias_same(p,s,data,scratch,ref from,ref to,4096);from[7]=16;
    to[7]=128;alias_same(p,s,data,scratch,ref from,ref to,4096);
    to[7]=512;alias_same(p,s,data,scratch,ref from,ref to,4096);
}
fn void queries(ref views::Pool p,ref roots::State s,ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch){
    same(p,s,data,scratch,16);same(p,s,data,scratch,23);same(p,s,data,scratch,47);
    same(p,s,data,scratch,511);same(p,s,data,scratch,512);same(p,s,data,scratch,18446744073709551615);
    alias_queries(p,s,data,scratch);
}
fn void corrupt(ref views::Pool clean,ref roots::State s,ref vec::Vec<bytes::Buffer> data,
    ref vec::Vec<bytes::Buffer> scratch,usize i,usize mode){
    var views::Pool p=*clean;
    if(mode==0){p.closed=true;}
    else if(mode==1){p.rows[i].generation=0;}
    else if(mode==2){p.rows[i].binding=512;}
    else if(mode==3){p.rows[i].serial=0;}
    else if(mode==4){p.rows[i].owner_binding=512;}
    else if(mode==5){p.rows[i].owner_slot=16;}
    else if(mode==6){p.rows[i].owner_generation=0;}
    else if(mode==7){p.rows[i].start=18446744073709551615;}
    else if(mode==8){p.rows[i].length=18446744073709551615;}
    else if(mode==9){p.rows[i].binding=clean.rows[0].binding;}
    else if(mode==10){p.rows[i].owner_binding=17;}
    else if(mode==11){p.rows[i].owner_slot=15;}
    else if(mode==12){p.rows[i].owner_generation=2;}
    else if(mode==13){let bool live=p.rows[i].live;p.rows[i].live=!live;}
    else if(mode==14){p.rows[i].generation=18446744073709551615;}
    else{p.rows[i].serial=18446744073709551615;}
    queries(ref p,s,data,scratch);
}
fn void root_faults(ref views::Pool p,ref roots::State clean,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch){
    var roots::State s=*clean;s.table.slots[0].reading=false;queries(p,ref s,data,scratch);
    s=*clean;s.rows[0].generation+=1;queries(p,ref s,data,scratch);
    s=*clean;s.table.slots[0].length=0;queries(p,ref s,data,scratch);
    s=*clean;s.closed=true;queries(p,ref s,data,scratch);
    s=*clean;s.ledger.used+=1;queries(p,ref s,data,scratch);
}
@test fn void original_lookup_matches_all_pool_sizes_metadata_faults_and_error_priorities(){
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var roots::State s=switch(roots::open(ref mut data,ref mut scratch,limits(),ref mut fuel)){
        case .ok(v):{v}case .err(_):{assert(false);original_lookup_matches_all_pool_sizes_metadata_faults_and_error_priorities();return;}};
    let usize serial=root_ok(roots::insert(ref mut s,ref mut data,ref mut scratch,16,b"abc",limits(),ref mut fuel));
    var views::Pool p=switch(views::open(ref mut s,ref data,ref scratch,limits(),ref mut fuel)){
        case .ok(v):{v}case .err(_):{assert(false);original_lookup_matches_all_pool_sizes_metadata_faults_and_error_priorities();return;}};
    var usize count=0;var views::Ticket first=views::Ticket{.slot=32,.generation=0};
    while(count<=32){queries(ref p,ref s,ref data,ref scratch);var usize i=0;
        while(i<count){same(ref p,ref s,ref data,ref scratch,16+i);i+=1;}
        if(count==0 || count==1 || count==8 || count==32){i=0;while(i<32){var usize mode=0;
            while(mode<16){corrupt(ref p,ref s,ref data,ref scratch,i,mode);mode+=1;}i+=1;}root_faults(ref p,ref s,ref data,ref scratch);}
        if(count==32){break;}
        if(count==0){first=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,16,16,0,3,ref mut fuel));}
        else{let views::Ticket added=ticket(views::alias(ref mut p,ref mut s,ref data,ref scratch,first,16,16+count,ref mut fuel));}
        count+=1;
    }
    let usize closed=ok(views::shutdown(ref mut p,ref mut s,ref data,ref scratch));
    assert(root_ok(roots::drain(ref mut s,ref mut data,ref mut scratch))==0);
}
@test fn void full_pool_lookup_then_read_keeps_exact_fuel_and_last_alias_cleanup(){
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var roots::State s=switch(roots::open(ref mut data,ref mut scratch,limits(),ref mut fuel)){
        case .ok(v):{v}case .err(_):{assert(false);full_pool_lookup_then_read_keeps_exact_fuel_and_last_alias_cleanup();return;}};
    let usize serial=root_ok(roots::insert(ref mut s,ref mut data,ref mut scratch,16,b"abc",limits(),ref mut fuel));
    var views::Pool p=switch(views::open(ref mut s,ref data,ref scratch,limits(),ref mut fuel)){
        case .ok(v):{v}case .err(_):{assert(false);full_pool_lookup_then_read_keeps_exact_fuel_and_last_alias_cleanup();return;}};
    let views::Ticket first=ticket(views::begin(ref mut p,ref mut s,ref data,ref scratch,serial,16,16,0,3,ref mut fuel));
    var usize i=1;while(i<32){let views::Ticket added=ticket(views::alias(ref mut p,ref mut s,ref data,ref scratch,first,16,16+i,ref mut fuel));i+=1;}
    fuel=4096*views::read_cost();i=0;while(i<4096){
        let views::Ticket selected=ticket(views::lookup(ref p,ref s,ref data,ref scratch,47));
        assert(switch(views::read(ref p,ref s,ref data,ref scratch,selected,47,1,ref mut fuel)){
            case .ok(v):{v==98}case .err(_):{false}});i+=1;
    }assert(fuel==0 && s.table.slots[0].reading);
    let usize closed=ok(views::shutdown(ref mut p,ref mut s,ref data,ref scratch));
    assert(fuel==0 && !s.table.slots[0].reading);
    assert(root_ok(roots::drain(ref mut s,ref mut data,ref mut scratch))==0 && s.ledger.used==0);
}
