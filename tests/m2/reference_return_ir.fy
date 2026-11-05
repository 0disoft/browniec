module tests::m2::reference_return_ir;
import static_call_ir as calls;
import static_call_sites as windows;
import static_ir as statics;
import static_image as images;
import ir as ir;
import errors as errors;
import verifier as verifier;
import program_image as programs;
import std::num as num;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn u8 byte(usize n){return switch(num::u8_from_i64(switch(num::i64_from_usize(n)){case .ok(v):{v}case .err(_):{assert(false);0}})){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize fresh(ref mut ir::Program p,u8 tag){let usize r=p.registers;p.types[r]=tag;p.registers+=1;return r;}
fn void end(ref mut ir::Program p,usize f){let usize pc=p.count;let usize r=p.registers;p.ends[f]=pc;p.register_ends[f]=r;
    if(f+1<p.function_count){p.starts[f+1]=pc;p.register_starts[f+1]=r;}}
fn images::Image image(){
    var images::Builder b=switch(images::builder(2)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    let usize a=switch(images::intern_bytes(ref mut b,b"*")){case .ok(v):{v}case .err(_):{assert(false);0}};
    let usize t=switch(images::intern_text(ref mut b,b"*")){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(images::freeze(ref b,578)){case .ok(v):{v}case .err(_):{assert(false);image()}};
}
fn usize call(ref mut ir::Program p,usize dst,usize target,ref usize[] args){
    let usize map=p.call_count;p.call_count+=1;p.call_arities[map]=byte(args.len);
    var usize i=0;while(i<args.len){p.call_args[map*8+i]=byte(args[i]);i+=1;}
    return built(ir::raw(p,78,dst,target,map,0));
}
fn usize find(ref ir::Program p,u8 op,usize nth){var usize n=0;var usize pc=0;
    while(pc<p.count){if(p.code[pc*8]==op){if(n==nth){return pc;}n+=1;}pc+=1;}assert(false);return 0;}
// Same returned signature is called with an image and a rooted runtime loan.
// This fixture intentionally proves recipes only, not returned-loan lifetimes.
fn calls::Program unit(usize arity,bool prefix,u8 projection,bool forward){
    var ir::Program p=ir::empty();p.function_count=if(forward){3}else{2};p.return_types[0]=1;
    let usize root=built(ir::array_in(ref mut p,0,10,1,false,0));let usize fill=built(ir::integer(ref mut p,42,10,0));
    let usize initialized=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize loan=built(ir::slice(ref mut p,root,0));let usize opened=built(ir::slice_open(ref mut p,loan,lo,hi,0));
    let usize literal=built(ir::raw(ref mut p,69,0,0,1,0));p.code[literal*8+6]=1;
    var usize[8] actuals=[192;8];if(prefix){actuals[0]=fill;}
    let usize first=call(ref mut p,1,1,ref actuals[..arity]);
    let usize close=built(ir::raw(ref mut p,70,0,0,0,0));
    let usize first_close=built(ir::raw(ref mut p,70,1,0,0,0));
    var usize i=0;while(i<arity){actuals[i]=if(prefix && i==0){fill}else{160+loan};i+=1;}
    let usize second=call(ref mut p,2,1,ref actuals[..arity]);let usize value=fresh(ref mut p,10);
    let usize read=built(ir::raw(ref mut p,71,value,2,lo,0));let usize second_close=built(ir::raw(ref mut p,70,2,0,0,0));
    let usize ended=built(ir::slice_close(ref mut p,loan,0));let usize dropped=built(ir::array_drop(ref mut p,root,0));
    let usize wide=built(ir::widen(ref mut p,value,1,0));let usize done=built(ir::emit(ref mut p,8,wide,0,0));end(ref mut p,0);
    var u8[128] parameters=[0;128];p.arities[1]=arity;i=0;
    if(prefix){let usize scalar=fresh(ref mut p,10);i=1;}
    let usize start=p.registers;var usize count=0;
    while(i<arity){let usize formal=fresh(ref mut p,0);parameters[formal]=3;count+=1;i+=1;}
    i=0;while(i<count){let usize param=built(ir::raw(ref mut p,77,3+i,start+i,3,0));i+=1;}
    var usize selected=3;
    if(projection==1){let usize alias=built(ir::raw(ref mut p,75,11,3,0,0));selected=11;}
    if(projection>=2){let usize low=built(ir::integer(ref mut p,0,12,0));let usize high=built(ir::integer(ref mut p,if(projection==3){0}else{1},12,0));
        let usize range=built(ir::raw(ref mut p,76,11,3,low,0));p.code[range*8+4]=byte(high);selected=11;}
    i=0;while(i<count){if(3+i!=selected){let usize closed=built(ir::raw(ref mut p,70,3+i,0,0,0));}i+=1;}
    var u8[16] results=[0;16];var u8[16] origins=[0;16];results[1]=3;origins[1]=if(prefix){2}else{1};
    if(forward){let usize[1] refs=[192+selected];let usize called=call(ref mut p,12,2,ref refs);
        let usize closed=built(ir::raw(ref mut p,70,selected,0,0,0));let usize returned=built(ir::raw(ref mut p,79,0,12,0,0));end(ref mut p,1);
        p.arities[2]=1;let usize formal=fresh(ref mut p,0);parameters[formal]=3;
        let usize param=built(ir::raw(ref mut p,77,13,formal,3,0));let usize ret=built(ir::raw(ref mut p,79,0,13,0,0));end(ref mut p,2);
        results[2]=3;origins[2]=1;
    }else{let usize returned=built(ir::raw(ref mut p,79,0,selected,0,0));end(ref mut p,1);}
    return calls::Program{.body=p,.parameters=parameters,.results=results,.origins=origins};
}
fn calls::Proof accepted(ref calls::Program p){let images::Image data=image();return switch(calls::inspect_reference_returns(p,ref data)){
    case .ok(v):{v}case .err(_):{assert(false);calls::Proof{.definitions=[256;16],.functions=[16;16],.kinds=[0;16],.formal_sites=[0;128],.site_origins=[0;16],.result_origins=[0;16],.sites=0,.calls=0,.returns=0,.rounds=0}}
};}
fn void rejected(ref calls::Program p){let images::Image data=image();switch(calls::inspect_reference_returns(p,ref data)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}
};}
@test fn void returned_byte_recipes_keep_selected_input_and_distinguish_caller_local_origins(){
    let calls::Program p=unit(1,false,0,false);let calls::Proof proof=accepted(ref p);
    assert(proof.kinds[1]==3 && proof.kinds[2]==3 && proof.result_origins[1]==1);
    assert(proof.site_origins[1]==9 && proof.site_origins[2]==10 && proof.site_origins[3]==1);
    let images::Image data=image();let statics::Sites roots=switch(windows::prepare(ref p,ref proof,ref data)){
        case .ok(v):{v}case .err(_):{assert(false);statics::empty()}
    };assert(roots.roots[1]==1 && roots.roots[2]==0 && roots.roots[3]==1);
}
@test fn void aliases_ranges_empty_windows_and_transitive_calls_preserve_return_origins(){
    let calls::Program a=unit(1,false,1,false);let calls::Proof alias=accepted(ref a);assert(alias.site_origins[11]==1);
    let calls::Program b=unit(1,false,2,true);let calls::Proof range=accepted(ref b);
    assert(range.result_origins[1]==1 && range.result_origins[2]==1 && range.site_origins[12]==1);
    let calls::Program c=unit(1,false,3,true);let calls::Proof empty=accepted(ref c);assert(empty.site_origins[12]==1);
}
@test fn void eight_actuals_and_scalar_prefixes_select_exact_logical_result_position(){
    let calls::Program a=unit(8,false,0,false);let calls::Proof all=accepted(ref a);assert(all.site_origins[3]==1 && all.site_origins[10]==8);
    let calls::Program b=unit(8,true,2,true);let calls::Proof prefix=accepted(ref b);
    assert(prefix.result_origins[1]==2 && prefix.site_origins[11]==2 && prefix.site_origins[12]==2);
    var calls::Program bad=b;bad.origins[1]=1;rejected(ref bad);
}
@test fn void image_byte_results_can_use_generic_result_kind_without_runtime_coercion(){
    var calls::Program p=unit(1,false,0,false);let usize formal=p.body.register_starts[1];
    p.parameters[formal]=1;let usize at=find(ref p.body,77,0);p.body.code[at*8+3]=1;
    // Both actuals are immutable image bytes in this version of the recipe.
    p.body.call_args[8]=206;let usize open=find(ref p.body,54,0);
    p.body.code[open*8]=69;p.body.code[open*8+1]=14;p.body.code[open*8+2]=0;p.body.code[open*8+3]=1;p.body.code[open*8+6]=1;
    let usize close=find(ref p.body,56,0);p.body.code[close*8]=70;p.body.code[close*8+1]=14;
    let calls::Proof proof=accepted(ref p);assert(proof.result_origins[1]==1 && proof.site_origins[2]==9);
}
@test fn void ordinary_rootless_shared_inputs_map_to_their_logical_origin(){
    var calls::Program p=unit(1,false,0,true);let usize f=1;let usize formal=p.body.register_starts[f];
    p.parameters[formal]=0;p.body.slice_parameters[formal]=2;p.body.slice_origins[1]=2;p.body.slice_functions[1]=2;p.body.slice_elements[1]=10;
    p.body.call_args[0]=160;
    let usize param=find(ref p.body,77,0);p.body.code[param*8]=19;p.body.code[param*8+1]=0;
    p.body.code[param*8+2]=byte(param+1);p.body.code[param*8+3]=0;
    // Skip the removed universal PARAM without inventing a scalar cell.
    // Forward the ordinary formal loan at its exact logical input position.
    let usize forwarded=find(ref p.body,78,2);let usize map=p.body.code[forwarded*8+3] as usize;p.body.call_args[map*8]=161;
    let usize close=find(ref p.body,70,3);p.body.code[close*8]=56;p.body.code[close*8+1]=1;
    let calls::Proof proof=accepted(ref p);assert(proof.result_origins[1]==1 && proof.site_origins[12]==1);
    p.body.slice_elements[1]=138;rejected(ref p);
}
@test fn void returning_an_owned_local_or_conflicting_origin_is_rejected(){
    var calls::Program p=unit(1,false,0,false);p.origins[1]=9;rejected(ref p);
    p=unit(1,false,0,true);let usize at=find(ref p.body,78,2);let usize map=p.body.code[at*8+3] as usize;
    // Spoofing an owned local source cannot satisfy a declared input origin.
    p.body.call_args[map*8]=160;p.body.slice_roots[0]=1;rejected(ref p);
    p=unit(1,false,0,false);let usize ret=find(ref p.body,79,0);p.body.code[ret*8+2]=0;rejected(ref p);
}
@test fn void generic_return_cannot_be_text_or_an_image_only_result(){
    var calls::Program p=unit(1,false,0,false);p.results[1]=1;rejected(ref p);
    p=unit(1,false,0,false);p.results[1]=2;rejected(ref p);
    p=unit(1,false,0,false);p.origins[1]=10;rejected(ref p);
    p=unit(1,false,0,false);p.origins[1]=0;rejected(ref p);
}
@test fn void returned_recipe_proof_never_opens_current_canonical_or_retained_admission(){
    let calls::Program p=unit(1,false,2,true);let calls::Proof proof=accepted(ref p);let images::Image data=image();
    assert(!calls::inspect(ref p,ref data).is_ok && !calls::inspect_references(ref p,ref data).is_ok);
    assert(!verifier::inspect_reference_calls(ref p,ref data).is_ok && !verifier::verify_static_calls(ref p,ref data).is_ok);
    switch(programs::retain_references(ref p,image(),578)){case .ok(_):{assert(false);}case .err(_):{}};
    switch(programs::retain_calls(ref p,image(),578)){case .ok(_):{assert(false);}case .err(_):{}};
}
