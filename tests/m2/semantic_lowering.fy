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

fn void returning(bool void_result){let ref u8[] source=if(void_result){b"return;"}else{b"return 42;"};
    var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    var ir::Program p=ir::empty();var locals::Table names=locals::empty();names.count=2;names.registers[0]=128;names.registers[1]=129;names.pending_places=9;
    var work::State w=work::begin(s,if(void_result){3}else{2},if(void_result){13}else{1},59,0);
    var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<2000);let u8 phase=w.phase;let usize row=w.row;let usize count=p.count;let usize cursor=s.cursor;
        assert(budget::reset(ref mut meter,0).is_ok && budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,ref mut s,ref mut p,ref mut names,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.row==row && p.count==count && s.cursor==cursor && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok && work::advance(source,ref mut s,ref mut p,ref mut names,ref mut w,ref mut meter).is_ok);
        if(phase==35 || phase==36){assert(p.count-count<=1 && (w.row==row || w.row+1==row || phase!=w.phase));}
        if(w.request==1){let usize at=s.begin;let i64 value=s.value;assert(s.kind==1 && lexer::next(source,ref mut s).is_ok);
            let usize reg=switch(ir::integer(ref mut p,value,1,at)){case .ok(v):{v}case .err(_):{assert(false);0}};
            assert(work::resume(ref mut w,1,reg,false).is_ok);}
        else{assert(w.request==0);}if(!w.done){assert(!work::prepared(ref w).is_ok);}turns+=1;
    }
    assert(w.stopped && work::prepared(ref w).is_ok && s.kind==0 && names.count==2 && names.pending_places==9);
    let usize base=if(void_result){0}else{1};assert(p.count==base+5);
    assert(p.code[base*8]==86 && p.code[base*8+1]==3 && p.code[(base+1)*8]==86 && p.code[(base+1)*8+1]==0);
    assert(p.code[(base+2)*8]==37 && p.code[(base+2)*8+1]==1 && p.code[(base+3)*8]==37 && p.code[(base+3)*8+1]==0);
    assert(p.code[(base+4)*8]==if(void_result){82}else{8});
    var usize i=base;while(i<p.count){assert(p.offsets[i]==0);i+=1;}
    let usize total=meter.total;assert(work::advance(source,ref mut s,ref mut p,ref mut names,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void returns_resume_one_reverse_cleanup_row_before_emitting_return(){returning(false);returning(true);}
