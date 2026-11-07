module tests::m2::value_view_join_origins;
import functions as functions;
import slice_result_source_origins as origins;

fn void selected(ref u8[] source,usize f,u8 expected,bool ordinary){
    var functions::Table t=switch(if(ordinary){functions::scan(source)}else{functions::scan_reference_returns(source)}){
        case .ok(v):{v}case .err(_):{assert(false);functions::empty()}
    };
    assert(origins::infer(source,ref mut t).is_ok);assert(t.return_slice_inputs[f]==expected);
}
fn void rejected(ref u8[] source){
    var functions::Table t=switch(functions::scan_reference_returns(source)){
        case .ok(v):{v}case .err(_):{assert(false);functions::empty()}
    };
    assert(!origins::infer(source,ref mut t).is_ok);
}
@test fn void mutable_bindings_and_same_input_if_control_rebindings_ground(){
    selected(b"module main;fn ref u8[] f(ref u8[] a,bool c){var r=a;if(c){r=a[1..];}else{r=a[..];}return r;}fn i32 main(){return 42;}",0,1,false);
    selected(b"module main;fn ref u8[] f(ref u8[] a,bool c){var ref u8[] r=ref a;if(c){r=ref a[1..];}return ref r;}fn i32 main(){return 42;}",0,1,false);
    selected(b"module main;fn ref mut i32[] f(ref mut i32[] a,bool c){var ref mut i32[] r=ref mut a;if(c){r=ref mut a[1..];}return ref mut r;}fn i32 main(){return 42;}",0,1,true);
}
@test fn void nested_if_switch_values_and_forward_selected_calls_ground(){
    selected(b"module main;fn ref u8[] f(ref u8[] a,ref u8[] b,bool c){var r=if(c){g(ref b,ref a)}else{switch(c){case true:{a[1..]}case false:{g(ref b,ref a)}}};r=if(c){r}else{a};return r;}fn ref u8[] g(ref u8[] a,ref u8[] b){return b;}fn i32 main(){return 42;}",0,1,false);
    selected(b"module main;fn ref u8[] f(ref u8[] a,bool c){return if(c){a}else if(c){a[1..]}else{a[..]};}fn i32 main(){return 42;}",0,1,false);
    selected(b"module main;fn ref i32[] f(ref i32[] a,bool c){return ref if(c){ref a}else{ref a[1..]};}fn i32 main(){return 42;}",0,1,true);
}
@test fn void continuing_paths_exclude_returning_arms_and_restore_branch_entry(){
    selected(b"module main;fn ref u8[] f(ref u8[] a,ref u8[] b,bool c){var r=b;if(c){r=a;}else{r=a;}return r;}fn i32 main(){return 42;}",0,1,false);
    selected(b"module main;fn ref u8[] f(ref u8[] a,ref u8[] b,bool c){var r=a;if(c){return a;}else{r=a[1..];}return r;}fn i32 main(){return 42;}",0,1,false);
    selected(b"module main;fn ref u8[] f(ref u8[] a,bool c){return switch(c){case true:{return a;}case false:{a[1..]}};}fn i32 main(){return 42;}",0,1,false);
}
@test fn void switch_rebindings_and_lexical_shadowing_preserve_outer_bindings(){
    selected(b"module main;fn ref u8[] f(ref u8[] a,ref u8[] b,bool c){var r=a;switch(c){case true:{r=a[1..];}case false:{r=a[..];}}{let r=b;}return r;}fn i32 main(){return 42;}",0,1,false);
    rejected(b"module main;fn ref u8[] f(ref u8[] a,bool c){switch(c){case .some(a):{return a;}case .none:{return a;}}}fn i32 main(){return 42;}");
}
@test fn void different_formals_missing_else_and_sequential_branch_pollution_reject(){
    rejected(b"module main;fn ref u8[] f(ref u8[] a,ref u8[] b,bool c){return if(c){a}else{b};}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] f(ref u8[] a,ref u8[] b,bool c){var r=a;if(c){r=b;}return r;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] f(ref u8[] a,ref u8[] b,bool c){var r=a;if(c){r=b;}else{r=r;}return r;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] f(ref u8[] a,ref u8[] b,bool c){var r=a;switch(c){case true:{r=b;}case false:{r=a;}}return r;}fn i32 main(){return 42;}");
}
@test fn void branch_local_escape_and_type_shadowing_reject(){
    rejected(b"module main;fn ref u8[] f(ref u8[] a,bool c){var r=a;if(c){let b=bytes::empty();r=bytes::view(ref b);}return r;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] f(ref u8[] a,bool c){return if(c){a}else{let b=bytes::empty();bytes::view(ref b)};}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] f(ref u8[] a){let u8 a=42;return a;}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] f(ref u8[] a){return ........................................a;}fn i32 main(){return 42;}");
}
@test fn void grounded_recursive_joins_revisit_all_pending_paths(){
    selected(b"module main;fn ref u8[] f(ref u8[] a,bool c){var r=if(c){a}else{g(ref a,c)};return r;}fn ref u8[] g(ref u8[] a,bool c){return f(ref a,c);}fn i32 main(){return 42;}",1,1,false);
    rejected(b"module main;fn ref u8[] f(ref u8[] a,ref u8[] b,bool c){return if(c){a}else{g(ref a,ref b,c)};}fn ref u8[] g(ref u8[] a,ref u8[] b,bool c){return if(c){b}else{f(ref a,ref b,c)};}fn i32 main(){return 42;}");
    rejected(b"module main;fn ref u8[] f(ref u8[] a,bool c){return if(c){g(ref a,c)}else{f(ref a,c)};}fn ref u8[] g(ref u8[] a,bool c){return f(ref a,c);}fn i32 main(){return 42;}");
}
@test fn void static_bytes_text_and_ordinary_typed_aliases_remain_advisory(){
    selected(b"module main;fn ref u8[] f(bool c){var r=if(c){b\"a\"}else{b\"b\"};r=text::bytes(\"x\");return r;}fn i32 main(){return 42;}",0,9,false);
    selected(b"module main;fn ref i32[] f(ref i32[] a,bool c){let ref i32[] r=ref a;return ref r;}fn i32 main(){return 42;}",0,1,true);
    rejected(b"module main;fn ref u8[] f(ref u8[] a,bool c){return if(c){a}else{b\"x\"};}fn i32 main(){return 42;}");
}
