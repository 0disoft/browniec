module array_parameters;

import ir as ir;
import errors as errors;
import register_set as registers;
import struct_parameters as records;
import slice_parameters as slices;
import copy_ir as copying;

// Called after catalog and function/register partitions have been verified.
pub fn Result<usize, errors::Error> metadata(ref ir::Program p) {
    var usize seen = 0;
    var usize r = 0;
    while (r < 128) {
        let usize encoded = p.array_parameters[r] as usize;
        if (encoded != 0) {
            if (r >= p.registers || encoded > p.arrays.count || p.slots[r] || p.record_parameters[r] != 0) { return .err(errors::make(5, 0)); }
            let usize id = encoded - 1;
            let usize one = 1;
            if ((seen & (one << id)) != 0 || p.arrays.mutable[id] || p.types[r] != p.arrays.elements[id]) { return .err(errors::make(5, 0)); }
            let usize f = p.array_functions[id] as usize;
            if (r < p.register_starts[f] || r >= p.register_starts[f] + p.arities[f]) { return .err(errors::make(5, 0)); }
            seen |= one << id;
        }
        r += 1;
    }
    return .ok(seen);
}
pub fn usize initial(ref ir::Program p, usize f) {
    var usize live = 0;
    var usize arg = 0;
    while (arg < p.arities[f]) {
        let usize encoded = p.array_parameters[p.register_starts[f] + arg] as usize;
        if (encoded != 0) { let usize one = 1; live |= one << (encoded - 1); }
        arg += 1;
    }
    return live;
}
pub fn Result<usize, errors::Error> arguments(ref ir::Program p, usize target, usize site, usize caller,
    ref registers::Set defined, usize live, usize pc) {
    let u8[1] empty=[0];return arguments_static(p,target,site,caller,defined,live,pc,ref empty[..0]);
}
// The complete image verifier has independently classified these Static positions.
// Ordinary scalar/array/record/loan positions retain the same canonical proof.
pub fn Result<usize, errors::Error> arguments_static(ref ir::Program p,usize target,usize site,usize caller,
    ref registers::Set defined,usize live,usize pc,ref u8[] statics){
    let usize count = p.call_arities[site] as usize;
    var usize arg = 0;
    var usize writers = 0; var usize writer_roots = 0; let usize one = 1;
    while (arg < 8) {
        let usize source = p.call_args[site * 8 + arg] as usize;
        if (arg < count) {
            let usize parameter = p.register_starts[target] + arg;
            let usize encoded = p.array_parameters[parameter] as usize;
            if(statics.len==128 && statics[parameter]!=0){
                if(statics[parameter]==3 && source>=160 && source<176){
                    let usize checked=slices::shared_byte(p,source,caller,live,pc)?;
                }
                arg+=1;continue;
            }
            if (p.slice_parameters[parameter] != 0) {
                let usize checked = slices::argument(p, parameter, source, caller, live, pc)?;
                if (ir::exclusive(p,checked)) {
                    let usize bit = one << checked;
                    let usize root = p.slice_roots[checked] as usize;
                    let usize root_bit = if(root==0){0}else{one << (root-1)};
                    // Shared duplicates remain legal. Each exclusive source and
                    // statically known owner root may appear only once per CALL.
                    if ((writers & bit)!=0 || (writer_roots & root_bit)!=0) { return .err(errors::make(5,pc)); }
                    writers |= bit; writer_roots |= root_bit;
                }
            } else if (p.record_parameters[parameter] != 0 || encoded != 0) {
                let copying::Plan checked=copying::argument(p,target,parameter,source,caller,live,pc)?;
            } else {
                if (source < p.register_starts[caller] || source >= p.register_ends[caller] ||
                    p.slots[source] || p.array_parameters[source] != 0 || p.record_parameters[source] != 0 || p.slice_parameters[source] != 0 || !registers::contains(defined, source) ||
                    p.types[source] != p.types[parameter]) { return .err(errors::make(5, pc)); }
            }
        } else if (source != 0) { return .err(errors::make(5, pc)); }
        arg += 1;
    }
    return .ok(count);
}
