/* Explicit verifier-only allocator seam, prepended to the pinned runtime. */
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>
static size_t live, attempts, failures, frees;
static int fail_next;
void ria_heap_fail(void){assert(!fail_next);fail_next=1;}
size_t ria_heap_live(void){return live;}
size_t ria_heap_attempts(void){return attempts;}
size_t ria_heap_failures(void){return failures;}
size_t ria_heap_frees(void){return frees;}
static void *ria_malloc(size_t n){
    void *p;++attempts;
    if(fail_next){fail_next=0;++failures;return NULL;}
    p=malloc(n);if(p){++live;}return p;
}
static void ria_free(void *p){if(p){assert(live);--live;++frees;}free(p);}
#define FY_STD_SYSTEM_HEAP_MALLOC_V0(size) ria_malloc(size)
#define FY_STD_SYSTEM_HEAP_FREE_V0(data) ria_free(data)
#define FY_STD_SYSTEM_HEAP_MAX_ALIGNMENT_V0 ((size_t)16)
