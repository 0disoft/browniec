module tests::m2::struct_subassign_owners;
import array_owners as owners;
import struct_layout as layouts;
import struct_range as ranges;
fn layouts::Catalog catalog() {
 var layouts::Catalog c=layouts::empty();c.count=3;
 c.fields[0]=3;c.types[0]=10;c.kinds[1]=1;c.types[1]=1;c.kinds[2]=1;c.types[2]=1;
 c.fields[1]=2;c.types[16]=9;c.types[17]=2;
 c.fields[2]=2;c.types[32]=9;c.types[33]=2;return c;
}
fn owners::Token token(Result<owners::Token,owners::Error> r) {
 return switch(r){case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}};
}
fn i64 read(ref layouts::Catalog c,ref owners::Table t,owners::Token p,ref usize[] path,ref u8[] b) {
 return switch(owners::read_record(c,t,p,path,b)){case .ok(n):{n}case .err(_):{assert(false);0}};
}
@test
fn void subrecord_ranges_copy_siblings_and_self_without_owners_or_neighbors() {
 let layouts::Catalog c=catalog();var u8[128] b=[85;128];var owners::Table t=owners::empty(128);
 let i64[5] a=[17,42,1,0,0];let i64[5] z=[9,0,0,22,1];
 let owners::Token p=token(owners::create_record(ref c,0,ref a,ref mut b,ref mut t));
 let owners::Token q=token(owners::create_record(ref c,0,ref z,ref mut b,ref mut t));
 assert(owners::assign_subrecord(ref c,p,q,1,1,3,ref mut b,ref t).is_ok);
 let usize[2] left=[1,0];let usize[2] right=[2,0];let usize[1] head=[0];
 assert(read(ref c,ref t,p,ref left,ref b)==22 && read(ref c,ref t,p,ref right,ref b)==0);
 assert(read(ref c,ref t,p,ref head,ref b)==17 && read(ref c,ref t,q,ref right,ref b)==22);
 assert(owners::assign_subrecord(ref c,p,p,1,3,1,ref mut b,ref t).is_ok);
 assert(owners::assign_subrecord(ref c,p,p,1,3,3,ref mut b,ref t).is_ok);
 assert(read(ref c,ref t,p,ref right,ref b)==22 && t.depth==2 && t.arena.used==80);
 assert(t.slots[p.slot].generation==p.generation && t.slots[q.slot].generation==q.generation);
}
@test
fn void invalid_bool_nominal_range_metadata_and_stale_tokens_do_not_write() {
 var layouts::Catalog c=catalog();var u8[128] b=[0;128];var owners::Table t=owners::empty(128);
 let i64[5] a=[17,42,1,0,0];
 let owners::Token p=token(owners::create_record(ref c,0,ref a,ref mut b,ref mut t));
 let owners::Token q=token(owners::create_record(ref c,0,ref a,ref mut b,ref mut t));
 b[t.slots[q.slot].base+16]=2;let u8[128] before=b;
 assert(!owners::assign_subrecord(ref c,p,q,1,1,1,ref mut b,ref t).is_ok);
 assert(!owners::assign_subrecord(ref c,p,q,2,1,1,ref mut b,ref t).is_ok);
 assert(!owners::assign_subrecord(ref c,p,q,1,2,1,ref mut b,ref t).is_ok);
 let owners::Token stale=owners::Token{.slot=q.slot,.generation=q.generation+1};
 assert(!owners::assign_subrecord(ref c,p,stale,1,1,1,ref mut b,ref t).is_ok);
 c.types[511]=2;assert(!owners::assign_subrecord(ref c,p,q,1,1,1,ref mut b,ref t).is_ok);
 var usize i=0;while(i<128){assert(b[i]==before[i]);i+=1;}
 assert(t.depth==2 && t.arena.used==80 && t.slots[p.slot].generation==p.generation);
 assert(!ranges::offset(ref c,0,1,128).is_ok);
}
@test
fn void full_owner_table_and_padding_normalization_use_no_extra_extent() {
 let layouts::Catalog c=catalog();var u8[256] b=[85;256];var owners::Table t=owners::empty(256);
 let i64[2] a=[42,1];var owners::Token[16] tokens=[owners::Token{.slot=0,.generation=0};16];
 var usize i=0;while(i<16){tokens[i]=token(owners::create_record(ref c,1,ref a,ref mut b,ref mut t));i+=1;}
 b[9]=85;assert(owners::assign_subrecord(ref c,tokens[15],tokens[0],1,0,0,ref mut b,ref t).is_ok);
 assert(t.depth==16 && t.arena.used==256 && b[9]==85 && b[249]==0);
 assert(tokens[15].generation==t.slots[tokens[15].slot].generation);
}
