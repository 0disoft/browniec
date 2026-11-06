module tests::m2::reference_return_lifetimes;
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
// Full canonical proof adds owner lifetimes to these return recipes.
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
fn void accepted(ref calls::Program p){let images::Image data=image();switch(verifier::inspect_reference_returns(p,ref data)){
    case .ok(_):{}case .err(_):{assert(false);}
};}
fn void rejected_at(ref calls::Program p,usize pc){let images::Image data=image();
    assert(calls::inspect_reference_returns(p,ref data).is_ok);
    switch(verifier::inspect_reference_returns(p,ref data)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==pc);}};
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
fn calls::Program source_closed(){var calls::Program p=unit(1,false,0,false);p.body.arrays.mutable[0]=true;
    let usize read=find(ref p.body,71,0);let usize close=find(ref p.body,70,2);let usize original=find(ref p.body,56,0);
    swap(ref mut p.body,read,original);swap(ref mut p.body,close,original);return p;
}
fn void effect(ref mut ir::Program p,usize at,u8 op,usize root){let usize init=find(p,33,0);let usize fill=p.code[init*8+2] as usize;
    if(op==81){assert(p.arrays.lengths[root]==1 && p.list_used==0);p.list_operands[0]=byte(fill);p.list_used=1;
        insert(p,at,81,root,0,0);return;}
    let usize open=find(p,54,0);let usize index=p.code[open*8+2] as usize;
    insert(p,at,op,root,if(op==36){index}else if(op==38){root}else{fill},if(op==36){fill}else{0});
}
@test fn void complete_return_analysis_remaps_each_call_actual_without_ancestor_owner_aliasing(){
    let calls::Program p=unit(8,true,2,true);let images::Image data=image();
    switch(verifier::inspect_reference_returns(ref p,ref data)){
        case .ok(v):{assert(v.owner_roots[1]==0 && v.owner_roots[2]==1 && v.owner_roots[3]==0);
            assert(v.owner_roots[11]==0 && v.owner_roots[12]==0 && v.recipes.result_origins[1]==2);}
        case .err(_):{assert(false);}
    };
    let calls::Program empty=unit(1,false,3,true);accepted(ref empty);
}
@test fn void closing_original_loan_preserves_returned_view_but_cannot_free_its_owner(){
    var calls::Program p=source_closed();accepted(ref p);
    let usize close=find(ref p.body,70,2);let usize drop=find(ref p.body,37,0);swap(ref mut p.body,close,drop);
    let usize read=find(ref p.body,71,0);let usize freed=find(ref p.body,37,0);swap(ref mut p.body,read,freed);
    rejected_at(ref p,read);
}
@test fn void writes_fill_and_assignment_reject_at_the_exact_effect_while_result_is_live(){
    let u8[4] ops=[36,38,40,81];var usize i=0;while(i<4){var calls::Program p=source_closed();
        let usize at=find(ref p.body,71,0);effect(ref mut p.body,at,ops[i],0);rejected_at(ref p,at);i+=1;}
}
@test fn void last_close_allows_mutation_and_an_unrelated_owner_remains_writable(){
    let u8[4] ops=[36,38,40,81];var usize i=0;while(i<4){var calls::Program p=source_closed();
        let usize at=find(ref p.body,37,0);effect(ref mut p.body,at,ops[i],0);accepted(ref p);i+=1;}
    var calls::Program p=source_closed();let usize other=built(ir::array_in(ref mut p.body,0,10,1,true,0));assert(other==1);
    let usize init=find(ref p.body,33,0);let usize fill=p.body.code[init*8+2] as usize;insert(ref mut p.body,init,33,other,fill,0);
    let usize read=find(ref p.body,71,0);effect(ref mut p.body,read,36,other);
    let usize drop=find(ref p.body,37,0);insert(ref mut p.body,drop,37,other,0,0);accepted(ref p);
}
fn calls::Program aliases(bool after){var calls::Program p=source_closed();let usize start=find(ref p.body,78,1)+1;
    let usize open=find(ref p.body,54,0);let usize lo=p.body.code[open*8+2] as usize;let usize hi=p.body.code[open*8+3] as usize;
    insert(ref mut p.body,start,75,14,2,0);insert(ref mut p.body,start+1,76,15,14,lo);p.body.code[(start+1)*8+4]=byte(hi);
    let usize drop=find(ref p.body,37,0);insert(ref mut p.body,drop,70,14,0,0);insert(ref mut p.body,drop+1,70,15,0,0);
    effect(ref mut p.body,if(after){drop+2}else{drop+1},36,0);return p;
}
@test fn void aliases_and_ranges_keep_the_owner_until_every_returned_view_is_closed(){
    let calls::Program bad=aliases(false);rejected_at(ref bad,find(ref bad.body,36,0));
    let calls::Program good=aliases(true);let images::Image data=image();
    switch(verifier::inspect_reference_returns(ref good,ref data)){
        case .ok(v):{assert(v.owner_roots[2]==1 && v.owner_roots[14]==1 && v.owner_roots[15]==1);}case .err(_):{assert(false);}
    };
}
@test fn void exclusive_open_rejects_before_publication_and_succeeds_after_last_close(){
    var usize i=0;while(i<2){var calls::Program p=source_closed();p.body.slice_roots[1]=1;p.body.slice_elements[1]=128;
        let usize original=find(ref p.body,54,0);let usize lo=p.body.code[original*8+2] as usize;let usize hi=p.body.code[original*8+3] as usize;
        let usize at=if(i==0){find(ref p.body,71,0)}else{find(ref p.body,37,0)};
        insert(ref mut p.body,at,54,1,lo,hi);insert(ref mut p.body,at+1,56,1,0,0);
        if(i==0){rejected_at(ref p,at);}else{accepted(ref p);}i+=1;
    }
}
@test fn void selected_places_respect_returned_owner_protection_at_select_read_and_store(){
    var usize mode=0;while(mode<4){var calls::Program p=source_closed();
        let usize initialized=find(ref p.body,33,0);let usize fill=p.body.code[initialized*8+2] as usize;
        let usize open=find(ref p.body,54,0);let usize index=p.body.code[open*8+2] as usize;
        if(mode==0 || mode==3){let usize at=if(mode==0){find(ref p.body,71,0)}else{find(ref p.body,37,0)};
            insert(ref mut p.body,at,83,0,0,index);insert(ref mut p.body,at+1,85,0,0,fill);insert(ref mut p.body,at+2,86,0,0,0);
            if(mode==0){rejected_at(ref p,at);}else{accepted(ref p);}
        }else{
            insert(ref mut p.body,open,83,0,0,index);let usize at=find(ref p.body,71,0);
            if(mode==1){insert(ref mut p.body,at,85,0,0,fill);insert(ref mut p.body,at+1,86,0,0,0);}
            else{p.body.code[at*8]=84;p.body.code[at*8+2]=0;p.body.code[at*8+3]=0;
                let usize drop=find(ref p.body,37,0);insert(ref mut p.body,drop,86,0,0,0);}
            rejected_at(ref p,at);
        }mode+=1;
    }
}
@test fn void ordinary_shared_input_results_keep_exact_ancestry_and_canonical_scalar_checks(){
    var calls::Program p=unit(1,false,0,true);let usize formal=p.body.register_starts[1];p.parameters[formal]=0;
    p.body.slice_parameters[formal]=2;p.body.slice_origins[1]=2;p.body.slice_functions[1]=2;p.body.slice_elements[1]=10;
    p.body.call_args[0]=160;let usize param=find(ref p.body,77,0);p.body.code[param*8]=19;p.body.code[param*8+1]=0;
    p.body.code[param*8+2]=byte(param+1);p.body.code[param*8+3]=0;
    let usize forwarded=find(ref p.body,78,2);let usize map=p.body.code[forwarded*8+3] as usize;p.body.call_args[map*8]=161;
    let usize close=find(ref p.body,70,3);p.body.code[close*8]=56;p.body.code[close*8+1]=1;accepted(ref p);
    p=unit(1,false,0,false);let usize read=find(ref p.body,71,0);p.body.code[read*8+3]=0;rejected_at(ref p,read);
    p=unit(1,false,0,false);let usize target=find(ref p.body,78,1);insert(ref mut p.body,target,56,0,0,0);rejected_at(ref p,target+1);
}
@test fn void complete_return_proof_does_not_enable_unimplemented_vm_or_public_admission(){
    let calls::Program p=unit(1,false,2,true);accepted(ref p);let images::Image data=image();
    assert(!verifier::inspect_reference_calls(ref p,ref data).is_ok && !verifier::verify_static_calls(ref p,ref data).is_ok);
    switch(programs::retain_references(ref p,image(),578)){case .ok(_):{assert(false);}case .err(_):{}};
    switch(programs::retain_calls(ref p,image(),578)){case .ok(_):{assert(false);}case .err(_):{}};
}
