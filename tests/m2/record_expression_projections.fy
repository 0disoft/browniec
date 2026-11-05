module tests::m2::record_expression_projections;
import compiler as compiler;
import ir as ir;
import vm as vm;
import verifier as verifier;
import program_image as programs;
import std::bytes as bytes;
fn void value(ref u8[] source){switch(compiler::compile_program(source,65536)){
    case .ok(p):{switch(programs::run_public(ref p,16000000)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};}
    case .err(_):{assert(false);}
};}
fn void rejected(ref u8[] source,u8 kind){switch(compiler::compile_program(source,65536)){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==kind);}
};}
fn ir::Program compiled(ref u8[] source){return switch(compiler::compile(source)){case .ok(p):{p}case .err(_):{assert(false);ir::empty()}};}
fn void identical(ref u8[] plain,ref u8[] grouped,usize backing){
    let ir::Program a=compiled(plain);let ir::Program b=compiled(grouped);
    assert(verifier::verify(ref a).is_ok && verifier::verify(ref b).is_ok);
    assert(a.count==b.count && a.registers==b.registers && a.records.count==b.records.count);
    var usize i=0;while(i<a.count*8){assert(a.code[i]==b.code[i]);i+=1;}
    switch(vm::run_with_array_limit(ref b,16000000,backing)){case .ok(n):{assert(n==42);}case .err(_):{assert(false);}};
}
@test fn void constructors_names_calls_and_split_paths_preserve_scalar_types(){
    value(b"module main;struct P{i32 x;i32 y;}fn i32 main(){let n=(P{.x=20,.y=22}).x;return n+P{.x=0,.y=22}.y;}");
    value(b"module main;struct P{i32 x;}struct R{i32 pad;P child;}fn R make(){return R{.pad=0,.child=P{.x=42}};}fn i32 main(){let r=make();return (((r).child)).x;}");
    value(b"module main;struct P{i32 x;}struct R{P child;}fn R make(){return R{.child=P{.x=42}};}fn i32 main(){let n=((make()).child).x;return n;}");
    value(b"module main;struct P{i64 x;u32 y;usize z;bool yes;u8 b;}fn i32 main(){let p=(P{.x=-9223372036854775808,.y=4294967295,.z=18446744073709551615,.yes=true,.b=42});if((p).x==-9223372036854775808 && (p).y==4294967295 && (p).z==18446744073709551615 && (p).yes){return (p).b as i32;}return 0;}");
}
@test fn void whole_and_child_values_compose_with_locals_returns_arguments_and_assignment(){
    value(b"module main;struct P{i32 x;}fn P make(){return (P{.x=42});}fn P pass(P p){return ((p));}fn i32 main(){let p=((make()));var P q=(p);q=((P{.x=0}));q=(pass((p)));return (q).x;}");
    value(b"module main;struct P{i32 x;}struct R{i32 pad;P child;}fn R make(){return (R{.pad=0,.child=(P{.x=42})});}fn P part(){return ((make()).child);}fn i32 take(P p){return (p).x;}fn i32 main(){var r=(R{.pad=0,.child=P{.x=0}});r.child=(part());return take(((r).child));}");
    value(b"module main;struct P{i32 x;}struct R{P child;}fn i32 main(){let r=R{.child=P{.x=42}};let p=((r).child);var q=(R{.child=(p)});q.child=((R{.child=P{.x=42}}).child);return (q.child).x;}");
}
@test fn void constructor_staging_and_mutable_captures_keep_once_only_source_order(){
    value(b"module main;struct P{i32 x;i32 y;}fn i32 tick(ref mut i32[] a){a[0]=a[0]+1;return a[0];}fn i32 main(){var a=[0];let n=(P{.x=tick(ref mut a),.y=tick(ref mut a)}).x;return n+a[0]+39;}");
    value(b"module main;struct P{i32 x;}struct R{P child;i32 y;}fn i32 take(P p,i32 n){return (p).x+n;}fn i32 main(){var p=(P{.x=20});let Option<i32> o=.none;let n=take((p),switch(o){case .some(v):{0}case .none:{p.x=22;0}});return n+p.x;}");
    value(b"module main;struct P{i32 x;}struct R{P child;i32 y;}fn i32 main(){var p=(P{.x=20});let Option<i32> o=.none;let r=(R{.child=(p),.y=switch(o){case .some(v):{0}case .none:{p.x=0;22}}});return r.child.x+r.y;}");
    value(b"module main;struct P{i32 x;}fn P make(ref mut i32[] c){c[0]=c[0]+1;return (P{.x=40});}fn i32 main(){var c=[0];let n=(make(ref mut c)).x;return n+c[0]+1;}");
}
@test fn void grouped_values_keep_existing_nonlocal_exit_cleanup_and_retained_execution(){
    value(b"module main;struct P{i32 x;}fn P make(){return (P{.x=0});}fn i32 take(P p,i32 n){return n;}fn i32 main(){let Option<i32> o=.none;var n=0;while(n<42){let k=take((make()),switch(o){case .some(v):{0}case .none:{n=n+1;continue;}});}while(true){let k=take((make()),switch(o){case .some(v):{0}case .none:{break;}});}return n;}");
    value(b"module main;struct P{i32 x;}fn i32 take(P p,i32 n){return p.x;}fn Option<i32> work(Option<i32> o){return .some(take((P{.x=42}),o?));}fn i32 main(){let ref u8[] marker=b\"*\";switch(work(.none)){case .some(_):{return 0;}case .none:{}}switch(work(.some(0))){case .some(v):{return v;}case .none:{return 0;}}}");
    value(b"module main;struct P{i32 x;}fn i32 main(){let ref u8[] marker=b\"*\";let Option<i32> o=.none;let p=(P{.x=switch(o){case .some(v):{0}case .none:{return 42;}}});return p.x;}");
}
@test fn void grouping_preserves_instruction_bytes_owner_counts_and_exact_backing(){
    identical(b"module main;struct P{i32 x;}fn i32 main(){let p=P{.x=42};return p.x;}",b"module main;struct P{i32 x;}fn i32 main(){let p=((P{.x=42}));return (p).x;}",4);
    identical(b"module main;struct P{i32 x;}fn i32 main(){var p=P{.x=0};p=P{.x=42};return p.x;}",b"module main;struct P{i32 x;}fn i32 main(){var p=(P{.x=0});p=((P{.x=42}));return (p).x;}",4);
    identical(b"module main;struct P{i32 x;}fn P make(){return P{.x=42};}fn i32 main(){return make().x;}",b"module main;struct P{i32 x;}fn P make(){return (P{.x=42});}fn i32 main(){return ((make())).x;}",4);
    identical(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){let p=P{.x=42};return take(p);}",b"module main;struct P{i32 x;}fn i32 take(P p){return (p).x;}fn i32 main(){let p=(P{.x=42});return take(((p)));}",8);
    let ir::Program p=compiled(b"module main;struct P{i32 x;}fn i32 main(){return (P{.x=42}).x;}");
    assert(p.records.count==0);assert(switch(vm::run_with_array_limit(ref p,16000000,0)){case .ok(n):{n==42}case .err(_):{false}});
}
@test fn void wrong_nominals_shapes_paths_and_protected_returned_owners_stay_rejected(){
    rejected(b"module main;struct P{i32 x;}struct Q{i32 x;}fn i32 main(){let P p=(Q{.x=42});return 0;}",3);
    rejected(b"module main;struct P{i32 x;}fn i32 main(){return (P{.x=42}).missing;}",3);
    rejected(b"module main;struct P{i32 x;}fn i32 take(P p){return p.x;}fn i32 main(){return take((42));}",3);
    rejected(b"module main;struct P{i32 x;}fn i32 main(){return (P{.x=true}).x;}",3);
    rejected(b"module main;struct P{i32 x;}fn i32 main(){return ((P{.x=42}).x;}",2);
    rejected(b"module main;struct P{i32 x;}struct R{P child;}fn i32 main(){let p=R{.child=P{.x=42}};return (p).child;}",3);
    rejected(b"module main;struct P{i32 x;}fn ref u8[] hold(P p,ref u8[] a){return ref a;}fn i32 main(){var u8[1] a=[42];let q=hold((P{.x=0}),ref a);a=[0];return q[0] as i32;}",5);
}
fn void append(ref mut bytes::Buffer b,ref u8[] source){assert(bytes::append(b,source).is_ok);}
fn void groups(usize count,bool pass){
    var bytes::Buffer source=bytes::empty();append(ref mut source,b"module main;struct P{i32 x;}fn i32 main(){let p=P{.x=42};return ");
    var usize i=0;while(i<count){append(ref mut source,b"(");i+=1;}append(ref mut source,b"p");
    i=0;while(i<count){append(ref mut source,b")");i+=1;}append(ref mut source,b".x;}");
    if(pass){value(bytes::view(ref source));}else{rejected(bytes::view(ref source),4);}
}
fn void calls(usize count,bool pass,bool retained,bool first){
    var bytes::Buffer source=bytes::empty();append(ref mut source,b"module main;struct P{i32 x;}fn i32 id(");
    append(ref mut source,if(first){b"P p,i32 n"}else{b"i32 n,P p"});
    append(ref mut source,b"){return n;}fn i32 main(){let p=P{.x=0};");
    if(retained){append(ref mut source,b"let ref u8[] marker=b\"*\";");}append(ref mut source,b"return ");
    var usize i=0;while(i<count){append(ref mut source,if(first){b"id((p),"}else{b"id("});i+=1;}
    append(ref mut source,b"42");i=0;while(i<count){append(ref mut source,if(first){b")"}else{b",(p))"});i+=1;}append(ref mut source,b";}");
    if(pass){value(bytes::view(ref source));}else{rejected(bytes::view(ref source),4);}
}
@test fn void grouping_and_32_deep_calls_keep_original_bounded_parser_stack(){
    groups(32,true);groups(33,false);
    calls(32,true,false,true);calls(33,false,false,true);calls(32,true,true,true);calls(33,false,true,true);
    calls(32,true,false,false);calls(33,false,false,false);calls(32,true,true,false);calls(33,false,true,false);
}
