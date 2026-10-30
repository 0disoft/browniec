module tests::m2::slice_builders;
import ir as ir;
import slice_builders as builders;
import slice_parameters as parameters;
import errors as errors;
import verifier as verifier;

fn usize built(Result<usize, errors::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } }; }
fn void rejected(Result<usize, errors::Error> r, u8 kind) { assert(switch(r) { case .ok(_): { false } case .err(e): { e.kind == kind && e.offset == 77 } }); }
fn ir::Program empty() { var ir::Program p=ir::empty(); p.function_count=2; p.entry=1; p.arities[0]=1; return p; }
fn void unchanged(ref ir::Program p, ref ir::Program old) {
    assert(p.registers==old.registers && p.count==old.count && p.call_count==old.call_count);
    var usize i=0;
    while(i<16) { assert(p.slice_roots[i]==old.slice_roots[i] && p.slice_origins[i]==old.slice_origins[i] && p.slice_functions[i]==old.slice_functions[i]); i+=1; }
    i=0; while(i<128) { assert(p.slice_parameters[i]==old.slice_parameters[i] && p.types[i]==old.types[i] && p.slots[i]==old.slots[i] && p.array_parameters[i]==old.array_parameters[i] && p.record_parameters[i]==old.record_parameters[i]); i+=1; }
}

@test
fn void interleaved_owned_formal_and_derived_sites_keep_unique_flat_origins() {
    var ir::Program p=empty(); let usize root=built(ir::array_in(ref mut p,0,10,4,false,0));
    assert(built(ir::slice(ref mut p,root,0))==0);
    assert(built(builders::parameter(ref mut p,0,0))==1);
    assert(built(ir::slice(ref mut p,root,0))==2);
    assert(built(builders::derived(ref mut p,1,0,0))==3);
    assert(built(builders::derived(ref mut p,3,0,0))==4);
    assert(built(ir::slice(ref mut p,root,0))==5);
    p.register_ends[0]=1; p.register_starts[1]=1; p.register_ends[1]=1;
    assert(built(parameters::metadata(ref p))==2 && p.slice_origins[4]==2 && p.slice_roots[4]==0);
    assert(p.registers==1 && p.types[0]==0 && p.count==0 && p.call_count==0);
}

@test
fn void capacity_failures_preserve_both_namespaces_and_formal_registers() {
    var ir::Program p=empty(); let usize root=built(ir::array_in(ref mut p,0,10,4,false,0));
    let usize formal=built(builders::parameter(ref mut p,0,0));
    var usize i=1;
    while(i<16) {
        if(i%2==0) { assert(built(ir::slice(ref mut p,root,0))==i); }
        else { assert(built(builders::derived(ref mut p,formal,0,0))==i); }
        i+=1;
    }
    p.arities[0]=2; let ir::Program old=p;
    rejected(builders::parameter(ref mut p,0,77),4); unchanged(ref p,ref old);
    // Restore the completed signature before testing derived admission.
    p.arities[0]=1;
    rejected(builders::derived(ref mut p,formal,0,77),4); unchanged(ref p,ref old);
    rejected(ir::slice(ref mut p,root,77),4); unchanged(ref p,ref old);
    var ir::Program reserved=empty(); reserved.slice_functions[0]=1; reserved.slice_origins[1]=1;
    assert(built(builders::parameter(ref mut reserved,0,0))==2);
    let usize other=built(ir::array_in(ref mut reserved,0,10,1,false,0));
    assert(built(ir::slice(ref mut reserved,other,0))==3);
}

@test
fn void invalid_formal_positions_and_register_exhaustion_do_not_publish_sites() {
    var usize i=0;
    while(i<12) {
        var ir::Program p=empty(); var usize function=0;
        if(i==0) { p.registers=128; } else if(i==1) { function=16; }
        else if(i==2) { function=1; } else if(i==3) { p.function_count=17; }
        else if(i==4) { p.arities[0]=0; } else if(i==5) { p.arities[0]=9; }
        else if(i==6) { p.register_starts[0]=1; } else if(i==7) { p.registers=1; }
        else if(i==8) { p.types[0]=1; } else if(i==9) { p.slots[0]=true; }
        else if(i==10) { p.array_parameters[0]=1; } else { p.record_parameters[0]=1; }
        let ir::Program old=p; rejected(builders::parameter(ref mut p,function,77),if(i==0){4}else{3});
        unchanged(ref p,ref old); i+=1;
    }
    var ir::Program p=empty(); p.arities[0]=8; var usize n=0;
    while(n<8) { assert(built(builders::parameter(ref mut p,0,0))==n); n+=1; }
    let ir::Program old=p; rejected(builders::parameter(ref mut p,0,77),3); unchanged(ref p,ref old);
}

@test
fn void foreign_or_orphan_derived_origins_and_conflicting_formals_fail_without_mutation() {
    var ir::Program good=empty(); let usize formal=built(builders::parameter(ref mut good,0,0));
    var usize i=0;
    while(i<10) {
        var ir::Program p=good; var usize parent=formal; var usize function=0;
        if(i==0) { parent=16; } else if(i==1) { function=1; }
        else if(i==2) { p.slice_roots[0]=1; } else if(i==3) { p.slice_origins[0]=2; }
        else if(i==4) { p.slice_parameters[0]=0; } else if(i==5) { p.types[0]=10; }
        else if(i==6) { p.registers=129; } else if(i==7) { p.arities[0]=9; }
        else if(i==8) { p.register_starts[0]=2; }
        else { p.registers=2; p.arities[0]=2; p.slice_parameters[1]=1; }
        let ir::Program old=p; rejected(builders::derived(ref mut p,parent,function,77),3); unchanged(ref p,ref old); i+=1;
    }
}

@test
fn void checked_argument_bytes_feed_existing_call_tables_without_enabling_execution() {
    var ir::Program p=empty(); let usize formal=built(builders::parameter(ref mut p,0,0));
    let usize child=built(builders::derived(ref mut p,formal,0,0));
    let usize value=built(ir::literal(ref mut p,42,0)); let usize ret=built(ir::emit(ref mut p,8,value,0,0));
    let usize end=p.count; let usize regs=p.registers; p.ends[0]=end; p.register_ends[0]=regs; p.return_types[0]=1;
    p.starts[1]=end; p.register_starts[1]=regs; p.return_types[1]=1;
    let usize root=built(ir::array_in(ref mut p,1,10,4,false,0)); let usize local=built(ir::slice(ref mut p,root,0));
    let usize answer=built(ir::literal(ref mut p,42,0)); let usize done=built(ir::emit(ref mut p,8,answer,0,0));
    let usize finish=p.count; let usize limit=p.registers; p.ends[1]=finish; p.register_ends[1]=limit;
    assert(built(parameters::metadata(ref p))==1); let usize one=1;
    let usize owned=built(builders::argument(ref p,0,local,1,1|(one<<34),0));
    let usize forwarded=built(builders::argument(ref p,0,child,0,one<<33,0));
    assert(owned==162 && forwarded==161);
    let usize[2] args=[owned,forwarded]; let usize call=built(ir::call(ref mut p,0,ref args,0));
    assert(p.call_args[0]==162 && p.call_args[1]==161 && p.call_arities[0]==2 && p.code[32]==9);
    rejected(builders::argument(ref p,0,16,0,one<<32,77),5);
    rejected(builders::argument(ref p,0,child,1,one<<33,77),5);
    rejected(builders::argument(ref p,0,local,1,one<<34,77),5);
    assert(!verifier::verify(ref p).is_ok);
}
