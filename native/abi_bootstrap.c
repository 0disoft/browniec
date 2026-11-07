/* Pointer/layout marshalling only. Fairy owns validation and metadata values.
   Private generated names below are guarded by a complete transport SHA-256
   in tools/build-abi-bootstrap.py; they are NOT a stable compiler or DLL ABI. */
#define BC_ABI_BOOTSTRAP_INTERNAL
#include "brownie.h"
#include "abi_bootstrap_layout.h"
#include <string.h>

#define main bc_private_unused_transport_main
#include "abi_bootstrap_generated.c"
#undef main

__declspec(dllexport) uint32_t BC_CALL bc_get_abi_info_v2(uint32_t requested_revision,
    uint32_t out_capacity, bc_abi_info *out_info) {
    uint32_t status = fy_fn_8(requested_revision, out_capacity, out_info != NULL);
    bc_abi_info info;
    if (status != BC_OK) { return status; }
    info.struct_size = fy_fn_3();
    info.abi_revision = fy_fn_5();
    info.pointer_bits = fy_fn_4();
    info.diagnostic_size = fy_fn_0();
    info.event_size = fy_fn_2();
    info.entry_info_size = fy_fn_1();
    info.source_size = fy_fn_7();
    info.slice_size = fy_fn_6();
    memcpy(out_info, &info, sizeof(info));
    return status;
}
