#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0602
#include <windows.h>
#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

enum Fault { no_fault, short_write, failed_write, failed_close };
static enum Fault fault;
static unsigned injected;
static HANDLE writing_handle;
static HANDLE publication_handle;

static BOOL WINAPI record_duplicate(HANDLE source_process, HANDLE source,
                                    HANDLE destination_process, LPHANDLE destination,
                                    DWORD access, BOOL inherited, DWORD options){
    BOOL ok=DuplicateHandle(source_process,source,destination_process,destination,access,inherited,options);
    if(ok && fault!=no_fault){
        assert(source==writing_handle && publication_handle==NULL);
        publication_handle=*destination;
    }
    return ok;
}

static BOOL WINAPI write_with_fault(HANDLE file, LPCVOID buffer, DWORD count,
                                    LPDWORD written, LPOVERLAPPED operation){
    if(fault!=no_fault){writing_handle=file;}
    if(fault!=short_write && fault!=failed_write){
        return WriteFile(file,buffer,count,written,operation);
    }
    assert(count>1 && operation==NULL);
    assert(WriteFile(file,buffer,count-1,written,NULL) && *written==count-1);
    ++injected;
    if(fault==short_write){return TRUE;}
    SetLastError(ERROR_DISK_FULL);
    return FALSE;
}

static BOOL WINAPI close_with_fault(HANDLE file){
    BOOL closed=CloseHandle(file);
    if(fault!=failed_close){return closed;}
    assert(closed);
    ++injected;
    fault=no_fault;
    // The handle is actually closed. Inject the failure status observed by the publisher.
    SetLastError(ERROR_INVALID_HANDLE);
    return FALSE;
}

#define WriteFile write_with_fault
#define CloseHandle close_with_fault
#define DuplicateHandle record_duplicate
#include "native/windows-project-cli.c"
#undef DuplicateHandle
#undef CloseHandle
#undef WriteFile

static const uint8_t target[]="result.bin";
static const uint8_t sealed[]={0x41,0x00,0xff,0x0a};

static void assert_no_sibling(void){
    WIN32_FIND_DATAW found;
    assert(FindFirstFileW(L".browniec-*",&found)==INVALID_HANDLE_VALUE);
    assert(GetLastError()==ERROR_FILE_NOT_FOUND);
}

static void assert_closed(HANDLE file){
    DWORD flags=0;
    assert(file!=NULL && !GetHandleInformation(file,&flags));
    assert(GetLastError()==ERROR_INVALID_HANDLE);
}

static void check_fault(enum Fault next){
    injected=0;
    writing_handle=NULL;
    publication_handle=NULL;
    fault=next;
    assert(bc_cli_write_output(target,sizeof(target)-1,sealed,sizeof(sealed))==0);
    fault=no_fault;
    assert(injected==1);
    assert_closed(writing_handle);
    if(next==failed_close){assert_closed(publication_handle);}
    else{assert(publication_handle==NULL);}
    assert(GetFileAttributesW(L"result.bin")==INVALID_FILE_ATTRIBUTES);
    assert(GetLastError()==ERROR_FILE_NOT_FOUND);
    assert_no_sibling();
}

int main(void){
    check_fault(short_write);
    check_fault(failed_write);
    check_fault(failed_close);
    // A fresh attempt to the same destination must publish the exact original bytes.
    assert(bc_cli_write_output(target,sizeof(target)-1,sealed,sizeof(sealed))==1);
    HANDLE file=CreateFileW(L"result.bin",GENERIC_READ,0,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL);
    assert(file!=INVALID_HANDLE_VALUE);
    uint8_t received[sizeof(sealed)+1];
    DWORD count=0;
    assert(ReadFile(file,received,sizeof(received),&count,NULL) && count==sizeof(sealed));
    assert(memcmp(received,sealed,sizeof(sealed))==0);
    assert(CloseHandle(file) && DeleteFileW(L"result.bin"));
    assert_no_sibling();
    puts("PASS: short write, failed write and close status leave no output, staging file or handle; retry publishes exact bytes");
    return 0;
}
