module tests::m2::record_copy_metadata_lowering;
import ir as ir;
import record_read_source_work as work;
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
    p.records.count=1;return p;
}
fn void compare(usize mode){var ir::Program a=fixture();var ir::Program b=fixture();
    if(mode==2){a.records.layouts.kinds[511]=1;b.records.layouts.kinds[511]=1;}
    if(mode==4){a.registers=128;b.registers=128;}if(mode==5){a.count=256;b.count=256;}
    if(mode==6){a.records.layouts.kinds[0]=1;a.records.layouts.types[0]=0;b.records.layouts.kinds[0]=1;b.records.layouts.types[0]=0;}
    if(mode==7){a.records.layouts.count=0;b.records.layouts.count=0;}
    if(mode==8){a.records.count=0;b.records.count=0;}
    let usize id=if(mode==1 || mode==2){16}else{0};let usize leaf=if(mode==3){2}else{1};
    let Result<usize,errors::Error> x=ir::record_read_raw(ref mut a,id,leaf,7);
    let Result<usize,errors::Error> y=ir::record_read(ref mut b,id,leaf,7);same(ref a,ref b);
    switch(x){case .ok(v):{assert(mode==0);switch(y){case .ok(z):{assert(v==z && b.types[z]==1);}case .err(_):{assert(false);}};}
        case .err(e):{assert(mode!=0);switch(y){case .ok(_):{assert(false);}case .err(z):{assert(e.kind==z.kind && e.offset==z.offset);}};}};
}
@test fn void record_read_metadata_preserves_raw_error_priority_and_ir_prefixes(){
    var usize mode=0;while(mode<9){compare(mode);mode+=1;}
}
@test fn void record_read_prepares_all_128_leaves_without_source_leaf_limit(){
    var ir::Program a=ir::empty();a.records.layouts.count=2;a.records.layouts.fields[0]=8;a.records.layouts.fields[1]=16;a.records.count=1;a.records.records[0]=1;
    var usize i=0;while(i<8){a.records.layouts.types[i]=2;i+=1;}
    i=0;while(i<16){a.records.layouts.kinds[16+i]=1;a.records.layouts.types[16+i]=0;i+=1;}
    var ir::Program b=a;let Result<usize,errors::Error> x=ir::record_read_raw(ref mut a,0,127,9);
    let Result<usize,errors::Error> y=ir::record_read(ref mut b,0,127,9);same(ref a,ref b);
    let usize left=switch(x){case .ok(v):{v}case .err(_):{assert(false);0}};
    let usize right=switch(y){case .ok(v):{v}case .err(_):{assert(false);0}};
    assert(left==right && b.types[0]==2 && b.count==1);
}
@test fn void record_copy_metadata_defers_validation_and_emission_without_replay(){
    var ir::Program p=fixture();var work::State w=work::begin(0,1,7);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<10000);let u8 phase=w.phase;let usize count=p.count;let usize visits=w.visits;
        let usize checked=w.metadata.layout.checked;let usize binding=w.metadata.binding;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);
        assert(work::advance(ref mut p,ref mut w,ref mut meter).is_ok && p.count==count && w.phase==phase && w.visits==visits && w.metadata.layout.checked==checked && w.metadata.binding==binding);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(ref mut p,ref mut w,ref mut meter).is_ok && p.count-count<=1);
        if(w.phase<3){assert(p.count==0);}if(!w.done){assert(!work::prepared(ref w).is_ok);}turns+=1;}
    assert(w.value==0 && p.types[0]==1 && p.count==1 && turns>32);let usize total=meter.total;
    assert(work::advance(ref mut p,ref mut w,ref mut meter).is_ok && meter.total==total && p.count==1);
}
