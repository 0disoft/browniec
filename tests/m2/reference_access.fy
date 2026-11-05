module tests::m2::reference_access;
import reference_access as access;
import static_image as images;
import static_ir as statics;
import verifier as verifier;
import ir as ir;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import errors as errors;
import compiler as compiler;
import slice_result_ir as results;
import slice_result_runtime as runtime;
import vm as vm;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn images::Image image(){
    var images::Builder b=switch(images::builder(2)){case .ok(v):{v}case .err(_):{assert(false);return image();}};
    let usize id=switch(images::intern_bytes(ref mut b,b"x*")){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(images::freeze(ref b,578)){case .ok(v):{v}case .err(_):{assert(false);image()}};
}
fn statics::Sites proof(ref images::Image image){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize opened=built(ir::raw(ref mut p,69,0,0,1,0));p.code[opened*8+4]=1;p.code[opened*8+6]=2;
    let usize index=built(ir::integer(ref mut p,0,12,0));p.types[1]=10;p.registers+=1;
    let usize read=built(ir::raw(ref mut p,71,1,0,index,0));let usize close=built(ir::raw(ref mut p,70,0,0,0,0));
    let usize wide=built(ir::widen(ref mut p,1,1,0));let usize done=built(ir::emit(ref mut p,8,wide,0,0));
    let usize end=p.count;let usize regs=p.registers;p.ends[0]=end;p.register_ends[0]=regs;
    return switch(verifier::verify_statics(ref p,image)){case .ok(v):{v}case .err(_):{assert(false);statics::empty()}};
}
fn owners::Token root(u8 kind,ref mut owners::Table table,ref mut u8[] data){
    let layouts::Array layout=switch(layouts::scalar(kind,if(kind==10){3}else{1})){
        case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}
    };
    return switch(owners::create(ref layout,24,data,table)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
}
fn slices::Ticket open(ref mut slices::Pool pool,ref mut owners::Table table,owners::Token root,bool writer,usize lo,usize hi,usize capacity){
    return switch(if(writer){slices::open_exclusive(pool,table,root,lo,hi,capacity)}else{slices::open(pool,table,root,lo,hi,capacity)}){
        case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}
    };
}
fn i64 value(Result<access::Value,errors::Error> result,usize remaining){return switch(result){
    case .ok(v):{assert(v.remaining==remaining);v.value}case .err(_):{assert(false);-99}
};}
fn void error(Result<access::Value,errors::Error> result,u8 kind){switch(result){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind && e.offset==77);}
};}
@test fn void one_source_contract_reads_image_and_runtime_bytes_with_their_own_prices(){
    let images::Image image=image();let statics::Sites sites=proof(ref image);let u32[16] words=[8193;16];
    var u8[4] data=[99;4];var owners::Table table=owners::empty(4);var slices::Pool pool=slices::empty();
    let owners::Token token=root(10,ref mut table,ref mut data);let slices::Ticket ticket=open(ref mut pool,ref mut table,token,false,1,2,4);
    let access::Source[2] sources=[access::image(0),access::loan(ticket)];let usize[2] read_costs=[17,4131];let usize[2] len_costs=[16,4097];
    let i64[2] expected=[42,24];var usize i=0;
    while(i<2){
        assert(value(access::read(ref sources[i],ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,ref data,0,read_costs[i],77),0)==expected[i]);
        assert(value(access::length(ref sources[i],ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,4,len_costs[i],77),0)==1);
        error(access::read(ref sources[i],ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,ref data,-1,read_costs[i]-1,77),8);
        error(access::read(ref sources[i],ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,ref data,-1,read_costs[i],77),14);
        error(access::length(ref sources[i],ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,4,len_costs[i]-1,77),8);i+=1;
    }
    assert(table.slots[token.slot].reading && pool.slots[ticket.slot].live && data[1]==24);
    assert(slices::close(ref mut pool,ticket,ref mut table,4).is_ok);assert(!table.slots[token.slot].reading);
}
@test fn void stale_runtime_tickets_and_noncanonical_backing_tags_cannot_select_other_storage(){
    let images::Image image=image();let statics::Sites sites=proof(ref image);let u32[16] words=[8193;16];
    var u8[4] data=[99;4];var owners::Table table=owners::empty(4);var slices::Pool pool=slices::empty();
    let owners::Token token=root(10,ref mut table,ref mut data);let slices::Ticket ticket=open(ref mut pool,ref mut table,token,false,0,1,4);
    var access::Source source=access::loan(ticket);assert(slices::close(ref mut pool,ticket,ref mut table,4).is_ok);
    error(access::read(ref source,ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,ref data,0,4130,77),8);
    error(access::read(ref source,ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,ref data,0,4131,77),5);
    source=access::image(0);source.ticket=ticket;
    error(access::read(ref source,ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,ref data,0,17,77),5);
    source=access::loan(ticket);source.site=0;
    error(access::length(ref source,ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,4,4097,77),5);
    source=access::image(0);source.storage=3;
    error(access::read(ref source,ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,ref data,0,17,77),5);
    source=access::image(0);
    error(access::read(ref source,ref sites,0,ref words,0,images::payload(ref image),ref pool,ref table,ref data,0,17,77),5);
}
@test fn void empty_image_and_runtime_byte_ranges_preserve_zero_length_and_bounds(){
    let images::Image image=image();let statics::Sites sites=proof(ref image);let u32[16] words=[8192;16];
    var u8[4] data=[99;4];var owners::Table table=owners::empty(4);var slices::Pool pool=slices::empty();
    let owners::Token token=root(10,ref mut table,ref mut data);let slices::Ticket ticket=open(ref mut pool,ref mut table,token,true,1,1,4);
    let access::Source[2] sources=[access::image(0),access::loan(ticket)];let usize[2] read_costs=[17,4131];let usize[2] len_costs=[16,4097];
    var usize i=0;while(i<2){
        assert(value(access::length(ref sources[i],ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,4,len_costs[i],77),0)==0);
        error(access::read(ref sources[i],ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,ref data,0,read_costs[i],77),14);i+=1;
    }
    assert(table.slots[token.slot].writing && pool.slots[ticket.slot].live);
    assert(slices::close(ref mut pool,ticket,ref mut table,4).is_ok);assert(!table.slots[token.slot].writing);
}
@test fn void runtime_scalar_types_do_not_coerce_to_byte_references(){
    let images::Image image=image();let statics::Sites sites=proof(ref image);let u32[16] words=[8193;16];
    var u8[4] data=[99;4];var owners::Table table=owners::empty(4);var slices::Pool pool=slices::empty();
    let owners::Token token=root(1,ref mut table,ref mut data);let slices::Ticket ticket=open(ref mut pool,ref mut table,token,false,0,1,4);
    let access::Source source=access::loan(ticket);
    error(access::read(ref source,ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,ref data,0,4131,77),5);
    error(access::length(ref source,ref sites,0,ref words,1,images::payload(ref image),ref pool,ref table,4,4097,77),5);
    assert(slices::close(ref mut pool,ticket,ref mut table,4).is_ok);
}
fn void dispatch(ref results::Program unit,bool writer,usize budget,u8 expected){
    var runtime::State state=runtime::empty(4);var u8[4] data=[99;4];
    let owners::Token token=root(10,ref mut state.runtime.owners,ref mut data);
    var slices::Pool pool=state.runtime.pool;var owners::Table table=state.runtime.owners;
    let slices::Ticket ticket=open(ref mut pool,ref mut table,token,writer,0,3,4);
    state.runtime.pool=pool;state.runtime.owners=table;
    let runtime::Capture[1] captures=[runtime::capture(ticket,true,true)];let i64[1] values=[0];
    let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    switch(vm::run_slice_scalar(unit,0,ref captures,ref values,ref inputs[..0],ref mut state,ref mut data,budget)){
        case .ok(v):{assert(expected==0 && v.value==42 && v.remaining==0);}
        case .err(e):{assert(expected!=0 && e.kind==expected);}
    };
    assert(state.runtime.authority.depth==0 && state.runtime.authority.frame==0);
    assert(state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
@test fn void canonical_byte_dispatch_charges_once_and_aborts_bounds_and_fuel_failures(){
    var usize mode=0;while(mode<3){
        let results::Program unit=switch(compiler::inspect_slice_result_ir(if(mode==0){
            b"module main;fn usize f(ref u8[] p){return (p[0] as usize)+p.len+15;}fn i32 main(){return 0;}"
        }else if(mode==1){
            b"module main;fn usize f(ref mut u8[] p){p[0]=42;return (p[0] as usize)+p.len-3;}fn i32 main(){return 0;}"
        }else{b"module main;fn i32 f(ref u8[] p){return p[3] as i32;}fn i32 main(){return 0;}"})){
            case .ok(v):{v}case .err(_):{assert(false);return;}
        };
        // Independent numeric prices: enter 147456, leave 196608, arity 1,
        // dispatch 1/op; byte READ 4131, LEN/CLOSE 4097 and WRITE 4132.
        var usize required=344065;var usize through_read=147457;var usize pc=unit.body.starts[0];
        while(pc<unit.body.ends[0]){
            let u8 op=unit.body.code[pc*8];var usize price=1;
            if(op==58){price+=4131;}else if(op==57 || op==56){price+=4097;}else if(op==60){price+=4132;}
            else{assert(op<33);}
            required+=price;through_read+=price;if(mode==2 && op==58){break;}pc+=1;
        }
        if(mode==2){dispatch(ref unit,false,through_read-1,8);dispatch(ref unit,false,through_read,14);}
        else{dispatch(ref unit,mode==1,required-1,8);dispatch(ref unit,mode==1,required,0);}
        mode+=1;
    }
}
