module call_capture_plan_tests;
import call_capture_plan as plans;
import slice_result_call_ir as recipes;
import ir as ir;
import errors as errors;
import std::num as num;

// Focused native kernel only. Parent owns compile/runner/Engine integration.
// The cache is trusted and bound to its immutable Program, not raw-IR proof.
unsafe extern C fn usize probe_live();
unsafe extern C fn usize probe_live_bytes();
unsafe extern C fn usize probe_attempts();
struct Heap { usize blocks; usize bytes; usize attempts; }
fn Heap heap(){return Heap{.blocks=unsafe{probe_live()},.bytes=unsafe{probe_live_bytes()},.attempts=unsafe{probe_attempts()}};}
fn void unchanged(ref Heap h){assert(unsafe{probe_live()}==h.blocks && unsafe{probe_live_bytes()}==h.bytes && unsafe{probe_attempts()}==h.attempts);}
fn u8 byte(usize n){return switch(num::i64_from_usize(n)){case .ok(v):{switch(num::u8_from_i64(v)){case .ok(b):{b}case .err(_):{assert(false);0}}}case .err(_):{assert(false);0}};}
fn plans::Plan prepared(ref ir::Program p){let Heap h=heap();let Result<plans::Plan,errors::Error> r=plans::prepare(p);unchanged(ref h);
    return switch(r){case .ok(v):{assert(v.ready);v}case .err(_):{assert(false);plans::empty()}};}
fn plans::Entry entry(ref plans::Plan plan,ref ir::Program p,usize pc){let Heap h=heap();let Result<plans::Entry,errors::Error> r=plans::lookup(plan,p,pc);unchanged(ref h);
    return switch(r){case .ok(v):{v}case .err(_):{assert(false);plans::Entry{.ends=[0;8],.parents=[16;8],.required=0,.absent=0}}};}
fn void rejected_prepare(ref ir::Program p){let Heap h=heap();switch(plans::prepare(p)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};unchanged(ref h);}
fn void rejected_lookup(ref plans::Plan plan,ref ir::Program p,usize pc){let Heap h=heap();switch(plans::lookup(plan,p,pc)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5);}};unchanged(ref h);}
fn void same_entry(plans::Entry a,plans::Entry b){assert(a.required==b.required && a.absent==b.absent);var usize i=0;while(i<8){assert(a.ends[i]==b.ends[i] && a.parents[i]==b.parents[i]);i+=1;}}
fn void same_plan(ref plans::Plan a,ref plans::Plan b){assert(a.ready==b.ready);var usize i=0;while(i<32){assert(a.pcs[i]==b.pcs[i] && a.required[i]==b.required[i] && a.absent[i]==b.absent[i]);i+=1;}
    i=0;while(i<256){assert(a.ends[i]==b.ends[i] && a.parents[i]==b.parents[i]);i+=1;}}
// Mutate one caller-owned Program in place; helpers never copy its large value.
fn void instruction(ref mut ir::Program p,usize pc,u8 op,usize dst,usize a,usize b){assert(pc<256);let usize at=pc*8;
    p.code[at]=op;p.code[at+1]=byte(dst);p.code[at+2]=byte(a);p.code[at+3]=byte(b);p.code[at+4]=0;p.code[at+5]=0;p.code[at+6]=0;p.code[at+7]=0;p.offsets[pc]=100+pc;}
fn void dimensions(ref mut ir::Program p,usize count,usize arity){p.count=count;p.function_count=2;p.entry=0;p.registers=16;
    p.starts[0]=0;p.ends[0]=count-1;p.starts[1]=count-1;p.ends[1]=count;p.register_starts[0]=0;p.register_ends[0]=8;p.register_starts[1]=8;p.register_ends[1]=16;
    p.arities[0]=1;p.arities[1]=arity;p.return_types[0]=1;var usize i=0;while(i<16){p.types[i]=12;p.slice_elements[i]=129;p.slice_origins[i]=1;p.slice_functions[i]=1;i+=1;}
    p.slice_parameters[0]=1;i=0;while(i<arity){p.slice_parameters[8+i]=byte(i+1);i+=1;}}
fn void call66(ref mut ir::Program p,usize pc,usize map,usize mask,usize site,usize parent){instruction(p,pc,66,2,1,map);p.code[pc*8+4]=byte(mask);p.code[pc*8+5]=byte(site);p.code[pc*8+6]=byte(parent);}
fn void bind(ref mut ir::Program p,usize pc,usize site,usize parent){instruction(p,pc,67,site,parent,0);p.code[pc*8+4]=1;}
fn void child(ref mut ir::Program p,usize pc,usize site,usize parent){instruction(p,pc,61,site,parent,0);p.code[pc*8+4]=1;}

// 0: two linked creators (61 then prior CALL66/BIND67), final CALL at 3.
// 1: all eight mask bits, eight sibling children. 2: sites 0..15 form one
// chain. Every CALL is strictly after its creators; END68 order is descending.
fn usize fixture(ref mut ir::Program p,usize mode){assert(mode<3);
    if(mode==0){dimensions(p,9,1);p.call_count=2;p.call_arities[0]=1;p.call_arities[1]=1;p.call_args[0]=161;p.call_args[8]=162;
        child(p,0,1,0);call66(p,1,0,0,2,1);bind(p,2,2,1);call66(p,3,1,1,3,0);
        instruction(p,4,68,2,1,0);instruction(p,5,68,1,0,0);bind(p,6,3,0);instruction(p,7,8,0,0,0);instruction(p,8,65,0,0,0);return 3;}
    let usize children=if(mode==1){8}else{15};let usize arity=if(mode==1){8}else{1};let usize pc=children;let usize bound=2*children+1;
    dimensions(p,bound+3,arity);p.call_count=1;p.call_arities[0]=byte(arity);var usize i=0;
    while(i<children){child(p,i,i+1,if(mode==1){15}else{i});i+=1;}
    i=0;while(i<arity){p.call_args[i]=byte(160+if(mode==1){i+1}else{15});i+=1;}
    call66(p,pc,0,if(mode==1){255}else{1},if(mode==1){9}else{1},if(mode==1){15}else{0});
    i=0;while(i<children){let usize site=children-i;instruction(p,pc+1+i,68,site,if(mode==1){15}else{site-1},0);i+=1;}
    bind(p,bound,if(mode==1){9}else{1},if(mode==1){15}else{0});instruction(p,bound+1,8,0,0,0);instruction(p,bound+2,65,0,0,0);return pc;
}
fn void mixed_calls(ref mut ir::Program p){dimensions(p,7,1);p.call_count=4;let u8[4] ops=[9,64,66,78];let usize[4] pcs=[0,1,2,4];var usize i=0;
    while(i<4){instruction(p,pcs[i],ops[i],2,1,i);p.call_arities[i]=1;p.call_args[i*8]=160;i+=1;}
    p.code[2*8+5]=1;bind(p,3,1,0);instruction(p,5,8,0,0,0);instruction(p,6,65,0,0,0);}

// 1. An unprepared empty cache cannot be used, even against a no-CALL body.
fn void empty_and_no_call(){var ir::Program p=ir::empty();let plans::Plan blank=plans::empty();assert(!blank.ready);rejected_lookup(ref blank,ref p,0);
    let plans::Plan vacant=prepared(ref p);rejected_lookup(ref vacant,ref p,0);
    p.count=1;p.function_count=1;p.registers=1;p.ends[0]=1;p.register_ends[0]=1;p.return_types[0]=1;p.types[0]=1;instruction(ref mut p,0,8,0,0,0);
    let plans::Plan ready=prepared(ref p);rejected_lookup(ref ready,ref p,0);rejected_lookup(ref ready,ref p,256);let plans::Plan again=plans::empty();same_plan(ref blank,ref again);}

// 2. Actual recipes are one oracle; explicit small numeric answers are another.
// The required/absent receipt masks are checked alongside END counts/parents.
fn plans::Entry oracle(ref ir::Program p,usize pc){var plans::Entry expected=plans::Entry{.ends=[0;8],.parents=[16;8],.required=0,.absent=0};
    let usize row=(p.code[pc*8+3] as usize)*8;let usize arity=p.call_arities[p.code[pc*8+3] as usize] as usize;let usize mask=p.code[pc*8+4] as usize;let usize one=1;
    var usize i=0;while(i<arity){if((mask&(one<<i))!=0){let recipes::Chain chain=switch(recipes::chain(p,pc,i)){case .ok(v):{v}case .err(_):{assert(false);recipes::Chain{.parent=16,.count=0}}};
        assert(chain.count>0 && chain.count<=16 && chain.parent<16 && p.call_args[row+i]>=160);expected.ends[i]=byte(chain.count);expected.parents[i]=byte(chain.parent);}i+=1;}
    let usize end=switch(recipes::binding(p,pc)){case .ok(v):{v}case .err(_):{assert(false);256}};
    var usize marker=pc+1;while(marker<end){if(p.code[marker*8]==68){let usize site=p.code[marker*8+1] as usize;let usize made=recipes::creator(p,site);assert(site<16 && made<pc);
        assert(p.code[marker*8+2]==p.code[made*8+2]);if(p.code[made*8]==67){expected.required|=one<<site;}else{expected.absent|=one<<site;}}marker+=1;}
    return expected;}
fn void recipe_parity_and_numeric_extremes(){var usize mode=0;while(mode<3){var ir::Program p=ir::empty();let usize pc=fixture(ref mut p,mode);let plans::Plan plan=prepared(ref p);
    let plans::Entry actual=entry(ref plan,ref p,pc);same_entry(actual,oracle(ref p,pc));let usize bound=switch(recipes::binding(ref p,pc)){case .ok(v):{v}case .err(_):{assert(false);256}};
    if(mode==0){assert(pc==3 && bound==6 && actual.required==4 && actual.absent==2 && recipes::creator(ref p,1)==0 && recipes::creator(ref p,2)==2);
        same_entry(actual,plans::Entry{.ends=[2,0,0,0,0,0,0,0],.parents=[0,16,16,16,16,16,16,16],.required=4,.absent=2});
        let plans::Entry earlier=entry(ref plan,ref p,1);same_entry(earlier,oracle(ref p,1));same_entry(earlier,plans::Entry{.ends=[0;8],.parents=[16;8],.required=0,.absent=0});}
    else if(mode==1){assert(pc==8 && bound==17 && actual.required==0 && actual.absent==510);same_entry(actual,plans::Entry{.ends=[1;8],.parents=[15;8],.required=0,.absent=510});
        var usize site=1;while(site<=8){assert(recipes::creator(ref p,site)==site-1);site+=1;}}
    else{assert(pc==15 && bound==31 && actual.required==0 && actual.absent==65534);same_entry(actual,plans::Entry{.ends=[15,0,0,0,0,0,0,0],.parents=[0,16,16,16,16,16,16,16],.required=0,.absent=65534});
        var usize site=1;while(site<16){assert(recipes::creator(ref p,site)==site-1);site+=1;}}
    assert(recipes::creator(ref p,16)==256);mode+=1;}}

// 3. prepare bounds its own reads and rejects reused maps even across ordinary,
// forwarding, returned-view and reference-aware CALL forms. No source proof is
// substituted for these independent kernel admission checks.
fn void dimensions_maps_and_error_before_index(){var ir::Program p=ir::empty();mixed_calls(ref mut p);let plans::Plan valid=prepared(ref p);assert(valid.ready);
    let usize[4] pcs=[0,1,2,4];var usize i=0;while(i<4){let usize next=(i+1)%4;let usize at=pcs[next]*8+3;let u8 saved=p.code[at];p.code[at]=byte(i);rejected_prepare(ref p);p.code[at]=saved;i+=1;}
    p.count=257;rejected_prepare(ref p);p.count=7;p.call_count=33;rejected_prepare(ref p);p.call_count=4;p.function_count=17;rejected_prepare(ref p);p.function_count=2;
    p.code[3]=32;rejected_prepare(ref p);p.code[3]=4;rejected_prepare(ref p);p.code[3]=0;
    p.code[2]=16;rejected_prepare(ref p);p.code[2]=2;rejected_prepare(ref p);p.code[2]=1;
    p.call_arities[0]=9;rejected_prepare(ref p);p.call_arities[0]=1;p.arities[1]=9;rejected_prepare(ref p);p.arities[1]=2;rejected_prepare(ref p);p.arities[1]=1;
    let plans::Plan recovered=prepared(ref p);same_plan(ref valid,ref recovered);}
// Keep this Program in a separate frame, never beside a copied large Program.
fn void missing_creator_before_index(){var ir::Program missing=ir::empty();let usize pc=fixture(ref mut missing,0);missing.code[0]=19;rejected_prepare(ref missing);assert(pc==3);
    missing.code[0]=61;missing.code[4*8+1]=16;rejected_prepare(ref missing);missing.code[4*8+1]=2;missing.code[4*8+2]=16;rejected_prepare(ref missing);}

// 4. Cache moves preserve recipes with zero SDK attempts. lookup only promises
// ready/PC/map/shape/range guards, not re-proving chains or authenticating edits.
fn void frozen_moves_and_lookup_guards(){var ir::Program p=ir::empty();let usize pc=fixture(ref mut p,0);let plans::Plan initial=prepared(ref p);let plans::Plan saved=initial;
    let Heap h=heap();var plans::Plan moved=initial;let plans::Plan final=moved;unchanged(ref h);same_plan(ref saved,ref final);let plans::Entry wanted=oracle(ref p,pc);
    same_entry(entry(ref final,ref p,pc),wanted);same_entry(entry(ref final,ref p,pc),wanted);same_plan(ref final,ref saved);
    rejected_lookup(ref final,ref p,pc+1);rejected_lookup(ref final,ref p,p.count);rejected_lookup(ref final,ref p,256);rejected_lookup(ref final,ref p,18446744073709551615);
    moved=final;moved.ready=false;rejected_lookup(ref moved,ref p,pc);moved=final;moved.pcs[1]=256;rejected_lookup(ref moved,ref p,pc);moved=final;moved.pcs[1]=1;rejected_lookup(ref moved,ref p,pc);
    moved=final;moved.ends[8]=17;rejected_lookup(ref moved,ref p,pc);moved=final;moved.ends[8]=0;rejected_lookup(ref moved,ref p,pc);
    moved=final;moved.parents[8]=16;rejected_lookup(ref moved,ref p,pc);moved=final;moved.ends[9]=1;rejected_lookup(ref moved,ref p,pc);moved=final;moved.parents[9]=0;rejected_lookup(ref moved,ref p,pc);
    moved=final;moved.required[1]=6;rejected_lookup(ref moved,ref p,pc);
    p.code[pc*8+3]=32;rejected_lookup(ref final,ref p,pc);p.code[pc*8+3]=2;rejected_lookup(ref final,ref p,pc);p.code[pc*8+3]=0;rejected_lookup(ref final,ref p,pc);p.code[pc*8+3]=1;
    p.call_arities[1]=9;rejected_lookup(ref final,ref p,pc);p.call_arities[1]=0;rejected_lookup(ref final,ref p,pc);p.call_arities[1]=1;
    p.code[pc*8+4]=2;rejected_lookup(ref final,ref p,pc);p.code[pc*8+4]=1;p.call_args[8]=159;rejected_lookup(ref final,ref p,pc);p.call_args[8]=176;rejected_lookup(ref final,ref p,pc);p.call_args[8]=162;
    same_entry(entry(ref final,ref p,pc),wanted);same_plan(ref final,ref saved);unchanged(ref h);}
pub fn void run(){let Heap before=heap();empty_and_no_call();recipe_parity_and_numeric_extremes();dimensions_maps_and_error_before_index();missing_creator_before_index();frozen_moves_and_lookup_guards();unchanged(ref before);}
