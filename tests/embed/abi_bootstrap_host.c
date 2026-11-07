/* Deliberately no import library: resolve and call the real DLL export. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include "abi_bootstrap_layout.h"

typedef uint32_t (BC_CALL *query_fn)(uint32_t, uint32_t, bc_abi_info *);
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s (winerr=%lu)\n", \
    __LINE__, #c, GetLastError()); return 1; } } while (0)

int wmain(int argc, wchar_t **argv) {
    const uint32_t revisions[] = {0, 1, 2, 3, UINT32_MAX};
    const uint32_t capacities[] = {0, 31, 32, 64, UINT32_MAX};
    const bc_abi_info expected = {32, 2, 64, 264, 336, 32, 32, 16};
    const char *unsupported[] = {"bc_engine_create", "bc_compile", "bc_program_entry_info",
        "bc_instance_create", "bc_step", "bc_host_reply", "bc_cancel",
        "bc_instance_destroy", "bc_program_release", "bc_engine_destroy"};
    HMODULE dll;
    FARPROC address;
    query_fn query;
    size_t i, j;
    unsigned calls = 0;
    struct guarded { unsigned char before[16]; bc_abi_info info; unsigned char after[48]; } g;
    unsigned char snapshot[sizeof(g)];
    CHECK(argc == 2);
    dll = LoadLibraryExW(argv[1], NULL, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    CHECK(dll != NULL);
    address = GetProcAddress(dll, "bc_get_abi_info_v2");
    CHECK(address != NULL);
    CHECK(sizeof(query) == sizeof(address));
    memcpy(&query, &address, sizeof(query));
    for (i = 0; i < sizeof(unsupported) / sizeof(unsupported[0]); ++i) {
        CHECK(GetProcAddress(dll, unsupported[i]) == NULL);
    }
    for (i = 0; i < sizeof(revisions) / sizeof(revisions[0]); ++i) {
        for (j = 0; j < sizeof(capacities) / sizeof(capacities[0]); ++j) {
            uint32_t rev = revisions[i], cap = capacities[j];
            uint32_t status = rev != 2 || cap < 32 ? BC_ABI_MISMATCH : BC_OK;
            memset(&g, 0xA5, sizeof(g)); /* Includes invalid caller struct_size. */
            memcpy(snapshot, &g, sizeof(g));
            CHECK(query(rev, cap, &g.info) == status); ++calls;
            if (status == BC_OK) {
                CHECK(memcmp(&g.info, &expected, sizeof(expected)) == 0);
                CHECK(memcmp(g.before, snapshot, sizeof(g.before)) == 0);
                CHECK(memcmp(g.after, snapshot + offsetof(struct guarded, after), sizeof(g.after)) == 0);
            } else { CHECK(memcmp(&g, snapshot, sizeof(g)) == 0); }
            CHECK(query(rev, cap, NULL) == (status == BC_OK ? BC_BAD_ARGUMENT : status)); ++calls;
        }
    }
    /* No-access output proves failure never reads or writes caller storage. */
    {
        void *guard = VirtualAlloc(NULL, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_NOACCESS);
        CHECK(guard != NULL);
        CHECK(query(1, UINT32_MAX, (bc_abi_info *)guard) == BC_ABI_MISMATCH); ++calls;
        CHECK(query(2, 31, (bc_abi_info *)guard) == BC_ABI_MISMATCH); ++calls;
        CHECK(VirtualFree(guard, 0, MEM_RELEASE));
    }
    /* Exactly 32 writable bytes followed by PAGE_NOACCESS: no overrun/read of
       the larger advertised capacity, even UINT32_MAX. Old bytes are arbitrary. */
    {
        SYSTEM_INFO sys;
        unsigned char *pages;
        bc_abi_info *edge;
        DWORD old_protect;
        GetSystemInfo(&sys);
        pages = (unsigned char *)VirtualAlloc(NULL, (SIZE_T)sys.dwPageSize * 2,
            MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
        CHECK(pages != NULL);
        CHECK(VirtualProtect(pages + sys.dwPageSize, sys.dwPageSize, PAGE_NOACCESS, &old_protect));
        edge = (bc_abi_info *)(pages + sys.dwPageSize - sizeof(bc_abi_info));
        memset(edge, 0xFF, sizeof(*edge));
        CHECK(query(2, UINT32_MAX, edge) == BC_OK); ++calls;
        CHECK(memcmp(edge, &expected, sizeof(expected)) == 0);
        CHECK(VirtualFree(pages, 0, MEM_RELEASE));
    }
    CHECK(FreeLibrary(dll));
    printf("PASS abi-bootstrap: %u DLL calls; exact metadata; failure preservation; canaries; guard pages; 10 unsupported exports absent\n", calls);
    return 0;
}
