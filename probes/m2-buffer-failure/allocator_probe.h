#pragma once
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Test-only FY system-heap seam, following probes/m0/native/allocator_probe.h.
// State is translation-unit local; the runtime heap implementation uses it.
#pragma warning(push)
#pragma warning(disable: 4505 4996)
static size_t brownie_buffer_live = 0;
static size_t brownie_buffer_target = 0;
static size_t brownie_buffer_attempts = 0;
static size_t brownie_buffer_all_attempts = 0;
static size_t brownie_buffer_frees = 0;
static int brownie_buffer_failed = 0;
static int brownie_buffer_started = 0;

static void brownie_buffer_finished(void) {
    if (brownie_buffer_live != 0 ||
        (brownie_buffer_target != 0 && brownie_buffer_failed != 1)) {
        fputs("Buffer allocator: outstanding allocation or injection did not execute\n", stderr);
        abort();
    }
    printf("{\"schema\":\"browniec.buffer-allocator/v2\",\"live\":%zu,"
           "\"target\":%zu,\"targetAttempts\":%zu,\"failures\":%d,\"attempts\":%zu,\"frees\":%zu}\n",
           brownie_buffer_live, brownie_buffer_target,
           brownie_buffer_attempts, brownie_buffer_failed, brownie_buffer_all_attempts, brownie_buffer_frees);
}
static void *brownie_buffer_malloc(size_t size) {
    brownie_buffer_all_attempts++;
    if (!brownie_buffer_started) {
        const char *setting = getenv("BROWNIE_BUFFER_FAIL_BYTES");
        if (setting != NULL) {
            if (strcmp(setting, "320") == 0) brownie_buffer_target = 320;
            else if (strcmp(setting, "384") == 0) brownie_buffer_target = 384;
            else abort();
        }
        if (atexit(brownie_buffer_finished) != 0) abort();
        brownie_buffer_started = 1;
    }
    if (brownie_buffer_target != 0 && size == brownie_buffer_target) {
        brownie_buffer_attempts++;
        if (!brownie_buffer_failed) {
            brownie_buffer_failed = 1;
            return NULL;
        }
    }
    void *value = malloc(size);
    if (value != NULL) brownie_buffer_live++;
    return value;
}
static void brownie_buffer_free(void *value) {
    if (value != NULL) {
        if (brownie_buffer_live == 0) abort();
        brownie_buffer_live--;
        brownie_buffer_frees++;
    }
    free(value);
}
#define FY_STD_SYSTEM_HEAP_MALLOC_V0(size) brownie_buffer_malloc(size)
#define FY_STD_SYSTEM_HEAP_FREE_V0(value) brownie_buffer_free(value)
#pragma warning(pop)
