module vm;
import ir as ir;
import errors as errors;
import verifier as verifier;
import array_vm as array_vm;
import slice_vm as slices;
import slice_call_vm as borrowed;
import slice_lifecycle_vm as lifecycle;
import vm_execution as execution;
import std::bytes as bytes;

// Guest calls use bounded VM frames, never native recursion. Register reads are
// verified per function, so reclaimed frame slots need no per-call zero-fill.
pub fn Result<i64, errors::Error> run(ref ir::Program p, usize fuel) {
    return run_with_array_limit(p, fuel, 65536);
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
    let Result<i64, errors::Error> outcome = execution::execute(p, remaining, ref mut arrays, ref mut payload, ref mut loans, ref mut frames);
    return lifecycle::finish(ref mut frames, ref mut loans, ref mut arrays, ref payload, outcome);
}
