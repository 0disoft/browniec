module tests::m2::reference_inference;
import compiler as compiler;
import program_image as programs;
import ir as ir;
import vm as vm;
import verifier as verifier;
import std::bytes as bytes;

fn void value(ref u8[] source,i64 expected){
    let programs::PublicProgram p=switch(compiler::compile_program(source,65536)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    var usize i=0;while(i<2){
        switch(programs::run_public(ref p,16000000)){case .ok(n):{assert(n==expected);}case .err(_):{assert(false);}};
        i+=1;
    }
}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
};}
@test fn void literal_text_bytes_aliases_groups_and_conversions_keep_exact_kinds(){
    value(b"module main;fn i32 main(){let a=b\"*\";let b=a;let c=ref b;return c[0] as i32;}",42);
    value(b"module main;fn i32 main(){let t=\"한\";let alias=ref t;let b=text::bytes(alias);if(b.len==3){return b[0] as i32;}return 0;}",237);
    value(b"module main;fn i32 main(){let t=((\"*\"));let b=(text::bytes(t))[..];let alias=(ref b);return alias[0] as i32;}",42);
    value(b"module main;fn i32 main(){let t=\"\";let b=text::bytes(t);if(b.len==0){return 42;}return 0;}",42);
}
@test fn void scalar_projections_and_grouped_scalar_expressions_keep_scalar_inference(){
    value(b"module main;fn i32 main(){let a=b\"*\";let n=a[0];let len=a.len;if(len==1){return n as i32;}return 0;}",42);
    value(b"module main;fn i32 main(){let n=(b\"*\"[0]);let len=(b\"*\".len);if(len==1){return n as i32;}return 0;}",42);
    value(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){let n=id(ref [42;1])[0];let len=id(ref b\"*\").len;if(len==1){return n as i32;}return 0;}",42);
    value(b"module main;fn i32 main(){let a=[42;1];let n=a[0];let len=a.len;if(len==1){return n;}return 0;}",42);
}
@test fn void rooted_shared_and_exclusive_loans_keep_all_existing_scalar_elements(){
    value(b"module main;fn i32 main(){let a=[42;1];let p=ref a;let q=p;return q[0];}",42);
    value(b"module main;fn i32 main(){var bool[1] a=[false;1];{let p=ref mut a;p[0]=true;}if(a[0]){return 42;}return 0;}",42);
    value(b"module main;fn i32 main(){var i64[1] a=[-9223372036854775808;1];{let p=ref mut a;if(p[0]==-9223372036854775808){p[0]=42;}}if(a[0]==42){return 42;}return 0;}",42);
    value(b"module main;fn i32 main(){let u8[1] a=[42;1];let u32[1] b=[4294967295;1];let usize[1] c=[18446744073709551615;1];let p=ref a;let q=ref b;let r=ref c;if(q[0]==4294967295 && r[0]==18446744073709551615){return p[0] as i32;}return 0;}",42);
}
@test fn void exclusive_reborrows_restore_parent_and_shared_aliases_close_in_reverse_order(){
    value(b"module main;fn i32 main(){var a=[0;2];{let p=ref mut a;{let q=ref mut p[1..];q[0]=20;}p[0]=22;}let p=ref a;{let q=p[..1];let r=q;if(r[0]!=22){return 0;}}return p[0]+p[1];}",42);
    value(b"module main;fn i32 read(ref i32[] p){let q=p;return q[0];}fn i32 main(){var a=[0;1];{let p=ref mut a;p[0]=42;}return read(ref a);}",42);
}
@test fn void returned_views_keep_selected_temporary_owners_and_native_runtime_origins(){
    value(b"module main;fn ref u8[] id(ref u8[] p){let q=p;return ref q;}fn i32 main(){let p=id(ref [42;3]);let alias=p;let narrowed=alias[1..];if(narrowed.len==2){return narrowed[1] as i32;}return 0;}",42);
    value(b"module main;fn ref u8[] pick(ref u8[] a,ref u8[] b){return ref a;}fn i32 main(){var u8[1] a=[42;1];var u8[1] b=[0;1];let p=pick(ref a,ref b);b[0]=7;let q=ref p;if(b[0]==7){return q[0] as i32;}return 0;}",42);
    value(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){let p=(ref id(ref b\"!*\"))[1..];return p[0] as i32;}",42);
    value(b"module main;fn ref u8[] data(){let text=\"*\";let alias=text;let b=text::bytes(alias);return ref b;}fn i32 main(){let p=data();return p[0] as i32;}",42);
}
@test fn void endpoint_effects_evaluate_once_and_in_source_order(){
    value(b"module main;fn usize low(ref mut i32[] n){n[0]=n[0]+1;return 0;}fn usize high(ref mut i32[] n){n[0]=n[0]*10+2;return 1;}fn i32 main(){var n=[0;1];let a=[30;1];let p=ref a[low(ref mut n)..high(ref mut n)];return n[0]+p[0];}",42);
    value(b"module main;fn usize low(ref mut i32[] n){n[0]=n[0]+1;return 0;}fn usize high(ref mut i32[] n){n[0]=n[0]*10+2;return 1;}fn i32 main(){var n=[0;1];let p=b\"\\x1E\"[low(ref mut n)..high(ref mut n)];return n[0]+(p[0] as i32);}",42);
}
@test fn void pending_returned_owners_cleanup_on_return_propagation_and_loop_exits(){
    value(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){let Option<i32> o=.none;let p=id(ref [42;2])[..switch(o){case .some(v):{1}case .none:{return 42;}}];return 0;}",42);
    value(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn Option<i32> f(Option<i32> o){let p=id(ref [42;2])[..switch(o){case .some(v):{1}case .none:{let n=o?;1}}];return .some(p[0] as i32);}fn i32 main(){switch(f(.none)){case .some(_):{return 0;}case .none:{return 42;}}}",42);
    value(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){let Option<i32> o=.none;var n=0;while(n<2){let p=id(ref [42;2])[..switch(o){case .some(v):{1}case .none:{n=n+1;continue;}}];}while(true){let p=id(ref [42;2])[switch(o){case .some(v):{0}case .none:{break;}}..];}return n+40;}",42);
}
@test fn void inferred_references_do_not_grant_access_rebind_escape_or_change_kinds(){
    rejected(b"module main;fn i32 main(){let a=[0;1];let p=ref mut a;return 0;}",3);
    rejected(b"module main;fn i32 main(){let p=ref mut b\"*\";return 0;}",3);
    rejected(b"module main;fn i32 main(){var p=b\"*\";return 0;}",3);
    rejected(b"module main;fn i32 main(){let a=[0;1];var p=ref a;return 0;}",3);
    rejected(b"module main;fn i32 main(){let p=b\"*\";p=b\"!\";return 0;}",3);
    rejected(b"module main;fn i32 main(){let t=\"*\";let ref u8[] b=t;return 0;}",3);
    rejected(b"module main;fn i32 main(){let t=\"*\";return t[0] as i32;}",3);
    rejected(b"module main;fn i32 main(){{let p=b\"*\";}let q=p;return 0;}",3);
    rejected(b"module main;fn i32 main(){let p=ref p;return 0;}",3);
    rejected(b"module main;fn i32 main(){var a=[0;1];let p=ref mut a;let q=p;return 0;}",3);
    rejected(b"module main;fn ref u8[] bad(){let u8[1] a=[42;1];let p=ref a;return ref p;}fn i32 main(){return 0;}",3);
}
@test fn void retained_aliases_preserve_owner_exclusion_until_the_last_live_alias(){
    rejected(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[42;1];let p=id(ref a);let q=p;a[0]=0;return q[0] as i32;}",5);
    rejected(b"module main;fn i32 main(){var a=[42;1];let p=ref a;let q=p;let r=ref mut a;return q[0];}",5);
    value(b"module main;fn ref u8[] id(ref u8[] p){return ref p;}fn i32 main(){var u8[1] a=[0;1];{let p=id(ref a);let q=p;let n=q[0];}a[0]=42;return a[0] as i32;}",42);
}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){
    case .ok(p):{p}case .err(_):{assert(false);ir::empty()}
};}
@test fn void inferred_native_loans_emit_the_same_ir_and_charge_the_same_exact_fuel(){
    let ir::Program a=compiled(b"module main;fn i32 main(){var i32[1] a=[0;1];{let ref mut i32[] p=ref mut a;p[0]=42;}let ref i32[] p=ref a;let ref i32[] q=ref p;return q[0];}");
    let ir::Program b=compiled(b"module main;fn i32 main(){var i32[1] a=[0;1];{let p=ref mut a;p[0]=42;}let p=ref a;let q=p;return q[0];}");
    assert(verifier::verify(ref a).is_ok && verifier::verify(ref b).is_ok);
    assert(a.count==b.count && a.registers==b.registers && a.constant_count==b.constant_count);
    var usize i=0;while(i<a.count*8){assert(a.code[i]==b.code[i]);i+=1;}
    i=0;while(i<a.registers){assert(a.types[i]==b.types[i] && a.slots[i]==b.slots[i]);i+=1;}
    i=0;while(i<a.constant_count){assert(a.constants[i]==b.constants[i]);i+=1;}
    // 64KiB preparation, one i32 initialization/drop, three OPEN/SUBs,
    // one length, three CLOSEs, one write/read and ten scalar instructions.
    let usize fuel=65537+68+49+65537*3+4097*4+4138+4134+10;
    switch(vm::run(ref b,fuel)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
    switch(vm::run(ref b,fuel-1)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
}
@test fn void inferred_retained_aliases_preserve_annotated_ir_and_independent_exact_fuel(){
    let programs::PublicProgram a=switch(compiler::compile_program(
        b"module main;fn i32 main(){let ref u8[] a=b\"*\";let ref u8[] alias=a;return alias[0] as i32;}",65536)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    let programs::PublicProgram b=switch(compiler::compile_program(
        b"module main;fn i32 main(){let a=b\"*\";let alias=a;return alias[0] as i32;}",65536)){
        case .ok(p):{p}case .err(_):{assert(false);return;}
    };
    let ref ir::Program left=programs::public_body(ref a);let ref ir::Program right=programs::public_body(ref b);
    assert(left.count==right.count && left.registers==right.registers && left.constant_count==right.constant_count);
    var usize i=0;while(i<left.count*8){assert(left.code[i]==right.code[i]);i+=1;}
    // Entry147456+leave196608+OPEN17+ALIAS17+index1+READ18+cast1+
    // two CLOSE dispatches+RETURN dispatch =344121, without price helpers.
    switch(programs::run_public(ref a,344121)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
    switch(programs::run_public(ref b,344121)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
    switch(programs::run_public(ref b,344120)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(programs::run_public(ref b,344122)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
}
fn void append(ref mut bytes::Buffer b,ref u8[] text){assert(bytes::append(b,text).is_ok);}
fn void site_limit(usize count,bool pass){
    var bytes::Buffer source=bytes::empty();append(ref mut source,b"module main;fn i32 main(){let a=b\"*\";");
    let ref u8[] letters=b"abcdefghijklmnopq";var usize i=1;
    while(i<count){append(ref mut source,b"let v");append(ref mut source,letters[i..i+1]);append(ref mut source,b"=a;");i+=1;}
    append(ref mut source,b"return 42;}");
    if(pass){value(bytes::view(ref source),42);}else{rejected(bytes::view(ref source),4);}
}
@test fn void inferred_static_aliases_preserve_the_sixteen_site_limit(){
    site_limit(16,true);site_limit(17,false);
}
