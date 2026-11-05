module tests::m2::reference_return_execution;
import static_call_ir as calls;
import static_call_sites as windows;
import static_ir as statics;
import static_views as views;
import static_image as images;
import ir as ir;
import errors as errors;
import verifier as verifier;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import slice_result_frames as frames;
import reference_words as words;
import reference_return_execution as transfers;
import program_image as programs;
import std::num as num;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 byte(usize n){return switch(num::u8_from_i64(switch(num::i64_from_usize(n)){case .ok(v):{v}case .err(_):{assert(false);0}})){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize fresh(ref mut ir::Program p,u8 tag){let usize r=p.registers;p.types[r]=tag;p.registers+=1;return r;}
fn void end(ref mut ir::Program p,usize f){let usize pc=p.count;let usize r=p.registers;p.ends[f]=pc;p.register_ends[f]=r;
    if(f+1<p.function_count){p.starts[f+1]=pc;p.register_starts[f+1]=r;}}
fn images::Image image(){
    var images::Builder b=switch(images::builder(3)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    let usize a=switch(images::intern_bytes(ref mut b,b"@#$")){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(images::freeze(ref b,579)){case .ok(v):{v}case .err(_):{assert(false);image()}};
}
fn usize call(ref mut ir::Program p,usize dst,usize target,ref usize[] args){
    let usize map=p.call_count;p.call_count+=1;p.call_arities[map]=byte(args.len);
    var usize i=0;while(i<args.len){p.call_args[map*8+i]=byte(args[i]);i+=1;}
    return built(ir::raw(p,78,dst,target,map,0));
}
fn usize find(ref ir::Program p,u8 op,usize nth){var usize n=0;var usize pc=0;
    while(pc<p.count){if(p.code[pc*8]==op){if(n==nth){return pc;}n+=1;}pc+=1;}assert(false);return 0;}
// Same returned signature is called with an image and a rooted runtime loan.
// Full canonical proof adds owner lifetimes to these return recipes.
fn calls::Program unit(usize arity,bool prefix,u8 projection,bool forward,bool length,bool image_only){
    var ir::Program p=ir::empty();p.function_count=if(forward){3}else{2};p.return_types[0]=1;
    let usize fill=built(ir::integer(ref mut p,42,10,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,3,12,0));
    if(!image_only){let usize root=built(ir::array_in(ref mut p,0,10,3,false,0));let usize init=built(ir::array_init(ref mut p,root,fill,0));
        let usize loan=built(ir::slice(ref mut p,root,0));let usize opened=built(ir::slice_open(ref mut p,loan,lo,hi,0));}
    let usize literal=built(ir::raw(ref mut p,69,0,0,1,0));p.code[literal*8+6]=3;
    var usize[8] actuals=[192;8];if(prefix){actuals[0]=fill;}
    let usize first=call(ref mut p,1,1,ref actuals[..arity]);let usize left=fresh(ref mut p,if(length){12}else{10});
    let usize read_left=built(ir::raw(ref mut p,if(length){72}else{71},left,1,if(length){0}else{lo},0));
    let usize first_close=built(ir::raw(ref mut p,70,1,0,0,0));
    if(!image_only){let usize close=built(ir::raw(ref mut p,70,0,0,0,0));}
    var usize i=0;while(i<arity){actuals[i]=if(prefix && i==0){fill}else if(image_only){192}else{160};i+=1;}
    let usize second=call(ref mut p,2,1,ref actuals[..arity]);if(image_only){let usize close=built(ir::raw(ref mut p,70,0,0,0,0));}
    let usize right=fresh(ref mut p,if(length){12}else{10});
    let usize read_right=built(ir::raw(ref mut p,if(length){72}else{71},right,2,if(length){0}else{lo},0));
    let usize second_close=built(ir::raw(ref mut p,70,2,0,0,0));
    if(!image_only){let usize ended=built(ir::slice_close(ref mut p,0,0));let usize dropped=built(ir::array_drop(ref mut p,0,0));}
    if(length){let usize total=built(ir::emit(ref mut p,2,left,right,0));
        let usize expected=built(ir::integer(ref mut p,if(projection==2){2}else if(projection==3){0}else{6},12,0));
        let usize same=built(ir::emit(ref mut p,11,total,expected,0));let usize branch=p.count;
        let usize jump=built(ir::raw(ref mut p,20,0,same,0,0));let usize answer=built(ir::literal(ref mut p,42,0));
        let usize done=built(ir::emit(ref mut p,8,answer,0,0));let usize bad=p.count;
        let usize zero=built(ir::literal(ref mut p,0,0));let usize failed=built(ir::emit(ref mut p,8,zero,0,0));let usize patched=built(ir::patch(ref mut p,branch,bad,0));
    }else{let usize a=built(ir::widen(ref mut p,left,1,0));let usize b=built(ir::widen(ref mut p,right,1,0));
        let usize total=built(ir::emit(ref mut p,2,a,b,0));let usize done=built(ir::emit(ref mut p,8,total,0,0));}end(ref mut p,0);
    var u8[128] parameters=[0;128];p.arities[1]=arity;i=0;
    if(prefix){let usize scalar=fresh(ref mut p,10);i=1;}
    let usize start=p.registers;var usize count=0;
    while(i<arity){let usize formal=fresh(ref mut p,0);parameters[formal]=3;count+=1;i+=1;}
    i=0;while(i<count){let usize param=built(ir::raw(ref mut p,77,3+i,start+i,3,0));i+=1;}
    var usize selected=3;
    if(projection==1){let usize alias=built(ir::raw(ref mut p,75,11,3,0,0));selected=11;}
    if(projection>=2 && projection!=4){let usize low=built(ir::integer(ref mut p,1,12,0));let usize high=built(ir::integer(ref mut p,if(projection==3){1}else{2},12,0));
        let usize range=built(ir::raw(ref mut p,76,11,3,low,0));p.code[range*8+4]=byte(high);selected=11;}
    if(projection==4){let usize literal=built(ir::raw(ref mut p,69,11,0,1,0));p.code[literal*8+6]=3;selected=11;}
    i=0;while(i<count){if(3+i!=selected){let usize closed=built(ir::raw(ref mut p,70,3+i,0,0,0));}i+=1;}
    var u8[16] results=[0;16];var u8[16] origins=[0;16];results[1]=3;origins[1]=if(projection==4){9}else if(prefix){2}else{1};
    if(forward){let usize[1] refs=[192+selected];let usize called=call(ref mut p,12,2,ref refs);
        let usize closed=built(ir::raw(ref mut p,70,selected,0,0,0));let usize returned=built(ir::raw(ref mut p,79,0,12,0,0));end(ref mut p,1);
        p.arities[2]=1;let usize formal=fresh(ref mut p,0);parameters[formal]=3;
        let usize param=built(ir::raw(ref mut p,77,13,formal,3,0));let usize ret=built(ir::raw(ref mut p,79,0,13,0,0));end(ref mut p,2);
        results[2]=3;origins[2]=1;
    }else{let usize returned=built(ir::raw(ref mut p,79,0,selected,0,0));end(ref mut p,1);}
    return calls::Program{.body=p,.parameters=parameters,.results=results,.origins=origins};
}
fn void swap(ref mut ir::Program p,usize a,usize b){var usize i=0;while(i<8){let u8 x=p.code[a*8+i];let u8 y=p.code[b*8+i];p.code[a*8+i]=y;p.code[b*8+i]=x;i+=1;}}
fn void insert(ref mut ir::Program p,usize at,u8 op,usize dst,usize a,usize b){
    let usize appended=built(ir::raw(p,op,dst,a,b,0));var u8[8] code=[0;8];var usize i=0;
    while(i<8){code[i]=p.code[appended*8+i];i+=1;}var usize pc=appended;
    while(pc>at){let usize offset=p.offsets[pc-1];p.offsets[pc]=offset;i=0;
        while(i<8){let u8 value=p.code[(pc-1)*8+i];p.code[pc*8+i]=value;i+=1;}pc-=1;}
    i=0;while(i<8){p.code[at*8+i]=code[i];i+=1;}p.offsets[at]=0;
    var usize f=0;while(f<p.function_count){if(p.starts[f]>=at){p.starts[f]+=1;}if(p.ends[f]>at){p.ends[f]+=1;}f+=1;}
}
fn void drained(ref runtime::State state){assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}}
fn Result<execution::Scalar,errors::Error> run(ref programs::ReferenceReturnProgram p,ref mut runtime::State state,ref mut u8[] data,usize fuel,usize entry){
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    return programs::run_reference_returns_scalar(p,entry,ref captures[..0],ref values[..0],ref inputs[..0],state,data,fuel);
}
// Independent numeric schedule along these fixtures' successful path. 0=image,
// 1=runtime formal, 2=returned runtime receipt; no production price helper used.
fn usize price(ref calls::Program unit,usize f,bool loan){let ref ir::Program p=ref unit.body;
    var u8[16] kinds=[0;16];var usize total=147456+p.arities[f]+if(f!=0 && loan && unit.origins[f]!=9){294912}else{196608};var usize pc=p.starts[f];
    while(pc<p.ends[f]){let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;total+=1;
        if(op==8){return total;}if(op==79){return total+512;}
        if(op==33){total+=61;}else if(op==37){total+=49;}else if(op==54){total+=65537;}else if(op==56){total+=4097;}
        else if(op==69){total+=16;}else if(op==70){if(kinds[dst]==2){total+=128;}}
        else if(op==77){kinds[dst]=if(loan){1}else{0};total+=16+if(loan){4097}else{0};}
        else if(op==75 || op==76){kinds[dst]=kinds[a];total+=if(op==75){16}else{127};if(kinds[a]==2){total+=64;}}
        else if(op==71 || op==72){total+=if(kinds[a]==0){if(op==71){17}else{16}}else{if(op==71){4131}else{4097}};
            if(kinds[a]==2){total+=64;}}
        else if(op==78){var usize refs=0;var usize loans=0;var usize returned=0;var usize i=0;
            while(i<p.arities[a]){let usize value=p.call_args[b*8+i] as usize;
                if(unit.parameters[p.register_starts[a]+i]!=0){refs+=1;
                    if((value>=160 && value<176) || (value>=192 && value<208 && kinds[value-192]!=0)){loans+=1;}
                    if(value>=192 && value<208 && kinds[value-192]==2){returned+=1;}}i+=1;
            }
            let usize origin=unit.origins[a] as usize;let usize value=if(origin==9){0}else{p.call_args[b*8+origin-1] as usize};
            let bool child=origin!=9 && ((value>=160 && value<176) || (value>=192 && value<208 && kinds[value-192]!=0));
            total+=32+32*refs+4097*loans+64*returned+price(unit,a,loans!=0);kinds[dst]=if(child){2}else{0};
        }else{assert(op<33);}pc+=1;
    }assert(false);return 0;
}
fn void trial(ref programs::ReferenceReturnProgram p,usize budget,i64 expected,usize left,u8 error,bool image_only){
    var runtime::State state=runtime::empty(if(image_only){0}else{4});var u8[4] data=[99;4];
    switch(run(p,ref mut state,ref mut data[..if(image_only){0}else{4}],budget,0)){
        case .ok(v):{assert(error==0 && v.value==expected && v.remaining==left);}case .err(e):{assert(error!=0 && e.kind==error);}
    };drained(ref state);
}
fn void example(ref calls::Program unit,i64 expected,bool image_only){let usize required=price(unit,0,false);
    let programs::ReferenceReturnProgram program=switch(programs::retain_reference_returns(unit,image(),579)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };trial(ref program,required-1,expected,0,8,image_only);trial(ref program,required,expected,0,0,image_only);trial(ref program,required+1,expected,1,0,image_only);
}
@test fn void the_same_returned_signature_reads_distinct_image_and_runtime_values_at_exact_fuel(){
    let calls::Program p=unit(1,false,0,false,false,false);example(ref p,106,false);
}
@test fn void narrowed_alias_and_forwarded_results_preserve_selected_input_and_actual_window(){
    let calls::Program a=unit(1,false,1,false,false,false);example(ref a,106,false);
    let calls::Program b=unit(1,false,2,true,false,false);example(ref b,77,false);
    let calls::Program c=unit(8,true,2,true,false,false);example(ref c,77,false);
    let calls::Program d=unit(8,false,0,false,false,false);example(ref d,106,false);
}
@test fn void empty_results_and_lengths_work_and_image_only_results_use_zero_guest_backing(){
    let calls::Program a=unit(1,false,3,true,true,false);example(ref a,42,false);
    let calls::Program b=unit(1,false,2,true,true,false);example(ref b,42,false);
    let calls::Program c=unit(1,false,0,false,false,true);example(ref c,128,true);
    let calls::Program d=unit(1,false,4,false,false,false);example(ref d,128,false);
}
@test fn void caller_alias_and_range_survive_parent_and_original_loan_close_until_last_alias(){
    var calls::Program p=unit(1,false,0,false,false,false);let usize start=find(ref p.body,78,1)+1;
    let usize opened=find(ref p.body,54,0);let usize lo=p.body.code[opened*8+2] as usize;let usize hi=p.body.code[opened*8+3] as usize;
    insert(ref mut p.body,start,75,14,2,0);insert(ref mut p.body,start+1,76,15,14,lo);p.body.code[(start+1)*8+4]=byte(hi);
    let usize read=find(ref p.body,71,1);p.body.code[read*8+2]=15;let usize close=find(ref p.body,70,2);swap(ref mut p.body,read,close);
    let usize source_close=find(ref p.body,56,0);swap(ref mut p.body,close,source_close);
    let usize drop=find(ref p.body,37,0);insert(ref mut p.body,drop,70,14,0,0);insert(ref mut p.body,drop+1,70,15,0,0);example(ref p,106,false);
}
@test fn void a_returned_result_can_feed_another_call_then_its_parent_can_close(){
    var calls::Program p=unit(1,false,0,false,false,false);let usize at=find(ref p.body,78,1)+1;
    let usize map=p.body.call_count;p.body.call_count+=1;p.body.call_arities[map]=1;p.body.call_args[map*8]=194;
    insert(ref mut p.body,at,78,14,1,map);let usize read=find(ref p.body,71,1);p.body.code[read*8+2]=14;
    let usize close=find(ref p.body,70,2);swap(ref mut p.body,read,close);
    let usize drop=find(ref p.body,37,0);insert(ref mut p.body,drop,70,14,0,0);example(ref p,106,false);
}
@test fn void bounds_and_fuel_failures_drain_every_returned_receipt_owner_and_frame(){
    var calls::Program code=unit(1,false,2,true,false,false);let usize read=find(ref code.body,71,1);let usize opened=find(ref code.body,54,0);
    let u8 index=code.body.code[opened*8+3];code.body.code[read*8+3]=index;let programs::ReferenceReturnProgram p=switch(programs::retain_reference_returns(ref code,image(),579)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };trial(ref p,10000000,0,0,14,false);trial(ref p,1,0,0,8,false);
}
@test fn void retained_return_code_is_immutable_and_host_generic_entry_and_old_admission_stay_closed(){
    var calls::Program code=unit(1,false,0,false,false,false);let usize required=price(ref code,0,false);
    let programs::ReferenceReturnProgram p=switch(programs::retain_reference_returns(ref code,image(),579)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };code.body.code[0]=0;trial(ref p,required,106,0,0,false);
    var runtime::State state=runtime::empty(4);var u8[4] data=[0;4];assert(!run(ref p,ref mut state,ref mut data,10000000,1).is_ok);drained(ref state);
    let calls::Program good=unit(1,false,0,false,false,false);let images::Image payload=image();
    assert(!verifier::inspect_reference_calls(ref good,ref payload).is_ok && !verifier::verify_static_calls(ref good,ref payload).is_ok);
    switch(programs::retain_reference_returns(ref good,image(),578)){case .ok(_):{assert(false);}case .err(_):{}};
}
@test fn void complete_return_fuel_is_checked_before_invalid_native_formal_authentication(){
    let calls::Program unit=unit(1,false,0,false,false,false);let images::Image image=image();
    let verifier::ReferenceReturnProof proof=switch(verifier::inspect_reference_returns(ref unit,ref image)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var runtime::State state=runtime::empty(4);var u8[4] data=[0;4];
    let layouts::Array shape=switch(layouts::scalar(10,3)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let owners::Token root=switch(owners::create(ref shape,42,ref mut data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket parent=switch(slices::open(ref mut pool,ref mut table,root,0,3,4)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    state.runtime.pool=pool;state.runtime.owners=table;
    let runtime::Capture[1] none=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let runtime::Contract ordinary=runtime::Contract{.tags=[0;8],.arity=0,.selected=0};
    let runtime::Call outer=switch(runtime::enter_call(ref mut state,ordinary,ref none[..0],4,147456)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var frames::Frames stack=frames::empty(ref state);let usize first=built(frames::push(ref unit.body,ref mut stack,outer,0,128,32,0));
    var runtime::Contract contract=runtime::Contract{.tags=[0;8],.arity=1,.selected=1};contract.tags[0]=10;
    let runtime::Capture[1] captures=[runtime::capture(parent,false,false)];
    let runtime::Call child=switch(runtime::enter(ref mut state,contract,ref captures,4,147456)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize call=find(ref unit.body,78,1);let usize map=unit.body.code[call*8+3] as usize;
    let usize second=built(frames::push(ref unit.body,ref mut stack,child,1,2,map,call+1));
    var u32[16] current=[0;16];current[3]=switch(words::pack(0,statics_span(),0)){case .ok(v):{v}case .err(_):{assert(false);0}};
    stack.issued[16]=slices::Ticket{.slot=16,.generation=1};let usize ret=find(ref unit.body,79,0);
    switch(transfers::prepare(ref unit.body,ref proof.statics,ret,1,ref current,8,0,ref stack,ref state,3,295423)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}
    };
    switch(transfers::prepare(ref unit.body,ref proof.statics,ret,1,ref current,8,0,ref stack,ref state,3,295424)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}
    };assert(runtime::abort(ref mut state,4,0).is_ok);drained(ref state);
}
fn views::Span statics_span(){return views::Span{.start=0,.length=3};}
