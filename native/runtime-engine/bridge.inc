#include "clock.inc"

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
 if(!status && operation==4){e->f_1=B6(e->f_1);e->f_2=B6(e->f_2);e->f_3=B7(e->f_3);e->f_4=B12(e->f_4);e->f_5=B12(e->f_5);e->f_6=B17(e->f_6);e->f_7=B17(e->f_7);e->f_8=B37(e->f_8);e->f_10=B43(e->f_10);e->f_9=B46(e->f_9);e->f_12=B57(e->f_12);}
}
uint32_t bc_runtime_engine_compile(void *raw,void *incoming,uintptr_t limit,uintptr_t deadline){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B4(&e->f_0,&e->f_1,(bc_engine_input *)incoming,limit,deadline);return finish(e,ticket,s);
}
static int compile_has_input(const bc_engine *e){
 const bc_compile_work *job=e->f_9.f_0;
 return e->f_9.f_3==1 && job->f_11;
}
uint32_t bc_runtime_engine_step_compile(void *raw,uintptr_t id){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=compile_has_input(e) ? B55(&e->f_0,&e->f_1,&e->f_9,&e->f_12,&e->f_11,&e->f_8,id)
                 : B42(&e->f_0,&e->f_1,&e->f_9,&e->f_10,&e->f_11,id);
 return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_begin_compile(void *raw,void *incoming,uintptr_t limit,uintptr_t deadline,uint32_t output){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B44(&e->f_0,&e->f_9,&e->f_10,(bc_engine_input *)incoming,limit,deadline,output!=0);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_begin_compile_input(void *raw,void *incoming,uintptr_t limit,uintptr_t deadline,uint32_t mode){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B54(&e->f_0,&e->f_9,&e->f_12,(bc_engine_input_entry *)incoming,limit,deadline,mode);
 return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_end_compile(void *raw,uintptr_t id,uint32_t detach){
 bc_engine *e=raw;bc_abi_thread_identity id_owner;uint32_t s=bc_abi_guard_enter(&id_owner);if(s)return s;
 s=B18(&e->f_0,id_owner.thread,id_owner.lifetime);
 if(!s)s=compile_has_input(e) ? B56(&e->f_0,&e->f_9,&e->f_12,&e->f_11,id,detach!=0)
                     : B45(&e->f_0,&e->f_9,&e->f_10,&e->f_11,id,detach!=0);
 uint32_t end=bc_abi_guard_leave(id_owner);return end?end:s;
}
uint32_t bc_runtime_engine_advance_compile_literals(void *meta,const void *selected,void *raw,void *candidate,void *meter,uint32_t collecting){
 bc_compile_work *job=raw;
 bc_compile_candidate *work=candidate;
 return B48(meta,selected,&job->f_9,&job->f_10,&work->f_1,&work->f_3,meter,collecting!=0);
}
uint32_t bc_runtime_engine_advance_compile_body(void *meta,const void *selected,void *raw,void *candidate,void *meter,uintptr_t deadline){
 bc_compile_work *job=raw;
 bc_compile_candidate *work=candidate;
 return B49(meta,selected,&job->f_9,work->f_2,job->f_12!=0,&job->f_10,&work->f_3,&work->f_0,&work->f_4,&work->f_5,
     &work->f_6,&work->f_7,&work->f_8,meter,deadline,&job->f_13);
}
/* Reserve a single SDK-owned slot before Fairy initializes its value. */
struct fy_std_system_heap_block_v0 {
 void *data;
 size_t size, alignment;
};
extern uint32_t fy_std_system_heap_allocate_v0(size_t,size_t,struct fy_std_system_heap_block_v0 *);
static uint32_t reserve_compile_slot(void **data,uintptr_t *bytes,uintptr_t *alignment,size_t size,size_t align){
 struct fy_std_system_heap_block_v0 block={0};
 const uint32_t status=fy_std_system_heap_allocate_v0(size,align,&block);
 if(status)return status;
 *data=block.data;
 *bytes=block.size;
 *alignment=block.alignment;
 return 0;
}
uintptr_t bc_runtime_engine_compile_proof_storage(const void *raw){
 const bc_compile_candidate *work=raw;
 if(!work || work->f_10.f_4>(UINTPTR_MAX-sizeof(bc_compile_proof))/8)return 0;
 return sizeof(bc_compile_proof)+work->f_10.f_4*8;
}
uint32_t bc_runtime_engine_advance_compile_proof(void *raw,const void *selected,void *meter,void *failure){
 bc_compile_candidate *work=raw;
 return B50(&work->f_0,&work->f_10,work->f_9.f_0,selected,meter,failure);
}
uint32_t bc_runtime_engine_begin_compile_proof(void *raw,const void *selected,uintptr_t image_limit,uintptr_t deadline,uint32_t input,void *failure){
 bc_compile_candidate *work=raw;
 uint32_t status=B51(&work->f_0,&work->f_1,&work->f_10,work->f_2,selected,image_limit,deadline,failure);
 if(status)return status;
 if(work->f_9.f_0 || work->f_9.f_1 || work->f_9.f_2 || work->f_9.f_3 ||
     work->f_9.f_4!=sizeof(bc_compile_proof) || work->f_9.f_5!=_Alignof(bc_compile_proof))return 2;
 status=reserve_compile_slot(&work->f_9.f_0,&work->f_9.f_1,&work->f_9.f_2,
     sizeof(bc_compile_proof),_Alignof(bc_compile_proof));
 return status || !B53(&work->f_9,input!=0) ? 2 : 0;
}
uint32_t bc_runtime_engine_reserve_proved_program(void *raw,const void *selected,void *outgoing,void *failure){
 bc_compile_candidate *work=raw;
 return B52(&work->f_0,&work->f_10,work->f_9.f_0,work->f_2,selected,outgoing,failure);
}
uint32_t bc_runtime_engine_retain_proved_input(void *raw,const void *selected,void *outgoing,void *failure){
 bc_compile_candidate *work=raw;
 return B58(&work->f_0,&work->f_10,work->f_9.f_0,selected,outgoing,failure);
}
uintptr_t bc_runtime_engine_output_proof_storage(const void *raw){
 const bc_compile_candidate *work=raw;
 if(!work || work->f_10.f_4>(UINTPTR_MAX-sizeof(bc_compile_output_proof))/8)return 0;
 return sizeof(bc_compile_output_proof)+work->f_10.f_4*8;
}
uint32_t bc_runtime_engine_begin_output_proof(void *raw,uintptr_t image_limit,uint32_t input,uintptr_t deadline,uintptr_t *fuel,void *failure){
 bc_compile_candidate *work=raw;
 if(work->f_11.f_0 || work->f_11.f_1 || work->f_11.f_2 || work->f_11.f_3 ||
     work->f_11.f_4!=sizeof(bc_compile_output_proof) || work->f_11.f_5!=_Alignof(bc_compile_output_proof))return 2;
 uint32_t status=B59(&work->f_1,&work->f_10,image_limit,deadline,fuel,failure);
 if(status)return status;
 status=reserve_compile_slot(&work->f_11.f_0,&work->f_11.f_1,&work->f_11.f_2,
     sizeof(bc_compile_output_proof),_Alignof(bc_compile_output_proof));
 if(status)return 2;
 bc_compile_output_proof *proof=work->f_11.f_0;
 memset(proof,0,sizeof(*proof));
 B60(&proof->f_0,&proof->f_1,input!=0);
 work->f_11.f_3=1;
 return 0;
}
uint32_t bc_runtime_engine_step_output_proof(void *raw,const void *snapshot,void *meter,void *failure){
 bc_compile_candidate *work=raw;
 bc_compile_output_proof *proof=work->f_11.f_0;
 return B61(&work->f_0,&work->f_10,&proof->f_0,&proof->f_1,snapshot,meter,failure);
}
uint32_t bc_runtime_engine_finish_output_proof(void *raw,const void *snapshot,uintptr_t deadline,uintptr_t *fuel,void *outgoing,void *failure){
 bc_compile_candidate *work=raw;
 return B62(&work->f_0,&work->f_10,work->f_11.f_0,snapshot,deadline,fuel,outgoing,failure);
}
uint32_t bc_runtime_engine_reserve_compile_candidate(void *raw){
 bc_compile_candidates *storage=raw;
 const size_t size=sizeof(bc_compile_candidate),align=_Alignof(bc_compile_candidate);
 if(storage->f_0 || storage->f_1 || storage->f_2 || storage->f_3 ||
     storage->f_4!=size || storage->f_5!=align)return 4;
 return reserve_compile_slot(&storage->f_0,&storage->f_1,&storage->f_2,size,align);
}
uintptr_t bc_runtime_engine_compile_candidate_width(void){return sizeof(bc_compile_candidate);}
void bc_runtime_engine_dispose_compile_candidate(void *raw){
 bc_compile_candidates *candidate=raw;*candidate=B47(*candidate);
}
uint32_t bc_runtime_engine_compile_input(void *raw,void *incoming,uintptr_t limit,uintptr_t deadline){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B9(&e->f_0,&e->f_1,(bc_engine_input_entry *)incoming,limit,deadline);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_execute_input(void *raw,uintptr_t instance,const void *input){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B10(&e->f_0,&e->f_1,&e->f_3,&e->f_4,instance,(const bc_engine_snapshot *)input,&e->f_6);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_instance_input(void *raw,uintptr_t program,void *incoming,uintptr_t budget){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B11(&e->f_0,&e->f_1,&e->f_3,&e->f_4,(bc_engine_snapshots *)incoming,program,budget,&e->f_6);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_compile_output(void *raw,void *incoming,uintptr_t limit,uint32_t mode,uintptr_t deadline){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=mode>5?1:mode?B14(&e->f_0,&e->f_1,(bc_engine_input_entry *)incoming,limit,mode,deadline,&e->f_8):B13(&e->f_0,&e->f_1,(bc_engine_input *)incoming,limit,deadline,&e->f_8);
 return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_instance_output(void *raw,uintptr_t program,void *input,uintptr_t budget,uintptr_t limit,uint32_t allowed,uintptr_t deadline){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B15(&e->f_0,&e->f_1,&e->f_3,&e->f_4,(bc_engine_snapshots *)input,program,budget,limit,allowed,deadline,&e->f_6);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_take_output(void *raw,uintptr_t instance,void *outgoing){
 bc_engine *e=raw;bc_engine_ticket ticket={0};bc_abi_thread_identity owner;
 uint32_t s=bc_abi_guard_enter(&owner);if(s)return s;
 s=B2(&e->f_0,owner.thread,owner.lifetime);
 if(s==8||s==14){
  /* Already-owned output extraction is bounded maintenance, not guest work. */
  s=B16(&e->f_0,&e->f_3,&e->f_6,&e->f_7,instance,(bc_engine_outputs *)outgoing,&e->f_1);
  uint32_t end=bc_abi_guard_leave(owner);return end?end:s;
 }
 if(!s){ticket.owner=owner;ticket.epoch=e->f_0.f_3;}
 uint32_t end=bc_abi_guard_leave(owner);if(end)return end;if(s)return s;
 s=B16(&e->f_0,&e->f_3,&e->f_6,&e->f_7,instance,(bc_engine_outputs *)outgoing,&e->f_1);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_call(void *raw,uint32_t operation,uintptr_t id,uintptr_t argument){
 bc_engine *e=raw;bc_engine_ticket ticket={0};bc_abi_thread_identity owner;
 uint32_t s=bc_abi_guard_enter(&owner);if(s)return s;
 s=B2(&e->f_0,owner.thread,owner.lifetime);
 if(s==8||s==14){
  s=B8(&e->f_0,&e->f_1,&e->f_2,&e->f_3,&e->f_4,&e->f_5,&e->f_6,&e->f_7,owner.thread,owner.lifetime,operation,id,argument);
  reset_closed(e,operation,s);uint32_t end=bc_abi_guard_leave(owner);return end?end:s;
 }
 if(!s){ticket.owner=owner;ticket.epoch=e->f_0.f_3;}
 uint32_t end=bc_abi_guard_leave(owner);if(end)return end;if(s)return s;
 s=B5(&e->f_0,&e->f_1,&e->f_2,&e->f_3,&e->f_4,&e->f_5,&e->f_6,&e->f_7,operation,id,argument);reset_closed(e,operation,s);
 return finish(e,ticket,s);
}

#ifndef BC_ENGINE_SCALAR_PREVIEW
uint32_t bc_runtime_engine_retain_host(void *raw,void *incoming,const void *empty,uintptr_t deadline){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 typedef __typeof__(((bc_engine_program *)0)->f_9) bc_host_programs;
 bc_host_programs *source=incoming;
 /* B38 consumes the vector even on denial. Restore the caller's empty owner. */
 bc_host_programs owned=*source;
 *source=*(const bc_host_programs *)empty;
 s=B38(&e->f_0,&e->f_1,owned,sizeof(bc_host_program),sizeof(bc_host_ir),deadline);return finish(e,ticket,s);
}
#endif

uint32_t bc_runtime_engine_prepare_host(void *raw,uintptr_t program,const void *run,
 const uint8_t *data,uintptr_t length,uintptr_t selected){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B39(&e->f_0,&e->f_1,&e->f_3,&e->f_6,&e->f_8,run,program,sizeof(bc_host_exchange),(fy_byte_slice){data,length},selected);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_reply_host(void *raw,uintptr_t instance,uintptr_t run,uintptr_t request,
 uint8_t kind,const uint8_t *data,uintptr_t length,uintptr_t total,uintptr_t offset){
 bc_engine *e=raw;bc_engine_ticket ticket;uint32_t s=admission(e,&ticket);if(s)return s;
 s=B40(&e->f_0,&e->f_1,&e->f_3,&e->f_6,&e->f_7,instance,run,request,kind,(fy_byte_slice){data,length},total,offset);return finish(e,ticket,s);
}
uint32_t bc_runtime_engine_drive_host(void *raw,uint32_t mode,uintptr_t quantum,uintptr_t run,uintptr_t request,
 uint8_t kind,const uint8_t *data,uintptr_t length,void *transition,uintptr_t offset){
 bc_engine_output *owner=raw;
 return B41(&owner->f_3,mode,quantum,run,request,kind,(fy_byte_slice){data,length},transition,offset);
}
uint32_t bc_runtime_engine_seal_host(void *raw){
 bc_engine_output *owner=raw;
 uint32_t status=0;
 owner->f_3=B63(owner->f_3,&owner->f_1.f_0,&owner->f_1.f_1,&status);
 return status;
}

_Static_assert(offsetof(bc_host_exchange,f_0)==0 && offsetof(bc_host_exchange,f_1)==32 &&
               sizeof(((bc_host_exchange *)0)->f_1)==32,"host Buffer slots");

uintptr_t bc_runtime_engine_policy_slot_bytes(void){return sizeof(bc_engine_policy);}

/* Only layout facts cross this bridge; capacities/quota arithmetic stay Fairy. */
uintptr_t bc_runtime_engine_control_layout(uint32_t kind){
 switch(kind){
 case 0:return sizeof(bc_engine);case 1:return sizeof(bc_engine_program);
 case 2:return sizeof(bc_engine_instance);case 3:return sizeof(bc_engine_bound_input);
 case 4:return sizeof(bc_engine_output);case 5:return sizeof(bc_ordinary_entry);
 case 6:return sizeof(bc_compile_work);case 7:return sizeof(bc_input_entry);default:return 0;
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
 case 6:return sizeof(bc_engine_snapshot);
 case 7:return sizeof(bc_host_ir);
 case 8:return sizeof(bc_host_program);
 default:return 0;
 }
}

/* Actual SDK byte counts and emitted type widths only; Fairy checks the sums.
   source is an authentic typed Fairy owner, never an arbitrary public pointer. */
uintptr_t bc_runtime_engine_compile_fact(const void *source,uint32_t kind,uint32_t fact){
 if(kind>1)return 0;
 if(fact==0)return kind?sizeof(bc_input_entry):sizeof(bc_ordinary_entry);
 if(fact==3)return 8*sizeof(bc_source_index_stored);
 if(!source)return 0;
 if(fact==2)return kind?((const bc_engine_input_entry *)source)->f_1:((const bc_engine_input *)source)->f_1;
 if(fact!=1)return 0;
 return kind?((const bc_input_entry *)source)->f_0.f_0.f_1:((const bc_ordinary_entry *)source)->f_0.f_0.f_1;
}
uint32_t bc_runtime_engine_compile_preflight(void *raw,uint32_t mode,const void *selected){
 bc_engine *e=raw;bc_abi_thread_identity id;uint32_t s=bc_abi_guard_enter(&id);if(s)return s;
 s=B18(&e->f_0,id.thread,id.lifetime);
 if(!s)s=B21(&e->f_0,&e->f_1,mode,0,0);
 if(!s&&selected){
  uint32_t kind=mode==1||mode==3;
  s=B21(&e->f_0,&e->f_1,mode,bc_runtime_engine_compile_fact(selected,kind,1),bc_runtime_engine_compile_fact(selected,kind,0));
 }
 uint32_t end=bc_abi_guard_leave(id);return end?end:s;
}
uintptr_t bc_runtime_engine_input_fact(const void *source,uint32_t fact){
 if(fact==0)return sizeof(bc_engine_snapshot);
 if(fact==1&&source)return ((const bc_engine_snapshots *)source)->f_1;
 return 0;
}
uint32_t bc_runtime_engine_input_preflight(void *raw,uintptr_t program,uintptr_t budget,
 const void *input,uint32_t output,uintptr_t limit,uint32_t allowed){
 bc_engine *e=raw;bc_abi_thread_identity id;uint32_t s=bc_abi_guard_enter(&id);if(s)return s;
 s=B18(&e->f_0,id.thread,id.lifetime);
 if(!s)s=B23(&e->f_0,&e->f_1,&e->f_3,program,budget,(const bc_engine_snapshot *)input,output,limit,allowed,sizeof(bc_engine_snapshot),&e->f_4,&e->f_6);
 uint32_t end=bc_abi_guard_leave(id);return end?end:s;
}
uintptr_t bc_runtime_engine_output_fact(const void *source,uint32_t fact){
 if(fact==0)return sizeof(bc_engine_output);
 if(fact==1&&source)return ((const bc_engine_outputs *)source)->f_1;
 return 0;
}
uint32_t bc_runtime_engine_output_preflight(void *raw,uintptr_t instance){
 bc_engine *e=raw;bc_abi_thread_identity id;uint32_t s=bc_abi_guard_enter(&id);if(s)return s;
 s=B18(&e->f_0,id.thread,id.lifetime);
 if(!s)s=B24(&e->f_0,&e->f_3,&e->f_6,instance,sizeof(bc_engine_output),&e->f_1);
 uint32_t end=bc_abi_guard_leave(id);return end?end:s;
}

/* Core and the register tail share one aligned SDK allocation. */
_Static_assert(sizeof(bc_pending_core)%_Alignof(int64_t)==0, "aligned register tail");
uintptr_t bc_runtime_pending_core_stride(void){return sizeof(bc_pending_core);}
uintptr_t bc_runtime_pending_machine_stride(void){return sizeof(bc_pending_machine);}
uint32_t bc_runtime_pending_advance(void *raw,const void *program,const void *input,uint32_t operation,uintptr_t quantum){
 bc_pending_machine *owner=raw;
 if(operation==1 && owner->f_7.f_6.f_3<=2)
  return B34(program,input,&owner->f_7,&owner->f_0,&owner->f_1,&owner->f_2,&owner->f_3,&owner->f_4,&owner->f_5,&owner->f_6,quantum);
 bc_pending_core *c=owner->f_0.f_0;
 const uintptr_t length=owner->f_0.f_3;
 if(!c || length<sizeof(*c)+2048 || length>sizeof(*c)+32768 || length!=owner->f_0.f_1 ||
    (length-sizeof(*c))%1024!=0)return 5;
 if(operation==1 && owner->f_7.f_6.f_3==3)return B35(&owner->f_7,c,quantum);
 int64_t *registers=(int64_t *)((uint8_t *)owner->f_0.f_0+sizeof(*c));
 return B26(program,input,&owner->f_7,&c->f_0,&c->f_1,
  (fy_mut_usize_slice){c->f_2.data,32},(fy_mut_u32_slice){c->f_3.data,512},
  (fy_mut_i64_slice){registers,(length-sizeof(*c))/sizeof(*registers)},&c->f_4,&c->f_5,
  &owner->f_1,&owner->f_2,&owner->f_3,&owner->f_4,&owner->f_5,&owner->f_6,operation,quantum);
}
uint32_t bc_runtime_pending_maintenance(void *raw,uint32_t operation,void *outgoing){
 bc_pending_machine *owner=raw;bc_pending_core *c=owner->f_0.f_0;
 return B27(&owner->f_7,&c->f_1,&owner->f_1,&owner->f_4,&owner->f_6,outgoing,operation,&c->f_4.f_1);
}

uint32_t bc_runtime_pending_initialize(void *raw,const void *state){
 bc_pending_machine *owner=raw;bc_pending_core *c=owner->f_0.f_0;
 B29(owner,c,state);return 0;
}
uint32_t bc_runtime_engine_step_output(void *raw,const void *program,const void *input,uintptr_t quantum,uintptr_t deadline){
 bc_engine_output *owner=raw;
 uint32_t status=B31(&owner->f_2,&owner->f_1.f_0,&owner->f_1.f_1,program,input,quantum,deadline);
 owner->f_2=B32(owner->f_2);owner->f_1.f_1=B36(owner->f_1.f_1,owner->f_1.f_0.f_6);return status;
}
uint32_t bc_runtime_engine_cancel_output(void *raw,uintptr_t deadline){
 bc_engine_output *owner=raw;return B33(&owner->f_2,deadline);
}
