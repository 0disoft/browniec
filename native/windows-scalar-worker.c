#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include "native/restricted_worker_frame.c"

static HANDLE result_pipe;
static bc_worker_frame result_frame;

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

size_t bc_scalar_worker_start(uint8_t *request, size_t capacity) {
    enum { metadata_bytes = 5, source_limit = 4096 };
    if (result_pipe || !request || capacity != metadata_bytes + source_limit || !confined()) return 0;
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
    expected.length = (uint32_t)capacity;
    if (!receive(input, &expected, &session) || session.length < metadata_bytes ||
        !transfer(input, request, NULL, session.length)) return 0;
    session.kind = BC_WORKER_RESULT;
    result_frame = session;
    result_pipe = output;
    return session.length;
}

uint32_t bc_scalar_worker_finish(const uint8_t *result, size_t length) {
    if (!result_pipe || !result || !length || length > 256) return 0;
    HANDLE output = result_pipe;
    result_pipe = NULL;
    result_frame.length = (uint32_t)length;
    return send(output, &result_frame) && transfer(output, NULL, result, result_frame.length);
}
