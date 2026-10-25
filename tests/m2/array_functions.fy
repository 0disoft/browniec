module tests::m2::array_functions;

import compiler as compiler;
import ir as ir;
import verifier as verifier;

fn ir::Program compiled() {
    return switch (compiler::compile(b"module main; fn i32 helper(){return 0;} fn i32 main(){let i32[1] a=[42;1]; var i32[1] b=a; b=a; b[0]=42; return b[0];}")) {
        case .ok(p): { p } case .err(_): { assert(false); ir::empty() }
    };
}

@test
fn void entry_builder_and_explicit_function_builder_keep_catalog_ownership() {
    var ir::Program p = compiled();
    assert(p.entry == 1 && p.array_functions[0] == 1 && p.array_functions[1] == 1);
    assert(verifier::verify(ref p).is_ok);
    let usize before = p.arrays.count;
    assert(!ir::array_in(ref mut p, 2, 1, 1, false, 0).is_ok);
    assert(!ir::array_in(ref mut p, 16, 1, 1, false, 0).is_ok);
    assert(p.arrays.count == before);
    let usize id = switch (ir::array_in(ref mut p, 0, 1, 1, false, 0)) {
        case .ok(n): { n } case .err(_): { assert(false); 0 }
    };
    assert(id == 2 && p.array_functions[id] == 0 && verifier::verify(ref p).is_ok);
}

@test
fn void malformed_and_unused_function_ownership_is_rejected() {
    var ir::Program p = compiled();
    p.array_functions[0] = 2; assert(!verifier::verify(ref p).is_ok);
    p.array_functions[0] = 255; assert(!verifier::verify(ref p).is_ok);
    p.array_functions[0] = 1; p.array_functions[2] = 1; assert(!verifier::verify(ref p).is_ok);
    p.array_functions[2] = 0; assert(verifier::verify(ref p).is_ok);
}

@test
fn void foreign_function_cannot_initialize_copy_assign_read_write_or_drop() {
    let ir::Program original = compiled();
    var usize pc = original.starts[original.entry];
    var usize checked = 0;
    while (pc < original.count) {
        let u8 op = original.code[pc * 8];
        if (op >= 33) {
            var ir::Program p = original;
            // Ownership changes after initialization remain independently checked:
            // convert preceding operations into forward jumps for this one probe.
            var usize prior = original.starts[original.entry];
            while (prior < pc) {
                if (p.code[prior * 8] >= 33) {
                    p.count = prior;
                    assert(ir::raw(ref mut p, 19, 0, prior + 1, 0, 0).is_ok);
                    p.count = original.count;
                }
                prior += 1;
            }
            p.array_functions[0] = 0; p.array_functions[1] = 0;
            assert(switch (verifier::verify(ref p)) {
                case .ok(_): { false } case .err(e): { e.kind == 5 && e.offset == pc }
            });
            checked += 1;
        }
        pc += 1;
    }
    assert(checked == 7);
}
