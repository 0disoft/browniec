module buffer_host_sweep;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_growth as growth;
import buffer_close as close;
import buffer_host_close as host;
import buffer_utf8_pool as pools;
import buffer_utf8_meter as meter;

// Enumeration/control state only. Native roots stay owned by the host.
pub struct Sweep { u8 phase; usize visited; bool offered; owners::Token current; close::Plan plan; }
fn owners::Token none(){return owners::Token{.slot=16,.generation=0};}
pub fn Sweep empty(){return Sweep{.phase=0,.visited=0,.offered=false,.current=none(),.plan=close::empty()};}
fn bool valid(ref Sweep sweep){
    if(sweep.phase>2 || sweep.visited>65535){return false;}
    if(sweep.offered){if(sweep.phase!=1 || sweep.current.slot>=16 || sweep.current.generation==0){return false;}}
    else if(sweep.current.slot!=16 || sweep.current.generation!=0){return false;}
    if(sweep.plan.active && (!sweep.offered || sweep.plan.source.slot!=sweep.current.slot ||
        sweep.plan.source.generation!=sweep.current.generation)){return false;}
    return true;
}
pub fn Result<usize,meter::ControlError> begin(ref mut Sweep sweep,ref mut pools::Pool pool,
    ref mut owners::Table table,ref mut growth::Ledger ledger){
    if(!valid(sweep) || sweep.phase!=0 || sweep.offered || sweep.plan.active || sweep.visited!=0){return .err(.State);}
    switch(owners::accounted(table)){case .ok(_):{}case .err(_):{return .err(.State);}};
    sweep.phase=1;
    // State may mean partial cleanup; retain the active sweep for independent roots.
    return pools::shutdown(pool,table,ledger);
}
pub fn Result<Option<owners::Token>,meter::ControlError> next(ref mut Sweep sweep,ref owners::Table table){
    if(!valid(sweep) || sweep.phase!=1){return .err(.State);}
    if(sweep.plan.active){return .ok(.some(sweep.current));}
    switch(owners::accounted(table)){case .ok(_):{}case .err(_):{return .err(.State);}};
    if(sweep.offered){
        switch(owners::describe(table,sweep.current)){case .ok(_):{}case .err(_):{return .err(.State);}};
        return .ok(.some(sweep.current));
    }
    // Deterministic descending slot order; slot reuse is not allocation order.
    var usize i=16;while(i>0){i-=1;
        let usize bit=1<<i;
        if(table.slots[i].live && (sweep.visited&bit)==0){
            sweep.current=owners::Token{.slot=i,.generation=table.slots[i].generation};sweep.offered=true;
            return .ok(.some(sweep.current));
        }
    }
    return .ok(.none);
}
fn void visited(ref mut Sweep sweep){
    sweep.visited|=1<<sweep.current.slot;sweep.offered=false;sweep.current=none();
}
pub fn Result<usize,bytes::Buffer> close_current(bytes::Buffer root,ref mut Sweep sweep,
    ref pools::Pool pool,ref mut owners::Table table,ref mut growth::Ledger ledger){
    if(!valid(sweep) || sweep.phase!=1 || !sweep.offered){return .err(root);}
    return switch(host::close_stopped(root,sweep.current,pool,table,ledger,ref mut sweep.plan)){
        case .ok(n):{visited(sweep);.ok(n)}
        case .err(retained):{
            // Failed preflight advances this pass; failed finish freezes its Plan.
            if(!sweep.plan.active){visited(sweep);};
            .err(retained)
        }
    };
}
pub fn Result<usize,meter::ControlError> retry(ref mut Sweep sweep,ref owners::Table table){
    if(!valid(sweep) || sweep.phase!=1 || sweep.offered || sweep.plan.active){return .err(.State);}
    switch(owners::accounted(table)){case .ok(_):{}case .err(_):{return .err(.State);}};
    var usize i=0;while(i<16){if(table.slots[i].live && (sweep.visited&(1<<i))==0){return .err(.State);}i+=1;}
    sweep.visited=0;return .ok(0);
}
pub fn Result<usize,meter::ControlError> finish(ref mut Sweep sweep,ref mut pools::Pool pool,
    ref mut owners::Table table,ref mut growth::Ledger ledger){
    if(!valid(sweep) || sweep.phase==0 || sweep.offered || sweep.plan.active){return .err(.State);}
    let usize used=host::finish_all(pool,table,ledger,ref sweep.plan)?;
    sweep.phase=2;sweep.visited=0;return .ok(used);
}
