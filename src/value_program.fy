module value_program;
import value_ir as values;
import verifier as verifier;
import value_frame_layout as frames;
import slice_reborrow_ir as reborrows;
import errors as errors;
import ir as ir;
import std::vec as vec;

pub struct Error { bool layout; errors::Error code; }
// Private fields seal one independently proved code/layout/loan snapshot. The
// resource is single-owned; its only projections are immutable borrows.
resource Snapshot {
    values::Program code; frames::Plan layout; reborrows::Sites loans;
    cleanup { }
}
// A single heap-owned snapshot keeps owning return values small on the native
// stack. Neither the vector nor its element has any external mutable projection.
pub resource Program { vec::Vec<Snapshot> snapshots; cleanup { } }

// No caller-supplied proof or runtime backing participates in admission. Typed
// instructions use the complete value verifier, without a legacy opcode gate.
// Finish the large verifier result before introducing owning return slots.
fn Result<reborrows::Sites,Error> inspect(ref values::Program unit){
    return switch(verifier::inspect_values(unit)){
        case .ok(proof):{.ok(proof.loans)}
        case .err(e):{.err(Error{.layout=false,.code=e})}
    };
}
pub fn Result<Program,Error> retain(ref values::Program unit){
    let reborrows::Sites loans=inspect(unit)?;
    let ref ir::Program body=ref unit.body;
    return switch(frames::retain(ref unit.catalog,ref unit.types,
        ref unit.functions,body.function_count)){
        case .ok(layout):{seal(unit,layout,loans)}
        case .err(_):{.err(Error{.layout=true,.code=errors::make(5,0)})}
    };
}
fn Result<Program,Error> seal(ref values::Program unit,frames::Plan layout,reborrows::Sites loans){
    var vec::Vec<Snapshot> snapshots=vec::empty<Snapshot>();
    if(!vec::reserve<Snapshot>(ref mut snapshots,1).is_ok){
        return .err(Error{.layout=false,.code=errors::make(15,0)});
    }
    switch(vec::push<Snapshot>(ref mut snapshots,Snapshot{.code=*unit,.layout=layout,.loans=loans})){
        case .ok(_):{}case .err(_):{return .err(Error{.layout=false,.code=errors::make(15,0)});}
    };
    return .ok(Program{.snapshots=snapshots});
}
pub fn ref values::Program code(ref Program p){
    let ref Snapshot snapshot=vec::at<Snapshot>(ref p.snapshots,0);return ref snapshot.code;
}
pub fn ref frames::Plan layout(ref Program p){
    let ref Snapshot snapshot=vec::at<Snapshot>(ref p.snapshots,0);return ref snapshot.layout;
}
pub fn ref reborrows::Sites loans(ref Program p){
    let ref Snapshot snapshot=vec::at<Snapshot>(ref p.snapshots,0);return ref snapshot.loans;
}
