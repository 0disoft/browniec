#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winternl.h>
#include <string.h>
#include "runtime_input_reader.h"

/* The user-mode SDK supplies FILE_INFORMATION_CLASS/IO_STATUS_BLOCK but not
   this documented native query declaration. Link explicitly against ntdll. */
NTSYSAPI NTSTATUS NTAPI NtQueryInformationFile(HANDLE,PIO_STATUS_BLOCK,PVOID,ULONG,FILE_INFORMATION_CLASS);

struct bc_rir_snapshot { size_t length; uint8_t bytes[]; };
#ifdef BC_RIR_TEST
static long live,attempts,partials,fail_after=-1;
void bc_rir_test_fail_after(long n){fail_after=n;}
long bc_rir_test_live(void){return live;}
long bc_rir_test_attempts(void){return attempts;}
long bc_rir_test_partial_reads(void){return partials;}
#endif
static bc_rir_status fail(DWORD *error,bc_rir_status status,DWORD code){
    if(error){*error=code;}return status;
}
static bc_rir_snapshot *allocate(size_t capacity){
    bc_rir_snapshot *p;
    if(capacity>BC_RIR_LIMIT||capacity>SIZE_MAX-sizeof(*p)){return NULL;}
#ifdef BC_RIR_TEST
    ++attempts;if(fail_after==0){return NULL;}if(fail_after>0){--fail_after;}
#endif
    p=HeapAlloc(GetProcessHeap(),0,sizeof(*p)+capacity);
    if(p){p->length=0;
#ifdef BC_RIR_TEST
        ++live;
#endif
    }return p;
}
void bc_rir_close(bc_rir_snapshot *p){if(p){
#ifdef BC_RIR_TEST
    --live;
#endif
    HeapFree(GetProcessHeap(),0,p);
}}
size_t bc_rir_length(const bc_rir_snapshot *p){return p?p->length:0;}
const uint8_t *bc_rir_bytes(const bc_rir_snapshot *p){return p?p->bytes:NULL;}

/* Owns h on entry. FileModeInformation is the documented OS ULONG Mode record,
   class 16; no Fairy type/layout is copied or projected here. Reject overlapped
   handles BEFORE ReadFile, so no pending write can outlive the staging owner. */
static bc_rir_status read_owned(HANDLE h,size_t limit,bc_rir_snapshot **out,DWORD *error){
    struct { ULONG Mode; } mode;
    IO_STATUS_BLOCK io;NTSTATUS nt;DWORD type,flags,state,got,request,code;
    LARGE_INTEGER size,position,zero;bc_rir_snapshot *stage=NULL;
    bc_rir_status status=BC_RIR_OK;uint8_t probe;uint8_t *destination;
    type=GetFileType(h);
    if(type!=FILE_TYPE_DISK&&type!=FILE_TYPE_PIPE){status=fail(error,BC_RIR_KIND,ERROR_INVALID_HANDLE);goto done;}
    memset(&io,0,sizeof(io));memset(&mode,0,sizeof(mode));
    nt=NtQueryInformationFile(h,&io,&mode,sizeof(mode),(FILE_INFORMATION_CLASS)16);
    if(nt<0){status=fail(error,BC_RIR_OS,ERROR_INVALID_FUNCTION);goto done;}
    if(!(mode.Mode&(0x10u|0x20u))){status=fail(error,BC_RIR_KIND,ERROR_NOT_SUPPORTED);goto done;}
    if(type==FILE_TYPE_DISK){
        zero.QuadPart=0;
        if(!GetFileSizeEx(h,&size)||!SetFilePointerEx(h,zero,&position,FILE_CURRENT)){
            status=fail(error,BC_RIR_OS,GetLastError());goto done;
        }
        if(size.QuadPart<0||position.QuadPart<0){status=fail(error,BC_RIR_OS,ERROR_INVALID_DATA);goto done;}
        if(size.QuadPart>position.QuadPart&&(uint64_t)(size.QuadPart-position.QuadPart)>limit){
            status=fail(error,BC_RIR_LIMIT_ERROR,ERROR_FILE_TOO_LARGE);goto done;
        }
    }else{
        if(!GetNamedPipeInfo(h,&flags,NULL,NULL,NULL)||!GetNamedPipeHandleStateW(h,&state,NULL,NULL,NULL,NULL,0)){
            status=fail(error,BC_RIR_OS,GetLastError());goto done;
        }
        if((flags&PIPE_TYPE_MESSAGE)||(state&(PIPE_NOWAIT|PIPE_READMODE_MESSAGE))){
            status=fail(error,BC_RIR_KIND,ERROR_NOT_SUPPORTED);goto done;
        }
    }
    stage=allocate(limit);
    if(!stage){status=fail(error,BC_RIR_ALLOCATION,ERROR_NOT_ENOUGH_MEMORY);goto done;}
    for(;;){
        request=(DWORD)(limit-stage->length);if(request>8192){request=8192;}
        destination=request?stage->bytes+stage->length:&probe;
        if(!request){request=1;}
        got=0;
        if(!ReadFile(h,destination,request,&got,NULL)){
            code=GetLastError();
            if(type==FILE_TYPE_PIPE&&code==ERROR_BROKEN_PIPE){break;}
            status=fail(error,BC_RIR_OS,code);goto done;
        }
        if(got>request){status=fail(error,BC_RIR_OS,ERROR_INVALID_DATA);goto done;}
        if(got==0){
            /* A successful zero-byte pipe read is a zero-byte writer operation,
               not EOF. Reject no progress without publishing or retrying. */
            if(type==FILE_TYPE_PIPE){status=fail(error,BC_RIR_OS,ERROR_NO_DATA);goto done;}
            break;
        }
#ifdef BC_RIR_TEST
        if(got<request){++partials;}
#endif
        if(got>limit-stage->length){status=fail(error,BC_RIR_LIMIT_ERROR,ERROR_FILE_TOO_LARGE);goto done;}
        stage->length+=got;
    }
done:
    if(!CloseHandle(h)&&status==BC_RIR_OK){status=fail(error,BC_RIR_OS,GetLastError());}
    if(status==BC_RIR_OK){*out=stage;}else{bc_rir_close(stage);}
    return status;
}
static bc_rir_status arguments(size_t limit,bc_rir_snapshot **out,DWORD *error){
    if(!out||*out){return fail(error,BC_RIR_ARGUMENT,ERROR_INVALID_PARAMETER);}
    if(limit>BC_RIR_LIMIT){return fail(error,BC_RIR_LIMIT_ERROR,ERROR_FILE_TOO_LARGE);}
    return BC_RIR_OK;
}
bc_rir_status bc_rir_handle(HANDLE input,size_t limit,bc_rir_snapshot **out,DWORD *error){
    HANDLE owned;bc_rir_status status=arguments(limit,out,error);if(status!=BC_RIR_OK){return status;}
    if(!input||input==INVALID_HANDLE_VALUE){return fail(error,BC_RIR_ARGUMENT,ERROR_INVALID_HANDLE);}
    if(!DuplicateHandle(GetCurrentProcess(),input,GetCurrentProcess(),&owned,0,FALSE,DUPLICATE_SAME_ACCESS)){
        return fail(error,BC_RIR_OS,GetLastError());
    }
    return read_owned(owned,limit,out,error);
}
bc_rir_status bc_rir_path(const wchar_t *path,size_t length,size_t limit,bc_rir_snapshot **out,DWORD *error){
    wchar_t terminated[BC_RIR_PATH_UNITS+1u];size_t i;HANDLE h;
    bc_rir_status status=arguments(limit,out,error);if(status!=BC_RIR_OK){return status;}
    if(!path||length<3||length>BC_RIR_PATH_UNITS||
       !((path[0]>='A'&&path[0]<='Z')||(path[0]>='a'&&path[0]<='z'))||path[1]!=':'||path[2]!='\\'){
        return fail(error,BC_RIR_ARGUMENT,ERROR_INVALID_NAME);
    }
    for(i=0;i<length;++i){if(!path[i]){return fail(error,BC_RIR_ARGUMENT,ERROR_INVALID_NAME);}}
    memcpy(terminated,path,length*sizeof(wchar_t));terminated[length]=0;
    h=CreateFileW(terminated,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_FLAG_SEQUENTIAL_SCAN,NULL);
    if(h==INVALID_HANDLE_VALUE){return fail(error,BC_RIR_OS,GetLastError());}
    /* An explicit file path is disk-only; pipes require explicit HANDLE API. */
    if(GetFileType(h)!=FILE_TYPE_DISK){CloseHandle(h);return fail(error,BC_RIR_KIND,ERROR_NOT_SUPPORTED);}
    return read_owned(h,limit,out,error);
}
