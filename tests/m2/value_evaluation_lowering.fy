module tests::m2::value_evaluation_lowering;
import value_expression_work as work;
import value_source_context as context;
import value_source_bindings as bindings;
import value_ir as values;
import value_properties as properties;
import lexer as lexer;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
fn void same_body(ref ir::Program a,ref ir::Program b){
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
fn void same(ref values::Program a,ref values::Program b){
    same_body(ref a.body,ref b.body);
    var usize i=0;while(i<128){assert(a.parameters[i]==b.parameters[i]);i+=1;}
    i=0;while(i<16){assert(a.types[i]==b.types[i] && a.functions[i]==b.functions[i] && a.results[i]==b.results[i]);i+=1;}
    assert(a.catalog.count==b.catalog.count);i=0;while(i<64){let properties::Node p=a.catalog.nodes[i];let properties::Node q=b.catalog.nodes[i];assert(p.kind==q.kind && p.first==q.first && p.second==q.second && p.extent==q.extent);i+=1;}
    assert(a.catalog.records.count==b.catalog.records.count);i=0;while(i<32){assert(a.catalog.records.fields[i]==b.catalog.records.fields[i]);i+=1;}
    i=0;while(i<512){assert(a.catalog.records.kinds[i]==b.catalog.records.kinds[i] && a.catalog.records.types[i]==b.catalog.records.types[i]);i+=1;}
}

fn values::Program base(){var values::Program p=values::Program{.body=ir::empty(),.catalog=properties::empty(),.types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};p.body.function_count=1;
    p.catalog.count=2;p.catalog.nodes[0]=properties::Node{.kind=1,.first=1,.second=0,.extent=0};p.catalog.nodes[1]=properties::Node{.kind=4,.first=0,.second=0,.extent=0};return p;}
fn Result<usize,errors::Error> raw(ref mut values::Program p,ref mut bindings::State s,context::Value v,u8 mode){
    if(mode==0){return context::capture_raw(p,s,v,7);}if(mode==1){return context::as_scalar_raw(p,s,v,7);}if(mode==2){return context::as_value_raw(p,s,v,7);}return context::discard_value_raw(p,s,v,7);}
fn Result<usize,errors::Error> staged(ref mut values::Program p,ref mut bindings::State s,context::Value v,u8 mode){
    if(mode==0){return context::capture(p,s,v,7);}if(mode==1){return context::as_scalar(p,s,v,7);}if(mode==2){return context::as_value(p,s,v,7);}return context::discard_value(p,s,v,7);}
fn void result(Result<usize,errors::Error> x,Result<usize,errors::Error> y){switch(x){case .ok(a):{assert(switch(y){case .ok(b):{a==b}case .err(_):{false}});}case .err(a):{assert(switch(y){case .ok(_):{false}case .err(b):{a.kind==b.kind && a.offset==b.offset}});}};}
@test fn void captures_reads_moves_and_discards_keep_raw_partial_ir_and_liveness(){
    var usize scenario=0;while(scenario<4){var u8 mode=0;while(mode<4){var values::Program a=base();var bindings::State x=bindings::empty();
        let usize type=if(scenario==1){1}else{0};a.types[0]=if(scenario==1){2}else{1};x.next=1;x.live=if(scenario==2){0}else{1};x.names.count=1;x.bindings[0]=1;x.names.registers[0]=208;
        if(scenario==3){a.body.count=256;}
        var values::Program b=a;var bindings::State y=x;let context::Value v=context::Value{.exact=type,.value=0,.typed=true,.nothing=false,.bottom=false,.binding=0};
        result(raw(ref mut a,ref mut x,v,mode),staged(ref mut b,ref mut y,v,mode));same(ref a,ref b);
        assert(x.next==y.next && x.live==y.live && x.maybe==y.maybe && x.pending==y.pending && x.required==y.required && x.generated==y.generated && x.kills==y.kills && x.names.count==y.names.count);
        mode+=1;}scenario+=1;}
}
@test fn void capture_children_wait_once_and_do_not_replay_reads_or_drops(){
    let values::Program p=base();let bindings::State s=bindings::empty();var context::Capture w=context::capturing(context::owned(0,0),7,1);var budget::State meter=budget::empty();var usize turns=0;var usize children=0;
    assert(!context::capture_result(ref w).is_ok);
    while(!w.done){assert(turns<30);let u8 phase=w.phase;assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(context::advance_capture(ref p,ref s,ref mut w,ref mut meter).is_ok && w.phase==phase && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok && context::advance_capture(ref p,ref s,ref mut w,ref mut meter).is_ok);
        if(w.request!=0){let u8 request=w.request;assert(budget::reset(ref mut meter,0).is_ok && context::advance_capture(ref p,ref s,ref mut w,ref mut meter).is_ok && meter.last==0);
            assert(context::resume_capture(ref mut w,request,if(request==2){6}else{0}).is_ok && !context::resume_capture(ref mut w,request,0).is_ok);children+=1;}turns+=1;}
    assert(children==3 && switch(context::capture_result(ref w)){case .ok(v):{v==6}case .err(_):{false}});
    let usize total=meter.total;assert(context::advance_capture(ref p,ref s,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void evaluation_waits_for_operands_and_guards_denied_completed_advances(){
    let ref u8[] input=b"42;";var lexer::State s=lexer::empty();assert(lexer::next(input,ref mut s).is_ok);var values::Program p=base();var work::State w=work::begin(64,1,0,0);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<20);let u8 phase=w.phase;assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(input,ref mut s,ref mut p,ref mut w,ref mut meter).is_ok && w.phase==phase && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(input,ref mut s,ref mut p,ref mut w,ref mut meter).is_ok);
        if(w.request==1){assert(budget::reset(ref mut meter,0).is_ok && work::advance(input,ref mut s,ref mut p,ref mut w,ref mut meter).is_ok && meter.last==0);
            assert(lexer::next(input,ref mut s).is_ok && work::resume_value(ref mut w,1,context::scalar(0,0)).is_ok && !work::resume_value(ref mut w,1,context::nothing()).is_ok);}turns+=1;}
    let usize total=meter.total;assert(work::advance(input,ref mut s,ref mut p,ref mut w,ref mut meter).is_ok && meter.total==total && p.body.count==0);
}
