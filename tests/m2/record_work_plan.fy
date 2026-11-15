module tests::m2::record_work_plan;
import struct_layout as layouts;
import struct_nested_storage as storage;
import array_owners as owners;
import array_fill_cursor as cursor;
import struct_work as work;

fn layouts::Catalog catalog(){
    var layouts::Catalog c=layouts::empty();c.count=3;
    c.fields[0]=3;c.types[0]=10;c.kinds[1]=1;c.types[1]=1;c.kinds[2]=1;c.types[2]=1;
    c.fields[1]=2;c.types[16]=9;c.types[17]=2;c.fields[2]=1;c.types[32]=10;return c;
}
fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){
    case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};}
fn u8 code(owners::Error e){return switch(e){
    case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}
    case .Metadata:{6}case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}};}
fn u8 storage_code(storage::Error e){return switch(e){
    case .Layout:{1}case .Bounds:{2}case .Fields:{3}case .State:{4}case .Alignment:{5}
    case .Quota:{6}case .Overflow:{7}case .Value:{8}case .Type:{9}};}
fn u8 checked(ref layouts::Catalog c,ref owners::Table t,ref cursor::State w){
    return switch(owners::validate_record_work(c,t,w,256)){case .ok(_):{0}case .err(e):{code(e)}};
}
fn void same_staging(ref layouts::Catalog c,usize nominal){
    let layouts::Plan plan=switch(layouts::plan(c,18446744073709551615)){
        case .ok(p):{p}case .err(_):{assert(false);return;}};
    let Result<storage::Staging,storage::Error> a=storage::staging(c,nominal);
    let Result<storage::Staging,storage::Error> b=storage::staging_prepared(c,ref plan,nominal);
    assert(switch(a){case .ok(x):{switch(b){case .ok(y):{x.size==y.size && x.alignment==y.alignment &&
        x.leaves==y.leaves && x.scalar_bytes==y.scalar_bytes && x.bools==y.bools}case .err(_):{false}}}
        case .err(x):{switch(b){case .ok(_):{false}case .err(y):{storage_code(x)==storage_code(y)}}}});
}
@test fn void staging_shares_exact_counts_at_scalar_depth_and_extent_limits(){
    let layouts::Catalog mixed=catalog();var usize i=0;while(i<4){same_staging(ref mixed,i);i+=1;}
    let storage::Staging expected=switch(storage::staging(ref mixed,0)){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(expected.size==40 && expected.alignment==8 && expected.leaves==5 && expected.scalar_bytes==19 && expected.bools==2);
    var layouts::Catalog c=layouts::empty();c.count=1;c.fields[0]=6;
    let u8[6] tags=[1,2,9,10,11,12];i=0;while(i<6){c.types[i]=tags[i];i+=1;}same_staging(ref c,0);
    var usize depth=1;while(depth<=16){c=layouts::empty();c.count=depth;i=0;var u8 next=1;while(i<depth){
        c.fields[i]=1;if(i+1<depth){c.kinds[i*16]=1;c.types[i*16]=next;}else{c.types[i*16]=2;}i+=1;next+=1;}
        same_staging(ref c,0);depth+=1;}
    c=layouts::empty();c.count=2;c.fields[0]=16;c.fields[1]=8;i=0;
    while(i<16){c.kinds[i]=1;c.types[i]=1;i+=1;}i=0;while(i<8){c.types[16+i]=2;i+=1;}
    same_staging(ref c,0);c.types[16]=9;same_staging(ref c,0);
    c= mixed;c.types[511]=2;assert(!storage::staging(ref c,0).is_ok);
    c=mixed;c.kinds[32]=1;c.types[32]=2;assert(!storage::staging(ref c,0).is_ok);
}
@test fn void every_validation_reauthenticates_catalog_and_saved_state_in_original_order(){
    let layouts::Catalog c=catalog();var owners::Table t=owners::empty(256);var u8[256] data=[85;256];
    let i64[5] fields=[17,42,1,-7,0];
    let owners::Token p=token(owners::create_record(ref c,0,ref fields,ref mut data,ref mut t));
    let owners::Token q=token(owners::create_record(ref c,0,ref fields,ref mut data,ref mut t));
    let i64[1] none=[0;1];let cursor::State w=switch(work::begin(ref c,ref t,46,0,p,q,0,0,ref none[..0],ref data)){
        case .ok(v):{v}case .err(_):{assert(false);return;}};assert(checked(ref c,ref t,ref w)==0);
    var usize i=0;while(i<512){var layouts::Catalog bad=c;bad.kinds[i]=2;assert(checked(ref bad,ref t,ref w)==6);
        bad=c;bad.types[i]=255;assert(checked(ref bad,ref t,ref w)==6);i+=1;}
    i=0;while(i<32){var layouts::Catalog bad=c;bad.fields[i]=17;assert(checked(ref bad,ref t,ref w)==6);i+=1;}
    i=0;while(i<16){var owners::Table bad=t;let bool occupied=bad.slots[i].occupied;bad.slots[i].occupied=!occupied;
        assert(checked(ref c,ref bad,ref w)==3);i+=1;}
    i=0;while(i<25){var cursor::State bad=w;
        if(i==0){bad.active=false;}else if(i==1){bad.element=1;}else if(i==2){bad.list_gathered=1;}
        else if(i==3){bad.list_encoded=1;}else if(i==4){bad.op=0;}else if(i==5){bad.slot=16;}
        else if(i==6){bad.generation=0;}else if(i==7){bad.depth+=1;}else if(i==8){bad.mark+=1;}
        else if(i==9){bad.base+=1;}else if(i==10){bad.end+=1;}else if(i==11){bad.record+=1;}
        else if(i==12){bad.length+=1;}else if(i==13){bad.stride+=1;}else if(i==14){bad.source_slot=16;}
        else if(i==15){bad.source_generation=0;}else if(i==16){bad.source_base+=1;}else if(i==17){bad.source_end+=1;}
        else if(i==18){bad.source_record+=1;}else if(i==19){bad.source_ordinal=1;}else if(i==20){bad.nominal=32;}
        else if(i==21){bad.ordinal=1;}else if(i==22){bad.written=129;}else if(i==23){bad.total=0;}else{bad.last=bad.total+1;}
        assert(checked(ref c,ref t,ref bad)!=0);i+=1;}
    var layouts::Catalog bad=c;bad.types[511]=2;var cursor::State saved=w;saved.slot=16;
    assert(checked(ref bad,ref t,ref saved)==6 && checked(ref c,ref t,ref saved)==1);
    saved.active=false;assert(checked(ref bad,ref t,ref saved)==3);
    saved=w;saved.source_generation+=1;assert(checked(ref c,ref t,ref saved)==1);
    var owners::Table changed=t;changed.slots[q.slot].generation+=1;assert(checked(ref c,ref changed,ref w)==1);
    changed=t;changed.arena.limit=257;assert(checked(ref c,ref changed,ref w)==3);
    let cursor::State resumed=w;assert(checked(ref c,ref t,ref resumed)==0);
}
@test fn void maximum_bool_copy_revalidates_every_byte_without_early_publication(){
    var layouts::Catalog c=layouts::empty();c.count=2;c.fields[0]=16;c.fields[1]=8;var usize i=0;
    while(i<16){c.kinds[i]=1;c.types[i]=1;i+=1;}i=0;while(i<8){c.types[16+i]=2;i+=1;}
    var owners::Table t=owners::empty(256);var u8[256] data=[85;256];let i64[128] values=[1;128];
    let owners::Token p=token(owners::create_record(ref c,0,ref values,ref mut data,ref mut t));
    let i64[1] none=[0;1];var cursor::State w=switch(work::begin(ref c,ref t,42,0,p,p,0,0,ref none[..0],ref data)){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(w.total==384 && t.depth==1 && t.arena.used==128);
    i=128;while(i<256){assert(data[i]==85);i+=1;}
    i=0;while(i<128){w.last=0;assert(work::advance(ref mut w,ref c,ref mut t,ref mut data,1).is_ok);
        assert(w.written==i+1 && w.total==385+i && w.last==1);
        if(i<127){assert(w.active && t.depth==1 && t.arena.used==128);}i+=1;}
    assert(!w.active && t.depth==2 && t.arena.used==256 && t.slots[p.slot].generation==p.generation);
    i=0;while(i<256){assert(data[i]==1);i+=1;}
}
@test fn void all_six_recipes_keep_one_byte_chunks_admission_and_final_publication(){
    let layouts::Catalog c=catalog();let u8[6] ops=[41,42,46,47,48,49];var usize recipe=0;
    while(recipe<6){var owners::Table t=owners::empty(256);var u8[256] data=[85;256];
        let i64[5] values=[17,42,1,-7,0];let i64[2] child=[99,1];let i64[1] none=[0;1];
        let owners::Token p=token(owners::create_record(ref c,0,ref values,ref mut data,ref mut t));
        let owners::Token q=token(owners::create_record(ref c,0,ref values,ref mut data,ref mut t));
        let u8 op=ops[recipe];let bool nested=op==47 || op==49;
        let ref i64[] fields=if(op==41 || op==48){ref values}else if(op==49){ref child}else{ref none[..0]};
        let u8[256] before=data;
        var cursor::State w=switch(work::begin(ref c,ref t,op,if(nested){1}else{0},p,q,
            if(nested){1}else{0},if(op==47){3}else{0},fields,ref data)){
            case .ok(v):{v}case .err(_):{assert(false);return;}};
        let owners::RecordWork window=switch(owners::validate_record_work(ref c,ref t,ref w,256)){
            case .ok(v):{v}case .err(_):{assert(false);return;}};
        let usize used=t.arena.used;let usize admission=w.total;
        var usize i=0;while(i<256){assert(data[i]==before[i]);i+=1;}
        while(w.active){w.last=0;let usize prior=w.written;
            assert(work::advance(ref mut w,ref c,ref mut t,ref mut data,1).is_ok);
            assert(w.written==prior+1 && w.last==1 && w.total==admission+w.written);
            if(w.active){assert(t.depth==2 && t.arena.used==used);}
        }
        assert(w.written==window.bytes && t.depth==if(op==41 || op==42){3}else{2});
        assert(t.slots[p.slot].generation==p.generation && t.slots[q.slot].generation==q.generation);
        i=0;while(i<window.size){assert(data[window.target+i]==w.record_encoded[i]);i+=1;}
        if(op!=41 && op!=42){assert(t.arena.used==used);}recipe+=1;
    }
}
