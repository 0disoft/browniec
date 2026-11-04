module tests::m2::slice_result_capture_chains;
import compiler as compiler;
import ir as ordinary;
import slice_result_ir as ir;
import slice_result_verifier as proof;
import slice_result_call_ir as recipes;
import slice_result_runtime as runtime;
import array_owners as owners;
import array_slices as slices;
import array_layout as layout;
import vm as vm;
import errors as errors;
import render as render;

// Source currently names these intermediates. Move their canonical ENDs into
// the final CALL recipe to model anonymous returned actuals without bypassing
// independent CFG/loan/origin proof. This is a straight-line IR fixture.
fn Result<ir::Program,errors::Error> build(bool second){
    var ir::Program unit=compiler::inspect_slice_result_ir(if(second){
        b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn ref mut i32[] select(ref mut i32[] a,ref mut i32[] b){return ref mut b[1..];}fn i32 use(ref mut i32[] p,ref mut i32[] q){{let ref mut i32[] r=id(ref mut p);let ref mut i32[] s=id(ref mut r);let ref mut i32[] u=id(ref mut q);let ref mut i32[] v=id(ref mut u);let ref mut i32[] t=select(ref mut s,ref mut v);t[0]=42;}return p[0]+p[1]+q[0]+q[1];}fn i32 main(){return 0;}"
    }else{
        b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn ref mut i32[] select(ref mut i32[] a,ref mut i32[] b){return ref mut a[1..];}fn i32 use(ref mut i32[] p,ref mut i32[] q){{let ref mut i32[] r=id(ref mut p);let ref mut i32[] s=id(ref mut r);let ref mut i32[] u=id(ref mut q);let ref mut i32[] v=id(ref mut u);let ref mut i32[] t=select(ref mut s,ref mut v);t[0]=42;}return p[0]+p[1]+q[0]+q[1];}fn i32 main(){return 0;}"
    })?;
    var usize call=256;var usize pc=unit.body.starts[2];while(pc<unit.body.ends[2]){if(unit.body.code[pc*8]==66){call=pc;}pc+=1;}
    if(call==256){return .err(errors::make(5,0));}
    let usize bound=recipes::binding(ref unit.body,call)?;let usize map=unit.body.code[call*8+3] as usize;
    var bool[16] ended=[false;16];var usize[2] anchors=[16;2];var usize argument=0;
    while(argument<2){var usize site=(unit.body.call_args[map*8+argument] as usize)-160;var usize depth=0;
        while(recipes::creator(ref unit.body,site)!=256){
            let usize made=recipes::creator(ref unit.body,site);ended[site]=true;site=unit.body.code[made*8+2] as usize;depth+=1;
            if(depth>16){return .err(errors::make(5,0));}
        }anchors[argument]=site;argument+=1;
    }
    var usize[16] closes=[256;16];var usize count=0;pc=bound+1;
    while(pc<unit.body.ends[2]){if(unit.body.code[pc*8]==62 && ended[unit.body.code[pc*8+1] as usize]){closes[count]=pc;count+=1;}pc+=1;}
    if(count!=4){return .err(errors::make(5,0));}
    var ordinary::Program body=unit.body;body.count=0;body.code=[0;2048];body.offsets=[0;256];
    let usize chosen=unit.parameters[1] as usize-1;let usize destination=unit.body.code[call*8+5] as usize;
    var usize f=0;while(f<body.function_count){let usize start=body.count;body.starts[f]=start;pc=unit.body.starts[f];
        while(pc<unit.body.ends[f]){
            if(pc==bound){var usize i=0;while(i<count){
                let usize old=closes[i];let usize at=body.count*8;
                var usize byte=0;while(byte<8){body.code[at+byte]=unit.body.code[old*8+byte];byte+=1;}body.code[at]=68;body.count+=1;i+=1;
            }}
            let usize old_at=pc*8;let u8 op=unit.body.code[old_at];
            if(op!=62 || !ended[unit.body.code[old_at+1] as usize]){
                let usize at=body.count*8;var usize byte=0;while(byte<8){body.code[at+byte]=unit.body.code[old_at+byte];byte+=1;}
                let usize destination_pc=body.count;body.offsets[destination_pc]=unit.body.offsets[pc];
                if(pc==call){body.code[at+4]=3;body.code[at+6]=unit.body.slice_origins[anchors[chosen]]-1;}
                if(pc==bound || (op==62 && unit.body.code[old_at+1] as usize==destination)){body.code[at+2]=unit.body.slice_origins[anchors[chosen]]-1;}
                body.count+=1;
            }pc+=1;
        }let usize end=body.count;body.ends[f]=end;f+=1;
    }unit.body=body;return .ok(unit);
}
fn ir::Program unit(bool second){return switch(build(second)){case .ok(p):{p}case .err(_):{assert(false);ir::Program{.body=ordinary::empty(),.elements=[0;16],.parameters=[0;16]}}};}
fn usize final_call(ref ir::Program p){var usize pc=p.body.starts[2];var usize at=256;while(pc<p.body.ends[2]){if(p.body.code[pc*8]==66){at=pc;}pc+=1;}return at;}
fn void drained(ref runtime::State state){assert(state.runtime.authority.depth==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}}
fn slices::Ticket input(ref mut runtime::State state,ref mut u8[] data){
    let layout::Array shape=switch(layout::scalar(1,2)){case .ok(v):{v}case .err(_):{assert(false);layout::Array{.element=1,.length=2,.stride=4,.alignment=4,.bytes=8}}};
    let owners::Token root=switch(owners::create(ref shape,0,data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket result=switch(slices::open_exclusive(ref mut pool,ref mut table,root,0,2,data.len)){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};
    state.runtime.pool=pool;state.runtime.owners=table;return result;
}
@effects(console)
fn Result<usize,errors::Error> execute(ref ir::Program p,usize fuel,u8 error,bool second){
    var runtime::State state=runtime::empty(16);var u8[16] data=[0;16];
    let slices::Ticket a=input(ref mut state,ref mut data);let slices::Ticket b=input(ref mut state,ref mut data);
    let runtime::Capture[2] captures=[runtime::capture(a,true,true),runtime::capture(b,true,true)];let i64[2] values=[0,0];let owners::Token[1] owned=[owners::Token{.slot=0,.generation=0}];
    let usize remaining=switch(vm::run_slice_scalar(p,2,ref captures,ref values,ref owned[..0],ref mut state,ref mut data,fuel)){
        case .ok(v):{assert(error==0 && v.value==42);v.remaining}
        case .err(e):{if(e.kind!=error){let i32 printed=render::outcome(true,true,true,0,e);}assert(e.kind==error);0}
    };
    drained(ref state);assert(data[if(second){12}else{4}]==42);return .ok(remaining);
}
@effects(console)
@test fn void chains_consume_selected_and_unselected_returned_receipts_in_acquisition_order(){
    let ir::Program first=unit(false);assert(proof::inspect(ref first).is_ok);assert(execute(ref first,16000000,0,false).is_ok);
    let ir::Program second=unit(true);assert(proof::inspect(ref second).is_ok);assert(execute(ref second,16000000,0,true).is_ok);
}
@effects(console)
fn Result<usize,errors::Error> boundaries(){let ir::Program p=unit(false);let usize left=execute(ref p,16000000,0,false)?;let usize used=16000000-left;assert(execute(ref p,used,0,false)?==0);let usize failed=execute(ref p,used-1,8,false)?;return .ok(0);}
@effects(console)
@test fn void exact_and_one_short_fuel_preserve_writes_and_drain_consumed_receipts(){assert(boundaries().is_ok);}
@test fn void invalid_masks_ancestry_and_unwind_order_fail_independent_admission(){
    var ir::Program p=unit(false);let usize call=final_call(ref p);
    assert(!recipes::chain(ref p.body,call,8).is_ok);p.body.code[call*8+4]=1;assert(!proof::inspect(ref p).is_ok);
    p=unit(false);p.body.code[(call+1)*8+2]=15;assert(!proof::inspect(ref p).is_ok);
    p=unit(false);let u8 repeated=p.body.code[(call+1)*8+1];p.body.code[(call+2)*8+1]=repeated;assert(!proof::inspect(ref p).is_ok);
    p=unit(false);let u8 bad_parent=p.body.code[(call+1)*8+1];p.body.code[call*8+6]=bad_parent;assert(!proof::inspect(ref p).is_ok);
}
