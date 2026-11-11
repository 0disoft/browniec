module tests::m2::source_state_work;
import source_state_work as work;
import source_context as raw;
import lexer as lexer;
import errors as errors;
import metadata_budget as budget;
fn u32 word(usize a,usize b,usize target){var usize value=a|(b<<13)|(target<<26);var u32 result=0;var u32 bit=1;
    while(value!=0){if((value&1)!=0){result|=bit;}value>>=1;if(value!=0){bit<<=1;}}return result;}
fn Result<lexer::State,errors::Error> run(ref u8[] source,ref raw::Table t,usize at){
    var work::State w=work::begin(at);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<500);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize row=w.row;let usize checked=w.check.cursor;let usize visits=w.check.visits;
        let usize cursor=w.result.cursor;assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,t,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.row==row && w.check.cursor==checked && w.check.visits==visits && w.result.cursor==cursor && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);
        switch(work::advance(source,t,ref mut w,ref mut meter)){
            case .ok(done):{assert(done==w.done && meter.last==4096 && w.check.visits-visits<=64);}
            case .err(e):{return .err(e);}};turns+=1;
    }
    let usize total=meter.total;assert(work::advance(source,t,ref mut w,ref mut meter).is_ok && meter.total==total);
    return work::prepared(ref w);
}
fn void same(ref u8[] source,ref raw::Table t,usize at){
    let Result<lexer::State,errors::Error> expected=raw::state(source,t,at);let Result<lexer::State,errors::Error> actual=run(source,t,at);
    switch(expected){case .ok(a):{switch(actual){case .ok(b):{assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end &&
                a.kind==b.kind && a.tokens==b.tokens && a.value==b.value && a.min_magnitude==b.min_magnitude && a.context==b.context);}
            case .err(_):{assert(false);}};}
        case .err(e):{switch(actual){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};}};
}
@test fn void unscoped_offsets_scoped_module_boundaries_and_text_aliases_match(){
    var raw::Table t=raw::empty();same(b"",ref t,0);same(b"x",ref t,4096);
    t.modules=2;t.ends[0]=4;t.ends[1]=8;t.imports=1;t.aliases[0]=word(0,4,1);
    same(b"textname",ref t,0);same(b"textname",ref t,3);same(b"textname",ref t,4);same(b"textname",ref t,7);
    same(b"textname",ref t,8);t.aliases[0]=word(4,8,0);same(b"textname",ref t,4);
    t=raw::empty();t.modules=1;t.ends[0]=4;t.imports=2;t.aliases[0]=word(0,4,0);t.aliases[1]=word(0,4,0);same(b"text",ref t,1);
}
@test fn void forged_context_authentication_yields_and_preserves_raw_failures(){
    var u8[4096] source=[65;4096];var raw::Table t=raw::empty();t.modules=1;t.ends[0]=4096;
    t.function_count=1;t.functions[0]=word(0,4096,0);same(ref source,ref t,4095);
    source[4095]=45;same(ref source,ref t,0);t.function_count=17;same(ref source,ref t,0);
    t=raw::empty();t.modules=17;same(b"x",ref t,0);t=raw::empty();t.modules=1;t.ends[0]=2;same(b"x",ref t,0);
    t.ends[0]=1;t.imports=1;t.aliases[0]=word(0,1,1);same(b"x",ref t,0);
}
