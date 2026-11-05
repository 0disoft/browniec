module static_execution;
import ir as ir;
import static_ir as statics;
import static_views as views;
import fuel as fuel;
import errors as errors;
import std::num as num;
import std::bytes as bytes;
import reference_access as access;

pub struct Step { usize live; usize remaining; }
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
fn Result<views::Span,errors::Error> declared(ref statics::Sites sites,usize site,usize f,
    u8 kind,usize payload,usize offset){
    if(site>=16 || sites.functions[site]!=f || (kind!=0 && sites.kinds[site]!=kind) ||
        (sites.kinds[site]!=1 && sites.kinds[site]!=2)){return .err(invalid(offset));}
    let usize lo=sites.spans[site].start;let usize hi=sites.spans[site].end;let usize start=sites.starts[site];
    if(hi<lo || hi-lo>4096 || start>payload || hi-lo>payload-start){return .err(invalid(offset));}
    return .ok(views::Span{.start=start,.length=hi-lo});
}
fn Result<views::Span,errors::Error> span(ref statics::Sites sites,usize site,usize f,
    u8 kind,usize live,ref u8[] payload,ref u32[] words,usize offset){
    if(words.len==16){return views::live(sites,site,f,kind,words,live,payload.len,offset);}
    let usize one=1;if(site>=16 || (live&(one<<site))==0){return .err(invalid(offset));}
    return declared(sites,site,f,kind,payload.len,offset);
}
// Fixed-span compatibility entry. Dynamic definitions require the explicit
// frame-word API; falling back to maximum proof windows would broaden a view.
pub fn Result<Step,errors::Error> step(ref ir::Program p,ref statics::Sites sites,ref u8[] payload,
    usize pc,usize f,ref mut i64[] registers,usize live,usize remaining){
    var u32[1] unused=[0];
    if(sites.dynamic!=0){return .err(invalid(0));}
    return execute(p,sites,payload,pc,f,registers,live,remaining,ref mut unused[..0]);
}
pub fn Result<Step,errors::Error> step_frame(ref ir::Program p,ref statics::Sites sites,ref u8[] payload,
    usize pc,usize f,ref mut i64[] registers,usize live,usize remaining,ref mut u32[] words){
    if(words.len!=16){return .err(invalid(0));}
    return execute(p,sites,payload,pc,f,registers,live,remaining,words);
}
// Invocation has independently proved the exact code/image. No register, word
// or live-bit publication precedes complete Fuel and guest endpoint validation.
fn Result<Step,errors::Error> execute(ref ir::Program p,ref statics::Sites sites,ref u8[] payload,
    usize pc,usize f,ref mut i64[] registers,usize live,usize remaining,ref mut u32[] words){
    if(pc>=p.count || pc>=256 || f>=16 || sites.count==0 || sites.count>16 || payload.len>4096){return .err(invalid(0));}
    let usize at=pc*8;let usize offset=p.offsets[pc];let u8 op=p.code[at];
    let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;
    let usize b=p.code[at+3] as usize;let usize one=1;
    if(!statics::operation(op) || op==77 || (op==76 && words.len!=16)){return .err(invalid(offset));}
    var views::Span left=views::Span{.start=0,.length=0};var usize right=0;var usize other=0;
    if(op==69 || op==74 || op==75 || op==76){
        if(dst>=16 || sites.definitions[dst]!=pc || sites.functions[dst]!=f || (live&(one<<dst))!=0){return .err(invalid(offset));}
        let views::Span bound=declared(sites,dst,f,0,payload.len,offset)?;
        left=if(op==69){bound}else{span(sites,a,f,if(op==74){2}else if(op==76){1}else{0},live,payload,words,offset)?};
        if(op==76 && (b>=registers.len || p.code[at+4] as usize>=registers.len)){return .err(invalid(offset));}
    }else if(op==70){left=span(sites,dst,f,0,live,payload,words,offset)?;}
    if(op==71 || op==72 || op==73){
        if(dst>=registers.len || (op==71 && b>=registers.len)){return .err(invalid(offset));}
        left=span(sites,a,f,if(op==73){0}else{1},live,payload,words,offset)?;
        if(op==73){let views::Span second=span(sites,b,f,0,live,payload,words,offset)?;right=second.length;other=second.start;}
    }
    let usize price=fuel::static_instruction(op,left.length,right);
    if(remaining<price){return .err(errors::make(8,offset));}let usize paid=remaining-price;
    if(op==69 || op==74 || op==75 || op==76){
        if(words.len==16){var u32 word=0;
            if(op==69){word=views::pack(left.start,left.length,payload.len,offset)?;}
            else if(op==76){let i64 lo=registers[b];let i64 hi=registers[p.code[at+4] as usize];
                if(lo<0 || hi<lo || hi>4096){return .err(errors::make(14,offset));}
                let usize start=switch(num::usize_from_i64(lo)){case .ok(v):{v}case .err(_):{return .err(errors::make(14,offset));}};
                let usize end=switch(num::usize_from_i64(hi)){case .ok(v):{v}case .err(_):{return .err(errors::make(14,offset));}};
                word=views::crop(ref left,start,end,payload.len,offset)?;
            }else{word=words[a];}
            let views::Span checked=views::inspect(sites,dst,f,0,word,payload.len,offset)?;
            words[dst]=word;
        }return .ok(Step{.live=live|(one<<dst),.remaining=paid});
    }
    if(op==70){if(words.len==16){words[dst]=0;}return .ok(Step{.live=live^(one<<dst),.remaining=paid});}
    var i64 value=0;
    if(op==71){value=access::checked_byte(payload,left,registers[b],offset)?;
    }else if(op==72){value=switch(num::i64_from_usize(left.length)){
        case .ok(v):{v}case .err(_):{return .err(invalid(offset));}
    };}else{value=if(bytes::equal(payload[left.start..left.start+left.length],payload[other..other+right])){1}else{0};}
    registers[dst]=value;return .ok(Step{.live=live,.remaining=paid});
}
