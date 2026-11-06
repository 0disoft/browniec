module tests::m2::value_source_boolean;
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
    let values::Program p=compiled(input);assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void rejected(ref u8[] input,u8 kind){
    assert(switch(source::compile(input)){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset<=input.len}});
}

@test fn void boolean_short_circuit_skips_traps_preserves_precedence_and_executes_required_rhs(){
    // Either eagerly evaluated RHS would trap before the guest returns 42.
    value(b"module main;fn i32 main(){let i32 zero=0;if(false && 1/zero==0){return 0;}if(true || 1/zero==0){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let b=bytes::empty();if(false && bytes::read(ref b,0)==42){return 0;}if(true || bytes::read(ref b,0)==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){if(true || false && false){return 42;}return 0;}");
    // Required RHS calls mutate once each, in order; both boolean values matter.
    value(b"module main;fn i32 main(){var b=bytes::empty();if(!(true && bytes::push(ref mut b,40).is_ok)){return 0;}if(!(false || bytes::push(ref mut b,42).is_ok)){return 0;}if(bytes::len(ref b)!=2){return 0;}if(bytes::read(ref b,0)!=40){return 0;}if(bytes::read(ref b,1)==42){return 42;}return 0;}");
}

@test fn void boolean_joins_preserve_conditional_moves_nested_loans_and_pending_results(){
    // RHS-only named moves are legal; the skipped edge must drop its live owner.
    value(b"module main;fn bool take(Buffer b){_ = b;return true;}fn i32 main(){let b=bytes::empty();_ = false && take(b);return 42;}");
    value(b"module main;fn bool take(Buffer b){_ = b;return true;}fn i32 main(){let b=bytes::empty();if(false || take(b)){return 42;}return 0;}");
    // Neither operator may revive a maybe-moved name at the continuing join.
    rejected(b"module main;fn bool take(Buffer b){_ = b;return true;}fn i32 main(){let b=bytes::empty();_ = false && take(b);_ = bytes::len(ref b);return 42;}",3);
    rejected(b"module main;fn bool take(Buffer b){_ = b;return true;}fn i32 main(){let b=bytes::empty();_ = true || take(b);_ = bytes::len(ref b);return 42;}",3);

    // Enclosing argument loans survive both nested boolean joins, then end normally.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,if(true && (false || true)){42}else{0});bytes::write(ref mut b,0,42);if(bytes::read(ref b,0)==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let u8 n=bytes::read(ref b,if(true && (false || bytes::len(ref b)==1)){0}else{1});bytes::write(ref mut b,0,n);if(bytes::read(ref b,0)==42){return 42;}return 0;}");
    // A nested RHS cannot overlap an outer mut loan, nor erase a shared loan.
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,if(true && (false || bytes::len(ref b)==0)){42}else{0});return 42;}",3);
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::read(ref b,if(true && (false || true)){_ = bytes::push(ref mut b,1);0}else{0});return 42;}",3);

    // RHS acknowledgment happens on only one CFG edge, even with literal guards.
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);_ = true && r.is_ok;return 42;}",18);
    rejected(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);_ = false || r.is_ok;return 42;}",18);
    // Explicit handling after the join or unconditional LHS inspection is enough.
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);_ = true && r.is_ok;_ = r;return 42;}");
    value(b"module main;fn i32 main(){let Result<i64,bool> r=.ok(42);if(r.is_ok || false){return 42;}return 0;}");
}
