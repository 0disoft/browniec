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
static int decode_path(const uint8_t *path,size_t length,wchar_t *wide,int capacity){
    /* UTF-8 has at most three bytes per UTF-16 code unit. Check before decode,
       allocation, int conversion or dereference; embedded NUL is never accepted. */
    if(!path||!length||length>(size_t)capacity*3u||memchr(path,0,length)){return 0;}
    return MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,(LPCCH)path,(int)length,wide,capacity);
}
static loader *open_root(const wchar_t *wide,size_t units,bc_as_status *status){
    loader *p;
    *status=BC_AS_ALLOCATION;
#ifdef BC_ASL_TEST
    if(fail_allocation){return NULL;}
#endif
    p=(loader*)HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,sizeof(*p));if(!p){return NULL;}
#ifdef BC_ASL_TEST
    ++live;
#endif
    *status=bc_as_root_open(wide,units,&p->root,NULL);
    if(*status!=BC_AS_OK){bc_asl_close(p);return NULL;}
    return p;
}
void *bc_asl_open(const uint8_t *root,size_t length){
    wchar_t wide[BC_AS_ROOT_CHARS];
    bc_as_status status;
    int units=decode_path(root,length,wide,BC_AS_ROOT_CHARS);
    return units?open_root(wide,(size_t)units,&status):NULL;
}
void *bc_asl_open_project(const uint8_t *path,size_t length,uint8_t *out,
                          size_t capacity,size_t *used,uint32_t *status){
    wchar_t raw[BC_AS_ROOT_CHARS+1],absolute[BC_AS_ROOT_CHARS+1],*leaf=NULL;
    DWORD resolved;
    bc_as_status result;
    loader *p;
    int units=decode_path(path,length,raw,BC_AS_ROOT_CHARS);
    *status=BC_AS_NAME;
    if(!units){return NULL;}
    raw[units]=0;
    /* Reject rooted-relative, UNC, device and drive-relative paths before
       Win32 can reinterpret them. Ordinary relative paths use the process CWD. */
    if(raw[0]=='\\'||raw[0]=='/'||(units>=2&&raw[1]==':'&&
       (units<3||(raw[2]!='\\'&&raw[2]!='/')))){return NULL;}
    if(raw[units-1]=='.'||raw[units-1]==' '||raw[units-1]=='\\'||raw[units-1]=='/'){return NULL;}
    resolved=GetFullPathNameW(raw,BC_AS_ROOT_CHARS+1,absolute,&leaf);
    if(!resolved||resolved>BC_AS_ROOT_CHARS||!leaf||leaf-absolute<3){return NULL;}
    size_t root_units=(size_t)(leaf-absolute);
    p=open_root(absolute,root_units==3?3:root_units-1,&result);
    if(p){
        result=bc_as_read_config(p->root,leaf,resolved-root_units,out,capacity,used);
        if(result!=BC_AS_OK){bc_asl_close(p);p=NULL;}
    }
    *status=(uint32_t)result;
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
    return bc_asl_collect_until(owner,source_bytes,0);
}
uint32_t bc_asl_collect_until(void *owner,size_t source_bytes,size_t deadline){
    loader *p=(loader*)owner;bc_as_status s;
    if(!p||p->attempted){return BC_AS_ARGUMENT;}p->attempted=1;
    s=bc_as_collect_until(p->root,p->paths,p->count,source_bytes,deadline,&p->snapshot,NULL);
    bc_as_root_close(p->root);p->root=NULL;return (uint32_t)s;
}
size_t bc_asl_copy(void *owner,size_t index,uint32_t part,uint8_t *out,size_t capacity){
    loader *p=(loader*)owner;bc_as_view view;const uint8_t *data;size_t length;
    if(!p||!p->snapshot||part>1||bc_as_file(p->snapshot,index,&view)!=BC_AS_OK){return SIZE_MAX;}
    data=part==0?view.name:view.bytes;length=part==0?view.name_length:view.length;
    if(length>capacity||(length&&!out)){return SIZE_MAX;}
    if(length){memcpy(out,data,length);}return length;
}
