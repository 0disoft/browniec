module tests::m2::slice_parameters;
import ir as ir;
import errors as errors;
import slice_parameters as parameters;
import verifier as verifier;
import vm as vm;
import compiler as compiler;

fn usize built(Result<usize,errors::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } }; }
fn void invalid(ref ir::Program p) { assert(switch(parameters::metadata(p)) { case .ok(_): { false } case .err(e): { e.kind==5 && e.offset==0 } }); }
fn void rejected(ref ir::Program p,usize parameter,usize source,usize caller,usize live) {
    assert(switch(parameters::argument(p,parameter,source,caller,live,77)) { case .ok(_): { false } case .err(e): { e.kind==5 && e.offset==77 } });
}
fn ir::Program program() {
    var ir::Program p=ir::empty(); p.function_count=2; p.entry=1; p.arities[0]=1;
    p.registers=1; p.slice_parameters[0]=1; p.slice_origins[0]=1; p.slice_functions[0]=1;
    p.slice_origins[1]=1; p.slice_functions[1]=1; p.slice_elements[0]=10; p.slice_elements[1]=10;
    let usize value=built(ir::literal(ref mut p,42,0)); let usize ret=built(ir::emit(ref mut p,8,value,0,0));
    let usize end=p.count; let usize registers=p.registers; p.ends[0]=end; p.register_ends[0]=registers; p.return_types[0]=1;
    p.starts[1]=end; p.register_starts[1]=registers;
    let usize answer=built(ir::literal(ref mut p,42,0)); let usize returned=built(ir::emit(ref mut p,8,answer,0,0));
    let usize finish=p.count; let usize limit=p.registers; p.ends[1]=finish; p.register_ends[1]=limit; p.return_types[1]=1;
    let usize root=built(ir::array_in(ref mut p,1,10,4,true,0)); p.slice_roots[2]=1;
    return p;
}

@test
fn void borrowed_anchors_and_derived_origins_are_separate_from_owned_array_shapes() {
    let ir::Program p=program(); assert(built(parameters::metadata(ref p))==1);
    let usize one=1; assert(built(parameters::initial(ref p,0))==(one<<32) && built(parameters::initial(ref p,1))==0);
    assert(built(parameters::argument(ref p,0,162,1,(one<<34)|1,77))==2);
    assert(built(parameters::argument(ref p,0,160,0,one<<32,77))==0);
    // A retained child can outlive its anchor ticket, without claiming array ownership.
    assert(built(parameters::argument(ref p,0,161,0,one<<33,77))==1);
    assert(p.types[0]==0 && p.array_parameters[0]==0 && p.slice_roots[0]==0 && p.slice_roots[1]==0);
}

@test
fn void malformed_parameter_slots_partitions_origins_cycles_and_mixed_kinds_are_rejected() {
    let ir::Program p=program(); var usize i=0;
    while(i<28) {
        var ir::Program bad=p;
        if(i==0) { bad.slice_parameters[0]=17; } else if(i==1) { bad.slice_parameters[0]=0; }
        else if(i==2) { bad.slice_parameters[1]=1; } else if(i==3) { bad.slice_origins[0]=2; }
        else if(i==4) { bad.slice_origins[1]=2; } else if(i==5) { bad.slice_functions[1]=2; }
        else if(i==6) { bad.slice_roots[1]=1; } else if(i==7) { bad.slice_functions[0]=0; }
        else if(i==8) { bad.slice_origins[0]=17; } else if(i==9) { bad.slice_functions[0]=3; }
        else if(i==10) { bad.types[0]=10; } else if(i==11) { bad.slots[0]=true; }
        else if(i==12) { bad.array_parameters[0]=1; } else if(i==13) { bad.record_parameters[0]=1; }
        else if(i==14) { bad.slice_parameters[127]=1; } else if(i==15) { bad.slice_functions[3]=1; }
        else if(i==16) { bad.slice_origins[3]=1; } else if(i==17) { bad.register_starts[1]=1; }
        else if(i==18) { bad.arities[0]=3; } else if(i==19) { bad.arities[1]=1; }
        else if(i==20) { bad.registers=129; } else if(i==21) { bad.function_count=17; }
        else if(i==22) { bad.entry=16; } else if(i==23) { bad.arrays.count=17; }
        else if(i==24) { bad.slice_origins[0]=0; } else if(i==25) { bad.slice_parameters[0]=2; }
        else if(i==26) { bad.slice_parameters[0]=0; bad.slice_origins[0]=0; bad.slice_functions[0]=0; }
        else { bad.function_count=0; }
        invalid(ref bad); i+=1;
    }
    var ir::Program duplicate=p; duplicate.arities[0]=2; duplicate.slice_parameters[1]=1; duplicate.types[1]=0; invalid(ref duplicate);
}

@test
fn void arguments_require_live_function_owned_u8_sources_and_not_scalar_or_record_encodings() {
    let ir::Program p=program(); let usize one=1; let usize live=(one<<34)|1;
    rejected(ref p,0,162,1,one<<34); rejected(ref p,0,162,1,1); rejected(ref p,0,162,0,live);
    rejected(ref p,0,161,1,one<<33); rejected(ref p,0,163,1,one<<35);
    rejected(ref p,0,159,1,live); rejected(ref p,0,176,1,live); rejected(ref p,0,144,1,live);
    rejected(ref p,0,128,1,live); rejected(ref p,0,2,1,live); rejected(ref p,128,162,1,live);
    rejected(ref p,1,162,1,live); rejected(ref p,0,162,16,live);
    var ir::Program bad=p; bad.arrays.elements[0]=1; rejected(ref bad,0,162,1,live);
    assert(!parameters::initial(ref p,16).is_ok);
}

@test
fn void all_sixteen_sites_fit_and_metadata_never_bypasses_complete_verification() {
    var ir::Program p=ir::empty(); p.function_count=3; p.entry=2; p.registers=17;
    p.register_ends[0]=8; p.register_starts[1]=8; p.register_ends[1]=16; p.register_starts[2]=16; p.register_ends[2]=17;
    p.arities[0]=8; p.arities[1]=8; p.types[16]=1;
    var usize i=0; var u8 encoded=1;
    while(i<16) { p.slice_parameters[i]=encoded; p.slice_origins[i]=encoded; p.slice_functions[i]=if(i<8){1}else{2}; p.slice_elements[i]=10; i+=1; encoded+=1; }
    assert(built(parameters::metadata(ref p))==65535); let usize one=1; let usize low=255;
    assert(built(parameters::initial(ref p,0))==(low<<32) && built(parameters::initial(ref p,1))==(low<<40));
    assert(built(parameters::argument(ref p,0,175,1,one<<47,77))==15);
    let ir::Program future=program(); assert(built(parameters::metadata(ref future))==1);
    assert(!verifier::verify(ref future).is_ok);
    assert(switch(vm::run_with_array_limit(ref future,0,65537)) { case .ok(_): { false } case .err(e): { e.kind==5 } });
    let ir::Program ordinary=switch(compiler::compile(b"module main;fn i32 main(){return 42;}")) { case .ok(v): { v } case .err(_): { assert(false); ir::empty() } };
    assert(built(parameters::metadata(ref ordinary))==0 && verifier::verify(ref ordinary).is_ok);
    assert(switch(vm::run(ref ordinary,100)) { case .ok(v): { v==42 } case .err(_): { false } });
    let ir::Program parsed=switch(compiler::compile(b"module main;fn i32 f(ref u8[] p){return p[0] as i32;}fn i32 main(){return 42;}")) { case .ok(v): { v } case .err(_): { assert(false); ir::empty() } };
    assert(verifier::verify(ref parsed).is_ok);
    assert(switch(vm::run(ref parsed,100)) {case .ok(v):{v==42}case .err(_):{false}});
}
