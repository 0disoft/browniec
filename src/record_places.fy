module record_places;

import array_owners as owners;
import struct_layout as layouts;
import struct_nested_storage as storage;
import scalar_codec as codec;

// Private metadata, bound to one immutable catalog and owner/backing lifetime.
// A scalar ordinal avoids copying a sixteen-word field path into each snapshot.
pub struct Place {
    owners::Token root; usize record; usize length; usize alignment;
    usize mark; usize base; usize end; usize ordinal; u8 element; usize offset;
}
fn owners::Error failure(storage::Error error) {
    return switch(error) {
        case .Layout: { .Metadata } case .Bounds: { .Bounds } case .Fields: { .Length }
        case .State: { .State } case .Alignment: { .Alignment } case .Quota: { .Quota }
        case .Overflow: { .Overflow } case .Value: { .Value } case .Type: { .Type }
    };
}
fn owners::Error codec_error(codec::Error error) {
    return switch(error) { case .Type: { .Type } case .Width: { .Metadata } case .Value: { .Value } };
}

// Authentication and scalar selection precede any RHS/payload read. Plain bool
// stores can replace a noncanonical old byte; compound reads must reject it.
pub fn Result<Place,owners::Error> select(ref layouts::Catalog catalog,
    ref owners::Table table,owners::Token root,usize ordinal,usize capacity) {
    let owners::Owner owner=owners::resolve_record(catalog,table,root,capacity)?;
    let storage::Leaf leaf=switch(storage::scalar_location(catalog,owner.record,owner.base,
        ordinal,capacity,ref table.arena)) {
        case .ok(value): { value } case .err(error): { return .err(failure(error)); }
    };
    return .ok(Place { .root=root,.record=owner.record,.length=owner.length,.alignment=owner.alignment,
        .mark=owner.mark,.base=owner.base,.end=owner.end,.ordinal=ordinal,.element=leaf.tag,.offset=leaf.offset });
}
// The caller's current descriptor/ordinal never redirects the selected target.
// In-place replacement may alter payload, but not nominal type or reservation.
fn Result<usize,owners::Error> validate(ref layouts::Catalog catalog,
    ref owners::Table table,ref Place place,usize capacity) {
    let Place now=select(catalog,table,place.root,place.ordinal,capacity)?;
    if(now.record!=place.record || now.element!=place.element){return .err(.Type);}
    if(now.length!=place.length){return .err(.Length);}
    if(now.alignment!=place.alignment || now.mark!=place.mark || now.base!=place.base ||
        now.end!=place.end || now.offset!=place.offset){return .err(.State);}
    return .ok(codec::width(now.element));
}
pub fn Result<i64,owners::Error> read(ref layouts::Catalog catalog,
    ref owners::Table table,ref Place place,ref u8[] bytes) {
    let usize width=validate(catalog,table,place,bytes.len)?;
    return switch(codec::decode(place.element,bytes[place.offset..place.offset+width])) {
        case .ok(value): { .ok(value) } case .err(error): { .err(codec_error(error)) }
    };
}
// The scalar codec stages <=8 bytes. Revalidation/encoding failure leaves both
// payload and owner metadata unchanged; no reservation, owner or heap allocation.
pub fn Result<usize,owners::Error> store(ref layouts::Catalog catalog,
    ref owners::Table table,ref Place place,i64 value,ref mut u8[] bytes) {
    let usize width=validate(catalog,table,place,bytes.len)?;
    return switch(codec::encode(place.element,value,bytes[place.offset..place.offset+width])) {
        case .ok(size): { .ok(size) } case .err(error): { .err(codec_error(error)) }
    };
}
