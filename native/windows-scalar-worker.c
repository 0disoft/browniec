#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include "native/restricted_worker_frame.h"
#include "native/restricted_worker_payload.h"

static HANDLE input_pipe, result_pipe;
static bc_worker_frame result_frame;
static size_t result_capacity;

static bool confined(void) {
    BOOL assigned = FALSE;
    HANDLE token = NULL;
    if (!IsProcessInJob(GetCurrentProcess(), NULL, &assigned) || !assigned ||
        !OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return false;
    DWORD app_container = 0, size = 0;
    const BOOL read = GetTokenInformation(token, TokenIsAppContainer,
        &app_container, sizeof(app_container), &size);
    CloseHandle(token);
    return read && app_container;
}

static bool client_pipe(HANDLE pipe, ULONG *pid) {
    DWORD flags;
    return GetNamedPipeInfo(pipe, &flags, NULL, NULL, NULL) &&
        !(flags & (PIPE_SERVER_END | PIPE_TYPE_MESSAGE)) &&
        GetNamedPipeServerProcessId(pipe, pid) && *pid && *pid != GetCurrentProcessId();
}

static bool transfer(HANDLE pipe, uint8_t *in, const uint8_t *out, DWORD length) {
    size_t used = 0;
    while (used < length) {
        DWORD count = 0;
        const DWORD pending = length - (DWORD)used;
        const BOOL ok = in ? ReadFile(pipe, in + used, pending, &count, NULL) :
            WriteFile(pipe, out + used, pending, &count, NULL);
        if (!ok || !count || count > pending) return false;
        used += count;
    }
    return true;
}

static bool receive(HANDLE input, const bc_worker_frame *expected, bc_worker_frame *received) {
    uint8_t wire[BC_WORKER_FRAME_BYTES];
    return transfer(input, wire, NULL, sizeof(wire)) &&
        bc_worker_frame_preflight(wire, sizeof(wire), expected, received);
}

static bool send(HANDLE output, const bc_worker_frame *frame) {
    uint8_t wire[BC_WORKER_FRAME_BYTES];
    return bc_worker_frame_encode(wire, frame) && transfer(output, NULL, wire, sizeof(wire));
}

static size_t begin(bool project) {
    if (input_pipe || result_pipe || !confined()) return 0;
    HANDLE input = GetStdHandle(STD_INPUT_HANDLE), output = GetStdHandle(STD_OUTPUT_HANDLE);
    ULONG input_pid = 0, output_pid = 0;
    if (input == output || !client_pipe(input, &input_pid) ||
        !client_pipe(output, &output_pid) || input_pid != output_pid) return 0;
    bc_worker_frame expected = {.kind = BC_WORKER_HELLO, .sequence = 1};
    bc_worker_frame session;
    if (!receive(input, &expected, &session)) return 0;
    session.kind = BC_WORKER_READY;
    if (!send(output, &session)) return 0;
    expected = session;
    expected.kind = BC_WORKER_START;
    expected.sequence = 2;
    expected.length = project ? BC_PROJECT_START_MAX : BC_SCALAR_START_MAX;
    if (!receive(input, &expected, &session) || session.length < (project ? 9u : 5u)) return 0;
    input_pipe = input;
    session.kind = BC_WORKER_RESULT;
    result_frame = session;
    result_pipe = output;
    result_capacity = project ? BC_PROJECT_RESULT_MAX : BC_SCALAR_RESULT_MAX;
    return session.length;
}

static bool read_start(uint8_t *request, size_t length) {
    if (!input_pipe || !request || length != result_frame.length ||
        !transfer(input_pipe, request, NULL, result_frame.length)) return false;
    input_pipe = NULL;
    return true;
}

size_t bc_scalar_worker_start(uint8_t *request, size_t capacity) {
    if (!request || capacity != BC_SCALAR_START_MAX) return 0;
    const size_t length = begin(false);
    return length && read_start(request, length) ? length : 0;
}

size_t bc_project_worker_begin(void) {
    return begin(true);
}

uint32_t bc_project_worker_read(uint8_t *request, size_t length) {
    return read_start(request, length);
}

uint32_t bc_scalar_worker_finish(const uint8_t *result, size_t length) {
    if (input_pipe || !result_pipe || !result || !length || length > result_capacity) return 0;
    HANDLE output = result_pipe;
    result_pipe = NULL;
    result_frame.length = (uint32_t)length;
    return send(output, &result_frame) && transfer(output, NULL, result, result_frame.length);
}
