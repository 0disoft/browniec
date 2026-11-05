module tests::m2::reference_receipts;
import reference_receipts as receipts;
import reference_words as words;
import reference_access as access;
import static_views as views;
import static_ir as statics;
import slice_result_bindings as bindings;
import slice_result_runtime as runtime;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import errors as errors;

fn slices::Ticket none(){return slices::Ticket{.slot=16,.generation=0};}
fn slices::Ticket opened(ref mut runtime::State state,ref mut u8[] data){
    let layouts::Array shape=switch(layouts::scalar(10,4)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}};
    let owners::Token root=switch(owners::create(ref shape,24,data,ref mut state.runtime.owners)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    data[2]=42;var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket ticket=switch(slices::open(ref mut pool,ref mut table,root,1,4,4)){
        case .ok(v):{v}case .err(_):{assert(false);none()}
    };state.runtime.pool=pool;state.runtime.owners=table;return ticket;
}
fn runtime::Returned returned(ref mut runtime::State state,slices::Ticket parent,bool drop){
    let runtime::Capture[1] captures=[runtime::capture(parent,drop,drop)];
    var runtime::Contract contract=runtime::Contract{.tags=[0;8],.arity=1,.selected=1};contract.tags[0]=10;
    var runtime::Call call=switch(runtime::enter(state,contract,ref captures,4,runtime::cost())){
        case .ok(v):{v}case .err(_):{assert(false);return returned(state,parent,drop);}
    };let slices::Ticket selected=call.issued[0];
    return switch(runtime::handoff(state,ref mut call,selected,4,runtime::handoff_cost())){
        case .ok(v):{v}case .err(_):{assert(false);returned(state,parent,drop)}
    };
}
fn usize publish(ref mut bindings::State held,runtime::Held value,ref mut u32[] current,usize site){
    return switch(receipts::publish(held,0,site,value,views::Span{.start=1,.length=1},current,0,77)){
        case .ok(v):{v}case .err(_):{assert(false);0}
    };
}
fn access::Source source(ref bindings::State held,u32 word){return switch(receipts::source(held,0,word,77)){
    case .ok(v):{v}case .err(_):{assert(false);access::loan(none())}
};}
fn i64 read(ref runtime::State state,ref u8[] data,ref access::Source selected){
    let statics::Sites sites=statics::empty();let u32[16] unused=[0;16];let u8[1] payload=[0];
    return switch(access::read(selected,ref sites,0,ref unused,0,ref payload[..0],ref state.runtime.pool,ref state.runtime.owners,data,0,4131,77)){
        case .ok(v):{assert(v.remaining==0);v.value}case .err(_):{assert(false);-1}
    };
}
fn receipts::Closed close(ref mut bindings::State held,ref mut runtime::State state,usize site,ref mut u32[] current,usize live){
    return switch(receipts::close(held,state,0,site,current,live,4,128,77)){
        case .ok(v):{assert(v.remaining==0);v}case .err(_):{assert(false);receipts::Closed{.live=live,.remaining=99}}
    };
}
fn usize count(ref runtime::State state){var usize n=0;var usize i=0;while(i<16){if(state.runtime.pool.slots[i].live){n+=1;}i+=1;}return n;}
fn void finish(ref mut bindings::State held,ref mut runtime::State state){assert(runtime::abort(state,4,0).is_ok);bindings::transferred(held,0);
    assert(!bindings::in_frame(held,0) && count(state)==0 && state.runtime.owners.depth==0);}
@test fn void returned_words_roundtrip_sixteen_receipt_sites_without_changing_formal_encoding(){
    let views::Span[4] spans=[views::Span{.start=0,.length=0},views::Span{.start=4096,.length=0},views::Span{.start=0,.length=4096},views::Span{.start=1,.length=1}];
    var usize site=0;while(site<16){var usize i=0;while(i<4){
        let u32 word=switch(words::pack_result(site,spans[i],77)){case .ok(v):{v}case .err(_):{assert(false);0}};
        assert(words::returned(word) && words::runtime(word));switch(words::unpack(word,77)){
            case .ok(v):{assert(v.argument==16+site && v.span.start==spans[i].start && v.span.length==spans[i].length);}case .err(_):{assert(false);}
        };i+=1;
    }site+=1;}
    assert(!words::pack_result(16,spans[0],77).is_ok && !words::unpack(2684354560,77).is_ok);
    assert(!words::returned(2147483648) && !words::returned(0));
}
@test fn void returned_source_preserves_exact_relative_window_and_full_native_ticket(){
    var runtime::State state=runtime::empty(4);var u8[4] data=[0;4];let slices::Ticket parent=opened(ref mut state,ref mut data);
    let runtime::Returned result=returned(ref mut state,parent,false);var bindings::State held=bindings::empty();var u32[16] current=[0;16];
    let usize live=publish(ref mut held,result.held,ref mut current,5);let access::Source selected=source(ref held,current[5]);
    assert(selected.ticket.slot==result.held.issued.slot && selected.ticket.generation==result.held.issued.generation && selected.window);
    assert(read(ref state,ref data,ref selected)==42 && count(ref state)==2);
    let receipts::Closed closed=close(ref mut held,ref mut state,5,ref mut current,live);assert(closed.live==0 && count(ref state)==1);
    finish(ref mut held,ref mut state);
}
@test fn void aliases_share_one_receipt_and_only_last_close_releases_it_at_exact_metadata_fuel(){
    var runtime::State state=runtime::empty(4);var u8[4] data=[0;4];let slices::Ticket parent=opened(ref mut state,ref mut data);
    let runtime::Returned result=returned(ref mut state,parent,false);var bindings::State held=bindings::empty();var u32[16] current=[0;16];
    var usize live=publish(ref mut held,result.held,ref mut current,5);current[6]=current[5];live|=64;
    switch(receipts::close(ref mut held,ref mut state,0,5,ref mut current,live,4,127,77)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8 && e.offset==77 && current[5]!=0);}
    };
    let receipts::Closed first=close(ref mut held,ref mut state,5,ref mut current,live);live=first.live;
    assert(current[5]==0 && bindings::in_frame(ref held,0) && count(ref state)==2);
    let access::Source selected=source(ref held,current[6]);assert(read(ref state,ref data,ref selected)==42);
    let receipts::Closed last=close(ref mut held,ref mut state,6,ref mut current,live);
    assert(last.live==0 && current[6]==0 && !bindings::in_frame(ref held,0) && count(ref state)==1);finish(ref mut held,ref mut state);
}
@test fn void ordinary_and_universal_sites_with_same_number_never_select_each_others_receipt(){
    var runtime::State state=runtime::empty(4);var u8[4] data=[0;4];let slices::Ticket parent=opened(ref mut state,ref mut data);
    let runtime::Returned ordinary=returned(ref mut state,parent,false);let runtime::Returned generic=returned(ref mut state,parent,false);
    var bindings::State held=bindings::empty();assert(bindings::retain(ref mut held,5,4,ordinary.held).is_ok);
    var u32[16] current=[0;16];let usize live=publish(ref mut held,generic.held,ref mut current,5);
    let access::Source selected=source(ref held,current[5]);assert(selected.ticket.slot==generic.held.issued.slot && selected.ticket.slot!=ordinary.held.issued.slot);
    assert(!receipts::source(ref held,1,current[5],77).is_ok);
    let receipts::Closed closed=close(ref mut held,ref mut state,5,ref mut current,live);
    assert(bindings::find(ref held,5)!=47 && bindings::in_frame(ref held,0));
    assert(bindings::close(ref mut held,ref mut state,5,ordinary.held.issued,4,0).is_ok);finish(ref mut held,ref mut state);
}
@test fn void failed_last_owner_drop_rolls_back_word_sparse_receipt_and_native_state(){
    var runtime::State state=runtime::empty(4);var u8[4] data=[0;4];let slices::Ticket parent=opened(ref mut state,ref mut data);
    var slices::Pool pool=state.runtime.pool;
    let slices::Ticket alias=switch(slices::subslice(ref mut pool,parent,ref state.runtime.owners,0,3,4)){
        case .ok(v):{v}case .err(_):{assert(false);none()}
    };state.runtime.pool=pool;
    let runtime::Returned result=returned(ref mut state,parent,true);var bindings::State held=bindings::empty();var u32[16] current=[0;16];
    let usize live=publish(ref mut held,result.held,ref mut current,5);let u32 before=current[5];
    assert(!receipts::close(ref mut held,ref mut state,0,5,ref mut current,live,4,128,77).is_ok);
    assert(current[5]==before && bindings::in_frame(ref held,0) && count(ref state)==2);
    let access::Source selected=source(ref held,current[5]);assert(read(ref state,ref data,ref selected)==42);
    pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    assert(slices::close(ref mut pool,alias,ref mut table,4).is_ok);state.runtime.pool=pool;state.runtime.owners=table;
    let receipts::Closed closed=close(ref mut held,ref mut state,5,ref mut current,live);
    assert(closed.live==0 && count(ref state)==0 && state.runtime.owners.depth==0);finish(ref mut held,ref mut state);
}
@test fn void stale_native_ticket_rejects_read_and_close_and_short_fuel_keeps_precedence(){
    var runtime::State state=runtime::empty(4);var u8[4] data=[0;4];let slices::Ticket parent=opened(ref mut state,ref mut data);
    let runtime::Returned result=returned(ref mut state,parent,false);var bindings::State held=bindings::empty();var u32[16] current=[0;16];
    let usize live=publish(ref mut held,result.held,ref mut current,5);let access::Source selected=source(ref held,current[5]);
    let usize slot=selected.ticket.slot;state.runtime.pool.slots[slot].generation+=1;
    switch(receipts::close(ref mut held,ref mut state,0,5,ref mut current,live,4,127,77)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==8);}};
    switch(receipts::close(ref mut held,ref mut state,0,5,ref mut current,live,4,128,77)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==77);}};
    assert(current[5]!=0 && bindings::in_frame(ref held,0));
    let statics::Sites sites=statics::empty();let u32[16] unused=[0;16];let u8[1] payload=[0];
    assert(!access::read(ref selected,ref sites,0,ref unused,0,ref payload[..0],ref state.runtime.pool,ref state.runtime.owners,ref data,0,4131,77).is_ok);
    finish(ref mut held,ref mut state);
}
@test fn void invalid_or_duplicate_publication_preserves_existing_words_and_receipts(){
    var runtime::State state=runtime::empty(4);var u8[4] data=[0;4];let slices::Ticket parent=opened(ref mut state,ref mut data);
    let runtime::Returned result=returned(ref mut state,parent,false);var bindings::State held=bindings::empty();var u32[16] current=[0;16];
    assert(!receipts::publish(ref mut held,0,5,result.held,views::Span{.start=3,.length=1},ref mut current,0,77).is_ok);
    assert(current[5]==0 && !bindings::in_frame(ref held,0));let usize live=publish(ref mut held,result.held,ref mut current,5);
    let u32 before=current[5];assert(!receipts::publish(ref mut held,0,6,result.held,views::Span{.start=0,.length=1},ref mut current,live,77).is_ok);
    assert(current[6]==0 && current[5]==before && count(ref state)==2);
    let receipts::Closed closed=close(ref mut held,ref mut state,5,ref mut current,live);finish(ref mut held,ref mut state);
}
@test fn void consumed_native_frame_clears_both_receipt_namespaces_without_releasing_twice(){
    var runtime::State state=runtime::empty(4);var u8[4] data=[0;4];let slices::Ticket parent=opened(ref mut state,ref mut data);
    let runtime::Returned a=returned(ref mut state,parent,false);let runtime::Returned b=returned(ref mut state,parent,false);
    var bindings::State held=bindings::empty();assert(bindings::retain(ref mut held,5,4,a.held).is_ok);
    var u32[16] current=[0;16];let usize live=publish(ref mut held,b.held,ref mut current,5);
    assert(runtime::abort(ref mut state,4,0).is_ok);bindings::transferred(ref mut held,0);
    assert(!bindings::in_frame(ref held,0) && !receipts::source(ref held,0,current[5],77).is_ok && count(ref state)==0);
}
