#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0602
#include <windows.h>
#include <winternl.h>
#include <string.h>
#include "anchored_sources.h"

/* NtCreateFile's documented numeric CreateOptions, not undocumented attributes. */
#ifndef FILE_OPEN_REPARSE_POINT
#define FILE_OPEN_REPARSE_POINT 0x00200000
#endif
#ifndef FILE_SYNCHRONOUS_IO_NONALERT
#define FILE_SYNCHRONOUS_IO_NONALERT 0x00000020
#endif
#ifndef FILE_OPEN
#define FILE_OPEN 1
#endif
#define BC_AS_HANDLES (BC_AS_FILES * (BC_AS_PATH/2u+1u))
struct bc_as_root { HANDLE handles[BC_AS_ROOT_COMPONENTS+1u]; size_t count; bc_as_identity identity; };
typedef struct bc_as_row { size_t start,length,name_length; uint8_t name[BC_AS_PATH]; bc_as_identity identity; } bc_as_row;
struct bc_as_snapshot { size_t count,used; bc_as_row rows[BC_AS_FILES]; uint8_t bytes[BC_AS_BYTES]; };
typedef struct bc_as_info { FILE_ATTRIBUTE_TAG_INFO tag; FILE_ID_INFO id; FILE_STANDARD_INFO standard; FILE_BASIC_INFO basic; } bc_as_info;
#ifdef BC_ANCHORED_SOURCES_TEST
static long allocations,fail_after=-1;
void bc_as_test_fail_alloc_after(long count){fail_after=count;}
long bc_as_test_live_allocations(void){return allocations;}
#define CHECKPOINT(s,h) bc_as_test_checkpoint(s,h)
#else
#define CHECKPOINT(s,h) ((void)0)
#endif
static void *allocate(size_t size){
    void *p;
#ifdef BC_ANCHORED_SOURCES_TEST
    if(fail_after==0){return NULL;}if(fail_after>0){--fail_after;}
#endif
    p=HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,size);
#ifdef BC_ANCHORED_SOURCES_TEST
    if(p){++allocations;}
#endif
    return p;
}
static void release(void *p){if(p){
#ifdef BC_ANCHORED_SOURCES_TEST
    --allocations;
#endif
    HeapFree(GetProcessHeap(),0,p);
}}
static bc_as_status fail(bc_as_error *e,bc_as_status s,DWORD os,NTSTATUS nt,size_t index){
    if(e){e->win32=os;e->ntstatus=(int32_t)nt;e->index=index;}return s;
}
static unsigned folded(unsigned c){return c>=65 && c<=90?c+32:c;}
static int device(const wchar_t *p,size_t n){
    unsigned a,b,c,d;
    if(n!=3 && n!=4){return 0;}a=folded(p[0]);b=folded(p[1]);c=folded(p[2]);
    if(n==3){return (a=='c'&&b=='o'&&c=='n')||(a=='p'&&b=='r'&&c=='n')||
        (a=='a'&&b=='u'&&c=='x')||(a=='n'&&b=='u'&&c=='l');}
    d=p[3];return ((a=='c'&&b=='o'&&c=='m')||(a=='l'&&b=='p'&&c=='t'))&&d>='1'&&d<='9';
}
static int component(const wchar_t *p,size_t n){
    size_t i,stem=0;if(n==0||p[n-1]=='.'||p[n-1]==' '){return 0;}
    if((n==1&&p[0]=='.')||(n==2&&p[0]=='.'&&p[1]=='.')){return 0;}
    while(stem<n&&p[stem]!='.'){++stem;}if(device(p,stem)){return 0;}
    for(i=0;i<n;++i){unsigned c=p[i];if(c<32||c==127||c=='/'||c=='\\'||c==':'||c=='*'||c=='?'||c=='"'||c=='<'||c=='>'||c=='|'){return 0;}}
    return 1;
}
int bc_as_member_path(const uint8_t *p,size_t n){
    wchar_t name[BC_AS_PATH];size_t i,start=0;
    if(!p||n==0||n>BC_AS_PATH){return 0;}
    if(!((n>=4&&memcmp(p+n-4,".brc",4)==0)||(n>=3&&memcmp(p+n-3,".fy",3)==0))){return 0;}
    for(i=0;i<n;++i){unsigned c=p[i];name[i]=(wchar_t)c;
        if(c=='/'){if(!component(name+start,i-start)){return 0;}start=i+1;}
        else if(!((c>='A'&&c<='Z')||(c>='a'&&c<='z')||(c>='0'&&c<='9')||c=='_'||c=='.'||c=='-')){return 0;}
    }return component(name+start,n-start);
}
static int same_name(const bc_as_path *a,const bc_as_path *b){
    size_t i;if(a->length!=b->length){return 0;}for(i=0;i<a->length;++i){if(folded(a->data[i])!=folded(b->data[i])){return 0;}}return 1;
}
static bc_as_identity identity(FILE_ID_INFO i){bc_as_identity v;v.volume=i.VolumeSerialNumber;memcpy(v.file,i.FileId.Identifier,16);return v;}
static int same_id(bc_as_identity a,bc_as_identity b){return a.volume==b.volume&&memcmp(a.file,b.file,16)==0;}
static bc_as_status inspect(HANDLE h,int directory,bc_as_info *info,bc_as_error *e,size_t index){
    if(GetFileType(h)!=FILE_TYPE_DISK){return fail(e,BC_AS_KIND,GetLastError(),0,index);}
    if(!GetFileInformationByHandleEx(h,FileAttributeTagInfo,&info->tag,sizeof(info->tag))){return fail(e,BC_AS_OS,GetLastError(),0,index);}
    if((info->tag.FileAttributes&FILE_ATTRIBUTE_REPARSE_POINT)||info->tag.ReparseTag){return fail(e,BC_AS_REPARSE,0,0,index);}
    if(((info->tag.FileAttributes&FILE_ATTRIBUTE_DIRECTORY)!=0)!=directory){return fail(e,BC_AS_KIND,0,0,index);}
    if(!GetFileInformationByHandleEx(h,FileIdInfo,&info->id,sizeof(info->id))||
       !GetFileInformationByHandleEx(h,FileStandardInfo,&info->standard,sizeof(info->standard))||
       !GetFileInformationByHandleEx(h,FileBasicInfo,&info->basic,sizeof(info->basic))){return fail(e,BC_AS_OS,GetLastError(),0,index);}
    if(info->standard.DeletePending||info->standard.Directory!=(BOOLEAN)directory||info->standard.EndOfFile.QuadPart<0){return fail(e,BC_AS_CHANGED,0,0,index);}
    /* A single supplied path must not admit an outside-root hard-link alias. */
    if(!directory&&info->standard.NumberOfLinks!=1){return fail(e,BC_AS_IDENTITY,0,0,index);}
    return BC_AS_OK;
}
static bc_as_status open_component(HANDLE parent,const wchar_t *name,size_t length,int directory,HANDLE *out,bc_as_error *e,size_t index){
    UNICODE_STRING text;OBJECT_ATTRIBUTES attrs;IO_STATUS_BLOCK io;NTSTATUS status;HANDLE h=NULL;bc_as_info info;bc_as_status result;
    if(length==0||length>BC_AS_ROOT_CHARS||length>32766){return fail(e,BC_AS_LIMIT,0,0,index);}
    text.Buffer=(PWSTR)name;text.Length=(USHORT)(length*sizeof(wchar_t));text.MaximumLength=text.Length;
    memset(&attrs,0,sizeof(attrs));attrs.Length=sizeof(attrs);attrs.RootDirectory=parent;attrs.ObjectName=&text;attrs.Attributes=OBJ_CASE_INSENSITIVE;
    memset(&io,0,sizeof(io));
    status=NtCreateFile(&h,FILE_READ_ATTRIBUTES|SYNCHRONIZE|(directory?FILE_TRAVERSE:FILE_READ_DATA),&attrs,&io,NULL,0,
                       FILE_SHARE_READ,FILE_OPEN,FILE_OPEN_REPARSE_POINT|FILE_SYNCHRONOUS_IO_NONALERT,NULL,0);
    if(status<0){return fail(e,BC_AS_OS,0,status,index);}
    result=inspect(h,directory,&info,e,index);
    if(result!=BC_AS_OK){CloseHandle(h);return result;}
    *out=h;return BC_AS_OK;
}
void bc_as_root_close(bc_as_root *r){if(r){while(r->count){CloseHandle(r->handles[--r->count]);}release(r);}}
bc_as_status bc_as_root_open(const wchar_t *path,size_t length,bc_as_root **out,bc_as_error *e){
    wchar_t drive[]=L"\\??\\C:\\";wchar_t final[64],fs[16];size_t i,start,parts=0;bc_as_root *r;bc_as_status s;DWORD n;bc_as_info info;
    if(!path||!out||*out){return fail(e,BC_AS_ARGUMENT,0,0,0);}
    if(length<3||length>BC_AS_ROOT_CHARS||!((path[0]>='A'&&path[0]<='Z')||(path[0]>='a'&&path[0]<='z'))||path[1]!=':'||path[2]!='\\'){
        return fail(e,BC_AS_NAME,0,0,0);
    }
    start=3;for(i=3;i<=length;++i){if(i==length||path[i]=='\\'){
        if(i==3&&length==3){break;}
        if(!component(path+start,i-start)){return fail(e,BC_AS_NAME,0,0,0);}
        if(++parts>BC_AS_ROOT_COMPONENTS){return fail(e,BC_AS_LIMIT,0,0,0);}start=i+1;
    }}
    r=allocate(sizeof(*r));if(!r){return fail(e,BC_AS_ALLOCATION,0,0,0);}drive[4]=path[0];
    s=open_component(NULL,drive,7,1,&r->handles[0],e,0);if(s!=BC_AS_OK){release(r);return s;}r->count=1;
    n=GetFinalPathNameByHandleW(r->handles[0],final,64,VOLUME_NAME_GUID|FILE_NAME_NORMALIZED);
    if(n!=49||wcsncmp(final,L"\\\\?\\Volume{",11)!=0||final[47]!='}'||final[48]!='\\'||GetDriveTypeW(final)!=DRIVE_FIXED||
       !GetVolumeInformationByHandleW(r->handles[0],NULL,0,NULL,NULL,NULL,fs,16)||wcscmp(fs,L"NTFS")!=0){
        bc_as_root_close(r);return fail(e,BC_AS_UNSUPPORTED,0,0,0);
    }
    start=3;for(i=3;i<=length;++i){if(i==length||path[i]=='\\'){
        if(i==3&&length==3){break;}
        s=open_component(r->handles[r->count-1],path+start,i-start,1,&r->handles[r->count],e,0);
        if(s!=BC_AS_OK){bc_as_root_close(r);return s;}++r->count;CHECKPOINT(1,r->handles[r->count-1]);start=i+1;
    }}
    s=inspect(r->handles[r->count-1],1,&info,e,0);if(s!=BC_AS_OK){bc_as_root_close(r);return s;}
    r->identity=identity(info.id);
    for(i=0;i<r->count;++i){s=inspect(r->handles[i],1,&info,e,i);if(s!=BC_AS_OK){bc_as_root_close(r);return s;}
        if(identity(info.id).volume!=r->identity.volume){bc_as_root_close(r);return fail(e,BC_AS_IDENTITY,0,0,i);}}
    *out=r;return BC_AS_OK;
}
bc_as_status bc_as_root_identity(const bc_as_root *r,bc_as_identity *out){if(!r||!out){return BC_AS_ARGUMENT;}*out=r->identity;return BC_AS_OK;}
static int stable(const bc_as_info *a,const bc_as_info *b){
    return same_id(identity(a->id),identity(b->id))&&a->standard.EndOfFile.QuadPart==b->standard.EndOfFile.QuadPart&&
        a->standard.NumberOfLinks==b->standard.NumberOfLinks&&a->basic.CreationTime.QuadPart==b->basic.CreationTime.QuadPart&&
        a->basic.LastWriteTime.QuadPart==b->basic.LastWriteTime.QuadPart&&a->basic.ChangeTime.QuadPart==b->basic.ChangeTime.QuadPart&&
        a->tag.FileAttributes==b->tag.FileAttributes;
}
bc_as_status bc_as_read_config(const bc_as_root *r,const wchar_t *name,size_t units,
                              uint8_t *out,size_t capacity,size_t *length){
    HANDLE file=NULL;
    bc_as_info before,after;
    DWORD got;
    uint8_t extra;
    size_t used=0,size;
    bc_as_status s;
    if(!r||!name||units==0||units>255||!out||capacity>65536||!length){return BC_AS_ARGUMENT;}
    if(!component(name,units)){return BC_AS_NAME;}
    s=open_component(r->handles[r->count-1],name,units,0,&file,NULL,0);
    if(s!=BC_AS_OK){return s;}
    s=inspect(file,0,&before,NULL,0);if(s!=BC_AS_OK){goto done;}
    if(identity(before.id).volume!=r->identity.volume){s=BC_AS_IDENTITY;goto done;}
    if((uint64_t)before.standard.EndOfFile.QuadPart>capacity){s=BC_AS_LIMIT;goto done;}
    size=(size_t)before.standard.EndOfFile.QuadPart;
    while(used<size){
        if(!ReadFile(file,out+used,(DWORD)(size-used),&got,NULL)){s=BC_AS_OS;goto done;}
        if(got==0||got>size-used){s=BC_AS_CHANGED;goto done;}
        used+=got;
    }
    if(!ReadFile(file,&extra,1,&got,NULL)){s=BC_AS_OS;goto done;}
    if(got!=0){s=BC_AS_CHANGED;goto done;}
    s=inspect(file,0,&after,NULL,0);
    if(s==BC_AS_OK&&!stable(&before,&after)){s=BC_AS_CHANGED;}
done:
    if(!CloseHandle(file)&&s==BC_AS_OK){s=BC_AS_OS;}
    if(s==BC_AS_OK){*length=used;}
    return s;
}
#ifdef BC_AS_TEST_ENGINE_CLOCK
extern uintptr_t bc_runtime_engine_monotonic_ticks(void);
#endif
static int expired(uint64_t deadline){
    if(!deadline){return 0;}
#ifdef BC_AS_TEST_ENGINE_CLOCK
    return bc_runtime_engine_monotonic_ticks()>=deadline;
#else
    ULONGLONG now;
    QueryInterruptTimePrecise(&now);
    return now>=deadline;
#endif
}
#ifndef BC_AS_TEST_ENGINE_CLOCK
#pragma comment(lib, "mincore.lib")
#endif

bc_as_status bc_as_collect(const bc_as_root *r,const bc_as_path *paths,size_t count,size_t budget,bc_as_snapshot **out,bc_as_error *e){
    return bc_as_collect_until(r,paths,count,budget,0,out,e);
}
bc_as_status bc_as_collect_until(const bc_as_root *r,const bc_as_path *paths,size_t count,size_t budget,
                                 uint64_t deadline,bc_as_snapshot **out,bc_as_error *e){
    bc_as_snapshot stage,*published;HANDLE handles[BC_AS_HANDLES],leaves[BC_AS_FILES];bc_as_info before[BC_AS_FILES],info;
    LONGLONG changes[BC_AS_HANDLES],root_changes[BC_AS_ROOT_COMPONENTS+1u];
    size_t held=0,i,j,at,start,n;bc_as_status s=BC_AS_OK;wchar_t name[BC_AS_PATH];HANDLE parent,h=NULL;DWORD got;uint8_t extra;
    if(!r||!paths||!out||*out||count==0){return fail(e,BC_AS_ARGUMENT,0,0,0);}
    if(count>BC_AS_FILES||budget>BC_AS_BYTES){return fail(e,BC_AS_LIMIT,0,0,0);}
    memset(&stage,0,sizeof(stage));
    for(i=0;i<count;++i){if(!bc_as_member_path(paths[i].data,paths[i].length)){return fail(e,BC_AS_NAME,0,0,i);}
        stage.rows[i].name_length=paths[i].length;memcpy(stage.rows[i].name,paths[i].data,paths[i].length);
        for(j=0;j<i;++j){bc_as_path a={stage.rows[i].name,stage.rows[i].name_length},b={stage.rows[j].name,stage.rows[j].name_length};
            if(same_name(&a,&b)){return fail(e,BC_AS_IDENTITY,0,0,i);}}
    }
    if(expired(deadline)){return fail(e,BC_AS_DEADLINE,0,0,0);}
    for(i=0;i<r->count;++i){s=inspect(r->handles[i],1,&info,e,i);if(s!=BC_AS_OK){return s;}root_changes[i]=info.basic.ChangeTime.QuadPart;}
    for(i=0;i<count;++i){
        if(expired(deadline)){s=fail(e,BC_AS_DEADLINE,0,0,i);goto done;}
        const bc_as_row *row=&stage.rows[i];parent=r->handles[r->count-1];start=0;
        for(at=0;at<=row->name_length;++at){if(at==row->name_length||row->name[at]=='/'){
            n=at-start;for(j=0;j<n;++j){name[j]=(wchar_t)row->name[start+j];}
            if(held==BC_AS_HANDLES){s=fail(e,BC_AS_LIMIT,0,0,i);goto done;}
            s=open_component(parent,name,n,at!=row->name_length,&h,e,i);if(s!=BC_AS_OK){goto done;}
            handles[held++]=h;parent=h;
            {FILE_BASIC_INFO basic;if(!GetFileInformationByHandleEx(h,FileBasicInfo,&basic,sizeof(basic))){s=fail(e,BC_AS_OS,GetLastError(),0,i);goto done;}changes[held-1]=basic.ChangeTime.QuadPart;}
            CHECKPOINT(at==row->name_length?3:2,h);start=at+1;
        }}
        leaves[i]=h;s=inspect(h,0,&before[i],e,i);if(s!=BC_AS_OK){goto done;}
        stage.rows[i].identity=identity(before[i].id);
        if(stage.rows[i].identity.volume!=r->identity.volume){s=fail(e,BC_AS_IDENTITY,0,0,i);goto done;}
        for(j=0;j<i;++j){if(same_id(stage.rows[j].identity,stage.rows[i].identity)){s=fail(e,BC_AS_IDENTITY,0,0,i);goto done;}}
        if((uint64_t)before[i].standard.EndOfFile.QuadPart>budget-stage.used){s=fail(e,BC_AS_LIMIT,0,0,i);goto done;}
        n=(size_t)before[i].standard.EndOfFile.QuadPart;stage.rows[i].start=stage.used;stage.rows[i].length=n;
        j=0;while(j<n){if(!ReadFile(h,stage.bytes+stage.used+j,(DWORD)(n-j),&got,NULL)){s=fail(e,BC_AS_OS,GetLastError(),0,i);goto done;}
            if(got==0||got>n-j){s=fail(e,BC_AS_CHANGED,0,0,i);goto done;}j+=got;
        }
        if(!ReadFile(h,&extra,1,&got,NULL)){s=fail(e,BC_AS_OS,GetLastError(),0,i);goto done;}
        if(got!=0){s=fail(e,BC_AS_CHANGED,0,0,i);goto done;}
        stage.used+=n;stage.count=i+1;CHECKPOINT(4,h);
    }
    if(expired(deadline)){s=fail(e,BC_AS_DEADLINE,0,0,count);goto done;}
    for(i=0;i<count;++i){s=inspect(leaves[i],0,&info,e,i);if(s!=BC_AS_OK){goto done;}
        if(!stable(&before[i],&info)){s=fail(e,BC_AS_CHANGED,0,0,i);goto done;}}
    for(i=0;i<held;++i){FILE_ATTRIBUTE_TAG_INFO tag;FILE_BASIC_INFO basic;
        if(!GetFileInformationByHandleEx(handles[i],FileAttributeTagInfo,&tag,sizeof(tag))){s=fail(e,BC_AS_OS,GetLastError(),0,i);goto done;}
        if((tag.FileAttributes&FILE_ATTRIBUTE_REPARSE_POINT)||tag.ReparseTag){s=fail(e,BC_AS_REPARSE,0,0,i);goto done;}
        if(!GetFileInformationByHandleEx(handles[i],FileBasicInfo,&basic,sizeof(basic))){s=fail(e,BC_AS_OS,GetLastError(),0,i);goto done;}
        if(basic.ChangeTime.QuadPart!=changes[i]){s=fail(e,BC_AS_CHANGED,0,0,i);goto done;}}
    for(i=0;i<r->count;++i){s=inspect(r->handles[i],1,&info,e,i);if(s!=BC_AS_OK){goto done;}
        if(info.basic.ChangeTime.QuadPart!=root_changes[i]){s=fail(e,BC_AS_CHANGED,0,0,i);goto done;}}
    if(expired(deadline)){s=fail(e,BC_AS_DEADLINE,0,0,count);goto done;}
    published=allocate(sizeof(*published));if(!published){s=fail(e,BC_AS_ALLOCATION,0,0,0);goto done;}
    *published=stage;*out=published;
done:
    while(held){CloseHandle(handles[--held]);}return s;
}
size_t bc_as_count(const bc_as_snapshot *s){return s?s->count:0;}
size_t bc_as_size(const bc_as_snapshot *s){return s?s->used:0;}
bc_as_status bc_as_file(const bc_as_snapshot *s,size_t index,bc_as_view *out){
    const bc_as_row *row;if(!s||!out||index>=s->count){return BC_AS_ARGUMENT;}row=&s->rows[index];
    out->name=row->name;out->name_length=row->name_length;out->bytes=s->bytes+row->start;out->length=row->length;out->identity=row->identity;return BC_AS_OK;
}
void bc_as_snapshot_close(bc_as_snapshot *s){release(s);}
