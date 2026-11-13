module tests::m2::value_call_lowering;
import value_call_source_work as work;
import value_source_context as context;
import value_ir as values;
import value_properties as properties;
import value_source_functions as functions;
import functions as signatures;
import lexer as lexer;
import ir as ir;
import metadata_budget as budget;
fn values::Program base(){var values::Program p=values::Program{.body=ir::empty(),.catalog=properties::empty(),.types=[0;16],.functions=[0;16],.parameters=[0;128],.results=[0;16]};p.body.function_count=2;return p;}
@test fn void call_arguments_wait_for_evaluation_capture_and_finalization_once(){
    let ref u8[] declarations=b"module main;fn i32 add(i32 a,i32 b){return a+b;}fn i32 main(){return add(20,22);}";
    var values::Program p=base();let signatures::Table table=switch(signatures::scan_values(declarations,ref mut p.catalog)){case .ok(v):{v}case .err(_):{assert(false);signatures::empty()}};
    let functions::Plan plan=switch(functions::prepare(ref p.catalog,ref table)){case .ok(v):{v}case .err(_):{assert(false);functions::Plan{.results=[0;16],.parameters=[0;128]}}};
    let ref u8[] input=b"(20,22)";var lexer::State s=lexer::empty();assert(lexer::next(input,ref mut s).is_ok);
    var work::Arguments w=work::arguments(0,0,0);var budget::State meter=budget::empty();var usize turns=0;var usize expressions=0;var usize captures=0;var usize finalized=0;
    assert(!work::arguments_result(ref w).is_ok);
    while(!w.done){assert(turns<100);let u8 phase=w.phase;let usize row=w.row;let usize cursor=s.cursor;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance_arguments(input,ref mut s,ref p,ref table,ref plan,ref mut w,ref mut meter).is_ok && meter.total==total && phase==w.phase && row==w.row && cursor==s.cursor);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance_arguments(input,ref mut s,ref p,ref table,ref plan,ref mut w,ref mut meter).is_ok);
        if(w.request!=0){let u8 request=w.request;
            assert(budget::reset(ref mut meter,0).is_ok && work::advance_arguments(input,ref mut s,ref p,ref table,ref plan,ref mut w,ref mut meter).is_ok && meter.last==0);
            if(request==1){assert(lexer::next(input,ref mut s).is_ok);expressions+=1;}else if(request==2){captures+=1;}else{finalized+=1;}
            let usize value=w.row;assert(work::resume_argument(ref mut w,request,context::scalar(0,value),value).is_ok && !work::resume_argument(ref mut w,request,context::nothing(),0).is_ok);}
        turns+=1;
    }
    assert(expressions==2 && captures==2 && finalized==1 && w.arguments[0]==0 && w.arguments[1]==1 && w.captures[0]==16 && w.captures[1]==16 && p.body.count==0);
    let usize total=meter.total;assert(work::advance_arguments(input,ref mut s,ref p,ref table,ref plan,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void constructor_payload_waits_for_close_capture_build_and_drop_once(){
    let values::Program p=base();let ref u8[] input=b".some(42)";var lexer::State s=lexer::empty();assert(lexer::next(input,ref mut s).is_ok);
    var work::Constructor w=work::constructor(64,0);var budget::State meter=budget::empty();var usize children=0;var usize turns=0;
    while(!w.done){assert(turns<100);let u8 phase=w.phase;assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance_constructor(input,ref mut s,ref p,ref mut w,ref mut meter).is_ok && meter.total==total && phase==w.phase);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance_constructor(input,ref mut s,ref p,ref mut w,ref mut meter).is_ok);
        if(w.request!=0){let u8 request=w.request;
            assert(budget::reset(ref mut meter,0).is_ok && work::advance_constructor(input,ref mut s,ref p,ref mut w,ref mut meter).is_ok && meter.last==0);
            if(request==1){assert(lexer::next(input,ref mut s).is_ok);}else{assert(s.kind==0);}
            assert(work::resume_constructor(ref mut w,request,context::scalar(0,0),if(request==2){1}else if(request==3){2}else if(request==4){3}else{0}).is_ok && !work::resume_constructor(ref mut w,request,context::nothing(),0).is_ok);children+=1;}
        turns+=1;
    }
    assert(children==5 && w.payload==2 && w.built==3 && switch(work::constructor_result(ref w)){case .ok(v):{v.typed && v.exact==1 && v.value==3}case .err(_):{false}});
    let usize total=meter.total;assert(work::advance_constructor(input,ref mut s,ref p,ref mut w,ref mut meter).is_ok && meter.total==total && p.body.count==0);
}
