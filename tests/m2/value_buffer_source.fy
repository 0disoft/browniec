module tests::m2::value_buffer_source;
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
fn void rejected(ref u8[] input){
    assert(switch(source::compile(input)){case .ok(_):{false}case .err(e):{e.offset<=input.len}});
}

@test fn void six_buffer_operations_execute_with_exact_bytes_lengths_and_private_results(){
    // All six operations execute; reserve preserves length and append preserves source.
    value(b"module main;fn i32 main(){var Buffer b=bytes::empty();var s=bytes::empty();_ = bytes::reserve(ref mut b,8);_ = bytes::push(ref mut b,7);bytes::write(ref mut b,0,40);_ = bytes::push(ref mut s,2);let Result<usize,u8> r=bytes::append(ref mut b,ref s);if(!r.is_ok){return 0;}if(bytes::len(ref b)!=2){return 0;}if(bytes::len(ref s)!=1){return 0;}if(bytes::read(ref b,0)!=40){return 0;}if(bytes::read(ref b,1)!=2){return 0;}if(bytes::read(ref s,0)!=2){return 0;}return 42;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();let r=brownie::bytes::reserve(ref mut b,0);if(!r.is_ok){return 0;}_ = brownie::bytes::push(ref mut b,1);brownie::bytes::write(ref mut b,0,42);if(brownie::bytes::len(ref b)==1 && brownie::bytes::read(ref b,0)==42){return 42;}return 0;}");
    // Growth publishes exact usize payloads, including a zero-length append.
    value(b"module main;fn i32 main(){var b=bytes::empty();let s=bytes::empty();let usize n=switch(bytes::push(ref mut b,42)){case .ok(n):{n}case .err(_):{0}};let usize m=switch(bytes::append(ref mut b,ref s)){case .ok(appended):{appended}case .err(_):{0}};if(n==1 && m==1 && bytes::read(ref b,0)==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();let usize n=switch(bytes::reserve(ref mut b,16)){case .ok(n):{n}case .err(_):{0}};if(n>=16 && bytes::len(ref b)==0){return 42;}return 0;}");
    // Temporary owned receivers are released after either shared operation.
    value(b"module main;fn i32 main(){if(bytes::len(ref bytes::empty())==0){return 42;}return 0;}");
    value(b"module main;fn Buffer make(){var b=bytes::empty();_ = bytes::push(ref mut b,42);return b;}fn i32 main(){if(bytes::read(ref make(),0)==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){if(bytes::push(ref mut bytes::empty(),42).is_ok){return 42;}return 0;}");
}

@test fn void buffer_borrows_compose_with_forward_calls_control_flow_and_result_obligations(){
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,1);bytes::write(ref mut b,index(),byte());if(bytes::read(ref b,0)==42){return 42;}return 0;}fn usize index(){return 0;}fn u8 byte(){return 42;}");
    // Distinct-owner effects make evaluation count observable, with no casts.
    value(b"module main;fn i32 main(){var b=bytes::empty();var count=bytes::empty();_ = bytes::push(ref mut b,0);bytes::write(ref mut b,if(true){_ = bytes::push(ref mut count,1);0}else{0},42);if(bytes::len(ref count)==1 && bytes::read(ref b,0)==42){return 42;}return 0;}");
    // A nested shared borrow keeps the same owner alive throughout the expression.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);if(bytes::read(ref b,bytes::len(ref b)-1)==42){return 42;}return 0;}");
    value(b"module main;fn Buffer make(){var b=bytes::empty();_ = bytes::push(ref mut b,42);return b;}fn i32 main(){if(bytes::read(ref make(),bytes::len(ref make())-1)==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var b=if(true){bytes::empty()}else{bytes::empty()};var n=0;while(n<2){_ = bytes::push(ref mut b,42);n+=1;}for(var i=0;i<2;i+=1){bytes::write(ref mut b,if(i==0){0}else{1},42);}if(bytes::len(ref b)==2 && bytes::read(ref b,1)==42){return 42;}return 0;}");
    // Successful propagation releases the loan before another mutation or move.
    value(b"module main;fn Result<usize,u8> fill(){var b=bytes::empty();let usize n=bytes::push(ref mut b,42)?;_ = bytes::reserve(ref mut b,8);let moved=b;return .ok(bytes::len(ref moved)+n);}fn i32 main(){switch(fill()){case .ok(n):{if(n==2){return 42;}return 0;}case .err(_):{return 0;}}}");
    // A later scalar argument propagates out while the mutable receiver is borrowed.
    value(b"module main;fn Result<u8,u8> fail(){return .err(1);}fn Result<usize,u8> f(){var b=bytes::empty();_ = bytes::push(ref mut b,fail()?);return .ok(0);}fn i32 main(){switch(f()){case .ok(_):{return 0;}case .err(e):{if(e==1){return 42;}return 0;}}}");
    value(b"module main;fn Result<u8,u8> byte(){return .ok(42);}fn Result<usize,u8> f(){var b=bytes::empty();_ = bytes::push(ref mut b,byte()?);_ = bytes::push(ref mut b,1);return .ok(bytes::len(ref b));}fn i32 main(){switch(f()){case .ok(n):{if(n==2){return 42;}return 0;}case .err(_):{return 0;}}}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,if(true){return 42;}else{0});return 0;}");
    // Inner loop exits restore the enclosing argument loan until PUSH completes.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,if(true){while(true){break;}42}else{0});if(bytes::read(ref b,0)==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,if(true){var n=0;while(n<1){n+=1;continue;}42}else{0});if(bytes::read(ref b,0)==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();{let r=bytes::push(ref mut b,42);if(!r.is_ok){return 0;}}let moved=b;if(bytes::len(ref moved)==1){return 42;}return 0;}");
    // Temporary source is distinct and dies after append; the destination survives.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);_ = bytes::append(ref mut b,ref bytes::empty());if(bytes::read(ref b,0)==42){return 42;}return 0;}");
}

@test fn void invalid_buffer_receivers_types_moves_shadowing_and_overlapping_loans_reject(){
    rejected(b"module main;fn i32 main(){let b=bytes::empty();_ = bytes::len(b);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(b,42);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref b,42);return 42;}");
    rejected(b"module main;fn i32 main(){let b=bytes::empty();_ = bytes::push(ref mut b,42);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();bytes::write(ref b,0,42);return 42;}");
    // Self append rejects even when no bytes would be copied.
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::append(ref mut b,ref b);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,1);_ = bytes::append(ref mut b,ref b);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let moved=b;_ = bytes::len(ref b);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = b;_ = bytes::push(ref mut b,42);return 42;}");
    rejected(b"module main;fn i32 main(){let b=42;_ = bytes::len(ref b);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::read(ref b,true);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let i32 n=0;_ = bytes::read(ref b,n);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let usize n=42;_ = bytes::push(ref mut b,n);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::reserve(ref mut b,true);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let s=42;_ = bytes::append(ref mut b,ref s);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let bytes=42;_ = bytes::len(ref b);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let brownie=42;_ = brownie::bytes::len(ref b);return 42;}");
    // The outer mut loan starts before parsing every later argument.
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,bytes::read(ref b,0));return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::reserve(ref mut b,bytes::len(ref b));return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();bytes::write(ref mut b,bytes::len(ref b),42);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,if(true){_ = bytes::push(ref mut b,1);42}else{42});return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,if(true){let moved=b;42}else{42});return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,if(true){while(true){break;}bytes::read(ref b,0)}else{42});return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();bytes::push(ref mut b,42);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let r=bytes::reserve(ref mut b,8);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let s=bytes::empty();bytes::append(ref mut b,ref s);return 42;}");
}
