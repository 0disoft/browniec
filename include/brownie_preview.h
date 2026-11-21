#ifndef BROWNIE_PREVIEW_H
#define BROWNIE_PREVIEW_H

#include "brownie.h"

#if defined(BC_BUILD_PREVIEW_DLL)
# define BC_PREVIEW_API __declspec(dllexport)
#elif defined(_WIN32)
# define BC_PREVIEW_API __declspec(dllimport)
#else
# define BC_PREVIEW_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Windows x64 trusted scalar preview. Handles belong to the Engine's creating
   thread. Pass live C storage and keep it valid for the duration of each call. */
#define BC_PREVIEW_REVISION 1u
#define BC_PREVIEW_MAX_FUEL UINT64_C(16000000)
enum bc_preview_event_kind {
    BC_PREVIEW_YIELD=1, BC_PREVIEW_DONE=2, BC_PREVIEW_TRAP=3, BC_PREVIEW_CANCELLED=4
};
typedef struct bc_preview_event {
    uint32_t struct_size, kind;
    int32_t return_i32;
    uint32_t diagnostic_code;
    uint64_t fuel_used;
} bc_preview_event;

BC_PREVIEW_API uint32_t BC_CALL bc_preview_engine_create(uint32_t revision, bc_handle *out);
/* One source with module main and a public fn i32 main(). Source bytes are copied. */
BC_PREVIEW_API uint32_t BC_CALL bc_preview_compile(bc_handle engine, bc_slice source, bc_handle *out);
BC_PREVIEW_API uint32_t BC_CALL bc_preview_instance_create(bc_handle engine, bc_handle program,
                                                         uint64_t fuel, bc_handle *out);
/* Initialize out->struct_size. Terminal events are immutable and repeatable. */
BC_PREVIEW_API uint32_t BC_CALL bc_preview_step(bc_handle instance, uint32_t quantum, bc_preview_event *out);
BC_PREVIEW_API uint32_t BC_CALL bc_preview_cancel(bc_handle instance);
BC_PREVIEW_API uint32_t BC_CALL bc_preview_instance_destroy(bc_handle instance);
BC_PREVIEW_API uint32_t BC_CALL bc_preview_program_release(bc_handle engine, bc_handle program);
BC_PREVIEW_API uint32_t BC_CALL bc_preview_engine_destroy(bc_handle engine);

#ifdef __cplusplus
}
#endif
#endif
