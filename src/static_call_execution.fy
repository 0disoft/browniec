module static_call_execution;
import ir as ir;
import static_ir as statics;
import static_views as views;
import fuel as fuel;
import errors as errors;

// Invocation-local unpublished metadata. Only a complete proof and a borrow of
// that exact image authorize these helpers; neither words nor plans pin storage.
pub struct Arguments { u32[16] words; usize remaining; }
pub struct Returned { u32 word; usize destination; usize remaining; }
fn errors::Error invalid(usize offset){return errors::make(5,offset);}
fn bool site(ref statics::Sites sites,usize id,usize f,u8 kind){
    return id<16 && sites.definitions[id]<256 && sites.functions[id]==f &&
        (kind==1 || kind==2) && sites.kinds[id]==kind;
}
// Validate every actual and its future PARAM destination before publishing any
// child word. A descriptor keeps its actual range, not its union of proof roots.
pub fn Result<Arguments,errors::Error> arguments(ref ir::Program p,ref statics::Sites sites,
    usize payload,usize pc,usize caller,ref u32[] words,usize live,usize remaining){
    if(!sites.call_profile || pc>=p.count || pc>=256 || caller>=p.function_count || caller>=16 ||
        pc<p.starts[caller] || pc>=p.ends[caller] || words.len!=16 || live>=65536 || p.code[pc*8]!=78){return .err(invalid(0));}
    let usize offset=p.offsets[pc];let usize at=pc*8;let usize target=p.code[at+2] as usize;
    let usize map=p.code[at+3] as usize;let usize dst=p.code[at+1] as usize;let usize one=1;
    if(target>=p.function_count || target>=16 || map>=p.call_count || map>=32 ||
        p.arities[target]>8 || p.call_arities[map] as usize!=p.arities[target] ||
        p.register_starts[target]>128 || p.arities[target]>128-p.register_starts[target]){return .err(invalid(offset));}
    if(sites.results[target]!=0 && (!site(sites,dst,caller,sites.results[target]) ||
        sites.definitions[dst]!=pc || (live&(one<<dst))!=0)){return .err(invalid(offset));}
    var u32[16] staged=[0;16];var usize mask=0;var usize count=0;var usize i=0;
    while(i<p.arities[target]){let usize formal=p.register_starts[target]+i;let u8 kind=sites.parameters[formal];
        if(kind!=0){let usize encoded=p.call_args[map*8+i] as usize;let usize future=sites.formal_sites[formal] as usize;
            if(encoded<192 || encoded>=208 || future==0 || future>16 ||
                !site(sites,future-1,target,kind) || (mask&(one<<(future-1)))!=0){return .err(invalid(offset));}
            let views::Span actual=views::live(sites,encoded-192,caller,kind,words,live,payload,offset)?;
            let u32 word=words[encoded-192];
            let views::Span checked=views::inspect(sites,future-1,target,kind,word,payload,offset)?;
            staged[future-1]=word;mask|=one<<(future-1);count+=1;
        }i+=1;
    }
    let usize price=fuel::static_call(count);
    if(remaining<price){return .err(errors::make(8,offset));}
    return .ok(Arguments{.words=staged,.remaining=remaining-price});
}
// CALL already staged this exact word. PARAM only makes its separate view live.
pub fn Result<usize,errors::Error> parameter(ref ir::Program p,ref statics::Sites sites,
    usize payload,usize pc,usize f,ref u32[] words,usize live,usize remaining){
    if(!sites.call_profile || pc>=p.count || pc>=256 || f>=p.function_count || f>=16 ||
        pc<p.starts[f] || pc>=p.ends[f] || words.len!=16 || live>=65536 || p.code[pc*8]!=77){return .err(invalid(0));}
    let usize at=pc*8;let usize offset=p.offsets[pc];let usize dst=p.code[at+1] as usize;
    let usize formal=p.code[at+2] as usize;let u8 kind=p.code[at+3];let usize one=1;
    if(p.arities[f]>8 || p.register_starts[f]>128 || p.arities[f]>128-p.register_starts[f] ||
        !site(sites,dst,f,kind) || sites.definitions[dst]!=pc || (live&(one<<dst))!=0 ||
        formal>=128 || formal<p.register_starts[f] || formal>=p.register_starts[f]+p.arities[f] ||
        sites.parameters[formal]!=kind || sites.formal_sites[formal] as usize!=dst+1){return .err(invalid(offset));}
    let views::Span checked=views::inspect(sites,dst,f,kind,words[dst],payload,offset)?;
    let usize price=fuel::static_instruction(77,0,0);
    if(remaining<price){return .err(errors::make(8,offset));}return .ok(remaining-price);
}
// Authenticate the sole returning word and the exact recipient CALL before
// native leave. Publication is infallible only after leave has also succeeded.
pub fn Result<Returned,errors::Error> returned(ref ir::Program p,ref statics::Sites sites,
    usize payload,usize pc,usize f,ref u32[] words,usize live,
    usize call,usize caller,usize destination,usize caller_live,usize remaining){
    if(!sites.call_profile || pc>=p.count || pc>=256 || f>=p.function_count || f>=16 ||
        pc<p.starts[f] || pc>=p.ends[f] || words.len!=16 || live>=65536 ||
        call>=p.count || call>=256 || caller>=p.function_count || caller>=16 ||
        call<p.starts[caller] || call>=p.ends[caller] || caller_live>=65536 || p.code[pc*8]!=79){return .err(invalid(0));}
    let usize offset=p.offsets[pc];let usize source=p.code[pc*8+2] as usize;let u8 kind=sites.results[f];let usize one=1;
    if(source>=16 || live!=(one<<source) || p.code[call*8]!=78 || p.code[call*8+2] as usize!=f ||
        p.code[call*8+1] as usize!=destination || !site(sites,destination,caller,kind) ||
        sites.definitions[destination]!=call || (caller_live&(one<<destination))!=0){return .err(invalid(offset));}
    let views::Span actual=views::live(sites,source,f,kind,words,live,payload,offset)?;
    let u32 word=words[source];let views::Span checked=views::inspect(sites,destination,caller,kind,word,payload,offset)?;
    let usize price=fuel::static_return();
    if(remaining<price){return .err(errors::make(8,offset));}
    return .ok(Returned{.word=word,.destination=destination,.remaining=remaining-price});
}
