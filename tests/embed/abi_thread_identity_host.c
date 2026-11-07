#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include "abi_thread_identity.h"

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); return 1; } } while (0)
typedef struct task {
    bc_abi_thread_identity first;
    bc_abi_thread_identity foreign;
    uint32_t expected;
    unsigned iterations;
    int fail;
} task;
static volatile LONG shared_count;

static DWORD WINAPI run_task(LPVOID raw) {
    task *t = raw;
    unsigned i;
    for (i = 0; i < t->iterations; ++i) {
        bc_abi_thread_identity current = {UINT64_MAX, UINT64_MAX};
        uint32_t status;
        unsigned attempts = 0;
        do {
            status = bc_abi_guard_enter(&current);
            if (status == 3) { SwitchToThread(); }
        } while (status == 3 && ++attempts < 1000000);
        if (status != t->expected) { t->fail = 1; return 1; }
        if (status != 0) {
            if (current.thread != UINT64_MAX || current.lifetime != UINT64_MAX) { t->fail = 1; }
            continue;
        }
        if (current.thread != GetCurrentThreadId() || current.lifetime == 0 ||
            (i && (current.thread != t->first.thread || current.lifetime != t->first.lifetime))) {
            t->fail = 1;
        }
        if (!i) { t->first = current; }
        /* Wrong-thread and wrong-lifetime leave must preserve the real guard. */
        if (t->foreign.thread && bc_abi_guard_leave(t->foreign) != 10) { t->fail = 1; }
        {
            bc_abi_thread_identity changed = current;
            bc_abi_thread_identity ignored = {9, 9};
            changed.lifetime = current.lifetime == UINT64_MAX ? 1 : current.lifetime + 1;
            if (bc_abi_guard_leave(changed) != 7 || bc_abi_guard_enter(&ignored) != 3 ||
                ignored.thread != 9 || ignored.lifetime != 9) { t->fail = 1; }
        }
        /* Deliberately ordinary load/store; exclusion must protect the increment. */
        {
            LONG before = shared_count;
            SwitchToThread();
            shared_count = before + 1;
        }
        if (bc_abi_guard_leave(current) != 0 || bc_abi_guard_leave(current) != 7) { t->fail = 1; }
    }
    return t->fail ? 1 : 0;
}

int main(void) {
    bc_abi_thread_identity main_id, again, untouched = {77, 88};
    task tasks[8]; HANDLE threads[8]; size_t i, j;
    CHECK(sizeof(void *) == 8);
    CHECK(bc_abi_guard_enter(NULL) == 1);
    CHECK(bc_abi_guard_enter(&main_id) == 0);
    CHECK(main_id.thread == GetCurrentThreadId() && main_id.lifetime != 0);
    CHECK(bc_abi_guard_enter(&untouched) == 3 && untouched.thread == 77 && untouched.lifetime == 88);
    memset(tasks, 0, sizeof(tasks));
    for (i = 0; i < 8; ++i) {
        tasks[i].iterations = 128; tasks[i].foreign = main_id;
        threads[i] = CreateThread(NULL, 0, run_task, &tasks[i], 0, NULL); CHECK(threads[i] != NULL);
    }
    CHECK(bc_abi_guard_leave(main_id) == 0);
    CHECK(WaitForMultipleObjects(8, threads, TRUE, 30000) == WAIT_OBJECT_0);
    for (i = 0; i < 8; ++i) {
        CHECK(CloseHandle(threads[i])); CHECK(!tasks[i].fail);
        CHECK(tasks[i].first.lifetime != main_id.lifetime);
        for (j = 0; j < i; ++j) { CHECK(tasks[i].first.lifetime != tasks[j].first.lifetime); }
    }
    CHECK(shared_count == 1024);
    /* Exited thread slots never reuse a ticket, including sequential threads. */
    for (i = 0; i < 32; ++i) {
        task t = {{0, 0}, {0, 0}, 0, 1, 0}; DWORD exit_code;
        HANDLE thread = CreateThread(NULL, 0, run_task, &t, 0, NULL); CHECK(thread != NULL);
        CHECK(WaitForSingleObject(thread, 30000) == WAIT_OBJECT_0);
        CHECK(GetExitCodeThread(thread, &exit_code) && exit_code == 0 && !t.fail);
        CHECK(CloseHandle(thread));
        CHECK(t.first.lifetime > main_id.lifetime);
        for (j = 0; j < 8; ++j) { CHECK(t.first.lifetime > tasks[j].first.lifetime); }
    }
    CHECK(bc_abi_guard_enter(&again) == 0);
    CHECK(again.thread == main_id.thread && again.lifetime == main_id.lifetime);
    CHECK(bc_abi_test_exhaust_next(again) == 0);
    CHECK(bc_abi_guard_leave(again) == 0);
    {
        task last = {{0, 0}, {0, 0}, 0, 1, 0};
        task denied = {{0, 0}, {0, 0}, 8, 1, 0};
        HANDLE thread = CreateThread(NULL, 0, run_task, &last, 0, NULL); CHECK(thread != NULL);
        CHECK(WaitForSingleObject(thread, 30000) == WAIT_OBJECT_0 && !last.fail); CHECK(CloseHandle(thread));
        CHECK(last.first.lifetime == UINT64_MAX);
        thread = CreateThread(NULL, 0, run_task, &denied, 0, NULL); CHECK(thread != NULL);
        CHECK(WaitForSingleObject(thread, 30000) == WAIT_OBJECT_0 && !denied.fail); CHECK(CloseHandle(thread));
    }
    CHECK(bc_abi_guard_enter(&again) == 0 && again.lifetime == main_id.lifetime);
    CHECK(bc_abi_guard_leave(again) == 0);
    puts("PASS thread-identity: 8 concurrent threads, 1024 guarded updates, 32 sequential lifetimes, nonwrapping exhaustion");
    return 0;
}
