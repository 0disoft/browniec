module project_program;
import project_manifest as project;
import project_sources as binding;
import source_snapshot as sources;
import module_entry as entries;
import module_index as modules;
import module_program as code;
import source_error as diagnostics;
import errors as errors;

// A sealed native project: exact source-map/header/entry binding and full
// executable admission, retaining declared requirements for every invocation.
pub enum Failure { Binding; Compile; Requirements; Runtime; }
pub struct Error { Failure kind; modules::Error binding; diagnostics::Error diagnostic; }
pub resource Program { project::Project metadata; code::Program code; cleanup { } }
fn modules::Error no_binding(){
    return modules::Error{.kind=.Bounds,.at=sources::no_source()};
}
fn Error failed(Failure kind,diagnostics::Error diagnostic){
    return Error{.kind=kind,.binding=no_binding(),.diagnostic=diagnostic};
}
pub fn Result<Program,Error> compile(project::Project metadata,entries::Entry selected,usize image_limit){
    let usize verified=switch(binding::verify(ref metadata,ref selected)){
        case .ok(v):{v}case .err(e):{
            return .err(Error{.kind=.Binding,.binding=e,.diagnostic=diagnostics::absent(errors::make(0,0))});
        }
    };
    let code::Program executable=switch(code::compile(selected,image_limit)){
        case .ok(v):{v}case .err(e):{return .err(failed(.Compile,e));}
    };
    return .ok(Program{.metadata=metadata,.code=executable});
}
pub fn ref project::Project metadata(ref Program program){return ref program.metadata;}
pub fn ref sources::Snapshot snapshot(ref Program program){return code::snapshot(ref program.code);}
pub fn u8 profile(ref Program program){return code::profile(ref program.code);}
// No policy/grant API is implied by a manifest declaration. Until that authority
// is implemented, every declared requirement is denied before guest execution.
pub fn Result<i64,Error> run(ref Program program,usize fuel){
    if(project::requirements(ref program.metadata)!=0){
        return .err(failed(.Requirements,diagnostics::absent(errors::make(11,0))));
    }
    return switch(code::run(ref program.code,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(failed(.Runtime,e))}
    };
}
