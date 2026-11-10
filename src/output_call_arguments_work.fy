module output_call_arguments_work;
import ir as ir;
import errors as errors;
import register_set as registers;
import static_ir as statics;
import struct_layout as layouts;
import output_record_copy_work as records;
import copy_ir as copying;
import slice_parameters as slices;
import metadata_budget as budget;

// Canonical CALL operands after partition/catalog proof. The parent freezes the
// Program, scalar definitions, Sites, live word and exact completed layout Plan.
// Record arguments descend into the resumable pair of nominal walks; other
// arguments visit one fixed row per stage. Typed-value CALLs are a separate ABI.
pub struct State {
    records::State record; usize target; usize map; usize caller; usize live; usize pc;
    usize index; usize writers; usize writer_roots; u8 phase; bool static_mode; bool active; bool done;
}
pub fn State empty(){return State{.record=records::empty(),.target=0,.map=0,.caller=0,.live=0,.pc=0,
    .index=0,.writers=0,.writer_roots=0,.phase=0,.static_mode=false,.active=false,.done=false};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
pub fn Result<usize,errors::Error> begin(ref mut State w,usize target,usize map,usize caller,usize live,usize pc,bool static_mode){
    if(w.active){return .err(invalid(pc));}
    w.target=target;w.map=map;w.caller=caller;w.live=live;w.pc=pc;w.static_mode=static_mode;
    w.index=0;w.writers=0;w.writer_roots=0;w.phase=0;w.active=true;w.done=false;return .ok(0);
}
pub fn Result<bool,errors::Error> advance(ref ir::Program p,ref layouts::Plan plan,ref statics::Sites sites,
    ref registers::Set defined,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(!w.active || w.phase>1){return .err(invalid(w.pc));}
    if(w.phase==1){
        let bool done=records::advance(p,plan,ref mut w.record,meter)?;
        if(done){let copying::Plan copy=records::prepared(ref w.record)?;let usize one=1;
            if(p.records.mutable[copy.destination] || p.records.mutable[copy.source] || (w.live&(one<<(16+copy.source)))==0){w.active=false;return .err(invalid(w.pc));}
            w.phase=0;w.index+=1;
        }return .ok(false);
    }
    if(!budget::admit(meter,4096,w.pc)?){return .ok(false);}
    let usize arg=w.index;let usize pc=w.pc;let usize target=w.target;let usize caller=w.caller;let usize map=w.map;
    if(arg==8){w.active=false;w.done=true;return .ok(true);}
    let usize count=p.call_arities[map] as usize;let usize source=p.call_args[map*8+arg] as usize;
    if(arg>=count){if(source!=0){w.active=false;return .err(invalid(pc));}w.index+=1;return .ok(false);}
    let usize parameter=p.register_starts[target]+arg;let usize encoded=p.array_parameters[parameter] as usize;
    if(w.static_mode && sites.parameters[parameter]!=0){
        if(sites.parameters[parameter]==3 && source>=160 && source<176){let usize checked=slices::shared_byte(p,source,caller,w.live,pc)?;}
        w.index+=1;return .ok(false);
    }
    if(p.slice_parameters[parameter]!=0){
        let usize checked=slices::argument(p,parameter,source,caller,w.live,pc)?;
        if(ir::exclusive(p,checked)){let usize one=1;let usize bit=one<<checked;let usize root=p.slice_roots[checked] as usize;
            let usize root_bit=if(root==0){0}else{one<<(root-1)};
            if((w.writers&bit)!=0 || (w.writer_roots&root_bit)!=0){w.active=false;return .err(invalid(pc));}
            w.writers|=bit;w.writer_roots|=root_bit;
        }
    }else if(p.record_parameters[parameter]!=0){
        let usize formal=p.record_parameters[parameter] as usize;
        if(formal>p.records.count || source<144 || source>=160 || encoded!=0){w.active=false;return .err(invalid(pc));}
        let records::Arguments args=records::Arguments{.destination=formal-1,.source=source-144,
            .destination_function=target,.source_function=caller,.fresh=true,.same_frame=false,.subtree=false,
            .nominal=0,.destination_leaf=0,.source_leaf=0,.pc=pc};
        let usize started=records::begin(ref mut w.record,args)?;w.phase=1;return .ok(false);
    }else if(encoded!=0){let copying::Plan checked=copying::argument(p,target,parameter,source,caller,w.live,pc)?;}
    else if(source<p.register_starts[caller] || source>=p.register_ends[caller] || p.slots[source] ||
        p.array_parameters[source]!=0 || p.record_parameters[source]!=0 || p.slice_parameters[source]!=0 ||
        !registers::contains(defined,source) || p.types[source]!=p.types[parameter]){w.active=false;return .err(invalid(pc));}
    w.index+=1;return .ok(false);
}
