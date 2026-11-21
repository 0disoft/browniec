module module_source_work;
import module_index as modules;
import source_context as context;
import source_context_work as collecting;
import source_features as features;
import source_error as diagnostics;
import metadata_budget as budget;
import runtime_clock as clock;
import errors as errors;

// The owning caller pins the same Index until this source pass finishes.
pub struct State {
    collecting::State context;
    features::State syntax;
    bool classify;
    bool done;
}
pub fn State begin(bool classify){
    return State{.context=collecting::empty(),.syntax=features::begin(),.classify=classify,.done=false};
}
pub fn Result<bool,diagnostics::Error> advance(ref modules::Index index,ref mut State work,ref mut budget::State meter){
    if(work.done){return .ok(true);}
    if(meter.last!=0){return .ok(false);}
    if(!work.context.done){
        let bool collected=switch(collecting::advance(index,ref mut work.context,meter)){
            case .ok(v):{v}
            case .err(e):{return .err(diagnostics::Error{.code=errors::make(5,e.at.start),.at=e.at});}
        };
        work.done=collected && !work.classify;
        return .ok(work.done);
    }
    var features::State syntax=work.syntax;
    let ref context::Input input=ref work.context.result;
    let bool ready=switch(features::advance(ref input.data[..input.used],ref input.context,ref mut syntax,meter)){
        case .ok(v):{v}
        case .err(e):{return .err(if(e.offset==0){diagnostics::absent(e)}else{diagnostics::map(modules::snapshot(index),e,16)});}
    };
    work.syntax=syntax;
    work.done=ready;
    return .ok(ready);
}
pub fn Result<usize,diagnostics::Error> finish_until(ref modules::Index index,ref mut State work,usize deadline){
    var usize fuel=budget::unlimited();
    return finish_metered(index,work,deadline,ref mut fuel);
}
pub fn Result<usize,diagnostics::Error> finish_metered(ref modules::Index index,ref mut State work,
    usize deadline,ref mut usize fuel){
    var budget::State meter=budget::empty();
    while(!work.done){
        if(clock::expired(deadline)){return .err(diagnostics::absent(errors::absent(errors::deadline_kind(),0)));}
        switch(budget::reset_metered(ref mut meter,fuel,0)){
            case .ok(_):{}case .err(e):{return .err(diagnostics::absent(e));}
        };
        let bool ready=advance(index,work,ref mut meter)?;
    }
    if(clock::expired(deadline)){return .err(diagnostics::absent(errors::absent(errors::deadline_kind(),0)));}
    return .ok(meter.stages);
}
