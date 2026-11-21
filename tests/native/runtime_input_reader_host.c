#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../../native/runtime_input_reader.h"
/* Actual OS probe. A queued suffix bounds the test even if this Windows build
   does not turn a zero-byte WriteFile into a successful zero-byte ReadFile. */
typedef struct zero_writer { HANDLE writer;HANDLE reader_thread;size_t prefix; } zero_writer;
static DWORD WINAPI write_zero(void *context){
    const uint8_t data[]={0,255,42};const uint8_t suffix=77;DWORD got;BOOL pending=FALSE;unsigned i;
    zero_writer *p=context;
    if(p->prefix){assert(WriteFile(p->writer,data,(DWORD)p->prefix,&got,NULL)&&got==p->prefix);Sleep(10);}
    for(i=0;i<1000;++i){assert(GetThreadIOPendingFlag(p->reader_thread,&pending));if(pending){break;}Sleep(1);}
    got=99;assert(WriteFile(p->writer,data,0,&got,NULL)&&got==0);
    Sleep(10);assert(WriteFile(p->writer,&suffix,1,&got,NULL)&&got==1);assert(CloseHandle(p->writer));return 0;
}
static unsigned zero_byte_pipe(size_t prefix,size_t cap){
    const uint8_t data[]={0,255,42};HANDLE r,w,thread;zero_writer p;
    DWORD got,e=0,flags,code;uint8_t byte=0;bc_rir_snapshot *s=NULL;bc_rir_status status;unsigned observed=0;
    assert(prefix<=sizeof(data));assert(CreatePipe(&r,&w,NULL,4096));
    assert(DuplicateHandle(GetCurrentProcess(),GetCurrentThread(),GetCurrentProcess(),&p.reader_thread,0,FALSE,DUPLICATE_SAME_ACCESS));
    p.writer=w;p.prefix=prefix;thread=CreateThread(NULL,0,write_zero,&p,0,NULL);assert(thread);
    status=bc_rir_handle(r,cap,&s,&e);
    assert(WaitForSingleObject(thread,10000)==WAIT_OBJECT_0);assert(GetExitCodeThread(thread,&code)&&code==0);
    assert(CloseHandle(thread));assert(CloseHandle(p.reader_thread));assert(GetHandleInformation(r,&flags));
    if(status==BC_RIR_OS&&e==ERROR_NO_DATA){
        assert(s==NULL);assert(ReadFile(r,&byte,1,&got,NULL)&&got==1&&byte==77);observed=1;
    }else if(cap==prefix){
        /* No zero return observed: the real suffix exceeds this exact cap. */
        assert(status==BC_RIR_LIMIT_ERROR&&s==NULL);
    }else{
        assert(status==BC_RIR_OK&&s&&bc_rir_length(s)==prefix+1);
        assert(prefix==0||memcmp(bc_rir_bytes(s),data,prefix)==0);
        assert(bc_rir_bytes(s)[prefix]==77);bc_rir_close(s);
    }
    assert(!ReadFile(r,&byte,1,&got,NULL)&&GetLastError()==ERROR_BROKEN_PIPE);
    assert(CloseHandle(r));return observed;
}
static unsigned zero_byte_pipes(void){
    unsigned n=0;n+=zero_byte_pipe(0,16);n+=zero_byte_pipe(3,16);n+=zero_byte_pipe(0,0);n+=zero_byte_pipe(3,3);return n;
}
#ifdef BC_RIR_ZERO_READ_SEAM
/* Explicit syscall-return injection only. This translation unit uses real
   ReadFile; /FI redirects only the reader object, never this host. */
static long zero_after=-1,read_calls;
BOOL bc_rir_zero_read(HANDLE h,LPVOID out,DWORD n,LPDWORD got,LPOVERLAPPED overlapped){
    ++read_calls;
    if(zero_after==0){zero_after=-1;*got=0;return TRUE;}
    if(zero_after>0){--zero_after;}
    return ReadFile(h,out,n,got,overlapped);
}
static void injected_zero_case(size_t prefix,size_t cap){
    const uint8_t data[]={0,255,42};const uint8_t suffix=77;HANDLE r,w;
    DWORD got,e=0,flags;uint8_t byte=0;bc_rir_snapshot *s=NULL;long before=bc_rir_test_live();
    assert(CreatePipe(&r,&w,NULL,4096));
    if(prefix){assert(WriteFile(w,data,(DWORD)prefix,&got,NULL)&&got==prefix);}
    zero_after=prefix?1:0;read_calls=0;
    assert(bc_rir_handle(r,cap,&s,&e)==BC_RIR_OS&&e==ERROR_NO_DATA&&s==NULL);
    assert(read_calls==(prefix?2:1)&&zero_after==-1&&bc_rir_test_live()==before);
    assert(GetHandleInformation(r,&flags));
    assert(WriteFile(w,&suffix,1,&got,NULL)&&got==1);assert(CloseHandle(w));
    assert(ReadFile(r,&byte,1,&got,NULL)&&got==1&&byte==suffix);
    assert(!ReadFile(r,&byte,1,&got,NULL)&&GetLastError()==ERROR_BROKEN_PIPE);assert(CloseHandle(r));
}
static void injected_zeros(void){injected_zero_case(0,16);injected_zero_case(3,16);injected_zero_case(0,0);injected_zero_case(3,3);}
#endif
#ifdef BC_RIR_TEST
static DWORD baseline;
static const char *group;
static uint8_t *payload;
static const wchar_t *fixture;
static void clean(void){DWORD n;assert(GetProcessHandleCount(GetCurrentProcess(),&n));if(n!=baseline){fprintf(stderr,"group=%s handles=%lu baseline=%lu\n",group,(unsigned long)n,(unsigned long)baseline);}assert(n==baseline);assert(bc_rir_test_live()==0);}
static void written(const wchar_t *path,size_t n){
    DWORD got;HANDLE h=CreateFileW(path,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL);
    assert(h!=INVALID_HANDLE_VALUE);assert(WriteFile(h,payload,(DWORD)n,&got,NULL)&&got==n);assert(CloseHandle(h));
}
static HANDLE disk(DWORD access,DWORD flags){
    HANDLE h=CreateFileW(fixture,access,FILE_SHARE_READ,NULL,OPEN_EXISTING,flags,NULL);assert(h!=INVALID_HANDLE_VALUE);return h;
}
static void exact(const bc_rir_snapshot *s,const uint8_t *data,size_t n){
    assert(s&&bc_rir_length(s)==n);assert(n==0||memcmp(bc_rir_bytes(s),data,n)==0);
}
static void files(void){
    size_t sizes[]={0,1,257,BC_RIR_LIMIT};size_t i;DWORD e=0;bc_rir_snapshot *s=NULL;
    for(i=0;i<sizeof(sizes)/sizeof(sizes[0]);++i){
        written(fixture,sizes[i]);assert(bc_rir_path(fixture,wcslen(fixture),sizes[i],&s,&e)==BC_RIR_OK);
        exact(s,payload,sizes[i]);assert(DeleteFileW(fixture));exact(s,payload,sizes[i]);bc_rir_close(s);s=NULL;clean();
    }
    written(fixture,BC_RIR_LIMIT+1u);i=(size_t)bc_rir_test_attempts();
    assert(bc_rir_path(fixture,wcslen(fixture),BC_RIR_LIMIT,&s,&e)==BC_RIR_LIMIT_ERROR&&s==NULL);
    assert((size_t)bc_rir_test_attempts()==i);clean();
    written(fixture,1);assert(bc_rir_path(fixture,wcslen(fixture),0,&s,&e)==BC_RIR_LIMIT_ERROR&&s==NULL);clean();
    written(fixture,0);assert(bc_rir_path(fixture,wcslen(fixture),0,&s,&e)==BC_RIR_OK);exact(s,payload,0);bc_rir_close(s);clean();
}
static void position_and_errors(void){
    HANDLE h,event;LARGE_INTEGER p,now,z;DWORD e=0;bc_rir_snapshot *s=NULL,*old;long attempts;
    written(fixture,257);h=disk(GENERIC_READ,0);p.QuadPart=13;z.QuadPart=0;
    assert(SetFilePointerEx(h,p,NULL,FILE_BEGIN));assert(bc_rir_handle(h,244,&s,&e)==BC_RIR_OK);exact(s,payload+13,244);
    assert(SetFilePointerEx(h,z,&now,FILE_CURRENT)&&now.QuadPart==257);assert(CloseHandle(h));
    old=s;assert(bc_rir_handle(INVALID_HANDLE_VALUE,1,&s,&e)==BC_RIR_ARGUMENT&&s==old);exact(s,payload+13,244);bc_rir_close(s);s=NULL;clean();
    h=disk(GENERIC_READ,FILE_FLAG_OVERLAPPED);attempts=bc_rir_test_attempts();
    assert(bc_rir_handle(h,257,&s,&e)==BC_RIR_KIND&&s==NULL&&bc_rir_test_attempts()==attempts);assert(CloseHandle(h));clean();
    h=disk(GENERIC_WRITE,0);assert(bc_rir_handle(h,257,&s,&e)!=BC_RIR_OK&&s==NULL);assert(CloseHandle(h));clean();
    event=CreateEventW(NULL,TRUE,FALSE,NULL);assert(event);assert(bc_rir_handle(event,10,&s,&e)==BC_RIR_KIND&&s==NULL);assert(CloseHandle(event));clean();
    assert(bc_rir_handle(NULL,1,&s,&e)==BC_RIR_ARGUMENT&&s==NULL);
    assert(bc_rir_handle(INVALID_HANDLE_VALUE,1,&s,&e)==BC_RIR_ARGUMENT&&s==NULL);
    assert(bc_rir_handle((HANDLE)(uintptr_t)0x1234,1,&s,&e)==BC_RIR_OS&&s==NULL);
    attempts=bc_rir_test_attempts();assert(bc_rir_handle(INVALID_HANDLE_VALUE,BC_RIR_LIMIT+1u,&s,&e)==BC_RIR_LIMIT_ERROR);
    assert(bc_rir_test_attempts()==attempts);assert(bc_rir_path(L"relative",8,1,&s,&e)==BC_RIR_ARGUMENT);
    assert(bc_rir_path(L"C:\\x\0z",6,1,&s,&e)==BC_RIR_ARGUMENT);
    assert(bc_rir_path(NULL,0,1,&s,&e)==BC_RIR_ARGUMENT);
    assert(bc_rir_path(L"C:\\",BC_RIR_PATH_UNITS+1u,1,&s,&e)==BC_RIR_ARGUMENT);
    assert(bc_rir_handle(NULL,0,NULL,&e)==BC_RIR_ARGUMENT);clean();
    assert(DeleteFileW(fixture));assert(bc_rir_path(fixture,wcslen(fixture),1,&s,&e)==BC_RIR_OS&&s==NULL);clean();
}
typedef struct producer { HANDLE writer;size_t length;int fragmented; } producer;
static DWORD WINAPI produce(void *context){
    producer *p=context;size_t offset=0;DWORD got,chunk;
    while(offset<p->length){chunk=(DWORD)(p->length-offset);if(chunk>(p->fragmented?31u:4096u)){chunk=p->fragmented?31u:4096u;}
        assert(WriteFile(p->writer,payload+offset,chunk,&got,NULL)&&got>0&&got<=chunk);offset+=got;
        if(p->fragmented){Sleep(2);}
    }assert(CloseHandle(p->writer));return 0;
}
static void pipe_case(size_t length,size_t cap,int fragmented,bc_rir_status expected){
    HANDLE r,w,thread;producer p;DWORD e=0,code;bc_rir_snapshot *s=NULL;
    assert(CreatePipe(&r,&w,NULL,4096));p.writer=w;p.length=length;p.fragmented=fragmented;
    thread=CreateThread(NULL,0,produce,&p,0,NULL);assert(thread);
    assert(bc_rir_handle(r,cap,&s,&e)==expected);
    if(expected==BC_RIR_OK){exact(s,payload,length);bc_rir_close(s);}else{assert(!s);}
    assert(WaitForSingleObject(thread,10000)==WAIT_OBJECT_0);assert(GetExitCodeThread(thread,&code)&&code==0);
    assert(CloseHandle(thread));assert(CloseHandle(r));clean();
}
static void pipes(void){
    long before=bc_rir_test_partial_reads();
    pipe_case(257,4096,1,BC_RIR_OK);assert(bc_rir_test_partial_reads()>before);
    pipe_case(0,0,0,BC_RIR_OK);pipe_case(1,0,0,BC_RIR_LIMIT_ERROR);
    pipe_case(BC_RIR_LIMIT,BC_RIR_LIMIT,0,BC_RIR_OK);
    pipe_case(BC_RIR_LIMIT+1u,BC_RIR_LIMIT,0,BC_RIR_LIMIT_ERROR);
}
static ULONGLONG cancel_at;
static uint32_t pipe_cancelled(void){return GetTickCount64()>=cancel_at;}
static void timed_pipes(void){
    HANDLE reader,writer;DWORD got,error;bc_rir_snapshot *snapshot=NULL;
    const bc_rir_status expected[]={BC_RIR_DEADLINE,BC_RIR_CANCELLED,BC_RIR_OK};
    for(size_t i=0;i<sizeof(expected)/sizeof(*expected);++i){
        assert(CreatePipe(&reader,&writer,NULL,4096));
        assert(WriteFile(writer,payload,3,&got,NULL)&&got==3);
        if(expected[i]==BC_RIR_OK){assert(CloseHandle(writer));}
        cancel_at=GetTickCount64()+50;
        assert(bc_rir_stdin(reader,3,expected[i]==BC_RIR_DEADLINE?50:2000,
                            expected[i]==BC_RIR_CANCELLED?pipe_cancelled:NULL,&snapshot,&error)==expected[i]);
        if(expected[i]==BC_RIR_OK){exact(snapshot,payload,3);bc_rir_close(snapshot);snapshot=NULL;}
        else {
            assert(!snapshot&&error==(DWORD)(expected[i]==BC_RIR_DEADLINE?ERROR_TIMEOUT:ERROR_OPERATION_ABORTED));
            assert(CloseHandle(writer));
        }
        assert(CloseHandle(reader));clean();
    }
}
static void oom(void){
    HANDLE h,r,w;DWORD e=0,got;long attempts;bc_rir_snapshot *s=NULL;LARGE_INTEGER z,p;
    written(fixture,257);h=disk(GENERIC_READ,0);attempts=bc_rir_test_attempts();bc_rir_test_fail_after(0);
    assert(bc_rir_handle(h,257,&s,&e)==BC_RIR_ALLOCATION&&!s);assert(bc_rir_test_attempts()==attempts+1);
    z.QuadPart=0;assert(SetFilePointerEx(h,z,&p,FILE_CURRENT)&&p.QuadPart==0);assert(CloseHandle(h));clean();
    attempts=bc_rir_test_attempts();assert(bc_rir_path(fixture,wcslen(fixture),257,&s,&e)==BC_RIR_ALLOCATION&&!s);
    assert(bc_rir_test_attempts()==attempts+1);clean();bc_rir_test_fail_after(-1);
    assert(CreatePipe(&r,&w,NULL,4096));assert(WriteFile(w,payload,257,&got,NULL)&&got==257);assert(CloseHandle(w));
    bc_rir_test_fail_after(0);attempts=bc_rir_test_attempts();assert(bc_rir_handle(r,257,&s,&e)==BC_RIR_ALLOCATION&&!s);
    assert(bc_rir_test_attempts()==attempts+1);bc_rir_test_fail_after(-1);
    assert(bc_rir_handle(r,257,&s,&e)==BC_RIR_OK);exact(s,payload,257);bc_rir_close(s);assert(CloseHandle(r));clean();
}
static void repeated_failures(void){
    size_t i;DWORD e=0;bc_rir_snapshot *s=NULL;written(fixture,257);
    for(i=0;i<32;++i){assert(bc_rir_path(fixture,wcslen(fixture),256,&s,&e)==BC_RIR_LIMIT_ERROR&&!s);clean();
        bc_rir_test_fail_after(0);assert(bc_rir_path(fixture,wcslen(fixture),257,&s,&e)==BC_RIR_ALLOCATION&&!s);bc_rir_test_fail_after(-1);clean();}
}
static DWORD WINAPI warm_thread(void *p){(void)p;Sleep(2);return 0;}
int wmain(int argc,wchar_t **argv){
    unsigned zero_observed;size_t i;assert(argc==2);fixture=argv[1];payload=HeapAlloc(GetProcessHeap(),0,BC_RIR_LIMIT+1u);assert(payload);
    for(i=0;i<BC_RIR_LIMIT+1u;++i){payload[i]=(uint8_t)(i%256);}
    /* Initialize Windows pipe/thread/wait internals before a stable handle baseline. */
    {HANDLE warm=CreateThread(NULL,0,warm_thread,NULL,0,NULL);assert(warm);assert(WaitForSingleObject(warm,10000)==WAIT_OBJECT_0);assert(CloseHandle(warm));}
    {HANDLE r,w;assert(CreatePipe(&r,&w,NULL,4096));assert(CloseHandle(w));assert(CloseHandle(r));}
    assert(GetProcessHandleCount(GetCurrentProcess(),&baseline));
    group="files";files();group="position";position_and_errors();group="pipes";pipes();group="timed-pipes";timed_pipes();
    group="zero-byte-pipes";zero_observed=zero_byte_pipes();clean();group="oom";oom();group="repeated";repeated_failures();
#ifdef BC_RIR_ZERO_READ_SEAM
    group="injected-zero-reads";injected_zeros();clean();
#endif
    assert(DeleteFileW(fixture));bc_rir_close(NULL);assert(bc_rir_length(NULL)==0&&bc_rir_bytes(NULL)==NULL);clean();
    assert(HeapFree(GetProcessHeap(),0,payload));
    printf("{\"groups\":7,\"zeroBytePipeOsAttempts\":4,\"zeroBytePipeOsObserved\":%u,\"injectedZeroCases\":%u,\"live\":%ld,\"partialReads\":%ld,\"attempts\":%ld}\n",zero_observed,
#ifdef BC_RIR_ZERO_READ_SEAM
        4u,
#else
        0u,
#endif
        bc_rir_test_live(),bc_rir_test_partial_reads(),bc_rir_test_attempts());return 0;
}

#else
/* Execute the actual hook-free production object as a separate binary. */
int wmain(int argc,wchar_t **argv){
    unsigned zero_observed;const uint8_t data[]={0,255,0,42};HANDLE h,r,w;DWORD got,baseline,now;
    bc_rir_snapshot *s=NULL;assert(argc==2);
    assert(CreatePipe(&r,&w,NULL,4096));assert(CloseHandle(w));assert(CloseHandle(r));
    assert(GetProcessHandleCount(GetCurrentProcess(),&baseline));
    h=CreateFileW(argv[1],GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL);
    assert(h!=INVALID_HANDLE_VALUE&&WriteFile(h,data,sizeof(data),&got,NULL)&&got==sizeof(data));assert(CloseHandle(h));
    assert(bc_rir_path(argv[1],wcslen(argv[1]),sizeof(data),&s,NULL)==BC_RIR_OK);
    assert(DeleteFileW(argv[1]));assert(bc_rir_length(s)==sizeof(data)&&memcmp(bc_rir_bytes(s),data,sizeof(data))==0);
    bc_rir_close(s);s=NULL;assert(bc_rir_path(argv[1],wcslen(argv[1]),4,&s,NULL)==BC_RIR_OS&&!s);
    assert(CreatePipe(&r,&w,NULL,4096));assert(WriteFile(w,data,sizeof(data),&got,NULL)&&got==sizeof(data));assert(CloseHandle(w));
    assert(bc_rir_handle(r,sizeof(data),&s,NULL)==BC_RIR_OK);
    assert(CloseHandle(r));assert(bc_rir_length(s)==sizeof(data)&&memcmp(bc_rir_bytes(s),data,sizeof(data))==0);bc_rir_close(s);
    zero_observed=zero_byte_pipes();
    assert(GetProcessHandleCount(GetCurrentProcess(),&now)&&now==baseline);
    printf("{\"groups\":3,\"zeroBytePipeOsAttempts\":4,\"zeroBytePipeOsObserved\":%u,\"handlesStable\":true}\n",zero_observed);return 0;
}
#endif
