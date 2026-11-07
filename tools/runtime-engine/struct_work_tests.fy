module struct_work_tests;
import struct_work as work;
import array_fill_cursor as cursor;
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
fn owners::Token unused(){return owners::Token{.slot=16,.generation=0};}
fn void same_token(owners::Token a,owners::Token b){assert(a.slot==b.slot && a.generation==b.generation);}
fn void same_table(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);var usize i=0;
    while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(x.generation==y.generation && x.occupied==y.occupied && x.live==y.live && x.read_generation==y.read_generation);
        assert(x.reading==y.reading && x.writing==y.writing && x.mark==y.mark && x.base==y.base && x.end==y.end);
        assert(x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment && a.order[i]==b.order[i]);i+=1;}
}
fn void same_cursor(ref cursor::State a,ref cursor::State b){
    assert(a.active==b.active && a.op==b.op && a.pc==b.pc && a.frame==b.frame && a.destination==b.destination && a.offset==b.offset);
    assert(a.slot==b.slot && a.generation==b.generation && a.mark==b.mark && a.base==b.base && a.end==b.end && a.depth==b.depth);
    assert(a.source_slot==b.source_slot && a.source_generation==b.source_generation && a.source_base==b.source_base && a.source_end==b.source_end);
    assert(a.element==b.element && a.length==b.length && a.stride==b.stride && a.written==b.written && a.total==b.total && a.last==b.last);
    assert(a.list_gathered==b.list_gathered && a.list_encoded==b.list_encoded);
    assert(a.record==b.record && a.nominal==b.nominal && a.ordinal==b.ordinal && a.source_record==b.source_record && a.source_ordinal==b.source_ordinal);
    var usize i=0;while(i<128){assert(a.record_encoded[i]==b.record_encoded[i]);if(i<8){assert(a.encoded[i]==b.encoded[i]);}i+=1;}
}
fn Result<usize,owners::Error> measure(ref records::Catalog c,usize nominal,bool fields){
    let Heap h=heap();let Result<usize,owners::Error> r=work::measure(c,nominal,fields);no_allocation(ref h);return r;
}
fn Result<cursor::State,owners::Error> begin(ref records::Catalog c,ref owners::Table t,u8 op,usize nominal,
    owners::Token target,owners::Token source,usize ordinal,usize source_ordinal,ref i64[] fields,ref u8[] data){
    let Heap h=heap();let Result<cursor::State,owners::Error> r=work::begin(c,t,op,nominal,target,source,ordinal,source_ordinal,fields,data);
    no_allocation(ref h);return r;
}
fn Result<Option<owners::Token>,owners::Error> advance(ref mut cursor::State s,ref records::Catalog c,
    ref mut owners::Table t,ref mut u8[] data,usize allowance){
    let Heap h=heap();let Result<Option<owners::Token>,owners::Error> r=work::advance(s,c,t,data,allowance);no_allocation(ref h);return r;
}
fn void pending(Option<owners::Token> r){switch(r){case .none:{}case .some(_):{assert(false);}};}
fn Result<owners::Token,owners::Error> completed(Option<owners::Token> r){return switch(r){case .some(t):{.ok(t)}case .none:{.err(.State)}};}
fn records::Catalog catalog(){
    var records::Catalog c=records::empty();c.count=3;c.fields[0]=3;c.types[0]=10;
    c.kinds[1]=1;c.types[1]=1;c.kinds[2]=1;c.types[2]=1;
    let u8[6] tags=[2,10,1,9,11,12];var usize i=0;c.fields[1]=6;c.fields[2]=6;
    while(i<6){c.types[16+i]=tags[i];c.types[32+i]=tags[i];i+=1;}return c;
}
fn arrays::Array byte(){return arrays::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1};}
fn void dirty(usize base,ref mut u8[] data){data[base+1]=85;data[base+10]=85;data[base+28]=85;data[base+42]=85;data[base+60]=85;}
// Each committed prefix matches the atomic oracle; all other bytes and every
// unpublished descriptor stay untouched, including CREATE/COPY alignment holes.
fn Result<owners::Token,owners::Error> drain(ref mut cursor::State s,ref records::Catalog c,ref mut owners::Table t,
    ref mut u8[] data,ref u8[] expected,usize selected_offset,usize allowance){
    assert(data.len<=512 && data.len==expected.len);var u8[512] old=[0;512];var usize i=0;
    while(i<data.len){old[i]=data[i];i+=1;}let owners::Table before=*t;let usize staged=s.total;
    let bool fresh=s.op==41 || s.op==42;let usize start=if(fresh){s.mark}else{s.base+selected_offset};var usize calls=0;
    while(s.active){assert(calls<136);s.last=0;let usize previous=s.total;
        let Option<owners::Token> r=advance(s,c,t,data,allowance)?;calls+=1;
        assert(s.last>0 && s.last<=allowance && s.total==previous+s.last && s.total==staged+s.written);
        i=0;while(i<data.len){assert(data[i]==if(i>=start && i-start<s.written){expected[i]}else{old[i]});i+=1;}
        if(s.active){pending(r);same_table(ref before,t);}else{if(!fresh){same_table(ref before,t);}return completed(r);}
    }return .err(.State);
}

// 1: all six operations, six scalar domains, nested ordinals and exact staging.
fn Result<usize,owners::Error> atomic_parity(){
    let records::Catalog c=catalog();let arrays::Array b=byte();let u8[6] ops=[41,42,46,47,48,49];let usize[2] budgets=[1,7];
    let i64[13] fields=[17,0,0,-2147483648,-9223372036854775808,0,-1,1,255,2147483647,9223372036854775807,4294967295,-9223372036854775808];
    let i64[13] zero=[0;13];assert(measure(ref c,0,true)?==229 && measure(ref c,0,false)?==127);
    assert(measure(ref c,1,true)?==106 && measure(ref c,1,false)?==59);
    var usize k=0;while(k<6){var usize q=0;while(q<2){let u8 op=ops[k];var u8[256] data=[85;256];var owners::Table t=owners::empty(256);
        let owners::Token head=owners::create(ref b,9,ref mut data,ref mut t)?;
        let owners::Token source=owners::create_record(ref c,0,ref fields,ref mut data,ref mut t)?;
        let usize source_base=t.slots[source.slot].base;dirty(source_base,ref mut data);
        let owners::Token guard=owners::create(ref b,19,ref mut data,ref mut t)?;var owners::Token target=unused();
        if(k>=2){target=owners::create_record(ref c,0,ref zero,ref mut data,ref mut t)?;let usize base=t.slots[target.slot].base;dirty(base,ref mut data);}
        let owners::Table before=t;let u8[256] old=data;var u8[256] expected=data;var owners::Table oracle=t;var owners::Token wanted=target;
        if(op==41){wanted=owners::create_record(ref c,0,ref fields,ref mut expected,ref mut oracle)?;}
        else if(op==42){wanted=owners::copy_record(ref c,source,ref mut expected,ref mut oracle)?;}
        else if(op==46){let usize n=owners::assign_record(ref c,target,source,ref mut expected,ref oracle)?;assert(n==72);}
        else if(op==47){let usize n=owners::assign_subrecord(ref c,target,source,1,1,7,ref mut expected,ref oracle)?;assert(n==32);}
        else if(op==48){let usize n=owners::replace_record(ref c,target,0,ref fields,ref mut expected,ref oracle)?;assert(n==72);}
        else{let usize n=owners::replace_subrecord(ref c,target,1,7,ref fields[7..13],ref mut expected,ref oracle)?;assert(n==32);}
        let bool sub=op==47 || op==49;let usize nominal=if(sub){1}else{0};let usize ordinal=if(op==47){1}else if(op==49){7}else{0};
        let usize source_ordinal=if(op==47){7}else{0};let bool constructor=op==41 || op==48 || op==49;
        let usize first=if(op==49){7}else{0};let usize arity=if(op==49){6}else if(constructor){13}else{0};
        let usize cost=measure(ref c,nominal,constructor)?;
        var cursor::State s=begin(ref c,ref t,op,nominal,target,source,ordinal,source_ordinal,ref fields[first..first+arity],ref data)?;
        assert(s.active && s.written==0 && s.total==cost && s.last==cost && cost<=1280);
        same_table(ref before,ref t);assert(bytes::equal(ref data,ref old));
        let usize selected_offset=if(op==47){8}else if(op==49){40}else{0};
        let owners::Token result=drain(ref mut s,ref c,ref mut t,ref mut data,ref expected,selected_offset,budgets[q])?;
        same_token(result,wanted);same_table(ref t,ref oracle);assert(bytes::equal(ref data,ref expected));
        assert(owners::read(ref t,head,0,ref data)?==9 && owners::read(ref t,guard,0,ref data)?==19);q+=1;
    }k+=1;}return .ok(0);
}

// 2: exact identity still rewrites padding; same-owner sibling/identity ranges
// use a full snapshot and retain the root token, generation and neighbors.
fn Result<usize,owners::Error> self_and_overlap(){
    let records::Catalog c=catalog();let i64[13] fields=[17,0,0,0,0,0,0,1,255,-1,-9223372036854775808,4294967295,-1];
    var usize k=0;while(k<3){var u8[96] data=[85;96];var owners::Table t=owners::empty(96);
        let owners::Token target=owners::create_record(ref c,0,ref fields,ref mut data,ref mut t)?;dirty(0,ref mut data);
        let owners::Table before=t;var owners::Table oracle=t;var u8[96] expected=data;
        let u8 op=if(k==0){46}else{47};let usize nominal=if(k==0){0}else{1};let usize ordinal=if(k==0){0}else{1};let usize origin=if(k==1){7}else{ordinal};
        if(k==0){let usize n=owners::assign_record(ref c,target,target,ref mut expected,ref oracle)?;assert(n==72);}
        else{let usize n=owners::assign_subrecord(ref c,target,target,1,ordinal,origin,ref mut expected,ref oracle)?;assert(n==32);}
        var cursor::State s=begin(ref c,ref t,op,nominal,target,target,ordinal,origin,ref fields[..0],ref data)?;
        assert(s.active && s.written==0);s.total+=37;s.last+=5;
        let usize selected_offset=if(k==0){0}else{8};
        let owners::Token result=drain(ref mut s,ref c,ref mut t,ref mut data,ref expected,selected_offset,1)?;
        assert(s.written==if(k==0){72}else{32});same_token(result,target);same_table(ref before,ref t);
        assert(bytes::equal(ref data,ref expected));k+=1;
    }return .ok(0);
}

// 3: invalid fields/source bools fail in begin, before padding or payload writes.
fn Result<usize,owners::Error> admission_rejections(){
    var records::Catalog c=catalog();let u8[6] ops=[41,42,46,47,48,49];let i64[13] valid=[17,0,0,0,0,0,0,1,255,-1,-1,4294967295,-1];
    var u8[256] data=[85;256];var owners::Table t=owners::empty(256);
    let owners::Token source=owners::create_record(ref c,0,ref valid,ref mut data,ref mut t)?;
    let owners::Token target=owners::create_record(ref c,0,ref valid,ref mut data,ref mut t)?;
    let owners::Table before=t;var i64[13] bad=valid;bad[7]=2;var usize k=0;
    while(k<6){let u8 op=ops[k];let bool constructor=op==41 || op==48 || op==49;
        let bool sub=op==47 || op==49;let usize nominal=if(sub){1}else{0};let usize ordinal=if(sub){7}else{0};
        data[40]=if(constructor){1}else{2};let u8[256] old=data;
        let usize first=if(op==49){7}else{0};let usize arity=if(op==49){6}else if(constructor){13}else{0};let usize origin=if(op==47){7}else{0};
        assert(!begin(ref c,ref t,op,nominal,target,source,ordinal,origin,ref bad[first..first+arity],ref data).is_ok);
        same_table(ref before,ref t);assert(bytes::equal(ref data,ref old));k+=1;
    }data[40]=1;let u8[256] old=data;
    assert(!begin(ref c,ref t,41,0,unused(),unused(),0,0,ref valid[..12],ref data).is_ok);
    assert(!begin(ref c,ref t,47,2,target,source,1,1,ref valid[..0],ref data).is_ok);
    assert(!begin(ref c,ref t,47,1,target,source,2,7,ref valid[..0],ref data).is_ok);
    assert(!begin(ref c,ref t,49,1,target,unused(),128,0,ref valid[7..13],ref data).is_ok);
    let owners::Token stale=owners::Token{.slot=source.slot,.generation=source.generation+1};
    assert(!begin(ref c,ref t,42,0,unused(),stale,0,0,ref valid[..0],ref data).is_ok);
    var owners::Table limited=t;limited.arena.limit=144;
    assert(!begin(ref c,ref limited,41,0,unused(),unused(),0,0,ref valid,ref data).is_ok);
    assert(!begin(ref c,ref limited,42,0,unused(),source,0,0,ref valid[..0],ref data).is_ok);
    c.types[511]=2;assert(!measure(ref c,0,true).is_ok);assert(!begin(ref c,ref t,48,0,target,unused(),0,0,ref valid,ref data).is_ok);
    same_table(ref before,ref t);assert(bytes::equal(ref data,ref old));return .ok(0);
}

// 4: reauthenticate after a committed byte. Focused faults cover both source and
// destination, catalog/shape/depth/loans/quota, counters and the shared 4096 cap.
fn Result<usize,owners::Error> resume_rejections(){
    let u8[6] ops=[41,42,46,47,48,49];let i64[13] fields=[0;13];var usize k=0;
    while(k<6){var usize fault=0;while(fault<13){var records::Catalog c=catalog();var u8[256] data=[85;256];var owners::Table t=owners::empty(256);
        let owners::Token source=owners::create_record(ref c,0,ref fields,ref mut data,ref mut t)?;
        let owners::Token target=owners::create_record(ref c,0,ref fields,ref mut data,ref mut t)?;
        let u8 op=ops[k];let bool sub=op==47 || op==49;let usize nominal=if(sub){1}else{0};let usize ordinal=if(sub){1}else{0};
        let bool constructor=op==41 || op==48 || op==49;
        let usize first=if(op==49){1}else{0};let usize arity=if(op==49){6}else if(constructor){13}else{0};let usize origin=if(op==47){1}else{0};
        var cursor::State s=begin(ref c,ref t,op,nominal,target,source,ordinal,origin,ref fields[first..first+arity],ref data)?;s.last=0;
        pending(advance(ref mut s,ref c,ref mut t,ref mut data,1)?);assert(s.written==1);s.last=0;var usize allowance=1;
        let usize slot=if(op==42 || op==46 || op==47){source.slot}else{s.slot};
        if(fault==0){t.slots[slot].generation+=1;}else if(fault==1){t.depth+=1;}
        else if(fault==2){c.types[511]=2;}else if(fault==3){s.length+=1;}
        else if(fault==4){t.slots[slot].reading=true;}else if(fault==5){t.arena.limit=1;}
        else if(fault==6){s.total=18446744073709551615;}else if(fault==7){allowance=0;}
        else if(fault==8){allowance=4097;}else if(fault==9){s.last=4096;}
        else if(fault==10){s.nominal=2;}else if(fault==11){s.depth+=1;}else{t.slots[s.slot].generation+=1;}
        let owners::Table before=t;let cursor::State saved=s;let u8[256] old=data;
        assert(!advance(ref mut s,ref c,ref mut t,ref mut data,allowance).is_ok);
        same_table(ref before,ref t);same_cursor(ref saved,ref s);assert(bytes::equal(ref data,ref old));fault+=1;
    }k+=1;}return .ok(0);
}

// 5: 128 nested bool leaves attain 1280/384 staging exactly; depth sixteen i64
// keeps signed edges. Every begin/advance is allocation-free, even cancellation.
fn Result<usize,owners::Error> maximum_and_depth(){
    var usize domain=0;while(domain<2){var records::Catalog c=records::empty();var usize i=0;
        if(domain==0){c.count=2;c.fields[0]=8;c.fields[1]=16;
            while(i<16){c.types[16+i]=2;if(i<8){c.kinds[i]=1;c.types[i]=1;}i+=1;}}
        else{c.count=16;var u8 child=1;while(i<16){c.fields[i]=1;
            if(i<15){c.kinds[i*16]=1;c.types[i*16]=child;}else{c.types[i*16]=9;}i+=1;child+=1;}}
        let usize count=if(domain==0){128}else{1};let usize size=if(domain==0){128}else{8};
        let usize ctor=if(domain==0){1280}else{24};let usize copy=if(domain==0){384}else{16};
        assert(measure(ref c,0,true)?==ctor && measure(ref c,0,false)?==copy);
        let i64[128] fields=if(domain==0){[1;128]}else{[-9223372036854775808;128]};
        var u8[256] data=[85;256];var owners::Table t=owners::empty(256);var usize operation=0;var owners::Token source=unused();
        while(operation<2){let u8 op=if(operation==0){41}else{42};let usize staging=if(operation==0){ctor}else{copy};
            let owners::Table before=t;var owners::Table oracle=t;let u8[256] old=data;var u8[256] expected=data;
            let owners::Token wanted=if(operation==0){owners::create_record(ref c,0,ref fields[..count],ref mut expected,ref mut oracle)?}
                else{owners::copy_record(ref c,source,ref mut expected,ref mut oracle)?};
            let usize arity=if(operation==0){count}else{0};
            var cursor::State s=begin(ref c,ref t,op,0,unused(),source,0,0,ref fields[..arity],ref data)?;
            assert(s.total==staging && s.last==staging && s.written==0);same_table(ref before,ref t);assert(bytes::equal(ref data,ref old));
            let cursor::State saved=s;assert(!advance(ref mut s,ref c,ref mut t,ref mut data,4096-staging+1).is_ok);
            same_cursor(ref saved,ref s);same_table(ref before,ref t);assert(bytes::equal(ref data,ref old));
            let owners::Token result=drain(ref mut s,ref c,ref mut t,ref mut data,ref expected,0,7)?;
            assert(s.total==staging+size && s.written==size);same_token(result,wanted);same_table(ref t,ref oracle);
            assert(bytes::equal(ref data,ref expected));source=result;operation+=1;
        }
        if(domain==0){c.fields[0]=16;i=8;while(i<16){c.kinds[i]=1;c.types[i]=1;i+=1;}assert(!measure(ref c,0,true).is_ok);}
        else{let usize[16] path=[0;16];assert(owners::read_record(ref c,ref t,source,ref path,ref data)?==-9223372036854775808);
            c.count=17;c.kinds[240]=1;c.types[240]=16;c.fields[16]=1;c.types[256]=9;assert(!measure(ref c,0,false).is_ok);}
        assert(!measure(ref c,32,true).is_ok);domain+=1;
    }return .ok(0);
}

pub fn void run(){
    let Heap before=heap();
    assert(atomic_parity().is_ok);same_heap(ref before);
    assert(self_and_overlap().is_ok);same_heap(ref before);
    assert(admission_rejections().is_ok);same_heap(ref before);
    assert(resume_rejections().is_ok);same_heap(ref before);
    assert(maximum_and_depth().is_ok);same_heap(ref before);
}
