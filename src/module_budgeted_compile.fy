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
import module_source_work as source_work;

// Temporary SDK heap, excluding inline native frames and caller-owned Entry.
// Existing list cells: 4096 source bytes * 8 slots * sizeof(usize).
// The three owning scratch vectors contain one element and never grow. Their
// first SDK backing has eight slots. Expression and structure guards admit at
// most 32 levels each, plus root/rejected-boundary frames; two wrappers per kind
// give 2 * ((32+2)+(32+2)) = 136 simultaneously live owners of each kind.
// Pinned emitted widths must fit 40000/6000/15000 bytes; transport review checks
// these caps. Scratch is destroyed before persistent retention begins.
pub fn usize scratch_bank_slot_bound(){return 40000;}
pub fn usize scratch_expression_slot_bound(){return 6000;}
pub fn usize scratch_conditional_slot_bound(){return 15000;}
pub fn usize scratch_owner_bound(){return 136;}
pub fn usize working_bound(){return 262144+scratch_owner_bound()*8*(scratch_bank_slot_bound()+scratch_expression_slot_bound()+scratch_conditional_slot_bound());}

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
    return compile_until(selected,image_limit,retained,plan,0);
}
pub fn Result<ordinary::Program,diagnostics::Error> compile_until(entries::Entry selected,usize image_limit,
    ref mut retention::Plan retained,ref mut memory::Plan plan,usize deadline){
    var retention::Plan local=begin(retained,plan)?;
    let Result<ordinary::Program,diagnostics::Error> built=ordinary::compile_with_retention_until(selected,image_limit,ref mut local,deadline);
    return switch(built){
        case .ok(p):{end(retained,ref local,plan,true);.ok(p)}
        case .err(e):{end(retained,ref local,plan,false);.err(e)}
    };
}
pub fn Result<inputs::Program,diagnostics::Error> compile_input(input_entries::InputEntry selected,usize image_limit,
    ref mut retention::Plan retained,ref mut memory::Plan plan){
    return compile_input_until(selected,image_limit,retained,plan,0);
}
pub fn Result<inputs::Program,diagnostics::Error> compile_input_until(input_entries::InputEntry selected,usize image_limit,
    ref mut retention::Plan retained,ref mut memory::Plan plan,usize deadline){
    var retention::Plan local=begin(retained,plan)?;
    let Result<inputs::Program,diagnostics::Error> built=inputs::compile_with_retention_until(selected,image_limit,ref mut local,deadline);
    return switch(built){
        case .ok(p):{end(retained,ref local,plan,true);.ok(p)}
        case .err(e):{end(retained,ref local,plan,false);.err(e)}
    };
}
pub fn Result<inputs::Program,diagnostics::Error> compile_input_prepared_until(ref input_entries::InputEntry selected,
    ref source_work::State source,usize image_limit,ref mut retention::Plan retained,ref mut memory::Plan plan,usize deadline){
    var retention::Plan local=begin(retained,plan)?;
    let Result<inputs::Program,diagnostics::Error> built=inputs::compile_prepared_until(selected,source,image_limit,ref mut local,deadline);
    return switch(built){
        case .ok(p):{end(retained,ref local,plan,true);.ok(p)}
        case .err(e):{end(retained,ref local,plan,false);.err(e)}
    };
}
fn Result<outputs::Program,diagnostics::Error> finish_output(Result<outputs::Program,diagnostics::Error> built,
    ref mut retention::Plan retained,ref retention::Plan local,ref mut memory::Plan plan){
    return switch(built){
        case .ok(p):{end(retained,local,plan,true);.ok(p)}
        case .err(e):{end(retained,local,plan,false);.err(e)}
    };
}
pub fn Result<outputs::Program,diagnostics::Error> compile_output(entries::Entry selected,usize image_limit,
    ref mut retention::Plan retained,ref mut memory::Plan plan){
    var retention::Plan local=begin(retained,plan)?;
    let Result<outputs::Program,diagnostics::Error> built=outputs::compile_with_retention(selected,image_limit,ref mut local);
    return finish_output(built,retained,ref local,plan);
}
pub fn Result<outputs::Program,diagnostics::Error> compile_input_output(input_entries::InputEntry selected,usize image_limit,
    ref mut retention::Plan retained,ref mut memory::Plan plan){
    var retention::Plan local=begin(retained,plan)?;
    let Result<outputs::Program,diagnostics::Error> built=outputs::compile_input_with_retention(selected,image_limit,ref mut local);
    return finish_output(built,retained,ref local,plan);
}
pub fn Result<outputs::Program,diagnostics::Error> compile_output_until(entries::Entry selected,usize image_limit,
    ref mut retention::Plan retained,ref mut memory::Plan plan,usize deadline){
    var retention::Plan local=begin(retained,plan)?;
    let Result<outputs::Program,diagnostics::Error> built=outputs::compile_with_retention_until(selected,image_limit,ref mut local,deadline);
    return finish_output(built,retained,ref local,plan);
}
pub fn Result<outputs::Program,diagnostics::Error> compile_input_output_until(input_entries::InputEntry selected,usize image_limit,
    ref mut retention::Plan retained,ref mut memory::Plan plan,usize deadline){
    var retention::Plan local=begin(retained,plan)?;
    let Result<outputs::Program,diagnostics::Error> built=outputs::compile_input_with_retention_until(selected,image_limit,ref mut local,deadline);
    return finish_output(built,retained,ref local,plan);
}
