module array_meta;

import array_layout as layouts;
import errors as errors;

pub struct Catalog { u8[16] elements; usize[16] lengths; bool[16] mutable; usize count; }
pub fn Catalog empty() {
    return Catalog { .elements = [0; 16], .lengths = [0; 16], .mutable = [false; 16], .count = 0 };
}
pub fn bool valid(ref Catalog catalog) {
    if (catalog.count > 16) { return false; }
    var usize i = 0;
    while (i < 16) {
        if (i < catalog.count) {
            if (!layouts::scalar(catalog.elements[i], catalog.lengths[i]).is_ok) { return false; }
        } else if (catalog.elements[i] != 0 || catalog.lengths[i] != 0 || catalog.mutable[i]) { return false; }
        i += 1;
    }
    return true;
}
pub fn Result<usize, errors::Error> declare(ref mut Catalog catalog, u8 element, usize length, bool mutable, usize offset) {
    if (catalog.count >= 16) { return .err(errors::make(4, offset)); }
    if (!layouts::scalar(element, length).is_ok) { return .err(errors::make(3, offset)); }
    let usize id = catalog.count;
    catalog.elements[id] = element; catalog.lengths[id] = length; catalog.mutable[id] = mutable;
    catalog.count += 1;
    return .ok(id);
}
