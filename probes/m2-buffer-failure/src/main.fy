module main;
import std::bytes as bytes;
import std::io as io;
import std::process as process;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_replacement as tx;
import buffer_append as append;

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
    else {return 2;}
    return switch(io::write("buffer-failure: passed\n")){case .ok(_):{0}case .err(_):{1}};
}
