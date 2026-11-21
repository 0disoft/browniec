module output_record_metadata_work;

import errors as errors;
import runtime_clock as clock;
import metadata_budget as budget;
import struct_layout as layouts;
import struct_layout_work as catalog_work;
import struct_meta as metadata;

// Bounded preparation for entry-owned record metadata. The caller pins the
// exact immutable Catalog until completion. Layout validation/planning reuses
// the independently bounded catalog kernel; this module only flattens the
// proved layout into the existing sixteen binding rows in declaration order.
pub struct State {
    catalog_work::State layout;
    metadata::Prepared result;
    usize[16] records;
    usize[16] fields;
    usize depth;
    usize binding;
    usize catalog_count;
    usize layout_count;
    u8 phase;
    bool active;
    bool done;
}

pub fn State empty(){
    return State{
        .layout=catalog_work::empty(),
        .result=metadata::Prepared{.leaves=[0;16],.tags=[0;2048]},
        .records=[0;16],.fields=[0;16],.depth=0,.binding=0,
        .catalog_count=0,.layout_count=0,
        .phase=0,.active=false,.done=false};
}

fn errors::Error invalid(){return errors::make(5,0);}

pub fn Result<usize,errors::Error> begin(ref mut State w,ref metadata::Catalog catalog){
    if(w.active){return .err(invalid());}
    switch(catalog_work::begin(ref mut w.layout,18446744073709551615)){
        case .ok(_):{}case .err(_):{return .err(invalid());}
    };
    w.result=metadata::Prepared{.leaves=[0;16],.tags=[0;2048]};
    var usize i=0;while(i<16){w.records[i]=0;w.fields[i]=0;i+=1;}
    w.depth=0;w.binding=0;w.catalog_count=catalog.count;
    w.layout_count=catalog.layouts.count;
    w.phase=0;w.active=true;w.done=false;return .ok(0);
}

// One fresh stage either advances the resumable layout planner or performs at
// most sixteen binding traversal visits. No allowance is retained across calls.
fn Result<usize,errors::Error> flatten(ref mut State w,ref metadata::Catalog catalog){
    if(catalog.count!=w.catalog_count || catalog.layouts.count!=w.layout_count){return .err(invalid());}
    var usize visits=0;
    while(visits<16){
        visits+=1;
        let usize id=w.binding;
        if(id>=16){w.phase=2;w.active=false;w.done=true;return .ok(visits);}
        let usize root=catalog.records[id] as usize;
        if(w.depth==0){
            if(id>=catalog.count){
                if(root!=0 || catalog.mutable[id]){return .err(invalid());}
                w.binding=id+1;continue;
            }
            let ref layouts::Plan plan=ref w.layout.plan;
            if(root>=plan.count || plan.bytes[root]>128){return .err(invalid());}
            w.records[0]=root;w.fields[0]=0;w.depth=1;continue;
        }
        let usize level=w.depth-1;
        let usize record=w.records[level];
        let usize field=w.fields[level];
        if(field>=catalog.layouts.fields[record] as usize){
            w.depth-=1;
            if(w.depth==0){w.binding=id+1;}
            continue;
        }
        w.fields[level]+=1;
        let usize slot=record*16+field;
        if(catalog.layouts.kinds[slot]==0){
            let usize leaf=w.result.leaves[id];
            if(leaf>=128){return .err(invalid());}
            w.result.tags[id*128+leaf]=catalog.layouts.types[slot];
            w.result.leaves[id]+=1;
        }else if(catalog.layouts.kinds[slot]==1){
            if(w.depth>=16){return .err(invalid());}
            let usize child=catalog.layouts.types[slot] as usize;
            if(child>=w.layout.plan.count){return .err(invalid());}
            let usize next=w.depth;
            w.records[next]=child;w.fields[next]=0;w.depth=next+1;
        }else{return .err(invalid());}
    }
    return .ok(visits);
}

pub fn Result<bool,errors::Error> advance(ref mut State w,ref metadata::Catalog catalog,
    ref mut budget::State allowance){
    if(!w.active || w.done || w.phase>2){return .err(invalid());}
    if(catalog.count!=w.catalog_count || catalog.layouts.count!=w.layout_count){return .err(invalid());}
    if(w.phase==0){
        // These are the raw prepare's first two checks. They occur in the same
        // first fresh stage, before the resumable layout kernel reads a row.
        if(allowance.last!=0){return .ok(false);}
        if((catalog.layouts.count==0 && catalog.count!=0) ||
            (catalog.layouts.count!=0 && catalog.count>16)){
            let bool admitted=switch(budget::admit(allowance,4096,0)){
                case .ok(v):{v}case .err(_):{return .err(invalid());}
            };
            if(!admitted){return .ok(false);}
            w.active=false;return .err(invalid());
        }
        let bool finished=switch(catalog_work::advance(ref mut w.layout,ref catalog.layouts,allowance)){
            case .ok(v):{v}case .err(_):{w.active=false;return .err(invalid());}
        };
        if(finished){w.phase=1;}
        return .ok(false);
    }
    if(allowance.last!=0){return .ok(false);}
    let bool admitted=switch(budget::admit(allowance,4096,0)){
        case .ok(v):{v}case .err(_):{return .err(invalid());}
    };
    if(!admitted){return .ok(false);}
    switch(flatten(w,catalog)){
        case .ok(_):{}case .err(_):{w.active=false;return .err(invalid());}
    };
    return .ok(w.done);
}

// Copyable fixed result, published only by the owning parent after success.
pub fn Result<metadata::Prepared,errors::Error> prepared(ref State w){
    if(w.active || !w.done || w.phase!=2){return .err(invalid());}
    return .ok(w.result);
}

// Timed ordinary verification drains the same catalog and binding stages.
pub fn Result<metadata::Prepared,errors::Error> prepare_until(ref metadata::Catalog catalog,usize deadline){
    if(deadline==0){return metadata::prepare(catalog);}
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    var State w=empty();var budget::State allowance=budget::empty();
    let usize started=begin(ref mut w,catalog)?;
    while(!w.done){
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        let usize ready=budget::reset(ref mut allowance,0)?;
        let bool done=advance(ref mut w,catalog,ref mut allowance)?;
    }
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    return prepared(ref w);
}
