#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include "abi_registry.h"
#include "abi_thread_identity.h"

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL %d: %s\n", __LINE__, #c); return 1; } } while (0)
/* Retry only OS contention in this TEST HOST, outside all guards. Production
   wrappers never wait/retry. Expected kernel Busy is checked without retry. */
#define EXPECT(expr, wanted) do { unsigned tries = 0; uint32_t s;     do { s = (expr); if (s == 3 && (wanted) != 3) { SwitchToThread(); } }     while (s == 3 && (wanted) != 3 && ++tries < 1000000);     CHECK(s == (wanted)); } while (0)

static int released(void) {
    bc_abi_thread_identity identity;
    CHECK(bc_abi_guard_enter(&identity) == 0);
    CHECK(bc_abi_guard_leave(identity) == 0); return 0;
}
static int drop(uint64_t handle, uint32_t kind, uint64_t engine, uint64_t object) {
    bc_abi_registry_admission a; uint64_t removed = 0;
    EXPECT(bc_abi_registry_enter(handle, kind, engine, &a), 0);
    EXPECT(bc_abi_registry_remove(&a, &removed), 0);
    CHECK(removed == object); return 0;
}
typedef struct foreign_task {
    uint64_t engine, program, instance;
    bc_abi_registry_admission admission;
    int failed;
} foreign_task;
static DWORD WINAPI foreign_calls(LPVOID raw) {
    foreign_task *t = raw; bc_abi_registry_admission out, before;
    uint64_t result = UINT64_MAX;
    memset(&out, 0xA5, sizeof(out)); before = out;
    EXPECT(bc_abi_registry_enter(t->engine, 1, t->engine, &out), 10);
    CHECK(memcmp(&out, &before, sizeof(out)) == 0);
    EXPECT(bc_abi_registry_enter(t->program, 2, t->engine, &out), 10);
    CHECK(memcmp(&out, &before, sizeof(out)) == 0);
    EXPECT(bc_abi_registry_enter_instance(t->instance, &out), 10);
    CHECK(memcmp(&out, &before, sizeof(out)) == 0);
    EXPECT(bc_abi_registry_insert(&t->admission, 3, 99, &result), 10);
    CHECK(result == UINT64_MAX);
    EXPECT(bc_abi_registry_remove(&t->admission, &result), 10);
    CHECK(result == UINT64_MAX);
    EXPECT(bc_abi_registry_leave(&t->admission), 10);
    CHECK(released() == 0); t->failed = 0; return 0;
}
static int basic(void) {
    bc_abi_registry_info info;
    bc_abi_registry_admission a, old, bad, untouched;
    struct { unsigned char before[16]; bc_abi_registry_admission a; unsigned char after[16]; } framed;
    unsigned char snapshot[sizeof(framed)];
    uint64_t e, p, instance, other, removed = UINT64_MAX, out = UINT64_MAX;
    uint64_t malformed[] = {0, 1, UINT64_C(4294967296), UINT64_C(4294967361), UINT64_MAX};
    size_t i; foreign_task t; HANDLE thread; DWORD code;
    CHECK(bc_abi_registry_inspect(&info) == 0);
    CHECK(info.capacity == 64 && info.table_bytes == 3080 && info.committed_bytes == 0 && info.allocation_count == 0);
    memset(&a, 0xA5, sizeof(a)); untouched = a;
    CHECK(bc_abi_registry_enter(0, 1, 0, &a) == 2 && memcmp(&a, &untouched, sizeof(a)) == 0);
    CHECK(released() == 0);
    bad = (bc_abi_registry_admission){0};
    CHECK(bc_abi_registry_remove(&bad, &out) == 2 && out == UINT64_MAX);
    CHECK(bc_abi_registry_leave(&bad) == 2);
    CHECK(bc_abi_registry_enter_instance(1, &a) == 2);
    CHECK(bc_abi_registry_insert(&bad, 2, 1, &out) == 2 && out == UINT64_MAX);
    CHECK(released() == 0);
    CHECK(bc_abi_registry_create_engine(1, NULL) == 1);
    CHECK(bc_abi_registry_enter(0, 1, 0, NULL) == 1);
    CHECK(bc_abi_registry_enter_instance(0, NULL) == 1);
    CHECK(bc_abi_registry_insert(NULL, 2, 1, &out) == 1);
    CHECK(bc_abi_registry_insert(&bad, 2, 1, NULL) == 1);
    CHECK(bc_abi_registry_leave(NULL) == 1);
    CHECK(bc_abi_registry_remove(NULL, &out) == 1);
    CHECK(bc_abi_registry_remove(&bad, NULL) == 1);
    CHECK(bc_abi_registry_inspect(NULL) == 1);
    CHECK(bc_abi_registry_inspect(&info) == 0 && info.allocation_count == 0);
    /* Values that would be invalid native addresses remain opaque integers. */
    CHECK(bc_abi_registry_create_engine(UINT64_MAX, &e) == 0 && e == UINT64_C(4294967297));
    CHECK(bc_abi_registry_create_engine(0, &out) == 1 && out == UINT64_MAX);
    CHECK(released() == 0);
    for (i = 0; i < sizeof(malformed) / sizeof(malformed[0]); ++i) {
        CHECK(bc_abi_registry_enter(malformed[i], 1, e, &a) == 2);
        CHECK(memcmp(&a, &untouched, sizeof(a)) == 0 && released() == 0);
    }
    CHECK(bc_abi_registry_enter(e, 2, e, &a) == 2);
    CHECK(bc_abi_registry_enter(e, 0, e, &a) == 1);
    CHECK(bc_abi_registry_enter(e, 1, e + UINT64_C(4294967296), &a) == 2);
    CHECK(memcmp(&a, &untouched, sizeof(a)) == 0 && released() == 0);
    memset(&framed, 0xA5, sizeof(framed)); memcpy(snapshot, &framed, sizeof(framed));
    CHECK(bc_abi_registry_enter(e, 1, e, &framed.a) == 0);
    CHECK(memcmp(framed.before, snapshot, 16) == 0 &&
        memcmp(framed.after, snapshot + sizeof(framed) - 16, 16) == 0);
    a = framed.a; old = a;
    CHECK(a.target == e && a.engine == e && a.kind == 1 && a.object == UINT64_MAX && a.reserved == 0);
    CHECK(released() == 0); /* Busy survives OS unlock. */
    CHECK(bc_abi_registry_enter(e, 1, e, &framed.a) == 3);
    CHECK(memcmp(&framed.a, &a, sizeof(a)) == 0);
    CHECK(bc_abi_registry_insert(&a, 3, 2, &out) == 1 && out == UINT64_MAX);
    CHECK(bc_abi_registry_insert(&a, 2, 0, &out) == 1 && out == UINT64_MAX);
    bad = a; bad.reserved = 1;
    CHECK(bc_abi_registry_leave(&bad) == 1);
    CHECK(bc_abi_registry_insert(&bad, 2, 2, &out) == 1 && out == UINT64_MAX);
    CHECK(bc_abi_registry_remove(&bad, &out) == 1 && out == UINT64_MAX);
    bad = a; bad.object = 7; CHECK(bc_abi_registry_leave(&bad) == 7);
    CHECK(bc_abi_registry_enter(e, 1, e, &framed.a) == 3 && released() == 0);
    CHECK(bc_abi_registry_insert(&a, 2, 2, &p) == 0);
    CHECK(bc_abi_registry_create_engine(33, &other) == 0);
    CHECK(drop(other, 1, other, 33) == 0); /* Independent Engine while e busy. */
    CHECK(bc_abi_registry_leave(&a) == 0 && bc_abi_registry_leave(&a) == 7);
    CHECK(bc_abi_registry_enter(p, 2, e, &a) == 0);
    CHECK(bc_abi_registry_insert(&a, 3, UINT64_C(0xFFFFFFFFFFFFFFF0), &instance) == 0);
    CHECK(bc_abi_registry_enter(instance, 2, e, &framed.a) == 2);
    CHECK(bc_abi_registry_enter(p, 2, other, &framed.a) == 2);
    CHECK(bc_abi_registry_leave(&old) == 7);
    CHECK(bc_abi_registry_remove(&old, &out) == 7 && out == UINT64_MAX);
    CHECK(bc_abi_registry_enter_instance(instance, &framed.a) == 3 && released() == 0);
    t.engine = e; t.program = p; t.instance = instance; t.admission = a; t.failed = 1;
    thread = CreateThread(NULL, 0, foreign_calls, &t, 0, NULL); CHECK(thread != NULL);
    CHECK(WaitForSingleObject(thread, 30000) == WAIT_OBJECT_0);
    CHECK(GetExitCodeThread(thread, &code) && code == 0 && !t.failed); CHECK(CloseHandle(thread));
    CHECK(bc_abi_registry_enter(e, 1, e, &framed.a) == 3);
    CHECK(bc_abi_registry_leave(&a) == 0);
    CHECK(bc_abi_registry_enter_instance(instance, &a) == 0);
    CHECK(a.object == UINT64_C(0xFFFFFFFFFFFFFFF0));
    CHECK(bc_abi_registry_leave(&a) == 0);
    CHECK(bc_abi_registry_enter(e, 1, e, &a) == 0);
    CHECK(bc_abi_registry_remove(&a, &out) == 3 && out == UINT64_MAX);
    CHECK(released() == 0 && bc_abi_registry_leave(&a) == 0);
    CHECK(drop(instance, 3, e, UINT64_C(0xFFFFFFFFFFFFFFF0)) == 0);
    CHECK(bc_abi_registry_enter_instance(instance, &framed.a) == 2);
    CHECK(drop(p, 2, e, 2) == 0);
    CHECK(bc_abi_registry_enter(e, 1, e, &a) == 0);
    CHECK(bc_abi_registry_remove(&a, &removed) == 0 && removed == UINT64_MAX);
    CHECK(bc_abi_registry_remove(&a, &out) == 2 && out == UINT64_MAX);
    CHECK(bc_abi_registry_create_engine(77, &other) == 0 && other == e + UINT64_C(4294967296));
    CHECK(bc_abi_registry_enter(e, 1, e, &framed.a) == 2);
    /* Force OS contention/reentry without modifying any production metadata. */
    {
        bc_abi_thread_identity id; bc_abi_registry_info untouched_info;
        CHECK(bc_abi_registry_enter(other, 1, other, &a) == 0);
        CHECK(bc_abi_guard_enter(&id) == 0);
        memset(&framed.a, 0xA5, sizeof(framed.a)); untouched = framed.a;
        memset(&info, 0xA5, sizeof(info)); untouched_info = info;
        CHECK(bc_abi_registry_create_engine(88, &out) == 3 && out == UINT64_MAX);
        CHECK(bc_abi_registry_enter(other, 1, other, &framed.a) == 3);
        CHECK(bc_abi_registry_enter_instance(instance, &framed.a) == 3);
        CHECK(memcmp(&framed.a, &untouched, sizeof(untouched)) == 0);
        CHECK(bc_abi_registry_insert(&a, 2, 88, &out) == 3 && out == UINT64_MAX);
        CHECK(bc_abi_registry_leave(&a) == 3);
        CHECK(bc_abi_registry_remove(&a, &out) == 3 && out == UINT64_MAX);
        CHECK(bc_abi_registry_inspect(&info) == 3 && memcmp(&info, &untouched_info, sizeof(info)) == 0);
        CHECK(bc_abi_guard_leave(id) == 0);
        CHECK(bc_abi_registry_remove(&a, &out) == 0 && out == 77);
    }
    CHECK(bc_abi_registry_inspect(&info) == 0 && info.allocation_count == 1 && info.committed_bytes == 4096);
    CHECK(released() == 0);
    puts("PASS registry basic: real wrappers, staged outputs, OS ownership, busy, stale, rollback"); return 0;
}
static int capacity(void) {
    uint64_t e, p[63], out = UINT64_MAX; size_t i;
    bc_abi_registry_admission a; bc_abi_registry_info info;
    CHECK(bc_abi_registry_create_engine(1, &e) == 0);
    CHECK(bc_abi_registry_enter(e, 1, e, &a) == 0);
    for (i = 0; i < 63; ++i) { CHECK(bc_abi_registry_insert(&a, 2, i + 2, &p[i]) == 0); }
    CHECK(p[62] == UINT64_C(4294967360));
    CHECK(bc_abi_registry_insert(&a, 2, 65, &out) == 8 && out == UINT64_MAX);
    CHECK(bc_abi_registry_create_engine(65, &out) == 8 && out == UINT64_MAX);
    CHECK(bc_abi_registry_remove(&a, &out) == 3 && out == UINT64_MAX);
    CHECK(released() == 0 && bc_abi_registry_leave(&a) == 0);
    for (i = 0; i < 63; ++i) { CHECK(drop(p[i], 2, e, i + 2) == 0); }
    CHECK(drop(e, 1, e, 1) == 0);
    CHECK(bc_abi_registry_inspect(&info) == 0 && info.allocation_count == 1 && info.committed_bytes == 4096);
    CHECK(bc_abi_registry_create_engine(100, &out) == 0 && out == e + UINT64_C(4294967296));
    CHECK(drop(out, 1, out, 100) == 0 && released() == 0);
    puts("PASS registry capacity: 64 slots, failure rollback, retained allocation and generations"); return 0;
}
typedef struct concurrent_task { HANDLE start; uint64_t first; unsigned index; int failed; } concurrent_task;
static DWORD WINAPI concurrent_calls(LPVOID raw) {
    concurrent_task *t = raw; unsigned i;
    CHECK(WaitForSingleObject(t->start, 30000) == WAIT_OBJECT_0);
    for (i = 0; i < 16; ++i) {
        uint64_t e, p, instance, out; bc_abi_registry_admission a;
        uint64_t object = 1 + t->index * 100 + i;
        EXPECT(bc_abi_registry_create_engine(object, &e), 0); if (!i) { t->first = e; }
        EXPECT(bc_abi_registry_enter(e, 1, e, &a), 0);
        Sleep(0); /* Unlocked work while Engine busy; other Engines must advance. */
        EXPECT(bc_abi_registry_insert(&a, 2, object + 1000, &p), 0);
        EXPECT(bc_abi_registry_leave(&a), 0);
        EXPECT(bc_abi_registry_enter(p, 2, e, &a), 0);
        EXPECT(bc_abi_registry_insert(&a, 3, object + 2000, &instance), 0);
        EXPECT(bc_abi_registry_leave(&a), 0);
        EXPECT(bc_abi_registry_enter_instance(instance, &a), 0);
        EXPECT(bc_abi_registry_remove(&a, &out), 0); CHECK(out == object + 2000);
        CHECK(drop(p, 2, e, object + 1000) == 0); CHECK(drop(e, 1, e, object) == 0);
    }
    t->failed = 0; return 0;
}
static int concurrent(void) {
    concurrent_task tasks[8]; HANDLE threads[8], start;
    size_t i, j; DWORD code; bc_abi_registry_info info;
    CHECK(bc_abi_registry_inspect(&info) == 0 && info.allocation_count == 0);
    start = CreateEventW(NULL, TRUE, FALSE, NULL); CHECK(start != NULL);
    memset(tasks, 0, sizeof(tasks));
    for (i = 0; i < 8; ++i) {
        tasks[i].start = start; tasks[i].index = (unsigned)i; tasks[i].failed = 1;
        threads[i] = CreateThread(NULL, 0, concurrent_calls, &tasks[i], 0, NULL); CHECK(threads[i] != NULL);
    }
    CHECK(SetEvent(start)); CHECK(WaitForMultipleObjects(8, threads, TRUE, 30000) == WAIT_OBJECT_0);
    for (i = 0; i < 8; ++i) {
        CHECK(GetExitCodeThread(threads[i], &code) && code == 0 && !tasks[i].failed);
        CHECK(CloseHandle(threads[i])); CHECK(tasks[i].first != 0);
        for (j = 0; j < i; ++j) { CHECK(tasks[i].first != tasks[j].first); }
    }
    CHECK(CloseHandle(start));
    CHECK(bc_abi_registry_inspect(&info) == 0 && info.allocation_count == 1 && info.committed_bytes == 4096);
    CHECK(released() == 0);
    puts("PASS registry concurrent: 8 threads, 128 Engine/Program/Instance cycles, one lazy allocation"); return 0;
}
typedef struct lifetime_task { uint64_t previous, handle; int failed; } lifetime_task;
static DWORD WINAPI lifetime_call(LPVOID raw) {
    lifetime_task *t = raw; bc_abi_registry_admission out;
    if (t->previous) { EXPECT(bc_abi_registry_enter(t->previous, 1, t->previous, &out), 10); }
    EXPECT(bc_abi_registry_create_engine(UINT64_MAX, &t->handle), 0);
    t->failed = 0; return 0; /* Intentionally dead owner; no adoption/reset API. */
}
static int lifetimes(void) {
    uint64_t previous = 0; DWORD ids[32], code; unsigned i, j, reused = 0;
    bc_abi_registry_admission out; bc_abi_registry_info info;
    for (i = 0; i < 32; ++i) {
        lifetime_task t = {previous, 0, 1};
        HANDLE thread = CreateThread(NULL, 0, lifetime_call, &t, 0, &ids[i]); CHECK(thread != NULL);
        CHECK(WaitForSingleObject(thread, 30000) == WAIT_OBJECT_0);
        CHECK(GetExitCodeThread(thread, &code) && code == 0 && !t.failed); CHECK(CloseHandle(thread));
        CHECK(t.handle != 0 && t.handle != previous); previous = t.handle;
        CHECK(bc_abi_registry_enter(previous, 1, previous, &out) == 10);
        for (j = 0; j < i; ++j) { if (ids[i] == ids[j]) { ++reused; break; } }
    }
    CHECK(bc_abi_registry_inspect(&info) == 0 && info.allocation_count == 1);
    CHECK(released() == 0);
    printf("PASS registry lifetimes: 32 exited owners rejected; observed numeric ID reuse=%u\n", reused); return 0;
}
int main(int argc, char **argv) {
    CHECK(argc == 2 && sizeof(void *) == 8);
    if (strcmp(argv[1], "basic") == 0) { return basic(); }
    if (strcmp(argv[1], "capacity") == 0) { return capacity(); }
    if (strcmp(argv[1], "concurrent") == 0) { return concurrent(); }
    if (strcmp(argv[1], "lifetimes") == 0) { return lifetimes(); }
    CHECK(0); return 1;
}
