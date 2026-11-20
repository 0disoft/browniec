module runtime_engine;
import call_copy_cursor as call_work;
import metadata_budget as metadata_budget;
import return_work_cursor as return_work;
import module_program as programs;
import module_entry as entries;
import module_input_program as input_programs;
import module_input_entry as input_entries;
import runtime_input as input_bytes;
import module_output_program as output_programs;
import source_error as diagnostics;
import errors as errors;
import fuel as fuel;
import std::vec as vec;
import std::bytes as bytes;
import runtime_control_budget as control;
import runtime_control_layout as control_layout;
import runtime_program_memory as memory;
import retention_plan as retention;
import compile_memory as compilation;
import module_budgeted_compile as bounded;
import module_index as modules;
import source_snapshot as sources;
import project_manifest as projects;
import project_source_loader as project_loader;
import project_sources as project_binding;
import runtime_live_memory as live;
import runtime_execution_memory as execution_heap;
import slice_result_machine as machines;
import runtime_pending_output as pending_vm;
import runtime_output as pending_output;
import runtime_pending_memory as pending_heap;
import output_copy_cursor as output_copy;
import array_fill_cursor as array_fill;
import runtime_policy as policy;
import runtime_policy_limits as policy_limits;
import runtime_run_config as run_config;
import host_catalog as host_catalog;
import compiler as compiler;
import host_exchange as host;
import host_program as host_program;
import ir as ir;

// Internal owning lifecycle, not public C handles/bc_step. IDs are scoped to
// this exact Engine; the outer ABI registry must authenticate their association.
pub struct Limits { usize programs; usize instances; usize fuel; }
pub struct Error { u32 status; diagnostics::Error diagnostic; }
pub struct Event { u8 kind; i64 value; diagnostics::Error diagnostic; usize remaining; bool fuel_known; }
// Event.kind 4 indicates a suspended host request. Request bytes are detached.
pub struct HostRequest { usize run; usize request; usize import_id; u8[14] payload; }
struct HostTransition { Event event; host::ScalarEvent scalar; }
pub struct Snapshot { usize programs; usize instances; usize pins; bool closed; }
struct Meta {
    Limits limits; usize thread; usize lifetime; usize active; usize admission;
    usize next; usize result; Error error; Event event; Snapshot snapshot; bool closed; control::Budget control; memory::Budget programs; live::Budget heap; bool configured;
}
// Exactly one executable vector has one element; the others are empty. Input code is
// never relabelled as a zero-argument Program or an array/image input lease.
struct EntryBinding {
    u8[128] scope; u8[64] function; usize scope_len; usize function_len; bool emits;
}
resource Program {
    usize id; usize pins; bool released; vec::Vec<programs::Program> code;
    vec::Vec<input_programs::Program> input; vec::Vec<output_programs::Program> output; usize bytes; usize execution_scratch; EntryBinding entry; vec::Vec<host_program::Program> host; cleanup { }
}
struct Instance { usize id; usize program; usize fuel; u8 phase; Event event; usize output_limit; bool output_allowed; usize input_bytes; usize output_bytes; host::ScalarEvent host_terminal; }
resource BoundInput { usize instance; input_bytes::Snapshot input; cleanup { } }
pub resource Output { usize instance; output_programs::Execution run; vec::Vec<machines::Machine> pending; vec::Vec<host::Exchange> host; cleanup { } }
pub resource Engine {
    Meta meta; vec::Vec<Program> programs; vec::Vec<Program> scratch;
    vec::Vec<Instance> instances; vec::Vec<BoundInput> inputs;
    vec::Vec<BoundInput> input_scratch; vec::Vec<Output> outputs; vec::Vec<Output> output_scratch; vec::Vec<policy::Policy> policy; cleanup { }
}
@link_name("bc_runtime_engine_input_preflight") unsafe extern C fn u32 input_preflight_raw(ptr mut void owner,usize program,usize budget,ptr void input,u32 output,usize limit,u32 allowed);
@link_name("bc_runtime_engine_input_fact") unsafe extern C fn usize input_fact_raw(ptr void source,u32 fact);
@link_name("bc_runtime_engine_compile_preflight") unsafe extern C fn u32 compile_preflight_raw(ptr mut void owner,u32 mode,ptr void selected);
@link_name("bc_runtime_engine_compile_fact") unsafe extern C fn usize compile_fact_raw(ptr void source,u32 kind,u32 fact);
@link_name("bc_runtime_engine_policy_slot_bytes") unsafe extern C fn usize policy_slot_bytes_raw();
@link_name("bc_runtime_engine_monotonic_ticks") unsafe extern C fn usize monotonic_ticks_raw();
@link_name("bc_runtime_engine_prepare_host") unsafe extern C fn u32 prepare_host_raw(ptr mut void owner,usize program,ptr void run);
@link_name("bc_runtime_engine_reply_host") unsafe extern C fn u32 reply_host_raw(ptr mut void owner,usize instance,usize run,usize request,u8 kind,ptr u8 data,usize length,usize total,usize offset);
@link_name("bc_runtime_engine_drive_host") unsafe extern C fn u32 drive_host_raw(ptr mut void owner,u32 mode,usize argument,usize run,usize request,u8 kind,ptr u8 data,usize length,ptr mut void transition,usize offset);
@link_name("bc_runtime_engine_retain_host") unsafe extern C fn u32 retain_host_raw(ptr mut void owner,ptr mut void incoming);
@link_name("bc_runtime_engine_bind") unsafe extern C fn u32 bind_raw(ptr mut void owner);
@link_name("bc_runtime_engine_compile") unsafe extern C fn u32 compile_raw(ptr mut void owner,ptr mut void incoming,usize limit);
@link_name("bc_runtime_engine_compile_input") unsafe extern C fn u32 compile_input_raw(ptr mut void owner,ptr mut void incoming,usize limit);
@link_name("bc_runtime_engine_execute_input") unsafe extern C fn u32 execute_input_raw(ptr mut void owner,usize instance,ptr void input);
@link_name("bc_runtime_engine_instance_input") unsafe extern C fn u32 instance_input_raw(ptr mut void owner,usize program,ptr mut void input,usize budget);
@link_name("bc_runtime_engine_call") unsafe extern C fn u32 call_raw(ptr mut void owner,u32 operation,usize id,usize argument);
@link_name("bc_runtime_engine_compile_output") unsafe extern C fn u32 compile_output_raw(ptr mut void owner,ptr mut void incoming,usize limit,u32 input);
@link_name("bc_runtime_engine_instance_output") unsafe extern C fn u32 instance_output_raw(ptr mut void owner,usize program,ptr mut void input,usize budget,usize limit,u32 allowed);
@link_name("bc_runtime_engine_output_preflight") unsafe extern C fn u32 output_preflight_raw(ptr mut void owner,usize instance);
@link_name("bc_runtime_engine_output_fact") unsafe extern C fn usize output_fact_raw(ptr void source,u32 fact);
@link_name("bc_runtime_engine_take_output") unsafe extern C fn u32 take_output_raw(ptr mut void owner,usize instance,ptr mut void outgoing);
@link_name("bc_runtime_engine_step_output") unsafe extern C fn u32 step_output_raw(ptr mut void owner,ptr void program,ptr void input,usize quantum);
@link_name("bc_runtime_engine_cancel_output") unsafe extern C fn u32 cancel_output_raw(ptr mut void owner);
// Retention markers are used only by the dedicated native transport fixture.
@link_name("bc_runtime_engine_control_access") unsafe extern C fn u32 control_access_raw(ptr void owner);
@link_name("bc_runtime_engine_binding") unsafe extern C fn void binding_raw(u32 number);
fn diagnostics::Error absent(){return diagnostics::absent(errors::make(0,0));}
fn Error error(u32 status){return Error{.status=status,.diagnostic=absent()};}
fn Event ready(usize budget){return Event{.kind=0,.value=0,.diagnostic=absent(),.remaining=budget,.fuel_known=true};}
fn Event pending(){return ready(0);}
fn Snapshot empty_snapshot(){return Snapshot{.programs=0,.instances=0,.pins=0,.closed=false};}
fn Result<usize,Error> result(ref Engine e,u32 status){
    if(status==0){return .ok(e.meta.result);}
    if(status==3 || status==10){return .err(error(status));}
    return .err(if(e.meta.error.status==status){e.meta.error}else{error(status)});
}
fn bool valid_limits(Limits limits){
    return limits.programs>0 && limits.programs<=64 && limits.instances>0 && limits.instances<=64 && limits.fuel>0 && limits.fuel<=fuel::cli_limit();
}
pub fn Result<usize,Error> required_control_bytes(Limits limits){
    if(!valid_limits(limits)){return .err(error(1));}
    return switch(control_layout::required(limits.programs,limits.instances)){
        case .ok(bytes):{.ok(bytes)}case .err(_):{.err(error(8))}
    };
}
pub fn Result<control::Observation,Error> control_memory(ref Engine e){
    let u32 s=unsafe{control_access_raw(e as ptr void)};
    if(s!=0){return .err(error(s));}return .ok(control::observe(ref e.meta.control));
}
pub fn Result<Engine,Error> create(Limits limits){return create_with_control_budget(limits,4194304);}
pub fn Result<memory::Observation,Error> program_memory(ref Engine e){
    let u32 s=unsafe{control_access_raw(e as ptr void)};
    if(s!=0){return .err(error(s));}return .ok(memory::observe(ref e.meta.programs));
}
pub fn Result<live::Observation,Error> instance_memory(ref Engine e){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}return .ok(live::observe(ref e.meta.heap));
}
pub fn Result<Engine,Error> create_with_control_budget(Limits limits,usize control_limit){
    return create_with_retention(limits,control_limit,memory::defaults());
}
pub fn Result<Engine,Error> create_with_retention(Limits limits,usize control_limit,memory::Limits retained){
    return create_with_compilation(limits,control_limit,retained,268435456);
}
pub fn Result<Engine,Error> create_with_compilation(Limits limits,usize control_limit,memory::Limits retained,usize working_limit){
    return create_with_instance_memory(limits,control_limit,retained,working_limit,live::Limits{.instance=268435456,.instances=536870912});
}
pub fn Result<Engine,Error> create_with_instance_memory(Limits limits,usize control_limit,memory::Limits retained,usize working_limit,live::Limits instance_limits){
    let usize required=required_control_bytes(limits)?;
    return allocate_owner(limits,control_limit,retained,working_limit,instance_limits,required,vec::empty<policy::Policy>());
}

pub fn Result<Engine,Error> create_with_policy(policy::Policy ceiling){
    let policy_limits::EngineLimits engine=policy::engine_limits(ref ceiling);
    let policy_limits::RunLimits run=policy::run_limits(ref ceiling);
    let policy_limits::CompileLimits compile=policy::compile_limits(ref ceiling);
    let Limits limits=Limits{.programs=if(engine.max_programs<64){engine.max_programs}else{64},
        .instances=if(engine.max_instances<64){engine.max_instances}else{64},
        .fuel=if(run.fuel<fuel::cli_limit()){run.fuel}else{fuel::cli_limit()}};
    let usize base=required_control_bytes(limits)?;
    let usize slot=unsafe{policy_slot_bytes_raw()};
    let usize strings=policy::heap_bytes(ref ceiling);
    if(slot==0 || slot>(18446744073709551615-base)/8 || strings>18446744073709551615-base-slot*8){
        return .err(error(8));
    }
    let usize total=base+slot*8+strings;
    if(total>engine.control_bytes || total>engine.memory_bytes){return .err(error(8));}
    var vec::Vec<policy::Policy> owned=vec::empty<policy::Policy>();
    if(!vec::reserve<policy::Policy>(ref mut owned,1).is_ok){return .err(error(6));}
    if(!vec::push<policy::Policy>(ref mut owned,ceiling).is_ok){return .err(error(6));}
    return allocate_owner(limits,engine.control_bytes,
        memory::Limits{.engine=engine.memory_bytes,.program=engine.program_bytes,.programs=engine.total_program_bytes},
        compile.working_bytes,live::Limits{.instance=run.memory_bytes,.instances=engine.instances_bytes},total,owned);
}

fn Result<Engine,Error> allocate_owner(Limits limits,usize control_limit,memory::Limits retained,usize working_limit,
    live::Limits instance_limits,usize required,vec::Vec<policy::Policy> owned){
    if(control_limit==0 || control_limit>4194304){return .err(error(1));}
    let control::Budget storage=switch(control::create(control_limit,required)){
        case .ok(v):{v}case .err(_):{return .err(error(8));}
    };
    let memory::Budget retained_storage=switch(memory::create_with_working(retained,required,working_limit)){
        case .ok(v):{v}case .err(e):{return .err(error(switch(e){case .Invalid:{1}case .Quota:{8}case .State:{7}}));}
    };
    let live::Budget payloads=switch(live::create(instance_limits)){
        case .ok(v):{v}case .err(_):{return .err(error(1));}
    };
    var vec::Vec<Program> programs=vec::empty<Program>();var vec::Vec<Program> scratch=vec::empty<Program>();
    var vec::Vec<Instance> instances=vec::empty<Instance>();
    if(!vec::reserve<Program>(ref mut programs,limits.programs).is_ok || !vec::reserve<Program>(ref mut scratch,limits.programs).is_ok || !vec::reserve<Instance>(ref mut instances,limits.instances).is_ok){return .err(error(6));}
    var vec::Vec<BoundInput> inputs=vec::empty<BoundInput>();var vec::Vec<BoundInput> input_scratch=vec::empty<BoundInput>();
    if(!vec::reserve<BoundInput>(ref mut inputs,limits.instances).is_ok || !vec::reserve<BoundInput>(ref mut input_scratch,limits.instances).is_ok){return .err(error(6));}
    var vec::Vec<Output> outputs=vec::empty<Output>();var vec::Vec<Output> output_scratch=vec::empty<Output>();
    if(!vec::reserve<Output>(ref mut outputs,limits.instances).is_ok || !vec::reserve<Output>(ref mut output_scratch,limits.instances).is_ok){return .err(error(6));}
    let bool configured=vec::len<policy::Policy>(ref owned)==1;
    var Engine e=Engine{.meta=Meta{.limits=limits,.thread=0,.lifetime=0,.active=0,.admission=1,.next=1,.result=0,.error=error(0),.event=pending(),.snapshot=empty_snapshot(),.closed=false,.control=storage,.programs=retained_storage,.heap=payloads,.configured=configured},
        .programs=programs,.scratch=scratch,.instances=instances,.inputs=inputs,.input_scratch=input_scratch,.outputs=outputs,.output_scratch=output_scratch,.policy=owned};
    let u32 status=unsafe {bind_raw(ref mut e as ptr mut void)};
    if(status!=0){return .err(error(status));}return .ok(e);
}
// Actual selected source admission and immutable Program retention; the temporary
// Entry vector transfers its owner through typed Fairy pop, not a raw ABI move.
pub fn Result<usize,Error> compile(ref mut Engine e,entries::Entry selected,usize image_limit){
    let usize admitted=unsafe{compile_preflight(e,0,ref selected as ptr void)}?;
    var vec::Vec<entries::Entry> incoming=vec::empty<entries::Entry>();
    if(!vec::reserve<entries::Entry>(ref mut incoming,1).is_ok){return .err(error(6));}
    if(!vec::push<entries::Entry>(ref mut incoming,selected).is_ok){return .err(error(6));}
    let u32 status=unsafe {compile_raw(e as ptr mut void,ref mut incoming as ptr mut void,image_limit)};
    return result(e,status);
}
fn usize project_source_limit(ref Engine e){
    let usize ceiling=sources::source_limit();
    if(!e.meta.configured){return ceiling;}
    let policy_limits::CompileLimits bounds=policy::compile_limits(vec::at<policy::Policy>(ref e.policy,0));
    return if(bounds.source_bytes<ceiling){bounds.source_bytes}else{ceiling};
}
// This entry selects the ordinary zero-argument Program, which cannot
// satisfy capability requirements. Preflight before touching the filesystem.
pub fn Result<usize,Error> compile_project(ref mut Engine e,ref projects::Project metadata,ref u8[] root,usize image_limit){
    let usize ready=unsafe{compile_preflight(e,0,null)}?;
    if(projects::requirements(metadata)!=0){return .err(error(5));}
    let usize limit=project_source_limit(e);
    let sources::Snapshot snapshot=switch(project_loader::load(metadata,root,limit)){
        case .ok(v):{v}
        case .err(reason):{return .err(error(switch(reason){case .Limit:{8}case .Acquisition:{1}case .Binding:{4}case .Compile:{4}}));}
    };
    let entries::Entry selected=switch(project_binding::select(metadata,snapshot)){
        case .ok(v):{v}
        case .err(reason):{return .err(Error{.status=4,.diagnostic=diagnostics::Error{
            .code=errors::make(3,reason.at.start),.at=reason.at}});}
    };
    return compile(e,selected,image_limit);
}
pub fn Result<usize,Error> compile_input(ref mut Engine e,input_entries::InputEntry selected,usize image_limit){
    let usize admitted=unsafe{compile_preflight(e,1,ref selected as ptr void)}?;
    var vec::Vec<input_entries::InputEntry> incoming=vec::empty<input_entries::InputEntry>();
    if(!vec::reserve<input_entries::InputEntry>(ref mut incoming,1).is_ok){return .err(error(6));}
    if(!vec::push<input_entries::InputEntry>(ref mut incoming,selected).is_ok){return .err(error(6));}
    let u32 status=unsafe {compile_input_raw(e as ptr mut void,ref mut incoming as ptr mut void,image_limit)};
    return result(e,status);
}
pub fn Result<usize,Error> create_instance(ref mut Engine e,usize program,usize budget){let u32 s=unsafe{call_raw(e as ptr mut void,1,program,budget)};return result(e,s);}
pub fn Result<usize,Error> compile_output(ref mut Engine e,entries::Entry selected,usize image_limit){
    let usize admitted=unsafe{compile_preflight(e,2,ref selected as ptr void)}?;
    var vec::Vec<entries::Entry> incoming=vec::empty<entries::Entry>();
    if(!vec::reserve<entries::Entry>(ref mut incoming,1).is_ok){return .err(error(6));}
    if(!vec::push<entries::Entry>(ref mut incoming,selected).is_ok){return .err(error(6));}
    let u32 s=unsafe{compile_output_raw(e as ptr mut void,ref mut incoming as ptr mut void,image_limit,0)};return result(e,s);
}
pub fn Result<usize,Error> compile_input_output(ref mut Engine e,input_entries::InputEntry selected,usize image_limit){
    let usize admitted=unsafe{compile_preflight(e,3,ref selected as ptr void)}?;
    var vec::Vec<input_entries::InputEntry> incoming=vec::empty<input_entries::InputEntry>();
    if(!vec::reserve<input_entries::InputEntry>(ref mut incoming,1).is_ok){return .err(error(6));}
    if(!vec::push<input_entries::InputEntry>(ref mut incoming,selected).is_ok){return .err(error(6));}
    let u32 s=unsafe{compile_output_raw(e as ptr mut void,ref mut incoming as ptr mut void,image_limit,1)};return result(e,s);
}
pub fn Result<usize,Error> create_output_instance(ref mut Engine e,usize program,usize budget,usize limit,bool allowed){
    var vec::Vec<input_bytes::Snapshot> incoming=vec::empty<input_bytes::Snapshot>();
    let u32 s=unsafe{instance_output_raw(e as ptr mut void,program,ref mut incoming as ptr mut void,budget,limit,if(allowed){1}else{0})};return result(e,s);
}
pub fn Result<usize,Error> create_input_output_instance(ref mut Engine e,usize program,input_bytes::Snapshot input,usize budget,usize limit,bool allowed){
    return bind_input_output(e,program,input,budget,limit,if(allowed){1}else{0});
}
// Modes 0/1 are trusted legacy denial/allow. Modes 2/3 carry configured
// denial/allow and can only be selected after the Engine policy check.
fn Result<usize,Error> bind_input_output(ref mut Engine e,usize program,input_bytes::Snapshot input,usize budget,usize limit,u32 authority){
    let u32 preflight=unsafe{input_preflight_raw(e as ptr mut void,program,budget,ref input as ptr void,1,limit,authority)};
    if(preflight!=0){return .err(error(preflight));}
    var vec::Vec<input_bytes::Snapshot> incoming=vec::empty<input_bytes::Snapshot>();
    if(!vec::reserve<input_bytes::Snapshot>(ref mut incoming,1).is_ok){return .err(error(6));}
    if(!vec::push<input_bytes::Snapshot>(ref mut incoming,input).is_ok){return .err(error(6));}
    let u32 s=unsafe{instance_output_raw(e as ptr mut void,program,ref mut incoming as ptr mut void,budget,limit,authority)};return result(e,s);
}
fn Result<usize,Error> check_run_policy(ref Engine e,ref run_config::RunConfig run){
    let u32 access=unsafe{control_access_raw(e as ptr void)};
    if(access!=0){return .err(error(access));}
    if(e.meta.closed){return .err(error(2));}
    if(!e.meta.configured || !run_config::narrowed_to(run,vec::at<policy::Policy>(ref e.policy,0))){
        return .err(error(5));
    }
    return .ok(0);
}

fn Result<policy_limits::CompileLimits,Error> source_host_limits(ref Engine e,ref run_config::RunConfig run){
    let usize checked=check_run_policy(e,run)?;
    if(!bytes::equal(run_config::module_name(run),b"main") ||
        !bytes::equal(run_config::function_name(run),b"main")){return .err(error(5));}
    if(e.meta.admission==0 || e.meta.next==0 || vec::len<Program>(ref e.programs)>=e.meta.limits.programs){return .err(error(8));}
    return .ok(policy::compile_limits(vec::at<policy::Policy>(ref e.policy,0)));
}

// Single-source entry through the existing private scalar host dialect.
pub fn Result<usize,Error> compile_scalar_host(ref mut Engine e,ref u8[] source,host_catalog::Catalog imports,
    ref u32[] digest,ref run_config::RunConfig run){
    let policy_limits::CompileLimits limits=source_host_limits(e,run)?;
    if(source.len>limits.source_bytes){return .err(error(8));}
    var ir::Program code=ir::empty();
    switch(compiler::lower_scalar_host(source,ref imports,ref mut code)){
        case .ok(_):{}
        case .err(problem):{
            let usize at=problem.offset;
            return .err(Error{.status=4,.diagnostic=diagnostics::Error{
                .code=problem,.at=sources::Span{.source=0,.start=at,.end=if(at<source.len){at+1}else{at}}}});
        }
    };
    if(code.count>limits.instructions || code.registers>limits.registers_per_function){return .err(error(8));}
    return retain_scalar_host(e,ref code,imports,digest,run);
}

// Trusted internal IR admission. The Engine retains the resulting verified owner.
pub fn Result<usize,Error> retain_scalar_host(ref mut Engine e,ref ir::Program code,host_catalog::Catalog imports,
    ref u32[] digest,ref run_config::RunConfig run){
    let host_program::Program verified=verify_scalar_host(e,code,imports,digest,run)?;
    var vec::Vec<host_program::Program> incoming=vec::empty<host_program::Program>();
    if(!vec::push<host_program::Program>(ref mut incoming,verified).is_ok){return .err(error(6));}
    let u32 status=unsafe{retain_host_raw(e as ptr mut void,ref mut incoming as ptr mut void)};
    return result(e,status);
}

fn Result<host_program::Program,Error> verify_scalar_host(ref Engine e,ref ir::Program code,host_catalog::Catalog imports,
    ref u32[] digest,ref run_config::RunConfig run){
    let usize checked=check_run_policy(e,run)?;
    if(e.meta.admission==0 || e.meta.next==0 || vec::len<Program>(ref e.programs)>=e.meta.limits.programs){return .err(error(8));}
    return switch(host_program::retain(code,imports,digest,vec::at<policy::Policy>(ref e.policy,0),run)){
        case .ok(v):{.ok(v)}
        case .err(reason):{return .err(error(switch(reason){
            case .Authority:{5}case .Allocation:{6}case .Code:{4}case .Catalog:{1}case .Binding:{1}
        }));}
    };
}

pub fn Result<usize,Error> prepare_scalar_host(ref mut Engine e,usize program,ref run_config::RunConfig run){
    let u32 status=unsafe{prepare_host_raw(e as ptr mut void,program,run as ptr void)};
    return result(e,status);
}
pub fn Result<Event,Error> reply_scalar_host(ref mut Engine e,usize instance,usize run,usize request,u8 kind,ref u8[] payload){
    return receive_host_reply(e,instance,run,request,kind,payload.len,0,payload);
}
// Supplies the next bounded piece of a typed reply. Offsets and total are
// measured in wire bytes. An empty fatal reply uses total and offset zero.
pub fn Result<Event,Error> receive_host_reply(ref mut Engine e,usize instance,usize run,usize request,
    u8 kind,usize total,usize offset,ref u8[] chunk){
    let u32 status=unsafe{reply_host_raw(e as ptr mut void,instance,run,request,kind,chunk as ptr u8,chunk.len,total,offset)};
    let usize completed=result(e,status)?;return .ok(e.meta.event);
}
fn Result<usize,Error> host_output_index(ref Engine e,usize instance){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}
    let usize oi=switch(output_index(ref e.outputs,instance)){
        case .ok(v):{v}case .err(s):{return .err(error(s));}
    };
    let ref Output owner=vec::at<Output>(ref e.outputs,oi);
    if(vec::len<host::Exchange>(ref owner.host)!=1){return .err(error(2));}
    return .ok(oi);
}
pub fn Result<host::ScalarEvent,Error> observe_scalar_host(ref Engine e,usize instance){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}
    switch(instance_index(ref e.instances,instance)){
        case .ok(i):{
            let host::ScalarEvent saved=vec::at<Instance>(ref e.instances,i).host_terminal;
            if(saved.phase!=0){return .ok(saved);}
        }
        case .err(_):{return .err(error(2));}
    };
    let usize oi=host_output_index(e,instance)?;
    let ref Output owner=vec::at<Output>(ref e.outputs,oi);
    return switch(host::observe_scalar(vec::at<host::Exchange>(ref owner.host,0))){
        case .ok(v):{.ok(v)}case .err(_):{.err(error(7))}
    };
}
// The borrow is scoped to the immutable Engine view. Copy into adapter-owned
// storage before stepping, replying, cancelling or destroying the Instance.
pub fn Result<ref u8[],Error> host_request_payload(ref Engine e,usize instance){
    let usize oi=host_output_index(e,instance)?;
    let ref Output owner=vec::at<Output>(ref e.outputs,oi);
    let ref host::Exchange exchange=vec::at<host::Exchange>(ref owner.host,0);
    if(host::deadline_reached(exchange,unsafe{monotonic_ticks_raw()})){return .err(error(11));}
    return switch(host::request_bytes(exchange)){
        case .ok(data):{.ok(data)}case .err(_):{.err(error(11))}
    };
}
pub fn Result<HostRequest,Error> scalar_host_request(ref Engine e,usize instance){
    let usize oi=host_output_index(e,instance)?;
    let ref Output owner=vec::at<Output>(ref e.outputs,oi);
    let ref host::Exchange exchange=vec::at<host::Exchange>(ref owner.host,0);
    let host::Observation state=host::observe(exchange);
    let ref u8[] data=switch(host::request_bytes(exchange)){
        case .ok(v):{v}case .err(_):{return .err(error(11));}
    };
    if(host::deadline_reached(exchange,unsafe{monotonic_ticks_raw()})){return .err(error(11));}
    if(data.len!=14 || state.run!=instance){return .err(error(7));}
    var u8[14] payload=[0;14];var usize i=0;
    while(i<14){payload[i]=data[i];i+=1;}
    return .ok(HostRequest{.run=state.run,.request=state.request,.import_id=state.import_id,.payload=payload});
}

// Compile the configured entry once. The retained Program starts with no pins.
pub fn Result<usize,Error> compile_granted_output(ref mut Engine e,modules::Index index,
    ref run_config::RunConfig run,usize image_limit){
    let usize checked=check_run_policy(e,run)?;
    let input_entries::InputEntry selected=switch(input_entries::select_i32_input(
        index,run_config::module_name(run),run_config::function_name(run))){
        case .ok(v):{v}
        case .err(e):{return .err(Error{.status=4,.diagnostic=diagnostics::Error{
            .code=errors::make(3,e.at.start),.at=e.at}});}
    };
    return compile_input_output(e,selected,image_limit);
}

// Program and Instance IDs are scoped to this Engine. Each run rechecks
// policy and entry before binding a fresh input snapshot and continuation.
pub fn Result<usize,Error> prepare_granted_instance(ref mut Engine e,usize program,
    ref run_config::RunConfig run,input_bytes::Snapshot input){
    let policy_limits::RunLimits limits=check_run_input(e,run,ref input)?;
    let bool emits=program_authority(e,program,run)?;
    let usize max_output=if(emits){limits.output_bytes}else{0};
    let usize pending=required_pending_bytes(e,program,max_output)?;
    if(pending>limits.memory_bytes-input_bytes::capacity(ref input)){return .err(error(8));}
    let usize instance=bind_input_output(e,program,input,limits.fuel,max_output,if(emits){3}else{2})?;
    return switch(prepare_instance(e,instance)){
        case .ok(_):{.ok(instance)}
        case .err(failure):{let usize disposed=destroy_instance(e,instance)?;.err(failure)}
    };
}

fn Result<policy_limits::RunLimits,Error> check_run_input(ref Engine e,ref run_config::RunConfig run,
    ref input_bytes::Snapshot input){
    let usize checked=check_run_policy(e,run)?;
    let policy_limits::RunLimits limits=run_config::run_limits(run);
    if(limits.fuel>e.meta.limits.fuel || input_bytes::view(input).len>limits.input_bytes ||
        input_bytes::capacity(input)>limits.memory_bytes){return .err(error(8));}
    return .ok(limits);
}

fn Result<bool,Error> program_authority(ref Engine e,usize id,ref run_config::RunConfig run){
    let usize index=switch(program_index(ref e.programs,id,true)){
        case .ok(v):{v}case .err(status):{return .err(error(status));}
    };
    let ref EntryBinding entry=ref vec::at<Program>(ref e.programs,index).entry;
    if(entry.scope_len==0){return .err(error(1));}
    let ref u8[] scope=ref entry.scope;
    let ref u8[] function=ref entry.function;
    if(!bytes::equal(scope[..entry.scope_len],run_config::module_name(run)) ||
        !bytes::equal(function[..entry.function_len],run_config::function_name(run))){
        return .err(error(5));
    }
    let ref u8[] name=b"brownie.output.emit";
    if(entry.emits && (!run_config::declares(run,name) || !run_config::grants(run,name))){
        return .err(error(5));
    }
    return .ok(entry.emits);
}

pub fn Result<usize,Error> prepare_granted_output(ref mut Engine e,modules::Index index,
    ref run_config::RunConfig run,input_bytes::Snapshot input,usize image_limit){
    let policy_limits::RunLimits checked=check_run_input(e,run,ref input)?;
    let usize program=compile_granted_output(e,index,run,image_limit)?;
    return switch(prepare_granted_instance(e,program,run,input)){
        case .ok(instance):{let usize released=release_program(e,program)?;.ok(instance)}
        case .err(failure):{let usize released=release_program(e,program)?;.err(failure)}
    };
}

pub fn Result<Output,Error> take_output(ref mut Engine e,usize instance){
    let u32 preflight=unsafe{output_preflight_raw(e as ptr mut void,instance)};
    if(preflight!=0){return .err(error(preflight));}
    var vec::Vec<Output> outgoing=vec::empty<Output>();
    if(!vec::reserve<Output>(ref mut outgoing,1).is_ok){return .err(error(6));}
    let u32 s=unsafe{take_output_raw(e as ptr mut void,instance,ref mut outgoing as ptr mut void)};
    if(s!=0){return .err(error(s));}return .ok(pop_output(ref mut outgoing));
}
pub fn output_programs::Completion output_completion(ref Output o){return output_programs::observe(ref o.run);}
pub fn bool output_available(ref Output o){return output_programs::has_output(ref o.run);}
pub fn ref u8[] output_view(ref Output o){
    let ref u8[] data=output_programs::view(ref o.run);
    // Tie both the empty and owned cases to this exact retained resource.
    return unsafe {byte_slice::from_raw_parts(o,data as ptr u8,data.len)};
}
// The accepted owning input association: its bytes move once, stay immutable,
// and are reclaimed with the Instance even after cancellation or Program release.
pub fn Result<usize,Error> create_input_instance(ref mut Engine e,usize program,input_bytes::Snapshot input,usize budget){
    let u32 preflight=unsafe{input_preflight_raw(e as ptr mut void,program,budget,ref input as ptr void,0,0,0)};
    if(preflight!=0){return .err(error(preflight));}
    var vec::Vec<input_bytes::Snapshot> incoming=vec::empty<input_bytes::Snapshot>();
    if(!vec::reserve<input_bytes::Snapshot>(ref mut incoming,1).is_ok){return .err(error(6));}
    if(!vec::push<input_bytes::Snapshot>(ref mut incoming,input).is_ok){return .err(error(6));}
    let u32 s=unsafe{instance_input_raw(e as ptr mut void,program,ref mut incoming as ptr mut void,budget)};return result(e,s);
}
pub fn Result<usize,Error> release_program(ref mut Engine e,usize program){let u32 s=unsafe{call_raw(e as ptr mut void,2,program,0)};return result(e,s);}
pub fn Result<usize,Error> destroy_instance(ref mut Engine e,usize instance){let u32 s=unsafe{call_raw(e as ptr mut void,3,instance,0)};return result(e,s);}
pub fn Result<usize,Error> destroy(ref mut Engine e){let u32 s=unsafe{call_raw(e as ptr mut void,4,0,0)};return result(e,s);}
pub fn Result<Event,Error> execute_once(ref mut Engine e,usize instance){
    let u32 s=unsafe{call_raw(e as ptr mut void,5,instance,0)};
    if(s!=0){return .err(error(s));}return .ok(e.meta.event);
}
// Preparation owns the continuation but executes no guest opcode. Step is a
// separate operation; a prepared Instance cannot enter the synchronous path.
pub fn Result<Event,Error> prepare_instance(ref mut Engine e,usize instance){
    let u32 s=unsafe{call_raw(e as ptr mut void,9,instance,0)};
    let usize completed=result(e,s)?;return .ok(e.meta.event);
}
pub fn Result<Event,Error> step_instance(ref mut Engine e,usize instance,usize quantum){
    let u32 s=unsafe{call_raw(e as ptr mut void,10,instance,quantum)};
    let usize completed=result(e,s)?;return .ok(e.meta.event);
}
pub fn usize output_transport_bytes(){return 8*unsafe{output_fact_raw(null,0)};}
pub fn Result<output_copy::State,Error> output_copy_progress(ref Engine e,usize instance){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}if(e.meta.closed){return .err(error(2));}
    let usize ii=switch(instance_index(ref e.instances,instance)){case .ok(v):{v}case .err(s):{return .err(error(s));}};
    if(vec::at<Instance>(ref e.instances,ii).phase!=3){return .err(error(11));}
    let usize oi=switch(output_index(ref e.outputs,instance)){case .ok(v):{v}case .err(_):{return .err(error(7));}};
    let ref Output saved=vec::at<Output>(ref e.outputs,oi);
    if(vec::len<machines::Machine>(ref saved.pending)!=1){return .err(error(7));}
    return .ok(machines::observe(vec::at<machines::Machine>(ref saved.pending,0)).cursor.output);
}
pub fn Result<array_fill::State,Error> array_fill_progress(ref Engine e,usize instance){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}if(e.meta.closed){return .err(error(2));}
    let usize ii=switch(instance_index(ref e.instances,instance)){case .ok(v):{v}case .err(s):{return .err(error(s));}};
    if(vec::at<Instance>(ref e.instances,ii).phase!=3){return .err(error(11));}
    let usize oi=switch(output_index(ref e.outputs,instance)){case .ok(v):{v}case .err(_):{return .err(error(7));}};
    let ref Output saved=vec::at<Output>(ref e.outputs,oi);
    if(vec::len<machines::Machine>(ref saved.pending)!=1){return .err(error(7));}
    return .ok(machines::observe(vec::at<machines::Machine>(ref saved.pending,0)).cursor.array);
}
// The same compact recipe bank now carries fill and copy work; no extra bank
// or payload snapshot is allocated. The normalized opcode distinguishes them.
pub fn Result<array_fill::State,Error> array_copy_progress(ref Engine e,usize instance){return array_fill_progress(e,instance);}
// Private observation of the owning VM CALL recipe, with the same guard/phase
// and Program pin as other saved work. It grants no authority to mutate the VM.
pub fn Result<call_work::State,Error> call_copy_progress(ref Engine e,usize instance){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}if(e.meta.closed){return .err(error(2));}
    let usize ii=switch(instance_index(ref e.instances,instance)){case .ok(v):{v}case .err(s):{return .err(error(s));}};
    if(vec::at<Instance>(ref e.instances,ii).phase!=3){return .err(error(11));}
    let usize oi=switch(output_index(ref e.outputs,instance)){case .ok(v):{v}case .err(_):{return .err(error(7));}};
    let ref Output saved=vec::at<Output>(ref e.outputs,oi);
    if(vec::len<machines::Machine>(ref saved.pending)!=1){return .err(error(7));}
    return .ok(machines::observe(vec::at<machines::Machine>(ref saved.pending,0)).cursor.call);
}
pub fn Result<metadata_budget::State,Error> authority_metadata_progress(ref Engine e,usize instance){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}if(e.meta.closed){return .err(error(2));}
    let usize ii=switch(instance_index(ref e.instances,instance)){case .ok(v):{v}case .err(s):{return .err(error(s));}};
    if(vec::at<Instance>(ref e.instances,ii).phase!=3){return .err(error(11));}
    let usize oi=switch(output_index(ref e.outputs,instance)){case .ok(v):{v}case .err(_):{return .err(error(7));}};
    let ref Output saved=vec::at<Output>(ref e.outputs,oi);
    if(vec::len<machines::Machine>(ref saved.pending)!=1){return .err(error(7));}
    return .ok(machines::observe(vec::at<machines::Machine>(ref saved.pending,0)).cursor.metadata);
}
pub fn Result<usize,Error> lifecycle_phase(ref Engine e,usize instance){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}if(e.meta.closed){return .err(error(2));}
    let usize ii=switch(instance_index(ref e.instances,instance)){case .ok(v):{v}case .err(s):{return .err(error(s));}};
    if(vec::at<Instance>(ref e.instances,ii).phase!=3){return .err(error(11));}
    let usize oi=switch(output_index(ref e.outputs,instance)){case .ok(v):{v}case .err(_):{return .err(error(7));}};
    let ref Output saved=vec::at<Output>(ref e.outputs,oi);
    if(vec::len<machines::Machine>(ref saved.pending)!=1){return .err(error(7));}
    return .ok(machines::observe(vec::at<machines::Machine>(ref saved.pending,0)).lifecycle.phase);
}
pub fn Result<usize,Error> call_metadata_phase(ref Engine e,usize instance){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}if(e.meta.closed){return .err(error(2));}
    let usize ii=switch(instance_index(ref e.instances,instance)){case .ok(v):{v}case .err(s):{return .err(error(s));}};
    if(vec::at<Instance>(ref e.instances,ii).phase!=3){return .err(error(11));}
    let usize oi=switch(output_index(ref e.outputs,instance)){case .ok(v):{v}case .err(_):{return .err(error(7));}};
    let ref Output saved=vec::at<Output>(ref e.outputs,oi);
    if(vec::len<machines::Machine>(ref saved.pending)!=1){return .err(error(7));}
    return .ok(machines::observe(vec::at<machines::Machine>(ref saved.pending,0)).cursor.call_metadata_phase as usize);
}
pub fn Result<usize,Error> return_metadata_phase(ref Engine e,usize instance){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}if(e.meta.closed){return .err(error(2));}
    let usize ii=switch(instance_index(ref e.instances,instance)){case .ok(v):{v}case .err(s):{return .err(error(s));}};
    if(vec::at<Instance>(ref e.instances,ii).phase!=3){return .err(error(11));}
    let usize oi=switch(output_index(ref e.outputs,instance)){case .ok(v):{v}case .err(_):{return .err(error(7));}};
    let ref Output saved=vec::at<Output>(ref e.outputs,oi);
    if(vec::len<machines::Machine>(ref saved.pending)!=1){return .err(error(7));}
    return .ok(machines::observe(vec::at<machines::Machine>(ref saved.pending,0)).cursor.return_metadata.phase as usize);
}
pub fn Result<return_work::State,Error> return_work_progress(ref Engine e,usize instance){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}if(e.meta.closed){return .err(error(2));}
    let usize ii=switch(instance_index(ref e.instances,instance)){case .ok(v):{v}case .err(s):{return .err(error(s));}};
    if(vec::at<Instance>(ref e.instances,ii).phase!=3){return .err(error(11));}
    let usize oi=switch(output_index(ref e.outputs,instance)){case .ok(v):{v}case .err(_):{return .err(error(7));}};
    let ref Output saved=vec::at<Output>(ref e.outputs,oi);
    if(vec::len<machines::Machine>(ref saved.pending)!=1){return .err(error(7));}
    return .ok(machines::observe(vec::at<machines::Machine>(ref saved.pending,0)).cursor.returned);
}
// Synchronous exact borrow: no Snapshot pointer is retained in an Instance or
// Program. Admission precedes inspection; completion precedes ending the borrow.
pub fn Result<Event,Error> execute_input_once(ref mut Engine e,usize instance,ref input_bytes::Snapshot input){
    let u32 s=unsafe{execute_input_raw(e as ptr mut void,instance,input as ptr void)};
    if(s!=0){return .err(error(s));}return .ok(e.meta.event);
}
pub fn Result<Event,Error> observe(ref mut Engine e,usize instance){
    let u32 s=unsafe{call_raw(e as ptr mut void,6,instance,0)};
    if(s!=0){return .err(error(s));}return .ok(e.meta.event);
}
pub fn Result<Event,Error> cancel_ready(ref mut Engine e,usize instance){
    let u32 s=unsafe{call_raw(e as ptr mut void,7,instance,0)};
    if(s!=0){return .err(error(s));}return .ok(e.meta.event);
}
pub fn Result<Snapshot,Error> inspect(ref mut Engine e){
    let u32 s=unsafe{call_raw(e as ptr mut void,8,0,0)};
    if(s!=0){return .err(error(s));}return .ok(e.meta.snapshot);
}
fn u32 failed(ref mut Meta m,u32 status){m.error=error(status);return status;}
fn u32 success(ref mut Meta m,usize value){m.error=error(0);m.result=value;return 0;}
// These typed helpers are private generated transport, not raw ABI declarations.
// The C projector supplies live field addresses; all lifecycle decisions stay here.
fn u32 bind_inner(ref mut Meta m,usize thread,usize lifetime){
    if(thread==0 || lifetime==0 || m.thread!=0 || m.lifetime!=0){return 7;}
    m.thread=thread;m.lifetime=lifetime;return 0;
}
fn u32 begin_inner(ref mut Meta m,usize thread,usize lifetime){
    if(m.thread!=thread || m.lifetime!=lifetime || thread==0 || lifetime==0){return 10;}
    if(m.active!=0){return 3;}if(m.closed){return failed(m,2);}if(m.admission==0){return failed(m,8);}
    m.active=m.admission;m.admission=if(m.admission==18446744073709551615){0}else{m.admission+1};return 0;
}
fn u32 end_inner(ref mut Meta m,usize thread,usize lifetime,usize epoch){
    if(m.thread!=thread || m.lifetime!=lifetime || thread==0 || lifetime==0){return 10;}
    if(epoch==0 || m.active!=epoch){return 7;}m.active=0;return 0;
}
fn Result<usize,u32> program_index(ref vec::Vec<Program> v,usize id,bool live){
    var usize i=0;while(i<vec::len<Program>(v)){let ref Program p=vec::at<Program>(v,i);
        if(p.id==id && (!live || !p.released)){return .ok(i);}i+=1;
    }return .err(2);
}
fn Result<usize,u32> instance_index(ref vec::Vec<Instance> v,usize id){
    var usize i=0;while(i<vec::len<Instance>(v)){if(vec::at<Instance>(v,i).id==id){return .ok(i);}i+=1;}return .err(2);
}
fn void advance(ref mut Meta m){m.next=if(m.next==18446744073709551615){0}else{m.next+1};}
// Facts describe actual typed SDK backing; every quota decision stays Fairy.
fn usize instance_identity(ref Instance instance){return instance.id;}
fn usize program_identity(ref Program program){return program.id;}
fn usize entry_heap(ref entries::Entry entry){return unsafe{compile_fact_raw(entry as ptr void,0,1)};}
fn usize input_entry_heap(ref input_entries::InputEntry entry){return unsafe{compile_fact_raw(entry as ptr void,1,1)};}
fn Result<usize,Error> compile_requirement(usize index,usize width){
    let usize maximum=18446744073709551615;
    if(index==0 || width==0){return .err(error(7));}
    if(width>maximum/8 || index>maximum-8*width){return .err(error(8));}
    let usize overhead=index+8*width;
    if(overhead>maximum-bounded::working_bound()){return .err(error(8));}
    return .ok(overhead+bounded::working_bound());
}
pub fn Result<usize,Error> required_compile_bytes(ref entries::Entry entry){
    return compile_requirement(entry_heap(entry),unsafe{compile_fact_raw(entry as ptr void,0,0)});
}
pub fn Result<usize,Error> required_input_compile_bytes(ref input_entries::InputEntry entry){
    return compile_requirement(input_entry_heap(entry),unsafe{compile_fact_raw(entry as ptr void,1,0)});
}
// Owner-only synchronous code makes no callbacks between this preflight and
// ordinary admission. SDK reserve cannot reenter; the actual operation rechecks.
// No epoch is spent on preflight or on a rejected/failed incoming allocation.
fn Result<usize,Error> compile_preflight(ref mut Engine e,u32 mode,ptr void selected){
    let u32 status=unsafe{compile_preflight_raw(e as ptr mut void,mode,selected)};
    return if(status==0){.ok(0)}else{.err(error(status))};
}
fn u32 compile_preflight_inner(ref mut Meta m,ref vec::Vec<Program> programs,u32 mode,usize index,usize width){
    if(m.closed){return 2;}
    if(m.admission==0 || m.next==0 || vec::len<Program>(programs)>=m.limits.programs){return 8;}
    if(mode>3){return 1;}
    let retention::Plan possible=switch(retention_plan(m,if(mode==0){0}else{if(mode==1){1}else{2}})){
        case .ok(v):{v}case .err(status):{return status;}
    };
    // First guarded call validates Engine state before native source observation.
    if(index==0 && width==0){return 0;}
    let usize requirement=switch(compile_requirement(index,width)){case .ok(v):{v}case .err(e):{return e.status;}};
    return switch(memory::prepare_compile(ref mut m.programs,requirement-bounded::working_bound())){
        case .ok(_):{0}case .err(_):{8}
    };
}
fn Result<live::Plan,u32> prepare_payload(ref mut Meta m,usize old,usize next,usize transient){
    let live::Plan plan=switch(live::prepare(ref m.heap,old,next,transient)){
        case .ok(v):{v}case .err(_):{return .err(8);}
    };
    switch(memory::prepare_external(ref mut m.programs,plan.aggregate_peak)){
        case .ok(_):{}case .err(_):{return .err(8);}
    };
    assert(live::record(ref mut m.heap,ref plan).is_ok);return .ok(plan);
}
fn void commit_payload(ref mut Meta m,ref live::Plan plan){
    assert(live::commit(ref mut m.heap,plan).is_ok);
    let usize retained=live::observe(ref m.heap).current;
    assert(memory::commit_external(ref mut m.programs,retained).is_ok);
}
fn void release_payload(ref mut Meta m,usize bytes){
    assert(live::release(ref mut m.heap,bytes).is_ok);
    let usize retained=live::observe(ref m.heap).current;
    assert(memory::commit_external(ref mut m.programs,retained).is_ok);
}
fn u32 input_preflight_inner(ref mut Meta m,ref vec::Vec<Program> p,ref vec::Vec<Instance> v,
    usize code,usize budget,ref input_bytes::Snapshot input,u32 output,usize limit,u32 allowed,usize width){
    if(m.closed){return 2;}if(m.admission==0){return 8;}
    if(output>1 || limit>1048576 || allowed>3){return 1;}
    if(m.configured!=(allowed>=2) || (output==0 && m.configured) || budget>m.limits.fuel){return 5;}
    let usize pi=switch(program_index(p,code,true)){case .ok(index):{index}case .err(status):{return status;}};
    let ref Program program=vec::at<Program>(p,pi);
    if(output==0){if(vec::len<input_programs::Program>(ref program.input)!=1){return 1;}}
    else{
        if(vec::len<output_programs::Program>(ref program.output)!=1){return 1;}
        if(!output_programs::accepts_input(vec::at<output_programs::Program>(ref program.output,0))){return 1;}
    }
    if(vec::len<Instance>(v)>=m.limits.instances || m.next==0){return 8;}
    if(width==0 || width>18446744073709551615/8){return 7;}
    return switch(prepare_payload(m,0,input_bytes::capacity(input),8*width)){
        case .ok(_):{0}case .err(status):{status}
    };
}
fn Result<compilation::Plan,u32> compile_work(ref mut Meta m,usize incoming,usize index){
    if(index==0 || incoming==0 || index>18446744073709551615-incoming){return .err(8);}
    return switch(memory::prepare_compile(ref mut m.programs,incoming+index)){
        case .ok(p):{.ok(p)}case .err(_):{.err(8)}
    };
}
fn Result<retention::Plan,u32> retention_plan(ref Meta m,u32 kind){
    return switch(memory::prepare(ref m.programs,kind)){case .ok(p):{.ok(p)}case .err(_):{.err(8)}};
}
fn u32 compile_error(ref mut Meta m,diagnostics::Error e){
    if(e.code.kind==retention::quota_kind()){return failed(m,8);}
    if(e.code.kind==15){return failed(m,6);}
    m.error=Error{.status=4,.diagnostic=e};return 4;
}
// Cached from immutable proved IR at publication, never rescanned per execution.
fn Result<usize,Error> execution_bytes(ref Program program,usize output_limit){
    if(output_limit>1048576){return .err(error(1));}
    let bool output=vec::len<output_programs::Program>(ref program.output)==1;
    if(!output && output_limit!=0){return .err(error(1));}
    let usize extra=if(output){616+output_limit}else{0};
    if(extra>18446744073709551615-program.execution_scratch){return .err(error(8));}
    return .ok(program.execution_scratch+extra);
}
pub fn Result<usize,Error> required_execution_bytes(ref Engine e,usize program,usize output_limit){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}if(e.meta.closed){return .err(error(2));}
    let usize index=switch(program_index(ref e.programs,program,false)){
        case .ok(v):{v}case .err(status):{return .err(error(status));}
    };
    return execution_bytes(vec::at<Program>(ref e.programs,index),output_limit);
}
fn Result<usize,Error> pending_bytes(ref Program program,usize limit){
    if(vec::len<output_programs::Program>(ref program.output)!=1 || limit>1048576){return .err(error(1));}
    return switch(pending_heap::prepare(program.execution_scratch,limit,pending_vm::pending_core_stride(),pending_vm::pending_machine_stride())){
        case .ok(v):{.ok(v.retained)}case .err(_):{.err(error(8))}
    };
}
pub fn Result<usize,Error> required_pending_bytes(ref Engine e,usize program,usize output_limit){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}if(e.meta.closed){return .err(error(2));}
    let usize index=switch(program_index(ref e.programs,program,false)){
        case .ok(v):{v}case .err(status):{return .err(error(status));}
    };
    return pending_bytes(vec::at<Program>(ref e.programs,index),output_limit);
}
fn u32 reserve_execution(ref mut Meta m,ref Program program,ref Instance instance){
    let usize transient=switch(execution_bytes(program,instance.output_limit)){
        case .ok(v):{v}case .err(e):{return failed(m,e.status);}
    };
    let usize retained=instance.input_bytes+instance.output_bytes;
    return switch(prepare_payload(m,retained,retained,transient)){
        case .ok(_):{0}case .err(status):{failed(m,status)}
    };
}
fn u32 compile_inner(ref mut Meta m,ref mut vec::Vec<Program> v,ref mut vec::Vec<entries::Entry> incoming,usize image_limit){
    if(vec::len<Program>(v)>=m.limits.programs || m.next==0){return failed(m,8);}
    if(vec::len<entries::Entry>(incoming)!=1){return failed(m,1);}
    var retention::Plan plan=switch(retention_plan(m,0)){case .ok(p):{p}case .err(s):{return failed(m,s);}};
    var compilation::Plan work=switch(compile_work(m,unsafe{compile_fact_raw(incoming as ptr void,0,2)},entry_heap(vec::at<entries::Entry>(incoming,0)))){case .ok(p):{p}case .err(status):{return failed(m,status);}};
    let Result<programs::Program,diagnostics::Error> built=bounded::compile(pop_entry(incoming),image_limit,ref mut plan,ref mut work);
    assert(memory::record_compile(ref mut m.programs,ref work).is_ok);
    assert(memory::record(ref mut m.programs,ref plan).is_ok);
    return switch(built){case .ok(code):{publish_program(m,v,code,plan.bytes)}case .err(e):{compile_error(m,e)}};
}
fn entries::Entry pop_entry(ref mut vec::Vec<entries::Entry> v){return switch(vec::pop<entries::Entry>(v)){
    case .some(e):{e}case .none:{assert(false);pop_entry(v)}
};}
fn u32 publish_program(ref mut Meta m,ref mut vec::Vec<Program> v,programs::Program code,usize bytes){
    let execution_heap::Plan heap=switch(execution_heap::prepare(programs::body(ref code),false,false,0)){
        case .ok(v):{v}case .err(_):{return failed(m,7);}
    };
    let usize id=m.next;
    var vec::Vec<programs::Program> retained=vec::empty<programs::Program>();
    if(!vec::reserve<programs::Program>(ref mut retained,1).is_ok){return failed(m,6);}
    if(!vec::push<programs::Program>(ref mut retained,code).is_ok){return failed(m,6);}
    if(!vec::push<Program>(v,Program{.id=id,.pins=0,.released=false,.code=retained,.input=vec::empty<input_programs::Program>(),.output=vec::empty<output_programs::Program>(),.bytes=bytes,.execution_scratch=heap.scratch,.entry=empty_entry(),.host=vec::empty<host_program::Program>()}).is_ok){return failed(m,6);}
    assert(memory::publish(ref mut m.programs,bytes).is_ok);advance(m);return success(m,id);
}
fn input_entries::InputEntry pop_input_entry(ref mut vec::Vec<input_entries::InputEntry> v){return switch(vec::pop<input_entries::InputEntry>(v)){
    case .some(e):{e}case .none:{assert(false);pop_input_entry(v)}
};}
fn u32 compile_input_inner(ref mut Meta m,ref mut vec::Vec<Program> v,ref mut vec::Vec<input_entries::InputEntry> incoming,usize image_limit){
    if(vec::len<Program>(v)>=m.limits.programs || m.next==0){return failed(m,8);}
    if(vec::len<input_entries::InputEntry>(incoming)!=1){return failed(m,1);}
    var retention::Plan plan=switch(retention_plan(m,1)){case .ok(p):{p}case .err(s):{return failed(m,s);}};
    var compilation::Plan work=switch(compile_work(m,unsafe{compile_fact_raw(incoming as ptr void,1,2)},input_entry_heap(vec::at<input_entries::InputEntry>(incoming,0)))){case .ok(p):{p}case .err(status):{return failed(m,status);}};
    let Result<input_programs::Program,diagnostics::Error> built=bounded::compile_input(pop_input_entry(incoming),image_limit,ref mut plan,ref mut work);
    assert(memory::record_compile(ref mut m.programs,ref work).is_ok);
    assert(memory::record(ref mut m.programs,ref plan).is_ok);
    return switch(built){case .ok(code):{publish_input_program(m,v,code,plan.bytes)}case .err(e):{compile_error(m,e)}};
}
fn u32 publish_input_program(ref mut Meta m,ref mut vec::Vec<Program> v,input_programs::Program code,usize bytes){
    let execution_heap::Plan heap=switch(execution_heap::prepare(ref input_programs::code(ref code).body,true,false,0)){
        case .ok(v):{v}case .err(_):{return failed(m,7);}
    };
    let usize id=m.next;var vec::Vec<input_programs::Program> retained=vec::empty<input_programs::Program>();
    if(!vec::reserve<input_programs::Program>(ref mut retained,1).is_ok){return failed(m,6);}
    if(!vec::push<input_programs::Program>(ref mut retained,code).is_ok){return failed(m,6);}
    if(!vec::push<Program>(v,Program{.id=id,.pins=0,.released=false,.code=vec::empty<programs::Program>(),.input=retained,.output=vec::empty<output_programs::Program>(),.bytes=bytes,.execution_scratch=heap.scratch,.entry=empty_entry(),.host=vec::empty<host_program::Program>()}).is_ok){return failed(m,6);}
    assert(memory::publish(ref mut m.programs,bytes).is_ok);advance(m);return success(m,id);
}
fn u32 compile_output_inner(ref mut Meta m,ref mut vec::Vec<Program> v,ref mut vec::Vec<entries::Entry> incoming,usize limit){
    if(vec::len<Program>(v)>=m.limits.programs || m.next==0){return failed(m,8);}
    if(vec::len<entries::Entry>(incoming)!=1){return failed(m,1);}
    var retention::Plan plan=switch(retention_plan(m,2)){case .ok(p):{p}case .err(s):{return failed(m,s);}};
    var compilation::Plan work=switch(compile_work(m,unsafe{compile_fact_raw(incoming as ptr void,0,2)},entry_heap(vec::at<entries::Entry>(incoming,0)))){case .ok(p):{p}case .err(status):{return failed(m,status);}};
    let Result<output_programs::Program,diagnostics::Error> built=bounded::compile_output(pop_entry(incoming),limit,ref mut plan,ref mut work);
    assert(memory::record_compile(ref mut m.programs,ref work).is_ok);
    assert(memory::record(ref mut m.programs,ref plan).is_ok);
    return switch(built){case .ok(code):{publish_output_program(m,v,code,plan.bytes,empty_entry())}case .err(e):{compile_error(m,e)}};
}
fn u32 compile_input_output_inner(ref mut Meta m,ref mut vec::Vec<Program> v,ref mut vec::Vec<input_entries::InputEntry> incoming,usize limit){
    if(vec::len<Program>(v)>=m.limits.programs || m.next==0){return failed(m,8);}
    if(vec::len<input_entries::InputEntry>(incoming)!=1){return failed(m,1);}
    var retention::Plan plan=switch(retention_plan(m,2)){case .ok(p):{p}case .err(s):{return failed(m,s);}};
    var compilation::Plan work=switch(compile_work(m,unsafe{compile_fact_raw(incoming as ptr void,1,2)},input_entry_heap(vec::at<input_entries::InputEntry>(incoming,0)))){case .ok(p):{p}case .err(status):{return failed(m,status);}};
    let EntryBinding entry=switch(bind_entry(m.configured,vec::at<input_entries::InputEntry>(incoming,0))){
        case .ok(v):{v}case .err(status):{return failed(m,status);}
    };
    let Result<output_programs::Program,diagnostics::Error> built=bounded::compile_input_output(pop_input_entry(incoming),limit,ref mut plan,ref mut work);
    assert(memory::record_compile(ref mut m.programs,ref work).is_ok);
    assert(memory::record(ref mut m.programs,ref plan).is_ok);
    return switch(built){case .ok(code):{publish_output_program(m,v,code,plan.bytes,entry)}case .err(e):{compile_error(m,e)}};
}
fn EntryBinding empty_entry(){
    return EntryBinding{.scope=[0;128],.function=[0;64],.scope_len=0,.function_len=0,.emits=false};
}
fn Result<EntryBinding,u32> bind_entry(bool configured,ref input_entries::InputEntry selected){
    if(!configured){return .ok(empty_entry());}
    let ref modules::Index index=input_entries::index(selected);
    let modules::Symbol symbol=switch(modules::symbol(index,input_entries::selected(selected))){
        case .ok(v):{v}case .err(_):{return .err(7);}
    };
    let ref u8[] scope=switch(modules::module_name(index,symbol.owner)){
        case .ok(v):{v}case .err(_):{return .err(7);}
    };
    let ref u8[] function=switch(sources::view(modules::snapshot(index),symbol.name)){
        case .ok(v):{v}case .err(_):{return .err(7);}
    };
    if(scope.len==0 || scope.len>128 || function.len==0 || function.len>64){return .err(4);}
    // Fill the arrays before constructing the value. The pinned optimizer
    // loses indexed writes through EntryBinding fields at this return boundary.
    var u8[128] scope_bytes=[0;128];
    var u8[64] function_bytes=[0;64];
    var usize i=0;
    while(i<scope.len){scope_bytes[i]=scope[i];i+=1;}
    i=0;
    while(i<function.len){function_bytes[i]=function[i];i+=1;}
    return .ok(EntryBinding{.scope=scope_bytes,.function=function_bytes,
        .scope_len=scope.len,.function_len=function.len,.emits=false});
}
fn u32 publish_output_program(ref mut Meta m,ref mut vec::Vec<Program> v,output_programs::Program code,usize bytes,EntryBinding selected){
    var EntryBinding entry=selected;
    if(entry.scope_len!=0){entry.emits=output_programs::requires_emit(ref code);}
    let usize scratch=output_programs::preparation(ref code).scratch;
    let usize id=m.next;var vec::Vec<output_programs::Program> retained=vec::empty<output_programs::Program>();
    if(!vec::reserve<output_programs::Program>(ref mut retained,1).is_ok){return failed(m,6);}
    if(!vec::push<output_programs::Program>(ref mut retained,code).is_ok){return failed(m,6);}
    if(!vec::push<Program>(v,Program{.id=id,.pins=0,.released=false,.code=vec::empty<programs::Program>(),
        .input=vec::empty<input_programs::Program>(),.output=retained,.bytes=bytes,.execution_scratch=scratch,.entry=entry,.host=vec::empty<host_program::Program>()}).is_ok){return failed(m,6);}
    assert(memory::publish(ref mut m.programs,bytes).is_ok);advance(m);return success(m,id);
}
fn host_program::Program pop_host_program(ref mut vec::Vec<host_program::Program> v){
    return switch(vec::pop<host_program::Program>(v)){
        case .some(p):{p}case .none:{assert(false);pop_host_program(v)}
    };
}
fn u32 publish_host_inner(ref mut Meta m,ref mut vec::Vec<Program> v,ref mut vec::Vec<host_program::Program> incoming,
    usize program_stride,usize ir_stride){
    if(!m.configured || vec::len<host_program::Program>(incoming)!=1){return failed(m,5);}
    if(m.next==0 || vec::len<Program>(v)>=m.limits.programs){return failed(m,8);}
    let usize bytes=control_layout::capacity(1)*program_stride+host_program::heap_bytes(vec::at<host_program::Program>(incoming,0),ir_stride);
    if(!memory::publish(ref mut m.programs,bytes).is_ok){return failed(m,8);}
    let host_program::Program code=pop_host_program(incoming);
    var vec::Vec<host_program::Program> retained=vec::empty<host_program::Program>();
    if(!vec::push<host_program::Program>(ref mut retained,code).is_ok){
        assert(memory::release(ref mut m.programs,bytes).is_ok);return failed(m,6);
    }
    let usize id=m.next;
    assert(vec::push<Program>(v,Program{.id=id,.pins=0,.released=false,.code=vec::empty<programs::Program>(),
        .input=vec::empty<input_programs::Program>(),.output=vec::empty<output_programs::Program>(),.bytes=bytes,
        .execution_scratch=0,.entry=empty_entry(),.host=retained}).is_ok);
    advance(m);return success(m,id);
}
fn u32 prepare_host_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref mut vec::Vec<Output> outputs,ref vec::Vec<policy::Policy> policies,ref run_config::RunConfig run,
    usize code,usize stride){
    if(!m.configured || vec::len<policy::Policy>(policies)!=1){return failed(m,5);}
    let usize pi=switch(program_index(p,code,true)){case .ok(x):{x}case .err(status):{return failed(m,status);}};
    if(vec::len<Instance>(v)>=m.limits.instances || m.next==0){return failed(m,8);}
    let ref Program program=vec::at<Program>(p,pi);
    if(vec::len<host_program::Program>(ref program.host)!=1){return failed(m,1);}
    let ref host_program::Program verified=vec::at<host_program::Program>(ref program.host,0);
    let ref policy::Policy ceiling=vec::at<policy::Policy>(policies,0);
    let policy_limits::RunLimits limits=run_config::run_limits(run);
    if(!host_program::allows(verified,ceiling,run) || limits.fuel>m.limits.fuel){return failed(m,5);}
    let usize exchange_bytes=host::scalar_storage_bound(verified,limits);
    let usize slots=control_layout::capacity(1);
    if(stride==0 || exchange_bytes>limits.memory_bytes || stride>(limits.memory_bytes-exchange_bytes)/slots){return failed(m,8);}
    // Policy bounds deadline_ms to 1..60000. Windows interrupt time uses 100 ns ticks.
    let usize duration=limits.deadline_ms*10000;
    let usize start=unsafe{monotonic_ticks_raw()};
    if(start>18446744073709551615-duration){return failed(m,8);}
    let usize charge=slots*stride+exchange_bytes;
    let live::Plan reservation=switch(prepare_payload(m,0,charge,0)){
        case .ok(plan):{plan}case .err(status):{return failed(m,status);}
    };
    let usize id=m.next;
    let host::Exchange exchange=switch(host::create_scalar(verified,ceiling,run,id,start+duration)){
        case .ok(value):{value}case .err(reason):{return failed(m,switch(reason){
            case .Authority:{5}case .Allocation:{6}case .Binding:{7}case .State:{7}case .Rejected:{7}
        });}
    };
    var vec::Vec<host::Exchange> saved=vec::empty<host::Exchange>();
    if(!vec::push<host::Exchange>(ref mut saved,exchange).is_ok){return failed(m,6);}
    assert(vec::push<Output>(outputs,Output{.instance=id,.run=output_programs::vacant(limits.fuel),
        .pending=vec::empty<machines::Machine>(),.host=saved}).is_ok);
    assert(vec::push<Instance>(v,Instance{.id=id,.program=code,.fuel=limits.fuel,.phase=4,.event=ready(limits.fuel),
        .output_limit=0,.output_allowed=false,.input_bytes=0,.output_bytes=charge,.host_terminal=host::empty_scalar_event()}).is_ok);
    commit_payload(m,ref reservation);
    let ref mut Program target=vec::at_mut<Program>(p,pi);target.pins+=1;
    advance(m);return success(m,id);
}

fn u32 drive_host_owner(ref mut vec::Vec<host::Exchange> owners,u32 mode,usize quantum,usize run,usize request,
    u8 kind,ref u8[] payload,ref mut HostTransition transition,usize offset){
    if(vec::len<host::Exchange>(owners)!=1){return 7;}
    let ref mut host::Exchange exchange=vec::at_mut<host::Exchange>(owners,0);
    var usize remaining=quantum;
    while(remaining>0 || mode==2){
        let usize now=unsafe{monotonic_ticks_raw()};
        let Result<host::ScalarEvent,host::ScalarError> action=if(mode==2){
            host::receive_scalar_reply(exchange,run,request,kind,quantum,offset,payload,now)
        }else{host::step_scalar_budget(exchange,now,mode==1,ref mut remaining)};
        let host::ScalarEvent observed=switch(action){
            case .ok(value):{value}case .err(reason):{return switch(reason){
                case .Rejected:{1}case .Allocation:{6}case .Authority:{5}case .State:{7}case .Binding:{7}
            };}
        };
        let bool done=observed.phase==3;
        let bool failed=observed.phase==4;
        let bool cancel=failed && observed.host.cause==1;
        let u8 event_kind=if(done){1}else if(cancel){3}else if(failed){2}else if(observed.phase==1){4}else{0};
        let u8 diagnostic=if(observed.failure==2){6}else if(observed.failure==4){12}else if(observed.host.cause==5){8}else if(observed.host.cause==4){15}else if(observed.host.cause==2){errors::deadline_kind()}else{0};
        *transition=HostTransition{.scalar=observed,.event=Event{.kind=event_kind,.value=observed.value,
            .diagnostic=diagnostics::absent(errors::make(diagnostic,0)),.remaining=observed.host.fuel,.fuel_known=true}};
        if(observed.phase!=0 || mode!=0){return 0;}
    }
    return 0;
}
fn u32 drive_host(ref mut Meta m,ref mut vec::Vec<Instance> v,ref mut vec::Vec<Output> outputs,
    ref mut vec::Vec<Output> scratch,usize ii,u32 mode,usize quantum,usize run,usize request,u8 kind,ref u8[] payload,usize offset){
    let usize id=vec::at<Instance>(v,ii).id;
    let usize oi=switch(output_index(outputs,id)){case .ok(i):{i}case .err(_):{return failed(m,7);}};
    var HostTransition next=HostTransition{.scalar=host::empty_scalar_event(),.event=pending()};
    var u32 status=0;
    {let ref mut Output saved=vec::at_mut<Output>(outputs,oi);
     status=unsafe{drive_host_raw(saved as ptr mut void,mode,quantum,run,request,kind,
        payload as ptr u8,payload.len,ref mut next as ptr mut void,offset)};}
    if(status!=0){return failed(m,status);}
    let ref mut Instance target=vec::at_mut<Instance>(v,ii);
    target.event=next.event;
    if(next.scalar.phase==3 || next.scalar.phase==4){
        remove_output(outputs,scratch,id);
        release_payload(m,target.output_bytes);
        target.output_bytes=0;
        target.host_terminal=next.scalar;
        target.phase=2;
    }
    m.event=next.event;return success(m,id);
}
fn u32 reply_host_inner(ref mut Meta m,ref mut vec::Vec<Instance> v,ref mut vec::Vec<Output> outputs,
    ref mut vec::Vec<Output> scratch,usize instance,usize run,usize request,u8 kind,ref u8[] payload,usize total,usize offset){
    let usize ii=switch(instance_index(v,instance)){case .ok(i):{i}case .err(status):{return failed(m,status);}};
    if(vec::at<Instance>(v,ii).phase!=4){return failed(m,11);}
    return drive_host(m,v,outputs,scratch,ii,2,total,run,request,kind,payload,offset);
}

fn u32 output_instance_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref mut vec::Vec<BoundInput> inputs,ref mut vec::Vec<input_bytes::Snapshot> incoming,usize code,usize budget,usize limit,u32 allowed){
    if(limit>1048576 || allowed>3){return failed(m,1);}
    if(m.configured!=(allowed>=2) || budget>m.limits.fuel){return failed(m,5);}
    let usize pi=switch(program_index(p,code,true)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let ref Program program=vec::at<Program>(p,pi);
    if(vec::len<output_programs::Program>(ref program.output)!=1){return failed(m,1);}
    let bool input=output_programs::accepts_input(vec::at<output_programs::Program>(ref program.output,0));
    if(vec::len<Instance>(v)>=m.limits.instances || m.next==0){return failed(m,8);}
    if(vec::len<input_bytes::Snapshot>(incoming)!=if(input){1}else{0}){return failed(m,1);}
    let usize capacity=if(input){input_bytes::capacity(vec::at<input_bytes::Snapshot>(incoming,0))}else{0};
    let usize transport=unsafe{input_fact_raw(incoming as ptr void,1)};
    let live::Plan storage=switch(prepare_payload(m,0,capacity,transport)){
        case .ok(v):{v}case .err(status):{return failed(m,status);}
    };
    let usize id=m.next;
    if(input){let input_bytes::Snapshot snapshot=pop_snapshot(incoming);
        if(!vec::push<BoundInput>(inputs,BoundInput{.instance=id,.input=snapshot}).is_ok){return failed(m,6);}}
    if(!vec::push<Instance>(v,Instance{.id=id,.program=code,.fuel=budget,.phase=0,.event=ready(budget),.output_limit=limit,.output_allowed=allowed==1 || allowed==3,.input_bytes=capacity,.output_bytes=0,.host_terminal=host::empty_scalar_event()}).is_ok){
        if(input){let Option<BoundInput> disposed=vec::pop<BoundInput>(inputs);}return failed(m,6);
    }
    commit_payload(m,ref storage);
    let ref mut Program target=vec::at_mut<Program>(p,pi);target.pins+=1;advance(m);return success(m,id);
}
fn Result<usize,u32> output_index(ref vec::Vec<Output> v,usize id){
    var usize i=0;while(i<vec::len<Output>(v)){if(vec::at<Output>(v,i).instance==id){return .ok(i);}i+=1;}return .err(2);
}
fn Output pop_output(ref mut vec::Vec<Output> v){return switch(vec::pop<Output>(v)){
    case .some(o):{o}case .none:{assert(false);pop_output(v)}
};}
fn void output_to_scratch(ref mut vec::Vec<Output> v,ref mut vec::Vec<Output> scratch,usize i){
    assert(vec::len<Output>(scratch)==0);
    while(vec::len<Output>(v)>i+1){let Output run=pop_output(v);assert(vec::push<Output>(scratch,run).is_ok);}
}
fn void restore_output(ref mut vec::Vec<Output> v,ref mut vec::Vec<Output> scratch){
    while(vec::len<Output>(scratch)>0){let Output run=pop_output(scratch);assert(vec::push<Output>(v,run).is_ok);}
}
fn void remove_output(ref mut vec::Vec<Output> v,ref mut vec::Vec<Output> scratch,usize id){
    let usize i=switch(output_index(v,id)){case .ok(value):{value}case .err(_):{return;}};
    output_to_scratch(v,scratch,i);{let Output disposed=pop_output(v);}restore_output(v,scratch);
}
fn u32 output_preflight_width(ref mut Meta m,ref vec::Vec<Instance> instances,ref vec::Vec<Output> outputs,usize id,usize width){
    if(width==0 || width>18446744073709551615/8){return 7;}
    return output_preflight_inner(m,instances,outputs,id,8*width);
}
fn u32 output_preflight_inner(ref mut Meta m,ref vec::Vec<Instance> instances,ref vec::Vec<Output> outputs,usize id,usize transport){
    if(m.closed){return 2;}
    let usize ii=switch(instance_index(instances,id)){case .ok(v):{v}case .err(status):{return status;}};
    let ref Instance instance=vec::at<Instance>(instances,ii);
    if(instance.phase!=2){return 11;}
    let usize output_at=switch(output_index(outputs,id)){case .ok(v):{v}case .err(_):{return 2;}};
    let ref Output owner=vec::at<Output>(outputs,output_at);
    if(vec::len<host::Exchange>(ref owner.host)!=0 || output_programs::observe(ref owner.run).cancelled){return 2;}
    let usize retained=instance.input_bytes+instance.output_bytes;
    return switch(prepare_payload(m,retained,retained,transport)){
        case .ok(_):{0}case .err(status):{status}
    };
}
fn u32 take_output_inner(ref mut Meta m,ref mut vec::Vec<Instance> instances,ref mut vec::Vec<Output> v,
    ref mut vec::Vec<Output> scratch,usize id,ref mut vec::Vec<Output> outgoing){
    if(vec::len<Output>(outgoing)!=0){return failed(m,1);}
    let u32 admitted=output_preflight_inner(m,instances,v,id,unsafe{output_fact_raw(outgoing as ptr void,1)});
    if(admitted!=0){return failed(m,admitted);}
    let usize ii=switch(instance_index(instances,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let usize i=switch(output_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let usize bytes=vec::at<Instance>(instances,ii).output_bytes;
    // The pre-reserved result slot receives the whole owner. No fallible work
    // follows detachment; outside bytes are no longer owned by this Engine.
    output_to_scratch(v,scratch,i);let Output run=pop_output(v);
    assert(vec::push<Output>(outgoing,run).is_ok);restore_output(v,scratch);
    assert(live::release(ref mut m.heap,bytes).is_ok);
    let usize current=live::observe(ref m.heap).current;
    assert(memory::commit_external(ref mut m.programs,current).is_ok);
    {let ref mut Instance target=vec::at_mut<Instance>(instances,ii);target.output_bytes=0;}
    return success(m,id);
}
fn u32 instance_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Instance> v,usize code,usize budget){
    if(m.configured || budget>m.limits.fuel){return failed(m,5);}
    let usize pi=switch(program_index(p,code,true)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    if(vec::len<Instance>(v)>=m.limits.instances || m.next==0){return failed(m,8);}
    let usize id=m.next;
    if(!vec::push<Instance>(v,Instance{.id=id,.program=code,.fuel=budget,.phase=0,.event=ready(budget),.output_limit=0,.output_allowed=false,.input_bytes=0,.output_bytes=0,.host_terminal=host::empty_scalar_event()}).is_ok){return failed(m,6);}
    let ref mut Program target=vec::at_mut<Program>(p,pi);target.pins+=1;advance(m);return success(m,id);
}
fn Result<usize,u32> input_index(ref vec::Vec<BoundInput> v,usize id){
    var usize i=0;while(i<vec::len<BoundInput>(v)){if(vec::at<BoundInput>(v,i).instance==id){return .ok(i);}i+=1;}return .err(2);
}
fn input_bytes::Snapshot pop_snapshot(ref mut vec::Vec<input_bytes::Snapshot> v){return switch(vec::pop<input_bytes::Snapshot>(v)){
    case .some(value):{value}case .none:{assert(false);pop_snapshot(v)}
};}
fn u32 input_instance_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref mut vec::Vec<BoundInput> inputs,ref mut vec::Vec<input_bytes::Snapshot> incoming,usize code,usize budget){
    if(m.configured || budget>m.limits.fuel){return failed(m,5);}
    let usize pi=switch(program_index(p,code,true)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    if(vec::len<input_programs::Program>(ref vec::at<Program>(p,pi).input)!=1){return failed(m,1);}
    if(vec::len<Instance>(v)>=m.limits.instances || m.next==0){return failed(m,8);}
    if(vec::len<input_bytes::Snapshot>(incoming)!=1){return failed(m,1);}
    let usize capacity=input_bytes::capacity(vec::at<input_bytes::Snapshot>(incoming,0));
    let live::Plan storage=switch(prepare_payload(m,0,capacity,unsafe{input_fact_raw(incoming as ptr void,1)})){
        case .ok(v):{v}case .err(status):{return failed(m,status);}
    };
    let usize id=m.next;let input_bytes::Snapshot snapshot=pop_snapshot(incoming);
    if(!vec::push<BoundInput>(inputs,BoundInput{.instance=id,.input=snapshot}).is_ok){return failed(m,6);}
    if(!vec::push<Instance>(v,Instance{.id=id,.program=code,.fuel=budget,.phase=0,.event=ready(budget),.output_limit=0,.output_allowed=false,.input_bytes=capacity,.output_bytes=0,.host_terminal=host::empty_scalar_event()}).is_ok){
        let Option<BoundInput> disposed=vec::pop<BoundInput>(inputs);return failed(m,6);
    }
    commit_payload(m,ref storage);
    let ref mut Program target=vec::at_mut<Program>(p,pi);target.pins+=1;advance(m);return success(m,id);
}
fn BoundInput pop_bound(ref mut vec::Vec<BoundInput> v){return switch(vec::pop<BoundInput>(v)){
    case .some(value):{value}case .none:{assert(false);pop_bound(v)}
};}
fn void remove_input(ref mut vec::Vec<BoundInput> v,ref mut vec::Vec<BoundInput> scratch,usize id){
    let usize i=switch(input_index(v,id)){case .ok(value):{value}case .err(_):{return;}};
    assert(vec::len<BoundInput>(scratch)==0);
    while(vec::len<BoundInput>(v)>i+1){let BoundInput input=pop_bound(v);assert(vec::push<BoundInput>(scratch,input).is_ok);}
    {let BoundInput disposed=pop_bound(v);}
    while(vec::len<BoundInput>(scratch)>0){let BoundInput input=pop_bound(scratch);assert(vec::push<BoundInput>(v,input).is_ok);}
}
fn Program pop(ref mut vec::Vec<Program> v){return switch(vec::pop<Program>(v)){case .some(p):{p}case .none:{assert(false);pop(v)}};}
fn void push(ref mut vec::Vec<Program> v,Program p){assert(vec::push<Program>(v,p).is_ok);}
fn void remove(ref mut Meta m,ref mut vec::Vec<Program> v,ref mut vec::Vec<Program> scratch,usize index){
    assert(vec::len<Program>(scratch)==0);
    while(vec::len<Program>(v)>index+1){let Program p=pop(v);push(scratch,p);}
    {let Program disposed=pop(v);assert(memory::release(ref mut m.programs,disposed.bytes).is_ok);}
    while(vec::len<Program>(scratch)>0){let Program p=pop(scratch);push(v,p);}
}
fn u32 release_inner(ref mut Meta m,ref mut vec::Vec<Program> v,ref mut vec::Vec<Program> scratch,usize id){
    let usize i=switch(program_index(v,id,true)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    if(vec::at<Program>(v,i).pins==0){remove(m,v,scratch,i);}else{let ref mut Program p=vec::at_mut<Program>(v,i);p.released=true;}
    return success(m,id);
}
fn u32 destroy_instance_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Program> scratch,ref mut vec::Vec<Instance> v,
    ref mut vec::Vec<BoundInput> inputs,ref mut vec::Vec<BoundInput> input_scratch,
    ref mut vec::Vec<Output> outputs,ref mut vec::Vec<Output> output_scratch,usize id){
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let Instance current=*vec::at<Instance>(v,ii);if(current.phase==1){return failed(m,3);}
    let usize pi=switch(program_index(p,current.program,false)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let usize pins=vec::at<Program>(p,pi).pins;if(pins==0){return failed(m,7);}
    let bool reclaim=pins==1 && vec::at<Program>(p,pi).released;
    // Dropping destroys the sole unpublished owner directly. No live guest
    // metadata or external handles survive it, so semantic unwinding is unused.
    {let ref mut Program code=vec::at_mut<Program>(p,pi);code.pins=pins-1;}
    let Instance last=switch(vec::pop<Instance>(v)){case .some(x):{x}case .none:{assert(false);current}};
    if(ii<vec::len<Instance>(v)){let ref mut Instance target=vec::at_mut<Instance>(v,ii);*target=last;}
    remove_output(outputs,output_scratch,id);remove_input(inputs,input_scratch,id);
    release_payload(m,current.input_bytes+current.output_bytes);
    if(reclaim){remove(m,p,scratch,pi);}return success(m,id);
}
fn u32 execute_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,ref vec::Vec<BoundInput> inputs,ref mut vec::Vec<Output> outputs,usize id){
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let Instance current=*vec::at<Instance>(v,ii);
    if(current.phase==1 || current.phase==3 || current.phase==4){return failed(m,3);}if(current.phase==2){return failed(m,11);}
    let usize pi=switch(program_index(p,current.program,false)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let ref Program code=vec::at<Program>(p,pi);if(code.pins==0){return failed(m,7);}
    if(vec::len<output_programs::Program>(ref code.output)!=0){return execute_output_inner(m,p,v,inputs,outputs,id);}
    if(vec::len<input_programs::Program>(ref code.input)!=0){
        let usize bi=switch(input_index(inputs,id)){case .ok(x):{x}case .err(_):{return failed(m,1);}};
        return execute_input_inner(m,p,v,id,ref vec::at<BoundInput>(inputs,bi).input);
    }
    if(vec::len<programs::Program>(ref code.code)!=1){return failed(m,7);}
    let u32 memory_status=reserve_execution(m,code,ref current);if(memory_status!=0){return memory_status;}
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.phase=1;}
    let Event event=switch(programs::run(vec::at<programs::Program>(ref code.code,0),current.fuel)){
        case .ok(value):{Event{.kind=1,.value=value,.diagnostic=absent(),.remaining=0,.fuel_known=false}}
        case .err(e):{Event{.kind=2,.value=0,.diagnostic=e,.remaining=0,.fuel_known=false}}
    };
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.event=event;target.phase=2;}
    m.event=event;return success(m,id);
}
fn u32 execute_output_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref vec::Vec<BoundInput> inputs,ref mut vec::Vec<Output> outputs,usize id){
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let Instance current=*vec::at<Instance>(v,ii);
    if(current.phase==1 || current.phase==3 || current.phase==4){return failed(m,3);}if(current.phase==2){return failed(m,11);}
    let usize pi=switch(program_index(p,current.program,false)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let ref Program code=vec::at<Program>(p,pi);
    if(code.pins==0 || vec::len<output_programs::Program>(ref code.output)!=1 || output_index(outputs,id).is_ok){return failed(m,7);}
    let ref output_programs::Program retained=vec::at<output_programs::Program>(ref code.output,0);
    if(output_programs::accepts_input(retained) && !input_index(inputs,id).is_ok){return failed(m,1);}
    let u32 memory_status=reserve_execution(m,code,ref current);if(memory_status!=0){return memory_status;}
    if(output_programs::accepts_input(retained)){
        let usize bi=switch(input_index(inputs,id)){case .ok(x):{x}case .err(_):{return failed(m,1);}};
        {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.phase=1;}
        return publish_output_run(m,v,outputs,ii,id,output_programs::complete(retained,
            ref vec::at<BoundInput>(inputs,bi).input,current.fuel,current.output_limit,current.output_allowed));
    }
    var usize budget=0;let input_bytes::Snapshot empty=switch(input_bytes::snapshot(b"",0,0,ref mut budget)){
        case .ok(value):{value}case .err(_):{return failed(m,7);}
    };
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.phase=1;}
    return publish_output_run(m,v,outputs,ii,id,output_programs::complete(retained,
        ref empty,current.fuel,current.output_limit,current.output_allowed));
}
fn Result<machines::Machine,diagnostics::Error> open_instance_machine(ref output_programs::Program code,
    ref vec::Vec<BoundInput> inputs,usize id,usize budget,usize limit,bool allowed){
    if(output_programs::accepts_input(code)){
        let usize bi=switch(input_index(inputs,id)){
            case .ok(x):{x}case .err(_):{return .err(diagnostics::absent(errors::make(5,0)));}
        };
        return pending_vm::prepare_pending_output(code,ref vec::at<BoundInput>(inputs,bi).input,budget,limit,allowed);
    }
    var usize unused=0;let input_bytes::Snapshot empty=switch(input_bytes::snapshot(b"",0,0,ref mut unused)){
        case .ok(v):{v}case .err(_):{return .err(diagnostics::absent(errors::make(15,0)));}
    };
    return pending_vm::prepare_pending_output(code,ref empty,budget,limit,allowed);
}
fn u32 prepare_instance_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref vec::Vec<BoundInput> inputs,ref mut vec::Vec<Output> outputs,usize id){
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let Instance before=*vec::at<Instance>(v,ii);
    if(before.phase!=0){return failed(m,3);}
    let usize pi=switch(program_index(p,before.program,false)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let ref Program code=vec::at<Program>(p,pi);
    if(code.pins==0 || output_index(outputs,id).is_ok){return failed(m,7);}
    let usize charge=switch(pending_bytes(code,before.output_limit)){case .ok(v):{v}case .err(e):{return failed(m,e.status);}};
    if(charge>18446744073709551615-before.input_bytes){return failed(m,8);}
    let live::Plan ownership=switch(prepare_payload(m,before.input_bytes,before.input_bytes+charge,0)){
        case .ok(v):{v}case .err(s):{return failed(m,s);}
    };
    // Everything remains local until all allocations and entry preparation
    // succeed. Failed attempts leave the Ready Instance and its input untouched.
    var vec::Vec<machines::Machine> saved=vec::empty<machines::Machine>();
    if(!vec::reserve<machines::Machine>(ref mut saved,1).is_ok){return failed(m,6);}
    let output_programs::Execution slot=switch(output_programs::pending_slot(before.fuel)){
        case .ok(v):{v}case .err(_):{return failed(m,6);}
    };
    let machines::Machine machine=switch(open_instance_machine(vec::at<output_programs::Program>(ref code.output,0),
        inputs,id,before.fuel,before.output_limit,before.output_allowed)){
        case .ok(v):{v}case .err(e):{
            if(e.code.kind==15){return failed(m,6);}
            m.error=Error{.status=4,.diagnostic=e};return 4;
        }
    };
    let machines::Meta state=machines::observe(ref machine);
    assert(state.phase==1 && state.stats.dispatched==0);
    assert(vec::push<machines::Machine>(ref mut saved,machine).is_ok);
    let Event event=Event{.kind=4,.value=0,.diagnostic=absent(),.remaining=state.remaining,.fuel_known=true};
    assert(vec::push<Output>(outputs,Output{.instance=id,.run=slot,.pending=saved,.host=vec::empty<host::Exchange>()}).is_ok);
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.phase=3;target.event=event;target.output_bytes=charge;}
    commit_payload(m,ref ownership);m.event=event;return success(m,id);
}
fn u32 publish_output_run(ref mut Meta m,ref mut vec::Vec<Instance> v,ref mut vec::Vec<Output> outputs,
    usize ii,usize id,output_programs::Execution run){
    let output_programs::Completion completed=output_programs::observe(ref run);
    let usize bytes=output_programs::heap_bytes(ref run);
    let Instance before=*vec::at<Instance>(v,ii);
    let live::Plan ownership=switch(live::prepare(ref m.heap,before.input_bytes,before.input_bytes+bytes,0)){
        case .ok(v):{v}case .err(_):{assert(false);return failed(m,7);}
    };
    let Event event=Event{.kind=if(completed.success){1}else{2},.value=completed.value,
        .diagnostic=completed.diagnostic,.remaining=completed.remaining,.fuel_known=true};
    assert(vec::push<Output>(outputs,Output{.instance=id,.run=run,.pending=vec::empty<machines::Machine>(),.host=vec::empty<host::Exchange>()}).is_ok);
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.event=event;target.phase=2;target.output_bytes=bytes;}
    commit_payload(m,ref ownership);
    m.event=event;return success(m,id);
}
// Typed projection enters this helper with disjoint owning fields, never a
// reconstructed VM. The preallocated publication slot receives a successful
// seal directly; popping terminal Machine state releases its private backing.
fn u32 step_output_owner(ref mut vec::Vec<machines::Machine> saved,ref mut output_programs::Completion completed,
    ref mut vec::Vec<pending_output::Published> published,ref output_programs::Program code,ref input_bytes::Snapshot input,usize quantum){
    if(quantum==0 || quantum>4096 || vec::len<machines::Machine>(saved)!=1 ||
        vec::len<pending_output::Published>(published)!=0 || vec::capacity<pending_output::Published>(published)<1){return 7;}
    {
        let ref mut machines::Machine machine=vec::at_mut<machines::Machine>(saved,0);
        let machines::Meta initial=machines::observe(machine);
        let machines::Meta progressed=if(initial.phase>=2){initial}else{switch(pending_vm::advance_pending_output(machine,code,input,quantum)){
            case .ok(v):{v}case .err(_):{return 7;}
        }};
        if(progressed.phase==1){
            *completed=output_programs::pending_completion(progressed.remaining);return 0;
        }
        if(progressed.phase==2){discard pending_vm::seal_pending_output_into(machine,published);}
        let machines::Meta finished=machines::observe(machine);
        if(finished.phase==1){*completed=output_programs::pending_completion(finished.remaining);return 0;}
        if(finished.phase==4){*completed=output_programs::cancelled_completion(finished.remaining);}
        else{if(finished.phase!=2 && finished.phase!=3){return 7;};
        *completed=output_programs::resumed_completion(code,published,finished.phase==2,finished.value,
            finished.remaining,finished.failure,pending_vm::pending_staged_emits(machine));}
    }
    {let Option<machines::Machine> disposed=vec::pop<machines::Machine>(saved);}return 0;
}
fn vec::Vec<machines::Machine> compact_pending_storage(vec::Vec<machines::Machine> saved){
    if(vec::len<machines::Machine>(ref saved)!=0){return saved;}return vec::empty<machines::Machine>();
}
fn vec::Vec<pending_output::Published> compact_cancelled_storage(vec::Vec<pending_output::Published> saved,bool cancelled){
    if(cancelled){return vec::empty<pending_output::Published>();}return saved;
}
fn u32 cancel_output_owner(ref mut vec::Vec<machines::Machine> saved){
    if(vec::len<machines::Machine>(saved)!=1){return 7;}
    return switch(pending_vm::cancel_pending_output(vec::at_mut<machines::Machine>(saved,0))){
        case .ok(v):{if(v.phase==1){12}else if(v.phase==3){13}else{0}}case .err(_):{7}
    };
}
fn u32 step_instance_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref vec::Vec<BoundInput> inputs,ref mut vec::Vec<Output> outputs,ref mut vec::Vec<Output> scratch,usize id,usize quantum){
    if(quantum==0 || quantum>4096){return failed(m,1);}
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let Instance before=*vec::at<Instance>(v,ii);
    if(before.phase==2){return failed(m,11);}
    if(before.phase==4){return drive_host(m,v,outputs,scratch,ii,0,quantum,0,0,0,b"",0);}
    if(before.phase!=3){return failed(m,3);}
    let usize pi=switch(program_index(p,before.program,false)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let ref Program code=vec::at<Program>(p,pi);
    if(code.pins==0 || vec::len<output_programs::Program>(ref code.output)!=1){return failed(m,7);}
    let ref output_programs::Program retained=vec::at<output_programs::Program>(ref code.output,0);
    let usize oi=switch(output_index(outputs,id)){case .ok(x):{x}case .err(_):{return failed(m,7);}};
    if(output_programs::accepts_input(retained)){
        let usize bi=switch(input_index(inputs,id)){case .ok(x):{x}case .err(_):{return failed(m,7);}};
        let ref input_bytes::Snapshot input=ref vec::at<BoundInput>(inputs,bi).input;
        let ref mut Output saved=vec::at_mut<Output>(outputs,oi);
        let u32 status=unsafe{step_output_raw(saved as ptr mut void,retained as ptr void,input as ptr void,quantum)};
        if(status!=0){return failed(m,status);}
    }else{
        var usize unused=0;let input_bytes::Snapshot empty=switch(input_bytes::snapshot(b"",0,0,ref mut unused)){
            case .ok(v):{v}case .err(_):{return failed(m,7);}
        };
        let ref mut Output saved=vec::at_mut<Output>(outputs,oi);
        let u32 status=unsafe{step_output_raw(saved as ptr mut void,retained as ptr void,ref empty as ptr void,quantum)};
        if(status!=0){return failed(m,status);}
    }
    let ref Output saved=vec::at<Output>(outputs,oi);
    let bool pending=vec::len<machines::Machine>(ref saved.pending)==1;
    let output_programs::Completion completed=output_programs::observe(ref saved.run);
    let usize bytes=if(pending){before.output_bytes}else{output_programs::heap_bytes(ref saved.run)};
    if(bytes>before.output_bytes){return failed(m,7);}
    let live::Plan ownership=switch(live::prepare(ref m.heap,before.input_bytes+before.output_bytes,before.input_bytes+bytes,0)){
        case .ok(v):{v}case .err(_):{return failed(m,7);}
    };
    let Event event=Event{.kind=if(pending){4}else if(completed.cancelled){3}else{if(completed.success){1}else{2}},.value=completed.value,
        .diagnostic=completed.diagnostic,.remaining=completed.remaining,.fuel_known=true};
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.phase=if(pending){3}else{2};target.event=event;target.output_bytes=bytes;}
    commit_payload(m,ref ownership);m.event=event;return success(m,id);
}
fn u32 execute_input_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,usize id,ref input_bytes::Snapshot input){
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let Instance current=*vec::at<Instance>(v,ii);
    if(current.phase==1){return failed(m,3);}if(current.phase==2){return failed(m,11);}
    let usize pi=switch(program_index(p,current.program,false)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let ref Program code=vec::at<Program>(p,pi);if(code.pins==0){return failed(m,7);}
    if(vec::len<output_programs::Program>(ref code.output)!=0){return failed(m,1);}
    if(vec::len<programs::Program>(ref code.code)!=0){return failed(m,1);}
    if(vec::len<input_programs::Program>(ref code.input)!=1){return failed(m,7);}
    let u32 memory_status=reserve_execution(m,code,ref current);if(memory_status!=0){return memory_status;}
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.phase=1;}
    let input_programs::Completion completion=input_programs::complete(vec::at<input_programs::Program>(ref code.input,0),input,current.fuel);
    let Event event=Event{.kind=if(completion.success){1}else{2},.value=completion.value,
        .diagnostic=completion.diagnostic,.remaining=completion.remaining,.fuel_known=true};
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.event=event;target.phase=2;}
    m.event=event;return success(m,id);
}
fn u32 execute_borrowed_input_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref vec::Vec<BoundInput> inputs,usize id,ref input_bytes::Snapshot input){
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let u8 phase=vec::at<Instance>(v,ii).phase;
    if(phase==1){return failed(m,3);}if(phase==2){return failed(m,11);}
    if(input_index(inputs,id).is_ok){return failed(m,1);}
    return execute_input_inner(m,p,v,id,input);
}
fn u32 observe_inner(ref mut Meta m,ref vec::Vec<Instance> v,usize id){
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    m.event=vec::at<Instance>(v,ii).event;return success(m,id);
}
fn u32 cancel_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,ref vec::Vec<BoundInput> inputs,ref mut vec::Vec<Output> outputs,ref mut vec::Vec<Output> scratch,usize id){
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let Instance before=*vec::at<Instance>(v,ii);
    if(before.phase==4){return drive_host(m,v,outputs,scratch,ii,1,1,0,0,0,b"",0);}
    if(before.phase==3){
        let usize oi=switch(output_index(outputs,id)){case .ok(x):{x}case .err(_):{return failed(m,7);}};
        // Drain canonical private metadata and discard any staged prefix before
        // releasing its sole owner; no guest effects are replayed or rolled back.
        var u32 status=0;
        {let ref mut Output saved=vec::at_mut<Output>(outputs,oi);status=unsafe{cancel_output_raw(saved as ptr mut void)};}
        if(status==12){m.event=before.event;return success(m,id);}
        // A prior failure wins. Finalize it through the same Program diagnostic
        // and retained-output path as step, even if the caller repeats cancel.
        if(status==13){return step_instance_inner(m,p,v,inputs,outputs,scratch,id,1);}
        if(status!=0){return failed(m,7);}
        remove_output(outputs,scratch,id);
        release_payload(m,before.output_bytes);
        let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.output_bytes=0;
        target.event=Event{.kind=3,.value=0,.diagnostic=absent(),.remaining=before.event.remaining,.fuel_known=true};target.phase=2;
    }
    let ref mut Instance target=vec::at_mut<Instance>(v,ii);
    if(target.phase==1){return failed(m,3);}if(target.phase==0){target.event=Event{.kind=3,.value=0,.diagnostic=absent(),.remaining=target.fuel,.fuel_known=true};target.phase=2;}
    m.event=target.event;return success(m,id);
}
fn u32 inspect_inner(ref mut Meta m,ref vec::Vec<Program> p,ref vec::Vec<Instance> v){
    var usize pins=0;var usize i=0;while(i<vec::len<Program>(p)){pins+=vec::at<Program>(p,i).pins;i+=1;}
    m.snapshot=Snapshot{.programs=vec::len<Program>(p),.instances=vec::len<Instance>(v),.pins=pins,.closed=m.closed};return success(m,0);
}
fn u32 close_inner(ref mut Meta m,ref vec::Vec<Program> p,ref vec::Vec<Instance> v,ref vec::Vec<BoundInput> inputs,ref vec::Vec<Output> outputs){
    if(vec::len<Program>(p)!=0 || vec::len<Instance>(v)!=0 || vec::len<BoundInput>(inputs)!=0 || vec::len<Output>(outputs)!=0){return failed(m,3);}
    let usize bytes=control::observe(ref m.control).reserved;
    assert(control::release(ref mut m.control,bytes).is_ok);assert(control::close(ref mut m.control).is_ok);
    assert(live::close(ref mut m.heap).is_ok);assert(memory::close(ref mut m.programs).is_ok);m.closed=true;return success(m,0);
}
fn u32 dispatch_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Program> scratch,
    ref mut vec::Vec<Instance> v,ref mut vec::Vec<BoundInput> inputs,ref mut vec::Vec<BoundInput> input_scratch,
    ref mut vec::Vec<Output> outputs,ref mut vec::Vec<Output> output_scratch,u32 operation,usize id,usize argument){
    if(operation==1){return instance_inner(m,p,v,id,argument);}
    if(operation==2){return release_inner(m,p,scratch,id);}
    if(operation==3){return destroy_instance_inner(m,p,scratch,v,inputs,input_scratch,outputs,output_scratch,id);}
    if(operation==4){return close_inner(m,p,v,inputs,outputs);}
    if(operation==5){return execute_inner(m,p,v,inputs,outputs,id);}
    if(operation==6){return observe_inner(m,v,id);}
    if(operation==7){return cancel_inner(m,p,v,inputs,outputs,output_scratch,id);}
    if(operation==8){return inspect_inner(m,p,v);}
    if(operation==9){return prepare_instance_inner(m,p,v,inputs,outputs,id);}
    if(operation==10){return step_instance_inner(m,p,v,inputs,outputs,output_scratch,id,argument);}
    return failed(m,1);
}
// After the last epoch, only bounded owner maintenance may run, under the
// native guard for its entire duration. It never issues/reuses an epoch or runs
// compilation/guest code; existing results and owning teardown remain available.
fn u32 maintenance_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Program> scratch,
    ref mut vec::Vec<Instance> v,ref mut vec::Vec<BoundInput> inputs,ref mut vec::Vec<BoundInput> input_scratch,
    ref mut vec::Vec<Output> outputs,ref mut vec::Vec<Output> output_scratch,usize thread,usize lifetime,u32 operation,usize id,usize argument){
    if(m.thread!=thread || m.lifetime!=lifetime || thread==0 || lifetime==0){return 10;}
    if(m.active!=0){return 3;}if(m.closed){return failed(m,2);}
    if(m.admission!=0){return failed(m,7);}
    if(operation!=2 && operation!=3 && operation!=4 && operation!=6 && operation!=7 && operation!=8){return failed(m,8);}
    return dispatch_inner(m,p,scratch,v,inputs,input_scratch,outputs,output_scratch,operation,id,argument);
}
fn vec::Vec<Program> reset_program_storage(vec::Vec<Program> v){assert(vec::len<Program>(ref v)==0);return vec::empty<Program>();}
fn vec::Vec<Instance> reset_instance_storage(vec::Vec<Instance> v){assert(vec::len<Instance>(ref v)==0);return vec::empty<Instance>();}
fn vec::Vec<BoundInput> reset_input_storage(vec::Vec<BoundInput> v){assert(vec::len<BoundInput>(ref v)==0);return vec::empty<BoundInput>();}
fn vec::Vec<Output> reset_output_storage(vec::Vec<Output> v){assert(vec::len<Output>(ref v)==0);return vec::empty<Output>();}
fn vec::Vec<policy::Policy> reset_policy_storage(vec::Vec<policy::Policy> owned){return vec::empty<policy::Policy>();}
// Only the dedicated transport fixture calls this helper-retention root. The
// marker calls identify typed definitions; they publish nothing or run guests.
fn u32 control_access_inner(ref Meta m,usize thread,usize lifetime){
    if(m.thread!=thread || m.lifetime!=lifetime || thread==0 || lifetime==0){return 10;}
    if(m.active!=0){return 3;}return 0;
}
fn usize output_identity(ref Output o){return o.instance;}
fn Result<modules::Index,u8> layout_index(ref u8[] source){
    var sources::Builder b=switch(sources::builder(4096,4096)){case .ok(v):{v}case .err(_):{return .err(1);}};
    if(!sources::add(ref mut b,b"layout",source).is_ok){return .err(2);}
    let sources::Snapshot snapshot=switch(sources::freeze(ref b)){case .ok(v):{v}case .err(_):{return .err(3);}};
    return switch(modules::build(snapshot)){case .ok(v):{.ok(v)}case .err(_):{.err(4)}};
}
// Keep layout witnesses in separate calls: their large compiler temporaries
// must not overlap the native initialization witness on the default stack.
fn void retain_output_bindings(ref input_bytes::Snapshot snapshot){
    let modules::Index index=switch(layout_index(b"module layout;pub fn i32 main(){return 0;}")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let entries::Entry entry=switch(entries::select_i32(index,b"layout",b"main")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    unsafe{binding_raw(19)};discard entry_heap(ref entry);
    let output_programs::Program kept=switch(output_programs::compile(entry,65536)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    pending_vm::retain_bindings(ref kept,snapshot);
    var vec::Vec<machines::Machine> saved=vec::empty<machines::Machine>();
    var vec::Vec<pending_output::Published> published=vec::empty<pending_output::Published>();
    var output_programs::Completion completed=output_programs::pending_completion(0);
    unsafe{binding_raw(31)};discard step_output_owner(ref mut saved,ref mut completed,ref mut published,ref kept,snapshot,0);
    unsafe{binding_raw(33)};discard cancel_output_owner(ref mut saved);
    unsafe{binding_raw(32)};let vec::Vec<machines::Machine> compacted=compact_pending_storage(saved);
    unsafe{binding_raw(36)};let vec::Vec<pending_output::Published> cleared=compact_cancelled_storage(published,false);
}
fn void retain_input_binding(){
    let modules::Index index=switch(layout_index(b"module layout;pub fn i32 main(ref u8[] data){return 0;}")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let input_entries::InputEntry entry=switch(input_entries::select_i32_input(index,b"layout",b"main")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    unsafe{binding_raw(20)};discard input_entry_heap(ref entry);
}
pub fn void retain_native_bindings(){
    let control::Budget storage=switch(control::create(1,0)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let memory::Budget retained_storage=switch(memory::create(memory::defaults(),0)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let live::Budget payloads=switch(live::create(live::Limits{.instance=268435456,.instances=536870912})){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var Meta m=Meta{.limits=Limits{.programs=1,.instances=1,.fuel=256},.thread=0,.lifetime=0,.active=0,.admission=1,.next=1,.result=0,.error=error(0),.event=pending(),.snapshot=empty_snapshot(),.closed=false,.control=storage,.programs=retained_storage,.heap=payloads,.configured=false};
    var vec::Vec<Program> p=vec::empty<Program>();var vec::Vec<Program> scratch=vec::empty<Program>();
    var vec::Vec<Instance> v=vec::empty<Instance>();var vec::Vec<entries::Entry> input=vec::empty<entries::Entry>();
    var vec::Vec<BoundInput> bound=vec::empty<BoundInput>();var vec::Vec<BoundInput> bound_scratch=vec::empty<BoundInput>();
    var vec::Vec<Output> outputs=vec::empty<Output>();var vec::Vec<Output> output_scratch=vec::empty<Output>();
    unsafe{binding_raw(1)};discard bind_inner(ref mut m,1,1);
    unsafe{binding_raw(2)};discard begin_inner(ref mut m,1,1);
    unsafe{binding_raw(3)};discard end_inner(ref mut m,1,1,1);
    unsafe{binding_raw(4)};discard compile_inner(ref mut m,ref mut p,ref mut input,0);
    unsafe{binding_raw(5)};discard dispatch_inner(ref mut m,ref mut p,ref mut scratch,ref mut v,ref mut bound,ref mut bound_scratch,ref mut outputs,ref mut output_scratch,8,0,0);
    unsafe{binding_raw(8)};discard maintenance_inner(ref mut m,ref mut p,ref mut scratch,ref mut v,ref mut bound,ref mut bound_scratch,ref mut outputs,ref mut output_scratch,1,1,8,0,0);
    unsafe{binding_raw(21)};discard compile_preflight_inner(ref mut m,ref p,0,0,0);
    unsafe{binding_raw(6)};let vec::Vec<Program> empty_programs=reset_program_storage(p);
    unsafe{binding_raw(7)};let vec::Vec<Instance> empty_instances=reset_instance_storage(v);
    var vec::Vec<input_entries::InputEntry> input_entry=vec::empty<input_entries::InputEntry>();
    var vec::Vec<Program> input_program=vec::empty<Program>();
    var vec::Vec<Instance> input_instances=vec::empty<Instance>();
    unsafe{binding_raw(9)};discard compile_input_inner(ref mut m,ref mut input_program,ref mut input_entry,0);
    var usize budget=0;
    let input_bytes::Snapshot snapshot=switch(input_bytes::snapshot(b"",0,0,ref mut budget)){
        case .ok(value):{value}case .err(_):{assert(false);return;}
    };
    unsafe{binding_raw(23)};discard input_preflight_inner(ref mut m,ref input_program,ref input_instances,0,0,ref snapshot,0,0,0,1);
    unsafe{binding_raw(10)};discard execute_borrowed_input_inner(ref mut m,ref input_program,ref mut input_instances,ref bound,0,ref snapshot);
    var vec::Vec<input_bytes::Snapshot> incoming_snapshot=vec::empty<input_bytes::Snapshot>();
    unsafe{binding_raw(11)};discard input_instance_inner(ref mut m,ref mut input_program,ref mut input_instances,ref mut bound,ref mut incoming_snapshot,0,0);
    unsafe{binding_raw(12)};let vec::Vec<BoundInput> empty_inputs=reset_input_storage(bound);
    var vec::Vec<Program> output_program=vec::empty<Program>();var vec::Vec<Instance> output_instances=vec::empty<Instance>();
    var vec::Vec<entries::Entry> output_entry=vec::empty<entries::Entry>();
    var vec::Vec<input_entries::InputEntry> output_input_entry=vec::empty<input_entries::InputEntry>();
    var vec::Vec<BoundInput> output_input=vec::empty<BoundInput>();
    unsafe{binding_raw(13)};discard compile_output_inner(ref mut m,ref mut output_program,ref mut output_entry,0);
    unsafe{binding_raw(14)};discard compile_input_output_inner(ref mut m,ref mut output_program,ref mut output_input_entry,0);
    unsafe{binding_raw(15)};discard output_instance_inner(ref mut m,ref mut output_program,ref mut output_instances,ref mut output_input,ref mut incoming_snapshot,0,0,0,0);
    var vec::Vec<Output> outgoing=vec::empty<Output>();
    unsafe{binding_raw(24)};discard output_preflight_width(ref mut m,ref output_instances,ref outputs,0,1);
    unsafe{binding_raw(16)};discard take_output_inner(ref mut m,ref mut output_instances,ref mut outputs,ref mut output_scratch,0,ref mut outgoing);
    unsafe{binding_raw(17)};let vec::Vec<Output> empty_outputs=reset_output_storage(outputs);
    unsafe{binding_raw(18)};discard control_access_inner(ref m,1,1);
    let Instance witness=Instance{.id=0,.program=0,.fuel=0,.phase=0,.event=pending(),.output_limit=0,.output_allowed=false,.input_bytes=0,.output_bytes=0,.host_terminal=host::empty_scalar_event()};
    unsafe{binding_raw(22)};discard instance_identity(ref witness);
    let Program program_witness=Program{.id=0,.pins=0,.released=false,.code=vec::empty<programs::Program>(),
        .input=vec::empty<input_programs::Program>(),.output=vec::empty<output_programs::Program>(),.bytes=0,.execution_scratch=0,.entry=empty_entry(),.host=vec::empty<host_program::Program>()};
    unsafe{binding_raw(25)};discard program_identity(ref program_witness);
    let Output output_witness=Output{.instance=0,.run=output_programs::vacant(0),.pending=vec::empty<machines::Machine>(),.host=vec::empty<host::Exchange>()};
    unsafe{binding_raw(30)};discard output_identity(ref output_witness);
    let vec::Vec<policy::Policy> owned=vec::empty<policy::Policy>();
    unsafe{binding_raw(37)};let vec::Vec<policy::Policy> cleared=reset_policy_storage(owned);
    var vec::Vec<host_program::Program> host_incoming=vec::empty<host_program::Program>();
    unsafe{binding_raw(38)};discard publish_host_inner(ref mut m,ref mut output_program,ref mut host_incoming,0,0);
    var vec::Vec<Output> host_outputs=vec::empty<Output>();
    retain_host_bindings(ref mut m,ref mut output_program,ref mut output_instances,ref mut host_outputs,ref mut output_scratch);
    retain_output_bindings(ref snapshot);retain_input_binding();
}

fn void retain_host_bindings(ref mut Meta m,ref mut vec::Vec<Program> p,
    ref mut vec::Vec<Instance> v,ref mut vec::Vec<Output> outputs,ref mut vec::Vec<Output> output_scratch){
    let ref u8[] policy_json=b"";
    switch(policy::parse(policy_json)){
        case .ok(ceiling):{
            switch(run_config::parse(b"",ref ceiling)){
                case .ok(run):{
                    let vec::Vec<policy::Policy> empty=vec::empty<policy::Policy>();
                    unsafe{binding_raw(39)};discard prepare_host_inner(m,p,v,outputs,ref empty,ref run,0,0);
                }
                case .err(_):{}
            };
        }
        case .err(_):{}
    };
    unsafe{binding_raw(40)};discard reply_host_inner(m,v,outputs,output_scratch,0,0,0,0,b"",0,0);
    var vec::Vec<host::Exchange> owners=vec::empty<host::Exchange>();
    var HostTransition next=HostTransition{.scalar=host::empty_scalar_event(),.event=pending()};
    unsafe{binding_raw(41)};discard drive_host_owner(ref mut owners,0,0,0,0,0,b"",ref mut next,0);
}

// Low-level owning VM helpers; Engine-owned stepping above pins its own inputs.
pub fn usize pending_core_stride(){return pending_vm::pending_core_stride();}
pub fn Result<machines::Machine,diagnostics::Error> prepare_pending_output(ref output_programs::Program p,ref input_bytes::Snapshot input,usize budget,usize limit,bool allowed){
    return pending_vm::prepare_pending_output(p,input,budget,limit,allowed);
}
pub fn Result<machines::Meta,errors::Error> advance_pending_output(ref mut machines::Machine machine,ref output_programs::Program p,ref input_bytes::Snapshot input,usize quantum){
    return pending_vm::advance_pending_output(machine,p,input,quantum);
}
pub fn Result<machines::Meta,errors::Error> cancel_pending_output(ref mut machines::Machine machine){return pending_vm::cancel_pending_output(machine);}
pub fn Result<pending_output::Published,errors::Error> seal_pending_output(ref mut machines::Machine machine){return pending_vm::seal_pending_output(machine);}
