module slice_result_dependency_work;
import ir as ir;
import locals as locals;
import functions as functions;
import errors as errors;
import metadata_budget as budget;
import std::num as num;

pub struct State { bool[64] keep; usize[16] chain; usize first; usize index; usize target; usize zero;
    usize at; usize parent; usize site; usize call; usize end; usize mask; usize arg; usize item;
    usize steps; usize count; usize total; usize value; usize search; usize wanted; usize found;
    usize visits; u8 phase; u8 back; u8 request; bool matched; bool done; }
pub fn State finish_begin(usize first,usize count,usize target,usize zero,usize at){
    return State{.keep=[false;64],.chain=[16;16],.first=first,.index=count,.target=target,.zero=zero,
        .at=at,.parent=0,.site=0,.call=0,.end=0,.mask=0,.arg=0,.item=0,.steps=0,.count=0,.total=0,
        .value=0,.search=0,.wanted=0,.found=0,.visits=0,.phase=0,.back=0,.request=0,.matched=false,.done=false};}
pub fn State publish_begin(usize value,usize at){var State w=finish_begin(0,0,0,0,at);w.value=value;w.phase=30;return w;}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.value);}
pub fn Result<usize,errors::Error> resume(ref mut State w,usize value){
    if(w.done || w.request==0 || w.request>3){return .err(errors::make(5,w.at));}
    if(w.request==1){w.site=value;}else if(w.request==2){w.call=value;}else if(w.request==3){w.found=value;}
    w.request=0;return .ok(value);
}
fn Result<u8,errors::Error> byte(usize value,usize at){
    let i64 wide=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{return .err(errors::make(4,at));}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(4,at))}};
}
fn void local(ref mut State w,usize first,usize value,u8 back){w.search=first;w.wanted=value;w.back=back;w.phase=90;}
fn void ancestor(ref mut State w,usize site,u8 back){w.search=0;w.wanted=site;w.back=back;w.phase=91;}
fn void creator(ref mut State w,usize site,u8 back){w.search=0;w.wanted=site;w.back=back;w.phase=92;}
fn Result<bool,errors::Error> scan(ref ir::Program p,ref locals::Table names,ref mut State w){
    if(w.phase==90){if(w.search>=names.count){w.found=64;w.phase=w.back;return .ok(false);}
        if(names.registers[w.search]==w.wanted){w.found=w.search;w.phase=w.back;}else{w.search+=1;}return .ok(false);}
    if(w.phase==91){if(w.search>=p.count || w.search>=256){w.found=16;w.phase=w.back;return .ok(false);}
        let usize pc=w.search;let u8 op=p.code[pc*8];
        if((op==59 || op==61 || op==67) && p.code[pc*8+1] as usize==w.wanted){w.found=p.code[pc*8+2] as usize;w.phase=w.back;}
        else{w.search+=1;}return .ok(false);}
    if(w.phase==92){if(p.count>256 || w.wanted>=16 || w.search>=p.count){w.found=256;w.phase=w.back;return .ok(false);}
        let usize pc=w.search;let u8 op=p.code[pc*8];
        if((op==61 || op==67) && p.code[pc*8+1] as usize==w.wanted){w.found=pc;w.phase=w.back;}
        else{w.search+=1;}return .ok(false);}
    return .err(errors::make(5,w.at));
}
pub fn Result<bool,errors::Error> finish_advance(ref mut ir::Program p,ref locals::Table names,
    ref locals::Table captures,ref functions::Table signatures,ref usize[] args,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(w.request!=0 || meter.last!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}w.visits+=1;
    if(w.phase>=90){return scan(p,captures,w);}
    if(w.phase==0){let usize chosen=signatures.return_slice_inputs[w.target] as usize;
        if(chosen==0 || chosen>args.len || signatures.return_slice_elements[w.target]==0 || p.return_types[w.target]!=12){return .err(errors::make(3,w.at));}
        let usize value=args[chosen-1];if(value<160 || value>=176){return .err(errors::make(3,w.at));}
        w.parent=value-160;w.phase=1;return .ok(false);}
    if(w.phase==1){let usize first=w.first;let usize parent=w.parent;local(w,first,160+parent,2);return .ok(false);}
    if(w.phase==2){if(w.found==64 || !ir::exclusive(p,w.parent)){w.steps=0;w.site=w.parent;w.phase=5;return .ok(false);}
        let usize parent=w.parent;creator(w,parent,3);return .ok(false);}
    if(w.phase==3){if(w.found==256){w.steps=0;w.site=w.parent;w.phase=5;return .ok(false);}
        if(w.steps>=16){return .err(errors::make(4,w.at));}w.steps+=1;w.parent=p.code[w.found*8+2] as usize;
        if(w.parent>=16){return .err(errors::make(3,w.at));}w.phase=1;return .ok(false);}
    if(w.phase==5){if(w.site>=16){w.phase=9;return .ok(false);}let usize first=w.first;let usize site=w.site;local(w,first,160+site,6);return .ok(false);}
    if(w.phase==6){if(w.found==64){w.phase=9;return .ok(false);}if(w.steps>=16){return .err(errors::make(4,w.at));}
        w.steps+=1;let usize found=w.found;w.keep[found]=true;let usize root=p.slice_roots[w.site] as usize;
        let usize first=w.first;let usize site=w.site;
        if(root!=0){local(w,first,127+root,7);}else{ancestor(w,site,8);}return .ok(false);}
    if(w.phase==7){if(w.found!=64){let usize found=w.found;w.keep[found]=true;}let usize site=w.site;ancestor(w,site,8);return .ok(false);}
    if(w.phase==8){w.site=w.found;w.phase=5;return .ok(false);}
    if(w.phase==9){w.request=1;w.phase=10;return .ok(false);}
    if(w.phase==10){w.request=2;w.phase=11;return .ok(false);}
    if(w.phase==11){p.code[w.call*8]=66;p.code[w.call*8+5]=byte(w.site,w.at)?;
        p.code[w.call*8+6]=byte(w.parent,w.at)?;w.phase=12;return .ok(false);}
    if(w.phase==12){if(w.index<=w.first){w.phase=19;return .ok(false);}w.index-=1;w.item=captures.registers[w.index];
        if(!w.keep[w.index]){w.end=p.count;w.request=3;w.phase=13;}return .ok(false);}
    if(w.phase==13){if(w.found!=0 && p.code[w.end*8]==62){w.arg=0;w.matched=false;w.phase=14;}else{w.phase=12;}return .ok(false);}
    if(w.phase==14){if(w.arg>=args.len){if(!w.matched){return .err(errors::make(3,w.at));}
            p.code[w.end*8]=68;w.phase=12;return .ok(false);}
        let usize value=args[w.arg];if(value<160 || value>=176){w.arg+=1;return .ok(false);}
        w.site=value-160;w.steps=0;w.phase=15;return .ok(false);}
    if(w.phase==15){if(w.site>=16 || w.steps>=16){w.arg+=1;w.phase=14;return .ok(false);}
        if(w.item==160+w.site){let usize one=1;w.mask|=one<<w.arg;w.matched=true;w.arg+=1;w.phase=14;return .ok(false);}
        let usize site=w.site;ancestor(w,site,16);return .ok(false);}
    if(w.phase==16){w.site=w.found;w.steps+=1;w.phase=15;return .ok(false);}
    if(w.phase==19){p.code[w.call*8+4]=byte(w.mask,w.at)?;w.phase=20;return .ok(false);}
    if(w.phase==20){let usize site=p.code[w.call*8+5] as usize;let usize bound=ir::raw(p,67,site,w.parent,w.zero,w.at)?;
        p.code[bound*8+4]=byte(w.zero,w.at)?;w.value=160+p.code[w.call*8+5] as usize;w.done=true;return .ok(true);}
    return .err(errors::make(5,w.at));
}
pub fn Result<bool,errors::Error> publish_advance(ref ir::Program p,ref mut locals::Table names,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}w.visits+=1;
    if(w.phase>=90){return scan(p,names,w);}
    if(w.phase==30){if(p.count==0 || p.code[(p.count-1)*8]!=67 || w.value!=160+p.code[(p.count-1)*8+1] as usize){return .err(errors::make(3,w.at));}
        w.parent=p.code[(p.count-1)*8+2] as usize;w.phase=31;return .ok(false);}
    if(w.phase==31){if(w.parent>=16){w.total=w.count;w.phase=34;return .ok(false);}let usize parent=w.parent;local(w,0,160+parent,32);return .ok(false);}
    if(w.phase==32){if(w.found!=64){w.total=w.count;w.phase=34;return .ok(false);}
        if(w.count>=16){return .err(errors::make(4,w.at));}let usize count=w.count;let usize parent=w.parent;w.chain[count]=parent;w.count+=1;ancestor(w,parent,33);return .ok(false);}
    if(w.phase==33){w.parent=w.found;w.phase=31;return .ok(false);}
    if(w.phase==34){if(w.count==0){w.value=w.total;w.done=true;return .ok(true);}
        w.count-=1;w.site=w.chain[w.count];let usize root=p.slice_roots[w.site] as usize;
        if(root!=0){local(w,0,127+root,35);}else{w.phase=36;}return .ok(false);}
    if(w.phase==35){let usize root=p.slice_roots[w.site] as usize;
        if(w.found==64){let usize owner=locals::declare(names,w.at,w.at,127+root,p.arrays.mutable[root-1])?;}w.phase=36;return .ok(false);}
    if(w.phase==36){let usize view=locals::declare(names,w.at,w.at,160+w.site,ir::exclusive(p,w.site))?;w.phase=34;return .ok(false);}
    return .err(errors::make(5,w.at));
}
