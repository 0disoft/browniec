module tests::m2::output_static_recipe_work;
import output_static_recipe_work as work;
import static_call_ir as raw;
import ir as ir;
import static_image as images;
import errors as errors;
import metadata_budget as budget;
import std::num as num;

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
fn void same_proof(ref raw::Proof expected,ref raw::Proof actual){
    var usize i=0;while(i<16){assert(expected.definitions[i]==actual.definitions[i]);
        assert(expected.functions[i]==actual.functions[i]);assert(expected.kinds[i]==actual.kinds[i]);
        assert(expected.site_origins[i]==actual.site_origins[i]);assert(expected.result_origins[i]==actual.result_origins[i]);i+=1;}
    i=0;while(i<128){assert(expected.formal_sites[i]==actual.formal_sites[i]);i+=1;}
    assert(expected.sites==actual.sites && expected.calls==actual.calls && expected.returns==actual.returns && expected.rounds==actual.rounds);
}
fn Result<raw::Proof,errors::Error> staged(ref raw::Program unit,ref images::Image data,bool input){
    var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    let usize begun=work::begin(ref mut w,unit,data,input)?;
    while(!w.done){assert(turns<4096);assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(ref mut w,unit,data,ref mut meter)?;
        assert(done==w.done && meter.last==4096);turns+=1;}
    let raw::Proof proof=work::prepared(ref w)?;let usize total=meter.total;
    assert(work::advance(ref mut w,unit,data,ref mut meter).is_ok);assert(total==meter.total);
    return .ok(proof);
}
fn Result<raw::Proof,errors::Error> staged_input(ref raw::Program unit,ref images::Image data){
    var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    let usize begun=work::begin_input(ref mut w,unit,data)?;assert(!w.output && w.input);
    while(!w.done){assert(turns<4096);assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(ref mut w,unit,data,ref mut meter)?;assert(done==w.done);turns+=1;}
    return work::prepared(ref w);
}
fn void same(raw::Program unit,bool input){let images::Image data=image();
    switch(raw::inspect_output_returns(ref unit,ref data,input)){
        case .ok(expected):{switch(staged(ref unit,ref data,input)){case .ok(actual):{same_proof(ref expected,ref actual);}case .err(_):{assert(false);}};}
        case .err(expected):{switch(staged(ref unit,ref data,input)){case .ok(_):{assert(false);}case .err(actual):{
            assert(expected.kind==actual.kind && expected.offset==actual.offset);}};}
    };
}
fn usize find(ref ir::Program p,u8 op,usize nth){var usize pc=0;var usize n=0;while(pc<p.count){
    if(p.code[pc*8]==op){if(n==nth){return pc;}n+=1;}pc+=1;}assert(false);return 0;}
fn raw::Program parameter(u8 kind,u8 mode,bool scalar_prefix){
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
    return raw::Program{.body=p,.parameters=parameters,.results=results,.origins=origins};
}
fn raw::Program input(){
    var ir::Program p=ir::empty();p.count=4;p.function_count=1;p.entry=0;p.registers=2;
    p.register_ends[0]=2;p.ends[0]=4;p.arities[0]=1;p.return_types[0]=1;p.types[1]=1;
    p.constant_count=1;p.constants[0]=42;
    p.code[0]=77;p.code[1]=0;p.code[2]=0;p.code[3]=3;
    p.code[8]=70;p.code[9]=0;p.code[10]=0;p.code[11]=0;
    p.code[16]=1;p.code[17]=1;p.code[18]=0;p.code[19]=0;
    p.code[24]=8;p.code[25]=0;p.code[26]=1;p.code[27]=0;
    var u8[128] parameters=[0;128];parameters[0]=3;
    return raw::Program{.body=p,.parameters=parameters,.results=[0;16],.origins=[0;16]};
}
fn raw::Program literal(bool recursive,bool grounded){
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
    return raw::Program{.body=p,.parameters=[0;128],.results=results,.origins=origins};
}
fn raw::Program forwarding(){
    let raw::Program base=parameter(1,0,true);var ir::Program p=base.body;
    var u8[128] parameters=base.parameters;var u8[16] results=base.results;var u8[16] origins=base.origins;
    let usize ret=find(ref p,79,0);p.code[ret*8]=78;p.code[ret*8+1]=3;p.code[ret*8+2]=2;p.code[ret*8+3]=1;
    p.function_count=3;p.call_count=2;p.call_arities[1]=1;p.call_args[8]=194;
    close(ref mut p,2);returned(ref mut p,3);end(ref mut p,1);
    let usize formal=fresh(ref mut p,0);parameters[formal]=1;p.arities[2]=1;p.return_types[2]=0;results[2]=1;origins[2]=1;
    let usize param=built(ir::raw(ref mut p,77,5,formal,1,0));returned(ref mut p,5);end(ref mut p,2);
    return raw::Program{.body=p,.parameters=parameters,.results=results,.origins=origins};
}
fn raw::Program cycle(){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=0;p.return_types[0]=1;p.return_types[1]=0;
    let usize root=open(ref mut p,1,1);returned(ref mut p,1);end(ref mut p,0);
    let usize loop_start=p.count;let usize step=built(ir::raw(ref mut p,25,0,0,0,0));
    let usize back=built(ir::raw(ref mut p,22,0,loop_start,0,0));let usize stop=built(ir::raw(ref mut p,82,0,0,0,0));end(ref mut p,1);
    var u8[16] results=[0;16];var u8[16] origins=[0;16];results[1]=1;origins[1]=9;
    return raw::Program{.body=p,.parameters=[0;128],.results=results,.origins=origins};
}
fn raw::Program jump_into_parameter(){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=0;p.return_types[0]=1;p.return_types[1]=0;
    let usize entry=fresh(ref mut p,3);p.arities[0]=1;
    let usize entry_param=built(ir::raw(ref mut p,77,0,entry,3,0));close(ref mut p,0);let usize entry_stop=built(ir::raw(ref mut p,82,0,0,0,0));end(ref mut p,0);
    let usize formal=fresh(ref mut p,1);p.arities[1]=1;
    let usize param=built(ir::raw(ref mut p,77,0,formal,1,0));
    let usize branch=built(ir::raw(ref mut p,19,0,param,0,0));let usize stop=built(ir::raw(ref mut p,82,0,0,0,0));end(ref mut p,1);
    var u8[128] parameters=[0;128];parameters[entry]=3;parameters[formal]=1;
    var u8[16] results=[0;16];var u8[16] origins=[0;16];
    return raw::Program{.body=p,.parameters=parameters,.results=results,.origins=origins};
}
@test fn void complete_output_recipe_matches_raw_in_every_definitions_flow_and_origin_bank(){
    same(parameter(1,0,false),false);same(parameter(1,1,false),false);same(parameter(1,2,false),false);
    same(parameter(2,0,false),false);same(parameter(2,3,false),false);
    same(parameter(1,0,true),false);same(literal(false,true),false);same(literal(false,true),true);
    same(forwarding(),false);same(cycle(),false);
}
@test fn void input_mode_rejects_emit_but_accepts_the_shared_byte_entry_recipe(){
    let raw::Program accepted=input();let images::Image data=image();
    switch(raw::inspect_input_returns(ref accepted,ref data)){case .ok(expected):{
        switch(staged_input(ref accepted,ref data)){case .ok(actual):{same_proof(ref expected,ref actual);}case .err(_):{assert(false);}}
    }case .err(_):{assert(false);}};
    var raw::Program emitted=accepted;emitted.body.code[8]=116;emitted.body.code[9]=0;
    emitted.body.code[10]=0;emitted.body.code[11]=1;
    switch(staged_input(ref emitted,ref data)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==1);}};
    switch(raw::inspect_input_returns(ref emitted,ref data)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==1);}};
}
@test fn void header_then_image_then_definition_diagnostics_preserve_raw_precedence(){
    var raw::Program p=parameter(1,0,false);p.parameters[127]=1;same(p,false);
    p=parameter(1,0,false);p.origins[1]=9;same(p,false);
    p=parameter(1,0,false);let usize param=find(ref p.body,77,0);p.body.code[param*8+1]=16;same(p,false);
    p=parameter(1,0,false);let usize lit=find(ref p.body,69,0);p.body.code[lit*8+3]=2;same(p,false);
}
@test fn void malformed_flow_coverage_and_origins_match_exact_raw_errors(){
    var raw::Program p=parameter(1,0,false);let usize call=find(ref p.body,78,0);p.body.call_args[0]=0;same(p,false);
    p=parameter(1,0,false);let usize close_pc=find(ref p.body,70,0);p.body.code[close_pc*8+2]=1;same(p,false);
    p=parameter(1,1,false);let usize alias=find(ref p.body,75,0);p.body.code[alias*8+2]=7;same(p,false);
    p=parameter(1,0,false);let usize ret=find(ref p.body,79,0);p.body.code[ret*8+2]=0;same(p,false);
    p=forwarding();let usize forward=find(ref p.body,78,1);p.body.code[forward*8+2]=0;same(p,false);
    same(jump_into_parameter(),true);
}
@test fn void fresh_opening_stage_charges_before_invalid_header_diagnostic(){
    var raw::Program p=parameter(1,0,false);p.body.count=0;let images::Image data=image();
    switch(raw::inspect_output_returns(ref p,ref data,false)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==0);}};
    var work::State w=work::empty();var budget::State meter=budget::empty();assert(work::begin(ref mut w,ref p,ref data,false).is_ok);
    switch(work::advance(ref mut w,ref p,ref data,ref mut meter)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==0);}};
    assert(meter.total==4096 && meter.last==4096 && meter.stages==1 && !w.active && !w.done);
}
fn images::Image bad_image(){
    var images::Builder b=switch(images::builder(2)){case .ok(v):{v}case .err(_):{assert(false);return bad_image();}};
    assert(images::intern_bytes(ref mut b,b"*").is_ok);
    return switch(images::freeze(ref b,8192)){case .ok(v):{v}case .err(_):{assert(false);bad_image()}};
}
@test fn void paired_image_substitution_is_rejected_before_any_stage_work(){
    let raw::Program p=parameter(1,0,false);let images::Image good=image();let images::Image bad=bad_image();
    var work::State w=work::empty();var budget::State meter=budget::empty();assert(work::begin(ref mut w,ref p,ref good,false).is_ok);
    let work::State before=w;let budget::State saved=meter;
    switch(work::advance(ref mut w,ref p,ref bad,ref mut meter)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==0);}};
    assert(w.pc==before.pc && w.phase==before.phase && w.work==before.work && meter.total==saved.total && meter.stages==saved.stages);
}
@test fn void malformed_text_boundary_uses_the_already_proved_image_without_text_revalidation(){
    var raw::Program p=parameter(2,0,false);let usize lit=find(ref p.body,69,0);
    p.body.code[lit*8+5]=1;p.body.code[lit*8+6]=2;same(p,false);
    p.body.code[lit*8+5]=1;p.body.code[lit*8+6]=1;same(p,false);
}
@test fn void partial_room_does_not_charge_or_advance_any_recipe_cursor(){
    let raw::Program p=parameter(1,0,false);let images::Image data=image();var work::State w=work::empty();var budget::State meter=budget::empty();
    assert(work::begin(ref mut w,ref p,ref data,false).is_ok);var usize turns=0;
    while(!w.done){assert(turns<4096);assert(budget::reset(ref mut meter,0).is_ok);assert(budget::admit(ref mut meter,1,0).is_ok);
        let work::State before=w;let budget::State saved=meter;
        switch(work::advance(ref mut w,ref p,ref data,ref mut meter)){case .ok(v):{assert(!v);}case .err(_):{assert(false);}};
        assert(w.phase==before.phase && w.function==before.function && w.pc==before.pc && w.round==before.round && w.done==before.done);
        assert(w.result.sites==before.result.sites && w.result.calls==before.result.calls && w.result.returns==before.result.returns);
        assert(meter.total==saved.total && meter.last==saved.last && meter.stages==saved.stages);
        assert(budget::reset(ref mut meter,0).is_ok);assert(work::advance(ref mut w,ref p,ref data,ref mut meter).is_ok);turns+=1;
    }assert(turns>20);
}
@test fn void each_pc_stage_advances_only_one_pc_or_its_explicit_transition(){
    let raw::Program p=parameter(1,0,false);let images::Image data=image();var work::State w=work::empty();var budget::State meter=budget::empty();
    assert(work::begin(ref mut w,ref p,ref data,false).is_ok);var usize turns=0;
    while(!w.done){assert(turns<4096);let u8 phase=w.phase;let usize pc=w.pc;let usize function=w.function;
        assert(budget::reset(ref mut meter,0).is_ok);assert(work::advance(ref mut w,ref p,ref data,ref mut meter).is_ok);
        if(phase==4){assert(w.pc==pc+1 || (function+1==w.function && w.pc==p.body.starts[w.function]));}
        if(phase==7 && w.phase==7){assert(w.pc==pc+1);}
        if(phase==10 && w.phase==10){assert(w.pc==pc+1);}
        if(phase==13 && w.phase==13){assert(w.pc==pc+1);}turns+=1;}
    assert(turns>=p.body.count);
}
