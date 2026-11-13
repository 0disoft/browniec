module tests::m2::aggregate_copy_lowering;
import aggregate_copy_source_work as work;
import struct_value_source as records;
import record_expression_source as expressions;
import array_source as arrays;
import lexer as lexer;
import ir as ir;
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

fn ir::Program fixture(){var ir::Program p=ir::empty();p.function_count=1;p.records.layouts.count=2;
    p.records.layouts.fields[0]=2;p.records.layouts.types[0]=1;p.records.layouts.types[1]=1;
    p.records.layouts.fields[1]=1;p.records.layouts.kinds[16]=1;p.records.layouts.types[16]=0;
    assert(ir::record_in(ref mut p,0,0,true,0).is_ok);return p;}
fn void result(Result<usize,errors::Error> x,Result<usize,errors::Error> y,bool success){switch(x){
    case .ok(v):{assert(success);switch(y){case .ok(z):{assert(v==z);}case .err(_):{assert(false);}};}
    case .err(e):{assert(!success);switch(y){case .ok(_):{assert(false);}case .err(z):{assert(e.kind==z.kind && e.offset==z.offset);}};}};}
@test fn void materialization_and_extraction_match_raw_failure_prefixes(){
    var usize mode=0;while(mode<6){var ir::Program a=fixture();var ir::Program b=fixture();
        let expressions::Value value=expressions::Value{.id=if(mode==0){16}else{0},.owned=mode==2,.record=0,.ordinal=0,.tag=0,.slots=[0;16],.depth=0};
        if(mode==3){a.records.count=16;b.records.count=16;}if(mode==4){a.count=256;b.count=256;}if(mode==5){a.registers=127;b.registers=127;}
        let Result<usize,errors::Error> x=if(mode<2){expressions::materialize_raw(ref mut a,0,ref value,false,7)}else{
            records::extract_part_raw(ref mut a,0,0,records::Leaf{.ordinal=0,.tag=0,.record=0},false,9,7,mode==2)};
        let Result<usize,errors::Error> y=if(mode<2){expressions::materialize(ref mut b,0,ref value,false,7)}else{
            records::extract_part(ref mut b,0,0,records::Leaf{.ordinal=0,.tag=0,.record=0},false,9,7,mode==2)};
        same(ref a,ref b);result(x,y,mode<3);mode+=1;}
}
@test fn void child_staging_preserves_slots_delimiters_and_error_order(){
    let ref u8[] source=b"}";var usize mode=0;while(mode<4){var ir::Program a=fixture();var ir::Program b=fixture();
        var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);var lexer::State t=s;
        var records::Initializer x=records::initializer(1);x.depth=1;x.records[0]=1;var records::Initializer y=x;
        var usize[16] left=[0;16];var usize[16] right=[0;16];let usize first=if(mode==1){15}else{0};
        if(mode==2){a.count=255;b.count=255;}if(mode==3){a.registers=127;b.registers=127;}
        let records::Leaf leaf=records::Leaf{.ordinal=0,.tag=0,.record=0};
        let Result<usize,errors::Error> raw=records::stage_part_raw(source,ref mut s,ref mut a,ref mut x,ref mut left,first,0,leaf,7);
        let Result<usize,errors::Error> staged=records::stage_part(source,ref mut t,ref mut b,ref mut y,ref mut right,first,0,leaf,7);
        same(ref a,ref b);result(raw,staged,mode==0);assert(s.cursor==t.cursor && x.fields[0]==y.fields[0]);
        var usize i=0;while(i<16){assert(left[i]==right[i]);i+=1;}mode+=1;}
}
@test fn void array_clone_exact_capacity_and_errors_match_raw(){
    var usize mode=0;while(mode<4){var ir::Program a=ir::empty();a.function_count=1;
        assert(ir::array_in(ref mut a,0,1,4096,true,0).is_ok);var ir::Program b=a;
        if(mode==1){a.arrays.count=16;b.arrays.count=16;}if(mode==2){a.count=256;b.count=256;}
        let usize length=if(mode==3){4095}else{4096};
        let Result<usize,errors::Error> x=arrays::copy_raw(ref mut a,0,0,1,length,false,7);
        let Result<usize,errors::Error> y=arrays::copy(ref mut b,0,0,1,length,false,7);
        same(ref a,ref b);result(x,y,mode==0);mode+=1;}
}
@test fn void copy_rows_wait_for_metadata_and_emit_one_operation_per_step(){
    var ir::Program p=fixture();let usize[1] input=[0];var usize[16] slots=[0;16];
    var work::State w=work::begin(1,0,0,0,0,0,false,false,7,7);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok && !work::resume(ref mut w,2).is_ok);
    while(!w.done){assert(turns<100);let u8 phase=w.phase;let usize row=w.row;let usize visits=w.visits;let usize count=p.count;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(ref mut p,ref input,ref mut slots,ref mut w,ref mut meter).is_ok && w.phase==phase && w.row==row && w.visits==visits && p.count==count && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(ref mut p,ref input,ref mut slots,ref mut w,ref mut meter).is_ok && p.count-count<=1);
        if(w.request!=0){assert(w.request==1);let usize cursor=w.visits;
            assert(budget::reset(ref mut meter,0).is_ok && work::advance(ref mut p,ref input,ref mut slots,ref mut w,ref mut meter).is_ok && w.visits==cursor && meter.last==0);
            assert(work::resume(ref mut w,2).is_ok && !work::resume(ref mut w,2).is_ok);}turns+=1;}
    assert(w.value==2 && p.count==4 && slots[0]==1 && slots[1]==3);
    let usize total=meter.total;assert(work::advance(ref mut p,ref input,ref mut slots,ref mut w,ref mut meter).is_ok && meter.total==total);
    let usize[16] staged=[11,12,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
    w=work::begin(3,16,0,0,2,0,false,false,7,7);
    while(!w.done){assert(budget::reset(ref mut meter,0).is_ok && work::advance(ref mut p,ref staged,ref mut slots,ref mut w,ref mut meter).is_ok);
        if(w.request==1){assert(work::resume(ref mut w,2).is_ok);}}
    assert(slots[2]==11 && slots[3]==12 && p.count==4);
    assert(ir::array_in(ref mut p,0,1,4096,true,0).is_ok);
    w=work::begin(5,0,0,0,0,0,false,false,7,7);w.element=1;w.length=4096;
    assert(budget::reset(ref mut meter,0).is_ok && work::advance(ref mut p,ref input,ref mut slots,ref mut w,ref mut meter).is_ok);
    assert(p.arrays.count==2 && p.count==4 && !work::prepared(ref w).is_ok);
    assert(budget::reset(ref mut meter,0).is_ok && work::advance(ref mut p,ref input,ref mut slots,ref mut w,ref mut meter).is_ok && w.done && w.value==1 && p.count==5);

}
