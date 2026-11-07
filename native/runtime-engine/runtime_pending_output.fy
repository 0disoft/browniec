module runtime_pending_output;
import slice_result_machine as machines;
import slice_result_execution as pending_execution;
import slice_result_runtime as pending_runtime;
import slice_result_frames as pending_frames;
import input_reference_views as pending_windows;
import static_ir as pending_sites;
import static_image as pending_images;
import ir as pending_ir;
import runtime_output as pending_output;
import output_execution as pending_output_steps;
import std::bytes as pending_bytes;
import slice_result_cursor as pending_cursors;
import module_output_program as output_programs;
import runtime_input as input_bytes;
import source_error as diagnostics;
import errors as errors;
import std::vec as vec;
@link_name("bc_runtime_engine_binding") unsafe extern C fn void binding_raw(u32 number);

// Owning VM continuation prerequisite. The caller pins this exact immutable
// Program and Snapshot until the machine is terminal/dropped. This low-level
// trusted interface is not yet the Instance ID/owner-thread step API.
@link_name("bc_runtime_pending_advance") unsafe extern C fn u32 pending_advance_raw(ptr mut void owner,ptr void program,ptr void input,u32 operation,usize quantum);
@link_name("bc_runtime_pending_maintenance") unsafe extern C fn u32 pending_maintenance_raw(ptr mut void owner,u32 operation,ptr mut void outgoing);
@link_name("bc_runtime_pending_core_stride") unsafe extern C fn usize pending_core_stride_raw();
pub fn usize pending_core_stride(){return unsafe{pending_core_stride_raw()};}
@link_name("bc_runtime_pending_machine_stride") unsafe extern C fn usize pending_machine_stride_raw();
pub fn usize pending_machine_stride(){return unsafe{pending_machine_stride_raw()};}
pub fn Result<machines::Machine,diagnostics::Error> prepare_pending_output(ref output_programs::Program p,ref input_bytes::Snapshot input,usize budget,usize limit,bool allowed){
    let bool accepts=output_programs::accepts_input(p);
    let ref output_programs::Preparation prepared=output_programs::preparation(p);
    var machines::Machine machine=switch(machines::open_prepared(ref output_programs::code(p).body,ref prepared.sites,
        ref prepared.origins,budget,limit,allowed,accepts,input_bytes::view(input).len,ref prepared.list,ref prepared.place,prepared.work)){
        case .ok(v):{v}case .err(e):{return .err(diagnostics::absent(e));}
    };
    let u32 status=unsafe{pending_advance_raw(ref mut machine as ptr mut void,p as ptr void,input as ptr void,0,0)};
    if(status!=0){return .err(diagnostics::absent(errors::make(5,0)));}
    return .ok(machine);
}
pub fn Result<machines::Meta,errors::Error> advance_pending_output(ref mut machines::Machine machine,ref output_programs::Program p,ref input_bytes::Snapshot input,usize quantum){
    if(!pending_cursors::valid_quantum(quantum)){return .err(errors::make(5,0));}
    let u32 status=unsafe{pending_advance_raw(machine as ptr mut void,p as ptr void,input as ptr void,1,quantum)};
    if(status!=0){return .err(errors::make(5,0));}return .ok(machines::observe(machine));
}
pub fn Result<machines::Meta,errors::Error> cancel_pending_output(ref mut machines::Machine machine){
    var vec::Vec<pending_output::Published> unused=vec::empty<pending_output::Published>();
    let u32 status=unsafe{pending_maintenance_raw(machine as ptr mut void,0,ref mut unused as ptr mut void)};
    if(status!=0){return .err(errors::make(5,0));}return .ok(machines::observe(machine));
}
pub fn usize pending_staged_emits(ref machines::Machine m){return machines::staged_emits(m);}
pub fn Result<machines::Meta,errors::Error> seal_pending_output_into(ref mut machines::Machine machine,ref mut vec::Vec<pending_output::Published> outgoing){
    if(machines::observe(machine).phase!=2 || vec::len<pending_output::Published>(outgoing)!=0 ||
        vec::capacity<pending_output::Published>(outgoing)<1){return .err(errors::make(5,0));}
    let u32 status=unsafe{pending_maintenance_raw(machine as ptr mut void,1,outgoing as ptr mut void)};
    let machines::Meta m=machines::observe(machine);
    if(status!=0){return .err(if(m.phase==3){m.failure}else{errors::make(5,0)});}
    return .ok(m);
}
pub fn Result<pending_output::Published,errors::Error> seal_pending_output(ref mut machines::Machine machine){
    if(machines::observe(machine).phase!=2){return .err(errors::make(5,0));}
    var vec::Vec<pending_output::Published> outgoing=vec::empty<pending_output::Published>();
    if(!vec::reserve<pending_output::Published>(ref mut outgoing,1).is_ok){return .err(errors::make(15,0));}
    let machines::Meta sealed=seal_pending_output_into(machine,ref mut outgoing)?;
    return switch(vec::pop<pending_output::Published>(ref mut outgoing)){case .some(v):{.ok(v)}case .none:{.err(errors::make(5,0))}};
}
fn u32 pending_advance_inner(ref output_programs::Program p,ref input_bytes::Snapshot input,
    ref mut machines::Meta m,ref mut pending_frames::Frames bindings,ref mut pending_runtime::State state,ref pending_sites::Sites sites,
    ref u8[] origins,ref mut usize[] live,ref mut u32[] words,ref mut i64[] registers,
    ref mut pending_bytes::Buffer payload,ref mut vec::Vec<i64> cells,ref mut pending_bytes::Buffer scratch,
    ref mut vec::Vec<usize> places,ref mut pending_windows::State windows,ref mut pending_output::Transaction staged,u32 operation,usize quantum){
    if(operation>1 || (operation==0 && m.phase!=0) || (operation==1 && (m.phase!=1 || !pending_cursors::valid_quantum(quantum)))){return 5;}
    let ref pending_ir::Program body=ref output_programs::code(p).body;
    let ref output_programs::Preparation prepared=output_programs::preparation(p);
    let ref u8[] guest=input_bytes::view(input);
    // The pinned compiler treats concurrent loans of sibling fields as loans
    // of Meta. Only these small control values are copied, never ownership maps.
    var usize remaining=m.remaining;var pending_cursors::Cursor cursor=m.cursor;var pending_cursors::Stats statistics=m.stats;
    if(operation==0){
        let Result<usize,errors::Error> entered=pending_execution::start_output_prepared_with_parameters(body,sites,ref prepared.parameters,output_programs::accepts_input(p),guest.len,state,
            pending_bytes::view_mut(payload),bindings,windows,ref mut remaining,ref mut cursor,live,words,registers,prepared.work);
        m.remaining=remaining;m.cursor=cursor;
        switch(entered){
            case .ok(_):{m.phase=1;return 0;}case .err(e):{m.failure=e;}
        };
    }else{
        let Result<Option<pending_execution::Scalar>,errors::Error> progressed=pending_execution::step_output_saved_with_parameters(body,ref prepared.parameters,bindings,state,pending_bytes::view_mut(payload),sites,
            pending_images::payload(output_programs::literals(p)),cells,scratch,places,windows,guest,origins,
            ref mut remaining,staged,ref mut cursor,live,words,registers,quantum,ref mut statistics);
        m.remaining=remaining;m.cursor=cursor;m.stats=statistics;
        switch(progressed){
            case .ok(progress):{switch(progress){
                case .none:{return 0;}case .some(v):{m.phase=2;m.value=v.value;return 0;}
            };}case .err(e):{m.failure=e;}
        };
    }
    pending_execution::abort_saved(state,pending_bytes::view(payload).len,places);
    let pending_output::Observation discarded=pending_output::fail(staged);
    m.phase=3;m.value=0;m.cursor.active=false;return 0;
}
fn u32 pending_maintenance_inner(ref mut machines::Meta m,ref mut pending_runtime::State state,
    ref pending_bytes::Buffer payload,ref mut vec::Vec<usize> places,ref mut pending_output::Transaction staged,
    ref mut vec::Vec<pending_output::Published> outgoing,u32 operation){
    if(operation==0){
        if(m.phase>=2){return 0;}
        pending_execution::abort_saved(state,pending_bytes::view(payload).len,places);
        let pending_output::Observation discarded=pending_output::cancel(staged);
        m.phase=4;m.value=0;m.cursor.active=false;return 0;
    }
    if(operation!=1 || m.phase!=2 || pending_output::observe(staged).phase!=0 || vec::len<pending_output::Published>(outgoing)!=0 ||
        vec::capacity<pending_output::Published>(outgoing)<1){return 5;}
    let pending_output::Published published=switch(pending_output::seal_metered(staged,ref mut m.remaining)){
        case .ok(v):{v}case .err(e):{
            m.failure=pending_output_steps::failure(e,0);m.phase=3;m.value=0;
            let pending_output::Observation discarded=pending_output::fail(staged);return 5;
        }
    };
    assert(vec::push<pending_output::Published>(outgoing,published).is_ok);return 0;
}
pub fn void retain_bindings(ref output_programs::Program p,ref input_bytes::Snapshot input){
    machines::retain_native_initialization();
    let machines::Machine owner=switch(prepare_pending_output(p,input,16000000,0,true)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var machines::Meta m=machines::observe(ref owner);m.phase=0;m.remaining=0;m.cursor=pending_cursors::empty();
    var pending_runtime::State state=pending_runtime::empty(0);var pending_frames::Frames bindings=pending_frames::empty(ref state);
    let pending_sites::Sites sites=pending_sites::empty();let u8[16] origins=[0;16];
    var usize[32] live=[0;32];var u32[512] words=[0;512];var i64[4096] registers=[0;4096];
    var pending_bytes::Buffer payload=pending_bytes::empty();var vec::Vec<i64> cells=vec::empty<i64>();
    var pending_bytes::Buffer scratch=pending_bytes::empty();var vec::Vec<usize> places=vec::empty<usize>();
    var pending_windows::State windows=pending_windows::disabled();var pending_output::Transaction staged=pending_output::disabled();
    unsafe{binding_raw(26)};discard pending_advance_inner(p,input,ref mut m,ref mut bindings,ref mut state,ref sites,ref origins,
        ref mut live,ref mut words,ref mut registers,ref mut payload,ref mut cells,ref mut scratch,ref mut places,ref mut windows,ref mut staged,0,0);
    var vec::Vec<pending_output::Published> outgoing=vec::empty<pending_output::Published>();
    unsafe{binding_raw(27)};discard pending_maintenance_inner(ref mut m,ref mut state,ref payload,ref mut places,ref mut staged,ref mut outgoing,0);
}
