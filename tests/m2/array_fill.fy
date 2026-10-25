module tests::m2::array_fill;
import array_owners as owners;
import array_layout as layouts;
import ir as ir;
import verifier as verifier;
import vm as vm;

fn layouts::Array layout(u8 tag,usize length) {
    return switch(layouts::scalar(tag,length)){case .ok(a):{a}case .err(_):{assert(false);layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}};
}
fn owners::Token created(ref layouts::Array a,ref mut u8[] bytes,ref mut owners::Table table) {
    return switch(owners::create(a,0,bytes,table)){case .ok(t):{t}case .err(_):{assert(false);owners::Token{.slot=0,.generation=0}}};
}
fn usize built(ref mut ir::Program p,u8 op,usize dst,usize a,usize b) {
    return switch(ir::raw(p,op,dst,a,b,0)){case .ok(n):{n}case .err(_):{assert(false);0}};
}
fn ir::Program program() {
    var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=1;
    let usize id=switch(ir::array(ref mut p,1,1,true,0)){case .ok(n):{n}case .err(_):{assert(false);0}};
    let usize zero=switch(ir::integer(ref mut p,0,1,0)){case .ok(n):{n}case .err(_):{assert(false);0}};
    let usize init=built(ref mut p,33,id,zero,0);
    let usize fill=switch(ir::integer(ref mut p,42,1,0)){case .ok(n):{n}case .err(_):{assert(false);0}};
    let usize filled=switch(ir::array_fill(ref mut p,id,fill,0)){case .ok(n):{n}case .err(_):{assert(false);0}};
    let usize index=switch(ir::integer(ref mut p,0,12,0)){case .ok(n):{n}case .err(_):{assert(false);0}};
    let usize read=switch(ir::array_read(ref mut p,id,index,0)){case .ok(n):{n}case .err(_):{assert(false);0}};
    let usize drop=built(ref mut p,37,id,0,0);let usize ret=built(ref mut p,8,0,read,0);
    let usize end=p.count;let usize regs=p.registers;p.ends[0]=end;p.register_ends[0]=regs;
    return p;
}
@test
fn void all_scalar_fills_preserve_metadata_and_neighbor_bytes() {
    let u8[6] tags=[1,2,9,10,11,12];let i64[6] values=[-2147483648,1,-9223372036854775808,255,4294967295,-1];
    var usize i=0;
    while(i<6){
        let layouts::Array a=layout(tags[i],3);var u8[64] bytes=[85;64];var owners::Table table=owners::empty(a.bytes);
        let owners::Token token=created(ref a,ref mut bytes,ref mut table);let owners::Owner before=table.slots[token.slot];
        assert(owners::fill(ref table,token,values[i],ref mut bytes).is_ok);
        assert(switch(owners::read(ref table,token,2,ref bytes)){case .ok(n):{n==values[i]}case .err(_):{false}});
        assert(table.depth==1 && table.arena.used==a.bytes && table.slots[token.slot].generation==before.generation);
        assert(table.slots[token.slot].base==before.base && table.slots[token.slot].end==before.end && bytes[a.bytes]==85);i+=1;
    }
    let layouts::Array a=layout(10,1);var u8[16] bytes=[0;16];var owners::Table table=owners::empty(16);
    var owners::Token token=created(ref a,ref mut bytes,ref mut table);i=1;
    while(i<16){token=created(ref a,ref mut bytes,ref mut table);i+=1;}
    assert(owners::fill(ref table,token,42,ref mut bytes).is_ok && bytes[15]==42 && table.depth==16 && table.arena.used==16);
}
@test
fn void invalid_fill_preflight_preserves_every_byte() {
    let layouts::Array a=layout(2,3);var u8[16] bytes=[85;16];var owners::Table table=owners::empty(16);
    let owners::Token token=created(ref a,ref mut bytes,ref mut table);let u8[16] before=bytes;
    assert(!owners::fill(ref table,token,2,ref mut bytes).is_ok);
    var owners::Table bad=table;bad.slots[token.slot].end+=1;
    assert(!owners::fill(ref bad,token,1,ref mut bytes).is_ok);
    assert(!owners::fill(ref table,owners::Token{.slot=token.slot,.generation=token.generation+1},1,ref mut bytes).is_ok);
    assert(!owners::fill(ref table,token,1,ref mut bytes[..2]).is_ok);
    var usize i=0;while(i<16){assert(bytes[i]==before[i]);i+=1;}
    assert(owners::release(ref mut table,token,bytes.len).is_ok);
    assert(!owners::fill(ref table,token,1,ref mut bytes).is_ok);
}
@test
fn void verifier_requires_live_mutable_exact_type_and_defined_operands() {
    let ir::Program good=program();assert(verifier::verify(ref good).is_ok);
    var ir::Program bad=good;bad.arrays.mutable[0]=false;assert(!verifier::verify(ref bad).is_ok);
    bad=good;bad.code[3*8+3]=1;assert(!verifier::verify(ref bad).is_ok);
    bad=good;bad.code[3*8+2]=4;assert(!verifier::verify(ref bad).is_ok);
    bad=good;bad.code[3*8+1]=1;assert(!verifier::verify(ref bad).is_ok);
    bad=good;bad.code[1*8]=37;bad.code[1*8+2]=0;assert(!verifier::verify(ref bad).is_ok);
}
@test
fn void vm_prepays_fill_and_uses_only_the_existing_extent() {
    let ir::Program p=program();
    assert(switch(vm::run_with_array_limit(ref p,224,4)){case .ok(n):{n==42}case .err(_):{false}});
    assert(switch(vm::run_with_array_limit(ref p,223,4)){case .ok(_):{false}case .err(e):{e.kind==8}});
    assert(switch(vm::run_with_array_limit(ref p,100000,3)){case .ok(_):{false}case .err(e):{e.kind==13}});
}
