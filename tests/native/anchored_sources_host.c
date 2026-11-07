#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0602
#include <windows.h>
#include <winioctl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include "anchored_sources.h"

#define REQUIRE(x) do{if(!(x)){fprintf(stderr,"line %d: %s; win32=%lu\n",__LINE__,#x,(unsigned long)GetLastError());ExitProcess(91);}}while(0)
static wchar_t base[2048],root_path[2048],outside[2048],path[2048],other[2048];
static unsigned groups,hook_stage,hook_calls;
static int hook_mode;
static bc_as_root *anchor;
static bc_as_error error;
static void join(wchar_t *out,const wchar_t *a,const wchar_t *b){REQUIRE(swprintf_s(out,2048,L"%ls\\%ls",a,b)>0);}
static void file(const wchar_t *name,const uint8_t *data,DWORD n){
    HANDLE h=CreateFileW(name,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL);DWORD written;
    REQUIRE(h!=INVALID_HANDLE_VALUE);REQUIRE(WriteFile(h,data,n,&written,NULL)&&written==n);REQUIRE(CloseHandle(h));
}
static bc_as_path member(const char *name){bc_as_path p;p.data=(const uint8_t*)name;p.length=strlen(name);return p;}
static void open_anchor(void){anchor=NULL;REQUIRE(bc_as_root_open(root_path,wcslen(root_path),&anchor,&error)==BC_AS_OK);}
static void passed(const char *name){printf("PASS %s\n",name);++groups;}
static bc_as_snapshot *collect(const char *name,size_t limit){
    bc_as_snapshot *s=NULL;bc_as_path p=member(name);bc_as_status status=bc_as_collect(anchor,&p,1,limit,&s,&error);
    if(status!=BC_AS_OK){fprintf(stderr,"collect status=%u nt=%lx os=%lu index=%zu\n",status,(unsigned long)error.ntstatus,(unsigned long)error.win32,error.index);}
    REQUIRE(status==BC_AS_OK);return s;
}
static void denied(const char *name,bc_as_status expected){
    bc_as_snapshot *s=NULL;bc_as_path p=member(name);bc_as_status status=bc_as_collect(anchor,&p,1,4096,&s,&error);
    REQUIRE(status!=BC_AS_OK&&s==NULL);if(expected!=BC_AS_OK){REQUIRE(status==expected);}
}
static void junction(const wchar_t *name,const wchar_t *target){
    struct mount_point {DWORD tag;WORD length,reserved,sub_offset,sub_length,print_offset,print_length;WCHAR names[2048];} data;
    wchar_t substitute[2048];size_t sub,print;HANDLE h;DWORD got;
    _Static_assert(offsetof(struct mount_point,names)==16,"documented mount point buffer header");
    REQUIRE(CreateDirectoryW(name,NULL));REQUIRE(swprintf_s(substitute,2048,L"\\??\\%ls",target)>0);
    memset(&data,0,sizeof(data));sub=wcslen(substitute)*2;print=wcslen(target)*2;
    REQUIRE(sub+print+4<=sizeof(data.names));data.tag=IO_REPARSE_TAG_MOUNT_POINT;
    data.length=(WORD)(8+sub+print+4);data.sub_length=(WORD)sub;data.print_offset=(WORD)(sub+2);data.print_length=(WORD)print;
    memcpy(data.names,substitute,sub+2);memcpy((uint8_t*)data.names+sub+2,target,print+2);
    h=CreateFileW(name,GENERIC_WRITE,0,NULL,OPEN_EXISTING,FILE_FLAG_OPEN_REPARSE_POINT|FILE_FLAG_BACKUP_SEMANTICS,NULL);
    REQUIRE(h!=INVALID_HANDLE_VALUE);REQUIRE(DeviceIoControl(h,FSCTL_SET_REPARSE_POINT,&data,(DWORD)data.length+8,NULL,0,&got,NULL));REQUIRE(CloseHandle(h));
}
void bc_as_test_checkpoint(unsigned stage,HANDLE handle){
    HANDLE h;(void)handle;if(stage!=hook_stage||!hook_mode){return;}++hook_calls;
    if(hook_mode==1){
        REQUIRE(!MoveFileExW(path,other,0));REQUIRE(GetLastError()==ERROR_SHARING_VIOLATION||GetLastError()==ERROR_ACCESS_DENIED);
        h=CreateFileW(path,GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL);
        REQUIRE(h==INVALID_HANDLE_VALUE);REQUIRE(GetLastError()==ERROR_SHARING_VIOLATION||GetLastError()==ERROR_ACCESS_DENIED);
    }else if(hook_mode==3){
        FILETIME created,accessed,written;ULARGE_INTEGER time;
        h=CreateFileW(path,FILE_WRITE_ATTRIBUTES,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,NULL,OPEN_EXISTING,0,NULL);
        REQUIRE(h!=INVALID_HANDLE_VALUE);REQUIRE(GetFileTime(h,&created,&accessed,&written));
        time.LowPart=written.dwLowDateTime;time.HighPart=written.dwHighDateTime;time.QuadPart+=10000000;
        written.dwLowDateTime=time.LowPart;written.dwHighDateTime=time.HighPart;REQUIRE(SetFileTime(h,NULL,NULL,&written));REQUIRE(CloseHandle(h));
    }else if(hook_mode==2){
        REQUIRE(!MoveFileExW(path,other,0));REQUIRE(GetLastError()==ERROR_SHARING_VIOLATION||GetLastError()==ERROR_ACCESS_DENIED);
    }
}
static void ordinary(void){
    bc_as_snapshot *s;bc_as_view v;bc_as_identity id;FILE_ID_INFO native_id;HANDLE h;
    open_anchor();REQUIRE(bc_as_root_identity(anchor,&id)==BC_AS_OK);
    h=CreateFileW(root_path,FILE_READ_ATTRIBUTES,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,NULL,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,NULL);
    REQUIRE(h!=INVALID_HANDLE_VALUE);REQUIRE(GetFileInformationByHandleEx(h,FileIdInfo,&native_id,sizeof(native_id)));
    REQUIRE(id.volume==native_id.VolumeSerialNumber&&memcmp(id.file,native_id.FileId.Identifier,16)==0);REQUIRE(CloseHandle(h));
    s=collect("sub/main.brc",4096);REQUIRE(bc_as_count(s)==1&&bc_as_size(s)==3);
    REQUIRE(bc_as_file(s,0,&v)==BC_AS_OK&&v.length==3&&memcmp(v.bytes,"abc",3)==0);
    REQUIRE(v.name_length==12&&memcmp(v.name,"sub/main.brc",12)==0);REQUIRE(bc_as_file(s,1,&v)==BC_AS_ARGUMENT);
    join(path,root_path,L"sub\\main.brc");file(path,(const uint8_t*)"new",3);
    REQUIRE(bc_as_file(s,0,&v)==BC_AS_OK&&memcmp(v.bytes,"abc",3)==0);
    h=CreateFileW(path,FILE_READ_ATTRIBUTES,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,NULL,OPEN_EXISTING,0,NULL);
    REQUIRE(h!=INVALID_HANDLE_VALUE);REQUIRE(GetFileInformationByHandleEx(h,FileIdInfo,&native_id,sizeof(native_id)));REQUIRE(CloseHandle(h));
    REQUIRE(v.identity.volume==native_id.VolumeSerialNumber&&memcmp(v.identity.file,native_id.FileId.Identifier,16)==0);
    bc_as_root_close(anchor);anchor=NULL;REQUIRE(bc_as_file(s,0,&v)==BC_AS_OK&&memcmp(v.bytes,"abc",3)==0);bc_as_snapshot_close(s);
    passed("bounded snapshots remain owned after source change and anchor close; actual handle identity");
}
static void names(void){
    static const char *bad[]={"../main.brc","a/../b.fy","a/./b.fy","/main.fy","C:/main.fy","\\main.fy","a\\main.fy", "a//b.fy","main.fy:ads","NUL.fy","con/a.fy","COM1.brc","a/LpT9.x.fy","a./b.fy","a /b.fy","a/b.FY","a/*b.fy","a/?.fy","a\x7f.fy","a\xff.fy","", "main.txt","a/b.fy/"};
    size_t i;bc_as_path p[2];bc_as_snapshot *s=NULL;uint8_t long_name[241],embedded[]={ 'a',0,'.','f','y' };
    open_anchor();for(i=0;i<sizeof(bad)/sizeof(bad[0]);++i){REQUIRE(!bc_as_member_path((const uint8_t*)bad[i],strlen(bad[i])));denied(bad[i],BC_AS_NAME);}
    memset(long_name,'a',sizeof(long_name));memcpy(long_name+238,".fy",3);REQUIRE(!bc_as_member_path(long_name,sizeof(long_name)));
    REQUIRE(!bc_as_member_path(embedded,sizeof(embedded)));REQUIRE(bc_as_member_path((const uint8_t*)"a/.fy",5));
    p[0]=member("sub/main.brc");p[1]=member("SUB/MAIN.brc");REQUIRE(bc_as_collect(anchor,p,2,4096,&s,&error)==BC_AS_IDENTITY&&s==NULL);
    bc_as_root_close(anchor);anchor=NULL;passed("authoritative member spelling, ADS/device/escape rejection and decoded byte lengths");
}
static void limits_and_cleanup(void){
    uint8_t data[4097];bc_as_snapshot *s=NULL;bc_as_path p[17];DWORD before,after;size_t i;bc_as_view v;bc_as_status status;
    memset(data,7,sizeof(data));join(path,root_path,L"large.fy");file(path,data,sizeof(data));
    join(path,root_path,L"exact.fy");file(path,data,4096);join(path,root_path,L"empty.fy");file(path,data,0);
    open_anchor();denied("large.fy",BC_AS_LIMIT);s=collect("exact.fy",4096);REQUIRE(bc_as_size(s)==4096);bc_as_snapshot_close(s);s=NULL;
    p[0]=member("exact.fy");REQUIRE(bc_as_collect(anchor,p,1,4095,&s,&error)==BC_AS_LIMIT&&s==NULL);
    p[1]=member("sub/main.brc");REQUIRE(bc_as_collect(anchor,p,2,4096,&s,&error)==BC_AS_LIMIT&&s==NULL);
    s=collect("empty.fy",0);REQUIRE(bc_as_file(s,0,&v)==BC_AS_OK&&v.length==0);bc_as_snapshot_close(s);s=NULL;
    REQUIRE(bc_as_collect(anchor,p,17,4096,&s,&error)==BC_AS_LIMIT&&s==NULL);
    REQUIRE(bc_as_collect(anchor,p,1,4097,&s,&error)==BC_AS_LIMIT&&s==NULL);
    REQUIRE(bc_as_collect(anchor,p,0,4096,&s,&error)==BC_AS_ARGUMENT&&s==NULL);
    for(i=0;i<16;++i){wchar_t leaf[32];static char names[16][32];REQUIRE(swprintf_s(leaf,32,L"f%zu.fy",i)>0);join(path,root_path,leaf);file(path,data,1);REQUIRE(sprintf_s(names[i],32,"f%zu.fy",i)>0);p[i]=member(names[i]);}
    REQUIRE(bc_as_collect(anchor,p,16,16,&s,&error)==BC_AS_OK&&bc_as_count(s)==16);bc_as_snapshot_close(s);s=NULL;
    REQUIRE(GetProcessHandleCount(GetCurrentProcess(),&before));
    for(i=0;i<64;++i){denied("missing.fy",BC_AS_OS);denied("sub/missing.fy",BC_AS_OS);denied("large.fy",BC_AS_LIMIT);}
    bc_as_test_fail_alloc_after(0);status=bc_as_collect(anchor,p,16,16,&s,&error);REQUIRE(status==BC_AS_ALLOCATION&&s==NULL);bc_as_test_fail_alloc_after(-1);
    REQUIRE(GetProcessHandleCount(GetCurrentProcess(),&after)&&before==after);REQUIRE(bc_as_test_live_allocations()==1);
    bc_as_root_close(anchor);anchor=NULL;REQUIRE(bc_as_test_live_allocations()==0);
    bc_as_test_fail_alloc_after(0);REQUIRE(bc_as_root_open(root_path,wcslen(root_path),&anchor,&error)==BC_AS_ALLOCATION&&anchor==NULL);bc_as_test_fail_alloc_after(-1);
    join(path,root_path,L"directory.fy");REQUIRE(CreateDirectoryW(path,NULL));
    open_anchor();denied("directory.fy",BC_AS_KIND);denied("exact.fy/child.fy",BC_AS_KIND);bc_as_root_close(anchor);anchor=NULL;
    join(path,root_path,L"missing-root");REQUIRE(GetProcessHandleCount(GetCurrentProcess(),&before));
    REQUIRE(bc_as_root_open(path,wcslen(path),&anchor,&error)!=BC_AS_OK&&anchor==NULL);
    REQUIRE(GetProcessHandleCount(GetCurrentProcess(),&after)&&before==after&&bc_as_test_live_allocations()==0);
    passed("16/17 files, exact/over/aggregate bytes, empty bytes, file kinds, rollback and handles/allocations");
}
static void reparses(void){
    bc_as_snapshot *s;bc_as_root *r=NULL;wchar_t link[2048],target[2048];BOOLEAN made;
    join(link,root_path,L"junction");junction(link,outside);open_anchor();denied("junction/escape.fy",BC_AS_REPARSE);bc_as_root_close(anchor);anchor=NULL;
    REQUIRE(bc_as_root_open(link,wcslen(link),&r,&error)==BC_AS_REPARSE&&r==NULL);
    join(target,link,L"child");REQUIRE(bc_as_root_open(target,wcslen(target),&r,&error)==BC_AS_REPARSE&&r==NULL);
    join(link,root_path,L"leaf.fy");join(target,outside,L"escape.fy");
    made=CreateSymbolicLinkW(link,target,SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE);
    if(!made&&GetLastError()==ERROR_INVALID_PARAMETER){made=CreateSymbolicLinkW(link,target,0);}
    REQUIRE(made);open_anchor();denied("leaf.fy",BC_AS_REPARSE);bc_as_root_close(anchor);anchor=NULL;
    REQUIRE(DeleteFileW(link));
    join(link,root_path,L"directory-link");made=CreateSymbolicLinkW(link,outside,SYMBOLIC_LINK_FLAG_DIRECTORY|SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE);
    if(!made&&GetLastError()==ERROR_INVALID_PARAMETER){made=CreateSymbolicLinkW(link,outside,SYMBOLIC_LINK_FLAG_DIRECTORY);}
    REQUIRE(made);open_anchor();denied("directory-link/escape.fy",BC_AS_REPARSE);bc_as_root_close(anchor);anchor=NULL;
    REQUIRE(bc_as_root_open(link,wcslen(link),&r,&error)==BC_AS_REPARSE&&r==NULL);REQUIRE(RemoveDirectoryW(link));
    join(path,root_path,L"junction");REQUIRE(RemoveDirectoryW(path));
    open_anchor();s=collect("sub/main.brc",4096);bc_as_snapshot_close(s);bc_as_root_close(anchor);anchor=NULL;
    passed("real directory junction, root/ancestor reparse and leaf/directory symbolic links refused");
}
static void identities_and_pins(void){
    bc_as_path p[2];bc_as_snapshot *s=NULL;HANDLE writer;unsigned i;DWORD a,b;bc_as_root *r=NULL;
    join(path,root_path,L"sub\\main.brc");join(other,root_path,L"alias.fy");REQUIRE(CreateHardLinkW(other,path,NULL));
    open_anchor();p[0]=member("sub/main.brc");p[1]=member("alias.fy");REQUIRE(bc_as_collect(anchor,p,2,4096,&s,&error)==BC_AS_IDENTITY&&s==NULL);
    denied("alias.fy",BC_AS_IDENTITY);denied("sub/main.brc",BC_AS_IDENTITY);REQUIRE(DeleteFileW(other));
    bc_as_root_close(anchor);anchor=NULL;
    {
        wchar_t alias[2048],target[2048];HANDLE ah,th;FILE_ID_INFO aid,tid;FILE_STANDARD_INFO standard;DWORD before,after;
        join(alias,root_path,L"outside-alias.fy");join(target,outside,L"escape.fy");REQUIRE(CreateHardLinkW(alias,target,NULL));
        ah=CreateFileW(alias,FILE_READ_ATTRIBUTES,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,NULL,OPEN_EXISTING,0,NULL);
        th=CreateFileW(target,FILE_READ_ATTRIBUTES,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,NULL,OPEN_EXISTING,0,NULL);
        REQUIRE(ah!=INVALID_HANDLE_VALUE&&th!=INVALID_HANDLE_VALUE);
        REQUIRE(GetFileInformationByHandleEx(ah,FileIdInfo,&aid,sizeof(aid))&&GetFileInformationByHandleEx(th,FileIdInfo,&tid,sizeof(tid)));
        REQUIRE(aid.VolumeSerialNumber==tid.VolumeSerialNumber&&memcmp(aid.FileId.Identifier,tid.FileId.Identifier,16)==0);
        REQUIRE(GetFileInformationByHandleEx(ah,FileStandardInfo,&standard,sizeof(standard))&&standard.NumberOfLinks==2);
        REQUIRE(CloseHandle(ah)&&CloseHandle(th));open_anchor();REQUIRE(GetProcessHandleCount(GetCurrentProcess(),&before));
        denied("outside-alias.fy",BC_AS_IDENTITY);REQUIRE(GetProcessHandleCount(GetCurrentProcess(),&after)&&before==after);
        bc_as_root_close(anchor);anchor=NULL;REQUIRE(DeleteFileW(alias));open_anchor();
    }
    join(other,root_path,L"renamed.brc");hook_mode=1;hook_stage=3;hook_calls=0;s=collect("sub/main.brc",4096);REQUIRE(hook_calls==1);bc_as_snapshot_close(s);
    hook_mode=1;hook_stage=4;hook_calls=0;s=collect("sub/main.brc",4096);REQUIRE(hook_calls==1);bc_as_snapshot_close(s);
    hook_mode=3;hook_stage=4;hook_calls=0;s=NULL;p[0]=member("sub/main.brc");
    REQUIRE(bc_as_collect(anchor,p,1,4096,&s,&error)==BC_AS_CHANGED&&s==NULL&&hook_calls==1);
    join(path,root_path,L"sub");join(other,root_path,L"renamed-dir");hook_mode=2;hook_stage=2;hook_calls=0;s=collect("sub/main.brc",4096);REQUIRE(hook_calls==1);bc_as_snapshot_close(s);hook_mode=0;
    REQUIRE(!MoveFileExW(root_path,other,0));REQUIRE(GetLastError()==ERROR_SHARING_VIOLATION||GetLastError()==ERROR_ACCESS_DENIED);
    bc_as_root_close(anchor);anchor=NULL;
    join(path,root_path,L"sub\\main.brc");writer=CreateFileW(path,GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,NULL,OPEN_EXISTING,0,NULL);REQUIRE(writer!=INVALID_HANDLE_VALUE);
    open_anchor();denied("sub/main.brc",BC_AS_OS);bc_as_root_close(anchor);anchor=NULL;REQUIRE(CloseHandle(writer));
    REQUIRE(GetProcessHandleCount(GetCurrentProcess(),&a));
    for(i=0;i<32;++i){open_anchor();s=collect("sub/main.brc",4096);bc_as_snapshot_close(s);bc_as_root_close(anchor);anchor=NULL;}
    REQUIRE(GetProcessHandleCount(GetCurrentProcess(),&b)&&a==b);REQUIRE(bc_as_test_live_allocations()==0);
    REQUIRE(bc_as_root_open(L"relative",8,&r,&error)==BC_AS_NAME&&r==NULL);
    REQUIRE(bc_as_root_open(L"C:relative",10,&r,&error)==BC_AS_NAME&&r==NULL);
    REQUIRE(bc_as_root_open(L"\\\\?\\C:\\",7,&r,&error)==BC_AS_NAME&&r==NULL);
    {
        wchar_t excessive[1025],deep[256];size_t k;
        for(k=0;k<1025;++k){excessive[k]='a';}excessive[0]='C';excessive[1]=':';excessive[2]='\\';
        REQUIRE(bc_as_root_open(excessive,1025,&r,&error)==BC_AS_NAME&&r==NULL);
        wcscpy_s(deep,256,L"C:\\");for(k=0;k<65;++k){wcscat_s(deep,256,k==0?L"a":L"\\a");}
        REQUIRE(bc_as_root_open(deep,wcslen(deep),&r,&error)==BC_AS_LIMIT&&r==NULL);
    }
    passed("single-name outside-root same-volume hardlink rejected, multi-link leaves rejected, deterministic rename/write/metadata-change interleavings, existing writer and anchor lifetime cleanup");
}
int wmain(int argc,wchar_t **argv){
    wchar_t dir[2048];DWORD n;
    REQUIRE(argc==2);REQUIRE(wcslen(argv[1])<1500);wcscpy_s(base,2048,argv[1]);REQUIRE(CreateDirectoryW(base,NULL));
    join(root_path,base,L"root");REQUIRE(CreateDirectoryW(root_path,NULL));join(outside,base,L"outside");REQUIRE(CreateDirectoryW(outside,NULL));
    join(dir,root_path,L"sub");REQUIRE(CreateDirectoryW(dir,NULL));join(dir,outside,L"child");REQUIRE(CreateDirectoryW(dir,NULL));
    join(path,root_path,L"sub\\main.brc");file(path,(const uint8_t*)"abc",3);join(path,outside,L"escape.fy");file(path,(const uint8_t*)"OUTSIDE",7);
    ordinary();names();limits_and_cleanup();reparses();identities_and_pins();
    REQUIRE(GetProcessHandleCount(GetCurrentProcess(),&n));REQUIRE(bc_as_test_live_allocations()==0);
    printf("RESULT groups=%u live_allocations=0 handles=%lu\n",groups,(unsigned long)n);return 0;
}
