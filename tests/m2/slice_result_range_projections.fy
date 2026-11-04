module tests::m2::slice_result_range_projections;
import compiler as compiler;
import ir as ordinary;
import slice_result_ir as ir;
import slice_result_runtime as runtime;
import slice_result_verifier as proof;
import slice_result_execution as execution;
import array_owners as owners;
import array_layout as layouts;
import array_slices as slices;
import vm as vm;
import errors as errors;
import render as render;

fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
@effects(console)
fn Result<usize,errors::Error> execute(ref ir::Program unit,usize fuel,u8 error,bool wrote){
    var runtime::State state=runtime::empty(256);var u8[256] data=[0;256];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let usize remaining=switch(vm::run_slice_scalar(unit,unit.body.entry,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,fuel)){
        case .ok(v):{if(error!=0 || v.value!=42){let i32 printed=render::outcome(true,true,true,v.value,errors::make(5,0));}assert(error==0 && v.value==42);v.remaining}
        case .err(e):{if(error!=e.kind){let i32 printed=render::outcome(true,true,true,0,e);}assert(e.kind==error);0}
    };
    drained(ref state);if(wrote){assert(data[0]==42);}return .ok(remaining);
}
@effects(console)
fn Result<usize,errors::Error> run(ref u8[] source){
    let ir::Program unit=switch(compiler::inspect_slice_result_ir(source)){
        case .ok(v):{v}case .err(e):{let i32 printed=render::outcome(true,true,true,0,e);return .err(e);}
    };
    assert(!compiler::compile(source).is_ok);return execute(ref unit,16000000,0,false);
}
@effects(console)
@test fn void declaration_ranges_preserve_all_six_scalar_types_and_access_modes(){
    assert(run(b"module main;fn ref i32[] tail(ref i32[] p){return ref p[1..];}fn i32 main(){let ref i32[] part=tail(ref [42;4])[1..2];if(part.len==1 && part[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut i32[] tail(ref mut i32[] p){return ref mut p[1..];}fn i32 main(){let ref mut i32[] part=tail(ref mut [42;4])[1..2];if(part.len==1 && part[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref bool[] tail(ref bool[] p){return ref p[1..];}fn i32 main(){let ref bool[] part=tail(ref [true;4])[1..2];if(part.len==1 && part[0]==true){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut bool[] tail(ref mut bool[] p){return ref mut p[1..];}fn i32 main(){let ref mut bool[] part=tail(ref mut [true;4])[1..2];if(part.len==1 && part[0]==true){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref i64[] tail(ref i64[] p){return ref p[1..];}fn i32 main(){let ref i64[] part=tail(ref [42;4])[1..2];if(part.len==1 && part[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut i64[] tail(ref mut i64[] p){return ref mut p[1..];}fn i32 main(){let ref mut i64[] part=tail(ref mut [42;4])[1..2];if(part.len==1 && part[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref u8[] tail(ref u8[] p){return ref p[1..];}fn i32 main(){let ref u8[] part=tail(ref [42;4])[1..2];if(part.len==1 && part[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut u8[] tail(ref mut u8[] p){return ref mut p[1..];}fn i32 main(){let ref mut u8[] part=tail(ref mut [42;4])[1..2];if(part.len==1 && part[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref u32[] tail(ref u32[] p){return ref p[1..];}fn i32 main(){let ref u32[] part=tail(ref [42;4])[1..2];if(part.len==1 && part[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut u32[] tail(ref mut u32[] p){return ref mut p[1..];}fn i32 main(){let ref mut u32[] part=tail(ref mut [42;4])[1..2];if(part.len==1 && part[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref usize[] tail(ref usize[] p){return ref p[1..];}fn i32 main(){let ref usize[] part=tail(ref [42;4])[1..2];if(part.len==1 && part[0]==42){return 42;}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut usize[] tail(ref mut usize[] p){return ref mut p[1..];}fn i32 main(){let ref mut usize[] part=tail(ref mut [42;4])[1..2];if(part.len==1 && part[0]==42){return 42;}return 0;}").is_ok);
}
@effects(console)
@test fn void direct_return_ranges_nested_calls_and_lexical_aliases_preserve_relative_bounds(){
    assert(run(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn ref i32[] crop(ref i32[] p){return id(ref id(ref p))[1..3];}fn i32 main(){let ref i32[] part=crop(ref [42;4])[..1];if(part.len==1){return part[0];}return 0;}").is_ok);
    assert(run(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn ref mut i32[] crop(ref mut i32[] p){return id(ref mut id(ref mut p))[1..3];}fn i32 main(){var i32[4] a=[0;4];{let ref mut i32[] part=crop(ref mut a)[1..];part[0]=42;}return a[2];}").is_ok);
    assert(run(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn ref i32[] crop(ref i32[] p,Option<i32> stop){return id(ref p)[switch(stop){case .some(v):{return ref p[1..2];}case .none:{1}}..3];}fn i32 main(){let ref i32[] a=crop(ref [42;4],.some(0))[..];let ref i32[] b=crop(ref [0;4],.none)[1..1];if(a.len==1 && b.len==0){return a[0];}return 0;}").is_ok);
}
@effects(console)
@test fn void endpoints_execute_once_in_order_before_the_new_range_is_acquired(){
    assert(run(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn usize first(ref mut i32[] n){n[0]=n[0]*10+1;return 0;}fn usize last(ref mut i32[] n){n[0]=n[0]*10+2;return 1;}fn i32 main(){var i32[1] n=[0;1];let ref mut i32[] part=id(ref mut [42;3])[first(ref mut n)..last(ref mut n)];if(n[0]==12 && part.len==1){return part[0];}return 0;}").is_ok);
    assert(run(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn i32 main(){var usize lo=1;let Option<i32> o=.none;let ref i32[] part=id(ref [42;4])[lo..switch(o){case .some(v):{2}case .none:{lo=3;2}}];if(part.len==1 && lo==3){return part[0];}return 0;}").is_ok);
}
@effects(console)
@test fn void endpoint_return_propagation_break_and_continue_cleanup_hidden_results(){
    assert(run(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn i32 main(){let Option<i32> o=.none;let ref i32[] part=id(ref [0;2])[switch(o){case .some(v):{0}case .none:{return 42;}}..];return part[0];}").is_ok);
    assert(run(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn Option<i32> outer(Option<i32> o){let ref mut i32[] part=id(ref mut [42;2])[0..switch(o){case .some(v):{1}case .none:{let i32 n=o?;1}}];return .some(part[0]);}fn i32 main(){switch(outer(.none)){case .some(v):{return 0;}case .none:{}}switch(outer(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}").is_ok);
    assert(run(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn ref mut i32[] crop(ref mut i32[] p){let Option<i32> o=.none;var i32 n=0;while(n<2){return id(ref mut p)[0..switch(o){case .some(v):{1}case .none:{n=n+1;continue;}}];}while(true){return id(ref mut p)[switch(o){case .some(v):{0}case .none:{break;}}..];}return ref mut p;}fn i32 main(){return crop(ref mut [42;2])[0];}").is_ok);
}
@test fn void wrong_types_conflicts_pending_names_and_temporary_escapes_reject(){
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn i32 main(){let ref i32[] part=id(ref [42;2])[true..];return 42;}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn i32 main(){var i32[2] a=[0;2];let ref mut i32[] part=id(ref mut a)[0..a[0] as usize];return 42;}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn i32 main(){let ref i32[] part=id(ref [42;2])[0..part.len];return 42;}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn ref i32[] bad(ref i32[] p){return id(ref [42;2])[..];}fn i32 main(){return 0;}").is_ok);
    assert(!compiler::inspect_slice_result_ir(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn i32 main(){let ref mut i32[] part=id(ref [42;2])[..];return 42;}").is_ok);
    let ir::Program unit=switch(compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] id(ref mut i32[] p){return ref mut p;}fn i32 main(){let ref mut i32[] part=id(ref mut [0;2])[1..];part[0]=42;return part[0];}")){case .ok(v):{v}case .err(_):{assert(false);ir::Program{.body=ordinary::empty(),.elements=[0;16],.parameters=[0;16]}}};
    var ir::Program bad=unit;var usize pc=bad.body.starts[bad.body.entry];while(pc<bad.body.ends[bad.body.entry] && bad.body.code[pc*8]!=61){pc+=1;}assert(pc<bad.body.ends[bad.body.entry]);bad.body.code[pc*8+2]=15;assert(!proof::inspect(ref bad).is_ok);
}
@effects(console)
fn Result<usize,errors::Error> boundaries(){
    let ir::Program unit=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] id(ref mut i32[] p){p[0]=42;return ref mut p;}fn ref mut i32[] crop(ref mut i32[] p){return id(ref mut p)[..2];}fn i32 main(){let ref mut i32[] part=crop(ref mut [0;3])[..1];return part[0];}")?;
    let usize left=execute(ref unit,16000000,0,true)?;let usize used=16000000-left;
    assert(execute(ref unit,used,0,true)?==0);let usize short=execute(ref unit,used-1,8,true)?;
    let ir::Program bounds=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] id(ref mut i32[] p){p[0]=42;return ref mut p;}fn i32 main(){let ref mut i32[] part=id(ref mut [0;2])[0..3];return 0;}")?;
    let usize failed=execute(ref bounds,16000000,14,true)?;
    let ir::Program endpoint=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] id(ref mut i32[] p){p[0]=42;return ref mut p;}fn i32 main(){let ref mut i32[] part=id(ref mut [0;2])[0..1/0];return 0;}")?;
    let usize trapped=execute(ref endpoint,16000000,7,true)?;return .ok(0);
}
@effects(console)
@test fn void exact_fuel_bounds_and_endpoint_traps_preserve_writes_and_drain(){assert(boundaries().is_ok);}

@effects(console)
fn Result<usize,errors::Error> external(ref ir::Program unit,bool writer,usize fuel,u8 error){
    var runtime::State state=runtime::empty(64);var u8[64] data=[0;64];
    let layouts::Array shape=switch(layouts::scalar(1,4)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,0));}};
    let owners::Token root=switch(owners::create(ref shape,1,ref mut data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,0));}};
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket parent=switch(if(writer){slices::open_exclusive(ref mut pool,ref mut table,root,0,4,data.len)}else{slices::open(ref mut pool,ref mut table,root,0,4,data.len)}){
        case .ok(v):{v}case .err(_):{return .err(errors::make(5,0));}
    };state.runtime.pool=pool;state.runtime.owners=table;
    let runtime::Capture[1] captures=[runtime::capture(parent,true,true)];let i64[1] values=[0];
    let usize remaining=switch(vm::run_slice_result(unit,1,ref captures,ref values,ref mut state,ref mut data,fuel)){
        case .ok(v):{
            assert(error==0 && v.held.exclusive==writer && v.held.view.start==2 && v.held.view.end==3 && v.held.view.length==4);
            var runtime::Held held=v.held;let slices::Ticket current=held.issued;
            switch(slices::length(ref state.runtime.pool,current,ref state.runtime.owners,data.len)){case .ok(length):{assert(length==1);}case .err(_):{assert(false);}};
            switch(slices::read(ref state.runtime.pool,current,ref state.runtime.owners,0,ref data)){case .ok(value):{assert(value==1);}case .err(_):{assert(false);}};
            let runtime::Closed closed=runtime::close(ref mut state,ref mut held,current,data.len,0)?;assert(closed.remaining==0);
            assert(!runtime::close(ref mut state,ref mut held,current,data.len,0).is_ok);
            assert(!slices::read(ref state.runtime.pool,current,ref state.runtime.owners,0,ref data).is_ok);v.remaining
        }
        case .err(e):{if(error==0 || e.kind!=error){let i32 printed=render::outcome(true,true,true,0,e);}assert(error!=0 && e.kind==error);0}
    };drained(ref state);return .ok(remaining);
}
@effects(console)
fn Result<usize,errors::Error> external_boundaries(){
    let ir::Program shared=compiler::inspect_slice_result_ir(b"module main;fn ref i32[] tail(ref i32[] p){return ref p[1..];}fn ref i32[] crop(ref i32[] p){return tail(ref p)[1..2];}fn i32 main(){return 0;}")?;
    let ir::Program writer=compiler::inspect_slice_result_ir(b"module main;fn ref mut i32[] tail(ref mut i32[] p){return ref mut p[1..];}fn ref mut i32[] crop(ref mut i32[] p){return tail(ref mut p)[1..2];}fn i32 main(){return 0;}")?;
    let usize shared_left=external(ref shared,false,16000000,0)?;let usize shared_used=16000000-shared_left;
    assert(external(ref shared,false,shared_used,0)?==0);let usize shared_short=external(ref shared,false,shared_used-1,8)?;
    let usize writer_left=external(ref writer,true,16000000,0)?;let usize writer_used=16000000-writer_left;
    assert(external(ref writer,true,writer_used,0)?==0);let usize writer_short=external(ref writer,true,writer_used-1,8)?;return .ok(0);
}
@effects(console)
@test fn void native_returned_subranges_close_exactly_once_at_zero_fuel(){
    switch(external_boundaries()){case .ok(_):{}case .err(e):{let i32 printed=render::outcome(true,true,true,0,e);assert(false);}};
}

@test fn void bare_forwarding_keeps_its_terminal_recipe_without_result_sites(){
    let ir::Program paths=switch(compiler::inspect_slice_result_ir(b"module main;fn ref i32[] id(ref i32[] p){return ref p;}fn ref i32[] forward(ref i32[] p){return id(ref p);}fn ref i32[] crop(ref i32[] p){return id(ref p)[..];}fn i32 main(){return 0;}")){case .ok(v):{v}case .err(_):{assert(false);ir::Program{.body=ordinary::empty(),.elements=[0;16],.parameters=[0;16]}}};
    var usize scan=paths.body.starts[1];var bool forwarded=false;
    while(scan<paths.body.ends[1]){let u8 op=paths.body.code[scan*8];assert(op!=66 && op!=67);if(op==64){forwarded=true;}scan+=1;}assert(forwarded);
    scan=paths.body.starts[2];var bool bound=false;var bool prepared=false;
    while(scan<paths.body.ends[2]){let u8 op=paths.body.code[scan*8];assert(op!=64);if(op==67){bound=true;}if(op==63){prepared=true;}scan+=1;}assert(bound && prepared);
}
