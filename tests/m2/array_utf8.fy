module tests::m2::array_utf8;
import ir as ir;
import vm as vm;
import verifier as verifier;
import array_vm as arrays;
import array_owners as owners;
import array_meta as meta;
import array_layout as layouts;
import errors as errors;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void finish(ref mut ir::Program p){
    let usize end=p.count;let usize registers=p.registers;
    p.function_count=1;p.entry=0;p.starts[0]=0;p.ends[0]=end;p.register_starts[0]=0;p.register_ends[0]=registers;p.return_types[0]=1;
}
fn ir::Program program(usize length,i64 fill){
    var ir::Program p=ir::empty();let usize id=built(ir::array(ref mut p,10,length,true,0));
    let usize value=built(ir::integer(ref mut p,fill,10,0));let usize init=built(ir::array_init(ref mut p,id,value,0));
    let usize valid=built(ir::array_utf8(ref mut p,id,77));let usize drop=built(ir::array_drop(ref mut p,id,0));
    let usize yes=built(ir::literal(ref mut p,42,0));let usize no=built(ir::literal(ref mut p,0,0));
    let usize target=p.count+2;let usize branch=built(ir::raw(ref mut p,20,0,valid,target,0));
    let usize returned=built(ir::emit(ref mut p,8,yes,0,0));let usize failed=built(ir::emit(ref mut p,8,no,0,0));
    finish(ref mut p);return p;
}
fn void result(ref ir::Program p,usize fuel,usize limit,i64 expected){assert(switch(vm::run_with_array_limit(p,fuel,limit)){
    case .ok(v):{v==expected}case .err(_):{false}});}
fn void invalid(ref ir::Program p){assert(switch(verifier::verify(p)){case .ok(_):{false}case .err(e):{e.kind==5}});}
fn void failed(Result<usize,errors::Error> r){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==5}});}
fn void same(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){assert(a.order[i]==b.order[i] && a.slots[i].generation==b.slots[i].generation &&
        a.slots[i].occupied==b.slots[i].occupied && a.slots[i].live==b.slots[i].live && a.slots[i].mark==b.slots[i].mark &&
        a.slots[i].base==b.slots[i].base && a.slots[i].end==b.slots[i].end && a.slots[i].element==b.slots[i].element &&
        a.slots[i].length==b.slots[i].length && a.slots[i].record==b.slots[i].record && a.slots[i].alignment==b.slots[i].alignment);i+=1;}
}

@test
fn void utf8_payload_cases_preserve_storage_owners_and_frame_tokens(){
    var meta::Catalog catalog=meta::empty();let usize id=built(meta::declare(ref mut catalog,10,4,true,0));
    var arrays::State state=arrays::empty(8);var bytes::Buffer payload=switch(arrays::prepare(8)){case .ok(b):{b}case .err(_):{assert(false);bytes::empty()}};
    var i64[4] registers=[0,91,92,93];let usize init=built(arrays::execute(33,id,0,0,2,ref catalog,ref mut state,ref mut payload,ref mut registers[..],0));
    let owners::Table before=state.owners;let owners::Token token=state.tokens[32];
    let u8[24] cases=[240,159,141,171,0,65,127,0,192,175,0,0,237,160,128,0,244,144,128,128,128,0,0,0];
    var usize c=0;while(c<6){
        {let ref mut u8[] data=bytes::view_mut(ref mut payload);var usize i=0;while(i<4){data[i]=cases[c*4+i];i+=1;}}
        let usize checked=built(arrays::execute(51,1,id,0,2,ref catalog,ref mut state,ref mut payload,ref mut registers[..],77));
        assert(registers[1]==if(c<2){1}else{0});assert(registers[0]==0 && registers[2]==92 && registers[3]==93);
        let ref u8[] data=bytes::view(ref payload);var usize i=0;while(i<4){assert(data[i]==cases[c*4+i]);i+=1;}
        same(ref state.owners,ref before);assert(state.tokens[32].slot==token.slot && state.tokens[32].generation==token.generation && state.tokens[0].generation==0);c+=1;
    }
    assert(built(arrays::cost(ref catalog,51,id,0))==49);
}

@test
fn void native_dispatch_prepays_exact_fuel_for_valid_and_invalid_bytes(){
    let usize[3] lengths=[1,4,4096];var usize i=0;while(i<3){
        let usize n=lengths[i];let usize fuel=146+6*n;let ir::Program good=program(n,65);let ir::Program bad=program(n,255);
        assert(verifier::verify(ref good).is_ok && verifier::verify(ref bad).is_ok);
        result(ref good,fuel,n,42);result(ref bad,fuel,n,0);
        assert(switch(vm::run_with_array_limit(ref good,fuel-1,n)){case .ok(_):{false}case .err(e):{e.kind==8}});
        assert(switch(vm::run_with_array_limit(ref bad,92+6*n,n)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==77}});
        result(ref good,fuel,n,42);i+=1;
    }
}

@test
fn void independent_verifier_rejects_wrong_types_operands_and_dead_sources(){
    let ir::Program baseline=program(4,65);var usize i=0;while(i<10){var ir::Program p=baseline;
        if(i==0){p.arrays.elements[0]=1;}else if(i==1){p.types[1]=1;}else if(i==2){p.code[19]=1;}
        else if(i==3){p.code[20]=1;}else if(i==4){p.code[18]=16;}else if(i==5){p.code[17]=0;}
        else if(i==6){p.slots[1]=true;}else if(i==7){p.code[8]=37;p.code[10]=0;}
        else if(i==8){p.code[16]=53;}else{p.code[18]=255;}
        invalid(ref p);i+=1;
    }
    var ir::Program dropped=baseline;
    dropped.code[16]=37;dropped.code[17]=0;dropped.code[18]=0;
    dropped.code[24]=51;dropped.code[25]=1;dropped.code[26]=0;invalid(ref dropped);
}

@test
fn void owner_identity_shape_and_backing_checks_precede_byte_access(){
    var meta::Catalog catalog=meta::empty();let usize id=built(meta::declare(ref mut catalog,10,2,false,0));
    var arrays::State state=arrays::empty(2);var bytes::Buffer payload=switch(arrays::prepare(2)){case .ok(b):{b}case .err(_):{assert(false);bytes::empty()}};
    var i64[2] registers=[0,99];let usize init=built(arrays::execute(33,id,0,0,0,ref catalog,ref mut state,ref mut payload,ref mut registers[..],0));
    let owners::Token token=state.tokens[0];let owners::Table before=state.owners;
    {let ref mut u8[] data=bytes::view_mut(ref mut payload);data[0]=226;data[1]=130;}
    let usize truncated=built(arrays::execute(51,1,id,0,0,ref catalog,ref mut state,ref mut payload,ref mut registers[..],0));assert(registers[1]==0);
    let bytes::Buffer missing=bytes::empty();assert(!owners::utf8_valid(ref state.owners,token,2,bytes::view(ref missing)).is_ok);
    assert(!owners::utf8_valid(ref state.owners,token,1,bytes::view(ref payload)).is_ok);
    assert(!owners::utf8_valid(ref state.owners,owners::Token{.slot=16,.generation=0},2,bytes::view(ref missing)).is_ok);
    state.owners.arena.used=1;assert(!owners::utf8_valid(ref state.owners,token,2,bytes::view(ref payload)).is_ok);state.owners=before;
    let usize drop=built(arrays::execute(37,id,0,0,0,ref catalog,ref mut state,ref mut payload,ref mut registers[..],0));
    assert(!owners::utf8_valid(ref state.owners,token,2,bytes::view(ref payload)).is_ok);
    var owners::Table booleans=owners::empty(2);var u8[2] bits=[0;2];
    let layouts::Array shape=switch(layouts::scalar(2,2)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=2,.length=2,.stride=1,.alignment=1,.bytes=2}}};
    let owners::Token other=switch(owners::create(ref shape,0,ref mut bits[..],ref mut booleans)){
        case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    assert(!owners::utf8_valid(ref booleans,other,2,ref bits[..]).is_ok);
}

@test
fn void runtime_operand_and_catalog_failures_do_not_overwrite_the_result(){
    var meta::Catalog catalog=meta::empty();let usize id=built(meta::declare(ref mut catalog,10,1,false,0));
    var arrays::State state=arrays::empty(1);var bytes::Buffer payload=switch(arrays::prepare(1)){case .ok(b):{b}case .err(_):{assert(false);bytes::empty()}};
    var i64[2] registers=[0,99];let usize init=built(arrays::execute(33,id,0,0,0,ref catalog,ref mut state,ref mut payload,ref mut registers[..],0));
    failed(arrays::execute(51,1,id,1,0,ref catalog,ref mut state,ref mut payload,ref mut registers[..],0));
    failed(arrays::execute(51,2,id,0,0,ref catalog,ref mut state,ref mut payload,ref mut registers[..],0));
    failed(arrays::execute(51,1,16,0,0,ref catalog,ref mut state,ref mut payload,ref mut registers[..],0));
    failed(arrays::execute(51,1,id,0,32,ref catalog,ref mut state,ref mut payload,ref mut registers[..],0));
    catalog.elements[id]=1;failed(arrays::cost(ref catalog,51,id,0));
    failed(arrays::execute(51,1,id,0,0,ref catalog,ref mut state,ref mut payload,ref mut registers[..],0));catalog.elements[id]=10;
    catalog.lengths[id]=2;failed(arrays::execute(51,1,id,0,0,ref catalog,ref mut state,ref mut payload,ref mut registers[..],0));
    assert(registers[1]==99 && registers[0]==0);
}

@test
fn void builder_requires_u8_and_predicate_does_not_consume_its_source(){
    var ir::Program p=ir::empty();let usize wrong=built(ir::array(ref mut p,2,1,false,0));
    assert(!ir::array_utf8(ref mut p,wrong,0).is_ok && !ir::array_utf8(ref mut p,16,0).is_ok && p.count==0 && p.registers==0);
    let ir::Program good=program(4,0);assert(good.code[16]==51 && good.types[1]==2 && good.code[24]==37);
    result(ref good,170,4,42);
}
