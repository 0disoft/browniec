module tests::m2::output_place_lifetimes_work;
import output_place_lifetimes_work as work;
import place_ir as raw;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
import struct_meta as records;
import aggregate_place_ir as aggregates;
import verifier as verifier;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(n):{n}case .err(_):{assert(false);0}};}
fn void finish(ref mut ir::Program p){p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize count=p.count;let usize registers=p.registers;p.ends[0]=count;p.register_ends[0]=registers;}
fn usize cell(ref mut ir::Program p,u8 tag){return if(tag==2){built(ir::boolean(p,true,0))}else{built(ir::integer(p,42,tag,0))};}
fn records::Prepared shapes(ref ir::Program p){return switch(records::prepare(ref p.records)){
    case .ok(v):{v}case .err(_):{assert(false);records::Prepared{.leaves=[0;16],.tags=[0;2048]}}};
}
fn Result<usize,errors::Error> staged(ref mut ir::Program p){
    var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<4096);assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(p,ref mut w,ref mut meter)?;assert(done==w.done);turns+=1;}
    let usize total=meter.total;assert(work::advance(p,ref mut w,ref mut meter).is_ok);
    assert(total==meter.total);return .ok(w.count);
}
fn void same(ir::Program p){let records::Prepared shapes=shapes(ref p);
    switch(raw::inspect_prepared(ref p,ref shapes)){
        case .ok(expected):{var ir::Program copy=p;switch(staged(ref mut copy)){case .ok(actual):{assert(expected==actual);}case .err(_):{assert(false);}};}
        case .err(expected):{var ir::Program copy=p;switch(staged(ref mut copy)){case .ok(_):{assert(false);}case .err(actual):{
            assert(expected.kind==actual.kind && expected.offset==actual.offset);}};}
    };
}
fn usize find(ref ir::Program p,u8 op){var usize pc=0;while(pc<p.count){if(p.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;}
fn bool has(ref ir::Program p,u8 op){var usize pc=0;while(pc<p.count){if(p.code[pc*8]==op){return true;}pc+=1;}return false;}
fn void jump(ref mut ir::Program p,usize pc,usize target){var usize i=0;while(i<8){p.code[pc*8+i]=0;i+=1;}
    p.code[pc*8]=19;let usize patched=built(ir::patch(p,pc,target,0));}
// constant0, INIT1, SELECT2, READ/STORE/REPLACE3, END4, DROP5, constant6, RETURN7.
fn ir::Program basic(u8 mode){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize root=built(ir::array(ref mut p,1,2,true,0));let usize fill=cell(ref mut p,1);
    let usize init=built(ir::array_init(ref mut p,root,fill,0));let usize index=built(ir::integer(ref mut p,1,12,0));
    let usize selected=built(ir::place_select(ref mut p,0,root,index,0));
    if(mode==0){let usize read=built(ir::place_read(ref mut p,0,root,0));}
    else{let usize stored=built(ir::place_store(ref mut p,0,root,fill,0));}
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize dropped=built(ir::array_drop(ref mut p,root,0));
    let usize result=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,result,0,0));finish(ref mut p);return p;
}
fn ir::Program replace(bool list){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize root=built(ir::array(ref mut p,1,2,true,0));let usize fill=cell(ref mut p,1);
    let usize init=built(ir::array_init(ref mut p,root,fill,0));let usize selected=built(aggregates::select_array(ref mut p,0,root,0));
    if(list){let usize[2] values=[fill,fill];let usize replaced=built(aggregates::replace_array(ref mut p,0,root,ref values,0));}
    else{let usize filled=built(aggregates::fill_array(ref mut p,0,root,fill,0));}
    let usize ended=built(ir::place_end(ref mut p,0,0));let usize dropped=built(ir::array_drop(ref mut p,root,0));
    let usize result=built(ir::literal(ref mut p,42,0));let usize returned=built(ir::emit(ref mut p,8,result,0,0));finish(ref mut p);return p;
}
@test fn void select_read_store_replace_and_runtime_abort_match_raw_exactly(){
    same(basic(0));same(basic(1));same(replace(false));same(replace(true));
    var ir::Program p=basic(1);assert(!has(ref p,25));let usize trap=built(ir::raw(ref mut p,25,0,0,0,0));
    let usize count=p.count;p.ends[0]=count;same(p);
}
@test fn void branch_identity_mismatch_loop_obligation_and_dead_metadata_match_raw(){
    var ir::Program p=basic(0);let usize read=find(ref p,84);jump(ref mut p,2,read);same(p);
    p=basic(1);let usize select=find(ref p,83);p.code[select*8+1]=1;same(p);
    p=basic(1);let usize store=find(ref p,85);p.code[store*8]=83;p.code[store*8+2]=0;p.code[store*8+3]=0;same(p);
    p=basic(1);let usize unreachable=built(ir::raw(ref mut p,84,0,0,0,0));finish(ref mut p);
    // Dead structural metadata belongs to the trusted canonical precondition.
    assert(!verifier::inspect(ref p).is_ok);
}
@test fn void one_pc_stages_and_full_origin_initialization_are_observable(){
    var ir::Program p=basic(1);var work::State w=work::empty();var budget::State meter=budget::empty();
    var usize turns=0;var usize observed=0;var usize full=0;
    while(!w.done){assert(turns<4096);assert(budget::reset(ref mut meter,0).is_ok);let u8 phase=w.phase;let usize pc=w.pc;
        assert(work::advance(ref p,ref mut w,ref mut meter).is_ok);
        if(phase==2){assert(w.cleared==2048 || w.cleared==4096);if(w.cleared==4096){full+=1;}}
        if(phase==4 && w.phase==4 && !w.done){assert(w.pc==pc+1);observed+=1;}
        turns+=1;}assert(turns>=p.count+3 && observed==p.count && full==1 && w.count==1);
}
@test fn void no_place_fast_path_finishes_without_a_graph_frame(){
    var ir::Program p=ir::empty();p.count=1;p.function_count=1;p.registers=1;p.ends[0]=1;
    p.register_ends[0]=1;p.code[0]=82;
    assert(switch(staged(ref mut p)){case .ok(n):{n==0}case .err(_):{false}});
}
