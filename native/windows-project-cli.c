/* Windows application source for Fairy C's project-root include path. */
#include "native/anchored_sources.c"
#include "native/anchored-source-loader/bridge.c"

#include "native/runtime_input_reader.h"
#include "native/host_adapter_process.h"
#include <bcrypt.h>

// One configured run per CLI process. The console thread only latches a flag.
static volatile LONG cancel_requested;
static BOOL WINAPI configured_run_control(DWORD event){
    if(event!=CTRL_C_EVENT&&event!=CTRL_BREAK_EVENT){return FALSE;}
    InterlockedExchange(&cancel_requested,1);
    return TRUE;
}
uint32_t bc_cli_enable_cancel(void){
    DWORD process;
    if(!GetConsoleProcessList(&process,1)){return 1;}
    return SetConsoleCtrlHandler(configured_run_control,TRUE)?1:0;
}
uint32_t bc_cli_cancel_requested(void){
    return InterlockedCompareExchange(&cancel_requested,0,0)!=0;
}

/* The CLI runs one Instance and admits one adapter lease at a time. */
static bc_adapter_budget adapter_budget = {
    .live_limit = 1,
    .launch_limit = 65535,
    .wire_limit = 65535 * (2 * BC_ADAPTER_HEADER_BYTES + 2 * BC_ADAPTER_BODY_LIMIT + 1)
};
static bc_adapter_slot adapter_slot = {.budget = &adapter_budget};
void *bc_cli_adapter_slot(void){return &adapter_slot;}
void bc_cli_adapter_wait(void){Sleep(1);}
uint32_t bc_cli_adapter_reap(void){
    ULONGLONG started=GetTickCount64();
    while(!bc_adapter_slot_close(&adapter_slot)){
        if(GetTickCount64()-started>=1000)return 0;
        Sleep(1);
    }
    return 1;
}

/* Resolve only an explicitly selected host file. Project member containment
   remains the separate anchored-source contract. */
static DWORD cli_disk_path(const uint8_t *path,size_t length,wchar_t *absolute){
    wchar_t raw[BC_AS_ROOT_CHARS+1];
    int units=decode_path(path,length,raw,BC_AS_ROOT_CHARS);
    if(!units||raw[0]=='\\'||raw[0]=='/'){return 0;}
    if(units>=2&&raw[1]==':'&&(units<3||(raw[2]!='\\'&&raw[2]!='/'))){return 0;}
    for(int i=0;i<units;++i){if(raw[i]==':'&&i!=1){return 0;}}
    if(raw[units-1]==' '||raw[units-1]=='.'||raw[units-1]=='\\'||raw[units-1]=='/'){return 0;}
    raw[units]=0;
    DWORD resolved=GetFullPathNameW(raw,BC_AS_ROOT_CHARS+1,absolute,NULL);
    return resolved<=BC_AS_ROOT_CHARS?resolved:0;
}

void *bc_cli_read_input(const uint8_t *path,size_t length,size_t limit,uint32_t *status){
    wchar_t absolute[BC_AS_ROOT_CHARS+1];
    bc_rir_snapshot *snapshot=NULL;
    DWORD resolved=cli_disk_path(path,length,absolute);
    *status=BC_RIR_ARGUMENT;
    if(!resolved){return NULL;}
    *status=(uint32_t)bc_rir_path(absolute,resolved,limit,&snapshot,NULL);
    return snapshot;
}

/* Keep the staging file pinned by handle through the no-replace rename. */
uint32_t bc_cli_write_output(const uint8_t *path,size_t length,const uint8_t *data,size_t count){
    union { FILE_RENAME_INFO info; unsigned char bytes[sizeof(FILE_RENAME_INFO)+(4+BC_AS_ROOT_CHARS+1)*sizeof(wchar_t)]; } target={0};
    wchar_t *extended=(wchar_t *)(target.bytes+offsetof(FILE_RENAME_INFO,FileName));
    memcpy(extended,L"\\\\?\\",4*sizeof(wchar_t));
    wchar_t *absolute=extended+4;
    DWORD resolved=cli_disk_path(path,length,absolute);
    if(resolved<4||absolute[1]!=L':'||absolute[2]!=L'\\'||count>1048576){return 0;}
    wchar_t *leaf=wcsrchr(absolute,L'\\')+1;
    size_t prefix=(size_t)(leaf-extended);
    static const wchar_t marker[]=L".browniec-";
    static const wchar_t hex[]=L"0123456789abcdef";
    uint8_t nonce[16];
    wchar_t sibling[4+BC_AS_ROOT_CHARS+sizeof(marker)/sizeof(*marker)+2*sizeof(nonce)];
    if(BCryptGenRandom(NULL,nonce,sizeof(nonce),BCRYPT_USE_SYSTEM_PREFERRED_RNG)<0){return 0;}
    memcpy(sibling,extended,prefix*sizeof(wchar_t));
    memcpy(sibling+prefix,marker,sizeof(marker)-sizeof(wchar_t));
    wchar_t *suffix=sibling+prefix+sizeof(marker)/sizeof(*marker)-1;
    for(size_t i=0;i<sizeof(nonce);++i){suffix[2*i]=hex[nonce[i]>>4];suffix[2*i+1]=hex[nonce[i]&15];}
    suffix[2*sizeof(nonce)]=0;

    HANDLE file=CreateFileW(sibling,GENERIC_WRITE|DELETE,0,NULL,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,NULL);
    if(file==INVALID_HANDLE_VALUE){return 0;}
    HANDLE publish=NULL;
    DWORD written=0;
    BOOL ok=GetFileType(file)==FILE_TYPE_DISK &&
        (!count||(WriteFile(file,data,(DWORD)count,&written,NULL)&&written==count)) &&
        FlushFileBuffers(file) &&
        DuplicateHandle(GetCurrentProcess(),file,GetCurrentProcess(),&publish,DELETE,FALSE,0);
    FILE_DISPOSITION_INFO discard={TRUE};
    if(!ok){
        SetFileInformationByHandle(file,FileDispositionInfo,&discard,sizeof(discard));
        CloseHandle(file);
        return 0;
    }
    target.info.FileNameLength=(4+resolved)*sizeof(wchar_t);
    ok=CloseHandle(file) && SetFileInformationByHandle(publish,FileRenameInfo,&target,
        (DWORD)(offsetof(FILE_RENAME_INFO,FileName)+target.info.FileNameLength+sizeof(wchar_t)));
    if(!ok){SetFileInformationByHandle(publish,FileDispositionInfo,&discard,sizeof(discard));}
    CloseHandle(publish);
    return ok;
}

void *bc_cli_read_stdin(size_t limit,uint32_t *status){
    bc_rir_snapshot *snapshot=NULL;
    *status=(uint32_t)bc_rir_handle(GetStdHandle(STD_INPUT_HANDLE),limit,&snapshot,NULL);
    return snapshot;
}

size_t bc_cli_input_length(void *snapshot){return bc_rir_length(snapshot);}
const uint8_t *bc_cli_input_bytes(void *snapshot){return bc_rir_bytes(snapshot);}
void bc_cli_input_close(void *snapshot){bc_rir_close(snapshot);}
