#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <assert.h>
#include <string.h>
#include "../../native/anchored-source-loader/bridge.h"
#include "../../native/anchored_sources.h"
static DWORD handles;
void bc_as_test_checkpoint(unsigned stage,HANDLE handle){(void)stage;(void)handle;}
void asl_test_start(void){assert(GetProcessHandleCount(GetCurrentProcess(),&handles));}
void asl_test_clean(void){
    DWORD now;assert(GetProcessHandleCount(GetCurrentProcess(),&now));
    assert(now==handles&&bc_asl_test_live()==0&&bc_as_test_live_allocations()==0);
}
void asl_test_failure(uint32_t mode){
    assert(mode<=3);bc_asl_test_fail(mode==1);bc_as_test_fail_alloc_after(mode==2?0:mode==3?1:-1);
}
void asl_test_rewrite(const uint8_t *root,size_t length,uint32_t mode){
    wchar_t path[1100];int units;HANDLE h;DWORD written;
    static const uint8_t original[]="module a;\r\n// \xc3\xa9\0";
    assert(length<=3072);units=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,(const char*)root,(int)length,path,1024);
    assert(units>0);memcpy(path+units,L"\\sub\\a.fy",sizeof(L"\\sub\\a.fy"));
    h=CreateFileW(path,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL);assert(h!=INVALID_HANDLE_VALUE);
    assert(WriteFile(h,mode?"changed":(const char*)original,mode?7:(DWORD)(sizeof(original)-1),&written,NULL));
    assert(written==(mode?7:sizeof(original)-1));assert(CloseHandle(h));
}
void asl_test_bridge(const uint8_t *root,size_t length){
    uint8_t out[32];void *p=bc_asl_open(root,length);assert(p);memset(out,0x55,sizeof(out));
    assert(bc_asl_copy(p,0,0,out,sizeof(out))==SIZE_MAX&&out[0]==0x55);
    assert(bc_asl_member(p,(const uint8_t*)"sub/a.fy",8)==0&&bc_asl_collect(p,4096)==0);
    assert(bc_asl_copy(p,0,0,out,7)==SIZE_MAX&&out[0]==0x55);
    assert(bc_asl_copy(p,1,0,out,sizeof(out))==SIZE_MAX);
    assert(bc_asl_copy(p,0,2,out,sizeof(out))==SIZE_MAX);
    assert(bc_asl_copy(p,0,1,NULL,0)==SIZE_MAX);
    assert(bc_asl_copy(p,0,0,out,sizeof(out))==8&&memcmp(out,"sub/a.fy",8)==0);
    assert(bc_asl_collect(p,4096)!=0&&bc_asl_member(p,(const uint8_t*)"empty.brc",9)!=0);
    bc_asl_close(p);bc_asl_close(NULL);asl_test_clean();
}
