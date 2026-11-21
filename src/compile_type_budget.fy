module compile_type_budget;
import ir as ir;
import array_meta as arrays;
import struct_layout as records;
import types as types;

struct Count { bool[143] seen; usize used; }

fn void add(ref mut Count count,u8 tag){
    if(!count.seen[tag as usize]){count.seen[tag as usize]=true;count.used+=1;}
}
fn void value(ref mut Count count,u8 tag){
    if(types::valid(tag)){
        add(count,tag);
        if(types::tagged(tag)){
            let u8 success=types::payload(tag,1);
            let u8 failure=types::payload(tag,0);
            add(count,success);
            if(failure!=0){add(count,failure);}
        }
    }else if(types::host_result_type(tag)){
        add(count,tag);
        add(count,tag-128);
        add(count,11);
    }
}

fn void array_types(ref mut Count count,ref arrays::Catalog catalog){
    var usize i=0;
    while(i<catalog.count){
        let u8 element=catalog.elements[i];
        let usize length=catalog.lengths[i];
        add(count,element);
        var usize prior=0;
        while(prior<i && (catalog.elements[prior]!=element || catalog.lengths[prior]!=length)){
            prior+=1;
        }
        if(prior==i){count.used+=1;}
        i+=1;
    }
}

// One namespace for scalar and wrapper tags. Nominal declarations have
// separate identities even when every scalar field has the same type.
pub fn bool fits(ref ir::Program code,ref u8[] reference_returns,usize limit){
    // The scalar, wrapper and nominal bound is 52, plus the occupied array sites.
    if(limit>=52+code.arrays.count){return true;}
    let ref records::Catalog layouts=ref code.records.layouts;
    var Count count=Count{.seen=[false;143],.used=layouts.count};
    var usize r=0;
    while(r<code.registers){value(ref mut count,code.types[r]);r+=1;}
    var usize f=0;
    while(f<code.function_count){
        if(reference_returns.len==0 || reference_returns[f]==0){value(ref mut count,code.return_types[f]);}
        f+=1;
    }
    r=0;
    while(r<layouts.count){
        var usize i=0;
        while(i<layouts.fields[r] as usize){
            let usize field=r*16+i;
            if(layouts.kinds[field]==0){value(ref mut count,layouts.types[field]);}
            i+=1;
        }
        r+=1;
    }
    array_types(ref mut count,ref code.arrays);
    return count.used<=limit;
}
