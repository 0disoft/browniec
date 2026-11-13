module tests::m2::value_ownership_lowering;
import value_source_bindings as bindings;
import value_view_bindings as views;
import value_ir as values;
import value_properties as properties;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
fn values::Program base(){var values::Program p=values::Program{.body=ir::empty(),.catalog=properties::empty(),.types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};p.body.function_count=1;return p;}
fn void result(Result<usize,errors::Error> a,Result<usize,errors::Error> b){switch(a){case .ok(x):{assert(switch(b){case .ok(y):{x==y}case .err(_):{false}});}case .err(x):{assert(switch(b){case .ok(_):{false}case .err(y):{x.kind==y.kind && x.offset==y.offset}});}};}
@test fn void ownership_authentication_matches_raw_for_valid_and_corrupted_ledgers(){
    var usize scenario=0;while(scenario<12){var values::Program p=base();var bindings::State s=bindings::empty();
        if(scenario==1){s.next=17;}if(scenario==2){s.names.count=65;}if(scenario==3){s.views.retained=65536;}
        if(scenario==4){s.views.origins[15]=26;}if(scenario==5){s.views.names[63]=17;}if(scenario==6){p.types[15]=1;}
        if(scenario==7){s.views.origins[0]=1;}if(scenario==8){s.views.names[63]=1;}if(scenario==9){s.live=1;}
        if(scenario==10){s.tracking=false;s.required=1;}if(scenario==11){p.body.function_count=0;}
        result(bindings::header_raw(ref p,ref s,7),bindings::authenticate(ref p,ref s,7));
        result(views::validate_raw(ref s.views,9),views::validate(ref s.views,9));
        result(views::authenticate_raw(ref p,ref s.views,11),views::authenticate(ref p,ref s.views,11));
        assert(p.body.count==0 && s.next==if(scenario==1){17}else{0});scenario+=1;
    }
}
@test fn void ownership_authentication_steps_guard_denial_completion_and_dependency_rows(){
    let values::Program p=base();let bindings::State s=bindings::empty();var bindings::Auth w=bindings::auth(19);var budget::State meter=budget::empty();var usize turns=0;
    assert(!bindings::auth_result(ref s,ref w).is_ok);
    while(!w.done){assert(turns<2000);let u8 phase=w.phase;let usize row=w.row;let usize owner=w.owner;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(bindings::advance_auth(ref p,ref s,ref mut w,ref mut meter).is_ok && meter.total==total && w.phase==phase && w.row==row && w.owner==owner);
        assert(budget::reset(ref mut meter,0).is_ok && bindings::advance_auth(ref p,ref s,ref mut w,ref mut meter).is_ok);
        if(phase==5){assert(w.owner==owner+1 && w.row==row || owner==15 && w.row==row+1 && w.phase==4);}turns+=1;
    }
    assert(turns>400 && bindings::auth_result(ref s,ref w).is_ok && p.body.count==0 && s.live==0);
    let usize total=meter.total;assert(bindings::advance_auth(ref p,ref s,ref mut w,ref mut meter).is_ok && meter.total==total);
}
