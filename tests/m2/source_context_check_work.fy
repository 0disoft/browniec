module tests::m2::source_context_check_work;
import source_context_check_work as work;
import source_context as raw;
import metadata_budget as budget;
fn u32 word(usize a,usize b,usize extra){
    var usize value=a|(b<<13)|extra;var u32 packed=0;var u32 bit=1;
    while(value!=0){if((value&1)!=0){packed|=bit;}value>>=1;if(value!=0){bit<<=1;}}return packed;
}
fn raw::Table table(){var raw::Table t=raw::empty();t.modules=2;t.ends[0]=3;t.ends[1]=6;
    t.imports=1;t.aliases[0]=word(0,3,67108864);t.function_count=1;t.functions[0]=word(3,6,67108864);
    t.record_count=1;t.records[0]=word(0,3,0);return t;}
fn void same(ref u8[] source,ref raw::Table t){
    let bool expected=raw::valid(source,t);var work::State w=work::empty();var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<512);assert(budget::reset(ref mut meter,0).is_ok);
        let usize row=w.row;let usize cursor=w.cursor;let usize visits=w.visits;let u8 phase=w.phase;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,t,ref mut w,ref mut meter).is_ok);
        assert(w.row==row && w.cursor==cursor && w.phase==phase && w.visits==visits && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);assert(work::advance(source,t,ref mut w,ref mut meter).is_ok);
        assert(w.visits-visits<=64 && meter.last==4096);turns+=1;
    }
    assert(w.result==expected);let usize total=meter.total;
    assert(work::advance(source,t,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void arbitrary_context_shapes_words_and_ascii_names_match_raw(){
    var raw::Table t=table();same(b"abcDEF",ref t);same(b"abcD.F",ref t);same(b"abc9EF",ref t);
    t=raw::empty();same(b"",ref t);same(b"abcDEF",ref t);
    t=table();t.modules=17;same(b"abcDEF",ref t);t=table();t.ends[0]=0;same(b"abcDEF",ref t);
    t=table();t.ends[1]=5;same(b"abcDEF",ref t);t=table();t.imports=65;same(b"abcDEF",ref t);
    t=table();t.function_count=17;same(b"abcDEF",ref t);t=table();t.record_count=33;same(b"abcDEF",ref t);
    t=table();t.aliases[0]=word(0,3,134217728);same(b"abcDEF",ref t);
    t=table();t.aliases[0]=word(0,4,0);same(b"abcDEF",ref t);
    t=table();t.functions[0]=word(3,6,134217728);same(b"abcDEF",ref t);
    t=table();t.records[0]=word(0,0,0);same(b"abcDEF",ref t);
    t=table();t.aliases[63]=1073741824;t.functions[15]=134217728;same(b"abcDEF",ref t);
}
@test fn void forged_long_name_validation_yields_without_skipping_bytes(){
    var u8[4096] source=[65;4096];var raw::Table t=raw::empty();t.modules=1;t.ends[0]=4096;
    t.function_count=1;t.functions[0]=word(0,4096,0);same(ref source,ref t);
    source[4095]=46;same(ref source,ref t);source[4095]=65;source[65]=128;same(ref source,ref t);
}
