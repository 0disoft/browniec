#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
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

static DWORD WINAPI foreign_instance_destroy(void *arg){
    return bc_instance_destroy(*(const bc_handle *)arg);
}

static bc_event finish_revision_two(bc_handle instance,uint32_t quantum){
    bc_event event={.struct_size=sizeof(event)};
    for(unsigned calls=0;calls<4096;++calls){
        assert(bc_step(instance,quantum,&event)==BC_OK);
        if(event.kind!=BC_DONE){assert(event.payload.data==NULL && event.payload.len==0);}
        assert(event.request_id==0 && event.import_id==0 && event.reserved==0);
        if(event.kind!=BC_YIELD){return event;}
    }
    assert(0 && "revision-2 guest did not finish");
    return event;
}

static size_t read_fixture(const char *name,uint8_t *config,size_t capacity){
    FILE *run=NULL;
    assert(fopen_s(&run,name,"rb")==0);
    const size_t length=fread(config,1,capacity-1,run);
    assert(length>0 && feof(run) && fclose(run)==0);
    config[length]=0;
    return length;
}

static void revision_two_instances(bc_handle engine,bc_handle program){
    uint8_t config[1024];
    const size_t length=read_fixture("run.json",config,sizeof(config));
    bc_slice json={config,length},empty={0};
    bc_handle first=UINT64_MAX,second=0;
    bc_diagnostic diagnostic={.struct_size=sizeof(diagnostic)};
    assert(bc_instance_create(engine,program,(bc_slice){config,1},json,&first,&diagnostic)==BC_BAD_ARGUMENT);
    assert(first==0);
    assert(bc_instance_create(engine,program,empty,(bc_slice){config,1},&first,&diagnostic)==BC_POLICY_ERROR);
    assert(first==0);
    uint8_t *fuel=(uint8_t *)strstr((const char *)config,"10000000");
    assert(fuel);
    memcpy(fuel,"10000001",8);
    assert(bc_instance_create(engine,program,empty,json,&first,&diagnostic)==BC_POLICY_ERROR && first==0);
    memcpy(fuel,"       1",8);
    assert(bc_instance_create(engine,program,empty,json,&first,&diagnostic)==BC_RESOURCE_LIMIT && first==0);
    memcpy(fuel,"10000000",8);
    assert(bc_instance_create(engine,program,empty,json,&first,&diagnostic)==BC_OK);
    uint8_t *frames=(uint8_t *)strstr((const char *)config,"\"call_frames\":128");
    assert(frames);
    frames+=sizeof("\"call_frames\":")-1;
    memcpy(frames,"  2",3);
    assert(bc_instance_create(engine,program,empty,json,&second,&diagnostic)==BC_OK);
    assert(first && second && first!=second);
    expect_diagnostic(&diagnostic,BC_OK);
    bc_handle limited=0;
    memcpy(frames,"  1",3);
    assert(bc_instance_create(engine,program,empty,json,&limited,&diagnostic)==BC_OK);
    memcpy(frames,"128",3);
    bc_handle cancelled=0,expired=0;
    assert(bc_instance_create(engine,program,empty,json,&cancelled,&diagnostic)==BC_OK);
    uint8_t *deadline=(uint8_t *)strstr((const char *)config,"\"deadline_ms\":1000");
    assert(deadline);
    memcpy(deadline+sizeof("\"deadline_ms\":")-1,"   1",4);
    assert(bc_instance_create(engine,program,empty,json,&expired,&diagnostic)==BC_OK);
    assert(bc_preview_instance_destroy(first)==BC_INVALID_HANDLE);
    HANDLE thread=CreateThread(NULL,0,foreign_instance_destroy,&first,0,NULL);
    DWORD status=0;
    assert(thread && WaitForSingleObject(thread,5000)==WAIT_OBJECT_0);
    assert(GetExitCodeThread(thread,&status) && status==BC_WRONG_THREAD && CloseHandle(thread));
    assert(bc_program_release(engine,program)==BC_OK);
    assert(bc_engine_destroy(engine)==BC_BUSY);
    bc_event unchanged={.struct_size=sizeof(unchanged),.kind=UINT32_MAX};
    assert(bc_step(first,0,&unchanged)==BC_BAD_ARGUMENT && unchanged.kind==UINT32_MAX);
    assert(bc_preview_cancel(cancelled)==BC_INVALID_HANDLE);
    assert(bc_cancel(cancelled)==BC_OK);
    bc_event one=finish_revision_two(first,1),many=finish_revision_two(second,64);
    assert(one.kind==BC_DONE && many.kind==BC_DONE && one.return_i32==77 && many.return_i32==77);
    expect_diagnostic(&one.diagnostic,BC_OK);
    assert(one.fuel_used>0 && one.fuel_used==many.fuel_used && one.trap_code==0);
    assert(one.peak_accounted_bytes>0 && one.peak_accounted_bytes==many.peak_accounted_bytes);
    bc_event limit=finish_revision_two(limited,64);
    assert(limit.kind==BC_TRAP && limit.trap_code==12 && limit.diagnostic.code==12);
    assert(limit.diagnostic.source_index==0 && limit.return_i32==0);
    bc_event stopped=finish_revision_two(cancelled,64);
    assert(stopped.kind==BC_FAILED && stopped.diagnostic.code==33 && stopped.trap_code==0 && stopped.return_i32==0);
    Sleep(32);
    assert(bc_cancel(expired)==BC_OK);
    bc_event timed_out=finish_revision_two(expired,64);
    assert(timed_out.kind==BC_FAILED && timed_out.diagnostic.code==30 && timed_out.return_i32==0);
    assert(bc_cancel(first)==BC_OK);
    bc_event again=finish_revision_two(first,64);
    assert(memcmp(&again,&one,sizeof(one))==0);
    again=finish_revision_two(cancelled,1);
    assert(memcmp(&again,&stopped,sizeof(stopped))==0);
    assert(bc_instance_destroy(cancelled)==BC_OK);
    assert(bc_instance_destroy(expired)==BC_OK);
    assert(bc_instance_destroy(limited)==BC_OK);
    assert(bc_instance_destroy(first)==BC_OK && bc_instance_destroy(first)==BC_INVALID_HANDLE);
    assert(bc_instance_destroy(second)==BC_OK);
}

static void revision_two_slot_limit(bc_handle engine,const uint8_t *text,size_t length,const char *field){
    static const uint8_t root[]="main";
    const bc_source source={{root,sizeof(root)-1},{text,length}};
    uint8_t config[1024];
    const bc_slice run={config,read_fixture("run.json",config,sizeof(config))};
    char *count=strstr((char *)config,field);
    assert(count);
    count+=strlen(field);
    assert(memcmp(count,"16384",5)==0);
    bc_handle program=0,exact=0,short_one=0;
    bc_diagnostic diag={.struct_size=sizeof(diag)};
    uint32_t compiled=bc_compile(engine,&source,1,(bc_slice){0},&program,&diag);
    if(compiled!=BC_OK){
        fprintf(stderr,"slot fixture %s failed at %" PRIu32 "..%" PRIu32 " (status %" PRIu32 ")\n",
            field,diag.byte_start,diag.byte_end,compiled);
    }
    assert(compiled==BC_OK);
    memcpy(count,"    2",5);
    assert(bc_instance_create(engine,program,(bc_slice){0},run,&exact,&diag)==BC_OK);
    memcpy(count,"    1",5);
    assert(bc_instance_create(engine,program,(bc_slice){0},run,&short_one,&diag)==BC_OK);
    assert(bc_program_release(engine,program)==BC_OK);
    const bc_event limited=finish_revision_two(short_one,1);
    assert(limited.kind==BC_TRAP && limited.trap_code==13 && limited.diagnostic.source_index==0);
    assert(bc_instance_destroy(short_one)==BC_OK);
    const bc_event done=finish_revision_two(exact,64);
    assert(done.kind==BC_DONE && done.return_i32==77);
    assert(bc_instance_destroy(exact)==BC_OK);
}

static void revision_two_slot_limits(bc_handle engine){
    static const uint8_t owners[]="module main; pub fn i32 main(){"
        "let i32[1] first=[40;1];let i32[1] second=[37;1];return first[0]+second[0];}";
    static const uint8_t descriptors[]="module main; pub fn i32 main(){"
        "let i32[2] values=[40,37];let ref i32[] left=ref values[..1];"
        "let ref i32[] right=ref values[1..];return left[0]+right[0];}";
    revision_two_slot_limit(engine,owners,sizeof(owners)-1,"\"owner_entries\":");
    revision_two_slot_limit(engine,descriptors,sizeof(descriptors)-1,"\"descriptor_entries\":");
}

static void revision_two_object_bytes(bc_handle engine){
    static const uint8_t root[]="main";
    static const uint8_t text[]="module main; pub fn i32 main(){"
        "let i32[1] first=[40;1];let i32[1] second=[37;1];return first[0]+second[0];}";
    const bc_source source={{root,sizeof(root)-1},{text,sizeof(text)-1}};
    uint8_t config[1024];
    const bc_slice run={config,read_fixture("run.json",config,sizeof(config))};
    char *limit=strstr((char *)config,"\"object_bytes\":4194304");
    assert(limit);
    limit+=sizeof("\"object_bytes\":")-1;
    bc_handle program=0,exact=0,short_one=0,default_limit=0;
    bc_diagnostic diag={.struct_size=sizeof(diag)};
    assert(bc_compile(engine,&source,1,(bc_slice){0},&program,&diag)==BC_OK);
    assert(bc_instance_create(engine,program,(bc_slice){0},run,&default_limit,&diag)==BC_OK);
    memcpy(limit,"      8",7);
    assert(bc_instance_create(engine,program,(bc_slice){0},run,&exact,&diag)==BC_OK);
    memcpy(limit,"      7",7);
    assert(bc_instance_create(engine,program,(bc_slice){0},run,&short_one,&diag)==BC_OK);
    assert(bc_program_release(engine,program)==BC_OK);

    const bc_event refused=finish_revision_two(short_one,1);
    assert(refused.kind==BC_TRAP && refused.trap_code==13 && refused.diagnostic.source_index==0);
    assert(bc_instance_destroy(short_one)==BC_OK);
    const bc_event done=finish_revision_two(exact,64);
    const bc_event unrestricted=finish_revision_two(default_limit,64);
    assert(done.kind==BC_DONE && unrestricted.kind==BC_DONE);
    assert(done.return_i32==77 && unrestricted.return_i32==77);
    assert(done.peak_accounted_bytes==refused.peak_accounted_bytes+1);
    assert(unrestricted.peak_accounted_bytes==done.peak_accounted_bytes+65536-8);
    assert(unrestricted.fuel_used==done.fuel_used+65536-8);
    assert(bc_instance_destroy(exact)==BC_OK);
    assert(bc_instance_destroy(default_limit)==BC_OK);
}

static HANDLE input_read, preparation_cancel;
static const uint8_t *guarded_input;

static LONG WINAPI signal_on_input_read(EXCEPTION_POINTERS *exception){
    const EXCEPTION_RECORD *record=exception->ExceptionRecord;
    if(record->ExceptionCode!=STATUS_GUARD_PAGE_VIOLATION || record->NumberParameters<2 ||
        record->ExceptionInformation[1]!=(ULONG_PTR)guarded_input){
        return EXCEPTION_CONTINUE_SEARCH;
    }
    assert(SetEvent(input_read));
    assert(WaitForSingleObject(preparation_cancel,5000)==WAIT_OBJECT_0);
    return EXCEPTION_CONTINUE_EXECUTION;
}

static DWORD WINAPI cancel_on_input_read(void *arg){
    const HANDLE cancel=arg;
    assert(WaitForSingleObject(input_read,5000)==WAIT_OBJECT_0);
    assert(SetEvent(cancel));
    return 0;
}

static void cancel_preparation(bc_handle engine,bc_handle program,bc_slice run){
    input_read=CreateEventW(NULL,TRUE,FALSE,NULL);
    preparation_cancel=CreateEventW(NULL,TRUE,TRUE,NULL);
    assert(input_read && preparation_cancel);
    bc_handle instance=UINT64_MAX;
    bc_diagnostic diagnostic={.struct_size=sizeof(diagnostic)};
    assert(bc_preview_instance_create_cancellable(engine,program,(bc_slice){0},run,
        preparation_cancel,&instance,&diagnostic)==BC_RUN_TERMINATED && instance==0);
    expect_diagnostic(&diagnostic,BC_RUN_TERMINATED);
    assert(ResetEvent(preparation_cancel));

    uint8_t *data=VirtualAlloc(NULL,4096,MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE);
    assert(data);
    memcpy(data,(const uint8_t[]){0,255,77},3);
    guarded_input=data;
    void *handler=AddVectoredExceptionHandler(1,signal_on_input_read);
    DWORD previous=0;
    assert(handler && VirtualProtect(data,4096,PAGE_READWRITE|PAGE_GUARD,&previous));
    HANDLE thread=CreateThread(NULL,0,cancel_on_input_read,preparation_cancel,0,NULL);
    assert(thread);
    instance=UINT64_MAX;
    const bc_slice input={data,3};
    assert(bc_preview_instance_create_cancellable(engine,program,input,run,
        preparation_cancel,&instance,&diagnostic)==BC_RUN_TERMINATED && instance==0);
    expect_diagnostic(&diagnostic,BC_RUN_TERMINATED);
    assert(WaitForSingleObject(thread,5000)==WAIT_OBJECT_0);
    assert(CloseHandle(thread) && RemoveVectoredExceptionHandler(handler));
    guarded_input=NULL;

    assert(ResetEvent(preparation_cancel));
    assert(bc_preview_instance_create_cancellable(engine,program,input,run,
        preparation_cancel,&instance,&diagnostic)==BC_OK && instance!=0);
    assert(SetEvent(preparation_cancel));
    const bc_event result=finish_revision_two(instance,64);
    assert(result.kind==BC_DONE && result.return_i32==77);
    assert(bc_instance_destroy(instance)==BC_OK);
    assert(VirtualFree(data,0,MEM_RELEASE));
    assert(CloseHandle(input_read) && CloseHandle(preparation_cancel));
    puts("PASS: preparation cancellation before and during input copy leaves no handle; clean retry returns 77");
}

static void revision_two_byte_inputs(bc_handle engine){
    static const uint8_t main[]="main";
    static const uint8_t text[]="module main; pub fn i32 main(ref u8[] data){"
        "if(data.len==0){return -1;}if(data[0]!=0 || data[1]!=255){return -2;}"
        "return data[data.len-1] as i32;}";
    const bc_slice name={main,sizeof(main)-1},empty={0};
    const bc_source source={name,{text,sizeof(text)-1}};
    bc_diagnostic diagnostic={.struct_size=sizeof(diagnostic)};
    bc_handle program=0,first=0,second=0,absent=0,refused=UINT64_MAX;
    assert(bc_compile(engine,&source,1,empty,&program,&diagnostic)==BC_OK);
    bc_entry_info info={.struct_size=sizeof(info)};
    assert(bc_program_entry_info(engine,program,name,name,&info,&diagnostic)==BC_OK);
    assert(info.input_kind==BC_INPUT_BYTES && info.required_capabilities_json.len==2);
    assert(memcmp(info.required_capabilities_json.data,"[]",2)==0);

    uint8_t config[1024];
    const bc_slice run={config,read_fixture("run.json",config,sizeof(config))};
    uint8_t *cap=(uint8_t *)strstr((const char *)config,"\"input_bytes\":1048576");
    assert(cap);
    memcpy(cap+sizeof("\"input_bytes\":")-1,"      3",7);
    cancel_preparation(engine,program,run);
    uint8_t bytes[]={0,255,42,99};
    assert(bc_instance_create(engine,program,(bc_slice){NULL,1},run,&refused,&diagnostic)==BC_BAD_ARGUMENT);
    assert(refused==0);
    assert(bc_instance_create(engine,program,(bc_slice){bytes,sizeof(bytes)},run,&refused,&diagnostic)==BC_RESOURCE_LIMIT);
    assert(refused==0);
    assert(bc_instance_create(engine,program,(bc_slice){bytes,3},run,&first,&diagnostic)==BC_OK);
    bytes[2]=77;
    assert(bc_instance_create(engine,program,(bc_slice){bytes,3},run,&second,&diagnostic)==BC_OK);
    assert(bc_instance_create(engine,program,empty,run,&absent,&diagnostic)==BC_OK);
    memset(bytes,0,sizeof(bytes));
    memset(config,0,sizeof(config));
    assert(bc_program_release(engine,program)==BC_OK);
    bc_event a=finish_revision_two(first,1),b=finish_revision_two(second,64),c=finish_revision_two(absent,64);
    assert(a.kind==BC_DONE && a.return_i32==42 && b.kind==BC_DONE && b.return_i32==77);
    assert(c.kind==BC_DONE && c.return_i32==-1);
    assert(a.fuel_used==b.fuel_used && a.peak_accounted_bytes==b.peak_accounted_bytes);
    assert(a.peak_accounted_bytes==c.peak_accounted_bytes+3);
    assert(bc_instance_destroy(first)==BC_OK && bc_instance_destroy(second)==BC_OK);
    assert(bc_instance_destroy(absent)==BC_OK);
}

static void revision_two_shared_descriptors(bc_handle engine){
    static const uint8_t root[]="main";
    static const uint8_t text[]="module main;"
        "fn ref u8[] tail(ref u8[] data){return data[1..];}"
        "pub fn i32 main(ref u8[] data){"
        "let i32[1] values=[35;1];let ref i32[] saved=ref values[..];"
        "var i32 n=0;var i32 value=0;while(n<3){"
        "let ref u8[] part=tail(ref data);value=part[0] as i32;n+=1;}"
        "return saved[0]+value;}";
    static const uint8_t bytes[]={0,42};
    const bc_source source={{root,sizeof(root)-1},{text,sizeof(text)-1}};
    const bc_slice input={bytes,sizeof(bytes)},empty={0};
    uint8_t config[1024];
    const bc_slice run={config,read_fixture("run.json",config,sizeof(config))};
    char *limit=strstr((char *)config,"\"descriptor_entries\":16384");
    assert(limit);
    limit+=sizeof("\"descriptor_entries\":")-1;
    bc_handle program=0;
    bc_diagnostic diag={.struct_size=sizeof(diag)};
    uint32_t compiled=bc_compile(engine,&source,1,empty,&program,&diag);
    if(compiled!=BC_OK){
        fprintf(stderr,"shared descriptor fixture failed at %" PRIu32 "..%" PRIu32 " (status %" PRIu32 ")\n",
            diag.byte_start,diag.byte_end,compiled);
    }
    assert(compiled==BC_OK);

    uint32_t offsets[3]={0};
    for(unsigned entries=1;entries<=4;++entries){
        bc_handle instance=0;
        memcpy(limit,"    ",4);
        limit[4]=(char)('0'+entries);
        assert(bc_instance_create(engine,program,input,run,&instance,&diag)==BC_OK);
        const bc_event result=finish_revision_two(instance,entries==4?64:1);
        if(entries<4){
            assert(result.kind==BC_TRAP && result.trap_code==13 && result.diagnostic.source_index==0);
            offsets[entries-1]=result.diagnostic.byte_start;
        }else{
            assert(result.kind==BC_DONE && result.return_i32==77);
        }
        assert(bc_instance_destroy(instance)==BC_OK);
    }
    // Array opening, CALL entry and the new input range fail at distinct sites.
    assert(offsets[2]<offsets[0] && offsets[0]<offsets[1]);
    assert(bc_program_release(engine,program)==BC_OK);
    puts("PASS: array, CALL and input range share limits; repeated return reuses four descriptors");
}

static DWORD WINAPI foreign_copy_output(void *arg){
    size_t size=SIZE_MAX;
    const uint32_t status=bc_preview_copy_output(*(bc_handle *)arg,NULL,0,&size);
    assert(size==SIZE_MAX);
    return status;
}

static void revision_two_output(bc_handle pure_engine){
    static const uint8_t main[]="main";
    static const uint8_t text[]="module main;pub fn i32 main(ref u8[] data){"
        "output::emit(ref data);if(data[0]==0){return 1/0;}return 77;}";
    static const uint8_t scalar[]="module main;pub fn i32 main(){output::emit(ref b\"A\\x00\");return 77;}";
    static const char capability[]="[\"brownie.output.emit\"]";
    const bc_slice name={main,sizeof(main)-1},empty={0};
    const bc_source source={name,{text,sizeof(text)-1}};
    uint8_t policy[2048],config[1024],denied[1024];
    const bc_slice authority={policy,read_fixture("policy-output.json",policy,sizeof(policy))};
    const bc_slice run={config,read_fixture("run-output.json",config,sizeof(config))};
    const bc_slice no_grant={denied,read_fixture("run.json",denied,sizeof(denied))};
    bc_handle engine=0,program=0,other=0,first=0,second=0,cancelled=0,trapped=0,refused=UINT64_MAX;
    bc_diagnostic diagnostic={.struct_size=sizeof(diagnostic)};
    assert(bc_compile(pure_engine,&source,1,empty,&other,&diagnostic)==BC_OK);
    const uint8_t input_bytes[]={65,0};
    const bc_slice input={input_bytes,sizeof(input_bytes)};
    assert(bc_instance_create(pure_engine,other,input,run,&refused,&diagnostic)==BC_POLICY_ERROR && refused==0);
    assert(bc_program_release(pure_engine,other)==BC_OK);

    assert(bc_engine_create(2,authority,&engine,&diagnostic)==BC_OK);
    assert(bc_compile(engine,&source,1,empty,&program,&diagnostic)==BC_OK);
    bc_entry_info info={.struct_size=sizeof(info)};
    assert(bc_program_entry_info(engine,program,name,name,&info,&diagnostic)==BC_OK);
    assert(info.input_kind==BC_INPUT_BYTES && info.required_capabilities_json.len==sizeof(capability)-1);
    assert(memcmp(info.required_capabilities_json.data,capability,sizeof(capability)-1)==0);
    assert(bc_instance_create(engine,program,input,no_grant,&refused,&diagnostic)==BC_POLICY_ERROR && refused==0);
    assert(bc_instance_create(engine,program,input,run,&first,&diagnostic)==BC_OK);
    assert(bc_instance_create(engine,program,input,run,&cancelled,&diagnostic)==BC_OK);
    const uint8_t fail_bytes[]={0,255};
    assert(bc_instance_create(engine,program,(bc_slice){fail_bytes,sizeof(fail_bytes)},run,&trapped,&diagnostic)==BC_OK);
    const bc_source no_input={name,{scalar,sizeof(scalar)-1}};
    assert(bc_compile(engine,&no_input,1,empty,&other,&diagnostic)==BC_OK);
    assert(bc_instance_create(engine,other,empty,run,&second,&diagnostic)==BC_OK);
    assert(bc_program_release(engine,program)==BC_OK && bc_program_release(engine,other)==BC_OK);

    size_t copied=SIZE_MAX;
    uint8_t detached[]={255,255,255};
    assert(bc_preview_copy_output(first,detached,sizeof(detached),&copied)==BC_BUSY);
    assert(copied==SIZE_MAX && detached[0]==255 && detached[1]==255 && detached[2]==255);
    assert(bc_preview_copy_output(first,NULL,1,&copied)==BC_BAD_ARGUMENT && copied==SIZE_MAX);
    assert(bc_preview_copy_output(first,NULL,0,NULL)==BC_BAD_ARGUMENT);

    bc_event pending={.struct_size=sizeof(pending)};
    assert(bc_step(cancelled,1,&pending)==BC_OK && pending.kind==BC_YIELD && pending.payload.len==0);
    assert(bc_cancel(cancelled)==BC_OK);
    const bc_event stopped=finish_revision_two(cancelled,64),failed=finish_revision_two(trapped,64);
    assert(stopped.kind==BC_FAILED && stopped.diagnostic.code==33);
    assert(failed.kind==BC_TRAP && failed.trap_code==7);
    bc_event a=finish_revision_two(first,1),b=finish_revision_two(second,64);
    assert(a.kind==BC_DONE && b.kind==BC_DONE && a.return_i32==77 && b.return_i32==77);
    assert(a.payload.len==sizeof(input_bytes) && memcmp(a.payload.data,input_bytes,sizeof(input_bytes))==0);
    assert(b.payload.len==sizeof(input_bytes) && memcmp(b.payload.data,input_bytes,sizeof(input_bytes))==0);
    assert(bc_preview_copy_output(cancelled,detached,sizeof(detached),&copied)==BC_RUN_TERMINATED);
    assert(bc_preview_copy_output(trapped,detached,sizeof(detached),&copied)==BC_RUN_TERMINATED);
    assert(copied==SIZE_MAX && detached[0]==255 && detached[1]==255 && detached[2]==255);

    HANDLE thread=CreateThread(NULL,0,foreign_copy_output,&first,0,NULL);
    DWORD foreign_status=0;
    assert(thread && WaitForSingleObject(thread,5000)==WAIT_OBJECT_0);
    assert(GetExitCodeThread(thread,&foreign_status) && foreign_status==BC_WRONG_THREAD && CloseHandle(thread));
    assert(bc_preview_copy_output(first,NULL,0,&copied)==BC_OK && copied==sizeof(input_bytes));
    copied=SIZE_MAX;
    assert(bc_preview_copy_output(first,detached,1,&copied)==BC_RESOURCE_LIMIT && copied==sizeof(input_bytes));
    assert(detached[0]==255 && detached[1]==255 && detached[2]==255);
    assert(bc_preview_copy_output(first,detached,sizeof(input_bytes),&copied)==BC_OK && copied==sizeof(input_bytes));
    assert(bc_instance_destroy(second)==BC_OK && bc_instance_destroy(trapped)==BC_OK);
    assert(bc_cancel(first)==BC_OK);
    bc_event repeated=finish_revision_two(first,64);
    assert(memcmp(&a,&repeated,sizeof(a))==0 && memcmp(repeated.payload.data,input_bytes,sizeof(input_bytes))==0);
    assert(bc_instance_destroy(first)==BC_OK && bc_instance_destroy(cancelled)==BC_OK);
    assert(bc_engine_destroy(engine)==BC_OK);
    assert(memcmp(detached,input_bytes,sizeof(input_bytes))==0 && detached[2]==255);
    copied=SIZE_MAX;
    assert(bc_preview_copy_output(first,detached,sizeof(detached),&copied)==BC_INVALID_HANDLE);
    assert(copied==SIZE_MAX && memcmp(detached,input_bytes,sizeof(input_bytes))==0 && detached[2]==255);
    puts("PASS: sealed output copy survives teardown; pending, failed, short, foreign and stale calls are rejected");
}

static DWORD WINAPI foreign_entry_lookup(void *arg){
    const bc_handle *handles=arg;
    const bc_slice main_name={(const uint8_t *)"main",4};
    bc_entry_info info={.struct_size=sizeof(info),.abi_revision=UINT32_MAX};
    bc_diagnostic diagnostic={.struct_size=sizeof(diagnostic)};
    uint32_t status=bc_program_entry_info(handles[0],handles[1],main_name,main_name,&info,&diagnostic);
    assert(info.abi_revision==UINT32_MAX);
    expect_diagnostic(&diagnostic,status);
    return status;
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

static void revision_two_modules(bc_handle engine,bc_slice policy){
    static const uint8_t main[]="main";
    static const uint8_t rates[]="pricing::rates";
    static const uint8_t root[]="module main; import pricing::rates as fees; "
        "pub fn i32 main(){return fees::amount();}";
    static const uint8_t helper[]="module pricing::rates; pub fn i32 amount(){return 77;}";
    static const uint8_t malformed[]="module pricing::rates; pub fn i32 amount(){return missing;}";
    const bc_slice empty={0},rate_name={rates,sizeof(rates)-1};
    bc_source sources[]={
        {{main,sizeof(main)-1},{root,sizeof(root)-1}},
        {rate_name,{malformed,sizeof(malformed)-1}},
    };
    bc_handle program=UINT64_MAX,instance=0;
    bc_diagnostic diagnostic={.struct_size=sizeof(diagnostic)};
    assert(bc_compile(engine,sources,2,empty,&program,&diagnostic)==BC_COMPILE_ERROR);
    assert(program==0 && diagnostic.source_index==1);
    assert(diagnostic.byte_start==sizeof(malformed)-sizeof("missing;}"));
    assert(diagnostic.byte_end==diagnostic.byte_start+1);

    sources[1].source_utf8=(bc_slice){helper,sizeof(helper)-1};
    sources[1].module=(bc_slice){(const uint8_t *)"other",5};
    assert(bc_compile(engine,sources,2,empty,&program,&diagnostic)==BC_COMPILE_ERROR);
    assert(program==0 && diagnostic.source_index==1);
    assert(diagnostic.byte_start==7 && diagnostic.byte_end==7+sizeof(rates)-1);
    sources[1].module=sources[0].module;
    assert(bc_compile(engine,sources,2,empty,&program,&diagnostic)==BC_COMPILE_ERROR);
    assert(program==0 && diagnostic.source_index==1);
    sources[1].module=rate_name;

    uint8_t short_policy[2048];
    assert(policy.len<sizeof(short_policy));
    memcpy(short_policy,policy.data,policy.len);
    short_policy[policy.len]=0;
    char *modules=strstr((char *)short_policy,"\"modules\": 32");
    assert(modules);
    memcpy(modules+sizeof("\"modules\": ")-1," 1",2);
    bc_handle limited=0;
    assert(bc_engine_create(2,(bc_slice){short_policy,policy.len},&limited,&diagnostic)==BC_OK);
    assert(bc_compile(limited,sources,2,empty,&program,&diagnostic)==BC_RESOURCE_LIMIT);
    assert(program==0 && diagnostic.source_index==UINT32_MAX);
    assert(bc_engine_destroy(limited)==BC_OK);

    uint8_t padded[4097-(sizeof(root)-1)];
    memset(padded,' ',sizeof(padded));
    memcpy(padded,helper,sizeof(helper)-1);
    sources[1].source_utf8=(bc_slice){padded,sizeof(padded)};
    assert(bc_compile(engine,sources,2,empty,&program,&diagnostic)==BC_RESOURCE_LIMIT);
    assert(program==0 && diagnostic.source_index==UINT32_MAX);
    --sources[1].source_utf8.len;
    assert(bc_compile(engine,sources,2,empty,&program,&diagnostic)==BC_OK && program);
    expect_diagnostic(&diagnostic,BC_OK);
    memset(padded,0,sizeof(padded));
    uint8_t config[1024];
    const bc_slice run={config,read_fixture("run.json",config,sizeof(config))};
    assert(bc_instance_create(engine,program,empty,run,&instance,&diagnostic)==BC_OK);
    assert(bc_program_release(engine,program)==BC_OK);
    const bc_event result=finish_revision_two(instance,64);
    assert(result.kind==BC_DONE && result.return_i32==77);
    assert(bc_instance_destroy(instance)==BC_OK);
    puts("PASS: two module sources, second-source diagnostics, policy count, and total byte limit");
}

static void revision_two_programs(bc_handle engine,bc_slice policy){
    static const uint8_t module[]="main";
    static const uint8_t invalid[]="module main; pub fn bool main(){return true;}";
    static const uint8_t valid[]="module main; fn i32 fee(){return 77;} pub fn i32 main(){return fee();}";
    const bc_slice empty={0};
    bc_source source={{module,sizeof(module)-1},{invalid,sizeof(invalid)-1}};
    bc_handle program=UINT64_MAX;
    bc_diagnostic diagnostic={.struct_size=1,.code=UINT32_MAX};
    assert(bc_compile(engine,&source,1,empty,&program,&diagnostic)==BC_BAD_ARGUMENT);
    assert(program==0 && diagnostic.struct_size==1 && diagnostic.code==UINT32_MAX);
    diagnostic.struct_size=sizeof(diagnostic);
    assert(bc_compile(engine,NULL,1,empty,&program,&diagnostic)==BC_BAD_ARGUMENT && program==0);
    assert(bc_compile(engine,&source,0,empty,&program,&diagnostic)==BC_BAD_ARGUMENT && program==0);
    assert(bc_compile(engine,&source,17,empty,&program,&diagnostic)==BC_RESOURCE_LIMIT && program==0);
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
    memset(large,0,sizeof(large));
    const bc_slice main_name=source.module;
    bc_entry_info info={.struct_size=1,.abi_revision=UINT32_MAX};
    assert(bc_program_entry_info(engine,program,main_name,main_name,&info,&diagnostic)==BC_BAD_ARGUMENT);
    assert(info.struct_size==1 && info.abi_revision==UINT32_MAX);
    expect_diagnostic(&diagnostic,BC_BAD_ARGUMENT);
    info.struct_size=sizeof(info);
    assert(bc_program_entry_info(engine,program,main_name,main_name,&info,NULL)==BC_BAD_ARGUMENT);
    assert(bc_program_entry_info(engine,program,main_name,empty,&info,&diagnostic)==BC_BAD_ARGUMENT);
    assert(info.abi_revision==UINT32_MAX);
    assert(bc_program_entry_info(engine,program,main_name,main_name,&info,&diagnostic)==BC_OK);
    expect_diagnostic(&diagnostic,BC_OK);
    assert(info.struct_size==sizeof(info) && info.abi_revision==2 && info.reserved==0);
    assert(info.input_kind==BC_INPUT_NONE && info.required_capabilities_json.len==2);
    assert(memcmp(info.required_capabilities_json.data,"[]",2)==0);
    bc_handle handles[]={engine,program};
    HANDLE thread=CreateThread(NULL,0,foreign_entry_lookup,handles,0,NULL);
    DWORD status=0;
    assert(thread && WaitForSingleObject(thread,5000)==WAIT_OBJECT_0);
    assert(GetExitCodeThread(thread,&status) && status==BC_WRONG_THREAD && CloseHandle(thread));
    assert(bc_engine_destroy(engine)==BC_BUSY);
    assert(bc_program_release(engine,engine)==BC_INVALID_HANDLE);
    assert(bc_preview_program_release(engine,program)==BC_INVALID_HANDLE);
    bc_handle instance=UINT64_MAX;
    assert(bc_preview_instance_create(engine,program,4000000,&instance)==BC_INVALID_HANDLE);
    assert(instance==UINT64_MAX);

    bc_handle other=0;
    assert(bc_engine_create(2,policy,&other,&diagnostic)==BC_OK);
    assert(bc_program_entry_info(other,program,main_name,main_name,&info,&diagnostic)==BC_INVALID_HANDLE);
    assert(bc_program_release(other,program)==BC_INVALID_HANDLE);
    assert(bc_engine_destroy(other)==BC_OK);
    assert(bc_preview_engine_create(BC_PREVIEW_REVISION,&other)==BC_OK);
    bc_handle wrong=UINT64_MAX;
    source.source_utf8=(bc_slice){valid,sizeof(valid)-1};
    assert(bc_compile(other,&source,1,empty,&wrong,&diagnostic)==BC_INVALID_HANDLE && wrong==0);
    assert(bc_preview_compile(other,(bc_slice){valid,sizeof(valid)-1},&wrong)==BC_OK);
    assert(bc_program_entry_info(other,wrong,main_name,main_name,&info,&diagnostic)==BC_INVALID_HANDLE);
    assert(bc_program_release(other,wrong)==BC_INVALID_HANDLE);
    assert(bc_preview_program_release(other,wrong)==BC_OK);
    assert(bc_preview_engine_destroy(other)==BC_OK);
    revision_two_instances(engine,program);
    assert(bc_program_entry_info(engine,program,main_name,main_name,&info,&diagnostic)==BC_INVALID_HANDLE);
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
    revision_two_modules(handle,(bc_slice){policy,length});
    revision_two_byte_inputs(handle);
    revision_two_shared_descriptors(handle);
    revision_two_slot_limits(handle);
    revision_two_object_bytes(handle);
    revision_two_output(handle);
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

static bc_event next_host_event(bc_handle instance,uint32_t quantum){
    bc_event event={.struct_size=sizeof(event)};
    for(unsigned n=0;n<32;++n){
        assert(bc_step(instance,quantum,&event)==BC_OK);
        if(event.kind!=BC_YIELD){return event;}
    }
    assert(0 && "host request or completion expected");
    return event;
}

static void revision_two_host_exchange(void){
    static const uint8_t main_name[]="main";
    static const uint8_t source_text[]=
        "module main; import host::example as api; "
        "pub fn i32 main(){return api::check(41) + 35;}";
    uint8_t catalog[]="{\"schema\":\"brownie.catalog/1\",\"imports\":["
        "{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\","
        "\"parameters\":[\"i32\"],\"result\":\"Result<i32,u32>\",\"effect\":\"read\","
        "\"capability\":\"host.example.check\",\"adapter_revision\":\"v1\"}]}";
    static const uint8_t request[]={1,0,3,0,0,0,4,0,0,0,41,0,0,0};
    uint8_t answer[]={3,0,0,0,4,0,0,0,42,0,0,0};
    static const char caps[]="[\"host.example.check\"]";
    uint8_t policy_data[4096],run_data[1024],pure_data[1024];
    const bc_slice policy={policy_data,read_fixture("policy-host.json",policy_data,sizeof(policy_data))};
    const bc_slice run={run_data,read_fixture("run-host.json",run_data,sizeof(run_data))};
    const bc_slice pure={pure_data,read_fixture("run.json",pure_data,sizeof(pure_data))};
    const bc_slice empty={0};
    const bc_slice name={main_name,sizeof(main_name)-1};
    const bc_source source={name,{source_text,sizeof(source_text)-1}};
    bc_handle engine=0,program=0,one=0,many=0,cancelled=0,fatal=0;
    bc_diagnostic diagnostic={.struct_size=sizeof(diagnostic)};
    assert(bc_engine_create(BC_ABI_REVISION,policy,&engine,&diagnostic)==BC_OK);
    assert(bc_compile(engine,&source,1,(bc_slice){catalog,sizeof(catalog)-1},&program,&diagnostic)==BC_OK);
    memset(catalog,0,sizeof(catalog));
    bc_entry_info info={.struct_size=sizeof(info)};
    assert(bc_program_entry_info(engine,program,name,name,&info,&diagnostic)==BC_OK);
    assert(info.input_kind==BC_INPUT_NONE && info.required_capabilities_json.len==sizeof(caps)-1);
    assert(memcmp(info.required_capabilities_json.data,caps,sizeof(caps)-1)==0);
    assert(bc_instance_create(engine,program,empty,pure,&one,&diagnostic)==BC_POLICY_ERROR && one==0);
    assert(bc_instance_create(engine,program,empty,run,&one,&diagnostic)==BC_OK);
    assert(bc_instance_create(engine,program,empty,run,&many,&diagnostic)==BC_OK);
    assert(bc_instance_create(engine,program,empty,run,&cancelled,&diagnostic)==BC_OK);
    assert(bc_instance_create(engine,program,empty,run,&fatal,&diagnostic)==BC_OK);
    assert(bc_program_release(engine,program)==BC_OK);

    const bc_event a=next_host_event(one,1),b=next_host_event(many,64);
    assert(a.kind==BC_HOST_REQUEST && b.kind==BC_HOST_REQUEST && a.import_id==0 && b.import_id==0);
    assert(a.request_id && b.request_id && a.request_id!=b.request_id);
    assert(a.payload.len==sizeof(request) && memcmp(a.payload.data,request,sizeof(request))==0);
    assert(b.payload.len==sizeof(request) && memcmp(b.payload.data,request,sizeof(request))==0);
    assert(bc_host_reply(one,b.request_id,BC_REPLY_OK,(bc_slice){answer,sizeof(answer)},&diagnostic)==BC_BAD_ARGUMENT);
    assert(bc_host_reply(one,a.request_id,BC_REPLY_OK,(bc_slice){answer,1},&diagnostic)==BC_BAD_ARGUMENT);
    const bc_event waiting=next_host_event(one,1);
    assert(waiting.kind==BC_WAIT && waiting.request_id==a.request_id && waiting.fuel_used==a.fuel_used);
    assert(!waiting.payload.data && !waiting.payload.len);
    assert(bc_host_reply(one,a.request_id,BC_REPLY_OK,(bc_slice){answer,sizeof(answer)},&diagnostic)==BC_OK);
    assert(bc_host_reply(one,a.request_id,BC_REPLY_OK,(bc_slice){answer,sizeof(answer)},&diagnostic)==BC_BAD_ARGUMENT);
    answer[8]=43;
    assert(bc_host_reply(many,b.request_id,BC_REPLY_OK,(bc_slice){answer,sizeof(answer)},&diagnostic)==BC_OK);
    memset(answer,0,sizeof(answer));

    const bc_event done_a=next_host_event(one,1),done_b=next_host_event(many,64);
    assert(done_a.kind==BC_DONE && done_b.kind==BC_DONE);
    assert(done_a.return_i32==77 && done_b.return_i32==78);
    assert(done_a.fuel_used==done_b.fuel_used && done_a.peak_accounted_bytes==done_b.peak_accounted_bytes);
    assert(done_a.peak_accounted_bytes>0 && done_a.payload.len==0 && done_b.payload.len==0);

    const bc_event pending=next_host_event(cancelled,64);
    assert(pending.kind==BC_HOST_REQUEST && bc_cancel(cancelled)==BC_OK);
    assert(bc_host_reply(cancelled,pending.request_id,BC_REPLY_FATAL,empty,&diagnostic)==BC_RUN_TERMINATED);
    const bc_event cancelled_event=next_host_event(cancelled,1);
    assert(cancelled_event.kind==BC_FAILED && cancelled_event.diagnostic.code==33 && cancelled_event.payload.len==0);
    const bc_event fatal_request=next_host_event(fatal,64);
    assert(fatal_request.kind==BC_HOST_REQUEST);
    assert(bc_host_reply(fatal,fatal_request.request_id,BC_REPLY_FATAL,empty,&diagnostic)==BC_OK);
    const bc_event fatal_event=next_host_event(fatal,1);
    assert(fatal_event.kind==BC_FAILED && fatal_event.diagnostic.code==20 && fatal_event.payload.len==0);
    assert(bc_instance_destroy(one)==BC_OK && bc_instance_destroy(many)==BC_OK);
    assert(bc_instance_destroy(cancelled)==BC_OK && bc_instance_destroy(fatal)==BC_OK);
    assert(bc_host_reply(one,a.request_id,BC_REPLY_FATAL,empty,&diagnostic)==BC_INVALID_HANDLE);
    assert(bc_engine_destroy(engine)==BC_OK);
}

static void revision_two_host_owner_limit(bc_handle engine,bc_slice catalog){
    static const uint8_t main_name[]="main";
    static const uint8_t text[]="module main; import host::example as api; pub fn i32 main(){"
        "let i32 first=switch(api::check(b\"x\")){case .ok(_):{35}case .err(_):{10}};"
        "let i32 second=switch(api::check(b\"y\")){case .ok(_):{42}case .err(_):{0}};"
        "return first+second;}";
    const uint8_t empty_buffer[]={7,0,0,0,0,0,0,0};
    const uint8_t one_byte[]={7,0,0,0,1,0,0,0,42};
    const uint8_t error[]={5,0,0,0,4,0,0,0,1,0,0,0};
    uint8_t run_data[1024];
    const bc_slice run={run_data,read_fixture("run-host.json",run_data,sizeof(run_data))};
    const bc_slice empty={0};
    char *owners=strstr((char *)run_data,"\"owner_entries\":16384");
    char *response=strstr((char *)run_data,"\"host_response_bytes\":1048576");
    assert(owners && response);
    owners+=sizeof("\"owner_entries\":")-1;
    memcpy(response+sizeof("\"host_response_bytes\":")-1,"     16",7);

    const bc_source source={{main_name,sizeof(main_name)-1},{text,sizeof(text)-1}};
    bc_handle program=0;
    bc_diagnostic diag={.struct_size=sizeof(diag)};
    uint32_t compiled=bc_compile(engine,&source,1,catalog,&program,&diag);
    if(compiled!=BC_OK){
        fprintf(stderr,"Owner quota fixture failed at %" PRIu32 "..%" PRIu32 " (status %" PRIu32 ")\n",
            diag.byte_start,diag.byte_end,compiled);
    }
    assert(compiled==BC_OK);

    uint64_t limited_peak=0;
    for(unsigned scenario=0;scenario<3;++scenario){
        const bool first_error=scenario==2;
        memcpy(owners,scenario==1?"    2":"    1",5);
        bc_handle instance=0;
        assert(bc_instance_create(engine,program,empty,run,&instance,&diag)==BC_OK);
        const bc_event first=next_host_event(instance,1);
        assert(first.kind==BC_HOST_REQUEST && first.import_id==0);
        const bc_slice initial=first_error?(bc_slice){error,sizeof(error)}:
            (bc_slice){empty_buffer,sizeof(empty_buffer)};
        assert(bc_host_reply(instance,first.request_id,first_error?BC_REPLY_ERR:BC_REPLY_OK,initial,&diag)==BC_OK);
        const bc_event second=next_host_event(instance,64);
        assert(second.kind==BC_HOST_REQUEST && second.import_id==0 && second.request_id!=first.request_id);
        assert(bc_host_reply(instance,second.request_id,BC_REPLY_OK,(bc_slice){one_byte,sizeof(one_byte)},&diag)==BC_OK);
        const bc_event terminal=next_host_event(instance,1);
        if(scenario==0){
            assert(terminal.kind==BC_TRAP && terminal.trap_code==13 && terminal.diagnostic.code==13);
            assert(terminal.payload.data==NULL && terminal.payload.len==0);
            limited_peak=terminal.peak_accounted_bytes;
        }else{
            assert(terminal.kind==BC_DONE && terminal.return_i32==(first_error?52:77));
            assert(terminal.peak_accounted_bytes==limited_peak+(first_error?0:8));
        }
        assert(bc_instance_destroy(instance)==BC_OK);
    }
    assert(bc_program_release(engine,program)==BC_OK);
    puts("PASS: Buffer owner quota includes empty success, skips Result error, and reduces arena reservation");
}

static void revision_two_large_host_reply(void){
    static const uint8_t main_name[]="main";
    static const uint8_t text[]=
        "module main; import host::example as api; pub fn i32 main(){"
        "let Result<brownie /* owner */ ::bytes::Buffer,u32> reply=api::check(b\"x\");"
        "return switch(reply){case .err(_):{17}case .ok(data):{api::next(ref data)+35}};}";
    static const uint8_t catalog[]="{\"schema\":\"brownie.catalog/1\",\"imports\":["
        "{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"ref u8[]\"],"
        "\"result\":\"Result<brownie::bytes::Buffer,u32>\",\"effect\":\"read\","
        "\"capability\":\"host.example.check\",\"adapter_revision\":\"v1\"},"
        "{\"id\":1,\"module\":\"host::example\",\"symbol\":\"next\",\"parameters\":[\"ref u8[]\"],"
        "\"result\":\"Result<i32,u32>\",\"effect\":\"read\","
        "\"capability\":\"host.example.check\",\"adapter_revision\":\"v1\"}]}";
    const uint8_t answer[]={3,0,0,0,4,0,0,0,42,0,0,0};
    const uint8_t error[]={5,0,0,0,4,0,0,0,1,0,0,0};
    enum {body_size=8193};
    uint8_t payload[8+body_size]={7,0,0,0,1,32,0,0};
    for(size_t i=0;i<body_size;++i){payload[8+i]=(uint8_t)(i%251);}
    uint8_t policy_data[4096],run_data[1024];
    const bc_slice policy={policy_data,read_fixture("policy-host.json",policy_data,sizeof(policy_data))};
    const bc_slice config={run_data,read_fixture("run-host.json",run_data,sizeof(run_data))};
    const bc_slice empty={0};
    const bc_source source={{main_name,sizeof(main_name)-1},{text,sizeof(text)-1}};
    bc_handle engine=0,program=0,done=0,cancelled=0,rejected=0;
    bc_diagnostic diag={.struct_size=sizeof(diag)};
    assert(bc_engine_create(BC_ABI_REVISION,policy,&engine,&diag)==BC_OK);
    const uint32_t compiled=bc_compile(engine,&source,1,(bc_slice){catalog,sizeof(catalog)-1},&program,&diag);
    if(compiled!=BC_OK){
        fprintf(stderr,"Large reply fixture compile status %" PRIu32 " source %" PRIu32 " bytes %" PRIu32 "..%" PRIu32 ": %s\n",
            compiled,diag.source_index,diag.byte_start,diag.byte_end,diag.message);
    }
    assert(compiled==BC_OK);
    assert(bc_instance_create(engine,program,empty,config,&done,&diag)==BC_OK);
    assert(bc_instance_create(engine,program,empty,config,&cancelled,&diag)==BC_OK);
    assert(bc_instance_create(engine,program,empty,config,&rejected,&diag)==BC_OK);
    assert(bc_program_release(engine,program)==BC_OK);
    bc_event first=next_host_event(done,64),second=next_host_event(cancelled,64);
    assert(first.kind==BC_HOST_REQUEST && second.kind==BC_HOST_REQUEST);
    assert(bc_host_reply(done,first.request_id,BC_REPLY_OK,(bc_slice){payload,sizeof(payload)},&diag)==BC_OK);
    assert(bc_host_reply(cancelled,second.request_id,BC_REPLY_OK,(bc_slice){payload,sizeof(payload)},&diag)==BC_OK);
    memset(payload,0,sizeof(payload));

    bc_event partial={.struct_size=sizeof(partial)};
    assert(bc_step(cancelled,4096,&partial)==BC_OK && partial.kind==BC_YIELD);
    assert(!partial.payload.data && !partial.payload.len && !partial.request_id);
    assert(bc_cancel(cancelled)==BC_OK);
    const bc_event stopped=next_host_event(cancelled,1);
    assert(stopped.kind==BC_FAILED && stopped.diagnostic.code==33 && stopped.payload.len==0);

    bc_event next={.struct_size=sizeof(next)};
    for(unsigned i=0;i<128;++i){
        assert(bc_step(done,4096,&next)==BC_OK);
        if(next.kind!=BC_YIELD){break;}
    }
    assert(next.kind==BC_HOST_REQUEST && next.import_id==1 && next.request_id!=first.request_id);
    assert(next.payload.len==body_size+10);
    for(size_t i=0;i<body_size;++i){assert(next.payload.data[10+i]==(uint8_t)(i%251));}
    assert(bc_host_reply(done,next.request_id,BC_REPLY_OK,(bc_slice){answer,sizeof(answer)},&diag)==BC_OK);
    const bc_event finished=next_host_event(done,64);
    assert(finished.kind==BC_DONE && finished.return_i32==77);
    const bc_event failed_request=next_host_event(rejected,64);
    assert(failed_request.kind==BC_HOST_REQUEST);
    assert(bc_host_reply(rejected,failed_request.request_id,BC_REPLY_ERR,(bc_slice){error,sizeof(error)},&diag)==BC_OK);
    const bc_event recovered=next_host_event(rejected,64);
    assert(recovered.kind==BC_DONE && recovered.return_i32==17);
    assert(bc_instance_destroy(done)==BC_OK && bc_instance_destroy(cancelled)==BC_OK);
    assert(bc_instance_destroy(rejected)==BC_OK);
    revision_two_host_owner_limit(engine,(bc_slice){catalog,sizeof(catalog)-1});
    assert(bc_engine_destroy(engine)==BC_OK);
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
    size_t copied=SIZE_MAX;
    assert(bc_preview_copy_output(one,NULL,0,&copied)==BC_INVALID_HANDLE && copied==SIZE_MAX);
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
    revision_two_host_exchange();
    revision_two_large_host_reply();
    printf("PASS: quanta 1/64 return 77 and consume %" PRIu64 " fuel; cancellation and ownership verified\n",a.fuel_used);
    puts("PASS: four owner threads independently compiled, stepped, and destroyed their Engines without retries");
    puts("PASS: revision-2 query, Engine policy admission, diagnostic sizing, quotas and stale handles");
    puts("PASS: revision-2 scalar compilation, source spans, size limits and Program ownership");
    puts("PASS: revision-2 Engine source policy rejects 43 bytes and accepts 42 bytes");
    puts("PASS: revision-2 entry info verifies layout, capabilities, and owner-thread admission");
    puts("PASS: revision-2 Instance policy admission, two Program pins, and destruction");
    puts("PASS: revision-2 quanta 1/64, independent cancellation, deadline precedence, and terminal snapshots");
    puts("PASS: call frame limit 1 traps and limit 2 returns 77 from the same Program");
    puts("PASS: owner and descriptor limits of 1 trap and limits of 2 return 77");
    puts("PASS: revision-2 byte input snapshots, empty input, exact byte quota, and peak accounting");
    puts("PASS: revision-2 output authority, binary completion views, cancellation, and trap rollback");
    puts("PASS: revision-2 host request correlation, independent replies, cancellation, and fatal reply");
    puts("PASS: 8193-byte host reply snapshot, cancellation during installation, and guest Result error");
    return 0;
}
