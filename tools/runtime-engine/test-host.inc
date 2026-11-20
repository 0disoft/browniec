#include <windows.h>
#include <assert.h>
#include <stdio.h>
extern size_t probe_live(void);

uintptr_t bc_runtime_engine_test_project_path(uint8_t *out,uintptr_t capacity){
 wchar_t root[1025];
 DWORD n=GetFullPathNameW(L"project-fixture",1025,root,NULL);
 assert(n&&n<1025&&capacity<=3072);
 int length=WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,root,(int)n,(char *)out,(int)capacity,NULL,NULL);
 assert(length>0);return (uintptr_t)length;
}
void bc_runtime_engine_test_rewrite_project(void){
 FILE *file=NULL;
 assert(_wfopen_s(&file,L"project-fixture\\helper.brc",L"wb")==0&&file);
 assert(fputs("module helper; pub fn i32 answer(){return 7;}",file)!=EOF);
 assert(fclose(file)==0);
}

static int host_clock_fixed;
static ULONGLONG host_clock_ticks;
static void bc_test_interrupt_time(PULONGLONG now){
 if(host_clock_fixed){*now=host_clock_ticks;return;}
 QueryInterruptTimePrecise(now);
}
void bc_runtime_engine_test_set_clock(uintptr_t ticks){
 assert(!host_clock_fixed||ticks>=host_clock_ticks);
 host_clock_ticks=ticks;host_clock_fixed=1;
}
void bc_runtime_engine_test_use_os_clock(void){host_clock_fixed=0;}
void bc_runtime_engine_test_wait_for_clock(uintptr_t start,uintptr_t elapsed){
 assert(!host_clock_fixed);
 ULONGLONG wait_start=GetTickCount64();
 while(bc_runtime_engine_monotonic_ticks()-start<elapsed){
  assert(GetTickCount64()-wait_start<5000);Sleep(1);
 }
}
void bc_runtime_engine_binding(uint32_t number){(void)number;}
static uintptr_t call_recipe_visits=0;
void bc_runtime_engine_test_recipe_visit(void){++call_recipe_visits;}
void bc_runtime_engine_test_recipe_begin(void){call_recipe_visits=0;}
uintptr_t bc_runtime_engine_test_recipe_count(void){return call_recipe_visits;}
void bc_runtime_engine_test_call_error(uint32_t status,uint8_t kind,uintptr_t offset){fprintf(stderr,"CALL fixture error: status=%u kind=%u offset=%zu\n",status,kind,(size_t)offset);}
typedef struct held_guard {HANDLE ready;HANDLE release;} held_guard;
static DWORD WINAPI holding_thread(void *raw){
 held_guard *events=raw;bc_abi_thread_identity id;assert(bc_abi_guard_enter(&id)==0);
 assert(SetEvent(events->ready));assert(WaitForSingleObject(events->release,10000)==WAIT_OBJECT_0);
 assert(bc_abi_guard_leave(id)==0);return 0;
}
static void completion_contention(bc_engine *e){
 bc_engine_ticket ticket;assert(admission(e,&ticket)==0);
 assert(B5(&e->f_0,&e->f_1,&e->f_2,&e->f_3,&e->f_4,&e->f_5,&e->f_6,&e->f_7,8,0,0)==0);
 held_guard events={CreateEventW(NULL,TRUE,FALSE,NULL),CreateEventW(NULL,TRUE,FALSE,NULL)};
 assert(events.ready&&events.release);HANDLE worker=CreateThread(NULL,0,holding_thread,&events,0,NULL);assert(worker);
 assert(WaitForSingleObject(events.ready,10000)==WAIT_OBJECT_0);
 assert(finish(e,ticket,0)==0&&e->f_0.f_3==0);
 assert(bc_runtime_engine_call(e,8,0,0)==3);
 assert(SetEvent(events.release));assert(WaitForSingleObject(worker,10000)==WAIT_OBJECT_0);
 DWORD code=99;assert(GetExitCodeThread(worker,&code)&&code==0);
 assert(CloseHandle(worker)&&CloseHandle(events.ready)&&CloseHandle(events.release));
 assert(bc_runtime_engine_call(e,8,0,0)==0);
}
static DWORD WINAPI wrong_thread(void *raw){
 assert(bc_runtime_engine_control_access(raw)==10);
 assert(bc_runtime_engine_compile_preflight(raw,0,(const void *)(uintptr_t)1)==10);
 assert(bc_runtime_engine_input_preflight(raw,0,0,(const void *)(uintptr_t)1,0,0,0)==10);
 assert(bc_runtime_engine_output_preflight(raw,0)==10);
 assert(bc_runtime_engine_call(raw,8,0,0)==10);
 assert(bc_runtime_engine_call(raw,9,0,0)==10);
 assert(bc_runtime_engine_call(raw,10,0,1)==10);
 assert(bc_runtime_engine_compile(raw,(void *)(uintptr_t)1,0)==10);
 assert(bc_runtime_engine_compile_input(raw,(void *)(uintptr_t)1,0)==10);
 assert(bc_runtime_engine_instance_input(raw,0,(void *)(uintptr_t)1,0)==10);
 assert(bc_runtime_engine_compile_output(raw,(void *)(uintptr_t)1,0,0)==10);
 assert(bc_runtime_engine_instance_output(raw,0,(void *)(uintptr_t)1,0,0,0)==10);
 assert(bc_runtime_engine_take_output(raw,0,(void *)(uintptr_t)1)==10);
 assert(bc_runtime_engine_execute_input(raw,0,(const void *)(uintptr_t)1)==10);return 0;
}
void bc_runtime_engine_test_guards(void *raw){
 bc_engine *e=raw;HANDLE worker=CreateThread(NULL,0,wrong_thread,raw,0,NULL);assert(worker);
 assert(WaitForSingleObject(worker,10000)==WAIT_OBJECT_0);DWORD code=99;assert(GetExitCodeThread(worker,&code)&&code==0);assert(CloseHandle(worker));
 bc_engine_ticket ticket;assert(admission(e,&ticket)==0&&ticket.epoch!=0);
 assert(bc_runtime_engine_control_access(raw)==3);
 assert(bc_runtime_engine_compile_preflight(raw,0,(const void *)(uintptr_t)1)==3);
 assert(bc_runtime_engine_input_preflight(raw,0,0,(const void *)(uintptr_t)1,0,0,0)==3);
 assert(bc_runtime_engine_output_preflight(raw,0)==3);
 assert(bc_runtime_engine_call(raw,8,0,0)==3);
 assert(bc_runtime_engine_call(raw,9,0,0)==3);
 assert(bc_runtime_engine_call(raw,10,0,1)==3);
 assert(bc_runtime_engine_compile(raw,(void *)(uintptr_t)1,0)==3);
 assert(bc_runtime_engine_compile_input(raw,(void *)(uintptr_t)1,0)==3);
 assert(bc_runtime_engine_instance_input(raw,0,(void *)(uintptr_t)1,0)==3);
 assert(bc_runtime_engine_compile_output(raw,(void *)(uintptr_t)1,0,0)==3);
 assert(bc_runtime_engine_instance_output(raw,0,(void *)(uintptr_t)1,0,0,0)==3);
 assert(bc_runtime_engine_take_output(raw,0,(void *)(uintptr_t)1)==3);
 assert(bc_runtime_engine_execute_input(raw,0,(const void *)(uintptr_t)1)==3);
 bc_engine_ticket stale=ticket;stale.epoch+=1;assert(finish(e,stale,0)==7);
 assert(e->f_0.f_3==ticket.epoch);assert(finish(e,ticket,0)==0);completion_contention(e);
}
void bc_runtime_engine_test_seed(void *raw,uint32_t kind){
 bc_engine *e=raw;bc_abi_thread_identity id;assert(bc_abi_guard_enter(&id)==0);
 assert(e->f_0.f_1==id.thread&&e->f_0.f_2==id.lifetime&&e->f_0.f_3==0);
 if(kind==1)e->f_0.f_5=UINT64_MAX;else{assert(kind==2);e->f_0.f_4=UINT64_MAX;}
 assert(bc_abi_guard_leave(id)==0);
}
void bc_runtime_engine_test_closed_allocations(void){assert(probe_live()==0);}
static HANDLE input_original=NULL,input_writer=NULL,input_thread=NULL;
static uintptr_t input_length=0;static DWORD input_handle_baseline=0;
static uint32_t input_kind=0;
static int input_handles_measured=0;
static unsigned char input_chunk[8192];
static DWORD WINAPI input_producer(void *unused){
 uintptr_t at=0;(void)unused;
 while(at<input_length){DWORD n=(DWORD)(input_length-at),got=0;if(n>sizeof(input_chunk))n=sizeof(input_chunk);
  assert(WriteFile(input_writer,input_chunk,n,&got,NULL)&&got==n);at+=got;}
 assert(CloseHandle(input_writer));return 0;
}
uintptr_t bc_runtime_engine_test_input_open(uint32_t kind,uintptr_t length){
 assert(!input_original&&!input_thread&&length<=1048576);
 assert(GetProcessHandleCount(GetCurrentProcess(),&input_handle_baseline));input_length=length;input_kind=kind;
 for(size_t i=0;i<sizeof(input_chunk);++i)input_chunk[i]=(unsigned char)(i%256);
 if(kind==0){
  wchar_t temp[MAX_PATH],path[MAX_PATH];assert(GetTempPathW(MAX_PATH,temp));assert(GetTempFileNameW(temp,L"bci",0,path));
  input_original=CreateFileW(path,GENERIC_READ|GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_DELETE,NULL,TRUNCATE_EXISTING,FILE_FLAG_DELETE_ON_CLOSE,NULL);
  assert(input_original!=INVALID_HANDLE_VALUE);uintptr_t at=0;
  while(at<length){DWORD n=(DWORD)(length-at),got=0;if(n>sizeof(input_chunk))n=sizeof(input_chunk);
   assert(WriteFile(input_original,input_chunk,n,&got,NULL)&&got==n);at+=got;}
  LARGE_INTEGER zero;zero.QuadPart=0;assert(SetFilePointerEx(input_original,zero,NULL,FILE_BEGIN));
 }else{
  assert(kind==1&&CreatePipe(&input_original,&input_writer,NULL,0));input_thread=CreateThread(NULL,0,input_producer,NULL,0,NULL);assert(input_thread);
 }
 return (uintptr_t)input_original;
}
void bc_runtime_engine_test_input_close(void){
 DWORD flags,count;assert(input_original&&GetHandleInformation(input_original,&flags));
 assert(CloseHandle(input_original));input_original=NULL;
 if(input_thread){assert(WaitForSingleObject(input_thread,10000)==WAIT_OBJECT_0);assert(CloseHandle(input_thread));input_thread=NULL;input_writer=NULL;}
 assert(GetProcessHandleCount(GetCurrentProcess(),&count));
 if(input_handles_measured){
  if(count!=input_handle_baseline)fprintf(stderr,"input fixture kind=%u length=%llu handles=%lu -> %lu\n",input_kind,(unsigned long long)input_length,input_handle_baseline,count);
  assert(count==input_handle_baseline);
 }
}
void bc_runtime_engine_test_input_measure(void){input_handles_measured=1;}
int main(void){
 int code=generated_main();if(code!=0||probe_live()!=0)return 99;
 FILE *metrics=fopen("preparation-metrics.json","wb");assert(metrics);
 assert(fprintf(metrics,"{\"cacheBytes\":%zu,\"storedBytes\":%zu,\"previousStoredBytes\":%zu,\"retainedVecExtraBytes\":%zu,\"capturePlanBytes\":%zu,\"previousCacheBytes\":%zu,\"capturePlanVecExtraBytes\":%zu}\n",
  sizeof(bc_output_preparation),sizeof(bc_output_stored),offsetof(bc_output_stored,f_4),8*sizeof(bc_output_preparation),
  sizeof(bc_call_capture_plan),offsetof(bc_output_preparation,f_8),8*(sizeof(bc_output_preparation)-offsetof(bc_output_preparation,f_8)))>0);
 assert(fclose(metrics)==0);
 FILE *fills=fopen("array-fill-metrics.json","wb");assert(fills);
 assert(fprintf(fills,"{\"arrayWorkBytes\":%zu,\"cursorBytes\":%zu,\"machineBytes\":%zu,\"coreBytes\":%zu,\"pendingVecExtraBytes\":%zu,\"callWorkBytes\":%zu,\"callPendingVecExtraBytes\":%zu,\"returnWorkBytes\":%zu,\"returnPendingVecExtraBytes\":%zu,\"combinedPendingVecExtraBytes\":%zu}\n",
  sizeof(bc_array_fill_work),sizeof(bc_dispatch_cursor),sizeof(bc_pending_machine),sizeof(bc_pending_core),8*sizeof(bc_array_fill_work),
  sizeof(bc_call_copy_work),8*sizeof(bc_call_copy_work),sizeof(bc_return_work),8*sizeof(bc_return_work),
  8*(sizeof(bc_array_fill_work)+sizeof(bc_call_copy_work)+sizeof(bc_return_work)))>0);
 assert(fclose(fills)==0);return 0;
}

extern size_t probe_live_bytes(void),probe_peak_bytes(void),probe_attempts(void);
extern void probe_measure_begin(void);
static uintptr_t small_heap_bytes=0,maximum_heap_bytes=0,owner_bytes=0;static unsigned control_cases=0;
void bc_runtime_engine_test_control_begin(void){probe_measure_begin();}
void bc_runtime_engine_test_control_no_allocations(void){assert(probe_attempts()==0&&probe_live_bytes()==0);}
void bc_runtime_engine_test_control_storage(const void *raw,uintptr_t expected,uint32_t kind){
 const bc_engine *e=raw;size_t sizes=e->f_1.f_1+e->f_2.f_1+e->f_3.f_1+e->f_4.f_1+e->f_5.f_1+e->f_6.f_1+e->f_7.f_1;
 assert(expected==sizeof(*e)+sizes&&probe_live()==7&&probe_live_bytes()==sizes&&probe_peak_bytes()==sizes&&probe_attempts()==7);
 assert(e->f_1.f_4==sizeof(bc_engine_program)&&e->f_3.f_4==sizeof(bc_engine_instance));
 assert(e->f_4.f_4==sizeof(bc_engine_bound_input)&&e->f_6.f_4==sizeof(bc_engine_output));
 if(kind==1){small_heap_bytes=sizes;owner_bytes=sizeof(*e);}if(kind==2)assert(sizes==small_heap_bytes);
 if(kind==4)maximum_heap_bytes=sizes;control_cases++;
}
void bc_runtime_engine_test_control_report(void){
 assert(control_cases==6&&small_heap_bytes*8==maximum_heap_bytes&&probe_live()==0&&probe_live_bytes()==0);
 FILE *f=fopen("control-metrics.json","wb");assert(f);
 assert(fprintf(f,"{\"cases\":6,\"smallHeapBytes\":%llu,\"maximumHeapBytes\":%llu,\"ownerBytes\":%llu}\n",(unsigned long long)small_heap_bytes,(unsigned long long)maximum_heap_bytes,(unsigned long long)owner_bytes)>0);
 assert(fclose(f)==0);
}

extern void probe_rebase(void);
extern void probe_retention_begin(void);
extern int probe_no_retention_allocations(void);
void bc_runtime_engine_test_program_probe(void){probe_rebase();probe_retention_begin();}
void bc_runtime_engine_test_program_no_retention_allocations(void){assert(probe_no_retention_allocations());}
void bc_runtime_engine_test_program_storage(const void *raw,uintptr_t bytes){
 const bc_engine *e=raw;size_t control=e->f_1.f_1+e->f_2.f_1+e->f_3.f_1+e->f_4.f_1+e->f_5.f_1+e->f_6.f_1+e->f_7.f_1;
 assert(bytes<=SIZE_MAX-control&&probe_live_bytes()==control+bytes);
}
static uintptr_t output_proof_visits=0;
void bc_runtime_engine_test_proof_visit(void){assert(output_proof_visits<UINTPTR_MAX);output_proof_visits+=1;}
void bc_runtime_engine_test_proof_begin(void){output_proof_visits=0;}
uintptr_t bc_runtime_engine_test_proof_count(void){return output_proof_visits;}
