#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <assert.h>
#include <stdint.h>
#include <string.h>
#include "../../native/anchored-source-loader/bridge.h"
#include "../../native/anchored_sources.h"
static DWORD handles;
void bc_as_test_checkpoint(unsigned stage,HANDLE handle){(void)stage;(void)handle;}
void psl_test_start(void){assert(GetProcessHandleCount(GetCurrentProcess(),&handles));}
void psl_test_clean(void){
    DWORD now;assert(GetProcessHandleCount(GetCurrentProcess(),&now));
    assert(now==handles && bc_asl_test_live()==0 && bc_as_test_live_allocations()==0);
}
void psl_test_failure(uint32_t mode){
    assert(mode<=3);bc_asl_test_fail(mode==1);bc_as_test_fail_alloc_after(mode==2?0:mode==3?1:-1);
}
void psl_test_rewrite(const uint8_t *root,size_t length){
    wchar_t path[1100];int n;HANDLE h;DWORD written;
    assert(length<=3072);n=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,(const char*)root,(int)length,path,1024);
    assert(n>0);memcpy(path+n,L"\\src\\main.fy",sizeof(L"\\src\\main.fy"));
    h=CreateFileW(path,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL);assert(h!=INVALID_HANDLE_VALUE);
    assert(WriteFile(h,"changed",7,&written,NULL)&&written==7);assert(CloseHandle(h));
}
