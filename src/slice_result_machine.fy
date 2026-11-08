module slice_result_machine;
import ir as ir;
import static_ir as static_ir;
import slice_result_cursor as slice_result_cursor;
import slice_result_frames as slice_result_frames;
import slice_result_runtime as slice_result_runtime;
import call_metadata_state as call_metadata;
import call_copy_plan_work as copy_plans;
import input_reference_views as input_reference_views;
import runtime_output as runtime_output;
import output_execution as output_steps;
import array_vm as backing;
import array_list_vm as lists;
import place_dispatch as places;
import struct_call_vm as owned_calls;
import fuel as meter;
import errors as errors;
import std::vec as vec;
import std::bytes as bytes;

// Trusted callers keep the exact verified Program, image and input alive and
// supply the same references to every step. This carrier is not a public
// authority or Engine API. The parent owns entry, phase changes and publication;
// its native projection supplies disjoint references to the inline Core fields.
pub struct Meta {
    slice_result_cursor::Cursor cursor;
    slice_result_cursor::Stats stats;
    usize remaining;
    // 0 ready for entry, 1 running, 2 success, 3 failed, 4 cancelled.
    u8 phase;
    i64 value;
    errors::Error failure;
}
pub struct Core {
    slice_result_frames::Frames bindings;
    slice_result_runtime::State runtime;
    static_ir::Sites sites;
    u8[16] origins;
    usize[32] static_live;
    u32[512] static_words;
    i64[4096] registers;
    call_metadata::State call_metadata;
    copy_plans::State copy_plan;
}
pub resource Machine {
    bytes::Buffer core;
    bytes::Buffer payload;
    vec::Vec<i64> list_cells;
    bytes::Buffer list_scratch;
    vec::Vec<usize> place_state;
    input_reference_views::State windows;
    runtime_output::Transaction staged;
    Meta meta;
    cleanup { }
}

pub fn Result<Machine,errors::Error> open(ref ir::Program body,ref static_ir::Sites sites,
    ref u8[] origins,usize budget,usize output_limit,bool allowed,bool input,usize input_length){
    let lists::Requirement list=lists::Requirement{.length=0,.bytes=0,.cost=0};
    let places::Requirement place=places::Requirement{.width=0,.cost=0,.aggregate=false,.slices=false,.records=false};
    return open_selected(body,sites,origins,budget,output_limit,allowed,input,input_length,false,ref list,ref place,0);
}
// Only an owning immutable Program supplies these cached plans. The raw helper
// above retains its requirement scans and their original admission ordering.
pub fn Result<Machine,errors::Error> open_prepared(ref ir::Program body,ref static_ir::Sites sites,
    ref u8[] origins,usize budget,usize output_limit,bool allowed,bool input,usize input_length,
    ref lists::Requirement list,ref places::Requirement place,usize work){
    return open_selected(body,sites,origins,budget,output_limit,allowed,input,input_length,true,list,place,work);
}
fn Result<Machine,errors::Error> open_selected(ref ir::Program body,ref static_ir::Sites sites,
    ref u8[] origins,usize budget,usize output_limit,bool allowed,bool input,usize input_length,
    bool cached,ref lists::Requirement cached_list,ref places::Requirement cached_place,usize cached_work){
    // Only dimensions and the entry ABI are checked here. The parent admits the
    // exact code/image; planning below reuses the canonical scratch requirements.
    if(body.count==0 || body.count>256 || body.registers==0 || body.registers>128 ||
        body.constant_count>128 || body.function_count==0 || body.function_count>16 ||
        body.entry>=body.function_count || body.call_count>32 || body.arrays.count>16 ||
        body.records.count>16 || body.records.layouts.count>32 || body.list_used>4096 ||
        sites.count>16 || origins.len!=16){return .err(errors::make(5,0));}
    let usize entry=body.entry;
    let usize start=body.register_starts[entry];
    let usize end=body.register_ends[entry];
    if(body.starts[entry]>=body.ends[entry] || body.ends[entry]>body.count ||
        start>end || end>body.registers || body.arities[entry]!=if(input){1}else{0} ||
        body.arities[entry]>end-start || body.return_types[entry]!=1 ||
        body.array_results[entry]!=0 || body.record_results[entry]!=0 || sites.results[entry]!=0){
        return .err(errors::make(5,0));
    }
    if(input){
        if(start>=128 || sites.parameters[start]!=3 || sites.formal_sites[start]==0 ||
            sites.formal_sites[start]>16 || body.array_parameters[start]!=0 ||
            body.record_parameters[start]!=0 || body.slice_parameters[start]!=0){
            return .err(errors::make(5,0));
        }
    }
    if(output_limit>runtime_output::hard_limit()){return .err(errors::make(20,0));}
    if(!input && input_length!=0){return .err(errors::make(5,0));}
    if(input_length>1048576){return .err(errors::make(4,0));}
    var usize remaining=budget;
    var runtime_output::Transaction staged=switch(runtime_output::open_metered(output_limit,allowed,ref mut remaining)){
        case .ok(value):{value}case .err(e):{return .err(output_steps::failure(e,0));}
    };
    let usize capacity=if(body.arrays.count!=0 || body.records.count!=0){65536}else{0};
    let usize preparation=if(capacity==0){0}else{1+capacity};
    let lists::Requirement list_plan=if(cached){*cached_list}else{lists::requirement(body)?};
    let places::Requirement place_plan=if(cached){*cached_place}else{places::requirement(body)?};
    let usize work=if(cached){cached_work}else{owned_calls::cost(body,entry,0)?+body.arities[entry]};
    let usize input_cost=if(input){meter::input_prepare()}else{0};
    if(remaining<preparation+input_cost+slice_result_runtime::cost()+work+list_plan.cost+place_plan.cost){
        return .err(errors::make(8,0));
    }
    var bytes::Buffer payload=if(capacity==0){bytes::empty()}else{backing::prepare(capacity)?};
    remaining-=preparation;
    let slice_result_runtime::State state=slice_result_runtime::empty(capacity);
    var input_reference_views::State windows=if(input){input_reference_views::open(input_length)?}else{input_reference_views::disabled()};
    remaining-=input_cost;
    var vec::Vec<i64> list_cells=lists::prepare_values(ref list_plan)?;
    var bytes::Buffer list_scratch=lists::prepare_encoded(ref list_plan)?;
    remaining-=list_plan.cost;
    var vec::Vec<usize> place_state=places::prepare_metered(ref place_plan,remaining)?;
    remaining-=place_plan.cost;

    // Exact-sized, aligned native storage avoids constructing/moving a huge
    // Core value and avoids the SDK generic Vec's eight-element minimum.
    // This backing is private typed VM storage, never guest input/output bytes.
    let usize stride=native_size();
    var bytes::Buffer core=switch(bytes::with_capacity(stride)){
        case .ok(v):{v}case .err(_):{return .err(errors::make(15,0));}
    };
    let u8[4096] zero=[0;4096];var usize initialized=0;
    while(initialized<stride){let usize chunk=if(stride-initialized>4096){4096}else{stride-initialized};
        if(!bytes::append(ref mut core,ref zero[..chunk]).is_ok){return .err(errors::make(15,0));}initialized+=chunk;
    }
    var Machine machine=Machine{.core=core,.payload=payload,.list_cells=list_cells,
        .list_scratch=list_scratch,.place_state=place_state,.windows=windows,.staged=staged,
        .meta=Meta{.cursor=slice_result_cursor::empty(),.stats=slice_result_cursor::stats(),
            .remaining=remaining,.phase=0,.value=0,.failure=errors::make(0,0)}};
    let u32 initialized_core=unsafe{initialize_raw(ref mut machine as ptr mut void,ref state as ptr void,sites as ptr void,origins as ptr u8,origins.len)};
    assert(initialized_core==0);return .ok(machine);
}
@link_name("bc_runtime_pending_initialize") unsafe extern C fn u32 initialize_raw(ptr mut void owner,ptr void state,ptr void sites,ptr u8 origins,usize length);
@link_name("bc_runtime_pending_core_stride") unsafe extern C fn usize native_size_raw();
fn usize native_size(){return unsafe{native_size_raw()};}
pub fn Meta observe(ref Machine machine){return machine.meta;}
pub fn usize staged_emits(ref Machine machine){return runtime_output::observe(ref machine.staged).emits;}
pub fn usize core_heap_bytes(ref Machine machine,usize stride){
    assert(stride==native_size() && bytes::view(ref machine.core).len==stride);
    return bytes::capacity(ref machine.core);
}
// Typed private transport helpers. The C shim only projects live addresses;
// initialization and metadata decisions remain here in Fairy.
pub fn void initialize_native(ref Machine owner,ref mut Core core,ref slice_result_runtime::State state,ref static_ir::Sites sites,ref u8[] origins){
    unsafe{binding_raw(29)};
    core.runtime=*state;slice_result_frames::initialize(ref mut core.bindings,state);core.sites=*sites;
    core.call_metadata=call_metadata::empty();core.copy_plan=copy_plans::empty();
    var usize i=0;while(i<16){core.origins[i]=origins[i];i+=1;}
    unsafe{binding_raw(28)};discard storage_identity(owner,core);
}
fn usize storage_identity(ref Machine owner,ref Core core){return bytes::capacity(ref owner.core);}
@link_name("bc_runtime_engine_binding") unsafe extern C fn void binding_raw(u32 number);

// The pinned MIR builder discovers native typed helpers through source calls.
// This cold witness retains types only: sizeof(Core) is nonzero, so no Core
// value is ever materialized on the actual initialization/execution stack.
pub fn void retain_native_initialization(){if(native_size()==0){retain_core_types();}}
fn void retain_core_types(){
    let slice_result_runtime::State state=slice_result_runtime::empty(0);let static_ir::Sites sites=static_ir::empty();
    let u8[16] origins=[0;16];
    var Core core=Core{.bindings=slice_result_frames::empty(ref state),.runtime=state,.sites=sites,
        .origins=[0;16],.static_live=[0;32],.static_words=[0;512],.registers=[0;4096],.call_metadata=call_metadata::empty(),.copy_plan=copy_plans::empty()};
    let Machine owner=Machine{.core=bytes::empty(),.payload=bytes::empty(),.list_cells=vec::empty<i64>(),
        .list_scratch=bytes::empty(),.place_state=vec::empty<usize>(),.windows=input_reference_views::disabled(),
        .staged=runtime_output::disabled(),.meta=Meta{.cursor=slice_result_cursor::empty(),.stats=slice_result_cursor::stats(),
        .remaining=0,.phase=0,.value=0,.failure=errors::make(0,0)}};
    initialize_native(ref owner,ref mut core,ref state,ref sites,ref origins);
}
