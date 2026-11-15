module value_codec;
import value_properties as properties;
import struct_layout as records;
import scalar_codec as scalar;
import cells as cells;

// Private immutable native layout. Copyable analysis data never substitutes for
// this retained catalog at byte boundaries. This grants no execution authority.
struct Classes { usize[64] ids; }
pub resource Layout {
    properties::Catalog catalog; properties::Plan shapes; records::Plan records;
    Classes classes; cleanup { }
}
pub enum Error { Layout; Type; Bounds; Value; Overlap; }
// A decoded word is NOT authenticated owner authority. The owning store must
// resolve it to the exact live native root before transferring or dropping it.
pub struct Active { bool present; usize offset; usize serial; }
pub struct Selection { bool matched; bool payload; usize type_id; usize offset; usize bytes; }
// Fresh byte inspection plus a deferred branch decision. The owning store must
// authenticate active before observing selection, including its Type error.
pub struct InspectedSelection { Active active; Result<Selection,Error> selection; }
struct Cursor { usize depth; usize[16] records; usize[16] fields; usize[16] bases; usize[16] ends; }
fn bool equivalent(properties::Node a,properties::Node b,ref usize[] classes){
    if(a.kind!=b.kind || a.extent!=b.extent){return false;}
    if(a.kind==5 || a.kind==6){return classes[a.first as usize]==classes[b.first as usize] &&
        (a.kind!=6 || classes[a.second as usize]==classes[b.second as usize]);}
    return a.first==b.first && a.second==b.second;
}
pub fn Result<Layout,Error> retain(ref properties::Catalog catalog){
    let properties::Inspected checked=switch(properties::inspect_described(catalog)){
        case .ok(v):{v}case .err(_):{return .err(.Layout);}
    };
    let ref properties::Plan shapes=ref checked.shapes;
    var Classes classes=Classes{.ids=[0;64]};var usize i=0;while(i<shapes.count){var usize identity=i;var usize j=0;
        while(j<i){if(equivalent(catalog.nodes[i],catalog.nodes[j],ref classes.ids)){identity=classes.ids[j];break;}j+=1;}
        classes.ids[i]=identity;i+=1;
    }
    return .ok(Layout{.catalog=*catalog,.shapes=*shapes,.records=checked.records,.classes=classes});
}
pub fn usize count(ref Layout layout){return layout.shapes.count;}
pub fn Result<properties::Property,Error> shape(ref Layout layout,usize id){
    if(id>=layout.shapes.count){return .err(.Type);}return .ok(layout.shapes.properties[id]);
}
pub fn Result<properties::Node,Error> node(ref Layout layout,usize id){
    if(id>=layout.shapes.count){return .err(.Type);}return .ok(layout.catalog.nodes[id]);
}
pub fn Result<bool,Error> same(ref Layout layout,usize a,usize b){
    if(a>=layout.shapes.count || b>=layout.shapes.count){return .err(.Type);}
    return .ok(layout.classes.ids[a]==layout.classes.ids[b]);
}
fn bool window(usize start,usize size,usize length){return start<=length && size<=length-start;}
fn bool zero(ref u8[] data,usize first,usize last){
    var usize i=first;while(i<last){if(data[i]!=0){return false;}i+=1;}return true;
}
fn Result<usize,Error> record(ref Layout layout,usize id,ref u8[] data){
    var Cursor c=Cursor{.depth=1,.records=[0;16],.fields=[0;16],.bases=[0;16],.ends=[0;16]};c.records[0]=id;
    while(c.depth>0){let usize level=c.depth-1;let usize nominal=c.records[level];
        let usize field=c.fields[level];let usize base=c.bases[level];
        if(field==layout.catalog.records.fields[nominal] as usize){
            if(!zero(data,base+c.ends[level],base+layout.records.bytes[nominal])){return .err(.Value);}
            c.depth-=1;
        }else{
            let usize slot=nominal*16+field;let usize at=layout.records.offsets[slot];
            let u8 tag=layout.catalog.records.types[slot];let bool nested=layout.catalog.records.kinds[slot]==1;
            let usize width=if(nested){layout.records.bytes[tag as usize]}else{scalar::width(tag)};
            if(!zero(data,base+c.ends[level],base+at)){return .err(.Value);}
            c.fields[level]+=1;c.ends[level]=at+width;
            // retain proved the scalar tag/width and inspect checked the exact
            // extent. All integer bit patterns are canonical; only bool has
            // invalid payload bytes. Keep every nested padding check above.
            if(nested){let usize child=c.depth;
                if(child>=16){return .err(.Layout);}
                c.records[child]=tag as usize;c.fields[child]=0;c.bases[child]=base+at;c.ends[child]=0;c.depth+=1;
            }else if(tag==2 && data[base+at]>1){return .err(.Value);}
        }
    }return .ok(data.len);
}
// Validate every readable scalar, tag and canonical padding byte, but never
// interpret an inactive payload as a scalar/token. At most one Buffer is active:
// records/arrays cannot contain resources and each wrapper selects one child.
pub fn Result<Active,Error> inspect(ref Layout layout,usize id,ref u8[] data){
    let properties::Property full=shape(layout,id)?;
    if(data.len!=full.bytes){return .err(.Bounds);}
    var usize current=id;var usize base=0;var usize steps=0;
    while(steps<5){steps+=1;let properties::Node n=layout.catalog.nodes[current];let properties::Property p=layout.shapes.properties[current];
        if(n.kind==5 || n.kind==6){
            let u8 encoded=data[base];if(encoded>1){return .err(.Value);}
            if(!zero(data,base+1,base+p.payload_offset)){return .err(.Value);}
            let bool first=if(n.kind==5){encoded==1}else{encoded==0};
            if(n.kind==5 && !first){
                if(!zero(data,base+p.payload_offset,base+p.bytes)){return .err(.Value);}
                return .ok(Active{.present=false,.offset=0,.serial=0});
            }
            let usize child=if(first){n.first as usize}else{n.second as usize};
            let usize size=layout.shapes.properties[child].bytes;
            if(!zero(data,base+p.payload_offset+size,base+p.bytes)){return .err(.Value);}
            base+=p.payload_offset;current=child;
        }else{
            let ref u8[] selected=data[base..base+p.bytes];
            if(n.kind==1){if(!scalar::decode(n.first,selected).is_ok){return .err(.Value);}}
            else if(n.kind==2){
                // retain proved the integer tag/extent and inspect checked the
                // exact byte length. Every integer bit pattern is canonical;
                // only bool arrays have invalid payload bytes (anything >1).
                if(n.first==2){var usize at=0;
                    while(at<p.bytes){if(selected[at]>1){return .err(.Value);}at+=1;}
                }
            }else if(n.kind==3){let usize checked=record(layout,n.first as usize,selected)?;}
            else if(n.kind==4){
                let i64 cell=switch(scalar::decode(12,selected)){case .ok(v):{v}case .err(_):{return .err(.Value);}};
                let usize serial=switch(cells::unpack(cell,0)){case .ok(v):{v}case .err(_):{return .err(.Value);}};
                if(serial==0){return .err(.Value);}
                return .ok(Active{.present=true,.offset=base,.serial=serial});
            }else{return .err(.Layout);}
            return .ok(Active{.present=false,.offset=0,.serial=0});
        }
    }return .err(.Layout);
}
pub fn Result<i64,Error> read_scalar(ref Layout layout,usize id,ref u8[] data){
    let properties::Node n=node(layout,id)?;if(n.kind!=1){return .err(.Type);}
    return switch(scalar::decode(n.first,data)){case .ok(v):{.ok(v)}case .err(_):{.err(.Value)}};
}
pub fn Result<usize,Error> write_scalar(ref Layout layout,usize id,i64 value,ref mut u8[] data){
    let properties::Node n=node(layout,id)?;if(n.kind!=1){return .err(.Type);}
    return switch(scalar::encode(n.first,value,data)){case .ok(v):{.ok(v)}case .err(_):{.err(.Value)}};
}
// These byte helpers alone transfer no ownership or initialized-state authority.
// One mutable backing view lets us authenticate aliases and stage-free copies.
fn void copy(usize source,usize destination,usize size,ref mut u8[] data){
    if(destination>source && destination-source<size){var usize i=size;while(i>0){i-=1;data[destination+i]=data[source+i];}}
    else{var usize i=0;while(i<size){data[destination+i]=data[source+i];i+=1;}}
}
pub fn Result<usize,Error> copy_at(ref Layout layout,usize id,usize source,usize destination,ref mut u8[] data){
    let properties::Property p=shape(layout,id)?;
    if(!window(source,p.bytes,data.len) || !window(destination,p.bytes,data.len)){return .err(.Bounds);}
    let Active active=inspect(layout,id,data[source..source+p.bytes])?;
    copy(source,destination,p.bytes,data);return .ok(p.bytes);
}
pub fn Result<usize,Error> wrap_at(ref Layout layout,usize id,u8 variant,
    usize source,usize destination,ref mut u8[] data){
    let properties::Node n=node(layout,id)?;let properties::Property p=shape(layout,id)?;
    if((n.kind!=5 && n.kind!=6) || variant>1){return .err(.Type);}
    if(!window(destination,p.bytes,data.len)){return .err(.Bounds);}
    let bool present=n.kind==6 || variant==1;
    var usize size=0;
    if(present){let usize child=if(variant==1){n.first as usize}else{n.second as usize};size=layout.shapes.properties[child].bytes;
        if(!window(source,size,data.len)){return .err(.Bounds);}
        // Preserve disjoint-source construction before any target writes.
        if(source<destination+p.bytes && destination<source+size){return .err(.Overlap);}
        let Active active=inspect(layout,child,data[source..source+size])?;
    }else if(source!=0){return .err(.Bounds);}
    // The validated payload is copied in full below; only clear its padding.
    var usize i=1;while(i<p.payload_offset){data[destination+i]=0;i+=1;}
    i=p.payload_offset+size;while(i<p.bytes){data[destination+i]=0;i+=1;}
    data[destination]=if(n.kind==6){if(variant==1){0}else{1}}else{variant};
    if(present){copy(source,destination+p.payload_offset,size,data);}
    return .ok(p.bytes);
}
// Only called after inspect succeeds for these exact immutable bytes and after
// the wrapper kind/variant checks. No caller-supplied proof enters this helper.
fn Selection selection(ref Layout layout,properties::Node n,properties::Property p,u8 variant,ref u8[] data){
    let u8 actual=if(n.kind==6){if(data[0]==0){1}else{0}}else{data[0]};
    if(actual!=variant){return Selection{.matched=false,.payload=false,.type_id=0,.offset=0,.bytes=0};}
    if(n.kind==5 && variant==0){return Selection{.matched=true,.payload=false,.type_id=0,.offset=0,.bytes=0};}
    let usize child=if(variant==1){n.first as usize}else{n.second as usize};
    return Selection{.matched=true,.payload=true,.type_id=child,.offset=p.payload_offset,.bytes=layout.shapes.properties[child].bytes};
}
pub fn Result<Selection,Error> select(ref Layout layout,usize id,u8 variant,ref u8[] data){
    let properties::Node n=node(layout,id)?;let properties::Property p=shape(layout,id)?;
    if((n.kind!=5 && n.kind!=6) || variant>1){return .err(.Type);}
    let Active active=inspect(layout,id,data)?;
    return .ok(selection(layout,n,p,variant,data));
}
// Store composition validates bytes first, then authenticates the active native
// root, then reports a branch Type error. Raw select retains its Type-first API.
pub fn Result<InspectedSelection,Error> inspect_selection(ref Layout layout,usize id,u8 variant,ref u8[] data){
    let Active active=inspect(layout,id,data)?;
    let properties::Node n=layout.catalog.nodes[id];let properties::Property p=layout.shapes.properties[id];
    let Result<Selection,Error> selected=if((n.kind==5 || n.kind==6) && variant<=1){.ok(selection(layout,n,p,variant,data))}else{.err(.Type)};
    return .ok(InspectedSelection{.active=active,.selection=selected});
}
