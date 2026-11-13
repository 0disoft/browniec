module tests::m2::aggregate_call_lowering;
import aggregate_call_source_work as work;
import call_operand_work as calls;
import compiler as compiler;
import lexer as lexer;
import locals as locals;
import functions as functions;
import ir as ir;
import loops as loops;
import errors as errors;
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

fn void compare(ref u8[] source,usize destination,bool success){
    var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);var lexer::State t=s;
    let locals::Table names=locals::empty();var functions::Table signatures=functions::empty();signatures.count=1;signatures.arities[0]=1;signatures.param_types[0]=1;
    var ir::Program a=ir::empty();a.function_count=1;a.return_types[0]=1;
    var ir::Program b=ir::empty();b.function_count=1;b.return_types[0]=1;var loops::State flow=loops::empty();
    let Result<usize,errors::Error> x=compiler::specialized_call(source,ref mut s,ref mut a,ref names,ref signatures,0,destination,0,0,1,0,ref mut flow,false);
    let Result<usize,errors::Error> y=compiler::specialized_call(source,ref mut t,ref mut b,ref names,ref signatures,0,destination,0,0,1,0,ref mut flow,true);
    same(ref a,ref b);assert(s.cursor==t.cursor && s.begin==t.begin && s.end==t.end && s.kind==t.kind);
    switch(x){case .ok(v):{assert(success);switch(y){case .ok(z):{assert(v==z);}case .err(_):{assert(false);}};}
        case .err(e):{assert(!success);switch(y){case .ok(_):{assert(false);}case .err(z):{assert(e.kind==z.kind && e.offset==z.offset);}};}};
}
@test fn void specialized_outer_calls_keep_raw_ir_and_error_prefixes(){
    compare(b"(42)",0,true);compare(b"(42)",144,true);compare(b"(42)",16,true);
    compare(b"(true)",0,false);compare(b"(42,)",144,false);compare(b"()",0,false);
    compare(b"(42,43)",144,false);compare(b"(missing)",0,false);compare(b"(42)@",0,false);
}
@test fn void destinations_cleanup_and_view_requests_defer_without_replay(){
    let ref u8[] source=b"(42)";var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    let locals::Table names=locals::empty();var functions::Table signatures=functions::empty();signatures.count=1;signatures.arities[0]=1;signatures.param_types[0]=1;
    var ir::Program p=ir::empty();var calls::State w=calls::begin(ref names,s,0,0,0);var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<2000);let u8 phase=w.phase;let usize count=p.count;let usize cursor=s.cursor;let usize row=w.row;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut s,ref mut p,ref signatures,0,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.row==row && p.count==count && s.cursor==cursor && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(source,ref mut s,ref mut p,ref signatures,0,ref mut w,ref mut meter).is_ok);
        assert(p.count-count<=1);
        if(w.request!=0){assert(w.request==1);assert(lexer::next(source,ref mut s).is_ok);
            let usize value=switch(ir::integer(ref mut p,42,1,1)){case .ok(v):{v}case .err(_):{assert(false);0}};
            w.names.count=2;w.names.registers[0]=128;w.names.registers[1]=129;
            assert(calls::resume(ref mut w,1,value).is_ok && !calls::resume(ref mut w,1,value).is_ok);}
        turns+=1;}
    assert(calls::prepared(ref w).is_ok && w.value==128 && p.count==4 && p.code[8]==9 && p.code[9]==128 && p.code[17]==1 && p.code[25]==0);
    let usize total=meter.total;assert(work::advance(source,ref mut s,ref mut p,ref signatures,0,ref mut w,ref mut meter).is_ok && meter.total==total);
}

@test fn void returned_view_request_waits_for_close_token_lexing(){
    let ref u8[] source=b"(42)";var lexer::State s=lexer::empty();
    let locals::Table names=locals::empty();var functions::Table signatures=functions::empty();signatures.count=1;signatures.arities[0]=1;signatures.param_types[0]=1;
    var ir::Program p=ir::empty();var calls::State w=calls::empty();var budget::State meter=budget::empty();
    s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);w=calls::begin(ref names,s,0,0,0);
    var bool finished_token=false;var bool finalized=false;
    while(!w.done){let bool lexing=w.lexing;let u8 phase=w.phase;let usize count=p.count;
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(source,ref mut s,ref mut p,ref signatures,176,ref mut w,ref mut meter).is_ok);
        if(phase==6 && lexing){assert(w.request==0 && p.count==count);finished_token=true;}
        if(w.request==1){assert(lexer::next(source,ref mut s).is_ok);let usize value=switch(ir::integer(ref mut p,42,1,1)){case .ok(v):{v}case .err(_):{assert(false);0}};
            assert(calls::resume(ref mut w,1,value).is_ok);}
        else if(w.request==3){assert(finished_token && s.kind==0 && !w.lexing && p.count==count && !calls::prepared(ref w).is_ok);
            assert(!calls::resume(ref mut w,2,160).is_ok && calls::resume(ref mut w,3,160).is_ok);finalized=true;}}
    assert(finalized && w.value==160);

}
