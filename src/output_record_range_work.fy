module output_record_range_work;

import errors as errors;
import metadata_budget as budget;
import struct_layout as layouts;

// Prepared-only record range analysis. The caller pins one catalog and one
// independently completed Plan; this kernel never plans or revalidates the
// catalog. Each advance performs at most sixteen depth-first visits in its own
// fresh 4096-unit allowance. The state may be reused for serial offset callers.
pub struct State {
    usize[16] records;
    usize[16] fields;
    usize[16] bases;
    usize root;
    usize nominal;
    usize ordinal;
    usize leaf;
    usize count;
    usize visits;
    usize depth;
    pub usize output;
    u8 mode;
    bool prepared;
    bool active;
    bool done;
}

pub fn State empty(){
    return State{
        .records=[0;16],.fields=[0;16],.bases=[0;16],
        .root=0,.nominal=0,.ordinal=0,.leaf=0,.count=0,.visits=0,.depth=0,.output=0,
        .mode=0,.prepared=false,.active=false,.done=false};
}

fn errors::Error invalid(){return errors::make(5,0);}
fn bool plan_matches(ref layouts::Catalog catalog,ref layouts::Plan plan){
    return plan.count==catalog.count && plan.count<=32;
}

fn void reset(ref mut State w,u8 mode){
    var usize i=0;
    while(i<16){w.records[i]=0;w.fields[i]=0;w.bases[i]=0;i+=1;}
    w.root=0;w.nominal=0;w.ordinal=0;w.leaf=0;w.count=0;w.visits=0;w.depth=0;w.output=0;
    w.mode=mode;w.prepared=false;w.active=true;w.done=false;
}

pub fn Result<usize,errors::Error> begin_offset(ref mut State w,
    usize root,usize nominal,usize ordinal){
    if(w.active){return .err(invalid());}
    reset(w,1);w.root=root;w.nominal=nominal;w.ordinal=ordinal;
    return .ok(0);
}

pub fn Result<usize,errors::Error> begin_leaves(ref mut State w,usize nominal){
    if(w.active){return .err(invalid());}
    reset(w,2);w.nominal=nominal;
    return .ok(0);
}

fn Result<usize,errors::Error> prepare_offset(ref mut State w,ref layouts::Plan plan){
    if(w.root>=plan.count || w.nominal>=plan.count || w.ordinal>=128 ||
        plan.bytes[w.root]>128 || plan.bytes[w.nominal]>128){return .err(invalid());}
    if(w.root==w.nominal && w.ordinal==0){
        w.output=0;w.prepared=true;w.active=false;w.done=true;return .ok(0);
    }
    let usize first=w.root;w.records[0]=first;w.fields[0]=0;w.bases[0]=0;w.depth=1;w.leaf=0;
    w.prepared=true;
    return .ok(0);
}

fn Result<usize,errors::Error> prepare_leaves(ref mut State w,ref layouts::Plan plan){
    if(w.nominal>=plan.count || plan.bytes[w.nominal]>128){return .err(invalid());}
    let usize first=w.nominal;w.prepared=true;w.records[0]=first;w.fields[0]=0;w.depth=1;w.count=0;
    return .ok(0);
}

// Validate the currently read node before indexing it; both inputs stay pinned
// by the owning caller, so this checks shape only and never replans.
fn Result<usize,errors::Error> node(ref layouts::Catalog catalog,usize record){
    if(record>=catalog.count || record>=32){return .err(invalid());}
    let usize fields=catalog.fields[record] as usize;
    if(fields==0 || fields>16){return .err(invalid());}
    return .ok(fields);
}

fn Result<usize,errors::Error> offset_visit(ref mut State w,
    ref layouts::Catalog catalog,ref layouts::Plan plan){
    if(w.visits>=4096){return .err(invalid());}
    w.visits+=1;
    if(w.depth==0 || w.depth>16){return .err(invalid());}
    let usize level=w.depth-1;
    let usize record=w.records[level];
    let usize field_count=node(catalog,record)?;
    let usize field=w.fields[level];
    if(field>=field_count){w.depth=level;return .ok(0);}
    let usize slot=record*16+field;
    w.fields[level]=field+1;
    if(catalog.kinds[slot]==0){
        if(catalog.types[slot]==0 || plan.offsets[slot]>=plan.bytes[record]){return .err(invalid());}
        w.leaf+=1;return .ok(0);
    }
    if(catalog.kinds[slot]!=1){return .err(invalid());}

    let usize base_at=w.bases[level];
    let usize field_offset=plan.offsets[slot];
    if(field_offset>128-base_at){return .err(invalid());}
    let usize base=base_at+field_offset;
    let usize child=catalog.types[slot] as usize;
    if(child>=catalog.count || child>=32){return .err(invalid());}
    if(child==w.nominal && w.leaf==w.ordinal){
        let usize root_bytes=plan.bytes[w.root];
        let usize nominal_bytes=plan.bytes[w.nominal];
        if(base>root_bytes || nominal_bytes>root_bytes-base){return .err(invalid());}
        w.output=base;w.active=false;w.done=true;return .ok(0);
    }
    if(w.depth>=16){return .err(invalid());}
    let usize next=w.depth;
    w.records[next]=child;w.fields[next]=0;w.bases[next]=base;w.depth=next+1;
    return .ok(0);
}

fn Result<usize,errors::Error> leaves_visit(ref mut State w,ref layouts::Catalog catalog){
    if(w.visits>=4096){return .err(invalid());}
    w.visits+=1;
    if(w.depth==0 || w.depth>16){return .err(invalid());}
    let usize level=w.depth-1;
    let usize record=w.records[level];
    let usize field_count=node(catalog,record)?;
    let usize field=w.fields[level];
    if(field>=field_count){w.depth=level;return .ok(0);}
    let usize slot=record*16+field;
    w.fields[level]=field+1;
    if(catalog.kinds[slot]==0){
        if(catalog.types[slot]==0 || w.count>=128){return .err(invalid());}
        w.count+=1;return .ok(0);
    }
    if(catalog.kinds[slot]!=1){return .err(invalid());}
    if(w.depth>=16){return .err(invalid());}
    let usize child=catalog.types[slot] as usize;
    if(child>=catalog.count || child>=32){return .err(invalid());}
    let usize next=w.depth;
    w.records[next]=child;w.fields[next]=0;w.depth=next+1;
    return .ok(0);
}

pub fn Result<bool,errors::Error> advance(ref mut State w,ref layouts::Catalog catalog,ref layouts::Plan plan,
    ref mut budget::State allowance){
    if(allowance.last!=0){return .ok(false);}
    if(w.done){return .ok(true);}
    if(!w.active || w.mode==0 || w.mode>2){return .err(invalid());}
    let bool admitted=switch(budget::admit(allowance,4096,0)){
        case .ok(v):{v}case .err(_):{return .err(invalid());}
    };
    if(!admitted){return .ok(false);}
    if(!plan_matches(catalog,plan)){w.active=false;return .err(invalid());}
    if(w.mode==1 && !w.prepared){
        let Result<usize,errors::Error> ready=prepare_offset(w,plan);
        switch(ready){case .ok(_):{}case .err(_):{w.active=false;return .err(invalid());}};
        if(w.done){return .ok(true);}
    }else if(w.mode==2 && !w.prepared){
        let Result<usize,errors::Error> ready=prepare_leaves(w,plan);
        switch(ready){case .ok(_):{}case .err(_):{w.active=false;return .err(invalid());}};
    }

    var usize visits=0;
    while(visits<16){
        let Result<usize,errors::Error> checked=if(w.mode==1){offset_visit(w,catalog,plan)}
            else{leaves_visit(w,catalog)};
        switch(checked){case .ok(_):{}case .err(_):{w.active=false;return .err(invalid());}};
        visits+=1;
        if(w.done){return .ok(true);}
        if(w.depth==0){
            if(w.mode==1){w.active=false;return .err(invalid());}
            w.output=w.count;w.active=false;w.done=true;return .ok(true);
        }
    }
    return .ok(false);
}
