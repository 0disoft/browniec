module tests::m2::slice_array_result_authority;
import ir as ir;
import errors as errors;
import verifier as verifier;
import compiler as compiler;
import vm_reborrow_execution as runner;
import vm_execution as execution;
import slice_reborrow_ir as proof;
import slice_authority as authority;
import slice_authority_call_vm as calls;
import slice_reborrow_vm as children;
import slice_reborrow_context as context;
import slice_vm as loans;
import slice_call_vm as shared;
import array_vm as arrays;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import struct_vm as records;
import array_result_vm as results;
import call_frame_vm as control;
import std::bytes as bytes;
fn usize built(Result<usize,errors::Error> r) {
    return switch(r) {case .ok(n):{n} case .err(_):{assert(false);0}};
}
fn void finish(ref mut ir::Program p,usize f) {
    let usize end=p.count;let usize regs=p.registers;p.ends[f]=end;p.register_ends[f]=regs;
}
fn layouts::Array shape(u8 tag,usize length) {
    return switch(layouts::scalar(tag,length)) {
        case .ok(a):{a} case .err(_):{assert(false);layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}
    };
}
fn bytes::Buffer buffer(usize capacity) {
    return switch(arrays::prepare(capacity)) {case .ok(b):{b} case .err(_):{assert(false);bytes::empty()}};
}
fn owners::Token create(ref mut arrays::State state,ref mut bytes::Buffer data,u8 tag,usize length,i64 fill) {
    let layouts::Array a=shape(tag,length);
    return switch(owners::create(ref a,fill,bytes::view_mut(data),ref mut state.owners)) {
        case .ok(t):{t} case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}
    };
}
fn ir::Program program(u8 tag,i64 fill,usize length,usize repetitions) {
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=tag;p.return_types[1]=1;
    let usize source=built(ir::array_in(ref mut p,0,tag,length,true,0));p.array_results[0]=1;
    let usize value=if(tag==2){built(ir::boolean(ref mut p,fill==1,0))}else{built(ir::integer(ref mut p,fill,tag,0))};
    let usize init=built(ir::array_init(ref mut p,source,value,0));
    let usize ret=built(ir::array_return(ref mut p,source,73));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize destination=built(ir::array_in(ref mut p,1,tag,length,false,0));
    let usize index=built(ir::integer(ref mut p,0,12,0));
    let usize expected=if(tag==2){built(ir::boolean(ref mut p,fill==1,0))}else{built(ir::integer(ref mut p,fill,tag,0))};
    var usize i=0;
    while(i<repetitions) {
        let usize[1] args=[0;1];let usize called=built(ir::array_call(ref mut p,0,destination,ref args[..0],0));
        let usize actual=built(ir::array_read(ref mut p,destination,index,0));
        let usize equal=built(ir::emit(ref mut p,11,actual,expected,0));
        let usize jump=built(ir::raw(ref mut p,21,0,equal,0,0));
        let usize fail=built(ir::raw(ref mut p,25,0,0,0,0));
        let usize after=p.count;let usize patched=built(ir::patch(ref mut p,jump,after,0));
        let usize dropped=built(ir::array_drop(ref mut p,destination,0));i+=1;
    }
    let usize answer=built(ir::integer(ref mut p,42,1,0));
    let usize returned=built(ir::emit(ref mut p,8,answer,0,0));finish(ref mut p,1);return p;
}
fn ir::Program recursive(i64 n) {
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=1;p.return_types[1]=1;p.arities[0]=1;
    p.types[0]=1;p.registers=1;
    let usize local=built(ir::array_in(ref mut p,0,1,1,false,0));p.array_results[0]=1;
    let usize result=built(ir::array_in(ref mut p,0,1,1,false,0));
    let usize zero=built(ir::integer(ref mut p,0,1,0));let usize more=built(ir::emit(ref mut p,15,0,zero,0));
    let usize branch=built(ir::raw(ref mut p,20,0,more,0,0));
    let usize one=built(ir::integer(ref mut p,1,1,0));let usize less=built(ir::emit(ref mut p,3,0,one,0));
    let usize[1] child=[less];let usize called=built(ir::array_call(ref mut p,0,result,ref child,0));
    let usize returned=built(ir::array_return(ref mut p,result,0));
    let usize base=p.count;let usize patched=built(ir::patch(ref mut p,branch,base,0));
    let usize fill=built(ir::integer(ref mut p,42,1,0));let usize init=built(ir::array_init(ref mut p,local,fill,0));
    let usize terminal=built(ir::array_return(ref mut p,local,0));finish(ref mut p,0);
    let usize start=p.count;let usize regs=p.registers;p.starts[1]=start;p.register_starts[1]=regs;
    let usize destination=built(ir::array_in(ref mut p,1,1,1,false,0));
    let usize count=built(ir::integer(ref mut p,n,1,0));let usize[1] args=[count];
    let usize entered=built(ir::array_call(ref mut p,0,destination,ref args,0));
    let usize index=built(ir::integer(ref mut p,0,12,0));let usize actual=built(ir::array_read(ref mut p,destination,index,0));
    let usize drop=built(ir::array_drop(ref mut p,destination,0));let usize done=built(ir::emit(ref mut p,8,actual,0,0));
    finish(ref mut p,1);return p;
}

fn ir::Program owned_child_result(){
    var ir::Program p=ir::empty();p.function_count=2;p.entry=1;p.return_types[0]=10;p.return_types[1]=1;
    let usize root=built(ir::array_in(ref mut p,0,10,1,true,77));p.array_results[0]=1;
    let usize parent=built(ir::exclusive_slice(ref mut p,root,77));let usize zero=built(ir::integer(ref mut p,0,12,77));let usize one=built(ir::integer(ref mut p,1,12,77));let usize z=built(ir::integer(ref mut p,0,10,77));let usize init=built(ir::array_init(ref mut p,root,z,77));let usize opened=built(ir::slice_open(ref mut p,parent,zero,one,77));
    let usize child=built(proof::derived(ref mut p,parent,77));let usize begin=built(proof::begin(ref mut p,child,parent,zero,one,77));let usize v=built(ir::integer(ref mut p,42,10,77));let usize written=built(ir::slice_write(ref mut p,child,zero,v,77));let usize ended=built(proof::end(ref mut p,child,parent,77));let usize closed=built(ir::slice_close(ref mut p,parent,77));let usize ret=built(ir::array_return(ref mut p,root,77));finish(ref mut p,0);
    let usize at=p.count;let usize r=p.registers;p.starts[1]=at;p.register_starts[1]=r;
    let usize destination=built(ir::array_in(ref mut p,1,10,1,false,77));let usize[1] args=[0];let usize called=built(ir::array_call(ref mut p,0,destination,ref args[..0],77));let usize index=built(ir::integer(ref mut p,0,12,77));let usize actual=built(ir::array_read(ref mut p,destination,index,77));let usize result=built(ir::widen(ref mut p,actual,1,77));let usize drop=built(ir::array_drop(ref mut p,destination,77));let usize done=built(ir::emit(ref mut p,8,result,0,77));finish(ref mut p,1);return p;
}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn proof::Sites sites(ref ir::Program p){return switch(runner::inspect(p)){case .ok(s):{s}case .err(_):{assert(false);proof::Sites{.parents=[16;16],.newer=[0;16],.count=0}}};}
fn usize pc(ref ir::Program p){var usize at=p.starts[p.entry];while(at<p.ends[p.entry] && p.code[at*8]!=9){at+=1;}assert(at<p.ends[p.entry]);return at;}
fn usize returned_site(ref ir::Program p){var usize at=p.starts[0];while(at<p.ends[0] && p.code[at*8]!=39){at+=1;}assert(at<p.ends[0]);return p.code[at*8+2] as usize;}
fn Result<i64,errors::Error> execute(ref ir::Program p,usize limit,usize fuel){
    var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];
    var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(limit);var bytes::Buffer b=buffer(limit);
    let Result<i64,errors::Error> outcome=runner::execute(p,fuel,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links);
    assert(context::ready(ref auth[0],ref c[0],ref links[0],ref l,ref f).is_ok);
    if(outcome.is_ok){assert(a.owners.depth==0 && a.owners.arena.used==0);}return outcome;
}
fn void value(ref ir::Program p,usize limit,usize fuel){assert(switch(execute(p,limit,fuel)){case .ok(n):{n==42}case .err(_):{false}});}
fn void failure(ref ir::Program p,usize limit,usize fuel,u8 kind){assert(switch(execute(p,limit,fuel)){case .ok(_):{false}case .err(e):{e.kind==kind}});}
fn void run(ref u8[] source){let ir::Program p=compiled(source);value(ref p,256,20000000);}
fn slices::Ticket ticket(Result<slices::Ticket,owners::Error> result){return switch(result){case .ok(t):{t}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}};}
fn void unchanged(ref arrays::State a,ref arrays::State old){
    assert(a.owners.depth==old.owners.depth && a.owners.arena.used==old.owners.arena.used && a.owners.arena.limit==old.owners.arena.limit);
    var usize i=0;while(i<512){assert(a.tokens[i].slot==old.tokens[i].slot && a.tokens[i].generation==old.tokens[i].generation);i+=1;}
    i=0;while(i<16){let owners::Owner x=a.owners.slots[i];let owners::Owner y=old.owners.slots[i];assert(a.owners.order[i]==old.owners.order[i] && x.generation==y.generation && x.read_generation==y.read_generation && x.reading==y.reading && x.writing==y.writing && x.occupied==y.occupied && x.live==y.live && x.base==y.base && x.end==y.end && x.mark==y.mark && x.length==y.length && x.element==y.element);i+=1;}
}
@test
fn void six_tags_and_maximum_lengths_rehome_without_second_extent(){
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] fills=[-2147483648,1,-9223372036854775808,255,4294967295,-1];var usize i=0;
    while(i<6){let layouts::Array a=shape(tags[i],1);let ir::Program p=program(tags[i],fills[i],1,1);value(ref p,a.bytes,1000000);failure(ref p,a.bytes-1,1000000,13);let ir::Program large=program(tags[i],fills[i],4096,1);let layouts::Array big=shape(tags[i],4096);value(ref large,big.bytes,1000000);i+=1;}
}
@test
fn void recursion_repeated_returns_and_exact_fuel_preserve_existing_limits(){
    let ir::Program p=program(1,42,1,1);// Native caller prepared the backing; public VM additionally charges 1+4 Fuel.
    value(ref p,4,227);failure(ref p,4,226,8);failure(ref p,4,136,8);assert(built(results::cost(ref p,0,0))==65);
    let ir::Program repeat=program(1,42,1,24);value(ref repeat,4,1000000);let ir::Program deep=recursive(30);value(ref deep,4,1000000);let ir::Program over=recursive(31);failure(ref over,4,1000000,12);
}
@test
fn void source_owned_record_shared_exclusive_and_lexical_children_interleave(){
    run(b"module main;fn i32[1] id(i32[1] a){return a;}fn i32 main(){var i32[1] a=[42;1];a=id(a);return a[0];}");
    run(b"module main;struct R{i32 x;}fn i32[1] f(R r,i32[1] a,ref i32[] q,ref mut i32[] p){p[0]=r.x+a[0]+q[0];return [p[0];1];}fn i32 main(){let R r=R{.x=20};let i32[1] a=[21;1];let i32[1] b=[1;1];var i32[1] out=[0;1];let ref i32[] q=ref b;let ref mut i32[] p=ref mut out;let i32[1] result=f(r,a,ref q,ref mut p);return result[0];}");
    let ir::Program lexical=owned_child_result();assert(!verifier::verify(ref lexical).is_ok);value(ref lexical,1,1000000);
    run(b"module main;fn i32[1] f(i32 n){if(n>0){return f(n-1);}return [42;1];}fn i32 main(){let i32[1] a=f(4);return a[0];}");
}
@test
fn void failed_result_and_call_authentication_preserve_the_complete_return_state(){
    let ir::Program p=program(2,1,4,1);let proof::Sites map=sites(ref p);let usize at=pc(ref p);var usize mode=0;
    while(mode<8){var arrays::State a=arrays::empty(4);var bytes::Buffer b=buffer(4);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var authority::State auth=authority::empty();var calls::Bindings c=calls::empty();var records::State rs=records::empty();
        assert(built(calls::enter_owned(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref mut rs,ref mut b,built(calls::cost(ref p,at,0))))==0);
        let owners::Token t=create(ref mut a,ref mut b,2,4,1);a.tokens[16]=t;
        if(mode==0){a.tokens[16].generation+=1;}else if(mode==1){a.tokens[1]=t;}else if(mode==2){a.tokens[17]=t;}else if(mode==3){bytes::view_mut(ref mut b)[3]=2;}else if(mode==4){a.owners.slots[t.slot].length=2;}else if(mode==5){c.pcs[0]=256;}else if(mode==6){auth.reserves[0]+=1;}
        let arrays::State old=a;let usize saved=c.pcs[0];let usize reserve=auth.reserves[0];let usize destination=if(mode==7){0}else{1};
        assert(switch(calls::return_array(ref p,0,1,0,destination,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref rs,ref b,73)){case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==73}});
        unchanged(ref a,ref old);assert(auth.depth==1 && auth.frame==1 && auth.reserves[0]==reserve && c.pcs[0]==saved);var usize i=0;while(i<4){assert(bytes::view(ref b)[i]==if(mode==3 && i==3){2}else{1});i+=1;}mode+=1;
    }
}
@test
fn void late_restoration_failure_keeps_result_and_reader_then_success_moves_once(){
    let ir::Program p=compiled(b"module main;fn i32[1] f(ref i32[] q,ref mut i32[] p){return [42;1];}fn i32 main(){let i32[1] a=[42;1];var i32[1] b=[0;1];let ref i32[] q=ref a;let ref mut i32[] p=ref mut b;let i32[1] result=f(ref q,ref mut p);return result[0];}");let proof::Sites map=sites(ref p);let usize at=pc(ref p);let usize args=p.code[at*8+3] as usize;
    var arrays::State a=arrays::empty(64);var bytes::Buffer b=buffer(64);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var authority::State auth=authority::empty();var calls::Bindings c=calls::empty();var records::State rs=records::empty();
    var usize i=0;while(i<p.arrays.count){if(p.array_functions[i] as usize==p.entry && i!=p.code[at*8+1] as usize-128){let owners::Token root=create(ref mut a,ref mut b,1,1,42);a.tokens[i]=root;}i+=1;}
    let usize reader=(p.call_args[args*8] as usize)-160;let usize writer=(p.call_args[args*8+1] as usize)-160;
    let owners::Token read_root=a.tokens[(p.slice_roots[reader] as usize)-1];let owners::Token write_root=a.tokens[(p.slice_roots[writer] as usize)-1];
    let slices::Ticket read_ticket=ticket(slices::open(ref mut l.pool,ref mut a.owners,read_root,0,1,64));l.tickets[reader]=read_ticket;
    let slices::Ticket write_ticket=ticket(slices::open_exclusive(ref mut l.pool,ref mut a.owners,write_root,0,1,64));l.tickets[writer]=write_ticket;let slices::Ticket original_reader=l.tickets[reader];
    let usize remaining=built(calls::enter_owned(ref p,ref map,at,0,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref mut rs,ref mut b,built(calls::cost(ref p,at,0))));assert(remaining==0);
    let usize source=returned_site(ref p);let usize destination=(p.code[at*8+1] as usize)-128;let owners::Token t=create(ref mut a,ref mut b,1,1,42);a.tokens[16+source]=t;
    let usize formal=(p.slice_parameters[p.register_starts[0]+1] as usize)-1;let slices::Ticket current=l.tickets[16+formal];l.pool.slots[current.slot].generation=18446744073709551615;l.tickets[16+formal].generation=18446744073709551615;
    let arrays::State old=a;let slices::Pool pool=l.pool;
    assert(!calls::return_array(ref p,0,1,source,destination,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref rs,ref b,73).is_ok);
    unchanged(ref a,ref old);assert(auth.depth==1 && c.pcs[0]==at);i=0;while(i<16){assert(l.pool.slots[i].live==pool.slots[i].live && l.pool.slots[i].generation==pool.slots[i].generation);i+=1;}
    l.pool.slots[current.slot].generation=current.generation;l.tickets[16+formal]=current;
    assert(built(calls::return_array(ref p,0,1,source,destination,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref rs,ref b,73))==4);
    assert(auth.depth==0 && auth.frame==0 && a.tokens[16+source].generation==0 && a.tokens[destination].slot==t.slot && a.tokens[destination].generation==t.generation && a.owners.depth==old.owners.depth && a.owners.arena.used==old.owners.arena.used);
    assert(l.tickets[reader].slot==original_reader.slot && l.tickets[reader].generation==original_reader.generation && slices::length(ref l.pool,l.tickets[writer],ref a.owners,64).is_ok);
    assert(!calls::return_array(ref p,0,1,source,destination,ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref rs,ref b,73).is_ok);
    assert(calls::finish(ref mut c,ref mut auth,ref mut f,ref mut l,ref mut a,ref b,.ok(42)).is_ok);
}
@test
fn void abort_after_transfer_retains_caller_result_write_and_original_error(){
    let ir::Program p=compiled(b"module main;fn i32[1] f(ref mut i32[] p){p[0]=42;return [1;1];}fn i32 main(){var i32[1] a=[0;1];let ref mut i32[] p=ref mut a;let i32[1] result=f(ref mut p);let i32 zero=0;return result[0]/zero;}");let proof::Sites map=sites(ref p);
    var authority::State[1] auth=[authority::empty();1];var calls::Bindings[1] c=[calls::empty();1];var children::Bindings[1] links=[children::empty();1];var loans::State l=loans::empty();var shared::Frames f=shared::empty();var arrays::State a=arrays::empty(64);var bytes::Buffer b=buffer(64);
    let errors::Error error=switch(execution::execute_canonical(ref p,ref map,1000000,ref mut a,ref mut b,ref mut l,ref mut f,ref mut auth,ref mut c,ref mut links)){case .ok(_):{assert(false);errors::make(0,0)}case .err(e):{e}};assert(error.kind==7 && auth[0].depth==0 && a.owners.depth==2);
    assert(switch(context::finish(ref mut links[0],ref mut c[0],ref mut auth[0],ref mut f,ref mut l,ref mut a,ref b,.err(error))){case .ok(_):{false}case .err(e):{e.kind==7 && e.offset==error.offset}});
    assert(context::ready(ref auth[0],ref c[0],ref links[0],ref l,ref f).is_ok && a.owners.depth==2 && a.owners.arena.used==8);
    let usize destination=(p.code[pc(ref p)*8+1] as usize)-128;assert(switch(owners::read(ref a.owners,a.tokens[destination],0,bytes::view(ref b))){case .ok(v):{v==1}case .err(_):{false}});
    assert(bytes::view(ref b)[0]==42);
}

@test
fn void result_signature_fuel_control_and_live_destination_gates_are_atomic(){
    let ir::Program original=program(1,42,1,1);let proof::Sites map=sites(ref original);let usize at=pc(ref original);var usize mode=0;
    while(mode<12){var ir::Program p=original;var arrays::State a=arrays::empty(4);var bytes::Buffer b=buffer(4);var loans::State l=loans::empty();var shared::Frames f=shared::empty();var authority::State auth=authority::empty();var calls::Bindings c=calls::empty();var records::State rs=records::empty();
        if(mode==1){p.array_results[0]=255;}else if(mode==2){p.array_functions[1]=0;}else if(mode==3){p.arrays.elements[1]=2;}else if(mode==4){p.arrays.lengths[1]=2;}else if(mode==5){p.record_results[0]=1;}else if(mode==6){p.code[at*8+1]=144;}else if(mode==7){p.array_functions[0]=1;}else if(mode==8){a.tokens[1]=owners::Token{.slot=0,.generation=1};}else if(mode==11){p.return_types[0]=2;}
        var i64[256] registers=[99;256];var usize[32] pcs=[77;32];var usize[32] dsts=[88;32];
        assert(switch(control::step_canonical(ref p,ref map,at,if(mode==10){31}else{0},ref mut c,ref mut auth,ref mut f,ref mut l,ref mut rs,ref mut a,ref mut b,ref mut registers,ref mut pcs[..if(mode==9){1}else{32}],ref mut dsts,if(mode==0){0}else{1})){case .ok(_):{false}case .err(e):{e.kind==if(mode==0){8}else if(mode==10){12}else{5}}});
        assert(auth.depth==0 && auth.frame==0 && c.pcs[0]==256 && a.owners.depth==0 && a.owners.arena.used==0 && a.tokens[1].generation==if(mode==8){1}else{0});
        var usize i=0;while(i<256){assert(registers[i]==99);i+=1;}i=0;while(i<32){assert(pcs[i]==77 && dsts[i]==88);i+=1;}mode+=1;
    }
}
