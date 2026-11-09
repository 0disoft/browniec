module tests::m2::runtime_preparation_work;
import runtime_preparation_work as work;
import metadata_budget as budget;
import ir as ir;
import static_ir as statics;
import call_capture_plan as captures;
import array_list_vm as lists;
import place_dispatch as places;
fn ir::Program body(){var ir::Program p=ir::empty();p.count=1;p.registers=1;p.function_count=1;
    p.ends[0]=1;p.register_ends[0]=1;p.return_types[0]=1;return p;}
fn bool tick(ref mut work::State w,ref ir::Program p,ref captures::Plan calls,ref mut budget::State allowance){
    let statics::Sites sites=statics::empty();let u8[16] parameters=[0;16];
    let lists::Requirement list=lists::Requirement{.length=0,.bytes=0,.cost=0};
    let places::Requirement place=places::Requirement{.width=0,.cost=0,.aggregate=false,.slices=false,.records=false};
    return switch(work::advance(w,p,ref sites,ref parameters,ref list,ref place,0,0,calls,false,allowance)){
        case .ok(v):{v}case .err(_):{assert(false);false}};
}
@test fn void fresh_stages_do_real_checks_without_banking_partial_room(){
    let ir::Program p=body();var captures::Plan calls=captures::empty();calls.ready=true;
    var work::State w=work::empty();var budget::State allowance=budget::empty();
    assert(budget::admit(ref mut allowance,1,0).is_ok);let usize before=allowance.total;
    assert(!tick(ref mut w,ref p,ref calls,ref mut allowance));
    assert(w.phase==0 && w.index==0 && allowance.total==before && allowance.last==1);
    var usize stages=0;while(!w.done){assert(budget::reset(ref mut allowance,0).is_ok);
        let bool done=tick(ref mut w,ref p,ref calls,ref mut allowance);stages+=1;
        assert(allowance.last==4096 && allowance.stages==stages+1 && done==w.done);}
    assert(stages==35 && w.phase==4 && w.index==32);
}
@test fn void malformed_late_cache_entry_rejects_at_its_own_stage(){
    let ir::Program p=body();var captures::Plan calls=captures::empty();calls.ready=true;calls.parents[31*8+7]=17;
    var work::State w=work::empty();var budget::State allowance=budget::empty();
    var usize n=0;while(n<34){assert(budget::reset(ref mut allowance,0).is_ok);
        assert(!tick(ref mut w,ref p,ref calls,ref mut allowance));n+=1;}
    assert(w.phase==3 && w.index==31 && !w.done);
    let statics::Sites sites=statics::empty();let u8[16] parameters=[0;16];
    let lists::Requirement list=lists::Requirement{.length=0,.bytes=0,.cost=0};
    let places::Requirement place=places::Requirement{.width=0,.cost=0,.aggregate=false,.slices=false,.records=false};
    assert(budget::reset(ref mut allowance,0).is_ok);
    switch(work::advance(ref mut w,ref p,ref sites,ref parameters,ref list,ref place,0,0,ref calls,false,ref mut allowance)){
        case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==0);}};
    assert(!w.done && w.index==31 && allowance.last==4096);
}
@test fn void unproved_cache_and_wrong_dimensions_reject_before_entry(){
    var ir::Program p=body();let statics::Sites sites=statics::empty();let u8[16] parameters=[0;16];
    let lists::Requirement list=lists::Requirement{.length=0,.bytes=0,.cost=0};
    let places::Requirement place=places::Requirement{.width=0,.cost=0,.aggregate=false,.slices=false,.records=false};
    var captures::Plan calls=captures::empty();var work::State w=work::empty();var budget::State allowance=budget::empty();
    assert(!work::advance(ref mut w,ref p,ref sites,ref parameters,ref list,ref place,0,0,ref calls,false,ref mut allowance).is_ok);
    assert(w.phase==0 && !w.done);calls.ready=true;p.function_count=17;
    assert(budget::reset(ref mut allowance,0).is_ok);
    assert(!work::advance(ref mut w,ref p,ref sites,ref parameters,ref list,ref place,0,0,ref calls,false,ref mut allowance).is_ok);
    assert(w.phase==0 && !w.done);
}
