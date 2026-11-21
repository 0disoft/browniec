/* Brownie C ABI revision 2, derived from design v0.3.0 contracts/host-abi.h.
   Windows x64, natural alignment, no packed structs, __cdecl.
   The bootstrap DLL exports bc_get_abi_info_v2. The scalar preview DLL also
   exports the Engine and scalar Program lifecycle documented below. */
#ifndef BROWNIE_HOST_ABI_H
#define BROWNIE_HOST_ABI_H
#include <stddef.h>
#include <stdint.h>
#if defined(_WIN32)
# if defined(BC_ABI_BOOTSTRAP_INTERNAL)
/* Private shim declarations only; its implemented definition exports explicitly. */
#  define BC_API
#  define BC_BOOTSTRAP_QUERY_API __declspec(dllexport)
# elif defined(BC_BUILD_DLL)
#  define BC_API __declspec(dllexport)
# else
#  define BC_API __declspec(dllimport)
# endif
# define BC_CALL __cdecl
#else
# define BC_API
# define BC_CALL
#endif
#ifndef BC_BOOTSTRAP_QUERY_API
# define BC_BOOTSTRAP_QUERY_API BC_API
#endif
#ifdef __cplusplus
extern "C" {
#endif
#define BC_ABI_REVISION 2u
typedef uint64_t bc_handle;
typedef struct bc_slice { const uint8_t *data; size_t len; } bc_slice;
typedef struct bc_source { bc_slice module; bc_slice source_utf8; } bc_source;
typedef struct bc_diagnostic {
    uint32_t struct_size, code, source_index, byte_start, byte_end, flags;
    char message[240]; /* Valid UTF-8 + NUL. Flags bit 0 means truncated. */
} bc_diagnostic;
typedef struct bc_event {
    uint32_t struct_size, kind, trap_code;
    int32_t return_i32;
    uint32_t import_id, reserved;
    uint64_t request_id, fuel_used, peak_accounted_bytes, elapsed_us;
    bc_slice payload;
    bc_diagnostic diagnostic;
} bc_event;
typedef struct bc_entry_info {
    uint32_t struct_size, abi_revision, input_kind, reserved;
    bc_slice required_capabilities_json; /* Program-owned UTF-8 JSON array. */
} bc_entry_info;
typedef struct bc_abi_info {
    uint32_t struct_size, abi_revision, pointer_bits, diagnostic_size;
    uint32_t event_size, entry_info_size, source_size, slice_size;
} bc_abi_info;
enum bc_api_result {
    BC_OK=0, BC_BAD_ARGUMENT=1, BC_INVALID_HANDLE=2, BC_BUSY=3,
    BC_COMPILE_ERROR=4, BC_POLICY_ERROR=5, BC_ALLOCATION_ERROR=6,
    BC_INTERNAL_ERROR=7, BC_RESOURCE_LIMIT=8, BC_ABI_MISMATCH=9,
    BC_WRONG_THREAD=10, BC_RUN_TERMINATED=11, BC_ENGINE_POISONED=12
};
enum bc_event_kind {
    BC_YIELD=1, BC_HOST_REQUEST=2, BC_DONE=3, BC_TRAP=4, BC_FAILED=5, BC_WAIT=6
};
enum bc_reply_kind { BC_REPLY_OK=0, BC_REPLY_ERR=1, BC_REPLY_FATAL=2 };
enum bc_input_kind { BC_INPUT_NONE=0, BC_INPUT_BYTES=1 };
/* Bootstrap: output is not read. Revision/capacity are checked before NULL.
   A revision other than 2 or capacity <32 returns BC_ABI_MISMATCH, then NULL
   returns BC_BAD_ARGUMENT. Failure leaves caller memory untouched. Success
   writes exactly 32 bytes, even if capacity is larger. Only trusted native
   callers with writable storage of at least 32 bytes may request success.
   Initialize struct_size before calls and verify ABI before Engine creation.
   Check the artifact's documented exports before using other declarations.
   Trusted native callers only. NULL is valid for zero-length slices, not outputs.
   All child handles belong to their Engine's owner-thread lifetime. No callbacks.
   Handles use one bounded kind/generation registry, never native pointers.
   ABI query checks revision/capacity before writing. Other output structs use
   exact struct_size. Empty views are NULL/0; successful diagnostics use code 0,
   source_index UINT32_MAX, byte span 0/0 and an empty NUL message. */
BC_BOOTSTRAP_QUERY_API uint32_t BC_CALL bc_get_abi_info_v2(uint32_t requested_revision,
    uint32_t out_capacity, bc_abi_info *out_info);
BC_API uint32_t BC_CALL bc_engine_create(uint32_t requested_revision,
    bc_slice policy_json, bc_handle *out_engine, bc_diagnostic *diagnostic);
/* Scalar preview DLL: up to 16 sources and 4096 total UTF-8 source bytes,
   subject to the Engine's source and module limits. Each module slice names
   its source's declared module. The entry is public main::main with signature
   i32 main() or i32 main(ref u8[] data). Supply up to 16384 bytes of
   brownie.catalog/1 JSON to resolve host imports under the Engine policy.
   Source and catalog storage can be reused when the call returns. */
BC_API uint32_t BC_CALL bc_compile(bc_handle engine,
    const bc_source *sources, uint32_t source_count, bc_slice catalog_json,
    bc_handle *out_program, bc_diagnostic *diagnostic);
/* Scalar preview DLL: query the compiled entry on the owning thread.
   Initialize both output sizes. The read-only JSON view is valid until
   Program release. */
BC_API uint32_t BC_CALL bc_program_entry_info(bc_handle engine, bc_handle program,
    bc_slice module, bc_slice function, bc_entry_info *out_info, bc_diagnostic *diagnostic);
/* Scalar preview DLL: a brownie.run/0.3 configuration for the compiled entry
   with explicit requires and grants for verified host imports and output::emit.
   BC_INPUT_NONE requires empty input.
   BC_INPUT_BYTES copies the slice during preparation, including empty input.
   The Engine checks its policy before preparing and pinning the Program. */
BC_API uint32_t BC_CALL bc_instance_create(bc_handle engine, bc_handle program,
    bc_slice input, bc_slice run_config_json, bc_handle *out_instance, bc_diagnostic *diagnostic);
/* Work unit: dispatch, <=4096-byte bulk chunk or <=64-entry metadata chunk.
   Terminal events and metrics are immutable snapshots. A valid-instance API
   checkpoint may select deadline/cancel/Engine poison before semantic validation.
   A malformed reply after that checkpoint leaves request and Fuel unchanged.
   BC_DONE payload is read-only sealed output and expires at Instance destruction.
   BC_HOST_REQUEST carries an Instance-specific reply ID and read-only TLV
   payload. Copy it before replying, cancelling, destroying or stepping the
   same Instance again. A subsequent poll while waiting returns BC_WAIT. */
BC_API uint32_t BC_CALL bc_step(bc_handle instance, uint32_t max_work_units, bc_event *out_event);
/* Pass the exact request ID and one typed TLV (empty for BC_REPLY_FATAL).
   Reply storage may be reused when this call returns. BC_RUN_TERMINATED means
   the next step will report a terminal event. */
BC_API uint32_t BC_CALL bc_host_reply(bc_handle instance, uint64_t request_id,
    uint32_t reply_kind, bc_slice typed_payload, bc_diagnostic *diagnostic);
BC_API uint32_t BC_CALL bc_cancel(bc_handle instance);
BC_API uint32_t BC_CALL bc_instance_destroy(bc_handle instance);
BC_API uint32_t BC_CALL bc_program_release(bc_handle engine, bc_handle program);
BC_API uint32_t BC_CALL bc_engine_destroy(bc_handle engine);
#ifdef __cplusplus
}
#endif
#endif
