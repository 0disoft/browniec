module tests::m2::slice_result_ir;
import compiler as compiler;
import slice_result_ir as results;
import slice_result_verifier as proof;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn results::Program lowered(ref u8[] source){
    return switch(compiler::inspect_slice_result_ir(source)){
        case .ok(p):{p}
        case .err(_):{assert(false);results::Program{.body=ir::empty(),.elements=[0;16],.parameters=[0;16]}}
    };
}
fn results::Program shared(){return lowered(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q){return ref p;}fn i32 main(){return 42;}");}
fn usize opcode(ref results::Program p,u8 op){var usize pc=0;while(pc<p.body.count){if(p.body.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;}
fn void rejected(ref results::Program p){
    switch(proof::inspect(p)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
}
fn void proved(ref u8[] source,u8 selected){
    let results::Program p=lowered(source);
    let proof::Proof valid=switch(proof::inspect(ref p)){case .ok(v):{v}case .err(_):{assert(false);proof::Proof{.parameters=[0;16],.preparations=0,.forwards=0,.returns=0,.rounds=0}}};
    assert(valid.parameters[0]==selected && valid.preparations==valid.returns && valid.returns>0);
    assert(!compiler::compile(source).is_ok && !verifier::verify(ref p.body).is_ok);
    assert(!vm::run(ref p.body,1000000).is_ok);
}

@test
fn void exact_six_scalar_modes_have_explicit_nonexecuting_result_recipes(){
    proved(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref mut i32[] f(ref mut i32[] p){return ref mut p;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref bool[] f(ref bool[] p){return ref p;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref mut bool[] f(ref mut bool[] p){return ref mut p;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref i64[] f(ref i64[] p){return ref p;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref mut i64[] f(ref mut i64[] p){return ref mut p;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref u8[] f(ref u8[] p){return ref p;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref mut u8[] f(ref mut u8[] p){return ref mut p;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref u32[] f(ref u32[] p){return ref p;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref mut u32[] f(ref mut u32[] p){return ref mut p;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref usize[] f(ref usize[] p){return ref p;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref mut usize[] f(ref mut usize[] p){return ref mut p;}fn i32 main(){return 42;}",1);
}

@test
fn void lexical_subviews_branches_and_cleanup_keep_one_origin(){
    proved(b"module main;fn ref i32[] f(ref i32[] p,bool b){if(b){return ref p;}let ref i32[] q=ref p[1..];return ref q;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref mut i32[] f(ref mut i32[] p,bool b){while(b){let ref mut i32[] q=ref mut p;return ref mut q;}return ref mut p;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref i32[] f(i32 n,ref i32[] p,Option<bool> o){switch(o){case .some(_):{return ref p;}case .none:{return ref p;}}}fn i32 main(){return 42;}",2);
}

@test
fn void forwarded_results_remap_inputs_and_ground_recursive_summaries(){
    proved(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q){return g(ref q,ref p);}fn ref i32[] g(ref i32[] a,ref i32[] b){return ref b;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref mut i32[] f(ref mut i32[] p,ref mut i32[] q){return g(ref mut q,ref mut p);}fn ref mut i32[] g(ref mut i32[] a,ref mut i32[] b){return ref mut b;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref i32[] f(ref i32[] p){return g(ref [42;1],ref p);}fn ref i32[] g(ref i32[] a,ref i32[] b){return ref b;}fn i32 main(){return 42;}",1);
    proved(b"module main;fn ref mut i32[] f(ref mut i32[] p,i32 n){if(n==0){return ref mut p;}return f(ref mut p,n-1);}fn i32 main(){return 42;}",1);
    let results::Program p=lowered(b"module main;fn ref i32[] f(ref i32[] p){return g(ref p);}fn ref i32[] g(ref i32[] p){return ref p;}fn i32 main(){return 42;}");
    assert(opcode(ref p,64)<p.body.count);
    switch(proof::inspect(ref p)){case .ok(v):{assert(v.forwards==1 && v.preparations==2 && v.returns==2);}case .err(_):{assert(false);}};
}

@test
fn void claimed_origins_types_modes_and_unused_metadata_are_not_trusted(){
    var results::Program p=shared();p.parameters[0]=2;rejected(ref p);
    p=shared();p.parameters[0]=0;rejected(ref p);
    p=shared();p.parameters[0]=9;rejected(ref p);
    p=shared();p.elements[0]=129;rejected(ref p);
    p=shared();p.elements[0]=10;rejected(ref p);
    p=shared();p.elements[15]=1;p.parameters[15]=1;rejected(ref p);
    p=shared();p.parameters[15]=1;rejected(ref p);
    p=shared();let usize entry=p.body.entry;p.elements[entry]=1;p.parameters[entry]=1;rejected(ref p);
}

@test
fn void scalar_laundering_and_reserved_result_bytes_reject(){
    var results::Program p=shared();var usize at=opcode(ref p,63);p.body.code[at*8]=57;rejected(ref p);
    p=shared();at=opcode(ref p,65);p.body.code[at*8]=8;rejected(ref p);
    p=shared();at=opcode(ref p,63);p.body.code[at*8+3]=1;rejected(ref p);
    p=shared();at=opcode(ref p,63);p.body.code[at*8+4]=1;rejected(ref p);
    p=shared();at=opcode(ref p,65);p.body.code[at*8+7]=1;rejected(ref p);
    p=shared();at=opcode(ref p,65);p.body.code[at*8+2]=0;rejected(ref p);
}

@test
fn void forwarding_cannot_hide_ordinary_calls_or_change_selected_actual(){
    var results::Program p=lowered(b"module main;fn ref i32[] f(ref i32[] p,ref i32[] q){return g(ref q,ref p);}fn ref i32[] g(ref i32[] a,ref i32[] b){return ref b;}fn i32 main(){return 42;}");
    let usize at=opcode(ref p,64);p.body.code[at*8]=9;rejected(ref p);
    p.body.code[at*8]=64;
    let usize call=p.body.code[at*8+3] as usize;
    let u8 first=p.body.call_args[call*8];let u8 second=p.body.call_args[call*8+1];p.body.call_args[call*8]=second;p.body.call_args[call*8+1]=first;rejected(ref p);
    p.body.call_args[call*8+1]=second;p.body.call_args[call*8]=first;
    p.elements[1]=10;rejected(ref p);
}

@test
fn void invalid_sites_live_state_cfg_and_dimensions_fail_without_trapping(){
    var results::Program p=shared();let usize at=opcode(ref p,63);p.body.code[at*8+2]=16;rejected(ref p);
    p=shared();p.body.slice_roots[0]=1;rejected(ref p);
    p=shared();p.body.slice_origins[0]=0;rejected(ref p);
    p=shared();p.body.count=257;rejected(ref p);
    p=shared();p.body.function_count=17;rejected(ref p);
    p=shared();p.body.entry=16;rejected(ref p);
    p=shared();p.body.registers=129;rejected(ref p);
    p=shared();let usize invalid_end=p.body.count+1;p.body.ends[0]=invalid_end;rejected(ref p);
    p=shared();p.body.arrays.count=17;rejected(ref p);
    p=shared();p.body.code[(at+1)*8]=19;p.body.code[(at+1)*8+1]=0;
    p.body.code[(at+1)*8+2]=63;rejected(ref p);
}

@test
fn void preparation_cannot_be_used_as_a_scalar_even_in_valid_normalized_ir(){
    var results::Program p=lowered(b"module main;fn ref i32[] f(ref i32[] p){let i32 n=1;return ref p;}fn i32 main(){return 42;}");
    let usize prepare=opcode(ref p,63);let usize constant=opcode(ref p,1);
    assert(constant<prepare);
    var usize i=0;while(i<8){let u8 byte=p.body.code[constant*8+i];let u8 selected=p.body.code[prepare*8+i];p.body.code[constant*8+i]=selected;p.body.code[prepare*8+i]=byte;i+=1;}
    var ir::Program proxy=p.body;var usize pc=0;
    while(pc<proxy.count){if(proxy.code[pc*8]==63){proxy.code[pc*8]=57;}else if(proxy.code[pc*8]==65){proxy.code[pc*8]=8;}pc+=1;}
    assert(verifier::verify(ref proxy).is_ok);
    rejected(ref p);
}

@test
fn void prepared_views_must_be_live_and_unsuspended_at_selection(){
    var results::Program p=lowered(b"module main;fn ref mut i32[] f(ref mut i32[] p){let ref mut i32[] q=ref mut p;return ref mut q;}fn i32 main(){return 42;}");
    let usize prepare=opcode(ref p,63);p.body.code[prepare*8+2]=0;rejected(ref p);
    p=shared();let usize at=opcode(ref p,63);
    // Close the exact selected formal where preparation used to be; keep the
    // terminal's identity so definite-initialization/loan proof must reject.
    let u8 site=p.body.code[at*8+2];p.body.code[at*8]=56;p.body.code[at*8+1]=site;p.body.code[at*8+2]=0;
    rejected(ref p);
}

@test
fn void unsafe_sources_stay_rejected_and_ordinary_programs_stay_ordinary(){
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] f(ref i32[] p){return f(ref p);}fn i32 main(){return 42;}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] f(ref i32[] p){return g(ref [42;1]);}fn ref i32[] g(ref i32[] p){return ref p;}fn i32 main(){return 42;}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] f(ref mut i32[] p){let ref mut i32[] q=ref mut p;return ref mut p;}fn i32 main(){return 42;}").is_ok);
    let results::Program p=lowered(b"module main;fn i32 main(){return 42;}");
    assert(verifier::verify(ref p.body).is_ok);
    switch(proof::inspect(ref p)){case .ok(v):{assert(v.preparations==0 && v.forwards==0 && v.returns==0);}case .err(_):{assert(false);}};
}
