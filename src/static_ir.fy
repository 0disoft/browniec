module static_ir;
import ir as ir;
import static_image as images;
import register_set as registers;
import errors as errors;

// Private Static dialect. Site IDs occupy their own read-only namespace:
// 69 OPEN dst=site,a=literal,b=1 bytes/2 text; bytes4..5 lo,6..7 hi (LE u16).
// 70 CLOSE dst=site,a=b=0. 71 READ u8 dst,a=byte site,b=usize index register.
// 72 LEN usize dst,a=byte site,b=0. 73 EQUAL bool dst,a/b=read-only byte/text sites.
// 74 BYTES dst=new byte site,a=live text site,b=0.
// 75 ALIAS dst=new same-kind site,a=live byte/text site,b=0. Reserved bytes are zero.
// 76 RANGE dst=new byte site,a=live byte site,b=lo usize register,byte4=hi register.
// Bytes5..7 are zero. Dynamic definitions retain their maximum image window.
// Definitions are reconstructed from actual code/image, never caller metadata.
// This copyable proof does not own/pin storage or authenticate a Program handle.
pub struct Sites { usize[16] definitions; usize[16] functions; usize[16] starts; u8[16] kinds; images::Span[16] spans; usize count; usize dynamic; u8[128] parameters; u8[128] formal_sites; u8[16] results; u8[16] origins; usize[16] roots; usize generic; bool call_profile; bool output; }
pub fn Sites empty(){return Sites{.definitions=[256;16],.functions=[16;16],.starts=[0;16],.kinds=[0;16],
    .spans=[images::Span{.literal=16,.start=0,.end=0};16],.count=0,.dynamic=0,.parameters=[0;128],.formal_sites=[0;128],.results=[0;16],.origins=[0;16],.roots=[0;16],.generic=0,.call_profile=false,.output=false};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
pub fn bool operation(u8 op){return op>=69 && op<=77;}

// This checks partitions before reading any PC. Complete ordinary CFG/type/loan
// proof is still mandatory and is supplied by verifier::inspect_statics.
pub fn Result<Sites,errors::Error> definitions(ref ir::Program p,ref images::Image image){
    if(p.count==0 || p.count>256 || p.function_count==0 || p.function_count>16){return .err(invalid(0));}
    switch(images::inspect(image)){case .ok(_):{}case .err(_):{return .err(invalid(0));}};
    var usize end=0;var usize f=0;
    while(f<p.function_count){
        if(p.starts[f]!=end || p.ends[f]<=end || p.ends[f]>p.count){return .err(invalid(0));}
        end=p.ends[f];f+=1;
    }
    if(end!=p.count){return .err(invalid(0));}
    var Sites sites=empty();var usize dynamic=0;let usize one=1;f=0;
    while(f<p.function_count){var usize pc=p.starts[f];while(pc<p.ends[f]){
        let usize at=pc*8;let u8 op=p.code[at];
        if(op==69 || op==74 || op==75 || op==76){
            let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;
            if(dst>=16 || sites.definitions[dst]!=256){return .err(invalid(pc));}
            var images::Span span=images::Span{.literal=16,.start=0,.end=0};var u8 kind=1;
            if(op==69){
                kind=p.code[at+3];if(kind!=1 && kind!=2){return .err(invalid(pc));}
                let u8 actual=switch(images::kind(image,a)){case .ok(v):{v}case .err(_):{return .err(invalid(pc));}};
                if(kind!=actual){return .err(invalid(pc));}
                span=images::Span{.literal=a,.start=p.code[at+4] as usize+256*(p.code[at+5] as usize),
                    .end=p.code[at+6] as usize+256*(p.code[at+7] as usize)};
                switch(images::view(image,span)){case .ok(_):{}case .err(_):{return .err(invalid(pc));}};
                if(kind==2){switch(images::text(image,span)){case .ok(_):{}case .err(_):{return .err(invalid(pc));}};}
            }else{
                if(a>=16 || a==dst || (sites.kinds[a]!=1 && sites.kinds[a]!=2) ||
                    (op==74 && sites.kinds[a]!=2) || (op==76 && sites.kinds[a]!=1) ||
                    sites.functions[a]!=f || sites.definitions[a]>=pc ||
                    (op!=76 && (p.code[at+3]!=0 || p.code[at+4]!=0)) ||
                    p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0){return .err(invalid(pc));}
                span=sites.spans[a];kind=if(op==75){sites.kinds[a]}else{1};
                if(op==76 || (dynamic&(one<<a))!=0){dynamic|=one<<dst;}
            }
            let usize absolute=switch(images::absolute(image,span)){case .ok(v):{v}case .err(_):{return .err(invalid(pc));}};
            sites.definitions[dst]=pc;sites.functions[dst]=f;sites.starts[dst]=absolute;sites.kinds[dst]=kind;sites.spans[dst]=span;sites.count+=1;
        }
        pc+=1;
    }f+=1;}sites.dynamic=dynamic;return .ok(sites);
}
fn bool live_site(ref Sites sites,usize site,usize f,u8 kind,usize live){
    let usize one=1;
    return site<16 && sites.functions[site]==f && (sites.kinds[site]==1 || sites.kinds[site]==2 || sites.kinds[site]==3) &&
        (kind==0 || sites.kinds[site]==kind || (kind==1 && sites.kinds[site]==3)) && (live&(one<<site))!=0;
}
fn bool scalar(ref ir::Program p,ref registers::Set defined,usize r,usize f){
    return r>=p.register_starts[f] && r<p.register_ends[f] && r<128 && !p.slots[r] &&
        p.array_parameters[r]==0 && p.record_parameters[r]==0 && p.slice_parameters[r]==0 && registers::contains(defined,r);
}
// Check live Static views independently from array owners, formal captures and
// exclusive loans. Equal scalar register values can never manufacture a site.
pub fn Result<usize,errors::Error> step(ref ir::Program p,ref Sites sites,usize pc,usize f,
    ref mut registers::Set defined,ref mut registers::Set written,usize live){
    if(p.count>256 || pc>=p.count || f>=p.function_count || f>=16 || sites.count>16){return .err(invalid(pc));}
    let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;
    let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;let usize one=1;
    if(!operation(op) || sites.count==0){return .err(invalid(pc));}
    if(op!=69 && op!=76 && (p.code[at+4]!=0 || p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0)){return .err(invalid(pc));}
    if(op==69 || op==74 || op==75 || op==76 || op==77){
        if(dst>=16 || sites.definitions[dst]!=pc || sites.functions[dst]!=f || (live&(one<<dst))!=0 ||
            ((op==74 || op==75) && (!live_site(sites,a,f,if(op==74){2}else{0},live) || b!=0))){return .err(invalid(pc));}
        if(op==77){
            if(a<p.register_starts[f] || a>=p.register_starts[f]+p.arities[f] ||
                sites.parameters[a]!=p.code[at+3] || sites.formal_sites[a] as usize!=dst+1 || p.types[a]!=0 ||
                (b!=1 && b!=2 && b!=3)){return .err(invalid(pc));}
        }
        if(op==76){let usize hi=p.code[at+4] as usize;
            if(!live_site(sites,a,f,1,live) || !scalar(p,defined,b,f) || !scalar(p,defined,hi,f) ||
                p.types[b]!=12 || p.types[hi]!=12 || p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0){return .err(invalid(pc));}}
        return .ok(live|(one<<dst));
    }
    if(op==70){
        if(dst>=16 || sites.functions[dst]!=f || sites.kinds[dst]==0 || (live&(one<<dst))==0 || a!=0 || b!=0){return .err(invalid(pc));}
        return .ok(live^(one<<dst));
    }
    if(op==71 || op==72){
        if(!live_site(sites,a,f,1,live) || (op==71 && (!scalar(p,defined,b,f) || p.types[b]!=12)) ||
            (op==72 && b!=0)){return .err(invalid(pc));}
    }else if(op==73){if(!live_site(sites,a,f,0,live) || !live_site(sites,b,f,0,live) ||
        sites.kinds[a]==3 || sites.kinds[b]==3){return .err(invalid(pc));}}
    else{return .err(invalid(pc));}
    let u8 tag=if(op==71){10}else if(op==72){12}else{2};
    if(dst<p.register_starts[f] || dst>=p.register_ends[f] || dst>=128 || p.slots[dst] ||
        p.array_parameters[dst]!=0 || p.record_parameters[dst]!=0 || p.slice_parameters[dst]!=0 ||
        p.types[dst]!=tag || registers::contains(written,dst)){return .err(invalid(pc));}
    registers::insert(defined,dst);registers::insert(written,dst);return .ok(live);
}
