module tests::m2::value_walk_lowering;
import value_walk_work as work;
import value_source as source;
import value_ir as values;
import value_properties as properties;
import value_source_functions as functions;
import functions as signatures;
import lexer as lexer;
import ir as ir;
import metadata_budget as budget;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;
import errors as errors;
import std::bytes as bytes;
fn values::Program empty(){return values::Program{.body=ir::empty(),.catalog=properties::empty(),.types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};}
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
fn void compare(ref u8[] input,bool success){var values::Program a=empty();var values::Program b=empty();
    let Result<usize,errors::Error> x=source::lower_candidate(input,ref mut a,false);let Result<usize,errors::Error> y=source::lower_candidate(input,ref mut b,true);same(ref a,ref b);
    switch(x){case .ok(n):{assert(success);assert(switch(y){case .ok(m):{n==m}case .err(_):{false}});
        assert(verifier::inspect_values(ref b).is_ok);let growth::Limits limits=growth::Limits{.object=4096,.instance=1048576,.engine=1048576};
        assert(switch(vm::run_values(ref b,10000000,0,limits)){case .ok(v):{v==42}case .err(_):{false}});}
        case .err(e):{assert(!success);assert(switch(y){case .ok(_):{false}case .err(z):{e.kind==z.kind && e.offset==z.offset}});}};
}
@test fn void typed_source_walks_preserve_raw_ir_catalogs_calls_scopes_and_owned_control(){
    compare(b"module main;fn void noop(){}fn i32 add(i32 x){return x+1;}fn i32 main(){noop();{let Option<i64> x=.some(42);_ = x;}return add(41);}",true);
    compare(b"module main;fn i32 main(){var i=0;for(;i<3;i+=1){if(i==1){continue;}}let Option<Buffer> x=.some(bytes::empty());switch(x){case .some(b):{_ = b;return 42;}case .none:{return 0;}}}",true);
    compare(b"module main;fn i32 main(){let n=if(false){0}else if(true){if(false){return 0;}42}else{0};return n;}",true);
    compare(b"module main;fn i32 main(){var a=bytes::empty();if(false){_ = a;}else{}a=bytes::empty();_ = a;return 42;}",true);
}
@test fn void typed_source_walk_failures_keep_raw_partial_candidates_and_diagnostics(){
    compare(b"module main;fn i32 main(){return 42;let x=1;}",false);
    compare(b"module main;fn i32 main(){let x=if(true){}else{42};return x;}",false);
    compare(b"module main;fn i32 main(){let a=bytes::empty();if(false){_ = a;}_ = a;return 42;}",false);
    compare(b"module main;fn i32 main(){let x=1;}",false);
    compare(b"module main;fn void f(){let i=1;}fn i32 main(){f();return 42;}",true);
    compare(b"module main;fn i32 main(){let x=if(true){return 42;}else{0};return x;}",true);
    compare(b"module main;fn i32 main(){return (20+1)*2;}",true);
    compare(b"module main;fn i32 main(){let i64 x=(40 as i64)+2;return if(x==42){42}else{0};}",true);
    compare(b"module main;fn i32 main(){let i64 x=-9223372036854775808;return if(x==-9223372036854775808){42}else{0};}",true);
    compare(b"module main;fn i32 main(){let x=~(-43);return x;}",true);
    compare(b"module main;fn i32 main(){let Option<i32> x=.some(42);return if((x).is_some){42}else{0};}",true);
    compare(b"module main;fn i32 main(){return (if(true){return 42;}else{return 0;}) as i64;}",true);
    compare(b"module main;fn i32 main(){return (42+);}",false);
    compare(b"module main;fn i32 main(){return (if(true){return 42;}else{return 0;}).is_ok;}",false);
}
@test fn void scope_requests_guard_waiting_denial_completion_and_yield_errors(){
    var lexer::State s=lexer::empty();s.kind=2;s.begin=7;var work::Scope w=work::scope(0,false);var budget::State meter=budget::empty();
    assert(!work::scope_result(ref w).is_ok && !work::resume_scope(ref mut w,1,work::outcome(false,false)).is_ok);
    assert(budget::admit(ref mut meter,1,0).is_ok && work::advance_scope(ref s,3,ref mut w,ref mut meter).is_ok && w.phase==0 && w.mark==0);
    assert(budget::reset(ref mut meter,0).is_ok && work::advance_scope(ref s,3,ref mut w,ref mut meter).is_ok && w.mark==3);
    assert(budget::reset(ref mut meter,0).is_ok && work::advance_scope(ref s,9,ref mut w,ref mut meter).is_ok && w.request==1);
    assert(budget::reset(ref mut meter,0).is_ok && work::advance_scope(ref s,9,ref mut w,ref mut meter).is_ok && meter.last==0 && w.mark==3);
    assert(work::resume_scope(ref mut w,1,work::outcome(false,false)).is_ok && !work::resume_scope(ref mut w,1,work::outcome(false,false)).is_ok);
    s.kind=125;assert(budget::reset(ref mut meter,0).is_ok && work::advance_scope(ref s,3,ref mut w,ref mut meter).is_ok);
    assert(budget::reset(ref mut meter,0).is_ok && work::advance_scope(ref s,3,ref mut w,ref mut meter).is_ok && w.request==2);
    assert(work::resume_scope(ref mut w,2,work::outcome(false,false)).is_ok);assert(budget::reset(ref mut meter,0).is_ok && work::advance_scope(ref s,3,ref mut w,ref mut meter).is_ok && w.done);
    let usize total=meter.total;assert(work::advance_scope(ref s,3,ref mut w,ref mut meter).is_ok && meter.total==total);
    w=work::scope(33,false);assert(budget::reset(ref mut meter,0).is_ok && !work::advance_scope(ref s,0,ref mut w,ref mut meter).is_ok);
    w=work::scope(0,true);assert(budget::reset(ref mut meter,0).is_ok && work::advance_scope(ref s,0,ref mut w,ref mut meter).is_ok);
    assert(budget::reset(ref mut meter,0).is_ok && work::advance_scope(ref s,0,ref mut w,ref mut meter).is_ok);
    assert(budget::reset(ref mut meter,0).is_ok && !work::advance_scope(ref s,0,ref mut w,ref mut meter).is_ok && w.request==0);
}
@test fn void program_walk_maps_one_function_per_stage_and_services_children_once(){
    let ref u8[] input=b"module main;fn void f(){}fn i32 main(){return 42;}";var values::Program unit=empty();
    let signatures::Table table=switch(signatures::scan_values(input,ref mut unit.catalog)){case .ok(v):{v}case .err(_):{assert(false);signatures::empty()}};let functions::Plan plan=switch(functions::prepare(ref unit.catalog,ref table)){case .ok(v):{v}case .err(_):{assert(false);functions::Plan{.results=[0;16],.parameters=[0;128]}}};
    var lexer::State s=lexer::empty();var work::Program w=work::program();var budget::State meter=budget::empty();var usize turns=0;var usize bodies=0;var usize cleanups=0;
    while(!w.done){assert(turns<1000);let usize row=w.row;let u8 phase=w.phase;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance_program(input,ref mut unit,ref table,ref plan,ref mut s,ref mut w,ref mut meter).is_ok && meter.total==total && row==w.row && phase==w.phase);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance_program(input,ref mut unit,ref table,ref plan,ref mut s,ref mut w,ref mut meter).is_ok);
        if(phase==1 && row<table.count){assert(w.row==row+1);}
        if(w.request!=0){let u8 request=w.request;
            assert(budget::reset(ref mut meter,0).is_ok && work::advance_program(input,ref mut unit,ref table,ref plan,ref mut s,ref mut w,ref mut meter).is_ok && meter.last==0);
            if(request==3){s.begin=table.body_ends[w.row];bodies+=1;}if(request==4){cleanups+=1;}
            let bool terminal=request==3 && w.row==1;assert(work::resume_program(ref mut w,request,terminal).is_ok && !work::resume_program(ref mut w,request,false).is_ok);}
        turns+=1;
    }assert(bodies==2 && cleanups==1 && unit.body.return_types[0]==13 && unit.body.return_types[1]==1);
    let usize total=meter.total;assert(work::advance_program(input,ref mut unit,ref table,ref plan,ref mut s,ref mut w,ref mut meter).is_ok && meter.total==total);
}
