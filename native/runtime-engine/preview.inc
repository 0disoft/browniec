/* Included after the isolated Fairy transport and reviewed binding declarations. */
#define BC_BUILD_PREVIEW_DLL
#define BC_ABI_BOOTSTRAP_INTERNAL
#include "brownie_preview.h"
#include "abi_bootstrap_layout.h"
#include "abi_registry.h"
#include <stdbool.h>
#include <string.h>

#pragma comment(linker, "/EXPORT:bc_engine_create")
#pragma comment(linker, "/EXPORT:bc_engine_destroy")
#pragma comment(linker, "/EXPORT:bc_compile")
#pragma comment(linker, "/EXPORT:bc_program_entry_info")
#pragma comment(linker, "/EXPORT:bc_instance_create")
#pragma comment(linker, "/EXPORT:bc_instance_destroy")
#pragma comment(linker, "/EXPORT:bc_step")
#pragma comment(linker, "/EXPORT:bc_host_reply")
#pragma comment(linker, "/EXPORT:bc_cancel")
#pragma comment(linker, "/EXPORT:bc_program_release")

typedef struct preview_engine {
    bc_engine engine;
    size_t children;
    uint32_t revision;
} preview_engine;

static const uint8_t emit_capability[]="brownie.output.emit";
static const uint8_t emit_capabilities[]="[\"brownie.output.emit\"]";
static const uint8_t no_capabilities[]="[]";

typedef struct preview_child {
    preview_engine *owner;
    uintptr_t id;
    union {
        uint64_t fuel;
        struct {
            uint32_t input_kind;
            bool catalog_backed;
            bc_slice capabilities;
        } program;
    };
} preview_child;

typedef struct preview_run {
    preview_child child;
    uint64_t peak;
    uint64_t start;
    bool catalog_backed;
    uint64_t request_id;
    uintptr_t engine_request;
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

static uint32_t compile_diagnostic(bc_diagnostic *out,uint32_t status,const bc_source *sources,size_t count,
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
    case BC_POLICY_ERROR: message="Compilation authority or catalog rejected";break;
    case BC_RESOURCE_LIMIT: message="Compilation exceeds a resource limit";break;
    case BC_ALLOCATION_ERROR: message="Compilation allocation failed";break;
    default: message="Compilation failed";break;
    }
    bc_diagnostic result=diagnostic_result(status,message);
    if(status!=BC_OK && index<count && start<=end && end<=sources[index].source_utf8.len){
        result.source_index=(uint32_t)index;
        result.byte_start=(uint32_t)start;
        result.byte_end=(uint32_t)end;
    }
    *out=result;
    return status;
}

/* Names from the validated catalog use only lower-case letters, digits and
   dots, so recording the required set does not need a JSON escape pass. */
static uint32_t host_capabilities(preview_child *program,uint64_t required,bool emits){
    enum {max_imports=64, max_name=128};
    bc_slice names[max_imports+1];
    size_t count=0,length=2;
    for(unsigned i=0;i<max_imports;++i){
        if(!(required & (UINT64_C(1)<<i))){continue;}
        __typeof__(P16(&program->owner->engine,program->id,i)) name=
            P16(&program->owner->engine,program->id,i);
        if(name.tag!=FY_RESULT_OK || name.p_0.f_1>max_name){return BC_INTERNAL_ERROR;}
        const bc_slice candidate={name.p_0.f_0,name.p_0.f_1};
        size_t j=0;
        while(j<count && (candidate.len!=names[j].len ||
            memcmp(candidate.data,names[j].data,candidate.len)!=0)){++j;}
        if(j==count){names[count++]=candidate;}
    }
    if(emits){
        const bc_slice emit={emit_capability,sizeof(emit_capability)-1};
        size_t j=0;
        while(j<count && (names[j].len!=emit.len || memcmp(names[j].data,emit.data,emit.len)!=0)){++j;}
        if(j==count){names[count++]=emit;}
    }
    for(size_t i=0;i<count;++i){length+=names[i].len+2+(i!=0);}
    uint8_t *json=HeapAlloc(GetProcessHeap(),0,length);
    if(!json){return BC_ALLOCATION_ERROR;}
    size_t at=0;
    json[at++]='[';
    for(size_t i=0;i<count;++i){
        if(i){json[at++]=',';}
        json[at++]='"';
        memcpy(json+at,names[i].data,names[i].len);
        at+=names[i].len;
        json[at++]='"';
    }
    json[at++]=']';
    if(at!=length){preview_invariant();}
    program->program.capabilities=(bc_slice){json,length};
    return BC_OK;
}

static void free_program(preview_child *program){
    if(program->program.catalog_backed && program->program.capabilities.data){
        HeapFree(GetProcessHeap(),0,(void *)program->program.capabilities.data);
    }
    HeapFree(GetProcessHeap(),0,program);
}

const uint8_t *bc_embed_source_data(const void *rows,uintptr_t index,uint32_t module_name){
    const bc_source *source=(const bc_source *)rows+index;
    return module_name?source->module.data:source->source_utf8.data;
}

uintptr_t bc_embed_source_size(const void *rows,uintptr_t index,uint32_t module_name){
    const bc_source *source=(const bc_source *)rows+index;
    return module_name?source->module.len:source->source_utf8.len;
}

static bool is_main(bc_slice name){return name.data && name.len==4 && memcmp(name.data,"main",4)==0;}

static uint32_t validate_compile_sources(const bc_source *sources,size_t count,bc_slice catalog){
    if(!sources||!count||(!catalog.data&&catalog.len)){return BC_BAD_ARGUMENT;}
    if(count>16||catalog.len>16384){return BC_RESOURCE_LIMIT;}
    if(catalog.len && (count!=1||!is_main(sources[0].module))){return BC_BAD_ARGUMENT;}
    size_t bytes=0;
    for(size_t i=0;i<count;++i){
        const bc_source source=sources[i];
        if(!source.module.data||!source.module.len||!source.source_utf8.data||!source.source_utf8.len){
            return BC_BAD_ARGUMENT;
        }
        if(source.module.len>128||source.source_utf8.len>4096-bytes){return BC_RESOURCE_LIMIT;}
        bytes+=source.source_utf8.len;
    }
    return BC_OK;
}

static uint32_t compile_program(bc_handle engine,uint32_t revision,const bc_source *sources,size_t count,
                                 bc_slice catalog,bc_handle *out,bc_diagnostic *diagnostic){
    size_t index=SIZE_MAX,start=0,end=0;
    uint32_t status=out?validate_compile_sources(sources,count,catalog):BC_BAD_ARGUMENT;
    if(status!=BC_OK){return compile_diagnostic(diagnostic,status,NULL,0,index,0,0);}
    bc_abi_registry_admission admission;
    status=bc_abi_registry_enter(engine,ENGINE_HANDLE,engine,&admission);
    if(status!=BC_OK){return compile_diagnostic(diagnostic,status,NULL,0,index,0,0);}
    preview_engine *owner=(preview_engine *)(uintptr_t)admission.object;
    if(owner->revision!=revision){
        leave_preview(&admission);
        return compile_diagnostic(diagnostic,BC_INVALID_HANDLE,NULL,0,index,0,0);
    }
    preview_child *program=HeapAlloc(GetProcessHeap(),0,sizeof(*program));
    if(!program){
        leave_preview(&admission);
        return compile_diagnostic(diagnostic,BC_ALLOCATION_ERROR,NULL,0,index,0,0);
    }
    *program=(preview_child){.owner=owner};
    if(catalog.len){
        const bc_slice source=sources[0].source_utf8;
        __typeof__(P14(&owner->engine,source.data,source.len,catalog.data,catalog.len)) compiled=
            P14(&owner->engine,source.data,source.len,catalog.data,catalog.len);
        if(compiled.tag==FY_RESULT_OK){
            program->id=compiled.p_0;
            program->program.catalog_backed=true;
            __typeof__(P15(&owner->engine,program->id)) profile=P15(&owner->engine,program->id);
            if(profile.tag!=FY_RESULT_OK){preview_invariant();}
            program->program.input_kind=profile.p_0.f_0?BC_INPUT_BYTES:BC_INPUT_NONE;
            status=host_capabilities(program,profile.p_0.f_2,profile.p_0.f_1!=0);
        }else{
            status=compiled.p_1.f_0;
            index=compiled.p_1.f_1.f_1.f_0;
            start=compiled.p_1.f_1.f_1.f_1;
            end=compiled.p_1.f_1.f_1.f_2;
        }
    }else{
        __typeof__(P2(&owner->engine,sources,count,false)) compiled=
            P2(&owner->engine,sources,count,revision==BC_ABI_REVISION);
        if(compiled.tag==FY_RESULT_OK){
            program->id=compiled.p_0.f_0;
            program->program.input_kind=compiled.p_0.f_1?BC_INPUT_BYTES:BC_INPUT_NONE;
            program->program.capabilities=compiled.p_0.f_2?(bc_slice){emit_capabilities,sizeof(emit_capabilities)-1}:
                (bc_slice){no_capabilities,sizeof(no_capabilities)-1};
        }else{
            status=compiled.p_1.f_0;
            index=compiled.p_1.f_1.f_1.f_0;
            start=compiled.p_1.f_1.f_1.f_1;
            end=compiled.p_1.f_1.f_1.f_2;
        }
    }
    if(status==BC_OK){status=bc_abi_registry_insert(&admission,PROGRAM_HANDLE,(uintptr_t)program,out);}
    if(status==BC_OK){++owner->children;}
    else{
        if(program->id && P7(&owner->engine,program->id).tag!=FY_RESULT_OK){preview_invariant();}
        free_program(program);
    }
    leave_preview(&admission);
    return compile_diagnostic(diagnostic,preview_status(status),sources,count,index,start,end);
}

uint32_t BC_CALL bc_preview_compile(bc_handle engine,bc_slice source,bc_handle *out){
    const bc_source row={{(const uint8_t *)"main",4},source};
    return compile_program(engine,BC_PREVIEW_REVISION,&row,1,(bc_slice){0},out,NULL);
}

uint32_t BC_CALL bc_compile(bc_handle engine,const bc_source *sources,uint32_t source_count,
                            bc_slice catalog,bc_handle *out,bc_diagnostic *diagnostic){
    if(out){*out=0;}
    if(!diagnostic||diagnostic->struct_size!=sizeof(*diagnostic)){return BC_BAD_ARGUMENT;}
    return compile_program(engine,BC_ABI_REVISION,sources,source_count,catalog,out,diagnostic);
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
            .required_capabilities_json=code->program.capabilities};
    }
    leave_preview(&admission);
    *diagnostic=diagnostic_result(status,message);
    return status;
}

static uint32_t preparation_status(HANDLE cancel_event){
    if(!cancel_event){return BC_OK;}
    switch(WaitForSingleObject(cancel_event,0)){
    case WAIT_TIMEOUT: return BC_OK;
    case WAIT_OBJECT_0: return BC_RUN_TERMINATED;
    default: return BC_BAD_ARGUMENT;
    }
}

static uint32_t create_instance(bc_handle engine,bc_handle program,uint32_t revision,uint64_t fuel,
                                bc_slice input,bc_slice config,HANDLE cancel_event,bc_handle *out){
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter(program,PROGRAM_HANDLE,engine,&admission);
    if(status!=BC_OK){return status;}
    preview_child *code=(preview_child *)(uintptr_t)admission.object;
    preview_engine *owner=code->owner;
    if(owner->revision!=revision){leave_preview(&admission);return BC_INVALID_HANDLE;}
    status=preparation_status(cancel_event);
    if(status!=BC_OK){leave_preview(&admission);return status;}
    preview_run *instance=HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,sizeof(*instance));
    if(!instance){leave_preview(&admission);return BC_ALLOCATION_ERROR;}
    uint8_t failure=0;
    if(revision==BC_ABI_REVISION){
        __typeof__(P11(&owner->engine,code->id,input.data,input.len,config.data,config.len,false)) prepared=
            P11(&owner->engine,code->id,input.data,input.len,config.data,config.len,code->program.catalog_backed);
        if(prepared.tag==FY_RESULT_OK){
            instance->child=(preview_child){.owner=owner,.id=prepared.p_0.f_0,.fuel=prepared.p_0.f_1};
            instance->catalog_backed=code->program.catalog_backed;
            instance->peak=prepared.p_0.f_2;
            instance->start=prepared.p_0.f_3;
        }else{status=prepared.p_1.f_0;failure=prepared.p_1.f_1.f_0.f_0;}
    }else{
        __typeof__(P3(&owner->engine,code->id,fuel)) prepared=P3(&owner->engine,code->id,fuel);
        if(prepared.tag==FY_RESULT_OK){instance->child=(preview_child){.owner=owner,.id=prepared.p_0,.fuel=fuel};}
        else{status=prepared.p_1.f_0;failure=prepared.p_1.f_1.f_0.f_0;}
    }
    if(status==BC_OK){
        status=preparation_status(cancel_event);
        if(status==BC_OK){
            status=bc_abi_registry_insert(&admission,INSTANCE_HANDLE,(uintptr_t)instance,out);
        }
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
    return create_instance(engine,program,BC_PREVIEW_REVISION,fuel,(bc_slice){0},(bc_slice){0},NULL,out);
}

uint32_t BC_CALL bc_preview_instance_create_cancellable(bc_handle engine,bc_handle program,
    bc_slice input,bc_slice config,void *cancel_event,bc_handle *out,bc_diagnostic *diagnostic){
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
        status=create_instance(engine,program,BC_ABI_REVISION,0,input,config,cancel_event,out);
        message=status==BC_OK?"":status==BC_RUN_TERMINATED?
            "Instance preparation cancelled":"Instance preparation failed";
    }
    *diagnostic=diagnostic_result(status,message);
    return status;
}

uint32_t BC_CALL bc_instance_create(bc_handle engine,bc_handle program,bc_slice input,bc_slice config,
                                    bc_handle *out,bc_diagnostic *diagnostic){
    return bc_preview_instance_create_cancellable(engine,program,input,config,NULL,out,diagnostic);
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

/* External tokens distinguish requests even when two Instances both await
   their internal request number 1. Never recycle a token during DLL life. */
static volatile LONG64 last_request_id;
static uint64_t next_request_id(void){
    LONG64 previous=InterlockedCompareExchange64(&last_request_id,0,0);
    while(previous<INT64_MAX){
        LONG64 found=InterlockedCompareExchange64(&last_request_id,previous+1,previous);
        if(found==previous){return (uint64_t)(previous+1);}
        previous=found;
    }
    preview_invariant();
}

static void publish_host_request(preview_run *run,bc_event *event){
    if(run->request_id){
        event->kind=BC_WAIT;
        event->request_id=run->request_id;
        return;
    }
    __typeof__(P17(&run->child.owner->engine,run->child.id)) request=
        P17(&run->child.owner->engine,run->child.id);
    if(request.tag!=FY_RESULT_OK || !request.p_0.f_0){preview_invariant();}
    run->engine_request=request.p_0.f_0;
    run->request_id=next_request_id();
    event->kind=BC_HOST_REQUEST;
    event->request_id=run->request_id;
    event->import_id=(uint32_t)request.p_0.f_1;
    event->payload=(bc_slice){request.p_0.f_2,request.p_0.f_3};
}

static bc_event revision_two_event(preview_run *run,preview_vm_event event){
    if(!event.f_4||event.f_3>run->child.fuel){preview_invariant();}
    bc_event result={.struct_size=sizeof(result),.fuel_used=run->child.fuel-event.f_3,
        .peak_accounted_bytes=run->peak,.elapsed_us=(bc_runtime_engine_monotonic_ticks()-run->start)/10};
    uint32_t code=event.f_2.f_0.f_0;
    const char *message="";
    switch(event.f_0){
    case 1: {
        __typeof__(P13(&run->child.owner->engine,run->child.id)) output=
            P13(&run->child.owner->engine,run->child.id);
        if(output.tag!=FY_RESULT_OK){preview_invariant();}
        result.kind=BC_DONE;
        result.return_i32=(int32_t)event.f_1;
        result.payload=(bc_slice){output.p_0.f_0,output.p_0.f_1};
        break;
    }
    case 2:
        switch(code){
        case 15: result.kind=BC_FAILED;message="Execution allocation failed";break;
        case 20: result.kind=BC_FAILED;message="Host exchange failed";break;
        case 30: result.kind=BC_FAILED;message="Execution deadline expired";break;
        case 32: result.kind=BC_FAILED;message="Execution memory limit exceeded";break;
        case 36: result.kind=BC_FAILED;message="Engine poisoned";break;
        default: result.kind=BC_TRAP;result.trap_code=code;message="Guest execution trapped";break;
        }
        break;
    case 3: result.kind=BC_FAILED;code=33;message="Execution cancelled";break;
    case 0: result.kind=BC_YIELD;break;
    case 4:
        if(run->catalog_backed){publish_host_request(run,&result);}
        else{result.kind=BC_YIELD;}
        break;
    default: preview_invariant();
    }
    result.diagnostic=diagnostic_result(code,message);
    if(code && event.f_2.f_1.f_0==0){
        result.diagnostic.source_index=0;
        result.diagnostic.byte_start=(uint32_t)event.f_2.f_1.f_1;
        result.diagnostic.byte_end=(uint32_t)event.f_2.f_1.f_2;
    }
    if(result.kind==BC_DONE || result.kind==BC_TRAP || result.kind==BC_FAILED){
        run->terminal=result;
        run->request_id=0;
    }
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

uint32_t BC_CALL bc_preview_copy_output(bc_handle instance,uint8_t *destination,
                                        size_t capacity,size_t *out_size){
    if(!out_size||(!destination&&capacity)){return BC_BAD_ARGUMENT;}
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter_instance(instance,&admission);
    if(status!=BC_OK){return status;}
    const preview_run *run=(const preview_run *)(uintptr_t)admission.object;
    if(run->child.owner->revision!=BC_ABI_REVISION){status=BC_INVALID_HANDLE;}
    else if(!run->terminal.kind){status=BC_BUSY;}
    else if(run->terminal.kind!=BC_DONE){status=BC_RUN_TERMINATED;}
    else{
        const bc_slice output=run->terminal.payload;
        *out_size=output.len;
        if(destination){
            if(capacity<output.len){status=BC_RESOURCE_LIMIT;}
            else if(output.len){memcpy(destination,output.data,output.len);}
        }
    }
    leave_preview(&admission);
    return status;
}

static uint32_t receive_host_reply(preview_run *run,uint64_t request_id,uint32_t kind,bc_slice payload){
    if(run->terminal.kind){return BC_RUN_TERMINATED;}
    if(!run->catalog_backed){return BC_BAD_ARGUMENT;}
    const bool valid=run->request_id && request_id==run->request_id &&
        kind<=BC_REPLY_FATAL && (payload.data || !payload.len);
    /* An invalid reply still runs the Engine's deadline checkpoint. Zero
       cannot match an internal request number. */
    const uintptr_t request=valid?run->engine_request:0;
    if(!valid){payload=(bc_slice){0};kind=BC_REPLY_FATAL;}
    bc_engine *owner=&run->child.owner->engine;
    size_t offset=0;
    do{
        const size_t remaining=payload.len-offset;
        const size_t count=remaining>4096?4096:remaining;
        const uint8_t *data=count?payload.data+offset:NULL;
        __typeof__(P18(owner,run->child.id,request,(uint8_t)kind,data,count,payload.len,offset)) reply=
            P18(owner,run->child.id,request,(uint8_t)kind,data,count,payload.len,offset);
        if(reply.tag!=FY_RESULT_OK){return preview_status(reply.p_1.f_0);}
        if(reply.p_0.f_0==2 || reply.p_0.f_0==3){
            const bc_event terminal=revision_two_event(run,reply.p_0);
            if(valid && kind==BC_REPLY_FATAL && terminal.diagnostic.code==20){return BC_OK;}
            return BC_RUN_TERMINATED;
        }
        offset+=count;
    }while(offset<payload.len);
    run->request_id=0;
    return BC_OK;
}

uint32_t BC_CALL bc_host_reply(bc_handle instance,uint64_t request_id,uint32_t kind,
                               bc_slice payload,bc_diagnostic *diagnostic){
    if(!diagnostic || diagnostic->struct_size!=sizeof(*diagnostic)){return BC_BAD_ARGUMENT;}
    bc_abi_registry_admission admission;
    uint32_t status=bc_abi_registry_enter_instance(instance,&admission);
    if(status==BC_OK){
        preview_run *run=(preview_run *)(uintptr_t)admission.object;
        status=run->child.owner->revision==BC_ABI_REVISION?
            receive_host_reply(run,request_id,kind,payload):BC_INVALID_HANDLE;
        leave_preview(&admission);
    }
    *diagnostic=diagnostic_result(status,status==BC_OK?"":"Host reply rejected");
    return status;
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
        if(kind==PROGRAM_HANDLE){free_program(object);}
        else{HeapFree(GetProcessHeap(),0,object);}
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
