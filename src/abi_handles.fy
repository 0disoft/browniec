module abi_handles;

// Internal bounded kernel, NOT a process singleton, DLL export or VM owner.
// The trusted coordinator owns one noncopied Table for the entire DLL lifetime,
// serializes EVERY access with an OS process lock, and supplies authenticated
// current OS thread ID + nonreused TLS lifetime ticket (neither may be zero).
// Never reset/recreate a table while old handles may exist. No native pointers
// are accepted/dereferenced: object is a trusted coordinator's nonzero object ID.
pub struct Identity { usize thread; usize lifetime; }
// kind: 0 free/retired, 1 Engine, 2 Program, 3 Instance. generation 0 retires.
// 48-byte slot on the pinned x64 transport; this is not a public C layout.
pub struct Slot {
    u32 generation; u32 kind; usize engine; usize thread; usize lifetime;
    usize busy; usize object;
}
pub struct Table { Slot[64] slots; usize next_admission; }
// Copyable trusted receipt, never a C/guest capability. Matching epoch prevents
// a saved receipt from ending a later call. All fields are revalidated on use.
pub struct Admission { usize target; usize engine; usize epoch; u32 kind; usize object; }
pub enum Error { BadArgument; InvalidHandle; WrongThread; Busy; ResourceLimit; State; }
pub fn u32 status(Error e){return switch(e){
    case .BadArgument:{1}case .InvalidHandle:{2}case .WrongThread:{10}
    case .Busy:{3}case .ResourceLimit:{8}case .State:{7}
};}
pub fn usize capacity(){return 64;}
pub fn u32 engine_kind(){return 1;}
pub fn u32 program_kind(){return 2;}
pub fn u32 instance_kind(){return 3;}
pub fn usize generation_max(){return 4294967295;}
fn Slot vacant(u32 generation){return Slot{.generation=generation,.kind=0,
    .engine=0,.thread=0,.lifetime=0,.busy=0,.object=0};}
pub fn Table empty(){return Table{.slots=[vacant(1);64],.next_admission=1};}
fn bool identity_valid(Identity caller){return caller.thread!=0 && caller.lifetime!=0;}
fn bool kind_valid(u32 kind){return kind>=1 && kind<=3;}
// Index is one based in the wire token; no untrusted value indexes before bounds.
pub fn Result<usize,Error> slot_index(usize handle){
    let usize low=handle%4294967296;let usize generation=handle/4294967296;
    if(low==0 || low>64 || generation==0){return .err(.InvalidHandle);}
    return .ok(low-1);
}
fn usize token(usize index,u32 generation){return (generation as usize)*4294967296+index+1;}
fn Result<usize,Error> lookup(ref Table table,usize handle,u32 kind){
    if(!kind_valid(kind)){return .err(.BadArgument);}
    let usize index=slot_index(handle)?;let Slot row=table.slots[index];
    if(row.kind!=kind || (row.generation as usize)!=handle/4294967296){return .err(.InvalidHandle);}
    if(row.object==0){return .err(.State);}
    return .ok(index);
}
fn Result<usize,Error> owner(ref Table table,usize target,u32 kind,usize engine,Identity caller){
    if(!identity_valid(caller)){return .err(.BadArgument);}
    let usize index=lookup(table,target,kind)?;let Slot row=table.slots[index];
    if(engine==0 || row.engine!=engine || (kind==1 && target!=engine)){
        return .err(.InvalidHandle);
    }
    let usize ei=lookup(table,engine,1)?;let Slot e=table.slots[ei];
    if(e.engine!=engine || e.thread==0 || e.lifetime==0){return .err(.State);}
    if(e.thread!=caller.thread || e.lifetime!=caller.lifetime){return .err(.WrongThread);}
    // Child identity is immutable and must agree with the live Engine lifetime.
    if(row.thread!=e.thread || row.lifetime!=e.lifetime){return .err(.State);}
    return .ok(ei);
}
fn Result<usize,Error> free_slot(ref Table table){
    var usize i=0;while(i<64){
        if(table.slots[i].kind==0 && table.slots[i].generation!=0){return .ok(i);}
        i+=1;
    }return .err(.ResourceLimit);
}
// Publish only after the coordinator finishes fallible native object creation.
// Rejection changes no slot, generation, busy guard or admission counter.
pub fn Result<usize,Error> create_engine(ref mut Table table,Identity caller,usize object){
    if(!identity_valid(caller) || object==0){return .err(.BadArgument);}
    let usize i=free_slot(table)?;let u32 generation=table.slots[i].generation;
    let usize handle=token(i,generation);
    table.slots[i]=Slot{.generation=generation,.kind=1,.engine=handle,
        .thread=caller.thread,.lifetime=caller.lifetime,.busy=0,.object=object};
    return .ok(handle);
}
// Explicit Engine association for APIs that take an Engine argument. Admission
// checks kind/generation/association/lifetime BEFORE busy or payload publication.
pub fn Result<Admission,Error> enter(ref mut Table table,usize target,u32 kind,
    usize engine,Identity caller){
    let usize ei=owner(table,target,kind,engine,caller)?;
    if(table.slots[ei].busy!=0){return .err(.Busy);}
    let usize epoch=table.next_admission;if(epoch==0){return .err(.ResourceLimit);}
    let usize i=slot_index(target)?;
    let Admission admitted=Admission{.target=target,.engine=engine,.epoch=epoch,
        .kind=kind,.object=table.slots[i].object};
    table.slots[ei].busy=epoch;
    // Never wrap an admission identity either; exhausted tables fail closed.
    table.next_admission=if(epoch==18446744073709551615){0}else{epoch+1};
    return .ok(admitted);
}
// Instance-only APIs have no explicit Engine argument. Resolve the stored owner,
// then apply exactly the same checks; no supplied object address is followed.
pub fn Result<Admission,Error> enter_instance(ref mut Table table,usize instance,Identity caller){
    let usize i=lookup(table,instance,3)?;let usize engine=table.slots[i].engine;
    return enter(table,instance,3,engine,caller);
}
fn Result<usize,Error> active(ref Table table,Admission a,Identity caller){
    let usize ei=owner(table,a.target,a.kind,a.engine,caller)?;
    if(a.epoch==0 || table.slots[ei].busy!=a.epoch){return .err(.State);}
    let usize i=slot_index(a.target)?;
    if(table.slots[i].object!=a.object){return .err(.State);}
    return .ok(ei);
}
// Release the admission on EVERY coordinator failure, including object OOM or
// pin/quota rejection. It consumes no registry slots or handle generations.
pub fn Result<usize,Error> leave(ref mut Table table,Admission a,Identity caller){
    let usize ei=active(table,a,caller)?;table.slots[ei].busy=0;return .ok(a.epoch);
}
// Compile publishes a Program under an Engine admission; Instance creation uses
// a Program admission. Program pins and native object lifetimes remain E03 work.
// A live admission persists on failure AND success until leave/remove is called.
pub fn Result<usize,Error> insert_child(ref mut Table table,Admission a,u32 kind,
    usize object,Identity caller){
    let usize ei=active(table,a,caller)?;
    if(object==0 || !((kind==2 && a.kind==1) || (kind==3 && a.kind==2))){
        return .err(.BadArgument);
    }
    let usize i=free_slot(table)?;let u32 generation=table.slots[i].generation;
    table.slots[i]=Slot{.generation=generation,.kind=kind,.engine=a.engine,
        .thread=caller.thread,.lifetime=caller.lifetime,.busy=0,.object=object};
    return .ok(token(i,generation));
}
// Metadata invalidation only, not bc_*_destroy. Caller must first finish/check
// bounded native cleanup and Program pin obligations. Returns object ID for the
// coordinator, atomically invalidating the target and consuming its admission.
// Engine removal refuses live children; no orphaning or implicit cascade.
pub fn Result<usize,Error> remove(ref mut Table table,Admission a,Identity caller){
    let usize ei=active(table,a,caller)?;let usize i=slot_index(a.target)?;
    if(a.kind==1){var usize child=0;while(child<64){let Slot row=table.slots[child];
        if(row.kind!=0 && child!=i && row.engine==a.engine){return .err(.Busy);}
        child+=1;
    }}
    let u32 generation=table.slots[i].generation;
    let u32 next=if(generation==4294967295){0}else{generation+1};
    table.slots[ei].busy=0;table.slots[i]=vacant(next);
    return .ok(a.object);
}
