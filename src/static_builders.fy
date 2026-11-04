module static_builders;
import ir as ir;
import errors as errors;
import std::num as num;

fn Result<u8,errors::Error> byte(usize value,usize offset){
    let i64 wide=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{return .err(errors::make(4,offset));}};
    return switch(num::u8_from_i64(wide)){case .ok(v):{.ok(v)}case .err(_):{.err(errors::make(4,offset))}};
}
// Derive the next global definition from actual retained code. Rewinding a pure
// for-post candidate therefore also rewinds Static site allocation.
fn Result<usize,errors::Error> fresh(ref ir::Program p,usize offset){
    if(p.count>256){return .err(errors::make(4,offset));}
    var usize count=0;var usize pc=0;while(pc<p.count){let usize at=pc*8;
        if(p.code[at]==69 || p.code[at]==74 || p.code[at]==75){let usize site=p.code[at+1] as usize;
            if(site>=16){return .err(errors::make(4,offset));}if(site>=count){count=site+1;}}
        pc+=1;
    }if(count==16){return .err(errors::make(4,offset));}return .ok(count);
}
pub fn Result<usize,errors::Error> open(ref mut ir::Program p,usize literal,u8 kind,usize length,usize offset){
    if(literal>=16 || (kind!=1 && kind!=2) || length>4096){return .err(errors::make(4,offset));}
    let usize site=fresh(p,offset)?;let u8 lo=byte(length%256,offset)?;let u8 hi=byte(length/256,offset)?;
    let usize pc=ir::raw(p,69,site,literal,0,offset)?;
    p.code[pc*8+3]=kind;p.code[pc*8+6]=lo;p.code[pc*8+7]=hi;return .ok(site);
}
pub fn Result<usize,errors::Error> bytes(ref mut ir::Program p,usize text,usize offset){
    if(text>=16){return .err(errors::make(3,offset));}
    let usize site=fresh(p,offset)?;let usize pc=ir::raw(p,74,site,text,0,offset)?;return .ok(site);
}
pub fn Result<usize,errors::Error> close(ref mut ir::Program p,usize site,usize offset){
    if(site>=16){return .err(errors::make(3,offset));}return ir::raw(p,70,site,0,0,offset);
}
pub fn Result<usize,errors::Error> scalar(ref mut ir::Program p,usize site,usize index,bool length,usize offset){
    if(site>=16 || (!length && (index>=p.registers || index>=128 || p.types[index]!=12))){return .err(errors::make(3,offset));}
    if(p.registers>=128){return .err(errors::make(4,offset));}
    let usize dst=p.registers;let usize pc=ir::raw(p,if(length){72}else{71},dst,site,if(length){0}else{index},offset)?;
    p.types[dst]=if(length){12}else{10};p.registers+=1;return .ok(dst);
}

// Copy a shared descriptor, preserving its actual kind/range and independent
// Program-image lifetime. Complete source liveness is proved at admission.
pub fn Result<usize,errors::Error> alias(ref mut ir::Program p,usize source,usize offset){
    if(source>=16){return .err(errors::make(3,offset));}
    let usize site=fresh(p,offset)?;let usize pc=ir::raw(p,75,site,source,0,offset)?;return .ok(site);
}

// Type/liveness/image authority are reconstructed independently at admission.
// Source callers enforce the byte-view signature before reaching this builder.
pub fn Result<usize,errors::Error> equal(ref mut ir::Program p,usize left,usize right,usize offset){
    if(left>=16 || right>=16){return .err(errors::make(3,offset));}
    if(p.registers>=128){return .err(errors::make(4,offset));}
    let usize dst=p.registers;let usize pc=ir::raw(p,73,dst,left,right,offset)?;
    p.types[dst]=2;p.registers+=1;return .ok(dst);
}
