module slice_parameters;
import ir as ir;
import errors as errors;
import types as types;

// Exact scalar borrow signatures. No scalar value or owned-array shape is implied.
fn bool formal(ref ir::Program p, usize r, usize site, usize f) {
    return r < 128 && r < p.registers && site < 16 && f < p.function_count && f < 16 &&
        p.slice_parameters[r] as usize == site + 1 && p.slice_roots[site] == 0 &&
        p.slice_origins[site] as usize == site + 1 && p.slice_functions[site] as usize == f + 1 && types::scalar(ir::borrow_element(p,site)) &&
        p.arities[f] <= 8 && p.register_starts[f] <= r && p.register_ends[f] <= p.registers &&
        r < p.register_ends[f] && r - p.register_starts[f] < p.arities[f] &&
        p.types[r] == 0 && !p.slots[r] && p.array_parameters[r] == 0 && p.record_parameters[r] == 0;
}

pub fn Result<usize, errors::Error> metadata(ref ir::Program p) {return metadata_mode(p,false);}
// Generic byte InputEntry is proved by the caller's separate complete static
// signature pass. It must not manufacture an ordinary array-backed formal.
pub fn Result<usize,errors::Error> metadata_input(ref ir::Program p){return metadata_mode(p,true);}
fn Result<usize,errors::Error> metadata_mode(ref ir::Program p,bool input) {
    if (p.function_count == 0 || p.function_count > 16 || p.entry >= p.function_count ||
        p.registers > 128 || p.arrays.count > 16) { return .err(errors::make(5, 0)); }
    if(input){
        if(p.arities[p.entry]!=1 || p.register_starts[p.entry]>=128 || p.slice_parameters[p.register_starts[p.entry]]!=0){return .err(errors::make(5,0));}
    }else if(p.arities[p.entry]!=0){return .err(errors::make(5,0));}
    var usize end = 0;
    var usize f = 0;
    while (f < p.function_count) {
        if (p.register_starts[f] != end || p.register_ends[f] < end || p.register_ends[f] > p.registers ||
            p.arities[f] > 8 || p.arities[f] > p.register_ends[f] - end) { return .err(errors::make(5, 0)); }
        end = p.register_ends[f]; f += 1;
    }
    if (end != p.registers) { return .err(errors::make(5, 0)); }
    var usize site = 0;
    while (site < 16) {
        let usize origin = p.slice_origins[site] as usize;
        let usize function = p.slice_functions[site] as usize;
        let usize root = p.slice_roots[site] as usize;
        if (ir::exclusive(p, site)) {
            if (root != 0) {
                if (root > p.arrays.count || !p.arrays.mutable[root - 1]) { return .err(errors::make(5, 0)); }
            } else if (!types::scalar(ir::borrow_element(p,site))) { return .err(errors::make(5, 0)); }
        }
        if (root > p.arrays.count || (root != 0 && (origin != 0 || function != 0)) ||
            (origin == 0 && (function != 0 || (p.slice_elements[site] != 0 && p.slice_elements[site] != 128)))) { return .err(errors::make(5, 0)); }
        if (origin != 0) {
            if (origin > 16 || function == 0 || function > p.function_count) { return .err(errors::make(5, 0)); }
            let usize anchor = origin - 1;
            if (p.slice_roots[anchor] != 0 || p.slice_origins[anchor] as usize != origin ||
                p.slice_functions[anchor] as usize != function || !types::scalar(ir::borrow_element(p,site)) ||
                p.slice_elements[anchor] != p.slice_elements[site]) { return .err(errors::make(5, 0)); }
        }
        site += 1;
    }
    var usize seen = 0;
    let usize one = 1;
    var usize r = 0;
    while (r < 128) {
        let usize encoded = p.slice_parameters[r] as usize;
        if (encoded != 0) {
            if (encoded > 16) { return .err(errors::make(5, 0)); }
            site = encoded - 1;
            let usize function = p.slice_functions[site] as usize;
            if (function == 0 || !formal(p, r, site, function - 1) || (seen & (one << site)) != 0) { return .err(errors::make(5, 0)); }
            seen |= one << site;
        }
        r += 1;
    }
    site = 0;
    while (site < 16) {
        let usize origin = p.slice_origins[site] as usize;
        if (origin != 0 && (seen & (one << (origin - 1))) == 0) { return .err(errors::make(5, 0)); }
        site += 1;
    }
    return .ok(seen);
}

// Call after metadata validation. These masks describe future function entry.
pub fn Result<usize, errors::Error> initial(ref ir::Program p, usize f) {
    if (f >= p.function_count || f >= 16 || p.registers > 128 || p.arities[f] > 8 ||
        p.register_starts[f] > p.register_ends[f] || p.register_ends[f] > p.registers ||
        p.arities[f] > p.register_ends[f] - p.register_starts[f]) { return .err(errors::make(5, 0)); }
    let usize one = 1;
    var usize live = 0;
    var usize i = 0;
    while (i < p.arities[f]) {
        let usize r = p.register_starts[f] + i;
        let usize encoded = p.slice_parameters[r] as usize;
        if (encoded != 0) {
            if (encoded > 16 || !formal(p, r, encoded - 1, f)) { return .err(errors::make(5, 0)); }
            live |= one << (32 + encoded - 1);
        }
        i += 1;
    }
    return .ok(live);
}

// Call after metadata validation. CALL encodes slice sources as 160..175.
// A derived borrow needs its own live ticket, not a still-live parent anchor.
pub fn Result<usize, errors::Error> argument(ref ir::Program p, usize parameter,
    usize source, usize caller, usize live, usize at) {
    if (parameter >= 128 || parameter >= p.registers || source < 160 || source >= 176 ||
        caller >= p.function_count || caller >= 16) { return .err(errors::make(5, at)); }
    let usize encoded = p.slice_parameters[parameter] as usize;
    if (encoded == 0 || encoded > 16) { return .err(errors::make(5, at)); }
    let usize destination = encoded - 1;
    let usize function = p.slice_functions[destination] as usize;
    if (function == 0 || !formal(p, parameter, destination, function - 1)) { return .err(errors::make(5, at)); }
    let usize site = source - 160;
    // Private mutable CALL proof requires exact modes; it is not VM admission.
    // In particular, writers never coerce to shared borrows or vice versa.
    if (ir::exclusive(p, site) != ir::exclusive(p,destination)) { return .err(errors::make(5, at)); }
    let usize one = 1;
    if ((live & (one << (32 + site))) == 0) { return .err(errors::make(5, at)); }
    let usize origin = p.slice_origins[site] as usize;
    if (origin != 0) {
        if (origin > 16 || p.slice_functions[site] as usize != caller + 1 || p.slice_roots[site] != 0) { return .err(errors::make(5, at)); }
        let usize anchor = origin - 1;
        if (p.slice_origins[anchor] as usize != origin || p.slice_functions[anchor] as usize != caller + 1 ||
            p.slice_roots[anchor] != 0 || p.slice_elements[site] != p.slice_elements[anchor] ||
            p.slice_elements[site] != p.slice_elements[destination]) { return .err(errors::make(5, at)); }
    } else {
        let usize root = p.slice_roots[site] as usize;
        if (root == 0 || root > 16 || root > p.arrays.count || p.slice_functions[site] != 0) { return .err(errors::make(5, at)); }
        if (p.array_functions[root - 1] as usize != caller || p.arrays.elements[root - 1] != ir::borrow_element(p,destination) ||
            (ir::exclusive(p,site) && !p.arrays.mutable[root-1]) ||
            (live & (one << (root - 1))) == 0) { return .err(errors::make(5, at)); }
    }
    return .ok(site);
}

// Storage-independent shared byte formals have no ordinary slice placeholder.
// Reuse the canonical caller live word and root/formal ancestry after metadata
// proof. An image actual never passes through this runtime-loan branch.
pub fn Result<usize,errors::Error> shared_byte(ref ir::Program p,usize source,usize caller,usize live,usize at){
    if(source<160 || source>=176 || caller>=p.function_count || caller>=16){return .err(errors::make(5,at));}
    let usize site=source-160;let usize one=1;
    let u8 element=switch(ir::slice_element(p,site,at)){case .ok(v):{v}case .err(_):{return .err(errors::make(5,at));}};
    if(ir::exclusive(p,site) || element!=10 || (live&(one<<(32+site)))==0){return .err(errors::make(5,at));}
    let usize origin=p.slice_origins[site] as usize;let usize root=p.slice_roots[site] as usize;
    if(origin!=0){
        if(origin>16 || root!=0 || p.slice_functions[site] as usize!=caller+1){return .err(errors::make(5,at));}
        let usize anchor=origin-1;
        if(p.slice_roots[anchor]!=0 || p.slice_origins[anchor] as usize!=origin ||
            p.slice_functions[anchor] as usize!=caller+1 || p.slice_elements[anchor]!=p.slice_elements[site]){return .err(errors::make(5,at));}
    }else{
        if(root==0 || root>p.arrays.count || root>16 || p.slice_functions[site]!=0 ||
            p.array_functions[root-1] as usize!=caller || p.arrays.elements[root-1]!=10 ||
            (live&(one<<(root-1)))==0){return .err(errors::make(5,at));}
    }
    return .ok(site);
}
