module tests::m2::static_execution;
import program_image as programs;
import static_image as images;
import compiler as compiler;
import slice_result_ir as ir;
import ir as ordinary_ir;
import slice_result_runtime as runtime;
import slice_result_execution as execution;
import array_owners as owners;
import array_slices as slices;
import std::bytes as bytes;
import errors as errors;
import verifier as verifier;
import vm as vm;
import static_ir as statics;
import static_execution as static_vm;
import static_builders as static_builders;

fn usize built(Result<usize,errors::Error> result){
    return switch(result){case .ok(value):{value}case .err(_):{assert(false);0}};
}
fn usize fresh(ref mut ordinary_ir::Program p,u8 tag){
    let usize register=p.registers;p.types[register]=tag;p.registers+=1;return register;
}
fn usize index_zero(ref mut ordinary_ir::Program p){return built(ordinary_ir::integer(p,0,12,0));}
fn usize index_one(ref mut ordinary_ir::Program p){return built(ordinary_ir::integer(p,1,12,0));}
fn usize open_site(ref mut ordinary_ir::Program p,usize site,usize literal,u8 kind,u8 start,u8 end){
    let usize pc=built(ordinary_ir::raw(p,69,site,literal,0,0));
    p.code[pc*8+3]=kind;p.code[pc*8+4]=start;p.code[pc*8+5]=0;
    p.code[pc*8+6]=end;p.code[pc*8+7]=0;return pc;
}
fn usize close_site(ref mut ordinary_ir::Program p,usize site){return built(ordinary_ir::raw(p,70,site,0,0,0));}
fn usize read_site(ref mut ordinary_ir::Program p,usize dst,usize site,usize index){
    return built(ordinary_ir::raw(p,71,dst,site,index,0));
}
fn usize length_site(ref mut ordinary_ir::Program p,usize dst,usize site){
    return built(ordinary_ir::raw(p,72,dst,site,0,0));
}
fn usize equal_sites(ref mut ordinary_ir::Program p,usize dst,usize a,usize b){
    return built(ordinary_ir::raw(p,73,dst,a,b,0));
}
fn usize bytes_site(ref mut ordinary_ir::Program p,usize dst,usize text){
    return built(ordinary_ir::raw(p,74,dst,text,0,0));
}
fn void function_end(ref mut ordinary_ir::Program p,usize f){
    let usize end=p.count;let usize registers=p.registers;
    p.ends[f]=end;p.register_ends[f]=registers;
    if(f+1<p.function_count){p.starts[f+1]=end;p.register_starts[f+1]=registers;}
}
fn usize returned(ref mut ordinary_ir::Program p,usize value){
    return built(ordinary_ir::emit(p,8,value,0,0));
}
fn usize choose_i32(ref mut ordinary_ir::Program p,usize condition,i64 yes,i64 no){
    let usize slot=built(ordinary_ir::slot(p,1,0));
    let usize positive=built(ordinary_ir::integer(p,yes,1,0));
    let usize branch=built(ordinary_ir::raw(p,20,0,condition,0,0));
    let usize store_yes=built(ordinary_ir::raw(p,18,slot,positive,0,0));
    let usize jump=built(ordinary_ir::raw(p,19,0,0,0,0));
    let usize zero_path=p.count;
    let usize negative=built(ordinary_ir::integer(p,no,1,0));
    let usize store_no=built(ordinary_ir::raw(p,18,slot,negative,0,0));
    let usize joined=p.count;
    let usize load=built(ordinary_ir::emit(p,17,slot,0,0));
    let usize patched=built(ordinary_ir::patch(p,branch,zero_path,0));
    let usize linked=built(ordinary_ir::patch(p,jump,joined,0));
    return load;
}
fn usize choose_value(ref mut ordinary_ir::Program p,usize condition,usize yes,usize no){
    let usize slot=built(ordinary_ir::slot(p,1,0));
    let usize branch=built(ordinary_ir::raw(p,20,0,condition,0,0));
    let usize store_yes=built(ordinary_ir::raw(p,18,slot,yes,0,0));
    let usize jump=built(ordinary_ir::raw(p,19,0,0,0,0));
    let usize zero_path=p.count;
    let usize store_no=built(ordinary_ir::raw(p,18,slot,no,0,0));
    let usize joined=p.count;
    let usize load=built(ordinary_ir::emit(p,17,slot,0,0));
    let usize patched=built(ordinary_ir::patch(p,branch,zero_path,0));
    let usize linked=built(ordinary_ir::patch(p,jump,joined,0));
    return load;
}
fn usize nth_opcode(ref ordinary_ir::Program p,u8 op,usize nth){
    var usize pc=0;var usize seen=0;
    while(pc<p.count){
        if(p.code[pc*8]==op){if(seen==nth){return pc;}seen+=1;}
        pc+=1;
    }
    assert(false);return 0;
}
fn ir::Program read_program(){
    var ordinary_ir::Program p=ordinary_ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize index=index_zero(ref mut p);
    let usize opened=open_site(ref mut p,0,0,1,0,1);
    let usize byte=fresh(ref mut p,10);
    let usize read=read_site(ref mut p,byte,0,index);
    let usize value=built(ordinary_ir::widen(ref mut p,byte,1,0));
    let usize closed=close_site(ref mut p,0);
    let usize done=returned(ref mut p,value);function_end(ref mut p,0);
    return ir::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
}
fn ir::Program text_length_program(){
    var ordinary_ir::Program p=ordinary_ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize opened=open_site(ref mut p,0,0,2,0,3);
    let usize converted=bytes_site(ref mut p,1,0);
    let usize length=fresh(ref mut p,12);let usize measured=length_site(ref mut p,length,1);
    let usize closed=close_site(ref mut p,0);let usize bytes_closed=close_site(ref mut p,1);
    let usize expected=built(ordinary_ir::integer(ref mut p,3,12,0));
    let usize equal=built(ordinary_ir::emit(ref mut p,11,length,expected,0));
    let usize answer=choose_i32(ref mut p,equal,42,0);
    let usize done=returned(ref mut p,answer);function_end(ref mut p,0);
    return ir::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
}
fn ir::Program equality_program(u8 left_len,u8 right_len,u8 left_kind,u8 right_kind){
    var ordinary_ir::Program p=ordinary_ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize left=open_site(ref mut p,0,0,left_kind,0,left_len);
    let usize right=open_site(ref mut p,1,if(left_len==0 && right_len==0){0}else{1},right_kind,0,right_len);
    let usize equal=fresh(ref mut p,2);let usize compared=equal_sites(ref mut p,equal,0,1);
    let usize close_left=close_site(ref mut p,0);let usize close_right=close_site(ref mut p,1);
    let usize answer=choose_i32(ref mut p,equal,42,7);
    let usize done=returned(ref mut p,answer);function_end(ref mut p,0);
    return ir::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
}
fn ir::Program bytes_after_close_program(){
    var ordinary_ir::Program p=ordinary_ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize index=index_one(ref mut p);
    let usize text=open_site(ref mut p,0,0,2,0,3);
    let usize view=bytes_site(ref mut p,1,0);
    let usize close_text=close_site(ref mut p,0);
    let usize byte=fresh(ref mut p,10);let usize read=read_site(ref mut p,byte,1,index);
    let usize value=built(ordinary_ir::widen(ref mut p,byte,1,0));
    let usize close_view=close_site(ref mut p,1);
    let usize done=returned(ref mut p,value);function_end(ref mut p,0);
    return ir::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
}
fn ir::Program fuel_program(){
    var ordinary_ir::Program p=ordinary_ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize index=index_zero(ref mut p);
    let usize byte_site=open_site(ref mut p,0,0,1,0,1);
    let usize byte=fresh(ref mut p,10);let usize read=read_site(ref mut p,byte,0,index);
    let usize value=built(ordinary_ir::widen(ref mut p,byte,1,0));
    let usize left=open_site(ref mut p,1,1,2,0,2);
    let usize right=open_site(ref mut p,2,1,2,2,4);
    let usize equal=fresh(ref mut p,2);let usize compared=equal_sites(ref mut p,equal,1,2);
    let usize close_byte=close_site(ref mut p,0);
    let usize close_left=close_site(ref mut p,1);let usize close_right=close_site(ref mut p,2);
    let usize zero=built(ordinary_ir::integer(ref mut p,0,1,0));
    let usize answer=choose_value(ref mut p,equal,value,zero);
    let usize done=returned(ref mut p,answer);function_end(ref mut p,0);
    return ir::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
}
fn ir::Program bounds_program(){
    var ordinary_ir::Program p=ordinary_ir::empty();p.function_count=2;p.entry=0;
    p.return_types[0]=1;p.return_types[1]=1;
    let usize bad_index=index_one(ref mut p);
    let usize bad_open=open_site(ref mut p,0,0,1,0,1);
    let usize bad_byte=fresh(ref mut p,10);let usize bad_read=read_site(ref mut p,bad_byte,0,bad_index);
    let usize bad_close=close_site(ref mut p,0);
    let usize bad_value=built(ordinary_ir::widen(ref mut p,bad_byte,1,0));
    let usize bad_done=returned(ref mut p,bad_value);function_end(ref mut p,0);
    let usize good_index=index_zero(ref mut p);
    let usize good_open=open_site(ref mut p,1,0,1,0,1);
    let usize good_byte=fresh(ref mut p,10);let usize good_read=read_site(ref mut p,good_byte,1,good_index);
    let usize good_close=close_site(ref mut p,1);
    let usize good_value=built(ordinary_ir::widen(ref mut p,good_byte,1,0));
    let usize good_done=returned(ref mut p,good_value);function_end(ref mut p,1);
    return ir::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
}
fn ir::Program coexistence_program(){
    var ordinary_ir::Program p=ordinary_ir::empty();p.function_count=2;p.entry=0;
    p.return_types[0]=1;p.return_types[1]=1;
    let usize root=built(ordinary_ir::array_in(ref mut p,0,1,2,true,0));
    let usize fill=built(ordinary_ir::integer(ref mut p,2,1,0));let usize init=built(ordinary_ir::array_init(ref mut p,root,fill,0));
    let usize slice=built(ordinary_ir::exclusive_slice(ref mut p,root,0));
    let usize zero=index_zero(ref mut p);let usize one=index_one(ref mut p);
    let usize two=built(ordinary_ir::integer(ref mut p,2,12,0));
    let usize opened=built(ordinary_ir::slice_open(ref mut p,slice,zero,two,0));
    let usize written_value=built(ordinary_ir::integer(ref mut p,1,1,0));
    let usize written=built(ordinary_ir::slice_write(ref mut p,slice,zero,written_value,0));
    let usize static_site=open_site(ref mut p,0,0,1,0,1);
    let usize[1] args=[0];let usize called=built(ordinary_ir::call(ref mut p,1,ref args[..0],0));
    let usize byte=fresh(ref mut p,10);let usize read=read_site(ref mut p,byte,0,zero);
    let usize local=built(ordinary_ir::widen(ref mut p,byte,1,0));
    let usize guest=built(ordinary_ir::slice_read(ref mut p,slice,one,0));
    let usize partial=built(ordinary_ir::emit(ref mut p,2,local,called,0));
    let usize total=built(ordinary_ir::emit(ref mut p,2,partial,guest,0));
    let usize close_static=close_site(ref mut p,0);
    let usize close_slice=built(ordinary_ir::slice_close(ref mut p,slice,0));
    let usize drop=built(ordinary_ir::array_drop(ref mut p,root,0));
    let usize done=returned(ref mut p,total);function_end(ref mut p,0);
    let usize helper_index=index_zero(ref mut p);
    let usize helper_open=open_site(ref mut p,1,1,1,0,1);
    let usize helper_byte=fresh(ref mut p,10);
    let usize helper_read=read_site(ref mut p,helper_byte,1,helper_index);
    let usize helper_value=built(ordinary_ir::widen(ref mut p,helper_byte,1,0));
    let usize helper_close=close_site(ref mut p,1);
    let usize helper_done=returned(ref mut p,helper_value);function_end(ref mut p,1);
    return ir::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
}
fn ir::Program compiled(ref u8[] source){
    return switch(compiler::inspect_slice_result_ir(source)){
        case .ok(value):{value}
        case .err(_):{assert(false);ir::Program{.body=ordinary_ir::empty(),.elements=[0;16],.parameters=[0;16]}}
    };
}
fn Result<images::Image,images::Error> one_image(u8 value){
    var images::Builder b=images::builder(1)?;
    let u8[1] payload=[value];let usize literal=images::intern_bytes(ref mut b,ref payload)?;
    assert(literal==0);return images::freeze(ref b,8192);
}
fn Result<images::Image,images::Error> text_image(ref u8[] value){
    var images::Builder b=images::builder(value.len)?;
    let usize literal=images::intern_text(ref mut b,value)?;assert(literal==0);
    return images::freeze(ref b,8192);
}
fn Result<images::Image,images::Error> nul_image(){
    var images::Builder b=images::builder(5)?;
    let u8[3] embedded=[97,0,98];
    let usize first=images::intern_text(ref mut b,ref embedded)?;
    let usize second=images::intern_text(ref mut b,b"ab")?;
    assert(first==0 && second==1);return images::freeze(ref b,8192);
}
fn Result<images::Image,images::Error> empty_image(){
    var images::Builder b=images::builder(0)?;
    let usize first=images::intern_text(ref mut b,b"")?;
    let usize second=images::intern_text(ref mut b,b"")?;
    assert(first==0 && second==0);return images::freeze(ref b,8192);
}
fn Result<images::Image,images::Error> frame_image(){
    var images::Builder b=images::builder(2)?;
    let u8[1] first=[1];let u8[1] second=[39];
    let usize one=images::intern_bytes(ref mut b,ref first)?;
    let usize two=images::intern_bytes(ref mut b,ref second)?;
    assert(one==0 && two==1);return images::freeze(ref b,8192);
}
fn Result<images::Image,images::Error> fuel_image(){
    var images::Builder b=images::builder(5)?;
    let u8[1] byte=[42];let usize first=images::intern_bytes(ref mut b,ref byte)?;
    let usize second=images::intern_text(ref mut b,b"abab")?;
    assert(first==0 && second==1);return images::freeze(ref b,8192);
}
fn Result<programs::Program,programs::Error> attach(ref ir::Program unit,images::Image backing){
    return programs::retain(unit,backing,8192);
}
fn Result<programs::Program,programs::Error> one_kept(ref ir::Program unit,u8 value){
    let images::Image backing=switch(one_image(value)){
        case .ok(image):{image}
        case .err(e):{return .err(programs::Error{.kind=.Literal,.code=errors::make(0,0),.literal=e});}
    };
    return attach(unit,backing);
}
fn bool quota(images::Error e){return switch(e){
    case .Quota:{true}case .State:{false}case .Limit:{false}case .Literals:{false}
    case .Utf8:{false}case .Kind:{false}case .Bounds:{false}case .Allocation:{false}case .Provider:{false}
};}
fn bool content(ref programs::Program p,usize literal,ref u8[] expected){
    let ref images::Image backing=programs::literals(p);
    return switch(images::whole(backing,literal)){
        case .ok(span):{switch(images::view(backing,span)){case .ok(value):{bytes::equal(value,expected)}case .err(_):{false}}}
        case .err(_):{false}
    };
}
fn void drained(ref runtime::State state){
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0 &&
        state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
fn Result<execution::Scalar,errors::Error> run(ref programs::Program p,usize function,usize fuel){
    var runtime::State state=runtime::empty(256);var u8[256] data=[0;256];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let Result<execution::Scalar,errors::Error> result=programs::run_scalar(p,function,
        ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data,fuel);
    drained(ref state);return result;
}
fn Result<execution::Scalar,errors::Error> run_zero(ref programs::Program p,usize function,usize fuel){
    var runtime::State state=runtime::empty(0);var u8[1] data=[0];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let Result<execution::Scalar,errors::Error> result=programs::run_scalar(p,function,
        ref captures[..0],ref values[..0],ref inputs[..0],ref mut state,ref mut data[..0],fuel);
    drained(ref state);return result;
}
@test fn void static_read_42_widens_to_i32_without_guest_backing(){
    let ir::Program unit=read_program();
    let programs::Program p=switch(one_kept(ref unit,42)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    switch(run_zero(ref p,0,1000000)){
        case .ok(value):{assert(value.value==42 && value.remaining>0);}
        case .err(_):{assert(false);}
    };
    assert(content(ref p,0,b"*"));
}

@test fn void text_length_comparison_branches_on_actual_selected_bytes(){
    let ir::Program unit=text_length_program();let u8[3] korean=[237,149,156];
    let images::Image backing=switch(text_image(ref korean)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    let programs::Program p=switch(attach(ref unit,backing)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    switch(run_zero(ref p,0,1000000)){case .ok(value):{assert(value.value==42);}case .err(_):{assert(false);}};
    switch(run_zero(ref p,0,1000000)){case .ok(value):{assert(value.value==42);}case .err(_):{assert(false);}};
}

@test fn void text_equality_handles_embedded_nul_and_empty_utf8(){
    let ir::Program unequal=equality_program(3,2,2,2);
    let images::Image nul=switch(nul_image()){case .ok(value):{value}case .err(_):{assert(false);return;}};
    let programs::Program different=switch(attach(ref unequal,nul)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    switch(run_zero(ref different,0,1000000)){case .ok(value):{assert(value.value==7);}case .err(_):{assert(false);}};
    let ir::Program same=equality_program(0,0,2,2);
    let images::Image empty=switch(empty_image()){case .ok(value):{value}case .err(_):{assert(false);return;}};
    let programs::Program equal=switch(attach(ref same,empty)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    switch(run_zero(ref equal,0,1000000)){case .ok(value):{assert(value.value==42);}case .err(_):{assert(false);}};
}

@test fn void bytes_view_survives_closing_its_text_source(){
    let ir::Program unit=bytes_after_close_program();
    let u8[3] korean=[234,176,128];
    let images::Image backing=switch(text_image(ref korean)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    let programs::Program p=switch(attach(ref unit,backing)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    switch(run_zero(ref p,0,1000000)){case .ok(value):{assert(value.value==176);}case .err(_):{assert(false);}};
    assert(content(ref p,0,ref korean));
}

@test fn void retained_programs_reuse_distinct_images_and_reject_bad_retention(){
    let ir::Program unit=read_program();
    let programs::Program a=switch(one_kept(ref unit,42)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    let programs::Program b=switch(one_kept(ref unit,99)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    switch(run_zero(ref a,0,1000000)){case .ok(value):{assert(value.value==42);}case .err(_):{assert(false);}};
    switch(run_zero(ref b,0,1000000)){case .ok(value):{assert(value.value==99);}case .err(_):{assert(false);}};
    switch(run_zero(ref a,0,1000000)){case .ok(value):{assert(value.value==42);}case .err(_):{assert(false);}};
    assert(content(ref a,0,b"*") && content(ref b,0,b"c"));

    let ir::Program results=compiled(b"module main;fn ref i32[] f(ref i32[] p){return ref p;}fn i32 main(){let i32[2] a=[42;2];let ref i32[] r=f(ref a);return r[0];}");
    let programs::Program returned_view=switch(one_kept(ref results,7)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    switch(run(ref returned_view,results.body.entry,10000000)){case .ok(value):{assert(value.value==42);}case .err(_):{assert(false);}};
    let u8[1] returned_image=[7];assert(content(ref returned_view,0,ref returned_image));

    let ir::Program good=read_program();let images::Image right=switch(one_image(42)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    var ir::Program bad=good;let usize opened=nth_opcode(ref good.body,69,0);bad.body.code[opened*8+6]=2;
    let images::Image bad_backing=switch(one_image(42)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    switch(programs::retain(ref bad,bad_backing,0)){
        case .ok(_):{assert(false);}
        case .err(e):{switch(e.kind){case .Code:{assert(e.code.kind==5);}case .Literal:{assert(false);}}}
    };
    let images::Image text=switch(text_image(b"A")){case .ok(value):{value}case .err(_):{assert(false);return;}};
    switch(programs::retain(ref good,text,8192)){
        case .ok(_):{assert(false);}
        case .err(e):{switch(e.kind){case .Code:{assert(e.code.kind==5);}case .Literal:{assert(false);}}}
    };
    switch(programs::retain(ref good,right,0)){
        case .ok(_):{assert(false);}
        case .err(e):{switch(e.kind){case .Code:{assert(false);}case .Literal:{assert(quota(e.literal));}}}
    };
    switch(verifier::verify(ref good.body)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
    switch(vm::run(ref good.body,0)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};
}

@test fn void static_fuel_matches_driver_added_prices_exactly(){
    let ir::Program unit=fuel_program();
    let images::Image backing=switch(fuel_image()){case .ok(value):{value}case .err(_):{assert(false);return;}};
    let programs::Program p=switch(attach(ref unit,backing)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    let usize exact=runtime::cost()+runtime::leave_cost()+101;
    switch(run_zero(ref p,0,exact)){case .ok(value):{assert(value.value==42 && value.remaining==0);}case .err(_):{assert(false);}};
    switch(run_zero(ref p,0,exact-1)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(run_zero(ref p,0,exact+1)){case .ok(value):{assert(value.value==42 && value.remaining==1);}case .err(_):{assert(false);}};
    assert(content(ref p,0,b"*"));
}

@test fn void bounds_failure_preserves_image_and_zero_backing_for_valid_retry(){
    let ir::Program unit=bounds_program();
    let programs::Program p=switch(one_kept(ref unit,42)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    switch(run_zero(ref p,0,runtime::cost()+35)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(run_zero(ref p,0,runtime::cost()+36)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==14);}};
    switch(run_zero(ref p,0,1000000)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==14);}};
    assert(content(ref p,0,b"*"));
    switch(run_zero(ref p,1,1000000)){case .ok(value):{assert(value.value==42);}case .err(_):{assert(false);}};
    assert(content(ref p,0,b"*"));
}

@test fn void static_site_zero_coexists_with_mutable_guest_slice_and_helper_frame(){
    let ir::Program unit=coexistence_program();
    let images::Image backing=switch(frame_image()){case .ok(value):{value}case .err(_):{assert(false);return;}};
    let programs::Program p=switch(attach(ref unit,backing)){case .ok(value):{value}case .err(_):{assert(false);return;}};
    switch(run(ref p,0,10000000)){case .ok(value):{assert(value.value==42);}case .err(_):{assert(false);}};
    switch(run(ref p,0,10000000)){case .ok(value):{assert(value.value==42);}case .err(_):{assert(false);}};
    let u8[1] first=[1];let u8[1] second=[39];
    assert(content(ref p,0,ref first) && content(ref p,1,ref second));
}

fn ir::Program binary_program(u8 right_begin,u8 right_end){
    var ordinary_ir::Program p=ordinary_ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize left=open_site(ref mut p,0,0,1,0,3);
    let usize right=open_site(ref mut p,1,0,1,right_begin,right_end);
    let usize equal=fresh(ref mut p,2);let usize compared=equal_sites(ref mut p,equal,0,1);
    let usize close_left=close_site(ref mut p,0);let usize close_right=close_site(ref mut p,1);
    let usize answer=choose_i32(ref mut p,equal,42,7);
    let usize done=returned(ref mut p,answer);function_end(ref mut p,0);
    return ir::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
}
fn Result<images::Image,images::Error> binary_image(){
    var images::Builder b=images::builder(6)?;
    let u8[6] payload=[255,0,195,255,0,195];
    let usize literal=images::intern_bytes(ref mut b,ref payload)?;
    assert(literal==0);return images::freeze(ref b,8192);
}
fn Result<images::Image,images::Error> mixed_image(){
    var images::Builder b=images::builder(6)?;
    let u8[3] payload=[97,0,98];
    let usize raw=images::intern_bytes(ref mut b,ref payload)?;
    let usize text=images::intern_text(ref mut b,ref payload)?;
    assert(raw==0 && text==1);return images::freeze(ref b,8192);
}
@test fn void byte_equality_compares_invalid_utf8_and_nul_without_guest_backing(){
    let ir::Program same=binary_program(3,6);
    let images::Image backing=switch(binary_image()){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Program p=switch(attach(ref same,backing)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    // Two OPENs 34, EQUAL 23, two CLOSEs 2, and six scalar/branch instructions.
    let usize exact=runtime::cost()+runtime::leave_cost()+65;
    switch(run_zero(ref p,0,exact)){case .ok(v):{assert(v.value==42 && v.remaining==0);}case .err(_):{assert(false);}};
    switch(run_zero(ref p,0,exact-1)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(run_zero(ref p,0,exact+1)){case .ok(v):{assert(v.value==42 && v.remaining==1);}case .err(_):{assert(false);}};
    let u8[6] payload=[255,0,195,255,0,195];assert(content(ref p,0,ref payload));
}
@test fn void byte_equality_distinguishes_content_length_and_empty_spans(){
    let ir::Program different=binary_program(1,4);
    let images::Image unequal=switch(binary_image()){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Program a=switch(attach(ref different,unequal)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(run_zero(ref a,0,1000000)){case .ok(v):{assert(v.value==7);}case .err(_):{assert(false);}};
    let ir::Program shorter=binary_program(0,2);
    let images::Image short_image=switch(binary_image()){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Program b=switch(attach(ref shorter,short_image)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(run_zero(ref b,0,1000000)){case .ok(v):{assert(v.value==7);}case .err(_):{assert(false);}};
    var ir::Program empty=binary_program(6,6);let usize left=nth_opcode(ref empty.body,69,0);
    empty.body.code[left*8+4]=6;empty.body.code[left*8+6]=6;
    let images::Image empty_image=switch(binary_image()){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Program c=switch(attach(ref empty,empty_image)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(run_zero(ref c,0,1000000)){case .ok(v):{assert(v.value==42);}case .err(_):{assert(false);}};
}
@test fn void equality_can_compare_explicit_bytes_views_and_text_backing(){
    let ir::Program unit=equality_program(3,3,1,2);
    let images::Image backing=switch(mixed_image()){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Program p=switch(attach(ref unit,backing)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(run_zero(ref p,0,1000000)){case .ok(v):{assert(v.value==42);}case .err(_):{assert(false);}};
}
@test fn void byte_equality_precharges_both_selected_lengths_before_publication(){
    let ir::Program unit=binary_program(3,6);
    let images::Image image=switch(binary_image()){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let statics::Sites sites=switch(verifier::inspect_statics(ref unit.body,ref image)){
        case .ok(v):{v}case .err(_):{assert(false);statics::empty()}
    };
    let usize pc=nth_opcode(ref unit.body,73,0);let usize dst=unit.body.code[pc*8+1] as usize;
    var i64[128] registers=[99;128];let ref u8[] payload=images::payload(ref image);
    switch(static_vm::step(ref unit.body,ref sites,payload,pc,0,ref mut registers,3,21)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}
    };
    assert(registers[dst]==99);
    switch(static_vm::step(ref unit.body,ref sites,payload,pc,0,ref mut registers,3,22)){
        case .ok(v):{assert(v.live==3 && v.remaining==0 && registers[dst]==1);}case .err(_):{assert(false);}
    };
}

fn ir::Program alias_program(u8 mode){
    var ordinary_ir::Program p=ordinary_ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize index=index_zero(ref mut p);
    let usize root=open_site(ref mut p,0,0,if(mode==0){1}else{2},0,if(mode==0){1}else{3});
    let usize first=if(mode==2){built(static_builders::bytes(ref mut p,0,0))}
        else{built(static_builders::alias(ref mut p,0,0))};
    assert(first==1);let usize close_root=close_site(ref mut p,0);
    let usize second=if(mode==1){built(static_builders::bytes(ref mut p,first,0))}
        else{built(static_builders::alias(ref mut p,first,0))};
    assert(second==2);let usize close_first=close_site(ref mut p,first);
    let usize byte=fresh(ref mut p,10);let usize read=read_site(ref mut p,byte,second,index);
    let usize result=built(ordinary_ir::widen(ref mut p,byte,1,0));
    let usize close_second=close_site(ref mut p,second);
    let usize done=returned(ref mut p,result);function_end(ref mut p,0);
    return ir::Program{.body=p,.elements=[0;16],.parameters=[0;16]};
}
@test fn void aliases_keep_bytes_text_and_converted_bytes_after_parent_close(){
    let ir::Program raw=alias_program(0);
    let programs::Program a=switch(one_kept(ref raw,42)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let usize exact=runtime::cost()+runtime::leave_cost()+75;
    switch(run_zero(ref a,0,exact)){case .ok(v):{assert(v.value==42 && v.remaining==0);}case .err(_):{assert(false);}};
    switch(run_zero(ref a,0,exact-1)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(run_zero(ref a,0,exact+1)){case .ok(v):{assert(v.value==42 && v.remaining==1);}case .err(_):{assert(false);}};
    let u8[3] korean=[237,149,156];
    let ir::Program text=alias_program(1);
    let images::Image image=switch(text_image(ref korean)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Program b=switch(attach(ref text,image)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(run_zero(ref b,0,exact)){case .ok(v):{assert(v.value==237 && v.remaining==0);}case .err(_):{assert(false);}};
    let ir::Program converted=alias_program(2);
    let images::Image backing=switch(text_image(ref korean)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let programs::Program c=switch(attach(ref converted,backing)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(run_zero(ref c,0,exact)){case .ok(v):{assert(v.value==237 && v.remaining==0);}case .err(_):{assert(false);}};
    assert(content(ref b,0,ref korean) && content(ref c,0,ref korean));
}
@test fn void alias_preflight_keeps_source_live_and_publishes_only_after_full_fuel(){
    let ir::Program unit=alias_program(0);
    let images::Image image=switch(one_image(42)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let statics::Sites sites=switch(verifier::inspect_statics(ref unit.body,ref image)){
        case .ok(v):{v}case .err(_):{assert(false);statics::empty()}
    };
    let usize pc=nth_opcode(ref unit.body,75,0);var i64[128] registers=[99;128];
    let ref u8[] payload=images::payload(ref image);
    switch(static_vm::step(ref unit.body,ref sites,payload,pc,0,ref mut registers,1,15)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}
    };
    assert(registers[0]==99);
    switch(static_vm::step(ref unit.body,ref sites,payload,pc,0,ref mut registers,1,16)){
        case .ok(v):{assert(v.live==3 && v.remaining==0 && registers[0]==99);}case .err(_):{assert(false);}
    };
}
