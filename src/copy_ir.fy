module copy_ir;

import ir as ir;
import errors as errors;
import runtime_clock as clock;
import aggregate_copy as windows;
import array_layout as arrays;
import struct_layout as records;
import struct_range as ranges;
import slice_verifier as loans;

// Derived from immutable IR, never supplied by the compiler or a guest. Relative
// windows describe nominal values; native storage still authenticates actual
// tokens, generations, backing bounds, bools and reservations before publication.
pub enum Domain { Array; Record; }
pub struct Plan {
    Domain domain; windows::Mode mode; windows::Relation relation;
    usize destination; usize source; usize bytes;
    usize destination_offset; usize source_offset; bool fresh; bool same_frame;
}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
pub fn bool operation(u8 op){return op==34 || op==38 || op==42 || op==46 || op==47;}

// Shared operand proof for selected aggregate STOREs. These derive a strategy;
// the caller must still prove current live owners/loans and SELECT identity.
pub fn Result<Plan,errors::Error> array_assignment(ref ir::Program p,usize dst,usize source,usize f,usize pc){
    if(p.function_count>16 || f>=p.function_count){return .err(invalid(pc));}
    return array(p,dst,source,f,f,false,true,pc);
}
pub fn Result<Plan,errors::Error> record_assignment(ref ir::Program p,usize dst,usize source,
    usize nominal,usize destination_leaf,usize source_leaf,usize f,usize pc){
    if(p.function_count>16 || f>=p.function_count){return .err(invalid(pc));}
    return record(p,dst,source,f,f,false,true,true,nominal,destination_leaf,source_leaf,pc);
}

fn Result<Plan,errors::Error> array(ref ir::Program p,usize dst,usize source,
    usize destination_function,usize source_function,bool fresh,bool same_frame,usize pc){
    if(p.arrays.count>16 || dst>=p.arrays.count || source>=p.arrays.count ||
        p.array_functions[dst] as usize!=destination_function ||
        p.array_functions[source] as usize!=source_function ||
        p.arrays.elements[dst]!=p.arrays.elements[source] ||
        p.arrays.lengths[dst]!=p.arrays.lengths[source] || (!fresh && !p.arrays.mutable[dst])){
        return .err(invalid(pc));
    }
    let arrays::Array shape=switch(arrays::scalar(p.arrays.elements[dst],p.arrays.lengths[dst])){
        case .ok(v):{v}case .err(_):{return .err(invalid(pc));}
    };
    let bool identical=same_frame && !fresh && dst==source;
    return .ok(Plan{.domain=.Array,.mode=if(identical){.NoOp}else{.Direct},
        .relation=if(identical){.Identical}else{.Disjoint},.destination=dst,.source=source,
        .bytes=shape.bytes,.destination_offset=0,.source_offset=0,.fresh=fresh,.same_frame=same_frame});
}
fn Result<Plan,errors::Error> record(ref ir::Program p,usize dst,usize source,
    usize destination_function,usize source_function,bool fresh,bool same_frame,
    bool subtree,usize nominal,usize destination_leaf,usize source_leaf,usize pc){
    if(p.records.count>16 || dst>=p.records.count || source>=p.records.count ||
        p.record_functions[dst] as usize!=destination_function ||
        p.record_functions[source] as usize!=source_function || (!fresh && !p.records.mutable[dst])){
        return .err(invalid(pc));
    }
    let records::Plan shapes=switch(records::plan(ref p.records.layouts,18446744073709551615)){
        case .ok(v):{v}case .err(_):{return .err(invalid(pc));}
    };
    let usize target=p.records.records[dst] as usize;let usize origin=p.records.records[source] as usize;
    let usize selected=if(subtree){nominal}else{target};
    if(target>=shapes.count || origin>=shapes.count || selected>=shapes.count ||
        shapes.bytes[target]>128 || shapes.bytes[origin]>128 || shapes.bytes[selected]>128 ||
        (!subtree && target!=origin)){return .err(invalid(pc));}
    let usize to=switch(ranges::offset_prepared(ref p.records.layouts,ref shapes,target,selected,destination_leaf)){
        case .ok(v):{v}case .err(_):{return .err(invalid(pc));}
    };
    let usize from=switch(ranges::offset_prepared(ref p.records.layouts,ref shapes,origin,selected,source_leaf)){
        case .ok(v):{v}case .err(_):{return .err(invalid(pc));}
    };
    let usize size=shapes.bytes[selected];
    var windows::Relation relation=.Disjoint;
    if(same_frame && !fresh && dst==source){
        relation=switch(windows::relation(to,from,size,shapes.bytes[target])){
            case .ok(v):{v}case .err(_):{return .err(invalid(pc));}
        };
    }
    // Complete staging also normalizes padding on identical record windows.
    return .ok(Plan{.domain=.Record,.mode=.Snapshot,.relation=relation,
        .destination=dst,.source=source,.bytes=size,.destination_offset=to,.source_offset=from,
        .fresh=fresh,.same_frame=same_frame});
}
pub fn Result<Plan,errors::Error> instruction(ref ir::Program p,usize pc,usize f){
    if(p.count>256 || pc>=p.count || p.function_count>16 || f>=p.function_count ||
        pc<p.starts[f] || pc>=p.ends[f] || p.ends[f]>p.count){return .err(invalid(pc));}
    let usize at=pc*8;let u8 op=p.code[at];
    if(!operation(op)){return .err(invalid(pc));}
    if(p.code[at+6]!=0 || p.code[at+7]!=0 ||
        (op!=47 && (p.code[at+3]!=0 || p.code[at+4]!=0 || p.code[at+5]!=0))){return .err(invalid(pc));}
    let usize dst=p.code[at+1] as usize;let usize source=p.code[at+2] as usize;
    if(op==34 || op==38){return array(p,dst,source,f,f,op==34,true,pc);}
    return record(p,dst,source,f,f,op==42,true,op==47,p.code[at+3] as usize,
        p.code[at+4] as usize,p.code[at+5] as usize,pc);
}
fn bool is_record(ref Plan plan){return switch(plan.domain){case .Array:{false}case .Record:{true}};}
fn usize bit(ref Plan plan,usize site){let usize one=1;return one<<(site+if(is_record(plan)){16}else{0});}
fn bool formal(ref ir::Program p,usize f,ref Plan plan){
    var usize arg=0;while(arg<p.arities[f]){
        let usize r=p.register_starts[f]+arg;
        let usize encoded=if(is_record(plan)){p.record_parameters[r] as usize}else{p.array_parameters[r] as usize};
        if(encoded==plan.destination+1){return true;}arg+=1;
    }return false;
}
// Canonical scalar/owner/loan CFG supplies its exact live state on every path.
// Copy lifetime checks consume that state and return the resulting owner set;
// joins/backedges retain the canonical exact-set invariant, with no second graph.
pub fn Result<usize,errors::Error> step(ref ir::Program p,usize pc,usize f,usize live){
    let Plan plan=instruction(p,pc,f)?;
    if(p.arities[f]>8 || p.register_starts[f]>128 || p.arities[f]>128-p.register_starts[f]){return .err(invalid(pc));}
    let usize destination=bit(ref plan,plan.destination);let usize source=bit(ref plan,plan.source);
    if((live&source)==0 || if(plan.fresh){(live&destination)!=0 || formal(p,f,ref plan)}else{(live&destination)==0}){
        return .err(invalid(pc));
    }
    if(!is_record(ref plan) && (loans::exclusive(p,plan.source,live) ||
        loans::exclusive(p,plan.destination,live) || (!plan.fresh && loans::borrowed(p,plan.destination,live)))){
        return .err(invalid(pc));
    }
    return .ok(if(plan.fresh){live|destination}else{live});
}
// Every by-value CALL argument names a new owner in a distinct activation,
// including recursive calls with equal static source/destination catalog IDs.
pub fn Result<Plan,errors::Error> argument(ref ir::Program p,usize target,usize parameter,
    usize encoded_source,usize caller,usize live,usize pc){
    if(p.function_count>16 || target>=p.function_count || caller>=p.function_count ||
        p.arities[target]>8 || p.register_starts[target]>128 || p.arities[target]>128-p.register_starts[target] ||
        parameter<p.register_starts[target] || parameter>=p.register_starts[target]+p.arities[target]){return .err(invalid(pc));}
    let usize record_parameter=p.record_parameters[parameter] as usize;
    if(record_parameter!=0){
        if(record_parameter>p.records.count || encoded_source<144 || encoded_source>=160 ||
            p.array_parameters[parameter]!=0 || p.slice_parameters[parameter]!=0){return .err(invalid(pc));}
        let Plan plan=record(p,record_parameter-1,encoded_source-144,target,caller,true,false,false,0,0,0,pc)?;
        if(p.records.mutable[plan.destination] || p.records.mutable[plan.source] ||
            (live&bit(ref plan,plan.source))==0){return .err(invalid(pc));}return .ok(plan);
    }
    let usize array_parameter=p.array_parameters[parameter] as usize;
    if(array_parameter==0 || array_parameter>p.arrays.count || encoded_source<128 || encoded_source>=144 ||
        p.slice_parameters[parameter]!=0){return .err(invalid(pc));}
    let Plan plan=array(p,array_parameter-1,encoded_source-128,target,caller,true,false,pc)?;
    if(p.arrays.mutable[plan.destination] || p.arrays.mutable[plan.source] ||
        (live&bit(ref plan,plan.source))==0 || loans::exclusive(p,plan.source,live)){return .err(invalid(pc));}
    return .ok(plan);
}
// Canonical whole-Program validation calls this after function partition proof.
// Unreachable copies receive the same domain/shape/reserved-byte checks.
pub fn Result<usize,errors::Error> metadata(ref ir::Program p){
    return metadata_until(p,0);
}
pub fn Result<usize,errors::Error> metadata_until(ref ir::Program p,usize deadline){
    if(p.count>256 || p.function_count>16){return .err(invalid(0));}
    var usize f=0;var usize count=0;
    while(f<p.function_count){
        if(p.starts[f]>=p.ends[f] || p.ends[f]>p.count){return .err(invalid(0));}
        var usize pc=p.starts[f];
        while(pc<p.ends[f]){
            if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
            if(operation(p.code[pc*8])){
                let Plan plan=instruction(p,pc,f)?;
                count+=1;
            }
            pc+=1;
        }
        f+=1;
    }
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    return .ok(count);
}
