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
