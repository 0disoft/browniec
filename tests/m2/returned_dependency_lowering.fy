module tests::m2::returned_dependency_lowering;
import ir as ir;
import functions as functions;
import reference_result_source as source;
import reference_owner_work as work;
import metadata_budget as budget;
import errors as errors;
import locals as locals;
import slice_result_call_source as slices;
import slice_result_dependency_work as slice_work;
import reference_result_work as ref_work;
import slice_reborrow_ir as reborrow;
import array_source as arrays;

fn void same_result(Result<usize,errors::Error> a,Result<usize,errors::Error> b,bool success){switch(a){
    case .ok(v):{assert(success);switch(b){case .ok(w):{assert(v==w);}case .err(_):{assert(false);}};}
    case .err(e):{assert(!success);switch(b){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};}};}
@test fn void reference_owners_match_recursive_walk_and_cycle_limit(){
    var functions::Table t=functions::empty();t.count=1;t.reference_returns=true;
    t.return_slice_elements[0]=10;t.return_slice_inputs[0]=1;
    var ir::Program p=ir::empty();p.count=3;p.code[0]=75;p.code[1]=0;p.code[2]=1;
    p.code[8]=78;p.code[9]=1;p.code[10]=0;p.code[11]=0;p.arities[0]=1;p.call_count=1;
    p.call_args[0]=160;p.slice_roots[0]=3;
    same_result(source::owners_raw(ref p,ref t,192,0,7),source::owners(ref p,ref t,192,0,7),true);
    p.call_args[0]=192;
    same_result(source::owners_raw(ref p,ref t,192,0,7),source::owners(ref p,ref t,192,0,7),false);
    p.call_args[0]=160;p.slice_roots[0]=17;
    same_result(source::owners_raw(ref p,ref t,192,0,7),source::owners(ref p,ref t,192,0,7),false);
    same_result(source::owners_raw(ref p,ref t,192,33,7),source::owners(ref p,ref t,192,33,7),false);
    t.return_slice_inputs[0]=0;
    same_result(source::owners_raw(ref p,ref t,192,0,7),source::owners(ref p,ref t,192,0,7),false);
}
@test fn void reference_owner_scan_yields_and_preserves_terminal_state(){
    var ir::Program p=ir::empty();p.count=2;p.code[8]=69;p.code[9]=0;
    let functions::Table t=functions::empty();var work::State w=work::begin(192,0,9);
    var budget::State meter=budget::empty();assert(!work::prepared(ref w).is_ok);
    assert(budget::admit(ref mut meter,1,0).is_ok);
    assert(work::advance(ref p,ref t,ref mut w,ref mut meter).is_ok && w.visits==0 && w.pc==0);
    while(!w.done){let usize before=w.visits;assert(budget::reset(ref mut meter,0).is_ok);
        assert(work::advance(ref p,ref t,ref mut w,ref mut meter).is_ok && w.visits==before+1);}
    assert(work::prepared(ref w).is_ok);let usize total=meter.total;
    assert(work::advance(ref p,ref t,ref mut w,ref mut meter).is_ok && meter.total==total);
}

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

fn void same_names(ref locals::Table a,ref locals::Table b){assert(a.count==b.count && a.function==b.function);
    var usize i=0;while(i<64){assert(a.begins[i]==b.begins[i] && a.ends[i]==b.ends[i] &&
        a.registers[i]==b.registers[i] && a.mutable[i]==b.mutable[i]);i+=1;}}
fn ir::Program slice_fixture(){var ir::Program p=ir::empty();p.function_count=1;p.return_types[0]=12;
    p.arrays.count=1;p.arrays.elements[0]=10;p.arrays.lengths[0]=4;p.arrays.mutable[0]=true;
    p.slice_roots[0]=1;p.slice_roots[1]=1;p.slice_elements[0]=128;p.slice_elements[1]=128;
    p.count=1;p.code[0]=61;p.code[1]=1;p.code[2]=0;return p;}
fn locals::Table slice_captures(){var locals::Table names=locals::empty();names.count=3;
    names.registers[0]=128;names.registers[1]=160;names.registers[2]=161;return names;}
fn functions::Table slice_signature(){var functions::Table t=functions::empty();t.count=1;
    t.return_slice_inputs[0]=1;t.return_slice_elements[0]=10;return t;}
@test fn void slice_finish_publish_preserve_retained_parent_and_cleanup_mask(){
    var ir::Program a=slice_fixture();var ir::Program b=slice_fixture();let locals::Table captures=slice_captures();
    var locals::Table left=locals::empty();var locals::Table right=locals::empty();let functions::Table t=slice_signature();
    let usize[1] args=[161];let Result<usize,errors::Error> x=slices::finish_raw(ref mut a,ref left,ref captures,ref t,0,ref args,0,7);
    let Result<usize,errors::Error> y=slices::finish(ref mut b,ref right,ref captures,ref t,0,ref args,0,7);
    same_result(x,y,true);same(ref a,ref b);assert(a.count==4 && a.code[8]==66 && a.code[12]==1 && a.code[16]==68 && a.code[24]==67);
    let usize value=160+a.code[25] as usize;
    let Result<usize,errors::Error> px=slices::publish_raw(ref a,ref mut left,value,7);
    let Result<usize,errors::Error> py=slices::publish(ref b,ref mut right,value,7);
    same_result(px,py,true);same_names(ref left,ref right);assert(left.count==2 && left.registers[0]==128 && left.registers[1]==160);
}
@test fn void slice_failure_prefixes_match_after_partial_argument_map_and_call(){
    var usize mode=0;while(mode<3){var ir::Program a=slice_fixture();var ir::Program b=slice_fixture();
        let locals::Table captures=slice_captures();let locals::Table names=locals::empty();let functions::Table t=slice_signature();
        let usize[2] args=[161,if(mode==0){300}else{161}];if(mode==1){a.count=255;b.count=255;}
        if(mode==2){a.registers=128;b.registers=128;}
        let Result<usize,errors::Error> x=slices::finish_raw(ref mut a,ref names,ref captures,ref t,0,ref args,0,7);
        let Result<usize,errors::Error> y=slices::finish(ref mut b,ref names,ref captures,ref t,0,ref args,0,7);
        same_result(x,y,false);same(ref a,ref b);mode+=1;}
}
fn functions::Table ref_signature(){var functions::Table t=functions::empty();t.count=1;t.reference_returns=true;
    t.return_slice_elements[0]=10;t.return_slice_inputs[0]=1;return t;}
fn ir::Program ref_fixture(){var ir::Program p=ir::empty();p.function_count=1;p.arities[0]=1;
    p.arrays.count=1;p.arrays.elements[0]=10;p.arrays.lengths[0]=4;p.slice_roots[0]=1;return p;}
fn locals::Table ref_captures(){var locals::Table names=locals::empty();names.count=2;
    names.registers[0]=128;names.registers[1]=193;return names;}
@test fn void reference_call_release_publish_match_raw_and_retain_owner(){
    var ir::Program a=ref_fixture();var ir::Program b=ref_fixture();let functions::Table t=ref_signature();
    let locals::Table captures=ref_captures();var locals::Table left=locals::empty();var locals::Table right=locals::empty();let usize[1] args=[160];
    let Result<usize,errors::Error> x=source::call_raw(ref mut a,ref t,ref left,ref captures,0,ref args,9);
    let Result<usize,errors::Error> y=source::call(ref mut b,ref t,ref right,ref captures,0,ref args,9);
    same_result(x,y,true);same(ref a,ref b);assert(a.count==2 && a.code[0]==78 && a.code[8]==70);
    let Result<usize,errors::Error> px=source::publish_raw(ref a,ref t,ref mut left,0,9);
    let Result<usize,errors::Error> py=source::publish(ref b,ref t,ref mut right,0,9);
    same_result(px,py,true);same_names(ref left,ref right);assert(left.count==1 && left.registers[0]==128);
    let Result<usize,errors::Error> rx=source::release_raw(ref mut a,ref captures,0,1,9);
    let Result<usize,errors::Error> ry=source::release(ref mut b,ref captures,0,1,9);
    same_result(rx,ry,true);same(ref a,ref b);
}
@test fn void reference_call_partial_map_and_capacity_errors_match(){
    var usize mode=0;while(mode<3){var ir::Program a=ref_fixture();var ir::Program b=ref_fixture();
        let functions::Table t=ref_signature();let locals::Table captures=ref_captures();let locals::Table names=locals::empty();
        let usize[2] args=[160,if(mode==0){300}else{160}];if(mode==1){a.count=256;b.count=256;}
        if(mode==2){a.call_count=32;b.call_count=32;}
        let Result<usize,errors::Error> x=source::call_raw(ref mut a,ref t,ref names,ref captures,0,ref args,9);
        let Result<usize,errors::Error> y=source::call(ref mut b,ref t,ref names,ref captures,0,ref args,9);
        same_result(x,y,false);same(ref a,ref b);mode+=1;}
}

@test fn void slice_dependency_work_defers_pending_rows_and_finishes_once(){
    var ir::Program p=slice_fixture();let locals::Table captures=slice_captures();let locals::Table names=locals::empty();
    let functions::Table t=slice_signature();let usize[1] args=[161];
    var slice_work::State w=slice_work::finish_begin(0,captures.count,0,0,7);var budget::State meter=budget::empty();
    assert(!slice_work::prepared(ref w).is_ok && !slice_work::resume(ref mut w,0).is_ok);var usize turns=0;
    while(!w.done){assert(turns<10000);let usize visits=w.visits;let usize search=w.search;let usize index=w.index;let usize count=p.count;let u8 phase=w.phase;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);
        assert(slice_work::finish_advance(ref mut p,ref names,ref captures,ref t,ref args,ref mut w,ref mut meter).is_ok);
        assert(w.visits==visits && w.search==search && w.index==index && w.phase==phase && p.count==count);
        assert(budget::reset(ref mut meter,0).is_ok && slice_work::finish_advance(ref mut p,ref names,ref captures,ref t,ref args,ref mut w,ref mut meter).is_ok);
        assert(w.visits==visits+1 && p.count-count<=1);
        if(w.request!=0){let usize total=meter.total;assert(budget::reset(ref mut meter,0).is_ok);
            assert(slice_work::finish_advance(ref mut p,ref names,ref captures,ref t,ref args,ref mut w,ref mut meter).is_ok && meter.total==total && !slice_work::prepared(ref w).is_ok);
            var usize result=0;let usize parent=w.parent;let usize row=w.index;
            if(w.request==1){result=switch(reborrow::derived(ref mut p,parent,7)){case .ok(v):{v}case .err(_):{assert(false);0}};}
            else if(w.request==2){result=p.count;assert(ir::call(ref mut p,0,ref args,7).is_ok);}
            else{result=switch(arrays::release_at(ref captures,ref mut p,row,7)){case .ok(v):{v}case .err(_):{assert(false);0}};}
            assert(slice_work::resume(ref mut w,result).is_ok && !slice_work::resume(ref mut w,result).is_ok);}
        turns+=1;}
    assert(slice_work::prepared(ref w).is_ok && p.count==4);let usize total=meter.total;let usize value=w.value;
    assert(slice_work::finish_advance(ref mut p,ref names,ref captures,ref t,ref args,ref mut w,ref mut meter).is_ok && meter.total==total);
    var locals::Table published=locals::empty();w=slice_work::publish_begin(value,7);turns=0;
    while(!w.done){assert(turns<10000);let usize size=published.count;let usize visits=w.visits;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);
        assert(slice_work::publish_advance(ref p,ref mut published,ref mut w,ref mut meter).is_ok && published.count==size && w.visits==visits);
        assert(budget::reset(ref mut meter,0).is_ok && slice_work::publish_advance(ref p,ref mut published,ref mut w,ref mut meter).is_ok && published.count-size<=1);turns+=1;}
    assert(w.value==1 && published.count==2);let usize end=meter.total;
    assert(slice_work::publish_advance(ref p,ref mut published,ref mut w,ref mut meter).is_ok && meter.total==end);
}
@test fn void reference_dependency_mapping_cleanup_and_publication_yield(){
    var ir::Program p=ref_fixture();let locals::Table captures=ref_captures();let functions::Table t=ref_signature();let usize[1] args=[160];
    var ref_work::State w=ref_work::call_begin(0,captures.count,0,9);var budget::State meter=budget::empty();var usize turns=0;
    assert(!ref_work::prepared(ref w).is_ok && !ref_work::resume(ref mut w,0).is_ok);
    while(!w.done){assert(turns<10000);let usize count=p.count;let usize row=w.row;let usize pc=w.pc;let u8 phase=w.phase;let usize visits=w.visits;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);
        assert(ref_work::call_advance(ref mut p,ref t,ref captures,ref args,ref mut w,ref mut meter).is_ok && w.phase==phase && w.row==row && w.pc==pc && w.visits==visits && p.count==count);
        assert(budget::reset(ref mut meter,0).is_ok && ref_work::call_advance(ref mut p,ref t,ref captures,ref args,ref mut w,ref mut meter).is_ok && p.count-count<=1);
        if(w.request==1){let usize total=meter.total;assert(budget::reset(ref mut meter,0).is_ok);
            assert(ref_work::call_advance(ref mut p,ref t,ref captures,ref args,ref mut w,ref mut meter).is_ok && meter.total==total && !ref_work::prepared(ref w).is_ok);
            let usize index=w.index;let usize released=switch(arrays::release_at(ref captures,ref mut p,index,9)){case .ok(v):{v}case .err(_):{assert(false);0}};
            assert(ref_work::resume(ref mut w,released).is_ok && !ref_work::resume(ref mut w,released).is_ok);}
        turns+=1;}
    assert(w.value==192 && p.count==2);let usize total=meter.total;
    assert(ref_work::call_advance(ref mut p,ref t,ref captures,ref args,ref mut w,ref mut meter).is_ok && meter.total==total);
    var locals::Table published=locals::empty();w=ref_work::publish_begin(0,9);turns=0;
    while(!w.done){assert(turns<10000);let usize size=published.count;let u8 phase=w.phase;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);
        assert(ref_work::publish_advance(ref p,ref t,ref mut published,ref mut w,ref mut meter).is_ok && published.count==size && w.phase==phase);
        assert(budget::reset(ref mut meter,0).is_ok && ref_work::publish_advance(ref p,ref t,ref mut published,ref mut w,ref mut meter).is_ok && published.count-size<=1);turns+=1;}
    assert(w.value==1 && published.count==1);let usize end=meter.total;
    assert(ref_work::publish_advance(ref p,ref t,ref mut published,ref mut w,ref mut meter).is_ok && meter.total==end);
}
