module tests::m2::array_slice_length;
import compiler as compiler;
import ir as ir;
import verifier as verifier;
import vm as vm;
import slice_vm as loans;
import array_vm as arrays;
import array_slices as slices;
import errors as errors;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r) { return switch(r) { case .ok(v): { v } case .err(_): { assert(false); 0 } }; }
fn ir::Program compiled(ref u8[] source) { return switch(compiler::compile(source)) { case .ok(p): { p } case .err(_): { assert(false); ir::empty() } }; }
fn void value(ref u8[] source,usize limit) { let ir::Program p=compiled(source); assert(verifier::verify(ref p).is_ok); assert(switch(vm::run_with_array_limit(ref p,3000000,limit)) { case .ok(v): { v==42 } case .err(_): { false } }); }
fn void rejected(ref u8[] source) { assert(!compiler::compile(source).is_ok); }
fn void invalid(ref ir::Program p) { assert(!verifier::verify(p).is_ok); }
fn void kind(Result<usize,errors::Error> r,u8 expected) { assert(switch(r) { case .ok(_): { false } case .err(e): { e.kind==expected && e.offset==77 } }); }

@test
fn void lengths_cover_whole_empty_computed_maximum_and_multibyte_selections() {
    value(b"module main;fn i32 main(){let u8[4] a=[65;4];let ref u8[] all=ref a;let ref u8[] part=ref a[1+0..a.len-1];let ref u8[] empty=ref a[4..];if(all.len==4 && part.len==2 && empty.len==0){return 42;}return 0;}",4);
    value(b"module main;fn usize length(u8[4096] a,usize lo){let ref u8[] part=ref a[lo..];return part.len;}fn i32 main(){let u8[4096] a=[65;4096];if(length(a,1)==4095){return 42;}return 0;}",8192);
    value(b"module main;fn i32 main(){var u8[4] a=[0;4];a[0]=240;a[1]=159;a[2]=141;a[3]=171;let ref u8[] part=ref a;if(part.len==4 && text::valid_utf8(part)){return 42;}return 0;}",4);
    value(b"module main;struct Box{usize n;}fn i32 main(){let u8[4] a=[65;4];let ref u8[] first=ref a[..2];let ref u8[] tail=ref a[first.len..];let Box b=Box{.n=tail.len};if(b.n==2 && first.len+tail.len==a.len){return 42;}return 0;}",16);
}

@test
fn void lengths_are_scalar_snapshots_and_keep_scope_and_root_conflict_rules() {
    value(b"module main;fn i32 main(){var u8[1] a=[65;1];var usize n=0;{let ref u8[] p=ref a;n=p.len;}a[0]=255;if(n==1 && !text::valid_utf8(a)){return 42;}return 0;}",1);
    value(b"module main;fn Option<i32> f(Option<i32> o){let u8[1] a=[65;1];let ref u8[] p=ref a;let usize n=p.len;let i32 v=o?;if(n==1){return .some(v);}return .some(0);}fn i32 main(){switch(f(.none)){case .some(v):{return 0;}case .none:{}}switch(f(.some(42))){case .some(v):{return v;}case .none:{return 0;}}}",1);
    value(b"module main;fn i32 main(){var u8[1] a=[65;1];var i32 n=0;while(n<2){let ref u8[] p=ref a;if(p.len==1){n=n+1;continue;}break;}a[0]=66;return n+40;}",1);
    rejected(b"module main;fn i32 main(){var u8[1] a=[65;1];let ref u8[] p=ref a;let usize n=p.len;a[0]=0;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];{let ref u8[] p=ref a;}let usize n=p.len;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] p=ref a;let u32 n=p.len;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] p=ref a;let usize n=p.capacity;return 42;}");
    rejected(b"module main;fn i32 main(){let u8[1] a=[65;1];let ref u8[] p=ref a;let u8 n=p[0];return 42;}");
}

fn ir::Program program(usize length) {
    var ir::Program p=ir::empty(); let usize root=built(ir::array(ref mut p,10,length,false,0)); let usize site=built(ir::slice(ref mut p,root,0));
    let usize fill=built(ir::integer(ref mut p,65,10,0)); let usize init=built(ir::array_init(ref mut p,root,fill,0));
    let usize lo=built(ir::integer(ref mut p,0,12,0)); let usize hi=built(ir::integer(ref mut p,1,12,0));
    let usize open=built(ir::slice_open(ref mut p,site,lo,hi,77)); let usize count=built(ir::slice_length(ref mut p,site,77));
    let usize close=built(ir::slice_close(ref mut p,site,77)); let usize drop=built(ir::array_drop(ref mut p,root,0));
    let usize yes=built(ir::literal(ref mut p,42,0)); let usize ret=built(ir::emit(ref mut p,8,yes,0,0));
    let usize end=p.count; let usize registers=p.registers;
    p.function_count=1; p.ends[0]=end; p.register_ends[0]=registers; p.return_types[0]=1; return p;
}
@test
fn void independent_verification_and_runtime_reject_dead_forged_or_wrong_frame_handles() {
    let ir::Program p=program(4); assert(verifier::verify(ref p).is_ok);
    var usize i=0; while(i<7) {
        var ir::Program bad=p;
        if(i==0) { bad.types[3]=2; } else if(i==1) { bad.slots[3]=true; } else if(i==2) { bad.code[42]=16; }
        else if(i==3) { bad.code[43]=1; } else if(i==4) { bad.code[44]=1; } else if(i==5) { bad.code[41]=1; }
        else { bad.code[40]=56; bad.code[41]=0; bad.code[48]=57; bad.code[49]=3; }
        invalid(ref bad); i+=1;
    }
    var arrays::State state=arrays::empty(4); var loans::State loan=loans::empty(); var bytes::Buffer data=switch(arrays::prepare(4)) { case .ok(v): { v } case .err(_): { assert(false); bytes::empty() } }; var i64[5] r=[65,0,0,99,42];
    let usize init=built(arrays::execute(33,0,0,0,0,ref p.arrays,ref mut state,ref mut data,ref mut r[..],0));
    kind(loans::step(ref p,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],4097),5);
    let usize open=built(loans::step(ref p,4,0,ref mut loan,ref mut state,ref data,ref mut r[..],65537));
    kind(loans::step(ref p,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],4096),8); assert(r[3]==99);
    assert(built(loans::step(ref p,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],4097))==0 && r[3]==0 && state.owners.slots[0].reading);
    r[3]=99; kind(loans::step(ref p,5,1,ref mut loan,ref mut state,ref data,ref mut r[..],4097),5);
    let bytes::Buffer missing=bytes::empty(); kind(loans::step(ref p,5,0,ref mut loan,ref mut state,ref missing,ref mut r[..],4097),5);
    var ir::Program bad=p; bad.arrays.lengths[0]=3; kind(loans::step(ref bad,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],4097),5);
    let slices::Ticket ticket=loan.tickets[0]; let slices::Slot saved=loan.pool.slots[ticket.slot]; var slices::Slot corrupt=saved; corrupt.generation+=1; loan.pool.slots[ticket.slot]=corrupt;
    kind(loans::step(ref p,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],4097),5); loan.pool.slots[ticket.slot]=saved;
    assert(r[3]==99 && r[4]==42 && loan.tickets[0].generation==ticket.generation);
    let usize close=built(loans::step(ref p,6,0,ref mut loan,ref mut state,ref data,ref mut r[..],4097));
    kind(loans::step(ref p,5,0,ref mut loan,ref mut state,ref data,ref mut r[..],4097),5);
    assert(!ir::slice_length(ref mut bad,16,0).is_ok);
}

@test
fn void exact_source_fuel_and_builder_limits_do_not_reexecute_bounds_or_change_scan_prices() {
    let ir::Program p=compiled(b"module main;fn i32 main(){let u8[4] a=[65;4];let ref u8[] part=ref a[..];if(part.len==4){return 42;}return 0;}");
    assert(verifier::verify(ref p).is_ok);
    assert(switch(vm::run_with_array_limit(ref p,73855,4)) { case .ok(v): { v==42 } case .err(_): { false } });
    assert(switch(vm::run_with_array_limit(ref p,73854,4)) { case .ok(_): { false } case .err(e): { e.kind==8 } });
    value(b"module main;fn i32 main(){var usize hi=2;let u8[4] a=[65;4];let ref u8[] p=ref a[..hi];hi=4;if(p.len==2 && p.len==2){return 42;}return 0;}",4);
    value(b"module main;fn i32 main(){var i32 n=0;let Option<i32> o=.none;let u8[1] a=[65;1];let ref u8[] p=ref a[0..switch(o){case .some(v):{1}case .none:{n=n+1;1}}];if(p.len==1 && p.len==1 && n==1){return 42;}return 0;}",1);
    var ir::Program full=program(1); let usize count=full.count; full.registers=128;
    assert(!ir::slice_length(ref mut full,0,0).is_ok && full.count==count);
    full=program(1); full.slice_roots[0]=255; full.arrays.count=255; assert(!ir::slice_length(ref mut full,0,0).is_ok);
}
