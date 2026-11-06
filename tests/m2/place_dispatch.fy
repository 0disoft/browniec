module tests::m2::place_dispatch;
import place_dispatch as execution;
import place_vm as formats;
import record_place_vm as old;
import aggregate_place_ir as aggregates;
import slice_place_ir as slices;
import record_place_ir as records;
import array_owners as owners;
import array_layout as arrays;
import array_slices as loans;
import ir as ir;
import verifier as verifier;
import errors as errors;
import std::vec as vec;
import std::bytes as bytes;

fn usize ok(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn owners::Token token(Result<owners::Token,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};}
fn loans::Ticket ticket(Result<loans::Ticket,owners::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);loans::Ticket{.slot=16,.generation=0}}};}
fn void failed(Result<usize,errors::Error> r,u8 kind){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset==77}});}
fn execution::Requirement plan(ref ir::Program p){return switch(execution::requirement(p)){
    case .ok(v):{v}case .err(_):{assert(false);execution::Requirement{.width=0,.cost=0,.aggregate=false,.slices=false,.records=false}}
};}
fn vec::Vec<usize> prepared(ref ir::Program p){let execution::Requirement needed=plan(p);
    return switch(execution::prepare_metered(ref needed,needed.cost)){case .ok(v):{v}case .err(_):{assert(false);vec::empty<usize>()}};
}
fn usize digest(ref vec::Vec<usize> state){let ref usize[] words=vec::view_usize(state);var usize value=0;var usize i=0;
    while(i<words.len){value+=words[i];i+=1;}return value;
}
fn owners::Token array(u8 tag,usize stride,i64 fill,ref mut u8[] data,ref mut owners::Table table){
    let arrays::Array shape=arrays::Array{.element=tag,.length=2,.stride=stride,.alignment=stride,.bytes=2*stride};
    return token(owners::create(ref shape,fill,data,table));
}
// constants0..3; owners4..7; OPEN8; SELECT9..13; READ14..16; STORE17..21;
// END22..26; CLOSE27; DROP28..31; RETURN32. Five distinct kinds share IDs0..4.
fn ir::Program unit(){
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize a=ok(ir::array(ref mut p,1,2,true,0));let usize b=ok(ir::array(ref mut p,1,2,false,0));
    let usize bytes=ok(ir::array(ref mut p,10,2,true,0));let usize slice=ok(ir::exclusive_slice(ref mut p,bytes,0));
    p.records.layouts.count=1;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=1;
    let usize record=ok(ir::record(ref mut p,0,true,0));
    let usize value=ok(ir::literal(ref mut p,42,0));let usize index=ok(ir::integer(ref mut p,0,12,0));
    let usize byte=ok(ir::integer(ref mut p,7,10,0));let usize end=ok(ir::integer(ref mut p,2,12,0));
    let usize ia=ok(ir::array_init(ref mut p,a,value,0));let usize ib=ok(ir::array_init(ref mut p,b,value,0));
    let usize ic=ok(ir::array_init(ref mut p,bytes,byte,0));let usize ir=ok(ir::record_init(ref mut p,record,value,0));
    let usize opened=ok(ir::slice_open(ref mut p,slice,index,end,0));
    let usize s0=ok(ir::place_select(ref mut p,0,a,index,77));let usize s1=ok(slices::select(ref mut p,1,slice,index,77));
    let usize s2=ok(records::select(ref mut p,2,record,0,77));let usize s3=ok(aggregates::select_array(ref mut p,3,a,77));
    let usize s4=ok(aggregates::select_record(ref mut p,4,record,0,0,77));
    let usize r0=ok(ir::place_read(ref mut p,0,a,77));let usize r1=ok(slices::read(ref mut p,1,slice,77));
    let usize r2=ok(records::read(ref mut p,2,record,0,77));
    let usize w0=ok(ir::place_store(ref mut p,0,a,value,77));let usize w1=ok(slices::store(ref mut p,1,slice,byte,77));
    let usize w2=ok(records::store(ref mut p,2,record,0,value,77));let usize w3=ok(aggregates::store_array(ref mut p,3,a,b,77));
    let usize w4=ok(aggregates::store_record(ref mut p,4,record,record,0,0,0,77));
    var usize i=0;while(i<5){let usize e=ok(ir::place_end(ref mut p,i,77));i+=1;}
    let usize closed=ok(ir::slice_close(ref mut p,slice,0));let usize dr=ok(ir::record_drop(ref mut p,record,0));
    let usize dc=ok(ir::array_drop(ref mut p,bytes,0));let usize db=ok(ir::array_drop(ref mut p,b,0));let usize da=ok(ir::array_drop(ref mut p,a,0));
    let usize ret=ok(ir::emit(ref mut p,8,value,0,0));let usize pc=p.count;let usize regs=p.registers;p.ends[0]=pc;p.register_ends[0]=regs;
    assert(pc==33 && regs==7 && verifier::inspect_aggregate_places(ref p).is_ok);return p;
}
fn usize run(ref ir::Program p,usize pc,usize frame,ref mut vec::Vec<usize> state,ref owners::Table table,
    ref owners::Token[] tokens,owners::Token record,ref loans::Pool pool,ref loans::Ticket[] tickets,
    ref mut u8[] data,ref mut i64[] regs,ref mut vec::Vec<i64> cells,ref mut bytes::Buffer scratch,usize fuel){
    return ok(execution::bound(p,pc,0,frame,state,table,tokens,record,record,pool,tickets,data,regs,cells,scratch,fuel));
}
@test fn void five_kinds_share_one_counter_and_all_legacy_reads_stores_and_end_prices(){
    let ir::Program p=unit();let execution::Requirement needed=plan(ref p);assert(needed.aggregate && needed.width==5 && needed.cost==29407);
    var vec::Vec<usize> state=prepared(ref p);assert(vec::len<usize>(ref state)==2915);
    var u8[32] data=[85;32];var owners::Table table=owners::empty(32);
    let owners::Token a=array(1,4,20,ref mut data,ref mut table);let owners::Token b=array(1,4,22,ref mut data,ref mut table);
    let owners::Token c=array(10,1,7,ref mut data,ref mut table);let i64[1] fields=[99];
    let owners::Token record=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
    var owners::Token[512] tokens=[owners::Token{.slot=16,.generation=0};512];tokens[496]=a;tokens[497]=b;tokens[498]=c;
    var loans::Pool pool=loans::empty();let loans::Ticket selected=ticket(loans::open_exclusive(ref mut pool,ref mut table,c,0,2,32));
    var loans::Ticket[512] tickets=[loans::Ticket{.slot=16,.generation=0};512];tickets[496]=selected;
    var i64[7] regs=[42,0,9,2,0,0,0];var vec::Vec<i64> cells=vec::empty<i64>();var bytes::Buffer scratch=bytes::empty();
    let usize[5] prices=[65,4129,41025,97,41057];var usize i=0;
    while(i<5){assert(ok(execution::price(ref p,9+i,0,31,ref state))==prices[i]);
        let usize s=run(ref p,9+i,31,ref mut state,ref table,ref tokens,record,ref pool,ref tickets,ref mut data,ref mut regs,ref mut cells,ref mut scratch,prices[i]);i+=1;}
    assert(vec::view_usize(ref state)[3+31*91]==5 && !execution::empty_frame(ref state,31,77).is_ok);
    assert(execution::empty_frame(ref state,30,77).is_ok && vec::view_usize(ref state)[2]==3);
    let usize[3] reads=[69,4163,41029];i=0;while(i<3){assert(ok(execution::price(ref p,14+i,0,31,ref state))==reads[i]);
        let usize r=run(ref p,14+i,31,ref mut state,ref table,ref tokens,record,ref pool,ref tickets,ref mut data,ref mut regs,ref mut cells,ref mut scratch,reads[i]);i+=1;}
    assert(regs[4]==20 && regs[5]==7 && regs[6]==99);
    let usize[5] writes=[73,4164,41033,186,172129];i=0;
    while(i<5){assert(ok(execution::price(ref p,17+i,0,31,ref state))==writes[i]);
        let usize w=run(ref p,17+i,31,ref mut state,ref table,ref tokens,record,ref pool,ref tickets,ref mut data,ref mut regs,ref mut cells,ref mut scratch,writes[i]);i+=1;}
    assert(data[0]==22 && data[16]==9 && data[20]==42 && table.depth==4 && table.arena.used==24);
    i=0;while(i<5){assert(ok(execution::price(ref p,22+i,0,31,ref state))==26);
        let usize e=run(ref p,22+i,31,ref mut state,ref table,ref tokens,record,ref pool,ref tickets,ref mut data,ref mut regs,ref mut cells,ref mut scratch,26);i+=1;}
    assert(execution::empty_frame(ref state,31,77).is_ok && vec::view_usize(ref state)[2]==3);
    assert(loans::close(ref mut pool,selected,ref mut table,32).is_ok);
}
@test fn void all_twenty_cross_kind_reselections_fail_before_mutating_shared_rows(){
    var usize selected_kind=0;while(selected_kind<5){var ir::Program p=unit();var usize i=0;
        while(i<5){p.code[(9+i)*8+1]=0;i+=1;}var vec::Vec<usize> state=prepared(ref p);
        var u8[32] data=[85;32];var owners::Table table=owners::empty(32);
        let owners::Token a=array(1,4,20,ref mut data,ref mut table);let owners::Token b=array(1,4,22,ref mut data,ref mut table);
        let owners::Token c=array(10,1,7,ref mut data,ref mut table);let i64[1] fields=[99];
        let owners::Token record=token(owners::create_record(ref p.records.layouts,0,ref fields,ref mut data,ref mut table));
        var owners::Token[512] tokens=[owners::Token{.slot=16,.generation=0};512];tokens[0]=a;tokens[1]=b;tokens[2]=c;
        var loans::Pool pool=loans::empty();let loans::Ticket live=ticket(loans::open_exclusive(ref mut pool,ref mut table,c,0,2,32));
        var loans::Ticket[512] tickets=[loans::Ticket{.slot=16,.generation=0};512];tickets[0]=live;
        var i64[7] regs=[42,0,9,2,0,0,0];var vec::Vec<i64> cells=vec::empty<i64>();var bytes::Buffer scratch=bytes::empty();
        let usize price=ok(execution::price(ref p,9+selected_kind,0,0,ref state));
        let usize s=run(ref p,9+selected_kind,0,ref mut state,ref table,ref tokens,record,ref pool,ref tickets,ref mut data,ref mut regs,ref mut cells,ref mut scratch,price);
        let usize before=digest(ref state);i=0;
        while(i<5){if(i!=selected_kind){let usize work=ok(execution::price(ref p,9+i,0,0,ref state));
            failed(execution::bound(ref p,9+i,0,0,ref mut state,ref table,ref tokens,record,record,ref pool,ref tickets,ref mut data,ref mut regs,ref mut cells,ref mut scratch,work),5);
            assert(digest(ref state)==before && data[0]==20 && data[20]==99);
        }i+=1;}
        let usize e=run(ref p,22,0,ref mut state,ref table,ref tokens,record,ref pool,ref tickets,ref mut data,ref mut regs,ref mut cells,ref mut scratch,26);
        assert(execution::empty_frame(ref state,0,77).is_ok);assert(loans::close(ref mut pool,live,ref mut table,32).is_ok);selected_kind+=1;
    }
}
@test fn void price_precedes_binding_access_and_zero_fuel_abort_keeps_invocation_ticket(){
    let ir::Program p=unit();var vec::Vec<usize> state=prepared(ref p);var u8[32] data=[85;32];var owners::Table table=owners::empty(32);
    let owners::Token root=array(1,4,20,ref mut data,ref mut table);let owners::Token none=owners::Token{.slot=16,.generation=0};
    var owners::Token[512] tokens=[none;512];tokens[0]=root;let loans::Pool pool=loans::empty();let loans::Ticket[1] tickets=[loans::Ticket{.slot=16,.generation=0}];
    var i64[7] regs=[42,0,7,2,0,0,0];var vec::Vec<i64> cells=vec::empty<i64>();var bytes::Buffer scratch=bytes::empty();let usize before=digest(ref state);
    failed(execution::bound(ref p,12,0,0,ref mut state,ref table,ref tokens[..0],none,none,ref pool,ref tickets[..0],ref mut data,ref mut regs,ref mut cells,ref mut scratch,96),8);
    assert(digest(ref state)==before && data[0]==20);
    let usize s=run(ref p,12,0,ref mut state,ref table,ref tokens,none,ref pool,ref tickets[..0],ref mut data,ref mut regs,ref mut cells,ref mut scratch,97);
    let usize serial=vec::view_usize(ref state)[2];assert(serial==2);
    failed(execution::bound(ref p,25,0,0,ref mut state,ref table,ref tokens[..0],none,none,ref pool,ref tickets[..0],ref mut data,ref mut regs,ref mut cells,ref mut scratch,25),8);
    execution::abort(ref mut state);assert(execution::empty_frame(ref state,0,77).is_ok && vec::view_usize(ref state)[2]==serial && data[0]==20);
}
@test fn void legacy_programs_keep_all_three_formats_exact_setup_and_no_aggregate_allocation(){
    var ir::Program p=unit();p.count=4;let usize s=ok(ir::place_select(ref mut p,0,0,1,77));let usize e=ok(ir::place_end(ref mut p,0,77));
    let usize[3] costs=[3457,5067,5077];var u8 kind=0;
    while(kind<3){p.code[4*8+4]=kind;p.code[4*8+3]=if(kind==2){0}else{1};let execution::Requirement needed=plan(ref p);
        assert(!needed.aggregate && needed.width==1 && needed.cost==costs[kind as usize]);
        let vec::Vec<usize> state=prepared(ref p);let formats::Format shape=switch(formats::format(ref state,77)){
            case .ok(v):{v}case .err(_):{assert(false);formats::Format{.width=0,.row=0,.prefix=0}}
        };assert(shape.prefix==kind as usize);kind+=1;
    }
    var execution::Requirement bad=plan(ref p);bad.aggregate=true;assert(!execution::prepare_metered(ref bad,16000000).is_ok);
    let ir::Program empty=ir::empty();let execution::Requirement zero=plan(ref empty);let vec::Vec<usize> none=prepared(ref empty);
    assert(zero.cost==0 && zero.width==0 && !zero.aggregate && vec::len<usize>(ref none)==0);
}
