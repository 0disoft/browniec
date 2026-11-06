module tests::m2::value_buffer_copy;
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
    assert(switch(vm::run_values(ref p,10000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void rejected(ref u8[] input,u8 kind){
    assert(switch(source::compile(input)){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset<=input.len}});
}

// Independent short sources respect the globally monotonic sixteen typed slots.
@test fn void copy_preserves_source_bytes_and_returns_independent_empty_and_temporary_owners(){
    // Both directions of mutation and a later source move must remain valid.
    value(b"module main;fn i32 main(){var original=bytes::empty();_ = bytes::push(ref mut original,42);var Buffer copied=switch(bytes::copy(ref original)){case .ok(owner):{owner}case .err(_):{return 0;}};bytes::write(ref mut copied,0,7);if(bytes::read(ref original,0)!=42){return 0;}bytes::write(ref mut original,0,9);if(bytes::read(ref copied,0)!=7){return 0;}_ = bytes::push(ref mut copied,11);let kept=original;if(bytes::len(ref kept)==1 && bytes::read(ref kept,0)==9 && bytes::len(ref copied)==2 && bytes::read(ref copied,1)==11){return 42;}return 0;}");
    // An immutable named receiver is accepted; exact length and both bytes survive.
    value(b"module main;fn Buffer make(){var data=bytes::empty();_ = bytes::push(ref mut data,7);_ = bytes::push(ref mut data,42);return data;}fn i32 main(){let original=make();let Result<Buffer,u8> result=bytes::copy(ref original);switch(result){case .ok(copied):{if(bytes::len(ref original)==2 && bytes::len(ref copied)==2 && bytes::read(ref copied,0)==7 && bytes::read(ref copied,1)==42 && bytes::read(ref original,1)==42){return 42;}return 0;}case .err(_):{return 0;}}}");
    // Even empty success owns its destination independently of the dropped source.
    value(b"module main;fn i32 main(){let original=bytes::empty();var copied=switch(bytes::copy(ref original)){case .ok(owner):{owner}case .err(_):{return 0;}};if(bytes::len(ref original)!=0 || bytes::len(ref copied)!=0){return 0;}_ = original;_ = bytes::push(ref mut copied,42);if(bytes::len(ref copied)==1 && bytes::read(ref copied,0)==42){return 42;}return 0;}");
    // The qualified temporary source dies before its returned copy is read.
    value(b"module main;fn i32 main(){switch(brownie::bytes::copy(ref make())){case .ok(copied):{if(brownie::bytes::len(ref copied)==1 && brownie::bytes::read(ref copied,0)==42){return 42;}return 0;}case .err(_):{return 0;}}}fn Buffer make(){var data=brownie::bytes::empty();_ = brownie::bytes::push(ref mut data,42);return data;}");
}

@test fn void copy_results_compose_with_switch_propagation_forward_calls_and_explicit_handling(){
    // A forward helper returns the exact owning Result through CALL and RETURN.
    value(b"module main;fn i32 main(){switch(copied()){case .ok(owner):{if(bytes::len(ref owner)==0){return 42;}return 0;}case .err(_):{return 0;}}}fn Result<Buffer,u8> copied(){let original=bytes::empty();return bytes::copy(ref original);}");
    // Propagation may change the success type while retaining the exact u8 error.
    value(b"module main;fn Result<usize,u8> length(){let original=bytes::empty();let owner=bytes::copy(ref original)?;return .ok(bytes::len(ref owner));}fn i32 main(){switch(length()){case .ok(size):{if(size==0){return 42;}return 0;}case .err(_):{return 0;}}}");
    // A predicate handles the obligation without consuming the move-only Result.
    value(b"module main;fn i32 main(){let original=bytes::empty();let Result<Buffer,u8> result=bytes::copy(ref original);_ = result.is_ok;return take(result);}fn i32 take(Result<Buffer,u8> incoming){switch(incoming){case .ok(owner):{if(bytes::len(ref owner)==0){return 42;}return 0;}case .err(_):{return 0;}}}");
    // Explicit discard is valid, including a qualified empty temporary receiver.
    value(b"module main;fn i32 main(){_ = brownie::bytes::copy(ref brownie::bytes::empty());return 42;}");
}

@test fn void copy_rejects_unhandled_results_wrong_references_types_loans_and_moved_values(){
    // Must-use failures must be obligation errors, never incidental slot overflow.
    rejected(b"module main;fn i32 main(){let original=bytes::empty();bytes::copy(ref original);return 42;}",18);
    rejected(b"module main;fn i32 main(){let original=bytes::empty();let result=bytes::copy(ref original);return 42;}",18);
    // Handling does not make Result<Buffer,u8> copyable or revive its payload.
    rejected(b"module main;fn i32 main(){let original=bytes::empty();let result=bytes::copy(ref original);_ = result.is_ok;let moved=result;_ = moved;_ = result.is_ok;return 42;}",3);
    rejected(b"module main;fn i32 main(){let original=bytes::empty();switch(bytes::copy(ref original)){case .ok(owner):{let moved=owner;_ = bytes::len(ref owner);}case .err(_):{}}return 42;}",3);
    rejected(b"module main;fn i32 main(){let original=bytes::empty();let result=bytes::copy(ref original);switch(result){case .ok(_):{}case .err(_):{}}_ = result.is_ok;return 42;}",3);
    rejected(b"module main;fn i32 main(){let original=bytes::empty();let moved=original;_ = bytes::copy(ref original);return 42;}",3);
    // Shared syntax is explicit; mut and non-Buffer receivers are not admitted.
    rejected(b"module main;fn i32 main(){let original=bytes::empty();_ = bytes::copy(original);return 42;}",3);
    rejected(b"module main;fn i32 main(){var original=bytes::empty();_ = bytes::copy(ref mut original);return 42;}",3);
    rejected(b"module main;fn i32 main(){let number=42;_ = bytes::copy(ref number);return 42;}",3);
    rejected(b"module main;fn i32 main(){let original=bytes::empty();let result=bytes::copy(ref original);_ = bytes::copy(ref result);return 42;}",3);
    // Both Result domains must match exactly, including propagation's error node.
    rejected(b"module main;fn i32 main(){let original=bytes::empty();let Result<usize,u8> result=bytes::copy(ref original);_ = result;return 42;}",3);
    rejected(b"module main;fn i32 main(){let original=bytes::empty();let Result<Buffer,bool> result=bytes::copy(ref original);_ = result;return 42;}",3);
    rejected(b"module main;fn Result<usize,bool> length(){let original=bytes::empty();let owner=bytes::copy(ref original)?;return .ok(bytes::len(ref owner));}fn i32 main(){return 42;}",3);
    // The outer mutable argument loan is live while its later argument is parsed.
    rejected(b"module main;fn i32 main(){var original=bytes::empty();_ = bytes::push(ref mut original,switch(bytes::copy(ref original)){case .ok(_):{42}case .err(_):{0}});return 42;}",3);
}
