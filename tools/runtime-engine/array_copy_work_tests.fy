module array_copy_work_tests;
import array_copy_work as work;
import array_fill_cursor as cursor;
import array_owners as owners;
import array_layout as layouts;
import std::bytes as bytes;

// Native fixture owns the hooks and main/runner integration.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
struct Heap { usize blocks; usize bytes; usize attempts; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()},
    .attempts=unsafe{probe_attempts()}};}
fn void same_heap(ref Heap h){assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes);}
fn void no_allocation(ref Heap h){same_heap(h);assert(unsafe{probe_attempts()}==h.attempts);}
fn owners::Token unused(){return owners::Token{.slot=16,.generation=0};}
fn Result<layouts::Array,owners::Error> shape(u8 tag,usize length){
    return switch(layouts::scalar(tag,length)){case .ok(v):{.ok(v)}case .err(_):{.err(.Metadata)}};
}
fn void same_token(owners::Token a,owners::Token b){assert(a.slot==b.slot && a.generation==b.generation);}
fn void same_table(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(x.generation==y.generation && x.occupied==y.occupied && x.live==y.live);
        assert(x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end);
        assert(x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment);
        assert(a.order[i]==b.order[i]);i+=1;
    }
}
fn void same_cursor(ref cursor::State a,ref cursor::State b){
    assert(a.active==b.active && a.op==b.op && a.pc==b.pc && a.frame==b.frame);
    assert(a.destination==b.destination && a.offset==b.offset && a.slot==b.slot && a.generation==b.generation);
    assert(a.mark==b.mark && a.base==b.base && a.end==b.end && a.depth==b.depth);
    assert(a.element==b.element && a.length==b.length && a.stride==b.stride);
    assert(a.source_slot==b.source_slot && a.source_generation==b.source_generation);
    assert(a.source_base==b.source_base && a.source_end==b.source_end);
    assert(a.written==b.written && a.total==b.total && a.last==b.last);
    var usize i=0;while(i<8){assert(a.encoded[i]==b.encoded[i]);i+=1;}
}
fn Result<cursor::State,owners::Error> begin(ref owners::Table table,u8 op,ref layouts::Array layout,
    owners::Token destination,owners::Token source,ref u8[] data){
    let Heap h=heap();let Result<cursor::State,owners::Error> result=work::begin(table,op,layout,destination,source,data);
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
fn Result<owners::Token,owners::Error> drain(ref mut cursor::State state,ref mut owners::Table table,
    ref mut u8[] data,usize quantum){
    let owners::Table before=*table;var usize calls=0;
    while(state.active){
        assert(calls<32776 && state.last<=4096);if(state.last==4096){state.last=0;}
        let usize room=4096-state.last;let usize allowance=if(quantum<room){quantum}else{room};
        let usize previous=state.total;let usize written=state.written;let usize last=state.last;
        let Option<owners::Token> result=advance(state,table,data,allowance)?;calls+=1;
        let usize count=state.total-previous;
        assert(count>0 && count<=allowance && state.last==last+count && state.written==written+count);
        if(state.active){pending(result);same_table(ref before,table);}
        else{if(state.op==38){same_table(ref before,table);}return completed(result);}
    }return .err(.State);
}
// Rejections preserve the current prefix, never roll back earlier chunks.
fn void rejected_begin(ref owners::Table table,u8 op,ref layouts::Array layout,
    owners::Token destination,owners::Token source,ref u8[] data){
    assert(data.len<=128);var u8[128] saved=[0;128];var usize i=0;
    while(i<data.len){saved[i]=data[i];i+=1;}let owners::Table before=*table;
    assert(!begin(table,op,layout,destination,source,data).is_ok);same_table(ref before,table);
    i=0;while(i<data.len){assert(saved[i]==data[i]);i+=1;}
}
fn void rejected_advance(ref mut cursor::State state,ref mut owners::Table table,ref mut u8[] data,usize allowance){
    assert(data.len<=128);var u8[128] saved=[0;128];var usize i=0;
    while(i<data.len){saved[i]=data[i];i+=1;}let owners::Table before=*table;let cursor::State recipe=*state;
    assert(!advance(state,table,data,allowance).is_ok);same_table(ref before,table);same_cursor(ref recipe,state);
    i=0;while(i<data.len){assert(saved[i]==data[i]);i+=1;}
}

// Group 1: all six scalar tags, heterogeneous elements, tiny split encodings,
// exact atomic copy/assign bytes and full owner metadata, plus identity NoOp.
fn Result<usize,owners::Error> scalar_and_atomic_parity(){
    let u8[6] tags=[1,2,9,10,11,12];let usize[3] quanta=[1,3,4096];
    var usize tag=0;while(tag<6){
        let i64[3] values=if(tags[tag]==1){[-2147483648,2147483647,-1]}
            else if(tags[tag]==2){[0,1,0]}
            else if(tags[tag]==9){[-9223372036854775808,9223372036854775807,-1]}
            else if(tags[tag]==10){[0,255,128]}
            else if(tags[tag]==11){[0,4294967295,2147483648]}
            else{[-1,-9223372036854775808,9223372036854775807]};
        let layouts::Array layout=shape(tags[tag],3)?;let usize reads=if(tags[tag]==2){3}else{0};
        var usize q=0;while(q<3){var usize operation=0;while(operation<2){
            var u8[128] data=[85;128];var u8[128] expected=[85;128];
            var owners::Table table=owners::empty(128);var owners::Table oracle=owners::empty(128);
            let owners::Token source=owners::create(ref layout,0,ref mut data,ref mut table)?;
            let owners::Token origin=owners::create(ref layout,0,ref mut expected,ref mut oracle)?;same_token(source,origin);
            var usize i=0;while(i<3){let usize a=owners::write(ref table,source,i,values[i],ref mut data)?;
                let usize b=owners::write(ref oracle,origin,i,values[i],ref mut expected)?;i+=1;}
            var owners::Token destination=unused();var owners::Token wanted=unused();
            if(operation==1){destination=owners::create(ref layout,1,ref mut data,ref mut table)?;
                wanted=owners::create(ref layout,1,ref mut expected,ref mut oracle)?;same_token(destination,wanted);}
            let owners::Table before=table;let u8[128] untouched=data;
            if(operation==0){wanted=owners::copy(origin,ref mut expected,ref mut oracle)?;}
            else{let usize count=owners::assign(wanted,origin,ref mut expected,ref oracle)?;assert(count==layout.bytes);}
            let u8 op=if(operation==0){34}else{38};
            var cursor::State state=begin(ref table,op,ref layout,destination,source,ref data)?;
            assert(state.active && state.written==0 && state.total==reads && state.last==reads);
            assert(state.source_slot==source.slot && state.source_generation==source.generation);
            assert(state.source_base==table.slots[source.slot].base && state.source_end==table.slots[source.slot].end);
            same_table(ref before,ref table);assert(bytes::equal(ref data,ref untouched));
            let owners::Token actual=drain(ref mut state,ref mut table,ref mut data,quanta[q])?;
            same_token(actual,wanted);same_table(ref table,ref oracle);assert(bytes::equal(ref data,ref expected));
            assert(!state.active && state.written==layout.bytes && state.total==reads+layout.bytes);
            i=0;while(i<3){assert(owners::read(ref table,actual,i,ref data)?==values[i]);i+=1;}
            let owners::Table retained=table;let u8[128] identity_bytes=data;
            let usize assigned=owners::assign(actual,actual,ref mut expected,ref oracle)?;assert(assigned==layout.bytes);
            state=begin(ref table,38,ref layout,actual,actual,ref data)?;
            assert(!state.active && state.written==0 && state.total==reads && state.last==reads);
            same_table(ref retained,ref table);assert(bytes::equal(ref data,ref identity_bytes));
            assert(bytes::equal(ref data,ref expected));rejected_advance(ref mut state,ref mut table,ref mut data,1);
            operation+=1;
        }q+=1;}tag+=1;
    }return .ok(0);
}

// Group 2: fresh copy counts/zeros seven alignment bytes and publishes only on
// the final byte. Bool validation is charged once; resume never rescans payload.
fn Result<usize,owners::Error> padding_publication_and_bool_accounting(){
    let layouts::Array wide=shape(9,1)?;let layouts::Array byte=shape(10,1)?;
    var u8[64] data=[85;64];var u8[64] expected=[85;64];
    var owners::Table table=owners::empty(64);var owners::Table oracle=owners::empty(64);
    let owners::Token source=owners::create(ref wide,-1,ref mut data,ref mut table)?;
    let owners::Token origin=owners::create(ref wide,-1,ref mut expected,ref mut oracle)?;
    let owners::Token prefix=owners::create(ref byte,42,ref mut data,ref mut table)?;
    let owners::Token reference=owners::create(ref byte,42,ref mut expected,ref mut oracle)?;same_token(prefix,reference);
    let owners::Token wanted=owners::copy(origin,ref mut expected,ref mut oracle)?;let owners::Table before=table;
    var cursor::State state=begin(ref table,34,ref wide,unused(),source,ref data)?;
    assert(state.mark==9 && state.base==16 && state.end==24 && state.depth==2);
    pending(advance(ref mut state,ref mut table,ref mut data,3)?);
    assert(state.written==3 && state.last==3 && state.total==3);same_table(ref before,ref table);
    var usize i=9;while(i<12){assert(data[i]==0);i+=1;}assert(data[12]==85 && data[16]==85);
    pending(advance(ref mut state,ref mut table,ref mut data,4)?);
    assert(state.written==7 && state.total==7 && state.last==7 && data[15]==0 && data[16]==85);
    same_table(ref before,ref table);state.last=0;
    pending(advance(ref mut state,ref mut table,ref mut data,7)?);
    assert(state.active && state.written==14 && state.total==14 && state.last==7 && data[22]==255 && data[23]==85);
    same_table(ref before,ref table);same_token(wanted,completed(advance(ref mut state,ref mut table,ref mut data,1)?)?);
    assert(!state.active && state.written==15 && state.total==15 && state.last==8);
    same_table(ref table,ref oracle);assert(bytes::equal(ref data,ref expected));
    assert(table.depth==3 && table.arena.used==24 && data[8]==42 && data[24]==85);

    let layouts::Array boolean=shape(2,3)?;var usize operation=0;
    while(operation<2){var u8[32] payload=[85;32];var owners::Table ledger=owners::empty(32);
        let owners::Token root=owners::create(ref boolean,1,ref mut payload,ref mut ledger)?;
        let owners::Token target=if(operation==0){unused()}else{owners::create(ref boolean,0,ref mut payload,ref mut ledger)?};
        let owners::Table retained=ledger;let u8 op=if(operation==0){34}else{38};
        state=begin(ref ledger,op,ref boolean,target,root,ref payload)?;
        assert(state.total==3 && state.last==3 && state.written==0);
        pending(advance(ref mut state,ref mut ledger,ref mut payload,1)?);
        assert(state.total==4 && state.last==4 && state.written==1);same_table(ref retained,ref ledger);
        // Poison only an already-consumed source byte, then restore it. A full
        // resume scan would reject; the remaining transferred bytes stay valid.
        payload[0]=2;pending(advance(ref mut state,ref mut ledger,ref mut payload,1)?);payload[0]=1;
        assert(state.total==5 && state.last==5 && state.written==2);same_table(ref retained,ref ledger);
        state.last=0;let owners::Token result=completed(advance(ref mut state,ref mut ledger,ref mut payload,4096)?)?;
        assert(!state.active && state.total==6 && state.last==1 && state.written==3);
        assert(owners::read(ref ledger,result,0,ref payload)?==1 && owners::read(ref ledger,result,2,ref payload)?==1);
        operation+=1;
    }return .ok(0);
}

// Group 3: complete bool preflight (including identity), exact shape, tokens,
// loans, backing, owner pressure and reservation limits all reject before writes.
fn Result<usize,owners::Error> preflight_rejections(){
    let layouts::Array layout=shape(2,3)?;var u8[128] data=[85;128];var owners::Table table=owners::empty(128);
    let owners::Token source=owners::create(ref layout,1,ref mut data,ref mut table)?;
    let owners::Token target=owners::create(ref layout,0,ref mut data,ref mut table)?;
    var usize i=0;while(i<3){data[i]=2;
        rejected_begin(ref table,34,ref layout,unused(),source,ref data);
        rejected_begin(ref table,38,ref layout,target,source,ref data);
        rejected_begin(ref table,38,ref layout,source,source,ref data);data[i]=1;i+=1;
    }
    let owners::Token stale=owners::Token{.slot=source.slot,.generation=source.generation+1};
    rejected_begin(ref table,34,ref layout,unused(),stale,ref data);
    rejected_begin(ref table,38,ref layout,target,stale,ref data);
    rejected_begin(ref table,38,ref layout,stale,source,ref data);
    rejected_begin(ref table,38,ref layout,unused(),source,ref data);
    rejected_begin(ref table,0,ref layout,target,source,ref data);
    let layouts::Array wrong_tag=shape(10,3)?;let layouts::Array wrong_length=shape(2,2)?;
    rejected_begin(ref table,34,ref wrong_tag,unused(),source,ref data);
    rejected_begin(ref table,38,ref wrong_length,target,source,ref data);
    let owners::Token unlike=owners::create(ref wrong_tag,7,ref mut data,ref mut table)?;
    let owners::Token shorter=owners::create(ref wrong_length,0,ref mut data,ref mut table)?;
    rejected_begin(ref table,38,ref layout,unlike,source,ref data);
    rejected_begin(ref table,38,ref layout,shorter,source,ref data);
    i=0;while(i<3){var layouts::Array malformed=layout;
        if(i==0){malformed.stride=8;}else if(i==1){malformed.alignment=8;}else{malformed.bytes+=1;}
        rejected_begin(ref table,34,ref malformed,unused(),source,ref data);
        rejected_begin(ref table,38,ref malformed,target,source,ref data);i+=1;
    }
    rejected_begin(ref table,34,ref layout,unused(),source,ref data[..2]);
    rejected_begin(ref table,38,ref layout,target,source,ref data[..5]);
    let owners::WriteLease writer=owners::begin_write(ref mut table,source,0,3,128)?;
    rejected_begin(ref table,34,ref layout,unused(),source,ref data);
    rejected_begin(ref table,38,ref layout,target,source,ref data);
    let usize source_end=owners::end_write(ref mut table,ref writer,128)?;
    let owners::ReadLease reader=owners::begin_read(ref mut table,target,128)?;
    rejected_begin(ref table,38,ref layout,target,source,ref data);
    let usize read_end=owners::end_read(ref mut table,reader,128)?;
    let owners::WriteLease target_writer=owners::begin_write(ref mut table,target,0,3,128)?;
    rejected_begin(ref table,38,ref layout,target,source,ref data);
    let usize target_end=owners::end_write(ref mut table,ref target_writer,128)?;
    // A source read lease is compatible with copying into a different owner.
    let owners::ReadLease source_reader=owners::begin_read(ref mut table,source,128)?;
    var cursor::State state=begin(ref table,38,ref layout,target,source,ref data)?;
    same_token(target,drain(ref mut state,ref mut table,ref mut data,1)?);
    state=begin(ref table,34,ref layout,unused(),source,ref data)?;
    let owners::Token copy=drain(ref mut state,ref mut table,ref mut data,1)?;
    let usize source_read_end=owners::end_read(ref mut table,source_reader,128)?;
    table.arena.limit=table.arena.used;rejected_begin(ref table,34,ref layout,unused(),source,ref data);
    table.arena.limit=128;
    while(table.depth<16){let owners::Token extra=owners::copy(source,ref mut data,ref mut table)?;}
    rejected_begin(ref table,34,ref layout,unused(),source,ref data);
    let usize released=owners::clear(ref mut table,128)?;
    rejected_begin(ref table,34,ref layout,unused(),source,ref data);return .ok(0);
}

// Group 4: one transferred byte precedes each fault. Reauthenticate both roots
// and every saved extent/counter before the next write; preserve the prefix.
fn Result<usize,owners::Error> resume_rejections(){
    let layouts::Array layout=shape(9,2)?;var usize operation=0;
    while(operation<2){var usize fault=0;while(fault<38){
        var u8[128] data=[85;128];var owners::Table table=owners::empty(128);
        let owners::Token target=if(operation==0){unused()}else{owners::create(ref layout,0,ref mut data,ref mut table)?};
        let owners::Token source=owners::create(ref layout,-1,ref mut data,ref mut table)?;
        let u8 op=if(operation==0){34}else{38};
        var cursor::State state=begin(ref table,op,ref layout,target,source,ref data)?;
        rejected_advance(ref mut state,ref mut table,ref mut data,0);
        rejected_advance(ref mut state,ref mut table,ref mut data,4097);
        pending(advance(ref mut state,ref mut table,ref mut data,1)?);
        assert(state.total==1 && state.last==1 && state.written==1 && data[state.base]==255);
        rejected_advance(ref mut state,ref mut table,ref mut data,4096);state.last=0;
        if(fault==0){table.slots[source.slot].generation+=1;}
        else if(fault==1){table.slots[state.slot].generation+=1;}
        else if(fault==2){table.slots[source.slot].length=1;}
        else if(fault==3){table.slots[source.slot].base+=8;}
        else if(fault==4){table.slots[source.slot].end-=8;}
        else if(fault==5){table.slots[source.slot].element=12;}
        else if(fault==6){table.slots[source.slot].record=1;}
        else if(fault==7){let owners::WriteLease loan=owners::begin_write(ref mut table,source,0,2,128)?;}
        else if(fault==8){if(operation==1){let owners::ReadLease loan=owners::begin_read(ref mut table,target,128)?;}
            else{table.slots[state.slot].occupied=true;}}
        else if(fault==9){if(operation==1){let owners::WriteLease loan=owners::begin_write(ref mut table,target,0,2,128)?;}
            else{table.depth+=1;}}
        else if(fault==10){table.arena.used+=1;}
        else if(fault==11){table.arena.limit=state.end-1;}
        else if(fault==12){state.source_slot=16;}
        else if(fault==13){state.source_generation+=1;}
        else if(fault==14){state.source_base+=1;}
        else if(fault==15){state.source_end-=1;}
        else if(fault==16){state.slot=16;}
        else if(fault==17){state.generation+=1;}
        else if(fault==18){state.mark+=1;}
        else if(fault==19){state.base+=1;}
        else if(fault==20){state.end-=1;}
        else if(fault==21){state.depth+=1;}
        else if(fault==22){state.stride=1;}
        else if(fault==23){state.element=12;}
        else if(fault==24){state.length=1;}
        else if(fault==25){state.written=17;}
        else if(fault==26){state.total=0;}
        else if(fault==27){state.last=4097;}
        else if(fault==28){state.last=2;}
        else if(fault==29){state.total=18446744073709551615;}
        else if(fault==30){state.op=0;}
        else if(fault==31){state.active=false;}
        else if(fault==32){table.slots[source.slot].alignment=8;}
        else if(fault==33){table.slots[source.slot].mark+=1;}
        else if(fault==34){table.order[0]=16;}
        else if(fault==35){table.slots[source.slot].live=false;}
        else if(fault==36){
            let usize freed=owners::release(ref mut table,source,128)?;
            let owners::Token replacement=owners::create(ref layout,42,ref mut data,ref mut table)?;
            assert(replacement.slot==source.slot && replacement.generation!=source.generation);
        }else{let usize short=state.end-1;
            rejected_advance(ref mut state,ref mut table,ref mut data[..short],1);fault+=1;continue;}
        rejected_advance(ref mut state,ref mut table,ref mut data,1);fault+=1;
    }operation+=1;}
    // A valid ledger can also replace the destination at the same slot/extent.
    var u8[128] data=[0;128];var owners::Table table=owners::empty(128);
    let owners::Token source=owners::create(ref layout,-1,ref mut data,ref mut table)?;
    let owners::Token target=owners::create(ref layout,0,ref mut data,ref mut table)?;
    var cursor::State state=begin(ref table,38,ref layout,target,source,ref data)?;
    pending(advance(ref mut state,ref mut table,ref mut data,1)?);
    let usize freed=owners::release(ref mut table,target,128)?;
    let owners::Token replacement=owners::create(ref layout,42,ref mut data,ref mut table)?;
    assert(replacement.slot==target.slot && replacement.generation!=target.generation);state.last=0;
    rejected_advance(ref mut state,ref mut table,ref mut data,1);return .ok(0);
}

fn Result<bytes::Buffer,owners::Error> backing(usize size){
    var bytes::Buffer data=switch(bytes::with_capacity(size)){case .ok(v):{v}case .err(_):{return .err(.Quota);}};
    if(!bytes::resize_zeroed(ref mut data,size).is_ok){return .err(.Quota);}return .ok(data);
}
// Group 5: heap-backed maximum payloads keep the default stack small. Wide
// copy/assign each take eight batches; a maximum bool scan fills begin's batch.
fn Result<usize,owners::Error> maximum_extents_and_batch_cap(){
    let layouts::Array layout=shape(9,4096)?;var usize operation=0;
    while(operation<2){var bytes::Buffer data=backing(65536)?;var bytes::Buffer expected=backing(65536)?;
        var owners::Table table=owners::empty(65536);var owners::Table oracle=owners::empty(65536);
        let owners::Token source=owners::create(ref layout,-1,bytes::view_mut(ref mut data),ref mut table)?;
        let owners::Token origin=owners::create(ref layout,-1,bytes::view_mut(ref mut expected),ref mut oracle)?;
        var owners::Token target=unused();var owners::Token wanted=unused();
        if(operation==0){wanted=owners::copy(origin,bytes::view_mut(ref mut expected),ref mut oracle)?;}
        else{target=owners::create(ref layout,0,bytes::view_mut(ref mut data),ref mut table)?;
            wanted=owners::create(ref layout,0,bytes::view_mut(ref mut expected),ref mut oracle)?;
            let usize count=owners::assign(wanted,origin,bytes::view_mut(ref mut expected),ref oracle)?;assert(count==32768);}
        let owners::Table before=table;let u8 op=if(operation==0){34}else{38};
        var cursor::State state=begin(ref table,op,ref layout,target,source,bytes::view(ref data))?;
        assert(state.total==0 && state.last==0 && state.written==0 && state.base==32768);
        var usize batch=0;while(batch<8){state.last=0;
            let Option<owners::Token> result=advance(ref mut state,ref mut table,bytes::view_mut(ref mut data),4096)?;
            batch+=1;assert(state.last==4096 && state.total==batch*4096 && state.written==batch*4096);
            let usize stop=state.base+batch*4096;
            assert(bytes::equal(bytes::view(ref data)[..stop],bytes::view(ref expected)[..stop]));
            if(batch<8){assert(state.active);pending(result);same_table(ref before,ref table);
                let ref u8[] remaining=bytes::view(ref data);var usize i=stop;
                while(i<remaining.len){assert(remaining[i]==0);i+=1;}
            }else{assert(!state.active);same_token(wanted,completed(result)?);}
        }
        same_table(ref table,ref oracle);assert(bytes::equal(bytes::view(ref data),bytes::view(ref expected)));operation+=1;
    }
    let layouts::Array boolean=shape(2,4096)?;var bytes::Buffer data=backing(8192)?;
    var owners::Table table=owners::empty(8192);
    let owners::Token source=owners::create(ref boolean,1,bytes::view_mut(ref mut data),ref mut table)?;
    var owners::Token destination=unused();
    operation=0;while(operation<2){let u8 op=if(operation==0){34}else{38};
        var cursor::State state=begin(ref table,op,ref boolean,destination,source,bytes::view(ref data))?;
        assert(state.active && state.written==0 && state.total==4096 && state.last==4096);
        let cursor::State saved=state;let owners::Table before=table;
        assert(!advance(ref mut state,ref mut table,bytes::view_mut(ref mut data),1).is_ok);
        same_cursor(ref saved,ref state);same_table(ref before,ref table);
        {let ref u8[] untouched=bytes::view(ref data);var usize i=0;
            while(i<8192){assert(untouched[i]==if(i<4096){1}else{0});i+=1;}}
        state.last=0;let owners::Token result=completed(advance(ref mut state,ref mut table,bytes::view_mut(ref mut data),4096)?)?;
        assert(!state.active && state.written==4096 && state.total==8192 && state.last==4096);
        assert(owners::read(ref table,result,4095,bytes::view(ref data))?==1);
        destination=result;
        // Restore a distinct destination for the next operation.
        let usize filled=owners::fill(ref table,result,0,bytes::view_mut(ref mut data))?;assert(filled==4096);
        let owners::Table retained=table;
        let cursor::State identity=begin(ref table,38,ref boolean,source,source,bytes::view(ref data))?;
        assert(!identity.active && identity.written==0 && identity.total==4096 && identity.last==4096);
        // The final source byte must be validated even for the identity NoOp.
        bytes::view_mut(ref mut data)[4095]=2;
        assert(!begin(ref table,38,ref boolean,source,source,bytes::view(ref data)).is_ok);
        same_table(ref retained,ref table);
        {let ref u8[] unchanged=bytes::view(ref data);var usize i=0;
            while(i<8192){assert(unchanged[i]==if(i<4095){1}else if(i==4095){2}else{0});i+=1;}}
        bytes::view_mut(ref mut data)[4095]=1;operation+=1;
    }return .ok(0);
}

pub fn void run(){
    let Heap before=heap();
    assert(scalar_and_atomic_parity().is_ok);same_heap(ref before);
    assert(padding_publication_and_bool_accounting().is_ok);same_heap(ref before);
    assert(preflight_rejections().is_ok);same_heap(ref before);
    assert(resume_rejections().is_ok);same_heap(ref before);
    assert(maximum_extents_and_batch_cap().is_ok);same_heap(ref before);
}
