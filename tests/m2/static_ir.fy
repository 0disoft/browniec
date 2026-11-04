module tests::m2::static_ir;
import ir as ir;
import errors as errors;
import static_image as images;
import verifier as verifier;
import static_ir as statics;

fn usize built(Result<usize,errors::Error> result){
    return switch(result){case .ok(value):{value}case .err(_):{assert(false);0}};
}
fn usize fresh(ref mut ir::Program p,u8 tag){
    let usize register=p.registers;p.types[register]=tag;p.registers+=1;return register;
}
fn usize index_zero(ref mut ir::Program p){return built(ir::integer(p,0,12,0));}
fn usize open_site(ref mut ir::Program p,usize site,usize literal,u8 kind,u8 start,u8 end){
    let usize pc=built(ir::raw(p,69,site,literal,0,0));
    p.code[pc*8+3]=kind;p.code[pc*8+4]=start;p.code[pc*8+5]=0;
    p.code[pc*8+6]=end;p.code[pc*8+7]=0;return site;
}
fn usize close_site(ref mut ir::Program p,usize site){return built(ir::raw(p,70,site,0,0,0));}
fn usize read_site(ref mut ir::Program p,usize dst,usize site,usize index){
    return built(ir::raw(p,71,dst,site,index,0));
}
fn usize length_site(ref mut ir::Program p,usize dst,usize site){
    return built(ir::raw(p,72,dst,site,0,0));
}
fn usize equal_sites(ref mut ir::Program p,usize dst,usize a,usize b){
    return built(ir::raw(p,73,dst,a,b,0));
}
fn usize bytes_site(ref mut ir::Program p,usize dst,usize text){
    return built(ir::raw(p,74,dst,text,0,0));
}
fn usize answer(ref mut ir::Program p){
    let usize value=built(ir::literal(p,42,0));
    return built(ir::emit(p,8,value,0,0));
}
fn void end_function(ref mut ir::Program p,usize f){
    let usize end=p.count;let usize registers=p.registers;let usize functions=p.function_count;
    p.ends[f]=end;p.register_ends[f]=registers;
    if(f+1<functions){p.starts[f+1]=end;p.register_starts[f+1]=registers;}
}
fn usize nth_opcode(ref ir::Program p,u8 op,usize nth){
    var usize pc=0;var usize seen=0;
    while(pc<p.count){
        if(p.code[pc*8]==op){if(seen==nth){return pc;}seen+=1;}
        pc+=1;
    }
    assert(false);return 0;
}
fn Result<images::Image,images::Error> fixture_image(){
    var images::Builder b=images::builder(4096)?;
    let u8[1] byte_a=[65];let u8[3] han=[237,149,156];let u8[4] mixed=[65,237,149,156];
    let usize byte_id=images::intern_bytes(ref mut b,ref byte_a)?;
    let usize han_id=images::intern_text(ref mut b,ref han)?;
    let usize empty_id=images::intern_text(ref mut b,b"")?;
    let usize mixed_id=images::intern_text(ref mut b,ref mixed)?;
    assert(byte_id==0 && han_id==1 && empty_id==2 && mixed_id==3);
    return images::freeze(ref b,8192);
}
fn void accepted(ref ir::Program p,ref images::Image image){
    switch(verifier::inspect_statics(p,image)){
        case .ok(_):{}
        case .err(_):{assert(false);}
    };
}
fn void rejected_at(ref ir::Program p,ref images::Image image,usize pc){
    switch(verifier::inspect_statics(p,image)){
        case .ok(_):{assert(false);}
        case .err(error):{assert(error.kind==5 && error.offset==pc);}
    };
}
fn void plain_inspect_rejected_at(ref ir::Program p,usize pc){
    switch(verifier::inspect(p)){
        case .ok(_):{assert(false);}
        case .err(error):{assert(error.kind==5 && error.offset==pc);}
    };
}
fn void plain_verify_rejected_at(ref ir::Program p,usize pc){
    switch(verifier::verify(p)){
        case .ok(_):{assert(false);}
        case .err(error):{assert(error.kind==5 && error.offset==pc);}
    };
}

fn ir::Program rich_program(){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize index=index_zero(ref mut p);
    let usize site_a=open_site(ref mut p,0,0,1,0,1);
    let usize site_han=open_site(ref mut p,1,1,2,0,3);
    let usize site_empty=open_site(ref mut p,2,2,2,0,0);
    let usize site_empty_han=open_site(ref mut p,3,1,2,0,0);
    let usize site_mixed_han=open_site(ref mut p,4,3,2,1,4);
    let usize equal_han=fresh(ref mut p,2);
    let usize han_eq=equal_sites(ref mut p,equal_han,site_han,site_mixed_han);
    let usize equal_empty=fresh(ref mut p,2);
    let usize empty_eq=equal_sites(ref mut p,equal_empty,site_empty,site_empty_han);
    let usize first_byte=fresh(ref mut p,10);
    let usize read_a=read_site(ref mut p,first_byte,site_a,index);
    let usize first_length=fresh(ref mut p,12);
    let usize len_a=length_site(ref mut p,first_length,site_a);
    let usize bytes_han=bytes_site(ref mut p,5,site_han);
    let usize close_han=close_site(ref mut p,site_han);
    let usize view_byte=fresh(ref mut p,10);
    let usize read_view=read_site(ref mut p,view_byte,5,index);
    let usize view_length=fresh(ref mut p,12);
    let usize len_view=length_site(ref mut p,view_length,5);
    let usize bytes_empty=bytes_site(ref mut p,6,site_empty);
    let usize close_empty=close_site(ref mut p,site_empty);
    let usize empty_length=fresh(ref mut p,12);
    let usize len_empty=length_site(ref mut p,empty_length,6);
    let usize close_a=close_site(ref mut p,site_a);
    let usize close_empty_han=close_site(ref mut p,site_empty_han);
    let usize close_mixed=close_site(ref mut p,site_mixed_han);
    let usize close_view=close_site(ref mut p,5);
    let usize close_empty_view=close_site(ref mut p,6);
    let usize returned=answer(ref mut p);end_function(ref mut p,0);return p;
}

@test
fn void scalar_reads_lengths_text_equality_and_detached_bytes_views_verify(){
    let images::Image image=switch(fixture_image()){case .ok(value):{value}case .err(_):{assert(false);return;}};
    let ir::Program p=rich_program();accepted(ref p,ref image);
    let statics::Sites sites=switch(verifier::inspect_statics(ref p,ref image)){
        case .ok(value):{value}case .err(_):{assert(false);statics::empty()}
    };
    assert(sites.count==7 && sites.starts[0]==0 && sites.starts[1]==1 && sites.starts[2]==4);
    assert(sites.starts[3]==1 && sites.starts[4]==5 && sites.starts[5]==1 && sites.starts[6]==4);
}

@test
fn void malformed_static_operands_and_reserved_bytes_are_rejected(){
    let images::Image image=switch(fixture_image()){case .ok(value):{value}case .err(_):{assert(false);return;}};
    var p=rich_program();var usize close=nth_opcode(ref p,70,0);p.code[close*8+2]=1;
    rejected_at(ref p,ref image,close);
    p=rich_program();close=nth_opcode(ref p,70,0);p.code[close*8+4]=1;
    rejected_at(ref p,ref image,close);
    p=rich_program();let usize read=nth_opcode(ref p,71,0);p.code[read*8+4]=1;
    rejected_at(ref p,ref image,read);
    p=rich_program();let usize length=nth_opcode(ref p,72,0);p.code[length*8+3]=1;
    rejected_at(ref p,ref image,length);
    p=rich_program();let usize equal=nth_opcode(ref p,73,0);p.code[equal*8+5]=1;
    rejected_at(ref p,ref image,equal);
    p=rich_program();let usize bytes=nth_opcode(ref p,74,0);p.code[bytes*8+6]=1;
    rejected_at(ref p,ref image,bytes);
    p=rich_program();let usize open=nth_opcode(ref p,69,0);p.code[open*8+3]=3;
    rejected_at(ref p,ref image,open);
}

@test
fn void forged_literal_kind_bounds_and_text_boundaries_are_rejected(){
    let images::Image image=switch(fixture_image()){case .ok(value):{value}case .err(_):{assert(false);return;}};
    var p=rich_program();var usize open=nth_opcode(ref p,69,0);p.code[open*8+2]=4;
    rejected_at(ref p,ref image,open);
    p=rich_program();open=nth_opcode(ref p,69,0);p.code[open*8+2]=255;
    rejected_at(ref p,ref image,open);
    p=rich_program();open=nth_opcode(ref p,69,0);p.code[open*8+6]=255;p.code[open*8+7]=255;
    rejected_at(ref p,ref image,open);
    p=rich_program();open=nth_opcode(ref p,69,0);p.code[open*8+2]=1;p.code[open*8+3]=1;
    rejected_at(ref p,ref image,open);
    p=rich_program();open=nth_opcode(ref p,69,0);p.code[open*8+3]=2;
    rejected_at(ref p,ref image,open);
    p=rich_program();open=nth_opcode(ref p,69,0);p.code[open*8+2]=1;p.code[open*8+3]=2;p.code[open*8+4]=0;p.code[open*8+6]=4;
    rejected_at(ref p,ref image,open);
    p=rich_program();open=nth_opcode(ref p,69,0);p.code[open*8+2]=1;p.code[open*8+3]=2;p.code[open*8+4]=2;p.code[open*8+6]=1;
    rejected_at(ref p,ref image,open);
    p=rich_program();open=nth_opcode(ref p,69,0);p.code[open*8+2]=1;p.code[open*8+3]=2;p.code[open*8+4]=0;p.code[open*8+6]=2;
    rejected_at(ref p,ref image,open);
    p=rich_program();open=nth_opcode(ref p,69,0);p.code[open*8+2]=1;p.code[open*8+3]=2;p.code[open*8+4]=1;p.code[open*8+6]=3;
    rejected_at(ref p,ref image,open);
}

fn ir::Program after_close_program(){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize index=index_zero(ref mut p);
    let usize open=open_site(ref mut p,0,0,1,0,1);let usize close=close_site(ref mut p,0);
    let usize dst=fresh(ref mut p,10);let usize read=read_site(ref mut p,dst,0,index);
    let usize returned=answer(ref mut p);end_function(ref mut p,0);return p;
}
fn ir::Program duplicate_site_program(){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize first=open_site(ref mut p,0,0,1,0,1);let usize second=open_site(ref mut p,0,0,1,0,1);
    let usize close=close_site(ref mut p,0);let usize returned=answer(ref mut p);
    end_function(ref mut p,0);return p;
}
fn ir::Program cross_function_program(){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=0;p.return_types[0]=1;p.return_types[1]=1;
    let usize open=open_site(ref mut p,0,0,1,0,1);let usize close=close_site(ref mut p,0);
    let usize first=answer(ref mut p);end_function(ref mut p,0);
    let usize index=index_zero(ref mut p);let usize dst=fresh(ref mut p,10);
    let usize read=read_site(ref mut p,dst,0,index);let usize returned=answer(ref mut p);
    end_function(ref mut p,1);return p;
}
fn ir::Program many_sites(bool extra){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    var usize site=0;while(site<16){let usize opened=open_site(ref mut p,site,0,1,0,1);
        let usize closed=close_site(ref mut p,site);site+=1;}
    if(extra){let usize overflow=open_site(ref mut p,16,0,1,0,1);}
    let usize returned=answer(ref mut p);end_function(ref mut p,0);return p;
}
fn ir::Program exception_program(){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize marker=built(ir::literal(ref mut p,1,0));
    let usize open=open_site(ref mut p,0,0,1,0,1);
    let usize failure=built(ir::raw(ref mut p,25,0,0,0,0));
    end_function(ref mut p,0);return p;
}
@test
fn void site_lifetime_duplicates_namespace_limits_and_exception_aborts_are_distinct(){
    let images::Image image=switch(fixture_image()){case .ok(value):{value}case .err(_):{assert(false);return;}};
    var p=after_close_program();var usize read=nth_opcode(ref p,71,0);rejected_at(ref p,ref image,read);
    p=duplicate_site_program();let usize second=nth_opcode(ref p,69,1);rejected_at(ref p,ref image,second);
    p=cross_function_program();read=nth_opcode(ref p,71,0);rejected_at(ref p,ref image,read);
    p=many_sites(false);accepted(ref p,ref image);
    p=many_sites(true);let usize overflow=nth_opcode(ref p,69,16);rejected_at(ref p,ref image,overflow);
    p=exception_program();accepted(ref p,ref image);
}

@test
fn void invalid_destinations_indices_and_uninitialized_scalars_are_rejected(){
    let images::Image image=switch(fixture_image()){case .ok(value):{value}case .err(_):{assert(false);return;}};
    var p=rich_program();var usize read=nth_opcode(ref p,71,0);let usize read_dst=p.code[read*8+1] as usize;
    p.types[read_dst]=12;rejected_at(ref p,ref image,read);
    p=rich_program();read=nth_opcode(ref p,71,0);p.code[read*8+1]=127;rejected_at(ref p,ref image,read);
    p=rich_program();read=nth_opcode(ref p,71,0);let usize read_index=p.code[read*8+3] as usize;
    p.types[read_index]=10;rejected_at(ref p,ref image,read);
    p=rich_program();read=nth_opcode(ref p,71,0);var usize length=nth_opcode(ref p,72,0);
    let u8 later=p.code[length*8+1];p.code[read*8+3]=later;rejected_at(ref p,ref image,read);
    p=rich_program();length=nth_opcode(ref p,72,0);let usize length_dst=p.code[length*8+1] as usize;
    p.types[length_dst]=10;rejected_at(ref p,ref image,length);
    p=rich_program();let usize equal=nth_opcode(ref p,73,0);let usize equal_dst=p.code[equal*8+1] as usize;
    p.types[equal_dst]=1;rejected_at(ref p,ref image,equal);
    p=rich_program();read=nth_opcode(ref p,71,1);
    let usize first=nth_opcode(ref p,71,0);let u8 prior=p.code[first*8+1];
    p.code[read*8+1]=prior;rejected_at(ref p,ref image,read);
    p=rich_program();p.registers=129;rejected_at(ref p,ref image,0);
}

fn ir::Program ordinary_site_program(){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize root=built(ir::array_in(ref mut p,0,10,1,true,0));
    let usize slice=built(ir::exclusive_slice(ref mut p,root,0));
    let usize fill=built(ir::integer(ref mut p,65,10,0));
    let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0));let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize opened=built(ir::slice_open(ref mut p,slice,lo,hi,0));
    let usize static_site=open_site(ref mut p,0,0,1,0,1);
    let usize index=index_zero(ref mut p);let usize dst=fresh(ref mut p,10);
    let usize read=read_site(ref mut p,dst,static_site,index);
    let usize close_static=close_site(ref mut p,static_site);
    let usize close_slice=built(ir::slice_close(ref mut p,slice,0));
    let usize drop=built(ir::array_drop(ref mut p,root,0));
    let usize returned=answer(ref mut p);end_function(ref mut p,0);return p;
}
@test
fn void static_and_ordinary_array_and_slice_site_zero_keep_separate_liveness(){
    let images::Image image=switch(fixture_image()){case .ok(value):{value}case .err(_):{assert(false);return;}};
    let ir::Program p=ordinary_site_program();accepted(ref p,ref image);
}

fn ir::Program forward_join_mismatch_program(){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize condition=built(ir::boolean(ref mut p,true,0));
    let usize open=open_site(ref mut p,0,0,1,0,1);
    let usize branch=built(ir::raw(ref mut p,20,0,condition,0,0));
    let usize close=close_site(ref mut p,0);
    let usize jump=built(ir::raw(ref mut p,19,0,0,0,0));let usize join=p.count;
    let usize returned=answer(ref mut p);
    let usize patched_branch=built(ir::patch(ref mut p,branch,join,0));
    let usize patched_jump=built(ir::patch(ref mut p,jump,join,0));
    end_function(ref mut p,0);return p;
}
fn ir::Program balanced_loop_program(){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize condition=built(ir::boolean(ref mut p,false,0));
    let usize head=p.count;let usize open=open_site(ref mut p,0,0,1,0,1);
    let usize close=close_site(ref mut p,0);
    let usize branch=built(ir::raw(ref mut p,20,0,condition,0,0));
    let usize back=built(ir::raw(ref mut p,22,0,head,0,0));
    let usize leave=p.count;let usize returned=answer(ref mut p);
    let usize patched=built(ir::patch(ref mut p,branch,leave,0));
    end_function(ref mut p,0);return p;
}
fn ir::Program backedge_mismatch_program(){
    var ir::Program p=ir::empty();p.function_count=1;p.entry=0;p.return_types[0]=1;
    let usize marker=built(ir::literal(ref mut p,1,0));
    let usize open=open_site(ref mut p,0,0,1,0,1);
    let usize back=built(ir::raw(ref mut p,22,0,open,0,0));
    end_function(ref mut p,0);return p;
}
@test
fn void forward_join_and_backedge_compare_the_private_static_live_mask(){
    let images::Image image=switch(fixture_image()){case .ok(value):{value}case .err(_):{assert(false);return;}};
    var p=balanced_loop_program();accepted(ref p,ref image);
    p=forward_join_mismatch_program();let usize jump=nth_opcode(ref p,19,0);
    rejected_at(ref p,ref image,jump);
    p=backedge_mismatch_program();let usize back=nth_opcode(ref p,22,0);
    rejected_at(ref p,ref image,back);
}

@test
fn void ordinary_inspect_and_verify_still_reject_static_opcodes(){
    let images::Image image=switch(fixture_image()){case .ok(value):{value}case .err(_):{assert(false);return;}};
    let ir::Program p=rich_program();let usize open=nth_opcode(ref p,69,0);
    accepted(ref p,ref image);
    plain_inspect_rejected_at(ref p,open);
    plain_verify_rejected_at(ref p,open);
}

@test fn void equality_accepts_live_byte_operands_without_weakening_site_proof(){
    let images::Image image=switch(fixture_image()){case .ok(v):{v}case .err(_):{assert(false);return;}};
    var ir::Program p=rich_program();let usize equal=nth_opcode(ref p,73,0);
    p.code[equal*8+2]=0;p.code[equal*8+3]=0;accepted(ref p,ref image);
    p=rich_program();p.code[equal*8+2]=0;accepted(ref p,ref image);
    p=rich_program();p.code[equal*8+3]=0;accepted(ref p,ref image);
    p=rich_program();p.code[equal*8+2]=255;rejected_at(ref p,ref image,equal);
    p=rich_program();p.code[equal*8+2]=5;rejected_at(ref p,ref image,equal);
    p=rich_program();p.code[equal*8]=70;p.code[equal*8+1]=0;
    p.code[equal*8+2]=0;p.code[equal*8+3]=0;
    let usize next=nth_opcode(ref p,73,0);p.code[next*8+2]=0;
    rejected_at(ref p,ref image,next);
}
