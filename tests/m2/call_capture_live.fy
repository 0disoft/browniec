module tests::m2::call_capture_live;

import call_capture_plan as plans;
import slice_result_owned_execution as owned;
import slice_result_runtime as runtime;
import slice_result_frames as frames;
import slice_result_bindings as bindings;
import ir as ir;
import errors as errors;
import array_slices as slices;

// Compact CALL66 fixture copied from call_capture_plan_tests:fixture(mode0).
// Its final map requires site 2 as an exclusive Held and site 1 as absent.
fn usize fixture(ref mut ir::Program p){
    p.count=9;p.function_count=2;p.entry=0;p.registers=16;
    p.starts[0]=0;p.ends[0]=8;p.starts[1]=8;p.ends[1]=9;
    p.register_starts[0]=0;p.register_ends[0]=8;p.register_starts[1]=8;p.register_ends[1]=16;
    p.arities[0]=1;p.arities[1]=1;p.return_types[0]=1;
    var usize i=0;while(i<16){p.types[i]=12;p.slice_elements[i]=129;p.slice_origins[i]=1;p.slice_functions[i]=1;i+=1;}
    p.slice_parameters[0]=1;p.slice_parameters[8]=1;
    p.call_count=2;p.call_arities[0]=1;p.call_arities[1]=1;p.call_args[0]=161;p.call_args[8]=162;

    // 61 child(site1,parent0); 66 CALL(map0); 67 bind(site2);
    // 66 final(map1,mask1,site3,parent0); END site2; END site1;
    // 67 bind(site3); ordinary return; prepared return.
    p.code[0]=61;p.code[1]=1;p.code[2]=0;p.code[3]=0;p.code[4]=1;
    p.code[8]=66;p.code[9]=2;p.code[10]=1;p.code[11]=0;p.code[12]=0;p.code[13]=2;p.code[14]=1;
    p.code[16]=67;p.code[17]=2;p.code[18]=1;p.code[19]=0;p.code[20]=1;
    p.code[24]=66;p.code[25]=2;p.code[26]=1;p.code[27]=1;p.code[28]=1;p.code[29]=3;p.code[30]=0;
    p.code[32]=68;p.code[33]=2;p.code[34]=1;p.code[40]=68;p.code[41]=1;p.code[42]=0;
    p.code[48]=67;p.code[49]=3;p.code[50]=0;p.code[51]=0;p.code[52]=1;
    p.code[56]=8;p.code[64]=65;
    i=0;while(i<p.count){p.offsets[i]=100+i;i+=1;}return 3;
}

// Synthetic receipts exercise metadata predicates only, not native authority.
fn void receipt(ref mut frames::Frames stack,usize site,usize slot,bool exclusive,bool close_parent,bool drop){
    var runtime::Held held=stack.loans.held[0];
    held.issued=slices::Ticket{.slot=slot,.generation=7};held.active=true;held.frame=1;
    held.exclusive=exclusive;held.close_parent=close_parent;held.drop=drop;
    assert(bindings::retain(ref mut stack.loans,16+site,16,held).is_ok);
}
fn void configure(ref mut frames::Frames stack,usize variant){
    bindings::transferred(ref mut stack.loans,1);stack.frame=1;
    stack.sites[18]=slices::Ticket{.slot=1,.generation=7};
    if(variant!=0){receipt(stack,2,1,variant!=1,variant==2,variant==3);}
    // Required Held is valid here; only the unexpected absent-site Held fails.
    if(variant==4){receipt(stack,1,2,true,false,false);}
}
fn void rejected(ref ir::Program p,ref frames::Frames stack,ref plans::Plan plan,runtime::Contract contract){
    let runtime::Capture[1] none=[runtime::capture(frames::none(),false,false)];
    switch(owned::prepare_enter(p,3,contract,stack,10000000,ref none[..0])){
        case .ok(_):{assert(false);}case .err(a):{assert(a.kind==5 && a.offset==103);}
    };
    switch(owned::prepare_enter_cached(p,3,contract,stack,10000000,ref none[..0],plan)){
        case .ok(_):{assert(false);}case .err(a):{assert(a.kind==5 && a.offset==103);}
    };
}
fn Result<usize,errors::Error> accepted(ref ir::Program p,ref frames::Frames stack,ref plans::Plan plan,runtime::Contract contract){
    let runtime::Capture[1] none=[runtime::capture(frames::none(),false,false)];
    let owned::Prepared a=owned::prepare_enter(p,3,contract,stack,10000000,ref none[..0])?;
    let owned::Prepared b=owned::prepare_enter_cached(p,3,contract,stack,10000000,ref none[..0],plan)?;
    assert(a.count==0 && b.count==0 && a.owned==b.owned && !a.records && !b.records);
    let runtime::Capture x=a.captures[0];let runtime::Capture y=b.captures[0];
    assert(x.ticket.slot==1 && x.ticket.generation==7 && x.ends==2 && x.close && !x.drop);
    assert(y.ticket.slot==x.ticket.slot && y.ticket.generation==x.ticket.generation &&
        y.ends==x.ends && y.close==x.close && y.drop==x.drop);
    return .ok(0);
}
@test fn void cached_and_legacy_dynamic_held_predicates_agree(){
    var ir::Program p=ir::empty();assert(fixture(ref mut p)==3);
    let plans::Plan plan=switch(plans::prepare(ref p)){
        case .ok(v):{v}case .err(_):{assert(false);plans::empty()}
    };
    let plans::Entry entry=switch(plans::lookup(ref plan,ref p,3)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    assert(entry.required==4 && entry.absent==2 && entry.ends[0]==2 && entry.parents[0]==0);
    let runtime::State state=runtime::empty(16);var frames::Frames stack=frames::empty(ref state);
    let runtime::Contract contract=runtime::Contract{.tags=[138,0,0,0,0,0,0,0],.arity=1,.selected=1};
    var usize variant=0;while(variant<5){
        configure(ref mut stack,variant);rejected(ref p,ref stack,ref plan,contract);
        // Neither preparation stores live Held state in the immutable cache.
        configure(ref mut stack,5);assert(accepted(ref p,ref stack,ref plan,contract).is_ok);
        variant+=1;
    }
}
