/* Windows application source for Fairy C's project-root include path. */
#include "native/anchored_sources.c"
#include "native/anchored-source-loader/bridge.c"

#include "native/runtime_input_reader.h"

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

/* Resolve only an explicitly selected host file. Project member containment
   remains the separate anchored-source contract. */
void *bc_cli_read_input(const uint8_t *path,size_t length,size_t limit,uint32_t *status){
    wchar_t raw[BC_AS_ROOT_CHARS+1],absolute[BC_AS_ROOT_CHARS+1];
    bc_rir_snapshot *snapshot=NULL;
    int units=decode_path(path,length,raw,BC_AS_ROOT_CHARS);
    *status=BC_RIR_ARGUMENT;
    if(!units||raw[0]=='\\'||raw[0]=='/'){return NULL;}
    if(units>=2&&raw[1]==':'&&(units<3||(raw[2]!='\\'&&raw[2]!='/'))){return NULL;}
    for(int i=0;i<units;++i){if(raw[i]==':'&&i!=1){return NULL;}}
    if(raw[units-1]==' '||raw[units-1]=='.'||raw[units-1]=='\\'||raw[units-1]=='/'){return NULL;}
    raw[units]=0;
    DWORD resolved=GetFullPathNameW(raw,BC_AS_ROOT_CHARS+1,absolute,NULL);
    if(!resolved||resolved>BC_AS_ROOT_CHARS){return NULL;}
    *status=(uint32_t)bc_rir_path(absolute,resolved,limit,&snapshot,NULL);
    return snapshot;
}

void *bc_cli_read_stdin(size_t limit,uint32_t *status){
    bc_rir_snapshot *snapshot=NULL;
    *status=(uint32_t)bc_rir_handle(GetStdHandle(STD_INPUT_HANDLE),limit,&snapshot,NULL);
    return snapshot;
}

size_t bc_cli_input_length(void *snapshot){return bc_rir_length(snapshot);}
const uint8_t *bc_cli_input_bytes(void *snapshot){return bc_rir_bytes(snapshot);}
void bc_cli_input_close(void *snapshot){bc_rir_close(snapshot);}
