#ifndef BC_ANCHORED_SOURCE_LOADER_H
#define BC_ANCHORED_SOURCE_LOADER_H
#include <stddef.h>
#include <stdint.h>
/* Private scalar/pointer ABI. Live caller buffers and serialized owner access
   are trusted native obligations. No Fairy resource/array/slice layout crosses. */
void *bc_asl_open(const uint8_t *root,size_t length);
void *bc_asl_open_project(const uint8_t *path,size_t length,uint8_t *out,
                          size_t capacity,size_t *used,uint32_t *status);
uint32_t bc_asl_member(void *owner,const uint8_t *name,size_t length);
uint32_t bc_asl_collect(void *owner,size_t source_bytes);
uint32_t bc_asl_collect_until(void *owner,size_t source_bytes,size_t deadline);
/* part 0=name, 1=source. SIZE_MAX on any error; destination unchanged on error. */
size_t bc_asl_copy(void *owner,size_t index,uint32_t part,uint8_t *out,size_t capacity);
void bc_asl_close(void *owner);
#ifdef BC_ASL_TEST
long bc_asl_test_live(void);
void bc_asl_test_fail(int enabled);
#endif
#endif
