module compiler;

import function_scan_work as signature_scan;

import host_catalog as host_catalog;
import host_source as host_source;
import host_program as host_program;

import errors as errors;
import runtime_clock as clock;
import lexer as lexer;
import ir as ir;
import locals as locals;
import local_inference as inference;
import declaration_header_work as declaration_headers;
import aggregate_inference as aggregate_inference;
import reference_inference as reference_inference;
import array_local_source as array_locals;
import std::vec as vec;
import functions as functions;
import struct_source as structs;
import struct_scan_work as struct_scan;
import struct_value_source as record_values;
import types as types;
import loops as loops;
import patterns as patterns;
import value_arm_syntax as arm_syntax;
import value_join_source as joins;
import conditional_evaluation_work as value_work;
import record_evaluation_work as record_work;
import static_evaluation_work as static_work;
import propagation as propagation;
import casts as casts;
import array_source as arrays;
import place_source as places;
import aggregate_place_source as aggregate_stores;
import place_syntax as place_syntax;
import slice_place_ir as slice_places;
import record_place_ir as record_places;
import array_call_source as array_calls;
import call_prefix_source as call_prefix;
import struct_call_source as record_calls;
import array_result_source as array_results;
import array_expression_source as array_expressions;
import record_expression_source as record_expressions;
import struct_result_source as record_results;
import std::text as text;
import text_source as text_source;
import slice_source as slices;
import slice_call_source as slice_calls;
import slice_builders as slice_builders;
import slice_reborrow_ir as reborrow;
import slice_result_origins as slice_origins;
import slice_result_ir as slice_result_ir;
import slice_result_verifier as slice_result_verifier;
import slice_result_range_source as return_ranges;
import slice_result_source_origins as source_origins;
import slice_result_call_source as result_calls;
import literal_collection as literal_collection;
import literal_collection_work as literal_work;
import literal_source as literal_source;
import static_builders as static_builders;
import static_source as static_source;
import static_image as static_images;
import program_image as program_images;
import reference_call_source as reference_calls;
import static_call_ir as reference_ir;
import reference_result_source as reference_results;
import source_features as source_features;
import source_context as source_context;
import source_context_work as collecting;
import module_source_work as module_source;
import module_entry as module_entries;
import module_input_entry as input_entries;
import source_error as source_errors;
import source_snapshot as source_snapshot;
import module_index as module_index;
import output_source as output_source;
import output_ir as output_ir;
import output_return_ir as output_returns;
import body_source_work as body_work;
import expression_source_work as expression_work;
import call_operand_work as call_operand_work;
import aggregate_call_source_work as aggregate_calls;
import argument_source_work as argument_work;
import argument_name_work as argument_names;
import semantic_source_work as semantic_work;
import metadata_budget as metadata_budget;
import aggregate_probe_work as aggregate_work;
import operand_route_work as route_work;

import std::vec as scratch_vec;

// Single initialized element; the SDK owns alignment and deterministic cleanup.
// Initialization temporaries return before any nested expression is evaluated.
fn Result<scratch_vec::Vec<expression_work::Bank>,errors::Error> expression_scratch(usize at){
    var scratch_vec::Vec<expression_work::Bank> scratch=scratch_vec::empty<expression_work::Bank>();
    switch(scratch_vec::push<expression_work::Bank>(ref mut scratch,expression_work::empty_bank())){
        case .ok(_):{}case .err(_):{return .err(errors::make(15,at));}};
    return .ok(scratch);
}
fn Result<scratch_vec::Vec<expression_work::State>,errors::Error> expression_state(usize depth,u8 minimum,u8 expected,usize at){
    var scratch_vec::Vec<expression_work::State> scratch=scratch_vec::empty<expression_work::State>();
    switch(scratch_vec::push<expression_work::State>(ref mut scratch,expression_work::begin(depth,minimum,expected))){
        case .ok(_):{}case .err(_):{return .err(errors::make(15,at));}};
    return .ok(scratch);
}
fn Result<scratch_vec::Vec<value_work::State>,errors::Error> conditional_scratch(ref locals::Table names,usize depth,usize structure,u8 result_type,usize at){
    var scratch_vec::Vec<value_work::State> scratch=scratch_vec::empty<value_work::State>();
    switch(scratch_vec::push<value_work::State>(ref mut scratch,value_work::begin(names,depth,structure,result_type))){
        case .ok(_):{}case .err(_):{return .err(errors::make(15,at));}};
    return .ok(scratch);
}
fn u8 precedence(u8 kind) {
    if (kind == 133) { return 1; }
    if (kind == 132) { return 2; }
    if (kind == 124) { return 3; }
    if (kind == 94) { return 4; }
    if (kind == 38) { return 5; }
    if (kind == 128 || kind == 129) { return 6; }
    if (kind == 60 || kind == 62 || kind == 130 || kind == 131) { return 7; }
    if (kind == 134 || kind == 135) { return 8; }
    if (kind == 43 || kind == 45) { return 9; }
    if (kind == 42 || kind == 47 || kind == 37) { return 10; }
    return 0;
}
fn u8 opcode(u8 kind) {
    if (kind == 134) { return 31; }
    if (kind == 135) { return 32; }
    if (kind == 38) { return 28; }
    if (kind == 94) { return 29; }
    if (kind == 124) { return 30; }
    if (kind == 128) { return 11; }
    if (kind == 129) { return 12; }
    if (kind == 60) { return 13; }
    if (kind == 130) { return 14; }
    if (kind == 62) { return 15; }
    if (kind == 131) { return 16; }
    if (kind == 43) { return 2; }
    if (kind == 45) { return 3; }
    if (kind == 42) { return 4; }
    if (kind == 47) { return 5; }
    return 6;
}
fn Result<usize, errors::Error> operand(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    if(depth>signatures.semantic_depth){return .err(errors::make(4,s.begin));}
    let u8 control=arm_syntax::operand_kind(source,s);
    if(control!=0){return conditional_operand(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state,deadline,fuel);}
    if(s.kind==2 || s.kind==5){return named_operand(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state,deadline,fuel);}
    return compound_operand(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state,deadline,fuel);
}
fn Result<usize, errors::Error> compound_operand(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    if(depth>signatures.semantic_depth){return .err(errors::make(4,s.begin));}
    let ref literal_collection::Index literals=ref signatures.literals;
    let usize at = s.begin;
    if(s.kind==40 && arm_syntax::conditional_atom_metered(source,s,deadline,fuel)?.valid){
        return conditional_operand(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state,deadline,fuel);
    }
    if(record_expressions::projected(source,s,p,table,signatures)?){
        return record_expression_read(source,s,p,table,signatures,at,depth,result_type,structure,loop_state);
    }
    if(s.kind==40 && array_expressions::projected(source,s,p,table,signatures)?){
        return array_grouped_projection(source,s,p,table,signatures,at,depth,result_type,structure,loop_state);
    }
    if(s.kind==91 || s.kind==40){
        let array_locals::Projection view=array_locals::projection(source,s)?;
        if(view.kind!=0){return array_literal_projection(source,s,p,table,signatures,view,at,depth,expected,result_type,structure,loop_state);}
        if(s.kind==91){return .err(errors::make(3,at));}
    }
    if(s.kind==3 && literals.enabled){
        var lexer::State look=lexer::snapshot(s);let usize next=lexer::next_with_budget(source,ref mut look,deadline,fuel)?;
        if(static_source::range_follows(source,ref look)?){
            let static_source::View view=static_view(source,s,p,table,signatures,depth,result_type,structure,loop_state)?;
            return static_projection(source,s,p,table,signatures,ref view,at,depth,result_type,structure,loop_state);
        }
        return literal_projection(source,s,p,table,signatures,depth,result_type,structure,loop_state,false);
    }
    if (s.kind == 46) {
        if (expected!=0 && !types::tagged(expected) && !types::host_result_type(expected)) {return .err(errors::make(3,at));}
        let usize dot=lexer::next_with_budget(source,s,deadline,fuel)?;
        let bool positive=word_is(source,s,b"some") || word_is(source,s,b"ok");
        if(expected==0){
            // Only Option's positive constructor carries its complete type.
            // No default payload/error domain is invented for none/ok/err.
            if(!word_is(source,s,b"some")){return .err(errors::make(3,at));}
        }else if (expected<=4) {
            if (!word_is(source,s,b"some") && !word_is(source,s,b"none")) {return .err(errors::make(3,at));}
        } else if (!word_is(source,s,b"ok") && !word_is(source,s,b"err")) {return .err(errors::make(3,at));}
        let u8 variant=if(positive) {1} else {0};
        let u8 payload_type=if(types::host_result_type(expected)){if(variant==0){11}else{expected-128}}
            else if(expected==0){0}else{types::payload(expected,variant)};
        let usize name=lexer::next_with_budget(source,s,deadline,fuel)?;
        var usize value=0;
        if (payload_type!=0 || expected==0) {
            let usize open=lexer::punctuation_with_budget(source,s,40,deadline,fuel)?;
            value=raw_expression(source,s,p,table,signatures,1,depth+1,payload_type,result_type,structure,loop_state,deadline,fuel)?;
            if (expected!=0 && p.types[value]!=payload_type) {return .err(errors::make(3,at));}
            let usize close=lexer::punctuation_with_budget(source,s,41,deadline,fuel)?;
        }
        var u8 tag=expected;
        if(tag==0){
            tag=if(p.types[value]==1){3}else if(p.types[value]==2){4}else{0};
            if(tag==0){return .err(errors::make(3,at));}
        }
        if(types::host_result_type(tag)){return host_source::wrap(p,tag,variant,value,at);}
        return ir::construct(p,tag,variant,value,at);
    }
    if (s.kind == 45 || s.kind == 33 || s.kind == 126) {
        let bool negative = s.kind == 45;
        let bool complement = s.kind == 126;
        if(negative && types::unsigned(expected)) {return .err(errors::make(3,at));}
        let usize advanced = lexer::next_with_budget(source,s,deadline,fuel)?;
        // Admit a minimum signed literal without constructing its positive magnitude.
        if (negative && s.kind == 1 && s.min_magnitude) {
            if (expected!=9) {return .err(errors::make(3,at));}
            let usize advanced_min=lexer::next_with_budget(source,s,deadline,fuel)?;
            return ir::integer(p,-9223372036854775808,9,at);
        }
        if (negative && s.kind == 1 && s.value == 2147483648 && expected!=9) {
            let usize advanced_min = lexer::next_with_budget(source,s,deadline,fuel)?;
            return ir::literal(p, -2147483648, at);
        }
        let usize operand = primary(source,s,p,table,signatures,depth + 1,expected,result_type,structure,loop_state,deadline,fuel)?;
        if ((negative && !types::signed(p.types[operand])) || (complement && !types::integer(p.types[operand])) ||
            (!negative && !complement && p.types[operand]!=2)) { return .err(errors::make(3, at)); }
        return ir::emit(p, if (negative) { 7 } else if(complement) {27} else { 10 }, operand, 0, at);
    }
    if (s.kind == 1) {
        let u8 tag=if(types::integer(expected)) {expected} else {1};
        if(!types::unsigned(tag) && s.value<0) {return .err(errors::make(3,at));}
        let i64 value = s.value;
        let usize advanced = lexer::next_with_budget(source,s,deadline,fuel)?;
        return ir::integer(p, value, tag, at);
    }
    if (s.kind == 40) {
        if(literals.enabled && static_source::grouped_projection(source,s,table)?){
            let static_source::View view=static_view(source,s,p,table,signatures,depth,result_type,structure,loop_state)?;
            return static_projection(source,s,p,table,signatures,ref view,at,depth,result_type,structure,loop_state);
        }
        let usize advanced = lexer::next_with_budget(source,s,deadline,fuel)?;
        let usize result = raw_expression(source,s,p,table,signatures,1,depth + 1,expected,result_type,structure,loop_state,deadline,fuel)?;
        let usize closed = lexer::punctuation_with_budget(source,s,41,deadline,fuel)?;
        return .ok(result);
    }
    return .err(errors::make(2, s.begin));
}
// Literal evaluation has no guest effect or owning temporary. Evaluate a
// computed index before OPEN, so early returns need no hidden Static cleanup.
fn Result<usize,errors::Error> literal_projection(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,bool text_bytes){
    let usize at=s.begin;
    if(s.kind!=if(text_bytes){4}else{3}){return .err(errors::make(3,at));}
    let usize row=literal_collection::find(ref signatures.literals,s.begin,s.end)?;
    let usize literal=signatures.literals.literals[row];let usize size=signatures.literals.lengths[row];
    let u8 kind=signatures.literals.kinds[row];
    let usize advanced=lexer::next(source,s)?;
    if(text_bytes){let usize call_close=lexer::punctuation(source,s,41)?;}
    let bool length=s.kind==46;var usize index=0;
    if(length){let usize dot=lexer::next(source,s)?;let usize member=lexer::word(source,s,b"len")?;}
    else{
        let usize bracket=lexer::punctuation(source,s,91)?;
        index=expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)?;
        if(p.types[index]!=12){return .err(errors::make(3,at));}
        let usize bracket_close=lexer::punctuation(source,s,93)?;
    }
    var usize site=static_builders::open(p,literal,kind,size,at)?;
    if(text_bytes){let usize text=site;site=static_builders::bytes(p,text,at)?;
        let usize close_text=static_builders::close(p,text,at)?;}
    let usize value=static_builders::scalar(p,site,index,length,at)?;
    let usize closed=static_builders::close(p,site,at)?;return .ok(value);
}
// Owned temporary views join lexical cleanup before evaluating an index, so
// return/propagation/break/continue inside that index cannot leak a live site.
fn Result<usize,errors::Error> static_projection(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    ref static_source::View view,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    if(static_source::range_follows(source,s)?){
        let static_source::View child=static_ranges(source,s,p,table,signatures,view,depth,result_type,structure,loop_state)?;
        return static_projection(source,s,p,table,signatures,ref child,at,depth,result_type,structure,loop_state);
    }
    if(view.kind!=1){return .err(errors::make(3,at));}
    if(!view.owned){return static_read(source,s,p,table,signatures,view.site,at,depth,result_type,structure,loop_state);}
    if(s.kind==46 && (!signatures.reference_returns || reference_results::owners(p,signatures,192+view.site,0,at)?==0)){
        let usize value=static_read(source,s,p,table,signatures,view.site,at,depth,result_type,structure,loop_state)?;
        let usize closed=static_builders::close(p,view.site,at)?;return .ok(value);
    }
    return static_temporary_projection(source,s,p,table,signatures,view.site,at,depth,result_type,structure,loop_state);
}
fn Result<usize,errors::Error> static_projection_staged(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    ref static_source::View view,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State flow){
    if(static_source::range_follows(source,s)?){return static_projection(source,s,p,table,signatures,view,at,depth,result_type,structure,flow);}
    if(view.kind!=1){return .err(errors::make(3,at));}
    let bool captured=view.owned && !(s.kind==46 && (!signatures.reference_returns || reference_results::owners(p,signatures,192+view.site,0,at)?==0));
    var locals::Table names=locals::snapshot(table);
    if(captured){if(signatures.reference_returns){let usize roots=reference_results::publish(p,signatures,ref mut names,view.site,at)?;}
        let usize hidden=locals::declare(ref mut names,at,at,192+view.site,false)?;}
    var static_work::State w=static_work::begin(view.site,at,depth,table.count,view.owned,captured);var metadata_budget::State meter=metadata_budget::empty();
    while(!w.done){let usize allowance=metadata_budget::reset(ref mut meter,s.begin)?;
        let bool done=static_work::advance(source,s,p,ref names,ref mut w,ref mut meter)?;
        if(w.request==1){let usize value=expression_staged(source,s,p,ref names,signatures,1,depth+1,12,result_type,structure,flow)?;
            let usize resumed=static_work::resume(ref mut w,value)?;}
    }return static_work::prepared(ref w);
}
fn Result<usize,errors::Error> static_temporary_projection(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize site,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    var locals::Table names=locals::snapshot(table);
    if(signatures.reference_returns){let usize roots=reference_results::publish(p,signatures,ref mut names,site,at)?;}
    let usize hidden=locals::declare(ref mut names,at,at,192+site,false)?;
    let usize value=static_read(source,s,p,ref names,signatures,site,at,depth,result_type,structure,loop_state)?;
    let usize closed=arrays::release_from(ref names,p,table.count,at)?;return .ok(value);
}
fn Result<usize,errors::Error> static_read(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize site,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    let bool length=s.kind==46;var usize index=0;
    if(length){let usize dot=lexer::next(source,s)?;let usize member=lexer::word(source,s,b"len")?;}
    else{let usize open=lexer::punctuation(source,s,91)?;
        index=expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)?;
        if(p.types[index]!=12){return .err(errors::make(3,at));}let usize close=lexer::punctuation(source,s,93)?;}
    return static_builders::scalar(p,site,index,length,at);
}
// Every owned parent joins lexical cleanup before effectful endpoints.
fn Result<static_source::View,errors::Error> static_view(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    var usize fuel=metadata_budget::unlimited();
    return static_view_metered(source,s,p,table,signatures,depth,result_type,structure,loop_state,0,ref mut fuel);
}
fn Result<static_source::View,errors::Error> static_view_metered(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    if(depth>signatures.semantic_depth){return .err(errors::make(4,s.begin));}
    let usize at=s.begin;var static_source::View value=static_source::View{.site=16,.kind=0,.owned=false};
    if(word_is(source,s,b"ref")){let usize prefix=lexer::next_metered(source,s,deadline,fuel)?;}
    if(reference_calls::returned_atom_metered(source,s,table,signatures,deadline,fuel)?){
        let usize target=functions::find(source,signatures,s.begin,s.end);let usize name=lexer::next_metered(source,s,deadline,fuel)?;
        let usize made=captured_call(source,s,p,table,signatures,target,240,at,depth,result_type,structure,loop_state,deadline,fuel)?;
        value=static_source::View{.site=made-192,.kind=1,.owned=true};
    }else if(s.kind==40){let usize open=lexer::next_metered(source,s,deadline,fuel)?;
        value=static_view_metered(source,s,p,table,signatures,depth+1,result_type,structure,loop_state,deadline,fuel)?;
        let usize close=lexer::punctuation_metered(source,s,41,deadline,fuel)?;
    }else if(word_is(source,s,b"text")){
        var lexer::State look=lexer::snapshot(s);let usize next=lexer::next_metered(source,ref mut look,deadline,fuel)?;
        if(look.kind==58){let usize module_name=lexer::next_metered(source,s,deadline,fuel)?;
            let usize colon=lexer::punctuation_metered(source,s,58,deadline,fuel)?;let usize path=lexer::punctuation_metered(source,s,58,deadline,fuel)?;
            let usize method=lexer::word_metered(source,s,b"bytes",deadline,fuel)?;let usize open=lexer::punctuation_metered(source,s,40,deadline,fuel)?;
            value=static_bytes_argument_metered(source,s,p,table,signatures,at,depth+1,result_type,structure,loop_state,deadline,fuel)?;
        }else{value=static_source::atom_metered(source,s,p,table,ref signatures.literals,depth,deadline,fuel)?;}
    }else{value=static_source::atom_metered(source,s,p,table,ref signatures.literals,depth,deadline,fuel)?;}
    return static_ranges_metered(source,s,p,table,signatures,ref value,depth,result_type,structure,loop_state,deadline,fuel);
}
fn Result<static_source::View,errors::Error> static_bytes_argument(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    var usize fuel=metadata_budget::unlimited();
    return static_bytes_argument_metered(source,s,p,table,signatures,at,depth,result_type,structure,loop_state,0,ref mut fuel);
}
fn Result<static_source::View,errors::Error> static_bytes_argument_metered(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let static_source::View text=static_view_metered(source,s,p,table,signatures,depth+1,result_type,structure,loop_state,deadline,fuel)?;
    if(text.kind!=2){return .err(errors::make(3,at));}
    let usize close=lexer::punctuation_metered(source,s,41,deadline,fuel)?;
    discard metadata_budget::visit(fuel,deadline,at)?;
    let usize made=static_builders::bytes(p,text.site,at)?;
    if(text.owned){let usize closed=static_builders::close(p,text.site,at)?;}
    return .ok(static_source::View{.site=made,.kind=1,.owned=true});
}
fn Result<static_source::View,errors::Error> static_ranges(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    ref static_source::View parent,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    var usize fuel=metadata_budget::unlimited();
    return static_ranges_metered(source,s,p,table,signatures,parent,depth,result_type,structure,loop_state,0,ref mut fuel);
}
fn Result<static_source::View,errors::Error> static_ranges_metered(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    ref static_source::View parent,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    var static_source::View value=static_source::View{.site=parent.site,.kind=parent.kind,.owned=parent.owned};
    while(static_source::range_follows_metered(source,s,deadline,fuel)?){
        if(value.kind!=1){return .err(errors::make(3,s.begin));}
        let static_source::View next=if(value.owned){static_owned_range(source,s,p,table,signatures,value.site,depth,result_type,structure,loop_state,deadline,fuel)?}
            else{static_range(source,s,p,table,signatures,value.site,depth,result_type,structure,loop_state,deadline,fuel)?};
        value=next;
    }return .ok(value);
}
fn Result<static_source::View,errors::Error> static_owned_range(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize parent,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let usize at=s.begin;var locals::Table names=locals::snapshot(table);
    if(signatures.reference_returns){let usize roots=reference_results::publish(p,signatures,ref mut names,parent,at)?;}
    let usize hidden=locals::declare(ref mut names,at,at,192+parent,false)?;
    let static_source::View child=static_range(source,s,p,ref names,signatures,parent,depth,result_type,structure,loop_state,deadline,fuel)?;
    let usize closed=if(signatures.reference_returns){
        let usize keep=reference_results::owners(p,signatures,192+child.site,0,at)?;
        reference_results::release(p,ref names,table.count,keep,at)?
    }else{arrays::release_from(ref names,p,table.count,at)?};return .ok(child);
}
fn Result<static_source::View,errors::Error> static_range(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize parent,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let usize at=s.begin;let usize open=lexer::punctuation_metered(source,s,91,deadline,fuel)?;
    let usize lo=if(s.kind==46){ir::integer(p,0,12,at)?}
        else{assignment_operand(source,s,p,table,signatures,depth+1,12,result_type,structure,loop_state,deadline,fuel)?};
    if(p.types[lo]!=12){return .err(errors::make(3,at));}
    let usize first=lexer::punctuation_metered(source,s,46,deadline,fuel)?;let usize second=lexer::punctuation_metered(source,s,46,deadline,fuel)?;
    let usize hi=if(s.kind==93){static_builders::scalar(p,parent,0,true,at)?}
        else{assignment_operand(source,s,p,table,signatures,depth+1,12,result_type,structure,loop_state,deadline,fuel)?};
    if(p.types[hi]!=12){return .err(errors::make(3,at));}
    let usize close=lexer::punctuation_metered(source,s,93,deadline,fuel)?;
    discard metadata_budget::visit(fuel,deadline,at)?;
    let usize site=static_builders::range(p,parent,lo,hi,at)?;
    return .ok(static_source::View{.site=site,.kind=1,.owned=true});
}
fn Result<usize,errors::Error> static_declaration(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    bool mutable,u8 terminator,u8 result_type,usize depth,usize structure,ref mut loops::State loop_state){
    let static_source::Header header=static_source::header(source,s,table,mutable,terminator,result_type)?;
    return static_initializer(source,s,p,table,signatures,header,terminator,result_type,depth,structure,loop_state);
}
fn Result<usize,errors::Error> static_initializer(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    static_source::Header header,u8 terminator,u8 result_type,usize depth,usize structure,ref mut loops::State loop_state){
    let static_source::View value=static_view(source,s,p,table,signatures,depth,result_type,structure,loop_state)?;
    let usize end=lexer::punctuation(source,s,terminator)?;
    if(signatures.reference_returns){let usize roots=reference_results::publish(p,signatures,table,value.site,header.begin)?;}
    return static_source::bind(p,table,ref header,ref value);
}
fn Result<usize,errors::Error> static_equal(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    let usize at=static_source::equal_head(source,s)?;
    let static_source::View left=static_view(source,s,p,table,signatures,depth,result_type,structure,loop_state)?;
    if(left.kind!=1){return .err(errors::make(3,at));}
    if(left.owned){return static_equal_owned(source,s,p,table,signatures,ref left,at,depth,result_type,structure,loop_state);}
    return static_equal_right(source,s,p,table,signatures,left.site,at,depth,result_type,structure,loop_state);
}
fn Result<usize,errors::Error> static_equal_owned(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    ref static_source::View left,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    var locals::Table names=locals::snapshot(table);
    let usize hidden=locals::declare(ref mut names,at,at,192+left.site,false)?;
    let usize value=static_equal_right(source,s,p,ref names,signatures,left.site,at,depth,result_type,structure,loop_state)?;
    let usize closed=arrays::release_from(ref names,p,table.count,at)?;return .ok(value);
}
fn Result<usize,errors::Error> static_equal_right(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize left,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    let usize comma=lexer::punctuation(source,s,44)?;
    let static_source::View right=static_view(source,s,p,table,signatures,depth,result_type,structure,loop_state)?;
    if(right.kind!=1){return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,41)?;let usize value=static_builders::equal(p,left,right.site,at)?;
    if(right.owned){let usize closed=static_builders::close(p,right.site,at)?;}return .ok(value);
}
fn Result<host_source::Invocation,errors::Error> host_invocation(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref locals::Table table,ref functions::Table signatures,usize depth,u8 result_type,usize structure,ref mut loops::State flow,usize deadline,ref mut usize fuel){
    if(result_type==0){return .err(errors::make(3,s.begin));}
    let host_source::Name item=host_source::name(source,s,deadline,fuel)?;
    let host_source::Call call=host_source::signature(p,item.begin,deadline,fuel)?;
    let usize open=lexer::punctuation_with_budget(source,s,40,deadline,fuel)?;
    var usize[32] arguments=[0;32];
    var usize i=0;
    while(i<call.argc){
        if(i!=0){let usize comma=lexer::punctuation_with_budget(source,s,44,deadline,fuel)?;}
        discard metadata_budget::visit(fuel,deadline,s.begin)?;
        let u8 expected=p.list_operands[call.parameters+i];
        let usize value=if(expected==14){host_source::byte_argument_metered(source,s,p,table,deadline,fuel)?}else{
            raw_expression(source,s,p,table,signatures,1,depth+1,expected,result_type,structure,flow,deadline,fuel)?
        };
        if(p.types[value]!=expected){return .err(errors::make(3,item.begin));}
        arguments[i]=value;i+=1;
    }
    let usize close=lexer::punctuation_with_budget(source,s,41,deadline,fuel)?;
    let ref usize[] args=ref arguments;
    return host_source::invoke(p,call,args,item.begin,deadline,fuel);
}
fn Result<usize, errors::Error> named_operand(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state,usize deadline,ref mut usize fuel) {
    if(signatures.scalar_host_calls && host_source::qualified(source,s,p,deadline,fuel)?){
        let host_source::Invocation call=host_invocation(source,s,p,table,signatures,depth,result_type,structure,loop_state,deadline,fuel)?;
        if(s.kind==63 || types::host_result_type(expected)){
            if(types::host_result_type(expected) && expected!=128+call.call.result){return .err(errors::make(3,call.at));}
            return host_source::save(p,ref call);
        }
        return host_source::emit(p,ref call);
    }
    let usize at = s.begin;
    if(record_expressions::projected(source,s,p,table,signatures)?){
        return record_expression_read(source,s,p,table,signatures,at,depth,result_type,structure,loop_state);
    }
    let ref literal_collection::Index literals=ref signatures.literals;
    if (word_is(source, s, b"text")) {
        var lexer::State look = lexer::snapshot(s);
        let usize next = lexer::next(source, ref mut look)?;
        let bool qualified=look.kind==58;
        if(qualified && literals.enabled){
            let usize first=lexer::next(source,ref mut look)?;
            let usize second=lexer::punctuation(source,ref mut look,58)?;
            if(word_is(source,ref look,b"equal")){return static_equal(source,s,p,table,signatures,depth,result_type,structure,loop_state);}
            if(word_is(source,ref look,b"bytes")){
                let usize module_name=lexer::next(source,s)?;
                let usize colon=lexer::punctuation(source,s,58)?;
                let usize path=lexer::punctuation(source,s,58)?;
                let usize method=lexer::word(source,s,b"bytes")?;
                let usize open=lexer::punctuation(source,s,40)?;
                let static_source::View view=static_bytes_argument(source,s,p,table,signatures,at,depth,result_type,structure,loop_state)?;
                return static_projection(source,s,p,table,signatures,ref view,at,depth,result_type,structure,loop_state);
            }
        }
        if (qualified) { return utf8_value(source,s,p,table,signatures,depth,result_type,structure,loop_state); }
    }
    if (word_is(source, s, b"true") || word_is(source, s, b"false")) {
        let bool value = word_is(source, s, b"true");
        let usize advanced = lexer::next(source, s)?;
        return ir::boolean(p, value, at);
    }
    if (locals::reserved(source[s.begin..s.end])) { return .err(errors::make(2, at)); }
    let usize begin = s.begin;
    let usize end = s.end;
    let usize index=argument_names::local_metered(source,table,begin,end,deadline,fuel)?;
    let usize advanced=lexer::next_with_budget(source,s,deadline,fuel)?;
    if (s.kind == 40) {
        if (index != 64) { return .err(errors::make(3, at)); }
        let usize target = functions::find(source, signatures, begin, end);
        if (target == 16 || signatures.return_types[target]==13) { return .err(errors::make(3, at)); }
        if(reference_calls::result(signatures,target)){
            let usize result=call_value(source,s,p,table,signatures,target,240,at,depth,result_type,structure,loop_state)?;
            let static_source::View view=static_source::View{.site=result-192,.kind=1,.owned=true};
            return static_projection(source,s,p,table,signatures,ref view,at,depth,result_type,structure,loop_state);
        }
        if(signatures.return_slice_elements[target]!=0){
            return slice_call_read(source,s,p,table,signatures,target,at,depth,result_type,structure,loop_state,false);
        }
        if(signatures.return_lengths[target]!=0) {
            return array_call_read(source,s,p,table,signatures,target,at,depth,result_type,structure,loop_state);
        }
        if(signatures.return_records[target]!=0) {
            return record_call_read(source,s,p,table,signatures,target,at,depth,result_type,structure,loop_state);
        }
        return call_value(source,s,p,table,signatures,target,16,at,depth,result_type,structure,loop_state);
    }
    return binding_operand(source,s,p,table,signatures,index,at,depth,result_type,structure,loop_state);
}
fn Result<usize, errors::Error> binding_operand(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize index, usize at, usize depth, u8 result_type, usize structure, ref mut loops::State loop_state) {
    if (index == 64) { return .err(errors::make(3, at)); }
    let usize register = table.registers[index];
    if(static_source::binding(table,index)){
        let static_source::View view=static_source::View{.site=static_source::site(register),.kind=static_source::kind(register),.owned=false};
        return static_projection(source,s,p,table,signatures,ref view,at,depth,result_type,structure,loop_state);
    }
    if (record_values::binding(table, index)) { return record_values::read(source, s, p, register - 144, at,ref signatures.context); }
    if (arrays::binding(table, index)) {
        if (s.kind == 46) {
            let usize dot = lexer::next(source, s)?;
            if (!word_is(source, s, b"len")) { return .err(errors::make(3, s.begin)); }
            let usize member = lexer::next(source, s)?;
            return arrays::length_value(p, register - 128, at);
        }
        if (s.kind != 91) { return .err(errors::make(3, at)); }
        let usize open = lexer::punctuation(source, s, 91)?;
        let usize subscript = expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)?;
        if (p.types[subscript] != 12) { return .err(errors::make(3, at)); }
        let usize close = lexer::punctuation(source, s, 93)?;
        return ir::array_read(p, register - 128, subscript, at);
    }
    if (slices::binding(table,index)) {
        if (s.kind == 46) { return slices::member(source,s,p,register-160,at); }
        if (s.kind != 91) { return .err(errors::make(3, at)); }
        let usize open = lexer::next(source, s)?;
        let usize subscript = expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)?;
        if (p.types[subscript] != 12) { return .err(errors::make(3, at)); }
        let usize close = lexer::punctuation(source, s, 93)?;
        return ir::slice_read(p, register-160, subscript, at);
    }
    if (register >= 128 || s.kind == 91) { return .err(errors::make(3, at)); }
    if (p.slots[register]) { return ir::emit(p, 17, register, 0, at); }
    return .ok(register);
}
// A pending UTF-8 call result stays absent from names during argument exits.
// After publication, computed bounds capture their owner for lexical cleanup.
fn Result<usize,errors::Error> utf8_value(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize depth,u8 result_type,usize structure,ref mut loops::State loop_state) {
    let usize at=text_source::begin(source,s)?;
    if(s.kind==40){
        let array_expressions::Value value=array_grouped_value(source,s,p,table,signatures,10,0,false,at,depth,result_type,structure,loop_state)?;
        if(value.owned){return utf8_temporary_range(source,s,p,table,signatures,value.id,at,value.depth,result_type,structure,loop_state);}
        if(text_source::simple(source,s)?){return text_source::predicate(source,s,p,table,value.id,at);}
        return utf8_computed_range(source,s,p,table,signatures,value.id,at,value.depth,result_type,structure,loop_state);
    }
    if(s.kind==91) {
        let usize literal_at=s.begin;
        let usize temporary=array_literal_value(source,s,p,table,signatures,10,0,false,literal_at,depth+1,result_type,structure,loop_state)?;
        return utf8_temporary_range(source,s,p,table,signatures,temporary,at,depth,result_type,structure,loop_state);
    }
    if((s.kind==2 || s.kind==5)) {
        var lexer::State look=lexer::snapshot(s);
        let usize next=lexer::next(source,ref mut look)?;
        if(look.kind==40) {
            let usize call_at=s.begin;
            if(locals::find(source,table,s.begin,s.end)!=64) {return .err(errors::make(3,call_at));}
            let usize target=functions::find(source,signatures,s.begin,s.end);
            if(target>=16 || target>=signatures.count){return .err(errors::make(3,call_at));}
            if(signatures.return_slice_elements[target]!=0){
                if((signatures.return_slice_elements[target]&127)!=10){return .err(errors::make(3,call_at));}
                let usize name=lexer::next(source,s)?;
                return slice_call_read(source,s,p,table,signatures,target,call_at,depth,result_type,structure,loop_state,true);
            }
            if(signatures.return_types[target]!=10 || signatures.return_lengths[target]==0){return .err(errors::make(3,call_at));}
            let usize temporary=array_results::destination(signatures,target,10,
                signatures.return_lengths[target],false,p,table.function,call_at)?;
            let usize name=lexer::next(source,s)?;
            let usize called=call_value(source,s,p,table,signatures,target,temporary,call_at,
                depth+1,result_type,structure,loop_state)?;
            return utf8_temporary_range(source,s,p,table,signatures,temporary,at,depth,result_type,structure,loop_state);
        }
    }
    if ((s.kind==2 || s.kind==5)) {
        let usize index = locals::find(source, table, s.begin, s.end);
        if (slices::binding(table, index)) { return slices::predicate(source,s,p,table,index,at); }
    }
    let usize id=text_source::argument(source,s,p,table)?;
    if(text_source::simple(source,s)?) {return text_source::predicate(source,s,p,table,id,at);}
    return utf8_computed_range(source,s,p,table,signatures,id,at,depth,result_type,structure,loop_state);
}
// Publish no name to guest lookup, but include the owner in every endpoint exit.
// Simple suffixes retain their original lowering and need no capture-table slot.
fn Result<usize,errors::Error> utf8_temporary_range(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize id,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state) {
    if(text_source::simple(source,s)?) {return text_source::temporary(source,s,p,table,id,at);}
    var locals::Table names=locals::snapshot(table);
    let usize capture=locals::declare(ref mut names,at,at,128+id,false)?;
    let usize value=utf8_computed_range(source,s,p,ref names,signatures,id,at,depth,result_type,structure,loop_state)?;
    let usize dropped=ir::array_drop(p,id,at)?;
    return .ok(value);
}
// Named or captured roots remain visible to existing lexical exit cleanup.
// Evaluate and snapshot the start value before any effects in the end expression.
fn Result<usize,errors::Error> utf8_computed_range(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize id,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state) {
    let usize open=lexer::punctuation(source,s,91)?;
    let usize lo=if(s.kind==46) {ir::integer(p,0,12,at)?}
        else {expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)?};
    if(p.types[lo]!=12) {return .err(errors::make(3,at));}
    let usize first=lexer::punctuation(source,s,46)?;
    let usize second=lexer::punctuation(source,s,46)?;
    let usize hi=if(s.kind==93) {arrays::length_value(p,id,at)?}
        else {expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)?};
    if(p.types[hi]!=12) {return .err(errors::make(3,at));}
    let usize bracket=lexer::punctuation(source,s,93)?;
    let usize close=lexer::punctuation(source,s,41)?;
    return ir::array_dynamic_utf8(p,id,lo,hi,at);
}
fn Result<record_expressions::Value,errors::Error> record_value(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    bool mutable,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    var usize fuel=metadata_budget::unlimited();
    return record_value_into(source,s,p,names,signatures,mutable,at,depth,result_type,structure,loop_state,16,0,ref mut fuel);
}
fn Result<record_expressions::Value,errors::Error> record_value_into_staged(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    bool mutable,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize destination){
    if(depth>signatures.semantic_depth){return .err(errors::make(4,at));}
    var usize groups=0;while(s.kind==40){if(groups>=signatures.semantic_depth-depth){return .err(errors::make(4,s.begin));}
        let usize next=lexer::next(source,s)?;groups+=1;}
    if(arm_syntax::operand_kind(source,s)!=0){
        return record_conditional_value(source,s,p,names,signatures,mutable,at,depth,result_type,structure,loop_state,destination,groups);
    }
    if(s.kind!=2 && s.kind!=5){return .err(errors::make(3,s.begin));}
    let usize local=locals::find(source,names,s.begin,s.end);let usize target=functions::find(source,signatures,s.begin,s.end);
    var lexer::State look=lexer::snapshot(s);let usize next=lexer::next(source,ref mut look)?;
    var usize id=16;var bool owned=false;var usize record=32;var usize[16] slots=[0;16];
    if(look.kind==123){record=record_values::named(source,s,ref signatures.context)?;
        let bool opened=record_values::constructor(source,s,record,ref signatures.context)?;
        let record_expressions::Staged staged=record_constructor_fields_staged(source,s,p,names,signatures,record,at,result_type,depth+groups,structure,loop_state)?;
        slots=staged.slots;
    }else if(look.kind==40){
        if(local!=64 || target>=signatures.count || signatures.return_records[target]==0){return .err(errors::make(3,s.begin));}
        record=signatures.return_records[target] as usize-1;
        id=if(destination<16 && p.records.records[destination] as usize==record){destination}
            else{record_results::destination(signatures,target,record,mutable,p,names.function,s.begin)?};
        let usize name=lexer::next(source,s)?;
        let usize called=call_value(source,s,p,names,signatures,target,144+id,at,depth+groups,result_type,structure,loop_state)?;owned=true;
    }else{
        if(!record_values::binding(names,local)){return .err(errors::make(3,s.begin));}
        id=names.registers[local]-144;
        if(id>=16 || id>=p.records.count || p.record_functions[id] as usize!=names.function){return .err(errors::make(3,at));}
        record=p.records.records[id] as usize;let usize name=lexer::next(source,s)?;
    }
    var usize ordinal=0;var u8 tag=0;var usize left=groups;
    while(true){if(tag==0 && s.kind==46){let record_values::Leaf leaf=record_values::path(source,s,p,record,at,ref signatures.context)?;
            ordinal+=leaf.ordinal;record=leaf.record;tag=leaf.tag;}
        if(left==0){break;}let usize close=lexer::punctuation(source,s,41)?;left-=1;
    }
    return .ok(record_expressions::Value{.id=id,.owned=owned,.record=record,.ordinal=ordinal,.tag=tag,.slots=slots,.depth=depth+groups});
}
fn Result<record_expressions::Value,errors::Error> record_value_into(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    bool mutable,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize destination,usize deadline,ref mut usize fuel){
    if(depth>signatures.semantic_depth){return .err(errors::make(4,at));}
    var usize groups=0;while(s.kind==40){if(groups>=signatures.semantic_depth-depth){return .err(errors::make(4,s.begin));}
        discard metadata_budget::visit(fuel,deadline,s.begin)?;
        let usize next=lexer::next(source,s)?;groups+=1;}
    if(arm_syntax::operand_kind(source,s)!=0){
        return record_conditional_value(source,s,p,names,signatures,mutable,at,depth,result_type,structure,loop_state,destination,groups);
    }
    if(s.kind!=2 && s.kind!=5){return .err(errors::make(3,s.begin));}
    let usize local=argument_names::local_metered(source,names,s.begin,s.end,deadline,fuel)?;let usize target=functions::find(source,signatures,s.begin,s.end);
    var lexer::State look=lexer::snapshot(s);let usize next=lexer::next(source,ref mut look)?;
    var usize id=16;var bool owned=false;var usize record=32;var usize[16] slots=[0;16];
    if(look.kind==123){record=record_values::named(source,s,ref signatures.context)?;
        let bool opened=record_values::constructor(source,s,record,ref signatures.context)?;
        let record_expressions::Staged staged=record_constructor_fields(source,s,p,names,signatures,record,at,result_type,depth+groups,structure,loop_state,deadline,fuel)?;
        slots=staged.slots;
    }else if(look.kind==40){
        if(local!=64 || target>=signatures.count || signatures.return_records[target]==0){return .err(errors::make(3,s.begin));}
        record=signatures.return_records[target] as usize-1;
        id=if(destination<16 && p.records.records[destination] as usize==record){destination}
            else{record_results::destination(signatures,target,record,mutable,p,names.function,s.begin)?};
        let usize name=lexer::next(source,s)?;
        let usize called=captured_call(source,s,p,names,signatures,target,144+id,at,depth+groups,result_type,structure,loop_state,deadline,fuel)?;owned=true;
    }else{
        if(!record_values::binding(names,local)){return .err(errors::make(3,s.begin));}
        id=names.registers[local]-144;
        if(id>=16 || id>=p.records.count || p.record_functions[id] as usize!=names.function){return .err(errors::make(3,at));}
        record=p.records.records[id] as usize;let usize name=lexer::next(source,s)?;
    }
    var usize ordinal=0;var u8 tag=0;var usize left=groups;
    while(true){if(tag==0 && s.kind==46){let record_values::Leaf leaf=record_values::path_metered(source,s,p,record,at,ref signatures.context,deadline,fuel)?;
            ordinal+=leaf.ordinal;record=leaf.record;tag=leaf.tag;}
        if(left==0){break;}let usize close=lexer::punctuation(source,s,41)?;left-=1;
    }
    return .ok(record_expressions::Value{.id=id,.owned=owned,.record=record,.ordinal=ordinal,.tag=tag,.slots=slots,.depth=depth+groups});
}
// Conditional scratch and duplicate record return staging stay off ordinary
// record atom frames, including the original 32-deep captured CALL path.
fn Result<record_expressions::Value,errors::Error> record_conditional_value(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    bool mutable,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize destination,usize groups){
    var joins::Join join=joins::empty(0,mutable);
    if(destination!=16){join=joins::record(p.records.records[destination] as usize,mutable);join.value=144+destination;}
    let bool terminal=value_join(source,s,p,names,signatures,ref mut join,depth+groups,result_type,structure,loop_state)?;
    if(terminal || join.kind!=3){return .err(errors::make(3,at));}
    let usize encoded=joins::finish(p,ref join,at)?;let usize id=encoded-144;
    var usize record=p.records.records[id] as usize;var usize ordinal=0;var u8 tag=0;var usize left=groups;
    while(true){if(tag==0 && s.kind==46){let record_values::Leaf leaf=record_values::path(source,s,p,record,at,ref signatures.context)?;
            ordinal+=leaf.ordinal;record=leaf.record;tag=leaf.tag;}
        if(left==0){break;}let usize close=lexer::punctuation(source,s,41)?;left-=1;}
    return .ok(record_expressions::Value{.id=id,.owned=true,.record=record,.ordinal=ordinal,.tag=tag,.slots=[0;16],.depth=depth+groups});
}
fn Result<usize,errors::Error> record_expression_read(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    let record_expressions::Value value=record_value(source,s,p,names,signatures,false,at,depth,result_type,structure,loop_state)?;
    return record_expressions::scalar(p,ref value,at);
}
fn Result<usize,errors::Error> record_expression_read_staged(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    usize at,usize depth,u8 result_type,usize structure,ref mut loops::State flow){
    let record_expressions::Value value=record_value_into_staged(source,s,p,names,signatures,false,at,depth,result_type,structure,flow,16)?;
    return record_expressions::scalar(p,ref value,at);
}
// Field paths contain no expressions: the returned owner is read and dropped
// consecutively, with no lexical capture needed between the two operations.
fn Result<usize,errors::Error> record_call_read(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize target,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state) {
    let usize record=(signatures.return_records[target] as usize)-1;
    let usize temporary=record_results::destination(signatures,target,record,false,p,table.function,at)?;
    let usize called=call_value(source,s,p,table,signatures,target,144+temporary,at,depth+1,result_type,structure,loop_state)?;
    let usize value=record_values::read(source,s,p,temporary,at,ref signatures.context)?;
    let usize dropped=ir::record_drop(p,temporary,at)?;
    return .ok(value);
}
// Finish CALL before snapshotting lexical names. Recursive scalar calls must
// not retain a 64-entry snapshot at every parser frame.
fn Result<usize,errors::Error> slice_call_read(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize target,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,bool utf8){
    let usize value=call_value(source,s,p,table,signatures,target,176,at,depth+1,result_type,structure,loop_state)?;
    return slice_projection(source,s,p,table,signatures,value,at,depth,result_type,structure,loop_state,utf8);
}
// The anonymous result and retained parents/owners participate in every index
// expression exit. Materialize the scalar before releasing the capture suffix.
fn Result<usize,errors::Error> slice_projection(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize result,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,bool utf8){
    var locals::Table names=locals::snapshot(table);
    let usize retained=result_calls::publish(p,ref mut names,result,at)?;
    let usize captured=locals::declare(ref mut names,at,at,result,ir::exclusive(p,result-160))?;
    var usize value=0;
    if(utf8){
        let usize close=lexer::punctuation(source,s,41)?;
        value=ir::slice_utf8(p,result-160,at)?;
    }else if(s.kind==46){value=slices::member(source,s,p,result-160,at)?;}
    else{
        let usize open=lexer::punctuation(source,s,91)?;
        let usize index=expression(source,s,p,ref names,signatures,1,depth+1,12,result_type,structure,loop_state)?;
        if(p.types[index]!=12){return .err(errors::make(3,at));}
        let usize close=lexer::punctuation(source,s,93)?;
        value=ir::slice_read(p,result-160,index,at)?;
    }
    let usize released=arrays::release_from(ref names,p,table.count,at)?;return .ok(value);
}
// Keep the returned owner visible to index-expression exits, then release it
// immediately after materializing the scalar read or length.
fn Result<usize,errors::Error> array_call_read(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize target,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state) {
    let usize temporary=array_results::destination(signatures,target,signatures.return_types[target],
        signatures.return_lengths[target],false,p,table.function,at)?;
    let usize called=call_value(source,s,p,table,signatures,target,temporary,at,depth+1,result_type,structure,loop_state)?;
    return array_temporary_read(source,s,p,table,signatures,temporary,at,depth,result_type,structure,loop_state);
}
fn Result<usize,errors::Error> array_literal_projection(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    array_locals::Projection view,usize at,usize depth,u8 expected,u8 result_type,
    usize structure,ref mut loops::State loop_state){
    if(depth>signatures.semantic_depth || view.groups>signatures.semantic_depth-depth){return .err(errors::make(4,at));}
    var usize i=0;while(i<view.groups){let usize open=lexer::punctuation(source,s,40)?;i+=1;}
    let u8 element=if(view.kind==91 && types::integer(expected)){expected}else{0};
    let usize id=array_literal_value(source,s,p,table,signatures,element,0,false,at,depth+view.groups+1,result_type,structure,loop_state)?;
    i=0;while(i<view.groups){let usize close=lexer::punctuation(source,s,41)?;i+=1;}
    return array_temporary_read(source,s,p,table,signatures,id,at,depth+view.groups,result_type,structure,loop_state);
}
fn Result<usize,errors::Error> array_literal_value(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    u8 expected,usize expected_length,bool mutable,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    var usize operand_fuel=metadata_budget::unlimited();
    return array_literal_value_into(source,s,p,table,signatures,expected,expected_length,mutable,at,depth,result_type,structure,loop_state,16,0,ref mut operand_fuel);
}
fn Result<usize,errors::Error> array_literal_value_into(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    u8 expected,usize expected_length,bool mutable,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize destination,usize deadline,ref mut usize fuel){
    if(!array_locals::is_repeated_metered(source,s,deadline,fuel)?){
        return array_list_value_into(source,s,p,table,signatures,expected,expected_length,mutable,at,depth,result_type,structure,loop_state,destination,deadline,fuel);
    }
    let usize open=lexer::punctuation(source,s,91)?;
    let usize filler=assignment_operand(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state,deadline,fuel)?;
    let u8 element=p.types[filler];
    if(!types::scalar(element) || (expected!=0 && element!=expected)){return .err(errors::make(3,at));}
    let usize separator=lexer::punctuation(source,s,59)?;let usize length=arrays::count(source,s)?;
    if(expected_length!=0 && expected_length!=length){return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,93)?;let usize id=array_locals::site(p,table.function,element,length,mutable,at,destination)?;
    let usize initialized=ir::array_init(p,id,filler,at)?;return .ok(id);
}
// CALL results and literal values have the same completed-owner lifetime:
// register for endpoint exits, materialize one scalar, then promptly drop.
fn Result<usize,errors::Error> array_temporary_read(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize temporary,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    var locals::Table names=locals::snapshot(table);
    let usize capture=locals::declare(ref mut names,at,at,128+temporary,false)?;
    let usize value=array_scalar_read(source,s,p,ref names,signatures,temporary,at,depth,result_type,structure,loop_state)?;
    let usize dropped=ir::array_drop(p,temporary,at)?;return .ok(value);
}
fn Result<usize,errors::Error> array_scalar_read(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize temporary,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    var usize value=0;
    if(s.kind==91) {
        let usize open=lexer::next(source,s)?;
        let usize index=expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)?;
        if(p.types[index]!=12) {return .err(errors::make(3,at));}
        let usize close=lexer::punctuation(source,s,93)?;
        value=ir::array_read(p,temporary,index,at)?;
    } else if(s.kind==46) {
        let usize dot=lexer::next(source,s)?;
        if(!word_is(source,s,b"len")) {return .err(errors::make(3,s.begin));}
        let usize member=lexer::next(source,s)?;
        value=arrays::length_value(p,temporary,at)?;
    } else {return .err(errors::make(3,s.begin));}
    return .ok(value);
}
// A named owner is borrowed by this source atom; only a literal/CALL creates an
// unpublished owner. Callers choose copy, capture, move, or prompt finalization.
fn Result<array_expressions::Value,errors::Error> array_grouped_value(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    u8 expected,usize length,bool mutable,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    var usize fuel=metadata_budget::unlimited();
    return array_value_into(source,s,p,names,signatures,expected,length,mutable,at,depth,result_type,structure,loop_state,16,0,ref mut fuel);
}
fn Result<array_expressions::Value,errors::Error> array_value_into(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    u8 expected,usize length,bool mutable,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize destination,usize deadline,ref mut usize fuel){
    if(depth>signatures.semantic_depth){return .err(errors::make(4,at));}
    let usize groups=if(s.kind==40){array_expressions::open(source,s,depth,signatures.semantic_depth)?}else{0};var usize id=16;var bool owned=false;
    if(arm_syntax::operand_kind(source,s)!=0){
        var joins::Join join=joins::array(expected,length,mutable);
        if(destination!=16){join.value=128+destination;}
        let bool terminal=value_join(source,s,p,names,signatures,ref mut join,depth+groups,result_type,structure,loop_state)?;
        if(terminal || join.kind!=2){return .err(errors::make(3,at));}
        let usize value=joins::finish(p,ref join,at)?;id=value-128;owned=true;
    }else if(s.kind==91){
        id=array_literal_value_into(source,s,p,names,signatures,expected,length,mutable,at,depth+groups,result_type,structure,loop_state,destination,deadline,fuel)?;owned=true;
    }else{
        if(s.kind!=2 && s.kind!=5){return .err(errors::make(3,s.begin));}
        let usize index=argument_names::local_metered(source,names,s.begin,s.end,deadline,fuel)?;let usize target=functions::find(source,signatures,s.begin,s.end);
        var lexer::State look=lexer::snapshot(s);let usize next=lexer::next(source,ref mut look)?;
        if(look.kind==40){
            if(index!=64 || target>=signatures.count || signatures.return_lengths[target]==0){return .err(errors::make(3,s.begin));}
            let u8 element=signatures.return_types[target];let usize size=signatures.return_lengths[target];
            if((expected!=0 && expected!=element) || (length!=0 && length!=size)){return .err(errors::make(3,at));}
            id=array_locals::site(p,names.function,element,size,mutable,s.begin,destination)?;
            let usize name=lexer::next(source,s)?;
            let usize called=captured_call(source,s,p,names,signatures,target,id,at,depth+groups,result_type,structure,loop_state,deadline,fuel)?;owned=true;
        }else{
            if(!arrays::binding(names,index)){return .err(errors::make(3,s.begin));}
            id=names.registers[index]-128;let usize name=lexer::next(source,s)?;
        }
    }
    if(id>=16 || id>=p.arrays.count || p.array_functions[id] as usize!=names.function ||
        (expected!=0 && p.arrays.elements[id]!=expected) || (length!=0 && p.arrays.lengths[id]!=length)){
        return .err(errors::make(3,at));}
    let usize close=array_expressions::close(source,s,groups)?;
    return .ok(array_expressions::Value{.id=id,.owned=owned,.depth=depth+groups});
}
fn Result<usize,errors::Error> array_grouped_projection(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    let array_expressions::Value value=array_grouped_value(source,s,p,names,signatures,0,0,false,at,depth,result_type,structure,loop_state)?;
    if(value.owned){return array_temporary_read(source,s,p,names,signatures,value.id,at,value.depth,result_type,structure,loop_state);}
    return array_scalar_read(source,s,p,names,signatures,value.id,at,value.depth,result_type,structure,loop_state);
}
// A nested result becomes an anonymous argument capture only after its CALL
// succeeds. Later arguments and early exits then use the existing mixed cleanup.
fn Result<usize,errors::Error> record_argument_raw(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    usize record,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    let usize at=s.begin;
    let record_expressions::Value value=record_value(source,s,p,names,signatures,false,at,depth,result_type,structure,loop_state)?;
    if(value.tag!=0 || value.record!=record || (s.kind!=44 && s.kind!=41)){return .err(errors::make(3,at));}
    if(record_expressions::whole(p,ref value) && !value.owned){return record_calls::capture_id(p,names,value.id,record,at);}
    let usize id=record_expressions::materialize(p,names.function,ref value,false,at)?;
    let usize capture=locals::declare(names,at,at,144+id,false)?;return .ok(144+id);
}

fn Result<usize,errors::Error> array_argument_raw(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 element,usize length,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state) {
    if(s.kind==40 || arm_syntax::operand_kind(source,s)!=0){let usize at=s.begin;
        let array_expressions::Value value=array_grouped_value(source,s,p,names,signatures,element,length,false,at,depth,result_type,structure,loop_state)?;
        if(s.kind!=44 && s.kind!=41){return .err(errors::make(3,s.begin));}
        if(!value.owned){return array_calls::capture_id(p,names,value.id,element,length,at);}
        let usize captured=locals::declare(names,at,at,128+value.id,false)?;return .ok(128+value.id);
    }
    if(s.kind==91) {
        let usize at=s.begin;
        if(!array_locals::is_repeated(source,s)?){
            let usize temporary=array_list_value(source,s,p,names,signatures,element,length,false,at,depth+1,result_type,structure,loop_state)?;
            if(s.kind!=44 && s.kind!=41){return .err(errors::make(3,s.begin));}
            let usize captured=locals::declare(names,at,at,128+temporary,false)?;
            return .ok(128+temporary);
        }
        let usize open=lexer::next(source,s)?;
        let usize value=expression(source,s,p,names,signatures,1,depth+1,element,result_type,structure,loop_state)?;
        if(p.types[value]!=element) {return .err(errors::make(3,at));}
        let usize separator=lexer::punctuation(source,s,59)?;
        let usize repeated=arrays::count(source,s)?;
        if(repeated!=length) {return .err(errors::make(3,at));}
        let usize close=lexer::punctuation(source,s,93)?;
        if(s.kind!=44 && s.kind!=41) {return .err(errors::make(3,s.begin));}
        let usize temporary=ir::array_in(p,names.function,element,length,false,at)?;
        let usize initialized=ir::array_init(p,temporary,value,at)?;
        let usize captured=locals::declare(names,at,at,128+temporary,false)?;
        return .ok(128+temporary);
    }
    if((s.kind==2 || s.kind==5)) {
        var lexer::State look=lexer::snapshot(s);
        let usize next=lexer::next(source,ref mut look)?;
        if(look.kind==40) {
            let usize at=s.begin;
            if(locals::find(source,names,s.begin,s.end)!=64) {return .err(errors::make(3,at));}
            let usize target=functions::find(source,signatures,s.begin,s.end);
            let usize temporary=array_results::destination(signatures,target,element,length,false,p,names.function,at)?;
            let usize name=lexer::next(source,s)?;
            let usize called=call_value(source,s,p,names,signatures,target,temporary,at,depth+1,result_type,structure,loop_state)?;
            if(s.kind!=44 && s.kind!=41) {return .err(errors::make(3,s.begin));}
            let usize captured=locals::declare(names,at,at,128+temporary,false)?;
            return .ok(128+temporary);
        }
    }
    return array_calls::capture_raw(source,s,p,names,element,length);
}
// A fresh literal or owned CALL result becomes a hidden owner before endpoints.
// Publishing the owner first makes every lexical exit close the view before DROP.
fn Result<slice_calls::Capture,errors::Error> slice_temporary_raw(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 encoded,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    let u8 element=encoded & 127;let bool exclusive=(encoded & 128)!=0;
    var usize id=16;
    if(s.kind==91 && !array_locals::is_repeated(source,s)?){
        id=array_list_value(source,s,p,names,signatures,element,0,exclusive,at,depth+1,result_type,structure,loop_state)?;
    }else if(s.kind==91){
        let usize open=lexer::next(source,s)?;
        let usize fill=expression(source,s,p,names,signatures,1,depth+1,element,result_type,structure,loop_state)?;
        if(p.types[fill]!=element){return .err(errors::make(3,at));}
        let usize separator=lexer::punctuation(source,s,59)?;
        let usize length=arrays::count(source,s)?;
        let usize close=lexer::punctuation(source,s,93)?;
        id=ir::array_in(p,names.function,element,length,exclusive,at)?;
        let usize initialized=ir::array_init(p,id,fill,at)?;
    }else{
        if((s.kind!=2 && s.kind!=5) || locals::find(source,names,s.begin,s.end)!=64){return .err(errors::make(3,s.begin));}
        let usize target=functions::find(source,signatures,s.begin,s.end);
        if(target>=signatures.count){return .err(errors::make(3,s.begin));}
        if(signatures.return_slice_elements[target]!=0){
            if(signatures.return_slice_elements[target]!=encoded){return .err(errors::make(3,s.begin));}
            let usize name=lexer::next(source,s)?;
            let usize value=call_value(source,s,p,names,signatures,target,176,at,depth+1,result_type,structure,loop_state)?;
            if(s.kind!=44 && s.kind!=41 && s.kind!=91){return .err(errors::make(3,s.begin));}
            let usize retained=result_calls::publish(p,names,value,at)?;
            let usize captured=locals::declare(names,at,at,value,exclusive)?;
            return .ok(slice_calls::Capture{.value=value,.root=16,.parent=if(s.kind==91){value-160}else{16},.exclusive=exclusive,.offset=at});
        }
        id=array_results::destination(signatures,target,element,signatures.return_lengths[target],exclusive,p,names.function,at)?;
        let usize name=lexer::next(source,s)?;
        let usize called=call_value(source,s,p,names,signatures,target,id,at,depth+1,result_type,structure,loop_state)?;
    }
    if(s.kind!=91 && s.kind!=44 && s.kind!=41){return .err(errors::make(3,s.begin));}
    let usize owner=locals::declare(names,at,at,128+id,exclusive)?;
    return .ok(slice_calls::Capture{.value=0,.root=id,.parent=16,.exclusive=exclusive,.offset=at});
}
// Keep endpoint parsing and its capture descriptor off the scalar CALL frame.
// The root or parent is not newly borrowed until both endpoints complete.
fn Result<usize,errors::Error> slice_argument_raw(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    usize parameter,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    let usize reference=s.begin;
    let u8 encoded=slice_calls::prefix(source,s,signatures,parameter)?;
    return slice_actual_raw(source,s,p,names,signatures,encoded,reference,depth,result_type,structure,loop_state);
}
fn Result<usize,errors::Error> slice_actual_raw(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 encoded,usize reference,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    var lexer::State look=lexer::snapshot(s);
    if((s.kind==2 || s.kind==5)){let usize next=lexer::next(source,ref mut look)?;}
    let slice_calls::Capture captured=if(s.kind==91 || ((s.kind==2 || s.kind==5) && look.kind==40)){
        slice_temporary_raw(source,s,p,names,signatures,encoded,reference,depth,result_type,structure,loop_state)?
    }else{slice_calls::capture_raw(source,s,p,names,encoded,reference)?};
    if(captured.root==16 && captured.parent==16){return .ok(captured.value);}
    let usize at=captured.offset;
    if(s.kind==44 || s.kind==41){
        let usize lo=ir::integer(p,0,12,at)?;
        let usize hi=arrays::length_value(p,captured.root,at)?;
        return slice_calls::range_raw(p,names,ref captured,lo,hi);
    }
    let usize open=lexer::punctuation(source,s,91)?;
    let usize lo=if(s.kind==46){ir::integer(p,0,12,at)?}
        else{expression(source,s,p,names,signatures,1,depth+1,12,result_type,structure,loop_state)?};
    if(p.types[lo]!=12){return .err(errors::make(3,at));}
    let usize first=lexer::punctuation(source,s,46)?;let usize second=lexer::punctuation(source,s,46)?;
    let usize hi=if(s.kind==93){if(captured.parent<16){ir::slice_length(p,captured.parent,at)?}else{arrays::length_value(p,captured.root,at)?}}
        else{expression(source,s,p,names,signatures,1,depth+1,12,result_type,structure,loop_state)?};
    if(p.types[hi]!=12){return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,93)?;
    if(s.kind!=44 && s.kind!=41){return .err(errors::make(3,s.begin));}
    return slice_calls::range_raw(p,names,ref captured,lo,hi);
}
// Image and universal view arguments join the same lexical suffix as native
// owner/loan captures before later arguments and their nonlocal exits execute.
fn Result<usize,errors::Error> reference_argument_raw(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    usize parameter,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    if(!reference_calls::image_argument_raw(source,s,names)? && !reference_calls::returned_atom_raw(source,s,names,signatures)?){
        return slice_argument_raw(source,s,p,names,signatures,parameter,depth,result_type,structure,loop_state);
    }
    let usize at=s.begin;let usize prefix=lexer::word(source,s,b"ref")?;
    let static_source::View value=static_view(source,s,p,names,signatures,depth,result_type,structure,loop_state)?;
    if(value.kind!=1 || (s.kind!=44 && s.kind!=41)){return .err(errors::make(3,at));}
    if(value.owned){
        if(signatures.reference_returns){let usize roots=reference_results::publish(p,signatures,names,value.site,at)?;}
        let usize hidden=locals::declare(names,at,at,192+value.site,false)?;
    }
    return .ok(192+value.site);
}
fn Result<usize,errors::Error> record_argument(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    usize record,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let usize at=s.begin;
    let record_expressions::Value value=record_value_into(source,s,p,names,signatures,false,at,depth,result_type,structure,loop_state,16,deadline,fuel)?;
    if(value.tag!=0 || value.record!=record || (s.kind!=44 && s.kind!=41)){return .err(errors::make(3,at));}
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    if(record_expressions::whole(p,ref value) && !value.owned){return record_calls::capture_id_metered(p,names,value.id,record,at,deadline,fuel);}
    let usize id=record_expressions::materialize(p,names.function,ref value,false,at)?;
    let usize capture=locals::declare(names,at,at,144+id,false)?;return .ok(144+id);
}

fn Result<usize,errors::Error> array_argument(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 element,usize length,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel) {
    if(s.kind==40 || arm_syntax::operand_kind(source,s)!=0){let usize at=s.begin;
        let array_expressions::Value value=array_value_into(source,s,p,names,signatures,element,length,false,at,depth,result_type,structure,loop_state,16,deadline,fuel)?;
        if(s.kind!=44 && s.kind!=41){return .err(errors::make(3,s.begin));}
        if(!value.owned){return array_calls::capture_id_metered(p,names,value.id,element,length,at,deadline,fuel);}
        let usize captured=locals::declare(names,at,at,128+value.id,false)?;return .ok(128+value.id);
    }
    if(s.kind==91) {
        let usize at=s.begin;
        if(!array_locals::is_repeated_metered(source,s,deadline,fuel)?){
            let usize temporary=array_list_value_into(source,s,p,names,signatures,element,length,false,at,depth+1,result_type,structure,loop_state,16,deadline,fuel)?;
            if(s.kind!=44 && s.kind!=41){return .err(errors::make(3,s.begin));}
            let usize captured=locals::declare(names,at,at,128+temporary,false)?;
            return .ok(128+temporary);
        }
        let usize temporary=repeated_argument(source,s,p,names,signatures,element,length,false,at,depth,result_type,structure,loop_state,1,deadline,fuel)?;
        let usize captured=locals::declare(names,at,at,128+temporary,false)?;
        return .ok(128+temporary);
    }
    if((s.kind==2 || s.kind==5)) {
        var lexer::State look=lexer::snapshot(s);
        let usize next=lexer::next(source,ref mut look)?;
        if(look.kind==40) {
            let usize at=s.begin;
            if(argument_names::local_metered(source,names,s.begin,s.end,deadline,fuel)?!=64) {return .err(errors::make(3,at));}
            let usize target=argument_names::target(source,signatures,s.begin,s.end)?;
            let usize temporary=array_results::destination(signatures,target,element,length,false,p,names.function,at)?;
            let usize name=lexer::next(source,s)?;
            let usize called=captured_call(source,s,p,names,signatures,target,temporary,at,depth+1,result_type,structure,loop_state,deadline,fuel)?;
            if(s.kind!=44 && s.kind!=41) {return .err(errors::make(3,s.begin));}
            let usize captured=locals::declare(names,at,at,128+temporary,false)?;
            return .ok(128+temporary);
        }
    }
    return array_calls::capture(source,s,p,names,element,length,deadline,fuel);
}
// A fresh literal or owned CALL result becomes a hidden owner before endpoints.
// Publishing the owner first makes every lexical exit close the view before DROP.
fn Result<slice_calls::Capture,errors::Error> slice_temporary(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 encoded,usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let u8 element=encoded & 127;let bool exclusive=(encoded & 128)!=0;
    var usize id=16;
    if(s.kind==91 && !array_locals::is_repeated_metered(source,s,deadline,fuel)?){
        id=array_list_value_into(source,s,p,names,signatures,element,0,exclusive,at,depth+1,result_type,structure,loop_state,16,deadline,fuel)?;
    }else if(s.kind==91){
        id=repeated_argument(source,s,p,names,signatures,element,0,exclusive,at,depth,result_type,structure,loop_state,2,deadline,fuel)?;
    }else{
        if((s.kind!=2 && s.kind!=5) || argument_names::local(source,names,s.begin,s.end)?!=64){return .err(errors::make(3,s.begin));}
        let usize target=argument_names::target(source,signatures,s.begin,s.end)?;
        if(target>=signatures.count){return .err(errors::make(3,s.begin));}
        if(signatures.return_slice_elements[target]!=0){
            if(signatures.return_slice_elements[target]!=encoded){return .err(errors::make(3,s.begin));}
            let usize name=lexer::next(source,s)?;
            let usize value=captured_call(source,s,p,names,signatures,target,176,at,depth+1,result_type,structure,loop_state,deadline,fuel)?;
            if(s.kind!=44 && s.kind!=41 && s.kind!=91){return .err(errors::make(3,s.begin));}
            let usize retained=result_calls::publish(p,names,value,at)?;
            let usize captured=locals::declare(names,at,at,value,exclusive)?;
            return .ok(slice_calls::Capture{.value=value,.root=16,.parent=if(s.kind==91){value-160}else{16},.exclusive=exclusive,.offset=at});
        }
        id=array_results::destination(signatures,target,element,signatures.return_lengths[target],exclusive,p,names.function,at)?;
        let usize name=lexer::next(source,s)?;
        let usize called=captured_call(source,s,p,names,signatures,target,id,at,depth+1,result_type,structure,loop_state,deadline,fuel)?;
    }
    if(s.kind!=91 && s.kind!=44 && s.kind!=41){return .err(errors::make(3,s.begin));}
    let usize owner=locals::declare(names,at,at,128+id,exclusive)?;
    return .ok(slice_calls::Capture{.value=0,.root=id,.parent=16,.exclusive=exclusive,.offset=at});
}
// Keep endpoint parsing and its capture descriptor off the scalar CALL frame.
// The root or parent is not newly borrowed until both endpoints complete.
fn Result<usize,errors::Error> slice_argument(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    usize parameter,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let usize reference=s.begin;
    let u8 encoded=slice_calls::prefix(source,s,signatures,parameter)?;
    return slice_actual(source,s,p,names,signatures,encoded,reference,depth,result_type,structure,loop_state,deadline,fuel);
}
fn Result<usize,errors::Error> slice_actual(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 encoded,usize reference,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    var lexer::State look=lexer::snapshot(s);
    if((s.kind==2 || s.kind==5)){let usize next=lexer::next(source,ref mut look)?;}
    let slice_calls::Capture captured=if(s.kind==91 || ((s.kind==2 || s.kind==5) && look.kind==40)){
        slice_temporary(source,s,p,names,signatures,encoded,reference,depth,result_type,structure,loop_state,deadline,fuel)?
    }else{slice_calls::capture(source,s,p,names,encoded,reference)?};
    if(captured.root==16 && captured.parent==16){return .ok(captured.value);}
    var argument_work::State w=argument_work::begin(*s,3,12,0,names.function,captured.offset);
    w.root=captured.root;w.parent=captured.parent;
    var metadata_budget::State meter=metadata_budget::empty();
    while(!w.done){
        discard metadata_budget::visit(fuel,deadline,s.begin)?;
        let usize allowance=metadata_budget::reset(ref mut meter,w.at)?;
        let bool done=argument_work::advance(source,s,p,ref mut w,ref mut meter)?;
        let u8 request=w.request;
        if(request==1){let usize value=assignment_operand(source,s,p,names,signatures,depth+1,12,result_type,structure,loop_state,deadline,fuel)?;
            let usize resumed=argument_work::resume(ref mut w,request,value)?;}
        else if(request==2){let usize lo=w.lo;let usize hi=w.hi;
            let usize value=slice_calls::range(p,names,ref captured,lo,hi)?;
            let usize resumed=argument_work::resume(ref mut w,request,value)?;}
    }return argument_work::prepared(ref w);
}
// Image and universal view arguments join the same lexical suffix as native
// owner/loan captures before later arguments and their nonlocal exits execute.
fn Result<usize,errors::Error> reference_argument(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    usize parameter,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    if(!reference_calls::image_argument_metered(source,s,names,deadline,fuel)? && !reference_calls::returned_atom_metered(source,s,names,signatures,deadline,fuel)?){
        return slice_argument(source,s,p,names,signatures,parameter,depth,result_type,structure,loop_state,deadline,fuel);
    }
    let usize at=s.begin;let usize prefix=lexer::word_metered(source,s,b"ref",deadline,fuel)?;
    let static_source::View value=static_view_metered(source,s,p,names,signatures,depth,result_type,structure,loop_state,deadline,fuel)?;
    if(value.kind!=1 || (s.kind!=44 && s.kind!=41)){return .err(errors::make(3,at));}
    if(value.owned){
        if(signatures.reference_returns){let usize roots=reference_results::publish(p,signatures,names,value.site,at)?;}
        let usize hidden=locals::declare(names,at,at,192+value.site,false)?;
    }
    return .ok(192+value.site);
}
fn Result<usize,errors::Error> repeated_argument(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    u8 element,usize length,bool exclusive,usize at,usize depth,u8 result_type,usize structure,
    ref mut loops::State flow,u8 mode,usize deadline,ref mut usize fuel){
    var argument_work::State w=argument_work::begin(*s,mode,element,length,names.function,at);w.exclusive=exclusive;
    var metadata_budget::State meter=metadata_budget::empty();
    while(!w.done){
        discard metadata_budget::visit(fuel,deadline,s.begin)?;
        let usize allowance=metadata_budget::reset(ref mut meter,at)?;
        let bool done=argument_work::advance(source,s,p,ref mut w,ref mut meter)?;
        if(w.request==1){let usize value=assignment_operand(source,s,p,names,signatures,depth+1,element,result_type,structure,flow,deadline,fuel)?;
            let usize resumed=argument_work::resume(ref mut w,1,value)?;}}
    return argument_work::prepared(ref w);
}
// Internal raw/staged seam for acquisition IR, error, token and capture parity.
pub fn Result<usize,errors::Error> acquire_argument(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 kind,usize parameter,u8 element,usize length,usize depth,u8 result_type,usize structure,
    ref mut loops::State flow,bool staged){
    var usize operand_fuel=metadata_budget::unlimited();
    if(kind==1){return if(staged){array_argument(source,s,p,names,signatures,element,length,depth,result_type,structure,flow,0,ref mut operand_fuel)}
        else{array_argument_raw(source,s,p,names,signatures,element,length,depth,result_type,structure,flow)};}
    if(kind==2){return if(staged){record_argument(source,s,p,names,signatures,parameter,depth,result_type,structure,flow,0,ref mut operand_fuel)}
        else{record_argument_raw(source,s,p,names,signatures,parameter,depth,result_type,structure,flow)};}
    if(kind==3){return if(staged){slice_argument(source,s,p,names,signatures,parameter,depth,result_type,structure,flow,0,ref mut operand_fuel)}
        else{slice_argument_raw(source,s,p,names,signatures,parameter,depth,result_type,structure,flow)};}
    return if(staged){reference_argument(source,s,p,names,signatures,parameter,depth,result_type,structure,flow,0,ref mut operand_fuel)}
        else{reference_argument_raw(source,s,p,names,signatures,parameter,depth,result_type,structure,flow)};
}
// All result kinds share argument evaluation and capture cleanup. Destinations
// 0..15 are dead array sites, 16 is scalar, and 144..159 are dead record sites.
fn Result<usize,errors::Error> call_value(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref locals::Table table,ref functions::Table signatures,usize target,usize destination,usize at,
    usize depth,u8 result_type,usize structure,ref mut loops::State loop_state) {
    if(depth>signatures.semantic_depth) {return .err(errors::make(4,at));}
    if(destination==16 && (signatures.return_lengths[target]!=0 || signatures.return_records[target]!=0)) {return .err(errors::make(3,at));}
    var bool plain=destination==16;var usize i=0;
    while(i<signatures.arities[target]){let usize parameter=target*8+i;
        if(signatures.param_slices[parameter] || signatures.param_lengths[parameter]!=0 || signatures.param_records[parameter]!=0){plain=false;}i+=1;
    }
    if(plain){return scalar_call(source,s,p,table,signatures,target,at,depth,result_type,structure,loop_state);}
    var usize fuel=metadata_budget::unlimited();
    return captured_call(source,s,p,table,signatures,target,destination,at,depth,result_type,structure,loop_state,0,ref mut fuel);
}
// No aggregate formal can capture a temporary across scalar argument evaluation.
// Keep the 64-entry lexical snapshot out of every scalar recursion frame.
fn Result<usize,errors::Error> scalar_call(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref locals::Table table,ref functions::Table signatures,usize target,usize at,
    usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    let usize open=lexer::punctuation(source,s,40)?;var usize[8] arguments=[0;8];var usize arity=0;
    while(s.kind!=41){
        if(arity>=8){return .err(errors::make(4,s.begin));}
        let u8 tag=if(arity<signatures.arities[target]){signatures.param_types[target*8+arity]}else{0};
        arguments[arity]=expression(source,s,p,table,signatures,1,depth+1,tag,result_type,structure,loop_state)?;
        if(arity>=signatures.arities[target] || p.types[arguments[arity]]!=tag){return .err(errors::make(3,at));}
        arity+=1;if(s.kind==41){break;}
        let usize comma=lexer::punctuation(source,s,44)?;if(s.kind==41){return .err(errors::make(2,s.begin));}
    }
    if(arity!=signatures.arities[target]){return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,41)?;
    return ir::call(p,target,ref arguments[..arity],at);
}
fn Result<usize,errors::Error> captured_call(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref locals::Table table,ref functions::Table signatures,usize target,usize destination,usize at,
    usize depth,u8 result_type,usize structure,ref mut loops::State flow,usize deadline,ref mut usize fuel){
    if(depth>signatures.semantic_depth){return .err(errors::make(4,at));}
    if(destination==16 && (signatures.return_lengths[target]!=0 || signatures.return_records[target]!=0)){return .err(errors::make(3,at));}
    let usize zero=if(destination==176){ir::integer(p,0,12,at)?}else{128};
    var call_operand_work::State w=call_operand_work::begin(table,*s,target,at,depth);var metadata_budget::State meter=metadata_budget::empty();
    while(!w.done){
        discard metadata_budget::visit(fuel,deadline,s.begin)?;
        let usize allowance=metadata_budget::reset(ref mut meter,s.begin)?;
        let bool done=aggregate_calls::advance(source,s,p,signatures,destination,ref mut w,ref mut meter)?;
        let u8 request=w.request;let usize parameter=w.parameter;let usize record=w.record;let usize length=w.length;let u8 tag=w.tag;var usize value=256;
        if(request==1){value=assignment_operand(source,s,p,ref w.names,signatures,depth+1,w.tag,result_type,structure,flow,deadline,fuel)?;}
        else if(request==2){var bool prefix=w.prefix;
            if(prefix && !w.sliced){value=call_prefix::stable_metered(source,s,p,ref w.names,w.tag,w.length,w.record,depth,deadline,fuel)?;if(value==256){prefix=false;}}
            if(value==256){if(w.sliced){value=if(reference_calls::parameter(signatures,w.parameter)){
                    reference_argument(source,s,p,ref mut w.names,signatures,parameter,depth,result_type,structure,flow,deadline,fuel)?
                }else{slice_argument(source,s,p,ref mut w.names,signatures,parameter,depth,result_type,structure,flow,deadline,fuel)?};}
                else if(w.record!=0){value=record_argument(source,s,p,ref mut w.names,signatures,record-1,depth,result_type,structure,flow,deadline,fuel)?;}
                else{value=array_argument(source,s,p,ref mut w.names,signatures,tag,length,depth,result_type,structure,flow,deadline,fuel)?;}}
            w.prefix=prefix;
        }else if(request==3){value=if(reference_calls::result(signatures,target)){
                reference_results::call(p,signatures,table,ref w.names,target,ref w.arguments[..w.arity],at)?
            }else{result_calls::finish(p,table,ref w.names,signatures,target,ref w.arguments[..w.arity],zero,at)?};}
        if(request!=0){let usize resumed=call_operand_work::resume(ref mut w,request,value)?;}
    }
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    return call_operand_work::prepared(ref w);
}
// Internal comparison seam: same prepared source/IR, independent outer CALL loop.
pub fn Result<usize,errors::Error> specialized_call(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref locals::Table table,ref functions::Table signatures,usize target,usize destination,usize at,
    usize depth,u8 result_type,usize structure,ref mut loops::State flow,bool staged){
    if(staged){
        var usize fuel=metadata_budget::unlimited();
        return captured_call(source,s,p,table,signatures,target,destination,at,depth,result_type,structure,flow,0,ref mut fuel);
    }
    return captured_call_raw(source,s,p,table,signatures,target,destination,at,depth,result_type,structure,flow);
}
fn Result<usize,errors::Error> captured_call_raw(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref locals::Table table,ref functions::Table signatures,usize target,usize destination,usize at,
    usize depth,u8 result_type,usize structure,ref mut loops::State loop_state) {
    if(depth>signatures.semantic_depth) {return .err(errors::make(4,at));}
    if(destination==16 && (signatures.return_lengths[target]!=0 || signatures.return_records[target]!=0)) {return .err(errors::make(3,at));}
    let usize zero=if(destination==176){ir::integer(p,0,12,at)?}else{128};
    let usize open=lexer::punctuation(source,s,40)?;
    var usize[8] arguments=[0;8];var usize arity=0;
    // Scalars and bare immutable owners need no hidden lexical captures. Finish
    // this prefix before a separate frame retains any capture-table snapshot.
    while(s.kind!=41 && arity<signatures.arities[target]){
        let usize parameter=target*8+arity;
        if(signatures.param_slices[parameter]){break;}
        let u8 tag=signatures.param_types[parameter];
        let usize length=signatures.param_lengths[parameter];let usize record=signatures.param_records[parameter] as usize;
        if(length!=0 || record!=0){
            let usize stable=call_prefix::stable(source,s,p,table,tag,length,record,depth)?;
            if(stable==256){break;}arguments[arity]=stable;
        }else{
            arguments[arity]=expression(source,s,p,table,signatures,1,depth+1,tag,result_type,structure,loop_state)?;
            if(p.types[arguments[arity]]!=tag){return .err(errors::make(3,at));}
        }
        arity+=1;if(s.kind==41){break;}
        let usize comma=lexer::punctuation(source,s,44)?;if(s.kind==41){return .err(errors::make(2,s.begin));}
    }
    return captured_tail_raw(source,s,p,table,signatures,target,destination,at,depth,result_type,structure,loop_state,ref mut arguments,arity,zero);
}
fn Result<usize,errors::Error> captured_tail_raw(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref locals::Table table,ref functions::Table signatures,usize target,usize destination,usize at,
    usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,ref mut usize[] arguments,usize first,usize zero){
    var usize operand_fuel=metadata_budget::unlimited();
    var locals::Table names=locals::snapshot(table);var usize arity=first;
    while(s.kind!=41) {
        if(arity>=8) {return .err(errors::make(4,s.begin));}
        let u8 tag=if(arity<signatures.arities[target]){signatures.param_types[target*8+arity]}else{0};
        let usize length=if(arity<signatures.arities[target]){signatures.param_lengths[target*8+arity]}else{0};
        let usize record=if(arity<signatures.arities[target]){signatures.param_records[target*8+arity] as usize}else{0};
        if(arity<signatures.arities[target] && signatures.param_slices[target*8+arity]) {
            arguments[arity]=if(reference_calls::parameter(signatures,target*8+arity)){
                reference_argument(source,s,p,ref mut names,signatures,target*8+arity,depth,result_type,structure,loop_state,0,ref mut operand_fuel)?
            }else{slice_argument(source,s,p,ref mut names,signatures,target*8+arity,depth,result_type,structure,loop_state,0,ref mut operand_fuel)?};
        }
        else if(record!=0) {arguments[arity]=record_argument(source,s,p,ref mut names,signatures,record-1,depth,result_type,structure,loop_state,0,ref mut operand_fuel)?;}
        else if(length!=0) {arguments[arity]=array_argument(source,s,p,ref mut names,signatures,tag,length,depth,result_type,structure,loop_state,0,ref mut operand_fuel)?;}
        else {
            arguments[arity]=expression(source,s,p,ref names,signatures,1,depth+1,tag,result_type,structure,loop_state)?;
            if(arity>=signatures.arities[target] || p.types[arguments[arity]]!=tag) {return .err(errors::make(3,at));}
        }
        arity+=1;
        if(s.kind==41) {break;}
        let usize comma=lexer::punctuation(source,s,44)?;
        if(s.kind==41) {return .err(errors::make(2,s.begin));}
    }
    if(arity!=signatures.arities[target]) {return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,41)?;
    if(reference_calls::result(signatures,target)){return reference_results::call(p,signatures,table,ref names,target,arguments[..arity],at);}
    if(destination==176){return result_calls::finish(p,table,ref names,signatures,target,arguments[..arity],zero,at);}
    let usize call_pc=p.count;
    let usize called=if(destination<16){ir::array_call(p,target,destination,arguments[..arity],at)?}
        else if(destination>=144 && destination<160){ir::record_call(p,target,destination-144,arguments[..arity],at)?}
        else{ir::call(p,target,arguments[..arity],at)?};
    if(reference_calls::target(signatures,target)){let usize promoted=reference_calls::promote(p,call_pc,at)?;}
    let usize dropped=arrays::release_from(ref names,p,table.count,at)?;
    return .ok(if(destination<16){128+destination}else if(destination>=144 && destination<160){destination}else{called});
}
// Read-only postfix lookahead supplies no bool context to a Result-producing
// atom. Nested calls/groups own their own suffixes; the real parser still checks
// every token and evaluates the expression exactly once.
fn Result<bool,errors::Error> result_property(ref u8[] source,ref lexer::State s){
    var lexer::State look=lexer::snapshot(s);
    var usize parens=0;var usize braces=0;var usize brackets=0;var bool started=false;
    while(look.kind!=0){
        if(parens==0 && braces==0 && brackets==0){
            if(look.kind==46 && started){
                let usize dot=lexer::next(source,ref mut look)?;
                if(look.kind==46){return .ok(false);}
                if(word_is(source,ref look,b"is_ok")){return .ok(true);}
                continue;
            }
            if(look.kind==59 || look.kind==44 || look.kind==41 || look.kind==125 || look.kind==93){return .ok(false);}
            if(started && (precedence(look.kind)!=0 || word_is(source,ref look,b"as"))){return .ok(false);}
        }
        if(look.kind==40){parens+=1;}else if(look.kind==41){if(parens==0){return .ok(false);}parens-=1;}
        else if(look.kind==123){braces+=1;}else if(look.kind==125){if(braces==0){return .ok(false);}braces-=1;}
        else if(look.kind==91){brackets+=1;}else if(look.kind==93){if(brackets==0){return .ok(false);}brackets-=1;}
        started=true;let usize next=lexer::next(source,ref mut look)?;
    }return .ok(false);
}
// CASE24 tests the already evaluated Result. Both paths initialize one bool
// slot; no payload is re-evaluated, moved or given a new cleanup obligation.
fn Result<usize,errors::Error> result_is_ok(ref mut ir::Program p,usize value,usize at){
    if(host_source::is_saved(p,value)){return host_source::project(p,value,2,at);}
    if(value>=128 || p.types[value]<5 || p.types[value]>8){return .err(errors::make(3,at));}
    let usize slot=ir::slot(p,2,at)?;
    let ir::Case branch=ir::branch_case(p,value,1,at)?;
    let usize yes=ir::boolean(p,true,at)?;
    let usize positive=ir::raw(p,18,slot,yes,0,at)?;
    let usize skip=ir::raw(p,19,0,0,0,at)?;
    let usize failure=p.count;let usize patched=ir::patch(p,branch.instruction,failure,at)?;
    let usize no=ir::boolean(p,false,at)?;
    let usize negative=ir::raw(p,18,slot,no,0,at)?;
    let usize join=p.count;let usize continued=ir::patch(p,skip,join,at)?;
    return ir::emit(p,17,slot,0,at);
}
// Postfix propagation and Result inspection bind before unary/binary operators.
// The operand parser recurses through primary for unary operators.
fn Result<usize, errors::Error> primary(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let u8 context=if(expected!=0 && !types::tagged(expected) && result_property(source,s)?){0}else{expected};
    var usize value=operand(source,s,p,table,signatures,depth,context,result_type,structure,loop_state,deadline,fuel)?;
    while(s.kind==63 || s.kind==46) {
        let usize at=s.begin;
        if(s.kind==46){
            // A range delimiter belongs to the enclosing slice parser. It is
            // not a Result member, including after a computed lower endpoint.
            var lexer::State look=lexer::snapshot(s);let usize next=lexer::next_with_budget(source,ref mut look,deadline,fuel)?;
            if(look.kind==46){break;}
            let usize dot=lexer::next_with_budget(source,s,deadline,fuel)?;
            if(!word_is(source,s,b"is_ok")){return .err(errors::make(3,at));}
            let usize member=lexer::next_with_budget(source,s,deadline,fuel)?;
            value=result_is_ok(p,value,at)?;continue;
        }
        let usize next=lexer::next_with_budget(source,s,deadline,fuel)?;
        if(signatures.scalar_host_calls && host_source::is_saved(p,value)){
            value=host_source::propagate(p,table,value,result_type,at)?;
        }else{value=propagation::lower(p,table,value,result_type,at)?;}
    }
    return .ok(value);
}
// Casts bind after unary/postfix work and before every binary operator.
fn Result<usize,errors::Error> converted(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,usize depth,u8 expected,u8 result_type, usize structure, ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let bool explicit=casts::follows(source,s)?;
    let u8 context=if(explicit) {0} else {expected};
    var usize value=primary(source,s,p,table,signatures,depth,context,result_type,structure,loop_state,deadline,fuel)?;
    while(word_is(source,s,b"as")) {
        let usize at=s.begin;
        let usize keyword=lexer::next_with_budget(source,s,deadline,fuel)?;
        let u8 target=types::parse(source,s)?;
        value=ir::widen(p,value,target,at)?;
    }
    return .ok(value);
}
fn Result<usize, errors::Error> expression(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, u8 minimum, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state) {
    var usize fuel=metadata_budget::unlimited();
    return raw_expression(source,s,p,table,signatures,minimum,depth,expected,result_type,structure,loop_state,0,ref mut fuel);
}
fn Result<usize, errors::Error> raw_expression(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, u8 minimum, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    if(depth>signatures.semantic_depth){return .err(errors::make(4,s.begin));}
    discard metadata_budget::visit(fuel,deadline,s.begin)?;
    var usize left = converted(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state,deadline,fuel)?;
    while (precedence(s.kind) >= minimum) {
        let u8 kind = s.kind;
        let u8 level = precedence(s.kind);
        let u8 operation = opcode(s.kind);
        let usize at = s.begin;
        let usize advanced = lexer::next_with_budget(source,s,deadline,fuel)?;
        if (kind == 132 || kind == 133) {
            if (p.types[left] != 2) { return .err(errors::make(3, at)); }
            let usize slot = ir::slot(p, 2, at)?;
            let usize initial = ir::raw(p, 18, slot, left, 0, at)?;
            let usize jump = ir::raw(p, if (kind == 132) { 20 } else { 21 }, 0, left, 0, at)?;
            let usize right = raw_expression(source,s,p,table,signatures,level + 1,depth + 1,expected,result_type,structure,loop_state,deadline,fuel)?;
            if (p.types[right] != 2) { return .err(errors::make(3, at)); }
            let usize stored = ir::raw(p, 18, slot, right, 0, at)?;
            let usize target = p.count;
            let usize patched = ir::patch(p, jump, target, at)?;
            left = ir::emit(p, 17, slot, 0, at)?;
            continue;
        }
        let u8 context=p.types[left];
        let usize right = raw_expression(source,s,p,table,signatures,level + 1,depth + 1,context,result_type,structure,loop_state,deadline,fuel)?;
        if (!types::scalar(p.types[left]) || p.types[left] != p.types[right] || ((operation < 11 || operation > 12) && !types::integer(p.types[left]))) { return .err(errors::make(3, at)); }
        left = ir::emit(p, operation, left, right, at)?;
    }
    return .ok(left);
}

fn Result<usize,errors::Error> complete_operand_in_environment(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,u8 result_type,
    usize structure,ref mut loops::State flow,ref mut expression_work::Bank bank,ref mut expression_work::State w,usize deadline,ref mut usize fuel){
    if(w.done || !w.waiting){return .err(errors::make(5,s.begin));}
    let expression_work::Frame f=expression_work::current(w);
    if(w.request==2){let usize initial=w.value;return expression_work::tail(w,bank,*s,initial,result_type);}
    if(w.request!=1){return .err(errors::make(5,s.begin));}
    // The read-only converted/primary preflight completed on the shared driver.
    let u8 context=f.context;
    let ref route_work::State route=ref bank.route;let u8 lane=route.lane;
    if(lane==2){return expression_work::unary(w,s.kind,context,s.begin);}
    if(lane==1){return expression_work::group(w,context);}
    let usize target=route.target;
    let ref aggregate_work::State aggregate=ref bank.aggregate;
    if(lane==3){return expression_work::call(w,target,signatures.arities[target],ref signatures.param_types[target*8..target*8+8],s.begin);}
    if(lane==4){return expression_work::captured(w,bank,names,*s,target,s.begin,f.depth);}
    if(lane==8 || lane==7 && aggregate.result.kind==2){let usize groups=aggregate.result.groups;
        let usize binding=aggregate.local;let u8 expected=if(lane==8 && aggregate.result.suffix==91 && types::integer(context)){context}else{0};
        return expression_work::array_operand(w,bank,groups,expected,lane==8,binding,s.begin);}
    if(lane==10){return .err(errors::make(3,s.begin));}
    let usize at=s.begin;var usize initial=0;
    if(lane==5 || arm_syntax::operand_kind(source,s)!=0){initial=conditional_operand_staged(source,s,p,names,signatures,f.depth,context,result_type,structure,flow,bank,w.used==1 && f.environment==34,deadline,fuel)?;}
    else if(lane==6){initial=record_expression_read_staged(source,s,p,names,signatures,at,f.depth,result_type,structure,flow)?;}
    else if(lane==7){initial=array_grouped_projection(source,s,p,names,signatures,at,f.depth,result_type,structure,flow)?;}
    else if(lane==8){let array_locals::Projection plan=array_locals::Projection{.groups=aggregate.result.groups,.kind=aggregate.result.suffix};
        initial=array_literal_projection(source,s,p,names,signatures,plan,at,f.depth,context,result_type,structure,flow)?;}
    else if(lane==9){let static_source::View view=static_view(source,s,p,names,signatures,f.depth,result_type,structure,flow)?;
        initial=static_projection_staged(source,s,p,names,signatures,ref view,at,f.depth,result_type,structure,flow)?;}
    else{var usize operand_fuel=metadata_budget::unlimited();initial=operand(source,s,p,names,signatures,f.depth,context,result_type,structure,flow,0,ref mut operand_fuel)?;}
    return expression_work::tail(w,bank,*s,initial,result_type);
}

// One active lexical context is copied into fixed caller scratch. The context
// bank and expression frames survive children without native recursive drivers.
fn Result<usize,errors::Error> complete_captured_operand(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,u8 result_type,
    usize structure,ref mut loops::State flow,ref mut expression_work::Bank bank,ref mut expression_work::State w,usize deadline,ref mut usize fuel){
    var usize operand_fuel=metadata_budget::unlimited();
    let expression_work::Frame f=expression_work::current(w);var locals::Table active=locals::empty();
    if(w.request==3){let usize i=w.used-1;let usize copied=expression_work::names_into(bank,i,ref mut active)?;
        let u8 tag=bank.calls[i].tag;let usize length=bank.calls[i].length;let usize record=bank.calls[i].record;let usize parameter=bank.calls[i].parameter;
        let bool sliced=bank.calls[i].sliced;var bool prefix=bank.calls[i].prefix;var usize value=256;
        if(prefix && !sliced){value=call_prefix::stable(source,s,p,ref active,tag,length,record,f.depth)?;if(value==256){prefix=false;}}
        if(value==256){
            if(sliced){value=if(reference_calls::parameter(signatures,parameter)){
                reference_argument(source,s,p,ref mut active,signatures,parameter,f.depth,result_type,structure,flow,0,ref mut operand_fuel)?
            }else{slice_argument(source,s,p,ref mut active,signatures,parameter,f.depth,result_type,structure,flow,0,ref mut operand_fuel)?};}
            else if(record!=0){value=record_argument(source,s,p,ref mut active,signatures,record-1,f.depth,result_type,structure,flow,0,ref mut operand_fuel)?;}
            else{value=array_argument(source,s,p,ref mut active,signatures,tag,length,f.depth,result_type,structure,flow,0,ref mut operand_fuel)?;}
        }
        return expression_work::captured_argument(w,bank,ref active,value,prefix);
    }
    let usize copied=expression_work::environment_into(w,bank,ref mut active)?;
    return complete_operand_in_environment(source,s,p,ref active,signatures,result_type,structure,flow,bank,w,deadline,fuel);
}

// No captured lexical table is retained by the ordinary scalar/conditional path.
fn Result<usize,errors::Error> complete_expression_operand(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,u8 result_type,
    usize structure,ref mut loops::State flow,ref mut expression_work::Bank bank,ref mut expression_work::State w,usize deadline,ref mut usize fuel){
    let expression_work::Frame f=expression_work::current(w);
    if(w.request!=3 && f.environment==34){return complete_operand_in_environment(source,s,p,names,signatures,result_type,structure,flow,bank,w,deadline,fuel);}
    return complete_captured_operand(source,s,p,names,signatures,result_type,structure,flow,bank,w,deadline,fuel);
}

pub fn Result<usize,errors::Error> expression_staged(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,u8 minimum,
    usize depth,u8 expected,u8 result_type,usize structure,ref mut loops::State flow){
    var usize fuel=metadata_budget::unlimited();
    return expression_metered(source,s,p,table,signatures,minimum,depth,expected,result_type,structure,flow,0,ref mut fuel);
}
fn Result<usize,errors::Error> expression_metered(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,u8 minimum,
    usize depth,u8 expected,u8 result_type,usize structure,ref mut loops::State flow,usize deadline,ref mut usize fuel){
    var scratch_vec::Vec<expression_work::Bank> scratch=expression_scratch(s.begin)?;let ref mut expression_work::Bank bank=scratch_vec::at_mut<expression_work::Bank>(ref mut scratch,0);
    return expression_in_bank(source,s,p,table,signatures,minimum,depth,expected,result_type,structure,flow,bank,deadline,fuel);
}
// A lone, uncaptured root has no suspended CALL or array frame in this Bank.
// Its conditional child may reuse classifier scratch; the parent State stays
// separately owned, and tail() reinitializes its transient postfix state.
fn Result<usize,errors::Error> expression_in_bank(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,u8 minimum,
    usize depth,u8 expected,u8 result_type,usize structure,ref mut loops::State flow,ref mut expression_work::Bank bank,usize deadline,ref mut usize fuel){
    var scratch_vec::Vec<expression_work::State> state=expression_state(depth,minimum,expected,s.begin)?;let ref mut expression_work::State w=scratch_vec::at_mut<expression_work::State>(ref mut state,0);var metadata_budget::State meter=metadata_budget::empty();
    while(!w.done){
        discard metadata_budget::visit(fuel,deadline,0)?;
        let usize allowance=metadata_budget::reset(ref mut meter,s.begin)?;
        let bool done=expression_work::advance(source,s,p,table,signatures,bank,w,ref mut meter)?;
        if(w.waiting){let usize completed=complete_expression_operand(source,s,p,table,signatures,result_type,structure,flow,bank,w,deadline,fuel)?;}
    }return expression_work::prepared(w);
}

fn bool word_is(ref u8[] source, ref lexer::State s, ref u8[] word) {
    return s.kind == 2 && lexer::equal(source[s.begin..s.end], word);
}

// Keep the unmetered oracle on its original expression path. Budgeted
// assignments check for a stop before using each completed operand.
fn Result<usize,errors::Error> assignment_operand(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    usize depth,u8 expected,u8 result_type,usize structure,ref mut loops::State flow,usize deadline,ref mut usize fuel){
    if(deadline==0 && *fuel==metadata_budget::unlimited()){
        return expression(source,s,p,names,signatures,1,depth,expected,result_type,structure,flow);
    }
    let usize value=expression_metered(source,s,p,names,signatures,1,depth,expected,result_type,structure,flow,deadline,fuel)?;
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    return .ok(value);
}

fn Result<usize, errors::Error> array_copy_statement(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, usize index, usize at, usize id, u8 terminator, u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state,usize place,usize deadline,ref mut usize fuel) {
    if(s.kind==40 || arm_syntax::operand_kind(source,s)!=0){
        let aggregate_work::Plan plan=aggregate_work::inspect_metered(source,*s,p,table,signatures,2,deadline,fuel)?;
        if(plan.kind==1){return array_grouped_literal_assignment(source,s,p,table,signatures,index,id,at,terminator,result_type,expr_depth,structure,loop_state,place,deadline,fuel);}
        let u8 element=p.arrays.elements[id];let usize length=p.arrays.lengths[id];
        let array_expressions::Value value=array_value_into(source,s,p,table,signatures,element,length,false,at,expr_depth,result_type,structure,loop_state,16,deadline,fuel)?;
        let usize end=lexer::punctuation(source,s,terminator)?;
        let usize assigned=aggregate_stores::copy_array(p,table,place,id,value.id,value.owned,at)?;
        return .ok(index);
    }
    if ((s.kind!=2 && s.kind!=5)) { return .err(errors::make(3, s.begin)); }
    let usize origin = locals::find(source, table, s.begin, s.end);
    var lexer::State look=lexer::snapshot(s);
    let usize advance=lexer::next(source,ref mut look)?;
    if(look.kind==40) {
        if(origin!=64) {return .err(errors::make(3,s.begin));}
        let usize target=functions::find(source,signatures,s.begin,s.end);
        let usize temporary=array_results::destination(signatures,target,p.arrays.elements[id],p.arrays.lengths[id],false,p,table.function,s.begin)?;
        let usize name=lexer::next(source,s)?;
        let usize called=captured_call(source,s,p,table,signatures,target,temporary,at,expr_depth,result_type,structure,loop_state,deadline,fuel)?;
        let usize end=lexer::punctuation(source,s,terminator)?;
        let usize assigned=aggregate_stores::copy_array(p,table,place,id,temporary,true,at)?;
        return .ok(index);
    }
    if (!arrays::binding(table, origin)) { return .err(errors::make(3, s.begin)); }
    let usize source_id = table.registers[origin] - 128;
    let usize next = lexer::next(source, s)?;
    let usize end_statement = lexer::punctuation(source, s, terminator)?;
    let usize assigned = aggregate_stores::copy_array(p,table,place,id,source_id,false,at)?;
    return .ok(index);
}

fn Result<usize, errors::Error> array_write_statement(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize index, usize at, usize id, u8 terminator, u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state,usize deadline,ref mut usize fuel) {
    if (s.kind != 91) { return .err(errors::make(3, at)); }
    let usize open = lexer::punctuation(source, s, 91)?;
    let usize index_at=s.begin;
    let usize subscript = assignment_operand(source,s,p,table,signatures,expr_depth+1,12,result_type,structure,loop_state,deadline,fuel)?;
    if (p.types[subscript] != 12) { return .err(errors::make(3, at)); }
    let usize close = lexer::punctuation(source, s, 93)?;
    if(!lexer::assignment(s.kind)){return .err(errors::make(2,s.begin));}
    let usize operation_at=s.begin;let u8 operation=places::compound(s.kind);
    let usize equals=lexer::next(source,s)?;
    let u8 element = p.arrays.elements[id];
    if(operation!=0 && !types::integer(element)){return .err(errors::make(3,operation_at));}
    var locals::Table names=locals::snapshot(table);
    let usize place=places::select(p,ref mut names,id,subscript,index_at)?;
    let usize old=if(operation==0){128}else{ir::place_read(p,place,id,operation_at)?};
    var usize value=assignment_operand(source,s,p,ref names,signatures,expr_depth,element,result_type,structure,loop_state,deadline,fuel)?;
    if (p.types[value] != element) { return .err(errors::make(3, at)); }
    let usize end_statement = lexer::punctuation(source, s, terminator)?;
    if(operation!=0){value=ir::emit(p,operation,old,value,operation_at)?;}
    let usize written=ir::place_store(p,place,id,value,operation_at)?;
    let usize ended=places::end(p,ref mut names,place,operation_at)?;
    return .ok(index);
}

// Keep array-only lowering out of recursive scalar statement frames.
fn Result<usize, errors::Error> array_statement(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize index, usize at, u8 terminator, u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state,usize deadline,ref mut usize fuel) {
    // For headers remain scalar-only; never use an array binding as a
    // scalar register in the header/post validation paths.
    if (result_type == 0) { return .err(errors::make(3, at)); }
    let usize id = table.registers[index] - 128;
    if (slices::borrowed(table,p,id)) { return .err(errors::make(3,at)); }
    if (s.kind == 61) {
        let usize equals = lexer::next(source, s)?;
        var locals::Table names=locals::snapshot(table);
        let usize place=places::array(p,ref mut names,id,at)?;
        if(s.kind==91){return array_grouped_literal_assignment(source,s,p,ref mut names,signatures,index,id,at,
            terminator,result_type,expr_depth,structure,loop_state,place,deadline,fuel);}
        return array_copy_statement(source,s,p,ref mut names,signatures,index,at,id,terminator,result_type,
            expr_depth,structure,loop_state,place,deadline,fuel);
    }
    return array_write_statement(source,s,p,table,signatures,index,at,id,terminator,result_type,expr_depth,structure,loop_state,deadline,fuel);
}

// Field calls publish only an anonymous returned root. Snapshot it and release
// its owner before evaluating siblings; the parent destination is still pending.
fn Result<usize, errors::Error> record_child_call(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures,
    ref mut record_values::Initializer state, ref mut usize[] slots, usize first,
    usize at, u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state,usize deadline,ref mut usize fuel) {
    var lexer::State atom=lexer::snapshot(s);if(s.kind==2 || s.kind==5){let usize next=lexer::next(source,ref mut atom)?;}
    if(s.kind==40 || atom.kind==123 || arm_syntax::operand_kind(source,s)!=0){
        let record_expressions::Value value=record_value_into(source,s,p,table,signatures,false,at,expr_depth+1,result_type,structure,loop_state,16,deadline,fuel)?;
        return record_expressions::stage(source,s,p,state,slots,first,ref value,at);
    }

    if(s.kind!=2 && s.kind!=5) {return .ok(0);}
    var lexer::State look=lexer::snapshot(s);
    let usize next=lexer::next(source,ref mut look)?;
    if(look.kind!=40) {return .ok(0);}
    if(locals::find(source,table,s.begin,s.end)!=64) {return .err(errors::make(3,s.begin));}
    let usize target=functions::find(source,signatures,s.begin,s.end);
    if(target>=signatures.count || signatures.return_records[target]==0) {return .err(errors::make(3,s.begin));}
    let usize nominal=(signatures.return_records[target] as usize)-1;
    let usize temporary=record_results::destination(signatures,target,nominal,false,p,table.function,s.begin)?;
    let usize name=lexer::next(source,s)?;
    let usize called=captured_call(source,s,p,table,signatures,target,144+temporary,at,expr_depth+2,result_type,structure+1,loop_state,deadline,fuel)?;
    let usize copied=record_values::stage_call_child(source,s,p,state,slots,first,temporary,at,ref signatures.context)?;
    let usize dropped=ir::record_drop(p,temporary,at)?;
    return .ok(copied);
}

// Shared declaration/replacement/return staging: finish every RHS expression before
// consecutive scalar loads. No destination owner or bytes change here.
// Ordered scalar slots are reusable by projections, parent constructors and
// existing-owner replacement before any complete record owner must exist.
fn Result<record_expressions::Staged,errors::Error> record_constructor_fields_staged(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    usize record,usize at,u8 result_type,usize depth,usize structure,ref mut loops::State flow){
    var usize fuel=metadata_budget::unlimited();
    var record_work::State w=record_work::begin(record,at,depth);var metadata_budget::State meter=metadata_budget::empty();
    while(!w.done){let usize allowance=metadata_budget::reset(ref mut meter,s.begin)?;let bool done=record_work::advance(p,ref mut w,ref mut meter)?;
        let u8 request=w.request;var usize value=0;var record_values::Initializer state=w.initializer;let usize row=w.row;
        if(request==1){w.tag=record_values::next_leaf(source,s,p,ref mut state,at,ref signatures.context)?;
            if(w.phase==3 && record_values::shorthand(ref state)){record_values::rewind_shorthand(s,ref state);record_values::consumed_shorthand(ref mut state);}}
        else if(request==2){value=expression_staged(source,s,p,names,signatures,1,depth+2,w.tag,result_type,structure+1,flow)?;}
        else if(request==3){var usize[16] slots=w.slots;
            value=record_child_call(source,s,p,names,signatures,ref mut state,ref mut slots,row,at,result_type,depth,structure,flow,0,ref mut fuel)?;
            if(value==0){value=record_values::stage_child(source,s,p,names,ref mut state,ref mut slots,row,at,ref signatures.context)?;}w.slots=slots;}
        else if(request==4){value=record_values::leaf_count(p,record,at)?;}
        else if(request==5){value=record_values::advance(source,s,p,ref mut state)?;}
        if(request!=0){w.initializer=state;let usize resumed=record_work::resume(ref mut w,request,value)?;}
    }let usize count=record_work::prepared(ref w)?;return .ok(record_expressions::Staged{.slots=w.slots,.count=count});
}
fn Result<record_expressions::Staged,errors::Error> record_constructor_fields(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize record,usize at,u8 result_type,usize expr_depth,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    if(expr_depth>signatures.semantic_depth){return .err(errors::make(4,at));}
    let usize leaves = record_values::leaf_count_metered(p,record,at,deadline,fuel)?;
    var usize[16] slots = [0; 16]; var usize i = 0;
    var record_values::Initializer state = record_values::initializer(record);
    i = 0;
    while (i < leaves) {
        let u8 tag = record_values::next_leaf_metered(source,s,p,ref mut state,at,ref signatures.context,deadline,fuel)?;
        if (tag == 255) {
            if (record_values::shorthand(ref state)) {
                record_values::rewind_shorthand(s,ref state);
                record_values::consumed_shorthand(ref mut state);
            }
            let usize called=record_child_call(source,s,p,table,signatures,ref mut state,ref mut slots,i,at,result_type,expr_depth,structure,loop_state,deadline,fuel)?;
            if(called!=0) {i+=called;continue;}
            let usize copied = record_values::stage_child(source,s,p,table,ref mut state,ref mut slots,i,at,ref signatures.context)?;
            i += copied; continue;
        }
        if (record_values::shorthand(ref state)) {
            record_values::rewind_shorthand(s,ref state);
            record_values::consumed_shorthand(ref mut state);
        }
        slots[i] = ir::slot(p,tag,at)?;
        let usize value = assignment_operand(source,s,p,table,signatures,expr_depth+2,tag,result_type,structure+1,loop_state,deadline,fuel)?;
        if (p.types[value] != tag) { return .err(errors::make(3,at)); }
        let usize store = ir::raw(p,18,slots[i],value,0,at)?; i += 1;
        let usize member = record_values::advance_metered(source,s,p,ref mut state,deadline,fuel)?;
    }
    let u8 closed = record_values::next_leaf_metered(source,s,p,ref mut state,at,ref signatures.context,deadline,fuel)?;
    if (closed != 0) { return .err(errors::make(3,at)); }
    return .ok(record_expressions::Staged{.slots=slots,.count=leaves});
}

fn Result<usize, errors::Error> record_declaration(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p,
    ref mut locals::Table table, ref functions::Table signatures, bool mutable, u8 terminator, u8 result_type,
    usize expr_depth, usize structure, ref mut loops::State loop_state) {
    let usize record = record_values::named(source, s,ref signatures.context)?;
    let record_values::Header header = record_values::header(source,s,p,table,record,mutable,terminator,result_type)?;
    return record_initializer(source,s,p,table,signatures,header,terminator,result_type,expr_depth,structure,loop_state);
}
fn Result<usize,errors::Error> record_initializer(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    record_values::Header header,u8 terminator,u8 result_type,usize expr_depth,usize structure,ref mut loops::State loop_state){
    if(result_type==0 || terminator!=59){return .err(errors::make(3,header.begin));}
    let record_expressions::Value value=record_value(source,s,p,table,signatures,header.mutable,header.begin,expr_depth,result_type,structure,loop_state)?;
    if(value.tag!=0 || value.record!=header.record){return .err(errors::make(3,header.begin));}
    let usize end=lexer::punctuation(source,s,terminator)?;
    let usize id=record_expressions::materialize(p,table.function,ref value,header.mutable,header.begin)?;
    return locals::declare(table,header.begin,header.end,144+id,header.mutable);
}

// Keep the pending slice absent from names while ordinary endpoint expressions
// execute. Existing exits then clean only the owners/borrows already published.
fn Result<usize, errors::Error> slice_declaration(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures,
    bool mutable, u8 terminator, u8 result_type, usize depth, usize structure, ref mut loops::State loop_state) {
    let slices::Header header = slices::declaration(source,s,table,mutable,terminator,result_type)?;
    return slice_initializer(source,s,p,table,signatures,header,false,result_type,depth,structure,loop_state);
}
fn Result<usize, errors::Error> slice_initializer(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures,
    slices::Header header,bool inferred,u8 result_type,usize depth,usize structure,ref mut loops::State loop_state) {
    if((s.kind==2 || s.kind==5) && !word_is(source,s,b"ref")){
        var lexer::State look=lexer::snapshot(s);let usize next=lexer::next(source,ref mut look)?;
        if(look.kind==40){
            let usize target=functions::find(source,signatures,s.begin,s.end);
            if(locals::find(source,table,s.begin,s.end)!=64 || target>=signatures.count ||
                signatures.return_slice_elements[target]!=(header.element|if(header.exclusive){128}else{0})){return .err(errors::make(3,s.begin));}
            let usize name=lexer::next(source,s)?;
            var usize value=call_value(source,s,p,table,signatures,target,176,header.begin,depth,result_type,structure,loop_state)?;
            let usize retained=result_calls::publish(p,table,value,header.begin)?;
            if(s.kind==91){
                let usize captured=locals::declare(table,header.begin,header.begin,value,header.exclusive)?;
                let return_ranges::Bounds bounds=slice_bounds(source,s,p,table,signatures,value-160,header.begin,structure,depth,result_type,loop_state)?;
                let usize end=lexer::punctuation(source,s,59)?;
                value=160+return_ranges::acquire(p,value-160,table.function,bounds.lo,bounds.hi,header.begin)?;
            }else{let usize end=lexer::punctuation(source,s,59)?;}
            return locals::declare(table,header.begin,header.end,value,header.exclusive);
        }
    }
    if(!inferred || word_is(source,s,b"ref")){let usize reference=lexer::word(source,s,b"ref")?;}
    if(header.exclusive){let usize access=lexer::word(source,s,b"mut")?;}
    let usize index = if ((s.kind==2 || s.kind==5)) { locals::find(source,table,s.begin,s.end) } else { 64 };
    let usize parent = if (slices::binding(table,index)) { table.registers[index]-160 } else { 16 };
    if (parent < 16 && header.exclusive != ir::exclusive(p,parent)) { return .err(errors::make(3,header.begin)); }
    var usize root = 0;
    if (parent < 16) {
        if (p.slice_roots[parent] != 0) { root = (p.slice_roots[parent] as usize)-1; }
        let usize name = lexer::next(source,s)?;
        // A bare parent reborrows its complete retained range through SUBSLICE.
        if (s.kind != 91 && s.kind != 59) { return .err(errors::make(3,header.begin)); }
    } else { root = slices::root_argument(source,s,p,table,header.element)?; }
    let u8 element = if (parent < 16) { ir::slice_element(p,parent,header.begin)? } else { p.arrays.elements[root] };
    if (element != header.element) { return .err(errors::make(3,header.begin)); }
    if (header.exclusive && parent == 16 && (!p.arrays.mutable[root] || !table.mutable[index])) { return .err(errors::make(3,header.begin)); }
    var usize lo = 0;
    var usize hi = 0;
    if (s.kind == 91) {
        let usize open = lexer::next(source,s)?;
        lo = if (s.kind == 46) { ir::integer(p,0,12,header.begin)? }
            else { expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)? };
        if (p.types[lo] != 12) { return .err(errors::make(3,header.begin)); }
        let usize first = lexer::punctuation(source,s,46)?;
        let usize second = lexer::punctuation(source,s,46)?;
        hi = if (s.kind == 93) { if (parent < 16) { ir::slice_length(p,parent,header.begin)? } else { arrays::length_value(p,root,header.begin)? } }
            else { expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)? };
        if (p.types[hi] != 12) { return .err(errors::make(3,header.begin)); }
        let usize close = lexer::punctuation(source,s,93)?;
    } else {
        lo = ir::integer(p,0,12,header.begin)?;
        hi = if (parent < 16) { ir::slice_length(p,parent,header.begin)? }
            else { arrays::length_value(p,root,header.begin)? };
    }
    let usize end = lexer::punctuation(source,s,59)?;
    let usize site = if (parent < 16 && header.exclusive) { reborrow::derived(p,parent,header.begin)? }
    else if (parent < 16 && p.slice_origins[parent] != 0) {
        slice_builders::derived(p,parent,table.function,header.begin)?
    } else if (header.exclusive) { ir::exclusive_slice(p,root,header.begin)? }
        else { ir::slice(p,root,header.begin)? };
    let usize opened = if (parent < 16 && header.exclusive) { reborrow::begin(p,site,parent,lo,hi,header.begin)? }
        else if (parent < 16) { ir::slice_sub(p,site,parent,lo,hi,header.begin)? }
        else { ir::slice_open(p,site,lo,hi,header.begin)? };
    return locals::declare(table,header.begin,header.end,160+site,header.exclusive);
}
// Exclusive bindings permit element stores, never rebinding or scalar STORE.
// Keep index/value expression scratch off the recursive scalar statement path.
fn Result<usize,errors::Error> slice_write_statement(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize index,usize at,u8 terminator,u8 result_type,usize depth,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel) {
    let usize site=table.registers[index]-160;
    if(result_type==0 || !ir::exclusive(p,site) || s.kind!=91) { return .err(errors::make(3,at)); }
    let usize open=lexer::next(source,s)?;
    let usize subscript=assignment_operand(source,s,p,table,signatures,depth+1,12,result_type,structure,loop_state,deadline,fuel)?;
    if(p.types[subscript]!=12) { return .err(errors::make(3,at)); }
    let usize close=lexer::punctuation(source,s,93)?;
    if(!lexer::assignment(s.kind)){return .err(errors::make(2,s.begin));}
    let usize operation_at=s.begin;let u8 operation=places::compound(s.kind);
    let usize equals=lexer::next(source,s)?;
    let u8 element=ir::slice_element(p,site,at)?;
    if(operation!=0 && !types::integer(element)){return .err(errors::make(3,operation_at));}
    var locals::Table names=locals::snapshot(table);
    let usize place=places::slice(p,ref mut names,site,subscript,at)?;
    let usize old=if(operation==0){128}else{slice_places::read(p,place,site,operation_at)?};
    var usize value=assignment_operand(source,s,p,ref names,signatures,depth,element,result_type,structure,loop_state,deadline,fuel)?;
    if(p.types[value]!=element) { return .err(errors::make(3,at)); }
    let usize end=lexer::punctuation(source,s,terminator)?;
    if(operation!=0){value=ir::emit(p,operation,old,value,operation_at)?;}
    let usize written=slice_places::store(p,place,site,value,operation_at)?;
    let usize ended=places::end(p,ref mut names,place,operation_at)?;
    return .ok(index);
}
fn Result<usize,errors::Error> inferred_declaration(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    bool mutable,u8 terminator,u8 result_type,usize expr_depth,usize structure,ref mut loops::State loop_state){
    let inference::Header name=inference::header(source,s,table)?;
    let arm_syntax::Conditional conditional=arm_syntax::conditional_atom(source,s)?;
    if(conditional.valid && conditional.suffix==terminator){
        return conditional_initializer(source,s,p,table,signatures,name,mutable,terminator,result_type,expr_depth,structure,loop_state);
    }
    let record_expressions::Plan record_plan=record_expressions::inspect(source,s,p,table,signatures)?;
    if(record_plan.kind!=0 && record_plan.tag==0 && record_plan.suffix==terminator){
        let usize checked=record_values::declaration_limit(p,table,record_plan.record,terminator,result_type,name.begin)?;
        let record_values::Header header=record_values::Header{.record=record_plan.record,.begin=name.begin,.end=name.end,.mutable=mutable};
        return record_initializer(source,s,p,table,signatures,header,terminator,result_type,expr_depth,structure,loop_state);
    }
    let reference_inference::Shape view=reference_inference::inspect(source,s,p,table,signatures)?;
    if(view.kind!=0){
        return inferred_reference(source,s,p,table,signatures,name,view,mutable,terminator,result_type,expr_depth,structure,loop_state);
    }
    if(s.kind==40){
        let array_expressions::Plan plan=array_expressions::inspect(source,s,p,table,signatures)?;
        if(plan.kind!=0 && plan.suffix==terminator){
            return array_grouped_initializer(source,s,p,table,signatures,name,0,0,mutable,terminator,result_type,expr_depth,structure,loop_state);
        }
    }
    if(s.kind==91 && array_locals::projection(source,s)?.kind==0){
        if(!array_locals::is_repeated(source,s)?){
            return array_list_initializer(source,s,p,table,signatures,name,0,0,mutable,terminator,result_type,expr_depth,structure,loop_state);
        }
        return inferred_repeated_array(source,s,p,table,signatures,name,mutable,terminator,result_type,expr_depth,structure,loop_state);
    }
    let aggregate_inference::Shape shape=aggregate_inference::inspect(source,s,p,table,signatures)?;
    if(shape.record!=0){
        let usize record=shape.record-1;
        let usize checked=record_values::declaration_limit(p,table,record,terminator,result_type,name.begin)?;
        if(p.records.count>=16){return .err(errors::make(4,name.begin));}
        let record_values::Header header=record_values::Header{.record=record,.begin=name.begin,.end=name.end,.mutable=mutable};
        return record_initializer(source,s,p,table,signatures,header,terminator,result_type,expr_depth,structure,loop_state);
    }
    if(shape.length!=0){
        return array_initializer(source,s,p,table,signatures,name,shape.element,shape.length,mutable,terminator,result_type,expr_depth,structure,loop_state);
    }
    let usize before=p.count;
    let usize value=expression(source,s,p,table,signatures,1,expr_depth,0,result_type,structure,loop_state)?;
    let usize end=lexer::punctuation(source,s,terminator)?;
    if(signatures.scalar_host_calls && value<128 && p.types[value]==14){
        if(mutable || terminator!=59 || result_type==0 || !host_source::fresh_bytes(p,before,value)){
            return .err(errors::make(3,name.begin));
        }
        return locals::declare(table,name.begin,name.end,value,false);
    }
    return inference::bind(p,table,name,value,mutable,result_type==0);
}
fn Result<usize,errors::Error> conditional_initializer(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    inference::Header name,bool mutable,u8 terminator,u8 result_type,usize depth,usize structure,ref mut loops::State loop_state){
    let usize groups=if(s.kind==40){array_expressions::open(source,s,depth,signatures.semantic_depth)?}else{0};
    var joins::Join join=joins::empty(0,mutable);
    let bool terminal=value_join(source,s,p,table,signatures,ref mut join,depth+groups,result_type,structure,loop_state)?;
    if(terminal){return .err(errors::make(3,name.begin));}
    let usize value=joins::finish(p,ref join,name.begin)?;
    let usize close=array_expressions::close(source,s,groups)?;let usize end=lexer::punctuation(source,s,terminator)?;
    if(value<128){return inference::bind(p,table,name,value,mutable,result_type==0);}
    return locals::declare(table,name.begin,name.end,value,mutable);
}
fn Result<usize,errors::Error> inferred_reference(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    inference::Header name,reference_inference::Shape shape,bool mutable,u8 terminator,u8 result_type,
    usize depth,usize structure,ref mut loops::State loop_state){
    if(mutable || terminator!=59 || result_type==0){return .err(errors::make(3,name.begin));}
    if(shape.kind==1 || shape.kind==2){
        if(shape.exclusive || !signatures.literals.enabled){return .err(errors::make(3,name.begin));}
        let static_source::Header header=static_source::Header{.begin=name.begin,.end=name.end,.kind=shape.kind};
        return static_initializer(source,s,p,table,signatures,header,terminator,result_type,depth,structure,loop_state);
    }
    let slices::Header header=slices::Header{.begin=name.begin,.end=name.end,.element=shape.element,.exclusive=shape.exclusive};
    return slice_initializer(source,s,p,table,signatures,header,true,result_type,depth,structure,loop_state);
}
fn Result<usize,errors::Error> inferred_repeated_array(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    inference::Header name,bool mutable,u8 terminator,u8 result_type,usize expr_depth,usize structure,ref mut loops::State loop_state){
    if(result_type==0 || terminator!=59){return .err(errors::make(3,name.begin));}
    let usize open=lexer::next(source,s)?;
    let usize value=expression(source,s,p,table,signatures,1,expr_depth,0,result_type,structure,loop_state)?;
    if(value>=p.registers || value>=128){return .err(errors::make(3,name.begin));}
    let u8 element=p.types[value];
    return array_locals::repeated(source,s,p,table,name,value,element,0,mutable,terminator);
}
fn Result<usize,errors::Error> array_initializer(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    inference::Header binding,u8 tag,usize length,bool mutable,u8 terminator,u8 result_type,
    usize expr_depth,usize structure,ref mut loops::State loop_state){
    if(result_type==0 || terminator!=59 || !types::scalar(tag)){return .err(errors::make(3,binding.begin));}
    if(s.kind==40 || arm_syntax::operand_kind(source,s)!=0){
        return array_grouped_initializer(source,s,p,table,signatures,binding,tag,length,mutable,terminator,result_type,expr_depth,structure,loop_state);
    }
    if(s.kind==2 || s.kind==5){
        let usize source_index=locals::find(source,table,s.begin,s.end);
        var lexer::State look=lexer::snapshot(s);let usize advance=lexer::next(source,ref mut look)?;
        if(look.kind==40){
            if(source_index!=64){return .err(errors::make(3,s.begin));}
            let usize at=s.begin;let usize target=functions::find(source,signatures,s.begin,s.end);
            let usize id=array_results::destination(signatures,target,tag,length,mutable,p,table.function,at)?;
            let usize name=lexer::next(source,s)?;
            let usize value=call_value(source,s,p,table,signatures,target,id,at,expr_depth,result_type,structure,loop_state)?;
            let usize finished=lexer::punctuation(source,s,terminator)?;
            return locals::declare(table,binding.begin,binding.end,value,mutable);
        }
        if(!arrays::binding(table,source_index)){return .err(errors::make(3,s.begin));}
        let usize source_id=table.registers[source_index]-128;
        let usize next=lexer::next(source,s)?;let usize finished=lexer::punctuation(source,s,terminator)?;
        let usize id=arrays::copy(p,table.function,source_id,tag,length,mutable,binding.begin)?;
        return locals::declare(table,binding.begin,binding.end,128+id,mutable);
    }
    if(!array_locals::is_repeated(source,s)?){
        return array_list_initializer(source,s,p,table,signatures,binding,tag,length,mutable,terminator,result_type,expr_depth,structure,loop_state);
    }
    let usize open=lexer::punctuation(source,s,91)?;
    let usize value=expression(source,s,p,table,signatures,1,expr_depth,tag,result_type,structure,loop_state)?;
    return array_locals::repeated(source,s,p,table,binding,value,tag,length,mutable,terminator);
}
// Grouping alone never creates a second literal/CALL owner. Named values copy
// only at a by-value declaration, preserving the original independent extent.
fn Result<usize,errors::Error> array_grouped_initializer(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    inference::Header binding,u8 tag,usize length,bool mutable,u8 terminator,u8 result_type,
    usize depth,usize structure,ref mut loops::State loop_state){
    if(result_type==0 || terminator!=59){return .err(errors::make(3,binding.begin));}
    let array_expressions::Value value=array_grouped_value(source,s,p,table,signatures,tag,length,mutable,binding.begin,depth,result_type,structure,loop_state)?;
    let usize end=lexer::punctuation(source,s,terminator)?;var usize id=value.id;
    if(!value.owned){let u8 element=p.arrays.elements[id];let usize size=p.arrays.lengths[id];
        id=arrays::copy(p,table.function,id,element,size,mutable,binding.begin)?;}
    return locals::declare(table,binding.begin,binding.end,128+id,mutable);
}
fn Result<usize,errors::Error> array_list_initializer(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    inference::Header name,u8 expected,usize length,bool mutable,u8 terminator,u8 result_type,
    usize depth,usize structure,ref mut loops::State loop_state){
    if(result_type==0 || terminator!=59){return .err(errors::make(3,name.begin));}
    let usize id=array_list_value(source,s,p,table,signatures,expected,length,mutable,name.begin,depth,result_type,structure,loop_state)?;
    let usize end=lexer::punctuation(source,s,terminator)?;
    return locals::declare(table,name.begin,name.end,128+id,mutable);
}
// One scalar evaluator for declarations, values and borrows. No lexical owner
// exists until all cells finish; callers publish/capture only the complete array.
// Heap-owned scratch stays off recursive expression/CALL parser frames.
fn Result<usize,errors::Error> array_list_value(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    u8 expected,usize length,bool mutable,usize offset,usize depth,u8 result_type,
    usize structure,ref mut loops::State loop_state){
    var usize operand_fuel=metadata_budget::unlimited();
    return array_list_value_into(source,s,p,table,signatures,expected,length,mutable,offset,depth,result_type,structure,loop_state,16,0,ref mut operand_fuel);
}
fn Result<usize,errors::Error> array_list_value_into(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    u8 expected,usize length,bool mutable,usize offset,usize depth,u8 result_type,
    usize structure,ref mut loops::State loop_state,usize destination,usize deadline,ref mut usize fuel){
    let vec::Vec<usize> values=array_list_cells(source,s,p,table,signatures,expected,depth,result_type,structure,loop_state,deadline,fuel)?;
    let ref usize[] cells=vec::view_usize(ref values);let u8 element=p.types[cells[0]];
    if(length!=0 && cells.len!=length){return .err(errors::make(3,offset));}
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    discard metadata_budget::charge(fuel,2*cells.len,offset)?;
    return array_locals::list_into(p,table.function,cells,element,length,mutable,offset,destination);
}
fn Result<usize,errors::Error> array_list_assignment(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    usize index,usize id,usize at,u8 terminator,u8 result_type,usize depth,
    usize structure,ref mut loops::State loop_state,usize groups,usize place,usize deadline,ref mut usize fuel){
    if(terminator!=59){return .err(errors::make(3,at));}
    let u8 element=p.arrays.elements[id];let usize length=p.arrays.lengths[id];
    let vec::Vec<usize> values=array_list_cells(source,s,p,table,signatures,element,depth,result_type,structure,loop_state,deadline,fuel)?;
    if(vec::len<usize>(ref values)!=length){return .err(errors::make(3,at));}
    let usize close=array_expressions::close(source,s,groups)?;
    let usize end=lexer::punctuation(source,s,terminator)?;
    // The dense pool checks the complete list before copying its register IDs.
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    discard metadata_budget::charge(fuel,2*length,at)?;
    let usize replaced=aggregate_stores::list_array(p,table,place,id,vec::view_usize(ref values),at)?;
    return .ok(index);
}
// Every literal store uses the selection captured before its RHS; grouped and
// bare literals share parsing without another temporary owner or payload extent.
fn Result<usize,errors::Error> array_grouped_literal_assignment(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    usize index,usize id,usize at,u8 terminator,u8 result_type,usize depth,
    usize structure,ref mut loops::State loop_state,usize place,usize deadline,ref mut usize fuel){
    if(terminator!=59){return .err(errors::make(3,at));}
    let usize groups=if(s.kind==40){array_expressions::open(source,s,depth,signatures.semantic_depth)?}else{0};
    if(!array_locals::is_repeated_metered(source,s,deadline,fuel)?){
        return array_list_assignment(source,s,p,table,signatures,index,id,at,terminator,result_type,depth+groups,structure,loop_state,groups,place,deadline,fuel);
    }
    let usize open=lexer::punctuation(source,s,91)?;
    let u8 element=p.arrays.elements[id];
    let usize value=assignment_operand(source,s,p,table,signatures,depth+groups,element,result_type,structure,loop_state,deadline,fuel)?;
    if(p.types[value]!=p.arrays.elements[id]){return .err(errors::make(3,at));}
    let usize separator=lexer::punctuation(source,s,59)?;let usize length=arrays::count(source,s)?;
    if(length!=p.arrays.lengths[id]){return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,93)?;let usize grouped=array_expressions::close(source,s,groups)?;
    let usize end=lexer::punctuation(source,s,terminator)?;
    let usize filled=aggregate_stores::fill_array(p,table,place,id,value,at)?;return .ok(index);
}
// Evaluation is shared by fresh values and existing destinations. Only the
// caller publishes an owner or replacement after its complete context validates.
fn Result<vec::Vec<usize>,errors::Error> array_list_cells(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    u8 expected,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let usize open=lexer::punctuation(source,s,91)?;
    if(s.kind==93){return .err(errors::make(3,s.begin));}
    var vec::Vec<usize> values=vec::empty<usize>();var u8 element=expected;
    while(true){
        if(vec::len<usize>(ref values)>=4096 || p.list_used>4096 ||
            vec::len<usize>(ref values)>=4096-p.list_used){return .err(errors::make(4,s.begin));}
        let usize at=s.begin;
        let usize value=assignment_operand(source,s,p,table,signatures,depth,element,result_type,structure,loop_state,deadline,fuel)?;
        if(value>=128 || value>=p.registers || !types::scalar(p.types[value])){return .err(errors::make(3,at));}
        if(element==0){element=p.types[value];}
        if(p.types[value]!=element){return .err(errors::make(3,at));}
        let usize pushed=switch(vec::push<usize>(ref mut values,value)){
            case .ok(n):{n}case .err(_):{return .err(errors::make(15,at));}
        };
        if(s.kind!=44){break;}
        let usize comma=lexer::next(source,s)?;
        if(s.kind==93){break;}
    }
    let usize close=lexer::punctuation(source,s,93)?;
    return .ok(values);
}
fn Result<usize, errors::Error> declaration(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 terminator, u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    if (word_is(source, s, b"let") || word_is(source, s, b"var")) {
        let bool mutable = word_is(source, s, b"var");
        let usize keyword = lexer::next(source, s)?;
        let usize type_at=s.begin;
        if(signatures.scalar_host_calls && word_is(source,s,b"Result")){
            if(mutable || terminator!=59 || result_type==0){return .err(errors::make(3,s.begin));}
            let u8 tag=host_source::annotation(source,s)?;
            if(signatures.semantic_depth<2){return .err(errors::make(4,type_at));}
            let inference::Header binding=inference::header(source,s,table)?;
            let usize at=s.begin;
            let usize before=p.registers;
            let usize value=expression(source,s,p,table,signatures,1,expr_depth,128+tag,result_type,structure,loop_state)?;
            if(value<before || !host_source::is_saved(p,value) || p.types[value+1]!=128+tag){
                return .err(errors::make(3,at));
            }
            let usize end=lexer::punctuation(source,s,terminator)?;
            return locals::declare(table,binding.begin,binding.end,value,false);
        }
        if(inference::follows(source,s)?){
            return inferred_declaration(source,s,p,table,signatures,mutable,terminator,result_type,expr_depth,structure,loop_state);
        }
        if (word_is(source,s,b"ref")) {
            if(signatures.semantic_depth<2){return .err(errors::make(4,type_at));}
            if(signatures.literals.enabled && (static_source::candidate(source,s,table)? || reference_calls::declaration(source,s,table,signatures)?)){
                return static_declaration(source,s,p,table,signatures,mutable,terminator,result_type,expr_depth,structure,loop_state);
            }
            return slice_declaration(source,s,p,table,signatures,mutable,terminator,result_type,expr_depth,structure,loop_state);
        }
        if ((s.kind==2 || s.kind==5) && !locals::reserved(source[s.begin..s.end])) {
            return record_declaration(source,s,p,table,signatures,mutable,terminator,result_type,expr_depth,structure,loop_state);
        }
        let declaration_headers::Prepared header=declaration_headers::prepare(source,s,table,1,mutable,terminator,result_type)?;
        let u8 tag=header.tag;let usize length=header.length;let usize begin=header.begin;let usize end=header.end;
        if(signatures.semantic_depth<2 && (types::tagged(tag) || length!=0)){return .err(errors::make(4,type_at));}
        if(length!=0){
            let inference::Header binding=inference::Header{.begin=begin,.end=end};
            return array_initializer(source,s,p,table,signatures,binding,tag,length,mutable,terminator,result_type,expr_depth,structure,loop_state);
        }
        // The new name is not visible until its initializer has been checked.
        let usize value = if(signatures.scalar_host_calls){raw_expression(source,s,p,table,signatures,1,expr_depth,tag,result_type,structure,loop_state,deadline,fuel)?}
            else{expression(source,s,p,table,signatures,1,expr_depth,tag,result_type,structure,loop_state)?};
        if (p.types[value] != tag) { return .err(errors::make(3, begin)); }
        let usize end_statement = lexer::punctuation(source, s, terminator)?;
        var usize binding = value;
        if (mutable) {
            binding = ir::slot(p, tag, begin)?;
            let usize stored = ir::raw(p, 18, binding, value, 0, begin)?;
        }
        return locals::declare(table, begin, end, binding, mutable);
    }
    return .err(errors::make(2, s.begin));
}

// Root and child call assignments keep their destination live and share argument
// evaluation. The anonymous result stays absent from locals until CALL completes.
fn Result<usize,errors::Error> record_value_assignment(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize id,record_values::Leaf target,usize at,u8 result_type,usize depth,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    var locals::Table names=locals::snapshot(table);
    let usize place=places::record_value(p,ref mut names,id,target.record,target.ordinal,at)?;
    let record_expressions::Value value=record_value_into(source,s,p,ref names,signatures,false,at,depth,result_type,structure,loop_state,16,deadline,fuel)?;
    if(value.tag!=0 || value.record!=target.record){return .err(errors::make(3,at));}
    let usize end=lexer::punctuation(source,s,59)?;
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    return aggregate_stores::record(p,ref mut names,place,id,target,ref value,at,deadline,fuel);
}
fn Result<usize, errors::Error> record_write_statement(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p,
    ref locals::Table table, ref functions::Table signatures, usize index, usize at, u8 terminator,
    u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state,usize deadline,ref mut usize fuel) {
    if (result_type == 0 || terminator != 59) { return .err(errors::make(3, at)); }
    let usize id = table.registers[index] - 144;
    let usize record = p.records.records[id] as usize;
    if(s.kind==61){let usize equals=lexer::next(source,s)?;
        let record_values::Leaf root=record_values::Leaf{.ordinal=0,.tag=0,.record=record};
        let usize assigned=record_value_assignment(source,s,p,table,signatures,id,root,at,result_type,expr_depth,structure,loop_state,deadline,fuel)?;return .ok(index);}
    let record_values::Leaf leaf=record_values::writable(source,s,p,id,at,ref signatures.context,deadline,fuel)?;
    if(!lexer::assignment(s.kind)){return .err(errors::make(2,s.begin));}
    let usize operation_at=s.begin;let u8 operation=places::compound(s.kind);
    if(operation!=0 && !types::integer(leaf.tag)){return .err(errors::make(3,operation_at));}
    let usize equals=lexer::next(source,s)?;
    if(leaf.tag==0){let usize assigned=record_value_assignment(source,s,p,table,signatures,id,leaf,at,result_type,expr_depth,structure,loop_state,deadline,fuel)?;return .ok(index);}
    let u8 tag = leaf.tag;
    var locals::Table names=locals::snapshot(table);
    let usize place=places::record(p,ref mut names,id,leaf.ordinal,at)?;
    let usize old=if(operation==0){128}else{record_places::read(p,place,id,leaf.ordinal,operation_at)?};
    var usize value = assignment_operand(source,s,p,ref names,signatures,expr_depth,tag,result_type,structure,loop_state,deadline,fuel)?;
    if (p.types[value] != tag) { return .err(errors::make(3, at)); }
    let usize end = lexer::punctuation(source,s,59)?;
    if(operation!=0){value=ir::emit(p,operation,old,value,operation_at)?;}
    let usize written=record_places::store(p,place,id,leaf.ordinal,value,operation_at)?;
    let usize ended=places::end(p,ref mut names,place,operation_at)?;
    return .ok(index);
}

// This adapter stays outside ordinary recursive scalar statement frames. Only
// grouped targets reserve a syntax plan; original target paths retain their IR.
fn Result<usize,errors::Error> grouped_assignment(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    u8 terminator,u8 result_type,usize depth,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let place_syntax::Plan plan=place_syntax::inspect(source,s)?;
    if(!plan.valid){return .err(errors::make(2,s.begin));}
    let usize at=plan.begin;let usize index=locals::find(source,table,plan.begin,plan.end);
    if(index==64 || !table.mutable[index]){return .err(errors::make(3,at));}
    s.cursor=plan.operation.cursor;s.begin=plan.operation.begin;s.end=plan.operation.end;
    s.tokens=plan.operation.tokens;s.kind=plan.operation.kind;s.value=plan.operation.value;
    s.min_magnitude=plan.operation.min_magnitude;s.context=plan.operation.context;
    if(record_values::binding(table,index)){
        if(result_type==0 || terminator!=59){return .err(errors::make(3,at));}
        let usize site=table.registers[index]-144;
        var record_values::Leaf leaf=record_values::Leaf{.ordinal=0,.tag=0,.record=p.records.records[site] as usize};
        var usize i=0;while(i<plan.count){if(plan.kinds[i]!=1){return .err(errors::make(3,plan.begins[i]));}
            leaf=record_values::project(source,p,leaf,plan.begins[i],plan.ends[i],ref signatures.context,deadline,fuel)?;i+=1;}
        if(leaf.tag==0){if(s.kind!=61){return .err(errors::make(3,s.begin));}
            let usize equals=lexer::next(source,s)?;
            let usize assigned=record_value_assignment(source,s,p,table,signatures,site,leaf,at,result_type,depth,structure,loop_state,deadline,fuel)?;return .ok(index);}
        return grouped_place_write(source,s,p,table,signatures,index,at,2,site,leaf.ordinal,leaf.tag,at,terminator,result_type,depth,structure,loop_state,deadline,fuel);
    }
    let bool array=arrays::binding(table,index);let bool slice=slices::binding(table,index);
    if(array && plan.count==0){return array_statement(source,s,p,table,signatures,index,at,terminator,result_type,depth,structure,loop_state,deadline,fuel);}
    if(array || slice){
        if(result_type==0 || plan.count!=1 || plan.kinds[0]!=2){return .err(errors::make(3,at));}
        let usize site=table.registers[index]-if(array){128}else{160};
        if((array && slices::borrowed(table,p,site)) || (slice && !ir::exclusive(p,site))){return .err(errors::make(3,at));}
        var lexer::State operand=lexer::snapshot(ref plan.operands[0]);
        let usize selected=assignment_operand(source,ref mut operand,p,table,signatures,depth+1,12,result_type,structure,loop_state,deadline,fuel)?;
        if(p.types[selected]!=12){return .err(errors::make(3,at));}
        if(operand.kind!=93 || operand.begin!=plan.ends[0]){return .err(errors::make(2,operand.begin));}
        let u8 tag=if(array){p.arrays.elements[site]}else{ir::slice_element(p,site,at)?};
        return grouped_place_write(source,s,p,table,signatures,index,at,if(array){0}else{1},site,selected,tag,
            if(array){plan.begins[0]}else{at},terminator,result_type,depth,structure,loop_state,deadline,fuel);
    }
    if(plan.count!=0){return .err(errors::make(3,at));}
    return scalar_assignment(source,s,p,table,signatures,index,at,terminator,result_type,depth,structure,loop_state,deadline,fuel);
}
fn Result<usize,errors::Error> grouped_place_write(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize index,usize at,u8 kind,usize site,usize selected,u8 tag,usize select_at,
    u8 terminator,u8 result_type,usize depth,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let usize operation_at=s.begin;let u8 operation=places::compound(s.kind);
    if(operation!=0 && !types::integer(tag)){return .err(errors::make(3,operation_at));}
    let usize equals=lexer::next(source,s)?;var locals::Table names=locals::snapshot(table);
    let usize place=if(kind==2){places::record(p,ref mut names,site,selected,select_at)?}
        else if(kind==1){places::slice(p,ref mut names,site,selected,select_at)?}
        else{places::select(p,ref mut names,site,selected,select_at)?};
    let usize old=if(operation==0){128}else if(kind==2){record_places::read(p,place,site,selected,operation_at)?}
        else if(kind==1){slice_places::read(p,place,site,operation_at)?}else{ir::place_read(p,place,site,operation_at)?};
    var usize value=assignment_operand(source,s,p,ref names,signatures,depth,tag,result_type,structure,loop_state,deadline,fuel)?;
    if(p.types[value]!=tag){return .err(errors::make(3,at));}
    let usize end=lexer::punctuation(source,s,terminator)?;
    if(operation!=0){value=ir::emit(p,operation,old,value,operation_at)?;}
    let usize written=if(kind==2){record_places::store(p,place,site,selected,value,operation_at)?}
        else if(kind==1){slice_places::store(p,place,site,value,operation_at)?}else{ir::place_store(p,place,site,value,operation_at)?};
    let usize ended=places::end(p,ref mut names,place,operation_at)?;return .ok(index);
}
fn Result<usize, errors::Error> statement(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 terminator, u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state, usize deadline, ref mut usize fuel) {
    if(word_is(source,s,b"_")){return discard_statement(source,s,p,table,signatures,terminator,result_type,expr_depth,structure,loop_state);}
    if(s.kind==40){return grouped_assignment(source,s,p,table,signatures,terminator,result_type,expr_depth,structure,loop_state,deadline,fuel);}
    if (word_is(source, s, b"let") || word_is(source, s, b"var")) {
        return declaration(source,s,p,table,signatures,terminator,result_type,expr_depth,structure,loop_state,deadline,fuel);
    }
    if(output_source::candidate(source,s,table,signatures)){return output_statement(source,s,p,table,signatures,terminator,result_type,expr_depth,structure,loop_state,deadline,fuel);}
    if(arm_syntax::direct_call(source,s)?){return void_call_statement(source,s,p,table,signatures,terminator,result_type,expr_depth,structure,loop_state);}
    if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) {
        return .err(errors::make(2, s.begin));
    }
    let usize at = s.begin;
    let usize index = locals::find(source, table, s.begin, s.end);
    if (index == 64 || !table.mutable[index]) { return .err(errors::make(3, at)); }
    let usize target = lexer::next(source, s)?;
    if (record_values::binding(table, index)) {
        return record_write_statement(source,s,p,table,signatures,index,at,terminator,result_type,expr_depth,structure,loop_state,deadline,fuel);
    }
    if (arrays::binding(table, index)) {
        return array_statement(source,s,p,table,signatures,index,at,terminator,result_type,expr_depth,structure,loop_state,deadline,fuel);
    }
    if (slices::binding(table,index)) {
        return slice_write_statement(source,s,p,table,signatures,index,at,terminator,result_type,expr_depth,structure,loop_state,deadline,fuel);
    }
    return scalar_assignment(source,s,p,table,signatures,index,at,terminator,result_type,expr_depth,structure,loop_state,deadline,fuel);
}
// Explicit discard acknowledges a value without a binding or extra instruction.
// Ordinary expression/CALL lowering retains argument captures and exit cleanup.
fn Result<usize,errors::Error> discard_statement(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    u8 terminator,u8 result_type,usize depth,usize structure,ref mut loops::State loop_state){
    let usize at=s.begin;
    if(terminator!=59 || result_type==0){return .err(errors::make(3,at));}
    let usize name=lexer::next(source,s)?;let usize equal=lexer::punctuation(source,s,61)?;
    let usize value=expression(source,s,p,table,signatures,1,depth,0,result_type,structure,loop_state)?;
    if(value>=128 || !types::valid(p.types[value])){return .err(errors::make(3,at));}
    let usize end=lexer::punctuation(source,s,59)?;return .ok(64);
}
fn Result<usize,errors::Error> scalar_assignment(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize index,usize at,u8 terminator,u8 result_type,usize expr_depth,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    if(!lexer::assignment(s.kind)){return .err(errors::make(2,s.begin));}
    let usize operation_at=s.begin;let u8 operation=places::compound(s.kind);
    // Mutable scalar bindings name stable frame slots. Capture the old value
    // before RHS work; its LOAD result is a fresh immutable register.
    let usize slot=table.registers[index];let u8 target_type=p.types[slot];
    if(operation!=0 && !types::integer(target_type)){return .err(errors::make(3,operation_at));}
    let usize equals=lexer::next(source,s)?;
    let usize old=if(operation==0){128}else{ir::emit(p,17,slot,0,operation_at)?};
    var usize value=assignment_operand(source,s,p,table,signatures,expr_depth,target_type,result_type,structure,loop_state,deadline,fuel)?;
    if (p.types[value] != target_type) { return .err(errors::make(3, at)); }
    let usize end_statement = lexer::punctuation(source, s, terminator)?;
    if(operation!=0){value=ir::emit(p,operation,old,value,operation_at)?;}
    let usize stored = ir::raw(p, 18, slot, value, 0, at)?;
    return .ok(index);
}
// Reuse existing effectful view/CALL/range lowering and lexical suffix cleanup.
// The output observation itself neither captures nor closes a caller-owned view.
fn Result<usize,errors::Error> output_statement(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    u8 terminator,u8 result_type,usize depth,usize structure,ref mut loops::State loop_state,
    usize deadline,ref mut usize fuel){
    if(signatures.scalar_host_calls){return host_output_statement(source,s,p,table,signatures,terminator,result_type,deadline,fuel);}
    let usize at=output_source::head(source,s,signatures,terminator,result_type,deadline,fuel)?;
    var locals::Table names=locals::snapshot(table);
    var usize site=16;var u8 kind=2;
    // Pure lookahead; receiver, endpoints and helper calls are lowered once.
    let bool image=output_source::image(source,s,deadline,fuel)? ||
        static_source::binding(table,locals::find(source,table,s.begin,s.end)) ||
        reference_calls::returned_atom(source,s,table,signatures)?;
    if(image){
        let static_source::View view=static_view_metered(source,s,p,ref names,signatures,depth,result_type,structure,loop_state,deadline,fuel)?;
        if(view.kind!=1){return .err(errors::make(3,at));}site=view.site;kind=1;
        if(view.owned){
            let usize roots=reference_results::publish(p,signatures,ref mut names,site,at)?;
            let usize hidden=locals::declare(ref mut names,at,at,192+site,false)?;
        }
    }else{
        let u8 access=output_source::access(source,s,table,p);
        let usize value=slice_actual(source,s,p,ref mut names,signatures,access,at,depth,result_type,structure,loop_state,deadline,fuel)?;
        if(value<160 || value>=176){return .err(errors::make(3,at));}site=value-160;
    }
    discard lexer::punctuation_metered(source,s,41,deadline,fuel)?;
    discard lexer::punctuation_metered(source,s,59,deadline,fuel)?;
    discard metadata_budget::visit(fuel,deadline,at)?;
    let usize emitted=output_ir::emit(p,site,kind,at)?;
    let usize released=arrays::release_from(ref names,p,table.count,at)?;return .ok(64);
}
fn Result<usize,errors::Error> host_output_statement(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    u8 terminator,u8 result_type,usize deadline,ref mut usize fuel){
    let usize at=s.begin;
    if(!signatures.output || terminator!=59 || result_type==0){return .err(errors::make(3,at));}
    discard lexer::next_metered(source,s,deadline,fuel)?;
    discard lexer::punctuation_metered(source,s,40,deadline,fuel)?;
    let usize value=host_source::byte_argument_metered(source,s,p,names,deadline,fuel)?;
    discard lexer::punctuation_metered(source,s,41,deadline,fuel)?;
    discard lexer::punctuation_metered(source,s,59,deadline,fuel)?;
    discard metadata_budget::visit(fuel,deadline,at)?;
    discard ir::raw(p,host_program::emit_opcode(),0,value,0,at)?;
    return .ok(64);
}
fn Result<usize,errors::Error> void_call_statement(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    u8 terminator,u8 result_type,usize depth,usize structure,ref mut loops::State loop_state){
    let usize at=s.begin;let usize target=functions::find(source,signatures,s.begin,s.end);
    if(terminator!=59 || result_type==0 || target>=signatures.count || signatures.return_types[target]!=13 ||
        locals::find(source,table,s.begin,s.end)!=64){return .err(errors::make(3,at));}
    let usize name=lexer::next(source,s)?;
    let usize called=call_value(source,s,p,table,signatures,target,16,at,depth,result_type,structure,loop_state)?;
    let usize end=lexer::punctuation(source,s,59)?;return .ok(64);
}

// Value arms have a private binding table; assignments still address the
// original outer var slots. Their final expression has no trailing semicolon.
struct Yield {usize value; bool terminal;}
// Boolean branches share the existing value-arm scope and nonlocal-exit
// cleanup. Only continuing value paths store into the lazy exact-type join.
fn Result<Yield,errors::Error> if_value(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize depth,u8 expected,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let usize at=s.begin;var joins::Join join=joins::empty(expected,false);
    let bool terminal=value_join_metered(source,s,p,table,signatures,ref mut join,depth,result_type,structure,loop_state,deadline,fuel)?;
    if(terminal){return .ok(Yield{.value=0,.terminal=true});}
    let usize value=joins::finish(p,ref join,at)?;return .ok(Yield{.value=value,.terminal=false});
}
// Both control forms share one exact-type/shape destination. This is source
// scratch only; ordinary CFG/owner admission remains authoritative.
fn Result<bool,errors::Error> value_join(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    ref mut joins::Join join,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    var usize fuel=metadata_budget::unlimited();
    return value_join_metered(source,s,p,table,signatures,join,depth,result_type,structure,loop_state,0,ref mut fuel);
}
fn Result<bool,errors::Error> value_join_metered(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    ref mut joins::Join join,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    if(word_is(source,s,b"switch")){return switch_join(source,s,p,table,signatures,join,depth,result_type,structure,loop_state,deadline,fuel);}
    return if_join(source,s,p,table,signatures,join,depth,result_type,structure,loop_state,deadline,fuel);
}
fn Result<bool,errors::Error> if_join(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    ref mut joins::Join join,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let usize at=s.begin;
    if(depth>30 || structure>30){return .err(errors::make(4,at));}
    if(result_type==0){return .err(errors::make(3,at));}
    let usize keyword=lexer::word_with_budget(source,s,b"if",deadline,fuel)?;let usize open=lexer::punctuation_with_budget(source,s,40,deadline,fuel)?;
    let usize condition=raw_expression(source,s,p,table,signatures,1,depth+1,2,result_type,structure+1,loop_state,deadline,fuel)?;
    if(p.types[condition]!=2){return .err(errors::make(3,at));}
    let usize close=lexer::punctuation_with_budget(source,s,41,deadline,fuel)?;let usize branch=ir::raw(p,20,0,condition,0,at)?;
    var locals::Table names=locals::snapshot(table);
    let bool positive=conditional_arm(source,s,p,ref mut names,signatures,join,depth+2,result_type,structure+2,loop_state,deadline,fuel)?;
    var usize skip=256;
    if(!positive){skip=ir::raw(p,19,0,0,0,at)?;}
    let usize otherwise=lexer::word_with_budget(source,s,b"else",deadline,fuel)?;
    let usize target=p.count;let usize patched=ir::patch(p,branch,target,at)?;
    names=locals::snapshot(table);
    let bool negative=if(word_is(source,s,b"if")){
        if_join(source,s,p,ref names,signatures,join,depth+1,result_type,structure+1,loop_state,deadline,fuel)?
    }else{conditional_arm(source,s,p,ref mut names,signatures,join,depth+2,result_type,structure+2,loop_state,deadline,fuel)?};
    if(skip!=256){let usize join=p.count;let usize patched=ir::patch(p,skip,join,at)?;}
    return .ok(positive && negative);
}
// Scope parsing is shared with ordinary value arms. The destination remains
// absent from names until the complete conditional has finished.
fn Result<bool,errors::Error> conditional_arm(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    ref mut joins::Join join,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    if(depth>signatures.semantic_depth || structure>signatures.semantic_depth){return .err(errors::make(4,s.begin));}
    let usize brace=lexer::punctuation_with_budget(source,s,123,deadline,fuel)?;let usize outer=table.count;
    while(true){let bool regular=word_is(source,s,b"_") || arm_syntax::regular_metered(source,s,deadline,fuel)?;
        let bool conditional=word_is(source,s,b"if") && arm_syntax::conditional_value_metered(source,s,deadline,fuel)?;
        let bool structured=s.kind==123 || (word_is(source,s,b"if") && !conditional) || word_is(source,s,b"while") ||
            word_is(source,s,b"for") || word_is(source,s,b"return") || word_is(source,s,b"break") || word_is(source,s,b"continue");
        if(!regular && !structured){break;}
        if(control(source,s,p,table,signatures,result_type,structure,depth,loop_state,deadline,fuel)?){
            let usize close=lexer::punctuation_with_budget(source,s,125,deadline,fuel)?;return .ok(true);}
    }
    let bool terminal=conditional_tail(source,s,p,table,signatures,join,depth,result_type,structure,loop_state,deadline,fuel)?;
    if(!terminal){
        var usize left=table.count;
        while(left>outer){left-=1;discard metadata_budget::visit(fuel,deadline,s.begin)?;
            discard arrays::release_at(table,p,left,s.begin)?;}
    }
    let usize close=lexer::punctuation_with_budget(source,s,125,deadline,fuel)?;return .ok(terminal);
}
fn Result<bool,errors::Error> conditional_tail(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    ref mut joins::Join join,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let usize at=s.begin;let arm_syntax::Conditional atom=arm_syntax::conditional_atom_metered(source,s,deadline,fuel)?;
    if(word_is(source,s,b"ref")){return .err(errors::make(3,at));}
    if(atom.valid && atom.suffix==125){
        if(depth>signatures.semantic_depth || atom.groups>signatures.semantic_depth-depth){return .err(errors::make(4,at));}
        var usize i=0;while(i<atom.groups){let usize next=lexer::next_with_budget(source,s,deadline,fuel)?;i+=1;}
        let bool terminal=value_join_metered(source,s,p,table,signatures,join,depth+atom.groups,result_type,structure,loop_state,deadline,fuel)?;
        let usize close=close_value_groups(source,s,atom.groups,deadline,fuel)?;return .ok(terminal);
    }
    if(join.kind<=1 && join.tag==0 && arm_syntax::constructor_atom_metered(source,s,deadline,fuel)?){
        return constructor_tail(source,s,p,table,signatures,join,depth,result_type,structure,loop_state,deadline,fuel);
    }
    let record_expressions::Plan record=record_expressions::inspect(source,s,p,table,signatures)?;
    if(record.kind!=0 && record.tag==0 && record.suffix==125){
        let usize destination=joins::record_target(join,record.record);
        let record_expressions::Value value=record_value_into(source,s,p,table,signatures,join.mutable,at,depth,result_type,structure,loop_state,destination,deadline,fuel)?;
        let usize accepted=joins::accept_record(p,join,table.function,ref value,at)?;return .ok(false);
    }
    let array_expressions::Plan array=array_expressions::inspect(source,s,p,table,signatures)?;
    if(array.kind!=0 && array.suffix==125){
        let u8 expected=if(join.kind==2){join.tag}else{0};let usize length=if(join.kind==2){join.size}else{0};
        let usize destination=if(join.kind==2 && join.value!=256){join.value-128}else{16};
        let array_expressions::Value value=array_value_into(source,s,p,table,signatures,expected,length,join.mutable,at,depth,result_type,structure,loop_state,destination,deadline,fuel)?;
        let usize accepted=joins::accept_array(p,join,table.function,value.id,value.owned,at)?;return .ok(false);
    }
    let u8 expected=if(join.kind==0 || join.kind==1){join.tag}else{0};
    let usize value=raw_expression(source,s,p,table,signatures,1,depth,expected,result_type,structure,loop_state,deadline,fuel)?;
    let usize accepted=joins::scalar(p,join,value,at)?;return .ok(false);
}
fn Result<bool,errors::Error> constructor_tail(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    ref mut joins::Join join,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let usize at=s.begin;var usize groups=0;
    while(s.kind==40){if(depth>signatures.semantic_depth || groups>=signatures.semantic_depth-depth){return .err(errors::make(4,s.begin));}
        let usize next=lexer::next_with_budget(source,s,deadline,fuel)?;groups+=1;}
    let usize dot=lexer::punctuation_with_budget(source,s,46,deadline,fuel)?;
    let bool option=word_is(source,s,b"some") || word_is(source,s,b"none");
    let bool positive=word_is(source,s,b"some") || word_is(source,s,b"ok");
    if(!option && !word_is(source,s,b"ok") && !word_is(source,s,b"err")){return .err(errors::make(3,at));}
    let usize name=lexer::next_with_budget(source,s,deadline,fuel)?;var usize payload=0;
    if(!option || positive){let usize open=lexer::punctuation_with_budget(source,s,40,deadline,fuel)?;
        payload=raw_expression(source,s,p,table,signatures,1,depth+groups+1,0,result_type,structure,loop_state,deadline,fuel)?;
        let usize close=lexer::punctuation_with_budget(source,s,41,deadline,fuel)?;}
    let usize close=close_value_groups(source,s,groups,deadline,fuel)?;
    if(s.kind!=125){return .err(errors::make(2,s.begin));}
    let usize accepted=joins::constructor(p,join,option,if(positive){1}else{0},payload,at)?;
    return .ok(false);
}
// These owners drain actual child kernels; no child is charged as one body stage.
fn Result<bool,errors::Error> value_control_staged(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,u8 result_type,
    usize structure,usize depth,ref mut loops::State flow,usize deadline,ref mut usize fuel){
    var body_work::State w=body_work::statement(structure);var metadata_budget::State meter=metadata_budget::empty();
    while(!w.done){
        discard metadata_budget::visit(fuel,deadline,s.begin)?;
        let usize allowance=metadata_budget::reset(ref mut meter,s.begin)?;
        let bool done=body_work::advance_limited(source,s,p,names,flow,ref mut w,ref mut meter,signatures.semantic_depth)?;
        if(w.request!=0){let usize completed=complete_body_child_metered(source,s,p,names,signatures,result_type,depth,flow,ref mut w,deadline,fuel)?;}
    }return body_work::prepared(ref w);
}
fn Result<Yield,errors::Error> if_value_staged(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table names,ref functions::Table signatures,
    usize depth,u8 expected,u8 result_type,usize structure,ref mut loops::State flow,ref mut expression_work::Bank bank,bool reuse,usize deadline,ref mut usize fuel){
    let usize at=s.begin;var joins::Join join=joins::empty(expected,false);
    var scratch_vec::Vec<value_work::State> scratch=conditional_scratch(names,depth,structure,result_type,s.begin)?;let ref mut value_work::State w=scratch_vec::at_mut<value_work::State>(ref mut scratch,0);var metadata_budget::State meter=metadata_budget::empty();
    while(!w.done){
        discard metadata_budget::visit(fuel,deadline,s.begin)?;
        let usize allowance=metadata_budget::reset(ref mut meter,s.begin)?;
        let bool done=value_work::advance(source,s,p,signatures,ref mut join,w,ref mut meter)?;
        let u8 request=w.request;let usize child_structure=w.child_structure;let usize child_depth=w.child_depth;var usize value=0;var bool stopped=false;
        if(request==1 || request==4){value=if(reuse){
            expression_in_bank(source,s,p,ref w.names,signatures,1,w.child_depth,w.expected,result_type,w.child_structure,flow,bank,deadline,fuel)?
        }else{expression_metered(source,s,p,ref w.names,signatures,1,w.child_depth,w.expected,result_type,w.child_structure,flow,deadline,fuel)?};}
        else if(request==2){stopped=value_control_staged(source,s,p,ref mut w.names,signatures,result_type,child_structure,child_depth,flow,deadline,fuel)?;}
        else if(request==3){stopped=conditional_tail(source,s,p,ref w.names,signatures,ref mut join,w.child_depth,result_type,w.child_structure,flow,deadline,fuel)?;}
        else if(request==5){w.pattern=patterns::parse_metered(source,s,w.expected,deadline,fuel)?;}
        if(request!=0){let usize resumed=value_work::resume(w,request,value,stopped)?;}
    }
    if(value_work::prepared(w)?){return .ok(Yield{.value=0,.terminal=true});}
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    let usize value=joins::finish(p,ref join,at)?;return .ok(Yield{.value=value,.terminal=false});
}
fn Result<usize,errors::Error> conditional_operand_staged(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize depth,u8 expected,u8 result_type,usize structure,ref mut loops::State loop_state,ref mut expression_work::Bank bank,bool reuse,usize deadline,ref mut usize fuel){
    let usize at=s.begin;var usize groups=0;
    while(s.kind==40){if(depth>signatures.semantic_depth || groups>=signatures.semantic_depth-depth){return .err(errors::make(4,s.begin));}
        discard lexer::next_metered(source,s,deadline,fuel)?;groups+=1;}
    let Yield result=if_value_staged(source,s,p,table,signatures,depth+groups,expected,result_type,structure,loop_state,bank,reuse,deadline,fuel)?;
    if(result.terminal){return .err(errors::make(3,at));}
    var usize left=groups;
    while(left!=0){discard lexer::punctuation_metered(source,s,41,deadline,fuel)?;left-=1;}
    let usize value=result.value;
    if(value<128){return .ok(value);}
    if(value<144){return array_temporary_read(source,s,p,table,signatures,value-128,at,depth+groups,result_type,structure,loop_state);}
    if(value<160){let usize id=value-144;let usize record=p.records.records[id] as usize;
        let record_values::Leaf leaf=record_values::path(source,s,p,record,at,ref signatures.context)?;
        if(leaf.tag==0){return .err(errors::make(3,at));}
        let usize scalar=ir::record_read(p,id,leaf.ordinal,at)?;let usize dropped=ir::record_drop(p,id,at)?;return .ok(scalar);}
    return .err(errors::make(3,at));
}
fn Result<usize,errors::Error> close_value_groups(ref u8[] source,ref mut lexer::State s,
    usize groups,usize deadline,ref mut usize fuel){
    var usize left=groups;
    while(left!=0){discard lexer::punctuation_with_budget(source,s,41,deadline,fuel)?;left-=1;}
    return .ok(groups);
}
fn Result<usize,errors::Error> conditional_operand(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize depth,u8 expected,u8 result_type,usize structure,ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let usize at=s.begin;var usize groups=0;
    while(s.kind==40){if(depth>signatures.semantic_depth || groups>=signatures.semantic_depth-depth){return .err(errors::make(4,s.begin));}
        let usize next=lexer::next_with_budget(source,s,deadline,fuel)?;groups+=1;}
    let Yield result=if_value(source,s,p,table,signatures,depth+groups,expected,result_type,structure,loop_state,deadline,fuel)?;
    if(result.terminal){return .err(errors::make(3,at));}
    let usize close=close_value_groups(source,s,groups,deadline,fuel)?;let usize value=result.value;
    if(value<128){return .ok(value);}
    if(value<144){return array_temporary_read(source,s,p,table,signatures,value-128,at,depth+groups,result_type,structure,loop_state);}
    if(value<160){let usize id=value-144;let usize record=p.records.records[id] as usize;
        let record_values::Leaf leaf=record_values::path(source,s,p,record,at,ref signatures.context)?;
        if(leaf.tag==0){return .err(errors::make(3,at));}
        let usize scalar=ir::record_read(p,id,leaf.ordinal,at)?;let usize dropped=ir::record_drop(p,id,at)?;return .ok(scalar);}
    return .err(errors::make(3,at));
}
fn Result<bool,errors::Error> switch_join(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,ref mut joins::Join join,usize depth,u8 result_type, usize structure, ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let usize at=s.begin;
    if(depth>30 || structure>30) {return .err(errors::make(4,at));}
    // Statement-bearing arms are excluded from the pure for-header subset.
    if(result_type==0) {return .err(errors::make(3,at));}
    let usize keyword=lexer::next_with_budget(source,s,deadline,fuel)?;
    let usize open=lexer::punctuation_with_budget(source,s,40,deadline,fuel)?;
    if(signatures.scalar_host_calls && host_source::qualified(source,s,p,deadline,fuel)?){
        var locals::Table names=locals::snapshot(table);
        return host_switch(source,s,p,ref mut names,signatures,join,true,result_type,structure,depth,loop_state,deadline,fuel);
    }
    let usize subject=raw_expression(source,s,p,table,signatures,1,depth+1,0,result_type,structure+1,loop_state,deadline,fuel)?;
    if(signatures.scalar_host_calls && host_source::is_saved(p,subject)){
        var locals::Table names=locals::snapshot(table);
        let host_source::Branch route=host_source::branch_saved(p,subject,at)?;
        return host_switch_arms(source,s,p,ref mut names,signatures,join,true,result_type,structure,depth,loop_state,ref route,deadline,fuel);
    }
    let u8 tag=p.types[subject];
    if(!types::tagged(tag)) {return .err(errors::make(3,at));}
    let usize close=lexer::punctuation_with_budget(source,s,41,deadline,fuel)?;
    let usize brace=lexer::punctuation_with_budget(source,s,123,deadline,fuel)?;
    var usize[2] skips=[256;2];
    var usize previous=256;
    var u8 first_variant=2;
    var usize arm=0;
    while(arm<2) {
        if(s.kind==125) {return .err(errors::make(3,at));}
        let patterns::Pattern pattern=patterns::parse_metered(source,s,tag,deadline,fuel)?;
        if(arm==1 && pattern.variant==first_variant) {return .err(errors::make(3,at));}
        if(arm==0) {first_variant=pattern.variant;}
        else {
            let usize target=p.count;
            let usize next=ir::patch(p,previous,target,at)?;
        }
        let ir::Case branch=ir::branch_case(p,subject,pattern.variant,at)?;
        var locals::Table names=locals::snapshot(table);
        if(pattern.binding) {
            if(argument_names::local_metered(source,ref names,pattern.begin,pattern.end,deadline,fuel)?!=64) {return .err(errors::make(3,pattern.begin));}
            let usize binding=locals::declare(ref mut names,pattern.begin,pattern.end,branch.payload,false)?;
        }
        let bool terminal=conditional_arm(source,s,p,ref mut names,signatures,join,depth+2,result_type,structure+2,loop_state,deadline,fuel)?;
        if(!terminal){skips[arm]=ir::raw(p,19,0,0,0,at)?;}
        previous=branch.instruction;
        arm+=1;
    }
    let usize end=lexer::punctuation_with_budget(source,s,125,deadline,fuel)?;
    let usize failure=ir::raw(p,25,0,0,0,at)?;
    let usize guarded=ir::patch(p,previous,failure,at)?;
    let usize target=p.count;
    arm=0;
    while(arm<2) {
        if(skips[arm]!=256) {let usize skip=ir::patch(p,skips[arm],target,at)?;}
        arm+=1;
    }
    return .ok(skips[0]==256 && skips[1]==256);
}

// Validate the post clause before the body (body locals are not visible), then
// rewind only its appended IR. Re-emission after the body preserves source order.
// A dead post is still type checked, but consumes no runtime registers or Fuel.
fn Result<usize, errors::Error> checked_post(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, usize expr_depth, usize structure, ref mut loops::State loop_state, usize deadline, ref mut usize fuel) {
    let usize at=s.begin;
    discard metadata_budget::visit(fuel,deadline,at)?;
    if (word_is(source,s,b"let") || word_is(source,s,b"var")) {return .err(errors::make(2,at));}
    let usize code=p.count;
    let usize registers=p.registers;
    let usize constants=p.constant_count;
    let usize calls=p.call_count;
    let usize post=statement(source,s,p,table,signatures,41,0,expr_depth,structure,loop_state,deadline,fuel)?;
    if (p.call_count!=calls || !types::scalar(p.types[table.registers[post]])) {return .err(errors::make(3,at));}
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    discard metadata_budget::charge(fuel,(p.registers-registers)+(p.count-code)*8,at)?;
    var usize r=registers;
    while(r<p.registers) {p.slots[r]=false; p.types[r]=0; r+=1;}
    // Extended instructions carry nonzero range bytes. Clear the discarded
    // region before body emission can reuse it for ordinary scalar operations.
    var usize discarded=code*8;let usize end=p.count*8;
    while(discarded<end){p.code[discarded]=0;discarded+=1;}
    p.count=code; p.registers=registers; p.constant_count=constants;
    return .ok(post);
}

fn Result<bool, errors::Error> block(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state,usize deadline,ref mut usize fuel) {
    if(depth>signatures.semantic_depth){return .err(errors::make(4,s.begin));}
    let usize open=if(signatures.scalar_host_calls){lexer::punctuation_with_budget(source,s,123,deadline,fuel)?}else{lexer::punctuation(source,s,123)?};
    let usize outer = table.count;
    var bool terminal = false;
    while (s.kind != 125) {
        if (s.kind == 0 || terminal) { return .err(errors::make(2, s.begin)); }
        if(signatures.scalar_host_calls){discard metadata_budget::visit(fuel,deadline,s.begin)?;}
        terminal = control(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state,deadline,fuel)?;
    }
    if (!terminal) { let usize dropped = arrays::release_from(table, p, outer, s.begin)?; }
    table.count = outer;
    let usize close=if(signatures.scalar_host_calls){lexer::next_with_budget(source,s,deadline,fuel)?}else{lexer::next(source,s)?};
    return .ok(terminal);
}
// Keep unrelated statement scratch out of recursive dispatcher frames.
fn Result<bool, errors::Error> control(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state,usize deadline,ref mut usize fuel) {
    if(depth>signatures.semantic_depth){return .err(errors::make(4,s.begin));}
    if (word_is(source,s,b"break") || word_is(source,s,b"continue")) {
        return control_transfer(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state);
    }
    if (word_is(source,s,b"switch")) {
        return control_switch(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state,deadline,fuel);
    }
    if (word_is(source,s,b"for")) {
        return control_for(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state,deadline,fuel);
    }
    if (word_is(source,s,b"while")) {
        return control_while(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state,deadline,fuel);
    }
    if (word_is(source, s, b"return")) {
        return control_return(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state,deadline,fuel);
    }
    if (word_is(source, s, b"if")) {
        return control_if(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state,deadline,fuel);
    }
    if (s.kind == 123) { return block(source,s,p,table,signatures,result_type,depth + 1,expr_depth,loop_state,deadline,fuel); }
    let usize regular = statement(source,s,p,table,signatures,59,result_type,expr_depth,depth,loop_state,deadline,fuel)?;
    return .ok(false);
}

fn Result<bool, errors::Error> control_transfer(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state) {
    let usize at = s.begin;
    let bool leave=word_is(source,s,b"break");
    let usize keyword=lexer::next(source,s)?;
    let usize end=lexer::punctuation(source,s,59)?;
    if (loop_state.depth == 0) { return .err(errors::make(2,at)); }
    let usize first=places::leave_loop(table,p,loop_state.bindings[loop_state.depth-1],at)?;
    let usize dropped=arrays::release_from(table,p,first,at)?;
    let usize jump=loops::transfer(loop_state,p,leave,at)?;
    return .ok(true);
}

fn Result<bool, errors::Error> control_switch(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state,usize deadline,ref mut usize fuel) {
    let usize at = s.begin;
    let usize keyword=if(signatures.scalar_host_calls){lexer::next_with_budget(source,s,deadline,fuel)?}else{lexer::next(source,s)?};
    let usize open=if(signatures.scalar_host_calls){lexer::punctuation_with_budget(source,s,40,deadline,fuel)?}else{lexer::punctuation(source,s,40)?};
    if(signatures.scalar_host_calls && host_source::qualified(source,s,p,deadline,fuel)?){
        var joins::Join unused=joins::empty(0,false);
        return host_switch(source,s,p,table,signatures,ref mut unused,false,result_type,depth,expr_depth,loop_state,deadline,fuel);
    }
    let usize subject=if(signatures.scalar_host_calls){raw_expression(source,s,p,table,signatures,1,expr_depth,0,result_type,depth,loop_state,deadline,fuel)?}
        else{expression(source,s,p,table,signatures,1,expr_depth,0,result_type,depth,loop_state)?};
    if(signatures.scalar_host_calls && host_source::is_saved(p,subject)){
        var joins::Join unused=joins::empty(0,false);
        let host_source::Branch route=host_source::branch_saved(p,subject,at)?;
        return host_switch_arms(source,s,p,table,signatures,ref mut unused,false,result_type,depth,expr_depth,loop_state,ref route,deadline,fuel);
    }
    let u8 tag=p.types[subject];
    if(!types::tagged(tag)) {return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,41)?;
    let usize brace=lexer::punctuation(source,s,123)?;
    var usize[2] skips=[256;2];
    var usize previous=256;
    var u8 first_variant=2;
    var bool terminal=true;
    var usize arm=0;
    while(arm<2) {
        if(s.kind==125) {return .err(errors::make(3,at));}
        let patterns::Pattern pattern=patterns::parse(source,s,tag)?;
        if(arm==1 && pattern.variant==first_variant) {return .err(errors::make(3,at));}
        if(arm==0) {first_variant=pattern.variant;}
        else {
            let usize next=p.count;
            let usize patched=ir::patch(p,previous,next,at)?;
        }
        let ir::Case branch=ir::branch_case(p,subject,pattern.variant,at)?;
        let usize outer=table.count;
        if(pattern.binding) {
            if(locals::find(source,table,pattern.begin,pattern.end)!=64) {return .err(errors::make(3,pattern.begin));}
            let usize binding=locals::declare(table,pattern.begin,pattern.end,branch.payload,false)?;
        }
        let bool stopped=block(source,s,p,table,signatures,result_type,depth+2,expr_depth,loop_state,deadline,fuel)?;
        table.count=outer;
        terminal=terminal && stopped;
        if(!stopped) {skips[arm]=ir::raw(p,19,0,0,0,at)?;}
        previous=branch.instruction;
        arm+=1;
    }
    let usize end=lexer::punctuation(source,s,125)?;
    let usize failure=p.count;
    let usize trap=ir::raw(p,25,0,0,0,at)?;
    let usize patched=ir::patch(p,previous,failure,at)?;
    let usize target=p.count;
    arm=0;
    while(arm<2) {
        if(skips[arm]!=256) {let usize skip=ir::patch(p,skips[arm],target,at)?;}
        arm+=1;
    }
    return .ok(terminal);
}

// A direct host switch has two independently defined payload registers.
// The regular arm lowerers own lexical scopes and join/exit handling.
fn Result<bool,errors::Error> host_switch(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref mut locals::Table table,ref functions::Table signatures,ref mut joins::Join join,bool value_mode,
    u8 result_type,usize structure,usize depth,ref mut loops::State flow,usize deadline,ref mut usize fuel){
    let usize at=s.begin;
    if(depth>30 || structure>30){return .err(errors::make(4,at));}
    let host_source::Invocation call=host_invocation(source,s,p,table,signatures,depth+1,result_type,structure+1,flow,deadline,fuel)?;
    let host_source::Branch route=host_source::branch(p,ref call)?;
    return host_switch_arms(source,s,p,table,signatures,join,value_mode,result_type,structure,depth,flow,ref route,deadline,fuel);
}

fn Result<bool,errors::Error> host_switch_arms(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref mut locals::Table table,ref functions::Table signatures,ref mut joins::Join join,bool value_mode,
    u8 result_type,usize structure,usize depth,ref mut loops::State flow,ref host_source::Branch route,usize deadline,ref mut usize fuel){
    let usize at=s.begin;
    if(depth>30 || structure>30){return .err(errors::make(4,at));}
    let usize close=lexer::punctuation_with_budget(source,s,41,deadline,fuel)?;
    let usize brace=lexer::punctuation_with_budget(source,s,123,deadline,fuel)?;
    let usize outer=table.count;
    let patterns::Pattern first=patterns::parse_result_metered(source,s,deadline,fuel)?;
    let bool first_stops=host_switch_arm(source,s,p,table,signatures,join,value_mode,result_type,structure,depth,flow,ref first,route,deadline,fuel)?;
    table.count=outer;
    let usize skip=if(first_stops){256}else{ir::raw(p,19,0,0,0,at)?};
    let patterns::Pattern second=patterns::parse_result_metered(source,s,deadline,fuel)?;
    if(second.variant==first.variant){return .err(errors::make(3,second.begin));}
    let bool second_stops=host_switch_arm(source,s,p,table,signatures,join,value_mode,result_type,structure,depth,flow,ref second,route,deadline,fuel)?;
    table.count=outer;
    let usize end=lexer::punctuation_with_budget(source,s,125,deadline,fuel)?;
    if(!first_stops){let usize target=p.count;let usize patched=ir::patch(p,skip,target,at)?;}
    return .ok(first_stops && second_stops);
}

fn Result<bool,errors::Error> host_switch_arm(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref mut locals::Table table,ref functions::Table signatures,ref mut joins::Join join,bool value_mode,
    u8 result_type,usize structure,usize depth,ref mut loops::State flow,ref patterns::Pattern pattern,ref host_source::Branch route,usize deadline,ref mut usize fuel){
    discard metadata_budget::visit(fuel,deadline,s.begin)?;
    let usize payload=host_source::enter_arm(p,route,pattern.variant,pattern.binding,s.begin)?;
    if(pattern.binding){
        let usize existing=argument_names::local_metered(source,table,pattern.begin,pattern.end,deadline,fuel)?;
        if(existing!=64){return .err(errors::make(3,pattern.begin));}
        let usize binding=locals::declare(table,pattern.begin,pattern.end,payload,false)?;
    }
    if(value_mode){return conditional_arm(source,s,p,table,signatures,join,depth+2,result_type,structure+2,flow,deadline,fuel);}
    return block(source,s,p,table,signatures,result_type,structure+2,depth,flow,deadline,fuel);
}

fn Result<bool, errors::Error> control_for(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state,usize deadline,ref mut usize fuel) {
    let usize at = s.begin;
    let usize outer=table.count;
    let usize keyword=lexer::next(source,s)?;
    let usize open=lexer::punctuation(source,s,40)?;
    let usize calls=p.call_count;
    var usize header_fuel=metadata_budget::unlimited();
    if (s.kind==59) {let usize empty=lexer::next(source,s)?;}
    else {
        let usize init=statement(source,s,p,table,signatures,59,0,expr_depth,depth,loop_state,0,ref mut header_fuel)?;
        if (!types::scalar(p.types[table.registers[init]])) {return .err(errors::make(3,at));}
    }
    let usize head=p.count;
    let usize condition=if (s.kind==59) {ir::boolean(p,true,at)?}
        else {expression(source,s,p,table,signatures,1,expr_depth,2,0,depth,loop_state)?};
    if (p.types[condition]!=2 || p.call_count!=calls) {return .err(errors::make(3,at));}
    let usize separator=lexer::punctuation(source,s,59)?;
    let usize exit=ir::raw(p,20,0,condition,0,at)?;
    let bool has_post=s.kind!=41;
    let usize post_start=s.begin;
    if (has_post) {let usize validated=checked_post(source,s,p,table,signatures,expr_depth,depth,loop_state,0,ref mut header_fuel)?;}
    else {let usize empty=lexer::next(source,s)?;}
    let usize level=loops::enter(loop_state,head,true,at)?;
    loop_state.bindings[level]=places::scope(table);
    let bool stopped=block(source,s,p,table,signatures,result_type,depth+1,expr_depth,loop_state,deadline,fuel)?;
    let usize post_target=p.count;
    let usize continues=loops::resolve(loop_state,p,false,post_target,at)?;
    if (!stopped || continues!=0) {
        if (has_post) {
            var lexer::State post=source_context::state(source,ref signatures.context,post_start)?;
            let usize first=lexer::next(source,ref mut post)?;
            let usize emitted=statement(source,ref mut post,p,table,signatures,41,0,expr_depth,depth,loop_state,0,ref mut header_fuel)?;
        }
        let usize back=ir::raw(p,22,0,head,0,at)?;
    }
    let usize target=p.count;
    let usize branch=ir::patch(p,exit,target,at)?;
    let usize breaks=loops::resolve(loop_state,p,true,target,at)?;
    loop_state.depth-=1; table.count=outer;
    return .ok(false);
}

fn Result<bool, errors::Error> control_while(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state,usize deadline,ref mut usize fuel) {
    let usize at = s.begin;
    let usize keyword=lexer::next(source,s)?;
    let usize open=lexer::punctuation(source,s,40)?;
    let usize head=p.count;
    let usize level=loops::enter(loop_state,head,false,at)?;
    loop_state.bindings[level]=places::scope(table);
    let usize condition=expression(source,s,p,table,signatures,1,expr_depth,2,result_type,depth,loop_state)?;
    if (p.types[condition]!=2) {return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,41)?;
    let usize exit=ir::raw(p,20,0,condition,0,at)?;
    let bool stopped=block(source,s,p,table,signatures,result_type,depth+1,expr_depth,loop_state,deadline,fuel)?;
    if (!stopped) {let usize back=ir::raw(p,22,0,head,0,at)?;}
    let usize target=p.count;
    let usize branch=ir::patch(p,exit,target,at)?;
    let usize breaks=loops::resolve(loop_state,p,true,target,at)?;
    loop_state.depth-=1;
    return .ok(false);
}

// Analysis uses a length observation, never an escaping runtime ticket. Ordinary
// expressions cannot consume borrowed CALL results as their scalar proxies.
fn Result<return_ranges::Bounds,errors::Error> slice_bounds(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize parent,usize at,usize structure,usize depth,u8 result_type,ref mut loops::State loop_state){
    let usize open=lexer::punctuation(source,s,91)?;
    let usize lo=if(s.kind==46){ir::integer(p,0,12,at)?}
        else{expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)?};
    if(p.types[lo]!=12){return .err(errors::make(3,at));}
    let usize first=lexer::punctuation(source,s,46)?;let usize second=lexer::punctuation(source,s,46)?;
    let usize hi=if(s.kind==93){ir::slice_length(p,parent,at)?}
        else{expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)?};
    if(p.types[hi]!=12){return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,93)?;
    return .ok(return_ranges::Bounds{.lo=lo,.hi=hi});
}
fn Result<usize,errors::Error> slice_range(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize parent,usize at,usize structure,usize depth,u8 result_type,ref mut loops::State loop_state){
    let return_ranges::Bounds bounds=slice_bounds(source,s,p,table,signatures,parent,at,structure,depth,result_type,loop_state)?;
    return return_ranges::acquire(p,parent,table.function,bounds.lo,bounds.hi,at);
}
// A returned CALL is already live while its endpoints evaluate. Keep its hidden
// ancestors in a separate post-CALL snapshot, never on every scalar parse frame.
fn Result<bool,errors::Error> slice_return_projection(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize result,usize at,usize structure,usize depth,ref mut loops::State loop_state){
    var locals::Table names=locals::snapshot(table);
    let usize retained=result_calls::publish(p,ref mut names,result,at)?;
    let usize captured=locals::declare(ref mut names,at,at,result,ir::exclusive(p,result-160))?;
    let return_ranges::Bounds bounds=slice_bounds(source,s,p,ref names,signatures,result-160,at,structure,depth,12,loop_state)?;
    let usize end=lexer::punctuation(source,s,59)?;
    let usize child=return_ranges::acquire(p,result-160,names.function,bounds.lo,bounds.hi,at)?;
    let usize value=ir::slice_length(p,child,at)?;
    let usize closed=return_ranges::release(p,child,result-160,at)?;
    let usize dropped=arrays::release_visible(ref names,p,at)?;
    let usize returned=ir::emit(p,8,value,0,at)?;return .ok(true);
}
fn Result<bool,errors::Error> slice_origin_return(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize at,usize depth,usize expr_depth,ref mut loops::State loop_state){
    let u8 encoded=signatures.return_slice_elements[table.function];
    var usize value=128;var usize child=16;var usize parent=16;
    if(word_is(source,s,b"ref")){
        let usize reference=lexer::next(source,s)?;
        if((encoded & 128)!=0){let usize access=lexer::word(source,s,b"mut")?;}
        if(s.kind!=2){return .err(errors::make(3,s.begin));}
        let usize index=locals::find(source,table,s.begin,s.end);
        if(!slices::binding(table,index)){return .err(errors::make(3,s.begin));}
        let usize site=table.registers[index]-160;
        if(ir::borrow_element(p,site)!=(encoded & 127) || ir::exclusive(p,site)!=((encoded & 128)!=0)){
            return .err(errors::make(3,s.begin));
        }
        let usize name=lexer::next(source,s)?;
        if(s.kind==91){
            parent=site;child=slice_range(source,s,p,table,signatures,site,at,depth,expr_depth,12,loop_state)?;
            value=ir::slice_length(p,child,at)?;
        }else{value=ir::slice_length(p,site,at)?;}
    }else{
        if((s.kind!=2 && s.kind!=5) || locals::find(source,table,s.begin,s.end)!=64){return .err(errors::make(3,s.begin));}
        let usize target=functions::find(source,signatures,s.begin,s.end);
        if(target>=signatures.count || signatures.return_slice_elements[target]!=encoded){return .err(errors::make(3,s.begin));}
        let usize name=lexer::next(source,s)?;
        if(return_ranges::follows(source,s)?){
            let usize result=call_value(source,s,p,table,signatures,target,176,at,expr_depth,12,depth,loop_state)?;
            return slice_return_projection(source,s,p,table,signatures,result,at,depth,expr_depth,loop_state);
        }
        value=call_value(source,s,p,table,signatures,target,16,at,expr_depth,12,depth,loop_state)?;
    }
    let usize end=lexer::punctuation(source,s,59)?;
    if(child!=16){let usize ended=return_ranges::release(p,child,parent,at)?;}
    let usize dropped=arrays::release_visible(table,p,at)?;
    let usize returned=ir::emit(p,8,value,0,at)?;
    return .ok(true);
}
// RETURN carries exactly one live byte view; all other lexical resources close
// before native handoff. Input/image origins are independently proved at retain.
fn Result<bool,errors::Error> reference_return(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize at,usize structure,usize depth,ref mut loops::State loop_state){
    let static_source::View value=static_view(source,s,p,table,signatures,depth,12,structure,loop_state)?;
    if(value.kind!=1){return .err(errors::make(3,at));}
    let usize end=lexer::punctuation(source,s,59)?;
    let usize ended=places::release(table,p,0,at)?;var usize i=table.count;
    while(i>0){i-=1;if(table.registers[i]!=192+value.site){let usize closed=arrays::release_at(table,p,i,at)?;}}
    let usize returned=ir::raw(p,79,0,value.site,0,at)?;return .ok(true);
}
fn Result<bool, errors::Error> control_return(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state,usize deadline,ref mut usize fuel){
    let usize at = s.begin;
    let usize keyword = lexer::next(source, s)?;
    if(signatures.return_types[table.function]==13){
        if(s.kind!=59){return .err(errors::make(3,s.begin));}
        let usize end=lexer::next(source,s)?;let usize dropped=arrays::release_visible(table,p,at)?;
        let usize returned=ir::raw(p,82,0,0,0,at)?;return .ok(true);
    }
    if(reference_calls::result(signatures,table.function)){
        return reference_return(source,s,p,table,signatures,at,depth,expr_depth,loop_state);
    }
    if(signatures.return_slice_elements[table.function]!=0){
        return slice_origin_return(source,s,p,table,signatures,at,depth,expr_depth,loop_state);
    }
    if(p.record_results[table.function]!=0){
        let usize expected=p.records.records[p.record_results[table.function] as usize-1] as usize;
        let record_expressions::Value value=record_value(source,s,p,table,signatures,false,at,expr_depth,result_type,depth,loop_state)?;
        if(value.tag!=0 || value.record!=expected){return .err(errors::make(3,at));}
        let usize end=lexer::punctuation(source,s,59)?;
        let usize id=if(record_expressions::whole(p,ref value)){value.id}else{record_expressions::materialize(p,table.function,ref value,false,at)?};
        let usize returned=record_results::finish(p,table,id,at)?;return .ok(true);
    }
    if(p.array_results[table.function]!=0) {
        if(s.kind==40 || arm_syntax::operand_kind(source,s)!=0){
            let usize shape=(p.array_results[table.function] as usize)-1;
            let u8 element=p.arrays.elements[shape];let usize length=p.arrays.lengths[shape];
            let array_expressions::Value value=array_grouped_value(source,s,p,table,signatures,element,length,false,at,expr_depth,result_type,depth,loop_state)?;
            let usize end=lexer::punctuation(source,s,59)?;
            let usize returned=array_results::finish(p,table,value.id,at)?;return .ok(true);
        }
        if(s.kind==91) {
            let usize shape=(p.array_results[table.function] as usize)-1;
            let u8 element=p.arrays.elements[shape];
            if(!array_locals::is_repeated(source,s)?){
                let usize length=p.arrays.lengths[shape];
                let usize id=array_list_value(source,s,p,table,signatures,element,length,false,at,expr_depth,result_type,depth,loop_state)?;
                let usize end=lexer::punctuation(source,s,59)?;
                let usize returned=array_results::finish(p,table,id,at)?;
                return .ok(true);
            }
            let usize open=lexer::next(source,s)?;
            let usize value=expression(source,s,p,table,signatures,1,expr_depth,element,result_type,depth,loop_state)?;
            let usize returned=array_results::repeated(source,s,p,table,value,at)?;
            return .ok(true);
        }
        var lexer::State look=lexer::snapshot(s);
        let usize next=lexer::next(source,ref mut look)?;
        if((s.kind==2 || s.kind==5) && look.kind==40) {
            if(locals::find(source,table,s.begin,s.end)!=64) {return .err(errors::make(3,s.begin));}
            let usize target=functions::find(source,signatures,s.begin,s.end);
            let usize shape=(p.array_results[table.function] as usize)-1;
            let usize id=array_results::destination(signatures,target,p.arrays.elements[shape],p.arrays.lengths[shape],false,p,table.function,s.begin)?;
            let usize name=lexer::next(source,s)?;
            let usize called=call_value(source,s,p,table,signatures,target,id,at,expr_depth,result_type,depth,loop_state)?;
            if(s.kind!=59) {return .err(errors::make(3,s.begin));}
            let usize end=lexer::next(source,s)?;
            let usize returned=array_results::finish(p,table,id,at)?;
            return .ok(true);
        }
        let usize returned=array_results::returned(source,s,p,table,at)?;
        return .ok(true);
    }
    let usize value = if(signatures.scalar_host_calls){raw_expression(source,s,p,table,signatures,1,expr_depth,result_type,result_type,depth,loop_state,deadline,fuel)?}
        else{expression(source,s,p,table,signatures,1,expr_depth,result_type,result_type,depth,loop_state)?};
    let bool matches=if(types::host_result_type(result_type)){
        host_source::is_saved(p,value) && p.types[value+1]==result_type
    }else{p.types[value]==result_type};
    if(!matches){return .err(errors::make(3,at));}
    let usize end = lexer::punctuation(source, s, 59)?;
    let usize dropped = arrays::release_visible(table, p, at)?;
    let usize returned = ir::emit(p, 8, value, 0, at)?;
    return .ok(true);
}

fn Result<bool, errors::Error> control_if(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state,usize deadline,ref mut usize fuel) {
    let usize at = s.begin;
    let usize keyword = lexer::next(source, s)?;
    let usize open = lexer::punctuation(source, s, 40)?;
    let usize condition = expression(source,s,p,table,signatures,1,expr_depth,2,result_type,depth,loop_state)?;
    if (p.types[condition] != 2) { return .err(errors::make(3, at)); }
    let usize close = lexer::punctuation(source, s, 41)?;
    let usize branch = ir::raw(p, 20, 0, condition, 0, at)?;
    let bool then_returns = block(source,s,p,table,signatures,result_type,depth + 1,expr_depth,loop_state,deadline,fuel)?;
    if (word_is(source, s, b"else")) {
        var usize skip = 256;
        if (!then_returns) { skip = ir::raw(p, 19, 0, 0, 0, at)?; }
        let usize else_start = p.count;
        let usize patched = ir::patch(p, branch, else_start, at)?;
        let usize else_word = lexer::next(source, s)?;
        let bool else_returns = if (word_is(source, s, b"if")) {
            control(source,s,p,table,signatures,result_type,depth + 1,expr_depth,loop_state,deadline,fuel)?
        } else { block(source,s,p,table,signatures,result_type,depth + 1,expr_depth,loop_state,deadline,fuel)? };
        if (skip != 256) {
            let usize continuation = p.count;
            let usize skipped = ir::patch(p, skip, continuation, at)?;
        }
        return .ok(then_returns && else_returns);
    }
    let usize continuation = p.count;
    let usize patched = ir::patch(p, branch, continuation, at)?;
    return .ok(false);
}

// Drain annotated declaration stages. Converted operands and unsupported
// statements remain explicit legacy children outside the stage allowance.
fn Result<usize,errors::Error> statement_staged(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 terminator,u8 result_type,usize expr_depth,usize structure,ref mut loops::State flow,usize deadline,ref mut usize fuel){
    var scratch_vec::Vec<expression_work::Bank> scratch=expression_scratch(s.begin)?;let ref mut expression_work::Bank bank=scratch_vec::at_mut<expression_work::Bank>(ref mut scratch,0);
    return statement_in_bank(source,s,p,names,signatures,terminator,result_type,expr_depth,structure,flow,bank,deadline,fuel);
}
fn Result<usize,errors::Error> statement_in_bank(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 terminator,u8 result_type,usize expr_depth,usize structure,ref mut loops::State flow,ref mut expression_work::Bank bank,usize deadline,ref mut usize fuel){
    var semantic_work::State w=semantic_work::begin(*s,1,0,terminator,expr_depth);
    var metadata_budget::State meter=metadata_budget::empty();
    while(!w.done){
        discard metadata_budget::visit(fuel,deadline,0)?;
        let usize allowance=metadata_budget::reset(ref mut meter,s.begin)?;
        let bool done=semantic_work::advance(source,s,p,names,signatures,bank,ref mut w,ref mut meter)?;
        if(w.request==1){let usize completed=complete_expression_operand(source,s,p,names,signatures,result_type,structure,flow,bank,ref mut w.expression,deadline,fuel)?;
            let usize continued=semantic_work::continue_operand(ref mut w)?;
        }else if(w.request==2){let usize value=statement(source,s,p,names,signatures,terminator,result_type,expr_depth,structure,flow,deadline,fuel)?;
            let usize completed=semantic_work::resume(ref mut w,2,value,false)?;}
        else if(w.request==3){let usize end=s.end;let inference::Header header=inference::header(source,s,names)?;let usize begin=header.begin;
            let usize completed=semantic_work::resume_header(ref mut w,begin,end)?;}
    }return semantic_work::prepared(ref w);
}

// Scalar/void returns resume expression, terminator, reverse cleanup and RETURN
// separately. Special result protocols keep their original explicit child.
fn Result<bool,errors::Error> return_staged(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 result_type,usize depth,usize expr_depth,ref mut loops::State flow,usize deadline,ref mut usize fuel){
    let usize function=names.function;
    let u8 kind=if(signatures.return_types[function]==13){3}
        else if(reference_calls::result(signatures,function) || signatures.return_slice_elements[function]!=0 ||
            p.record_results[function]!=0 || p.array_results[function]!=0 || !types::scalar(result_type)){0}else{2};
    var scratch_vec::Vec<expression_work::Bank> scratch=expression_scratch(s.begin)?;let ref mut expression_work::Bank bank=scratch_vec::at_mut<expression_work::Bank>(ref mut scratch,0);
    return return_in_bank(source,s,p,names,signatures,result_type,depth,expr_depth,flow,kind,bank,deadline,fuel);
}
// Semantic state is needed after Bank initialization, not while Vec::push is
// constructing its large success/error payloads.
fn Result<bool,errors::Error> return_in_bank(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 result_type,usize depth,usize expr_depth,ref mut loops::State flow,u8 kind,ref mut expression_work::Bank bank,usize deadline,ref mut usize fuel){
    var semantic_work::State w=semantic_work::begin(*s,kind,result_type,59,expr_depth);
    var metadata_budget::State meter=metadata_budget::empty();
    while(!w.done){
        discard metadata_budget::visit(fuel,deadline,0)?;
        let usize allowance=metadata_budget::reset(ref mut meter,s.begin)?;
        let bool done=semantic_work::advance(source,s,p,names,signatures,bank,ref mut w,ref mut meter)?;
        if(w.request==1){let usize completed=complete_expression_operand(source,s,p,names,signatures,result_type,depth,flow,bank,ref mut w.expression,deadline,fuel)?;
            let usize continued=semantic_work::continue_operand(ref mut w)?;
        }else if(w.request==2){let bool stopped=control_return(source,s,p,names,signatures,result_type,depth,expr_depth,flow,deadline,fuel)?;
            let usize completed=semantic_work::resume(ref mut w,2,0,stopped)?;}
    }let usize value=semantic_work::prepared(ref w)?;return .ok(w.stopped);
}

// Complete one explicit semantic child outside the control-stage allowance.
// Common Pratt/declaration/scalar-return adapters drain their own kernels.
// Remaining semantic children stay explicit and outside the stage allowance.
// All candidates still need independent admission.
pub fn Result<usize,errors::Error> complete_body_child(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 result_type,usize expr_depth,ref mut loops::State flow,ref mut body_work::State w){
    var usize fuel=metadata_budget::unlimited();
    return complete_body_child_metered(source,s,p,names,signatures,result_type,expr_depth,flow,w,0,ref mut fuel);
}
fn Result<usize,errors::Error> complete_body_child_metered(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,u8 result_type,usize expr_depth,
    ref mut loops::State flow,ref mut body_work::State w,usize deadline,ref mut usize fuel){
    let u8 request=w.request;
    if(w.done || w.lexing || request==0){return .err(errors::make(5,s.begin));}
    let body_work::Frame f=body_work::current(w);var usize value=0;var bool stopped=false;
    if(request==1){value=statement_staged(source,s,p,names,signatures,59,result_type,expr_depth,f.depth,flow,deadline,fuel)?;}
    else if(request==2){stopped=return_staged(source,s,p,names,signatures,result_type,f.depth,expr_depth,flow,deadline,fuel)?;}
    else if(request==4 || request==5 || request==7 || request==10){
        value=expression_metered(source,s,p,names,signatures,1,expr_depth,if(request==10){0}else{2},
            if(request==7){0}else{result_type},f.depth,flow,deadline,fuel)?;
    }else if(request==6){value=statement_staged(source,s,p,names,signatures,59,0,expr_depth,f.depth,flow,deadline,fuel)?;}
    else if(request==8){value=checked_post(source,s,p,names,signatures,expr_depth,f.depth,flow,deadline,fuel)?;}
    else if(request==9){
        discard metadata_budget::visit(fuel,deadline,f.c)?;
        var lexer::State post=source_context::state(source,ref signatures.context,f.c)?;
        let usize first=lexer::next(source,ref mut post)?;
        value=statement(source,ref mut post,p,names,signatures,41,0,expr_depth,f.depth,flow,deadline,fuel)?;
    }else{return .err(errors::make(5,s.begin));}
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    return body_work::resume(w,request,value,stopped);
}
fn Result<bool,errors::Error> walk_body(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 result_type,ref mut loops::State flow){
    var body_work::State w=body_work::begin(0,false);var metadata_budget::State meter=metadata_budget::empty();
    while(!w.done){let usize allowance=metadata_budget::reset(ref mut meter,s.begin)?;
        let bool done=body_work::advance_limited(source,s,p,names,flow,ref mut w,ref mut meter,signatures.semantic_depth)?;
        if(w.request!=0){let usize completed=complete_body_child(source,s,p,names,signatures,result_type,0,flow,ref mut w)?;}
    }return body_work::prepared(ref w);
}
fn Result<bool,errors::Error> walk_body_until(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 result_type,ref mut loops::State flow,usize deadline){
    var body_work::State w=body_work::begin(0,false);var metadata_budget::State meter=metadata_budget::empty();
    var usize fuel=metadata_budget::unlimited();
    while(true){
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        if(w.done){return body_work::prepared(ref w);}
        if(w.request==0){
            let usize allowance=metadata_budget::reset(ref mut meter,s.begin)?;
            let bool advanced=body_work::advance_limited(source,s,p,names,flow,ref mut w,ref mut meter,signatures.semantic_depth)?;
        }else{
            let usize completed=complete_body_child_metered(source,s,p,names,signatures,result_type,0,flow,ref mut w,deadline,ref mut fuel)?;
        }
    }
    return .err(errors::make(5,0));
}
// Private raw body oracle for exact IR/error comparisons, with caller-prepared
// signatures/catalogs. Both routes produce candidates, never executable authority.
pub fn Result<usize, errors::Error> lower_body(ref u8[] source, ref functions::Table signatures, usize f, ref mut ir::Program p,bool staged) {
    var usize fuel=metadata_budget::unlimited();
    return lower_body_metered(source,signatures,f,p,staged,0,ref mut fuel);
}
fn Result<usize,errors::Error> lower_body_metered(ref u8[] source,ref functions::Table signatures,
    usize f,ref mut ir::Program p,bool staged,usize deadline,ref mut usize fuel){
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    discard metadata_budget::prepay(fuel,signatures.bodies[f])?;
    var locals::Table table = locals::empty();
    let usize bound=bind_body(signatures,f,p,ref mut table)?;
    var lexer::State s=source_context::state(source,ref signatures.context,signatures.bodies[f])?;
    let usize first = lexer::next(source, ref mut s)?;
    var loops::State loop_state=loops::empty();
    let u8 result_context=if(reference_calls::result(signatures,f)){12}else{record_results::context(p,f)};
    var bool terminal = false;
    if(staged && source.len<=4096){terminal=walk_body(source,ref mut s,p,ref mut table,signatures,result_context,ref mut loop_state)?;}
    else{while (s.kind != 125) {
        if (terminal || s.kind == 0) { return .err(errors::make(2, s.begin)); }
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        discard metadata_budget::prepay(fuel,s.begin)?;
        terminal = control(source,ref mut s,p,ref mut table,signatures,result_context,0,0,ref mut loop_state,deadline,fuel)?;
    }
    }
    return finish_body(signatures,f,p,ref table,ref s,terminal);
}

fn Result<usize,errors::Error> lower_body_until(ref u8[] source, ref functions::Table signatures, usize f, ref mut ir::Program p,usize deadline) {
    var locals::Table table = locals::empty();
    let usize bound=bind_body(signatures,f,p,ref mut table)?;
    var lexer::State s=source_context::state(source,ref signatures.context,signatures.bodies[f])?;
    let usize first = lexer::next(source, ref mut s)?;
    var loops::State loop_state=loops::empty();
    let u8 result_context=if(reference_calls::result(signatures,f)){12}else{record_results::context(p,f)};
    let bool terminal=walk_body_until(source,ref mut s,p,ref mut table,signatures,result_context,ref mut loop_state,deadline)?;
    return finish_body(signatures,f,p,ref table,ref s,terminal);
}

fn Result<usize,errors::Error> bind_body(ref functions::Table signatures,usize f,ref mut ir::Program p,ref mut locals::Table table){
    table.function = f;
    let usize arity = signatures.arities[f];
    if (p.registers + arity > 128) { return .err(errors::make(4, signatures.begins[f])); }
    let usize start = p.count;
    let usize registers_start = p.registers;
    p.starts[f] = start;
    p.register_starts[f] = registers_start;
    p.arities[f] = arity;
    var usize i = 0;
    while (i < arity) {
        let usize at = f * 8 + i;
        let usize parameter = if(reference_calls::parameter(signatures,at)){reference_calls::bind(signatures,at,p,table)?}
            else if(signatures.param_slices[at]){slice_calls::bind(signatures,at,p,table)?}
            else if(signatures.param_records[at]!=0){record_calls::bind(signatures,at,p,table)?}
            else{array_calls::bind(signatures,at,p,table)?};
        i += 1;
    }
    return .ok(f);
}
fn Result<usize,errors::Error> finish_body(ref functions::Table signatures,usize f,ref mut ir::Program p,
    ref locals::Table table,ref lexer::State s,bool stopped){
    var bool terminal=stopped;
    if(!terminal && signatures.return_types[f]==13){
        let usize dropped=arrays::release_visible(table,p,s.begin)?;
        let usize returned=ir::raw(p,82,0,0,0,s.begin)?;terminal=true;
    }
    if (!terminal) { return .err(errors::make(2, s.begin)); }
    if (s.kind != 125 || s.begin != signatures.body_ends[f]) { return .err(errors::make(2, s.begin)); }
    let usize end = p.count;
    let usize registers_end = p.registers;
    p.ends[f] = end;
    p.register_ends[f] = registers_end;
    return .ok(f);
}

fn Result<usize,errors::Error> body(ref u8[] source,ref functions::Table signatures,usize f,ref mut ir::Program p){
    return lower_body(source,signatures,f,p,!signatures.scalar_host_calls);
}

// Release source-name/catalog scratch before recursive expression lowering.
pub fn Result<usize, errors::Error> prepare_aggregates(ref u8[] source, ref mut functions::Table signatures, ref mut ir::Program p) {
    return prepare_aggregates_from(source,signatures,p,0,0);
}
fn Result<usize,errors::Error> prepare_aggregates_from(ref u8[] source,ref mut functions::Table signatures,
    ref mut ir::Program p,usize start,usize deadline){
    let usize parameters = array_calls::prepare(signatures, p)?;
    let usize results = array_results::prepare(signatures, p)?;
    let structs::Table records = if(start!=0){struct_scan::scan_single_from(source,start)?}
        else if(signatures.context.modules==0){structs::scan(source)?}
        else{struct_scan::scan_scoped_until(source,ref signatures.context,deadline,signatures.semantic_depth)?};
    var usize f = 0;
    while (f < signatures.count) {
        if (structs::find(source, ref records, signatures.begins[f], signatures.ends[f]) != 32) {
            return .err(errors::make(3, signatures.begins[f]));
        }
        f += 1;
    }
    p.records.layouts = records.layouts;
    let usize record_parameters = record_calls::prepare(signatures,p)?;
    let usize record_returns = record_results::prepare(signatures,p)?;
    return .ok(records.layouts.count);
}

// Signature selection temporaries are gone before recursive body lowering.
fn Result<functions::Table,errors::Error> lowering_signatures(ref u8[] source,bool returns){
    if(returns){return functions::scan_reference_returns(source);}
    return functions::scan(source);
}

// Scratch belongs to the wrapper and never escapes on failure. Avoid a large
// Result<Program> value throughout nested source lowering in native debug code.
fn Result<usize, errors::Error> lower_into(ref u8[] source,bool origin_analysis,bool references,bool returns,bool scalar_host_calls,ref literal_collection::Index literals,ref mut ir::Program p) {
    if (source.len > 4096) { return .err(errors::make(4, 4096)); }
    let ref str valid = switch (text::validate_utf8(source)) {
        case .ok(value): { value } case .err(_): { return .err(errors::make(1, 0)); }
    };
    var functions::Table signatures = lowering_signatures(source,returns)?;
    if(scalar_host_calls && signatures.count!=1){return .err(errors::make(3,0));}
    signatures.scalar_host_calls=scalar_host_calls;
    var usize active=16;
    return lower_prepared(source,origin_analysis,references,returns,literals,ref mut signatures,p,ref mut active,0);
}
fn Result<usize,errors::Error> lower_prepared(ref u8[] source,bool origin_analysis,bool references,bool returns,
    ref literal_collection::Index literals,ref mut functions::Table signatures,ref mut ir::Program p,ref mut usize active,usize start){
    let usize ready=prepare_lowering(source,origin_analysis,references,returns,literals,signatures,p,start,0)?;
    var usize f=0;
    while(f<signatures.count){
        let usize scoped=locate_body(source,signatures,f,active)?;
        let usize emitted=body(source,signatures,f,p)?;
        f+=1;
    }
    return finish_lowering(p,signatures,returns,active);
}
fn Result<usize,errors::Error> lower_prepared_until(ref u8[] source,bool references,ref literal_collection::Index literals,
    ref mut functions::Table signatures,ref mut ir::Program p,ref mut usize active,usize deadline){
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    let usize ready=prepare_lowering(source,false,references,references,literals,signatures,p,0,deadline)?;
    var usize f=0;
    while(f<signatures.count){
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        let usize scoped=locate_body(source,signatures,f,active)?;
        let usize emitted=lower_body_until(source,signatures,f,p,deadline)?;
        f+=1;
    }
    return finish_lowering(p,signatures,references,active);
}

fn Result<usize,errors::Error> prepare_lowering(ref u8[] source,bool origin_analysis,bool references,bool returns,
    ref literal_collection::Index literals,ref mut functions::Table signatures,ref mut ir::Program p,usize start,usize deadline){
    signatures.literals=*literals;signatures.reference_calls=references;
    // Signature candidates do not prove a returned borrow's origin or lifetime.
    // Ordinary/public lowering rejects these declarations, even unreachable
    // ones. Private output carries explicit recipes into a separate complete
    // normalized CFG and original borrowed-result proof before publication.
    var usize declaration = 0;
    while (declaration < signatures.count) {
        if (!origin_analysis && !(signatures.output && returns) && signatures.return_slice_elements[declaration] != 0 && !reference_calls::result(signatures,declaration)) {
            return .err(errors::make(3, signatures.begins[declaration]));
        }
        declaration += 1;
    }
    if(origin_analysis || returns){let usize inferred=source_origins::infer_until(source,signatures,deadline)?;}
    p.function_count = signatures.count;
    p.entry = signatures.entry;
    p.return_types = signatures.return_types;
    if(origin_analysis){
        declaration=0;
        while(declaration<signatures.count){
            if(signatures.return_slice_elements[declaration]!=0){p.return_types[declaration]=12;}
            declaration+=1;
        }
    }
    if(signatures.output && returns){
        declaration=0;while(declaration<signatures.count){
            if(signatures.return_slice_elements[declaration]!=0 && !reference_calls::result(signatures,declaration)){p.return_types[declaration]=12;}
            declaration+=1;
        }
    }
    let usize aggregates=prepare_aggregates_from(source,signatures,p,start,deadline)?;
    return .ok(aggregates);
}
fn Result<usize,errors::Error> locate_body(ref u8[] source,ref functions::Table signatures,usize f,ref mut usize active){
    if(signatures.context.modules!=0){
        *active=switch(source_context::location(source,ref signatures.context,signatures.begins[f])){
            case .ok(v):{v.source}case .err(_):{return .err(errors::make(5,signatures.begins[f]));}
        };
    }
    return .ok(*active);
}
fn Result<usize,errors::Error> finish_lowering(ref mut ir::Program p,ref functions::Table signatures,bool returns,ref mut usize active){
    *active=16;
    if(signatures.output && returns){let usize prepared=output_returns::lower(p,signatures)?;}
    // Preserve the current source/IR restriction on entry calls in array programs.
    if (p.arrays.count != 0 || p.records.count != 0) {
        var usize pc = 0;
        while (pc < p.count) {
            if (p.code[pc * 8] == 9 && p.code[pc * 8 + 2] as usize == p.entry) {
                return .err(errors::make(3, p.offsets[pc]));
            }
            pc += 1;
        }
    }
    return .ok(p.count);
}

pub fn Result<ir::Program,errors::Error> compile(ref u8[] source){
    var ir::Program p=ir::empty();
    let literal_collection::Index literals=literal_collection::empty();
    let usize lowered=lower_into(source,false,false,false,false,ref literals,ref mut p)?;
    return .ok(p);
}
pub fn Result<ir::Program,errors::Error> compile_eval_i32(ref u8[] source){
    if(source.len>4096){return .err(errors::make(4,4096));}
    let ref str valid=switch(text::validate_utf8(source)){case .ok(v):{v}case .err(_):{return .err(errors::make(1,0));}};
    var functions::Table signatures=signature_scan::scan_eval(source)?;
    let literal_collection::Index literals=literal_collection::empty();
    var ir::Program p=ir::empty();var usize active=16;
    let usize lowered=lower_prepared(source,false,false,false,ref literals,ref mut signatures,ref mut p,ref mut active,0)?;
    if(p.arrays.count!=0 || p.records.count!=0){return .err(errors::make(3,signatures.begins[signatures.entry]));}
    return .ok(p);
}
// Private candidate only. The Engine still verifies and binds the catalog digest
// and Policy through the existing host Program admission.
pub fn Result<usize,errors::Error> lower_scalar_host(ref u8[] source,ref host_catalog::Catalog imports,ref mut ir::Program code){
    return lower_scalar_host_with_limit(source,imports,code,1024);
}
pub fn Result<usize,errors::Error> lower_scalar_host_with_limit(ref u8[] source,ref host_catalog::Catalog imports,
    ref mut ir::Program code,usize token_limit){
    return lower_scalar_host_until(source,imports,code,token_limit,0);
}
pub fn Result<usize,errors::Error> lower_scalar_host_until(ref u8[] source,ref host_catalog::Catalog imports,
    ref mut ir::Program code,usize token_limit,usize deadline){
    if(source.len>4096){return .err(errors::make(4,4096));}
    let ref str valid=switch(text::validate_utf8(source)){case .ok(v):{v}case .err(_):{return .err(errors::make(1,0));}};
    let usize start=host_source::prepare(source,code,imports,token_limit)?;
    var functions::Table signatures=signature_scan::scan_host_from(source,start)?;
    let literal_collection::Index literals=literal_collection::empty();
    var usize active=16;
    let usize count=lower_prepared(source,false,false,false,ref literals,ref mut signatures,code,ref mut active,start)?;
    return host_source::finish_until(source,code,deadline);
}

// The selected Index owns the original modules and scoped guest aliases.
pub fn Result<usize,source_errors::Error> lower_project_host(ref module_index::Index index,usize selected,
    ref host_catalog::Catalog imports,ref mut ir::Program code,usize deadline,ref mut usize fuel){
    let ref source_snapshot::Snapshot snapshot=module_index::snapshot(index);
    var usize active=16;
    switch(host_source::prepare_project(index,code,imports,ref mut active,deadline,fuel)){
        case .ok(_):{}case .err(e):{
            return .err(if(e.location==errors::absent_location()){source_errors::absent(e)}else{source_errors::map(snapshot,e,active)});
        }
    };
    var module_source::State work=module_source::begin(false);
    discard module_source::finish_metered(index,ref mut work,deadline,fuel)?;
    let ref source_context::Input input=ref work.context.result;
    let ref u8[] source=ref input.data[..input.used];
    return lower_project_host_body(source,ref input.context,index,selected,code,deadline,fuel);
}
fn Result<usize,source_errors::Error> lower_project_host_body(ref u8[] source,ref source_context::Table scope,
    ref module_index::Index index,usize selected,ref mut ir::Program code,usize deadline,ref mut usize fuel){
    var functions::Table signatures=switch(signature_scan::scan_indexed_metered(source,scope,index,selected,false,true,deadline,fuel)){
        case .ok(v):{v}case .err(e):{return .err(input_module_error(index,e,16));}
    };
    signatures.output=true;
    let usize entry=signatures.entry;
    let usize formal=entry*8;
    let usize arity=signatures.arities[entry];
    if(signatures.return_types[entry]!=1 || signatures.return_lengths[entry]!=0 ||
        signatures.return_records[entry]!=0 || signatures.return_slice_elements[entry]!=0 ||
        (arity!=0 && (arity!=1 || !signatures.param_slices[formal] || signatures.param_slice_elements[formal]!=10))){
        return .err(input_module_error(index,errors::make(3,signatures.begins[entry]),16));
    }
    if(arity==1){
        // Host byte cells carry only immutable descriptors owned by the exchange.
        signatures.param_slices[formal]=false;
        signatures.param_types[formal]=14;
    }
    let literal_collection::Index literals=literal_collection::empty();
    var usize active=16;
    switch(lower_host_project_bodies(source,ref literals,ref mut signatures,code,ref mut active,deadline,fuel)){
        case .ok(_):{}case .err(e):{return .err(input_module_error(index,e,active));}
    };
    return switch(host_source::finish_metered(source,code,deadline,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(input_module_error(index,e,16))}
    };
}

fn Result<usize,errors::Error> lower_host_project_bodies(ref u8[] source,ref literal_collection::Index literals,
    ref mut functions::Table signatures,ref mut ir::Program code,ref mut usize active,usize deadline,ref mut usize fuel){
    discard metadata_budget::prepay(fuel,0)?;
    discard prepare_lowering(source,false,false,false,literals,signatures,code,0,deadline)?;
    var usize f=0;
    while(f<signatures.count){
        discard locate_body(source,signatures,f,active)?;
        discard lower_body_metered(source,signatures,f,code,false,deadline,fuel)?;
        f+=1;
    }
    discard metadata_budget::prepay(fuel,0)?;
    return finish_lowering(code,signatures,false,active);
}

// The analysis Program stays private and is never returned to an executor.
pub fn Result<slice_origins::Summary,errors::Error> inspect_slice_results(ref u8[] source){
    var ir::Program p=ir::empty();
    let literal_collection::Index literals=literal_collection::empty();
    let usize lowered=lower_into(source,true,false,false,false,ref literals,ref mut p)?;
    let functions::Table signatures=functions::scan(source)?;
    let slice_result_ir::Program unit=slice_result_ir::from_proxy(p,ref signatures)?;
    let slice_result_verifier::Proof checked=slice_result_verifier::inspect(ref unit)?;
    return .ok(slice_origins::Summary{.parameters=checked.parameters,.rounds=checked.rounds});
}

// Non-executable returned-view IR. Public compile retains its declaration gate.
pub fn Result<slice_result_ir::Program,errors::Error> inspect_slice_result_ir(ref u8[] source){
    var ir::Program p=ir::empty();
    let literal_collection::Index literals=literal_collection::empty();
    let usize lowered=lower_into(source,true,false,false,false,ref literals,ref mut p)?;
    let functions::Table signatures=functions::scan(source)?;
    let slice_result_ir::Program unit=slice_result_ir::from_proxy(p,ref signatures)?;
    let slice_result_verifier::Proof checked=slice_result_verifier::inspect(ref unit)?;
    return .ok(unit);
}

fn program_images::Error image_source_error(errors::Error e){
    return program_images::Error{.kind=.Code,.code=e,.literal=.State};
}
fn program_images::Error image_literal_error(static_images::Error e){
    return program_images::Error{.kind=.Literal,.code=errors::make(0,0),.literal=e};
}
// Native retained-image source entry. Source/IR/image scratch never escapes on
// failure. Returned-reference declarations keep their existing public gate here.
// image_limit covers image metadata+payload, not complete compiler/Program RAM.
pub fn Result<program_images::Program,program_images::Error> compile_image(ref u8[] source,usize image_limit){
    var static_images::Builder builder=switch(static_images::builder(4096)){
        case .ok(v):{v}case .err(e):{return .err(image_literal_error(e));}
    };
    let literal_collection::Index literals=switch(literal_collection::collect(ref mut builder,source)){
        case .ok(v):{v}case .err(e):{
            let program_images::Error mapped=switch(e.kind){
                case .Source:{image_source_error(e.source)}case .Image:{image_literal_error(e.image)}
            };return .err(mapped);
        }
    };
    var ir::Program body=ir::empty();
    switch(lower_into(source,false,false,false,false,ref literals,ref mut body)){
        case .ok(_):{}case .err(e):{return .err(image_source_error(e));}
    };
    let static_images::Image image=switch(static_images::freeze(ref builder,image_limit)){
        case .ok(v):{v}case .err(e):{return .err(image_literal_error(e));}
    };
    let slice_result_ir::Program code=slice_result_ir::Program{.body=body,.elements=[0;16],.parameters=[0;16]};
    return program_images::retain(ref code,image,image_limit);
}

// Private source-to-retained mixed-backing CALL path. Public entry points keep
// their gates until result/source and ordinary admission integration is complete.
pub fn Result<program_images::ReferenceProgram,program_images::Error> compile_references(ref u8[] source,usize image_limit){
    var static_images::Builder builder=switch(static_images::builder(4096)){
        case .ok(v):{v}case .err(e):{return .err(image_literal_error(e));}
    };
    let literal_collection::Index literals=switch(literal_collection::collect(ref mut builder,source)){
        case .ok(v):{v}case .err(e):{return .err(switch(e.kind){
            case .Source:{image_source_error(e.source)}case .Image:{image_literal_error(e.image)}
        });}
    };
    var ir::Program body=ir::empty();
    switch(lower_into(source,false,true,false,false,ref literals,ref mut body)){
        case .ok(_):{}case .err(e):{return .err(image_source_error(e));}
    };
    let functions::Table signatures=switch(functions::scan(source)){
        case .ok(v):{v}case .err(e):{return .err(image_source_error(e));}
    };
    var reference_ir::Program code=reference_ir::Program{.body=body,.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    var usize f=0;while(f<signatures.count){var usize i=0;while(i<signatures.arities[f]){
        let usize at=f*8+i;
        if(signatures.param_slices[at] && signatures.param_slice_elements[at]==10){code.parameters[body.register_starts[f]+i]=3;}i+=1;
    }f+=1;}
    let static_images::Image image=switch(static_images::freeze(ref builder,image_limit)){
        case .ok(v):{v}case .err(e):{return .err(image_literal_error(e));}
    };
    return program_images::retain_references(ref code,image,image_limit);
}

// Private returned-reference source path. Generic result admission remains
// separate from the ordinary public compiler and host-visible reference ABI.
pub fn Result<program_images::ReferenceReturnProgram,program_images::Error> compile_reference_returns(ref u8[] source,usize image_limit){
    var static_images::Builder builder=static_images::full_builder();
    var reference_ir::Program code=reference_return_candidate();
    let Result<usize,program_images::Error> lowered=lower_reference_returns(source,ref mut builder,ref mut code);
    return publish_lowered_reference_returns(ref builder,ref code,lowered,image_limit);
}
// Constructor intermediates must return before recursive lowering starts.
fn reference_ir::Program reference_return_candidate(){
    return reference_ir::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
}
fn Result<program_images::ReferenceReturnProgram,program_images::Error> publish_lowered_reference_returns(
    ref static_images::Builder builder,ref reference_ir::Program code,
    Result<usize,program_images::Error> lowered,usize image_limit){
    switch(lowered){case .ok(_):{}case .err(e):{return .err(e);}};
    return finish_reference_returns(builder,code,image_limit);
}
fn Result<program_images::ReferenceReturnProgram,program_images::Error> finish_reference_returns(
    ref static_images::Builder builder,ref reference_ir::Program code,usize image_limit){
    let static_images::Image image=switch(static_images::freeze(builder,image_limit)){
        case .ok(v):{v}case .err(e):{return .err(image_literal_error(e));}
    };
    return program_images::retain_reference_returns(code,image,image_limit);
}
// Recursive lowering must not retain large Result<ReferenceReturnProgram>
// error/return slots or the signature pass's separate scratch on its stack.
fn Result<usize,program_images::Error> lower_reference_returns(ref u8[] source,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code){
    let literal_collection::Index literals=switch(literal_collection::collect(builder,source)){
        case .ok(v):{v}case .err(e):{return .err(switch(e.kind){
            case .Source:{image_source_error(e.source)}case .Image:{image_literal_error(e.image)}
        });}
    };
    switch(lower_into(source,false,true,true,false,ref literals,ref mut code.body)){
        case .ok(_):{}case .err(e):{return .err(image_source_error(e));}
    };
    return reference_return_signature(source,code);
}
fn Result<usize,program_images::Error> reference_return_signature(ref u8[] source,ref mut reference_ir::Program code){
    var functions::Table signatures=switch(functions::scan_reference_returns(source)){
        case .ok(v):{v}case .err(e):{return .err(image_source_error(e));}
    };
    switch(source_origins::infer(source,ref mut signatures)){case .ok(_):{}case .err(e):{return .err(image_source_error(e));}};
    code.origins=signatures.return_slice_inputs;
    var u8[128] parameters=[0;128];var u8[16] results=[0;16];
    let ref ir::Program body=ref code.body;
    var usize f=0;while(f<signatures.count){
        if(signatures.return_slice_elements[f]==10){results[f]=3;}
        var usize i=0;while(i<signatures.arities[f]){let usize at=f*8+i;
            if(signatures.param_slices[at] && signatures.param_slice_elements[at]==10){parameters[body.register_starts[f]+i]=3;}i+=1;
        }f+=1;
    }
    code.parameters=parameters;code.results=results;
    return .ok(signatures.count);
}

pub fn errors::Error public_error(program_images::Error error){
    return switch(error.kind){case .Code:{error.code}case .Literal:{switch(error.literal){
        case .Allocation:{errors::make(15,0)}case .Utf8:{errors::make(1,0)}
        case .Limit:{errors::make(4,0)}case .Quota:{errors::make(4,0)}case .Literals:{errors::make(4,0)}
        case .State:{errors::make(5,0)}case .Kind:{errors::make(5,0)}case .Bounds:{errors::make(5,0)}case .Provider:{errors::make(5,0)}
    }}};
}
// Public source admission chooses one complete path from explicit token syntax.
// A failed compile is never retried under a different language or Fuel schedule.
pub fn Result<program_images::PublicProgram,errors::Error> compile_program(ref u8[] source,usize image_limit){
    if(source_features::retained(source)?){return compile_public_references(source,image_limit);}
    return compile_public_legacy(source);
}
// Keep mutually exclusive admission temporaries off each other's native stack.
fn Result<program_images::PublicProgram,errors::Error> compile_public_references(ref u8[] source,usize image_limit){
    // Share lowering and final admission with the private API, without waiting
    // in its owning Result frame as well as the public adapter's frame.
    var static_images::Builder builder=static_images::full_builder();
    var reference_ir::Program code=reference_return_candidate();
    let Result<usize,program_images::Error> lowered=lower_reference_returns(source,ref mut builder,ref mut code);
    return publish_lowered_public_references(ref builder,ref code,lowered,image_limit);
}
fn Result<program_images::PublicProgram,errors::Error> publish_lowered_public_references(
    ref static_images::Builder builder,ref reference_ir::Program code,
    Result<usize,program_images::Error> lowered,usize image_limit){
    switch(lowered){case .ok(_):{}case .err(e):{return .err(public_error(e));}};
    return publish_public_references(finish_reference_returns(builder,code,image_limit));
}
fn Result<program_images::PublicProgram,errors::Error> publish_public_references(
    Result<program_images::ReferenceReturnProgram,program_images::Error> candidate){
    return switch(candidate){
        case .ok(p):{.ok(program_images::retain_public_references(p))}
        case .err(e):{.err(public_error(e))}
    };
}
fn Result<program_images::PublicProgram,errors::Error> compile_public_legacy(ref u8[] source){
    var ir::Program code=ir::empty();
    let literal_collection::Index literals=literal_collection::empty();
    let usize lowered=lower_into(source,false,false,false,false,ref literals,ref mut code)?;
    return switch(program_images::retain_public_legacy(ref code)){
        case .ok(v):{.ok(v)}case .err(e):{.err(public_error(e))}
    };
}

// Candidate lowering only. Rebuild all compiler scratch from the exact retained
// selection; callers must independently admit the complete IR and image.
pub fn Result<bool,source_errors::Error> lower_modules(ref module_entries::Entry selected,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code){
    return lower_modules_mode(selected,builder,code,false);
}
pub fn Result<usize,source_errors::Error> lower_output_modules(ref module_entries::Entry selected,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code){
    let bool retained=lower_modules_mode(selected,builder,code,true)?;
    return .ok(code.body.count);
}
pub fn Result<usize,source_errors::Error> lower_output_modules_until(ref module_entries::Entry selected,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code,usize deadline,ref mut usize fuel){
    let ref module_index::Index index=module_entries::index(selected);
    var module_source::State work=module_source::begin(true);
    discard module_source::finish_metered(index,ref mut work,deadline,fuel)?;
    discard lower_modules_prepared_metered(selected,ref work,builder,code,true,deadline,fuel)?;
    return .ok(code.body.count);
}
pub fn Result<bool,source_errors::Error> lower_modules_until(ref module_entries::Entry selected,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code,bool output,usize deadline){
    let ref module_index::Index index=module_entries::index(selected);
    var module_source::State work=module_source::begin(true);
    let usize staged=module_source::finish_until(index,ref mut work,deadline)?;
    return lower_modules_prepared_until(selected,ref work,builder,code,output,deadline);
}
// The owning source pass binds work to the Index of selected for its lifetime.
pub fn Result<bool,source_errors::Error> lower_modules_prepared_until(ref module_entries::Entry selected,
    ref module_source::State work,ref mut static_images::Builder builder,ref mut reference_ir::Program code,bool output,usize deadline){
    var usize fuel=metadata_budget::unlimited();
    return lower_modules_prepared_metered(selected,work,builder,code,output,deadline,ref mut fuel);
}
fn Result<bool,source_errors::Error> lower_modules_prepared_metered(ref module_entries::Entry selected,
    ref module_source::State work,ref mut static_images::Builder builder,ref mut reference_ir::Program code,
    bool output,usize deadline,ref mut usize fuel){
    if(!work.done || !work.syntax.done){return .err(source_errors::absent(errors::absent(5,0)));}
    if(clock::expired(deadline)){return .err(source_errors::absent(errors::absent(errors::deadline_kind(),0)));}
    let ref module_index::Index index=module_entries::index(selected);
    let ref source_context::Input input=ref work.context.result;
    let ref u8[] source=ref input.data[..input.used];
    let ref source_context::Table scope=ref input.context;
    let bool references=work.syntax.result || output;
    let literal_collection::Index literals=if(references){module_literals_metered(builder,source,scope,index,deadline,fuel)?}
        else{literal_collection::empty()};
    return lower_modules_literals_until(selected,work,ref literals,code,output,deadline,fuel);
}
pub fn Result<bool,source_errors::Error> advance_module_literals(ref module_index::Index index,
    ref module_source::State work,ref mut static_images::Builder builder,ref mut literal_work::State literals,
    ref mut metadata_budget::State meter){
    let ref source_context::Input input=ref work.context.result;
    return switch(literal_work::advance_fresh(ref input.data[..input.used],ref input.context,builder,literals,meter)){
        case .ok(v):{.ok(v)}case .err(e):{.err(module_literal_failure(e,index))}
    };
}
fn Result<bool,source_errors::Error> lower_modules_literals_until(ref module_entries::Entry selected,
    ref module_source::State work,ref literal_collection::Index literals,ref mut reference_ir::Program code,bool output,usize deadline,ref mut usize fuel){
    let ref module_index::Index index=module_entries::index(selected);
    let usize entry=module_entries::selected(selected);
    let ref source_context::Input input=ref work.context.result;
    let ref u8[] source=ref input.data[..input.used];
    let ref source_context::Table scope=ref input.context;
    let bool references=work.syntax.result || output;
    var functions::Table signatures=switch(signature_scan::scan_indexed_metered(source,scope,index,entry,references,false,deadline,fuel)){
        case .ok(v):{v}case .err(e):{return .err(module_error(selected,e,16));}
    };
    if(output){
        signatures.output=true;
        let usize lowered=lower_reference_bodies_until(index,source,literals,ref mut signatures,code,deadline,fuel)?;
        return .ok(true);
    }
    let bool lowered=lower_modules_signatures_until(selected,work,literals,ref mut signatures,code,false,deadline)?;
    if(lowered){let usize bound=module_reference_signature_until(source,scope,selected,code,deadline)?;}
    return .ok(lowered);
}
pub fn Result<bool,source_errors::Error> advance_module_signatures(ref module_index::Index index,
    ref module_source::State work,ref mut signature_scan::State signatures,ref mut metadata_budget::State meter){
    let ref source_context::Input input=ref work.context.result;
    return switch(signature_scan::advance_indexed(ref input.data[..input.used],ref input.context,
        index,signatures,meter)){
        case .ok(v):{.ok(v)}case .err(e):{.err(input_module_error(index,e,16))}
    };
}
fn Result<bool,source_errors::Error> lower_modules_signatures_until(ref module_entries::Entry selected,
    ref module_source::State work,ref literal_collection::Index literals,ref mut functions::Table signatures,
    ref mut reference_ir::Program code,bool output,usize deadline){
    let ref source_context::Input input=ref work.context.result;
    let ref u8[] source=ref input.data[..input.used];
    let bool references=work.syntax.result || output;
    signatures.output=output;
    var usize active=16;
    switch(lower_prepared_until(source,references,literals,signatures,ref mut code.body,ref mut active,deadline)){
        case .ok(_):{}case .err(e):{return .err(module_error(selected,e,active));}
    };
    return .ok(references);
}
pub struct BodyProgress { usize function; usize active; u8 phase; }
pub fn BodyProgress begin_module_bodies(){return BodyProgress{.function=0,.active=16,.phase=0};}

pub fn Result<bool,source_errors::Error> advance_module_bodies(ref module_index::Index index,
    ref module_source::State work,bool references,bool output,ref literal_work::State collection,ref mut signature_scan::State scan,
    ref mut reference_ir::Program code,ref mut BodyProgress progress,
    ref mut lexer::State token,ref mut locals::Table names,ref mut loops::State flow,
    ref mut body_work::State cursor,ref mut metadata_budget::State meter,usize deadline,ref mut usize fuel){
    if(!work.done || !scan.done || (references && !collection.done)){
        return .err(source_errors::absent(errors::absent(5,0)));
    }
    let ref source_context::Input input=ref work.context.result;
    let ref u8[] source=ref input.data[..input.used];
    let literal_collection::Index unused=literal_collection::empty();
    let ref literal_collection::Index literals=if(references){ref collection.result}else{ref unused};
    if(progress.phase==0){scan.result.output=output;}
    return switch(advance_module_body(source,references,literals,ref mut scan.result,code,progress,token,names,flow,cursor,meter,deadline,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(input_module_error(index,e,progress.active))}
    };
}

// Semantic child calls return before another control advance. Preparation and
// child internals retain their existing synchronous boundaries.
fn Result<bool,errors::Error> advance_module_body(ref u8[] source,bool references,ref literal_collection::Index literals,
    ref mut functions::Table signatures,ref mut reference_ir::Program code,ref mut BodyProgress progress,
    ref mut lexer::State token,ref mut locals::Table names,ref mut loops::State flow,
    ref mut body_work::State cursor,ref mut metadata_budget::State meter,usize deadline,ref mut usize fuel){
    if(progress.phase==3){return .ok(true);}
    let usize f=progress.function;
    if(progress.phase==0){
        let usize ready=prepare_lowering(source,false,references,references,literals,signatures,ref mut code.body,0,deadline)?;
        progress.phase=1;
        return .ok(false);
    }
    if(f==signatures.count){
        let usize done=finish_lowering(ref mut code.body,signatures,references,ref mut progress.active)?;
        if(references){let usize bound=finish_reference_lowering(signatures,code);}
        progress.phase=3;
        return .ok(true);
    }
    if(progress.phase==1){
        let usize active=locate_body(source,signatures,f,ref mut progress.active)?;
        *names=locals::empty();
        let usize bound=bind_body(signatures,f,ref mut code.body,names)?;
        *token=source_context::state(source,ref signatures.context,signatures.bodies[f])?;
        let usize first=lexer::next(source,token)?;
        *flow=loops::empty();
        *cursor=body_work::begin(0,false);
        progress.phase=2;
        return .ok(false);
    }
    if(cursor.done){
        let bool terminal=body_work::prepared(cursor)?;
        let usize finished=finish_body(signatures,f,ref mut code.body,names,token,terminal)?;
        progress.function=f+1;
        progress.phase=1;
        return .ok(false);
    }
    if(cursor.request!=0){
        let u8 result=if(reference_calls::result(signatures,f)){12}else{record_results::context(ref code.body,f)};
        let usize completed=complete_body_child_metered(source,token,ref mut code.body,names,signatures,result,0,flow,cursor,deadline,fuel)?;
        return .ok(false);
    }
    let bool advanced=body_work::advance_limited(source,token,ref mut code.body,names,flow,cursor,meter,signatures.semantic_depth)?;
    return .ok(false);
}

fn Result<bool,source_errors::Error> lower_modules_mode(ref module_entries::Entry selected,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code,bool output){
    let source_context::Input input=switch(collecting::collect(module_entries::index(selected))){
        case .ok(v):{v}case .err(e):{return .err(source_errors::Error{.code=errors::make(5,e.at.start),.at=e.at});}
    };
    return lower_modules_collected(ref input,selected,builder,code,output);
}
fn Result<bool,source_errors::Error> lower_modules_collected(ref source_context::Input input,ref module_entries::Entry selected,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code,bool output){
    let ref u8[] data=ref input.data;let ref u8[] source=data[..input.used];
    let ref source_context::Table scope=ref input.context;
    let bool retained=switch(source_features::retained_scoped(source,scope)){
        case .ok(v):{v}case .err(e):{return .err(module_error(selected,e,16));}
    };
    if(retained || output){let usize lowered=lower_module_references(source,scope,selected,builder,code,output)?;}
    else{let literal_collection::Index literals=literal_collection::empty();var usize active=16;
        switch(lower_module(source,scope,selected,false,ref literals,ref mut code.body,ref mut active)){
            case .ok(_):{}case .err(e):{return .err(module_error(selected,e,active));}
        };
    }return .ok(retained || output);
}
fn source_errors::Error module_error(ref module_entries::Entry selected,errors::Error error,usize active){
    return if(error.offset==0){source_errors::absent(error)}else{source_errors::map(module_index::snapshot(module_entries::index(selected)),error,active)};
}
fn Result<usize,errors::Error> lower_module(ref u8[] source,ref source_context::Table scope,
    ref module_entries::Entry selected,bool references,ref literal_collection::Index literals,ref mut ir::Program code,ref mut usize active){
    var functions::Table signatures=functions::scan_scoped(source,scope,selected,references)?;
    return lower_prepared(source,false,references,references,literals,ref mut signatures,code,active,0);
}
fn Result<usize,source_errors::Error> lower_module_references(ref u8[] source,ref source_context::Table scope,
    ref module_entries::Entry selected,ref mut static_images::Builder builder,ref mut reference_ir::Program code,bool output){
    let literal_collection::Index literals=module_literals(builder,source,scope,module_entries::index(selected))?;
    var usize active=16;
    var functions::Table signatures=switch(functions::scan_scoped(source,scope,selected,true)){
        case .ok(v):{v}case .err(e):{return .err(module_error(selected,e,16));}
    };signatures.output=output;
    switch(lower_prepared(source,false,true,true,ref literals,ref mut signatures,ref mut code.body,ref mut active,0)){
        case .ok(_):{}case .err(e):{return .err(module_error(selected,e,active));}
    };
    return module_reference_signature(source,scope,selected,code);
}
fn Result<literal_collection::Index,source_errors::Error> module_literals(ref mut static_images::Builder builder,
    ref u8[] source,ref source_context::Table scope,ref module_index::Index index){
    return module_literal_result(literal_collection::collect_scoped(builder,source,scope),index);
}
fn Result<literal_collection::Index,source_errors::Error> module_literals_metered(ref mut static_images::Builder builder,
    ref u8[] source,ref source_context::Table scope,ref module_index::Index index,usize deadline,ref mut usize fuel){
    return module_literal_result(literal_collection::collect_scoped_metered(builder,source,scope,deadline,fuel),index);
}
fn Result<literal_collection::Index,source_errors::Error> module_literal_result(
    Result<literal_collection::Index,literal_source::Error> collected,ref module_index::Index index){
    return switch(collected){
        case .ok(v):{.ok(v)}case .err(e):{.err(module_literal_failure(e,index))}
    };
}
fn source_errors::Error module_literal_failure(literal_source::Error e,ref module_index::Index index){
    return input_module_error(index,public_error(switch(e.kind){
        case .Source:{image_source_error(e.source)}case .Image:{image_literal_error(e.image)}
    }),16);
}

fn Result<usize,source_errors::Error> module_reference_signature(ref u8[] source,ref source_context::Table scope,
    ref module_entries::Entry selected,ref mut reference_ir::Program code){
    var functions::Table signatures=switch(functions::scan_scoped(source,scope,selected,true)){
        case .ok(v):{v}case .err(e):{return .err(module_error(selected,e,16));}
    };
    return bind_reference_signature(source,ref mut signatures,selected,code,0);
}
fn Result<usize,source_errors::Error> module_reference_signature_until(ref u8[] source,ref source_context::Table scope,
    ref module_entries::Entry selected,ref mut reference_ir::Program code,usize deadline){
    let ref module_index::Index index=module_entries::index(selected);
    let usize entry=module_entries::selected(selected);
    var functions::Table signatures=switch(signature_scan::scan_indexed_until(source,scope,index,entry,true,deadline)){
        case .ok(v):{v}case .err(e):{return .err(module_error(selected,e,16));}
    };
    return bind_reference_signature(source,ref mut signatures,selected,code,deadline);
}
fn Result<usize,source_errors::Error> bind_reference_signature(ref u8[] source,ref mut functions::Table signatures,
    ref module_entries::Entry selected,ref mut reference_ir::Program code,usize deadline){
    switch(source_origins::infer_until(source,signatures,deadline)){case .ok(_):{}case .err(e):{return .err(module_error(selected,e,16));}};
    code.origins=signatures.return_slice_inputs;
    var u8[128] parameters=[0;128];var u8[16] results=[0;16];
    let ref ir::Program body=ref code.body;var usize f=0;
    while(f<signatures.count){
        if(signatures.return_slice_elements[f]==10){results[f]=3;}
        var usize i=0;while(i<signatures.arities[f]){let usize at=f*8+i;
            if(signatures.param_slices[at] && signatures.param_slice_elements[at]==10){parameters[body.register_starts[f]+i]=3;}i+=1;
        }f+=1;
    }code.parameters=parameters;code.results=results;return .ok(signatures.count);
}

// Private one-shared-byte-input entry. The exact selected Index is rebuilt into
// the same body compiler; separate independent input admission must follow.
pub fn Result<usize,source_errors::Error> lower_input_modules(ref input_entries::InputEntry selected,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code){
    return lower_input_modules_mode(selected,builder,code,false);
}
pub fn Result<usize,source_errors::Error> lower_input_output_modules(ref input_entries::InputEntry selected,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code){
    return lower_input_modules_mode(selected,builder,code,true);
}
pub fn Result<usize,source_errors::Error> lower_input_modules_until(ref input_entries::InputEntry selected,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code,bool output,usize deadline){
    var usize fuel=metadata_budget::unlimited();
    return lower_input_modules_metered(selected,builder,code,output,deadline,ref mut fuel);
}
pub fn Result<usize,source_errors::Error> lower_input_modules_metered(ref input_entries::InputEntry selected,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code,bool output,usize deadline,ref mut usize fuel){
    let ref module_index::Index index=input_entries::index(selected);
    var module_source::State work=module_source::begin(false);
    discard module_source::finish_metered(index,ref mut work,deadline,fuel)?;
    return lower_input_modules_prepared_metered(selected,ref work,builder,code,output,deadline,fuel);
}
fn Result<usize,source_errors::Error> lower_input_modules_prepared_metered(ref input_entries::InputEntry selected,
    ref module_source::State work,ref mut static_images::Builder builder,ref mut reference_ir::Program code,
    bool output,usize deadline,ref mut usize fuel){
    if(!work.done || work.classify){return .err(source_errors::absent(errors::absent(5,0)));}
    if(clock::expired(deadline)){return .err(source_errors::absent(errors::absent(errors::deadline_kind(),0)));}
    let ref module_index::Index index=input_entries::index(selected);
    let ref source_context::Input input=ref work.context.result;
    let ref u8[] source=ref input.data[..input.used];
    let ref source_context::Table scope=ref input.context;
    let literal_collection::Index literals=module_literals_metered(builder,source,scope,index,deadline,fuel)?;
    var functions::Table signatures=switch(signature_scan::scan_indexed_metered(source,scope,index,input_entries::selected(selected),true,false,deadline,fuel)){
        case .ok(v):{v}case .err(e):{return .err(input_module_error(index,e,16));}
    };
    signatures.output=output;
    return lower_reference_bodies_until(index,source,ref literals,ref mut signatures,code,deadline,fuel);
}
// Input and output both require reference metadata. The synchronous adapters
// drain the same body cursor as the private Engine and preserve the Index for spans.
fn Result<usize,source_errors::Error> lower_reference_bodies_until(ref module_index::Index index,ref u8[] source,
    ref literal_collection::Index literals,ref mut functions::Table signatures,ref mut reference_ir::Program code,usize deadline,ref mut usize fuel){
    var BodyProgress progress=begin_module_bodies();
    var lexer::State token=lexer::empty();var locals::Table names=locals::empty();
    var loops::State flow=loops::empty();var body_work::State cursor=body_work::begin(0,false);
    while(true){
        if(clock::expired(deadline)){return .err(source_errors::absent(errors::absent(errors::deadline_kind(),0)));}
        switch(metadata_budget::prepay(fuel,token.begin)){
            case .ok(_):{}case .err(e):{return .err(input_module_error(index,e,progress.active));}
        };
        var metadata_budget::State meter=metadata_budget::empty();
        switch(advance_module_body(source,true,literals,signatures,code,ref mut progress,
            ref mut token,ref mut names,ref mut flow,ref mut cursor,ref mut meter,deadline,fuel)){
            case .ok(done):{if(done){return .ok(code.body.count);}}
            case .err(e):{return .err(input_module_error(index,e,progress.active));}
        };
    }
    return .err(source_errors::absent(errors::absent(5,0)));
}
fn Result<usize,source_errors::Error> lower_input_modules_mode(ref input_entries::InputEntry selected,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code,bool output){
    let ref module_index::Index index=input_entries::index(selected);
    let source_context::Input input=switch(collecting::collect(index)){
        case .ok(v):{v}case .err(e):{return .err(source_errors::Error{.code=errors::make(5,e.at.start),.at=e.at});}
    };
    return lower_input_collected(ref input,selected,builder,code,output);
}
fn Result<usize,source_errors::Error> lower_input_collected(ref source_context::Input input,ref input_entries::InputEntry selected,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code,bool output){
    let ref module_index::Index index=input_entries::index(selected);
    let ref u8[] data=ref input.data;let ref u8[] source=data[..input.used];let ref source_context::Table scope=ref input.context;
    let literal_collection::Index literals=module_literals(builder,source,scope,index)?;
    var functions::Table signatures=switch(functions::scan_input_scoped(source,scope,selected)){
        case .ok(v):{v}case .err(e):{return .err(input_module_error(index,e,16));}
    };signatures.output=output;
    var usize active=16;
    switch(lower_prepared(source,false,true,true,ref literals,ref mut signatures,ref mut code.body,ref mut active,0)){
        case .ok(_):{}case .err(e):{return .err(input_module_error(index,e,active));}
    };
    return .ok(finish_reference_lowering(ref signatures,code));
}
fn usize finish_reference_lowering(ref functions::Table signatures,ref mut reference_ir::Program code){
    code.origins=signatures.return_slice_inputs;
    code.parameters=[0;128];code.results=[0;16];
    var usize f=0;
    while(f<signatures.count){
        if(signatures.return_slice_elements[f]==10){code.results[f]=3;}
        var usize i=0;while(i<signatures.arities[f]){let usize at=f*8+i;
            if(signatures.param_slices[at] && signatures.param_slice_elements[at]==10){let usize formal=code.body.register_starts[f]+i;code.parameters[formal]=3;}i+=1;
        }f+=1;
    }return code.body.count;
}
fn source_errors::Error input_module_error(ref module_index::Index index,errors::Error e,usize active){
    return if(e.offset==0){source_errors::absent(e)}else{source_errors::map(module_index::snapshot(index),e,active)};
}
