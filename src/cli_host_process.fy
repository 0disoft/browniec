module cli_host_process;

import errors as errors;
import host_catalog as catalog;
import host_process_adapter as adapter;
import runtime_engine as engine;
import std::process as process;

unsafe extern C fn ptr mut void bc_cli_adapter_slot();
unsafe extern C fn void bc_cli_adapter_wait();
unsafe extern C fn u32 bc_cli_adapter_reap();
unsafe extern C fn u32 bc_cli_cancel_requested();

pub fn Result<adapter::Route,errors::Error> read(usize argument,ref catalog::Catalog imports){
    var u8[2] raw=[0;2];
    let usize n=switch(process::arg(argument,ref mut raw)){
        case .ok(v):{v}case .err(_):{return .err(errors::absent(10,0));}
    };
    if(n==0){return .err(errors::absent(10,0));}
    var usize index=0;
    var usize i=0;
    while(i<n){
        if(raw[i]<48 || raw[i]>57){return .err(errors::absent(10,0));}
        index=index*10+(raw[i]-48) as usize;
        i+=1;
    }
    if(index>=64){return .err(errors::absent(10,0));}
    var u8[64] revision=[0;64];
    let usize size=switch(process::arg(argument+1,ref mut revision)){
        case .ok(v):{v}case .err(_):{return .err(errors::absent(10,0));}
    };
    var u8[4096] executable=[0;4096];
    let usize length=switch(process::arg(argument+2,ref mut executable)){
        case .ok(v):{v}case .err(_):{return .err(errors::absent(10,0));}
    };
    return switch(adapter::register(imports,index,ref revision[..size],ref executable[..length])){
        case .ok(v):{.ok(v)}case .err(e):{.err(problem(e.status))}
    };
}

fn errors::Error problem(u32 status){
    if(status==6){return errors::absent(15,0);}
    if(status==8){return errors::absent(errors::memory_limit_kind(),0);}
    return errors::absent(11,0);
}

fn Result<engine::Event,errors::Error> observed(ref engine::Engine owner,usize instance){
    return switch(engine::instance_status(owner,instance)){
        case .ok(v):{.ok(v.event)}case .err(e):{.err(problem(e.status))}
    };
}

fn Result<engine::Event,errors::Error> interruption(ref mut engine::Engine owner,usize instance){
    let Result<engine::Event,engine::Error> stopped=if(unsafe{bc_cli_cancel_requested()}!=0){
        engine::cancel_ready(owner,instance)
    }else{
        engine::step_instance(owner,instance,1)
    };
    return switch(stopped){case .ok(v):{.ok(v)}case .err(e):{.err(problem(e.status))}};
}

fn Result<engine::Event,errors::Error> drive(ref mut engine::Engine owner,usize instance,ref adapter::Session session){
    while(unsafe{bc_cli_cancel_requested()}==0){
        switch(adapter::poll(owner,session,4096)){
            case .ok(progress):{
                switch(progress){
                    case .Pending:{unsafe{bc_cli_adapter_wait()};}
                    case .Submitted:{return observed(owner,instance);}
                    case .Stopped:{return interruption(owner,instance);}
                };
            }
            case .err(e):{
                if(e.status==11){return interruption(owner,instance);}
                return .err(problem(e.status));
            }
        };
    }
    return interruption(owner,instance);
}

pub fn Result<engine::Event,errors::Error> dispatch(ref mut engine::Engine owner,usize instance,ref adapter::Route route){
    let ptr mut void slot=unsafe{bc_cli_adapter_slot()};
    let Result<engine::Event,errors::Error> result=switch(adapter::start(owner,instance,route,slot,4096)){
        case .ok(session):{drive(owner,instance,ref session)}
        case .err(e):{
            let engine::Event status=observed(owner,instance)?;
            if(status.kind!=4){.ok(status)}
            else if(e.status==11){interruption(owner,instance)}
            else{.err(problem(e.status))}
        }
    };
    if(unsafe{bc_cli_adapter_reap()}==0){
        // The static slot retains pending storage until the CLI process exits.
        discard result;
        return .err(errors::absent(5,0));
    }
    return result;
}
