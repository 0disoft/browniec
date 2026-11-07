#include <windows.h>
typedef struct bc_engine_ticket { bc_abi_thread_identity owner; uintptr_t epoch; } bc_engine_ticket;
uint32_t bc_runtime_engine_bind(void *raw){
 bc_engine *e=raw;bc_abi_thread_identity id;uint32_t s=bc_abi_guard_enter(&id);if(s)return s;
 s=B1(&e->f_0,id.thread,id.lifetime);uint32_t end=bc_abi_guard_leave(id);return end?end:s;
}
static uint32_t admission(bc_engine *e,bc_engine_ticket *ticket){
 bc_abi_thread_identity id;uint32_t s=bc_abi_guard_enter(&id);if(s)return s;
 s=B2(&e->f_0,id.thread,id.lifetime);if(!s){ticket->epoch=e->f_0.f_3;ticket->owner=id;}
 uint32_t end=bc_abi_guard_leave(id);return end?end:s;
}
static uint32_t finish(bc_engine *e,bc_engine_ticket ticket,uint32_t result){
 /* Admission already authenticated this synchronous no-callback operation.
    No second lock acquisition can strand an already committed operation. */
 if((uint64_t)GetCurrentThreadId()!=ticket.owner.thread){return 10;}
 uint32_t s=B3(&e->f_0,ticket.owner.thread,ticket.owner.lifetime,ticket.epoch);return s?s:result;
}
static void reset_closed(bc_engine *e,uint32_t operation,uint32_t status){
 if(!status && operation==4){e->f_1=B6(e->f_1);e->f_2=B6(e->f_2);e->f_3=B7(e->f_3);}
}
uint32_t bc_runtime_engine_compile(void *raw,void *incoming,uintptr_t limit){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B4(&e->f_0,&e->f_1,(bc_engine_input *)incoming,limit);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_call(void *raw,uint32_t operation,uintptr_t id,uintptr_t argument){
 bc_engine *e=raw;bc_engine_ticket ticket;bc_abi_thread_identity owner;
 uint32_t s=bc_abi_guard_enter(&owner);if(s)return s;
 s=B2(&e->f_0,owner.thread,owner.lifetime);
 if(s==8){
  s=B8(&e->f_0,&e->f_1,&e->f_2,&e->f_3,owner.thread,owner.lifetime,operation,id,argument);
  reset_closed(e,operation,s);uint32_t end=bc_abi_guard_leave(owner);return end?end:s;
 }
 if(!s){ticket.owner=owner;ticket.epoch=e->f_0.f_3;}
 uint32_t end=bc_abi_guard_leave(owner);if(end)return end;if(s)return s;
 s=B5(&e->f_0,&e->f_1,&e->f_2,&e->f_3,operation,id,argument);reset_closed(e,operation,s);
 return finish(e,ticket,s);
}
