module tests::m2::body_source_work;
import body_source_work as work;
import lexer as lexer;
import ir as ir;
import locals as locals;
import loops as loops;
import metadata_budget as budget;
import std::bytes as bytes;
fn bool blocks(ref u8[] source,usize depth){
    var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    var ir::Program p=ir::empty();var locals::Table names=locals::empty();var loops::State flow=loops::empty();
    var work::State w=work::begin(depth,true);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<2000);assert(w.request==0);assert(budget::reset(ref mut meter,0).is_ok);
        let usize visits=w.visits;let usize used=w.used;let usize cursor=s.cursor;let bool lexing=w.lexing;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(switch(work::advance(source,ref mut s,ref mut p,ref mut names,ref mut flow,ref mut w,ref mut meter)){case .ok(v):{!v}case .err(_):{assert(false);false}});
        assert(w.visits==visits && w.used==used && s.cursor==cursor && w.lexing==lexing && meter.total==total && p.count==0);
        assert(budget::reset(ref mut meter,0).is_ok);
        switch(work::advance(source,ref mut s,ref mut p,ref mut names,ref mut flow,ref mut w,ref mut meter)){
            case .ok(_):{}case .err(e):{assert(e.kind==4 && e.offset<=source.len);return false;}};
        assert(w.visits-visits<=1 && meter.last==4096);turns+=1;
    }
    assert(work::prepared(ref w).is_ok && !w.stopped);let usize total=meter.total;
    assert(work::advance(source,ref mut s,ref mut p,ref mut names,ref mut flow,ref mut w,ref mut meter).is_ok && meter.total==total);
    assert(names.count==0 && flow.depth==0 && s.kind==0 && turns>4);return true;
}
@test fn void explicit_scope_frames_preserve_depth_and_deferral_without_semantic_replay(){
    var bytes::Buffer source=bytes::empty();var usize i=0;
    while(i<33){assert(bytes::append(ref mut source,b"{").is_ok);i+=1;}
    assert(bytes::append(ref mut source,b"/* a comment crosses token stages */                                                         ").is_ok);
    i=0;while(i<33){assert(bytes::append(ref mut source,b"}").is_ok);i+=1;}
    assert(blocks(bytes::view(ref source),0));assert(!blocks(bytes::view(ref source),1));
}
@test fn void semantic_children_wait_for_one_matching_completion(){
    let ref u8[] source=b"{x;}";var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);
    var ir::Program p=ir::empty();var locals::Table names=locals::empty();var loops::State flow=loops::empty();
    var work::State w=work::begin(0,true);var budget::State meter=budget::empty();
    while(w.request==0){assert(budget::reset(ref mut meter,0).is_ok);assert(work::advance(source,ref mut s,ref mut p,ref mut names,ref mut flow,ref mut w,ref mut meter).is_ok);}
    assert(w.request==1);let usize visits=w.visits;let usize cursor=s.cursor;
    assert(budget::reset(ref mut meter,0).is_ok);assert(work::advance(source,ref mut s,ref mut p,ref mut names,ref mut flow,ref mut w,ref mut meter).is_ok);
    assert(meter.last==0 && w.visits==visits && s.cursor==cursor && !work::resume(ref mut w,2,0,false).is_ok && w.request==1);
    assert(lexer::next(source,ref mut s).is_ok && lexer::punctuation(source,ref mut s,59).is_ok);
    assert(work::resume(ref mut w,1,0,false).is_ok && !work::resume(ref mut w,1,0,false).is_ok);
    while(!w.done){assert(budget::reset(ref mut meter,0).is_ok);assert(work::advance(source,ref mut s,ref mut p,ref mut names,ref mut flow,ref mut w,ref mut meter).is_ok);}
    assert(work::prepared(ref w).is_ok && !w.stopped && p.count==0);
}
