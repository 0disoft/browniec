module vm;
import ir as ir;
import errors as errors;
import verifier as verifier;
import array_vm as array_vm;
import slice_vm as slices;
import slice_call_vm as borrowed;
import slice_lifecycle_vm as lifecycle;
import vm_execution as execution;
import slice_mutable_call_vm as mutable;
import std::bytes as bytes;

// Guest calls use bounded VM frames, never native recursion. Register reads are
// verified per function, so reclaimed frame slots need no per-call zero-fill.
pub fn Result<i64, errors::Error> run(ref ir::Program p, usize fuel) {
    return run_with_array_limit(p, fuel, 65536);
}
// Keep the receipt collection in the mutable invocation branch. Every outcome,
// including a failed CALL or detached formal, passes through the same drain.
fn Result<i64, errors::Error> run_mutable(ref ir::Program p, usize fuel,
    ref mut array_vm::State arrays, ref mut bytes::Buffer payload,
    ref mut slices::State loans, ref mut borrowed::Frames frames) {
    var mutable::Frame[32] receipts = [mutable::empty(); 32];
    let Result<i64, errors::Error> outcome = execution::execute_mutable(p, fuel,
        arrays, payload, loans, frames, ref mut receipts);
    return mutable::finish(ref mut receipts, frames, loans, arrays, payload, outcome);
}
pub fn Result<i64, errors::Error> run_with_array_limit(ref ir::Program p, usize fuel, usize array_limit) {
    let usize verified = verifier::verify(p)?;
    var usize remaining = fuel;
    var bytes::Buffer payload = bytes::empty();
    let bool aggregates = p.arrays.count != 0 || p.records.count != 0;
    var array_vm::State arrays = array_vm::empty(if (aggregates) { array_limit } else { 0 });
    if (aggregates) {
        if (array_limit > 65536) { return .err(errors::make(13, 0)); }
        let usize preparation = 1 + array_limit;
        if (remaining < preparation) { return .err(errors::make(8, 0)); }
        remaining -= preparation;
        payload = array_vm::prepare(array_limit)?;
    }
    var slices::State loans = slices::empty();
    var borrowed::Frames frames = borrowed::empty();
    var usize site = 0;
    while (site < 16) {
        if (p.slice_roots[site] == 0 && ir::exclusive(p, site)) {
            return run_mutable(p, remaining, ref mut arrays, ref mut payload, ref mut loans, ref mut frames);
        }
        site += 1;
    }
    let Result<i64, errors::Error> outcome = execution::execute(p, remaining, ref mut arrays, ref mut payload, ref mut loans, ref mut frames);
    return lifecycle::finish(ref mut frames, ref mut loans, ref mut arrays, ref payload, outcome);
}
