module value_ir;
import ir as ir;
import value_properties as properties;
import errors as errors;

// Typed value extension of the actual eight-byte IR. Only the independently
// retained private value VM admits it; ordinary/image/reference routes reject.
// Value IDs are a separate 16-slot frame domain.
// 88 MOVE dst,a; 89 COPY dst,a; 90 DROP dst; 91 TAG_BUILD dst,a,variant;
// 92 CASE dst,a,variant,byte4=mismatch PC; 93 CALL dst,callee,map;
// 94 RETURN 0,a; 95 EMPTY_BUFFER dst; 96 SCALAR_READ scalar-dst,a;
// 97 SCALAR_VALUE dst,scalar-a. Except CASE byte4, bytes4..7 are zero.
// Variant1 means some/ok, variant0 none/err, matching existing IR (not a new
// serialized tag layout). CASE none uses dst0; TAG_BUILD none uses a0.
// CALL resource actuals encode 208+value ID; ordinary argument encodings remain.
pub struct Program {
    ir::Program body; properties::Catalog catalog;
    u8[16] types; u8[16] functions; u8[128] parameters; u8[16] results;
}
// Only verifier's private canonical path consumes this independently prepared
// metadata. A public copyable analysis result confers no executable authority.
pub struct Sites { bool enabled; u8[128] parameters; u8[16] results; u8[16] scalar_tags; }
pub struct Prepared { properties::Plan properties; usize[64] classes; Sites sites; }
pub fn Sites empty(){return Sites{.enabled=false,.parameters=[0;128],.results=[0;16],.scalar_tags=[0;16]};}
pub fn bool operation(u8 op){return op>=88 && op<=97;}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
pub fn bool slot(ref Program unit,usize id,usize f){
    return id<16 && unit.types[id]!=0 && unit.functions[id] as usize==f;
}
pub fn usize type_id(ref Program unit,usize id){return (unit.types[id] as usize)-1;}
pub fn bool same(ref Program unit,ref Prepared proof,usize a,usize b){
    return proof.classes[type_id(unit,a)]==proof.classes[type_id(unit,b)];
}
pub fn bool copyable(ref Program unit,ref Prepared proof,usize id){return proof.properties.properties[type_id(unit,id)].copyable;}
pub fn Result<usize,errors::Error> payload(ref Program unit,usize id,usize variant,usize pc){
    let properties::Node node=unit.catalog.nodes[type_id(unit,id)];
    if(variant>1 || (node.kind!=5 && node.kind!=6)){return .err(invalid(pc));}
    return .ok(if(node.kind==5 && variant==0){0}else{
        (if(variant==1){node.first as usize}else{node.second as usize})+1
    });
}
fn bool equivalent(properties::Node a,properties::Node b,ref usize[] classes){
    if(a.kind!=b.kind || a.extent!=b.extent){return false;}
    if(a.kind==5 || a.kind==6){return classes[a.first as usize]==classes[b.first as usize] &&
        (a.kind!=6 || classes[a.second as usize]==classes[b.second as usize]);}
    return a.first==b.first && a.second==b.second;
}
pub fn Result<Prepared,errors::Error> prepare(ref Program unit){
    let ref ir::Program p=ref unit.body;
    if(p.count==0 || p.count>256 || p.registers==0 || p.registers>128 || p.constant_count>128 ||
        p.function_count==0 || p.function_count>16 || p.entry>=p.function_count || p.call_count>32){return .err(invalid(0));}
    let properties::Plan shapes=switch(properties::inspect(ref unit.catalog)){
        case .ok(v):{v}case .err(_):{return .err(invalid(0));}
    };
    var Prepared proof=Prepared{.properties=shapes,.classes=[0;64],.sites=empty()};
    proof.sites.enabled=true;proof.sites.parameters=unit.parameters;proof.sites.results=unit.results;
    // Canonical equivalence handles duplicated DAG nodes without treating plain
    // records with equal layouts as the same nominal type. At most 2016 pairs.
    var usize i=0;while(i<shapes.count){var usize identity=i;var usize j=0;
        while(j<i){if(equivalent(unit.catalog.nodes[i],unit.catalog.nodes[j],ref proof.classes)){
            identity=proof.classes[j];break;}j+=1;}
        proof.classes[i]=identity;i+=1;
    }
    i=0;while(i<16){let usize encoded=unit.types[i] as usize;
        if(encoded>shapes.count || (encoded==0 && unit.functions[i]!=0) ||
            (encoded!=0 && unit.functions[i] as usize>=p.function_count)){return .err(invalid(0));}
        if(encoded!=0 && unit.catalog.nodes[encoded-1].kind==1){proof.sites.scalar_tags[i]=unit.catalog.nodes[encoded-1].first;}
        i+=1;
    }
    var usize code=0;var usize registers=0;var usize formals=0;var usize f=0;let usize one=1;
    while(f<16){let usize result=unit.results[f] as usize;
        if(f>=p.function_count){if(result!=0){return .err(invalid(0));}}
        else{
            if(p.starts[f]!=code || p.ends[f]<=code || p.ends[f]>p.count || p.register_starts[f]!=registers ||
                p.register_ends[f]<registers || p.register_ends[f]>p.registers || p.arities[f]>8 ||
                p.arities[f]>p.register_ends[f]-registers){return .err(invalid(code));}
            if(result!=0 && (result>16 || !slot(unit,result-1,f) || p.return_types[f]!=0 ||
                p.array_results[f]!=0 || p.record_results[f]!=0)){return .err(invalid(code));}
            var usize r=registers;while(r<p.register_ends[f]){let usize value=unit.parameters[r] as usize;
                if(value!=0){
                    if(value>16 || !slot(unit,value-1,f) || r>=registers+p.arities[f] || p.types[r]!=0 ||
                        p.slots[r] || p.array_parameters[r]!=0 || p.record_parameters[r]!=0 || p.slice_parameters[r]!=0 ||
                        (formals&(one<<(value-1)))!=0){return .err(invalid(code));}
                    formals|=one<<(value-1);
                }r+=1;
            }
            code=p.ends[f];registers=p.register_ends[f];
        }f+=1;
    }
    if(code!=p.count || registers!=p.registers || p.arities[p.entry]!=0 || p.return_types[p.entry]!=1 ||
        unit.results[p.entry]!=0){return .err(invalid(0));}
    i=p.registers;while(i<128){if(unit.parameters[i]!=0){return .err(invalid(0));}i+=1;}
    return .ok(proof);
}
// Check every new operation, including dead blocks, before any liveness proof.
pub fn Result<usize,errors::Error> instruction(ref Program unit,ref Prepared proof,usize pc,usize f){
    let ref ir::Program p=ref unit.body;let usize at=pc*8;let u8 op=p.code[at];
    let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    if(!operation(op) || (op!=92 && p.code[at+4]!=0) || p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0){return .err(invalid(pc));}
    if(op==93){
        if(a>=p.function_count || b>=p.call_count || p.call_arities[b] as usize!=p.arities[a]){return .err(invalid(pc));}
        if(unit.results[a]!=0 && (!slot(unit,dst,f) || !same(unit,proof,dst,(unit.results[a] as usize)-1))){return .err(invalid(pc));}
    }else if(op==94){
        if(dst!=0 || b!=0 || !slot(unit,a,f) || unit.results[f]==0 ||
            !same(unit,proof,a,(unit.results[f] as usize)-1)){return .err(invalid(pc));}
    }else if(op==96){
        if(!slot(unit,a,f) || b!=0 || proof.sites.scalar_tags[a]==0 || dst<p.register_starts[f] ||
            dst>=p.register_ends[f] || p.types[dst]!=proof.sites.scalar_tags[a]){return .err(invalid(pc));}
    }else{
        if(op==92){
            if(!slot(unit,a,f) || b>1 || p.code[at+4] as usize<=pc || p.code[at+4] as usize>=p.ends[f]){return .err(invalid(pc));}
            let usize child=payload(unit,a,b,pc)?;
            if(child==0){if(dst!=0){return .err(invalid(pc));}}
            else if(!slot(unit,dst,f) || proof.classes[type_id(unit,dst)]!=proof.classes[child-1]){return .err(invalid(pc));}
        }else{
            if(!slot(unit,dst,f)){return .err(invalid(pc));}
            if(op==88 || op==89){
                if(b!=0 || !slot(unit,a,f) || !same(unit,proof,dst,a) || (op==89 && !copyable(unit,proof,a))){return .err(invalid(pc));}
            }else if(op==90 || op==95){
                if(a!=0 || b!=0 || (op==95 && unit.catalog.nodes[type_id(unit,dst)].kind!=4)){return .err(invalid(pc));}
            }else if(op==91){
                let usize child=payload(unit,dst,b,pc)?;
                if(child==0){if(a!=0){return .err(invalid(pc));}}
                else if(!slot(unit,a,f) || proof.classes[type_id(unit,a)]!=proof.classes[child-1]){return .err(invalid(pc));}
            }else if(op==97){
                if(b!=0 || proof.sites.scalar_tags[dst]==0 || a<p.register_starts[f] || a>=p.register_ends[f] ||
                    p.types[a]!=proof.sites.scalar_tags[dst]){return .err(invalid(pc));}
            }
        }
    }return .ok(pc);
}
