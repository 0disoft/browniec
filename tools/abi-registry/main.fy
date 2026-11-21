module main;
import abi_handles as h;
// Explicit private transport retention root. Never called by the coordinator.
fn i32 main(){
    let h::Slot fresh=h::Slot{.generation=0,.kind=0,.engine=0,.thread=0,.lifetime=0,.busy=0,.object=0,.children=0};
    var h::Slot[3] slots=[fresh;3];
    var h::Index table=h::empty(h::capacity());
    let h::Identity caller=h::Identity{.thread=1,.lifetime=1};
    let usize engine=switch(h::create_engine(ref mut slots,ref mut table,caller,1)){
        case .ok(v):{v}case .err(e):{if(h::status(e)==0){return 0;}return 1;}
    };
    let h::Admission a=switch(h::enter(ref mut slots,ref mut table,engine,h::engine_kind(),engine,caller)){
        case .ok(v):{v}case .err(e):{if(h::status(e)==0){return 0;}return 1;}
    };
    let usize program=switch(h::insert_child(ref mut slots,ref mut table,a,h::program_kind(),2,caller)){
        case .ok(v):{v}case .err(e):{if(h::status(e)==0){return 0;}return 1;}
    };
    let usize left=switch(h::leave(ref mut slots,a,caller)){
        case .ok(v):{v}case .err(e):{if(h::status(e)==0){return 0;}return 1;}
    };
    let bool missing=switch(h::enter_instance(ref mut slots,ref mut table,program,caller)){
        case .ok(_):{false}case .err(e):{h::status(e)==2}
    };
    let h::Admission b=switch(h::enter(ref mut slots,ref mut table,program,h::program_kind(),engine,caller)){
        case .ok(v):{v}case .err(e):{if(h::status(e)==0){return 0;}return 1;}
    };
    let usize removed=switch(h::remove(ref mut slots,ref mut table,b,caller)){
        case .ok(v):{v}case .err(e):{if(h::status(e)==0){return 0;}return 1;}
    };
    let usize index=switch(h::slot_index(engine)){
        case .ok(v):{v}case .err(_):{return 1;}
    };
    if(h::capacity()!=65536 || h::instance_kind()!=3 || h::generation_max()!=4294967295 ||
        !missing || index!=0 || removed!=2 || left==0){return 1;}
    return 0;
}
