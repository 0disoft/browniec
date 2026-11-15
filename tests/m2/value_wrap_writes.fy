module tests::m2::value_wrap_writes;
import value_codec as codec;
import value_properties as values;
import std::bytes as bytes;

fn values::Node node(u8 kind,u8 first,u8 second,usize extent){return values::Node{.kind=kind,.first=first,.second=second,.extent=extent};}
fn values::Catalog catalog(){
    var values::Catalog c=values::empty();c.count=20;
    c.nodes[0]=node(1,2,0,0);c.nodes[1]=node(1,10,0,0);c.nodes[2]=node(1,1,0,0);c.nodes[3]=node(1,9,0,0);
    c.nodes[4]=node(2,9,0,4096);c.nodes[5]=node(2,2,0,8);c.nodes[6]=node(3,0,0,0);c.nodes[7]=node(4,0,0,0);
    c.nodes[8]=node(5,0,0,0);c.nodes[9]=node(5,3,0,0);c.nodes[10]=node(6,4,0,0);c.nodes[11]=node(5,4,0,0);
    c.nodes[12]=node(5,6,0,0);c.nodes[13]=node(5,7,0,0);c.nodes[14]=node(6,0,7,0);c.nodes[15]=node(5,13,0,0);
    c.nodes[16]=node(5,15,0,0);c.nodes[17]=node(5,16,0,0);c.nodes[18]=node(6,2,1,0);c.nodes[19]=node(5,5,0,0);
    c.records.count=1;c.records.fields[0]=3;c.records.types[0]=2;c.records.types[1]=9;c.records.types[2]=10;return c;
}
fn codec::Layout retained(ref values::Catalog c){return switch(codec::retain(c)){
    case .ok(v):{v}case .err(_):{assert(false);retained(c)}};}
fn usize ok(Result<usize,codec::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn values::Property shape(ref codec::Layout l,usize id){return switch(codec::shape(l,id)){
    case .ok(v):{v}case .err(_):{assert(false);shape(l,0)}};}
fn values::Node kind(ref codec::Layout l,usize id){return switch(codec::node(l,id)){
    case .ok(v):{v}case .err(_):{assert(false);node(0,0,0,0)}};}
fn u8 code(codec::Error e){return switch(e){case .Layout:{1}case .Type:{2}case .Bounds:{3}case .Value:{4}case .Overlap:{5}};}
fn bytes::Buffer backing(usize size){var bytes::Buffer b=switch(bytes::with_capacity(size)){
    case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(bytes::resize_zeroed(ref mut b,size).is_ok);return b;
}
fn void copy(ref u8[] source,ref mut u8[] destination){assert(source.len==destination.len);
    var usize i=0;while(i<source.len){destination[i]=source[i];i+=1;}
}
fn bool window(usize start,usize size,usize length){return start<=length && size<=length-start;}
fn void original_copy(usize source,usize destination,usize size,ref mut u8[] data){
    if(destination>source && destination-source<size){var usize i=size;while(i>0){i-=1;data[destination+i]=data[source+i];}}
    else{var usize i=0;while(i<size){data[destination+i]=data[source+i];i+=1;}}
}
// Frozen ed474cf construction, including all preflight/error ordering.
fn Result<usize,codec::Error> original(ref codec::Layout layout,usize id,u8 variant,
    usize source,usize destination,ref mut u8[] data){
    let values::Node n=codec::node(layout,id)?;let values::Property p=codec::shape(layout,id)?;
    if((n.kind!=5 && n.kind!=6) || variant>1){return .err(.Type);}
    if(!window(destination,p.bytes,data.len)){return .err(.Bounds);}
    let bool present=n.kind==6 || variant==1;var usize size=0;
    if(present){let usize child=if(variant==1){n.first as usize}else{n.second as usize};size=shape(layout,child).bytes;
        if(!window(source,size,data.len)){return .err(.Bounds);}
        if(source<destination+p.bytes && destination<source+size){return .err(.Overlap);}
        let codec::Active active=codec::inspect(layout,child,data[source..source+size])?;
    }else if(source!=0){return .err(.Bounds);}
    var usize i=0;while(i<p.bytes){data[destination+i]=0;i+=1;}
    data[destination]=if(n.kind==6){if(variant==1){0}else{1}}else{variant};
    if(present){original_copy(source,destination+p.payload_offset,size,data);}
    return .ok(p.bytes);
}
fn void parity(ref codec::Layout l,usize id,u8 variant,usize source,usize destination,ref u8[] initial){
    var bytes::Buffer expected=backing(initial.len);var bytes::Buffer actual=backing(initial.len);
    copy(initial,bytes::view_mut(ref mut expected));copy(initial,bytes::view_mut(ref mut actual));
    let Result<usize,codec::Error> wanted=original(l,id,variant,source,destination,bytes::view_mut(ref mut expected));
    let Result<usize,codec::Error> got=codec::wrap_at(l,id,variant,source,destination,bytes::view_mut(ref mut actual));
    switch(wanted){case .ok(x):{
        assert(switch(got){case .ok(y):{x==y}case .err(_):{false}});
        assert(codec::inspect(l,id,bytes::view(ref actual)[destination..destination+x]).is_ok);
    }case .err(e):{
        assert(switch(got){case .ok(_):{false}case .err(f):{code(e)==code(f)}});
        assert(bytes::equal(initial,bytes::view(ref actual)));
    }};
    assert(bytes::equal(bytes::view(ref expected),bytes::view(ref actual)));
}
// Independently spell canonical source bytes, including nonzero deep resources.
fn void seed(ref codec::Layout l,usize id,usize source,ref mut u8[] data){
    let usize width=shape(l,id).bytes;var usize i=0;while(i<width){data[source+i]=0;i+=1;}
    var usize current=id;var usize base=source;
    while(true){let values::Node n=kind(l,current);let values::Property p=shape(l,current);
        if(n.kind==5 || n.kind==6){data[base]=if(n.kind==5){1}else{0};base+=p.payload_offset;current=n.first as usize;}
        else{
            if(n.kind==4){data[base]=13;}
            else if(n.kind==3){data[base]=1;data[base+8]=253;data[base+16]=199;}
            else{i=0;var u8 value=3;while(i<p.bytes){data[base+i]=if(n.first==2){1}else{value};
                if(value==250){value=0;}else{value+=1;}i+=1;}}
            break;
        }
    }
    assert(codec::inspect(l,id,data[source..source+width]).is_ok);
}
@test fn void padding_only_writes_match_original_bytes_errors_and_atomic_overlap_rejection(){
    let values::Catalog c=catalog();let codec::Layout l=retained(ref c);var usize id=8;
    while(id<c.count){if(shape(ref l,id).bytes<=40){let values::Node n=kind(ref l,id);var u8 variant=0;
        while(variant<2){var u8[192] data=[173;192];let bool present=n.kind==6 || variant==1;
            let usize child=if(variant==1){n.first as usize}else{n.second as usize};let usize source=if(present){11}else{0};
            if(present){seed(ref l,child,source,ref mut data);}
            parity(ref l,id,variant,source,88,ref data);
            parity(ref l,id,variant,source,185,ref data);
            parity(ref l,id,variant,18446744073709551615,88,ref data);
            parity(ref l,id,2,source,88,ref data);
            if(present){parity(ref l,id,variant,source,source,ref data);
                let usize width=shape(ref l,child).bytes;var usize at=0;
                while(at<width){let u8 saved=data[source+at];let u8[3] mutations=[0,2,255];var usize m=0;
                    while(m<3){data[source+at]=mutations[m];parity(ref l,id,variant,source,88,ref data);m+=1;}
                    data[source+at]=saved;at+=1;}
            }
            variant+=1;
        }
    }id+=1;}
    let u8[8] bad=[255;8];parity(ref l,0,1,18446744073709551615,18446744073709551615,ref bad);
    parity(ref l,64,1,0,0,ref bad);
}
@test fn void maximum_payloads_and_inactive_tails_match_original_in_both_copy_directions(){
    let values::Catalog c=catalog();let codec::Layout l=retained(ref c);var bytes::Buffer initial=backing(65568);
    {let ref mut u8[] raw=bytes::view_mut(ref mut initial);var usize i=0;while(i<raw.len){raw[i]=173;i+=1;}
        seed(ref l,4,0,raw);}
    parity(ref l,10,1,0,32768,bytes::view(ref initial));parity(ref l,11,1,0,32768,bytes::view(ref initial));
    parity(ref l,11,0,0,32768,bytes::view(ref initial));
    {let ref mut u8[] raw=bytes::view_mut(ref mut initial);seed(ref l,4,32784,raw);}
    parity(ref l,10,1,32784,0,bytes::view(ref initial));parity(ref l,11,1,32784,0,bytes::view(ref initial));
    {let ref mut u8[] raw=bytes::view_mut(ref mut initial);raw[0]=1;}
    parity(ref l,10,0,0,32768,bytes::view(ref initial));
    {let ref mut u8[] raw=bytes::view_mut(ref mut initial);raw[0]=2;}
    parity(ref l,10,0,0,32768,bytes::view(ref initial));
    assert(shape(ref l,10).bytes==32776 && shape(ref l,11).bytes==32776);
}
