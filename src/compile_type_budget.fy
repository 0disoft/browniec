module compile_type_budget;
import ir as ir;
import array_meta as arrays;
import struct_layout as records;
import types as types;

struct Count { bool[143] seen; usize used; usize views; }

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

fn void view(ref mut Count count,usize key){
    let usize one=1;let usize bit=one<<key;
    if((count.views&bit)==0){count.views|=bit;count.used+=1;}
}
fn void slice_type(ref mut Count count,u8 element,bool exclusive){
    add(count,element);
    view(count,element as usize+if(exclusive){16}else{0});
}
fn bool view_types(ref mut Count count,ref ir::Program code,ref u8[] static_kinds){
    var usize site=0;
    while(site<16){
        if(code.slice_roots[site]!=0 || code.slice_origins[site]!=0){
            let u8 element=switch(ir::slice_element(code,site,0)){
                case .ok(v):{v}case .err(_):{return false;}
            };
            slice_type(count,element,ir::exclusive(code,site));
        }
        site+=1;
    }
    site=0;
    while(site<static_kinds.len){
        let u8 kind=static_kinds[site];
        if(kind==1 || kind==3){slice_type(count,10,false);}
        else if(kind==2){view(count,32);}
        site+=1;
    }
    return true;
}

// One namespace for scalar and wrapper tags. Nominal declarations have
// separate identities even when every scalar field has the same type.
pub fn bool fits(ref ir::Program code,ref u8[] reference_returns,ref u8[] static_kinds,usize limit){
    // 52 scalar/wrapper/nominal identities plus 12 scalar views and one text view.
    if(limit>=65+code.arrays.count){return true;}
    let ref records::Catalog layouts=ref code.records.layouts;
    var Count count=Count{.seen=[false;143],.used=layouts.count,.views=0};
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
    return view_types(ref mut count,code,static_kinds) && count.used<=limit;
}
