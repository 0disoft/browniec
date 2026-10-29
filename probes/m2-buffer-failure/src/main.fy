module main;
import std::bytes as bytes;
import std::io as io;
import std::process as process;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_replacement as tx;
import buffer_append as append;
import buffer_close as close;
import buffer_truncate as truncate;
import buffer_resize as resize;
import grow_resize as grow_resize;
import create as create_probe;
import copy_out as copy_out;
import write as write_probe;
import prepared_write as prepared_write;
import utf8 as utf8_probe;
import utf8_scan as utf8_scan;
import utf8_meter as utf8_meter;

fn growth::Limits limits(bool minimum) {
    return growth::Limits{.object=4096,.instance=if(minimum){704}else{8192},
        .engine=if(minimum){736}else{8192}};
}
fn bytes::Buffer prepared(Result<bytes::Buffer,tx::Error> r) {
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
}
fn owners::Token token(Result<owners::Token,owners::Error> r) {
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn void kept(ref owners::Table table,owners::Token t,ref bytes::Buffer b) {
    assert(bytes::capacity(b)==256 && bytes::len(b)==4 && bytes::equal(bytes::view(b),b"keep"));
    assert(switch(owners::read(table,t,0,b)){case .ok(v):{v==107}case .err(_):{false}});
}
fn void run(bool minimum,bool oom,bool abandon) {
    var growth::Ledger l=growth::empty();var bytes::Buffer b=bytes::empty();
    b=switch(storage::prepare_growth(ref b,256,limits(false),ref mut l)) {
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    switch(growth::commit(256,ref mut l)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(ref mut b,b"keep")){case .ok(_):{}case .err(_):{assert(false);}};
    l.engine_used+=32;l.engine_peak+=32;
    var owners::Table table=owners::empty();let owners::Token old=token(owners::create(ref mut table,ref b));
    let owners::Table before=owners::Table{.slots=table.slots};
    var tx::Plan plan=tx::empty();
    let usize capacity=if(minimum){320}else{384};
    let usize peak=if(minimum){704}else{768};
    if(oom) {
        assert(switch(tx::prepare(ref table,old,ref b,257,limits(minimum),ref mut l,ref mut plan)) {
            case .ok(_):{false}
            case .err(e):{switch(e){case .Allocation:{true}case .Token:{false}case .Owners:{false}
                case .State:{false}case .Overflow:{false}case .Quota:{false}case .NoGrowth:{false}case .Provider:{false}}}
        });
        kept(ref table,old,ref b);
        assert(l.used==320 && l.engine_used==352 && l.peak==peak && l.engine_peak==peak+32);
        assert(l.pending==0 && l.old_capacity==0 && l.new_capacity==0 &&
            l.before_used==0 && l.before_engine_used==0 && !plan.active);
        var usize i=0;while(i<16) {
            assert(table.slots[i].live==before.slots[i].live && table.slots[i].generation==before.slots[i].generation &&
                table.slots[i].length==before.slots[i].length && table.slots[i].capacity==before.slots[i].capacity);i+=1;
        }
        // This retry is explicit. prepare must have returned Allocation first.
    }
    if(abandon) {
        {let bytes::Buffer discarded=prepared(tx::prepare(ref table,old,ref b,257,limits(minimum),ref mut l,ref mut plan));
            assert(bytes::capacity(ref discarded)==capacity && bytes::equal(bytes::view(ref discarded),b"keep"));
            kept(ref table,old,ref b);assert(l.used==peak && l.engine_used==peak+32 && plan.active);}
        assert(switch(tx::cancel(ref table,ref mut l,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
        kept(ref table,old,ref b);assert(l.engine_used==352 && l.pending==0 && !plan.active);
    } else {
        b=prepared(tx::prepare(ref table,old,ref b,257,limits(minimum),ref mut l,ref mut plan));
        let owners::Token fresh=switch(tx::commit(ref mut table,ref b,ref mut l,ref mut plan)) {
            case .ok(v):{v}case .err(_):{assert(false);old}
        };
        assert(fresh.slot==old.slot && fresh.generation==old.generation+1);
        assert(bytes::capacity(ref b)==capacity && bytes::len(ref b)==4 && bytes::equal(bytes::view(ref b),b"keep"));
        assert(l.used==capacity+64 && l.engine_used==capacity+96 && l.pending==0 && !plan.active);
        let bytes::Buffer missing=bytes::empty();
        assert(switch(owners::read(ref table,old,0,ref missing)) {
            case .ok(_):{false}case .err(e):{switch(e){case .Token:{true}case .Owners:{false}case .State:{false}case .Bounds:{false}}}
        });
    }
    assert(l.peak==peak && l.engine_peak==peak+32);
}
fn u8 append_code(append::Error e) {
    return switch(e){case .Token:{1}case .Owners:{2}case .State:{3}case .Overflow:{4}
        case .Quota:{5}case .Capacity:{6}case .Provider:{7}};
}
fn void append_failed(Result<owners::Token,append::Error> r,u8 expected) {
    assert(switch(r){case .ok(_):{false}case .err(e):{append_code(e)==expected}});
}
fn owners::Token appended(Result<owners::Token,append::Error> r) {
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn void run_append(u8 mode) {
    var growth::Ledger l=growth::empty();var bytes::Buffer b=bytes::empty();
    b=switch(storage::prepare_growth(ref b,256,limits(false),ref mut l)) {
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    switch(growth::commit(256,ref mut l)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(ref mut b,b"keep")){case .ok(_):{}case .err(_):{assert(false);}};
    var owners::Table table=owners::empty();let owners::Token old=token(owners::create(ref mut table,ref b));
    let growth::Ledger before=l;
    if(mode==0) {
        let owners::Token fresh=appended(append::within_capacity(ref mut table,old,ref mut b,b"!",limits(false),ref l));
        assert(fresh.slot==old.slot && fresh.generation==old.generation+1);
        assert(bytes::equal(bytes::view(ref b),b"keep!") && table.slots[fresh.slot].length==5);
        assert(switch(owners::read(ref table,fresh,4,ref b)){case .ok(v):{v==33}case .err(_):{false}});
        append_failed(append::within_capacity(ref mut table,old,ref mut b,b"x",limits(false),ref l),1);
        let owners::Token same=appended(append::within_capacity(ref mut table,fresh,ref mut b,b"",limits(false),ref l));
        assert(same.generation==fresh.generation && bytes::capacity(ref b)==256);
    } else if(mode==1) {
        let u8[253] too_many=[88;253];
        append_failed(append::within_capacity(ref mut table,old,ref mut b,ref too_many[..],limits(false),ref l),6);
        kept(ref table,old,ref b);
        let u8[252] exact=[88;252];
        let owners::Token fresh=appended(append::within_capacity(ref mut table,old,ref mut b,ref exact[..],limits(false),ref l));
        assert(bytes::len(ref b)==256 && bytes::capacity(ref b)==256);
        assert(switch(owners::read(ref table,fresh,255,ref b)){case .ok(v):{v==88}case .err(_):{false}});
        append_failed(append::within_capacity(ref mut table,fresh,ref mut b,b"!",limits(false),ref l),6);
    } else if(mode==2) {
        let owners::Token invalid=owners::Token{.slot=16,.generation=1};
        var bytes::Buffer missing=bytes::empty();
        append_failed(append::within_capacity(ref mut table,invalid,ref mut missing,b"!",limits(false),ref l),1);
        append_failed(append::within_capacity(ref mut table,old,ref mut missing,b"!",limits(false),ref l),3);
        table.slots[old.slot].generation=18446744073709551615;
        let owners::Token last=owners::Token{.slot=old.slot,.generation=18446744073709551615};
        append_failed(append::within_capacity(ref mut table,last,ref mut b,b"!",limits(false),ref l),2);
        let owners::Token same=appended(append::within_capacity(ref mut table,last,ref mut b,b"",limits(false),ref l));
        assert(same.generation==last.generation);kept(ref table,last,ref b);
    } else {
        l.pending=1;
        append_failed(append::within_capacity(ref mut table,old,ref mut b,b"!",limits(false),ref l),3);l.pending=0;
        l.used=0;
        append_failed(append::within_capacity(ref mut table,old,ref mut b,b"!",limits(false),ref l),3);l.used=320;
        append_failed(append::within_capacity(ref mut table,old,ref mut b,b"!",growth::Limits{.object=4096,.instance=319,.engine=8192},ref l),5);
        // An object ceiling below the current capacity rejects even a no-op.
        append_failed(append::within_capacity(ref mut table,old,ref mut b,b"",growth::Limits{.object=255,.instance=8192,.engine=8192},ref l),5);
        kept(ref table,old,ref b);
    }
    assert(l.used==before.used && l.engine_used==before.engine_used && l.peak==before.peak && l.engine_peak==before.engine_peak &&
        l.pending==before.pending && l.old_capacity==before.old_capacity && l.new_capacity==before.new_capacity &&
        l.before_used==before.before_used && l.before_engine_used==before.before_engine_used);
}
fn bytes::Buffer close_root(ref mut growth::Ledger l) {
    var bytes::Buffer b=bytes::empty();
    b=switch(storage::prepare_growth(ref b,256,limits(false),l)) {
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    switch(growth::commit(256,l)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(ref mut b,b"keep")){case .ok(_):{}case .err(_):{assert(false);}};
    return b;
}
fn void close_failed(Result<usize,close::Error> r,bool identity) {
    assert(switch(r){case .ok(_):{false}case .err(e):{switch(e){case .Token:{identity}case .State:{!identity}}}});
}
fn void close_empty() {
    var growth::Ledger l=growth::empty();var owners::Table table=owners::empty();var close::Plan plan=close::empty();
    {let bytes::Buffer b=bytes::empty();let owners::Token t=token(owners::create(ref mut table,ref b));
        assert(switch(close::begin(ref mut table,t,ref b,ref l,ref mut plan)){case .ok(n):{n==64}case .err(_):{false}});
        assert(l.used==64 && l.engine_used==64);}
    assert(switch(close::finish(ref table,ref mut l,ref mut plan)){case .ok(n):{n==0}case .err(_):{false}});
    assert(l.engine_used==0 && l.peak==64 && l.engine_peak==64 && !plan.active);
}
fn void run_close(u8 mode) {
    var growth::Ledger l=growth::empty();var owners::Table table=owners::empty();var close::Plan plan=close::empty();
    var owners::Token source=owners::Token{.slot=16,.generation=0};
    {
        var bytes::Buffer b=close_root(ref mut l);source=token(owners::create(ref mut table,ref b));
        if(mode==0) {l.engine_used+=32;l.engine_peak+=32;}
        if(mode==1) {
            let bytes::Buffer missing=bytes::empty();
            close_failed(close::begin(ref mut table,owners::Token{.slot=16,.generation=1},ref missing,ref l,ref mut plan),true);
            close_failed(close::begin(ref mut table,source,ref missing,ref l,ref mut plan),false);
            l.used=319;close_failed(close::begin(ref mut table,source,ref b,ref l,ref mut plan),false);l.used=320;
            table.slots[1].capacity=64;close_failed(close::begin(ref mut table,source,ref b,ref l,ref mut plan),false);table.slots[1].capacity=0;
            switch(growth::begin(256,257,limits(false),ref mut l)){case .ok(_):{}case .err(_):{assert(false);}};
            close_failed(close::begin(ref mut table,source,ref b,ref l,ref mut plan),false);
            assert(l.used==768 && l.pending==448 && !plan.active);kept(ref table,source,ref b);
            switch(growth::cancel(ref mut l)){case .ok(_):{}case .err(_):{assert(false);}};
        }
        if(mode==3) {table.slots[source.slot].generation=18446744073709551615;source.generation=18446744073709551615;}
        let growth::Ledger before=l;
        assert(switch(close::begin(ref mut table,source,ref b,ref l,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
        assert(plan.active && !table.slots[source.slot].live && l.used==before.used && l.engine_used==before.engine_used);
        assert(bytes::equal(bytes::view(ref b),b"keep"));
        assert(switch(owners::read(ref table,source,0,ref b)){case .ok(_):{false}case .err(e):{switch(e){case .Token:{true}case .Owners:{false}case .State:{false}case .Bounds:{false}}}});
        close_failed(close::begin(ref mut table,source,ref b,ref l,ref mut plan),false);
        var close::Plan duplicate=close::empty();close_failed(close::begin(ref mut table,source,ref b,ref l,ref mut duplicate),true);
    }
    // Native root scope has ended; only now may accounting release its charge.
    if(mode==2) {
        l.engine_used+=1;close_failed(close::finish(ref table,ref mut l,ref mut plan),false);
        assert(l.used==320 && l.engine_used==321 && plan.active);l.engine_used-=1;
        table.slots[1].generation=2;close_failed(close::finish(ref table,ref mut l,ref mut plan),false);
        assert(l.used==320 && table.slots[1].generation==2 && plan.active);table.slots[1].generation=1;
        plan.capacity=18446744073709551615;close_failed(close::finish(ref table,ref mut l,ref mut plan),false);plan.capacity=256;
        plan.charge=321;close_failed(close::finish(ref table,ref mut l,ref mut plan),false);plan.charge=320;
    }
    let usize peak=l.peak;let usize engine_peak=l.engine_peak;
    assert(switch(close::finish(ref table,ref mut l,ref mut plan)){case .ok(n):{n==0}case .err(_):{false}});
    assert(l.engine_used==if(mode==0){32}else{0});
    assert(l.peak==peak && l.engine_peak==engine_peak && l.pending==0 && l.old_capacity==0 && l.new_capacity==0 &&
        l.before_used==0 && l.before_engine_used==0 && !plan.active);
    close_failed(close::finish(ref table,ref mut l,ref mut plan),false);
    assert(table.slots[source.slot].generation==if(mode==3){0}else{source.generation+1});
    if(mode==0) {close_empty();}
}
fn void tx_failed(Result<bytes::Buffer,tx::Error> r,u8 expected) {
    assert(switch(r){case .ok(_):{false}case .err(e):{switch(e){
        case .Token:{expected==1}case .Owners:{expected==2}case .State:{expected==3}
        case .Overflow:{expected==4}case .Quota:{expected==5}case .NoGrowth:{expected==6}
        case .Allocation:{expected==7}case .Provider:{expected==8}}}});
}
fn void run_grow_append(bool minimum,bool oom,bool abandon,bool self_append,bool preflight) {
    var growth::Ledger l=growth::empty();var bytes::Buffer b=close_root(ref mut l);
    l.engine_used+=32;l.engine_peak+=32;
    if(self_append) {
        let u8[196] padding=[88;196];
        switch(bytes::append(ref mut b,ref padding[..])){case .ok(n):{assert(n==200);}case .err(_):{assert(false);}};
    }
    var owners::Table table=owners::empty();let owners::Token old=token(owners::create(ref mut table,ref b));
    let u8[253] suffix=[88;253];var tx::Plan plan=tx::empty();
    if(preflight) {
        tx_failed(tx::prepare_append(ref table,old,ref b,b"",limits(false),ref mut l,ref mut plan),6);
        tx_failed(tx::prepare_append(ref table,old,ref b,b"!",limits(false),ref mut l,ref mut plan),6);
        let bytes::Buffer missing=bytes::empty();
        tx_failed(tx::prepare_append(ref table,owners::Token{.slot=16,.generation=1},ref missing,b"!",limits(false),ref mut l,ref mut plan),1);
        tx_failed(tx::prepare_append(ref table,old,ref b,ref suffix[..],growth::Limits{.object=4096,.instance=703,.engine=8192},ref mut l,ref mut plan),5);
        assert(!plan.active && l.used==320 && l.engine_used==352 && l.pending==0 && l.peak==384);
        kept(ref table,old,ref b);return;
    }
    let usize capacity=if(self_append){448}else{if(minimum){320}else{384}};
    let usize length=if(self_append){400}else{257};
    let usize peak=320+capacity+64;
    if(oom) {
        tx_failed(tx::prepare_append(ref table,old,ref b,ref suffix[..],limits(minimum),ref mut l,ref mut plan),7);
        kept(ref table,old,ref b);
        assert(l.used==320 && l.engine_used==352 && l.peak==peak && l.engine_peak==peak+32 &&
            l.pending==0 && l.old_capacity==0 && l.new_capacity==0 && l.before_used==0 && l.before_engine_used==0 && !plan.active);
    }
    if(abandon) {
        {let bytes::Buffer discarded=prepared(tx::prepare_append(ref table,old,ref b,ref suffix[..],limits(minimum),ref mut l,ref mut plan));
            assert(bytes::len(ref discarded)==length && plan.length==length);kept(ref table,old,ref b);
            assert(table.slots[old.slot].length==4 && l.used==peak);}
        plan.length=plan.capacity+1;
        assert(switch(tx::cancel(ref table,ref mut l,ref mut plan)){case .ok(_):{false}case .err(_):{true}});
        assert(plan.active && l.used==peak);plan.length=length;
        assert(switch(tx::cancel(ref table,ref mut l,ref mut plan)){case .ok(n):{n==320}case .err(_):{false}});
        kept(ref table,old,ref b);assert(l.engine_used==352 && l.peak==peak && !plan.active);return;
    }
    let bytes::Buffer ready=if(self_append) {
        prepared(tx::prepare_append(ref table,old,ref b,bytes::view(ref b),limits(false),ref mut l,ref mut plan))
    } else {prepared(tx::prepare_append(ref table,old,ref b,ref suffix[..],limits(minimum),ref mut l,ref mut plan))};
    assert(bytes::len(ref ready)==length && bytes::capacity(ref ready)==capacity && plan.length==length);
    assert(table.slots[old.slot].length==if(self_append){200}else{4});
    b=ready;
    let owners::Token fresh=switch(tx::commit(ref mut table,ref b,ref mut l,ref mut plan)) {
        case .ok(v):{v}case .err(_):{assert(false);old}
    };
    assert(fresh.slot==old.slot && fresh.generation==old.generation+1 && table.slots[fresh.slot].length==length);
    assert(switch(owners::read(ref table,fresh,0,ref b)){case .ok(n):{n==107}case .err(_):{false}});
    assert(switch(owners::read(ref table,fresh,length-1,ref b)){case .ok(n):{n==88}case .err(_):{false}});
    if(self_append) {assert(switch(owners::read(ref table,fresh,200,ref b)){case .ok(n):{n==107}case .err(_):{false}});}
    let bytes::Buffer missing=bytes::empty();
    assert(switch(owners::read(ref table,old,0,ref missing)){case .ok(_):{false}case .err(_):{true}});
    assert(l.used==capacity+64 && l.engine_used==capacity+96 && l.peak==peak && l.engine_peak==peak+32 && l.pending==0 && !plan.active);
    if(!minimum && !oom && !self_append) {
        var close::Plan closed=close::empty();
        assert(switch(close::begin(ref mut table,fresh,ref b,ref l,ref mut closed)){case .ok(n):{n==capacity+64}case .err(_):{false}});
        {let bytes::Buffer disposed=b;}
        assert(switch(close::finish(ref table,ref mut l,ref mut closed)){case .ok(n):{n==0}case .err(_):{false}});
        assert(l.engine_used==32 && l.peak==peak && !closed.active);
    } else {let bytes::Buffer disposed=b;}
}
fn owners::Token shortened(Result<owners::Token,truncate::Error> r) {
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn void truncate_failed(Result<owners::Token,truncate::Error> r,u8 expected) {
    assert(switch(r){case .ok(_):{false}case .err(e):{switch(e){
        case .Token:{expected==1}case .Owners:{expected==2}case .State:{expected==3}
        case .Overflow:{expected==4}case .Quota:{expected==5}case .Bounds:{expected==6}case .Provider:{expected==7}}}});
}
fn void same_usage(ref growth::Ledger a,ref growth::Ledger b) {
    assert(a.used==b.used && a.engine_used==b.engine_used && a.peak==b.peak && a.engine_peak==b.engine_peak &&
        a.pending==b.pending && a.old_capacity==b.old_capacity && a.new_capacity==b.new_capacity &&
        a.before_used==b.before_used && a.before_engine_used==b.before_engine_used);
}
fn void run_truncate(u8 mode) {
    var growth::Ledger l=growth::empty();var bytes::Buffer b=close_root(ref mut l);
    l.engine_used+=32;l.engine_peak+=32;
    var owners::Table table=owners::empty();table.slots[15].generation=7;
    let owners::Token old=token(owners::create(ref mut table,ref b));let growth::Ledger before=l;
    let owners::Table unchanged=owners::Table{.slots=table.slots};
    if(mode==0) {
        let owners::Token small=shortened(truncate::to_length(ref mut table,old,ref mut b,2,limits(false),ref l));
        assert(small.slot==old.slot && small.generation==old.generation+1 && table.slots[small.slot].length==2);
        assert(bytes::equal(bytes::view(ref b),b"ke") && bytes::capacity(ref b)==256);
        assert(switch(owners::read(ref table,small,2,ref b)){case .ok(_):{false}case .err(e):{switch(e){case .Bounds:{true}case .Token:{false}case .Owners:{false}case .State:{false}}}});
        truncate_failed(truncate::clear(ref mut table,old,ref mut b,limits(false),ref l),1);
        let owners::Token extended=appended(append::within_capacity(ref mut table,small,ref mut b,b"!",limits(false),ref l));
        assert(bytes::equal(bytes::view(ref b),b"ke!"));
        let owners::Token empty=shortened(truncate::clear(ref mut table,extended,ref mut b,limits(false),ref l));
        assert(empty.generation==extended.generation+1 && bytes::len(ref b)==0 && table.slots[empty.slot].length==0);
        let owners::Token same=shortened(truncate::clear(ref mut table,empty,ref mut b,limits(false),ref l));
        assert(same.generation==empty.generation);
        let owners::Token reused=appended(append::within_capacity(ref mut table,empty,ref mut b,b"new",limits(false),ref l));
        assert(bytes::equal(bytes::view(ref b),b"new") && table.slots[reused.slot].length==3);
        same_usage(ref l,ref before);
        var close::Plan closed=close::empty();
        assert(switch(close::begin(ref mut table,reused,ref b,ref l,ref mut closed)){case .ok(n):{n==320}case .err(_):{false}});
        {let bytes::Buffer disposed=b;}
        assert(switch(close::finish(ref table,ref mut l,ref mut closed)){case .ok(n):{n==0}case .err(_):{false}});
        assert(l.engine_used==32 && l.peak==before.peak && l.engine_peak==before.engine_peak);
    } else {
        if(mode==1) {
            truncate_failed(truncate::to_length(ref mut table,old,ref mut b,5,limits(false),ref l),6);
            truncate_failed(truncate::to_length(ref mut table,old,ref mut b,18446744073709551615,limits(false),ref l),6);
            let owners::Token same=shortened(truncate::to_length(ref mut table,old,ref mut b,4,limits(false),ref l));
            assert(same.generation==old.generation);
            var bytes::Buffer missing=bytes::empty();
            truncate_failed(truncate::to_length(ref mut table,owners::Token{.slot=16,.generation=0},ref mut missing,0,limits(false),ref l),1);
            truncate_failed(truncate::clear(ref mut table,old,ref mut missing,limits(false),ref l),3);
            table.slots[15].length=1;
            truncate_failed(truncate::clear(ref mut table,old,ref mut b,limits(false),ref l),3);table.slots[15].length=0;
            kept(ref table,old,ref b);
        } else if(mode==2) {
            table.slots[old.slot].generation=18446744073709551615;
            let owners::Token last=owners::Token{.slot=old.slot,.generation=18446744073709551615};
            truncate_failed(truncate::to_length(ref mut table,last,ref mut b,2,limits(false),ref l),2);
            truncate_failed(truncate::clear(ref mut table,last,ref mut b,limits(false),ref l),2);
            let owners::Token same=shortened(truncate::to_length(ref mut table,last,ref mut b,4,limits(false),ref l));
            assert(same.generation==last.generation);kept(ref table,last,ref b);
            table.slots[old.slot].generation=18446744073709551614;
            let owners::Token almost=owners::Token{.slot=old.slot,.generation=18446744073709551614};
            let owners::Token empty=shortened(truncate::clear(ref mut table,almost,ref mut b,limits(false),ref l));
            assert(empty.generation==last.generation && table.slots[empty.slot].length==0 && bytes::len(ref b)==0);
            let owners::Token again=shortened(truncate::clear(ref mut table,empty,ref mut b,limits(false),ref l));
            assert(again.generation==last.generation);
        } else {
            var usize i=0;while(i<9) {
                if(i==0){l.pending=1;}else if(i==1){l.old_capacity=64;}else if(i==2){l.new_capacity=64;}
                else if(i==3){l.before_used=64;}else if(i==4){l.before_engine_used=64;}else if(i==5){l.used=319;}
                else if(i==6){l.engine_used=319;}else if(i==7){l.peak=319;}else{l.engine_peak=319;}
                let growth::Ledger corrupt=l;
                truncate_failed(truncate::clear(ref mut table,old,ref mut b,limits(false),ref l),3);
                same_usage(ref l,ref corrupt);kept(ref table,old,ref b);l=before;i+=1;
            }
            truncate_failed(truncate::clear(ref mut table,old,ref mut b,growth::Limits{.object=4096,.instance=319,.engine=8192},ref l),5);
            truncate_failed(truncate::clear(ref mut table,old,ref mut b,growth::Limits{.object=4096,.instance=8192,.engine=351},ref l),5);
            truncate_failed(truncate::to_length(ref mut table,old,ref mut b,4,growth::Limits{.object=255,.instance=8192,.engine=8192},ref l),5);
            kept(ref table,old,ref b);
        }
        same_usage(ref l,ref before);{let bytes::Buffer disposed=b;}
    }
    var usize i=1;while(i<16) {
        assert(table.slots[i].generation==unchanged.slots[i].generation && table.slots[i].live==unchanged.slots[i].live &&
            table.slots[i].length==unchanged.slots[i].length && table.slots[i].capacity==unchanged.slots[i].capacity);i+=1;
    }
}
fn owners::Token resized(Result<owners::Token,resize::Error> r) {
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn void resize_failed(Result<owners::Token,resize::Error> r,u8 expected) {
    assert(switch(r){case .ok(_):{false}case .err(e):{switch(e){
        case .Token:{expected==1}case .Owners:{expected==2}case .State:{expected==3}
        case .Overflow:{expected==4}case .Quota:{expected==5}case .Capacity:{expected==6}case .Provider:{expected==7}}}});
}
fn void zero_tail(ref owners::Table table,owners::Token t,ref bytes::Buffer b,usize first,usize last) {
    var usize i=first;while(i<last) {
        assert(switch(owners::read(table,t,i,b)){case .ok(v):{v==0}case .err(_):{false}});i+=1;
    }
}
fn void run_resize(u8 mode) {
    var growth::Ledger l=growth::empty();var bytes::Buffer b=close_root(ref mut l);
    l.engine_used+=32;l.engine_peak+=32;
    var owners::Table table=owners::empty();table.slots[15].generation=7;
    let owners::Token old=token(owners::create(ref mut table,ref b));let growth::Ledger before=l;
    let owners::Table unchanged=owners::Table{.slots=table.slots};
    if(mode==0) {
        let owners::Token small=shortened(truncate::to_length(ref mut table,old,ref mut b,2,limits(false),ref l));
        let owners::Token grown=resized(resize::within_capacity(ref mut table,small,ref mut b,4,limits(false),ref l));
        assert(grown.slot==small.slot && grown.generation==small.generation+1 && table.slots[grown.slot].length==4);
        assert(bytes::view(ref b)[0]==107 && bytes::view(ref b)[1]==101);zero_tail(ref table,grown,ref b,2,4);
        resize_failed(resize::within_capacity(ref mut table,small,ref mut b,3,limits(false),ref l),1);
        assert(switch(owners::write(ref table,grown,3,88,ref mut b)){case .ok(n):{n==3}case .err(_):{false}});
        let owners::Token shrunk=resized(resize::within_capacity(ref mut table,grown,ref mut b,2,limits(false),ref l));
        assert(shrunk.generation==grown.generation+1 && bytes::equal(bytes::view(ref b),b"ke"));
        let owners::Token full=resized(resize::within_capacity(ref mut table,shrunk,ref mut b,256,limits(false),ref l));
        assert(bytes::len(ref b)==256 && bytes::capacity(ref b)==256 && table.slots[full.slot].length==256);
        zero_tail(ref table,full,ref b,2,256);
        let owners::Token same=resized(resize::within_capacity(ref mut table,full,ref mut b,256,limits(false),ref l));
        assert(same.generation==full.generation);
        let owners::Token empty=resized(resize::within_capacity(ref mut table,full,ref mut b,0,limits(false),ref l));
        let owners::Token fresh=resized(resize::within_capacity(ref mut table,empty,ref mut b,16,limits(false),ref l));
        zero_tail(ref table,fresh,ref b,0,16);
        let owners::Token extended=appended(append::within_capacity(ref mut table,fresh,ref mut b,b"!",limits(false),ref l));
        assert(bytes::len(ref b)==17 && switch(owners::read(ref table,extended,16,ref b)){case .ok(n):{n==33}case .err(_):{false}});
        same_usage(ref l,ref before);
        var close::Plan closed=close::empty();
        assert(switch(close::begin(ref mut table,extended,ref b,ref l,ref mut closed)){case .ok(n):{n==320}case .err(_):{false}});
        {let bytes::Buffer disposed=b;}
        assert(switch(close::finish(ref table,ref mut l,ref mut closed)){case .ok(n):{n==0}case .err(_):{false}});
        assert(l.engine_used==32 && l.peak==before.peak && l.engine_peak==before.engine_peak);
    } else {
        if(mode==1) {
            resize_failed(resize::within_capacity(ref mut table,old,ref mut b,257,limits(false),ref l),6);
            resize_failed(resize::within_capacity(ref mut table,old,ref mut b,18446744073709551615,limits(false),ref l),6);
            let owners::Token same=resized(resize::within_capacity(ref mut table,old,ref mut b,4,limits(false),ref l));
            assert(same.generation==old.generation);
            var bytes::Buffer missing=bytes::empty();
            resize_failed(resize::within_capacity(ref mut table,owners::Token{.slot=16,.generation=0},ref mut missing,0,limits(false),ref l),1);
            resize_failed(resize::within_capacity(ref mut table,old,ref mut missing,0,limits(false),ref l),3);
            table.slots[15].length=1;
            resize_failed(resize::within_capacity(ref mut table,old,ref mut b,0,limits(false),ref l),3);table.slots[15].length=0;
            kept(ref table,old,ref b);
        } else if(mode==2) {
            table.slots[old.slot].generation=18446744073709551615;
            let owners::Token last=owners::Token{.slot=old.slot,.generation=18446744073709551615};
            resize_failed(resize::within_capacity(ref mut table,last,ref mut b,5,limits(false),ref l),2);
            resize_failed(resize::within_capacity(ref mut table,last,ref mut b,2,limits(false),ref l),2);
            let owners::Token same=resized(resize::within_capacity(ref mut table,last,ref mut b,4,limits(false),ref l));
            assert(same.generation==last.generation);kept(ref table,last,ref b);
            table.slots[old.slot].generation=18446744073709551614;
            let owners::Token almost=owners::Token{.slot=old.slot,.generation=18446744073709551614};
            let owners::Token fresh=resized(resize::within_capacity(ref mut table,almost,ref mut b,5,limits(false),ref l));
            assert(fresh.generation==last.generation && table.slots[fresh.slot].length==5 && bytes::len(ref b)==5);
            zero_tail(ref table,fresh,ref b,4,5);
            let owners::Token again=resized(resize::within_capacity(ref mut table,fresh,ref mut b,5,limits(false),ref l));
            assert(again.generation==last.generation);
        } else {
            var usize i=0;while(i<9) {
                if(i==0){l.pending=1;}else if(i==1){l.old_capacity=64;}else if(i==2){l.new_capacity=64;}
                else if(i==3){l.before_used=64;}else if(i==4){l.before_engine_used=64;}else if(i==5){l.used=319;}
                else if(i==6){l.engine_used=319;}else if(i==7){l.peak=319;}else{l.engine_peak=319;}
                let growth::Ledger corrupt=l;
                resize_failed(resize::within_capacity(ref mut table,old,ref mut b,5,limits(false),ref l),3);
                same_usage(ref l,ref corrupt);kept(ref table,old,ref b);l=before;i+=1;
            }
            resize_failed(resize::within_capacity(ref mut table,old,ref mut b,5,growth::Limits{.object=4096,.instance=319,.engine=8192},ref l),5);
            resize_failed(resize::within_capacity(ref mut table,old,ref mut b,0,growth::Limits{.object=4096,.instance=8192,.engine=351},ref l),5);
            resize_failed(resize::within_capacity(ref mut table,old,ref mut b,4,growth::Limits{.object=255,.instance=8192,.engine=8192},ref l),5);
            kept(ref table,old,ref b);
        }
        same_usage(ref l,ref before);{let bytes::Buffer disposed=b;}
    }
    var usize i=1;while(i<16) {
        assert(table.slots[i].generation==unchanged.slots[i].generation && table.slots[i].live==unchanged.slots[i].live &&
            table.slots[i].length==unchanged.slots[i].length && table.slots[i].capacity==unchanged.slots[i].capacity);i+=1;
    }
}
@effects(console)
fn i32 main() {
    if(process::arg_count()!=2) {return 2;}
    var u8[32] arg=[0;32];
    let usize n=switch(process::arg(1,ref mut arg[..])) {case .ok(v):{v}case .err(_):{return 2;}};
    let ref u8[] mode=ref arg[..n];
    if(bytes::equal(mode,b"normal-min")) {run(true,false,false);}
    else if(bytes::equal(mode,b"normal-preferred")) {run(false,false,false);}
    else if(bytes::equal(mode,b"abandon")) {run(false,false,true);}
    else if(bytes::equal(mode,b"oom-min")) {run(true,true,false);}
    else if(bytes::equal(mode,b"oom-preferred")) {run(false,true,false);}
    else if(bytes::equal(mode,b"append-success")) {run_append(0);}
    else if(bytes::equal(mode,b"append-capacity")) {run_append(1);}
    else if(bytes::equal(mode,b"append-identity")) {run_append(2);}
    else if(bytes::equal(mode,b"append-state")) {run_append(3);}
    else if(bytes::equal(mode,b"close-success")) {run_close(0);}
    else if(bytes::equal(mode,b"close-preflight")) {run_close(1);}
    else if(bytes::equal(mode,b"close-snapshot")) {run_close(2);}
    else if(bytes::equal(mode,b"close-generation")) {run_close(3);}
    else if(bytes::equal(mode,b"grow-append-preferred")) {run_grow_append(false,false,false,false,false);}
    else if(bytes::equal(mode,b"grow-append-min")) {run_grow_append(true,false,false,false,false);}
    else if(bytes::equal(mode,b"grow-append-oom-min")) {run_grow_append(true,true,false,false,false);}
    else if(bytes::equal(mode,b"grow-append-oom-preferred")) {run_grow_append(false,true,false,false,false);}
    else if(bytes::equal(mode,b"grow-append-abandon")) {run_grow_append(false,false,true,false,false);}
    else if(bytes::equal(mode,b"grow-append-self")) {run_grow_append(false,false,false,true,false);}
    else if(bytes::equal(mode,b"grow-append-preflight")) {run_grow_append(false,false,false,false,true);}
    else if(bytes::equal(mode,b"truncate-success")) {run_truncate(0);}
    else if(bytes::equal(mode,b"truncate-bounds")) {run_truncate(1);}
    else if(bytes::equal(mode,b"truncate-generation")) {run_truncate(2);}
    else if(bytes::equal(mode,b"truncate-state")) {run_truncate(3);}
    else if(bytes::equal(mode,b"resize-success")) {run_resize(0);}
    else if(bytes::equal(mode,b"resize-capacity")) {run_resize(1);}
    else if(bytes::equal(mode,b"resize-generation")) {run_resize(2);}
    else if(bytes::equal(mode,b"resize-state")) {run_resize(3);}
    else if(bytes::equal(mode,b"grow-resize-preferred")) {grow_resize::run(0);}
    else if(bytes::equal(mode,b"grow-resize-min")) {grow_resize::run(1);}
    else if(bytes::equal(mode,b"grow-resize-oom-min")) {grow_resize::run(2);}
    else if(bytes::equal(mode,b"grow-resize-oom-preferred")) {grow_resize::run(3);}
    else if(bytes::equal(mode,b"grow-resize-abandon")) {grow_resize::run(4);}
    else if(bytes::equal(mode,b"grow-resize-truncated")) {grow_resize::run(5);}
    else if(bytes::equal(mode,b"grow-resize-preflight")) {grow_resize::run(6);}
    else if(bytes::equal(mode,b"create-success")) {create_probe::run(0);}
    else if(bytes::equal(mode,b"create-preflight")) {create_probe::run(1);}
    else if(bytes::equal(mode,b"create-state")) {create_probe::run(2);}
    else if(bytes::equal(mode,b"create-slots")) {create_probe::run(3);}
    else if(bytes::equal(mode,b"copy-out-success")) {copy_out::run(0);}
    else if(bytes::equal(mode,b"copy-out-bounds")) {copy_out::run(1);}
    else if(bytes::equal(mode,b"copy-out-identity")) {copy_out::run(2);}
    else if(bytes::equal(mode,b"copy-out-pending")) {copy_out::run(3);}
    else if(bytes::equal(mode,b"write-success")) {write_probe::run(0);}
    else if(bytes::equal(mode,b"write-bounds")) {write_probe::run(1);}
    else if(bytes::equal(mode,b"write-identity")) {write_probe::run(2);}
    else if(bytes::equal(mode,b"write-state")) {write_probe::run(3);}
    else if(bytes::equal(mode,b"prepared-write-success")) {prepared_write::run(0);}
    else if(bytes::equal(mode,b"prepared-write-bounds")) {prepared_write::run(1);}
    else if(bytes::equal(mode,b"prepared-write-preflight")) {prepared_write::run(2);}
    else if(bytes::equal(mode,b"prepared-write-abandon")) {prepared_write::run(3);}
    else if(bytes::equal(mode,b"utf8-valid")) {utf8_probe::run(0);}
    else if(bytes::equal(mode,b"utf8-invalid")) {utf8_probe::run(1);}
    else if(bytes::equal(mode,b"utf8-identity")) {utf8_probe::run(2);}
    else if(bytes::equal(mode,b"utf8-pending")) {utf8_probe::run(3);}
    else if(bytes::equal(mode,b"utf8-scan-valid")) {utf8_scan::run(0);}
    else if(bytes::equal(mode,b"utf8-scan-invalid")) {utf8_scan::run(1);}
    else if(bytes::equal(mode,b"utf8-scan-state")) {utf8_scan::run(2);}
    else if(bytes::equal(mode,b"utf8-scan-pending")) {utf8_scan::run(3);}
    else if(bytes::equal(mode,b"utf8-meter-success")) {utf8_meter::run(0);}
    else if(bytes::equal(mode,b"utf8-meter-fuel")) {utf8_meter::run(1);}
    else if(bytes::equal(mode,b"utf8-meter-errors")) {utf8_meter::run(2);}
    else if(bytes::equal(mode,b"utf8-meter-pending")) {utf8_meter::run(3);}
    else {return 2;}
    return switch(io::write("buffer-failure: passed\n")){case .ok(_):{0}case .err(_):{1}};
}
