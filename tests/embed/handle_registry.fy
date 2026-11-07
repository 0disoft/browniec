module tests::embed::handle_registry;
import abi_handles as h;

// Synthetic identities test the Fairy boundary; these are NOT OS thread tests.
fn h::Identity who(){return h::Identity{.thread=41,.lifetime=101};}
fn usize ok(Result<usize,h::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn h::Admission admitted(Result<h::Admission,h::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);h::Admission{.target=0,.engine=0,.epoch=0,.kind=0,.object=0}}
};}
fn u32 error(Result<usize,h::Error> r){return switch(r){case .ok(_):{assert(false);0}case .err(e):{h::status(e)}};}
fn u32 denied(Result<h::Admission,h::Error> r){return switch(r){case .ok(_):{assert(false);0}case .err(e):{h::status(e)}};}
fn void unchanged(ref h::Table a,ref h::Table b){
    assert(a.next_admission==b.next_admission);var usize i=0;
    while(i<h::capacity()){let h::Slot x=a.slots[i];let h::Slot y=b.slots[i];
        assert(x.generation==y.generation && x.kind==y.kind && x.engine==y.engine &&
            x.thread==y.thread && x.lifetime==y.lifetime && x.busy==y.busy && x.object==y.object);i+=1;
    }
}
fn usize program(ref mut h::Table t,usize e,usize object){
    let h::Admission a=admitted(h::enter(t,e,h::engine_kind(),e,who()));
    let usize child=ok(h::insert_child(t,a,h::program_kind(),object,who()));
    let usize done=ok(h::leave(t,a,who()));return child;
}
fn usize instance(ref mut h::Table t,usize e,usize p,usize object){
    let h::Admission a=admitted(h::enter(t,p,h::program_kind(),e,who()));
    let usize child=ok(h::insert_child(t,a,h::instance_kind(),object,who()));
    let usize done=ok(h::leave(t,a,who()));return child;
}
fn usize remove_row(ref mut h::Table t,usize target,u32 kind,usize engine){
    let h::Admission a=admitted(h::enter(t,target,kind,engine,who()));return ok(h::remove(t,a,who()));
}

@test fn void typed_wire_bounds_and_argument_rollback(){
    var h::Table t=h::empty();let usize e=ok(h::create_engine(ref mut t,who(),81));
    assert(e==4294967297 && ok(h::slot_index(e))==0);
    let h::Table before=t;
    let usize[8] malformed=[0,1,4294967296,4294967361,8589934591,
        18446744073709551615,18446744069414584320,18446744069414584385];
    var usize i=0;while(i<malformed.len){
        assert(denied(h::enter(ref mut t,malformed[i],1,e,who()))==2);i+=1;
    }
    assert(denied(h::enter(ref mut t,e,2,e,who()))==2);
    assert(denied(h::enter(ref mut t,e,3,e,who()))==2);
    assert(denied(h::enter(ref mut t,e,0,e,who()))==1);
    assert(denied(h::enter(ref mut t,e,4,e,who()))==1);
    assert(denied(h::enter(ref mut t,e,1,0,who()))==2);
    assert(error(h::create_engine(ref mut t,who(),0))==1);
    assert(error(h::create_engine(ref mut t,h::Identity{.thread=0,.lifetime=1},1))==1);
    assert(error(h::create_engine(ref mut t,h::Identity{.thread=1,.lifetime=0},1))==1);
    unchanged(ref t,ref before);
}

@test fn void stale_kind_reuse_never_revives(){
    var h::Table t=h::empty();let usize e=ok(h::create_engine(ref mut t,who(),1));
    let usize p=program(ref mut t,e,2);assert(remove_row(ref mut t,p,2,e)==2);
    let usize q=program(ref mut t,e,3);assert(q==p+4294967296);
    let usize inst=instance(ref mut t,e,q,4);
    let h::Table before=t;
    assert(denied(h::enter(ref mut t,p,2,e,who()))==2);
    assert(denied(h::enter(ref mut t,q,3,e,who()))==2);
    assert(denied(h::enter(ref mut t,inst,2,e,who()))==2);
    assert(denied(h::enter_instance(ref mut t,q,who()))==2);
    unchanged(ref t,ref before);
    let h::Admission a=admitted(h::enter_instance(ref mut t,inst,who()));
    assert(a.engine==e && a.object==4 && a.kind==3);assert(ok(h::remove(ref mut t,a,who()))==4);
    assert(remove_row(ref mut t,q,2,e)==3);assert(remove_row(ref mut t,e,1,e)==1);
    let usize replacement=ok(h::create_engine(ref mut t,who(),5));assert(replacement==e+4294967296);
    assert(denied(h::enter(ref mut t,e,1,e,who()))==2);
    assert(denied(h::enter_instance(ref mut t,inst,who()))==2);
}

@test fn void engine_association_and_owner_lifetime(){
    var h::Table t=h::empty();let usize e=ok(h::create_engine(ref mut t,who(),1));
    let usize other=ok(h::create_engine(ref mut t,who(),2));
    let usize p=program(ref mut t,e,3);let usize inst=instance(ref mut t,e,p,4);
    let h::Table before=t;
    assert(denied(h::enter(ref mut t,p,2,other,who()))==2);
    assert(denied(h::enter(ref mut t,inst,3,other,who()))==2);
    assert(denied(h::enter(ref mut t,e,1,other,who()))==2);
    let h::Identity foreign=h::Identity{.thread=42,.lifetime=101};
    let h::Identity recycled=h::Identity{.thread=41,.lifetime=102};
    assert(denied(h::enter(ref mut t,e,1,e,foreign))==10);
    assert(denied(h::enter(ref mut t,p,2,e,recycled))==10);
    assert(denied(h::enter_instance(ref mut t,inst,recycled))==10);
    assert(denied(h::enter_instance(ref mut t,inst,foreign))==10);
    assert(denied(h::enter(ref mut t,e,1,e,h::Identity{.thread=0,.lifetime=101}))==1);
    unchanged(ref t,ref before);
    // A stale Engine generation cannot authenticate a still-live child.
    assert(denied(h::enter(ref mut t,p,2,e+4294967296,who()))==2);
    unchanged(ref t,ref before);
}

@test fn void busy_reentry_and_independent_engines(){
    var h::Table t=h::empty();let usize e=ok(h::create_engine(ref mut t,who(),1));
    let usize other=ok(h::create_engine(ref mut t,who(),2));
    let usize p=program(ref mut t,e,3);let usize inst=instance(ref mut t,e,p,4);
    let h::Admission a=admitted(h::enter_instance(ref mut t,inst,who()));
    let h::Table before=t;
    assert(denied(h::enter(ref mut t,e,1,e,who()))==3);
    assert(denied(h::enter(ref mut t,p,2,e,who()))==3);
    assert(denied(h::enter_instance(ref mut t,inst,who()))==3);
    assert(denied(h::enter_instance(ref mut t,inst,h::Identity{.thread=41,.lifetime=102}))==10);
    assert(denied(h::enter(ref mut t,p,3,e,who()))==2);
    unchanged(ref t,ref before);
    let h::Admission b=admitted(h::enter(ref mut t,other,1,other,who()));
    let usize finished=ok(h::leave(ref mut t,b,who()));
    assert(t.slots[ok(h::slot_index(e))].busy==a.epoch);
    let usize done=ok(h::leave(ref mut t,a,who()));
    let h::Admission retry=admitted(h::enter(ref mut t,e,1,e,who()));
    let usize retried=ok(h::leave(ref mut t,retry,who()));
}

@test fn void admission_rollback_stale_receipts_and_payload(){
    var h::Table t=h::empty();let usize e=ok(h::create_engine(ref mut t,who(),1));
    let h::Admission a=admitted(h::enter(ref mut t,e,1,e,who()));
    let h::Table before=t;
    assert(error(h::insert_child(ref mut t,a,2,0,who()))==1);
    assert(error(h::insert_child(ref mut t,a,3,2,who()))==1);
    assert(error(h::insert_child(ref mut t,a,1,2,who()))==1);
    let h::Identity foreign=h::Identity{.thread=99,.lifetime=101};
    assert(error(h::insert_child(ref mut t,a,2,2,foreign))==10);
    assert(error(h::leave(ref mut t,a,foreign))==10);
    assert(error(h::remove(ref mut t,a,foreign))==10);
    var h::Admission forged=a;forged.object=90;
    assert(error(h::leave(ref mut t,forged,who()))==7);
    forged=a;forged.epoch=0;assert(error(h::remove(ref mut t,forged,who()))==7);
    unchanged(ref t,ref before);
    // Simulate native OOM before publication: finally leave, no slot issued.
    let usize rollback=ok(h::leave(ref mut t,a,who()));
    let h::Table idle=t;assert(error(h::leave(ref mut t,a,who()))==7);unchanged(ref t,ref idle);
    let h::Admission b=admitted(h::enter(ref mut t,e,1,e,who()));assert(b.epoch!=a.epoch);
    let h::Table second=t;
    assert(error(h::leave(ref mut t,a,who()))==7);
    assert(error(h::insert_child(ref mut t,a,2,2,who()))==7);
    assert(error(h::remove(ref mut t,a,who()))==7);
    unchanged(ref t,ref second);
    let usize p=ok(h::insert_child(ref mut t,b,2,2,who()));assert(p==4294967298);
    let usize done=ok(h::leave(ref mut t,b,who()));
}

@test fn void exact_capacity_and_failed_insert_rollback(){
    var h::Table t=h::empty();let usize e=ok(h::create_engine(ref mut t,who(),1));
    let h::Admission a=admitted(h::enter(ref mut t,e,1,e,who()));
    var usize i=1;var usize last=0;while(i<h::capacity()){
        last=ok(h::insert_child(ref mut t,a,2,i+1,who()));i+=1;
    }
    assert(last==4294967360 && ok(h::slot_index(last))==63);
    let h::Table full=t;
    assert(error(h::insert_child(ref mut t,a,2,100,who()))==8);
    assert(error(h::create_engine(ref mut t,who(),100))==8);unchanged(ref t,ref full);
    let usize done=ok(h::leave(ref mut t,a,who()));
    assert(remove_row(ref mut t,last,2,e)==64);
    let usize reused=program(ref mut t,e,100);assert(reused==last+4294967296);
    assert(denied(h::enter(ref mut t,last,2,e,who()))==2);
}

@test fn void generation_max_engine_retirement_and_tombstone(){
    var h::Table t=h::empty();t.slots[0].generation=4294967295;
    let usize e=ok(h::create_engine(ref mut t,who(),1));
    assert(e==18446744069414584321 && e/4294967296==h::generation_max());
    assert(remove_row(ref mut t,e,1,e)==1);
    assert(t.slots[0].generation==0 && t.slots[0].kind==0);
    let usize fresh=ok(h::create_engine(ref mut t,who(),2));assert(fresh==4294967298);
    let h::Table before=t;
    assert(denied(h::enter(ref mut t,e,1,e,who()))==2);
    assert(denied(h::enter(ref mut t,4294967297,1,4294967297,who()))==2);
    unchanged(ref t,ref before);
    assert(remove_row(ref mut t,fresh,1,fresh)==2);
    let usize again=ok(h::create_engine(ref mut t,who(),3));assert(again==8589934594);
    assert(t.slots[0].generation==0);
}

@test fn void retired_children_consume_capacity_permanently(){
    var h::Table t=h::empty();let usize e=ok(h::create_engine(ref mut t,who(),1));
    t.slots[1].generation=4294967295;
    let usize p=program(ref mut t,e,2);assert(p==18446744069414584322);
    assert(remove_row(ref mut t,p,2,e)==2);assert(t.slots[1].generation==0);
    let h::Admission a=admitted(h::enter(ref mut t,e,1,e,who()));
    var usize i=2;while(i<h::capacity()){
        let usize child=ok(h::insert_child(ref mut t,a,2,i+1,who()));i+=1;
    }
    let h::Table full=t;assert(error(h::insert_child(ref mut t,a,2,99,who()))==8);
    unchanged(ref t,ref full);let usize done=ok(h::leave(ref mut t,a,who()));
    assert(denied(h::enter(ref mut t,p,2,e,who()))==2);
    assert(t.slots[1].generation==0 && t.slots[1].kind==0);
}

@test fn void engine_removal_refuses_children_and_consumes_admission(){
    var h::Table t=h::empty();let usize e=ok(h::create_engine(ref mut t,who(),11));
    let usize p=program(ref mut t,e,12);let usize inst=instance(ref mut t,e,p,13);
    let h::Admission a=admitted(h::enter(ref mut t,e,1,e,who()));
    let h::Table before=t;assert(error(h::remove(ref mut t,a,who()))==3);unchanged(ref t,ref before);
    let usize done=ok(h::leave(ref mut t,a,who()));
    assert(remove_row(ref mut t,inst,3,e)==13);assert(remove_row(ref mut t,p,2,e)==12);
    let h::Admission b=admitted(h::enter(ref mut t,e,1,e,who()));
    assert(ok(h::remove(ref mut t,b,who()))==11);
    let h::Table removed=t;assert(error(h::remove(ref mut t,b,who()))==2);
    assert(error(h::leave(ref mut t,b,who()))==2);unchanged(ref t,ref removed);
    let usize replacement=ok(h::create_engine(ref mut t,who(),14));
    assert(replacement==e+4294967296);
    assert(error(h::insert_child(ref mut t,b,2,15,who()))==2);
}

@test fn void admission_identity_exhaustion_is_fail_closed(){
    var h::Table t=h::empty();let usize e=ok(h::create_engine(ref mut t,who(),1));
    t.next_admission=18446744073709551615;
    let h::Admission a=admitted(h::enter(ref mut t,e,1,e,who()));
    assert(a.epoch==18446744073709551615 && t.next_admission==0);
    let usize done=ok(h::leave(ref mut t,a,who()));let h::Table before=t;
    assert(denied(h::enter(ref mut t,e,1,e,who()))==8);unchanged(ref t,ref before);
    assert(error(h::leave(ref mut t,a,who()))==7);unchanged(ref t,ref before);
}
