module tests::m2::semantic_lowering;
import semantic_source_work as work;
import lexer as lexer;
import ir as ir;
import locals as locals;
import metadata_budget as budget;
fn void declaration(ref u8[] source,bool mutable){
    var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    var ir::Program p=ir::empty();var locals::Table names=locals::empty();
    var work::State w=work::begin(s,1,0,59,0);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok && !work::resume(ref mut w,1,0,false).is_ok);
    while(!w.done){assert(turns<4000);let u8 phase=w.phase;let usize count=p.count;
        let usize cursor=s.cursor;let usize bindings=names.count;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);
        let usize total=meter.total;
        assert(work::advance(source,ref mut s,ref mut p,ref mut names,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && p.count==count && s.cursor==cursor && names.count==bindings && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);
        assert(work::advance(source,ref mut s,ref mut p,ref mut names,ref mut w,ref mut meter).is_ok);
        if(w.request==1){let u8 tag=w.expression.frames[w.expression.used-1].expected;let i64 value=s.value;let usize at=s.begin;
            assert(s.kind==1 && names.count==0 && lexer::next(source,ref mut s).is_ok);
            let usize reg=switch(ir::integer(ref mut p,value,tag,at)){case .ok(v):{v}case .err(_):{assert(false);0}};
            assert(work::resume(ref mut w,1,reg,false).is_ok && !work::resume(ref mut w,1,reg,false).is_ok);}
        else{assert(w.request==0);}
        if(!w.done){assert(names.count==0 && !work::prepared(ref w).is_ok);}turns+=1;
    }
    assert(work::prepared(ref w).is_ok && names.count==1 && names.mutable[0]==mutable && s.kind==0);
    assert(p.types[names.registers[0]]==1 && p.slots[names.registers[0]]==mutable);
    let usize total=meter.total;assert(work::advance(source,ref mut s,ref mut p,ref mut names,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void annotated_bindings_publish_only_after_initializer_and_terminator(){
    declaration(b"let i32 value=20+11*2;",false);declaration(b"var i32 value=42;",true);
}
