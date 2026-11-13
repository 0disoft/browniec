module tests::m2::value_buffer_depth_probe;
import value_buffer_call_work as work;
import value_buffer_source as buffers;
import value_source_context as context;
import value_source_bindings as bindings;
import metadata_budget as budget;
import lexer as lexer;
import value_source as source;
import value_view_source_work as view_work;
import value_view_source as views;
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
fn void compare_kind(ref u8[] input,bool success,u8 kind){var values::Program a=empty();var values::Program b=empty();
    let Result<usize,errors::Error> x=source::lower_candidate(input,ref mut a,false);let Result<usize,errors::Error> y=source::lower_candidate(input,ref mut b,true);same(ref a,ref b);
    switch(x){case .ok(n):{assert(success);assert(switch(y){case .ok(m):{n==m}case .err(_):{false}});
        assert(verifier::inspect_values(ref b).is_ok);let growth::Limits limits=growth::Limits{.object=4096,.instance=1048576,.engine=1048576};
        assert(switch(vm::run_values(ref b,10000000,0,limits)){case .ok(v):{v==42}case .err(_):{false}});}
        case .err(e):{assert(!success && (kind==0 || e.kind==kind));assert(switch(y){case .ok(_):{false}case .err(z):{e.kind==z.kind && e.offset==z.offset}});}};
}

fn void probe(bool staged){
    var usize depth=32;while(depth<=33){var bytes::Buffer input=bytes::empty();assert(bytes::append(ref mut input,b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,0);if(").is_ok);var usize i=0;
        while(i<depth){assert(bytes::append(ref mut input,b"bytes::read(ref b,").is_ok);i+=1;}assert(bytes::append(ref mut input,b"0").is_ok);i=0;
        while(i<depth){assert(bytes::append(ref mut input,b")").is_ok);if(i+1<depth){assert(bytes::append(ref mut input,b" as usize").is_ok);}i+=1;}
        assert(bytes::append(ref mut input,b"==0){return 42;}return 0;}").is_ok);var values::Program p=empty();switch(source::lower_candidate(bytes::view(ref input),ref mut p,staged)){case .ok(_):{assert(depth==32);}case .err(e):{assert(depth==33 && e.kind==4);}};depth+=1;}
}

@test fn void raw_special_depth(){probe(false);}
@test fn void staged_special_depth(){probe(true);}
