module tests::m2::return_metadata_execution;
import return_metadata_execution as adapter;
import return_prepare_work as preparing;
import return_work_cursor as validation;
import return_work_execution as measurements;
import runtime_metadata_work as metadata;
import metadata_budget as budget;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import slice_result_owned_execution as owned;
import slice_result_record_execution as records;
import slice_result_record_bindings as record_bindings;
import slice_result_bindings as loans;
import slice_authority as authority;
import array_owners as owners;
import array_slices as slices;
import array_layout as layouts;
import array_vm as arrays;
import ir as ir;
import static_ir as statics;
import static_views as views;
import static_call_execution as transfer;
import reference_return_execution as reference_returns;
import reference_receipts as receipts;
import reference_words as words;
import reference_access as access;
import input_reference_views as inputs;
import call_capture_plan as captures;
import errors as errors;
import std::vec as vec;
import fuel as meter;

// Private native coordinator fixtures, not guest IR/proof admission evidence.
// One fixture owns each Frames/Runtime; independent raw/staged invocations
// return compact snapshots, never another Frames or retained Work value.
struct Snapshot {
    owners::Table owners; slices::Pool pool; runtime::Call call; runtime::Held held;
    owners::Token[32] arrays; owners::Token[32] records; slices::Ticket[32] sites;
    u32[32] words; usize[3] live; usize[3] functions; bool[3] active; bool[3] prepared;
    u8[64] data; usize frame; usize depth; usize native_frame; usize held_location; usize held_parent;
    i64 value; usize remaining;
}
fn slices::Ticket none(){return slices::Ticket{.slot=16,.generation=0};}
fn runtime::Held no_held(){return runtime::Held{.issued=none(),.view=owners::View{.root=owners::Token{.slot=16,.generation=0},
    .element=0,.length=0,.start=0,.end=0},.exclusive=false,.close_parent=false,.drop=false,.depth=0,.frame=0,.active=false};}
fn Result<usize,errors::Error> size(Result<usize,owners::Error> r){return switch(r){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};}
fn Result<slices::Ticket,errors::Error> ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};}
fn void same_ticket(slices::Ticket a,slices::Ticket b){assert(a.slot==b.slot && a.generation==b.generation);}
fn void same_token(owners::Token a,owners::Token b){assert(a.slot==b.slot && a.generation==b.generation);}
fn void same_view(owners::View a,owners::View b){same_token(a.root,b.root);assert(a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end);}
fn void same_held(runtime::Held a,runtime::Held b){same_ticket(a.issued,b.issued);same_view(a.view,b.view);
    assert(a.exclusive==b.exclusive && a.close_parent==b.close_parent && a.drop==b.drop && a.depth==b.depth && a.frame==b.frame && a.active==b.active);}
fn void same_call(ref runtime::Call a,ref runtime::Call b){
    assert(a.contract.arity==b.contract.arity && a.contract.selected==b.contract.selected && a.depth==b.depth && a.frame==b.frame && a.remaining==b.remaining && a.active==b.active);
    var usize i=0;while(i<8){let runtime::Capture x=a.captures[i];let runtime::Capture y=b.captures[i];same_ticket(x.ticket,y.ticket);
        assert(x.close==y.close && x.drop==y.drop && x.ends==y.ends && a.contract.tags[i]==b.contract.tags[i]);same_view(a.views[i],b.views[i]);same_ticket(a.issued[i],b.issued[i]);i+=1;}
    i=0;while(i<16){same_ticket(a.before[i],b.before[i]);i+=1;}
}
fn Snapshot blank_snapshot(){
    let runtime::Held blank=no_held();
    let runtime::Call call=runtime::Call{.captures=[runtime::capture(none(),false,false);8],.views=[blank.view;8],
        .issued=[none();8],.before=[none();16],.contract=runtime::Contract{.tags=[0;8],.arity=0,.selected=0},
        .depth=0,.frame=0,.remaining=0,.active=false};
    return Snapshot{.owners=owners::empty(64),.pool=slices::empty(),.call=call,.held=blank,
        .arrays=[owners::Token{.slot=0,.generation=0};32],.records=[owners::Token{.slot=0,.generation=0};32],.sites=[none();32],
        .words=[0;32],.live=[0;3],.functions=[0;3],.active=[false;3],.prepared=[false;3],.data=[0;64],
        .frame=0,.depth=0,.native_frame=0,.held_location=512,.held_parent=512,.value=0,.remaining=0};
}
// Large constructors run only in short-lived setup frames. All persistent
// Program/Frames/Runtime/Work and comparison storage live in SDK Vec banks.
fn vec::Vec<Snapshot> snapshot_bank(usize count){
    var vec::Vec<Snapshot> bank=vec::empty<Snapshot>();assert(vec::reserve<Snapshot>(ref mut bank,count).is_ok);
    var usize i=0;while(i<count){assert(vec::push<Snapshot>(ref mut bank,blank_snapshot()).is_ok);i+=1;}return bank;
}
fn vec::Vec<runtime::State> runtime_bank(){
    var vec::Vec<runtime::State> bank=vec::empty<runtime::State>();assert(vec::reserve<runtime::State>(ref mut bank,1).is_ok);
    assert(vec::push<runtime::State>(ref mut bank,runtime::empty(64)).is_ok);return bank;
}
fn vec::Vec<frames::Frames> frame_bank(ref runtime::State state){
    var vec::Vec<frames::Frames> bank=vec::empty<frames::Frames>();assert(vec::reserve<frames::Frames>(ref mut bank,1).is_ok);
    assert(vec::push<frames::Frames>(ref mut bank,frames::empty(state)).is_ok);return bank;
}
fn vec::Vec<metadata::State> work_bank(){
    var vec::Vec<metadata::State> bank=vec::empty<metadata::State>();assert(vec::reserve<metadata::State>(ref mut bank,1).is_ok);
    assert(vec::push<metadata::State>(ref mut bank,metadata::empty()).is_ok);return bank;
}
fn Result<usize,errors::Error> save_snapshot(ref mut Snapshot result,ref runtime::State state,ref frames::Frames bindings,
    ref usize[] live,ref u32[] current,ref i64[] registers,ref u8[] data,usize remaining){
    let ref owners::Table table=ref state.runtime.owners;let ref slices::Pool pool=ref state.runtime.pool;
    let ref authority::State stack=ref state.runtime.authority;let usize valid=size(authority::inspect(stack))?;
    result.owners=*table;result.pool=*pool;result.call=frames::current(bindings);result.held=no_held();
    result.frame=bindings.frame;result.depth=stack.depth;result.native_frame=stack.frame;
    result.held_location=512;result.held_parent=512;result.value=registers[131];result.remaining=remaining;
    var usize i=0;while(i<32){result.arrays[i]=bindings.tokens[16+i];result.records[i]=record_bindings::get(ref bindings.records,16+i);
        result.sites[i]=bindings.sites[16+i];result.words[i]=current[16+i];i+=1;}
    i=0;while(i<3){result.live[i]=live[i];result.functions[i]=bindings.functions[i];result.active[i]=bindings.active[i];result.prepared[i]=bindings.prepared[i];i+=1;}
    i=0;while(i<64){result.data[i]=data[i];i+=1;}
    let ref loans::State bank=ref bindings.loans;
    i=0;while(i<47){if(bank.held[i].active){result.held=bank.held[i];result.held_location=bank.locations[i];result.held_parent=bank.parents[i];break;}i+=1;}
    return .ok(0);
}
fn void same_snapshot(ref Snapshot a,ref Snapshot b){
    assert(a.frame==b.frame && a.depth==b.depth && a.native_frame==b.native_frame && a.value==b.value && a.remaining==b.remaining && a.held_location==b.held_location && a.held_parent==b.held_parent);
    same_call(ref a.call,ref b.call);same_held(a.held,b.held);
    let ref owners::Table x=ref a.owners;let ref owners::Table y=ref b.owners;
    assert(x.depth==y.depth && x.arena.used==y.arena.used && x.arena.limit==y.arena.limit);
    var usize i=0;while(i<16){let owners::Owner u=x.slots[i];let owners::Owner v=y.slots[i];
        assert(x.order[i]==y.order[i] && u.generation==v.generation && u.occupied==v.occupied && u.live==v.live && u.reading==v.reading && u.writing==v.writing && u.read_generation==v.read_generation && u.mark==v.mark && u.base==v.base && u.end==v.end && u.element==v.element && u.length==v.length && u.record==v.record && u.alignment==v.alignment);
        let slices::Slot p=a.pool.slots[i];let slices::Slot q=b.pool.slots[i];same_view(p.view,q.view);
        assert(p.generation==q.generation && p.live==q.live && p.exclusive==q.exclusive && p.lease.root.slot==q.lease.root.slot && p.lease.root.generation==q.lease.root.generation && p.lease.generation==q.lease.generation);i+=1;}
    i=0;while(i<32){same_token(a.arrays[i],b.arrays[i]);same_token(a.records[i],b.records[i]);same_ticket(a.sites[i],b.sites[i]);assert(a.words[i]==b.words[i]);i+=1;}
    i=0;while(i<3){assert(a.live[i]==b.live[i] && a.functions[i]==b.functions[i] && a.active[i]==b.active[i] && a.prepared[i]==b.prepared[i]);i+=1;}
    i=0;while(i<64){assert(a.data[i]==b.data[i]);i+=1;}
}
fn Result<usize,errors::Error> frozen(ref Snapshot before,ref mut vec::Vec<Snapshot> scratch,ref runtime::State state,ref frames::Frames bindings,
    ref usize[] live,ref u32[] current,ref i64[] registers,ref u8[] data,usize remaining){
    let ref mut Snapshot after=vec::at_mut<Snapshot>(scratch,0);
    let usize saved=save_snapshot(after,state,bindings,live,current,registers,data,remaining)?;same_snapshot(before,after);return .ok(0);
}
fn Result<owners::Token,errors::Error> create(ref mut runtime::State state,ref mut u8[] data,u8 tag){
    let layouts::Array shape=switch(layouts::scalar(tag,4)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,0));}};
    return switch(owners::create(ref shape,0,data,ref mut state.runtime.owners)){case .ok(v):{.ok(v)}case .err(e):{.err(arrays::failure(e,0))}};
}
fn Result<slices::Ticket,errors::Error> open(ref mut runtime::State state,owners::Token root,bool exclusive){
    let ref slices::Pool original_pool=ref state.runtime.pool;var slices::Pool pool=*original_pool;
    let ref owners::Table original_table=ref state.runtime.owners;var owners::Table table=*original_table;
    let slices::Ticket result=ticket(if(exclusive){slices::open_exclusive(ref mut pool,ref mut table,root,0,4,64)}else{slices::open(ref mut pool,ref mut table,root,0,4,64)})?;
    state.runtime.pool=pool;state.runtime.owners=table;return .ok(result);
}
// mode: 0 scalar, 1 RET65 exclusive, 2 runtime-reference79, 3 ARET bool,
// 4 SRET {bool,i32}, 5 static79. Function zero owns the paused caller.
fn void program(ref mut ir::Program p,u8 mode){
    p.count=4;p.function_count=2;p.call_count=1;p.entry=0;p.starts[0]=0;p.ends[0]=3;p.starts[1]=3;p.ends[1]=4;
    p.registers=2;p.register_starts[1]=1;p.register_ends[0]=1;p.register_ends[1]=2;
    p.code[0]=9;p.code[1]=3;p.code[2]=1;p.code[8]=1;p.code[16]=8;
    p.code[24]=if(mode==1){65}else if(mode==2 || mode==5){79}else if(mode==3){39}else if(mode==4){50}else{8};p.offsets[3]=73;
    if(mode==1 || mode==2){p.arities[1]=1;p.call_arities[0]=1;p.call_args[0]=160;}
    if(mode==1){p.code[0]=66;p.code[1]=0;p.code[5]=1;p.code[6]=0;p.code[8]=67;p.code[9]=1;p.code[10]=0;p.slice_parameters[1]=1;}
    if(mode==2 || mode==5){p.code[0]=78;p.code[1]=1;}
    if(mode==3){p.arrays.count=2;p.arrays.elements[0]=2;p.arrays.elements[1]=2;p.arrays.lengths[0]=4;p.arrays.lengths[1]=4;
        p.arrays.mutable[0]=true;p.arrays.mutable[1]=true;p.array_functions[0]=1;p.array_results[1]=1;p.code[1]=129;}
    if(mode==4){p.records.count=2;p.records.layouts.count=1;p.records.layouts.fields[0]=2;p.records.layouts.types[0]=2;p.records.layouts.types[1]=1;
        p.record_functions[0]=1;p.record_results[1]=1;p.code[1]=145;}
}
fn vec::Vec<ir::Program> program_bank(u8 mode){
    var ir::Program p=ir::empty();program(ref mut p,mode);
    var vec::Vec<ir::Program> bank=vec::empty<ir::Program>();assert(vec::reserve<ir::Program>(ref mut bank,1).is_ok);
    assert(vec::push<ir::Program>(ref mut bank,p).is_ok);return bank;
}
fn statics::Sites site_context(u8 mode){
    var statics::Sites sites=statics::empty();
    if(mode==2 || mode==5){sites.count=2;sites.call_profile=true;
        sites.functions[0]=1;sites.definitions[0]=3;sites.functions[1]=0;sites.definitions[1]=0;
        sites.kinds[0]=if(mode==2){3}else{1};sites.kinds[1]=if(mode==2){3}else{1};sites.results[1]=if(mode==2){3}else{1};
        if(mode==2){sites.parameters[1]=3;}
        else{sites.spans[0].literal=0;sites.spans[0].end=4;sites.spans[1].literal=0;sites.spans[1].end=4;}
    }
    return sites;
}
fn Result<usize,errors::Error> enter(ref ir::Program p,ref mut frames::Frames bindings,ref mut runtime::State state,
    ref mut u8[] data,u8 mode){
    let runtime::Capture[1] no_args=[runtime::capture(none(),false,false)];
    let runtime::Contract scalar=runtime::Contract{.tags=[0;8],.arity=0,.selected=0};
    let runtime::Call root_call=runtime::enter_call(state,scalar,ref no_args[..0],64,runtime::cost())?;
    let usize root_frame=frames::push(p,bindings,root_call,0,3,0,0)?;
    var runtime::Contract binding=scalar;var runtime::Capture[1] args=no_args;var usize count=0;
    if(mode==1 || mode==2){let owners::Token root=create(state,data,10)?;
        let usize written=size(owners::write(ref mut state.runtime.owners,root,1,42,data))?;
        let slices::Ticket parent=open(state,root,mode==1)?;
        binding.arity=1;binding.selected=1;binding.tags[0]=if(mode==1){138}else{10};args[0]=runtime::capture(parent,mode==2,mode==2);count=1;
    }
    let runtime::Call call=runtime::enter_call(state,binding,ref args[..count],64,runtime::cost())?;
    let usize destination=if(mode==1){161}else{p.code[1] as usize};
    let usize child=frames::push(p,bindings,call,1,destination,0,1)?;
    if(mode==1){let usize selected=frames::prepare(bindings,0,call.issued[0])?;}
    if(mode==3){let owners::Token root=create(state,data,2)?;let usize written=size(owners::write(ref mut state.runtime.owners,root,1,1,data))?;bindings.tokens[32]=root;}
    if(mode==4){let i64[2] fields=[1,42];let owners::Token root=switch(owners::create_record(ref p.records.layouts,0,ref fields,data,ref mut state.runtime.owners)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}};record_bindings::bind(ref mut bindings.records,32,root);}
    return .ok(0);
}
fn vec::Vec<preparing::State> preparation_bank(){
    var vec::Vec<preparing::State> bank=vec::empty<preparing::State>();assert(vec::reserve<preparing::State>(ref mut bank,1).is_ok);
    assert(vec::push<preparing::State>(ref mut bank,preparing::empty()).is_ok);return bank;
}
fn Result<usize,errors::Error> prepare_pending(ref mut adapter::State s,ref ir::Program p,ref statics::Sites sites,
    ref frames::Frames bindings,ref runtime::State state,ref u8[] data,ref inputs::State windows,ref u8[] origins,
    ref usize[] live,ref u32[] current,ref i64[] registers,ref mut usize remaining){
    var vec::Vec<preparing::State> bank=preparation_bank();let ref mut preparing::State w=vec::at_mut<preparing::State>(ref mut bank,0);
    var validation::State counter=validation::empty();var budget::State allowance=budget::empty();
    let vec::Vec<usize> places=vec::empty<usize>();
    let usize begun=preparing::begin(w,s,3,bindings.frame,*remaining)?;
    var vec::Vec<Snapshot> original=snapshot_bank(1);var vec::Vec<Snapshot> scratch=snapshot_bank(1);
    let ref mut Snapshot before=vec::at_mut<Snapshot>(ref mut original,0);
    let usize saved=save_snapshot(before,state,bindings,live,current,registers,data,*remaining)?;
    var usize n=0;while(n<512){counter.last=0;let usize reset=budget::reset(ref mut allowance,73)?;
        let usize phase=w.phase;let usize fuel=*remaining;let usize required=w.required;let usize total=counter.total;
        let bool partial=preparing::advance(w,s,p,sites,bindings,state,data,4,windows,origins,live,current,registers,ref places,
            remaining,ref mut counter,ref mut allowance,4095)?;
        assert(!partial && w.phase==phase && w.required==required && *remaining==fuel && counter.total==total && allowance.last==0);
        let bool done=preparing::advance(w,s,p,sites,bindings,state,data,4,windows,origins,live,current,registers,ref places,
            remaining,ref mut counter,ref mut allowance,4096)?;
        assert(counter.last+allowance.last<=4096);before.remaining=*remaining;
        let usize unchanged=frozen(before,ref mut scratch,state,bindings,live,current,registers,data,*remaining)?;
        if(done){assert(s.phase==1 && s.pending && !s.done && w.done && !w.active);
            let usize expected=measurements::required(p,3)?;assert(counter.total==expected && counter.required==expected && counter.op==s.op);
            return .ok(0);}
        n+=1;
    }assert(false);return .err(errors::make(5,73));
}

fn Result<usize,errors::Error> staged(ref ir::Program p,ref statics::Sites sites,ref mut frames::Frames bindings,
    ref mut runtime::State state,ref u8[] data,ref mut inputs::State windows,ref u8[] origins,
    ref mut usize[] live,ref mut u32[] current,ref mut i64[] registers,ref mut usize remaining,ref captures::Plan plans){
    var adapter::State s=adapter::empty();var vec::Vec<metadata::State> work_storage=work_bank();
    let ref mut metadata::State work=vec::at_mut<metadata::State>(ref mut work_storage,0);var budget::State allowance=budget::empty();
    var vec::Vec<Snapshot> before_storage=snapshot_bank(1);var vec::Vec<Snapshot> scratch=snapshot_bank(1);
    let ref mut Snapshot before=vec::at_mut<Snapshot>(ref mut before_storage,0);
    let usize saved=save_snapshot(before,state,bindings,live,current,registers,data,*remaining)?;
    let usize begun=prepare_pending(ref mut s,p,sites,bindings,state,data,windows,origins,live,current,registers,remaining)?;
    assert(s.pending && !s.done && s.phase==1 && s.frame==2 && s.pc==3);
    let usize pinned=*remaining;before.remaining=pinned;
    let usize prepared_frozen=frozen(before,ref mut scratch,state,bindings,live,current,registers,data,pinned)?;
    var usize dispatches=0;var bool saw_final=false;
    while(dispatches<256){
        let usize cleared=budget::reset(ref mut allowance,73)?;
        let usize total=allowance.total;let usize stages=allowance.stages;let bool charged=budget::admit(ref mut allowance,512,73)?;assert(charged);
        let u8 phase=s.phase;let u8 work_phase=work.phase;let usize index=work.index;let bool active=work.active;let bool done=work.done;
        // This is a payload-shared dispatch: no stage may use partial room.
        let bool partial=adapter::advance(ref mut s,work,ref mut allowance,p,sites,bindings,state,64,windows,origins,live,current,registers,remaining,3584,plans)?;
        assert(!partial && s.phase==phase && s.pending && !s.done && work.phase==work_phase && work.index==index && work.active==active && work.done==done);
        assert(allowance.last==512 && allowance.total==total+512 && allowance.stages==stages+1 && *remaining==pinned);
        let usize unchanged=frozen(before,ref mut scratch,state,bindings,live,current,registers,data,*remaining)?;
        // The next dispatch resets last; the earlier 512 cannot be banked.
        let usize reset=budget::reset(ref mut allowance,73)?;assert(reset==4096 && allowance.last==0);
        if(phase==3){assert(work.done && !work.active);saw_final=true;}
        let bool finished=adapter::advance(ref mut s,work,ref mut allowance,p,sites,bindings,state,64,windows,origins,live,current,registers,remaining,4096,plans)?;
        assert(allowance.last==4096 && allowance.total==total+4608 && allowance.stages==stages+2);dispatches+=1;
        if(finished){assert(phase==3 && saw_final && !s.pending && s.done && s.phase==4 && !s.complete && !s.view && s.next==1 && bindings.frame==1 && *remaining==work.returned.remaining);return .ok(s.next);}
        assert(s.pending && !s.done && *remaining==pinned);
        let usize still_frozen=frozen(before,ref mut scratch,state,bindings,live,current,registers,data,*remaining)?;
    }
    assert(false);return .err(errors::make(5,73));
}
// Independent synchronous route follows the legacy dispatch branches, with
// no calls to adapter preparation, Work advance, or adapter publication.
fn Result<usize,errors::Error> raw(ref ir::Program p,ref statics::Sites sites,ref mut frames::Frames bindings,
    ref mut runtime::State state,ref u8[] data,ref mut inputs::State windows,ref u8[] origins,
    ref mut usize[] live,ref mut u32[] current,ref mut i64[] registers,ref mut usize remaining,ref captures::Plan plans){
    let u8 op=p.code[24];let usize frame=bindings.frame;let usize parent=frame-1;let usize destination=bindings.destinations[frame];
    if(op==65){let usize selected=frames::selected(bindings,0)?;var runtime::Call call=frames::current(bindings);
        let runtime::Returned result=records::handoff(bindings,state,ref mut call,bindings.results[selected],64,*remaining)?;
        *remaining=result.remaining;let usize next=frames::pop_cached(p,bindings,result,plans)?;
        let usize cleared=inputs::clear_frame(windows,frame,73)?;return .ok(next);
    }
    if(op==79){
        if(sites.results[1]==3){let reference_returns::Returned prepared=reference_returns::prepare_input(p,sites,3,1,
                current[32..48],live[2],live[1],bindings,state,4,*remaining,windows,origins)?;
            assert(prepared.loan);*remaining=prepared.remaining;var runtime::Call call=frames::current(bindings);
            let runtime::Returned result=records::handoff(bindings,state,ref mut call,prepared.ticket,64,*remaining)?;
            *remaining=result.remaining;let usize next=frames::pop_reference(p,bindings,result)?;
            live[parent]=receipts::publish(ref mut bindings.loans,parent,prepared.destination,result.held,prepared.span,current[16..32],live[parent],73)?;
        }else{let transfer::Returned prepared=transfer::returned(p,sites,4,3,1,current[32..48],live[2],0,0,destination,live[1],*remaining)?;
            *remaining=prepared.remaining;let runtime::Resumed resumed=switch(owned::leave(p,3,8,bindings,state,data,*remaining)){
                case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,p.offsets[3]));}
            };*remaining=resumed.remaining;
            current[16+prepared.destination]=prepared.word;let usize one=1;live[1]|=one<<prepared.destination;
        }
        let usize cleared=inputs::clear_frame(windows,frame,73)?;live[2]=0;var usize i=0;while(i<16){current[32+i]=0;i+=1;}return .ok(1);
    }
    let i64 value=registers[256];let runtime::Resumed resumed=switch(owned::leave(p,3,op,bindings,state,data,*remaining)){
        case .ok(v):{v}case .err(e):{return .err(errors::make(e.kind,p.offsets[3]));}
    };*remaining=resumed.remaining;
    let usize cleared=inputs::clear_frame(windows,frame,73)?;if(op==8){registers[128+destination]=value;}return .ok(1);
}
fn Result<usize,errors::Error> scenario(ref ir::Program p,ref mut Snapshot result,u8 mode,bool use_staged){
    let statics::Sites sites=site_context(mode);var vec::Vec<runtime::State> runtime_storage=runtime_bank();
    let ref mut runtime::State state=vec::at_mut<runtime::State>(ref mut runtime_storage,0);
    var vec::Vec<frames::Frames> frame_storage=frame_bank(state);let ref mut frames::Frames bindings=vec::at_mut<frames::Frames>(ref mut frame_storage,0);
    var u8[64] data=[0;64];let usize entered=enter(p,bindings,state,ref mut data,mode)?;
    var usize[32] live=[0;32];var u32[512] current=[0;512];var i64[4096] registers=[0;4096];registers[131]=-7;registers[256]=42;
    var inputs::State windows=inputs::disabled();let u8[16] origins=[0;16];
    if(mode==2 || mode==5){live[2]=1;current[32]=if(mode==2){words::pack(0,views::Span{.start=1,.length=2},73)?}else{views::pack(1,2,4,73)?};}
    let captures::Plan plans=captures::prepare(p)?;var usize remaining=1000000000;
    // Both routes begin after the parent's single opcode debit/empty-place check.
    if(!use_staged){remaining-=1;}let usize next=if(use_staged){staged(p,ref sites,bindings,state,ref data,ref mut windows,ref origins,
        ref mut live,ref mut current,ref mut registers,ref mut remaining,ref plans)?}
        else{raw(p,ref sites,bindings,state,ref data,ref mut windows,ref origins,
        ref mut live,ref mut current,ref mut registers,ref mut remaining,ref plans)?};
    assert(next==1 && bindings.frame==1 && !bindings.active[2] && bindings.functions[2]==16);
    if(mode==0){assert(registers[131]==42);}
    if(mode==1){assert(frames::result_bound(bindings,1));}
    if(mode==2){assert(live[1]==2 && live[2]==0 && words::returned(current[17]));
        let access::Source selected=receipts::source(ref bindings.loans,1,current[17],73)?;
        assert(selected.storage==2 && selected.window && selected.span.start==1 && selected.span.length==2);
        switch(slices::read(ref state.runtime.pool,selected.ticket,ref state.runtime.owners,1,ref data)){case .ok(v):{assert(v==42);}case .err(e):{return .err(arrays::failure(e,0));}};
    }
    if(mode==3){assert(bindings.tokens[17].generation!=0 && bindings.tokens[32].generation==0 && data[1]==1);}
    if(mode==4){assert(record_bindings::get(ref bindings.records,17).generation!=0 && record_bindings::get(ref bindings.records,32).generation==0);}
    if(mode==5){assert(live[1]==2 && live[2]==0 && current[17]==8194 && current[32]==0);}
    let usize saved=save_snapshot(result,state,bindings,ref live,ref current,ref registers,ref data,remaining)?;
    let usize drained=runtime::abort(state,64,0)?;assert(drained==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    return .ok(0);
}
fn Result<usize,errors::Error> parity(u8 mode){
    let vec::Vec<ir::Program> programs=program_bank(mode);let ref ir::Program p=vec::at<ir::Program>(ref programs,0);
    var vec::Vec<Snapshot> observations=snapshot_bank(2);
    let ref mut Snapshot raw_result=vec::at_mut<Snapshot>(ref mut observations,0);let usize old=scenario(p,raw_result,mode,false)?;
    let ref mut Snapshot staged_result=vec::at_mut<Snapshot>(ref mut observations,1);let usize new_result=scenario(p,staged_result,mode,true)?;
    let ref Snapshot expected=vec::at<Snapshot>(ref observations,0);let ref Snapshot actual=vec::at<Snapshot>(ref observations,1);
    same_snapshot(expected,actual);return .ok(0);
}

struct Failure { errors::Error error; usize remaining; }
// A corrupted frame map is rejected only after metadata restoration finishes.
// The private plan may change; every original frame/runtime/output and the
// prefix-charged Fuel must remain unchanged when final preflight rejects it.
fn Result<Failure,errors::Error> staged_bad_map(ref ir::Program p,ref statics::Sites sites,ref mut frames::Frames bindings,
    ref mut runtime::State state,ref u8[] data,ref mut inputs::State windows,ref u8[] origins,
    ref mut usize[] live,ref mut u32[] current,ref mut i64[] registers,ref mut usize remaining,ref captures::Plan plans){
    var adapter::State s=adapter::empty();var vec::Vec<metadata::State> work_storage=work_bank();
    let ref mut metadata::State work=vec::at_mut<metadata::State>(ref mut work_storage,0);var budget::State allowance=budget::empty();
    var vec::Vec<Snapshot> before_storage=snapshot_bank(1);var vec::Vec<Snapshot> scratch=snapshot_bank(1);
    let ref mut Snapshot before=vec::at_mut<Snapshot>(ref mut before_storage,0);
    let usize saved=save_snapshot(before,state,bindings,live,current,registers,data,*remaining)?;
    let usize begun=prepare_pending(ref mut s,p,sites,bindings,state,data,windows,origins,live,current,registers,remaining)?;
    assert(s.pending && !s.done && s.phase==1);let usize pinned=*remaining;before.remaining=pinned;
    let usize prepared_frozen=frozen(before,ref mut scratch,state,bindings,live,current,registers,data,pinned)?;
    var usize dispatches=0;while(dispatches<256){
        let usize reset=budget::reset(ref mut allowance,73)?;assert(reset==4096 && allowance.last==0);let u8 phase=s.phase;
        let Result<bool,errors::Error> progressed=adapter::advance(ref mut s,work,ref mut allowance,p,sites,bindings,state,64,
            windows,origins,live,current,registers,remaining,4096,plans);
        var bool failed=false;var bool finished=false;var errors::Error failure=errors::make(0,0);
        switch(progressed){case .err(e):{failed=true;failure=e;}case .ok(done):{finished=done;}};
        dispatches+=1;assert(allowance.last==4096 && allowance.stages==dispatches && allowance.total==dispatches*4096);
        let usize unchanged=frozen(before,ref mut scratch,state,bindings,live,current,registers,data,*remaining)?;
        assert(*remaining==pinned && bindings.frame==2 && bindings.maps[2]==p.call_count && bindings.active[2] && bindings.functions[2]==1);
        if(failed){
            assert(phase==3 && work.done && !work.active && !s.pending && !s.done && !s.complete && !s.view);
            assert(work.planned.authority.frame==1 && state.runtime.authority.frame==2);
            return .ok(Failure{.error=failure,.remaining=*remaining});
        }
        assert(!finished && s.pending && !s.done);
    }
    assert(false);return .err(errors::make(5,73));
}
fn Result<Failure,errors::Error> bad_map_scenario(ref ir::Program p,u8 mode,bool use_staged){
    let statics::Sites sites=site_context(mode);var vec::Vec<runtime::State> runtime_storage=runtime_bank();
    let ref mut runtime::State state=vec::at_mut<runtime::State>(ref mut runtime_storage,0);
    var vec::Vec<frames::Frames> frame_storage=frame_bank(state);let ref mut frames::Frames bindings=vec::at_mut<frames::Frames>(ref mut frame_storage,0);
    var u8[64] data=[0;64];let usize entered=enter(p,bindings,state,ref mut data,mode)?;bindings.maps[2]=p.call_count;
    var usize[32] live=[0;32];var u32[512] current=[0;512];var i64[4096] registers=[0;4096];registers[131]=-7;registers[256]=42;
    var inputs::State windows=inputs::disabled();let u8[16] origins=[0;16];
    if(mode==5){live[2]=1;current[32]=views::pack(1,2,4,73)?;}
    let captures::Plan plans=captures::prepare(p)?;var usize remaining=1000000000;if(!use_staged){remaining-=1;}
    var Failure observed=Failure{.error=errors::make(99,0),.remaining=remaining};
    if(use_staged){observed=staged_bad_map(p,ref sites,bindings,state,ref data,ref mut windows,ref origins,
        ref mut live,ref mut current,ref mut registers,ref mut remaining,ref plans)?;}
    else{
        // Raw leave may already have published native restoration before its
        // frame-pop error. Do not impose staged rollback on that legacy route.
        switch(raw(p,ref sites,bindings,state,ref data,ref mut windows,ref origins,
            ref mut live,ref mut current,ref mut registers,ref mut remaining,ref plans)){
            case .ok(_):{assert(false);}
            case .err(e):{observed=Failure{.error=e,.remaining=remaining};}
        };
    }
    let usize drained=runtime::abort(state,64,0)?;assert(drained==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    return .ok(observed);
}
fn Result<usize,errors::Error> bad_map_parity(u8 mode){
    let vec::Vec<ir::Program> programs=program_bank(mode);let ref ir::Program p=vec::at<ir::Program>(ref programs,0);
    let Failure expected=bad_map_scenario(p,mode,false)?;let Failure actual=bad_map_scenario(p,mode,true)?;
    let usize offset=if(mode==1){0}else{73};
    assert(expected.error.kind==5 && expected.error.offset==offset);
    assert(actual.error.kind==expected.error.kind && actual.error.offset==expected.error.offset);
    if(mode==1){
        // RET65 assigns handoff.remaining before the legacy pop fails. The
        // staged rejection publishes neither metadata nor this native debit.
        assert(actual.remaining==999999999 && expected.remaining==actual.remaining-runtime::handoff_cost());
    }else{let usize prefix=if(mode==5){meter::static_return()}else{0};
        assert(actual.remaining==999999999-prefix && actual.remaining==expected.remaining);
    }
    return .ok(0);
}

@test fn void ordinary_scalar_return_matches_raw_and_publishes_only_in_final_phase(){assert(parity(0).is_ok);}
@test fn void ret65_exclusive_return_matches_raw_with_cached_caller_binding(){assert(parity(1).is_ok);}
@test fn void reference79_loan_return_matches_raw_held_word_and_root_metadata(){assert(parity(2).is_ok);}
@test fn void aret_bool_owner_transfer_matches_raw_without_payload_changes(){assert(parity(3).is_ok);}
@test fn void sret_bool_record_owner_transfer_matches_raw_without_payload_changes(){assert(parity(4).is_ok);}
@test fn void static79_return_matches_raw_word_and_live_banks(){assert(parity(5).is_ok);}
@test fn void ordinary_bad_frame_map_preserves_ret_offset_and_unpublished_staged_state(){assert(bad_map_parity(0).is_ok);}
@test fn void static79_bad_frame_map_preserves_ret_offset_and_unpublished_staged_state(){assert(bad_map_parity(5).is_ok);}
@test fn void ret65_bad_frame_map_preserves_native_offset_and_unpublished_staged_state(){assert(bad_map_parity(1).is_ok);}

fn Result<Failure,errors::Error> early_context_error(u8 mode,bool staged_path){
    var vec::Vec<ir::Program> programs=program_bank(mode);let ref mut ir::Program p=vec::at_mut<ir::Program>(ref mut programs,0);
    if(mode==1){p.code[26]=16;}
    let statics::Sites sites=site_context(mode);var vec::Vec<runtime::State> runtime_storage=runtime_bank();
    let ref mut runtime::State state=vec::at_mut<runtime::State>(ref mut runtime_storage,0);
    var vec::Vec<frames::Frames> frame_storage=frame_bank(state);let ref mut frames::Frames bindings=vec::at_mut<frames::Frames>(ref mut frame_storage,0);
    var u8[64] data=[0;64];let usize entered=enter(p,bindings,state,ref mut data,mode)?;
    var usize[32] live=[0;32];var u32[512] current=[0;512];var i64[4096] registers=[0;4096];
    var inputs::State windows=inputs::disabled();let u8[16] origins=[0;16];
    if(mode==2){bindings.active[2]=false;live[2]=1;current[32]=words::pack(0,views::Span{.start=1,.length=2},73)?;}
    var adapter::State s=adapter::empty();var usize remaining=1000000000;
    var vec::Vec<Snapshot> before_storage=snapshot_bank(1);var vec::Vec<Snapshot> scratch=snapshot_bank(1);
    let ref mut Snapshot before=vec::at_mut<Snapshot>(ref mut before_storage,0);
    let usize saved=save_snapshot(before,state,bindings,ref live,ref current,ref registers,ref data,remaining)?;
    let Result<usize,errors::Error> result=if(staged_path){prepare_pending(ref mut s,p,ref sites,bindings,state,ref data,
        ref windows,ref origins,ref live,ref current,ref registers,ref mut remaining)}else{
        remaining-=1;adapter::begin(ref mut s,p,ref sites,3,bindings,state,ref data,4,ref windows,ref origins,ref live,ref current,ref registers,ref mut remaining)
    };
    let errors::Error e=switch(result){case .ok(_):{assert(false);errors::make(99,0)}case .err(v):{v}};
    before.remaining=remaining;let usize unchanged=frozen(before,ref mut scratch,state,bindings,ref live,ref current,ref registers,ref data,remaining)?;
    let usize drained=runtime::abort(state,64,0)?;return .ok(Failure{.error=e,.remaining=remaining});
}
fn Result<usize,errors::Error> early_context_parity(u8 mode){
    let Failure a=early_context_error(mode,false)?;let Failure b=early_context_error(mode,true)?;
    assert(a.error.kind==5 && a.error.offset==0 && a.remaining==999999999);
    assert(a.error.kind==b.error.kind && a.error.offset==b.error.offset && a.remaining==b.remaining);return .ok(0);
}
@test fn void ret65_invalid_selection_keeps_native_zero_offset(){assert(early_context_parity(1).is_ok);}
@test fn void reference79_invalid_frame_keeps_native_zero_offset(){assert(early_context_parity(2).is_ok);}
