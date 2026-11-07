module array_fill_work_tests;
import array_fill_work as work;
import array_fill_cursor as cursor;
import array_owners as owners;
import array_layout as layouts;
import std::bytes as bytes;

// Native fixture supplies these hooks; parent owns main/runner integration.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
struct Heap { usize blocks; usize bytes; usize attempts; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()},
    .attempts=unsafe{probe_attempts()}};}
fn void same_heap(ref Heap h){
    assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes);
}
fn void no_allocation(ref Heap h){same_heap(h);assert(unsafe{probe_attempts()}==h.attempts);}
fn owners::Token unused(){return owners::Token{.slot=16,.generation=0};}
fn Result<layouts::Array,owners::Error> shape(u8 tag,usize length){
    return switch(layouts::scalar(tag,length)){case .ok(v):{.ok(v)}case .err(_):{.err(.Metadata)}};
}
fn void same_token(owners::Token a,owners::Token b){assert(a.slot==b.slot && a.generation==b.generation);}
fn void same_owner(ref owners::Owner a,ref owners::Owner b){
    assert(a.generation==b.generation && a.occupied==b.occupied && a.live==b.live);
    assert(a.reading==b.reading && a.writing==b.writing && a.read_generation==b.read_generation);
    assert(a.mark==b.mark && a.base==b.base && a.end==b.end);
    assert(a.element==b.element && a.length==b.length && a.record==b.record && a.alignment==b.alignment);
}
fn void same_table(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){same_owner(ref a.slots[i],ref b.slots[i]);assert(a.order[i]==b.order[i]);i+=1;}
}
fn void same_cursor(ref cursor::State a,ref cursor::State b){
    assert(a.active==b.active && a.op==b.op && a.pc==b.pc && a.frame==b.frame);
    assert(a.destination==b.destination && a.offset==b.offset && a.slot==b.slot && a.generation==b.generation);
    assert(a.mark==b.mark && a.base==b.base && a.end==b.end && a.depth==b.depth);
    assert(a.element==b.element && a.length==b.length && a.stride==b.stride);
    assert(a.written==b.written && a.total==b.total && a.last==b.last);
    var usize i=0;while(i<8){assert(a.encoded[i]==b.encoded[i]);i+=1;}
}
fn Result<cursor::State,owners::Error> begin(ref owners::Table table,u8 op,ref layouts::Array layout,
    owners::Token target,i64 value,usize capacity){
    let Heap h=heap();let Result<cursor::State,owners::Error> result=work::begin(table,op,layout,target,value,capacity);
    no_allocation(ref h);return result;
}
fn Result<Option<owners::Token>,owners::Error> advance(ref mut cursor::State state,ref mut owners::Table table,
    ref mut u8[] data,usize allowance){
    let Heap h=heap();let Result<Option<owners::Token>,owners::Error> result=work::advance(state,table,data,allowance);
    no_allocation(ref h);return result;
}
fn void pending(Option<owners::Token> result){switch(result){case .none:{}case .some(_):{assert(false);}};}
fn Result<owners::Token,owners::Error> completed(Option<owners::Token> result){
    return switch(result){case .some(token):{.ok(token)}case .none:{.err(.State)}};
}
// Result helpers propagate failures without recursive fallback constructors.
fn Result<owners::Token,owners::Error> drain(ref mut cursor::State state,ref mut owners::Table table,
    ref mut u8[] data,usize quantum){
    let owners::Table before=*table;let bool creating=state.op==33;var usize calls=0;
    while(state.active){
        assert(calls<32769);state.last=0;let usize previous=state.total;
        let Option<owners::Token> result=advance(state,table,data,quantum)?;calls+=1;
        assert(state.total>previous && state.total-previous<=quantum && state.last==state.total-previous);
        if(state.active){pending(result);same_table(ref before,table);}
        else{if(!creating){same_table(ref before,table);}return completed(result);}
    }
    return .err(.State);
}
fn void rejected_begin(ref owners::Table table,u8 op,ref layouts::Array layout,
    owners::Token target,i64 value,usize capacity){
    let owners::Table before=*table;assert(!begin(table,op,layout,target,value,capacity).is_ok);same_table(ref before,table);
}
// Small rejection fixtures only: snapshot current bytes, including any prefix
// already written. Rejection promises no NEW writes, never prefix rollback.
fn void rejected_advance(ref mut cursor::State state,ref mut owners::Table table,ref mut u8[] data,usize allowance){
    assert(data.len<=128);var u8[128] before=[0;128];var usize i=0;
    while(i<data.len){before[i]=data[i];i+=1;}
    let owners::Table ledger=*table;let cursor::State saved=*state;
    assert(!advance(state,table,data,allowance).is_ok);
    same_table(ref ledger,table);same_cursor(ref saved,state);
    i=0;while(i<data.len){assert(before[i]==data[i]);i+=1;}
}

// Group 1: all six codecs, signed extrema and packed usize high-bit values.
// Both CREATE and FILL match the atomic oracle byte-for-byte and metadata-for-
// metadata. Tiny allowances split scalar encodings; 4096 exercises the cap.
fn Result<usize,owners::Error> scalar_edges_and_atomic_parity(){
    let u8[6] tags=[1,2,9,10,11,12];let usize[4] quanta=[1,3,7,4096];
    var usize tag=0;while(tag<6){
        let i64[4] values=if(tags[tag]==1){[-2147483648,2147483647,-1,0]}
            else if(tags[tag]==2){[0,1,0,1]}
            else if(tags[tag]==9){[-9223372036854775808,9223372036854775807,-1,0]}
            else if(tags[tag]==10){[0,255,128,1]}
            else if(tags[tag]==11){[0,4294967295,2147483648,1]}
            else{[-1,-9223372036854775808,9223372036854775807,0]};
        let layouts::Array layout=shape(tags[tag],7)?;var usize edge=0;while(edge<4){
            var usize q=0;while(q<4){
                var u8[128] data=[85;128];var u8[128] expected=[85;128];
                var owners::Table table=owners::empty(128);var owners::Table oracle=owners::empty(128);
                let owners::Table empty=table;
                let owners::Token wanted=owners::create(ref layout,values[edge],ref mut expected,ref mut oracle)?;
                var cursor::State state=begin(ref table,33,ref layout,unused(),values[edge],data.len)?;
                same_table(ref empty,ref table);assert(state.active && state.total==0 && state.last==0);
                let owners::Token actual=drain(ref mut state,ref mut table,ref mut data,quanta[q])?;
                same_token(actual,wanted);same_table(ref table,ref oracle);assert(bytes::equal(ref data,ref expected));
                assert(!state.active && state.total==layout.bytes);
                let owners::Table retained=table;let i64 replacement=values[(edge+1)%4];
                let usize filled=owners::fill(ref oracle,wanted,replacement,ref mut expected)?;assert(filled==layout.bytes);
                state=begin(ref table,40,ref layout,actual,replacement,data.len)?;
                let owners::Token again=drain(ref mut state,ref mut table,ref mut data,quanta[q])?;
                same_token(actual,again);same_table(ref retained,ref table);same_table(ref oracle,ref table);
                assert(state.total==layout.bytes && bytes::equal(ref data,ref expected));
                assert(owners::read(ref table,actual,0,ref data)?==replacement);
                assert(owners::read(ref table,actual,6,ref data)?==replacement);q+=1;
            }edge+=1;
        }tag+=1;
    }return .ok(0);
}

// Group 2: seven alignment bytes are real work. Several advances share one
// caller batch; only the caller resets last. Publication waits for byte 15.
fn Result<usize,owners::Error> padding_and_delayed_publication(){
    let layouts::Array byte=shape(10,1)?;let layouts::Array wide=shape(9,1)?;
    var u8[32] data=[85;32];var u8[32] expected=[85;32];
    var owners::Table table=owners::empty(32);var owners::Table oracle=owners::empty(32);
    let owners::Token prefix=owners::create(ref byte,42,ref mut data,ref mut table)?;
    let owners::Token reference=owners::create(ref byte,42,ref mut expected,ref mut oracle)?;same_token(prefix,reference);
    let owners::Token wanted=owners::create(ref wide,-1,ref mut expected,ref mut oracle)?;
    let owners::Table before=table;var cursor::State state=begin(ref table,33,ref wide,unused(),-1,data.len)?;
    assert(state.mark==1 && state.base==8 && state.end==16 && state.depth==1);
    assert(state.slot==wanted.slot && state.generation==wanted.generation);same_table(ref before,ref table);
    pending(advance(ref mut state,ref mut table,ref mut data,3)?);
    assert(state.active && state.total==3 && state.last==3);same_table(ref before,ref table);
    var usize i=1;while(i<4){assert(data[i]==0);i+=1;}
    assert(data[4]==85 && data[8]==85 && data[0]==42);
    pending(advance(ref mut state,ref mut table,ref mut data,4)?);
    assert(state.total==7 && state.last==7);same_table(ref before,ref table);
    assert(data[7]==0 && data[8]==85);
    state.last=0;pending(advance(ref mut state,ref mut table,ref mut data,7)?);
    assert(state.active && state.total==14 && state.last==7 && data[14]==255 && data[15]==85);
    same_table(ref before,ref table);
    let owners::Token actual=completed(advance(ref mut state,ref mut table,ref mut data,1)?)?;
    assert(!state.active && state.total==15 && state.last==8);same_token(actual,wanted);
    same_table(ref table,ref oracle);assert(bytes::equal(ref data,ref expected));
    assert(table.depth==2 && table.arena.used==16 && data[16]==85);
    return .ok(0);
}

// Group 3: invalid scalar/layout/token/capacity/loan and allowance admission
// must preserve the ledger, bytes, and (for rejected advance) entire cursor.
fn Result<usize,owners::Error> preflight_rejections(){
    let cursor::State idle=cursor::empty();assert(!idle.active && idle.total==0 && idle.last==0);
    let layouts::Array layout=shape(2,3)?;var u8[64] data=[85;64];var owners::Table table=owners::empty(64);
    let owners::Token target=owners::create(ref layout,0,ref mut data,ref mut table)?;let u8[64] before=data;
    rejected_begin(ref table,33,ref layout,unused(),2,64);rejected_begin(ref table,40,ref layout,target,2,64);
    let u8[3] tags=[1,10,11];let i64[3] invalid=[2147483648,256,4294967296];var usize i=0;
    while(i<3){let layouts::Array bad_value=shape(tags[i],3)?;
        rejected_begin(ref table,33,ref bad_value,unused(),invalid[i],64);i+=1;}
    let owners::Token stale=owners::Token{.slot=target.slot,.generation=target.generation+1};
    rejected_begin(ref table,40,ref layout,stale,1,64);
    let layouts::Array wrong_tag=shape(10,3)?;let layouts::Array wrong_length=shape(2,2)?;
    rejected_begin(ref table,40,ref wrong_tag,target,1,64);rejected_begin(ref table,40,ref wrong_length,target,1,64);
    var layouts::Array malformed=layout;malformed.stride=8;
    rejected_begin(ref table,33,ref malformed,unused(),1,64);rejected_begin(ref table,40,ref malformed,target,1,64);
    rejected_begin(ref table,40,ref layout,target,1,2);rejected_begin(ref table,33,ref layout,unused(),1,2);
    let layouts::Array too_big=shape(9,4096)?;rejected_begin(ref table,33,ref too_big,unused(),0,64);
    rejected_begin(ref table,0,ref layout,target,1,64);
    let owners::ReadLease reader=owners::begin_read(ref mut table,target,64)?;
    rejected_begin(ref table,40,ref layout,target,1,64);let usize read_end=owners::end_read(ref mut table,reader,64)?;
    let owners::WriteLease writer=owners::begin_write(ref mut table,target,0,3,64)?;
    rejected_begin(ref table,40,ref layout,target,1,64);let usize write_end=owners::end_write(ref mut table,ref writer,64)?;
    var cursor::State state=begin(ref table,40,ref layout,target,1,64)?;
    rejected_advance(ref mut state,ref mut table,ref mut data,0);
    rejected_advance(ref mut state,ref mut table,ref mut data,4097);
    // A smaller backing on resume is independently checked before writing.
    rejected_advance(ref mut state,ref mut table,ref mut data[..2],1);
    assert(bytes::equal(ref data,ref before));
    let usize released=owners::release(ref mut table,target,64)?;rejected_begin(ref table,40,ref layout,target,1,64);
    return .ok(0);
}

// Group 4: saved recipes grant no authority. Alter metadata AFTER one byte,
// then authenticate again before touching the next byte. Keep the old prefix.
fn Result<usize,owners::Error> late_metadata_rejection(){
    let layouts::Array layout=shape(9,2)?;var usize creating=0;
    while(creating<2){var usize variant=0;while(variant<5){
        var u8[64] data=[85;64];var owners::Table table=owners::empty(64);
        let owners::Token target=if(creating==0){owners::create(ref layout,0,ref mut data,ref mut table)?}else{unused()};
        let u8 op=if(creating==0){40}else{33};
        var cursor::State state=begin(ref table,op,ref layout,target,-1,64)?;
        pending(advance(ref mut state,ref mut table,ref mut data,1)?);
        assert(state.active && state.total==1 && state.last==1 && data[0]==255);
        assert(data[1]==if(creating==0){0}else{85});
        if(variant==0){table.slots[state.slot].generation+=1;}
        else if(variant==1){table.arena.used+=1;}
        else if(variant==2){
            if(creating==0){table.slots[target.slot].length=1;}else{table.depth=1;}
        }else if(variant==3){
            if(creating==0){let owners::ReadLease loan=owners::begin_read(ref mut table,target,64)?;}
            else{table.arena.limit=8;}
        }else{
            if(creating==0){let owners::WriteLease loan=owners::begin_write(ref mut table,target,0,2,64)?;}
            else{table.slots[state.slot].occupied=true;}
        }
        state.last=0;rejected_advance(ref mut state,ref mut table,ref mut data,7);
        assert(state.total==1 && data[0]==255 && data[1]==if(creating==0){0}else{85});variant+=1;
    }creating+=1;}
    // Actual release/reuse produces a valid table with a new token generation.
    var u8[64] data=[0;64];var owners::Table table=owners::empty(64);
    let owners::Token old=owners::create(ref layout,0,ref mut data,ref mut table)?;
    var cursor::State state=begin(ref table,40,ref layout,old,-1,64)?;
    pending(advance(ref mut state,ref mut table,ref mut data,1)?);
    let usize released=owners::release(ref mut table,old,64)?;
    let owners::Token replacement=owners::create(ref layout,42,ref mut data,ref mut table)?;
    assert(replacement.slot==old.slot && replacement.generation!=old.generation);
    state.last=0;rejected_advance(ref mut state,ref mut table,ref mut data,1);
    assert(owners::read(ref table,replacement,0,ref data)?==42);return .ok(0);
}

fn Result<bytes::Buffer,owners::Error> backing(){
    var bytes::Buffer data=switch(bytes::with_capacity(32768)){
        case .ok(v):{v}case .err(_):{return .err(.Quota);}
    };
    if(!bytes::resize_zeroed(ref mut data,32768).is_ok){return .err(.Quota);}return .ok(data);
}
// Group 5: 4096 i64 elements mean 32768 bytes, exactly eight 4096-byte
// batches per operation. Heap-backed buffers keep native stack usage small.
fn Result<usize,owners::Error> maximum_extent_eight_batches(){
    let layouts::Array layout=shape(9,4096)?;var bytes::Buffer data=backing()?;var bytes::Buffer expected=backing()?;
    var owners::Table table=owners::empty(32768);var owners::Table oracle=owners::empty(32768);
    let owners::Token wanted=owners::create(ref layout,-9223372036854775808,bytes::view_mut(ref mut expected),ref mut oracle)?;
    var cursor::State state=begin(ref table,33,ref layout,unused(),-9223372036854775808,32768)?;
    let owners::Table empty=table;var owners::Token actual=unused();var usize batch=0;
    while(batch<8){state.last=0;
        let Option<owners::Token> result=advance(ref mut state,ref mut table,bytes::view_mut(ref mut data),4096)?;
        batch+=1;assert(state.last==4096 && state.total==batch*4096);
        assert(bytes::equal(bytes::view(ref data)[..batch*4096],bytes::view(ref expected)[..batch*4096]));
        if(batch<8){assert(state.active);pending(result);same_table(ref empty,ref table);
            let ref u8[] untouched=bytes::view(ref data);var usize i=batch*4096;
            while(i<untouched.len){assert(untouched[i]==0);i+=1;}
        }else{assert(!state.active);actual=completed(result)?;}
    }
    same_token(actual,wanted);same_table(ref table,ref oracle);
    assert(bytes::equal(bytes::view(ref data),bytes::view(ref expected)));
    let owners::Table retained=table;let usize filled=owners::fill(ref oracle,wanted,9223372036854775807,bytes::view_mut(ref mut expected))?;
    assert(filled==32768);state=begin(ref table,40,ref layout,actual,9223372036854775807,32768)?;batch=0;
    while(batch<8){state.last=0;
        let Option<owners::Token> result=advance(ref mut state,ref mut table,bytes::view_mut(ref mut data),4096)?;
        batch+=1;assert(state.last==4096 && state.total==batch*4096);same_table(ref retained,ref table);
        assert(bytes::equal(bytes::view(ref data)[..batch*4096],bytes::view(ref expected)[..batch*4096]));
        if(batch<8){assert(state.active);pending(result);}else{assert(!state.active);same_token(actual,completed(result)?);}
    }
    same_table(ref table,ref oracle);assert(bytes::equal(bytes::view(ref data),bytes::view(ref expected)));
    assert(owners::read(ref table,actual,0,bytes::view(ref data))?==9223372036854775807);
    assert(owners::read(ref table,actual,4095,bytes::view(ref data))?==9223372036854775807);return .ok(0);
}

pub fn void run(){
    let Heap before=heap();
    assert(scalar_edges_and_atomic_parity().is_ok);same_heap(ref before);
    assert(padding_and_delayed_publication().is_ok);same_heap(ref before);
    assert(preflight_rejections().is_ok);same_heap(ref before);
    assert(late_metadata_rejection().is_ok);same_heap(ref before);
    assert(maximum_extent_eight_batches().is_ok);same_heap(ref before);
}
