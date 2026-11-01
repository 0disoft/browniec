module slice_reborrow_ir;
import ir as ir;
import errors as errors;
import register_set as registers;
import slice_verifier as slices;
import std::num as num;

// Private op61 begins a child; op62 ends it and restores its parent.
// Prove the forest once from immutable code, not trusted Program metadata.
pub struct Sites { usize[16] parents; usize count; }
fn Sites empty() { return Sites { .parents=[16;16],.count=0 }; }
pub fn bool present(ref ir::Program p) {
    if(p.count>256) { return true; }
    var usize pc=0;
    while(pc<p.count) { if(p.code[pc*8]==61 || p.code[pc*8]==62) { return true; } pc+=1; }
    return false;
}
fn bool compatible(ref ir::Program p,usize child,usize parent) {
    return child<16 && parent<16 && child!=parent && ir::exclusive(p,child) && ir::exclusive(p,parent) &&
        p.slice_roots[child]==p.slice_roots[parent] && p.slice_origins[child]==p.slice_origins[parent] &&
        p.slice_functions[child]==p.slice_functions[parent] && p.slice_elements[child]==p.slice_elements[parent] &&
        (p.slice_roots[child]!=0 || p.slice_origins[child] as usize!=child+1);
}
// Called after ordinary slice metadata and function partitions have been checked.
fn usize function(ref ir::Program p,usize site) {
    let usize root=p.slice_roots[site] as usize;
    return if(root!=0){p.array_functions[root-1] as usize}else{(p.slice_functions[site] as usize)-1};
}
pub fn Result<Sites,errors::Error> metadata(ref ir::Program p) {
    var Sites sites=empty();var usize f=0;
    while(f<p.function_count) {
        var usize pc=p.starts[f];
        while(pc<p.ends[f]) {
            if(p.code[pc*8]==61) {
                let usize child=p.code[pc*8+1] as usize;let usize parent=p.code[pc*8+2] as usize;
                if(!compatible(p,child,parent) || sites.parents[child]!=16 || function(p,child)!=f) { return .err(errors::make(5,pc)); }
                sites.parents[child]=parent;sites.count+=1;
            }
            pc+=1;
        }
        f+=1;
    }
    var usize site=0;
    while(site<16) {
        if(p.slice_roots[site]==0 && ir::exclusive(p,site) && p.slice_origins[site] as usize!=site+1 && sites.parents[site]==16) { return .err(errors::make(5,0)); }
        var usize cursor=site;var usize steps=0;
        while(sites.parents[cursor]!=16) {
            cursor=sites.parents[cursor];steps+=1;
            if(steps>=16) { return .err(errors::make(5,0)); }
        }
        site+=1;
    }
    return .ok(sites);
}

// Construction reserves shape only. Independent metadata/flow proof is required.
pub fn Result<usize,errors::Error> derived(ref mut ir::Program p,usize parent,usize offset) {
    let u8 element=ir::slice_element(p,parent,offset)?;
    if(!ir::exclusive(p,parent)) { return .err(errors::make(3,offset)); }
    let usize root=p.slice_roots[parent] as usize;
    if(root!=0) { return ir::exclusive_slice(p,root-1,offset); }
    let u8 origin=p.slice_origins[parent];let u8 owner=p.slice_functions[parent];
    let usize child=ir::slice_site(p,offset)?;
    p.slice_origins[child]=origin;p.slice_functions[child]=owner;
    p.slice_elements[child]=element|128;
    return .ok(child);
}
fn bool bound(ref ir::Program p,usize r) {
    return r<128 && r<p.registers && p.types[r]==12 && !p.slots[r] &&
        p.array_parameters[r]==0 && p.record_parameters[r]==0 && p.slice_parameters[r]==0;
}
pub fn Result<usize,errors::Error> begin(ref mut ir::Program p,usize child,usize parent,usize lo,usize hi,usize offset) {
    if(!compatible(p,child,parent) || !bound(p,lo) || !bound(p,hi)) { return .err(errors::make(3,offset)); }
    let u8 tag=ir::slice_element(p,child,offset)?;
    let i64 wide=switch(num::i64_from_usize(hi)){case .ok(v):{v}case .err(_):{return .err(errors::make(3,offset));}};
    let u8 end=switch(num::u8_from_i64(wide)){case .ok(v):{v}case .err(_):{return .err(errors::make(3,offset));}};
    let usize pc=ir::raw(p,61,child,parent,lo,offset)?;p.code[pc*8+4]=end;
    return .ok(pc);
}
pub fn Result<usize,errors::Error> end(ref mut ir::Program p,usize child,usize parent,usize offset) {
    if(!compatible(p,child,parent)) { return .err(errors::make(3,offset)); }
    let u8 tag=ir::slice_element(p,child,offset)?;
    return ir::raw(p,62,child,parent,0,offset);
}
fn bool readable(ref ir::Program p,ref registers::Set defined,usize r,usize f) {
    return bound(p,r) && r>=p.register_starts[f] && r<p.register_ends[f] && registers::contains(defined,r);
}

// Existing live bits0..47 retain their meanings. Bits48..63 are suspended sites.
pub fn Result<usize,errors::Error> step(ref ir::Program p,ref Sites sites,usize pc,usize f,
    ref mut registers::Set defined,ref mut registers::Set written,usize live) {
    let usize at=pc*8;let u8 op=p.code[at];let usize child=p.code[at+1] as usize;let usize parent=p.code[at+2] as usize;
    let usize one=1;
    if(op==61 || op==62) {
        if(child>=16 || parent>=16 || sites.parents[child]!=parent || function(p,child)!=f) { return .err(errors::make(5,pc)); }
        let usize root=p.slice_roots[child] as usize;
        if(root!=0 && (live&(one<<(root-1)))==0) { return .err(errors::make(5,pc)); }
        let usize c=one<<(32+child);let usize cs=one<<(48+child);
        let usize a=one<<(32+parent);let usize suspended=one<<(48+parent);
        if(op==61) {
            if((live&(c|cs|suspended))!=0 || (live&a)==0 ||
                !readable(p,defined,p.code[at+3] as usize,f) || !readable(p,defined,p.code[at+4] as usize,f)) { return .err(errors::make(5,pc)); }
            return .ok((live^a)|c|suspended);
        }
        if(p.code[at+3]!=0 || (live&c)==0 || (live&(cs|a))!=0 || (live&suspended)==0) { return .err(errors::make(5,pc)); }
        return .ok((live^(c|suspended))|a);
    }
    let usize id=if(op==55 || op==57 || op==58){parent}else{child};
    if(id<16 && ((live&(one<<(48+id)))!=0 ||
        (sites.parents[id]!=16 && (op==54 || op==56 || op==59)))) { return .err(errors::make(5,pc)); }
    return slices::step(p,pc,f,defined,written,live);
}
