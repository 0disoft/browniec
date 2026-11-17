module array_operand_work;
import lexer as lexer;
import ir as ir;
import types as types;
import locals as locals;
import array_source as arrays;
import cells as cells;
import std::num as num;
import errors as errors;
import metadata_budget as budget;
// Actual scalar projections. Requests: 1 token, 2 expression, 3 owner capture,
// 4 repeated/list probe. Scratch cells share the pinned source's 1024-token cap.
pub struct Frame { usize at; usize depth; usize groups; usize left; usize binding; usize id;
    usize start; usize count; usize length; usize row; usize list_start; usize inner;
    usize value; usize child_depth; u8 expected; u8 element; u8 phase; u8 request;
    bool literal; bool repeated; bool owned; bool done; }
pub fn Frame begin(usize at,usize depth,usize groups,u8 expected,bool literal,usize binding,usize start){
    return Frame{.at=at,.depth=depth,.groups=groups,.left=0,.binding=binding,.id=16,.start=start,.count=0,.length=0,.row=0,
        .list_start=0,.inner=at,.value=0,.child_depth=depth+groups+1,.expected=expected,.element=expected,.phase=0,.request=0,
        .literal=literal,.repeated=false,.owned=literal,.done=false};}
fn Result<bool,errors::Error> take(ref lexer::State s,ref mut Frame f,u8 kind,u8 next){
    if(kind!=0 && s.kind!=kind){return .err(errors::make(2,s.begin));}f.phase=next;f.request=1;return .ok(false);}
fn Result<u8,errors::Error> register_byte(usize value,usize at){
    let i64 wide=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{return .err(errors::make(4,at));}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(4,at))}};
}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref lexer::State s,ref mut ir::Program p,
    ref locals::Table names,ref mut Frame f,ref mut u8[] values,ref mut usize used,ref mut budget::State meter){
    if(f.done){return .ok(true);}if(meter.last!=0 || f.request!=0){return .ok(false);}
    if(!budget::admit(meter,4096,s.begin)?){return .ok(false);}
    if(f.phase==0){if(f.depth>32 || f.literal && f.groups>32-f.depth){return .err(errors::make(4,f.at));}
        if(f.left<f.groups){if(!f.literal && f.left>=32-f.depth){return .err(errors::make(4,s.begin));}f.left+=1;return take(s,f,40,0);}
        f.left=f.groups;f.phase=if(f.literal){1}else{20};return .ok(false);}
    if(f.phase==1){f.request=4;f.phase=2;return .ok(false);}
    if(f.phase==2){return take(s,f,91,3);}
    if(f.phase==3){if(!f.repeated && s.kind==93){return .err(errors::make(3,s.begin));}f.phase=4;return .ok(false);}
    if(f.phase==4){if(!f.repeated && (f.count>=4096 || p.list_used>4096 || f.count>=4096-p.list_used)){return .err(errors::make(4,s.begin));}
        f.inner=s.begin;f.request=2;f.phase=5;return .ok(false);}
    if(f.phase==5){let usize value=f.value;
        if(f.repeated){if(!types::scalar(p.types[value]) || f.expected!=0 && p.types[value]!=f.expected){return .err(errors::make(3,f.at));}
            f.element=p.types[value];return take(s,f,59,6);}
        if(value>=128 || value>=p.registers || !types::scalar(p.types[value])){return .err(errors::make(3,f.inner));}
        if(f.element==0){f.element=p.types[value];}if(p.types[value]!=f.element){return .err(errors::make(3,f.inner));}
        if(*used>=values.len){return .err(errors::make(5,f.inner));}let usize slot=*used;values[slot]=register_byte(value,f.inner)?;*used+=1;f.count+=1;f.expected=f.element;
        if(s.kind==44){return take(s,f,44,8);}return take(s,f,93,10);}
    if(f.phase==6){if(s.kind!=1 || s.value<1 || s.value>4096){return .err(errors::make(3,s.begin));}
        f.length=cells::unpack(s.value,s.begin)?;return take(s,f,1,7);}
    if(f.phase==7){return take(s,f,93,10);}
    if(f.phase==8){if(s.kind==93){return take(s,f,93,10);}f.phase=4;return .ok(false);}
    if(f.phase==10){let usize length=if(f.repeated){f.length}else{f.count};
        f.id=ir::array_in(p,names.function,f.element,length,false,f.at)?;f.phase=11;return .ok(false);}
    if(f.phase==11){if(f.repeated){let usize initialized=ir::array_init(p,f.id,f.value,f.at)?;f.phase=19;return .ok(false);}
        if(f.id>=16 || f.id>=p.arrays.count || f.count!=p.arrays.lengths[f.id] || f.count==0 || f.count>4096 || !types::scalar(p.arrays.elements[f.id])){return .err(errors::make(3,f.at));}
        if(p.count>=256 || p.list_used>4096 || f.count>4096-p.list_used){return .err(errors::make(4,f.at));}f.row=0;f.phase=12;return .ok(false);}
    if(f.phase==12){if(f.row==f.count){f.phase=13;return .ok(false);}let usize r=values[f.start+f.row] as usize;
        if(r>=128 || r>=p.registers || p.types[r]!=p.arrays.elements[f.id] || p.slots[r] || p.array_parameters[r]!=0 || p.record_parameters[r]!=0 || p.slice_parameters[r]!=0){return .err(errors::make(3,f.at));}
        f.row+=1;return .ok(false);}
    if(f.phase==13){f.list_start=p.list_used;let usize pc=ir::raw(p,80,f.id,f.list_start%256,f.list_start/256,f.at)?;f.row=0;f.phase=14;return .ok(false);}
    if(f.phase==14){if(f.row==f.count){p.list_used=f.list_start+f.count;f.phase=19;return .ok(false);}
        let usize r=values[f.start+f.row] as usize;let u8 byte=register_byte(r,f.at)?;
        p.list_operands[f.list_start+f.row]=byte;f.row+=1;return .ok(false);}
    if(f.phase==19){*used=f.start;f.phase=22;return .ok(false);}
    if(f.phase==20){if(f.binding>=names.count || names.registers[f.binding]<128 || names.registers[f.binding]>=144){return .err(errors::make(3,s.begin));}
        f.id=names.registers[f.binding]-128;return take(s,f,0,21);}
    if(f.phase==21){if(f.id>=16 || f.id>=p.arrays.count || p.array_functions[f.id] as usize!=names.function){return .err(errors::make(3,f.at));}f.phase=22;return .ok(false);}
    if(f.phase==22){if(f.left!=0){f.left-=1;return take(s,f,41,22);}f.phase=if(f.owned){23}else{24};return .ok(false);}
    if(f.phase==23){f.request=3;f.phase=24;return .ok(false);}
    if(f.phase==24){if(s.kind==91){return take(s,f,91,25);}if(s.kind==46){return take(s,f,46,28);}return .err(errors::make(3,s.begin));}
    if(f.phase==25){f.expected=12;f.request=2;f.phase=26;return .ok(false);}
    if(f.phase==26){if(p.types[f.value]!=12){return .err(errors::make(3,f.at));}return take(s,f,93,27);}
    if(f.phase==27){f.value=ir::array_read(p,f.id,f.value,f.at)?;f.phase=30;return .ok(false);}
    if(f.phase==28){if(s.kind!=2 || !lexer::equal(source[s.begin..s.end],b"len")){return .err(errors::make(3,s.begin));}return take(s,f,2,29);}
    if(f.phase==29){f.value=arrays::length_value(p,f.id,f.at)?;f.phase=30;return .ok(false);}
    if(f.phase==30){if(f.owned){let usize dropped=ir::array_drop(p,f.id,f.at)?;}f.done=true;return .ok(true);}
    return .err(errors::make(5,s.begin));
}
