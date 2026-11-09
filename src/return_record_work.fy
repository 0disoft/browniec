module return_record_work;
import struct_layout as layouts;
import struct_layout_work as catalogs;
import metadata_budget as budget;
import scalar_codec as codec;
import errors as errors;

// Invocation-private proof/measurement. The parent pins the exact catalog and
// nominal until abort/publication. No payload or owner is accessed here.
pub struct State {
    catalogs::State catalog; u8[128] mask;
    usize[16] records; usize[16] fields; usize[16] bases;
    usize nominal; usize size; usize alignment; usize scalar_bytes; usize bools;
    usize depth; usize phase; bool active; bool done;
}
pub fn State empty(){return State{.catalog=catalogs::empty(),.mask=[0;128],
    .records=[0;16],.fields=[0;16],.bases=[0;16],.nominal=0,.size=0,.alignment=0,
    .scalar_bytes=0,.bools=0,.depth=0,.phase=0,.active=false,.done=false};}
pub fn Result<usize,errors::Error> begin(ref mut State w,usize nominal){
    if(w.active){return .err(errors::make(5,0));}
    w.nominal=nominal;w.size=0;w.alignment=0;w.scalar_bytes=0;w.bools=0;
    w.depth=0;w.phase=0;w.active=true;w.done=false;
    let usize begun=switch(catalogs::begin(ref mut w.catalog,18446744073709551615)){
        case .ok(v):{v}case .err(_):{w.active=false;return .err(errors::make(5,0));}};
    return .ok(0);
}
pub fn usize measured(ref State w){return 128+w.size+w.scalar_bytes+w.bools;}
fn Result<usize,errors::Error> selected(ref mut State w){
    let ref catalogs::State c=ref w.catalog;let ref layouts::Plan p=ref c.plan;
    if(w.nominal>=p.count){return .err(errors::make(5,0));}
    if(p.bytes[w.nominal]>128){return .err(errors::make(13,0));}
    let usize size=p.bytes[w.nominal];let usize alignment=p.alignments[w.nominal];
    let usize nominal=w.nominal;w.size=size;w.alignment=alignment;
    var usize i=0;while(i<128){w.mask[i]=0;i+=1;}
    w.records[0]=nominal;w.fields[0]=0;w.bases[0]=0;w.depth=1;w.phase=2;return .ok(0);
}
fn Result<usize,errors::Error> leaves(ref mut State w,ref layouts::Catalog c){
    // At most sixteen DFS edges per stage, including shared/nested records.
    // Each scalar expands at most eight mask bytes; no whole-tree iterator.
    var usize steps=0;while(steps<16 && w.depth!=0){steps+=1;
        let usize level=w.depth-1;let usize r=w.records[level];let usize f=w.fields[level];
        if(f==c.fields[r] as usize){w.depth-=1;}
        else{w.fields[level]+=1;let usize slot=r*16+f;
            let ref catalogs::State checked=ref w.catalog;let ref layouts::Plan p=ref checked.plan;
            let usize offset=w.bases[level]+p.offsets[slot];
            if(c.kinds[slot]==0){let u8 tag=c.types[slot];let usize width=codec::width(tag);
                if(offset>w.size || width>w.size-offset){return .err(errors::make(5,0));}
                var usize byte=0;while(byte<width){w.mask[offset+byte]=if(tag==2){2}else{1};byte+=1;}
                w.scalar_bytes+=width;if(tag==2){w.bools+=1;}
            }else{if(w.depth>=16){return .err(errors::make(5,0));}
                let usize at=w.depth;w.records[at]=c.types[slot] as usize;
                w.fields[at]=0;w.bases[at]=offset;w.depth+=1;}
        }
    }
    if(w.depth==0){w.active=false;w.done=true;w.phase=3;}return .ok(0);
}
pub fn Result<bool,errors::Error> advance(ref mut State w,ref layouts::Catalog c,ref mut budget::State allowance){
    if(!w.active || w.done || w.phase>2){return .err(errors::make(5,0));}
    if(allowance.last!=0){return .ok(false);}
    if(w.phase==0){
        switch(catalogs::advance(ref mut w.catalog,c,allowance)){
            case .ok(done):{if(done){w.phase=1;}}
            case .err(_):{w.active=false;return .err(errors::make(5,0));}
        };return .ok(false);
    }
    if(!budget::admit(allowance,4096,0)?){return .ok(false);}
    let Result<usize,errors::Error> result=if(w.phase==1){selected(w)}else{leaves(w,c)};
    switch(result){case .ok(_):{}case .err(e):{w.active=false;return .err(e);}};
    return .ok(w.done);
}
