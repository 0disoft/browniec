module compile_type_budget;
import ir as ir;
import array_meta as arrays;
import struct_layout as records;
import types as types;
import host_catalog as catalog;
import host_program as host;
import host_wire as wire;

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

fn usize upper_bound(ref ir::Program code){
    // 52 scalar/wrapper/nominal identities plus 12 scalar views and one text view.
    return 65+code.arrays.count;
}
pub fn bool fits(ref ir::Program code,ref u8[] reference_returns,ref u8[] static_kinds,usize limit){
    if(limit>=upper_bound(code)){return true;}
    var Count count=Count{.seen=[false;143],.used=code.records.layouts.count,.views=0};
    return image_types(ref mut count,code,reference_returns,static_kinds) && count.used<=limit;
}
pub fn bool fits_host(ref host::Program program,usize limit){
    let ref ir::Program code=host::code(program);
    if(limit>=upper_bound(code)){return true;}
    var Count count=Count{.seen=[false;143],.used=code.records.layouts.count,.views=0};
    let ref u8[] input=if(host::accepts_input(program)){b"\x03"}else{b""};
    if(!image_types(ref mut count,code,b"",input)){return false;}
    let ref catalog::Catalog imports=host::imports(program);
    let usize used=host::requirements(program);
    let usize one=1;
    var usize id=0;
    while(id<catalog::count(imports)){
        if((used&(one<<id))!=0 && !host_signature(ref mut count,imports,id)){return false;}
        id+=1;
    }
    return count.used<=limit;
}
fn bool host_signature(ref mut Count count,ref catalog::Catalog imports,usize id){
    let u8 result=switch(catalog::result_tag(imports,id)){
        case .ok(v):{v}case .err(_):{return false;}
    };
    value(count,128+wire::register_tag(result));
    let usize argc=switch(catalog::parameter_count(imports,id)){
        case .ok(v):{v}case .err(_):{return false;}
    };
    var usize i=0;
    while(i<argc){
        let u8 tag=switch(catalog::parameter_tag(imports,id,i)){
            case .ok(v):{v}case .err(_):{return false;}
        };
        if(tag==7){slice_type(count,10,false);}
        else{value(count,wire::scalar_tag(tag));}
        i+=1;
    }
    return true;
}

// Nominal declarations have separate identities even with identical fields.
fn bool image_types(ref mut Count count,ref ir::Program code,ref u8[] reference_returns,ref u8[] static_kinds){
    let ref records::Catalog layouts=ref code.records.layouts;
    var usize r=0;
    while(r<code.registers){value(count,code.types[r]);r+=1;}
    var usize f=0;
    while(f<code.function_count){
        if(reference_returns.len==0 || reference_returns[f]==0){value(count,code.return_types[f]);}
        f+=1;
    }
    r=0;
    while(r<layouts.count){
        var usize i=0;
        while(i<layouts.fields[r] as usize){
            let usize field=r*16+i;
            if(layouts.kinds[field]==0){value(count,layouts.types[field]);}
            i+=1;
        }
        r+=1;
    }
    array_types(count,ref code.arrays);
    return view_types(count,code,static_kinds);
}
