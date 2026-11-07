#include <stdlib.h>
#include <stddef.h>
static size_t live_allocations;
static void *psl_malloc(size_t n){void *p=malloc(n);if(p){++live_allocations;}return p;}
static void psl_free(void *p){if(p){if(!live_allocations){abort();}--live_allocations;}free(p);}
size_t psl_heap_live(void){return live_allocations;}
#define FY_STD_SYSTEM_HEAP_MALLOC_V0(size) psl_malloc(size)
#define FY_STD_SYSTEM_HEAP_FREE_V0(data) psl_free(data)
#define FY_STD_SYSTEM_HEAP_MAX_ALIGNMENT_V0 ((size_t)16)
