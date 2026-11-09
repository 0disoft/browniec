module tests::m2::call_argument_work;
import call_argument_work as work;
import static_call_execution as transfer;
import reference_execution as references;
import reference_words as words;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import slice_result_bindings as receipts;
import array_owners as owners;
import array_layout as layouts;
import array_slices as slices;
import array_vm as arrays;
import input_reference_views as inputs;
import static_views as views;
import static_ir as statics;
import metadata_budget as budget;
import fuel as meter;
import ir as ir;
import errors as errors;
import std::vec as vec;

// mode0 Static; mode1 generic image; mode2 direct runtime ticket;
// mode3 input marker; mode4 returned-reference word. Only metadata is staged.
fn u8 byte(usize n){assert(n<256);var u8 out=0;var usize i=0;while(i<n){out+=1;i+=1;}return out;}
fn ir::Program program(usize mode,usize arity){
    var ir::Program p=ir::empty();let u8 count=byte(arity);let u8 actual=if(mode==2){160}else{192};
    p.count=2;p.function_count=2;p.starts[0]=0;p.ends[0]=1;p.starts[1]=1;p.ends[1]=2;
    p.register_starts[0]=0;p.register_ends[0]=8;p.register_starts[1]=8;p.register_ends[1]=16;
    p.registers=16;p.arities[1]=arity;p.call_count=1;p.call_arities[0]=count;
    p.code[0]=78;p.code[2]=1;p.code[8]=8;p.offsets[0]=73;p.offsets[1]=74;
    var usize i=0;while(i<arity){p.call_args[i]=actual;i+=1;}return p;
}
fn statics::Sites site_map(usize mode,usize arity,usize bad){
    var statics::Sites s=statics::empty();let u8 kind=if(mode==0){1}else{3};
    s.count=16;s.call_profile=true;s.functions[0]=0;s.definitions[0]=0;s.kinds[0]=if(mode>=3){3}else{1};
    s.spans[0].literal=0;s.spans[0].start=0;s.spans[0].end=1;
    var usize i=0;while(i<arity){let usize future=8+i;let u8 formal=byte(9+i);
        s.parameters[8+i]=kind;s.formal_sites[8+i]=formal;s.functions[future]=1;s.definitions[future]=0;s.kinds[future]=kind;
        s.spans[future].literal=0;s.spans[future].start=0;s.spans[future].end=1;i+=1;}
    if(bad==1 && arity!=0){let usize last=8+arity-1;s.formal_sites[last]=0;}return s;
}
// Each large constructor/return slot has its own short-lived setup frame. No
// verifier Bundle, whole image, full frame snapshot or stack override is used.
fn vec::Vec<ir::Program> program_bank(usize mode,usize arity){
    var vec::Vec<ir::Program> bank=vec::empty<ir::Program>();assert(vec::reserve<ir::Program>(ref mut bank,1).is_ok);
    assert(vec::push<ir::Program>(ref mut bank,program(mode,arity)).is_ok);return bank;
}
fn vec::Vec<runtime::State> runtime_bank(){
    var vec::Vec<runtime::State> bank=vec::empty<runtime::State>();assert(vec::reserve<runtime::State>(ref mut bank,1).is_ok);
    assert(vec::push<runtime::State>(ref mut bank,runtime::empty(64)).is_ok);return bank;
}
fn vec::Vec<work::State> work_bank(){
    var vec::Vec<work::State> bank=vec::empty<work::State>();assert(vec::reserve<work::State>(ref mut bank,1).is_ok);
    assert(vec::push<work::State>(ref mut bank,work::empty()).is_ok);return bank;
}
fn Result<slices::Ticket,errors::Error> native_window(ref mut runtime::State state,ref mut u8[] data){
    let layouts::Array shape=switch(layouts::scalar(10,4)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,0));}};
    let ref owners::Table original=ref state.runtime.owners;var owners::Table table=*original;
    let ref slices::Pool original_pool=ref state.runtime.pool;var slices::Pool pool=*original_pool;
    let owners::Token root=switch(owners::create(ref shape,42,data,ref mut table)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}};
    let slices::Ticket ticket=switch(slices::open(ref mut pool,ref mut table,root,0,4,64)){
        case .ok(v):{v}case .err(e):{return .err(arrays::failure(e,0));}};
    state.runtime.owners=table;state.runtime.pool=pool;return .ok(ticket);
}
fn Result<vec::Vec<frames::Frames>,errors::Error> frame_bank(ref runtime::State state,usize mode,usize bad,slices::Ticket ticket){
    var vec::Vec<frames::Frames> bank=vec::empty<frames::Frames>();assert(vec::reserve<frames::Frames>(ref mut bank,1).is_ok);
    assert(vec::push<frames::Frames>(ref mut bank,frames::empty(state)).is_ok);
    {
        let ref mut frames::Frames f=vec::at_mut<frames::Frames>(ref mut bank,0);f.frame=1;f.functions[1]=0;f.active[1]=true;
        let slices::Ticket source=if(bad==2){slices::Ticket{.slot=ticket.slot,.generation=ticket.generation+1}}else{ticket};f.sites[16]=source;
        if(mode==4 && bad!=3){
            let ref slices::Pool pool=ref state.runtime.pool;let slices::Slot entry=pool.slots[ticket.slot];
            let runtime::Held held=runtime::Held{.issued=ticket,.view=entry.view,.exclusive=false,.close_parent=false,.drop=false,.depth=0,.frame=1,.active=true};
            let usize retained=receipts::retain_reference(ref mut f.loans,1,0,held)?;assert(retained==0);
        }
    }return .ok(bank);
}
fn Result<inputs::State,errors::Error> input_bank(usize mode,usize bad){
    var inputs::State input=if(mode==3){inputs::open(0)?}else{inputs::disabled()};
    if(mode==3 && bad!=3){let usize saved=inputs::put(ref mut input,1,0,views::Span{.start=0,.length=0},0)?;}
    return .ok(input);
}
fn void same_capture(runtime::Capture a,runtime::Capture b){
    assert(a.ticket.slot==b.ticket.slot && a.ticket.generation==b.ticket.generation && a.close==b.close && a.drop==b.drop && a.ends==b.ends);
}
fn void same_result(ref references::Arguments a,ref references::Arguments b){
    assert(a.remaining==b.remaining && a.input_mask==b.input_mask);var usize i=0;
    while(i<16){assert(a.words[i]==b.words[i]);i+=1;}
    i=0;while(i<8){same_capture(a.captures[i],b.captures[i]);assert(a.tags[i]==b.tags[i]);
        assert(a.input_windows[i].start==b.input_windows[i].start && a.input_windows[i].length==b.input_windows[i].length);i+=1;}
}
fn void same_work(ref work::State a,ref work::State b){
    assert(a.remaining==b.remaining && a.target==b.target && a.map==b.map && a.offset==b.offset && a.count==b.count && a.index==b.index && a.price==b.price && a.work==b.work && a.word_mask==b.word_mask);
    assert(a.phase==b.phase && a.generic==b.generic && a.active==b.active && a.done==b.done);same_result(ref a.result,ref b.result);
}
fn void unchanged(ref runtime::State state,ref frames::Frames f,ref inputs::State input,usize mode,usize bad,
    usize depth,usize used,slices::Ticket ticket,usize pool_generation,usize read_generation){
    let ref owners::Table table=ref state.runtime.owners;let ref slices::Pool pool=ref state.runtime.pool;
    assert(table.depth==depth && table.arena.used==used && table.arena.limit==64 && state.runtime.authority.depth==0);
    assert(pool.slots[0].generation==pool_generation && table.slots[0].read_generation==read_generation);
    assert(f.frame==1 && f.functions[1]==0 && f.active[1] && !f.active[2] && f.functions[2]==16);
    assert(f.sites[16].slot==ticket.slot && f.sites[16].generation==ticket.generation);
    if(mode==2 || mode==4){assert(table.slots[0].live && table.slots[0].reading && pool.slots[0].live && !pool.slots[0].exclusive);}
    if(mode==4){let usize held=receipts::find(ref f.loans,1040);assert(held==if(bad==3){47}else{0});}
    assert(inputs::enabled(input)==(mode==3));
    if(mode==3){assert(inputs::get(input,1,0,0).is_ok==(bad!=3));assert(!inputs::get(input,2,8,0).is_ok);
        if(bad!=3){let views::Span span=switch(inputs::get(input,1,0,0)){case .ok(v):{v}case .err(_):{assert(false);views::Span{.start=0,.length=0}}};assert(span.start==0 && span.length==0);}
    }
}
fn Result<references::Arguments,errors::Error> oracle(bool generic,ref ir::Program p,ref statics::Sites sites,
    ref u32[] current,usize live,ref frames::Frames f,ref runtime::State state,ref inputs::State input,usize fuel){
    if(generic){return references::arguments_input(p,sites,0,0,current,live,f,state,64,1,fuel,input);}
    let transfer::Arguments value=transfer::arguments(p,sites,1,0,0,current,live,fuel)?;
    var references::Arguments result=references::empty(value.remaining);result.words=value.words;return .ok(result);
}
fn Result<usize,errors::Error> drive(ref mut work::State w,bool generic,ref ir::Program p,ref statics::Sites sites,
    ref u32[] current,usize live,ref frames::Frames f,ref runtime::State state,ref inputs::State input,usize initial,usize mode,usize bad){
    let usize begun=work::begin(w,generic,initial)?;assert(begun==0 && w.active && !w.done);
    let ref owners::Table table=ref state.runtime.owners;let ref slices::Pool pool=ref state.runtime.pool;
    let usize depth=table.depth;let usize used=table.arena.used;let usize epoch=table.slots[0].read_generation;
    let usize generation=pool.slots[0].generation;let slices::Ticket ticket=f.sites[16];
    var vec::Vec<work::State> snapshots=work_bank();let ref mut work::State saved=vec::at_mut<work::State>(ref mut snapshots,0);
    var budget::State allowance=budget::empty();var usize stages=0;
    while(stages<16){
        assert(budget::reset(ref mut allowance,0).is_ok);*saved=*w;let usize total=allowance.total;let usize count=allowance.stages;
        let bool admitted=switch(budget::admit(ref mut allowance,1,0)){case .ok(v):{v}case .err(_):{assert(false);false}};assert(admitted);
        let bool blocked=work::advance(w,p,sites,0,0,current,live,f,state,64,1,input,ref mut allowance)?;
        assert(!blocked && allowance.last==1 && allowance.total==total+1 && allowance.stages==count+1);
        same_work(w,saved);unchanged(state,f,input,mode,bad,depth,used,ticket,generation,epoch);
        assert(budget::reset(ref mut allowance,0).is_ok);assert(allowance.last==0 && allowance.total==total+1);
        let usize prior=allowance.total;let usize prior_count=allowance.stages;
        let Result<bool,errors::Error> result=work::advance(w,p,sites,0,0,current,live,f,state,64,1,input,ref mut allowance);
        stages+=1;assert(allowance.last==4096 && allowance.total==prior+4096 && allowance.stages==prior_count+1 && w.remaining==initial);
        unchanged(state,f,input,mode,bad,depth,used,ticket,generation,epoch);
        switch(result){case .err(e):{assert(!w.active && !w.done);let references::Arguments blank=references::empty(initial);same_result(ref w.result,ref blank);return .err(e);}
            case .ok(done):{if(done){assert(w.done && !w.active);return .ok(stages);}assert(w.active && !w.done);}};
    }
    assert(false);return .err(errors::make(99,0));
}
fn usize price(usize mode,usize arity){
    if(mode==0){return meter::static_call(arity);}
    let usize loans=if(mode==2 || mode==4){arity}else{0};let usize returned=if(mode==4){arity}else{0};let usize input=if(mode==3){arity}else{0};
    return meter::reference_call(arity,loans)+meter::reference_result_lookup()*returned+meter::input_arguments(input);
}
fn Result<usize,errors::Error> example(usize mode,usize arity,usize bad,bool low,u8 expected_error){
    let bool generic=mode!=0;let usize charge=price(mode,arity);
    let usize threshold=charge+if(generic){runtime::cost()+arity}else{0};let usize fuel=if(low){threshold-1}else{threshold};
    let vec::Vec<ir::Program> programs=program_bank(mode,arity);let ref ir::Program p=vec::at<ir::Program>(ref programs,0);
    let statics::Sites sites=site_map(mode,arity,bad);var vec::Vec<runtime::State> native=runtime_bank();let ref mut runtime::State state=vec::at_mut<runtime::State>(ref mut native,0);
    var u8[64] data=[0;64];let slices::Ticket ticket=if(mode==2 || mode==4){native_window(state,ref mut data)?}else{frames::none()};
    var vec::Vec<frames::Frames> stack=frame_bank(state,mode,bad,ticket)?;let ref frames::Frames f=vec::at<frames::Frames>(ref stack,0);
    let inputs::State input=input_bank(mode,bad)?;var u32[16] current=[0;16];
    current[0]=if(mode==3){inputs::marker()}else if(mode==4){words::pack_result(0,views::Span{.start=1,.length=2},73)?}else{1};
    let u32[16] original=current;let usize live=if(arity==0 || mode==2){0}else{1};
    let Result<references::Arguments,errors::Error> expected=oracle(generic,p,ref sites,ref current,live,f,state,ref input,fuel);
    var vec::Vec<work::State> states=work_bank();let ref mut work::State w=vec::at_mut<work::State>(ref mut states,0);
    let Result<usize,errors::Error> actual=drive(w,generic,p,ref sites,ref current,live,f,state,ref input,fuel,mode,bad);
    var usize stages=0;
    switch(expected){case .ok(value):{
        assert(expected_error==0);stages=actual?;same_result(ref value,ref w.result);assert(stages==arity+1 && w.result.remaining==fuel-charge);
        var usize i=0;while(i<arity){let usize future=8+i;
            if(mode==0 || mode==1){assert(w.result.words[future]==1 && w.result.tags[i]==0);}
            else if(mode==3){assert(w.result.words[future]==inputs::marker() && w.result.tags[i]==0 && w.result.input_windows[i].length==0);}
            else{assert(w.result.tags[i]==10);same_capture(w.result.captures[i],runtime::capture(ticket,false,false));
                let usize start=if(mode==4){1}else{0};let usize length=if(mode==4){2}else{4};
                let words::Word span=words::unpack(w.result.words[future],73)?;assert(span.argument==i && span.span.start==start && span.span.length==length);}
            i+=1;
        }
        if(mode==3){let usize one=1;assert(w.result.input_mask==(one<<arity)-1);}
    }case .err(error):{
        assert(error.kind==expected_error && error.offset==73);
        switch(actual){case .ok(_):{assert(false);}case .err(found):{assert(found.kind==error.kind && found.offset==error.offset);}};
        if(low && generic){assert(w.phase==0 && w.index==0);}
        if(!generic && bad==1){assert(w.index==arity-1);}
    }};
    var usize i=0;while(i<16){assert(current[i]==original[i]);i+=1;}
    if(mode==2 || mode==4){i=0;while(i<4){assert(data[i]==42);i+=1;}}
    return .ok(stages);
}

@test fn void eight_static_arguments_match_raw_and_validate_late_actual_before_fuel(){
    assert(example(0,8,0,false,0).is_ok);assert(example(0,8,0,true,8).is_ok);
    assert(example(0,8,1,false,5).is_ok);assert(example(0,8,1,true,5).is_ok);
}
@test fn void generic_image_runtime_input_and_returned_sources_match_all_result_fields(){
    assert(example(1,8,0,false,0).is_ok);assert(example(2,8,0,false,0).is_ok);
    assert(example(3,1,0,false,0).is_ok);assert(example(4,1,0,false,0).is_ok);
}
@test fn void generic_preprice_shortage_precedes_late_destination_authentication(){
    var usize mode=1;while(mode<=4){assert(example(mode,8,1,true,8).is_ok);assert(example(mode,8,1,false,5).is_ok);mode+=1;}
}
@test fn void stale_runtime_and_missing_input_or_returned_receipt_fail_after_preprice(){
    assert(example(2,1,2,false,5).is_ok);assert(example(2,1,2,true,8).is_ok);
    assert(example(3,1,3,false,5).is_ok);assert(example(3,1,3,true,8).is_ok);
    assert(example(4,1,3,false,5).is_ok);assert(example(4,1,3,true,8).is_ok);
}
@test fn void zero_arity_still_pays_positive_static_price_and_every_stage_defers_privately(){
    assert(meter::static_call(0)>0);assert(example(0,0,0,false,0).is_ok);assert(example(0,0,0,true,8).is_ok);
    assert(example(1,0,0,false,0).is_ok);assert(example(1,0,0,true,8).is_ok);
    // All preceding cases pre-admit one unit before EVERY real stage. All
    // result/progress fields and pinned live metadata stay unchanged on defer.
}
