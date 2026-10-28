module main;
import std::bytes as bytes;
import std::io as io;
import std::process as process;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_replacement as tx;

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
    else {return 2;}
    return switch(io::write("buffer-failure: passed\n")){case .ok(_):{0}case .err(_):{1}};
}
