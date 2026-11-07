/* Exact emitted types, no cloned layouts or byte offsets. Build checks transport SHA. */
#define main generated_main
#include "generated.c"
#undef main
#include <stdlib.h>
static uintptr_t drops[16];static uintptr_t drop_count=0;
void record_drop(uintptr_t value){if(drop_count>=16)abort();drops[drop_count++]=value;}
void reset_trace(void){drop_count=0;}
uintptr_t trace_count(void){return drop_count;}
uintptr_t trace_word(uintptr_t index){if(index>=drop_count)abort();return drops[index];}
uintptr_t push_raw(void *owner,uintptr_t value){fy_resource_3 *s=owner;return fy_fn_9(&s->f_0,value);}
uintptr_t pop_raw(void *owner){fy_resource_3 *s=owner;return fy_fn_7(&s->f_0);}
uintptr_t mutate_raw(void *owner,uintptr_t index,uint8_t value){
 fy_resource_3 *s=owner;fy_resource_1 *e=fy_fn_2(&s->f_0,index);return fy_fn_4(&e->f_0,value);
}
extern size_t probe_live(void);
int main(void){int result=generated_main();if(result!=0 || probe_live()!=0)return 98;return 0;}
