module tests::m2::value_safe_casts_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;
import ir as ir;
import compiler as public_compiler;

fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(p):{p}case .err(_):{assert(false);compiled(input)}
};}
fn void value(ref u8[] input){
    let values::Program p=compiled(input);assert(verifier::inspect_values(ref p).is_ok);
    let growth::Limits limits=growth::Limits{.object=4096,.instance=1048576,.engine=1048576};
    assert(switch(vm::run_values(ref p,10000000,0,limits)){case .ok(v):{v==42}case .err(_):{false}});
}
fn void rejected(ref u8[] input){assert(switch(source::compile(input)){
    case .ok(_):{false}case .err(e):{e.kind==3 && e.offset<=input.len}
});}
fn void invalid(ref u8[] input){assert(!source::compile(input).is_ok);}
fn usize count(ref values::Program p,u8 op){let ref ir::Program body=ref p.body;
    var usize i=0;var usize n=0;while(i<body.count){if(body.code[i*8]==op){n+=1;}i+=1;}return n;
}
fn void pair(ref u8[] input,bool allowed,u8 target){
    assert(public_compiler::compile(input).is_ok==allowed);
    if(!allowed){rejected(input);return;}
    let values::Program p=compiled(input);assert(count(ref p,26)==1);
    let ref ir::Program body=ref p.body;var usize i=0;
    while(i<body.count){if(body.code[i*8]==26){assert(body.types[body.code[i*8+1] as usize]==target);}i+=1;}
    value(input);
}

@test fn void every_scalar_pair_matches_existing_strict_widening(){
    pair(b"module main;fn i32 main(){let i32 x=42;let i32 y=x as i32;_ = y;return 42;}",false,1);
    pair(b"module main;fn i32 main(){let i32 x=42;let i64 y=x as i64;_ = y;return 42;}",true,9);
    pair(b"module main;fn i32 main(){let i32 x=42;let u8 y=x as u8;_ = y;return 42;}",false,10);
    pair(b"module main;fn i32 main(){let i32 x=42;let u32 y=x as u32;_ = y;return 42;}",false,11);
    pair(b"module main;fn i32 main(){let i32 x=42;let usize y=x as usize;_ = y;return 42;}",false,12);
    pair(b"module main;fn i32 main(){let i32 x=42;let bool y=x as bool;_ = y;return 42;}",false,2);
    pair(b"module main;fn i32 main(){let i64 x=42;let i32 y=x as i32;_ = y;return 42;}",false,1);
    pair(b"module main;fn i32 main(){let i64 x=42;let i64 y=x as i64;_ = y;return 42;}",false,9);
    pair(b"module main;fn i32 main(){let i64 x=42;let u8 y=x as u8;_ = y;return 42;}",false,10);
    pair(b"module main;fn i32 main(){let i64 x=42;let u32 y=x as u32;_ = y;return 42;}",false,11);
    pair(b"module main;fn i32 main(){let i64 x=42;let usize y=x as usize;_ = y;return 42;}",false,12);
    pair(b"module main;fn i32 main(){let i64 x=42;let bool y=x as bool;_ = y;return 42;}",false,2);
    pair(b"module main;fn i32 main(){let u8 x=42;let i32 y=x as i32;_ = y;return 42;}",true,1);
    pair(b"module main;fn i32 main(){let u8 x=42;let i64 y=x as i64;_ = y;return 42;}",true,9);
    pair(b"module main;fn i32 main(){let u8 x=42;let u8 y=x as u8;_ = y;return 42;}",false,10);
    pair(b"module main;fn i32 main(){let u8 x=42;let u32 y=x as u32;_ = y;return 42;}",true,11);
    pair(b"module main;fn i32 main(){let u8 x=42;let usize y=x as usize;_ = y;return 42;}",true,12);
    pair(b"module main;fn i32 main(){let u8 x=42;let bool y=x as bool;_ = y;return 42;}",false,2);
    pair(b"module main;fn i32 main(){let u32 x=42;let i32 y=x as i32;_ = y;return 42;}",false,1);
    pair(b"module main;fn i32 main(){let u32 x=42;let i64 y=x as i64;_ = y;return 42;}",true,9);
    pair(b"module main;fn i32 main(){let u32 x=42;let u8 y=x as u8;_ = y;return 42;}",false,10);
    pair(b"module main;fn i32 main(){let u32 x=42;let u32 y=x as u32;_ = y;return 42;}",false,11);
    pair(b"module main;fn i32 main(){let u32 x=42;let usize y=x as usize;_ = y;return 42;}",true,12);
    pair(b"module main;fn i32 main(){let u32 x=42;let bool y=x as bool;_ = y;return 42;}",false,2);
    pair(b"module main;fn i32 main(){let usize x=42;let i32 y=x as i32;_ = y;return 42;}",false,1);
    pair(b"module main;fn i32 main(){let usize x=42;let i64 y=x as i64;_ = y;return 42;}",false,9);
    pair(b"module main;fn i32 main(){let usize x=42;let u8 y=x as u8;_ = y;return 42;}",false,10);
    pair(b"module main;fn i32 main(){let usize x=42;let u32 y=x as u32;_ = y;return 42;}",false,11);
    pair(b"module main;fn i32 main(){let usize x=42;let usize y=x as usize;_ = y;return 42;}",false,12);
    pair(b"module main;fn i32 main(){let usize x=42;let bool y=x as bool;_ = y;return 42;}",false,2);
    pair(b"module main;fn i32 main(){let bool x=true;let i32 y=x as i32;_ = y;return 42;}",false,1);
    pair(b"module main;fn i32 main(){let bool x=true;let i64 y=x as i64;_ = y;return 42;}",false,9);
    pair(b"module main;fn i32 main(){let bool x=true;let u8 y=x as u8;_ = y;return 42;}",false,10);
    pair(b"module main;fn i32 main(){let bool x=true;let u32 y=x as u32;_ = y;return 42;}",false,11);
    pair(b"module main;fn i32 main(){let bool x=true;let usize y=x as usize;_ = y;return 42;}",false,12);
    pair(b"module main;fn i32 main(){let bool x=true;let bool y=x as bool;_ = y;return 42;}",false,2);
}

@test fn void boundaries_unary_binary_and_literal_contexts(){
    value(b"module main;fn i32 main(){let u8 x=0;let i32 y=x as i32;if(y==0){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u8 x=255;let i32 y=x as i32;if(y==255){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u8 x=0;let i64 y=x as i64;if(y==0){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u8 x=255;let i64 y=x as i64;if(y==255){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u8 x=0;let u32 y=x as u32;if(y==0){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u8 x=255;let u32 y=x as u32;if(y==255){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u8 x=0;let usize y=x as usize;if(y==0){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u8 x=255;let usize y=x as usize;if(y==255){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u32 x=0;let i64 y=x as i64;if(y==0){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u32 x=4294967295;let i64 y=x as i64;if(y==4294967295){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u32 x=0;let usize y=x as usize;if(y==0){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u32 x=4294967295;let usize y=x as usize;if(y==4294967295){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let i32 x=-2147483648;let i64 y=x as i64;if(y==-2147483648){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let i32 x=2147483647;let i64 y=x as i64;if(y==2147483647){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u8 x=255;let i64 y=x as i32 as i64;if(y==255){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u32 x=4294967295;let i64 y=x as i64;if(y==4294967295){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u32 x=4294967295;let usize y=x as usize;if(y==4294967295){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let i64 x=-2147483648 as i64;if(x==-2147483648){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let i64 x=2147483647 as i64;if(x==2147483647){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u8 x=1;let i32 y=~x as i32;if(y==254){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u8 x=2;if(40+x as i32==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u8 x=1;let i64 y=(x as i32+41) as i64;if(y==42){return 42;}return 0;}");
    value(b"module main;fn i64 take(i64 x){return x;}fn i32 main(){let i64 x=take((40+2) as i64);if(x==42){return 42;}return 0;}");
    value(b"module main;fn i64 give(){return -42 as i64;}fn i32 main(){if(give()==-42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var i64 x=0;x=42 as i64;let Option<i64> y=.some(42 as i64);_ = y;if(x==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u8 x=0;let usize y=x as u32 as usize;if(y==0){return 42;}return 0;}");
    rejected(b"module main;fn i32 main(){let i64 x=9223372036854775807;_ = x as usize;return 42;}");
    rejected(b"module main;fn i32 main(){let usize x=18446744073709551615;_ = x as i64;return 42;}");
    rejected(b"module main;fn i32 main(){let i64 x=2147483648 as i64;return 42;}");
    rejected(b"module main;fn i32 main(){let i64 x=-9223372036854775808 as i64;return 42;}");
    rejected(b"module main;fn i32 main(){let usize x=18446744073709551615 as usize;return 42;}");
    rejected(b"module main;fn i32 main(){let u8 x=1 as u8;return 42;}");
    rejected(b"module main;fn i32 main(){let u8 x=1;let i64 y=x;return 42;}");
    rejected(b"module main;fn i32 main(){let u8 x=1;return x+41;}");
    rejected(b"module main;fn i32 main(){let u8 x=1;let i32 y=-x as i32;return 42;}");
    rejected(b"module main;fn i32 main(){let i32 x=1 as i64;return 42;}");
    rejected(b"module main;fn i32 main(){let u8 x=1;let i64 y=x as u32 as i32;return 42;}");
    rejected(b"module main;fn i64 take(i64 x){return x;}fn i32 main(){let u8 x=42;_ = take(x);return 42;}");
    rejected(b"module main;fn i64 give(){let u8 x=42;return x;}fn i32 main(){return 42;}");
}

@test fn void scalar_bindings_postfix_calls_and_control_results(){
    value(b"module main;fn u8 byte(){return 42;}fn i32 main(){return byte() as i32;}");
    value(b"module main;fn i32 main(){let u8 x=42;return if(true){x}else{x} as i32;}");
    value(b"module main;fn i32 main(){let u8 x=42;return switch(.some(x)){case .some(n):{n}case .none:{x}} as i32;}");
    value(b"module main;fn i32 main(){let Option<u8> x=.some(42);return switch(x){case .some(n):{let i32 y=n as i32;if(n==42){y}else{0}}case .none:{0}};}");
    value(b"module main;fn i32 main(){let u8 x=42;let i64 y=if(true){if(false){x}else{x} as i32}else{42} as i64;if(y==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let v=bytes::view(ref b);return v[0] as i32;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);return bytes::read(ref b,0) as i32;}");
    rejected(b"module main;fn i32 main(){let Option<u8> x=.some(42);_ = x as i32;return 42;}");
    rejected(b"module main;fn i32 main(){_ = bytes::empty() as i32;return 42;}");
    rejected(b"module main;fn void noop(){}fn i32 main(){_ = noop() as i32;return 42;}");
    rejected(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);_ = v as i32;return 42;}");
    rejected(b"module main;fn i32 main(){let b=bytes::empty();_ = bytes::view(ref b).len as i64;return 42;}");
    rejected(b"module main;fn i32 main(){let Option<u8> x=.some(42);_ = x.is_some as i32;return 42;}");
    rejected(b"module main;fn i32 main(){let u8 x=42;_ = x as Option<i32>;return 42;}");
    rejected(b"module main;fn i32 main(){let u8 x=42;_ = x as Buffer;return 42;}");
}

@test fn void effects_propagation_and_temporary_cleanup_execute_once(){
    // Header-owner 03c758a fixture, restoring the explicit index cast.
    // Return both before first rebind and after a real backedge.
    value(b"module main;fn ref u8[] id(ref u8[] v){return v;}fn Buffer make(u8 n){var b=bytes::empty();_ = bytes::push(ref mut b,n);return b;}fn i32 work(bool early){let b=make(42);var ref u8[] r=id(ref bytes::view(ref make(7)));var n=0;while(n<2){if(early || n==1){return r[0] as i32;}r=bytes::view(ref b);n+=1;}return 0;}fn i32 main(){if(work(true)==7 && work(false)==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var n=0;var b=bytes::empty();_ = bytes::push(ref mut b,42);let i64 x=bytes::view(ref b)[if(true){n+=1;0}else{0}] as i32 as i64;bytes::write(ref mut b,0,7);if(x==42 && n==1){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var n=0;let u8 x=42;let i64 y=if(true){n+=1;x}else{n+=9;x} as i32 as i64;if(y==42 && n==1){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var n=0;let u8 x=42;let i64 y=switch(.some(x)){case .some(k):{n+=1;k}case .none:{n+=9;x}} as i32 as i64;if(y==42 && n==1){return 42;}return 0;}");
    value(b"module main;fn Result<i64,u8> cv(Result<u8,u8> r){let b=bytes::empty();let v=bytes::view(ref b);_ = v.len;return .ok(r? as i32 as i64);}fn i32 main(){let Result<u8,u8> r=.ok(42);return switch(cv(r)){case .ok(n):{if(n==42){42}else{0}}case .err(_):{0}};}");
    value(b"module main;fn Result<i64,u8> cv(Result<u8,u8> r){let b=bytes::empty();let v=bytes::view(ref b);return .ok(r? as i32 as i64);}fn i32 main(){let Result<u8,u8> r=.err(7);return switch(cv(r)){case .ok(_):{0}case .err(n):{if(n==7){42}else{0}}};}");
    value(b"module main;fn Option<i64> cv(Option<u8> r){let b=bytes::empty();return .some(r? as i64);}fn i32 main(){let Option<u8> r=.none;return switch(cv(r)){case .some(_):{0}case .none:{42}};}");
    value(b"module main;fn Option<i64> cv(Option<u8> r){return .some(r? as i64);}fn i32 main(){let Option<u8> r=.some(42);return switch(cv(r)){case .some(n):{if(n==42){42}else{0}}case .none:{0}};}");
    value(b"module main;fn u8 take(Buffer b){return 42;}fn i32 main(){return take(bytes::empty()) as i32;}");
}

@test fn void bottom_validates_targets_without_reads_captures_or_widening(){
    let values::Program plain=compiled(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;};}");
    let values::Program cast=compiled(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;} as usize as bool as i32;}");
    assert(count(ref cast,26)==0 && count(ref cast,96)==0 && count(ref cast,97)==0);
    assert(cast.body.count==plain.body.count && cast.body.registers==plain.body.registers && cast.catalog.count==plain.catalog.count);
    var usize i=0;while(i<cast.body.count*8){assert(cast.body.code[i]==plain.body.code[i]);i+=1;}
    value(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;} as usize as bool as i32;}");
    value(b"module main;fn i32 main(){return switch(.some(1)){case .some(_):{return 42;}case .none:{return 0;}} as u8 as i64;}");
    value(b"module main;fn i32 main(){var n=0;while(n<2){let b=bytes::empty();let v=bytes::view(ref b);let dead=if(n==0){n+=1;continue;}else{n+=41;break;} as i64;}return n;}");
    value(b"module main;fn i32 never(Buffer b,i64 n){return 0;}fn i32 main(){return never(bytes::empty(),if(true){return 42;}else{return 0;} as i64);}");
    value(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);return -(if(true){return 42;}else{return 0;}) as i64;}");
    invalid(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;} as Option<i32>;}");
    invalid(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;} as Result<i32,bool>;}");
    invalid(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;} as Buffer;}");
    invalid(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;} as void;}");
    invalid(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;} as ref u8[];}");
    invalid(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;} as ;}");
    invalid(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;} as Missing;}");
    invalid(b"module main;fn i32 main(){return if(true){return 42;}else{return 0;} as i64 as;}");
}
