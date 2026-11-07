module aggregate_places;

import array_owners as owners;
import array_layout as arrays;
import struct_layout as records;
import struct_range as ranges;

// Native metadata, bound by its coordinator to one immutable catalog and one
// owner-table/backing lifetime. It pins no owner and grants no IR write authority.
// element zero selects a nominal record subtree; arrays select the whole owner.
pub struct Place {
    owners::Token root; u8 element; usize length; usize record;
    usize nominal; usize ordinal; usize alignment;
    usize mark; usize base; usize end; usize offset; usize size;
}

// Selection authenticates only metadata. A corrupt old bool may be replaced;
// source payload validation and canonical staging belong to the eventual store.
pub fn Result<Place,owners::Error> select_array(ref owners::Table table,
    owners::Token root,usize capacity){
    let owners::View view=owners::view(table,root,0,0,capacity)?;
    let owners::Owner owner=table.slots[root.slot];
    if(owner.reading){return .err(.State);}
    let arrays::Array shape=switch(arrays::scalar(view.element,view.length)){
        case .ok(v):{v}case .err(_):{return .err(.Metadata);}
    };
    return .ok(Place{.root=root,.element=view.element,.length=view.length,.record=0,
        .nominal=0,.ordinal=0,.alignment=shape.alignment,.mark=owner.mark,.base=owner.base,
        .end=owner.end,.offset=0,.size=shape.bytes});
}
pub fn Result<Place,owners::Error> select_record(ref records::Catalog catalog,
    ref owners::Table table,owners::Token root,usize nominal,usize ordinal,usize capacity){
    let owners::Owner owner=owners::resolve_record(catalog,table,root,capacity)?;
    let records::Plan plan=switch(records::plan(catalog,18446744073709551615)){
        case .ok(v):{v}case .err(_):{return .err(.Metadata);}
    };
    let usize offset=switch(ranges::offset_prepared(catalog,ref plan,owner.record,nominal,ordinal)){
        case .ok(v):{v}case .err(_):{return .err(.Type);}
    };
    let usize size=plan.bytes[nominal];
    if(offset>owner.length || size>owner.length-offset){return .err(.Bounds);}
    return .ok(Place{.root=root,.element=0,.length=owner.length,.record=owner.record,
        .nominal=nominal,.ordinal=ordinal,.alignment=owner.alignment,.mark=owner.mark,
        .base=owner.base,.end=owner.end,.offset=offset,.size=size});
}
fn Result<usize,owners::Error> unchanged(ref Place old,ref Place now){
    if(old.element!=now.element || old.record!=now.record || old.nominal!=now.nominal){return .err(.Type);}
    if(old.length!=now.length || old.size!=now.size){return .err(.Length);}
    if(old.ordinal!=now.ordinal || old.alignment!=now.alignment || old.mark!=now.mark ||
        old.base!=now.base || old.end!=now.end || old.offset!=now.offset){return .err(.State);}
    return .ok(now.size);
}
pub fn Result<usize,owners::Error> validate_array(ref owners::Table table,ref Place place,usize capacity){
    if(place.element==0){return .err(.Type);}
    let Place now=select_array(table,place.root,capacity)?;return unchanged(place,ref now);
}
pub fn Result<usize,owners::Error> validate_record(ref records::Catalog catalog,
    ref owners::Table table,ref Place place,usize capacity){
    if(place.element!=0){return .err(.Type);}
    let Place now=select_record(catalog,table,place.root,place.nominal,place.ordinal,capacity)?;
    return unchanged(place,ref now);
}
// Never re-read a mutable descriptor for the destination after RHS evaluation.
// Native storage independently proves byte windows against the authenticated
// current tokens and finishes source validation/snapshotting before publication.
pub fn Result<usize,owners::Error> store_array(ref owners::Table table,ref Place place,
    owners::Token source,ref mut u8[] bytes){
    let usize checked=validate_array(table,place,bytes.len)?;
    return owners::assign(place.root,source,bytes,table);
}
pub fn Result<usize,owners::Error> fill_array(ref owners::Table table,ref Place place,
    i64 value,ref mut u8[] bytes){
    let usize checked=validate_array(table,place,bytes.len)?;
    return owners::fill(table,place.root,value,bytes);
}
// Scratch is caller-owned, disjoint native storage; no extra guest owner/extent.
pub fn Result<usize,owners::Error> replace_array(ref owners::Table table,ref Place place,
    ref i64[] values,ref mut u8[] scratch,ref mut u8[] bytes){
    let usize checked=validate_array(table,place,bytes.len)?;
    let arrays::Array shape=switch(arrays::scalar(place.element,place.length)){
        case .ok(v):{v}case .err(_):{return .err(.Metadata);}
    };
    if(scratch.len<shape.bytes){return .err(.Length);}
    return owners::replace_values(ref shape,place.root,values,scratch[..shape.bytes],bytes,table);
}
pub fn Result<usize,owners::Error> store_record(ref records::Catalog catalog,
    ref owners::Table table,ref Place place,owners::Token source,usize source_ordinal,ref mut u8[] bytes){
    let usize checked=validate_record(catalog,table,place,bytes.len)?;
    return owners::assign_subrecord(catalog,place.root,source,place.nominal,place.ordinal,source_ordinal,bytes,table);
}
pub fn Result<usize,owners::Error> replace_record(ref records::Catalog catalog,
    ref owners::Table table,ref Place place,ref i64[] fields,ref mut u8[] bytes){
    let usize checked=validate_record(catalog,table,place,bytes.len)?;
    return owners::replace_subrecord(catalog,place.root,place.nominal,place.ordinal,fields,bytes,table);
}
