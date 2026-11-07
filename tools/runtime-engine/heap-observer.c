#include <stdlib.h>
#include <stdint.h>
static size_t live_allocations=0;
static intptr_t allocation_fail_after=-1;
static void *tracked_malloc(size_t n){
    if(allocation_fail_after==0)return NULL;
    if(allocation_fail_after>0)allocation_fail_after--;
    void *p=malloc(n);if(p)live_allocations++;return p;
}
static void tracked_free(void *p){if(p){if(live_allocations==0)abort();live_allocations--;}free(p);}
size_t probe_live(void){return live_allocations;}
void bc_runtime_engine_test_fail(int64_t count){allocation_fail_after=(intptr_t)count;}
#define FY_STD_SYSTEM_HEAP_MALLOC_V0(size) tracked_malloc(size)
#define FY_STD_SYSTEM_HEAP_FREE_V0(data) tracked_free(data)
#define FY_STD_SYSTEM_HEAP_MAX_ALIGNMENT_V0 ((size_t)16)
