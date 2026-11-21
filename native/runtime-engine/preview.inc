/* Included after the isolated Fairy transport and reviewed binding declarations. */
#define BC_BUILD_PREVIEW_DLL
#include "brownie_preview.h"
#include "abi_registry.h"

typedef struct preview_engine {
    bc_engine engine;
    size_t children;
} preview_engine;

typedef struct preview_child {
    preview_engine *owner;
    uintptr_t id;
    uint64_t fuel;
} preview_child;

/* Serialize the full preview API. Registry operations use their own short
   guard and can therefore finish an admission even after VM work commits. */
static SRWLOCK preview_guard=SRWLOCK_INIT;
enum {ENGINE_HANDLE=1, PROGRAM_HANDLE=2, INSTANCE_HANDLE=3};

void bc_embed_binding(uint32_t id){(void)id;}
void bc_runtime_engine_binding(uint32_t id){(void)id;}
const uint8_t *bc_embed_witness_source(void){return NULL;}

static _Noreturn void preview_invariant(void){
    RaiseFailFastException(NULL,NULL,0);
    ExitProcess(BC_INTERNAL_ERROR);
}

static uint32_t preview_status(uint32_t status){
    return status==14?BC_ENGINE_POISONED:status;
}

static uint32_t finish_preview(uint32_t status){
    ReleaseSRWLockExclusive(&preview_guard);
    return preview_status(status);
}

static void leave_preview(const bc_abi_registry_admission *admission){
    if(bc_abi_registry_leave(admission)!=BC_OK){preview_invariant();}
}

static void remove_preview(const bc_abi_registry_admission *admission){
    uint64_t removed=0;
    if(bc_abi_registry_remove(admission,&removed)!=BC_OK || removed!=admission->object){preview_invariant();}
}

uint32_t BC_CALL bc_preview_engine_create(uint32_t revision,bc_handle *out){
    if(revision!=BC_PREVIEW_REVISION){return BC_ABI_MISMATCH;}
    if(!out){return BC_BAD_ARGUMENT;}
    if(!TryAcquireSRWLockExclusive(&preview_guard)){return BC_BUSY;}
    preview_engine *owner=HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,sizeof(*owner));
    if(!owner){return finish_preview(BC_ALLOCATION_ERROR);}
    __typeof__(P1()) created=P1();
    if(created.tag!=FY_RESULT_OK){
        HeapFree(GetProcessHeap(),0,owner);
        return finish_preview(created.p_1.f_0);
    }
    owner->engine=created.p_0;
    bc_handle handle=0;
    uint32_t status=bc_abi_registry_create_engine((uintptr_t)owner,&handle);
    if(status!=BC_OK){
        if(P8(&owner->engine).tag!=FY_RESULT_OK){preview_invariant();}
        HeapFree(GetProcessHeap(),0,owner);
    }else{*out=handle;}
    return finish_preview(status);
}

uint32_t BC_CALL bc_preview_compile(bc_handle engine,bc_slice source,bc_handle *out){
    if(!out||!source.data||!source.len){return BC_BAD_ARGUMENT;}
    if(source.len>4096){return BC_RESOURCE_LIMIT;}
    if(!TryAcquireSRWLockExclusive(&preview_guard)){return BC_BUSY;}
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter(engine,ENGINE_HANDLE,engine,&admission);
    if(status!=BC_OK){return finish_preview(status);}
    preview_engine *owner=(preview_engine *)(uintptr_t)admission.object;
    preview_child *program=HeapAlloc(GetProcessHeap(),0,sizeof(*program));
    if(!program){leave_preview(&admission);return finish_preview(BC_ALLOCATION_ERROR);}
    __typeof__(P2(&owner->engine,source.data,source.len)) compiled=P2(&owner->engine,source.data,source.len);
    if(compiled.tag==FY_RESULT_OK){
        *program=(preview_child){owner,compiled.p_0,0};
        status=bc_abi_registry_insert(&admission,PROGRAM_HANDLE,(uintptr_t)program,out);
        if(status==BC_OK){++owner->children;}
        else if(P7(&owner->engine,program->id).tag!=FY_RESULT_OK){preview_invariant();}
    }else{status=compiled.p_1.f_0;}
    if(status!=BC_OK){HeapFree(GetProcessHeap(),0,program);}
    leave_preview(&admission);
    return finish_preview(status);
}

uint32_t BC_CALL bc_preview_instance_create(bc_handle engine,bc_handle program,uint64_t fuel,bc_handle *out){
    if(!out){return BC_BAD_ARGUMENT;}
    if(fuel>BC_PREVIEW_MAX_FUEL){return BC_RESOURCE_LIMIT;}
    if(!TryAcquireSRWLockExclusive(&preview_guard)){return BC_BUSY;}
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter(program,PROGRAM_HANDLE,engine,&admission);
    if(status!=BC_OK){return finish_preview(status);}
    preview_child *code=(preview_child *)(uintptr_t)admission.object;
    preview_engine *owner=code->owner;
    preview_child *instance=HeapAlloc(GetProcessHeap(),0,sizeof(*instance));
    if(!instance){leave_preview(&admission);return finish_preview(BC_ALLOCATION_ERROR);}
    __typeof__(P3(&owner->engine,code->id,fuel)) prepared=P3(&owner->engine,code->id,fuel);
    if(prepared.tag==FY_RESULT_OK){
        *instance=(preview_child){owner,prepared.p_0,fuel};
        status=bc_abi_registry_insert(&admission,INSTANCE_HANDLE,(uintptr_t)instance,out);
        if(status==BC_OK){++owner->children;}
        else if(P6(&owner->engine,instance->id).tag!=FY_RESULT_OK){preview_invariant();}
    }else{
        status=prepared.p_1.f_0;
        // The private preparation API reports setup Fuel exhaustion as a
        // diagnostic. No Instance exists yet, so this is a resource refusal.
        if(status==BC_COMPILE_ERROR && prepared.p_1.f_1.f_0.f_0==8){status=BC_RESOURCE_LIMIT;}
    }
    if(status!=BC_OK){HeapFree(GetProcessHeap(),0,instance);}
    leave_preview(&admission);
    return finish_preview(status);
}

uint32_t BC_CALL bc_preview_step(bc_handle instance,uint32_t quantum,bc_preview_event *out){
    if(!out||out->struct_size!=sizeof(*out)||!quantum||quantum>4096){return BC_BAD_ARGUMENT;}
    if(!TryAcquireSRWLockExclusive(&preview_guard)){return BC_BUSY;}
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter_instance(instance,&admission);
    if(status!=BC_OK){return finish_preview(status);}
    preview_child *run=(preview_child *)(uintptr_t)admission.object;
    __typeof__(P4(&run->owner->engine,run->id,quantum)) stepped=P4(&run->owner->engine,run->id,quantum);
    if(stepped.tag!=FY_RESULT_OK){status=stepped.p_1.f_0;}
    else{
        __typeof__(stepped.p_0) event=stepped.p_0;
        bc_preview_event published={.struct_size=sizeof(published),.diagnostic_code=event.f_2.f_0.f_0};
        if(!event.f_4||event.f_3>run->fuel){preview_invariant();}
        published.fuel_used=run->fuel-event.f_3;
        switch(event.f_0){
        case 1: published.kind=BC_PREVIEW_DONE;published.return_i32=(int32_t)event.f_1;break;
        case 2: published.kind=BC_PREVIEW_TRAP;break;
        case 3: published.kind=BC_PREVIEW_CANCELLED;break;
        case 4: published.kind=BC_PREVIEW_YIELD;break;
        default: preview_invariant();
        }
        *out=published;
    }
    leave_preview(&admission);
    return finish_preview(status);
}

uint32_t BC_CALL bc_preview_cancel(bc_handle instance){
    if(!TryAcquireSRWLockExclusive(&preview_guard)){return BC_BUSY;}
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter_instance(instance,&admission);
    if(status!=BC_OK){return finish_preview(status);}
    preview_child *run=(preview_child *)(uintptr_t)admission.object;
    __typeof__(P5(&run->owner->engine,run->id)) cancelled=P5(&run->owner->engine,run->id);
    status=cancelled.tag==FY_RESULT_OK?BC_OK:cancelled.p_1.f_0;
    leave_preview(&admission);
    return finish_preview(status);
}

static uint32_t release_child(bc_handle child,bc_handle engine,uint32_t kind){
    if(!TryAcquireSRWLockExclusive(&preview_guard)){return BC_BUSY;}
    bc_abi_registry_admission admission;
    uint32_t status=kind==INSTANCE_HANDLE?bc_abi_registry_enter_instance(child,&admission):
        bc_abi_registry_enter(child,kind,engine,&admission);
    if(status!=BC_OK){return finish_preview(status);}
    preview_child *object=(preview_child *)(uintptr_t)admission.object;
    preview_engine *owner=object->owner;
    __typeof__(P6(&owner->engine,object->id)) dropped=kind==INSTANCE_HANDLE?
        P6(&owner->engine,object->id):P7(&owner->engine,object->id);
    if(dropped.tag==FY_RESULT_OK){
        remove_preview(&admission);
        --owner->children;
        HeapFree(GetProcessHeap(),0,object);
    }else{status=dropped.p_1.f_0;leave_preview(&admission);}
    return finish_preview(status);
}

uint32_t BC_CALL bc_preview_instance_destroy(bc_handle instance){return release_child(instance,0,INSTANCE_HANDLE);}
uint32_t BC_CALL bc_preview_program_release(bc_handle engine,bc_handle program){return release_child(program,engine,PROGRAM_HANDLE);}

uint32_t BC_CALL bc_preview_engine_destroy(bc_handle engine){
    if(!TryAcquireSRWLockExclusive(&preview_guard)){return BC_BUSY;}
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter(engine,ENGINE_HANDLE,engine,&admission);
    if(status!=BC_OK){return finish_preview(status);}
    preview_engine *owner=(preview_engine *)(uintptr_t)admission.object;
    if(owner->children){leave_preview(&admission);return finish_preview(BC_BUSY);}
    __typeof__(P8(&owner->engine)) dropped=P8(&owner->engine);
    if(dropped.tag==FY_RESULT_OK){remove_preview(&admission);HeapFree(GetProcessHeap(),0,owner);}
    else{status=dropped.p_1.f_0;leave_preview(&admission);}
    return finish_preview(status);
}
