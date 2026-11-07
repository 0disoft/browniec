module tests::m2::slice_result_cursor;
import slice_result_cursor as cursor;
import errors as errors;

fn void value(Result<usize,errors::Error> result,usize expected){
    switch(result){case .ok(v):{assert(v==expected);}case .err(_):{assert(false);}};
}
fn void rejected(Result<usize,errors::Error> result){
    switch(result){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==0);}};
}
fn void same(ref cursor::Stats a,ref cursor::Stats b){
    assert(a.calls==b.calls && a.yields==b.yields && a.dispatched==b.dispatched);
    assert(a.last==b.last && a.maximum==b.maximum);
}
fn void history(ref cursor::Stats s,usize calls,usize yields,usize dispatched,usize last,usize maximum){
    assert(s.calls==calls && s.yields==yields && s.dispatched==dispatched && s.last==last && s.maximum==maximum);
}
fn void malformed(ref mut cursor::Stats s){
    let cursor::Stats before=*s;
    rejected(cursor::begin(s,1));same(s,ref before);
    rejected(cursor::finish(s,1,false));same(s,ref before);
    rejected(cursor::visit(s));same(s,ref before);
    rejected(cursor::yielded(s));same(s,ref before);
}

@test
fn void cursor_empty_moves_and_resets_only_resume_control(){
    var cursor::Cursor c=cursor::empty();assert(c.pc==0 && !c.active);
    c.pc=255;c.active=true;let cursor::Cursor moved=c;
    assert(moved.pc==255 && moved.active);
    c=cursor::empty();assert(c.pc==0 && !c.active);
    assert(moved.pc==255 && moved.active);
    let cursor::Stats s=cursor::stats();history(ref s,0,0,0,0,0);
}

@test
fn void quantum_boundaries_and_begin_rejections_preserve_every_counter(){
    let usize maximum=18446744073709551615;
    assert(!cursor::valid_quantum(0) && cursor::valid_quantum(1));
    assert(cursor::valid_quantum(4096) && !cursor::valid_quantum(4097) && !cursor::valid_quantum(maximum));
    var cursor::Stats s=cursor::stats();let cursor::Stats empty=s;
    rejected(cursor::begin(ref mut s,0));same(ref s,ref empty);
    rejected(cursor::begin(ref mut s,4097));same(ref s,ref empty);
    rejected(cursor::begin(ref mut s,maximum));same(ref s,ref empty);
    value(cursor::begin(ref mut s,4096),4096);
    value(cursor::finish(ref mut s,4096,true),4096);history(ref s,1,1,4096,4096,4096);
    let cursor::Stats full_batch=s;rejected(cursor::visit(ref mut s));same(ref s,ref full_batch);
    value(cursor::begin(ref mut s,1),1);history(ref s,2,1,4096,0,4096);
    value(cursor::finish(ref mut s,1,false),1);history(ref s,2,1,4097,1,4096);
    let cursor::Stats before=s;rejected(cursor::begin(ref mut s,0));same(ref s,ref before);
}

@test
fn void finish_aggregates_pending_complete_and_error_histories_once_per_batch(){
    var cursor::Stats s=cursor::stats();
    value(cursor::begin(ref mut s,3),3);value(cursor::finish(ref mut s,3,true),3);
    history(ref s,1,1,3,3,3);
    value(cursor::begin(ref mut s,2),2);value(cursor::finish(ref mut s,2,true),2);
    history(ref s,2,2,5,2,3);
    var cursor::Stats moved=s;same(ref moved,ref s);
    // A terminal error can report the instruction already visited before failure.
    value(cursor::begin(ref mut moved,2),2);value(cursor::finish(ref mut moved,1,false),1);
    history(ref moved,3,2,6,1,3);
    // Setup/terminal failure with no opcode dispatched is counted as a call only.
    value(cursor::begin(ref mut moved,1),1);value(cursor::finish(ref mut moved,0,false),0);
    history(ref moved,4,2,6,0,3);
    let cursor::Stats before=moved;
    rejected(cursor::finish(ref mut moved,0,true));same(ref moved,ref before);
    rejected(cursor::finish(ref mut moved,4097,false));same(ref moved,ref before);
    rejected(cursor::finish(ref mut moved,18446744073709551615,true));same(ref moved,ref before);
    history(ref s,2,2,5,2,3);
}

@test
fn void begin_reserves_full_quantum_headroom_and_finish_overflow_is_atomic(){
    let usize maximum=18446744073709551615;
    var cursor::Stats calls=cursor::Stats{.calls=maximum,.yields=0,.dispatched=0,.last=0,.maximum=0};
    let cursor::Stats calls_before=calls;rejected(cursor::begin(ref mut calls,1));same(ref calls,ref calls_before);
    var cursor::Stats exact=cursor::Stats{.calls=1,.yields=0,.dispatched=maximum-4096,.last=1,.maximum=1};
    let cursor::Stats before=exact;
    var cursor::Stats short=exact;short.dispatched=maximum-4095;let cursor::Stats short_before=short;
    rejected(cursor::begin(ref mut short,4096));same(ref short,ref short_before);
    value(cursor::begin(ref mut exact,4096),4096);
    value(cursor::finish(ref mut exact,4096,true),4096);history(ref exact,2,1,maximum,4096,4096);
    let cursor::Stats full=exact;
    rejected(cursor::begin(ref mut exact,1));same(ref exact,ref full);
    rejected(cursor::finish(ref mut exact,1,false));same(ref exact,ref full);
    rejected(cursor::visit(ref mut exact));same(ref exact,ref full);
    value(cursor::finish(ref mut exact,0,false),0);history(ref exact,2,1,maximum,0,4096);
    var cursor::Stats yields=cursor::Stats{.calls=maximum,.yields=maximum,.dispatched=1,.last=1,.maximum=1};
    let cursor::Stats yields_before=yields;
    var cursor::Stats final_call=cursor::Stats{.calls=maximum-1,.yields=maximum-1,.dispatched=1,.last=1,.maximum=1};
    value(cursor::begin(ref mut final_call,1),1);
    value(cursor::finish(ref mut final_call,1,true),1);history(ref final_call,maximum,maximum,2,1,1);
    rejected(cursor::begin(ref mut yields,1));same(ref yields,ref yields_before);
    rejected(cursor::finish(ref mut yields,1,true));same(ref yields,ref yields_before);
    rejected(cursor::yielded(ref mut yields));same(ref yields,ref yields_before);
    history(ref before,1,0,maximum-4096,1,1);
}

@test
fn void malformed_states_and_compatibility_helpers_obey_atomic_bounds(){
    var cursor::Stats s=cursor::stats();let cursor::Stats empty=s;
    rejected(cursor::finish(ref mut s,0,false));same(ref s,ref empty);
    rejected(cursor::visit(ref mut s));same(ref s,ref empty);
    rejected(cursor::yielded(ref mut s));same(ref s,ref empty);
    s=cursor::Stats{.calls=1,.yields=0,.dispatched=1,.last=2,.maximum=1};malformed(ref mut s);
    s=cursor::Stats{.calls=1,.yields=0,.dispatched=4097,.last=0,.maximum=4097};malformed(ref mut s);
    s=cursor::Stats{.calls=1,.yields=0,.dispatched=1,.last=0,.maximum=2};malformed(ref mut s);
    s=cursor::Stats{.calls=1,.yields=2,.dispatched=0,.last=0,.maximum=0};malformed(ref mut s);
    s=cursor::Stats{.calls=0,.yields=0,.dispatched=1,.last=0,.maximum=1};malformed(ref mut s);
    s=cursor::Stats{.calls=1,.yields=0,.dispatched=1,.last=0,.maximum=0};malformed(ref mut s);
    s=cursor::stats();value(cursor::begin(ref mut s,2),2);
    value(cursor::visit(ref mut s),1);value(cursor::visit(ref mut s),2);
    value(cursor::yielded(ref mut s),1);history(ref s,1,1,2,2,2);
    let cursor::Stats yielded=s;rejected(cursor::yielded(ref mut s));same(ref s,ref yielded);
}
