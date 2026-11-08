module call_copy_plan_work;
import array_owners as owners;
import struct_layout as records;
import struct_layout_work as catalog_work;
import metadata_budget as budget;
import call_copy_cursor as cursor;
import scalar_codec as codec;
import std::num as num;

// Private per-invocation proof bank, never guest/raw-IR authority. The parent
// freezes the exact catalog, table, arguments and source bytes until publication.
pub struct Plan { owners::Table planned; owners::Copies copies; owners::CallCopyRange[8] ranges;
    usize mark; usize depth; usize checked; bool failed; u8 failure; }
pub struct State {
    Plan plan; catalog_work::State layout;
    u8[1024] masks; u8[1024] positions; usize[8] bools;
    usize[16] records; usize[16] fields; usize[16] bases;
    usize count; usize capacity; usize index; usize depth; usize reads; usize read_left; usize bool_index;
    u8 phase; bool arrays_only; bool layout_ok; bool layout_bad; bool active; bool done; bool ready;
}
pub fn State empty(){
    let owners::Token zero=owners::Token{.slot=0,.generation=0};
    return State{.plan=Plan{.planned=owners::empty(0),.copies=owners::Copies{.tokens=[zero;8],.count=0},
        .ranges=[owners::CallCopyRange{.source=0,.target=0,.mark=0,.end=0,.size=0};8],.mark=0,.depth=0,.checked=0,.failed=false,.failure=0},
        .layout=catalog_work::empty(),.masks=[0;1024],.positions=[0;1024],.bools=[0;8],.records=[0;16],.fields=[0;16],.bases=[0;16],
        .count=0,.capacity=0,.index=0,.depth=0,.reads=0,.read_left=0,.bool_index=0,.phase=0,.arrays_only=false,
        .layout_ok=false,.layout_bad=false,.active=false,.done=false,.ready=false};
}
fn u8 code(owners::Error e){return switch(e){case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}
    case .Metadata:{6}case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}};}
pub fn owners::Error failure(ref Plan p){
    if(p.failure==1){return .Token;}if(p.failure==2){return .Owners;}if(p.failure==3){return .State;}
    if(p.failure==4){return .Type;}if(p.failure==5){return .Length;}if(p.failure==6){return .Metadata;}
    if(p.failure==7){return .Overflow;}if(p.failure==8){return .Quota;}if(p.failure==9){return .Bounds;}
    if(p.failure==10){return .Alignment;}if(p.failure==11){return .Value;}return .State;
}
pub fn owners::CallCopyPlan owner_plan(ref State w){let ref Plan p=ref w.plan;
    return owners::CallCopyPlan{.planned=p.planned,.copies=p.copies,.ranges=p.ranges,.mark=p.mark,.depth=p.depth,.checked=p.checked,
        .failure=if(p.failed){.some(failure(p))}else{.none}};
}
fn Result<usize,owners::Error> arrays(ref owners::CallArgument[] args){
    if(args.len>8){return .err(.Metadata);}var usize i=0;while(i<args.len){
        if(args[i].element==0){return .err(.Type);}if(args[i].record!=0){return .err(.Metadata);}i+=1;}return .ok(i);
}
pub fn Result<usize,owners::Error> begin(ref mut State w,bool arrays_only){
    if(w.active){return .err(.State);}w.phase=0;w.arrays_only=arrays_only;w.layout_ok=false;w.layout_bad=false;
    w.index=0;w.depth=0;w.reads=0;w.read_left=0;w.bool_index=0;w.ready=false;w.active=true;w.done=false;return .ok(0);
}
// Fixed eight-argument planner using a completed invocation-local layout proof.
// No catalog traversal, mask building, payload access or table publication.
fn Result<Plan,owners::Error> plan(ref State w,ref owners::Table table,
    ref owners::CallArgument[] args,usize capacity){
    if(args.len>8){return .err(.Metadata);}let usize valid=owners::inspect_call_copy_table(table,capacity)?;
    let owners::Token zero=owners::Token{.slot=0,.generation=0};
    var Plan p=Plan{.planned=*table,.copies=owners::Copies{.tokens=[zero;8],.count=0},
        .ranges=[owners::CallCopyRange{.source=0,.target=0,.mark=0,.end=0,.size=0};8],.mark=table.arena.used,.depth=table.depth,.checked=0,.failed=false,.failure=0};
    var usize i=0;while(i<args.len){
        var owners::Owner owner=table.slots[0];
        switch(owners::inspect_call_copy_source(table,args[i])){case .ok(v):{owner=v;}case .err(e):{p.failed=true;p.failure=code(e);break;}};
        if(args[i].element==0){
            let ref catalog_work::State layout=ref w.layout;let ref records::Plan shape=ref layout.plan;
            if(!w.layout_ok || owner.record>=shape.count){p.failed=true;p.failure=6;break;}
            if(shape.bytes[owner.record]!=owner.length || shape.alignments[owner.record]!=owner.alignment){p.failed=true;p.failure=6;break;}
        }
        if(owner.end>p.mark){p.failed=true;p.failure=3;break;}
        p.ranges[i]=owners::CallCopyRange{.source=owner.base,.target=0,.mark=0,.end=0,.size=owner.end-owner.base};p.checked=i+1;
        let ref owners::Table before=ref p.planned;let usize mark=before.arena.used;
        var owners::Token token=zero;
        switch(owners::reserve_call_copy_target(ref mut p.planned,ref owner)){
            case .ok(v):{token=v;}case .err(e):{p.failed=true;p.failure=code(e);break;}};
        let ref owners::Table after=ref p.planned;let owners::Owner target=after.slots[token.slot];
        p.ranges[i]=owners::CallCopyRange{.source=owner.base,.target=target.base,.mark=mark,.end=target.end,.size=owner.end-owner.base};
        p.copies.tokens[i]=token;p.copies.count+=1;i+=1;
    }return .ok(p);
}
fn Result<usize,owners::Error> header(ref mut State w,ref owners::Table table,ref owners::CallArgument[] args,usize capacity){
    if(args.len>8){return .err(.Metadata);}if(w.arrays_only){let usize valid=arrays(args)?;}
    let usize valid=owners::inspect_call_copy_table(table,capacity)?;
    w.count=args.len;w.capacity=capacity;var bool record=false;var usize i=0;
    while(i<args.len){if(args[i].element==0){record=true;}w.bools[i]=0;i+=1;}
    if(record){let usize begun=switch(catalog_work::begin(ref mut w.layout,18446744073709551615)){
        case .ok(v):{v}case .err(_):{return .err(.State);}};w.phase=1;}else{w.phase=2;}return .ok(0);
}
fn Result<usize,owners::Error> mask_header(ref mut State w,ref owners::CallArgument[] args){
    let ref Plan p=ref w.plan;let usize checked=p.checked;
    if(w.index==checked){w.active=false;w.done=true;w.phase=5;return .ok(0);}
    let usize i=w.index;let u8 element=args[i].element;
    let ref Plan current=ref w.plan;let usize size=current.ranges[i].size;
    if(element==2){w.bools[i]=size;w.reads+=size;w.index+=1;return .ok(0);}
    if(element!=0){w.bools[i]=0;w.index+=1;return .ok(0);}
    if(!w.layout_ok || size>128){return .err(.State);}
    var usize at=0;while(at<128){w.masks[i*128+at]=0;at+=1;}
    w.bools[i]=0;w.depth=1;w.records[0]=args[i].record;w.fields[0]=0;w.bases[0]=0;w.phase=4;return .ok(0);
}
fn Result<usize,owners::Error> mask_step(ref mut State w,ref records::Catalog c){
    let usize argument=w.index;var usize steps=0;
    while(steps<16 && w.depth!=0){steps+=1;let usize level=w.depth-1;let usize record=w.records[level];let usize field=w.fields[level];
        if(field==c.fields[record] as usize){w.depth-=1;}
        else{
            w.fields[level]+=1;let usize slot=record*16+field;
            let ref catalog_work::State layout=ref w.layout;let ref records::Plan p=ref layout.plan;
            let usize offset=w.bases[level]+p.offsets[slot];
            if(c.kinds[slot]==0){let u8 tag=c.types[slot];let usize width=codec::width(tag);var usize byte=0;
                while(byte<width){w.masks[argument*128+offset+byte]=if(tag==2){2}else{1};byte+=1;}
                if(tag==2){let usize at=w.bools[argument];let i64 wide=switch(num::i64_from_usize(offset)){case .ok(v):{v}case .err(_):{return .err(.State);}};
                    let u8 narrow=switch(num::u8_from_i64(wide)){case .ok(v):{v}case .err(_):{return .err(.State);}};
                    w.positions[argument*128+at]=narrow;w.bools[argument]+=1;w.reads+=1;}
            }else{let usize next=w.depth;w.records[next]=c.types[slot] as usize;w.fields[next]=0;w.bases[next]=offset;w.depth+=1;}
        }
    }if(w.depth==0){w.index+=1;w.phase=3;}return .ok(0);
}
pub fn Result<bool,owners::Error> advance(ref mut State w,ref owners::Table table,ref records::Catalog c,
    ref owners::CallArgument[] args,usize capacity,ref mut budget::State allowance){
    if(!w.active || w.done || w.phase>4){return .err(.State);}
    if(allowance.last>4096 || allowance.last>allowance.total || allowance.stages>allowance.total || allowance.total>18446744073709551615-4096 || allowance.stages==18446744073709551615){return .err(.State);}
    if(allowance.last!=0){return .ok(false);}
    if(w.phase!=0 && (w.count!=args.len || w.capacity!=capacity)){return .err(.State);}
    if(w.phase==1){
        switch(catalog_work::advance(ref mut w.layout,c,allowance)){
            case .ok(done):{if(done){w.layout_ok=true;w.phase=2;}}
            case .err(_):{w.layout_bad=true;w.phase=2;}
        };return .ok(false);
    }
    let bool admitted=switch(budget::admit(allowance,4096,0)){case .ok(v):{v}case .err(_):{return .err(.State);}};
    if(!admitted){return .ok(false);}
    let Result<usize,owners::Error> result=if(w.phase==0){header(w,table,args,capacity)}
        else if(w.phase==2){switch(plan(w,table,args,capacity)){case .ok(p):{w.plan=p;w.index=0;w.phase=3;.ok(0)}case .err(e):{.err(e)}}}
        else if(w.phase==3){mask_header(w,args)}else{mask_step(w,c)};
    switch(result){case .ok(_):{}case .err(e):{w.active=false;return .err(e);}};return .ok(w.done);
}
pub fn Result<cursor::State,owners::Error> capture(ref State w,ref owners::CallArgument[] args){
    if(w.active || !w.done || w.count!=args.len){return .err(.State);}
    let owners::CallCopyPlan p=owner_plan(w);var cursor::State copy=owners::capture_call_copy(ref p,args)?;copy.reserve_first=w.arrays_only;return .ok(copy);
}

// Reauthenticate one payload continuation in its OWN fresh metadata batch.
// The catalog proof/masks belong to this pinned invocation, not raw authority.
// At most eight sources, sixteen table slots and 128 current bool positions are
// inspected; no full catalog/layout/mask reconstruction is called here.
pub fn Result<bool,owners::Error> validate(ref mut State w,ref owners::Table table,
    ref owners::CallArgument[] args,ref cursor::State copy,usize capacity,ref mut budget::State allowance){
    if(w.active || !w.done || w.ready){return .err(.State);}
    if(allowance.last!=0){return .ok(false);}
    let bool admitted=switch(budget::admit(allowance,4096,0)){case .ok(v):{v}case .err(_):{return .err(.State);}};
    if(!admitted){return .ok(false);}
    if(copy.count!=args.len || copy.count!=w.count || copy.count>8 || copy.phase>1 || copy.reserve_first!=w.arrays_only || capacity!=w.capacity){return .err(.State);}
    if(!copy.active && copy.count!=0){return .err(.State);}
    if(copy.index>copy.count || copy.last>copy.total || copy.written>copy.total){return .err(.State);}
    var usize i=0;while(i<copy.count){if(args[i].source.slot!=copy.source_slots[i] || args[i].source.generation!=copy.source_generations[i]){return .err(.State);}i+=1;}
    let Plan next=plan(w,table,args,capacity)?;
    if(copy.phase==1 && next.failed){return .err(failure(ref next));}
    if(next.mark!=copy.mark || next.planned.arena.used!=copy.end || next.depth!=copy.depth){return .err(.State);}
    i=0;while(i<8){let owners::Token token=next.copies.tokens[i];let owners::CallCopyRange range=next.ranges[i];
        if(range.source!=copy.source_bases[i] || range.source+range.size!=copy.source_ends[i] ||
            token.slot!=copy.target_slots[i] || token.generation!=copy.target_generations[i]){return .err(.State);}i+=1;
    }
    if(copy.end<copy.mark || copy.written>copy.end-copy.mark){return .err(.State);}
    if(copy.count==0){if(copy.active || copy.phase!=0 || copy.index!=0 || copy.at!=0 || copy.written!=0){return .err(.State);}}
    else if(copy.phase==0){
        if(copy.written!=0 || copy.index>next.checked){return .err(.State);}
        if(copy.index==next.checked){if(copy.at!=0){return .err(.State);}}
        else if(copy.at>next.ranges[copy.index].size){return .err(.State);}
    }else{
        if(next.copies.count!=copy.count || copy.index>=copy.count){return .err(.State);}
        let owners::CallCopyRange range=next.ranges[copy.index];
        if(copy.at>range.end-range.mark || copy.written!=range.mark-copy.mark+copy.at || copy.written>=copy.end-copy.mark){return .err(.State);}
    }
    if(copy.reserve_first){let usize checked=arrays(args)?;}
    var usize left=0;var usize position=0;
    if(copy.phase==0){i=copy.index;while(i<next.checked){
        let owners::CallArgument arg=args[i];let usize at=if(i==copy.index){copy.at}else{0};
        if(arg.element==2){left+=next.ranges[i].size-at;}
        else if(arg.element==0){var usize used=0;
            while(used<w.bools[i] && (w.positions[i*128+used] as usize)<at){used+=1;}
            left+=w.bools[i]-used;if(i==copy.index){position=used;}
        }i+=1;
    }}
    w.plan=next;w.read_left=left;w.bool_index=position;w.ready=true;return .ok(true);
}
