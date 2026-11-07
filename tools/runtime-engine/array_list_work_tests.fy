module array_list_work_tests;
import array_list_work as work;
import array_fill_cursor as cursor;
import array_owners as owners;
import array_layout as layouts;
import std::bytes as bytes;
import std::vec as vec;

unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
struct Heap { usize blocks; usize bytes; usize attempts; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()},.attempts=unsafe{probe_attempts()}};}
fn void same_heap(ref Heap h){assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes);}
fn void no_allocation(ref Heap h){same_heap(h);assert(unsafe{probe_attempts()}==h.attempts);}
fn owners::Token unused(){return owners::Token{.slot=16,.generation=0};}
fn Result<layouts::Array,owners::Error> shape(u8 tag,usize length){return switch(layouts::scalar(tag,length)){
    case .ok(v):{.ok(v)}case .err(_):{.err(.Metadata)}};}
fn void same_token(owners::Token a,owners::Token b){assert(a.slot==b.slot && a.generation==b.generation);}
fn void same_table(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(x.generation==y.generation && x.occupied==y.occupied && x.live==y.live);
        assert(x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element);
        assert(x.length==y.length && x.record==y.record && x.alignment==y.alignment && a.order[i]==b.order[i]);i+=1;}
}
fn void same_cursor(ref cursor::State a,ref cursor::State b){
    assert(a.active==b.active && a.op==b.op && a.pc==b.pc && a.frame==b.frame && a.destination==b.destination && a.offset==b.offset);
    assert(a.slot==b.slot && a.generation==b.generation && a.mark==b.mark && a.base==b.base && a.end==b.end && a.depth==b.depth);
    assert(a.source_slot==b.source_slot && a.source_generation==b.source_generation && a.source_base==b.source_base && a.source_end==b.source_end);
    assert(a.element==b.element && a.length==b.length && a.stride==b.stride);
    assert(a.list_gathered==b.list_gathered && a.list_encoded==b.list_encoded && a.written==b.written && a.total==b.total && a.last==b.last);
    var usize i=0;while(i<8){assert(a.encoded[i]==b.encoded[i]);i+=1;}
}
fn Result<cursor::State,owners::Error> begin(ref owners::Table table,u8 op,ref layouts::Array layout,owners::Token target,usize capacity){
    let Heap h=heap();let Result<cursor::State,owners::Error> result=work::begin(table,op,layout,target,capacity);no_allocation(ref h);return result;
}
fn Result<Option<owners::Token>,owners::Error> advance(ref mut cursor::State state,ref mut owners::Table table,
    ref mut u8[] data,ref u8[] operands,ref i64[] registers,ref mut i64[] cells,ref mut u8[] scratch,usize allowance){
    let Heap h=heap();let Result<Option<owners::Token>,owners::Error> result=work::advance(state,table,data,operands,registers,cells,scratch,allowance);
    no_allocation(ref h);return result;
}
fn void pending(Option<owners::Token> result){switch(result){case .none:{}case .some(_):{assert(false);}};}
fn Result<owners::Token,owners::Error> completed(Option<owners::Token> result){return switch(result){case .some(v):{.ok(v)}case .none:{.err(.State)}};}
fn Result<bytes::Buffer,owners::Error> backing(usize size){
    var bytes::Buffer b=switch(bytes::with_capacity(size)){case .ok(v):{v}case .err(_):{return .err(.Quota);}};
    if(!bytes::resize_zeroed(ref mut b,size).is_ok){return .err(.Quota);}return .ok(b);
}

// 1: heterogeneous values in all six scalar domains; exact atomic bytes,
// neighbors and owner identity with small and full caller budgets.
fn Result<usize,owners::Error> scalar_atomic_parity(){
    let u8[6] tags=[1,2,9,10,11,12];let usize[3] budgets=[8,13,4096];var usize t=0;
    while(t<6){let i64[3] values=if(tags[t]==1){[-2147483648,2147483647,-1]}else if(tags[t]==2){[0,1,0]}
        else if(tags[t]==9){[-9223372036854775808,9223372036854775807,-1]}else if(tags[t]==10){[0,255,128]}
        else if(tags[t]==11){[0,4294967295,2147483648]}else{[-1,-9223372036854775808,9223372036854775807]};
        let layouts::Array layout=shape(tags[t],3)?;let layouts::Array byte=shape(10,1)?;let usize size=layout.bytes;
        let u8[3] operands=[2,0,1];let i64[3] registers=[values[1],values[2],values[0]];var usize q=0;
        while(q<3){var usize operation=0;while(operation<2){
            var u8[64] data=[85;64];var u8[64] expected=[85;64];var u8[24] scratch=[77;24];var u8[24] stage=[77;24];
            var i64[3] cells=[0;3];var owners::Table table=owners::empty(64);var owners::Table oracle=owners::empty(64);
            let owners::Token prefix=owners::create(ref byte,42,ref mut data,ref mut table)?;
            let owners::Token reference=owners::create(ref byte,42,ref mut expected,ref mut oracle)?;same_token(prefix,reference);
            var owners::Token target=unused();var owners::Token wanted=unused();
            if(operation==1){target=owners::create(ref layout,0,ref mut data,ref mut table)?;
                wanted=owners::create(ref layout,0,ref mut expected,ref mut oracle)?;
                let owners::Token tail=owners::create(ref byte,9,ref mut data,ref mut table)?;
                let owners::Token guard=owners::create(ref byte,9,ref mut expected,ref mut oracle)?;same_token(tail,guard);
                let usize n=owners::replace_values(ref layout,wanted,ref values,ref mut stage[..size],ref mut expected,ref oracle)?;assert(n==size);
            }else{wanted=owners::create_values(ref layout,ref values,ref mut stage[..size],ref mut expected,ref mut oracle)?;}
            let owners::Table before=table;let u8[64] untouched=data;let u8 op=if(operation==0){80}else{81};
            var cursor::State state=begin(ref table,op,ref layout,target,64)?;var usize calls=0;
            assert(state.total==0 && state.last==0 && state.written==0 && state.list_gathered==0 && state.list_encoded==0);
            same_table(ref before,ref table);assert(bytes::equal(ref data,ref untouched));
            while(state.active){assert(calls<100);state.last=0;let usize previous=state.total;
                let Option<owners::Token> result=advance(ref mut state,ref mut table,ref mut data,ref operands,ref registers,ref mut cells,ref mut scratch[..size],budgets[q])?;
                assert(state.total>previous && state.total-previous==state.last && state.last<=budgets[q]);calls+=1;
                if(state.list_encoded<3){assert(state.written==0 && bytes::equal(ref data,ref untouched));}
                if(state.active){pending(result);same_table(ref before,ref table);}else{same_token(wanted,completed(result)?);}
            }
            let usize extent=state.end-if(op==80){state.mark}else{state.base};
            assert(state.list_gathered==3 && state.list_encoded==3 && state.written==extent && state.total==24+size+extent);
            same_table(ref table,ref oracle);assert(bytes::equal(ref data,ref expected));var usize i=0;
            while(i<3){assert(cells[i]==values[i] && owners::read(ref table,wanted,i,ref data)?==values[i]);i+=1;}operation+=1;
        }q+=1;}t+=1;
    }return .ok(0);
}

// 2: a bad final operand/register or scalar may leave staging progress, but
// neither replacement bytes nor fresh padding/owner metadata can be touched.
fn Result<usize,owners::Error> late_failures(){
    let u8[6] tags=[9,9,1,2,10,11];let i64[6] bad=[0,0,2147483648,2,256,4294967296];var usize f=0;
    while(f<6){var usize operation=0;while(operation<2){let layouts::Array layout=shape(tags[f],3)?;let usize size=layout.bytes;
        var u8[64] data=[85;64];var u8[24] scratch=[77;24];var i64[3] cells=[0;3];var owners::Table table=owners::empty(64);
        let layouts::Array byte=shape(10,1)?;let owners::Token prefix=owners::create(ref byte,7,ref mut data,ref mut table)?;
        let owners::Token target=if(operation==0){unused()}else{owners::create(ref layout,0,ref mut data,ref mut table)?};
        let u8[3] operands=if(f==0){[0,1,128]}else{[0,1,2]};let i64[3] registers=[0,1,bad[f]];
        let usize count=if(f==1){2}else{3};let owners::Table before=table;let u8[64] untouched=data;
        let u8 op=if(operation==0){80}else{81};var cursor::State state=begin(ref table,op,ref layout,target,64)?;
        var bool failed=false;var usize calls=0;while(!failed && calls<12){state.last=0;calls+=1;
            switch(advance(ref mut state,ref mut table,ref mut data,ref operands,ref registers[..count],ref mut cells,ref mut scratch[..size],8)){
                case .ok(v):{pending(v);}case .err(_):{failed=true;}
            };
            assert(state.written==0 && bytes::equal(ref data,ref untouched));same_table(ref before,ref table);
        }
        assert(failed && state.list_gathered==if(f<2){2}else{3});if(f>=2){assert(state.list_encoded==2);}operation+=1;
    }f+=1;}return .ok(0);
}

// 3: minimum atomic gather/encode deferral, carried counters, seven delayed
// padding bytes and publication strictly after the final payload byte.
fn Result<usize,owners::Error> padding_and_deferral(){
    let layouts::Array byte=shape(10,1)?;let layouts::Array layout=shape(9,1)?;
    var u8[32] data=[85;32];var u8[8] scratch=[77;8];var i64[1] cells=[42];let i64[1] registers=[-1];let u8[1] operands=[0];
    var owners::Table table=owners::empty(32);let owners::Token prefix=owners::create(ref byte,7,ref mut data,ref mut table)?;
    let owners::Table before=table;let u8[32] untouched=data;var cursor::State state=begin(ref table,80,ref layout,unused(),32)?;
    assert(state.mark==1 && state.base==8 && state.end==16);state.total=100;state.last=5;
    let cursor::State gather=state;pending(advance(ref mut state,ref mut table,ref mut data,ref operands,ref registers,ref mut cells,ref mut scratch,7)?);
    same_cursor(ref gather,ref state);assert(cells[0]==42 && scratch[0]==77 && bytes::equal(ref data,ref untouched));
    pending(advance(ref mut state,ref mut table,ref mut data,ref operands,ref registers,ref mut cells,ref mut scratch,8)?);
    assert(cells[0]==-1 && state.list_gathered==1 && state.list_encoded==0 && state.total==108 && state.last==13);
    let cursor::State encode=state;pending(advance(ref mut state,ref mut table,ref mut data,ref operands,ref registers,ref mut cells,ref mut scratch,7)?);
    same_cursor(ref encode,ref state);var usize i=0;while(i<8){assert(scratch[i]==77);i+=1;}
    pending(advance(ref mut state,ref mut table,ref mut data,ref operands,ref registers,ref mut cells,ref mut scratch,8)?);
    assert(state.list_encoded==1 && state.written==0 && state.total==116 && state.last==21);
    assert(bytes::equal(ref data,ref untouched));same_table(ref before,ref table);
    pending(advance(ref mut state,ref mut table,ref mut data,ref operands,ref registers,ref mut cells,ref mut scratch,7)?);
    assert(state.written==7 && state.total==123 && data[8]==85);i=1;while(i<8){assert(data[i]==0);i+=1;}same_table(ref before,ref table);
    pending(advance(ref mut state,ref mut table,ref mut data,ref operands,ref registers,ref mut cells,ref mut scratch,7)?);
    assert(state.active && state.written==14 && data[14]==255 && data[15]==85);same_table(ref before,ref table);
    let owners::Token result=completed(advance(ref mut state,ref mut table,ref mut data,ref operands,ref registers,ref mut cells,ref mut scratch,1)?)?;
    assert(!state.active && state.written==15 && state.total==131 && state.last==36 && table.depth==2 && table.arena.used==16);
    assert(owners::read(ref table,prefix,0,ref data)?==7 && owners::read(ref table,result,0,ref data)?==-1 && data[16]==85);return .ok(0);
}

// 4: reauthenticate during gathering and after a committed prefix. Metadata,
// reservation, loans, staging bounds and counter/budget faults preserve all state.
fn Result<usize,owners::Error> resume_rejections(){
    let layouts::Array layout=shape(9,2)?;let u8[2] operands=[0,1];let i64[2] registers=[-1,42];var usize operation=0;
    while(operation<2){var usize phase=0;while(phase<2){var usize fault=0;while(fault<23){
        var u8[64] data=[85;64];var u8[16] scratch=[77;16];var i64[2] cells=[0;2];var owners::Table table=owners::empty(64);
        let owners::Token target=if(operation==0){unused()}else{owners::create(ref layout,0,ref mut data,ref mut table)?};
        let u8 op=if(operation==0){80}else{81};var cursor::State state=begin(ref table,op,ref layout,target,64)?;
        let usize initial=if(phase==0){8}else{33};pending(advance(ref mut state,ref mut table,ref mut data,ref operands,ref registers,ref mut cells,ref mut scratch,initial)?);
        assert(state.written==if(phase==0){0}else{1});state.last=0;var usize allowance=8;var usize capacity=64;
        var usize arity=2;var usize cell_count=2;var usize scratch_size=16;let usize slot=state.slot;
        if(fault==0){table.slots[slot].generation+=1;}else if(fault==1){state.generation+=1;}
        else if(fault==2){state.base+=8;}else if(fault==3){state.end-=8;}else if(fault==4){state.depth+=1;}
        else if(fault==5){state.stride=1;}else if(fault==6){state.active=false;}else if(fault==7){state.op=33;}
        else if(fault==8){state.list_gathered=3;}else if(fault==9){state.list_encoded=3;}
        else if(fault==10){state.list_encoded=1;}else if(fault==11){state.written=17;}
        else if(fault==12){state.total=0;}else if(fault==13){state.total=18446744073709551615;}
        else if(fault==14){allowance=0;}else if(fault==15){allowance=4097;}else if(fault==16){state.last=1;allowance=4096;}
        else if(fault==17){capacity=15;}else if(fault==18){arity=1;}else if(fault==19){cell_count=1;}
        else if(fault==20){scratch_size=15;}else if(fault==21){table.arena.limit=state.end-1;}
        else{if(operation==0){table.slots[slot].occupied=true;}else{let owners::ReadLease loan=owners::begin_read(ref mut table,target,64)?;}}
        let owners::Table before=table;let cursor::State saved=state;let u8[64] old=data;let u8[16] encoded=scratch;let i64[2] values=cells;
        assert(!advance(ref mut state,ref mut table,ref mut data[..capacity],ref operands[..arity],ref registers,ref mut cells[..cell_count],ref mut scratch[..scratch_size],allowance).is_ok);
        same_table(ref before,ref table);same_cursor(ref saved,ref state);assert(bytes::equal(ref data,ref old) && bytes::equal(ref scratch,ref encoded));
        assert(cells[0]==values[0] && cells[1]==values[1]);fault+=1;
    }phase+=1;}operation+=1;}
    // Writable-target admission rejects both loan types and stale generations.
    var u8[32] data=[0;32];var owners::Table table=owners::empty(32);let owners::Token target=owners::create(ref layout,0,ref mut data,ref mut table)?;
    let owners::ReadLease reader=owners::begin_read(ref mut table,target,32)?;assert(!begin(ref table,81,ref layout,target,32).is_ok);
    let usize ended=owners::end_read(ref mut table,reader,32)?;let owners::WriteLease writer=owners::begin_write(ref mut table,target,0,2,32)?;
    assert(!begin(ref table,81,ref layout,target,32).is_ok);let usize finished=owners::end_write(ref mut table,ref writer,32)?;
    let usize released=owners::release(ref mut table,target,32)?;let owners::Token replacement=owners::create(ref layout,1,ref mut data,ref mut table)?;
    assert(replacement.slot==target.slot && replacement.generation!=target.generation && !begin(ref table,81,ref layout,target,32).is_ok);
    assert(!begin(ref table,0,ref layout,target,32).is_ok);return .ok(0);
}

// 5: maximum lists use heap-backed i64 cells and byte buffers. Aligned i64
// needs eight gather, eight encode, eight commit batches; bool needs 8+1+1.
fn Result<usize,owners::Error> maximum_batches(){
    let i64[4] wide=[-9223372036854775808,9223372036854775807,-1,42];let i64[4] boolean=[0,1,1,0];
    let u8[4] cycle=[0,1,2,3];var u8[4096] operands=[0;4096];var usize i=0;while(i<4096){operands[i]=cycle[i%4];i+=1;}
    var usize domain=0;while(domain<2){let layouts::Array layout=shape(if(domain==0){9}else{2},4096)?;let usize size=layout.bytes;
        let i64[4] registers=if(domain==0){wide}else{boolean};var usize operation=0;while(operation<2){
            var vec::Vec<i64> cells=vec::empty<i64>();if(!vec::reserve<i64>(ref mut cells,4096).is_ok){return .err(.Quota);}
            i=0;while(i<4096){if(!vec::push<i64>(ref mut cells,0).is_ok){return .err(.Quota);}i+=1;}
            var bytes::Buffer data=backing(size+2)?;var bytes::Buffer expected=backing(size+2)?;var bytes::Buffer scratch=backing(size)?;
            var owners::Table table=owners::empty(size);var owners::Table oracle=owners::empty(size);
            var owners::Token target=unused();var owners::Token wanted=unused();
            {let ref mut u8[] actual=bytes::view_mut(ref mut data);let ref mut u8[] reference=bytes::view_mut(ref mut expected);
                i=0;while(i<size+2){actual[i]=85;reference[i]=85;i+=1;}
                if(operation==1){target=owners::create(ref layout,0,actual[1..size+1],ref mut table)?;
                    wanted=owners::create(ref layout,0,reference[1..size+1],ref mut oracle)?;}}
            let owners::Table before=table;let u8 op=if(operation==0){80}else{81};var cursor::State state=begin(ref table,op,ref layout,target,size)?;
            let usize encode_end=if(domain==0){16}else{9};let usize batches=if(domain==0){24}else{10};var usize batch=0;
            while(batch<batches){state.last=0;let ref mut i64[] values=vec::view_mut_i64(ref mut cells);let ref mut u8[] stage=bytes::view_mut(ref mut scratch);
                let ref mut u8[] all=bytes::view_mut(ref mut data);
                let Option<owners::Token> result=advance(ref mut state,ref mut table,all[1..size+1],ref operands,ref registers,values,stage,4096)?;
                batch+=1;assert(state.last==4096 && state.total==batch*4096 && all[0]==85 && all[size+1]==85);
                let usize gather=if(batch<8){batch*512}else{4096};let usize encoding=if(batch<=8){0}else if(domain==0 && batch<16){(batch-8)*512}else{4096};
                let usize committed=if(batch<=encode_end){0}else{(batch-encode_end)*4096};
                assert(state.list_gathered==gather && state.list_encoded==encoding && state.written==committed);
                i=committed;while(i<size){assert(all[1+i]==if(operation==0){85}else{0});i+=1;}
                if(batch<batches){assert(state.active);pending(result);same_table(ref before,ref table);}else{assert(!state.active);target=completed(result)?;}
            }
            {let ref i64[] values=vec::view_i64(ref cells);let ref mut u8[] stage=bytes::view_mut(ref mut scratch);let ref mut u8[] all=bytes::view_mut(ref mut expected);
                if(operation==0){wanted=owners::create_values(ref layout,values,stage,all[1..size+1],ref mut oracle)?;}
                else{let usize count=owners::replace_values(ref layout,wanted,values,stage,all[1..size+1],ref oracle)?;assert(count==size);}}
            same_token(target,wanted);same_table(ref table,ref oracle);assert(bytes::equal(bytes::view(ref data),bytes::view(ref expected)));
            assert(state.total==32768+2*size && state.written==size);operation+=1;
        }domain+=1;
    }return .ok(0);
}

pub fn void run(){
    let Heap before=heap();
    assert(scalar_atomic_parity().is_ok);same_heap(ref before);
    assert(late_failures().is_ok);same_heap(ref before);
    assert(padding_and_deferral().is_ok);same_heap(ref before);
    assert(resume_rejections().is_ok);same_heap(ref before);
    assert(maximum_batches().is_ok);same_heap(ref before);
}
