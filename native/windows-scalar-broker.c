#define FY_PROJECT_PRIVATE_BINDINGS
#include "fy_project.h"
#include "native/restricted_worker.c"
#include "native/restricted_worker_broker.c"
#include "native/restricted_worker_frame.c"
#include "native/restricted_worker_gate.c"
#include "native/restricted_worker_io.c"
#include "native/restricted_worker_payload.h"
#include "native/restricted_worker_process_route.h"
#include "native/restricted_worker_pipes.c"
#include "native/restricted_worker_stage.c"
#include "native/restricted_worker_stream.c"
#include <userenv.h>
#include <bcrypt.h>

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
    uint32_t output;
    size_t output_limit;
} project_expectation;

static bool validate_project(const void *raw, const uint8_t *body, size_t length) {
    const project_expectation *expected = raw;
    return fy_private_fn_776f726b65725f70726f6a6563745f62726f6b65723a3a76616c69646174655f726573756c74(
        body, length, expected->run, expected->lengths, expected->count, expected->output, expected->output_limit) != 0;
}

static size_t respond_project_host(void *context, uint64_t correlation,
    const uint8_t *request, size_t length, uint8_t *reply, size_t capacity) {
    (void)correlation;
    return fy_private_fn_776f726b65725f70726f6a6563745f62726f6b65723a3a726573706f6e645f686f7374(context, request, length, reply, capacity);
}

enum { PROJECT_ROUTE_COUNT = 64, PROJECT_ROUTE_WORDS = 4 };
typedef fy_private_type_686f73745f70726f636573735f616461707465723a3a526f757465 project_route; /* host_process_adapter::Route */

void bc_project_broker_store_route(void *table, size_t id, const void *route, const uint8_t *path,
    size_t length, size_t capacity) {
    uintptr_t *row = (uintptr_t *)table + id * PROJECT_ROUTE_WORDS;
    row[0] = (uintptr_t)route;
    row[1] = (uintptr_t)path;
    row[2] = length;
    row[3] = capacity;
}

typedef struct project_process_codec {
    const uintptr_t *routes;
    bc_worker_process_adapter *adapter;
    const project_route *route;
    uint64_t run, correlation;
} project_process_codec;

static bool encode_project_process(void *raw, uint64_t correlation, const uint8_t *request,
    size_t length, uint8_t *header) {
    project_process_codec *codec = raw;
    if (length < 4) return false;
    const uint64_t id = get_le(request, 4);
    if (id >= PROJECT_ROUTE_COUNT) return false;
    const uintptr_t *row = codec->routes + id * PROJECT_ROUTE_WORDS;
    const project_route *selected = (const project_route *)row[0];
    if (!selected ||
        !fy_private_fn_776f726b65725f70726f6a6563745f62726f6b65723a3a70726f636573735f686561646572(
            selected, codec->run, correlation, request, length, header)) return false;
    codec->route = selected;
    codec->correlation = correlation;
    codec->adapter->path = (const uint8_t *)row[1];
    codec->adapter->path_length = row[2];
    return true;
}

static bool size_project_process_reply(void *raw, const uint8_t *header, size_t length,
    size_t limit, size_t *body) {
    const project_process_codec *codec = raw;
    const size_t accepted = fy_private_fn_776f726b65725f70726f6a6563745f62726f6b65723a3a70726f636573735f7265706c79(
        codec->route, codec->run, codec->correlation, header, length, NULL, limit);
    if (!accepted) return false;
    *body = accepted - 1;
    return true;
}

static size_t decode_project_process(void *raw, const uint8_t *frame, size_t length,
    uint8_t *reply, size_t capacity) {
    const project_process_codec *codec = raw;
    return fy_private_fn_776f726b65725f70726f6a6563745f62726f6b65723a3a70726f636573735f7265706c79(
        codec->route, codec->run, codec->correlation, frame, length, reply, capacity);
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
    bc_worker_broker_host host;
    const bc_worker_host_adapter *adapter;
    size_t adapter_wire_bytes;
    size_t adapter_parent_bytes;
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
    uint8_t *reply, size_t result_capacity, size_t *reply_length) {
    bc_worker_broker broker = {0};
    const size_t wire = exchange->host.max_calls ? limits->transport_bytes :
        5 * BC_WORKER_FRAME_BYTES + exchange->request_length + result_capacity + 1;
    const bc_worker_host_adapter *adapter = exchange->adapter;
    bc_worker_broker_budget budget = {.limit = {
        .sessions = 1,
        .parent_bytes = sizeof(broker) + exchange->request_length + result_capacity +
            exchange->host.request_capacity + exchange->host.reply_capacity +
            exchange->adapter_parent_bytes + bc_restricted_worker_launch_heap_bytes(),
        .child_commit_bytes = limits->commit_bytes + (adapter ? adapter->child_commit_bytes : 0),
        .wire_bytes = limits->transport_bytes,
        .adapter_slots = adapter ? 1 : 0,
        .io_slots = BC_WORKER_BROKER_IO_SLOTS + (adapter ? (size_t)adapter->io_slots : 0),
        .pipe_buffer_bytes = BC_WORKER_PIPE_BUFFER_RESERVATION +
            (adapter ? (size_t)adapter->pipe_buffer_bytes : 0),
        .host_request_bytes = exchange->host.max_calls * exchange->host.request_capacity,
        .host_reply_bytes = exchange->host.max_calls * exchange->host.reply_capacity,
        .handle_slots = BC_WORKER_BROKER_HANDLE_SLOTS + (adapter ? (size_t)adapter->handle_slots : 0)
    }};
    wchar_t scalar_command[] = L"browniec --internal-scalar-worker";
    wchar_t project_command[] = L"browniec --internal-project-worker";
    const bc_worker_broker_run config = {
        .budget = &budget, .application = image, .directory = directory,
        .command_line = exchange->project ? project_command : scalar_command,
        .profile = sid, .commit_bytes = limits->commit_bytes, .cpu_ms = limits->cpu_ms,
        .startup_ms = limits->startup_ms, .io_idle_ms = limits->idle_ms, .shutdown_grace_ms = limits->grace_ms,
        .deadline = deadline, .wire_limit = wire < limits->transport_bytes ? wire : limits->transport_bytes,
        .adapter_wire_bytes = exchange->adapter_wire_bytes,
        .adapter_parent_bytes = exchange->adapter_parent_bytes,
        .request = exchange->request, .request_length = exchange->request_length, .result = reply,
        .result_capacity = result_capacity, .validate = exchange->validate, .expectation = exchange->expectation,
        .host = exchange->host, .adapter = exchange->adapter
    };
    const DWORD started = bc_worker_broker_start(&broker, &config);
    size_t length = 0;
    const uint8_t *payload = NULL;
    if (!started) {
        while (!bc_cli_cancel_requested() && broker.gate.status == BC_WORKER_GATE_PENDING &&
            broker.phase != BC_WORKER_BROKER_FINISH) {
            bc_worker_broker_step(&broker);
            if (broker.io.pipe || broker.phase == BC_WORKER_BROKER_WAIT_EXIT ||
                broker.phase == BC_WORKER_BROKER_WAIT_HOST || broker.phase == BC_WORKER_BROKER_REAP_HOST) Sleep(1);
        }
        if (bc_cli_cancel_requested()) bc_worker_broker_cancel(&broker);
        else payload = bc_worker_broker_take(&broker, &length);
    }
    const bool expired = started == ERROR_TIMEOUT || broker.gate.status == BC_WORKER_GATE_EXPIRED;
    const bool cancelled = broker.gate.status == BC_WORKER_GATE_CANCELLED;
    while (!bc_worker_broker_close(&broker)) Sleep(1);
    if (expired) return 2;
    if (cancelled) return 3;
    if (payload != reply) return 0;
    *reply_length = length;
    return 1;
}

static DWORD stage_stop(void *context) {
    const uint64_t deadline = *(const uint64_t *)context;
    if (now_ticks() >= deadline) return ERROR_TIMEOUT;
    return bc_cli_cancel_requested() ? ERROR_CANCELLED : ERROR_SUCCESS;
}

static uint32_t invoke_broker(const uint8_t *profile, size_t profile_length,
    const worker_exchange *exchange, const worker_limits *limits, uint8_t *reply, size_t capacity, size_t *reply_length) {
    *reply_length = 0;
    wchar_t image[4096], directory[4096];
    if (!self_location(image, directory, _countof(image)) || !bc_cli_enable_cancel()) return 0;
    uint64_t deadline = now_ticks() + (uint64_t)limits->session_ms * 10000;
    if (profile) {
        PSID sid = resolve_profile(profile, profile_length);
        if (!sid) return 0;
        const uint32_t status = run_broker(sid, image, directory, exchange, limits, deadline, reply, capacity, reply_length);
        FreeSid(sid);
        return status;
    }
    bc_worker_stage stage = {0};
    const DWORD setup = bc_worker_stage_open(&stage, image, stage_stop, &deadline);
    const DWORD stop = setup ? setup : stage_stop(&deadline);
    size_t pending_length = 0;
    uint32_t status = 0;
    if (stop == ERROR_TIMEOUT) status = 2;
    else if (stop == ERROR_CANCELLED) status = 3;
    else if (!stop) status = run_broker(stage.profile, stage.image, stage.directory,
        exchange, limits, deadline, reply, capacity, &pending_length);
    const BOOL cleaned = bc_worker_stage_close(&stage);
    if (status != 1) return status;
    if (!cleaned) return 0;
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
    const worker_exchange exchange = {request, source_length + 5, validate_scalar, &expected, false, {0}, NULL, 0, 0};
    return invoke_broker(profile, profile_length, &exchange, &default_limits, reply, BC_SCALAR_RESULT_MAX, reply_length);
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

/* All route descriptors and path buffers stay live. Only one launch can be
   active, so reserve the largest launch heap rather than their sum. */
static size_t process_parent_bytes(const uintptr_t *routes, size_t route_slots,
    const uint8_t **first, size_t *first_length) {
    const size_t table_bytes = PROJECT_ROUTE_COUNT * PROJECT_ROUTE_WORDS * sizeof(*routes);
    if (!route_slots || route_slots > PROJECT_ROUTE_COUNT) return 0;
    size_t bytes = table_bytes + route_slots * sizeof(project_route) +
        sizeof(bc_worker_process_route) + sizeof(project_process_codec);
    size_t peak = 0, count = 0;
    for (size_t id = 0; id < PROJECT_ROUTE_COUNT; ++id) {
        const uintptr_t *row = routes + id * PROJECT_ROUTE_WORDS;
        if (!row[0]) continue;
        const uint8_t *path = (const uint8_t *)row[1];
        if (++count > route_slots || row[3] < row[2] || row[3] > SIZE_MAX - bytes ||
            !bc_adapter_path_valid(path, row[2])) return 0;
        const size_t launch = bc_adapter_slot_heap_bytes(path, row[2]);
        if (!launch) return 0;
        if (launch > peak) peak = launch;
        bytes += row[3];
        *first = path;
        *first_length = row[2];
    }
    return peak && peak <= SIZE_MAX - bytes ? bytes + peak : 0;
}

uint32_t bc_project_broker_invoke(const uint8_t *request, size_t request_length, uint32_t run,
    const uint8_t *lengths, size_t count, const uint8_t *configuration, size_t config_size,
    uint32_t output, size_t output_limit, const uint8_t *host_limits, const void *context,
    const void *route_table, size_t route_slots,
    uint8_t *reply, size_t capacity, size_t *reply_length) {
    const uintptr_t *routes = route_table;
    if (!request || request_length < 9 || request_length > BC_PROJECT_START_MAX ||
        run > 1 || !lengths || !count || count > 32 || count % 2 || !reply || !reply_length ||
        output > 1 || (output && (!config_size || !run)) ||
        (!output && output_limit) || output_limit > BC_PROJECT_OUTPUT_MAX ||
        capacity != BC_PROJECT_RESULT_BASE + (output ? 3 + output_limit : 0)) return 0;
    if ((routes != NULL) != (route_slots != 0) || (routes && (context || !run))) return 0;
    const bool dispatch = routes || context;
    const bool host = config_size && request_length >= 25 && request[0] >= 7 && request[0] <= 9;
    const bool input_run = config_size && run && request[0] == 6 && request_length >= 21;
    if (host) {
        if ((run != 0) != (request[0] != 7) || dispatch != (run != 0)) return 0;
    } else if (dispatch || (!input_run && request[0] != (config_size ? 4u : 2u) + run)) {
        return 0;
    }
    const project_expectation expected = {run, lengths, count, output, output_limit};
    worker_exchange exchange = {request, request_length, validate_project, &expected, true, {0}, NULL, 0, 0};
    worker_limits limits = default_limits;
    if (config_size && !read_worker_limits(configuration, config_size, &limits)) return 0;
    if (!dispatch) return invoke_broker(NULL, 0, &exchange, &limits, reply, capacity, reply_length);
    if (!host_limits) return 0;
    const uint32_t calls = (uint32_t)get_le(host_limits, 4);
    if (!calls) return invoke_broker(NULL, 0, &exchange, &limits, reply, capacity, reply_length);
    const size_t request_cap = (size_t)get_le(host_limits + 4, 4);
    const size_t reply_cap = (size_t)get_le(host_limits + 8, 4);
    if (calls > 65535 || request_cap < 4 || request_cap > 4100 || !reply_cap || reply_cap > 4097) return 0;
    bc_worker_process_route route;
    project_process_codec codec = {.routes = routes, .adapter = &route.adapter};
    if (routes) {
        const uint8_t *path = NULL;
        size_t path_length = 0;
        exchange.adapter_parent_bytes = process_parent_bytes(routes, route_slots, &path, &path_length);
        if (!exchange.adapter_parent_bytes) return 0;
        const size_t fixed = 5 * BC_WORKER_FRAME_BYTES + request_length + capacity + 1;
        const size_t per_call = 2 * BC_WORKER_FRAME_BYTES + request_cap + reply_cap;
        const size_t adapter_wire = 128 + request_cap - 4 + reply_cap;
        if (fixed > limits.transport_bytes ||
            calls > (limits.transport_bytes - fixed) / (per_call + adapter_wire) ||
            BCryptGenRandom(NULL, (uint8_t *)&codec.run, sizeof(codec.run),
                BCRYPT_USE_SYSTEM_PREFERRED_RNG) < 0 || !codec.run) return 0;
        exchange.adapter_wire_bytes = calls * adapter_wire;
        if (!bc_worker_process_route_init(&route, path, path_length, reply_cap - 1,
            calls, exchange.adapter_wire_bytes, &codec, encode_project_process, size_project_process_reply,
            decode_project_process)) return 0;
        exchange.adapter = &bc_worker_process_callbacks;
    }
    uint8_t *staging = HeapAlloc(GetProcessHeap(), 0, request_cap + reply_cap);
    uint32_t status = 0;
    if (staging) {
        exchange.host = (bc_worker_broker_host){routes ? NULL : respond_project_host,
            routes ? (void *)&route.adapter : (void *)context,
            staging, staging + request_cap, request_cap, reply_cap, calls};
        status = invoke_broker(NULL, 0, &exchange, &limits, reply, capacity, reply_length);
        HeapFree(GetProcessHeap(), 0, staging);
    }
    return status;
}
