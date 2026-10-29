module tests::m2::array_range_utf8;
import ir as ir;
import vm as vm;
import verifier as verifier;
import array_vm as arrays;
import array_range_vm as ranges;
import array_owners as owners;
import errors as errors;
import std::bytes as bytes;

fn usize built(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void finish(ref mut ir::Program p){
    let usize end=p.count;let usize registers=p.registers;
    p.function_count=1;p.entry=0;p.starts[0]=0;p.ends[0]=end;p.register_starts[0]=0;p.register_ends[0]=registers;p.return_types[0]=1;
}
fn void result(ref ir::Program p,usize fuel,usize limit,i64 expected){assert(switch(vm::run_with_array_limit(p,fuel,limit)){
    case .ok(v):{v==expected}case .err(_):{false}});}
fn void invalid(ref ir::Program p){assert(switch(verifier::verify(p)){case .ok(_):{false}case .err(e):{e.kind==5}});}
fn void failed(Result<usize,errors::Error> r){assert(switch(r){case .ok(_):{false}case .err(e):{e.kind==5}});}
fn void same(ref owners::Table a,ref owners::Table b,ref u8[] data,ref u8[] saved){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);
    var usize i=0;while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.live==y.live && x.occupied==y.occupied);
        assert(x.reading==y.reading && x.read_generation==y.read_generation);
        assert(x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length);
        assert(x.record==y.record && x.alignment==y.alignment);i+=1;}
    assert(data.len==saved.len);i=0;while(i<data.len){assert(data[i]==saved[i]);i+=1;}
}


fn ir::Program program(usize n, usize start, usize end, i64 fill) {
    var ir::Program p = ir::empty();
    let usize id = built(ir::array(ref mut p, 10, n, true, 0));
    let usize value = built(ir::integer(ref mut p, fill, 10, 0));
    let usize init = built(ir::array_init(ref mut p, id, value, 0));
    let usize valid = built(ir::array_range_utf8(ref mut p, id, start, end, 77));
    let usize drop = built(ir::array_drop(ref mut p, id, 0));
    let usize yes = built(ir::literal(ref mut p, 42, 0));
    let usize no = built(ir::literal(ref mut p, 0, 0));
    let usize target = p.count + 2;
    let usize branch = built(ir::raw(ref mut p, 20, 0, valid, target, 0));
    let usize returned = built(ir::emit(ref mut p, 8, yes, 0, 0));
    let usize rejected = built(ir::emit(ref mut p, 8, no, 0, 0));
    finish(ref mut p); return p;
}
fn bytes::Buffer backing(usize n) {
    return switch (arrays::prepare(n)) { case .ok(b): { b } case .err(_): { assert(false); bytes::empty() } };
}
fn void endpoints(ref mut ir::Program p, u8 start, u8 end) {
    // All endpoints used here fit a byte; high-byte corruption has separate cases.
    let usize at = 16;
    p.code[at + 4] = start; p.code[at + 5] = 0;
    p.code[at + 6] = end; p.code[at + 7] = 0;
}

@test
fn void selected_bytes_and_empty_ranges_have_independent_utf8_boundaries() {
    var ir::Program p = program(8, 1, 5, 0);
    var arrays::State state = arrays::empty(8); var bytes::Buffer data = backing(8);
    var i64[4] registers = [0, 99, 92, 93];
    let usize init = built(arrays::execute(33, 0, 0, 0, 2, ref p.arrays, ref mut state, ref mut data, ref mut registers[..], 0));
    { let ref mut u8[] b = bytes::view_mut(ref mut data);
      let u8[8] values = [255, 240, 159, 141, 171, 0, 65, 255];
      var usize i = 0; while (i < 8) { b[i] = values[i]; i += 1; } }
    let owners::Table before = state.owners;
    let u8[12] bounds = [1,5, 0,8, 1,4, 2,5, 5,7, 8,8];
    var usize c = 0; while (c < 6) {
        endpoints(ref mut p, bounds[c*2], bounds[c*2+1]);
        let usize left = built(ranges::step(ref p, 2, 2, ref state, ref data, ref mut registers[..], 100));
        assert(left == 100 - 65 - 4*((bounds[c*2+1] as usize)-(bounds[c*2] as usize)));
        assert(registers[1] == if(c == 0 || c >= 4){1}else{0});
        assert(registers[0] == 0 && registers[2] == 92 && registers[3] == 93); c += 1;
    }
    let u8[8] saved = [255,240,159,141,171,0,65,255];
    same(ref state.owners, ref before, bytes::view(ref data), ref saved);
}

@test
fn void vm_prepays_selected_length_including_empty_and_maximum_endpoints() {
    let usize[4] lengths = [1,4,256,4096]; var usize i = 0;
    while (i < 4) {
        let usize n = lengths[i]; let usize start = if(i == 0){n}else{1};
        let usize k = n-start; let usize fuel = 178 + 2*n + 4*k;
        let ir::Program good = program(n,start,n,65); let ir::Program bad = program(n,start,n,255);
        assert(verifier::verify(ref good).is_ok && verifier::verify(ref bad).is_ok);
        result(ref good,fuel,n,42); result(ref bad,fuel,n,if(k==0){42}else{0});
        assert(switch(vm::run_with_array_limit(ref good,fuel-1,n)){case .ok(_):{false}case .err(e):{e.kind==8}});
        assert(switch(vm::run_with_array_limit(ref good,124+2*n+4*k,n)){case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==77}});
        result(ref good,fuel,n,42); i += 1;
    }
}

@test
fn void verifier_rejects_bad_ranges_types_destinations_and_dead_or_foreign_sources() {
    let ir::Program baseline = program(4,1,3,65); var usize i = 0;
    while (i < 15) { var ir::Program p = baseline;
        if(i==0){p.arrays.elements[0]=1;} else if(i==1){p.types[1]=1;}
        else if(i==2){p.code[19]=1;} else if(i==3){p.code[20]=4;}
        else if(i==4){p.code[22]=5;} else if(i==5){p.code[21]=1;}
        else if(i==6){p.code[23]=16;} else if(i==7){p.code[17]=0;}
        else if(i==8){p.slots[1]=true;} else if(i==9){p.code[18]=16;}
        else if(i==10){p.code[18]=255;} else if(i==11){p.code[16]=53;}
        else if(i==12){p.register_ends[0]=1;}
        else if(i==13){p.array_functions[0]=1;}
        else {p.code[8]=37;p.code[10]=0;}
        invalid(ref p); i += 1;
    }
    var ir::Program dropped = baseline;
    dropped.code[16]=37;dropped.code[17]=0;dropped.code[18]=0;endpoints(ref mut dropped,0,0);
    dropped.code[24]=52;dropped.code[25]=1;dropped.code[26]=0;invalid(ref dropped);
}

@test
fn void defensive_runtime_errors_and_short_fuel_preserve_destination_and_storage() {
    let ir::Program baseline = program(4,1,3,65);
    var arrays::State state = arrays::empty(4); var bytes::Buffer data = backing(4);
    var i64[2] registers = [65,99];
    let usize init = built(arrays::execute(33,0,0,0,0,ref baseline.arrays,ref mut state,ref mut data,ref mut registers[..],0));
    let owners::Table before = state.owners; let u8[4] saved = [65;4];
    assert(switch(ranges::step(ref baseline,2,0,ref state,ref data,ref mut registers[..],72)){
        case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==77}});
    var usize i=0;while(i<12){var ir::Program p=baseline;
        if(i==0){p.code[17]=2;}else if(i==1){p.code[18]=16;}else if(i==2){p.code[19]=1;}
        else if(i==3){p.arrays.elements[0]=2;}else if(i==4){p.arrays.lengths[0]=3;}
        else if(i==5){p.arrays.lengths[0]=0;}else if(i==6){p.arrays.lengths[0]=4097;}
        else if(i==7){p.code[20]=4;}else if(i==8){p.code[23]=255;}
        else if(i==9){p.code[16]=51;}else if(i==10){p.count=2;}else{p.arrays.count=0;}
        failed(ranges::step(ref p,2,0,ref state,ref data,ref mut registers[..],100));
        assert(registers[0]==65 && registers[1]==99);same(ref state.owners,ref before,bytes::view(ref data),ref saved);i+=1;
    }
    failed(ranges::step(ref baseline,2,32,ref state,ref data,ref mut registers[..],100));
    failed(ranges::step(ref baseline,2,1,ref state,ref data,ref mut registers[..],100));
    let bytes::Buffer missing=bytes::empty();failed(ranges::step(ref baseline,2,0,ref state,ref missing,ref mut registers[..],100));
    state.owners.arena.used=3;failed(ranges::step(ref baseline,2,0,ref state,ref data,ref mut registers[..],100));state.owners=before;
    let usize drop=built(arrays::execute(37,0,0,0,0,ref baseline.arrays,ref mut state,ref mut data,ref mut registers[..],0));
    failed(ranges::step(ref baseline,2,0,ref state,ref data,ref mut registers[..],100));assert(registers[1]==99);
}

@test
fn void all_owner_slots_and_last_frame_can_read_without_new_owners_or_session_changes() {
    let ir::Program p=program(1,0,1,65);var arrays::State state=arrays::empty(16);var bytes::Buffer data=backing(16);
    var i64[2] registers=[65,99];var usize i=0;
    while(i<16){let usize init=built(arrays::execute(33,0,0,0,i,ref p.arrays,ref mut state,ref mut data,ref mut registers[..],0));i+=1;}
    let owners::Token root=state.tokens[240];state.tokens[496]=root;
    let owners::ReadLease lease=switch(owners::begin_read(ref mut state.owners,root,16)){
        case .ok(v):{v}case .err(_):{assert(false);owners::ReadLease{.root=root,.generation=0}}};
    let arrays::State before=state;let u8[16] saved=[65;16];
    assert(built(ranges::step(ref p,2,31,ref state,ref data,ref mut registers[..],69))==0 && registers[1]==1);
    same(ref state.owners,ref before.owners,bytes::view(ref data),ref saved);
    i=0;while(i<512){assert(state.tokens[i].slot==before.tokens[i].slot && state.tokens[i].generation==before.tokens[i].generation);i+=1;}
    assert(owners::end_read(ref mut state.owners,lease,16).is_ok);
    assert(owners::clear(ref mut state.owners,16).is_ok);
}

@test
fn void builder_rejects_invalid_requests_before_publication_and_encodes_u16_endpoints() {
    var ir::Program p=ir::empty();let usize id=built(ir::array(ref mut p,10,4096,false,0));
    let usize other=built(ir::array(ref mut p,1,1,false,0));
    assert(!ir::array_range_utf8(ref mut p,other,0,1,0).is_ok);
    assert(!ir::array_range_utf8(ref mut p,16,0,1,0).is_ok);
    assert(!ir::array_range_utf8(ref mut p,id,2,1,0).is_ok);
    assert(!ir::array_range_utf8(ref mut p,id,0,4097,0).is_ok);
    assert(p.count==0 && p.registers==0);
    let usize value=built(ir::array_range_utf8(ref mut p,id,256,4096,77));
    assert(value==0 && p.types[0]==2 && p.count==1 && p.registers==1);
    assert(p.code[0]==52 && p.code[4]==0 && p.code[5]==1 && p.code[6]==0 && p.code[7]==16);
}
