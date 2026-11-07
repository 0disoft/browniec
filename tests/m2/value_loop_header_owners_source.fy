module tests::m2::value_loop_header_owners_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(v):{v}case .err(_):{assert(false);compiled(input)}
};}
fn void value(ref u8[] input){
    let values::Program p=compiled(input);
    assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){
        case .ok(v):{v==42}case .err(_):{false}
    });
}
// Rejection must happen in source checking, not merely in canonical verification.
fn void rejected(ref u8[] input,u8 kind){assert(switch(source::compile(input)){
    case .ok(_):{false}case .err(e):{e.kind==kind && e.offset<=input.len}
});}
fn void failure(ref u8[] input,u8 kind){
    let values::Program p=compiled(input);
    assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){
        case .ok(_):{false}case .err(e):{e.kind==kind && e.offset<=input.len}
    });
    // Fresh invocation recovery is observable here; internal ledger emptiness
    // and retained allocation counts require separate runtime instrumentation.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);{var ref u8[] r=id(ref bytes::view(ref bytes::empty()));var n=0;while(n<2){r=bytes::view(ref b);n+=1;}if(r[0]!=42){return 0;}}bytes::write(ref mut b,0,7);return 42;}");
}

// Pre-loop anonymous roots only. Each guest independently uses the existing
// private compile / canonical verifier / VM helpers and normal limits.
@test fn void last_seed_alias_rebinding_repeats_through_while_for_and_nested_edges(){
    // The first visit reads the anonymous seed; later visits read the named
    // replacement. Dropping the seed at the first rebind must not change the
    // exact owning header on a subsequent backedge.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let b=make(42);var ref u8[] r=id(ref bytes::view(ref make(7)));var n=0;while(n<3){if(n==0){if(r[0]!=7){return 0;}}else{if(r[0]!=42){return 0;}}r=bytes::view(ref b);n+=1;}if(n==3 && r[0]==42){return 42;}return 0;}");
    // Continue goes through the shared for-post path on all three visits.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);{var ref u8[] r=id(ref bytes::view(ref bytes::empty()));var n=0;for(;n<3;n+=1){r=bytes::view(ref b);continue;}if(n!=3 || r[0]!=42){return 0;}}bytes::write(ref mut b,0,7);return 42;}");
    // Both inner and outer headers inherit the same anonymous seed. Its last
    // alias is rebound on an inner repeated edge, then the outer edge repeats.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);{var ref u8[] r=id(ref bytes::view(ref bytes::empty()));var i=0;var seen=0;while(i<2){var j=0;while(j<2){r=bytes::view(ref b);if(r[0]!=42){return 0;}seen+=1;j+=1;continue;}i+=1;}if(seen!=4 || r[0]!=42){return 0;}}bytes::write(ref mut b,0,9);return 42;}");
}

@test fn void zero_trip_break_conditional_seeds_and_last_alias_scopes_cleanup(){
    // The zero-trip path must preserve the actual seed payload, not a dummy.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){let b=make(7);{var ref u8[] r=id(ref bytes::view(ref make(42)));while(false){r=bytes::view(ref b);}if(r[0]!=42){return 0;}}return 42;}");
    // A repeated edge first defers the seed; a later break joins zero-trip.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);{var ref u8[] r=id(ref bytes::view(ref bytes::empty()));var n=0;while(n<3){r=bytes::view(ref b);if(n==1){break;}n+=1;}if(n!=1 || r[0]!=42){return 0;}}bytes::write(ref mut b,0,7);return 42;}");
    // Both concrete branches execute, exercising exact maybe-owner headers.
    // Only the chosen anonymous root exists; both alternatives must clean up.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 work(bool c){let b=make(42);{var ref u8[] r=if(c){id(ref bytes::view(ref make(7)))}else{id(ref bytes::view(ref make(9)))};if(c){if(r[0]!=7){return 0;}}else{if(r[0]!=9){return 0;}}var n=0;while(n<2){r=bytes::view(ref b);n+=1;}if(r[0]!=42){return 0;}}return 21;}fn i32 main(){return work(true)+work(false);}");
    // Static-review regression: orphaned possible seeds remain protected through
    // nested-loop exit and slow branch normalization. Added after the one batch.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();var ref u8[] r=if(false){id(ref bytes::view(ref bytes::empty()))}else{id(ref bytes::view(ref bytes::empty()))};var n=0;while(n<2){r=bytes::view(ref b);var j=0;while(j<1){j+=1;}n+=1;}if(r.len==0){return 42;}return 0;}");
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();var ref u8[] r=if(false){id(ref bytes::view(ref bytes::empty()))}else{id(ref bytes::view(ref bytes::empty()))};var n=0;while(n<2){r=bytes::view(ref b);let owner=bytes::empty();if(n==0){_ = owner;}n+=1;}if(r.len==0){return 42;}return 0;}");
    // Closing r is insufficient while s still aliases the seed. Rebinding s
    // closes the last old alias; closing both final descriptors unpins b.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 main(){var b=make(42);{var ref u8[] r=id(ref bytes::view(ref make(7)));var ref u8[] s=r;var n=0;while(n<2){r=bytes::view(ref b);if(n==0){if(s[0]!=7){return 0;}}else{if(s[0]!=42){return 0;}}s=r;n+=1;}if(r[0]!=42 || s[0]!=42){return 0;}}bytes::write(ref mut b,0,9);if(bytes::read(ref b,0)==9){return 42;}return 0;}");
}

@test fn void return_propagation_and_runtime_failures_close_deferred_seed_roots(){
    // Return before the first rebind and after one real backedge both execute.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn u8 work(bool early){let b=make(42);var ref u8[] r=id(ref bytes::view(ref make(7)));var n=0;while(n<2){if(early || n==1){return r[0];}r=bytes::view(ref b);n+=1;}return 0;}fn i32 main(){if(work(true)==7 && work(false)==42){return 42;}return 0;}");
    // Option failure occurs before rebind or after one repeated edge. A later
    // successful call exercises cleanup followed by another live seed/frame.
    // One static CALL site repeats all three cases within the 16-slot IR limit.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Option<i32> work(bool present,bool early){var Option<i32> o=.none;if(present){o=.some(42);}let b=bytes::empty();var ref u8[] r=id(ref bytes::view(ref bytes::empty()));var n=0;while(n<2){if(early || n==1){let x=o?;return .some(x);}r=bytes::view(ref b);n+=1;}return .some(0);}fn i32 main(){var n=0;var total=0;while(n<3){switch(work(n==2,n==0)){case .some(v):{if(n!=2){return 0;}total+=v;}case .none:{if(n==2){return 0;}}}n+=1;}return total;}");
    // Result error propagation preserves its error while draining the deferred
    // anonymous root and the live named replacement after a real backedge.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Result<usize,u8> fail(){return .err(7);}fn Result<usize,u8> work(){let b=bytes::empty();var ref u8[] r=id(ref bytes::view(ref bytes::empty()));var n=0;while(n<2){if(n==1){_ = r[fail()?];}r=bytes::view(ref b);n+=1;}return .ok(0);}fn i32 main(){switch(work()){case .ok(_):{return 0;}case .err(e):{if(e==7){return 42;}return 0;}}}");
    // Bounds and arithmetic fail on the second visit, with deferred cleanup
    // already required. Preserve the original failure kind, then recover.
    failure(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);var ref u8[] r=id(ref bytes::view(ref bytes::empty()));var n=0;while(n<2){if(n==1){_ = r[1];}r=bytes::view(ref b);n+=1;}return 42;}",14);
    failure(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();var ref u8[] r=if(false){id(ref bytes::view(ref bytes::empty()))}else{id(ref bytes::view(ref bytes::empty()))};var u8 x=255;var n=0;while(n<2){if(n==1){x+=1;}r=bytes::view(ref b);n+=1;}return 42;}",6);
}

@test fn void deferral_does_not_admit_named_owner_loss_pins_or_pending_results(){
    // Fresh retained body owners are covered by value_fresh_loop_owners_source.
    // A named owning header still requires exact liveness at a continue edge.
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();let owner=bytes::empty();var ref u8[] r=id(ref bytes::view(ref bytes::empty()));while(true){r=bytes::view(ref b);_ = owner;continue;}return 42;}",3);
    // Widening must recheck an earlier write and preserve pins on exit.
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);var ref u8[] r=id(ref bytes::view(ref bytes::empty()));var n=0;while(n<2){bytes::write(ref mut b,0,7);r=bytes::view(ref b);n+=1;}return 42;}",3);
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){var b=bytes::empty();var ref u8[] r=id(ref bytes::view(ref bytes::empty()));var n=0;while(n<2){r=bytes::view(ref b);n+=1;}_ = bytes::reserve(ref mut b,0);return 42;}",3);
    // The unrelated Result obligation cannot be deferred with anonymous roots:
    // the next visit overwrites a pending value, despite an acknowledgment later.
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();var ref u8[] r=id(ref bytes::view(ref bytes::empty()));var Result<i64,bool> pending=.ok(1);_ = pending;var n=0;while(n<2){r=bytes::view(ref b);pending=.err(false);n+=1;}_ = pending;return 42;}",18);
    // Nor may zero-trip exit silently discharge a Result handled only in body.
    rejected(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn i32 main(){let b=bytes::empty();var ref u8[] r=id(ref bytes::view(ref bytes::empty()));let Result<i64,bool> pending=.ok(1);while(true){r=bytes::view(ref b);_ = pending;break;}return 42;}",18);
}
