module runtime_engine;
import call_copy_cursor as call_work;
import metadata_budget as metadata_budget;
import static_image as images;
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
import runtime_clock as clock;
import module_index as modules;
import source_snapshot as sources;
import project_manifest as projects;
import project_source_loader as project_loader;
import anchored_source_loader as anchored;
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
import module_source_work as source_work;
import literal_collection_work as literal_work;
import function_scan_work as signature_scan;
import static_call_ir as compile_ir;
import lexer as lexer;
import locals as locals;
import loops as loops;
import body_source_work as body_work;

// Internal owning lifecycle, not public C handles/bc_step. IDs are scoped to
// this exact Engine; the outer ABI registry must authenticate their association.
pub struct Limits { usize programs; usize instances; usize fuel; }
pub struct Error { u32 status; diagnostics::Error diagnostic; }
pub struct Event { u8 kind; i64 value; diagnostics::Error diagnostic; usize remaining; bool fuel_known; }
pub struct ScalarPreparation { usize instance; usize fuel; usize peak; usize start; }
pub enum InstanceState { Ready; Running; WaitingHost; Stopping; Terminal; }
pub struct InstanceStatus { InstanceState state; Event event; }
pub enum CompileState { Preparing; Prepared; Lowering; Lowered; Proving; Completed; Failed; Cancelled; }
pub struct CompileStatus { usize id; CompileState state; usize program; Error failure; usize batches; }
struct CompileWork {
    usize id; u8 state; usize program; Error failure; usize batches;
    usize next; usize deadline; usize image_limit;
    usize source_bytes; source_work::State source; literal_work::State literals; bool input; u32 output_mode;
}
// Request bytes are detached from the exchange.
pub struct HostRequest { usize run; usize request; usize import_id; u8[14] payload; }
// Detached routing facts for typed adapters. Pair with an Engine-scoped payload borrow.
pub struct HostRequestInfo {
    usize run; usize request; usize import_id; usize payload_bytes; host::Binding catalog;
    usize deadline; usize reply_limit;
}
struct HostTransition { Event event; host::ScalarEvent scalar; }
pub struct Snapshot { usize programs; usize instances; usize pins; bool closed; }
struct Meta {
    Limits limits; usize thread; usize lifetime; usize active; usize admission;
    usize next; usize result; Error error; Event event; Snapshot snapshot; bool closed; control::Budget control; memory::Budget programs; live::Budget heap; bool configured; bool poisoned;
}
// Exactly one executable vector has one element; the others are empty. Input code is
// never relabelled as a zero-argument Program or an array/image input lease.
struct EntryBinding {
    u8[128] scope; u8[64] function; usize scope_len; usize function_len; bool emits; bool requires_output;
}
resource Program {
    usize id; usize pins; bool released; vec::Vec<programs::Program> code;
    vec::Vec<input_programs::Program> input; vec::Vec<output_programs::Program> output; usize bytes; usize execution_scratch; EntryBinding entry; vec::Vec<host_program::Program> host; cleanup { }
}
struct Instance { usize id; usize program; usize fuel; u8 phase; bool output_owned; Event event; usize output_limit; bool output_allowed; bool input_bound; usize input_bytes; usize output_bytes; host::ScalarEvent host_terminal; usize deadline; }
resource BoundInput { usize instance; input_bytes::Snapshot input; cleanup { } }
pub resource Output { usize instance; output_programs::Execution run; vec::Vec<machines::Machine> pending; vec::Vec<host::Exchange> host; cleanup { } }
pub resource Engine {
    Meta meta; vec::Vec<Program> programs; vec::Vec<Program> scratch;
    vec::Vec<Instance> instances; vec::Vec<BoundInput> inputs;
    vec::Vec<BoundInput> input_scratch; vec::Vec<Output> outputs; vec::Vec<Output> output_scratch; vec::Vec<policy::Policy> policy;
    vec::Vec<CompileWork> compile_work; vec::Vec<entries::Entry> compile_entry; vec::Vec<programs::Lowered> compile_candidate;
    vec::Vec<input_entries::InputEntry> compile_input_entry; cleanup { }
}
@link_name("bc_runtime_engine_input_preflight") unsafe extern C fn u32 input_preflight_raw(ptr mut void owner,usize program,usize budget,ptr void input,u32 output,usize limit,u32 allowed);
@link_name("bc_runtime_engine_input_fact") unsafe extern C fn usize input_fact_raw(ptr void source,u32 fact);
@link_name("bc_runtime_engine_compile_preflight") unsafe extern C fn u32 compile_preflight_raw(ptr mut void owner,u32 mode,ptr void selected);
@link_name("bc_runtime_engine_compile_fact") unsafe extern C fn usize compile_fact_raw(ptr void source,u32 kind,u32 fact);
@link_name("bc_runtime_engine_policy_slot_bytes") unsafe extern C fn usize policy_slot_bytes_raw();
@link_name("bc_runtime_engine_prepare_host") unsafe extern C fn u32 prepare_host_raw(ptr mut void owner,usize program,ptr void run,ptr u8 input,usize length,usize selected);
@link_name("bc_runtime_engine_reply_host") unsafe extern C fn u32 reply_host_raw(ptr mut void owner,usize instance,usize run,usize request,u8 kind,ptr u8 data,usize length,usize total,usize offset);
@link_name("bc_runtime_engine_drive_host") unsafe extern C fn u32 drive_host_raw(ptr mut void owner,u32 mode,usize argument,usize run,usize request,u8 kind,ptr u8 data,usize length,ptr mut void transition,usize offset);
@link_name("bc_runtime_engine_retain_host") unsafe extern C fn u32 retain_host_raw(ptr mut void owner,ptr mut void incoming,usize deadline);
@link_name("bc_runtime_engine_bind") unsafe extern C fn u32 bind_raw(ptr mut void owner);
@link_name("bc_runtime_engine_compile") unsafe extern C fn u32 compile_raw(ptr mut void owner,ptr mut void incoming,usize limit,usize deadline);
@link_name("bc_runtime_engine_step_compile") unsafe extern C fn u32 step_compile_raw(ptr mut void owner,usize id);
@link_name("bc_runtime_engine_begin_compile") unsafe extern C fn u32 begin_compile_raw(ptr mut void owner,ptr mut void incoming,usize image_limit,usize deadline,u32 output);
@link_name("bc_runtime_engine_begin_compile_input")
unsafe extern C fn u32 begin_compile_input_raw(ptr mut void owner,ptr mut void incoming,usize image_limit,usize deadline,u32 mode);
@link_name("bc_runtime_engine_end_compile") unsafe extern C fn u32 end_compile_raw(ptr mut void owner,usize id,u32 detach);
@link_name("bc_runtime_engine_advance_compile_literals") unsafe extern C fn u32 advance_compile_literals_raw(ptr mut void meta,
    ptr void index,ptr mut void job,ptr mut void lowered,ptr mut void meter,u32 collecting);
@link_name("bc_runtime_engine_advance_compile_body") unsafe extern C fn u32 advance_compile_body_raw(ptr mut void meta,
    ptr void index,ptr void job,ptr mut void lowered,ptr mut void meter,usize deadline);
@link_name("bc_runtime_engine_compile_candidate_width") unsafe extern C fn usize compile_candidate_width_raw();
@link_name("bc_runtime_engine_dispose_compile_candidate") unsafe extern C fn void dispose_compile_candidate_raw(ptr mut void candidate);
@link_name("bc_runtime_engine_compile_input") unsafe extern C fn u32 compile_input_raw(ptr mut void owner,ptr mut void incoming,usize limit,usize deadline);
@link_name("bc_runtime_engine_execute_input") unsafe extern C fn u32 execute_input_raw(ptr mut void owner,usize instance,ptr void input);
@link_name("bc_runtime_engine_instance_input") unsafe extern C fn u32 instance_input_raw(ptr mut void owner,usize program,ptr mut void input,usize budget);
@link_name("bc_runtime_engine_call") unsafe extern C fn u32 call_raw(ptr mut void owner,u32 operation,usize id,usize argument);
@link_name("bc_runtime_engine_compile_output") unsafe extern C fn u32 compile_output_raw(ptr mut void owner,ptr mut void incoming,usize limit,u32 mode,usize deadline);
@link_name("bc_runtime_engine_instance_output") unsafe extern C fn u32 instance_output_raw(ptr mut void owner,usize program,ptr mut void input,usize budget,usize limit,u32 allowed,usize deadline);
@link_name("bc_runtime_engine_output_preflight") unsafe extern C fn u32 output_preflight_raw(ptr mut void owner,usize instance);
@link_name("bc_runtime_engine_output_fact") unsafe extern C fn usize output_fact_raw(ptr void source,u32 fact);
@link_name("bc_runtime_engine_take_output") unsafe extern C fn u32 take_output_raw(ptr mut void owner,usize instance,ptr mut void outgoing);
@link_name("bc_runtime_engine_step_output") unsafe extern C fn u32 step_output_raw(ptr mut void owner,ptr void program,ptr void input,usize quantum,usize deadline);
@link_name("bc_runtime_engine_cancel_output") unsafe extern C fn u32 cancel_output_raw(ptr mut void owner,usize deadline);
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
    var vec::Vec<entries::Entry> compile_entry=vec::empty<entries::Entry>();
    if(!vec::reserve<entries::Entry>(ref mut compile_entry,1).is_ok){return .err(error(6));}
    var vec::Vec<input_entries::InputEntry> compile_input_entry=vec::empty<input_entries::InputEntry>();
    if(!vec::reserve<input_entries::InputEntry>(ref mut compile_input_entry,1).is_ok){return .err(error(6));}
    var vec::Vec<CompileWork> compile_work=vec::empty<CompileWork>();
    if(!vec::push<CompileWork>(ref mut compile_work,empty_compile(1)).is_ok){return .err(error(6));}
    let bool configured=vec::len<policy::Policy>(ref owned)==1;
    var Engine e=Engine{.meta=Meta{.limits=limits,.thread=0,.lifetime=0,.active=0,.admission=1,.next=1,.result=0,.error=error(0),.event=pending(),.snapshot=empty_snapshot(),.closed=false,.control=storage,.programs=retained_storage,.heap=payloads,.configured=configured,.poisoned=false},
        .programs=programs,.scratch=scratch,.instances=instances,.inputs=inputs,.input_scratch=input_scratch,.outputs=outputs,.output_scratch=output_scratch,.policy=owned,
        .compile_work=compile_work,.compile_entry=compile_entry,.compile_candidate=vec::empty<programs::Lowered>(),
        .compile_input_entry=compile_input_entry};
    let u32 status=unsafe {bind_raw(ref mut e as ptr mut void)};
    if(status!=0){return .err(error(status));}return .ok(e);
}
// Actual selected source admission and immutable Program retention; the temporary
// Entry vector transfers its owner through typed Fairy pop, not a raw ABI move.
pub fn Result<usize,Error> compile(ref mut Engine e,entries::Entry selected,usize image_limit){
    return retain_entry(e,selected,image_limit,0,0);
}
fn CompileWork empty_compile(usize next){
    return CompileWork{.id=0,.state=0,.program=0,.failure=error(0),.batches=0,
        .next=next,.deadline=0,.image_limit=0,.source_bytes=0,.source=source_work::begin(true),.literals=literal_work::empty(),.input=false,.output_mode=0};
}
fn bool compile_live(CompileState state){
    return switch(state){case .Preparing:{true}case .Prepared:{true}case .Lowering:{true}case .Lowered:{true}case .Proving:{true}case .Completed:{false}case .Failed:{false}case .Cancelled:{false}};
}
fn bool compile_attached(ref Engine e){return vec::at<CompileWork>(ref e.compile_work,0).id!=0;}
pub fn Result<usize,Error> begin_compile(ref mut Engine e,entries::Entry selected,usize image_limit){
    return begin_selected_compile(e,selected,image_limit,false,0);
}
pub fn Result<usize,Error> begin_compile_output(ref mut Engine e,entries::Entry selected,usize image_limit){
    return begin_selected_compile(e,selected,image_limit,true,0);
}
fn Result<usize,Error> begin_selected_compile(ref mut Engine e,entries::Entry selected,usize image_limit,bool output,usize expires){
    let usize guard=unsafe{compile_preflight(e,if(output){2}else{0},ref selected as ptr void)}?;
    let usize deadline=compile_deadline(e,expires)?;
    if(compile_attached(e)){return .err(error(3));}
    var vec::Vec<entries::Entry> incoming=vec::empty<entries::Entry>();
    if(!vec::push<entries::Entry>(ref mut incoming,selected).is_ok){return .err(error(6));}
    let u32 status=unsafe{begin_compile_raw(e as ptr mut void,ref mut incoming as ptr mut void,image_limit,deadline,if(output){1}else{0})};
    return result(e,status);
}
pub fn Result<usize,Error> begin_compile_input(ref mut Engine e,input_entries::InputEntry selected,usize image_limit){
    return begin_selected_input_compile(e,selected,image_limit,0,0);
}
pub fn Result<usize,Error> begin_compile_input_output(ref mut Engine e,input_entries::InputEntry selected,usize image_limit){
    return begin_selected_input_compile(e,selected,image_limit,1,0);
}
fn Result<usize,Error> begin_selected_input_compile(ref mut Engine e,input_entries::InputEntry selected,usize image_limit,u32 mode,usize expires){
    let usize guard=unsafe{compile_preflight(e,if(mode==0){1}else{3},ref selected as ptr void)}?;
    if(compile_attached(e)){return .err(error(3));}
    let usize deadline=compile_deadline(e,expires)?;
    var vec::Vec<input_entries::InputEntry> incoming=vec::empty<input_entries::InputEntry>();
    if(!vec::push<input_entries::InputEntry>(ref mut incoming,selected).is_ok){return .err(error(6));}
    let u32 status=unsafe{begin_compile_input_raw(e as ptr mut void,ref mut incoming as ptr mut void,image_limit,deadline,mode)};
    return result(e,status);
}
fn CompileStatus observed_compile(ref Engine e){
    let ref CompileWork job=vec::at<CompileWork>(ref e.compile_work,0);
    let u8 phase=job.state;
    let CompileState state=if(phase==0){.Preparing}else if(phase==1){.Prepared}
        else if(phase==2){.Lowered}else if(phase==3){.Completed}else if(phase==4){.Failed}else if(phase==5){.Cancelled}else if(phase==6){.Lowering}else{.Proving};
    return CompileStatus{.id=job.id,.state=state,.program=job.program,.failure=job.failure,.batches=job.batches};
}
pub fn Result<CompileStatus,Error> observe_compile(ref Engine e,usize id){
    let u32 guard=unsafe{control_access_raw(e as ptr void)};
    if(guard!=0){return .err(error(guard));}
    if(e.meta.closed || id==0){return .err(error(2));}
    let CompileStatus status=observed_compile(e);
    return if(status.id==id){.ok(status)}else{.err(error(2))};
}
pub fn Result<CompileStatus,Error> step_compile(ref mut Engine e,usize id){
    let CompileStatus before=observe_compile(e,id)?;
    if(!compile_live(before.state)){return .ok(before);}
    let u32 status=unsafe{step_compile_raw(e as ptr mut void,id)};
    if(status!=0){return .err(error(status));}
    return .ok(observed_compile(e));
}
pub fn Result<CompileStatus,Error> cancel_compile(ref mut Engine e,usize id){
    let CompileStatus before=observe_compile(e,id)?;
    if(!compile_live(before.state)){return .ok(before);}
    let u32 status=unsafe{end_compile_raw(e as ptr mut void,id,0)};
    if(status!=0){return .err(error(status));}
    return .ok(observed_compile(e));
}
pub fn Result<CompileStatus,Error> detach_compile(ref mut Engine e,usize id){
    let CompileStatus final=observe_compile(e,id)?;
    if(compile_live(final.state)){return .err(error(3));}
    let u32 status=unsafe{end_compile_raw(e as ptr mut void,id,1)};
    if(status!=0){return .err(error(status));}
    return .ok(final);
}
fn Result<usize,Error> retain_entry(ref mut Engine e,entries::Entry selected,usize image_limit,u32 mode,usize deadline){
    let usize admitted=unsafe{compile_preflight(e,mode,ref selected as ptr void)}?;
    let usize expires=compile_deadline(e,deadline)?;
    var vec::Vec<entries::Entry> incoming=vec::empty<entries::Entry>();
    if(!vec::reserve<entries::Entry>(ref mut incoming,1).is_ok){return .err(error(6));}
    if(!vec::push<entries::Entry>(ref mut incoming,selected).is_ok){return .err(error(6));}
    let u32 status=unsafe {
        if(mode==0){compile_raw(e as ptr mut void,ref mut incoming as ptr mut void,image_limit,expires)}
        else{compile_output_raw(e as ptr mut void,ref mut incoming as ptr mut void,image_limit,0,expires)}
    };
    return result(e,status);
}
pub fn usize source_byte_limit(ref Engine e){
    let usize ceiling=sources::source_limit();
    if(!e.meta.configured){return ceiling;}
    let policy_limits::CompileLimits bounds=policy::compile_limits(vec::at<policy::Policy>(ref e.policy,0));
    return if(bounds.source_bytes<ceiling){bounds.source_bytes}else{ceiling};
}
fn Result<sources::Snapshot,Error> load_project(ref Engine e,ref projects::Project metadata,ref u8[] root,usize deadline){
    let usize limit=source_byte_limit(e);
    return project_snapshot(project_loader::load_until(metadata,root,limit,deadline));
}
fn Result<sources::Snapshot,Error> project_snapshot(Result<sources::Snapshot,project_loader::Error> collected){
    return switch(collected){
        case .ok(v):{.ok(v)}
        case .err(reason):{.err(switch(reason){
            case .Limit:{error(8)}case .Acquisition:{error(1)}case .Binding:{error(4)}
            case .Compile:{error(4)}case .Deadline:{compile_timeout()}
        })}
    };
}
fn Error project_error(modules::Error reason){
    return Error{.status=4,.diagnostic=diagnostics::Error{.code=errors::make(3,reason.at.start),.at=reason.at}};
}
// Pure project profiles deny requirements before touching the filesystem.
pub fn Result<usize,Error> compile_project(ref mut Engine e,ref projects::Project metadata,ref u8[] root,usize image_limit){
    let usize ready=unsafe{compile_preflight(e,0,null)}?;
    if(projects::requirements(metadata)!=0){return .err(error(5));}
    let usize deadline=compile_deadline(e,0)?;
    let entries::Entry selected=project_entry(e,metadata,root,deadline)?;
    return retain_entry(e,selected,image_limit,0,deadline);
}
// Acquisition and entry selection finish before the caller receives a job.
pub fn Result<usize,Error> begin_compile_project(ref mut Engine e,ref projects::Project metadata,ref u8[] root,usize image_limit){
    let usize ready=unsafe{compile_preflight(e,0,null)}?;
    if(projects::requirements(metadata)!=0){return .err(error(5));}
    if(compile_attached(e)){return .err(error(3));}
    let usize deadline=compile_deadline(e,0)?;
    let entries::Entry selected=project_entry(e,metadata,root,deadline)?;
    return begin_selected_compile(e,selected,image_limit,false,deadline);
}
fn Result<entries::Entry,Error> project_entry(ref Engine e,ref projects::Project metadata,ref u8[] root,usize deadline){
    let sources::Snapshot snapshot=load_project(e,metadata,root,deadline)?;
    if(clock::expired(deadline)){return .err(compile_timeout());}
    return switch(project_binding::select(metadata,snapshot)){
        case .ok(v):{.ok(v)}case .err(reason):{.err(project_error(reason))}
    };
}
pub fn Result<usize,Error> compile_project_input(ref mut Engine e,ref projects::Project metadata,ref u8[] root,usize image_limit){
    let usize ready=unsafe{compile_preflight(e,1,null)}?;
    if(projects::requirements(metadata)!=0){return .err(error(5));}
    let usize deadline=compile_deadline(e,0)?;
    let input_entries::InputEntry selected=project_input_entry(e,metadata,root,deadline)?;
    return retain_input_entry(e,selected,image_limit,0,deadline);
}
pub fn Result<usize,Error> begin_compile_project_input(ref mut Engine e,ref projects::Project metadata,ref u8[] root,usize image_limit){
    let usize ready=unsafe{compile_preflight(e,1,null)}?;
    if(projects::requirements(metadata)!=0){return .err(error(5));}
    if(compile_attached(e)){return .err(error(3));}
    let usize deadline=compile_deadline(e,0)?;
    let input_entries::InputEntry selected=project_input_entry(e,metadata,root,deadline)?;
    return begin_selected_input_compile(e,selected,image_limit,0,deadline);
}
fn Result<input_entries::InputEntry,Error> project_input_entry(ref Engine e,ref projects::Project metadata,ref u8[] root,usize deadline){
    let sources::Snapshot snapshot=load_project(e,metadata,root,deadline)?;
    return select_project_input(metadata,snapshot,deadline);
}
fn Result<input_entries::InputEntry,Error> select_project_input(ref projects::Project metadata,
    sources::Snapshot snapshot,usize deadline){
    if(clock::expired(deadline)){return .err(compile_timeout());}
    return switch(project_binding::select_input(metadata,snapshot)){
        case .ok(v):{.ok(v)}
        case .err(reason):{.err(project_error(reason))}
    };
}
pub fn Result<usize,Error> compile_input(ref mut Engine e,input_entries::InputEntry selected,usize image_limit){
    return retain_input_entry(e,selected,image_limit,0,0);
}
pub fn Result<usize,Error> create_instance(ref mut Engine e,usize program,usize budget){let u32 s=unsafe{call_raw(e as ptr mut void,1,program,budget)};return result(e,s);}
pub fn Result<usize,Error> compile_output(ref mut Engine e,entries::Entry selected,usize image_limit){
    return retain_entry(e,selected,image_limit,2,0);
}
pub fn Result<usize,Error> compile_input_output(ref mut Engine e,input_entries::InputEntry selected,usize image_limit){
    return retain_input_entry(e,selected,image_limit,1,0);
}
// Output modes 2 and 3 carry a checked project declaration into publication.
fn Result<usize,Error> retain_input_entry(ref mut Engine e,input_entries::InputEntry selected,usize image_limit,u32 mode,usize deadline){
    let usize admitted=unsafe{compile_preflight(e,if(mode==0){1}else{3},ref selected as ptr void)}?;
    let usize expires=compile_deadline(e,deadline)?;
    var vec::Vec<input_entries::InputEntry> incoming=vec::empty<input_entries::InputEntry>();
    if(!vec::reserve<input_entries::InputEntry>(ref mut incoming,1).is_ok){return .err(error(6));}
    if(!vec::push<input_entries::InputEntry>(ref mut incoming,selected).is_ok){return .err(error(6));}
    let u32 status=unsafe{
        if(mode==0){compile_input_raw(e as ptr mut void,ref mut incoming as ptr mut void,image_limit,expires)}
        else{compile_output_raw(e as ptr mut void,ref mut incoming as ptr mut void,image_limit,mode,expires)}
    };
    return result(e,status);
}
pub fn Result<usize,Error> create_output_instance(ref mut Engine e,usize program,usize budget,usize limit,bool allowed){
    var vec::Vec<input_bytes::Snapshot> incoming=vec::empty<input_bytes::Snapshot>();
    let u32 s=unsafe{instance_output_raw(e as ptr mut void,program,ref mut incoming as ptr mut void,budget,limit,if(allowed){1}else{0},0)};return result(e,s);
}
pub fn Result<usize,Error> create_input_output_instance(ref mut Engine e,usize program,input_bytes::Snapshot input,usize budget,usize limit,bool allowed){
    return bind_input_output(e,program,input,budget,limit,if(allowed){1}else{0},0);
}
// Modes 0/1 are trusted legacy denial/allow. Modes 2/3 carry configured
// denial/allow and can only be selected after the Engine policy check.
fn Result<usize,Error> bind_input_output(ref mut Engine e,usize program,input_bytes::Snapshot input,usize budget,usize limit,u32 authority,usize deadline){
    let u32 preflight=unsafe{input_preflight_raw(e as ptr mut void,program,budget,ref input as ptr void,1,limit,authority)};
    if(preflight!=0){return .err(error(preflight));}
    var vec::Vec<input_bytes::Snapshot> incoming=vec::empty<input_bytes::Snapshot>();
    if(!vec::reserve<input_bytes::Snapshot>(ref mut incoming,1).is_ok){return .err(error(6));}
    if(!vec::push<input_bytes::Snapshot>(ref mut incoming,input).is_ok){return .err(error(6));}
    let u32 s=unsafe{instance_output_raw(e as ptr mut void,program,ref mut incoming as ptr mut void,budget,limit,authority,deadline)};return result(e,s);
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
    return host_compile_limits(e);
}
fn Result<policy_limits::CompileLimits,Error> host_compile_limits(ref Engine e){
    if(e.meta.poisoned){return .err(error(14));}
    if(e.meta.admission==0 || e.meta.next==0 || vec::len<Program>(ref e.programs)>=e.meta.limits.programs){return .err(error(8));}
    return .ok(policy::compile_limits(vec::at<policy::Policy>(ref e.policy,0)));
}

// Single-source entry through the existing private scalar host dialect.
pub fn Result<usize,Error> compile_scalar_host(ref mut Engine e,ref u8[] source,host_catalog::Catalog imports,
    ref u32[] digest,ref run_config::RunConfig run){
    let policy_limits::CompileLimits limits=source_host_limits(e,run)?;
    if(source.len>limits.source_bytes){return .err(error(8));}
    let usize deadline=deadline_after(limits.deadline_ms)?;
    var ir::Program code=ir::empty();
    switch(compiler::lower_scalar_host_until(source,ref imports,ref mut code,limits.tokens,deadline)){
        case .ok(_):{}
        case .err(problem):{
            if(problem.kind==errors::deadline_kind()){return .err(compile_timeout());}
            let usize at=problem.offset;
            return .err(Error{.status=4,.diagnostic=diagnostics::Error{
                .code=problem,.at=sources::Span{.source=0,.start=at,.end=if(at<source.len){at+1}else{at}}}});
        }
    };
    return retain_limited_host(e,ref code,imports,digest,run,limits,deadline);
}

fn bool project_host_authority(ref projects::Project project,ref run_config::RunConfig run){
    let usize count=projects::requirements(project);
    if(count!=run_config::requires_count(run) ||
       !bytes::equal(projects::entry_module(project),run_config::module_name(run)) ||
       !bytes::equal(projects::entry_function(project),run_config::function_name(run))){return false;}
    var usize i=0;
    while(i<count){
        let ref u8[] name=switch(projects::requirement(project,i)){
            case .ok(v):{v}case .err(_):{return false;}
        };
        if(!run_config::declares(run,name)){return false;}
        i+=1;
    }
    return true;
}

pub fn Result<usize,Error> compile_anchored_project_host(ref mut Engine e,ref projects::Project project,
    ref mut anchored::Root root,host_catalog::Catalog imports,ref u32[] digest,ref run_config::RunConfig run){
    discard check_run_policy(e,run)?;
    if(!project_host_authority(project,run)){return .err(error(5));}
    let policy_limits::CompileLimits limits=host_compile_limits(e)?;
    if(projects::count(project)>limits.modules){return .err(error(8));}
    let usize deadline=deadline_after(limits.deadline_ms)?;
    let sources::Snapshot snapshot=project_snapshot(project_loader::load_from_until(project,root,source_byte_limit(e),deadline))?;
    if(clock::expired(deadline)){return .err(compile_timeout());}
    let modules::Index index=switch(project_binding::index_host(project,snapshot,limits.tokens)){
        case .ok(v):{v}case .err(e):{return .err(host_binding_error(e));}
    };
    let usize selected=switch(modules::entry(ref index,projects::entry_module(project),projects::entry_function(project))){
        case .ok(v):{v}case .err(e):{return .err(host_binding_error(e));}
    };
    return retain_project_host(e,ref index,selected,imports,digest,run,limits,deadline);
}
fn Error host_binding_error(modules::Error e){
    return Error{.status=4,.diagnostic=diagnostics::Error{.code=diagnostics::binding(e),.at=e.at}};
}
fn Result<usize,Error> retain_project_host(ref mut Engine e,ref modules::Index index,usize selected,
    host_catalog::Catalog imports,ref u32[] digest,ref run_config::RunConfig run,policy_limits::CompileLimits limits,usize deadline){
    var ir::Program code=ir::empty();
    switch(compiler::lower_project_host(index,selected,ref imports,ref mut code,deadline)){
        case .ok(_):{}case .err(e):{return .err(Error{.status=4,.diagnostic=e});}
    };
    return retain_limited_host(e,ref code,imports,digest,run,limits,deadline);
}
fn Result<usize,Error> retain_limited_host(ref mut Engine e,ref ir::Program code,host_catalog::Catalog imports,
    ref u32[] digest,ref run_config::RunConfig run,policy_limits::CompileLimits limits,usize deadline){
    if(code.count>limits.instructions || code.function_count>limits.functions){return .err(error(8));}
    var usize f=0;
    while(f<code.function_count){
        if(code.register_ends[f]-code.register_starts[f]>limits.registers_per_function){return .err(error(8));}
        f+=1;
    }
    return retain_verified_host(e,code,imports,digest,run,deadline);
}

// Trusted internal IR admission. The Engine retains the resulting verified owner.
pub fn Result<usize,Error> retain_scalar_host(ref mut Engine e,ref ir::Program code,host_catalog::Catalog imports,
    ref u32[] digest,ref run_config::RunConfig run){
    let usize checked=check_run_policy(e,run)?;
    let usize deadline=compile_deadline(e,0)?;
    return retain_verified_host(e,code,imports,digest,run,deadline);
}
fn Result<usize,Error> retain_verified_host(ref mut Engine e,ref ir::Program code,host_catalog::Catalog imports,
    ref u32[] digest,ref run_config::RunConfig run,usize deadline){
    if(clock::expired(deadline)){return .err(compile_timeout());}
    let host_program::Program verified=verify_scalar_host(e,code,imports,digest,run)?;
    var vec::Vec<host_program::Program> incoming=vec::empty<host_program::Program>();
    if(!vec::push<host_program::Program>(ref mut incoming,verified).is_ok){return .err(error(6));}
    let u32 status=unsafe{retain_host_raw(e as ptr mut void,ref mut incoming as ptr mut void,deadline)};
    return result(e,status);
}

fn Result<host_program::Program,Error> verify_scalar_host(ref Engine e,ref ir::Program code,host_catalog::Catalog imports,
    ref u32[] digest,ref run_config::RunConfig run){
    let usize checked=check_run_policy(e,run)?;
    if(e.meta.poisoned){return .err(error(14));}
    if(e.meta.admission==0 || e.meta.next==0 || vec::len<Program>(ref e.programs)>=e.meta.limits.programs){return .err(error(8));}
    return switch(host_program::retain(code,imports,digest,vec::at<policy::Policy>(ref e.policy,0),run)){
        case .ok(v):{.ok(v)}
        case .err(reason):{return .err(error(switch(reason){
            case .Authority:{5}case .Allocation:{6}case .Code:{4}case .Catalog:{1}case .Binding:{1}
        }));}
    };
}

pub fn Result<bool,Error> host_program_emits(ref Engine e,usize id){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}
    let usize pi=switch(program_index(ref e.programs,id,true)){
        case .ok(v):{v}case .err(s):{return .err(error(s));}
    };
    let ref Program retained=vec::at<Program>(ref e.programs,pi);
    if(vec::len<host_program::Program>(ref retained.host)!=1){return .err(error(1));}
    return .ok(host_program::emits(vec::at<host_program::Program>(ref retained.host,0)));
}

// Trusted embedding can reuse the output Machine for its resumable dispatcher.
// Read the input signature from the retained proof. Output authority is denied
// for this embedding profile.
pub fn Result<bool,Error> preview_accepts_input(ref Engine e,usize id){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}
    let usize pi=switch(program_index(ref e.programs,id,true)){
        case .ok(v):{v}case .err(s):{return .err(error(s));}
    };
    let ref Program retained=vec::at<Program>(ref e.programs,pi);
    if(vec::len<output_programs::Program>(ref retained.output)!=1){return .err(error(1));}
    let ref output_programs::Program code=vec::at<output_programs::Program>(ref retained.output,0);
    if(output_programs::requires_emit(code)){return .err(error(5));}
    return .ok(output_programs::accepts_input(code));
}

pub fn Result<usize,Error> prepare_scalar_host(ref mut Engine e,usize program,ref run_config::RunConfig run){
    return prepare_host(e,program,run,b"",0);
}
pub fn Result<usize,Error> prepare_input_host(ref mut Engine e,usize program,ref run_config::RunConfig run,
    ref input_bytes::Snapshot input){
    let policy_limits::RunLimits limits=check_run_input(e,run,input)?;
    // Charge the caller's immutable Snapshot during the handoff as well as the
    // exchange's own retained copy. No source pointer survives this call.
    return prepare_host(e,program,run,input_bytes::view(input),input_bytes::capacity(input)+1);
}
fn Result<usize,Error> prepare_host(ref mut Engine e,usize program,ref run_config::RunConfig run,
    ref u8[] input,usize selected){
    let u32 status=unsafe{prepare_host_raw(e as ptr mut void,program,run as ptr void,input as ptr u8,input.len,selected)};
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
            if(vec::at<Instance>(ref e.instances,i).phase==5){return .err(error(14));}
        }
        case .err(_):{return .err(error(2));}
    };
    let usize oi=host_output_index(e,instance)?;
    let ref Output owner=vec::at<Output>(ref e.outputs,oi);
    return switch(host::observe_scalar(vec::at<host::Exchange>(ref owner.host,0))){
        case .ok(v):{.ok(v)}case .err(_):{.err(error(7))}
    };
}
fn Result<ref host::Exchange,Error> request_exchange(ref Engine e,usize instance){
    let usize oi=host_output_index(e,instance)?;
    if(e.meta.poisoned){return .err(error(14));}
    let ref Output owner=vec::at<Output>(ref e.outputs,oi);
    let ref host::Exchange exchange=vec::at<host::Exchange>(ref owner.host,0);
    if(host::deadline_reached(exchange,clock::now())){return .err(error(11));}
    return .ok(exchange);
}

pub fn Result<HostRequestInfo,Error> host_request_info(ref Engine e,usize instance){
    let ref host::Exchange exchange=request_exchange(e,instance)?;
    let host::Observation state=host::observe(exchange);
    if(state.phase!=1){return .err(error(11));}
    if(state.run!=instance){return .err(error(7));}
    let ref u8[] payload=switch(host::request_bytes(exchange)){
        case .ok(data):{data}case .err(_):{return .err(error(7));}
    };
    return .ok(HostRequestInfo{.run=state.run,.request=state.request,.import_id=state.import_id,
        .payload_bytes=payload.len,.catalog=host::binding(exchange),
        .deadline=host::deadline(exchange),.reply_limit=host::reply_limit(exchange)});
}

pub fn bool same_host_request(ref HostRequestInfo expected,ref HostRequestInfo current){
    return expected.run==current.run && expected.request==current.request &&
        expected.import_id==current.import_id && expected.payload_bytes==current.payload_bytes &&
        expected.deadline==current.deadline && expected.reply_limit==current.reply_limit &&
        host_program::same_digest(ref expected.catalog.words,ref current.catalog.words);
}

// The adapter reserves dispatch after it has copied and validated the request.
pub fn Result<usize,Error> claim_host_request(ref mut Engine e,usize instance,ref HostRequestInfo expected){
    let HostRequestInfo current=host_request_info(e,instance)?;
    if(!same_host_request(expected,ref current)){return .err(error(1));}
    let u32 status=unsafe{call_raw(e as ptr mut void,11,instance,current.request)};
    return result(e,status);
}

// The borrow is scoped to the immutable Engine view. Copy into adapter-owned
// storage before stepping, replying, cancelling or destroying the Instance.
pub fn Result<ref u8[],Error> host_request_payload(ref Engine e,usize instance){
    let ref host::Exchange exchange=request_exchange(e,instance)?;
    return switch(host::request_bytes(exchange)){
        case .ok(data):{.ok(data)}case .err(_):{.err(error(11))}
    };
}
pub fn Result<HostRequest,Error> scalar_host_request(ref Engine e,usize instance){
    let ref host::Exchange exchange=request_exchange(e,instance)?;
    let host::Observation state=host::observe(exchange);
    let ref u8[] data=switch(host::request_bytes(exchange)){
        case .ok(v):{v}case .err(_):{return .err(error(11));}
    };
    if(data.len!=14 || state.run!=instance){return .err(error(7));}
    var u8[14] payload=[0;14];var usize i=0;
    while(i<14){payload[i]=data[i];i+=1;}
    return .ok(HostRequest{.run=state.run,.request=state.request,.import_id=state.import_id,.payload=payload});
}

fn Result<u32,Error> project_output_mode(ref mut Engine e,ref projects::Project metadata,ref run_config::RunConfig run){
    let usize checked=check_run_policy(e,run)?;
    let usize ready=unsafe{compile_preflight(e,3,null)}?;
    let usize declared=projects::requirements(metadata);
    if(declared>1 || declared!=run_config::requires_count(run) ||
        !bytes::equal(projects::entry_module(metadata),run_config::module_name(run)) ||
        !bytes::equal(projects::entry_function(metadata),run_config::function_name(run))){return .err(error(5));}
    if(declared==1){
        let ref u8[] name=switch(projects::requirement(metadata,0)){
            case .ok(v):{v}case .err(_):{return .err(error(7));}
        };
        if(!bytes::equal(name,b"brownie.output.emit") || !run_config::declares(run,name)){return .err(error(5));}
    }
    return .ok(if(declared==1){3}else{2});
}

// Compile the configured entry once. The retained Program starts with no pins.
pub fn Result<usize,Error> compile_project_output(ref mut Engine e,ref projects::Project metadata,
    ref u8[] root,ref run_config::RunConfig run,usize image_limit){
    let u32 mode=project_output_mode(e,metadata,run)?;
    let usize deadline=compile_deadline(e,0)?;
    let input_entries::InputEntry selected=project_input_entry(e,metadata,root,deadline)?;
    return retain_input_entry(e,selected,image_limit,mode,deadline);
}

pub fn Result<usize,Error> begin_compile_project_output(ref mut Engine e,ref projects::Project metadata,
    ref u8[] root,ref run_config::RunConfig run,usize image_limit){
    let u32 mode=project_output_mode(e,metadata,run)?;
    if(compile_attached(e)){return .err(error(3));}
    let usize deadline=compile_deadline(e,0)?;
    let input_entries::InputEntry selected=project_input_entry(e,metadata,root,deadline)?;
    return begin_selected_input_compile(e,selected,image_limit,mode,deadline);
}

// Use the directory owner that supplied the explicit manifest. Validate policy
// and entry before consuming the anchor's single allowed member collection.
pub fn Result<usize,Error> compile_anchored_project_output(ref mut Engine e,ref projects::Project metadata,
    ref mut anchored::Root root,ref run_config::RunConfig run,usize image_limit){
    let u32 mode=project_output_mode(e,metadata,run)?;
    let usize deadline=compile_deadline(e,0)?;
    let input_entries::InputEntry selected=anchored_project_input_entry(e,metadata,root,deadline)?;
    return retain_input_entry(e,selected,image_limit,mode,deadline);
}

pub fn Result<usize,Error> begin_compile_anchored_project_output(ref mut Engine e,ref projects::Project metadata,
    ref mut anchored::Root root,ref run_config::RunConfig run,usize image_limit){
    let u32 mode=project_output_mode(e,metadata,run)?;
    if(compile_attached(e)){return .err(error(3));}
    let usize deadline=compile_deadline(e,0)?;
    let input_entries::InputEntry selected=anchored_project_input_entry(e,metadata,root,deadline)?;
    return begin_selected_input_compile(e,selected,image_limit,mode,deadline);
}
fn Result<input_entries::InputEntry,Error> anchored_project_input_entry(ref Engine e,ref projects::Project metadata,
    ref mut anchored::Root root,usize deadline){
    let sources::Snapshot snapshot=project_snapshot(project_loader::load_from_until(metadata,root,source_byte_limit(e),deadline))?;
    return select_project_input(metadata,snapshot,deadline);
}

pub fn Result<usize,Error> compile_granted_output(ref mut Engine e,modules::Index index,
    ref run_config::RunConfig run,usize image_limit){
    let usize checked=check_run_policy(e,run)?;
    let usize deadline=compile_deadline(e,0)?;
    let input_entries::InputEntry selected=switch(input_entries::select_i32_input(
        index,run_config::module_name(run),run_config::function_name(run))){
        case .ok(v):{v}
        case .err(e):{return .err(Error{.status=4,.diagnostic=diagnostics::Error{
            .code=errors::make(3,e.at.start),.at=e.at}});}
    };
    return retain_input_entry(e,selected,image_limit,1,deadline);
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
    let usize deadline=deadline_after(limits.deadline_ms)?;
    let usize instance=bind_input_output(e,program,input,limits.fuel,max_output,if(emits){3}else{2},deadline)?;
    return prepare_created_instance(e,instance,limits.call_frames);
}

fn Result<usize,Error> prepare_created_instance(ref mut Engine e,usize instance,usize frame_limit){
    return switch(prepare_instance_frames(e,instance,frame_limit)){
        case .ok(_):{.ok(instance)}
        case .err(failure):{let usize disposed=destroy_instance(e,instance)?;.err(failure)}
    };
}

// The scalar embedding adapter has already authenticated the public handle.
// Check the request against this Engine's policy before pinning the Program.
fn Result<run_config::RunConfig,Error> parse_scalar_run(ref Engine e,ref u8[] configuration){
    if(!e.meta.configured){return .err(error(5));}
    let run_config::RunConfig run=switch(run_config::parse(configuration,vec::at<policy::Policy>(ref e.policy,0))){
        case .ok(v):{v}
        case .err(problem):{
            let u32 status=switch(problem.kind){
            case .Allocation:{6}case .Limit:{8}
            case .Json:{5}case .Unknown:{5}case .Duplicate:{5}case .Missing:{5}
            case .Value:{5}case .Relation:{5}case .Authority:{5}case .Bounds:{5}
            };
            return .err(error(status));
        }
    };
    return .ok(run);
}

pub fn Result<ScalarPreparation,Error> prepare_scalar_preview(ref mut Engine e,usize program,ref u8[] input,ref u8[] configuration){
    let bool accepts=preview_accepts_input(e,program)?;
    if(!accepts && input.len!=0){return .err(error(1));}
    let run_config::RunConfig run=parse_scalar_run(e,configuration)?;
    if(!bytes::equal(run_config::module_name(ref run),b"main") ||
        !bytes::equal(run_config::function_name(ref run),b"main") ||
        run_config::requires_count(ref run)!=0 || run_config::grants_count(ref run)!=0){return .err(error(5));}
    let policy_limits::RunLimits limits=run_config::run_limits(ref run);
    let usize pending=required_pending_bytes(e,program,0)?;
    if(limits.fuel>e.meta.limits.fuel || input.len>limits.input_bytes ||
        pending>limits.memory_bytes || input.len>limits.memory_bytes-pending){return .err(error(8));}
    let usize deadline=deadline_after(limits.deadline_ms)?;
    var usize peak=pending;
    let usize id=if(accepts){
        var usize unused=0;
        let input_bytes::Snapshot snapshot=switch(input_bytes::snapshot(input,limits.input_bytes,0,ref mut unused)){
            case .ok(v):{v}
            case .err(reason):{return .err(error(switch(reason){
                case .Allocation:{6}case .Limit:{8}case .Fuel:{8}case .Bounds:{1}
            }));}
        };
        let usize capacity=input_bytes::capacity(ref snapshot);
        if(capacity>limits.memory_bytes-pending){return .err(error(8));}
        peak+=capacity;
        bind_input_output(e,program,snapshot,limits.fuel,0,2,deadline)?
    }else{
        var vec::Vec<input_bytes::Snapshot> incoming=vec::empty<input_bytes::Snapshot>();
        let u32 status=unsafe{instance_output_raw(e as ptr mut void,program,ref mut incoming as ptr mut void,
            limits.fuel,0,2,deadline)};
        result(e,status)?
    };
    let usize prepared=prepare_created_instance(e,id,limits.call_frames)?;
    return .ok(ScalarPreparation{.instance=prepared,.fuel=limits.fuel,.peak=peak,
        .start=deadline-limits.deadline_ms*10000});
}

// Policy admits durations in 1..60000 ms; Windows interrupt time uses 100 ns ticks.
fn Result<usize,Error> deadline_after(usize milliseconds){
    let usize duration=milliseconds*10000;
    let usize start=clock::now();
    if(start>18446744073709551615-duration){return .err(error(8));}
    return .ok(start+duration);
}
fn Result<usize,Error> compile_deadline(ref Engine e,usize existing){
    if(existing!=0){return .ok(existing);}
    if(!e.meta.configured){return .ok(0);}
    let policy_limits::CompileLimits limits=policy::compile_limits(vec::at<policy::Policy>(ref e.policy,0));
    return deadline_after(limits.deadline_ms);
}
fn Error compile_timeout(){
    return Error{.status=4,.diagnostic=diagnostics::absent(errors::absent(errors::deadline_kind(),0))};
}
fn u32 compile_timed_out(ref mut Meta m){m.error=compile_timeout();return 4;}

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
    if((entry.emits || entry.requires_output) && (!run_config::declares(run,name) || !run_config::grants(run,name))){
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
fn bool has_host_output(ref Output o){
    return vec::len<host::Exchange>(ref o.host)==1 && host::has_guest_output(vec::at<host::Exchange>(ref o.host,0));
}
pub fn output_programs::Completion output_completion(ref Output o){
    if(!has_host_output(o)){return output_programs::observe(ref o.run);}
    let ref host::Exchange exchange=vec::at<host::Exchange>(ref o.host,0);
    let host::ScalarEvent done=switch(host::observe_scalar(exchange)){
        case .ok(v):{v}case .err(_):{assert(false);host::empty_scalar_event()}
    };
    return output_programs::Completion{.success=true,.value=done.value,.remaining=done.host.fuel,
        .diagnostic=absent(),.output_bytes=host::guest_output(exchange).len,.emits=host::guest_emits(exchange),.cancelled=false};
}
pub fn bool output_available(ref Output o){return has_host_output(o) || output_programs::has_output(ref o.run);}
pub fn ref u8[] output_view(ref Output o){
    if(has_host_output(o)){return host::guest_output(vec::at<host::Exchange>(ref o.host,0));}
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
    return prepare_instance_frames(e,instance,31);
}
fn Result<Event,Error> prepare_instance_frames(ref mut Engine e,usize instance,usize frame_limit){
    let u32 s=unsafe{call_raw(e as ptr mut void,9,instance,frame_limit)};
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
// A detached observation of the current lifecycle. For Stopping, the event
// describes the latched outcome, while the Instance still owns its scratch.
pub fn Result<InstanceStatus,Error> instance_status(ref Engine e,usize instance){
    let u32 status=unsafe{control_access_raw(e as ptr void)};
    if(status!=0){return .err(error(status));}
    if(e.meta.closed){return .err(error(2));}
    let usize ii=switch(instance_index(ref e.instances,instance)){
        case .ok(v):{v}case .err(s):{return .err(error(s));}
    };
    let ref Instance current=vec::at<Instance>(ref e.instances,ii);
    if(current.phase==3){return pending_instance_status(e,current);}
    let InstanceState state=if(current.phase==0){.Ready}else if(current.phase==2 || current.phase==5){.Terminal}
        else if(current.phase==4 && current.event.kind==4){.WaitingHost}else{.Running};
    return .ok(InstanceStatus{.state=state,.event=current.event});
}
fn Result<InstanceStatus,Error> pending_instance_status(ref Engine e,ref Instance current){
    let usize oi=switch(output_index(ref e.outputs,current.id)){
        case .ok(v):{v}case .err(_):{return .err(error(7));}
    };
    let ref Output output=vec::at<Output>(ref e.outputs,oi);
    if(vec::len<machines::Machine>(ref output.pending)!=1){return .err(error(7));}
    return switch(machines::stopping(vec::at<machines::Machine>(ref output.pending,0))){
        case .some(stop):{
            let Event event=stopping_event(ref e.programs,current,stop)?;
            .ok(InstanceStatus{.state=.Stopping,.event=event})
        }
        case .none:{.ok(InstanceStatus{.state=.Running,.event=current.event})}
    };
}
fn Result<Event,Error> stopping_event(ref vec::Vec<Program> programs,ref Instance current,machines::Stop stop){
    var diagnostics::Error diagnostic=absent();
    if(!stop.cancelled){
        let usize pi=switch(program_index(programs,current.program,false)){
            case .ok(v):{v}case .err(_):{return .err(error(7));}
        };
        let ref Program program=vec::at<Program>(programs,pi);
        if(program.pins==0 || vec::len<output_programs::Program>(ref program.output)!=1){return .err(error(7));}
        diagnostic=output_programs::runtime_diagnostic(vec::at<output_programs::Program>(ref program.output,0),stop.failure);
    }
    return .ok(Event{.kind=if(stop.cancelled){3}else{2},.value=0,
        .diagnostic=diagnostic,.remaining=stop.remaining,.fuel_known=true});
}

// Quarantine nonterminal children. Destroy reclaims their owned storage
// directly, without resuming guest work or trusting the failed cleanup plan.
fn void poison_children(ref mut Meta m,ref vec::Vec<Program> programs,ref mut vec::Vec<Instance> instances,
    ref vec::Vec<Output> outputs){
    m.poisoned=true;
    var usize i=0;
    while(i<vec::len<Instance>(instances)){
        let ref mut Instance child=vec::at_mut<Instance>(instances,i);
        if(child.phase!=2 && child.phase!=5){
            let Event terminal=poison_event(programs,child,outputs);
            child.event=terminal;
            child.phase=5;
        }
        i+=1;
    }
}
fn Event poison_event(ref vec::Vec<Program> programs,ref Instance child,ref vec::Vec<Output> outputs){
    if(child.phase==3){
        switch(output_index(outputs,child.id)){
            case .ok(i):{
                let ref Output output=vec::at<Output>(outputs,i);
                if(vec::len<machines::Machine>(ref output.pending)==1){
                    switch(machines::stopping(vec::at<machines::Machine>(ref output.pending,0))){
                        case .some(stop):{
                            switch(stopping_event(programs,child,stop)){
                                case .ok(event):{return event;}
                                case .err(_):{}
                            };
                        }
                        case .none:{}
                    };
                }
            }
            case .err(_):{}
        };
    }
    return Event{.kind=2,.value=0,.diagnostic=diagnostics::absent(errors::absent(errors::engine_poisoned_kind(),0)),
        .remaining=child.event.remaining,.fuel_known=child.event.fuel_known};
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
    if(m.active!=0){return 3;}if(m.closed){return failed(m,2);}
    if(m.poisoned){return failed(m,14);}if(m.admission==0){return failed(m,8);}
    m.active=m.admission;m.admission=if(m.admission==18446744073709551615){0}else{m.admission+1};return 0;
}
fn u32 end_inner(ref mut Meta m,usize thread,usize lifetime,usize epoch){
    if(m.thread!=thread || m.lifetime!=lifetime || thread==0 || lifetime==0){return 10;}
    if(epoch==0 || m.active!=epoch){return 7;}m.active=0;return 0;
}
fn usize program_variants(ref Program program){
    return vec::len<host_program::Program>(ref program.host)+vec::len<programs::Program>(ref program.code)+
        vec::len<input_programs::Program>(ref program.input)+vec::len<output_programs::Program>(ref program.output);
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
    if(m.closed){return 2;}if(m.poisoned){return 14;}
    if(mode==0 && m.programs.compile_source!=0){return 3;}
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
fn bool payload_ledger_intact(ref Meta m){
    return m.heap.current==m.programs.external && !m.programs.closed &&
        m.programs.control<=m.programs.engine &&
        m.programs.retained<=m.programs.engine-m.programs.control &&
        m.programs.external<=m.programs.engine-m.programs.control-m.programs.retained &&
        m.programs.compile_source<=m.programs.engine-m.programs.control-m.programs.retained-m.programs.external &&
        live::prepare(ref m.heap,0,0,0).is_ok;
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
fn bool input_admission_intact(ref Meta m,ref vec::Vec<Instance> v,ref vec::Vec<BoundInput> inputs,bool bound){
    if(vec::len<Instance>(v)>=vec::capacity<Instance>(v) || !payload_ledger_intact(m)){return false;}
    return !bound || (vec::len<BoundInput>(inputs)<vec::capacity<BoundInput>(inputs) &&
        vec::len<BoundInput>(inputs)<=vec::len<Instance>(v));
}
fn u32 input_preflight_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    usize code,usize budget,ref input_bytes::Snapshot input,u32 output,usize limit,u32 allowed,usize width,
    ref vec::Vec<BoundInput> inputs,ref vec::Vec<Output> outputs){
    if(m.closed){return 2;}if(m.poisoned){return 14;}if(m.admission==0){return 8;}
    if(output>1 || limit>1048576 || allowed>3){return 1;}
    if(m.configured!=(allowed>=2) || (output==0 && m.configured) || budget>m.limits.fuel){return 5;}
    let usize pi=switch(program_index(p,code,true)){case .ok(index):{index}case .err(status):{return status;}};
    let ref Program program=vec::at<Program>(p,pi);
    if(program_variants(program)!=1){return contain_execution_fault(m,p,v,outputs);}
    if(output==0){if(vec::len<input_programs::Program>(ref program.input)!=1){return 1;}}
    else{
        if(vec::len<output_programs::Program>(ref program.output)!=1){return 1;}
        if(!output_programs::accepts_input(vec::at<output_programs::Program>(ref program.output,0))){return 1;}
    }
    if(vec::len<Instance>(v)>=m.limits.instances || m.next==0){return 8;}
    if(width==0 || width>18446744073709551615/8 || !input_admission_intact(m,v,inputs,true)){
        return contain_execution_fault(m,p,v,outputs);
    }
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
fn u32 compile_inner(ref mut Meta m,ref mut vec::Vec<Program> v,ref mut vec::Vec<entries::Entry> incoming,usize image_limit,usize deadline){
    if(clock::expired(deadline)){return compile_timed_out(m);}
    if(m.programs.compile_source!=0){return failed(m,3);}
    if(vec::len<Program>(v)>=m.limits.programs || m.next==0){return failed(m,8);}
    if(vec::len<entries::Entry>(incoming)!=1){return failed(m,1);}
    var retention::Plan plan=switch(retention_plan(m,0)){case .ok(p):{p}case .err(s):{return failed(m,s);}};
    let usize incoming_bytes=unsafe{compile_fact_raw(incoming as ptr void,0,2)};
    let usize index_bytes=entry_heap(vec::at<entries::Entry>(incoming,0));
    var compilation::Plan work=switch(compile_work(m,incoming_bytes,index_bytes)){case .ok(p):{p}case .err(status):{return failed(m,status);}};
    let usize source_bytes=incoming_bytes+index_bytes;
    assert(memory::hold_compile_source(ref mut m.programs,source_bytes).is_ok);
    let Result<programs::Program,diagnostics::Error> built=bounded::compile_until(pop_entry(incoming),image_limit,ref mut plan,ref mut work,deadline);
    assert(memory::release_compile_source(ref mut m.programs,source_bytes).is_ok);
    assert(memory::record_compile(ref mut m.programs,ref work).is_ok);
    assert(memory::record(ref mut m.programs,ref plan).is_ok);
    return switch(built){case .ok(code):{publish_program(m,v,code,plan.bytes,deadline)}case .err(e):{compile_error(m,e)}};
}
fn void finish_compile_source(ref mut Meta m,ref mut CompileWork job,ref mut vec::Vec<entries::Entry> selected,
    ref mut vec::Vec<programs::Lowered> candidate){
    unsafe{dispose_compile_candidate_raw(candidate as ptr mut void)};
    assert(vec::clear<entries::Entry>(selected)==1);
    assert(memory::release_compile_source(ref mut m.programs,job.source_bytes).is_ok);
    job.source_bytes=0;
}
fn u32 stop_compile(ref mut Meta m,ref mut CompileWork job,ref mut vec::Vec<entries::Entry> selected,
    ref mut vec::Vec<programs::Lowered> candidate,Error failure){
    finish_compile_source(m,job,selected,candidate);
    job.state=4;
    job.failure=failure;
    return 0;
}
fn u32 allocate_compile_candidate(ref mut Meta m,ref mut CompileWork job,usize selected,bool references,
    ref mut vec::Vec<programs::Lowered> candidate){
    let usize bytes=unsafe{compile_candidate_width_raw()};
    if(bytes==0){return 7;}
    if(!memory::prepare_compile(ref mut m.programs,bytes).is_ok){return 8;}
    if(!programs::start_lowered(candidate,selected,references).is_ok){return 6;}
    assert(vec::capacity<programs::Lowered>(candidate)==1);
    assert(memory::hold_compile_candidate(ref mut m.programs,bytes).is_ok);
    job.source_bytes+=bytes;
    return 0;
}
fn u32 advance_compile_literals_inner(ref mut Meta m,ref modules::Index index,ref source_work::State source,
    ref mut literal_work::State literals,ref mut images::Builder builder,ref mut signature_scan::State signatures,
    ref mut metadata_budget::State meter,bool collecting){
    return switch(if(collecting){compiler::advance_module_literals(index,source,builder,literals,meter)}
        else{compiler::advance_module_signatures(index,source,signatures,meter)}){
        case .ok(_):{0}case .err(e):{compile_error(m,e)}
    };
}
fn u32 lower_compile_metadata(ref mut Meta m,ref mut CompileWork job,ref modules::Index index,
    usize selected,bool references,ref mut vec::Vec<programs::Lowered> candidate){
    if(vec::len<programs::Lowered>(candidate)==0){
        let u32 status=allocate_compile_candidate(m,job,selected,references,candidate);
        if(status!=0){return failed(m,status);}
    }
    let ref mut programs::Lowered lowered=vec::at_mut<programs::Lowered>(candidate,0);
    let bool collecting_literals=references && !job.literals.done;
    if(!collecting_literals && programs::signatures_done(lowered)){
        job.state=6;
        return 0;
    }
    var metadata_budget::State meter=metadata_budget::empty();
    let u32 status=unsafe{advance_compile_literals_raw(m as ptr mut void,index as ptr void,
        job as ptr mut void,lowered as ptr mut void,ref mut meter as ptr mut void,if(collecting_literals){1}else{0})};
    job.batches+=meter.stages;
    if(status!=0){return status;}
    if(clock::expired(job.deadline)){return compile_timed_out(m);}
    return 0;
}
fn u32 advance_compile_body_inner(ref mut Meta m,ref modules::Index index,ref source_work::State source,
    bool references,bool output,ref literal_work::State literals,ref mut signature_scan::State signatures,ref mut compile_ir::Program code,
    ref mut compiler::BodyProgress progress,ref mut lexer::State token,ref mut locals::Table names,
    ref mut loops::State flow,ref mut body_work::State cursor,ref mut metadata_budget::State meter,usize deadline){
    let Result<bool,diagnostics::Error> step=compiler::advance_module_bodies(index,source,references,output,literals,
        signatures,code,progress,token,names,flow,cursor,meter,deadline);
    return switch(step){case .ok(complete):{if(complete){1}else{0}}case .err(e):{compile_error(m,e)}};
}
fn u32 step_compile_body(ref mut Meta m,ref mut CompileWork job,ref modules::Index index,
    ref mut vec::Vec<programs::Lowered> candidate){
    let ref mut programs::Lowered lowered=vec::at_mut<programs::Lowered>(candidate,0);
    var metadata_budget::State meter=metadata_budget::empty();
    let usize deadline=job.deadline;
    let u32 status=unsafe{advance_compile_body_raw(m as ptr mut void,index as ptr void,
        job as ptr void,lowered as ptr mut void,ref mut meter as ptr mut void,deadline)};
    job.batches+=meter.stages;
    if(status>1){return status;}
    if(clock::expired(deadline)){return compile_timed_out(m);}
    if(status==1){job.state=2;}
    return 0;
}
fn bool compile_terminal(u8 phase){return phase>=3 && phase<=5;}
fn u32 begin_pending_proof(ref mut Meta m,ref mut CompileWork job,ref mut vec::Vec<entries::Entry> selected,
    ref mut vec::Vec<programs::Lowered> candidate){
    let ref modules::Index index=entries::index(vec::at<entries::Entry>(selected,0));
    let u32 status=begin_compile_proof(m,job,index,candidate);
    if(status!=0){let Error cause=m.error;return stop_compile(m,job,selected,candidate,cause);}
    return 0;
}
fn u32 begin_compile_proof(ref mut Meta m,ref mut CompileWork job,ref modules::Index index,
    ref mut vec::Vec<programs::Lowered> candidate){
    let ref mut programs::Lowered lowered=vec::at_mut<programs::Lowered>(candidate,0);
    let usize payload=switch(programs::proof_payload(lowered)){
        case .ok(v):{v}case .err(e):{return compile_error(m,e);}
    };
    var retention::Plan retained=switch(retention_plan(m,if(job.output_mode!=0){2}else if(job.input){1}else{0})){
        case .ok(v):{v}case .err(status):{return failed(m,status);}
    };
    if(!retention::admit(ref mut retained,payload).is_ok){return failed(m,8);}
    let usize storage=if(job.output_mode!=0){output_programs::proof_storage_bytes(lowered)}else{programs::proof_storage_bytes(lowered)};
    if(storage==0 || payload>18446744073709551615-storage){return failed(m,7);}
    let usize bytes=payload+storage;
    var memory::Budget charged=m.programs;
    if(!memory::hold_compile_candidate(ref mut charged,bytes).is_ok){return failed(m,8);}
    let Result<usize,diagnostics::Error> opened=if(job.output_mode!=0){output_programs::begin_proof(lowered,job.image_limit,job.input)}
        else{programs::begin_proof(index,lowered,job.image_limit,job.deadline,job.input)};
    switch(opened){
        case .ok(_):{}case .err(e):{return compile_error(m,e);}
    };
    m.programs=charged;
    job.source_bytes+=bytes;
    if(clock::expired(job.deadline)){return compile_timed_out(m);}
    job.state=7;
    return 0;
}
fn u32 step_pending_proof(ref mut Meta m,ref mut CompileWork job,ref mut vec::Vec<entries::Entry> selected,
    ref mut vec::Vec<programs::Lowered> candidate){
    let ref modules::Index index=entries::index(vec::at<entries::Entry>(selected,0));
    let u32 status=step_compile_proof(m,job,index,candidate);
    if(status!=0){let Error cause=m.error;return stop_compile(m,job,selected,candidate,cause);}
    return 0;
}
fn u32 step_compile_proof(ref mut Meta m,ref mut CompileWork job,ref modules::Index index,
    ref mut vec::Vec<programs::Lowered> candidate){
    var metadata_budget::State meter=metadata_budget::empty();
    let ref mut programs::Lowered lowered=vec::at_mut<programs::Lowered>(candidate,0);
    let Result<bool,diagnostics::Error> advanced=if(job.output_mode!=0){output_programs::advance_proof(
        modules::snapshot(index),lowered,ref mut meter)}else{programs::advance_proof(index,lowered,ref mut meter)};
    job.batches+=meter.stages;
    switch(advanced){
        case .ok(done):{if(done){job.state=8;}}
        case .err(e):{return compile_error(m,e);}
    };
    if(clock::expired(job.deadline)){return compile_timed_out(m);}
    return 0;
}
fn u32 finish_pending_compile(ref mut Meta m,ref mut vec::Vec<Program> programs,ref mut CompileWork job,
    ref mut vec::Vec<entries::Entry> selected,ref mut vec::Vec<programs::Lowered> candidate){
    if(vec::len<Program>(programs)>=m.limits.programs || m.next==0){return stop_compile(m,job,selected,candidate,error(8));}
    let ref mut programs::Lowered lowered=vec::at_mut<programs::Lowered>(candidate,0);
    let usize payload=switch(programs::proof_payload(lowered)){
        case .ok(v):{v}case .err(e):{let u32 status=compile_error(m,e);let Error cause=m.error;return stop_compile(m,job,selected,candidate,cause);}
    };
    var retention::Plan retained=switch(memory::prepare_transfer(ref m.programs,0,payload)){
        case .ok(v):{v}case .err(_):{return stop_compile(m,job,selected,candidate,error(8));}
    };
    if(!retention::admit(ref mut retained,payload).is_ok){return stop_compile(m,job,selected,candidate,error(8));}
    var vec::Vec<programs::Program> code=vec::empty<programs::Program>();
    let Result<usize,diagnostics::Error> built=programs::finish_proof(
        vec::at<entries::Entry>(selected,0),lowered,ref mut code);
    assert(memory::record_transfer(ref mut m.programs,ref retained,payload).is_ok);
    finish_compile_source(m,job,selected,candidate);
    switch(built){
        case .ok(_):{}
        case .err(failure):{discard compile_error(m,failure);job.state=4;job.failure=m.error;return 0;}
    };
    let u32 status=publish_program_storage(m,programs,code,retained.bytes,job.deadline);
    if(status==0){job.state=3;job.program=m.result;}
    else{job.state=4;job.failure=m.error;}
    return 0;
}
fn u32 finish_pending_output_compile(ref mut Meta m,ref mut vec::Vec<Program> programs,ref mut CompileWork job,
    ref mut vec::Vec<entries::Entry> selected,ref mut vec::Vec<programs::Lowered> candidate){
    if(vec::len<Program>(programs)>=m.limits.programs || m.next==0){return stop_compile(m,job,selected,candidate,error(8));}
    let ref sources::Snapshot snapshot=modules::snapshot(entries::index(vec::at<entries::Entry>(selected,0)));
    var vec::Vec<output_programs::Program> code=vec::empty<output_programs::Program>();
    let usize bytes=switch(retain_pending_output(m,snapshot,candidate,job.deadline,ref mut code)){
        case .ok(v):{v}case .err(cause):{return stop_compile(m,job,selected,candidate,cause);}
    };
    finish_compile_source(m,job,selected,candidate);
    return publish_pending_output(m,programs,job,code,bytes,empty_entry());
}
fn Result<usize,Error> retain_pending_output(ref mut Meta m,ref sources::Snapshot snapshot,
    ref mut vec::Vec<programs::Lowered> candidate,usize deadline,ref mut vec::Vec<output_programs::Program> code){
    let ref mut programs::Lowered lowered=vec::at_mut<programs::Lowered>(candidate,0);
    let usize payload=switch(programs::proof_payload(lowered)){
        case .ok(v):{v}case .err(e):{discard compile_error(m,e);return .err(m.error);}
    };
    var retention::Plan plan=switch(memory::prepare_transfer(ref m.programs,2,payload)){
        case .ok(v):{v}case .err(_):{return .err(error(8));}
    };
    if(!retention::admit(ref mut plan,payload).is_ok){return .err(error(8));}
    let Result<usize,diagnostics::Error> built=output_programs::finish_proof(snapshot,lowered,deadline,code);
    assert(memory::record_transfer(ref mut m.programs,ref plan,payload).is_ok);
    return switch(built){
        case .ok(_):{.ok(plan.bytes)}case .err(e):{discard compile_error(m,e);.err(m.error)}
    };
}
fn u32 publish_pending_output(ref mut Meta m,ref mut vec::Vec<Program> programs,ref mut CompileWork job,
    vec::Vec<output_programs::Program> code,usize bytes,EntryBinding selected){
    let EntryBinding entry=switch(bind_output_authority(vec::at<output_programs::Program>(ref code,0),selected,job.output_mode)){
        case .ok(v):{v}case .err(status):{job.state=4;job.failure=error(status);return 0;}
    };
    let u32 status=publish_output_program_storage(m,programs,code,bytes,entry,job.deadline);
    if(status==0){job.state=3;job.program=m.result;}
    else{job.state=4;job.failure=m.error;}
    return 0;
}
fn u32 step_compile_inner(ref mut Meta m,ref mut vec::Vec<Program> programs,ref mut vec::Vec<CompileWork> jobs,
    ref mut vec::Vec<entries::Entry> selected,ref mut vec::Vec<programs::Lowered> candidate,usize id){
    if(vec::len<CompileWork>(jobs)!=1){return 7;}
    let ref mut CompileWork job=vec::at_mut<CompileWork>(jobs,0);
    if(id==0 || job.id!=id){return 2;}
    if(compile_terminal(job.state)){return 0;}
    if(clock::expired(job.deadline)){return stop_compile(m,job,selected,candidate,compile_timeout());}
    if(job.state==2){return begin_pending_proof(m,job,selected,candidate);}
    if(job.state==7){return step_pending_proof(m,job,selected,candidate);}
    if(job.state==8){
        if(job.output_mode!=0){return finish_pending_output_compile(m,programs,job,selected,candidate);}
        return finish_pending_compile(m,programs,job,selected,candidate);
    }
    let ref entries::Entry entry=vec::at<entries::Entry>(selected,0);
    let ref modules::Index index=entries::index(entry);
    let bool references=job.output_mode!=0 || job.source.syntax.result;
    let u32 status=if(job.state==1){lower_compile_metadata(m,job,index,entries::selected(entry),references,candidate)}
        else if(job.state==6){step_compile_body(m,job,index,candidate)}
        else{step_compile_source(m,job,index)};
    if(status!=0){let Error cause=m.error;return stop_compile(m,job,selected,candidate,cause);}
    return 0;
}
fn u32 step_compile_source(ref mut Meta m,ref mut CompileWork job,ref modules::Index index){
    var metadata_budget::State meter=metadata_budget::empty();
    let bool ready=switch(source_work::advance(index,ref mut job.source,ref mut meter)){
        case .ok(v):{v}case .err(e):{return compile_error(m,e);}
    };
    job.batches+=meter.stages;
    if(clock::expired(job.deadline)){return compile_timed_out(m);}
    if(ready){job.state=1;}
    return 0;
}
fn u32 begin_compile_inner(ref mut Meta m,ref mut vec::Vec<CompileWork> jobs,ref mut vec::Vec<entries::Entry> selected,
    ref mut vec::Vec<entries::Entry> incoming,usize image_limit,usize deadline,bool output){
    if(vec::len<CompileWork>(jobs)!=1){return failed(m,7);}
    let ref mut CompileWork job=vec::at_mut<CompileWork>(jobs,0);
    if(job.id!=0){return failed(m,3);}
    if(job.next==0){return failed(m,8);}
    if(clock::expired(deadline)){return compile_timed_out(m);}
    if(vec::len<entries::Entry>(incoming)!=1 || vec::len<entries::Entry>(selected)!=0){return failed(m,7);}
    let usize charge=entry_heap(vec::at<entries::Entry>(incoming,0));
    if(!memory::hold_compile_source(ref mut m.programs,charge).is_ok){return failed(m,8);}
    if(!vec::push<entries::Entry>(selected,pop_entry(incoming)).is_ok){
        assert(memory::release_compile_source(ref mut m.programs,charge).is_ok);
        return failed(m,6);
    }
    job.output_mode=if(output){1}else{0};
    return start_compile_job(m,job,charge,image_limit,deadline);
}
fn u32 start_compile_job(ref mut Meta m,ref mut CompileWork job,usize charge,usize image_limit,usize deadline){
    job.id=job.next;
    job.next=if(job.id==18446744073709551615){0}else{job.id+1};
    job.deadline=deadline;
    job.image_limit=image_limit;
    job.source_bytes=charge;
    return success(m,job.id);
}
fn u32 begin_compile_input_inner(ref mut Meta m,ref mut vec::Vec<CompileWork> jobs,
    ref mut vec::Vec<input_entries::InputEntry> selected,ref mut vec::Vec<input_entries::InputEntry> incoming,
    usize image_limit,usize deadline,u32 mode){
    if(mode>3 || (mode>1 && !m.configured)){return failed(m,5);}
    if(vec::len<CompileWork>(jobs)!=1){return failed(m,7);}
    let ref mut CompileWork job=vec::at_mut<CompileWork>(jobs,0);
    if(job.id!=0){return failed(m,3);}
    if(job.next==0){return failed(m,8);}
    if(clock::expired(deadline)){return compile_timed_out(m);}
    if(vec::len<input_entries::InputEntry>(incoming)!=1 || vec::len<input_entries::InputEntry>(selected)!=0){return failed(m,7);}
    let usize charge=input_entry_heap(vec::at<input_entries::InputEntry>(incoming,0));
    if(!memory::hold_compile_source(ref mut m.programs,charge).is_ok){return failed(m,8);}
    if(!vec::push<input_entries::InputEntry>(selected,pop_input_entry(incoming)).is_ok){
        assert(memory::release_compile_source(ref mut m.programs,charge).is_ok);
        return failed(m,6);
    }
    job.input=true;
    job.output_mode=mode;
    job.source.classify=false;
    return start_compile_job(m,job,charge,image_limit,deadline);
}
fn void finish_compile_input_source(ref mut Meta m,ref mut CompileWork job,
    ref mut vec::Vec<input_entries::InputEntry> selected,ref mut vec::Vec<programs::Lowered> candidate){
    unsafe{dispose_compile_candidate_raw(candidate as ptr mut void)};
    assert(vec::clear<input_entries::InputEntry>(selected)==1);
    assert(memory::release_compile_source(ref mut m.programs,job.source_bytes).is_ok);
    job.source_bytes=0;
}
fn u32 stop_compile_input(ref mut Meta m,ref mut CompileWork job,ref mut vec::Vec<input_entries::InputEntry> selected,ref mut vec::Vec<programs::Lowered> candidate,Error cause){
    finish_compile_input_source(m,job,selected,candidate);
    job.state=4;job.failure=cause;
    return 0;
}
fn u32 step_compile_input_inner(ref mut Meta m,ref mut vec::Vec<Program> programs,ref mut vec::Vec<CompileWork> jobs,
    ref mut vec::Vec<input_entries::InputEntry> selected,ref mut vec::Vec<programs::Lowered> candidate,usize id){
    if(vec::len<CompileWork>(jobs)!=1){return 7;}
    let ref mut CompileWork job=vec::at_mut<CompileWork>(jobs,0);
    if(id==0 || job.id!=id){return 2;}
    if(compile_terminal(job.state)){return 0;}
    if(clock::expired(job.deadline)){return stop_compile_input(m,job,selected,candidate,compile_timeout());}
    if(job.state==8){
        if(job.output_mode!=0){return finish_pending_input_output_compile(m,programs,job,selected,candidate);}
        return finish_pending_input_compile(m,programs,job,selected,candidate);
    }
    let ref input_entries::InputEntry entry=vec::at<input_entries::InputEntry>(selected,0);
    let ref modules::Index index=input_entries::index(entry);
    let u32 status=if(job.state==2){begin_compile_proof(m,job,index,candidate)}
        else if(job.state==7){step_compile_proof(m,job,index,candidate)}
        else if(job.state==1){lower_compile_metadata(m,job,index,input_entries::selected(entry),true,candidate)}
        else if(job.state==6){step_compile_body(m,job,index,candidate)}
        else{step_compile_source(m,job,index)};
    if(status!=0){let Error cause=m.error;return stop_compile_input(m,job,selected,candidate,cause);}
    return 0;
}
fn u32 finish_pending_input_output_compile(ref mut Meta m,ref mut vec::Vec<Program> programs,ref mut CompileWork job,
    ref mut vec::Vec<input_entries::InputEntry> selected,ref mut vec::Vec<programs::Lowered> candidate){
    if(vec::len<Program>(programs)>=m.limits.programs || m.next==0){
        return stop_compile_input(m,job,selected,candidate,error(8));
    }
    let ref input_entries::InputEntry source=vec::at<input_entries::InputEntry>(selected,0);
    let EntryBinding entry=switch(bind_entry(m.configured,source)){
        case .ok(v):{v}case .err(status):{return stop_compile_input(m,job,selected,candidate,error(status));}
    };
    let ref sources::Snapshot snapshot=modules::snapshot(input_entries::index(source));
    var vec::Vec<output_programs::Program> code=vec::empty<output_programs::Program>();
    let usize bytes=switch(retain_pending_output(m,snapshot,candidate,job.deadline,ref mut code)){
        case .ok(v):{v}case .err(cause):{return stop_compile_input(m,job,selected,candidate,cause);}
    };
    finish_compile_input_source(m,job,selected,candidate);
    return publish_pending_output(m,programs,job,code,bytes,entry);
}
fn u32 finish_pending_input_compile(ref mut Meta m,ref mut vec::Vec<Program> programs,ref mut CompileWork job,
    ref mut vec::Vec<input_entries::InputEntry> selected,ref mut vec::Vec<programs::Lowered> candidate){
    if(vec::len<Program>(programs)>=m.limits.programs || m.next==0){
        return stop_compile_input(m,job,selected,candidate,error(8));
    }
    let ref mut programs::Lowered lowered=vec::at_mut<programs::Lowered>(candidate,0);
    let usize payload=switch(programs::proof_payload(lowered)){
        case .ok(v):{v}
        case .err(e):{discard compile_error(m,e);let Error cause=m.error;return stop_compile_input(m,job,selected,candidate,cause);}
    };
    var retention::Plan plan=switch(memory::prepare_transfer(ref m.programs,1,payload)){
        case .ok(p):{p}case .err(_):{return stop_compile_input(m,job,selected,candidate,error(8));}
    };
    if(!retention::admit(ref mut plan,payload).is_ok){return stop_compile_input(m,job,selected,candidate,error(8));}
    var vec::Vec<input_programs::Program> code=vec::empty<input_programs::Program>();
    let Result<usize,diagnostics::Error> built=input_programs::finish_proof(
        vec::at<input_entries::InputEntry>(selected,0),lowered,ref mut code);
    assert(memory::record_transfer(ref mut m.programs,ref plan,payload).is_ok);
    finish_compile_input_source(m,job,selected,candidate);
    switch(built){
        case .ok(_):{}
        case .err(e):{discard compile_error(m,e);job.state=4;job.failure=m.error;return 0;}
    };
    let u32 status=publish_input_program_storage(m,programs,code,plan.bytes,job.deadline);
    if(status==0){job.state=3;job.program=m.result;}
    else{job.state=4;job.failure=m.error;}
    return 0;
}
fn u32 end_compile_input_inner(ref mut Meta m,ref mut vec::Vec<CompileWork> jobs,
    ref mut vec::Vec<input_entries::InputEntry> selected,ref mut vec::Vec<programs::Lowered> candidate,usize id,bool detach){
    if(m.closed || id==0){return 2;}
    if(vec::len<CompileWork>(jobs)!=1){return 7;}
    let ref mut CompileWork job=vec::at_mut<CompileWork>(jobs,0);
    if(id!=job.id){return 2;}
    if(detach){return detach_compile_job(job);}
    if(compile_terminal(job.state)){return 0;}
    if(m.poisoned){return stop_compile_input(m,job,selected,candidate,error(14));}
    if(clock::expired(job.deadline)){return stop_compile_input(m,job,selected,candidate,compile_timeout());}
    finish_compile_input_source(m,job,selected,candidate);
    job.state=5;
    return 0;
}
fn vec::Vec<input_entries::InputEntry> reset_compile_input_storage(vec::Vec<input_entries::InputEntry> entry){
    assert(vec::len<input_entries::InputEntry>(ref entry)==0);
    return vec::empty<input_entries::InputEntry>();
}
fn u32 end_compile_inner(ref mut Meta m,ref mut vec::Vec<CompileWork> jobs,ref mut vec::Vec<entries::Entry> selected,
    ref mut vec::Vec<programs::Lowered> candidate,usize id,bool detach){
    if(m.closed || id==0){return 2;}
    if(vec::len<CompileWork>(jobs)!=1){return 7;}
    let ref mut CompileWork job=vec::at_mut<CompileWork>(jobs,0);
    if(id!=job.id){return 2;}
    if(detach){return detach_compile_job(job);}
    if(compile_terminal(job.state)){return 0;}
    if(m.poisoned){return stop_compile(m,job,selected,candidate,error(14));}
    if(clock::expired(job.deadline)){return stop_compile(m,job,selected,candidate,compile_timeout());}
    finish_compile_source(m,job,selected,candidate);
    job.state=5;
    return 0;
}
fn vec::Vec<entries::Entry> reset_compile_storage(vec::Vec<entries::Entry> entry){
    assert(vec::len<entries::Entry>(ref entry)==0);
    return vec::empty<entries::Entry>();
}
fn u32 detach_compile_job(ref mut CompileWork job){
    if(!compile_terminal(job.state)){return 3;}
    let CompileWork cleared=empty_compile(job.next);
    *job=cleared;
    return 0;
}
fn vec::Vec<CompileWork> reset_compile_work(vec::Vec<CompileWork> work){return vec::empty<CompileWork>();}
fn vec::Vec<programs::Lowered> reset_compile_candidate(vec::Vec<programs::Lowered> work){return vec::empty<programs::Lowered>();}
fn entries::Entry pop_entry(ref mut vec::Vec<entries::Entry> v){return switch(vec::pop<entries::Entry>(v)){
    case .some(e):{e}case .none:{assert(false);pop_entry(v)}
};}
fn u32 publish_program(ref mut Meta m,ref mut vec::Vec<Program> v,programs::Program code,usize bytes,usize deadline){
    var vec::Vec<programs::Program> retained=vec::empty<programs::Program>();
    if(!vec::reserve<programs::Program>(ref mut retained,1).is_ok){return failed(m,6);}
    if(!vec::push<programs::Program>(ref mut retained,code).is_ok){return failed(m,6);}
    return publish_program_storage(m,v,retained,bytes,deadline);
}
fn u32 publish_program_storage(ref mut Meta m,ref mut vec::Vec<Program> v,
    vec::Vec<programs::Program> retained,usize bytes,usize deadline){
    let ref programs::Program code=vec::at<programs::Program>(ref retained,0);
    let execution_heap::Plan heap=switch(execution_heap::prepare_until(programs::body(code),false,false,0,deadline)){
        case .ok(v):{v}case .err(e):{
            if(e.kind==errors::deadline_kind()){return compile_timed_out(m);}
            return failed(m,7);
        }
    };
    let usize id=m.next;
    if(clock::expired(deadline)){return compile_timed_out(m);}
    if(!vec::push<Program>(v,Program{.id=id,.pins=0,.released=false,.code=retained,.input=vec::empty<input_programs::Program>(),.output=vec::empty<output_programs::Program>(),.bytes=bytes,.execution_scratch=heap.scratch,.entry=empty_entry(),.host=vec::empty<host_program::Program>()}).is_ok){return failed(m,6);}
    assert(memory::publish(ref mut m.programs,bytes).is_ok);advance(m);return success(m,id);
}
fn input_entries::InputEntry pop_input_entry(ref mut vec::Vec<input_entries::InputEntry> v){return switch(vec::pop<input_entries::InputEntry>(v)){
    case .some(e):{e}case .none:{assert(false);pop_input_entry(v)}
};}
fn u32 compile_input_inner(ref mut Meta m,ref mut vec::Vec<Program> v,ref mut vec::Vec<input_entries::InputEntry> incoming,usize image_limit,usize deadline){
    if(clock::expired(deadline)){return compile_timed_out(m);}
    if(vec::len<Program>(v)>=m.limits.programs || m.next==0){return failed(m,8);}
    if(vec::len<input_entries::InputEntry>(incoming)!=1){return failed(m,1);}
    var retention::Plan plan=switch(retention_plan(m,1)){case .ok(p):{p}case .err(s):{return failed(m,s);}};
    var compilation::Plan work=switch(compile_work(m,unsafe{compile_fact_raw(incoming as ptr void,1,2)},input_entry_heap(vec::at<input_entries::InputEntry>(incoming,0)))){case .ok(p):{p}case .err(status):{return failed(m,status);}};
    let Result<input_programs::Program,diagnostics::Error> built=bounded::compile_input_until(pop_input_entry(incoming),image_limit,ref mut plan,ref mut work,deadline);
    assert(memory::record_compile(ref mut m.programs,ref work).is_ok);
    assert(memory::record(ref mut m.programs,ref plan).is_ok);
    return switch(built){case .ok(code):{publish_input_program(m,v,code,plan.bytes,deadline)}case .err(e):{compile_error(m,e)}};
}
fn u32 publish_input_program(ref mut Meta m,ref mut vec::Vec<Program> v,input_programs::Program code,usize bytes,usize deadline){
    var vec::Vec<input_programs::Program> retained=vec::empty<input_programs::Program>();
    if(!vec::reserve<input_programs::Program>(ref mut retained,1).is_ok){return failed(m,6);}
    if(!vec::push<input_programs::Program>(ref mut retained,code).is_ok){return failed(m,6);}
    return publish_input_program_storage(m,v,retained,bytes,deadline);
}
fn u32 publish_input_program_storage(ref mut Meta m,ref mut vec::Vec<Program> v,
    vec::Vec<input_programs::Program> retained,usize bytes,usize deadline){
    let ref input_programs::Program code=vec::at<input_programs::Program>(ref retained,0);
    let execution_heap::Plan heap=switch(execution_heap::prepare_until(ref input_programs::code(code).body,true,false,0,deadline)){
        case .ok(v):{v}case .err(e):{
            if(e.kind==errors::deadline_kind()){return compile_timed_out(m);}
            return failed(m,7);
        }
    };
    let usize id=m.next;
    if(clock::expired(deadline)){return compile_timed_out(m);}
    if(!vec::push<Program>(v,Program{.id=id,.pins=0,.released=false,.code=vec::empty<programs::Program>(),.input=retained,.output=vec::empty<output_programs::Program>(),.bytes=bytes,.execution_scratch=heap.scratch,.entry=empty_entry(),.host=vec::empty<host_program::Program>()}).is_ok){return failed(m,6);}
    assert(memory::publish(ref mut m.programs,bytes).is_ok);advance(m);return success(m,id);
}
fn u32 compile_output_inner(ref mut Meta m,ref mut vec::Vec<Program> v,ref mut vec::Vec<entries::Entry> incoming,usize limit,usize deadline){
    if(clock::expired(deadline)){return compile_timed_out(m);}
    if(vec::len<Program>(v)>=m.limits.programs || m.next==0){return failed(m,8);}
    if(vec::len<entries::Entry>(incoming)!=1){return failed(m,1);}
    var retention::Plan plan=switch(retention_plan(m,2)){case .ok(p):{p}case .err(s):{return failed(m,s);}};
    var compilation::Plan work=switch(compile_work(m,unsafe{compile_fact_raw(incoming as ptr void,0,2)},entry_heap(vec::at<entries::Entry>(incoming,0)))){case .ok(p):{p}case .err(status):{return failed(m,status);}};
    let Result<output_programs::Program,diagnostics::Error> built=bounded::compile_output_until(pop_entry(incoming),limit,ref mut plan,ref mut work,deadline);
    assert(memory::record_compile(ref mut m.programs,ref work).is_ok);
    assert(memory::record(ref mut m.programs,ref plan).is_ok);
    return switch(built){case .ok(code):{publish_output_program(m,v,code,plan.bytes,empty_entry(),0,deadline)}case .err(e):{compile_error(m,e)}};
}
fn u32 compile_input_output_inner(ref mut Meta m,ref mut vec::Vec<Program> v,ref mut vec::Vec<input_entries::InputEntry> incoming,usize limit,u32 mode,usize deadline){
    if(clock::expired(deadline)){return compile_timed_out(m);}
    if(mode>1 && !m.configured){return failed(m,5);}
    if(vec::len<Program>(v)>=m.limits.programs || m.next==0){return failed(m,8);}
    if(vec::len<input_entries::InputEntry>(incoming)!=1){return failed(m,1);}
    var retention::Plan plan=switch(retention_plan(m,2)){case .ok(p):{p}case .err(s):{return failed(m,s);}};
    var compilation::Plan work=switch(compile_work(m,unsafe{compile_fact_raw(incoming as ptr void,1,2)},input_entry_heap(vec::at<input_entries::InputEntry>(incoming,0)))){case .ok(p):{p}case .err(status):{return failed(m,status);}};
    let EntryBinding entry=switch(bind_entry(m.configured,vec::at<input_entries::InputEntry>(incoming,0))){
        case .ok(v):{v}case .err(status):{return failed(m,status);}
    };
    let Result<output_programs::Program,diagnostics::Error> built=bounded::compile_input_output_until(pop_input_entry(incoming),limit,ref mut plan,ref mut work,deadline);
    assert(memory::record_compile(ref mut m.programs,ref work).is_ok);
    assert(memory::record(ref mut m.programs,ref plan).is_ok);
    return switch(built){case .ok(code):{publish_output_program(m,v,code,plan.bytes,entry,mode,deadline)}case .err(e):{compile_error(m,e)}};
}
fn EntryBinding empty_entry(){
    return EntryBinding{.scope=[0;128],.function=[0;64],.scope_len=0,.function_len=0,.emits=false,.requires_output=false};
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
        .scope_len=scope.len,.function_len=function.len,.emits=false,.requires_output=false});
}
fn Result<EntryBinding,u32> bind_output_authority(ref output_programs::Program code,EntryBinding selected,u32 mode){
    var EntryBinding entry=selected;
    if(entry.scope_len!=0){entry.emits=output_programs::requires_emit(code);}
    if(mode==2 && entry.emits){return .err(5);}
    entry.requires_output=mode==3;
    return .ok(entry);
}
fn u32 publish_output_program(ref mut Meta m,ref mut vec::Vec<Program> v,output_programs::Program code,usize bytes,EntryBinding selected,u32 mode,usize deadline){
    let EntryBinding entry=switch(bind_output_authority(ref code,selected,mode)){
        case .ok(v):{v}case .err(status):{return failed(m,status);}
    };
    var vec::Vec<output_programs::Program> retained=vec::empty<output_programs::Program>();
    if(!vec::reserve<output_programs::Program>(ref mut retained,1).is_ok){return failed(m,6);}
    if(!vec::push<output_programs::Program>(ref mut retained,code).is_ok){return failed(m,6);}
    return publish_output_program_storage(m,v,retained,bytes,entry,deadline);
}
fn u32 publish_output_program_storage(ref mut Meta m,ref mut vec::Vec<Program> v,
    vec::Vec<output_programs::Program> retained,usize bytes,EntryBinding entry,usize deadline){
    if(clock::expired(deadline)){return compile_timed_out(m);}
    let usize scratch=output_programs::preparation(vec::at<output_programs::Program>(ref retained,0)).scratch;
    let usize id=m.next;
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
    usize program_stride,usize ir_stride,usize deadline){
    if(clock::expired(deadline)){return compile_timed_out(m);}
    if(!m.configured || vec::len<host_program::Program>(incoming)!=1){return failed(m,5);}
    if(m.next==0 || vec::len<Program>(v)>=m.limits.programs){return failed(m,8);}
    let usize bytes=control_layout::capacity(1)*program_stride+host_program::heap_bytes(vec::at<host_program::Program>(incoming,0),ir_stride);
    if(!memory::publish(ref mut m.programs,bytes).is_ok){return failed(m,8);}
    let host_program::Program code=pop_host_program(incoming);
    var vec::Vec<host_program::Program> retained=vec::empty<host_program::Program>();
    if(!vec::push<host_program::Program>(ref mut retained,code).is_ok){
        assert(memory::release(ref mut m.programs,bytes).is_ok);return failed(m,6);
    }
    if(clock::expired(deadline)){
        assert(memory::release(ref mut m.programs,bytes).is_ok);return compile_timed_out(m);
    }
    let usize id=m.next;
    assert(vec::push<Program>(v,Program{.id=id,.pins=0,.released=false,.code=vec::empty<programs::Program>(),
        .input=vec::empty<input_programs::Program>(),.output=vec::empty<output_programs::Program>(),.bytes=bytes,
        .execution_scratch=0,.entry=empty_entry(),.host=retained}).is_ok);
    advance(m);return success(m,id);
}
fn u32 prepare_host_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref mut vec::Vec<Output> outputs,ref vec::Vec<policy::Policy> policies,ref run_config::RunConfig run,
    usize code,usize stride,ref u8[] input,usize selected){
    if(!m.configured){return failed(m,5);}
    if(vec::len<policy::Policy>(policies)!=1){return contain_execution_fault(m,p,v,outputs);}
    let usize pi=switch(program_index(p,code,true)){case .ok(x):{x}case .err(status):{return failed(m,status);}};
    let ref Program program=vec::at<Program>(p,pi);
    if(program_variants(program)!=1){return contain_execution_fault(m,p,v,outputs);}
    if(vec::len<host_program::Program>(ref program.host)==0){return failed(m,1);}
    if(vec::len<Instance>(v)>=m.limits.instances || m.next==0){return failed(m,8);}
    if(stride==0 || vec::len<Instance>(v)>=vec::capacity<Instance>(v) ||
        vec::len<Output>(outputs)>=vec::capacity<Output>(outputs)){return contain_execution_fault(m,p,v,outputs);}
    let ref host_program::Program verified=vec::at<host_program::Program>(ref program.host,0);
    let ref policy::Policy ceiling=vec::at<policy::Policy>(policies,0);
    let policy_limits::RunLimits limits=run_config::run_limits(run);
    if(!host_program::allows(verified,ceiling,run) || limits.fuel>m.limits.fuel){return failed(m,5);}
    if(selected!=0 && !host_program::accepts_input(verified)){return failed(m,1);}
    if(input.len>limits.input_bytes || input.len>input_bytes::hard_limit()){return failed(m,8);}
    let usize exchange_bytes=host::scalar_storage_bound(verified,limits)+input.len;
    let usize slots=control_layout::capacity(1);
    let usize transient=if(selected==0){0}else{selected-1};
    if(transient>limits.memory_bytes || exchange_bytes>limits.memory_bytes-transient ||
        stride>(limits.memory_bytes-transient-exchange_bytes)/slots){return failed(m,8);}
    let usize deadline=switch(deadline_after(limits.deadline_ms)){
        case .ok(v):{v}case .err(e):{return failed(m,e.status);}
    };
    let usize charge=slots*stride+exchange_bytes;
    let live::Plan reservation=switch(prepare_payload(m,0,charge,transient)){
        case .ok(plan):{plan}case .err(status):{return failed(m,status);}
    };
    let usize id=m.next;
    let host::Exchange exchange=switch(host::create_scalar_input(verified,ceiling,run,id,deadline,input)){
        case .ok(value):{value}case .err(reason):{
            // Authority, input bounds and run identity already passed admission.
            let bool allocation=switch(reason){
                case .Allocation:{true}
                case .Authority:{false}case .Binding:{false}case .State:{false}case .Rejected:{false}
            };
            if(allocation){return failed(m,6);}
            return contain_execution_fault(m,p,v,outputs);
        }
    };
    var vec::Vec<host::Exchange> saved=vec::empty<host::Exchange>();
    if(!vec::push<host::Exchange>(ref mut saved,exchange).is_ok){return failed(m,6);}
    assert(vec::push<Output>(outputs,Output{.instance=id,.run=output_programs::vacant(limits.fuel),
        .pending=vec::empty<machines::Machine>(),.host=saved}).is_ok);
    assert(vec::push<Instance>(v,Instance{.id=id,.program=code,.fuel=limits.fuel,.phase=4,.output_owned=true,.event=ready(limits.fuel),
        .output_limit=0,.output_allowed=host_program::emits(verified),.input_bound=false,.input_bytes=0,.output_bytes=charge,.host_terminal=host::empty_scalar_event(),.deadline=0}).is_ok);
    commit_payload(m,ref reservation);
    let ref mut Program target=vec::at_mut<Program>(p,pi);target.pins+=1;
    advance(m);return success(m,id);
}

fn u32 drive_host_owner(ref mut vec::Vec<host::Exchange> owners,u32 mode,usize quantum,usize run,usize request,
    u8 kind,ref u8[] payload,ref mut HostTransition transition,usize offset){
    if(vec::len<host::Exchange>(owners)!=1){return 14;}
    let ref mut host::Exchange exchange=vec::at_mut<host::Exchange>(owners,0);
    if(mode==3){
        return switch(host::claim_scalar_dispatch(exchange,run,request,clock::now())){
            case .ok(claimed):{if(claimed){0}else{11}}case .err(_):{14}
        };
    }
    var usize remaining=quantum;
    while(remaining>0 || mode==2){
        let usize now=clock::now();
        let Result<host::ScalarEvent,host::ScalarError> action=if(mode==2){
            host::receive_scalar_reply(exchange,run,request,kind,quantum,offset,payload,now)
        }else{host::step_scalar_budget(exchange,now,mode==1,ref mut remaining)};
        let host::ScalarEvent observed=switch(action){
            case .ok(value):{value}case .err(reason):{return switch(reason){
                case .Rejected:{1}case .Allocation:{6}case .Authority:{5}case .State:{14}case .Binding:{14}
            };}
        };
        let bool done=observed.phase==3;
        let bool failed=observed.phase==4;
        let bool cancel=failed && observed.host.cause==1;
        let u8 event_kind=if(done){1}else if(cancel){3}else if(failed){2}else if(observed.phase==1){4}else{0};
        let u8 diagnostic=if(observed.failure==2){6}else if(observed.failure==4){12}else if(observed.host.cause==7){20}else if(observed.host.cause==5){8}else if(observed.host.cause==4){15}else if(observed.host.cause==2){errors::deadline_kind()}else{0};
        *transition=HostTransition{.scalar=observed,.event=Event{.kind=event_kind,.value=observed.value,
            .diagnostic=diagnostics::absent(errors::make(diagnostic,0)),.remaining=observed.host.fuel,.fuel_known=true}};
        if(observed.phase!=0 || mode!=0){return 0;}
    }
    return 0;
}
fn u32 contain_execution_fault(ref mut Meta m,ref vec::Vec<Program> programs,ref mut vec::Vec<Instance> instances,
    ref vec::Vec<Output> outputs){
    poison_children(m,programs,instances,outputs);
    return failed(m,14);
}
fn u32 drive_host(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,ref mut vec::Vec<Output> outputs,
    ref mut vec::Vec<Output> scratch,usize ii,u32 mode,usize quantum,usize run,usize request,u8 kind,ref u8[] payload,usize offset){
    let usize id=vec::at<Instance>(v,ii).id;
    let usize oi=switch(output_index(outputs,id)){case .ok(i):{i}case .err(_):{return contain_execution_fault(m,p,v,outputs);}};
    var HostTransition next=HostTransition{.scalar=host::empty_scalar_event(),.event=pending()};
    var u32 status=0;
    {let ref mut Output saved=vec::at_mut<Output>(outputs,oi);
     status=unsafe{drive_host_raw(saved as ptr mut void,mode,quantum,run,request,kind,
        payload as ptr u8,payload.len,ref mut next as ptr mut void,offset)};}
    if(status==14){return contain_execution_fault(m,p,v,outputs);}
    if(status!=0){return failed(m,status);}
    if(mode==3){return success(m,request);}
    let ref mut Instance target=vec::at_mut<Instance>(v,ii);
    target.event=next.event;
    if(next.scalar.phase==3 || next.scalar.phase==4){
        if(next.scalar.phase!=3 || !target.output_allowed){
            remove_output(outputs,scratch,id);
            release_payload(m,target.output_bytes);
            target.output_bytes=0;target.output_owned=false;
        }
        target.host_terminal=next.scalar;
        target.phase=2;
    }
    m.event=next.event;return success(m,id);
}
fn u32 reply_host_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,ref mut vec::Vec<Output> outputs,
    ref mut vec::Vec<Output> scratch,usize instance,usize run,usize request,u8 kind,ref u8[] payload,usize total,usize offset){
    let usize ii=switch(instance_index(v,instance)){case .ok(i):{i}case .err(status):{return failed(m,status);}};
    if(vec::at<Instance>(v,ii).phase!=4){return failed(m,11);}
    return drive_host(m,p,v,outputs,scratch,ii,2,total,run,request,kind,payload,offset);
}

fn u32 output_instance_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref mut vec::Vec<BoundInput> inputs,ref mut vec::Vec<input_bytes::Snapshot> incoming,usize code,usize budget,usize limit,u32 allowed,usize deadline,
    ref vec::Vec<Output> outputs){
    if(limit>1048576 || allowed>3){return failed(m,1);}
    if(m.configured!=(allowed>=2) || m.configured!=(deadline!=0) || budget>m.limits.fuel){return failed(m,5);}
    let usize pi=switch(program_index(p,code,true)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let ref Program program=vec::at<Program>(p,pi);
    if(program_variants(program)!=1){return contain_execution_fault(m,p,v,outputs);}
    if(vec::len<output_programs::Program>(ref program.output)!=1){return failed(m,1);}
    let bool input=output_programs::accepts_input(vec::at<output_programs::Program>(ref program.output,0));
    if(vec::len<Instance>(v)>=m.limits.instances || m.next==0){return failed(m,8);}
    if(vec::len<input_bytes::Snapshot>(incoming)!=if(input){1}else{0}){return failed(m,1);}
    if(!input_admission_intact(m,v,inputs,input)){return contain_execution_fault(m,p,v,outputs);}
    let usize capacity=if(input){input_bytes::capacity(vec::at<input_bytes::Snapshot>(incoming,0))}else{0};
    let usize transport=unsafe{input_fact_raw(incoming as ptr void,1)};
    let live::Plan storage=switch(prepare_payload(m,0,capacity,transport)){
        case .ok(v):{v}case .err(status):{return failed(m,status);}
    };
    let usize id=m.next;
    if(input){let input_bytes::Snapshot snapshot=pop_snapshot(incoming);
        assert(vec::push<BoundInput>(inputs,BoundInput{.instance=id,.input=snapshot}).is_ok);}
    assert(vec::push<Instance>(v,Instance{.id=id,.program=code,.fuel=budget,.phase=0,.output_owned=false,.event=ready(budget),.output_limit=limit,.output_allowed=allowed==1 || allowed==3,.input_bound=input,.input_bytes=capacity,.output_bytes=0,.host_terminal=host::empty_scalar_event(),.deadline=deadline}).is_ok);
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
    remove_output_at(v,scratch,i);
}
fn void remove_output_at(ref mut vec::Vec<Output> v,ref mut vec::Vec<Output> scratch,usize i){
    output_to_scratch(v,scratch,i);{let Output disposed=pop_output(v);}restore_output(v,scratch);
}
struct OutputTake { usize instance; usize owner; live::Plan refund; }
fn Result<OutputTake,u32> plan_output_take(ref mut Meta m,ref vec::Vec<Instance> instances,
    ref vec::Vec<Output> outputs,usize id,usize transport){
    if(m.closed){return .err(2);}
    let usize ii=instance_index(instances,id)?;
    let ref Instance child=vec::at<Instance>(instances,ii);
    if(child.phase==5){return .err(2);}
    if(child.phase!=2){return .err(11);}
    let Result<usize,u32> located=output_index(outputs,id);
    if(located.is_ok!=child.output_owned || (!child.output_owned && child.output_bytes!=0)){return .err(14);}
    let usize oi=located?;
    let ref Output owner=vec::at<Output>(outputs,oi);
    let usize hosts=vec::len<host::Exchange>(ref owner.host);
    if(vec::len<machines::Machine>(ref owner.pending)!=0 || hosts>1){return .err(14);}
    if(child.host_terminal.phase==3){
        // Host output retains its whole admitted Exchange reservation.
        if(hosts!=1 || child.output_bytes==0 || !has_host_output(owner)){return .err(14);}
    }else{
        if(hosts!=0 || output_programs::heap_bytes(ref owner.run)!=child.output_bytes){return .err(14);}
        if(output_programs::observe(ref owner.run).cancelled){return .err(2);}
    }
    if(child.output_bytes>18446744073709551615-child.input_bytes){return .err(14);}
    let usize retained=child.input_bytes+child.output_bytes;
    if(retained>m.heap.instance_limit || !payload_ledger_intact(m)){return .err(14);}
    let live::Plan plan=switch(live::prepare(ref m.heap,retained,child.input_bytes,transport)){
        case .ok(v):{v}case .err(reason):{
            let u32 status=switch(reason){case .Quota:{8}case .State:{14}case .Invalid:{14}};
            return .err(status);
        }
    };
    switch(memory::prepare_external(ref mut m.programs,plan.aggregate_peak)){
        case .ok(_):{}
        case .err(reason):{
            let u32 status=switch(reason){case .Quota:{8}case .State:{14}case .Invalid:{14}};
            return .err(status);
        }
    };
    assert(live::record(ref mut m.heap,ref plan).is_ok);
    return .ok(OutputTake{.instance=ii,.owner=oi,.refund=plan});
}
fn u32 output_preflight_width(ref mut Meta m,ref mut vec::Vec<Instance> instances,ref vec::Vec<Output> outputs,
    usize id,usize width,ref vec::Vec<Program> programs){
    if(width==0 || width>18446744073709551615/8){return contain_execution_fault(m,programs,instances,outputs);}
    return switch(plan_output_take(m,instances,outputs,id,8*width)){
        case .ok(_):{0}case .err(status):{
            if(status==14){return contain_execution_fault(m,programs,instances,outputs);}
            status
        }
    };
}
fn u32 take_output_inner(ref mut Meta m,ref mut vec::Vec<Instance> instances,ref mut vec::Vec<Output> v,
    ref mut vec::Vec<Output> scratch,usize id,ref mut vec::Vec<Output> outgoing,ref vec::Vec<Program> programs){
    if(vec::len<Output>(outgoing)!=0 || vec::capacity<Output>(outgoing)==0){return failed(m,1);}
    let OutputTake plan=switch(plan_output_take(m,instances,v,id,unsafe{output_fact_raw(outgoing as ptr void,1)})){
        case .ok(v):{v}case .err(status):{
            if(status==14){return contain_execution_fault(m,programs,instances,v);}
            return failed(m,status);
        }
    };
    if(vec::len<Output>(scratch)!=0 || vec::capacity<Output>(scratch)<vec::len<Output>(v)-plan.owner-1){
        return contain_execution_fault(m,programs,instances,v);
    }
    // The reserved result slot receives the whole owner without further allocation.
    output_to_scratch(v,scratch,plan.owner);let Output run=pop_output(v);
    assert(vec::push<Output>(outgoing,run).is_ok);restore_output(v,scratch);
    commit_payload(m,ref plan.refund);
    {let ref mut Instance target=vec::at_mut<Instance>(instances,plan.instance);target.output_bytes=0;target.output_owned=false;}
    return success(m,id);
}
fn u32 instance_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Instance> v,usize code,usize budget){
    if(m.configured || budget>m.limits.fuel){return failed(m,5);}
    let usize pi=switch(program_index(p,code,true)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    if(vec::len<Instance>(v)>=m.limits.instances || m.next==0){return failed(m,8);}
    let usize id=m.next;
    if(!vec::push<Instance>(v,Instance{.id=id,.program=code,.fuel=budget,.phase=0,.output_owned=false,.event=ready(budget),.output_limit=0,.output_allowed=false,.input_bound=false,.input_bytes=0,.output_bytes=0,.host_terminal=host::empty_scalar_event(),.deadline=0}).is_ok){return failed(m,6);}
    let ref mut Program target=vec::at_mut<Program>(p,pi);target.pins+=1;advance(m);return success(m,id);
}
fn Result<usize,u32> input_index(ref vec::Vec<BoundInput> v,usize id){
    var usize i=0;while(i<vec::len<BoundInput>(v)){if(vec::at<BoundInput>(v,i).instance==id){return .ok(i);}i+=1;}return .err(2);
}
fn input_bytes::Snapshot pop_snapshot(ref mut vec::Vec<input_bytes::Snapshot> v){return switch(vec::pop<input_bytes::Snapshot>(v)){
    case .some(value):{value}case .none:{assert(false);pop_snapshot(v)}
};}
fn u32 input_instance_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref mut vec::Vec<BoundInput> inputs,ref mut vec::Vec<input_bytes::Snapshot> incoming,usize code,usize budget,ref vec::Vec<Output> outputs){
    if(m.configured || budget>m.limits.fuel){return failed(m,5);}
    let usize pi=switch(program_index(p,code,true)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let ref Program program=vec::at<Program>(p,pi);
    if(program_variants(program)!=1){return contain_execution_fault(m,p,v,outputs);}
    if(vec::len<input_programs::Program>(ref program.input)!=1){return failed(m,1);}
    if(vec::len<Instance>(v)>=m.limits.instances || m.next==0){return failed(m,8);}
    if(vec::len<input_bytes::Snapshot>(incoming)!=1){return failed(m,1);}
    if(!input_admission_intact(m,v,inputs,true)){return contain_execution_fault(m,p,v,outputs);}
    let usize capacity=input_bytes::capacity(vec::at<input_bytes::Snapshot>(incoming,0));
    let live::Plan storage=switch(prepare_payload(m,0,capacity,unsafe{input_fact_raw(incoming as ptr void,1)})){
        case .ok(v):{v}case .err(status):{return failed(m,status);}
    };
    let usize id=m.next;let input_bytes::Snapshot snapshot=pop_snapshot(incoming);
    assert(vec::push<BoundInput>(inputs,BoundInput{.instance=id,.input=snapshot}).is_ok);
    assert(vec::push<Instance>(v,Instance{.id=id,.program=code,.fuel=budget,.phase=0,.output_owned=false,.event=ready(budget),.output_limit=0,.output_allowed=false,.input_bound=true,.input_bytes=capacity,.output_bytes=0,.host_terminal=host::empty_scalar_event(),.deadline=0}).is_ok);
    commit_payload(m,ref storage);
    let ref mut Program target=vec::at_mut<Program>(p,pi);target.pins+=1;advance(m);return success(m,id);
}
fn BoundInput pop_bound(ref mut vec::Vec<BoundInput> v){return switch(vec::pop<BoundInput>(v)){
    case .some(value):{value}case .none:{assert(false);pop_bound(v)}
};}
fn void remove_input_at(ref mut vec::Vec<BoundInput> v,ref mut vec::Vec<BoundInput> scratch,usize i){
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
fn bool pins_match(ref Program code,ref vec::Vec<Instance> instances){
    var usize pins=0;
    var usize i=0;
    while(i<vec::len<Instance>(instances)){
        if(vec::at<Instance>(instances,i).program==code.id){pins+=1;}
        i+=1;
    }
    return code.pins==pins;
}
fn bool program_reclaimable(ref Meta m,ref vec::Vec<Program> programs,ref vec::Vec<Program> scratch,usize index){
    if(!payload_ledger_intact(m) || vec::len<Program>(scratch)!=0 ||
        vec::capacity<Program>(scratch)<vec::len<Program>(programs)-index-1){return false;}
    var usize retained=m.programs.retained;
    var usize i=0;
    while(i<vec::len<Program>(programs)){
        let usize bytes=vec::at<Program>(programs,i).bytes;
        if(bytes>retained){return false;}
        retained-=bytes;
        i+=1;
    }
    return retained==0;
}
fn bool instance_charges_match(ref Meta m,ref vec::Vec<Instance> instances){
    if(!payload_ledger_intact(m)){return false;}
    var usize retained=m.heap.current;
    var usize i=0;
    while(i<vec::len<Instance>(instances)){
        let ref Instance child=vec::at<Instance>(instances,i);
        if(child.input_bytes>retained || child.output_bytes>retained-child.input_bytes){return false;}
        retained-=child.input_bytes+child.output_bytes;
        i+=1;
    }
    return retained==0;
}
fn u32 release_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Program> scratch,
    ref mut vec::Vec<Instance> v,ref vec::Vec<Output> outputs,usize id){
    let usize i=switch(program_index(p,id,true)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let ref Program code=vec::at<Program>(p,i);
    if(!pins_match(code,v)){return contain_execution_fault(m,p,v,outputs);}
    if(code.pins==0){
        if(!program_reclaimable(m,p,scratch,i)){return contain_execution_fault(m,p,v,outputs);}
        remove(m,p,scratch,i);
    }else{let ref mut Program target=vec::at_mut<Program>(p,i);target.released=true;}
    return success(m,id);
}
fn u32 destroy_instance_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Program> scratch,ref mut vec::Vec<Instance> v,
    ref mut vec::Vec<BoundInput> inputs,ref mut vec::Vec<BoundInput> input_scratch,
    ref mut vec::Vec<Output> outputs,ref mut vec::Vec<Output> output_scratch,usize id){
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let Instance current=*vec::at<Instance>(v,ii);if(current.phase==1){return failed(m,3);}
    let usize pi=switch(program_index(p,current.program,false)){
        case .ok(x):{x}case .err(_):{return contain_execution_fault(m,p,v,outputs);}
    };
    let ref Program program=vec::at<Program>(p,pi);
    let usize pins=program.pins;
    if(pins==0 || !pins_match(program,v) || !instance_charges_match(m,v)){
        return contain_execution_fault(m,p,v,outputs);
    }
    let bool reclaim=pins==1 && program.released;
    if(reclaim && !program_reclaimable(m,p,scratch,pi)){return contain_execution_fault(m,p,v,outputs);}
    if(vec::len<BoundInput>(input_scratch)!=0 || vec::len<Output>(output_scratch)!=0){
        return contain_execution_fault(m,p,v,outputs);
    }
    let Option<usize> bound=switch(input_index(inputs,id)){
        case .ok(i):{
            if(!current.input_bound || input_bytes::capacity(ref vec::at<BoundInput>(inputs,i).input)!=current.input_bytes ||
                vec::capacity<BoundInput>(input_scratch)<vec::len<BoundInput>(inputs)-i-1){
                return contain_execution_fault(m,p,v,outputs);
            }
            let Option<usize> found=.some(i);found
        }
        case .err(_):{
            if(current.input_bound || current.input_bytes!=0){return contain_execution_fault(m,p,v,outputs);}
            let Option<usize> missing=.none;missing
        }
    };
    let Option<usize> output=switch(output_index(outputs,id)){
        case .ok(i):{
            if(!current.output_owned || vec::capacity<Output>(output_scratch)<vec::len<Output>(outputs)-i-1){
                return contain_execution_fault(m,p,v,outputs);
            }
            let Option<usize> found=.some(i);found
        }
        case .err(_):{
            if(current.output_owned || current.output_bytes!=0){return contain_execution_fault(m,p,v,outputs);}
            let Option<usize> missing=.none;missing
        }
    };
    // Dropping destroys the sole unpublished owner directly. No live guest
    // metadata or external handles survive it, so semantic unwinding is unused.
    {let ref mut Program code=vec::at_mut<Program>(p,pi);code.pins=pins-1;}
    let Instance last=switch(vec::pop<Instance>(v)){case .some(x):{x}case .none:{assert(false);current}};
    if(ii<vec::len<Instance>(v)){let ref mut Instance target=vec::at_mut<Instance>(v,ii);*target=last;}
    switch(output){case .some(i):{remove_output_at(outputs,output_scratch,i);}case .none:{}};
    switch(bound){case .some(i):{remove_input_at(inputs,input_scratch,i);}case .none:{}};
    release_payload(m,current.input_bytes+current.output_bytes);
    if(reclaim){remove(m,p,scratch,pi);}return success(m,id);
}
fn u32 execute_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,ref vec::Vec<BoundInput> inputs,ref mut vec::Vec<Output> outputs,usize id){
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let Instance current=*vec::at<Instance>(v,ii);
    if(current.phase==1 || current.phase==3 || current.phase==4){return failed(m,3);}if(current.phase==2){return failed(m,11);}
    let usize pi=switch(program_index(p,current.program,false)){
        case .ok(x):{x}case .err(_):{return contain_execution_fault(m,p,v,outputs);}
    };
    let ref Program code=vec::at<Program>(p,pi);
    if(code.pins==0 || program_variants(code)!=1){return contain_execution_fault(m,p,v,outputs);}
    if(vec::len<output_programs::Program>(ref code.output)!=0){return execute_output_inner(m,p,v,inputs,outputs,pi,ii);}
    if(vec::len<input_programs::Program>(ref code.input)!=0){
        let Result<usize,u32> bound_input=input_index(inputs,id);
        if(bound_input.is_ok!=current.input_bound){return contain_execution_fault(m,p,v,outputs);}
        let usize bi=switch(bound_input){case .ok(x):{x}case .err(_):{return failed(m,1);}};
        let ref input_bytes::Snapshot input=ref vec::at<BoundInput>(inputs,bi).input;
        if(input_bytes::capacity(input)!=current.input_bytes){return contain_execution_fault(m,p,v,outputs);}
        return execute_input_inner(m,v,code,ii,input);
    }
    if(vec::len<programs::Program>(ref code.code)!=1){return failed(m,1);}
    let u32 memory_status=reserve_execution(m,code,ref current);if(memory_status!=0){return memory_status;}
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.phase=1;}
    let Event event=switch(programs::run(vec::at<programs::Program>(ref code.code,0),current.fuel)){
        case .ok(value):{Event{.kind=1,.value=value,.diagnostic=absent(),.remaining=0,.fuel_known=false}}
        case .err(e):{Event{.kind=2,.value=0,.diagnostic=e,.remaining=0,.fuel_known=false}}
    };
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.event=event;target.phase=2;}
    m.event=event;return success(m,id);
}
fn Result<Option<usize>,u32> locate_output_input(ref vec::Vec<BoundInput> inputs,ref Instance child,bool accepts_input){
    let Result<usize,u32> located=input_index(inputs,child.id);
    if(located.is_ok!=child.input_bound){return .err(14);}
    let Option<usize> index=switch(located){
        case .ok(i):{
            let ref input_bytes::Snapshot input=ref vec::at<BoundInput>(inputs,i).input;
            if(!accepts_input || input_bytes::capacity(input)!=child.input_bytes){return .err(14);}
            let Option<usize> found=.some(i);found
        }
        case .err(_):{
            if(child.input_bytes!=0){return .err(14);}
            if(accepts_input){return .err(1);}
            let Option<usize> empty=.none;empty
        }
    };
    return .ok(index);
}
fn u32 execute_output_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref vec::Vec<BoundInput> inputs,ref mut vec::Vec<Output> outputs,usize pi,usize ii){
    let Instance current=*vec::at<Instance>(v,ii);
    if(output_index(outputs,current.id).is_ok || current.output_owned || current.output_bytes!=0 ||
        vec::len<Output>(outputs)>=vec::capacity<Output>(outputs)){return contain_execution_fault(m,p,v,outputs);}
    let ref Program code=vec::at<Program>(p,pi);
    let ref output_programs::Program retained=vec::at<output_programs::Program>(ref code.output,0);
    let Option<usize> bound=switch(locate_output_input(inputs,ref current,output_programs::accepts_input(retained))){
        case .ok(index):{index}
        case .err(status):{
            if(status==14){return contain_execution_fault(m,p,v,outputs);}
            return failed(m,status);
        }
    };
    let u32 memory_status=reserve_execution(m,code,ref current);if(memory_status!=0){return memory_status;}
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.phase=1;}
    let output_programs::Execution run=switch(bound){
        case .some(i):{output_programs::complete(retained,ref vec::at<BoundInput>(inputs,i).input,
            current.fuel,current.output_limit,current.output_allowed)}
        case .none:{
            var usize unused=0;
            let input_bytes::Snapshot empty=switch(input_bytes::snapshot(b"",0,0,ref mut unused)){
                case .ok(value):{value}case .err(_):{return contain_execution_fault(m,p,v,outputs);}
            };
            output_programs::complete(retained,ref empty,current.fuel,current.output_limit,current.output_allowed)
        }
    };
    return publish_output_run(m,p,v,outputs,ii,run);
}
fn Result<machines::Machine,diagnostics::Error> open_instance_machine(ref output_programs::Program code,
    ref vec::Vec<BoundInput> inputs,Option<usize> bound,usize budget,usize limit,bool allowed,usize frame_limit){
    return switch(bound){
        case .some(index):{pending_vm::prepare_with_frame_limit(code,ref vec::at<BoundInput>(inputs,index).input,budget,limit,allowed,frame_limit)}
        case .none:{
            var usize unused=0;let input_bytes::Snapshot empty=switch(input_bytes::snapshot(b"",0,0,ref mut unused)){
                case .ok(v):{v}case .err(_):{return .err(diagnostics::absent(errors::make(15,0)));}
            };
            pending_vm::prepare_with_frame_limit(code,ref empty,budget,limit,allowed,frame_limit)
        }
    };
}
fn u32 prepare_instance_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref vec::Vec<BoundInput> inputs,ref mut vec::Vec<Output> outputs,usize id,usize frame_limit){
    if(frame_limit==0){return failed(m,1);}
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let Instance before=*vec::at<Instance>(v,ii);
    if(before.phase!=0){return failed(m,3);}
    let usize pi=switch(program_index(p,before.program,false)){case .ok(x):{x}case .err(_):{return contain_execution_fault(m,p,v,outputs);}};
    let ref Program code=vec::at<Program>(p,pi);
    if(code.pins==0 || program_variants(code)!=1 || output_index(outputs,id).is_ok || before.output_owned || before.output_bytes!=0){
        return contain_execution_fault(m,p,v,outputs);
    }
    if(vec::len<output_programs::Program>(ref code.output)==0){return failed(m,1);}
    if(vec::len<Output>(outputs)>=vec::capacity<Output>(outputs)){return contain_execution_fault(m,p,v,outputs);}
    let ref output_programs::Program retained=vec::at<output_programs::Program>(ref code.output,0);
    let Option<usize> bound=switch(locate_output_input(inputs,ref before,output_programs::accepts_input(retained))){
        case .ok(index):{index}
        case .err(status):{
            if(status==14){return contain_execution_fault(m,p,v,outputs);}
            return failed(m,status);
        }
    };
    let usize charge=switch(pending_bytes(code,before.output_limit)){case .ok(v):{v}case .err(e):{return failed(m,e.status);}};
    if(charge>18446744073709551615-before.input_bytes){return failed(m,8);}
    let live::Plan ownership=switch(prepare_payload(m,before.input_bytes,before.input_bytes+charge,0)){
        case .ok(v):{v}case .err(s):{return failed(m,s);}
    };
    // Everything remains local until all allocations and entry preparation
    // succeed. Resource refusals leave the Ready Instance and its input intact.
    var vec::Vec<machines::Machine> saved=vec::empty<machines::Machine>();
    if(!vec::reserve<machines::Machine>(ref mut saved,1).is_ok){return failed(m,6);}
    let output_programs::Execution slot=switch(output_programs::pending_slot(before.fuel)){
        case .ok(v):{v}case .err(_):{return failed(m,6);}
    };
    let machines::Machine machine=switch(open_instance_machine(retained,inputs,bound,before.fuel,before.output_limit,before.output_allowed,frame_limit)){
        case .ok(v):{v}case .err(e):{
            if(e.code.kind==15){return failed(m,6);}
            if(e.code.kind!=8){return contain_execution_fault(m,p,v,outputs);}
            m.error=Error{.status=4,.diagnostic=e};return 4;
        }
    };
    let machines::Meta state=machines::observe(ref machine);
    if(state.phase!=1 || state.stats.dispatched!=0){return contain_execution_fault(m,p,v,outputs);}
    assert(vec::push<machines::Machine>(ref mut saved,machine).is_ok);
    let Event event=Event{.kind=4,.value=0,.diagnostic=absent(),.remaining=state.remaining,.fuel_known=true};
    assert(vec::push<Output>(outputs,Output{.instance=id,.run=slot,.pending=saved,.host=vec::empty<host::Exchange>()}).is_ok);
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.phase=3;target.event=event;target.output_bytes=charge;target.output_owned=true;}
    commit_payload(m,ref ownership);m.event=event;return success(m,id);
}
fn u32 publish_output_run(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref mut vec::Vec<Output> outputs,usize ii,output_programs::Execution run){
    let output_programs::Completion completed=output_programs::observe(ref run);
    let usize bytes=output_programs::heap_bytes(ref run);
    let Instance before=*vec::at<Instance>(v,ii);
    let usize id=before.id;
    // Keep consumed Fuel visible if publication itself fails.
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.event.remaining=completed.remaining;}
    if(bytes>616+before.output_limit || bytes>18446744073709551615-before.input_bytes){
        return contain_execution_fault(m,p,v,outputs);
    }
    let live::Plan ownership=switch(live::prepare(ref m.heap,before.input_bytes,before.input_bytes+bytes,0)){
        case .ok(v):{v}case .err(_):{return contain_execution_fault(m,p,v,outputs);}
    };
    let Event event=Event{.kind=if(completed.success){1}else{2},.value=completed.value,
        .diagnostic=completed.diagnostic,.remaining=completed.remaining,.fuel_known=true};
    assert(vec::push<Output>(outputs,Output{.instance=id,.run=run,.pending=vec::empty<machines::Machine>(),.host=vec::empty<host::Exchange>()}).is_ok);
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.event=event;target.phase=2;target.output_bytes=bytes;target.output_owned=true;}
    commit_payload(m,ref ownership);
    m.event=event;return success(m,id);
}
// Typed projection enters this helper with disjoint owning fields, never a
// reconstructed VM. The preallocated publication slot receives a successful
// seal directly; popping terminal Machine state releases its private backing.
fn u32 step_output_owner(ref mut vec::Vec<machines::Machine> saved,ref mut output_programs::Completion completed,
    ref mut vec::Vec<pending_output::Published> published,ref output_programs::Program code,ref input_bytes::Snapshot input,usize quantum,usize deadline){
    if(quantum==0 || quantum>4096 || vec::len<machines::Machine>(saved)!=1 ||
        vec::len<pending_output::Published>(published)!=0 || vec::capacity<pending_output::Published>(published)<1){return 7;}
    var bool cleanup_failed=false;
    {
        let ref mut machines::Machine machine=vec::at_mut<machines::Machine>(saved,0);
        if(clock::expired(deadline) && !pending_vm::expire_pending_output(machine).is_ok){return 7;}
        let machines::Meta initial=machines::observe(machine);
        var machines::Meta progressed=if(initial.phase>=2){initial}else{switch(pending_vm::advance_pending_output(machine,code,input,quantum)){
            case .ok(v):{v}case .err(_):{return 7;}
        }};
        if(progressed.lifecycle.terminal==0 && clock::expired(deadline)){
            progressed=switch(pending_vm::expire_pending_output(machine)){case .ok(v):{v}case .err(_):{return 7;}};
        }
        if(progressed.phase==1){
            *completed=output_programs::pending_completion(progressed.remaining);return 0;
        }
        if(progressed.phase==2){discard pending_vm::seal_pending_output_into(machine,published);}
        let machines::Meta finished=machines::observe(machine);
        if(finished.phase==1){*completed=output_programs::pending_completion(finished.remaining);return 0;}
        // A refused seal can leave the machine ready to publish. Only an
        // actual sealed owner can authorize a successful Engine event.
        if(finished.phase==2 && vec::len<pending_output::Published>(published)!=1){return 7;}
        cleanup_failed=finished.lifecycle.cleanup_failed;
        if(finished.phase==2 && clock::expired(deadline)){
            // The sealed owner is still private. Drop it before Engine publication.
            let Option<pending_output::Published> discarded=vec::pop<pending_output::Published>(published);
            *completed=output_programs::resumed_completion(code,published,false,0,finished.remaining,
                errors::absent(errors::deadline_kind(),0),0);
        }else if(finished.phase==4){*completed=output_programs::cancelled_completion(finished.remaining);}
        else{if(finished.phase!=2 && finished.phase!=3){return 7;};
        *completed=output_programs::resumed_completion(code,published,finished.phase==2,finished.value,
            finished.remaining,finished.failure,pending_vm::pending_staged_emits(machine));}
    }
    {let Option<machines::Machine> disposed=vec::pop<machines::Machine>(saved);}
    return if(cleanup_failed){14}else{0};
}
fn vec::Vec<machines::Machine> compact_pending_storage(vec::Vec<machines::Machine> saved){
    if(vec::len<machines::Machine>(ref saved)!=0){return saved;}return vec::empty<machines::Machine>();
}
fn vec::Vec<pending_output::Published> compact_cancelled_storage(vec::Vec<pending_output::Published> saved,bool cancelled){
    if(cancelled){return vec::empty<pending_output::Published>();}return saved;
}
fn u32 cancel_output_owner(ref mut vec::Vec<machines::Machine> saved,usize deadline){
    if(vec::len<machines::Machine>(saved)!=1){return 7;}
    let ref mut machines::Machine machine=vec::at_mut<machines::Machine>(saved,0);
    if(clock::expired(deadline) && !pending_vm::expire_pending_output(machine).is_ok){return 7;}
    return switch(pending_vm::cancel_pending_output(machine)){
        case .ok(v):{if(v.phase==1){12}else if(v.phase==3 || v.lifecycle.cleanup_failed){13}else{0}}case .err(_):{7}
    };
}
fn u32 step_instance_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref vec::Vec<BoundInput> inputs,ref mut vec::Vec<Output> outputs,ref mut vec::Vec<Output> scratch,usize id,usize quantum){
    if(quantum==0 || quantum>4096){return failed(m,1);}
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let Instance before=*vec::at<Instance>(v,ii);
    if(before.phase==2){return failed(m,11);}
    if(before.phase==4){return drive_host(m,p,v,outputs,scratch,ii,0,quantum,0,0,0,b"",0);}
    if(before.phase!=3){return failed(m,3);}
    let usize pi=switch(program_index(p,before.program,false)){case .ok(x):{x}case .err(_):{return contain_execution_fault(m,p,v,outputs);}};
    let ref Program code=vec::at<Program>(p,pi);
    if(code.pins==0 || vec::len<output_programs::Program>(ref code.output)!=1){return contain_execution_fault(m,p,v,outputs);}
    let ref output_programs::Program retained=vec::at<output_programs::Program>(ref code.output,0);
    let usize oi=switch(output_index(outputs,id)){case .ok(x):{x}case .err(_):{return contain_execution_fault(m,p,v,outputs);}};
    let Option<usize> bound=switch(locate_output_input(inputs,ref before,output_programs::accepts_input(retained))){
        case .ok(index):{index}
        case .err(_):{return contain_execution_fault(m,p,v,outputs);}
    };
    var u32 status=0;
    switch(bound){
        case .some(i):{
            let ref input_bytes::Snapshot input=ref vec::at<BoundInput>(inputs,i).input;
            let ref mut Output saved=vec::at_mut<Output>(outputs,oi);
            status=unsafe{step_output_raw(saved as ptr mut void,retained as ptr void,input as ptr void,quantum,before.deadline)};
        }
        case .none:{
            var usize unused=0;let input_bytes::Snapshot empty=switch(input_bytes::snapshot(b"",0,0,ref mut unused)){
                case .ok(v):{v}case .err(_):{return contain_execution_fault(m,p,v,outputs);}
            };
            let ref mut Output saved=vec::at_mut<Output>(outputs,oi);
            status=unsafe{step_output_raw(saved as ptr mut void,retained as ptr void,ref empty as ptr void,quantum,before.deadline)};
        }
    };
    if(status!=0 && status!=14){return contain_execution_fault(m,p,v,outputs);}
    let ref Output saved=vec::at<Output>(outputs,oi);
    let bool pending=vec::len<machines::Machine>(ref saved.pending)==1;
    let output_programs::Completion completed=output_programs::observe(ref saved.run);
    let usize bytes=if(pending){before.output_bytes}else{output_programs::heap_bytes(ref saved.run)};
    if(bytes>before.output_bytes){return contain_execution_fault(m,p,v,outputs);}
    let live::Plan ownership=switch(live::prepare(ref m.heap,before.input_bytes+before.output_bytes,before.input_bytes+bytes,0)){
        case .ok(v):{v}case .err(_):{return contain_execution_fault(m,p,v,outputs);}
    };
    let Event event=Event{.kind=if(pending){4}else if(completed.cancelled){3}else{if(completed.success){1}else{2}},.value=completed.value,
        .diagnostic=completed.diagnostic,.remaining=completed.remaining,.fuel_known=true};
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.phase=if(pending){3}else{2};target.event=event;target.output_bytes=bytes;}
    commit_payload(m,ref ownership);
    if(status==14){poison_children(m,p,v,outputs);}
    m.event=event;return success(m,id);
}
fn u32 execute_input_inner(ref mut Meta m,ref mut vec::Vec<Instance> v,ref Program code,usize ii,ref input_bytes::Snapshot input){
    let Instance current=*vec::at<Instance>(v,ii);
    let u32 memory_status=reserve_execution(m,code,ref current);if(memory_status!=0){return memory_status;}
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.phase=1;}
    let input_programs::Completion completion=input_programs::complete(vec::at<input_programs::Program>(ref code.input,0),input,current.fuel);
    let Event event=Event{.kind=if(completion.success){1}else{2},.value=completion.value,
        .diagnostic=completion.diagnostic,.remaining=completion.remaining,.fuel_known=true};
    {let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.event=event;target.phase=2;}
    m.event=event;return success(m,current.id);
}
fn u32 execute_borrowed_input_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref vec::Vec<BoundInput> inputs,usize id,ref input_bytes::Snapshot input,ref vec::Vec<Output> outputs){
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let ref Instance current=vec::at<Instance>(v,ii);
    if(current.phase==1){return failed(m,3);}if(current.phase==2){return failed(m,11);}
    let bool bound=input_index(inputs,id).is_ok;
    if(bound!=current.input_bound){return contain_execution_fault(m,p,v,outputs);}
    if(bound){return failed(m,1);}
    let usize pi=switch(program_index(p,current.program,false)){
        case .ok(x):{x}case .err(_):{return contain_execution_fault(m,p,v,outputs);}
    };
    let ref Program code=vec::at<Program>(p,pi);
    if(code.pins==0 || program_variants(code)!=1){return contain_execution_fault(m,p,v,outputs);}
    if(vec::len<input_programs::Program>(ref code.input)!=1){return failed(m,1);}
    return execute_input_inner(m,v,code,ii,input);
}
fn u32 observe_inner(ref mut Meta m,ref vec::Vec<Instance> v,usize id){
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    m.event=vec::at<Instance>(v,ii).event;return success(m,id);
}
fn u32 cancel_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,ref vec::Vec<BoundInput> inputs,ref mut vec::Vec<Output> outputs,ref mut vec::Vec<Output> scratch,usize id){
    let usize ii=switch(instance_index(v,id)){case .ok(x):{x}case .err(s):{return failed(m,s);}};
    let Instance before=*vec::at<Instance>(v,ii);
    if(before.phase==4){return drive_host(m,p,v,outputs,scratch,ii,1,1,0,0,0,b"",0);}
    if(before.phase==3){
        let usize oi=switch(output_index(outputs,id)){case .ok(x):{x}case .err(_):{return contain_execution_fault(m,p,v,outputs);}};
        // Drain canonical private metadata and discard any staged prefix before
        // releasing its sole owner; no guest effects are replayed or rolled back.
        var u32 status=0;
        {let ref mut Output saved=vec::at_mut<Output>(outputs,oi);status=unsafe{cancel_output_raw(saved as ptr mut void,before.deadline)};}
        if(status==12){m.event=before.event;return success(m,id);}
        // A prior failure wins. Finalize it through the same Program diagnostic
        // and retained-output path as step, even if the caller repeats cancel.
        if(status==13){return step_instance_inner(m,p,v,inputs,outputs,scratch,id,1);}
        if(status!=0){return contain_execution_fault(m,p,v,outputs);}
        remove_output(outputs,scratch,id);
        release_payload(m,before.output_bytes);
        let ref mut Instance target=vec::at_mut<Instance>(v,ii);target.output_bytes=0;target.output_owned=false;
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
    if(m.programs.compile_source!=0){return failed(m,3);}
    if(vec::len<Program>(p)!=0 || vec::len<Instance>(v)!=0 || vec::len<BoundInput>(inputs)!=0 || vec::len<Output>(outputs)!=0){return failed(m,3);}
    let usize bytes=control::observe(ref m.control).reserved;
    assert(control::release(ref mut m.control,bytes).is_ok);assert(control::close(ref mut m.control).is_ok);
    assert(live::close(ref mut m.heap).is_ok);assert(memory::close(ref mut m.programs).is_ok);m.closed=true;return success(m,0);
}
fn u32 claim_host_inner(ref mut Meta m,ref vec::Vec<Program> p,ref mut vec::Vec<Instance> v,
    ref mut vec::Vec<Output> outputs,ref mut vec::Vec<Output> scratch,usize instance,usize request){
    let usize ii=switch(instance_index(v,instance)){case .ok(i):{i}case .err(s):{return failed(m,s);}};
    if(vec::at<Instance>(v,ii).phase!=4){return failed(m,11);}
    return drive_host(m,p,v,outputs,scratch,ii,3,0,instance,request,0,b"",0);
}

fn u32 dispatch_inner(ref mut Meta m,ref mut vec::Vec<Program> p,ref mut vec::Vec<Program> scratch,
    ref mut vec::Vec<Instance> v,ref mut vec::Vec<BoundInput> inputs,ref mut vec::Vec<BoundInput> input_scratch,
    ref mut vec::Vec<Output> outputs,ref mut vec::Vec<Output> output_scratch,u32 operation,usize id,usize argument){
    if(operation==1){return instance_inner(m,p,v,id,argument);}
    if(operation==2){return release_inner(m,p,scratch,v,outputs,id);}
    if(operation==3){return destroy_instance_inner(m,p,scratch,v,inputs,input_scratch,outputs,output_scratch,id);}
    if(operation==4){return close_inner(m,p,v,inputs,outputs);}
    if(operation==5){return execute_inner(m,p,v,inputs,outputs,id);}
    if(operation==6){return observe_inner(m,v,id);}
    if(operation==7){return cancel_inner(m,p,v,inputs,outputs,output_scratch,id);}
    if(operation==8){return inspect_inner(m,p,v);}
    if(operation==9){return prepare_instance_inner(m,p,v,inputs,outputs,id,argument);}
    if(operation==10){return step_instance_inner(m,p,v,inputs,outputs,output_scratch,id,argument);}
    if(operation==11){return claim_host_inner(m,p,v,outputs,output_scratch,id,argument);}
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
    if(m.admission!=0 && !m.poisoned){return failed(m,7);}
    if(operation!=2 && operation!=3 && operation!=4 && operation!=6 && operation!=7 && operation!=8){
        let u32 unavailable=if(m.poisoned){14}else{8};return failed(m,unavailable);
    }
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
fn void retain_output_bindings(ref mut Meta m,ref input_bytes::Snapshot snapshot){
    let modules::Index index=switch(layout_index(b"module layout;pub fn i32 main(){return 0;}")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let entries::Entry entry=switch(entries::select_i32(index,b"layout",b"main")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    unsafe{binding_raw(19)};discard entry_heap(ref entry);
    retain_compile_literal_binding(m,ref entry);
    let output_programs::Program kept=switch(output_programs::compile(entry,65536)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    pending_vm::retain_bindings(ref kept,snapshot);
    var vec::Vec<machines::Machine> saved=vec::empty<machines::Machine>();
    var vec::Vec<pending_output::Published> published=vec::empty<pending_output::Published>();
    var output_programs::Completion completed=output_programs::pending_completion(0);
    unsafe{binding_raw(31)};discard step_output_owner(ref mut saved,ref mut completed,ref mut published,ref kept,snapshot,0,0);
    unsafe{binding_raw(33)};discard cancel_output_owner(ref mut saved,0);
    unsafe{binding_raw(32)};let vec::Vec<machines::Machine> compacted=compact_pending_storage(saved);
    unsafe{binding_raw(36)};let vec::Vec<pending_output::Published> cleared=compact_cancelled_storage(published,false);
}
fn void retain_input_binding(){
    let modules::Index index=switch(layout_index(b"module layout;pub fn i32 main(ref u8[] data){return 0;}")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let input_entries::InputEntry entry=switch(input_entries::select_i32_input(index,b"layout",b"main")){case .ok(v):{v}case .err(_):{assert(false);return;}};
    unsafe{binding_raw(20)};discard input_entry_heap(ref entry);
    input_programs::retain_proof_binding(ref entry);
}
fn void retain_compile_literal_binding(ref mut Meta m,ref entries::Entry entry){
    let source_work::State source=source_work::begin(true);
    var literal_work::State literals=literal_work::empty();
    var images::Builder builder=images::full_builder();
    var signature_scan::State signatures=signature_scan::indexed(0,false);
    var metadata_budget::State meter=metadata_budget::empty();
    let ref modules::Index index=entries::index(entry);
    unsafe{binding_raw(48)};discard advance_compile_literals_inner(m,index,ref source,ref mut literals,
        ref mut builder,ref mut signatures,ref mut meter,true);
    retain_compile_body_binding(m,entry,ref source,ref literals);
    programs::retain_proof_binding(entry);
    output_programs::retain_proof_bindings(modules::snapshot(index));
}
fn void retain_compile_body_binding(ref mut Meta m,ref entries::Entry entry,ref source_work::State source,ref literal_work::State literals){
    var signature_scan::State signatures=signature_scan::indexed(0,false);
    var compile_ir::Program code=compile_ir::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    var compiler::BodyProgress progress=compiler::begin_module_bodies();
    var lexer::State token=lexer::empty();var locals::Table names=locals::empty();
    var loops::State flow=loops::empty();var body_work::State cursor=body_work::begin(0,false);
    var metadata_budget::State meter=metadata_budget::empty();
    let ref modules::Index index=entries::index(entry);
    unsafe{binding_raw(49)};discard advance_compile_body_inner(m,index,source,false,false,literals,ref mut signatures,ref mut code,
        ref mut progress,ref mut token,ref mut names,ref mut flow,ref mut cursor,ref mut meter,0);
}
fn void retain_compile_input_bindings(ref mut Meta m){
    var vec::Vec<CompileWork> jobs=vec::empty<CompileWork>();
    var vec::Vec<Program> programs=vec::empty<Program>();
    var vec::Vec<input_entries::InputEntry> selected=vec::empty<input_entries::InputEntry>();
    var vec::Vec<input_entries::InputEntry> incoming=vec::empty<input_entries::InputEntry>();
    unsafe{binding_raw(54)};discard begin_compile_input_inner(m,ref mut jobs,ref mut selected,ref mut incoming,0,0,0);
    var vec::Vec<programs::Lowered> candidate=vec::empty<programs::Lowered>();
    unsafe{binding_raw(55)};discard step_compile_input_inner(m,ref mut programs,ref mut jobs,ref mut selected,ref mut candidate,0);
    unsafe{binding_raw(56)};discard end_compile_input_inner(m,ref mut jobs,ref mut selected,ref mut candidate,0,false);
    unsafe{binding_raw(57)};let vec::Vec<input_entries::InputEntry> cleared=reset_compile_input_storage(selected);
}
pub fn void retain_native_bindings(){
    let control::Budget storage=switch(control::create(1,0)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let memory::Budget retained_storage=switch(memory::create(memory::defaults(),0)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let live::Budget payloads=switch(live::create(live::Limits{.instance=268435456,.instances=536870912})){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var Meta m=Meta{.limits=Limits{.programs=1,.instances=1,.fuel=256},.thread=0,.lifetime=0,.active=0,.admission=1,.next=1,.result=0,.error=error(0),.event=pending(),.snapshot=empty_snapshot(),.closed=false,.control=storage,.programs=retained_storage,.heap=payloads,.configured=false,.poisoned=false};
    retain_compile_input_bindings(ref mut m);
    var vec::Vec<Program> p=vec::empty<Program>();var vec::Vec<Program> scratch=vec::empty<Program>();
    var vec::Vec<Instance> v=vec::empty<Instance>();var vec::Vec<entries::Entry> input=vec::empty<entries::Entry>();
    var vec::Vec<BoundInput> bound=vec::empty<BoundInput>();var vec::Vec<BoundInput> bound_scratch=vec::empty<BoundInput>();
    var vec::Vec<Output> outputs=vec::empty<Output>();var vec::Vec<Output> output_scratch=vec::empty<Output>();
    unsafe{binding_raw(1)};discard bind_inner(ref mut m,1,1);
    unsafe{binding_raw(2)};discard begin_inner(ref mut m,1,1);
    unsafe{binding_raw(3)};discard end_inner(ref mut m,1,1,1);
    unsafe{binding_raw(4)};discard compile_inner(ref mut m,ref mut p,ref mut input,0,0);
    unsafe{binding_raw(5)};discard dispatch_inner(ref mut m,ref mut p,ref mut scratch,ref mut v,ref mut bound,ref mut bound_scratch,ref mut outputs,ref mut output_scratch,8,0,0);
    unsafe{binding_raw(8)};discard maintenance_inner(ref mut m,ref mut p,ref mut scratch,ref mut v,ref mut bound,ref mut bound_scratch,ref mut outputs,ref mut output_scratch,1,1,8,0,0);
    unsafe{binding_raw(21)};discard compile_preflight_inner(ref mut m,ref p,0,0,0);
    unsafe{binding_raw(6)};let vec::Vec<Program> empty_programs=reset_program_storage(p);
    unsafe{binding_raw(7)};let vec::Vec<Instance> empty_instances=reset_instance_storage(v);
    var vec::Vec<input_entries::InputEntry> input_entry=vec::empty<input_entries::InputEntry>();
    var vec::Vec<Program> input_program=vec::empty<Program>();
    var vec::Vec<Instance> input_instances=vec::empty<Instance>();
    unsafe{binding_raw(9)};discard compile_input_inner(ref mut m,ref mut input_program,ref mut input_entry,0,0);
    var usize budget=0;
    let input_bytes::Snapshot snapshot=switch(input_bytes::snapshot(b"",0,0,ref mut budget)){
        case .ok(value):{value}case .err(_):{assert(false);return;}
    };
    unsafe{binding_raw(23)};discard input_preflight_inner(ref mut m,ref input_program,ref mut input_instances,0,0,ref snapshot,0,0,0,1,ref bound,ref outputs);
    unsafe{binding_raw(10)};discard execute_borrowed_input_inner(ref mut m,ref input_program,ref mut input_instances,ref bound,0,ref snapshot,ref outputs);
    var vec::Vec<input_bytes::Snapshot> incoming_snapshot=vec::empty<input_bytes::Snapshot>();
    unsafe{binding_raw(11)};discard input_instance_inner(ref mut m,ref mut input_program,ref mut input_instances,ref mut bound,ref mut incoming_snapshot,0,0,ref outputs);
    unsafe{binding_raw(12)};let vec::Vec<BoundInput> empty_inputs=reset_input_storage(bound);
    var vec::Vec<Program> output_program=vec::empty<Program>();var vec::Vec<Instance> output_instances=vec::empty<Instance>();
    var vec::Vec<entries::Entry> output_entry=vec::empty<entries::Entry>();
    var vec::Vec<input_entries::InputEntry> output_input_entry=vec::empty<input_entries::InputEntry>();
    var vec::Vec<BoundInput> output_input=vec::empty<BoundInput>();
    unsafe{binding_raw(13)};discard compile_output_inner(ref mut m,ref mut output_program,ref mut output_entry,0,0);
    unsafe{binding_raw(14)};discard compile_input_output_inner(ref mut m,ref mut output_program,ref mut output_input_entry,0,1,0);
    unsafe{binding_raw(15)};discard output_instance_inner(ref mut m,ref mut output_program,ref mut output_instances,ref mut output_input,ref mut incoming_snapshot,0,0,0,0,0,ref outputs);
    var vec::Vec<Output> outgoing=vec::empty<Output>();
    unsafe{binding_raw(24)};discard output_preflight_width(ref mut m,ref mut output_instances,ref outputs,0,1,ref output_program);
    unsafe{binding_raw(16)};discard take_output_inner(ref mut m,ref mut output_instances,ref mut outputs,ref mut output_scratch,0,ref mut outgoing,ref output_program);
    unsafe{binding_raw(17)};let vec::Vec<Output> empty_outputs=reset_output_storage(outputs);
    unsafe{binding_raw(18)};discard control_access_inner(ref m,1,1);
    let Instance witness=Instance{.id=0,.program=0,.fuel=0,.phase=0,.output_owned=false,.event=pending(),.output_limit=0,.output_allowed=false,.input_bound=false,.input_bytes=0,.output_bytes=0,.host_terminal=host::empty_scalar_event(),.deadline=0};
    unsafe{binding_raw(22)};discard instance_identity(ref witness);
    let Program program_witness=Program{.id=0,.pins=0,.released=false,.code=vec::empty<programs::Program>(),
        .input=vec::empty<input_programs::Program>(),.output=vec::empty<output_programs::Program>(),.bytes=0,.execution_scratch=0,.entry=empty_entry(),.host=vec::empty<host_program::Program>()};
    unsafe{binding_raw(25)};discard program_identity(ref program_witness);
    let Output output_witness=Output{.instance=0,.run=output_programs::vacant(0),.pending=vec::empty<machines::Machine>(),.host=vec::empty<host::Exchange>()};
    unsafe{binding_raw(30)};discard output_identity(ref output_witness);
    let vec::Vec<policy::Policy> owned=vec::empty<policy::Policy>();
    unsafe{binding_raw(37)};let vec::Vec<policy::Policy> cleared=reset_policy_storage(owned);
    var vec::Vec<host_program::Program> host_incoming=vec::empty<host_program::Program>();
    unsafe{binding_raw(38)};discard publish_host_inner(ref mut m,ref mut output_program,ref mut host_incoming,0,0,0);
    var vec::Vec<Output> host_outputs=vec::empty<Output>();
    retain_host_bindings(ref mut m,ref mut output_program,ref mut output_instances,ref mut host_outputs,ref mut output_scratch);
    retain_output_bindings(ref mut m,ref snapshot);retain_input_binding();
    var vec::Vec<CompileWork> compile_work=vec::empty<CompileWork>();
    var vec::Vec<programs::Lowered> compile_candidate=vec::empty<programs::Lowered>();
    unsafe{binding_raw(42)};discard step_compile_inner(ref mut m,ref mut output_program,ref mut compile_work,ref mut input,ref mut compile_candidate,0);
    unsafe{binding_raw(44)};discard begin_compile_inner(ref mut m,ref mut compile_work,ref mut input,ref mut output_entry,0,0,false);
    unsafe{binding_raw(45)};discard end_compile_inner(ref mut m,ref mut compile_work,ref mut input,ref mut compile_candidate,0,false);
    unsafe{binding_raw(43)};let vec::Vec<entries::Entry> no_entry=reset_compile_storage(input);
    unsafe{binding_raw(46)};let vec::Vec<CompileWork> no_work=reset_compile_work(compile_work);
    unsafe{binding_raw(47)};let vec::Vec<programs::Lowered> no_candidate=reset_compile_candidate(compile_candidate);
}

fn void retain_host_bindings(ref mut Meta m,ref mut vec::Vec<Program> p,
    ref mut vec::Vec<Instance> v,ref mut vec::Vec<Output> outputs,ref mut vec::Vec<Output> output_scratch){
    let ref u8[] policy_json=b"";
    switch(policy::parse(policy_json)){
        case .ok(ceiling):{
            switch(run_config::parse(b"",ref ceiling)){
                case .ok(run):{
                    let vec::Vec<policy::Policy> empty=vec::empty<policy::Policy>();
                    unsafe{binding_raw(39)};discard prepare_host_inner(m,p,v,outputs,ref empty,ref run,0,0,b"",0);
                }
                case .err(_):{}
            };
        }
        case .err(_):{}
    };
    unsafe{binding_raw(40)};discard reply_host_inner(m,p,v,outputs,output_scratch,0,0,0,0,b"",0,0);
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
