module tests::m2::output_reference_lifetimes_work;
import output_reference_lifetimes_work as work;
import reference_lifetimes as raw;
import static_ir as statics;
import ir as ir;
import errors as errors;
import metadata_budget as budget;

fn ir::Program program(){
    var ir::Program p=ir::empty();p.count=5;p.function_count=2;p.starts[1]=4;p.ends[0]=4;p.ends[1]=5;
    p.arities[1]=1;p.call_count=1;p.call_arities[0]=1;p.call_args[0]=160;
    p.arrays.count=1;p.slice_roots[0]=1;
    p.code[0]=78;p.code[2]=1;p.code[8]=70;p.code[16]=37;p.code[24]=82;p.code[32]=82;
    return p;
}
fn statics::Sites sites(){var statics::Sites s=statics::empty();s.results[1]=3;s.origins[1]=1;return s;}
fn Result<usize[16],errors::Error> staged(ref ir::Program p,ref statics::Sites s){
    var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<600);assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(p,s,ref mut w,ref mut meter)?;assert(done==w.done && meter.last==4096);turns+=1;
    }return .ok(w.roots);
}
fn Result<usize[16],errors::Error> synchronous(ref ir::Program p,ref statics::Sites s){
    let usize[16] roots=raw::prepare(p,s)?;let usize checked=raw::inspect(p,s,ref roots)?;return .ok(roots);
}
fn void same(ref ir::Program p,ref statics::Sites s){
    switch(synchronous(p,s)){
        case .ok(expected):{switch(staged(p,s)){case .ok(actual):{var usize i=0;while(i<16){assert(expected[i]==actual[i]);i+=1;}}case .err(_):{assert(false);}};}
        case .err(expected):{switch(staged(p,s)){case .ok(_):{assert(false);}case .err(actual):{assert(expected.kind==actual.kind && expected.offset==actual.offset);}};}
    };
}
@test fn void owner_dependencies_alias_close_and_long_cfg_match_raw(){
    var ir::Program p=program();let statics::Sites s=sites();same(ref p,ref s);
    p.code[8]=75;p.code[9]=1; // alias 1 retains owner 0 after closing 0
    p.code[16]=70;same(ref p,ref s);
    p.code[16]=37;same(ref p,ref s);
    p=program();p.count=256;p.starts[1]=255;p.ends[0]=255;p.ends[1]=256;
    var usize pc=3;while(pc<256){p.code[pc*8]=82;pc+=1;}
    // All PCs are visited, including unreachable instructions after a return.
    same(ref p,ref s);
}
@test fn void mutation_bad_origins_and_cfg_join_diagnostics_match_raw(){
    var ir::Program p=program();var statics::Sites s=sites();p.code[8]=37;same(ref p,ref s);
    p=program();s.origins[1]=0;same(ref p,ref s);s.origins[1]=10;same(ref p,ref s);
    s=sites();p.call_args[0]=255;same(ref p,ref s);
    p=program();p.slice_roots[0]=2;same(ref p,ref s);
    p=program();p.code[8]=20;p.code[11]=3;p.code[16]=70;same(ref p,ref s);
    p=program();p.code[8]=22;p.code[10]=0;same(ref p,ref s);
}
@test fn void partial_room_preserves_roots_and_cfg_banks_at_every_stage(){
    let ir::Program p=program();let statics::Sites s=sites();var work::State w=work::empty();var budget::State meter=budget::empty();
    var usize turns=0;while(!w.done){
        assert(budget::reset(ref mut meter,0).is_ok);assert(budget::admit(ref mut meter,1,0).is_ok);
        let work::State before=w;let budget::State saved=meter;
        switch(work::advance(ref p,ref s,ref mut w,ref mut meter)){case .ok(v):{assert(!v);}case .err(_):{assert(false);}};
        assert(w.phase==before.phase && w.pc==before.pc && w.function==before.function && w.done==before.done);
        var usize i=0;while(i<16){assert(w.roots[i]==before.roots[i]);i+=1;}
        i=0;while(i<256){assert(w.seen[i]==before.seen[i] && w.states[i]==before.states[i]);i+=1;}
        assert(meter.total==saved.total && meter.last==saved.last && meter.stages==saved.stages);
        assert(budget::reset(ref mut meter,0).is_ok);assert(work::advance(ref p,ref s,ref mut w,ref mut meter).is_ok);
        turns+=1;assert(turns<30);
    }
    let usize total=meter.total;assert(work::advance(ref p,ref s,ref mut w,ref mut meter).is_ok);assert(total==meter.total);
}
