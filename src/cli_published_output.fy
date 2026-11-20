module cli_published_output;

import errors as errors;
import module_output_program as programs;
import render as render;

// The VM exposes bytes only through an immutable successful publication.
@effects(console)
pub fn i32 write(render::Format format,ref programs::Program program,ref programs::Execution run){
    let programs::Completion result=programs::observe(run);
    if(!result.success){
        let u8 kind=result.diagnostic.code.kind;
        if(kind==0){return render::selected_outcome(format,true,true,0,errors::absent(5,0),8);}
        return render::project_failure(format,true,result.diagnostic.code,programs::snapshot(program),result.diagnostic.at,8);
    }
    if(!programs::has_output(run)){
        return render::selected_outcome(format,true,true,0,errors::absent(5,0),8);
    }
    return render::published_output(format,result.value,programs::view(run));
}
