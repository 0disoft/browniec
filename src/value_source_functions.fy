module value_source_functions;
import value_properties as properties;
import value_signature_source as signature;
import value_source_bindings as bindings;
import value_ir as values;
import functions as functions;
import locals as locals;
import lexer as lexer;
import types as scalar;
import errors as errors;

// Compile-only forward metadata. Entries are exact canonical node ID + 1;
// only a void result is zero. No IR slot or runtime authority is encoded here.
pub struct Plan { usize[16] results; usize[128] parameters; }
fn errors::Error invalid(usize at){return errors::make(3,at);}
fn Result<usize,errors::Error> inspected(ref properties::Catalog catalog,usize at){
    return switch(properties::inspect(catalog)){
        case .ok(p):{.ok(p.count)}case .err(e):{
            let u8 kind=switch(e){case .Metadata:{5}case .Type:{3}case .Depth:{4}case .Size:{4}};
            .err(errors::make(kind,at))
        }
    };
}
fn Result<usize,errors::Error> exact(ref properties::Catalog catalog,u8 tag,usize length,u8 record,
    bool result,usize at){
    if(tag==13 && result && length==0 && record==0){return .ok(0);}
    if(signature::typed(tag)){
        if(length!=0 || record!=0){return .err(invalid(at));}
        return .ok(signature::type_id(tag,catalog,at)?+1);
    }
    let u8 kind=if(record!=0){3}else if(length!=0){2}else{1};
    if((record!=0 && (tag!=0 || length!=0)) || (record==0 && !scalar::scalar(tag))){
        return .err(invalid(at));
    }
    let usize first=if(record!=0){(record as usize)-1}else{tag as usize};
    var usize i=0;while(i<catalog.count){let properties::Node n=catalog.nodes[i];
        if(n.kind==kind && n.first as usize==first && n.second==0 && n.extent==length){return .ok(i+1);}i+=1;
    }return .err(invalid(at));
}
pub fn Result<Plan,errors::Error> prepare(ref properties::Catalog catalog,ref functions::Table signatures){
    let usize checked=inspected(catalog,0)?;
    if(signatures.count>16){return .err(errors::make(4,0));}
    if(signatures.count==0 || signatures.entry>=signatures.count){return .err(invalid(0));}
    var Plan plan=Plan{.results=[0;16],.parameters=[0;128]};
    var usize f=0;while(f<16){
        if(f>=signatures.count){
            if(signatures.arities[f]!=0 || signatures.return_types[f]!=0 || signatures.return_lengths[f]!=0 ||
                signatures.return_records[f]!=0 || signatures.return_slice_elements[f]!=0){return .err(invalid(0));}
        }else{
            let usize at=signatures.begins[f];
            if(signatures.arities[f]>8){return .err(errors::make(4,at));}
            if(signatures.return_slice_elements[f]!=0 || signatures.return_slice_inputs[f]!=0 ||
                signatures.return_slice_candidates[f]!=0){return .err(invalid(at));}
            plan.results[f]=exact(catalog,signatures.return_types[f],signatures.return_lengths[f],
                signatures.return_records[f],true,at)?;
        }
        var usize i=0;while(i<8){let usize p=f*8+i;
            if(f>=signatures.count || i>=signatures.arities[f]){
                if(signatures.param_types[p]!=0 || signatures.param_lengths[p]!=0 || signatures.param_records[p]!=0 ||
                    signatures.param_slices[p] || signatures.param_slice_elements[p]!=0){return .err(invalid(0));}
            }else{
                if(signatures.param_slices[p] || signatures.param_slice_elements[p]!=0){
                    return .err(invalid(signatures.param_begins[p]));}
                plan.parameters[p]=exact(catalog,signatures.param_types[p],signatures.param_lengths[p],
                    signatures.param_records[p],false,signatures.param_begins[p])?;
            }i+=1;
        }f+=1;
    }
    let usize entry=signatures.entry;
    if(signatures.arities[entry]!=0 || signatures.return_types[entry]!=1 ||
        signatures.return_lengths[entry]!=0 || signatures.return_records[entry]!=0){
        return .err(invalid(signatures.begins[entry]));}
    return .ok(plan);
}
// Values written below are bounded to <=128 by the small-header preflight.
fn u8 byte(usize value){var u8 result=0;var usize i=0;while(i<value){result+=1;i+=1;}return result;}
// The caller discards the ENTIRE compiler candidate on any error. Preflight
// bounds/spans/types without copying the giant Program. Binder errors after
// publication may leave partial headers/slots/names; never resume that candidate.
// Parent installs ALL return_types before this call, including forward callees.
pub fn Result<usize,errors::Error> begin(ref mut values::Program unit,ref mut bindings::State state,
    ref u8[] source,ref functions::Table signatures,ref Plan plan,usize f){
    if(signatures.count==0 || signatures.count>16 || f>=signatures.count ||
        signatures.entry>=signatures.count || unit.body.function_count!=signatures.count ||
        unit.body.entry!=signatures.entry){return .err(invalid(0));}
    let usize at=signatures.begins[f];let usize arity=signatures.arities[f];
    if(arity>8 || unit.body.registers>128 || state.next>16 || unit.body.count>256){return .err(errors::make(4,at));}
    if(arity>128-unit.body.registers){return .err(errors::make(4,at));}
    if(state.names.count!=0 || state.live!=0 || state.names.pending_places!=0 || unit.results[f]!=0){return .err(invalid(at));}
    if((f==0 && (unit.body.count!=0 || unit.body.registers!=0)) ||
        (f!=0 && (unit.body.ends[f-1]!=unit.body.count || unit.body.register_ends[f-1]!=unit.body.registers ||
            state.names.function!=f-1))){return .err(invalid(at));}
    let usize checked=inspected(ref unit.catalog,at)?;
    let usize result=exact(ref unit.catalog,signatures.return_types[f],signatures.return_lengths[f],
        signatures.return_records[f],true,at)?;
    if(result!=plan.results[f] || signatures.return_slice_elements[f]!=0){return .err(invalid(at));}
    let bool typed=result!=0 && unit.catalog.nodes[result-1].kind!=1;
    let u8 tag=if(result==0){13}else if(typed){0}else{unit.catalog.nodes[result-1].first};
    if(unit.body.return_types[f]!=tag){return .err(invalid(at));}
    var usize needed=if(typed){1}else{0};var usize i=0;
    while(i<arity){let usize p=f*8+i;let usize begin=signatures.param_begins[p];let usize end=signatures.param_ends[p];
        if(signatures.param_slices[p] || signatures.param_slice_elements[p]!=0){return .err(invalid(begin));}
        let usize encoded=exact(ref unit.catalog,signatures.param_types[p],signatures.param_lengths[p],
            signatures.param_records[p],false,begin)?;
        if(encoded!=plan.parameters[p]){return .err(invalid(begin));}
        if(!lexer::simple(source,begin,end) || locals::reserved(source[begin..end])){return .err(errors::make(2,begin));}
        var usize j=0;while(j<i){let usize prior=f*8+j;
            if(lexer::equal(source[begin..end],source[signatures.param_begins[prior]..signatures.param_ends[prior]])){
                return .err(invalid(begin));}j+=1;
        }
        if(unit.catalog.nodes[encoded-1].kind!=1){needed+=1;}
        let usize r=unit.body.registers+i;
        if(unit.parameters[r]!=0 || unit.body.types[r]!=0 || unit.body.slots[r] ||
            unit.body.array_parameters[r]!=0 || unit.body.record_parameters[r]!=0 || unit.body.slice_parameters[r]!=0){
            return .err(invalid(begin));}i+=1;
    }
    if(needed>16-state.next){return .err(errors::make(4,at));}
    let usize entered=bindings::enter_function(unit,state,f,at)?;
    let usize start=unit.body.registers;
    let usize code_start=unit.body.count;
    unit.body.starts[f]=code_start;unit.body.register_starts[f]=start;unit.body.arities[f]=arity;
    unit.body.registers=start+arity;i=0;
    while(i<arity){let usize p=f*8+i;let usize r=start+i;let usize id=plan.parameters[p]-1;
        if(unit.catalog.nodes[id].kind==1){
            let u8 parameter_tag=unit.catalog.nodes[id].first;
            unit.body.types[r]=parameter_tag;unit.body.slots[r]=false;
            let usize index=locals::declare(ref mut state.names,signatures.param_begins[p],signatures.param_ends[p],r,false)?;
            state.bindings[index]=0;
        }else{
            let usize slot=bindings::allocate(unit,state,id,signatures.param_begins[p])?;
            let usize live=bindings::initialize(unit,state,slot,signatures.param_begins[p])?;
            let usize index=bindings::declare(unit,state,source,signatures.param_begins[p],signatures.param_ends[p],slot,id)?;
            unit.body.types[r]=0;unit.body.slots[r]=false;unit.parameters[r]=byte(slot+1);
        }i+=1;
    }
    if(typed){let usize anchor=bindings::allocate(unit,state,result-1,at)?;unit.results[f]=byte(anchor+1);}
    return .ok(f);
}
// Parent emits the terminal instruction/cleanup and clears all lexical names
// and live bits first. Finishing never rewinds the global typed-slot allocator.
pub fn Result<usize,errors::Error> finish(ref mut values::Program unit,ref bindings::State state,usize f,usize at){
    if(unit.body.function_count==0 || unit.body.function_count>16 || f>=unit.body.function_count ||
        state.names.function!=f || state.names.count!=0 || state.names.pending_places!=0 || state.live!=0){return .err(invalid(at));}
    if(unit.body.count>256 || unit.body.registers>128 || state.next>16){return .err(errors::make(4,at));}
    if(unit.body.count<=unit.body.starts[f] || unit.body.registers<unit.body.register_starts[f] ||
        unit.body.arities[f]>8 || unit.body.arities[f]>unit.body.registers-unit.body.register_starts[f]){return .err(invalid(at));}
    let usize code_end=unit.body.count;let usize registers_end=unit.body.registers;
    unit.body.ends[f]=code_end;unit.body.register_ends[f]=registers_end;return .ok(f);
}
