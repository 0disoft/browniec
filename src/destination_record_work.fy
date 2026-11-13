module destination_record_work;
import ir as ir;
import output_record_metadata_work as metadata;
import struct_layout_work as layouts;
import output_record_copy_work as copies;
import errors as errors;
import metadata_budget as budget;
// Pin Program until complete. Mode 2 preserves scalar-place catalog diagnostics;
// mode 4 preserves layout-only nominal-copy diagnostics, without extra checks on
// unrelated binding padding. Neither mode emits IR or publishes a place.
pub struct State { metadata::State metadata; copies::State copy; usize root; usize nominal;
    usize ordinal; usize at; usize visits; u8 kind; u8 phase; u8 tag; bool done; }
pub fn State begin(u8 kind,usize root,usize nominal,usize ordinal,usize at){return State{
    .metadata=metadata::empty(),.copy=copies::empty(),.root=root,.nominal=nominal,.ordinal=ordinal,
    .at=at,.visits=0,.kind=kind,.phase=0,.tag=0,.done=false};}
fn errors::Error invalid(ref State w){return errors::make(if(w.kind==2){3}else{5},w.at);}
pub fn Result<u8,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.tag);}
pub fn Result<bool,errors::Error> advance(ref ir::Program p,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==1){switch(metadata::advance(ref mut w.metadata,ref p.records,meter)){
        case .err(_):{return .err(invalid(w));}case .ok(done):{if(done){w.phase=2;}return .ok(false);}};}
    if(w.phase==11){switch(layouts::advance(ref mut w.metadata.layout,ref p.records.layouts,meter)){
        case .err(_):{return .err(invalid(w));}case .ok(done):{if(done){w.phase=12;}return .ok(false);}};}
    // Fixed-size child scratch avoids overlapping nested loans in the pinned
    // compiler. The child is under 4096 bytes; no catalog scan/copy is hidden.
    if(w.phase==13){var copies::State child=w.copy;
        let Result<bool,errors::Error> result=copies::advance(p,ref w.metadata.layout.plan,ref mut child,meter);w.copy=child;
        switch(result){case .err(e):{return .err(e);}case .ok(done):{if(done){w.done=true;}return .ok(w.done);}};}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}w.visits+=1;
    if(w.phase==0){if(w.kind==2){
            if(w.root>=16 || w.root>=p.records.count || !p.records.mutable[w.root] || w.ordinal>=128){return .err(invalid(w));}
            let usize started=metadata::begin(ref mut w.metadata,ref p.records)?;w.phase=1;return .ok(false);}
        if(w.kind!=4){return .err(errors::make(5,w.at));}
        if(w.root>=16 || w.root>=p.records.count){return .err(invalid(w));}
        let usize f=p.record_functions[w.root] as usize;
        if(p.function_count>16 || f>=p.function_count || p.records.count>16 || !p.records.mutable[w.root]){return .err(invalid(w));}
        let usize started=switch(layouts::begin(ref mut w.metadata.layout,18446744073709551615)){case .ok(value):{value}case .err(_):{return .err(invalid(w));}};w.phase=11;return .ok(false);}
    if(w.phase==2){if(w.ordinal>=w.metadata.result.leaves[w.root]){return .err(invalid(w));}
        w.tag=w.metadata.result.tags[w.root*128+w.ordinal];w.done=true;return .ok(true);}
    if(w.phase==12){let usize f=p.record_functions[w.root] as usize;
        let copies::Arguments args=copies::Arguments{.destination=w.root,.source=w.root,.destination_function=f,.source_function=f,
            .fresh=false,.same_frame=true,.subtree=true,.nominal=w.nominal,.destination_leaf=w.ordinal,.source_leaf=w.ordinal,.pc=w.at};
        let usize started=copies::begin(ref mut w.copy,args)?;w.phase=13;return .ok(false);}
    return .err(errors::make(5,w.at));
}
pub fn Result<u8,errors::Error> prepare(ref ir::Program p,u8 kind,usize root,usize nominal,usize ordinal,usize at){
    var State w=begin(kind,root,nominal,ordinal,at);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,at)?;let bool done=advance(p,ref mut w,ref mut meter)?;}
    return prepared(ref w);
}
