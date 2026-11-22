#include "restricted_worker_process_route.h"
#include "host_adapter_process.h"

bool bc_worker_process_route_init(bc_worker_process_route *owner,
    const uint8_t *path, size_t path_length, size_t reply_limit,
    uint32_t launches, size_t wire_limit, void *codec, bc_worker_process_encode encode,
    bc_worker_process_reply_size reply_size, bc_worker_process_decode decode) {
    if (!owner || !path || !path_length || path_length > 4096 || reply_limit > BC_ADAPTER_BODY_LIMIT ||
        !launches || !encode || !reply_size || !decode) return false;
    owner->budget = (bc_adapter_budget){.live_limit = 1, .launch_limit = launches, .wire_limit = wire_limit};
    owner->adapter = (bc_worker_process_adapter){.slot = {.budget = &owner->budget},
        .path = path, .path_length = path_length, .reply_limit = reply_limit, .codec = codec,
        .encode = encode, .reply_size = reply_size, .decode = decode};
    return true;
}

static bool process_begin(void *context, uint64_t correlation, const uint8_t *request,
    size_t length, uint64_t deadline) {
    bc_worker_process_adapter *adapter = context;
    uint8_t header[BC_ADAPTER_HEADER_BYTES] = {0};
    if (!adapter || length < 4 || !adapter->encode || !adapter->decode || !adapter->reply_size ||
        !bc_adapter_slot_admits(&adapter->slot, length - 4, adapter->reply_limit) ||
        !adapter->encode(adapter->codec, correlation, request, length, header)) return false;
    return bc_adapter_slot_start(&adapter->slot, adapter, adapter->path, adapter->path_length,
        header, request + 4, length - 4, adapter->reply_limit, (uintptr_t)deadline) != 0;
}

static bc_worker_host_progress process_poll(void *context, uint8_t *reply, size_t capacity, size_t *length) {
    bc_worker_process_adapter *adapter = context;
    bc_adapter_process *process = bc_adapter_slot_process(&adapter->slot, adapter, adapter->slot.generation);
    if (!process) return BC_WORKER_HOST_REJECTED;
    const bc_adapter_state state = bc_adapter_process_step(process);
    if (state == BC_ADAPTER_PENDING) return BC_WORKER_HOST_PENDING;
    if (state != BC_ADAPTER_HEADER && state != BC_ADAPTER_READY) return BC_WORKER_HOST_REJECTED;
    size_t size = 0;
    const uint8_t *frame = bc_adapter_process_frame(process, &size);
    if (!frame) return BC_WORKER_HOST_REJECTED;
    if (state == BC_ADAPTER_HEADER) {
        size_t body = 0;
        if (!adapter->reply_size(adapter->codec, frame, size, adapter->reply_limit, &body) ||
            !bc_adapter_process_accept_body(process, body)) return BC_WORKER_HOST_REJECTED;
        return BC_WORKER_HOST_PENDING;
    }
    *length = adapter->decode(adapter->codec, frame, size, reply, capacity);
    return *length && *length <= capacity ? BC_WORKER_HOST_READY : BC_WORKER_HOST_REJECTED;
}

static bool process_close(void *context) {
    bc_worker_process_adapter *adapter = context;
    return !adapter || bc_adapter_slot_close(&adapter->slot);
}

const bc_worker_host_adapter bc_worker_process_callbacks = {
    process_begin, process_poll, process_close, 1, BC_ADAPTER_PIPE_BUFFER_RESERVATION
};
