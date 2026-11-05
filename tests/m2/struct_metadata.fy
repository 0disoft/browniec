module tests::m2::struct_metadata;
import struct_meta as records;
import struct_layout as layouts;

@test fn void empty_record_preparation_authenticates_late_unused_slots_and_binding_metadata(){
    var records::Catalog c=records::empty();
    switch(records::prepare(ref c)){case .ok(p):{assert(p.leaves[15]==0 && p.tags[2047]==0);}case .err(_):{assert(false);}};
    c.layouts.fields[31]=1;assert(!records::prepare(ref c).is_ok);c.layouts.fields[31]=0;
    c.layouts.kinds[511]=1;assert(!records::prepare(ref c).is_ok);c.layouts.kinds[511]=0;
    c.layouts.types[511]=1;assert(!records::prepare(ref c).is_ok);c.layouts.types[511]=0;
    c.records[15]=1;assert(!records::prepare(ref c).is_ok);c.records[15]=0;
    c.mutable[15]=true;assert(!records::prepare(ref c).is_ok);c.mutable[15]=false;
    c.count=1;assert(!records::prepare(ref c).is_ok);c.count=0;
    assert(records::prepare(ref c).is_ok);
    var layouts::Catalog populated=layouts::empty();populated.count=1;
    populated.fields[0]=1;populated.types[0]=1;
    assert(!layouts::inspect_empty(ref populated).is_ok);
    c.layouts=populated;c.count=1;
    switch(records::prepare(ref c)){case .ok(p):{assert(p.leaves[0]==1 && p.tags[0]==1);}case .err(_):{assert(false);}};
}
