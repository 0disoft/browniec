module tests::m2::argument_acquisition_lowering;
import compiler as compiler;
import lexer as lexer;
import locals as locals;
import functions as functions;
import ir as ir;
import loops as loops;
import errors as errors;
import argument_source_work as work;
import argument_name_work as names_work;
import std::bytes as bytes;
import slice_capture_source_work as captures;
import slice_call_source as slices;
import metadata_budget as budget;
fn void same(ref ir::Program a,ref ir::Program b){
    {var usize i=0;while(i<2048){assert(a.code[i]==b.code[i]);i+=1;}}
    {var usize i=0;while(i<128){assert(a.constants[i]==b.constants[i]);i+=1;}}
    {var usize i=0;while(i<256){assert(a.offsets[i]==b.offsets[i]);i+=1;}}
    assert(a.count==b.count);
    assert(a.registers==b.registers);
    assert(a.constant_count==b.constant_count);
    {var usize i=0;while(i<16){assert(a.starts[i]==b.starts[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.ends[i]==b.ends[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.register_starts[i]==b.register_starts[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.register_ends[i]==b.register_ends[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.arities[i]==b.arities[i]);i+=1;}}
    {var usize i=0;while(i<256){assert(a.call_args[i]==b.call_args[i]);i+=1;}}
    {var usize i=0;while(i<32){assert(a.call_arities[i]==b.call_arities[i]);i+=1;}}
    assert(a.function_count==b.function_count);
    assert(a.entry==b.entry);
    assert(a.call_count==b.call_count);
    {var usize i=0;while(i<128){assert(a.types[i]==b.types[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.return_types[i]==b.return_types[i]);i+=1;}}
    {var usize i=0;while(i<128){assert(a.slots[i]==b.slots[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.array_functions[i]==b.array_functions[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.record_functions[i]==b.record_functions[i]);i+=1;}}
    {var usize i=0;while(i<128){assert(a.array_parameters[i]==b.array_parameters[i]);i+=1;}}
    {var usize i=0;while(i<128){assert(a.record_parameters[i]==b.record_parameters[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.array_results[i]==b.array_results[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.record_results[i]==b.record_results[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.slice_roots[i]==b.slice_roots[i]);i+=1;}}
    {var usize i=0;while(i<128){assert(a.slice_parameters[i]==b.slice_parameters[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.slice_origins[i]==b.slice_origins[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.slice_functions[i]==b.slice_functions[i]);i+=1;}}
    {var usize i=0;while(i<16){assert(a.slice_elements[i]==b.slice_elements[i]);i+=1;}}
    {var usize i=0;while(i<4096){assert(a.list_operands[i]==b.list_operands[i]);i+=1;}}
    assert(a.list_used==b.list_used);
    assert(a.arrays.count==b.arrays.count && a.records.count==b.records.count && a.records.layouts.count==b.records.layouts.count);
    var usize i=0;while(i<16){assert(a.arrays.elements[i]==b.arrays.elements[i] && a.arrays.lengths[i]==b.arrays.lengths[i] && a.arrays.mutable[i]==b.arrays.mutable[i]);assert(a.records.records[i]==b.records.records[i] && a.records.mutable[i]==b.records.mutable[i]);i+=1;}
    i=0;while(i<32){assert(a.records.layouts.fields[i]==b.records.layouts.fields[i]);i+=1;}
    i=0;while(i<512){assert(a.records.layouts.kinds[i]==b.records.layouts.kinds[i] && a.records.layouts.types[i]==b.records.layouts.types[i]);i+=1;}
}


fn void compare(ref u8[] source,u8 kind,bool named,bool exclusive,usize registers,usize count,bool expected){
    var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);var lexer::State t=s;
    var locals::Table names=locals::empty();if(named){names.count=1;names.begins[0]=4;names.ends[0]=8;names.registers[0]=128;names.mutable[0]=true;}
    var locals::Table other=locals::snapshot(ref names);
    var functions::Table signatures=functions::empty();signatures.count=1;signatures.arities[0]=1;
    signatures.param_slices[0]=true;signatures.param_slice_elements[0]=if(exclusive){129}else{1};
    var ir::Program a=ir::empty();a.function_count=1;a.registers=registers;a.count=count;
    a.arrays.count=1;a.arrays.elements[0]=1;a.arrays.lengths[0]=4;a.arrays.mutable[0]=true;
    var ir::Program b=ir::empty();b.function_count=1;b.registers=registers;b.count=count;
    b.arrays.count=1;b.arrays.elements[0]=1;b.arrays.lengths[0]=4;b.arrays.mutable[0]=true;
    var loops::State flow=loops::empty();
    let Result<usize,errors::Error> x=compiler::acquire_argument(source,ref mut s,ref mut a,ref mut names,ref signatures,kind,0,1,4,0,1,0,ref mut flow,false);
    let Result<usize,errors::Error> y=compiler::acquire_argument(source,ref mut t,ref mut b,ref mut other,ref signatures,kind,0,1,4,0,1,0,ref mut flow,true);
    assert(x.is_ok==expected && y.is_ok==expected);same(ref a,ref b);assert(s.cursor==t.cursor && s.begin==t.begin && s.end==t.end && s.kind==t.kind && s.tokens==t.tokens);
    assert(names.count==other.count);var usize i=0;while(i<64){assert(names.begins[i]==other.begins[i] && names.ends[i]==other.ends[i] && names.registers[i]==other.registers[i] && names.mutable[i]==other.mutable[i]);i+=1;}
    switch(x){case .ok(v):{switch(y){case .ok(z):{assert(v==z);}case .err(_):{assert(false);}};}
        case .err(e):{switch(y){case .ok(_):{assert(false);}case .err(z):{assert(e.kind==z.kind && e.offset==z.offset);}};}};
}
@test fn void repeated_arguments_keep_raw_success_and_failure_prefixes(){
    compare(b"[7;4],",1,false,false,0,0,true);compare(b"[7;3],",1,false,false,0,0,false);
    compare(b"[true;4],",1,false,false,0,0,false);compare(b"[7;0],",1,false,false,0,0,false);
    compare(b"[7;4]@",1,false,false,0,0,false);compare(b"[7;4]x",1,false,false,0,0,false);
    compare(b"[7;4],",1,false,false,128,0,false);compare(b"[7;4],",1,false,false,0,256,false);
    compare(b"([7;4]),",1,false,false,0,0,true);compare(b"[7,7,7,7],",1,false,false,0,0,true);
}
@test fn void slice_acquisition_keeps_raw_endpoints_owners_and_errors(){
    compare(b"ref [7;4],",3,false,false,0,0,true);compare(b"ref [7;4][1..3],",3,false,false,0,0,true);
    compare(b"ref [7;4][..],",3,false,false,0,0,true);compare(b"ref [7;4][true..3],",3,false,false,0,0,false);
    compare(b"ref [7;4][1.3],",3,false,false,0,0,false);compare(b"ref [7;4][1..true],",3,false,false,0,0,false);
    compare(b"ref [7;4][1..3]@",3,false,false,0,0,false);compare(b"ref [7;4],",3,false,false,127,0,false);
    compare(b"ref root[..],",3,true,false,0,0,true);compare(b"ref root,",3,true,false,0,0,true);
    compare(b"ref root[1..3],",3,true,false,0,255,false);compare(b"ref mut [7;4][..],",3,false,true,0,0,true);
}
@test fn void repeated_and_endpoint_requests_do_not_replay_or_publish_early(){
    let ref u8[] source=b"[7;4],";var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    var ir::Program p=ir::empty();p.function_count=1;var work::State w=work::begin(s,1,1,4,0,0);var budget::State meter=budget::empty();
    assert(!work::prepared(ref w).is_ok && !work::resume(ref mut w,1,0).is_ok);
    var usize steps=0;while(!w.done){assert(steps<1000);let usize count=p.count;let usize cursor=s.cursor;let u8 phase=w.phase;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);
        assert(work::advance(source,ref mut s,ref mut p,ref mut w,ref mut meter).is_ok && p.count==count && s.cursor==cursor && w.phase==phase);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(source,ref mut s,ref mut p,ref mut w,ref mut meter).is_ok && p.count-count<=1);
        if(w.request==1){let usize total=meter.total;assert(work::advance(source,ref mut s,ref mut p,ref mut w,ref mut meter).is_ok && meter.total==total);
            assert(lexer::next(source,ref mut s).is_ok);let usize v=switch(ir::integer(ref mut p,7,1,1)){case .ok(v):{v}case .err(_):{assert(false);0}};
            assert(work::resume(ref mut w,1,v).is_ok && !work::resume(ref mut w,1,v).is_ok);}
        steps+=1;}
    assert(work::prepared(ref w).is_ok && p.count==2 && p.arrays.count==1);let usize total=meter.total;
    assert(work::advance(source,ref mut s,ref mut p,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void named_capture_scan_and_acquisition_yield_before_publication(){
    let ref u8[] source=b"root,";var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    var locals::Table names=locals::empty();names.count=1;names.begins[0]=0;names.ends[0]=4;names.registers[0]=128;
    var ir::Program p=ir::empty();p.function_count=1;p.arrays.count=1;p.arrays.elements[0]=1;p.arrays.lengths[0]=4;
    var captures::State w=captures::begin(s,0,1,9);var budget::State meter=budget::empty();var usize steps=0;
    while(!w.done){assert(steps<1000);let usize count=p.count;let usize size=names.count;let u8 phase=w.phase;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);
        assert(captures::advance(source,ref mut s,ref mut p,ref mut names,ref mut w,ref mut meter).is_ok && w.phase==phase && p.count==count && names.count==size);
        assert(budget::reset(ref mut meter,0).is_ok && captures::advance(source,ref mut s,ref mut p,ref mut names,ref mut w,ref mut meter).is_ok);
        assert(p.count-count<=1);if(!w.done){assert(names.count==1);}steps+=1;}
    assert(w.value==160 && names.count==2 && p.count==3);let usize total=meter.total;
    assert(captures::advance(source,ref mut s,ref mut p,ref mut names,ref mut w,ref mut meter).is_ok && meter.total==total);
}

@test fn void acquisition_names_stop_at_first_match_and_scan_long_spellings_in_chunks(){
    var bytes::Buffer b=bytes::empty();var usize i=0;while(i<200){assert(bytes::append(ref mut b,b"a").is_ok);i+=1;}
    assert(bytes::append(ref mut b,b",").is_ok);i=0;while(i<200){assert(bytes::append(ref mut b,b"a").is_ok);i+=1;}
    let ref u8[] source=bytes::view(ref b);var locals::Table names=locals::empty();names.count=64;
    i=0;while(i<64){names.begins[i]=201;names.ends[i]=401;i+=1;}
    var names_work::State w=names_work::begin(0,200,64);var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<1000);let usize compared=w.compared;let usize row=w.row;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);
        assert(names_work::advance(source,ref names.begins,ref names.ends,names.count,ref mut w,ref mut meter).is_ok && w.compared==compared && w.row==row);
        assert(budget::reset(ref mut meter,0).is_ok && names_work::advance(source,ref names.begins,ref names.ends,names.count,ref mut w,ref mut meter).is_ok);
        assert(w.compared-compared<=64 && w.row-row<=1);turns+=1;}
    assert(w.result==0 && turns>=5);let usize total=meter.total;
    assert(names_work::advance(source,ref names.begins,ref names.ends,names.count,ref mut w,ref mut meter).is_ok && meter.total==total);
}
