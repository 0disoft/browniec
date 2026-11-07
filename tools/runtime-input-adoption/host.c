#include "../../native/runtime_input_reader.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
size_t ria_heap_live(void);size_t ria_heap_attempts(void);
size_t ria_heap_failures(void);size_t ria_heap_frees(void);
static HANDLE original=NULL,writer=NULL,thread=NULL;
static wchar_t path[512];static DWORD baseline;
static size_t payload;static unsigned char chunk[8192];
static DWORD WINAPI produce(void *unused){
    size_t at=0;DWORD got; (void)unused;
    while(at<payload){DWORD count=(DWORD)(payload-at);if(count>sizeof(chunk)){count=sizeof(chunk);}
        if(!WriteFile(writer,chunk,count,&got,NULL)){assert(GetLastError()==ERROR_BROKEN_PIPE);break;}
        assert(got==count);at+=got;
    }assert(CloseHandle(writer));return 0;
}
uintptr_t ria_fixture(uint32_t kind,uintptr_t length){
    size_t i;DWORD got;wchar_t temp[MAX_PATH];
    assert(!original&&!thread);payload=length;
    for(i=0;i<sizeof(chunk);++i){chunk[i]=(unsigned char)(i%256);}
    assert(GetTempPathW(MAX_PATH,temp)>0);assert(GetTempFileNameW(temp,L"ria",0,path));
    if(kind==0){
        HANDLE file=CreateFileW(path,GENERIC_READ|GENERIC_WRITE,FILE_SHARE_READ,NULL,TRUNCATE_EXISTING,0,NULL);
        size_t at=0;LARGE_INTEGER zero;zero.QuadPart=0;assert(file!=INVALID_HANDLE_VALUE);
        while(at<length){DWORD count=(DWORD)(length-at);if(count>sizeof(chunk)){count=sizeof(chunk);}
            assert(WriteFile(file,chunk,count,&got,NULL)&&got==count);at+=got;}
        assert(SetFilePointerEx(file,zero,NULL,FILE_BEGIN));assert(CloseHandle(file));
        original=CreateFileW(path,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,0,NULL);assert(original!=INVALID_HANDLE_VALUE);
    }else{
        assert(CreatePipe(&original,&writer,NULL,0));thread=CreateThread(NULL,0,produce,NULL,0,NULL);assert(thread);
    }return (uintptr_t)original;
}
uintptr_t ria_path(uint8_t *out,uintptr_t capacity){
    size_t n=wcslen(path)*sizeof(wchar_t);assert(n<capacity);memcpy(out,path,n);return n;
}
void ria_release(void){
    assert(original);assert(CloseHandle(original));original=NULL;
    if(thread){assert(WaitForSingleObject(thread,INFINITE)==WAIT_OBJECT_0);assert(CloseHandle(thread));thread=NULL;writer=NULL;}
    assert(DeleteFileW(path));
}
void ria_remaining(uintptr_t count,uint8_t first){
    unsigned char bytes[16];DWORD got=0;BOOL ok;DWORD flags;
    assert(count<sizeof(bytes)&&GetHandleInformation(original,&flags));
    if(thread){assert(WaitForSingleObject(thread,INFINITE)==WAIT_OBJECT_0);}
    ok=ReadFile(original,bytes,sizeof(bytes),&got,NULL);
    assert((ok || (thread&&GetLastError()==ERROR_BROKEN_PIPE))&&got==count);
    if(count){assert(bytes[0]==first);}
}
void ria_clean(uintptr_t heap){
    assert(ria_heap_live()==heap);
#ifdef BC_RIR_TEST
    assert(bc_rir_test_live()==0);
#endif
}
uint32_t ria_seams(void){
#ifdef BC_RIR_TEST
    return 1;
#else
    return 0;
#endif
}
void ria_native_fail(uint32_t enabled){
#ifdef BC_RIR_TEST
    bc_rir_test_fail_after(enabled?0:-1);
#else
    (void)enabled;assert(0);
#endif
}
void ria_begin(void){assert(GetProcessHandleCount(GetCurrentProcess(),&baseline));}
void ria_end(void){
    DWORD handles;assert(!original&&!thread);assert(GetProcessHandleCount(GetCurrentProcess(),&handles));
    assert(handles==baseline&&ria_heap_live()==0);
    assert(ria_heap_attempts()==ria_heap_frees()+ria_heap_failures());
    assert(ria_heap_failures()==(ria_seams()?48u:0u));
    printf("{\"liveHeap\":0,\"nativeLive\":0,\"handlesStable\":true,\"fairyOomCases\":%zu,\"nativeOomCases\":%u,\"attempts\":%zu,\"frees\":%zu}\n",
        ria_heap_failures(),ria_seams()?24u:0u,ria_heap_attempts(),ria_heap_frees());
}
