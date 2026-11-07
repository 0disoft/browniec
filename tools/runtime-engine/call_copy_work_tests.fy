module call_copy_work_tests;
import call_copy_work as work;
import call_copy_cursor as cursor;
import array_owners as owners;
import array_layout as arrays;
import struct_layout as records;
import std::bytes as bytes;

unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
struct Heap { usize blocks; usize bytes; usize attempts; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()},.attempts=unsafe{probe_attempts()}};}
fn void same_heap(ref Heap h){assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes);}
fn void no_allocation(ref Heap h){same_heap(h);assert(unsafe{probe_attempts()}==h.attempts);}
fn Result<arrays::Array,owners::Error> shape(u8 tag,usize length){return switch(arrays::scalar(tag,length)){
    case .ok(v):{.ok(v)}case .err(_):{.err(.Metadata)}};}
fn owners::CallArgument arg(owners::Token source,u8 element,usize length){
    return owners::CallArgument{.source=source,.element=element,.length=length,.record=0};
}
fn void same_copies(ref owners::Copies a,ref owners::Copies b){assert(a.count==b.count);var usize i=0;
    while(i<a.count){assert(a.tokens[i].slot==b.tokens[i].slot && a.tokens[i].generation==b.tokens[i].generation);i+=1;}}
fn void same_table(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);var usize i=0;
    while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(x.generation==y.generation && x.occupied==y.occupied && x.live==y.live && x.read_generation==y.read_generation);
        assert(x.reading==y.reading && x.writing==y.writing && x.mark==y.mark && x.base==y.base && x.end==y.end);
        assert(x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment && a.order[i]==b.order[i]);i+=1;}
}
fn void same_cursor(ref cursor::State a,ref cursor::State b){
    assert(a.active==b.active && a.phase==b.phase && a.index==b.index && a.at==b.at && a.count==b.count);
    assert(a.mark==b.mark && a.end==b.end && a.depth==b.depth && a.written==b.written && a.total==b.total && a.last==b.last);
    var usize i=0;while(i<8){assert(a.source_slots[i]==b.source_slots[i] && a.source_generations[i]==b.source_generations[i]);
        assert(a.source_bases[i]==b.source_bases[i] && a.source_ends[i]==b.source_ends[i]);
        assert(a.target_slots[i]==b.target_slots[i] && a.target_generations[i]==b.target_generations[i]);i+=1;}
}
fn Result<cursor::State,owners::Error> begin(ref owners::Table t,ref records::Catalog c,ref owners::CallArgument[] args,usize capacity){
    let Heap h=heap();let Result<cursor::State,owners::Error> r=work::begin(t,c,args,capacity);no_allocation(ref h);return r;
}
fn Result<Option<owners::Copies>,owners::Error> advance(ref mut cursor::State s,ref mut owners::Table t,
    ref records::Catalog c,ref owners::CallArgument[] args,ref mut u8[] data,usize allowance){
    let Heap h=heap();let Result<Option<owners::Copies>,owners::Error> r=work::advance(s,t,c,args,data,allowance);no_allocation(ref h);return r;
}
fn void pending(Option<owners::Copies> r){switch(r){case .none:{}case .some(_):{assert(false);}};}
fn Result<owners::Copies,owners::Error> completed(Option<owners::Copies> r){return switch(r){case .some(v):{.ok(v)}case .none:{.err(.State)}};}
fn usize error_kind(owners::Error e){return switch(e){
    case .State:{1}case .Value:{2}case .Token:{0}case .Owners:{0}case .Type:{0}case .Length:{0}
    case .Metadata:{0}case .Overflow:{0}case .Quota:{0}case .Bounds:{0}case .Alignment:{0}};}
fn bool value_error(owners::Error e){return error_kind(e)==2;}
fn bool state_error(owners::Error e){return error_kind(e)==1;}
fn Result<bytes::Buffer,owners::Error> backing(usize size){
    var bytes::Buffer b=switch(bytes::with_capacity(size)){case .ok(v):{v}case .err(_):{return .err(.Quota);}};
    if(!bytes::resize_zeroed(ref mut b,size).is_ok){return .err(.Quota);}return .ok(b);
}
fn records::Catalog catalog(){var records::Catalog c=records::empty();c.count=2;c.fields[0]=3;c.fields[1]=3;
    c.types[0]=2;c.kinds[1]=1;c.types[1]=1;c.types[2]=10;c.types[16]=2;c.types[17]=9;c.types[18]=10;return c;}
fn Result<usize,owners::Error> parity(ref mut owners::Table t,ref records::Catalog c,
    ref owners::CallArgument[] args,ref mut u8[] data,usize allowance){
    assert(data.len<=512);var u8[512] expected=[0;512];var u8[512] old=[0;512];var usize i=0;
    while(i<data.len){expected[i]=data[i];old[i]=data[i];i+=1;}let owners::Table before=*t;var owners::Table oracle=*t;
    let owners::Copies wanted=owners::copy_call_arguments(c,args,ref mut expected[..data.len],ref mut oracle)?;
    var cursor::State s=begin(t,c,args,data.len)?;assert(s.written==0 && s.total==0 && s.last==0 && s.count==args.len);
    same_table(ref before,t);var usize calls=0;
    while(s.active){assert(calls<1024);calls+=1;if(s.last==4096){s.last=0;}
        let usize room=4096-s.last;let usize budget=if(allowance<room){allowance}else{room};
        let usize total=s.total;let usize last=s.last;let usize written=s.written;
        let Option<owners::Copies> r=advance(ref mut s,t,c,args,data,budget)?;
        assert(s.total>total && s.total-total<=budget && s.last==last+s.total-total && s.written>=written);
        i=0;while(i<data.len){assert(data[i]==if(i>=s.mark && i-s.mark<s.written){expected[i]}else{old[i]});i+=1;}
        if(s.active){pending(r);same_table(ref before,t);}else{let owners::Copies actual=completed(r)?;same_copies(ref actual,ref wanted);}
    }
    assert(s.written==s.end-s.mark);same_table(t,ref oracle);assert(bytes::equal(data,ref expected[..data.len]));return .ok(0);
}

// 1: six scalar domains, signed/unsigned edges, nested bools, dirty record
// padding and repeated mixed sources agree with the already-atomic oracle.
fn Result<usize,owners::Error> atomic_parity(){
    let u8[6] tags=[1,2,9,10,11,12];let usize[2] budgets=[1,7];var usize q=0;
    while(q<2){var u8[512] data=[85;512];var owners::Table t=owners::empty(512);let records::Catalog empty=records::empty();
        let owners::Token none=owners::Token{.slot=16,.generation=0};let owners::CallArgument blank=arg(none,10,1);
        var owners::CallArgument[6] args=[blank;6];var usize k=0;
        while(k<6){let arrays::Array layout=shape(tags[k],3)?;
            let i64[3] values=if(k==0){[-2147483648,2147483647,-1]}else if(k==1){[0,1,0]}
                else if(k==2){[-9223372036854775808,9223372036854775807,-1]}else if(k==3){[0,255,128]}
                else if(k==4){[0,4294967295,2147483648]}else{[-1,-9223372036854775808,9223372036854775807]};
            let owners::Token source=owners::create(ref layout,0,ref mut data,ref mut t)?;var usize i=0;
            while(i<3){let usize n=owners::write(ref t,source,i,values[i],ref mut data)?;i+=1;}args[k]=arg(source,tags[k],3);k+=1;}
        let usize n=parity(ref mut t,ref empty,ref args,ref mut data,budgets[q])?;
        let records::Catalog c=catalog();var u8[256] mixed=[85;256];var owners::Table ledger=owners::empty(256);
        let arrays::Array boolean=shape(2,3)?;let owners::Token a=owners::create(ref boolean,1,ref mut mixed,ref mut ledger)?;
        let i64[5] fields=[1,0,-9223372036854775808,255,128];
        let owners::Token r=owners::create_record(ref c,0,ref fields,ref mut mixed,ref mut ledger)?;
        let usize base=ledger.slots[r.slot].base;mixed[base+1]=77;mixed[base+9]=77;mixed[base+25]=77;mixed[base+33]=77;
        let owners::CallArgument[4] repeated=[arg(a,2,3),arg(r,0,0),arg(a,2,3),arg(r,0,0)];
        let usize m=parity(ref mut ledger,ref c,ref repeated,ref mut mixed,budgets[q])?;q+=1;
    }return .ok(0);
}

// 2: eight maximum i64 sources plus eight destinations fit 524288 bytes.
// Exact shared batches: 64 wide copies, or 8 bool scans followed by 8 copies.
fn Result<usize,owners::Error> maximum_batches(){
    var usize domain=0;while(domain<2){let u8 tag=if(domain==0){9}else{2};let usize size=if(domain==0){524288}else{65536};
        let usize copied=size/2;let usize scans=if(domain==0){0}else{8};let usize batches=if(domain==0){64}else{16};
        let arrays::Array layout=shape(tag,4096)?;let records::Catalog c=records::empty();var bytes::Buffer data=backing(size)?;
        var bytes::Buffer expected=backing(size)?;var owners::Table t=owners::empty(size);
        let owners::Token none=owners::Token{.slot=16,.generation=0};let owners::CallArgument blank=arg(none,tag,4096);
        var owners::CallArgument[8] args=[blank;8];var usize i=0;
        while(i<8){let i64 value=if(domain==0){-1}else{1};
            let owners::Token source=owners::create(ref layout,value,bytes::view_mut(ref mut data),ref mut t)?;args[i]=arg(source,tag,4096);i+=1;}
        {let ref u8[] original=bytes::view(ref data);let ref mut u8[] target=bytes::view_mut(ref mut expected);
            i=0;while(i<size){target[i]=original[i];i+=1;}}
        let owners::Table before=t;var owners::Table oracle=t;
        let owners::Copies wanted=owners::copy_call_arguments(ref c,ref args,bytes::view_mut(ref mut expected),ref mut oracle)?;
        var cursor::State s=begin(ref t,ref c,ref args,size)?;assert(s.total==0 && s.written==0);var usize batch=0;
        while(batch<batches){s.last=0;let Option<owners::Copies> result=advance(ref mut s,ref mut t,ref c,ref args,bytes::view_mut(ref mut data),4096)?;
            batch+=1;let usize written=if(batch<=scans){0}else{(batch-scans)*4096};
            assert(s.last==4096 && s.total==batch*4096 && s.written==written);
            {let ref u8[] actual=bytes::view(ref data);let ref u8[] want=bytes::view(ref expected);i=0;
                while(i<size){assert(actual[i]==if(i<copied+written){want[i]}else{0});i+=1;}}
            if(batch<batches){assert(s.active);pending(result);same_table(ref before,ref t);}
            else{assert(!s.active);let owners::Copies actual=completed(result)?;same_copies(ref actual,ref wanted);}
        }
        assert(s.written==copied);same_table(ref t,ref oracle);assert(bytes::equal(bytes::view(ref data),bytes::view(ref expected)));domain+=1;
    }return .ok(0);
}

// 3: even a bad final bool leaves every destination/padding byte untouched.
// Earlier invalid bool beats later owner pressure; Value poisons retries.
fn Result<usize,owners::Error> late_failure_and_priority(){
    let arrays::Array boolean=shape(2,3)?;let arrays::Array byte=shape(10,1)?;let arrays::Array wide=shape(9,1)?;
    var usize mode=0;while(mode<3){let records::Catalog c=if(mode==2){catalog()}else{records::empty()};
        var u8[128] data=[85;128];var owners::Table t=owners::empty(128);
        let owners::Token a=owners::create(ref boolean,1,ref mut data,ref mut t)?;
        var owners::Token b=a;
        if(mode==0){b=owners::create(ref wide,-1,ref mut data,ref mut t)?;}
        else if(mode==1){var usize i=0;while(i<14){let owners::Token filler=owners::create(ref byte,7,ref mut data,ref mut t)?;i+=1;}}
        else{let i64[5] fields=[1,1,-1,255,128];b=owners::create_record(ref c,0,ref fields,ref mut data,ref mut t)?;}
        let owners::CallArgument[2] args=if(mode==0){[arg(b,9,1),arg(a,2,3)]}
            else if(mode==1){[arg(a,2,3),arg(a,2,3)]}else{[arg(a,2,3),arg(b,0,0)]};
        let usize bad=if(mode==2){t.slots[b.slot].base+8}else{2};let usize reads=if(mode==2){5}else{3};
        data[bad]=2;let u8[128] old=data;let owners::Table before=t;var owners::Table oracle=t;var u8[128] expected=data;
        switch(owners::copy_call_arguments(ref c,ref args,ref mut expected,ref mut oracle)){
            case .ok(_):{assert(false);}case .err(e):{assert(value_error(e));}};
        same_table(ref before,ref oracle);assert(bytes::equal(ref old,ref expected));
        var cursor::State s=begin(ref t,ref c,ref args,128)?;var bool failed=false;var usize calls=0;
        while(!failed && calls<8){calls+=1;switch(advance(ref mut s,ref mut t,ref c,ref args,ref mut data,1)){
            case .ok(v):{pending(v);}case .err(e):{assert(value_error(e));failed=true;}};
            assert(s.written==0 && bytes::equal(ref data,ref old));same_table(ref before,ref t);}
        assert(failed && !s.active && s.total==reads && s.last==reads);data[bad]=1;let u8[128] repaired=data;let cursor::State poisoned=s;
        let usize room=4096-s.last;
        switch(advance(ref mut s,ref mut t,ref c,ref args,ref mut data,room)){
            case .ok(_):{assert(false);}case .err(e):{assert(state_error(e));}};
        same_cursor(ref poisoned,ref s);same_table(ref before,ref t);assert(bytes::equal(ref repaired,ref data));mode+=1;
    }return .ok(0);
}

// 4: reauthenticate chunks in validation AND copying, with no further touch on
// stale catalog/source/shape/reservation, overflow, backing or shared-budget faults.
fn Result<usize,owners::Error> resume_rejections(){
    let arrays::Array boolean=shape(2,3)?;var usize stage=0;while(stage<2){var usize fault=0;while(fault<13){
        var records::Catalog c=catalog();var u8[128] data=[85;128];var owners::Table t=owners::empty(128);
        let owners::Token source=owners::create(ref boolean,1,ref mut data,ref mut t)?;
        let i64[5] fields=[1,0,-1,255,128];
        let owners::Token record=owners::create_record(ref c,0,ref fields,ref mut data,ref mut t)?;
        var owners::CallArgument[2] args=[arg(source,2,3),arg(record,0,0)];var cursor::State s=begin(ref t,ref c,ref args,128)?;
        pending(advance(ref mut s,ref mut t,ref c,ref args,ref mut data,1)?);
        if(stage==1){var usize calls=0;while(s.written==0){assert(calls<8);calls+=1;
            pending(advance(ref mut s,ref mut t,ref c,ref args,ref mut data,1)?);}assert(s.written==1);}
        else{assert(s.written==0 && s.total==1);}var usize allowance=1;var usize capacity=128;
        if(fault==0){var owners::Owner changed=t.slots[source.slot];changed.generation+=1;t.slots[source.slot]=changed;}else if(fault==1){c.types[511]=2;}
        else if(fault==2){args[0]=arg(source,2,2);}else if(fault==3){var owners::Owner changed=t.slots[2];changed.generation+=1;t.slots[2]=changed;}
        else if(fault==4){t.arena.limit=95;}else if(fault==5){t.depth+=1;}
        else if(fault==6){var owners::Owner changed=t.slots[source.slot];changed.writing=true;t.slots[source.slot]=changed;}else if(fault==7){s.total=18446744073709551615;}
        else if(fault==8){allowance=0;}else if(fault==9){allowance=4097;}
        else if(fault==10){s.last=4095;allowance=2;}else if(fault==11){s.end+=1;}else{capacity=5;}
        let u8[128] old=data;let owners::Table before=t;let cursor::State saved=s;
        assert(!advance(ref mut s,ref mut t,ref c,ref args,ref mut data[..capacity],allowance).is_ok);
        same_cursor(ref saved,ref s);same_table(ref before,ref t);assert(bytes::equal(ref old,ref data));fault+=1;
    }stage+=1;}
    // Structurally valid equal-shape range permutation must still fail State.
    let arrays::Array byte=shape(10,3)?;let records::Catalog c=records::empty();var u8[32] data=[85;32];var owners::Table t=owners::empty(32);
    let owners::Token a=owners::create(ref byte,7,ref mut data,ref mut t)?;let owners::Token b=owners::create(ref byte,9,ref mut data,ref mut t)?;
    let owners::CallArgument[1] args=[arg(a,10,3)];var cursor::State s=begin(ref t,ref c,ref args,32)?;
    pending(advance(ref mut s,ref mut t,ref c,ref args,ref mut data,1)?);assert(s.written==1);
    let owners::Owner first=t.slots[a.slot];let owners::Owner second=t.slots[b.slot];
    t.order[0]=b.slot;t.order[1]=a.slot;
    var owners::Owner moved_first=first;moved_first.mark=second.mark;moved_first.base=second.base;moved_first.end=second.end;
    var owners::Owner moved_second=second;moved_second.mark=first.mark;moved_second.base=first.base;moved_second.end=first.end;
    t.slots[a.slot]=moved_first;t.slots[b.slot]=moved_second;
    assert(owners::read(ref t,a,0,ref data)?==9 && owners::read(ref t,b,0,ref data)?==7);
    let owners::Table before=t;let cursor::State saved=s;let u8[32] old=data;
    switch(advance(ref mut s,ref mut t,ref c,ref args,ref mut data,1)){
        case .ok(_):{assert(false);}case .err(e):{assert(state_error(e));}};
    same_cursor(ref saved,ref s);same_table(ref before,ref t);assert(bytes::equal(ref old,ref data));return .ok(0);
}

// 5: seven padding bytes consume the shared batch; finishing argument zero
// never publishes a partial batch. Dropping a cursor abandons only spare bytes.
fn Result<usize,owners::Error> padding_empty_and_cancellation(){
    let arrays::Array wide=shape(9,1)?;let arrays::Array byte=shape(10,1)?;let records::Catalog c=records::empty();
    var u8[64] data=[85;64];var owners::Table t=owners::empty(64);
    let owners::Token source=owners::create(ref wide,-1,ref mut data,ref mut t)?;
    let owners::Token tail=owners::create(ref byte,42,ref mut data,ref mut t)?;
    let owners::CallArgument[2] args=[arg(source,9,1),arg(source,9,1)];let owners::Table before=t;
    let owners::CallArgument first=args[0];let owners::CallArgument[9] too_many=[first;9];
    let u8[64] initial=data;
    assert(!begin(ref t,ref c,ref too_many,64).is_ok);
    same_table(ref before,ref t);assert(bytes::equal(ref data,ref initial));
    var owners::Table oracle=t;var u8[64] expected=data;
    let owners::Copies wanted=owners::copy_call_arguments(ref c,ref args,ref mut expected,ref mut oracle)?;
    {var cursor::State cancelled=begin(ref t,ref c,ref args,64)?;
        pending(advance(ref mut cancelled,ref mut t,ref c,ref args,ref mut data,1)?);assert(cancelled.written==1);}
    same_table(ref before,ref t);assert(data[9]==0 && data[10]==85 && owners::read(ref t,tail,0,ref data)?==42);
    var cursor::State s=begin(ref t,ref c,ref args,64)?;assert(s.mark==9 && s.end==32);s.total=5000;s.last=4089;
    pending(advance(ref mut s,ref mut t,ref c,ref args,ref mut data,7)?);
    assert(s.written==7 && s.total==5007 && s.last==4096);same_table(ref before,ref t);
    let cursor::State saved=s;let u8[64] old=data;assert(!advance(ref mut s,ref mut t,ref c,ref args,ref mut data,1).is_ok);
    same_cursor(ref saved,ref s);same_table(ref before,ref t);assert(bytes::equal(ref old,ref data));s.last=0;
    pending(advance(ref mut s,ref mut t,ref c,ref args,ref mut data,8)?);
    assert(s.written==15 && s.index==1 && data[23]==255 && data[24]==85);same_table(ref before,ref t);
    pending(advance(ref mut s,ref mut t,ref c,ref args,ref mut data,7)?);
    assert(s.written==22 && data[30]==255 && data[31]==85);same_table(ref before,ref t);
    let owners::Copies actual=completed(advance(ref mut s,ref mut t,ref c,ref args,ref mut data,1)?)?;
    assert(!s.active && s.written==23 && s.total==5023 && s.last==16);same_copies(ref actual,ref wanted);
    same_table(ref t,ref oracle);assert(bytes::equal(ref data,ref expected));
    let owners::Table published=t;let u8[64] final_bytes=data;s=begin(ref t,ref c,ref args[..0],64)?;
    assert(!s.active && s.count==0 && s.written==0 && s.total==0);let cursor::State empty=s;
    let owners::Copies zero=completed(advance(ref mut s,ref mut t,ref c,ref args[..0],ref mut data,1)?)?;
    assert(zero.count==0);same_cursor(ref empty,ref s);same_table(ref published,ref t);assert(bytes::equal(ref data,ref final_bytes));return .ok(0);
}

pub fn void run(){let Heap before=heap();
    assert(atomic_parity().is_ok);same_heap(ref before);
    assert(maximum_batches().is_ok);same_heap(ref before);
    assert(late_failure_and_priority().is_ok);same_heap(ref before);
    assert(resume_rejections().is_ok);same_heap(ref before);
    assert(padding_empty_and_cancellation().is_ok);same_heap(ref before);
}
