module grow_resize;
import std::bytes as bytes;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_replacement as tx;
import buffer_close as close;

fn growth::Limits limits(bool minimum) {
    return growth::Limits{.object=4096,.instance=if(minimum){704}else{8192},.engine=if(minimum){736}else{8192}};
}
fn bytes::Buffer take(Result<bytes::Buffer,tx::Error> r) {
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
}
fn void failed(Result<bytes::Buffer,tx::Error> r,u8 expected) {
    assert(switch(r){case .ok(_):{false}case .err(e):{switch(e){
        case .Token:{expected==1}case .Owners:{expected==2}case .State:{expected==3}
        case .Overflow:{expected==4}case .Quota:{expected==5}case .NoGrowth:{expected==6}
        case .Allocation:{expected==7}case .Provider:{expected==8}}}});
}
fn void kept(ref owners::Table table,owners::Token source,ref bytes::Buffer b,bool truncated) {
    assert(bytes::capacity(b)==256);
    if(truncated){assert(bytes::equal(bytes::view(b),b"ke"));}else{assert(bytes::equal(bytes::view(b),b"keep"));}
    assert(switch(owners::read(table,source,0,b)){case .ok(v):{v==107}case .err(_):{false}});
}
fn void zeros(ref bytes::Buffer b,usize first,usize length) {
    let ref u8[] view=bytes::view(b);var usize i=first;
    while(i<length){assert(view[i]==0);i+=1;}
    assert(view[0]==107 && view[1]==101);
    if(first==4){assert(view[2]==101 && view[3]==112);}
}
fn void same_table(ref owners::Table a,ref owners::Table b) {
    var usize i=0;while(i<16){
        assert(a.slots[i].generation==b.slots[i].generation && a.slots[i].live==b.slots[i].live &&
            a.slots[i].length==b.slots[i].length && a.slots[i].capacity==b.slots[i].capacity);i+=1;
    }
}
pub fn void run(u8 mode) {
    let bool minimum=mode==1 || mode==2;let bool oom=mode==2 || mode==3;let bool truncated=mode==5;
    var growth::Ledger l=growth::empty();var bytes::Buffer b=bytes::empty();
    b=switch(storage::prepare_growth(ref b,256,limits(false),ref mut l)) {
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    switch(growth::commit(256,ref mut l)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(ref mut b,b"keep")){case .ok(_):{}case .err(_):{assert(false);}};
    if(truncated){switch(bytes::truncate(ref mut b,2)){case .ok(_):{}case .err(_):{assert(false);}};}
    l.engine_used+=32;l.engine_peak+=32;
    var owners::Table table=owners::empty();table.slots[15].generation=7;
    let owners::Token old=switch(owners::create(ref mut table,ref b)) {
        case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}
    };
    let owners::Table before=owners::Table{.slots=table.slots};var tx::Plan plan=tx::empty();
    if(mode==6) {
        failed(tx::prepare_resize(ref table,old,ref b,0,limits(false),ref mut l,ref mut plan),6);
        failed(tx::prepare_resize(ref table,old,ref b,256,limits(false),ref mut l,ref mut plan),6);
        let bytes::Buffer missing=bytes::empty();
        failed(tx::prepare_resize(ref table,owners::Token{.slot=16,.generation=0},ref missing,257,limits(false),ref mut l,ref mut plan),1);
        failed(tx::prepare_resize(ref table,old,ref b,257,growth::Limits{.object=4096,.instance=703,.engine=8192},ref mut l,ref mut plan),5);
        failed(tx::prepare_resize(ref table,old,ref b,18446744073709551615,limits(false),ref mut l,ref mut plan),4);
        table.slots[old.slot].generation=18446744073709551615;
        let owners::Token last=owners::Token{.slot=old.slot,.generation=18446744073709551615};
        failed(tx::prepare_resize(ref table,last,ref b,257,limits(false),ref mut l,ref mut plan),2);
        table.slots[old.slot].generation=old.generation;
        assert(l.used==320 && l.engine_used==352 && l.peak==384 && l.engine_peak==416 && l.pending==0 &&
            l.old_capacity==0 && l.new_capacity==0 && l.before_used==0 && l.before_engine_used==0 && !plan.active);
        same_table(ref table,ref before);kept(ref table,old,ref b,false);return;
    }
    let usize capacity=if(minimum){320}else{384};let usize peak=320+capacity+64;
    if(oom) {
        failed(tx::prepare_resize(ref table,old,ref b,257,limits(minimum),ref mut l,ref mut plan),7);
        kept(ref table,old,ref b,false);same_table(ref table,ref before);
        assert(l.used==320 && l.engine_used==352 && l.peak==peak && l.engine_peak==peak+32 && l.pending==0 &&
            l.old_capacity==0 && l.new_capacity==0 && l.before_used==0 && l.before_engine_used==0 && !plan.active);
    }
    if(mode==4) {
        {let bytes::Buffer discarded=take(tx::prepare_resize(ref table,old,ref b,257,limits(false),ref mut l,ref mut plan));
            assert(bytes::len(ref discarded)==257 && plan.length==257);zeros(ref discarded,4,257);
            kept(ref table,old,ref b,false);same_table(ref table,ref before);assert(l.used==peak);}
        assert(switch(tx::cancel(ref table,ref mut l,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
        assert(l.engine_used==352 && l.peak==peak && l.engine_peak==peak+32 && l.pending==0 && !plan.active);
        kept(ref table,old,ref b,false);same_table(ref table,ref before);return;
    }
    let bytes::Buffer ready=take(tx::prepare_resize(ref table,old,ref b,257,limits(minimum),ref mut l,ref mut plan));
    assert(bytes::len(ref ready)==257 && bytes::capacity(ref ready)==capacity && plan.length==257);
    zeros(ref ready,if(truncated){2}else{4},257);kept(ref table,old,ref b,truncated);same_table(ref table,ref before);
    assert(l.used==peak && l.engine_used==peak+32 && l.pending==capacity+64);
    b=ready;
    let owners::Token fresh=switch(tx::commit(ref mut table,ref b,ref mut l,ref mut plan)) {
        case .ok(v):{v}case .err(_):{assert(false);old}
    };
    assert(fresh.slot==old.slot && fresh.generation==old.generation+1 && table.slots[fresh.slot].length==257 && table.slots[fresh.slot].capacity==capacity);
    zeros(ref b,if(truncated){2}else{4},257);
    assert(switch(owners::read(ref table,fresh,256,ref b)){case .ok(v):{v==0}case .err(_):{false}});
    let bytes::Buffer missing=bytes::empty();
    assert(switch(owners::read(ref table,old,0,ref missing)){case .ok(_):{false}case .err(e):{
        switch(e){case .Token:{true}case .Owners:{false}case .State:{false}case .Bounds:{false}}}});
    assert(l.used==capacity+64 && l.engine_used==capacity+96 && l.peak==peak && l.engine_peak==peak+32 && l.pending==0 && !plan.active);
    var usize i=1;while(i<16){assert(table.slots[i].generation==before.slots[i].generation &&
        table.slots[i].live==before.slots[i].live && table.slots[i].length==before.slots[i].length &&
        table.slots[i].capacity==before.slots[i].capacity);i+=1;}
    if(mode==0) {
        var close::Plan closed=close::empty();
        assert(switch(close::begin(ref mut table,fresh,ref b,ref l,ref mut closed)){case .ok(n):{n==capacity+64}case .err(_):{false}});
        {let bytes::Buffer disposed=b;}
        assert(switch(close::finish(ref table,ref mut l,ref mut closed)){case .ok(n):{n==0}case .err(_):{false}});
        assert(l.engine_used==32 && l.peak==peak && l.engine_peak==peak+32 && !closed.active);
    }else{let bytes::Buffer disposed=b;}
}
