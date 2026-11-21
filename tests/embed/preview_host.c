#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <string.h>
#include "brownie_preview.h"

_Static_assert(sizeof(bc_preview_event)==24,"preview event layout");

static bc_preview_event step(bc_handle instance,uint32_t quantum){
    bc_preview_event event={.struct_size=sizeof(event)};
    assert(bc_preview_step(instance,quantum,&event)==BC_OK);
    return event;
}

static bc_preview_event finish(bc_handle instance,uint32_t quantum){
    for(unsigned calls=0;calls<4096;++calls){
        bc_preview_event event=step(instance,quantum);
        if(event.kind!=BC_PREVIEW_YIELD){return event;}
    }
    assert(0 && "guest did not finish");
    return (bc_preview_event){0};
}

static DWORD WINAPI foreign_step(void *arg){
    bc_preview_event event={.struct_size=sizeof(event)};
    return bc_preview_step(*(bc_handle *)arg,1,&event);
}

static DWORD WINAPI run_owned_engine(void *start){
    static const uint8_t source[]="module main; pub fn i32 main(){var i32 n=0;while(n<77){n+=1;}return n;}";
    bc_handle engine=0,program=0,instance=0;
    assert(WaitForSingleObject(start,5000)==WAIT_OBJECT_0);
    assert(bc_preview_engine_create(BC_PREVIEW_REVISION,&engine)==BC_OK);
    assert(bc_preview_compile(engine,(bc_slice){source,sizeof(source)-1},&program)==BC_OK);
    assert(bc_preview_instance_create(engine,program,4000000,&instance)==BC_OK);
    bc_preview_event event=finish(instance,1);
    assert(event.kind==BC_PREVIEW_DONE && event.return_i32==77 && event.fuel_used>0);
    assert(bc_preview_instance_destroy(instance)==BC_OK);
    assert(bc_preview_program_release(engine,program)==BC_OK);
    assert(bc_preview_engine_destroy(engine)==BC_OK);
    return 0;
}

static void independent_engine_threads(void){
    HANDLE start=CreateEventW(NULL,TRUE,FALSE,NULL);
    HANDLE owners[4];
    assert(start);
    for(unsigned i=0;i<4;++i){
        owners[i]=CreateThread(NULL,0,run_owned_engine,start,0,NULL);
        assert(owners[i]);
    }
    assert(SetEvent(start));
    assert(WaitForMultipleObjects(4,owners,TRUE,10000)==WAIT_OBJECT_0);
    for(unsigned i=0;i<4;++i){
        DWORD status=1;
        assert(GetExitCodeThread(owners[i],&status) && status==0 && CloseHandle(owners[i]));
    }
    assert(CloseHandle(start));
}

static void expect_diagnostic(const bc_diagnostic *diagnostic,uint32_t code){
    assert(diagnostic->struct_size==sizeof(*diagnostic));
    assert(diagnostic->code==code && diagnostic->source_index==UINT32_MAX);
    assert(diagnostic->byte_start==0 && diagnostic->byte_end==0 && diagnostic->flags==0);
    assert(memchr(diagnostic->message,0,sizeof(diagnostic->message)));
    assert((diagnostic->message[0]==0)==(code==BC_OK));
}

static DWORD WINAPI foreign_engine_destroy(void *arg){
    return bc_engine_destroy(*(const bc_handle *)arg);
}

static void revision_two_source_limit(uint8_t *policy,size_t length){
    static const uint8_t module[]="main";
    static const uint8_t text[]="module main; pub fn i32 main(){return 77;} ";
    uint8_t *limit=(uint8_t *)strstr((const char *)policy,"\"source_bytes\": 262144");
    assert(limit);
    limit+=sizeof("\"source_bytes\": ")-1;
    assert(sizeof(text)-2==42);
    memcpy(limit,"    42",6);
    bc_handle engine=0,program=UINT64_MAX;
    bc_diagnostic diagnostic={.struct_size=sizeof(diagnostic)};
    assert(bc_engine_create(2,(bc_slice){policy,length},&engine,&diagnostic)==BC_OK);
    memcpy(limit,"262144",6);

    bc_source source={{module,sizeof(module)-1},{text,sizeof(text)-1}};
    assert(bc_compile(engine,&source,1,(bc_slice){0},&program,&diagnostic)==BC_RESOURCE_LIMIT);
    assert(program==0);
    expect_diagnostic(&diagnostic,BC_RESOURCE_LIMIT);
    --source.source_utf8.len;
    assert(bc_compile(engine,&source,1,(bc_slice){0},&program,&diagnostic)==BC_OK);
    expect_diagnostic(&diagnostic,BC_OK);
    assert(bc_program_release(engine,program)==BC_OK);
    assert(bc_engine_destroy(engine)==BC_OK);
}

static void revision_two_programs(bc_handle engine,bc_slice policy){
    static const uint8_t module[]="main";
    static const uint8_t invalid[]="module main; pub fn bool main(){return true;}";
    static const uint8_t valid[]="module main; pub fn i32 main(){return 77;}";
    const bc_slice empty={0};
    bc_source source={{module,sizeof(module)-1},{invalid,sizeof(invalid)-1}};
    bc_handle program=UINT64_MAX;
    bc_diagnostic diagnostic={.struct_size=1,.code=UINT32_MAX};
    assert(bc_compile(engine,&source,1,empty,&program,&diagnostic)==BC_BAD_ARGUMENT);
    assert(program==0 && diagnostic.struct_size==1 && diagnostic.code==UINT32_MAX);
    diagnostic.struct_size=sizeof(diagnostic);
    assert(bc_compile(engine,NULL,1,empty,&program,&diagnostic)==BC_BAD_ARGUMENT && program==0);
    assert(bc_compile(engine,&source,0,empty,&program,&diagnostic)==BC_BAD_ARGUMENT && program==0);
    assert(bc_compile(engine,&source,2,empty,&program,&diagnostic)==BC_BAD_ARGUMENT && program==0);
    assert(bc_compile(engine,&source,1,(bc_slice){NULL,1},&program,&diagnostic)==BC_BAD_ARGUMENT);
    assert(bc_compile(engine,&source,1,(bc_slice){module,1},&program,&diagnostic)==BC_POLICY_ERROR);
    expect_diagnostic(&diagnostic,BC_POLICY_ERROR);
    assert(bc_compile(engine,&source,1,empty,&program,&diagnostic)==BC_COMPILE_ERROR && program==0);
    assert(diagnostic.code==BC_COMPILE_ERROR && diagnostic.source_index==0);
    assert(diagnostic.byte_start==20 && diagnostic.byte_end==24 && diagnostic.message[0]);

    source.source_utf8=(bc_slice){NULL,sizeof(valid)-1};
    assert(bc_compile(engine,&source,1,empty,&program,&diagnostic)==BC_BAD_ARGUMENT && program==0);
    uint8_t large[4097];
    memset(large,' ',sizeof(large));
    memcpy(large,valid,sizeof(valid)-1);
    source.source_utf8=(bc_slice){large,sizeof(large)};
    assert(bc_compile(engine,&source,1,empty,&program,&diagnostic)==BC_RESOURCE_LIMIT && program==0);
    expect_diagnostic(&diagnostic,BC_RESOURCE_LIMIT);
    --source.source_utf8.len;
    assert(bc_compile(engine,&source,1,empty,&program,&diagnostic)==BC_OK && program!=0);
    expect_diagnostic(&diagnostic,BC_OK);
    assert(bc_engine_destroy(engine)==BC_BUSY);
    assert(bc_program_release(engine,engine)==BC_INVALID_HANDLE);
    assert(bc_preview_program_release(engine,program)==BC_INVALID_HANDLE);
    bc_handle instance=UINT64_MAX;
    assert(bc_preview_instance_create(engine,program,4000000,&instance)==BC_INVALID_HANDLE);
    assert(instance==UINT64_MAX);

    bc_handle other=0;
    assert(bc_engine_create(2,policy,&other,&diagnostic)==BC_OK);
    assert(bc_program_release(other,program)==BC_INVALID_HANDLE);
    assert(bc_engine_destroy(other)==BC_OK);
    assert(bc_preview_engine_create(BC_PREVIEW_REVISION,&other)==BC_OK);
    bc_handle wrong=UINT64_MAX;
    assert(bc_compile(other,&source,1,empty,&wrong,&diagnostic)==BC_INVALID_HANDLE && wrong==0);
    assert(bc_preview_compile(other,(bc_slice){valid,sizeof(valid)-1},&wrong)==BC_OK);
    assert(bc_program_release(other,wrong)==BC_INVALID_HANDLE);
    assert(bc_preview_program_release(other,wrong)==BC_OK);
    assert(bc_preview_engine_destroy(other)==BC_OK);
    assert(bc_program_release(engine,program)==BC_OK);
    assert(bc_program_release(engine,program)==BC_INVALID_HANDLE);
}

static void revision_two_engines(void){
    bc_abi_info abi={0};
    assert(bc_get_abi_info_v2(1,sizeof(abi),&abi)==BC_ABI_MISMATCH && abi.struct_size==0);
    assert(bc_get_abi_info_v2(2,sizeof(abi)-1,&abi)==BC_ABI_MISMATCH && abi.struct_size==0);
    assert(bc_get_abi_info_v2(2,sizeof(abi),&abi)==BC_OK);
    assert(abi.abi_revision==2 && abi.struct_size==sizeof(abi) && abi.pointer_bits==64);
    assert(abi.diagnostic_size==sizeof(bc_diagnostic) && abi.event_size==sizeof(bc_event));
    assert(abi.entry_info_size==sizeof(bc_entry_info) && abi.source_size==sizeof(bc_source));
    assert(abi.slice_size==sizeof(bc_slice));

    bc_handle handle=UINT64_MAX;
    bc_diagnostic diagnostic={.struct_size=1,.code=UINT32_MAX};
    assert(bc_engine_create(1,(bc_slice){0},&handle,&diagnostic)==BC_ABI_MISMATCH);
    assert(handle==0 && diagnostic.code==UINT32_MAX);
    handle=UINT64_MAX;
    assert(bc_engine_create(2,(bc_slice){0},&handle,&diagnostic)==BC_BAD_ARGUMENT);
    assert(handle==0 && diagnostic.struct_size==1 && diagnostic.code==UINT32_MAX);
    handle=UINT64_MAX;
    assert(bc_engine_create(2,(bc_slice){0},&handle,NULL)==BC_BAD_ARGUMENT && handle==0);
    diagnostic.struct_size=sizeof(diagnostic);
    assert(bc_engine_create(2,(bc_slice){NULL,1},&handle,&diagnostic)==BC_BAD_ARGUMENT);
    expect_diagnostic(&diagnostic,BC_BAD_ARGUMENT);
    const uint8_t malformed[]="{\"schema\":\"brownie.policy/0.3\",\"schema\":\"brownie.policy/0.3\"}";
    assert(bc_engine_create(2,(bc_slice){malformed,sizeof(malformed)-1},&handle,&diagnostic)==BC_POLICY_ERROR);
    assert(handle==0);
    expect_diagnostic(&diagnostic,BC_POLICY_ERROR);

    static uint8_t policy[65537];
    FILE *file=NULL;
    assert(fopen_s(&file,"policy.json","rb")==0);
    size_t length=fread(policy,1,sizeof(policy)-1,file);
    assert(length>0 && feof(file) && fclose(file)==0);
    uint8_t *limit=(uint8_t *)strstr((const char *)policy,"\"control_bytes\": 1048576");
    assert(limit);
    limit+=sizeof("\"control_bytes\": ")-1;
    memcpy(limit,"      1",7);
    assert(bc_engine_create(2,(bc_slice){policy,length},&handle,&diagnostic)==BC_RESOURCE_LIMIT);
    assert(handle==0);
    expect_diagnostic(&diagnostic,BC_RESOURCE_LIMIT);
    memcpy(limit,"1048576",7);
    memset(policy+length,' ',sizeof(policy)-length);
    assert(bc_engine_create(2,(bc_slice){policy,sizeof(policy)},&handle,&diagnostic)==BC_RESOURCE_LIMIT);
    assert(handle==0);
    assert(bc_engine_create(2,(bc_slice){policy,sizeof(policy)-1},&handle,&diagnostic)==BC_OK);
    assert(handle!=0);
    expect_diagnostic(&diagnostic,BC_OK);
    revision_two_programs(handle,(bc_slice){policy,length});
    revision_two_source_limit(policy,length);
    memset(policy,0,sizeof(policy));
    HANDLE thread=CreateThread(NULL,0,foreign_engine_destroy,&handle,0,NULL);
    DWORD status=0;
    assert(thread && WaitForSingleObject(thread,5000)==WAIT_OBJECT_0);
    assert(GetExitCodeThread(thread,&status) && status==BC_WRONG_THREAD && CloseHandle(thread));
    bc_handle program=UINT64_MAX;
    assert(bc_preview_compile(handle,(bc_slice){malformed,sizeof(malformed)-1},&program)==BC_INVALID_HANDLE);
    assert(program==UINT64_MAX);
    assert(bc_preview_engine_destroy(handle)==BC_INVALID_HANDLE);
    assert(bc_engine_destroy(handle)==BC_OK);
    assert(bc_engine_destroy(handle)==BC_INVALID_HANDLE);

    assert(bc_preview_engine_create(BC_PREVIEW_REVISION,&handle)==BC_OK);
    assert(bc_engine_destroy(handle)==BC_INVALID_HANDLE);
    assert(bc_preview_engine_destroy(handle)==BC_OK);
}

int main(void){
    uint8_t text[]="module main; fn i32 inc(i32 n){return n+1;} "
        "pub fn i32 main(){var i32 n=70;while(n<77){n=inc(n);}return n;}";
    const uint8_t invalid[]="module main; pub fn bool main(){return true;}";
    bc_handle engine=0,other=0,program=0,one=0,many=0,cancelled=0,short_fuel=0;
    bc_handle unchanged=UINT64_MAX;
    assert(bc_preview_engine_create(0,&unchanged)==BC_ABI_MISMATCH && unchanged==UINT64_MAX);
    assert(bc_preview_engine_create(BC_PREVIEW_REVISION,&engine)==BC_OK);
    assert(bc_preview_engine_create(BC_PREVIEW_REVISION,&other)==BC_OK);
    assert(bc_preview_compile(engine,(bc_slice){invalid,sizeof(invalid)-1},&unchanged)==BC_COMPILE_ERROR);
    assert(unchanged==UINT64_MAX);
    assert(bc_preview_compile(engine,(bc_slice){text,sizeof(text)-1},&program)==BC_OK);
    memset(text,0,sizeof(text));
    assert(bc_preview_instance_create(other,program,100000,&unchanged)==BC_INVALID_HANDLE);
    assert(bc_preview_engine_destroy(other)==BC_OK);
    assert(bc_preview_instance_create(engine,program,4000000,&one)==BC_OK);
    assert(bc_preview_instance_create(engine,program,8000000,&many)==BC_OK);
    assert(bc_preview_instance_create(engine,program,1000000,&cancelled)==BC_OK);
    assert(bc_preview_instance_create(engine,program,1000000,&short_fuel)==BC_OK);
    assert(bc_preview_instance_create(engine,program,0,&unchanged)==BC_RESOURCE_LIMIT);
    assert(bc_preview_engine_destroy(engine)==BC_BUSY);

    HANDLE thread=CreateThread(NULL,0,foreign_step,&many,0,NULL);
    assert(thread && WaitForSingleObject(thread,5000)==WAIT_OBJECT_0);
    DWORD status=0;
    assert(GetExitCodeThread(thread,&status) && status==BC_WRONG_THREAD && CloseHandle(thread));
    assert(bc_preview_program_release(engine,program)==BC_OK);
    assert(bc_preview_instance_create(engine,program,100000,&unchanged)==BC_INVALID_HANDLE);
    assert(unchanged==UINT64_MAX);

    assert(step(one,1).kind==BC_PREVIEW_YIELD);
    assert(step(cancelled,1).kind==BC_PREVIEW_YIELD);
    assert(bc_preview_cancel(cancelled)==BC_OK);
    bc_preview_event a=finish(one,1),b=finish(many,64),c=finish(cancelled,64);
    assert(a.kind==BC_PREVIEW_DONE && b.kind==BC_PREVIEW_DONE);
    assert(a.return_i32==77 && b.return_i32==77 && a.fuel_used>0 && a.fuel_used==b.fuel_used);
    assert(c.kind==BC_PREVIEW_CANCELLED && c.fuel_used<a.fuel_used);
    bc_preview_event exhausted=finish(short_fuel,64);
    assert(exhausted.kind==BC_PREVIEW_TRAP && exhausted.diagnostic_code==8);
    assert(bc_preview_cancel(many)==BC_OK);
    bc_preview_event again=step(many,1);
    assert(again.kind==b.kind && again.return_i32==b.return_i32 && again.fuel_used==b.fuel_used);
    assert(bc_preview_instance_destroy(one)==BC_OK);
    assert(bc_preview_cancel(one)==BC_INVALID_HANDLE);
    assert(bc_preview_instance_destroy(many)==BC_OK);
    assert(bc_preview_instance_destroy(cancelled)==BC_OK);
    assert(bc_preview_instance_destroy(short_fuel)==BC_OK);
    assert(bc_preview_engine_destroy(engine)==BC_OK);
    assert(bc_preview_engine_destroy(engine)==BC_INVALID_HANDLE);
    independent_engine_threads();
    revision_two_engines();
    printf("PASS: quanta 1/64 return 77 and consume %" PRIu64 " fuel; cancellation and ownership verified\n",a.fuel_used);
    puts("PASS: four owner threads independently compiled, stepped, and destroyed their Engines without retries");
    puts("PASS: revision-2 query, Engine policy admission, diagnostic sizing, quotas and stale handles");
    puts("PASS: revision-2 scalar compilation, source spans, size limits and Program ownership");
    puts("PASS: revision-2 Engine source policy rejects 43 bytes and accepts 42 bytes");
    return 0;
}
