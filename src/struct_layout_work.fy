module struct_layout_work;
import struct_layout as layouts;
import array_layout as arrays;
import metadata_budget as budget;

// Invocation-private builder. Pin the exact catalog/limit until done or abort.
// A stage initializes fixed scratch, inspects sixteen catalog slots/dependency
// edges, or lays out one node (at most sixteen fields). No whole-catalog helper.
pub struct State {
    layouts::Plan plan; usize[32] records; usize[32] fields; bool[32] visiting;
    usize root; usize depth; usize checked; usize limit; u8 phase; bool active; bool done;
}
pub fn State empty(){return State{.plan=layouts::Plan{.count=0,.bytes=[0;32],.alignments=[0;32],.depths=[0;32],.offsets=[0;512]},
    .records=[0;32],.fields=[0;32],.visiting=[false;32],.root=0,.depth=0,.checked=0,.limit=0,.phase=0,.active=false,.done=false};}
pub fn Result<usize,layouts::Error> begin(ref mut State w,usize limit){
    if(w.active){return .err(.Metadata);}w.limit=limit;w.phase=0;w.root=0;w.depth=0;w.checked=0;w.active=true;w.done=false;return .ok(0);
}
fn usize width(u8 tag){return switch(arrays::scalar(tag,1)){case .ok(v):{v.bytes}case .err(_):{0}};}
fn Result<usize,layouts::Error> aligned(usize value,usize alignment){
    let usize r=value%alignment;let usize padding=if(r==0){0}else{alignment-r};
    if(padding>18446744073709551615-value){return .err(.Overflow);}return .ok(value+padding);
}
fn Result<usize,layouts::Error> initialize(ref mut State w,ref layouts::Catalog c){
    if(c.count>32){return .err(.Limit);}w.plan.count=c.count;
    var usize i=0;while(i<32){w.plan.bytes[i]=0;w.plan.alignments[i]=0;w.plan.depths[i]=0;w.visiting[i]=false;i+=1;}
    i=0;while(i<512){w.plan.offsets[i]=0;i+=1;}w.phase=1;return .ok(0);
}
fn Result<usize,layouts::Error> inspect(ref mut State w,ref layouts::Catalog c){
    let usize r=w.checked;let usize n=c.fields[r] as usize;
    if(r<c.count){if(n==0 || n>16){return .err(.Fields);}}else if(n!=0){return .err(.Metadata);}
    var usize i=0;while(i<16){let usize at=r*16+i;let u8 kind=c.kinds[at];let u8 tag=c.types[at];
        if(r>=c.count || i>=n){if(kind!=0 || tag!=0){return .err(.Metadata);}}
        else if(kind==0){if(width(tag)==0){return .err(.Type);}}
        else if(kind!=1 || tag as usize>=c.count){return .err(.Type);}i+=1;
    }w.checked+=1;if(w.checked==32){w.phase=2;}return .ok(0);
}
fn Result<usize,layouts::Error> dependencies(ref mut State w,ref layouts::Catalog c){
    var usize steps=0;while(steps<16){steps+=1;
        if(w.depth==0){
            if(w.root==c.count){w.done=true;w.active=false;return .ok(0);}
            let ref layouts::Plan p=ref w.plan;let bool ready=p.depths[w.root]!=0;
            if(ready){w.root+=1;}
            else{let usize root=w.root;w.records[0]=root;w.fields[0]=0;w.visiting[root]=true;w.depth=1;}
        }else{
            let usize level=w.depth-1;let usize r=w.records[level];let usize f=w.fields[level];
            if(f==c.fields[r] as usize){w.phase=3;return .ok(0);}
            w.fields[level]+=1;let usize at=r*16+f;
            if(c.kinds[at]==1){let usize child=c.types[at] as usize;
                let ref layouts::Plan p=ref w.plan;let bool pending=p.depths[child]==0;
                if(pending){if(w.visiting[child] || w.depth>=32){return .err(.Cycle);}
                    let usize next=w.depth;w.records[next]=child;w.fields[next]=0;w.visiting[child]=true;w.depth+=1;}
            }
        }
    }return .ok(0);
}
fn Result<usize,layouts::Error> node(ref mut State w,ref layouts::Catalog c){
    let usize r=w.records[w.depth-1];var usize size=0;var usize alignment=1;var usize depth=1;var usize f=0;
    while(f<c.fields[r] as usize){let usize slot=r*16+f;let usize tag=c.types[slot] as usize;
        var usize bytes=0;var usize a=1;
        if(c.kinds[slot]==1){let ref layouts::Plan p=ref w.plan;
            bytes=p.bytes[tag];a=p.alignments[tag];let usize d=p.depths[tag];
            if(d>=16){return .err(.Depth);}if(depth<=d){depth=d+1;}
        }else{bytes=width(c.types[slot]);a=bytes;}
        let usize offset=aligned(size,a)?;if(bytes>18446744073709551615-offset){return .err(.Overflow);}
        size=offset+bytes;if(size>w.limit){return .err(.Quota);}if(alignment<a){alignment=a;}
        w.plan.offsets[slot]=offset;f+=1;
    }
    let usize padded=aligned(size,alignment)?;if(padded>w.limit){return .err(.Quota);}
    w.plan.bytes[r]=padded;w.plan.alignments[r]=alignment;w.plan.depths[r]=depth;
    w.visiting[r]=false;w.depth-=1;w.phase=2;return .ok(0);
}
pub fn Result<bool,layouts::Error> advance(ref mut State w,ref layouts::Catalog c,ref mut budget::State allowance){
    if(!w.active || w.done || w.phase>3){return .err(.Metadata);}
    if(allowance.last!=0){return .ok(false);}
    let bool admitted=switch(budget::admit(allowance,4096,0)){case .ok(v):{v}case .err(_):{return .err(.Metadata);}};
    if(!admitted){return .ok(false);}
    let Result<usize,layouts::Error> result=if(w.phase==0){initialize(w,c)}else if(w.phase==1){inspect(w,c)}
        else if(w.phase==2){dependencies(w,c)}else{node(w,c)};
    switch(result){case .ok(_):{}case .err(e):{w.active=false;return .err(e);}};return .ok(w.done);
}
