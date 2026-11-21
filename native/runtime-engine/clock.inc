#include <stdint.h>
#include <windows.h>
#pragma comment(lib, "mincore.lib")

#ifndef BC_ENGINE_INTERRUPT_TIME
#define BC_ENGINE_INTERRUPT_TIME QueryInterruptTimePrecise
#endif
uintptr_t bc_runtime_engine_monotonic_ticks(void){
 ULONGLONG now;
 BC_ENGINE_INTERRUPT_TIME(&now);
 return (uintptr_t)now;
}

/* Only the project worker installs a probe, for one synchronous compile. */
typedef uint32_t (*bc_compile_stop_probe)(void);
static __declspec(thread) bc_compile_stop_probe compile_stop_probe;
static __declspec(thread) uint32_t compile_stop_cause;

void bc_runtime_engine_compile_stop_begin(bc_compile_stop_probe probe){
    compile_stop_cause = 0;
    compile_stop_probe = probe;
}

uint32_t bc_runtime_engine_compile_stop_end(void){
    const uint32_t cause = compile_stop_cause;
    compile_stop_probe = NULL;
    compile_stop_cause = 0;
    return cause;
}

uint32_t bc_runtime_engine_deadline_reached(uintptr_t deadline){
    if (compile_stop_cause) return 1;
    const BOOL expired = deadline && bc_runtime_engine_monotonic_ticks() >= deadline;
    if (compile_stop_probe)
        compile_stop_cause = expired ? 3 : compile_stop_probe();
    return expired || compile_stop_cause != 0;
}
