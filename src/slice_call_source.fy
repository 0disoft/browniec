module slice_call_source;
import functions as functions;
import locals as locals;
import lexer as lexer;
import ir as ir;
import slice_source as slices;
import slice_builders as builders;
import errors as errors;
import array_source as arrays;

// Signature kinds are known before bodies; site/register IDs are assigned in
// body order. Forward calls need only the signature, never a future ticket.
pub fn Result<usize, errors::Error> bind(ref functions::Table signatures, usize at,
    ref mut ir::Program p, ref mut locals::Table names) {
    if (at >= 128 || !signatures.param_slices[at] || names.count >= 64) { return .err(errors::make(4, 0)); }
    let u8 encoded = signatures.param_slice_elements[at];
    let bool exclusive = (encoded & 128) != 0;
    let usize site = if (exclusive) { builders::parameter_exclusive(p, names.function, encoded & 127, signatures.param_begins[at])? }
        else { builders::parameter_typed(p, names.function, encoded, signatures.param_begins[at])? };
    return locals::declare(names, signatures.param_begins[at], signatures.param_ends[at], 160 + site, exclusive);
}

// A capture is ready when root==16. An owned range with root<16 is only a
// checked source descriptor: the compiler evaluates endpoints before OPEN.
pub struct Capture { usize value; usize root; bool exclusive; usize offset; }
// An owned whole-array argument opens an anonymous lexical handle at evaluation
// time. Existing CALL capture cleanup closes it after return or an argument exit.
fn Result<Capture,errors::Error> owned(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut locals::Table names,u8 element,bool exclusive,usize at){
    let usize index=locals::find(source,names,s.begin,s.end);
    if(names.count>=64){return .err(errors::make(4,at));}
    if(!arrays::binding(names,index)){return .err(errors::make(3,s.begin));}
    let usize root=names.registers[index]-128;
    if(exclusive && (!names.mutable[index] || !p.arrays.mutable[root])){return .err(errors::make(3,at));}
    let usize selected=slices::root_argument(source,s,p,names,element)?;
    if(s.kind==91){return .ok(Capture{.value=0,.root=selected,.exclusive=exclusive,.offset=at});}
    if(s.kind!=44 && s.kind!=41){return .err(errors::make(3,s.begin));}
    let usize lo=ir::integer(p,0,12,at)?;
    let usize hi=arrays::length_value(p,selected,at)?;
    let usize value=open(p,names,selected,lo,hi,exclusive,at)?;
    return .ok(Capture{.value=value,.root=16,.exclusive=exclusive,.offset=at});
}
// Endpoints have completed before this single acquisition/publication point.
pub fn Result<usize,errors::Error> open(ref mut ir::Program p,ref mut locals::Table names,
    usize root,usize lo,usize hi,bool exclusive,usize at){
    if(names.count>=64){return .err(errors::make(4,at));}
    let usize site=if(exclusive){ir::exclusive_slice(p,root,at)?}else{ir::slice(p,root,at)?};
    let usize opened=ir::slice_open(p,site,lo,hi,at)?;
    let usize anonymous=locals::declare(names,at,at,160+site,exclusive)?;
    return .ok(160+site);
}
// Explicit ref [mut] requires exact access and scalar element type. Named slices
// keep their existing ticket; owned arrays use a call-scoped anonymous handle.
// Keep signature-array indexing scratch off the recursive scalar CALL path.
pub fn Result<Capture, errors::Error> capture(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref mut locals::Table names, ref functions::Table signatures, usize parameter) {
    let usize at = s.begin;
    if (parameter >= 128 || !signatures.param_slices[parameter]) { return .err(errors::make(3, at)); }
    let u8 encoded = signatures.param_slice_elements[parameter];
    let u8 element = encoded & 127;
    let bool exclusive = (encoded & 128) != 0;
    if (s.kind != 2 || !lexer::equal(source[s.begin..s.end], b"ref")) { return .err(errors::make(3, at)); }
    let usize reference = lexer::next(source, s)?;
    if (exclusive) { let usize access = lexer::word(source, s, b"mut")?; }
    if (s.kind != 2) { return .err(errors::make(3, s.begin)); }
    let usize index = locals::find(source, names, s.begin, s.end);
    if(arrays::binding(names,index)){return owned(source,s,p,names,element,exclusive,at);}
    if (!slices::binding(names, index)) { return .err(errors::make(3, s.begin)); }
    let usize site = names.registers[index] - 160;
    if (ir::exclusive(p,site) != exclusive) { return .err(errors::make(3,at)); }
    let usize root = p.slice_roots[site] as usize;
    let usize origin = p.slice_origins[site] as usize;
    if (root != 0) {
        if (root > 16 || root > p.arrays.count || p.arrays.elements[root - 1] != element ||
            p.array_functions[root - 1] as usize != names.function || origin != 0 ||
            p.slice_functions[site] != 0) { return .err(errors::make(3, at)); }
    } else {
        if (origin == 0 || origin > 16 || p.slice_functions[site] as usize != names.function + 1 ||
            p.slice_roots[origin - 1] != 0 || p.slice_origins[origin - 1] as usize != origin ||
            p.slice_functions[origin - 1] != p.slice_functions[site]) { return .err(errors::make(3, at)); }
    }
    let u8 actual = ir::slice_element(p, site, at)?;
    if (actual != element) { return .err(errors::make(3, at)); }
    let usize name = lexer::next(source, s)?;
    if (s.kind != 44 && s.kind != 41) { return .err(errors::make(3, s.begin)); }
    return .ok(Capture{.value=160+site,.root=16,.exclusive=exclusive,.offset=at});
}
