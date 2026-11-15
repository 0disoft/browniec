module tests::m2::value_root_resolution;
import value_roots as store;
import buffer_owners as owners;
import buffer_growth as growth;
import std::bytes as bytes;
import std::vec as vec;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=32768,.engine=32768};}
fn u8 code(store::Error e){return switch(e){case .Fuel:{1}case .State:{2}case .Binding:{3}case .Serial:{4}
    case .Owners:{5}case .Quota:{6}case .Allocation:{7}case .Bounds:{8}};}
fn usize ok(Result<usize,store::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void same(Result<usize,store::Error> a,Result<usize,store::Error> b){
    assert(switch(a){case .ok(x):{switch(b){case .ok(y):{x==y}case .err(_):{false}}}
        case .err(x):{switch(b){case .ok(_):{false}case .err(y):{code(x)==code(y)}}}});
}
// Original 0f3472e resolver. inspect_store is the unchanged, independently
// tested full preflight; keep the raw owner API revalidation as the oracle.
fn Result<usize,store::Error> original(ref store::State s,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,bool writing){
    let usize count=store::inspect_store(s,roots,scratch)?;
    if(serial==0 || binding>=512){return .err(.Binding);}
    var usize i=0;while(i<count){let store::Row row=s.rows[i];
        if(row.serial==serial){
            if(row.binding!=binding){return .err(.Binding);}
            let owners::Token token=owners::Token{.slot=row.slot,.generation=row.generation};
            let Result<owners::Owner,owners::Error> checked=if(writing){owners::writable(ref s.table,token)}
                else{owners::describe(ref s.table,token)};
            let owners::Owner owner=switch(checked){case .ok(v):{v}case .err(_):{return .err(.State);}};
            let ref bytes::Buffer root=vec::at<bytes::Buffer>(roots,i);
            if(bytes::len(root)!=owner.length || bytes::capacity(root)!=owner.capacity){return .err(.State);}
            return .ok(i);
        }i+=1;
    }return .err(.Serial);
}
fn Result<owners::Owner,store::Error> described(ref store::State s,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding){
    let usize i=original(s,roots,scratch,serial,binding,false)?;let store::Row row=s.rows[i];
    return switch(owners::describe(ref s.table,owners::Token{.slot=row.slot,.generation=row.generation})){
        case .ok(v):{.ok(v)}case .err(_):{.err(.State)}};
}
fn Result<usize,store::Error> length(ref store::State s,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding){
    let usize i=original(s,roots,scratch,serial,binding,false)?;return .ok(bytes::len(vec::at<bytes::Buffer>(roots,i)));
}
fn Result<usize,store::Error> read(ref store::State s,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,usize index){
    let usize i=original(s,roots,scratch,serial,binding,false)?;let store::Row row=s.rows[i];
    return switch(owners::read(ref s.table,owners::Token{.slot=row.slot,.generation=row.generation},index,vec::at<bytes::Buffer>(roots,i))){
        case .ok(v):{.ok(v as usize)}case .err(e):{.err(switch(e){case .Bounds:{.Bounds}case .Owners:{.Owners}case .Token:{.State}case .State:{.State}})}};
}
// Frozen raw-owner copy path: keep independent table/backing/range checks.
fn Result<usize,store::Error> copied(ref store::State s,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,usize start,ref mut u8[] output){
    let usize i=original(s,roots,scratch,serial,binding,false)?;let store::Row row=s.rows[i];
    return switch(owners::copy_out(ref s.table,owners::Token{.slot=row.slot,.generation=row.generation},start,
        vec::at<bytes::Buffer>(roots,i),output)){case .ok(v):{.ok(v)}case .err(_):{.err(.Bounds)}};
}
fn void copy_boundary(ref store::State s,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,usize start,usize size){
    var u8[65] expected=[253;65];var u8[65] actual=[253;65];
    let Result<usize,store::Error> wanted=copied(s,roots,scratch,serial,binding,start,ref mut expected[..size]);
    var usize fuel=256+size;
    let Result<usize,store::Error> got=store::copy_out(s,roots,scratch,serial,binding,start,ref mut actual[..size],ref mut fuel);
    same(wanted,got);assert(fuel==0 && bytes::equal(ref actual,ref expected));
    if(!got.is_ok){let u8[65] untouched=[253;65];assert(bytes::equal(ref actual,ref untouched));}
    var u8[65] short_output=[253;65];let u8[65] untouched=[253;65];fuel=255+size;
    same(.err(.Fuel),store::copy_out(s,roots,scratch,serial,binding,start,ref mut short_output[..size],ref mut fuel));
    assert(fuel==255+size && bytes::equal(ref short_output,ref untouched));
}
fn void parity(ref store::State s,ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,
    usize serial,usize binding){
    copy_boundary(s,roots,scratch,serial,binding,0,3);
    copy_boundary(s,roots,scratch,serial,binding,1,3);
    copy_boundary(s,roots,scratch,serial,binding,18446744073709551615,0);
    let Result<owners::Owner,store::Error> expected=described(s,roots,scratch,serial,binding);
    let Result<owners::Owner,store::Error> actual=store::describe(s,roots,scratch,serial,binding);
    assert(switch(expected){case .err(x):{switch(actual){case .err(y):{code(x)==code(y)}case .ok(_):{false}}}
        case .ok(x):{switch(actual){case .err(_):{false}case .ok(y):{x.generation==y.generation && x.live==y.live &&
            x.length==y.length && x.capacity==y.capacity && x.reading==y.reading}}}});
    var usize fuel=store::len_cost()+1;same(length(s,roots,scratch,serial,binding),store::len(s,roots,scratch,serial,binding,ref mut fuel));
    assert(fuel==1);var usize index=0;
    while(index<4){fuel=store::read_cost();
        let Result<usize,store::Error> wanted=read(s,roots,scratch,serial,binding,index);
        let Result<usize,store::Error> got=switch(store::read(s,roots,scratch,serial,binding,index,ref mut fuel)){
            case .ok(v):{.ok(v as usize)}case .err(e):{.err(e)}};
        same(wanted,got);assert(fuel==0);index+=1;
    }
    let Result<usize,store::Error> writable=original(s,roots,scratch,serial,binding,true);
    fuel=256;let Result<usize,store::Error> written=store::write(s,roots,scratch,serial,binding,0,b"",limits(),ref mut fuel);
    switch(writable){case .ok(_):{same(.ok(0),written);}case .err(e):{same(.err(e),written);}};
    assert(fuel==0 && vec::len<bytes::Buffer>(scratch)==0);
    fuel=store::len_cost()-1;same(.err(.Fuel),store::len(s,roots,scratch,serial,binding,ref mut fuel));assert(fuel==255);
    fuel=store::read_cost()-1;assert(switch(store::read(s,roots,scratch,serial,binding,99,ref mut fuel)){
        case .ok(_):{false}case .err(e):{code(e)==1}});assert(fuel==256);
    var usize i=0;while(i<vec::len<bytes::Buffer>(roots)){assert(bytes::equal(bytes::view(vec::at<bytes::Buffer>(roots,i)),b"abc"));i+=1;}
}
fn void queries(ref store::State s,ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,
    usize serial,usize binding){
    parity(s,roots,scratch,serial,binding);parity(s,roots,scratch,0,binding);
    parity(s,roots,scratch,serial,512);parity(s,roots,scratch,serial,511);
    parity(s,roots,scratch,18446744073709551615,binding);
}
fn store::State opened(ref mut vec::Vec<bytes::Buffer> roots,ref mut vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){
    return switch(store::open(roots,scratch,limits(),fuel)){case .ok(v):{v}case .err(_):{assert(false);opened(roots,scratch,fuel)}};
}
fn store::State fault(ref store::State clean,usize slot,usize mode){var store::State s=*clean;
    if(mode==0){s.rows[slot].serial=0;}
    else if(mode==1){s.rows[slot].binding=512;}
    else if(mode==2){s.rows[slot].slot=16;}
    else if(mode==3){s.rows[slot].generation=0;}
    else if(mode==4){s.rows[slot].generation+=1;}
    else if(mode==5){s.rows[slot].serial=clean.rows[0].serial;}
    else if(mode==6){s.rows[slot].binding=clean.rows[0].binding;}
    else if(mode==7){s.rows[slot].slot=clean.rows[0].slot;}
    else if(mode==8){s.table.slots[slot].generation=0;}
    else if(mode==9){s.table.slots[slot].generation+=1;}
    else if(mode==10){let bool live=s.table.slots[slot].live;s.table.slots[slot].live=!live;}
    else if(mode==11){s.table.slots[slot].capacity=1;}
    else if(mode==12){s.table.slots[slot].length=65;}
    else if(mode==13){s.table.slots[slot].reading=true;}
    else if(mode==14){s.table.slots[slot].length=2;}
    else if(mode==15){s.ledger.used+=1;}
    else if(mode==16){s.closing.active=true;}
    else if(mode==17){s.ledger.pending=64;}
    else if(mode==18){s.external=1;}
    else{s.closed=true;}return s;
}
@test fn void checked_root_resolution_matches_original_for_every_row_and_combined_fault_priority(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
    var usize count=0;while(count<=16){
        if(count==0 || count==1 || count==8 || count==16){
            let usize serial=if(count==0){1}else{s.rows[count-1].serial};let usize binding=if(count==0){0}else{s.rows[count-1].binding};
            queries(ref s,ref mut roots,ref mut scratch,serial,binding);var usize slot=0;
            while(slot<16){var usize mode=0;while(mode<20){let store::State bad=fault(ref s,slot,mode);
                queries(ref bad,ref mut roots,ref mut scratch,serial,binding);mode+=1;}slot+=1;}
        }
        if(count==16){break;}let usize serial=ok(store::insert(ref mut s,ref mut roots,ref mut scratch,count,b"abc",limits(),ref mut fuel));count+=1;
    }
    assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0);
}
@test fn void reused_descriptor_slots_and_terminal_generations_keep_native_root_identity(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);var usize i=0;
    while(i<8){let usize serial=ok(store::insert(ref mut s,ref mut roots,ref mut scratch,i,b"abc",limits(),ref mut fuel));i+=1;}
    let store::Row removed=s.rows[3];let usize used=ok(store::drop(ref mut s,ref mut roots,ref mut scratch,removed.serial,removed.binding,ref mut fuel));
    let usize serial=ok(store::insert(ref mut s,ref mut roots,ref mut scratch,3,b"abc",limits(),ref mut fuel));
    assert(s.rows[7].slot==removed.slot && s.rows[7].generation!=removed.generation);
    i=0;while(i<8){let store::Row row=s.rows[i];queries(ref s,ref mut roots,ref mut scratch,row.serial,row.binding);i+=1;}
    queries(ref s,ref mut roots,ref mut scratch,removed.serial,removed.binding);
    let usize slot=s.rows[7].slot;s.rows[7].generation=18446744073709551615;s.table.slots[slot].generation=18446744073709551615;
    queries(ref s,ref mut roots,ref mut scratch,serial,3);
    assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0);
}

fn void read_boundary(ref store::State s,ref vec::Vec<bytes::Buffer> roots,
    ref vec::Vec<bytes::Buffer> scratch,usize serial,usize binding,usize index,ref u8[] expected){
    let Result<usize,store::Error> wanted=read(s,roots,scratch,serial,binding,index);
    var usize fuel=store::read_cost();
    let Result<usize,store::Error> got=switch(store::read(s,roots,scratch,serial,binding,index,ref mut fuel)){
        case .ok(v):{.ok(v as usize)}case .err(e):{.err(e)}};
    same(wanted,got);assert(fuel==0);
    if(index<expected.len){same(.ok(expected[index] as usize),got);}else{same(.err(.Bounds),got);}
    fuel=store::read_cost()-1;
    assert(switch(store::read(s,roots,scratch,0,512,index,ref mut fuel)){
        case .ok(_):{false}case .err(e):{code(e)==1}});assert(fuel==store::read_cost()-1);
}
@test fn void direct_reads_match_raw_owner_at_empty_alignment_and_extreme_boundaries_with_leases(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
    var u8[4096] input=[0;4096];var usize i=0;var u8 value=0;
    while(i<4096){input[i]=value;value=if(value==250){0}else{value+1};i+=1;}
    let usize[6] sizes=[0,1,63,64,65,4096];var usize n=0;
    while(n<sizes.len){let usize length=sizes[n];fuel=1000000;
        let usize serial=ok(store::insert(ref mut s,ref mut roots,ref mut scratch,n,ref input[..length],limits(),ref mut fuel));
        let usize cap=bytes::capacity(vec::at<bytes::Buffer>(ref roots,n));
        let usize[6] indices=[0,length/2,if(length==0){0}else{length-1},length,cap,18446744073709551615];
        let store::Snapshot before=store::snapshot(ref s,ref roots);var usize phase=0;
        let owners::Token token=owners::Token{.slot=s.rows[n].slot,.generation=s.rows[n].generation};
        while(phase<2){
            if(phase==1){assert(store::begin_read(ref mut s,ref roots,ref scratch,serial,n,ref mut fuel).is_ok);}
            i=0;while(i<indices.len){read_boundary(ref s,ref roots,ref scratch,serial,n,indices[i],ref input[..length]);i+=1;}
            assert(s.table.slots[token.slot].reading==(phase==1));
            if(phase==1){fuel=0;assert(ok(store::end_read(ref mut s,ref roots,ref scratch,serial,n,token))==token.slot && fuel==0);}
            phase+=1;
        }
        let store::Snapshot after=store::snapshot(ref s,ref roots);
        assert(before.count==after.count && before.used==after.used && before.peak==after.peak &&
            before.next==after.next && before.closed==after.closed);
        assert(bytes::equal(bytes::view(vec::at<bytes::Buffer>(ref roots,n)),ref input[..length]));n+=1;
    }
    fuel=0;assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0 && fuel==0 && s.ledger.used==0);
}

@test fn void authenticated_copies_match_raw_owner_ranges_leases_and_full_store_repetition(){
    var vec::Vec<bytes::Buffer> roots=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var usize fuel=1000000;var store::State s=opened(ref mut roots,ref mut scratch,ref mut fuel);
    var u8[65] input=[0;65];var usize i=0;var u8 value=0;
    while(i<input.len){input[i]=value;value+=1;i+=1;}
    let usize[6] sizes=[0,1,63,64,65,4096];var u8[4096] large=[71;4096];var usize n=0;
    while(n<sizes.len){let usize length=sizes[n];
        let usize serial=ok(store::insert(ref mut s,ref mut roots,ref mut scratch,n,ref large[..length],limits(),ref mut fuel));
        let usize cap=bytes::capacity(vec::at<bytes::Buffer>(ref roots,n));
        let usize[6] starts=[0,length/2,if(length==0){0}else{length-1},length,cap,18446744073709551615];
        let usize[5] outputs=[0,1,63,64,65];let store::Snapshot before=store::snapshot(ref s,ref roots);
        let owners::Owner owner=s.table.slots[s.rows[n].slot];var usize phase=0;
        let owners::Token token=owners::Token{.slot=s.rows[n].slot,.generation=s.rows[n].generation};
        while(phase<2){
            if(phase==1){assert(store::begin_read(ref mut s,ref roots,ref scratch,serial,n,ref mut fuel).is_ok);}
            i=0;while(i<starts.len){var usize j=0;while(j<outputs.len){
                copy_boundary(ref s,ref roots,ref scratch,serial,n,starts[i],outputs[j]);j+=1;}i+=1;}
            assert(s.table.slots[token.slot].reading==(phase==1));
            if(phase==1){fuel=0;assert(ok(store::end_read(ref mut s,ref roots,ref scratch,serial,n,token))==token.slot && fuel==0);}
            fuel=1000000;phase+=1;
        }
        let store::Snapshot after=store::snapshot(ref s,ref roots);let owners::Owner current=s.table.slots[token.slot];
        assert(before.count==after.count && before.used==after.used && before.peak==after.peak &&
            before.next==after.next && before.closed==after.closed && vec::len<bytes::Buffer>(ref scratch)==0);
        assert(owner.generation==current.generation && owner.live==current.live && owner.length==current.length &&
            owner.capacity==current.capacity && owner.reading==current.reading);
        assert(bytes::equal(bytes::view(vec::at<bytes::Buffer>(ref roots,n)),ref large[..length]));n+=1;
    }
    while(n<16){let usize serial=ok(store::insert(ref mut s,ref mut roots,ref mut scratch,n,ref input,limits(),ref mut fuel));n+=1;}
    let store::Row row=s.rows[15];let owners::Token token=switch(store::begin_read(ref mut s,ref roots,ref scratch,row.serial,15,ref mut fuel)){
        case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    fuel=4096*(256+65);i=0;var u8[65] output=[253;65];
    while(i<4096){assert(ok(store::copy_out(ref s,ref roots,ref scratch,row.serial,15,0,ref mut output,ref mut fuel))==65);
        assert(bytes::equal(ref output,ref input));i+=1;}
    assert(fuel==0);assert(ok(store::end_read(ref mut s,ref roots,ref scratch,row.serial,15,token))==token.slot && fuel==0);
    assert(ok(store::drain(ref mut s,ref mut roots,ref mut scratch))==0 && fuel==0 && s.ledger.used==0);
}
