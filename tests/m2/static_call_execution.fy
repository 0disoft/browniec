module tests::m2::static_call_execution;
import ir as ir;
import static_call_ir as calls;
import static_image as images;
import static_call_execution as execution;
import static_ir as statics;
import verifier as verifier;
import errors as errors;
import std::num as num;

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
    error(execution::arguments(ref p.body,ref sites,2,pc,0,ref words,3,31),8);
    let execution::Arguments plan=switch(execution::arguments(ref p.body,ref sites,2,pc,0,ref words,3,32)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Arguments{.words=[0;16],.remaining=99}}
    };assert(plan.remaining==0 && plan.words[3]==8193 && plan.words[0]==0 && words[1]==8193);
    error(execution::arguments(ref p.body,ref sites,2,pc,0,ref words,1,32),5);
    words[1]=24576;error(execution::arguments(ref p.body,ref sites,2,pc,0,ref words,3,32),5);
}
@test fn void parameter_activation_and_static_return_check_exact_recipient_before_publication(){
    let calls::Program p=fixture(1,1,false);let images::Image data=image(1);let statics::Sites sites=proof(ref p,ref data);
    let usize param=find(ref p.body,77);let usize ret=find(ref p.body,79);let usize call=find(ref p.body,78);
    var u32[16] words=[0;16];words[3]=8193;
    assert(built(execution::parameter(ref p.body,ref sites,2,param,1,ref words,0,16))==0);
    switch(execution::parameter(ref p.body,ref sites,2,param,1,ref words,0,15)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(execution::parameter(ref p.body,ref sites,2,param,1,ref words,8,16)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
    let execution::Returned result=switch(execution::returned(ref p.body,ref sites,2,ret,1,ref words,8,call,0,2,3,16)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Returned{.word=0,.destination=0,.remaining=99}}
    };assert(result.word==8193 && result.destination==2 && result.remaining==0);
    switch(execution::returned(ref p.body,ref sites,2,ret,1,ref words,8,call,0,2,3,15)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(execution::returned(ref p.body,ref sites,2,ret,1,ref words,8,call,0,0,3,16)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
    switch(execution::returned(ref p.body,ref sites,2,ret,1,ref words,8,call,0,2,7,16)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
    assert(words[3]==8193);
}
@test fn void text_arguments_require_the_complete_validated_window(){
    let calls::Program p=fixture(2,1,false);let images::Image data=image(2);let statics::Sites sites=proof(ref p,ref data);
    var u32[16] words=[0;16];words[1]=2;let usize pc=find(ref p.body,78);
    let execution::Arguments plan=switch(execution::arguments(ref p.body,ref sites,2,pc,0,ref words,2,32)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Arguments{.words=[0;16],.remaining=99}}
    };assert(plan.words[3]==2);words[1]=8193;error(execution::arguments(ref p.body,ref sites,2,pc,0,ref words,2,32),5);
}
@test fn void mixed_logical_positions_and_all_eight_descriptors_have_exact_additive_prices(){
    let calls::Program p=fixture(1,1,true);let images::Image data=image(1);let statics::Sites sites=proof(ref p,ref data);
    var u32[16] words=[0;16];words[1]=8193;
    let execution::Arguments mixed=switch(execution::arguments(ref p.body,ref sites,2,find(ref p.body,78),0,ref words,2,32)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Arguments{.words=[0;16],.remaining=99}}
    };assert(mixed.words[3]==8193 && mixed.remaining==0);
    let calls::Program eight=fixture(1,8,false);let statics::Sites many=proof(ref eight,ref data);let usize pc=find(ref eight.body,78);
    error(execution::arguments(ref eight.body,ref many,2,pc,0,ref words,2,143),8);
    let execution::Arguments all=switch(execution::arguments(ref eight.body,ref many,2,pc,0,ref words,2,144)){
        case .ok(v):{v}case .err(_):{assert(false);execution::Arguments{.words=[0;16],.remaining=99}}
    };assert(all.remaining==0);var usize i=3;while(i<11){assert(all.words[i]==8193);i+=1;}
}
