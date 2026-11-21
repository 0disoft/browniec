/* Included after the isolated Fairy transport and reviewed binding declarations. */
#define BC_BUILD_PREVIEW_DLL
#define BC_ABI_BOOTSTRAP_INTERNAL
#include "brownie_preview.h"
#include "abi_bootstrap_layout.h"
#include "abi_registry.h"
#include <string.h>

#pragma comment(linker, "/EXPORT:bc_engine_create")
#pragma comment(linker, "/EXPORT:bc_engine_destroy")
#pragma comment(linker, "/EXPORT:bc_compile")
#pragma comment(linker, "/EXPORT:bc_program_entry_info")
#pragma comment(linker, "/EXPORT:bc_instance_create")
#pragma comment(linker, "/EXPORT:bc_instance_destroy")
#pragma comment(linker, "/EXPORT:bc_step")
#pragma comment(linker, "/EXPORT:bc_cancel")
#pragma comment(linker, "/EXPORT:bc_program_release")

typedef struct preview_engine {
    bc_engine engine;
    size_t children;
    uint32_t revision;
} preview_engine;

typedef struct preview_child {
    preview_engine *owner;
    uintptr_t id;
    union {
        uint64_t fuel;
        struct {
            uint32_t input_kind;
            uint8_t capabilities_json[2];
        } program;
    };
} preview_child;

typedef struct preview_run {
    preview_child child;
    uint64_t peak;
    uint64_t start;
    bc_event terminal;
} preview_run;

/* The registry owns a busy admission for one Engine while its VM runs.
   The embedding build waits only to acquire the shared metadata guard. */
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

static void leave_preview(const bc_abi_registry_admission *admission){
    if(bc_abi_registry_leave(admission)!=BC_OK){preview_invariant();}
}

static void remove_preview(const bc_abi_registry_admission *admission){
    uint64_t removed=0;
    if(bc_abi_registry_remove(admission,&removed)!=BC_OK || removed!=admission->object){preview_invariant();}
}

static uint32_t create_engine(uint32_t revision,bc_slice policy,bc_handle *out){
    preview_engine *owner=HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,sizeof(*owner));
    if(!owner){return BC_ALLOCATION_ERROR;}
    __typeof__(P1()) created=revision==BC_ABI_REVISION?P9(policy.data,policy.len):P1();
    if(created.tag!=FY_RESULT_OK){
        HeapFree(GetProcessHeap(),0,owner);
        return preview_status(created.p_1.f_0);
    }
    owner->engine=created.p_0;
    owner->revision=revision;
    bc_handle handle=0;
    uint32_t status=bc_abi_registry_create_engine((uintptr_t)owner,&handle);
    if(status!=BC_OK){
        if(P8(&owner->engine).tag!=FY_RESULT_OK){preview_invariant();}
        HeapFree(GetProcessHeap(),0,owner);
    }else{*out=handle;}
    return preview_status(status);
}

uint32_t BC_CALL bc_preview_engine_create(uint32_t revision,bc_handle *out){
    if(revision!=BC_PREVIEW_REVISION){return BC_ABI_MISMATCH;}
    if(!out){return BC_BAD_ARGUMENT;}
    return create_engine(revision,(bc_slice){0},out);
}

uint32_t BC_CALL bc_get_abi_info_v2(uint32_t revision,uint32_t capacity,bc_abi_info *out){
    uint32_t status=P10(revision,capacity,out!=NULL);
    if(status!=BC_OK){return status;}
    *out=(bc_abi_info){sizeof(bc_abi_info),BC_ABI_REVISION,64,sizeof(bc_diagnostic),
                      sizeof(bc_event),sizeof(bc_entry_info),sizeof(bc_source),sizeof(bc_slice)};
    return BC_OK;
}

static bc_diagnostic diagnostic_result(uint32_t status,const char *message){
    bc_diagnostic result={.struct_size=sizeof(result),.code=status,.source_index=UINT32_MAX};
    memcpy(result.message,message,strlen(message)+1);
    return result;
}

static uint32_t engine_diagnostic(bc_diagnostic *out,uint32_t status){
    const char *message="";
    switch(status){
    case BC_OK: break;
    case BC_POLICY_ERROR: message="Invalid Engine policy";break;
    case BC_RESOURCE_LIMIT: message="Engine policy exceeds a resource limit";break;
    case BC_ALLOCATION_ERROR: message="Engine allocation failed";break;
    case BC_BAD_ARGUMENT: message="Invalid Engine creation arguments";break;
    default: message="Engine creation failed";break;
    }
    *out=diagnostic_result(status,message);
    return status;
}

uint32_t BC_CALL bc_engine_create(uint32_t revision,bc_slice policy,bc_handle *out,bc_diagnostic *diagnostic){
    if(out){*out=0;}
    if(revision!=BC_ABI_REVISION){return BC_ABI_MISMATCH;}
    if(!diagnostic||diagnostic->struct_size!=sizeof(*diagnostic)){return BC_BAD_ARGUMENT;}
    if(!out||(!policy.data&&policy.len)){return engine_diagnostic(diagnostic,BC_BAD_ARGUMENT);}
    if(!policy.len){return engine_diagnostic(diagnostic,BC_POLICY_ERROR);}
    if(policy.len>65536){return engine_diagnostic(diagnostic,BC_RESOURCE_LIMIT);}
    return engine_diagnostic(diagnostic,create_engine(revision,policy,out));
}

static uint32_t compile_diagnostic(bc_diagnostic *out,uint32_t status,bc_slice source,
                                   size_t index,size_t start,size_t end){
    if(!out){return status;}
    const char *message;
    switch(status){
    case BC_OK: message="";break;
    case BC_BAD_ARGUMENT: message="Invalid scalar compilation arguments";break;
    case BC_INVALID_HANDLE: message="Invalid Engine handle";break;
    case BC_WRONG_THREAD: message="Engine belongs to another thread";break;
    case BC_BUSY: message="Engine is busy";break;
    case BC_COMPILE_ERROR: message="Source compilation failed";break;
    case BC_POLICY_ERROR: message="Scalar compilation does not accept a host catalog or guest output";break;
    case BC_RESOURCE_LIMIT: message="Compilation exceeds a resource limit";break;
    case BC_ALLOCATION_ERROR: message="Compilation allocation failed";break;
    default: message="Compilation failed";break;
    }
    bc_diagnostic result=diagnostic_result(status,message);
    if(status!=BC_OK && index==0 && start<=end && end<=source.len){
        result.source_index=0;
        result.byte_start=(uint32_t)start;
        result.byte_end=(uint32_t)end;
    }
    *out=result;
    return status;
}

static uint32_t compile_program(bc_handle engine,uint32_t revision,bc_slice source,bc_handle *out,
                                 bc_diagnostic *diagnostic){
    size_t index=SIZE_MAX,start=0,end=0;
    if(!out||!source.data||!source.len){return compile_diagnostic(diagnostic,BC_BAD_ARGUMENT,source,index,0,0);}
    if(source.len>4096){return compile_diagnostic(diagnostic,BC_RESOURCE_LIMIT,source,index,0,0);}
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter(engine,ENGINE_HANDLE,engine,&admission);
    if(status!=BC_OK){return compile_diagnostic(diagnostic,status,source,index,0,0);}
    preview_engine *owner=(preview_engine *)(uintptr_t)admission.object;
    if(owner->revision!=revision){
        leave_preview(&admission);
        return compile_diagnostic(diagnostic,BC_INVALID_HANDLE,source,index,0,0);
    }
    preview_child *program=HeapAlloc(GetProcessHeap(),0,sizeof(*program));
    if(!program){
        leave_preview(&admission);
        return compile_diagnostic(diagnostic,BC_ALLOCATION_ERROR,source,index,0,0);
    }
    __typeof__(P2(&owner->engine,source.data,source.len,0)) compiled=
        P2(&owner->engine,source.data,source.len,revision==BC_ABI_REVISION);
    if(compiled.tag==FY_RESULT_OK){
        *program=(preview_child){.owner=owner,.id=compiled.p_0.f_0,
            .program={.input_kind=compiled.p_0.f_1?BC_INPUT_BYTES:BC_INPUT_NONE,.capabilities_json={'[',']'}}};
        status=bc_abi_registry_insert(&admission,PROGRAM_HANDLE,(uintptr_t)program,out);
        if(status==BC_OK){++owner->children;}
        else if(P7(&owner->engine,program->id).tag!=FY_RESULT_OK){preview_invariant();}
    }else{
        status=compiled.p_1.f_0;
        index=compiled.p_1.f_1.f_1.f_0;
        start=compiled.p_1.f_1.f_1.f_1;
        end=compiled.p_1.f_1.f_1.f_2;
    }
    if(status!=BC_OK){HeapFree(GetProcessHeap(),0,program);}
    leave_preview(&admission);
    return compile_diagnostic(diagnostic,preview_status(status),source,index,start,end);
}

uint32_t BC_CALL bc_preview_compile(bc_handle engine,bc_slice source,bc_handle *out){
    return compile_program(engine,BC_PREVIEW_REVISION,source,out,NULL);
}

static int is_main(bc_slice name){return name.data && name.len==4 && memcmp(name.data,"main",4)==0;}

uint32_t BC_CALL bc_compile(bc_handle engine,const bc_source *sources,uint32_t source_count,
                            bc_slice catalog,bc_handle *out,bc_diagnostic *diagnostic){
    if(out){*out=0;}
    if(!diagnostic||diagnostic->struct_size!=sizeof(*diagnostic)){return BC_BAD_ARGUMENT;}
    if(!out||!sources||source_count!=1||(!catalog.data&&catalog.len)){
        return compile_diagnostic(diagnostic,BC_BAD_ARGUMENT,(bc_slice){0},SIZE_MAX,0,0);
    }
    if(!is_main(sources[0].module)){
        return compile_diagnostic(diagnostic,BC_BAD_ARGUMENT,(bc_slice){0},SIZE_MAX,0,0);
    }
    if(catalog.len){return compile_diagnostic(diagnostic,BC_POLICY_ERROR,(bc_slice){0},SIZE_MAX,0,0);}
    return compile_program(engine,BC_ABI_REVISION,sources[0].source_utf8,out,diagnostic);
}

uint32_t BC_CALL bc_program_entry_info(bc_handle engine,bc_handle program,bc_slice module,bc_slice function,
                                       bc_entry_info *out,bc_diagnostic *diagnostic){
    if(!diagnostic||diagnostic->struct_size!=sizeof(*diagnostic)){return BC_BAD_ARGUMENT;}
    if(!out||out->struct_size!=sizeof(*out)){
        *diagnostic=diagnostic_result(BC_BAD_ARGUMENT,"Invalid entry info output");
        return BC_BAD_ARGUMENT;
    }
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter(program,PROGRAM_HANDLE,engine,&admission);
    if(status!=BC_OK){
        *diagnostic=diagnostic_result(status,"Program entry lookup could not enter the Engine");
        return status;
    }
    const preview_child *code=(const preview_child *)(uintptr_t)admission.object;
    const char *message="";
    if(code->owner->revision!=BC_ABI_REVISION){
        status=BC_INVALID_HANDLE;
        message="Invalid revision-2 Program handle";
    }else if(!is_main(module)||!is_main(function)){
        status=BC_BAD_ARGUMENT;
        message="Scalar Program entry must be main::main";
    }else{
        *out=(bc_entry_info){.struct_size=sizeof(*out),.abi_revision=BC_ABI_REVISION,
            .input_kind=code->program.input_kind,
            .required_capabilities_json={code->program.capabilities_json,sizeof(code->program.capabilities_json)}};
    }
    leave_preview(&admission);
    *diagnostic=diagnostic_result(status,message);
    return status;
}

static uint32_t create_instance(bc_handle engine,bc_handle program,uint32_t revision,uint64_t fuel,
                                bc_slice input,bc_slice config,bc_handle *out){
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter(program,PROGRAM_HANDLE,engine,&admission);
    if(status!=BC_OK){return status;}
    preview_child *code=(preview_child *)(uintptr_t)admission.object;
    preview_engine *owner=code->owner;
    if(owner->revision!=revision){leave_preview(&admission);return BC_INVALID_HANDLE;}
    preview_run *instance=HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,sizeof(*instance));
    if(!instance){leave_preview(&admission);return BC_ALLOCATION_ERROR;}
    uint8_t failure=0;
    if(revision==BC_ABI_REVISION){
        __typeof__(P11(&owner->engine,code->id,input.data,input.len,config.data,config.len)) prepared=
            P11(&owner->engine,code->id,input.data,input.len,config.data,config.len);
        if(prepared.tag==FY_RESULT_OK){
            instance->child=(preview_child){.owner=owner,.id=prepared.p_0.f_0,.fuel=prepared.p_0.f_1};
            instance->peak=prepared.p_0.f_2;
            instance->start=prepared.p_0.f_3;
        }else{status=prepared.p_1.f_0;failure=prepared.p_1.f_1.f_0.f_0;}
    }else{
        __typeof__(P3(&owner->engine,code->id,fuel)) prepared=P3(&owner->engine,code->id,fuel);
        if(prepared.tag==FY_RESULT_OK){instance->child=(preview_child){.owner=owner,.id=prepared.p_0,.fuel=fuel};}
        else{status=prepared.p_1.f_0;failure=prepared.p_1.f_1.f_0.f_0;}
    }
    if(status==BC_OK){
        status=bc_abi_registry_insert(&admission,INSTANCE_HANDLE,(uintptr_t)instance,out);
        if(status==BC_OK){++owner->children;}
        else if(P6(&owner->engine,instance->child.id).tag!=FY_RESULT_OK){preview_invariant();}
    }
    // Setup Fuel exhaustion is a resource refusal before Instance publication.
    if(status==BC_COMPILE_ERROR && failure==8){status=BC_RESOURCE_LIMIT;}
    if(status!=BC_OK){HeapFree(GetProcessHeap(),0,instance);}
    leave_preview(&admission);
    return preview_status(status);
}

uint32_t BC_CALL bc_preview_instance_create(bc_handle engine,bc_handle program,uint64_t fuel,bc_handle *out){
    if(!out){return BC_BAD_ARGUMENT;}
    if(fuel>BC_PREVIEW_MAX_FUEL){return BC_RESOURCE_LIMIT;}
    return create_instance(engine,program,BC_PREVIEW_REVISION,fuel,(bc_slice){0},(bc_slice){0},out);
}

uint32_t BC_CALL bc_instance_create(bc_handle engine,bc_handle program,bc_slice input,bc_slice config,
                                    bc_handle *out,bc_diagnostic *diagnostic){
    if(out){*out=0;}
    if(!diagnostic||diagnostic->struct_size!=sizeof(*diagnostic)){return BC_BAD_ARGUMENT;}
    uint32_t status;
    const char *message;
    if(!out||(!input.data&&input.len)||!config.data||!config.len){
        status=BC_BAD_ARGUMENT;
        message="Invalid input slice or run configuration";
    }else if(config.len>65536){
        status=BC_RESOURCE_LIMIT;
        message="Run configuration exceeds the byte limit";
    }else{
        status=create_instance(engine,program,BC_ABI_REVISION,0,input,config,out);
        message=status==BC_OK?"":"Instance preparation failed";
    }
    *diagnostic=diagnostic_result(status,message);
    return status;
}

uint32_t BC_CALL bc_preview_step(bc_handle instance,uint32_t quantum,bc_preview_event *out){
    if(!out||out->struct_size!=sizeof(*out)||!quantum||quantum>4096){return BC_BAD_ARGUMENT;}
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter_instance(instance,&admission);
    if(status!=BC_OK){return status;}
    preview_child *run=(preview_child *)(uintptr_t)admission.object;
    if(run->owner->revision!=BC_PREVIEW_REVISION){leave_preview(&admission);return BC_INVALID_HANDLE;}
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
    return preview_status(status);
}

typedef __typeof__(P4((bc_engine *)0,0,0).p_0) preview_vm_event;

static bc_event revision_two_event(preview_run *run,preview_vm_event event){
    if(!event.f_4||event.f_3>run->child.fuel){preview_invariant();}
    bc_event result={.struct_size=sizeof(result),.fuel_used=run->child.fuel-event.f_3,
        .peak_accounted_bytes=run->peak,.elapsed_us=(bc_runtime_engine_monotonic_ticks()-run->start)/10};
    uint32_t code=event.f_2.f_0.f_0;
    const char *message="";
    switch(event.f_0){
    case 1: result.kind=BC_DONE;result.return_i32=(int32_t)event.f_1;break;
    case 2:
        switch(code){
        case 15: result.kind=BC_FAILED;message="Execution allocation failed";break;
        case 30: result.kind=BC_FAILED;message="Execution deadline expired";break;
        case 32: result.kind=BC_FAILED;message="Execution memory limit exceeded";break;
        case 36: result.kind=BC_FAILED;message="Engine poisoned";break;
        default: result.kind=BC_TRAP;result.trap_code=code;message="Guest execution trapped";break;
        }
        break;
    case 3: result.kind=BC_FAILED;code=33;message="Execution cancelled";break;
    case 4: result.kind=BC_YIELD;break;
    default: preview_invariant();
    }
    result.diagnostic=diagnostic_result(code,message);
    if(code && event.f_2.f_1.f_0==0){
        result.diagnostic.source_index=0;
        result.diagnostic.byte_start=(uint32_t)event.f_2.f_1.f_1;
        result.diagnostic.byte_end=(uint32_t)event.f_2.f_1.f_2;
    }
    if(result.kind!=BC_YIELD){run->terminal=result;}
    return result;
}

uint32_t BC_CALL bc_step(bc_handle instance,uint32_t quantum,bc_event *out){
    if(!out||out->struct_size!=sizeof(*out)||!quantum||quantum>4096){return BC_BAD_ARGUMENT;}
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter_instance(instance,&admission);
    if(status!=BC_OK){return status;}
    preview_run *run=(preview_run *)(uintptr_t)admission.object;
    if(run->child.owner->revision!=BC_ABI_REVISION){status=BC_INVALID_HANDLE;}
    else if(run->terminal.kind){*out=run->terminal;}
    else{
        __typeof__(P4(&run->child.owner->engine,run->child.id,quantum)) stepped=
            P4(&run->child.owner->engine,run->child.id,quantum);
        if(stepped.tag!=FY_RESULT_OK){status=stepped.p_1.f_0;}
        else{*out=revision_two_event(run,stepped.p_0);}
    }
    leave_preview(&admission);
    return preview_status(status);
}

static uint32_t cancel_instance(bc_handle instance,uint32_t revision){
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter_instance(instance,&admission);
    if(status!=BC_OK){return status;}
    preview_run *instance_state=(preview_run *)(uintptr_t)admission.object;
    preview_child *run=&instance_state->child;
    if(run->owner->revision!=revision){leave_preview(&admission);return BC_INVALID_HANDLE;}
    if(instance_state->terminal.kind){leave_preview(&admission);return BC_OK;}
    __typeof__(P5(&run->owner->engine,run->id)) cancelled=P5(&run->owner->engine,run->id);
    status=cancelled.tag==FY_RESULT_OK?BC_OK:cancelled.p_1.f_0;
    if(status==BC_OK && revision==BC_ABI_REVISION){
        __typeof__(P12(&run->owner->engine,run->id)) observed=P12(&run->owner->engine,run->id);
        if(observed.tag!=FY_RESULT_OK){preview_invariant();}
        if(observed.p_0.f_0!=4){(void)revision_two_event(instance_state,observed.p_0);}
    }
    leave_preview(&admission);
    return preview_status(status);
}

uint32_t BC_CALL bc_preview_cancel(bc_handle instance){return cancel_instance(instance,BC_PREVIEW_REVISION);}
uint32_t BC_CALL bc_cancel(bc_handle instance){return cancel_instance(instance,BC_ABI_REVISION);}

static uint32_t release_child(bc_handle child,bc_handle engine,uint32_t kind,uint32_t revision){
    bc_abi_registry_admission admission;
    uint32_t status=kind==INSTANCE_HANDLE?bc_abi_registry_enter_instance(child,&admission):
        bc_abi_registry_enter(child,kind,engine,&admission);
    if(status!=BC_OK){return status;}
    preview_child *object=(preview_child *)(uintptr_t)admission.object;
    preview_engine *owner=object->owner;
    if(owner->revision!=revision){leave_preview(&admission);return BC_INVALID_HANDLE;}
    __typeof__(P6(&owner->engine,object->id)) dropped=kind==INSTANCE_HANDLE?
        P6(&owner->engine,object->id):P7(&owner->engine,object->id);
    if(dropped.tag==FY_RESULT_OK){
        remove_preview(&admission);
        --owner->children;
        HeapFree(GetProcessHeap(),0,object);
    }else{status=dropped.p_1.f_0;leave_preview(&admission);}
    return preview_status(status);
}

uint32_t BC_CALL bc_preview_instance_destroy(bc_handle instance){return release_child(instance,0,INSTANCE_HANDLE,BC_PREVIEW_REVISION);}
uint32_t BC_CALL bc_instance_destroy(bc_handle instance){return release_child(instance,0,INSTANCE_HANDLE,BC_ABI_REVISION);}
uint32_t BC_CALL bc_preview_program_release(bc_handle engine,bc_handle program){return release_child(program,engine,PROGRAM_HANDLE,BC_PREVIEW_REVISION);}
uint32_t BC_CALL bc_program_release(bc_handle engine,bc_handle program){return release_child(program,engine,PROGRAM_HANDLE,BC_ABI_REVISION);}

static uint32_t destroy_engine(bc_handle engine,uint32_t revision){
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter(engine,ENGINE_HANDLE,engine,&admission);
    if(status!=BC_OK){return status;}
    preview_engine *owner=(preview_engine *)(uintptr_t)admission.object;
    if(owner->revision!=revision){leave_preview(&admission);return BC_INVALID_HANDLE;}
    if(owner->children){leave_preview(&admission);return BC_BUSY;}
    __typeof__(P8(&owner->engine)) dropped=P8(&owner->engine);
    if(dropped.tag==FY_RESULT_OK){remove_preview(&admission);HeapFree(GetProcessHeap(),0,owner);}
    else{status=dropped.p_1.f_0;leave_preview(&admission);}
    return preview_status(status);
}

uint32_t BC_CALL bc_preview_engine_destroy(bc_handle engine){return destroy_engine(engine,BC_PREVIEW_REVISION);}

uint32_t BC_CALL bc_engine_destroy(bc_handle engine){
    return destroy_engine(engine,BC_ABI_REVISION);
}
