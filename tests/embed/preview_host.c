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
    printf("PASS: quanta 1/64 return 77 and consume %" PRIu64 " fuel; cancellation and ownership verified\n",a.fuel_used);
    puts("PASS: four owner threads independently compiled, stepped, and destroyed their Engines without retries");
    return 0;
}
