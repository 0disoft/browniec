module tests::m2::static_call_ir;
import static_call_ir as calls;
import ir as ir;
import static_image as images;
import errors as errors;
import std::num as num;
import verifier as verifier;
import vm as vm;
import program_image as programs;
import slice_result_ir as borrowed;
fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize fresh(ref mut ir::Program p,u8 kind){let usize r=p.registers;p.types[r]=kind;p.registers+=1;return r;}
fn void end(ref mut ir::Program p,usize f){let usize pc=p.count;let usize r=p.registers;p.ends[f]=pc;p.register_ends[f]=r;
    if(f+1<p.function_count){p.starts[f+1]=pc;p.register_starts[f+1]=r;}}
fn usize open(ref mut ir::Program p,usize dst,u8 kind){let usize pc=built(ir::raw(p,69,dst,if(kind==1){0}else{1},kind as usize,0));p.code[pc*8+6]=1;return pc;}
fn void close(ref mut ir::Program p,usize site){let usize pc=built(ir::raw(p,70,site,0,0,0));}
fn void returned(ref mut ir::Program p,usize site){let usize pc=built(ir::raw(p,79,0,site,0,0));}
fn void answer(ref mut ir::Program p,usize site,u8 kind){
    var usize bytes=site;if(kind==2){let usize pc=built(ir::raw(p,74,4,site,0,0));close(p,site);bytes=4;}
    let usize index=built(ir::integer(p,0,12,0));let usize byte=fresh(p,10);let usize read=built(ir::raw(p,71,byte,bytes,index,0));
    close(p,bytes);let usize value=built(ir::widen(p,byte,1,0));let usize pc=built(ir::emit(p,8,value,0,0));
}
fn images::Image image(){
    var images::Builder b=switch(images::builder(2)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    let usize raw=switch(images::intern_bytes(ref mut b,b"*")){case .ok(v):{v}case .err(_):{assert(false);0}};
    let usize text=switch(images::intern_text(ref mut b,b"*")){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(images::freeze(ref b,8192)){case .ok(v):{v}case .err(_):{assert(false);image()}};
}
fn calls::Proof accepted(ref calls::Program p){let images::Image data=image();return switch(calls::inspect(p,ref data)){
    case .ok(v):{v}case .err(_):{assert(false);calls::Proof{.definitions=[256;16],.functions=[16;16],.kinds=[0;16],
        .formal_sites=[0;128],.site_origins=[0;16],.result_origins=[0;16],.sites=0,.calls=0,.returns=0,.rounds=0}}
};}
fn void rejected(ref calls::Program p){let images::Image data=image();switch(calls::inspect(p,ref data)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}
};}
fn usize find(ref ir::Program p,u8 op,usize nth){var usize pc=0;var usize n=0;while(pc<p.count){
    if(p.code[pc*8]==op){if(n==nth){return pc;}n+=1;}pc+=1;}assert(false);return 0;}
// Modes: direct bytes/text, alias, range, or text->bytes. All origins still
// identify the exact logical input position, regardless of storage projections.
fn calls::Program parameter(u8 kind,u8 mode,bool scalar_prefix){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=0;p.return_types[0]=1;p.return_types[1]=0;
    var u8[128] parameters=[0;128];var u8[16] results=[0;16];var u8[16] origins=[0;16];
    results[1]=if(mode==3){1}else{kind};origins[1]=if(scalar_prefix){2}else{1};
    let usize root=open(ref mut p,0,kind);p.call_count=1;p.call_arities[0]=if(scalar_prefix){2}else{1};
    if(scalar_prefix){let usize scalar=built(ir::literal(ref mut p,42,0));p.call_args[0]=0;p.call_args[1]=192;}
    else{p.call_args[0]=192;}
    let usize call=built(ir::raw(ref mut p,78,1,1,0,0));close(ref mut p,0);answer(ref mut p,1,results[1]);end(ref mut p,0);
    if(scalar_prefix){let usize scalar=fresh(ref mut p,1);}
    let usize formal=fresh(ref mut p,0);parameters[formal]=kind;p.arities[1]=if(scalar_prefix){2}else{1};
    let usize param=built(ir::raw(ref mut p,77,2,formal,kind as usize,0));var usize selected=2;
    if(mode==1){let usize alias=built(ir::raw(ref mut p,75,3,2,0,0));selected=3;}
    if(mode==2){let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
        let usize range=built(ir::raw(ref mut p,76,3,2,lo,0));p.code[range*8+4]=switch(num::u8_from_i64(switch(num::i64_from_usize(hi)){case .ok(v):{v}case .err(_):{assert(false);0}})){case .ok(v):{v}case .err(_):{assert(false);0}};selected=3;}
    if(mode==3){let usize bytes=built(ir::raw(ref mut p,74,3,2,0,0));selected=3;}
    if(selected!=2){close(ref mut p,2);}returned(ref mut p,selected);end(ref mut p,1);
    return calls::Program{.body=p,.parameters=parameters,.results=results,.origins=origins};
}
fn calls::Program literal(bool recursive,bool grounded){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=0;p.return_types[0]=1;p.return_types[1]=0;
    let usize condition=built(ir::boolean(ref mut p,false,0));p.call_count=if(recursive){2}else{1};p.call_arities[0]=if(recursive && grounded){1}else{0};
    if(recursive && grounded){p.call_args[0]=0;}
    let usize call=built(ir::raw(ref mut p,78,0,1,0,0));answer(ref mut p,0,1);end(ref mut p,0);
    var usize branch=0;var usize formal=0;
    if(recursive && grounded){formal=fresh(ref mut p,2);p.arities[1]=1;branch=built(ir::raw(ref mut p,20,0,formal,0,0));}
    if(recursive){p.call_arities[1]=if(grounded){1}else{0};if(grounded){p.call_args[8]=switch(num::u8_from_i64(switch(num::i64_from_usize(formal)){case .ok(v):{v}case .err(_):{assert(false);0}})){case .ok(v):{v}case .err(_):{assert(false);0}};}
        let usize self=built(ir::raw(ref mut p,78,2,1,1,0));returned(ref mut p,2);}
    if(!recursive || grounded){let usize base=p.count;let usize root=open(ref mut p,1,1);returned(ref mut p,1);
        if(recursive){let usize patched=built(ir::patch(ref mut p,branch,base,0));}}
    end(ref mut p,1);var u8[16] results=[0;16];var u8[16] origins=[0;16];results[1]=1;origins[1]=9;
    return calls::Program{.body=p,.parameters=[0;128],.results=results,.origins=origins};
}
@test fn void parameter_alias_range_and_conversion_preserve_the_exact_input_origin(){
    let calls::Program direct=parameter(1,0,false);let calls::Proof a=accepted(ref direct);assert(a.calls==1 && a.returns==1 && a.result_origins[1]==1 && a.site_origins[1]==9);
    let calls::Program alias=parameter(1,1,false);let calls::Proof b=accepted(ref alias);assert(b.site_origins[3]==1);
    let calls::Program range=parameter(1,2,false);let calls::Proof c=accepted(ref range);assert(c.site_origins[3]==1);
    let calls::Program text=parameter(2,0,false);let calls::Proof d=accepted(ref text);assert(d.kinds[1]==2);
    let calls::Program bytes=parameter(2,3,false);let calls::Proof e=accepted(ref bytes);assert(e.site_origins[3]==1 && e.kinds[3]==1);
}
@test fn void logical_input_position_is_not_the_static_parameter_ordinal(){
    let calls::Program p=parameter(1,0,true);let calls::Proof proof=accepted(ref p);assert(proof.result_origins[1]==2 && proof.site_origins[2]==2 && proof.site_origins[1]==9);
}
@test fn void literal_results_and_recursive_literal_results_require_real_grounding(){
    let calls::Program direct=literal(false,true);let calls::Proof a=accepted(ref direct);assert(a.result_origins[1]==9 && a.site_origins[0]==9);
    let calls::Program recursive=literal(true,true);let calls::Proof b=accepted(ref recursive);assert(b.result_origins[1]==9 && b.site_origins[2]==9 && b.rounds>=2);
    let calls::Program ungrounded=literal(true,false);rejected(ref ungrounded);
}
@test fn void claimed_static_or_other_parameter_origins_cannot_replace_real_definitions(){
    var calls::Program p=parameter(1,0,false);p.origins[1]=9;rejected(ref p);
    p=parameter(1,0,true);p.origins[1]=1;rejected(ref p);
    p=literal(false,true);p.origins[1]=1;rejected(ref p);
    p=parameter(1,0,false);p.origins[1]=0;rejected(ref p);
}
@test fn void scalar_foreign_closed_and_wrong_kind_actuals_are_rejected(){
    var calls::Program p=parameter(1,0,false);p.body.call_args[0]=0;rejected(ref p);
    p=parameter(1,0,false);p.body.call_args[0]=194;rejected(ref p);
    p=parameter(1,0,false);let usize call=find(ref p.body,78,0);let usize close=find(ref p.body,70,0);
    var usize i=0;while(i<8){let u8 a=p.body.code[call*8+i];let u8 b=p.body.code[close*8+i];p.body.code[call*8+i]=b;p.body.code[close*8+i]=a;i+=1;}rejected(ref p);
    p=parameter(1,0,false);p.body.code[3]=2;p.body.code[2]=1;rejected(ref p);
}
@test fn void signature_sites_preludes_and_reserved_bytes_are_independently_rebuilt(){
    var calls::Program p=parameter(1,0,false);let usize param=find(ref p.body,77,0);p.body.code[param*8+1]=0;rejected(ref p);
    p=parameter(1,0,false);p.body.code[param*8+3]=2;rejected(ref p);
    p=parameter(1,0,false);p.body.code[param*8+4]=1;rejected(ref p);
    p=parameter(1,0,false);p.body.code[param*8+1]=16;rejected(ref p);
    p=parameter(1,0,false);p.parameters[127]=1;rejected(ref p);
    p=parameter(1,0,false);let usize formal=p.body.register_starts[1];p.body.slots[formal]=true;rejected(ref p);
}
@test fn void returning_a_child_requires_closing_every_other_live_static_site(){
    var calls::Program p=parameter(1,1,false);let usize close=find(ref p.body,70,2);p.body.code[close*8]=75;p.body.code[close*8+1]=5;p.body.code[close*8+2]=2;rejected(ref p);
    p=parameter(1,0,false);let usize ret=find(ref p.body,79,0);p.body.code[ret*8+2]=0;rejected(ref p);
    p=parameter(1,0,false);p.body.code[ret*8+3]=1;rejected(ref p);
}
@test fn void ordinary_call_opcodes_do_not_bypass_static_argument_classification(){
    var calls::Program p=parameter(1,0,false);let usize call=find(ref p.body,78,0);p.body.code[call*8]=9;rejected(ref p);
    p=parameter(1,0,false);p.body.call_args[1]=192;rejected(ref p);
    p=parameter(1,0,false);p.body.call_arities[0]=0;rejected(ref p);
    p=parameter(1,0,false);p.body.code[call*8+5]=1;rejected(ref p);
}
@test fn void recipe_proof_never_promotes_bare_or_retained_program_execution(){
    let calls::Program p=parameter(1,0,false);let calls::Proof checked=accepted(ref p);
    switch(verifier::inspect(ref p.body)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
    switch(vm::run(ref p.body,16000000)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
    let borrowed::Program body=borrowed::Program{.body=p.body,.elements=[0;16],.parameters=[0;16]};
    let images::Image backing=image();switch(programs::retain(ref body,backing,8192)){
        case .ok(_):{assert(false);}case .err(e):{switch(e.kind){case .Code:{assert(e.code.kind==5);}case .Literal:{assert(false);}}}
    };
}


fn calls::Program choice(bool conflict){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=0;p.return_types[0]=1;p.return_types[1]=0;
    let usize root_a=open(ref mut p,0,1);let usize root_b=open(ref mut p,1,1);let usize condition=built(ir::boolean(ref mut p,false,0));
    p.call_count=1;p.call_arities[0]=3;p.call_args[0]=192;p.call_args[1]=193;p.call_args[2]=0;
    let usize call=built(ir::raw(ref mut p,78,4,1,0,0));close(ref mut p,1);close(ref mut p,0);answer(ref mut p,4,1);end(ref mut p,0);
    let usize a=fresh(ref mut p,0);let usize b=fresh(ref mut p,0);let usize test=fresh(ref mut p,2);p.arities[1]=3;
    let usize pa=built(ir::raw(ref mut p,77,2,a,1,0));let usize pb=built(ir::raw(ref mut p,77,3,b,1,0));
    let usize branch=built(ir::raw(ref mut p,20,0,test,0,0));close(ref mut p,3);returned(ref mut p,2);
    let usize second=p.count;close(ref mut p,if(conflict){2}else{3});returned(ref mut p,if(conflict){3}else{2});
    let usize patched=built(ir::patch(ref mut p,branch,second,0));end(ref mut p,1);
    var u8[128] parameters=[0;128];parameters[a]=1;parameters[b]=1;
    var u8[16] results=[0;16];var u8[16] origins=[0;16];results[1]=1;origins[1]=1;
    return calls::Program{.body=p,.parameters=parameters,.results=results,.origins=origins};
}
@test fn void every_return_path_must_select_the_same_logical_input_origin(){
    let calls::Program consistent=choice(false);let calls::Proof checked=accepted(ref consistent);assert(checked.returns==2 && checked.result_origins[1]==1);
    let calls::Program conflicting=choice(true);rejected(ref conflicting);
}
fn calls::Program forwarding(){
    let calls::Program base=parameter(1,0,true);var ir::Program p=base.body;
    var u8[128] parameters=base.parameters;var u8[16] results=base.results;var u8[16] origins=base.origins;
    let usize ret=find(ref p,79,0);p.code[ret*8]=78;p.code[ret*8+1]=3;p.code[ret*8+2]=2;p.code[ret*8+3]=1;
    p.function_count=3;p.call_count=2;p.call_arities[1]=1;p.call_args[8]=194;
    close(ref mut p,2);returned(ref mut p,3);end(ref mut p,1);
    let usize formal=fresh(ref mut p,0);parameters[formal]=1;p.arities[2]=1;p.return_types[2]=0;results[2]=1;origins[2]=1;
    let usize param=built(ir::raw(ref mut p,77,5,formal,1,0));returned(ref mut p,5);end(ref mut p,2);
    return calls::Program{.body=p,.parameters=parameters,.results=results,.origins=origins};
}
@test fn void transitive_calls_remap_callee_origins_to_the_callers_logical_positions(){
    let calls::Program p=forwarding();let calls::Proof proof=accepted(ref p);
    assert(proof.result_origins[1]==2 && proof.result_origins[2]==1 && proof.site_origins[3]==2 && proof.site_origins[1]==9 && proof.rounds>=3);
}
