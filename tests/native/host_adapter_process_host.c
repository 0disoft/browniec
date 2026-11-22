#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include "../../native/host_adapter_process.h"

static void check(int ok, const char *what) {
    if (!ok) {
        fprintf(stderr, "%s (Windows error %lu)\n", what, GetLastError());
        exit(1);
    }
}

static void read_exact(HANDLE input, uint8_t *out, DWORD length) {
    while (length) {
        DWORD got = 0;
        check(ReadFile(input, out, length, &got, NULL) && got, "child request read");
        out += got;
        length -= got;
    }
}

static void write_exact(HANDLE output, const uint8_t *data, DWORD length) {
    DWORD done;
    check(WriteFile(output, data, length, &done, NULL) && done == length, "child reply write");
}

static int child(wchar_t mode) {
    HANDLE input = GetStdHandle(STD_INPUT_HANDLE), output = GetStdHandle(STD_OUTPUT_HANDLE);
    uint8_t header[BC_ADAPTER_HEADER_BYTES];
    uint8_t body[BC_ADAPTER_BODY_LIMIT];
    read_exact(input, header, sizeof(header));
    read_exact(input, body, sizeof(body));
    check(!memcmp(header, "BCA1", 4) && header[4] == 0 &&
        header[28] == 0 && header[29] == 16, "child request header");
    for (size_t i = 0; i < sizeof(body); ++i) check(body[i] == (uint8_t)i, "child request body");
    DWORD got;
    check(!ReadFile(input, body, 1, &got, NULL) && GetLastError() == ERROR_BROKEN_PIPE,
        "child request EOF");
    header[4] = mode == L'z' ? 3 : 1;
    header[28] = mode == L'z' ? 0 : 12;
    header[29] = 0;
    write_exact(output, header, 9);
    write_exact(output, header+9, sizeof(header)-9);
    if (mode == L'z') return 0;
    static const uint8_t answer[] = {3,0,0,0,4,0,0,0,42,0,0,0,0};
    write_exact(output, answer, 3);
    if (mode == L's' || mode == L'd') Sleep(INFINITE);
    if (mode == L't') return 0;
    write_exact(output, answer+3, mode == L'x' ? 10 : 9);
    if (mode == L'e') return 9;
    if (mode == L'h') {
        CloseHandle(output);
        Sleep(INFINITE);
    }
    return 0;
}

static void fixture_mode(wchar_t mode) {
    wchar_t value[] = {mode, 0};
    check(SetEnvironmentVariableW(L"BC_TEST_ADAPTER_FIXTURE", mode ? value : NULL), "fixture mode");
}

static void make_request(uint8_t *header, uint8_t *body) {
    memcpy(header, "BCA1", 4);
    header[29] = 16;
    for (size_t i = 0; i < BC_ADAPTER_BODY_LIMIT; ++i) body[i] = (uint8_t)i;
}

static bc_adapter_process *start(const wchar_t *path, wchar_t mode, uint64_t deadline) {
    fixture_mode(mode);
    uint8_t header[BC_ADAPTER_HEADER_BYTES] = {0};
    uint8_t body[BC_ADAPTER_BODY_LIMIT];
    make_request(header, body);
    bc_adapter_process *session = bc_adapter_process_start(path, wcslen(path),
        header, body, sizeof(body), deadline, 0);
    fixture_mode(0);
    return session;
}

static uint64_t deadline_after(DWORD milliseconds) {
    ULONGLONG ticks;
    QueryInterruptTimePrecise(&ticks);
    return ticks + UINT64_C(10000)*milliseconds;
}

static bc_adapter_state wait_event(bc_adapter_process *session, uint64_t until) {
    bc_adapter_state state;
    while ((state = bc_adapter_process_step(session)) == BC_ADAPTER_PENDING) {
        check(GetTickCount64() < until, "step watchdog");
        Sleep(1);
    }
    return state;
}

static void reap(bc_adapter_process *session) {
    const uint64_t until = GetTickCount64()+3000;
    while (!bc_adapter_process_close(session)) {
        check(GetTickCount64() < until, "reaping watchdog");
        Sleep(1);
    }
}

static void exchange(const wchar_t *path, wchar_t mode, bc_adapter_state expected) {
    DWORD limit = (mode == L'h' || mode == L'd') ? 1000 : 3000;
    uint64_t watchdog = GetTickCount64()+limit+3000;
    uint64_t deadline = deadline_after(limit);
    bc_adapter_process *session = start(path, mode, deadline);
    check(session != NULL, "process launch");
    check(wait_event(session, watchdog) == BC_ADAPTER_HEADER, "header phase");
    size_t length = 99;
    const uint8_t *frame = bc_adapter_process_frame(session, &length);
    check(frame && length == BC_ADAPTER_HEADER_BYTES && !memcmp(frame, "BCA1", 4),
        "only header visible before approval");
    size_t body = mode == L'z' ? 0 : 12;
    check(!bc_adapter_process_accept_body(session, BC_ADAPTER_BODY_LIMIT+1),
        "oversized body admission");
    check(bc_adapter_process_accept_body(session, body), "accept exact body");
    check(!bc_adapter_process_accept_body(session, body), "body admission is one-shot");
    check(!bc_adapter_process_frame(session, &length) && length == 0, "hide pending bytes");
    if (mode == L's') {
        for (int i = 0; i < 8; ++i) {
            check(bc_adapter_process_step(session) == BC_ADAPTER_PENDING, "partial body remains pending");
            Sleep(1);
        }
        bc_adapter_process_cancel(session);
    }
    check(wait_event(session, watchdog) == expected, "expected terminal transport state");
    bc_adapter_process_cancel(session);
    check(bc_adapter_process_step(session) == expected, "first terminal state preserved");
    frame = bc_adapter_process_frame(session, &length);
    if (expected == BC_ADAPTER_READY) {
        check(frame && length == BC_ADAPTER_HEADER_BYTES+body, "ready frame length");
        if (body) check(frame[BC_ADAPTER_HEADER_BYTES+8] == 42, "ready body");
    } else {
        check(!frame && length == 0, "hide failed or partial frame");
    }
    reap(session);
}

static uintptr_t start_slot(bc_adapter_slot *slot, const wchar_t *path, wchar_t mode) {
    uint8_t path_utf8[4096], header[BC_ADAPTER_HEADER_BYTES] = {0}, body[BC_ADAPTER_BODY_LIMIT];
    int length = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, path, (int)wcslen(path),
        (char *)path_utf8, sizeof(path_utf8), NULL, NULL);
    check(length > 0, "slot fixture path");
    make_request(header, body);
    fixture_mode(mode);
    uintptr_t generation = bc_adapter_slot_start(slot, slot->budget, path_utf8, (size_t)length,
        header, body, sizeof(body), 12, deadline_after(3000));
    fixture_mode(0);
    return generation;
}

static void reap_slot(bc_adapter_slot *slot) {
    uint64_t until = GetTickCount64()+3000;
    while (!bc_adapter_slot_close(slot)) {
        check(GetTickCount64() < until, "slot reaping watchdog");
        Sleep(1);
    }
}

static void aggregate(const wchar_t *path, const wchar_t *missing) {
    const size_t frame_budget = 2 * BC_ADAPTER_HEADER_BYTES + BC_ADAPTER_BODY_LIMIT + 12 + 1;
    bc_adapter_budget short_wire = {.live_limit = 2, .launch_limit = 3, .wire_limit = frame_budget-1};
    bc_adapter_slot denied = {.budget = &short_wire};
    check(!start_slot(&denied, path, L'g') && !short_wire.live && !short_wire.launches &&
        !short_wire.wire && !denied.generation, "one byte short leaves admission untouched");

    bc_adapter_budget budget = {.live_limit = 2, .launch_limit = 3, .wire_limit = 4*frame_budget};
    bc_adapter_slot a = {.budget = &budget}, b = {.budget = &budget}, c = {.budget = &budget};
    uintptr_t first = start_slot(&a, path, L'g'), second = start_slot(&b, path, L's');
    check(first && second && budget.live == 2 && budget.launches == 2 &&
        budget.wire == 2*frame_budget, "two slots charge the shared budget");
    bc_adapter_process *active = bc_adapter_slot_process(&a, &budget, first);
    bc_adapter_process *stalled = bc_adapter_slot_process(&b, &budget, second);
    check(active && stalled, "resolve concurrent leases");
    uint64_t until = GetTickCount64()+3000;
    check(wait_event(active, until) == BC_ADAPTER_HEADER, "admitted reply");
    check(!bc_adapter_process_accept_body(active, 13) && bc_adapter_process_accept_body(active, 12),
        "only reserved reply bytes may be read");
    check(wait_event(stalled, until) == BC_ADAPTER_HEADER, "stalled reply header");
    check(bc_adapter_process_accept_body(stalled, 12), "approve stalled reply");
    bc_adapter_process_step(stalled);
    bc_adapter_process_cancel(stalled);
    check(!start_slot(&c, path, L'g') && budget.live == 2 && budget.launches == 2 &&
        budget.wire == 2*frame_budget, "cancelled lease still consumes a slot");
    reap_slot(&b);
    check(budget.live == 1 && !bc_adapter_slot_process(&b, &budget, second),
        "reaping releases the live slot and invalidates its generation");
    check(!start_slot(&c, missing, L'g') && budget.live == 1 && budget.launches == 3 &&
        budget.wire == 3*frame_budget, "failed launch keeps only its cumulative charges");
    check(!bc_adapter_slot_admits(&b, BC_ADAPTER_BODY_LIMIT, 12),
        "launch count can reject despite remaining wire and live capacity");
    check(wait_event(active, until) == BC_ADAPTER_READY, "peer still completes");
    reap_slot(&a);
    check(bc_adapter_slot_close(&a) && budget.live == 0 && budget.launches == 3 &&
        budget.wire == 3*frame_budget, "closing twice refunds only once");

    bc_adapter_budget exact_wire = {.live_limit = 1, .launch_limit = 2, .wire_limit = frame_budget};
    bc_adapter_slot exact = {.budget = &exact_wire};
    check(start_slot(&exact, path, L'g') && exact_wire.wire == frame_budget, "exact wire limit accepted");
    reap_slot(&exact);
    check(!bc_adapter_slot_admits(&exact, BC_ADAPTER_BODY_LIMIT, 12), "reaping cannot replenish wire");
}

int wmain(void) {
    wchar_t mode[2];
    if (GetEnvironmentVariableW(L"BC_TEST_ADAPTER_FIXTURE", mode, _countof(mode)) == 1)
        return child(mode[0]);
    wchar_t path[32767];
    DWORD path_len = GetModuleFileNameW(NULL, path, _countof(path));
    check(path_len && path_len < _countof(path), "fixture module path");
    /* Windows initializes process-wide cryptography and launch handles on first use. */
    const wchar_t *missing = L"C:\\Windows\\browniec-fixture-not-present.exe";
    check(!start(missing, L'g', deadline_after(3000)), "warm failed launch");
    exchange(path, L'g', BC_ADAPTER_READY);
    DWORD baseline, after;
    check(GetProcessHandleCount(GetCurrentProcess(), &baseline), "baseline handles");
    check(!start(path, L'g', deadline_after(0)), "expired startup");
    check(!start(L"relative.exe", L'g', deadline_after(3000)), "relative path");
    check(!start(missing, L'g', deadline_after(3000)), "launch failure unwinds");
    exchange(path, L'g', BC_ADAPTER_READY);
    exchange(path, L'z', BC_ADAPTER_READY);
    exchange(path, L't', BC_ADAPTER_FAILED);
    exchange(path, L'x', BC_ADAPTER_FAILED);
    exchange(path, L'e', BC_ADAPTER_FAILED);
    exchange(path, L's', BC_ADAPTER_CANCELLED);
    exchange(path, L'd', BC_ADAPTER_DEADLINE);
    exchange(path, L'h', BC_ADAPTER_DEADLINE);
    aggregate(path, missing);
    check(GetProcessHandleCount(GetCurrentProcess(), &after), "final handle count");
    if (after != baseline) fprintf(stderr, "handles before=%lu after=%lu\n", baseline, after);
    check(after == baseline, "handle ownership balanced");
    puts("{\"processCases\":8,\"launchRejections\":3,\"aggregateCases\":1,\"handleDelta\":0}");
    return 0;
}
