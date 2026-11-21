module call_capture_plan;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
import slice_result_call_ir as recipes;

// Immutable recipes for this exact compiled Program. No live loan/owner state
// is cached; callers still authenticate Held receipts against these masks.
pub struct Plan {
    u32[32] pcs; u8[256] ends; u8[256] parents;
    u32[32] required; u32[32] absent; bool ready;
}
// required: Held exists, is exclusive, !close_parent and !drop.
// absent: no Held at that site. Unmasked/unused argument parents are 16.
pub struct Entry { u8[8] ends; u8[8] parents; usize required; usize absent; }
pub fn Plan empty(){
    return Plan{.pcs=[256;32],.ends=[0;256],.parents=[16;256],
        .required=[0;32],.absent=[0;32],.ready=false};
}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
// Bounded conversion without an unchecked narrowing cast or SDK extension.
fn Result<u8,errors::Error> recipe_byte(usize value,usize pc){
    if(value>16){return .err(invalid(pc));}
    var u8 result=0;var usize i=0;
    while(i<value){result+=1;i+=1;}return .ok(result);
}
// Whole-Program proof remains the caller's responsibility. Independently bound
// every operand used here and reject map reuse across all four CALL forms.
pub fn Result<Plan,errors::Error> prepare(ref ir::Program p){
    var usize fuel=budget::unlimited();
    return prepare_metered(p,0,ref mut fuel);
}
pub fn Result<Plan,errors::Error> prepare_metered(ref ir::Program p,usize deadline,ref mut usize fuel){
    if(p.count>256 || p.call_count>32 || p.function_count>16){return .err(invalid(0));}
    var Plan plan=empty();var bool[32] used=[false;32];
    var usize pc=0;var u32 stored_pc=0;let usize one=1;
    while(pc<p.count){
        discard budget::visit(fuel,deadline,pc)?;
        // pc < count <= 256 proves at + 7 < 2048 and stored_pc <= 255.
        let usize at=pc*8;let u8 op=p.code[at];
        if(op==9 || op==64 || op==66 || op==78){
            let usize map=p.code[at+3] as usize;let usize target=p.code[at+2] as usize;
            if(map>=32 || map>=p.call_count || target>=16 || target>=p.function_count){return .err(invalid(pc));}
            let usize arity=p.call_arities[map] as usize;
            if(used[map] || arity>8 || p.arities[target]>8 || arity!=p.arities[target]){return .err(invalid(pc));}
            used[map]=true;
            if(op==66){
                let usize row=map*8;let usize mask=p.code[at+4] as usize;
                if(mask>=(one<<arity)){return .err(invalid(pc));}
                var usize i=0;
                while(i<arity){
                    discard budget::visit(fuel,deadline,pc)?;
                    if((mask&(one<<i))!=0){
                        // The canonical recipe proves source namespace, each
                        // creator/parent link and the sixteen-END bound.
                        let recipes::Chain chain=recipes::chain_metered(p,pc,i,deadline,fuel)?;
                        if(chain.count==0 || chain.count>16 || chain.parent>=16){return .err(invalid(pc));}
                        plan.ends[row+i]=recipe_byte(chain.count,pc)?;
                        plan.parents[row+i]=recipe_byte(chain.parent,pc)?;
                    }i+=1;
                }
                let usize end=recipes::binding_metered(p,pc,deadline,fuel)?;
                if(end<=pc || end>=p.count || end>=256){return .err(invalid(pc));}
                var usize marker=pc+1;
                while(marker<end){
                    discard budget::visit(fuel,deadline,pc)?;
                    let usize marker_at=marker*8;
                    if(p.code[marker_at]==68){
                        let usize site=p.code[marker_at+1] as usize;
                        if(site>=16 || p.code[marker_at+2]>=16){return .err(invalid(pc));}
                        let usize made=recipes::creator_metered(p,site,deadline,fuel)?;
                        // Check the absent-creator sentinel before reading code.
                        if(made>=pc || made>=p.count || made>=256){return .err(invalid(pc));}
                        let usize made_at=made*8;
                        if(p.code[marker_at+2]!=p.code[made_at+2]){return .err(invalid(pc));}
                        var u32 bit=1;var usize shift=0;
                        while(shift<site){bit*=2;shift+=1;}
                        if(p.code[made_at]==67){plan.required[map]|=bit;}
                        else{plan.absent[map]|=bit;}
                    }marker+=1;
                }
                if((plan.required[map]&plan.absent[map])!=0){return .err(invalid(pc));}
                plan.pcs[map]=stored_pc;
            }
        }
        pc+=1;stored_pc+=1;
    }
    plan.ready=true;return .ok(plan);
}
// Constant-size lookup only: one CALL and its eight cached arguments. The
// owning Program pins this cache with the same immutable IR; no recipe scan.
pub fn Result<Entry,errors::Error> lookup(ref Plan plan,ref ir::Program p,usize pc){
    if(!plan.ready || p.count>256 || pc>=p.count || pc>=256 ||
        p.call_count>32 || p.function_count>16){return .err(invalid(pc));}
    let usize at=pc*8;
    if(p.code[at]!=66){return .err(invalid(pc));}
    let usize map=p.code[at+3] as usize;let usize target=p.code[at+2] as usize;
    if(map>=32 || map>=p.call_count || target>=16 || target>=p.function_count){return .err(invalid(pc));}
    let usize arity=p.call_arities[map] as usize;
    if(plan.pcs[map] as usize!=pc || arity>8 || p.arities[target]>8 || arity!=p.arities[target]){return .err(invalid(pc));}
    let usize required=plan.required[map] as usize;let usize absent=plan.absent[map] as usize;
    if(required>65535 || absent>65535 || (required&absent)!=0){return .err(invalid(pc));}
    let usize one=1;let usize mask=p.code[at+4] as usize;
    if(mask>=(one<<arity)){return .err(invalid(pc));}
    var Entry entry=Entry{.ends=[0;8],.parents=[16;8],.required=required,.absent=absent};
    let usize row=map*8;var usize i=0;
    while(i<8){
        let u8 count=plan.ends[row+i];let u8 parent=plan.parents[row+i];
        if(count>16 || (count!=0 && parent>=16)){return .err(invalid(pc));}
        if(i<arity && (mask&(one<<i))!=0){
            let usize source=p.call_args[row+i] as usize;
            if(source<160 || source>=176 || count==0){return .err(invalid(pc));}
        }else if(count!=0 || parent!=16){return .err(invalid(pc));}
        entry.ends[i]=count;entry.parents[i]=parent;i+=1;
    }
    return .ok(entry);
}
