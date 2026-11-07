#include "../runtime_input_reader.h"
#include <string.h>

/* Only primitive extern-C types cross this boundary. All Snapshot construction,
   Fuel changes and ownership transfer remain in Fairy and the pinned SDK. */
_Static_assert(sizeof(wchar_t)==sizeof(uint16_t), "Windows UTF16 units");
void *bc_ria_read_handle(uintptr_t input,uintptr_t limit,uint32_t *status,uint32_t *os){
    bc_rir_snapshot *owner=NULL;DWORD error=0;
    *status=(uint32_t)bc_rir_handle((HANDLE)input,limit,&owner,&error);*os=error;
    return owner;
}
void *bc_ria_read_path(const uint8_t *path,uintptr_t length,uintptr_t limit,uint32_t *status,uint32_t *os){
    wchar_t aligned[BC_RIR_PATH_UNITS];
    bc_rir_snapshot *owner=NULL;DWORD error=0;
    if(!path || length<6 || length%2 || length>sizeof(aligned)){
        *status=BC_RIR_ARGUMENT;*os=ERROR_INVALID_NAME;return NULL;
    }
    memcpy(aligned,path,length);
    *status=(uint32_t)bc_rir_path(aligned,length/2,limit,&owner,&error);*os=error;
    return owner;
}
uintptr_t bc_ria_length(void *owner){return bc_rir_length(owner);}
const uint8_t *bc_ria_bytes(void *owner){return bc_rir_bytes(owner);}
void bc_ria_close(void *owner){bc_rir_close(owner);}
