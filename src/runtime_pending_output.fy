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
import call_metadata_state as pending_call_metadata;
import call_copy_plan_work as copy_plans;
import module_output_program as output_programs;
import runtime_input as input_bytes;
import source_error as diagnostics;
import errors as errors;
import metadata_budget as metadata_budget;
import runtime_lifecycle_work as lifecycle;
import runtime_setup_work as setup_work;
import runtime_preparation_work as preparation_work;
import runtime_cleanup_work as cleanup_work;
import runtime_seal_work as seal_work;
import runtime_metadata_work as metadata_work;
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
    return prepare_with_frame_limit(p,input,budget,limit,allowed,31);
}
pub fn Result<machines::Machine,diagnostics::Error> prepare_with_frame_limit(ref output_programs::Program p,ref input_bytes::Snapshot input,usize budget,usize limit,bool allowed,usize frame_limit){
    let bool accepts=output_programs::accepts_input(p);
    let ref output_programs::Preparation prepared=output_programs::preparation(p);
    var machines::Machine machine=switch(machines::open_prepared(ref output_programs::code(p).body,ref prepared.sites,
        ref prepared.origins,budget,limit,allowed,accepts,input_bytes::view(input).len,ref prepared.list,ref prepared.place,prepared.work,frame_limit)){
        case .ok(v):{v}case .err(e):{return .err(diagnostics::absent(e));}
    };
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
pub fn Result<machines::Meta,errors::Error> expire_pending_output(ref mut machines::Machine machine){
    var vec::Vec<pending_output::Published> unused=vec::empty<pending_output::Published>();
    let u32 status=unsafe{pending_maintenance_raw(machine as ptr mut void,2,ref mut unused as ptr mut void)};
    if(status!=0){return .err(errors::make(5,0));}return .ok(machines::observe(machine));
}
pub fn usize pending_staged_emits(ref machines::Machine m){return machines::staged_emits(m);}
pub fn Result<machines::Meta,errors::Error> seal_pending_output_into(ref mut machines::Machine machine,ref mut vec::Vec<pending_output::Published> outgoing){
    if(machines::observe(machine).phase!=2 || vec::len<pending_output::Published>(outgoing)!=0 ||
        vec::capacity<pending_output::Published>(outgoing)<1){return .err(errors::make(5,0));}
    let u32 status=unsafe{pending_maintenance_raw(machine as ptr mut void,1,outgoing as ptr mut void)};
    let machines::Meta m=machines::observe(machine);
    if(status!=0){return .err(if(m.lifecycle.terminal==3 || m.phase==3){m.failure}else{errors::make(5,0)});}
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
    ref u8[] origins,ref mut usize[] live,ref mut u32[] words,ref mut i64[] registers,ref mut pending_call_metadata::State call_metadata,ref mut copy_plans::State copy_plan,
    ref mut pending_bytes::Buffer payload,ref mut vec::Vec<i64> cells,ref mut pending_bytes::Buffer scratch,
    ref mut vec::Vec<usize> places,ref mut pending_windows::State windows,ref mut pending_output::Transaction staged,u32 operation,usize quantum){
    return switch(pending_advance_impl(p,input,m,bindings,state,sites,origins,live,words,registers,call_metadata,copy_plan,payload,cells,scratch,places,windows,staged,operation,quantum)){case .ok(_):{0}case .err(_):{5}};
}
fn Result<usize,errors::Error> pending_advance_impl(ref output_programs::Program p,ref input_bytes::Snapshot input,
    ref mut machines::Meta m,ref mut pending_frames::Frames bindings,ref mut pending_runtime::State state,ref pending_sites::Sites sites,
    ref u8[] origins,ref mut usize[] live,ref mut u32[] words,ref mut i64[] registers,ref mut pending_call_metadata::State call_metadata,ref mut copy_plans::State copy_plan,
    ref mut pending_bytes::Buffer payload,ref mut vec::Vec<i64> cells,ref mut pending_bytes::Buffer scratch,
    ref mut vec::Vec<usize> places,ref mut pending_windows::State windows,ref mut pending_output::Transaction staged,u32 operation,usize quantum){
    if(operation>1 || (operation==0 && m.phase!=0) || (operation==1 && (m.phase!=1 || !pending_cursors::valid_quantum(quantum)))){return .err(errors::make(5,0));}
    let ref pending_ir::Program body=ref output_programs::code(p).body;
    let ref output_programs::Preparation prepared=output_programs::preparation(p);
    let ref u8[] guest=input_bytes::view(input);
    if(m.lifecycle.phase>=7){let u32 status=finish_stage(m,state,ref mut call_metadata.metadata,places,staged,quantum);return .ok(0);}
    var usize remaining=m.remaining;var pending_cursors::Cursor cursor=m.cursor;var pending_cursors::Stats statistics=m.stats;
    if(m.lifecycle.phase==6){
        let usize admitted=pending_cursors::begin(ref mut statistics,quantum)?;
        reset_counters(ref mut cursor);let usize reset=metadata_budget::reset(ref mut cursor.metadata,0)?;
        // Only a constant control handoff here. The owning caller immediately
        // seals using this fresh allowance; no work credit is retained or spent.
        let usize finished=pending_cursors::finish(ref mut statistics,1,false)?;
        m.cursor=cursor;m.stats=statistics;m.phase=2;m.lifecycle.phase=11;m.cursor.active=false;return .ok(0);
    }
    if(operation==0 || m.lifecycle.phase==4){
        if(operation==1){let usize admitted=pending_cursors::begin(ref mut statistics,quantum)?;
            reset_counters(ref mut cursor);let usize reset=metadata_budget::reset(ref mut cursor.metadata,0)?;
            assert(metadata_budget::admit(ref mut cursor.metadata,4096,0)?);}
        cursor.active=false;
        let Result<usize,errors::Error> entered=pending_execution::start_output_prepared_with_parameters(body,sites,ref prepared.parameters,output_programs::accepts_input(p),guest.len,state,
            pending_bytes::view_mut(payload),bindings,windows,ref mut remaining,ref mut cursor,live,words,registers,prepared.work);
        m.remaining=remaining;m.cursor=cursor;
        switch(entered){case .ok(_):{m.phase=1;m.lifecycle.phase=5;
            if(operation==1){let usize recorded=pending_cursors::finish(ref mut statistics,1,true)?;m.stats=statistics;}return .ok(0);}
            case .err(e):{m.failure=e;}};
        if(operation==1){let usize recorded=pending_cursors::finish(ref mut statistics,1,true)?;m.stats=statistics;}
    }else{
        let Result<Option<pending_execution::Scalar>,errors::Error> progressed=pending_execution::step_output_cached_staged(body,ref prepared.parameters,bindings,state,pending_bytes::view_mut(payload),sites,
            pending_images::payload(output_programs::literals(p)),cells,scratch,places,windows,guest,origins,
            ref mut remaining,staged,ref mut cursor,live,words,registers,quantum,ref mut statistics,ref output_programs::preparation(p).calls,call_metadata,copy_plan);
        m.remaining=remaining;m.cursor=cursor;m.stats=statistics;
        switch(progressed){case .ok(progress):{switch(progress){case .none:{return .ok(0);}
            case .some(v):{m.lifecycle.phase=6;m.value=v.value;if(m.stats.yields<m.stats.calls){m.stats.yields+=1;}m.cursor.active=true;return .ok(0);}};}
            case .err(e):{m.failure=e;}};
    }
    m.lifecycle.terminal=3;m.lifecycle.phase=7;m.cursor.active=true;
    if(m.stats.last==0){m.stats.last=1;m.stats.dispatched+=1;if(m.stats.maximum==0){m.stats.maximum=1;}}
    if(m.stats.yields<m.stats.calls){m.stats.yields+=1;}return .ok(0);
}
fn void reset_counters(ref mut pending_cursors::Cursor cursor){
    cursor.output.last=0;cursor.array.last=0;cursor.call.last=0;cursor.returned.last=0;
}
// u32 transport wrappers cannot use Result propagation; their bodies remain
// separate from the fallible staged implementation below.
fn Result<usize,errors::Error> setup_stage(ref output_programs::Program p,ref input_bytes::Snapshot input,
    ref mut machines::Meta m,ref mut pending_bytes::Buffer core,ref mut pending_bytes::Buffer payload,
    ref mut vec::Vec<i64> cells,ref mut pending_bytes::Buffer scratch,ref mut vec::Vec<usize> places,
    ref mut pending_windows::State windows,usize quantum){
    if(m.phase!=1 || m.lifecycle.phase>2){return .err(errors::make(5,0));}
    var lifecycle::State flow=m.lifecycle;var pending_cursors::Cursor cursor=m.cursor;var pending_cursors::Stats statistics=m.stats;
    let usize admitted=pending_cursors::begin(ref mut statistics,quantum)?;reset_counters(ref mut cursor);
    let usize reset=metadata_budget::reset(ref mut cursor.metadata,0)?;
    let ref output_programs::Preparation prepared=output_programs::preparation(p);
    if(flow.phase==0){
        if(preparation_work::advance(ref mut flow.proof,ref output_programs::code(p).body,ref prepared.sites,
            ref prepared.parameters,ref prepared.list,ref prepared.place,prepared.work,prepared.capacity,
            ref prepared.calls,output_programs::accepts_input(p),ref mut cursor.metadata)?){flow.phase=1;}
    }else if(flow.phase==1){
        if(setup_work::advance(ref mut flow.setup,core,payload,cells,scratch,places,ref mut cursor.metadata)?){flow.phase=2;}
    }else{
        if(!output_programs::accepts_input(p)){
            assert(metadata_budget::admit(ref mut cursor.metadata,4096,0)?);flow.phase=3;flow.index=0;
        }else if(pending_windows::initialize_chunk(windows,ref mut cursor.metadata)?){flow.phase=3;flow.index=0;}
    }
    let usize recorded=pending_cursors::finish(ref mut statistics,1,true)?;
    m.lifecycle=flow;m.cursor=cursor;m.stats=statistics;return .ok(0);
}
fn u32 pending_setup_inner(ref output_programs::Program p,ref input_bytes::Snapshot input,
    ref mut machines::Meta m,ref mut pending_bytes::Buffer core,ref mut pending_bytes::Buffer payload,
    ref mut vec::Vec<i64> cells,ref mut pending_bytes::Buffer scratch,ref mut vec::Vec<usize> places,
    ref mut pending_windows::State windows,ref mut pending_output::Transaction staged,usize quantum){
    switch(setup_stage(p,input,m,core,payload,cells,scratch,places,windows,quantum)){
        case .ok(_):{return 0;}case .err(e):{m.failure=e;m.phase=3;m.lifecycle.terminal=3;m.lifecycle.phase=11;
            m.cursor.active=false;let pending_output::Observation dropped=pending_output::fail(staged);return 0;}};
    return 5;
}
fn u32 pending_core_setup_inner(ref output_programs::Program p,ref mut machines::Meta m,ref mut machines::Core core,usize quantum){
    var pending_cursors::Cursor cursor=m.cursor;var pending_cursors::Stats statistics=m.stats;
    if(m.phase!=1 || m.lifecycle.phase!=3 || m.lifecycle.index>=49){return 5;}
    if(!pending_cursors::begin(ref mut statistics,quantum).is_ok){return 5;}reset_counters(ref mut cursor);
    if(!metadata_budget::reset(ref mut cursor.metadata,0).is_ok){return 5;}
    if(!metadata_budget::admit(ref mut cursor.metadata,4096,0).is_ok){return 5;}
    let ref output_programs::Preparation prepared=output_programs::preparation(p);
    if(machines::initialize_staged(core,m.lifecycle.index,prepared.capacity,ref prepared.sites,ref prepared.origins)){m.lifecycle.phase=4;}
    m.lifecycle.index+=1;assert(pending_cursors::finish(ref mut statistics,1,true).is_ok);
    m.cursor=cursor;m.stats=statistics;return 0;
}
fn Result<usize,errors::Error> finish_stage_impl(ref mut machines::Meta m,ref mut pending_runtime::State state,
    ref mut metadata_work::State bank,ref mut vec::Vec<usize> places,ref mut pending_output::Transaction staged,usize quantum){
    var lifecycle::State flow=m.lifecycle;var pending_cursors::Cursor cursor=m.cursor;var pending_cursors::Stats statistics=m.stats;
    let usize admitted=pending_cursors::begin(ref mut statistics,quantum)?;reset_counters(ref mut cursor);
    let usize reset=metadata_budget::reset(ref mut cursor.metadata,0)?;
    if(flow.phase==7){assert(metadata_budget::admit(ref mut cursor.metadata,4096,0)?);
        let usize capacity=flow.setup.plan.payload;let usize begun=cleanup_work::begin(ref mut flow.cleaning,capacity)?;flow.phase=8;
    }else if(flow.phase==8){
        if(cleanup_work::advance(ref mut flow.cleaning,ref mut bank.planned,state,ref mut cursor.metadata)?){
            flow.phase=9;flow.place=vec::len<usize>(places)%32;}
    }else if(flow.phase==9){assert(metadata_budget::admit(ref mut cursor.metadata,4096,0)?);
        let ref mut usize[] words=vec::view_mut_usize(places);let usize count=if(words.len-flow.place>256){256}else{words.len-flow.place};
        var usize i=0;while(i<count){words[flow.place+i]=0;i+=1;}flow.place+=count;
        if(flow.place==words.len){flow.phase=10;}
    }else if(flow.phase==10){assert(metadata_budget::admit(ref mut cursor.metadata,4096,0)?);
        cleanup_work::publish(ref flow.cleaning,ref bank.planned,state);
        let pending_output::Observation discarded=if(flow.terminal==4){pending_output::cancel(staged)}else{pending_output::fail(staged)};
        m.phase=flow.terminal;m.value=0;cursor.active=false;flow.phase=11;
    }else{return .err(errors::make(5,0));}
    let usize recorded=pending_cursors::finish(ref mut statistics,1,m.phase==1)?;
    m.lifecycle=flow;m.cursor=cursor;m.stats=statistics;return .ok(0);
}
fn u32 finish_stage(ref mut machines::Meta m,ref mut pending_runtime::State state,ref mut metadata_work::State bank,
    ref mut vec::Vec<usize> places,ref mut pending_output::Transaction staged,usize quantum){
    switch(finish_stage_impl(m,state,bank,places,staged,quantum)){case .ok(_):{return 0;}case .err(_):{
        // Invalid private cleanup never publishes its partial plan or replaces
        // the first terminal cause. Dropping the sole owner releases storage.
        m.lifecycle.cleanup_failed=true;
        m.phase=m.lifecycle.terminal;m.lifecycle.phase=11;m.value=0;m.cursor.active=false;
        let pending_output::Observation dropped=if(m.phase==4){pending_output::cancel(staged)}else{pending_output::fail(staged)};return 0;}};
    return 5;
}
fn u32 pending_maintenance_inner(ref mut machines::Meta m,ref mut pending_runtime::State state,
    ref pending_bytes::Buffer payload,ref mut vec::Vec<usize> places,ref mut pending_output::Transaction staged,
    ref mut vec::Vec<pending_output::Published> outgoing,u32 operation,ref mut metadata_work::State bank){
    if(operation==2){
        if(m.phase>=3 || m.lifecycle.terminal!=0){return 0;}
        m.failure=errors::absent(errors::deadline_kind(),0);
        m.lifecycle.terminal=3;m.value=0;
        if(m.lifecycle.phase<4){
            let pending_output::Observation dropped=pending_output::fail(staged);
            m.phase=3;m.cursor.active=false;m.lifecycle.phase=11;return 0;
        }
        // Latch the deadline without spending a second work allowance.
        m.phase=1;m.lifecycle.phase=7;m.cursor.active=true;return 0;
    }
    if(operation==0){
        if(m.phase>=2){return 0;}
        if(m.lifecycle.terminal==0){m.lifecycle.terminal=4;
            if(m.lifecycle.phase<4){
                let pending_output::Observation dropped=pending_output::cancel(staged);
                m.phase=4;m.value=0;m.cursor.active=false;m.lifecycle.phase=11;return 0;
            }m.lifecycle.phase=7;m.cursor.active=true;
        }
        return finish_stage(m,state,bank,places,staged,1);
    }
    if(operation!=1 || m.phase!=2){return 5;}
    var pending_cursors::Cursor cursor=m.cursor;var usize remaining=m.remaining;
    switch(seal_work::advance(staged,outgoing,ref mut remaining,ref mut cursor.metadata)){
        case .ok(done):{if(!done){return 5;}m.cursor=cursor;m.remaining=remaining;return 0;}
        case .err(e):{m.cursor=cursor;m.remaining=remaining;m.failure=e;m.phase=1;m.value=0;
            m.lifecycle.terminal=3;m.lifecycle.phase=7;m.cursor.active=true;if(m.stats.yields<m.stats.calls){m.stats.yields+=1;}return 5;}
    };
    return 5;
}
pub fn void retain_bindings(ref output_programs::Program p,ref input_bytes::Snapshot input){
    machines::retain_native_initialization();
    // Declaration/type witnesses are cold, just like Core's initialization
    // witness. Actual Engine tests exercise these helpers through heap Core
    // projections; constructing duplicate flat banks here spends native stack.
    if(pending_core_stride()==0){retain_advance_types(p,input);retain_core_setup_types(p,input);}
}
fn void retain_advance_types(ref output_programs::Program p,ref input_bytes::Snapshot input){
    let machines::Machine owner=switch(prepare_pending_output(p,input,16000000,0,true)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var machines::Meta m=machines::observe(ref owner);m.phase=0;m.remaining=0;m.cursor=pending_cursors::empty();
    var pending_runtime::State state=pending_runtime::empty(0);var pending_frames::Frames bindings=pending_frames::empty(ref state);
    let pending_sites::Sites sites=pending_sites::empty();let u8[16] origins=[0;16];
    var usize[32] live=[0;32];var u32[512] words=[0;512];var i64[4096] registers=[0;4096];
    var pending_call_metadata::State call_metadata=pending_call_metadata::empty();var copy_plans::State copy_plan=copy_plans::empty();
    var pending_bytes::Buffer payload=pending_bytes::empty();var vec::Vec<i64> cells=vec::empty<i64>();
    var pending_bytes::Buffer scratch=pending_bytes::empty();var vec::Vec<usize> places=vec::empty<usize>();
    var pending_windows::State windows=pending_windows::disabled();var pending_output::Transaction staged=pending_output::disabled();
    var pending_bytes::Buffer core_storage=pending_bytes::empty();
    unsafe{binding_raw(34)};discard pending_setup_inner(p,input,ref mut m,ref mut core_storage,ref mut payload,
        ref mut cells,ref mut scratch,ref mut places,ref mut windows,ref mut staged,1);
    unsafe{binding_raw(26)};discard pending_advance_inner(p,input,ref mut m,ref mut bindings,ref mut state,ref sites,ref origins,
        ref mut live,ref mut words,ref mut registers,ref mut call_metadata,ref mut copy_plan,ref mut payload,ref mut cells,ref mut scratch,ref mut places,ref mut windows,ref mut staged,0,0);
    var vec::Vec<pending_output::Published> outgoing=vec::empty<pending_output::Published>();
    unsafe{binding_raw(27)};discard pending_maintenance_inner(ref mut m,ref mut state,ref payload,ref mut places,ref mut staged,ref mut outgoing,0,ref mut call_metadata.metadata);
}

pub fn void retain_core_setup(ref output_programs::Program p,ref mut machines::Meta m,ref mut machines::Core core){
    unsafe{binding_raw(35)};discard pending_core_setup_inner(p,m,core,1);
}

fn void retain_core_setup_types(ref output_programs::Program p,ref input_bytes::Snapshot input){
    var machines::Core core=machines::cold_core();let machines::Machine owner=switch(prepare_pending_output(p,input,16000000,0,true)){
        case .ok(v):{v}case .err(_):{return;}};
    var machines::Meta m=machines::observe(ref owner);retain_core_setup(p,ref mut m,ref mut core);
}
