module tests::m2::slice_reborrow_order;
import slice_reborrow as reborrow;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import ir as ir;
import errors as errors;
import slice_builders as builders;
import slice_reborrow_ir as loans;
import slice_authority as authority;
import register_set as registers;
import verifier as verifier;
import vm as vm;

fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn usize size(Result<usize,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn i64 cell(Result<i64,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn owners::Token create(ref mut owners::Table table,u8 tag,usize n,ref mut u8[] data){
    let layouts::Array shape=switch(layouts::scalar(tag,n)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=10,.length=1,.stride=1,.alignment=1,.bytes=1}}};
    return switch(owners::create(ref shape,0,data,table)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn void same_view(owners::View a,owners::View b){assert(a.root.slot==b.root.slot && a.root.generation==b.root.generation && a.element==b.element && a.length==b.length && a.start==b.start && a.end==b.end);}
fn void same_pool(ref slices::Pool a,ref slices::Pool b){var usize i=0;while(i<16){let slices::Slot x=a.slots[i];let slices::Slot y=b.slots[i];assert(x.generation==y.generation && x.live==y.live && x.exclusive==y.exclusive && x.lease.root.slot==y.lease.root.slot && x.lease.root.generation==y.lease.root.generation && x.lease.generation==y.lease.generation);same_view(x.view,y.view);i+=1;}}
fn void same_owners(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];assert(a.order[i]==b.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live && x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation && x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment);i+=1;}
}

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void finish(ref mut ir::Program p,usize f){let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;}
fn usize pc(ref ir::Program p,u8 op){var usize i=p.starts[0];while(i<p.ends[0] && p.code[i*8]!=op){i+=1;}assert(i<p.ends[0]);return i;}
fn void accepted(ref ir::Program p){assert(verifier::inspect(p).is_ok);assert(switch(verifier::verify(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});assert(switch(vm::run_with_array_limit(p,0,65537)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==0}});}
fn void rejected(ref ir::Program p){assert(!verifier::inspect(p).is_ok && !verifier::verify(p).is_ok);}
fn void rejected_at(ref ir::Program p,usize at){assert(switch(verifier::inspect(p)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==at}});rejected(p);}
fn void skip(ref mut ir::Program p,usize at){p.code[at*8]=19;p.code[at*8+1]=0;p.code[at*8+3]=0;p.code[at*8+4]=0;let usize done=built(ir::patch(p,at,at+1,77));}

fn loans::Sites mapping(ref ir::Program p){return switch(loans::metadata(p)){case .ok(v):{v}case .err(_):{assert(false);loans::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};}
// mode0: reverse close; 1: crossing close; 2: balanced loop; 3: skip whole
// lifetime; 4: skip only the younger child; 6: highest site bit, ascending IDs.
fn ir::Program program(u8 tag,bool formal,usize mode){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=1;p.return_types[1]=1;
    var usize ra=16;var usize rb=16;var usize a=16;var usize b=16;
    if(formal){p.arities[0]=2;a=built(builders::parameter_exclusive(ref mut p,0,tag,77));b=built(builders::parameter_exclusive(ref mut p,0,tag,77));}
    else{ra=built(ir::array_in(ref mut p,0,tag,2,true,77));rb=built(ir::array_in(ref mut p,0,tag,2,true,77));a=built(ir::exclusive_slice(ref mut p,ra,77));b=built(ir::exclusive_slice(ref mut p,rb,77));let usize fill=built(if(tag==2){ir::boolean(ref mut p,false,77)}else{ir::integer(ref mut p,0,tag,77)});let usize ia=built(ir::array_init(ref mut p,ra,fill,77));let usize ib=built(ir::array_init(ref mut p,rb,fill,77));}
    let usize lo=built(ir::integer(ref mut p,0,12,77));let usize hi=built(ir::integer(ref mut p,1,12,77));let usize cond=built(ir::boolean(ref mut p,true,77));
    if(!formal){let usize oa=built(ir::slice_open(ref mut p,a,lo,hi,77));let usize ob=built(ir::slice_open(ref mut p,b,lo,hi,77));}
    var usize ca=16;var usize cb=16;
    if(mode==6){var usize i=0;while(i<12){let usize unused=built(ir::exclusive_slice(ref mut p,ra,77));i+=1;}ca=built(loans::derived(ref mut p,a,77));cb=built(loans::derived(ref mut p,b,77));}
    else{cb=built(loans::derived(ref mut p,b,77));ca=built(loans::derived(ref mut p,a,77));}
    let usize branch=built(ir::raw(ref mut p,if(mode==3){20}else{19},0,if(mode==3){cond}else{0},0,77));let usize next=branch+1;let usize patched=built(ir::patch(ref mut p,branch,next,77));
    let usize start=p.count;let usize ba=built(loans::begin(ref mut p,ca,a,lo,hi,77));
    var usize inner_branch=256;if(mode==4){inner_branch=built(ir::raw(ref mut p,20,0,cond,0,77));}
    let usize bb=built(loans::begin(ref mut p,cb,b,lo,hi,77));let usize la=built(ir::slice_length(ref mut p,ca,77));let usize lb=built(ir::slice_length(ref mut p,cb,77));
    let usize eb=built(loans::end(ref mut p,if(mode==1){ca}else{cb},if(mode==1){a}else{b},77));
    if(mode==4){let usize target=p.count;let usize patch=built(ir::patch(ref mut p,inner_branch,target,77));}
    let usize ea=built(loans::end(ref mut p,if(mode==1){cb}else{ca},if(mode==1){b}else{a},77));
    if(mode==3){let usize target=p.count;let usize patch=built(ir::patch(ref mut p,branch,target,77));}
    if(mode==2){let usize exit=built(ir::raw(ref mut p,20,0,cond,0,77));let usize back=built(ir::raw(ref mut p,22,0,start,0,77));let usize target=p.count;let usize patch=built(ir::patch(ref mut p,exit,target,77));}
    let usize cla=built(ir::slice_close(ref mut p,a,77));let usize clb=built(ir::slice_close(ref mut p,b,77));if(!formal){let usize db=built(ir::array_drop(ref mut p,rb,77));let usize da=built(ir::array_drop(ref mut p,ra,77));}
    let usize answer=built(ir::literal(ref mut p,42,77));let usize ret=built(ir::emit(ref mut p,8,answer,0,77));finish(ref mut p,0);
    let usize start1=p.count;let usize regs=p.registers;p.starts[1]=start1;p.register_starts[1]=regs;let usize done=built(ir::literal(ref mut p,42,77));let usize returned=built(ir::emit(ref mut p,8,done,0,77));finish(ref mut p,1);return p;
}
@test
fn void six_scalar_owned_and_formal_independent_roots_restore_in_reverse_creation_order(){
    let u8[6] tags=[1,2,9,10,11,12];var usize i=0;while(i<6){let ir::Program owned=program(tags[i],false,0);let ir::Program formal=program(tags[i],true,0);accepted(ref owned);accepted(ref formal);let ir::Program crossing=program(tags[i],false,1);let ir::Program formal_crossing=program(tags[i],true,1);rejected_at(ref crossing,pc(ref crossing,62));rejected_at(ref formal_crossing,pc(ref formal_crossing,62));i+=1;}
}
@test
fn void balanced_repeated_and_conditional_lifetimes_keep_a_unique_stack_at_every_join(){
    var usize mode=2;while(mode<=4){let ir::Program owned=program(10,false,mode);let ir::Program formal=program(10,true,mode);accepted(ref owned);accepted(ref formal);mode+=1;}
}
@test
fn void branches_and_backedges_cannot_skip_restoration_or_merge_different_pending_stacks(){
    var ir::Program bad=program(10,true,3);let usize branch=pc(ref bad,20);let usize end=pc(ref bad,62);let usize patch=built(ir::patch(ref mut bad,branch,end,77));rejected(ref bad);
    bad=program(10,true,2);let usize first=pc(ref bad,62);skip(ref mut bad,first);rejected(ref bad);
    bad=program(10,false,4);let usize inner=pc(ref bad,20);let usize close=pc(ref bad,56);let usize mismatch=built(ir::patch(ref mut bad,inner,close,77));rejected(ref bad);
}
@test
fn void immutable_creation_rank_does_not_follow_site_ids_and_counts_suspended_children(){
    let ir::Program p=program(10,true,0);let loans::Sites sites=mapping(ref p);let usize first=pc(ref p,61);let usize one=1;assert(p.code[first*8+1]==3 && sites.newer[3]==(one<<2) && sites.newer[2]==0 && sites.count==2);
    var registers::Set defined=registers::empty();var registers::Set written=registers::empty();registers::insert(ref mut defined,p.code[first*8+3] as usize);registers::insert(ref mut defined,p.code[first*8+4] as usize);
    let usize base=(one<<32)|(one<<33);assert(loans::step(ref p,ref sites,first,0,ref mut defined,ref mut written,base).is_ok);
    let usize younger=(one<<32)|(one<<34)|(one<<49);assert(!loans::step(ref p,ref sites,first,0,ref mut defined,ref mut written,younger).is_ok);
    // Synthetic state exercises the suspended-derived portion of the mask too.
    let usize suspended=(one<<32)|(one<<49)|(one<<50);assert(!loans::step(ref p,ref sites,first,0,ref mut defined,ref mut written,suspended).is_ok);
}
@test
fn void highest_child_site_bit_participates_and_reserved_unused_sites_do_not(){
    let ir::Program p=program(10,false,6);accepted(ref p);let loans::Sites sites=mapping(ref p);let usize one=1;assert(sites.parents[14]==0 && sites.parents[15]==1 && sites.newer[14]==(one<<15) && sites.newer[15]==0 && sites.newer[13]==0);
    var ir::Program bad=p;let usize end=pc(ref bad,62);bad.code[end*8+1]=14;bad.code[end*8+2]=0;bad.code[(end+1)*8+1]=15;bad.code[(end+1)*8+2]=1;rejected_at(ref bad,end);
}
@test
fn void independent_native_receipts_and_ir_agree_on_wrong_then_reverse_restoration(){
    let ir::Program p=program(10,false,0);let ir::Program bad=program(10,false,1);accepted(ref p);rejected_at(ref bad,pc(ref bad,62));
    var u8[8] data=[0;8];var owners::Table table=owners::empty(8);var slices::Pool pool=slices::empty();var authority::State state=authority::empty();let owners::Token a=create(ref mut table,10,1,ref mut data);let owners::Token b=create(ref mut table,10,1,ref mut data);let slices::Ticket x=ticket(slices::open_exclusive(ref mut pool,ref mut table,a,0,1,8));let slices::Ticket y=ticket(slices::open_exclusive(ref mut pool,ref mut table,b,0,1,8));
    let slices::Ticket cx=ticket(authority::enter_child(ref mut state,ref mut pool,x,ref table,0,1,8,0));let slices::Ticket cy=ticket(authority::enter_child(ref mut state,ref mut pool,y,ref table,0,1,8,0));let slices::Pool saved=pool;let owners::Table before=table;assert(!authority::leave_child(ref mut state,ref mut pool,cx,ref table,8,0).is_ok && state.depth==2 && state.frame==0);same_pool(ref pool,ref saved);same_owners(ref table,ref before);
    let slices::Ticket ry=ticket(authority::leave_child(ref mut state,ref mut pool,cy,ref table,8,0));let slices::Ticket rx=ticket(authority::leave_child(ref mut state,ref mut pool,cx,ref table,8,0));assert(state.depth==0 && state.frame==0 && slices::close(ref mut pool,ry,ref mut table,8).is_ok && slices::close(ref mut pool,rx,ref mut table,8).is_ok);
}
