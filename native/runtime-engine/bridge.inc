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
 if(!status && operation==4){e->f_1=B6(e->f_1);e->f_2=B6(e->f_2);e->f_3=B7(e->f_3);e->f_4=B12(e->f_4);e->f_5=B12(e->f_5);e->f_6=B17(e->f_6);e->f_7=B17(e->f_7);}
}
uint32_t bc_runtime_engine_compile(void *raw,void *incoming,uintptr_t limit){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B4(&e->f_0,&e->f_1,(bc_engine_input *)incoming,limit);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_compile_input(void *raw,void *incoming,uintptr_t limit){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B9(&e->f_0,&e->f_1,(bc_engine_input_entry *)incoming,limit);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_execute_input(void *raw,uintptr_t instance,const void *input){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B10(&e->f_0,&e->f_1,&e->f_3,&e->f_4,instance,(const bc_engine_snapshot *)input);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_instance_input(void *raw,uintptr_t program,void *incoming,uintptr_t budget){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B11(&e->f_0,&e->f_1,&e->f_3,&e->f_4,(bc_engine_snapshots *)incoming,program,budget);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_compile_output(void *raw,void *incoming,uintptr_t limit,uint32_t input){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=input>1?1:input?B14(&e->f_0,&e->f_1,(bc_engine_input_entry *)incoming,limit):B13(&e->f_0,&e->f_1,(bc_engine_input *)incoming,limit);
 return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_instance_output(void *raw,uintptr_t program,void *input,uintptr_t budget,uintptr_t limit,uint32_t allowed){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B15(&e->f_0,&e->f_1,&e->f_3,&e->f_4,(bc_engine_snapshots *)input,program,budget,limit,allowed);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_take_output(void *raw,uintptr_t instance,void *outgoing){
 bc_engine *e=raw;bc_engine_ticket ticket;bc_abi_thread_identity owner;
 uint32_t s=bc_abi_guard_enter(&owner);if(s)return s;
 s=B2(&e->f_0,owner.thread,owner.lifetime);
 if(s==8){
  /* Already-owned output extraction is bounded maintenance, not guest work. */
  s=B16(&e->f_0,&e->f_3,&e->f_6,&e->f_7,instance,(bc_engine_outputs *)outgoing);
  uint32_t end=bc_abi_guard_leave(owner);return end?end:s;
 }
 if(!s){ticket.owner=owner;ticket.epoch=e->f_0.f_3;}
 uint32_t end=bc_abi_guard_leave(owner);if(end)return end;if(s)return s;
 s=B16(&e->f_0,&e->f_3,&e->f_6,&e->f_7,instance,(bc_engine_outputs *)outgoing);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_call(void *raw,uint32_t operation,uintptr_t id,uintptr_t argument){
 bc_engine *e=raw;bc_engine_ticket ticket;bc_abi_thread_identity owner;
 uint32_t s=bc_abi_guard_enter(&owner);if(s)return s;
 s=B2(&e->f_0,owner.thread,owner.lifetime);
 if(s==8){
  s=B8(&e->f_0,&e->f_1,&e->f_2,&e->f_3,&e->f_4,&e->f_5,&e->f_6,&e->f_7,owner.thread,owner.lifetime,operation,id,argument);
  reset_closed(e,operation,s);uint32_t end=bc_abi_guard_leave(owner);return end?end:s;
 }
 if(!s){ticket.owner=owner;ticket.epoch=e->f_0.f_3;}
 uint32_t end=bc_abi_guard_leave(owner);if(end)return end;if(s)return s;
 s=B5(&e->f_0,&e->f_1,&e->f_2,&e->f_3,&e->f_4,&e->f_5,&e->f_6,&e->f_7,operation,id,argument);reset_closed(e,operation,s);
 return finish(e,ticket,s);
}

/* Only layout facts cross this bridge; capacities/quota arithmetic stay Fairy. */
uintptr_t bc_runtime_engine_control_layout(uint32_t kind){
 switch(kind){
 case 0:return sizeof(bc_engine);case 1:return sizeof(bc_engine_program);
 case 2:return sizeof(bc_engine_instance);case 3:return sizeof(bc_engine_bound_input);
 case 4:return sizeof(bc_engine_output);default:return 0;
 }
}
uint32_t bc_runtime_engine_control_access(const void *raw){
 const bc_engine *e=raw;bc_abi_thread_identity id;uint32_t s=bc_abi_guard_enter(&id);if(s)return s;
 s=B18(&e->f_0,id.thread,id.lifetime);uint32_t end=bc_abi_guard_leave(id);return end?end:s;
}

uintptr_t bc_runtime_engine_program_layout(uint32_t kind){
 switch(kind){
 case 0:return sizeof(bc_ordinary_stored);case 1:return sizeof(bc_ordinary_program);
 case 2:return sizeof(bc_input_stored);case 3:return sizeof(bc_input_program);
 case 4:return sizeof(bc_output_stored);case 5:return sizeof(bc_output_program);
 default:return 0;
 }
}

/* Actual SDK byte counts and emitted type widths only; Fairy checks the sums.
   source is an authentic typed Fairy owner, never an arbitrary public pointer. */
uintptr_t bc_runtime_engine_compile_fact(const void *source,uint32_t kind,uint32_t fact){
 if(kind>1)return 0;
 if(fact==0)return kind?sizeof(bc_input_entry):sizeof(bc_ordinary_entry);
 if(!source)return 0;
 if(fact==2)return kind?((const bc_engine_input_entry *)source)->f_1:((const bc_engine_input *)source)->f_1;
 if(fact!=1)return 0;
 return kind?((const bc_input_entry *)source)->f_0.f_0.f_1:((const bc_ordinary_entry *)source)->f_0.f_0.f_1;
}
uint32_t bc_runtime_engine_compile_preflight(void *raw,uint32_t mode,const void *selected){
 bc_engine *e=raw;bc_abi_thread_identity id;uint32_t s=bc_abi_guard_enter(&id);if(s)return s;
 s=B18(&e->f_0,id.thread,id.lifetime);
 if(!s)s=B21(&e->f_0,&e->f_1,mode,0,0);
 if(!s){
  uint32_t kind=mode==1||mode==3;
  s=B21(&e->f_0,&e->f_1,mode,bc_runtime_engine_compile_fact(selected,kind,1),bc_runtime_engine_compile_fact(selected,kind,0));
 }
 uint32_t end=bc_abi_guard_leave(id);return end?end:s;
}
