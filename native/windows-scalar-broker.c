#define FY_PROJECT_PRIVATE_BINDINGS
#include "fy_project.h"
#include "native/restricted_worker.c"
#include "native/restricted_worker_broker.c"
#include "native/restricted_worker_frame.c"
#include "native/restricted_worker_gate.c"
#include "native/restricted_worker_io.c"
#include "native/restricted_worker_payload.h"
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

typedef struct project_expectation {
    uint32_t run;
    const uint8_t *lengths;
    size_t count;
} project_expectation;

static bool validate_project(const void *raw, const uint8_t *body, size_t length) {
    const project_expectation *expected = raw;
    return fy_private_fn_776f726b65725f70726f6a6563745f62726f6b65723a3a76616c69646174655f726573756c74(
        body, length, expected->run, expected->lengths, expected->count) != 0;
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

typedef struct worker_exchange {
    const uint8_t *request;
    size_t request_length;
    bc_worker_result_validator validate;
    const void *expectation;
    bool project;
} worker_exchange;

typedef struct worker_limits {
    SIZE_T commit_bytes;
    DWORD cpu_ms, startup_ms, idle_ms, grace_ms, session_ms;
    size_t transport_bytes;
} worker_limits;

static const worker_limits default_limits = {128 * 1024 * 1024, 2000, 4000, 4000, 500, 10000,
    BC_WORKER_FRAME_BYTES + BC_WORKER_FRAME_PAYLOAD_MAX};

static uint32_t run_broker(PSID sid, const wchar_t *image, const wchar_t *directory,
    const worker_exchange *exchange, const worker_limits *limits, uint64_t deadline,
    uint8_t *reply, size_t *reply_length) {
    uint8_t result[BC_PROJECT_RESULT_MAX];
    const size_t result_capacity = exchange->project ? BC_PROJECT_RESULT_MAX : BC_SCALAR_RESULT_MAX;
    bc_worker_broker broker = {0};
    const size_t wire = 5 * BC_WORKER_FRAME_BYTES + exchange->request_length + result_capacity + 1;
    bc_worker_broker_budget budget = {.limit = {1, sizeof(broker) + exchange->request_length + result_capacity,
        limits->commit_bytes, limits->transport_bytes}};
    wchar_t scalar_command[] = L"browniec --internal-scalar-worker";
    wchar_t project_command[] = L"browniec --internal-project-worker";
    const bc_worker_broker_run config = {
        .budget = &budget, .application = image, .directory = directory,
        .command_line = exchange->project ? project_command : scalar_command,
        .profile = sid, .commit_bytes = limits->commit_bytes, .cpu_ms = limits->cpu_ms,
        .startup_ms = limits->startup_ms, .io_idle_ms = limits->idle_ms, .shutdown_grace_ms = limits->grace_ms,
        .deadline = deadline, .wire_limit = wire < limits->transport_bytes ? wire : limits->transport_bytes,
        .request = exchange->request, .request_length = exchange->request_length, .result = result,
        .result_capacity = result_capacity, .validate = exchange->validate, .expectation = exchange->expectation
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

static uint32_t invoke_broker(const uint8_t *profile, size_t profile_length,
    const worker_exchange *exchange, const worker_limits *limits, uint8_t *reply, size_t *reply_length) {
    wchar_t image[4096], directory[4096];
    if (!self_location(image, directory, _countof(image)) || !bc_cli_enable_cancel()) return 0;
    const uint64_t deadline = now_ticks() + (uint64_t)limits->session_ms * 10000;
    if (profile) {
        PSID sid = resolve_profile(profile, profile_length);
        if (!sid) return 0;
        const uint32_t status = run_broker(sid, image, directory, exchange, limits, deadline, reply, reply_length);
        FreeSid(sid);
        return status;
    }
    bc_worker_stage stage = {0};
    const DWORD setup = bc_worker_stage_open(&stage, image);
    uint8_t pending_reply[BC_PROJECT_RESULT_MAX];
    size_t pending_length = 0;
    uint32_t status = 0;
    if (now_ticks() >= deadline) status = 2;
    else if (bc_cli_cancel_requested()) status = 3;
    else if (!setup) status = run_broker(stage.profile, stage.image, stage.directory,
        exchange, limits, deadline, pending_reply, &pending_length);
    const BOOL cleaned = bc_worker_stage_close(&stage);
    if (status != 1) return status;
    if (!cleaned) return 0;
    memcpy(reply, pending_reply, pending_length);
    *reply_length = pending_length;
    return 1;
}

uint32_t bc_scalar_broker_invoke(const uint8_t *profile, size_t profile_length,
    const uint8_t *source, size_t source_length, uint32_t run, size_t fuel,
    uint8_t *reply, size_t *reply_length) {
    if (!source || source_length > BC_SCALAR_START_MAX - 5 || run > 1 ||
        (!run && fuel) || fuel > UINT32_MAX || !reply || !reply_length) return 0;
    uint8_t request[BC_SCALAR_START_MAX] = {(uint8_t)run};
    put_le(request + 1, 4, fuel);
    memcpy(request + 5, source, source_length);
    const scalar_expectation expected = {run, source_length};
    const worker_exchange exchange = {request, source_length + 5, validate_scalar, &expected, false};
    return invoke_broker(profile, profile_length, &exchange, &default_limits, reply, reply_length);
}

// Trusted in-process policy projection. The worker cannot supply these bytes.
static bool read_worker_limits(const uint8_t *raw, size_t length, worker_limits *limits) {
    if (!raw || length != 28) return false;
    *limits = (worker_limits){
        .commit_bytes = (SIZE_T)get_le(raw, 4), .cpu_ms = (DWORD)get_le(raw + 4, 4),
        .startup_ms = (DWORD)get_le(raw + 8, 4), .idle_ms = (DWORD)get_le(raw + 12, 4),
        .grace_ms = (DWORD)get_le(raw + 16, 4), .session_ms = (DWORD)get_le(raw + 20, 4),
        .transport_bytes = (size_t)get_le(raw + 24, 4)
    };
    return limits->commit_bytes >= 37748736 + limits->transport_bytes &&
        limits->commit_bytes <= 2147483648ULL && limits->cpu_ms && limits->cpu_ms <= 120000 &&
        limits->startup_ms && limits->startup_ms <= 60000 && limits->startup_ms <= limits->session_ms &&
        limits->idle_ms && limits->idle_ms <= 60000 && limits->grace_ms && limits->grace_ms <= 5000 &&
        limits->session_ms && limits->session_ms <= 120000 && limits->transport_bytes == 4194304;
}

uint32_t bc_project_broker_invoke(const uint8_t *request, size_t request_length, uint32_t run,
    const uint8_t *lengths, size_t count, const uint8_t *configuration, size_t config_size,
    uint8_t *reply, size_t *reply_length) {
    if (!request || request_length < 9 || request_length > BC_PROJECT_START_MAX ||
        run > 1 || request[0] != 2 + run || !lengths || !count || count > 32 ||
        count % 2 || !reply || !reply_length) return 0;
    const project_expectation expected = {run, lengths, count};
    const worker_exchange exchange = {request, request_length, validate_project, &expected, true};
    worker_limits limits = default_limits;
    if (config_size && !read_worker_limits(configuration, config_size, &limits)) return 0;
    return invoke_broker(NULL, 0, &exchange, &limits, reply, reply_length);
}
