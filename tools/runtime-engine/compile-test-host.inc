/* Include after generated.c, bindings.h and bridge.inc in the native fixture.
 * Read scalar counters only; never copy ownership or consume an admission.
 * Each call authenticates the current owner and requires no active operation.
 */
#include <assert.h>
#include <stdint.h>

uintptr_t bc_runtime_engine_test_compile_epoch(const void *raw){
    const bc_engine *e=raw;
    assert(bc_runtime_engine_control_access(raw)==0);
    return e->f_0.f_4;
}

uintptr_t bc_runtime_engine_test_compile_next(const void *raw){
    const bc_engine *e=raw;
    assert(bc_runtime_engine_control_access(raw)==0);
    return e->f_0.f_5;
}
