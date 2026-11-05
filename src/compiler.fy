module compiler;

import errors as errors;
import lexer as lexer;
import ir as ir;
import locals as locals;
import local_inference as inference;
import aggregate_inference as aggregate_inference;
import reference_inference as reference_inference;
import array_local_source as array_locals;
import std::vec as vec;
import functions as functions;
import struct_source as structs;
import struct_value_source as record_values;
import types as types;
import loops as loops;
import patterns as patterns;
import propagation as propagation;
import casts as casts;
import array_source as arrays;
import array_call_source as array_calls;
import call_prefix_source as call_prefix;
import struct_call_source as record_calls;
import array_result_source as array_results;
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
import static_builders as static_builders;
import static_source as static_source;
import static_image as static_images;
import program_image as program_images;
import reference_call_source as reference_calls;
import static_call_ir as reference_ir;
import reference_result_source as reference_results;
import source_features as source_features;
import source_context as source_context;
import module_entry as module_entries;
import source_error as source_errors;
import module_index as module_index;

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
fn Result<usize, errors::Error> operand(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state) {
    if(depth>32){return .err(errors::make(4,s.begin));}
    if((s.kind==2 || s.kind==5) && !word_is(source,s,b"switch")){
        return named_operand(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state);
    }
    return compound_operand(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state);
}
fn Result<usize, errors::Error> compound_operand(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state) {
    if (depth > 32) { return .err(errors::make(4, s.begin)); }
    let ref literal_collection::Index literals=ref signatures.literals;
    let usize at = s.begin;
    if(s.kind==3 && literals.enabled){
        var lexer::State look=lexer::snapshot(s);let usize next=lexer::next(source,ref mut look)?;
        if(static_source::range_follows(source,ref look)?){
            let static_source::View view=static_view(source,s,p,table,signatures,depth,result_type,structure,loop_state)?;
            return static_projection(source,s,p,table,signatures,ref view,at,depth,result_type,structure,loop_state);
        }
        return literal_projection(source,s,p,table,signatures,depth,result_type,structure,loop_state,false);
    }
    if(word_is(source,s,b"switch")) {
        return switch_value(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state);
    }
    if (s.kind == 46) {
        if (expected!=0 && !types::tagged(expected)) {return .err(errors::make(3,at));}
        let usize dot=lexer::next(source,s)?;
        let bool positive=word_is(source,s,b"some") || word_is(source,s,b"ok");
        if(expected==0){
            // Only Option's positive constructor carries its complete type.
            // No default payload/error domain is invented for none/ok/err.
            if(!word_is(source,s,b"some")){return .err(errors::make(3,at));}
        }else if (expected<=4) {
            if (!word_is(source,s,b"some") && !word_is(source,s,b"none")) {return .err(errors::make(3,at));}
        } else if (!word_is(source,s,b"ok") && !word_is(source,s,b"err")) {return .err(errors::make(3,at));}
        let u8 variant=if(positive) {1} else {0};
        let u8 payload_type=if(expected==0){0}else{types::payload(expected,variant)};
        let usize name=lexer::next(source,s)?;
        var usize value=0;
        if (payload_type!=0 || expected==0) {
            let usize open=lexer::punctuation(source,s,40)?;
            value=expression(source,s,p,table,signatures,1,depth+1,payload_type,result_type,structure,loop_state)?;
            if (expected!=0 && p.types[value]!=payload_type) {return .err(errors::make(3,at));}
            let usize close=lexer::punctuation(source,s,41)?;
        }
        var u8 tag=expected;
        if(tag==0){
            tag=if(p.types[value]==1){3}else if(p.types[value]==2){4}else{0};
            if(tag==0){return .err(errors::make(3,at));}
        }
        return ir::construct(p,tag,variant,value,at);
    }
    if (s.kind == 45 || s.kind == 33 || s.kind == 126) {
        let bool negative = s.kind == 45;
        let bool complement = s.kind == 126;
        if(negative && types::unsigned(expected)) {return .err(errors::make(3,at));}
        let usize advanced = lexer::next(source, s)?;
        // Admit a minimum signed literal without constructing its positive magnitude.
        if (negative && s.kind == 1 && s.min_magnitude) {
            if (expected!=9) {return .err(errors::make(3,at));}
            let usize advanced_min=lexer::next(source,s)?;
            return ir::integer(p,-9223372036854775808,9,at);
        }
        if (negative && s.kind == 1 && s.value == 2147483648 && expected!=9) {
            let usize advanced_min = lexer::next(source, s)?;
            return ir::literal(p, -2147483648, at);
        }
        let usize operand = primary(source,s,p,table,signatures,depth + 1,expected,result_type,structure,loop_state)?;
        if ((negative && !types::signed(p.types[operand])) || (complement && !types::integer(p.types[operand])) ||
            (!negative && !complement && p.types[operand]!=2)) { return .err(errors::make(3, at)); }
        return ir::emit(p, if (negative) { 7 } else if(complement) {27} else { 10 }, operand, 0, at);
    }
    if (s.kind == 1) {
        let u8 tag=if(types::integer(expected)) {expected} else {1};
        if(!types::unsigned(tag) && s.value<0) {return .err(errors::make(3,at));}
        let i64 value = s.value;
        let usize advanced = lexer::next(source, s)?;
        return ir::integer(p, value, tag, at);
    }
    if (s.kind == 40) {
        if(literals.enabled && static_source::grouped_projection(source,s,table)?){
            let static_source::View view=static_view(source,s,p,table,signatures,depth,result_type,structure,loop_state)?;
            return static_projection(source,s,p,table,signatures,ref view,at,depth,result_type,structure,loop_state);
        }
        let usize advanced = lexer::next(source, s)?;
        let usize result = expression(source,s,p,table,signatures,1,depth + 1,expected,result_type,structure,loop_state)?;
        let usize closed = lexer::punctuation(source, s, 41)?;
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
    if(depth>32){return .err(errors::make(4,s.begin));}
    let usize at=s.begin;var static_source::View value=static_source::View{.site=16,.kind=0,.owned=false};
    if(word_is(source,s,b"ref")){let usize prefix=lexer::next(source,s)?;}
    if(reference_calls::returned_atom(source,s,table,signatures)?){
        let usize target=functions::find(source,signatures,s.begin,s.end);let usize name=lexer::next(source,s)?;
        let usize made=call_value(source,s,p,table,signatures,target,240,at,depth,result_type,structure,loop_state)?;
        value=static_source::View{.site=made-192,.kind=1,.owned=true};
    }else if(s.kind==40){let usize open=lexer::next(source,s)?;
        value=static_view(source,s,p,table,signatures,depth+1,result_type,structure,loop_state)?;
        let usize close=lexer::punctuation(source,s,41)?;
    }else if(word_is(source,s,b"text")){
        var lexer::State look=lexer::snapshot(s);let usize next=lexer::next(source,ref mut look)?;
        if(look.kind==58){let usize module_name=lexer::next(source,s)?;
            let usize colon=lexer::punctuation(source,s,58)?;let usize path=lexer::punctuation(source,s,58)?;
            let usize method=lexer::word(source,s,b"bytes")?;let usize open=lexer::punctuation(source,s,40)?;
            value=static_bytes_argument(source,s,p,table,signatures,at,depth+1,result_type,structure,loop_state)?;
        }else{value=static_source::atom(source,s,p,table,ref signatures.literals,depth)?;}
    }else{value=static_source::atom(source,s,p,table,ref signatures.literals,depth)?;}
    return static_ranges(source,s,p,table,signatures,ref value,depth,result_type,structure,loop_state);
}
fn Result<static_source::View,errors::Error> static_bytes_argument(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize at,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    let static_source::View text=static_view(source,s,p,table,signatures,depth+1,result_type,structure,loop_state)?;
    if(text.kind!=2){return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,41)?;let usize made=static_builders::bytes(p,text.site,at)?;
    if(text.owned){let usize closed=static_builders::close(p,text.site,at)?;}
    return .ok(static_source::View{.site=made,.kind=1,.owned=true});
}
fn Result<static_source::View,errors::Error> static_ranges(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    ref static_source::View parent,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    var static_source::View value=static_source::View{.site=parent.site,.kind=parent.kind,.owned=parent.owned};
    while(static_source::range_follows(source,s)?){
        if(value.kind!=1){return .err(errors::make(3,s.begin));}
        let static_source::View next=if(value.owned){static_owned_range(source,s,p,table,signatures,value.site,depth,result_type,structure,loop_state)?}
            else{static_range(source,s,p,table,signatures,value.site,depth,result_type,structure,loop_state)?};
        value=next;
    }return .ok(value);
}
fn Result<static_source::View,errors::Error> static_owned_range(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize parent,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    let usize at=s.begin;var locals::Table names=locals::snapshot(table);
    if(signatures.reference_returns){let usize roots=reference_results::publish(p,signatures,ref mut names,parent,at)?;}
    let usize hidden=locals::declare(ref mut names,at,at,192+parent,false)?;
    let static_source::View child=static_range(source,s,p,ref names,signatures,parent,depth,result_type,structure,loop_state)?;
    let usize closed=if(signatures.reference_returns){
        let usize keep=reference_results::owners(p,signatures,192+child.site,0,at)?;
        reference_results::release(p,ref names,table.count,keep,at)?
    }else{arrays::release_from(ref names,p,table.count,at)?};return .ok(child);
}
fn Result<static_source::View,errors::Error> static_range(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,
    usize parent,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    let usize at=s.begin;let usize open=lexer::punctuation(source,s,91)?;
    let usize lo=if(s.kind==46){ir::integer(p,0,12,at)?}
        else{expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)?};
    if(p.types[lo]!=12){return .err(errors::make(3,at));}
    let usize first=lexer::punctuation(source,s,46)?;let usize second=lexer::punctuation(source,s,46)?;
    let usize hi=if(s.kind==93){static_builders::scalar(p,parent,0,true,at)?}
        else{expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)?};
    if(p.types[hi]!=12){return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,93)?;let usize site=static_builders::range(p,parent,lo,hi,at)?;
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
fn Result<usize, errors::Error> named_operand(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state) {
    let ref literal_collection::Index literals=ref signatures.literals;
    let usize at = s.begin;
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
    let usize index = locals::find(source, table, begin, end);
    let usize advanced = lexer::next(source, s)?;
    if (s.kind == 40) {
        if (index != 64) { return .err(errors::make(3, at)); }
        let usize target = functions::find(source, signatures, begin, end);
        if (target == 16) { return .err(errors::make(3, at)); }
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
    if(s.kind==91) {
        let usize literal_at=s.begin;
        let usize open=lexer::next(source,s)?;
        let usize filler=expression(source,s,p,table,signatures,1,depth+1,10,result_type,structure,loop_state)?;
        if(p.types[filler]!=10) {return .err(errors::make(3,literal_at));}
        let usize separator=lexer::punctuation(source,s,59)?;
        let usize length=arrays::count(source,s)?;
        let usize close_array=lexer::punctuation(source,s,93)?;
        let usize temporary=ir::array_in(p,table.function,10,length,false,literal_at)?;
        let usize initialized=ir::array_init(p,temporary,filler,literal_at)?;
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
    var locals::Table names=locals::snapshot(table);
    let usize capture=locals::declare(ref mut names,at,at,128+temporary,false)?;
    var usize value=0;
    if(s.kind==91) {
        let usize open=lexer::next(source,s)?;
        let usize index=expression(source,s,p,ref names,signatures,1,depth+1,12,result_type,structure,loop_state)?;
        if(p.types[index]!=12) {return .err(errors::make(3,at));}
        let usize close=lexer::punctuation(source,s,93)?;
        value=ir::array_read(p,temporary,index,at)?;
    } else if(s.kind==46) {
        let usize dot=lexer::next(source,s)?;
        if(!word_is(source,s,b"len")) {return .err(errors::make(3,s.begin));}
        let usize member=lexer::next(source,s)?;
        value=arrays::length_value(p,temporary,at)?;
    } else {return .err(errors::make(3,s.begin));}
    let usize dropped=ir::array_drop(p,temporary,at)?;
    return .ok(value);
}
// A nested result becomes an anonymous argument capture only after its CALL
// succeeds. Later arguments and early exits then use the existing mixed cleanup.
fn Result<usize,errors::Error> record_argument(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    usize record,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state) {
    if((s.kind==2 || s.kind==5)) {
        var lexer::State look=lexer::snapshot(s);
        let usize next=lexer::next(source,ref mut look)?;
        if(look.kind==123) {
            let usize at=s.begin;
            let bool prefix=record_values::constructor(source,s,record,ref signatures.context)?;
            let usize first=record_constructor_value(source,s,p,names,signatures,record,at,result_type,depth,structure,loop_state,true)?;
            let usize temporary=ir::record_in(p,names.function,record,false,at)?;
            let usize init=ir::record_init(p,temporary,first,at)?;
            let usize captured=locals::declare(names,at,at,144+temporary,false)?;
            return .ok(144+temporary);
        }
        if(look.kind==46) {
            let usize at=s.begin;
            let usize temporary=record_values::extracted_argument(source,s,p,names,record,at,ref signatures.context)?;
            let usize captured=locals::declare(names,at,at,144+temporary,false)?;
            return .ok(144+temporary);
        }
        if(look.kind==40) {
            let usize at=s.begin;
            if(locals::find(source,names,s.begin,s.end)!=64) {return .err(errors::make(3,at));}
            let usize target=functions::find(source,signatures,s.begin,s.end);
            if(target>=signatures.count || signatures.return_records[target]==0) {return .err(errors::make(3,at));}
            let usize nominal=(signatures.return_records[target] as usize)-1;
            var usize temporary=record_results::destination(signatures,target,nominal,false,p,names.function,at)?;
            let usize name=lexer::next(source,s)?;
            let usize called=call_value(source,s,p,names,signatures,target,144+temporary,at,depth+1,result_type,structure,loop_state)?;
            if(s.kind==46) {
                temporary=record_values::extracted_call_argument(source,s,p,names.function,temporary,record,at,ref signatures.context)?;
            } else if(nominal!=record) {return .err(errors::make(3,at));}
            if(s.kind!=44 && s.kind!=41) {return .err(errors::make(3,s.begin));}
            let usize captured=locals::declare(names,at,at,144+temporary,false)?;
            return .ok(144+temporary);
        }
    }
    return record_calls::capture(source,s,p,names,record);
}
// Array call results join the same lexical capture suffix as record results.
// A destination remains unnamed until CALL and delimiter validation succeed.
fn Result<usize,errors::Error> array_argument(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    u8 element,usize length,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state) {
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
    return array_calls::capture(source,s,p,names,element,length);
}
// A fresh literal or owned CALL result becomes a hidden owner before endpoints.
// Publishing the owner first makes every lexical exit close the view before DROP.
fn Result<slice_calls::Capture,errors::Error> slice_temporary(ref u8[] source,ref mut lexer::State s,
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
fn Result<usize,errors::Error> slice_argument(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    usize parameter,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    let usize reference=s.begin;
    let u8 encoded=slice_calls::prefix(source,s,signatures,parameter)?;
    var lexer::State look=lexer::snapshot(s);
    if((s.kind==2 || s.kind==5)){let usize next=lexer::next(source,ref mut look)?;}
    let slice_calls::Capture captured=if(s.kind==91 || ((s.kind==2 || s.kind==5) && look.kind==40)){
        slice_temporary(source,s,p,names,signatures,encoded,reference,depth,result_type,structure,loop_state)?
    }else{slice_calls::capture(source,s,p,names,encoded,reference)?};
    if(captured.root==16 && captured.parent==16){return .ok(captured.value);}
    let usize at=captured.offset;
    if(s.kind==44 || s.kind==41){
        let usize lo=ir::integer(p,0,12,at)?;
        let usize hi=arrays::length_value(p,captured.root,at)?;
        return slice_calls::range(p,names,ref captured,lo,hi);
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
    return slice_calls::range(p,names,ref captured,lo,hi);
}
// Image and universal view arguments join the same lexical suffix as native
// owner/loan captures before later arguments and their nonlocal exits execute.
fn Result<usize,errors::Error> reference_argument(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,ref functions::Table signatures,
    usize parameter,usize depth,u8 result_type,usize structure,ref mut loops::State loop_state){
    if(!reference_calls::image_argument(source,s,names)? && !reference_calls::returned_atom(source,s,names,signatures)?){
        return slice_argument(source,s,p,names,signatures,parameter,depth,result_type,structure,loop_state);
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
// All result kinds share argument evaluation and capture cleanup. Destinations
// 0..15 are dead array sites, 16 is scalar, and 144..159 are dead record sites.
fn Result<usize,errors::Error> call_value(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref locals::Table table,ref functions::Table signatures,usize target,usize destination,usize at,
    usize depth,u8 result_type,usize structure,ref mut loops::State loop_state) {
    if(depth>32) {return .err(errors::make(4,at));}
    if(destination==16 && (signatures.return_lengths[target]!=0 || signatures.return_records[target]!=0)) {return .err(errors::make(3,at));}
    var bool plain=destination==16;var usize i=0;
    while(i<signatures.arities[target]){let usize parameter=target*8+i;
        if(signatures.param_slices[parameter] || signatures.param_lengths[parameter]!=0 || signatures.param_records[parameter]!=0){plain=false;}i+=1;
    }
    if(plain){return scalar_call(source,s,p,table,signatures,target,at,depth,result_type,structure,loop_state);}
    return captured_call(source,s,p,table,signatures,target,destination,at,depth,result_type,structure,loop_state);
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
    usize depth,u8 result_type,usize structure,ref mut loops::State loop_state) {
    if(depth>32) {return .err(errors::make(4,at));}
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
            let usize stable=call_prefix::stable(source,s,p,table,tag,length,record)?;
            if(stable==256){break;}arguments[arity]=stable;
        }else{
            arguments[arity]=expression(source,s,p,table,signatures,1,depth+1,tag,result_type,structure,loop_state)?;
            if(p.types[arguments[arity]]!=tag){return .err(errors::make(3,at));}
        }
        arity+=1;if(s.kind==41){break;}
        let usize comma=lexer::punctuation(source,s,44)?;if(s.kind==41){return .err(errors::make(2,s.begin));}
    }
    return captured_tail(source,s,p,table,signatures,target,destination,at,depth,result_type,structure,loop_state,ref mut arguments,arity,zero);
}
fn Result<usize,errors::Error> captured_tail(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref locals::Table table,ref functions::Table signatures,usize target,usize destination,usize at,
    usize depth,u8 result_type,usize structure,ref mut loops::State loop_state,ref mut usize[] arguments,usize first,usize zero){
    var locals::Table names=locals::snapshot(table);var usize arity=first;
    while(s.kind!=41) {
        if(arity>=8) {return .err(errors::make(4,s.begin));}
        let u8 tag=if(arity<signatures.arities[target]){signatures.param_types[target*8+arity]}else{0};
        let usize length=if(arity<signatures.arities[target]){signatures.param_lengths[target*8+arity]}else{0};
        let usize record=if(arity<signatures.arities[target]){signatures.param_records[target*8+arity] as usize}else{0};
        if(arity<signatures.arities[target] && signatures.param_slices[target*8+arity]) {
            arguments[arity]=if(reference_calls::parameter(signatures,target*8+arity)){
                reference_argument(source,s,p,ref mut names,signatures,target*8+arity,depth,result_type,structure,loop_state)?
            }else{slice_argument(source,s,p,ref mut names,signatures,target*8+arity,depth,result_type,structure,loop_state)?};
        }
        else if(record!=0) {arguments[arity]=record_argument(source,s,p,ref mut names,signatures,record-1,depth,result_type,structure,loop_state)?;}
        else if(length!=0) {arguments[arity]=array_argument(source,s,p,ref mut names,signatures,tag,length,depth,result_type,structure,loop_state)?;}
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
// Postfix propagation binds before unary and binary operators. The operand
// parser recurses through primary for unary operators, preserving that order.
fn Result<usize, errors::Error> primary(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state) {
    var usize value=operand(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state)?;
    while(s.kind==63) {
        let usize at=s.begin;
        let usize next=lexer::next(source,s)?;
        value=propagation::lower(p,table,value,result_type,at)?;
    }
    return .ok(value);
}
// Casts bind after unary/postfix work and before every binary operator.
fn Result<usize,errors::Error> converted(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,usize depth,u8 expected,u8 result_type, usize structure, ref mut loops::State loop_state) {
    let bool explicit=casts::follows(source,s)?;
    let u8 context=if(explicit) {0} else {expected};
    var usize value=primary(source,s,p,table,signatures,depth,context,result_type,structure,loop_state)?;
    while(word_is(source,s,b"as")) {
        let usize at=s.begin;
        let usize keyword=lexer::next(source,s)?;
        let u8 target=types::parse(source,s)?;
        value=ir::widen(p,value,target,at)?;
    }
    return .ok(value);
}
fn Result<usize, errors::Error> expression(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, u8 minimum, usize depth, u8 expected, u8 result_type, usize structure, ref mut loops::State loop_state) {
    if (depth > 32) { return .err(errors::make(4, s.begin)); }
    var usize left = converted(source,s,p,table,signatures,depth,expected,result_type,structure,loop_state)?;
    while (precedence(s.kind) >= minimum) {
        let u8 kind = s.kind;
        let u8 level = precedence(s.kind);
        let u8 operation = opcode(s.kind);
        let usize at = s.begin;
        let usize advanced = lexer::next(source, s)?;
        if (kind == 132 || kind == 133) {
            if (p.types[left] != 2) { return .err(errors::make(3, at)); }
            let usize slot = ir::slot(p, 2, at)?;
            let usize initial = ir::raw(p, 18, slot, left, 0, at)?;
            let usize jump = ir::raw(p, if (kind == 132) { 20 } else { 21 }, 0, left, 0, at)?;
            let usize right = expression(source,s,p,table,signatures,level + 1,depth + 1,expected,result_type,structure,loop_state)?;
            if (p.types[right] != 2) { return .err(errors::make(3, at)); }
            let usize stored = ir::raw(p, 18, slot, right, 0, at)?;
            let usize target = p.count;
            let usize patched = ir::patch(p, jump, target, at)?;
            left = ir::emit(p, 17, slot, 0, at)?;
            continue;
        }
        let u8 context=p.types[left];
        let usize right = expression(source,s,p,table,signatures,level + 1,depth + 1,context,result_type,structure,loop_state)?;
        if (!types::scalar(p.types[left]) || p.types[left] != p.types[right] || ((operation < 11 || operation > 12) && !types::integer(p.types[left]))) { return .err(errors::make(3, at)); }
        left = ir::emit(p, operation, left, right, at)?;
    }
    return .ok(left);
}

fn bool word_is(ref u8[] source, ref lexer::State s, ref u8[] word) {
    return s.kind == 2 && lexer::equal(source[s.begin..s.end], word);
}

fn Result<usize, errors::Error> array_copy_statement(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize index, usize at, usize id, u8 terminator, u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state) {
    if ((s.kind!=2 && s.kind!=5)) { return .err(errors::make(3, s.begin)); }
    let usize origin = locals::find(source, table, s.begin, s.end);
    var lexer::State look=lexer::snapshot(s);
    let usize advance=lexer::next(source,ref mut look)?;
    if(look.kind==40) {
        if(origin!=64) {return .err(errors::make(3,s.begin));}
        let usize target=functions::find(source,signatures,s.begin,s.end);
        let usize temporary=array_results::destination(signatures,target,p.arrays.elements[id],p.arrays.lengths[id],false,p,table.function,s.begin)?;
        let usize name=lexer::next(source,s)?;
        let usize called=call_value(source,s,p,table,signatures,target,temporary,at,expr_depth,result_type,structure,loop_state)?;
        let usize end=lexer::punctuation(source,s,terminator)?;
        let usize assigned=array_results::assigned(p,id,temporary,at)?;
        return .ok(index);
    }
    if (!arrays::binding(table, origin)) { return .err(errors::make(3, s.begin)); }
    let usize source_id = table.registers[origin] - 128;
    let usize next = lexer::next(source, s)?;
    let usize end_statement = lexer::punctuation(source, s, terminator)?;
    let usize assigned = arrays::assign(p, id, source_id, at)?;
    return .ok(index);
}

fn Result<usize, errors::Error> array_write_statement(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize index, usize at, usize id, u8 terminator, u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state) {
    if (s.kind != 91) { return .err(errors::make(3, at)); }
    let usize open = lexer::punctuation(source, s, 91)?;
    let usize subscript = expression(source,s,p,table,signatures,1,expr_depth+1,12,result_type,structure,loop_state)?;
    if (p.types[subscript] != 12) { return .err(errors::make(3, at)); }
    let usize close = lexer::punctuation(source, s, 93)?;
    let usize equals = lexer::punctuation(source, s, 61)?;
    let u8 element = p.arrays.elements[id];
    let usize value = expression(source,s,p,table,signatures,1,expr_depth,element,result_type,structure,loop_state)?;
    if (p.types[value] != element) { return .err(errors::make(3, at)); }
    let usize end_statement = lexer::punctuation(source, s, terminator)?;
    let usize written = ir::array_write(p, id, subscript, value, at)?;
    return .ok(index);
}

// Keep array-only lowering out of recursive scalar statement frames.
fn Result<usize, errors::Error> array_statement(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures, usize index, usize at, u8 terminator, u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state) {
    // For headers remain scalar-only; never use an array binding as a
    // scalar register in the header/post validation paths.
    if (result_type == 0) { return .err(errors::make(3, at)); }
    let usize id = table.registers[index] - 128;
    if (slices::borrowed(table,p,id)) { return .err(errors::make(3,at)); }
    if (s.kind == 61) {
        let usize equals = lexer::next(source, s)?;
        if(s.kind==91) {
            let u8 element=p.arrays.elements[id];
            let usize open=lexer::next(source,s)?;
            let usize value=expression(source,s,p,table,signatures,1,expr_depth,element,result_type,structure,loop_state)?;
            let usize filled=arrays::refill(source,s,p,table.function,id,value,at)?;
            return .ok(index);
        }
        return array_copy_statement(source,s,p,table,signatures,index,at,id,terminator,result_type,expr_depth,structure,loop_state);
    }
    return array_write_statement(source,s,p,table,signatures,index,at,id,terminator,result_type,expr_depth,structure,loop_state);
}

// Field calls publish only an anonymous returned root. Snapshot it and release
// its owner before evaluating siblings; the parent destination is still pending.
fn Result<usize, errors::Error> record_child_call(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures,
    ref mut record_values::Initializer state, ref mut usize[] slots, usize first,
    usize at, u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state) {
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
    let usize called=call_value(source,s,p,table,signatures,target,144+temporary,at,expr_depth+2,result_type,structure+1,loop_state)?;
    let usize copied=record_values::stage_call_child(source,s,p,state,slots,first,temporary,at,ref signatures.context)?;
    let usize dropped=ir::record_drop(p,temporary,at)?;
    return .ok(copied);
}

// Shared declaration/replacement/return staging: finish every RHS expression before
// consecutive scalar loads. No destination owner or bytes change here.
fn Result<usize, errors::Error> record_constructor(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures,
    usize record, usize at, u8 result_type, usize expr_depth, usize structure,
    ref mut loops::State loop_state) {
    return record_constructor_value(source,s,p,table,signatures,record,at,result_type,expr_depth,structure,loop_state,false);
}
// Argument constructors leave ',' or ')' to the outer call; statement forms
// retain their semicolon contract. Neither publishes an owner while staging.
fn Result<usize, errors::Error> record_constructor_value(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures,
    usize record, usize at, u8 result_type, usize expr_depth, usize structure,
    ref mut loops::State loop_state, bool argument) {
    let usize leaves = record_values::leaf_count(p,record,at)?;
    var usize[16] slots = [0; 16]; var usize i = 0;
    var record_values::Initializer state = record_values::initializer(record);
    i = 0;
    while (i < leaves) {
        let u8 tag = record_values::next_leaf(source,s,p,ref mut state,at,ref signatures.context)?;
        if (tag == 255) {
            if (record_values::shorthand(ref state)) {
                record_values::rewind_shorthand(s,ref state);
                record_values::consumed_shorthand(ref mut state);
            }
            let usize called=record_child_call(source,s,p,table,signatures,ref mut state,ref mut slots,i,at,result_type,expr_depth,structure,loop_state)?;
            if(called!=0) {i+=called;continue;}
            let usize copied = record_values::stage_child(source,s,p,table,ref mut state,ref mut slots,i,at,ref signatures.context)?;
            i += copied; continue;
        }
        if (record_values::shorthand(ref state)) {
            record_values::rewind_shorthand(s,ref state);
            record_values::consumed_shorthand(ref mut state);
        }
        slots[i] = ir::slot(p,tag,at)?;
        let usize value = expression(source,s,p,table,signatures,1,expr_depth+2,tag,result_type,structure+1,loop_state)?;
        if (p.types[value] != tag) { return .err(errors::make(3,at)); }
        let usize store = ir::raw(p,18,slots[i],value,0,at)?; i += 1;
        let usize member = record_values::advance(source,s,p,ref mut state)?;
    }
    let u8 closed = record_values::next_leaf(source,s,p,ref mut state,at,ref signatures.context)?;
    if (closed != 0) { return .err(errors::make(3,at)); }
    if(argument) {
        if(s.kind!=44 && s.kind!=41) {return .err(errors::make(3,s.begin));}
    } else {let usize end=lexer::punctuation(source,s,59)?;}
    let usize first = p.registers; i = 0;
    while (i < leaves) { let usize loaded = ir::emit(p,17,slots[i],0,at)?; i += 1; }
    return .ok(first);
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
    let usize record=header.record;let bool mutable=header.mutable;
    if((s.kind==2 || s.kind==5)) {
        var lexer::State look=lexer::snapshot(s);
        let usize next=lexer::next(source,ref mut look)?;
        if(look.kind==40) {
            if(locals::find(source,table,s.begin,s.end)!=64) {return .err(errors::make(3,s.begin));}
            let usize at=s.begin;let usize target=functions::find(source,signatures,s.begin,s.end);
            if(target>=signatures.count || signatures.return_records[target]==0) {return .err(errors::make(3,at));}
            let usize nominal=(signatures.return_records[target] as usize)-1;
            var usize id=record_results::destination(signatures,target,nominal,mutable,p,table.function,at)?;
            let usize name=lexer::next(source,s)?;
            // Pending destinations remain invisible during all argument effects.
            let usize value=call_value(source,s,p,table,signatures,target,144+id,at,expr_depth,result_type,structure,loop_state)?;
            if(s.kind==46) {
                id=record_values::extracted_call(source,s,p,table.function,id,record,mutable,at,false,ref signatures.context)?;
            } else {
                if(nominal!=record) {return .err(errors::make(3,at));}
                let usize end=lexer::punctuation(source,s,terminator)?;
            }
            return locals::declare(table,header.begin,header.end,144+id,mutable);
        }
    }
    if (!record_values::constructor(source,s,record,ref signatures.context)?) { return record_values::copy(source,s,p,table,header,ref signatures.context); }
    let usize first = record_constructor(source,s,p,table,signatures,record,header.begin,result_type,expr_depth,structure,loop_state)?;
    let usize id = ir::record_in(p,table.function,record,mutable,header.begin)?;
    let usize init = ir::record_init(p,id,first,header.begin)?;
    return locals::declare(table,header.begin,header.end,144+id,mutable);
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
    usize index,usize at,u8 terminator,u8 result_type,usize depth,usize structure,ref mut loops::State loop_state) {
    let usize site=table.registers[index]-160;
    if(result_type==0 || !ir::exclusive(p,site) || s.kind!=91) { return .err(errors::make(3,at)); }
    let usize open=lexer::next(source,s)?;
    let usize subscript=expression(source,s,p,table,signatures,1,depth+1,12,result_type,structure,loop_state)?;
    if(p.types[subscript]!=12) { return .err(errors::make(3,at)); }
    let usize close=lexer::punctuation(source,s,93)?;let usize equals=lexer::punctuation(source,s,61)?;
    let u8 element=ir::slice_element(p,site,at)?;
    let usize value=expression(source,s,p,table,signatures,1,depth,element,result_type,structure,loop_state)?;
    if(p.types[value]!=element) { return .err(errors::make(3,at)); }
    let usize end=lexer::punctuation(source,s,terminator)?;
    let usize written=ir::slice_write(p,site,subscript,value,at)?;
    return .ok(index);
}
fn Result<usize,errors::Error> inferred_declaration(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,
    bool mutable,u8 terminator,u8 result_type,usize expr_depth,usize structure,ref mut loops::State loop_state){
    let inference::Header name=inference::header(source,s,table)?;
    let reference_inference::Shape view=reference_inference::inspect(source,s,p,table,signatures)?;
    if(view.kind!=0){
        return inferred_reference(source,s,p,table,signatures,name,view,mutable,terminator,result_type,expr_depth,structure,loop_state);
    }
    if(s.kind==91){
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
    let usize value=expression(source,s,p,table,signatures,1,expr_depth,0,result_type,structure,loop_state)?;
    let usize end=lexer::punctuation(source,s,terminator)?;
    return inference::bind(p,table,name,value,mutable,result_type==0);
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
    let usize open=lexer::punctuation(source,s,91)?;
    if(s.kind==93){return .err(errors::make(3,s.begin));}
    var vec::Vec<usize> values=vec::empty<usize>();var u8 element=expected;
    while(true){
        if(vec::len<usize>(ref values)>=4096 || p.list_used>4096 ||
            vec::len<usize>(ref values)>=4096-p.list_used){return .err(errors::make(4,s.begin));}
        let usize at=s.begin;
        let usize value=expression(source,s,p,table,signatures,1,depth,element,result_type,structure,loop_state)?;
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
    return array_locals::list(p,table.function,vec::view_usize(ref values),element,length,mutable,offset);
}
fn Result<usize, errors::Error> declaration(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 terminator, u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state) {
    if (word_is(source, s, b"let") || word_is(source, s, b"var")) {
        let bool mutable = word_is(source, s, b"var");
        let usize keyword = lexer::next(source, s)?;
        if(inference::follows(source,s)?){
            return inferred_declaration(source,s,p,table,signatures,mutable,terminator,result_type,expr_depth,structure,loop_state);
        }
        if (word_is(source,s,b"ref")) {
            if(signatures.literals.enabled && (static_source::candidate(source,s,table)? || reference_calls::declaration(source,s,table,signatures)?)){
                return static_declaration(source,s,p,table,signatures,mutable,terminator,result_type,expr_depth,structure,loop_state);
            }
            return slice_declaration(source,s,p,table,signatures,mutable,terminator,result_type,expr_depth,structure,loop_state);
        }
        if ((s.kind==2 || s.kind==5) && !locals::reserved(source[s.begin..s.end])) {
            return record_declaration(source,s,p,table,signatures,mutable,terminator,result_type,expr_depth,structure,loop_state);
        }
        let u8 tag = types::parse(source, s)?;
        let usize length = if (s.kind == 91) { arrays::length(source, s)? } else { 0 };
        if (length != 0 && (result_type == 0 ||
            terminator != 59 || !types::scalar(tag))) { return .err(errors::make(3, s.begin)); }
        if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) {
            return .err(errors::make(2, s.begin));
        }
        let usize begin = s.begin;
        let usize end = s.end;
        if (locals::find(source, table, begin, end) != 64) { return .err(errors::make(3, begin)); }
        if (table.count >= 64) { return .err(errors::make(4, begin)); }
        let usize name = lexer::next(source, s)?;
        let usize equals = lexer::punctuation(source, s, 61)?;
        if(length!=0){
            let inference::Header binding=inference::Header{.begin=begin,.end=end};
            return array_initializer(source,s,p,table,signatures,binding,tag,length,mutable,terminator,result_type,expr_depth,structure,loop_state);
        }
        // The new name is not visible until its initializer has been checked.
        let usize value = expression(source,s,p,table,signatures,1,expr_depth,tag,result_type,structure,loop_state)?;
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
fn Result<bool, errors::Error> record_call_assignment(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table table, ref functions::Table signatures,
    usize id, record_values::Leaf leaf, bool whole, usize at, u8 result_type,
    usize expr_depth, usize structure, ref mut loops::State loop_state) {
    var lexer::State look=lexer::snapshot(s);
    if(whole) {let usize equals=lexer::next(source,ref mut look)?;}
    if(look.kind!=2 && look.kind!=5) {return .ok(false);}
    var lexer::State call=lexer::snapshot(ref look);
    let usize next=lexer::next(source,ref mut call)?;
    if(call.kind!=40) {return .ok(false);}
    if(!p.records.mutable[id] || locals::find(source,table,look.begin,look.end)!=64) {return .err(errors::make(3,look.begin));}
    let usize target=functions::find(source,signatures,look.begin,look.end);
    if(target>=signatures.count || signatures.return_records[target]==0) {return .err(errors::make(3,look.begin));}
    let usize nominal=(signatures.return_records[target] as usize)-1;
    let usize temporary=record_results::destination(signatures,target,nominal,false,p,table.function,look.begin)?;
    if(whole) {let usize equals=lexer::next(source,s)?;}
    let usize name=lexer::next(source,s)?;
    let usize called=call_value(source,s,p,table,signatures,target,144+temporary,at,expr_depth,result_type,structure,loop_state)?;
    if(s.kind==46) {
        let usize assigned=record_values::assign_call_part(source,s,p,id,temporary,leaf,at,ref signatures.context)?;
        return .ok(true);
    }
    if(nominal!=leaf.record) {return .err(errors::make(3,at));}
    let usize end=lexer::punctuation(source,s,59)?;
    if(whole) {let usize assigned=record_results::assigned(p,id,temporary,at)?;}
    else {let usize assigned=record_results::subassigned(p,id,temporary,leaf,at)?;}
    return .ok(true);
}

fn Result<usize, errors::Error> record_write_statement(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p,
    ref locals::Table table, ref functions::Table signatures, usize index, usize at, u8 terminator,
    u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state) {
    if (result_type == 0 || terminator != 59) { return .err(errors::make(3, at)); }
    let usize id = table.registers[index] - 144;
    let usize record = p.records.records[id] as usize;
    if (s.kind == 61) {
        var lexer::State look = lexer::snapshot(s);
        let usize equals = lexer::next(source,ref mut look)?;
        let record_values::Leaf root=record_values::Leaf{.ordinal=0,.tag=0,.record=record};
        if(record_call_assignment(source,s,p,table,signatures,id,root,true,at,result_type,expr_depth,structure,loop_state)?) {return .ok(index);}
        if (record_values::constructor(source,ref mut look,record,ref signatures.context)?) {
            if (!p.records.mutable[id]) { return .err(errors::make(3,at)); }
            let usize consumed = lexer::next(source,s)?;
            let bool opened = record_values::constructor(source,s,record,ref signatures.context)?;
            let usize first = record_constructor(source,s,p,table,signatures,record,at,result_type,expr_depth,structure,loop_state)?;
            let usize replaced = ir::record_replace(p,id,first,record,at)?;
            return .ok(index);
        }
        let usize assigned = record_values::assign(source,s,p,table,id,at,ref signatures.context)?;
        return .ok(index);
    }
    let record_values::Leaf leaf = record_values::writable(source,s,p,id,at,ref signatures.context)?;
    if (leaf.tag == 0) {
        if(record_call_assignment(source,s,p,table,signatures,id,leaf,false,at,result_type,expr_depth,structure,loop_state)?) {return .ok(index);}
        if (record_values::constructor(source,s,leaf.record,ref signatures.context)?) {
            let usize first = record_constructor(source,s,p,table,signatures,leaf.record,at,result_type,expr_depth,structure,loop_state)?;
            let usize replaced = ir::record_subreplace(p,id,first,leaf.record,leaf.ordinal,at)?;
            return .ok(index);
        }
        let usize assigned = record_values::assign_part(source,s,p,table,id,leaf,at,ref signatures.context)?;
        return .ok(index);
    }
    let u8 tag = leaf.tag;
    let usize value = expression(source,s,p,table,signatures,1,expr_depth,tag,result_type,structure,loop_state)?;
    if (p.types[value] != tag) { return .err(errors::make(3, at)); }
    let usize end = lexer::punctuation(source,s,59)?;
    let usize written = ir::record_write(p,id,leaf.ordinal,value,at)?;
    return .ok(index);
}

fn Result<usize, errors::Error> statement(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 terminator, u8 result_type, usize expr_depth, usize structure, ref mut loops::State loop_state) {
    if (word_is(source, s, b"let") || word_is(source, s, b"var")) {
        return declaration(source,s,p,table,signatures,terminator,result_type,expr_depth,structure,loop_state);
    }
    if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) {
        return .err(errors::make(2, s.begin));
    }
    let usize at = s.begin;
    let usize index = locals::find(source, table, s.begin, s.end);
    if (index == 64 || !table.mutable[index]) { return .err(errors::make(3, at)); }
    let usize target = lexer::next(source, s)?;
    if (record_values::binding(table, index)) {
        return record_write_statement(source,s,p,table,signatures,index,at,terminator,result_type,expr_depth,structure,loop_state);
    }
    if (arrays::binding(table, index)) {
        return array_statement(source,s,p,table,signatures,index,at,terminator,result_type,expr_depth,structure,loop_state);
    }
    if (slices::binding(table,index)) {
        return slice_write_statement(source,s,p,table,signatures,index,at,terminator,result_type,expr_depth,structure,loop_state);
    }
    let usize equals = lexer::punctuation(source, s, 61)?;
    let u8 target_type=p.types[table.registers[index]];
    let usize value = expression(source,s,p,table,signatures,1,expr_depth,target_type,result_type,structure,loop_state)?;
    if (p.types[value] != target_type) { return .err(errors::make(3, at)); }
    let usize end_statement = lexer::punctuation(source, s, terminator)?;
    let usize stored = ir::raw(p, 18, table.registers[index], value, 0, at)?;
    return .ok(index);
}

// Value arms have a private binding table; assignments still address the
// original outer var slots. Their final expression has no trailing semicolon.
struct Yield {usize value; bool terminal;}
fn Result<Yield,errors::Error> value_arm(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,ref mut locals::Table table,ref functions::Table signatures,usize depth,u8 expected,u8 result_type, usize structure, ref mut loops::State loop_state) {
    if(depth>32 || structure>32) {return .err(errors::make(4,s.begin));}
    let usize brace=lexer::punctuation(source,s,123)?;
    let usize outer=table.count;
    while(true) {
        var bool regular=word_is(source,s,b"let") || word_is(source,s,b"var");
        if(!regular && s.kind==2 && !locals::reserved(source[s.begin..s.end])) {
            var lexer::State look=lexer::snapshot(s);
            let usize next=lexer::next(source,ref mut look)?;
            regular=look.kind==61 || (look.kind==91 && arrays::indexed_assignment(source, ref look)?) ||
                (look.kind==46 && record_values::assigned(source, ref look)?);
        }
        // A leading switch remains the final expression. Wrap a statement
        // switch in a standalone block to make that statement intent explicit.
        let bool structured=s.kind==123 || word_is(source,s,b"if") || word_is(source,s,b"while") ||
            word_is(source,s,b"for") || word_is(source,s,b"return") ||
            word_is(source,s,b"break") || word_is(source,s,b"continue");
        if(!regular && !structured) {break;}
        let bool terminal=control(source,s,p,table,signatures,result_type,structure,depth,loop_state)?;
        if(terminal) {
            let usize close=lexer::punctuation(source,s,125)?;
            return .ok(Yield {.value=0,.terminal=true});
        }
    }
    let usize value=expression(source,s,p,table,signatures,1,depth,expected,result_type,structure,loop_state)?;
    let usize dropped=arrays::release_from(table,p,outer,s.begin)?;
    let usize close=lexer::punctuation(source,s,125)?;
    return .ok(Yield {.value=value,.terminal=false});
}
fn Result<usize,errors::Error> switch_value(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,ref locals::Table table,ref functions::Table signatures,usize depth,u8 expected,u8 result_type, usize structure, ref mut loops::State loop_state) {
    let usize at=s.begin;
    if(depth>30 || structure>30) {return .err(errors::make(4,at));}
    // Statement-bearing arms are excluded from the pure for-header subset.
    if(result_type==0) {return .err(errors::make(3,at));}
    let usize keyword=lexer::next(source,s)?;
    let usize open=lexer::punctuation(source,s,40)?;
    let usize subject=expression(source,s,p,table,signatures,1,depth+1,0,result_type,structure+1,loop_state)?;
    let u8 tag=p.types[subject];
    if(!types::tagged(tag)) {return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,41)?;
    let usize brace=lexer::punctuation(source,s,123)?;
    var usize slot=128;
    var usize[2] skips=[256;2];
    var usize previous=256;
    var u8 first_variant=2;
    var usize arm=0;
    while(arm<2) {
        if(s.kind==125) {return .err(errors::make(3,at));}
        let patterns::Pattern pattern=patterns::parse(source,s,tag)?;
        if(arm==1 && pattern.variant==first_variant) {return .err(errors::make(3,at));}
        if(arm==0) {first_variant=pattern.variant;}
        else {
            let usize target=p.count;
            let usize next=ir::patch(p,previous,target,at)?;
        }
        let ir::Case branch=ir::branch_case(p,subject,pattern.variant,at)?;
        var locals::Table names=locals::snapshot(table);
        if(pattern.binding) {
            if(locals::find(source,ref names,pattern.begin,pattern.end)!=64) {return .err(errors::make(3,pattern.begin));}
            let usize binding=locals::declare(ref mut names,pattern.begin,pattern.end,branch.payload,false)?;
        }
        let u8 context=if(slot==128) {expected} else {p.types[slot]};
        let Yield yield=value_arm(source,s,p,ref mut names,signatures,depth+2,context,result_type,structure+2,loop_state)?;
        if(!yield.terminal) {
            if(slot==128) {
                let u8 tag=p.types[yield.value];
                slot=ir::slot(p,tag,at)?;
            }
            else if(p.types[yield.value]!=p.types[slot]) {return .err(errors::make(3,at));}
            let usize stored=ir::raw(p,18,slot,yield.value,0,at)?;
            skips[arm]=ir::raw(p,19,0,0,0,at)?;
        }
        previous=branch.instruction;
        arm+=1;
    }
    let usize end=lexer::punctuation(source,s,125)?;
    if(slot==128) {return .err(errors::make(3,at));}
    let usize failure=ir::raw(p,25,0,0,0,at)?;
    let usize guarded=ir::patch(p,previous,failure,at)?;
    let usize target=p.count;
    arm=0;
    while(arm<2) {
        if(skips[arm]!=256) {let usize skip=ir::patch(p,skips[arm],target,at)?;}
        arm+=1;
    }
    return ir::emit(p,17,slot,0,at);
}

// Validate the post clause before the body (body locals are not visible), then
// rewind only its appended IR. Re-emission after the body preserves source order.
// A dead post is still type checked, but consumes no runtime registers or Fuel.
fn Result<usize, errors::Error> checked_post(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, usize expr_depth, usize structure, ref mut loops::State loop_state) {
    let usize at=s.begin;
    if (word_is(source,s,b"let") || word_is(source,s,b"var")) {return .err(errors::make(2,at));}
    let usize code=p.count;
    let usize registers=p.registers;
    let usize constants=p.constant_count;
    let usize calls=p.call_count;
    let usize post=statement(source,s,p,table,signatures,41,0,expr_depth,structure,loop_state)?;
    if (p.call_count!=calls || !types::scalar(p.types[table.registers[post]])) {return .err(errors::make(3,at));}
    var usize r=registers;
    while(r<p.registers) {p.slots[r]=false; p.types[r]=0; r+=1;}
    // Extended instructions carry nonzero range bytes. Clear the discarded
    // region before body emission can reuse it for ordinary scalar operations.
    var usize discarded=code*8;let usize end=p.count*8;
    while(discarded<end){p.code[discarded]=0;discarded+=1;}
    p.count=code; p.registers=registers; p.constant_count=constants;
    return .ok(post);
}

fn Result<bool, errors::Error> block(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state) {
    if (depth > 32) { return .err(errors::make(4, s.begin)); }
    let usize open = lexer::punctuation(source, s, 123)?;
    let usize outer = table.count;
    var bool terminal = false;
    while (s.kind != 125) {
        if (s.kind == 0 || terminal) { return .err(errors::make(2, s.begin)); }
        terminal = control(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state)?;
    }
    if (!terminal) { let usize dropped = arrays::release_from(table, p, outer, s.begin)?; }
    table.count = outer;
    let usize close = lexer::next(source, s)?;
    return .ok(terminal);
}
// Keep unrelated statement scratch out of recursive dispatcher frames.
fn Result<bool, errors::Error> control(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state) {
    if (depth > 32) { return .err(errors::make(4, s.begin)); }
    if (word_is(source,s,b"break") || word_is(source,s,b"continue")) {
        return control_transfer(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state);
    }
    if (word_is(source,s,b"switch")) {
        return control_switch(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state);
    }
    if (word_is(source,s,b"for")) {
        return control_for(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state);
    }
    if (word_is(source,s,b"while")) {
        return control_while(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state);
    }
    if (word_is(source, s, b"return")) {
        return control_return(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state);
    }
    if (word_is(source, s, b"if")) {
        return control_if(source,s,p,table,signatures,result_type,depth,expr_depth,loop_state);
    }
    if (s.kind == 123) { return block(source,s,p,table,signatures,result_type,depth + 1,expr_depth,loop_state); }
    let usize regular = statement(source,s,p,table,signatures,59,result_type,expr_depth,depth,loop_state)?;
    return .ok(false);
}

fn Result<bool, errors::Error> control_transfer(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state) {
    let usize at = s.begin;
    let bool leave=word_is(source,s,b"break");
    let usize keyword=lexer::next(source,s)?;
    let usize end=lexer::punctuation(source,s,59)?;
    if (loop_state.depth == 0) { return .err(errors::make(2,at)); }
    let usize dropped=arrays::release_from(table,p,loop_state.bindings[loop_state.depth-1],at)?;
    let usize jump=loops::transfer(loop_state,p,leave,at)?;
    return .ok(true);
}

fn Result<bool, errors::Error> control_switch(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state) {
    let usize at = s.begin;
    let usize keyword=lexer::next(source,s)?;
    let usize open=lexer::punctuation(source,s,40)?;
    let usize subject=expression(source,s,p,table,signatures,1,expr_depth,0,result_type,depth,loop_state)?;
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
        let bool stopped=block(source,s,p,table,signatures,result_type,depth+2,expr_depth,loop_state)?;
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

fn Result<bool, errors::Error> control_for(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state) {
    let usize at = s.begin;
    let usize outer=table.count;
    let usize keyword=lexer::next(source,s)?;
    let usize open=lexer::punctuation(source,s,40)?;
    let usize calls=p.call_count;
    if (s.kind==59) {let usize empty=lexer::next(source,s)?;}
    else {
        let usize init=statement(source,s,p,table,signatures,59,0,expr_depth,depth,loop_state)?;
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
    if (has_post) {let usize validated=checked_post(source,s,p,table,signatures,expr_depth,depth,loop_state)?;}
    else {let usize empty=lexer::next(source,s)?;}
    let usize level=loops::enter(loop_state,head,true,at)?;
    loop_state.bindings[level]=table.count;
    let bool stopped=block(source,s,p,table,signatures,result_type,depth+1,expr_depth,loop_state)?;
    let usize post_target=p.count;
    let usize continues=loops::resolve(loop_state,p,false,post_target,at)?;
    if (!stopped || continues!=0) {
        if (has_post) {
            var lexer::State post=source_context::state(source,ref signatures.context,post_start)?;
            let usize first=lexer::next(source,ref mut post)?;
            let usize emitted=statement(source,ref mut post,p,table,signatures,41,0,expr_depth,depth,loop_state)?;
        }
        let usize back=ir::raw(p,22,0,head,0,at)?;
    }
    let usize target=p.count;
    let usize branch=ir::patch(p,exit,target,at)?;
    let usize breaks=loops::resolve(loop_state,p,true,target,at)?;
    loop_state.depth-=1; table.count=outer;
    return .ok(false);
}

fn Result<bool, errors::Error> control_while(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state) {
    let usize at = s.begin;
    let usize keyword=lexer::next(source,s)?;
    let usize open=lexer::punctuation(source,s,40)?;
    let usize head=p.count;
    let usize level=loops::enter(loop_state,head,false,at)?;
    loop_state.bindings[level]=table.count;
    let usize condition=expression(source,s,p,table,signatures,1,expr_depth,2,result_type,depth,loop_state)?;
    if (p.types[condition]!=2) {return .err(errors::make(3,at));}
    let usize close=lexer::punctuation(source,s,41)?;
    let usize exit=ir::raw(p,20,0,condition,0,at)?;
    let bool stopped=block(source,s,p,table,signatures,result_type,depth+1,expr_depth,loop_state)?;
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
    let usize end=lexer::punctuation(source,s,59)?;var usize i=table.count;
    while(i>0){i-=1;if(table.registers[i]!=192+value.site){let usize closed=arrays::release_at(table,p,i,at)?;}}
    let usize returned=ir::raw(p,79,0,value.site,0,at)?;return .ok(true);
}
fn Result<bool, errors::Error> control_return(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state) {
    let usize at = s.begin;
    let usize keyword = lexer::next(source, s)?;
    if(reference_calls::result(signatures,table.function)){
        return reference_return(source,s,p,table,signatures,at,depth,expr_depth,loop_state);
    }
    if(signatures.return_slice_elements[table.function]!=0){
        return slice_origin_return(source,s,p,table,signatures,at,depth,expr_depth,loop_state);
    }
    if(p.record_results[table.function]!=0) {
        if((s.kind==2 || s.kind==5)) {
            var lexer::State look=lexer::snapshot(s);
            let usize next=lexer::next(source,ref mut look)?;
            if(look.kind==123) {
                let usize shape=(p.record_results[table.function] as usize)-1;
                let usize record=p.records.records[shape] as usize;
                let bool constructor=record_values::constructor(source,s,record,ref signatures.context)?;
                let usize first=record_constructor(source,s,p,table,signatures,record,at,result_type,expr_depth,depth,loop_state)?;
                // Publish no name or owner while field expressions can leave.
                let usize id=ir::record_in(p,table.function,record,false,at)?;
                let usize init=ir::record_init(p,id,first,at)?;
                let usize returned=record_results::finish(p,table,id,at)?;
                return .ok(true);
            }
            if(look.kind==40) {
                if(locals::find(source,table,s.begin,s.end)!=64) {return .err(errors::make(3,s.begin));}
                let usize target=functions::find(source,signatures,s.begin,s.end);
                let usize shape=(p.record_results[table.function] as usize)-1;
                if(target>=signatures.count || signatures.return_records[target]==0) {return .err(errors::make(3,s.begin));}
                let usize record=p.records.records[shape] as usize;
                let usize nominal=(signatures.return_records[target] as usize)-1;
                var usize id=record_results::destination(signatures,target,nominal,false,p,table.function,s.begin)?;
                let usize name=lexer::next(source,s)?;
                let usize called=call_value(source,s,p,table,signatures,target,144+id,at,expr_depth,result_type,depth,loop_state)?;
                if(s.kind==46) {
                    id=record_values::extracted_call(source,s,p,table.function,id,record,false,at,false,ref signatures.context)?;
                } else {
                    if(nominal!=record || s.kind!=59) {return .err(errors::make(3,s.begin));}
                    let usize end=lexer::next(source,s)?;
                }
                let usize returned=record_results::finish(p,table,id,at)?;
                return .ok(true);
            }
        }
        let usize returned=record_results::returned(source,s,p,table,at,ref signatures.context)?;
        return .ok(true);
    }
    if(p.array_results[table.function]!=0) {
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
    let usize value = expression(source,s,p,table,signatures,1,expr_depth,result_type,result_type,depth,loop_state)?;
    if (p.types[value] != result_type) { return .err(errors::make(3, at)); }
    let usize end = lexer::punctuation(source, s, 59)?;
    let usize dropped = arrays::release_visible(table, p, at)?;
    let usize returned = ir::emit(p, 8, value, 0, at)?;
    return .ok(true);
}

fn Result<bool, errors::Error> control_if(ref u8[] source, ref mut lexer::State s, ref mut ir::Program p, ref mut locals::Table table, ref functions::Table signatures, u8 result_type, usize depth, usize expr_depth, ref mut loops::State loop_state) {
    let usize at = s.begin;
    let usize keyword = lexer::next(source, s)?;
    let usize open = lexer::punctuation(source, s, 40)?;
    let usize condition = expression(source,s,p,table,signatures,1,expr_depth,2,result_type,depth,loop_state)?;
    if (p.types[condition] != 2) { return .err(errors::make(3, at)); }
    let usize close = lexer::punctuation(source, s, 41)?;
    let usize branch = ir::raw(p, 20, 0, condition, 0, at)?;
    let bool then_returns = block(source,s,p,table,signatures,result_type,depth + 1,expr_depth,loop_state)?;
    if (word_is(source, s, b"else")) {
        var usize skip = 256;
        if (!then_returns) { skip = ir::raw(p, 19, 0, 0, 0, at)?; }
        let usize else_start = p.count;
        let usize patched = ir::patch(p, branch, else_start, at)?;
        let usize else_word = lexer::next(source, s)?;
        let bool else_returns = if (word_is(source, s, b"if")) {
            control(source,s,p,table,signatures,result_type,depth + 1,expr_depth,loop_state)?
        } else { block(source,s,p,table,signatures,result_type,depth + 1,expr_depth,loop_state)? };
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

fn Result<usize, errors::Error> body(ref u8[] source, ref functions::Table signatures, usize f, ref mut ir::Program p) {
    var locals::Table table = locals::empty();
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
        let usize parameter = if(reference_calls::parameter(signatures,at)){reference_calls::bind(signatures,at,p,ref mut table)?}
            else if(signatures.param_slices[at]){slice_calls::bind(signatures,at,p,ref mut table)?}
            else if(signatures.param_records[at]!=0){record_calls::bind(signatures,at,p,ref mut table)?}
            else{array_calls::bind(signatures,at,p,ref mut table)?};
        i += 1;
    }
    var lexer::State s=source_context::state(source,ref signatures.context,signatures.bodies[f])?;
    let usize first = lexer::next(source, ref mut s)?;
    var loops::State loop_state=loops::empty();
    let u8 result_context=if(reference_calls::result(signatures,f)){12}else{record_results::context(p,f)};
    var bool terminal = false;
    while (s.kind != 125) {
        if (terminal || s.kind == 0) { return .err(errors::make(2, s.begin)); }
        terminal = control(source,ref mut s,p,ref mut table,signatures,result_context,0,0,ref mut loop_state)?;
    }
    if (!terminal) { return .err(errors::make(2, s.begin)); }
    if (s.kind != 125 || s.begin != signatures.body_ends[f]) { return .err(errors::make(2, s.begin)); }
    let usize end = p.count;
    let usize registers_end = p.registers;
    p.ends[f] = end;
    p.register_ends[f] = registers_end;
    return .ok(f);
}

// Release source-name/catalog scratch before recursive expression lowering.
fn Result<usize, errors::Error> prepare_aggregates(ref u8[] source, ref mut functions::Table signatures, ref mut ir::Program p) {
    let usize parameters = array_calls::prepare(signatures, p)?;
    let usize results = array_results::prepare(signatures, p)?;
    let structs::Table records = if(signatures.context.modules==0){structs::scan(source)?}
        else{structs::scan_scoped(source,ref signatures.context)?};
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
fn Result<usize, errors::Error> lower_into(ref u8[] source,bool origin_analysis,bool references,bool returns,ref literal_collection::Index literals,ref mut ir::Program p) {
    if (source.len > 4096) { return .err(errors::make(4, 4096)); }
    let ref str valid = switch (text::validate_utf8(source)) {
        case .ok(value): { value } case .err(_): { return .err(errors::make(1, 0)); }
    };
    var functions::Table signatures = lowering_signatures(source,returns)?;
    var usize active=16;
    return lower_prepared(source,origin_analysis,references,returns,literals,ref mut signatures,p,ref mut active);
}
fn Result<usize,errors::Error> lower_prepared(ref u8[] source,bool origin_analysis,bool references,bool returns,
    ref literal_collection::Index literals,ref mut functions::Table signatures,ref mut ir::Program p,ref mut usize active){
    signatures.literals=*literals;signatures.reference_calls=references;
    // Signature candidates do not prove a returned borrow's origin or lifetime.
    // Reject every such declaration, including unreachable functions, before
    // Program/result preparation can mistake it for an ordinary scalar result.
    var usize declaration = 0;
    while (declaration < signatures.count) {
        if (!origin_analysis && signatures.return_slice_elements[declaration] != 0 && !reference_calls::result(signatures,declaration)) {
            return .err(errors::make(3, signatures.begins[declaration]));
        }
        declaration += 1;
    }
    if(origin_analysis || returns){let usize inferred=source_origins::infer(source,signatures)?;}
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
    let usize aggregates = prepare_aggregates(source, signatures, p)?;
    var usize f = 0;
    while (f < signatures.count) {
        if(signatures.context.modules!=0){
            *active=switch(source_context::location(source,ref signatures.context,signatures.begins[f])){
                case .ok(v):{v.source}case .err(_):{return .err(errors::make(5,signatures.begins[f]));}
            };
        }
        let usize emitted = body(source, signatures, f, p)?;
        f += 1;
    }
    *active=16;
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
    let usize lowered=lower_into(source,false,false,false,ref literals,ref mut p)?;
    return .ok(p);
}
// The analysis Program stays private and is never returned to an executor.
pub fn Result<slice_origins::Summary,errors::Error> inspect_slice_results(ref u8[] source){
    var ir::Program p=ir::empty();
    let literal_collection::Index literals=literal_collection::empty();
    let usize lowered=lower_into(source,true,false,false,ref literals,ref mut p)?;
    let functions::Table signatures=functions::scan(source)?;
    let slice_result_ir::Program unit=slice_result_ir::from_proxy(p,ref signatures)?;
    let slice_result_verifier::Proof checked=slice_result_verifier::inspect(ref unit)?;
    return .ok(slice_origins::Summary{.parameters=checked.parameters,.rounds=checked.rounds});
}

// Non-executable returned-view IR. Public compile retains its declaration gate.
pub fn Result<slice_result_ir::Program,errors::Error> inspect_slice_result_ir(ref u8[] source){
    var ir::Program p=ir::empty();
    let literal_collection::Index literals=literal_collection::empty();
    let usize lowered=lower_into(source,true,false,false,ref literals,ref mut p)?;
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
    switch(lower_into(source,false,false,false,ref literals,ref mut body)){
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
    switch(lower_into(source,false,true,false,ref literals,ref mut body)){
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
    var static_images::Builder builder=switch(static_images::builder(4096)){
        case .ok(v):{v}case .err(e):{return .err(image_literal_error(e));}
    };
    var reference_ir::Program code=reference_ir::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    let usize lowered=lower_reference_returns(source,ref mut builder,ref mut code)?;
    return finish_reference_returns(ref builder,ref code,image_limit);
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
    switch(lower_into(source,false,true,true,ref literals,ref mut code.body)){
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
    return switch(compile_reference_returns(source,image_limit)){
        case .ok(p):{.ok(program_images::retain_public_references(p))}
        case .err(e):{.err(public_error(e))}
    };
}
fn Result<program_images::PublicProgram,errors::Error> compile_public_legacy(ref u8[] source){
    var ir::Program code=ir::empty();
    let literal_collection::Index literals=literal_collection::empty();
    let usize lowered=lower_into(source,false,false,false,ref literals,ref mut code)?;
    return switch(program_images::retain_public_legacy(ref code)){
        case .ok(v):{.ok(v)}case .err(e):{.err(public_error(e))}
    };
}

// Candidate lowering only. Rebuild all compiler scratch from the exact retained
// selection; callers must independently admit the complete IR and image.
pub fn Result<bool,source_errors::Error> lower_modules(ref module_entries::Entry selected,
    ref mut static_images::Builder builder,ref mut reference_ir::Program code){
    let source_context::Input input=switch(source_context::collect(module_entries::index(selected))){
        case .ok(v):{v}case .err(e):{return .err(source_errors::Error{.code=errors::make(5,e.at.start),.at=e.at});}
    };
    let ref u8[] data=ref input.data;let ref u8[] source=data[..input.used];
    let ref source_context::Table scope=ref input.context;
    let bool retained=switch(source_features::retained_scoped(source,scope)){
        case .ok(v):{v}case .err(e):{return .err(module_error(selected,e,16));}
    };
    if(retained){let usize lowered=lower_module_references(source,scope,selected,builder,code)?;}
    else{let literal_collection::Index literals=literal_collection::empty();var usize active=16;
        switch(lower_module(source,scope,selected,false,ref literals,ref mut code.body,ref mut active)){
            case .ok(_):{}case .err(e):{return .err(module_error(selected,e,active));}
        };
    }return .ok(retained);
}
fn source_errors::Error module_error(ref module_entries::Entry selected,errors::Error error,usize active){
    return if(error.offset==0){source_errors::absent(error)}else{source_errors::map(module_index::snapshot(module_entries::index(selected)),error,active)};
}
fn Result<usize,errors::Error> lower_module(ref u8[] source,ref source_context::Table scope,
    ref module_entries::Entry selected,bool references,ref literal_collection::Index literals,ref mut ir::Program code,ref mut usize active){
    var functions::Table signatures=functions::scan_scoped(source,scope,selected,references)?;
    return lower_prepared(source,false,references,references,literals,ref mut signatures,code,active);
}
fn Result<usize,source_errors::Error> lower_module_references(ref u8[] source,ref source_context::Table scope,
    ref module_entries::Entry selected,ref mut static_images::Builder builder,ref mut reference_ir::Program code){
    let literal_collection::Index literals=switch(literal_collection::collect_scoped(builder,source,scope)){
        case .ok(v):{v}case .err(e):{return .err(module_error(selected,public_error(switch(e.kind){
            case .Source:{image_source_error(e.source)}case .Image:{image_literal_error(e.image)}
        }),16));}
    };
    var usize active=16;
    switch(lower_module(source,scope,selected,true,ref literals,ref mut code.body,ref mut active)){
        case .ok(_):{}case .err(e):{return .err(module_error(selected,e,active));}
    };
    return module_reference_signature(source,scope,selected,code);
}
fn Result<usize,source_errors::Error> module_reference_signature(ref u8[] source,ref source_context::Table scope,
    ref module_entries::Entry selected,ref mut reference_ir::Program code){
    var functions::Table signatures=switch(functions::scan_scoped(source,scope,selected,true)){
        case .ok(v):{v}case .err(e):{return .err(module_error(selected,e,16));}
    };
    switch(source_origins::infer(source,ref mut signatures)){case .ok(_):{}case .err(e):{return .err(module_error(selected,e,16));}};
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
