module module_budgeted_compile;
import compile_memory as memory;
import retention_plan as retention;
import module_entry as entries;
import module_input_entry as input_entries;
import module_program as ordinary;
import module_input_program as inputs;
import module_output_program as outputs;
import source_error as diagnostics;
import errors as errors;

// Temporary heap only. Native stacks, the caller's already-built Index and the
// Engine's owning Entry transport are separate accounting classes.
// Each live pushed cell (plus the next allocation cell) has a distinct source
// byte. At most 4096 bytes; initial capacity 8 and doubling old+new need at most
// 8 slots per cell. usize is 8 bytes on the supported native AMD64 target.
pub fn usize working_bound(){return 262144;}

fn diagnostics::Error failure(u8 kind){return diagnostics::absent(errors::make(kind,0));}
fn Result<retention::Plan,diagnostics::Error> begin(ref retention::Plan retained,ref mut memory::Plan plan){
    if(retained.admitted || retained.fixed==0 || retained.fixed>retained.limit || plan.baseline>plan.combined_limit){return .err(failure(5));}
    switch(memory::reserve_work(plan,working_bound())){
        case .ok(_):{}case .err(e):{
            return .err(failure(switch(e){case .Quota:{21}case .Invalid:{5}case .State:{5}}));
        }
    };
    let usize remaining=plan.combined_limit-plan.baseline;
    let usize limit=if(retained.limit<remaining){retained.limit}else{remaining};
    if(retained.fixed>limit){assert(memory::abort(plan).is_ok);return .err(failure(21));}
    // The existing exact pre-freeze admission now also enforces this invocation's
    // combined ceiling, including persistent allocation attempts that fail.
    return .ok(retention::Plan{.fixed=retained.fixed,.limit=limit,.bytes=0,.admitted=false});
}
fn void end(ref mut retention::Plan retained,ref retention::Plan local,ref mut memory::Plan plan,bool success){
    if(local.admitted){
        assert(memory::begin_retention(plan,local.bytes).is_ok);
        retained.bytes=local.bytes;retained.admitted=true;
    }
    if(success){assert(local.admitted);assert(memory::finish(plan).is_ok);}
    else{assert(memory::abort(plan).is_ok);}
}

// Source lowering returns (and destroys every array-cell scratch vector) before
// the delegated compiler admits/freeze-copies the persistent image and Stored.
// Keeping the wrapper outside the parser adds no recursive expression frame.
pub fn Result<ordinary::Program,diagnostics::Error> compile(entries::Entry selected,usize image_limit,
    ref mut retention::Plan retained,ref mut memory::Plan plan){
    var retention::Plan local=begin(retained,plan)?;
    let Result<ordinary::Program,diagnostics::Error> built=ordinary::compile_with_retention(selected,image_limit,ref mut local);
    return switch(built){
        case .ok(p):{end(retained,ref local,plan,true);.ok(p)}
        case .err(e):{end(retained,ref local,plan,false);.err(e)}
    };
}
pub fn Result<inputs::Program,diagnostics::Error> compile_input(input_entries::InputEntry selected,usize image_limit,
    ref mut retention::Plan retained,ref mut memory::Plan plan){
    var retention::Plan local=begin(retained,plan)?;
    let Result<inputs::Program,diagnostics::Error> built=inputs::compile_with_retention(selected,image_limit,ref mut local);
    return switch(built){
        case .ok(p):{end(retained,ref local,plan,true);.ok(p)}
        case .err(e):{end(retained,ref local,plan,false);.err(e)}
    };
}
pub fn Result<outputs::Program,diagnostics::Error> compile_output(entries::Entry selected,usize image_limit,
    ref mut retention::Plan retained,ref mut memory::Plan plan){
    var retention::Plan local=begin(retained,plan)?;
    let Result<outputs::Program,diagnostics::Error> built=outputs::compile_with_retention(selected,image_limit,ref mut local);
    return switch(built){
        case .ok(p):{end(retained,ref local,plan,true);.ok(p)}
        case .err(e):{end(retained,ref local,plan,false);.err(e)}
    };
}
pub fn Result<outputs::Program,diagnostics::Error> compile_input_output(input_entries::InputEntry selected,usize image_limit,
    ref mut retention::Plan retained,ref mut memory::Plan plan){
    var retention::Plan local=begin(retained,plan)?;
    let Result<outputs::Program,diagnostics::Error> built=outputs::compile_input_with_retention(selected,image_limit,ref mut local);
    return switch(built){
        case .ok(p):{end(retained,ref local,plan,true);.ok(p)}
        case .err(e):{end(retained,ref local,plan,false);.err(e)}
    };
}
