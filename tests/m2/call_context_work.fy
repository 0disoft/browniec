module tests::m2::call_context_work;
import call_context_work as context;
import call_argument_work as arguments;
import call_owned_work as owned_work;
import call_work_execution as raw;
import call_capture_plan as plans;
import slice_result_owned_execution as owned;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import array_owners as owners;
import array_slices as slices;
import input_reference_views as inputs;
import static_views as views;
import static_ir as statics;
import place_vm as places;
import metadata_budget as budget;
import fuel as meter;
import ir as ir;
import errors as errors;
import std::vec as vec;

struct Outcome { u8 error; usize offset; usize remaining; usize captured; usize count; bool done; }
fn Outcome failure(errors::Error e,usize remaining){return Outcome{.error=e.kind,.offset=e.offset,.remaining=remaining,.captured=0,.count=0,.done=false};}
fn Outcome success(usize remaining,usize captured,usize count){return Outcome{.error=0,.offset=0,.remaining=remaining,.captured=captured,.count=count,.done=true};}
fn ir::Program program(bool scalar){
    var ir::Program p=ir::empty();let usize arity=if(scalar){1}else{0};let u8 encoded=if(scalar){1}else{0};
    p.count=2;p.function_count=2;p.registers=16;p.starts[0]=0;p.ends[0]=1;p.starts[1]=1;p.ends[1]=2;
    p.register_starts[0]=0;p.register_ends[0]=8;p.register_starts[1]=8;p.register_ends[1]=16;
    p.arities[1]=arity;p.call_count=1;p.call_arities[0]=encoded;p.call_args[0]=0;
    p.return_types[0]=1;p.return_types[1]=1;p.types[0]=1;p.types[8]=1;
    p.code[0]=9;p.code[2]=1;p.code[8]=8;p.offsets[0]=73;p.offsets[1]=74;return p;
}
// Setup constructors and native aggregate return slots have separate short-lived
// frames. No large Program, Frames, Runtime or Work value lives in the test root.
fn vec::Vec<ir::Program> program_bank(bool scalar){
    var vec::Vec<ir::Program> bank=vec::empty<ir::Program>();assert(vec::reserve<ir::Program>(ref mut bank,1).is_ok);
    assert(vec::push<ir::Program>(ref mut bank,program(scalar)).is_ok);return bank;
}
fn vec::Vec<runtime::State> runtime_bank(){
    var vec::Vec<runtime::State> bank=vec::empty<runtime::State>();assert(vec::reserve<runtime::State>(ref mut bank,1).is_ok);
    assert(vec::push<runtime::State>(ref mut bank,runtime::empty(64)).is_ok);return bank;
}
fn Result<vec::Vec<frames::Frames>,errors::Error> frame_bank(ref ir::Program p,ref mut runtime::State state,usize fault){
    let runtime::Contract root=runtime::Contract{.tags=[0;8],.arity=0,.selected=0};
    let runtime::Capture[1] none=[runtime::capture(frames::none(),false,false)];
    let runtime::Call entry=runtime::enter_call(state,root,ref none[..0],64,1000000)?;
    var vec::Vec<frames::Frames> bank=vec::empty<frames::Frames>();assert(vec::reserve<frames::Frames>(ref mut bank,1).is_ok);
    assert(vec::push<frames::Frames>(ref mut bank,frames::empty(state)).is_ok);
    {
        let ref mut frames::Frames f=vec::at_mut<frames::Frames>(ref mut bank,0);
        let usize child=frames::push(p,f,entry,0,0,0,0)?;assert(child==1);
        // Exhaustion sentinels must fail before runtime authority validation.
        if(fault==1){f.frame=31;}
    }
    if(fault==2){state.runtime.authority.depth=31;}
    return .ok(bank);
}
fn vec::Vec<context::State> work_bank(){
    var vec::Vec<context::State> bank=vec::empty<context::State>();assert(vec::reserve<context::State>(ref mut bank,1).is_ok);
    assert(vec::push<context::State>(ref mut bank,context::empty()).is_ok);return bank;
}
fn Result<vec::Vec<usize>,errors::Error> place_bank(usize mode){
    var vec::Vec<usize> bank=if(mode==2){places::prepare_format(1,false)?}else{vec::empty<usize>()};
    if(mode==1){assert(vec::push<usize>(ref mut bank,0).is_ok);}
    if(mode==2){let ref mut usize[] words=vec::view_mut_usize(ref mut bank);words[20]=1;}
    return .ok(bank);
}
fn Result<inputs::State,errors::Error> window_bank(bool enabled){
    var inputs::State windows=if(enabled){inputs::open(0)?}else{inputs::disabled()};
    if(enabled){let views::Span empty=views::Span{.start=0,.length=0};
        let usize a=inputs::put(ref mut windows,1,3,empty,0)?;
        let usize b=inputs::put_grant(ref mut windows,1,2,empty,0)?;
        let usize c=inputs::put(ref mut windows,2,4,empty,0)?;
        let usize d=inputs::put_grant(ref mut windows,2,5,empty,0)?;
    }return .ok(windows);
}
fn void same_windows(ref inputs::State windows,bool enabled){
    assert(inputs::enabled(windows)==enabled);
    if(enabled){
        let views::Span a=switch(inputs::get(windows,1,3,0)){case .ok(v):{v}case .err(_):{assert(false);views::Span{.start=0,.length=0}}};
        let views::Span b=switch(inputs::grant(windows,1,2,0)){case .ok(v):{v}case .err(_):{assert(false);views::Span{.start=0,.length=0}}};
        let views::Span c=switch(inputs::get(windows,2,4,0)){case .ok(v):{v}case .err(_):{assert(false);views::Span{.start=0,.length=0}}};
        let views::Span d=switch(inputs::grant(windows,2,5,0)){case .ok(v):{v}case .err(_):{assert(false);views::Span{.start=0,.length=0}}};
        assert(a.start==0 && a.length==0 && b.start==0 && b.length==0 && c.start==0 && c.length==0 && d.start==0 && d.length==0);
        assert(!inputs::get(windows,1,0,0).is_ok && !inputs::get(windows,2,0,0).is_ok);
        assert(!inputs::grant(windows,1,0,0).is_ok && !inputs::grant(windows,2,0,0).is_ok);
        assert(!inputs::accepts(windows,views::Span{.start=1,.length=0}));
    }else{assert(!inputs::get(windows,1,3,0).is_ok && !inputs::grant(windows,2,5,0).is_ok);}
}
fn void same_ticket(slices::Ticket a,slices::Ticket b){assert(a.slot==b.slot && a.generation==b.generation);}
fn void same_token(owners::Token a,owners::Token b){assert(a.slot==b.slot && a.generation==b.generation);}
fn void same_view(owners::View a,owners::View b){same_token(a.root,b.root);assert(a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end);}
fn void same_capture(runtime::Capture a,runtime::Capture b){same_ticket(a.ticket,b.ticket);assert(a.close==b.close && a.drop==b.drop && a.ends==b.ends);}
fn void same_prepared(ref owned::Prepared a,ref owned::Prepared b){
    assert(a.count==b.count && a.owned==b.owned && a.records==b.records);var usize i=0;
    while(i<8){same_capture(a.captures[i],b.captures[i]);same_token(a.sources[i],b.sources[i]);
        assert(a.destinations[i]==b.destinations[i] && a.record_args[i]==b.record_args[i]);
        assert(a.shapes[i].element==b.shapes[i].element && a.shapes[i].length==b.shapes[i].length && a.shapes[i].stride==b.shapes[i].stride && a.shapes[i].alignment==b.shapes[i].alignment && a.shapes[i].bytes==b.shapes[i].bytes);
        same_token(a.arguments[i].source,b.arguments[i].source);assert(a.arguments[i].element==b.arguments[i].element && a.arguments[i].length==b.arguments[i].length && a.arguments[i].record==b.arguments[i].record);i+=1;}
}
fn void same_argument(ref arguments::State a,ref arguments::State b){
    assert(a.remaining==b.remaining && a.target==b.target && a.map==b.map && a.offset==b.offset && a.count==b.count && a.index==b.index && a.price==b.price && a.work==b.work && a.word_mask==b.word_mask);
    assert(a.phase==b.phase && a.generic==b.generic && a.active==b.active && a.done==b.done);
    assert(a.result.remaining==b.result.remaining && a.result.input_mask==b.result.input_mask);var usize i=0;
    while(i<16){assert(a.result.words[i]==b.result.words[i]);i+=1;}
    i=0;while(i<8){same_capture(a.result.captures[i],b.result.captures[i]);assert(a.result.tags[i]==b.result.tags[i]);
        assert(a.result.input_windows[i].start==b.result.input_windows[i].start && a.result.input_windows[i].length==b.result.input_windows[i].length);i+=1;}
}
fn void same_work(ref context::State a,ref context::State b){
    assert(a.phase==b.phase && a.caller==b.caller && a.capacity==b.capacity && a.payload==b.payload && a.remaining==b.remaining && a.generic==b.generic && a.active==b.active && a.done==b.done);
    assert(a.contract.arity==b.contract.arity && a.contract.selected==b.contract.selected);var usize i=0;
    while(i<8){assert(a.contract.tags[i]==b.contract.tags[i] && a.owned.entry.ends[i]==b.owned.entry.ends[i] && a.owned.entry.parents[i]==b.owned.entry.parents[i]);i+=1;}
    assert(a.owned.phase==b.owned.phase && a.owned.index==b.owned.index && a.owned.active==b.owned.active && a.owned.done==b.owned.done);
    assert(a.owned.entry.required==b.owned.entry.required && a.owned.entry.absent==b.owned.entry.absent);
    same_prepared(ref a.owned.result,ref b.owned.result);same_argument(ref a.arguments,ref b.arguments);
}
// A compact receipt of the live root and next frame; no full Frames/Runtime
// clone or payload mirror is needed for these owner-free prefix fixtures.
struct Live {
    owners::Table table; slices::Pool pool; usize depth; usize native_frame; usize frame;
    usize[32] functions; bool[32] active; usize[32] remaining;
    owners::Token[32] tokens; slices::Ticket[32] sites;
}
fn Live live_snapshot(ref frames::Frames f,ref runtime::State state){
    let ref owners::Table table=ref state.runtime.owners;let ref slices::Pool pool=ref state.runtime.pool;
    let ref usize[] functions=ref f.functions[..];let ref bool[] active=ref f.active[..];let ref usize[] fuel=ref f.remaining[..];
    var Live saved=Live{.table=*table,.pool=*pool,.depth=state.runtime.authority.depth,.native_frame=state.runtime.authority.frame,.frame=f.frame,
        .functions=[0;32],.active=[false;32],.remaining=[0;32],.tokens=[owners::Token{.slot=0,.generation=0};32],.sites=[frames::none();32]};
    var usize i=0;while(i<32){saved.functions[i]=functions[i];saved.active[i]=active[i];saved.remaining[i]=fuel[i];saved.tokens[i]=f.tokens[16+i];saved.sites[i]=f.sites[16+i];i+=1;}return saved;
}
fn void same_live(ref Live before,ref frames::Frames f,ref runtime::State state){
    assert(f.frame==before.frame && state.runtime.authority.depth==before.depth && state.runtime.authority.frame==before.native_frame);
    let ref owners::Table table=ref state.runtime.owners;let ref owners::Table old=ref before.table;
    let ref slices::Pool pool=ref state.runtime.pool;let ref slices::Pool prior=ref before.pool;
    assert(table.depth==old.depth && table.arena.used==old.arena.used && table.arena.limit==old.arena.limit);var usize i=0;
    while(i<16){let owners::Owner a=table.slots[i];let owners::Owner b=old.slots[i];
        assert(table.order[i]==old.order[i] && a.generation==b.generation && a.occupied==b.occupied && a.live==b.live && a.reading==b.reading && a.writing==b.writing && a.read_generation==b.read_generation && a.mark==b.mark && a.base==b.base && a.end==b.end && a.element==b.element && a.length==b.length && a.record==b.record && a.alignment==b.alignment);
        let slices::Slot x=pool.slots[i];let slices::Slot y=prior.slots[i];same_view(x.view,y.view);same_token(x.lease.root,y.lease.root);
        assert(x.generation==y.generation && x.live==y.live && x.exclusive==y.exclusive && x.lease.generation==y.lease.generation);i+=1;}
    i=0;while(i<32){assert(f.functions[i]==before.functions[i] && f.active[i]==before.active[i] && f.remaining[i]==before.remaining[i]);same_token(f.tokens[16+i],before.tokens[i]);same_ticket(f.sites[16+i],before.sites[i]);i+=1;}
}
fn void same_places(ref vec::Vec<usize> values,usize mode){
    let usize length=vec::len<usize>(values);assert(length==if(mode==0){0}else if(mode==1){1}else{320});
    let ref usize[] words=vec::view_usize(values);var usize i=0;while(i<length){assert(words[i]==if(mode==2 && i==20){1}else{0});i+=1;}
}
fn Outcome drive(ref mut context::State w,ref ir::Program p,ref frames::Frames f,ref runtime::State state,
    ref inputs::State windows,ref vec::Vec<usize> place_state,ref mut usize remaining,bool enabled,usize place_mode){
    let u8[16] parameters=[0;16];let u32[16] words=[0;16];let statics::Sites sites=statics::empty();let plans::Plan cache=plans::empty();
    let usize initial=*remaining;switch(context::begin(w,64,0,initial)){case .ok(_):{}case .err(e):{return failure(e,*remaining);}};
    let Live before=live_snapshot(f,state);var budget::State allowance=budget::empty();
    var vec::Vec<context::State> snapshots=work_bank();let ref mut context::State saved=vec::at_mut<context::State>(ref mut snapshots,0);
    var usize attempts=0;
    while(attempts<64){
        assert(budget::reset(ref mut allowance,0).is_ok);*saved=*w;
        let usize fuel=*remaining;let usize total=allowance.total;let usize stages=allowance.stages;
        let bool admitted=switch(budget::admit(ref mut allowance,1,0)){case .ok(v):{v}case .err(_):{assert(false);false}};assert(admitted);
        let bool blocked=switch(context::advance(w,p,ref parameters,ref sites,0,f,state,ref words,0,windows,place_state,remaining,ref cache,ref mut allowance)){
            case .ok(v):{v}case .err(_):{assert(false);false}};
        assert(!blocked && allowance.last==1 && allowance.total==total+1 && allowance.stages==stages+1 && *remaining==fuel);
        same_work(w,saved);same_live(ref before,f,state);same_windows(windows,enabled);same_places(place_state,place_mode);
        assert(budget::reset(ref mut allowance,0).is_ok);assert(allowance.last==0 && allowance.total==total+1);
        let usize prior_total=allowance.total;let usize prior_stages=allowance.stages;let usize phase=w.phase;
        let Result<bool,errors::Error> result=context::advance(w,p,ref parameters,ref sites,0,f,state,ref words,0,windows,place_state,remaining,ref cache,ref mut allowance);
        attempts+=1;assert(allowance.last==4096 && allowance.total==prior_total+4096 && allowance.stages==prior_stages+1);
        same_live(ref before,f,state);same_windows(windows,enabled);same_places(place_state,place_mode);
        if(phase!=0){assert(*remaining==fuel);}
        switch(result){case .err(e):{assert(!w.active && !w.done);return failure(e,*remaining);}case .ok(done):{
            if(done){assert(w.done && !w.active && w.remaining==*remaining && attempts>=5);
                assert(!w.generic && w.contract.arity==p.arities[1] && w.contract.selected==0 && w.caller==0);
                assert(w.owned.done && !w.owned.active && w.owned.result.count==0 && !w.owned.result.records && w.owned.result.owned==p.arities[1]);
                assert(w.arguments.result.remaining==*remaining && w.arguments.result.input_mask==0);
                var usize i=0;while(i<8){assert(w.contract.tags[i]==0 && w.arguments.result.tags[i]==0);same_ticket(w.owned.result.captures[i].ticket,frames::none());i+=1;}
                i=0;while(i<16){assert(w.arguments.result.words[i]==0);i+=1;}
                let usize debit=if(enabled){meter::input_frame()}else{0};assert(*remaining==initial-debit);
                return success(*remaining,w.remaining,w.owned.result.count);
            }assert(w.active && !w.done);
        }};
    }
    assert(false);return failure(errors::make(99,0),*remaining);
}
fn Result<Outcome,errors::Error> observe(ref ir::Program p,bool staged,bool enabled,usize fault,usize place_mode,usize initial){
    var vec::Vec<runtime::State> runtimes=runtime_bank();let ref mut runtime::State state=vec::at_mut<runtime::State>(ref mut runtimes,0);
    var vec::Vec<frames::Frames> stack=frame_bank(p,state,fault)?;let ref frames::Frames f=vec::at<frames::Frames>(ref stack,0);
    var inputs::State windows=window_bank(enabled)?;var vec::Vec<usize> place_state=place_bank(place_mode)?;var usize remaining=initial;
    var Outcome result=failure(errors::make(99,0),remaining);
    if(staged){var vec::Vec<context::State> work=work_bank();let ref mut context::State w=vec::at_mut<context::State>(ref mut work,0);
        result=drive(w,p,f,state,ref windows,ref place_state,ref mut remaining,enabled,place_mode);
    }else{
        let Live before=live_snapshot(f,state);let u8[16] parameters=[0;16];let u32[16] words=[0;16];
        let statics::Sites sites=statics::empty();let plans::Plan cache=plans::empty();
        switch(raw::begin(p,ref parameters,ref sites,0,f,state,64,0,ref words,0,ref windows,ref mut place_state,ref mut remaining,ref cache)){
            case .err(e):{result=failure(e,remaining);}
            case .ok(copy):{assert(copy.pending && !copy.charged && copy.frame==1 && copy.count==0 && copy.captured==remaining);result=success(remaining,copy.captured,copy.count);}
        };
        same_live(ref before,f,state);same_windows(ref windows,enabled);same_places(ref place_state,place_mode);
    }
    assert(result.remaining==remaining);return .ok(result);
}
fn Result<usize,errors::Error> parity(bool scalar,bool enabled,usize fault,usize place_mode,usize initial,u8 error,usize expected_remaining){
    let vec::Vec<ir::Program> programs=program_bank(scalar);let ref ir::Program p=vec::at<ir::Program>(ref programs,0);
    let Outcome expected=observe(p,false,enabled,fault,place_mode,initial)?;
    let Outcome actual=observe(p,true,enabled,fault,place_mode,initial)?;
    assert(actual.error==expected.error && actual.offset==expected.offset && actual.remaining==expected.remaining && actual.captured==expected.captured && actual.count==expected.count && actual.done==expected.done);
    assert(actual.error==error && actual.remaining==expected_remaining);
    if(error==0){assert(actual.done && actual.count==0 && actual.captured==expected_remaining);}
    else{assert(!actual.done && actual.offset==73);}
    return .ok(actual.remaining);
}

@test fn void frame_and_authority_depth_exhaustion_precede_fuel_and_bad_places(){
    var usize fault=1;while(fault<=2){
        assert(parity(false,false,fault,1,0,12,0).is_ok);assert(parity(false,true,fault,1,0,12,0).is_ok);
        assert(parity(false,true,fault,1,1000000,12,1000000).is_ok);fault+=1;
    }
}
@test fn void enabled_and_disabled_input_short_fuel_preserves_external_balance(){
    let usize ordinary=runtime::cost()-1;let usize with_input=runtime::cost()+meter::input_frame()-1;
    assert(parity(false,false,0,0,ordinary,8,ordinary).is_ok);
    assert(parity(false,false,0,1,ordinary,8,ordinary).is_ok);
    assert(parity(false,true,0,0,with_input,8,with_input).is_ok);
    assert(parity(false,true,0,2,with_input,8,with_input).is_ok);
    let usize enough_without_input=runtime::cost();assert(parity(false,true,0,1,enough_without_input,8,enough_without_input).is_ok);
}
@test fn void malformed_and_nonempty_future_places_debit_input_frame_exactly_once(){
    var usize mode=1;while(mode<=2){
        assert(parity(false,false,0,mode,1000000,5,1000000).is_ok);
        let usize charged=1000000-meter::input_frame();assert(parity(false,true,0,mode,1000000,5,charged).is_ok);mode+=1;
    }
}
@test fn void scalar_and_zero_arity_success_keep_contract_flags_and_captured_fuel(){
    let usize base=runtime::cost();let usize input=meter::input_frame();
    assert(parity(false,false,0,0,base,0,base).is_ok);
    assert(parity(false,true,0,0,base+input,0,base).is_ok);
    assert(parity(true,false,0,0,base+1,0,base+1).is_ok);
    assert(parity(true,true,0,0,base+input+1,0,base+1).is_ok);
}
