#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <string.h>
#include "bridge.h"
#include "../anchored_sources.h"
typedef struct loader {
    bc_as_root *root; bc_as_snapshot *snapshot;
    bc_as_path paths[BC_AS_FILES]; uint8_t names[BC_AS_FILES][BC_AS_PATH];
    size_t count; int attempted;
} loader;
#ifdef BC_ASL_TEST
static long live;static int fail_allocation;
long bc_asl_test_live(void){return live;}
void bc_asl_test_fail(int enabled){fail_allocation=enabled;}
#endif
void bc_asl_close(void *owner){
    loader *p=(loader*)owner;if(!p){return;}
    bc_as_snapshot_close(p->snapshot);bc_as_root_close(p->root);
#ifdef BC_ASL_TEST
    --live;
#endif
    HeapFree(GetProcessHeap(),0,p);
}
void *bc_asl_open(const uint8_t *root,size_t length){
    wchar_t wide[BC_AS_ROOT_CHARS];int units;loader *p;
    /* UTF-8 has at most three bytes per UTF-16 code unit. Check before decode,
       allocation, int conversion or dereference; embedded NUL is never accepted. */
    if(!root||!length||length>BC_AS_ROOT_CHARS*3u||memchr(root,0,length)){return NULL;}
    units=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,(LPCCH)root,(int)length,wide,BC_AS_ROOT_CHARS);
    if(!units){return NULL;}
#ifdef BC_ASL_TEST
    if(fail_allocation){return NULL;}
#endif
    p=(loader*)HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,sizeof(*p));if(!p){return NULL;}
#ifdef BC_ASL_TEST
    ++live;
#endif
    if(bc_as_root_open(wide,(size_t)units,&p->root,NULL)!=BC_AS_OK){bc_asl_close(p);return NULL;}
    return p;
}
uint32_t bc_asl_member(void *owner,const uint8_t *name,size_t length){
    loader *p=(loader*)owner;
    if(!p||p->attempted||p->count==BC_AS_FILES){return BC_AS_ARGUMENT;}
    if(!bc_as_member_path(name,length)){return BC_AS_NAME;}
    memcpy(p->names[p->count],name,length);
    p->paths[p->count].data=p->names[p->count];p->paths[p->count].length=length;++p->count;return BC_AS_OK;
}
uint32_t bc_asl_collect(void *owner,size_t source_bytes){
    loader *p=(loader*)owner;bc_as_status s;
    if(!p||p->attempted){return BC_AS_ARGUMENT;}p->attempted=1;
    s=bc_as_collect(p->root,p->paths,p->count,source_bytes,&p->snapshot,NULL);
    bc_as_root_close(p->root);p->root=NULL;return (uint32_t)s;
}
size_t bc_asl_copy(void *owner,size_t index,uint32_t part,uint8_t *out,size_t capacity){
    loader *p=(loader*)owner;bc_as_view view;const uint8_t *data;size_t length;
    if(!p||!p->snapshot||part>1||bc_as_file(p->snapshot,index,&view)!=BC_AS_OK){return SIZE_MAX;}
    data=part==0?view.name:view.bytes;length=part==0?view.name_length:view.length;
    if(length>capacity||(length&&!out)){return SIZE_MAX;}
    if(length){memcpy(out,data,length);}return length;
}
