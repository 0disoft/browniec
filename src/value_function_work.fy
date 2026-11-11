module value_function_work;
import functions as functions;
import function_scan_work as scanning;
import struct_scan_work as records;
import value_signature_work as annotations;
import value_properties as properties;
import lexer as lexer;
import errors as errors;
import metadata_budget as budget;
// Complete value signatures: validate all record declarations first, prepare the
// private canonical catalog, then share the single-source signature coordinator.
// Caller catalog remains separate; only success publishes both candidates.
pub struct State { records::State records; scanning::State functions; annotations::State annotation; usize row; u8 phase; bool done; }
pub fn State empty(){return State{.records=records::single(),.functions=scanning::single(false),.annotation=annotations::begin(lexer::empty()),.row=0,.phase=0,.done=false};}
pub fn Result<functions::Table,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,0));}return scanning::prepared(ref w.functions);}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref mut properties::Catalog candidate,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==0){let bool done=records::advance_single(source,ref mut w.records,meter)?;if(done){w.phase=1;}return .ok(false);}
    if(w.phase==5){var annotations::State frame=w.annotation;
        let Result<bool,errors::Error> result=scanning::advance_values(source,candidate,ref mut frame,ref mut w.functions,meter);w.annotation=frame;
        let bool done=result?;if(done){w.done=true;return .ok(true);}return .ok(false);}
    if(!budget::admit(meter,4096,0)?){return .ok(false);}
    if(w.phase==1){candidate.count=0;candidate.records.count=w.records.result.layouts.count;w.row=0;w.phase=2;return .ok(false);}
    if(w.phase==2){if(w.row==64){w.row=0;w.phase=3;return .ok(false);}let usize i=w.row;candidate.nodes[i]=properties::Node{.kind=0,.first=0,.second=0,.extent=0};w.row+=1;return .ok(false);}
    if(w.phase==3){if(w.row==32){w.row=0;w.phase=4;return .ok(false);}let usize i=w.row;candidate.records.fields[i]=w.records.result.layouts.fields[i];w.row+=1;return .ok(false);}
    if(w.phase==4){var usize n=0;while(n<16){let usize i=w.row;candidate.records.kinds[i]=w.records.result.layouts.kinds[i];candidate.records.types[i]=w.records.result.layouts.types[i];w.row+=1;n+=1;}
        if(w.row==512){w.phase=5;}return .ok(false);}
    return .err(errors::make(5,0));
}
