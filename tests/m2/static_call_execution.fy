module tests::m2::static_call_execution;
import ir as ir;
import static_call_ir as calls;
import static_image as images;
import static_call_execution as execution;
import static_ir as statics;
import verifier as verifier;
import errors as errors;
import std::num as num;
import program_image as programs;
import slice_result_runtime as runtime;
import slice_result_execution as driver;
import array_owners as owners;
import array_slices as array_slices;
import slice_result_ir as legacy;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 byte(usize n){return switch(num::u8_from_i64(switch(num::i64_from_usize(n)){case .ok(v):{v}case .err(_):{assert(false);0}})){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize fresh(ref mut ir::Program p,u8 kind){let usize r=p.registers;p.types[r]=kind;p.registers+=1;return r;}
fn void close(ref mut ir::Program p,usize s){let usize pc=built(ir::raw(p,70,s,0,0,0));}
fn images::Image image(u8 kind){
    var images::Builder b=switch(images::builder(2)){case .ok(v):{v}case .err(_):{assert(false);return image(kind);}};
    let usize id=switch(if(kind==1){images::intern_bytes(ref mut b,b"x*")}else{images::intern_text(ref mut b,b"x*")}){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(images::freeze(ref b,8192)){case .ok(v):{v}case .err(_):{assert(false);image(kind)}};
}
// Real image/recipe/canonical proof: bytes are narrowed to the final byte;
// validated text retains the exact two-byte window. Logical scalar prefixes and
// eight duplicate shared actuals do not change which PARAM sites receive words.
fn calls::Program fixture(u8 kind,usize count,bool prefix){
    assert(count>0 && count<=8 && (!prefix || count==1));
    var ir::Program p=ir::empty();p.function_count=2;p.return_types[0]=1;p.return_types[1]=0;
    let usize opened=built(ir::raw(ref mut p,69,0,0,kind as usize,0));p.code[opened*8+6]=2;
    let usize lo=built(ir::integer(ref mut p,1,12,0));let usize hi=built(ir::integer(ref mut p,2,12,0));
    if(kind==1){let usize range=built(ir::raw(ref mut p,76,1,0,lo,0));p.code[range*8+4]=byte(hi);}
    else{let usize alias=built(ir::raw(ref mut p,75,1,0,0,0));}
    p.call_count=1;p.call_arities[0]=byte(count+if(prefix){1}else{0});
    var usize i=0;while(i<count){p.call_args[i+if(prefix){1}else{0}]=193;i+=1;}
    let usize call=built(ir::raw(ref mut p,78,2,1,0,0));close(ref mut p,0);close(ref mut p,1);
    var usize selected=2;if(kind==2){let usize bytes=built(ir::raw(ref mut p,74,11,2,0,0));close(ref mut p,2);selected=11;}
    let usize index=built(ir::integer(ref mut p,if(kind==1){0}else{1},12,0));let usize value=fresh(ref mut p,10);
    let usize read=built(ir::raw(ref mut p,71,value,selected,index,0));close(ref mut p,selected);
    let usize wide=built(ir::widen(ref mut p,value,1,0));let usize done=built(ir::emit(ref mut p,8,wide,0,0));
    let usize middle=p.count;let usize locals=p.registers;
    p.ends[0]=middle;p.register_ends[0]=locals;p.starts[1]=middle;p.register_starts[1]=locals;
    var u8[128] parameters=[0;128];p.arities[1]=count+if(prefix){1}else{0};
    if(prefix){let usize scalar=fresh(ref mut p,12);}
    var usize[8] formals=[0;8];i=0;while(i<count){let usize formal=fresh(ref mut p,0);formals[i]=formal;parameters[formal]=kind;i+=1;}
    i=0;while(i<count){let usize param=built(ir::raw(ref mut p,77,3+i,formals[i],kind as usize,0));i+=1;}
    i=1;while(i<count){close(ref mut p,3+i);i+=1;}
    let usize ret=built(ir::raw(ref mut p,79,0,3,0,0));let usize last=p.count;let usize registers=p.registers;
    p.ends[1]=last;p.register_ends[1]=registers;
    var u8[16] results=[0;16];var u8[16] origins=[0;16];results[1]=kind;origins[1]=if(prefix){2}else{1};
    return calls::Program{.body=p,.parameters=parameters,.results=results,.origins=origins};
}
fn statics::Sites proof(ref calls::Program p,ref images::Image data){return switch(verifier::verify_static_calls(p,data)){
    case .ok(v):{v.statics}case .err(_):{assert(false);statics::empty()}
};}
fn usize find(ref ir::Program p,u8 op){var usize pc=0;while(pc<p.count){if(p.code[pc*8]==op){return pc;}pc+=1;}assert(false);return 0;}
fn void error(Result<execution::Arguments,errors::Error> r,u8 kind){switch(r){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}};}
@test fn void actual_byte_ranges_transfer_without_broadening_and_preflight_complete_call_price(){
    let calls::Program p=fixture(1,1,false);let images::Image data=image(1);let statics::Sites sites=proof(ref p,ref data);
    var u32[16] words=[0;16];words[0]=2;words[1]=8193;let usize pc=find(ref p.body,78);
    error(execution::arguments(ref p.body,ref sites,2,pc,0,ref words,3,63),8);
    let execution::Arguments plan=switch(execution::arguments(ref p.body,ref sites,2,pc,0,ref words,3,64)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Arguments{.words=[0;16],.remaining=99}}
    };assert(plan.remaining==0 && plan.words[3]==8193 && plan.words[0]==0 && words[1]==8193);
    error(execution::arguments(ref p.body,ref sites,2,pc,0,ref words,1,64),5);
    words[1]=24576;error(execution::arguments(ref p.body,ref sites,2,pc,0,ref words,3,64),5);
}
@test fn void parameter_activation_and_static_return_check_exact_recipient_before_publication(){
    let calls::Program p=fixture(1,1,false);let images::Image data=image(1);let statics::Sites sites=proof(ref p,ref data);
    let usize param=find(ref p.body,77);let usize ret=find(ref p.body,79);let usize call=find(ref p.body,78);
    var u32[16] words=[0;16];words[3]=8193;
    assert(built(execution::parameter(ref p.body,ref sites,2,param,1,ref words,0,16))==0);
    switch(execution::parameter(ref p.body,ref sites,2,param,1,ref words,0,15)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(execution::parameter(ref p.body,ref sites,2,param,1,ref words,8,16)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
    let execution::Returned result=switch(execution::returned(ref p.body,ref sites,2,ret,1,ref words,8,call,0,2,3,48)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Returned{.word=0,.destination=0,.remaining=99}}
    };assert(result.word==8193 && result.destination==2 && result.remaining==0);
    switch(execution::returned(ref p.body,ref sites,2,ret,1,ref words,8,call,0,2,3,47)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(execution::returned(ref p.body,ref sites,2,ret,1,ref words,8,call,0,0,3,48)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
    switch(execution::returned(ref p.body,ref sites,2,ret,1,ref words,8,call,0,2,7,48)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
    assert(words[3]==8193);
}
@test fn void text_arguments_require_the_complete_validated_window(){
    let calls::Program p=fixture(2,1,false);let images::Image data=image(2);let statics::Sites sites=proof(ref p,ref data);
    var u32[16] words=[0;16];words[1]=2;let usize pc=find(ref p.body,78);
    let execution::Arguments plan=switch(execution::arguments(ref p.body,ref sites,2,pc,0,ref words,2,64)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Arguments{.words=[0;16],.remaining=99}}
    };assert(plan.words[3]==2);words[1]=8193;error(execution::arguments(ref p.body,ref sites,2,pc,0,ref words,2,64),5);
}
@test fn void mixed_logical_positions_and_all_eight_descriptors_have_exact_additive_prices(){
    let calls::Program p=fixture(1,1,true);let images::Image data=image(1);let statics::Sites sites=proof(ref p,ref data);
    var u32[16] words=[0;16];words[1]=8193;
    let execution::Arguments mixed=switch(execution::arguments(ref p.body,ref sites,2,find(ref p.body,78),0,ref words,2,64)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Arguments{.words=[0;16],.remaining=99}}
    };assert(mixed.words[3]==8193 && mixed.remaining==0);
    let calls::Program eight=fixture(1,8,false);let statics::Sites many=proof(ref eight,ref data);let usize pc=find(ref eight.body,78);
    error(execution::arguments(ref eight.body,ref many,2,pc,0,ref words,2,287),8);
    let execution::Arguments all=switch(execution::arguments(ref eight.body,ref many,2,pc,0,ref words,2,288)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Arguments{.words=[0;16],.remaining=99}}
    };assert(all.remaining==0);var usize i=3;while(i<11){assert(all.words[i]==8193);i+=1;}
}

fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
fn Result<driver::Scalar,errors::Error> run(ref programs::CallProgram p,ref mut runtime::State state,ref mut u8[] data,usize fuel){
    let runtime::Capture[1] captures=[runtime::capture(slices_none(),false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    return programs::run_call_scalar(p,0,ref captures[..0],ref values[..0],ref inputs[..0],state,data,fuel);
}
fn array_slices::Ticket slices_none(){return array_slices::Ticket{.slot=16,.generation=0};}
fn programs::CallProgram retained(ref calls::Program p,u8 kind){
    return switch(programs::retain_calls(p,image(kind),578)){
        case .ok(v):{v}case .err(_):{assert(false);return retained(p,kind);}
    };
}
fn void exact(ref calls::Program p,u8 kind,usize price){
    let programs::CallProgram program=retained(p,kind);
    var runtime::State state=runtime::empty(0);var u8[1] data=[99];
    switch(run(ref program,ref mut state,ref mut data[..0],price-1)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};drained(ref state);
    let driver::Scalar result=switch(run(ref program,ref mut state,ref mut data[..0],price)){
        case .ok(v):{v}case .err(_):{assert(false);driver::Scalar{.value=0,.remaining=99,.resumed=[slices_none();8]}}
    };assert(result.value==42 && result.remaining==0);drained(ref state);
    let driver::Scalar more=switch(run(ref program,ref mut state,ref mut data[..0],price+1)){
        case .ok(v):{v}case .err(_):{assert(false);driver::Scalar{.value=0,.remaining=99,.resumed=[slices_none();8]}}
    };assert(more.value==42 && more.remaining==1 && data[0]==99);drained(ref state);
}
@test fn void retained_calls_execute_narrowed_bytes_and_exact_text_at_exact_fuel(){
    // Independent numeric oracles: two native enters/leaves = 688128.
    // Bytes execute 303 additional units; text executes 210. Neither allocates
    // guest backing, and repeating a retained Program must preserve its image.
    let calls::Program bytes=fixture(1,1,false);exact(ref bytes,1,688431);
    let calls::Program text=fixture(2,1,false);exact(ref text,2,688338);
    var calls::Program literal=fixture(1,1,false);let usize param=find(ref literal.body,77);
    literal.body.registers=5;literal.body.register_ends[1]=5;literal.body.arities[1]=0;
    literal.body.call_arities[0]=0;literal.body.call_args[0]=0;literal.parameters[5]=0;literal.origins[1]=9;
    literal.body.code[param*8]=69;literal.body.code[param*8+2]=0;
    literal.body.code[param*8+4]=1;literal.body.code[param*8+6]=2;
    exact(ref literal,1,688398);
    var calls::Program empty=fixture(1,1,false);
    let usize lo=empty.body.code[1*8+2] as usize;let usize hi=empty.body.code[2*8+2] as usize;
    empty.body.constants[lo]=0;empty.body.constants[hi]=0;
    let programs::CallProgram zero=retained(ref empty,1);var runtime::State state=runtime::empty(0);var u8[1] data=[99];
    // Packed zero is a valid empty view, not a missing argument. Transfer must
    // succeed and reach the caller's actual out-of-bounds READ.
    switch(run(ref zero,ref mut state,ref mut data[..0],10000000)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==14);}
    };drained(ref state);assert(data[0]==99);
}

@test fn void short_entry_call_and_return_budgets_abort_and_retained_code_cannot_be_rewritten(){
    var calls::Program p=fixture(1,1,false);let programs::CallProgram program=retained(ref p,1);
    var runtime::State state=runtime::empty(0);var u8[1] data=[99];
    // One short at initial admission, complete CALL publication and Static RETURN.
    let usize[3] budgets=[147455,295124,491798];var usize i=0;
    while(i<3){switch(run(ref program,ref mut state,ref mut data[..0],budgets[i])){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}
    };drained(ref state);i+=1;}
    p.body.call_args[0]=0;let images::Image other=image(1);
    let runtime::Capture[1] captures=[runtime::capture(slices_none(),false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    switch(driver::execute_static_scalar(ref p,ref other,0,ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data[..0],0)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}
    };drained(ref state);
    let driver::Scalar result=switch(run(ref program,ref mut state,ref mut data[..0],688431)){
        case .ok(v):{v}case .err(_):{assert(false);driver::Scalar{.value=0,.remaining=99,.resumed=[slices_none();8]}}
    };assert(result.value==42 && result.remaining==0 && data[0]==99);drained(ref state);
    let calls::Program clean=fixture(1,1,false);
    let legacy::Program bare=legacy::Program{.body=clean.body,.elements=[0;16],.parameters=[0;16]};
    switch(programs::retain(ref bare,image(1),8192)){case .ok(_):{assert(false);}case .err(e):{assert(e.code.kind==5);}};
}
fn calls::Program recursive(){
    var ir::Program p=ir::empty();p.function_count=2;p.return_types[0]=1;p.return_types[1]=0;
    let usize opened=built(ir::raw(ref mut p,69,0,0,1,0));p.code[opened*8+6]=2;
    let usize flag=built(ir::boolean(ref mut p,true,0));p.call_count=2;p.call_arities[0]=2;p.call_args[0]=192;p.call_args[1]=byte(flag);
    let usize call=built(ir::raw(ref mut p,78,1,1,0,0));close(ref mut p,0);
    let usize index=built(ir::integer(ref mut p,0,12,0));let usize value=fresh(ref mut p,10);
    let usize read=built(ir::raw(ref mut p,71,value,1,index,0));close(ref mut p,1);
    let usize wide=built(ir::widen(ref mut p,value,1,0));let usize done=built(ir::emit(ref mut p,8,wide,0,0));
    let usize middle=p.count;let usize locals=p.registers;p.ends[0]=middle;p.starts[1]=middle;p.register_ends[0]=locals;p.register_starts[1]=locals;
    let usize formal=fresh(ref mut p,0);let usize condition=fresh(ref mut p,2);p.arities[1]=2;
    let usize param=built(ir::raw(ref mut p,77,2,formal,1,0));let usize branch=built(ir::raw(ref mut p,20,0,condition,0,0));
    let usize lo=built(ir::integer(ref mut p,1,12,0));let usize hi=built(ir::integer(ref mut p,2,12,0));
    let usize range=built(ir::raw(ref mut p,76,3,2,lo,0));p.code[range*8+4]=byte(hi);
    let usize stop=built(ir::boolean(ref mut p,false,0));p.call_arities[1]=2;p.call_args[8]=195;p.call_args[9]=byte(stop);
    let usize nested=built(ir::raw(ref mut p,78,4,1,1,0));close(ref mut p,2);close(ref mut p,3);
    let usize nested_return=built(ir::raw(ref mut p,79,0,4,0,0));let usize base=p.count;
    let usize patched=built(ir::patch(ref mut p,branch,base,0));let usize ret=built(ir::raw(ref mut p,79,0,2,0,0));
    let usize last=p.count;let usize registers=p.registers;p.ends[1]=last;p.register_ends[1]=registers;
    var u8[128] parameters=[0;128];parameters[formal]=1;var u8[16] results=[0;16];var u8[16] origins=[0;16];results[1]=1;origins[1]=1;
    return calls::Program{.body=p,.parameters=parameters,.results=results,.origins=origins};
}
@test fn void all_eight_actuals_scalar_prefixes_and_recursive_actual_words_use_separate_frames(){
    let calls::Program eight=fixture(1,8,false);exact(ref eight,1,688788);
    let calls::Program mixed=fixture(1,1,true);exact(ref mixed,1,688432);
    let calls::Program nested=recursive();let programs::CallProgram program=retained(ref nested,1);
    var runtime::State state=runtime::empty(0);var u8[1] data=[99];
    let driver::Scalar result=switch(run(ref program,ref mut state,ref mut data[..0],10000000)){
        case .ok(v):{v}case .err(_):{assert(false);driver::Scalar{.value=0,.remaining=99,.resumed=[slices_none();8]}}
    };assert(result.value==42 && data[0]==99);drained(ref state);
    var calls::Program limit=recursive();let usize range=find(ref limit.body,76);
    limit.body.code[range*8]=75;limit.body.code[range*8+3]=0;limit.body.code[range*8+4]=0;
    let usize flag=limit.body.call_args[9] as usize;var usize pc=limit.body.starts[1];
    while(pc<limit.body.ends[1]){if(limit.body.code[pc*8]==1 && limit.body.code[pc*8+1] as usize==flag){
        let usize constant=limit.body.code[pc*8+2] as usize;limit.body.constants[constant]=1;
    }pc+=1;}
    let programs::CallProgram capped=retained(ref limit,1);
    switch(run(ref capped,ref mut state,ref mut data[..0],10000000)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==12);}
    };drained(ref state);
}
// This straight-line fixture has no jumps. Insert an instruction while keeping
// both exact function partitions and all eight-byte instructions intact.
fn void insert(ref mut ir::Program p,usize at,u8 op,usize dst,usize a){
    let usize added=built(ir::raw(p,op,dst,a,0,0));var u8[8] code=[0;8];var usize i=0;
    while(i<8){code[i]=p.code[added*8+i];i+=1;}
    var usize pc=added;while(pc>at){i=0;while(i<8){let u8 current=p.code[(pc-1)*8+i];p.code[pc*8+i]=current;i+=1;}pc-=1;}
    i=0;while(i<8){p.code[at*8+i]=code[i];i+=1;}
    var usize f=0;while(f<p.function_count){if(p.starts[f]>=at){p.starts[f]+=1;}if(p.ends[f]>at){p.ends[f]+=1;}f+=1;}
}
fn calls::Program owned_argument(){
    var calls::Program p=fixture(1,1,false);
    let usize caller=built(ir::array_in(ref mut p.body,0,12,1,false,0));let usize callee=built(ir::array_in(ref mut p.body,1,12,1,false,0));
    assert(caller==0 && callee==1);let usize formal=fresh(ref mut p.body,12);let usize registers=p.body.registers;
    p.body.register_ends[1]=registers;p.body.arities[1]=2;p.body.array_parameters[formal]=2;
    p.body.call_arities[0]=2;p.body.call_args[1]=128;
    let usize call=find(ref p.body,78);insert(ref mut p.body,call,33,0,0);insert(ref mut p.body,call+2,37,0,0);
    let usize ret=find(ref p.body,79);insert(ref mut p.body,ret,37,1,0);return p;
}
@test fn void static_calls_copy_and_drop_owned_array_arguments_through_canonical_ownership(){
    let calls::Program p=owned_argument();let programs::CallProgram program=retained(ref p,1);
    var runtime::State state=runtime::empty(16);var u8[16] data=[99;16];
    let driver::Scalar result=switch(run(ref program,ref mut state,ref mut data,10000000)){
        case .ok(v):{v}case .err(_):{assert(false);driver::Scalar{.value=0,.remaining=99,.resumed=[slices_none();8]}}
    };assert(result.value==42);drained(ref state);
    switch(run(ref program,ref mut state,ref mut data,148000)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    assert(data[0]==1);drained(ref state);
}
