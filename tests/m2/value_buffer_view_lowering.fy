module tests::m2::value_buffer_view_lowering;
import value_buffer_call_work as work;
import value_buffer_source as buffers;
import value_source_context as context;
import value_source_bindings as bindings;
import metadata_budget as budget;
import lexer as lexer;
import value_source as source;
import value_ir as values;
import value_properties as properties;
import value_source_functions as functions;
import functions as signatures;
import ir as ir;
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

@test fn void buffer_operations_match_raw_candidates_and_execute_once(){
    compare(b"module main;fn i32 main(){var b=bytes::empty();var s=bytes::empty();_ = bytes::reserve(ref mut b,8);_ = bytes::push(ref mut b,7);bytes::write(ref mut b,0,40);_ = bytes::push(ref mut s,2);_ = bytes::append(ref mut b,ref s);return if(bytes::len(ref b)==2 && bytes::read(ref b,0)==40 && bytes::read(ref b,1)==2){42}else{0};}",true);
    compare(b"module main;fn i32 main(){var b=brownie::bytes::empty();_ = brownie::bytes::push(ref mut b,42);return if(brownie::bytes::len(ref b)==1){42}else{0};}",true);
    compare(b"module main;fn i32 main(){var b=bytes::empty();var count=bytes::empty();_ = bytes::push(ref mut b,0);bytes::write(ref mut b,if(true){_ = bytes::push(ref mut count,1);0}else{0},42);return if(bytes::len(ref count)==1 && bytes::read(ref b,0)==42){42}else{0};}",true);
    compare(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,if(true){return 42;}else{0});return 0;}",true);
    compare(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,1);_ = bytes::append(ref mut b,ref b);return 42;}",false);
    compare(b"module main;fn i32 main(){let bytes=42;_ = bytes::empty();return 42;}",false);
    compare(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::read(ref b,);return 42;}",false);
    compare(b"module main;fn i32 main(){var b=bytes::empty();bytes::write(ref mut b,if(true){return 42;}else{0},1);return 0;}",true);
    compare(b"module main;fn i32 main(){var b=bytes::empty();bytes::write(ref mut b,if(true){return 42;}else{return 0;},1);return 0;}",false);
    compare(b"module main;fn i32 main(){let b=bytes::empty();_ = bytes::push(ref mut b,42);return 42;}",false);
    compare(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref b,42);return 42;}",false);
    compare(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::len(ref mut b);return 42;}",false);
    compare(b"module main;fn i32 main(){_ = bytes::unknown();return 42;}",false);
    compare(b"module main;fn i32 main(){_ = bytes::empty(42);return 42;}",false);
}
@test fn void buffer_call_cursor_waits_and_resumes_children_without_publishing(){
    let ref u8[] input=b"brownie::bytes::write(ref mut b,0,42)";var lexer::State s=lexer::empty();assert(lexer::next(input,ref mut s).is_ok);
    var work::State w=work::begin(64,0,0);var budget::State meter=budget::empty();var usize turns=0;var usize expressions=0;var usize loans=0;var usize finals=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<160);let u8 phase=w.phase;let usize cursor=s.cursor;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(input,ref mut s,ref mut w,ref mut meter).is_ok && w.phase==phase && cursor==s.cursor && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(input,ref mut s,ref mut w,ref mut meter).is_ok);
        if(w.request!=0){let u8 request=w.request;assert(budget::reset(ref mut meter,0).is_ok && work::advance(input,ref mut s,ref mut w,ref mut meter).is_ok && meter.last==0);
            if(request==1){assert(lexer::next(input,ref mut s).is_ok);expressions+=1;}if(request==3){loans+=1;}if(request==10){assert(s.kind==0);finals+=1;}
            assert(work::resume(ref mut w,request,context::scalar(0,0),if(request==7){64}else{0}).is_ok && !work::resume(ref mut w,request,context::nothing(),0).is_ok);}
        turns+=1;}
    assert(expressions==3 && loans==1 && finals==1);let usize total=meter.total;assert(work::advance(input,ref mut s,ref mut w,ref mut meter).is_ok && total==meter.total);
}
@test fn void buffer_finish_separates_children_and_completion_is_inert(){
    var values::Program p=empty();p.body.function_count=1;var bindings::State s=bindings::empty();var buffers::Finish w=buffers::finishing(95,buffers::none(),buffers::none(),0,0,64,7);var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){let u8 phase=w.phase;let usize count=p.body.count;assert(budget::reset(ref mut meter,7).is_ok && budget::admit(ref mut meter,1,7).is_ok);
        assert(buffers::advance_finish(ref mut p,ref mut s,ref mut w,ref mut meter).is_ok && phase==w.phase && p.body.count==count);
        assert(budget::reset(ref mut meter,7).is_ok && buffers::advance_finish(ref mut p,ref mut s,ref mut w,ref mut meter).is_ok);turns+=1;assert(turns<10);}
    assert(turns==3 && p.body.count==1 && s.next==1 && s.live==1);let usize total=meter.total;assert(buffers::advance_finish(ref mut p,ref mut s,ref mut w,ref mut meter).is_ok && total==meter.total && p.body.count==1);
}
