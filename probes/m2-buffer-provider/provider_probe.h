#pragma once
#include "../m2-buffer-failure/allocator_probe.h"

// Test-only hooks inserted into the compiler-emitted native Buffer provider.
// Shortened metadata always remains within the actual allocation and is droppable.
static size_t brownie_provider_hits = 0;
static void brownie_provider_finished(void) {
    printf("{\"schema\":\"browniec.buffer-provider/v1\",\"hits\":%zu}\n", brownie_provider_hits);
}
static int brownie_provider_fault(const char *name) {
    const char *setting = getenv("BROWNIE_BUFFER_PROVIDER_FAULT");
    if (setting == NULL || strcmp(setting, name) != 0 || brownie_provider_hits != 0) return 0;
    if (atexit(brownie_provider_finished) != 0) abort();
    brownie_provider_hits++;
    return 1;
}
