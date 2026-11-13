module reference_result_work;
import ir as ir;
import functions as functions;
import locals as locals;
import reference_call_source as calls;
import reference_owner_work as owners;
import errors as errors;
import metadata_budget as budget;
import std::num as num;

pub struct State { owners::State owner; usize first; usize index; usize keep; usize at; usize target;
    usize site; usize pc; usize map; usize row; usize root; usize local; usize count; usize value;
    usize visits; u8 phase; u8 request; bool done; }
pub fn State release_begin(usize first,usize count,usize keep,usize at){return State{
    .owner=owners::begin(0,0,at),.first=first,.index=count,.keep=keep,.at=at,.target=0,.site=0,
    .pc=0,.map=0,.row=0,.root=0,.local=0,.count=0,.value=0,.visits=0,.phase=20,.request=0,.done=false};}
pub fn State publish_begin(usize site,usize at){var State w=release_begin(0,0,0,at);
    w.site=site;w.owner=owners::begin(192+site,0,at);w.phase=30;return w;}
pub fn State call_begin(usize first,usize count,usize target,usize at){var State w=release_begin(first,count,0,at);
    w.target=target;w.phase=0;return w;}
pub fn Result<usize,errors::Error> prepared(ref State w){if(!w.done){return .err(errors::make(5,w.at));}return .ok(w.value);}
pub fn Result<usize,errors::Error> resume(ref mut State w,usize value){
    if(w.done || w.request!=1){return .err(errors::make(5,w.at));}w.count+=value;w.request=0;return .ok(value);}
fn Result<u8,errors::Error> byte(usize value,usize at){
    let i64 wide=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{return .err(errors::make(4,at));}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(4,at))}};
}
fn Result<bool,errors::Error> release_step(ref locals::Table captures,ref mut State w){
    if(w.index<=w.first){if(w.phase==20){w.value=w.count;}else{w.value=192+w.site;}w.done=true;return .ok(true);}
    w.index-=1;let usize value=captures.registers[w.index];let usize one=1;
    if(!(value>=128 && value<144 && (w.keep&(one<<(value-128)))!=0)){w.request=1;}
    return .ok(false);
}
pub fn Result<bool,errors::Error> release_advance(ref mut ir::Program p,ref locals::Table captures,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(w.request!=0 || meter.last!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}w.visits+=1;return release_step(captures,w);
}
pub fn Result<bool,errors::Error> publish_advance(ref ir::Program p,ref functions::Table signatures,
    ref mut locals::Table names,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==30){if(!w.owner.done){return owners::advance(p,signatures,ref mut w.owner,meter);}
        w.keep=owners::prepared(ref w.owner)?;w.phase=31;}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}w.visits+=1;
    if(w.phase==31){if(w.root>=16){w.value=w.count;w.done=true;return .ok(true);}let usize one=1;
        if((w.keep&(one<<w.root))==0){w.root+=1;return .ok(false);}w.local=0;w.phase=32;return .ok(false);}
    if(w.phase==32){if(w.local>=names.count){w.phase=33;return .ok(false);}
        if(names.registers[w.local]==128+w.root){w.root+=1;w.phase=31;}else{w.local+=1;}return .ok(false);}
    if(w.phase==33){if(w.root>=p.arrays.count){return .err(errors::make(3,w.at));}
        let usize hidden=locals::declare(names,w.at,w.at,128+w.root,p.arrays.mutable[w.root])?;w.count+=1;w.root+=1;w.phase=31;return .ok(false);}
    return .err(errors::make(5,w.at));
}
pub fn Result<bool,errors::Error> call_advance(ref mut ir::Program p,ref functions::Table signatures,
    ref locals::Table captures,ref usize[] arguments,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(w.request!=0 || meter.last!=0){return .ok(false);}
    if(w.phase==6){if(!w.owner.done){return owners::advance(p,signatures,ref mut w.owner,meter);}
        w.keep=owners::prepared(ref w.owner)?;w.phase=7;}
    if(!budget::admit(meter,4096,w.at)?){return .ok(false);}w.visits+=1;
    if(w.phase==0){if(!calls::result(signatures,w.target) || p.call_count>=32 || arguments.len>8){return .err(errors::make(3,w.at));}
        if(p.count>256){return .err(errors::make(4,w.at));}w.phase=1;return .ok(false);}
    if(w.phase==1){if(w.pc>=p.count){if(w.site==16){return .err(errors::make(4,w.at));}w.map=p.call_count;w.phase=2;return .ok(false);}
        let usize pos=w.pc*8;let u8 op=p.code[pos];
        if(op==69 || op==74 || op==75 || op==76 || op==77 ||
            (op==78 && p.code[pos+2]<16 && p.return_types[p.code[pos+2] as usize]==0 &&
            p.array_results[p.code[pos+2] as usize]==0 && p.record_results[p.code[pos+2] as usize]==0)){
            let usize site=p.code[pos+1] as usize;if(site>=16){return .err(errors::make(4,w.at));}
            if(site>=w.site){w.site=site+1;}}
        w.pc+=1;return .ok(false);}
    if(w.phase==2){if(w.row<arguments.len){p.call_args[w.map*8+w.row]=byte(arguments[w.row],w.at)?;w.row+=1;return .ok(false);}
        w.phase=3;return .ok(false);}
    if(w.phase==3){p.call_arities[w.map]=byte(arguments.len,w.at)?;p.call_count+=1;w.phase=4;return .ok(false);}
    if(w.phase==4){let usize pc=ir::raw(p,78,w.site,w.target,w.map,w.at)?;
        w.owner=owners::begin(192+w.site,0,w.at);w.phase=6;return .ok(false);}
    if(w.phase==7){return release_step(captures,w);}
    return .err(errors::make(5,w.at));
}
