module slice_result_call_ir;
import ir as ir;
import errors as errors;
import struct_range as records;
import types as types;

// 66 CALL_BIND: scalar proof identity, callee, map; byte4 caller-END mask,
// byte5 result site, byte6 surviving parent, byte7 zero.
// 68 END_CAPTURE: child,parent,0; canonical END already belongs to handoff.
// Cleanup markers then 67 BIND_RESULT: child,parent,lo,hi; proof-only range.
pub fn Result<usize,errors::Error> binding(ref ir::Program p,usize pc){
    if(p.count>256 || pc>=p.count){return .err(errors::make(5,0));}
    var usize at=pc+1;while(at<p.count){let u8 op=p.code[at*8];
        if(op==67){return .ok(at);}if(op!=68 && op!=56 && op!=37 && op!=45){return .err(errors::make(5,pc));}at+=1;
    }return .err(errors::make(5,pc));
}
pub fn Result<usize,errors::Error> rewrite(ref mut ir::Program p){
    if(p.count>256 || p.function_count>16){return .err(errors::make(5,0));}
    var bool[256] interior=[false;256];var usize pc=0;var usize count=0;
    while(pc<p.count){let usize at=pc*8;let u8 op=p.code[at];
        if(op==66){
            let usize end=binding(p,pc)?;
            if(p.code[at+7]!=0 || p.code[end*8+1]!=p.code[at+5] || p.code[end*8+2]!=p.code[at+6]){return .err(errors::make(5,pc));}
            var usize i=pc+1;while(i<=end){if(interior[i]){return .err(errors::make(5,i));}interior[i]=true;i+=1;}
            count+=1;
        }pc+=1;
    }
    var usize f=0;while(f<p.function_count){if(p.starts[f]<p.count && interior[p.starts[f]]){return .err(errors::make(5,p.starts[f]));}f+=1;}
    pc=0;while(pc<p.count){let usize at=pc*8;let u8 op=p.code[at];
        if((op==67 || op==68) && !interior[pc]){return .err(errors::make(5,pc));}
        let usize target=if(op==19 || op==22){p.code[at+2] as usize}else if(op==20 || op==21){p.code[at+3] as usize}else if(op==24){p.code[at+4] as usize}else{256};
        if(target<p.count && interior[target]){return .err(errors::make(5,pc));}
        if(op==66){p.code[at]=9;p.code[at+4]=0;p.code[at+5]=0;p.code[at+6]=0;}
        else if(op==67){if(p.code[at+1]>=16){return .err(errors::make(5,pc));}let usize site=p.code[at+1] as usize;let bool exclusive=ir::exclusive(p,site);p.code[at]=if(exclusive){61}else{59};}
        else if(op==68){p.code[at]=62;}
        pc+=1;
    }return .ok(count);
}
pub fn usize creator(ref ir::Program p,usize site){
    var usize pc=0;while(pc<p.count){if(p.code[pc*8]==61 && p.code[pc*8+1] as usize==site){return pc;}pc+=1;}return 256;
}
// Called only after complete normalized CFG/type/loan proof has bounded operands.
fn Result<bool,errors::Error> reads(ref ir::Program p,usize pc,usize r){
    let usize at=pc*8;let u8 op=p.code[at];let usize dst=p.code[at+1] as usize;let usize a=p.code[at+2] as usize;let usize b=p.code[at+3] as usize;
    if((op>=2 && op<=6) || (op>=11 && op<=16) || (op>=28 && op<=32) || op==36 || op==54 || op==60){return .ok(a==r || b==r);}
    if(op==7 || op==8 || op==10 || op==17 || op==18 || op==20 || op==21 || op==24 || op==26 || op==27 || op==33 || op==40){return .ok(a==r);}
    if(op==23){return .ok(a==r && b<=1 && types::payload(p.types[dst],p.code[at+3])!=0);}
    if(op==9){var usize i=0;while(i<p.call_arities[b] as usize){if(p.call_args[b*8+i] as usize==r){return .ok(true);}i+=1;}}
    if(op==35 || op==58){return .ok(b==r);}
    if(op==44){return .ok(b==r);}
    if(op==53 || op==59 || op==61){return .ok(b==r || p.code[at+4] as usize==r);}
    if(op==41 || op==48 || op==49){
        let usize nominal=if(op==49){b}else{p.records.records[dst] as usize};let usize count=records::leaves(ref p.records.layouts,nominal)?;
        return .ok(r>=a && r-a<count);
    }return .ok(false);
}
pub fn Result<usize,errors::Error> inspect(ref ir::Program normalized,ref ir::Program recipes,ref u8[] elements,ref u8[] selected){
    var usize pc=0;var usize count=0;
    while(pc<recipes.count){let usize at=pc*8;
        if(recipes.code[at]==66){
            let usize target=recipes.code[at+2] as usize;let usize map=recipes.code[at+3] as usize;let usize end=binding(recipes,pc)?;
            let usize site=recipes.code[at+5] as usize;let usize parent=recipes.code[at+6] as usize;let usize chosen=selected[target] as usize;
            if(elements[target]==0 || chosen==0 || chosen>normalized.arities[target] ||
                ir::slice_element(normalized,site,pc)?!=(elements[target]&127) || ir::exclusive(normalized,site)!=((elements[target]&128)!=0)){return .err(errors::make(5,pc));}
            let usize mask=recipes.code[at+4] as usize;let usize one=1;
            if(mask>=(one<<normalized.arities[target])){return .err(errors::make(5,pc));}
            var usize expected=0;var usize previous=0;var usize i=0;
            while(i<normalized.arities[target]){if((mask&(one<<i))!=0){
                let usize source=normalized.call_args[map*8+i] as usize;
                if(source<160 || source>=176){return .err(errors::make(5,pc));}
                let usize made=creator(recipes,source-160);
                if(made==256 || made>=pc || (expected!=0 && made<=previous)){return .err(errors::make(5,pc));}previous=made;
                var usize found=0;var usize step=pc+1;
                while(step<end){if(recipes.code[step*8]==68 && recipes.code[step*8+1] as usize==source-160 && recipes.code[step*8+2]==recipes.code[made*8+2]){found+=1;}step+=1;}
                if(found!=1){return .err(errors::make(5,pc));}expected+=1;
            }i+=1;}
            var usize actual=normalized.call_args[map*8+chosen-1] as usize;
            if(actual<160 || actual>=176){return .err(errors::make(5,pc));}actual-=160;
            if((mask&(one<<(chosen-1)))!=0){actual=recipes.code[creator(recipes,actual)*8+2] as usize;}
            if(parent!=actual){return .err(errors::make(5,pc));}
            var usize seen=0;var usize step=pc+1;while(step<end){if(recipes.code[step*8]==68){seen+=1;}step+=1;}
            if(seen!=expected){return .err(errors::make(5,pc));}
            let usize identity=recipes.code[at+1] as usize;step=0;
            while(step<normalized.count){if(reads(normalized,step,identity)?){return .err(errors::make(5,step));}step+=1;}
            count+=1;
        }pc+=1;
    }return .ok(count);
}
