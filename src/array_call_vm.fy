module array_call_vm;

import ir as ir;
import errors as errors;
import array_vm as arrays;
import array_owners as owners;
import array_layout as layouts;
import array_meta as array_meta;
import std::bytes as bytes;

// Verified mixed CALLs retain their scalar charge. Array work is prepaid for
// table staging/commit, bounded descriptor scans, alignment and payload work.
pub fn Result<usize,errors::Error> cost(ref ir::Program p,usize target,usize offset) {
    let ref array_meta::Catalog catalog=ref p.arrays;
    var usize total=0; var usize arg=0;
    while(arg<p.arities[target]) {
        let usize encoded=p.array_parameters[p.register_starts[target]+arg] as usize;
        if(encoded!=0) {
            let usize id=encoded-1;
            let layouts::Array shape=switch(layouts::scalar(catalog.elements[id],catalog.lengths[id])) {
                case .ok(a):{a} case .err(_):{return .err(errors::make(5,offset));}
            };
            if(total==0) {total=128;}
            total+=128+shape.bytes+7+if(shape.element==2){shape.length}else{0};
        }
        arg+=1;
    }
    return .ok(total);
}
// Only verified CALLs enter here, after Fuel and frame admission. No scalar
// register or return-frame mutation occurs until this array transaction succeeds.
pub fn Result<usize,errors::Error> enter(ref ir::Program p,usize target,usize site,usize parent,
    ref mut arrays::State state,ref mut bytes::Buffer buffer,usize offset) {
    return enter_data(p,target,site,parent,state,bytes::view_mut(buffer),offset);
}
pub fn Result<usize,errors::Error> enter_data(ref ir::Program p,usize target,usize site,usize parent,
    ref mut arrays::State state,ref mut u8[] data,usize offset){
    var owners::Token[8] sources=[owners::Token{.slot=0,.generation=0};8];
    var layouts::Array[8] shapes=[layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0};8];
    var usize[8] destinations=[0;8];
    var usize count=0; var usize arg=0;
    while(arg<p.arities[target]) {
        let usize encoded=p.array_parameters[p.register_starts[target]+arg] as usize;
        if(encoded!=0) {
            if(parent>=31) {return .err(errors::make(12,offset));}
            let usize id=encoded-1;
            let usize destination=(parent+1)*16+id;
            if(state.tokens[destination].generation!=0) {return .err(errors::make(5,offset));}
            let usize source=(p.call_args[site*8+arg] as usize)-128;
            sources[count]=state.tokens[parent*16+source];
            shapes[count]=switch(layouts::scalar(p.arrays.elements[id],p.arrays.lengths[id])) {
                case .ok(a):{a} case .err(_):{return .err(errors::make(5,offset));}
            };
            destinations[count]=destination; count+=1;
        }
        arg+=1;
    }
    if(count==0) {return .ok(0);}
    let owners::Copies copies=switch(owners::copy_arguments(ref sources[..count],ref shapes[..count],data,ref mut state.owners)) {
        case .ok(c):{c} case .err(e):{return .err(arrays::failure(e,offset));}
    };
    arg=0;
    while(arg<count) {state.tokens[destinations[arg]]=copies.tokens[arg];arg+=1;}
    return .ok(count);
}
