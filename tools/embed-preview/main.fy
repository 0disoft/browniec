module main;

import abi_bootstrap as abi;
import module_entry as entries;
import module_index as modules;
import runtime_engine as engine;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import static_image as images;
import fuel as fuel;
import runtime_policy as policies;

unsafe extern C fn void bc_embed_binding(u32 id);
unsafe extern C fn ptr u8 bc_embed_witness_source();

fn engine::Error failed(u32 status){
    return engine::Error{.status=status,.diagnostic=diagnostics::absent(errors::absent(0,0))};
}

fn engine::Error binding_failure(modules::Error error){
    let errors::Error code=diagnostics::binding(error);
    return engine::Error{.status=if(code.kind==15){6}else if(code.kind==4){8}else{4},
        .diagnostic=diagnostics::Error{.code=code,.at=error.at}};
}

fn Result<engine::Engine,engine::Error> create(){
    return engine::create(engine::Limits{.programs=8,.instances=16,.fuel=fuel::cli_limit()});
}

fn Result<engine::Engine,engine::Error> create_configured(ptr u8 data,usize length){
    let usize lifetime=length;
    let ref u8[] source=unsafe{byte_slice::from_raw_parts(ref lifetime,data,length)};
    let policies::Policy policy=switch(policies::parse(source)){
        case .ok(v):{v}
        case .err(e):{
            return .err(failed(switch(e.kind){
                case .Allocation:{6}case .Limit:{8}
                case .Json:{5}case .Unknown:{5}case .Duplicate:{5}case .Missing:{5}
                case .Value:{5}case .Relation:{5}case .Authority:{5}case .Bounds:{5}
            }));
        }
    };
    return engine::create_with_policy(policy);
}

fn Result<entries::Entry,engine::Error> entry(ref u8[] source){
    var sources::Builder builder=switch(sources::builder(sources::source_limit(),16)){
        case .ok(v):{v}case .err(_):{return .err(failed(7));}
    };
    if(!sources::add(ref mut builder,b"main.brc",source).is_ok){return .err(failed(4));}
    let sources::Snapshot snapshot=switch(sources::freeze(ref builder)){
        case .ok(v):{v}case .err(_):{return .err(failed(4));}
    };
    let modules::Index index=switch(modules::build(snapshot)){
        case .ok(v):{v}case .err(e):{return .err(binding_failure(e));}
    };
    return switch(entries::select_i32(index,b"main",b"main")){
        case .ok(v):{.ok(v)}case .err(e):{.err(binding_failure(e))}
    };
}

fn Result<usize,engine::Error> compile(ref mut engine::Engine owner,ptr u8 data,usize length){
    // The synchronous C caller keeps its source alive through the Snapshot copy.
    let usize lifetime=length;
    let ref u8[] source=unsafe{byte_slice::from_raw_parts(ref lifetime,data,length)};
    let entries::Entry selected=entry(source)?;
    let usize program=engine::compile_output(owner,selected,images::metadata_charge()+images::byte_limit())?;
    if(!engine::scalar_preview_program(owner,program)?){
        let usize released=engine::release_program(owner,program)?;
        return .err(failed(5));
    }
    return .ok(program);
}

fn Result<usize,engine::Error> instance(ref mut engine::Engine owner,usize program,usize fuel){
    let usize run=engine::create_output_instance(owner,program,fuel,0,false)?;
    return switch(engine::prepare_instance(owner,run)){
        case .ok(_):{.ok(run)}
        case .err(e):{
            let usize removed=engine::destroy_instance(owner,run)?;
            .err(e)
        }
    };
}

fn Result<engine::Event,engine::Error> step(ref mut engine::Engine owner,usize run,usize quantum){
    return switch(engine::step_instance(owner,run,quantum)){
        case .ok(v):{.ok(v)}
        case .err(e):{if(e.status==11){engine::observe(owner,run)}else{.err(e)}}
    };
}

// Retain only the generated bindings. The DLL never invokes this root driver.
fn i32 main(){
    engine::retain_native_bindings();
    unsafe{bc_embed_binding(1)};
    var engine::Engine owner=switch(create()){case .ok(v):{v}case .err(_):{return 1;}};
    let ptr u8 source=unsafe{bc_embed_witness_source()};
    unsafe{bc_embed_binding(2)};discard compile(ref mut owner,source,1);
    unsafe{bc_embed_binding(3)};discard instance(ref mut owner,1,1);
    unsafe{bc_embed_binding(4)};discard step(ref mut owner,1,1);
    unsafe{bc_embed_binding(5)};discard engine::cancel_ready(ref mut owner,1);
    unsafe{bc_embed_binding(6)};discard engine::destroy_instance(ref mut owner,1);
    unsafe{bc_embed_binding(7)};discard engine::release_program(ref mut owner,1);
    unsafe{bc_embed_binding(8)};discard engine::destroy(ref mut owner);
    unsafe{bc_embed_binding(9)};discard create_configured(source,1);
    unsafe{bc_embed_binding(10)};discard abi::validate(2,32,true);
    return 0;
}
