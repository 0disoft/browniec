module tests::m2::initializer_metadata_lowering;
import struct_value_source as values;
import record_initializer_source_work as work;
import source_context as context;
import lexer as lexer;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
fn void same_result(Result<u8,errors::Error> a,Result<u8,errors::Error> b){switch(a){
    case .ok(v):{switch(b){case .ok(x):{assert(v==x);}case .err(_):{assert(false);}};}
    case .err(e):{switch(b){case .ok(_):{assert(false);}case .err(x):{assert(e.kind==x.kind && e.offset==x.offset);}};}};}
fn void same_state(ref lexer::State a,ref lexer::State b,ref values::Initializer x,ref values::Initializer y){
    assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end && a.kind==b.kind && a.tokens==b.tokens);
    assert(x.depth==y.depth && x.is_shorthand==y.is_shorthand);
    assert(x.shorthand.begin==y.shorthand.begin && x.shorthand.end==y.shorthand.end && x.shorthand.cursor==y.shorthand.cursor && x.shorthand.kind==y.shorthand.kind);
    var usize i=0;while(i<16){assert(x.records[i]==y.records[i] && x.fields[i]==y.fields[i]);i+=1;}}
fn Result<u8,errors::Error> staged(ref u8[] source,ref mut lexer::State s,ref ir::Program p,
    ref mut values::Initializer init,usize at,ref context::Table scope){var work::State w=work::begin_next(at);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,at)?;let bool done=work::advance(source,s,p,init,scope,ref mut w,ref mut meter)?;}
    return work::prepared(ref w);}
fn void one(ref u8[] source,usize suffix,bool ok){var ir::Program p=ir::empty();p.records.layouts.count=2;
    p.records.layouts.fields[0]=2;p.records.layouts.kinds[0]=1;p.records.layouts.types[0]=1;p.records.layouts.types[1]=1;
    p.records.layouts.fields[1]=1;p.records.layouts.types[16]=1;
    var lexer::State a=lexer::empty();a.cursor=source.len-suffix;assert(lexer::next(source,ref mut a).is_ok);var lexer::State b=a;
    var values::Initializer x=values::initializer(0);var values::Initializer y=x;var context::Table scope=context::empty();
    let Result<u8,errors::Error> raw=values::next_leaf_raw(source,ref mut a,ref p,ref mut x,77,ref scope);
    let Result<u8,errors::Error> staged_value=staged(source,ref mut b,ref p,ref mut y,77,ref scope);
    assert(raw.is_ok==ok && staged_value.is_ok==ok);same_result(raw,staged_value);same_state(ref a,ref b,ref x,ref y);}
@test fn void constructor_transitions_and_failure_prefixes(){
    one(b"module main;struct R{P p;i32 y;}struct P{i32 x;}.p=P{.x=42}",11,true);
    one(b"module main;struct R{P p;i32 y;}struct P{i32 x;}.p,",3,true);
    one(b"module main;struct R{P p;i32 y;}struct P{i32 x;}.p=other",8,true);
    one(b"module main;struct R{P p;i32 y;}struct P{i32 x;}.y=1",4,false);
    one(b"module main;struct R{P p;i32 y;}struct P{i32 x;}.p?",3,false);
    one(b"module main;struct R{P p;i32 y;}struct P{i32 x;}.p=P{.x=@}",10,false);
}
@test fn void initializer_budget_does_not_mutate_state(){let ref u8[] source=b".";var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    var values::Initializer init=values::initializer(0);var ir::Program p=ir::empty();var context::Table scope=context::empty();
    var work::State w=work::begin_next(5);var budget::State meter=budget::empty();assert(!work::prepared(ref w).is_ok);
    assert(budget::admit(ref mut meter,1,0).is_ok);assert(work::advance(source,ref mut s,ref p,ref mut init,ref scope,ref mut w,ref mut meter).is_ok);
    assert(w.phase==0 && init.depth==1 && init.fields[0]==0 && s.kind==46);
}

fn void closing(ref u8[] source){
    var ir::Program p=ir::empty();p.records.layouts.count=1;p.records.layouts.fields[0]=1;
    var lexer::State a=lexer::empty();assert(lexer::next(source,ref mut a).is_ok);var lexer::State b=a;
    var values::Initializer x=values::initializer(0);x.fields[0]=1;var values::Initializer y=x;let context::Table scope=context::empty();
    let Result<u8,errors::Error> raw=values::next_leaf_raw(source,ref mut a,ref p,ref mut x,7,ref scope);
    let Result<u8,errors::Error> lowered=staged(source,ref mut b,ref p,ref mut y,7,ref scope);same_result(raw,lowered);same_state(ref a,ref b,ref x,ref y);
}
@test fn void closing_and_advance_keep_partial_initializer_mutations(){
    closing(b"}");closing(b"}@");
    var usize mode=0;while(mode<3){let ref u8[] source=if(mode==0){b",42"}else if(mode==1){b"}"}else{b",@"};
        var ir::Program p=ir::empty();p.records.layouts.count=1;p.records.layouts.fields[0]=2;
        var lexer::State a=lexer::empty();assert(lexer::next(source,ref mut a).is_ok);var lexer::State b=a;
        var values::Initializer x=values::initializer(0);x.is_shorthand=true;x.shorthand=a;var values::Initializer y=x;
        let Result<usize,errors::Error> raw=values::advance_raw(source,ref mut a,ref p,ref mut x);
        let Result<usize,errors::Error> lowered=values::advance(source,ref mut b,ref p,ref mut y);
        assert(raw.is_ok==(mode==0) && lowered.is_ok==(mode==0));same_state(ref a,ref b,ref x,ref y);
        switch(raw){case .ok(v):{switch(lowered){case .ok(z):{assert(v==z);}case .err(_):{assert(false);}};}
            case .err(e):{switch(lowered){case .ok(_):{assert(false);}case .err(z):{assert(e.kind==z.kind && e.offset==z.offset);}};}};mode+=1;}
}
