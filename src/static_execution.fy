module static_execution;
import ir as ir;
import static_ir as statics;
import fuel as fuel;
import errors as errors;
import std::num as num;
import std::bytes as bytes;

pub struct Step { usize live; usize remaining; }
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
// Each site is a shared alias into the exact live Program image. This helper
// receives proof/payload only from independently admitted invocation paths.
fn Result<usize,errors::Error> span(ref statics::Sites sites,usize site,usize f,
    u8 kind,usize live,ref u8[] payload,usize offset){
    let usize one=1;
    if(site>=16 || sites.functions[site]!=f || (kind!=0 && sites.kinds[site]!=kind) ||
        (sites.kinds[site]!=1 && sites.kinds[site]!=2) || (live&(one<<site))==0){return .err(invalid(offset));}
    let usize lo=sites.spans[site].start;let usize hi=sites.spans[site].end;
    let usize start=sites.starts[site];
    if(hi<lo || hi-lo>4096 || start>payload.len || hi-lo>payload.len-start){return .err(invalid(offset));}
    return .ok(hi-lo);
}
// No bytes or live/register publication precede the complete price preflight.
// Caller already paid its one dispatch unit. Byte indices trap as array Bounds.
pub fn Result<Step,errors::Error> step(ref ir::Program p,ref statics::Sites sites,ref u8[] payload,
    usize pc,usize f,ref mut i64[] registers,usize live,usize remaining){
    if(pc>=p.count || pc>=256 || f>=16 || sites.count==0 || sites.count>16 || payload.len>4096){return .err(invalid(0));}
    let usize at=pc*8;let usize offset=p.offsets[pc];let u8 op=p.code[at];
    let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;
    let usize b=p.code[at+3] as usize;let usize one=1;
    if(!statics::operation(op)){return .err(invalid(offset));}
    if(op==69 || op==74 || op==75){
        if(dst>=16 || sites.definitions[dst]!=pc || sites.functions[dst]!=f || (live&(one<<dst))!=0){return .err(invalid(offset));}
        let usize length=span(sites,dst,f,0,live|(one<<dst),payload,offset)?;
        if(op==74 || op==75){let usize source=span(sites,a,f,if(op==74){2}else{0},live,payload,offset)?;}
    }else if(op==70){let usize length=span(sites,dst,f,0,live,payload,offset)?;}
    var usize left=0;var usize right=0;
    if(op==71 || op==72 || op==73){
        if(dst>=registers.len || (op==71 && b>=registers.len)){return .err(invalid(offset));}
        left=span(sites,a,f,if(op==73){0}else{1},live,payload,offset)?;
        if(op==73){right=span(sites,b,f,0,live,payload,offset)?;}
    }
    let usize price=fuel::static_instruction(op,left,right);
    if(remaining<price){return .err(errors::make(8,offset));}
    let usize paid=remaining-price;
    if(op==69 || op==74 || op==75){return .ok(Step{.live=live|(one<<dst),.remaining=paid});}
    if(op==70){return .ok(Step{.live=live^(one<<dst),.remaining=paid});}
    var i64 value=0;
    if(op==71){
        let usize index=switch(num::usize_from_i64(registers[b])){
            case .ok(v):{v}case .err(_):{return .err(errors::make(14,offset));}
        };
        if(index>=left){return .err(errors::make(14,offset));}
        value=payload[sites.starts[a]+index] as i64;
    }else if(op==72){value=switch(num::i64_from_usize(left)){
        case .ok(v):{v}case .err(_):{return .err(invalid(offset));}
    };}else{
        let usize x=sites.starts[a];let usize y=sites.starts[b];
        value=if(bytes::equal(payload[x..x+left],payload[y..y+right])){1}else{0};
    }
    registers[dst]=value;return .ok(Step{.live=live,.remaining=paid});
}
