module tests::m2::call_metadata_execution;
import call_work_execution as calls;
import call_metadata_state as staged;
import metadata_budget as budget;
import call_capture_plan as plans;
import call_copy_cursor as call_copy_cursor;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import array_owners as owners;
import array_layout as layouts;
import input_reference_views as inputs;
import static_ir as statics;
import ir as ir;
import errors as errors;
import std::vec as vec;
import call_copy_plan_work as copy_plans;

struct Observed { u8 error; usize offset; usize remaining; usize frame; usize depth; usize used; usize token; usize generation; u8 first; }
fn ir::Program program(){
    var ir::Program p=ir::empty();p.count=2;p.function_count=2;p.starts[0]=0;p.ends[0]=1;p.starts[1]=1;p.ends[1]=2;
    p.register_starts[0]=0;p.register_ends[0]=8;p.register_starts[1]=8;p.register_ends[1]=16;
    p.arities[1]=1;p.array_parameters[8]=1;p.arrays.count=1;p.arrays.elements[0]=2;p.arrays.lengths[0]=4;
    p.call_count=1;p.call_arities[0]=1;p.call_args[0]=128;p.code[0]=9;p.code[1]=0;p.code[2]=1;p.code[3]=0;p.offsets[0]=23;
    return p;
}
// Construct the large value in a short-lived setup frame, then keep its sole
// live instance in SDK storage, like the owning Machine's indirect Core.
fn vec::Vec<ir::Program> program_bank(){
    var vec::Vec<ir::Program> bank=vec::empty<ir::Program>();
    assert(vec::reserve<ir::Program>(ref mut bank,1).is_ok);
    assert(vec::push<ir::Program>(ref mut bank,program()).is_ok);return bank;
}
fn vec::Vec<frames::Frames> frame_bank(ref runtime::State state){
    var vec::Vec<frames::Frames> bank=vec::empty<frames::Frames>();
    assert(vec::reserve<frames::Frames>(ref mut bank,1).is_ok);
    assert(vec::push<frames::Frames>(ref mut bank,frames::empty(state)).is_ok);return bank;
}
fn vec::Vec<staged::State> work_bank(){
    var vec::Vec<staged::State> bank=vec::empty<staged::State>();
    assert(vec::reserve<staged::State>(ref mut bank,1).is_ok);
    assert(vec::push<staged::State>(ref mut bank,staged::empty()).is_ok);return bank;
}
fn vec::Vec<copy_plans::State> plan_bank(){
    var vec::Vec<copy_plans::State> bank=vec::empty<copy_plans::State>();
    assert(vec::reserve<copy_plans::State>(ref mut bank,1).is_ok);
    assert(vec::push<copy_plans::State>(ref mut bank,copy_plans::empty()).is_ok);return bank;
}
struct Outcome { u8 error; usize offset; }
fn Outcome failed(errors::Error e){return Outcome{.error=e.kind,.offset=e.offset};}
fn Outcome ok(){return Outcome{.error=0,.offset=0};}

// This helper owns only the legacy copy cursor. No staged Work or Program or
// frame bank is constructed in this native stack frame.
fn Outcome drive_old(ref ir::Program p,ref statics::Sites sites,ref plans::Plan cache,ref u8[] parameters,
    ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,ref mut inputs::State windows,
    ref mut vec::Vec<usize> places,ref mut usize[] live,ref mut u32[] words,ref mut i64[] registers,
    ref mut usize remaining,usize quantum){
    let Result<call_copy_cursor::State,errors::Error> started=calls::begin(p,parameters,sites,0,bindings,state,64,0,
        words[16..32],live[1],windows,places,remaining,cache);
    var call_copy_cursor::State work=switch(started){case .ok(v):{v}case .err(e):{return failed(e);}};
    var usize iterations=0;while(iterations<128){
        work.last=0;
        let bool done=switch(calls::advance(ref mut work,p,parameters,sites,bindings,state,data,0,
            windows,live,words,registers,remaining,quantum,cache)){
            case .ok(v):{v}case .err(e):{return failed(e);}
        };
        if(done){return ok();}iterations+=1;
    }
    assert(false);return Outcome{.error=99,.offset=0};
}

// Work is borrowed from separate SDK storage and is never copied into the
// fixture or Cursor. Check the original owner at every unpublished boundary.
fn Outcome drive_staged(ref ir::Program p,ref statics::Sites sites,ref plans::Plan cache,ref u8[] parameters,
    ref mut frames::Frames bindings,ref mut runtime::State state,ref mut u8[] data,ref mut inputs::State windows,
    ref mut vec::Vec<usize> places,ref mut usize[] live,ref mut u32[] words,ref mut i64[] registers,
    ref mut usize remaining,usize quantum){
    var vec::Vec<staged::State> bank=work_bank();let ref mut staged::State work=vec::at_mut<staged::State>(ref mut bank,0);
    var vec::Vec<copy_plans::State> plans_storage=plan_bank();let ref mut copy_plans::State copy_plan=vec::at_mut<copy_plans::State>(ref mut plans_storage,0);
    var budget::State allowance=budget::empty();
    switch(calls::begin_staged(work,p,parameters,sites,0,bindings,state,64,0,words[16..32],live[1],windows,places,remaining,cache)){
        case .ok(_) : {} case .err(e):{return failed(e);}
    };
    var usize iterations=0;while(iterations<128){
        let usize reset=switch(budget::reset(ref mut allowance,0)){case .ok(v):{v}case .err(_):{assert(false);0}};
        work.copy.last=0;
        if((work.phase==0 || work.phase==4) && quantum<4096){
            let usize fuel=*remaining;let usize total=work.copy.total;
            let Result<bool,errors::Error> deferred=calls::advance_staged(work,copy_plan,ref mut allowance,p,sites,bindings,state,
                data,windows,live,words,registers,remaining,quantum,parameters,0,places,cache);
            let bool progressed=switch(deferred){case .ok(v):{v}case .err(_):{assert(false);true}};
            assert(!progressed && allowance.last==0 && work.copy.last==0 && work.copy.total==total && *remaining==fuel);
        }
        let Result<bool,errors::Error> result=calls::advance_staged(work,copy_plan,ref mut allowance,p,sites,bindings,state,
            data,windows,live,words,registers,remaining,4096,parameters,0,places,cache);
        assert(work.copy.last+allowance.last<=4096);
        let bool done=switch(result){case .ok(v):{v}case .err(e):{
            assert(!work.active && bindings.frame==1 && state.runtime.owners.depth==1 && state.runtime.owners.arena.used==4);
            return failed(e);
        }};
        if(done){return ok();}
        assert(bindings.frame==1 && state.runtime.owners.depth==1 && state.runtime.owners.arena.used==4);
        iterations+=1;
    }
    assert(false);return Outcome{.error=99,.offset=0};
}

// Runtime/data/banks are separate from the Program and Work setup frames.
fn Observed run(ref ir::Program p,bool use_staged,bool bad,usize quantum){
    let statics::Sites sites=statics::empty();let plans::Plan cache=plans::empty();let u8[16] parameters=[0;16];
    var runtime::State state=runtime::empty(64);var u8[64] data=[0;64];
    let layouts::Array shape=switch(layouts::scalar(2,4)){case .ok(v):{v}case .err(_):{assert(false);return Observed{.error=99,.offset=0,.remaining=0,.frame=0,.depth=0,.used=0,.token=0,.generation=0,.first=0};}};
    let owners::Token source=switch(owners::create(ref shape,0,ref mut data,ref mut state.runtime.owners)){
        case .ok(v):{v}case .err(_):{assert(false);return Observed{.error=99,.offset=0,.remaining=0,.frame=0,.depth=0,.used=0,.token=0,.generation=0,.first=0};}
    };
    if(bad){data[2]=2;}
    let runtime::Capture[1] none=[runtime::capture(frames::none(),false,false)];
    let runtime::Contract contract=runtime::Contract{.tags=[0;8],.arity=0,.selected=0};
    let runtime::Call entry=switch(runtime::enter_call(ref mut state,contract,ref none[..0],64,1000000)){
        case .ok(v):{v}case .err(_):{assert(false);return Observed{.error=99,.offset=0,.remaining=0,.frame=0,.depth=0,.used=0,.token=0,.generation=0,.first=0};}
    };
    var vec::Vec<frames::Frames> stack=frame_bank(ref state);
    let ref mut frames::Frames bindings=vec::at_mut<frames::Frames>(ref mut stack,0);
    assert(frames::push(p,bindings,entry,0,0,0,0).is_ok);bindings.tokens[16]=source;
    var inputs::State windows=inputs::disabled();var vec::Vec<usize> places=vec::empty<usize>();
    var usize[32] live=[0;32];var u32[512] words=[0;512];var i64[4096] registers=[0;4096];var usize remaining=1000000;
    let Outcome result=if(use_staged){drive_staged(p,ref sites,ref cache,ref parameters,bindings,ref mut state,ref mut data,
        ref mut windows,ref mut places,ref mut live,ref mut words,ref mut registers,ref mut remaining,quantum)}
        else{drive_old(p,ref sites,ref cache,ref parameters,bindings,ref mut state,ref mut data,
        ref mut windows,ref mut places,ref mut live,ref mut words,ref mut registers,ref mut remaining,quantum)};
    let owners::Token token=bindings.tokens[32];
    return Observed{.error=result.error,.offset=result.offset,.remaining=remaining,.frame=bindings.frame,
        .depth=state.runtime.owners.depth,.used=state.runtime.owners.arena.used,.token=token.slot,.generation=token.generation,.first=data[4]};
}
fn void equal(Observed a,Observed b){assert(a.error==b.error && a.offset==b.offset && a.remaining==b.remaining &&
    a.frame==b.frame && a.depth==b.depth && a.used==b.used && a.token==b.token && a.generation==b.generation && a.first==b.first);}
@test fn void scalar_bool_owner_call_matches_existing_success_and_error(){
    let vec::Vec<ir::Program> bank=program_bank();let ref ir::Program p=vec::at<ir::Program>(ref bank,0);
    var usize quantum=1;while(quantum<=4){
        let Observed a=run(p,false,false,quantum);let Observed b=run(p,true,false,quantum);
        assert(a.error==0 && a.frame==2 && a.depth==2 && a.used==8);equal(a,b);
        let Observed x=run(p,false,true,quantum);let Observed y=run(p,true,true,quantum);
        assert(x.error!=0 && x.frame==1 && x.depth==1 && x.used==4);equal(x,y);quantum*=2;
    }
}
