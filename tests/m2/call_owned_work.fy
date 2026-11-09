module tests::m2::call_owned_work;
import call_owned_work as work;
import call_capture_plan as plans;
import slice_result_owned_execution as owned;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import slice_result_record_bindings as record_bindings;
import array_slices as slices;
import array_owners as owners;
import struct_call_vm as calls;
import metadata_budget as budget;
import ir as ir;
import errors as errors;
import std::vec as vec;

fn u8 byte(usize value){assert(value<256);var u8 out=0;var usize i=0;while(i<value){out+=1;i+=1;}return out;}
// These fixtures authenticate metadata preparation only. Tickets/tokens/Held
// are synthetic; no backing bytes, runtime authority or live frame is published.
// mode0: eight mixed owned args; mode1: eight arrays; mode2: CALL66 with one
// borrow plus seven owned args; mode3: eight borrows; mode4: zero args.
fn ir::Program program(usize mode,u8 op){
    var ir::Program p=ir::empty();p.count=2;p.function_count=2;p.registers=16;
    p.starts[0]=0;p.ends[0]=1;p.starts[1]=1;p.ends[1]=2;
    p.register_starts[0]=0;p.register_ends[0]=8;p.register_starts[1]=8;p.register_ends[1]=16;
    let usize arity=if(mode==4){0}else{8};p.arities[1]=arity;p.call_count=1;p.call_arities[0]=byte(arity);
    p.code[0]=op;p.code[2]=1;p.code[8]=8;p.offsets[0]=173;p.offsets[1]=174;
    p.arrays.count=if(mode==1){8}else if(mode==0 || mode==2){4}else{0};
    let u8[8] tags=[2,1,9,10,11,12,2,10];var usize i=0;
    while(i<p.arrays.count){p.arrays.elements[i]=tags[i];p.arrays.lengths[i]=i+1;i+=1;}
    if(mode==0 || mode==2){p.records.count=if(mode==2){3}else{4};
        p.records.layouts.count=1;p.records.layouts.fields[0]=2;p.records.layouts.types[0]=2;p.records.layouts.types[1]=1;}
    if(mode==0){let u8[8] args=[128,144,129,145,130,146,131,147];p.call_args[0]=args[0];
        i=0;while(i<8){p.call_args[i]=args[i];let usize id=i/2;
            if(i%2==0){p.array_parameters[8+i]=byte(id+1);}else{p.record_parameters[8+i]=byte(id+1);}i+=1;}
    }else if(mode==1){i=0;while(i<8){p.call_args[i]=byte(128+i);p.array_parameters[8+i]=byte(i+1);i+=1;}}
    else if(mode==3){i=0;while(i<8){p.call_args[i]=byte(160+i);p.slice_parameters[8+i]=byte(i+1);i+=1;}}
    if(mode==2){
        // Reuse call_capture_live's two-link recipe. The earlier call targets
        // function0 (arity1), while final map1 targets the eight-argument callee.
        p.count=9;p.starts[0]=0;p.ends[0]=8;p.starts[1]=8;p.ends[1]=9;p.arities[0]=1;
        p.slice_parameters[0]=1;p.slice_parameters[8]=1;p.call_count=2;p.call_arities[0]=1;p.call_arities[1]=8;
        i=0;while(i<16){p.types[i]=12;p.slice_elements[i]=138;p.slice_origins[i]=1;p.slice_functions[i]=1;i+=1;}
        p.call_args[0]=161;let u8[8] args=[162,128,144,129,145,130,146,131];
        i=0;while(i<8){p.call_args[8+i]=args[i];i+=1;}
        i=1;while(i<8){let usize id=(i-1)/2;
            if(i%2==1){p.array_parameters[8+i]=byte(id+1);}else{p.record_parameters[8+i]=byte(id+1);}i+=1;}
        // Clear the ordinary instruction before installing the canonical recipe.
        i=0;while(i<72){p.code[i]=0;i+=1;}
        p.code[0]=61;p.code[1]=1;p.code[4]=1;
        p.code[8]=66;p.code[9]=2;p.code[10]=0;p.code[11]=0;p.code[13]=2;p.code[14]=1;
        p.code[16]=67;p.code[17]=2;p.code[18]=1;p.code[20]=1;
        p.code[24]=66;p.code[25]=2;p.code[26]=1;p.code[27]=1;p.code[28]=1;p.code[29]=3;
        p.code[32]=68;p.code[33]=2;p.code[34]=1;p.code[40]=68;p.code[41]=1;
        p.code[48]=67;p.code[49]=3;p.code[52]=1;p.code[56]=8;p.code[64]=65;
        i=0;while(i<9){p.offsets[i]=100+i;i+=1;}
    }
    return p;
}
// Large Program/Frames constructors, snapshots and native return slots live in
// separate short-lived setup frames. Persistent values use SDK banks.
fn vec::Vec<ir::Program> program_bank(usize mode,u8 op){
    var vec::Vec<ir::Program> bank=vec::empty<ir::Program>();assert(vec::reserve<ir::Program>(ref mut bank,1).is_ok);
    assert(vec::push<ir::Program>(ref mut bank,program(mode,op)).is_ok);return bank;
}
fn vec::Vec<ir::Program> program_snapshot(ref ir::Program p){
    var vec::Vec<ir::Program> bank=vec::empty<ir::Program>();assert(vec::reserve<ir::Program>(ref mut bank,1).is_ok);
    assert(vec::push<ir::Program>(ref mut bank,*p).is_ok);return bank;
}
fn vec::Vec<frames::Frames> frame_bank(){
    let runtime::State state=runtime::empty(64);var vec::Vec<frames::Frames> bank=vec::empty<frames::Frames>();
    assert(vec::reserve<frames::Frames>(ref mut bank,1).is_ok);
    assert(vec::push<frames::Frames>(ref mut bank,frames::empty(ref state)).is_ok);return bank;
}
fn vec::Vec<frames::Frames> frame_snapshot(ref frames::Frames f){
    var vec::Vec<frames::Frames> bank=vec::empty<frames::Frames>();assert(vec::reserve<frames::Frames>(ref mut bank,1).is_ok);
    assert(vec::push<frames::Frames>(ref mut bank,*f).is_ok);return bank;
}
fn vec::Vec<work::State> work_bank(){
    var vec::Vec<work::State> bank=vec::empty<work::State>();assert(vec::reserve<work::State>(ref mut bank,1).is_ok);
    assert(vec::push<work::State>(ref mut bank,work::empty()).is_ok);return bank;
}
fn runtime::Contract contract(usize mode){
    let u8[8] tags=if(mode==2){[138,0,0,0,0,0,0,0]}else if(mode==3){[10;8]}else{[0;8]};
    return runtime::Contract{.tags=tags,.arity=if(mode==4){0}else{8},.selected=if(mode==2){1}else{0}};
}
fn runtime::Capture[8] supplied(usize mode){
    var runtime::Capture[8] out=[runtime::capture(frames::none(),false,false);8];var usize i=0;
    while(i<if(mode==2){1}else{8}){let slices::Ticket ticket=slices::Ticket{.slot=7-i,.generation=77+i};
        out[i]=if(i%2==0){runtime::chain_capture(ticket,if(mode==2){2}else{i+1})}else{runtime::capture(ticket,false,true)};i+=1;}
    return out;
}
fn void configure(ref mut frames::Frames f,usize mode,usize variant){
    f.frame=1;f.active[1]=true;f.functions[1]=0;f.remaining[1]=987654;
    var usize i=0;while(i<8){f.tokens[16+i]=owners::Token{.slot=i,.generation=11+i};
        record_bindings::bind(ref mut f.records,16+i,owners::Token{.slot=8+i,.generation=31+i});
        f.sites[16+i]=slices::Ticket{.slot=i,.generation=51+i};i+=1;}
    if(mode==2){
        // Put the required Held last to exercise the complete find47 search.
        var runtime::Held held=f.loans.held[46];held.active=variant!=1;held.frame=1;held.depth=3;
        held.issued=slices::Ticket{.slot=1,.generation=7};held.exclusive=variant!=2;
        held.close_parent=variant==3;held.drop=variant==4;
        f.loans.held[46]=held;f.loans.locations[46]=18;f.loans.parents[46]=16;f.sites[18]=held.issued;
        if(variant==5){held.issued=slices::Ticket{.slot=2,.generation=7};f.loans.held[45]=held;f.loans.locations[45]=17;f.loans.parents[45]=16;}
        // Held errors must win before this late descriptor error.
        if((variant>=1 && variant<=5) || variant==9){f.tokens[35]=owners::Token{.slot=3,.generation=99};}
        if(variant==10){record_bindings::bind(ref mut f.records,34,owners::Token{.slot=15,.generation=99});}
    }else{
        if(variant==9){f.tokens[if(mode==1){39}else{35}]=owners::Token{.slot=3,.generation=99};}
        if(variant==10){record_bindings::bind(ref mut f.records,35,owners::Token{.slot=15,.generation=99});}
    }
}
fn void same_ticket(slices::Ticket a,slices::Ticket b){assert(a.slot==b.slot && a.generation==b.generation);}
fn void same_token(owners::Token a,owners::Token b){assert(a.slot==b.slot && a.generation==b.generation);}
fn void same_capture(runtime::Capture a,runtime::Capture b){same_ticket(a.ticket,b.ticket);assert(a.close==b.close && a.drop==b.drop && a.ends==b.ends);}
fn void same_view(owners::View a,owners::View b){same_token(a.root,b.root);assert(a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end);}
fn void same_prepared(ref owned::Prepared a,ref owned::Prepared b){
    assert(a.count==b.count && a.owned==b.owned && a.records==b.records);var usize i=0;
    while(i<8){same_capture(a.captures[i],b.captures[i]);same_token(a.sources[i],b.sources[i]);
        assert(a.destinations[i]==b.destinations[i] && a.record_args[i]==b.record_args[i]);
        assert(a.shapes[i].element==b.shapes[i].element && a.shapes[i].length==b.shapes[i].length && a.shapes[i].stride==b.shapes[i].stride && a.shapes[i].alignment==b.shapes[i].alignment && a.shapes[i].bytes==b.shapes[i].bytes);
        same_token(a.arguments[i].source,b.arguments[i].source);
        assert(a.arguments[i].element==b.arguments[i].element && a.arguments[i].length==b.arguments[i].length && a.arguments[i].record==b.arguments[i].record);i+=1;}
}
fn void same_work(ref work::State a,ref work::State b){
    assert(a.phase==b.phase && a.index==b.index && a.active==b.active && a.done==b.done);same_prepared(ref a.result,ref b.result);
    assert(a.entry.required==b.entry.required && a.entry.absent==b.entry.absent);var usize i=0;
    while(i<8){assert(a.entry.ends[i]==b.entry.ends[i] && a.entry.parents[i]==b.entry.parents[i]);i+=1;}
}
fn void same_frames(ref frames::Frames a,ref frames::Frames b){
    assert(a.frame==b.frame);var usize i=0;
    while(i<512){same_token(a.tokens[i],b.tokens[i]);same_ticket(a.sites[i],b.sites[i]);same_ticket(a.before[i],b.before[i]);i+=1;}
    i=0;while(i<256){same_capture(a.captures[i],b.captures[i]);same_view(a.views[i],b.views[i]);same_ticket(a.issued[i],b.issued[i]);assert(a.tags[i]==b.tags[i]);i+=1;}
    i=0;while(i<32){same_ticket(a.results[i],b.results[i]);
        assert(a.arities[i]==b.arities[i] && a.selected[i]==b.selected[i] && a.depths[i]==b.depths[i] && a.remaining[i]==b.remaining[i] && a.active[i]==b.active[i]);
        assert(a.functions[i]==b.functions[i] && a.continuations[i]==b.continuations[i] && a.maps[i]==b.maps[i] && a.destinations[i]==b.destinations[i] && a.identities[i]==b.identities[i] && a.prepared[i]==b.prepared[i]);i+=1;}
    i=0;while(i<16){same_token(a.records.tokens[i],b.records.tokens[i]);assert(a.records.locations[i]==b.records.locations[i]);i+=1;}
    i=0;while(i<47){let runtime::Held x=a.loans.held[i];let runtime::Held y=b.loans.held[i];
        same_ticket(x.issued,y.issued);same_view(x.view,y.view);
        assert(x.exclusive==y.exclusive && x.close_parent==y.close_parent && x.drop==y.drop && x.depth==y.depth && x.frame==y.frame && x.active==y.active);
        assert(a.loans.locations[i]==b.loans.locations[i] && a.loans.parents[i]==b.loans.parents[i]);i+=1;}
}
fn void same_cache(ref plans::Plan a,ref plans::Plan b){
    assert(a.ready==b.ready);var usize i=0;while(i<32){assert(a.pcs[i]==b.pcs[i] && a.required[i]==b.required[i] && a.absent[i]==b.absent[i]);i+=1;}
    i=0;while(i<256){assert(a.ends[i]==b.ends[i] && a.parents[i]==b.parents[i]);i+=1;}
}
fn void same_program(ref ir::Program a,ref ir::Program b){
    assert(a.count==b.count && a.registers==b.registers && a.constant_count==b.constant_count && a.function_count==b.function_count && a.entry==b.entry && a.call_count==b.call_count && a.list_used==b.list_used);
    assert(a.arrays.count==b.arrays.count && a.records.count==b.records.count && a.records.layouts.count==b.records.layouts.count);
    var usize i=0;while(i<2048){assert(a.code[i]==b.code[i]);i+=1;}
    i=0;while(i<256){assert(a.offsets[i]==b.offsets[i] && a.call_args[i]==b.call_args[i]);i+=1;}
    i=0;while(i<128){assert(a.constants[i]==b.constants[i] && a.types[i]==b.types[i] && a.slots[i]==b.slots[i] && a.array_parameters[i]==b.array_parameters[i] && a.record_parameters[i]==b.record_parameters[i] && a.slice_parameters[i]==b.slice_parameters[i]);i+=1;}
    i=0;while(i<32){assert(a.call_arities[i]==b.call_arities[i] && a.records.layouts.fields[i]==b.records.layouts.fields[i]);i+=1;}
    i=0;while(i<16){
        assert(a.starts[i]==b.starts[i] && a.ends[i]==b.ends[i] && a.register_starts[i]==b.register_starts[i] && a.register_ends[i]==b.register_ends[i] && a.arities[i]==b.arities[i] && a.return_types[i]==b.return_types[i]);
        assert(a.array_functions[i]==b.array_functions[i] && a.record_functions[i]==b.record_functions[i] && a.array_results[i]==b.array_results[i] && a.record_results[i]==b.record_results[i]);
        assert(a.slice_roots[i]==b.slice_roots[i] && a.slice_origins[i]==b.slice_origins[i] && a.slice_functions[i]==b.slice_functions[i] && a.slice_elements[i]==b.slice_elements[i]);
        assert(a.arrays.elements[i]==b.arrays.elements[i] && a.arrays.lengths[i]==b.arrays.lengths[i] && a.arrays.mutable[i]==b.arrays.mutable[i] && a.records.records[i]==b.records.records[i] && a.records.mutable[i]==b.records.mutable[i]);i+=1;}
    i=0;while(i<512){assert(a.records.layouts.kinds[i]==b.records.layouts.kinds[i] && a.records.layouts.types[i]==b.records.layouts.types[i]);i+=1;}
    i=0;while(i<4096){assert(a.list_operands[i]==b.list_operands[i]);i+=1;}
}
fn Result<usize,errors::Error> drive(ref mut work::State w,ref ir::Program p,ref ir::Program original,
    usize pc,runtime::Contract binding,ref frames::Frames f,ref frames::Frames before,
    usize fuel,ref runtime::Capture[] input,ref plans::Plan cache,bool probe){
    let usize begun=work::begin(w)?;assert(begun==0 && w.active && !w.done);
    let plans::Plan saved_cache=*cache;var budget::State allowance=budget::empty();
    var vec::Vec<work::State> saved_bank=work_bank();let ref mut work::State saved=vec::at_mut<work::State>(ref mut saved_bank,0);
    var usize stages=0;while(stages<128){
        assert(budget::reset(ref mut allowance,0).is_ok);assert(allowance.last==0);
        if(probe){*saved=*w;let usize total=allowance.total;let usize count=allowance.stages;
            let bool admitted=switch(budget::admit(ref mut allowance,1,0)){case .ok(v):{v}case .err(_):{assert(false);false}};assert(admitted);
            let bool done=work::advance(w,p,pc,binding,f,fuel,input,cache,ref mut allowance)?;
            assert(!done && allowance.last==1 && allowance.total==total+1 && allowance.stages==count+1);
            same_work(w,saved);same_frames(f,before);same_program(p,original);same_cache(cache,ref saved_cache);
            assert(budget::reset(ref mut allowance,0).is_ok);assert(allowance.last==0 && allowance.total==total+1);
        }
        let usize total=allowance.total;let usize count=allowance.stages;
        let Result<bool,errors::Error> next=work::advance(w,p,pc,binding,f,fuel,input,cache,ref mut allowance);
        stages+=1;assert(allowance.last==4096 && allowance.total==total+4096 && allowance.stages==count+1);
        same_frames(f,before);same_program(p,original);same_cache(cache,ref saved_cache);
        switch(next){case .err(e):{assert(!w.active && !w.done);return .err(e);}case .ok(done):{
            if(done){assert(w.done && !w.active);return .ok(stages);}assert(w.active && !w.done);
        }};
    }
    assert(false);return .err(errors::make(99,0));
}
fn Result<usize,errors::Error> example(usize mode,u8 op,usize variant,usize supplied_count,bool low,u8 expected_error){
    var vec::Vec<ir::Program> programs=program_bank(mode,op);let ref mut ir::Program p=vec::at_mut<ir::Program>(ref mut programs,0);
    let usize pc=if(mode==2){3}else{0};let runtime::Contract binding=contract(mode);
    let usize price=calls::cost(p,1,p.offsets[pc])?+binding.arity;let usize exact=runtime::cost()+price;
    let usize fuel=if(low){exact-1}else{exact};
    var plans::Plan cache=if(mode==2){plans::prepare(p)?}else{plans::empty()};
    if(variant==6){cache.ready=false;}if(variant==7){cache.pcs[1]=256;}if(variant==8){cache.ends[8]=17;}
    if(variant==11){p.arrays.elements[3]=3;}
    var vec::Vec<frames::Frames> stack=frame_bank();let ref mut frames::Frames f=vec::at_mut<frames::Frames>(ref mut stack,0);configure(f,mode,variant);
    let vec::Vec<ir::Program> originals=program_snapshot(p);let ref ir::Program original=vec::at<ir::Program>(ref originals,0);
    let vec::Vec<frames::Frames> before_bank=frame_snapshot(f);let ref frames::Frames before=vec::at<frames::Frames>(ref before_bank,0);
    let runtime::Capture[8] input=supplied(mode);let runtime::Capture[8] saved_input=input;
    let Result<owned::Prepared,errors::Error> expected=if(mode==2){owned::prepare_enter_cached(p,pc,binding,f,fuel,ref input[..supplied_count],ref cache)}
        else{owned::prepare_enter(p,pc,binding,f,fuel,ref input[..supplied_count])};
    var vec::Vec<work::State> storage=work_bank();let ref mut work::State w=vec::at_mut<work::State>(ref mut storage,0);
    let Result<usize,errors::Error> actual=drive(w,p,original,pc,binding,f,before,fuel,ref input[..supplied_count],ref cache,true);
    var usize stages=0;
    switch(expected){case .ok(value):{
        assert(expected_error==0);stages=actual?;same_prepared(ref value,ref w.result);assert(w.result.owned==price);
        if(mode==0 || mode==1){assert(w.result.count==8 && stages>=17);}
        if(mode==2){assert(w.result.count==7 && w.result.records && stages>=33);
            let owned::Prepared raw=owned::prepare_enter(p,pc,binding,f,fuel,ref input[..supplied_count])?;same_prepared(ref raw,ref value);
            assert(w.entry.required==4 && w.entry.absent==2 && w.entry.ends[0]==2);
            let runtime::Capture captured=w.result.captures[0];assert(captured.ends==2 && captured.close && !captured.drop);
            assert(captured.ticket.generation==if(supplied_count==0){7}else{77});
        }
        if(mode==3){assert(w.result.count==0 && !w.result.records);var usize i=0;
            while(i<8){if(supplied_count==0){same_ticket(w.result.captures[i].ticket,f.sites[16+i]);assert(w.result.captures[i].ends==0);}
                else{same_capture(w.result.captures[i],input[i]);}i+=1;}}
        if(mode==4){assert(w.result.count==0 && !w.result.records && w.result.owned==0);}
    }case .err(error):{
        assert(error.kind==expected_error);
        switch(actual){case .ok(_):{assert(false);}case .err(found):{assert(found.kind==error.kind && found.offset==error.offset);}};
        if(mode==2 && variant>=1 && variant<=5 && !low){
            assert(w.phase==2 && w.result.count==0);
            switch(owned::prepare_enter(p,pc,binding,f,fuel,ref input[..supplied_count])){
                case .ok(_):{assert(false);}case .err(raw):{assert(raw.kind==error.kind && raw.offset==error.offset);}};
        }
        if((variant==9 || variant==10) && !low){assert(w.phase==3 && w.result.count>0);}
        if(low && variant!=11){assert(error.kind==8 && w.phase==0);}
    }};
    var usize i=0;while(i<8){same_capture(input[i],saved_input[i]);i+=1;}
    same_frames(f,before);same_program(p,original);assert(fuel==if(low){exact-1}else{exact});return .ok(stages);
}

@test fn void eight_mixed_owned_and_all_array_descriptors_match_atomic_preparation(){
    let u8[3] ops=[9,64,78];var usize i=0;while(i<3){assert(example(0,ops[i],0,0,false,0).is_ok);i+=1;}
    assert(example(1,9,0,0,false,0).is_ok);
}
@test fn void supplied_and_derived_captures_preserve_all_flags_and_full_arity(){
    assert(example(3,78,0,8,false,0).is_ok);assert(example(3,78,0,0,false,0).is_ok);
    assert(example(3,64,0,8,false,0).is_ok);assert(example(3,78,0,7,false,5).is_ok);
    assert(example(3,78,0,7,true,8).is_ok);
}
@test fn void cached_call66_held_recipe_and_seven_owned_arguments_match_raw(){
    assert(example(2,66,0,0,false,0).is_ok);assert(example(2,66,0,8,false,0).is_ok);
}
@test fn void cached_required_and_absent_held_errors_precede_late_destination(){
    var usize variant=1;while(variant<=5){assert(example(2,66,variant,0,false,5).is_ok);variant+=1;}
    assert(example(2,66,9,0,false,5).is_ok);assert(example(2,66,10,0,false,5).is_ok);
}
@test fn void exact_fuel_and_one_less_preserve_cost_cache_and_destination_error_order(){
    assert(example(0,9,0,0,true,8).is_ok);assert(example(1,9,0,0,true,8).is_ok);
    assert(example(0,9,9,0,false,5).is_ok);assert(example(0,9,10,0,false,5).is_ok);
    assert(example(0,9,10,0,true,8).is_ok);assert(example(0,9,11,0,true,5).is_ok);
    var usize variant=6;while(variant<=8){assert(example(2,66,variant,0,false,5).is_ok);variant+=1;}
    assert(example(2,66,6,0,true,8).is_ok);
}
@test fn void partial_room_leaves_every_phase_private_and_zero_arity_finishes(){
    // Every example pre-admits one unit before EVERY stage, including each Held
    // scan and late failure. All Work fields, cache, captures, IR and Frames are
    // compared before a fresh reset admits the actual 4096-unit stage.
    assert(example(0,9,0,0,false,0).is_ok);assert(example(2,66,0,0,false,0).is_ok);
    assert(example(4,9,0,0,false,0).is_ok);assert(example(4,9,0,0,true,8).is_ok);
}
