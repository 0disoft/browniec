module tests::m2::aggregate_places;
import aggregate_places as places;
import array_owners as owners;
import array_layout as arrays;
import struct_layout as records;
import std::bytes as buffers;

fn owners::Token token(Result<owners::Token,owners::Error> result){return switch(result){
    case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}
};}
fn places::Place selected(Result<places::Place,owners::Error> result){return switch(result){
    case .ok(p):{p}case .err(_):{assert(false);places::Place{.root=owners::Token{.slot=0,.generation=0},
        .element=0,.length=0,.record=0,.nominal=0,.ordinal=0,.alignment=0,.mark=0,.base=0,.end=0,.offset=0,.size=0}}
};}
fn i64 value(Result<i64,owners::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize size(Result<usize,owners::Error> result){return switch(result){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn owners::Token array(u8 element,usize length,i64 fill,ref mut u8[] bytes,ref mut owners::Table table){
    let arrays::Array shape=switch(arrays::scalar(element,length)){
        case .ok(v):{v}case .err(_):{assert(false);arrays::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}
    };return token(owners::create(ref shape,fill,bytes,table));
}
fn records::Catalog pair(){var records::Catalog c=records::empty();c.count=2;
    c.fields[0]=2;c.kinds[0]=1;c.kinds[1]=1;c.types[0]=1;c.types[1]=1;
    c.fields[1]=2;c.types[16]=1;c.types[17]=2;return c;
}
fn void unchanged(ref u8[] bytes,ref u8[] before){assert(bytes.len==before.len);var usize i=0;
    while(i<bytes.len){assert(bytes[i]==before[i]);i+=1;}
}
fn void array_domain(u8 tag){
    var u8[64] bytes=[85;64];var owners::Table table=owners::empty(64);
    var owners::Token descriptor=array(tag,2,0,ref mut bytes,ref mut table);let owners::Token original=descriptor;
    let places::Place p=selected(places::select_array(ref table,descriptor,bytes.len));
    let i64 expected=if(tag==2){1}else{42};
    let owners::Token source=array(tag,2,expected,ref mut bytes,ref mut table);
    descriptor=array(tag,2,0,ref mut bytes,ref mut table);
    assert(owners::fill(ref table,original,0,ref mut bytes).is_ok);
    assert(size(places::store_array(ref table,ref p,source,ref mut bytes))==p.size);
    assert(value(owners::read(ref table,original,1,ref bytes))==expected);
    assert(value(owners::read(ref table,descriptor,1,ref bytes))==0);
    assert(owners::write(ref table,source,1,0,ref mut bytes).is_ok);
    assert(value(owners::read(ref table,original,1,ref bytes))==expected);
    var u8[16] scratch=[85;16];let i64[2] replacement=[expected,expected];
    assert(size(places::replace_array(ref table,ref p,ref replacement,ref mut scratch,ref mut bytes))==p.size);
    assert(places::store_array(ref table,ref p,original,ref mut bytes).is_ok);
    assert(places::fill_array(ref table,ref p,expected,ref mut bytes).is_ok);
    assert(table.depth==3 && table.arena.used==p.size*3 && table.slots[original.slot].generation==original.generation);
}
@test fn void array_original_owner_survives_rhs_descriptor_changes_for_all_six_domains(){
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<6){array_domain(tags[i]);i+=1;}
}

@test fn void array_loans_and_released_reused_or_cleared_generations_revalidate_before_writing(){
    var u8[32] bytes=[85;32];var owners::Table table=owners::empty(32);
    let owners::Token root=array(1,2,20,ref mut bytes,ref mut table);
    let places::Place p=selected(places::select_array(ref table,root,bytes.len));
    let owners::Token source=array(1,2,42,ref mut bytes,ref mut table);
    let owners::ReadLease read=switch(owners::begin_read(ref mut table,root,bytes.len)){
        case .ok(v):{v}case .err(_):{assert(false);owners::ReadLease{.root=root,.generation=0}}
    };let u8[32] before=bytes;
    assert(!places::select_array(ref table,root,bytes.len).is_ok);
    assert(!places::store_array(ref table,ref p,source,ref mut bytes).is_ok);unchanged(ref bytes,ref before);
    assert(owners::end_read(ref mut table,read,bytes.len).is_ok);
    let owners::View view=switch(owners::view(ref table,root,0,2,bytes.len)){
        case .ok(v):{v}case .err(_):{assert(false);owners::View{.root=root,.element=1,.length=2,.start=0,.end=2}}
    };
    let owners::WriteLease write=switch(owners::begin_write(ref mut table,root,0,2,bytes.len)){
        case .ok(v):{v}case .err(_):{assert(false);owners::WriteLease{.view=view,.generation=0}}
    };
    assert(!places::select_array(ref table,root,bytes.len).is_ok);
    assert(!places::store_array(ref table,ref p,source,ref mut bytes).is_ok);unchanged(ref bytes,ref before);
    assert(owners::end_write(ref mut table,ref write,bytes.len).is_ok);
    assert(places::store_array(ref table,ref p,source,ref mut bytes).is_ok);
    assert(owners::release(ref mut table,root,bytes.len).is_ok);
    assert(!places::store_array(ref table,ref p,source,ref mut bytes).is_ok);
    assert(owners::release(ref mut table,source,bytes.len).is_ok);
    let owners::Token replacement=array(1,2,99,ref mut bytes,ref mut table);
    assert(replacement.slot==root.slot && replacement.generation!=root.generation);
    let u8[32] reused=bytes;assert(!places::fill_array(ref table,ref p,42,ref mut bytes).is_ok);unchanged(ref bytes,ref reused);
    let places::Place fresh=selected(places::select_array(ref table,replacement,bytes.len));
    assert(owners::clear(ref mut table,bytes.len).is_ok);
    assert(!places::fill_array(ref table,ref fresh,42,ref mut bytes).is_ok);
}

@test fn void record_subtrees_keep_the_original_target_and_canonical_snapshot_in_both_directions(){
    let records::Catalog c=pair();var u8[64] bytes=[85;64];var owners::Table table=owners::empty(64);
    let owners::Token prefix=array(10,1,7,ref mut bytes,ref mut table);
    let i64[4] initial=[20,0,42,1];var owners::Token descriptor=token(owners::create_record(ref c,0,ref initial,ref mut bytes,ref mut table));
    let owners::Token original=descriptor;
    let places::Place left=selected(places::select_record(ref c,ref table,descriptor,1,0,bytes.len));
    descriptor=token(owners::create_record(ref c,0,ref initial,ref mut bytes,ref mut table));
    let i64[4] changed=[9,0,42,1];assert(owners::replace_record(ref c,original,0,ref changed,ref mut bytes,ref table).is_ok);
    assert(size(places::store_record(ref c,ref table,ref left,original,2,ref mut bytes))==8);
    let usize[2] a=[0,0];let usize[2] b=[1,0];
    assert(value(owners::read_record(ref c,ref table,original,ref a,ref bytes))==42);
    assert(value(owners::read_record(ref c,ref table,descriptor,ref a,ref bytes))==20);
    let places::Place right=selected(places::select_record(ref c,ref table,original,1,2,bytes.len));
    let i64[2] fields=[22,0];assert(places::replace_record(ref c,ref table,ref left,ref fields,ref mut bytes).is_ok);
    assert(places::store_record(ref c,ref table,ref right,original,0,ref mut bytes).is_ok);
    assert(value(owners::read_record(ref c,ref table,original,ref b,ref bytes))==22);
    bytes[left.base+5]=85;bytes[left.base+6]=85;bytes[left.base+7]=85;
    assert(places::store_record(ref c,ref table,ref left,original,0,ref mut bytes).is_ok);
    assert(bytes[left.base+5]==0 && bytes[left.base+6]==0 && bytes[left.base+7]==0);
    assert(value(owners::read(ref table,prefix,0,ref bytes))==7 && left.mark==1 && left.base==4);
    assert(table.depth==3 && table.arena.used==36);
}

fn void array_atomic(){
    var u8[16] bytes=[85;16];var owners::Table table=owners::empty(16);
    let owners::Token root=array(2,2,0,ref mut bytes,ref mut table);
    let places::Place p=selected(places::select_array(ref table,root,bytes.len));
    let owners::Token source=array(2,2,1,ref mut bytes,ref mut table);bytes[3]=7;
    let u8[16] before=bytes;
    assert(!places::store_array(ref table,ref p,source,ref mut bytes).is_ok);unchanged(ref bytes,ref before);
    var u8[2] scratch=[85;2];let i64[2] invalid=[1,2];let i64[2] valid=[1,1];
    assert(!places::replace_array(ref table,ref p,ref invalid,ref mut scratch,ref mut bytes).is_ok);unchanged(ref bytes,ref before);
    assert(!places::replace_array(ref table,ref p,ref valid,ref mut scratch[..1],ref mut bytes).is_ok);unchanged(ref bytes,ref before);
    assert(!places::fill_array(ref table,ref p,2,ref mut bytes).is_ok);unchanged(ref bytes,ref before);
    bytes[1]=7;let places::Place corrupt=selected(places::select_array(ref table,root,bytes.len));
    let u8[16] bad_self=bytes;assert(!places::store_array(ref table,ref corrupt,root,ref mut bytes).is_ok);unchanged(ref bytes,ref bad_self);
    assert(places::replace_array(ref table,ref corrupt,ref valid,ref mut scratch,ref mut bytes).is_ok);
    assert(bytes[0]==1 && bytes[1]==1 && bytes[3]==7 && table.depth==2 && table.arena.used==4);
}
fn void record_atomic(){
    let records::Catalog c=pair();var u8[64] bytes=[85;64];var owners::Table table=owners::empty(64);
    let i64[4] fields=[20,0,42,1];let owners::Token root=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    let owners::Token source=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    let places::Place p=selected(places::select_record(ref c,ref table,root,1,0,bytes.len));
    bytes[28]=7;let u8[64] before=bytes;
    assert(!places::store_record(ref c,ref table,ref p,source,2,ref mut bytes).is_ok);unchanged(ref bytes,ref before);
    let i64[2] invalid=[99,2];assert(!places::replace_record(ref c,ref table,ref p,ref invalid,ref mut bytes).is_ok);unchanged(ref bytes,ref before);
    assert(!places::store_record(ref c,ref table,ref p,source,1,ref mut bytes).is_ok);unchanged(ref bytes,ref before);
    bytes[4]=7;let places::Place corrupt=selected(places::select_record(ref c,ref table,root,1,0,bytes.len));
    let i64[2] valid=[42,1];assert(places::replace_record(ref c,ref table,ref corrupt,ref valid,ref mut bytes).is_ok);
    assert(bytes[4]==1 && bytes[28]==7 && table.depth==2 && table.arena.used==32);
}
@test fn void late_invalid_sources_and_scalar_staging_never_publish_a_prefix(){array_atomic();record_atomic();}

@test fn void malformed_snapshot_fields_domains_and_owner_ledgers_cannot_redirect_writes(){
    let records::Catalog c=pair();var u8[64] bytes=[85;64];var owners::Table table=owners::empty(64);
    let owners::Token a=array(1,2,20,ref mut bytes,ref mut table);
    let places::Place array_place=selected(places::select_array(ref table,a,bytes.len));
    let i64[4] fields=[20,0,42,1];let owners::Token root=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    let places::Place p=selected(places::select_record(ref c,ref table,root,1,0,bytes.len));let u8[64] before=bytes;
    var places::Place bad=p;bad.offset+=1;assert(!places::store_record(ref c,ref table,ref bad,root,2,ref mut bytes).is_ok);
    bad=p;bad.size+=1;assert(!places::store_record(ref c,ref table,ref bad,root,2,ref mut bytes).is_ok);
    bad=p;bad.ordinal=2;assert(!places::store_record(ref c,ref table,ref bad,root,0,ref mut bytes).is_ok);
    bad=p;bad.base+=4;assert(!places::store_record(ref c,ref table,ref bad,root,2,ref mut bytes).is_ok);
    bad=array_place;bad.nominal=1;assert(!places::fill_array(ref table,ref bad,42,ref mut bytes).is_ok);
    assert(!places::store_array(ref table,ref p,a,ref mut bytes).is_ok);
    assert(!places::store_record(ref c,ref table,ref array_place,root,0,ref mut bytes).is_ok);
    assert(!places::select_record(ref c,ref table,a,1,0,bytes.len).is_ok);
    assert(!places::select_array(ref table,root,bytes.len).is_ok);
    table.slots[root.slot].mark+=1;assert(!places::store_record(ref c,ref table,ref p,root,2,ref mut bytes).is_ok);
    table.slots[root.slot].mark-=1;unchanged(ref bytes,ref before);
}

fn void maximum_array(){
    var buffers::Buffer backing=switch(buffers::with_capacity(32783)){case .ok(v):{v}case .err(_):{assert(false);buffers::empty()}};
    assert(buffers::resize_zeroed(ref mut backing,32783).is_ok);let ref mut u8[] bytes=buffers::view_mut(ref mut backing);
    var owners::Table table=owners::empty(32783);let owners::Token root=array(9,4096,20,bytes,ref mut table);
    let places::Place p=selected(places::select_array(ref table,root,bytes.len));var usize i=0;
    while(i<15){let owners::Token other=array(10,1,7,bytes,ref mut table);i+=1;}
    assert(size(places::fill_array(ref table,ref p,-9223372036854775808,bytes))==32768);
    assert(size(places::store_array(ref table,ref p,root,bytes))==32768);
    assert(value(owners::read(ref table,root,4095,bytes)) == -9223372036854775808);
    assert(bytes[32782]==7 && table.depth==16 && table.arena.used==32783);
}
fn void maximum_record(){
    var records::Catalog c=records::empty();c.count=2;c.fields[0]=8;c.fields[1]=16;
    var usize i=0;while(i<16){if(i<8){c.kinds[i]=1;c.types[i]=1;}c.types[16+i]=10;i+=1;}
    var u8[2048] bytes=[85;2048];var owners::Table table=owners::empty(2048);let i64[128] fields=[20;128];
    let owners::Token root=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    let places::Place whole=selected(places::select_record(ref c,ref table,root,0,0,bytes.len));i=1;
    while(i<16){let owners::Token other=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));i+=1;}
    let places::Place last=selected(places::select_record(ref c,ref table,root,1,112,bytes.len));let i64[16] replacement=[42;16];
    assert(last.offset==112 && last.size==16 && whole.size==128);
    assert(places::replace_record(ref c,ref table,ref last,ref replacement,ref mut bytes).is_ok);
    assert(bytes[111]==20 && bytes[112]==42 && bytes[127]==42 && bytes[128]==20);
    assert(size(places::store_record(ref c,ref table,ref whole,root,0,ref mut bytes))==128);
    assert(table.depth==16 && table.arena.used==2048 && table.slots[root.slot].generation==root.generation);
}
fn void maximum_depth(){
    var records::Catalog c=records::empty();c.count=16;var usize i=0;var u8 next=1;
    while(i<16){c.fields[i]=1;if(i<15){c.kinds[i*16]=1;c.types[i*16]=next;next+=1;}else{c.types[i*16]=11;}i+=1;}
    var u8[4] bytes=[85;4];var owners::Table table=owners::empty(4);let i64[1] fields=[42];
    let owners::Token root=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    let places::Place p=selected(places::select_record(ref c,ref table,root,15,0,bytes.len));
    assert(size(places::store_record(ref c,ref table,ref p,root,0,ref mut bytes))==4 && bytes[0]==42);
}
@test fn void maximum_payload_leaves_depth_and_full_owner_backing_capacity_need_no_new_extent(){maximum_array();maximum_record();maximum_depth();}

@test fn void record_generation_expiry_invalid_nominal_and_bad_catalog_reject_before_publication(){
    var records::Catalog c=pair();var u8[32] bytes=[85;32];var owners::Table table=owners::empty(32);
    let i64[4] fields=[20,0,42,1];let owners::Token root=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    let places::Place p=selected(places::select_record(ref c,ref table,root,1,0,bytes.len));
    assert(!places::select_record(ref c,ref table,root,2,0,bytes.len).is_ok);
    assert(!places::select_record(ref c,ref table,root,1,128,bytes.len).is_ok);
    c.kinds[16]=1;c.types[16]=0;let u8[32] before=bytes;
    assert(!places::store_record(ref c,ref table,ref p,root,0,ref mut bytes).is_ok);unchanged(ref bytes,ref before);
    c.kinds[16]=0;c.types[16]=1;assert(owners::release(ref mut table,root,bytes.len).is_ok);
    assert(!places::replace_record(ref c,ref table,ref p,ref fields[..2],ref mut bytes).is_ok);
    let owners::Token reused=token(owners::create_record(ref c,0,ref fields,ref mut bytes,ref mut table));
    assert(reused.slot==root.slot && reused.generation!=root.generation);
    let u8[32] after=bytes;assert(!places::store_record(ref c,ref table,ref p,reused,0,ref mut bytes).is_ok);unchanged(ref bytes,ref after);
    let places::Place fresh=selected(places::select_record(ref c,ref table,reused,0,0,bytes.len));
    assert(owners::clear(ref mut table,bytes.len).is_ok);
    assert(!places::store_record(ref c,ref table,ref fresh,reused,0,ref mut bytes).is_ok);
}
