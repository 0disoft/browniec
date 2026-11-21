module main;

import abi_bootstrap as abi;
import module_entry as entries;
import module_input_entry as input_entries;
import module_index as modules;
import runtime_engine as engine;
import source_snapshot as sources;
import source_error as diagnostics;
import errors as errors;
import static_image as images;
import fuel as fuel;
import runtime_policy as policies;
import host_catalog as catalog;
import host_exchange as host;

unsafe extern C fn void bc_embed_binding(u32 id);
unsafe extern C fn ptr u8 bc_embed_witness_source();
unsafe extern C fn ptr u8 bc_embed_source_data(ptr void rows,usize row,u32 module_name);
unsafe extern C fn usize bc_embed_source_size(ptr void rows,usize row,u32 module_name);

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

fn Result<usize,engine::Error> add_source(ref mut sources::Builder builder,ptr void rows,usize row){
    let usize length=unsafe{bc_embed_source_size(rows,row,0)};
    let usize name_length=unsafe{bc_embed_source_size(rows,row,1)};
    let ref u8[] data=unsafe{byte_slice::from_raw_parts(ref length,bc_embed_source_data(rows,row,0),length)};
    let ref u8[] name=unsafe{byte_slice::from_raw_parts(ref name_length,bc_embed_source_data(rows,row,1),name_length)};
    return switch(sources::add(builder,name,data)){
        case .ok(v):{.ok(v)}
        case .err(reason):{
            let sources::Span at=sources::Span{.source=row,.start=0,.end=0};
            .err(switch(reason){
                case .Limit:{failed(8)}
                case .Duplicate:{binding_failure(modules::Error{.kind=.Duplicate,.at=at})}
                case .Utf8:{binding_failure(modules::Error{.kind=.Lexical,.at=at})}
                case .Name:{failed(1)}
                case .State:{failed(7)}
                case .Bounds:{failed(7)}
            })
        }
    };
}

fn Result<sources::Snapshot,engine::Error> source_snapshot(ref engine::Engine owner,ptr void rows,usize count){
    if(count>engine::source_module_limit(owner)){return .err(failed(8));}
    var sources::Builder builder=switch(sources::builder(engine::source_byte_limit(owner),sources::name_limit())){
        case .ok(v):{v}case .err(_):{return .err(failed(7));}
    };
    var usize row=0;
    while(row<count){discard add_source(ref mut builder,rows,row)?;row+=1;}
    return switch(sources::freeze(ref builder)){
        case .ok(v):{.ok(v)}case .err(_):{.err(failed(7))}
    };
}

struct Compiled { usize program; bool accepts_input; bool emits; }
fn Result<Compiled,engine::Error> compile(ref mut engine::Engine owner,ptr void rows,usize count,bool configured){
    let sources::Snapshot snapshot=source_snapshot(owner,rows,count)?;
    let modules::Index index=switch(modules::build(snapshot)){
        case .ok(v):{v}case .err(e):{return .err(binding_failure(e));}
    };
    switch(modules::match_source_names(ref index)){
        case .ok(_):{}case .err(e):{return .err(binding_failure(e));}
    };
    let bool input=configured && input_entries::has_i32_input(ref index,b"main",b"main");
    let usize image_limit=images::metadata_charge()+images::byte_limit();
    let usize program=if(input){
        let input_entries::InputEntry selected=switch(input_entries::select_i32_input(index,b"main",b"main")){
            case .ok(v):{v}case .err(e):{return .err(binding_failure(e));}
        };
        engine::compile_input_output(owner,selected,image_limit)?
    }else{
        let entries::Entry selected=switch(entries::select_i32(index,b"main",b"main")){
            case .ok(v):{v}case .err(e):{return .err(binding_failure(e));}
        };
        engine::compile_output(owner,selected,image_limit)?
    };
    let engine::PreviewEntry profile=switch(engine::preview_entry(owner,program)){
        case .ok(v):{v}
        case .err(e):{let usize released=engine::release_program(owner,program)?;return .err(e);}
    };
    if(!configured && profile.emits){
        let usize released=engine::release_program(owner,program)?;
        return .err(failed(5));
    }
    return .ok(Compiled{.program=program,.accepts_input=profile.accepts_input,.emits=profile.emits});
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
        case .err(e):{if(e.status==11 || e.status==14){engine::observe(owner,run)}else{.err(e)}}
    };
}

fn Result<engine::ScalarPreparation,engine::Error> instance_configured(ref mut engine::Engine owner,usize program,
    ptr u8 bytes,usize size,ptr u8 data,usize length,bool catalog_backed){
    let usize lifetime=length;
    let ref u8[] configuration=unsafe{byte_slice::from_raw_parts(ref lifetime,data,length)};
    let usize input_lifetime=size;
    let ref u8[] input=if(size==0){b""}else{unsafe{byte_slice::from_raw_parts(ref input_lifetime,bytes,size)}};
    if(catalog_backed){return engine::prepare_host_preview(owner,program,input,configuration);}
    return engine::prepare_scalar_preview(owner,program,input,configuration);
}

struct OutputSlice { ptr u8 data; usize length; }
fn Result<OutputSlice,engine::Error> output_slice(ref engine::Engine owner,usize instance){
    let ref u8[] data=engine::preview_output(owner,instance)?;
    return .ok(OutputSlice{.data=if(data.len==0){null}else{unsafe{data as ptr u8}},.length=data.len});
}

fn Result<usize,engine::Error> compile_host(ref mut engine::Engine owner,ptr void rows,usize count,
    ptr u8 catalog_data,usize catalog_size){
    let usize catalog_lifetime=catalog_size;
    let ref u8[] json=unsafe{byte_slice::from_raw_parts(ref catalog_lifetime,catalog_data,catalog_size)};
    let catalog::Catalog imports=switch(catalog::parse(json)){
        case .ok(v):{v}case .err(e):{
            return .err(failed(switch(e.kind){
                case .Allocation:{6}case .Limit:{8}
                case .Json:{5}case .Unknown:{5}case .Duplicate:{5}case .Missing:{5}
                case .Value:{5}case .Order:{5}case .Bounds:{5}
            }));
        }
    };
    let sources::Snapshot snapshot=source_snapshot(owner,rows,count)?;
    return engine::compile_preview_host(owner,snapshot,imports);
}

fn Result<OutputSlice,engine::Error> host_capability(ref engine::Engine owner,usize program,usize index){
    let ref u8[] name=engine::preview_host_capability(owner,program,index)?;
    return .ok(OutputSlice{.data=unsafe{name as ptr u8},.length=name.len});
}
struct RequestView { usize request; usize import_id; ptr u8 data; usize length; }
fn Result<RequestView,engine::Error> host_request(ref engine::Engine owner,usize instance){
    let ref host::Exchange exchange=engine::preview_host_exchange(owner,instance)?;
    let host::Observation state=host::observe(exchange);
    let ref u8[] payload=switch(host::request_bytes(exchange)){
        case .ok(v):{v}case .err(_):{return .err(failed(7));}
    };
    return .ok(RequestView{.request=state.request,.import_id=state.import_id,
        .data=unsafe{payload as ptr u8},.length=payload.len});
}
fn Result<engine::Event,engine::Error> host_reply(ref mut engine::Engine owner,usize instance,usize request,
    u8 kind,ptr u8 data,usize length,usize total,usize offset){
    let usize lifetime=length;
    let ref u8[] chunk=if(length==0){b""}else{unsafe{byte_slice::from_raw_parts(ref lifetime,data,length)}};
    return engine::receive_host_reply(owner,instance,instance,request,kind,total,offset,chunk);
}

// Retain only the generated bindings. The DLL never invokes this root driver.
fn i32 main(){
    engine::retain_native_bindings();
    unsafe{bc_embed_binding(1)};
    var engine::Engine owner=switch(create()){case .ok(v):{v}case .err(_):{return 1;}};
    let ptr u8 source=unsafe{bc_embed_witness_source()};
    unsafe{bc_embed_binding(2)};discard compile(ref mut owner,null,1,true);
    unsafe{bc_embed_binding(3)};discard instance(ref mut owner,1,1);
    unsafe{bc_embed_binding(4)};discard step(ref mut owner,1,1);
    unsafe{bc_embed_binding(5)};discard engine::cancel_ready(ref mut owner,1);
    unsafe{bc_embed_binding(6)};discard engine::destroy_instance(ref mut owner,1);
    unsafe{bc_embed_binding(7)};discard engine::release_program(ref mut owner,1);
    unsafe{bc_embed_binding(8)};discard engine::destroy(ref mut owner);
    unsafe{bc_embed_binding(9)};discard create_configured(source,1);
    unsafe{bc_embed_binding(10)};discard abi::validate(2,32,true);
    unsafe{bc_embed_binding(11)};discard instance_configured(ref mut owner,1,source,1,source,1,true);
    unsafe{bc_embed_binding(12)};discard engine::observe(ref mut owner,1);
    unsafe{bc_embed_binding(13)};discard output_slice(ref owner,1);
    unsafe{bc_embed_binding(14)};discard compile_host(ref mut owner,null,1,source,1);
    unsafe{bc_embed_binding(15)};discard engine::preview_host_entry(ref owner,1);
    unsafe{bc_embed_binding(16)};discard host_capability(ref owner,1,1);
    unsafe{bc_embed_binding(17)};discard host_request(ref owner,1);
    unsafe{bc_embed_binding(18)};discard host_reply(ref mut owner,1,1,0,source,1,1,0);
    return 0;
}
