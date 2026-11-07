module output_ir;
import ir as ir;
import static_ir as statics;
import errors as errors;

// PRIVATE EMIT 116: dst=0,a=site,b=1 shared byte view / 2 live byte loan.
// Bytes4..7 are zero. No register or loan is defined, consumed or closed.
pub fn Result<usize,errors::Error> emit(ref mut ir::Program p,usize site,u8 kind,usize at){
    if(site>=16 || (kind!=1 && kind!=2)){return .err(errors::make(3,at));}
    let usize pc=ir::raw(p,116,0,site,kind as usize,at)?;
    p.code[pc*8+4]=0;p.code[pc*8+5]=0;p.code[pc*8+6]=0;p.code[pc*8+7]=0;
    return .ok(pc);
}
pub fn bool canonical(ref ir::Program p,usize pc){
    if(pc>=p.count || pc>=256){return false;}let usize at=pc*8;
    return p.code[at]==116 && p.code[at+1]==0 && p.code[at+2]<16 &&
        (p.code[at+3]==1 || p.code[at+3]==2) && p.code[at+4]==0 &&
        p.code[at+5]==0 && p.code[at+6]==0 && p.code[at+7]==0;
}
// Called inside the complete canonical scalar/owner/loan/CFG proof. Same numeric
// site in the other namespace confers no authority. Suspended exclusive loans fail.
pub fn Result<usize,errors::Error> inspect(ref ir::Program p,ref statics::Sites sites,
    usize pc,usize f,usize live,usize views){
    if(!sites.output || !canonical(p,pc)){return .err(errors::make(5,pc));}
    let usize at=pc*8;let usize site=p.code[at+2] as usize;let usize one=1;
    if(p.code[at+3]==1){
        if(sites.functions[site]!=f || sites.definitions[site]>=pc ||
            (sites.kinds[site]!=1 && sites.kinds[site]!=3) || (views&(one<<site))==0){return .err(errors::make(5,pc));}
    }else{
        if((live&(one<<(32+site)))==0 || (live&(one<<(48+site)))!=0 ||
            ir::slice_element(p,site,pc)?!=10){return .err(errors::make(5,pc));}
        let usize root=p.slice_roots[site] as usize;
        if(root!=0){
            if(root>p.arrays.count || root>16 || p.array_functions[root-1] as usize!=f ||
                (live&(one<<(root-1)))==0){return .err(errors::make(5,pc));}
        }else if(p.slice_functions[site] as usize!=f+1 || p.slice_origins[site]==0){return .err(errors::make(5,pc));}
    }return .ok(pc);
}
