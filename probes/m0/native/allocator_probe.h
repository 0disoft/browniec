#pragma once
#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

// Test-only replacement of the target runtime's documented allocator seam.
// Each translation unit has private state; only the heap implementation uses it.
#pragma warning(push)
#pragma warning(disable: 4505 4996)
static size_t brownie_probe_live = 0;
static int brownie_probe_started = 0;
static int brownie_probe_failed = 0;

static void brownie_probe_finished(void) {
    if (brownie_probe_live != 0 ||
        (getenv("BROWNIE_M0_OOM") != NULL && !brownie_probe_failed)) {
        fputs("M0 allocator: leak or failure injection did not execute\n", stderr);
        abort();
    }
}

static void *brownie_probe_malloc(size_t size) {
    if (!brownie_probe_started) {
        if (atexit(brownie_probe_finished) != 0) abort();
        brownie_probe_started = 1;
    }
    if (size == 320 && getenv("BROWNIE_M0_OOM") != NULL && !brownie_probe_failed) {
        brownie_probe_failed = 1;
        return NULL;
    }
    void *value = malloc(size);
    if (value != NULL) brownie_probe_live++;
    return value;
}

static void brownie_probe_free(void *value) {
    if (value != NULL) {
        if (brownie_probe_live == 0) abort();
        brownie_probe_live--;
    }
    free(value);
}

#define FY_STD_SYSTEM_HEAP_MALLOC_V0(size) brownie_probe_malloc(size)
#define FY_STD_SYSTEM_HEAP_FREE_V0(value) brownie_probe_free(value)
#pragma warning(pop)
