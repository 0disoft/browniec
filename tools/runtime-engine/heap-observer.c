#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
/* Instrumentation only. SDK-requested bytes exclude these aligned headers. */
typedef struct probe_block {size_t bytes;uintptr_t marker;} probe_block;
_Static_assert(sizeof(probe_block)==16,"preserve malloc's 16-byte alignment");
static size_t live_allocations=0,live_bytes=0,peak_bytes=0,attempts=0;
static intptr_t allocation_fail_after=-1,retention_fail_after=-1;
static size_t compiler_work_depth=0,retention_start_attempts=0;
static int retention_probe=0,retention_admitted=0,unexpected_before_retention=0;
static void *tracked_malloc(size_t n){
    attempts++;
    if(retention_probe && attempts>1 && !compiler_work_depth && !retention_admitted)
        unexpected_before_retention=1;
    if(allocation_fail_after==0)return NULL;
    if(allocation_fail_after>0)allocation_fail_after--;
    if(n>SIZE_MAX-sizeof(probe_block))return NULL;
    probe_block *p=malloc(n+sizeof(probe_block));if(!p)return NULL;
    p->bytes=n;p->marker=UINT64_C(0x62726f776e696563);
    live_allocations++;if(n>SIZE_MAX-live_bytes)abort();live_bytes+=n;
    if(live_bytes>peak_bytes)peak_bytes=live_bytes;return p+1;
}
static void tracked_free(void *raw){
    if(!raw)return;probe_block *p=(probe_block *)raw-1;
    if(!live_allocations||p->marker!=UINT64_C(0x62726f776e696563)||p->bytes>live_bytes)abort();
    live_allocations--;live_bytes-=p->bytes;p->marker=0;free(p);
}
size_t probe_live(void){return live_allocations;}
size_t probe_live_bytes(void){return live_bytes;}
size_t probe_peak_bytes(void){return peak_bytes;}
size_t probe_attempts(void){return attempts;}
void probe_measure_begin(void){if(live_allocations||live_bytes)abort();attempts=0;peak_bytes=0;}
void probe_rebase(void){attempts=0;peak_bytes=live_bytes;}
void bc_runtime_engine_test_fail(int64_t count){allocation_fail_after=(intptr_t)count;retention_fail_after=-1;}
/* Retention fixtures name incoming/Image/Stored/handle seams. Independent
 * compile fixtures still inject every global allocation, including scratch. */
void bc_runtime_engine_test_retention_fail(int64_t count){
    allocation_fail_after=count==0?0:-1;retention_fail_after=count>0?(intptr_t)count-1:-1;
}
void bc_runtime_engine_test_compiler_work_begin(void){compiler_work_depth++;}
void bc_runtime_engine_test_compiler_work_end(void){if(!compiler_work_depth)abort();compiler_work_depth--;}
void bc_runtime_engine_test_retention_admitted(void){
    if(compiler_work_depth)abort();retention_admitted=1;retention_start_attempts=attempts;
    if(retention_fail_after>=0){allocation_fail_after=retention_fail_after;retention_fail_after=-1;}
}
void probe_retention_begin(void){
    if(compiler_work_depth)abort();retention_probe=1;retention_admitted=0;unexpected_before_retention=0;
}
int probe_no_retention_allocations(void){return !compiler_work_depth && !retention_admitted && !unexpected_before_retention;}
#define FY_STD_SYSTEM_HEAP_MALLOC_V0(size) tracked_malloc(size)
#define FY_STD_SYSTEM_HEAP_FREE_V0(data) tracked_free(data)
#define FY_STD_SYSTEM_HEAP_MAX_ALIGNMENT_V0 ((size_t)16)

size_t probe_retention_start(void){return retention_start_attempts;}
