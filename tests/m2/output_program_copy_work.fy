module tests::m2::output_program_copy_work;
import output_program_copy_work as work;
import static_call_ir as programs;
import ir as ir;
import metadata_budget as budget;
fn programs::Program empty(){return programs::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};}
fn void same(ref programs::Program left,ref programs::Program right){
    let ref ir::Program a=ref left.body;let ref ir::Program b=ref right.body;var usize i=0;
    i=0;while(i<2048){assert(a.code[i]==b.code[i]);i+=1;}
    i=0;while(i<128){assert(a.constants[i]==b.constants[i]);i+=1;}
    i=0;while(i<256){assert(a.offsets[i]==b.offsets[i]);i+=1;}
    assert(a.count==b.count);
    assert(a.registers==b.registers);
    assert(a.constant_count==b.constant_count);
    i=0;while(i<16){assert(a.starts[i]==b.starts[i]);i+=1;}
    i=0;while(i<16){assert(a.ends[i]==b.ends[i]);i+=1;}
    i=0;while(i<16){assert(a.register_starts[i]==b.register_starts[i]);i+=1;}
    i=0;while(i<16){assert(a.register_ends[i]==b.register_ends[i]);i+=1;}
    i=0;while(i<16){assert(a.arities[i]==b.arities[i]);i+=1;}
    i=0;while(i<256){assert(a.call_args[i]==b.call_args[i]);i+=1;}
    i=0;while(i<32){assert(a.call_arities[i]==b.call_arities[i]);i+=1;}
    assert(a.function_count==b.function_count);
    assert(a.entry==b.entry);
    assert(a.call_count==b.call_count);
    i=0;while(i<128){assert(a.types[i]==b.types[i]);i+=1;}
    i=0;while(i<16){assert(a.return_types[i]==b.return_types[i]);i+=1;}
    i=0;while(i<128){assert(a.slots[i]==b.slots[i]);i+=1;}
    i=0;while(i<16){assert(a.array_functions[i]==b.array_functions[i]);i+=1;}
    i=0;while(i<16){assert(a.record_functions[i]==b.record_functions[i]);i+=1;}
    i=0;while(i<128){assert(a.array_parameters[i]==b.array_parameters[i]);i+=1;}
    i=0;while(i<128){assert(a.record_parameters[i]==b.record_parameters[i]);i+=1;}
    i=0;while(i<16){assert(a.array_results[i]==b.array_results[i]);i+=1;}
    i=0;while(i<16){assert(a.record_results[i]==b.record_results[i]);i+=1;}
    i=0;while(i<16){assert(a.slice_roots[i]==b.slice_roots[i]);i+=1;}
    i=0;while(i<128){assert(a.slice_parameters[i]==b.slice_parameters[i]);i+=1;}
    i=0;while(i<16){assert(a.slice_origins[i]==b.slice_origins[i]);i+=1;}
    i=0;while(i<16){assert(a.slice_functions[i]==b.slice_functions[i]);i+=1;}
    i=0;while(i<16){assert(a.slice_elements[i]==b.slice_elements[i]);i+=1;}
    i=0;while(i<4096){assert(a.list_operands[i]==b.list_operands[i]);i+=1;}
    assert(a.list_used==b.list_used);
    assert(a.arrays.count==b.arrays.count && a.records.count==b.records.count && a.records.layouts.count==b.records.layouts.count);
    i=0;while(i<16){assert(a.arrays.elements[i]==b.arrays.elements[i] && a.arrays.lengths[i]==b.arrays.lengths[i] && a.arrays.mutable[i]==b.arrays.mutable[i]);
        assert(a.records.records[i]==b.records.records[i] && a.records.mutable[i]==b.records.mutable[i]);
        assert(left.results[i]==right.results[i] && left.origins[i]==right.origins[i]);i+=1;}
    i=0;while(i<32){assert(a.records.layouts.fields[i]==b.records.layouts.fields[i]);i+=1;}
    i=0;while(i<512){assert(a.records.layouts.kinds[i]==b.records.layouts.kinds[i] && a.records.layouts.types[i]==b.records.layouts.types[i]);i+=1;}
    i=0;while(i<128){assert(left.parameters[i]==right.parameters[i]);i+=1;}
}
fn programs::Program seed(){var programs::Program p=empty();
    p.body.code=[7;2048];
    p.body.constants=[-42;128];
    p.body.offsets=[37;256];
    p.body.count=37;
    p.body.registers=37;
    p.body.constant_count=37;
    p.body.starts=[37;16];
    p.body.ends=[37;16];
    p.body.register_starts=[37;16];
    p.body.register_ends=[37;16];
    p.body.arities=[37;16];
    p.body.call_args=[7;256];
    p.body.call_arities=[7;32];
    p.body.function_count=37;
    p.body.entry=37;
    p.body.call_count=37;
    p.body.types=[7;128];
    p.body.return_types=[7;16];
    p.body.slots=[true;128];
    p.body.array_functions=[7;16];
    p.body.record_functions=[7;16];
    p.body.array_parameters=[7;128];
    p.body.record_parameters=[7;128];
    p.body.array_results=[7;16];
    p.body.record_results=[7;16];
    p.body.slice_roots=[7;16];
    p.body.slice_parameters=[7;128];
    p.body.slice_origins=[7;16];
    p.body.slice_functions=[7;16];
    p.body.slice_elements=[7;16];
    p.body.list_operands=[7;4096];
    p.body.list_used=37;
    p.body.arrays.count=5;p.body.arrays.elements=[10;16];p.body.arrays.lengths=[19;16];p.body.arrays.mutable=[true;16];
    p.body.records.count=4;p.body.records.records=[3;16];p.body.records.mutable=[true;16];p.body.records.layouts.count=9;
    p.body.records.layouts.fields=[13;32];p.body.records.layouts.kinds=[1;512];p.body.records.layouts.types=[2;512];
    p.parameters=[3;128];p.results=[2;16];p.origins=[1;16];return p;
}
fn void copy(ref programs::Program source,ref mut programs::Program target,bool defers){
    var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<40);assert(budget::reset(ref mut meter,0).is_ok);
        if(defers){let programs::Program saved=*target;let work::State before=w;
            assert(budget::admit(ref mut meter,1,0).is_ok);let budget::State allowance=meter;
            switch(work::advance(source,target,ref mut w,ref mut meter)){case .ok(done):{assert(!done);}case .err(_):{assert(false);return;}};
            same(ref saved,target);assert(w.phase==before.phase && w.index==before.index && !w.done);
            assert(meter.total==allowance.total && meter.last==allowance.last && meter.stages==allowance.stages);
            assert(budget::reset(ref mut meter,0).is_ok);
        }
        assert(work::advance(source,target,ref mut w,ref mut meter).is_ok);assert(meter.last==4096);turns+=1;
    }same(source,target);
}
@test fn void copies_all_fixed_banks_and_unused_tails_without_aliasing(){
    let programs::Program source=seed();var programs::Program target=empty();copy(ref source,ref mut target,false);
    target.body.code[2047]=0;assert(source.body.code[2047]==7);
}
@test fn void partial_room_changes_neither_target_nor_builder_at_any_stage(){
    let programs::Program source=empty();var programs::Program target=seed();copy(ref source,ref mut target,true);
}
