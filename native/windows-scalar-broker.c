#define FY_PROJECT_PRIVATE_BINDINGS
#include "fy_project.h"
#include "native/restricted_worker.c"
#include "native/restricted_worker_broker.c"
#include "native/restricted_worker_frame.c"
#include "native/restricted_worker_gate.c"
#include "native/restricted_worker_io.c"
#include "native/restricted_worker_pipes.c"
#include "native/restricted_worker_stage.c"
#include "native/restricted_worker_stream.c"
#include <userenv.h>

extern uint32_t bc_cli_enable_cancel(void);
extern uint32_t bc_cli_cancel_requested(void);

typedef struct scalar_expectation {
    uint32_t run;
    size_t source_bytes;
} scalar_expectation;

static bool validate_scalar(const void *raw, const uint8_t *body, size_t length) {
    const scalar_expectation *expected = raw;
    return fy_private_fn_776f726b65725f7363616c61725f62726f6b65723a3a76616c69646174655f726573756c74(
        body, length, expected->run, expected->source_bytes) != 0;
}

static PSID resolve_profile(const uint8_t *name, size_t length) {
    wchar_t profile[64];
    if (!name || !length || length >= _countof(profile)) return NULL;
    for (size_t i = 0; i < length; ++i) {
        uint8_t c = name[i];
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
            (c >= '0' && c <= '9') || c == '.' || c == '-')) return NULL;
        profile[i] = c;
    }
    profile[length] = 0;
    PSID sid = NULL;
    return SUCCEEDED(DeriveAppContainerSidFromAppContainerName(profile, &sid)) ? sid : NULL;
}

static bool self_location(wchar_t *image, wchar_t *directory, DWORD capacity) {
    const DWORD length = GetModuleFileNameW(NULL, image, capacity);
    if (!length || length >= capacity || !absolute_drive_path(image)) return false;
    wchar_t *separator = wcsrchr(image, L'\\');
    if (!separator) return false;
    const size_t prefix = (size_t)(separator - image) + 1;
    memcpy(directory, image, prefix * sizeof(*image));
    directory[prefix] = 0;
    return true;
}

static uint32_t run_scalar_broker(PSID sid, const wchar_t *image, const wchar_t *directory,
    const uint8_t *source, size_t source_length, uint32_t run, size_t fuel,
    uint8_t *reply, size_t *reply_length) {
    enum { source_cap = 4096, reply_cap = 256, metadata = 5, child_commit = 128 * 1024 * 1024 };
    uint8_t request[source_cap + metadata] = {(uint8_t)run};
    put_le(request + 1, 4, fuel);
    memcpy(request + metadata, source, source_length);
    const size_t request_length = metadata + source_length;
    uint8_t result[reply_cap];
    bc_worker_broker broker = {0};
    const size_t wire = 5 * BC_WORKER_FRAME_BYTES + request_length + sizeof(result) + 1;
    bc_worker_broker_budget budget = {.limit = {1, sizeof(broker) + request_length + sizeof(result),
        child_commit, wire}};
    wchar_t command[] = L"browniec --internal-scalar-worker";
    const scalar_expectation expected = {run, source_length};
    const bc_worker_broker_run config = {
        .budget = &budget, .application = image, .command_line = command, .directory = directory,
        .profile = sid, .commit_bytes = child_commit, .cpu_ms = 2000,
        .startup_ms = 4000, .io_idle_ms = 4000, .shutdown_grace_ms = 500,
        .deadline = now_ticks() + 100000000, .wire_limit = wire,
        .request = request, .request_length = request_length, .result = result,
        .result_capacity = sizeof(result), .validate = validate_scalar, .expectation = &expected
    };
    const DWORD started = bc_worker_broker_start(&broker, &config);
    size_t length = 0;
    const uint8_t *payload = NULL;
    if (!started) {
        while (!bc_cli_cancel_requested() && broker.gate.status == BC_WORKER_GATE_PENDING &&
            broker.phase != BC_WORKER_BROKER_FINISH) {
            bc_worker_broker_step(&broker);
            if (broker.io.pipe || broker.phase == BC_WORKER_BROKER_WAIT_EXIT) Sleep(1);
        }
        if (bc_cli_cancel_requested()) bc_worker_broker_cancel(&broker);
        else payload = bc_worker_broker_take(&broker, &length);
    }
    const bool expired = started == ERROR_TIMEOUT || broker.gate.status == BC_WORKER_GATE_EXPIRED;
    const bool cancelled = broker.gate.status == BC_WORKER_GATE_CANCELLED;
    while (!bc_worker_broker_close(&broker)) Sleep(1);
    if (expired) return 2;
    if (cancelled) return 3;
    if (!payload) return 0;
    memcpy(reply, payload, length);
    *reply_length = length;
    return 1;
}

uint32_t bc_scalar_broker_invoke(const uint8_t *profile, size_t profile_length,
    const uint8_t *source, size_t source_length, uint32_t run, size_t fuel,
    uint8_t *reply, size_t *reply_length) {
    if (!source || source_length > 4096 || run > 1 ||
        (!run && fuel) || fuel > UINT32_MAX || !reply || !reply_length) return 0;
    wchar_t image[4096], directory[4096];
    if (!self_location(image, directory, _countof(image)) || !bc_cli_enable_cancel()) return 0;
    if (profile) {
        PSID sid = resolve_profile(profile, profile_length);
        if (!sid) return 0;
        const uint32_t status = run_scalar_broker(sid, image, directory,
            source, source_length, run, fuel, reply, reply_length);
        FreeSid(sid);
        return status;
    }
    bc_worker_stage stage = {0};
    const DWORD setup = bc_worker_stage_open(&stage, image);
    uint8_t pending_reply[256];
    size_t pending_length = 0;
    uint32_t status = 0;
    if (bc_cli_cancel_requested()) status = 3;
    else if (!setup) status = run_scalar_broker(stage.profile, stage.image, stage.directory,
        source, source_length, run, fuel, pending_reply, &pending_length);
    const BOOL cleaned = bc_worker_stage_close(&stage);
    if (status != 1) return status;
    if (!cleaned) return 0;
    memcpy(reply, pending_reply, pending_length);
    *reply_length = pending_length;
    return 1;
}
