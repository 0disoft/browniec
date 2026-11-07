/* Revision-2 Windows x64 natural layout, checked by C and C++ MSVC. */
#ifndef BC_BOOTSTRAP_LAYOUT_H
#define BC_BOOTSTRAP_LAYOUT_H
#include "brownie.h"
#ifdef __cplusplus
#define BC_ASSERT(c) static_assert(c, #c)
#define BC_ALIGNOF(t) alignof(t)
#else
#define BC_ASSERT(c) _Static_assert(c, #c)
#define BC_ALIGNOF(t) _Alignof(t)
#endif
BC_ASSERT(sizeof(void *) == 8);
BC_ASSERT(sizeof(bc_handle) == 8);
BC_ASSERT(sizeof(bc_slice) == 16);
BC_ASSERT(sizeof(bc_source) == 32);
BC_ASSERT(sizeof(bc_diagnostic) == 264);
BC_ASSERT(sizeof(bc_event) == 336);
BC_ASSERT(sizeof(bc_entry_info) == 32);
BC_ASSERT(sizeof(bc_abi_info) == 32);
BC_ASSERT(BC_ALIGNOF(bc_slice) == 8);
BC_ASSERT(BC_ALIGNOF(bc_source) == 8);
BC_ASSERT(BC_ALIGNOF(bc_event) == 8);
BC_ASSERT(BC_ALIGNOF(bc_entry_info) == 8);
BC_ASSERT(BC_ALIGNOF(bc_diagnostic) == 4);
BC_ASSERT(BC_ALIGNOF(bc_abi_info) == 4);
#define BC_OFFSET(t, f, n) BC_ASSERT(offsetof(t, f) == n)
BC_OFFSET(bc_slice, data, 0); BC_OFFSET(bc_slice, len, 8);
BC_OFFSET(bc_source, module, 0); BC_OFFSET(bc_source, source_utf8, 16);
BC_OFFSET(bc_diagnostic, struct_size, 0); BC_OFFSET(bc_diagnostic, code, 4);
BC_OFFSET(bc_diagnostic, source_index, 8); BC_OFFSET(bc_diagnostic, byte_start, 12);
BC_OFFSET(bc_diagnostic, byte_end, 16); BC_OFFSET(bc_diagnostic, flags, 20);
BC_OFFSET(bc_diagnostic, message, 24);
BC_OFFSET(bc_event, struct_size, 0); BC_OFFSET(bc_event, kind, 4);
BC_OFFSET(bc_event, trap_code, 8); BC_OFFSET(bc_event, return_i32, 12);
BC_OFFSET(bc_event, import_id, 16); BC_OFFSET(bc_event, reserved, 20);
BC_OFFSET(bc_event, request_id, 24); BC_OFFSET(bc_event, fuel_used, 32);
BC_OFFSET(bc_event, peak_accounted_bytes, 40); BC_OFFSET(bc_event, elapsed_us, 48);
BC_OFFSET(bc_event, payload, 56); BC_OFFSET(bc_event, diagnostic, 72);
BC_OFFSET(bc_entry_info, struct_size, 0); BC_OFFSET(bc_entry_info, abi_revision, 4);
BC_OFFSET(bc_entry_info, input_kind, 8); BC_OFFSET(bc_entry_info, reserved, 12);
BC_OFFSET(bc_entry_info, required_capabilities_json, 16);
BC_OFFSET(bc_abi_info, struct_size, 0); BC_OFFSET(bc_abi_info, abi_revision, 4);
BC_OFFSET(bc_abi_info, pointer_bits, 8); BC_OFFSET(bc_abi_info, diagnostic_size, 12);
BC_OFFSET(bc_abi_info, event_size, 16); BC_OFFSET(bc_abi_info, entry_info_size, 20);
BC_OFFSET(bc_abi_info, source_size, 24); BC_OFFSET(bc_abi_info, slice_size, 28);
#undef BC_OFFSET
#undef BC_ALIGNOF
#undef BC_ASSERT
#endif
