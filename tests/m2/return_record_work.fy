module tests::m2::return_record_work;
import return_record_work as work;
import struct_layout as layouts;
import struct_nested_storage as storage;
import metadata_budget as budget;
import errors as errors;

fn layouts::Catalog catalog(){var layouts::Catalog c=layouts::empty();c.count=3;
    c.fields[0]=3;c.kinds[0]=1;c.types[0]=2;c.types[1]=2;c.types[2]=10;
    c.fields[1]=1;c.types[16]=1;c.fields[2]=2;c.types[32]=2;c.types[33]=9;return c;}
fn Result<bool,errors::Error> drive(ref mut work::State w,ref layouts::Catalog c){
    var budget::State b=budget::empty();var usize n=0;while(n<512){
        let usize reset=budget::reset(ref mut b,0)?;let usize total=b.total;
        let bool charged=budget::admit(ref mut b,1,0)?;assert(charged);
        let usize phase=w.phase;let usize depth=w.depth;let usize size=w.size;let usize bytes=w.scalar_bytes;
        let bool deferred=work::advance(w,c,ref mut b)?;
        assert(!deferred && w.phase==phase && w.depth==depth && w.size==size && w.scalar_bytes==bytes && b.total==total+1 && b.last==1);
        let usize again=budget::reset(ref mut b,0)?;
        let bool done=work::advance(w,c,ref mut b)?;assert(b.last==4096 && b.total==total+4097);
        if(done){assert(w.done && !w.active);return .ok(true);}n+=1;
    }assert(false);return .ok(false);
}
@test fn void selected_nested_measure_and_mask_match_independent_storage(){
    let layouts::Catalog c=catalog();var work::State w=work::empty();assert(work::begin(ref mut w,0).is_ok);
    assert(drive(ref mut w,ref c).is_ok);
    let storage::Staging expected=switch(storage::staging(ref c,0)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(w.size==expected.size && w.alignment==expected.alignment && w.scalar_bytes==expected.scalar_bytes && w.bools==expected.bools);
    assert(work::measured(ref w)==128+expected.size+expected.scalar_bytes+expected.bools);
    var u8[128] mask=[0;128];assert(storage::byte_kinds(ref c,0,ref mut mask[..w.size]).is_ok);
    var usize i=0;while(i<128){assert(w.mask[i]==mask[i]);i+=1;}
}
@test fn void unused_catalog_slots_and_cycles_are_still_authenticated(){
    var layouts::Catalog c=catalog();c.types[511]=1;var work::State w=work::empty();assert(work::begin(ref mut w,0).is_ok);
    assert(!drive(ref mut w,ref c).is_ok && !w.active);
    c=catalog();c.kinds[16]=1;c.types[16]=1;w=work::empty();assert(work::begin(ref mut w,0).is_ok);
    assert(!drive(ref mut w,ref c).is_ok && !w.active);
}
@test fn void shared_leaf_expansion_reaches_exact_128_byte_limit(){
    var layouts::Catalog c=layouts::empty();c.count=2;c.fields[0]=16;c.fields[1]=8;var usize i=0;
    while(i<16){c.kinds[i]=1;c.types[i]=1;i+=1;}i=0;while(i<8){c.types[16+i]=2;i+=1;}
    var work::State w=work::empty();assert(work::begin(ref mut w,0).is_ok && drive(ref mut w,ref c).is_ok);
    assert(w.size==128 && w.scalar_bytes==128 && w.bools==128 && work::measured(ref w)==512);
    i=0;while(i<128){assert(w.mask[i]==2);i+=1;}
}
@test fn void selected_extent_and_missing_nominal_fail_without_payload(){
    var layouts::Catalog c=layouts::empty();c.count=2;c.fields[0]=16;c.fields[1]=2;var usize i=0;
    while(i<16){c.kinds[i]=1;c.types[i]=1;i+=1;}c.types[16]=9;c.types[17]=9;
    var work::State w=work::empty();assert(work::begin(ref mut w,0).is_ok);
    let u8 kind=switch(drive(ref mut w,ref c)){case .ok(_):{0}case .err(e):{e.kind}};assert(kind==13);
    w=work::empty();assert(work::begin(ref mut w,2).is_ok);
    let u8 missing=switch(drive(ref mut w,ref c)){case .ok(_):{0}case .err(e):{e.kind}};assert(missing==14);
}
