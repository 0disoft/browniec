module tests::m2::value_source_predicates;
import value_source as source;
import value_ir as values;
import ir as ir;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn values::Program compiled(ref u8[] text){return switch(source::compile(text)){
    case .ok(v):{v}case .err(_):{assert(false);compiled(text)}
};}
fn void executes(ref values::Program p){
    assert(verifier::inspect_values(p).is_ok);
    assert(switch(vm::run_values(p,10000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void value(ref u8[] text){let values::Program p=compiled(text);executes(ref p);}
fn void rejected(ref u8[] text,u8 kind){
    assert(switch(source::compile(text)){case .ok(_):{false}case .err(e):{e.kind==kind && e.offset<=text.len}});
}
// All predicates in these single-subject fixtures must read the same typed slot.
// Neither even a copyable subject nor an inactive Buffer alternative is captured.
fn void inspected(ref u8[] text,usize expected){
    let values::Program p=compiled(text);let ref ir::Program body=ref p.body;
    var usize pc=0;var usize count=0;var usize subject=16;var usize last=0;
    while(pc<body.count){let usize row=pc*8;
        if(body.code[row]==98){
            let usize actual=body.code[row+2] as usize;
            if(count==0){subject=actual;}assert(actual==subject && actual<16);
            assert(body.code[row+3]<2 && pc+1<body.count);
            // A following explicit discard may legitimately DROP this owner;
            // a predicate-owned DROP would instead carry the same source site.
            assert(body.code[row+8]!=90 || body.code[row+9] as usize!=subject ||
                body.offsets[pc+1]!=body.offsets[pc]);
            last=pc;count+=1;
        }pc+=1;
    }
    assert(count==expected && count!=0);pc=0;
    while(pc<=last){let usize row=pc*8;let u8 op=body.code[row];
        if(op==88 || op==89){assert(body.code[row+2] as usize!=subject);}pc+=1;
    }
    executes(ref p);
}
// A computed subject is owned by its expression: TAG_TEST must be followed by
// explicit DROP of that slot. Simple producer fixtures have exactly one CALL.
fn void temporary(ref u8[] text,usize calls){
    let values::Program p=compiled(text);let ref ir::Program body=ref p.body;
    var usize pc=0;var usize tests=0;var usize actual_calls=0;
    while(pc<body.count){let usize row=pc*8;let u8 op=body.code[row];
        if(op==93 || op==9){actual_calls+=1;}
        if(op==98){
            assert(pc+1<body.count && body.code[row+8]==90);
            assert(body.code[row+9]==body.code[row+2]);tests+=1;
        }pc+=1;
    }
    assert(tests==1 && actual_calls==calls);executes(ref p);
}

@test fn void named_option_predicates_read_both_polarities_without_capturing_active_or_inactive_owners(){
    inspected(b"module main;fn i32 main(){let Option<Buffer> a=.some(bytes::empty());_ = a.is_some;if(a.is_none){return 0;}if(!a.is_some){return 0;}switch(a){case .some(b):{_ = b;return 42;}case .none:{return 0;}}}",3);
    inspected(b"module main;fn i32 main(){let Option<Buffer> a=.none;if(a.is_some){return 0;}if(!a.is_none){return 0;}switch(a){case .some(b):{_ = b;return 0;}case .none:{return 42;}}}",2);
    inspected(b"module main;fn i32 main(){let Option<i32> a=.some(42);if(a.is_none){return 0;}if(!a.is_some){return 0;}switch(a){case .some(n):{return n;}case .none:{return 0;}}}",2);
    inspected(b"module main;fn i32 main(){let Option<i64> a=.none;if(a.is_some){return 0;}if(!a.is_none){return 0;}_ = a;return 42;}",2);
}

@test fn void named_result_predicates_preserve_both_buffer_alternatives_for_real_switches(){
    inspected(b"module main;fn i32 main(){let Result<Buffer,i64> a=.ok(bytes::empty());if(a.is_err){return 0;}if(!a.is_ok){return 0;}switch(a){case .ok(b):{_ = b;return 42;}case .err(n):{_ = n;return 0;}}}",2);
    inspected(b"module main;fn i32 main(){let Result<Buffer,i64> a=.err(42);if(a.is_ok){return 0;}if(!a.is_err){return 0;}switch(a){case .ok(b):{_ = b;return 0;}case .err(n):{if(n==42){return 42;}return 0;}}}",2);
    inspected(b"module main;fn i32 main(){let Result<i64,Buffer> a=.ok(42);if(a.is_err){return 0;}if(!a.is_ok){return 0;}switch(a){case .ok(n):{if(n==42){return 42;}return 0;}case .err(b):{_ = b;return 0;}}}",2);
    inspected(b"module main;fn i32 main(){let Result<i64,Buffer> a=.err(bytes::empty());if(a.is_ok){return 0;}if(!a.is_err){return 0;}switch(a){case .ok(n):{_ = n;return 0;}case .err(b):{_ = b;return 42;}}}",2);
}

@test fn void nested_move_only_wrappers_inspect_outer_tags_and_then_extract_live_or_inactive_payloads(){
    value(b"module main;fn i32 main(){let Option<Result<Buffer,i64>> a=.some(.ok(bytes::empty()));if(!a.is_some){return 0;}switch(a){case .some(r):{if(r.is_err){return 0;}switch(r){case .ok(b):{_ = b;return 42;}case .err(n):{_ = n;return 0;}}}case .none:{return 0;}}}");
    value(b"module main;fn i32 main(){let Option<Result<Buffer,i64>> a=.some(.err(42));if(a.is_none){return 0;}switch(a){case .some(r):{if(!r.is_err){return 0;}switch(r){case .ok(b):{_ = b;return 0;}case .err(n):{if(n==42){return 42;}return 0;}}}case .none:{return 0;}}}");
    inspected(b"module main;fn i32 main(){let Option<Result<Buffer,i64>> a=.none;if(a.is_some){return 0;}if(!a.is_none){return 0;}_ = a;return 42;}",2);
    value(b"module main;fn i32 main(){let Result<Option<Buffer>,Buffer> a=.ok(.none);if(a.is_err){return 0;}switch(a){case .ok(o):{if(!o.is_none){return 0;}_ = o;return 42;}case .err(b):{_ = b;return 0;}}}");
    inspected(b"module main;fn i32 main(){let Result<Option<Buffer>,Buffer> a=.err(bytes::empty());if(a.is_ok){return 0;}if(!a.is_err){return 0;}_ = a;return 42;}",2);
}

@test fn void parenthesized_named_predicates_allow_later_move_call_and_typed_return(){
    value(b"module main;fn Option<Buffer> pass(Option<Buffer> a){if(!(a).is_some){return a;}_ = ((a)).is_none;return (a);}fn i32 main(){let Option<Buffer> a=.some(bytes::empty());_ = (a).is_none;let b=pass(a);switch(b){case .some(v):{_ = v;return 42;}case .none:{return 0;}}}");
    value(b"module main;fn Result<i64,Buffer> pass(Result<i64,Buffer> a){_ = ((a)).is_err;return a;}fn i32 main(){let Result<i64,Buffer> a=.ok(42);if(!(a).is_ok){return 0;}let b=pass(a);switch(b){case .ok(n):{if(n==42){return 42;}return 0;}case .err(v):{_ = v;return 0;}}}");
    inspected(b"module main;fn i32 main(){let Option<Buffer> a=.none;_ = ((a)).is_some;if(!(a).is_none){return 0;}let b=(a);_ = b;return 42;}",2);
}

@test fn void seventeen_named_inspections_reuse_one_typed_slot_and_leave_owner_available(){
    inspected(b"module main;fn i32 main(){let Option<Buffer> a=.some(bytes::empty());_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;_ = a.is_some;switch(a){case .some(b):{_ = b;return 42;}case .none:{return 0;}}}",17);
    inspected(b"module main;fn i32 main(){let Result<i64,Buffer> a=.ok(42);_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a.is_ok;_ = a;return 42;}",17);
}

@test fn void call_and_parenthesized_temporaries_evaluate_once_and_drop_after_tag_test(){
    temporary(b"module main;fn Option<Buffer> made(){return .some(bytes::empty());}fn i32 main(){if(!made().is_some){return 0;}return 42;}",1);
    temporary(b"module main;fn Option<Buffer> made(){return .none;}fn i32 main(){if(!((made())).is_none){return 0;}return 42;}",1);
    temporary(b"module main;fn Result<Buffer,i64> made(){return .ok(bytes::empty());}fn i32 main(){if(!(made()).is_ok){return 0;}return 42;}",1);
    temporary(b"module main;fn Result<i64,Buffer> made(){return .err(bytes::empty());}fn i32 main(){if(!((made())).is_err){return 0;}return 42;}",1);
    temporary(b"module main;fn Result<i64,Buffer> made(){return .ok(42);}fn i32 main(){if(made().is_err){return 0;}return 42;}",1);
}

@test fn void inferred_option_constructor_predicates_drop_computed_nested_and_scalar_subjects(){
    temporary(b"module main;fn i32 main(){if(!.some(bytes::empty()).is_some){return 0;}return 42;}",0);
    temporary(b"module main;fn i32 main(){let bool b=(.some(1)).is_none;if(b){return 0;}return 42;}",0);
    temporary(b"module main;fn i32 main(){if(!(.some(.some(bytes::empty()))).is_some){return 0;}return 42;}",0);
    temporary(b"module main;fn i32 main(){let bool b=.some(1).is_some;if(b){return 42;}return 0;}",0);
}

@test fn void predicates_are_ordinary_bools_in_conditions_comparisons_calls_and_integer_control(){
    inspected(b"module main;fn i32 main(){let Option<Buffer> a=.some(bytes::empty());let bool same=(a.is_some==!a.is_none);var n=40;if(same){n+=2;}if(a.is_some!=true){return 0;}_ = a;return n;}",3);
    value(b"module main;fn i32 choose(bool b){if(b){return 40+2;}return 0;}fn i32 main(){let Result<i64,Buffer> a=.ok(1);let n=choose(a.is_ok==true);_ = a;return n;}");
    value(b"module main;fn bool check(Option<Buffer> a){return a.is_none;}fn i32 main(){let Option<Buffer> a=.none;if(check(a)){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var Option<Buffer> a=.none;if(a.is_none){a=.some(bytes::empty());}if(a.is_some){_ = a;return 42;}return 0;}");
}

@test fn void wrong_wrappers_chained_predicates_and_nonbool_consumers_reject_with_type_errors(){
    rejected(b"module main;fn i32 main(){let Option<Buffer> a=.none;_ = a.is_ok;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Option<i32> a=.some(1);_ = a.is_err;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Result<i64,Buffer> a=.ok(1);_ = a.is_some;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Result<i64,Buffer> a=.err(bytes::empty());_ = a.is_none;return 42;}",3);
    rejected(b"module main;fn i32 main(){let a=bytes::empty();_ = a.is_some;return 42;}",3);
    rejected(b"module main;fn i32 main(){_ = (42).is_ok;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Option<Buffer> a=.none;_ = a.is_none.is_some;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Result<i64,Buffer> a=.ok(1);_ = a.is_ok.is_err;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Option<Buffer> a=.none;_ = a.is_none+1;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Option<Buffer> a=.none;return a.is_none;}",3);
    rejected(b"module main;fn i32 main(){_ = (.ok(1)).is_ok;return 42;}",3);
}

@test fn void method_calls_and_missing_predicate_names_reject_as_syntax_errors(){
    rejected(b"module main;fn i32 main(){let Option<Buffer> a=.none;_ = a.is_none();return 42;}",2);
    rejected(b"module main;fn i32 main(){let Option<Buffer> a=.some(bytes::empty());_ = (a).is_some();return 42;}",2);
    rejected(b"module main;fn i32 main(){let Result<i64,Buffer> a=.ok(1);_ = a.is_ok();return 42;}",2);
    rejected(b"module main;fn i32 main(){let Result<i64,Buffer> a=.err(bytes::empty());_ = a.is_err();return 42;}",2);
    rejected(b"module main;fn i32 main(){let Option<Buffer> a=.none;_ = a.;return 42;}",2);
}

@test fn void moved_scoped_out_unresolved_and_maybe_moved_subject_names_reject(){
    rejected(b"module main;fn i32 main(){let Option<Buffer> a=.none;let b=a;_ = a.is_none;_ = b;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Result<i64,Buffer> a=.ok(1);_ = a;_ = (a).is_ok;return 42;}",3);
    rejected(b"module main;fn void take(Option<Buffer> a){}fn i32 main(){let Option<Buffer> a=.some(bytes::empty());take(a);_ = a.is_some;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Option<Buffer> a=.none;switch(a){case .some(b):{_ = b;}case .none:{}}_ = a.is_none;return 42;}",3);
    rejected(b"module main;fn i32 main(){{let Option<Buffer> a=.none;}_ = a.is_none;return 42;}",3);
    rejected(b"module main;fn i32 main(){_ = missing.is_ok;return 42;}",3);
    rejected(b"module main;fn i32 main(){let Option<Buffer> a=.none;if(false){_ = a;}_ = a.is_none;return 42;}",3);
}
