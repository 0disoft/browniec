module vm;
import ir as ir;
import errors as errors;
import verifier as verifier;
import array_vm as array_vm;
import slice_vm as slices;
import slice_call_vm as borrowed;
import slice_lifecycle_vm as lifecycle;
import vm_execution as execution;
import slice_authority as authority;
import slice_authority_call_vm as calls;
import slice_reborrow_vm as children;
import slice_reborrow_ir as proof;
import slice_reborrow_context as context;
import std::bytes as bytes;

// Guest calls use bounded VM frames, never native recursion. Register reads are
// verified per function, so reclaimed frame slots need no per-call zero-fill.
pub fn Result<i64, errors::Error> run(ref ir::Program p, usize fuel) {
    return run_with_array_limit(p, fuel, 65536);
}
// Called only after public verify: op61/62 are absent, so the exact Sites forest
// is empty. Fresh local roots need no second whole-program proof. Every outcome
// passes through canonical drain before the invocation backing is disposed.
fn Result<i64, errors::Error> run_mutable(ref ir::Program p, usize fuel,
    ref mut array_vm::State arrays, ref mut bytes::Buffer payload,
    ref mut slices::State loans, ref mut borrowed::Frames frames) {
    let proof::Sites sites=proof::Sites{.parents=[16;16],.newer=[0;16],.count=0};
    var authority::State[1] receipts=[authority::empty();1];
    var calls::Bindings[1] call_sites=[calls::empty();1];
    var children::Bindings[1] child_sites=[children::empty();1];
    let Result<i64,errors::Error> outcome=execution::execute_canonical(p,ref sites,fuel,
        arrays,payload,loans,frames,ref mut receipts,ref mut call_sites,ref mut child_sites);
    return context::finish(ref mut child_sites[0],ref mut call_sites[0],ref mut receipts[0],frames,loans,arrays,payload,outcome);
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
